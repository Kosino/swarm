## Isometric Apis — Build 12 pro art (seamless meadow, atmosphere, organic hive).
extends Node2D

const C = preload("res://apis/config.gd")
const Iso = preload("res://apis/iso.gd")
const Atlas = preload("res://apis/iso_atlas.gd")
const Atm = preload("res://ui/atmosphere.gd")
const ProArt = preload("res://ui/pro_art.gd")
const STheme = preload("res://ui/swarm_theme.gd")

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
const TILE_SC_1X := 1.08
const TILE_SC_2X := 0.54

var panning: bool = false
var pan_last: Vector2 = Vector2.ZERO
var zoom_target: float = 1.0
var _drag: bool = false
var atlas: Dictionary = {}
var sequences: Dictionary = {}
var pro: Dictionary = {}
var _atm: Dictionary = {}
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
	## Diegetic default — debug HUD only via F1.
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
	pro = ProArt.load_all(_use_2x)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
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
	if capture_at >= 0.0:
		opts["silent"] = true
		if capture_at >= C.START10_T - 5.0:
			opts["startAt"] = 600.0
		elif capture_at >= C.START5_T - 5.0:
			opts["startAt"] = 280.0
	world = ApisWorld.new(opts)
	if resume_t > world.time:
		_catch_up(resume_t)
	if capture_at >= 0.0:
		var Bot = preload("res://tools/capture_bot.gd")
		Bot.advance_apis(world, capture_at)
		demo_on = false
		## Pull out at later beats so comb rings / trails / meadow živá / dusk read.
		if capture_at >= 600.0:
			world.cam_zoom = minf(world.cam_zoom_target, C.CAM_ZOOM_OUT * 0.95)
		elif capture_at >= 300.0:
			world.cam_zoom = lerpf(C.CAM_ZOOM_IN, C.CAM_ZOOM_OUT, 0.35)
		else:
			world.cam_zoom = world.cam_zoom_target
	SwarmAudio.set_ambient("apis")
	_atm = Atm.apply(self, "apis", camera, hud)
	hud.visible = demo_on
	camera.position = Iso.world_to_iso(_hive().x, _hive().y)
	zoom_target = 1.0
	camera.zoom = Vector2(zoom_target * world.cam_zoom, zoom_target * world.cam_zoom)
	Atm.sync_light(_atm, camera.position)
	queue_redraw()
	if capture_at >= 0.0 and capture_out != "":
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		print("capture_time_verify apis t=", world.time, " chambers=", world.chambers.size(), " trails=", world.trails.size(), " dusk=", world.dusk, " bloom=", world.meadow_bloom, " floor2=", world.floor2)
		var img: Image = get_viewport().get_texture().get_image()
		if img:
			img.save_png(capture_out)
			print("capture_saved ", capture_out)
		get_tree().quit()


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
	camera.zoom = camera.zoom.lerp(Vector2(z, z), 1.0 - exp(-dt * 1.55))
	var h := _hive()
	var h_iso := Iso.world_to_iso(h.x, h.y)
	Atm.sync_light(_atm, h_iso, 0.4 + world.core_pulse * 0.28 + world.brass_sheen * 0.2)
	## Presentational dusk ramp from ~10:00 even if hint beat is late — readable 11:00 dusk.
	var dusk_v: float = maxf(world.dusk, clampf((world.time - 560.0) / 140.0, 0.0, 1.0) * 0.85)
	Atm.set_dusk(_atm, dusk_v)
	if _atm.has("dust"):
		(_atm["dust"] as Node2D).global_position = h_iso
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
	## Time-weighted so meadow živá spread reads clearly 5:00 → 11:00 → 15:00.
	var base: float = 90.0 + float(world.chambers.size()) * 7.0 + float(world.trails.size()) * 32.0 + world.time * 0.28
	if world.meadow2 != null:
		base += 80.0
	if world.second_hive != null:
		base += 100.0
	if world.meadow_bloom > 0.4:
		base += 50.0
	if world.dusk > 0.3:
		base += 40.0
	return clampf(base, 90.0, 580.0)


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
	_draw_ground_base()
	_draw_meadow()
	_draw_routes_trails()
	_draw_chambers()
	_draw_flowers()
	_draw_builders()
	_draw_workers()
	_draw_fx()
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
	## Per macro-cell UV rotation breaks periodic pale stripe bands from single tiled fill.
	draw_set_transform(center, rot, Vector2.ONE)
	var half := cell * 0.5
	draw_texture_rect(tex, Rect2(-half, -half, cell, cell), true, modulate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_ground_base() -> void:
	var c := Iso.world_to_iso(float(C.W) * 0.5, float(C.H) * 0.5)
	var hw: float = float(C.W) * 1.55
	var hh: float = float(C.H) * 1.05
	draw_colored_polygon(_diamond_at(c, hw * 1.55, hh * 1.55), Color(0.12, 0.09, 0.05, 1.0))
	var t_div: Texture2D = ProArt.tex(pro, "apis_tex_louka_divoka")
	var t_osa: Texture2D = ProArt.tex(pro, "apis_tex_louka_osazena")
	var t_ziv: Texture2D = ProArt.tex(pro, "apis_tex_louka_ziva")
	if t_div != null:
		## Continuous base fill (no cell seams), then noise-blended rotated louka overlays
		## break the baked diagonal pale stripes inside the seamless textures.
		var reach: float = _visual_reach()
		var bloom: float = world.meadow_bloom
		var fill := Rect2(c.x - 2200.0, c.y - 1400.0, 4400.0, 2800.0)
		var base: Texture2D = t_div
		if reach > 220.0 and t_osa != null:
			base = t_osa
		if (reach > 380.0 or bloom > 0.4) and t_ziv != null:
			base = t_ziv
		draw_texture_rect(base, fill, true)
		var cell: float = 520.0
		var step: float = 260.0
		var x0: float = c.x - 2200.0
		var y0: float = c.y - 1400.0
		var nx: int = int(ceil(4400.0 / step)) + 1
		var ny: int = int(ceil(2800.0 / step)) + 1
		for iy in range(ny):
			for ix in range(nx):
				var cx: float = x0 + float(ix) * step + cell * 0.5
				var cy: float = y0 + float(iy) * step + cell * 0.5
				var h0: float = _hash2(ix, iy)
				var h1: float = _hash2(ix + 19, iy + 7)
				var h2: float = _hash2(ix + 41, iy + 23)
				var n: float = 0.5 + 0.5 * sin(float(ix) * 0.29 + float(iy) * 0.23) * cos(float(ix) * 0.15 - float(iy) * 0.37)
				## Soft falloff toward cell edge — heavy overlap so overlays never read as a grid.
				var edge: float = 0.55 + 0.45 * n
				var rot: float = float(int(h2 * 4.0) % 4) * PI * 0.5
				## Pick 1–2 non-base loukas by low-freq weights.
				var use_osa: bool = t_osa != null and (h0 * clampf(reach / 240.0, 0.2, 1.0)) > 0.28
				var use_ziv: bool = t_ziv != null and (h1 * clampf((reach - 160.0) / 300.0 + bloom * 0.6, 0.0, 1.0)) > 0.32
				var use_div: bool = (base != t_div) and n > 0.42
				if use_osa and base != t_osa:
					_draw_tex_cell(t_osa, Vector2(cx, cy), cell, rot, Color(1, 1, 1, 0.28 * edge))
				if use_ziv and base != t_ziv:
					_draw_tex_cell(t_ziv, Vector2(cx, cy), cell, rot + PI * 0.5, Color(1, 1, 1, 0.32 * edge))
				if use_div:
					_draw_tex_cell(t_div, Vector2(cx, cy), cell, rot + PI, Color(1, 1, 1, 0.26 * edge))
				## Always stamp one rotated alternate so stripe phase never aligns across neighbors.
				var alt: Texture2D = t_osa if t_osa != null and base != t_osa else (t_ziv if t_ziv != null and base != t_ziv else t_div)
				if alt != null and alt != base:
					_draw_tex_cell(alt, Vector2(cx, cy), cell * 0.85, rot + float(ix + iy) * 0.5 * PI, Color(1, 1, 1, 0.18 + 0.12 * h0))
		var rim: Texture2D = ProArt.tex(pro, "apis_tex_skala_okraj")
		if rim != null:
			var rim_pts := _diamond_at(c + Vector2(0, hh * 0.55), hw * 0.75, 56.0)
			var ruv := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
			draw_polygon(rim_pts, PackedColorArray([Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.05)]), ruv, rim)
	else:
		draw_colored_polygon(_diamond_at(c, hw, hh), Color(0.28, 0.22, 0.12, 1.0))
	_draw_meadow_decals()


