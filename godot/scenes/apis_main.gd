## Isometric Apis — atlas art v2 (meadow / feromon / building stages + FX).
extends Node2D

const C = preload("res://apis/config.gd")
const Iso = preload("res://apis/iso.gd")
const Atlas = preload("res://apis/iso_atlas.gd")

@onready var camera: Camera2D = $Camera2D
@onready var hud: CanvasLayer = $HUD
@onready var clock_label: Label = $HUD/Panel/VBox/Clock
@onready var next_label: Label = $HUD/Panel/VBox/Next
@onready var wow_label: Label = $HUD/Panel/VBox/Wow
@onready var speed_label: Label = $HUD/Panel/VBox/Speed
@onready var guide_label: Label = $HUD/Diegetic/Guide

var world: ApisWorld
var demo_on: bool = false
var speed_mul: float = 1.0
var speed_idx: int = 0
const SPEEDS := [1.0, 2.0, 4.0, 8.0]

var panning: bool = false
var pan_last: Vector2 = Vector2.ZERO
var zoom_target: float = 1.0
var _drag: bool = false
var atlas: Dictionary = {}
var sequences: Dictionary = {}
var _use_2x: bool = false
var _orbit_done: bool = false
var _other_planet_a: float = 0.0
var _autosave_cd: float = 60.0
var _run_seed: int = 42
var _fx: Array = [] ## {seq, x, y, t, life}
var _prev_core_pulse: float = 0.0
var _prev_highway: float = 0.0


func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	if "--sim" in args or "sim" in args:
		_run_sim_and_quit()
		return
	if "--demo" in args or "demo" in args:
		demo_on = true
	if OS.has_feature("web"):
		demo_on = true
	_use_2x = DisplayServer.screen_get_scale() >= 1.5
	atlas = Atlas.load_all(_use_2x)
	sequences = Atlas.load_sequences(_use_2x)
	_run_seed = 42
	var opts := {"silent": false, "seed": _run_seed}
	var resume_t: float = -1.0
	if get_tree().has_meta("swarm_continue") and bool(get_tree().get_meta("swarm_continue")):
		get_tree().set_meta("swarm_continue", false)
		var sav: Dictionary = SwarmSave.load_all()
		if str(sav.rod) == "apis":
			_run_seed = int(sav.seed)
			opts["seed"] = _run_seed
			resume_t = float(sav.time)
			if resume_t >= C.START10_T - 5.0:
				opts["startAt"] = 600.0
			elif resume_t >= C.START5_T - 5.0:
				opts["startAt"] = 280.0
	elif "--start=10" in args or "start=10" in args:
		opts["startAt"] = 600.0
	world = ApisWorld.new(opts)
	if resume_t > world.time:
		_catch_up(resume_t)
	SwarmAudio.set_ambient("apis")
	hud.visible = demo_on
	camera.position = Iso.world_to_iso(float(C.W) * 0.5, float(C.H) * 0.48)
	zoom_target = 1.0
	camera.zoom = Vector2(zoom_target, zoom_target)
	queue_redraw()


func _catch_up(target: float) -> void:
	var silent_was: bool = world.silent
	world.silent = true
	var guard := 0
	while world.time < target - 0.05 and guard < 200000:
		world.update(minf(1.0 / 12.0, target - world.time))
		guard += 1
	world.silent = silent_was


func _autosave(_force: bool = false) -> void:
	if world == null or world.mvp_end_time != null:
		return
	SwarmSave.save_progress("apis", float(world.time), _run_seed)


func _return_menu(grown_flag: bool = false) -> void:
	_autosave(true)
	if grown_flag:
		get_tree().set_meta("swarm_grown_apis", true)
		SwarmSave.save_progress("apis", 900.0, _run_seed, {"apis": true})
		SwarmSave.clear_progress()
	get_tree().set_meta("swarm_return_choose", true)
	SwarmAudio.set_ambient("menu")
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _run_sim_and_quit() -> void:
	var runner := ApisHeadless.new()
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
		if world.orbit_t > 4.5 and not _orbit_done:
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
	camera.zoom = camera.zoom.lerp(Vector2(z, z), 1.0 - exp(-dt * 3.0))
	_refresh_hud()
	queue_redraw()


