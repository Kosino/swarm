## Isometric Mycelium — Build 12 pro art (seamless ground, atmosphere, branded UI).
## Build #18 — draw budget / settings / keybind help.
extends Node2D

const C = preload("res://mycelium/config.gd")
const Iso = preload("res://mycelium/iso.gd")
const Atlas = preload("res://mycelium/iso_atlas.gd")
const Atm = preload("res://ui/atmosphere.gd")
const ProArt = preload("res://ui/pro_art.gd")
const STheme = preload("res://ui/swarm_theme.gd")
const Juice = preload("res://ui/juice.gd")
const Diegetic = preload("res://ui/diegetic.gd")

@onready var camera: Camera2D = $Camera2D
@onready var world_root: Node2D = $WorldRoot
@onready var hyphae: Node2D = $WorldRoot/Hyphae
@onready var objects: Node2D = $WorldRoot/Objects
@onready var hud: CanvasLayer = $HUD
@onready var clock_label: Label = $HUD/Panel/VBox/Clock
@onready var next_label: Label = $HUD/Panel/VBox/Next
@onready var wow_label: Label = $HUD/Panel/VBox/Wow
@onready var speed_label: Label = $HUD/Panel/VBox/Speed
@onready var guide_label: Label = $HUD/Diegetic/Guide

var world: MyceliumWorld
var demo_on: bool = false
var speed_mul: float = 1.0
var speed_idx: int = 0
const SPEEDS := [1.0, 2.0, 4.0, 8.0]
## 128×64 soil diamond covers SOIL_TILE=64 iso spacing at scale 1.0; slight overlap kills seams.
const TILE_SC_1X := 1.08
const TILE_SC_2X := 0.54

var panning: bool = false
var pan_last: Vector2 = Vector2.ZERO
var zoom_target: float = 1.0
var atlas: Dictionary = {}
var sequences: Dictionary = {}
var pro: Dictionary = {}
var _atm: Dictionary = {}
var _die: Dictionary = {}
var _drag: bool = false
var _use_2x: bool = false
var _orbit_done: bool = false
var _other_planet_a: float = 0.0
var _autosave_cd: float = 60.0
var _run_seed: int = 42
var _fx: Array = [] ## {seq, x, y, t, life}
var _juice: Array = [] ## placement pop / ripple / float text
var _prev_pulse: float = 0.0
var _prev_bright: float = 0.0
var _prev_anchors: int = 0
var _prev_workers: int = 0
var _prev_mite_alive: bool = false
var _prev_mite_purged: bool = false
var _had_seed: bool = false
var _seen_rings: int = 0
var help_open: bool = false
var _view: Rect2 = Rect2()
var _body_font: Font
var _help_draw: Node2D
var _hover_info: Dictionary = {}
var _mouse_screen: Vector2 = Vector2.ZERO
var _capture_tooltip: bool = false


func _resolve_rod() -> String:
	var args = OS.get_cmdline_user_args()
	for a in args:
		var s := str(a)
		if s.begins_with("--rod="):
			return s.substr(6).to_lower()
		if s.begins_with("rod="):
			return s.substr(4).to_lower()
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		var js = Engine.get_singleton("JavaScriptBridge")
		var q: String = str(js.eval("window.location.search || ''"))
		if "rod=apis" in q.to_lower():
			return "apis"
		if "rod=mycelium" in q.to_lower():
			return "mycelium"
	return "mycelium"


func _ready() -> void:
	## Only auto-route to Apis when this scene is the entry (CLI/web ?rod=), not from menu.
	var from_menu := get_tree().has_meta("swarm_from_menu") and bool(get_tree().get_meta("swarm_from_menu"))
	if not from_menu:
		var rod := _resolve_rod()
		if rod == "apis":
			get_tree().call_deferred("change_scene_to_file", "res://scenes/apis_main.tscn")
			return
	else:
		get_tree().set_meta("swarm_from_menu", false)
	var args = OS.get_cmdline_user_args()
	if "--sim" in args or "sim" in args:
		_run_sim_and_quit()
		return
	if "--demo" in args or "demo" in args:
		demo_on = true
	## Diegetic default — debug HUD only via F1 (also on web).
	SwarmGfx.apply()
	_body_font = STheme.body_font()
	_setup_help_layer()

	_use_2x = DisplayServer.screen_get_scale() >= 1.5
	atlas = Atlas.load_all(_use_2x)
	sequences = Atlas.load_sequences(_use_2x)
	_run_seed = 42
	var opts := {"silent": false, "seed": _run_seed}
	var resume_t: float = -1.0
	var capture_at: float = -1.0
	var capture_out := ""
	for a2 in args:
		var s2 := str(a2)
		if s2.begins_with("--capture-at="):
			capture_at = float(s2.substr(13))
		if s2.begins_with("--capture-out="):
			capture_out = s2.substr(14)
		if s2 == "--capture-tooltip" or s2 == "capture-tooltip":
			_capture_tooltip = true
	pro = ProArt.load_all(_use_2x)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if get_tree().has_meta("swarm_continue") and bool(get_tree().get_meta("swarm_continue")):
		get_tree().set_meta("swarm_continue", false)
		var sav: Dictionary = SwarmSave.load_all()
		if str(sav.rod) == "mycelium":
			_run_seed = int(sav.seed)
			opts["seed"] = _run_seed
			resume_t = float(sav.time)
			if resume_t >= C.START10_T - 5.0:
				opts["startAt"] = 600.0
			elif resume_t >= C.START5_T - 5.0:
				opts["startAt"] = 280.0
	elif "--start=10" in args or "start=10" in args:
		opts["startAt"] = 600.0
	if capture_at >= 0.0:
		opts["silent"] = true
		if capture_at >= C.START10_T - 5.0:
			opts["startAt"] = 600.0
		elif capture_at >= C.START5_T - 5.0:
			opts["startAt"] = 280.0
	world = MyceliumWorld.new(opts)
	if resume_t > world.time:
		_catch_up(resume_t)
	if capture_at >= 0.0:
		var Bot = preload("res://tools/capture_bot.gd")
		Bot.advance_mycelium(world, capture_at)
		demo_on = false
		## Snap to world growth zoom (progress/time in MyceliumWorld.update) — no capture-only override.
		world.cam_zoom = world.cam_zoom_target
	SwarmAudio.set_ambient("mycelium")
	_atm = Atm.apply(self, "mycelium", camera, hud)
	## Diegetic chrome always on; debug Panel only via F1 / --demo.
	hud.visible = true
	_die = Diegetic.mount(hud, "mycelium")
	Diegetic.set_debug_visible(_die, demo_on)
	_had_seed = world.seed != null
	_prev_anchors = _count_anchors()
	_prev_workers = world.workers.size()
	_prev_mite_alive = world.mite_nest != null and not world.mite_purged
	_prev_mite_purged = world.mite_purged
	_seen_rings = world.rings.size()
	camera.position = Iso.world_to_iso(_nest().x, _nest().y)
	zoom_target = 1.0
	camera.zoom = Vector2(zoom_target * world.cam_zoom, zoom_target * world.cam_zoom)
	Atm.sync_light(_atm, camera.position)
	Atm.sync_particles(_atm, camera.position)
	Atm.set_myc_day(_atm, clampf(world.network_bright * 0.65 + world.network_pulse * 0.25, 0.0, 1.0))
	_refresh_hud()
	queue_redraw()
	if capture_at >= 0.0 and capture_out != "":
		## Capture-only: Age 3 holds rarely complete under autoplay — force ending chrome for stills.
		if capture_at >= 890.0 and world.mvp_end_time == null:
			world._trigger_mvp_end()
		if world.mvp_end_time != null:
			world.orbit_t = maxf(world.orbit_t, 3.2)
			_other_planet_a = 1.0
			world.cam_zoom = world.cam_zoom_target
			camera.zoom = Vector2(zoom_target * world.cam_zoom, zoom_target * world.cam_zoom)
		if _capture_tooltip:
			_force_capture_tooltip()
		_refresh_hud()
		queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		print("capture_time_verify myc t=", world.time, " segs=", world.segs.size(), " tips=", world.tips.size(), " bright=", world.network_bright, " reach=", _visual_reach(), " orbit=", world.orbit_t, " end=", world.mvp_end_time != null)
		var img: Image = get_viewport().get_texture().get_image()
		if img:
			img.save_png(capture_out)
			print("capture_saved ", capture_out)
		get_tree().quit()


