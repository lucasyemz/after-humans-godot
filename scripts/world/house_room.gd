## Interior de uma loja da rua (versão enxuta do AAHHouseRoom): uma sala longe da rua, com a parede do fundo, o chão, o
## rodapé e os itens pintados da loja, o teto, uma luminária e as paredes com colisão. A equipe entra pela porta da
## parede da esquerda. Os pontos de busca ficam a 36%, 56% e 74% da largura (SpotFractions); a patrulha, a 66%.
class_name AHHouseRoom
extends Node3D

const ART := "res://art/rooms/"
const SHOP_ART := ["grocery", "workshop", "cinema"]
const WIDTH := 15.0
const BACK_Z := -4.4
## Paredes, chão e teto passam da faixa em direção à câmera, fechando a caixa (FrontY da Unreal); a equipe anda até WALK_FRONT_Z.
const FRONT_Z := 6.0
const WALK_FRONT_Z := 1.4
## A equipe anda a esta distância das paredes do lado e do fundo (m).
const SIDE_MARGIN := 0.65
const BACK_MARGIN := 0.75
const HEIGHT := 3.4
const WALL_HEIGHT := 3.2
const DOOR_Z := Vector2(-1.4, 0.4)
const SPOT_FRACTIONS := [0.36, 0.56, 0.74]
## A frente dos objetos de busca (#50): na frente dos móveis pintados no fundo, atrás de onde a equipe anda.
const SEARCH_PROP_Z := -2.2
const GUARD_FRACTION := 0.66
const ENTRANCE_FRACTION := 0.3
## Item da parede que começa abaixo disto (m) está apoiado no chão e ganha colisão, com esta profundidade a partir da parede.
const FLOOR_ITEM_BOTTOM := 0.5
const FLOOR_ITEM_DEPTH := 0.8
## Itens presos na parede do fundo (WallItems da Unreal): loja, item, centro em X, base e altura, em cm.
const WALL_ITEMS := [
	[0, 3, 230, 120, 85], [0, 1, 450, 195, 75], [0, 2, 680, 215, 55], [0, 0, 960, 0, 235],
	[1, 3, 250, 150, 70], [1, 0, 470, 105, 125], [1, 1, 960, 15, 195], [1, 2, 1190, 25, 205],
	[2, 0, 177, 40, 190], [2, 5, 387, 30, 245], [2, 3, 569, 120, 42], [2, 1, 741, 40, 190], [2, 2, 950, 180, 62], [2, 4, 1132, 180, 62],
]

var shop := 0
## Caixas de colisão visíveis com C (a rua junta estas às dela enquanto a sala está aberta).
var debug_colliders: Array[MeshInstance3D] = []
var debug_material: Material
var spot_xs: Array[float] = []
## O objeto de cada ponto de busca (#50), fechado ou aberto.
var search_props: Array[AHSearchProp] = []
var guard_x := 0.0
var entrance_x := 0.0
var exit_x := 0.0
var camp_x := 0.0
var _fire_material: ShaderMaterial
var _fire_light: OmniLight3D
var _lamp: OmniLight3D


## Monta a sala com a origem (canto esquerdo do fundo) em origin_x. spots: quantos pontos de busca a casa tem;
## searched: quais já foram vasculhados (o objeto deles aparece aberto).
func build(shop_index: int, origin_x: float, spots: int, camp: bool, searched: Array = []) -> void:
	shop = clampi(shop_index, 0, 2)
	position = Vector3(origin_x, 0, 0)
	var art: String = SHOP_ART[shop]
	_floor(art)
	_back_wall(art)
	_walls()
	for item in WALL_ITEMS:
		if item[0] == shop:
			_wall_item(art, item[1], item[2] * 0.01, item[3] * 0.01, item[4] * 0.01)
	for i in mini(spots, 3):
		spot_xs.append(origin_x + WIDTH * SPOT_FRACTIONS[i])
		_search_prop(i, i < searched.size() and searched[i])
	guard_x = origin_x + WIDTH * GUARD_FRACTION
	entrance_x = origin_x + WIDTH * ENTRANCE_FRACTION
	exit_x = origin_x + 1.3
	camp_x = origin_x + WIDTH * 0.47
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(WIDTH * 0.5, 3.0, -1.6)
	_lamp.light_color = Color(1.0, 0.82, 0.6)
	_lamp.light_energy = 2.4
	_lamp.omni_range = 11.0
	# A sombra das luzes da casa segue a qualidade, como a das luminárias (#37).
	_lamp.add_to_group(Settings.SHADOW_LAMPS)
	_lamp.shadow_enabled = Settings.effects().lamp_shadows
	add_child(_lamp)
	if camp:
		_campfire()


