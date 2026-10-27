## Rua das Vitrines montada em código, como AAHShopfrontStreetBlockout (Source/AfterHumans/Exploration): mesmas medidas,
## mesma arte pintada. Por cima, a atmosfera do Emberfall: câmera teleobjetiva, sol baixo, luzes quentes, névoa,
## partículas e o pós-processamento de shaders/post_emberfall.gdshader. Chuva com chão molhado (a fogueira apaga) e
## colisão: o líder anda na rua e nos becos e esbarra nos prédios, carros e props; a equipe segue o caminho dele.
##
## As medidas abaixo estão em centímetros e nos eixos da Unreal (X direita, Y profundidade com a câmera em +Y, Z cima);
## ue() converte para metros nos eixos da Godot (X direita, Y cima, Z para a câmera).
extends Node3D


# A montagem fixa da rua (prédios, postes, carros, props) está em AHStreetSet e na cena gravada (#8).
const FIRE := Vector3(180, 40, 0)
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
## A câmera dos cenários: inclinação (quase reta) e meio campo de visão na horizontal, em graus.
const SCENARIO_PITCH := 0.5
const SCENARIO_HALF_FOV := 15.0
## A câmera da exploração (#129), num lugar só: a distância até a equipe e a altura do alvo sobre o piso (m), na rua,
## nos cenários e dentro das lojas. Uns 17% mais perto que antes (18,5, 19 e 11 m); o alvo desce junto, para os pés
## ficarem acima das plaquinhas da equipe. A Ponte das Raízes (antes 28 m e 2,7 m) usa a dos outros cenários (#140).
## A barra de Admin ainda aproxima ou afasta.
const EXPLORE_CAMERA := {
	"street": {"distance": 15.4, "height": 1.7},
	"scenario": {"distance": 15.8, "height": 1.45},
	"indoor": {"distance": 9.2, "height": 1.45},
}
## O preenchimento da luta nos cenários: energia no fim de tarde e quanto soma de noite e na chuva.
const COMBAT_FILL := 0.3
const COMBAT_FILL_NIGHT := 0.35
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
## Preenchimento da luta nos cenários (#48): uma luz direcional que só pega os personagens (a camada das placas). As
## luminárias do mapa deixam pontas da luta na penumbra, e no Compatibility (a web) cada objeto recebe só 8 luzes, o
## que deixava a luz de leitura de fora; a direcional não conta nesse limite e ilumina as quatro posições por igual.
var _fill_light: DirectionalLight3D
## Passos (#62): um a cada passada de ~75 cm, só fora da luta.
var _step_distance := 0.37
## O balanço do passo de cada herói (WalkBobHeight da Unreal: 3 cm, 3 passos por segundo, só andando).
var _bob_time: Array[float] = []
const WALK_BOB := 0.03
const WALK_BOB_STEPS := 3.0
## A rua montada: a cena gravada (tools/bake_street.gd) e o que se monta a cada abertura (a fogueira, a colisão dos
## cenários), com os mesmos auxiliares.
var _set: AHStreetSet
var _dynamic: AHStreetSet
var _piece_materials := {}
var _skyline_materials: Array[ShaderMaterial] = []
var _lamp_lights: Array[OmniLight3D] = []
var _door_lights: Array[OmniLight3D] = []
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
## A silhueta de quem está escondido e o esmaecimento do que tapa (#51).
var occlusion: AHOcclusion
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
## Na luta num cenário, o quanto o chão de quem luta sobe para os pés passarem da borda da frente do piso (#48).
var combat_lift := 0.0
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
	_dynamic = AHStreetSet.new()
	_dynamic.name = "Dynamic"
	add_child(_dynamic)
	_debug_material = _dynamic.debug_material
	_build_environment()
	var map := _journey_map()
	if map != "" and AHScenarioWorld.exists(map):
		scenario = AHScenarioWorld.new()
		add_child(scenario)
		scenario.build(map)
		_build_scenario_colliders()
	else:
		# A rua vem pronta da cena (editável no editor); sem ela, monta na hora (o mesmo resultado).
		if ResourceLoader.exists(AHStreetSet.scene_path):
			_set = load(AHStreetSet.scene_path).instantiate()
		else:
			push_warning("Rua: %s não existe; montando em código (rode tools/bake_street.gd)." % AHStreetSet.scene_path)
			_set = AHStreetSet.new()
			_set.build()
		add_child(_set)
	_build_atmosphere()
	_collect_set()
	# Os materiais do chão vêm da cena (compartilhados): começam secos, como o clima pede.
	_apply_wet()
	_build_rain()
	_build_party()
	occlusion = AHOcclusion.new()
	occlusion.name = "Occlusion"
	add_child(occlusion)
	occlusion.scan(scenario if scenario else _set)
	# Os objetos da rua que o corredor põe depois (portas, pontos de busca) entram no fim do quadro.
	occlusion.scan.call_deferred(_dynamic)
	for card in _heroes:
		occlusion.track(card)
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
	_fill_light = DirectionalLight3D.new()
	_fill_light.light_cull_mask = AHSpriteCard.CHARACTER_LAYER
	_fill_light.light_color = Color(1.0, 0.9, 0.78)
	_fill_light.shadow_enabled = false
	_fill_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_fill_light.rotation_degrees = Vector3(-30.0, 20.0, 0.0)
	_fill_light.visible = false
	add_child(_fill_light)
	_build_camera()
	_build_post_and_hud()
	_arena = AHCombatArena.new()
	add_child(_arena)
	_arena.setup(self)
	_apply_graphics()
	Settings.changed.connect(func():
		_apply_graphics()
		_apply_weather()
		if scenario:
			scenario.refresh_water_pace())
	_apply_weather()
	exploration_hud = AHExplorationHud.new()
	_street_hud.add_child(exploration_hud)
	if scenario:
		exploration_hud.place = scenario.display_name
		exploration_hud.map_id = scenario.map_name
	exploration_hud.set_weather(_hud_weather.text)
	corridor = AHStreetCorridor.new()
	add_child(corridor)
	corridor.setup(self, exploration_hud)
	var touch := AHTouchControls.new()
	touch.street = self
	_street_hud.add_child(touch)
	Tips.show_tip("explore")


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
	Settings.apply_lamp_shadows()
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