func _setup_help_layer() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HelpOverlay"
	layer.layer = 90
	_help_draw = Node2D.new()
	_help_draw.name = "HelpDraw"
	_help_draw.set_script(load("res://ui/help_overlay.gd"))
	layer.add_child(_help_draw)
	add_child(layer)


func _set_help(open: bool) -> void:
	help_open = open
	if _help_draw and _help_draw.has_method("set_open"):
		_help_draw.call("set_open", open)


func _catch_up(target: float) -> void:
	var silent_was: bool = world._silent
	world._silent = true
	var guard := 0
	while world.time < target - 0.05 and guard < 200000:
		world.update(minf(1.0 / 12.0, target - world.time))
		guard += 1
	world._silent = silent_was


func _autosave(force: bool = false) -> void:
	if world == null or world.mvp_end_time != null:
		return
	SwarmSave.save_progress("mycelium", float(world.time), _run_seed)


func _return_menu(grown_flag: bool = false) -> void:
	_autosave(true)
	if grown_flag:
		get_tree().set_meta("swarm_grown_mycelium", true)
		SwarmSave.save_progress("mycelium", 900.0, _run_seed, {"mycelium": true})
		SwarmSave.clear_progress()
	get_tree().set_meta("swarm_return_choose", true)
	SwarmAudio.set_ambient("menu")
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _run_sim_and_quit() -> void:
	var runner := MyceliumHeadless.new()
	var result := runner.run()
	print(JSON.stringify(result, "\t"))
	get_tree().quit(0 if result.get("ok", false) else 1)


func _process(dt: float) -> void:
	if world == null:
		return
	world.update(dt * speed_mul)
	_autosave_cd -= dt
	if _autosave_cd <= 0.0:
		_autosave_cd = 60.0
		_autosave()
	_tick_fx(dt)

	if world.mvp_end_time != null:
		_other_planet_a = minf(1.0, _other_planet_a + dt * 0.35)
		if world.orbit_t > Diegetic.ORBIT_HOLD and not _orbit_done:
			_orbit_done = true
			_return_menu(true)
			return
	else:
		var move := Vector2.ZERO
		if Input.is_action_pressed("cam_left"):
			move.x -= 1
		if Input.is_action_pressed("cam_right"):
			move.x += 1
		if Input.is_action_pressed("cam_up"):
			move.y -= 1
		if Input.is_action_pressed("cam_down"):
			move.y += 1
		if move != Vector2.ZERO:
			camera.position += move.normalized() * 420.0 * dt / maxf(camera.zoom.x, 0.2)

	var z: float = zoom_target * world.cam_zoom
	## Soft easing — no hard snaps at growth thresholds.
	camera.zoom = camera.zoom.lerp(Vector2(z, z), 1.0 - exp(-dt * 1.55))
	var nest_iso := Iso.world_to_iso(_nest().x, _nest().y)
	var glow_e: float = 0.38 + world.network_bright * 0.28 + world.network_pulse * 0.2
	Atm.sync_light(_atm, nest_iso, glow_e)
	Atm.sync_particles(_atm, nest_iso)
	Atm.set_myc_day(_atm, clampf(world.network_bright * 0.65 + world.network_pulse * 0.25, 0.0, 1.0))
	_refresh_hud()
	queue_redraw()


func _refresh_hud() -> void:
	var g = world.guidance()
	var label := str(g.get("label", ""))
	guide_label.text = label
	var force_hint := world.mvp_end_time == null and (world.time < Diegetic.HINT_UNTIL or _capture_tooltip)
	Diegetic.refresh_hint(_die, float(world.time), label, force_hint and world.time < Diegetic.HINT_UNTIL)
	if world.mvp_end_time != null:
		Diegetic.refresh_tooltip(_die, {}, _mouse_screen)
		Diegetic.refresh_ending(_die, "mycelium", float(world.orbit_t), Diegetic.mycelium_stats(world.metrics()))
	else:
		Diegetic.refresh_ending(_die, "mycelium", 0.0, [])
		Diegetic.refresh_tooltip(_die, _hover_info, _mouse_screen)
	if not demo_on:
		return
	var m = world.metrics()
	clock_label.text = _fmt_clock(float(m.time))
	speed_label.text = "Rychlost: %.0f×" % speed_mul
	next_label.text = "Dál: %s" % label
	var wows = world.poll_wows()
	if wows.size() > 0:
		wow_label.text = str(wows[wows.size() - 1].label)
		wow_label.modulate.a = 1.0
	else:
		wow_label.modulate.a = maxf(0.0, wow_label.modulate.a - 0.4 * get_process_delta_time())


func _fmt_clock(t: float) -> String:
	return Diegetic.fmt_clock(t)


func _force_capture_tooltip() -> void:
	## Prefer an unlit nutrient patch for a readable still.
	for p in world.patches:
		if p.get("big", false):
			continue
		_hover_info = {
			"title": "Skvrna živin" if not p.on else "Kotva",
			"body": "Doveď špičku hyfy sem a ukotvi." if not p.on else "Už propojená skvrna živin.",
		}
		var iso := Iso.world_to_iso(p.x, p.y)
		_mouse_screen = get_viewport().get_canvas_transform() * iso
		return
	_hover_info = {"title": "Zárodek", "body": "Srdce sítě. Táhni hyfy ven ke skvrnám."}
	_mouse_screen = Vector2(640, 280)


