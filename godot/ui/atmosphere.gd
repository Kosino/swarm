extends RefCounted
class_name SwarmAtmosphere
## Shared Build-12 atmosphere: clear color, glow env, canvas mood, soft core light, dust, vignette.
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
		mood.color = Color(1.02, 0.99, 0.94)
	else:
		mood.color = Color(0.96, 1.0, 0.97)
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

	var dust := CPUParticles2D.new()
	dust.name = "AmbientDust"
	dust.amount = SwarmGfx.dust_amount()
	dust.lifetime = 7.0
	dust.preprocess = 3.0 if SwarmGfx.q_level() == 0 else 1.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(520, 320)
	dust.direction = Vector2(0.15, -0.35)
	dust.spread = 50.0
	dust.gravity = Vector2(0, -4)
	dust.initial_velocity_min = 6.0
	dust.initial_velocity_max = 18.0
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.8
	if rod == "apis":
		dust.color = Color(1.0, 0.85, 0.45, 0.35)
	else:
		dust.color = Color(0.55, 0.95, 0.7, 0.3)
	host.add_child(dust)
	nodes["dust"] = dust

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
	mat.set_shader_parameter("strength", 0.32)
	mat.set_shader_parameter("softness", 0.78)
	mat.set_shader_parameter("tint", clear)
	rect.material = mat
	vig_layer.add_child(rect)
	host.add_child(vig_layer)
	nodes["vignette"] = vig_layer

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
	return nodes


static func _vignette_code() -> String:
	return """
shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.0) = 0.32;
uniform float softness : hint_range(0.1, 1.5) = 0.78;
uniform vec4 tint : source_color = vec4(0.02, 0.03, 0.02, 1.0);
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	// Squared radius → fades only near corners/edges, never a mid-frame ring.
	float r = length(uv * vec2(1.0, 1.08));
	float v = smoothstep(softness, 1.55, r) * strength;
	COLOR = vec4(tint.rgb, v);
}
"""


static func sync_light(nodes: Dictionary, world_iso: Vector2, energy: float = -1.0) -> void:
	if not nodes.has("light"):
		return
	var light: PointLight2D = nodes["light"]
	light.global_position = world_iso
	if energy >= 0.0:
		light.energy = energy


static func set_dusk(nodes: Dictionary, dusk: float) -> void:
	if not nodes.has("mood"):
		return
	var mood: CanvasModulate = nodes["mood"]
	## Day → dusk: warmer amber-magenta wash — readable at 11:00 captures.
	var day := Color(1.02, 0.99, 0.94)
	var eve := Color(0.88, 0.72, 0.95)
	mood.color = day.lerp(eve, clampf(dusk, 0.0, 1.0))
	if nodes.has("dust") and dusk > 0.15:
		var dust: CPUParticles2D = nodes["dust"]
		dust.color = Color(1.0, 0.78, 0.55, 0.28 + dusk * 0.2)
