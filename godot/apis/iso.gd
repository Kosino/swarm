extends RefCounted
class_name ApisIso
## Isometric 2:1 helpers. World stays top-down W×H.

const C = preload("res://apis/config.gd")


static func world_to_iso(x: float, y: float) -> Vector2:
	var wx := x - float(C.W) * 0.5
	var wy := y - float(C.H) * 0.5
	return Vector2(wx - wy, (wx + wy) * 0.5)


static func iso_to_world(ix: float, iy: float) -> Vector2:
	var x := ix * 0.5 + iy
	var y := iy - ix * 0.5
	return Vector2(x + float(C.W) * 0.5, y + float(C.H) * 0.5)


static func tile_diamond(half_w: float, half_h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -half_h),
		Vector2(half_w, 0),
		Vector2(0, half_h),
		Vector2(-half_w, 0),
	])


static func box_points(cx: float, cy: float, half_w: float, half_h: float, height: float) -> Dictionary:
	var top_c := Vector2(cx, cy - height)
	var t0 := top_c + Vector2(0, -half_h)
	var t1 := top_c + Vector2(half_w, 0)
	var t2 := top_c + Vector2(0, half_h)
	var t3 := top_c + Vector2(-half_w, 0)
	var b1 := Vector2(cx, cy) + Vector2(half_w, 0)
	var b2 := Vector2(cx, cy) + Vector2(0, half_h)
	var b3 := Vector2(cx, cy) + Vector2(-half_w, 0)
	return {
		"top": PackedVector2Array([t0, t1, t2, t3]),
		"right": PackedVector2Array([t1, t2, b2, b1]),
		"left": PackedVector2Array([t3, t2, b2, b3]),
	}
