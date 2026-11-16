## Build #9–#12 main menu — branded title → rod choice → dive.
## Build #18 — graphics settings + keybind help.
extends Node2D

const ProArt = preload("res://ui/pro_art.gd")
const STheme = preload("res://ui/swarm_theme.gd")

enum Phase { TITLE, CHOOSE, DIVE }

var phase: int = Phase.TITLE
var t: float = 0.0
var dive_t: float = 0.0
var selected: String = ""
var hover: String = ""
var grown: Dictionary = {"apis": false, "mycelium": false}
var dive_rod: String = ""
var continue_available: bool = false
var continue_rod: String = ""
var continue_hover: bool = false
var vol_drag: bool = false
var _prev_hover: String = ""
var _prev_continue_hover: bool = false
var pro: Dictionary = {}
var _title_font: Font
var _body_font: Font
var settings_open: bool = false
var help_open: bool = false
var gfx: Dictionary = {}
var settings_hover: String = "" ## "gear" | "quality" | "resolution" | "fullscreen" | "close" | ""

const COL_BG := Color(0.04, 0.05, 0.06)
const COL_APIS := Color(0.92, 0.72, 0.28)
const COL_MYC := Color(0.35, 0.72, 0.48)
const COL_LOGO := Color(0.92, 0.94, 0.88)


func _ready() -> void:
	RenderingServer.set_default_clear_color(COL_BG)
	pro = ProArt.load_all()
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_title_font = STheme.title_font()
	_body_font = STheme.body_font()
	gfx = SwarmGfx.load_gfx()
	SwarmGfx.apply(gfx)
	var args = OS.get_cmdline_user_args()
	if "--sim" in args or "sim" in args:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	for a in args:
		var s := str(a)
		if s.begins_with("--rod=") or s.begins_with("rod="):
			var rod := s.get_slice("=", 1).to_lower()
			_start_dive(rod)
			return
	## Capture harness: jump straight to choose screen / save PNG.
	var capture_out := ""
	for a3 in args:
		var s3 := str(a3)
		if s3.begins_with("--capture-out="):
			capture_out = s3.substr(14)
		## Desktop / capture: grown=apis|mycelium mirrors web query + MVP return.
		if s3.begins_with("--grown=") or s3.begins_with("grown="):
			var g := s3.get_slice("=", 1).to_lower()
			if g == "apis":
				grown.apis = true
			elif g == "mycelium":
				grown.mycelium = true
	if "--menu=choose" in args or "menu=choose" in args:
		phase = Phase.CHOOSE
	_load_persist()
	## Cmdline grown flags win over empty save (capture / return stills).
	for a4 in args:
		var s4 := str(a4)
		if s4.begins_with("--grown=") or s4.begins_with("grown="):
			var g2 := s4.get_slice("=", 1).to_lower()
			if g2 == "apis":
				grown.apis = true
			elif g2 == "mycelium":
				grown.mycelium = true
	if capture_out != "":
		phase = Phase.CHOOSE
		## Let invite / grown blink settle one beat before PNG.
		t = 1.35
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		if img:
			img.save_png(capture_out)
			print("capture_saved ", capture_out)
		get_tree().quit()
		return
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		var js = Engine.get_singleton("JavaScriptBridge")
		var q: String = str(js.eval("window.location.search || ''"))
		if "rod=apis" in q.to_lower():
			_start_dive("apis")
			return
		if "rod=mycelium" in q.to_lower():
			_start_dive("mycelium")
			return
		if "grown=apis" in q.to_lower():
			grown.apis = true
			phase = Phase.CHOOSE
		elif "grown=mycelium" in q.to_lower():
			grown.mycelium = true
			phase = Phase.CHOOSE
		if "menu=1" in q.to_lower() or "menu=choose" in q.to_lower():
			phase = Phase.CHOOSE
		if "continue=1" in q.to_lower() and continue_available:
			_do_continue()
			return
	if get_tree().has_meta("swarm_grown_apis"):
		grown.apis = bool(get_tree().get_meta("swarm_grown_apis"))
	if get_tree().has_meta("swarm_grown_mycelium"):
		grown.mycelium = bool(get_tree().get_meta("swarm_grown_mycelium"))
	if get_tree().has_meta("swarm_return_choose") and bool(get_tree().get_meta("swarm_return_choose")):
		phase = Phase.CHOOSE
		get_tree().set_meta("swarm_return_choose", false)
	SwarmAudio.set_ambient("menu")


