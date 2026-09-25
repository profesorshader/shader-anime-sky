// for cloud textures, try something like:
//   NoiseTexture2D > FastNoiseLite > Noise Type = Value Cubic 
//   Also, enable [x] Seamless and disable [ ] Generate Mipmaps
//   For "Cloud Hor Tex" use an aspect ratio of 2:1 (like 1024 width and 512 height)

shader_type sky;

#define USE_TOP_COVER 1

group_uniforms background;
	uniform vec4 back_color_top : source_color = vec4(0.12, 0.40, 0.66, 1.0);
	uniform vec4 back_color_bottom : source_color = vec4(0.34, 0.75, 0.92, 1.0);
	
group_uniforms sun;	
	uniform float sun_size : hint_range(0.0, 0.1, 0.0001) = 0.001; 
	uniform float sun_softness : hint_range(0.0, 1.0) = 0.1;
	uniform float sun_glow_size : hint_range(0.0, 0.9) = 0.2;
	uniform vec3 sun_color : source_color = vec3(1.0, 1.0, 1.0);
	uniform vec4 sun_glow_color : source_color = vec4(1.0, 1.0, 1.0, 0.15);

group_uniforms horizon;
	uniform float hor_height_min : hint_range(0.0, 0.8) = 0.05;
	uniform float hor_height_max : hint_range(0.1, 0.9) = 0.2;
	uniform vec4 hor_color_mix : source_color = vec4(1.0, 1.0, 1.0, 0.125);
	uniform vec4 hor_color_add : source_color = vec4(1.0, 1.0, 1.0, 0.125);
	
group_uniforms cloud_shape;	
	uniform sampler2D cloud_hor_tex : repeat_enable; // horizon
	uniform float cloud_hor_start : hint_range(0.1, 0.8) = 0.25;
	uniform float cloud_hor_end : hint_range(0.2, 0.9) = 0.5;
	uniform vec2 cloud_hor_scale = vec2(2.0, 2.0); // use integer values for U/X value

#if USE_TOP_COVER	
	uniform sampler2D cloud_top_tex : repeat_enable; // top
	uniform float cloud_top_start : hint_range(0.1, 0.8) = 0.6;
	uniform float cloud_top_end : hint_range(0.2, 0.9) = 0.7;	
	uniform float cloud_top_scale = 0.5;
#endif
	
	uniform float clouds_power : hint_range(0.5, 10.0) = 3.0;	
	
	uniform float cloud_transtion_start : hint_range(0.1, 0.8) = 0.8;
	uniform float cloud_transtion_end : hint_range(0.2, 0.9) = 0.9;
	
group_uniforms cloud_colors;	
	uniform vec3 cloud_color_bright : source_color = vec3(1.0, 1.0, 1.0);
	uniform vec3 cloud_color_dark : source_color = vec3(0.8, 0.9, 1.0);
	uniform vec3 cloud_color_edges_mix : source_color = vec3(1.0, 1.0, 1.0);
	uniform vec3 cloud_color_edges_add : source_color = vec3(1.0, 1.0, 1.0);
	uniform float cloud_edges : hint_range(0.1, 1.0) = 0.9;

group_uniforms cloud_motion;		
	uniform float hor_speed = 0.1;
	uniform float hor_layer0_speed_mult : hint_range(-1.0, 1.0) = 0.05;	
	uniform float hor_layer1_speed_mult : hint_range(-1.0, 1.0) = 0.10;	
#if USE_TOP_COVER
	uniform float top_speed = 0.05;
#endif	
	
#if USE_TOP_COVER
// taken from godotshaders :)
vec2 rotate_uvs(vec2 uv, vec2 pivot, float angle)
{
	mat2 rotation = mat2(vec2(sin(angle), -cos(angle)),
						vec2(cos(angle), sin(angle)));
	
	uv -= pivot;
	uv = uv * rotation;
	uv += pivot;
	return uv;
}
#endif

vec2 eyedir_to_cylindrical_uv_mapping(vec3 dir, vec2 scale) {
    float u = -fract(((atan(dir.x, dir.z) + PI) / TAU) * scale.x);
    float v = -dir.y * 0.5 * scale.y;	
	return vec2(u, v);
}

