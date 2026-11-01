// O halo de uma fonte de luz prática e a poça de luz no chão (#154): a textura colorida sobre preto, somada (o preto não
// soma nada). color tinge (branco no halo, que já vem colorido; a cor da luz na poça, que é cinza) e energy acima de 1
// deixa o glow do Environment pegar.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 color : source_color = vec3(1.0);
uniform float energy = 1.5;

void fragment() {
	ALBEDO = texture(tex, UV).rgb * color * energy;
}
