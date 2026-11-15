/** Apis build #3 — grey-shape meadow through minute 5. */
export const W = 1000;
export const H = 640;

/** Flat-top hex size (center → vertex). */
export const HEX = 26;
export const HEX_GAP = 1.5;

/** Swarm wax stock (brightness). */
export const WAX_START = 1;
export const WAX_COST = 0.35;
export const WAX_MIN = 0.3;
export const WAX_NECTAR = 0.28;
export const WAX_MAX = 1;

/** Chamber growth + hatch. */
export const BUILD_DUR_FIRST = 8;
export const BUILD_DUR = 0.95;
export const HATCH_DELAY = 12;

/** Workers / flight. */
export const WORKER_SPEED = 9.2;
export const WORKER_SPEED_RETURN = 10.4;
export const MAX_WORKERS = 200;
export const SWARM_DOTS = 10;

/** Drag reach grows with hive size. */
export const REACH_BASE = 245;
export const REACH_PER_CHAMBER = 9;
export const TREE_MIN_CHAMBERS = 24;
/** Soft attract starts ~this many chambers before reach/min. */
export const TREE_ATTRACT_LEAD = 8;

/** Living traffic / bloom. */
export const TRAFFIC_WORKERS = 11;
export const TRAFFIC_ROUTES = 3;
export const BLOOM_MAX = 18;

/** Full nectar dum/amber flood cooldown after the first. */
export const NECTAR_FULL_CD = 8;

/** Idle twitch hint toward nearest flower. */
export const TWITCH_INTERVAL = 3.2;
export const TWITCH_DUR = 0.55;

/** Roj tremor when wax too low to build. */
export const SHIVER_DUR = 0.9;

/** Camera on big flight. */
export const CAM_ZOOM_OUT = 0.7;
export const CAM_ZOOM_DUR = 3.2;

/** Sound (Web Audio). */
export const DUM_FREQ = 96;
export const DUM_FREQ_DEEP = 48;
export const DUM_DUR = 0.3;
export const BZZ_FREQ = 180;
export const BZZ_DUR = 0.18;
export const CHIME_FREQ = 520;
export const CHIME_DUR = 0.35;

/** Flower / tree layout. */
export const FLOWER_MIN = 8;
export const FLOWER_MAX = 12;
export const FLOWER_R = 11;
export const TREE_R = 36;
export const TREE_EDGE = 56;
