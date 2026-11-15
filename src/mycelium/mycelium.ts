import {
  W,
  H,
  SPEED,
  STEP,
  MAXTIPS,
  BRANCH_P,
  SENSE,
  GUIDE_R,
  SEED_CLEAR,
  FUSION_R,
  FUSION_MIN_T,
  FUSION_COOLDOWN,
  HOLD_S,
  HOLD_R,
  HOLD_SPEED_MUL,
  HOLD_BRANCH_MUL,
  HOLD_STEER,
  WORKER_MIN_SEGS,
  WORKER_DELAY,
  MAX_WORKERS,
  WORKER_SPAWN_RATE,
  WORKER_SPEED,
  BIG_APPEAR_T,
  BIG_R,
  BIG_EDGE,
  CAM_ZOOM_OUT,
  CAM_ZOOM_DUR,
} from "./config";
import { playDum } from "./sound";
import {
  loadMyceliumAtlas,
  drawCentered,
  drawSegSprite,
  drawTipSprite,
  type MycAtlas,
} from "./atlas";
import type { Seg, Tip, Patch, Pulse, Ring, Speck, Worker, SimMetrics } from "./types";
import { mountCanvas } from "../core";

const SOIL_TILE = 64;
const SEG_TH = [7.5, 10.5, 13.5, 17];

function wrap(a: number): number {
  while (a > Math.PI) a -= 2 * Math.PI;
  while (a < -Math.PI) a += 2 * Math.PI;
  return a;
}

function distPointSeg(
  px: number,
  py: number,
  x1: number,
  y1: number,
  x2: number,
  y2: number,
): { d: number; cx: number; cy: number } {
  const dx = x2 - x1;
  const dy = y2 - y1;
  const len2 = dx * dx + dy * dy;
  let t = len2 > 0 ? ((px - x1) * dx + (py - y1) * dy) / len2 : 0;
  t = Math.max(0, Math.min(1, t));
  const cx = x1 + t * dx;
  const cy = y1 + t * dy;
  return { d: Math.hypot(px - cx, py - cy), cx, cy };
}

export type WorldOpts = {
  /** Disable Web Audio (headless / CI). */
  silent?: boolean;
  /** Fixed RNG seed; omit for Math.random. */
  rng?: () => number;
};

export type WorldSnapshot = {
  tips: { x: number; y: number }[];
  patches: { x: number; y: number; on: boolean; big?: boolean }[];
  seed: { x: number; y: number } | null;
};

export type MyceliumWorld = {
  update: (dt: number) => void;
  draw: (ctx: CanvasRenderingContext2D, dpr: number) => void;
  pointerDown: (x: number, y: number) => void;
  pointerMove: (x: number, y: number) => void;
  pointerUp: () => void;
  metrics: () => SimMetrics;
  snapshot: () => WorldSnapshot;
  /** Stress-fill network for FPS measurement. */
  stressFill: (segCount: number, workerCount: number) => void;
  setAtlas: (atlas: MycAtlas) => void;
};

