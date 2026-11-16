## Headless acceptance — same policy as src/mycelium/headless.ts
class_name MyceliumHeadless
extends RefCounted

const C = preload("res://mycelium/config.gd")
const G = preload("res://mycelium/gestures.gd")

const SEEDS := [7, 11, 21, 42, 77, 100, 128, 256, 512, 1024, 2048, 4096]


func _fmt(t: Variant) -> String:
	if t == null or (t is float and is_nan(t)):
		return "—"
	var tf: float = float(t)
	var m: float = int(floor(tf / 60.0))
	var s = fmod(tf, 60.0)
	var ss = "%.1f" % s
	if ss.length() < 4:
		ss = "0" + ss
	return "%d:%s" % [m, ss]


func _median(vals: Array) -> Variant:
	var a: Array = []
	for v in vals:
		if v != null and typeof(v) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(v)):
			a.append(float(v))
	if a.is_empty():
		return null
	a.sort()
	var mid: float = int(floor(float(a.size()) / 2.0))
	if a.size() % 2 == 1:
		return a[mid]
	return (a[mid - 1] + a[mid]) / 2.0


func _max_gap(times: Array) -> Variant:
	var seq: Array = []
	for v in times:
		if v != null:
			seq.append(float(v))
	if seq.size() < 2:
		return null
	seq.sort()
	var g = 0.0
	for i in range(1, seq.size()):
		g = maxf(g, seq[i] - seq[i - 1])
	return g


func _mean_tip(tips: Array) -> Dictionary:
	var acc = {"x": 0.0, "y": 0.0}
	if tips.is_empty():
		return acc
	for tip in tips:
		acc.x += tip.x / float(tips.size())
		acc.y += tip.y / float(tips.size())
	return acc


func _nearest_unlit(tips: Array, patches: Array, prefer_big: bool) -> Variant:
	var unlit: Array = []
	for p in patches:
		if not p.on:
			unlit.append(p)
	if unlit.is_empty() or tips.is_empty():
		return null
	if prefer_big:
		for p in unlit:
			if p.get("big", false):
				return p
	var tip: Dictionary = tips[0]
	var best: Dictionary = unlit[0]
	for p in unlit:
		var db: float = G.hypot(best.x - tip.x, best.y - tip.y)
		var dp: float = G.hypot(p.x - tip.x, p.y - tip.y)
		if dp < db:
			best = p
	return best


func _encircle_stroke(world: MyceliumWorld, cx: float, cy: float, r: float, steps: int) -> void:
	var pts: Array = []
	for i in range(steps + 1):
		var a: float = (float(i) / float(steps)) * PI * 2.0
		pts.append({"x": cx + cos(a) * r, "y": cy + sin(a) * r})
	var length = 0.0
	for i in range(1, pts.size()):
		length += G.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y)
	if length < C.ENC_MIN_LEN:
		var scale: float = (C.ENC_MIN_LEN * 1.15) / maxf(length, 1.0)
		for p in pts:
			p.x = cx + (p.x - cx) * scale
			p.y = cy + (p.y - cy) * scale
	world.pointer_down(pts[0].x, pts[0].y)
	for i in range(1, pts.size()):
		world.pointer_move(pts[i].x, pts[i].y)
	world.pointer_up()


