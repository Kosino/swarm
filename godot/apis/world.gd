## ApisWorld — behavioral port of src/apis/apis.ts (no canvas draw).
class_name ApisWorld
extends RefCounted

const C = preload("res://apis/config.gd")
const G = preload("res://apis/gestures.gd")

const RING := [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
const FLOWER_VARS := ["a", "b", "c"]
const MEADOW_VARS := ["louka_a", "louka_b", "louka_c"]
const IDLE_GHOST_S := 8.0
const MAX_GHOST_PERFORMS := 2

var rng: ApisRng
var silent: bool = true

var cx: float
var cy: float

var flowers: Array = []  # Dictionaries
var chambers: Dictionary = {}  # "q,r" -> Dictionary
var workers: Array = []
var routes: Array = []
var pulses: Array = []
var swarm: Array = []

var core = null  # {x,y} or null
var planted: bool = false
var wax: float = C.WAX_START
var time: float = 0.0
var shiver: float = 0.0
var core_pulse: float = 0.0
var ring_closed: bool = false
var ring_time = null
var traffic: bool = false
var traffic_time = null
var first_worker = null
var first_nectar = null
var last_full_nectar: float = -C.NECTAR_FULL_CD
var big_flight: bool = false
var big_flight_time = null
var big_flight_t: float = 0.0
var cam_zoom: float = C.CAM_ZOOM_IN
var cam_zoom_target: float = C.CAM_ZOOM_IN
var hive_scale: float = 1.0
var tree_attract: bool = false
var tree_attract_pulse: float = 0.0
var last_chime: float = -10.0
var twitch_cd: float = C.TWITCH_INTERVAL * 0.4

var dragging: bool = false
var dsx: float = 0.0
var dsy: float = 0.0
var hx: float = 0.0
var hy: float = 0.0
var pulse_hex_glow: float = 1.0

var trails: Array = []
var stroke_pts: Array = []
var stroke_t0: float = 0.0
var stroke_len: float = 0.0
var pointer_meta: Dictionary = {"dpr": 1.0, "touch": false}
var miss_fx: Array = []
var snap_hover = null
var meadow_names: Array = []
var meadow_cols: int
var meadow_rows: int
var meadow2 = null
var second_hive = null
var highway_glow: float = 0.0
var trail_time = null
var floor2_time = null
var swarm_time = null
var join_time = null
var hint_time = null
var winter_time = null
var brass_time = null
var royal_time = null
var seeds_time = null
var mvp_end_time = null
var dusk: float = 0.0
var rust_chamber = null
var floor2: bool = false
var floor3: bool = false
var meadow_bloom: float = 0.0
var hive_pulse_sync: float = 0.0
var cold: float = 0.0
var rust_machine = null ## {x,y,r,looted}
var brass_sheen: float = 0.0
var royal_cell = null ## {x,y,glow,capped,queen}
var age3_hold_t: float = 0.0
var orbit_t: float = 0.0
var dim_all: float = 0.0
var worker_slow: float = 1.0

var idle_t: float = 0.0
var show_ghost: bool = false
var step_performs: Dictionary = {}
var emitted_wows: Dictionary = {}
var wow_queue: Array = []

# Public mirrors for renderer
var stroke_active: bool:
	get:
		return dragging and stroke_pts.size() > 1


func _init(opts: Dictionary = {}) -> void:
	silent = bool(opts.get("silent", true))
	if opts.has("rng") and opts.rng != null:
		rng = opts.rng
	elif opts.has("seed"):
		rng = ApisRng.new(int(opts.seed))
	else:
		rng = ApisRng.new(42)
	cx = float(C.W) * 0.5
	cy = float(C.H) * 0.48
	hx = cx
	hy = cy
	_init_flowers()
	_init_swarm()
	meadow_cols = int(ceil(float(C.W) / float(C.MEADOW_TILE))) + 1
	meadow_rows = int(ceil(float(C.H) / float(C.MEADOW_TILE))) + 1
	for i in range(meadow_cols * meadow_rows):
		meadow_names.append(MEADOW_VARS[i % MEADOW_VARS.size()])
	if opts.has("startAt"):
		var at: float = float(opts.startAt)
		if at >= C.START10_T - 5.0:
			bootstrap_start10()
		elif at >= C.START5_T - 5.0:
			bootstrap_start5()


func _rnd() -> float:
	return rng.next()


func _hex_key(q: int, r: int) -> String:
	return "%d,%d" % [q, r]


func _axial_to_pixel(q: int, r: int) -> Vector2:
	var size: float = C.HEX + C.HEX_GAP
	var x: float = size * (1.5 * float(q)) + cx
	var y: float = size * ((sqrt(3.0) / 2.0) * float(q) + sqrt(3.0) * float(r)) + cy
	return Vector2(x, y)


func _hex_round(q: float, r: float) -> Vector2i:
	var s: float = -q - r
	var rq: float = round(q)
	var rr: float = round(r)
	var rs: float = round(s)
	var dq: float = absf(rq - q)
	var dr: float = absf(rr - r)
	var ds: float = absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))


func _pixel_to_axial(x: float, y: float) -> Vector2i:
	var size: float = C.HEX + C.HEX_GAP
	var px: float = x - cx
	var py: float = y - cy
	var q: float = ((2.0 / 3.0) * px) / size
	var r: float = ((-1.0 / 3.0) * px + (sqrt(3.0) / 3.0) * py) / size
	return _hex_round(q, r)


func _neighbors(q: int, r: int) -> Array:
	var out: Array = []
	for cell in RING:
		out.append(Vector2i(q + cell.x, r + cell.y))
	return out


func _path_len(pts: Array) -> float:
	return G.path_length(pts)


func _sample_polyline(pts: Array, t: float, lane: float = 0.0) -> Vector2:
	## Sample 0..1 along polyline with lateral lane offset (bee streams).
	if pts.is_empty():
		return Vector2(cx, cy)
	if pts.size() == 1:
		return Vector2(float(pts[0].x), float(pts[0].y))
	var u: float = clampf(t, 0.0, 1.0)
	var total: float = maxf(1.0, _path_len(pts))
	var target: float = u * total
	var acc: float = 0.0
	for i in range(1, pts.size()):
		var a := Vector2(float(pts[i - 1].x), float(pts[i - 1].y))
		var b := Vector2(float(pts[i].x), float(pts[i].y))
		var seg: float = a.distance_to(b)
		if acc + seg >= target or i == pts.size() - 1:
			var local: float = 0.0 if seg <= 0.001 else clampf((target - acc) / seg, 0.0, 1.0)
			var p: Vector2 = a.lerp(b, local)
			var tang: Vector2 = (b - a).normalized() if seg > 0.001 else Vector2.RIGHT
			var nrm := Vector2(-tang.y, tang.x)
			return p + nrm * lane
		acc += seg
	return Vector2(float(pts[pts.size() - 1].x), float(pts[pts.size() - 1].y))


func _stream_path_for_flower(hc: Vector2, f: Dictionary, salt: int) -> Array:
	## Prefer an existing trail that ends near the flower; else curved hive→flower ribbon.
	var best: Array = []
	var best_d := INF
	for tr in trails:
		if tr.pts.size() < 2:
			continue
		var last = tr.pts[tr.pts.size() - 1]
		var d: float = G.hypot(float(last.x) - float(f.x), float(last.y) - float(f.y))
		if d < best_d and d < 90.0:
			best_d = d
			best = tr.pts
	if best.size() >= 2:
		return best
	var bend := Vector2(-16.0 + float(salt % 5) * 4.0, 10.0 - float(salt % 3) * 3.0)
	var pts: Array = []
	var steps := 8
	for s in range(steps + 1):
		var u: float = float(s) / float(steps)
		var p: Vector2 = hc.lerp(Vector2(float(f.x), float(f.y)), u) + bend * sin(u * PI)
		pts.append({"x": p.x, "y": p.y})
	return pts