func _refresh_hud() -> void:
	var g = world.guidance()
	guide_label.text = str(g.get("label", ""))
	if not demo_on:
		return
	var m = world.metrics()
	clock_label.text = _fmt_clock(float(m.time))
	speed_label.text = "Rychlost: %.0f×" % speed_mul
	next_label.text = "Dál: %s" % str(g.get("label", ""))
	var wows = world.poll_wows()
	if wows.size() > 0:
		wow_label.text = str(wows[wows.size() - 1].label)
		wow_label.modulate.a = 1.0
	else:
		wow_label.modulate.a = maxf(0.0, wow_label.modulate.a - 0.4 * get_process_delta_time())


func _fmt_clock(t: float) -> String:
	var m := int(floor(t / 60.0))
	var s := int(floor(fmod(t, 60.0)))
	return "%d:%02d" % [m, s]


func _unhandled_input(event: InputEvent) -> void:
	if world == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		_return_menu(false)
		return
	if event.is_action_pressed("toggle_demo"):
		demo_on = not demo_on
		hud.visible = demo_on
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
				world.note_pointer()
				world.pointer_down(wpos.x, wpos.y)
			else:
				_drag = false
				world.pointer_up()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if panning:
			var delta: Vector2 = mm.position - pan_last
			pan_last = mm.position
			camera.position -= delta / camera.zoom.x
		elif _drag:
			var wpos2 := _screen_to_world(mm.position)
			world.note_pointer()
			world.pointer_move(wpos2.x, wpos2.y)


func _screen_to_world(screen: Vector2) -> Vector2:
	var canvas: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen
	return Iso.iso_to_world(canvas.x, canvas.y)


func _hive() -> Vector2:
	if world.core != null:
		return Vector2(world.core.x, world.core.y)
	return Vector2(world.cx, world.cy)


func _visual_reach() -> float:
	var base: float = 100.0 + float(world.chambers.size()) * 6.5 + float(world.trails.size()) * 28.0 + world.time * 0.2
	if world.meadow2 != null:
		base += 70.0
	if world.second_hive != null:
		base += 90.0
	return clampf(base, 100.0, 540.0)


func _terrain_stage(wx: float, wy: float) -> String:
	var hive := _hive()
	var d: float = hive.distance_to(Vector2(wx, wy))
	var reach: float = _visual_reach()
	if d > reach * 1.05:
		return "divoka"
	if d > reach * 0.52:
		return "osazena"
	return "ziva"


func _intensity(glow: float) -> String:
	if glow < 0.35:
		return "slaba"
	if glow < 0.7:
		return "stredni"
	return "silna"


func _spawn_fx(seq: String, x: float, y: float, life: float = 1.0) -> void:
	if not sequences.has(seq):
		return
	_fx.append({"seq": seq, "x": x, "y": y, "t": 0.0, "life": life})


func _tick_fx(dt: float) -> void:
	if world.core_pulse > _prev_core_pulse + 0.35:
		var h := _hive()
		_spawn_fx("apis2_fx_kapka", h.x, h.y, 1.0)
		_spawn_fx("apis2_fx_pyl", h.x + 10.0, h.y - 6.0, 1.1)
		_spawn_fx("apis2_fx_feromon", h.x, h.y + 8.0, 0.95)
	if world.highway_glow > _prev_highway + 0.35:
		var h2 := _hive()
		_spawn_fx("apis2_fx_feromon", h2.x, h2.y, 1.0)
		_spawn_fx("apis2_fx_pyl", h2.x - 8.0, h2.y + 6.0, 1.05)
	_prev_core_pulse = world.core_pulse
	_prev_highway = world.highway_glow
	var i := _fx.size() - 1
	while i >= 0:
		_fx[i].t += dt
		if _fx[i].t >= _fx[i].life:
			_fx.remove_at(i)
		i -= 1


func _draw() -> void:
	if world == null:
		return
	_draw_meadow()
	_draw_routes_trails()
	_draw_chambers()
	_draw_flowers()
	_draw_builders()
	_draw_workers()
	_draw_fx()
	_draw_guidance()


func _blit(name: String, world_x: float, world_y: float, scale: float = 1.0, modulate: Color = Color.WHITE, extra_off: Vector2 = Vector2.ZERO) -> void:
	if not atlas.has(name):
		return
	var entry: Dictionary = atlas[name]
	var tex: Texture2D = entry.texture
	var off: Vector2 = entry.offset
	var iso: Vector2 = Iso.world_to_iso(world_x, world_y) + extra_off
	var sz: Vector2 = tex.get_size() * scale
	draw_texture_rect(tex, Rect2(iso + off * scale, sz), false, modulate)


