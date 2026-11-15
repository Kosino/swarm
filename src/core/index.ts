export { mountCanvas } from "./loop";
export type { GameWorld, MountOpts } from "./loop";
export { createDemoControls, resolveDemoMode } from "./demo";
export type { DemoControls, DemoSpeed } from "./demo";
export {
  drawGuidePulse,
  drawGhostHand,
  fmtGameTime,
  IDLE_GHOST_S,
  MAX_GHOST_PERFORMS,
} from "./guidance";
export type { GuidanceInfo, GuideTarget, GhostKind, WowEvent } from "./guidance";
