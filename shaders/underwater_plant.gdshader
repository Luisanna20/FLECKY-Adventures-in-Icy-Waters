shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec4 base_color : source_color = vec4(0.18, 0.58, 0.38, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform bool has_albedo_texture = false;
uniform float blade_base = -1.0;
uniform float blade_height = 2.0;
uniform float tint_amount : hint_range(0.0, 1.0) = 0.18;
uniform vec3 swimmer_position = vec3(0.0, -1000.0, 0.0);
uniform vec3 swimmer_velocity = vec3(0.0);
uniform float swimmer_activity : hint_range(0.0, 1.0) = 0.0;
uniform float interaction_radius : hint_range(1.0, 8.0) = 4.6;
uniform float wake_length : hint_range(1.0, 10.0) = 5.4;

instance uniform vec4 plant_tint : source_color = vec4(0.12, 0.62, 0.48, 1.0);
instance uniform float sway_phase = 0.0;
instance uniform float sway_strength : hint_range(0.0, 0.4) = 0.10;
instance uniform float reaction_flex : hint_range(0.2, 1.5) = 1.0;


void vertex() {
	float height_ratio = clamp((VERTEX.y - blade_base) / max(blade_height, 0.01), 0.0, 1.0);
	float flexible_tip = pow(height_ratio, 1.65);
	float current_time = TIME * 0.72;
	float broad_current = sin(current_time + sway_phase + VERTEX.y * 0.82);
	float cross_current = cos(current_time * 0.79 + sway_phase * 1.37 + VERTEX.y * 1.14);
	VERTEX.x += broad_current * sway_strength * flexible_tip;
	VERTEX.z += cross_current * sway_strength * 0.52 * flexible_tip;

	vec3 world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 from_swimmer = world_vertex - swimmer_position;
	float swimmer_speed = length(swimmer_velocity);
	float speed_ratio = clamp(swimmer_speed / 8.75, 0.0, 1.0);
	vec2 swim_direction = (
		swimmer_speed > 0.05
		? normalize(swimmer_velocity.xz)
		: vec2(0.0, -1.0)
	);

	float body_distance = length(from_swimmer);
	float body_influence = 1.0 - smoothstep(
		interaction_radius * 0.24,
		interaction_radius,
		body_distance
	);
	vec2 radial_direction = (
		length(from_swimmer.xz) > 0.02
		? normalize(from_swimmer.xz)
		: vec2(-swim_direction.y, swim_direction.x)
	);

	float distance_behind = clamp(
		-dot(from_swimmer.xz, swim_direction),
		0.0,
		wake_length
	);
	vec2 from_wake_axis = from_swimmer.xz + swim_direction * distance_behind;
	float wake_distance = length(
		vec3(from_wake_axis.x, from_swimmer.y * 0.82, from_wake_axis.y)
	);
	float trail_falloff = 1.0 - distance_behind / max(wake_length, 0.01);
	float wake_influence = (
		(1.0 - smoothstep(0.45, interaction_radius * 0.72, wake_distance))
		* trail_falloff
		* speed_ratio
	);

	vec2 world_bend = (
		radial_direction * body_influence * (0.48 + speed_ratio * 0.38)
		+ swim_direction * wake_influence * (0.34 + speed_ratio * 0.44)
	);
	vec3 local_bend = (
		inverse(MODEL_MATRIX)
		* vec4(world_bend.x, 0.0, world_bend.y, 0.0)
	).xyz;
	VERTEX += (
		local_bend
		* flexible_tip
		* reaction_flex
		* swimmer_activity
	);
}


void fragment() {
	vec4 source = base_color;
	if (has_albedo_texture) {
		source *= texture(albedo_texture, UV);
	}
	vec3 cold_color = mix(source.rgb, plant_tint.rgb, tint_amount);
	ALBEDO = cold_color;
	ROUGHNESS = 0.76;
	SPECULAR = 0.28;
	EMISSION = cold_color * 0.075;
}
