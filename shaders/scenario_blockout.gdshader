// Blockout dos cenários (port do M_AHBlockout da Unreal): a textura projetada pelo mundo (o tamanho da amostra em m),
// vezes a cor; molhado, escurece e brilha (a rua usa a mesma ideia com as poças).
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 color : source_color = vec3(1.0);
uniform float tile_size = 1.4;
uniform float roughness_value = 0.8;
uniform float wet = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv = n.y >= max(n.x, n.z) ? world_pos.xz : (n.x >= n.z ? vec2(world_pos.z, -world_pos.y) : vec2(world_pos.x, -world_pos.y));
	vec3 base = texture(albedo_tex, uv / max(tile_size, 0.05)).rgb * color;
	ALBEDO = base * mix(1.0, 0.55, wet);
	ROUGHNESS = mix(roughness_value, 0.08, wet * clamp(world_normal.y, 0.0, 1.0));
}
