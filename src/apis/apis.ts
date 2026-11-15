import {
  W,
  H,
  HEX,
  HEX_GAP,
  WAX_START,
  WAX_COST,
  WAX_MIN,
  WAX_NECTAR,
  WAX_MAX,
  BUILD_DUR_FIRST,
  BUILD_DUR,
  HATCH_DELAY,
  WORKER_SPEED,
  WORKER_SPEED_RETURN,
  MAX_WORKERS,
  SWARM_DOTS,
  REACH_BASE,
  REACH_PER_CHAMBER,
  TREE_MIN_CHAMBERS,
  TREE_ATTRACT_LEAD,
  TRAFFIC_WORKERS,
  TRAFFIC_ROUTES,
  BLOOM_MAX,
  NECTAR_FULL_CD,
  TWITCH_INTERVAL,
  TWITCH_DUR,
  SHIVER_DUR,
  CAM_ZOOM_OUT,
  CAM_ZOOM_DUR,
  FLOWER_MIN,
  FLOWER_MAX,
  FLOWER_R,
  TREE_R,
  TREE_EDGE,
  START5_T,
  TRAIL_MAX_SPEED,
  TRAIL_MIN_LEN,
  TRAIL_MIN_PTS,
  TRAIL_BUILD_SPACING,
  TRAIL_BUILD_RATE,
  MEADOW2_DIST,
  HINT_DUR,
} from "./config";
import { playDum, playBzz, playChime, playSoft } from "./sound";
import type {
  Chamber,
  Flower,
  WorkerBee,
  Route,
  Pulse,
  SwarmDot,
  SimMetrics,
  WorldSnapshot,
  HexKey,
  PheromoneTrail,
  TrailPt,
} from "./types";
import { mountCanvas } from "../core";

const RING: [number, number][] = [
  [1, 0],
  [1, -1],
  [0, -1],
  [-1, 0],
  [-1, 1],
  [0, 1],
];

function hexKey(q: number, r: number): HexKey {
  return `${q},${r}`;
}

function axialToPixel(q: number, r: number, cx: number, cy: number): [number, number] {
  const size = HEX + HEX_GAP;
  const x = size * (1.5 * q) + cx;
  const y = size * ((Math.sqrt(3) / 2) * q + Math.sqrt(3) * r) + cy;
  return [x, y];
}

function pixelToAxial(x: number, y: number, cx: number, cy: number): [number, number] {
  const size = HEX + HEX_GAP;
  const px = x - cx;
  const py = y - cy;
  const q = ((2 / 3) * px) / size;
  const r = ((-1 / 3) * px + (Math.sqrt(3) / 3) * py) / size;
  return hexRound(q, r);
}

function hexRound(q: number, r: number): [number, number] {
  const s = -q - r;
  let rq = Math.round(q);
  let rr = Math.round(r);
  const rs = Math.round(s);
  const dq = Math.abs(rq - q);
  const dr = Math.abs(rr - r);
  const ds = Math.abs(rs - s);
  if (dq > dr && dq > ds) rq = -rr - rs;
  else if (dr > ds) rr = -rq - rs;
  return [rq, rr];
}

function neighbors(q: number, r: number): [number, number][] {
  return RING.map(([dq, dr]) => [q + dq, r + dr]);
}

export type WorldOpts = {
  silent?: boolean;
  rng?: () => number;
  /** Fast-forward / bootstrap to ~4:40 midgame (?start=5). */
  startAt?: number;
};

export type ApisWorld = {
  update: (dt: number) => void;
  draw: (ctx: CanvasRenderingContext2D, dpr: number) => void;
  pointerDown: (x: number, y: number) => void;
  pointerMove: (x: number, y: number) => void;
  pointerUp: () => void;
  metrics: () => SimMetrics;
  snapshot: () => WorldSnapshot;
  stressFill: (workerCount: number) => void;
  bootstrapStart5: () => void;
};

function pathLen(pts: TrailPt[]): number {
  let len = 0;
  for (let i = 1; i < pts.length; i++) {
    len += Math.hypot(pts[i]!.x - pts[i - 1]!.x, pts[i]!.y - pts[i - 1]!.y);
  }
  return len;
}

