extends RefCounted
class_name SwarmOrganicHud
## Mid-game Korpus chrome: honeycomb resource bar + organic build-menu icons.
## Visual-only — does not touch sim clocks / medians. Unlocks ~10:00 (GDD mid-game).

const STheme = preload("res://ui/swarm_theme.gd")

const BTN_NORMAL := "res://art/pro_v3/ui/btn_normal.png"
const BTN_HOVER := "res://art/pro_v3/ui/btn_hover.png"
const ICON_APIS := "res://art/pro_v3/ui/icon_apis_64.png"
const ICON_MYC := "res://art/pro_v3/ui/icon_mycelium_64.png"

## GDD: metrics / Korpus after early diegetic stretch.
const UNLOCK_T := 600.0

const COL_TITLE := Color(0.949, 0.769, 0.420, 1.0) ## #f2c46b
const COL_BODY := Color(0.953, 0.906, 0.812, 1.0) ## #f3e7cf
const COL_OUTLINE := Color(0.04, 0.02, 0.01, 0.92)
const COL_FILL := Color(0.106, 0.071, 0.043, 0.94)
const COL_AMBER := Color(0.95, 0.72, 0.28, 1.0)
const COL_AMBER_DIM := Color(0.35, 0.22, 0.1, 0.85)
const COL_LIME := Color(0.72, 0.92, 0.35, 1.0)
const COL_LIME_DIM := Color(0.18, 0.28, 0.12, 0.85)
const COL_BRASS := Color(0.72, 0.55, 0.28, 0.95)
const COL_MOSS := Color(0.42, 0.62, 0.38, 0.95)

## 1080p-readable sizes (also clear at 720p capture).
const ICON_PX := 52.0
const BAR_H := 64.0
const CELL_R := 11.0
const BUILD_ICON := 58.0
const FONT_TITLE := 18
const FONT_BODY := 16


static func mount(hud: CanvasLayer, rod: String) -> Dictionary:
	var out := {"rod": rod}
	var layer := Control.new()
	layer.name = "OrganicHud"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.visible = false
	hud.add_child(layer)
	out["layer"] = layer

	var tf := STheme.title_font()
	var bf := STheme.body_font()
	var accent := COL_AMBER if rod == "apis" else COL_LIME
	var accent_dim := COL_AMBER_DIM if rod == "apis" else COL_LIME_DIM
	var border := COL_BRASS if rod == "apis" else COL_MOSS

	## --- Resource bar (top-left) ---
	var bar := _framed_plate("ResourceBar")
	bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bar.anchor_left = 0.0
	bar.anchor_right = 0.0
	bar.anchor_top = 0.0
	bar.anchor_bottom = 0.0
	bar.offset_left = 14.0
	bar.offset_top = 12.0
	bar.offset_right = 420.0
	bar.offset_bottom = 12.0 + BAR_H + 18.0
	layer.add_child(bar)
	out["bar"] = bar

	var bar_row := HBoxContainer.new()
	bar_row.name = "Row"
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_theme_constant_override("separation", 10)
	_plate_box(bar).add_child(bar_row)

	var rod_icon := TextureRect.new()
	rod_icon.name = "RodIcon"
	rod_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rod_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rod_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rod_icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	var icon_path := ICON_APIS if rod == "apis" else ICON_MYC
	if ResourceLoader.exists(icon_path) or FileAccess.file_exists(icon_path):
		rod_icon.texture = load(icon_path) as Texture2D
	bar_row.add_child(rod_icon)
	out["rod_icon"] = rod_icon

	var bar_col := VBoxContainer.new()
	bar_col.name = "Col"
	bar_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_col.add_theme_constant_override("separation", 4)
	bar_row.add_child(bar_col)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_theme_constant_override("separation", 8)
	bar_col.add_child(title_row)

	var res_title := _label("ResTitle", "Vosk" if rod == "apis" else "Živiny", tf, FONT_TITLE, COL_TITLE, true)
	title_row.add_child(res_title)
	out["res_title"] = res_title

	var res_val := _label("ResVal", "0%", bf, FONT_BODY, COL_BODY, false)
	res_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(res_val)
	out["res_val"] = res_val

	var cells := _HoneyCellBar.new()
	cells.name = "Cells"
	cells.custom_minimum_size = Vector2(0, CELL_R * 2.0 + 4.0)
	cells.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cells.cell_count = 8
	cells.fill = 0.0
	cells.fill_color = accent
	cells.empty_color = accent_dim
	cells.edge_color = border
	cells.organic = rod != "apis"
	bar_col.add_child(cells)
	out["cells"] = cells

	## --- Build menu (bottom-left) ---
	var menu := _framed_plate("BuildMenu")
	menu.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	menu.anchor_left = 0.0
	menu.anchor_right = 0.0
	menu.anchor_top = 1.0
	menu.anchor_bottom = 1.0
	menu.offset_left = 14.0
	menu.offset_right = 14.0 + 4.0 * (BUILD_ICON + 10.0) + 36.0
	menu.offset_top = -14.0 - BUILD_ICON - 52.0
	menu.offset_bottom = -14.0
	layer.add_child(menu)
	out["menu"] = menu

	var menu_col := VBoxContainer.new()
	menu_col.name = "MenuCol"
	menu_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_col.add_theme_constant_override("separation", 4)
	_plate_box(menu).add_child(menu_col)

	var menu_title := _label("MenuTitle", "Stavby", tf, FONT_TITLE, COL_TITLE, true)
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_col.add_child(menu_title)

	var icons_row := HBoxContainer.new()
	icons_row.name = "Icons"
	icons_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	icons_row.add_theme_constant_override("separation", 8)
	menu_col.add_child(icons_row)
	out["icons_row"] = icons_row

	var defs: Array = _build_defs(rod)
	var icon_nodes: Array = []
	for d in defs:
		var slot := _make_build_slot(str(d.id), str(d.label), str(d.glyph), accent, border, bf)
		icons_row.add_child(slot)
		icon_nodes.append(slot)
	out["build_icons"] = icon_nodes
	out["build_defs"] = defs
	return out


