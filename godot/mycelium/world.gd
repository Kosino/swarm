## Faithful GDScript port of src/mycelium/mycelium.ts (+ Build #6 encircle/snap).
## Pure sim — no Node required for headless.
class_name MyceliumWorld
extends RefCounted

const C = preload("res://mycelium/config.gd")
const G = preload("res://mycelium/gestures.gd")

var _rng: MyceliumRng
var _silent: bool = true

var patches: Array = [] ## Dictionary Patch
var specks: Array = []
var soil_cols: int = 0
var soil_rows: int = 0
var soil_tiles: Array = [] ## 0|1|2

var segs: Array = [] ## Dictionary Seg
var tips: Array = [] ## Dictionary Tip
var pulses: Array = []
var rings: Array = []
var workers: Array = []
var routes: Array = []

var seed: Variant = null ## {x,y} or null
var seed_glow: float = 0.0
var guide_a: float = 0.0
var guide_w: float = 0.0
var dragging: bool = false
var dsx: float = 0.0
var dsy: float = 0.0
var hx: float = float(C.W) / 2.0
var hy: float = float(C.H) / 2.0
var hovering: bool = false
var time: float = 0.0
var hold_t: float = 0.0
var densify: bool = false
var densify_x: float = 0.0
var densify_y: float = 0.0
var fusion_cd: float = 0.0
var first_anchor: Variant = null
var midstep: Variant = null
var first_fusion: Variant = null
var first_workers: Variant = null
var big_spawned: bool = false
var big_anchored: bool = false
var big_anchor_time: Variant = null
var cam_zoom: float = C.CAM_ZOOM_IN
var cam_zoom_target: float = C.CAM_ZOOM_IN
var network_pulse: float = 0.0
var network_bright: float = 0.0
var mid_wow_done: bool = false

var matters: Array = []
var germs: Array = []
var grains: Array = []
var spores: Array = []
var stroke: Array = []
var stroke_active: bool = false
var matters_spawned: bool = false
var decay_time: Variant = null
var fruit_time: Variant = null
var spore_time: Variant = null
var join_time: Variant = null
var hint_time: Variant = null
var quarantine_time: Variant = null
var skeleton_time: Variant = null
var giant_time: Variant = null
var seeds_time: Variant = null
var mvp_end_time: Variant = null
var heart_beat: float = 0.0
var heart_phase: float = 0.0
var foreign_net: float = 0.0
var foreign_seed: Variant = null
var decay_count: int = 0
var infected: Variant = null ## {x,y,r,grey,dead}
var skeleton: Variant = null ## {x,y,r,encircled,decay}
var giant_fruit: Variant = null ## {x,y,r,grow}
var seed_capsule: Variant = null ## {x,y,glow,pulse}
var network_gold: float = 0.0
var orbit_t: float = 0.0
var dim_all: float = 0.0
var age3_hold_t: float = 0.0
var invasion_active: bool = false

var idle_t: float = 0.0
var show_ghost: bool = false
var step_performs: Dictionary = {}
var emitted_wows: Dictionary = {}
var wow_queue: Array = []
var prev_anchors: int = 0
var prev_densify: bool = false

## Build #6
var pointer_meta: Dictionary = {"dpr": 1.0, "touch": false}
var miss_fx: Array = []
var stroke_catch: Variant = null
var snap_hover: Variant = null


func _init(opts: Dictionary = {}) -> void:
	_silent = opts.get("silent", true)
	if opts.has("rng") and opts.rng is MyceliumRng:
		_rng = opts.rng
	elif opts.has("seed"):
		_rng = MyceliumRng.new(int(opts.seed))
	else:
		_rng = MyceliumRng.new(int(Time.get_ticks_msec()) & 0xFFFFFFFF)
	_bootstrap_world()
	if opts.has("startAt"):
		var at: float = float(opts.startAt)
		if at >= C.START10_T - 5.0:
			bootstrap_start10()
		elif at >= C.START5_T - 5.0:
			bootstrap_start5()


func _rnd() -> float:
	return _rng.next()


func _hypot(dx: float, dy: float) -> float:
	return sqrt(dx * dx + dy * dy)


func _wrap(a: float) -> float:
	while a > PI:
		a -= 2.0 * PI
	while a < -PI:
		a += 2.0 * PI
	return a


func _dist_point_seg(px: float, py: float, x1: float, y1: float, x2: float, y2: float) -> Dictionary:
	var dx: float = x2 - x1
	var dy: float = y2 - y1
	var len2: float = dx * dx + dy * dy
	var t = 0.0
	if len2 > 0.0:
		t = ((px - x1) * dx + (py - y1) * dy) / len2
	t = clampf(t, 0.0, 1.0)
	var cx: float = x1 + t * dx
	var cy: float = y1 + t * dy
	return {"d": _hypot(px - cx, py - cy), "cx": cx, "cy": cy}


func _bootstrap_world() -> void:
	patches.clear()
	var n: float = 6 + int(floor(_rnd() * 5.0))
	var guard = 0
	while patches.size() < n and guard < 800:
		guard += 1
		var r: float = 16.0 + _rnd() * 14.0
		var x: float = 70.0 + _rnd() * (float(C.W) - 140.0)
		var y: float = 70.0 + _rnd() * (float(C.H) - 140.0)
		var ok = true
		for p in patches:
			if _hypot(p.x - x, p.y - y) <= 150.0:
				ok = false
				break
		if ok:
			patches.append({"x": x, "y": y, "r": r, "lit": 0.0, "on": false, "ph": _rnd() * 6.0, "big": false})
	specks.clear()
	for _i in range(120):
		specks.append({
			"x": _rnd() * float(C.W),
			"y": _rnd() * float(C.H),
			"r": _rnd() * 1.6 + 0.3,
			"a": _rnd() * 0.05 + 0.015,
		})
	soil_cols = int(ceil(float(C.W) / float(C.SOIL_TILE))) + 1
	soil_rows = int(ceil(float(C.H) / float(C.SOIL_TILE))) + 1
	soil_tiles.clear()
	for _i in range(soil_cols * soil_rows):
		soil_tiles.append(int(floor(_rnd() * 3.0)))


func _bump_perform(step_id: String) -> void:
	step_performs[step_id] = int(step_performs.get(step_id, 0)) + 1


func _can_ghost(step_id: String) -> bool:
	return int(step_performs.get(step_id, 0)) < C.MAX_GHOST_PERFORMS


func _emit_wow(id: String, label: String, t: Variant) -> void:
	if t == null or emitted_wows.has(id):
		return
	emitted_wows[id] = true
	wow_queue.append({"id": id, "label": label, "time": t})


func _push_seg(x1: float, y1: float, x2: float, y2: float, p: int, th: int, fuse_glow: Variant = null) -> int:
	var seg = {
		"x1": x1, "y1": y1, "x2": x2, "y2": y2,
		"p": p, "th": th, "v": 0 if _rnd() < 0.5 else 1,
	}
	if fuse_glow != null:
		seg["fuseGlow"] = float(fuse_glow)
	segs.append(seg)
	return segs.size() - 1


func _add_tip(x: float, y: float, a: float, seg: int) -> void:
	tips.append({"x": x, "y": y, "a": a, "seg": seg, "sx": x, "sy": y, "g": false})


func _ancestors(seg_idx: int) -> Dictionary:
	var s: Dictionary = {}
	var i = seg_idx
	var guard_a = 0
	while i >= 0 and guard_a < 4000:
		guard_a += 1
		s[i] = true
		i = int(segs[i].p)
	return s


func _spawn_matters() -> void:
	if matters_spawned or seed == null:
		return
	matters_spawned = true
	var corners: Array = [
		[C.BIG_EDGE + 40.0, C.BIG_EDGE + 50.0],
		[float(C.W) - C.BIG_EDGE - 40.0, C.BIG_EDGE + 50.0],
		[C.BIG_EDGE + 50.0, float(C.H) - C.BIG_EDGE - 40.0],
		[float(C.W) - C.BIG_EDGE - 50.0, float(C.H) - C.BIG_EDGE - 40.0],
	]
	var big: Variant = null
	for p in patches:
		if p.get("big", false):
			big = p
			break
	var scored: Array = []
	for c in corners:
		var d: float = _hypot(c[0] - seed.x, c[1] - seed.y)
		if big != null:
			d += _hypot(c[0] - big.x, c[1] - big.y) * 0.4
		scored.append({"c": c, "d": d})
	scored.sort_custom(func(a, b): return a.d > b.d)
	var m1 = scored[0].c
	var m2 = scored[1].c
	matters.append({
		"x": m1[0], "y": m1[1], "r": C.MATTER_R_MACHINE, "kind": "machine",
		"decay": 0.0, "encircled": false, "ph": _rnd() * 6.0,
	})
	matters.append({
		"x": m2[0], "y": m2[1], "r": C.MATTER_R_BEETLE, "kind": "beetle",
		"decay": 0.0, "encircled": false, "ph": _rnd() * 6.0,
	})


