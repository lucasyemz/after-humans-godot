// Silhueta da cidade ao fundo (M_AHCard com Haze): a cor puxa para o tom do céu para não parecer colada nos telhados.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D albedo : source_color, filter_linear_mipmap;
uniform vec3 haze_color : source_color = vec3(0.29, 0.36, 0.38);
uniform float haze = 0.5;
uniform bool mirror = false;

void fragment() {
	vec2 uv = mirror ? vec2(1.0 - UV.x, UV.y) : UV;
	vec4 tex = texture(albedo, uv);
	if (tex.a < 0.5) {
		discard;
	}
	ALBEDO = mix(tex.rgb, haze_color, haze);
}
