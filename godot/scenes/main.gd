## Isometric Mycelium — atlas art v1 (grey fallback if atlas missing).
extends Node2D

const C = preload("res://mycelium/config.gd")
const Iso = preload("res://mycelium/iso.gd")
const Atlas = preload("res://mycelium/iso_atlas.gd")

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

var panning: bool = false
var pan_last: Vector2 = Vector2.ZERO
var zoom_target: float = 1.0
var atlas: Dictionary = {}
var _drag: bool = false
var _use_2x: bool = false
var _orbit_done: bool = false
var _other_planet_a: float = 0.0


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
	if OS.has_feature("web"):
		demo_on = true

	_use_2x = DisplayServer.screen_get_scale() >= 1.5
	atlas = Atlas.load_all(_use_2x)
	var opts := {"silent": true, "seed": 42}
	if "--start=10" in args or "start=10" in args:
		opts["startAt"] = 600.0
	world = MyceliumWorld.new(opts)
	hud.visible = demo_on
	camera.position = Iso.world_to_iso(float(C.W) * 0.5, float(C.H) * 0.5)
	zoom_target = 1.0
	camera.zoom = Vector2(zoom_target, zoom_target)
	queue_redraw()


func _run_sim_and_quit() -> void:
	var runner := MyceliumHeadless.new()
	var result := runner.run()
	print(JSON.stringify(result, "\t"))
	get_tree().quit(0 if result.get("ok", false) else 1)


func _process(dt: float) -> void:
	if world == null:
		return
	world.update(dt * speed_mul)

	if world.mvp_end_time != null:
		_other_planet_a = minf(1.0, _other_planet_a + dt * 0.35)
		if world.orbit_t > 4.5 and not _orbit_done:
			_orbit_done = true
			get_tree().set_meta("swarm_grown_mycelium", true)
			get_tree().set_meta("swarm_return_choose", true)
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
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


func _draw() -> void:
	if world == null:
		return
	_draw_soil()
	_draw_hyphae()
	_draw_entities()
	_draw_guidance()


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
	var cols: int = world.soil_cols
	var rows: int = world.soil_rows
	var tile: float = float(C.SOIL_TILE)
	var names := ["myc_iso_puda_a", "myc_iso_puda_b", "myc_iso_puda_c"]
	for ty in range(rows):
		for tx in range(cols):
			var wx: float = (float(tx) + 0.5) * tile
			var wy: float = (float(ty) + 0.5) * tile
			var idx: int = int(world.soil_tiles[ty * cols + tx]) if ty * cols + tx < world.soil_tiles.size() else 0
			var n: String = names[clampi(idx, 0, 2)]
			if atlas.has(n):
				_blit(n, wx, wy, 0.5 if not _use_2x else 0.25)
			else:
				var iso := Iso.world_to_iso(wx, wy)
				var shade := 0.18 + 0.04 * float(idx)
				draw_colored_polygon(_diamond_at(iso, tile * 0.5, tile * 0.25), Color(shade, shade, shade * 0.95))


func _diamond_at(center: Vector2, half_w: float, half_h: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -half_h),
		center + Vector2(half_w, 0),
		center + Vector2(0, half_h),
		center + Vector2(-half_w, 0),
	])


func _hyfa_dir(dx: float, dy: float) -> String:
	## Map world delta to NE/SE/NW/SW iso directions.
	var a := atan2(dy, dx)
	# iso axes: NE ≈ -π/4, SE ≈ π/4, SW ≈ 3π/4, NW ≈ -3π/4 in world
	if a >= -PI * 0.25 and a < PI * 0.25:
		return "SE"
	if a >= PI * 0.25 and a < PI * 0.75:
		return "SW"
	if a >= -PI * 0.75 and a < -PI * 0.25:
		return "NE"
	return "NW"


func _draw_hyphae() -> void:
	var bright: float = 1.0 + world.network_bright * 0.55
	var col := Color(1, 1, 1, 0.85 * bright)
	for s in world.segs:
		var dx: float = s.x2 - s.x1
		var dy: float = s.y2 - s.y1
		var dir := _hyfa_dir(dx, dy)
		var name := "myc_iso_hyfa_%s" % dir
		var mx: float = (s.x1 + s.x2) * 0.5
		var my: float = (s.y1 + s.y2) * 0.5
		if atlas.has(name):
			var sc := 0.22 + 0.04 * float(mini(3, int(s.th)))
			if _use_2x:
				sc *= 0.5
			_blit(name, mx, my, sc, col)
		else:
			var a := Iso.world_to_iso(s.x1, s.y1)
			var b := Iso.world_to_iso(s.x2, s.y2)
			draw_line(a, b, Color(0.8, 0.8, 0.8, 0.78 * bright), 1.0 + float(mini(3, int(s.th))) * 0.7, true)
	for t in world.tips:
		var dir2 := _hyfa_dir(cos(t.a), sin(t.a))
		var tip_name := "myc_iso_hyfa_tip_%s" % dir2
		if not atlas.has(tip_name):
			tip_name = "myc_iso_hyfa_tip"
		if atlas.has(tip_name):
			_blit(tip_name, t.x, t.y, 0.35 if not _use_2x else 0.18, col)
		else:
			draw_circle(Iso.world_to_iso(t.x, t.y), 2.0, Color(0.92, 0.92, 0.92, 0.9))