static func refresh(nodes: Dictionary, rod: String, time_s: float, fill: float, role_counts: Dictionary, ending: bool) -> void:
	if not nodes.has("layer"):
		return
	var layer: Control = nodes["layer"]
	var show := (not ending) and time_s >= UNLOCK_T
	layer.visible = show
	if not show:
		return
	layer.modulate.a = clampf((time_s - UNLOCK_T) / 4.0, 0.0, 1.0)

	var f := clampf(fill, 0.0, 1.0)
	if nodes.has("cells") and nodes["cells"] != null:
		nodes["cells"].fill = f
		nodes["cells"].queue_redraw()
	if nodes.has("res_val"):
		(nodes["res_val"] as Label).text = "%d%%" % int(round(f * 100.0))
	if nodes.has("res_title"):
		(nodes["res_title"] as Label).text = "Vosk" if rod == "apis" else "Živiny"

	if not nodes.has("build_icons"):
		return
	var icons: Array = nodes["build_icons"]
	var defs: Array = nodes.get("build_defs", [])
	for i in range(mini(icons.size(), defs.size())):
		var slot: Control = icons[i]
		var id := str(defs[i].id)
		var n := int(role_counts.get(id, 0))
		var count_lab: Label = slot.get_node_or_null("Count") as Label
		if count_lab:
			count_lab.text = str(n) if n > 0 else "—"
			count_lab.modulate.a = 1.0 if n > 0 else 0.55
		var glyph: Control = slot.get_node_or_null("Glyph") as Control
		if glyph:
			glyph.modulate = Color(1, 1, 1, 1.0 if n > 0 else 0.55)
		## Soft hover glow via btn_hover when specialized present.
		var frame: TextureRect = slot.get_node_or_null("Frame") as TextureRect
		if frame and (ResourceLoader.exists(BTN_HOVER) or FileAccess.file_exists(BTN_HOVER)):
			frame.texture = load(BTN_HOVER if n > 0 else BTN_NORMAL) as Texture2D