func _load_persist() -> void:
	var d: Dictionary = SwarmSave.load_all()
	grown = {
		"apis": bool(d.grown.get("apis", false)),
		"mycelium": bool(d.grown.get("mycelium", false)),
	}
	continue_available = SwarmSave.has_continue()
	continue_rod = str(d.rod) if continue_available else ""
	get_tree().set_meta("swarm_grown_apis", grown.apis)
	get_tree().set_meta("swarm_grown_mycelium", grown.mycelium)


func _process(dt: float) -> void:
	t += dt
	if phase == Phase.DIVE:
		dive_t += dt
		if dive_t >= 1.15:
			_enter_rod(dive_rod)
			return
	## Planet hover cues ambient blend.
	if phase == Phase.CHOOSE:
		if hover == "apis":
			SwarmAudio.set_ambient("apis")
		elif hover == "mycelium":
			SwarmAudio.set_ambient("mycelium")
		else:
			SwarmAudio.set_ambient("menu")
	queue_redraw()


func _planet_centers() -> Dictionary:
	var vp := get_viewport_rect().size
	var mid := vp * 0.5
	match phase:
		Phase.TITLE:
			return {
				"apis": mid + Vector2(-90.0 + sin(t * 0.15) * 8.0, 20.0 + cos(t * 0.12) * 6.0),
				"mycelium": mid + Vector2(95.0 + cos(t * 0.13) * 8.0, -10.0 + sin(t * 0.11) * 6.0),
			}
		Phase.CHOOSE, Phase.DIVE:
			return {
				"apis": Vector2(vp.x * 0.28, mid.y + 10.0),
				"mycelium": Vector2(vp.x * 0.72, mid.y + 10.0),
			}
	return {"apis": mid, "mycelium": mid}


func _planet_radius(rod: String) -> float:
	var base := 96.0 if phase == Phase.TITLE else 138.0
	if phase == Phase.DIVE and dive_rod == rod:
		return base * (1.0 + dive_t * 2.8)
	if hover == rod and phase == Phase.CHOOSE:
		return base * 1.12
	return base


func _hit_rod(pos: Vector2) -> String:
	if phase != Phase.CHOOSE:
		return ""
	var c := _planet_centers()
	for rod in ["apis", "mycelium"]:
		if pos.distance_to(c[rod]) <= _planet_radius(rod) * 1.05:
			return rod
	return ""


func _volume_pos() -> Vector2:
	var vp := get_viewport_rect().size
	return Vector2(vp.x - 36.0, 36.0)


func _volume_slider_rect() -> Rect2:
	## Track to the left of the volume icon.
	var ic := _volume_pos()
	return Rect2(ic.x - 118.0, ic.y - 8.0, 88.0, 16.0)


func _volume_hit(pos: Vector2) -> bool:
	if pos.distance_to(_volume_pos()) < 22.0:
		return true
	return _volume_slider_rect().grow(6.0).has_point(pos)


func _set_volume_from_x(x: float) -> void:
	var r := _volume_slider_rect()
	var u: float = clampf((x - r.position.x) / maxf(1.0, r.size.x), 0.0, 1.0)
	SwarmAudio.set_volume(u)
	SwarmAudio.set_ambient("menu" if hover == "" else hover)


func _gear_pos() -> Vector2:
	## Left of volume slider so icons don't overlap the track.
	var vp := get_viewport_rect().size
	return Vector2(vp.x - 190.0, 36.0)


func _help_pos() -> Vector2:
	var vp := get_viewport_rect().size
	return Vector2(vp.x - 232.0, 36.0)


func _continue_pos() -> Vector2:
	var vp := get_viewport_rect().size
	return Vector2(vp.x * 0.5, vp.y - 56.0)


func _settings_panel() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp.x * 0.5 - 200.0, vp.y * 0.5 - 140.0, 400.0, 280.0)


