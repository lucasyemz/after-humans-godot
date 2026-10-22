## A parte fixa da Rua das Vitrines (#8): o chão, os prédios com as fachadas pintadas, os becos, os postes, os carros, os
## props da calçada e as silhuetas do fundo, com a colisão de cada um. tools/bake_street.gd monta uma vez e grava em
## scenes/street_set.tscn, que a rua carrega pronta: dá para mexer nela no editor. Cada peça fica num nó próprio (Lamp1,
## Building3, Car2, Prop7…) com a placa, a colisão, a luz e o halo dela: mover o nó leva tudo junto.
## O que a rua mexe depois de abrir (as luzes no clima, os feixes de sol, o chão molhado, as caixas da tecla C) ela acha
## pelos grupos gravados na cena e pelos metadados dos materiais. Os mesmos auxiliares (add_card, add_collider...)
## montam o que é dinâmico (a fogueira, a colisão dos cenários) num AHStreetSet que não é gravado.
class_name AHStreetSet
extends Node3D

const ART := "res://art/street/"
const SCENE := "res://scenes/street_set.tscn"
const LAMP_GROUP := "street_lamp_light"
const DOOR_LIGHT_GROUP := "street_door_light"
const SHAFT_GROUP := "street_shaft"
const SKYLINE_GROUP := "street_skyline"
const DEBUG_GROUP := "street_debug_collider"
## A cena que a rua carrega (os testes trocam por uma cópia mexida).
static var scene_path := SCENE

# Profundidade (Y) e altura (Z), de AHShopfrontStreetBlockout.cpp.
const SIDEWALK_FRONT_Y := -150.0
const FACADE_FRONT_Y := -330.0
const FACADE_BACK_Y := -360.0
const SIDEWALK_TOP_Z := 15.0
const STREET_MIN_X := -1600.0
const STREET_MAX_X := 9200.0
const FACADE_WIDTH := 900.0
const FACADE_HEIGHT := 600.0
const BUILDING_BACK_Y := -1500.0
const ALLEY_BACK_Y := -1500.0
const CAR_HEIGHT := 150.0
const LAMP_XS := [1480.0, 3860.0, 6280.0]
const LAMP_Y := -245.0
const LAMP_HEIGHT := 450.0
const DOOR_LIGHTS := [Vector3(880, -140, 280), Vector3(2175, -140, 260), Vector3(3280, -140, 300)]

# Peças de caixa: cor (sRGB), rugosidade e textura repetida (cm por repetição). wet: molha na chuva.
const PIECES := {
	"asphalt": {"color": Color8(255, 255, 255), "roughness": 0.8, "texture": "asphalt-v1.webp", "tile": 400.0, "wet": true},
	"sidewalk": {"color": Color8(150, 150, 145), "roughness": 0.75, "texture": "plaster-v1.webp", "tile": 250.0, "wet": true},
	"concrete": {"color": Color8(255, 255, 255), "roughness": 0.85, "texture": "plaster-v1.webp", "tile": 300.0, "wet": false},
	"brick": {"color": Color8(255, 255, 255), "roughness": 0.9, "texture": "alley-brick-v1.webp", "tile": 300.0, "wet": false},
}
# Chão: sem colisão (o líder flutua na altura do piso).
const FLOOR_PIECES := ["asphalt", "sidewalk"]

