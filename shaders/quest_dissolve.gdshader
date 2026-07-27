shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint_color : source_color = vec4(0.55, 1.0, 0.72, 1.0);
uniform float softness : hint_range(0.01, 0.35) = 0.12;

float hash12(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void fragment() {
	float noise = hash12(UV * vec2(256.0, 256.0));
	float edge = smoothstep(progress - softness, progress + softness, noise);
	COLOR = vec4(tint_color.rgb, 1.0 - edge);
}
