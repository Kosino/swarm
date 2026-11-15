export type HexKey = string;

export type Chamber = {
  q: number;
  r: number;
  /** 0..1 growth; 1 = built. */
  grow: number;
  growDur: number;
  amber: number;
  hatchT: number;
  hatched: boolean;
  pulse: number;
};

export type Flower = {
  x: number;
  y: number;
  r: number;
  ph: number;
  bloom: number;
  visits: number;
  tree?: boolean;
};

export type WorkerBee = {
  x: number;
  y: number;
  flower: number;
  /** 0 at hive → 1 at flower → back. */
  t: number;
  outbound: boolean;
  carrying: boolean;
  phase: number;
};

export type Route = {
  flower: number;
  glow: number;
};

export type Pulse = {
  x0: number;
  y0: number;
  x1: number;
  y1: number;
  t: number;
  dur: number;
};

export type SwarmDot = {
  a: number;
  r: number;
  spd: number;
};

export type SimMetrics = {
  time: number;
  chambers: number;
  workers: number;
  wax: number;
  routes: number;
  firstWorker: number | null;
  firstNectar: number | null;
  ringTime: number | null;
  trafficTime: number | null;
  bigFlight: boolean;
  bigFlightTime: number | null;
  ringClosed: boolean;
  traffic: boolean;
};

export type WorldSnapshot = {
  core: { x: number; y: number } | null;
  chambers: { q: number; r: number; grow: number; hatched: boolean }[];
  flowers: { x: number; y: number; tree?: boolean; bloom: number }[];
  workers: { x: number; y: number; carrying: boolean; flower: number }[];
  wax: number;
  reach: number;
  ringClosed: boolean;
  traffic: boolean;
  shivering: number;
};
