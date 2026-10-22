## Estação Raiz: o refúgio entre as expedições, em corte, transcrito do AAHShelterStation da Unreal. A montagem fica em
## station_build.gd; aqui ficam a câmera (as chaves de posição, campo de visão e inclinação da Unreal), a passagem secreta
## entre a plataforma e o abrigo, o trem que chega e parte, as filas do relatório e da partida na plataforma e os
## moradores (passeio, banco da Cantina e poses de trabalho). O HUD (AHRefugeHud) cuida das telas e chama isto.
##
## Medidas em metros: X para a direita, Y para cima, Z para o fundo negativo (o corte fica em Z 0, de frente para a câmera).
class_name AHStation
extends Node3D

const S := preload("res://scripts/flow/station_rules.gd")

const STATION_END := 27.6
const CORE_X1 := 33.6
const LEFT_END := -12.4
const DOOR_X := 22.0
const PANEL_SLIDE := 3.0

## Cômodos (a tabela Rooms da Unreal, na ordem do menu): extensão em X, piso e teto e a faixa livre de passeio.
const ROOMS := [
	{"id": "characters", "x0": -0.4, "x1": 7.6, "floor": -5.2, "ceiling": -2.0, "lane": [1.1, 6.1]},
	{"id": "canteen", "x0": 15.6, "x1": STATION_END, "floor": -5.2, "ceiling": -2.0, "lane": [17.2, 25.6]},
	{"id": "bar", "x0": 7.6, "x1": 15.6, "floor": -5.2, "ceiling": -2.0, "lane": [9.1, 14.1]},
	{"id": "dormitory", "x0": -12.4, "x1": -0.4, "floor": -5.2, "ceiling": -2.0, "lane": [-10.9, -1.9]},
	{"id": "forge", "x0": 11.6, "x1": 21.6, "floor": -10.4, "ceiling": -6.2, "lane": [13.6, 19.6]},
	{"id": "depot", "x0": 5.6, "x1": 11.6, "floor": -9.4, "ceiling": -6.2, "lane": [7.2, 10.3]},
	{"id": "research", "x0": -6.4, "x1": 5.6, "floor": -9.4, "ceiling": -6.2, "lane": [-4.9, 4.1]},
	{"id": "preparation", "x0": 21.6, "x1": STATION_END, "floor": -9.4, "ceiling": -6.2, "lane": [22.9, 26.2]},
]
## Profundidade em que os moradores ficam (a faixa de passeio da Unreal, Y -330).
const LANE_Z := -3.3
## Chance de um morador dividir um cômodo já ocupado (no máximo dois).
const SHARE_ROOM_CHANCE := 0.3
## Passeio (a Unreal anda a 120 cm/s); quem desce do trem anda a 3 m/s.
const WALK_SPEED := 1.2
const TRAIN_WALK_SPEED := 3.0
## Banco atrás da mesa da Cantina: os dois lugares e a profundidade (CanteenSeats, CanteenSeatY).
const CANTEEN_SEATS := [17.6, 19.4]
const CANTEEN_SEAT_Z := -5.94
## Trabalho por sala (#80): o herói fundador, o cômodo e a pose. Só vale com o cômodo recuperado e ligado.
const WORK_POSES := {"hero_cao_bento": "forge", "hero_gato_nick": "depot", "hero_sapo_iris": "research", "hero_coruja_vespera": "research"}
## A fila do relatório e da partida na plataforma, diante da parede de serviço (ReportCenterX, ReportSpacing, ReportY).
const LINE_CENTER_X := 13.8
const LINE_SPACING := 2.1
const LINE_Z := -6.4
## O trem: entra do túnel em 3,2 s, pausa na porta até 4 s; sai fechando e acelerando (TrainSlideEnd, TrainDoorEnd).
const TRAIN_SLIDE_END := 3.2
const TRAIN_DOOR_END := 4.0
const TRAIN_OUT := -32.0
## A faixa da tela que o HUD deixa livre (na base de 1920): à direita do menu e, com um painel aberto, à esquerda dele.
const SCREEN_MENU_RIGHT := 380.0
const SCREEN_PANEL_LEFT := 1200.0

var hud: AHRefugeHud
var camera: Camera3D
var residents := {}
## Na plataforma (o relatório, o trem, a partida) ou no abrigo; a passagem secreta liga os dois.
var on_platform := false
var lineup: Array = []
var _build: AHStationBuild
var _walkers: Array = []
var _combat_art := {}
var _civilian_art := {}
var _poses := {}
var _key := {}
var _goal := {}
var _path: Array = []
var _path_time := 0.0
var _path_duration := 0.0
var _path_down := false
var _panel_open := 0.0
var _seats := {}
var _contacts: Array = []
var _wagon_base := {}
var _wagon_x := 0.0
var _door_open := 0.0
var _train_mode := 0
var _train_time := 0.0
var _warning_time := -1.0
var _candidate: AHSpriteCard
var _candidate_id := ""
var _pending_arrival := ""
var _env: Environment


