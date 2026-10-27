// A água pintada dos cenários (#140), comum à água do chão (water_painted.gdshader) e à do fundo pintado
// (scenario_card_water.gdshader): a linguagem dos cards, nada de reflexo realista.
// p: o ponto na água em metros (x ao longo, y a distância da margem da frente, crescendo para o fundo).
// - faixas de cor em degraus (claro na superfície perto, escuro no fundo e longe);
// - ondinhas desenhadas: traços curtos na horizontal que andam devagar;
// - um brilho que pisca nas cristas (parado com "Reduzir efeitos");
// - a espuma na margem e em volta das estacas e dos barcos (foam: 0 a 1, de quem chama).

uniform vec3 surface_color : source_color = vec3(0.30, 0.44, 0.44);
uniform vec3 mid_color : source_color = vec3(0.13, 0.25, 0.27);
uniform vec3 deep_color : source_color = vec3(0.04, 0.10, 0.13);
uniform vec3 ripple_color : source_color = vec3(0.52, 0.66, 0.64);
uniform vec3 sparkle_color : source_color = vec3(0.95, 0.93, 0.80);
uniform vec3 foam_color : source_color = vec3(0.78, 0.84, 0.80);
// A distância (m) em que a água chega à cor do fundo.
uniform float depth_scale = 18.0;
// O passo da animação (1 normal; com "Reduzir efeitos", mais devagar) e o brilho (0 sem piscar).
uniform float flow = 1.0;
uniform float sparkle = 1.0;
// O detalhe das ondinhas (1 perto; menos nos planos de longe).
uniform float detail = 1.0;

float wp_hash(vec2 c) {
	return fract(sin(dot(c, vec2(127.1, 311.7))) * 43758.5453);
}

float wp_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(wp_hash(i), wp_hash(i + vec2(1.0, 0.0)), u.x), mix(wp_hash(i + vec2(0.0, 1.0)), wp_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Um traço de onda por célula: um risco curto e achatado, que anda para o lado e some e volta.
float wp_strokes(vec2 p, float t, float scale) {
	// Com a câmera quase rente, o metro de fundo vira poucos pixels: a célula cresce com a distância para o traço não sumir.
	vec2 q = vec2(p.x * 0.55 / scale + t * 0.12, p.y * 2.2 / scale / (1.0 + p.y * 0.08));
	vec2 cell = floor(q);
	vec2 f = fract(q) - 0.5;
	float h = wp_hash(cell);
	f.x += (h - 0.5) * 0.5;
	float life = 0.5 + 0.5 * sin(t * 0.7 + h * 6.283);
	float d = length(vec2(f.x * 0.9, f.y * 4.0));
	return smoothstep(0.42, 0.30, d) * step(0.35, h) * life;
}

// A cor da água em p. glint: quanto do brilho apareceu (para o emissivo de quem chama).
vec3 painted_water(vec2 p, float foam, out float glint) {
	float t = TIME * flow;
	// As faixas: a distância, com uma ondulação larga, em quatro degraus.
	float depth = clamp(p.y / depth_scale + (wp_noise(vec2(p.x * 0.08 + t * 0.03, p.y * 0.25)) - 0.5) * 0.25, 0.0, 1.0);
	// Os degraus com uma borda curta (não uma linha dura de costura).
	float steps = depth * 4.0;
	float band = (floor(steps) + smoothstep(0.85, 1.0, fract(steps))) / 3.0;
	vec3 color = band < 0.5 ? mix(surface_color, mid_color, band * 2.0) : mix(mid_color, deep_color, band * 2.0 - 1.0);
	// As ondinhas, mais finas e mais apagadas para o fundo.
	float strokes = wp_strokes(p, t, mix(2.2, 1.0, detail)) * mix(0.55, 1.0, detail) * (1.0 - depth * 0.6);
	strokes += wp_strokes(p + vec2(13.7, 0.37), t * 1.3, mix(3.0, 1.6, detail)) * 0.5 * detail * (1.0 - depth);
	color = mix(color, ripple_color, clamp(strokes, 0.0, 1.0) * 0.7);
	// O brilho nas cristas: só nos traços, piscando fora de fase.
	vec2 cell = floor(vec2(p.x * 0.55 + t * 0.12, p.y * 2.2 / (1.0 + p.y * 0.08)));
	float h = wp_hash(cell + 7.0);
	glint = sparkle * step(0.93, h) * smoothstep(0.75, 1.0, sin(TIME * 3.0 + h * 40.0)) * clamp(strokes, 0.0, 1.0);
	color = mix(color, sparkle_color, glint);
	// A espuma: manchas brancas recortadas pelo ruído, mais cheias perto do que encosta.
	float foam_mask = foam * smoothstep(0.35, 0.55, wp_noise(vec2(p.x * 1.6 + t * 0.2, p.y * 3.0 - t * 0.1)) + foam * 0.45);
	return mix(color, foam_color, clamp(foam_mask, 0.0, 1.0) * 0.85);
}