func _diamond_at(center: Vector2, half_w: float, half_h: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -half_h),
		center + Vector2(half_w, 0),
		center + Vector2(0, half_h),
		center + Vector2(-half_w, 0),
	])


func _draw_box(wx: float, wy: float, half: float, col: Color, height: float = -1.0) -> void:
	var c := Iso.world_to_iso(wx, wy)
	var h: float = half * 0.35 if height < 0.0 else height
	var box: Dictionary = Iso.box_points(c.x, c.y, half, half * 0.5, h)
	draw_colored_polygon(box.left, col.darkened(0.25))
	draw_colored_polygon(box.right, col.darkened(0.15))
	draw_colored_polygon(box.top, col)


func _draw_meadow() -> void:
	var tile: float = float(C.MEADOW_TILE)
	var cols: int = world.meadow_cols
	var rows: int = world.meadow_rows
	var sc: float = 0.5 if not _use_2x else 0.25
	for ty in range(rows):
		for tx in range(cols):
			var wx: float = (float(tx) + 0.5) * tile
			var wy: float = (float(ty) + 0.5) * tile
			var idx: int = (ty * cols + tx) % 3
			var variant: String = ["a", "b", "c"][idx]
			var stage: String = _terrain_stage(wx, wy)
			var n := "apis2_louka_%s_%s" % [stage, variant]
			if atlas.has(n):
				_blit(n, wx, wy, sc)
			else:
				var iso := Iso.world_to_iso(wx, wy)
				var shade := 0.72 - 0.04 * float(idx) - world.dusk * 0.12
				draw_colored_polygon(
					_diamond_at(iso, tile * 0.55, tile * 0.28),
					Color(shade, shade * 0.98, shade * 0.9, 1.0)
				)
			if stage == "ziva" and atlas.has("apis2_overlay_kvet"):
				_blit("apis2_overlay_kvet", wx, wy, sc * 0.9, Color(1, 1, 1, 0.2 + world.meadow_bloom * 0.25))
	if world.meadow2 != null:
		var m2 = world.meadow2
		if atlas.has("apis2_overlay_kvet"):
			_blit("apis2_overlay_kvet", m2.x, m2.y, 0.55 if not _use_2x else 0.28, Color(1, 1, 1, 0.7 + world.meadow_bloom * 0.3))
		elif atlas.has("apis2_louka_ziva_a"):
			_blit("apis2_louka_ziva_a", m2.x, m2.y, 0.55 if not _use_2x else 0.28, Color(1, 1, 1, 0.7 + world.meadow_bloom * 0.3))
		else:
			var c := Iso.world_to_iso(m2.x, m2.y)
			draw_circle(c, 28.0 + world.meadow_bloom * 8.0, Color(0.7, 0.62, 0.35, 0.22 + world.meadow_bloom * 0.2))


func _feromon_dir(dx: float, dy: float) -> String:
	var a := atan2(dy, dx)
	if a >= -PI * 0.25 and a < PI * 0.25:
		return "SE"
	if a >= PI * 0.25 and a < PI * 0.75:
		return "SW"
	if a >= -PI * 0.75 and a < -PI * 0.25:
		return "NE"
	return "NW"


