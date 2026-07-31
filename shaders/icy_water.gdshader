shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 shallow_color : source_color = vec4(0.035, 0.44, 0.55, 0.19);
uniform vec4 mid_color : source_color = vec4(0.012, 0.27, 0.41, 0.35);
uniform vec4 deep_color : source_color = vec4(0.004, 0.11, 0.23, 0.58);
uniform vec4 sky_reflection_color : source_color = vec4(0.14, 0.48, 0.60, 1.0);
uniform vec4 horizon_reflection_color : source_color = vec4(0.44, 0.72, 0.78, 1.0);
uniform vec4 crest_color : source_color = vec4(0.79, 0.96, 0.98, 1.0);
uniform float wave_height : hint_range(0.0, 0.8) = 0.255;
uniform float wave_speed : hint_range(0.0, 3.0) = 0.62;
uniform float refraction_strength : hint_range(0.0, 0.08) = 0.0072;
uniform float absorption_strength : hint_range(0.01, 1.0) = 0.18;
uniform float foam_width : hint_range(0.05, 2.0) = 0.38;
uniform vec3 sun_direction = vec3(-0.289, 0.788, 0.544);
uniform vec2 swimmer_position = vec2(1000.0, 1000.0);
uniform vec2 swimmer_forward = vec2(0.0, -1.0);
uniform float swimmer_speed : hint_range(0.0, 1.0) = 0.0;
uniform float swimmer_surface : hint_range(0.0, 1.0) = 0.0;

varying float crest;
varying vec2 water_position;
varying float swimmer_wake;
varying vec2 vertex_slope;


vec2 wave_direction(float x, float y) {
	return normalize(vec2(x, y));
}


void add_wave(
	vec2 position,
	vec2 direction,
	float frequency,
	float amplitude,
	float speed,
	float steepness,
	inout float height,
	inout vec2 slope,
	inout vec2 horizontal
) {
	float phase = dot(position, direction) * frequency + TIME * speed;
	height += sin(phase) * amplitude;
	slope += cos(phase) * amplitude * frequency * direction;
	horizontal += direction * cos(phase) * amplitude * steepness;
}


void vertex() {
	vec2 position = VERTEX.xz;
	float height = 0.0;
	vec2 slope = vec2(0.0);
	vec2 horizontal = vec2(0.0);

	add_wave(position, wave_direction(1.0, 0.24), 0.145, wave_height * 0.43, wave_speed, 0.34, height, slope, horizontal);
	add_wave(position, wave_direction(-0.35, 1.0), 0.205, wave_height * 0.27, wave_speed * 0.83, 0.28, height, slope, horizontal);
	add_wave(position, wave_direction(0.72, -1.0), 0.315, wave_height * 0.18, wave_speed * 1.22, 0.20, height, slope, horizontal);
	add_wave(position, wave_direction(-1.0, -0.58), 0.48, wave_height * 0.12, wave_speed * 1.55, 0.14, height, slope, horizontal);
	add_wave(position, wave_direction(0.18, 1.0), 0.82, wave_height * 0.032, wave_speed * 2.05, 0.05, height, slope, horizontal);

	vec2 wake_forward = normalize(swimmer_forward + vec2(0.0001));
	vec2 wake_side = vec2(-wake_forward.y, wake_forward.x);
	vec2 from_swimmer = position - swimmer_position;
	float wake_behind = max(-dot(from_swimmer, wake_forward), 0.0);
	float wake_lateral = abs(dot(from_swimmer, wake_side));
	float wake_length_mask = smoothstep(0.12, 0.95, wake_behind) * exp(-wake_behind * 0.17);
	float wake_width_mask = exp(-wake_lateral * wake_lateral * 0.82);
	float wake_wave = sin(wake_behind * 3.85 + wake_lateral * 2.4 - TIME * 1.1);
	float bow_distance = length(from_swimmer - wake_forward * 0.28);
	float bow_mask = exp(-bow_distance * bow_distance * 1.55);
	float interaction = swimmer_surface * swimmer_speed;
	height += wake_wave * wake_length_mask * wake_width_mask * interaction * 0.065;
	height += bow_mask * interaction * 0.045;
	swimmer_wake = clamp(
		(wake_length_mask * wake_width_mask * (0.52 + wake_wave * 0.48) + bow_mask)
		* interaction,
		0.0,
		1.0
	);

	float plane_edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	horizontal *= smoothstep(0.0, 0.055, plane_edge);
	VERTEX.xz += horizontal;
	VERTEX.y += height;
	NORMAL = normalize(vec3(-slope.x, 1.0, -slope.y));
	crest = height / max(wave_height, 0.001);
	water_position = position + horizontal;
	vertex_slope = slope;
}