func _settings_row_rect(i: int) -> Rect2:
	var p := _settings_panel()
	return Rect2(p.position.x + 24.0, p.position.y + 72.0 + float(i) * 44.0, p.size.x - 48.0, 36.0)


func _hit_settings(mp: Vector2) -> String:
	if not settings_open:
		return ""
	var p := _settings_panel()
	if not p.has_point(mp):
		return "outside"
	if Rect2(p.position + Vector2(p.size.x - 40.0, 12.0), Vector2(28, 28)).has_point(mp):
		return "close"
	if _settings_row_rect(0).has_point(mp):
		return "quality"
	if _settings_row_rect(1).has_point(mp):
		return "resolution"
	if _settings_row_rect(2).has_point(mp):
		return "fullscreen"
	return "panel"


func _persist_gfx() -> void:
	SwarmGfx.save_gfx(str(gfx.quality), str(gfx.resolution), bool(gfx.fullscreen))
	SwarmGfx.apply(gfx)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k == KEY_ESCAPE:
			if help_open:
				help_open = false
				return
			if settings_open:
				settings_open = false
				return
		if k == KEY_H or k == KEY_SLASH:
			if settings_open:
				settings_open = false
			help_open = not help_open
			return
	if event is InputEventMouseMotion:
		var mp := (event as InputEventMouseMotion).position
		if settings_open:
			settings_hover = _hit_settings(mp)
			hover = ""
			continue_hover = false
			return
		if vol_drag and phase == Phase.CHOOSE:
			_set_volume_from_x(mp.x)
			return
		hover = _hit_rod(mp)
		continue_hover = continue_available and phase == Phase.CHOOSE and mp.distance_to(_continue_pos()) < 28.0
		settings_hover = ""
		if mp.distance_to(_gear_pos()) < 20.0:
			settings_hover = "gear"
		elif mp.distance_to(_help_pos()) < 20.0:
			settings_hover = "help"
		if phase == Phase.CHOOSE:
			if hover != _prev_hover and hover != "":
				SwarmAudio.play_ui("hover")
			elif continue_hover and not _prev_continue_hover:
				SwarmAudio.play_ui("hover")
			elif settings_hover != "" and settings_hover != _prev_hover:
				SwarmAudio.play_ui("hover")
		_prev_hover = hover if hover != "" else settings_hover
		_prev_continue_hover = continue_hover
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if not mb.pressed:
			vol_drag = false
			return
		if help_open:
			help_open = false
			return
		if settings_open:
			var hit := _hit_settings(mb.position)
			match hit:
				"close", "outside":
					settings_open = false
				"quality":
					gfx.quality = SwarmGfx.cycle_quality(str(gfx.quality))
					_persist_gfx()
				"resolution":
					gfx.resolution = SwarmGfx.cycle_resolution(str(gfx.resolution))
					_persist_gfx()
				"fullscreen":
					gfx.fullscreen = not bool(gfx.fullscreen)
					_persist_gfx()
			return
		if phase == Phase.TITLE:
			SwarmAudio.play_ui("click")
			phase = Phase.CHOOSE
			return
		if phase == Phase.CHOOSE:
			if _volume_hit(mb.position):
				vol_drag = true
				if mb.position.distance_to(_volume_pos()) < 22.0 and not _volume_slider_rect().has_point(mb.position):
					## Icon tap still cycles for one-handed mute.
					SwarmAudio.cycle_volume()
					SwarmAudio.play_ui("tick")
				else:
					_set_volume_from_x(mb.position.x)
					SwarmAudio.play_ui("tick")
				SwarmAudio.set_ambient("menu" if hover == "" else hover)
				return
			if mb.position.distance_to(_gear_pos()) < 22.0:
				SwarmAudio.play_ui("click")
				settings_open = true
				help_open = false
				return
			if mb.position.distance_to(_help_pos()) < 22.0:
				SwarmAudio.play_ui("click")
				help_open = true
				settings_open = false
				return
			if continue_available and mb.position.distance_to(_continue_pos()) < 28.0:
				SwarmAudio.play_ui("click")
				_do_continue()
				return
			var rod := _hit_rod(mb.position)
			if rod != "":
				SwarmAudio.play_ui("click")
				## Fresh run for chosen rod.
				get_tree().set_meta("swarm_continue", false)
				_start_dive(rod)