func _unhandled_input(event: InputEvent) -> void:
	if world == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k == KEY_ESCAPE:
			if help_open:
				_set_help(false)
				return
			_return_menu(false)
			return
		if k == KEY_H or k == KEY_SLASH:
			_set_help(not help_open)
			return
	if event.is_action_pressed("toggle_demo"):
		demo_on = not demo_on
		Diegetic.set_debug_visible(_die, demo_on)
		return
	if demo_on and event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				speed_idx = 0
				speed_mul = SPEEDS[0]
			KEY_2:
				speed_idx = 1
				speed_mul = SPEEDS[1]
			KEY_3:
				speed_idx = 2
				speed_mul = SPEEDS[2]
			KEY_4:
				speed_idx = 3
				speed_mul = SPEEDS[3]
			KEY_SPACE:
				get_tree().paused = not get_tree().paused

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_target = minf(2.5, zoom_target * 1.1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_target = maxf(0.35, zoom_target / 1.1)
		elif mb.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			panning = mb.pressed
			pan_last = mb.position
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			var wpos := _screen_to_world(mb.position)
			if mb.pressed:
				_drag = true
				_hover_info = {}
				world.note_pointer()
				world.pointer_down(wpos.x, wpos.y)
			else:
				_drag = false
				world.pointer_up()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_mouse_screen = mm.position
		if panning:
			var delta: Vector2 = mm.position - pan_last
			pan_last = mm.position
			camera.position -= delta / camera.zoom.x
		elif _drag:
			var wpos2 := _screen_to_world(mm.position)
			world.note_pointer()
			world.pointer_move(wpos2.x, wpos2.y)
			_hover_info = {}
		elif world.mvp_end_time == null:
			var wpos3 := _screen_to_world(mm.position)
			_hover_info = Diegetic.inspect_mycelium(world, wpos3.x, wpos3.y)


func _screen_to_world(screen: Vector2) -> Vector2:
	var canvas: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen
	return Iso.iso_to_world(canvas.x, canvas.y)


func _nest() -> Vector2:
	if world.seed != null:
		return Vector2(world.seed.x, world.seed.y)
	return Vector2(float(C.W) * 0.5, float(C.H) * 0.5)


func _visual_reach() -> float:
	## Stronger time/seg growth so soil stages read clearly from 0:30 → 15:00.
	var base: float = 70.0 + float(world.segs.size()) * 0.14 + world.time * 0.32
	if world.big_anchored:
		base += 90.0
	if world.join_time != null:
		base += 70.0
	if world.network_bright > 0.4:
		base += 40.0
	return clampf(base, 70.0, 560.0)


func _terrain_stage(wx: float, wy: float) -> String:
	var nest := _nest()
	var d: float = nest.distance_to(Vector2(wx, wy))
	var reach: float = _visual_reach()
	if d > reach * 1.05:
		return "pusta"
	if d > reach * 0.52:
		return "prorostla"
	return "ziva"


func _th_name(th: int) -> String:
	if th <= 0:
		return "tenka"
	if th == 1:
		return "stredni"
	return "silna"


func _count_anchors() -> int:
	var n: int = 0
	for p in world.patches:
		if p.on:
			n += 1
	return n


func _spawn_fx(seq: String, x: float, y: float, life: float = 1.0) -> void:
	if not sequences.has(seq):
		return
	_fx.append({"seq": seq, "x": x, "y": y, "t": 0.0, "life": life})


func _tick_fx(dt: float) -> void:
	## Rising pulse / wow → kapka + spóra bursts + ripple juice.
	if world.network_pulse > _prev_pulse + 0.35:
		var nest := _nest()
		_spawn_fx("myc2_fx_kapka", nest.x, nest.y, 1.0)
		_spawn_fx("myc2_fx_spora", nest.x + 12.0, nest.y - 8.0, 1.15)
		Juice.spawn_ripple(_juice, nest.x, nest.y, true, Color(0.55, 0.92, 0.7, 0.75))
	if world.network_bright > _prev_bright + 0.45:
		for p in world.patches:
			if p.on and (p.lit > 0.55 or p.get("big", false)):
				_spawn_fx("myc2_fx_spora", p.x, p.y, 1.2)
				break
	## Seed placement pop (covers resume/catch-up silence via _had_seed).
	if world.seed != null and not _had_seed:
		_had_seed = true
		Juice.spawn_pop(_juice, world.seed.x, world.seed.y, Color(0.65, 0.95, 0.72, 0.95))
		Juice.spawn_ripple(_juice, world.seed.x, world.seed.y, false, Color(0.5, 0.85, 0.65, 0.65))
	elif world.seed != null:
		_had_seed = true
	## New world rings → subtle ripples (world already owns timing).
	if world.rings.size() > _seen_rings:
		for ri in range(_seen_rings, world.rings.size()):
			var rg: Dictionary = world.rings[ri]
			Juice.spawn_ripple(_juice, float(rg.x), float(rg.y), bool(rg.get("big", false)), Color(0.5, 0.88, 0.68, 0.55))
	_seen_rings = world.rings.size()
	## Resource ticks — anchors / workers floating +N.
	var anchors: int = _count_anchors()
	if anchors > _prev_anchors:
		var ax: float = _nest().x
		var ay: float = _nest().y
		for p2 in world.patches:
			if p2.on:
				ax = float(p2.x)
				ay = float(p2.y)
		Juice.spawn_float(_juice, ax, ay, "+anchor", Color(0.75, 0.95, 0.7, 0.95))
		Juice.spawn_pop(_juice, ax, ay, Color(0.7, 0.95, 0.72, 0.8), 0.35)
	_prev_anchors = anchors
	var workers: int = world.workers.size()
	if workers > _prev_workers:
		Juice.spawn_float(_juice, _nest().x, _nest().y - 10.0, "+%d" % (workers - _prev_workers), Color(0.85, 0.95, 0.78, 0.9))
		## Spore-crawler spawn puff (art_drop myc2_fx_spora).
		_spawn_fx("myc2_fx_spora", _nest().x + 6.0, _nest().y - 4.0, 0.85)
	_prev_workers = workers
	## Mite invasion hit / death VFX — art_drop kapka + spora sequences.
	var mite_alive: bool = world.mite_nest != null and not world.mite_purged and world.quarantine_time == null
	if mite_alive and not _prev_mite_alive and world.mite_nest != null:
		var nest_h: Dictionary = world.mite_nest
		_spawn_fx("myc2_fx_kapka", float(nest_h.x), float(nest_h.y), 1.05)
		_spawn_fx("myc2_fx_spora", float(nest_h.x) + 10.0, float(nest_h.y) - 6.0, 1.1)
		Juice.spawn_ripple(_juice, float(nest_h.x), float(nest_h.y), true, Color(0.55, 0.5, 0.35, 0.7))
		Juice.spawn_pop(_juice, float(nest_h.x), float(nest_h.y), Color(0.7, 0.55, 0.35, 0.9), 0.4)
		for mite_h in world.mites:
			_spawn_fx("myc2_fx_spora", float(mite_h.x), float(mite_h.y), 0.7)
	if world.mite_purged and not _prev_mite_purged:
		var nx: float = _nest().x
		var ny: float = _nest().y
		if world.mite_nest != null:
			nx = float(world.mite_nest.x)
			ny = float(world.mite_nest.y)
		_spawn_fx("myc2_fx_kapka", nx, ny, 1.15)
		_spawn_fx("myc2_fx_spora", nx + 8.0, ny - 10.0, 1.25)
		_spawn_fx("myc2_fx_spora", nx - 10.0, ny - 4.0, 1.0)
		Juice.spawn_ripple(_juice, nx, ny, true, Color(0.65, 0.9, 0.55, 0.8))
		Juice.spawn_pop(_juice, nx, ny, Color(0.85, 0.95, 0.7, 0.95), 0.5)
		Juice.spawn_float(_juice, nx, ny - 12.0, "purge", Color(0.8, 0.95, 0.7, 0.95))
	_prev_mite_alive = mite_alive
	_prev_mite_purged = world.mite_purged
	_prev_pulse = world.network_pulse
	_prev_bright = world.network_bright
	var i := _fx.size() - 1
	while i >= 0:
		_fx[i].t += dt
		if _fx[i].t >= _fx[i].life:
			_fx.remove_at(i)
		i -= 1
	Juice.tick(_juice, dt)


func _draw() -> void:
	if world == null:
		return
	_view = SwarmGfx.view_bounds(camera)
	_draw_ground_base()
	_draw_soil()
	_draw_hyphae()
	_draw_entities()
	_draw_fx()
	_draw_juice()
	_draw_edge_fog()
	_draw_guidance()


func _tile_sc() -> float:
	return TILE_SC_2X if _use_2x else TILE_SC_1X


func _hash2(ix: int, iy: int) -> float:
	var n: int = ix * 374761393 + iy * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return float(n & 0xffff) / 65535.0


func _draw_tex_cell(tex: Texture2D, center: Vector2, cell: float, rot: float, modulate: Color) -> void:
	if tex == null or modulate.a <= 0.01:
		return
	draw_set_transform(center, rot, Vector2.ONE)
	var half := cell * 0.5
	draw_texture_rect(tex, Rect2(-half, -half, cell, cell), true, modulate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_ground_base() -> void:
	## Soil-stage growth: hola → prorostla → sparse zarici wash (readable 0:30→15:00).
	var c := Iso.world_to_iso(float(C.W) * 0.5, float(C.H) * 0.5)
	var hw: float = float(C.W) * 1.55
	var hh: float = float(C.H) * 1.05
	draw_colored_polygon(_diamond_at(c, hw * 1.55, hh * 1.55), Color(0.08, 0.1, 0.055, 1.0))
	var t_hola: Texture2D = ProArt.tex(pro, "myc_tex_puda_hola")
	var t_pro: Texture2D = ProArt.tex(pro, "myc_tex_puda_prorostla")
	var t_zar: Texture2D = ProArt.tex(pro, "myc_tex_puda_zarici")
	if t_hola != null:
		var reach: float = _visual_reach()
		var fill := Rect2(c.x - 2200.0, c.y - 1400.0, 4400.0, 2800.0)
		## Early = bare soil; mid = prorostla; late = soft zarici only near nest.
		var base: Texture2D = t_hola
		if reach > 140.0 and t_pro != null:
			base = t_pro
		draw_texture_rect(base, fill, true)
		var cell: float = 480.0
		var step: float = 240.0 * SwarmGfx.ground_overlay_step_mul()
		var x0: float = c.x - 2200.0
		var y0: float = c.y - 1400.0
		var nx: int = int(ceil(4400.0 / step)) + 1
		var ny: int = int(ceil(2800.0 / step)) + 1
		var nest_iso := Iso.world_to_iso(_nest().x, _nest().y)
		var ql: int = SwarmGfx.q_level()
		for iy in range(ny):
			for ix in range(nx):
				var cx: float = x0 + float(ix) * step + cell * 0.5
				var cy: float = y0 + float(iy) * step + cell * 0.5
				if not SwarmGfx.iso_in_view(Vector2(cx, cy), _view):
					continue
				var h0: float = _hash2(ix, iy)
				var rot: float = float(int(h0 * 4.0) % 4) * PI * 0.5
				var d_iso: float = Vector2(cx, cy).distance_to(nest_iso)
				if t_pro != null and base == t_hola and reach > 100.0 and h0 > 0.4:
					_draw_tex_cell(t_pro, Vector2(cx, cy), cell, rot, Color(1, 1, 1, 0.2 + 0.12 * h0))
				if ql < 2 and t_hola != null and base != t_hola and _hash2(ix + 3, iy + 5) > 0.6:
					_draw_tex_cell(t_hola, Vector2(cx, cy), cell * 0.9, rot + PI * 0.5, Color(1, 1, 1, 0.14))
				## Late-game living soil wash — very soft, rotated, near nest only (no hatch carpet).
				if ql == 0 and t_zar != null and reach > 280.0 and d_iso < 380.0 and world.network_bright > 0.2 and h0 > 0.72:
					var a: float = 0.05 + 0.07 * world.network_bright * (1.0 - clampf(d_iso / 380.0, 0.0, 1.0))
					_draw_tex_cell(t_zar, Vector2(cx, cy), cell * 0.7, rot + PI, Color(1, 1, 1, a))
	else:
		draw_colored_polygon(_diamond_at(c, hw, hh), Color(0.14, 0.18, 0.1, 1.0))
	_draw_ground_decals()


func _blit(name: String, world_x: float, world_y: float, scale: float = 1.0, modulate: Color = Color.WHITE, extra_off: Vector2 = Vector2.ZERO) -> void:
	if not atlas.has(name):
		return
	var entry: Dictionary = atlas[name]
	var tex: Texture2D = entry.texture
	var off: Vector2 = entry.offset
	var iso: Vector2 = Iso.world_to_iso(world_x, world_y) + extra_off
	var sz: Vector2 = tex.get_size() * scale
	var dest := Rect2(iso + off * scale, sz)
	draw_texture_rect(tex, dest, false, modulate)


func _draw_soil() -> void:
	## Sparse atlas variation on seamless fill — avoid a hard rectangular soil patch.
	var cols: int = world.soil_cols
	var rows: int = world.soil_rows
	var tile: float = float(C.SOIL_TILE)
	var sc: float = _tile_sc()
	var has_fill: bool = ProArt.has(pro, "myc_tex_puda_hola")
	var sparse_mod: int = SwarmGfx.soil_sparse_mod()
	for ty in range(rows):
		for tx in range(cols):
			## Sparse soil stage sprites — keep pusta/prorostla/ziva readable over time (no prorust hatch).
			if has_fill and ((tx * 5 + ty * 11) % sparse_mod) != 0:
				continue
			var wx: float = (float(tx) + 0.5) * tile
			var wy: float = (float(ty) + 0.5) * tile
			var iso0 := Iso.world_to_iso(wx, wy)
			if not SwarmGfx.iso_in_view(iso0, _view):
				continue
			var idx: int = int(world.soil_tiles[ty * cols + tx]) if ty * cols + tx < world.soil_tiles.size() else 0
			var variant: String = ["a", "b", "c"][clampi(idx, 0, 2)]
			var stage: String = _terrain_stage(wx, wy)
			var n := "myc2_puda_%s_%s" % [stage, variant]
			if atlas.has(n):
				var a: float = 0.18 if has_fill else 1.0
				if stage == "prorostla":
					a = 0.28 if has_fill else 1.0
				elif stage == "ziva":
					a = 0.38 if has_fill else 1.0
				_blit(n, wx, wy, sc, Color(1, 1, 1, a))
			elif not has_fill:
				draw_colored_polygon(_diamond_at(iso0, tile * 0.56, tile * 0.28), Color(0.16 + 0.03 * idx, 0.2 + 0.02 * idx, 0.11, 1.0))
			## No myc2_overlay_prorust — hatch patches stay gone.


func _draw_ground_decals() -> void:
	## Biome detail rings — moss/mushroom near nest, leaf/root mid, stone far. Deterministic.
	var nest := _nest()
	var near_keys := ["myc_decal_houbicka", "myc_decal_kvet_mech", "myc_decal_trs_mech", "myc_decal_hyfa_chomac", "myc_decal_mech_a", "myc_decal_mech_b"]
	var mid_keys := ["myc_decal_listi_a", "myc_decal_listi_b", "myc_decal_koren_a", "myc_decal_koren_b", "myc_decal_mech_a", "myc_decal_trs_mech"]
	var far_keys := ["myc_decal_kamen_a", "myc_decal_kamen_b", "myc_decal_koren_a", "myc_decal_listi_b", "myc_decal_mech_b"]
	var near_p: Array = []
	var mid_p: Array = []
	var far_p: Array = []
	for k in near_keys:
		if ProArt.has(pro, k):
			near_p.append(k)
	for k in mid_keys:
		if ProArt.has(pro, k):
			mid_p.append(k)
	for k in far_keys:
		if ProArt.has(pro, k):
			far_p.append(k)
	if near_p.is_empty() and mid_p.is_empty() and far_p.is_empty():
		return
	var sc: float = 0.44 if not _use_2x else 0.23
	var decal_n: int = SwarmGfx.decal_count() + SwarmGfx.detail_decal_count()
	for i in range(decal_n):
		var ang: float = float(i) * 2.399963 + float(i % 7) * 0.11
		var rad: float = 42.0 + fmod(float(i * 47), 420.0)
		var wx: float = nest.x + cos(ang) * rad + sin(float(i) * 1.7) * 8.0
		var wy: float = nest.y + sin(ang) * rad * 0.72 + cos(float(i) * 1.3) * 6.0
		if wx < -40.0 or wy < -40.0 or wx > float(C.W) + 40.0 or wy > float(C.H) + 40.0:
			continue
		var iso_d := Iso.world_to_iso(wx, wy)
		if not SwarmGfx.iso_in_view(iso_d, _view):
			continue
		var pool: Array = mid_p
		if rad < 140.0 and not near_p.is_empty():
			pool = near_p
		elif rad > 280.0 and not far_p.is_empty():
			pool = far_p
		elif pool.is_empty():
			pool = near_p if not near_p.is_empty() else far_p
		if pool.is_empty():
			continue
		var key: String = pool[i % pool.size()]
		var a: float = 0.62 if i % 5 == 0 else (0.48 if i % 3 == 0 else 0.34)
		var local_sc: float = sc * (0.78 + float(i % 6) * 0.07)
		## Tiny mushrooms read better slightly larger near the nest.
		if key == "myc_decal_houbicka" or key == "myc_decal_kvet_mech":
			local_sc *= 1.12
			a = minf(0.72, a + 0.08)
		ProArt.blit(self, pro, key, iso_d, local_sc, Color(1, 1, 1, a))


func _diamond_at(center: Vector2, half_w: float, half_h: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -half_h),
		center + Vector2(half_w, 0),
		center + Vector2(0, half_h),
		center + Vector2(-half_w, 0),
	])


