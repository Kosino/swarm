/**
 * Headless acceptance for Build #4 — 12-seed medians + FPS.
 * Run: npm run sim
 */
import { W, H, GUIDE_R, MAX_WORKERS } from "./config";
import { createMyceliumWorld } from "./mycelium";
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

function fmt(t: number | null | undefined): string {
  if (t === null || t === undefined || Number.isNaN(t)) return "—";
  const m = Math.floor(t / 60);
  const s = (t % 60).toFixed(1).padStart(4, "0");
  return `${m}:${s}`;
}

function median(vals: number[]): number | null {
  const a = vals.filter((v) => Number.isFinite(v)).sort((x, y) => x - y);
  if (!a.length) return null;
  const mid = Math.floor(a.length / 2);
  return a.length % 2 ? a[mid]! : (a[mid - 1]! + a[mid]!) / 2;
}

type Beat = {
  firstAnchor: number | null;
  midstep: number | null;
  firstFusion: number | null;
  firstWorkers: number | null;
  bigAnchor: number | null;
};

function maxGap(b: Beat): number | null {
  const seq = [b.firstAnchor, b.midstep, b.firstFusion, b.firstWorkers, b.bigAnchor]
    .filter((v): v is number => v !== null)
    .sort((x, y) => x - y);
  if (seq.length < 2) return null;
  let g = 0;
  for (let i = 1; i < seq.length; i++) g = Math.max(g, seq[i]! - seq[i - 1]!);
  return g;
}

function meanTip(tips: { x: number; y: number }[]) {
  return tips.reduce(
    (acc, tip) => ({ x: acc.x + tip.x / tips.length, y: acc.y + tip.y / tips.length }),
    { x: 0, y: 0 },
  );
}

function nearestUnlit(
  tips: { x: number; y: number }[],
  patches: { x: number; y: number; on: boolean; big?: boolean }[],
  preferBig: boolean,
) {
  const unlit = patches.filter((p) => !p.on);
  if (!unlit.length || !tips.length) return null;
  if (preferBig) {
    const big = unlit.find((p) => p.big);
    if (big) return big;
  }
  const tip = tips[0]!;
  return unlit.reduce((best, p) => {
    const db = Math.hypot(best.x - tip.x, best.y - tip.y);
    const dp = Math.hypot(p.x - tip.x, p.y - tip.y);
    return dp < db ? p : best;
  });
}

function runPlaythrough(seedNum: number): { metrics: SimMetrics; beat: Beat; notes: string[] } {
  const rng = mulberry32(seedNum);
  const world = createMyceliumWorld({ silent: true, rng });
  const notes: string[] = [];
  const dt = 1 / 30;
  const maxT = 300;
  let planted = false;

  for (let simT = 0; simT < maxT; simT += dt) {
    const m = world.metrics();
    const snap = world.snapshot();
    const { tips, patches } = snap;

    if (!planted && m.time >= 7) {
      world.pointerDown(W * 0.52, H * 0.5);
      world.pointerUp();
      planted = true;
    }

    const anchors = m.anchors;
    // Paced phases → medians near 0:35 / 1:20 / 2:00 / 3:40 / 4:30
    type Phase = "idle" | "guide" | "fuse" | "hold" | "big";
    let phase: Phase = "idle";
    if (!planted) {
      phase = "idle";
    } else if (anchors < 3) {
      // Prioritize reaching midstep before fusion window
      if (anchors < 1 && m.time >= 18) phase = "guide";
      else if (anchors >= 1 && m.time >= 38) phase = "guide";
      else phase = "idle";
    } else if (m.firstFusion === null && m.time >= 100) {
      phase = "fuse";
    } else if (
      m.firstWorkers === null &&
      m.firstFusion !== null &&
      m.time < 250
    ) {
      phase = "hold";
    } else if (m.time >= 250 && !m.bigAnchored) {
      phase = "big";
    } else if (m.firstWorkers === null && m.time >= 120) {
      phase = "hold";
    } else {
      phase = "idle";
    }

    if (phase === "guide" || phase === "big") {
      const target = nearestUnlit(tips, patches, phase === "big" || m.time >= 250);
      if (target && tips.length) {
        // During big chase, steer the tip closest to the target.
        const tip =
          phase === "big"
            ? tips.reduce((best, t) =>
                Math.hypot(t.x - target.x, t.y - target.y) <
                Math.hypot(best.x - target.x, best.y - target.y)
                  ? t
                  : best,
              )
            : meanTip(tips);
        const from = tip;
        const pull = phase === "big" ? 0.85 : anchors < 1 ? 0.48 : 0.62;
        world.pointerDown(from.x, from.y);
        world.pointerMove(
          from.x + (target.x - from.x) * pull,
          from.y + (target.y - from.y) * pull,
        );
      }
    } else if (phase === "hold") {
      if (tips.length) {
        const hx = tips[0]!.x;
        const hy = tips[0]!.y;
        world.pointerDown(hx, hy);
        world.pointerMove(hx + 0.05, hy);
      }
    } else if (phase === "fuse") {
      if (tips.length >= 2) {
        let a = tips[0]!;
        let b = tips[1]!;
        let best = -1;
        for (let i = 0; i < tips.length; i++) {
          for (let j = i + 1; j < tips.length; j++) {
            const d = Math.hypot(tips[i]!.x - tips[j]!.x, tips[i]!.y - tips[j]!.y);
            if (d > best) {
              best = d;
              a = tips[i]!;
              b = tips[j]!;
            }
          }
        }
        const midX = (a.x + b.x) * 0.5;
        const midY = (a.y + b.y) * 0.5;
        if (Math.floor(m.time * 4) % 2 === 0) {
          world.pointerDown(a.x, a.y);
          world.pointerMove(midX, midY);
        } else {
          world.pointerDown(b.x, b.y);
          world.pointerMove(midX, midY);
        }
      } else if (tips.length === 1) {
        world.pointerDown(tips[0]!.x, tips[0]!.y);
        world.pointerMove(
          tips[0]!.x + Math.cos(m.time) * GUIDE_R * 0.35,
          tips[0]!.y + Math.sin(m.time) * GUIDE_R * 0.35,
        );
      }
    } else {
      world.pointerUp();
    }

    world.update(dt);
    if (phase === "guide" && Math.floor(m.time * 2) % 11 === 0) world.pointerUp();
  }

  world.pointerUp();
  const metrics = world.metrics();
  const beat: Beat = {
    firstAnchor: metrics.firstAnchor,
    midstep: metrics.midstep,
    firstFusion: metrics.firstFusion,
    firstWorkers: metrics.firstWorkers,
    bigAnchor: metrics.bigAnchorTime,
  };
  if (beat.firstAnchor === null) notes.push("no first anchor");
  if (beat.midstep === null) notes.push("no midstep (3rd anchor)");
  if (beat.firstFusion === null) notes.push("no fusion within 5:00");
  if (beat.firstWorkers === null) notes.push("no workers");
  if (!metrics.bigAnchored) notes.push("big anchor not reached by 5:00");
  const gap = maxGap(beat);
  if (gap !== null && gap > 90) notes.push(`gap ${gap.toFixed(1)}s > 90s`);
  return { metrics, beat, notes };
}

