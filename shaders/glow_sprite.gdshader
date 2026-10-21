// Halo de lâmpada e brasa: disco suave em HDR (acima de 1, o glow do Environment pega).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.72, 0.4);
uniform float energy = 2.5;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float falloff = pow(clamp(1.0 - d, 0.0, 1.0), 2.2);
	ALBEDO = color * energy * falloff * COLOR.rgb;
}
