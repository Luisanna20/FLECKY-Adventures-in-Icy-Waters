shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D frost_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
varying vec3 world_position;
varying vec3 local_position;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;local_position=VERTEX;}
void fragment(){
    float grain=noise(world_position.xz*3.5+world_position.y*1.7);
    float broad=noise(world_position.xz*0.55+world_position.y*0.8);
    float cracks=pow(1.0-abs(sin(world_position.x*0.85+world_position.z*0.47+noise(world_position.xz*0.4)*3.0)),14.0);
    float frost=smoothstep(-0.18,0.52,world_position.y);
    vec3 blue_ice=mix(vec3(0.23,0.42,0.48),vec3(0.49,0.67,0.69),broad);
    blue_ice*=0.92+grain*0.12;
    blue_ice=mix(blue_ice,vec3(0.17,0.33,0.40),cracks*0.17);
    ALBEDO=mix(blue_ice,vec3(0.77,0.85,0.84),frost*0.75);
    ROUGHNESS=mix(0.38,0.80,frost)+grain*0.08;
    SPECULAR=0.45;
    NORMAL_MAP=texture(frost_normal,UV*vec2(8.0,2.0)).rgb;
    NORMAL_MAP_DEPTH=mix(0.10,0.32,frost);
    // Diffuse light transmitted through pale ice keeps submerged faces readable.
    EMISSION=ALBEDO*(1.0-frost)*0.14;
}