## A colisão dos obstáculos do cenário (o que a Unreal marca como sólido na faixa de passeio), com as caixas da tecla C.
func _build_scenario_colliders() -> void:
	for box in scenario.obstacles:
		_dynamic.add_collider(box.get_center(), box.size)


## O que a rua mexe depois de montada, achado pelos grupos e pelos metadados gravados na cena: as luzes dos postes e das
## portas, os feixes de sol, as silhuetas do fundo, os materiais do chão que molham e as caixas da tecla C. Roda uma vez,
## no _ready: uma colisão posta em _dynamic depois disso precisa entrar em _debug_colliders à mão (como as das casas).
func _collect_set() -> void:
	for root in ([_set] if _set else []) + [_dynamic]:
		for node in root.find_children("*", "", true, false):
			if node.is_queued_for_deletion():
				continue
			if node.is_in_group(AHStreetSet.LAMP_GROUP):
				_lamp_lights.append(node)
				# Os postes têm sombra no desenho: ela segue a qualidade (#37).
				if node.shadow_enabled:
					node.add_to_group(Settings.SHADOW_LAMPS)
			elif node.is_in_group(AHStreetSet.DOOR_LIGHT_GROUP):
				_door_lights.append(node)
			elif node.is_in_group(AHStreetSet.SHAFT_GROUP):
				_shafts.append(node)
			elif node.is_in_group(AHStreetSet.SKYLINE_GROUP):
				_skyline_materials.append(node.material_override)
			elif node.is_in_group(AHStreetSet.DEBUG_GROUP):
				_debug_colliders.append(node)
			if node is MeshInstance3D and node.material_override != null and node.material_override.has_meta("street_piece"):
				_piece_materials[String(node.material_override.get_meta("street_piece"))] = node.material_override