func _box(min_corner: Vector3, max_corner: Vector3, material: Material, solid: bool) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = (max_corner - min_corner).abs()
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = (min_corner + max_corner) * 0.5
	add_child(mesh)
	if solid:
		_solid(mesh.position, box.size)


## Caixa só de colisão, com a caixa de depuração que a tecla C mostra.
func _solid(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = size
	shape.shape = collider
	body.add_child(shape)
	var debug := MeshInstance3D.new()
	var debug_box := BoxMesh.new()
	debug_box.size = size
	debug.mesh = debug_box
	debug.material_override = debug_material
	debug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	debug.visible = false
	body.add_child(debug)
	debug_colliders.append(debug)
	add_child(body)


## O objeto do ponto i encostado no fundo, com colisão no volume dele (a equipe vasculha da frente).
func _search_prop(i: int, open: bool) -> void:
	var prop := AHSearchProp.new().setup(AHSearchProp.shop_prop(shop, i), open)
	prop.position = Vector3(WIDTH * SPOT_FRACTIONS[i], 0, SEARCH_PROP_Z - float(prop.spec.depth_m) * 0.5)
	add_child(prop)
	search_props.append(prop)
	var box := prop.volume()
	_solid(box.get_center(), box.size)


static func _tone(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


func _floor(art: String) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(ART + art + "-floor.webp")
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / 2.5
	material.roughness = 0.85
	_box(Vector3(-0.3, -0.2, BACK_Z - 0.3), Vector3(WIDTH + 0.3, 0.0, FRONT_Z), material, false)
	# Forro com cor própria (escuro, mas lendo como teto) e as vigas.
	_box(Vector3(-0.3, HEIGHT, BACK_Z - 0.3), Vector3(WIDTH + 0.3, HEIGHT + 0.2, FRONT_Z), _tone(Color(0.075, 0.055, 0.038)), false)
	for i in 4:
		var x := WIDTH * (i + 0.5) / 4.0
		_box(Vector3(x - 0.12, HEIGHT - 0.22, BACK_Z), Vector3(x + 0.12, HEIGHT, FRONT_Z), _tone(Color(0.05, 0.036, 0.025)), false)


func _back_wall(art: String) -> void:
	var texture: Texture2D = load(ART + art + "-walltile-seamless.webp")
	var tile_width := WALL_HEIGHT * texture.get_width() / texture.get_height()
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_scale = Vector3(WIDTH / tile_width, 1, 1)
	material.roughness = 0.95
	var wall := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(WIDTH + 0.6, WALL_HEIGHT)
	wall.mesh = quad
	wall.material_override = material
	wall.position = Vector3(WIDTH * 0.5, WALL_HEIGHT * 0.5, BACK_Z)
	add_child(wall)
	# Acima da parede pintada, até o teto, o reboco escuro.
	_box(Vector3(-0.3, WALL_HEIGHT, BACK_Z - 0.3), Vector3(WIDTH + 0.3, HEIGHT, BACK_Z), _tone(Color(0.16, 0.12, 0.09)), false)
	var trim_texture: Texture2D = load(ART + art + "-trim-cut.webp")
	if trim_texture != null:
		var trim_height := 0.32
		var trim := MeshInstance3D.new()
		var trim_quad := QuadMesh.new()
		trim_quad.size = Vector2(WIDTH + 0.6, trim_height)
		trim.mesh = trim_quad
		var trim_material := StandardMaterial3D.new()
		trim_material.albedo_texture = trim_texture
		trim_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		trim_material.uv1_scale = Vector3((WIDTH + 0.6) / (trim_height * trim_texture.get_width() / trim_texture.get_height()), 1, 1)
		trim.material_override = trim_material
		trim.position = Vector3(WIDTH * 0.5, trim_height * 0.5, BACK_Z + 0.03)
		add_child(trim)
	# Parede do fundo com colisão (a equipe não atravessa).
	_solid(Vector3(WIDTH * 0.5, HEIGHT * 0.5, BACK_Z - 0.15), Vector3(WIDTH + 0.6, HEIGHT, 0.3))


func _walls() -> void:
	var plaster := _tone(Color(0.24, 0.19, 0.15))
	# Esquerda: a fachada vista de dentro, com o vão da porta na linha da equipe.
	_box(Vector3(-0.3, 0, BACK_Z - 0.3), Vector3(0, HEIGHT, DOOR_Z.x), plaster, true)
	_box(Vector3(-0.3, 0, DOOR_Z.y), Vector3(0, HEIGHT, FRONT_Z), plaster, true)
	_box(Vector3(-0.3, 2.4, DOOR_Z.x), Vector3(0, HEIGHT, DOOR_Z.y), plaster, false)
	# A rua lá fora, pelo vão: uma luz fria entrando.
	var street_light := OmniLight3D.new()
	street_light.position = Vector3(-1.2, 1.6, (DOOR_Z.x + DOOR_Z.y) * 0.5)
	street_light.light_color = Color(0.7, 0.8, 1.0)
	street_light.light_energy = 1.2
	street_light.omni_range = 5.0
	add_child(street_light)
	_box(Vector3(WIDTH, 0, BACK_Z - 0.3), Vector3(WIDTH + 0.3, HEIGHT, FRONT_Z), plaster, true)
	# Frente aberta para a câmera, mas com colisão (a equipe não sai da sala pela frente).
	_solid(Vector3(WIDTH * 0.5, 1.0, WALK_FRONT_Z + 0.1), Vector3(WIDTH, 2.0, 0.2))


func _wall_item(art: String, item: int, center_x: float, bottom: float, height: float) -> void:
	var path := ART + "%s-item%d.webp" % [art, item]
	if not ResourceLoader.exists(path):
		return
	var texture: Texture2D = load(path)
	var card := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(height * texture.get_width() / texture.get_height(), height)
	card.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.roughness = 1.0
	card.material_override = material
	card.position = Vector3(center_x, bottom + height * 0.5, BACK_Z + 0.4)
	add_child(card)
	# Móveis no chão (prateleiras, balcões, bancadas, poltronas): a equipe para na frente deles, não passa por dentro.
	# Os quadros e luminárias presos no alto da parede ficam sem colisão.
	if bottom < FLOOR_ITEM_BOTTOM:
		_solid(Vector3(center_x, height * 0.5, BACK_Z + FLOOR_ITEM_DEPTH * 0.5), Vector3(quad.size.x * 0.85, height, FLOOR_ITEM_DEPTH))


func _campfire() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	_fire_material = ShaderMaterial.new()
	_fire_material.shader = preload("res://shaders/campfire.gdshader")
	_fire_material.set_shader_parameter("albedo_tex", load("res://art/street/campfire-v1.png"))
	_fire_material.set_shader_parameter("burn", 0.0)
	var fire := MeshInstance3D.new()
	fire.mesh = quad
	fire.material_override = _fire_material
	fire.position = Vector3(camp_x - position.x, 0.45, 0.35)
	add_child(fire)
	_solid(Vector3(camp_x - position.x, 0.3, 0.3), Vector3(0.8, 0.6, 0.55))
	_fire_light = OmniLight3D.new()
	_fire_light.position = Vector3(camp_x - position.x, 0.8, 0.6)
	_fire_light.light_color = Color(1.0, 0.6, 0.3)
	_fire_light.omni_range = 6.5
	_fire_light.add_to_group(Settings.SHADOW_LAMPS)
	_fire_light.shadow_enabled = Settings.effects().lamp_shadows
	_fire_light.visible = false
	add_child(_fire_light)


## Acampamento: a fogueira acende e a luminária cai para 25% (como a cena da Unreal).
func set_camp_lit(lit: bool) -> void:
	if _fire_material == null:
		return
	_fire_material.set_shader_parameter("burn", 1.0 if lit else 0.0)
	_fire_light.visible = lit
	_fire_light.light_energy = 2.6
	_lamp.light_energy = 0.6 if lit else 2.4


func _process(_delta: float) -> void:
	if _fire_light != null and _fire_light.visible:
		var t := Time.get_ticks_msec() * 0.001
		_fire_light.light_energy = 2.6 * (0.85 + 0.15 * sin(t * 13.0) * sin(t * 7.3 + 1.1))
