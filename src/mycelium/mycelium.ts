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
  START5_T,
  ENC_MIN_LEN,
  ENC_CLOSE_R,
  ENC_MIN_PTS,
  MATTER_R_MACHINE,
  MATTER_R_BEETLE,
  MATTER_SLIDE_R,
  SPORE_GERMS,
  JOIN_PULSE_PERIOD,
  HINT_DUR,
} from "./config";
import { playDum, playSoft } from "./sound";
import {
  loadMyceliumAtlas,
  drawCentered,
  drawSegSprite,
  drawTipSprite,
  type MycAtlas,
} from "./atlas";
import type {
  Seg,
  Tip,
  Patch,
  Pulse,
  Ring,
  Speck,
  Worker,
  SimMetrics,
  Matter,
  Germ,
} from "./types";
import {
  mountCanvas,
  drawGuidePulse,
  drawGhostHand,
  IDLE_GHOST_S,
  MAX_GHOST_PERFORMS,
  pathLength,
  pointInPoly,
  smoothResample,
  encircleRecognized,
  snapRadius,
  nearestTarget,
  spawnMiss,
  tickMiss,
  drawMissFx,
  TRAIL_FINISH_PX,
  type DemoControls,
  type GuidanceInfo,
  type WowEvent,
  type PointerMeta,
  type MissFx,
  type Pt,
} from "../core";

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
  /** Fast-forward / bootstrap to ~4:40 midgame (?start=5). */
  startAt?: number;
};

export type WorldSnapshot = {
  tips: { x: number; y: number }[];
  patches: { x: number; y: number; on: boolean; big?: boolean }[];
  seed: { x: number; y: number } | null;
  matters: { x: number; y: number; r: number; kind: string; decay: number }[];
  germs: { x: number; y: number; linked: boolean }[];
  fruits: { x: number; y: number }[];
};

