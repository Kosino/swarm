extends RefCounted
class_name SwarmDiegetic
## Branded diegetic HUD: first-90s hint panel, object tooltips, ending stats.
## Outer chrome = pro_v3 9-slice border only; inner fill is smooth dark for readable text.

const STheme = preload("res://ui/swarm_theme.gd")
const ApisC = preload("res://apis/config.gd")

const HINT_UNTIL := 90.0
## Presentational hold so ending stats are readable (does not affect sim medians).
const ORBIT_HOLD := 9.0

const PANEL_TEX := "res://art/pro_v3/ui/panel_9slice.png"
const COL_FILL := Color(0.106, 0.071, 0.043, 0.95) ## #1b120b @ ~95%
const COL_FILL_TOP := Color(0.14, 0.09, 0.055, 0.96)
const COL_TITLE := Color(0.949, 0.769, 0.420, 1.0) ## #f2c46b
const COL_BODY := Color(0.953, 0.906, 0.812, 1.0) ## #f3e7cf
const COL_OUTLINE := Color(0.04, 0.02, 0.01, 0.92)
const PAD := 12.0


static func mount(hud: CanvasLayer, rod: String) -> Dictionary:
	var out := {}
	hud.layer = 60

	var debug: Control = hud.get_node_or_null("Panel") as Control
	if debug:
		debug.visible = false
		out["debug"] = debug

	var layer := Control.new()
	layer.name = "DiegeticLayer"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(layer)
	out["layer"] = layer

	var tf := STheme.title_font()
	var bf := STheme.body_font()

	## --- Hint (bottom center, first 90s) ---
	## Slim chrome: short panels can't fit full 102/74 margins (border would fill the plate).
	var hint := _make_framed_panel("HintPanel", "slim")
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -260.0
	hint.offset_right = 260.0
	hint.offset_top = -150.0
	hint.offset_bottom = -14.0
	hint.visible = false
	layer.add_child(hint)
	out["hint"] = hint

	var hint_inner: VBoxContainer = hint.get_node("Fill/Pad/Box")
	hint_inner.alignment = BoxContainer.ALIGNMENT_CENTER
	var hint_title := _make_label("HintTitle", "Nápověda", tf, 20, COL_TITLE, true)
	hint_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_inner.add_child(hint_title)
	out["hint_title"] = hint_title
	var hint_label := _make_label("HintLabel", "", bf, 16, COL_BODY, false)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_inner.add_child(hint_label)
	out["hint_label"] = hint_label

	var legacy := hud.get_node_or_null("Diegetic")
	if legacy:
		legacy.visible = false

	## --- Tooltip (auto-sizes to text) ---
	var tip := _make_framed_panel("TooltipPanel", "slim")
	tip.visible = false
	tip.z_index = 20
	## Grow from top-left; size follows content.
	tip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	layer.add_child(tip)
	out["tooltip"] = tip

	var tip_inner: VBoxContainer = tip.get_node("Fill/Pad/Box")
	tip_inner.add_theme_constant_override("separation", 4)
	var tip_title := _make_label("TipTitle", "", tf, 20, COL_TITLE, true)
	tip_inner.add_child(tip_title)
	out["tip_title"] = tip_title
	var tip_body := _make_label("TipBody", "", bf, 15, COL_BODY, false)
	tip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_body.custom_minimum_size = Vector2(0, 0)
	tip_inner.add_child(tip_body)
	out["tip_body"] = tip_body

	## --- Ending overlay (two-column stats, larger type, content-heavy) ---
	var end := _make_framed_panel("EndPanel", "compact")
	end.set_anchors_preset(Control.PRESET_CENTER)
	end.anchor_left = 0.5
	end.anchor_right = 0.5
	end.anchor_top = 0.5
	end.anchor_bottom = 0.5
	## Lower plate so orbit logo + other-planet glimmer stay readable above.
	end.offset_left = -280.0
	end.offset_right = 280.0
	end.offset_top = -40.0
	end.offset_bottom = 300.0
	end.visible = false
	end.modulate.a = 0.0
	layer.add_child(end)
	out["end"] = end

	var end_inner: VBoxContainer = end.get_node("Fill/Pad/Box")
	end_inner.add_theme_constant_override("separation", 10)
	end_inner.alignment = BoxContainer.ALIGNMENT_CENTER

	## pro_v3 wordmark — text title is fallback only.
	var end_logo := TextureRect.new()
	end_logo.name = "EndLogo"
	end_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	end_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	end_logo.custom_minimum_size = Vector2(300, 104)
	end_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var logo_tex: Texture2D = load("res://art/pro_v3/menu/logo_swarm_sm.png") as Texture2D
	if logo_tex == null:
		logo_tex = load("res://art/pro_v3/menu/logo_swarm.png") as Texture2D
	end_logo.texture = logo_tex
	end_logo.visible = logo_tex != null
	end_inner.add_child(end_logo)
	out["end_logo"] = end_logo

	var end_title := _make_label("EndTitle", "SWARM", tf, 30, COL_TITLE, true)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title.visible = logo_tex == null
	end_inner.add_child(end_title)
	out["end_title"] = end_title

	var end_sub := _make_label("EndSub", "Orbit", bf, 16, COL_BODY, false)
	end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_inner.add_child(end_sub)
	out["end_sub"] = end_sub

	var stats_grid := GridContainer.new()
	stats_grid.name = "StatsGrid"
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 28)
	stats_grid.add_theme_constant_override("v_separation", 8)
	stats_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	end_inner.add_child(stats_grid)
	out["end_stats_grid"] = stats_grid
	out["end_stat_font"] = bf
	## Keep a dummy for older refresh callers (unused).
	out["end_stats"] = null

	return out


