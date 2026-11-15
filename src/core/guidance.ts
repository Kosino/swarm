/** Diegetic guidance + demo step labels (state-driven, not clock). */

export type GhostKind = "tap" | "drag" | "hold" | "encircle" | "trail";

export type GuideTarget = {
  x: number;
  y: number;
  r: number;
};

export type GuidanceInfo = {
  /** Stable id for the current teaching step. */
  stepId: string;
  /** Demo-only bottom line (follows game state). */
  label: string;
  /** Soft pulse target for next action (always-on diegetic). */
  target: GuideTarget | null;
  /** Optional second target (e.g. encircle both fruits). */
  target2: GuideTarget | null;
  /** Ghost gesture kind after idle. */
  ghost: GhostKind | null;
  /** Drag/trail/encircle path endpoints. */
  from: GuideTarget | null;
  to: GuideTarget | null;
};

export type WowEvent = {
  id: string;
  label: string;
  time: number;
};

export const IDLE_GHOST_S = 8;
export const MAX_GHOST_PERFORMS = 2;

export function fmtGameTime(t: number): string {
  const m = Math.floor(t / 60);
  const s = Math.floor(t % 60);
  return `${m}:${s.toString().padStart(2, "0")}`;
}

/** Draw soft pulse ring at target (diegetic, no text). */
export function drawGuidePulse(
  ctx: CanvasRenderingContext2D,
  target: GuideTarget,
  time: number,
  alpha = 0.45,
): void {
  const breath = 0.5 + 0.5 * Math.sin(time * 2.4);
  const r = target.r * (1.1 + breath * 0.35);
  ctx.beginPath();
  ctx.arc(target.x, target.y, r, 0, Math.PI * 2);
  ctx.strokeStyle = `rgba(220,220,210,${alpha * (0.35 + breath * 0.4)})`;
  ctx.lineWidth = 2;
  ctx.stroke();
  ctx.beginPath();
  ctx.arc(target.x, target.y, r * 0.55, 0, Math.PI * 2);
  ctx.fillStyle = `rgba(220,220,210,${alpha * 0.12 * breath})`;
  ctx.fill();
}

/** Translucent ghost hand demo — vanishes when player acts. */
export function drawGhostHand(
  ctx: CanvasRenderingContext2D,
  kind: GhostKind,
  from: GuideTarget | null,
  to: GuideTarget | null,
  time: number,
): void {
  const phase = (time % 2.4) / 2.4;
  ctx.save();
  ctx.globalAlpha = 0.35;

  if (kind === "tap" && to) {
    const k = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    const x = to.x;
    const y = to.y - 18 + k * 10;
    drawHand(ctx, x, y, 0);
    ctx.beginPath();
    ctx.arc(to.x, to.y, 6 + k * 8, 0, Math.PI * 2);
    ctx.strokeStyle = "rgba(240,240,230,0.5)";
    ctx.lineWidth = 1.5;
    ctx.stroke();
  } else if ((kind === "drag" || kind === "trail") && from && to) {
    const x = from.x + (to.x - from.x) * phase;
    const y = from.y + (to.y - from.y) * phase;
    ctx.strokeStyle = "rgba(230,220,200,0.35)";
    ctx.lineWidth = kind === "trail" ? 2.4 : 1.8;
    ctx.setLineDash(kind === "trail" ? [6, 5] : []);
    ctx.beginPath();
    ctx.moveTo(from.x, from.y);
    ctx.lineTo(to.x, to.y);
    ctx.stroke();
    ctx.setLineDash([]);
    drawHand(ctx, x, y, Math.atan2(to.y - from.y, to.x - from.x));
  } else if (kind === "hold" && to) {
    const k = 0.5 + 0.5 * Math.sin(time * 3);
    drawHand(ctx, to.x, to.y - 8, 0);
    ctx.beginPath();
    ctx.arc(to.x, to.y, to.r * (0.9 + k * 0.3), 0, Math.PI * 2);
    ctx.strokeStyle = `rgba(230,230,220,${0.25 + k * 0.25})`;
    ctx.lineWidth = 2;
    ctx.stroke();
  } else if (kind === "encircle" && to) {
    const r = to.r * 1.45;
    const a = phase * Math.PI * 2;
    const x = to.x + Math.cos(a) * r;
    const y = to.y + Math.sin(a) * r;
    ctx.strokeStyle = "rgba(210,220,200,0.3)";
    ctx.lineWidth = 1.8;
    ctx.setLineDash([5, 4]);
    ctx.beginPath();
    ctx.arc(to.x, to.y, r, 0, Math.PI * 2);
    ctx.stroke();
    ctx.setLineDash([]);
    drawHand(ctx, x, y, a + Math.PI / 2);
  }

  ctx.restore();
}

function drawHand(ctx: CanvasRenderingContext2D, x: number, y: number, ang: number): void {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(ang);
  ctx.fillStyle = "rgba(240,235,220,0.85)";
  ctx.beginPath();
  ctx.ellipse(0, 0, 7, 10, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillRect(-2.5, 8, 5, 9);
  ctx.restore();
}
