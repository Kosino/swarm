/** Shared gesture recognition helpers — encircle, connect snap, miss FX. */

export type Pt = { x: number; y: number };

export type PointerMeta = {
  /** Device pixel ratio (canvas buffer / CSS). */
  dpr: number;
  /** True for touch / pen contact. */
  touch: boolean;
};

export type MissFx = {
  x: number;
  y: number;
  t: number;
  dur: number;
};

/** Encircle: close when end within this of start (logical px). */
export const ENC_CLOSE_PX = 60;
/** Encircle: accept if angular coverage around target ≥ this. */
export const ENC_ANGLE_FRAC = 0.8;
/** Encircle: shape hit if outline sample coverage ≥ this. */
export const ENC_OUTLINE_FRAC = 0.5;
/** Connect: base magnetic snap radius (logical px). */
export const SNAP_BASE = 40;
/** Pheromone / join: auto-finish when end within this of target. */
export const TRAIL_FINISH_PX = 60;
/** Human-hand sim: positional jitter (px). */
export const HAND_JITTER = 10;
/** Human-hand sim: loop radius undershoot fraction. */
export const HAND_UNDERSHOOT = 0.15;

export function pathLength(pts: Pt[]): number {
  let len = 0;
  for (let i = 1; i < pts.length; i++) {
    len += Math.hypot(pts[i]!.x - pts[i - 1]!.x, pts[i]!.y - pts[i - 1]!.y);
  }
  return len;
}

export function pointInPoly(px: number, py: number, pts: Pt[]): boolean {
  let inside = false;
  for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    const xi = pts[i]!.x;
    const yi = pts[i]!.y;
    const xj = pts[j]!.x;
    const yj = pts[j]!.y;
    const hit =
      yi > py !== yj > py && px < ((xj - xi) * (py - yi)) / (yj - yi + 1e-9) + xi;
    if (hit) inside = !inside;
  }
  return inside;
}

/** Moving-average smooth then resample to roughly `spacing` px. */
export function smoothResample(pts: Pt[], spacing = 8, passes = 1): Pt[] {
  if (pts.length < 2) return pts.map((p) => ({ ...p }));
  let cur = pts.map((p) => ({ ...p }));
  for (let p = 0; p < passes; p++) {
    if (cur.length < 3) break;
    const next: Pt[] = [{ ...cur[0]! }];
    for (let i = 1; i < cur.length - 1; i++) {
      const a = cur[i - 1]!;
      const b = cur[i]!;
      const c = cur[i + 1]!;
      next.push({
        x: (a.x + b.x * 2 + c.x) * 0.25,
        y: (a.y + b.y * 2 + c.y) * 0.25,
      });
    }
    next.push({ ...cur[cur.length - 1]! });
    cur = next;
  }
  const out: Pt[] = [{ ...cur[0]! }];
  let ax = cur[0]!.x;
  let ay = cur[0]!.y;
  let budget = spacing;
  for (let i = 1; i < cur.length; i++) {
    let x1 = cur[i]!.x;
    let y1 = cur[i]!.y;
    let dx = x1 - ax;
    let dy = y1 - ay;
    let seg = Math.hypot(dx, dy);
    while (seg >= budget && seg > 1e-6) {
      const t = budget / seg;
      ax += dx * t;
      ay += dy * t;
      out.push({ x: ax, y: ay });
      dx = x1 - ax;
      dy = y1 - ay;
      seg = Math.hypot(dx, dy);
      budget = spacing;
    }
    budget -= seg;
    ax = x1;
    ay = y1;
  }
  const last = cur[cur.length - 1]!;
  const tip = out[out.length - 1]!;
  if (Math.hypot(last.x - tip.x, last.y - tip.y) > 1.5) out.push({ ...last });
  return out;
}

/** Fraction of 2π covered by stroke angles around (cx,cy), via unique bins. */
export function angularCoverage(pts: Pt[], cx: number, cy: number, bins = 36): number {
  if (pts.length < 3) return 0;
  const hit = new Uint8Array(bins);
  for (const p of pts) {
    let a = Math.atan2(p.y - cy, p.x - cx);
    if (a < 0) a += Math.PI * 2;
    const b = Math.min(bins - 1, Math.floor((a / (Math.PI * 2)) * bins));
    hit[b] = 1;
  }
  let n = 0;
  for (let i = 0; i < bins; i++) n += hit[i]!;
  return n / bins;
}

/** Fraction of outline samples that fall inside the stroke polygon. */
export function outlineCoverage(
  pts: Pt[],
  cx: number,
  cy: number,
  rx: number,
  ry: number,
  samples = 24,
): number {
  if (pts.length < 3) return 0;
  let inside = 0;
  for (let i = 0; i < samples; i++) {
    const a = (i / samples) * Math.PI * 2;
    const x = cx + Math.cos(a) * rx;
    const y = cy + Math.sin(a) * ry;
    if (pointInPoly(x, y, pts)) inside++;
  }
  return inside / samples;
}

export function loopClosed(pts: Pt[], closePx = ENC_CLOSE_PX): boolean {
  if (pts.length < 3) return false;
  const a = pts[0]!;
  const b = pts[pts.length - 1]!;
  return Math.hypot(b.x - a.x, b.y - a.y) <= closePx;
}

