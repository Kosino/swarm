## Headless acceptance — same policy as src/apis/headless.ts
class_name ApisHeadless
extends RefCounted

const C = preload("res://apis/config.gd")
const G = preload("res://apis/gestures.gd")

const SEEDS := [3, 7, 11, 21, 42, 77, 100, 128, 256, 512, 1024, 2048]
const RING := [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]


func _fmt(t) -> String:
	if t == null or (typeof(t) == TYPE_FLOAT and is_nan(float(t))):
		return "—"
	var tf: float = float(t)
	var m: int = int(floor(tf / 60.0))
	var s = fmod(tf, 60.0)
	var ss = "%.1f" % s
	if ss.length() < 4:
		ss = "0" + ss
	return "%d:%s" % [m, ss]


func _median(vals: Array):
	var a: Array = []
	for v in vals:
		if v != null and typeof(v) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(v)):
			a.append(float(v))
	if a.is_empty():
		return null
	a.sort()
	return a[int(floor(float(a.size()) / 2.0))]


func _axial_to_pixel(q: int, r: int, cx: float, cy: float) -> Vector2:
	var size: float = C.HEX + C.HEX_GAP
	return Vector2(
		size * (1.5 * float(q)) + cx,
		size * ((sqrt(3.0) / 2.0) * float(q) + sqrt(3.0) * float(r)) + cy
	)


func _slow_trail(world: ApisWorld, pts: Array, dt: float) -> void:
	world.pointer_down(pts[0].x, pts[0].y)
	world.update(dt)
	for i in range(1, pts.size()):
		world.pointer_move(pts[i].x, pts[i].y)
		var d: float = G.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y)
		var wait: float = maxf(dt, d / 55.0)
		var t := 0.0
		while t < wait:
			world.update(dt)
			t += dt
	world.pointer_up()
	world.update(dt)


