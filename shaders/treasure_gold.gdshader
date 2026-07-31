shader_type spatial;
render_mode cull_disabled;

uniform vec4 gold_color : source_color = vec4(1.0, 0.57, 0.08, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.30, 0.025, 1.0);


void fragment() {
	float pulse = 0.72 + sin(TIME * 2.65 + UV.x * 8.0 + UV.y * 5.0) * 0.28;
	float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 2.2);
	ALBEDO = gold_color.rgb;
	METALLIC = 0.88;
	ROUGHNESS = 0.24;
	EMISSION = glow_color.rgb * (0.30 + pulse * 0.45 + rim * 0.42);
}