func _ready() -> void:
	var campaign: Dictionary = Campaign.state
	# Quem abre a Estação no meio de uma expedição (o jogo fechou na rua) volta para a rua.
	var session: Dictionary = campaign.get("session", {})
	if session.get("expedition") != null and session.get("result", "") == "":
		set_process(false)
		GameFlow.redirect("street")
		return
	_combat_art = JSON.parse_string(FileAccess.get_file_as_string(AHCombatArena.ART_MANIFEST))
	_civilian_art = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/civilians.json"))
	_poses = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/station_poses.json"))
	_build_environment()
	var builder := AHStationBuilder.new(self)
	_build = AHStationBuild.new(builder)
	_build.build()
	# O que liga e desliga fica separado; o resto vira uma malha por material.
	var keep := {}
	for nodes in _build.dressing.values():
		for node in nodes:
			keep[node] = true
	for entry in _build.stock:
		for node in entry[1]:
			keep[node] = true
	for node in _build.wagon:
		keep[node] = true
		_wagon_base[node] = node.position
	builder.merge_static(keep)
	_build_camera()
	_build_post()
	_build_sound_loops()
	hud = AHRefugeHud.new()
	hud.station = self
	var layer := CanvasLayer.new()
	layer.layer = 2
	layer.add_child(hud)
	add_child(layer)
	_apply_panel(0.0)
	_arrive(campaign)
	refresh()


## Chegada: a volta da expedição (se o jogo fechou no relatório da rua, a entrega acontece aqui), os voluntários a
## caminho e o que espera o jogador (o relatório na plataforma, a noite, o trem).
func _arrive(campaign: Dictionary) -> void:
	if campaign.session.get("expedition") != null and campaign.session.get("result", "") != "":
		S.finish_return(campaign)
	# A partida do trem que ficou pela metade (a cena saiu antes do fim da animação).
	S.finish_departure(campaign)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	S.receive_volunteers(campaign, rng)
	Campaign.save()
	_place_residents(rng)
	if not campaign.station.last_return.is_empty() and not campaign.station.last_return.get("seen", false):
		hud.open_service("report")
	elif campaign.night.phase != "none":
		focus_overview(true)
		hud.open_room("dormitory")
	elif S.visit_pending(campaign):
		hud.open_service("train")
	else:
		focus_overview(true)


## Grava a campanha e atualiza tudo o que mostra o estado (HUD, luzes com energia, mobiliário, estoque, moradores).
func commit() -> void:
	Campaign.save()
	refresh()


func refresh() -> void:
	var campaign: Dictionary = Campaign.state
	var running := S.running_rooms(campaign)
	for room_id in _build.room_lights:
		var light: OmniLight3D = _build.room_lights[room_id]
		if not light.has_meta("energy"):
			light.set_meta("energy", light.light_energy)
		var level := S.room_level(campaign, room_id)
		# Cômodo vazio fica na penumbra; sem energia, a luz cai (as salas que gastam energia).
		var powered: bool = not [S.CANTEEN, S.RESEARCH, S.FORGE].has(room_id) or running.has(room_id)
		light.light_energy = float(light.get_meta("energy")) * ((1.0 if powered else 0.4) if level >= 1 else 0.3)
	# O mobiliário some nos cômodos vazios (nível 0: Forja, Pesquisa, Bar e Dormitório numa jornada nova).
	for room_id in _build.dressing:
		var furnished := S.room_level(campaign, room_id) >= 1
		for node in _build.dressing[room_id]:
			if is_instance_valid(node):
				node.visible = furnished
	_update_sleepers()
	# O estoque visível acompanha os suprimentos (#65): cada faixa acende uma prateleira.
	var band := S.supply_band(S.quantity(campaign, S.SUPPLIES))
	for entry in _build.stock:
		for node in entry[1]:
			if is_instance_valid(node):
				node.visible = band >= entry[0] and S.room_level(campaign, S.DEPOT) >= 1
	if hud:
		hud.refresh()


func _process(delta: float) -> void:
	_tick_camera(delta)
	if _pending_arrival != "" and _path.is_empty():
		play_train_arrival(_pending_arrival)
		_pending_arrival = ""
	_tick_train(delta)
	_walk(delta)
	if _build.ember_light:
		# Brasas: variação lenta e pequena (duas senoides fora de fase), sem piscar.
		var time := Time.get_ticks_msec() * 0.001
		if not _build.ember_light.has_meta("energy"):
			_build.ember_light.set_meta("energy", _build.ember_light.light_energy)
		_build.ember_light.light_energy = float(_build.ember_light.get_meta("energy")) * (1.0 + 0.1 * sin(time * 6.3) + 0.05 * sin(time * 14.1 + 1.3))


# ---------------------------------------------------------------- câmera

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.far = 300.0
	add_child(camera)
	_key = _overview_key()
	_goal = _key
	_apply_key(_key)


