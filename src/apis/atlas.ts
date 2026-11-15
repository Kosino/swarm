/** Apis v1 texture atlas — 1x + _2x frames. */

export type AtlasFrame = {
  x: number;
  y: number;
  w: number;
  h: number;
  ox: number;
  oy: number;
  srcW: number;
  srcH: number;
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

export type ApisAtlas = {
  image: CanvasImageSource;
  ready: boolean;
  frame: (base: string, hiDpi: boolean) => AtlasFrame | null;
};

const BASE = "apis_";

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

export function createAtlas(image: CanvasImageSource, json: AtlasJson): ApisAtlas {
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

export async function loadApisAtlas(baseUrl = "./art/atlas_apis_v1"): Promise<ApisAtlas> {
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

/** Draw frame centered at (cx, cy). */
export function drawCentered(
  ctx: CanvasRenderingContext2D,
  atlas: ApisAtlas,
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
