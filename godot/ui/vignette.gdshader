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
