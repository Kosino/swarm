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
export {
  ENC_CLOSE_PX,
  ENC_ANGLE_FRAC,
  ENC_OUTLINE_FRAC,
  SNAP_BASE,
  TRAIL_FINISH_PX,
  HAND_JITTER,
  HAND_UNDERSHOOT,
  pathLength,
  pointInPoly,
  smoothResample,
  angularCoverage,
  outlineCoverage,
  loopClosed,
  encircleRecognized,
  snapRadius,
  nearestTarget,
  spawnMiss,
  tickMiss,
  drawMissFx,
  noisyLoop,
  noisyConnect,
} from "./gestures";
export type { Pt, PointerMeta, MissFx } from "./gestures";
