## Isometric Mycelium — Build 12 pro art (seamless ground, atmosphere, branded UI).
extends Node2D

const C = preload("res://mycelium/config.gd")
const Iso = preload("res://mycelium/iso.gd")
const Atlas = preload("res://mycelium/iso_atlas.gd")
const Atm = preload("res://ui/atmosphere.gd")
const ProArt = preload("res://ui/pro_art.gd")
const STheme = preload("res://ui/swarm_theme.gd")

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
var _drag: bool = false
var _use_2x: bool = false
var _orbit_done: bool = false
var _other_planet_a: float = 0.0
var _autosave_cd: float = 60.0
var _run_seed: int = 42
var _fx: Array = [] ## {seq, x, y, t, life}
var _prev_pulse: float = 0.0
var _prev_bright: float = 0.0


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
		## Snap presentational zoom for deterministic captures.
		world.cam_zoom = world.cam_zoom_target
	SwarmAudio.set_ambient("mycelium")
	_atm = Atm.apply(self, "mycelium", camera, hud)
	hud.visible = demo_on
	camera.position = Iso.world_to_iso(_nest().x, _nest().y)
	zoom_target = 1.0
	camera.zoom = Vector2(zoom_target * world.cam_zoom, zoom_target * world.cam_zoom)
	Atm.sync_light(_atm, camera.position)
	queue_redraw()
	if capture_at >= 0.0 and capture_out != "":
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		if img:
			img.save_png(capture_out)
			print("capture_saved ", capture_out)
		get_tree().quit()


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
	## Soft easing — no hard snaps at growth thresholds.
	camera.zoom = camera.zoom.lerp(Vector2(z, z), 1.0 - exp(-dt * 1.55))
	var nest_iso := Iso.world_to_iso(_nest().x, _nest().y)
	var glow_e: float = 0.38 + world.network_bright * 0.28 + world.network_pulse * 0.2
	Atm.sync_light(_atm, nest_iso, glow_e)
	if _atm.has("dust"):
		(_atm["dust"] as Node2D).global_position = nest_iso
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


func _nest() -> Vector2:
	if world.seed != null:
		return Vector2(world.seed.x, world.seed.y)
	return Vector2(float(C.W) * 0.5, float(C.H) * 0.5)


func _visual_reach() -> float:
	var base: float = 90.0 + float(world.segs.size()) * 0.11 + world.time * 0.22
	if world.big_anchored:
		base += 80.0
	if world.join_time != null:
		base += 60.0
	return clampf(base, 90.0, 520.0)


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


func _spawn_fx(seq: String, x: float, y: float, life: float = 1.0) -> void:
	if not sequences.has(seq):
		return
	_fx.append({"seq": seq, "x": x, "y": y, "t": 0.0, "life": life})


