## Estação Raiz: o refúgio entre as expedições, em corte (port da planta do AAHShelterStation da Unreal). A plataforma do
## metrô em cima, o subterrâneo 1 (Dormitório, Sala dos Personagens, Bar, Cantina) e o subterrâneo 2 (Pesquisa, Depósito,
## Forja, Preparação), com o eixo de escadas à direita. Esta é a casca da Fase 3a: lajes, paredes, materiais da Poly Haven
## e a luz de cada cômodo, com as mesmas medidas da Unreal; o mobiliário entra na 3b. O HUD (AHRefugeHud) cuida das telas.
##
## Medidas em metros, como na Unreal dividida por 100: X para a direita, Y para cima, Z para o fundo negativo (o corte
## fica em Z 0, de frente para a câmera).
class_name AHStation
extends Node3D

const S := preload("res://scripts/flow/station_rules.gd")
const ART := "res://art/station/"

const STATION_END := 27.6
const TRACK_END := 25.6
const PLATFORM_FRONT := -3.6
const STATION_BACK := -10.0
const BUFFERS_X := 24.4
const CORE_X0 := 28.0
const CORE_X1 := 33.6
const B1_FLOOR := -5.2
const B1_CEILING := -2.0
const B2_FLOOR := -9.4
const B2_CEILING := -6.2
const FORGE_FLOOR := -10.4
const ROOM_BACK := -9.0
const VAULT_TOP := 6.2
const LEFT_END := -12.4
const DOOR_WIDTH := 1.1
const DOOR_HEIGHT := 2.25

const WARM := Color(1.0, 0.74, 0.47)
const AMBER := Color(1.0, 0.62, 0.32)
const NEUTRAL := Color(1.0, 0.94, 0.86)
const COOL := Color(0.82, 0.9, 1.0)
## Cal amarelada e gasta (o branco puro estourava sob as luminárias).
const PLASTER_TINT := Color(0.78, 0.72, 0.62)
const ROCK_TINT := Color(0.17, 0.15, 0.13)

## Cômodos (a tabela Rooms da Unreal, na ordem do menu): id das regras, extensão em X, piso e teto, piso, parede,
## lambri, cor da luz, porta do fundo e a faixa onde os moradores ficam.
const ROOMS := [
	{"id": "characters", "x0": -0.4, "x1": 7.6, "floor": B1_FLOOR, "ceiling": B1_CEILING, "floor_art": "wood_planks_grey",
		"wall": "painted_plaster_wall", "wainscot": "", "light": WARM, "door": 1.2, "lane": [1.1, 6.1]},
	{"id": "canteen", "x0": 15.6, "x1": STATION_END, "floor": B1_FLOOR, "ceiling": B1_CEILING, "floor_art": "worn_tile_floor",
		"wall": "painted_plaster_wall", "wainscot": "long_white_tiles", "light": WARM, "door": 17.0, "lane": [17.2, 25.6]},
	{"id": "bar", "x0": 7.6, "x1": 15.6, "floor": B1_FLOOR, "ceiling": B1_CEILING, "floor_art": "wood_planks_grey",
		"wall": "red_brick_03", "wainscot": "", "light": AMBER, "door": 8.8, "lane": [9.1, 14.1]},
	{"id": "dormitory", "x0": -12.4, "x1": -0.4, "floor": B1_FLOOR, "ceiling": B1_CEILING, "floor_art": "wood_planks_grey",
		"wall": "painted_plaster_wall", "wainscot": "", "light": WARM, "door": -2.1, "lane": [-10.9, -1.9]},
	{"id": "forge", "x0": 11.6, "x1": 21.6, "floor": FORGE_FLOOR, "ceiling": B2_CEILING, "floor_art": "DiamondPlate008A",
		"wall": "CorrugatedSteel009", "wainscot": "Metal021", "light": NEUTRAL, "door": 12.8, "lane": [13.6, 19.6]},
	{"id": "depot", "x0": 5.6, "x1": 11.6, "floor": B2_FLOOR, "ceiling": B2_CEILING, "floor_art": "concrete_floor_worn_001",
		"wall": "concrete_wall_008", "wainscot": "", "light": NEUTRAL, "door": 6.8, "lane": [7.2, 10.3]},
	{"id": "research", "x0": -6.4, "x1": 5.6, "floor": B2_FLOOR, "ceiling": B2_CEILING, "floor_art": "concrete_floor_painted",
		"wall": "painted_plaster_wall", "wainscot": "long_white_tiles", "light": COOL, "door": 3.9, "lane": [-4.9, 4.1]},
	{"id": "preparation", "x0": 21.6, "x1": STATION_END, "floor": B2_FLOOR, "ceiling": B2_CEILING, "floor_art": "rubber_tiles",
		"wall": "concrete_wall_008", "wainscot": "", "light": NEUTRAL, "door": 22.8, "lane": [22.9, 26.2]},
]
## Profundidade em que os moradores ficam (a faixa de passeio da Unreal, Y -330).
const LANE_Z := -3.3
## Chance de um morador dividir um cômodo já ocupado (no máximo dois).
const SHARE_ROOM_CHANCE := 0.3