static func _make_framed_panel(pname: String, border_mode: String) -> PanelContainer:
	var outer := PanelContainer.new()
	outer.name = pname
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_theme_stylebox_override("panel", _chrome_style(border_mode))

	## Smooth dark fill — honeycomb stays on the 9-slice border only.
	var fill := PanelContainer.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_theme_stylebox_override("panel", _fill_style())
	outer.add_child(fill)

	var pad := MarginContainer.new()
	pad.name = "Pad"
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", int(PAD))
	pad.add_theme_constant_override("margin_right", int(PAD))
	pad.add_theme_constant_override("margin_top", int(PAD))
	pad.add_theme_constant_override("margin_bottom", int(PAD))
	fill.add_child(pad)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	pad.add_child(box)
	return outer


static func _chrome_style(border_mode: String) -> StyleBox:
	if ResourceLoader.exists(PANEL_TEX) or FileAccess.file_exists(PANEL_TEX):
		var tex: Texture2D = load(PANEL_TEX) as Texture2D
		if tex != null:
			var sb := StyleBoxTexture.new()
			sb.texture = tex
			## Honeycomb is border-only — do not draw the busy center fill.
			sb.draw_center = false
			if border_mode == "slim":
				## Short hint/tooltip panels: margins must leave a real content hole.
				sb.texture_margin_left = 40
				sb.texture_margin_top = 28
				sb.texture_margin_right = 28
				sb.texture_margin_bottom = 28
				sb.content_margin_left = 8
				sb.content_margin_right = 8
				sb.content_margin_top = 6
				sb.content_margin_bottom = 6
			elif border_mode == "compact":
				## Ending: thinner frame relative to large content area.
				sb.texture_margin_left = 66
				sb.texture_margin_top = 48
				sb.texture_margin_right = 48
				sb.texture_margin_bottom = 48
				sb.content_margin_left = 10
				sb.content_margin_right = 10
				sb.content_margin_top = 8
				sb.content_margin_bottom = 8
			else:
				## Full Art Pipeline margins: L/T/R/B = 102/74/74/74.
				sb.texture_margin_left = 102
				sb.texture_margin_top = 74
				sb.texture_margin_right = 74
				sb.texture_margin_bottom = 74
				sb.content_margin_left = 14
				sb.content_margin_right = 14
				sb.content_margin_top = 12
				sb.content_margin_bottom = 12
			return sb
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.border_color = Color(0.55, 0.4, 0.22, 0.9)
	flat.set_border_width_all(3)
	flat.set_corner_radius_all(8)
	flat.content_margin_left = 10
	flat.content_margin_right = 10
	flat.content_margin_top = 8
	flat.content_margin_bottom = 8
	return flat


static func _fill_style() -> StyleBoxFlat:
	var fill := StyleBoxFlat.new()
	## Smooth dark plate with a slight top→bottom warmth (gradient via border tint).
	fill.bg_color = COL_FILL
	fill.border_color = COL_FILL_TOP
	fill.border_width_top = 3
	fill.border_width_bottom = 0
	fill.border_width_left = 0
	fill.border_width_right = 0
	fill.set_corner_radius_all(4)
	fill.content_margin_left = 0
	fill.content_margin_right = 0
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	return fill