func _init_flowers() -> void:
	flowers.clear()
	var n_flowers: int = C.FLOWER_MIN + int(floor(_rnd() * float(C.FLOWER_MAX - C.FLOWER_MIN + 1)))
	var bands: Array = [
		{"min": 210.0, "max": 250.0, "n": 3},
		{"min": 270.0, "max": 330.0, "n": 4},
		{"min": 350.0, "max": 430.0, "n": n_flowers - 7},
	]
	for band in bands:
		var placed := 0
		var tries := 0
		while placed < maxi(0, int(band.n)) and tries < 400:
			tries += 1
			var ang: float = _rnd() * TAU
			var dist: float = band.min + _rnd() * (band.max - band.min)
			var x: float = cx + cos(ang) * dist
			var y: float = cy + sin(ang) * dist * 0.82
			if x < 40.0 or x > float(C.W) - 40.0 or y < 40.0 or y > float(C.H) - 40.0:
				continue
			var ok := true
			for f in flowers:
				if G.hypot(f.x - x, f.y - y) <= 70.0:
					ok = false
					break
			if ok:
				flowers.append({
					"x": x, "y": y,
					"r": C.FLOWER_R * (0.85 + _rnd() * 0.35),
					"ph": _rnd() * 6.0,
					"bloom": 0.25 + _rnd() * 0.2,
					"visits": 0,
					"hint": 0.0,
					"variant": FLOWER_VARS[flowers.size() % 3],
					"tree": false,
				})
				placed += 1
	var guard := 0
	while flowers.size() < n_flowers and guard < 900:
		guard += 1
		var ang2: float = _rnd() * TAU
		var dist2: float = 240.0 + _rnd() * 160.0
		var x2: float = cx + cos(ang2) * dist2
		var y2: float = cy + sin(ang2) * dist2 * 0.82
		if x2 < 40.0 or x2 > float(C.W) - 40.0 or y2 < 40.0 or y2 > float(C.H) - 40.0:
			continue
		var ok2 := true
		for f2 in flowers:
			if G.hypot(f2.x - x2, f2.y - y2) <= 70.0:
				ok2 = false
				break
		if ok2:
			flowers.append({
				"x": x2, "y": y2,
				"r": C.FLOWER_R * (0.85 + _rnd() * 0.35),
				"ph": _rnd() * 6.0,
				"bloom": 0.25 + _rnd() * 0.2,
				"visits": 0,
				"hint": 0.0,
				"variant": FLOWER_VARS[flowers.size() % 3],
				"tree": false,
			})
	# Golden tree
	var mx := 0.0
	var my := 0.0
	for f3 in flowers:
		mx += f3.x
		my += f3.y
	mx /= float(maxi(1, flowers.size()))
	my /= float(maxi(1, flowers.size()))
	var corners: Array = [
		Vector2(C.TREE_EDGE + C.TREE_R, C.TREE_EDGE + C.TREE_R),
		Vector2(float(C.W) - C.TREE_EDGE - C.TREE_R, C.TREE_EDGE + C.TREE_R),
		Vector2(C.TREE_EDGE + C.TREE_R, float(C.H) - C.TREE_EDGE - C.TREE_R),
		Vector2(float(C.W) - C.TREE_EDGE - C.TREE_R, float(C.H) - C.TREE_EDGE - C.TREE_R),
	]
	var best: Vector2 = corners[0]
	var bd := -1.0
	for c in corners:
		var d: float = G.hypot(c.x - mx, c.y - my) + G.hypot(c.x - cx, c.y - cy) * 0.3
		if d > bd:
			bd = d
			best = c
	flowers.append({
		"x": best.x, "y": best.y, "r": C.TREE_R, "ph": _rnd() * 6.0,
		"bloom": 0.55, "visits": 0, "tree": true, "hint": 0.0,
	})


func _init_swarm() -> void:
	swarm.clear()
	for _i in range(C.SWARM_DOTS):
		swarm.append({
			"a": _rnd() * TAU,
			"r": 14.0 + _rnd() * 18.0,
			"spd": 0.7 + _rnd() * 1.1,
		})


func _bump_perform(step_id: String) -> void:
	step_performs[step_id] = int(step_performs.get(step_id, 0)) + 1


func _can_ghost(step_id: String) -> bool:
	return int(step_performs.get(step_id, 0)) < MAX_GHOST_PERFORMS


func _emit_wow(id: String, label: String, t) -> void:
	if t == null or emitted_wows.has(id):
		return
	emitted_wows[id] = true
	wow_queue.append({"id": id, "label": label, "time": t})


func note_pointer() -> void:
	idle_t = 0.0
	show_ghost = false


func _built_count() -> int:
	var n := 0
	for c in chambers.values():
		if c.grow >= 1.0:
			n += 1
	return n


func _reach() -> float:
	return C.REACH_BASE + float(_built_count()) * C.REACH_PER_CHAMBER


func _hive_center() -> Vector2:
	if core != null:
		return Vector2(core.x, core.y)
	return Vector2(cx, cy)


func _is_adjacent_to_hive(q: int, r: int) -> bool:
	if not planted:
		return q == 0 and r == 0
	if q == 0 and r == 0:
		return false
	if chambers.has(_hex_key(q, r)):
		return false
	for n in _neighbors(q, r):
		if n.x == 0 and n.y == 0:
			return true
		var ch = chambers.get(_hex_key(n.x, n.y))
		if ch != null and ch.grow >= 1.0:
			return true
	return false


func _sfx_dum(deep: bool = false) -> void:
	if silent:
		return
	SwarmSfx.play_dum(deep)


func _sfx_soft(kind: String) -> void:
	if silent:
		return
	SwarmSfx.play_soft(kind)


func _sfx_bzz() -> void:
	if silent:
		return
	SwarmSfx.play_bzz()


func _sfx_chime() -> void:
	if silent:
		return
	SwarmSfx.play_chime()


func _try_build(q: int, r: int) -> bool:
	if not planted:
		if q != 0 or r != 0:
			return false
		planted = true
		core = {"x": cx, "y": cy}
		_sfx_dum(false)
		SwarmSfx.play_place(false)
		var best: Vector2i = RING[0]
		var bd := INF
		for cell in RING:
			var p: Vector2 = _axial_to_pixel(cell.x, cell.y)
			for f in flowers:
				if f.get("tree", false):
					continue
				var d: float = G.hypot(f.x - p.x, f.y - p.y)
				if d < bd:
					bd = d
					best = cell
		var key := _hex_key(best.x, best.y)
		chambers[key] = {
			"q": best.x, "r": best.y, "grow": 0.0, "growDur": C.BUILD_DUR_FIRST,
			"amber": 0.0, "hatchT": 0.0, "hatched": false, "pulse": 0.0,
		}
		wax = maxf(0.0, wax - C.WAX_COST)
		return true
	if not _is_adjacent_to_hive(q, r):
		return false
	if chambers.has(_hex_key(q, r)):
		return false
	if wax < C.WAX_MIN:
		shiver = C.SHIVER_DUR
		_sfx_bzz()
		return false
	chambers[_hex_key(q, r)] = {
		"q": q, "r": r, "grow": 0.0, "growDur": C.BUILD_DUR,
		"amber": 0.0, "hatchT": 0.0, "hatched": false, "pulse": 0.0,
	}
	wax = maxf(0.0, wax - C.WAX_COST)
	_sfx_soft("gesture")
	SwarmSfx.play_place(true)
	return true


func _check_ring() -> void:
	if ring_closed:
		return
	for cell in RING:
		var ch = chambers.get(_hex_key(cell.x, cell.y))
		if ch == null or ch.grow < 1.0:
			return
	ring_closed = true
	ring_time = time
	_sfx_dum(true)
	hive_scale = 1.18
	core_pulse = 1.0


func _check_traffic() -> void:
	if traffic:
		return
	if workers.size() >= C.TRAFFIC_WORKERS and routes.size() >= C.TRAFFIC_ROUTES:
		var was := traffic
		traffic = true
		if traffic_time == null:
			traffic_time = time
			if not was:
				_sfx_soft("dual")


