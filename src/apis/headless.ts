/**
 * Headless acceptance for Apis Build #5 — 0–5 + midgame wows.
 * Run: npm run sim:apis
 */
import { W, H, HEX, TREE_MIN_CHAMBERS, TRAIL_MIN_LEN } from "./config";
import { createApisWorld } from "./apis";
import type { SimMetrics } from "./types";

function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function fmt(t: number | null): string {
  if (t === null) return "—";
  const m = Math.floor(t / 60);
  const s = (t % 60).toFixed(1).padStart(4, "0");
  return `${m}:${s}`;
}

type Result = {
  ok: boolean;
  metrics: SimMetrics;
  fps: number;
  updateMs: number;
  notes: string[];
  seed: number;
};

function axialToPixel(q: number, r: number, cx: number, cy: number): [number, number] {
  const size = HEX + 1.5;
  const x = size * (1.5 * q) + cx;
  const y = size * ((Math.sqrt(3) / 2) * q + Math.sqrt(3) * r) + cy;
  return [x, y];
}

const RING: [number, number][] = [
  [1, 0],
  [1, -1],
  [0, -1],
  [-1, 0],
  [-1, 1],
  [0, 1],
];

function slowTrail(
  world: ReturnType<typeof createApisWorld>,
  pts: { x: number; y: number }[],
  update: (dt: number) => void,
  dt: number,
) {
  // Paint slowly so avg speed < TRAIL_MAX_SPEED
  world.pointerDown(pts[0]!.x, pts[0]!.y);
  update(dt);
  for (let i = 1; i < pts.length; i++) {
    world.pointerMove(pts[i]!.x, pts[i]!.y);
    // ~40 px/s → wait
    const d = Math.hypot(pts[i]!.x - pts[i - 1]!.x, pts[i]!.y - pts[i - 1]!.y);
    const wait = Math.max(dt, d / 55);
    for (let t = 0; t < wait; t += dt) update(dt);
  }
  world.pointerUp();
  update(dt);
}

