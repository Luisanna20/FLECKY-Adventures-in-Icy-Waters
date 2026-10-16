shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D blocker_map : repeat_disable, filter_linear;
uniform bool blockers_ready=false;
uniform vec3 sun_direction=vec3(0.073,0.633,-0.771);
uniform float underwater_amount=0.0;

void vertex(){POSITION=vec4(VERTEX.xy,1.0,1.0);}

void fragment(){
    float depth=textureLod(depth_texture,SCREEN_UV,0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    vec3 ndc=vec3(SCREEN_UV,depth)*2.0-1.0;
#else
    vec3 ndc=vec3(SCREEN_UV*2.0-1.0,depth);
#endif
    vec4 view=INV_PROJECTION_MATRIX*vec4(ndc,1.0);
    vec3 endpoint=(INV_VIEW_MATRIX*vec4(view.xyz/view.w,1.0)).xyz;
    vec3 origin=CAMERA_POSITION_WORLD;
    vec3 ray=normalize(endpoint-origin);
    float distance_limit=min(length(endpoint-origin),38.0);
    if(ray.y>0.001){distance_limit=min(distance_limit,max(-origin.y/ray.y,0.0));}
    float step_length=distance_limit/32.0;
    float light=0.0;
    for(int i=0;i<32;i++){
        vec3 p=origin+ray*(float(i)+0.5)*step_length;
        vec2 surface=p.xz-p.y*sun_direction.xz/sun_direction.y;
        float blocker=textureLod(blocker_map,surface/200.0+0.5,0.0).r*50.0-22.0;
        float open_water=blockers_ready?smoothstep(blocker-0.1,blocker+0.55,p.y):0.0;
        float a=sin(surface.x*0.72+sin(surface.y*0.37+TIME*0.18));
        float b=sin(surface.y*0.91-TIME*0.14+sin(surface.x*0.21));
        float beam=pow(max(a*b,0.0),4.0);
        float attenuation=exp(-max(-p.y,0.0)*0.075)*exp(-float(i)*step_length*0.035);
        light+=beam*open_water*attenuation*step_length;
    }
    float facing=pow(max(dot(ray,sun_direction),0.0),3.0);
    ALBEDO=vec3(0.40,0.75,0.82)*light*(0.020+facing*0.045);
    ALPHA=underwater_amount;
}