## Entra numa zona do cenário: o piso, a faixa (até 1,2 m para cada lado do meio, como a LaneDepth da Unreal), a
## câmera e se é coberta (sem chuva). As cobertas: Abrigo, Dutos e Depósito inteiros, e as zonas depois da primeira.
func set_scenario_zone(index: int) -> void:
	_zone = scenario.zones[index]
	floor_y = _zone.y
	lane_z = (_zone.z0 + _zone.z1) * 0.5
	var half_depth: float = minf(1.2, (_zone.z1 - _zone.z0 - 1.0) * 0.5)
	walk_min = Vector3(_zone.x0 + 0.4, floor_y, lane_z - half_depth)
	walk_max = Vector3(_zone.x1 - 0.4, floor_y, lane_z + half_depth)
	# A borda do piso da frente encobre os pés: a silhueta não pinta essa faixa (#51).
	var edge: float = scenario.front_edge(index, lane_z) + 0.04
	for card in _heroes:
		card.set_silhouette_foot(maxf(AHSpriteCard.SILHOUETTE_FOOT, edge))
	sheltered = index > 0 or ["SewerDucts", "SealedShelter", "FloodedDepot"].has(scenario.map_name)
	_apply_weather()


# ---------------------------------------------------------------- arte e materiais

# ---------------------------------------------------------------- montagem (Rebuild)

## Portas das fachadas dentro do corredor: X (m), loja, espelho e o trecho onde fica (as de fora ficam fechadas).
func door_list() -> Array:
	var doors: Array = []
	if scenario:
		return doors
	for spec in door_specs():
		var index: int = spec.building
		var building: Array = AHStreetSet.FACADE_BUILDINGS[index]
		# O X vem da cena (o nó BuildingN, na ordem de FACADE_BUILDINGS): movido no editor, a porta onde se entra vai junto,
		# sem sair do corredor.
		var x: float = spec.base
		var node := _set.get_node_or_null("Building%d" % (index + 1)) as Node3D if _set else null
		if node != null:
			x = clampf(spec.base + node.global_position.x - (building[0] + AHStreetSet.FACADE_WIDTH * 0.5) * 0.01, 0.5, CORRIDOR_LENGTH - 0.5)
		doors.append({"x": x, "shop": spec.shop, "mirror": spec.mirror, "step": spec.step})
	return doors


