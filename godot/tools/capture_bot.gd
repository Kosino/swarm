extends RefCounted
class_name SwarmCaptureBot
## Lightweight seed-42 autoplay until target time for screenshot harness.


static func advance_mycelium(world: MyceliumWorld, target: float) -> void:
	var dt := 1.0 / 12.0
	var guard := 0
	while world.time < target - 0.02 and guard < 250000:
		guard += 1
		if world.tips.size() > 0 and not world.stroke_active:
			var tip = world.tips[0]
			var goal = null
			for p in world.patches:
				if not p.on:
					goal = p
					if p.get("big", false):
						break
			if goal == null:
				for m in world.matters:
					if not m.encircled:
						goal = m
						break
			if goal != null:
				var dx: float = goal.x - tip.x
				var dy: float = goal.y - tip.y
				var dist: float = sqrt(dx * dx + dy * dy)
				if dist > 8.0:
					var steps: int = mini(14, int(dist / 10.0) + 2)
					world.pointer_down(tip.x, tip.y)
					for s in range(1, steps + 1):
						var u: float = float(s) / float(steps)
						world.pointer_move(tip.x + dx * u, tip.y + dy * u)
					world.pointer_up()
		world.update(minf(dt, target - world.time))


static func _apis_max_trails(target: float) -> int:
	## Gate trails so 5:00 vs 11:00 growth stays readable.
	if target < 180.0:
		return 0
	if target < 360.0:
		return 1
	if target < 540.0:
		return 2
	if target < 660.0:
		return 3
	return 4


static func _stroke_pts(world: ApisWorld, pts: Array) -> void:
	if pts.is_empty():
		return
	world.pointer_down(float(pts[0].x), float(pts[0].y))
	for i in range(1, pts.size()):
		world.pointer_move(float(pts[i].x), float(pts[i].y))
	world.pointer_up()


static func advance_apis(world: ApisWorld, target: float) -> void:
	var dt := 1.0 / 12.0
	var guard := 0
	var max_trails: int = _apis_max_trails(target)
	while world.time < target - 0.02 and guard < 250000:
		guard += 1
		var cx: float = world.cx
		var cy: float = world.cy
		if not world.planted:
			world.pointer_down(cx, cy)
			world.pointer_up()
		elif world.flowers.size() > 0 and world.trails.size() < max_trails:
			## Early: nearest flower. Late (≥10:00): prefer tree once for highway/readability.
			var f = null
			if target >= 600.0 and world.trails.size() == 0:
				for cand in world.flowers:
					if cand.get("tree", false):
						f = cand
						break
			if f == null:
				f = world.flowers[mini(world.trails.size(), world.flowers.size() - 1)]
			var hc := Vector2(cx, cy)
			if world.core != null:
				hc = Vector2(world.core.x, world.core.y)
			var steps := 14
			world.pointer_down(hc.x, hc.y)
			for s in range(1, steps + 1):
				var u: float = float(s) / float(steps)
				var bend_x: float = -12.0 * sin(u * PI)
				var bend_y: float = 8.0 * sin(u * PI)
				world.pointer_move(lerpf(hc.x, f.x, u) + bend_x, lerpf(hc.y, f.y, u) + bend_y)
			world.pointer_up()
		## Age-3 capture gates (winter → brass → royal) so queen art appears late.
		elif target >= 670.0 and world.hint_time != null and world.winter_time == null and world.time >= 662.0:
			var pts_w: Array = []
			var rw := 100.0
			for i8 in range(22):
				var aw: float = -0.5 + (float(i8) / 21.0) * 2.6
				pts_w.append({"x": cx + cos(aw) * rw, "y": cy + sin(aw) * rw * 0.85})
			_stroke_pts(world, pts_w)
		elif target >= 740.0 and world.winter_time != null and world.brass_time == null and world.time >= 737.0:
			var tx: float = cx + 220.0
			var ty: float = cy - 40.0
			if world.rust_machine != null:
				tx = float(world.rust_machine.x)
				ty = float(world.rust_machine.y)
			var pts_b: Array = []
			for i9 in range(23):
				var tb: float = float(i9) / 22.0
				pts_b.append({"x": lerpf(cx, tx, tb), "y": lerpf(cy, ty, tb)})
			_stroke_pts(world, pts_b)
		elif target >= 820.0 and world.brass_time != null and world.royal_time == null and world.time >= 812.0:
			world.pointer_down(cx, cy)
			for _h in range(24):
				world.pointer_move(cx + 0.05, cy)
				world.update(dt)
			world.pointer_up()
		world.update(minf(dt, target - world.time))