function runPlaythrough(seedNum: number): { metrics: SimMetrics; notes: string[] } {
  const rng = mulberry32(seedNum);
  const world = createApisWorld({ silent: true, rng });
  const notes: string[] = [];
  const dt = 1 / 30;
  const maxT = 620;
  const cx = W * 0.5;
  const cy = H * 0.48;

  let planted = false;
  let lastBuildT = -10;
  let lastRouteT = -10;
  let midTrailAt = -1;

  const step = () => {
    world.update(dt);
  };

  for (let simT = 0; simT < maxT; ) {
    const m = world.metrics();
    const snap = world.snapshot();

    if (!planted && m.time >= 14) {
      world.pointerDown(cx, cy);
      world.pointerUp();
      planted = true;
      lastBuildT = m.time;
    }

    if (planted && !m.bigFlight) {
      const built = new Set(snap.chambers.filter((c) => c.grow >= 1).map((c) => `${c.q},${c.r}`));
      const growing = snap.chambers.some((c) => c.grow < 1);
      const nBuilt = snap.chambers.filter((c) => c.grow >= 1).length;
      const buildCd = !snap.ringClosed ? 0.7 : nBuilt < 12 ? 1.0 : 2.9;
      const holdRing = !snap.ringClosed && nBuilt >= 3 && m.time < 124;
      const holdExpand = snap.ringClosed && nBuilt >= 11 && m.time < 225;
      if (holdRing || holdExpand) {
        // wait
      } else if (!growing && m.time - lastBuildT > buildCd && snap.wax >= 0.3) {
        let target: [number, number] | null = null;
        if (!snap.ringClosed) {
          for (const cell of RING) {
            if (!built.has(`${cell[0]},${cell[1]}`)) {
              target = cell;
              break;
            }
          }
        } else {
          const tree = snap.flowers.find((f) => f.tree);
          if (tree) {
            let best: [number, number] | null = null;
            let bd = Infinity;
            const candidates: [number, number][] = [];
            for (const ch of snap.chambers) {
              if (ch.grow < 1) continue;
              for (const [dq, dr] of RING) candidates.push([ch.q + dq, ch.r + dr]);
            }
            for (const [q, r] of candidates) {
              if (q === 0 && r === 0) continue;
              if (built.has(`${q},${r}`)) continue;
              if (snap.chambers.some((c) => c.q === q && c.r === r)) continue;
              const [px, py] = axialToPixel(q, r, cx, cy);
              const d = Math.hypot(tree.x - px, tree.y - py);
              if (d < bd) {
                bd = d;
                best = [q, r];
              }
            }
            target = best;
          }
        }
        if (target) {
          const [px, py] = axialToPixel(target[0], target[1], cx, cy);
          world.pointerDown(px, py);
          world.pointerUp();
          lastBuildT = m.time;
        }
      }

      if (m.time - lastRouteT > 1.2 && (snap.workers.length > 0 || m.time > 30)) {
        const tree = snap.flowers.find((f) => f.tree);
        const hive = snap.core ?? { x: cx, y: cy };
        const all = snap.flowers;
        const dest = all
          .map((f, i) => ({ f, i }))
          .filter(({ f }) => !f.tree)
          .filter(({ f }) => Math.hypot(f.x - hive.x, f.y - hive.y) <= snap.reach + 5)
          .sort(
            (a, b) =>
              Math.hypot(a.f.x - hive.x, a.f.y - hive.y) - Math.hypot(b.f.x - hive.x, b.f.y - hive.y),
          );
        const routed = new Set(snap.workers.filter((w) => w.flower >= 0).map((w) => w.flower));
        let pickIdx = dest[0]?.i ?? -1;
        if (
          tree &&
          snap.chambers.filter((c) => c.grow >= 1).length >= TREE_MIN_CHAMBERS &&
          Math.hypot(tree.x - hive.x, tree.y - hive.y) <= snap.reach + 5 &&
          !m.bigFlight
        ) {
          pickIdx = all.indexOf(tree);
        } else {
          for (const { i } of dest) {
            if (!routed.has(i)) {
              pickIdx = i;
              break;
            }
          }
        }
        if (pickIdx >= 0) {
          const pick = all[pickIdx]!;
          world.pointerDown(hive.x + 8, hive.y);
          world.pointerMove(pick.x, pick.y);
          world.pointerUp();
          lastRouteT = m.time;
        }
      }
    }

    // Midgame pheromone trails at wow windows
    if (m.bigFlight && m.time - midTrailAt > 3) {
      const hive = snap.core ?? { x: cx, y: cy };
      if (m.trailTime === null && m.time >= 342) {
        // Slow trail into meadow
        const ang = 0.4 + (seedNum % 7) * 0.15;
        const pts: { x: number; y: number }[] = [];
        for (let i = 0; i <= 18; i++) {
          const t = i / 18;
          pts.push({
            x: hive.x + Math.cos(ang) * (40 + t * 200),
            y: hive.y + Math.sin(ang) * (30 + t * 160),
          });
        }
        // Ensure length
        let len = 0;
        for (let i = 1; i < pts.length; i++)
          len += Math.hypot(pts[i]!.x - pts[i - 1]!.x, pts[i]!.y - pts[i - 1]!.y);
        if (len < TRAIL_MIN_LEN) {
          pts.push({
            x: pts[pts.length - 1]!.x + Math.cos(ang) * 80,
            y: pts[pts.length - 1]!.y + Math.sin(ang) * 60,
          });
        }
        slowTrail(world, pts, step, dt);
        midTrailAt = world.metrics().time;
        simT = world.metrics().time;
        continue;
      }
      if (m.floor2Time === null && m.trailTime !== null && m.time >= 415) {
        // Arc around hive
        const pts: { x: number; y: number }[] = [];
        const r = 95;
        for (let i = 0; i <= 20; i++) {
          const a = -0.4 + (i / 20) * 2.4;
          pts.push({ x: hive.x + Math.cos(a) * r, y: hive.y + Math.sin(a) * r * 0.85 });
        }
        slowTrail(world, pts, step, dt);
        midTrailAt = world.metrics().time;
        simT = world.metrics().time;
        continue;
      }
      if (m.swarmTime === null && m.floor2Time !== null && m.time >= 488) {
        const dest = snap.meadow2 ?? snap.flowers.reduce((best, f) => {
          const d = Math.hypot(f.x - hive.x, f.y - hive.y);
          const bd = Math.hypot(best.x - hive.x, best.y - hive.y);
          return d > bd ? f : best;
        }, snap.flowers[0]!);
        const pts: { x: number; y: number }[] = [];
        for (let i = 0; i <= 22; i++) {
          const t = i / 22;
          pts.push({
            x: hive.x + (dest.x - hive.x) * t,
            y: hive.y + (dest.y - hive.y) * t,
          });
        }
        slowTrail(world, pts, step, dt);
        midTrailAt = world.metrics().time;
        simT = world.metrics().time;
        continue;
      }
      if (m.joinTime === null && m.swarmTime !== null && m.time >= 552) {
        const dest = snap.secondHive ?? snap.meadow2 ?? { x: hive.x + 200, y: hive.y };
        const pts: { x: number; y: number }[] = [];
        for (let i = 0; i <= 20; i++) {
          const t = i / 20;
          pts.push({
            x: hive.x + (dest.x - hive.x) * t,
            y: hive.y + (dest.y - hive.y) * t,
          });
        }
        slowTrail(world, pts, step, dt);
        midTrailAt = world.metrics().time;
        simT = world.metrics().time;
        continue;
      }
    }

    step();
    simT = world.metrics().time;
  }

  const metrics = world.metrics();
  if (metrics.firstWorker === null || metrics.firstWorker < 25 || metrics.firstWorker > 50)
    notes.push(`first worker off ~0:35 (${fmt(metrics.firstWorker)})`);
  if (metrics.firstNectar === null || metrics.firstNectar < 65 || metrics.firstNectar > 100)
    notes.push(`first nectar off ~1:20 (${fmt(metrics.firstNectar)})`);
  if (metrics.ringTime === null || metrics.ringTime < 110 || metrics.ringTime > 160)
    notes.push(`ring off ~2:15 (${fmt(metrics.ringTime)})`);
  if (metrics.trafficTime === null || metrics.trafficTime < 175 || metrics.trafficTime > 230)
    notes.push(`traffic off ~3:20 (${fmt(metrics.trafficTime)})`);
  if (!metrics.bigFlight) notes.push("big flight not reached by 5:00");
  else if (
    metrics.bigFlightTime !== null &&
    (metrics.bigFlightTime < 240 || metrics.bigFlightTime > 295)
  )
    notes.push(`big flight off ~4:40 (${fmt(metrics.bigFlightTime)})`);

  const early = [
    metrics.firstWorker,
    metrics.firstNectar,
    metrics.ringTime,
    metrics.trafficTime,
    metrics.bigFlightTime,
  ];
  for (let i = 1; i < early.length; i++) {
    const a = early[i - 1];
    const b = early[i];
    if (a !== null && b !== null && b - a > 90)
      notes.push(`early gap >90s (${fmt(a)} → ${fmt(b)})`);
  }

  if (metrics.trailTime === null) notes.push("no trail wow");
  else if (Math.abs(metrics.trailTime - 345) > 20)
    notes.push(`trail off ~5:45 (${fmt(metrics.trailTime)})`);
  if (metrics.floor2Time === null) notes.push("no floor2 wow");
  else if (Math.abs(metrics.floor2Time - 420) > 20)
    notes.push(`floor2 off ~7:00 (${fmt(metrics.floor2Time)})`);
  if (metrics.swarmTime === null) notes.push("no swarm wow");
  else if (Math.abs(metrics.swarmTime - 495) > 20)
    notes.push(`swarm off ~8:15 (${fmt(metrics.swarmTime)})`);
  if (metrics.joinTime === null) notes.push("no join wow");
  else if (Math.abs(metrics.joinTime - 560) > 20)
    notes.push(`join off ~9:20 (${fmt(metrics.joinTime)})`);
  if (metrics.hintTime === null) notes.push("no hint");
  else if (Math.abs(metrics.hintTime - 600) > 20)
    notes.push(`hint off ~10:00 (${fmt(metrics.hintTime)})`);

  const mid = [
    metrics.trailTime,
    metrics.floor2Time,
    metrics.swarmTime,
    metrics.joinTime,
    metrics.hintTime,
  ];
  for (let i = 1; i < mid.length; i++) {
    const a = mid[i - 1];
    const b = mid[i];
    if (a !== null && b !== null && b - a > 90) notes.push(`mid gap >90s (${fmt(a)} → ${fmt(b)})`);
  }

  return { metrics, notes };
}