## As portas do corredor pela montagem original, sem a cena (o radar do Mapa da Rede lê as casas com elas, #87): quais
## estão no corredor e o trecho de cada uma. O save guarda a porta pelo índice nesta lista, e mexer na cena não pode
## trocá-lo. {building, base, shop, mirror, step}.
static func door_specs() -> Array:
	var doors: Array = []
	for index in AHStreetSet.FACADE_BUILDINGS.size():
		var building: Array = AHStreetSet.FACADE_BUILDINGS[index]
		var overlay: Rect2 = AHStreetSet.DOOR_OVERLAYS[building[1]]
		var offset: float = (overlay.position.x + overlay.size.x * 0.5 - 768.0) * AHStreetSet.FACADE_WIDTH / 1536.0
		var base: float = (building[0] + AHStreetSet.FACADE_WIDTH * 0.5 + (-offset if building[2] else offset)) * 0.01
		if base < 0.0 or base >= CORRIDOR_LENGTH:
			continue
		doors.append({"building": index, "base": base, "shop": building[1], "mirror": building[2], "step": floori(base / (CORRIDOR_LENGTH / 10.0))})
	return doors


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
	_dynamic.begin("Campfire", Vector3.ZERO)
	var fire_root := _dynamic.current()
	var texture := _dynamic.art("campfire-v1.png")
	var quad := QuadMesh.new()
	quad.size = Vector2(0.95, 0.95)
	_fire_material = ShaderMaterial.new()
	_fire_material.shader = preload("res://shaders/campfire.gdshader")
	_fire_material.set_shader_parameter("albedo_tex", texture)
	var fire := MeshInstance3D.new()
	fire.mesh = quad
	fire.material_override = _fire_material
	fire.position = ue(FIRE.x, FIRE.y, FIRE.z + 47.5)
	fire_root.add_child(fire)
	_dynamic.add_collider(ue(FIRE.x, FIRE.y, 30), Vector3(0.8, 0.6, 0.55))
	_fire_glow = _dynamic.add_glow(FIRE + Vector3(0, 10, 35), 120.0, Color(1.0, 0.5, 0.18), 2.2)
	_fire_light = _dynamic.add_light(FIRE + Vector3(0, 40, 70), 2.2, 650.0, true)
	_fire_light.light_color = Color(1.0, 0.6, 0.3)
	# A sombra da fogueira segue a qualidade, como a das luminárias (#37).
	_fire_light.add_to_group(Settings.SHADOW_LAMPS)
	_fire_light.shadow_enabled = Settings.effects().lamp_shadows

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
	fire_root.add_child(_embers)

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
	fire_root.add_child(_smoke)
	_dynamic.end(false)
	# Nos cenários a fogueira é só da rua: fica escondida e sem colisão.
	if scenario:
		for node in fire_root.get_children():
			if node is StaticBody3D:
				fire_root.remove_child(node)
				node.free()
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
		var art := {} if hero == null else AHCombatArena.art_entry(_combat_art.heroes, hero_id, String(hero.get("art_variant", "")))
		if hero == null or not hero.get("alive", true) or art.is_empty() or party_ids.size() >= 4:
			continue
		var card := AHSpriteCard.new()
		card.body_height = AHCharacterHeights.find(hero_id)
		card.show_art(art.idle)
		add_child(card)
		party_ids.append(hero_id)
		_heroes.append(card)
	_place_leader(Vector3(7.6, 0, 0.45))


## Põe o líder num ponto e a equipe enfileirada atrás dele (início e capturas).
func _place_leader(at: Vector3, facing: float = 1.0) -> void:
	at = _free_spot(at)
	_leader.position = at
	_trail.clear()
	# O rastro (onde os seguidores ficam) não sai da área de andar: na chegada a um cenário eles nasciam atrás da parede
	# ou da escada (e apareciam em silhueta, #51). Perto da ponta ele fica curto e a fila se aperta nele (_place_party);
	# o líder fica onde foi posto (mais à frente ele caía no alcance da primeira patrulha).
	for step in 80:
		_trail.append((at - Vector3(facing * 0.06 * step, 0, 0)).clamp(walk_min, walk_max))
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
		return floor_y + combat_lift
	return AHStreetSet.SIDEWALK_TOP_Z * 0.01 if z < AHStreetSet.SIDEWALK_FRONT_Y * 0.01 else 0.0


func _place_party(delta: float) -> void:
	if _arena != null and _arena.active:
		return
	# No acampamento (#77), cada um fica no seu lugar em volta da fogueira.
	if corridor != null and corridor.camp != null and corridor.camp.active:
		return
	# A fila cabe no rastro que existe: perto da ponta da área (na chegada) os espaços encolhem e abrem de novo quando
	# o líder anda.
	var spacing := PARTY_SPACING
	if _heroes.size() > 1:
		var length := 0.0
		for i in range(1, _trail.size()):
			length += _trail[i - 1].distance_to(_trail[i])
		spacing = PARTY_SPACING * clampf(length / (PARTY_SPACING * (_heroes.size() - 1)), 0.15, 1.0)
	for index in _heroes.size():
		var card := _heroes[index]
		var target := _leader.position if index == 0 else _trail_point(spacing * index)
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
		# Andando, o passo levanta a placa um pouco (a arte não tem folha de andar).
		while _bob_time.size() <= index:
			_bob_time.append(0.0)
		var moving: bool = delta > 0.0 and Vector2(x - previous.x, z - previous.z).length() > 0.2 * delta
		_bob_time[index] = _bob_time[index] + delta if moving else 0.0
		var bob := WALK_BOB * absf(sin(_bob_time[index] * WALK_BOB_STEPS * PI))
		card.position = Vector3(x, _ground_height(z) + bob, z - PARTY_DEPTH_STEP * index)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 26.0
	_camera.far = 250.0
	add_child(_camera)
	_update_camera(0.0)


