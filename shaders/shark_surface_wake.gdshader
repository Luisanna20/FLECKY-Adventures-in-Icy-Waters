shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 foam_color : source_color = vec4(0.76, 0.95, 0.99, 0.52);
uniform float wake_strength : hint_range(0.0, 1.0) = 0.0;


void fragment() {
	float fade_behind = pow(1.0 - UV.y, 0.82);
	float broken_line = (
		sin(UV.y * 31.0 - TIME * 4.2 + UV.x * 5.0) * 0.5 + 0.5
	);
	broken_line = mix(0.28, 1.0, smoothstep(0.30, 0.76, broken_line));
	float edge_softness = smoothstep(0.0, 0.22, UV.x)
		* (1.0 - smoothstep(0.78, 1.0, UV.x));
	ALBEDO = foam_color.rgb;
	EMISSION = foam_color.rgb * 0.045;
	ROUGHNESS = 0.74;
	ALPHA = foam_color.a
		* fade_behind
		* broken_line
		* edge_softness
		* wake_strength;
}