var hud: AHRefugeHud
var camera: Camera3D
var residents := {}
var _materials := {}
var _room_lights := {}
var _camera_target := Vector3.ZERO
var _camera_distance := 60.0
var _camera_tween: Tween
var _combat_art := {}
var _civilian_art := {}
var _candidate_card: AHSpriteCard
var _train: Node3D


func _ready() -> void:
	var campaign: Dictionary = Campaign.state
	# Quem abre a Estação no meio de uma expedição (o jogo fechou na rua) volta para a rua.
	var session: Dictionary = campaign.get("session", {})
	if session.get("expedition") != null and session.get("result", "") == "":
		GameFlow.change_to.call_deferred("street", {}, false)
		return
	_combat_art = JSON.parse_string(FileAccess.get_file_as_string(AHCombatArena.ART_MANIFEST))
	_civilian_art = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/civilians.json"))
	_build_environment()
	_build_platform()
	_build_levels()
	for room in ROOMS:
		_build_room(room)
	_build_core()
	_build_camera()
	_build_post()
	hud = AHRefugeHud.new()
	hud.station = self
	var layer := CanvasLayer.new()
	layer.layer = 2
	layer.add_child(hud)
	add_child(layer)
	_arrive(campaign)
	refresh()


## Chegada: a volta da expedição (se o jogo fechou no relatório da rua, a entrega acontece aqui), os voluntários a
## caminho e o que espera o jogador (o relatório, a noite, o trem).
func _arrive(campaign: Dictionary) -> void:
	if campaign.session.get("expedition") != null and campaign.session.get("result", "") != "":
		S.finish_return(campaign)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	S.receive_volunteers(campaign, rng)
	Campaign.save()
	_place_residents(rng)
	if not campaign.station.last_return.is_empty() and not campaign.station.last_return.get("seen", false):
		hud.open_service("report")
	elif campaign.night.phase != "none":
		hud.open_room("dormitory")
	elif S.visit_pending(campaign):
		hud.open_service("train")
	else:
		focus_overview(true)


## Grava a campanha e atualiza tudo o que mostra o estado (HUD, moradores, trem, luzes com energia).
func commit() -> void:
	Campaign.save()
	refresh()


func refresh() -> void:
	var campaign: Dictionary = Campaign.state
	var running := S.running_rooms(campaign)
	for room_id in _room_lights:
		var light: OmniLight3D = _room_lights[room_id]
		var level := S.room_level(campaign, room_id)
		# Cômodo vazio fica na penumbra; sem energia, a luz cai (as salas que gastam energia).
		var powered: bool = not [S.CANTEEN, S.RESEARCH, S.FORGE].has(room_id) or running.has(room_id)
		light.light_energy = (4.0 if powered else 1.4) if level >= 1 else 1.2
	_update_train(campaign)
	if hud:
		hud.refresh()


# ---------------------------------------------------------------- câmera

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 26.0
	camera.far = 300.0
	add_child(camera)
	_camera_target = Vector3((LEFT_END + CORE_X1) * 0.5, -2.0, -4.0)
	_camera_distance = 62.0
	_place_camera()


func _place_camera() -> void:
	var pitch := deg_to_rad(3.0)
	camera.position = _camera_target + Vector3(0, sin(pitch) * _camera_distance, cos(pitch) * _camera_distance)
	camera.look_at(_camera_target)


