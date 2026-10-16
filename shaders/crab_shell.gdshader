shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform float walking=1.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){
    float phase=TIME*5.2+COLOR.g*TAU;
    VERTEX.z+=max(sin(phase),0.0)*COLOR.r*0.0010*walking;
    VERTEX.x+=cos(phase)*COLOR.r*0.0007*walking;
}
void fragment(){
    float patches=noise(UV*11.0)*0.65+noise(UV*27.0)*0.35;
    float grain=noise(UV*190.0);
    vec3 shell=mix(vec3(0.10,0.06,0.035),vec3(0.40,0.25,0.14),patches);
    shell*=0.89+grain*0.22;
    float speckles=smoothstep(0.72,0.87,noise(UV*72.0));
    shell=mix(shell,vec3(0.46,0.36,0.22),speckles*0.30);
    if(UV2.y>1.5){shell=vec3(0.008,0.012,0.013);}
    else if(UV2.y>0.5){shell=mix(shell,vec3(0.47,0.37,0.23),0.60);}
    ALBEDO=shell;
    ROUGHNESS=UV2.y>1.5?0.20:0.55+grain*0.12;
    SPECULAR=0.42;
    EMISSION=shell*0.12;
}