static func apis_fill(world) -> float:
	if world == null:
		return 0.0
	return clampf(float(world.wax), 0.0, 1.0)


static func mycelium_fill(world) -> float:
	if world == null:
		return 0.0
	## Presentational nutrient read from lit anchors — no sim change.
	var lit := 0
	var total := 0
	for p in world.patches:
		total += 1
		if p.on:
			lit += 1
	if total <= 0:
		return clampf(float(world.network_bright), 0.0, 1.0)
	var base := clampf(float(lit) / maxf(4.0, float(total) * 0.55), 0.0, 1.0)
	return clampf(base * 0.85 + float(world.network_bright) * 0.15, 0.0, 1.0)


static func apis_roles(world) -> Dictionary:
	var out := {"comb": 0, "nursery": 0, "honey": 0, "workshop": 0}
	if world == null:
		return out
	for ch in world.chambers.values():
		if float(ch.get("grow", 0.0)) < 1.0:
			continue
		var role := str(ch.get("role", "comb"))
		if out.has(role):
			out[role] = int(out[role]) + 1
		else:
			out[role] = 1
	return out


static func mycelium_roles(world) -> Dictionary:
	var out := {"anchor": 0, "nursery": 0, "depot": 0, "sporangium": 0}
	if world == null:
		return out
	for p in world.patches:
		if not p.on:
			continue
		var role := str(p.get("role", "anchor"))
		if role == "depot":
			out["depot"] = int(out["depot"]) + 1
		else:
			out["anchor"] = int(out["anchor"]) + 1
	for g in world.germs:
		var grole := str(g.get("role", "germ"))
		if grole == "nursery":
			out["nursery"] = int(out["nursery"]) + 1
		elif grole == "depot":
			out["depot"] = int(out["depot"]) + 1
	for m in world.matters:
		if str(m.get("kind", "")) != "fruit":
			continue
		var mrole := str(m.get("role", "fruit"))
		if mrole == "sporangium":
			out["sporangium"] = int(out["sporangium"]) + 1
	return out


static func _build_defs(rod: String) -> Array:
	if rod == "apis":
		return [
			{"id": "comb", "label": "Komora", "glyph": "hex"},
			{"id": "nursery", "label": "Líheň", "glyph": "cocoon"},
			{"id": "honey", "label": "Medárna", "glyph": "drop"},
			{"id": "workshop", "label": "Dílna", "glyph": "gear"},
		]
	return [
		{"id": "anchor", "label": "Kotva", "glyph": "root"},
		{"id": "nursery", "label": "Líheň", "glyph": "bulb"},
		{"id": "depot", "label": "Zásoba", "glyph": "pod"},
		{"id": "sporangium", "label": "Výtrus", "glyph": "spore"},
	]


static func _framed_plate(pname: String) -> PanelContainer:
	var outer := PanelContainer.new()
	outer.name = pname
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Honeycomb chrome from Art Pipeline button 9-slice (readable when thin).
	if ResourceLoader.exists(BTN_NORMAL) or FileAccess.file_exists(BTN_NORMAL):
		var tex: Texture2D = load(BTN_NORMAL) as Texture2D
		if tex != null:
			var sb := StyleBoxTexture.new()
			sb.texture = tex
			sb.texture_margin_left = 28
			sb.texture_margin_top = 16
			sb.texture_margin_right = 28
			sb.texture_margin_bottom = 16
			sb.content_margin_left = 6
			sb.content_margin_right = 6
			sb.content_margin_top = 4
			sb.content_margin_bottom = 4
			sb.draw_center = false
			outer.add_theme_stylebox_override("panel", sb)
		else:
			outer.add_theme_stylebox_override("panel", _flat_chrome())
	else:
		outer.add_theme_stylebox_override("panel", _flat_chrome())

	var fill := PanelContainer.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := StyleBoxFlat.new()
	fs.bg_color = COL_FILL
	fs.set_corner_radius_all(4)
	fs.content_margin_left = 8
	fs.content_margin_right = 8
	fs.content_margin_top = 6
	fs.content_margin_bottom = 6
	fill.add_theme_stylebox_override("panel", fs)
	outer.add_child(fill)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	fill.add_child(box)
	return outer