func _hyfa_dir(dx: float, dy: float) -> String:
	var a := atan2(dy, dx)
	if a >= -PI * 0.25 and a < PI * 0.25:
		return "SE"
	if a >= PI * 0.25 and a < PI * 0.75:
		return "SW"
	if a >= -PI * 0.75 and a < -PI * 0.25:
		return "NE"
	return "NW"


func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


func _resample_catmull(pts: Array, ths: Array, step: float) -> Dictionary:
	## pts/ths are root→tip world points. Returns iso pts + half-widths.
	var out_pts := PackedVector2Array()
	var out_hw := PackedFloat32Array()
	if pts.size() < 2:
		return {"pts": out_pts, "hw": out_hw}
	var n: int = pts.size()
	## Approximate total length for tip taper (last ~60px).
	var total: float = 0.0
	for i in range(1, n):
		total += Vector2(pts[i]).distance_to(Vector2(pts[i - 1]))
	var along: float = 0.0
	for i in range(n - 1):
		var p0: Vector2 = pts[maxi(0, i - 1)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(n - 1, i + 2)]
		var seg_len: float = p1.distance_to(p2)
		var samples: int = maxi(1, int(ceil(seg_len / maxf(step, 4.0))))
		var th_a: float = float(ths[mini(i, ths.size() - 1)]) if ths.size() > 0 else 0.0
		var th_b: float = float(ths[mini(i + 1, ths.size() - 1)]) if ths.size() > 0 else th_a
		for s in range(samples):
			var u: float = float(s) / float(samples)
			var p: Vector2 = _catmull(p0, p1, p2, p3, u)
			## Very slight organic wander — keep ribbon smooth (no jagged hatch).
			var nx: float = sin((along + u * seg_len) * 0.04 + float(i) * 0.9) * 0.9
			var ny: float = cos((along + u * seg_len) * 0.035 + float(i) * 0.7) * 0.7
			p += Vector2(nx, ny)
			var th_u: float = lerpf(th_a, th_b, u)
			var dist_left: float = total - (along + u * seg_len)
			## Width by traffic/thickness; taper last ~60px tendril.
			var hw: float = 1.35 + th_u * 1.85 + world.network_bright * 0.4
			if dist_left < 60.0:
				hw *= clampf(dist_left / 60.0, 0.12, 1.0)
			out_pts.append(Iso.world_to_iso(p.x, p.y))
			out_hw.append(hw)
		along += seg_len
	## Tip endpoint.
	var tip: Vector2 = pts[n - 1]
	out_pts.append(Iso.world_to_iso(tip.x, tip.y))
	out_hw.append(0.55)
	return {"pts": out_pts, "hw": out_hw}