static func _make_label(lname: String, text: String, font: Font, size_px: int, col: Color, title: bool) -> Label:
	var lab := Label.new()
	lab.name = lname
	lab.text = text
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		lab.add_theme_font_override("font", font)
	lab.add_theme_font_size_override("font_size", size_px)
	lab.add_theme_color_override("font_color", col)
	## 1px dark outline + soft shadow for contrast on any plate.
	lab.add_theme_constant_override("outline_size", 1)
	lab.add_theme_color_override("font_outline_color", COL_OUTLINE)
	lab.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.0, 0.75))
	lab.add_theme_constant_override("shadow_offset_x", 1)
	lab.add_theme_constant_override("shadow_offset_y", 1)
	if title:
		lab.add_theme_constant_override("outline_size", 2)
	return lab


static func set_debug_visible(nodes: Dictionary, on: bool) -> void:
	if nodes.has("debug") and nodes["debug"] is Control:
		(nodes["debug"] as Control).visible = on


static func refresh_hint(nodes: Dictionary, time_s: float, label: String, force: bool = false) -> void:
	if not nodes.has("hint"):
		return
	var hint: PanelContainer = nodes["hint"]
	var show := force or (time_s < HINT_UNTIL and label.strip_edges() != "")
	hint.visible = show
	if show and nodes.has("hint_label"):
		(nodes["hint_label"] as Label).text = label
	if show and not force and time_s > HINT_UNTIL - 8.0:
		hint.modulate.a = clampf((HINT_UNTIL - time_s) / 8.0, 0.0, 1.0)
	elif show:
		hint.modulate.a = 1.0


static func refresh_tooltip(nodes: Dictionary, info: Dictionary, screen_pos: Vector2) -> void:
	if not nodes.has("tooltip"):
		return
	var tip: PanelContainer = nodes["tooltip"]
	if info.is_empty() or str(info.get("title", "")) == "":
		tip.visible = false
		return
	tip.visible = true
	var title_s := str(info.get("title", ""))
	var body_s := str(info.get("body", ""))
	if nodes.has("tip_title"):
		(nodes["tip_title"] as Label).text = title_s
	if nodes.has("tip_body"):
		var body_lab: Label = nodes["tip_body"]
		body_lab.text = body_s
		## Soft wrap only for long lines; otherwise hug text.
		var wrap_w := 320.0 if body_s.length() > 42 else 0.0
		body_lab.custom_minimum_size = Vector2(wrap_w, 0)
		body_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap_w > 0.0 else TextServer.AUTOWRAP_OFF
	## Reset forced size so content drives layout, then clamp on-screen.
	tip.size = Vector2.ZERO
	tip.reset_size()
	var sz: Vector2 = tip.get_combined_minimum_size()
	tip.size = sz
	var vp := tip.get_viewport_rect().size
	var x := clampf(screen_pos.x + 18.0, 8.0, maxf(8.0, vp.x - sz.x - 8.0))
	var y := clampf(screen_pos.y + 18.0, 8.0, maxf(8.0, vp.y - sz.y - 8.0))
	tip.position = Vector2(x, y)


static func refresh_ending(nodes: Dictionary, rod: String, orbit_t: float, stats_rows: Array) -> void:
	if not nodes.has("end"):
		return
	var end: PanelContainer = nodes["end"]
	## Let planet glimmer + logo beat read first; stats panel follows.
	var show := orbit_t > 1.15
	end.visible = show
	if not show:
		return
	end.modulate.a = clampf((orbit_t - 1.15) / 1.4, 0.0, 1.0)
	if nodes.has("end_logo"):
		var logo: TextureRect = nodes["end_logo"]
		logo.visible = logo.texture != null
		if nodes.has("end_title"):
			(nodes["end_title"] as Label).visible = not logo.visible
	if nodes.has("end_title"):
		(nodes["end_title"] as Label).text = "SWARM"
	if nodes.has("end_sub"):
		(nodes["end_sub"] as Label).text = "Apis — orbit" if rod == "apis" else "Mycelium — orbit"
	if not nodes.has("end_stats_grid"):
		return
	var grid: GridContainer = nodes["end_stats_grid"]
	## Clear previous rows.
	for c in grid.get_children():
		c.queue_free()
	var font: Font = nodes.get("end_stat_font", null)
	for row in stats_rows:
		var lab_s := ""
		var val_s := ""
		if typeof(row) == TYPE_DICTIONARY:
			lab_s = str(row.get("label", ""))
			val_s = str(row.get("value", ""))
		else:
			## Fallback: "Label  value" split on last spaces-run.
			var raw := str(row)
			var parts: PackedStringArray = raw.split("  ")
			if parts.size() >= 2:
				lab_s = parts[0]
				val_s = parts[parts.size() - 1]
			else:
				lab_s = raw
		var lab := _make_label("L", lab_s, font, 22, COL_BODY, false)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var val := _make_label("V", val_s, font, 22, COL_TITLE, true)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(lab)
		grid.add_child(val)


