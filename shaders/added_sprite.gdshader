// Uma peça colorida sobre preto, somada (o fogo e o halo do tambor, #205): o preto não soma nada, sem névoa por cima
// (a névoa num quad somado pintava o retângulo inteiro) e com energy acima de 1 o glow do Environment pega.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float energy = 1.0;

void fragment() {
	ALBEDO = texture(tex, UV).rgb * energy;
}