void sky() {
	// get background color
	vec4 background_color = mix(back_color_bottom, back_color_top, abs(EYEDIR.y));
	vec3 sky_final = background_color.rgb;	
	
	// sky or floor?
	if (EYEDIR.y > 0.0) {
		// the sun is easy to calculate thanks to the dot product between EYEDIR and LIGHT0_DIRECTION
		float eye_dot = dot(EYEDIR, LIGHT0_DIRECTION);
		float sun_dot = max(0.0, eye_dot); 
		float inv_sun_size = clamp(1.0 - sun_size, 0.0, 1.0);
		float sun = smoothstep(inv_sun_size, inv_sun_size + (sun_size * sun_softness), sun_dot);
		float sun_glow = smoothstep(inv_sun_size - sun_glow_size, inv_sun_size, sun_dot);
		
		// get top uvs
#if USE_TOP_COVER		
		vec2 uv_top = vec2(EYEDIR.x, -EYEDIR.z);
		uv_top = rotate_uvs(uv_top, vec2(0.0), TIME * 0.525 * top_speed);		
#endif		
		
		// get cylindrical uvs
		vec2 uv_cyl_a = eyedir_to_cylindrical_uv_mapping(EYEDIR, cloud_hor_scale);
		vec2 uv_cyl_b = uv_cyl_a;
		uv_cyl_a.x += TIME * hor_layer0_speed_mult * hor_speed;			
		uv_cyl_b.x += TIME * hor_layer1_speed_mult * hor_speed;			
				
		// sample top and cyl
#if USE_TOP_COVER		
		float col_top_val = textureLod(cloud_top_tex, uv_top * cloud_top_scale, 0).r;			
		col_top_val = smoothstep(cloud_top_start, cloud_top_end, col_top_val);
		vec4 col_top = vec4(1.0, 1.0, 1.0, col_top_val);
#endif		
		
		float cloud_hor_val_a = textureLod(cloud_hor_tex, uv_cyl_a, 0).r;
		float cloud_hor_val_b = textureLod(cloud_hor_tex, uv_cyl_b, 0).r;
		float cloud_hor_val = smoothstep(cloud_hor_start, cloud_hor_end, cloud_hor_val_a * cloud_hor_val_b);
		vec4 col_cyl = vec4(1.0, 1.0, 1.0, cloud_hor_val);
				
		// horizon or top?
		float cloud_mix = smoothstep(cloud_transtion_start, cloud_transtion_end, abs(EYEDIR.y));
#if USE_TOP_COVER		
		vec4 clouds = mix(col_cyl, col_top, cloud_mix);
#else
		vec4 clouds = mix(col_cyl, vec4(0.0), cloud_mix);
#endif
		
		// power clouds
		clouds.a = pow(clouds.a, clouds_power);
		
		// give cloud details
		float cloud_detail_val = smoothstep(cloud_edges, 1.0, clouds.a);
		clouds.rgb = mix(cloud_color_edges_mix, clouds.rgb, cloud_detail_val);
		clouds.rgb += mix(cloud_color_edges_add, vec3(0.0), cloud_detail_val);
		
		// cloud color based on sun direction
		float cloud_color_val = (eye_dot + 1.0) * 0.5;
		clouds.rgb = mix(clouds.rgb * cloud_color_bright, clouds.rgb * cloud_color_dark, cloud_color_val);
				
		// change cloud color if the sun is just back
		clouds.rgb = mix(clouds.rgb, cloud_color_bright, sun_glow);
		
		// get horizon value
		float horizon_val = smoothstep(hor_height_min, hor_height_max, EYEDIR.y);
		float horizon_val_inv = clamp(1.0 - horizon_val, 0.0, 1.0);
		
		// remove clouds in the horizon
		clouds.rgb = mix(sky_final.rgb, clouds.rgb, horizon_val);
		
		// draw the sun (over the ceil color)
		sky_final.rgb += vec3(sun_color * sun);
		
		// draw sun glow
		sky_final += vec3(sun_glow_color.rgb) * sun_glow * sun_glow_color.a;
		
		// mix clouds
		sky_final = mix(sky_final, clouds.rgb, clouds.a);		
		
		// draw horizon color
		sky_final.rgb = mix(sky_final.rgb, hor_color_mix.rgb, hor_color_mix.a * horizon_val_inv);
		sky_final.rgb += hor_color_add.rgb * hor_color_add.a * horizon_val_inv;	
	}
	
	// output final result
	COLOR = sky_final;	
}