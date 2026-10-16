shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 fur_color : source_color = vec4(0.83, 0.82, 0.77, 1.0);
uniform bool deform_head = false;
uniform mat4 head_pose = mat4(1.0);
uniform float swim_amount = 0.0;
uniform float swim_phase = 0.0;
varying vec3 fur_position;

float hash(vec3 p) {
    p = fract(p * 0.3183099 + vec3(0.11, 0.23, 0.37));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise3(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x),
                   mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
               mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
                   mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() {
    fur_position = VERTEX;
    if (deform_head) {
        float weight = 1.0 - smoothstep(-0.83, -0.32, VERTEX.z);
        vec3 pivot = vec3(0.0, 0.12, -0.82);
        vec3 posed = (head_pose * vec4(VERTEX - pivot, 1.0)).xyz;
        VERTEX = mix(VERTEX, posed, weight);
        NORMAL = normalize(mix(NORMAL, mat3(head_pose) * NORMAL, weight));
        // True seals drive the stroke with the rear body and hind flippers.
        float rear = smoothstep(0.1, 1.2, VERTEX.z);
        VERTEX.x += sin(swim_phase - VERTEX.z * 1.3) * rear * 0.065 * swim_amount;
    }
}
void fragment() {
    float broad = noise3(fur_position * 7.0);
    float detail = 1.0 - smoothstep(0.004, 0.018, length(fwidth(fur_position)));
    float grain = mix(0.5, noise3(fur_position * vec3(130.0, 130.0, 35.0)), detail);
    float belly = 1.0 - smoothstep(-0.30, 0.26, fur_position.y);
    vec3 base = mix(fur_color.rgb, vec3(0.91, 0.89, 0.83), belly * 0.28);
    ALBEDO = base * (0.94 + broad * 0.06 + grain * 0.02);
    ROUGHNESS = 0.84 + grain * 0.09;
    SPECULAR = 0.24;
    // A soft grazing response suggests the short coat without shell geometry.
    RIM = 0.07;
    RIM_TINT = 0.8;
}
