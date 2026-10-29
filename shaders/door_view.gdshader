// O lado de fora visto por uma porta aberta de dentro de um interior (#141): o céu em cima e a água pintada embaixo
// (water_painted.gdshaderinc), com a cor da hora de fora e, com chuva, o véu cinza e os riscos dela. Sem luz própria.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/water_painted.gdshaderinc"

uniform sampler2D sky_tex : source_color, filter_linear_mipmap;
uniform float horizon = 0.55;
uniform vec4 weather = vec4(1.0);
uniform float wet = 0.0;
uniform float brightness = 1.0;
// A largura que a vista finge ter (m), para as ondinhas terem o tamanho das de fora.
uniform float width_m = 6.0;

void fragment() {
	vec3 color;
	if (UV.y < horizon) {
		color = texture(sky_tex, vec2(0.3 + UV.x * 0.25, 0.25 + UV.y * 0.6)).rgb;
	} else {
		float s = (UV.y - horizon) / (1.0 - horizon);
		float glint;
		color = painted_water(vec2(UV.x * width_m, 30.0 * (1.0 - s) * (1.0 - s)), 0.0, glint);
	}
	if (wet > 0.0) {
		// A chuva lá fora: o céu e a água ficam cinza, e os riscos descem pela porta.
		color = mix(color, vec3(dot(color, vec3(0.33))) * 0.9, 0.45 * wet);
		vec2 cell = vec2(UV.x * 38.0, UV.y * 3.0 + TIME * 4.5);
		float lane = fract(sin(floor(cell.x) * 91.7) * 4375.5);
		float streak = step(0.82, fract(cell.y + lane)) * step(0.55, lane) * smoothstep(0.5, 0.0, abs(fract(cell.x) - 0.5));
		color += vec3(0.16) * streak * wet;
	}
	ALBEDO = color * brightness * weather.rgb;
}