func _do_continue() -> void:
	if not continue_available:
		return
	get_tree().set_meta("swarm_continue", true)
	_start_dive(continue_rod)


func _start_dive(rod: String) -> void:
	if rod != "apis" and rod != "mycelium":
		rod = "mycelium"
	selected = rod
	dive_rod = rod
	phase = Phase.DIVE
	dive_t = 0.0
	SwarmAudio.set_ambient(rod)
	SwarmAudio.play_soft("gesture")


func _enter_rod(rod: String) -> void:
	get_tree().set_meta("swarm_from_menu", true)
	var resuming := get_tree().has_meta("swarm_continue") and bool(get_tree().get_meta("swarm_continue"))
	if not resuming:
		## New run — drop stale continue until first autosave.
		SwarmSave.clear_progress()
	if rod == "apis":
		get_tree().change_scene_to_file("res://scenes/apis_main.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _draw_cover(tex: Texture2D, vp: Vector2) -> void:
	## Full-bleed cover (crop edges) — no letterbox bars.
	var ts: Vector2 = tex.get_size()
	if ts.x <= 1.0 or ts.y <= 1.0:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, vp), false)
		return
	var sc: float = maxf(vp.x / ts.x, vp.y / ts.y)
	var sz: Vector2 = ts * sc
	var origin: Vector2 = (vp - sz) * 0.5
	draw_texture_rect(tex, Rect2(origin, sz), false)


func _draw() -> void:
	var vp := get_viewport_rect().size
	## Painted menu backgrounds from pro_v3 — full-bleed cover.
	var bg_key := "menu_title"
	if phase == Phase.CHOOSE:
		bg_key = "menu_choose"
	elif phase == Phase.DIVE:
		bg_key = "menu_apis" if dive_rod == "apis" else "menu_mycelium"
	var bg: Texture2D = ProArt.tex(pro, bg_key)
	if bg == null:
		bg = ProArt.tex(pro, "menu_bg")
	if bg != null:
		_draw_cover(bg, vp)
	else:
		draw_rect(Rect2(Vector2.ZERO, vp), COL_BG)
		draw_circle(vp * 0.5 + Vector2(-120, 40), 220.0, Color(0.55, 0.35, 0.12, 0.12))
		draw_circle(vp * 0.5 + Vector2(140, -30), 240.0, Color(0.15, 0.4, 0.28, 0.14))
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		for i in range(70):
			var sx: float = fmod(rng.randf() * vp.x + t * (4.0 + float(i % 5)), vp.x)
			var sy: float = rng.randf() * vp.y
			var a: float = 0.2 + 0.45 * abs(sin(t * 0.7 + float(i)))
			draw_circle(Vector2(sx, sy), 1.0 + float(i % 2), Color(1, 1, 1, a * 0.4))

	var centers := _planet_centers()
	## MVP return / Dva úly: faint mycelium thread when one Rod matured.
	if phase == Phase.CHOOSE and (grown.apis or grown.mycelium) and not (grown.apis and grown.mycelium):
		_draw_dual_invite_link(centers.apis, centers.mycelium)
	_draw_planet(centers.apis, _planet_radius("apis"), COL_APIS, grown.apis, "APIS", phase != Phase.TITLE)
	_draw_planet(centers.mycelium, _planet_radius("mycelium"), COL_MYC, grown.mycelium, "MYCELIUM", phase != Phase.TITLE)

	var logo_y: float = 56.0 if phase != Phase.TITLE else vp.y * 0.18
	_draw_logo(Vector2(vp.x * 0.5, logo_y), 1.0 if phase != Phase.DIVE else maxf(0.0, 1.0 - dive_t))

	if phase == Phase.CHOOSE:
		_draw_volume_icon(_volume_pos())
		_draw_gear_icon(_gear_pos(), settings_hover == "gear" or settings_open)
		_draw_help_icon(_help_pos(), settings_hover == "help" or help_open)
		if continue_available:
			_draw_continue_icon(_continue_pos(), continue_hover)
		## Branded rod icons — brighten on hover.
		if ProArt.has(pro, "icon_apis"):
			var ia: float = 1.0 if hover == "apis" else 0.82
			ProArt.blit(self, pro, "icon_apis", centers.apis + Vector2(0, _planet_radius("apis") + 52.0), 0.38 if hover == "apis" else 0.34, Color(1, 1, 1, ia))
		if ProArt.has(pro, "icon_mycelium"):
			var im: float = 1.0 if hover == "mycelium" else 0.82
			ProArt.blit(self, pro, "icon_mycelium", centers.mycelium + Vector2(0, _planet_radius("mycelium") + 52.0), 0.38 if hover == "mycelium" else 0.34, Color(1, 1, 1, im))

	if phase == Phase.DIVE:
		var wash := Color(COL_APIS.r, COL_APIS.g, COL_APIS.b, dive_t * 0.55) if dive_rod == "apis" \
			else Color(COL_MYC.r, COL_MYC.g, COL_MYC.b, dive_t * 0.55)
		draw_rect(Rect2(Vector2.ZERO, vp), wash)

	if settings_open:
		_draw_settings_panel()
	if help_open:
		SwarmGfx.draw_help(self, _body_font if _body_font else _title_font, vp)