static func _plate_box(plate: PanelContainer) -> VBoxContainer:
	return plate.get_node("Fill/Box") as VBoxContainer


static func _flat_chrome() -> StyleBoxFlat:
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.border_color = COL_BRASS
	flat.set_border_width_all(2)
	flat.set_corner_radius_all(8)
	flat.content_margin_left = 6
	flat.content_margin_right = 6
	flat.content_margin_top = 4
	flat.content_margin_bottom = 4
	return flat


static func _make_build_slot(id: String, label: String, glyph: String, accent: Color, border: Color, font: Font) -> Control:
	var slot := Control.new()
	slot.name = "Slot_%s" % id
	slot.custom_minimum_size = Vector2(BUILD_ICON + 4.0, BUILD_ICON + 22.0)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.position = Vector2(2, 0)
	frame.size = Vector2(BUILD_ICON, BUILD_ICON)
	if ResourceLoader.exists(BTN_NORMAL) or FileAccess.file_exists(BTN_NORMAL):
		frame.texture = load(BTN_NORMAL) as Texture2D
	slot.add_child(frame)

	var g := _BuildGlyph.new()
	g.name = "Glyph"
	g.glyph = glyph
	g.accent = accent
	g.border = border
	g.position = Vector2(2, 0)
	g.size = Vector2(BUILD_ICON, BUILD_ICON)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(g)

	var count := _label("Count", "—", font, 14, COL_BODY, false)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.position = Vector2(0, BUILD_ICON - 2.0)
	count.size = Vector2(BUILD_ICON + 4.0, 20.0)
	slot.add_child(count)

	## Tiny caption under count for 1080p ID (tooltip-like, short).
	var cap := _label("Cap", label, font, 11, COL_TITLE, false)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.position = Vector2(-6, BUILD_ICON + 12.0)
	cap.size = Vector2(BUILD_ICON + 16.0, 16.0)
	cap.visible = false ## count + glyph carry the read; keep label for a11y/debug
	slot.add_child(cap)
	return slot


static func _label(lname: String, text: String, font: Font, size_px: int, col: Color, title: bool) -> Label:
	var lab := Label.new()
	lab.name = lname
	lab.text = text
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		lab.add_theme_font_override("font", font)
	lab.add_theme_font_size_override("font_size", size_px)
	lab.add_theme_color_override("font_color", col)
	lab.add_theme_constant_override("outline_size", 2 if title else 1)
	lab.add_theme_color_override("font_outline_color", COL_OUTLINE)
	lab.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.0, 0.7))
	lab.add_theme_constant_override("shadow_offset_x", 1)
	lab.add_theme_constant_override("shadow_offset_y", 1)
	return lab