func _update_camera(delta: float) -> void:
	# Teleobjetiva a ~18 m, olhando um pouco de cima (o enquadramento do Emberfall); avança um pouco nos becos.
	var leader := _leader.position
	var view_spec: Dictionary = EXPLORE_CAMERA.street
	var target := Vector3(clampf(leader.x, -6.0, 76.0), view_spec.height, clampf(-1.4 + minf(leader.z + 1.0, 0.0) * 0.45, -6.5, -1.4))
	var pitch := deg_to_rad(12.0)
	var distance: float = view_spec.distance
	if scenario and not _zone.is_empty():
		# A câmera da prévia da Unreal: 19 m de distância, 1,7 m acima do piso, quase reta (0,5°), 30° na horizontal; a
		# Ponte usa a da rua (28 m, 2,7 m). O centro vai até 4 m das pontas da zona (LaneEdgePadding).
		view_spec = EXPLORE_CAMERA.scenario
		distance = view_spec.distance
		pitch = deg_to_rad(SCENARIO_PITCH)
		_camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(SCENARIO_HALF_FOV)) / get_viewport().get_visible_rect().size.aspect()))
		var half_view: float = tan(deg_to_rad(SCENARIO_HALF_FOV)) * distance
		var low: float = _zone.x0 + minf(half_view - 4.0, (_zone.x1 - _zone.x0) * 0.5)
		var high: float = _zone.x1 - minf(half_view - 4.0, (_zone.x1 - _zone.x0) * 0.5)
		target = Vector3(clampf(leader.x, low, maxf(low, high)), floor_y + float(view_spec.height), lane_z)
	if _indoor:
		# Dentro da loja, a câmera desce para ficar abaixo do forro e enquadra a sala.
		# Vai até perto das paredes do lado (elas tapam o que fica fora da sala): na frente da sala a câmera vê só ~3,5 m
		# para cada lado, e com a folga maior a equipe saía do quadro nas pontas.
		# Com a câmera mais perto (#129), o centro fica entre o líder e o último da fila: a equipe inteira no quadro.
		var middle: float = leader.x if _heroes.is_empty() else (leader.x + _heroes[-1].position.x) * 0.5
		target = Vector3(clampf(middle, _room_x + INDOOR_CAMERA_MARGIN, _room_x + _room_width - INDOOR_CAMERA_MARGIN),
			EXPLORE_CAMERA.indoor.height, -1.2)
		pitch = deg_to_rad(4.0)
		distance = EXPLORE_CAMERA.indoor.distance
		# No acampamento (#77), a câmera fica no herói escolhido, mais perto e mais baixa (todos sentados no chão).
		if corridor != null and corridor.camp != null and corridor.camp.active:
			target = Vector3(corridor.camp.focus_x, AHCampScene.FOCUS_HEIGHT, -0.2)
			distance = AHCampScene.FOCUS_DISTANCE
	if _arena != null and _arena.active:
		# Na luta, a arena enquadra todos e se aproxima do golpe. A altura do alvo põe os pés sempre na mesma linha da
		# tela, acima do painel do HUD, qualquer que seja a distância.
		var view: Vector2 = _arena.camera_view()
		distance = view.y
		target = Vector3(view.x, floor_y + combat_lift + COMBAT_FEET_LINE * tan(deg_to_rad(_camera.fov * 0.5)) * distance / cos(pitch),
			(lane_z - 1.35) if scenario else -0.9)
	# A câmera da barra de Admin (#130): mais perto ou mais longe, na exploração e na luta.
	distance *= Admin.zoom("fight" if _arena != null and _arena.active else "explore")
	# O tremor do acerto (#33): desloca a vista sem mover a câmera (a suavização não o arrasta), em pixels da tela.
	var shake: Vector2 = _arena.camera_shake() if _arena != null and _arena.active else Vector2.ZERO
	var meters_per_pixel := 2.0 * tan(deg_to_rad(_camera.fov * 0.5)) * distance / 1080.0
	_camera.h_offset = shake.x * meters_per_pixel
	_camera.v_offset = shake.y * meters_per_pixel
	var wanted := target + Vector3(0, sin(pitch) * distance, cos(pitch) * distance)
	_camera.position = wanted if delta == 0.0 else _camera.position.lerp(wanted, 1.0 - exp(-3.0 * delta))
	_camera.look_at(Vector3(_camera.position.x, target.y, target.z))
	var ground := floor_y if scenario else 0.0
	_key_light.position = Vector3(target.x, ground + combat_lift + 2.6, (lane_z if scenario else 0.45) + 2.2)
	# Na luta num cenário, o preenchimento acende sobre quem luta (#48).
	_fill_light.visible = scenario != null and _arena != null and _arena.active
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
	# O nome do lugar, o tempo e os controles ficam no HUD da exploração; aqui só o que é de teste (F1 liga).
	_hud_weather = _label("", 20, Vector2(36, 112))
	_hud_weather.visible = false
	hud.add_child(_hud_weather)
	# O contador de quadros: no modo de captura e pela barra de Admin (#130, Ajustes).
	_hud_stats = _label("", 18, Vector2(1380, 1000))
	_hud_stats.visible = _capture_dir != ""
	hud.add_child(_hud_stats)