func _draw_logo(at: Vector2, alpha: float) -> void:
	if alpha <= 0.02:
		return
	var col := Color(COL_LOGO.r, COL_LOGO.g, COL_LOGO.b, alpha)
	if ProArt.has(pro, "logo"):
		ProArt.blit(self, pro, "logo", at, 0.42 if phase == Phase.TITLE else 0.32, Color(1, 1, 1, alpha))
		return
	if ProArt.has(pro, "swarm_logo"):
		ProArt.blit(self, pro, "swarm_logo", at, 0.55, Color(1, 1, 1, alpha))
		return
	draw_arc(at + Vector2(-78, 0), 11.0, 0, TAU, 22, col, 2.2)
	draw_arc(at + Vector2(-58, 0), 7.5, 0, TAU, 18, col, 1.6)
	var font: Font = _title_font if _title_font else ThemeDB.fallback_font
	draw_string(font, at + Vector2(-36, 8), "SWARM", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, col)


func _draw_volume_icon(ic: Vector2) -> void:
	var vol: float = 0.0 if SwarmAudio.muted else SwarmAudio.volume
	var track := _volume_slider_rect()
	## Slider track + fill.
	draw_rect(track, Color(0.12, 0.14, 0.12, 0.55))
	draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(vol, 0.0, 1.0), track.size.y)), Color(0.72, 0.82, 0.68, 0.75))
	draw_arc(track.position + Vector2(track.size.x * clampf(vol, 0.0, 1.0), track.size.y * 0.5), 6.0, 0, TAU, 16, Color(0.88, 0.92, 0.84, 0.95), 1.6)
	draw_arc(ic, 14.0, 0, TAU, 24, Color(0.75, 0.78, 0.72, 0.7), 1.5)
	if vol < 0.05:
		draw_line(ic + Vector2(-8, -8), ic + Vector2(8, 8), Color(0.85, 0.4, 0.35, 0.85), 2.0)
	else:
		draw_circle(ic, 3.5, Color(0.8, 0.82, 0.75, 0.85))
		## Arc fill shows level (no text).
		var sweep: float = TAU * clampf(vol, 0.0, 1.0)
		draw_arc(ic, 9.0, -PI * 0.5, -PI * 0.5 + sweep, 18, Color(0.85, 0.88, 0.8, 0.9), 2.0)


func _draw_gear_icon(ic: Vector2, hot: bool) -> void:
	var a: float = 0.95 if hot else 0.7
	var col := Color(0.8, 0.84, 0.76, a)
	draw_arc(ic, 14.0, 0, TAU, 24, col, 1.5)
	draw_arc(ic, 7.0, 0, TAU, 18, col, 1.6)
	for i in range(6):
		var ang: float = float(i) * TAU / 6.0
		var a0 := ic + Vector2(cos(ang), sin(ang)) * 9.0
		var a1 := ic + Vector2(cos(ang), sin(ang)) * 13.0
		draw_line(a0, a1, col, 2.0)