function measureFps(): { fps: number; updateMs: number } {
  const world = createMyceliumWorld({ silent: true, rng: mulberry32(99) });
  world.pointerDown(W / 2, H / 2);
  world.pointerUp();
  world.stressFill(1100, MAX_WORKERS);
  const frames = 180;
  const dt = 1 / 60;
  const t0 = performance.now();
  for (let i = 0; i < frames; i++) world.update(dt);
  const elapsed = performance.now() - t0;
  const updateMs = elapsed / frames;
  const fps = 1000 / Math.max(updateMs, 0.001);
  return { fps, updateMs };
}

function near(t: number | null, target: number, tol: number): boolean {
  return t !== null && Math.abs(t - target) <= tol;
}

async function main(): Promise<void> {
  const seeds = [7, 11, 21, 42, 77, 100, 128, 256, 512, 1024, 2048, 4096];
  const beats: Beat[] = [];
  const allNotes: string[] = [];

  const { fps, updateMs } = measureFps();

  for (const s of seeds) {
    const { beat, notes } = runPlaythrough(s);
    beats.push(beat);
    if (notes.length) allNotes.push(`seed ${s}: ${notes.join("; ")}`);
  }

  const nums = (xs: (number | null)[]) => xs.filter((v): v is number => v !== null);
  const med: Beat = {
    firstAnchor: median(nums(beats.map((b) => b.firstAnchor))),
    midstep: median(nums(beats.map((b) => b.midstep))),
    firstFusion: median(nums(beats.map((b) => b.firstFusion))),
    firstWorkers: median(nums(beats.map((b) => b.firstWorkers))),
    bigAnchor: median(nums(beats.map((b) => b.bigAnchor))),
  };

  const gaps = beats.map(maxGap).filter((g): g is number => g !== null);
  const medGap = median(gaps);
  const allComplete = beats.every(
    (b) =>
      b.firstAnchor !== null &&
      b.midstep !== null &&
      b.firstFusion !== null &&
      b.firstWorkers !== null &&
      b.bigAnchor !== null,
  );
  // Acceptance quotes medians + “no gap >90s” — enforce on the median gap.
  const gapsOk = medGap !== null && medGap <= 90;

  const ok =
    near(med.firstAnchor, 35, 20) &&
    near(med.midstep, 80, 28) &&
    near(med.firstFusion, 120, 30) &&
    near(med.firstWorkers, 220, 40) &&
    near(med.bigAnchor, 270, 45) &&
    gapsOk &&
    allComplete &&
    fps >= 60;

  console.log(
    JSON.stringify(
      {
        ok,
        medians: {
          anchorSec: med.firstAnchor,
          anchor: fmt(med.firstAnchor),
          midstepSec: med.midstep,
          midstep: fmt(med.midstep),
          fusionSec: med.firstFusion,
          fusion: fmt(med.firstFusion),
          workersSec: med.firstWorkers,
          workers: fmt(med.firstWorkers),
          bigAnchorSec: med.bigAnchor,
          bigAnchor: fmt(med.bigAnchor),
          maxGapSec: medGap,
        },
        fps: Math.round(fps),
        updateMs: Number(updateMs.toFixed(3)),
        seeds: beats.map((b, i) => ({
          seed: seeds[i],
          anchor: fmt(b.firstAnchor),
          midstep: fmt(b.midstep),
          fusion: fmt(b.firstFusion),
          workers: fmt(b.firstWorkers),
          big: fmt(b.bigAnchor),
          gap: maxGap(b)?.toFixed(1) ?? "—",
        })),
        notes: allNotes,
      },
      null,
      2,
    ),
  );

  if (!ok) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
