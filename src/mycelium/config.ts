/** Build #1 mycelium params — keep 1:1 with approved prototype. */
export const W = 1000;
export const H = 640;
export const SPEED = 10;
export const STEP = 7;
export const MAXTIPS = 20;
export const BRANCH_P = 0.005;
export const SENSE = 70;
export const GUIDE_R = 150;
export const SEED_CLEAR = 200;

/** Build #2 — fusion, hold densify, workers, big anchor, sound. */
export const FUSION_R = 8;
export const FUSION_MIN_T = 120;
export const FUSION_COOLDOWN = 0.35;
export const HOLD_S = 0.6;
export const HOLD_R = 150;
export const HOLD_SPEED_MUL = 2.4;
export const HOLD_BRANCH_MUL = 3.5;
export const HOLD_STEER = 1.8;
/** Fertility: after first fusion, once the network is dense enough and a beat has passed. */
export const WORKER_MIN_SEGS = 1500;
/** Minimum seconds after first fusion before workers (keeps fusion→workers gap ≤90s). */
export const WORKER_DELAY = 78;
export const MAX_WORKERS = 150;
export const WORKER_SPAWN_RATE = 0.75;
export const WORKER_SPEED = 55;
export const BIG_APPEAR_T = 235;
export const BIG_R = 32;
export const BIG_EDGE = 48;
export const CAM_ZOOM_OUT = 0.72;
export const CAM_ZOOM_DUR = 2.8;
export const DUM_FREQ = 108;
export const DUM_FREQ_BIG = 52;
export const DUM_DUR = 0.28;

/** Build #5 — encircle midgame (minutes 5–10). */
/** Jump target for ?start=5 (~4:40 after big anchor). */
export const START5_T = 280;
/** Encircle stroke: min path length to count as a loop. */
export const ENC_MIN_LEN = 140;
/** Close the loop when pointer returns within this of stroke start (~60px). */
export const ENC_CLOSE_R = 60;
/** Min samples on encircle path. */
export const ENC_MIN_PTS = 10;
/** Connect magnetic snap base (logical px; × DPR, larger on touch). */
export const CONNECT_SNAP = 40;
/** Matter (machine / beetle) radii. */
export const MATTER_R_MACHINE = 28;
export const MATTER_R_BEETLE = 36;
/** Hyphae slide on matter surface instead of piercing (pre-decay). */
export const MATTER_SLIDE_R = 1.15;
/** Target wow times (seconds) — headless aims near these. */
export const WOW_DECAY = 345;
export const WOW_FRUIT = 420;
export const WOW_SPORE = 495;
export const WOW_JOIN = 560;
export const WOW_HINT = 600;
/** Spore rain: new germs spawned. */
export const SPORE_GERMS = 4;
/** Heartbeat after network join. */
export const JOIN_PULSE_PERIOD = 1.85;
/** Foreign network hint duration. */
export const HINT_DUR = 3.2;