func _blit(name: String, world_x: float, world_y: float, scale: float = 1.0, modulate: Color = Color.WHITE, extra_off: Vector2 = Vector2.ZERO) -> void:
	if not atlas.has(name):
		return
	var entry: Dictionary = atlas[name]
	var tex: Texture2D = entry.texture
	var off: Vector2 = entry.offset
	var iso: Vector2 = Iso.world_to_iso(world_x, world_y) + extra_off
	var sz: Vector2 = tex.get_size() * scale
	draw_texture_rect(tex, Rect2(iso + off * scale, sz), false, modulate)


func _blit_rot(name: String, world_x: float, world_y: float, scale: float, modulate: Color, rot: float, extra_off: Vector2 = Vector2.ZERO) -> void:
	if not atlas.has(name):
		return
	if absf(rot) < 0.01:
		_blit(name, world_x, world_y, scale, modulate, extra_off)
		return
	var entry: Dictionary = atlas[name]
	var tex: Texture2D = entry.texture
	var off: Vector2 = entry.offset * scale + extra_off
	var iso: Vector2 = Iso.world_to_iso(world_x, world_y)
	var sz: Vector2 = tex.get_size() * scale
	draw_set_transform(iso, rot, Vector2.ONE)
	draw_texture_rect(tex, Rect2(off, sz), false, modulate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
	## Sparse meadow atlas over seamless fill — avoid hard rectangular meadow patch.
	var tile: float = float(C.MEADOW_TILE)
	var cols: int = world.meadow_cols
	var rows: int = world.meadow_rows
	var sc: float = _tile_sc()
	var has_fill: bool = ProArt.has(pro, "apis_tex_louka_divoka")
	for ty in range(rows):
		for tx in range(cols):
			## Very sparse meadow sprites — diamond atlas tiles must not form a pale grid.
			var sparse: int = 6 if _visual_reach() > 300.0 else 9
			if has_fill and ((tx * 5 + ty * 7) % sparse) != 0:
				continue
			var wx: float = (float(tx) + 0.5) * tile
			var wy: float = (float(ty) + 0.5) * tile
			var idx: int = (ty * cols + tx) % 3
			var variant: String = ["a", "b", "c"][idx]
			var stage: String = _terrain_stage(wx, wy)
			var n := "apis2_louka_%s_%s" % [stage, variant]
			if atlas.has(n):
				var a: float = 0.08 if has_fill else 1.0
				if stage == "osazena":
					a = 0.14 if has_fill else 1.0
				elif stage == "ziva":
					a = 0.22 if has_fill else 1.0
				_blit(n, wx, wy, sc * 0.85, Color(1, 1, 1, a))
			elif not has_fill:
				var iso := Iso.world_to_iso(wx, wy)
				var shade := 0.42 - 0.03 * float(idx) - world.dusk * 0.08
				draw_colored_polygon(
					_diamond_at(iso, tile * 0.56, tile * 0.28),
					Color(shade, shade * 0.92, shade * 0.7, 1.0)
				)
			if stage == "ziva" and atlas.has("apis2_overlay_kvet"):
				_blit("apis2_overlay_kvet", wx, wy, sc * 0.95, Color(1, 1, 1, 0.22 + world.meadow_bloom * 0.35))
	if world.meadow2 != null:
		var m2 = world.meadow2
		if atlas.has("apis2_overlay_kvet"):
			_blit("apis2_overlay_kvet", m2.x, m2.y, 0.7 if not _use_2x else 0.35, Color(1, 1, 1, 0.7 + world.meadow_bloom * 0.3))
		elif atlas.has("apis2_louka_ziva_a"):
			_blit("apis2_louka_ziva_a", m2.x, m2.y, _tile_sc(), Color(1, 1, 1, 0.7 + world.meadow_bloom * 0.3))


func _draw_meadow_decals() -> void:
	var hive := _hive()
	var keys := [
		"apis_decal_trs_a", "apis_decal_trs_b", "apis_decal_trs_suchy", "apis_decal_kvet_a",
		"apis_decal_kvet_b", "apis_decal_kvet_trso", "apis_decal_kamen_a", "apis_decal_kamen_b",
		"apis_decal_oblazek_a", "apis_decal_oblazek_b", "apis_decal_kerl", "apis_decal_pyl_skvrna",
	]
	var present: Array = []
	for k in keys:
		if ProArt.has(pro, k):
			present.append(k)
	if present.is_empty():
		return
	var sc: float = 0.4 if not _use_2x else 0.2
	for i in range(52):
		var ang: float = float(i) * 2.399963
		var rad: float = 60.0 + fmod(float(i * 53), 400.0)
		var wx: float = hive.x + cos(ang) * rad
		var wy: float = hive.y + sin(ang) * rad * 0.7
		if wx < -40.0 or wy < -40.0 or wx > float(C.W) + 40.0 or wy > float(C.H) + 40.0:
			continue
		var key: String = present[i % present.size()]
		var a: float = 0.58 if i % 4 == 0 else 0.4
		ProArt.blit(self, pro, key, Iso.world_to_iso(wx, wy), sc * (0.85 + float(i % 5) * 0.05), Color(1, 1, 1, a))


func _feromon_dir(dx: float, dy: float) -> String:
	var a := atan2(dy, dx)
	if a >= -PI * 0.25 and a < PI * 0.25:
		return "SE"
	if a >= PI * 0.25 and a < PI * 0.75:
		return "SW"
	if a >= -PI * 0.75 and a < -PI * 0.25:
		return "NE"
	return "NW"


func _draw_gold_trail(pts: Array, gold: float, pulse_phase: float = 0.0) -> void:
	## Wide golden additive-looking trail with traveling pulse (hive → flowers / tree).
	if pts.size() < 2:
		return
	var inten := _intensity(gold)
	var pulse_t: float = fmod(world.time * 0.55 + pulse_phase, 1.0)
	var sc_base: float = 0.72 if not _use_2x else 0.36
	for i in range(1, pts.size()):
		var p0 = pts[i - 1]
		var p1 = pts[i]
		var a2 := Iso.world_to_iso(float(p0.x), float(p0.y))
		var b2 := Iso.world_to_iso(float(p1.x), float(p1.y))
		var seg_u: float = float(i) / float(pts.size())
		var pulse: float = exp(-pow((seg_u - pulse_t) * 4.5, 2.0))
		var w: float = 7.5 + gold * 5.0 + pulse * 6.0
		## Soft additive stacks — bright HDR modulate blooms via atmosphere glow.
		draw_line(a2, b2, Color(1.35, 0.95, 0.28, 0.16 + gold * 0.12 + pulse * 0.18), w * 1.85, true)
		draw_line(a2, b2, Color(1.7, 1.25, 0.45, 0.28 + gold * 0.22 + pulse * 0.35), w, true)
		draw_line(a2, b2, Color(2.0, 1.6, 0.7, 0.22 + pulse * 0.45), maxf(2.0, w * 0.35), true)
		var dir := _feromon_dir(float(p1.x) - float(p0.x), float(p1.y) - float(p0.y))
		var fname := "apis2_feromon_%s_%s" % [inten, dir]
		var glow_col := Color(1.65 + pulse * 0.5, 1.3 + pulse * 0.35, 0.45, 0.45 + gold * 0.35 + pulse * 0.3)
		if atlas.has(fname):
			_blit(fname, (float(p0.x) + float(p1.x)) * 0.5, (float(p0.y) + float(p1.y)) * 0.5, sc_base * (0.95 + pulse * 0.25), glow_col)
	var last = pts[pts.size() - 1]
	var prev = pts[pts.size() - 2]
	var tip := "apis2_feromon_tip_%s_%s" % [inten, _feromon_dir(float(last.x) - float(prev.x), float(last.y) - float(prev.y))]
	if not atlas.has(tip):
		tip = "apis2_feromon_tip"
	if atlas.has(tip):
		_blit(tip, float(last.x), float(last.y), sc_base, Color(1.7, 1.35, 0.5, 0.8))
	if atlas.has("apis2_feromon_uzel_%s" % inten) and pts.size() > 2:
		var mid = pts[pts.size() / 2]
		_blit("apis2_feromon_uzel_%s" % inten, float(mid.x), float(mid.y), sc_base * 0.75, Color(1.55, 1.25, 0.48, 0.55 + gold * 0.3))


func _draw_routes_trails() -> void:
	var hc := _hive()
	## Wide golden additive trails hive→flowers/tree with pulse — no hard ruler axes.
	for tr_i in range(world.trails.size()):
		var tr = world.trails[tr_i]
		if tr.pts.size() < 2:
			continue
		var gold: float = world.highway_glow if tr.kind in ["join", "highway"] else maxf(tr.glow, 0.55)
		_draw_gold_trail(tr.pts, gold, float(tr_i) * 0.17)
	## Route ribbons toward each flower / tree so streams stay readable even without stroke trails.
	for rt_i in range(world.routes.size()):
		var rt = world.routes[rt_i]
		var fi: int = int(rt.flower) if rt.has("flower") else -1
		if fi < 0 or fi >= world.flowers.size():
			continue
		var f = world.flowers[fi]
		var gold_r: float = 0.45 + float(rt.get("glow", 0.3)) * 0.6 + (0.2 if f.get("tree", false) else 0.0)
		var bend := Vector2(-18.0 + float(rt_i) * 3.0, 12.0 - float(rt_i) * 2.0)
		var pts_r: Array = []
		var steps_r := 7
		for s in range(steps_r + 1):
			var u: float = float(s) / float(steps_r)
			var p: Vector2 = hc.lerp(Vector2(f.x, f.y), u) + bend * sin(u * PI)
			pts_r.append({"x": p.x, "y": p.y})
		_draw_gold_trail(pts_r, gold_r, 0.33 + float(rt_i) * 0.11)
	if world.stroke_active:
		for i in range(1, world.stroke_pts.size()):
			var a3 := Iso.world_to_iso(world.stroke_pts[i - 1].x, world.stroke_pts[i - 1].y)
			var b3 := Iso.world_to_iso(world.stroke_pts[i].x, world.stroke_pts[i].y)
			draw_line(a3, b3, Color(1.2, 0.9, 0.35, 0.28), 4.0, true)
			draw_line(a3, b3, Color(1.7, 1.3, 0.5, 0.4), 1.8, true)
	if world.second_hive != null:
		var sh = world.second_hive
		var hwy: Array = []
		var steps := 10
		for s in range(steps + 1):
			var t1: float = float(s) / float(steps)
			var bend2 := Vector2(-22.0, 14.0) * sin(t1 * PI)
			var q1 := hc.lerp(Vector2(sh.x, sh.y), t1) + bend2 * t1
			hwy.append({"x": q1.x, "y": q1.y})
		_draw_gold_trail(hwy, 0.7 + world.highway_glow * 0.5, 0.08)
		var uln := "apis2_ul_zarivy" if sh.pulse > 0.4 or world.highway_glow > 0.5 else "apis2_ul_dostaveny"
		if atlas.has(uln):
			_blit(uln, sh.x, sh.y, 0.35 if not _use_2x else 0.18, Color(1, 1, 1, 0.75 + sh.pulse * 0.2))
	if world.swarm_time != null and atlas.has("apis2_overlay_med"):
		_blit("apis2_overlay_med", hc.x, hc.y - 40.0, 0.4 if not _use_2x else 0.2, Color(1.3, 1.15, 0.7, 0.28 + world.highway_glow * 0.2))


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
	var hive := _hive()
	var max_ring: float = 0.0
	for ch0 in world.chambers.values():
		max_ring = maxf(max_ring, sqrt(float(ch0.q * ch0.q + ch0.r * ch0.r + ch0.q * ch0.r)))
	for ch in world.chambers.values():
		var ring: float = sqrt(float(ch.q * ch.q + ch.r * ch.r + ch.q * ch.r))
		## Organic gaps / missing outer cells — leave holes in the rim lattice.
		var gap_h: float = _hash2(int(ch.q) + 50, int(ch.r) + 70)
		if ring > maxf(1.2, max_ring * 0.55) and gap_h < 0.28:
			continue
		var p: Vector2 = world._axial_to_pixel(ch.q, ch.r)
		## Organic comb mound — heavier jitter + core pull (break hex lattice).
		var jx: float = sin(float(ch.q) * 2.1 + float(ch.r) * 1.6) * (9.5 + ring * 1.8)
		var jy: float = cos(float(ch.q) * 1.4 - float(ch.r) * 2.0) * (8.2 + ring * 1.4)
		var toward := (hive - p) * (0.22 + ring * 0.035)
		var spiral := Vector2(cos(float(ch.q + ch.r) * 0.85), sin(float(ch.q - ch.r) * 0.7)) * (6.5 + ring * 1.3)
		p += Vector2(jx, jy) + toward + spiral
		var iso := Iso.world_to_iso(p.x, p.y)
		var rot: float = sin(float(ch.q) * 1.15 + float(ch.r) * 1.55) * 0.48
		var sc_jit: float = 0.62 + 0.5 * abs(sin(float(ch.q) * 1.3 + float(ch.r) * 0.9))
		## Half-built rim bias — outer ring stays rozestaveny / smaller.
		var rim: bool = ring >= maxf(1.4, max_ring * 0.72)
		items.append({"ch": ch, "p": p, "iso_y": iso.y, "rot": rot, "sc_jit": sc_jit, "ring": ring, "rim": rim})
	items.sort_custom(func(a, b): return a.iso_y < b.iso_y)
	var sc: float = 0.46 if not _use_2x else 0.23
	sc *= world.hive_scale
	for it in items:
		var ch = it.ch
		var p: Vector2 = it.p
		var grow: float = ch.grow
		var rim: bool = bool(it.rim)
		var stage := _plast_stage(ch)
		if rim:
			stage = "rozestaveny"
			grow = minf(grow, 0.55 + 0.2 * _hash2(int(ch.q) + 3, int(ch.r) + 9))
		elif float(it.ring) <= 0.8 and (world.brass_sheen > 0.2 or world.core_pulse > 0.4):
			stage = "zarivy"
		var pname := "apis2_plast_%s" % stage
		var mod := Color(1, 1, 1, 0.4 + grow * 0.55)
		if ch.amber > 0.05 and not rim:
			mod = mod.lerp(Color(1.15, 0.9, 0.45, 0.95), ch.amber * 0.4)
		if world.brass_sheen > 0.0 and not rim:
			mod = mod.lerp(Color(1.2, 0.95, 0.55, 1.0), world.brass_sheen * 0.35)
		if world.rust_chamber != null and world._hex_key(ch.q, ch.r) == world.rust_chamber and world.winter_time == null:
			mod = mod.lerp(Color(0.85, 0.45, 0.3, 0.95), 0.45 + world.cold * 0.3)
		_draw_soft_shadow(p.x, p.y, 8.0 + grow * 4.0, 0.2 + grow * 0.1)
		if atlas.has(pname):
			var core_boost: float = 1.18 - clampf(float(it.ring) / maxf(max_ring, 1.0), 0.0, 1.0) * 0.35
			var psz: float = sc * (0.62 + grow * 0.38) * float(it.sc_jit) * core_boost
			if rim:
				psz *= 0.78
			_blit_rot(pname, p.x, p.y, psz, mod, float(it.rot))
			## Stack height only near center — dome reads as tallest mound.
			if (world.floor2 or world.floor3) and float(it.ring) < max_ring * 0.55 and not rim:
				var stack: Vector2 = Vector2.ZERO
				var e1: Dictionary = atlas[pname]
				if e1.has("stack_offset"):
					stack = e1.stack_offset * psz
				elif atlas.has("apis2_plast_dostaveny") and atlas["apis2_plast_dostaveny"].has("stack_offset"):
					stack = atlas["apis2_plast_dostaveny"].stack_offset * psz
				var upper := "apis2_plast_zarivy" if stage == "zarivy" else "apis2_plast_dostaveny"
				if atlas.has(upper):
					_blit_rot(upper, p.x, p.y, psz, mod, float(it.rot) * 0.5, stack)
					if world.floor3 and float(it.ring) < 1.2:
						_blit_rot(upper, p.x, p.y, psz, mod, float(it.rot) * -0.35, stack * 1.85)
		else:
			var half: float = C.HEX * 0.45 * (0.55 + grow * 0.45)
			var floor_mul: float = 1.35 if world.floor3 else (1.15 if world.floor2 else 1.0)
			_draw_box(p.x, p.y, half, Color(0.7, 0.55, 0.35, 0.55 + grow * 0.35), half * 0.35 * world.hive_scale * floor_mul)
	if world.core != null:
		var ul := "apis2_ul_zarivy" if world.core_pulse > 0.4 or world.brass_sheen > 0.3 else "apis2_ul_dostaveny"
		if world.time < 90.0 and world.chambers.size() < 4:
			ul = "apis2_ul_rozestaveny"
		if atlas.has(ul):
			## Tallest center dome — scale + lift so úl crowns the comb mound.
			var ul_sc: float = (0.62 if not _use_2x else 0.31) * maxf(1.0, world.hive_scale * 0.92)
			var lift := Vector2(0.0, -18.0 - 10.0 * world.hive_scale)
			_blit(ul, world.core.x, world.core.y, ul_sc, Color(1, 1, 1, 0.9 + world.core_pulse * 0.1), lift)
		if atlas.has("apis2_overlay_med") and world.core_pulse > 0.2:
			_blit("apis2_overlay_med", world.core.x, world.core.y, 0.4 if not _use_2x else 0.2, Color(1.35, 1.15, 0.7, 0.25 + world.core_pulse * 0.35), Vector2(0, -22))
	if world.rust_machine != null:
		var rm = world.rust_machine
		if ProArt.has(pro, "apis_rust_machine"):
			ProArt.blit(self, pro, "apis_rust_machine", Iso.world_to_iso(rm.x, rm.y), 0.55 if not _use_2x else 0.28, Color(1, 1, 1, 0.8 if not rm.looted else 0.4))
		elif atlas.has("apis2_kamen_dostaveny"):
			_blit("apis2_kamen_dostaveny", rm.x, rm.y, 0.5 if not _use_2x else 0.25, Color(0.85, 0.55, 0.4, 0.7 if not rm.looted else 0.35))
		else:
			_draw_box(rm.x, rm.y, rm.r * 0.45, Color(0.55, 0.4, 0.3, 0.7), rm.r * 0.3)
	if world.royal_cell != null:
		var cell = world.royal_cell
		var glow: float = cell.glow
		var iso_c := Iso.world_to_iso(cell.x, cell.y)
		if cell.capped and ProArt.has(pro, "apis_royal_cell"):
			ProArt.blit(self, pro, "apis_royal_cell", iso_c, 0.5 if not _use_2x else 0.25, Color(1.15, 1.05, 0.7, 0.75 + glow * 0.25))
		elif ProArt.has(pro, "apis_queen"):
			ProArt.blit(self, pro, "apis_queen", iso_c, 0.55 + glow * 0.1 if not _use_2x else 0.28, Color(1.2, 1.1, 0.7, 0.75 + glow * 0.25))
		elif atlas.has("apis2_plast_zarivy"):
			_blit("apis2_plast_zarivy", cell.x, cell.y, 0.28 if not _use_2x else 0.14, Color(1.35, 1.15, 0.55, 0.65 + glow * 0.3))
			if cell.capped:
				draw_arc(iso_c, 14.0, 0, TAU, 24, Color(1.2, 1.0, 0.55, 0.55 + cell.queen * 0.3), 1.6)
	if world.mvp_end_time != null:
		_draw_ending_planet()


func _draw_flowers() -> void:
	for f in world.flowers:
		var iso := Iso.world_to_iso(f.x, f.y)
		if f.get("tree", false):
			if ProArt.has(pro, "apis_tree_flower"):
				ProArt.blit(self, pro, "apis_tree_flower", iso, 0.6 if not _use_2x else 0.3, Color(1, 1, 1, 0.9))
			elif atlas.has("apis2_louka_ziva_a"):
				_blit("apis2_louka_ziva_a", f.x, f.y, 0.45 if not _use_2x else 0.22, Color(1, 1, 1, 0.8))
				if atlas.has("apis2_overlay_kvet"):
					_blit("apis2_overlay_kvet", f.x, f.y, 0.4 if not _use_2x else 0.2, Color(1.2, 1.1, 0.7, 0.7))
			else:
				_draw_box(f.x, f.y, f.r * 0.45, Color(0.62, 0.55, 0.35, 0.75), f.r * 0.35)
			if world.tree_attract:
				draw_arc(iso, f.r * 0.5 + 8.0 + world.tree_attract_pulse * 6.0, 0, TAU, 28, Color(1.0, 0.82, 0.35, 0.25 + world.tree_attract_pulse * 0.3), 1.4)
		elif atlas.has("apis2_overlay_kvet"):
			_blit("apis2_overlay_kvet", f.x, f.y, 0.28 if not _use_2x else 0.14, Color(1.15, 1.05, 0.75, 0.55 + f.bloom * 0.4))
		else:
			var br: float = f.r * (0.55 + f.bloom * 0.35)
			draw_colored_polygon(_diamond_at(iso, br, br * 0.55), Color(0.7, 0.58, 0.35, 0.7 + f.bloom * 0.2))


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
	## Visual-only stavitelky on the half-built rim (and any still-growing cells).
	var hive := _hive()
	var sc: float = 0.42 if not _use_2x else 0.21
	var max_ring: float = 0.0
	for ch0 in world.chambers.values():
		max_ring = maxf(max_ring, sqrt(float(ch0.q * ch0.q + ch0.r * ch0.r + ch0.q * ch0.r)))
	var drawn := 0
	for ch in world.chambers.values():
		var ring: float = sqrt(float(ch.q * ch.q + ch.r * ch.r + ch.q * ch.r))
		var rim: bool = ring >= maxf(1.4, max_ring * 0.72)
		if ch.grow >= 1.0 and not rim:
			continue
		## Prefer parking stavitelka near unfinished rim cells.
		var p: Vector2 = world._axial_to_pixel(ch.q, ch.r)
		var t: float = fmod(world.time * 0.55 + float(ch.q) * 0.17 + float(ch.r) * 0.13, 1.0)
		if rim:
			t = 0.72 + 0.22 * sin(world.time * 1.1 + float(ch.q))
		var bx: float = lerpf(hive.x, p.x, t)
		var by: float = lerpf(hive.y, p.y, t)
		var dir := _bee_dir(p.x - hive.x, p.y - hive.y)
		var name := "apis2_stavitelka_neseni_%s" % dir
		if not atlas.has(name):
			name = "apis2_stavitelka_%s" % dir
		if atlas.has(name):
			_blit(name, bx, by, sc)
			drawn += 1
			if drawn > 10:
				break


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
		_blit(frame, fx.x, fx.y, sc, Color(1.55, 1.35, 0.95, alpha))


func _draw_edge_fog() -> void:
	## Oversized meadow fill + screen vignette; no circular arcs (dark-ring bug).
	pass


func _draw_soft_shadow(wx: float, wy: float, radius: float, alpha: float = 0.28) -> void:
	var iso := Iso.world_to_iso(wx, wy) + Vector2(3.0, 5.0)
	draw_colored_polygon(_diamond_at(iso, radius * 1.15, radius * 0.55), Color(0.04, 0.02, 0.01, alpha))


func _draw_ending_planet() -> void:
	var vp := get_viewport_rect().size
	var cam := camera.position
	if ProArt.has(pro, "orbit_bg"):
		ProArt.blit(self, pro, "orbit_bg", cam, 0.55 / maxf(camera.zoom.x, 0.2), Color(1, 1, 1, minf(0.85, world.orbit_t * 0.2)))
	var p2 := cam + Vector2(-vp.x * 0.28 / maxf(camera.zoom.x, 0.2), -vp.y * 0.22 / maxf(camera.zoom.y, 0.2))
	var tw: float = 0.4 + 0.6 * abs(sin(world.time * 2.5))
	if ProArt.has(pro, "ending_planet"):
		ProArt.blit(self, pro, "ending_planet", p2, 0.12, Color(1, 1, 1, _other_planet_a * tw * 0.9))
	elif ProArt.has(pro, "menu_mycelium"):
		ProArt.blit(self, pro, "menu_mycelium", p2, 0.08, Color(1, 1, 1, _other_planet_a * tw * 0.85))
	else:
		draw_circle(p2, 7.0, Color(0.4, 0.75, 0.5, _other_planet_a * tw))
		draw_arc(p2, 14.0, 0, TAU, 24, Color(0.35, 0.7, 0.48, _other_planet_a * 0.45), 1.4)
	if ProArt.has(pro, "swarm_logo"):
		ProArt.blit(self, pro, "swarm_logo", cam + Vector2(0, -vp.y * 0.32 / maxf(camera.zoom.y, 0.2)), 0.22, Color(1, 1, 1, minf(1.0, world.orbit_t * 0.25)))
	else:
		var font: Font = STheme.title_font()
		if font == null:
			font = ThemeDB.fallback_font
		draw_string(font, cam + Vector2(-48, -vp.y * 0.32 / maxf(camera.zoom.y, 0.2)), "SWARM", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.95, 0.92, 0.82, minf(1.0, world.orbit_t * 0.25)))


