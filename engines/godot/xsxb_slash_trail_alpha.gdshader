shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
#include "res://addons/xsxb_slash/xsxb_slash_trail.gdshaderinc"

void fragment() {
	vec4 r = xsxb_slash_trail(UV, UV2.x, TIME, UV2.y);
	ALBEDO = r.rgb;
	ALPHA = debug_mode > 0 ? 1.0 : r.a;
}
