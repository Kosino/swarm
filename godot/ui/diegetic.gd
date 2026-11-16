extends RefCounted
class_name SwarmDiegetic
## Branded diegetic HUD: first-90s hint panel, object tooltips, ending stats.
## All chrome uses SwarmTheme 9-slice — no default Godot StyleBoxFlat panels.

const STheme = preload("res://ui/swarm_theme.gd")
const ApisC = preload("res://apis/config.gd")

const HINT_UNTIL := 90.0
## Presentational hold so ending stats are readable (does not affect sim medians).
const ORBIT_HOLD := 9.0


static func mount(hud: CanvasLayer, rod: String) -> Dictionary:
	var theme: Theme = STheme.build(rod)
	var out := {}

	## Sit above world + vignette so hints/tooltips/ending stay readable.
	hud.layer = 60

	## Debug panel stays F1-only; diegetic layer is always on.
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

	## --- Hint (bottom center, first 90s) ---
	var hint := PanelContainer.new()
	hint.name = "HintPanel"
	hint.theme = theme
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -220.0
	hint.offset_right = 220.0
	hint.offset_top = -110.0
	hint.offset_bottom = -18.0
	hint.visible = false
	layer.add_child(hint)
	out["hint"] = hint

	var hint_box := VBoxContainer.new()
	hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_child(hint_box)

	var hint_title := Label.new()
	hint_title.name = "HintTitle"
	hint_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_title.text = "Nápověda"
	var tf := STheme.title_font()
	if tf:
		hint_title.add_theme_font_override("font", tf)
	hint_title.add_theme_font_size_override("font_size", 13)
	hint_title.add_theme_color_override("font_color", Color(0.78, 0.82, 0.7, 0.75) if rod != "apis" else Color(0.9, 0.82, 0.62, 0.75))
	hint_box.add_child(hint_title)
	out["hint_title"] = hint_title

	var hint_label := Label.new()
	hint_label.name = "HintLabel"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bf := STheme.body_font()
	if bf:
		hint_label.add_theme_font_override("font", bf)
	hint_label.add_theme_font_size_override("font_size", 17)
	hint_label.add_theme_color_override("font_color", Color(0.92, 0.95, 0.88, 0.98) if rod != "apis" else Color(0.97, 0.93, 0.82, 0.98))
	hint_box.add_child(hint_label)
	out["hint_label"] = hint_label

	## Hide legacy bare Guide if present (replaced by HintPanel).
	var legacy := hud.get_node_or_null("Diegetic")
	if legacy:
		legacy.visible = false

	## --- Tooltip (follows cursor / object) ---
	var tip := PanelContainer.new()
	tip.name = "TooltipPanel"
	tip.theme = theme
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.visible = false
	tip.z_index = 20
	layer.add_child(tip)
	out["tooltip"] = tip

	var tip_box := VBoxContainer.new()
	tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.add_child(tip_box)

	var tip_title := Label.new()
	tip_title.name = "TipTitle"
	if tf:
		tip_title.add_theme_font_override("font", tf)
	tip_title.add_theme_font_size_override("font_size", 15)
	tip_title.add_theme_color_override("font_color", Color(0.95, 0.96, 0.9, 1.0))
	tip_box.add_child(tip_title)
	out["tip_title"] = tip_title

	var tip_body := Label.new()
	tip_body.name = "TipBody"
	tip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_body.custom_minimum_size = Vector2(220, 0)
	if bf:
		tip_body.add_theme_font_override("font", bf)
	tip_body.add_theme_font_size_override("font_size", 13)
	tip_body.add_theme_color_override("font_color", Color(0.82, 0.86, 0.78, 0.92))
	tip_box.add_child(tip_body)
	out["tip_body"] = tip_body

	## --- Ending overlay ---
	var end := PanelContainer.new()
	end.name = "EndPanel"
	end.theme = theme
	end.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end.set_anchors_preset(Control.PRESET_CENTER)
	end.anchor_left = 0.5
	end.anchor_right = 0.5
	end.anchor_top = 0.5
	end.anchor_bottom = 0.5
	end.offset_left = -260.0
	end.offset_right = 260.0
	end.offset_top = -160.0
	end.offset_bottom = 180.0
	end.visible = false
	end.modulate.a = 0.0
	layer.add_child(end)
	out["end"] = end

	var end_box := VBoxContainer.new()
	end_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_box.add_theme_constant_override("separation", 6)
	end.add_child(end_box)

	var end_title := Label.new()
	end_title.name = "EndTitle"
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title.text = "SWARM"
	if tf:
		end_title.add_theme_font_override("font", tf)
	end_title.add_theme_font_size_override("font_size", 28)
	end_title.add_theme_color_override("font_color", Color(0.95, 0.94, 0.86, 1.0))
	end_box.add_child(end_title)
	out["end_title"] = end_title

	var end_sub := Label.new()
	end_sub.name = "EndSub"
	end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_sub.text = "Orbit"
	if bf:
		end_sub.add_theme_font_override("font", bf)
	end_sub.add_theme_font_size_override("font_size", 14)
	end_sub.add_theme_color_override("font_color", Color(0.78, 0.82, 0.72, 0.9))
	end_box.add_child(end_sub)
	out["end_sub"] = end_sub

	var end_stats := Label.new()
	end_stats.name = "EndStats"
	end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if bf:
		end_stats.add_theme_font_override("font", bf)
	end_stats.add_theme_font_size_override("font_size", 15)
	end_stats.add_theme_color_override("font_color", Color(0.9, 0.92, 0.86, 0.95))
	end_box.add_child(end_stats)
	out["end_stats"] = end_stats

	return out


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
	## Soft fade near the cutoff.
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
	if nodes.has("tip_title"):
		(nodes["tip_title"] as Label).text = str(info.get("title", ""))
	if nodes.has("tip_body"):
		(nodes["tip_body"] as Label).text = str(info.get("body", ""))
	## Keep panel on-screen.
	var vp := tip.get_viewport_rect().size
	var sz := tip.get_combined_minimum_size()
	if sz.x < 200.0:
		sz.x = 240.0
	if sz.y < 60.0:
		sz.y = 72.0
	var x := clampf(screen_pos.x + 18.0, 8.0, maxf(8.0, vp.x - sz.x - 8.0))
	var y := clampf(screen_pos.y + 18.0, 8.0, maxf(8.0, vp.y - sz.y - 8.0))
	tip.position = Vector2(x, y)
	tip.size = sz


