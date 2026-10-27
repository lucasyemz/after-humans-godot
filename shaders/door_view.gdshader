// O lado de fora visto por uma porta aberta de dentro de um interior (#141): o céu em cima e a água pintada embaixo
// (water_painted.gdshaderinc), com a cor do clima e da hora como os cards. Sem luz própria.
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
	ALBEDO = color * brightness * weather.rgb;
}
