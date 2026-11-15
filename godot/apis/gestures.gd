extends RefCounted
class_name ApisGestures
## Build #6 gesture helpers — points are {x,y} dictionaries (match world.gd).

const ENC_CLOSE_PX := 60.0
const ENC_ANGLE_FRAC := 0.8
const ENC_OUTLINE_FRAC := 0.5
const SNAP_BASE := 40.0
const TRAIL_FINISH_PX := 60.0


static func hypot(dx: float, dy: float) -> float:
	return sqrt(dx * dx + dy * dy)


static func path_length(pts: Array) -> float:
	var length := 0.0
	for i in range(1, pts.size()):
		length += hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y)
	return length


static func point_in_poly(px: float, py: float, pts: Array) -> bool:
	var inside := false
	var j := pts.size() - 1
	for i in range(pts.size()):
		var xi: float = pts[i].x
		var yi: float = pts[i].y
		var xj: float = pts[j].x
		var yj: float = pts[j].y
		var hit := (yi > py) != (yj > py) and px < ((xj - xi) * (py - yi)) / (yj - yi + 1e-9) + xi
		if hit:
			inside = not inside
		j = i
	return inside


static func smooth_resample(pts: Array, spacing: float = 8.0, passes: int = 1) -> Array:
	if pts.size() < 2:
		var copy: Array = []
		for p in pts:
			copy.append({"x": p.x, "y": p.y})
		return copy
	var cur: Array = []
	for p in pts:
		cur.append({"x": p.x, "y": p.y})
	for _p in range(passes):
		if cur.size() < 3:
			break
		var nxt: Array = [{"x": cur[0].x, "y": cur[0].y}]
		for i in range(1, cur.size() - 1):
			var a = cur[i - 1]
			var b = cur[i]
			var c = cur[i + 1]
			nxt.append({
				"x": (a.x + b.x * 2.0 + c.x) * 0.25,
				"y": (a.y + b.y * 2.0 + c.y) * 0.25,
			})
		nxt.append({"x": cur[cur.size() - 1].x, "y": cur[cur.size() - 1].y})
		cur = nxt
	var out: Array = [{"x": cur[0].x, "y": cur[0].y}]
	var ax: float = cur[0].x
	var ay: float = cur[0].y
	var budget := spacing
	for i in range(1, cur.size()):
		var x1: float = cur[i].x
		var y1: float = cur[i].y
		var dx := x1 - ax
		var dy := y1 - ay
		var seg := hypot(dx, dy)
		while seg >= budget and seg > 1e-6:
			var t := budget / seg
			ax += dx * t
			ay += dy * t
			out.append({"x": ax, "y": ay})
			dx = x1 - ax
			dy = y1 - ay
			seg = hypot(dx, dy)
			budget = spacing
		budget -= seg
		ax = x1
		ay = y1
	var last = cur[cur.size() - 1]
	var tip = out[out.size() - 1]
	if hypot(last.x - tip.x, last.y - tip.y) > 1.5:
		out.append({"x": last.x, "y": last.y})
	return out


static func angular_coverage(pts: Array, cx: float, cy: float, bins: int = 36) -> float:
	if pts.size() < 3:
		return 0.0
	var hit := PackedByteArray()
	hit.resize(bins)
	for p in pts:
		var a := atan2(p.y - cy, p.x - cx)
		if a < 0.0:
			a += TAU
		var b := mini(bins - 1, int(floor((a / TAU) * float(bins))))
		hit[b] = 1
	var n := 0
	for i in range(bins):
		n += int(hit[i])
	return float(n) / float(bins)


static func outline_coverage(pts: Array, cx: float, cy: float, rx: float, ry: float, samples: int = 24) -> float:
	if pts.size() < 3:
		return 0.0
	var inside := 0
	for i in range(samples):
		var a := (float(i) / float(samples)) * TAU
		if point_in_poly(cx + cos(a) * rx, cy + sin(a) * ry, pts):
			inside += 1
	return float(inside) / float(samples)


static func loop_closed(pts: Array, close_px: float = ENC_CLOSE_PX) -> bool:
	if pts.size() < 3:
		return false
	return hypot(pts[pts.size() - 1].x - pts[0].x, pts[pts.size() - 1].y - pts[0].y) <= close_px


static func encircle_recognized(raw: Array, shape: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var min_len: float = float(opts.get("minLen", opts.get("min_len", 140.0)))
	var min_pts: int = int(opts.get("minPts", opts.get("min_pts", 10)))
	var close_px: float = float(opts.get("closePx", opts.get("close_px", ENC_CLOSE_PX)))
	var angle_frac: float = float(opts.get("angleFrac", opts.get("angle_frac", ENC_ANGLE_FRAC)))
	var outline_frac: float = float(opts.get("outlineFrac", opts.get("outline_frac", ENC_OUTLINE_FRAC)))
	var poly := smooth_resample(raw)
	if poly.size() < min_pts or path_length(poly) < min_len:
		return {"ok": false, "poly": poly}
	var closed := loop_closed(poly, close_px)
	var ang := angular_coverage(poly, shape.x, shape.y)
	if not closed and ang < angle_frac:
		return {"ok": false, "poly": poly}
	var center_hit := point_in_poly(shape.x, shape.y, poly)
	var outline := outline_coverage(poly, shape.x, shape.y, shape.rx, shape.ry)
	return {"ok": center_hit or outline >= outline_frac, "poly": poly}


static func snap_radius(meta: Dictionary = {}) -> float:
	var dpr: float = float(meta.get("dpr", 1.0))
	var touch: bool = bool(meta.get("touch", false))
	return SNAP_BASE * maxf(1.0, dpr) * (1.55 if touch else 1.0)


static func nearest_target(x: float, y: float, targets: Array, max_dist: float) -> Variant:
	var best = null
	var bd := max_dist
	var bi := -1
	for i in range(targets.size()):
		var t = targets[i]
		var d := hypot(t.x - x, t.y - y)
		if d < bd:
			bd = d
			best = t
			bi = i
	if best == null:
		return {}
	return {"target": best, "dist": bd, "index": bi}


static func spawn_miss(x: float, y: float) -> Dictionary:
	return {"x": x, "y": y, "t": 0.0, "dur": 0.55}


static func tick_miss(list: Array, dt: float) -> void:
	for m in list:
		m.t += dt
	for i in range(list.size() - 1, -1, -1):
		if list[i].t >= list[i].dur:
			list.remove_at(i)