func _draw_help_icon(ic: Vector2, hot: bool) -> void:
	var a: float = 0.95 if hot else 0.7
	var col := Color(0.8, 0.84, 0.76, a)
	draw_arc(ic, 14.0, 0, TAU, 24, col, 1.5)
	var font: Font = _body_font if _body_font else ThemeDB.fallback_font
	draw_string(font, ic + Vector2(-5, 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)


func _draw_settings_panel() -> void:
	var p := _settings_panel()
	var font: Font = _body_font if _body_font else ThemeDB.fallback_font
	var title: Font = _title_font if _title_font else font
	draw_rect(p, Color(0.05, 0.06, 0.05, 0.88), true)
	draw_rect(p, Color(0.75, 0.8, 0.7, 0.55), false, 1.5)
	draw_string(title, p.position + Vector2(24, 36), "Nastavení", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.92, 0.94, 0.88))
	draw_string(font, p.position + Vector2(p.size.x - 30, 34), "×", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.85, 0.5, 0.45) if settings_hover == "close" else Color(0.7, 0.74, 0.68))
	var rows := [
		{"key": "quality", "label": "Grafika", "value": SwarmGfx.quality_label(str(gfx.quality))},
		{"key": "resolution", "label": "Rozlišení", "value": SwarmGfx.resolution_label(str(gfx.resolution))},
		{"key": "fullscreen", "label": "Celá obrazovka", "value": "Ano" if bool(gfx.fullscreen) else "Ne"},
	]
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var rr := _settings_row_rect(i)
		var hot: bool = settings_hover == str(row.key)
		draw_rect(rr, Color(0.12, 0.14, 0.12, 0.75 if hot else 0.45), true)
		draw_string(font, rr.position + Vector2(12, 24), str(row.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.82, 0.86, 0.8))
		draw_string(font, rr.position + Vector2(rr.size.x - 120, 24), str(row.value), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.9, 0.7) if hot else Color(0.88, 0.9, 0.84))
	draw_string(font, p.position + Vector2(24, p.size.y - 22), "Kliknutím přepneš · H = ovládání", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.65, 0.58, 0.8))


func _draw_continue_icon(at: Vector2, hot: bool) -> void:
	## Play/resume triangle — no text wall.
	var a: float = 0.95 if hot else 0.7
	var col := Color(0.88, 0.9, 0.84, a)
	draw_arc(at, 22.0, 0, TAU, 28, col, 1.6)
	var tri := PackedVector2Array([
		at + Vector2(-6, -10),
		at + Vector2(-6, 10),
		at + Vector2(12, 0),
	])
	draw_colored_polygon(tri, col)


func _draw_dual_invite_link(a: Vector2, b: Vector2) -> void:
	## Soft mycelium hint between matured Rod and the inviting other planet.
	var mid: Vector2 = (a + b) * 0.5 + Vector2(0, -36.0 + sin(t * 1.4) * 6.0)
	var alpha: float = 0.22 + 0.18 * abs(sin(t * 1.6))
	var steps := 10
	for i in range(1, steps + 1):
		var u0: float = float(i - 1) / float(steps)
		var u1: float = float(i) / float(steps)
		var p0: Vector2 = a.lerp(b, u0) + (mid - (a + b) * 0.5) * sin(u0 * PI)
		var p1: Vector2 = a.lerp(b, u1) + (mid - (a + b) * 0.5) * sin(u1 * PI)
		var c: Color = COL_APIS.lerp(COL_MYC, u1)
		c.a = alpha * (0.45 + 0.55 * sin(u1 * PI))
		draw_line(p0, p1, c, 1.6, true)
	var mote_u: float = fmod(t * 0.28, 1.0)
	var mote: Vector2 = a.lerp(b, mote_u) + (mid - (a + b) * 0.5) * sin(mote_u * PI)
	draw_circle(mote, 2.8, Color(0.95, 1.05, 0.7, alpha + 0.25))