# Recortes de arte: arquivo, tamanho da imagem e retângulo (x, y, largura, altura) em pixels.
const FACADES := ["grocery-v1.webp", "workshop-v1.webp", "cinema-v1.webp"]
const DOOR_OVERLAYS := [Rect2(624, 616, 288, 390), Rect2(168, 552, 618, 460), Rect2(612, 660, 312, 350)]
const LONG_SIDE_WALLS := ["side-long-fire-escape.png", "side-long-plain.png"]
const SKYLINES := ["background0.png", "background1.png", "background2.png"]
const VEHICLES := [Rect2(20, 117, 814, 363), Rect2(920, 92, 799, 388)]
const ALLEY := {
	"bin": Rect2(86, 142, 216, 329), "dumpster": Rect2(384, 166, 379, 305), "crate": Rect2(828, 119, 282, 360),
	"bag": Rect2(1190, 222, 306, 261), "barrel": Rect2(82, 583, 218, 343), "pallet": Rect2(418, 601, 296, 321),
	"rubble": Rect2(1184, 719, 312, 203),
}
# Props da calçada: atlas, recorte, X, Y, altura, espelho.
const SIDEWALK_PROPS := [
	["props-street-v1.webp", Rect2(994, 1010, 209, 180), -380, -295, 50, false],
	["props-street-v1.webp", Rect2(346, 1042, 257, 130), 120, -285, 45, false],
	["props-street-v1.webp", Rect2(713, 357, 143, 230), 330, -280, 75, false],
	["props-service-v1.webp", Rect2(662, 68, 241, 207), 1180, -290, 60, false],
	["props-storefront-v1.webp", Rect2(396, 639, 148, 266), 1640, -300, 105, false],
	["props-service-v1.webp", Rect2(967, 87, 252, 183), 1870, -290, 55, true],
	["props-service-v1.webp", Rect2(684, 966, 194, 231), 2380, -290, 80, false],
	["props-service-v1.webp", Rect2(394, 651, 149, 249), 2700, -300, 95, false],
	["props-street-v1.webp", Rect2(1031, 96, 129, 179), 3020, -275, 55, false],
	["props-storefront-v1.webp", Rect2(48, 81, 257, 178), 3560, -300, 80, false],
	["props-street-v1.webp", Rect2(69, 402, 208, 178), 4080, -280, 85, false],
	["props-street-v1.webp", Rect2(713, 357, 143, 230), 4260, -280, 75, true],
	["props-street-v1.webp", Rect2(60, 715, 220, 169), 4720, -290, 45, false],
	["props-service-v1.webp", Rect2(344, 945, 251, 272), 5020, -295, 100, true],
	["props-street-v1.webp", Rect2(370, 706, 221, 184), 5480, -290, 45, false],
	["props-street-v1.webp", Rect2(994, 1010, 209, 180), 5900, -300, 55, true],
	["props-street-v1.webp", Rect2(346, 1042, 257, 130), 6060, -285, 45, true],
	["props-storefront-v1.webp", Rect2(702, 643, 154, 268), 6720, -300, 110, false],
	["props-street-v1.webp", Rect2(665, 968, 257, 228), 7120, -290, 90, false],
]
# Carros: X inicial, modelo, espelho.
const CARS := [[-350.0, 0, false], [5650.0, 1, true], [2650.0, 0, true]]
# Prédios com fachada pintada: X inicial (cm), fachada (0 mercearia, 1 oficina, 2 cinema) e espelho. Ordem de Rebuild.
const FACADE_BUILDINGS := [[-770, 1, true], [430, 0, false], [1635, 1, false], [2830, 2, false], [4030, 0, true], [5230, 1, true], [6430, 2, true]]

## A caixa vermelha da colisão (tecla C).
var debug_material: StandardMaterial3D
var _target: Node3D = self
var _counts := {}
var _materials := {}
var _textures := {}


static func ue(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, z, y) * 0.01


func _init() -> void:
	debug_material = StandardMaterial3D.new()
	debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	debug_material.albedo_color = Color(1.0, 0.15, 0.1, 0.35)
	debug_material.no_depth_test = true


## Monta a rua inteira (a ferramenta grava o resultado; o jogo carrega a cena gravada).
func build() -> void:
	_build_street()
	_build_buildings()
	_build_props()
	_build_backdrop()


## Uma peça nova: um nó com nome, na posição dela; o que vem depois entra nele (em coordenadas do mundo) até end().
func begin(node_name: String, at: Vector3) -> void:
	var group := Node3D.new()
	group.name = node_name
	group.position = at
	add_child(group)
	_target = group


## Fecha a peça: os filhos foram postos em coordenadas do mundo; passam a ficar relativos ao nó dela.
func end(relative: bool = true) -> void:
	if relative:
		for child in _target.get_children():
			child.position -= _target.position
	_target = self


## O nó da peça aberta (begin), para pôr nele o que não sai dos auxiliares.
func current() -> Node3D:
	return _target