func _spawn_fruit_at(x: float, y: float) -> void:
	matters.append({
		"x": x, "y": y - 8.0, "r": 22.0, "kind": "fruit",
		"decay": 0.0, "encircled": false, "ph": _rnd() * 6.0,
	})


func _sfx_dum(big: bool = false, soft: bool = false) -> void:
	if _silent:
		return
	SwarmSfx.play_dum(big, soft)


func _sfx_soft(kind: String) -> void:
	if _silent:
		return
	SwarmSfx.play_soft(kind)


func _trigger_decay(m: Dictionary) -> void:
	if m.encircled or m.kind == "fruit":
		return
	m.encircled = true
	decay_count += 1
	if decay_time == null:
		decay_time = time
		_sfx_soft("bubble")
		_sfx_dum(true)
	if seed != null:
		for i in range(18):
			var a: float = _rnd() * PI * 2.0
			grains.append({
				"x": m.x + cos(a) * m.r * 0.4,
				"y": m.y + sin(a) * m.r * 0.4,
				"vx": (seed.x - m.x) * (0.15 + _rnd() * 0.25),
				"vy": (seed.y - m.y) * (0.15 + _rnd() * 0.25),
				"life": 1.2 + _rnd() * 0.8,
			})
	for s in segs:
		var mx: float = (s.x1 + s.x2) * 0.5
		var my: float = (s.y1 + s.y2) * 0.5
		if _hypot(mx - m.x, my - m.y) < m.r * 2.2:
			s.th = mini(3, int(s.th) + 1)
	rings.append({"x": m.x, "y": m.y, "t": 0.0, "big": true})
	network_bright = 1.0


func _trigger_fruit(m: Dictionary) -> void:
	if m.encircled or m.kind == "fruit":
		return
	_trigger_decay(m)
	var site: Dictionary = m
	for x in matters:
		if x.kind != "fruit" and x.encircled:
			site = x
			break
	var has_fruit = false
	for x in matters:
		if x.kind == "fruit":
			has_fruit = true
			break
	if not has_fruit:
		_spawn_fruit_at(site.x, site.y)
	var fruit_n = 0
	for x in matters:
		if x.kind == "fruit":
			fruit_n += 1
	if m.kind == "beetle" and fruit_n < 2:
		_spawn_fruit_at(m.x + (_rnd() - 0.5) * 30.0, m.y + (_rnd() - 0.5) * 30.0)
	if fruit_time == null:
		fruit_time = time
		_sfx_soft("puff")
		for s in segs:
			if _rnd() < 0.35:
				s.th = mini(3, int(s.th) + 1)


func _trigger_spore() -> void:
	if spore_time != null:
		return
	var fruits: Array = []
	for m in matters:
		if m.kind == "fruit":
			fruits.append(m)
	if fruits.size() < 1:
		return
	spore_time = time
	_sfx_soft("rain")
	for f in fruits:
		for i in range(22):
			var a: float = _rnd() * PI * 2.0
			spores.append({
				"x": f.x, "y": f.y,
				"vx": cos(a) * (20.0 + _rnd() * 60.0),
				"vy": sin(a) * (20.0 + _rnd() * 60.0),
				"life": 1.5 + _rnd(),
			})
		f.encircled = true
	var cx0: float = seed.x if seed != null else float(C.W) / 2.0
	var cy0: float = seed.y if seed != null else float(C.H) / 2.0
	for i in range(C.SPORE_GERMS):
		var gx = 0.0
		var gy = 0.0
		for t in range(40):
			var a: float = _rnd() * PI * 2.0
			var d: float = 180.0 + _rnd() * 160.0
			gx = cx0 + cos(a) * d
			gy = cy0 + sin(a) * d * 0.85
			if gx > 50.0 and gx < float(C.W) - 50.0 and gy > 50.0 and gy < float(C.H) - 50.0:
				break
		germs.append({"x": gx, "y": gy, "lit": 0.0, "linked": false})
	rings.append({"x": fruits[0].x, "y": fruits[0].y, "t": 0.0, "big": true})


func _trigger_join() -> void:
	if join_time != null or germs.size() == 0 or seed == null:
		return
	join_time = time
	_sfx_soft("beat")
	heart_beat = 1.0
	network_pulse = 1.0
	network_bright = 1.0
	for g in germs:
		g.linked = true
		g.lit = 1.0
		var x: float = seed.x
		var y: float = seed.y
		var prev: float = -1
		var steps: float = 8 + int(floor(_rnd() * 4.0))
		for i in range(1, steps + 1):
			var t: float = float(i) / float(steps)
			var nx: float = seed.x + (g.x - seed.x) * t + (_rnd() - 0.5) * 18.0
			var ny: float = seed.y + (g.y - seed.y) * t + (_rnd() - 0.5) * 18.0
			prev = _push_seg(x, y, nx, ny, prev, 2 if i > steps - 2 else 1)
			x = nx
			y = ny
		_add_tip(g.x, g.y, _rnd() * PI * 2.0, prev)
	var net = _whole_network_path(seed.x, seed.y)
	pulses.append({"path": net, "t": 0.0, "dur": 1.2 + float(net.size()) * 0.002})


func _trigger_hint() -> void:
	if hint_time != null:
		return
	hint_time = time
	_sfx_soft("hiss")
	foreign_net = 1.0
	var cx0: float = seed.x if seed != null else float(C.W) / 2.0
	var cy0: float = seed.y if seed != null else float(C.H) / 2.0
	foreign_seed = {
		"x": float(C.W) - 70.0 if cx0 < float(C.W) / 2.0 else 70.0,
		"y": float(C.H) - 60.0 if cy0 < float(C.H) / 2.0 else 60.0,
	}


func _begin_invasion() -> void:
	if invasion_active or foreign_seed == null:
		return
	invasion_active = true
	foreign_net = 1.0
	infected = {
		"x": foreign_seed.x,
		"y": foreign_seed.y,
		"r": C.INFECT_R,
		"grey": 0.35,
		"dead": false,
	}


func _trigger_quarantine() -> void:
	if quarantine_time != null or infected == null or infected.dead:
		return
	quarantine_time = time
	_sfx_soft("clean")
	infected.dead = true
	infected.grey = 1.0
	foreign_net = 0.15
	if seed != null:
		for i in range(22):
			var a: float = _rnd() * PI * 2.0
			grains.append({
				"x": infected.x + cos(a) * infected.r * 0.5,
				"y": infected.y + sin(a) * infected.r * 0.5,
				"vx": (seed.x - infected.x) * (0.12 + _rnd() * 0.2),
				"vy": (seed.y - infected.y) * (0.12 + _rnd() * 0.2),
				"life": 1.4 + _rnd(),
			})
	rings.append({"x": infected.x, "y": infected.y, "t": 0.0, "big": true})
	network_bright = 1.0
	_bump_perform("quarantine")
	## Giant skeleton appears as foreign net retreats.
	skeleton = {
		"x": infected.x + (float(C.W) * 0.5 - infected.x) * 0.15,
		"y": infected.y + (float(C.H) * 0.5 - infected.y) * 0.1,
		"r": C.SKELETON_R,
		"encircled": false,
		"decay": 0.0,
	}


