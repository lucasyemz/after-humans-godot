// Uma camada do vagão 2D (#149, #256): a pintura sem luz própria, como os cards dos cenários (scenario_card), com o
// brilho do card e a cor do clima. Recorte no alfa: a carroceria, o interior, as rodas e o truque.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform float brightness = 1.0;
uniform float wet = 0.0;
uniform vec4 weather = vec4(1.0);

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	ALBEDO = tex.rgb * mix(1.0, 0.75, wet) * brightness * weather.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