func _draw_ribbon(iso_pts: PackedVector2Array, half_w: PackedFloat32Array, col: Color, width_mul: float = 1.0) -> void:
	if iso_pts.size() < 2 or half_w.size() != iso_pts.size():
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var kept := 0
	var last_iso := Vector2.ZERO
	for i in range(iso_pts.size()):
		var tang: Vector2
		if i == 0:
			tang = (iso_pts[1] - iso_pts[0])
		elif i == iso_pts.size() - 1:
			tang = (iso_pts[i] - iso_pts[i - 1])
		else:
			tang = (iso_pts[i + 1] - iso_pts[i - 1])
		if tang.length_squared() < 0.0001:
			tang = Vector2.RIGHT
		else:
			tang = tang.normalized()
		## Skip near-duplicate samples that collapse the ribbon into a zero-area poly.
		if kept > 0 and iso_pts[i].distance_squared_to(last_iso) < 0.36:
			continue
		var nrm := Vector2(-tang.y, tang.x)
		var hw: float = half_w[i] * width_mul
		left.append(iso_pts[i] + nrm * hw)
		right.append(iso_pts[i] - nrm * hw)
		last_iso = iso_pts[i]
		kept += 1
	if kept < 2:
		return
	var poly := PackedVector2Array()
	for p in left:
		poly.append(p)
	for ri in range(right.size() - 1, -1, -1):
		poly.append(right[ri])
	if poly.size() >= 3:
		draw_colored_polygon(poly, col)


func _hypha_chain_len(pts: Array) -> float:
	var total: float = 0.0
	for i in range(1, pts.size()):
		total += Vector2(pts[i]).distance_to(Vector2(pts[i - 1]))
	return total


func _hypha_mean_th(ths: Array) -> float:
	if ths.is_empty():
		return 0.0
	var s: float = 0.0
	for t in ths:
		s += float(t)
	return s / float(ths.size())


func _draw_hyphae() -> void:
	## Build 14 retune: ~8–15 arteries (6–14px), lime core #e8f25a + olive glow #6f8a2a.
	## Secondaries thinner @ ~40% opacity. SwarmGfx quality/view cull preserved (Build 18).
	var col_olive := Color(0.435, 0.541, 0.165) ## #6f8a2a
	var col_lime := Color(0.910, 0.949, 0.353) ## #e8f25a
	var bright: float = 1.0 + world.network_bright * 0.15
	var hyfa_tex: Texture2D = null
	if SwarmGfx.hyfa_tex_accent():
		if atlas.has("myc2_hyfa_silna_SE"):
			hyfa_tex = atlas["myc2_hyfa_silna_SE"].texture
		elif atlas.has("myc2_hyfa_stredni_SE"):
			hyfa_tex = atlas["myc2_hyfa_stredni_SE"].texture
	var passes: int = SwarmGfx.ribbon_passes()
	var step_r: float = SwarmGfx.ribbon_resample_step()
	## Art budget: 8–15 main arteries + sparse secondaries (never full spaghetti).
	var max_arteries: int = 13
	var max_secondary: int = 6
	if SwarmGfx.q_level() >= 1:
		max_arteries = 11
		max_secondary = 4
	if SwarmGfx.q_level() >= 2:
		max_arteries = 8
		max_secondary = 3
	max_arteries = mini(max_arteries, SwarmGfx.max_hypha_chains())
	## Rank tips by max ancestral thickness so trunks win over fresh tip th=0.
	var tip_order: Array = []
	for ti in range(world.tips.size()):
		var tip0 = world.tips[ti]
		var max_th: int = 0
		var sum_th: int = 0
		var n_th: int = 0
		var s0: int = int(tip0.seg)
		var g0 := 0
		while s0 >= 0 and s0 < world.segs.size() and g0 < 4000:
			g0 += 1
			var thv: int = int(world.segs[s0].th)
			max_th = maxi(max_th, thv)
			sum_th += thv
			n_th += 1
			s0 = int(world.segs[s0].p)
		var mean0: float = float(sum_th) / float(maxi(1, n_th))
		tip_order.append({"i": ti, "th": max_th, "mean": mean0})
	tip_order.sort_custom(func(a, b):
		if int(a.th) != int(b.th):
			return int(a.th) > int(b.th)
		return float(a.mean) > float(b.mean)
	)
	var drawn_arteries := 0
	var drawn_secondary := 0
	var drawn_anchors: Array = []
	for item in tip_order:
		if drawn_arteries >= max_arteries and drawn_secondary >= max_secondary:
			break
		var tip = world.tips[int(item.i)]
		var max_th: int = int(item.th)
		var pts: Array = []
		var ths: Array = []
		pts.append(Vector2(float(tip.x), float(tip.y)))
		var si: int = int(tip.seg)
		var guard := 0
		while si >= 0 and si < world.segs.size() and guard < 4000:
			guard += 1
			var s: Dictionary = world.segs[si]
			pts.append(Vector2(float(s.x1), float(s.y1)))
			ths.append(int(s.th))
			si = int(s.p)
		if pts.size() < 2:
			continue
		## Cull only when the whole chain misses the view.
		var any_in := false
		var stride: int = maxi(1, pts.size() / 8)
		var pi := 0
		while pi < pts.size():
			var pw: Vector2 = pts[pi]
			if SwarmGfx.iso_in_view(Iso.world_to_iso(pw.x, pw.y), _view):
				any_in = true
				break
			pi += stride
		if not any_in:
			continue
		pts.reverse()
		ths.reverse()
		while ths.size() < pts.size() - 1:
			ths.append(0)
		var mean_th: float = _hypha_mean_th(ths)
		var chain_len: float = _hypha_chain_len(pts)
		## Prefer thick/long trunks as arteries so late maps keep ~8–15 readable highways.
		var is_artery: bool = max_th >= 2 or mean_th >= 1.15 or (max_th >= 1 and chain_len > 180.0)
		if is_artery and drawn_arteries >= max_arteries:
			is_artery = false
		if not is_artery and drawn_secondary >= max_secondary:
			continue
		## Merge parallel secondaries into arteries.
		if not is_artery and drawn_anchors.size() > 0:
			var tip_w: Vector2 = Vector2(float(tip.x), float(tip.y))
			var mid_w: Vector2 = pts[pts.size() / 2]
			var near_parallel := false
			for anchors in drawn_anchors:
				for ai in range(anchors.size()):
					var a: Vector2 = anchors[ai]
					if tip_w.distance_squared_to(a) < 42.0 * 42.0 or mid_w.distance_squared_to(a) < 34.0 * 34.0:
						near_parallel = true
						break
				if near_parallel:
					break
			if near_parallel:
				continue
		## Secondaries: only distal third so they don't carpet the map.
		if not is_artery and pts.size() > 8:
			var keep_from: int = int(float(pts.size()) * 0.62)
			pts = pts.slice(keep_from)
			ths = ths.slice(mini(keep_from, ths.size()))
			while ths.size() < pts.size() - 1:
				ths.append(0)
		var sampled: Dictionary = _resample_catmull(pts, ths, step_r if is_artery else step_r * 1.2)
		var iso_pts: PackedVector2Array = sampled.pts
		var half_w: PackedFloat32Array = sampled.hw
		if iso_pts.size() < 2:
			continue
		## Target full width: arteries 6–14px → half_w ≈ 3–7; secondaries thinner.
		for wi in range(half_w.size()):
			if is_artery:
				## Force readable artery width regardless of thin tip samples.
				var t_u: float = float(wi) / float(maxi(1, half_w.size() - 1))
				half_w[wi] = lerpf(6.2, 3.4, t_u) ## root thicker → tip taper within 6–14px full
			else:
				half_w[wi] = clampf(half_w[wi] * 0.9, 1.6, 2.8)
		var fade: float = 1.0 if is_artery else 0.40
		## Olive glow + lime core (additive stack; no cream blowout).
		if passes >= 4:
			_draw_ribbon(iso_pts, half_w, Color(col_olive.r, col_olive.g, col_olive.b, 0.38 * bright * fade), 2.2)
			_draw_ribbon(iso_pts, half_w, Color(col_olive.r, col_olive.g, col_olive.b, 0.32 * bright * fade), 1.45)
			_draw_ribbon(iso_pts, half_w, Color(col_lime.r, col_lime.g, col_lime.b, 0.70 * bright * fade), 0.85)
			_draw_ribbon(iso_pts, half_w, Color(col_lime.r, col_lime.g, col_lime.b, 0.88 * bright * fade), 0.38)
		elif passes >= 2:
			_draw_ribbon(iso_pts, half_w, Color(col_olive.r, col_olive.g, col_olive.b, 0.40 * bright * fade), 2.0)
			_draw_ribbon(iso_pts, half_w, Color(col_lime.r, col_lime.g, col_lime.b, 0.78 * bright * fade), 0.65)
		else:
			_draw_ribbon(iso_pts, half_w, Color(col_olive.r, col_olive.g, col_olive.b, 0.36 * bright * fade), 1.85)
			_draw_ribbon(iso_pts, half_w, Color(col_lime.r, col_lime.g, col_lime.b, 0.82 * bright * fade), 0.75)
		if hyfa_tex != null and is_artery and iso_pts.size() >= 2:
			var mid_i: int = iso_pts.size() / 2
			var mid: Vector2 = iso_pts[mid_i]
			var hw_m: float = half_w[mid_i] * 1.6
			var a: float = 0.14 + 0.08 * world.network_bright
			draw_texture_rect(hyfa_tex, Rect2(mid - Vector2(hw_m * 2.0, hw_m), Vector2(hw_m * 4.0, hw_m * 2.0)), false, Color(col_lime.r, col_lime.g, col_lime.b, a))
		var anchors2 := PackedVector2Array()
		var step_a: int = maxi(1, int(pts.size() / 6))
		for pj in range(0, pts.size(), step_a):
			anchors2.append(pts[pj])
		drawn_anchors.append(anchors2)
		if is_artery:
			drawn_arteries += 1
		else:
			drawn_secondary += 1
	## Sparse organic node accents only (not hatch).
	if SwarmGfx.q_level() < 2 and ProArt.has(pro, "myc_decal_hyfa_chomac"):
		var shown := 0
		var j := 0
		var max_nodes: int = 14 if SwarmGfx.q_level() == 0 else 8
		for s2 in world.segs:
			j += 1
			if int(s2.th) < 2 or (j % 9) != 0:
				continue
			var iso_n := Iso.world_to_iso(s2.x1, s2.y1)
			if not SwarmGfx.iso_in_view(iso_n, _view):
				continue
			ProArt.blit(self, pro, "myc_decal_hyfa_chomac", iso_n, 0.26 if not _use_2x else 0.13, Color(col_lime.r, col_lime.g, col_lime.b, 0.32))
			shown += 1
			if shown > max_nodes:
				break