func _trigger_skeleton() -> void:
	if skeleton_time != null or skeleton == null or skeleton.encircled:
		return
	skeleton_time = time
	_sfx_soft("rain")
	_sfx_dum(true)
	skeleton.encircled = true
	network_gold = 1.0
	network_bright = 1.0
	_bump_perform("skeleton")
	for g in germs:
		for i in range(10):
			var a: float = _rnd() * PI * 2.0
			grains.append({
				"x": skeleton.x + cos(a) * skeleton.r * 0.4,
				"y": skeleton.y + sin(a) * skeleton.r * 0.4,
				"vx": (g.x - skeleton.x) * (0.1 + _rnd() * 0.2),
				"vy": (g.y - skeleton.y) * (0.1 + _rnd() * 0.2),
				"life": 2.0 + _rnd(),
			})
	if germs.is_empty() and seed != null:
		for i in range(16):
			var a2: float = _rnd() * PI * 2.0
			grains.append({
				"x": skeleton.x, "y": skeleton.y,
				"vx": (seed.x - skeleton.x) * (0.1 + _rnd() * 0.2),
				"vy": (seed.y - skeleton.y) * (0.1 + _rnd() * 0.2),
				"life": 2.0 + _rnd(),
			})
	rings.append({"x": skeleton.x, "y": skeleton.y, "t": 0.0, "big": true})


func _main_fruit_pos() -> Dictionary:
	for m in matters:
		if m.kind == "fruit":
			return {"x": m.x, "y": m.y, "r": m.r}
	if seed != null:
		return {"x": seed.x, "y": seed.y - 20.0, "r": 28.0}
	return {"x": float(C.W) * 0.5, "y": float(C.H) * 0.5, "r": 28.0}


func _trigger_giant() -> void:
	if giant_time != null:
		return
	giant_time = time
	_sfx_soft("beat")
	_sfx_dum(true)
	var fp := _main_fruit_pos()
	giant_fruit = {"x": fp.x, "y": fp.y - 10.0, "r": C.GIANT_FRUIT_R, "grow": 0.0}
	network_bright = 1.0
	heart_beat = 1.0
	_bump_perform("giant")
	rings.append({"x": fp.x, "y": fp.y, "t": 0.0, "big": true})


func _trigger_seeds_hint() -> void:
	if seeds_time != null or giant_fruit == null:
		return
	seeds_time = time
	_sfx_soft("puff")
	dim_all = 1.0
	seed_capsule = {
		"x": giant_fruit.x,
		"y": giant_fruit.y - giant_fruit.r * 0.55,
		"glow": 1.0,
		"pulse": 0.0,
	}


func _trigger_mvp_end() -> void:
	if mvp_end_time != null:
		return
	mvp_end_time = time
	_sfx_soft("beat")
	orbit_t = 0.01
	cam_zoom_target = 0.22
	if seed_capsule != null:
		seed_capsule.pulse = 1.0


func _shape_of_matter(m: Dictionary) -> Dictionary:
	return {
		"x": m.x, "y": m.y,
		"rx": m.r * (1.05 if m.kind == "beetle" else 0.85),
		"ry": m.r * (0.7 if m.kind == "beetle" else 0.55),
	}


func _update_stroke_catch() -> void:
	stroke_catch = null
	if not stroke_active or stroke.size() < 4:
		return
	var poly = G.smooth_resample(stroke)
	var candidates: Array = []
	for m in matters:
		if not m.encircled:
			candidates.append(m)
	for g in germs:
		if not g.linked:
			candidates.append(g)
	var best: Variant = null
	var score = 0.0
	for c in candidates:
		var r: float = c.r if c.has("r") else 14.0
		var rec = G.encircle_recognized(poly, {"x": c.x, "y": c.y, "rx": r, "ry": r * 0.75}, {
			"minLen": C.ENC_MIN_LEN * 0.55,
			"minPts": 6,
			"closePx": C.ENC_CLOSE_R,
		})
		var s = 1.0 if rec.ok else (0.7 if G.point_in_poly(c.x, c.y, poly) else 0.0)
		if s > score:
			score = s
			best = c
	if score >= 0.55:
		stroke_catch = best


func _try_encircle() -> bool:
	if not big_anchored or stroke.size() < C.ENC_MIN_PTS:
		return false
	var poly = G.smooth_resample(stroke)
	if G.path_length(poly) < C.ENC_MIN_LEN:
		return false
	stroke = poly

	var intact: Array = []
	var fruits: Array = []
	for m in matters:
		if m.kind == "fruit":
			if not m.encircled:
				fruits.append(m)
		elif not m.encircled:
			intact.append(m)
	var last: Dictionary = poly[poly.size() - 1]

	if spore_time == null and fruits.size() >= 1 and decay_count >= 2:
		var covered: Array = []
		for f in fruits:
			var rec = G.encircle_recognized(poly, {"x": f.x, "y": f.y, "rx": f.r, "ry": f.r * 0.7}, {
				"minLen": C.ENC_MIN_LEN * 0.7,
				"minPts": C.ENC_MIN_PTS,
				"closePx": C.ENC_CLOSE_R,
			})
			if rec.ok:
				covered.append(f)
		if (
			covered.size() >= mini(2, fruits.size())
			or (fruits.size() >= 2 and covered.size() >= 1 and G.path_length(poly) > C.ENC_MIN_LEN * 1.4)
		):
			_trigger_spore()
			return true

	if fruit_time == null and decay_count >= 1:
		for m in intact:
			var rec = G.encircle_recognized(poly, _shape_of_matter(m), {
				"minLen": C.ENC_MIN_LEN,
				"minPts": C.ENC_MIN_PTS,
				"closePx": C.ENC_CLOSE_R,
			})
			if rec.ok:
				_trigger_fruit(m)
				return true

	if decay_time == null or intact.size() > 0:
		for m in intact:
			var rec2 = G.encircle_recognized(poly, _shape_of_matter(m), {
				"minLen": C.ENC_MIN_LEN,
				"minPts": C.ENC_MIN_PTS,
				"closePx": C.ENC_CLOSE_R,
			})
			if rec2.ok:
				if decay_time == null:
					_trigger_decay(m)
				else:
					_trigger_fruit(m)
				return true

	if spore_time != null and join_time == null:
		var unlinked: Array = []
		for g in germs:
			if not g.linked:
				unlinked.append(g)
		var snap = G.snap_radius(pointer_meta)
		if unlinked.size() > 0:
			var all_ok = true
			for g in unlinked:
				var rec3 = G.encircle_recognized(poly, {"x": g.x, "y": g.y, "rx": 16.0, "ry": 14.0}, {
					"minLen": C.ENC_MIN_LEN * 0.7,
					"minPts": 8,
					"closePx": C.ENC_CLOSE_R,
				})
				var near = false
				for p in poly:
					if _hypot(p.x - g.x, p.y - g.y) < 50.0:
						near = true
						break
				if not (rec3.ok or G.point_in_poly(g.x, g.y, poly) or near):
					all_ok = false
					break
			if all_ok:
				_trigger_join()
				return true
			var near_end = false
			for g in unlinked:
				if _hypot(last.x - g.x, last.y - g.y) < maxf(G.TRAIL_FINISH_PX, snap):
					near_end = true
					break
			if near_end and G.path_length(poly) > C.ENC_MIN_LEN * 0.8:
				_trigger_join()
				return true

	## Age 3 — quarantine infected zone / giant skeleton (same encircle gesture).
	if (
		hint_time != null and quarantine_time == null and infected != null and not infected.dead
		and time >= C.WOW_QUARANTINE - 8.0
	):
		var rec_q = G.encircle_recognized(poly, {
			"x": infected.x, "y": infected.y, "rx": infected.r, "ry": infected.r * 0.8,
		}, {"minLen": C.ENC_MIN_LEN * 0.75, "minPts": 8, "closePx": C.ENC_CLOSE_R})
		if rec_q.ok or G.point_in_poly(infected.x, infected.y, poly):
			_trigger_quarantine()
			return true
	if (
		quarantine_time != null and skeleton_time == null and skeleton != null and not skeleton.encircled
		and time >= C.WOW_SKELETON - 8.0
	):
		var rec_s = G.encircle_recognized(poly, {
			"x": skeleton.x, "y": skeleton.y, "rx": skeleton.r, "ry": skeleton.r * 0.75,
		}, {"minLen": C.ENC_MIN_LEN * 0.9, "minPts": C.ENC_MIN_PTS, "closePx": C.ENC_CLOSE_R})
		if rec_s.ok or G.point_in_poly(skeleton.x, skeleton.y, poly):
			_trigger_skeleton()
			return true
	return false


