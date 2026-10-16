shader_type spatial;
// Screen refraction is already composited: do not alpha-blend it a second time.
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D ripple_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 shallow_color : source_color = vec4(0.055, 0.34, 0.37, 1.0);
uniform vec4 deep_color : source_color = vec4(0.025, 0.16, 0.22, 1.0);
uniform vec4 crest_color : source_color = vec4(0.79, 0.88, 0.89, 1.0);
uniform float wave_height : hint_range(0.0, 0.8) = 0.23;
uniform float wave_speed : hint_range(0.0, 3.0) = 0.66;
uniform float refraction_strength : hint_range(0.0, 0.08) = 0.018;
uniform float absorption_strength : hint_range(0.01, 1.0) = 0.18;
uniform float foam_width : hint_range(0.05, 2.0) = 0.32;
uniform vec3 sun_direction = vec3(0.073, 0.633, -0.771);
uniform vec2 swimmer_position = vec2(1000.0);
uniform vec2 swimmer_forward = vec2(0.0, -1.0);
uniform float swimmer_speed : hint_range(0.0, 1.0) = 0.0;
uniform float swimmer_surface : hint_range(0.0, 1.0) = 0.0;

varying vec3 water_world_position;
varying vec2 vertex_slope;

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i), hash2(i + vec2(1,0)), f.x),
               mix(hash2(i + vec2(0,1)), hash2(i + vec2(1,1)), f.x), f.y);
}

void add_wave(vec2 p, vec2 direction, float frequency, float amplitude,
              float speed, inout float height, inout vec2 slope) {
    vec2 d = normalize(direction);
    float phase = dot(p, d) * frequency - TIME * speed;
    height += sin(phase) * amplitude;
    slope += cos(phase) * amplitude * frequency * d;
}

// Expanding divergent waves and a disturbed strip behind the swimmer.
vec3 wake_field(vec2 p) {
    vec2 forward = normalize(swimmer_forward + vec2(0.00001));
    vec2 side = vec2(-forward.y, forward.x);
    vec2 offset = p - swimmer_position;
    float behind = -dot(offset, forward);
    float lateral = dot(offset, side);
    float side_sign = sign(lateral);
    float transverse = abs(lateral) - behind * 0.32;
    float envelope = smoothstep(0.15, 1.0, behind) * exp(-max(behind, 0.0) * 0.23);
    envelope *= exp(-transverse * transverse * 1.8);
    float phase = transverse * 7.0 - TIME * 2.6;
    float strength = swimmer_surface * swimmer_speed;
    float height = sin(phase) * envelope * 0.032 * strength;
    vec2 slope = cos(phase) * envelope * 0.20 * strength * (side * side_sign + forward * 0.32);
    return vec3(slope, height);
}

void vertex() {
    vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
    float height = 0.0;
    vec2 slope = vec2(0.0);
    add_wave(p, vec2(1.0, 0.27), 0.30, wave_height * 0.43, wave_speed, height, slope);
    add_wave(p, vec2(0.78, 0.63), 0.49, wave_height * 0.29, wave_speed * 1.29, height, slope);
    add_wave(p, vec2(-0.38, 1.0), 0.78, wave_height * 0.18, wave_speed * 1.61, height, slope);
    add_wave(p, vec2(0.92, -0.39), 1.23, wave_height * 0.10, wave_speed * 2.02, height, slope);
    vec3 wake = wake_field(p);
    VERTEX.y += height + wake.z;
    vertex_slope = slope;
    NORMAL = normalize(vec3(-slope.x, 1.0, -slope.y));
    water_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 reconstruct_view_position(vec2 uv, float raw_depth, mat4 inverse_projection) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    vec3 ndc = vec3(uv, raw_depth) * 2.0 - 1.0;
#else
    vec3 ndc = vec3(uv * 2.0 - 1.0, raw_depth);
#endif
    vec4 position = inverse_projection * vec4(ndc, 1.0);
    return position.xyz / position.w;
}

