// Uma camada do vagão 2D em mistura alfa (#149, #256): as folhas das portas (o vidro delas é semitransparente) e o
// reflexo das janelas. O mesmo brilho e o mesmo clima de train_layer.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform float brightness = 1.0;
uniform float wet = 0.0;
uniform vec4 weather = vec4(1.0);

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	ALBEDO = tex.rgb * mix(1.0, 0.75, wet) * brightness * weather.rgb;
	ALPHA = tex.a;
}