static func fmt_clock(t: float) -> String:
	var m := int(floor(t / 60.0))
	var s := int(floor(fmod(maxf(0.0, t), 60.0)))
	return "%d:%02d" % [m, s]


static func mycelium_stats(m: Dictionary) -> Array:
	return [
		{"label": "Čas běhu", "value": fmt_clock(float(m.get("time", 0.0)))},
		{"label": "Kotvy", "value": str(int(m.get("anchors", 0)))},
		{"label": "Segmenty", "value": str(int(m.get("segs", 0)))},
		{"label": "Dělníci", "value": str(int(m.get("workers", 0)))},
		{"label": "Špičky", "value": str(int(m.get("tips", 0)))},
	]


static func apis_stats(m: Dictionary) -> Array:
	return [
		{"label": "Čas běhu", "value": fmt_clock(float(m.get("time", 0.0)))},
		{"label": "Komory", "value": str(int(m.get("chambers", 0)))},
		{"label": "Dělnice", "value": str(int(m.get("workers", 0)))},
		{"label": "Trasy", "value": str(int(m.get("routes", 0)))},
		{"label": "Vosk", "value": "%.0f%%" % (float(m.get("wax", 0.0)) * 100.0)},
	]


## Read-only hover probe — does not mutate world / sim clocks.
static func inspect_mycelium(world, wx: float, wy: float) -> Dictionary:
	if world == null:
		return {}
	var best := {}
	var bd := 42.0
	if world.seed != null:
		var d0: float = _hypot(wx - world.seed.x, wy - world.seed.y)
		if d0 < bd:
			bd = d0
			best = {"title": "Zárodek", "body": "Srdce sítě. Táhni hyfy ven ke skvrnám."}
	for p in world.patches:
		var d: float = _hypot(wx - p.x, wy - p.y)
		var r: float = float(p.get("r", 22.0)) + 10.0
		if d < maxf(bd, r) and d < r:
			bd = d
			if p.get("big", false):
				best = {"title": "Velká skvrna", "body": "Hlavní kotva. Doveď silnou hyfu a ukotvi síť."}
			elif p.on:
				best = {"title": "Kotva", "body": "Už propojená skvrna živin. Síť sem proudí."}
			else:
				best = {"title": "Skvrna živin", "body": "Doveď špičku hyfy sem a ukotvi."}
	for m in world.matters:
		var d2: float = _hypot(wx - m.x, wy - m.y)
		var rr: float = float(m.get("r", 20.0)) + 8.0
		if d2 < rr and d2 < bd + 4.0:
			bd = d2
			match str(m.kind):
				"machine":
					best = {"title": "Rozpadlý stroj", "body": "Zakroužkuj hyfami — mycelium ho rozloží."}
				"beetle":
					best = {"title": "Brouk", "body": "Zakroužkuj a nech síť ho strávit."}
				"fruit":
					best = {"title": "Plodnice", "body": "Výtrusný uzel. Podrž pro růst."}
				_:
					best = {"title": "Hmota", "body": "Zakroužkuj nebo podrž."}
	for g in world.germs:
		var d3: float = _hypot(wx - g.x, wy - g.y)
		if d3 < 28.0 and d3 < bd + 4.0:
			bd = d3
			best = {"title": "Cizí zárodek", "body": "Doveď síť a spoj se — join."}
	if world.infected != null and not world.infected.dead:
		var d4: float = _hypot(wx - world.infected.x, wy - world.infected.y)
		if d4 < float(world.infected.r) + 10.0:
			best = {"title": "Nákaza", "body": "Zakroužkuj nakaženou část — karanténa."}
	if world.skeleton != null:
		var d5: float = _hypot(wx - world.skeleton.x, wy - world.skeleton.y)
		if d5 < float(world.skeleton.r) + 10.0:
			best = {"title": "Kostra stroje", "body": "Zakroužkuj kostru a nech ji prorůst."}
	if world.giant_fruit != null:
		var d6: float = _hypot(wx - world.giant_fruit.x, wy - world.giant_fruit.y)
		if d6 < float(world.giant_fruit.r) + 12.0:
			best = {"title": "Obří plodnice", "body": "Podrž — připraví tobolku semen."}
	if world.seed_capsule != null:
		var d7: float = _hypot(wx - world.seed_capsule.x, wy - world.seed_capsule.y)
		if d7 < 28.0:
			best = {"title": "Tobolka", "body": "Semy mycelia — Seeds."}
	return best