func _move_camera(target: Vector3, distance: float, instant: bool) -> void:
	if _camera_tween:
		_camera_tween.kill()
	if instant:
		_camera_target = target
		_camera_distance = distance
		_place_camera()
		return
	_camera_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(self, "_camera_target", target, 0.7)
	_camera_tween.tween_property(self, "_camera_distance", distance, 0.7)


func _process(_delta: float) -> void:
	if camera:
		_place_camera()


## A faixa da tela que o HUD deixa livre (na base de 1920): à direita do menu e, com um painel aberto, à esquerda dele.
const SCREEN_MENU_RIGHT := 380.0
const SCREEN_PANEL_LEFT := 1200.0


## O corte inteiro, à direita do menu.
func focus_overview(instant: bool = false) -> void:
	_frame(LEFT_END - 0.5, CORE_X1 + 0.5, -2.4, SCREEN_MENU_RIGHT, 1900.0, instant)


func focus_platform(instant: bool = false) -> void:
	_frame(0.5, STATION_END, 2.0, SCREEN_MENU_RIGHT, SCREEN_PANEL_LEFT, instant)


func focus_room(room_id: String, instant: bool = false) -> void:
	var room := room_def(room_id)
	if room.is_empty():
		return
	_frame(room.x0 - 0.3, room.x1 + 0.3, room.floor + 1.55, SCREEN_MENU_RIGHT, SCREEN_PANEL_LEFT, instant)


## Põe a extensão x0..x1 inteira na faixa da tela entre left_px e right_px (na base de 1920), com o centro vertical em
## y. A câmera fica de frente para o corte, então a distância sai da largura que a faixa mostra.
func _frame(x0: float, x1: float, y: float, left_px: float, right_px: float, instant: bool) -> void:
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var half_width_per_meter := tan(deg_to_rad(camera.fov * 0.5)) * aspect
	var share := (right_px - left_px) / 1920.0
	# O corte fica em Z 0 e a câmera olha para Z ~ -4: a distância conta até o plano da frente.
	var distance := (x1 - x0) / (2.0 * half_width_per_meter * share * 0.94) + 4.5
	var offset := ((left_px + right_px) * 0.5 - 960.0) / 1920.0 * 2.0 * half_width_per_meter * (distance - 4.5)
	_move_camera(Vector3((x0 + x1) * 0.5 - offset, y, -4.5), distance, instant)


static func room_def(room_id: String) -> Dictionary:
	for room in ROOMS:
		if room.id == room_id:
			return room
	return {}


# ---------------------------------------------------------------- moradores

## Cada herói vivo num cômodo sorteado (30% de chance de dividir um já ocupado, no máximo dois), parado na faixa do
## cômodo; os civis ficam no cômodo deles. O passeio pelos cômodos entra na 3b.
func _place_residents(rng: RandomNumberGenerator) -> void:
	for card in residents.values():
		card.queue_free()
	residents.clear()
	var campaign: Dictionary = Campaign.state
	var occupancy := {}
	var free_rooms: Array = ROOMS.map(func(r): return r.id)
	for entry in S.living(campaign):
		var art: Dictionary = _combat_art.heroes.get(entry.id, {})
		if art.is_empty():
			art = _class_art(entry.class_id)
		if art.is_empty():
			continue
		var room_id: String
		var shared: Array = occupancy.keys().filter(func(id): return occupancy[id] < 2)
		if free_rooms.is_empty() or (not shared.is_empty() and rng.randf() < SHARE_ROOM_CHANCE):
			room_id = shared[rng.randi_range(0, shared.size() - 1)] if not shared.is_empty() else ROOMS[0].id
		else:
			room_id = free_rooms.pop_at(rng.randi_range(0, free_rooms.size() - 1))
		occupancy[room_id] = int(occupancy.get(room_id, 0)) + 1
		var room := room_def(room_id)
		var card := AHSpriteCard.new()
		card.body_height = AHCharacterHeights.find(entry.id)
		card.show_art(art.idle)
		add_child(card)
		var lane: Array = room.lane
		var slot := 0.3 if occupancy[room_id] == 1 else 0.7
		card.position = Vector3(lerpf(lane[0], lane[1], slot + rng.randf_range(-0.12, 0.12)), room.floor, LANE_Z + rng.randf_range(-0.3, 0.3))
		card.set_facing(1.0 if rng.randf() < 0.5 else -1.0)
		residents[entry.id] = card
	for civilian_id in campaign.station.residents:
		var art: Dictionary = _civilian_art.get(civilian_id, {})
		var room := room_def(S.civilian(civilian_id).get("room", ""))
		if art.is_empty() or room.is_empty():
			continue
		var card := AHSpriteCard.new()
		card.body_height = AHCharacterHeights.find(civilian_id)
		card.show_art(art)
		add_child(card)
		card.position = Vector3(lerpf(room.lane[0], room.lane[1], 0.5), room.floor, LANE_Z - 0.4)
		residents[civilian_id] = card


