## Rua das Vitrines montada em código, como AAHShopfrontStreetBlockout (Source/AfterHumans/Exploration): mesmas medidas,
## mesma arte pintada. Por cima, a atmosfera do Emberfall: câmera teleobjetiva, sol baixo, luzes quentes, névoa,
## partículas e o pós-processamento de shaders/post_emberfall.gdshader. Chuva com chão molhado (a fogueira apaga) e
## colisão: o líder anda na rua e nos becos e esbarra nos prédios, carros e props; a equipe segue o caminho dele.
##
## As medidas abaixo estão em centímetros e nos eixos da Unreal (X direita, Y profundidade com a câmera em +Y, Z cima);
## ue() converte para metros nos eixos da Godot (X direita, Y cima, Z para a câmera).
extends Node3D

const ART := "res://art/street/"

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
const FIRE := Vector3(180, 40, 0)

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
# O corredor de 10 trechos começa em X 0 e tem 78 m (AHStreetCorridor).
const CORRIDOR_LENGTH := 78.0
const WEATHER_NAMES := {"clear": "céu limpo", "sunset": "fim de tarde", "rain": "chuva", "storm": "tempestade", "mist": "névoa",
	"fog": "neblina", "night": "noite", "nightRain": "noite de chuva"}
const PARTY_SPACING := 1.15
## Cada herói da fila fica um pouco atrás do anterior, para o da frente ser desenhado por cima.
const PARTY_DEPTH_STEP := 0.02
## Dentro das lojas, o centro da câmera fica a esta distância das paredes do lado (m).
const INDOOR_CAMERA_MARGIN := 3.0
const LEADER_RADIUS := 0.28
## Na luta, os pés ficam esta fração da meia tela abaixo do centro (~y 760 de 1080), acima do painel do HUD.
const COMBAT_FEET_LINE := 0.4
# Onde o líder pode ir (metros): da rua até o fundo dos becos.
const STREET_WALK_MIN := Vector3(-2.0, 0.0, -14.4)
const STREET_WALK_MAX := Vector3(79.0, 0.0, 2.4)

# Hora do dia: "golden" (fim de tarde, o do Emberfall) e "night". RAIN muda por cima de qualquer uma.
const MOODS := {
	"golden": {
		"sun_color": Color(1.0, 0.74, 0.5), "sun_energy": 2.0, "sun_angle": Vector3(-16, -50, 0),
		"sky_top": Color(0.24, 0.36, 0.58), "sky_horizon": Color(0.86, 0.66, 0.52), "ground": Color(0.16, 0.14, 0.13),
		"ambient": 0.45, "fog": Color(0.62, 0.56, 0.52), "fog_density": 0.0028, "haze": Color(0.56, 0.52, 0.52),
		"lamp_energy": 1.6, "exposure": 0.95, "volumetric": 0.006,
	},
	"night": {
		"sun_color": Color(0.55, 0.66, 1.0), "sun_energy": 0.4, "sun_angle": Vector3(-38, 30, 0),
		"sky_top": Color(0.02, 0.03, 0.07), "sky_horizon": Color(0.10, 0.12, 0.20), "ground": Color(0.02, 0.02, 0.03),
		"ambient": 0.34, "fog": Color(0.10, 0.12, 0.18), "fog_density": 0.007, "haze": Color(0.07, 0.09, 0.14),
		"lamp_energy": 4.2, "exposure": 1.25, "volumetric": 0.02,
	},
}
const RAIN := {
	"golden": {
		"sun_color": Color(0.82, 0.84, 0.9), "sun_energy": 1.0, "sky_top": Color(0.34, 0.37, 0.42),
		"sky_horizon": Color(0.56, 0.56, 0.58), "ambient": 0.75, "fog": Color(0.5, 0.53, 0.58), "fog_density": 0.0065,
		"haze": Color(0.38, 0.41, 0.46), "lamp_energy": 2.4, "volumetric": 0.02,
	},
	"night": {
		"ambient": 0.48, "fog": Color(0.08, 0.1, 0.14), "fog_density": 0.01, "lamp_energy": 5.0, "volumetric": 0.03,
	},
}

var _forward_plus := false
var _key_light: OmniLight3D
## Passos (#62): um a cada passada de ~75 cm, só fora da luta.
var _step_distance := 0.37
var _materials := {}
var _textures := {}
var _skyline_materials: Array[ShaderMaterial] = []
var _lamp_lights: Array[OmniLight3D] = []
var _shafts: Array[MeshInstance3D] = []
var _debug_colliders: Array[MeshInstance3D] = []
var _debug_material: StandardMaterial3D
var _sun: DirectionalLight3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _camera: Camera3D
var _post: ShaderMaterial
var _hud_stats: Label
var _hud_weather: Label
var _dust: CPUParticles3D

var _leader: CharacterBody3D
## Heróis da equipe (a equipe viva da expedição) e as placas deles, na mesma ordem.
var party_ids: Array = []
var _heroes: Array[AHSpriteCard] = []
var _combat_art := {}
var _arena: AHCombatArena
var corridor: AHStreetCorridor
var exploration_hud: AHExplorationHud
## Onde o líder pode andar (o corredor fecha o trecho por vencer; dentro de uma casa, a sala).
var walk_min := STREET_WALK_MIN
var walk_max := STREET_WALK_MAX
var _indoor := false
## Cenário da jornada (#86): o mapa da Unreal no lugar da rua (nulo na Rua das Vitrines). A zona atual dá o piso, a faixa
## e o enquadramento; nas cobertas não chove.
var scenario: AHScenarioWorld
var floor_y := 0.0
var lane_z := 0.45
var sheltered := false
var _zone := {}
var _room_x := 0.0
var _room_width := 0.0
var _fog_boost := 1.0
var _storm := false
var _street_hud: CanvasLayer
## A arena aponta a câmera para o meio do lance (null: o meio da arena).
## Caminho do líder, do mais novo para o mais velho; os outros heróis ficam a PARTY_SPACING um do outro nele.
var _trail: Array[Vector3] = []

var _rain: GPUParticles3D
var _splashes: GPUParticles3D
var _raining := false
var _wet := 0.0
var _flash := 0.0
var _next_flash := 6.0

var _fire_material: ShaderMaterial
var _fire_glow: MeshInstance3D
var _fire_light: OmniLight3D
var _embers: CPUParticles3D
var _smoke: CPUParticles3D
var _fire_burn := 1.0
var _smoke_left := 0.0

var _mood := "golden"
var _time := 0.0
var _frame_ms: Array[float] = []
var _stats_timer := 0.0
var _capture_dir := ""
var _capture_step := 0
var _capture_frames := 0
var _capture_time := 0.0
var _capture_input := Vector2.ZERO
var _combat_phase := 0
var _combat_time := 0.0


static func ue(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, z, y) * 0.01


