extends RefCounted
class_name SwarmAtmosphere
## Shared atmosphere: clear color, glow, mood, core light, pollen/spore motes, soft vignette + day tint.
## No circular world-space fog arcs (those read as a dark ring).

const STheme = preload("res://ui/swarm_theme.gd")


static func apply(host: Node2D, rod: String, camera: Camera2D, hud: CanvasLayer) -> Dictionary:
	var nodes := {}
	var clear := Color(0.08, 0.1, 0.055) if rod == "mycelium" else Color(0.12, 0.09, 0.05)
	RenderingServer.set_default_clear_color(clear)

	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = SwarmGfx.glow_enabled()
	env.glow_intensity = 0.62 if rod == "apis" else 0.55
	env.glow_strength = 0.95
	env.glow_bloom = 0.14
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.78
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	host.add_child(we)
	nodes["world_env"] = we

	## Keep mood near-white so PointLight falloff never reads as a dark mid-ring.
	var mood := CanvasModulate.new()
	mood.name = "Mood"
	if rod == "apis":
		mood.color = Color(1.04, 1.0, 0.93)
	else:
		mood.color = Color(0.97, 1.02, 0.98)
	host.add_child(mood)
	nodes["mood"] = mood

	var light := PointLight2D.new()
	light.name = "CoreLight"
	light.energy = 0.55 if rod == "apis" else 0.48
	light.color = Color(1.0, 0.86, 0.55) if rod == "apis" else Color(0.6, 0.98, 0.72)
	light.texture_scale = 4.2
	light.range_item_cull_mask = 1
	## Very soft radial falloff (smoothstep) — no hard bright/dark band.
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(256):
			var d: float = Vector2(x - 128, y - 128).length() / 128.0
			var a: float = 1.0 - smoothstep(0.15, 1.0, d)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	light.texture = tex
	host.add_child(light)
	nodes["light"] = light

	var fog := Node2D.new()
	fog.name = "FogLayer"
	fog.z_index = 40
	host.add_child(fog)
	nodes["fog"] = fog

	## Fine ambient haze.
	var dust := _make_particles(
		"AmbientDust",
		SwarmGfx.dust_amount(),
		7.0,
		Vector2(520, 320),
		Vector2(0.12, -0.32),
		50.0,
		Vector2(0, -3.5),
		4.0,
		14.0,
		0.45,
		1.35
	)
	if rod == "apis":
		dust.color = Color(1.0, 0.88, 0.55, 0.28)
	else:
		dust.color = Color(0.62, 0.96, 0.74, 0.26)
	host.add_child(dust)
	nodes["dust"] = dust

	## Larger pollen (Apis) / spore (Mycelium) motes — distinct from fine dust.
	var motes := _make_particles(
		"AmbientMotes",
		SwarmGfx.mote_amount(),
		9.5,
		Vector2(480, 300),
		Vector2(0.28, -0.18) if rod == "apis" else Vector2(0.08, -0.42),
		62.0 if rod == "apis" else 48.0,
		Vector2(0, -2.0) if rod == "apis" else Vector2(0, -6.0),
		5.0,
		16.0,
		0.9,
		2.4
	)
	motes.z_index = 35
	if rod == "apis":
		motes.color = Color(1.0, 0.82, 0.42, 0.42)
	else:
		motes.color = Color(0.72, 0.98, 0.62, 0.38)
	host.add_child(motes)
	nodes["motes"] = motes

	## Soft day-light wash (screen space) — warm meadow / cool canopy.
	var day_layer := CanvasLayer.new()
	day_layer.name = "DayTint"
	day_layer.layer = 48
	var day_rect := ColorRect.new()
	day_rect.name = "DayTintRect"
	day_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	day_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var day_sh := Shader.new()
	day_sh.code = _day_tint_code()
	var day_mat := ShaderMaterial.new()
	day_mat.shader = day_sh
	if rod == "apis":
		day_mat.set_shader_parameter("tint", Color(1.0, 0.9, 0.62, 1.0))
		day_mat.set_shader_parameter("strength", 0.11)
	else:
		day_mat.set_shader_parameter("tint", Color(0.72, 0.95, 0.78, 1.0))
		day_mat.set_shader_parameter("strength", 0.09)
	day_rect.material = day_mat
	day_layer.add_child(day_rect)
	host.add_child(day_layer)
	nodes["day_tint"] = day_layer
	nodes["day_mat"] = day_mat

	## Soft screen-edge vignette only (no circular world ring).
	var vig_layer := CanvasLayer.new()
	vig_layer.name = "Vignette"
	vig_layer.layer = 50
	var rect := ColorRect.new()
	rect.name = "VignetteRect"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = _vignette_code()
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("strength", 0.38)
	mat.set_shader_parameter("softness", 0.72)
	mat.set_shader_parameter("tint", clear.darkened(0.15))
	rect.material = mat
	vig_layer.add_child(rect)
	host.add_child(vig_layer)
	nodes["vignette"] = vig_layer
	nodes["vig_mat"] = mat

	## Theme on HUD controls (CanvasLayer itself has no theme property).
	if hud:
		var theme = STheme.build(rod)
		var panel = hud.get_node_or_null("Panel")
		if panel and panel is Control:
			(panel as Control).theme = theme
		for lab_path in ["Panel/VBox/Clock", "Panel/VBox/Next", "Panel/VBox/Wow", "Panel/VBox/Speed", "Diegetic/Guide"]:
			var lab = hud.get_node_or_null(lab_path)
			if lab and lab is Label:
				var tf = STheme.body_font() if lab_path.ends_with("Guide") or lab_path.ends_with("Next") else STheme.title_font()
				if tf:
					lab.add_theme_font_override("font", tf)
				lab.add_theme_font_size_override("font_size", 15)
		var guide = hud.get_node_or_null("Diegetic/Guide")
		if guide and guide is Label:
			if rod == "apis":
				guide.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65, 0.9))
			else:
				guide.add_theme_color_override("font_color", Color(0.78, 0.92, 0.75, 0.9))

	if camera:
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 4.5
	nodes["rod"] = rod
	return nodes