export type MyceliumWorld = {
  update: (dt: number) => void;
  draw: (ctx: CanvasRenderingContext2D, dpr: number) => void;
  pointerDown: (x: number, y: number, meta?: PointerMeta) => void;
  pointerMove: (x: number, y: number, meta?: PointerMeta) => void;
  pointerUp: (meta?: PointerMeta) => void;
  metrics: () => SimMetrics;
  snapshot: () => WorldSnapshot;
  /** Stress-fill network for FPS measurement. */
  stressFill: (segCount: number, workerCount: number) => void;
  setAtlas: (atlas: MycAtlas) => void;
  /** Bootstrap post–big-anchor state at ~4:40. */
  bootstrapStart5: () => void;
  guidance: () => GuidanceInfo;
  pollWows: () => WowEvent[];
  notePointer: () => void;
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

  /** Build #5 midgame. */
  const matters: Matter[] = [];
  const germs: Germ[] = [];
  const grains: { x: number; y: number; vx: number; vy: number; life: number }[] = [];
  const spores: { x: number; y: number; vx: number; vy: number; life: number }[] = [];
  let stroke: Pt[] = [];
  let strokeActive = false;
  let strokeCatch: Matter | Germ | null = null;
  let pointerMeta: PointerMeta = { dpr: 1, touch: false };
  const missFx: MissFx[] = [];
  let snapHover: { x: number; y: number; kind: "germ" | "tip" | "patch" } | null = null;
  let mattersSpawned = false;
  let decayTime: number | null = null;
  let fruitTime: number | null = null;
  let sporeTime: number | null = null;
  let joinTime: number | null = null;
  let hintTime: number | null = null;
  let heartBeat = 0;
  let heartPhase = 0;
  let foreignNet = 0;
  let foreignSeed: { x: number; y: number } | null = null;
  let decayCount = 0;

  /** Guidance / demo. */
  let idleT = 0;
  let showGhost = false;
  const stepPerforms = new Map<string, number>();
  const emittedWows = new Set<string>();
  const wowQueue: WowEvent[] = [];
  let prevAnchors = 0;
  let prevDensify = false;

  const bumpPerform = (stepId: string) => {
    stepPerforms.set(stepId, (stepPerforms.get(stepId) ?? 0) + 1);
  };

  const canGhost = (stepId: string) => (stepPerforms.get(stepId) ?? 0) < MAX_GHOST_PERFORMS;

  const emitWow = (id: string, label: string, t: number | null) => {
    if (t === null || emittedWows.has(id)) return;
    emittedWows.add(id);
    wowQueue.push({ id, label, time: t });
  };

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

  const soft = (kind: "bubble" | "puff" | "rain" | "beat" | "hiss") => {
    if (!silent) playSoft(kind);
  };

  const spawnMatters = () => {
    if (mattersSpawned || !seed) return;
    mattersSpawned = true;
    const corners: [number, number][] = [
      [BIG_EDGE + 40, BIG_EDGE + 50],
      [W - BIG_EDGE - 40, BIG_EDGE + 50],
      [BIG_EDGE + 50, H - BIG_EDGE - 40],
      [W - BIG_EDGE - 50, H - BIG_EDGE - 40],
    ];
    // Prefer corners away from seed and big patch
    const big = patches.find((p) => p.big);
    const scored = corners
      .map((c) => {
        let d = Math.hypot(c[0] - seed!.x, c[1] - seed!.y);
        if (big) d += Math.hypot(c[0] - big.x, c[1] - big.y) * 0.4;
        return { c, d };
      })
      .sort((a, b) => b.d - a.d);
    const m1 = scored[0]!.c;
    const m2 = scored[1]!.c;
    matters.push({
      x: m1[0],
      y: m1[1],
      r: MATTER_R_MACHINE,
      kind: "machine",
      decay: 0,
      encircled: false,
      ph: rnd() * 6,
    });
    matters.push({
      x: m2[0],
      y: m2[1],
      r: MATTER_R_BEETLE,
      kind: "beetle",
      decay: 0,
      encircled: false,
      ph: rnd() * 6,
    });
  };

  const spawnFruitAt = (x: number, y: number) => {
    matters.push({
      x,
      y: y - 8,
      r: 22,
      kind: "fruit",
      decay: 0,
      encircled: false,
      ph: rnd() * 6,
    });
  };

  const triggerDecay = (m: Matter) => {
    if (m.encircled || m.kind === "fruit") return;
    m.encircled = true;
    decayCount++;
    if (decayTime === null) {
      decayTime = time;
      soft("bubble");
      dum(true);
    }
    // Glow grains toward seed
    if (seed) {
      for (let i = 0; i < 18; i++) {
        const a = rnd() * Math.PI * 2;
        grains.push({
          x: m.x + Math.cos(a) * m.r * 0.4,
          y: m.y + Math.sin(a) * m.r * 0.4,
          vx: (seed.x - m.x) * (0.15 + rnd() * 0.25),
          vy: (seed.y - m.y) * (0.15 + rnd() * 0.25),
          life: 1.2 + rnd() * 0.8,
        });
      }
    }
    // Thicken nearby segs
    for (const s of segs) {
      const mx = (s.x1 + s.x2) * 0.5;
      const my = (s.y1 + s.y2) * 0.5;
      if (Math.hypot(mx - m.x, my - m.y) < m.r * 2.2) s.th = Math.min(3, s.th + 1);
    }
    rings.push({ x: m.x, y: m.y, t: 0, big: true });
    networkBright = 1;
  };

  const triggerFruit = (m: Matter) => {
    if (m.encircled || m.kind === "fruit") return;
    triggerDecay(m);
    // Fruiting body at first decay site
    const site = matters.find((x) => x.kind !== "fruit" && x.encircled) ?? m;
    if (!matters.some((x) => x.kind === "fruit")) {
      spawnFruitAt(site.x, site.y);
    }
    // Second fruit near this decay if beetle
    if (m.kind === "beetle" && matters.filter((x) => x.kind === "fruit").length < 2) {
      spawnFruitAt(m.x + (rnd() - 0.5) * 30, m.y + (rnd() - 0.5) * 30);
    }
    if (fruitTime === null) {
      fruitTime = time;
      soft("puff");
      // Thicken network + more workers density via seg thickness
      for (const s of segs) {
        if (rnd() < 0.35) s.th = Math.min(3, s.th + 1);
      }
    }
  };

  const triggerSpore = () => {
    if (sporeTime !== null) return;
    const fruits = matters.filter((m) => m.kind === "fruit");
    if (fruits.length < 1) return;
    sporeTime = time;
    soft("rain");
    for (const f of fruits) {
      for (let i = 0; i < 22; i++) {
        const a = rnd() * Math.PI * 2;
        spores.push({
          x: f.x,
          y: f.y,
          vx: Math.cos(a) * (20 + rnd() * 60),
          vy: Math.sin(a) * (20 + rnd() * 60),
          life: 1.5 + rnd(),
        });
      }
      f.encircled = true;
    }
    // New germs far from network
    const cx0 = seed?.x ?? W / 2;
    const cy0 = seed?.y ?? H / 2;
    for (let i = 0; i < SPORE_GERMS; i++) {
      let gx = 0;
      let gy = 0;
      for (let t = 0; t < 40; t++) {
        const a = rnd() * Math.PI * 2;
        const d = 180 + rnd() * 160;
        gx = cx0 + Math.cos(a) * d;
        gy = cy0 + Math.sin(a) * d * 0.85;
        if (gx > 50 && gx < W - 50 && gy > 50 && gy < H - 50) break;
      }
      germs.push({ x: gx, y: gy, lit: 0, linked: false });
    }
    rings.push({ x: fruits[0]!.x, y: fruits[0]!.y, t: 0, big: true });
  };

  const triggerJoin = () => {
    if (joinTime !== null || germs.length === 0 || !seed) return;
    joinTime = time;
    soft("beat");
    heartBeat = 1;
    networkPulse = 1;
    networkBright = 1;
    for (const g of germs) {
      g.linked = true;
      g.lit = 1;
      // Grow hyphae path toward germ (simplified spine)
      let x = seed.x;
      let y = seed.y;
      let prev = -1;
      const steps = 8 + Math.floor(rnd() * 4);
      for (let i = 1; i <= steps; i++) {
        const t = i / steps;
        const nx = seed.x + (g.x - seed.x) * t + (rnd() - 0.5) * 18;
        const ny = seed.y + (g.y - seed.y) * t + (rnd() - 0.5) * 18;
        prev = pushSeg(x, y, nx, ny, prev, i > steps - 2 ? 2 : 1);
        x = nx;
        y = ny;
      }
      addTip(g.x, g.y, rnd() * Math.PI * 2, prev);
    }
    const net = wholeNetworkPath(seed.x, seed.y);
    pulses.push({ path: net, t: 0, dur: 1.2 + net.length * 0.002 });
  };

  const triggerHint = () => {
    if (hintTime !== null) return;
    hintTime = time;
    soft("hiss");
    foreignNet = 1;
    const cx0 = seed?.x ?? W / 2;
    const cy0 = seed?.y ?? H / 2;
    // Opposite far edge
    foreignSeed = {
      x: cx0 < W / 2 ? W - 70 : 70,
      y: cy0 < H / 2 ? H - 60 : 60,
    };
  };

  const shapeOfMatter = (m: Matter) => ({
    x: m.x,
    y: m.y,
    rx: m.r * (m.kind === "beetle" ? 1.05 : 0.85),
    ry: m.r * (m.kind === "beetle" ? 0.7 : 0.55),
  });

  const updateStrokeCatch = () => {
    strokeCatch = null;
    if (!strokeActive || stroke.length < 4) return;
    const poly = smoothResample(stroke);
    const candidates: (Matter | Germ)[] = [
      ...matters.filter((m) => !m.encircled),
      ...germs.filter((g) => !g.linked),
    ];
    let best: Matter | Germ | null = null;
    let score = 0;
    for (const c of candidates) {
      const r = "r" in c ? c.r : 14;
      const rec = encircleRecognized(poly, { x: c.x, y: c.y, rx: r, ry: r * 0.75 }, {
        minLen: ENC_MIN_LEN * 0.55,
        minPts: 6,
        closePx: ENC_CLOSE_R,
      });
      const s = rec.ok ? 1 : pointInPoly(c.x, c.y, poly) ? 0.7 : 0;
      if (s > score) {
        score = s;
        best = c;
      }
    }
    if (score >= 0.55) strokeCatch = best;
  };

  const tryEncircle = (): boolean => {
    if (!bigAnchored || stroke.length < ENC_MIN_PTS) return false;
    const poly = smoothResample(stroke);
    if (pathLength(poly) < ENC_MIN_LEN) return false;
    stroke = poly;

    const intact = matters.filter((m) => m.kind !== "fruit" && !m.encircled);
    const fruits = matters.filter((m) => m.kind === "fruit" && !m.encircled);
    const last = poly[poly.length - 1]!;

    // Spore: encircle covering ≥2 fruits (or 1 fruit + loop large)
    if (sporeTime === null && fruits.length >= 1 && decayCount >= 2) {
      const covered = fruits.filter((f) => {
        const rec = encircleRecognized(poly, { x: f.x, y: f.y, rx: f.r, ry: f.r * 0.7 }, {
          minLen: ENC_MIN_LEN * 0.7,
          minPts: ENC_MIN_PTS,
          closePx: ENC_CLOSE_R,
        });
        return rec.ok;
      });
      if (
        covered.length >= Math.min(2, fruits.length) ||
        (fruits.length >= 2 && covered.length >= 1 && pathLength(poly) > ENC_MIN_LEN * 1.4)
      ) {
        triggerSpore();
        return true;
      }
    }

    // Fruit wow / first decay via center-in-poly OR ≥50% outline
    const tryMatter = (list: Matter[], onHit: (m: Matter) => void): boolean => {
      for (const m of list) {
        const rec = encircleRecognized(poly, shapeOfMatter(m), {
          minLen: ENC_MIN_LEN,
          minPts: ENC_MIN_PTS,
          closePx: ENC_CLOSE_R,
        });
        if (rec.ok) {
          onHit(m);
          return true;
        }
      }
      return false;
    };

    if (fruitTime === null && decayCount >= 1) {
      if (tryMatter(intact, (m) => triggerFruit(m))) return true;
    }

    if (decayTime === null || intact.length) {
      if (
        tryMatter(intact, (m) => {
          if (decayTime === null) triggerDecay(m);
          else triggerFruit(m);
        })
      ) {
        return true;
      }
    }

    // Join: encircle or magnetic connect near unlinked germs after spore
    if (sporeTime !== null && joinTime === null) {
      const unlinked = germs.filter((g) => !g.linked);
      const snap = snapRadius(pointerMeta);
      if (
        unlinked.length &&
        unlinked.every((g) => {
          const rec = encircleRecognized(poly, { x: g.x, y: g.y, rx: 16, ry: 14 }, {
            minLen: ENC_MIN_LEN * 0.7,
            minPts: 8,
            closePx: ENC_CLOSE_R,
          });
          return (
            rec.ok ||
            pointInPoly(g.x, g.y, poly) ||
            poly.some((p) => Math.hypot(p.x - g.x, p.y - g.y) < 50)
          );
        })
      ) {
        triggerJoin();
        return true;
      }
      if (
        unlinked.some((g) => Math.hypot(last.x - g.x, last.y - g.y) < Math.max(TRAIL_FINISH_PX, snap)) &&
        pathLength(poly) > ENC_MIN_LEN * 0.8
      ) {
        triggerJoin();
        return true;
      }
    }
    return false;
  };

  const resolveConnectSnap = (
    x: number,
    y: number,
  ): { x: number; y: number; kind: "germ" | "tip" | "patch"; germ?: Germ } | null => {
    const snap = snapRadius(pointerMeta);
    const unlinked = germs.filter((g) => !g.linked).map((g) => ({ x: g.x, y: g.y, germ: g }));
    const tipPts = tips.map((t) => ({ x: t.x, y: t.y }));
    const patchPts = patches.filter((p) => !p.on).map((p) => ({ x: p.x, y: p.y }));

    const gHit = nearestTarget(x, y, unlinked, snap);
    if (gHit) return { x: gHit.target.x, y: gHit.target.y, kind: "germ", germ: gHit.target.germ };

    const tHit = nearestTarget(x, y, tipPts, snap);
    if (tHit) return { x: tHit.target.x, y: tHit.target.y, kind: "tip" };

    const pHit = nearestTarget(x, y, patchPts, snap);
    if (pHit) return { x: pHit.target.x, y: pHit.target.y, kind: "patch" };

    return null;
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

  const notePointer = () => {
    idleT = 0;
    showGhost = false;
  };

  const guidance = (): GuidanceInfo => {
    const tip = tips[0] ?? (seed ? { x: seed.x, y: seed.y } : { x: W / 2, y: H / 2 });
    const unlit = patches.filter((p) => !p.on && !p.big);
    const nearest = unlit.length
      ? unlit.reduce((b, p) =>
          Math.hypot(p.x - tip.x, p.y - tip.y) < Math.hypot(b.x - tip.x, b.y - tip.y) ? p : b,
        )
      : null;
    const big = patches.find((p) => p.big && !p.on);
    const machine = matters.find((m) => m.kind === "machine" && !m.encircled);
    const beetle = matters.find((m) => m.kind === "beetle" && !m.encircled);
    const fruits = matters.filter((m) => m.kind === "fruit");
    const germ = germs.find((g) => !g.linked);

    if (!seed) {
      return {
        stepId: "plant",
        label: "Klepni — zasaď zárodek",
        target: { x: hovering ? hx : W / 2, y: hovering ? hy : H / 2, r: 18 },
        target2: null,
        ghost: "tap",
        from: null,
        to: { x: W / 2, y: H / 2, r: 18 },
      };
    }
    if (firstAnchor === null) {
      const t = nearest ?? { x: tip.x + 80, y: tip.y, r: 20 };
      return {
        stepId: "anchor1",
        label: "Táhni hyfy ke skvrně",
        target: { x: t.x, y: t.y, r: t.r ?? 20 },
        target2: null,
        ghost: "drag",
        from: { x: tip.x, y: tip.y, r: 8 },
        to: { x: t.x, y: t.y, r: t.r ?? 20 },
      };
    }
    if ((midstep === null && patches.filter((p) => p.on && !p.big).length < 3) || midstep === null) {
      if (nearest && patches.filter((p) => p.on && !p.big).length < 3) {
        return {
          stepId: "anchors",
          label: "Kotvi další skvrny",
          target: { x: nearest.x, y: nearest.y, r: nearest.r },
          target2: null,
          ghost: "drag",
          from: { x: tip.x, y: tip.y, r: 8 },
          to: { x: nearest.x, y: nearest.y, r: nearest.r },
        };
      }
    }
    if (firstFusion === null) {
      return {
        stepId: "fuse",
        label: "Spoj hyfy do smyčky",
        target: tips[0] ? { x: tips[0].x, y: tips[0].y, r: 16 } : null,
        target2: tips[1] ? { x: tips[1].x, y: tips[1].y, r: 16 } : null,
        ghost: "drag",
        from: tips[0] ? { x: tips[0].x, y: tips[0].y, r: 8 } : null,
        to: tips[1]
          ? { x: tips[1].x, y: tips[1].y, r: 8 }
          : seed
            ? { x: seed.x + 60, y: seed.y, r: 8 }
            : null,
      };
    }
    if (firstWorkers === null) {
      const hx0 = tips[0]?.x ?? seed.x;
      const hy0 = tips[0]?.y ?? seed.y;
      return {
        stepId: "hold",
        label: "Podrž — zahušť síť",
        target: { x: hx0, y: hy0, r: 28 },
        target2: null,
        ghost: "hold",
        from: null,
        to: { x: hx0, y: hy0, r: 28 },
      };
    }
    if (!bigAnchored) {
      const t = big ?? nearest;
      if (t) {
        return {
          stepId: "big",
          label: "Dosáhni velké skvrny",
          target: { x: t.x, y: t.y, r: t.r },
          target2: null,
          ghost: "drag",
          from: { x: tip.x, y: tip.y, r: 8 },
          to: { x: t.x, y: t.y, r: t.r },
        };
      }
    }
    if (decayTime === null && machine) {
      return {
        stepId: "decay",
        label: "Zakroužkuj stroj",
        target: { x: machine.x, y: machine.y, r: machine.r },
        target2: null,
        ghost: "encircle",
        from: null,
        to: { x: machine.x, y: machine.y, r: machine.r },
      };
    }
    if (fruitTime === null && beetle) {
      return {
        stepId: "fruit",
        label: "Zakroužkuj brouka",
        target: { x: beetle.x, y: beetle.y, r: beetle.r },
        target2: null,
        ghost: "encircle",
        from: null,
        to: { x: beetle.x, y: beetle.y, r: beetle.r },
      };
    }
    if (sporeTime === null && fruits.length) {
      const mx = fruits.reduce((s, f) => s + f.x, 0) / fruits.length;
      const my = fruits.reduce((s, f) => s + f.y, 0) / fruits.length;
      return {
        stepId: "spore",
        label: "Zakroužkuj plodnice",
        target: { x: fruits[0]!.x, y: fruits[0]!.y, r: fruits[0]!.r },
        target2: fruits[1] ? { x: fruits[1].x, y: fruits[1].y, r: fruits[1].r } : null,
        ghost: "encircle",
        from: null,
        to: { x: mx, y: my, r: 50 },
      };
    }
    if (joinTime === null && germ) {
      return {
        stepId: "join",
        label: "Doveď síť k zárodkům",
        target: { x: germ.x, y: germ.y, r: 16 },
        target2: null,
        ghost: "drag",
        from: { x: tip.x, y: tip.y, r: 8 },
        to: { x: germ.x, y: germ.y, r: 16 },
      };
    }
    return {
      stepId: "watch",
      label: hintTime ? "Sleduj okraj tmy" : "Sleduj síť",
      target: foreignSeed ? { x: foreignSeed.x, y: foreignSeed.y, r: 24 } : null,
      target2: null,
      ghost: null,
      from: null,
      to: null,
    };
  };

  const pollWows = (): WowEvent[] => {
    emitWow("anchor", "První kotva", firstAnchor);
    emitWow("midstep", "Třetí kotva", midstep);
    emitWow("fusion", "Fúze", firstFusion);
    emitWow("workers", "Cvrkot", firstWorkers);
    emitWow("big", "Velká kotva", bigAnchorTime);
    emitWow("decay", "Obrůstání", decayTime);
    emitWow("fruit", "Plodnice", fruitTime);
    emitWow("spore", "Výtrusný déšť", sporeTime);
    emitWow("join", "Spojení sítí", joinTime);
    emitWow("hint", "Cizí síť", hintTime);
    if (!wowQueue.length) return [];
    return wowQueue.splice(0, wowQueue.length);
  };

  const pointerDown = (x: number, y: number, meta?: PointerMeta) => {
    if (meta) pointerMeta = meta;
    if (!seed) {
      plantSeed(x, y);
      bumpPerform("plant");
    }
    dragging = true;
    holdT = 0;
    densify = false;
    dsx = x;
    dsy = y;
    hx = x;
    hy = y;
    guideW = 0;
    strokeCatch = null;
    snapHover = null;
    const snap = snapRadius(pointerMeta);
    for (const t of tips) t.g = Math.hypot(t.x - x, t.y - y) < Math.max(GUIDE_R, snap * 3);
    if (bigAnchored) {
      stroke = [{ x, y }];
      strokeActive = true;
    }
  };

  const pointerMove = (x: number, y: number, meta?: PointerMeta) => {
    if (meta) pointerMeta = meta;
    let px = x;
    let py = y;
    const snap = resolveConnectSnap(x, y);
    snapHover = snap ? { x: snap.x, y: snap.y, kind: snap.kind } : null;
    // Magnetic pull toward valid connect target while dragging
    if (dragging && snap && Math.hypot(x - snap.x, y - snap.y) < snapRadius(pointerMeta)) {
      const k = 0.55;
      px = x + (snap.x - x) * k;
      py = y + (snap.y - y) * k;
    }
    hx = px;
    hy = py;
    hovering = true;
    if (!dragging || !seed) return;
    const dx = px - dsx;
    const dy = py - dsy;
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
    if (strokeActive) {
      const last = stroke[stroke.length - 1];
      if (!last || Math.hypot(px - last.x, py - last.y) > 6) {
        stroke.push({ x: px, y: py });
        updateStrokeCatch();
        // Auto-close when near start after enough length
        if (
          stroke.length >= ENC_MIN_PTS &&
          pathLength(stroke) >= ENC_MIN_LEN &&
          Math.hypot(px - stroke[0]!.x, py - stroke[0]!.y) < ENC_CLOSE_R
        ) {
          const ok = tryEncircle();
          if (!ok) missFx.push(spawnMiss(px, py));
          stroke = [];
          strokeActive = false;
          strokeCatch = null;
        }
      }
    }
  };

  const pointerUp = (meta?: PointerMeta) => {
    if (meta) pointerMeta = meta;
    let did = false;
    if (strokeActive && stroke.length >= ENC_MIN_PTS) {
      // Soft-close: if near enough, snap end to start
      const first = stroke[0]!;
      const last = stroke[stroke.length - 1]!;
      if (Math.hypot(last.x - first.x, last.y - first.y) < ENC_CLOSE_R) {
        stroke.push({ x: first.x, y: first.y });
      }
      did = tryEncircle();
      if (!did && pathLength(stroke) >= ENC_MIN_LEN * 0.6) {
        missFx.push(spawnMiss(hx, hy));
      }
    }
    // Join by magnetic connect toward germs (after spore)
    if (!did && bigAnchored && sporeTime !== null && joinTime === null && seed) {
      const snap = resolveConnectSnap(hx, hy);
      const finish = Math.max(TRAIL_FINISH_PX, snapRadius(pointerMeta));
      const unlinked = germs.filter((g) => !g.linked);
      if (
        (snap?.kind === "germ" && snap.germ) ||
        unlinked.some((g) => Math.hypot(hx - g.x, hy - g.y) < finish)
      ) {
        triggerJoin();
        did = true;
      } else if (dragging && Math.hypot(hx - dsx, hy - dsy) > 40 && unlinked.length) {
        missFx.push(spawnMiss(hx, hy));
      }
    }
    stroke = [];
    strokeActive = false;
    strokeCatch = null;
    snapHover = null;
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
    idleT += dt;
    tickMiss(missFx, dt);
    if (idleT >= IDLE_GHOST_S) showGhost = true;
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
        if (!prevDensify) bumpPerform("hold");
      }
    }
    prevDensify = densify;
    const anchorsNow = patches.filter((p) => p.on).length;
    if (anchorsNow > prevAnchors) {
      if (prevAnchors === 0) bumpPerform("anchor1");
      else bumpPerform("anchors");
      if (bigAnchored) bumpPerform("big");
    }
    prevAnchors = anchorsNow;
    if (firstFusion !== null && (stepPerforms.get("fuse") ?? 0) === 0) bumpPerform("fuse");
    if (firstWorkers !== null && (stepPerforms.get("hold") ?? 0) === 0) bumpPerform("hold");
    if (decayTime !== null && (stepPerforms.get("decay") ?? 0) === 0) bumpPerform("decay");
    if (fruitTime !== null && (stepPerforms.get("fruit") ?? 0) === 0) bumpPerform("fruit");
    if (sporeTime !== null && (stepPerforms.get("spore") ?? 0) === 0) bumpPerform("spore");
    if (joinTime !== null && (stepPerforms.get("join") ?? 0) === 0) bumpPerform("join");
    if (time >= BIG_APPEAR_T) spawnBigPatch();
    if (bigAnchored) spawnMatters();
    if (camZoom !== camZoomTarget) {
      const k = 1 - Math.exp(-dt / (CAM_ZOOM_DUR * 0.45));
      camZoom += (camZoomTarget - camZoom) * k;
      if (Math.abs(camZoom - camZoomTarget) < 0.001) camZoom = camZoomTarget;
    }
    networkPulse = Math.max(0, networkPulse - dt * 0.55);
    networkBright = Math.max(0, networkBright - dt * 0.35);

    // Matter decay animation
    for (const m of matters) {
      if (m.encircled && m.kind !== "fruit" && m.decay < 1) {
        m.decay = Math.min(1, m.decay + dt * 0.35);
      }
    }
    // Grains flow to seed
    for (let i = grains.length - 1; i >= 0; i--) {
      const g = grains[i]!;
      g.life -= dt;
      g.x += g.vx * dt;
      g.y += g.vy * dt;
      if (seed) {
        g.vx += (seed.x - g.x) * dt * 1.2;
        g.vy += (seed.y - g.y) * dt * 1.2;
      }
      if (g.life <= 0) grains.splice(i, 1);
    }
    for (let i = spores.length - 1; i >= 0; i--) {
      const s = spores[i]!;
      s.life -= dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vx *= 0.98;
      s.vy *= 0.98;
      if (s.life <= 0) spores.splice(i, 1);
    }
    for (const g of germs) {
      if (g.lit < 1) g.lit = Math.min(1, g.lit + dt * 0.4);
    }
    // Heartbeat after join
    if (joinTime !== null) {
      heartPhase += dt;
      heartBeat = 0.55 + 0.45 * Math.sin((heartPhase / JOIN_PULSE_PERIOD) * Math.PI * 2);
      networkBright = Math.max(networkBright, heartBeat * 0.35);
    }
    // Auto hint at ~10:00 after join (visual only — no new system)
    if (joinTime !== null && hintTime === null && time >= 595) {
      triggerHint();
    }
    if (foreignNet > 0) {
      foreignNet = Math.max(0, foreignNet - dt / HINT_DUR);
    }

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
      // Slide on intact matter surfaces (no pierce)
      for (const mat of matters) {
        if (mat.kind === "fruit" || mat.encircled) continue;
        const d = Math.hypot(mat.x - t.x, mat.y - t.y);
        const lim = mat.r * MATTER_SLIDE_R;
        if (d < lim && d > 1) {
          const out = Math.atan2(t.y - mat.y, t.x - mat.x);
          t.a += wrap(out + Math.PI * 0.5 - t.a) * 2.2 * dt;
          const push = (lim - d) * 0.5;
          t.x += Math.cos(out) * push;
          t.y += Math.sin(out) * push;
        }
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

    // Matter shapes (grey) — machine / beetle / fruiting body
    for (const m of matters) {
      const breath = 0.5 + 0.5 * Math.sin(time * 1.1 + m.ph);
      const alpha = m.kind === "fruit" ? 0.7 : 0.55 + 0.15 * breath;
      const green = m.decay * 0.55;
      const rr = m.r * (1 - m.decay * 0.45);
      if (m.kind === "fruit") {
        // Cap + stem (grey)
        ctx.fillStyle = `rgba(150,150,148,${alpha})`;
        ctx.beginPath();
        ctx.ellipse(m.x, m.y - rr * 0.25, rr * 0.95, rr * 0.55, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = `rgba(130,130,128,${alpha})`;
        ctx.fillRect(m.x - 3, m.y - 2, 6, rr * 0.7);
      } else if (m.kind === "machine") {
        ctx.fillStyle = `rgba(${Math.floor(120 + green * 40)},${Math.floor(120 + green * 80)},${Math.floor(118 - green * 20)},${alpha * (1 - m.decay * 0.3)})`;
        ctx.fillRect(m.x - rr * 0.7, m.y - rr * 0.45, rr * 1.4, rr * 0.9);
        ctx.strokeStyle = `rgba(90,90,88,${0.45 * (1 - m.decay)})`;
        ctx.lineWidth = 1.4;
        ctx.strokeRect(m.x - rr * 0.7, m.y - rr * 0.45, rr * 1.4, rr * 0.9);
        ctx.beginPath();
        ctx.arc(m.x - rr * 0.25, m.y, rr * 0.22, 0, Math.PI * 2);
        ctx.arc(m.x + rr * 0.3, m.y - rr * 0.1, rr * 0.18, 0, Math.PI * 2);
        ctx.stroke();
      } else {
        // Beetle oval
        ctx.fillStyle = `rgba(${Math.floor(110 + green * 50)},${Math.floor(110 + green * 70)},${Math.floor(108)},${alpha * (1 - m.decay * 0.3)})`;
        ctx.beginPath();
        ctx.ellipse(m.x, m.y, rr * 1.05, rr * 0.65, m.ph * 0.05, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = `rgba(80,80,78,${0.4 * (1 - m.decay)})`;
        ctx.lineWidth = 1.3;
        ctx.stroke();
      }
    }

    // Distant germs
    for (const g of germs) {
      const r = 5 + g.lit * 3 + Math.sin(time * 2 + g.x) * 0.5;
      const col = g.linked ? "200,210,190" : "160,160,155";
      const grd = ctx.createRadialGradient(g.x, g.y, 0, g.x, g.y, r * 3);
      grd.addColorStop(0, `rgba(${col},${0.35 + g.lit * 0.4})`);
      grd.addColorStop(1, `rgba(${col},0)`);
      ctx.fillStyle = grd;
      ctx.beginPath();
      ctx.arc(g.x, g.y, r * 3, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = `rgba(${col},${0.7 + g.lit * 0.25})`;
      ctx.beginPath();
      ctx.arc(g.x, g.y, r, 0, Math.PI * 2);
      ctx.fill();
    }

    // Grains + spores
    for (const g of grains) {
      ctx.fillStyle = `rgba(180,220,160,${Math.min(1, g.life) * 0.85})`;
      ctx.beginPath();
      ctx.arc(g.x, g.y, 2.2, 0, Math.PI * 2);
      ctx.fill();
    }
    for (const s of spores) {
      ctx.fillStyle = `rgba(200,200,190,${Math.min(1, s.life) * 0.5})`;
      ctx.beginPath();
      ctx.arc(s.x, s.y, 1.4, 0, Math.PI * 2);
      ctx.fill();
    }

    // Encircle live trail + catch highlight
    if (strokeActive && stroke.length > 1) {
      const live = smoothResample(stroke, 6, 1);
      ctx.strokeStyle = "rgba(200,210,190,0.45)";
      ctx.lineWidth = 2.4;
      ctx.lineCap = "round";
      ctx.lineJoin = "round";
      ctx.beginPath();
      ctx.moveTo(live[0]!.x, live[0]!.y);
      for (let i = 1; i < live.length; i++) ctx.lineTo(live[i]!.x, live[i]!.y);
      ctx.stroke();
      if (strokeCatch) {
        const r = "r" in strokeCatch ? strokeCatch.r * 1.35 : 18;
        ctx.strokeStyle = "rgba(210,230,180,0.65)";
        ctx.lineWidth = 2.2;
        ctx.beginPath();
        ctx.arc(strokeCatch.x, strokeCatch.y, r + 4 + Math.sin(time * 6) * 2, 0, Math.PI * 2);
        ctx.stroke();
        ctx.fillStyle = "rgba(190,220,160,0.12)";
        ctx.fill();
      }
    }

    // Magnetic connect target light
    if (snapHover) {
      ctx.strokeStyle = "rgba(220,230,200,0.7)";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(snapHover.x, snapHover.y, 14 + Math.sin(time * 8) * 2, 0, Math.PI * 2);
      ctx.stroke();
      ctx.fillStyle = "rgba(220,230,200,0.15)";
      ctx.fill();
    }

    drawMissFx(ctx, missFx);

    // Foreign network hint (visual only)
    if (foreignNet > 0 && foreignSeed) {
      const a = foreignNet * (0.35 + 0.25 * Math.sin(time * 7.3));
      ctx.strokeStyle = `rgba(140,190,130,${a})`;
      ctx.lineWidth = 1.6;
      ctx.beginPath();
      const fx = foreignSeed.x;
      const fy = foreignSeed.y;
      for (let i = 0; i < 5; i++) {
        const ang = (i / 5) * Math.PI * 2 + time * 0.4;
        ctx.moveTo(fx, fy);
        ctx.lineTo(fx + Math.cos(ang) * (30 + i * 8), fy + Math.sin(ang) * (22 + i * 6));
      }
      ctx.stroke();
    }

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

    // Diegetic guidance (always) — soft pulse + idle ghost hand
    {
      const g = guidance();
      if (g.target) drawGuidePulse(ctx, g.target, time);
      if (g.target2) drawGuidePulse(ctx, g.target2, time + 0.7, 0.35);
      if (showGhost && g.ghost && canGhost(g.stepId)) {
        drawGhostHand(ctx, g.ghost, g.from, g.to ?? g.target, time);
      }
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
    decayTime,
    fruitTime,
    sporeTime,
    joinTime,
    hintTime,
  });

  const snapshot = (): WorldSnapshot => ({
    tips: tips.map((t) => ({ x: t.x, y: t.y })),
    patches: patches.map((p) => ({ x: p.x, y: p.y, on: p.on, big: p.big })),
    seed: seed ? { x: seed.x, y: seed.y } : null,
    matters: matters.map((m) => ({
      x: m.x,
      y: m.y,
      r: m.r,
      kind: m.kind,
      decay: m.decay,
    })),
    germs: germs.map((g) => ({ x: g.x, y: g.y, linked: g.linked })),
    fruits: matters.filter((m) => m.kind === "fruit").map((m) => ({ x: m.x, y: m.y })),
  });

  const bootstrapStart5 = () => {
    // Post–big-anchor state at ~4:40 for ?start=5
    plantSeed(W * 0.5, H * 0.5);
    time = START5_T;
    // Dense network stub
    const base = rnd() * Math.PI * 2;
    for (let i = 0; i < 6; i++) {
      const a = base + (i * Math.PI * 2) / 6;
      let x = seed!.x;
      let y = seed!.y;
      let prev = -1;
      for (let s = 0; s < 28; s++) {
        const nx = x + Math.cos(a + (rnd() - 0.5) * 0.4) * STEP;
        const ny = y + Math.sin(a + (rnd() - 0.5) * 0.4) * STEP;
        prev = pushSeg(x, y, nx, ny, prev, s > 20 ? 1 : 0);
        x = nx;
        y = ny;
      }
      addTip(x, y, a, prev);
    }
    // Light a few patches
    for (let i = 0; i < Math.min(3, patches.length); i++) {
      const p = patches[i]!;
      if (p.big) continue;
      p.on = true;
      p.lit = 1;
      const idx = pushSeg(seed!.x, seed!.y, p.x, p.y, -1, 1);
      routes.push([idx]);
      if (firstAnchor === null) firstAnchor = 35;
    }
    midWowDone = true;
    midstep = 80;
    firstFusion = 120;
    firstWorkers = 220;
    spawnBigPatch();
    const big = patches.find((p) => p.big);
    if (big) {
      big.on = true;
      big.lit = 1;
      bigAnchored = true;
      bigAnchorTime = START5_T - 5;
      const idx = pushSeg(seed!.x, seed!.y, big.x, big.y, -1, 2);
      routes.push([idx]);
      camZoom = CAM_ZOOM_OUT;
      camZoomTarget = CAM_ZOOM_OUT;
      networkPulse = 0.6;
    }
    for (let i = 0; i < 40; i++) spawnWorker();
    spawnMatters();
  };

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

  if (opts.startAt !== undefined && opts.startAt >= START5_T - 5) {
    bootstrapStart5();
  }

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
    bootstrapStart5,
    guidance,
    pollWows,
    notePointer,
  };
}

/** Mount mycelium sim on a canvas. Returns cleanup. */
export function startMycelium(
  cv: HTMLCanvasElement,
  startAt?: number,
  demo?: DemoControls,
): () => void {
  const world = createMyceliumWorld({ startAt });
  void loadMyceliumAtlas().then((a) => world.setAtlas(a));
  return mountCanvas(cv, world, W, H, { demo });
}
