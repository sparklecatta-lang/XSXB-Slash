// XSXB-Slash layer shader body (recipe v1, docs/SPEC.md section 3). Included by xsxb_slash_trail_alpha / xsxb_slash_trail_add.
uniform sampler2D shape_tex : hint_default_white, filter_linear, repeat_disable;
uniform sampler2D mask_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D highlight_tex : hint_default_black, filter_linear, repeat_disable;
// colours are linear (no source_color hint on purpose)
uniform vec3 color = vec3(0.0);
uniform vec3 edge_color = vec3(0.0);
uniform vec3 highlight_color = vec3(1.0);
uniform float alpha = 1.0;
uniform float hdr = 1.0;
uniform float window_narrow = 0.6;
uniform float mask_amount = 0.5;
uniform float mask_tile_per_m = 0.6;
uniform float mask_pan_per_s = -0.35;
uniform float erode_speed = 0.85;
uniform float erode_sharp = 6.0;
uniform float edge_width = 0.08;
uniform float edge_glow = 0.0;
uniform float highlight = 0.0;
uniform int debug_mode = 0; // 0 off, 1 UV (red age, green V), 2 frac(dist)
// recipe.constants
uniform float erode_base = -0.12;
uniform float erode_age_pow = 1.5;
uniform float erode_inner = 0.1;
uniform float mask_tile_v = 0.8;
uniform float mask_age_drift = 0.15;
uniform float detail_gain = 1.6;
uniform float head_soft = 0.005;

vec4 xsxb_slash_trail(vec2 uv, float dist, float t, float xu) {   // xu = filled U (UV2.y): texture lookups
	float x = uv.x, v = uv.y;
	if (debug_mode == 2) return vec4(vec3(fract(dist)), 1.0);
	if (debug_mode == 1) return vec4(xu, v, 0.0, 1.0);   // red = filled U
	float sv = 1.0 - (1.0 - v) * (1.0 + window_narrow * x);
	// Godot UV origin is top-left: the PNG's top row (outer edge) is at y = 0, so sample (x, 1 - sv)
	float shp = sv < 0.0 ? 0.0 : texture(shape_tex, vec2(xu, 1.0 - sv)).r;
	float m = texture(mask_tex, vec2(dist * mask_tile_per_m + t * mask_pan_per_s, v * mask_tile_v + x * mask_age_drift)).r;
	float det = mix(1.0, m * detail_gain, mask_amount);
	float thr = erode_base + pow(max(x, 0.0), erode_age_pow) * erode_speed + (1.0 - v) * erode_inner;
	float mg = m - thr;
	float keep = clamp(mg * erode_sharp, 0.0, 1.0);
	float edge = clamp(1.0 - mg / max(edge_width, 1e-3), 0.0, 1.0) * keep;
	float hl = sv < 0.0 ? 0.0 : texture(highlight_tex, vec2(xu, 1.0 - sv)).r;
	float a = clamp(shp * det * keep * alpha * smoothstep(0.0, head_soft, xu), 0.0, 1.0);
	vec3 c = color * hdr + edge_color * edge * edge_glow + highlight_color * hl * highlight;
	return vec4(c, a);
}