func _spawn_bloom() -> void:
	var non_tree := 0
	for f in flowers:
		if not f.get("tree", false):
			non_tree += 1
	if non_tree >= C.BLOOM_MAX:
		return
	if not traffic and routes.size() < 2:
		return
	var hc := _hive_center()
	for route in routes:
		non_tree = 0
		for f2 in flowers:
			if not f2.get("tree", false):
				non_tree += 1
		if non_tree >= C.BLOOM_MAX:
			break
		if route.flower < 0 or route.flower >= flowers.size():
			continue
		var f = flowers[route.flower]
		if f.get("tree", false):
			continue
		var t: float = 0.35 + _rnd() * 0.4
		var bx: float = hc.x + (f.x - hc.x) * t + (_rnd() - 0.5) * 50.0
		var by: float = hc.y + (f.y - hc.y) * t + (_rnd() - 0.5) * 40.0
		if bx < 30.0 or bx > float(C.W) - 30.0 or by < 30.0 or by > float(C.H) - 30.0:
			continue
		var ok := true
		for o in flowers:
			if G.hypot(o.x - bx, o.y - by) <= 55.0:
				ok = false
				break
		if ok:
			flowers.append({
				"x": bx, "y": by,
				"r": C.FLOWER_R * (0.7 + _rnd() * 0.4),
				"ph": _rnd() * 6.0, "bloom": 0.15, "visits": 0, "hint": 0.0,
				"variant": FLOWER_VARS[flowers.size() % 3], "tree": false,
			})


func _assign_route(flower_idx: int) -> bool:
	if flower_idx < 0 or flower_idx >= flowers.size():
		return false
	var f = flowers[flower_idx]
	var hc := _hive_center()
	var dist: float = G.hypot(f.x - hc.x, f.y - hc.y)
	var rch := _reach()
	if dist > rch + 8.0:
		return false
	if f.get("tree", false):
		if _built_count() < C.TREE_MIN_CHAMBERS:
			return false
		if not big_flight:
			big_flight = true
			big_flight_time = time
			big_flight_t = 0.0
			_sfx_dum(true)
			cam_zoom_target = C.CAM_ZOOM_OUT
			wax = minf(C.WAX_MAX, wax + 0.55)
			for ch in chambers.values():
				ch.amber = minf(1.0, ch.amber + 0.7)
			core_pulse = 1.0
		return true
	var has := false
	for rt in routes:
		if rt.flower == flower_idx:
			has = true
			break
	if not has:
		routes.append({"flower": flower_idx, "glow": 0.4})
		_bump_perform("route")
		_bump_perform("traffic")
	for w in workers:
		if w.flower < 0:
			w.flower = flower_idx
			w.t = 0.0
			w.outbound = true
			w.carrying = false
	return true


func _nearest_flower_idx(x: float, y: float, max_dist: float) -> int:
	var best := -1
	var bd := max_dist
	for i in range(flowers.size()):
		var d: float = G.hypot(flowers[i].x - x, flowers[i].y - y)
		if d < bd:
			bd = d
			best = i
	return best


func _spawn_meadow2() -> void:
	if meadow2 != null or core == null:
		return
	var tree = null
	for f in flowers:
		if f.get("tree", false):
			tree = f
			break
	var ang: float
	if tree != null:
		ang = atan2(tree.y - cy, tree.x - cx) + PI * 0.55
	else:
		ang = _rnd() * TAU
	var x: float = cx + cos(ang) * C.MEADOW2_DIST
	var y: float = cy + sin(ang) * C.MEADOW2_DIST * 0.82
	x = clampf(x, 80.0, float(C.W) - 80.0)
	y = clampf(y, 70.0, float(C.H) - 70.0)
	meadow2 = {"x": x, "y": y, "r": 48.0}
	for i in range(5):
		var a: float = _rnd() * TAU
		var d: float = 20.0 + _rnd() * 40.0
		flowers.append({
			"x": x + cos(a) * d, "y": y + sin(a) * d * 0.8,
			"r": C.FLOWER_R * (0.9 + _rnd() * 0.3), "ph": _rnd() * 6.0,
			"bloom": 0.35, "visits": 0, "hint": 0.0,
			"variant": FLOWER_VARS[flowers.size() % 3], "tree": false,
		})


func _classify_trail(pts: Array) -> String:
	if core == null:
		return "meadow"
	var last = pts[pts.size() - 1]
	var first = pts[0]
	var length := _path_len(pts)
	var a0: float = atan2(first.y - cy, first.x - cx)
	var a1: float = atan2(last.y - cy, last.x - cx)
	var da: float = absf(a1 - a0)
	if da > PI:
		da = TAU - da
	var mean_dist := 0.0
	for p in pts:
		mean_dist += G.hypot(p.x - cx, p.y - cy)
	mean_dist /= float(pts.size())
	if trail_time != null and floor2_time == null and da > 1.1 and mean_dist < 150.0:
		return "arc"
	if floor2_time != null and swarm_time == null and length >= C.TRAIL_MIN_LEN:
		var outward: bool = G.hypot(last.x - cx, last.y - cy) > 200.0
		var near_meadow := meadow2 != null and G.hypot(last.x - meadow2.x, last.y - meadow2.y) < 120.0
		if outward or near_meadow:
			return "highway"
	if swarm_time != null and join_time == null and second_hive != null and length >= C.TRAIL_MIN_LEN * 0.7:
		return "join"
	if meadow2 != null and G.hypot(last.x - meadow2.x, last.y - meadow2.y) < maxf(90.0, C.TRAIL_FINISH_PX * 1.4):
		if second_hive != null and join_time == null:
			return "join"
		if swarm_time == null:
			return "highway"
	## Age 3: winter cluster (loop near hive) then brass trail to rust machine.
	if hint_time != null and winter_time == null and da > 1.0 and mean_dist < 170.0:
		return "winter"
	if (
		winter_time != null and brass_time == null and rust_machine != null
		and G.hypot(last.x - rust_machine.x, last.y - rust_machine.y) < maxf(100.0, C.TRAIL_FINISH_PX * 1.6)
		and length >= C.TRAIL_MIN_LEN * 0.75
	):
		return "brass"
	return "meadow"


func _resolve_connect_snap(x: float, y: float):
	var snap: float = G.snap_radius(pointer_meta)
	var hc := _hive_center()
	var flower_pts: Array = []
	for i in range(flowers.size()):
		flower_pts.append({"x": flowers[i].x, "y": flowers[i].y, "i": i})
	var f_hit = G.nearest_target(x, y, flower_pts, snap)
	if f_hit is Dictionary and f_hit.has("target"):
		var t = f_hit.target
		return {"x": t.x, "y": t.y, "kind": "flower", "flowerIdx": t.i}
	if second_hive != null and G.hypot(x - second_hive.x, y - second_hive.y) < maxf(snap, C.TRAIL_FINISH_PX):
		return {"x": second_hive.x, "y": second_hive.y, "kind": "hive"}
	if meadow2 != null and G.hypot(x - meadow2.x, y - meadow2.y) < maxf(snap, C.TRAIL_FINISH_PX):
		return {"x": meadow2.x, "y": meadow2.y, "kind": "meadow"}
	if rust_machine != null and G.hypot(x - rust_machine.x, y - rust_machine.y) < maxf(snap, C.TRAIL_FINISH_PX * 1.2):
		return {"x": rust_machine.x, "y": rust_machine.y, "kind": "machine"}
	if G.hypot(x - hc.x, y - hc.y) < snap:
		return {"x": hc.x, "y": hc.y, "kind": "hive"}
	return null


func _build_along_trail(trail: Dictionary, target_built: float) -> void:
	if core == null:
		return
	while trail.built < target_built - 0.001:
		var u: float = minf(0.999, trail.built + 0.02)
		var total: float = _path_len(trail.pts)
		var remain: float = u * total
		var x: float = trail.pts[0].x
		var y: float = trail.pts[0].y
		for i in range(1, trail.pts.size()):
			var d: float = G.hypot(trail.pts[i].x - trail.pts[i - 1].x, trail.pts[i].y - trail.pts[i - 1].y)
			if remain <= d:
				var t: float = (remain / d) if d > 0.0 else 0.0
				x = trail.pts[i - 1].x + (trail.pts[i].x - trail.pts[i - 1].x) * t
				y = trail.pts[i - 1].y + (trail.pts[i].y - trail.pts[i - 1].y) * t
				break
			remain -= d
			x = trail.pts[i].x
			y = trail.pts[i].y
		var ax := _pixel_to_axial(x, y)
		var q: int = ax.x
		var r: int = ax.y
		var key := _hex_key(q, r)
		if _is_adjacent_to_hive(q, r) or (trail.kind != "meadow" and not chambers.has(key)):
			if not chambers.has(key):
				var adj := _is_adjacent_to_hive(q, r)
				if adj and wax >= C.WAX_MIN * 0.5:
					chambers[key] = {
						"q": q, "r": r, "grow": 0.0, "growDur": C.BUILD_DUR * 0.75,
						"amber": 0.15, "hatchT": 0.0, "hatched": false, "pulse": 0.4,
					}
					wax = maxf(0.15, wax - C.WAX_COST * 0.55)
				elif not adj:
					var best = null
					var bd := INF
					for ch in chambers.values():
						if ch.grow < 1.0:
							continue
						for n in _neighbors(ch.q, ch.r):
							if n.x == 0 and n.y == 0:
								continue
							if chambers.has(_hex_key(n.x, n.y)):
								continue
							var p: Vector2 = _axial_to_pixel(n.x, n.y)
							var d2: float = G.hypot(p.x - x, p.y - y)
							if d2 < bd and d2 < C.TRAIL_BUILD_SPACING * 1.6:
								bd = d2
								best = n
					if best != null and wax >= C.WAX_MIN * 0.4:
						chambers[_hex_key(best.x, best.y)] = {
							"q": best.x, "r": best.y, "grow": 0.0, "growDur": C.BUILD_DUR * 0.7,
							"amber": 0.2, "hatchT": 0.0, "hatched": false, "pulse": 0.5,
						}
						wax = maxf(0.15, wax - C.WAX_COST * 0.5)
		trail.built = minf(1.0, trail.built + C.TRAIL_BUILD_SPACING / maxf(total, 1.0))
		if trail.built >= target_built or trail.built >= 1.0:
			break


