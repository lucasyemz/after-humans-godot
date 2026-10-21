// Fogueira pintada que apaga: com burn 0, as chamas somem (acima das toras, e as amarelas entre elas) e as toras viram
// carvão. Com burn 1, as chamas emitem luz própria (o glow pega).
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float burn : hint_range(0.0, 1.0) = 1.0;
uniform float flicker = 1.0;
// Topo das toras na arte (fração da altura, de cima para baixo).
uniform float logs_top = 0.40;

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	float l = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	// Chama: laranja ou amarela (verde alto); as brasas das toras são vermelhas (verde baixo) e ficam.
	float flame = clamp((t.r - t.b) * 1.6, 0.0, 1.0) * smoothstep(0.32, 0.6, t.g);
	float above = 1.0 - smoothstep(logs_top - 0.03, logs_top + 0.02, UV.y);
	float gone = max(flame, above) * (1.0 - burn);
	if (t.a * (1.0 - gone * 1.3) < 0.5) {
		discard;
	}
	vec3 charcoal = vec3(l * 0.3) * vec3(1.0, 0.9, 0.82);
	ALBEDO = mix(charcoal, t.rgb, burn);
	EMISSION = t.rgb * flame * burn * 1.8 * flicker;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	BACKLIGHT = vec3(0.4);
}