## Honeycomb / organic cell strip for the resource meter.
class _HoneyCellBar extends Control:
	var cell_count: int = 8
	var fill: float = 0.0
	var fill_color: Color = Color(0.95, 0.72, 0.28, 1.0)
	var empty_color: Color = Color(0.35, 0.22, 0.1, 0.85)
	var edge_color: Color = Color(0.72, 0.55, 0.28, 0.95)
	var organic: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var n := maxi(1, cell_count)
		var w := size.x
		var h := size.y
		var gap := 3.0
		var cell_w := (w - gap * float(n - 1)) / float(n)
		var filled := fill * float(n)
		for i in range(n):
			var x := float(i) * (cell_w + gap) + cell_w * 0.5
			var y := h * 0.5
			var r := mini(cell_w * 0.48, h * 0.48)
			var amt := clampf(filled - float(i), 0.0, 1.0)
			var col := empty_color.lerp(fill_color, amt)
			if organic:
				## Soft pod (circle + oval) — avoid self-intersecting polys (triangulation).
				draw_circle(Vector2(x, y), r * 0.92, col)
				draw_circle(Vector2(x, y - r * 0.12), r * 0.55, col.lightened(0.12))
				draw_arc(Vector2(x, y), r, 0.0, TAU, 20, edge_color, 1.5, true)
			else:
				_draw_hex(Vector2(x, y), r, col)
				_draw_hex_outline(Vector2(x, y), r, edge_color)

	func _draw_hex(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in range(6):
			var a := -PI / 6.0 + float(k) * PI / 3.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		## Convex regular hex — always triangulates.
		if pts.size() >= 3:
			draw_colored_polygon(pts, col)

	func _draw_hex_outline(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in range(7):
			var a := -PI / 6.0 + float(k % 6) * PI / 3.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_polyline(pts, col, 1.6, true)


## Simple silhouette glyphs inside honeycomb button frames.
class _BuildGlyph extends Control:
	var glyph: String = "hex"
	var accent: Color = Color(0.95, 0.72, 0.28, 1.0)
	var border: Color = Color(0.72, 0.55, 0.28, 0.95)

	func _draw() -> void:
		var c := size * 0.5
		var r := mini(size.x, size.y) * 0.28
		match glyph:
			"hex":
				_poly(c, r, 6, -PI / 6.0, accent)
				_ring(c, r * 1.05, 6, -PI / 6.0, border)
			"cocoon":
				draw_circle(c + Vector2(0, 2), r * 0.55, accent.darkened(0.15))
				draw_circle(c + Vector2(0, -r * 0.35), r * 0.38, accent)
				draw_arc(c, r * 0.9, 0.2, TAU - 0.2, 16, border, 1.5, true)
			"drop":
				var pts := PackedVector2Array([
					c + Vector2(0, -r * 1.1),
					c + Vector2(r * 0.75, r * 0.25),
					c + Vector2(0, r * 0.95),
					c + Vector2(-r * 0.75, r * 0.25),
				])
				draw_colored_polygon(pts, accent)
			"gear":
				_poly(c, r * 1.05, 8, 0.0, accent.darkened(0.1))
				draw_circle(c, r * 0.35, Color(0.106, 0.071, 0.043, 0.94))
				draw_arc(c, r * 0.38, 0.0, TAU, 12, border, 1.4, true)
			"root":
				draw_line(c + Vector2(0, -r), c + Vector2(0, r * 0.2), accent, 2.4, true)
				draw_line(c, c + Vector2(-r * 0.85, r * 0.85), accent, 2.0, true)
				draw_line(c, c + Vector2(r * 0.85, r * 0.85), accent, 2.0, true)
				draw_circle(c + Vector2(0, -r * 0.15), r * 0.28, accent)
			"bulb":
				draw_circle(c + Vector2(0, r * 0.15), r * 0.7, accent)
				draw_line(c + Vector2(0, -r * 0.9), c + Vector2(0, -r * 0.2), border, 2.0, true)
				draw_circle(c + Vector2(0, r * 0.05), r * 0.28, accent.lightened(0.25))
			"pod":
				draw_circle(c, r * 0.85, accent.darkened(0.05))
				draw_circle(c + Vector2(-r * 0.2, -r * 0.15), r * 0.25, accent.lightened(0.2))
				draw_arc(c, r * 0.88, 0.0, TAU, 16, border, 1.4, true)
			"spore":
				draw_circle(c + Vector2(0, r * 0.25), r * 0.55, accent)
				draw_circle(c + Vector2(-r * 0.55, -r * 0.35), r * 0.28, accent.lightened(0.1))
				draw_circle(c + Vector2(r * 0.5, -r * 0.25), r * 0.22, accent.darkened(0.05))
				draw_line(c + Vector2(0, r * 0.8), c + Vector2(0, r * 1.05), border, 1.6, true)
			_:
				draw_circle(c, r, accent)

	func _poly(c: Vector2, r: float, n: int, rot: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in range(n):
			var a := rot + float(k) * TAU / float(n)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, col)

	func _ring(c: Vector2, r: float, n: int, rot: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in range(n + 1):
			var a := rot + float(k % n) * TAU / float(n)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_polyline(pts, col, 1.5, true)
