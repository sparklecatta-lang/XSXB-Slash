shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
#include "res://addons/xsxb_slash/xsxb_slash_trail.gdshaderinc"

void fragment() {
	vec4 r = xsxb_slash_trail(UV, UV2.x, TIME, UV2.y);
	ALBEDO = debug_mode > 0 ? r.rgb : r.rgb * r.a;
}
