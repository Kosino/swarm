/** Mycelium v2 texture atlas — 1x + _2x frames. */

export type AtlasFrame = {
  x: number;
  y: number;
  w: number;
  h: number;
  ox: number;
  oy: number;
  srcW: number;
  srcH: number;
  /** Logical draw size (CSS px); half of src for _2x. */
  logicW: number;
  logicH: number;
};

type RawFrame = {
  frame: { x: number; y: number; w: number; h: number };
  spriteSourceSize: { x: number; y: number; w: number; h: number };
  sourceSize: { w: number; h: number };
};

type AtlasJson = {
  frames: Record<string, RawFrame>;
  meta: { image: string; size: { w: number; h: number } };
};

export type MycAtlas = {
  image: CanvasImageSource;
  ready: boolean;
  frame: (base: string, hiDpi: boolean) => AtlasFrame | null;
};

const BASE = "myc_";

function toFrame(raw: RawFrame, hiDpi: boolean): AtlasFrame {
  const scale = hiDpi ? 2 : 1;
  return {
    x: raw.frame.x,
    y: raw.frame.y,
    w: raw.frame.w,
    h: raw.frame.h,
    ox: raw.spriteSourceSize.x,
    oy: raw.spriteSourceSize.y,
    srcW: raw.sourceSize.w,
    srcH: raw.sourceSize.h,
    logicW: raw.sourceSize.w / scale,
    logicH: raw.sourceSize.h / scale,
  };
}

export function createAtlas(image: CanvasImageSource, json: AtlasJson): MycAtlas {
  const map = new Map<string, { x1: AtlasFrame; x2: AtlasFrame | null }>();
  for (const [key, raw] of Object.entries(json.frames)) {
    const hi = key.endsWith("_2x");
    const base = hi ? key.slice(0, -3) : key;
    let slot = map.get(base);
    if (!slot) {
      slot = { x1: toFrame(raw, false), x2: null };
      map.set(base, slot);
    }
    if (hi) slot.x2 = toFrame(raw, true);
    else slot.x1 = toFrame(raw, false);
  }

  return {
    image,
    ready: true,
    frame(base: string, hiDpi: boolean): AtlasFrame | null {
      const key = base.startsWith(BASE) ? base : BASE + base;
      const slot = map.get(key);
      if (!slot) return null;
      if (hiDpi && slot.x2) return slot.x2;
      return slot.x1;
    },
  };
}

export async function loadMyceliumAtlas(
  baseUrl = "./art/atlas_mycelium_v2",
): Promise<MycAtlas> {
  const [img, json] = await Promise.all([
    loadImage(`${baseUrl}.png`),
    fetch(`${baseUrl}.json`).then((r) => {
      if (!r.ok) throw new Error(`atlas json ${r.status}`);
      return r.json() as Promise<AtlasJson>;
    }),
  ]);
  return createAtlas(img, json);
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error(`Failed to load ${src}`));
    img.src = src;
  });
}

/** Draw frame centered at (cx, cy), optional rotation / uniform scale / alpha. */
export function drawCentered(
  ctx: CanvasRenderingContext2D,
  atlas: MycAtlas,
  fr: AtlasFrame,
  cx: number,
  cy: number,
  opts: { rot?: number; scale?: number; alpha?: number } = {},
): void {
  const scale = opts.scale ?? 1;
  const rot = opts.rot ?? 0;
  const alpha = opts.alpha ?? 1;
  const dw = fr.logicW * scale;
  const dh = fr.logicH * scale;
  const ox = (fr.ox / fr.srcW) * dw;
  const oy = (fr.oy / fr.srcH) * dh;
  const fw = (fr.w / fr.srcW) * dw;
  const fh = (fr.h / fr.srcH) * dh;
  ctx.save();
  if (alpha < 1) ctx.globalAlpha *= alpha;
  ctx.translate(cx, cy);
  if (rot) ctx.rotate(rot);
  ctx.drawImage(atlas.image, fr.x, fr.y, fr.w, fr.h, -dw / 2 + ox, -dh / 2 + oy, fw, fh);
  ctx.restore();
}

/**
 * Stretch a hypha segment sprite from (x1,y1)→(x2,y2).
 * Thickness is logical height in px (density).
 */
export function drawSegSprite(
  ctx: CanvasRenderingContext2D,
  atlas: MycAtlas,
  fr: AtlasFrame,
  x1: number,
  y1: number,
  x2: number,
  y2: number,
  thickness: number,
  alpha = 1,
): void {
  const dx = x2 - x1;
  const dy = y2 - y1;
  const len = Math.hypot(dx, dy);
  if (len < 0.5) return;
  const ang = Math.atan2(dy, dx);
  // Trimmed content height relative to full cell
  const contentH = (fr.h / fr.srcH) * thickness;
  const contentY = ((fr.oy + fr.h / 2) / fr.srcH) * thickness - contentH / 2;
  ctx.save();
  if (alpha < 1) ctx.globalAlpha *= alpha;
  ctx.translate(x1, y1);
  ctx.rotate(ang);
  ctx.drawImage(
    atlas.image,
    fr.x,
    fr.y,
    fr.w,
    fr.h,
    0,
    -thickness / 2 + contentY,
    len,
    contentH,
  );
  ctx.restore();
}

/** Tip sprite with nose along `angle`, pivot near trailing edge. */
export function drawTipSprite(
  ctx: CanvasRenderingContext2D,
  atlas: MycAtlas,
  fr: AtlasFrame,
  x: number,
  y: number,
  angle: number,
  scale: number,
  alpha = 1,
): void {
  const dw = fr.logicW * scale;
  const dh = fr.logicH * scale;
  const ox = (fr.ox / fr.srcW) * dw;
  const oy = (fr.oy / fr.srcH) * dh;
  const fw = (fr.w / fr.srcW) * dw;
  const fh = (fr.h / fr.srcH) * dh;
  ctx.save();
  if (alpha < 1) ctx.globalAlpha *= alpha;
  ctx.translate(x, y);
  ctx.rotate(angle);
  // Tip art points +X; place trailing edge at origin so nose leads.
  ctx.drawImage(atlas.image, fr.x, fr.y, fr.w, fr.h, -fw * 0.15 + ox, -dh / 2 + oy, fw, fh);
  ctx.restore();
}