/** True if stroke closes around shape OR covers enough angle + hits shape. */
export function encircleRecognized(
  raw: Pt[],
  shape: { x: number; y: number; rx: number; ry: number },
  opts: {
    minLen?: number;
    minPts?: number;
    closePx?: number;
    angleFrac?: number;
    outlineFrac?: number;
  } = {},
): { ok: boolean; poly: Pt[] } {
  const minLen = opts.minLen ?? 140;
  const minPts = opts.minPts ?? 10;
  const closePx = opts.closePx ?? ENC_CLOSE_PX;
  const angleFrac = opts.angleFrac ?? ENC_ANGLE_FRAC;
  const outlineFrac = opts.outlineFrac ?? ENC_OUTLINE_FRAC;

  const poly = smoothResample(raw);
  if (poly.length < minPts || pathLength(poly) < minLen) return { ok: false, poly };

  const closed = loopClosed(poly, closePx);
  const ang = angularCoverage(poly, shape.x, shape.y);
  if (!closed && ang < angleFrac) return { ok: false, poly };

  const centerHit = pointInPoly(shape.x, shape.y, poly);
  const outline = outlineCoverage(poly, shape.x, shape.y, shape.rx, shape.ry);
  const hit = centerHit || outline >= outlineFrac;
  return { ok: hit, poly };
}

/** Magnetic snap radius: ~40px × DPR, larger on touch. */
export function snapRadius(meta?: PointerMeta): number {
  const dpr = meta?.dpr ?? 1;
  const touch = meta?.touch ?? false;
  return SNAP_BASE * Math.max(1, dpr) * (touch ? 1.55 : 1);
}

export function nearestTarget<T extends { x: number; y: number }>(
  x: number,
  y: number,
  targets: T[],
  maxDist: number,
): { target: T; dist: number; index: number } | null {
  let best: T | null = null;
  let bd = maxDist;
  let bi = -1;
  for (let i = 0; i < targets.length; i++) {
    const t = targets[i]!;
    const d = Math.hypot(t.x - x, t.y - y);
    if (d < bd) {
      bd = d;
      best = t;
      bi = i;
    }
  }
  return best ? { target: best, dist: bd, index: bi } : null;
}

export function spawnMiss(x: number, y: number): MissFx {
  return { x, y, t: 0, dur: 0.55 };
}

export function tickMiss(list: MissFx[], dt: number): void {
  for (const m of list) m.t += dt;
  for (let i = list.length - 1; i >= 0; i--) {
    if (list[i]!.t >= list[i]!.dur) list.splice(i, 1);
  }
}

export function drawMissFx(ctx: CanvasRenderingContext2D, list: MissFx[]): void {
  for (const m of list) {
    const k = m.t / m.dur;
    const a = (1 - k) * 0.55;
    const r = 10 + k * 22;
    ctx.strokeStyle = `rgba(180,110,100,${a})`;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(m.x, m.y, r, 0, Math.PI * 2);
    ctx.stroke();
    // Soft X
    const s = 6 + k * 8;
    ctx.beginPath();
    ctx.moveTo(m.x - s, m.y - s);
    ctx.lineTo(m.x + s, m.y + s);
    ctx.moveTo(m.x + s, m.y - s);
    ctx.lineTo(m.x - s, m.y + s);
    ctx.stroke();
  }
}

/** Noisy human-hand circle around (cx,cy). Undershoots radius; adds jitter. */
export function noisyLoop(
  cx: number,
  cy: number,
  r: number,
  steps: number,
  rng: () => number,
  opts: { jitter?: number; undershoot?: number } = {},
): Pt[] {
  const jitter = opts.jitter ?? HAND_JITTER;
  const under = opts.undershoot ?? HAND_UNDERSHOOT;
  const rr = r * (1 - under);
  const pts: Pt[] = [];
  // Leave a gap so close must rely on ENC_CLOSE_PX / angle (realistic miss-close)
  const span = Math.PI * 2 * (0.92 + rng() * 0.06);
  const a0 = rng() * Math.PI * 2;
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    const a = a0 + t * span;
    const jr = (rng() - 0.5) * 2 * jitter;
    const ja = (rng() - 0.5) * 0.08;
    pts.push({
      x: cx + Math.cos(a + ja) * (rr + jr),
      y: cy + Math.sin(a + ja) * (rr + jr),
    });
  }
  return pts;
}

/** Noisy drag from A→B that undershoots toward B then needs snap. */
export function noisyConnect(
  ax: number,
  ay: number,
  bx: number,
  by: number,
  steps: number,
  rng: () => number,
  opts: { jitter?: number; undershoot?: number } = {},
): Pt[] {
  const jitter = opts.jitter ?? HAND_JITTER;
  const under = opts.undershoot ?? HAND_UNDERSHOOT;
  const dx = bx - ax;
  const dy = by - ay;
  const len = Math.hypot(dx, dy);
  const stop = Math.max(0, 1 - under);
  const pts: Pt[] = [];
  for (let i = 0; i <= steps; i++) {
    const t = (i / steps) * stop;
    pts.push({
      x: ax + dx * t + (rng() - 0.5) * 2 * jitter,
      y: ay + dy * t + (rng() - 0.5) * 2 * jitter,
    });
  }
  // Long edges: 15% undershoot can exceed snap — park end just inside finish radius
  const last = pts[pts.length - 1]!;
  const dist = Math.hypot(bx - last.x, by - last.y);
  const finish = Math.max(SNAP_BASE, TRAIL_FINISH_PX) * 0.92;
  if (dist > finish && len > 1) {
    const t = 1 - finish / dist;
    last.x += (bx - last.x) * t;
    last.y += (by - last.y) * t;
  }
  return pts;
}
