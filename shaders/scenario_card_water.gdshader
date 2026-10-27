// O card pintado de fundo com a água viva (#140, o panorama da Ponte das Raízes): acima da linha d'água (waterline, na
// altura do UV), a pintura como no scenario_card; abaixo dela, no lugar da água pintada parada (com o reflexo das
// árvores), a água pintada do chão (water_painted.gdshaderinc) em escala de distância.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/water_painted.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform float brightness = 1.0;
uniform float haze = 0.0;
uniform vec3 haze_color : source_color = vec3(0.55, 0.52, 0.48);
uniform float wet = 0.0;
uniform vec4 weather = vec4(1.0);
uniform float waterline = 0.56;
// A largura do card em metros (para as ondinhas terem o tamanho das do chão) e o fundo que a água finge ter.
uniform float width_m = 75.0;
uniform float far_m = 60.0;
// Quanto da cor da margem pintada encosta na linha d'água, e a cor do horizonte (a água de longe).
uniform float shore = 0.35;
uniform vec3 horizon_color : source_color = vec3(0.42, 0.52, 0.52);

void fragment() {
	vec2 uv = UV;
	if (uv.y < waterline) {
		vec4 tex = texture(albedo_tex, uv);
		if (tex.a < 0.333) {
			discard;
		}
		ALBEDO = mix(tex.rgb * mix(1.0, 0.75, wet), haze_color, haze) * brightness * weather.rgb;
	} else {
		// Abaixo da linha d'água, a água pintada do chão (a mesma do Cais) em escala de distância: as faixas, os traços e o
		// brilho, com menos detalhe e mais névoa para o horizonte. Da pintura antiga fica só uma mancha apagada da margem
		// (shore), sem o reflexo das árvores.
		float s = (uv.y - waterline) / max(1.0 - waterline, 0.001);
		vec2 p = vec2(uv.x * width_m, far_m * (1.0 - s) * (1.0 - s));
		float glint;
		vec3 water = painted_water(p, 0.0, glint);
		vec3 painted = texture(albedo_tex, vec2(uv.x, waterline + 0.004)).rgb;
		vec3 color = mix(water, painted, shore * (1.0 - smoothstep(0.0, 0.12, s)));
		color = mix(color, horizon_color, (1.0 - s) * 0.55);
		ALBEDO = mix(color, haze_color, haze * (1.0 - s)) * brightness * weather.rgb;
	}
}