/** Shared Build #1+#2 sim — canvas optional for headless runs. */
export function createMyceliumWorld(opts: WorldOpts = {}): MyceliumWorld {
  const rnd = opts.rng ?? Math.random;
  const silent = !!opts.silent;

  const patches: Patch[] = [];
  const n = 6 + Math.floor(rnd() * 5);
  let guard = 0;
  while (patches.length < n && guard++ < 800) {
    const r = 16 + rnd() * 14;
    const x = 70 + rnd() * (W - 140);
    const y = 70 + rnd() * (H - 140);
    if (patches.every((p: Patch) => Math.hypot(p.x - x, p.y - y) > 150)) {
      patches.push({ x, y, r, lit: 0, on: false, ph: rnd() * 6 });
    }
  }
  const specks: Speck[] = Array.from({ length: 120 }, () => ({
    x: rnd() * W,
    y: rnd() * H,
    r: rnd() * 1.6 + 0.3,
    a: rnd() * 0.05 + 0.015,
  }));

  // Random seamless soil tile indices (a/b/c)
  const soilCols = Math.ceil(W / SOIL_TILE) + 1;
  const soilRows = Math.ceil(H / SOIL_TILE) + 1;
  const soilTiles: (0 | 1 | 2)[] = Array.from({ length: soilCols * soilRows }, () =>
    (Math.floor(rnd() * 3) as 0 | 1 | 2),
  );
  const soilNames = ["puda_a", "puda_b", "puda_c"] as const;

  const segs: Seg[] = [];
  let tips: Tip[] = [];
  const pulses: Pulse[] = [];
  const rings: Ring[] = [];
  const workers: Worker[] = [];
  const routes: number[][] = [];
  let seed: { x: number; y: number } | null = null;
  let seedGlow = 0;
  let guideA = 0;
  let guideW = 0;
  let dragging = false;
  let dsx = 0;
  let dsy = 0;
  let hx = W / 2;
  let hy = H / 2;
  let hovering = false;
  let time = 0;
  let holdT = 0;
  let densify = false;
  let densifyX = 0;
  let densifyY = 0;
  let fusionCd = 0;
  let firstAnchor: number | null = null;
  let midstep: number | null = null;
  let firstFusion: number | null = null;
  let firstWorkers: number | null = null;
  let bigSpawned = false;
  let bigAnchored = false;
  let bigAnchorTime: number | null = null;
  let camZoom = 1;
  let camZoomTarget = 1;
  let networkPulse = 0;
  let networkBright = 0;
  let atlas: MycAtlas | null = null;
  let midWowDone = false;

  const pushSeg = (
    x1: number,
    y1: number,
    x2: number,
    y2: number,
    p: number,
    th: number,
    fuseGlow?: number,
  ): number => {
    const seg: Seg = { x1, y1, x2, y2, p, th, v: rnd() < 0.5 ? 0 : 1 };
    if (fuseGlow !== undefined) seg.fuseGlow = fuseGlow;
    segs.push(seg);
    return segs.length - 1;
  };

  const addTip = (x: number, y: number, a: number, seg: number) => {
    tips.push({ x, y, a, seg, sx: x, sy: y, g: false });
  };

  const ancestors = (segIdx: number): Set<number> => {
    const s = new Set<number>();
    let i = segIdx;
    let guardA = 0;
    while (i >= 0 && guardA++ < 4000) {
      s.add(i);
      i = segs[i].p;
    }
    return s;
  };

  const dum = (big: boolean, soft = false) => {
    if (!silent) playDum(big, soft);
  };

  const spawnBigPatch = () => {
    if (bigSpawned || !seed) return;
    bigSpawned = true;
    const corners: [number, number][] = [
      [BIG_EDGE + BIG_R, BIG_EDGE + BIG_R],
      [W - BIG_EDGE - BIG_R, BIG_EDGE + BIG_R],
      [BIG_EDGE + BIG_R, H - BIG_EDGE - BIG_R],
      [W - BIG_EDGE - BIG_R, H - BIG_EDGE - BIG_R],
    ];
    let best = corners[0];
    let bd = -1;
    for (const c of corners) {
      const d = Math.hypot(c[0] - seed.x, c[1] - seed.y);
      if (d > bd) {
        bd = d;
        best = c;
      }
    }
    patches.push({
      x: best[0],
      y: best[1],
      r: BIG_R,
      lit: 0,
      on: false,
      ph: rnd() * 6,
      big: true,
    });
  };

  const plantSeed = (x: number, y: number) => {
    if (seed) return;
    seed = { x, y };
    for (const p of patches) {
      if (Math.hypot(p.x - x, p.y - y) >= SEED_CLEAR) continue;
      for (let k = 0; k < 300; k++) {
        const nx = 70 + rnd() * (W - 140);
        const ny = 70 + rnd() * (H - 140);
        if (
          Math.hypot(nx - x, ny - y) >= SEED_CLEAR &&
          patches.every((q: Patch) => q === p || Math.hypot(q.x - nx, q.y - ny) > 150)
        ) {
          p.x = nx;
          p.y = ny;
          break;
        }
      }
    }
    rings.push({ x, y, t: 0, big: false });
    const k = 3;
    const base = rnd() * Math.PI * 2;
    for (let i = 0; i < k; i++)
      addTip(x, y, base + (i * Math.PI * 2) / k + (rnd() - 0.5) * 0.6, -1);
  };

  const pointerDown = (x: number, y: number) => {
    if (!seed) plantSeed(x, y);
    dragging = true;
    holdT = 0;
    densify = false;
    dsx = x;
    dsy = y;
    hx = x;
    hy = y;
    guideW = 0;
    for (const t of tips) t.g = Math.hypot(t.x - x, t.y - y) < GUIDE_R;
  };

  const pointerMove = (x: number, y: number) => {
    hx = x;
    hy = y;
    hovering = true;
    if (!dragging || !seed) return;
    const dx = x - dsx;
    const dy = y - dsy;
    const len = Math.hypot(dx, dy);
    if (len > 12) {
      guideA = Math.atan2(dy, dx);
      guideW = 1;
      holdT = 0;
      densify = false;
    }
    if (len > 80) {
      dsx += dx * 0.4;
      dsy += dy * 0.4;
    }
  };

  const pointerUp = () => {
    dragging = false;
    holdT = 0;
    densify = false;
  };

  const wholeNetworkPath = (fromX: number, fromY: number): number[] => {
    const indexed = segs.map((s, i) => ({
      i,
      d: Math.hypot((s.x1 + s.x2) * 0.5 - fromX, (s.y1 + s.y2) * 0.5 - fromY),
    }));
    indexed.sort((a, b) => a.d - b.d);
    return indexed.map((x) => x.i);
  };

  const anchor = (tip: Tip, p: Patch) => {
    const idx = pushSeg(tip.sx, tip.sy, p.x, p.y, tip.seg, 0);
    p.on = true;
    const path: number[] = [];
    let i = idx;
    while (i >= 0) {
      path.push(i);
      i = segs[i].p;
    }
    routes.push([...path].reverse());
    const anchorsOn = patches.filter((q) => q.on).length;
    if (firstAnchor === null) firstAnchor = time;

    // Mid wow (~1:20): third anchor — whole-network pulse, brighten, 2–3 tips, soft dum.
    const isMidWow = !midWowDone && anchorsOn === 3 && !p.big;
    if (isMidWow) {
      midWowDone = true;
      midstep = time;
      const net = wholeNetworkPath(p.x, p.y);
      pulses.push({ path: net.length ? net : path, t: 0, dur: 0.85 + net.length * 0.0035 });
      networkPulse = 1;
      networkBright = 1;
      rings.push({ x: p.x, y: p.y, t: 0, big: true });
      dum(false, true);
      const k = 2 + (rnd() < 0.55 ? 1 : 0);
      const base = rnd() * Math.PI * 2;
      for (let j = 0; j < k; j++)
        addTip(p.x, p.y, base + (j * Math.PI * 2) / k + (rnd() - 0.5) * 0.5, idx);
      return;
    }

    pulses.push({ path, t: 0, dur: 0.5 + path.length * 0.012 });
    rings.push({ x: p.x, y: p.y, t: 0, big: true });
    dum(!!p.big);
    if (p.big) {
      bigAnchored = true;
      bigAnchorTime = time;
      networkPulse = 1;
      camZoomTarget = CAM_ZOOM_OUT;
      for (const s of segs) s.th = Math.min(3, s.th + 1);
    }
    const k = 1 + (rnd() < 0.6 ? 1 : 0);
    const base = rnd() * Math.PI * 2;
    for (let j = 0; j < k; j++)
      addTip(p.x, p.y, base + j * Math.PI + (rnd() - 0.5) * 0.8, idx);
  };

  const tryFusion = (t: Tip): boolean => {
    if (fusionCd > 0 || time < FUSION_MIN_T) return false;
    if (t.seg < 0) return false;
    const own = ancestors(t.seg);
    if (own.size < 3) return false;
    // Tip–tip
    for (const o of tips) {
      if (o === t) continue;
      if (o.seg < 0) continue;
      if (Math.hypot(o.x - t.x, o.y - t.y) > FUSION_R) continue;
      const oOwn = ancestors(o.seg);
      if (oOwn.size < 3) continue;
      // Same branch (one lies on the other's path) — not a loop yet
      if (own.has(o.seg) || oOwn.has(t.seg)) continue;
      const midX = (t.x + o.x) * 0.5;
      const midY = (t.y + o.y) * 0.5;
      const a = pushSeg(t.sx, t.sy, midX, midY, t.seg, 1, 1);
      const b = pushSeg(o.sx, o.sy, midX, midY, o.seg, 1, 1);
      segs[a].th = Math.min(3, segs[a].th + 1);
      segs[b].th = Math.min(3, segs[b].th + 1);
      if (t.seg >= 0) segs[t.seg].th = Math.min(3, segs[t.seg].th + 1);
      if (o.seg >= 0) segs[o.seg].th = Math.min(3, segs[o.seg].th + 1);
      pulses.push({ path: [a, b], t: 0, dur: 0.45 });
      rings.push({ x: midX, y: midY, t: 0, big: false });
      fusionCd = FUSION_COOLDOWN;
      if (firstFusion === null) firstFusion = time;
      t.seg = a;
      t.sx = midX;
      t.sy = midY;
      t.x = midX;
      t.y = midY;
      o.seg = b;
      o.sx = midX;
      o.sy = midY;
      o.x = midX;
      o.y = midY;
      const scatter = rnd() * Math.PI * 2;
      t.a = scatter;
      o.a = scatter + Math.PI + (rnd() - 0.5) * 0.4;
      return true;
    }
    // Tip–foreign segment
    for (let si = 0; si < segs.length; si++) {
      if (own.has(si)) continue;
      const s = segs[si];
      const { d, cx, cy } = distPointSeg(t.x, t.y, s.x1, s.y1, s.x2, s.y2);
      if (d > FUSION_R) continue;
      const idx = pushSeg(t.sx, t.sy, cx, cy, t.seg, 1, 1);
      s.th = Math.min(3, s.th + 1);
      segs[idx].th = Math.min(3, segs[idx].th + 1);
      if (t.seg >= 0) segs[t.seg].th = Math.min(3, segs[t.seg].th + 1);
      pulses.push({ path: [idx, si], t: 0, dur: 0.45 });
      rings.push({ x: cx, y: cy, t: 0, big: false });
      fusionCd = FUSION_COOLDOWN;
      if (firstFusion === null) firstFusion = time;
      t.seg = idx;
      t.sx = cx;
      t.sy = cy;
      t.x = cx;
      t.y = cy;
      t.a += Math.PI * 0.6 + (rnd() - 0.5) * 0.8;
      return true;
    }
    return false;
  };

  const fertility = () =>
    firstFusion !== null &&
    segs.length >= WORKER_MIN_SEGS &&
    time - firstFusion >= WORKER_DELAY;

  const targetWorkers = () => {
    const density = segs.reduce((a, s) => a + 1 + s.th, 0);
    return Math.min(MAX_WORKERS, Math.floor(density / 18));
  };

  const spawnWorker = () => {
    if (!seed || routes.length === 0) return;
    const route = routes[Math.floor(rnd() * routes.length)];
    if (route.length < 1) return;
    workers.push({
      route,
      pos: 0,
      dir: 1,
      speed: WORKER_SPEED * (0.85 + rnd() * 0.3),
    });
    if (firstWorkers === null) firstWorkers = time;
  };

  const workerPos = (w: Worker): { x: number; y: number } => {
    const n = w.route.length;
    if (n === 0 && seed) return { x: seed.x, y: seed.y };
    const f = Math.max(0, Math.min(n - 1e-6, w.pos));
    const i = Math.min(n - 1, Math.floor(f));
    const u = f - Math.floor(f);
    const s = segs[w.route[i]];
    if (!s) return seed ? { x: seed.x, y: seed.y } : { x: 0, y: 0 };
    return {
      x: s.x1 + (s.x2 - s.x1) * u,
      y: s.y1 + (s.y2 - s.y1) * u,
    };
  };

  const update = (dt: number) => {
    time += dt;
    if (fusionCd > 0) fusionCd = Math.max(0, fusionCd - dt);
    if (!dragging) {
      guideW = Math.max(0, guideW - dt * 0.08);
      holdT = 0;
      densify = false;
    } else if (seed) {
      holdT += dt;
      if (holdT >= HOLD_S) {
        densify = true;
        densifyX = hx;
        densifyY = hy;
      }
    }
    if (time >= BIG_APPEAR_T) spawnBigPatch();
    if (camZoom !== camZoomTarget) {
      const k = 1 - Math.exp(-dt / (CAM_ZOOM_DUR * 0.45));
      camZoom += (camZoomTarget - camZoom) * k;
      if (Math.abs(camZoom - camZoomTarget) < 0.001) camZoom = camZoomTarget;
    }
    networkPulse = Math.max(0, networkPulse - dt * 0.55);
    networkBright = Math.max(0, networkBright - dt * 0.35);

    const next: Tip[] = [];
    for (const t of tips) {
      if (tryFusion(t)) {
        next.push(t);
        continue;
      }
      let best: Patch | null = null;
      let bd = SENSE;
      for (const p of patches) {
        if (p.on) continue;
        const d = Math.hypot(p.x - t.x, p.y - t.y);
        const sense = p.big ? SENSE * 1.35 : SENSE;
        if (d < bd && d < sense) {
          bd = d;
          best = p;
        }
      }
      if (best && bd < best.r * 0.8) {
        anchor(t, best);
        continue;
      }
      if (best) t.a += wrap(Math.atan2(best.y - t.y, best.x - t.x) - t.a) * 1.4 * (1 - bd / SENSE) * dt;
      if (guideW > 0 && t.g) t.a += wrap(guideA - t.a) * 2.6 * guideW * dt;
      const inHold = densify && Math.hypot(t.x - densifyX, t.y - densifyY) < HOLD_R;
      if (inHold) {
        t.a += wrap(Math.atan2(densifyY - t.y, densifyX - t.x) - t.a) * HOLD_STEER * dt;
      }
      const m = 30;
      if (t.x < m || t.x > W - m || t.y < m || t.y > H - m) {
        t.a += wrap(Math.atan2(H / 2 - t.y, W / 2 - t.x) - t.a) * 2.5 * dt;
      }
      t.a += (rnd() - 0.5) * 1.2 * dt;
      const spd = SPEED * (inHold ? HOLD_SPEED_MUL : 1);
      t.x += Math.cos(t.a) * spd * dt;
      t.y += Math.sin(t.a) * spd * dt;
      const stepNeed = inHold ? STEP * 0.85 : STEP;
      if (Math.hypot(t.x - t.sx, t.y - t.sy) >= stepNeed) {
        t.seg = pushSeg(t.sx, t.sy, t.x, t.y, t.seg, 0);
        t.sx = t.x;
        t.sy = t.y;
        t.a += (rnd() - 0.5) * 0.7;
        const branchP = BRANCH_P * (inHold ? HOLD_BRANCH_MUL : 1);
        if (tips.length + next.length < MAXTIPS && rnd() < branchP) {
          const s = rnd() < 0.5 ? 1 : -1;
          next.push({
            x: t.x,
            y: t.y,
            a: t.a + s * (0.5 + rnd() * 0.4),
            seg: t.seg,
            sx: t.x,
            sy: t.y,
            g: t.g,
          });
          t.a -= s * 0.25;
        }
      }
      next.push(t);
    }
    tips = next;

    for (const p of patches) {
      if (p.on && p.lit < 1) p.lit = Math.min(1, p.lit + dt * 1.2);
    }
    for (let i = pulses.length - 1; i >= 0; i--) {
      const pu = pulses[i];
      pu.t += dt / pu.dur;
      if (pu.t >= 1) {
        for (const s of pu.path) {
          if (segs[s]) segs[s].th += 1;
        }
        seedGlow = 1;
        if (seed) rings.push({ x: seed.x, y: seed.y, t: 0, big: false });
        pulses.splice(i, 1);
      }
    }
    seedGlow = Math.max(0, seedGlow - dt * 1.5);
    for (let i = rings.length - 1; i >= 0; i--) {
      rings[i].t += dt;
      if (rings[i].t > (rings[i].big ? 1.2 : 0.6)) rings.splice(i, 1);
    }
    for (const s of segs) {
      if (s.fuseGlow && s.fuseGlow > 0) s.fuseGlow = Math.max(0, s.fuseGlow - dt * 1.4);
    }

    if (fertility() && seed) {
      const want = targetWorkers();
      if (workers.length < want && rnd() < WORKER_SPAWN_RATE * dt * 8) spawnWorker();
    }
    for (const w of workers) {
      const n = w.route.length;
      if (n < 1) continue;
      // approximate segment length ~ STEP
      w.pos += ((w.dir * w.speed) / Math.max(STEP, 1)) * dt;
      if (w.pos >= n - 0.01) {
        w.pos = n - 0.01;
        w.dir = -1;
      } else if (w.pos <= 0) {
        w.pos = 0;
        w.dir = 1;
        if (routes.length > 0 && rnd() < 0.35) {
          w.route = routes[Math.floor(rnd() * routes.length)];
        }
      }
    }
  };

  const draw = (ctx: CanvasRenderingContext2D, dpr: number) => {
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    const hi = dpr >= 1.5;
    const art = atlas && atlas.ready ? atlas : null;

    // Soil
    if (art) {
      for (let ty = 0; ty < soilRows; ty++) {
        for (let tx = 0; tx < soilCols; tx++) {
          const name = soilNames[soilTiles[ty * soilCols + tx]];
          const fr = art.frame(name, hi);
          if (!fr) continue;
          ctx.drawImage(
            art.image,
            fr.x,
            fr.y,
            fr.w,
            fr.h,
            tx * SOIL_TILE,
            ty * SOIL_TILE,
            SOIL_TILE,
            SOIL_TILE,
          );
        }
      }
      ctx.fillStyle = "rgba(12,10,8,0.28)";
      ctx.fillRect(0, 0, W, H);
    } else {
      ctx.fillStyle = "#242424";
      ctx.fillRect(0, 0, W, H);
    }

    const cx = seed ? seed.x : W / 2;
    const cy = seed ? seed.y : H / 2;
    ctx.save();
    ctx.translate(W / 2, H / 2);
    ctx.scale(camZoom, camZoom);
    ctx.translate(-cx, -cy);

    for (const s of specks) {
      ctx.fillStyle = `rgba(255,255,255,${s.a})`;
      ctx.beginPath();
      ctx.arc(s.x, s.y, s.r, 0, Math.PI * 2);
      ctx.fill();
    }

    const bright = 1 + networkBright * 0.55;

    // Patches — skvrna / kotva
    for (const p of patches) {
      const breath = 0.5 + 0.5 * Math.sin(time * 1.3 + p.ph);
      if (art) {
        const name = p.on ? "kotva" : "skvrna";
        const fr = art.frame(name, hi);
        if (fr) {
          const base = p.big ? 1.55 : 0.95;
          const sc = base * (1 + p.lit * 0.25 + breath * 0.06) * (p.big ? 1.1 : 1);
          const alpha = p.on ? 0.95 : 0.55 + 0.25 * breath + p.lit * 0.3;
          drawCentered(ctx, art, fr, p.x, p.y, {
            scale: sc,
            alpha: Math.min(1, alpha * bright),
            rot: p.ph * 0.15,
          });
        }
      } else {
        const rr = p.r * (1.7 + p.lit * 0.9) * (p.big ? 1.15 : 1);
        const g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, rr);
        const base = (p.big ? 0.18 : 0.13) + 0.03 * breath;
        const lit = p.lit * (0.55 + 0.1 * breath);
        const c = p.big ? Math.round(90 + 80 * p.lit) : Math.round(110 + 110 * p.lit);
        const cg = p.big ? Math.round(100 + 90 * p.lit) : c;
        const cb = p.big ? Math.round(120 + 100 * p.lit) : c;
        g.addColorStop(0, `rgba(${c},${cg},${cb},${base + lit})`);
        g.addColorStop(0.45, `rgba(${c},${cg},${cb},${(base + lit) * 0.6})`);
        g.addColorStop(1, "rgba(120,120,120,0)");
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.arc(p.x, p.y, rr, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    // Hyphae — compose seg a/b; thickness by density
    if (art) {
      const frA = art.frame("hyfa_seg_a", hi);
      const frB = art.frame("hyfa_seg_b", hi);
      const tipFr = art.frame("hyfa_tip", hi);
      const segAlpha = Math.min(1, 0.82 * bright);
      for (const s of segs) {
        const fr = (s.v === 0 ? frA : frB) ?? frA ?? frB;
        if (!fr) continue;
        const th = SEG_TH[Math.min(3, s.th)] * (1 + networkBright * 0.12);
        drawSegSprite(ctx, art, fr, s.x1, s.y1, s.x2, s.y2, th, segAlpha);
      }
      for (const t of tips) {
        const fr = (Math.floor(t.x + t.y) % 2 === 0 ? frA : frB) ?? frA;
        if (fr) {
          drawSegSprite(ctx, art, fr, t.sx, t.sy, t.x, t.y, SEG_TH[0], segAlpha);
        }
        if (tipFr) {
          drawTipSprite(ctx, art, tipFr, t.x, t.y, t.a, 0.42, Math.min(1, 0.95 * bright));
        }
      }
    } else {
      const widths = [1, 1.7, 2.4, 3.2];
      ctx.lineCap = "round";
      ctx.strokeStyle = `rgba(205,205,205,${0.78 * bright})`;
      for (let b = 0; b < 4; b++) {
        ctx.lineWidth = widths[b];
        ctx.beginPath();
        for (const s of segs) {
          if (Math.min(3, s.th) !== b) continue;
          ctx.moveTo(s.x1, s.y1);
          ctx.lineTo(s.x2, s.y2);
        }
        if (b === 0) {
          for (const t of tips) {
            ctx.moveTo(t.sx, t.sy);
            ctx.lineTo(t.x, t.y);
          }
        }
        ctx.stroke();
      }
      ctx.fillStyle = "rgba(235,235,235,0.9)";
      for (const t of tips) {
        ctx.beginPath();
        ctx.arc(t.x, t.y, 1.6, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    // Fusion glow
    for (const s of segs) {
      if (!s.fuseGlow || s.fuseGlow <= 0) continue;
      ctx.strokeStyle = `rgba(255,255,255,${0.85 * s.fuseGlow})`;
      ctx.lineWidth = 3.2;
      ctx.beginPath();
      ctx.moveTo(s.x1, s.y1);
      ctx.lineTo(s.x2, s.y2);
      ctx.stroke();
    }
    if (networkPulse > 0) {
      ctx.strokeStyle = `rgba(255,255,255,${0.35 * networkPulse})`;
      ctx.lineWidth = 2.2;
      ctx.beginPath();
      for (const s of segs) {
        ctx.moveTo(s.x1, s.y1);
        ctx.lineTo(s.x2, s.y2);
      }
      ctx.stroke();
    }

    for (const pu of pulses) {
      const len = pu.path.length;
      if (len < 1) continue;
      const head = Math.min(len - 1, Math.floor(pu.t * len));
      ctx.lineWidth = 2.6;
      const trail = Math.min(14, Math.max(8, Math.floor(len * 0.04) + 6));
      for (let k = 0; k < trail; k++) {
        const i = head - k;
        if (i < 0) break;
        const s = segs[pu.path[i]];
        if (!s) continue;
        ctx.strokeStyle = `rgba(255,255,255,${0.9 * (1 - k / trail)})`;
        ctx.beginPath();
        ctx.moveTo(s.x1, s.y1);
        ctx.lineTo(s.x2, s.y2);
        ctx.stroke();
      }
      const hs = segs[pu.path[head]];
      if (hs) {
        const g = ctx.createRadialGradient(hs.x1, hs.y1, 0, hs.x1, hs.y1, 10);
        g.addColorStop(0, "rgba(255,255,255,0.9)");
        g.addColorStop(1, "rgba(255,255,255,0)");
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.arc(hs.x1, hs.y1, 10, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    // Workers
    if (art) {
      const wFr = art.frame("delnik", hi);
      for (const w of workers) {
        const { x, y } = workerPos(w);
        if (!wFr) continue;
        const n = w.route.length;
        let ang = 0;
        if (n > 0) {
          const i = Math.min(n - 1, Math.floor(Math.max(0, w.pos)));
          const s = segs[w.route[i]];
          if (s) ang = Math.atan2(s.y2 - s.y1, s.x2 - s.x1) + (w.dir < 0 ? Math.PI : 0);
        }
        drawCentered(ctx, art, wFr, x, y, { rot: ang, scale: 0.55, alpha: 0.92 });
      }
    } else {
      ctx.fillStyle = "rgba(230,230,230,0.92)";
      for (const w of workers) {
        const { x, y } = workerPos(w);
        ctx.beginPath();
        ctx.arc(x, y, 1.35, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    if (seed) {
      if (art) {
        const fr = art.frame("zarodek", hi);
        if (fr) {
          const sc = 0.55 + Math.sin(time * 2) * 0.03 + seedGlow * 0.2;
          drawCentered(ctx, art, fr, seed.x, seed.y, {
            scale: sc,
            alpha: Math.min(1, 0.9 + seedGlow * 0.1),
            rot: Math.sin(time * 0.7) * 0.08,
          });
        }
        const g = ctx.createRadialGradient(
          seed.x,
          seed.y,
          0,
          seed.x,
          seed.y,
          28 + seedGlow * 18,
        );
        g.addColorStop(0, `rgba(230,220,200,${0.2 + seedGlow * 0.35})`);
        g.addColorStop(1, "rgba(230,220,200,0)");
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.arc(seed.x, seed.y, 28 + seedGlow * 18, 0, Math.PI * 2);
        ctx.fill();
      } else {
        const r = 6 + Math.sin(time * 2) * 0.6 + seedGlow * 3;
        const g = ctx.createRadialGradient(seed.x, seed.y, 0, seed.x, seed.y, r * 3);
        g.addColorStop(0, `rgba(230,230,230,${0.35 + seedGlow * 0.4})`);
        g.addColorStop(1, "rgba(230,230,230,0)");
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.arc(seed.x, seed.y, r * 3, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = "#d8d8d8";
        ctx.beginPath();
        ctx.arc(seed.x, seed.y, r, 0, Math.PI * 2);
        ctx.fill();
      }
    } else {
      const x = hovering ? hx : W / 2;
      const y = hovering ? hy : H / 2;
      const ph = (time % 1.8) / 1.8;
      ctx.strokeStyle = `rgba(220,220,220,${0.45 * (1 - ph)})`;
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.arc(x, y, 6 + ph * 22, 0, Math.PI * 2);
      ctx.stroke();
      ctx.fillStyle = "rgba(220,220,220,0.35)";
      ctx.beginPath();
      ctx.arc(x, y, 4, 0, Math.PI * 2);
      ctx.fill();
    }
    if (dragging && seed && guideW > 0) {
      ctx.strokeStyle = "rgba(220,220,220,0.18)";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(dsx, dsy);
      ctx.lineTo(hx, hy);
      ctx.stroke();
    }
    for (const r of rings) {
      const life = r.big ? 1.2 : 0.6;
      const k = r.t / life;
      ctx.strokeStyle = `rgba(240,240,240,${0.6 * (1 - k)})`;
      ctx.lineWidth = r.big ? 2 : 1.5;
      ctx.beginPath();
      ctx.arc(r.x, r.y, (r.big ? 10 : 5) + k * (r.big ? 50 : 26), 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();
  };

  const metrics = (): SimMetrics => ({
    time,
    segs: segs.length,
    tips: tips.length,
    anchors: patches.filter((p) => p.on).length,
    workers: workers.length,
    firstAnchor,
    midstep,
    firstFusion,
    firstWorkers,
    bigAnchored,
    bigAnchorTime,
  });

  const snapshot = (): WorldSnapshot => ({
    tips: tips.map((t) => ({ x: t.x, y: t.y })),
    patches: patches.map((p) => ({ x: p.x, y: p.y, on: p.on, big: p.big })),
    seed: seed ? { x: seed.x, y: seed.y } : null,
  });

  const stressFill = (segCount: number, workerCount: number) => {
    if (!seed) plantSeed(W / 2, H / 2);
    while (segs.length < segCount) {
      const x1 = rnd() * W;
      const y1 = rnd() * H;
      const a = rnd() * Math.PI * 2;
      const x2 = x1 + Math.cos(a) * STEP;
      const y2 = y1 + Math.sin(a) * STEP;
      const p = segs.length > 0 ? Math.floor(rnd() * segs.length) : -1;
      pushSeg(x1, y1, x2, y2, p, Math.floor(rnd() * 3));
    }
    if (routes.length === 0) {
      const path: number[] = [];
      for (let i = 0; i < Math.min(40, segs.length); i++) path.push(i);
      routes.push(path);
    }
    while (workers.length < workerCount) {
      workers.push({
        route: routes[0],
        pos: rnd() * Math.max(1, routes[0].length - 1),
        dir: rnd() < 0.5 ? 1 : -1,
        speed: WORKER_SPEED,
      });
    }
    if (firstWorkers === null && workers.length > 0) firstWorkers = time;
  };

  const setAtlas = (a: MycAtlas) => {
    atlas = a;
  };

  return {
    update,
    draw,
    pointerDown,
    pointerMove,
    pointerUp,
    metrics,
    snapshot,
    stressFill,
    setAtlas,
  };
}

/** Mount mycelium sim on a canvas. Returns cleanup. */
export function startMycelium(cv: HTMLCanvasElement): () => void {
  const world = createMyceliumWorld();
  void loadMyceliumAtlas().then((a) => world.setAtlas(a));
  return mountCanvas(cv, world, W, H);
}