## Recrutas novos ainda não têm arte própria: usam a do fundador da mesma classe.
func _class_art(class_id: String) -> Dictionary:
	for hero_id in _combat_art.heroes:
		if hero_id.begins_with("hero_%s_" % class_id):
			return _combat_art.heroes[hero_id]
	return {}


func civilian_art(civilian_id: String) -> Dictionary:
	return _civilian_art.get(civilian_id, {})


## O trem na plataforma enquanto há um candidato esperando (ou partindo), com o candidato na porta.
func _update_train(campaign: Dictionary) -> void:
	var train: Dictionary = campaign.station.train
	_train.visible = train.phase != "none"
	if _candidate_card:
		_candidate_card.queue_free()
		_candidate_card = null
	if train.phase == "waiting":
		var art := civilian_art(train.candidate_id)
		if not art.is_empty():
			_candidate_card = AHSpriteCard.new()
			_candidate_card.body_height = AHCharacterHeights.find(train.candidate_id)
			_candidate_card.show_art(art)
			add_child(_candidate_card)
			_candidate_card.position = Vector3(15.4, 0.0, -4.6)
			_candidate_card.set_facing(1.0)


# ---------------------------------------------------------------- casca

func _surface(name: String, tint: Color = Color.WHITE, scale: float = 0.5) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [name, tint.to_html(), scale]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	var path := ART + name + ".webp"
	if ResourceLoader.exists(path):
		material.albedo_texture = load(path)
	material.albedo_color = tint
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * scale
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.roughness = 0.9
	_materials[key] = material
	return material


func _tone(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var key := "tone|%s|%s" % [color.to_html(), emission]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	_materials[key] = material
	return material


func _box(min_corner: Vector3, max_corner: Vector3, material: Material, shadow: bool = true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = (max_corner - min_corner).abs()
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = (min_corner + max_corner) * 0.5
	if not shadow:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh


func _light(at: Vector3, color: Color, energy: float, light_range: float, shadow: bool = true) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.2
	light.shadow_enabled = shadow
	add_child(light)
	return light


## Luminária pendente: a cúpula escura, a lâmpada acesa e a luz.
func _lamp(at: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	_box(at + Vector3(-0.22, 0.0, -0.22), at + Vector3(0.22, 0.12, 0.22), _tone(Color(0.08, 0.07, 0.06)), false)
	_box(at + Vector3(-0.08, -0.08, -0.08), at + Vector3(0.08, 0.0, 0.08), _tone(color, 4.0), false)
	return _light(at + Vector3(0, -0.25, 0.4), color, energy, light_range)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.028, 0.026)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.45)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 5.0
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_strength = 0.9
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.04
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		env.ssao_enabled = true
		env.ssao_radius = 0.9
		env.ssao_intensity = 1.4
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	# Luz de preenchimento de frente, fraca, para ler o corte (como a câmera da Unreal).
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-12, 8, 0)
	fill.light_color = Color(0.85, 0.82, 0.78)
	fill.light_energy = 0.22
	add_child(fill)


func _build_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var post := ShaderMaterial.new()
	post.shader = preload("res://shaders/post_emberfall.gdshader")
	# No refúgio o corte inteiro precisa ler: foco largo e pouco desfoque, só a cor e a vinheta do Emberfall.
	post.set_shader_parameter("focus_center", 0.5)
	post.set_shader_parameter("focus_width", 0.8)
	post.set_shader_parameter("max_blur", 3.0)
	post.set_shader_parameter("vignette", 0.45)
	rect.material = post
	layer.add_child(rect)
	add_child(layer)