func _resolve_connect_snap(x: float, y: float) -> Dictionary:
	var snap = G.snap_radius(pointer_meta)
	var unlinked: Array = []
	for g in germs:
		if not g.linked:
			unlinked.append({"x": g.x, "y": g.y, "germ": g})
	var tip_pts: Array = []
	for t in tips:
		tip_pts.append({"x": t.x, "y": t.y})
	var patch_pts: Array = []
	for p in patches:
		if not p.on:
			patch_pts.append({"x": p.x, "y": p.y})

	## Germs always (join connect). Tip/patch snap only after big anchor —
	## early tip magnetism slips first-anchor timing vs Build #5 medians.
	var g_hit = G.nearest_target(x, y, unlinked, snap)
	if g_hit is Dictionary and not g_hit.is_empty():
		return {"x": g_hit.target.x, "y": g_hit.target.y, "kind": "germ", "germ": g_hit.target.germ}
	if big_anchored:
		var t_hit = G.nearest_target(x, y, tip_pts, snap)
		if t_hit is Dictionary and not t_hit.is_empty():
			return {"x": t_hit.target.x, "y": t_hit.target.y, "kind": "tip"}
		var p_hit = G.nearest_target(x, y, patch_pts, snap)
		if p_hit is Dictionary and not p_hit.is_empty():
			return {"x": p_hit.target.x, "y": p_hit.target.y, "kind": "patch"}
	return {}


func _spawn_big_patch() -> void:
	if big_spawned or seed == null:
		return
	big_spawned = true
	var corners: Array = [
		[C.BIG_EDGE + C.BIG_R, C.BIG_EDGE + C.BIG_R],
		[float(C.W) - C.BIG_EDGE - C.BIG_R, C.BIG_EDGE + C.BIG_R],
		[C.BIG_EDGE + C.BIG_R, float(C.H) - C.BIG_EDGE - C.BIG_R],
		[float(C.W) - C.BIG_EDGE - C.BIG_R, float(C.H) - C.BIG_EDGE - C.BIG_R],
	]
	var best = corners[0]
	var bd: float = -1.0
	for c in corners:
		var d: float = _hypot(c[0] - seed.x, c[1] - seed.y)
		if d > bd:
			bd = d
			best = c
	patches.append({
		"x": best[0], "y": best[1], "r": C.BIG_R, "lit": 0.0, "on": false,
		"ph": _rnd() * 6.0, "big": true,
	})


func plant_seed(x: float, y: float) -> void:
	if seed != null:
		return
	seed = {"x": x, "y": y}
	for p in patches:
		if _hypot(p.x - x, p.y - y) >= C.SEED_CLEAR:
			continue
		for k in range(300):
			var nx: float = 70.0 + _rnd() * (float(C.W) - 140.0)
			var ny: float = 70.0 + _rnd() * (float(C.H) - 140.0)
			if _hypot(nx - x, ny - y) < C.SEED_CLEAR:
				continue
			var far = true
			for q in patches:
				if is_same(q, p):
					continue
				if _hypot(q.x - nx, q.y - ny) <= 150.0:
					far = false
					break
			if far:
				p.x = nx
				p.y = ny
				break
	rings.append({"x": x, "y": y, "t": 0.0, "big": false})
	var k = 3
	var base: float = _rnd() * PI * 2.0
	for i in range(k):
		_add_tip(x, y, base + (float(i) * PI * 2.0) / float(k) + (_rnd() - 0.5) * 0.6, -1)


func note_pointer() -> void:
	idle_t = 0.0
	show_ghost = false


func guidance() -> Dictionary:
	var tip: Dictionary
	if tips.size() > 0:
		tip = tips[0]
	elif seed != null:
		tip = {"x": seed.x, "y": seed.y}
	else:
		tip = {"x": float(C.W) / 2.0, "y": float(C.H) / 2.0}
	var unlit: Array = []
	for p in patches:
		if not p.on and not p.get("big", false):
			unlit.append(p)
	var nearest: Variant = null
	if unlit.size() > 0:
		nearest = unlit[0]
		for p in unlit:
			if _hypot(p.x - tip.x, p.y - tip.y) < _hypot(nearest.x - tip.x, nearest.y - tip.y):
				nearest = p
	var big: Variant = null
	for p in patches:
		if p.get("big", false) and not p.on:
			big = p
			break
	var machine: Variant = null
	var beetle: Variant = null
	var fruits: Array = []
	for m in matters:
		if m.kind == "machine" and not m.encircled:
			machine = m
		elif m.kind == "beetle" and not m.encircled:
			beetle = m
		elif m.kind == "fruit":
			fruits.append(m)
	var germ: Variant = null
	for g in germs:
		if not g.linked:
			germ = g
			break

	if seed == null:
		return {
			"stepId": "plant", "label": "Klepni — zasaď zárodek",
			"target": {"x": hx if hovering else float(C.W) / 2.0, "y": hy if hovering else float(C.H) / 2.0, "r": 18.0},
			"target2": null, "ghost": "tap", "from": null,
			"to": {"x": float(C.W) / 2.0, "y": float(C.H) / 2.0, "r": 18.0},
		}
	if first_anchor == null:
		var t = nearest if nearest != null else {"x": tip.x + 80.0, "y": tip.y, "r": 20.0}
		return {
			"stepId": "anchor1", "label": "Táhni hyfy ke skvrně",
			"target": {"x": t.x, "y": t.y, "r": t.get("r", 20.0)},
			"target2": null, "ghost": "drag",
			"from": {"x": tip.x, "y": tip.y, "r": 8.0},
			"to": {"x": t.x, "y": t.y, "r": t.get("r", 20.0)},
		}
	var on_n = 0
	for p in patches:
		if p.on and not p.get("big", false):
			on_n += 1
	if midstep == null or on_n < 3:
		if nearest != null and on_n < 3:
			return {
				"stepId": "anchors", "label": "Kotvi další skvrny",
				"target": {"x": nearest.x, "y": nearest.y, "r": nearest.r},
				"target2": null, "ghost": "drag",
				"from": {"x": tip.x, "y": tip.y, "r": 8.0},
				"to": {"x": nearest.x, "y": nearest.y, "r": nearest.r},
			}
	if first_fusion == null:
		return {
			"stepId": "fuse", "label": "Spoj hyfy do smyčky",
			"target": {"x": tips[0].x, "y": tips[0].y, "r": 16.0} if tips.size() > 0 else null,
			"target2": {"x": tips[1].x, "y": tips[1].y, "r": 16.0} if tips.size() > 1 else null,
			"ghost": "drag",
			"from": {"x": tips[0].x, "y": tips[0].y, "r": 8.0} if tips.size() > 0 else null,
			"to": ({"x": tips[1].x, "y": tips[1].y, "r": 8.0} if tips.size() > 1
				else ({"x": seed.x + 60.0, "y": seed.y, "r": 8.0} if seed != null else null)),
		}
	if first_workers == null:
		var hx0: float = tips[0].x if tips.size() > 0 else seed.x
		var hy0: float = tips[0].y if tips.size() > 0 else seed.y
		return {
			"stepId": "hold", "label": "Podrž — zahušť síť",
			"target": {"x": hx0, "y": hy0, "r": 28.0},
			"target2": null, "ghost": "hold", "from": null,
			"to": {"x": hx0, "y": hy0, "r": 28.0},
		}
	if not big_anchored:
		var t2 = big if big != null else nearest
		if t2 != null:
			return {
				"stepId": "big", "label": "Dosáhni velké skvrny",
				"target": {"x": t2.x, "y": t2.y, "r": t2.r},
				"target2": null, "ghost": "drag",
				"from": {"x": tip.x, "y": tip.y, "r": 8.0},
				"to": {"x": t2.x, "y": t2.y, "r": t2.r},
			}
	if decay_time == null and machine != null:
		return {
			"stepId": "decay", "label": "Zakroužkuj stroj",
			"target": {"x": machine.x, "y": machine.y, "r": machine.r},
			"target2": null, "ghost": "encircle", "from": null,
			"to": {"x": machine.x, "y": machine.y, "r": machine.r},
		}
	if fruit_time == null and beetle != null:
		return {
			"stepId": "fruit", "label": "Zakroužkuj brouka",
			"target": {"x": beetle.x, "y": beetle.y, "r": beetle.r},
			"target2": null, "ghost": "encircle", "from": null,
			"to": {"x": beetle.x, "y": beetle.y, "r": beetle.r},
		}
	if spore_time == null and fruits.size() > 0:
		var mx = 0.0
		var my = 0.0
		for f in fruits:
			mx += f.x
			my += f.y
		mx /= float(fruits.size())
		my /= float(fruits.size())
		return {
			"stepId": "spore", "label": "Zakroužkuj plodnice",
			"target": {"x": fruits[0].x, "y": fruits[0].y, "r": fruits[0].r},
			"target2": {"x": fruits[1].x, "y": fruits[1].y, "r": fruits[1].r} if fruits.size() > 1 else null,
			"ghost": "encircle", "from": null,
			"to": {"x": mx, "y": my, "r": 50.0},
		}
	if join_time == null and germ != null:
		return {
			"stepId": "join", "label": "Doveď síť k zárodkům",
			"target": {"x": germ.x, "y": germ.y, "r": 16.0},
			"target2": null, "ghost": "drag",
			"from": {"x": tip.x, "y": tip.y, "r": 8.0},
			"to": {"x": germ.x, "y": germ.y, "r": 16.0},
		}
	if hint_time != null and quarantine_time == null and infected != null and not infected.dead:
		return {
			"stepId": "quarantine", "label": "Zakroužkuj nakaženou část",
			"target": {"x": infected.x, "y": infected.y, "r": infected.r},
			"target2": null, "ghost": "encircle", "from": null,
			"to": {"x": infected.x, "y": infected.y, "r": infected.r},
		}
	if quarantine_time != null and skeleton_time == null and skeleton != null and not skeleton.encircled:
		return {
			"stepId": "skeleton", "label": "Zakroužkuj kostru stroje",
			"target": {"x": skeleton.x, "y": skeleton.y, "r": skeleton.r},
			"target2": null, "ghost": "encircle", "from": null,
			"to": {"x": skeleton.x, "y": skeleton.y, "r": skeleton.r},
		}
	if skeleton_time != null and giant_time == null:
		var fp := _main_fruit_pos()
		return {
			"stepId": "giant", "label": "Podrž hlavní plodnici",
			"target": {"x": fp.x, "y": fp.y, "r": fp.r},
			"target2": null, "ghost": "hold", "from": null,
			"to": {"x": fp.x, "y": fp.y, "r": fp.r},
		}
	if mvp_end_time != null:
		return {
			"stepId": "orbit", "label": "SWARM",
			"target": null, "target2": null, "ghost": null, "from": null, "to": null,
		}
	if seeds_time != null:
		return {
			"stepId": "seeds", "label": "Sleduj tobolku",
			"target": {"x": seed_capsule.x, "y": seed_capsule.y, "r": 18.0} if seed_capsule != null else null,
			"target2": null, "ghost": null, "from": null, "to": null,
		}
	return {
		"stepId": "watch",
		"label": "Sleduj okraj tmy" if hint_time != null else "Sleduj síť",
		"target": {"x": foreign_seed.x, "y": foreign_seed.y, "r": 24.0} if foreign_seed != null else null,
		"target2": null, "ghost": null, "from": null, "to": null,
	}