## Chave de câmera da Unreal (FCameraKey): posição em cm nos eixos de lá, FOV horizontal e inclinação (positiva olha
## para cima).
func ue_key(x: float, y: float, z: float, horizontal_fov: float, pitch: float) -> Dictionary:
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var vertical := rad_to_deg(2.0 * atan(tan(deg_to_rad(horizontal_fov * 0.5)) / aspect))
	return {"pos": AHStationBuilder.v(x, y, z), "fov": vertical, "pitch": pitch}


func _apply_key(key: Dictionary) -> void:
	camera.position = key.pos
	camera.rotation = Vector3(deg_to_rad(key.pitch), 0, 0)
	camera.fov = key.fov


static func _lerp_key(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	return {"pos": a.pos.lerp(b.pos, t), "fov": lerpf(a.fov, b.fov, t), "pitch": lerpf(a.pitch, b.pitch, t)}


func _set_goal(key: Dictionary, instant: bool = false) -> void:
	_goal = key
	if instant:
		_key = key
		_apply_key(_key)


## A câmera segue a chave com suavização (VInterpTo da Unreal); na passagem, percorre o caminho e abre o painel.
func _tick_camera(delta: float) -> void:
	if not _path.is_empty():
		_path_time += delta
		# Descendo: 1,2 s só do painel e da alavanca; depois a câmera percorre o caminho.
		var panel_phase := 1.2 if _path_down else 0.0
		var open_start := 0.0 if _path_down else 0.35
		var close_start := _path_duration - 1.0
		var opening := clampf((_path_time - open_start) / 0.9, 0.0, 1.0)
		var closing := clampf((_path_time - close_start) / 0.9, 0.0, 1.0)
		_apply_panel(opening * (1.0 - closing))
		var travel := clampf((_path_time - panel_phase) / (_path_duration - panel_phase), 0.0, 1.0)
		var segments := _path.size() - 1
		var scaled := travel * segments
		var segment := mini(floori(scaled), segments - 1)
		var alpha := smoothstep(0.0, 1.0, scaled - segment)
		_key = _lerp_key(_path[segment], _path[segment + 1], alpha)
		_apply_key(_key)
		if _path_time >= _path_duration:
			_goal = _path[-1]
			_path.clear()
			_apply_panel(0.0)
		return
	_key = _lerp_key(_key, _goal, 1.0 - exp(-5.0 * delta))
	_apply_key(_key)


## Põe a extensão x0..x1 (na profundidade depth) inteira na faixa da tela entre left_px e right_px, com o centro vertical
## em y. pitch negativo olha de cima (os cômodos); positivo, de baixo (as filas na plataforma, como a Unreal).
func _framed_key(x0: float, x1: float, y: float, left_px: float, right_px: float, fov: float = 26.0, pitch: float = -3.0,
		depth: float = -4.5) -> Dictionary:
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var half_width_per_meter := tan(deg_to_rad(fov * 0.5)) * aspect
	var share := (right_px - left_px) / 1920.0
	var distance := (x1 - x0) / (2.0 * half_width_per_meter * share * 0.94)
	var offset := ((left_px + right_px) * 0.5 - 960.0) / 1920.0 * 2.0 * half_width_per_meter * distance
	var target := Vector3((x0 + x1) * 0.5 - offset, y, depth)
	var tilt := deg_to_rad(-pitch)
	return {"pos": target + Vector3(0, sin(tilt) * distance, cos(tilt) * distance), "fov": fov, "pitch": pitch}


func _overview_key() -> Dictionary:
	return _framed_key(LEFT_END - 0.5, CORE_X1 + 0.5, -2.4, SCREEN_MENU_RIGHT, 1900.0, 26.0, -3.0, 0.0)


## A plataforma, o vagão e o fim da linha (PlatformKey da Unreal).
func _platform_key() -> Dictionary:
	return ue_key(1650, 2600, 230, 58, -3)


func focus_overview(instant: bool = false) -> void:
	_go(_overview_key(), false, instant)


## Com o HUD oculto, a Estação inteira no meio da tela (sem a faixa do menu à esquerda).
func focus_clean_overview() -> void:
	_go(_framed_key(LEFT_END - 0.5, CORE_X1 + 0.5, -2.4, 20.0, 1900.0, 26.0, -3.0, 0.0), false, false)


func focus_room(room_id: String, instant: bool = false) -> void:
	var room := room_def(room_id)
	if room.is_empty():
		return
	_go(_framed_key(room.x0 - 0.3, room.x1 + 0.3, room.floor + 1.55, SCREEN_MENU_RIGHT, SCREEN_PANEL_LEFT, 26.0, -3.0, 0.0), false, instant)


## A plataforma onde o trem para e o candidato espera.
func focus_platform(instant: bool = false) -> void:
	_go(_framed_key(1.0, 21.0, 1.8, SCREEN_MENU_RIGHT, SCREEN_PANEL_LEFT, 26.0, -3.0, 0.0), true, instant)


## O trem: a câmera sobe para a plataforma; terminada a passagem, o trem chega com o candidato (uma vez por visita) e a
## câmera fecha nele de corpo inteiro, à esquerda do painel (FocusTrainCandidate).
func open_train(candidate_id: String, arrive: bool) -> void:
	clear_lineup()
	_go(_platform_key(), true, false)
	if arrive:
		_pending_arrival = candidate_id
	else:
		show_candidate(candidate_id)
		_set_goal(_candidate_key())


func _candidate_key() -> Dictionary:
	var feet := _departure_slot(1)
	return ue_key(feet.x * 100 + 100, feet.z * 100 + 650, 92, 44, 0)


## A câmera da fila na plataforma: baixa, olhando um pouco para cima, com a fila inteira à esquerda do painel.
func _line_key(count: int) -> Dictionary:
	# A fila ocupa a faixa entre o menu e o painel de ponta a ponta (cada um com ~0,7 m de folga): os personagens grandes,
	# como o relatório da Unreal, e os cartões embaixo.
	var half := (maxi(1, count) - 1) * 0.5 * LINE_SPACING + 0.7
	return _framed_key(LINE_CENTER_X - half, LINE_CENTER_X + half, 1.0, SCREEN_MENU_RIGHT, SCREEN_PANEL_LEFT + 30.0, 40.0, 3.0, LINE_Z)


## Vai para a chave; entre a plataforma e o abrigo, pela passagem secreta (a não ser no instante inicial).
func _go(key: Dictionary, platform: bool, instant: bool) -> void:
	if platform != on_platform and not instant:
		_start_passage(not platform, key)
	else:
		_set_goal(key, instant)
	on_platform = platform


## Plataforma -> diante do painel -> porta -> antecâmara -> eixo de escadas -> abrigo (e o inverso), com o painel do
## mapa da rede abrindo e fechando atrás da equipe (StartPassage da Unreal).
func _start_passage(down: bool, final: Dictionary) -> void:
	var door := ue_key(DOOR_X * 100 + 60, 760, 150, 50, -2)
	var antechamber := ue_key(3080, 1150, 140, 56, -6)
	var core := ue_key(3080, 1350, -420, 58, -4)
	var path := [_platform_key(), door, antechamber, core, _overview_key()]
	if not down:
		path.reverse()
	path[-1] = final
	path[0] = _key
	_path = path
	_path_time = 0.0
	_path_duration = 5.2 if down else 3.6
	_path_down = down


func passage_moving() -> bool:
	return not _path.is_empty()


## O painel desliza 3 m para a esquerda, a alavanca gira e a fresta de luz some (ApplyPanel).
func _apply_panel(open: float) -> void:
	_panel_open = clampf(open, 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, _panel_open)
	if _build.panel:
		_build.panel.position.x = DOOR_X - PANEL_SLIDE * eased
	if _build.lever:
		_build.lever.basis = AHStationBuilder.basis(0, 0, -110.0 * clampf(_panel_open * 4.0, 0.0, 1.0))
	if _build.slit:
		_build.slit.visible = _panel_open < 0.02
	if _build.slit_light:
		_build.slit_light.light_energy = (8.0 if _panel_open < 0.02 else 100.0) / AHStationBuilder.LUMENS_PER_ENERGY


static func room_def(room_id: String) -> Dictionary:
	for room in ROOMS:
		if room.id == room_id:
			return room
	return {}


# ---------------------------------------------------------------- filas na plataforma

func _line_slot(index: int, count: int) -> Vector3:
	return Vector3(LINE_CENTER_X + (index - (maxi(1, count) - 1) * 0.5) * LINE_SPACING, 0, LINE_Z)


## Posição 1 (a frente) na direita, 4 na esquerda, como na tela de formação.
func _departure_slot(position: int) -> Vector3:
	return Vector3(LINE_CENTER_X + (1.5 - position) * LINE_SPACING, 0, LINE_Z)


## O relatório: os sobreviventes de pé na plataforma, a câmera baixa e próxima olhando um pouco para cima (ShowReport).
func show_report(hero_ids: Array, instant: bool = true) -> void:
	clear_lineup()
	for index in hero_ids.size():
		_line_card(hero_ids[index], _line_slot(index, hero_ids.size()))
	on_platform = true
	_path.clear()
	_apply_panel(0.0)
	_set_goal(_line_key(hero_ids.size()), instant)


## A partida: a equipe em fila (posição 1 à direita) com o contato no chão; do abrigo, sobe pela passagem (ShowDeparture).
func show_departure(front_to_back: Array) -> void:
	var first := lineup.is_empty()
	clear_lineup()
	for position in mini(4, front_to_back.size()):
		_line_card(front_to_back[position], _departure_slot(position))
	if first:
		_go(_line_key(4), true, false)


func _line_card(hero_id: String, feet: Vector3) -> void:
	var entry = S.hero(Campaign.state, hero_id)
	var art := _hero_art(entry)
	if art.is_empty():
		return
	var card := AHSpriteCard.new()
	card.body_height = AHCharacterHeights.find(hero_id)
	card.show_art(art.idle)
	add_child(card)
	card.position = feet
	card.set_facing(1.0)
	lineup.append({"hero_id": hero_id, "card": card})
	_contacts.append(_contact(feet, Vector2(0.9, 0.45)))
	# Quem está na fila não aparece ao mesmo tempo no seu cômodo.
	if residents.has(hero_id):
		residents[hero_id].visible = false


func clear_lineup() -> void:
	for entry in lineup:
		if is_instance_valid(entry.card):
			entry.card.queue_free()
		if residents.has(entry.hero_id):
			residents[entry.hero_id].visible = true
	lineup.clear()
	for contact in _contacts:
		if is_instance_valid(contact):
			contact.queue_free()
	_contacts.clear()


func _contact(feet: Vector3, size: Vector2) -> MeshInstance3D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0.45))
	gradient.set_color(1, Color(0, 0, 0, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var plane := PlaneMesh.new()
	plane.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.position = feet + Vector3(0, 0.008, 0)
	add_child(mesh)
	return mesh


## O retângulo de cada cômodo na tela (a boca do corte, do piso ao teto), para a seleção com os cantos do HUD; com a
## câmera em movimento, nada.
func room_screen_rects() -> Dictionary:
	var out := {}
	if camera == null or not _path.is_empty():
		return out
	for room in ROOMS:
		var a := Vector3(room.x0, room.floor, 0.0)
		var b := Vector3(room.x1, room.ceiling, 0.0)
		if camera.is_position_behind(a) or camera.is_position_behind(b):
			continue
		var pa := camera.unproject_position(a)
		var pb := camera.unproject_position(b)
		out[room.id] = Rect2(Vector2(minf(pa.x, pb.x), minf(pa.y, pb.y)), (pb - pa).abs())
	return out


## Onde fica, na tela, o pé de cada um da fila (o HUD põe o cartão embaixo).
func lineup_screen_positions() -> Array:
	var out: Array = []
	for entry in lineup:
		if is_instance_valid(entry.card) and not camera.is_position_behind(entry.card.position):
			out.append({"hero_id": entry.hero_id, "at": camera.unproject_position(entry.card.position)})
	return out


# ---------------------------------------------------------------- trem

## O vagão deslocado em x (m); as folhas da plataforma ainda deslizam 88 cm para os lados com a porta aberta
## (OffsetWagon e SetTrainDoorOpen da Unreal).
func _offset_wagon(x: float) -> void:
	_wagon_x = x
	var slides := {}
	for door in _build.wagon_doors:
		slides[door[0]] = door[1] * 0.88 * _door_open
	for node in _wagon_base:
		if is_instance_valid(node):
			node.position = _wagon_base[node] + Vector3(x + slides.get(node, 0.0), 0, 0)


func _set_door_open(amount: float) -> void:
	_door_open = clampf(amount, 0.0, 1.0)
	_offset_wagon(_wagon_x)


## O trem chega do túnel com o candidato: desacelera até parar, pausa na porta e o candidato desce e anda até a
## plataforma (PlayTrainArrival). O sinal vermelho pisca enquanto ele se aproxima.
func play_train_arrival(candidate_id: String) -> void:
	Sound.play("res://audio/station/train_arrival.ogg", 0.9)
	_remove_candidate()
	_candidate_id = candidate_id
	_train_mode = 1
	_train_time = 0.0
	_warning_time = 0.0
	_door_open = 0.0
	_offset_wagon(TRAIN_OUT)


## Fecha e acelera para o túnel; fica fora até a próxima chegada. Recusado, o candidato vai junto (PlayTrainDeparture).
func play_train_departure(candidate_leaves: bool) -> void:
	Sound.play("res://audio/station/train_departure.ogg", 0.9)
	_warning_time = -1.0
	if candidate_leaves:
		_remove_candidate()
	_train_mode = 2
	_train_time = 0.0
	_offset_wagon(0.0)


## A trilha do refúgio (Contemplation, a mesma da exploração) por baixo dos loops da Estação; sem chuva nem ambiente
## de cenário: a Estação é subterrânea.
func soundscape() -> Dictionary:
	return {"music": "res://audio/music/explore_3.ogg", "music_gain": 0.26, "ambience": "res://audio/station/hum_loop.ogg",
		"ambience_gain": 0.45}


## Os loops com lugar (FAHAudio::Loop espacial): o ventilador do Bar e a lâmpada tubular do Depósito.
func _build_sound_loops() -> void:
	for spec in [["bar", "res://audio/station/bar_fan_loop.ogg", -2.0], ["depot", "res://audio/station/depot_tube_loop.ogg", -6.0]]:
		var room: Dictionary = ROOMS.filter(func(r): return r.id == spec[0])[0]
		var player := AudioStreamPlayer3D.new()
		var stream: AudioStream = load(spec[1])
		stream.loop = true
		player.stream = stream
		player.bus = "Ambience"
		player.volume_db = spec[2]
		player.unit_size = 9.0
		player.max_distance = 60.0
		player.position = Vector3((room.x0 + room.x1) * 0.5, room.ceiling - 0.4, LANE_Z)
		player.autoplay = true
		add_child(player)


func train_busy() -> bool:
	return _train_mode != 0


## O candidato esperando na plataforma, sem a chegada (o jogo foi reaberto com o trem parado).
func show_candidate(candidate_id: String) -> void:
	if is_instance_valid(_candidate) and _candidate_id == candidate_id:
		return
	_remove_candidate()
	_candidate_id = candidate_id
	_spawn_candidate(_departure_slot(1))
	_offset_wagon(0.0)


func clear_candidate() -> void:
	_remove_candidate()
	_candidate_id = ""


func _remove_candidate() -> void:
	if is_instance_valid(_candidate):
		_candidate.queue_free()
	_candidate = null
	_walkers = _walkers.filter(func(w): return is_instance_valid(w.card))


func _spawn_candidate(feet: Vector3) -> AHSpriteCard:
	var art: Dictionary = _civilian_art.get(_candidate_id, {})
	if art.is_empty():
		return null
	_candidate = AHSpriteCard.new()
	_candidate.body_height = AHCharacterHeights.find(_candidate_id)
	_candidate.show_art(art)
	add_child(_candidate)
	_candidate.position = feet
	_candidate.set_facing(1.0)
	return _candidate


func _tick_train(delta: float) -> void:
	if _warning_time >= 0.0:
		_warning_time += delta
	var approaching := _warning_time >= 0.0
	var bright := not approaching or fmod(_warning_time, 0.8) < 0.4
	if _build.signal_light:
		_build.signal_light.light_energy = (90.0 if bright else 9.0) / AHStationBuilder.LUMENS_PER_ENERGY
	if _build.signal_glow:
		_build.signal_glow.visible = bright
	if _train_mode == 0:
		return
	var before := _train_time
	_train_time += delta
	if _train_mode == 2:
		# Fecha primeiro; depois acelera para o túnel.
		_door_open = clampf(1.0 - _train_time / 0.55, 0.0, 1.0)
		var alpha := clampf((_train_time - 0.55) / 2.6, 0.0, 1.0)
		_offset_wagon(-36.0 * alpha * alpha)
		if _train_time >= 3.75:
			_train_mode = 0
		return
	if _train_time >= TRAIN_SLIDE_END:
		_warning_time = -1.0
	var slide := clampf(_train_time / TRAIN_SLIDE_END, 0.0, 1.0)
	_door_open = clampf((_train_time - TRAIN_SLIDE_END) / (TRAIN_DOOR_END - TRAIN_SLIDE_END), 0.0, 1.0)
	_offset_wagon(TRAIN_OUT * (1.0 - slide) * (1.0 - slide))
	var target := _departure_slot(1)
	if before < TRAIN_DOOR_END and _train_time >= TRAIN_DOOR_END:
		# Desce pela porta do metrô (sem o modelo, 3,3 m antes do lugar dele) e anda até a plataforma.
		var door := Vector3(_build.train_exit_x, target.y, target.z) if not is_nan(_build.train_exit_x) else target - Vector3(3.3, 0, 0)
		var card := _spawn_candidate(door)
		if card:
			_walkers.append({"card": card, "min": target.x, "max": target.x, "target": target.x, "wait": 0.0, "phase": 0.0,
				"speed": TRAIN_WALK_SPEED, "stay": true, "home_z": target.z})
	if _train_time >= TRAIN_DOOR_END and (not is_instance_valid(_candidate) or absf(_candidate.position.x - target.x) < 0.05):
		_train_mode = 0
		_set_goal(_candidate_key())


# ---------------------------------------------------------------- moradores

## Os quatro lugares dos beliches (m): de baixo à esquerda, de baixo à direita, e os de cima.
static func sleep_slots() -> Array:
	var out: Array = []
	for tier in 2:
		for x in AHStationBuild.BUNK_X:
			# Um pouco para a cabeceira (o travesseiro fica à esquerda) e à frente da cama pintada.
			out.append(AHStationBuilder.vu(Vector3(x - 12.0, AHStationBuild.BUNK_Y + 30.0,
				AHStationBuild.BUNK_FLOOR + tier * AHStationBuild.BUNK_UPPER + AHStationBuild.MATTRESS_TOP)))
	return out


## Quem dorme esta noite: os participantes vivos da noite por resolver, menos o vigia (S.night_preview).
static func sleepers(campaign: Dictionary) -> Array:
	if campaign.night.phase != "planning":
		return []
	return S.night_preview(campaign).heroes.filter(func(row): return not row.watch).map(func(row): return row.hero_id)


## À noite, quem dorme deita no beliche (a pose de dormir aprovada pelo Lucas); o vigia fica de pé no Dormitório. Com a
## noite resolvida, todos voltam a passear.
func _update_sleepers() -> void:
	var campaign: Dictionary = Campaign.state
	var asleep := sleepers(campaign)
	var slots := sleep_slots()
	var watch: String = campaign.night.watch_hero_id if campaign.night.phase == "planning" else ""
	var dorm := room_def(S.DORMITORY)
	for walker in _walkers:
		if not walker.has("hero_id") or not is_instance_valid(walker.card):
			continue
		var card: AHSpriteCard = walker.card
		# Cada um tem o seu lugar pela ordem na equipe: trocar o vigia não muda os outros de cama.
		var slot: int = campaign.night.participants.find(walker.hero_id) if asleep.has(walker.hero_id) else -1
		if slot >= 0 and slot < slots.size() and _poses.has(walker.hero_id + "_sleep"):
			walker.sleeping = true
			card.show_art(_poses[walker.hero_id + "_sleep"])
			card.position = slots[slot]
			card.set_facing(1.0)
			card.scale = Vector3.ONE
			continue
		if walker.get("sleeping", false):
			walker.sleeping = false
			card.show_art(walker.idle)
			card.position = Vector3(walker.target, walker.floor, walker.home_z)
		if walker.hero_id == watch and walker.room != S.DORMITORY:
			# O vigia vai para o Dormitório e fica perto da porta.
			walker.room = S.DORMITORY
			walker.min = dorm.lane[1] - 2.0
			walker.max = dorm.lane[1]
			walker.floor = dorm.floor
			walker.target = walker.max
			card.position = Vector3(walker.max, dorm.floor, walker.home_z)
			card.show_art(walker.idle)
			card.scale = Vector3.ONE



## Cada herói vivo num cômodo sorteado (30% de chance de dividir um já ocupado, no máximo dois), passeando pela faixa
## do cômodo; os civis ficam no cômodo deles, alternando o idle e a pose de trabalho.
func _place_residents(rng: RandomNumberGenerator) -> void:
	for card in residents.values():
		card.queue_free()
	residents.clear()
	_walkers.clear()
	_seats.clear()
	var campaign: Dictionary = Campaign.state
	var occupancy := {}
	var free_rooms: Array = ROOMS.map(func(r): return r.id)
	for entry in S.living(campaign):
		var art := _hero_art(entry)
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
		var occupants: int = occupancy[room_id]
		var half: float = (lane[1] - lane[0]) * 0.5
		# O segundo morador do cômodo passeia na metade da direita da faixa.
		var lane_min: float = lane[0] if occupants == 1 else lane[0] + half
		var lane_max: float = lane[1]
		card.position = Vector3(rng.randf_range(lane_min, lane_max), room.floor, LANE_Z + rng.randf_range(-0.3, 0.3))
		card.set_facing(1.0 if rng.randf() < 0.5 else -1.0)
		residents[entry.id] = card
		var walker := {"card": card, "min": lane_min, "max": lane_max, "target": card.position.x, "wait": rng.randf_range(0.5, 4.0),
			"phase": rng.randf() * TAU, "room": room_id, "idle": art.idle, "hero_id": entry.id, "home_z": card.position.z,
			"floor": room.floor, "seat": -1, "sitting": 0.0, "work": WORK_POSES.get(entry.id, "") == room_id and _poses.has(entry.id + "_work"),
			"working": 0.0, "pause": rng.randf_range(1.0, 4.0)}
		_walkers.append(walker)
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
		# Civil morador: alterna o idle e a pose de trabalho, parado no posto dele.
		_walkers.append({"card": card, "civilian": civilian_id, "idle": art, "civil_timer": rng.randf_range(3.0, 7.0), "civil_working": false})
	# Refeitos os passeios (depois do trem, por exemplo), quem dorme volta para o beliche.
	_update_sleepers()


## A arte do herói (recrutas novos usam a do fundador da mesma classe).
func _hero_art(entry) -> Dictionary:
	return {} if entry == null else AHCombatArena.art_entry(_combat_art.heroes, entry.id, String(entry.get("art_variant", "")))


func civilian_art(civilian_id: String) -> Dictionary:
	return _civilian_art.get(civilian_id, {})


## O passeio e o lobby vivo: anda a 1,2 m/s até um ponto da faixa (virado para onde anda, com um balanço de passo),
## descansa e escolhe outro; na Cantina às vezes senta no banco; quem tem pose de trabalho na sala alterna trabalho e
## pausa (só com a sala recuperada e ligada); os civis alternam o idle e o trabalho.
func _walk(delta: float) -> void:
	var time := Time.get_ticks_msec() * 0.001
	var running := S.running_rooms(Campaign.state)
	# Cartas liberadas (o candidato que embarcou, moradores refeitos) saem da lista antes de qualquer acesso.
	_walkers = _walkers.filter(func(w): return is_instance_valid(w.card))
	for walker in _walkers:
		var card: AHSpriteCard = walker.card
		if not card.visible or walker.get("sleeping", false):
			continue
		if walker.has("civilian"):
			walker.civil_timer -= delta
			if walker.civil_timer <= 0.0:
				walker.civil_working = not walker.civil_working
				var work: Dictionary = _poses.get(walker.civilian + "_work", {})
				card.show_art(work if walker.civil_working and not work.is_empty() else walker.idle)
				walker.civil_timer = randf_range(6.0, 10.0) if walker.civil_working else randf_range(4.0, 7.0)
			continue
		# Sentado no banco da Cantina: fica um pouco e levanta.
		if walker.get("sitting", 0.0) > 0.0:
			walker.sitting -= delta
			if walker.sitting <= 0.0:
				_stand_up(walker)
			continue
		# Pose de trabalho na sala (Forja, Depósito, Pesquisa), no posto do meio da faixa.
		if walker.get("work", false):
			var room_on: bool = S.room_level(Campaign.state, walker.room) >= 1 and (not [S.FORGE, S.RESEARCH].has(walker.room) or running.has(walker.room))
			if room_on:
				if walker.working > 0.0:
					walker.working -= delta
					if walker.working <= 0.0:
						card.show_art(walker.idle)
						card.position.z = walker.home_z
						walker.pause = randf_range(4.0, 10.0)
					continue
				walker.pause -= delta
				if walker.pause <= 0.0 and walker.wait > 0.0:
					card.show_art(_poses[walker.hero_id + "_work"])
					card.position = Vector3((walker.min + walker.max) * 0.5, walker.floor, -5.6)
					card.set_facing(1.0)
					card.scale = Vector3.ONE
					walker.working = randf_range(12.0, 26.0)
					continue
		if walker.wait > 0.0:
			walker.wait -= delta
			card.scale = Vector3(1, 1.0 + 0.012 * sin(time * 2.2 + walker.phase), 1)
			if walker.wait <= 0.0:
				_choose_target(walker)
			continue
		var gap: float = walker.target - card.position.x
		var speed: float = walker.get("speed", WALK_SPEED)
		if absf(gap) < 0.05:
			card.scale = Vector3.ONE
			if walker.get("stay", false):
				walker.wait = INF
				continue
			if walker.get("seat", -1) >= 0:
				_sit_down(walker)
				continue
			walker.wait = randf_range(2.5, 7.0)
			continue
		card.set_facing(signf(gap))
		card.position.x += signf(gap) * minf(absf(gap), speed * delta)
		card.scale = Vector3(1, 1.0 + 0.025 * absf(sin(time * 7.0 + walker.phase)), 1)


func _choose_target(walker: Dictionary) -> void:
	var card: AHSpriteCard = walker.card
	# Pelo menos 1 m de caminhada; perto de uma ponta, vai para a outra.
	var target := randf_range(walker.min, walker.max)
	if absf(target - card.position.x) < 1.0:
		target = walker.min if card.position.x > (walker.min + walker.max) * 0.5 else walker.max
	# Na Cantina, às vezes vai sentar no banco livre atrás da mesa (só os fundadores têm a pose sentada).
	if walker.get("room", "") == "canteen" and _poses.has(walker.hero_id + "_seat") and randf() < 0.45:
		for seat in CANTEEN_SEATS.size():
			if not _seats.has(seat):
				_seats[seat] = walker
				walker.seat = seat
				target = CANTEEN_SEATS[seat]
				break
	walker.target = target


func _sit_down(walker: Dictionary) -> void:
	var card: AHSpriteCard = walker.card
	card.show_art(_poses[walker.hero_id + "_seat"])
	card.position = Vector3(CANTEEN_SEATS[walker.seat], walker.floor, CANTEEN_SEAT_Z)
	card.set_facing(1.0)
	walker.sitting = randf_range(6.0, 11.0)


func _stand_up(walker: Dictionary) -> void:
	var card: AHSpriteCard = walker.card
	_seats.erase(walker.seat)
	walker.seat = -1
	card.show_art(walker.idle)
	card.position.z = walker.home_z
	walker.wait = randf_range(2.0, 5.0)


# ---------------------------------------------------------------- ambiente

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.028, 0.026)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.45)
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 5.0
	# Exposição fixa, como a câmera da Estação na Unreal (não herda o ajuste da rua).
	env.tonemap_exposure = 1.25
	env.glow_enabled = true
	env.glow_strength = 0.9
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.04
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		env.ssao_enabled = Settings.effects().ssao
		env.ssao_radius = 0.9
		env.ssao_intensity = 1.4
		# A oclusão acompanha a qualidade das opções (Settings). Pelo método do nó: a conexão sai junto com a cena (uma
		# lambda que só usa env não é do nó e ficava conectada a cada visita à Estação).
		_env = env
		Settings.changed.connect(_on_settings_changed)
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	# Preenchimento suave de frente (a luz retangular de 70 m da Unreal): só mostra a seção, sem sombra.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-6, 0, 0)
	fill.light_color = Color(0.78, 0.84, 0.95)
	fill.light_energy = 0.28
	fill.shadow_enabled = false
	add_child(fill)


func _on_settings_changed() -> void:
	_env.ssao_enabled = Settings.effects().ssao


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