static func _make_particles(
	pname: String,
	amount: int,
	lifetime: float,
	extents: Vector2,
	direction: Vector2,
	spread: float,
	gravity: Vector2,
	vmin: float,
	vmax: float,
	smin: float,
	smax: float
) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = pname
	p.amount = maxi(amount, 1)
	p.lifetime = lifetime
	p.preprocess = 3.0 if SwarmGfx.q_level() == 0 else 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extents
	p.direction = direction
	p.spread = spread
	p.gravity = gravity
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	p.explosiveness = 0.0
	p.randomness = 0.55
	return p


static func _vignette_code() -> String:
	return """
shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.0) = 0.38;
uniform float softness : hint_range(0.1, 1.5) = 0.72;
uniform vec4 tint : source_color = vec4(0.02, 0.03, 0.02, 1.0);
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	// Squared radius → fades only near corners/edges, never a mid-frame ring.
	float r = length(uv * vec2(1.0, 1.08));
	float v = smoothstep(softness, 1.58, r) * strength;
	COLOR = vec4(tint.rgb, v);
}
"""


static func _day_tint_code() -> String:
	return """
shader_type canvas_item;
uniform float strength : hint_range(0.0, 0.4) = 0.1;
uniform vec4 tint : source_color = vec4(1.0, 0.92, 0.7, 1.0);
void fragment() {
	// Soft multiply wash — stronger at top (sky lean), never a hard band.
	float sky = smoothstep(1.0, 0.15, UV.y);
	float a = strength * (0.55 + 0.45 * sky);
	COLOR = vec4(tint.rgb, a);
}
"""


static func sync_light(nodes: Dictionary, world_iso: Vector2, energy: float = -1.0) -> void:
	if not nodes.has("light"):
		return
	var light: PointLight2D = nodes["light"]
	light.global_position = world_iso
	if energy >= 0.0:
		light.energy = energy


static func sync_particles(nodes: Dictionary, world_iso: Vector2) -> void:
	if nodes.has("dust"):
		(nodes["dust"] as Node2D).global_position = world_iso
	if nodes.has("motes"):
		(nodes["motes"] as Node2D).global_position = world_iso


static func set_dusk(nodes: Dictionary, dusk: float) -> void:
	if not nodes.has("mood"):
		return
	var mood: CanvasModulate = nodes["mood"]
	## Day → dusk: warmer amber-magenta wash — readable at 11:00 captures.
	var day := Color(1.04, 1.0, 0.93)
	var eve := Color(0.88, 0.72, 0.95)
	var d: float = clampf(dusk, 0.0, 1.0)
	mood.color = day.lerp(eve, d)
	if nodes.has("day_mat"):
		var dm: ShaderMaterial = nodes["day_mat"]
		## Day wash fades as dusk takes over.
		dm.set_shader_parameter("strength", lerpf(0.12, 0.04, d))
		dm.set_shader_parameter("tint", Color(1.0, 0.9, 0.62, 1.0).lerp(Color(0.92, 0.7, 0.95, 1.0), d))
	if nodes.has("dust") and d > 0.15:
		var dust: CPUParticles2D = nodes["dust"]
		dust.color = Color(1.0, 0.78, 0.55, 0.26 + d * 0.18)
	if nodes.has("motes") and d > 0.1:
		var motes: CPUParticles2D = nodes["motes"]
		motes.color = Color(1.0, 0.72, 0.48, 0.34 + d * 0.12)


static func set_myc_day(nodes: Dictionary, life: float) -> void:
	## Mycelium day wash — olive → living lime as network brightens (presentation only).
	if not nodes.has("mood"):
		return
	var u: float = clampf(life, 0.0, 1.0)
	var mood: CanvasModulate = nodes["mood"]
	mood.color = Color(0.97, 1.02, 0.98).lerp(Color(0.94, 1.05, 0.96), u * 0.55)
	if nodes.has("day_mat"):
		var dm: ShaderMaterial = nodes["day_mat"]
		dm.set_shader_parameter("strength", lerpf(0.08, 0.13, u))
		dm.set_shader_parameter("tint", Color(0.72, 0.95, 0.78, 1.0).lerp(Color(0.78, 1.0, 0.7, 1.0), u))
	if nodes.has("motes"):
		var motes: CPUParticles2D = nodes["motes"]
		motes.color = Color(0.68, 0.96, 0.6, 0.34 + u * 0.12)