func poll_wows() -> Array:
	_emit_wow("anchor", "První kotva", first_anchor)
	_emit_wow("midstep", "Třetí kotva", midstep)
	_emit_wow("fusion", "Fúze", first_fusion)
	_emit_wow("workers", "Cvrkot", first_workers)
	_emit_wow("big", "Velká kotva", big_anchor_time)
	_emit_wow("decay", "Obrůstání", decay_time)
	_emit_wow("fruit", "Plodnice", fruit_time)
	_emit_wow("spore", "Výtrusný déšť", spore_time)
	_emit_wow("join", "Spojení sítí", join_time)
	_emit_wow("hint", "Cizí síť", hint_time)
	_emit_wow("quarantine", "Karanténa", quarantine_time)
	_emit_wow("skeleton", "Kostra stroje", skeleton_time)
	_emit_wow("giant", "Obří plodnice", giant_time)
	_emit_wow("seeds", "Tobolka", seeds_time)
	_emit_wow("mvp", "Konec MVP", mvp_end_time)
	if wow_queue.is_empty():
		return []
	var out = wow_queue.duplicate()
	wow_queue.clear()
	return out


func pointer_down(x: float, y: float, meta: Dictionary = {}) -> void:
	if not meta.is_empty():
		pointer_meta = meta
	if seed == null:
		plant_seed(x, y)
		_bump_perform("plant")
	dragging = true
	hold_t = 0.0
	densify = false
	dsx = x
	dsy = y
	hx = x
	hy = y
	guide_w = 0.0
	stroke_catch = null
	snap_hover = null
	var snap = G.snap_radius(pointer_meta)
	for t in tips:
		t.g = _hypot(t.x - x, t.y - y) < maxf(C.GUIDE_R, snap * 3.0)
	if big_anchored:
		stroke = [{"x": x, "y": y}]
		stroke_active = true


func pointer_move(x: float, y: float, meta: Dictionary = {}) -> void:
	if not meta.is_empty():
		pointer_meta = meta
	var px = x
	var py = y
	var snap = _resolve_connect_snap(x, y)
	snap_hover = {"x": snap.x, "y": snap.y, "kind": snap.kind} if not snap.is_empty() else null
	if dragging and snap != null and not snap.is_empty() and _hypot(x - snap.x, y - snap.y) < G.snap_radius(pointer_meta):
		var k = 0.55
		px = x + (snap.x - x) * k
		py = y + (snap.y - y) * k
	hx = px
	hy = py
	hovering = true
	if not dragging or seed == null:
		return
	var dx: float = px - dsx
	var dy: float = py - dsy
	var length = _hypot(dx, dy)
	if length > 12.0:
		guide_a = atan2(dy, dx)
		guide_w = 1.0
		hold_t = 0.0
		densify = false
	if length > 80.0:
		dsx += dx * 0.4
		dsy += dy * 0.4
	if stroke_active:
		var last: Variant = stroke[stroke.size() - 1] if stroke.size() > 0 else null
		if last == null or _hypot(px - last.x, py - last.y) > 6.0:
			stroke.append({"x": px, "y": py})
			_update_stroke_catch()
			if (
				stroke.size() >= C.ENC_MIN_PTS
				and G.path_length(stroke) >= C.ENC_MIN_LEN
				and _hypot(px - stroke[0].x, py - stroke[0].y) < C.ENC_CLOSE_R
			):
				var ok = _try_encircle()
				if not ok:
					miss_fx.append(G.spawn_miss(px, py))
				stroke = []
				stroke_active = false
				stroke_catch = null


func pointer_up(meta: Dictionary = {}) -> void:
	if not meta.is_empty():
		pointer_meta = meta
	var did = false
	if stroke_active and stroke.size() >= C.ENC_MIN_PTS:
		var first: Dictionary = stroke[0]
		var last: Dictionary = stroke[stroke.size() - 1]
		if _hypot(last.x - first.x, last.y - first.y) < C.ENC_CLOSE_R:
			stroke.append({"x": first.x, "y": first.y})
		did = _try_encircle()
		if not did and G.path_length(stroke) >= C.ENC_MIN_LEN * 0.6:
			miss_fx.append(G.spawn_miss(hx, hy))
	if not did and big_anchored and spore_time != null and join_time == null and seed != null:
		var snap = _resolve_connect_snap(hx, hy)
		var finish: float = maxf(G.TRAIL_FINISH_PX, G.snap_radius(pointer_meta))
		var unlinked: Array = []
		for g in germs:
			if not g.linked:
				unlinked.append(g)
		var hit_germ = not snap.is_empty() and snap.kind == "germ" and snap.has("germ")
		var near_germ = false
		for g in unlinked:
			if _hypot(hx - g.x, hy - g.y) < finish:
				near_germ = true
				break
		if hit_germ or near_germ:
			_trigger_join()
			did = true
		elif dragging and _hypot(hx - dsx, hy - dsy) > 40.0 and unlinked.size() > 0:
			miss_fx.append(G.spawn_miss(hx, hy))
	stroke = []
	stroke_active = false
	stroke_catch = null
	snap_hover = null
	dragging = false
	hold_t = 0.0
	densify = false


