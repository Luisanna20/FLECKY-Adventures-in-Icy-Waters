shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float underwater_amount : hint_range(0.0, 1.0) = 0.0;
uniform float depth_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    // Subtle refraction rather than caustics and light rays stuck to the camera.
    // World-space caustics remain on the actual seabed material.
    vec2 drift = vec2(sin(SCREEN_UV.y * 27.0 + TIME * 0.8),
                      cos(SCREEN_UV.x * 23.0 - TIME * 0.65));
    vec2 distortion = drift * 0.00030 * underwater_amount;
    vec2 uv = clamp(SCREEN_UV + distortion, vec2(0.001), vec2(0.999));
    vec3 scene_color = texture(screen_texture, uv).rgb;
    vec3 cold_color = scene_color * mix(vec3(0.98, 1.0, 1.01), vec3(0.94, 0.99, 1.0), depth_amount);
    float edge = smoothstep(0.30, 0.77, distance(UV, vec2(0.5)));
    cold_color *= 1.0 - edge * 0.055;
    COLOR = vec4(mix(scene_color, cold_color, underwater_amount), 1.0);
}
