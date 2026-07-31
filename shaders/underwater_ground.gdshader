shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.10, 0.31, 0.34, 1.0);
uniform vec3 caustic_color : source_color = vec3(0.22, 0.72, 0.76);
uniform float roughness : hint_range(0.0, 1.0) = 0.90;
uniform float caustic_strength : hint_range(0.0, 1.0) = 0.22;
uniform sampler2D seabed_diffuse : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D seabed_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D seabed_displacement : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float texture_strength : hint_range(0.0, 1.0) = 0.70;
uniform float texture_scale : hint_range(0.02, 1.0) = 0.43;

varying vec3 world_position;
varying vec3 world_normal;


float caustic_layer(vec2 position, float time_offset) {
	float line_a = sin(position.x * 2.15 + sin(position.y * 1.62 + time_offset));
	float line_b = sin(position.y * 2.48 - cos(position.x * 1.44 - time_offset * 0.81));
	float cells = abs(line_a + line_b) * 0.5;
	return pow(clamp(1.0 - cells, 0.0, 1.0), 8.0);
}


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}


void fragment() {
	vec3 blend_weights = pow(abs(normalize(world_normal)), vec3(4.0));
	blend_weights /= max(blend_weights.x + blend_weights.y + blend_weights.z, 0.001);
	vec2 texture_uv_x = world_position.zy * texture_scale;
	vec2 texture_uv_y = world_position.xz * texture_scale;
	vec2 texture_uv_z = world_position.xy * texture_scale;

	vec3 texture_color = (
		texture(seabed_diffuse, texture_uv_x).rgb * blend_weights.x
		+ texture(seabed_diffuse, texture_uv_y).rgb * blend_weights.y
		+ texture(seabed_diffuse, texture_uv_z).rgb * blend_weights.z
	);
	float texture_roughness = (
		texture(seabed_roughness, texture_uv_x).r * blend_weights.x
		+ texture(seabed_roughness, texture_uv_y).r * blend_weights.y
		+ texture(seabed_roughness, texture_uv_z).r * blend_weights.z
	);
	float texture_height = (
		texture(seabed_displacement, texture_uv_x).r * blend_weights.x
		+ texture(seabed_displacement, texture_uv_y).r * blend_weights.y
		+ texture(seabed_displacement, texture_uv_z).r * blend_weights.z
	);
	vec3 cold_pebbles = pow(texture_color, vec3(0.86)) * vec3(0.52, 0.72, 0.75);
	cold_pebbles += vec3(0.018, 0.055, 0.060);
	cold_pebbles *= mix(0.88, 1.10, texture_height);
	vec3 textured_base = mix(base_color.rgb, cold_pebbles, texture_strength);

	vec2 pattern_position = world_position.xz * 0.24;
	float caustic = caustic_layer(
		pattern_position + vec2(TIME * 0.18, TIME * 0.11),
		TIME * 0.61
	);
	caustic += caustic_layer(
		pattern_position * 1.31 - vec2(TIME * 0.13, TIME * 0.16),
		-TIME * 0.43
	) * 0.46;
	float below_surface = smoothstep(0.4, 2.4, -world_position.y);
	float deep_fade = 1.0 - smoothstep(12.0, 16.5, -world_position.y);
	float visibility = below_surface * mix(0.34, 1.0, deep_fade);
	float light_pattern = caustic * caustic_strength * visibility;

	ALBEDO = textured_base * (1.0 + light_pattern * 0.58);
	ROUGHNESS = mix(roughness, texture_roughness, texture_strength * 0.72);
	METALLIC = 0.0;
	SPECULAR = 0.32;
	EMISSION = caustic_color * light_pattern * 0.12;
}
