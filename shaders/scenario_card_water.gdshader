// O card pintado de fundo com a água viva (#140, o panorama da Ponte das Raízes): acima da linha d'água (waterline, na
// altura do UV), a pintura como no scenario_card; abaixo dela, a água pintada do quadro se mexe: as ondinhas quebram a
// pintura na horizontal e os traços e o brilho da água do chão (water_painted.gdshaderinc) passam por cima.
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
// Quanto dos traços das ondinhas aparece por cima da pintura.
uniform float reflection = 0.55;

void fragment() {
	vec2 uv = UV;
	if (uv.y < waterline) {
		vec4 tex = texture(albedo_tex, uv);
		if (tex.a < 0.333) {
			discard;
		}
		ALBEDO = mix(tex.rgb * mix(1.0, 0.75, wet), haze_color, haze) * brightness * weather.rgb;
	} else {
		// A água pintada do quadro, viva: a pintura de baixo da linha d'água quebrada na horizontal pelas ondinhas, com os
		// traços desenhados e o brilho da água do chão por cima (menos detalhe e mais névoa para o horizonte).
		float s = (uv.y - waterline) / max(1.0 - waterline, 0.001);
		vec2 p = vec2(uv.x * width_m, far_m * (1.0 - s) * (1.0 - s));
		float t = TIME * flow;
		float wobble = (wp_noise(vec2(uv.x * 60.0, s * 40.0 - t * 0.5)) - 0.5) * 0.006 * (0.25 + s);
		vec2 moved = vec2(uv.x + wobble, clamp(uv.y + wobble * 0.4, waterline + 0.002, 1.0));
		vec3 painted = texture(albedo_tex, moved).rgb * mix(1.0, 0.85, wet);
		float strokes = wp_strokes(p, t, mix(2.2, 1.0, detail)) * (0.35 + 0.65 * s);
		vec3 color = mix(painted, ripple_color, clamp(strokes, 0.0, 1.0) * reflection * 0.6);
		vec2 cell = floor(vec2(p.x * 0.55 + t * 0.12, p.y * 2.2 / (1.0 + p.y * 0.08)));
		float h = wp_hash(cell + 7.0);
		float glint = sparkle * step(0.93, h) * smoothstep(0.75, 1.0, sin(TIME * 3.0 + h * 40.0)) * clamp(strokes, 0.0, 1.0);
		color = mix(color, sparkle_color, glint * 0.8);
		ALBEDO = mix(color, haze_color, haze * (1.0 - s)) * brightness * weather.rgb;
	}
}