func _ready() -> void:
	_forward_plus = RenderingServer.get_current_rendering_method() == "forward_plus"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_capture_dir = arg.trim_prefix("--capture=")
			# Sem vsync, para medir o custo real do quadro.
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			# Campanha própria da captura, numa pasta própria: o save do jogador fica intacto.
			Campaign.save_dir = _capture_dir.path_join("save")
			Campaign.state = Campaign.create_initial(7)
			AHJourneyRules.start_expedition(Campaign.state, "fase_1", 20261021)
	_debug_material = StandardMaterial3D.new()
	_debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_debug_material.albedo_color = Color(1.0, 0.15, 0.1, 0.35)
	_debug_material.no_depth_test = true
	_build_environment()
	var map := _journey_map()
	if map != "" and AHScenarioWorld.exists(map):
		scenario = AHScenarioWorld.new()
		add_child(scenario)
		scenario.build(map)
	else:
		_build_street()
		_build_buildings()
		_build_props()
		_build_backdrop()
	_build_atmosphere()
	_build_rain()
	_build_party()
	if scenario and ["FloodedDepot", "SewerDucts"].has(scenario.map_name):
		# Lanterna de mão no Depósito e nos Dutos (a da Unreal: 160 lm, 10 m, presa ao líder, um pouco à frente).
		var lantern := OmniLight3D.new()
		lantern.position = Vector3(0, 0.8, 0.5)
		lantern.light_energy = 160.0 / AHScenarioWorld.LUMENS_PER_ENERGY * 3.0
		lantern.omni_range = 10.0
		lantern.light_color = Color(1.0, 0.8, 0.55)
		_leader.add_child(lantern)
	# Luz de leitura: acompanha a equipe (e a luta), do lado da câmera, de noite e na chuva.
	_key_light = OmniLight3D.new()
	_key_light.omni_range = 9.0
	_key_light.light_color = Color(1.0, 0.88, 0.72)
	_key_light.light_energy = 0.0
	_key_light.shadow_enabled = false
	add_child(_key_light)
	_build_camera()
	_build_post_and_hud()
	_arena = AHCombatArena.new()
	add_child(_arena)
	_arena.setup(self)
	_apply_graphics()
	Settings.changed.connect(func():
		_apply_graphics()
		_apply_weather())
	_apply_weather()
	exploration_hud = AHExplorationHud.new()
	_street_hud.add_child(exploration_hud)
	if scenario:
		exploration_hud.place = scenario.display_name
	corridor = AHStreetCorridor.new()
	add_child(corridor)
	corridor.setup(self, exploration_hud)


## Opção da campanha: sem relâmpagos nem poeira no ar.
func _reduced_effects() -> bool:
	return bool(Campaign.state.get("settings", {}).get("reduced_environment_effects", false))


## A qualidade gráfica das opções (Settings): oclusão, neblina volumétrica, sombra do sol e densidade da chuva.
func _apply_graphics() -> void:
	var fx := Settings.effects()
	_env.ssao_enabled = _forward_plus and fx.ssao
	_env.volumetric_fog_enabled = _forward_plus and fx.volumetric_fog
	_env.ssr_enabled = _forward_plus and _raining and fx.ssr
	_sun.shadow_enabled = fx.shadows
	_rain.amount_ratio = fx.rain_scale
	_splashes.amount_ratio = fx.rain_scale


## O mapa do trecho atual da expedição ("" = a rua): o de passagem nos primeiros trechos, depois o da fase.
func _journey_map() -> String:
	if _capture_dir != "":
		return ""
	var expedition = Campaign.state.get("session", {}).get("expedition")
	if expedition == null:
		return ""
	return AHJourneyRules.map_for_step(expedition.phase_id, int(expedition.corridor.index))


## Entra numa zona do cenário: o piso, a faixa (até 1,2 m para cada lado do meio, como a LaneDepth da Unreal), a
## câmera e se é coberta (sem chuva). As cobertas: Abrigo, Dutos e Depósito inteiros, e as zonas depois da primeira.
func set_scenario_zone(index: int) -> void:
	_zone = scenario.zones[index]
	floor_y = _zone.y
	lane_z = (_zone.z0 + _zone.z1) * 0.5
	var half_depth: float = minf(1.2, (_zone.z1 - _zone.z0 - 1.0) * 0.5)
	walk_min = Vector3(_zone.x0 + 0.4, floor_y, lane_z - half_depth)
	walk_max = Vector3(_zone.x1 - 0.4, floor_y, lane_z + half_depth)
	sheltered = index > 0 or ["SewerDucts", "SealedShelter", "FloodedDepot"].has(scenario.map_name)
	_apply_weather()


# ---------------------------------------------------------------- arte e materiais

func _texture(file: String) -> Texture2D:
	if not _textures.has(file):
		_textures[file] = load(ART + file)
	return _textures[file]


## Material de placa pintada: recorte do atlas por UV, espelho invertendo o U, recorte pelo alfa.
func _card_material(file: String, rect: Rect2, mirror: bool, alpha: bool) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [file, rect, mirror]
	if _materials.has(key):
		return _materials[key]
	var texture := _texture(file)
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
func _add_card(file: String, rect: Rect2, bottom: Vector3, height: float, yaw: float = 0.0, mirror: bool = false,
		shadow: bool = true, alpha: bool = true, solid: bool = false, depth: float = 50.0) -> MeshInstance3D:
	var texture := _texture(file)
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
	add_child(card)
	if solid:
		_add_collider(ue(bottom.x, bottom.y, bottom.z + height * 0.5), Vector3(width * 0.8, height, depth) * 0.01)
	return card