func _draw_entities() -> void:
	var dim: float = 1.0
	if world.dim_all > 0.0:
		dim = maxf(0.15, 1.0 - world.dim_all * 0.85)
	for p in world.patches:
		var name := "myc_iso_kotva" if p.on else "myc_iso_skvrna"
		var sc := 0.55 if p.get("big", false) else 0.4
		if _use_2x:
			sc *= 0.5
		if atlas.has(name):
			_blit(name, p.x, p.y, sc, Color(1, 1, 1, 0.55 + p.lit * 0.4))
		else:
			_draw_box_fallback(p.x, p.y, p.r * 0.7, Color(0.5, 0.5, 0.48, 0.85))

	for m in world.matters:
		var name := ""
		match String(m.kind):
			"machine":
				name = "myc_iso_stroj_obrostly" if m.encircled else "myc_iso_stroj_cely"
			"beetle":
				name = "myc_iso_brouk_obrostly" if m.encircled else "myc_iso_brouk_cely"
			"fruit":
				name = "myc_iso_plodnice"
		var sc := 0.45
		if _use_2x:
			sc *= 0.5
		var alpha := 1.0 - float(m.decay) * 0.35
		if name != "" and atlas.has(name):
			_blit(name, m.x, m.y, sc, Color(1, 1, 1, alpha))
		else:
			_draw_box_fallback(m.x, m.y, m.r * 0.55, Color(0.48, 0.48, 0.46, 0.7 * alpha))

	for g in world.germs:
		# distant seeds reuse zarodek scaled down
		if atlas.has("myc_iso_zarodek"):
			_blit("myc_iso_zarodek", g.x, g.y, 0.22 if not _use_2x else 0.11, Color(0.85, 0.9, 0.8, 0.7 + g.lit * 0.3))
		else:
			draw_circle(Iso.world_to_iso(g.x, g.y), 4.0, Color(0.7, 0.75, 0.65, 0.8))

	if world.seed != null:
		if atlas.has("myc_iso_zarodek"):
			_blit("myc_iso_zarodek", world.seed.x, world.seed.y, 0.5 if not _use_2x else 0.25)
		else:
			draw_circle(Iso.world_to_iso(world.seed.x, world.seed.y), 6.0, Color(0.85, 0.85, 0.82))

	for w in world.workers:
		var pos = world.worker_pos(w)
		var dir := "SE"
		if w.dir < 0:
			dir = "NW"
		var name := "myc_iso_delnik_%s" % dir
		if not atlas.has(name):
			name = "myc_iso_delnik_SE"
		if atlas.has(name):
			_blit(name, pos.x, pos.y, 0.55 if not _use_2x else 0.28)
		else:
			draw_circle(Iso.world_to_iso(pos.x, pos.y), 2.0, Color(0.9, 0.9, 0.9))

	if world.stroke_active and world.stroke.size() > 1:
		for i in range(1, world.stroke.size()):
			var a := Iso.world_to_iso(world.stroke[i - 1].x, world.stroke[i - 1].y)
			var b := Iso.world_to_iso(world.stroke[i].x, world.stroke[i].y)
			draw_line(a, b, Color(0.78, 0.82, 0.74, 0.45), 2.0, true)

	# moist soil under decayed matter
	for m in world.matters:
		if m.encircled and m.kind != "fruit" and atlas.has("myc_iso_puda_vlhka"):
			_blit("myc_iso_puda_vlhka", m.x, m.y, 0.4 if not _use_2x else 0.2, Color(1, 1, 1, 0.35 * m.decay))

	## Age 3 overlays
	if world.infected != null:
		var inf = world.infected
		var ig := Color(0.45, 0.55, 0.4, 0.35 + inf.grey * 0.4) if not inf.dead else Color(0.35, 0.32, 0.28, 0.25)
		_draw_box_fallback(inf.x, inf.y, inf.r * 0.55, ig)
	if world.skeleton != null:
		var sk = world.skeleton
		var alpha: float = 0.75 * (1.0 - float(sk.decay) * 0.5)
		_draw_box_fallback(sk.x, sk.y, sk.r * 0.6, Color(0.55, 0.52, 0.48, alpha))
	if world.giant_fruit != null:
		var gf = world.giant_fruit
		var gr: float = gf.r * (0.35 + gf.grow * 0.65)
		_draw_box_fallback(gf.x, gf.y, gr * 0.55, Color(0.7, 0.72, 0.62, 0.85 * dim))
	if world.seed_capsule != null:
		var sc = world.seed_capsule
		var glow: float = 0.6 + 0.4 * abs(sin(world.time * 3.2))
		draw_circle(Iso.world_to_iso(sc.x, sc.y), 7.0 + sc.pulse * 4.0, Color(0.95, 0.98, 0.7, glow))
	if world.mvp_end_time != null:
		## Distant warm Apis planet glitter (no interaction).
		var vp := get_viewport_rect().size
		var p := Vector2(vp.x * 0.78, vp.y * 0.22)
		var tw: float = 0.4 + 0.6 * abs(sin(world.time * 2.5))
		draw_circle(p, 5.0, Color(0.95, 0.75, 0.3, _other_planet_a * tw))
		draw_arc(p, 10.0, 0, TAU, 20, Color(0.95, 0.7, 0.25, _other_planet_a * 0.45), 1.2)
		draw_string(ThemeDB.fallback_font, Vector2(vp.x * 0.5 - 40, vp.y * 0.12), "SWARM", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.9, 0.92, 0.88, minf(1.0, world.orbit_t * 0.25)))


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
		draw_arc(c, float(t.get("r", 16.0)) * 0.6 + ph * 10.0, 0, TAU, 32, Color(0.85, 0.85, 0.8, 0.35 * (1.0 - ph)), 1.5)
