## Build #9–#12 main menu — branded title → rod choice → dive.
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
var pro: Dictionary = {}
var _title_font: Font
var _body_font: Font

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
	if "--menu=choose" in args or "menu=choose" in args:
		phase = Phase.CHOOSE
	_load_persist()
	if capture_out != "":
		phase = Phase.CHOOSE
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


func _continue_pos() -> Vector2:
	var vp := get_viewport_rect().size
	return Vector2(vp.x * 0.5, vp.y - 56.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mp := (event as InputEventMouseMotion).position
		hover = _hit_rod(mp)
		continue_hover = continue_available and phase == Phase.CHOOSE and mp.distance_to(_continue_pos()) < 28.0
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if phase == Phase.TITLE:
			phase = Phase.CHOOSE
			return
		if phase == Phase.CHOOSE:
			if mb.position.distance_to(_volume_pos()) < 22.0:
				SwarmAudio.cycle_volume()
				SwarmAudio.set_ambient("menu" if hover == "" else hover)
				return
			if continue_available and mb.position.distance_to(_continue_pos()) < 28.0:
				_do_continue()
				return
			var rod := _hit_rod(mb.position)
			if rod != "":
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
	_draw_planet(centers.apis, _planet_radius("apis"), COL_APIS, grown.apis, "APIS", phase != Phase.TITLE)
	_draw_planet(centers.mycelium, _planet_radius("mycelium"), COL_MYC, grown.mycelium, "MYCELIUM", phase != Phase.TITLE)

	var logo_y: float = 56.0 if phase != Phase.TITLE else vp.y * 0.18
	_draw_logo(Vector2(vp.x * 0.5, logo_y), 1.0 if phase != Phase.DIVE else maxf(0.0, 1.0 - dive_t))

	if phase == Phase.CHOOSE:
		_draw_volume_icon(_volume_pos())
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
	draw_arc(ic, 14.0, 0, TAU, 24, Color(0.75, 0.78, 0.72, 0.7), 1.5)
	if vol < 0.05:
		draw_line(ic + Vector2(-8, -8), ic + Vector2(8, 8), Color(0.85, 0.4, 0.35, 0.85), 2.0)
	else:
		draw_circle(ic, 3.5, Color(0.8, 0.82, 0.75, 0.85))
		## Arc fill shows level (no text).
		var sweep: float = TAU * clampf(vol, 0.0, 1.0)
		draw_arc(ic, 9.0, -PI * 0.5, -PI * 0.5 + sweep, 18, Color(0.85, 0.88, 0.8, 0.9), 2.0)


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


func _draw_planet(c: Vector2, r: float, col: Color, has_grown: bool, label: String, show_label: bool) -> void:
	## menu_dual already paints both planets — never re-blit full menu panels (rectangular insets).
	## Hover = soft ring + wash; dive title uses procedural sphere if no dual bg.
	var hot: bool = hover == label.to_lower()
	var dual_bg: bool = ProArt.has(pro, "menu_choose") or ProArt.has(pro, "menu_dual")
	if phase == Phase.CHOOSE and dual_bg:
		if hot:
			draw_circle(c, r * 1.12, Color(col.r, col.g, col.b, 0.14))
			draw_arc(c, r * 1.02, 0, TAU, 64, Color(col.r, col.g, col.b, 0.95), 3.0)
			draw_arc(c, r * 0.92, 0, TAU, 48, Color(1, 1, 1, 0.35), 1.4)
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
		var blink: float = 0.55 + 0.45 * abs(sin(t * 3.0))
		draw_circle(c + Vector2(0, -r * 0.15), r * 0.18, Color(1, 1, 0.85, blink))
		draw_arc(c + Vector2(0, -r * 0.15), r * 0.28, 0, TAU, 20, Color(1, 1, 0.9, blink * 0.7), 1.5)
	if show_label and phase != Phase.DIVE:
		var lc := Color(0.92, 0.94, 0.88, 0.95 if hot else 0.85)
		var font: Font = _title_font if _title_font else ThemeDB.fallback_font
		draw_string(font, c + Vector2(-42, r + 28), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, lc)