func _whole_network_path(from_x: float, from_y: float) -> Array:
	var indexed: Array = []
	for i in range(segs.size()):
		var s: Dictionary = segs[i]
		indexed.append({
			"i": i,
			"d": _hypot((s.x1 + s.x2) * 0.5 - from_x, (s.y1 + s.y2) * 0.5 - from_y),
		})
	indexed.sort_custom(func(a, b): return a.d < b.d)
	var out: Array = []
	for x in indexed:
		out.append(x.i)
	return out


func _anchor(tip: Dictionary, p: Dictionary) -> void:
	var idx = _push_seg(tip.sx, tip.sy, p.x, p.y, tip.seg, 0)
	p.on = true
	var path: Array = []
	var i = idx
	while i >= 0:
		path.append(i)
		i = int(segs[i].p)
	var rev: Array = path.duplicate()
	rev.reverse()
	routes.append(rev)
	var anchors_on = 0
	for q in patches:
		if q.on:
			anchors_on += 1
	if first_anchor == null:
		first_anchor = time
		_sfx_dum(false)

	var is_mid_wow: int = not mid_wow_done and anchors_on == 3 and not p.get("big", false)
	if is_mid_wow:
		mid_wow_done = true
		midstep = time
		_sfx_dum(false, true)
		var net = _whole_network_path(p.x, p.y)
		pulses.append({"path": net if net.size() > 0 else path, "t": 0.0, "dur": 0.85 + float(net.size()) * 0.0035})
		network_pulse = 1.0
		network_bright = 1.0
		rings.append({"x": p.x, "y": p.y, "t": 0.0, "big": true})
		var kk: float = 2 + (1 if _rnd() < 0.55 else 0)
		var base: float = _rnd() * PI * 2.0
		for j in range(kk):
			_add_tip(p.x, p.y, base + (float(j) * PI * 2.0) / float(kk) + (_rnd() - 0.5) * 0.5, idx)
		return

	pulses.append({"path": path, "t": 0.0, "dur": 0.5 + float(path.size()) * 0.012})
	rings.append({"x": p.x, "y": p.y, "t": 0.0, "big": true})
	if p.get("big", false):
		big_anchored = true
		big_anchor_time = time
		_sfx_dum(true)
		network_pulse = 1.0
		cam_zoom_target = C.CAM_ZOOM_OUT
		for s in segs:
			s.th = mini(3, int(s.th) + 1)
	var k2: float = 1 + (1 if _rnd() < 0.6 else 0)
	var base2: float = _rnd() * PI * 2.0
	for j in range(k2):
		_add_tip(p.x, p.y, base2 + float(j) * PI + (_rnd() - 0.5) * 0.8, idx)


func _try_fusion(t: Dictionary) -> bool:
	if fusion_cd > 0.0 or time < C.FUSION_MIN_T:
		return false
	if int(t.seg) < 0:
		return false
	var own: Dictionary = _ancestors(int(t.seg))
	if own.size() < 3:
		return false
	for o in tips:
		if is_same(o, t):
			continue
		if int(o.seg) < 0:
			continue
		if _hypot(o.x - t.x, o.y - t.y) > C.FUSION_R:
			continue
		var o_own: Dictionary = _ancestors(int(o.seg))
		if o_own.size() < 3:
			continue
		if own.has(int(o.seg)) or o_own.has(int(t.seg)):
			continue
		var mid_x: float = (t.x + o.x) * 0.5
		var mid_y: float = (t.y + o.y) * 0.5
		var a: int = _push_seg(t.sx, t.sy, mid_x, mid_y, int(t.seg), 1, 1.0)
		var b: int = _push_seg(o.sx, o.sy, mid_x, mid_y, int(o.seg), 1, 1.0)
		segs[a].th = mini(3, int(segs[a].th) + 1)
		segs[b].th = mini(3, int(segs[b].th) + 1)
		if int(t.seg) >= 0:
			segs[int(t.seg)].th = mini(3, int(segs[int(t.seg)].th) + 1)
		if int(o.seg) >= 0:
			segs[int(o.seg)].th = mini(3, int(segs[int(o.seg)].th) + 1)
		pulses.append({"path": [a, b], "t": 0.0, "dur": 0.45})
		rings.append({"x": mid_x, "y": mid_y, "t": 0.0, "big": false})
		fusion_cd = C.FUSION_COOLDOWN
		if first_fusion == null:
			first_fusion = time
			_sfx_dum(false)
		t.seg = a
		t.sx = mid_x
		t.sy = mid_y
		t.x = mid_x
		t.y = mid_y
		o.seg = b
		o.sx = mid_x
		o.sy = mid_y
		o.x = mid_x
		o.y = mid_y
		var scatter: float = _rnd() * PI * 2.0
		t.a = scatter
		o.a = scatter + PI + (_rnd() - 0.5) * 0.4
		return true
	for si in range(segs.size()):
		if own.has(si):
			continue
		var s: Dictionary = segs[si]
		var hit = _dist_point_seg(t.x, t.y, s.x1, s.y1, s.x2, s.y2)
		if hit.d > C.FUSION_R:
			continue
		var idx: int = _push_seg(t.sx, t.sy, hit.cx, hit.cy, int(t.seg), 1, 1.0)
		s.th = mini(3, int(s.th) + 1)
		segs[idx].th = mini(3, int(segs[idx].th) + 1)
		if int(t.seg) >= 0:
			segs[int(t.seg)].th = mini(3, int(segs[int(t.seg)].th) + 1)
		pulses.append({"path": [idx, si], "t": 0.0, "dur": 0.45})
		rings.append({"x": hit.cx, "y": hit.cy, "t": 0.0, "big": false})
		fusion_cd = C.FUSION_COOLDOWN
		if first_fusion == null:
			first_fusion = time
			_sfx_dum(false)
		t.seg = idx
		t.sx = hit.cx
		t.sy = hit.cy
		t.x = hit.cx
		t.y = hit.cy
		t.a += PI * 0.6 + (_rnd() - 0.5) * 0.8
		return true
	return false


func _fertility() -> bool:
	return first_fusion != null and segs.size() >= C.WORKER_MIN_SEGS and time - float(first_fusion) >= C.WORKER_DELAY


func _target_workers() -> int:
	var density = 0
	for s in segs:
		density += 1 + int(s.th)
	return mini(C.MAX_WORKERS, int(floor(float(density) / 18.0)))


func _spawn_worker() -> void:
	if seed == null or routes.size() == 0:
		return
	var route = routes[int(floor(_rnd() * float(routes.size())))]
	if route.size() < 1:
		return
	workers.append({
		"route": route,
		"pos": 0.0,
		"dir": 1,
		"speed": C.WORKER_SPEED * (0.85 + _rnd() * 0.3),
	})
	if first_workers == null:
		first_workers = time


func worker_pos(w: Dictionary) -> Dictionary:
	var n: int = w.route.size()
	if n == 0 and seed != null:
		return {"x": seed.x, "y": seed.y}
	var f: float = clampf(float(w.pos), 0.0, float(n) - 1e-6)
	var i: float = mini(n - 1, int(floor(f)))
	var u: float = f - floor(f)
	var s: Dictionary = segs[w.route[i]]
	if s == null:
		return {"x": seed.x, "y": seed.y} if seed != null else {"x": 0.0, "y": 0.0}
	return {
		"x": s.x1 + (s.x2 - s.x1) * u,
		"y": s.y1 + (s.y2 - s.y1) * u,
	}


