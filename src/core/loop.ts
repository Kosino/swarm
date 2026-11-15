/** Shared canvas mount: RAF loop + pointer → world coords. */

export type GameWorld = {
  update: (dt: number) => void;
  draw: (ctx: CanvasRenderingContext2D, dpr: number) => void;
  pointerDown: (x: number, y: number) => void;
  pointerMove: (x: number, y: number) => void;
  pointerUp: () => void;
};

export function mountCanvas(
  cv: HTMLCanvasElement,
  world: GameWorld,
  W: number,
  H: number,
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
    world.pointerDown(x, y);
  };
  const onMove = (e: PointerEvent) => {
    const [x, y] = toWorld(e);
    world.pointerMove(x, y);
  };
  const onUp = () => world.pointerUp();

  cv.addEventListener("pointerdown", onDown);
  cv.addEventListener("pointermove", onMove);
  cv.addEventListener("pointerup", onUp);
  cv.addEventListener("pointercancel", onUp);

  let last = performance.now();
  let raf = 0;
  const loop = (now: number) => {
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    world.update(dt);
    world.draw(ctx, dpr);
    raf = requestAnimationFrame(loop);
  };
  raf = requestAnimationFrame(loop);

  return () => {
    cancelAnimationFrame(raf);
    cv.removeEventListener("pointerdown", onDown);
    cv.removeEventListener("pointermove", onMove);
    cv.removeEventListener("pointerup", onUp);
    cv.removeEventListener("pointercancel", onUp);
  };
}