func _kotva_stage(p: Dictionary) -> String:
	if p.get("big", false) or p.lit > 0.75 or world.network_bright > 0.55:
		return "zariva"
	if p.on and p.lit > 0.25:
		return "dorostla"
	return "rozestavena"


func _node_role(node: Dictionary, fallback: String) -> String:
	return str(node.get("role", fallback))


func _draw_entities() -> void:
	var dim: float = 1.0
	if world.dim_all > 0.0:
		dim = maxf(0.15, 1.0 - world.dim_all * 0.85)
	var mite_grey: float = world.mite_pressure if world.quarantine_time == null else 0.0
	for p in world.patches:
		if not p.on and p.lit < 0.05 and not p.get("big", false):
			continue
		if not SwarmGfx.iso_in_view(Iso.world_to_iso(p.x, p.y), _view):
			continue
		var stage := _kotva_stage(p)
		var prole := _node_role(p, "anchor")
		## Age-3 / late mid-game building variety from existing atlas.
		if prole == "depot":
			stage = "zariva"
		var name := "myc2_kotva_%s" % stage
		## Build 21: taller kotva silhouette (koncept_pokrocila stone-ruin mass).
		var sc := 0.72 if p.get("big", false) else 0.55
		if prole == "depot":
			sc *= 1.18
		if _use_2x:
			sc *= 0.5
		var lift := Vector2(0.0, -6.0 if p.get("big", false) else -3.0)
		if SwarmGfx.soft_shadows():
			_draw_soft_shadow(p.x, p.y, 18.0 if p.get("big", false) else 12.0, 0.26 + p.lit * 0.14)
		var pmod := Color(1, 1, 1, 0.62 + p.lit * 0.35)
		if prole == "depot":
			pmod = pmod.lerp(Color(1.25, 1.15, 0.55, 1.0), 0.35 + p.lit * 0.2)
		if mite_grey > 0.2:
			pmod = pmod.lerp(Color(0.55, 0.6, 0.5, 0.9), mite_grey * 0.25)
		if atlas.has(name):
			_blit(name, p.x, p.y, sc, pmod, lift)
			## Soft zariva bloom only — never prorust hatch overlays.
			if (stage == "zariva" or prole == "depot") and atlas.has("myc2_overlay_zare") and p.lit > 0.55 and SwarmGfx.q_level() == 0:
				_blit("myc2_overlay_zare", p.x, p.y, sc * 0.78, Color(1.15, 1.3, 0.85, 0.12 + p.lit * 0.1), lift + Vector2(0, -4))
		else:
			_draw_box_fallback(p.x, p.y, p.r * 0.7, Color(0.35, 0.7, 0.45, 0.85))

	for m in world.matters:
		var name := ""
		var mrole := _node_role(m, "fruit" if String(m.kind) == "fruit" else String(m.kind))
		match String(m.kind):
			"machine", "beetle":
				## No dedicated v2 husks — reuse plodnice stages as organic overgrowth markers.
				if m.encircled:
					name = "myc2_plodnice_dorostla" if m.decay < 0.55 else "myc2_plodnice_zariva"
				else:
					name = "myc2_plodnice_rozestavena"
			"fruit":
				if mrole == "sporangium" or world.network_bright > 0.5 or world.spore_time != null:
					name = "myc2_plodnice_zariva"
				elif m.encircled or world.fruit_time != null:
					name = "myc2_plodnice_dorostla"
				else:
					name = "myc2_plodnice_rozestavena"
		## Build 21: bulbous plodnice height / depth toward overview 3/4.
		var sc := 0.62
		if mrole == "sporangium":
			sc *= 1.22
		elif String(m.kind) == "fruit":
			sc *= 1.08
		if _use_2x:
			sc *= 0.5
		var alpha := 1.0 - float(m.decay) * 0.35
		var mmod := Color(1, 1, 1, alpha)
		if mrole == "sporangium":
			mmod = mmod.lerp(Color(1.25, 1.4, 0.9, alpha), 0.4)
		if mite_grey > 0.2 and String(m.kind) == "fruit":
			mmod = mmod.lerp(Color(0.6, 0.65, 0.5, alpha), mite_grey * 0.2)
		var mlift := Vector2(0.0, -8.0 if mrole == "sporangium" else -5.0)
		if name != "" and atlas.has(name):
			if SwarmGfx.soft_shadows():
				_draw_soft_shadow(m.x, m.y, 14.0 if mrole == "sporangium" else 11.0, 0.24)
			_blit(name, m.x, m.y, sc, mmod, mlift)
			## Stacked crown for zariva / sporangium — taller overview reading.
			if mrole == "sporangium" or name.ends_with("_zariva"):
				_blit(name, m.x, m.y, sc * 0.72, mmod, mlift + Vector2(0.0, -18.0 if not _use_2x else -9.0))
			if mrole == "sporangium" and atlas.has("myc2_overlay_zare"):
				_blit("myc2_overlay_zare", m.x, m.y - 6.0, sc * 0.85, Color(1.15, 1.35, 0.9, 0.14 + world.network_bright * 0.12), mlift + Vector2(0, -10))
		else:
			_draw_box_fallback(m.x, m.y, m.r * 0.55, Color(0.4, 0.65, 0.45, 0.7 * alpha))

	for g in world.germs:
		var grole := _node_role(g, "germ")
		var gstage := "rozestavena"
		if g.linked or g.lit > 0.4 or grole == "nursery" or grole == "depot":
			gstage = "dorostla"
		if g.lit > 0.75 or world.network_bright > 0.6 or grole == "nursery":
			gstage = "zariva"
		## Depot germs read as nutrient stores via kotva; nursery keeps zarodek.
		var gname := "myc2_zarodek_%s" % gstage
		## Build 21: zárodek / nursery nodes with more stalk height.
		var gsc := 0.32 if not _use_2x else 0.16
		var gmod := Color(0.85, 0.95, 0.8, 0.75 + g.lit * 0.25)
		var glift := Vector2(0.0, -4.0)
		if grole == "depot":
			gname = "myc2_kotva_%s" % ("zariva" if g.lit > 0.6 else "dorostla")
			gsc = 0.42 if not _use_2x else 0.21
			gmod = Color(1.2, 1.1, 0.55, 0.78 + g.lit * 0.22)
			glift = Vector2(0.0, -5.0)
		elif grole == "nursery":
			gsc *= 1.35
			gmod = gmod.lerp(Color(1.05, 1.2, 1.15, 1.0), 0.35 + g.lit * 0.2)
			glift = Vector2(0.0, -6.0)
		if atlas.has(gname):
			if SwarmGfx.soft_shadows():
				_draw_soft_shadow(g.x, g.y, 8.0, 0.18 + g.lit * 0.08)
			_blit(gname, g.x, g.y, gsc, gmod, glift)
			if (grole == "nursery" or grole == "depot") and atlas.has("myc2_overlay_zare"):
				_blit("myc2_overlay_zare", g.x, g.y, gsc * 0.9, Color(1.1, 1.25, 0.95, 0.14 + g.lit * 0.1), glift)
		else:
			draw_circle(Iso.world_to_iso(g.x, g.y), 4.0, Color(0.45, 0.85, 0.55, 0.8))

	if world.seed != null:
		var sstage := "dorostla"
		if world.network_bright > 0.45 or world.big_anchored:
			sstage = "zariva"
		elif world.segs.size() < 40:
			sstage = "rozestavena"
		var sname := "myc2_zarodek_%s" % sstage
		## Central zárodek — taller stalk orb (overview 0-min / core).
		var ssc: float = 0.68 if not _use_2x else 0.34
		if atlas.has(sname):
			if SwarmGfx.soft_shadows():
				_draw_soft_shadow(world.seed.x, world.seed.y, 16.0, 0.28)
			_blit(sname, world.seed.x, world.seed.y, ssc, Color(1.05, 1.15, 0.95, 0.95), Vector2(0, -8))
		else:
			draw_circle(Iso.world_to_iso(world.seed.x, world.seed.y), 6.0, Color(0.5, 0.9, 0.6))

	## Spore crawlers (dělníci) — art_drop iso 3/4; spaced + capped by graphics quality.
	var drawn_workers: Array = []
	var spacing: float = SwarmGfx.worker_spacing()
	var max_w: int = SwarmGfx.max_workers_drawn()
	for w in world.workers:
		if drawn_workers.size() >= max_w:
			break
		var pos = world.worker_pos(w)
		var px: float = float(pos.x)
		var py: float = float(pos.y)
		var iso_w := Iso.world_to_iso(px, py)
		if not SwarmGfx.iso_in_view(iso_w, _view):
			continue
		var too_close := false
		for prev in drawn_workers:
			if Vector2(px, py).distance_to(prev) < spacing:
				too_close = true
				break
		if too_close:
			continue
		## Face along current segment tangent (all 4 dirs).
		var dir := "SE"
		var n: int = w.route.size() if w.has("route") else 0
		if n > 0 and world.segs.size() > 0:
			var fi: float = clampf(float(w.pos), 0.0, float(n) - 1e-6)
			var si: int = clampi(int(floor(fi)), 0, n - 1)
			var seg = world.segs[w.route[si]] if w.route[si] < world.segs.size() else null
			if seg != null:
				var sdx: float = float(seg.x2 - seg.x1) * float(w.dir)
				var sdy: float = float(seg.y2 - seg.y1) * float(w.dir)
				dir = _hyfa_dir(sdx, sdy)
		elif int(w.dir) < 0:
			dir = "NW"
		var carrying: bool = int(w.dir) < 0
		var name := ("myc2_delnik_neseni_%s" if carrying else "myc2_delnik_%s") % dir
		if not atlas.has(name):
			name = "myc2_delnik_SE"
		## 3/4 readable crawler silhouette (was 0.32 translucent dust).
		var wsc: float = 0.58 if not _use_2x else 0.29
		var wlift := Vector2(0.0, -3.0)
		if SwarmGfx.soft_shadows():
			_draw_soft_shadow(px, py, 4.5, 0.18)
		if atlas.has(name):
			var wmod := Color(1.15, 1.35, 0.75, 0.82) if carrying else Color(1.05, 1.25, 0.7, 0.78)
			_blit(name, px, py, wsc, wmod, wlift)
			## Soft spore glint on carrying crawlers.
			if carrying and atlas.has("myc2_overlay_zare") and SwarmGfx.q_level() == 0:
				_blit("myc2_overlay_zare", px, py, wsc * 0.55, Color(1.2, 1.45, 0.7, 0.16), wlift + Vector2(0, -2))
		else:
			draw_circle(iso_w, 2.0, Color(0.85, 1.0, 0.35, 0.7))
		drawn_workers.append(Vector2(px, py))

	if world.stroke_active and world.stroke.size() > 1:
		for i in range(1, world.stroke.size()):
			var a := Iso.world_to_iso(world.stroke[i - 1].x, world.stroke[i - 1].y)
			var b := Iso.world_to_iso(world.stroke[i].x, world.stroke[i].y)
			## Soft guidance stroke — never a neon slash.
			draw_line(a, b, Color(0.55, 0.85, 0.65, 0.28), 1.6, true)

	## Build 13: no matter-site prorust hatch overlays.

	## Mid-game mite enemies (GDD Invaze roztočů) — beetle nest + grey crawler mites, 3/4.
	if world.mite_nest != null and not world.mite_purged and world.quarantine_time == null:
		var nest = world.mite_nest
		var nest_a: float = 0.6 + world.mite_pressure * 0.35
		var nest_sc: float = 0.42 if not _use_2x else 0.21
		var nest_lift := Vector2(0.0, -6.0)
		if SwarmGfx.soft_shadows():
			_draw_soft_shadow(nest.x, nest.y, 16.0, 0.28 + world.mite_pressure * 0.1)
		if ProArt.has(pro, "myc_infected_beetle"):
			ProArt.blit(
				self, pro, "myc_infected_beetle",
				Iso.world_to_iso(nest.x, nest.y) + nest_lift,
				nest_sc,
				Color(0.82, 0.72, 0.5, nest_a)
			)
		elif atlas.has("myc2_plodnice_rozestavena"):
			_blit("myc2_plodnice_rozestavena", nest.x, nest.y, nest_sc, Color(0.55, 0.5, 0.4, nest_a), nest_lift)
		for mite in world.mites:
			## Facing orbit tangent — grey enemy crawlers, shorter than spore dělníci.
			var mph: float = float(mite.get("ph", 0.0))
			var mdir := "SE"
			if cos(mph) < -0.35:
				mdir = "NW"
			elif sin(mph) > 0.35:
				mdir = "NE"
			elif sin(mph) < -0.35:
				mdir = "SW"
			var mname := "myc2_delnik_%s" % mdir
			if not atlas.has(mname):
				mname = "myc2_delnik_SE"
			var msc: float = 0.38 if not _use_2x else 0.19
			var mlift := Vector2(0.0, -2.0)
			var hit_flash: float = 0.12 + 0.1 * abs(sin(world.time * 6.0 + mph))
			if SwarmGfx.soft_shadows():
				_draw_soft_shadow(mite.x, mite.y, 3.5, 0.16)
			if atlas.has(mname):
				_blit(
					mname, mite.x, mite.y, msc,
					Color(0.62 + hit_flash, 0.48, 0.38, 0.72 + world.mite_pressure * 0.22),
					mlift
				)
			else:
				draw_circle(Iso.world_to_iso(mite.x, mite.y), float(mite.r) * 0.45, Color(0.5, 0.45, 0.35, 0.75))

	## Age 3 — pro_v3 sprites (no procedural boxes when pack present).
	if world.infected != null:
		var inf = world.infected
		var ikey := "myc_infected"
		if ProArt.has(pro, "myc_infected_beetle") and int(inf.x * 3.0 + inf.y) % 2 == 0:
			ikey = "myc_infected_beetle"
		if ProArt.has(pro, ikey):
			## Overgrown ruin mass — koncept 15-min silhouette.
			ProArt.blit(self, pro, ikey, Iso.world_to_iso(inf.x, inf.y), 0.72 if not _use_2x else 0.36, Color(1, 1, 1, 0.82 + inf.grey * 0.18))
		elif atlas.has("myc2_plodnice_dorostla"):
			_blit("myc2_plodnice_dorostla", inf.x, inf.y, 0.62 if not _use_2x else 0.31, Color(0.55, 0.7, 0.45, 0.6 + inf.grey * 0.3))
	if world.skeleton != null:
		var sk = world.skeleton
		var alpha: float = 0.85 * (1.0 - float(sk.decay) * 0.45)
		if ProArt.has(pro, "myc_skeleton"):
			## Tall ruin silhouette (koncept_pokrocila background wreck).
			ProArt.blit(self, pro, "myc_skeleton", Iso.world_to_iso(sk.x, sk.y), 0.92 if not _use_2x else 0.46, Color(1.05, 1.02, 0.95, alpha))
		elif atlas.has("myc2_kotva_dorostla"):
			_blit("myc2_kotva_dorostla", sk.x, sk.y, 0.7 if not _use_2x else 0.35, Color(0.75, 0.7, 0.6, alpha))
	if world.giant_fruit != null:
		var gf = world.giant_fruit
		## Build 21: obří plodnice — more 3/4 volume.
		if ProArt.has(pro, "myc_giant_fruit"):
			ProArt.blit(self, pro, "myc_giant_fruit", Iso.world_to_iso(gf.x, gf.y) + Vector2(0, -12), 0.82 + gf.grow * 0.42 if not _use_2x else 0.41 + gf.grow * 0.21, Color(1, 1, 1, 0.92 * dim))
		else:
			var gfn := "myc2_plodnice_zariva" if gf.grow > 0.7 else ("myc2_plodnice_dorostla" if gf.grow > 0.3 else "myc2_plodnice_rozestavena")
			if atlas.has(gfn):
				_blit(gfn, gf.x, gf.y, 0.88 + gf.grow * 0.45 if not _use_2x else 0.44 + gf.grow * 0.22, Color(1.2, 1.25, 1.05, 0.9 * dim), Vector2(0, -12))
	if world.seed_capsule != null:
		var sc = world.seed_capsule
		var glow: float = 0.6 + 0.4 * abs(sin(world.time * 3.2))
		if ProArt.has(pro, "myc_seed_capsule"):
			ProArt.blit(self, pro, "myc_seed_capsule", Iso.world_to_iso(sc.x, sc.y) + Vector2(0, -8), 0.7 if not _use_2x else 0.35, Color(1.15, 1.2, 1.0, glow))
		elif atlas.has("myc2_zarodek_zariva"):
			_blit("myc2_zarodek_zariva", sc.x, sc.y, 0.58 if not _use_2x else 0.29, Color(1.3, 1.35, 1.1, glow), Vector2(0, -8))
	if world.mvp_end_time != null:
		_draw_ending_planet()