export function createApisWorld(opts: WorldOpts = {}): ApisWorld {
  const rnd = opts.rng ?? Math.random;
  const silent = !!opts.silent;

  const cx = W * 0.5;
  const cy = H * 0.48;

  const flowers: Flower[] = [];
  const nFlowers = FLOWER_MIN + Math.floor(rnd() * (FLOWER_MAX - FLOWER_MIN + 1));
  let guard = 0;
  // Near / mid / far bands so first nectar ~1:20 and later routes stretch out.
  const bands = [
    { min: 210, max: 250, n: 3 },
    { min: 270, max: 330, n: 4 },
    { min: 350, max: 430, n: nFlowers - 7 },
  ];
  for (const band of bands) {
    let placed = 0;
    let tries = 0;
    while (placed < Math.max(0, band.n) && tries++ < 400) {
      const ang = rnd() * Math.PI * 2;
      const dist = band.min + rnd() * (band.max - band.min);
      const x = cx + Math.cos(ang) * dist;
      const y = cy + Math.sin(ang) * dist * 0.82;
      if (x < 40 || x > W - 40 || y < 40 || y > H - 40) continue;
      if (flowers.every((f) => Math.hypot(f.x - x, f.y - y) > 70)) {
        flowers.push({
          x,
          y,
          r: FLOWER_R * (0.85 + rnd() * 0.35),
          ph: rnd() * 6,
          bloom: 0.25 + rnd() * 0.2,
          visits: 0,
          hint: 0,
        });
        placed++;
      }
    }
  }
  while (flowers.length < nFlowers && guard++ < 900) {
    const ang = rnd() * Math.PI * 2;
    const dist = 240 + rnd() * 160;
    const x = cx + Math.cos(ang) * dist;
    const y = cy + Math.sin(ang) * dist * 0.82;
    if (x < 40 || x > W - 40 || y < 40 || y > H - 40) continue;
    if (flowers.every((f) => Math.hypot(f.x - x, f.y - y) > 70)) {
      flowers.push({
        x,
        y,
        r: FLOWER_R * (0.85 + rnd() * 0.35),
        ph: rnd() * 6,
        bloom: 0.25 + rnd() * 0.2,
        visits: 0,
        hint: 0,
      });
    }
  }

  // Golden tree in far corner opposite densest flower cluster mean
  {
    const mx = flowers.reduce((s, f) => s + f.x, 0) / Math.max(1, flowers.length);
    const my = flowers.reduce((s, f) => s + f.y, 0) / Math.max(1, flowers.length);
    const corners: [number, number][] = [
      [TREE_EDGE + TREE_R, TREE_EDGE + TREE_R],
      [W - TREE_EDGE - TREE_R, TREE_EDGE + TREE_R],
      [TREE_EDGE + TREE_R, H - TREE_EDGE - TREE_R],
      [W - TREE_EDGE - TREE_R, H - TREE_EDGE - TREE_R],
    ];
    let best = corners[0];
    let bd = -1;
    for (const c of corners) {
      const d = Math.hypot(c[0] - mx, c[1] - my) + Math.hypot(c[0] - cx, c[1] - cy) * 0.3;
      if (d > bd) {
        bd = d;
        best = c;
      }
    }
    flowers.push({
      x: best[0],
      y: best[1],
      r: TREE_R,
      ph: rnd() * 6,
      bloom: 0.55,
      visits: 0,
      tree: true,
      hint: 0,
    });
  }

  const chambers = new Map<HexKey, Chamber>();
  const workers: WorkerBee[] = [];
  const routes: Route[] = [];
  const pulses: Pulse[] = [];
  const swarm: SwarmDot[] = Array.from({ length: SWARM_DOTS }, () => ({
    a: rnd() * Math.PI * 2,
    r: 14 + rnd() * 18,
    spd: 0.7 + rnd() * 1.1,
  }));

  let core: { x: number; y: number } | null = null;
  let planted = false;
  let wax = WAX_START;
  let time = 0;
  let shiver = 0;
  let corePulse = 0;
  let ringClosed = false;
  let ringTime: number | null = null;
  let traffic = false;
  let trafficTime: number | null = null;
  let firstWorker: number | null = null;
  let firstNectar: number | null = null;
  let lastFullNectar = -NECTAR_FULL_CD;
  let bigFlight = false;
  let bigFlightTime: number | null = null;
  let bigFlightT = 0;
  let camZoom = 1;
  let camZoomTarget = 1;
  let hiveScale = 1;
  let treeAttract = false;
  let treeAttractPulse = 0;
  let lastChime = -10;
  let twitchCd = TWITCH_INTERVAL * 0.4;

  let dragging = false;
  let dsx = 0;
  let dsy = 0;
  let hx = cx;
  let hy = cy;
  let pulseHexGlow = 1;

  /** Build #5 midgame. */
  const trails: PheromoneTrail[] = [];
  let strokePts: TrailPt[] = [];
  let strokeT0 = 0;
  let strokeLen = 0;
  let meadow2: { x: number; y: number; r: number } | null = null;
  let secondHive: { x: number; y: number; chambers: number; pulse: number } | null = null;
  let highwayGlow = 0;
  let trailTime: number | null = null;
  let floor2Time: number | null = null;
  let swarmTime: number | null = null;
  let joinTime: number | null = null;
  let hintTime: number | null = null;
  let dusk = 0;
  let rustChamber: HexKey | null = null;
  let floor2 = false;
  let meadowBloom = 0;
  let hivePulseSync = 0;

  const dum = (deep: boolean) => {
    if (!silent) playDum(deep);
  };

  const soft = (kind: "open" | "copper" | "dual" | "chord" | "wind") => {
    if (!silent) playSoft(kind);
  };

  const spawnMeadow2 = () => {
    if (meadow2 || !core) return;
    const tree = flowers.find((f) => f.tree);
    const ang = tree
      ? Math.atan2(tree.y - cy, tree.x - cx) + Math.PI * 0.55
      : rnd() * Math.PI * 2;
    let x = cx + Math.cos(ang) * MEADOW2_DIST;
    let y = cy + Math.sin(ang) * MEADOW2_DIST * 0.82;
    x = Math.max(80, Math.min(W - 80, x));
    y = Math.max(70, Math.min(H - 70, y));
    meadow2 = { x, y, r: 48 };
    // Extra distant flowers in second meadow
    for (let i = 0; i < 5; i++) {
      const a = rnd() * Math.PI * 2;
      const d = 20 + rnd() * 40;
      flowers.push({
        x: x + Math.cos(a) * d,
        y: y + Math.sin(a) * d * 0.8,
        r: FLOWER_R * (0.9 + rnd() * 0.3),
        ph: rnd() * 6,
        bloom: 0.35,
        visits: 0,
        hint: 0,
      });
    }
  };

  const classifyTrail = (pts: TrailPt[]): PheromoneTrail["kind"] => {
    if (!core) return "meadow";
    const last = pts[pts.length - 1]!;
    const first = pts[0]!;
    const len = pathLen(pts);
    // Arc around hive: angular sweep, stays near hive
    const a0 = Math.atan2(first.y - cy, first.x - cx);
    const a1 = Math.atan2(last.y - cy, last.x - cx);
    let da = Math.abs(a1 - a0);
    if (da > Math.PI) da = Math.PI * 2 - da;
    const meanDist =
      pts.reduce((s, p) => s + Math.hypot(p.x - cx, p.y - cy), 0) / pts.length;
    if (trailTime !== null && floor2Time === null && da > 1.1 && meanDist < 150) return "arc";
    // After floor2: long outward trail → highway / second hive
    if (floor2Time !== null && swarmTime === null && len >= TRAIL_MIN_LEN) {
      const outward = Math.hypot(last.x - cx, last.y - cy) > 200;
      const nearMeadow = meadow2 && Math.hypot(last.x - meadow2.x, last.y - meadow2.y) < 120;
      if (outward || nearMeadow) return "highway";
    }
    // After swarm: trail closing the gap → join
    if (swarmTime !== null && joinTime === null && secondHive && len >= TRAIL_MIN_LEN * 0.7) {
      if (Math.hypot(last.x - secondHive.x, last.y - secondHive.y) < 140) return "join";
      return "join";
    }
    if (meadow2 && Math.hypot(last.x - meadow2.x, last.y - meadow2.y) < 90) {
      if (secondHive && joinTime === null) return "join";
      if (swarmTime === null) return "highway";
    }
    return "meadow";
  };

  const buildAlongTrail = (trail: PheromoneTrail, targetBuilt: number) => {
    if (!core) return;
    while (trail.built < targetBuilt - 0.001) {
      const u = Math.min(0.999, trail.built + 0.02);
      // Position along polyline
      const total = pathLen(trail.pts);
      let remain = u * total;
      let x = trail.pts[0]!.x;
      let y = trail.pts[0]!.y;
      for (let i = 1; i < trail.pts.length; i++) {
        const d = Math.hypot(trail.pts[i]!.x - trail.pts[i - 1]!.x, trail.pts[i]!.y - trail.pts[i - 1]!.y);
        if (remain <= d) {
          const t = d > 0 ? remain / d : 0;
          x = trail.pts[i - 1]!.x + (trail.pts[i]!.x - trail.pts[i - 1]!.x) * t;
          y = trail.pts[i - 1]!.y + (trail.pts[i]!.y - trail.pts[i - 1]!.y) * t;
          break;
        }
        remain -= d;
        x = trail.pts[i]!.x;
        y = trail.pts[i]!.y;
      }
      const [q, r] = pixelToAxial(x, y, cx, cy);
      if (isAdjacentToHive(q, r) || (trail.kind !== "meadow" && !chambers.has(hexKey(q, r)))) {
        // Allow build if adjacent OR near existing for trail growth
        if (!chambers.has(hexKey(q, r))) {
          const adj = isAdjacentToHive(q, r);
          if (adj && wax >= WAX_MIN * 0.5) {
            chambers.set(hexKey(q, r), {
              q,
              r,
              grow: 0,
              growDur: BUILD_DUR * 0.75,
              amber: 0.15,
              hatchT: 0,
              hatched: false,
              pulse: 0.4,
            });
            wax = Math.max(0.15, wax - WAX_COST * 0.55);
          } else if (!adj) {
            // Find nearest adjacent cell toward this point
            let best: [number, number] | null = null;
            let bd = Infinity;
            for (const ch of chambers.values()) {
              if (ch.grow < 1) continue;
              for (const [nq, nr] of neighbors(ch.q, ch.r)) {
                if (nq === 0 && nr === 0) continue;
                if (chambers.has(hexKey(nq, nr))) continue;
                const [px, py] = axialToPixel(nq, nr, cx, cy);
                const d = Math.hypot(px - x, py - y);
                if (d < bd && d < TRAIL_BUILD_SPACING * 1.6) {
                  bd = d;
                  best = [nq, nr];
                }
              }
            }
            if (best && wax >= WAX_MIN * 0.4) {
              chambers.set(hexKey(best[0], best[1]), {
                q: best[0],
                r: best[1],
                grow: 0,
                growDur: BUILD_DUR * 0.7,
                amber: 0.2,
                hatchT: 0,
                hatched: false,
                pulse: 0.5,
              });
              wax = Math.max(0.15, wax - WAX_COST * 0.5);
            }
          }
        }
      }
      trail.built = Math.min(1, trail.built + TRAIL_BUILD_SPACING / Math.max(total, 1));
      if (trail.built >= targetBuilt) break;
      if (trail.built >= 1) break;
    }
  };

  const activateTrail = (pts: TrailPt[]) => {
    if (pts.length < TRAIL_MIN_PTS || pathLen(pts) < TRAIL_MIN_LEN) return false;
    const kind = classifyTrail(pts);
    const trail: PheromoneTrail = { pts: pts.map((p) => ({ ...p })), glow: 1, built: 0, kind };
    trails.push(trail);

    if (kind === "meadow" && trailTime === null) {
      trailTime = time;
      soft("open");
      wax = Math.min(WAX_MAX, wax + 0.35);
    } else if (kind === "arc" && floor2Time === null) {
      floor2Time = time;
      floor2 = true;
      hiveScale = Math.max(hiveScale, 1.32);
      corePulse = 1;
      soft("copper");
      dum(true);
      // Wrap second-floor ring (outer neighbors of RING)
      for (const [q, r] of RING) {
        for (const [nq, nr] of neighbors(q, r)) {
          if (nq === 0 && nr === 0) continue;
          if (RING.some(([rq, rr]) => rq === nq && rr === nr)) continue;
          const k = hexKey(nq, nr);
          if (chambers.has(k)) continue;
          // Only a subset around the arc
          const [px, py] = axialToPixel(nq, nr, cx, cy);
          if (pts.some((p) => Math.hypot(p.x - px, p.y - py) < 55)) {
            chambers.set(k, {
              q: nq,
              r: nr,
              grow: 0,
              growDur: BUILD_DUR * 0.85,
              amber: 0.25,
              hatchT: 0,
              hatched: false,
              pulse: 0.6,
            });
          }
        }
      }
    } else if (kind === "highway" && swarmTime === null) {
      swarmTime = time;
      soft("dual");
      const last = pts[pts.length - 1]!;
      secondHive = {
        x: meadow2 ? meadow2.x : last.x,
        y: meadow2 ? meadow2.y : last.y,
        chambers: 3,
        pulse: 1,
      };
      highwayGlow = 1;
      // Send some workers toward second hive
      let sent = 0;
      for (const w of workers) {
        if (sent >= Math.floor(workers.length * 0.35)) break;
        if (w.flower >= 0 && rnd() < 0.5) continue;
        w.flower = -2; // special: fly to second hive
        w.t = 0;
        w.outbound = true;
        w.carrying = false;
        sent++;
      }
    } else if (kind === "join" && joinTime === null && secondHive) {
      joinTime = time;
      soft("chord");
      highwayGlow = 1.4;
      hivePulseSync = 1;
      meadowBloom = 1;
      corePulse = 1;
      secondHive.pulse = 1;
      for (const f of flowers) {
        if (!f.tree) f.bloom = Math.min(1, f.bloom + 0.55);
      }
      // Extra bloom flowers between hives
      for (let i = 0; i < 8; i++) {
        const t = 0.2 + rnd() * 0.6;
        const x = cx + (secondHive.x - cx) * t + (rnd() - 0.5) * 60;
        const y = cy + (secondHive.y - cy) * t + (rnd() - 0.5) * 50;
        if (x < 30 || x > W - 30 || y < 30 || y > H - 30) continue;
        flowers.push({
          x,
          y,
          r: FLOWER_R * (0.8 + rnd() * 0.4),
          ph: rnd() * 6,
          bloom: 0.7,
          visits: 0,
          hint: 0,
        });
      }
    }
    return true;
  };

  const triggerDuskHint = () => {
    if (hintTime !== null) return;
    hintTime = time;
    soft("wind");
    dusk = 1;
    // Rust on a far chamber
    let far: Chamber | null = null;
    let bd = -1;
    for (const ch of chambers.values()) {
      if (ch.grow < 1) continue;
      const [px, py] = axialToPixel(ch.q, ch.r, cx, cy);
      const d = Math.hypot(px - cx, py - cy);
      if (d > bd) {
        bd = d;
        far = ch;
      }
    }
    if (far) rustChamber = hexKey(far.q, far.r);
  };

  const builtCount = () => {
    let n = 0;
    for (const c of chambers.values()) if (c.grow >= 1) n++;
    return n;
  };

  const reach = () => REACH_BASE + builtCount() * REACH_PER_CHAMBER;

  const hiveCenter = (): [number, number] => (core ? [core.x, core.y] : [cx, cy]);

  const isAdjacentToHive = (q: number, r: number): boolean => {
    if (!planted) return q === 0 && r === 0;
    if (q === 0 && r === 0) return false;
    if (chambers.has(hexKey(q, r))) return false;
    for (const [nq, nr] of neighbors(q, r)) {
      if (nq === 0 && nr === 0) return true;
      const ch = chambers.get(hexKey(nq, nr));
      if (ch && ch.grow >= 1) return true;
    }
    return false;
  };

  const tryBuild = (q: number, r: number): boolean => {
    if (!planted) {
      if (q !== 0 || r !== 0) return false;
      planted = true;
      core = { x: cx, y: cy };
      // First chamber is one ring neighbor — pick nearest to a flower for bot friendliness
      let best: [number, number] = RING[0];
      let bd = Infinity;
      for (const cell of RING) {
        const [px, py] = axialToPixel(cell[0], cell[1], cx, cy);
        for (const f of flowers) {
          if (f.tree) continue;
          const d = Math.hypot(f.x - px, f.y - py);
          if (d < bd) {
            bd = d;
            best = cell;
          }
        }
      }
      const key = hexKey(best[0], best[1]);
      chambers.set(key, {
        q: best[0],
        r: best[1],
        grow: 0,
        growDur: BUILD_DUR_FIRST,
        amber: 0,
        hatchT: 0,
        hatched: false,
        pulse: 0,
      });
      wax = Math.max(0, wax - WAX_COST);
      return true;
    }

    if (!isAdjacentToHive(q, r)) return false;
    if (chambers.has(hexKey(q, r))) return false;
    if (wax < WAX_MIN) {
      shiver = SHIVER_DUR;
      if (!silent) playBzz();
      return false;
    }

    chambers.set(hexKey(q, r), {
      q,
      r,
      grow: 0,
      growDur: BUILD_DUR,
      amber: 0,
      hatchT: 0,
      hatched: false,
      pulse: 0,
    });
    wax = Math.max(0, wax - WAX_COST);
    return true;
  };

  const checkRing = () => {
    if (ringClosed) return;
    let ok = true;
    for (const [q, r] of RING) {
      const ch = chambers.get(hexKey(q, r));
      if (!ch || ch.grow < 1) {
        ok = false;
        break;
      }
    }
    if (!ok) return;
    ringClosed = true;
    ringTime = time;
    hiveScale = 1.18;
    corePulse = 1;
    dum(true);
  };

  const checkTraffic = () => {
    if (traffic) return;
    if (workers.length >= TRAFFIC_WORKERS && routes.length >= TRAFFIC_ROUTES) {
      traffic = true;
      trafficTime = time;
    }
  };

  const spawnBloom = () => {
    if (flowers.filter((f) => !f.tree).length >= BLOOM_MAX) return;
    if (!traffic && routes.length < 2) return;
    // Bloom near active routes
    for (const route of routes) {
      if (flowers.filter((f) => !f.tree).length >= BLOOM_MAX) break;
      const f = flowers[route.flower];
      if (!f || f.tree) continue;
      const [hx0, hy0] = hiveCenter();
      const t = 0.35 + rnd() * 0.4;
      const bx = hx0 + (f.x - hx0) * t + (rnd() - 0.5) * 50;
      const by = hy0 + (f.y - hy0) * t + (rnd() - 0.5) * 40;
      if (bx < 30 || bx > W - 30 || by < 30 || by > H - 30) continue;
      if (flowers.every((o) => Math.hypot(o.x - bx, o.y - by) > 55)) {
        flowers.push({
          x: bx,
          y: by,
          r: FLOWER_R * (0.7 + rnd() * 0.4),
          ph: rnd() * 6,
          bloom: 0.15,
          visits: 0,
          hint: 0,
        });
      }
    }
  };

  const assignRoute = (flowerIdx: number) => {
    if (flowerIdx < 0 || flowerIdx >= flowers.length) return false;
    const f = flowers[flowerIdx];
    const [hx0, hy0] = hiveCenter();
    const dist = Math.hypot(f.x - hx0, f.y - hy0);
    const rch = reach();
    if (dist > rch + 8) return false;

    if (f.tree) {
      if (builtCount() < TREE_MIN_CHAMBERS) return false;
      if (!bigFlight) {
        bigFlight = true;
        bigFlightTime = time;
        bigFlightT = 0;
        camZoomTarget = CAM_ZOOM_OUT;
        wax = Math.min(WAX_MAX, wax + 0.55);
        for (const ch of chambers.values()) ch.amber = Math.min(1, ch.amber + 0.7);
        corePulse = 1;
        dum(true);
      }
      return true;
    }

    if (!routes.some((rt) => rt.flower === flowerIdx)) {
      routes.push({ flower: flowerIdx, glow: 0.4 });
    }

    // Send idle workers on this route
    for (const w of workers) {
      if (w.flower < 0) {
        w.flower = flowerIdx;
        w.t = 0;
        w.outbound = true;
        w.carrying = false;
      }
    }
    return true;
  };

  const nearestFlowerIdx = (x: number, y: number, maxDist: number): number => {
    let best = -1;
    let bd = maxDist;
    for (let i = 0; i < flowers.length; i++) {
      const d = Math.hypot(flowers[i].x - x, flowers[i].y - y);
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  };

  const update = (dt: number) => {
    time += dt;
    if (shiver > 0) shiver = Math.max(0, shiver - dt);
    if (corePulse > 0) corePulse = Math.max(0, corePulse - dt * 0.7);
    pulseHexGlow = 0.55 + 0.45 * Math.sin(time * 2.4);

    camZoom += (camZoomTarget - camZoom) * Math.min(1, dt / (CAM_ZOOM_DUR * 0.35));
    if (bigFlight) bigFlightT += dt;

    // Grow chambers + hatch
    for (const ch of chambers.values()) {
      if (ch.grow < 1) {
        ch.grow = Math.min(1, ch.grow + dt / ch.growDur);
        if (ch.grow >= 1) {
          ch.grow = 1;
          checkRing();
        }
      } else if (!ch.hatched) {
        ch.hatchT += dt;
        if (ch.hatchT >= HATCH_DELAY && workers.length < MAX_WORKERS) {
          ch.hatched = true;
          const [px, py] = axialToPixel(ch.q, ch.r, cx, cy);
          workers.push({
            x: px,
            y: py,
            flower: -1,
            t: 0,
            outbound: true,
            carrying: false,
            phase: rnd() * 6,
            twitch: 0,
            hintFlower: -1,
          });
          if (firstWorker === null) firstWorker = time;
          corePulse = Math.max(corePulse, 0.6);
          // Assign to existing route if any
          if (routes.length) {
            const rt = routes[workers.length % routes.length];
            const w = workers[workers.length - 1];
            w.flower = rt.flower;
          }
        }
      }
      if (ch.pulse > 0) ch.pulse = Math.max(0, ch.pulse - dt);
      if (ch.amber > 0.02) ch.amber *= 1 - dt * 0.04;
    }

    // Workers fly
    const [hx0, hy0] = hiveCenter();
    const rch = reach();

    // Idle twitch toward nearest reachable flower (first-move hint)
    twitchCd -= dt;
    if (twitchCd <= 0) {
      twitchCd = TWITCH_INTERVAL + rnd() * 1.4;
      const idle = workers.filter((w) => w.flower < 0 && w.twitch <= 0);
      if (idle.length) {
        const w = idle[Math.floor(rnd() * idle.length)];
        let best = -1;
        let bd = rch + 8;
        for (let i = 0; i < flowers.length; i++) {
          const f = flowers[i];
          if (f.tree) continue;
          const d = Math.hypot(f.x - hx0, f.y - hy0);
          if (d < bd) {
            bd = d;
            best = i;
          }
        }
        if (best >= 0) {
          w.twitch = TWITCH_DUR;
          w.hintFlower = best;
          flowers[best].hint = 1;
        }
      }
    }

    for (const w of workers) {
      w.phase += dt;
      if (w.twitch > 0) w.twitch = Math.max(0, w.twitch - dt);
      // Swarm to second hive
      if (w.flower === -2 && secondHive) {
        const tx = secondHive.x;
        const ty = secondHive.y;
        const dist = Math.hypot(tx - hx0, ty - hy0);
        w.t += (WORKER_SPEED * dt) / Math.max(40, dist);
        if (w.outbound) {
          if (w.t >= 1) {
            w.t = 0;
            w.outbound = false;
          }
          const u = Math.min(1, w.t);
          w.x = hx0 + (tx - hx0) * u;
          w.y = hy0 + (ty - hy0) * u;
        } else {
          // Orbit second hive
          const ang = w.phase * 1.1;
          w.x = tx + Math.cos(ang) * (14 + (w.phase % 4));
          w.y = ty + Math.sin(ang) * (12 + (w.phase % 3));
        }
        continue;
      }
      if (w.flower < 0) {
        // Idle orbit near hive edge; occasional lean toward hint flower
        const ang = w.phase * 0.8;
        let ox = hx0 + Math.cos(ang) * (22 + (w.phase % 5));
        let oy = hy0 + Math.sin(ang) * (18 + (w.phase % 4));
        if (w.twitch > 0 && w.hintFlower >= 0) {
          const hf = flowers[w.hintFlower];
          if (hf) {
            const k = (w.twitch / TWITCH_DUR) * 0.35;
            ox += (hf.x - hx0) * k * 0.12;
            oy += (hf.y - hy0) * k * 0.12;
          }
        }
        w.x = ox;
        w.y = oy;
        continue;
      }
      const f = flowers[w.flower];
      if (!f) {
        w.flower = -1;
        continue;
      }
      const spd = w.outbound ? WORKER_SPEED : WORKER_SPEED_RETURN;
      const dist = Math.hypot(f.x - hx0, f.y - hy0);
      const travel = Math.max(40, dist);
      w.t += (spd * dt) / travel;
      if (w.outbound) {
        if (w.t >= 1) {
          w.t = 1;
          w.outbound = false;
          w.carrying = true;
          f.visits++;
          f.bloom = Math.min(1, f.bloom + 0.12);
          w.t = 0;
        }
        const u = w.t;
        w.x = hx0 + (f.x - hx0) * u;
        w.y = hy0 + (f.y - hy0) * u;
      } else {
        if (w.t >= 1) {
          w.t = 0;
          w.outbound = true;
          if (w.carrying) {
            w.carrying = false;
            wax = Math.min(WAX_MAX, wax + WAX_NECTAR);
            const isFirst = firstNectar === null;
            if (isFirst) firstNectar = time;
            const full = isFirst || time - lastFullNectar >= NECTAR_FULL_CD;
            if (full) {
              lastFullNectar = time;
              for (const ch of chambers.values()) {
                if (ch.grow >= 1) {
                  ch.amber = Math.min(1, ch.amber + 0.45);
                  ch.pulse = 1;
                }
              }
              pulses.push({
                x0: w.x,
                y0: w.y,
                x1: hx0,
                y1: hy0,
                t: 0,
                dur: 0.55,
              });
              corePulse = 1;
              dum(false);
            } else {
              // Small local chamber flash only
              let nearest: Chamber | null = null;
              let nd = Infinity;
              for (const ch of chambers.values()) {
                if (ch.grow < 1) continue;
                const [px, py] = axialToPixel(ch.q, ch.r, cx, cy);
                const d = Math.hypot(px - w.x, py - w.y);
                if (d < nd) {
                  nd = d;
                  nearest = ch;
                }
              }
              if (nearest) {
                nearest.amber = Math.min(1, nearest.amber + 0.18);
                nearest.pulse = 0.7;
              }
            }
          }
        }
        const u = w.t;
        w.x = f.x + (hx0 - f.x) * u;
        w.y = f.y + (hy0 - f.y) * u;
      }
    }

    for (const f of flowers) {
      if (f.hint > 0) f.hint = Math.max(0, f.hint - dt * 1.2);
    }

    for (const p of pulses) p.t += dt;
    for (let i = pulses.length - 1; i >= 0; i--) {
      if (pulses[i].t >= pulses[i].dur) pulses.splice(i, 1);
    }

    for (const rt of routes) {
      rt.glow = 0.25 + 0.2 * Math.sin(time * 2 + rt.flower);
    }

    // Golden tree soft attract ~20s before reachable
    {
      const tree = flowers.find((f) => f.tree);
      if (tree && !bigFlight && planted) {
        const td = Math.hypot(tree.x - hx0, tree.y - hy0);
        const needReach = Math.max(0, Math.ceil((td - rch - 8) / REACH_PER_CHAMBER));
        const needMin = Math.max(0, TREE_MIN_CHAMBERS - builtCount());
        const lead = Math.max(needReach, needMin);
        const was = treeAttract;
        treeAttract = lead > 0 && lead <= TREE_ATTRACT_LEAD;
        if (treeAttract) {
          treeAttractPulse = 0.45 + 0.35 * Math.sin(time * 2.2);
          if (!was || time - lastChime > 4.5) {
            lastChime = time;
            if (!silent) playChime();
          }
        } else {
          treeAttractPulse = Math.max(0, treeAttractPulse - dt);
        }
      }
    }

    checkTraffic();
    if (traffic && Math.floor(time * 2) !== Math.floor((time - dt) * 2)) spawnBloom();

    // Soft hive scale settle after ring
    if (ringClosed && hiveScale > 1.08 && !floor2) {
      hiveScale += (1.1 - hiveScale) * Math.min(1, dt * 0.4);
    }
    if (floor2 && hiveScale < 1.28) {
      hiveScale += (1.3 - hiveScale) * Math.min(1, dt * 0.35);
    }

    // Midgame: meadow2 after big flight; trail auto-build; dusk hint
    if (bigFlight) spawnMeadow2();
    for (const tr of trails) {
      tr.glow = 0.55 + 0.35 * Math.sin(time * 2.5);
      if (tr.built < 1 && (tr.kind === "meadow" || tr.kind === "highway" || tr.kind === "join")) {
        const step = TRAIL_BUILD_RATE * dt * (TRAIL_BUILD_SPACING / Math.max(pathLen(tr.pts), 1));
        buildAlongTrail(tr, Math.min(1, tr.built + step * 8));
      }
    }
    if (highwayGlow > 0.3) highwayGlow = 0.55 + 0.45 * Math.sin(time * 2.2);
    if (hivePulseSync > 0) {
      hivePulseSync = Math.max(0.35, 0.55 + 0.45 * Math.sin(time * 2));
      corePulse = Math.max(corePulse, hivePulseSync * 0.5);
      if (secondHive) secondHive.pulse = hivePulseSync;
    }
    if (meadowBloom > 0) meadowBloom = Math.max(0.4, meadowBloom - dt * 0.02);
    if (joinTime !== null && hintTime === null && time >= 595) {
      triggerDuskHint();
    }
    if (dusk > 0) dusk = Math.min(1, dusk + dt / HINT_DUR);
  };

  const drawHex = (
    ctx: CanvasRenderingContext2D,
    x: number,
    y: number,
    size: number,
    fill: string,
    stroke: string,
    lw = 1.2,
  ) => {
    ctx.beginPath();
    for (let i = 0; i < 6; i++) {
      const a = (Math.PI / 180) * (60 * i);
      const px = x + size * Math.cos(a);
      const py = y + size * Math.sin(a);
      if (i === 0) ctx.moveTo(px, py);
      else ctx.lineTo(px, py);
    }
    ctx.closePath();
    ctx.fillStyle = fill;
    ctx.fill();
    ctx.strokeStyle = stroke;
    ctx.lineWidth = lw;
    ctx.stroke();
  };

  const draw = (ctx: CanvasRenderingContext2D, dpr: number) => {
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, W, H);

    // Warm light meadow → dusk tint after hint
    const duskK = Math.min(1, dusk);
    const g = ctx.createRadialGradient(cx, cy, 40, cx, cy, 520);
    g.addColorStop(0, duskK > 0.2 ? "#d4cfc0" : "#e8e2d4");
    g.addColorStop(0.55, duskK > 0.2 ? "#b8b3a4" : "#d5d0c2");
    g.addColorStop(1, duskK > 0.2 ? "#8a8680" : "#c4c0b4");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);
    if (duskK > 0.05) {
      ctx.fillStyle = `rgba(40,50,70,${duskK * 0.28})`;
      ctx.fillRect(0, 0, W, H);
    }

    ctx.save();
    ctx.translate(W / 2, H / 2);
    ctx.scale(camZoom, camZoom);
    ctx.translate(-W / 2, -H / 2);

    // Soft grass specks
    ctx.fillStyle = "rgba(120,130,100,0.06)";
    for (let i = 0; i < 120; i++) {
      const sx = ((i * 97) % W) + Math.sin(time * 0.3 + i) * 2;
      const sy = ((i * 53) % H) + Math.cos(time * 0.25 + i) * 2;
      ctx.beginPath();
      ctx.arc(sx, sy, 1.2, 0, Math.PI * 2);
      ctx.fill();
    }

    // Buildable neighbor glow
    if (planted) {
      const seen = new Set<string>();
      const candidates: [number, number][] = [...RING];
      for (const ch of chambers.values()) {
        if (ch.grow < 1) continue;
        for (const n of neighbors(ch.q, ch.r)) candidates.push(n);
      }
      for (const [q, r] of candidates) {
        if (q === 0 && r === 0) continue;
        const k = hexKey(q, r);
        if (seen.has(k) || chambers.has(k)) continue;
        seen.add(k);
        if (!isAdjacentToHive(q, r)) continue;
        const [px, py] = axialToPixel(q, r, cx, cy);
        const dim = wax < WAX_MIN ? 0.12 : 0.22 + 0.1 * pulseHexGlow;
        drawHex(ctx, px, py, HEX * 0.92, `rgba(180,175,160,${dim * 0.35})`, `rgba(140,135,120,${dim})`);
      }
    } else {
      // Pulsing starter hex
      const [px, py] = axialToPixel(0, 0, cx, cy);
      drawHex(
        ctx,
        px,
        py,
        HEX * (0.95 + 0.06 * pulseHexGlow),
        `rgba(190,185,170,${0.25 + 0.2 * pulseHexGlow})`,
        `rgba(120,115,100,${0.4 + 0.35 * pulseHexGlow})`,
        1.6,
      );
    }

    // Routes
    const [hx0, hy0] = hiveCenter();
    for (const rt of routes) {
      const f = flowers[rt.flower];
      if (!f) continue;
      ctx.strokeStyle = `rgba(160,150,120,${0.18 + rt.glow * 0.35})`;
      ctx.lineWidth = traffic ? 2.2 : 1.4;
      ctx.beginPath();
      ctx.moveTo(hx0, hy0);
      ctx.lineTo(f.x, f.y);
      ctx.stroke();
    }

    // Pheromone trails
    for (const tr of trails) {
      if (tr.pts.length < 2) continue;
      const gold = tr.kind === "join" || tr.kind === "highway" ? highwayGlow : tr.glow;
      ctx.strokeStyle = `rgba(190,160,70,${0.25 + gold * 0.45})`;
      ctx.lineWidth = tr.kind === "highway" || tr.kind === "join" ? 3.2 : 2.4;
      ctx.beginPath();
      ctx.moveTo(tr.pts[0]!.x, tr.pts[0]!.y);
      for (let i = 1; i < tr.pts.length; i++) ctx.lineTo(tr.pts[i]!.x, tr.pts[i]!.y);
      ctx.stroke();
    }
    // Live stroke
    if (dragging && strokePts.length > 1 && bigFlight) {
      ctx.strokeStyle = "rgba(180,150,70,0.35)";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(strokePts[0]!.x, strokePts[0]!.y);
      for (let i = 1; i < strokePts.length; i++) ctx.lineTo(strokePts[i]!.x, strokePts[i]!.y);
      ctx.stroke();
    }

    // Second golden meadow
    if (meadow2) {
      const mg = ctx.createRadialGradient(meadow2.x, meadow2.y, 4, meadow2.x, meadow2.y, meadow2.r);
      mg.addColorStop(0, `rgba(180,160,90,${0.22 + meadowBloom * 0.25})`);
      mg.addColorStop(1, "rgba(180,160,90,0)");
      ctx.fillStyle = mg;
      ctx.beginPath();
      ctx.arc(meadow2.x, meadow2.y, meadow2.r, 0, Math.PI * 2);
      ctx.fill();
    }

    // Second hive (grey)
    if (secondHive) {
      const sh = secondHive;
      for (let i = 0; i < sh.chambers; i++) {
        const a = (i / sh.chambers) * Math.PI * 2 + time * 0.1;
        drawHex(
          ctx,
          sh.x + Math.cos(a) * 16,
          sh.y + Math.sin(a) * 14,
          HEX * 0.7,
          `rgba(150,145,130,${0.4 + sh.pulse * 0.2})`,
          `rgba(110,105,95,0.45)`,
        );
      }
      ctx.beginPath();
      ctx.arc(sh.x, sh.y, 8 + sh.pulse * 4, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(160,150,120,${0.5 + sh.pulse * 0.3})`;
      ctx.fill();
      // Highway
      ctx.strokeStyle = `rgba(190,160,70,${0.2 + highwayGlow * 0.4})`;
      ctx.lineWidth = 2.8;
      ctx.beginPath();
      ctx.moveTo(hx0, hy0);
      ctx.lineTo(sh.x, sh.y);
      ctx.stroke();
    }

    // Flowers (grey / warm circles)
    for (const f of flowers) {
      const sway = Math.sin(time * 1.1 + f.ph) * (f.tree ? 1.2 : 2.2);
      const x = f.x + sway;
      const y = f.y + Math.cos(time * 0.9 + f.ph) * (f.tree ? 0.6 : 1.4);
      if (f.tree) {
        const reachOk =
          builtCount() >= TREE_MIN_CHAMBERS && Math.hypot(f.x - hx0, f.y - hy0) <= reach() + 8;
        const attract = treeAttract || treeAttractPulse > 0.05;
        const pulseR = attract ? treeAttractPulse * 10 : 0;
        ctx.beginPath();
        ctx.arc(x, y, f.r + pulseR * 0.35, 0, Math.PI * 2);
        ctx.fillStyle = reachOk
          ? "rgba(170,150,90,0.55)"
          : attract
            ? `rgba(165,155,110,${0.38 + treeAttractPulse * 0.2})`
            : "rgba(150,145,130,0.4)";
        ctx.fill();
        ctx.strokeStyle = reachOk
          ? "rgba(140,120,60,0.7)"
          : attract
            ? `rgba(150,135,80,${0.4 + treeAttractPulse * 0.35})`
            : "rgba(120,115,100,0.45)";
        ctx.lineWidth = attract ? 2.2 : 2;
        ctx.stroke();
        if (attract) {
          ctx.beginPath();
          ctx.arc(x, y, f.r + 6 + (1 - treeAttractPulse) * 14, 0, Math.PI * 2);
          ctx.strokeStyle = `rgba(180,160,90,${0.2 + treeAttractPulse * 0.35})`;
          ctx.lineWidth = 1.4;
          ctx.stroke();
        }
        ctx.beginPath();
        ctx.arc(x, y, f.r * 0.45, 0, Math.PI * 2);
        ctx.strokeStyle = "rgba(180,160,100,0.35)";
        ctx.stroke();
      } else {
        const close = duskK > 0.3 ? Math.max(0.35, 1 - duskK * 0.55) : 1;
        const br = f.r * (0.7 + f.bloom * 0.45) * close;
        const hint = f.hint;
        ctx.beginPath();
        ctx.arc(x, y, br + hint * 3, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(150,145,135,${(0.25 + f.bloom * 0.35 + hint * 0.15) * close})`;
        ctx.fill();
        ctx.strokeStyle = `rgba(110,105,95,${0.3 + f.bloom * 0.3 + hint * 0.35})`;
        ctx.lineWidth = hint > 0 ? 1.6 : 1.2;
        ctx.stroke();
        if (hint > 0) {
          ctx.beginPath();
          ctx.arc(x, y, br + 4 + (1 - hint) * 10, 0, Math.PI * 2);
          ctx.strokeStyle = `rgba(160,150,120,${hint * 0.4})`;
          ctx.lineWidth = 1.2;
          ctx.stroke();
        }
        ctx.beginPath();
        ctx.arc(x, y, br * 0.35, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(170,160,140,${0.2 + f.bloom * 0.4})`;
        ctx.fill();
      }
    }

    // Chambers
    ctx.save();
    if (core) {
      ctx.translate(core.x, core.y);
      ctx.scale(hiveScale, hiveScale);
      ctx.translate(-core.x, -core.y);
    }
    for (const ch of chambers.values()) {
      const [px, py] = axialToPixel(ch.q, ch.r, cx, cy);
      const gsz = HEX * (0.4 + 0.6 * Math.min(1, ch.grow));
      const amber = ch.amber;
      const grey = 1 - amber;
      const fill = `rgba(${Math.floor(150 + amber * 40)},${Math.floor(145 + amber * 30)},${Math.floor(130 - amber * 40)},${0.35 + ch.grow * 0.4})`;
      const stroke = amber > 0.2
        ? `rgba(180,150,80,${0.35 + amber * 0.4})`
        : `rgba(120,115,105,${0.35 + grey * 0.25})`;
      const isRust = rustChamber === hexKey(ch.q, ch.r);
      const fillR = isRust
        ? `rgba(${Math.floor(150 + amber * 20)},${Math.floor(110 + amber * 20)},${Math.floor(90)},${0.4 + ch.grow * 0.35})`
        : fill;
      drawHex(ctx, px, py, gsz, fillR, stroke, 1.4);
      if (ch.pulse > 0) {
        ctx.strokeStyle = `rgba(200,170,90,${ch.pulse * 0.5})`;
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(px, py, gsz + (1 - ch.pulse) * 12, 0, Math.PI * 2);
        ctx.stroke();
      }
    }

    // Core (queen)
    if (core) {
      const pr = 10 + corePulse * 6;
      ctx.beginPath();
      ctx.arc(core.x, core.y, pr, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(160,150,120,${0.55 + corePulse * 0.3})`;
      ctx.fill();
      ctx.strokeStyle = `rgba(100,95,80,${0.5 + corePulse * 0.3})`;
      ctx.lineWidth = 1.8;
      ctx.stroke();
    }
    ctx.restore();

    // Swarm dots (wax brightness)
    const [sx0, sy0] = hiveCenter();
    const bright = 0.2 + wax * 0.65;
    const shiv = shiver > 0 ? Math.sin(time * 40) * 3 * shiver : 0;
    for (const d of swarm) {
      const a = d.a + time * d.spd;
      const x = sx0 + Math.cos(a) * d.r + shiv;
      const y = sy0 + Math.sin(a) * d.r * 0.75;
      ctx.beginPath();
      ctx.arc(x, y, 2.2, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(90,85,70,${bright})`;
      ctx.fill();
    }

    // Workers
    for (const w of workers) {
      ctx.beginPath();
      ctx.arc(w.x, w.y, w.carrying ? 2.8 : 2.2, 0, Math.PI * 2);
      ctx.fillStyle = w.carrying ? "rgba(170,140,70,0.85)" : "rgba(80,75,65,0.75)";
      ctx.fill();
    }

    // Pulses
    for (const p of pulses) {
      const k = p.t / p.dur;
      const x = p.x0 + (p.x1 - p.x0) * k;
      const y = p.y0 + (p.y1 - p.y0) * k;
      ctx.beginPath();
      ctx.arc(x, y, 4 + k * 3, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(190,160,80,${0.55 * (1 - k)})`;
      ctx.fill();
    }

    // Drag trail
    if (dragging) {
      const dist = Math.hypot(hx - dsx, hy - dsy);
      const ok = dist <= reach() + 8;
      ctx.strokeStyle = ok ? "rgba(140,130,100,0.35)" : "rgba(140,100,100,0.25)";
      ctx.lineWidth = 1.6;
      ctx.setLineDash(ok ? [] : [6, 5]);
      ctx.beginPath();
      ctx.moveTo(dsx, dsy);
      ctx.lineTo(hx, hy);
      ctx.stroke();
      ctx.setLineDash([]);
    }

    // Big flight swarm cloud
    if (bigFlight && bigFlightT < 6) {
      const tree = flowers.find((f) => f.tree);
      if (tree) {
        const u = Math.min(1, bigFlightT / 2.5);
        const back = bigFlightT > 3 ? Math.min(1, (bigFlightT - 3) / 2.2) : 0;
        const t = back > 0 ? 1 - back : u;
        const bx = hx0 + (tree.x - hx0) * t;
        const by = hy0 + (tree.y - hy0) * t;
        for (let i = 0; i < 28; i++) {
          const a = (i / 28) * Math.PI * 2 + time * 2;
          const rr = 8 + (i % 5) * 3;
          ctx.beginPath();
          ctx.arc(bx + Math.cos(a) * rr, by + Math.sin(a) * rr * 0.7, 2, 0, Math.PI * 2);
          ctx.fillStyle = `rgba(160,140,80,${0.35 + 0.25 * (1 - back)})`;
          ctx.fill();
        }
      }
    }

    ctx.restore();
  };

  const pointerDown = (x: number, y: number) => {
    dragging = true;
    dsx = x;
    dsy = y;
    hx = x;
    hy = y;
    strokePts = [{ x, y }];
    strokeT0 = time;
    strokeLen = 0;

    const [q, r] = pixelToAxial(x, y, cx, cy);
    const [px, py] = axialToPixel(q, r, cx, cy);
    if (Math.hypot(px - x, py - y) < HEX * 1.15) {
      if (!planted && q === 0 && r === 0) {
        tryBuild(0, 0);
        dragging = false;
        strokePts = [];
        return;
      }
      if (planted && isAdjacentToHive(q, r) && !chambers.has(hexKey(q, r))) {
        tryBuild(q, r);
        dragging = false;
        strokePts = [];
        return;
      }
    }
  };

  const pointerMove = (x: number, y: number) => {
    hx = x;
    hy = y;
    if (!dragging) return;
    const last = strokePts[strokePts.length - 1];
    if (!last || Math.hypot(x - last.x, y - last.y) > 5) {
      if (last) strokeLen += Math.hypot(x - (last?.x ?? x), y - (last?.y ?? y));
      strokePts.push({ x, y });
    }
  };

  const pointerUp = () => {
    if (!dragging) return;
    dragging = false;
    const dist = Math.hypot(hx - dsx, hy - dsy);
    if (dist < 18) {
      strokePts = [];
      return;
    }

    // After big flight: slow long drag = pheromone trail
    if (bigFlight && strokePts.length >= TRAIL_MIN_PTS) {
      const dur = Math.max(0.05, time - strokeT0);
      const avgSpd = pathLen(strokePts) / dur;
      if (avgSpd <= TRAIL_MAX_SPEED && pathLen(strokePts) >= TRAIL_MIN_LEN) {
        if (activateTrail(strokePts)) {
          strokePts = [];
          return;
        }
      }
    }

    // Drag from hive area toward flower (early-game route)
    const [hx0, hy0] = hiveCenter();
    const nearHive = Math.hypot(dsx - hx0, dsy - hy0) < 70 || workers.some((w) => Math.hypot(dsx - w.x, dsy - w.y) < 28);
    if (!nearHive && planted) {
      let nearCh = false;
      for (const ch of chambers.values()) {
        const [px, py] = axialToPixel(ch.q, ch.r, cx, cy);
        if (Math.hypot(dsx - px, dsy - py) < HEX * 1.4) {
          nearCh = true;
          break;
        }
      }
      if (!nearCh) {
        strokePts = [];
        return;
      }
    }
    if (!planted) {
      strokePts = [];
      return;
    }

    const fi = nearestFlowerIdx(hx, hy, 55);
    if (fi >= 0) assignRoute(fi);
    strokePts = [];
  };

  const metrics = (): SimMetrics => ({
    time,
    chambers: builtCount(),
    workers: workers.length,
    wax,
    routes: routes.length,
    firstWorker,
    firstNectar,
    ringTime,
    trafficTime,
    bigFlight,
    bigFlightTime,
    ringClosed,
    traffic,
    trailTime,
    floor2Time,
    swarmTime,
    joinTime,
    hintTime,
  });

  const snapshot = (): WorldSnapshot => ({
    core: core ? { x: core.x, y: core.y } : null,
    chambers: [...chambers.values()].map((c) => ({
      q: c.q,
      r: c.r,
      grow: c.grow,
      hatched: c.hatched,
    })),
    flowers: flowers.map((f) => ({ x: f.x, y: f.y, tree: f.tree, bloom: f.bloom })),
    workers: workers.map((w) => ({
      x: w.x,
      y: w.y,
      carrying: w.carrying,
      flower: w.flower,
    })),
    wax,
    reach: reach(),
    ringClosed,
    traffic,
    shivering: shiver,
    meadow2: meadow2 ? { x: meadow2.x, y: meadow2.y } : null,
    secondHive: secondHive ? { x: secondHive.x, y: secondHive.y } : null,
  });

  const bootstrapStart5 = () => {
    tryBuild(0, 0);
    time = START5_T;
    // Complete ring + expansion
    for (const [q, r] of RING) {
      const k = hexKey(q, r);
      chambers.set(k, {
        q,
        r,
        grow: 1,
        growDur: BUILD_DUR,
        amber: 0.4,
        hatchT: HATCH_DELAY,
        hatched: true,
        pulse: 0,
      });
    }
    ringClosed = true;
    ringTime = 135;
    hiveScale = 1.12;
    for (const [q, r] of RING) {
      for (const [nq, nr] of neighbors(q, r)) {
        if (nq === 0 && nr === 0) continue;
        if (RING.some(([rq, rr]) => rq === nq && rr === nr)) continue;
        const k = hexKey(nq, nr);
        if (chambers.has(k)) continue;
        chambers.set(k, {
          q: nq,
          r: nr,
          grow: 1,
          growDur: BUILD_DUR,
          amber: 0.25,
          hatchT: HATCH_DELAY,
          hatched: true,
          pulse: 0,
        });
        if (builtCount() >= TREE_MIN_CHAMBERS + 4) break;
      }
      if (builtCount() >= TREE_MIN_CHAMBERS + 4) break;
    }
    firstWorker = 35;
    firstNectar = 80;
    traffic = true;
    trafficTime = 200;
    const flowerIdx = flowers.findIndex((f) => !f.tree);
    if (flowerIdx >= 0) {
      routes.push({ flower: flowerIdx, glow: 0.4 });
      assignRoute(flowerIdx);
    }
    while (workers.length < 40) {
      workers.push({
        x: cx + (rnd() - 0.5) * 40,
        y: cy + (rnd() - 0.5) * 40,
        flower: flowerIdx >= 0 ? flowerIdx : -1,
        t: rnd(),
        outbound: rnd() < 0.5,
        carrying: false,
        phase: rnd() * 6,
        twitch: 0,
        hintFlower: -1,
      });
    }
    // Big flight done
    const tree = flowers.find((f) => f.tree);
    if (tree) {
      bigFlight = true;
      bigFlightTime = START5_T - 8;
      bigFlightT = 8;
      camZoom = CAM_ZOOM_OUT;
      camZoomTarget = CAM_ZOOM_OUT;
      wax = Math.min(WAX_MAX, wax + 0.5);
    }
    spawnMeadow2();
  };

  const stressFill = (workerCount: number) => {
    if (!planted) tryBuild(0, 0);
    // Instant-complete ring + outer ring
    for (const [q, r] of RING) {
      const k = hexKey(q, r);
      if (!chambers.has(k)) {
        chambers.set(k, {
          q,
          r,
          grow: 1,
          growDur: BUILD_DUR,
          amber: 0.3,
          hatchT: HATCH_DELAY,
          hatched: true,
          pulse: 0,
        });
      } else {
        const ch = chambers.get(k)!;
        ch.grow = 1;
        ch.hatched = true;
      }
    }
    ringClosed = true;
    // Extra chambers
    for (const [q, r] of RING) {
      for (const [nq, nr] of neighbors(q, r)) {
        if (nq === 0 && nr === 0) continue;
        const k = hexKey(nq, nr);
        if (chambers.has(k)) continue;
        chambers.set(k, {
          q: nq,
          r: nr,
          grow: 1,
          growDur: BUILD_DUR,
          amber: 0.2,
          hatchT: HATCH_DELAY,
          hatched: true,
          pulse: 0,
        });
      }
    }
    const flowerIdx = flowers.findIndex((f) => !f.tree);
    if (flowerIdx >= 0 && !routes.some((r) => r.flower === flowerIdx)) {
      routes.push({ flower: flowerIdx, glow: 0.4 });
    }
    while (workers.length < workerCount) {
      workers.push({
        x: cx + (rnd() - 0.5) * 40,
        y: cy + (rnd() - 0.5) * 40,
        flower: flowerIdx >= 0 ? flowerIdx : -1,
        t: rnd(),
        outbound: rnd() < 0.5,
        carrying: false,
        phase: rnd() * 6,
        twitch: 0,
        hintFlower: -1,
      });
    }
    if (firstWorker === null && workers.length) firstWorker = time;
    traffic = true;
  };

  if (opts.startAt !== undefined && opts.startAt >= START5_T - 5) {
    bootstrapStart5();
  }

  return {
    update,
    draw,
    pointerDown,
    pointerMove,
    pointerUp,
    metrics,
    snapshot,
    stressFill,
    bootstrapStart5,
  };
}

export function startApis(cv: HTMLCanvasElement, startAt?: number): () => void {
  document.body.style.background = "#c8c4b8";
  const app = document.getElementById("app");
  if (app) (app as HTMLElement).style.background = "#c8c4b8";
  cv.style.background = "#d5d0c2";
  const world = createApisWorld({ startAt });
  return mountCanvas(cv, world, W, H);
}