static func refresh_ending(nodes: Dictionary, rod: String, orbit_t: float, stats_lines: Array) -> void:
	if not nodes.has("end"):
		return
	var end: PanelContainer = nodes["end"]
	var show := orbit_t > 0.35
	end.visible = show
	if not show:
		return
	end.modulate.a = clampf((orbit_t - 0.35) / 1.2, 0.0, 1.0)
	if nodes.has("end_title"):
		(nodes["end_title"] as Label).text = "SWARM"
	if nodes.has("end_sub"):
		(nodes["end_sub"] as Label).text = "Apis — orbit" if rod == "apis" else "Mycelium — orbit"
	if nodes.has("end_stats"):
		var body := ""
		for line in stats_lines:
			if body != "":
				body += "\n"
			body += str(line)
		(nodes["end_stats"] as Label).text = body


static func fmt_clock(t: float) -> String:
	var m := int(floor(t / 60.0))
	var s := int(floor(fmod(maxf(0.0, t), 60.0)))
	return "%d:%02d" % [m, s]


static func mycelium_stats(m: Dictionary) -> Array:
	return [
		"Čas běhu  %s" % fmt_clock(float(m.get("time", 0.0))),
		"Kotvy  %d" % int(m.get("anchors", 0)),
		"Segmenty  %d" % int(m.get("segs", 0)),
		"Dělníci  %d" % int(m.get("workers", 0)),
		"Špičky  %d" % int(m.get("tips", 0)),
	]


static func apis_stats(m: Dictionary) -> Array:
	return [
		"Čas běhu  %s" % fmt_clock(float(m.get("time", 0.0))),
		"Komory  %d" % int(m.get("chambers", 0)),
		"Dělnice  %d" % int(m.get("workers", 0)),
		"Trasy  %d" % int(m.get("routes", 0)),
		"Vosk  %.0f%%" % (float(m.get("wax", 0.0)) * 100.0),
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
	## Buildable empty neighbor cells.
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