## Colisão estática (metros, eixos da Godot), com uma caixa vermelha que a tecla C mostra.
func _add_collider(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var debug := MeshInstance3D.new()
	var debug_box := BoxMesh.new()
	debug_box.size = size
	debug.mesh = debug_box
	debug.material_override = _debug_material
	debug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	debug.visible = false
	body.add_child(debug)
	_debug_colliders.append(debug)
	add_child(body)


func _piece_material(piece: String) -> StandardMaterial3D:
	var key := "piece|" + piece
	if _materials.has(key):
		return _materials[key]
	var spec: Dictionary = PIECES[piece]
	var material := StandardMaterial3D.new()
	material.albedo_color = spec.color
	material.roughness = spec.roughness
	material.albedo_texture = _texture(spec.texture)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / (spec.tile * 0.01)
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
		_materials["puddles|" + piece] = puddles
	_materials[key] = material
	return material


## Caixa entre dois cantos (AddBox). Paredes e prédios também colidem; o chão não.
func _add_box(piece: String, min_corner: Vector3, max_corner: Vector3) -> void:
	var a := ue(min_corner.x, min_corner.y, min_corner.z)
	var b := ue(max_corner.x, max_corner.y, max_corner.z)
	var box := BoxMesh.new()
	box.size = (b - a).abs()
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = _piece_material(piece)
	mesh.position = (a + b) * 0.5
	add_child(mesh)
	if not FLOOR_PIECES.has(piece):
		_add_collider(mesh.position, box.size)


func _add_glow(center: Vector3, size: float, color: Color, energy: float) -> MeshInstance3D:
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
	add_child(glow)
	return glow


func _add_light(at: Vector3, energy: float, light_range: float, shadow: bool) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = ue(at.x, at.y, at.z)
	light.light_color = Color8(255, 205, 160)
	light.light_energy = energy
	light.omni_range = light_range * 0.01
	light.omni_attenuation = 1.4
	light.shadow_enabled = shadow
	light.light_volumetric_fog_energy = 2.5
	light.light_specular = 0.35
	add_child(light)
	return light


# ---------------------------------------------------------------- montagem (Rebuild)

func _build_street() -> void:
	_add_box("asphalt", Vector3(STREET_MIN_X, SIDEWALK_FRONT_Y, -20), Vector3(STREET_MAX_X, 900, 0))
	_add_box("sidewalk", Vector3(STREET_MIN_X, FACADE_BACK_Y, -20), Vector3(STREET_MAX_X, SIDEWALK_FRONT_Y, SIDEWALK_TOP_Z))
	# Postes pintados com a luz sob a cúpula e um halo na lâmpada. O mastro fica a ~1/4 da largura à direita do centro.
	for lamp_x in LAMP_XS:
		_add_card("lamp.png", Rect2(), Vector3(lamp_x, LAMP_Y, SIDEWALK_TOP_Z), LAMP_HEIGHT, 0.0, false, false)
		_add_collider(ue(lamp_x + 52, LAMP_Y, LAMP_HEIGHT * 0.5), Vector3(0.24, LAMP_HEIGHT * 0.01, 0.24))
		_add_glow(Vector3(lamp_x - 53, LAMP_Y + 6, 385), 70.0, Color(1.0, 0.72, 0.4), 3.0)
		_lamp_lights.append(_add_light(Vector3(lamp_x - 53, LAMP_Y + 30, 370), 1.6, 750.0, true))
	for at in DOOR_LIGHTS:
		_lamp_lights.append(_add_light(at, 0.6, 550.0, false))


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
	var x1 := x0 + FACADE_WIDTH
	var mid := (x0 + x1) * 0.5
	var top := FACADE_HEIGHT + SIDEWALK_TOP_Z + 5
	_add_box("concrete", Vector3(x0, BUILDING_BACK_Y, 0), Vector3(x1, FACADE_FRONT_Y, top))
	_add_box("concrete", Vector3(x0 - 10, BUILDING_BACK_Y - 10, top), Vector3(x1 + 10, FACADE_FRONT_Y + 10, top + 25))
	_add_card(FACADES[facade], Rect2(), Vector3(mid, FACADE_FRONT_Y + 1, SIDEWALK_TOP_Z), FACADE_HEIGHT, 0.0, mirror, false, false)
	# Laterais longas encadeadas até o fundo, alternando a variante e o espelho.
	for side in 2:
		var side_x := x0 - 1 if side == 0 else x1 + 1
		var start_y := FACADE_FRONT_Y
		var slot := 0
		while start_y > BUILDING_BACK_Y + 1:
			var wall: String = LONG_SIDE_WALLS[(facade + side + slot) % LONG_SIDE_WALLS.size()]
			var long_mirror := (side == 0) != (slot % 2 == 1)
			_add_card(wall, Rect2(), Vector3(side_x, start_y - FACADE_HEIGHT * 0.5, SIDEWALK_TOP_Z), FACADE_HEIGHT, 90.0, long_mirror, false, false)
			start_y -= FACADE_HEIGHT
			slot += 1


func _build_brick_block(x0: float, x1: float) -> void:
	_add_box("brick", Vector3(x0, BUILDING_BACK_Y, 0), Vector3(x1, FACADE_FRONT_Y, 760))
	_add_box("concrete", Vector3(x0, BUILDING_BACK_Y, 760), Vector3(x1, FACADE_FRONT_Y + 10, 790))


func _build_alley(x0: float, x1: float, variant: int) -> void:
	_add_box("sidewalk", Vector3(x0, ALLEY_BACK_Y, -20), Vector3(x1, FACADE_BACK_Y, SIDEWALK_TOP_Z))
	_add_box("brick", Vector3(x0 - 20, ALLEY_BACK_Y - 30, 0), Vector3(x1 + 20, ALLEY_BACK_Y, 650))
	var mid := (x0 + x1) * 0.5
	var atlas := "alley-props-v1.webp"
	match variant % 3:
		0:
			_add_card(atlas, ALLEY.dumpster, Vector3(mid - 30, -1050, SIDEWALK_TOP_Z), 130, 0.0, false, true, true, true, 90.0)
			_add_card(atlas, ALLEY.bag, Vector3(mid + 85, -880, SIDEWALK_TOP_Z), 60, 0.0, false, true, true, true)
		1:
			_add_card(atlas, ALLEY.crate, Vector3(mid - 60, -980, SIDEWALK_TOP_Z), 110, 0.0, false, true, true, true, 70.0)
			_add_card(atlas, ALLEY.barrel, Vector3(mid + 70, -820, SIDEWALK_TOP_Z), 95, 0.0, false, true, true, true)
			_add_card(atlas, ALLEY.pallet, Vector3(mid + 40, -1300, SIDEWALK_TOP_Z), 100, 0.0, true, true, true, true)
		_:
			_add_card(atlas, ALLEY.bin, Vector3(mid - 70, -900, SIDEWALK_TOP_Z), 95, 0.0, false, true, true, true)
			_add_card(atlas, ALLEY.bin, Vector3(mid + 10, -960, SIDEWALK_TOP_Z), 95, 0.0, true, true, true, true)
			_add_card(atlas, ALLEY.rubble, Vector3(mid + 70, -760, SIDEWALK_TOP_Z), 45, 0.0, false, true, true, true)
	# Feixe de sol entrando pelo beco (a névoa volumétrica faz isso no Forward+; aqui vale para os dois).
	_add_shaft(Vector3(mid - 40, -900, 380), 260.0, 620.0)


## Portas das fachadas dentro do corredor: X (m), loja, espelho e o trecho onde fica (as de fora ficam fechadas).
func door_list() -> Array:
	var doors: Array = []
	if scenario:
		return doors
	for building in FACADE_BUILDINGS:
		var overlay: Rect2 = DOOR_OVERLAYS[building[1]]
		var offset: float = (overlay.position.x + overlay.size.x * 0.5 - 768.0) * FACADE_WIDTH / 1536.0
		var x: float = (building[0] + FACADE_WIDTH * 0.5 + (-offset if building[2] else offset)) * 0.01
		if x >= 0.0 and x < CORRIDOR_LENGTH:
			doors.append({"x": x, "shop": building[1], "mirror": building[2], "step": floori(x / (CORRIDOR_LENGTH / 10.0))})
	return doors


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
			_add_card(prop[0], rect, Vector3(prop[2], prop[3], SIDEWALK_TOP_Z), prop[4], 0.0, prop[5], true, true, true)
	for car in CARS:
		var rect: Rect2 = VEHICLES[car[1]]
		var length: float = CAR_HEIGHT * rect.size.x / rect.size.y
		_add_card("vehicles-profile-v2.webp", rect, Vector3(car[0] + length * 0.5, -110, 0), CAR_HEIGHT, 0.0, car[2])
		# A caixa do carro da Unreal (BuildCar): encostado no meio-fio, 1,8 m de fundo.
		_add_collider(ue(car[0] + length * 0.5, -110, (CAR_HEIGHT - 10) * 0.5), Vector3(length, CAR_HEIGHT - 10, 180) * 0.01)


func _build_backdrop() -> void:
	# Duas camadas de silhuetas bem atrás dos prédios; a névoa e o tom do céu separam as camadas.
	for row in [[-5500.0, 1700.0, 0.0, 0, 0.6], [-3400.0, 1150.0, 900.0, 1, 0.4]]:
		var copy_width: float = row[1] * 569.0 / 336.0
		var copy := -2
		while copy * copy_width < STREET_MAX_X + 3000.0:
			var index: int = ((copy + row[3]) % 3 + 3) % 3
			var texture := _texture(SKYLINES[index])
			var quad := QuadMesh.new()
			quad.size = Vector2(row[1] * texture.get_width() / texture.get_height(), row[1]) * 0.01
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/skyline_card.gdshader")
			material.set_shader_parameter("albedo", texture)
			material.set_shader_parameter("haze", row[4])
			material.set_shader_parameter("mirror", copy % 2 != 0)
			_skyline_materials.append(material)
			var card := MeshInstance3D.new()
			card.mesh = quad
			card.material_override = material
			card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			card.position = ue(row[2] + copy * copy_width, row[0], row[1] * 0.5)
			add_child(card)
			copy += 1


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
	add_child(shaft)
	_shafts.append(shaft)


# ---------------------------------------------------------------- luz, céu e partículas

func _build_environment() -> void:
	_sky = ProceduralSkyMaterial.new()
	_sky.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = _sky
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_white = 5.0
	_env.glow_enabled = true
	_env.glow_strength = 1.0
	_env.glow_bloom = 0.04
	_env.glow_hdr_threshold = 0.95
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	_env.set_glow_level(2, 1.0)
	_env.set_glow_level(4, 0.8)
	_env.set_glow_level(5, 0.6)
	_env.fog_enabled = true
	_env.fog_sky_affect = 0.35
	_env.adjustment_enabled = true
	_env.adjustment_contrast = 1.08
	_env.adjustment_saturation = 1.05
	if _forward_plus:
		_env.ssao_enabled = true
		_env.ssao_radius = 1.2
		_env.ssao_intensity = 1.6
		_env.volumetric_fog_enabled = true
		_env.volumetric_fog_length = 48.0
		_env.volumetric_fog_anisotropy = 0.55
		_env.ssr_max_steps = 48
		_env.ssr_fade_out = 1.5
	var world := WorldEnvironment.new()
	world.environment = _env
	add_child(world)

	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.5
	_sun.directional_shadow_max_distance = 60.0
	_sun.light_volumetric_fog_energy = 1.2
	add_child(_sun)


func _build_atmosphere() -> void:
	# Poeira no ar, presa à câmera (como o pó do Emberfall).
	_dust = CPUParticles3D.new()
	_dust.amount = 220
	_dust.lifetime = 9.0
	_dust.preprocess = 9.0
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(16, 4, 5)
	_dust.direction = Vector3(1, 0.2, 0)
	_dust.spread = 180.0
	_dust.gravity = Vector3(0.05, 0.02, 0)
	_dust.initial_velocity_min = 0.03
	_dust.initial_velocity_max = 0.18
	_dust.scale_amount_min = 0.5
	_dust.scale_amount_max = 1.4
	_dust.mesh = _mote_mesh(0.045, Color(1.0, 0.82, 0.6), 1.6)
	_dust.local_coords = false
	add_child(_dust)

	# Fogueira na rua, com brasas, luz que tremula e fumaça quando a chuva apaga.
	var fire_start := get_child_count()
	var texture := _texture("campfire-v1.png")
	var quad := QuadMesh.new()
	quad.size = Vector2(0.95, 0.95)
	_fire_material = ShaderMaterial.new()
	_fire_material.shader = preload("res://shaders/campfire.gdshader")
	_fire_material.set_shader_parameter("albedo_tex", texture)
	var fire := MeshInstance3D.new()
	fire.mesh = quad
	fire.material_override = _fire_material
	fire.position = ue(FIRE.x, FIRE.y, FIRE.z + 47.5)
	add_child(fire)
	_add_collider(ue(FIRE.x, FIRE.y, 30), Vector3(0.8, 0.6, 0.55))
	_fire_glow = _add_glow(FIRE + Vector3(0, 10, 35), 120.0, Color(1.0, 0.5, 0.18), 2.2)
	_fire_light = _add_light(FIRE + Vector3(0, 40, 70), 2.2, 650.0, true)
	_fire_light.light_color = Color(1.0, 0.6, 0.3)

	_embers = CPUParticles3D.new()
	_embers.amount = 40
	_embers.lifetime = 2.6
	_embers.position = ue(FIRE.x, FIRE.y + 10, FIRE.z + 30)
	_embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_embers.emission_sphere_radius = 0.18
	_embers.direction = Vector3(0, 1, 0)
	_embers.spread = 25.0
	_embers.gravity = Vector3(0.1, 0.35, 0)
	_embers.initial_velocity_min = 0.3
	_embers.initial_velocity_max = 0.9
	_embers.mesh = _mote_mesh(0.035, Color(1.0, 0.55, 0.2), 4.0)
	_embers.color_ramp = _fade_ramp(Color(1, 1, 1, 1))
	add_child(_embers)

	_smoke = CPUParticles3D.new()
	_smoke.amount = 36
	_smoke.lifetime = 4.5
	_smoke.emitting = false
	_smoke.position = ue(FIRE.x, FIRE.y + 10, FIRE.z + 35)
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = 0.15
	_smoke.direction = Vector3(0.15, 1, 0)
	_smoke.spread = 12.0
	_smoke.gravity = Vector3(0.12, 0.25, 0)
	_smoke.initial_velocity_min = 0.25
	_smoke.initial_velocity_max = 0.45
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 2.6))
	_smoke.scale_amount_curve = grow
	_smoke.color_ramp = _fade_ramp(Color(1, 1, 1, 0.9))
	_smoke.mesh = _soft_mesh(Vector2(0.5, 0.5), Color(0.62, 0.62, 0.65), 0.6, false)
	add_child(_smoke)
	# Nos cenários a fogueira é só da rua: fica escondida e sem colisão.
	if scenario:
		for i in range(fire_start, get_child_count()):
			var node := get_child(i)
			if node is StaticBody3D:
				for debug in node.get_children():
					if debug is MeshInstance3D:
						_debug_colliders.erase(debug)
				node.queue_free()
			elif node is Node3D:
				node.visible = false