func _next_index(prefix: String) -> int:
	_counts[prefix] = int(_counts.get(prefix, 0)) + 1
	return _counts[prefix]


func art(file: String) -> Texture2D:
	if not _textures.has(file):
		_textures[file] = load(ART + file)
	return _textures[file]



## Material de placa pintada: recorte do atlas por UV, espelho invertendo o U, recorte pelo alfa.
func _card_material(file: String, rect: Rect2, mirror: bool, alpha: bool) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [file, rect, mirror]
	if _materials.has(key):
		return _materials[key]
	var texture := art(file)
	var size := Vector2(texture.get_width(), texture.get_height())
	if rect.size == Vector2.ZERO:
		rect = Rect2(Vector2.ZERO, size)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	material.metallic_specular = 0.15
	# Placas finas: a luz de trás também conta (a fogueira e os postes ficam dos dois lados).
	material.backlight_enabled = true
	material.backlight = Color(0.45, 0.45, 0.45)
	if alpha:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
	var u0 := (rect.position.x + (rect.size.x if mirror else 0.0)) / size.x
	material.uv1_offset = Vector3(u0, rect.position.y / size.y, 0)
	material.uv1_scale = Vector3((-rect.size.x if mirror else rect.size.x) / size.x, rect.size.y / size.y, 1)
	_materials[key] = material
	return material



## Placa de pé (AddCard): base no ponto dado, altura em cm, largura pela proporção do recorte. yaw em graus da Unreal.
## solid: uma caixa de colisão no pé da placa (80% da largura, depth cm de fundo).
func add_card(file: String, rect: Rect2, bottom: Vector3, height: float, yaw: float = 0.0, mirror: bool = false,
		shadow: bool = true, alpha: bool = true, solid: bool = false, depth: float = 50.0) -> MeshInstance3D:
	var texture := art(file)
	var size := rect.size if rect.size != Vector2.ZERO else Vector2(texture.get_width(), texture.get_height())
	var width := height * size.x / size.y
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height) * 0.01
	var card := MeshInstance3D.new()
	card.mesh = quad
	card.material_override = _card_material(file, rect, mirror, alpha)
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.position = ue(bottom.x, bottom.y, bottom.z + height * 0.5)
	card.rotation_degrees.y = -yaw
	card.name = "Card"
	_target.add_child(card, true)
	if solid:
		add_collider(ue(bottom.x, bottom.y, bottom.z + height * 0.5), Vector3(width * 0.8, height, depth) * 0.01)
	return card



