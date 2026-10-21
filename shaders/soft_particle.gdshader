// Partícula com mistura normal (não aditiva): gota de chuva (traço vertical) ou fumaça (disco suave).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(0.75, 0.82, 0.92);
uniform float opacity = 0.3;
// true: traço que afina nas pontas (chuva); false: disco suave (fumaça, respingo).
uniform bool streak = true;

void fragment() {
	float shape;
	if (streak) {
		shape = (1.0 - abs(UV.x - 0.5) * 2.0) * smoothstep(0.0, 0.5, UV.y) * (1.0 - smoothstep(0.85, 1.0, UV.y));
	} else {
		shape = pow(clamp(1.0 - length(UV - 0.5) * 2.0, 0.0, 1.0), 1.6);
	}
	ALBEDO = color * COLOR.rgb;
	ALPHA = shape * opacity * COLOR.a;
}