func _activate_trail(pts: Array) -> bool:
	if pts.size() < C.TRAIL_MIN_PTS or _path_len(pts) < C.TRAIL_MIN_LEN:
		return false
	var kind := _classify_trail(pts)
	var copied: Array = []
	for p in pts:
		copied.append({"x": p.x, "y": p.y})
	var trail := {"pts": copied, "glow": 1.0, "built": 0.0, "kind": kind}
	trails.append(trail)
	if kind == "meadow" and trail_time == null:
		trail_time = time
		_bump_perform("trail")
		_sfx_soft("open")
		wax = minf(C.WAX_MAX, wax + 0.35)
	elif kind == "arc" and floor2_time == null:
		floor2_time = time
		_bump_perform("arc")
		_sfx_soft("copper")
		_sfx_dum(true)
		floor2 = true
		hive_scale = maxf(hive_scale, 1.32)
		core_pulse = 1.0
		for cell in RING:
			for n in _neighbors(cell.x, cell.y):
				if n.x == 0 and n.y == 0:
					continue
				var on_ring := false
				for rq in RING:
					if rq.x == n.x and rq.y == n.y:
						on_ring = true
						break
				if on_ring:
					continue
				var k := _hex_key(n.x, n.y)
				if chambers.has(k):
					continue
				var p: Vector2 = _axial_to_pixel(n.x, n.y)
				var near := false
				for pt in pts:
					if G.hypot(pt.x - p.x, pt.y - p.y) < 55.0:
						near = true
						break
				if near:
					chambers[k] = {
						"q": n.x, "r": n.y, "grow": 0.0, "growDur": C.BUILD_DUR * 0.85,
						"amber": 0.25, "hatchT": 0.0, "hatched": false, "pulse": 0.6,
					}
	elif kind == "highway" and swarm_time == null:
		swarm_time = time
		_bump_perform("swarm")
		_sfx_soft("dual")
		var last = pts[pts.size() - 1]
		second_hive = {
			"x": meadow2.x if meadow2 != null else last.x,
			"y": meadow2.y if meadow2 != null else last.y,
			"chambers": 3, "pulse": 1.0,
		}
		highway_glow = 1.0
		var sent := 0
		var limit: int = int(floor(float(workers.size()) * 0.35))
		for w in workers:
			if sent >= limit:
				break
			if w.flower >= 0 and _rnd() < 0.5:
				continue
			w.flower = -2
			w.t = 0.0
			w.outbound = true
			w.carrying = false
			sent += 1
	elif kind == "join" and join_time == null and second_hive != null:
		join_time = time
		_bump_perform("join")
		_sfx_soft("chord")
		highway_glow = 1.4
		hive_pulse_sync = 1.0
		meadow_bloom = 1.0
		core_pulse = 1.0
		second_hive.pulse = 1.0
		for f in flowers:
			if not f.get("tree", false):
				f.bloom = minf(1.0, f.bloom + 0.55)
		for i in range(8):
			var t: float = 0.2 + _rnd() * 0.6
			var x: float = cx + (second_hive.x - cx) * t + (_rnd() - 0.5) * 60.0
			var y: float = cy + (second_hive.y - cy) * t + (_rnd() - 0.5) * 50.0
			if x < 30.0 or x > float(C.W) - 30.0 or y < 30.0 or y > float(C.H) - 30.0:
				continue
			flowers.append({
				"x": x, "y": y, "r": C.FLOWER_R * (0.8 + _rnd() * 0.4),
				"ph": _rnd() * 6.0, "bloom": 0.7, "visits": 0, "hint": 0.0,
				"variant": FLOWER_VARS[flowers.size() % 3], "tree": false,
			})
	elif kind == "winter" and winter_time == null:
		_trigger_winter()
	elif kind == "brass" and brass_time == null:
		_trigger_brass()
	return true


func _spawn_rust_machine() -> void:
	if rust_machine != null:
		return
	var ang: float = PI * 0.15 + _rnd() * 0.4
	if meadow2 != null:
		ang = atan2(meadow2.y - cy, meadow2.x - cx) + PI * 0.35
	var x: float = cx + cos(ang) * C.RUST_MACHINE_DIST
	var y: float = cy + sin(ang) * C.RUST_MACHINE_DIST * 0.8
	x = clampf(x, 70.0, float(C.W) - 70.0)
	y = clampf(y, 60.0, float(C.H) - 60.0)
	rust_machine = {"x": x, "y": y, "r": C.RUST_MACHINE_R, "looted": false}


func _trigger_dusk_hint() -> void:
	if hint_time != null:
		return
	hint_time = time
	_sfx_soft("wind")
	dusk = 1.0
	cold = 0.4
	worker_slow = 0.55
	var far = null
	var bd := -1.0
	for ch in chambers.values():
		if ch.grow < 1.0:
			continue
		var p: Vector2 = _axial_to_pixel(ch.q, ch.r)
		var d: float = G.hypot(p.x - cx, p.y - cy)
		if d > bd:
			bd = d
			far = ch
	if far != null:
		rust_chamber = _hex_key(far.q, far.r)
	_spawn_rust_machine()


func _trigger_winter() -> void:
	if winter_time != null:
		return
	winter_time = time
	_bump_perform("winter")
	_sfx_soft("dual")
	_sfx_dum(true)
	cold = 0.0
	worker_slow = 1.0
	dusk = maxf(0.0, dusk - 0.5)
	core_pulse = 1.0
	hive_pulse_sync = 1.0
	## Cluster workers into a warm ball near hive.
	for w in workers:
		if _rnd() < 0.65:
			w.flower = -3
			w.t = _rnd()
	meadow_bloom = maxf(meadow_bloom, 0.6)


func _trigger_brass() -> void:
	if brass_time != null or rust_machine == null:
		return
	brass_time = time
	_bump_perform("brass")
	_sfx_soft("copper")
	rust_machine.looted = true
	brass_sheen = 1.0
	core_pulse = 1.0
	for ch in chambers.values():
		if ch.grow >= 1.0:
			ch.amber = minf(1.0, ch.amber + 0.35)
			ch.pulse = 1.0
	meadow_bloom = 1.0
	for f in flowers:
		if not f.get("tree", false):
			f.bloom = minf(1.0, f.bloom + 0.4)


func _trigger_royal() -> void:
	if royal_time != null:
		return
	royal_time = time
	_bump_perform("royal")
	_sfx_soft("chord")
	_sfx_dum(true)
	floor3 = true
	hive_scale = maxf(hive_scale, 1.55)
	core_pulse = 1.0
	hive_pulse_sync = 1.0
	royal_cell = {"x": cx, "y": cy - 18.0, "glow": 0.6, "capped": false, "queen": 0.0}
	if second_hive != null:
		second_hive.pulse = 1.0


func _trigger_seeds_hint() -> void:
	if seeds_time != null or royal_cell == null:
		return
	seeds_time = time
	_sfx_soft("open")
	dim_all = 1.0
	royal_cell.capped = true
	royal_cell.glow = 1.0
	royal_cell.queen = 0.4


