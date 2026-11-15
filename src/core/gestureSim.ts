/**
 * Noisy human-hand gesture simulator.
 * Reports encircle + connect success rates (target ≥95%).
 *
 *   npm run sim:gestures
 */
import {
  encircleRecognized,
  noisyLoop,
  noisyConnect,
  snapRadius,
  nearestTarget,
  pathLength,
  HAND_JITTER,
  HAND_UNDERSHOOT,
  ENC_CLOSE_PX,
  TRAIL_FINISH_PX,
} from "./gestures";

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

function runEncircle(trials: number, seed0: number): { ok: number; n: number } {
  let ok = 0;
  for (let i = 0; i < trials; i++) {
    const rng = mulberry32(seed0 + i * 97);
    const cx = 200 + rng() * 600;
    const cy = 160 + rng() * 320;
    const r = 36 + rng() * 28;
    const pts = noisyLoop(cx, cy, r, 28 + Math.floor(rng() * 10), rng, {
      jitter: HAND_JITTER,
      undershoot: HAND_UNDERSHOOT,
    });
    const rec = encircleRecognized(
      pts,
      { x: cx, y: cy, rx: r * 0.9, ry: r * 0.7 },
      { minLen: 140, minPts: 10, closePx: ENC_CLOSE_PX },
    );
    if (rec.ok) ok++;
  }
  return { ok, n: trials };
}

function runConnect(trials: number, seed0: number): { ok: number; n: number } {
  let ok = 0;
  const meta = { dpr: 1, touch: false };
  const snap = snapRadius(meta);
  for (let i = 0; i < trials; i++) {
    const rng = mulberry32(seed0 + i * 131);
    const ax = 120 + rng() * 200;
    const ay = 200 + rng() * 200;
    const bx = 500 + rng() * 350;
    const by = 150 + rng() * 300;
    const pts = noisyConnect(ax, ay, bx, by, 18 + Math.floor(rng() * 8), rng, {
      jitter: HAND_JITTER,
      undershoot: HAND_UNDERSHOOT,
    });
    const last = pts[pts.length - 1]!;
    const hit = nearestTarget(last.x, last.y, [{ x: bx, y: by }], Math.max(snap, TRAIL_FINISH_PX));
    // Also accept if path got within finish radius at any late sample
    let near = !!hit;
    if (!near) {
      for (let k = Math.max(0, pts.length - 5); k < pts.length; k++) {
        if (Math.hypot(pts[k]!.x - bx, pts[k]!.y - by) <= Math.max(snap, TRAIL_FINISH_PX)) {
          near = true;
          break;
        }
      }
    }
    if (near && pathLength(pts) > 40) ok++;
  }
  return { ok, n: trials };
}

/** Mycelium-style join: noisy drag toward germ with magnetic snap. */
function runMycJoin(trials: number, seed0: number): { ok: number; n: number } {
  let ok = 0;
  const snap = snapRadius({ dpr: 1, touch: false });
  for (let i = 0; i < trials; i++) {
    const rng = mulberry32(seed0 + i * 173);
    const sx = 400 + rng() * 80;
    const sy = 300 + rng() * 40;
    const gx = sx + 120 + rng() * 160;
    const gy = sy + (rng() - 0.5) * 120;
    const pts = noisyConnect(sx, sy, gx, gy, 16, rng);
    const last = pts[pts.length - 1]!;
    if (Math.hypot(last.x - gx, last.y - gy) <= Math.max(snap, TRAIL_FINISH_PX)) ok++;
  }
  return { ok, n: trials };
}

async function main(): Promise<void> {
  const N = 200;
  const enc = runEncircle(N, 42);
  const conn = runConnect(N, 77);
  const join = runMycJoin(N, 99);
  const encRate = enc.ok / enc.n;
  const connRate = conn.ok / conn.n;
  const joinRate = join.ok / join.n;
  const overall = (enc.ok + conn.ok + join.ok) / (enc.n + conn.n + join.n);

  console.log("=== Gesture noise sim (human hand) ===");
  console.log(`jitter≈${HAND_JITTER}px  undershoot=${(HAND_UNDERSHOOT * 100).toFixed(0)}%`);
  console.log(
    `encircle: ${enc.ok}/${enc.n} = ${(encRate * 100).toFixed(1)}%  (target ≥95%)`,
  );
  console.log(
    `connect:  ${conn.ok}/${conn.n} = ${(connRate * 100).toFixed(1)}%  (target ≥95%)`,
  );
  console.log(
    `join:     ${join.ok}/${join.n} = ${(joinRate * 100).toFixed(1)}%  (target ≥95%)`,
  );
  console.log(`overall:  ${(overall * 100).toFixed(1)}%`);

  const pass = encRate >= 0.95 && connRate >= 0.95 && joinRate >= 0.95;
  if (!pass) {
    console.error("FAIL: gesture success below 95%");
    process.exit(1);
  }
  console.log("PASS");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