func _mote_mesh(size: float, color: Color, energy: float) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/glow_sprite.gdshader")
	material.set_shader_parameter("color", color)
	material.set_shader_parameter("energy", energy)
	quad.material = material
	return quad


func _soft_mesh(size: Vector2, color: Color, opacity: float, streak: bool) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = size
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/soft_particle.gdshader")
	material.set_shader_parameter("color", color)
	material.set_shader_parameter("opacity", opacity)
	material.set_shader_parameter("streak", streak)
	quad.material = material
	return quad


func _fade_ramp(start: Color) -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, start)
	ramp.set_color(1, Color(start.r, start.g, start.b, 0))
	return ramp


func _build_rain() -> void:
	# Gotas: traços finos caindo um pouco de lado, numa caixa que acompanha a câmera.
	var fall := ParticleProcessMaterial.new()
	fall.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	fall.emission_box_extents = Vector3(16, 0.5, 8)
	fall.direction = Vector3(0.12, -1, 0)
	fall.spread = 2.0
	fall.initial_velocity_min = 13.0
	fall.initial_velocity_max = 16.0
	fall.gravity = Vector3(0, -4, 0)
	_rain = GPUParticles3D.new()
	_rain.amount = 4500 if _forward_plus else 3000
	_rain.lifetime = 0.8
	_rain.emitting = false
	_rain.local_coords = false
	_rain.visibility_aabb = AABB(Vector3(-20, -14, -10), Vector3(40, 16, 20))
	_rain.process_material = fall
	_rain.draw_pass_1 = _soft_mesh(Vector2(0.014, 0.55), Color(0.78, 0.84, 0.94), 0.32 if _forward_plus else 0.5, true)
	add_child(_rain)

	# Respingos no chão: discos que crescem e somem.
	var splash := ParticleProcessMaterial.new()
	splash.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	splash.emission_box_extents = Vector3(16, 0.0, 3.6)
	splash.direction = Vector3(0, 1, 0)
	splash.spread = 60.0
	splash.initial_velocity_min = 0.2
	splash.initial_velocity_max = 0.6
	splash.gravity = Vector3(0, -3, 0)
	var grow := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.0))
	grow.curve = curve
	splash.scale_curve = grow
	var fade := GradientTexture1D.new()
	fade.gradient = _fade_ramp(Color(1, 1, 1, 1))
	splash.color_ramp = fade
	_splashes = GPUParticles3D.new()
	_splashes.amount = 900 if _forward_plus else 600
	_splashes.lifetime = 0.3
	_splashes.emitting = false
	_splashes.local_coords = false
	_splashes.visibility_aabb = AABB(Vector3(-20, -1, -6), Vector3(40, 3, 12))
	_splashes.process_material = splash
	_splashes.draw_pass_1 = _soft_mesh(Vector2(0.09, 0.05), Color(0.85, 0.9, 0.97), 0.5, false)
	add_child(_splashes)


# ---------------------------------------------------------------- equipe e câmera

