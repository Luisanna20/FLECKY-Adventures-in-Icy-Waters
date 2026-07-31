shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.025, 0.095, 0.18);
uniform vec3 horizon_color : source_color = vec3(0.22, 0.46, 0.56);
uniform vec3 lower_sky_color : source_color = vec3(0.035, 0.15, 0.23);
uniform vec3 aurora_green : source_color = vec3(0.20, 0.92, 0.62);
uniform vec3 aurora_cyan : source_color = vec3(0.18, 0.70, 0.91);
uniform float aurora_brightness : hint_range(0.0, 2.0) = 0.76;
uniform float aurora_speed : hint_range(0.0, 1.0) = 0.055;
uniform vec3 sun_direction = vec3(-0.289, 0.788, 0.544);
uniform vec3 sun_color : source_color = vec3(1.0, 0.89, 0.68);
uniform float sun_brightness : hint_range(0.0, 4.0) = 1.35;


float random_value(vec2 position) {
	return fract(sin(dot(position, vec2(127.1, 311.7))) * 43758.5453);
}


float smooth_noise(vec2 position) {
	vec2 cell = floor(position);
	vec2 local = fract(position);
	local = local * local * (3.0 - 2.0 * local);
	float a = random_value(cell);
	float b = random_value(cell + vec2(1.0, 0.0));
	float c = random_value(cell + vec2(0.0, 1.0));
	float d = random_value(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}


float layered_noise(vec2 position) {
	float value = 0.0;
	float amplitude = 0.55;
	for (int index = 0; index < 4; index++) {
		value += smooth_noise(position) * amplitude;
		position = position * 1.93 + vec2(7.4, 3.8);
		amplitude *= 0.48;
	}
	return value;
}


void sky() {
	vec3 direction = normalize(EYEDIR);
	float upper = clamp(direction.y, 0.0, 1.0);
	float horizon_glow = pow(1.0 - abs(direction.y), 3.2);
	vec3 sky_color = mix(horizon_color, zenith_color, smoothstep(0.02, 0.86, upper));
	if (direction.y < 0.0) {
		sky_color = mix(horizon_color, lower_sky_color, smoothstep(0.0, 0.72, -direction.y));
	}
	sky_color += vec3(0.035, 0.075, 0.085) * horizon_glow;

	if (direction.y > -0.03) {
		float azimuth = atan(direction.z, direction.x);
		float time = TIME * aurora_speed;
		float broad_warp = layered_noise(vec2(azimuth * 0.72 + time, direction.y * 2.4 - time * 0.31));
		float lower_edge = 0.018 + sin(azimuth * 2.7 + time * 1.3) * 0.035 + broad_warp * 0.040;
		float height_mask = smoothstep(lower_edge, lower_edge + 0.070, direction.y);
		height_mask *= 1.0 - smoothstep(0.64, 0.94, direction.y);
		height_mask *= smoothstep(-0.03, 0.045, direction.y);

		float narrow_warp = layered_noise(vec2(azimuth * 2.1 - time * 0.73, direction.y * 5.2 + time * 0.24));
		float curtain_wave = sin(azimuth * 13.5 + narrow_warp * 5.8 + time * 1.8);
		float curtains = pow(clamp(curtain_wave * 0.5 + 0.5, 0.0, 1.0), 2.8);
		curtains = mix(curtains, narrow_warp, 0.34);
		float shimmer = 0.72 + sin(azimuth * 31.0 - time * 2.6) * 0.10;
		float aurora_amount = (0.10 + curtains * 0.90) * height_mask * shimmer * aurora_brightness;
		vec3 aurora_color = mix(aurora_green, aurora_cyan, clamp(narrow_warp * 0.86, 0.0, 1.0));
		sky_color += aurora_color * aurora_amount;
	}

	vec3 normalized_sun_direction = normalize(sun_direction);
	float sun_alignment = max(dot(direction, normalized_sun_direction), 0.0);
	float sun_visibility = smoothstep(-0.03, 0.09, normalized_sun_direction.y);
	float sun_disk = smoothstep(0.99972, 0.99994, sun_alignment);
	float inner_halo = pow(sun_alignment, 420.0);
	float wide_halo = pow(sun_alignment, 34.0);
	float horizon_haze = pow(max(dot(
		normalize(vec3(direction.x, 0.08, direction.z)),
		normalize(vec3(normalized_sun_direction.x, 0.08, normalized_sun_direction.z))
	), 0.0), 18.0);
	sky_color += sun_color * (
		sun_disk * 1.55
		+ inner_halo * 0.52
		+ wide_halo * 0.075
		+ horizon_haze * horizon_glow * 0.055
	) * sun_brightness * sun_visibility;

	COLOR = sky_color;
}
