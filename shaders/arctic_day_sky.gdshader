shader_type sky;

uniform sampler2D panorama_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 sun_direction = vec3(0.073, 0.633, -0.771);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.91, 0.73);
uniform float panorama_brightness : hint_range(0.1, 2.0) = 1.05;
uniform float cloud_softness : hint_range(0.0, 1.0) = 0.10;


vec2 direction_to_panorama_uv(vec3 direction) {
	float longitude = atan(direction.z, direction.x);
	float latitude = acos(clamp(direction.y, -1.0, 1.0));
	return vec2(
		fract(longitude / (2.0 * PI) + 0.5),
		clamp(latitude / PI, 0.001, 0.999)
	);
}


void sky() {
	vec3 direction = normalize(EYEDIR);
	vec2 panorama_uv = direction_to_panorama_uv(direction);
	vec3 sky_color = textureLod(panorama_texture, panorama_uv, 0.0).rgb;

	float horizon = pow(1.0 - abs(direction.y), 5.0);
	sky_color = mix(
		sky_color,
		sky_color * vec3(0.91, 1.01, 1.05) + vec3(0.025, 0.045, 0.052),
		horizon * 0.28
	);
	float luminance = dot(sky_color, vec3(0.2126, 0.7152, 0.0722));
	sky_color = mix(sky_color, vec3(luminance), cloud_softness * 0.12);

	float sun_alignment = max(dot(direction, normalize(sun_direction)), 0.0);
	float sun_core = smoothstep(0.99970, 0.99995, sun_alignment);
	float sun_halo = pow(sun_alignment, 52.0);
	sky_color += sun_tint * (sun_core * 0.30 + sun_halo * 0.035);

	COLOR = sky_color * panorama_brightness;
}
