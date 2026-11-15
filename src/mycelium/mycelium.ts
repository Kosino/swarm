import {
  W,
  H,
  SPEED,
  STEP,
  MAXTIPS,
  BRANCH_P,
  SENSE,
  GUIDE_R,
  SEED_CLEAR,
} from "./config";
import type { Seg, Tip, Patch, Pulse, Ring, Speck } from "./types";

function wrap(a: number): number {
  while (a > Math.PI) a -= 2 * Math.PI;
  while (a < -Math.PI) a += 2 * Math.PI;
  return a;
}

/** Mount Build #1 mycelium sim on a canvas. Returns cleanup. */
export function startMycelium(cv: HTMLCanvasElement): () => void {
  const ctx = cv.getContext("2d");
  if (!ctx) return () => {};

  const dpr = Math.min(2, window.devicePixelRatio || 1);
  cv.width = W * dpr;
  cv.height = H * dpr;

  const patches: Patch[] = [];
  const n = 6 + Math.floor(Math.random() * 5);
  let guard = 0;
  while (patches.length < n && guard++ < 800) {
    const r = 16 + Math.random() * 14;
    const x = 70 + Math.random() * (W - 140);
    const y = 70 + Math.random() * (H - 140);
    if (patches.every((p: Patch) => Math.hypot(p.x - x, p.y - y) > 150)) {
      patches.push({ x, y, r, lit: 0, on: false, ph: Math.random() * 6 });
    }
  }
  const specks: Speck[] = Array.from({ length: 280 }, () => ({
    x: Math.random() * W,
    y: Math.random() * H,
    r: Math.random() * 1.6 + 0.3,
    a: Math.random() * 0.07 + 0.02,
  }));

  const segs: Seg[] = [];
  let tips: Tip[] = [];
  const pulses: Pulse[] = [];
  const rings: Ring[] = [];
  let seed: { x: number; y: number } | null = null;
  let seedGlow = 0;
  let guideA = 0;
  let guideW = 0;
  let dragging = false;
  let dsx = 0;
  let dsy = 0;
  let hx = W / 2;
  let hy = H / 2;
  let hovering = false;
  let time = 0;

  const addTip = (x: number, y: number, a: number, seg: number) => {
    tips.push({ x, y, a, seg, sx: x, sy: y, g: false });
  };

  const toWorld = (e: PointerEvent): [number, number] => {
    const r = cv.getBoundingClientRect();
    return [((e.clientX - r.left) / r.width) * W, ((e.clientY - r.top) / r.height) * H];
  };

  const onDown = (e: PointerEvent) => {
    const [x, y] = toWorld(e);
    cv.setPointerCapture(e.pointerId);
    if (!seed) {
      seed = { x, y };
      for (const p of patches) {
        if (Math.hypot(p.x - x, p.y - y) >= SEED_CLEAR) continue;
        for (let k = 0; k < 300; k++) {
          const nx = 70 + Math.random() * (W - 140);
          const ny = 70 + Math.random() * (H - 140);
          if (
            Math.hypot(nx - x, ny - y) >= SEED_CLEAR &&
            patches.every((q: Patch) => q === p || Math.hypot(q.x - nx, q.y - ny) > 150)
          ) {
            p.x = nx;
            p.y = ny;
            break;
          }
        }
      }
      rings.push({ x, y, t: 0, big: false });
      const k = 3;
      const base = Math.random() * Math.PI * 2;
      for (let i = 0; i < k; i++)
        addTip(x, y, base + (i * Math.PI * 2) / k + (Math.random() - 0.5) * 0.6, -1);
    }
    dragging = true;
    dsx = x;
    dsy = y;
    guideW = 0;
    for (const t of tips) t.g = Math.hypot(t.x - x, t.y - y) < GUIDE_R;
  };
  const onMove = (e: PointerEvent) => {
    const [x, y] = toWorld(e);
    hx = x;
    hy = y;
    hovering = true;
    if (!dragging || !seed) return;
    const dx = x - dsx;
    const dy = y - dsy;
    const len = Math.hypot(dx, dy);
    if (len > 12) {
      guideA = Math.atan2(dy, dx);
      guideW = 1;
    }
    if (len > 80) {
      dsx += dx * 0.4;
      dsy += dy * 0.4;
    }
  };
  const onUp = () => {
    dragging = false;
  };
  const onLeave = () => {
    hovering = false;
  };
  cv.addEventListener("pointerdown", onDown);
  cv.addEventListener("pointermove", onMove);
  cv.addEventListener("pointerup", onUp);
  cv.addEventListener("pointercancel", onUp);
  cv.addEventListener("pointerleave", onLeave);

  const anchor = (tip: Tip, p: Patch) => {
    segs.push({ x1: tip.sx, y1: tip.sy, x2: p.x, y2: p.y, p: tip.seg, th: 0 });
    const idx = segs.length - 1;
    p.on = true;
    const path: number[] = [];
    let i = idx;
    while (i >= 0) {
      path.push(i);
      i = segs[i].p;
    }
    pulses.push({ path, t: 0, dur: 0.5 + path.length * 0.012 });
    rings.push({ x: p.x, y: p.y, t: 0, big: true });
    const k = 1 + (Math.random() < 0.6 ? 1 : 0);
    const base = Math.random() * Math.PI * 2;
    for (let j = 0; j < k; j++)
      addTip(p.x, p.y, base + j * Math.PI + (Math.random() - 0.5) * 0.8, idx);
  };

  const update = (dt: number) => {
    time += dt;
    if (!dragging) guideW = Math.max(0, guideW - dt * 0.08);
    const next: Tip[] = [];
    for (const t of tips) {
      let best: Patch | null = null;
      let bd = SENSE;
      for (const p of patches) {
        if (p.on) continue;
        const d = Math.hypot(p.x - t.x, p.y - t.y);
        if (d < bd) {
          bd = d;
          best = p;
        }
      }
      if (best && bd < best.r * 0.8) {
        anchor(t, best);
        continue;
      }
      if (best) t.a += wrap(Math.atan2(best.y - t.y, best.x - t.x) - t.a) * 1.4 * (1 - bd / SENSE) * dt;
      if (guideW > 0 && t.g) t.a += wrap(guideA - t.a) * 2.6 * guideW * dt;
      const m = 30;
      if (t.x < m || t.x > W - m || t.y < m || t.y > H - m) {
        t.a += wrap(Math.atan2(H / 2 - t.y, W / 2 - t.x) - t.a) * 2.5 * dt;
      }
      t.a += (Math.random() - 0.5) * 1.2 * dt;
      t.x += Math.cos(t.a) * SPEED * dt;
      t.y += Math.sin(t.a) * SPEED * dt;
      if (Math.hypot(t.x - t.sx, t.y - t.sy) >= STEP) {
        segs.push({ x1: t.sx, y1: t.sy, x2: t.x, y2: t.y, p: t.seg, th: 0 });
        t.seg = segs.length - 1;
        t.sx = t.x;
        t.sy = t.y;
        t.a += (Math.random() - 0.5) * 0.7;
        if (tips.length + next.length < MAXTIPS && Math.random() < BRANCH_P) {
          const s = Math.random() < 0.5 ? 1 : -1;
          next.push({
            x: t.x,
            y: t.y,
            a: t.a + s * (0.5 + Math.random() * 0.4),
            seg: t.seg,
            sx: t.x,
            sy: t.y,
            g: t.g,
          });
          t.a -= s * 0.25;
        }
      }
      next.push(t);
    }
    tips = next;
    for (const p of patches) {
      if (p.on && p.lit < 1) p.lit = Math.min(1, p.lit + dt * 1.2);
    }
    for (let i = pulses.length - 1; i >= 0; i--) {
      const pu = pulses[i];
      pu.t += dt / pu.dur;
      if (pu.t >= 1) {
        for (const s of pu.path) segs[s].th += 1;
        seedGlow = 1;
        if (seed) rings.push({ x: seed.x, y: seed.y, t: 0, big: false });
        pulses.splice(i, 1);
      }
    }
    seedGlow = Math.max(0, seedGlow - dt * 1.5);
    for (let i = rings.length - 1; i >= 0; i--) {
      rings[i].t += dt;
      if (rings[i].t > (rings[i].big ? 1.2 : 0.6)) rings.splice(i, 1);
    }
  };

  const draw = () => {
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = "#242424";
    ctx.fillRect(0, 0, W, H);
    for (const s of specks) {
      ctx.fillStyle = `rgba(255,255,255,${s.a})`;
      ctx.beginPath();
      ctx.arc(s.x, s.y, s.r, 0, Math.PI * 2);
      ctx.fill();
    }
    for (const p of patches) {
      const breath = 0.5 + 0.5 * Math.sin(time * 1.3 + p.ph);
      const rr = p.r * (1.7 + p.lit * 0.9);
      const g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, rr);
      const base = 0.13 + 0.03 * breath;
      const lit = p.lit * (0.55 + 0.1 * breath);
      const c = Math.round(110 + 110 * p.lit);
      g.addColorStop(0, `rgba(${c},${c},${c},${base + lit})`);
      g.addColorStop(0.45, `rgba(${c},${c},${c},${(base + lit) * 0.6})`);
      g.addColorStop(1, "rgba(120,120,120,0)");
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(p.x, p.y, rr, 0, Math.PI * 2);
      ctx.fill();
    }
    const widths = [1, 1.7, 2.4, 3.2];
    ctx.lineCap = "round";
    ctx.strokeStyle = "rgba(205,205,205,0.78)";
    for (let b = 0; b < 4; b++) {
      ctx.lineWidth = widths[b];
      ctx.beginPath();
      for (const s of segs) {
        if (Math.min(3, s.th) !== b) continue;
        ctx.moveTo(s.x1, s.y1);
        ctx.lineTo(s.x2, s.y2);
      }
      if (b === 0) {
        for (const t of tips) {
          ctx.moveTo(t.sx, t.sy);
          ctx.lineTo(t.x, t.y);
        }
      }
      ctx.stroke();
    }
    ctx.fillStyle = "rgba(235,235,235,0.9)";
    for (const t of tips) {
      ctx.beginPath();
      ctx.arc(t.x, t.y, 1.6, 0, Math.PI * 2);
      ctx.fill();
    }
    for (const pu of pulses) {
      const len = pu.path.length;
      const head = Math.min(len - 1, Math.floor(pu.t * len));
      ctx.lineWidth = 2.6;
      for (let k = 0; k < 10; k++) {
        const i = head - k;
        if (i < 0) break;
        const s = segs[pu.path[i]];
        ctx.strokeStyle = `rgba(255,255,255,${0.9 * (1 - k / 10)})`;
        ctx.beginPath();
        ctx.moveTo(s.x1, s.y1);
        ctx.lineTo(s.x2, s.y2);
        ctx.stroke();
      }
      const hs = segs[pu.path[head]];
      const g = ctx.createRadialGradient(hs.x1, hs.y1, 0, hs.x1, hs.y1, 10);
      g.addColorStop(0, "rgba(255,255,255,0.9)");
      g.addColorStop(1, "rgba(255,255,255,0)");
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(hs.x1, hs.y1, 10, 0, Math.PI * 2);
      ctx.fill();
    }
    if (seed) {
      const r = 6 + Math.sin(time * 2) * 0.6 + seedGlow * 3;
      const g = ctx.createRadialGradient(seed.x, seed.y, 0, seed.x, seed.y, r * 3);
      g.addColorStop(0, `rgba(230,230,230,${0.35 + seedGlow * 0.4})`);
      g.addColorStop(1, "rgba(230,230,230,0)");
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(seed.x, seed.y, r * 3, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#d8d8d8";
      ctx.beginPath();
      ctx.arc(seed.x, seed.y, r, 0, Math.PI * 2);
      ctx.fill();
    } else {
      const x = hovering ? hx : W / 2;
      const y = hovering ? hy : H / 2;
      const ph = (time % 1.8) / 1.8;
      ctx.strokeStyle = `rgba(220,220,220,${0.45 * (1 - ph)})`;
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.arc(x, y, 6 + ph * 22, 0, Math.PI * 2);
      ctx.stroke();
      ctx.fillStyle = "rgba(220,220,220,0.35)";
      ctx.beginPath();
      ctx.arc(x, y, 4, 0, Math.PI * 2);
      ctx.fill();
    }
    if (dragging && seed && guideW > 0) {
      ctx.strokeStyle = "rgba(220,220,220,0.18)";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(dsx, dsy);
      ctx.lineTo(hx, hy);
      ctx.stroke();
    }
    for (const r of rings) {
      const life = r.big ? 1.2 : 0.6;
      const k = r.t / life;
      ctx.strokeStyle = `rgba(240,240,240,${0.6 * (1 - k)})`;
      ctx.lineWidth = r.big ? 2 : 1.5;
      ctx.beginPath();
      ctx.arc(r.x, r.y, (r.big ? 10 : 5) + k * (r.big ? 50 : 26), 0, Math.PI * 2);
      ctx.stroke();
    }
  };

  let last = performance.now();
  let raf = 0;
  const loop = (now: number) => {
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    update(dt);
    draw();
    raf = requestAnimationFrame(loop);
  };
  raf = requestAnimationFrame(loop);

  return () => {
    cancelAnimationFrame(raf);
    cv.removeEventListener("pointerdown", onDown);
    cv.removeEventListener("pointermove", onMove);
    cv.removeEventListener("pointerup", onUp);
    cv.removeEventListener("pointercancel", onUp);
    cv.removeEventListener("pointerleave", onLeave);
  };
}