func _draw_routes_trails() -> void:
	var hc := _hive()
	for rt in world.routes:
		if rt.flower < 0 or rt.flower >= world.flowers.size():
			continue
		var f = world.flowers[rt.flower]
		var a := Iso.world_to_iso(hc.x, hc.y)
		var b := Iso.world_to_iso(f.x, f.y)
		draw_line(a, b, Color(0.55, 0.52, 0.42, 0.25 + rt.glow * 0.3), 1.6, true)
	for tr in world.trails:
		if tr.pts.size() < 2:
			continue
		var gold: float = world.highway_glow if tr.kind in ["join", "highway"] else tr.glow
		var inten := _intensity(gold)
		for i in range(1, tr.pts.size()):
			var p0 = tr.pts[i - 1]
			var p1 = tr.pts[i]
			var dir := _feromon_dir(p1.x - p0.x, p1.y - p0.y)
			var fname := "apis2_feromon_%s_%s" % [inten, dir]
			if atlas.has(fname):
				_blit(fname, (p0.x + p1.x) * 0.5, (p0.y + p1.y) * 0.5, 0.28 if not _use_2x else 0.14, Color(1, 1, 1, 0.4 + gold * 0.45))
			else:
				var a2 := Iso.world_to_iso(p0.x, p0.y)
				var b2 := Iso.world_to_iso(p1.x, p1.y)
				draw_line(a2, b2, Color(0.85, 0.65, 0.25, 0.3 + gold * 0.4), 2.4, true)
		var last = tr.pts[tr.pts.size() - 1]
		var prev = tr.pts[tr.pts.size() - 2]
		var tip := "apis2_feromon_tip_%s_%s" % [inten, _feromon_dir(last.x - prev.x, last.y - prev.y)]
		if not atlas.has(tip):
			tip = "apis2_feromon_tip"
		if atlas.has(tip):
			_blit(tip, last.x, last.y, 0.3 if not _use_2x else 0.15)
		if atlas.has("apis2_feromon_uzel_%s" % inten) and tr.pts.size() > 2:
			var mid = tr.pts[tr.pts.size() / 2]
			_blit("apis2_feromon_uzel_%s" % inten, mid.x, mid.y, 0.22 if not _use_2x else 0.11, Color(1, 1, 1, 0.5 + gold * 0.3))
	if world.stroke_active:
		for i in range(1, world.stroke_pts.size()):
			var a3 := Iso.world_to_iso(world.stroke_pts[i - 1].x, world.stroke_pts[i - 1].y)
			var b3 := Iso.world_to_iso(world.stroke_pts[i].x, world.stroke_pts[i].y)
			draw_line(a3, b3, Color(0.7, 0.58, 0.28, 0.45), 2.2, true)
	if world.second_hive != null:
		var sh = world.second_hive
		var a4 := Iso.world_to_iso(hc.x, hc.y)
		var b4 := Iso.world_to_iso(sh.x, sh.y)
		draw_line(a4, b4, Color(0.72, 0.58, 0.28, 0.25 + world.highway_glow * 0.35), 2.6, true)
		var uln := "apis2_ul_zarivy" if sh.pulse > 0.4 or world.highway_glow > 0.5 else "apis2_ul_dostaveny"
		if atlas.has(uln):
			_blit(uln, sh.x, sh.y, 0.35 if not _use_2x else 0.18, Color(1, 1, 1, 0.75 + sh.pulse * 0.2))
		else:
			_draw_box(sh.x, sh.y, 14.0, Color(0.7, 0.55, 0.35, 0.75), 10.0 + sh.pulse * 4.0)
	if world.swarm_time != null and atlas.has("apis2_overlay_med"):
		_blit("apis2_overlay_med", hc.x, hc.y - 40.0, 0.4 if not _use_2x else 0.2, Color(1, 1, 1, 0.35 + world.highway_glow * 0.25))


func _plast_stage(ch: Dictionary) -> String:
	if world.brass_sheen > 0.25 or ch.amber > 0.45 or world.core_pulse > 0.55:
		return "zarivy"
	if ch.grow >= 1.0:
		return "dostaveny"
	return "rozestaveny"