func _build_party() -> void:
	# Líder com colisão (cápsula de 0,2 a 1,4 m do chão: passa pelo meio-fio, esbarra nos props baixos).
	_leader = CharacterBody3D.new()
	_leader.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = LEADER_RADIUS
	capsule.height = 1.2
	shape.shape = capsule
	shape.position.y = 0.8
	_leader.add_child(shape)
	add_child(_leader)

	_combat_art = JSON.parse_string(FileAccess.get_file_as_string(AHCombatArena.ART_MANIFEST))
	# A equipe é a da expedição (ou a formação da campanha antes dela), só com quem está vivo.
	var expedition = Campaign.state.get("session", {}).get("expedition")
	for hero_id in (expedition.team if expedition != null else Campaign.state.get("preferred_formation", [])):
		var hero = Campaign.hero(hero_id)
		if hero == null or not hero.get("alive", true) or not _combat_art.heroes.has(hero_id) or party_ids.size() >= 4:
			continue
		var card := AHSpriteCard.new()
		card.body_height = AHCharacterHeights.find(hero_id)
		card.show_art(_combat_art.heroes[hero_id].idle)
		add_child(card)
		party_ids.append(hero_id)
		_heroes.append(card)
	_place_leader(Vector3(7.6, 0, 0.45))


## Põe o líder num ponto e a equipe enfileirada atrás dele (início e capturas).
func _place_leader(at: Vector3, facing: float = 1.0) -> void:
	at = _free_spot(at)
	_leader.position = at
	_trail.clear()
	for step in 80:
		_trail.append(at - Vector3(facing * 0.06 * step, 0, 0))
	for index in _heroes.size():
		_set_facing(index, facing)
	_place_party(0.0)
	# Um teleporte (casa, recomeço, captura): a câmera vai junto, sem atravessar a cidade.
	if _camera != null:
		_update_camera(0.0)


## O ponto livre mais perto: um líder posto dentro de uma caixa de colisão (a fogueira na chegada) fica preso, porque a
## cápsula não sai dela. Tenta a frente e o fundo, depois os lados, sem sair da área de andar.
func _free_spot(at: Vector3) -> Vector3:
	for offset in [Vector2.ZERO, Vector2(0, 0.4), Vector2(0, 0.8), Vector2(0, -0.4), Vector2(0, -0.8),
			Vector2(0.6, 0), Vector2(-0.6, 0), Vector2(1.2, 0), Vector2(-1.2, 0), Vector2(0.6, 1.2), Vector2(-0.6, 1.2)]:
		var spot := (at + Vector3(offset.x, 0, offset.y)).clamp(walk_min, walk_max)
		if not _blocked(spot):
			return spot
	return at


func _blocked(spot: Vector3) -> bool:
	var reach := LEADER_RADIUS + 0.05
	for debug in _debug_colliders:
		var center: Vector3 = (debug.get_parent() as Node3D).global_position
		var half: Vector3 = (debug.mesh as BoxMesh).size * 0.5
		# Caixas abaixo da cápsula (meio-fio) não seguram ninguém.
		if center.y + half.y < 0.2:
			continue
		var nearest := Vector2(clampf(spot.x, center.x - half.x, center.x + half.x), clampf(spot.z, center.z - half.z, center.z + half.z))
		if nearest.distance_to(Vector2(spot.x, spot.z)) < reach:
			return true
	return false


func _set_facing(index: int, facing: float) -> void:
	_heroes[index].set_facing(facing)


## Ponto do caminho do líder a uma distância dele.
func _trail_point(distance: float) -> Vector3:
	var walked := 0.0
	for i in range(1, _trail.size()):
		var step := _trail[i - 1].distance_to(_trail[i])
		if walked + step >= distance:
			return _trail[i - 1].lerp(_trail[i], (distance - walked) / maxf(step, 0.0001))
		walked += step
	return _trail[-1]


func _ground_height(z: float) -> float:
	if scenario:
		return floor_y
	return SIDEWALK_TOP_Z * 0.01 if z < SIDEWALK_FRONT_Y * 0.01 else 0.0


func _place_party(delta: float) -> void:
	if _arena != null and _arena.active:
		return
	for index in _heroes.size():
		var card := _heroes[index]
		var target := _leader.position if index == 0 else _trail_point(PARTY_SPACING * index)
		# A posição suavizada não inclui o recuo de desenho (0,02 por herói): somado de novo a cada quadro, ele
		# acumulava até ~0,25 m por herói a 120 fps e levava os últimos para dentro da parede do fundo das lojas.
		var previous := card.position + Vector3(0, 0, PARTY_DEPTH_STEP * index)
		var x := target.x if delta == 0.0 or index == 0 else lerpf(previous.x, target.x, 1.0 - exp(-10.0 * delta))
		var z := target.z if delta == 0.0 or index == 0 else lerpf(previous.z, target.z, 1.0 - exp(-10.0 * delta))
		if delta > 0.0 and absf(x - previous.x) > 0.004:
			_set_facing(index, signf(x - previous.x))
		# Respiração leve: só a escala vertical, com a base no chão.
		var breath := 1.0 + 0.012 * sin(_time * 2.2 + index * 1.7)
		card.scale = Vector3(1, breath, 1)
		card.position = Vector3(x, _ground_height(z), z - PARTY_DEPTH_STEP * index)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 26.0
	_camera.far = 250.0
	add_child(_camera)
	_update_camera(0.0)


func _update_camera(delta: float) -> void:
	# Teleobjetiva a ~18 m, olhando um pouco de cima (o enquadramento do Emberfall); avança um pouco nos becos.
	var leader := _leader.position
	var target := Vector3(clampf(leader.x, -6.0, 76.0), 2.5, clampf(-1.4 + minf(leader.z + 1.0, 0.0) * 0.45, -6.5, -1.4))
	var pitch := deg_to_rad(12.0)
	var distance := 18.5
	if scenario and not _zone.is_empty():
		# A câmera da prévia da Unreal: 19 m de distância, 1,7 m acima do piso, quase reta (0,5°), 30° na horizontal; a
		# Ponte usa a da rua (28 m, 2,7 m). O centro vai até 4 m das pontas da zona (LaneEdgePadding).
		var bridge: bool = scenario.map_name == "RootBridge"
		distance = 28.0 if bridge else 19.0
		pitch = deg_to_rad(0.5)
		_camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(15.0)) / get_viewport().get_visible_rect().size.aspect()))
		var half_view: float = tan(deg_to_rad(15.0)) * distance
		var low: float = _zone.x0 + minf(half_view - 4.0, (_zone.x1 - _zone.x0) * 0.5)
		var high: float = _zone.x1 - minf(half_view - 4.0, (_zone.x1 - _zone.x0) * 0.5)
		target = Vector3(clampf(leader.x, low, maxf(low, high)), floor_y + (2.7 if bridge else 1.7), lane_z)
	if _indoor:
		# Dentro da loja, a câmera desce para ficar abaixo do forro e enquadra a sala.
		# Vai até perto das paredes do lado (elas tapam o que fica fora da sala): na frente da sala a câmera vê só ~3,5 m
		# para cada lado, e com a folga maior a equipe saía do quadro nas pontas.
		target = Vector3(clampf(leader.x, _room_x + INDOOR_CAMERA_MARGIN, _room_x + _room_width - INDOOR_CAMERA_MARGIN), 1.6, -1.2)
		pitch = deg_to_rad(4.0)
		distance = 11.0
	if _arena != null and _arena.active:
		# Na luta, a arena enquadra todos e se aproxima do golpe. A altura do alvo põe os pés sempre na mesma linha da
		# tela, acima do painel do HUD, qualquer que seja a distância.
		var view: Vector2 = _arena.camera_view()
		distance = view.y
		target = Vector3(view.x, floor_y + COMBAT_FEET_LINE * tan(deg_to_rad(_camera.fov * 0.5)) * distance / cos(pitch),
			(lane_z - 1.35) if scenario else -0.9)
	var wanted := target + Vector3(0, sin(pitch) * distance, cos(pitch) * distance)
	_camera.position = wanted if delta == 0.0 else _camera.position.lerp(wanted, 1.0 - exp(-3.0 * delta))
	_camera.look_at(Vector3(_camera.position.x, target.y, target.z))
	var ground := floor_y if scenario else 0.0
	_key_light.position = Vector3(target.x, ground + 2.6, (lane_z if scenario else 0.45) + 2.2)
	_dust.position = Vector3(_camera.position.x, ground + 2.6, -1.0 + (lane_z if scenario else 0.0))
	_rain.position = Vector3(_camera.position.x + 0.8, ground + 9.0, -1.0 + (lane_z if scenario else 0.0))
	_splashes.position = Vector3(_camera.position.x, ground + 0.03, -1.0 + (lane_z if scenario else 0.0))


