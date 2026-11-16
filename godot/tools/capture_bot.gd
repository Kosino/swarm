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


static func advance_apis(world: ApisWorld, target: float) -> void:
	var dt := 1.0 / 12.0
	var guard := 0
	while world.time < target - 0.02 and guard < 250000:
		guard += 1
		if not world.planted:
			world.pointer_down(world.cx, world.cy)
			world.pointer_up()
		elif world.flowers.size() > 0 and world.trails.size() < 4:
			## Prefer tree once, then flowers — ensures hive→flower/tree pheromone streams in captures.
			var f = null
			if world.trails.size() == 0:
				for cand in world.flowers:
					if cand.get("tree", false):
						f = cand
						break
			if f == null:
				f = world.flowers[mini(world.trails.size(), world.flowers.size() - 1)]
			var hc := Vector2(world.cx, world.cy)
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
		world.update(minf(dt, target - world.time))
