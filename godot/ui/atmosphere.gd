extends RefCounted
class_name SwarmAtmosphere
## Shared Build-12 atmosphere: clear color, glow env, canvas mood, core light, fog, particles, vignette.

const STheme = preload("res://ui/swarm_theme.gd")


static func apply(host: Node2D, rod: String, camera: Camera2D, hud: CanvasLayer) -> Dictionary:
	var nodes := {}
	var clear := Color(0.08, 0.1, 0.055) if rod == "mycelium" else Color(0.12, 0.09, 0.05)
	RenderingServer.set_default_clear_color(clear)

	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.55 if rod == "apis" else 0.48
	env.glow_strength = 0.9
	env.glow_bloom = 0.12
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	host.add_child(we)
	nodes["world_env"] = we

	var mood := CanvasModulate.new()
	mood.name = "Mood"
	if rod == "apis":
		mood.color = Color(1.05, 0.98, 0.88)
	else:
		mood.color = Color(0.88, 0.98, 0.9)
	host.add_child(mood)
	nodes["mood"] = mood

	var light := PointLight2D.new()
	light.name = "CoreLight"
	light.energy = 0.85 if rod == "apis" else 0.7
	light.color = Color(1.0, 0.82, 0.45) if rod == "apis" else Color(0.55, 0.95, 0.65)
	light.texture_scale = 2.8
	light.range_item_cull_mask = 1
	## Soft circular falloff via generated texture.
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var d: float = Vector2(x - 64, y - 64).length() / 64.0
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a
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
	dust.amount = 36
	dust.lifetime = 7.0
	dust.preprocess = 3.0
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

	## Vignette overlay (screen space).
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
	mat.set_shader_parameter("strength", 0.58)
	mat.set_shader_parameter("softness", 0.62)
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
uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform float softness : hint_range(0.1, 1.5) = 0.65;
uniform vec4 tint : source_color = vec4(0.02, 0.03, 0.02, 1.0);
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv * vec2(1.0, 1.05));
	float v = smoothstep(softness, 1.35, r) * strength;
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
	## Day → dusk: cooler magenta-amber wash for Apis.
	var day := Color(1.05, 0.98, 0.88)
	var eve := Color(0.85, 0.72, 0.95)
	mood.color = day.lerp(eve, clampf(dusk, 0.0, 1.0))
