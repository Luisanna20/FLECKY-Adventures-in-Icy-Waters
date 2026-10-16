shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 flank_color : source_color = vec4(0.51,0.64,0.66,1.0);
varying float body_height;

void vertex(){
    body_height=VERTEX.y;
    float width=mix(0.90,1.10,INSTANCE_CUSTOM.b);
    VERTEX.x*=width;
    NORMAL.x/=width;
    NORMAL=normalize(NORMAL);
    float bend=smoothstep(-0.22,0.53,VERTEX.z);
    float phase=TIME*INSTANCE_CUSTOM.g+INSTANCE_CUSTOM.r-VERTEX.z*5.0;
    VERTEX.x+=sin(phase)*bend*bend*0.085;
}

void fragment(){
    vec3 color=mix(vec3(0.53,0.61,0.56),flank_color.rgb,smoothstep(-0.10,0.02,body_height));
    color=mix(color,vec3(0.055,0.13,0.16),smoothstep(0.01,0.14,body_height));
    float lateral=exp(-pow((body_height-0.008)/0.009,2.0));
    color*=1.0-lateral*0.055;
    if(UV2.x>1.5){color=vec3(0.009,0.014,0.016);}
    else if(UV2.x>0.5){color=mix(flank_color.rgb,vec3(0.12,0.22,0.24),0.55);}
    ALBEDO=color*COLOR.rgb;
    ROUGHNESS=UV2.x>1.5?0.22:0.58;
    SPECULAR=0.34;
    METALLIC=UV2.x<0.5?0.04:0.0;
    EMISSION=ALBEDO*0.025;
}
