// Card pintado de fundo dos cenários (port do M_DressingCard): sem luz própria, a pintura com o brilho que a Unreal dá
// (Emissive), puxada para a cor da névoa (Haze) nos planos de trás e um pouco mais escura molhada.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform float brightness = 1.0;
uniform float haze = 0.0;
uniform vec3 haze_color : source_color = vec3(0.55, 0.52, 0.48);
uniform float wet = 0.0;
uniform vec4 weather = vec4(1.0);

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	if (tex.a < 0.333) {
		discard;
	}
	vec3 painted = tex.rgb * mix(1.0, 0.75, wet);
	ALBEDO = mix(painted, haze_color, haze) * brightness * weather.rgb;
}