func _run_playthrough(seed_num: int) -> Dictionary:
	var rng = MyceliumRng.new(seed_num)
	var world = MyceliumWorld.new({"silent": true, "rng": rng})
	var notes: Array = []
	var dt: float = 1.0 / 12.0
	var max_t = 920.0
	var planted = false
	var encircle_cd = 0.0
	var sim_t = 0.0
	while sim_t < max_t:
		var m = world.metrics()
		var snap = world.snapshot()
		var tips: Array = snap.tips
		var patches: Array = snap.patches
		var matters: Array = snap.matters
		var germs: Array = snap.germs
		var fruits: Array = snap.fruits

		if not planted and m.time >= 7.0:
			world.pointer_down(float(C.W) * 0.52, float(C.H) * 0.5)
			world.pointer_up()
			planted = true

		var anchors: int = m.anchors
		var phase = "idle"

		if not planted:
			phase = "idle"
		elif not m.bigAnchored:
			if anchors < 3:
				if anchors < 1 and m.time >= 12.0:
					phase = "guide"
				elif anchors >= 1 and m.time >= 26.0:
					phase = "guide"
				else:
					phase = "idle"
			elif m.firstFusion == null and m.time >= 100.0:
				phase = "fuse"
			elif m.firstWorkers == null and m.firstFusion != null and m.time < 250.0:
				phase = "hold"
			elif m.time >= 250.0 and not m.bigAnchored:
				phase = "big"
			elif m.firstWorkers == null and m.time >= 120.0:
				phase = "hold"
			else:
				phase = "idle"
		else:
			encircle_cd = maxf(0.0, encircle_cd - dt)
			if m.decayTime == null and m.time >= 340.0:
				phase = "enc_decay"
			elif m.fruitTime == null and m.decayTime != null and m.time >= 415.0:
				phase = "enc_fruit"
			elif m.sporeTime == null and m.fruitTime != null and m.time >= 488.0:
				phase = "enc_spore"
			elif m.joinTime == null and m.sporeTime != null and m.time >= 552.0:
				phase = "join"
			elif m.hintTime == null and m.joinTime != null:
				phase = "wait_hint"
			## Mid-game mite purge (GDD Invaze roztočů) before Age-3 quarantine.
			elif m.miteTime != null and not bool(m.get("mitePurged", false)) and m.quarantineTime == null and m.time >= 640.0:
				phase = "enc_mites"
			elif m.quarantineTime == null and m.hintTime != null and m.time >= 662.0:
				phase = "enc_quarantine"
			elif m.skeletonTime == null and m.quarantineTime != null and m.time >= 737.0:
				phase = "enc_skeleton"
			elif m.giantTime == null and m.skeletonTime != null and m.time >= 812.0:
				phase = "hold_giant"
			elif m.seedsTime == null and m.giantTime != null:
				phase = "wait_seeds"
			elif m.mvpEndTime == null and m.seedsTime != null:
				phase = "wait_mvp"
			else:
				phase = "idle"

		if phase == "guide" or phase == "big":
			var target = _nearest_unlit(tips, patches, phase == "big" or m.time >= 250.0)
			if target != null and tips.size() > 0:
				var tip: Dictionary
				if phase == "big":
					tip = tips[0]
					for t in tips:
						if G.hypot(t.x - target.x, t.y - target.y) < G.hypot(tip.x - target.x, tip.y - target.y):
							tip = t
				else:
					tip = _mean_tip(tips)
				var pull: float = 0.85 if phase == "big" else (0.62 if anchors < 1 else 0.70)
				world.pointer_down(tip.x, tip.y)
				world.pointer_move(
					tip.x + (target.x - tip.x) * pull,
					tip.y + (target.y - tip.y) * pull
				)
		elif phase == "hold":
			if tips.size() > 0:
				var hx: float = tips[0].x
				var hy: float = tips[0].y
				world.pointer_down(hx, hy)
				world.pointer_move(hx + 0.05, hy)
		elif phase == "fuse":
			if tips.size() >= 2:
				var a: Dictionary = tips[0]
				var b: Dictionary = tips[1]
				var best: float = -1.0
				for i in range(tips.size()):
					for j in range(i + 1, tips.size()):
						var d: float = G.hypot(tips[i].x - tips[j].x, tips[i].y - tips[j].y)
						if d > best:
							best = d
							a = tips[i]
							b = tips[j]
				var mid_x: float = (a.x + b.x) * 0.5
				var mid_y: float = (a.y + b.y) * 0.5
				if int(floor(m.time * 4.0)) % 2 == 0:
					world.pointer_down(a.x, a.y)
					world.pointer_move(mid_x, mid_y)
				else:
					world.pointer_down(b.x, b.y)
					world.pointer_move(mid_x, mid_y)
			elif tips.size() == 1:
				world.pointer_down(tips[0].x, tips[0].y)
				world.pointer_move(
					tips[0].x + cos(m.time) * C.GUIDE_R * 0.35,
					tips[0].y + sin(m.time) * C.GUIDE_R * 0.35
				)
		elif phase == "enc_decay" and encircle_cd <= 0.0:
			var target2: Variant = null
			for x in matters:
				if x.kind == "machine" and x.decay < 0.5:
					target2 = x
					break
			if target2 == null:
				for x in matters:
					if x.kind != "fruit":
						target2 = x
						break
			if target2 != null:
				_encircle_stroke(world, target2.x, target2.y, target2.r * 1.35, 24)
				encircle_cd = 2.5
		elif phase == "enc_fruit" and encircle_cd <= 0.0:
			var target3: Variant = null
			for x in matters:
				if x.kind == "beetle" and x.decay < 0.5:
					target3 = x
					break
			if target3 == null:
				for x in matters:
					if x.kind != "fruit" and x.decay < 0.5:
						target3 = x
						break
			if target3 != null:
				_encircle_stroke(world, target3.x, target3.y, target3.r * 1.4, 28)
				encircle_cd = 2.5
		elif phase == "enc_spore" and encircle_cd <= 0.0:
			if fruits.size() >= 1:
				var mx = 0.0
				var my = 0.0
				for f in fruits:
					mx += f.x
					my += f.y
				mx /= float(fruits.size())
				my /= float(fruits.size())
				var span = 80.0
				for f in fruits:
					span = maxf(span, G.hypot(f.x - mx, f.y - my) + 40.0)
				_encircle_stroke(world, mx, my, span, 32)
				encircle_cd = 2.5
		elif phase == "join" and encircle_cd <= 0.0:
			if germs.size() > 0:
				var g: Dictionary = germs[0]
				for x in germs:
					if not x.linked:
						g = x
						break
				if tips.size() > 0:
					world.pointer_down(tips[0].x, tips[0].y)
					world.pointer_move(g.x, g.y)
					world.pointer_up()
				_encircle_stroke(world, g.x, g.y, 55.0, 20)
				encircle_cd = 2.0
		elif phase == "enc_mites" and encircle_cd <= 0.0:
			var nest = snap.get("miteNest")
			if nest != null:
				_encircle_stroke(world, nest.x, nest.y, float(nest.r) * 1.35, 24)
				encircle_cd = 2.2
		elif phase == "enc_quarantine" and encircle_cd <= 0.0:
			var inf = snap.get("infected")
			if inf != null:
				_encircle_stroke(world, inf.x, inf.y, float(inf.r) * 1.35, 24)
				encircle_cd = 2.2
		elif phase == "enc_skeleton" and encircle_cd <= 0.0:
			var sk = snap.get("skeleton")
			if sk != null:
				_encircle_stroke(world, sk.x, sk.y, float(sk.r) * 1.35, 28)
				encircle_cd = 2.2
		elif phase == "hold_giant":
			var gf = snap.get("giantFruit")
			var fx: float
			var fy: float
			if gf != null:
				fx = gf.x
				fy = gf.y
			elif fruits.size() > 0:
				fx = fruits[0].x
				fy = fruits[0].y
			elif snap.seed != null:
				fx = snap.seed.x
				fy = snap.seed.y - 20.0
			else:
				fx = float(C.W) * 0.5
				fy = float(C.H) * 0.5
			world.pointer_down(fx, fy)
			world.pointer_move(fx + 0.05, fy)
		else:
			world.pointer_up()

		world.update(dt)
		# Fast-forward quiet time-gated stretches between midgame / Age 3 wows
		# (pause at mite / purge windows so headless can encircle).
		if phase in ["idle", "wait_hint", "wait_seeds", "wait_mvp"] and m.bigAnchored:
			var jump := 0.0
			if m.decayTime == null and m.time < 338.0:
				jump = minf(338.0 - m.time, 3.0)
			elif m.fruitTime == null and m.decayTime != null and m.time < 413.0:
				jump = minf(413.0 - m.time, 3.0)
			elif m.sporeTime == null and m.fruitTime != null and m.time < 486.0:
				jump = minf(486.0 - m.time, 3.0)
			elif m.joinTime == null and m.sporeTime != null and m.time < 550.0:
				jump = minf(550.0 - m.time, 3.0)
			elif m.hintTime == null and m.joinTime != null and m.time < 593.0:
				jump = minf(593.0 - m.time, 3.0)
			elif m.hintTime != null and m.miteTime == null and m.time < 623.0:
				jump = minf(623.0 - m.time, 4.0)
			elif m.miteTime != null and not bool(m.get("mitePurged", false)) and m.quarantineTime == null and m.time < 638.0:
				jump = minf(638.0 - m.time, 4.0)
			elif m.quarantineTime == null and m.hintTime != null and m.time < 660.0:
				jump = minf(660.0 - m.time, 4.0)
			elif m.skeletonTime == null and m.quarantineTime != null and m.time < 735.0:
				jump = minf(735.0 - m.time, 4.0)
			elif m.giantTime == null and m.skeletonTime != null and m.time < 810.0:
				jump = minf(810.0 - m.time, 4.0)
			elif m.seedsTime == null and m.giantTime != null and m.time < 878.0:
				jump = minf(878.0 - m.time, 4.0)
			elif m.mvpEndTime == null and m.seedsTime != null and m.time < 898.0:
				jump = minf(898.0 - m.time, 4.0)
			if jump > 0.0:
				world.update(jump)
				sim_t += jump
		if phase == "guide" and int(floor(m.time * 2.0)) % 11 == 0:
			world.pointer_up()
		sim_t += dt

	world.pointer_up()
	var metrics = world.metrics()
	var beat = {
		"firstAnchor": metrics.firstAnchor,
		"midstep": metrics.midstep,
		"firstFusion": metrics.firstFusion,
		"firstWorkers": metrics.firstWorkers,
		"bigAnchor": metrics.bigAnchorTime,
		"decay": metrics.decayTime,
		"fruit": metrics.fruitTime,
		"spore": metrics.sporeTime,
		"join": metrics.joinTime,
		"hint": metrics.hintTime,
		"quarantine": metrics.quarantineTime,
		"skeleton": metrics.skeletonTime,
		"giant": metrics.giantTime,
		"seeds": metrics.seedsTime,
		"mvpEnd": metrics.mvpEndTime,
	}
	if beat.firstAnchor == null:
		notes.append("no first anchor")
	if beat.midstep == null:
		notes.append("no midstep (3rd anchor)")
	if beat.firstFusion == null:
		notes.append("no fusion within 5:00")
	if beat.firstWorkers == null:
		notes.append("no workers")
	if not metrics.bigAnchored:
		notes.append("big anchor not reached by 5:00")
	if beat.decay == null:
		notes.append("no decay wow")
	if beat.fruit == null:
		notes.append("no fruit wow")
	if beat.spore == null:
		notes.append("no spore wow")
	if beat.join == null:
		notes.append("no join wow")
	if beat.hint == null:
		notes.append("no hint")
	if beat.quarantine == null:
		notes.append("no quarantine")
	if beat.skeleton == null:
		notes.append("no skeleton")
	if beat.giant == null:
		notes.append("no giant fruit")
	if beat.seeds == null:
		notes.append("no seeds hint")
	if beat.mvpEnd == null:
		notes.append("no mvp end")
	var early_gap = _max_gap([beat.firstAnchor, beat.midstep, beat.firstFusion, beat.firstWorkers, beat.bigAnchor])
	var mid_gap = _max_gap([beat.decay, beat.fruit, beat.spore, beat.join, beat.hint])
	var late_gap = _max_gap([beat.quarantine, beat.skeleton, beat.giant, beat.seeds, beat.mvpEnd])
	if early_gap != null and float(early_gap) > 90.0:
		notes.append("early gap %.1fs > 90s" % float(early_gap))
	if mid_gap != null and float(mid_gap) > 90.0:
		notes.append("mid gap %.1fs > 90s" % float(mid_gap))
	if late_gap != null and float(late_gap) > 90.0:
		notes.append("late gap %.1fs > 90s" % float(late_gap))
	return {"metrics": metrics, "beat": beat, "notes": notes}