## A plataforma do metrô: leito da via com brita, trilhos e dormentes na frente, a plataforma atrás, a parede de
## azulejos do fundo, o teto de tijolo, o batente no fim da via e o vagão (visível quando o trem traz alguém).
func _build_platform() -> void:
	var concrete := _surface("rough_concrete", PLASTER_TINT * 0.8)
	_box(Vector3(0, -2.0, PLATFORM_FRONT), Vector3(TRACK_END, -1.0, 0), _surface("gravel_floor_02", Color(0.75, 0.72, 0.68), 0.6))
	for x in range(1, int(TRACK_END * 1.5)):
		_box(Vector3(x / 1.5 - 0.12, -1.0, -2.95), Vector3(x / 1.5 + 0.12, -0.9, -0.65), _tone(Color(0.16, 0.12, 0.09)))
	for z in [-2.55, -1.05]:
		_box(Vector3(0, -0.9, z - 0.04), Vector3(TRACK_END, -0.78, z + 0.04), _tone(Color(0.34, 0.33, 0.32)))
	_box(Vector3(TRACK_END, -2.0, PLATFORM_FRONT), Vector3(STATION_END, 0.0, 0), concrete)
	# Batente com a lanterna vermelha do fim da linha.
	_box(Vector3(BUFFERS_X - 0.3, -1.0, -2.9), Vector3(BUFFERS_X + 0.3, -0.1, -0.7), _tone(Color(0.32, 0.08, 0.05)))
	_box(Vector3(BUFFERS_X - 0.1, -0.1, -1.9), Vector3(BUFFERS_X + 0.1, 0.1, -1.7), _tone(Color(1.0, 0.15, 0.08), 6.0), false)
	_light(Vector3(BUFFERS_X - 0.5, 0.3, -1.2), Color(1.0, 0.25, 0.12), 1.2, 4.0, false)
	# Plataforma: o piso, a borda e a parede do fundo com azulejo até 3 m e tijolo em cima.
	_box(Vector3(0, -2.0, STATION_BACK), Vector3(STATION_END, 0.0, PLATFORM_FRONT), _surface("anti_slip_concrete", Color(0.8, 0.78, 0.74), 0.5))
	_box(Vector3(0, -0.05, PLATFORM_FRONT - 0.35), Vector3(STATION_END, 0.0, PLATFORM_FRONT), _tone(Color(0.78, 0.66, 0.2)), false)
	_box(Vector3(0, 0, STATION_BACK - 0.3), Vector3(STATION_END, 3.0, STATION_BACK), _surface("long_white_tiles", Color(0.82, 0.8, 0.74), 0.6))
	_box(Vector3(0, 3.0, STATION_BACK - 0.3), Vector3(STATION_END, VAULT_TOP, STATION_BACK), _surface("red_brick_03", Color(0.62, 0.5, 0.44), 0.5))
	_box(Vector3(-0.3, VAULT_TOP, STATION_BACK - 0.3), Vector3(STATION_END + 0.3, VAULT_TOP + 0.6, 0.4), _surface("red_brick_03", Color(0.5, 0.4, 0.36), 0.5))
	# Paredes de término: à esquerda o túnel continua escuro; à direita o fim da estação.
	_box(Vector3(-0.6, -2.0, STATION_BACK - 0.3), Vector3(0, VAULT_TOP, 0.4), _surface("factory_brick", Color(0.35, 0.3, 0.27), 0.5))
	_box(Vector3(STATION_END, -2.0, STATION_BACK - 0.3), Vector3(CORE_X0, VAULT_TOP + 0.6, 0.4), concrete)
	for x in [3.0, 9.0, 15.0, 21.0, 26.0]:
		_lamp(Vector3(x, 5.2, -6.2), NEUTRAL, 2.2, 9.0)
	# Bancos da plataforma e uma pilastra a cada 6 m.
	for x in [3.3, 11.3, 14.5]:
		_box(Vector3(x - 0.8, 0.0, -9.6), Vector3(x + 0.8, 0.45, -9.1), _tone(Color(0.3, 0.2, 0.12)))
		_box(Vector3(x - 0.8, 0.45, -9.75), Vector3(x + 0.8, 0.95, -9.6), _tone(Color(0.3, 0.2, 0.12)))
	for x in [6.0, 12.0, 18.0]:
		_box(Vector3(x - 0.25, 0.0, -9.9), Vector3(x + 0.25, VAULT_TOP, -9.5), _surface("long_white_tiles", Color(0.7, 0.68, 0.62), 0.6))
	# O vagão: chega com o trem de cada volta e espera enquanto há alguém para decidir.
	_train = Node3D.new()
	add_child(_train)
	var body := _box(Vector3(0.4, -0.75, -3.15), Vector3(13.6, 2.85, -0.45), _tone(Color(0.78, 0.78, 0.76)))
	body.reparent(_train)
	for x in [2.6, 6.4, 10.2]:
		var door := _box(Vector3(x - 0.75, -0.6, -0.44), Vector3(x + 0.75, 2.3, -0.4), _tone(Color(0.72, 0.1, 0.08)))
		door.reparent(_train)
	for x in range(1, 13):
		var window := _box(Vector3(x - 0.3, 1.1, -0.43), Vector3(x + 0.3, 2.0, -0.41), _tone(Color(0.55, 0.45, 0.32), 0.35), false)
		window.reparent(_train)
	var nose := _box(Vector3(13.6, -0.75, -3.0), Vector3(14.0, 2.6, -0.6), _tone(Color(0.72, 0.1, 0.08)))
	nose.reparent(_train)