func _label(text: String, size: int, at: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", AHUiStyle.px(size))
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
	for light in _lamp_lights:
		light.light_energy = w.lamp_energy
	for light in _door_lights:
		light.light_energy = w.lamp_energy * 0.4
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
		scenario.set_weather(_wet if not covered else 0.0, Color(1, 1, 1) if _mood == "golden" else Color(0.55, 0.6, 0.75), covered)
	# Luz de leitura: acende de noite e na chuva, sobre a equipe e a luta.
	var readable := (1.0 if _mood == "night" else 0.0) + (0.3 if _raining else 0.0)
	_key_light.light_energy = 0.7 * clampf(readable, 0.0, 1.2)
	_fill_light.light_energy = COMBAT_FILL + COMBAT_FILL_NIGHT * clampf(readable, 0.0, 1.2)
	_hud_weather.text = (tr("Noite") if _mood == "night" else tr("Fim de tarde")) + (tr(" · chuva") if _raining else "")
	if exploration_hud:
		exploration_hud.set_weather(_hud_weather.text)
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
	for piece in _piece_materials:
		var spec: Dictionary = AHStreetSet.PIECES.get(piece, {})
		if not spec.get("wet", false):
			continue
		var material: StandardMaterial3D = _piece_materials[piece]
		material.albedo_color = spec.color.darkened(0.38 * _wet)
		material.roughness = lerpf(spec.roughness, 0.55, _wet)
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		material.metallic_specular = lerpf(0.5, 0.9, _wet)
		# Seco, sem a textura de poças (a rugosidade fica a do material).
		material.roughness_texture = material.get_meta("puddles", null) if _wet > 0.02 else null


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
			# O passo de quem vai na frente (#36: cada herói pisa de um jeito).
			var leader = Campaign.hero(party_ids[0]) if not party_ids.is_empty() else null
			Sound.footstep("concrete" if _indoor or scenario == null else Sound.surface_of(scenario.map_name), leader.class_id if leader else "")
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
		want.music = ["", "res://audio/music/explore_1.ogg", "res://audio/music/explore_2.ogg", "res://audio/music/explore_3.ogg"][track]
		if place == "RootBridge":
			want.music = "res://audio/music/explore_root_bridge.ogg"
		want.music_gain = 0.32
	if _raining:
		want.rain = "res://audio/ambience/rain_indoor.ogg" if _indoor or sheltered else "res://audio/ambience/rain_outdoor.ogg"
	return want


## Na captura, a jornada só começa depois das fotos da rua (elas passam perto das patrulhas).
func capture_paused() -> bool:
	return _capture_dir != "" and _combat_phase == 0


# ---------------------------------------------------------------- jornada (chamado pelo AHStreetCorridor)

## Onde a luta pode ficar (#52): o lugar em que se anda (a zona do cenário, a sala da casa ou a rua inteira) e, nos
## cenários, os obstáculos que cruzam a linha da luta (escada, caixote), como faixas em x.
func combat_room(_at_x: float) -> Dictionary:
	var obstacles: Array = []
	if scenario and not _indoor:
		var z0 := lane_z - 0.3 - 0.25 - 0.2
		var z1 := lane_z - 0.3 + 0.05
		for box: AABB in scenario.obstacles:
			if box.position.z <= z1 and box.end.z >= z0 and box.position.y < floor_y + 1.2:
				obstacles.append(Vector2(box.position.x - 0.3, box.end.x + 0.3))
	# O lugar inteiro, não o limite de andar da vez (que para antes da patrulha).
	var bounds := Vector2(STREET_WALK_MIN.x, STREET_WALK_MAX.x)
	if _indoor:
		bounds = Vector2(walk_min.x, walk_max.x)
	elif scenario and not _zone.is_empty():
		bounds = Vector2(_zone.x0 + 0.4, _zone.x1 - 0.4)
	return {"bounds": bounds, "obstacles": obstacles}


func begin_fight() -> void:
	_street_hud.visible = false
	_leader.velocity = Vector3.ZERO
	combat_lift = 0.0
	if scenario and not _zone.is_empty():
		combat_lift = scenario.front_lift(scenario.zones.find(_zone), lane_z - 0.3, combat_slope())


## Quanto a linha de visão da câmera da luta nos cenários sobe por metro de profundidade, a partir do pé: a altura da
## câmera sobre o chão (a linha dos pés e a inclinação de 0,5°) dividida pela distância, no limite de longe (o pior).
func combat_slope() -> float:
	return combat_slope_for(get_viewport().get_visible_rect().size.aspect())


static func combat_slope_for(aspect: float) -> float:
	var pitch := deg_to_rad(SCENARIO_PITCH)
	var fov := 2.0 * atan(tan(deg_to_rad(SCENARIO_HALF_FOV)) / aspect)
	return COMBAT_FEET_LINE * tan(fov * 0.5) / (cos(pitch) * cos(pitch)) + tan(pitch)


func end_fight() -> void:
	_street_hud.visible = true
	combat_lift = 0.0


## A formação (#129): dois heróis trocam de lugar na fila. As placas andam com a ordem, e a fila se refaz atrás do
## líder, virada para o mesmo lado.
func swap_party(a: String, b: String) -> void:
	var i := party_ids.find(a)
	var k := party_ids.find(b)
	if i < 0 or k < 0 or i == k:
		return
	var facing: float = _heroes[0].facing
	party_ids[i] = b
	party_ids[k] = a
	var card := _heroes[i]
	_heroes[i] = _heroes[k]
	_heroes[k] = card
	_place_leader(_leader.position, facing)


## Quem caiu sai da equipe até a volta (#118); os outros voltam a andar do lugar onde terminaram a luta.
func remove_dead_heroes() -> void:
	for index in range(party_ids.size() - 1, -1, -1):
		var hero = Campaign.hero(party_ids[index])
		if hero == null or not hero.alive:
			_heroes[index].queue_free()
			_heroes.remove_at(index)
			party_ids.remove_at(index)
	for index in _heroes.size():
		_heroes[index].show_art(AHCombatArena.art_entry(_combat_art.heroes, party_ids[index]).idle)
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