func _measure_fps() -> Dictionary:
	var world = MyceliumWorld.new({"silent": true, "rng": MyceliumRng.new(99)})
	world.pointer_down(float(C.W) / 2.0, float(C.H) / 2.0)
	world.pointer_up()
	world.stress_fill(1100, C.MAX_WORKERS)
	var frames = 180
	var dt: float = 1.0 / 60.0
	var t0 = Time.get_ticks_usec()
	for i in range(frames):
		world.update(dt)
	var elapsed_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	var update_ms: float = elapsed_ms / float(frames)
	var fps: float = 1000.0 / maxf(update_ms, 0.001)
	return {"fps": fps, "updateMs": update_ms}


func _near(t: Variant, target: float, tol: float) -> bool:
	return t != null and absf(float(t) - target) <= tol


func _nums(xs: Array) -> Array:
	var out: Array = []
	for v in xs:
		if v != null:
			out.append(float(v))
	return out


func run() -> Dictionary:
	var beats: Array = []
	var all_notes: Array = []
	var fps_info = _measure_fps()
	var fps: float = fps_info.fps
	var update_ms: float = fps_info.updateMs

	for s in SEEDS:
		print("seed ", s, "…")
		var result = _run_playthrough(int(s))
		beats.append(result.beat)
		if result.notes.size() > 0:
			all_notes.append("seed %d: %s" % [int(s), "; ".join(result.notes)])

	var med = {
		"firstAnchor": _median(_nums(beats.map(func(b): return b.firstAnchor))),
		"midstep": _median(_nums(beats.map(func(b): return b.midstep))),
		"firstFusion": _median(_nums(beats.map(func(b): return b.firstFusion))),
		"firstWorkers": _median(_nums(beats.map(func(b): return b.firstWorkers))),
		"bigAnchor": _median(_nums(beats.map(func(b): return b.bigAnchor))),
		"decay": _median(_nums(beats.map(func(b): return b.decay))),
		"fruit": _median(_nums(beats.map(func(b): return b.fruit))),
		"spore": _median(_nums(beats.map(func(b): return b.spore))),
		"join": _median(_nums(beats.map(func(b): return b.join))),
		"hint": _median(_nums(beats.map(func(b): return b.hint))),
		"quarantine": _median(_nums(beats.map(func(b): return b.quarantine))),
		"skeleton": _median(_nums(beats.map(func(b): return b.skeleton))),
		"giant": _median(_nums(beats.map(func(b): return b.giant))),
		"seeds": _median(_nums(beats.map(func(b): return b.seeds))),
		"mvpEnd": _median(_nums(beats.map(func(b): return b.mvpEnd))),
	}

	var early_gaps: Array = []
	var mid_gaps: Array = []
	var late_gaps: Array = []
	for b in beats:
		var eg = _max_gap([b.firstAnchor, b.midstep, b.firstFusion, b.firstWorkers, b.bigAnchor])
		var mg = _max_gap([b.decay, b.fruit, b.spore, b.join, b.hint])
		var lg = _max_gap([b.quarantine, b.skeleton, b.giant, b.seeds, b.mvpEnd])
		if eg != null:
			early_gaps.append(eg)
		if mg != null:
			mid_gaps.append(mg)
		if lg != null:
			late_gaps.append(lg)
	var med_early_gap = _median(early_gaps)
	var med_mid_gap = _median(mid_gaps)
	var med_late_gap = _median(late_gaps)

	var all_complete = true
	for b in beats:
		if (
			b.firstAnchor == null or b.midstep == null or b.firstFusion == null
			or b.firstWorkers == null or b.bigAnchor == null or b.decay == null
			or b.fruit == null or b.spore == null or b.join == null or b.hint == null
			or b.quarantine == null or b.skeleton == null or b.giant == null
			or b.seeds == null or b.mvpEnd == null
		):
			all_complete = false
			break

	# Early wow targets: anchor~0:35 mid~1:20 (Godot fix for web slip after build 6)
	var early_ok = (
		_near(med.firstAnchor, 35.0, 15.0)
		and _near(med.midstep, 80.0, 15.0)
		and _near(med.firstFusion, 120.0, 15.0)
		and _near(med.firstWorkers, 198.2, 15.0)
		and _near(med.bigAnchor, 262.4, 15.0)
		and med_early_gap != null
		and float(med_early_gap) <= 90.0
	)
	# Midgame: match web medians ±15s (5:40 / 6:55 / 8:08 / 9:12 / 9:55)
	var mid_ok = (
		_near(med.decay, 340.0, 15.0)
		and _near(med.fruit, 415.0, 15.0)
		and _near(med.spore, 488.0, 15.0)
		and _near(med.join, 552.0, 15.0)
		and _near(med.hint, 595.0, 15.0)
		and med_mid_gap != null
		and float(med_mid_gap) <= 90.0
	)
	# Age 3: 11:10 / 12:25 / 13:40 / 14:40 / 15:00
	var late_ok = (
		_near(med.quarantine, 670.0, 15.0)
		and _near(med.skeleton, 745.0, 15.0)
		and _near(med.giant, 820.0, 15.0)
		and _near(med.seeds, 880.0, 15.0)
		and _near(med.mvpEnd, 900.0, 15.0)
		and med_late_gap != null
		and float(med_late_gap) <= 90.0
	)
	var ok = early_ok and mid_ok and late_ok and all_complete and fps >= 60.0

	var seeds_out: Array = []
	for i in range(beats.size()):
		var b: Dictionary = beats[i]
		seeds_out.append({
			"seed": SEEDS[i],
			"decay": _fmt(b.decay),
			"fruit": _fmt(b.fruit),
			"spore": _fmt(b.spore),
			"join": _fmt(b.join),
			"hint": _fmt(b.hint),
			"quarantine": _fmt(b.quarantine),
			"skeleton": _fmt(b.skeleton),
			"giant": _fmt(b.giant),
			"seeds": _fmt(b.seeds),
			"mvpEnd": _fmt(b.mvpEnd),
		})

	return {
		"ok": ok,
		"medians": {
			"anchor": _fmt(med.firstAnchor),
			"midstep": _fmt(med.midstep),
			"fusion": _fmt(med.firstFusion),
			"workers": _fmt(med.firstWorkers),
			"bigAnchor": _fmt(med.bigAnchor),
			"decay": _fmt(med.decay),
			"fruit": _fmt(med.fruit),
			"spore": _fmt(med.spore),
			"join": _fmt(med.join),
			"hint": _fmt(med.hint),
			"quarantine": _fmt(med.quarantine),
			"skeleton": _fmt(med.skeleton),
			"giant": _fmt(med.giant),
			"seeds": _fmt(med.seeds),
			"mvpEnd": _fmt(med.mvpEnd),
			"earlyGapSec": med_early_gap,
			"midGapSec": med_mid_gap,
			"lateGapSec": med_late_gap,
		},
		"fps": int(round(fps)),
		"updateMs": snappedf(update_ms, 0.001),
		"seeds": seeds_out,
		"notes": all_notes,
	}