func update(dt: float) -> void:
	time += dt
	idle_t += dt
	G.tick_miss(miss_fx, dt)
	if idle_t >= C.IDLE_GHOST_S:
		show_ghost = true
	if fusion_cd > 0.0:
		fusion_cd = maxf(0.0, fusion_cd - dt)
	if not dragging:
		guide_w = maxf(0.0, guide_w - dt * 0.08)
		hold_t = 0.0
		densify = false
	elif seed != null:
		hold_t += dt
		if hold_t >= C.HOLD_S:
			densify = true
			densify_x = hx
			densify_y = hy
			if not prev_densify:
				_bump_perform("hold")
	prev_densify = densify
	var anchors_now = 0
	for p in patches:
		if p.on:
			anchors_now += 1
	if anchors_now > prev_anchors:
		if prev_anchors == 0:
			_bump_perform("anchor1")
		else:
			_bump_perform("anchors")
		if big_anchored:
			_bump_perform("big")
	prev_anchors = anchors_now
	if first_fusion != null and int(step_performs.get("fuse", 0)) == 0:
		_bump_perform("fuse")
	if first_workers != null and int(step_performs.get("hold", 0)) == 0:
		_bump_perform("hold")
	if decay_time != null and int(step_performs.get("decay", 0)) == 0:
		_bump_perform("decay")
	if fruit_time != null and int(step_performs.get("fruit", 0)) == 0:
		_bump_perform("fruit")
	if spore_time != null and int(step_performs.get("spore", 0)) == 0:
		_bump_perform("spore")
	if join_time != null and int(step_performs.get("join", 0)) == 0:
		_bump_perform("join")
	if time >= C.BIG_APPEAR_T:
		_spawn_big_patch()
	if big_anchored:
		_spawn_matters()
	## Gentle zoom-out with colony growth so minute 15 shows the whole work.
	if mvp_end_time == null:
		var anchors_on := 0
		for p in patches:
			if p.on:
				anchors_on += 1
		var growth: float = clampf(
			float(segs.size()) / 2200.0 * 0.45
			+ float(anchors_on) / 8.0 * 0.25
			+ time / 900.0 * 0.35,
			0.0, 1.0
		)
		var z_goal: float = lerpf(C.CAM_ZOOM_IN, C.CAM_ZOOM_OUT, growth)
		if time > 600.0:
			z_goal = lerpf(z_goal, C.CAM_ZOOM_OUT * 0.9, clampf((time - 600.0) / 280.0, 0.0, 1.0))
		if z_goal < cam_zoom_target:
			cam_zoom_target = z_goal
	if cam_zoom != cam_zoom_target:
		var k: float = 1.0 - exp(-dt / (C.CAM_ZOOM_DUR * 0.45))
		cam_zoom += (cam_zoom_target - cam_zoom) * k
		if absf(cam_zoom - cam_zoom_target) < 0.001:
			cam_zoom = cam_zoom_target
	network_pulse = maxf(0.0, network_pulse - dt * 0.55)
	network_bright = maxf(0.0, network_bright - dt * 0.35)

	for m in matters:
		if m.encircled and m.kind != "fruit" and m.decay < 1.0:
			m.decay = minf(1.0, m.decay + dt * 0.35)
	var gi: float = grains.size() - 1
	while gi >= 0:
		var g: Dictionary = grains[gi]
		g.life -= dt
		g.x += g.vx * dt
		g.y += g.vy * dt
		if seed != null:
			g.vx += (seed.x - g.x) * dt * 1.2
			g.vy += (seed.y - g.y) * dt * 1.2
		if g.life <= 0.0:
			grains.remove_at(gi)
		gi -= 1
	var si: float = spores.size() - 1
	while si >= 0:
		var s: Dictionary = spores[si]
		s.life -= dt
		s.x += s.vx * dt
		s.y += s.vy * dt
		s.vx *= 0.98
		s.vy *= 0.98
		if s.life <= 0.0:
			spores.remove_at(si)
		si -= 1
	for g2 in germs:
		if g2.lit < 1.0:
			g2.lit = minf(1.0, g2.lit + dt * 0.4)
	if join_time != null:
		heart_phase += dt
		heart_beat = 0.55 + 0.45 * sin((heart_phase / C.JOIN_PULSE_PERIOD) * PI * 2.0)
		network_bright = maxf(network_bright, heart_beat * 0.35)
	if join_time != null and hint_time == null and time >= 595.0:
		_trigger_hint()
	if hint_time != null and not invasion_active and time >= 620.0:
		_begin_invasion()
	if infected != null and not infected.dead:
		infected.grey = minf(1.0, infected.grey + dt * 0.08)
	if skeleton != null and skeleton.encircled and skeleton.decay < 1.0:
		skeleton.decay = minf(1.0, skeleton.decay + dt / 10.0)
	if network_gold > 0.0:
		network_gold = maxf(0.35, network_gold - dt * 0.02)
	## Age 3 hold on main fruit → giant fruiting body.
	if skeleton_time != null and giant_time == null and dragging and time >= C.WOW_GIANT - 8.0:
		var fp := _main_fruit_pos()
		if _hypot(hx - fp.x, hy - fp.y) < fp.r * 1.6:
			age3_hold_t += dt
			if age3_hold_t >= C.HOLD_AGE3_S:
				_trigger_giant()
		else:
			age3_hold_t = 0.0
	else:
		age3_hold_t = 0.0
	if giant_fruit != null and giant_fruit.grow < 1.0:
		giant_fruit.grow = minf(1.0, giant_fruit.grow + dt * 0.35)
	if giant_time != null and seeds_time == null and time >= C.WOW_SEEDS - 2.0:
		_trigger_seeds_hint()
	if seeds_time != null and mvp_end_time == null and time >= C.WOW_END - 2.0:
		_trigger_mvp_end()
	if orbit_t > 0.0:
		orbit_t += dt
	if dim_all > 0.0 and mvp_end_time == null:
		dim_all = minf(1.0, dim_all + dt * 0.15)
	if foreign_net > 0.0 and quarantine_time == null and not invasion_active:
		foreign_net = maxf(0.0, foreign_net - dt / C.HINT_DUR)
	elif foreign_net > 0.0 and quarantine_time != null:
		foreign_net = maxf(0.0, foreign_net - dt * 0.2)

	var next: Array = []
	for t in tips:
		if _try_fusion(t):
			next.append(t)
			continue
		var best: Variant = null
		var bd: float = C.SENSE
		for p in patches:
			if p.on:
				continue
			var d: float = _hypot(p.x - t.x, p.y - t.y)
			var sense: float = C.SENSE * 1.35 if p.get("big", false) else C.SENSE
			if d < bd and d < sense:
				bd = d
				best = p
		if best != null and bd < best.r * 0.8:
			_anchor(t, best)
			continue
		if best != null:
			t.a += _wrap(atan2(best.y - t.y, best.x - t.x) - t.a) * 1.4 * (1.0 - bd / C.SENSE) * dt
		if guide_w > 0.0 and t.g:
			t.a += _wrap(guide_a - t.a) * 2.6 * guide_w * dt
		var in_hold: float = densify and _hypot(t.x - densify_x, t.y - densify_y) < C.HOLD_R
		if in_hold:
			t.a += _wrap(atan2(densify_y - t.y, densify_x - t.x) - t.a) * C.HOLD_STEER * dt
		for mat in matters:
			if mat.kind == "fruit" or mat.encircled:
				continue
			var d2: float = _hypot(mat.x - t.x, mat.y - t.y)
			var lim: float = mat.r * C.MATTER_SLIDE_R
			if d2 < lim and d2 > 1.0:
				var out_a: float = atan2(t.y - mat.y, t.x - mat.x)
				t.a += _wrap(out_a + PI * 0.5 - t.a) * 2.2 * dt
				var push: float = (lim - d2) * 0.5
				t.x += cos(out_a) * push
				t.y += sin(out_a) * push
		var mgn = 30.0
		if t.x < mgn or t.x > float(C.W) - mgn or t.y < mgn or t.y > float(C.H) - mgn:
			t.a += _wrap(atan2(float(C.H) / 2.0 - t.y, float(C.W) / 2.0 - t.x) - t.a) * 2.5 * dt
		t.a += (_rnd() - 0.5) * 1.2 * dt
		var spd: float = C.SPEED * (C.HOLD_SPEED_MUL if in_hold else 1.0)
		t.x += cos(t.a) * spd * dt
		t.y += sin(t.a) * spd * dt
		var step_need: float = C.STEP * 0.85 if in_hold else C.STEP
		if _hypot(t.x - t.sx, t.y - t.sy) >= step_need:
			t.seg = _push_seg(t.sx, t.sy, t.x, t.y, int(t.seg), 0)
			t.sx = t.x
			t.sy = t.y
			t.a += (_rnd() - 0.5) * 0.7
			var branch_p: float = C.BRANCH_P * (C.HOLD_BRANCH_MUL if in_hold else 1.0)
			if tips.size() + next.size() < C.MAXTIPS and _rnd() < branch_p:
				var sdir: float = 1.0 if _rnd() < 0.5 else -1.0
				next.append({
					"x": t.x, "y": t.y,
					"a": t.a + sdir * (0.5 + _rnd() * 0.4),
					"seg": t.seg, "sx": t.x, "sy": t.y, "g": t.g,
				})
				t.a -= sdir * 0.25
		next.append(t)
	tips = next

	for p in patches:
		if p.on and p.lit < 1.0:
			p.lit = minf(1.0, p.lit + dt * 1.2)
	var pi: float = pulses.size() - 1
	while pi >= 0:
		var pu: Dictionary = pulses[pi]
		pu.t += dt / pu.dur
		if pu.t >= 1.0:
			for sidx in pu.path:
				if int(sidx) >= 0 and int(sidx) < segs.size():
					segs[int(sidx)].th = int(segs[int(sidx)].th) + 1
			seed_glow = 1.0
			if seed != null:
				rings.append({"x": seed.x, "y": seed.y, "t": 0.0, "big": false})
			pulses.remove_at(pi)
		pi -= 1
	seed_glow = maxf(0.0, seed_glow - dt * 1.5)
	var ri: float = rings.size() - 1
	while ri >= 0:
		rings[ri].t += dt
		if rings[ri].t > (1.2 if rings[ri].big else 0.6):
			rings.remove_at(ri)
		ri -= 1
	for s3 in segs:
		if s3.has("fuseGlow") and s3.fuseGlow > 0.0:
			s3.fuseGlow = maxf(0.0, s3.fuseGlow - dt * 1.4)

	if _fertility() and seed != null:
		var want = _target_workers()
		if workers.size() < want and _rnd() < C.WORKER_SPAWN_RATE * dt * 8.0:
			_spawn_worker()
	for w in workers:
		var n: int = w.route.size()
		if n < 1:
			continue
		w.pos += ((float(w.dir) * float(w.speed)) / maxf(C.STEP, 1.0)) * dt
		if w.pos >= float(n) - 0.01:
			w.pos = float(n) - 0.01
			w.dir = -1
		elif w.pos <= 0.0:
			w.pos = 0.0
			w.dir = 1
			if routes.size() > 0 and _rnd() < 0.35:
				w.route = routes[int(floor(_rnd() * float(routes.size())))]