vec3 reconstruct_view_position(
	vec2 screen_uv,
	float raw_depth,
	mat4 inverse_projection
) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(screen_uv, raw_depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, raw_depth);
#endif
	vec4 view_position = inverse_projection * vec4(ndc, 1.0);
	return view_position.xyz / max(view_position.w, 0.00001);
}


float circular_edge(vec2 position, vec2 center, float radius, float width) {
	float edge_distance = abs(length(position - center) - radius);
	return 1.0 - smoothstep(width * 0.18, width, edge_distance);
}


float contact_foam_mask(vec2 position, float detail_wave) {
	float floe_foam = 0.0;
	floe_foam = max(floe_foam, circular_edge(position, vec2(-25.0, -15.0), 7.6, foam_width));
	floe_foam = max(floe_foam, circular_edge(position, vec2(18.0, -27.0), 6.8, foam_width));
	floe_foam = max(floe_foam, circular_edge(position, vec2(32.0, 10.0), 8.4, foam_width));
	floe_foam = max(floe_foam, circular_edge(position, vec2(-29.0, 27.0), 7.2, foam_width));
	floe_foam = max(floe_foam, circular_edge(position, vec2(3.0, 34.0), 5.8, foam_width));
	float shore_distance = abs(length(position) - 63.8);
	float shore_foam = 1.0 - smoothstep(0.08, 1.35, shore_distance);
	float edge_variation = detail_wave + sin(
		position.x * 2.7 + position.y * 3.1 - TIME * 0.72
	) * 0.22;
	float broken_edge = smoothstep(-0.02, 0.58, edge_variation);
	return clamp(max(floe_foam, shore_foam * 0.76) * broken_edge, 0.0, 1.0);
}


