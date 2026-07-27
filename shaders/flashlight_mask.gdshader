shader_type canvas_item;

uniform vec2 mouse_uv = vec2(0.5, 0.5);
uniform float radius : hint_range(0.03, 0.4) = 0.12;
uniform float softness : hint_range(0.005, 0.2) = 0.05;
uniform float darkness : hint_range(0.0, 1.0) = 0.92;

void fragment() {
	float d = distance(UV, mouse_uv);
	float mask = smoothstep(radius, radius + softness, d);
	COLOR = vec4(0.0, 0.0, 0.0, mask * darkness);
}