func metrics() -> Dictionary:
	var anchors = 0
	for p in patches:
		if p.on:
			anchors += 1
	return {
		"time": time,
		"segs": segs.size(),
		"tips": tips.size(),
		"anchors": anchors,
		"workers": workers.size(),
		"firstAnchor": first_anchor,
		"midstep": midstep,
		"firstFusion": first_fusion,
		"firstWorkers": first_workers,
		"bigAnchored": big_anchored,
		"bigAnchorTime": big_anchor_time,
		"decayTime": decay_time,
		"fruitTime": fruit_time,
		"sporeTime": spore_time,
		"joinTime": join_time,
		"hintTime": hint_time,
		"quarantineTime": quarantine_time,
		"skeletonTime": skeleton_time,
		"giantTime": giant_time,
		"seedsTime": seeds_time,
		"mvpEndTime": mvp_end_time,
	}


func snapshot() -> Dictionary:
	var tip_out: Array = []
	for t in tips:
		tip_out.append({"x": t.x, "y": t.y})
	var patch_out: Array = []
	for p in patches:
		patch_out.append({"x": p.x, "y": p.y, "on": p.on, "big": p.get("big", false)})
	var matter_out: Array = []
	var fruit_out: Array = []
	for m in matters:
		matter_out.append({"x": m.x, "y": m.y, "r": m.r, "kind": m.kind, "decay": m.decay})
		if m.kind == "fruit":
			fruit_out.append({"x": m.x, "y": m.y})
	var germ_out: Array = []
	for g in germs:
		germ_out.append({"x": g.x, "y": g.y, "linked": g.linked})
	return {
		"tips": tip_out,
		"patches": patch_out,
		"seed": {"x": seed.x, "y": seed.y} if seed != null else null,
		"matters": matter_out,
		"germs": germ_out,
		"fruits": fruit_out,
		"infected": {"x": infected.x, "y": infected.y, "r": infected.r, "dead": infected.dead} if infected != null else null,
		"skeleton": {"x": skeleton.x, "y": skeleton.y, "r": skeleton.r, "encircled": skeleton.encircled} if skeleton != null else null,
		"giantFruit": {"x": giant_fruit.x, "y": giant_fruit.y, "r": giant_fruit.r, "grow": giant_fruit.grow} if giant_fruit != null else null,
		"seedCapsule": {"x": seed_capsule.x, "y": seed_capsule.y} if seed_capsule != null else null,
	}


func bootstrap_start5() -> void:
	plant_seed(float(C.W) * 0.5, float(C.H) * 0.5)
	time = C.START5_T
	var base: float = _rnd() * PI * 2.0
	for i in range(6):
		var a: float = base + (float(i) * PI * 2.0) / 6.0
		var x: float = seed.x
		var y: float = seed.y
		var prev: float = -1
		for s in range(28):
			var nx: float = x + cos(a + (_rnd() - 0.5) * 0.4) * C.STEP
			var ny: float = y + sin(a + (_rnd() - 0.5) * 0.4) * C.STEP
			prev = _push_seg(x, y, nx, ny, prev, 1 if s > 20 else 0)
			x = nx
			y = ny
		_add_tip(x, y, a, prev)
	for i in range(mini(3, patches.size())):
		var p: Dictionary = patches[i]
		if p.get("big", false):
			continue
		p.on = true
		p.lit = 1.0
		var idx: float = _push_seg(seed.x, seed.y, p.x, p.y, -1, 1)
		routes.append([idx])
		if first_anchor == null:
			first_anchor = 35.0
	mid_wow_done = true
	midstep = 80.0
	first_fusion = 120.0
	first_workers = 220.0
	_spawn_big_patch()
	var big: Variant = null
	for p2 in patches:
		if p2.get("big", false):
			big = p2
			break
	if big != null:
		big.on = true
		big.lit = 1.0
		big_anchored = true
		big_anchor_time = C.START5_T - 5.0
		var idx2: float = _push_seg(seed.x, seed.y, big.x, big.y, -1, 2)
		routes.append([idx2])
		cam_zoom = C.CAM_ZOOM_OUT
		cam_zoom_target = C.CAM_ZOOM_OUT
		network_pulse = 0.6
	for i in range(40):
		_spawn_worker()
	_spawn_matters()


func bootstrap_start10() -> void:
	bootstrap_start5()
	## Fast-forward midgame markers so Age 3 content can start.
	decay_time = C.WOW_DECAY
	fruit_time = C.WOW_FRUIT
	spore_time = C.WOW_SPORE
	join_time = C.WOW_JOIN
	_spawn_fruit_at(float(C.W) * 0.42, float(C.H) * 0.45)
	_spawn_fruit_at(float(C.W) * 0.58, float(C.H) * 0.52)
	for m in matters:
		if m.kind != "fruit":
			m.encircled = true
			m.decay = 1.0
	for i in range(C.SPORE_GERMS):
		var a: float = (float(i) / float(C.SPORE_GERMS)) * PI * 2.0
		germs.append({
			"x": seed.x + cos(a) * 220.0,
			"y": seed.y + sin(a) * 180.0,
			"lit": 1.0,
			"linked": true,
		})
	heart_beat = 0.7
	time = C.START10_T
	_trigger_hint()
	_begin_invasion()


func stress_fill(seg_count: int, worker_count: int) -> void:
	if seed == null:
		plant_seed(float(C.W) / 2.0, float(C.H) / 2.0)
	while segs.size() < seg_count:
		var x1: float = _rnd() * float(C.W)
		var y1: float = _rnd() * float(C.H)
		var a: float = _rnd() * PI * 2.0
		var x2: float = x1 + cos(a) * C.STEP
		var y2: float = y1 + sin(a) * C.STEP
		var p: float = int(floor(_rnd() * float(segs.size()))) if segs.size() > 0 else -1
		_push_seg(x1, y1, x2, y2, p, int(floor(_rnd() * 3.0)))
	if routes.size() == 0:
		var path: Array = []
		for i in range(mini(40, segs.size())):
			path.append(i)
		routes.append(path)
	while workers.size() < worker_count:
		workers.append({
			"route": routes[0],
			"pos": _rnd() * maxf(1.0, float(routes[0].size()) - 1.0),
			"dir": 1 if _rnd() < 0.5 else -1,
			"speed": C.WORKER_SPEED,
		})
	if first_workers == null and workers.size() > 0:
		first_workers = time