## As lajes entre os níveis e a terra em volta do corte.
func _build_levels() -> void:
	var slab := _surface("rough_concrete", Color(0.5, 0.47, 0.43), 0.5)
	var rock := _surface("rough_concrete", ROCK_TINT * 2.0, 0.35)
	# Laje do subterrâneo 1 (entre a via e o teto do B1).
	_box(Vector3(LEFT_END, B1_CEILING, ROOM_BACK - 2.2), Vector3(0, -0.6, 0.0), slab)
	_box(Vector3(0, B1_CEILING, ROOM_BACK - 2.2), Vector3(STATION_END, -2.0 + 0.001, STATION_BACK - 0.3), slab)
	_box(Vector3(LEFT_END, B1_CEILING + 0.001, 0), Vector3(STATION_END, B1_CEILING + 0.35, 0.05), _tone(Color(0.32, 0.3, 0.27)))
	# Laje entre o B1 e o B2.
	_box(Vector3(LEFT_END, B2_CEILING, ROOM_BACK - 2.2), Vector3(STATION_END, B1_FLOOR - 0.3, 0.0), slab)
	# Terra: à esquerda da plataforma, embaixo do B2 e no fundo.
	_box(Vector3(LEFT_END - 4.0, -0.6, ROOM_BACK - 2.4), Vector3(-0.6, VAULT_TOP + 1.0, 0.0), rock)
	_box(Vector3(LEFT_END - 4.0, FORGE_FLOOR - 3.0, ROOM_BACK - 2.4), Vector3(CORE_X1 + 4.0, B2_FLOOR - 0.3, 0.0), rock)
	_box(Vector3(LEFT_END - 4.0, FORGE_FLOOR - 3.0, ROOM_BACK - 2.6), Vector3(CORE_X1 + 4.0, VAULT_TOP + 1.0, ROOM_BACK - 2.4), rock)
	_box(Vector3(LEFT_END - 4.0, B2_FLOOR - 0.3, ROOM_BACK - 2.4), Vector3(-6.4, B2_CEILING, 0.0), rock)
	_box(Vector3(CORE_X1, FORGE_FLOOR - 3.0, ROOM_BACK - 2.4), Vector3(CORE_X1 + 4.0, VAULT_TOP + 1.0, 0.0), rock)
	# Corredor de serviço ao fundo de cada nível (atrás das portas dos cômodos).
	for level in [[B1_FLOOR, B1_CEILING], [B2_FLOOR, B2_CEILING]]:
		_box(Vector3(LEFT_END, level[0] - 0.3, ROOM_BACK - 2.2), Vector3(STATION_END, level[0], ROOM_BACK), slab)
		_box(Vector3(LEFT_END, level[0], ROOM_BACK - 2.4), Vector3(STATION_END, level[1], ROOM_BACK - 2.2), _surface("concrete_wall_008", PLASTER_TINT * 0.6))