func _run_playthrough(seed_num: int) -> Dictionary:
	var rng := ApisRng.new(seed_num)
	var world := ApisWorld.new({"silent": true, "rng": rng})
	var notes: Array = []
	var dt: float = 1.0 / 30.0
	var max_t := 620.0
	var cx: float = float(C.W) * 0.5
	var cy: float = float(C.H) * 0.48
	var planted := false
	var last_build_t := -10.0
	var last_route_t := -10.0
	var mid_trail_at := -1.0
	var sim_t := 0.0

	while sim_t < max_t:
		var m = world.metrics()
		var snap = world.snapshot()

		if not planted and m.time >= 14.0:
			world.pointer_down(cx, cy)
			world.pointer_up()
			planted = true
			last_build_t = m.time

		if planted and not m.bigFlight:
			var built: Dictionary = {}
			for c in snap.chambers:
				if c.grow >= 1.0:
					built["%d,%d" % [c.q, c.r]] = true
			var growing := false
			for c2 in snap.chambers:
				if c2.grow < 1.0:
					growing = true
					break
			var n_built: int = built.size()
			var build_cd: float = 0.7 if not snap.ringClosed else (1.0 if n_built < 12 else 2.9)
			var hold_ring: bool = not snap.ringClosed and n_built >= 3 and m.time < 124.0
			var hold_expand: bool = snap.ringClosed and n_built >= 11 and m.time < 225.0
			if hold_ring or hold_expand:
				pass
			elif not growing and m.time - last_build_t > build_cd and snap.wax >= 0.3:
				var target = null
				if not snap.ringClosed:
					for cell in RING:
						var k := "%d,%d" % [cell.x, cell.y]
						if not built.has(k):
							target = cell
							break
				else:
					var tree = null
					for f in snap.flowers:
						if f.get("tree", false):
							tree = f
							break
					if tree != null:
						var best = null
						var bd := INF
						var candidates: Array = []
						for ch in snap.chambers:
							if ch.grow < 1.0:
								continue
							for cell2 in RING:
								candidates.append(Vector2i(ch.q + cell2.x, ch.r + cell2.y))
						for cand in candidates:
							if cand.x == 0 and cand.y == 0:
								continue
							var kk := "%d,%d" % [cand.x, cand.y]
							if built.has(kk):
								continue
							var already := false
							for c3 in snap.chambers:
								if c3.q == cand.x and c3.r == cand.y:
									already = true
									break
							if already:
								continue
							var p: Vector2 = _axial_to_pixel(cand.x, cand.y, cx, cy)
							var d: float = G.hypot(tree.x - p.x, tree.y - p.y)
							if d < bd:
								bd = d
								best = cand
						target = best
				if target != null:
					var px: Vector2 = _axial_to_pixel(target.x, target.y, cx, cy)
					world.pointer_down(px.x, px.y)
					world.pointer_up()
					last_build_t = m.time

			if m.time - last_route_t > 1.2 and (snap.workers.size() > 0 or m.time > 30.0):
				var tree2 = null
				for f2 in snap.flowers:
					if f2.get("tree", false):
						tree2 = f2
						break
				var hive = snap.core if snap.core != null else {"x": cx, "y": cy}
				var dest: Array = []
				for i in range(snap.flowers.size()):
					var f3 = snap.flowers[i]
					if f3.get("tree", false):
						continue
					if G.hypot(f3.x - hive.x, f3.y - hive.y) <= snap.reach + 5.0:
						dest.append({"f": f3, "i": i})
				dest.sort_custom(func(a, b):
					return G.hypot(a.f.x - hive.x, a.f.y - hive.y) < G.hypot(b.f.x - hive.x, b.f.y - hive.y)
				)
				var routed: Dictionary = {}
				for w in snap.workers:
					if w.flower >= 0:
						routed[w.flower] = true
				var pick_idx: int = dest[0].i if dest.size() > 0 else -1
				var n_built2 := 0
				for c4 in snap.chambers:
					if c4.grow >= 1.0:
						n_built2 += 1
				if (
					tree2 != null
					and n_built2 >= C.TREE_MIN_CHAMBERS
					and G.hypot(tree2.x - hive.x, tree2.y - hive.y) <= snap.reach + 5.0
					and not m.bigFlight
				):
					for i2 in range(snap.flowers.size()):
						if snap.flowers[i2].get("tree", false):
							pick_idx = i2
							break
				else:
					for ditem in dest:
						if not routed.has(ditem.i):
							pick_idx = ditem.i
							break
				if pick_idx >= 0:
					var pick = snap.flowers[pick_idx]
					world.pointer_down(hive.x + 8.0, hive.y)
					world.pointer_move(pick.x, pick.y)
					world.pointer_up()
					last_route_t = m.time

		if m.bigFlight and m.time - mid_trail_at > 3.0:
			var hive2 = snap.core if snap.core != null else {"x": cx, "y": cy}
			if m.trailTime == null and m.time >= 342.0:
				var ang: float = 0.4 + float(seed_num % 7) * 0.15
				var pts: Array = []
				for i3 in range(19):
					var t: float = float(i3) / 18.0
					pts.append({
						"x": hive2.x + cos(ang) * (40.0 + t * 200.0),
						"y": hive2.y + sin(ang) * (30.0 + t * 160.0),
					})
				var length := 0.0
				for i4 in range(1, pts.size()):
					length += G.hypot(pts[i4].x - pts[i4 - 1].x, pts[i4].y - pts[i4 - 1].y)
				if length < C.TRAIL_MIN_LEN:
					pts.append({
						"x": pts[pts.size() - 1].x + cos(ang) * 80.0,
						"y": pts[pts.size() - 1].y + sin(ang) * 60.0,
					})
				_slow_trail(world, pts, dt)
				mid_trail_at = world.metrics().time
				sim_t = world.metrics().time
				continue
			if m.floor2Time == null and m.trailTime != null and m.time >= 415.0:
				var pts2: Array = []
				var r := 95.0
				for i5 in range(21):
					var a: float = -0.4 + (float(i5) / 20.0) * 2.4
					pts2.append({"x": hive2.x + cos(a) * r, "y": hive2.y + sin(a) * r * 0.85})
				_slow_trail(world, pts2, dt)
				mid_trail_at = world.metrics().time
				sim_t = world.metrics().time
				continue
			if m.swarmTime == null and m.floor2Time != null and m.time >= 488.0:
				var dest2 = snap.meadow2
				if dest2 == null and snap.flowers.size() > 0:
					dest2 = snap.flowers[0]
					for f4 in snap.flowers:
						var d4: float = G.hypot(f4.x - hive2.x, f4.y - hive2.y)
						var bd4: float = G.hypot(dest2.x - hive2.x, dest2.y - hive2.y)
						if d4 > bd4:
							dest2 = f4
				if dest2 != null:
					var pts3: Array = []
					for i6 in range(23):
						var t2: float = float(i6) / 22.0
						pts3.append({
							"x": hive2.x + (dest2.x - hive2.x) * t2,
							"y": hive2.y + (dest2.y - hive2.y) * t2,
						})
					_slow_trail(world, pts3, dt)
					mid_trail_at = world.metrics().time
					sim_t = world.metrics().time
					continue
			if m.joinTime == null and m.swarmTime != null and m.time >= 552.0:
				var dest3 = snap.secondHive if snap.secondHive != null else (snap.meadow2 if snap.meadow2 != null else {"x": hive2.x + 200.0, "y": hive2.y})
				var pts4: Array = []
				for i7 in range(21):
					var t3: float = float(i7) / 20.0
					pts4.append({
						"x": hive2.x + (dest3.x - hive2.x) * t3,
						"y": hive2.y + (dest3.y - hive2.y) * t3,
					})
				_slow_trail(world, pts4, dt)
				mid_trail_at = world.metrics().time
				sim_t = world.metrics().time
				continue

		world.update(dt)
		sim_t = world.metrics().time

	var metrics = world.metrics()
	return {"metrics": metrics, "notes": notes}


