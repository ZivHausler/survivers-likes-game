shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Control maps are DATA (no sRGB): plain linear filtering.
uniform sampler2D splatmap : filter_linear;
uniform sampler2D ao_map : filter_linear;
// Zone albedos: sRGB, tiling.
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plaza_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_tex  : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex  : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D flower_tex: source_color, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec2 tile_scale = vec2(24.0, 24.0);  // UV(0..1 over map) * tile_scale = texture repeats
uniform float roughness_val = 0.92;
uniform float height_blend = 3.0;            // 0 = plain cross-fade; >0 = taller texture wins near seams

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec2 map_uv = UV;
	vec4 s = texture(splatmap, map_uv);
	// grass is the implicit base (channel order must match SplatField.CHANNEL).
	float w_plaza = s.r;
	float w_path  = s.g;
	float w_dirt  = s.b;
	float w_flower= s.a;
	float w_grass = clamp(1.0 - (w_plaza + w_path + w_dirt + w_flower), 0.0, 1.0);

	vec2 tuv = map_uv * tile_scale;
	vec3 c_grass = texture(grass_tex, tuv).rgb;
	vec3 c_plaza = texture(plaza_tex, tuv).rgb;
	vec3 c_path  = texture(path_tex,  tuv).rgb;
	vec3 c_dirt  = texture(dirt_tex,  tuv).rgb;
	vec3 c_flower= texture(flower_tex,tuv).rgb;

	// Depth blend: bias each weight by its texture height (luma proxy) so cobbles sit on top
	// of grass at a seam instead of ghosting through it.
	float g  = w_grass  * (1.0 + height_blend * luma(c_grass));
	float p  = w_plaza  * (1.0 + height_blend * luma(c_plaza));
	float pa = w_path   * (1.0 + height_blend * luma(c_path));
	float d  = w_dirt   * (1.0 + height_blend * luma(c_dirt));
	float f  = w_flower * (1.0 + height_blend * luma(c_flower));
	float tot = g + p + pa + d + f + 0.00001;

	vec3 col = (c_grass * g + c_plaza * p + c_path * pa + c_dirt * d + c_flower * f) / tot;
	col *= texture(ao_map, map_uv).r;  // faux-elevation edge shadow

	ALBEDO = col;
	ROUGHNESS = roughness_val;
	METALLIC = 0.0;
}