## Um cômodo: piso, parede do fundo (com lambri e a porta do corredor), teto, divisórias e a luminária.
func _build_room(room: Dictionary) -> void:
	var x0: float = room.x0
	var x1: float = room.x1
	var floor_y: float = room.floor
	var top: float = room.ceiling
	_box(Vector3(x0, floor_y - 0.3, ROOM_BACK), Vector3(x1, floor_y, 0.0), _surface(room.floor_art, Color(0.85, 0.82, 0.78), 0.5))
	var wall_tint := PLASTER_TINT if room.wall == "painted_plaster_wall" else Color(0.75, 0.72, 0.68)
	var wainscot_top := floor_y + (1.2 if room.wainscot != "" else 0.0)
	_box(Vector3(x0, wainscot_top, ROOM_BACK - 0.2), Vector3(x1, top, ROOM_BACK), _surface(room.wall, wall_tint, 0.45))
	if room.wainscot != "":
		_box(Vector3(x0, floor_y, ROOM_BACK - 0.2), Vector3(x1, wainscot_top, ROOM_BACK + 0.02), _surface(room.wainscot, Color(0.8, 0.8, 0.76), 0.6))
	# Porta para o corredor do fundo: o vão escuro e o batente.
	var door_x: float = room.door
	_box(Vector3(door_x - DOOR_WIDTH * 0.5 - 0.08, floor_y, ROOM_BACK + 0.02), Vector3(door_x + DOOR_WIDTH * 0.5 + 0.08, floor_y + DOOR_HEIGHT + 0.08, ROOM_BACK + 0.06), _tone(Color(0.2, 0.17, 0.13)))
	_box(Vector3(door_x - DOOR_WIDTH * 0.5, floor_y, ROOM_BACK + 0.06), Vector3(door_x + DOOR_WIDTH * 0.5, floor_y + DOOR_HEIGHT, ROOM_BACK + 0.08), _tone(Color(0.3, 0.33, 0.22)))
	_box(Vector3(x0 - 0.1, top, ROOM_BACK), Vector3(x1 + 0.1, top + 0.2, 0.0), _surface("concrete_wall_008", Color(0.42, 0.4, 0.37), 0.5))
	for x in [x0, x1]:
		_box(Vector3(x - 0.12, floor_y, ROOM_BACK), Vector3(x + 0.12, top, 0.0), _surface("concrete_wall_008", Color(0.55, 0.52, 0.48), 0.5))
	var light := _lamp(Vector3((x0 + x1) * 0.5, top - 0.35, -4.2), room.light, 4.0, maxf(10.0, (x1 - x0) * 1.0))
	_room_lights[room.id] = light


## O eixo de escadas à direita: patamares em cada nível e os lances entre eles.
func _build_core() -> void:
	var concrete := _surface("concrete_wall_008", Color(0.5, 0.47, 0.43), 0.5)
	_box(Vector3(CORE_X0, FORGE_FLOOR - 0.3, ROOM_BACK - 0.2), Vector3(CORE_X1, VAULT_TOP, ROOM_BACK), concrete)
	for level in [[0.0, 3.0], [B1_FLOOR, B1_CEILING], [B2_FLOOR, B2_CEILING]]:
		_box(Vector3(CORE_X0, level[0] - 0.3, ROOM_BACK), Vector3(CORE_X1, level[0], 0.0), _surface("concrete_floor_worn_001", Color(0.7, 0.68, 0.64), 0.5))
		_lamp(Vector3(CORE_X0 + 1.2, level[1] - 0.4, -2.5), WARM, 1.6, 6.0)
	for pair in [[0.0, B1_FLOOR], [B1_FLOOR, B2_FLOOR]]:
		var flight := _box(Vector3(-2.0, -0.12, -0.6), Vector3(2.0, 0.12, 0.6), _tone(Color(0.36, 0.34, 0.31)))
		var drop: float = pair[0] - pair[1]
		flight.position = Vector3((CORE_X0 + CORE_X1) * 0.5 + 0.4, (pair[0] + pair[1]) * 0.5, -6.0)
		flight.scale = Vector3(sqrt(4.0 * 4.0 + drop * drop) / 4.0, 1.0, 1.0)
		flight.rotation.z = atan2(drop, 4.0)
	_box(Vector3(CORE_X0 - 0.15, FORGE_FLOOR - 0.3, ROOM_BACK), Vector3(CORE_X0 + 0.05, VAULT_TOP, 0.0), concrete)
