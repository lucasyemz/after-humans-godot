// Superfície da Estação Raiz (port do M_ShelterSurface da Unreal): a textura projetada pelo mundo por face (piso e teto
// pelo plano horizontal, paredes pelo eixo horizontal da face e a altura), com o tamanho real da amostra (tile_size em
// metros), a tinta e a umidade no rodapé: perto do piso a cor escurece e a superfície fica mais lisa.
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_normal = false;
uniform vec3 tint : source_color = vec3(1.0);
uniform float tile_size = 2.0;
uniform float roughness_scale = 1.0;
uniform float floor_y = 0.0;
uniform float damp_height = 0.35;
uniform float damp_amount = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv = n.y >= max(n.x, n.z) ? world_pos.xz : (n.x >= n.z ? vec2(world_pos.z, -world_pos.y) : vec2(world_pos.x, -world_pos.y));
	uv /= max(tile_size, 0.5);
	vec3 color = texture(albedo_tex, uv).rgb * tint;
	float damp = clamp((floor_y + damp_height - world_pos.y) / max(damp_height, 0.01), 0.0, 1.0) * damp_amount;
	ALBEDO = mix(color, color * 0.55, damp);
	ROUGHNESS = mix(0.9, 0.45, damp) * roughness_scale;
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, uv).rgb;
		NORMAL_MAP_DEPTH = 0.8;
	}
}
