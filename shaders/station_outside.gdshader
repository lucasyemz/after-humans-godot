// A vista de fora pela abertura da abóbada no fim da linha (#217): um recorte do panorama da cidade alagada, com a cor
// da hora (tint, já com o brilho), o brilho perto do horizonte no amanhecer e no fim de tarde, e estrelas à noite.
// Sem luz própria: a luz que entra é a SpotLight de AHStationOutside.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D sky_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
// rgb: a cor do horizonte; a: a força.
uniform vec4 glow = vec4(1.0, 1.0, 1.0, 0.0);
uniform float stars = 0.0;
// O recorte do panorama: u de início e largura, v de início e altura (embaixo, a linha da água); o horizonte é o pé
// da cidade, em v do panorama.
uniform float crop_u = 0.22;
uniform float crop_w = 0.55;
uniform float crop_v = 0.0;
uniform float crop_h = 0.8;
uniform float horizon = 0.72;

void fragment() {
	vec2 uv = vec2(crop_u + UV.x * crop_w, crop_v + UV.y * crop_h);
	vec3 color = texture(sky_tex, uv).rgb * tint.rgb;
	// O céu fica acima do horizonte: o brilho sobe dele e some para cima.
	float sky = 1.0 - smoothstep(horizon - 0.12, horizon, uv.y);
	float near = smoothstep(0.0, horizon, uv.y) * sky;
	color = mix(color, color + glow.rgb * 0.45, glow.a * near);
	if (stars > 0.0) {
		vec2 cell = floor(uv * vec2(900.0, 260.0));
		float r = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
		float top = 1.0 - smoothstep(0.1, horizon - 0.2, uv.y);
		color += vec3(0.9, 0.92, 1.0) * step(0.995, r) * top * stars * 0.8;
	}
	ALBEDO = color;
}