void fragment() {
	vec2 direction_a = normalize(vec2(0.91, 0.41));
	vec2 direction_b = normalize(vec2(-0.37, 0.93));
	vec2 direction_c = normalize(vec2(0.68, -0.73));
	vec2 direction_d = normalize(vec2(-0.84, -0.54));

	float phase_a = dot(water_position, direction_a) * 2.05 + TIME * 1.16;
	float phase_b = dot(water_position, direction_b) * 2.91 - TIME * 1.34;
	float phase_c = dot(water_position, direction_c) * 5.35 + TIME * 1.82;
	float phase_d = dot(water_position, direction_d) * 8.40 - TIME * 2.26;
	float detail_wave = (
		sin(phase_a) * 0.37
		+ sin(phase_b) * 0.29
		+ sin(phase_c) * 0.21
		+ sin(phase_d) * 0.13
	);
	vec2 detail_slope = (
		direction_a * cos(phase_a) * 0.56
		+ direction_b * cos(phase_b) * 0.42
		+ direction_c * cos(phase_c) * 0.22
		+ direction_d * cos(phase_d) * 0.10
	);
	vec2 combined_slope = detail_slope + vertex_slope * 1.8;
	NORMAL_MAP = normalize(vec3(combined_slope * 0.095, 1.0));
	NORMAL_MAP_DEPTH = 0.34;

	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.05);

	float raw_scene_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec3 scene_view_position = reconstruct_view_position(
		SCREEN_UV,
		raw_scene_depth,
		INV_PROJECTION_MATRIX
	);
	float scene_depth = max(-scene_view_position.z, 0.0);
	float surface_depth = max(-VERTEX.z, 0.0);
	float sampled_thickness = max(scene_depth - surface_depth, 0.0);
	float valid_depth = smoothstep(0.045, 0.22, sampled_thickness);
	float fallback_thickness = 2.4 + fresnel * 4.8;
	float optical_depth = mix(
		fallback_thickness,
		clamp(sampled_thickness, 0.0, 18.0),
		valid_depth
	);
	float depth_amount = 1.0 - exp(-optical_depth * absorption_strength);
	float deep_amount = smoothstep(0.28, 0.88, depth_amount);

	vec2 refraction_offset = combined_slope * refraction_strength * (0.24 + facing * 0.76);
	refraction_offset += NORMAL.xy * refraction_strength * 0.22;
	vec2 refracted_uv = clamp(SCREEN_UV + refraction_offset, vec2(0.002), vec2(0.998));
	float refraction_lod = mix(0.0, 1.25, deep_amount);
	vec3 refracted_scene = textureLod(screen_texture, refracted_uv, refraction_lod).rgb;

	vec3 absorption = exp(
		-vec3(0.34, 0.105, 0.038) * optical_depth * absorption_strength * 2.0
	);
	vec3 transmitted_scene = refracted_scene * absorption * vec3(0.82, 0.98, 1.04);
	vec3 volume_color = mix(
		shallow_color.rgb,
		mix(mid_color.rgb, deep_color.rgb, deep_amount),
		depth_amount
	);
	float volume_mix = mix(0.18, 0.68, depth_amount);
	vec3 final_color = mix(transmitted_scene, volume_color, volume_mix);

	float reflected_height = clamp(0.30 + facing * 0.70 + detail_wave * 0.06, 0.0, 1.0);
	vec3 reflected_sky = mix(
		sky_reflection_color.rgb,
		horizon_reflection_color.rgb,
		reflected_height
	);
	final_color = mix(final_color, reflected_sky, fresnel * 0.46);

	float crest_line = smoothstep(0.48, 0.92, crest + detail_wave * 0.10);
	float micro_glint = smoothstep(0.94, 0.998, detail_wave * 0.5 + 0.5);
	vec3 world_surface_normal = normalize(vec3(
		-combined_slope.x * 0.15,
		1.0,
		-combined_slope.y * 0.15
	));
	vec3 world_surface_position = vec3(water_position.x, 0.0, water_position.y);
	vec3 direction_to_camera = normalize(CAMERA_POSITION_WORLD - world_surface_position);
	vec3 sun_half_direction = normalize(direction_to_camera + normalize(sun_direction));
	float sun_reflection = pow(
		max(dot(world_surface_normal, sun_half_direction), 0.0),
		190.0
	);
	float sparkle = sun_reflection * (0.40 + micro_glint * 0.60);
	float contact_foam = contact_foam_mask(water_position, detail_wave + crest * 0.75);
	float foam = clamp(
		contact_foam * 0.72
		+ crest_line * 0.12
		+ swimmer_wake * 0.52,
		0.0,
		1.0
	);
	final_color = mix(final_color, crest_color.rgb, foam * 0.52);
	final_color = mix(final_color, horizon_reflection_color.rgb, sparkle * 0.58);

	ALBEDO = final_color;
	METALLIC = 0.02;
	ROUGHNESS = clamp(
		mix(0.18, 0.045, fresnel)
		+ foam * 0.34
		- sparkle * 0.035,
		0.035,
		0.62
	);
	SPECULAR = 0.96;
	EMISSION = crest_color.rgb * (
		sparkle * 0.12
		+ foam * 0.012
	);
	ALPHA = clamp(
		mix(shallow_color.a, deep_color.a, depth_amount)
		+ fresnel * 0.25
		+ foam * 0.16,
		0.20,
		0.82
	);
}
