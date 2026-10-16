shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(0.18,0.24,0.22,1.0);
uniform vec3 caustic_color : source_color = vec3(0.35,0.57,0.60);
uniform float roughness = 0.90;
uniform float caustic_strength = 0.22;
uniform float caustic_scale = 0.78;
uniform float caustic_softness = 0.085;
uniform float caustic_light_gain = 8.45;
uniform sampler2D seabed_diffuse : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D seabed_roughness : filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D seabed_displacement : filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D sand_diffuse : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D sand_normal : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D sand_roughness : filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D rock_diffuse : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D rock_normal : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D rock_roughness : filter_linear_mipmap_anisotropic,repeat_enable;
uniform float texture_strength = 0.70;
uniform float texture_scale = 0.43;
uniform bool terrain_blend = false;
varying vec3 world_position;
varying vec3 world_normal;
varying float focused_light;

float hash2(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise2(vec2 p) {
    vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1,1)),f.x),f.y);
}
vec3 tri_color(sampler2D tex, vec3 p, vec3 weights) {
    return texture(tex,p.zy).rgb*weights.x + texture(tex,p.xz).rgb*weights.y + texture(tex,p.xy).rgb*weights.z;
}
float caustic(vec2 p,float t) {
    float a=sin(p.x*2.15+sin(p.y*1.62+t));
    float b=sin(p.y*2.48-cos(p.x*1.44-t*0.81));
    float ridge=abs(a+b);
    // A rounded light profile has no flat white core. Preserve energy when
    // pixel coverage broadens distant lines, so they do not become a bright veil.
    float pixel_width=fwidth(ridge)*0.5;
    float width=sqrt(caustic_softness*caustic_softness+pixel_width*pixel_width);
    return exp(-0.5*ridge*ridge/(width*width))*caustic_softness/width;
}
void vertex() {
    world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
    vec3 n=normalize(world_normal);
    vec3 weights=pow(abs(n),vec3(5.0)); weights/=max(dot(weights,vec3(1.0)),0.001);
    vec3 p=world_position*0.43;
    vec3 stone=tri_color(rock_diffuse,p,weights);
    float stone_rough=tri_color(rock_roughness,p,weights).r;
    vec3 nx=texture(rock_normal,p.zy).rgb*2.0-1.0;
    vec3 ny=texture(rock_normal,p.xz).rgb*2.0-1.0;
    vec3 nz=texture(rock_normal,p.xy).rgb*2.0-1.0;
    vec3 mapped=normalize(vec3(nx.z*sign(n.x),nx.y,nx.x)*weights.x
                         +vec3(ny.x,ny.z*sign(n.y),ny.y)*weights.y
                         +vec3(nz.x,nz.y,nz.z*sign(n.z))*weights.z);
    vec3 color=stone*vec3(0.72,0.76,0.74);
    float surface_rough=stone_rough;
    if (terrain_blend) {
        vec2 sand_uv=world_position.xz*0.18;
        vec3 sand=texture(sand_diffuse,sand_uv).rgb*vec3(0.75,0.81,0.80);
        vec3 gravel=texture(seabed_diffuse,world_position.xz*0.27).rgb*vec3(0.67,0.74,0.73);
        float patches=noise2(world_position.xz*0.095)*0.7+noise2(world_position.xz*0.32)*0.3;
        float gravel_mix=smoothstep(0.38,0.68,patches);
        float rock_mix=clamp((1.0-n.y)*3.4+smoothstep(-12.2,-8.0,world_position.y)*0.38,0.0,0.92);
        color=mix(mix(sand,gravel,gravel_mix),color,rock_mix);
        vec3 sn=texture(sand_normal,sand_uv).rgb*2.0-1.0;
        vec3 sand_n=normalize(n+vec3(sn.x,0.0,sn.y)*0.45);
        mapped=normalize(mix(sand_n,mapped,rock_mix));
        surface_rough=mix(texture(sand_roughness,sand_uv).r,stone_rough,rock_mix);
        // Gentle sediment bands, not regular painted stripes.
        float silt=sin(world_position.x*3.7+world_position.z*1.1+noise2(world_position.xz*0.16)*4.0);
        color*=1.0+silt*0.024*(1.0-gravel_mix)*(1.0-rock_mix);
    }
    float macro=noise2(world_position.xz*0.085+world_position.y*0.11);
    color*=mix(0.78,1.07,macro);
    color=mix(color,base_color.rgb,0.075*(1.0-texture_strength));
    // Project along the refracted sunlight direction, keeping patterns on slopes.
    vec2 cp=(world_position.xz-world_position.y*vec2(0.06,-0.58))*caustic_scale;
    float light_pattern=caustic(cp+TIME*vec2(0.14,0.08),TIME*0.55);
    light_pattern+=caustic(cp*1.37-TIME*vec2(0.11,0.13),-TIME*0.43)*0.36;
    light_pattern*=0.9+0.2*noise2(cp*0.75+TIME*vec2(0.06,-0.04));
    light_pattern*=caustic_strength*exp(min(world_position.y,0.0)*0.035);
    focused_light=light_pattern;
    NORMAL=normalize((VIEW_MATRIX*vec4(normalize(mix(n,mapped,0.62)),0.0)).xyz);
    ALBEDO=color;
    ROUGHNESS=clamp(mix(roughness,surface_rough,0.6),0.63,0.98);
    SPECULAR=0.25;
}

void light() {
    // Real light attenuation includes shadows: no glowing caustics in the cave
    // or beneath opaque ice. Local treasure lights retain steady illumination.
    float focusing=LIGHT_IS_DIRECTIONAL ? 1.0+focused_light*caustic_light_gain : 1.0;
    DIFFUSE_LIGHT += max(dot(NORMAL,LIGHT),0.0)*ATTENUATION*LIGHT_COLOR*focusing/PI;
}