func _measure_fps() -> Dictionary:
	var world := ApisWorld.new({"silent": true, "rng": ApisRng.new(99)})
	world.pointer_down(float(C.W) / 2.0, float(C.H) * 0.48)
	world.pointer_up()
	world.stress_fill(150)
	var frames := 180
	var dt: float = 1.0 / 60.0
	var t0 := Time.get_ticks_usec()
	for i in range(frames):
		world.update(dt)
	var elapsed_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	var update_ms: float = elapsed_ms / float(frames)
	var fps: float = 1000.0 / maxf(update_ms, 0.001)
	return {"fps": fps, "updateMs": update_ms}


func _near(t, target: float, tol: float) -> bool:
	return t != null and absf(float(t) - target) <= tol


func _nums(xs: Array) -> Array:
	var out: Array = []
	for v in xs:
		if v != null:
			out.append(float(v))
	return out


func _max_gap(times: Array):
	var seq: Array = []
	for v in times:
		if v != null:
			seq.append(float(v))
	if seq.size() < 2:
		return null
	seq.sort()
	var g := 0.0
	for i in range(1, seq.size()):
		g = maxf(g, seq[i] - seq[i - 1])
	return g


func run() -> Dictionary:
	var results: Array = []
	var all_notes: Array = []
	var fps_info = _measure_fps()
	var fps: float = fps_info.fps
	var update_ms: float = fps_info.updateMs

	for s in SEEDS:
		print("seed ", s, "…")
		var result = _run_playthrough(int(s))
		results.append(result.metrics)
		if result.notes.size() > 0:
			all_notes.append("seed %d: %s" % [int(s), "; ".join(result.notes)])

	var med = {
		"firstWorker": _median(_nums(results.map(func(m): return m.firstWorker))),
		"firstNectar": _median(_nums(results.map(func(m): return m.firstNectar))),
		"ring": _median(_nums(results.map(func(m): return m.ringTime))),
		"traffic": _median(_nums(results.map(func(m): return m.trafficTime))),
		"bigFlight": _median(_nums(results.map(func(m): return m.bigFlightTime))),
		"trail": _median(_nums(results.map(func(m): return m.trailTime))),
		"floor2": _median(_nums(results.map(func(m): return m.floor2Time))),
		"swarm": _median(_nums(results.map(func(m): return m.swarmTime))),
		"join": _median(_nums(results.map(func(m): return m.joinTime))),
		"hint": _median(_nums(results.map(func(m): return m.hintTime))),
	}

	# Web medians (assignment): 0:34 / 1:16 / 2:07 / 3:22 / 4:34 / 5:46 / 7:07 / 8:14 / 9:17 / 9:55
	var targets := {
		"firstWorker": 34.1, "firstNectar": 75.7, "ring": 126.9, "traffic": 201.6,
		"bigFlight": 273.6, "trail": 345.6, "floor2": 426.6, "swarm": 493.9,
		"join": 557.4, "hint": 595.0,
	}
	var early_gaps: Array = []
	var mid_gaps: Array = []
	var all_complete := true
	for m in results:
		if (
			m.firstWorker == null or m.firstNectar == null or m.ringTime == null
			or m.trafficTime == null or m.bigFlightTime == null or m.trailTime == null
			or m.floor2Time == null or m.swarmTime == null or m.joinTime == null or m.hintTime == null
		):
			all_complete = false
		var eg = _max_gap([m.firstWorker, m.firstNectar, m.ringTime, m.trafficTime, m.bigFlightTime])
		var mg = _max_gap([m.trailTime, m.floor2Time, m.swarmTime, m.joinTime, m.hintTime])
		if eg != null:
			early_gaps.append(eg)
		if mg != null:
			mid_gaps.append(mg)
	var med_early_gap = _median(early_gaps)
	var med_mid_gap = _median(mid_gaps)

	var ok := all_complete and fps >= 60.0
	for k in targets.keys():
		if not _near(med[k], float(targets[k]), 15.0):
			ok = false
			all_notes.append("median %s off: %s vs %.1f" % [k, _fmt(med[k]), float(targets[k])])
	if med_early_gap == null or float(med_early_gap) > 90.0:
		ok = false
	if med_mid_gap == null or float(med_mid_gap) > 90.0:
		ok = false

	return {
		"ok": ok,
		"medians": {
			"firstWorker": _fmt(med.firstWorker),
			"firstNectar": _fmt(med.firstNectar),
			"ring": _fmt(med.ring),
			"traffic": _fmt(med.traffic),
			"bigFlight": _fmt(med.bigFlight),
			"trail": _fmt(med.trail),
			"floor2": _fmt(med.floor2),
			"swarm": _fmt(med.swarm),
			"join": _fmt(med.join),
			"hint": _fmt(med.hint),
			"earlyGapSec": med_early_gap,
			"midGapSec": med_mid_gap,
		},
		"fps": int(round(fps)),
		"updateMs": snappedf(update_ms, 0.001),
		"notes": all_notes,
	}
