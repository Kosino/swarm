export type Seg = {
  x1: number;
  y1: number;
  x2: number;
  y2: number;
  p: number;
  th: number;
  /** 0 = hyfa_seg_a, 1 = hyfa_seg_b */
  v: 0 | 1;
  fuseGlow?: number;
};

export type Tip = {
  x: number;
  y: number;
  a: number;
  seg: number;
  sx: number;
  sy: number;
  g: boolean;
};

export type Patch = {
  x: number;
  y: number;
  r: number;
  lit: number;
  on: boolean;
  ph: number;
  big?: boolean;
};

export type Pulse = { path: number[]; t: number; dur: number };
export type Ring = { x: number; y: number; t: number; big: boolean };
export type Speck = { x: number; y: number; r: number; a: number };

export type Worker = {
  route: number[];
  pos: number;
  dir: 1 | -1;
  speed: number;
};

/** Midgame matter: machine / beetle / fruiting body (grey shapes). */
export type MatterKind = "machine" | "beetle" | "fruit";

export type Matter = {
  x: number;
  y: number;
  r: number;
  kind: MatterKind;
  /** 0 intact → 1 fully decayed / consumed. */
  decay: number;
  encircled: boolean;
  ph: number;
};

export type Germ = {
  x: number;
  y: number;
  lit: number;
  linked: boolean;
};

export type SimMetrics = {
  time: number;
  segs: number;
  tips: number;
  anchors: number;
  workers: number;
  firstAnchor: number | null;
  midstep: number | null;
  firstFusion: number | null;
  firstWorkers: number | null;
  bigAnchored: boolean;
  bigAnchorTime: number | null;
  /** Build #5 wow times. */
  decayTime: number | null;
  fruitTime: number | null;
  sporeTime: number | null;
  joinTime: number | null;
  hintTime: number | null;
};
