export type Seg = { x1: number; y1: number; x2: number; y2: number; p: number; th: number };
export type Tip = { x: number; y: number; a: number; seg: number; sx: number; sy: number; g: boolean };
export type Patch = { x: number; y: number; r: number; lit: number; on: boolean; ph: number };
export type Pulse = { path: number[]; t: number; dur: number };
export type Ring = { x: number; y: number; t: number; big: boolean };
export type Speck = { x: number; y: number; r: number; a: number };