func _draw_chambers() -> void:
	if not world.planted:
		var kn := "apis2_kamen_zarivy" if world.pulse_hex_glow > 0.7 else "apis2_kamen_rozestaveny"
		if atlas.has(kn):
			_blit(kn, world.cx, world.cy, 0.45 if not _use_2x else 0.22, Color(1, 1, 1, 0.55 + world.pulse_hex_glow * 0.35))
		else:
			_draw_box(world.cx, world.cy, C.HEX * 0.55, Color(0.62, 0.6, 0.55, 0.55 + world.pulse_hex_glow * 0.25))
		return
	var items: Array = []
	for ch in world.chambers.values():
		var p: Vector2 = world._axial_to_pixel(ch.q, ch.r)
		var iso := Iso.world_to_iso(p.x, p.y)
		items.append({"ch": ch, "p": p, "iso_y": iso.y})
	items.sort_custom(func(a, b): return a.iso_y < b.iso_y)
	var sc: float = 0.38 if not _use_2x else 0.19
	sc *= world.hive_scale
	for it in items:
		var ch = it.ch
		var p: Vector2 = it.p
		var grow: float = ch.grow
		var stage := _plast_stage(ch)
		var pname := "apis2_plast_%s" % stage
		var mod := Color(1, 1, 1, 0.45 + grow * 0.5)
		if ch.amber > 0.05:
			mod = mod.lerp(Color(1.0, 0.85, 0.45, 0.95), ch.amber * 0.4)
		if world.brass_sheen > 0.0:
			mod = mod.lerp(Color(1.0, 0.88, 0.5, 1.0), world.brass_sheen * 0.35)
		if world.rust_chamber != null and world._hex_key(ch.q, ch.r) == world.rust_chamber and world.winter_time == null:
			mod = mod.lerp(Color(0.85, 0.45, 0.3, 0.95), 0.45 + world.cold * 0.3)
		if atlas.has(pname):
			var psz: float = sc * (0.7 + grow * 0.3)
			_blit(pname, p.x, p.y, psz, mod)
			if (world.floor2 or world.floor3):
				var stack: Vector2 = Vector2.ZERO
				var e1: Dictionary = atlas[pname]
				if e1.has("stack_offset"):
					stack = e1.stack_offset * psz
				elif atlas.has("apis2_plast_dostaveny") and atlas["apis2_plast_dostaveny"].has("stack_offset"):
					stack = atlas["apis2_plast_dostaveny"].stack_offset * psz
				var upper := "apis2_plast_zarivy" if stage == "zarivy" else "apis2_plast_dostaveny"
				if atlas.has(upper):
					_blit(upper, p.x, p.y, psz, mod, stack)
					if world.floor3:
						_blit(upper, p.x, p.y, psz, mod, stack * 1.85)
		else:
			var half: float = C.HEX * 0.45 * (0.55 + grow * 0.45)
			var floor_mul: float = 1.35 if world.floor3 else (1.15 if world.floor2 else 1.0)
			_draw_box(p.x, p.y, half, Color(0.7, 0.55, 0.35, 0.55 + grow * 0.35), half * 0.35 * world.hive_scale * floor_mul)
	if world.core != null:
		var ul := "apis2_ul_zarivy" if world.core_pulse > 0.4 or world.brass_sheen > 0.3 else "apis2_ul_dostaveny"
		if world.time < 90.0 and world.chambers.size() < 4:
			ul = "apis2_ul_rozestaveny"
		if atlas.has(ul):
			_blit(ul, world.core.x, world.core.y, 0.42 if not _use_2x else 0.21, Color(1, 1, 1, 0.85 + world.core_pulse * 0.15))
		else:
			_draw_box(world.core.x, world.core.y, 10.0 * world.hive_scale, Color(0.75, 0.55, 0.35, 0.9), 8.0 + world.core_pulse * 4.0)
		if atlas.has("apis2_overlay_med") and world.core_pulse > 0.2:
			_blit("apis2_overlay_med", world.core.x, world.core.y, 0.35 if not _use_2x else 0.18, Color(1, 1, 1, 0.25 + world.core_pulse * 0.35))
	if world.rust_machine != null:
		var rm = world.rust_machine
		var rc := Color(0.5, 0.38, 0.3, 0.7) if not rm.looted else Color(0.45, 0.4, 0.35, 0.35)
		_draw_box(rm.x, rm.y, rm.r * 0.45, rc, rm.r * 0.3)
	if world.royal_cell != null:
		var cell = world.royal_cell
		var glow: float = cell.glow
		var iso_c := Iso.world_to_iso(cell.x, cell.y)
		draw_circle(iso_c, 8.0 + glow * 4.0, Color(0.95, 0.85, 0.45, 0.55 + glow * 0.4))
		if cell.capped:
			draw_arc(iso_c, 14.0, 0, TAU, 24, Color(1.0, 0.92, 0.55, 0.7 + cell.queen * 0.3), 2.0)
	if world.mvp_end_time != null:
		var vp := get_viewport_rect().size
		var p2 := Vector2(vp.x * 0.22, vp.y * 0.2)
		var tw: float = 0.4 + 0.6 * abs(sin(world.time * 2.5))
		draw_circle(p2, 5.0, Color(0.4, 0.75, 0.5, _other_planet_a * tw))
		draw_arc(p2, 10.0, 0, TAU, 20, Color(0.35, 0.7, 0.48, _other_planet_a * 0.45), 1.2)
		draw_string(ThemeDB.fallback_font, Vector2(vp.x * 0.5 - 40, vp.y * 0.12), "SWARM", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.9, 0.92, 0.88, minf(1.0, world.orbit_t * 0.25)))