func _draw_planet(c: Vector2, r: float, col: Color, has_grown: bool, label: String, show_label: bool) -> void:
	## menu_dual already paints both planets — never re-blit full menu panels (rectangular insets).
	## Hover = soft ring + wash; dive title uses procedural sphere if no dual bg.
	var rod_key: String = label.to_lower()
	var hot: bool = hover == rod_key
	## After MVP: ungrown planet invites play (breathing rings) while grown carries organism.
	var other_grown: bool = bool(grown.mycelium) if rod_key == "apis" else bool(grown.apis)
	var inviting: bool = phase == Phase.CHOOSE and not has_grown and other_grown
	var dual_bg: bool = ProArt.has(pro, "menu_choose") or ProArt.has(pro, "menu_dual")
	var invite_pulse: float = 0.55 + 0.45 * abs(sin(t * 2.4))
	if phase == Phase.CHOOSE and dual_bg:
		if hot or inviting:
			var wash_a: float = 0.14 if hot else 0.08 + 0.06 * invite_pulse
			draw_circle(c, r * (1.12 + (0.06 * invite_pulse if inviting else 0.0)), Color(col.r, col.g, col.b, wash_a))
			draw_arc(c, r * 1.02, 0, TAU, 64, Color(col.r, col.g, col.b, 0.95 if hot else 0.55 + 0.4 * invite_pulse), 3.0)
			draw_arc(c, r * 0.92, 0, TAU, 48, Color(1, 1, 1, 0.35 if hot else 0.18 + 0.2 * invite_pulse), 1.4)
			if inviting:
				draw_arc(c, r * (1.18 + 0.08 * invite_pulse), 0, TAU, 48, Color(col.r, col.g, col.b, 0.28 * invite_pulse), 1.5)
		else:
			draw_arc(c, r, 0, TAU, 48, Color(col.r, col.g, col.b, 0.35), 1.5)
	elif ProArt.has(pro, "menu_apis" if label == "APIS" else "menu_mycelium") and phase != Phase.CHOOSE:
		## Title / dive only — circular soft plate, not full UI panel.
		draw_circle(c, r * 1.05, Color(col.r, col.g, col.b, 0.22 if hot else 0.12))
		draw_arc(c, r, 0, TAU, 48, Color(col.r, col.g, col.b, 0.7 if hot else 0.45), 2.2)
	else:
		draw_circle(c, r * 1.18, Color(col.r, col.g, col.b, 0.14))
		draw_circle(c, r, col.darkened(0.35))
		draw_circle(c + Vector2(-r * 0.22, -r * 0.18), r * 0.72, col.lightened(0.08))
		draw_arc(c, r, 0, TAU, 48, Color(col.r, col.g, col.b, 0.55 if hot else 0.35), 2.0)
	if has_grown:
		## Grown organism on player's planet — pro_v3 kukla / tobolka blink (scenar_10-15 return).
		var blink: float = 0.55 + 0.45 * abs(sin(t * 3.0))
		var org_at := c + Vector2(0, -r * 0.08)
		var org_key := "apis_royal_cell" if rod_key == "apis" else "myc_seed_capsule"
		if ProArt.has(pro, org_key):
			## Pivot is foot-biased — sit the organism on the planet crown.
			var osc: float = 0.26 + 0.04 * blink
			draw_circle(org_at + Vector2(0, -18.0), r * 0.22, Color(1.0, 0.95, 0.7, 0.16 + 0.14 * blink))
			ProArt.blit(self, pro, org_key, org_at, osc, Color(1.2, 1.12, 0.92, 0.7 + 0.3 * blink))
			draw_arc(org_at + Vector2(0, -22.0), r * 0.36, 0, TAU, 28, Color(1, 1, 0.9, blink * 0.65), 1.6)
		else:
			draw_circle(org_at, r * 0.18, Color(1, 1, 0.85, blink))
			draw_arc(org_at, r * 0.28, 0, TAU, 20, Color(1, 1, 0.9, blink * 0.7), 1.5)
	if show_label and phase != Phase.DIVE:
		var lc := Color(0.92, 0.94, 0.88, 0.95 if hot or inviting else 0.85)
		var font: Font = _title_font if _title_font else ThemeDB.fallback_font
		draw_string(font, c + Vector2(-42, r + 28), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, lc)