func _draw_fx() -> void:
	var sc: float = 0.55 if not _use_2x else 0.28
	for fx in _fx:
		var seq_name: String = fx.seq
		if not sequences.has(seq_name):
			continue
		var seq: Dictionary = sequences[seq_name]
		var frames: Array = seq.get("frames", [])
		if frames.is_empty():
			continue
		var fps: float = float(seq.get("fps", 8))
		var idx: int = int(floor(fx.t * fps)) % frames.size()
		var frame: String = str(frames[idx])
		var alpha: float = 0.85 * (1.0 - fx.t / maxf(fx.life, 0.01))
		_blit(frame, fx.x, fx.y, sc, Color(1.55, 1.55, 1.4, alpha))


func _draw_juice() -> void:
	Juice.draw_all(self, _juice, func(x: float, y: float) -> Vector2: return Iso.world_to_iso(x, y), STheme.body_font())


func _draw_edge_fog() -> void:
	## Map edge handled by oversized seamless fill + soft screen vignette.
	## Deliberately no circular/world arcs — those produced the dark-ring bug.
	pass


func _draw_soft_shadow(wx: float, wy: float, radius: float, alpha: float = 0.28) -> void:
	var iso := Iso.world_to_iso(wx, wy) + Vector2(3.0, 5.0)
	draw_colored_polygon(_diamond_at(iso, radius * 1.15, radius * 0.55), Color(0.02, 0.03, 0.02, alpha))