func _draw_flowers() -> void:
	for f in world.flowers:
		var iso := Iso.world_to_iso(f.x, f.y)
		if f.get("tree", false):
			_draw_box(f.x, f.y, f.r * 0.45, Color(0.62, 0.55, 0.35, 0.75), f.r * 0.35)
			if world.tree_attract:
				draw_arc(iso, f.r * 0.5 + 8.0 + world.tree_attract_pulse * 6.0, 0, TAU, 28, Color(0.7, 0.6, 0.3, 0.25 + world.tree_attract_pulse * 0.3), 1.4)
		elif atlas.has("apis2_overlay_kvet"):
			_blit("apis2_overlay_kvet", f.x, f.y, 0.22 if not _use_2x else 0.11, Color(1, 1, 1, 0.55 + f.bloom * 0.4))
		else:
			var br: float = f.r * (0.55 + f.bloom * 0.35)
			draw_colored_polygon(_diamond_at(iso, br, br * 0.55), Color(0.55, 0.55, 0.5, 0.7 + f.bloom * 0.2))


func _bee_dir(dx: float, dy: float) -> String:
	var a := atan2(dy, dx)
	if a >= -PI * 0.25 and a < PI * 0.25:
		return "SE"
	if a >= PI * 0.25 and a < PI * 0.75:
		return "SW"
	if a >= -PI * 0.75 and a < -PI * 0.25:
		return "NE"
	return "NW"


func _draw_builders() -> void:
	## Visual-only stavitelky ferrying wax to growing chambers.
	var hive := _hive()
	var sc: float = 0.42 if not _use_2x else 0.21
	for ch in world.chambers.values():
		if ch.grow >= 1.0:
			continue
		var p: Vector2 = world._axial_to_pixel(ch.q, ch.r)
		var t: float = fmod(world.time * 0.55 + float(ch.q) * 0.17 + float(ch.r) * 0.13, 1.0)
		var bx: float = lerpf(hive.x, p.x, t)
		var by: float = lerpf(hive.y, p.y, t)
		var dir := _bee_dir(p.x - hive.x, p.y - hive.y)
		var name := "apis2_stavitelka_neseni_%s" % dir
		if not atlas.has(name):
			name = "apis2_stavitelka_%s" % dir
		if atlas.has(name):
			_blit(name, bx, by, sc)


func _draw_workers() -> void:
	for w in world.workers:
		var dir := "SE"
		if w.outbound and w.flower >= 0 and w.flower < world.flowers.size():
			var f = world.flowers[w.flower]
			dir = _bee_dir(f.x - w.x, f.y - w.y)
		elif not w.outbound:
			dir = _bee_dir(world.cx - w.x, world.cy - w.y)
		## Carrying nectar uses letavka (same bee) — pollen FX marks cargo; keep sprite readable.
		var name := "apis2_letavka_%s" % dir
		if not atlas.has(name):
			name = "apis2_letavka_SE"
		if atlas.has(name):
			_blit(name, w.x, w.y, 0.45 if not _use_2x else 0.22)
			if w.carrying and atlas.has("apis2_overlay_med"):
				_blit("apis2_overlay_med", w.x, w.y, 0.18 if not _use_2x else 0.09, Color(1, 1, 1, 0.55))
		else:
			var iso := Iso.world_to_iso(w.x, w.y)
			var col := Color(0.85, 0.75, 0.35, 0.95) if w.carrying else Color(0.45, 0.42, 0.38, 0.9)
			draw_circle(iso, 2.2, col)


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
		var alpha: float = 0.9 * (1.0 - fx.t / maxf(fx.life, 0.01))
		_blit(frame, fx.x, fx.y, sc, Color(1.35, 1.25, 1.05, alpha))


func _draw_guidance() -> void:
	var g = world.guidance()
	if g.get("target") != null:
		var t: Dictionary = g.target
		var c := Iso.world_to_iso(t.x, t.y)
		var ph: float = fmod(world.time, 1.6) / 1.6
		draw_arc(c, float(t.get("r", 16.0)) * 0.6 + ph * 10.0, 0, TAU, 32, Color(0.75, 0.7, 0.5, 0.35 * (1.0 - ph)), 1.5)
