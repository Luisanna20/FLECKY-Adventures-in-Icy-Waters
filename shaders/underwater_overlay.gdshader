shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float underwater_amount : hint_range(0.0, 1.0) = 0.0;


float caustic_layer(vec2 position, float time_offset) {
	float line_a = sin(position.x * 2.35 + sin(position.y * 1.72 + time_offset));
	float line_b = sin(position.y * 2.66 - cos(position.x * 1.48 - time_offset * 0.83));
	float cells = abs(line_a + line_b) * 0.5;
	return pow(clamp(1.0 - cells, 0.0, 1.0), 7.0);
}


void fragment() {
	vec2 slow_wave = vec2(
		sin(SCREEN_UV.y * 34.0 + TIME * 1.18) + sin(SCREEN_UV.y * 71.0 - TIME * 0.53) * 0.35,
		cos(SCREEN_UV.x * 29.0 - TIME * 0.86) + cos(SCREEN_UV.x * 63.0 + TIME * 0.47) * 0.30
	);
	vec2 distortion = slow_wave * 0.00062 * underwater_amount;
	vec3 scene_color = texture(screen_texture, SCREEN_UV + distortion).rgb;

	float chromatic_shift = 0.00042 * underwater_amount;
	scene_color.r = texture(screen_texture, SCREEN_UV + distortion + vec2(chromatic_shift, 0.0)).r;
	scene_color.b = texture(screen_texture, SCREEN_UV + distortion - vec2(chromatic_shift, 0.0)).b;

	vec3 cold_color = scene_color * vec3(0.82, 1.00, 1.055) + vec3(0.004, 0.038, 0.050);
	vec2 caustic_position = SCREEN_UV * vec2(19.0, 12.0);
	float caustic = caustic_layer(caustic_position + vec2(TIME * 0.22, TIME * 0.12), TIME * 0.74);
	caustic += caustic_layer(caustic_position * 1.34 - vec2(TIME * 0.16, TIME * 0.20), -TIME * 0.51) * 0.48;
	caustic *= 0.0022 * underwater_amount;
	caustic *= mix(0.38, 1.0, 1.0 - SCREEN_UV.y);
	cold_color += vec3(0.18, 0.73, 0.87) * caustic;

	float ray_pattern = pow(max(sin(SCREEN_UV.x * 31.0 + TIME * 0.10), 0.0), 10.0);
	float ray_falloff = smoothstep(0.92, 0.08, SCREEN_UV.y) * (1.0 - SCREEN_UV.y);
	cold_color += vec3(0.10, 0.34, 0.38) * ray_pattern * ray_falloff * 0.022 * underwater_amount;

	float edge = smoothstep(0.30, 0.74, distance(UV, vec2(0.5)));
	cold_color -= edge * 0.022;
	COLOR = vec4(mix(scene_color, cold_color, underwater_amount), 1.0);
}
