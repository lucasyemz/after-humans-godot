// Feixe de luz falso (aditivo): faz o papel da névoa volumétrica onde ela não existe (Compatibility, web).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.72, 0.42);
uniform float intensity = 0.09;

void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	float body = (1.0 - smoothstep(0.25, 1.0, across)) * smoothstep(0.0, 0.2, UV.y) * (1.0 - smoothstep(0.5, 1.0, UV.y));
	float motes = 0.75 + 0.25 * sin(UV.x * 23.0 + TIME * 0.4) * sin(UV.x * 7.0 - TIME * 0.25);
	ALBEDO = color * intensity * body * motes;
}
