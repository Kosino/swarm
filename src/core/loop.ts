/** Shared canvas mount: RAF loop + pointer → world coords + optional demo speed. */

import type { DemoControls } from "./demo";
import type { GuidanceInfo, WowEvent } from "./guidance";

export type GameWorld = {
  update: (dt: number) => void;
  draw: (ctx: CanvasRenderingContext2D, dpr: number) => void;
  pointerDown: (x: number, y: number) => void;
  pointerMove: (x: number, y: number) => void;
  pointerUp: () => void;
  /** Optional: sim clock + wow metrics for demo HUD. */
  metrics?: () => { time: number; [k: string]: unknown };
  /** Optional: diegetic + demo guidance. */
  guidance?: () => GuidanceInfo;
  /** Optional: collect new wow events since last poll. */
  pollWows?: () => WowEvent[];
  /** Notify idle/action for ghost hand. */
  notePointer?: () => void;
};

export type MountOpts = {
  demo?: DemoControls;
};

export function mountCanvas(
  cv: HTMLCanvasElement,
  world: GameWorld,
  W: number,
  H: number,
  opts: MountOpts = {},
): () => void {
  const ctx = cv.getContext("2d");
  if (!ctx) return () => {};

  const dpr = Math.min(2, window.devicePixelRatio || 1);
  cv.width = W * dpr;
  cv.height = H * dpr;

  const toWorld = (e: PointerEvent): [number, number] => {
    const r = cv.getBoundingClientRect();
    return [((e.clientX - r.left) / r.width) * W, ((e.clientY - r.top) / r.height) * H];
  };

  const onDown = (e: PointerEvent) => {
    const [x, y] = toWorld(e);
    cv.setPointerCapture(e.pointerId);
    world.notePointer?.();
    world.pointerDown(x, y);
  };
  const onMove = (e: PointerEvent) => {
    const [x, y] = toWorld(e);
    world.pointerMove(x, y);
  };
  const onUp = () => {
    world.notePointer?.();
    world.pointerUp();
  };

  cv.addEventListener("pointerdown", onDown);
  cv.addEventListener("pointermove", onMove);
  cv.addEventListener("pointerup", onUp);
  cv.addEventListener("pointercancel", onUp);

  let last = performance.now();
  let raf = 0;
  const loop = (now: number) => {
    const wallDt = Math.min(0.05, (now - last) / 1000);
    last = now;

    const demo = opts.demo;
    const paused = demo?.paused ?? false;
    const speed = demo?.speed ?? 1;

    if (!paused) {
      // Speed simulation, not render — substep for stability
      let remaining = wallDt * speed;
      while (remaining > 1e-6) {
        const step = Math.min(0.05, remaining);
        world.update(step);
        remaining -= step;
      }
    }

    world.draw(ctx, dpr);

    if (demo) {
      for (const w of world.pollWows?.() ?? []) demo.pushWow(w);
      const m = world.metrics?.();
      const g = world.guidance?.();
      demo.tick(m?.time ?? 0, demo.demo ? (g?.label ?? null) : null);
    }

    raf = requestAnimationFrame(loop);
  };
  raf = requestAnimationFrame(loop);

  return () => {
    cancelAnimationFrame(raf);
    cv.removeEventListener("pointerdown", onDown);
    cv.removeEventListener("pointermove", onMove);
    cv.removeEventListener("pointerup", onUp);
    cv.removeEventListener("pointercancel", onUp);
    opts.demo?.destroy();
  };
}