func _build_post_and_hud() -> void:
	var post_layer := CanvasLayer.new()
	post_layer.layer = 1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post = ShaderMaterial.new()
	_post.shader = preload("res://shaders/post_emberfall.gdshader")
	rect.material = _post
	post_layer.add_child(rect)
	add_child(post_layer)

	var hud := CanvasLayer.new()
	hud.layer = 2
	add_child(hud)
	_street_hud = hud
	var title := "RUA DAS VITRINES\nBairro Submerso"
	if scenario:
		# O cabeçalho dos cenários: o mapa e a fase ("CAIS DO RIO · Jornada 2 · Ponte das Raízes").
		var expedition: Dictionary = Campaign.state.session.expedition
		var info := AHJourneyRules.phase(expedition.phase_id)
		title = "%s\nJornada %d · %s" % [scenario.display_name.to_upper(), AHJourneyRules.PHASES.find(info) + 1, info.get("name", "")]
	hud.add_child(_label(title, 30, Vector2(36, 28)))
	_hud_weather = _label("", 20, Vector2(36, 112))
	hud.add_child(_hud_weather)
	hud.add_child(_label("A/D andar   W/S fundo e frente   Shift correr   E interagir   Esc menu   K próxima patrulha   R chuva   T dia/noite   P pós   C colisões", 18, Vector2(36, 1030)))
	_hud_stats = _label("", 18, Vector2(1380, 30))
	hud.add_child(_hud_stats)


func _label(text: String, size: int, at: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.66))
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.03))
	label.add_theme_constant_override("outline_size", 6)
	return label


# ---------------------------------------------------------------- clima

## Junta a hora do dia com a chuva por cima.
func _weather() -> Dictionary:
	var w: Dictionary = MOODS[_mood].duplicate()
	if _raining:
		w.merge(RAIN[_mood], true)
	var site: Dictionary = AHScenarioWorld.SITES.get(scenario.map_name, {}) if scenario else {}
	if not site.is_empty():
		# AdjustForSite da Unreal.
		w.sun_energy = maxf(w.sun_energy, site.min_night_sun if _mood == "night" else site.min_sun)
		w.ambient = maxf(w.ambient, site.min_ambient)
		w.fog_density *= site.fog_scale
		w.volumetric *= site.fog_scale
		w.sun_angle = Vector3(minf(w.sun_angle.x, -site.min_elevation), w.sun_angle.y, w.sun_angle.z)
	return w


func _apply_weather() -> void:
	var w := _weather()
	_sun.light_color = w.sun_color
	_sun.rotation_degrees = w.sun_angle
	_sky.sky_top_color = w.sky_top
	_sky.sky_horizon_color = w.sky_horizon
	_sky.ground_horizon_color = w.sky_horizon.darkened(0.3)
	_sky.ground_bottom_color = w.ground
	_env.ambient_light_energy = w.ambient
	_env.fog_light_color = w.fog
	_env.fog_density = w.fog_density * _fog_boost
	# O Compatibility (web) soma a luz direta e o glow mais forte: a mesma cena, calibrada a olho contra o Forward+.
	_env.tonemap_exposure = w.exposure * (1.0 if _forward_plus else 0.9)
	_env.glow_intensity = 0.7 if _forward_plus else 0.45
	if _forward_plus:
		_env.volumetric_fog_density = w.volumetric
		_env.volumetric_fog_albedo = w.fog.lightened(0.3)
		_env.ssr_enabled = _raining and Settings.effects().ssr
	for material in _skyline_materials:
		material.set_shader_parameter("haze_color", w.haze)
	for shaft in _shafts:
		shaft.visible = _mood == "golden" and not _raining and not _indoor
	for index in _lamp_lights.size():
		# Os três primeiros são os postes; os outros, as portas.
		_lamp_lights[index].light_energy = w.lamp_energy * (1.0 if index < LAMP_XS.size() else 0.4)
	# Dentro de uma casa não chove (e a poeira dourada é da rua).
	var covered := _indoor or sheltered
	_rain.emitting = _raining and not covered
	_rain.visible = not covered
	_dust.emitting = not _raining and not covered and not _reduced_effects()
	_dust.visible = not covered
	_splashes.emitting = _raining and not covered
	_splashes.visible = not covered
	if scenario:
		# Nos cenários o céu e o sol da rua só tingem; a luz é a das luminárias do mapa (e a lanterna).
		scenario.set_weather(_wet if not covered else 0.0, Color(1, 1, 1) if _mood == "golden" else Color(0.55, 0.6, 0.75))
	# Luz de leitura: acende de noite e na chuva, sobre a equipe e a luta.
	var readable := (1.0 if _mood == "night" else 0.0) + (0.3 if _raining else 0.0)
	_key_light.light_energy = 0.7 * clampf(readable, 0.0, 1.2)
	_hud_weather.text = ("Noite" if _mood == "night" else "Fim de tarde") + (" · chuva" if _raining else "")
	_update_sun(0.0)


func _update_sun(delta: float) -> void:
	var w := _weather()
	var direct_scale := 1.0 if _forward_plus else 0.62
	# Relâmpago (só com chuva): dois clarões rápidos, azulados.
	if _raining and _capture_dir == "" and not _reduced_effects():
		_next_flash -= delta
		if _next_flash <= 0.0:
			_next_flash = randf_range(4.0, 9.0) if _storm else randf_range(9.0, 20.0)
			_flash = 1.0
	_flash = maxf(0.0, _flash - delta * 3.5)
	var flicker := _flash * (0.6 + 0.4 * sin(_flash * 40.0))
	_sun.light_energy = w.sun_energy * direct_scale + flicker * 3.0
	_sun.light_color = w.sun_color.lerp(Color(0.75, 0.82, 1.0), clampf(flicker, 0.0, 1.0))


## Chão molhado: escurece, fica liso e as poças do ruído brilham. wet vai de 0 a 1 devagar.
func _apply_wet() -> void:
	for piece in PIECES:
		var spec: Dictionary = PIECES[piece]
		if not spec.wet:
			continue
		var material := _piece_material(piece)
		material.albedo_color = spec.color.darkened(0.38 * _wet)
		material.roughness = lerpf(spec.roughness, 0.55, _wet)
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		material.metallic_specular = lerpf(0.5, 0.9, _wet)
		# Seco, sem a textura de poças (a rugosidade fica a do material).
		material.roughness_texture = _materials["puddles|" + piece] if _wet > 0.02 else null


func _update_fire(delta: float) -> void:
	if scenario:
		return
	# A chuva apaga a fogueira em poucos segundos; sobra fumaça. Quando para, as brasas reacendem devagar.
	var before := _fire_burn
	_fire_burn = clampf(_fire_burn + (-0.45 if _raining else 0.12) * delta, 0.0, 1.0)
	if before > 0.25 and _fire_burn <= 0.25:
		_smoke_left = 14.0
	_smoke_left = maxf(0.0, _smoke_left - delta)
	_smoke.emitting = _smoke_left > 0.0
	_embers.emitting = _fire_burn > 0.35
	var flicker := 0.85 + 0.15 * sin(_time * 13.0) * sin(_time * 7.3 + 1.1)
	_fire_material.set_shader_parameter("burn", _fire_burn)
	_fire_material.set_shader_parameter("flicker", flicker)
	_fire_light.light_energy = 2.2 * flicker * _fire_burn
	_fire_light.visible = _fire_burn > 0.01
	_fire_glow.visible = _fire_burn > 0.01
	(_fire_glow.material_override as ShaderMaterial).set_shader_parameter("energy", 2.2 * _fire_burn)