## Colisão estática (metros, eixos da Godot), com uma caixa vermelha que a tecla C mostra.
func add_collider(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Collider"
	body.position = center
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var debug := MeshInstance3D.new()
	var debug_box := BoxMesh.new()
	debug_box.size = size
	debug.mesh = debug_box
	debug.material_override = debug_material
	debug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	debug.visible = false
	debug.add_to_group(DEBUG_GROUP, true)
	debug.name = "DebugBox"
	body.add_child(debug)
	_target.add_child(body, true)



func _piece_material(piece: String) -> StandardMaterial3D:
	var key := "piece|" + piece
	if _materials.has(key):
		return _materials[key]
	var spec: Dictionary = PIECES[piece]
	var material := StandardMaterial3D.new()
	material.albedo_color = spec.color
	material.roughness = spec.roughness
	material.albedo_texture = art(spec.texture)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / (spec.tile * 0.01)
	material.set_meta("street_piece", piece)
	if spec.wet:
		# Poças: um ruído na rugosidade, que só aparece quando o chão molha (_apply_wet).
		var noise := FastNoiseLite.new()
		noise.frequency = 0.012
		noise.seed = 7
		var ramp := Gradient.new()
		ramp.set_offset(0, 0.32)
		ramp.set_offset(1, 0.72)
		var puddles := NoiseTexture2D.new()
		puddles.width = 512
		puddles.height = 512
		puddles.seamless = true
		puddles.noise = noise
		puddles.color_ramp = ramp
		material.set_meta("puddles", puddles)
	_materials[key] = material
	return material



## Caixa entre dois cantos (AddBox). Paredes e prédios também colidem; o chão não.
func add_box(piece: String, min_corner: Vector3, max_corner: Vector3) -> void:
	var a := ue(min_corner.x, min_corner.y, min_corner.z)
	var b := ue(max_corner.x, max_corner.y, max_corner.z)
	var box := BoxMesh.new()
	box.size = (b - a).abs()
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = _piece_material(piece)
	mesh.position = (a + b) * 0.5
	mesh.name = piece.capitalize()
	_target.add_child(mesh, true)
	if not FLOOR_PIECES.has(piece):
		add_collider(mesh.position, box.size)



func add_glow(center: Vector3, size: float, color: Color, energy: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size * 0.01
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/glow_sprite.gdshader")
	material.set_shader_parameter("color", color)
	material.set_shader_parameter("energy", energy)
	var glow := MeshInstance3D.new()
	glow.mesh = quad
	glow.material_override = material
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = ue(center.x, center.y, center.z)
	glow.name = "Glow"
	_target.add_child(glow, true)
	return glow



func add_light(at: Vector3, energy: float, light_range: float, shadow: bool) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = ue(at.x, at.y, at.z)
	light.light_color = Color8(255, 205, 160)
	light.light_energy = energy
	light.omni_range = light_range * 0.01
	light.omni_attenuation = 1.4
	light.shadow_enabled = shadow
	light.light_volumetric_fog_energy = 2.5
	light.light_specular = 0.35
	light.name = "Light"
	_target.add_child(light, true)
	return light



func _build_street() -> void:
	begin("Ground", Vector3.ZERO)
	add_box("asphalt", Vector3(STREET_MIN_X, SIDEWALK_FRONT_Y, -20), Vector3(STREET_MAX_X, 900, 0))
	add_box("sidewalk", Vector3(STREET_MIN_X, FACADE_BACK_Y, -20), Vector3(STREET_MAX_X, SIDEWALK_FRONT_Y, SIDEWALK_TOP_Z))
	end()
	# Postes pintados com a luz sob a cúpula e um halo na lâmpada. O mastro fica a ~1/4 da largura à direita do centro.
	for i in LAMP_XS.size():
		var lamp_x: float = LAMP_XS[i]
		begin("Lamp%d" % (i + 1), ue(lamp_x, LAMP_Y, SIDEWALK_TOP_Z))
		add_card("lamp.png", Rect2(), Vector3(lamp_x, LAMP_Y, SIDEWALK_TOP_Z), LAMP_HEIGHT, 0.0, false, false)
		add_collider(ue(lamp_x + 52, LAMP_Y, LAMP_HEIGHT * 0.5), Vector3(0.24, LAMP_HEIGHT * 0.01, 0.24))
		add_glow(Vector3(lamp_x - 53, LAMP_Y + 6, 385), 70.0, Color(1.0, 0.72, 0.4), 3.0)
		add_light(Vector3(lamp_x - 53, LAMP_Y + 30, 370), 1.6, 750.0, true).add_to_group(LAMP_GROUP, true)
		end()
	for i in DOOR_LIGHTS.size():
		begin("DoorLight%d" % (i + 1), ue(DOOR_LIGHTS[i].x, DOOR_LIGHTS[i].y, DOOR_LIGHTS[i].z))
		add_light(DOOR_LIGHTS[i], 0.6, 550.0, false).add_to_group(DOOR_LIGHT_GROUP, true)
		end()



func _build_buildings() -> void:
	_build_brick_block(-1600, -770)
	_build_facade_building(-770, 1, true)
	_build_alley(130, 430, 0)
	_build_facade_building(430, 0, false)
	_build_alley(1330, 1635, 1)
	_build_facade_building(1635, 1, false)
	_build_alley(2535, 2830, 2)
	_build_facade_building(2830, 2, false)
	_build_alley(3730, 4030, 0)
	_build_facade_building(4030, 0, true)
	_build_alley(4930, 5230, 1)
	_build_facade_building(5230, 1, true)
	_build_alley(6130, 6430, 2)
	_build_facade_building(6430, 2, true)
	_build_brick_block(7330, STREET_MAX_X)



func _build_facade_building(x0: float, facade: int, mirror: bool) -> void:
	begin("Building%d" % _next_index("Building"), ue(x0 + FACADE_WIDTH * 0.5, FACADE_FRONT_Y, 0))
	var x1 := x0 + FACADE_WIDTH
	var mid := (x0 + x1) * 0.5
	var top := FACADE_HEIGHT + SIDEWALK_TOP_Z + 5
	add_box("concrete", Vector3(x0, BUILDING_BACK_Y, 0), Vector3(x1, FACADE_FRONT_Y, top))
	add_box("concrete", Vector3(x0 - 10, BUILDING_BACK_Y - 10, top), Vector3(x1 + 10, FACADE_FRONT_Y + 10, top + 25))
	add_card(FACADES[facade], Rect2(), Vector3(mid, FACADE_FRONT_Y + 1, SIDEWALK_TOP_Z), FACADE_HEIGHT, 0.0, mirror, false, false)
	# Laterais longas encadeadas até o fundo, alternando a variante e o espelho.
	for side in 2:
		var side_x := x0 - 1 if side == 0 else x1 + 1
		var start_y := FACADE_FRONT_Y
		var slot := 0
		while start_y > BUILDING_BACK_Y + 1:
			var wall: String = LONG_SIDE_WALLS[(facade + side + slot) % LONG_SIDE_WALLS.size()]
			var long_mirror := (side == 0) != (slot % 2 == 1)
			add_card(wall, Rect2(), Vector3(side_x, start_y - FACADE_HEIGHT * 0.5, SIDEWALK_TOP_Z), FACADE_HEIGHT, 90.0, long_mirror, false, false)
			start_y -= FACADE_HEIGHT
			slot += 1
	end()



func _build_brick_block(x0: float, x1: float) -> void:
	begin("BrickBlock%d" % _next_index("BrickBlock"), ue((x0 + x1) * 0.5, FACADE_FRONT_Y, 0))
	add_box("brick", Vector3(x0, BUILDING_BACK_Y, 0), Vector3(x1, FACADE_FRONT_Y, 760))
	add_box("concrete", Vector3(x0, BUILDING_BACK_Y, 760), Vector3(x1, FACADE_FRONT_Y + 10, 790))
	end()



func _build_alley(x0: float, x1: float, variant: int) -> void:
	begin("Alley%d" % _next_index("Alley"), ue((x0 + x1) * 0.5, FACADE_BACK_Y, 0))
	add_box("sidewalk", Vector3(x0, ALLEY_BACK_Y, -20), Vector3(x1, FACADE_BACK_Y, SIDEWALK_TOP_Z))
	add_box("brick", Vector3(x0 - 20, ALLEY_BACK_Y - 30, 0), Vector3(x1 + 20, ALLEY_BACK_Y, 650))
	var mid := (x0 + x1) * 0.5
	var atlas := "alley-props-v1.webp"
	match variant % 3:
		0:
			add_card(atlas, ALLEY.dumpster, Vector3(mid - 30, -1050, SIDEWALK_TOP_Z), 130, 0.0, false, true, true, true, 90.0)
			add_card(atlas, ALLEY.bag, Vector3(mid + 85, -880, SIDEWALK_TOP_Z), 60, 0.0, false, true, true, true)
		1:
			add_card(atlas, ALLEY.crate, Vector3(mid - 60, -980, SIDEWALK_TOP_Z), 110, 0.0, false, true, true, true, 70.0)
			add_card(atlas, ALLEY.barrel, Vector3(mid + 70, -820, SIDEWALK_TOP_Z), 95, 0.0, false, true, true, true)
			add_card(atlas, ALLEY.pallet, Vector3(mid + 40, -1300, SIDEWALK_TOP_Z), 100, 0.0, true, true, true, true)
		_:
			add_card(atlas, ALLEY.bin, Vector3(mid - 70, -900, SIDEWALK_TOP_Z), 95, 0.0, false, true, true, true)
			add_card(atlas, ALLEY.bin, Vector3(mid + 10, -960, SIDEWALK_TOP_Z), 95, 0.0, true, true, true, true)
			add_card(atlas, ALLEY.rubble, Vector3(mid + 70, -760, SIDEWALK_TOP_Z), 45, 0.0, false, true, true, true)
	# Feixe de sol entrando pelo beco (a névoa volumétrica faz isso no Forward+; aqui vale para os dois).
	_add_shaft(Vector3(mid - 40, -900, 380), 260.0, 620.0)
	end()



func _build_props() -> void:
	var door_xs: Array = []
	for building in FACADE_BUILDINGS:
		var overlay: Rect2 = DOOR_OVERLAYS[building[1]]
		var offset: float = (overlay.position.x + overlay.size.x * 0.5 - 768.0) * FACADE_WIDTH / 1536.0
		door_xs.append([building[0] + FACADE_WIDTH * 0.5 + (-offset if building[2] else offset), overlay.size.x * FACADE_WIDTH / 1536.0 * 0.5])
	for prop in SIDEWALK_PROPS:
		var rect: Rect2 = prop[1]
		var half: float = prop[4] * rect.size.x / rect.size.y * 0.5
		var blocks := door_xs.any(func(door): return absf(prop[2] - door[0]) < door[1] + half + 40.0)
		if not blocks:
			begin("Prop%d" % _next_index("Prop"), ue(prop[2], prop[3], SIDEWALK_TOP_Z))
			add_card(prop[0], rect, Vector3(prop[2], prop[3], SIDEWALK_TOP_Z), prop[4], 0.0, prop[5], true, true, true)
			end()
	for car in CARS:
		var rect: Rect2 = VEHICLES[car[1]]
		var length: float = CAR_HEIGHT * rect.size.x / rect.size.y
		begin("Car%d" % _next_index("Car"), ue(car[0] + length * 0.5, -110, 0))
		add_card("vehicles-profile-v2.webp", rect, Vector3(car[0] + length * 0.5, -110, 0), CAR_HEIGHT, 0.0, car[2])
		# A caixa do carro da Unreal (BuildCar): encostado no meio-fio, 1,8 m de fundo.
		add_collider(ue(car[0] + length * 0.5, -110, (CAR_HEIGHT - 10) * 0.5), Vector3(length, CAR_HEIGHT - 10, 180) * 0.01)
		end()



func _build_backdrop() -> void:
	begin("Skyline", Vector3.ZERO)
	# Duas camadas de silhuetas bem atrás dos prédios; a névoa e o tom do céu separam as camadas.
	for row in [[-5500.0, 1700.0, 0.0, 0, 0.6], [-3400.0, 1150.0, 900.0, 1, 0.4]]:
		var copy_width: float = row[1] * 569.0 / 336.0
		var copy := -2
		while copy * copy_width < STREET_MAX_X + 3000.0:
			var index: int = ((copy + row[3]) % 3 + 3) % 3
			var texture := art(SKYLINES[index])
			var quad := QuadMesh.new()
			quad.size = Vector2(row[1] * texture.get_width() / texture.get_height(), row[1]) * 0.01
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/skyline_card.gdshader")
			material.set_shader_parameter("albedo", texture)
			material.set_shader_parameter("haze", row[4])
			material.set_shader_parameter("mirror", copy % 2 != 0)
			var card := MeshInstance3D.new()
			card.add_to_group(SKYLINE_GROUP, true)
			card.mesh = quad
			card.material_override = material
			card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			card.position = ue(row[2] + copy * copy_width, row[0], row[1] * 0.5)
			card.name = "Silhouette"
			_target.add_child(card, true)
			copy += 1
	end()



func _add_shaft(top: Vector3, width: float, length: float) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(width, length) * 0.01
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/light_shaft.gdshader")
	var shaft := MeshInstance3D.new()
	shaft.mesh = quad
	shaft.material_override = material
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft.position = ue(top.x, top.y, top.z - length * 0.4)
	shaft.rotation_degrees = Vector3(0, 0, -24)
	shaft.add_to_group(SHAFT_GROUP, true)
	shaft.name = "SunShaft"
	_target.add_child(shaft, true)