function measureFps(): { fps: number; updateMs: number } {
  const world = createApisWorld({ silent: true, rng: mulberry32(99) });
  world.pointerDown(W / 2, H * 0.48);
  world.pointerUp();
  world.stressFill(200);
  const frames = 180;
  const dt = 1 / 60;
  const t0 = performance.now();
  for (let i = 0; i < frames; i++) world.update(dt);
  const elapsed = performance.now() - t0;
  const updateMs = elapsed / frames;
  const fps = 1000 / Math.max(updateMs, 0.001);
  return { fps, updateMs };
}

function accept(r: Result): boolean {
  const { metrics, fps } = r;
  const wOk =
    metrics.firstWorker !== null && metrics.firstWorker >= 25 && metrics.firstWorker <= 50;
  const nOk =
    metrics.firstNectar !== null && metrics.firstNectar >= 65 && metrics.firstNectar <= 100;
  const rOk = metrics.ringTime !== null && metrics.ringTime >= 110 && metrics.ringTime <= 160;
  const tOk =
    metrics.trafficTime !== null && metrics.trafficTime >= 175 && metrics.trafficTime <= 230;
  const bOk =
    metrics.bigFlight &&
    metrics.bigFlightTime !== null &&
    metrics.bigFlightTime >= 240 &&
    metrics.bigFlightTime <= 295;
  const trailOk = metrics.trailTime !== null && Math.abs(metrics.trailTime - 345) <= 20;
  const floorOk = metrics.floor2Time !== null && Math.abs(metrics.floor2Time - 420) <= 20;
  const swarmOk = metrics.swarmTime !== null && Math.abs(metrics.swarmTime - 495) <= 20;
  const joinOk = metrics.joinTime !== null && Math.abs(metrics.joinTime - 560) <= 20;
  const hintOk = metrics.hintTime !== null && Math.abs(metrics.hintTime - 600) <= 20;
  const marks = [
    metrics.firstWorker,
    metrics.firstNectar,
    metrics.ringTime,
    metrics.trafficTime,
    metrics.bigFlightTime,
    metrics.trailTime,
    metrics.floor2Time,
    metrics.swarmTime,
    metrics.joinTime,
    metrics.hintTime,
  ];
  let gapsOk = true;
  for (let i = 1; i < marks.length; i++) {
    const a = marks[i - 1];
    const b = marks[i];
    if (a === null || b === null || b - a > 90) gapsOk = false;
  }
  return (
    wOk &&
    nOk &&
    rOk &&
    tOk &&
    bOk &&
    trailOk &&
    floorOk &&
    swarmOk &&
    joinOk &&
    hintOk &&
    gapsOk &&
    fps >= 60
  );
}