# ---------------------------------------------------------------- quadro a quadro

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("debug_time"):
		_mood = "night" if _mood == "golden" else "golden"
		_apply_weather()
	elif event.is_action_pressed("debug_rain"):
		_raining = not _raining
		_next_flash = 4.0
		_apply_weather()
	elif event.is_action_pressed("debug_post"):
		_post.set_shader_parameter("enabled", not _post.get_shader_parameter("enabled"))
	elif event.is_action_pressed("debug_colliders"):
		for debug in _debug_colliders:
			debug.visible = not debug.visible
	elif event.is_action_pressed("debug_combat") and not _arena.active:
		corridor.debug_next_fight()


func _input_vector() -> Vector2:
	if _capture_dir != "":
		return _capture_input
	return Input.get_vector("move_left", "move_right", "move_back", "move_front")


func _physics_process(delta: float) -> void:
	if _arena.active or (corridor != null and corridor.blocking()):
		_leader.velocity = Vector3.ZERO
		return
	var input := _input_vector()
	var speed := 4.4 if Input.is_action_pressed("run") else 2.4
	# Para o fundo e para a frente anda mais devagar (a câmera vê pouco dessa direção).
	_leader.velocity = Vector3(input.x, 0, input.y * 0.75) * speed
	var before := _leader.position
	_leader.move_and_slide()
	_leader.position = _leader.position.clamp(walk_min, walk_max)
	var moved := Vector2(_leader.position.x - before.x, _leader.position.z - before.z).length()
	if moved > 0.2 * delta:
		_step_distance += moved
		if _step_distance >= 0.75:
			_step_distance = 0.0
			Sound.footstep("concrete" if _indoor or scenario == null else Sound.surface_of(scenario.map_name))
	else:
		_step_distance = 0.37
	if _trail.is_empty() or _leader.position.distance_to(_trail[0]) > 0.05:
		_trail.push_front(_leader.position)
		if _trail.size() > 200:
			_trail.pop_back()


## A paisagem sonora (UAHSoundscapeSubsystem::Decide): exploração calma (uma de três faixas pela expedição; a Ponte
## tem a sua), batalha ou chefe na luta, o ambiente do lugar e a chuva (de dentro numa casa ou cenário coberto).
func soundscape() -> Dictionary:
	var place := scenario.map_name if scenario else "ShopfrontStreet"
	var want := {"ambience": "res://audio/ambience/%s.ogg" % place, "ambience_gain": 0.8, "rain": "", "rain_gain": 0.7}
	if _arena != null and _arena.active:
		var boss: bool = _arena.session != null and _arena.session.state.enemy_team.any(func(u): return u.enemy_id == "porteiro")
		want.music = "res://audio/music/boss.ogg" if boss else "res://audio/music/battle.ogg"
		want.music_gain = 0.5
		want.ambience_gain = 0.4
	else:
		var expedition = Campaign.state.get("session", {}).get("expedition")
		var track := (hash(String(expedition.get("id", ""))) % 3 + 3) % 3 + 1 if expedition != null else 1
		want.music = ["", "res://audio/music/explore_1.ogg", "res://audio/music/explore_2.mp3", "res://audio/music/explore_3.mp3"][track]
		if place == "RootBridge":
			want.music = "res://audio/music/explore_root_bridge.mp3"
		want.music_gain = 0.32
	if _raining:
		want.rain = "res://audio/ambience/rain_indoor.ogg" if _indoor or sheltered else "res://audio/ambience/rain_outdoor.ogg"
	return want


## Na captura, a jornada só começa depois das fotos da rua (elas passam perto das patrulhas).
func capture_paused() -> bool:
	return _capture_dir != "" and _combat_phase == 0


# ---------------------------------------------------------------- jornada (chamado pelo AHStreetCorridor)

func begin_fight() -> void:
	_street_hud.visible = false
	_leader.velocity = Vector3.ZERO


func end_fight() -> void:
	_street_hud.visible = true


## Quem morreu sai da equipe; os outros voltam a andar do lugar onde terminaram a luta.
func remove_dead_heroes() -> void:
	for index in range(party_ids.size() - 1, -1, -1):
		var hero = Campaign.hero(party_ids[index])
		if hero == null or not hero.alive:
			_heroes[index].queue_free()
			_heroes.remove_at(index)
			party_ids.remove_at(index)
	for index in _heroes.size():
		_heroes[index].show_art(_combat_art.heroes[party_ids[index]].idle)
		_heroes[index].set_tint(Color.WHITE)
	if not _heroes.is_empty():
		_place_leader(Vector3(_heroes[0].position.x, 0, _leader.position.z if not _indoor else -0.5))


## Dentro de uma casa: a sala é o limite de andar e da câmera, e o clima da rua some (chuva, poeira, feixes).
func set_indoor(indoor: bool, room_x: float = 0.0, room_width: float = 0.0) -> void:
	_indoor = indoor
	_room_x = room_x
	_room_width = room_width
	if indoor:
		# Folga das paredes: o desenho do personagem é mais largo que a cápsula e afundava nas paredes do lado; no fundo,
		# os pés ficam fora do rodapé e na frente dos itens pintados da parede.
		walk_min = Vector3(room_x + AHHouseRoom.SIDE_MARGIN, 0, AHHouseRoom.BACK_Z + AHHouseRoom.BACK_MARGIN)
		walk_max = Vector3(room_x + room_width - AHHouseRoom.SIDE_MARGIN, 0, AHHouseRoom.WALK_FRONT_Z - 0.3)
	else:
		walk_min = STREET_WALK_MIN
		walk_max = STREET_WALK_MAX
	_apply_weather()


## O clima sorteado pela fase (e o que muda ao levantar acampamento), nos ajustes da rua.
func apply_corridor_weather(weather: String) -> void:
	_mood = "night" if ["night", "nightRain", "storm"].has(weather) else "golden"
	_raining = ["rain", "storm", "nightRain"].has(weather)
	_storm = weather == "storm"
	_fog_boost = 2.6 if ["mist", "fog"].has(weather) else 1.0
	_next_flash = 4.0
	_apply_weather()


## Quanto a patrulha enxerga, pelo clima: menos à noite, na chuva e na névoa.
func sight_multiplier() -> float:
	var value := 1.0
	if _mood == "night":
		value *= 0.65
	if _raining:
		value *= 0.8
	if _fog_boost > 1.0:
		value *= 0.7
	return value


func _process(delta: float) -> void:
	_time += delta
	var wet_target := 1.0 if _raining else 0.0
	if not is_equal_approx(_wet, wet_target):
		_wet = move_toward(_wet, wet_target, delta / (4.0 if _raining else 12.0))
		_apply_wet()
	_update_sun(delta)
	_update_fire(delta)
	_place_party(delta)
	_update_camera(delta)
	_update_stats(delta)
	if _capture_dir != "":
		_run_capture(delta)


func _update_stats(delta: float) -> void:
	_frame_ms.append(delta * 1000.0)
	if _frame_ms.size() > 600:
		_frame_ms.pop_front()
	_stats_timer += delta
	if _stats_timer >= 0.5:
		_stats_timer = 0.0
		var avg := 0.0
		for ms in _frame_ms:
			avg += ms
		avg /= _frame_ms.size()
		var size := get_viewport().get_visible_rect().size
		_hud_stats.text = "%s · %dx%d · %d fps (%.1f ms)" % ["Forward+" if _forward_plus else "Compatibility", size.x, size.y, roundi(1000.0 / avg), avg]