func _tick_fx(dt: float) -> void:
	## Rising pulse / wow → kapka + spóra bursts.
	if world.network_pulse > _prev_pulse + 0.35:
		var nest := _nest()
		_spawn_fx("myc2_fx_kapka", nest.x, nest.y, 1.0)
		_spawn_fx("myc2_fx_spora", nest.x + 12.0, nest.y - 8.0, 1.15)
	if world.network_bright > _prev_bright + 0.45:
		for p in world.patches:
			if p.on and (p.lit > 0.55 or p.get("big", false)):
				_spawn_fx("myc2_fx_spora", p.x, p.y, 1.2)
				break
	_prev_pulse = world.network_pulse
	_prev_bright = world.network_bright
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
	_draw_soil()
	_draw_hyphae()
	_draw_entities()
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
	draw_set_transform(center, rot, Vector2.ONE)
	var half := cell * 0.5
	draw_texture_rect(tex, Rect2(-half, -half, cell, cell), true, modulate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_ground_base() -> void:
	## Continuous iso underlay — never tile zarici full-screen (baked hyphae/spores → hatch carpet).
	var c := Iso.world_to_iso(float(C.W) * 0.5, float(C.H) * 0.5)
	var hw: float = float(C.W) * 1.55
	var hh: float = float(C.H) * 1.05
	draw_colored_polygon(_diamond_at(c, hw * 1.55, hh * 1.55), Color(0.08, 0.1, 0.055, 1.0))
	var t_hola: Texture2D = ProArt.tex(pro, "myc_tex_puda_hola")
	var t_pro: Texture2D = ProArt.tex(pro, "myc_tex_puda_prorostla")
	## Never tile zarici — baked hyphae/spheres read as green hatch patches.
	if t_hola != null:
		var reach: float = _visual_reach()
		var fill := Rect2(c.x - 2200.0, c.y - 1400.0, 4400.0, 2800.0)
		var base: Texture2D = t_hola
		if reach > 180.0 and t_pro != null:
			base = t_pro
		draw_texture_rect(base, fill, true)
		var cell: float = 480.0
		var step: float = 240.0
		var x0: float = c.x - 2200.0
		var y0: float = c.y - 1400.0
		var nx: int = int(ceil(4400.0 / step)) + 1
		var ny: int = int(ceil(2800.0 / step)) + 1
		for iy in range(ny):
			for ix in range(nx):
				var cx: float = x0 + float(ix) * step + cell * 0.5
				var cy: float = y0 + float(iy) * step + cell * 0.5
				var h0: float = _hash2(ix, iy)
				var rot: float = float(int(h0 * 4.0) % 4) * PI * 0.5
				if t_pro != null and base != t_pro and h0 > 0.35:
					_draw_tex_cell(t_pro, Vector2(cx, cy), cell, rot, Color(1, 1, 1, 0.22 + 0.1 * h0))
				if t_hola != null and base != t_hola and _hash2(ix + 3, iy + 5) > 0.55:
					_draw_tex_cell(t_hola, Vector2(cx, cy), cell * 0.9, rot + PI * 0.5, Color(1, 1, 1, 0.18))
	else:
		draw_colored_polygon(_diamond_at(c, hw, hh), Color(0.14, 0.18, 0.1, 1.0))
	_draw_ground_decals()


func _blit(name: String, world_x: float, world_y: float, scale: float = 1.0, modulate: Color = Color.WHITE) -> void:
	if not atlas.has(name):
		return
	var entry: Dictionary = atlas[name]
	var tex: Texture2D = entry.texture
	var off: Vector2 = entry.offset
	var iso: Vector2 = Iso.world_to_iso(world_x, world_y)
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
	for ty in range(rows):
		for tx in range(cols):
			## Sparse soil sprites only — skip ziva diamonds that read as hatch patches.
			if has_fill and ((tx * 5 + ty * 11) % 8) != 0:
				continue
			var wx: float = (float(tx) + 0.5) * tile
			var wy: float = (float(ty) + 0.5) * tile
			var idx: int = int(world.soil_tiles[ty * cols + tx]) if ty * cols + tx < world.soil_tiles.size() else 0
			var variant: String = ["a", "b", "c"][clampi(idx, 0, 2)]
			var stage: String = _terrain_stage(wx, wy)
			if stage == "ziva":
				stage = "prorostla"
			var n := "myc2_puda_%s_%s" % [stage, variant]
			if atlas.has(n):
				var a: float = 0.16 if has_fill else 1.0
				_blit(n, wx, wy, sc, Color(1, 1, 1, a))
			elif not has_fill:
				var iso := Iso.world_to_iso(wx, wy)
				draw_colored_polygon(_diamond_at(iso, tile * 0.56, tile * 0.28), Color(0.16 + 0.03 * idx, 0.2 + 0.02 * idx, 0.11, 1.0))
			## Build 13: no myc2_overlay_prorust — removes green cross-hatch grid patches.


func _draw_ground_decals() -> void:
	## Phase B soil variation — deterministic scatter, no rectangular footprint.
	var nest := _nest()
	var keys := [
		"myc_decal_mech_a", "myc_decal_mech_b", "myc_decal_kamen_a", "myc_decal_kamen_b",
		"myc_decal_listi_a", "myc_decal_listi_b", "myc_decal_koren_a", "myc_decal_koren_b",
		"myc_decal_houbicka", "myc_decal_kvet_mech", "myc_decal_trs_mech", "myc_decal_hyfa_chomac",
	]
	var present: Array = []
	for k in keys:
		if ProArt.has(pro, k):
			present.append(k)
	if present.is_empty():
		return
	var sc: float = 0.42 if not _use_2x else 0.22
	for i in range(48):
		var ang: float = float(i) * 2.399963
		var rad: float = 55.0 + fmod(float(i * 47), 380.0)
		var wx: float = nest.x + cos(ang) * rad
		var wy: float = nest.y + sin(ang) * rad * 0.72
		if wx < -40.0 or wy < -40.0 or wx > float(C.W) + 40.0 or wy > float(C.H) + 40.0:
			continue
		var key: String = present[i % present.size()]
		var a: float = 0.55 if i % 4 == 0 else 0.38
		ProArt.blit(self, pro, key, Iso.world_to_iso(wx, wy), sc * (0.85 + float(i % 5) * 0.06), Color(1, 1, 1, a))


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


func _draw_hyphae() -> void:
	## Organic filaments: glow at core, thin tips — avoid neon hatch carpet of overlapping tenka.
	var bright: float = 1.0 + world.network_bright * 0.35
	var nest := _nest()
	var drawn := 0
	var max_draw := 900
	var i := 0
	var seg_n: int = world.segs.size()
	for s in world.segs:
		i += 1
		var th: int = int(s.th)
		## Skip most tenka — dense parallel thin sprites read as green cross-hatch patches.
		var stride := 1
		if th <= 0:
			stride = 4
		elif th == 1:
			stride = 2
		if (i % stride) != 0:
			continue
		if drawn >= max_draw:
			break
		var dx: float = s.x2 - s.x1
		var dy: float = s.y2 - s.y1
		var dir := _hyfa_dir(dx, dy)
		var mx: float = (s.x1 + s.x2) * 0.5
		var my: float = (s.y1 + s.y2) * 0.5
		var dist_n: float = nest.distance_to(Vector2(mx, my))
		var near_core: bool = dist_n < 180.0
		## Prefer soft glowing trunks; periphery almost exclusively tip-thin.
		var draw_th: int = th
		if dist_n > 220.0:
			draw_th = 0
		elif near_core:
			draw_th = maxi(th, 2 if th >= 1 else 1)
		var thn := _th_name(draw_th)
		## Prefer silna/stredni near core so the network reads as glowing cords, not hatch mesh.
		if near_core and draw_th >= 1:
			thn = "silna" if draw_th >= 2 else "stredni"
		var name := "myc2_hyfa_%s_%s" % [thn, dir]
		var a_iso := Iso.world_to_iso(s.x1, s.y1)
		var b_iso := Iso.world_to_iso(s.x2, s.y2)
		var fuse: float = 0.0
		if s is Dictionary and s.has("fuseGlow"):
			fuse = float(s.fuseGlow)
		var alpha: float = (0.38 + 0.18 * float(mini(3, draw_th))) * minf(1.05, bright)
		if near_core:
			alpha = minf(0.92, alpha + 0.2 + fuse * 0.12)
		var col := Color(1.1 + (0.25 if near_core else 0.0), 1.2 + (0.3 if near_core else 0.05), 0.85, alpha)
		if atlas.has(name):
			var sc := 0.28 + 0.14 * float(mini(3, maxi(draw_th, 1 if near_core else 0)))
			if near_core:
				sc += 0.1
			if _use_2x:
				sc *= 0.5
			## Sprite-only — core glow via brighter silna modulate (no SE/SW line underlay hatch).
			if near_core and draw_th >= 2:
				col = Color(1.55, 1.85, 0.7, minf(0.98, alpha + 0.1 + fuse * 0.12))
				sc *= 1.18
			elif near_core:
				col = Color(1.3, 1.5, 0.7, minf(0.9, alpha + 0.05))
			_blit(name, mx, my, sc, col)
			drawn += 1
		else:
			## Fallback only on atlas miss — keep hairline, never a neon carpet.
			var w: float = 0.55 + float(mini(3, draw_th)) * 0.25
			draw_line(a_iso, b_iso, Color(0.55, 0.8, 0.5, 0.2 * bright), w, true)
			drawn += 1
	## Sparse branch / node accents.
	if atlas.has("myc2_hyfa_uzel_stredni"):
		var shown := 0
		var j := 0
		for s2 in world.segs:
			j += 1
			if int(s2.th) < 2 or (j % 4) != 0:
				continue
			var thn2 := _th_name(int(s2.th))
			var uname := "myc2_hyfa_uzel_%s" % thn2
			if atlas.has(uname):
				_blit(uname, s2.x1, s2.y1, 0.28 if not _use_2x else 0.14, Color(1.35, 1.55, 1.15, 0.55 + world.network_bright * 0.2))
				shown += 1
				if shown > 28:
					break
			if atlas.has("myc2_hyfa_vetveni_%s" % thn2) and shown % 3 == 0:
				_blit("myc2_hyfa_vetveni_%s" % thn2, s2.x2, s2.y2, 0.22 if not _use_2x else 0.11, Color(1.25, 1.45, 1.1, 0.45))
			if ProArt.has(pro, "myc_decal_hyfa_chomac") and shown % 4 == 0:
				ProArt.blit(self, pro, "myc_decal_hyfa_chomac", Iso.world_to_iso(s2.x1, s2.y1), 0.3 if not _use_2x else 0.15, Color(1.15, 1.3, 1.05, 0.45))
	for t in world.tips:
		var dir2 := _hyfa_dir(cos(t.a), sin(t.a))
		## Tips always thin — never escalate with network_bright.
		var tip_name := "myc2_hyfa_tip_tenka_%s" % dir2
		if not atlas.has(tip_name):
			tip_name = "myc2_hyfa_tip"
		if atlas.has(tip_name):
			_blit(tip_name, t.x, t.y, 0.22 if not _use_2x else 0.11, Color(1.15, 1.3, 1.0, 0.42 * bright))
		else:
			draw_circle(Iso.world_to_iso(t.x, t.y), 1.2, Color(0.55, 0.9, 0.65, 0.4))


func _kotva_stage(p: Dictionary) -> String:
	if p.get("big", false) or p.lit > 0.75 or world.network_bright > 0.55:
		return "zariva"
	if p.on and p.lit > 0.25:
		return "dorostla"
	return "rozestavena"


func _draw_entities() -> void:
	var dim: float = 1.0
	if world.dim_all > 0.0:
		dim = maxf(0.15, 1.0 - world.dim_all * 0.85)
	for p in world.patches:
		if not p.on and p.lit < 0.05 and not p.get("big", false):
			continue
		var stage := _kotva_stage(p)
		var name := "myc2_kotva_%s" % stage
		var sc := 0.55 if p.get("big", false) else 0.4
		if _use_2x:
			sc *= 0.5
		_draw_soft_shadow(p.x, p.y, 14.0 if p.get("big", false) else 9.0, 0.22 + p.lit * 0.12)
		if atlas.has(name):
			_blit(name, p.x, p.y, sc, Color(1, 1, 1, 0.55 + p.lit * 0.4))
			## Soft zariva bloom only — never prorust hatch overlays.
			if stage == "zariva" and atlas.has("myc2_overlay_zare") and p.lit > 0.7:
				_blit("myc2_overlay_zare", p.x, p.y, sc * 0.7, Color(1.1, 1.25, 1.05, 0.08 + p.lit * 0.06))
		else:
			_draw_box_fallback(p.x, p.y, p.r * 0.7, Color(0.35, 0.7, 0.45, 0.85))

	for m in world.matters:
		var name := ""
		match String(m.kind):
			"machine", "beetle":
				## No dedicated v2 husks — reuse plodnice stages as organic overgrowth markers.
				if m.encircled:
					name = "myc2_plodnice_dorostla" if m.decay < 0.55 else "myc2_plodnice_zariva"
				else:
					name = "myc2_plodnice_rozestavena"
			"fruit":
				if world.network_bright > 0.5 or world.spore_time != null:
					name = "myc2_plodnice_zariva"
				elif m.encircled or world.fruit_time != null:
					name = "myc2_plodnice_dorostla"
				else:
					name = "myc2_plodnice_rozestavena"
		var sc := 0.45
		if _use_2x:
			sc *= 0.5
		var alpha := 1.0 - float(m.decay) * 0.35
		if name != "" and atlas.has(name):
			_blit(name, m.x, m.y, sc, Color(1, 1, 1, alpha))
		else:
			_draw_box_fallback(m.x, m.y, m.r * 0.55, Color(0.4, 0.65, 0.45, 0.7 * alpha))

	for g in world.germs:
		var gstage := "rozestavena"
		if g.linked or g.lit > 0.4:
			gstage = "dorostla"
		if g.lit > 0.75 or world.network_bright > 0.6:
			gstage = "zariva"
		var gname := "myc2_zarodek_%s" % gstage
		if atlas.has(gname):
			_blit(gname, g.x, g.y, 0.22 if not _use_2x else 0.11, Color(0.85, 0.95, 0.8, 0.7 + g.lit * 0.3))
		else:
			draw_circle(Iso.world_to_iso(g.x, g.y), 4.0, Color(0.45, 0.85, 0.55, 0.8))

	if world.seed != null:
		var sstage := "dorostla"
		if world.network_bright > 0.45 or world.big_anchored:
			sstage = "zariva"
		elif world.segs.size() < 40:
			sstage = "rozestavena"
		var sname := "myc2_zarodek_%s" % sstage
		if atlas.has(sname):
			_blit(sname, world.seed.x, world.seed.y, 0.5 if not _use_2x else 0.25)
		else:
			draw_circle(Iso.world_to_iso(world.seed.x, world.seed.y), 6.0, Color(0.5, 0.9, 0.6))

	## Translucent yellow-green spores/workers — ~50% smaller, spaced (~1 / 40px hypha).
	var drawn_workers: Array = []
	for w in world.workers:
		var pos = world.worker_pos(w)
		var px: float = float(pos.x)
		var py: float = float(pos.y)
		var too_close := false
		for prev in drawn_workers:
			if Vector2(px, py).distance_to(prev) < 40.0:
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
		var wsc: float = 0.36 if not _use_2x else 0.18
		_draw_soft_shadow(px, py, 2.5, 0.14)
		if atlas.has(name):
			## Translucent yellow-green spore look (modulate overcomes dark delnik base).
			_blit(name, px, py, wsc, Color(1.55, 1.85, 0.55, 0.62))
		else:
			draw_circle(Iso.world_to_iso(px, py), 1.4, Color(0.85, 1.0, 0.35, 0.55))
		drawn_workers.append(Vector2(px, py))

	if world.stroke_active and world.stroke.size() > 1:
		for i in range(1, world.stroke.size()):
			var a := Iso.world_to_iso(world.stroke[i - 1].x, world.stroke[i - 1].y)
			var b := Iso.world_to_iso(world.stroke[i].x, world.stroke[i].y)
			## Soft guidance stroke — never a neon slash.
			draw_line(a, b, Color(0.55, 0.85, 0.65, 0.28), 1.6, true)

	## Build 13: no matter-site prorust hatch overlays.

	## Age 3 — pro_v3 sprites (no procedural boxes when pack present).
	if world.infected != null:
		var inf = world.infected
		var ikey := "myc_infected"
		if ProArt.has(pro, "myc_infected_beetle") and int(inf.x * 3.0 + inf.y) % 2 == 0:
			ikey = "myc_infected_beetle"
		if ProArt.has(pro, ikey):
			ProArt.blit(self, pro, ikey, Iso.world_to_iso(inf.x, inf.y), 0.55 if not _use_2x else 0.28, Color(1, 1, 1, 0.75 + inf.grey * 0.2))
		elif atlas.has("myc2_plodnice_dorostla"):
			_blit("myc2_plodnice_dorostla", inf.x, inf.y, 0.5 if not _use_2x else 0.25, Color(0.55, 0.7, 0.45, 0.55 + inf.grey * 0.3))
	if world.skeleton != null:
		var sk = world.skeleton
		var alpha: float = 0.75 * (1.0 - float(sk.decay) * 0.5)
		if ProArt.has(pro, "myc_skeleton"):
			ProArt.blit(self, pro, "myc_skeleton", Iso.world_to_iso(sk.x, sk.y), 0.7 if not _use_2x else 0.35, Color(1, 1, 1, alpha))
		elif atlas.has("myc2_kotva_dorostla"):
			_blit("myc2_kotva_dorostla", sk.x, sk.y, 0.55 if not _use_2x else 0.28, Color(0.75, 0.7, 0.6, alpha))
	if world.giant_fruit != null:
		var gf = world.giant_fruit
		if ProArt.has(pro, "myc_giant_fruit"):
			ProArt.blit(self, pro, "myc_giant_fruit", Iso.world_to_iso(gf.x, gf.y), 0.65 + gf.grow * 0.35 if not _use_2x else 0.32 + gf.grow * 0.18, Color(1, 1, 1, 0.9 * dim))
		else:
			var gfn := "myc2_plodnice_zariva" if gf.grow > 0.7 else ("myc2_plodnice_dorostla" if gf.grow > 0.3 else "myc2_plodnice_rozestavena")
			if atlas.has(gfn):
				_blit(gfn, gf.x, gf.y, 0.7 + gf.grow * 0.4 if not _use_2x else 0.35 + gf.grow * 0.2, Color(1.2, 1.25, 1.05, 0.9 * dim))
	if world.seed_capsule != null:
		var sc = world.seed_capsule
		var glow: float = 0.6 + 0.4 * abs(sin(world.time * 3.2))
		if ProArt.has(pro, "myc_seed_capsule"):
			ProArt.blit(self, pro, "myc_seed_capsule", Iso.world_to_iso(sc.x, sc.y), 0.55 if not _use_2x else 0.28, Color(1.15, 1.2, 1.0, glow))
		elif atlas.has("myc2_zarodek_zariva"):
			_blit("myc2_zarodek_zariva", sc.x, sc.y, 0.45 if not _use_2x else 0.22, Color(1.3, 1.35, 1.1, glow))
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
	## Screen-space overlays relative to camera center.
	if ProArt.has(pro, "orbit_bg"):
		ProArt.blit(self, pro, "orbit_bg", cam, 0.55 / maxf(camera.zoom.x, 0.2), Color(1, 1, 1, minf(0.85, world.orbit_t * 0.2)))
	var p := cam + Vector2(vp.x * 0.28 / maxf(camera.zoom.x, 0.2), -vp.y * 0.22 / maxf(camera.zoom.y, 0.2))
	var tw: float = 0.4 + 0.6 * abs(sin(world.time * 2.5))
	if ProArt.has(pro, "ending_planet"):
		ProArt.blit(self, pro, "ending_planet", p, 0.12, Color(1, 1, 1, _other_planet_a * tw * 0.9))
	elif ProArt.has(pro, "menu_apis"):
		ProArt.blit(self, pro, "menu_apis", p, 0.08, Color(1, 1, 1, _other_planet_a * tw * 0.85))
	else:
		draw_circle(p, 7.0, Color(0.95, 0.75, 0.3, _other_planet_a * tw))
		draw_arc(p, 14.0, 0, TAU, 24, Color(0.95, 0.7, 0.25, _other_planet_a * 0.45), 1.4)
	if ProArt.has(pro, "swarm_logo"):
		ProArt.blit(self, pro, "swarm_logo", cam + Vector2(0, -vp.y * 0.32 / maxf(camera.zoom.y, 0.2)), 0.22, Color(1, 1, 1, minf(1.0, world.orbit_t * 0.25)))
	else:
		var font: Font = STheme.title_font()
		if font == null:
			font = ThemeDB.fallback_font
		draw_string(font, cam + Vector2(-48, -vp.y * 0.32 / maxf(camera.zoom.y, 0.2)), "SWARM", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.92, 0.95, 0.88, minf(1.0, world.orbit_t * 0.25)))


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