function median(vals: (number | null)[]): number | null {
  const a = vals.filter((v): v is number => v !== null).sort((x, y) => x - y);
  if (!a.length) return null;
  return a[Math.floor(a.length / 2)];
}

async function main(): Promise<void> {
  const seeds = [3, 7, 11, 21, 42, 77, 100, 128, 256, 512, 1024, 2048];
  const results: Result[] = [];

  const { fps, updateMs } = measureFps();

  for (const s of seeds) {
    const { metrics, notes } = runPlaythrough(s);
    const result: Result = { ok: false, metrics, fps, updateMs, notes, seed: s };
    result.ok = accept(result);
    results.push(result);
  }

  const okCount = results.filter((r) => r.ok).length;
  const med = {
    firstWorker: median(results.map((r) => r.metrics.firstWorker)),
    firstNectar: median(results.map((r) => r.metrics.firstNectar)),
    ring: median(results.map((r) => r.metrics.ringTime)),
    traffic: median(results.map((r) => r.metrics.trafficTime)),
    bigFlight: median(results.map((r) => r.metrics.bigFlightTime)),
    trail: median(results.map((r) => r.metrics.trailTime)),
    floor2: median(results.map((r) => r.metrics.floor2Time)),
    swarm: median(results.map((r) => r.metrics.swarmTime)),
    join: median(results.map((r) => r.metrics.joinTime)),
    hint: median(results.map((r) => r.metrics.hintTime)),
  };

  console.log(
    JSON.stringify(
      {
        ok: okCount === results.length,
        okCount,
        seeds: results.length,
        medians: {
          firstWorker: fmt(med.firstWorker),
          firstNectar: fmt(med.firstNectar),
          ring: fmt(med.ring),
          traffic: fmt(med.traffic),
          bigFlight: fmt(med.bigFlight),
          trail: fmt(med.trail),
          floor2: fmt(med.floor2),
          swarm: fmt(med.swarm),
          join: fmt(med.join),
          hint: fmt(med.hint),
        },
        fps: Math.round(fps),
        updateMs: Number(updateMs.toFixed(3)),
        notes: results.flatMap((r) => r.notes.map((n) => `seed ${r.seed}: ${n}`)),
      },
      null,
      2,
    ),
  );

  if (okCount < results.length) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