static func inspect_apis(world, wx: float, wy: float) -> Dictionary:
	if world == null:
		return {}
	var best := {}
	var bd := 48.0
	var hex: float = float(ApisC.HEX)
	if world.core != null:
		var d0: float = _hypot(wx - world.core.x, wy - world.core.y)
		if d0 < maxf(bd, hex * 1.4):
			bd = d0
			best = {"title": "Jádro", "body": "Královna / procesor. Stav komory kolem."}
	for ch in world.chambers.values():
		var p: Vector2 = world._axial_to_pixel(ch.q, ch.r)
		var d: float = _hypot(wx - p.x, wy - p.y)
		if d < hex * 1.05 and d < bd + 2.0:
			bd = d
			if ch.grow < 1.0:
				best = {"title": "Komora (roste)", "body": "Vosková buňka se staví. Čekej na líhnutí."}
			elif not ch.hatched:
				best = {"title": "Komora", "body": "Připravená plástev — brzy vylíhne dělnici."}
			else:
				best = {"title": "Komora", "body": "Obsazená plástev. Odkazuj dělnice na květiny."}
	if world.planted:
		for ch2 in world.chambers.values():
			if ch2.grow < 1.0:
				continue
			for n in world._neighbors(ch2.q, ch2.r):
				if n.x == 0 and n.y == 0:
					continue
				if world.chambers.has(world._hex_key(n.x, n.y)):
					continue
				var p2: Vector2 = world._axial_to_pixel(n.x, n.y)
				var d2: float = _hypot(wx - p2.x, wy - p2.y)
				if d2 < hex * 0.95 and d2 < bd:
					bd = d2
					best = {"title": "Stavební místo", "body": "Klepni — postav další komoru (spotřebuje vosk)."}
	for f in world.flowers:
		var d3: float = _hypot(wx - f.x, wy - f.y)
		var fr: float = float(f.get("r", 18.0)) + 12.0
		if d3 < fr and d3 < bd + 6.0:
			bd = d3
			if f.get("tree", false):
				best = {"title": "Zlatý strom", "body": "Dosáhni tahem — odemkne velký let."}
			else:
				best = {"title": "Květina", "body": "Táhni od úlu sem — odkaž dělnici na nektar."}
	if world.meadow2 != null:
		var d4: float = _hypot(wx - world.meadow2.x, wy - world.meadow2.y)
		if d4 < 40.0:
			best = {"title": "Druhá louka", "body": "Namaluj stopu sem — rojení."}
	if world.second_hive != null:
		var d5: float = _hypot(wx - world.second_hive.x, wy - world.second_hive.y)
		if d5 < 36.0:
			best = {"title": "Druhý úl", "body": "Spoj úly stopou — join."}
	if world.rust_machine != null:
		var d6: float = _hypot(wx - world.rust_machine.x, wy - world.rust_machine.y)
		if d6 < float(world.rust_machine.r) + 12.0:
			best = {"title": "Rozpadlá mašina", "body": "Stopa sem — mosazný lesk a kov."}
	if world.royal_cell != null:
		var d7: float = _hypot(wx - world.royal_cell.x, wy - world.royal_cell.y)
		if d7 < 28.0:
			best = {"title": "Královská buňka", "body": "Nová královna — Seeds."}
	return best


static func _hypot(dx: float, dy: float) -> float:
	return sqrt(dx * dx + dy * dy)
