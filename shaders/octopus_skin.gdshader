shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 skin_color : source_color = vec4(0.39,0.22,0.29,1.0);
uniform float arm_phase = 0.0;
uniform bool animate_arm = false;
uniform bool sucker = false;
varying vec3 skin_position;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){
    skin_position=VERTEX;
    if(animate_arm){
        float w=smoothstep(0.15,1.6,VERTEX.z);
        float a=TIME*1.35+arm_phase+VERTEX.z*2.8;
        VERTEX.y+=sin(a)*w*0.14;
        VERTEX.x+=cos(a*0.82)*w*0.09;
    }
}
void fragment(){
    float mottles=noise(skin_position*8.0);
    float pores=noise(skin_position*85.0);
    vec3 base=skin_color.rgb*mix(0.65,1.35,mottles);
    base=mix(base,vec3(0.65,0.48,0.40),smoothstep(0.65,0.85,mottles)*0.35);
    ALBEDO=base*(0.92+pores*0.16);
    ROUGHNESS=sucker?0.57:0.48+pores*0.12;
    SPECULAR=0.48;
    EMISSION=ALBEDO*0.055;
}
