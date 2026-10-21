// Pós-processamento no estilo do Emberfall, numa passada de tela que roda igual no Forward+ e no Compatibility (web):
// tilt-shift com bokeh nas luzes, aberração cromática, grading com sombras frias e luzes quentes, vinheta e grão.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform bool enabled = true;

group_uniforms tilt_shift;
// Faixa nítida em coordenadas de tela (0 = topo).
uniform float focus_center = 0.62;
uniform float focus_width = 0.30;
uniform float focus_feather = 0.30;
// Raio máximo em pixels numa tela de 1080 linhas.
uniform float max_blur = 11.0;
uniform float bokeh_boost = 1.8;

group_uniforms grade;
uniform vec3 shadows_tint = vec3(-0.04, 0.05, 0.15);
uniform vec3 highlights_tint = vec3(0.06, 0.03, -0.02);
uniform float tint_amount = 0.45;
uniform float saturation = 1.12;
uniform float contrast = 1.05;
uniform float chromatic_aberration = 0.0015;

group_uniforms vignette;
uniform float vignette = 0.55;
uniform vec3 vignette_color : source_color = vec3(0.05, 0.025, 0.04);
uniform float vignette_softness = 0.55;
uniform float grain = 0.03;

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (!enabled) {
		COLOR = vec4(texture(screen_tex, uv).rgb, 1.0);
	} else {
		vec2 px = SCREEN_PIXEL_SIZE;
		float aspect = px.y / px.x;

		// Aberração cromática, mais forte nas bordas.
		vec2 dir = uv - 0.5;
		vec3 base = vec3(texture(screen_tex, uv + dir * chromatic_aberration).r, texture(screen_tex, uv).g,
			texture(screen_tex, uv - dir * chromatic_aberration).b);

		// Tilt-shift: o desfoque cresce acima e abaixo da faixa nítida; as luzes pesam mais (bokeh).
		float d = abs(uv.y - focus_center) - focus_width * 0.5;
		float coc = smoothstep(0.0, 1.0, clamp(d / focus_feather, 0.0, 1.0));
		float radius = coc * max_blur * (1.0 / px.y) / 1080.0;
		vec3 col = base;
		if (radius > 0.6) {
			vec3 acc = base;
			float weights = 1.0;
			for (int i = 0; i < 24; i++) {
				float fi = float(i) + 0.5;
				float r = sqrt(fi / 24.0) * radius;
				float a = fi * 2.39996;
				vec3 s = texture(screen_tex, uv + vec2(cos(a), sin(a)) * r * px).rgb;
				float w = 1.0 + bokeh_boost * smoothstep(0.6, 1.0, luma(s)) * coc;
				acc += s * w;
				weights += w;
			}
			col = acc / weights;
		}

		// Grading: sombras frias, luzes quentes, um pouco mais de saturação e contraste.
		float l = luma(col);
		col += shadows_tint * tint_amount * (1.0 - smoothstep(0.0, 0.45, l));
		col += highlights_tint * tint_amount * smoothstep(0.45, 1.0, l);
		col = mix(vec3(luma(col)), col, saturation);
		col = (col - 0.5) * contrast + 0.5;

		// Vinheta arredondada e grão.
		float r = length(dir * vec2(aspect, 1.0)) / length(vec2(aspect, 1.0) * 0.5);
		col = mix(col, vignette_color, smoothstep(1.0 - vignette_softness - 0.2, 1.05, r) * vignette);
		col += (hash(uv / px + fract(TIME) * 91.7) - 0.5) * grain;
		COLOR = vec4(max(col, vec3(0.0)), 1.0);
	}
}