func _draw_guidance() -> void:
	var g = world.guidance()
	if g.get("target") != null:
		var t: Dictionary = g.target
		var c := Iso.world_to_iso(t.x, t.y)
		var ph: float = fmod(world.time, 1.6) / 1.6
		var pulse_i: int = int(floor(fmod(world.time * 6.0, 6.0)))
		var pulse_key := "reticle_apis_pulse_%02d" % pulse_i
		if ProArt.has(pro, pulse_key):
			ProArt.blit(self, pro, pulse_key, c, 0.4 + ph * 0.08, Color(1, 1, 1, 0.55 * (1.0 - ph * 0.5)))
		elif ProArt.has(pro, "reticle_apis"):
			ProArt.blit(self, pro, "reticle_apis", c, 0.38 + ph * 0.1, Color(1, 1, 1, 0.5 * (1.0 - ph)))
		elif ProArt.has(pro, "reticle"):
			ProArt.blit(self, pro, "reticle", c, 0.35 + ph * 0.1, Color(1, 1, 1, 0.45 * (1.0 - ph)))
		else:
			draw_arc(c, float(t.get("r", 16.0)) * 0.55 + ph * 8.0, 0, TAU, 32, Color(1.0, 0.82, 0.4, 0.28 * (1.0 - ph)), 1.4)
