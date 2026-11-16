## Build #15 screen juice — placement pop, pulse ripple, floating resource ticks.
## Presentation-only; no sim coupling beyond reading world coords.
class_name SwarmJuice
extends RefCounted


static func spawn_pop(bag: Array, x: float, y: float, col: Color = Color(0.75, 0.95, 0.7, 0.9), life: float = 0.42) -> void:
	bag.append({"kind": "pop", "x": x, "y": y, "t": 0.0, "life": life, "col": col})


static func spawn_ripple(bag: Array, x: float, y: float, big: bool = false, col: Color = Color(0.6, 0.9, 0.7, 0.7)) -> void:
	bag.append({"kind": "ripple", "x": x, "y": y, "t": 0.0, "life": 0.85 if big else 0.55, "col": col, "big": big})


static func spawn_float(bag: Array, x: float, y: float, text: String, col: Color = Color(0.9, 0.95, 0.75, 0.95)) -> void:
	bag.append({"kind": "float", "x": x, "y": y, "t": 0.0, "life": 0.95, "text": text, "col": col})


static func tick(bag: Array, dt: float) -> void:
	var i: int = bag.size() - 1
	while i >= 0:
		bag[i].t = float(bag[i].t) + dt
		if float(bag[i].t) >= float(bag[i].life):
			bag.remove_at(i)
		i -= 1


static func draw_all(ci: CanvasItem, bag: Array, to_iso: Callable, font: Font = null) -> void:
	if font == null:
		font = ThemeDB.fallback_font
	for fx in bag:
		var u: float = clampf(float(fx.t) / maxf(0.001, float(fx.life)), 0.0, 1.0)
		var iso: Vector2 = to_iso.call(float(fx.x), float(fx.y))
		var col: Color = fx.col
		match str(fx.kind):
			"pop":
				var a: float = (1.0 - u) * col.a
				var r: float = 6.0 + u * 28.0
				ci.draw_circle(iso, r * 0.35, Color(col.r, col.g, col.b, a * 0.55))
				ci.draw_arc(iso, r, 0.0, TAU, 36, Color(col.r, col.g, col.b, a), 2.0)
				ci.draw_arc(iso, r * 0.55, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, a * 0.45), 1.2)
			"ripple":
				var big: bool = bool(fx.get("big", false))
				var a2: float = (1.0 - u) * col.a
				var r2: float = (10.0 if big else 6.0) + u * (72.0 if big else 42.0)
				ci.draw_arc(iso, r2, 0.0, TAU, 48, Color(col.r, col.g, col.b, a2 * 0.85), 2.2 if big else 1.6)
				ci.draw_arc(iso, r2 * 0.72, 0.0, TAU, 40, Color(col.r, col.g, col.b, a2 * 0.35), 1.2)
			"float":
				var rise: float = u * 36.0
				var a3: float = (1.0 - u * u) * col.a
				var pos := iso + Vector2(-10.0, -12.0 - rise)
				ci.draw_string(font, pos, str(fx.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(col.r, col.g, col.b, a3))
