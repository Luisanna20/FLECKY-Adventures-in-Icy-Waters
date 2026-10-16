shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec4 back_color : source_color;
uniform vec4 flank_color : source_color;
uniform vec4 belly_color : source_color;
uniform vec4 fin_color : source_color;
uniform int surface_kind=0; // 0 skin, 1 eye, 2 fin
uniform float patch_lightness=1.0;
uniform float scale_count=70.0;
uniform float stripe_strength=0.0;

float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}

void fragment(){
    if(!FRONT_FACING){NORMAL=-NORMAL;}
    vec3 color=flank_color.rgb;
    float gloss=0.40;
    if(surface_kind==1){
        float radius=length((UV-0.5)*2.0);
        float iris=smoothstep(0.40,0.49,radius)*(1.0-smoothstep(0.76,0.95,radius));
        float spokes=sin(atan(UV.y-0.5,UV.x-0.5)*36.0)*0.06;
        color=mix(vec3(0.007,0.010,0.012),vec3(0.28,0.23,0.12)*(1.0+spokes),iris);
        gloss=0.17;
    }else if(surface_kind==2){
        float root=UV.x>0.77?0.77:0.42;
        float angle=atan(UV.y-0.48,(UV.x-root)*1.7);
        float rays=sin(angle*28.0);
        float detail=1.0-smoothstep(0.3,1.0,fwidth(angle*28.0));
        color=fin_color.rgb*(0.94+rays*0.08*detail);
        gloss=0.52;
    }else{
        color=mix(belly_color.rgb,flank_color.rgb,smoothstep(0.12,0.52,UV.y));
        color=mix(color,back_color.rgb,smoothstep(0.58,0.96,UV.y));
        color*=patch_lightness*(0.94+noise(UV*vec2(23.0,13.0))*0.12);
        float stripe=smoothstep(-0.25,0.6,sin(UV.y*TAU*3.0+0.2));
        color*=1.0-stripe*stripe_strength;
        vec2 scales=UV*vec2(scale_count,26.0);
        float detail=1.0-smoothstep(0.25,0.85,length(fwidth(scales)));
        scales.x+=mod(floor(scales.y),2.0)*0.5;
        vec2 cell=fract(scales)-0.5;
        float rim=smoothstep(0.32,0.47,length(cell*vec2(1.0,1.15)));
        float body=smoothstep(0.19,0.32,UV.x)*(1.0-smoothstep(0.83,0.95,UV.x));
        color*=1.0-rim*0.035*detail*body;
        // A curved operculum and a faint lateral line, both fixed to the skin.
        float gill_x=0.25-0.13*pow((UV.y-0.48)*1.8,2.0);
        float gill=exp(-pow((UV.x-gill_x)/0.009,2.0));
        gill*=smoothstep(0.14,0.28,UV.y)*(1.0-smoothstep(0.72,0.88,UV.y));
        color*=1.0-gill*0.22;
        float lateral=exp(-pow((UV.y-0.51-sin(UV.x*4.0)*0.025)/0.009,2.0))*body;
        color*=1.0-lateral*0.06;
        gloss=0.39+rim*detail*body*0.045;
    }
    ALBEDO=color;
    ROUGHNESS=gloss;
    SPECULAR=0.54;
    METALLIC=surface_kind==0?0.12:0.0;
    // Small ambient lift; replaces the old strong self-illumination.
    EMISSION=color*0.045;
}
