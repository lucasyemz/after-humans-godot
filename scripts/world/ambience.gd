## A câmera de cinema de cada lugar (#153): o perfil de data/presentation/ambience.json (o default com o que o lugar
## troca) e o que a barra de Admin mudou por cima (Admin.ambience, ao vivo). Aplica no pós-processamento
## (post_emberfall), no Environment e nas partículas do ar. A qualidade manda: no Baixo, sem o desfoque de profundidade
## e com pouca partícula; a névoa volumétrica só no Forward+ e a partir do Alto (Settings.effects).
class_name AHAmbience
extends RefCounted

const PATH := "res://data/presentation/ambience.json"
## Os campos do pós com o nome do uniform do post_emberfall.gdshader.
const POST_FIELDS := ["saturation", "contrast", "tint_amount", "shadows_tint", "highlights_tint", "chromatic_aberration",
	"vignette", "grain", "focus_center", "focus_width", "max_blur"]
## No Baixo, quanto sobra das partículas do ar.
const LOW_PARTICLES := 0.35

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data


## O perfil do lugar (o id do mapa, "ShopfrontStreet" para a Rua, "Station"): o default, o do lugar e o do Admin.
static func profile(id: String) -> Dictionary:
	var out: Dictionary = data().get("default", {}).duplicate(true)
	out.merge(data().get(id, {}), true)
	var admin = Engine.get_main_loop().root.get_node_or_null("Admin") if Engine.get_main_loop() is SceneTree else null
	if admin != null and admin.allowed():
		out.merge(admin.ambience.get(id, {}), true)
	return out


## O perfil como texto, para o Lucas mandar os números (Admin: Copiar o perfil). Só os campos que saem do default.
static func profile_text(id: String) -> String:
	var full := profile(id)
	var base: Dictionary = data().get("default", {})
	var diff := {}
	for key in full:
		if full[key] != base.get(key):
			diff[key] = full[key]
	return "\"%s\": %s" % [id, JSON.stringify(diff)]


static func post_values(p: Dictionary, quality: int) -> Dictionary:
	var out := {}
	for key in POST_FIELDS:
		var value = p.get(key)
		if value is Array:
			value = Vector3(float(value[0]), float(value[1]), float(value[2]))
		out[key] = value
	# No Baixo, sem o desfoque de profundidade (a passada mais cara do pós).
	if quality <= 0:
		out.max_blur = 0.0
	return out


static func apply_post(post: ShaderMaterial, p: Dictionary, quality: int) -> void:
	var values := post_values(p, quality)
	for key in values:
		post.set_shader_parameter(key, values[key])


## O glow e a névoa por altura do Environment (a densidade da névoa e a volumétrica entram junto com o clima).
static func apply_env(env: Environment, p: Dictionary, base_glow: float) -> void:
	env.glow_hdr_threshold = float(p.glow_threshold)
	env.glow_intensity = base_glow * float(p.glow_intensity)
	env.fog_height = float(p.fog_height)
	env.fog_height_density = float(p.fog_height_density)


## Quanto de uma partícula do ar (0 a 1) com a qualidade.
static func particles(p: Dictionary, key: String, quality: int) -> float:
	return float(p.get(key, 0.0)) * (LOW_PARTICLES if quality <= 0 else 1.0)