func _trigger_mvp_end() -> void:
	if mvp_end_time != null:
		return
	mvp_end_time = time
	_sfx_soft("chord")
	orbit_t = 0.01
	cam_zoom_target = 0.22
	if royal_cell != null:
		royal_cell.queen = 1.0
		royal_cell.glow = 1.0


func update(dt: float) -> void:
	time += dt
	G.tick_miss(miss_fx, dt)
	idle_t += dt
	if idle_t >= IDLE_GHOST_S:
		show_ghost = true
	if shiver > 0.0:
		shiver = maxf(0.0, shiver - dt)
	if core_pulse > 0.0:
		core_pulse = maxf(0.0, core_pulse - dt * 0.7)
	pulse_hex_glow = 0.55 + 0.45 * sin(time * 2.4)
	## Gentle zoom-out with hive growth so minute 15 shows the whole work.
	if mvp_end_time == null:
		var growth: float = clampf(
			float(chambers.size()) / 40.0 * 0.4
			+ float(trails.size()) / 6.0 * 0.2
			+ float(workers.size()) / 80.0 * 0.15
			+ time / 900.0 * 0.35,
			0.0, 1.0
		)
		var z_goal: float = lerpf(C.CAM_ZOOM_IN, C.CAM_ZOOM_OUT, growth)
		if time > 600.0:
			z_goal = lerpf(z_goal, C.CAM_ZOOM_OUT * 0.9, clampf((time - 600.0) / 280.0, 0.0, 1.0))
		if z_goal < cam_zoom_target:
			cam_zoom_target = z_goal
	cam_zoom += (cam_zoom_target - cam_zoom) * minf(1.0, dt / (C.CAM_ZOOM_DUR * 0.35))
	if big_flight:
		big_flight_t += dt

	for ch in chambers.values():
		if ch.grow < 1.0:
			ch.grow = minf(1.0, ch.grow + dt / ch.growDur)
			if ch.grow >= 1.0:
				ch.grow = 1.0
				_check_ring()
		elif not ch.hatched:
			ch.hatchT += dt
			if ch.hatchT >= C.HATCH_DELAY and workers.size() < C.MAX_WORKERS:
				ch.hatched = true
				var p: Vector2 = _axial_to_pixel(ch.q, ch.r)
				workers.append({
					"x": p.x, "y": p.y, "flower": -1, "t": 0.0,
					"outbound": true, "carrying": false, "phase": _rnd() * 6.0,
					"twitch": 0.0, "hintFlower": -1,
				})
				if first_worker == null:
					first_worker = time
					_sfx_dum(false)
				core_pulse = maxf(core_pulse, 0.6)
				if routes.size() > 0:
					var rt = routes[workers.size() % routes.size()]
					workers[workers.size() - 1].flower = rt.flower
		if ch.pulse > 0.0:
			ch.pulse = maxf(0.0, ch.pulse - dt)
		if ch.amber > 0.02:
			ch.amber *= 1.0 - dt * 0.04

	var hc := _hive_center()
	var rch := _reach()
	twitch_cd -= dt
	if twitch_cd <= 0.0:
		twitch_cd = C.TWITCH_INTERVAL + _rnd() * 1.4
		var idle: Array = []
		for w0 in workers:
			if w0.flower < 0 and w0.twitch <= 0.0:
				idle.append(w0)
		if idle.size() > 0:
			var w = idle[int(floor(_rnd() * float(idle.size())))]
			var best := -1
			var bd := rch + 8.0
			for i in range(flowers.size()):
				var f = flowers[i]
				if f.get("tree", false):
					continue
				var d: float = G.hypot(f.x - hc.x, f.y - hc.y)
				if d < bd:
					bd = d
					best = i
			if best >= 0:
				w.twitch = C.TWITCH_DUR
				w.hintFlower = best
				flowers[best].hint = 1.0

	for w in workers:
		w.phase += dt
		if w.twitch > 0.0:
			w.twitch = maxf(0.0, w.twitch - dt)
		if w.flower == -3:
			## Winter cluster — orbit as a warm ball near the hive.
			var angw: float = w.phase * 2.4 + w.phase
			var rr: float = 18.0 + 8.0 * sin(time * 1.5 + w.phase)
			w.x = hc.x + cos(angw) * rr
			w.y = hc.y + sin(angw) * rr * 0.85
			continue
		if w.flower == -2 and second_hive != null:
			var tx: float = second_hive.x
			var ty: float = second_hive.y
			var dist: float = G.hypot(tx - hc.x, ty - hc.y)
			w.t += (C.WORKER_SPEED * worker_slow * dt) / maxf(40.0, dist)
			if w.outbound:
				if w.t >= 1.0:
					w.t = 0.0
					w.outbound = false
				var u: float = minf(1.0, w.t)
				w.x = hc.x + (tx - hc.x) * u
				w.y = hc.y + (ty - hc.y) * u
			else:
				var ang: float = w.phase * 1.1
				w.x = tx + cos(ang) * (14.0 + fmod(w.phase, 4.0))
				w.y = ty + sin(ang) * (12.0 + fmod(w.phase, 3.0))
			continue
		if w.flower < 0:
			var ang2: float = w.phase * 0.8
			var ox: float = hc.x + cos(ang2) * (22.0 + fmod(w.phase, 5.0))
			var oy: float = hc.y + sin(ang2) * (18.0 + fmod(w.phase, 4.0))
			if w.twitch > 0.0 and w.hintFlower >= 0 and w.hintFlower < flowers.size():
				var hf = flowers[w.hintFlower]
				var k: float = (w.twitch / C.TWITCH_DUR) * 0.35
				ox += (hf.x - hc.x) * k * 0.12
				oy += (hf.y - hc.y) * k * 0.12
			w.x = ox
			w.y = oy
			continue
		if w.flower >= flowers.size():
			w.flower = -1
			continue
		var f = flowers[w.flower]
		var spd: float = (C.WORKER_SPEED if w.outbound else C.WORKER_SPEED_RETURN) * worker_slow
		var dist2: float = G.hypot(f.x - hc.x, f.y - hc.y)
		var travel: float = maxf(40.0, dist2)
		w.t += (spd * dt) / travel
		## Stream bees along pheromone polylines (timing still uses straight-line travel).
		var salt: int = int(floor(float(w.phase) * 17.0))
		var path_pts: Array = _stream_path_for_flower(hc, f, salt)
		var lane: float = (fmod(float(w.phase) * 0.618, 1.0) - 0.5) * 14.0
		if w.outbound:
			if w.t >= 1.0:
				w.t = 1.0
				w.outbound = false
				w.carrying = true
				f.visits += 1
				f.bloom = minf(1.0, f.bloom + 0.12)
				w.t = 0.0
			var u2: float = w.t
			var pos2: Vector2 = _sample_polyline(path_pts, u2, lane)
			w.x = pos2.x
			w.y = pos2.y
		else:
			if w.t >= 1.0:
				w.t = 0.0
				w.outbound = true
				if w.carrying:
					w.carrying = false
					wax = minf(C.WAX_MAX, wax + C.WAX_NECTAR)
					var is_first: bool = first_nectar == null
					if is_first:
						first_nectar = time
						_sfx_soft("open")
					var full: bool = is_first or time - last_full_nectar >= C.NECTAR_FULL_CD
					if full:
						last_full_nectar = time
						for ch2 in chambers.values():
							if ch2.grow >= 1.0:
								ch2.amber = minf(1.0, ch2.amber + 0.45)
								ch2.pulse = 1.0
						pulses.append({"x0": w.x, "y0": w.y, "x1": hc.x, "y1": hc.y, "t": 0.0, "dur": 0.55})
						core_pulse = 1.0
					else:
						var nearest = null
						var nd := INF
						for ch3 in chambers.values():
							if ch3.grow < 1.0:
								continue
							var pp: Vector2 = _axial_to_pixel(ch3.q, ch3.r)
							var d3: float = G.hypot(pp.x - w.x, pp.y - w.y)
							if d3 < nd:
								nd = d3
								nearest = ch3
						if nearest != null:
							nearest.amber = minf(1.0, nearest.amber + 0.18)
							nearest.pulse = 0.7
			var u3: float = w.t
			var pos3: Vector2 = _sample_polyline(path_pts, 1.0 - u3, -lane)
			w.x = pos3.x
			w.y = pos3.y

	for f4 in flowers:
		if f4.hint > 0.0:
			f4.hint = maxf(0.0, f4.hint - dt * 1.2)
	for p4 in pulses:
		p4.t += dt
	for i in range(pulses.size() - 1, -1, -1):
		if pulses[i].t >= pulses[i].dur:
			pulses.remove_at(i)
	for rt in routes:
		rt.glow = 0.25 + 0.2 * sin(time * 2.0 + float(rt.flower))

	var tree = null
	for f5 in flowers:
		if f5.get("tree", false):
			tree = f5
			break
	if tree != null and not big_flight and planted:
		var td: float = G.hypot(tree.x - hc.x, tree.y - hc.y)
		var need_reach: int = maxi(0, int(ceil((td - rch - 8.0) / C.REACH_PER_CHAMBER)))
		var need_min: int = maxi(0, C.TREE_MIN_CHAMBERS - _built_count())
		var lead: int = maxi(need_reach, need_min)
		var was := tree_attract
		tree_attract = lead > 0 and lead <= C.TREE_ATTRACT_LEAD
		if tree_attract:
			tree_attract_pulse = 0.45 + 0.35 * sin(time * 2.2)
			if not was or time - last_chime > 4.5:
				last_chime = time
				_sfx_chime()
		else:
			tree_attract_pulse = maxf(0.0, tree_attract_pulse - dt)

	_check_traffic()
	if traffic and int(floor(time * 2.0)) != int(floor((time - dt) * 2.0)):
		_spawn_bloom()
	if ring_closed and hive_scale > 1.08 and not floor2:
		hive_scale += (1.1 - hive_scale) * minf(1.0, dt * 0.4)
	if floor2 and hive_scale < 1.28:
		hive_scale += (1.3 - hive_scale) * minf(1.0, dt * 0.35)
	if big_flight:
		_spawn_meadow2()
	for tr in trails:
		tr.glow = 0.55 + 0.35 * sin(time * 2.5)
		if tr.built < 1.0 and tr.kind in ["meadow", "highway", "join"]:
			var step: float = C.TRAIL_BUILD_RATE * dt * (C.TRAIL_BUILD_SPACING / maxf(_path_len(tr.pts), 1.0))
			_build_along_trail(tr, minf(1.0, tr.built + step * 8.0))
	if highway_glow > 0.3:
		highway_glow = 0.55 + 0.45 * sin(time * 2.2)
	if hive_pulse_sync > 0.0:
		hive_pulse_sync = maxf(0.35, 0.55 + 0.45 * sin(time * 2.0))
		core_pulse = maxf(core_pulse, hive_pulse_sync * 0.5)
		if second_hive != null:
			second_hive.pulse = hive_pulse_sync
	if meadow_bloom > 0.0:
		meadow_bloom = maxf(0.4, meadow_bloom - dt * 0.02)
	if join_time != null and hint_time == null and time >= 595.0:
		_trigger_dusk_hint()
	if dusk > 0.0 and winter_time == null:
		dusk = minf(1.0, dusk + dt / C.HINT_DUR)
		cold = minf(1.0, cold + dt * 0.05)
		worker_slow = lerpf(0.55, 0.35, cold)
	if brass_sheen > 0.0:
		brass_sheen = maxf(0.4, brass_sheen - dt * 0.015)
	## Age 3 hold on core → royal cell / third floor.
	if brass_time != null and royal_time == null and dragging and time >= C.WOW_ROYAL - 8.0:
		if G.hypot(hx - cx, hy - cy) < C.HEX * 2.2:
			age3_hold_t += dt
			if age3_hold_t >= C.HOLD_AGE3_S:
				_trigger_royal()
		else:
			age3_hold_t = 0.0
	else:
		age3_hold_t = 0.0
	if floor3 and hive_scale < 1.58:
		hive_scale += (1.6 - hive_scale) * minf(1.0, dt * 0.4)
	if royal_cell != null and not royal_cell.capped:
		royal_cell.glow = 0.45 + 0.35 * sin(time * 2.4)
	if royal_time != null and seeds_time == null and time >= C.WOW_SEEDS - 2.0:
		_trigger_seeds_hint()
	if seeds_time != null and mvp_end_time == null and time >= C.WOW_END - 2.0:
		_trigger_mvp_end()
	if orbit_t > 0.0:
		orbit_t += dt
	if royal_cell != null and royal_cell.capped:
		royal_cell.queen = minf(1.0, royal_cell.queen + dt * 0.12)
		royal_cell.glow = 0.75 + 0.25 * sin(time * 3.0)
	if dim_all > 0.0 and mvp_end_time == null:
		dim_all = minf(1.0, dim_all + dt * 0.15)


