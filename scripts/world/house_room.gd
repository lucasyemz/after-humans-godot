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
const HEIGHT := 3.4
const WALL_HEIGHT := 3.2
const DOOR_Z := Vector2(-1.4, 0.4)
const SPOT_FRACTIONS := [0.36, 0.56, 0.74]
const GUARD_FRACTION := 0.66
const ENTRANCE_FRACTION := 0.3
## Itens presos na parede do fundo (WallItems da Unreal): loja, item, centro em X, base e altura, em cm.
const WALL_ITEMS := [
	[0, 3, 230, 120, 85], [0, 1, 450, 195, 75], [0, 2, 680, 215, 55], [0, 0, 960, 0, 235],
	[1, 3, 250, 150, 70], [1, 0, 470, 105, 125], [1, 1, 960, 15, 195], [1, 2, 1190, 25, 205],
	[2, 0, 177, 40, 190], [2, 5, 387, 30, 245], [2, 3, 569, 120, 42], [2, 1, 741, 40, 190], [2, 2, 950, 180, 62], [2, 4, 1132, 180, 62],
]

var shop := 0
var spot_xs: Array[float] = []
var guard_x := 0.0
var entrance_x := 0.0
var exit_x := 0.0
var camp_x := 0.0
var _fire_material: ShaderMaterial
var _fire_light: OmniLight3D
var _lamp: OmniLight3D


## Monta a sala com a origem (canto esquerdo do fundo) em origin_x. spots: quantos pontos de busca a casa tem.
func build(shop_index: int, origin_x: float, spots: int, camp: bool) -> void:
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
	guard_x = origin_x + WIDTH * GUARD_FRACTION
	entrance_x = origin_x + WIDTH * ENTRANCE_FRACTION
	exit_x = origin_x + 1.3
	camp_x = origin_x + WIDTH * 0.47
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(WIDTH * 0.5, 3.0, -1.6)
	_lamp.light_color = Color(1.0, 0.82, 0.6)
	_lamp.light_energy = 2.4
	_lamp.omni_range = 11.0
	_lamp.shadow_enabled = true
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
		var body := StaticBody3D.new()
		body.position = mesh.position
		var shape := CollisionShape3D.new()
		var collider := BoxShape3D.new()
		collider.size = box.size
		shape.shape = collider
		body.add_child(shape)
		add_child(body)


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
	var body := StaticBody3D.new()
	body.position = Vector3(WIDTH * 0.5, HEIGHT * 0.5, BACK_Z - 0.15)
	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = Vector3(WIDTH + 0.6, HEIGHT, 0.3)
	shape.shape = collider
	body.add_child(shape)
	add_child(body)


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
	var body := StaticBody3D.new()
	body.position = Vector3(WIDTH * 0.5, 1.0, WALK_FRONT_Z + 0.1)
	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = Vector3(WIDTH, 2.0, 0.2)
	shape.shape = collider
	body.add_child(shape)
	add_child(body)


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
	_fire_light = OmniLight3D.new()
	_fire_light.position = Vector3(camp_x - position.x, 0.8, 0.6)
	_fire_light.light_color = Color(1.0, 0.6, 0.3)
	_fire_light.omni_range = 6.5
	_fire_light.shadow_enabled = true
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