void fragment() {
    vec2 p = water_world_position.xz;
    float footprint = length(fwidth(p));
    float detail_fade = 1.0 - smoothstep(0.08, 0.55, footprint);
    float fine_fade = 1.0 - smoothstep(0.025, 0.17, footprint);
    float drift = sin(p.x * 0.17 + p.y * 0.29 - TIME * 0.24) * 1.2;
    vec2 d1 = normalize(vec2(1.0, 0.31));
    vec2 d2 = normalize(vec2(0.67, 0.74));
    vec2 d3 = normalize(vec2(-0.42, 1.0));
    vec2 d4 = normalize(vec2(0.91, -0.41));
    vec2 ripple = d1 * cos(dot(p, d1) * 2.7 - TIME * 1.75 + drift) * 0.052;
    ripple += d2 * cos(dot(p, d2) * 4.6 - TIME * 2.3 + drift * 0.7) * 0.043;
    ripple += d3 * cos(dot(p, d3) * 8.9 - TIME * 3.1 + drift) * 0.045 * fine_fade;
    ripple += d4 * cos(dot(p, d4) * 16.7 - TIME * 4.15) * 0.026 * fine_fade;
    ripple += vec2(0.21, 0.98) * cos(dot(p, vec2(0.21, 0.98)) * 6.3 - TIME * 2.7) * 0.028 * detail_fade;
    vec2 slope = vertex_slope + ripple * detail_fade + wake_field(p).xy;
    // Two differently oriented wind-ripple fields break up the regular wave trains.
    vec2 ripple_uv = p * 0.065;
    vec2 noise_a = texture(ripple_normal, ripple_uv + TIME * vec2(-0.014, 0.006)).xy * 2.0 - 1.0;
    vec2 noise_b = texture(ripple_normal, vec2(-ripple_uv.y, ripple_uv.x) * 1.37 + TIME * vec2(0.008, -0.011)).xy * 2.0 - 1.0;
    slope += (noise_a + vec2(noise_b.y, -noise_b.x) * 0.65) * 0.18 * detail_fade;
    vec3 world_normal = normalize(vec3(-slope.x, 1.0, -slope.y));
    bool underwater = CAMERA_POSITION_WORLD.y < water_world_position.y;
    if (underwater) {
        world_normal = -world_normal;
    }
    // NORMAL is view-space. NORMAL_MAP would require encoded tangent normals.
    NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
    float facing = clamp(dot(NORMAL, normalize(VIEW)), 0.0, 1.0);
    float fresnel = 0.0204 + 0.9796 * pow(1.0 - facing, 5.0);

    vec3 scene_position = reconstruct_view_position(SCREEN_UV,
        textureLod(depth_texture, SCREEN_UV, 0.0).r, INV_PROJECTION_MATRIX);
    float surface_depth = -VERTEX.z;
    float original_thickness = max(-scene_position.z - surface_depth, 0.0);
    // Reduce distortion at real intersections, screen edges, and grazing angles.
    float edge_fade = smoothstep(0.0, 0.06, min(min(SCREEN_UV.x, 1.0-SCREEN_UV.x),
                                                    min(SCREEN_UV.y, 1.0-SCREEN_UV.y)));
    vec2 offset = NORMAL.xy * refraction_strength * smoothstep(0.0, 0.8, original_thickness);
    offset *= edge_fade * smoothstep(0.02, 0.28, facing);
    vec2 uv = clamp(SCREEN_UV + offset, vec2(0.001), vec2(0.999));
    vec3 refracted_position = reconstruct_view_position(uv,
        textureLod(depth_texture, uv, 0.0).r, INV_PROJECTION_MATRIX);
    // Reject above-water foreground pixels pulled into the refracted image.
    float valid_refraction = step(surface_depth + 0.015, -refracted_position.z);
    uv = mix(SCREEN_UV, uv, valid_refraction);
    refracted_position = mix(scene_position, refracted_position, valid_refraction);
    vec3 refracted_scene = textureLod(screen_texture, uv, 0.0).rgb;
    float thickness = clamp(length(refracted_position - VERTEX), 0.0, 65.0);
    // Beer-Lambert attenuation: red fades first, blue-green travels farther.
    vec3 transmission = exp(-vec3(1.0, 0.45, 0.28) * thickness * absorption_strength);
    float depth_mix = 1.0 - exp(-thickness * 0.12);
    vec3 scatter = mix(shallow_color.rgb, deep_color.rgb, depth_mix);
    vec3 through_water = refracted_scene * transmission + scatter * (vec3(1.0) - transmission);

    float foam_noise = noise2(p * 5.5 + vec2(TIME * 0.17, -TIME * 0.11));
    float contact = (1.0 - smoothstep(0.025, foam_width, original_thickness))
        * smoothstep(0.26, 0.68, foam_noise);
    vec2 forward = normalize(swimmer_forward + vec2(0.00001));
    vec2 from_swimmer = p - swimmer_position;
    float behind = -dot(from_swimmer, forward);
    float across = abs(dot(from_swimmer, vec2(-forward.y, forward.x)));
    float trail = smoothstep(0.2, 1.0, behind) * exp(-max(behind, 0.0) * 0.4)
        * exp(-across * across * 3.5) * swimmer_speed * swimmer_surface;
    float foam = clamp(contact * 0.52 + trail * smoothstep(0.38, 0.74, foam_noise) * 0.24, 0.0, 0.65);

    float internal_reflection = 0.0;
    if (underwater) {
        // Clear upward view through Snell's window; reflective beyond critical angle.
        internal_reflection = 1.0 - smoothstep(0.62, 0.70, facing);
        fresnel = max(fresnel, internal_reflection);
        through_water = refracted_scene;
        // Transmitted daylight follows the refracted sun, with moving wave facets.
        // This is a narrow sun window, not a uniform bright underwater ceiling.
        vec3 to_surface=normalize(water_world_position-CAMERA_POSITION_WORLD);
        vec3 underwater_sun=normalize(vec3(sun_direction.x*0.75,
            sqrt(1.0-dot(sun_direction.xz,sun_direction.xz)*0.5625),sun_direction.z*0.75));
        vec3 warped_view=normalize(to_surface+vec3(slope.x,0.0,slope.y)*0.25);
        float sun_alignment=max(dot(warped_view,underwater_sun),0.0);
        float sun_window=pow(sun_alignment,110.0)*1.7+pow(sun_alignment,14.0)*0.24;
        through_water+=vec3(0.64,0.91,1.0)*sun_window;
        foam *= 0.25;
    }
    // PBR contributes the actual sky/ice probe and sun reflection only.
    // The transmitted scene is already lit; keep it out of the diffuse light pass.
    ALBEDO = mix(crest_color.rgb * foam, vec3(0.40, 0.63, 0.70), internal_reflection);
    EMISSION = through_water * (1.0 - fresnel) * (1.0 - foam);
    METALLIC = internal_reflection;
    SPECULAR = 0.255;
    ROUGHNESS = 0.16 + foam * 0.48 + (1.0 - fine_fade) * 0.04;
    ALPHA = 1.0;
}