func pointer_down(x: float, y: float, meta: Dictionary = {}) -> void:
	if not meta.is_empty():
		pointer_meta = meta
	dragging = true
	dsx = x
	dsy = y
	hx = x
	hy = y
	stroke_pts = [{"x": x, "y": y}]
	stroke_t0 = time
	stroke_len = 0.0
	snap_hover = null
	var ax := _pixel_to_axial(x, y)
	var p: Vector2 = _axial_to_pixel(ax.x, ax.y)
	if G.hypot(p.x - x, p.y - y) < C.HEX * 1.15:
		if not planted and ax.x == 0 and ax.y == 0:
			_try_build(0, 0)
			_bump_perform("plant")
			dragging = false
			stroke_pts = []
			return
		if planted and _is_adjacent_to_hive(ax.x, ax.y) and not chambers.has(_hex_key(ax.x, ax.y)):
			if _try_build(ax.x, ax.y):
				_bump_perform("build")
				_bump_perform("ring")
			dragging = false
			stroke_pts = []
			return


func pointer_move(x: float, y: float, meta: Dictionary = {}) -> void:
	if not meta.is_empty():
		pointer_meta = meta
	var px := x
	var py := y
	var snap = _resolve_connect_snap(x, y)
	snap_hover = {"x": snap.x, "y": snap.y, "kind": snap.kind} if snap != null else null
	if dragging and snap != null:
		var k := 0.55
		px = x + (snap.x - x) * k
		py = y + (snap.y - y) * k
	hx = px
	hy = py
	if not dragging:
		return
	var last = stroke_pts[stroke_pts.size() - 1] if stroke_pts.size() > 0 else null
	if last == null or G.hypot(px - last.x, py - last.y) > 5.0:
		if last != null:
			stroke_len += G.hypot(px - last.x, py - last.y)
		stroke_pts.append({"x": px, "y": py})
		if (
			big_flight
			and stroke_pts.size() >= C.TRAIL_MIN_PTS
			and _path_len(stroke_pts) >= C.TRAIL_MIN_LEN * 0.85
			and snap != null
			and (snap.kind == "hive" or snap.kind == "meadow")
			and G.hypot(px - snap.x, py - snap.y) < C.TRAIL_FINISH_PX
		):
			var dur: float = maxf(0.05, time - stroke_t0)
			var avg_spd: float = _path_len(stroke_pts) / dur
			if avg_spd <= C.TRAIL_MAX_SPEED * 1.15:
				if _activate_trail(stroke_pts):
					stroke_pts = []
					dragging = false
					snap_hover = null