## Modo de captura (QA sem editor): Godot ... -- --capture=<pasta>. Tira as fotos, mede os quadros e testa a colisão
## (o líder anda contra um carro e contra uma fachada e precisa parar antes deles), depois sai.
func _run_capture(delta: float) -> void:
	# nome, hora, chuva, X, Z, pós, entrada (X, Z) e segundos andando (testes de colisão).
	const SHOTS := [
		["01-golden-start", "golden", false, 7.6, 0.45, true],
		["02-golden-cinema", "golden", false, 33.0, 0.45, true],
		["03-golden-no-post", "golden", false, 7.6, 0.45, false],
		["04-night-start", "night", false, 7.6, 0.45, true],
		["05-night-workshop", "night", false, 21.0, 0.45, true],
		["06-rain-golden", "golden", true, 7.6, 0.45, true],
		["07-rain-night", "night", true, 33.0, 0.45, true],
		["08-collision-car", "golden", false, 23.0, -1.0, true, Vector2(1, 0), 2.5, 26.5 - LEADER_RADIUS],
		["09-collision-facade", "golden", false, 8.0, -2.0, true, Vector2(0, -1), 2.5, -3.3 + LEADER_RADIUS],
	]
	_capture_frames += 1
	_capture_time += delta
	if _capture_step >= SHOTS.size():
		_run_combat_capture(delta)
		return
	var shot: Array = SHOTS[_capture_step]
	if _capture_frames == 1:
		_frame_ms.clear()
		_capture_time = 0.0
		_mood = shot[1]
		_raining = shot[2]
		# A chuva já assentou: chão molhado e fogueira apagada.
		_wet = 1.0 if _raining else 0.0
		_fire_burn = 0.0 if _raining else 1.0
		_smoke_left = 14.0 if _raining else 0.0
		_apply_wet()
		_apply_weather()
		_place_leader(Vector3(shot[3], 0, shot[4]))
		_post.set_shader_parameter("enabled", shot[5])
		_capture_input = shot[6] if shot.size() > 6 else Vector2.ZERO
		_update_camera(0.0)
		return
	var walking: bool = shot.size() > 6
	if walking and _capture_time < shot[7]:
		return
	_capture_input = Vector2.ZERO
	if _capture_frames < 240:
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	get_viewport().get_texture().get_image().save_png(_capture_dir.path_join(shot[0] + ".png"))
	var line: String
	if walking:
		# Andou para +X (carro) ou -Z (fachada): a posição final não pode passar do limite.
		var reached: float = _leader.position.x if shot[6].x != 0 else _leader.position.z
		var limit: float = shot[8]
		# Precisa chegar até o obstáculo e parar nele (parado longe dele também é falha).
		var ok := absf(reached - limit) <= 0.05
		line = "%s %s reached=%.2f limit=%.2f\n" % [shot[0], "PASS" if ok else "FAIL", reached, limit]
	else:
		var sorted := _frame_ms.slice(60)
		sorted.sort()
		var avg := 0.0
		for ms in sorted:
			avg += ms
		avg /= sorted.size()
		line = "%s avg_ms=%.2f p95_ms=%.2f renderer=%s\n" % [shot[0], avg, sorted[int(sorted.size() * 0.95)], RenderingServer.get_current_rendering_method()]
	var path := _capture_dir.path_join("frames.txt")
	var log_file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	log_file.seek_end()
	log_file.store_string(line)
	log_file.close()
	print(line.strip_edges())
	_capture_step += 1
	_capture_frames = 0


func _save_capture(shot_name: String, line: String = "") -> void:
	get_viewport().get_texture().get_image().save_png(_capture_dir.path_join(shot_name + ".png"))
	if line == "":
		return
	var path := _capture_dir.path_join("frames.txt")
	var log_file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	log_file.seek_end()
	log_file.store_string(line + "\n")
	log_file.close()
	print(line)


## Depois das fotos da rua, a jornada: a equipe se aproxima da primeira patrulha (foto da suspeita), luta (HUD, uma
## ação, o resultado), entra numa casa e vasculha um ponto. A captura usa uma campanha própria, numa pasta própria.
func _run_combat_capture(delta: float) -> void:
	_combat_time += delta
	var campaign: Dictionary = Campaign.state
	var route: Dictionary = campaign.session.expedition.corridor
	match _combat_phase:
		0:
			_mood = "golden"
			_raining = false
			_wet = 0.0
			_fire_burn = 1.0
			_apply_wet()
			_apply_weather()
			_post.set_shader_parameter("enabled", true)
			_combat_phase = 1
			corridor.debug_next_fight()
			_combat_time = 0.0
		1:
			# Anda devagar até a patrulha: a suspeita sobe.
			_capture_input = Vector2(0.5, 0)
			var guard = corridor.guards.get(route.index)
			if guard != null and guard.meter > 0.4 and _combat_time > 0.5 and not FileAccess.file_exists(_capture_dir.path_join("10-patrol-sight.png")):
				_save_capture("10-patrol-sight", "10-patrol-sight meter=%.2f detected=%s" % [guard.meter, guard.detected])
			if _arena.active:
				_capture_input = Vector2.ZERO
				_combat_phase = 2
				_combat_time = 0.0
		2:
			if _arena.hud.waiting and _combat_time > 2.5:
				_save_capture("11-combat-hud")
				var actor := _arena.session.current_actor()
				var options: Array = _arena.session.ability_options(actor.id).filter(func(o): return o.usable)
				var option: Dictionary = options[0]
				_arena.hud.command_chosen.emit({"kind": "ability", "ability_id": option.id,
					"rank": actor.rank if option.self else option.targets[0]})
				_combat_phase = 3
				_combat_time = 0.0
		3:
			if _combat_time > 0.75:
				_save_capture("12-combat-action")
				_arena.auto_battle = true
				_arena.speed = 3.0
				_combat_phase = 4
				_combat_time = 0.0
		4:
			if _arena.hud.waiting:
				_arena.hud.command_chosen.emit({"kind": "defend"})
			if _arena.hud._result.visible and _combat_time > 0.3:
				_save_capture("13-combat-result", "13-combat-result result=%s rounds=%d" % [_arena.session.result(), _arena.session.state.round])
				_combat_phase = 5
				_combat_time = 0.0
			elif not _arena.hud._result.visible:
				_combat_time = 0.0
		5:
			if not _arena.active and _combat_time > 1.0:
				_save_capture("14-after-combat", "14-after-combat step=%d resolved=%s party=%d" % [route.index + 1, route.steps[route.index].resolved, _heroes.size()])
				# Uma casa aberta (atalho da captura: os trechos até ela contam como vencidos).
				var site_index: int = route.sites.map(func(s): return not s.locked).find(true)
				while route.index < route.sites[site_index].step:
					route.steps[route.index].resolved = true
					AHJourneyRules.enter_step(campaign, route.index + 1)
				corridor._enter_house(site_index)
				_combat_phase = 6
				_combat_time = 0.0
		6:
			if _arena.active:
				_arena.auto_battle = true
				_arena.speed = 3.0
				if _arena.hud.waiting:
					_arena.hud.command_chosen.emit({"kind": "defend"})
				_combat_time = 0.0
			elif corridor.room != null and not corridor.busy and _combat_time > 1.5:
				_save_capture("15-house-inside", "15-house-inside shop=%d spots=%d" % [corridor.room.shop, corridor.room.spot_xs.size()])
				var spot: int = route.sites[route.current_house].spots.map(func(s): return not s.searched).find(true)
				if spot >= 0:
					corridor._search_spot(route.current_house, spot)
				_combat_phase = 7
				_combat_time = 0.0
		7:
			if _combat_time > 0.8:
				_save_capture("16-house-search", "16-house-search food=%d seeds=%d event=%s" % [campaign.session.expedition.food,
					campaign.session.expedition.loot.seeds, str(campaign.session.event != null)])
				get_tree().quit()
