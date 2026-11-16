## Isometric Apis — grey placeholders (atlas optional later).
extends Node2D

const C = preload("res://apis/config.gd")
const Iso = preload("res://apis/iso.gd")

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
var _orbit_done: bool = false
var _other_planet_a: float = 0.0


func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	if "--sim" in args or "sim" in args:
		_run_sim_and_quit()
		return
	if "--demo" in args or "demo" in args:
		demo_on = true
	if OS.has_feature("web"):
		demo_on = true
	_try_load_atlas()
	var opts := {"silent": true, "seed": 42}
	if "--start=10" in args or "start=10" in args:
		opts["startAt"] = 600.0
	world = ApisWorld.new(opts)
	hud.visible = demo_on
	camera.position = Iso.world_to_iso(float(C.W) * 0.5, float(C.H) * 0.48)
	zoom_target = 1.0
	camera.zoom = Vector2(zoom_target, zoom_target)
	queue_redraw()


func _try_load_atlas() -> void:
	## Wire apis_iso_v1 when present under res://art/apis_iso_v1/
	var path := "res://art/apis_iso_v1/godot_atlas.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	# Optional: frames keyed by name → {texture, offset}. Grey fallback if missing.
	atlas = data


func _run_sim_and_quit() -> void:
	var runner := ApisHeadless.new()
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
			get_tree().set_meta("swarm_grown_apis", true)
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
	_draw_meadow()
	_draw_routes_trails()
	_draw_chambers()
	_draw_flowers()
	_draw_workers()
	_draw_guidance()


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
	for ty in range(rows):
		for tx in range(cols):
			var wx: float = (float(tx) + 0.5) * tile
			var wy: float = (float(ty) + 0.5) * tile
			var idx: int = (ty * cols + tx) % 3
			var iso := Iso.world_to_iso(wx, wy)
			var shade := 0.72 - 0.04 * float(idx) - world.dusk * 0.12
			draw_colored_polygon(
				_diamond_at(iso, tile * 0.55, tile * 0.28),
				Color(shade, shade * 0.98, shade * 0.9, 1.0)
			)
	if world.meadow2 != null:
		var m2 = world.meadow2
		var c := Iso.world_to_iso(m2.x, m2.y)
		draw_circle(c, 28.0 + world.meadow_bloom * 8.0, Color(0.7, 0.62, 0.35, 0.22 + world.meadow_bloom * 0.2))


func _draw_routes_trails() -> void:
	var hc := Vector2(world.cx, world.cy)
	if world.core != null:
		hc = Vector2(world.core.x, world.core.y)
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
		for i in range(1, tr.pts.size()):
			var a2 := Iso.world_to_iso(tr.pts[i - 1].x, tr.pts[i - 1].y)
			var b2 := Iso.world_to_iso(tr.pts[i].x, tr.pts[i].y)
			var gold: float = world.highway_glow if tr.kind in ["join", "highway"] else tr.glow
			draw_line(a2, b2, Color(0.72, 0.58, 0.28, 0.3 + gold * 0.4), 2.4, true)
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
		_draw_box(sh.x, sh.y, 14.0, Color(0.55, 0.52, 0.46, 0.75), 10.0 + sh.pulse * 4.0)


func _draw_chambers() -> void:
	if not world.planted:
		_draw_box(world.cx, world.cy, C.HEX * 0.55, Color(0.62, 0.6, 0.55, 0.55 + world.pulse_hex_glow * 0.25))
		return
	# Sort by iso Y for painter's order
	var items: Array = []
	for ch in world.chambers.values():
		var p: Vector2 = world._axial_to_pixel(ch.q, ch.r)
		var iso := Iso.world_to_iso(p.x, p.y)
		items.append({"ch": ch, "p": p, "iso_y": iso.y})
	items.sort_custom(func(a, b): return a.iso_y < b.iso_y)
	for it in items:
		var ch = it.ch
		var p: Vector2 = it.p
		var grow: float = ch.grow
		var half: float = C.HEX * 0.45 * (0.55 + grow * 0.45)
		var floor_mul: float = 1.0
		if world.floor3:
			floor_mul = 1.35
		elif world.floor2:
			floor_mul = 1.15
		var h: float = half * 0.35 * world.hive_scale * floor_mul
		var base := Color(0.52, 0.5, 0.46, 0.55 + grow * 0.35)
		if ch.amber > 0.05:
			base = base.lerp(Color(0.72, 0.58, 0.28, 0.85), ch.amber * 0.55)
		if world.brass_sheen > 0.0:
			base = base.lerp(Color(0.78, 0.62, 0.32, 0.95), world.brass_sheen * 0.45)
		if world.rust_chamber != null and world._hex_key(ch.q, ch.r) == world.rust_chamber and world.winter_time == null:
			base = base.lerp(Color(0.55, 0.35, 0.25, 0.9), 0.45 + world.cold * 0.3)
		_draw_box(p.x, p.y, half, base, h)
	if world.core != null:
		_draw_box(world.core.x, world.core.y, 10.0 * world.hive_scale, Color(0.58, 0.55, 0.48, 0.9), 8.0 + world.core_pulse * 4.0)
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
		else:
			var br: float = f.r * (0.55 + f.bloom * 0.35)
			draw_colored_polygon(_diamond_at(iso, br, br * 0.55), Color(0.55, 0.55, 0.5, 0.7 + f.bloom * 0.2))


func _draw_workers() -> void:
	for w in world.workers:
		var iso := Iso.world_to_iso(w.x, w.y)
		var col := Color(0.85, 0.75, 0.35, 0.95) if w.carrying else Color(0.45, 0.42, 0.38, 0.9)
		draw_circle(iso, 2.2, col)


func _draw_guidance() -> void:
	var g = world.guidance()
	if g.get("target") != null:
		var t: Dictionary = g.target
		var c := Iso.world_to_iso(t.x, t.y)
		var ph: float = fmod(world.time, 1.6) / 1.6
		draw_arc(c, float(t.get("r", 16.0)) * 0.6 + ph * 10.0, 0, TAU, 32, Color(0.75, 0.7, 0.5, 0.35 * (1.0 - ph)), 1.5)