func pointer_up(meta: Dictionary = {}) -> void:
	if not meta.is_empty():
		pointer_meta = meta
	if not dragging:
		snap_hover = null
		return
	dragging = false
	var dist: float = G.hypot(hx - dsx, hy - dsy)
	if dist < 18.0:
		stroke_pts = []
		snap_hover = null
		return
	var snap = _resolve_connect_snap(hx, hy)
	var pts: Array = stroke_pts.duplicate()
	if snap != null and G.hypot(hx - snap.x, hy - snap.y) < maxf(G.snap_radius(pointer_meta), C.TRAIL_FINISH_PX):
		pts.append({"x": snap.x, "y": snap.y})
		hx = snap.x
		hy = snap.y
	if big_flight and pts.size() >= C.TRAIL_MIN_PTS:
		var dur: float = maxf(0.05, time - stroke_t0)
		var avg_spd: float = _path_len(pts) / dur
		if avg_spd <= C.TRAIL_MAX_SPEED and _path_len(pts) >= C.TRAIL_MIN_LEN:
			if _activate_trail(pts):
				stroke_pts = []
				snap_hover = null
				return
		if snap != null and _path_len(pts) >= C.TRAIL_MIN_LEN * 0.75 and G.hypot(hx - snap.x, hy - snap.y) <= C.TRAIL_FINISH_PX:
			if _activate_trail(pts):
				stroke_pts = []
				snap_hover = null
				return
	var hc := _hive_center()
	var near_hive: bool = G.hypot(dsx - hc.x, dsy - hc.y) < 70.0
	if not near_hive:
		for w in workers:
			if G.hypot(dsx - w.x, dsy - w.y) < 28.0:
				near_hive = true
				break
	if not near_hive and planted:
		var near_ch := false
		for ch in chambers.values():
			var p: Vector2 = _axial_to_pixel(ch.q, ch.r)
			if G.hypot(dsx - p.x, dsy - p.y) < C.HEX * 1.4:
				near_ch = true
				break
		if not near_ch:
			if dist > 40.0:
				miss_fx.append(G.spawn_miss(hx, hy))
			stroke_pts = []
			snap_hover = null
			return
	if not planted:
		stroke_pts = []
		snap_hover = null
		return
	var snap_dist: float = maxf(55.0, G.snap_radius(pointer_meta))
	var fi := -1
	if snap != null and snap.kind == "flower" and snap.has("flowerIdx"):
		fi = int(snap.flowerIdx)
	else:
		fi = _nearest_flower_idx(hx, hy, snap_dist)
	if fi >= 0:
		if not _assign_route(fi):
			miss_fx.append(G.spawn_miss(hx, hy))
	elif dist > 40.0:
		miss_fx.append(G.spawn_miss(hx, hy))
	stroke_pts = []
	snap_hover = null


func metrics() -> Dictionary:
	return {
		"time": time,
		"chambers": _built_count(),
		"workers": workers.size(),
		"wax": wax,
		"routes": routes.size(),
		"firstWorker": first_worker,
		"firstNectar": first_nectar,
		"ringTime": ring_time,
		"trafficTime": traffic_time,
		"bigFlight": big_flight,
		"bigFlightTime": big_flight_time,
		"ringClosed": ring_closed,
		"traffic": traffic,
		"trailTime": trail_time,
		"floor2Time": floor2_time,
		"swarmTime": swarm_time,
		"joinTime": join_time,
		"hintTime": hint_time,
		"winterTime": winter_time,
		"brassTime": brass_time,
		"royalTime": royal_time,
		"seedsTime": seeds_time,
		"mvpEndTime": mvp_end_time,
	}


func snapshot() -> Dictionary:
	var chs: Array = []
	for c in chambers.values():
		chs.append({"q": c.q, "r": c.r, "grow": c.grow, "hatched": c.hatched})
	var fls: Array = []
	for f in flowers:
		fls.append({"x": f.x, "y": f.y, "tree": f.get("tree", false), "bloom": f.bloom})
	var wks: Array = []
	for w in workers:
		wks.append({"x": w.x, "y": w.y, "carrying": w.carrying, "flower": w.flower})
	return {
		"core": {"x": core.x, "y": core.y} if core != null else null,
		"chambers": chs,
		"flowers": fls,
		"workers": wks,
		"wax": wax,
		"reach": _reach(),
		"ringClosed": ring_closed,
		"traffic": traffic,
		"shivering": shiver,
		"meadow2": {"x": meadow2.x, "y": meadow2.y} if meadow2 != null else null,
		"secondHive": {"x": second_hive.x, "y": second_hive.y} if second_hive != null else null,
		"rustMachine": {"x": rust_machine.x, "y": rust_machine.y, "r": rust_machine.r, "looted": rust_machine.looted} if rust_machine != null else null,
		"royalCell": {"x": royal_cell.x, "y": royal_cell.y, "capped": royal_cell.capped} if royal_cell != null else null,
	}


func guidance() -> Dictionary:
	var hc := _hive_center()
	var near_flower = null
	var bd := INF
	for f in flowers:
		if f.get("tree", false):
			continue
		var d: float = G.hypot(f.x - hc.x, f.y - hc.y)
		if d < bd and d <= _reach() + 8.0:
			bd = d
			near_flower = f
	var tree = null
	for f2 in flowers:
		if f2.get("tree", false):
			tree = f2
			break
	if not planted:
		return {
			"stepId": "plant", "label": "Klepni — zasaď jádro",
			"target": {"x": cx, "y": cy, "r": C.HEX}, "target2": null,
			"ghost": "tap", "from": null, "to": {"x": cx, "y": cy, "r": C.HEX},
		}
	if first_worker == null or _built_count() < 2:
		var target = null
		for cell in RING:
			if not chambers.has(_hex_key(cell.x, cell.y)):
				var p: Vector2 = _axial_to_pixel(cell.x, cell.y)
				target = {"x": p.x, "y": p.y, "r": C.HEX}
				break
		return {
			"stepId": "build", "label": "Stav komory kolem",
			"target": target, "target2": null, "ghost": "tap", "from": null, "to": target,
		}
	if first_nectar == null:
		return {
			"stepId": "route", "label": "Táhni k květině",
			"target": {"x": near_flower.x, "y": near_flower.y, "r": near_flower.r} if near_flower != null else null,
			"target2": null, "ghost": "drag",
			"from": {"x": hc.x, "y": hc.y, "r": 12.0},
			"to": {"x": near_flower.x, "y": near_flower.y, "r": near_flower.r} if near_flower != null else null,
		}
	if not ring_closed:
		var target2 = null
		for cell2 in RING:
			var ch = chambers.get(_hex_key(cell2.x, cell2.y))
			if ch == null or ch.grow < 1.0:
				var p2: Vector2 = _axial_to_pixel(cell2.x, cell2.y)
				target2 = {"x": p2.x, "y": p2.y, "r": C.HEX}
				break
		return {
			"stepId": "ring", "label": "Uzavři prstenec",
			"target": target2, "target2": null, "ghost": "tap", "from": null, "to": target2,
		}
	if not traffic:
		return {
			"stepId": "traffic", "label": "Odkazuj víc dělnic",
			"target": {"x": near_flower.x, "y": near_flower.y, "r": near_flower.r} if near_flower != null else null,
			"target2": null, "ghost": "drag",
			"from": {"x": hc.x, "y": hc.y, "r": 12.0},
			"to": {"x": near_flower.x, "y": near_flower.y, "r": near_flower.r} if near_flower != null else null,
		}
	if not big_flight:
		return {
			"stepId": "tree", "label": "Dosáhni zlatého stromu",
			"target": {"x": tree.x, "y": tree.y, "r": tree.r} if tree != null else null,
			"target2": null, "ghost": "drag",
			"from": {"x": hc.x, "y": hc.y, "r": 12.0},
			"to": {"x": tree.x, "y": tree.y, "r": tree.r} if tree != null else null,
		}
	if trail_time == null:
		var ang := 0.5
		var to := {"x": hc.x + cos(ang) * 180.0, "y": hc.y + sin(ang) * 140.0, "r": 16.0}
		return {
			"stepId": "trail", "label": "Pomalu namaluj stopu",
			"target": to, "target2": null, "ghost": "trail",
			"from": {"x": hc.x, "y": hc.y, "r": 12.0}, "to": to,
		}
	if floor2_time == null:
		return {
			"stepId": "arc", "label": "Oblouk kolem úlu",
			"target": {"x": hc.x + 90.0, "y": hc.y, "r": 20.0}, "target2": null, "ghost": "trail",
			"from": {"x": hc.x + 90.0, "y": hc.y - 40.0, "r": 12.0},
			"to": {"x": hc.x + 40.0, "y": hc.y + 85.0, "r": 12.0},
		}
	if swarm_time == null:
		var dest = meadow2 if meadow2 != null else {"x": hc.x + 200.0, "y": hc.y - 80.0, "r": 24.0}
		return {
			"stepId": "swarm", "label": "Stopa k druhé louce",
			"target": {"x": dest.x, "y": dest.y, "r": 28.0}, "target2": null, "ghost": "trail",
			"from": {"x": hc.x, "y": hc.y, "r": 12.0},
			"to": {"x": dest.x, "y": dest.y, "r": 28.0},
		}
	if join_time == null and second_hive != null:
		return {
			"stepId": "join", "label": "Spoj úly stopou",
			"target": {"x": second_hive.x, "y": second_hive.y, "r": 22.0}, "target2": null, "ghost": "trail",
			"from": {"x": hc.x, "y": hc.y, "r": 12.0},
			"to": {"x": second_hive.x, "y": second_hive.y, "r": 22.0},
		}
	if hint_time != null and winter_time == null:
		return {
			"stepId": "winter", "label": "Stopa kolem úlu",
			"target": {"x": hc.x + 95.0, "y": hc.y, "r": 20.0}, "target2": null, "ghost": "trail",
			"from": {"x": hc.x + 95.0, "y": hc.y - 40.0, "r": 12.0},
			"to": {"x": hc.x + 40.0, "y": hc.y + 85.0, "r": 12.0},
		}
	if winter_time != null and brass_time == null and rust_machine != null:
		return {
			"stepId": "brass", "label": "Stopa k rozpadlé mašině",
			"target": {"x": rust_machine.x, "y": rust_machine.y, "r": rust_machine.r},
			"target2": null, "ghost": "trail",
			"from": {"x": hc.x, "y": hc.y, "r": 12.0},
			"to": {"x": rust_machine.x, "y": rust_machine.y, "r": rust_machine.r},
		}
	if brass_time != null and royal_time == null:
		return {
			"stepId": "royal", "label": "Podrž jádro",
			"target": {"x": cx, "y": cy, "r": C.HEX * 1.6},
			"target2": null, "ghost": "hold", "from": null,
			"to": {"x": cx, "y": cy, "r": C.HEX * 1.6},
		}
	if mvp_end_time != null:
		return {
			"stepId": "orbit", "label": "SWARM",
			"target": null, "target2": null, "ghost": null, "from": null, "to": null,
		}
	if seeds_time != null:
		return {
			"stepId": "seeds", "label": "Sleduj královskou buňku",
			"target": {"x": royal_cell.x, "y": royal_cell.y, "r": 16.0} if royal_cell != null else null,
			"target2": null, "ghost": null, "from": null, "to": null,
		}
	return {
		"stepId": "watch",
		"label": "Sleduj soumrak" if hint_time != null else "Sleduj louku",
		"target": null, "target2": null, "ghost": null, "from": null, "to": null,
	}


