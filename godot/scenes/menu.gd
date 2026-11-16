## Build #9–#10 main menu — title → rod choice (+ continue / volume) → dive.
extends Node2D

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

const COL_BG := Color(0.02, 0.03, 0.05)
const COL_APIS := Color(0.92, 0.72, 0.28)
const COL_MYC := Color(0.35, 0.72, 0.48)
const COL_LOGO := Color(0.88, 0.9, 0.86)


func _ready() -> void:
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
	_load_persist()
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
	var base := 78.0 if phase == Phase.TITLE else 110.0
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


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), COL_BG)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(90):
		var sx: float = fmod(rng.randf() * vp.x + t * (4.0 + float(i % 5)), vp.x)
		var sy: float = rng.randf() * vp.y
		var a: float = 0.25 + 0.55 * abs(sin(t * 0.7 + float(i)))
		draw_circle(Vector2(sx, sy), 1.0 + float(i % 2), Color(1, 1, 1, a * 0.5))

	var centers := _planet_centers()
	_draw_planet(centers.apis, _planet_radius("apis"), COL_APIS, grown.apis, "APIS", phase != Phase.TITLE)
	_draw_planet(centers.mycelium, _planet_radius("mycelium"), COL_MYC, grown.mycelium, "MYCELIUM", phase != Phase.TITLE)

	var logo_y: float = 56.0 if phase != Phase.TITLE else vp.y * 0.18
	_draw_logo(Vector2(vp.x * 0.5, logo_y), 1.0 if phase != Phase.DIVE else maxf(0.0, 1.0 - dive_t))

	if phase == Phase.CHOOSE:
		_draw_volume_icon(_volume_pos())
		if continue_available:
			_draw_continue_icon(_continue_pos(), continue_hover)

	if phase == Phase.DIVE:
		var wash := Color(COL_APIS.r, COL_APIS.g, COL_APIS.b, dive_t * 0.55) if dive_rod == "apis" \
			else Color(COL_MYC.r, COL_MYC.g, COL_MYC.b, dive_t * 0.55)
		draw_rect(Rect2(Vector2.ZERO, vp), wash)


func _draw_logo(at: Vector2, alpha: float) -> void:
	if alpha <= 0.02:
		return
	var col := Color(COL_LOGO.r, COL_LOGO.g, COL_LOGO.b, alpha)
	draw_arc(at + Vector2(-70, 0), 10.0, 0, TAU, 20, col, 2.0)
	draw_arc(at + Vector2(-52, 0), 7.0, 0, TAU, 16, col, 1.5)
	draw_string(ThemeDB.fallback_font, at + Vector2(-30, 6), "SWARM", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, col)


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
	draw_circle(c, r * 1.18, Color(col.r, col.g, col.b, 0.12))
	draw_circle(c, r, col.darkened(0.35))
	draw_circle(c + Vector2(-r * 0.22, -r * 0.18), r * 0.72, col.lightened(0.08))
	for i in range(4):
		var yy: float = -r * 0.55 + float(i) * r * 0.35
		draw_line(c + Vector2(-r * 0.7, yy), c + Vector2(r * 0.7, yy * 0.9), Color(col.r, col.g, col.b, 0.25), 2.0)
	if has_grown:
		var blink: float = 0.55 + 0.45 * abs(sin(t * 3.0))
		draw_circle(c + Vector2(0, -r * 0.15), r * 0.18, Color(1, 1, 0.85, blink))
		draw_arc(c + Vector2(0, -r * 0.15), r * 0.28, 0, TAU, 20, Color(1, 1, 0.9, blink * 0.7), 1.5)
	if show_label and phase != Phase.DIVE:
		var lc := Color(0.9, 0.92, 0.88, 0.9)
		draw_string(ThemeDB.fallback_font, c + Vector2(-40, r + 28), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, lc)
