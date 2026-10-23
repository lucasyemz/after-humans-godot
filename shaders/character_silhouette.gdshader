// A silhueta do personagem atrás de alguma coisa (#51, M_AHCharacterSilhouette da Unreal): o segundo passe da placa do
// personagem só desenha onde ela está escondida (o teste de profundidade invertido) e nunca por cima de outro personagem
// (a placa de todo personagem marca o stencil com 1). Preenchimento fraco e contorno mais forte, na cor do lado.
shader_type spatial;
render_mode unshaded, depth_test_inverted, depth_draw_never, cull_disabled, blend_mix, shadows_disabled, fog_disabled;
stencil_mode read, compare_not_equal, 1;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
// A mesma região da textura que a placa mostra (quadro da folha, virada para o lado).
uniform vec2 uv_offset = vec2(0.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec4 color : source_color = vec4(0.94, 0.82, 0.55, 1.0);
uniform float fill_alpha = 0.22;
uniform float edge_alpha = 0.85;
// Largura do contorno, na fração da região mostrada.
uniform float edge_width = 0.012;
// O passe chega um pouco mais perto da câmera: a própria placa (e o chão logo atrás do pé) não contam como esconderijo.
uniform float bias = 0.08;
// A faixa do pé (fração de baixo da região) fica de fora: a borda do piso da frente encobre a sola em alguns
// cenários, e a sola em silhueta parecia um defeito.
uniform float foot_cut = 0.0;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 toward = normalize(CAMERA_POSITION_WORLD - world) * bias;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(toward, 0.0)).xyz;
}

float alpha_at(vec2 uv) {
	return texture(albedo_tex, uv_offset + clamp(uv, 0.0, 1.0) * uv_scale).a;
}

void fragment() {
	float a = alpha_at(UV);
	if (a < 0.5 || UV.y > 1.0 - foot_cut) {
		discard;
	}
	// Contorno: algum vizinho fora do corpo.
	float e = edge_width;
	float around = min(min(alpha_at(UV + vec2(e, 0.0)), alpha_at(UV - vec2(e, 0.0))),
		min(alpha_at(UV + vec2(0.0, e * 0.5)), alpha_at(UV - vec2(0.0, e * 0.5))));
	ALBEDO = color.rgb;
	ALPHA = around < 0.5 ? edge_alpha : fill_alpha;
}