func poll_wows() -> Array:
	_emit_wow("worker", "První líhnutí", first_worker)
	_emit_wow("nectar", "První nektar", first_nectar)
	_emit_wow("ring", "Prstenec", ring_time)
	_emit_wow("traffic", "Živý provoz", traffic_time)
	_emit_wow("big", "Velký let", big_flight_time)
	_emit_wow("trail", "Feromonová stopa", trail_time)
	_emit_wow("floor2", "Druhé patro", floor2_time)
	_emit_wow("swarm", "Rojení", swarm_time)
	_emit_wow("join", "Spojení úlů", join_time)
	_emit_wow("hint", "Soumrak", hint_time)
	_emit_wow("winter", "Zimní chomáč", winter_time)
	_emit_wow("brass", "Mosazný lesk", brass_time)
	_emit_wow("royal", "Královská buňka", royal_time)
	_emit_wow("seeds", "Nová královna", seeds_time)
	_emit_wow("mvp", "Konec MVP", mvp_end_time)
	if wow_queue.is_empty():
		return []
	var out: Array = wow_queue.duplicate()
	wow_queue.clear()
	return out


func bootstrap_start10() -> void:
	bootstrap_start5()
	trail_time = C.WOW_TRAIL
	floor2_time = C.WOW_FLOOR2
	floor2 = true
	hive_scale = 1.32
	swarm_time = C.WOW_SWARM
	join_time = C.WOW_JOIN
	highway_glow = 1.0
	hive_pulse_sync = 0.8
	meadow_bloom = 0.8
	if meadow2 == null:
		_spawn_meadow2()
	if second_hive == null and meadow2 != null:
		second_hive = {"x": meadow2.x, "y": meadow2.y, "chambers": 3, "pulse": 0.8}
	time = C.START10_T
	_trigger_dusk_hint()


func bootstrap_start5() -> void:
	_try_build(0, 0)
	time = C.START5_T
	for cell in RING:
		chambers[_hex_key(cell.x, cell.y)] = {
			"q": cell.x, "r": cell.y, "grow": 1.0, "growDur": C.BUILD_DUR,
			"amber": 0.4, "hatchT": C.HATCH_DELAY, "hatched": true, "pulse": 0.0,
		}
	ring_closed = true
	ring_time = 135.0
	hive_scale = 1.12
	for cell2 in RING:
		for n in _neighbors(cell2.x, cell2.y):
			if n.x == 0 and n.y == 0:
				continue
			var on_ring := false
			for rq in RING:
				if rq.x == n.x and rq.y == n.y:
					on_ring = true
					break
			if on_ring:
				continue
			var k := _hex_key(n.x, n.y)
			if chambers.has(k):
				continue
			chambers[k] = {
				"q": n.x, "r": n.y, "grow": 1.0, "growDur": C.BUILD_DUR,
				"amber": 0.25, "hatchT": C.HATCH_DELAY, "hatched": true, "pulse": 0.0,
			}
			if _built_count() >= C.TREE_MIN_CHAMBERS + 4:
				break
		if _built_count() >= C.TREE_MIN_CHAMBERS + 4:
			break
	first_worker = 35.0
	first_nectar = 80.0
	traffic = true
	traffic_time = 200.0
	var flower_idx := -1
	for i in range(flowers.size()):
		if not flowers[i].get("tree", false):
			flower_idx = i
			break
	if flower_idx >= 0:
		routes.append({"flower": flower_idx, "glow": 0.4})
		_assign_route(flower_idx)
	while workers.size() < 40:
		workers.append({
			"x": cx + (_rnd() - 0.5) * 40.0, "y": cy + (_rnd() - 0.5) * 40.0,
			"flower": flower_idx if flower_idx >= 0 else -1, "t": _rnd(),
			"outbound": _rnd() < 0.5, "carrying": false, "phase": _rnd() * 6.0,
			"twitch": 0.0, "hintFlower": -1,
		})
	var tree = null
	for f in flowers:
		if f.get("tree", false):
			tree = f
			break
	if tree != null:
		big_flight = true
		big_flight_time = C.START5_T - 8.0
		big_flight_t = 8.0
		cam_zoom = C.CAM_ZOOM_OUT
		cam_zoom_target = C.CAM_ZOOM_OUT
		wax = minf(C.WAX_MAX, wax + 0.5)
	_spawn_meadow2()


func stress_fill(worker_count: int) -> void:
	if not planted:
		_try_build(0, 0)
	for cell in RING:
		var k := _hex_key(cell.x, cell.y)
		if not chambers.has(k):
			chambers[k] = {
				"q": cell.x, "r": cell.y, "grow": 1.0, "growDur": C.BUILD_DUR,
				"amber": 0.3, "hatchT": C.HATCH_DELAY, "hatched": true, "pulse": 0.0,
			}
		else:
			chambers[k].grow = 1.0
			chambers[k].hatched = true
	ring_closed = true
	for cell2 in RING:
		for n in _neighbors(cell2.x, cell2.y):
			if n.x == 0 and n.y == 0:
				continue
			var k2 := _hex_key(n.x, n.y)
			if chambers.has(k2):
				continue
			chambers[k2] = {
				"q": n.x, "r": n.y, "grow": 1.0, "growDur": C.BUILD_DUR,
				"amber": 0.2, "hatchT": C.HATCH_DELAY, "hatched": true, "pulse": 0.0,
			}
	var flower_idx := -1
	for i in range(flowers.size()):
		if not flowers[i].get("tree", false):
			flower_idx = i
			break
	if flower_idx >= 0:
		var has := false
		for r in routes:
			if r.flower == flower_idx:
				has = true
				break
		if not has:
			routes.append({"flower": flower_idx, "glow": 0.4})
	while workers.size() < worker_count:
		workers.append({
			"x": cx + (_rnd() - 0.5) * 40.0, "y": cy + (_rnd() - 0.5) * 40.0,
			"flower": flower_idx if flower_idx >= 0 else -1, "t": _rnd(),
			"outbound": _rnd() < 0.5, "carrying": false, "phase": _rnd() * 6.0,
			"twitch": 0.0, "hintFlower": -1,
		})
	if first_worker == null and workers.size() > 0:
		first_worker = time
	traffic = true
