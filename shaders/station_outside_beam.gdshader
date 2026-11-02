// O feixe da luz de fora (#217): desce do vão da abóbada na saída do trem até a via, na frente do vagão, com a cor da
// hora (beam.rgb) e a força em beam.a. Aditivo e sem luz própria, para tingir de leve em qualquer renderer.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 beam = vec4(1.0, 1.0, 1.0, 0.0);

void fragment() {
	// UV.y 0 no alto (o vão) e 1 embaixo (a via). O feixe inclina para a direita ao descer (a luz entra de cima e da
	// esquerda) e se abre um pouco; some nas bordas e perto do chão.
	float y = UV.y;
	float center = 0.4 + 0.18 * y;
	float half_width = 0.3 + 0.12 * y;
	float across = 1.0 - smoothstep(half_width * 0.45, half_width, abs(UV.x - center));
	float down = smoothstep(0.0, 0.06, y) * (1.0 - smoothstep(0.55, 1.0, y));
	ALBEDO = beam.rgb * beam.a * across * down;
}