func _draw_ending_planet() -> void:
	var vp := get_viewport_rect().size
	var cam := camera.position
	var z: float = maxf(camera.zoom.x, 0.2)
	var a_bg: float = minf(0.92, world.orbit_t * 0.28)
	## Full-bleed orbit nebula behind the far planet.
	if ProArt.has(pro, "orbit_bg"):
		ProArt.blit(self, pro, "orbit_bg", cam, 0.72 / z, Color(1, 1, 1, a_bg))
	## Soft dim so the diegetic stats panel stays readable.
	draw_rect(Rect2(cam - vp * 0.55 / z, vp * 1.1 / z), Color(0.02, 0.03, 0.04, minf(0.45, world.orbit_t * 0.12)), true)
	var p := cam + Vector2(vp.x * 0.3 / z, -vp.y * 0.18 / z)
	var tw: float = 0.45 + 0.55 * abs(sin(world.time * 2.2))
	var planet_a: float = _other_planet_a * tw
	if ProArt.has(pro, "ending_planet"):
		ProArt.blit(self, pro, "ending_planet", p, 0.16 / z * camera.zoom.x, Color(1.05, 1.02, 0.98, planet_a))
	elif ProArt.has(pro, "menu_apis"):
		ProArt.blit(self, pro, "menu_apis", p, 0.1, Color(1, 1, 1, planet_a * 0.85))
	else:
		draw_circle(p, 10.0, Color(0.95, 0.75, 0.3, planet_a))
		draw_arc(p, 18.0, 0, TAU, 28, Color(0.95, 0.7, 0.25, planet_a * 0.45), 1.6)
	## Title lives in the 9-slice EndPanel — keep a faint logo only if panel missing.
	if not _die.has("end") and ProArt.has(pro, "swarm_logo"):
		ProArt.blit(self, pro, "swarm_logo", cam + Vector2(0, -vp.y * 0.32 / z), 0.22, Color(1, 1, 1, minf(1.0, world.orbit_t * 0.25)))


func _draw_box_fallback(wx: float, wy: float, half: float, col: Color) -> void:
	var c := Iso.world_to_iso(wx, wy)
	var box: Dictionary = Iso.box_points(c.x, c.y, half, half * 0.5, half * 0.35)
	draw_colored_polygon(box.left, col.darkened(0.25))
	draw_colored_polygon(box.right, col.darkened(0.15))
	draw_colored_polygon(box.top, col)


func _draw_guidance() -> void:
	var g = world.guidance()
	if g.get("target") != null:
		var t: Dictionary = g.target
		var c := Iso.world_to_iso(t.x, t.y)
		var ph: float = fmod(world.time, 1.6) / 1.6
		var pulse_i: int = int(floor(fmod(world.time * 6.0, 6.0)))
		var pulse_key := "reticle_myc_pulse_%02d" % pulse_i
		if ProArt.has(pro, pulse_key):
			ProArt.blit(self, pro, pulse_key, c, 0.4 + ph * 0.08, Color(1, 1, 1, 0.55 * (1.0 - ph * 0.5)))
		elif ProArt.has(pro, "reticle_myc"):
			ProArt.blit(self, pro, "reticle_myc", c, 0.38 + ph * 0.1, Color(1, 1, 1, 0.5 * (1.0 - ph)))
		elif ProArt.has(pro, "reticle"):
			ProArt.blit(self, pro, "reticle", c, 0.35 + ph * 0.1, Color(1, 1, 1, 0.45 * (1.0 - ph)))
		else:
			draw_arc(c, float(t.get("r", 16.0)) * 0.55 + ph * 8.0, 0, TAU, 32, Color(0.55, 0.9, 0.65, 0.28 * (1.0 - ph)), 1.4)
