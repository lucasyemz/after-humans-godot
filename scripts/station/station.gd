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
	{"id": "infirmary", "x0": -12.4, "x1": -6.4, "floor": -9.4, "ceiling": -6.2, "lane": [-11.2, -7.6]},
]
## Profundidade em que os moradores ficam (a faixa de passeio da Unreal, Y -330).
const LANE_Z := -3.3
## Chance de um morador dividir um cômodo já ocupado (no máximo dois).
const SHARE_ROOM_CHANCE := 0.3
## Passeio (a Unreal anda a 120 cm/s); quem desce do trem anda a 3 m/s.
const WALK_SPEED := 1.2
const TRAIN_WALK_SPEED := 3.0
## Distância mínima entre quem para na mesma faixa: ninguém para em cima do outro.
const STOP_GAP := 1.1
## Quantas vezes quem chega num ponto cheio procura outro antes de parar mesmo assim (a faixa sem lugar nenhum).
const REROUTE_LIMIT := 12
## Banco atrás da mesa da Cantina: os dois lugares e a profundidade (CanteenSeats, CanteenSeatY).
const CANTEEN_SEATS := [17.6, 19.4]
const CANTEEN_SEAT_Z := -5.94
## Trabalho por sala (#80): o herói fundador, o cômodo e a pose. Só vale com o cômodo recuperado e ligado.
const WORK_POSES := {"hero_cao_bento": "forge", "hero_gato_nick": "depot", "hero_sapo_iris": "research", "hero_coruja_vespera": "research"}
## A fila do relatório e da partida na plataforma, diante da parede de serviço (ReportCenterX, ReportSpacing, ReportY).
const LINE_CENTER_X := 13.8
const LINE_SPACING := 2.1
const LINE_Z := -6.4
## O segundo do trem (#182) espera a esta distância do primeiro (m).
const COMPANION_GAP := 1.4
## O relatório no kit (#60): os centros das cartas dos heróis a 416 px um do outro, e os pés da fila logo acima delas.
const REPORT_CARD_STEP := 416.0
const REPORT_FEET_Y := 634.0
## Na fila do relatório, um pouco mais afastados que na partida: a câmera recua e os heróis cabem entre a faixa do alto
## (que cresce no texto Maior) e as abas das cartas.
const REPORT_SPACING := 2.6
## A Sala dos Personagens no kit (#60): o teto e o piso do cômodo na tela.
const STAGE_TOP := 112.0
const STAGE_FLOOR := 900.0
## O trem (#61), na ordem da cena: o aviso (o sinal pisca e o sino toca) por TRAIN_WARNING s; o trem entra do túnel
## freando em 3,2 s (TrainSlideEnd da Unreal) e para em TRAIN_STOP; as portas abrem de TRAIN_DOOR_START a TRAIN_DOOR_END;
## o candidato desce e anda; só então a câmera fecha nele. Na saída: o recusado volta ao trem, o sino avisa, as portas
## fecham em TRAIN_CLOSE s e o trem acelera para o túnel em TRAIN_LEAVE s com o som da partida.
const TRAIN_WARNING := 0.8
const TRAIN_STOP := TRAIN_WARNING + 3.2
const TRAIN_DOOR_START := TRAIN_STOP + 0.25
const TRAIN_DOOR_END := TRAIN_DOOR_START + 0.8
const TRAIN_CLOSE := 0.55
const TRAIN_LEAVE := 2.6
const TRAIN_OUT := -32.0
## A volta da equipe (#76): o intervalo entre quem desce, o passo de quem está ferido e quanto o trem vazio espera.
const TEAM_STEP_OUT := 0.45
const WOUNDED_PACE := 0.55
const EMPTY_WAIT := 1.2
## Depois do relatório, a fila sai andando para a direita (#131): um de cada vez, a frente primeiro, e cada um só volta
## ao seu cômodo depois de sair da câmera.
const LEAVE_STEP := 0.35
const LEAVE_SPEED := 2.4
## O HUD segura a câmera na plataforma no máximo este tempo enquanto a fila sai.
const LEAVE_HOLD := 2.5
## A câmera da vista geral anda para os lados (#131): o deslocamento em metros, nos limites (na distância da vista geral,
## cerca de 330 px para cada lado: as pontas da Estação chegam perto do meio da tela).
const PAN_RANGE := Vector2(-12.0, 13.0)
## Ao escolher um cômodo, a câmera aproxima: as paredes do lado saem um pouco do quadro (m).
const ROOM_CROP := 0.6
## A distância mínima (m) de quem desce atrás para quem vai na frente.
const FOLLOW_GAP := 1.0
## Quanto antes de parar o freio começa (s).
const BRAKE_LEAD := 1.6
## A faixa da tela que o HUD deixa livre (na base de 1920): à direita do menu e, com um painel aberto, à esquerda dele.
const SCREEN_MENU_RIGHT := 380.0
const SCREEN_PANEL_LEFT := 1200.0

var hud: AHRefugeHud
## Onde termina, na tela, o menu da esquerda da vista geral (o HUD mede: cresce com o texto Maior e o inglês). A vista
## geral enquadra a Estação à direita dele, para nenhum cômodo (o Dormitório da ponta) ficar embaixo do menu (#76).
var menu_right := SCREEN_MENU_RIGHT
var camera: Camera3D
var residents := {}
## Os moradores escondidos por uma tela do kit (hide_residents).
var _residents_hidden := false
## Na plataforma (o relatório, o trem, a partida) ou no abrigo; a passagem secreta liga os dois.
var on_platform := false
var lineup: Array = []
## Quem sai da plataforma depois do relatório (#131): {hero_id, card, delay, speed}.
var _leaving: Array = []
## Enquanto a fila sai, a câmera fica na plataforma (até LEAVE_HOLD): a ida para baixo pedida nesse meio espera aqui.
var _held_go: Array = []
## O pedido que espera é o da vista geral (refeito com o menu de agora quando sai), não outro enquadramento.
var _held_overview := false
var _asking_overview := false
var _hold_until := 0
## O deslocamento da vista geral (m) e se a câmera está nela (só ali ele vale).
var pan := 0.0
var _in_overview := true
var _build: AHStationBuild
var _walkers: Array = []
var occlusion: AHOcclusion
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
## 0 parado, 1 chegando, 2 partindo, 3 o recusado voltando para o trem antes da partida.
var _train_mode := 0
var _train_time := 0.0
## Os passos da cena do trem, na ordem em que acontecem (o teste e a gravação conferem a ordem): warning, brake, stop,
## doors_open, candidate_out, candidate_ready, camera_on_candidate; boarding, boarded, doors_closing, doors_closed,
## leaving, gone. O camera_on_candidate vem também quando o painel do trem, reaberto depois da cena, termina de levar a
## câmera ao candidato; e não vem se o jogador saiu para outro painel no meio (a cena acaba sem a câmera).
signal train_event(name: String)
var _warning_time := -1.0
var _candidate: AHSpriteCard
## O segundo que desceu do trem (#182), à espera da vez dele.
var _companion: AHSpriteCard
var _candidate_id := ""
var _pending_arrival := ""
## O som do trem que está tocando (esmaece na parada e quando o trem some, #61).
var _train_sound: AudioStreamPlayer = null
## A chegada terminou com o candidato no lugar; falta a câmera fechar nele (só com o painel do trem e na plataforma).
var _camera_pending := false
## O painel do trem reaberto depois da cena: a câmera vai ao candidato (pela passagem, se preciso) antes de o painel abrir.
var _reopen_pending := false
var _env: Environment
## O pós da Estação (o perfil de ambiência, reaplicado quando a qualidade muda).
var _post: ShaderMaterial
## Quem desce do trem na volta: {hero_id, art, slot, delay, speed, card, hurt}.
var _arrivals: Array = []
## O trem da volta fechando e indo embora depois de a equipe descer (não conta como cena do trem ocupada).
var _team_train_leaving := false


func _ready() -> void:
	night_scene = false
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
	# A silhueta dos heróis atrás do mobiliário e o esmaecimento do que tapa (#51).
	occlusion = AHOcclusion.new()
	occlusion.name = "Occlusion"
	add_child(occlusion)
	occlusion.scan(self)
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
		# A equipe chega de trem e desce; depois, o relatório (#76).
		hud.play_arrival()
	elif campaign.night.phase != "none":
		# A noite pendente: a vista geral com o Dormitório em destaque e a Preparação bloqueada (#76), como depois do
		# relatório.
		focus_overview(true)
	elif S.visit_pending(campaign):
		hud.open_service("train")
	else:
		focus_overview(true)


## A noite passando (#132): as luzes dos cômodos caem até este fator e voltam de manhã.
var night_dim := 1.0


func set_night_dim(value: float) -> void:
	night_dim = clampf(value, 0.0, 1.0)
	var running := S.running_rooms(Campaign.state)
	for room_id in _build.room_lights:
		var light: OmniLight3D = _build.room_lights[room_id]
		if not light.has_meta("energy"):
			light.set_meta("energy", light.light_energy)
		var powered: bool = not [S.CANTEEN, S.RESEARCH, S.FORGE].has(room_id) or running.has(room_id)
		light.light_energy = float(light.get_meta("energy")) * ((1.0 if powered else 0.4) if S.room_level(Campaign.state, room_id) >= 1 else 0.3) * night_dim


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
		light.light_energy = float(light.get_meta("energy")) * ((1.0 if powered else 0.4) if level >= 1 else 0.3) * night_dim
	# O mobiliário some nos cômodos vazios (nível 0: Forja, Pesquisa, Bar e Dormitório numa jornada nova).
	for room_id in _build.dressing:
		# "infirmary@2": a peça que só aparece no nível 2.
		var parts: PackedStringArray = String(room_id).split("@")
		var furnished := S.room_level(campaign, parts[0]) >= (int(parts[1]) if parts.size() > 1 else 1)
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
	# O candidato chega depois de o trem da volta sair de vista (senão o vagão pulava para o túnel).
	if _pending_arrival != "" and _path.is_empty() and not _team_train_leaving:
		play_train_arrival(_pending_arrival)
		_pending_arrival = ""
	_tick_train(delta)
	if _reopen_pending:
		_tick_reopen()
	_walk(delta)
	_tick_leaving(delta)
	if not _held_go.is_empty() and (not lineup_leaving() or Time.get_ticks_msec() >= _hold_until):
		var held := _held_go
		var overview := _held_overview
		_hold_until = 0
		# A vista geral pedida durante a espera sai com o menu de agora (a largura dele pode ter mudado no meio); outro
		# enquadramento (a Estação inteira, com o HUD oculto) sai como foi pedido.
		_go(_overview_key() if overview else held[0], held[1], held[2])
		_in_overview = overview
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
	# A câmera da barra de Admin (#130): o campo de visão mais fechado ou mais aberto.
	camera.fov = clampf(key.fov * Admin.zoom("station"), 5.0, 120.0)


static func _lerp_key(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	return {"pos": a.pos.lerp(b.pos, t), "fov": lerpf(a.fov, b.fov, t), "pitch": lerpf(a.pitch, b.pitch, t)}


func _set_goal(key: Dictionary, instant: bool = false) -> void:
	_goal = key
	# No meio da passagem, a chave nova vira o fim do caminho (senão a passagem, ao terminar, voltava à de antes).
	if not _path.is_empty() and not instant:
		_path[-1] = key
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
	var key := _framed_key(LEFT_END - 0.5, CORE_X1 + 0.5, -2.4, menu_right, 1900.0, 26.0, -3.0, 0.0)
	key.pos.x += pan
	return key


## Anda a vista geral para os lados (#131), dentro de PAN_RANGE; fora da vista geral, só guarda.
func set_pan(value: float) -> void:
	pan = clampf(value, PAN_RANGE.x, PAN_RANGE.y)
	if _in_overview and not on_platform and _path.is_empty():
		_set_goal(_overview_key())


## Quantos pixels da tela um metro ocupa no plano dos cômodos, na vista geral (para arrastar com o mouse).
func overview_pixels_per_meter() -> float:
	var key := _overview_key()
	var distance: float = key.pos.z
	var aspect := get_viewport().get_visible_rect().size.aspect()
	return 1920.0 / (2.0 * tan(deg_to_rad(key.fov * 0.5)) * aspect * distance)


## A vista geral anda até o cômodo ficar inteiro na faixa da tela entre left_px e right_px (as setas escolhendo um
## cômodo que o menu cobre).
func pan_to_room(room_id: String, left_px: float, right_px: float) -> void:
	var room := room_def(room_id)
	if room.is_empty():
		return
	var ppm := overview_pixels_per_meter()
	var key := _overview_key()
	var center_x: float = key.pos.x
	var screen_x0: float = 960.0 + (room.x0 - center_x) * ppm
	var screen_x1: float = 960.0 + (room.x1 - center_x) * ppm
	if screen_x0 < left_px:
		set_pan(pan + (screen_x0 - left_px) / ppm)
	elif screen_x1 > right_px:
		set_pan(pan + (screen_x1 - right_px) / ppm)


## A plataforma, o vagão e o fim da linha (PlatformKey da Unreal).
func _platform_key() -> Dictionary:
	return ue_key(1650, 2600, 230, 58, -3)


func focus_overview(instant: bool = false) -> void:
	_asking_overview = true
	_go(_overview_key(), false, instant)
	_asking_overview = false
	_in_overview = true


## O menu da esquerda mudou de largura (o HUD chama só na vista geral): a vista geral de agora, ou a do fim da
## passagem descendo da plataforma, reenquadra.
func refit_overview() -> void:
	if on_platform:
		return
	if not _path.is_empty():
		if _path_down:
			_path[-1] = _overview_key()
		return
	if _in_overview:
		_set_goal(_overview_key())


## Com o HUD oculto, a Estação inteira no meio da tela (sem a faixa do menu à esquerda).
func focus_clean_overview() -> void:
	_go(_framed_key(LEFT_END - 0.5, CORE_X1 + 0.5, -2.4, 20.0, 1900.0, 26.0, -3.0, 0.0), false, false)


func focus_room(room_id: String, instant: bool = false) -> void:
	var room := room_def(room_id)
	if room.is_empty():
		return
	# Mais perto que a vista do cômodo inteiro (#131): as paredes do lado saem um pouco do quadro.
	_in_overview = false
	_go(_framed_key(room.x0 + ROOM_CROP, room.x1 - ROOM_CROP, room.floor + 1.55, SCREEN_MENU_RIGHT, SCREEN_PANEL_LEFT, 26.0, -3.0, 0.0), false, instant)


## O cômodo entre os dois painéis de uma tela do kit (a Sala dos Personagens, #60): a câmera fecha na altura do
## cômodo (do teto em STAGE_TOP ao piso em STAGE_FLOOR, na tela), então o fundo atrás do herói é só o próprio cômodo,
## sem a plataforma e o trem em cima nem o andar de baixo.
func focus_room_stage(room_id: String, left_px: float, right_px: float, instant: bool = false) -> void:
	var room := room_def(room_id)
	if room.is_empty():
		return
	var fov := 26.0
	var pitch := -3.0
	var focal := 540.0 / tan(deg_to_rad(fov * 0.5))
	var depth: float = focal * (room.ceiling - room.floor) / (STAGE_FLOOR - STAGE_TOP)
	var drop := atan((STAGE_FLOOR - 540.0) / focal) + deg_to_rad(-pitch)
	var x: float = (room.x0 + room.x1) * 0.5 - ((left_px + right_px) * 0.5 - 960.0) * depth / focal
	_go({"pos": Vector3(x, room.floor + depth * tan(drop), depth), "fov": fov, "pitch": pitch}, false, instant)


## A câmera chegou aonde ia (sem caminho pela passagem e perto da chave).
func camera_settled() -> bool:
	return _path.is_empty() and not _goal.is_empty() and _key.pos.distance_to(_goal.pos) < 0.02


## Todos os moradores (heróis e civis) somem enquanto uma tela do kit cobre a Estação: nenhum aparece no vão entre os
## painéis nem numa lasca na borda deles.
func hide_residents(hidden: bool) -> void:
	_residents_hidden = hidden
	# Quem está na fila da plataforma ou saindo dela (#131) não aparece no cômodo ao mesmo tempo.
	var away: Array = lineup.map(func(e): return e.hero_id) + _leaving.map(func(e): return e.hero_id)
	for id in residents:
		var card = residents[id]
		if is_instance_valid(card):
			card.visible = not hidden and not away.has(id)


## A plataforma onde o trem para e o candidato espera.
func focus_platform(instant: bool = false) -> void:
	_go(_framed_key(1.0, 21.0, 1.8, SCREEN_MENU_RIGHT, SCREEN_PANEL_LEFT, 26.0, -3.0, 0.0), true, instant)


## O trem: a câmera sobe para a plataforma; terminada a passagem, o trem chega com o candidato (uma vez por visita) e a
## câmera fecha nele de corpo inteiro, à esquerda do painel (FocusTrainCandidate).
func open_train(candidate_id: String, arrive: bool) -> void:
	clear_lineup()
	if arrive:
		_go(_platform_key(), true, false)
		_pending_arrival = candidate_id
		# O trem ainda não chegou: fica no túnel, sem ninguém na plataforma (aparecia parado e sumia para chegar).
		_remove_candidate()
		_door_open = 0.0
		_offset_wagon(TRAIN_OUT)
	else:
		# A passagem termina no candidato (terminava na plataforma inteira e descartava a chave dele).
		show_candidate(candidate_id)
		_go(_candidate_key(), true, false)
		_reopen_pending = true


## O painel do trem reaberto no meio da cena: a câmera volta para a plataforma (pela passagem, se preciso).
func follow_train() -> void:
	clear_lineup()
	_go(_candidate_key() if _reopen_pending else _platform_key(), true, false)


func _candidate_key() -> Dictionary:
	var feet := _departure_slot(1)
	# Desceram dois (#182): a câmera recua para o segundo, ao lado, também caber à esquerda do painel.
	if not Campaign.state.station.train.get("next", {}).is_empty():
		return ue_key(feet.x * 100 + 20, feet.z * 100 + 800, 92, 44, 0)
	return ue_key(feet.x * 100 + 100, feet.z * 100 + 650, 92, 44, 0)


## Onde o segundo do trem espera: ao lado do primeiro, um pouco atrás.
func _companion_slot() -> Vector3:
	return _departure_slot(1) + Vector3(-COMPANION_GAP, 0, -0.3)


## A câmera da fila na plataforma: baixa, olhando um pouco para cima, com a fila inteira à esquerda do painel.
func _line_key(count: int) -> Dictionary:
	# A fila ocupa a faixa entre o menu e o painel de ponta a ponta (cada um com ~0,7 m de folga): os personagens grandes,
	# como o relatório da Unreal, e os cartões embaixo.
	var half := (maxi(1, count) - 1) * 0.5 * LINE_SPACING + 0.7
	return _framed_key(LINE_CENTER_X - half, LINE_CENTER_X + half, 1.0, SCREEN_MENU_RIGHT, SCREEN_PANEL_LEFT + 30.0, 40.0, 3.0, LINE_Z)


## Vai para a chave; entre a plataforma e o abrigo, pela passagem secreta (a não ser no instante inicial).
func _go(key: Dictionary, platform: bool, instant: bool) -> void:
	# A fila ainda saindo da plataforma (#131): a descida espera por ela (no máximo LEAVE_HOLD).
	if not platform and on_platform and not instant and lineup_leaving() and Time.get_ticks_msec() < _hold_until:
		_held_go = [key, platform, instant]
		_held_overview = _asking_overview
		return
	_held_go = []
	_in_overview = false
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
		_line_card(hero_ids[index], Vector3(LINE_CENTER_X + (index - (maxi(1, hero_ids.size()) - 1) * 0.5) * REPORT_SPACING, 0, LINE_Z))
	on_platform = true
	_path.clear()
	_apply_panel(0.0)
	_set_goal(_report_key(), instant)


## A câmera do relatório no kit (#60): a fila na tela inteira, com cada um de pé sobre a sua carta (os centros das
## cartas ficam a REPORT_CARD_STEP px um do outro, e os da fila a REPORT_SPACING m: a distância sai daí) e os pés em
## REPORT_FEET_Y, logo acima das cartas.
func _report_key() -> Dictionary:
	var fov := 40.0
	var pitch := -3.0
	var focal := 540.0 / tan(deg_to_rad(fov * 0.5))
	var depth := focal / (REPORT_CARD_STEP / REPORT_SPACING)
	var drop := atan((REPORT_FEET_Y - 540.0) / focal) + deg_to_rad(-pitch)
	return {"pos": Vector3(LINE_CENTER_X, depth * tan(drop), LINE_Z + depth), "fov": fov, "pitch": pitch}


## Cada um da fila vai para cima do centro da sua carta (centers: o x na tela de cada herói; o HUD diz onde), pela chave do relatório
## (aonde a câmera chega, e não onde ela está no caminho: ninguém desliza enquanto ela anda). O ponto da tela na
## altura dos pés, levado à linha da fila. Assim nenhuma carta corta um herói, em qualquer largura da janela.
func align_lineup(centers: Dictionary) -> void:
	if _goal.is_empty():
		return
	var screen := get_viewport().get_visible_rect().size
	var focal: float = screen.y * 0.5 / tan(deg_to_rad(float(_goal.fov) * 0.5))
	var tilt := deg_to_rad(-float(_goal.pitch))
	var along: float = (_goal.pos.z - LINE_Z) * cos(tilt) + _goal.pos.y * sin(tilt)
	for i in lineup.size():
		var entry: Dictionary = lineup[i]
		if not is_instance_valid(entry.card) or not centers.has(entry.hero_id):
			continue
		var x: float = _goal.pos.x + (float(centers[entry.hero_id]) - screen.x * 0.5) * along / focal
		entry.card.position.x = x
		if is_instance_valid(entry.get("contact")):
			entry.contact.position.x = x


## A partida (#123): a equipe em fila na Plataforma 1, na câmera do relatório, cada um de pé sobre a sua carta
## (align_lineup); do abrigo, a câmera sobe pela passagem. hero_ids vem na ordem da cena (a posição 1 à direita).
func show_departure(hero_ids: Array) -> void:
	clear_lineup()
	_release_boarding()
	for index in hero_ids.size():
		_line_card(hero_ids[index], Vector3(LINE_CENTER_X + (index - (maxi(1, hero_ids.size()) - 1) * 0.5) * REPORT_SPACING, 0, LINE_Z))
	_go(_report_key(), true, false)


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
	var contact := _contact(feet, Vector2(0.9, 0.45))
	lineup.append({"hero_id": hero_id, "card": card, "contact": contact})
	_contacts.append(contact)
	# Quem está na fila não aparece ao mesmo tempo no seu cômodo.
	if residents.has(hero_id):
		residents[hero_id].visible = false


## A fila do relatório sai andando (#131): da direita (a posição 1, mais perto da porta) para a esquerda, cada um com o
## passo dele (o ferido mais devagar). Quem sai da câmera vai para o cômodo; a fila fica vazia na hora.
func walk_off_lineup() -> void:
	var entries: Array = lineup.filter(func(e): return is_instance_valid(e.card))
	lineup.clear()
	entries.sort_custom(func(a, b): return a.card.position.x > b.card.position.x)
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var hero = S.hero(Campaign.state, entry.hero_id)
		entry.delay = i * LEAVE_STEP
		entry.speed = LEAVE_SPEED * (WOUNDED_PACE if hero != null and int(hero.hp) < int(hero.max_hp) else 1.0)
		# A sombra de contato vai junto (filha da carta).
		if entry.has("contact") and is_instance_valid(entry.contact):
			_contacts.erase(entry.contact)
			entry.contact.reparent(entry.card)
		_leaving.append(entry)
	if not _leaving.is_empty():
		_hold_until = Time.get_ticks_msec() + int(LEAVE_HOLD * 1000.0)


## Alguém da fila ainda está saindo da plataforma.
func lineup_leaving() -> bool:
	return not _leaving.is_empty()


func _tick_leaving(delta: float) -> void:
	var time := Time.get_ticks_msec() * 0.001
	for entry in _leaving.duplicate():
		var card: AHSpriteCard = entry.card
		if not is_instance_valid(card):
			_release_leaving(entry)
			continue
		entry.delay -= delta
		if entry.delay > 0.0:
			continue
		card.set_facing(1.0)
		card.position.x += entry.speed * delta
		card.scale = Vector3(1, 1.0 + 0.025 * absf(sin(time * 7.0)), 1)
		if not _on_screen(card) or card.position.x > DOOR_X + 2.0:
			_release_leaving(entry)


## A carta (do pé à cabeça) aparece na câmera.
func _on_screen(card: AHSpriteCard) -> bool:
	if camera == null:
		return false
	var rect := Rect2(Vector2(-80, -80), get_viewport().get_visible_rect().size + Vector2(160, 160))
	for point in [card.position, card.position + Vector3(0, card.body_height, 0)]:
		if not camera.is_position_behind(point) and rect.has_point(camera.unproject_position(point)):
			return true
	return false


func _release_leaving(entry: Dictionary) -> void:
	_leaving.erase(entry)
	if is_instance_valid(entry.card):
		entry.card.queue_free()
	if residents.has(entry.hero_id):
		residents[entry.hero_id].visible = not _residents_hidden


func clear_lineup() -> void:
	for entry in lineup:
		if is_instance_valid(entry.card):
			entry.card.queue_free()
		if residents.has(entry.hero_id):
			residents[entry.hero_id].visible = not _residents_hidden
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


## O trem chega do túnel com o candidato (PlayTrainArrival): o aviso primeiro, depois a entrada freando até parar, as
## portas e o candidato descendo; a câmera só fecha nele quando ele chega à plataforma.
func play_train_arrival(candidate_id: String) -> void:
	_team_train_leaving = false
	_remove_candidate()
	_candidate_id = candidate_id
	_train_mode = 1
	_train_time = 0.0
	_warning_time = 0.0
	_door_open = 0.0
	_camera_pending = false
	_offset_wagon(TRAIN_OUT)
	_train_sound = Sound.play("res://audio/station/train_arrival.ogg", 0.9)
	Sound.play("res://audio/station/train_bell.ogg", 0.8)
	train_event.emit("warning")


## Fecha e acelera para o túnel; fica fora até a próxima chegada (PlayTrainDeparture). Recusado, o candidato volta
## para dentro do trem antes de as portas fecharem.
func play_train_departure(candidate_leaves: bool) -> void:
	departure_pending = false
	_team_train_leaving = false
	_warning_time = -1.0
	_train_time = 0.0
	_camera_pending = false
	_reopen_pending = false
	_offset_wagon(0.0)
	# A partida à vista: a câmera volta para a plataforma inteira, com o vagão, a porta e o lugar do candidato.
	if on_platform and not passage_moving():
		_set_goal(_platform_key())
	if candidate_leaves and is_instance_valid(_candidate):
		_train_mode = 3
		# Ele entra pela porta aberta (o candidato mostrado sem a chegada esperava com o vagão fechado).
		_set_door_open(1.0)
		# O candidato mostrado sem a chegada (o painel reaberto depois da cena) não tem passeio: ganha um agora.
		var own: Array = _walkers.filter(func(w): return w.card == _candidate)
		var walker: Dictionary = own[0] if not own.is_empty() else {"card": _candidate, "phase": 0.0, "home_z": _candidate.position.z}
		if own.is_empty():
			_walkers.append(walker)
		walker.min = _train_door_x()
		walker.max = _candidate.position.x
		walker.target = _train_door_x()
		walker.wait = 0.0
		walker.stay = true
		walker.speed = TRAIN_WALK_SPEED * train_speed()
		train_event.emit("boarding")
		return
	if candidate_leaves:
		_remove_candidate()
	_close_and_leave()


func _close_and_leave() -> void:
	_train_mode = 2
	_train_time = 0.0
	# O sino avisa que as portas fecham (#36); o som da partida vem quando o trem anda.
	Sound.play("res://audio/station/train_bell.ogg", 0.7)
	train_event.emit("doors_closing")


## A velocidade da cena do trem: a da luta nas Opções (1x ou 2x).
func train_speed() -> float:
	return float(clampi(int(Campaign.state.get("settings", {}).get("battle_speed", 1)), 1, 2))


## Onde o candidato entra e sai do vagão (sem o modelo do metrô, 3,3 m antes do lugar dele na plataforma).
func _train_door_x() -> float:
	var target := _departure_slot(1)
	return _build.train_exit_x if not is_nan(_build.train_exit_x) else target.x - 3.3


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
		player.volume_db = spec[2] + Sound.mix_db(spec[1])
		player.unit_size = 9.0
		player.max_distance = 60.0
		player.position = Vector3((room.x0 + room.x1) * 0.5, room.ceiling - 0.4, LANE_Z)
		player.autoplay = true
		add_child(player)


## Espera um passo da cena do trem (o _decide do HUD espera o "gone").
func train_event_named(name: String) -> void:
	while true:
		var got: String = await train_event
		if got == name:
			return


func train_busy() -> bool:
	# O trem que trouxe a equipe indo embora não segura a cena do candidato: a chegada dele começa do túnel.
	return (_train_mode != 0 and not _team_train_leaving) or _pending_arrival != "" or _reopen_pending or departure_pending


# ---------------------------------------------------------------- a volta da equipe (#76)

## A volta da expedição: o trem chega à plataforma com a equipe, as portas abrem e cada sobrevivente desce e anda até o
## lugar da fila do relatório (quem está ferido, mais devagar); os mortos não descem. Com todos no lugar, "team_ready"
## (o HUD abre o relatório) e o trem fecha e vai embora. finish_team_arrival pula para o fim. É só a cena: o save
## não muda (reaberto no meio, a volta começa de novo).
func play_team_arrival(hero_ids: Array) -> void:
	clear_lineup()
	# Quem ainda saía da plataforma de uma volta anterior (#131) sai de vez: a carta velha não fica na fila nova.
	for entry in _leaving.duplicate():
		_release_leaving(entry)
	_held_go = []
	_remove_candidate()
	_arrivals.clear()
	# Na ordem da formação, a posição 1 à direita (#131).
	var survivors: Array = AHStationReport.scene_order(hero_ids.filter(func(id): var h = S.hero(Campaign.state, id); return h != null and h.alive))
	# Os lugares da fila ficam todos à direita da porta: desce primeiro quem vai para o mais longe, para ninguém
	# atravessar quem já parou (a fila fica na ordem do relatório).
	for step in survivors.size():
		var index: int = survivors.size() - 1 - step
		var entry = S.hero(Campaign.state, survivors[index])
		var art := _hero_art(entry)
		if art.is_empty():
			continue
		var hurt: bool = int(entry.get("hp", 0)) < int(entry.get("max_hp", 0))
		_arrivals.append({"hero_id": survivors[index], "art": art.idle, "slot": _line_slot(index, survivors.size()),
			"delay": step * TEAM_STEP_OUT, "speed": TRAIN_WALK_SPEED * (WOUNDED_PACE if hurt else 1.0), "card": null, "hurt": hurt})
	on_platform = true
	_path.clear()
	_apply_panel(0.0)
	# A câmera da fila do relatório: a equipe desce pela porta do lado da plataforma (atrás do vagão) e aparece saindo
	# de trás dele, andando até o lugar (como o candidato, #61).
	_set_goal(_line_key(maxi(1, survivors.size())), true)
	_train_mode = 4
	_train_time = 0.0
	_warning_time = 0.0
	_door_open = 0.0
	_camera_pending = false
	_offset_wagon(TRAIN_OUT)
	_train_sound = Sound.play("res://audio/station/train_arrival.ogg", 0.9)
	Sound.play("res://audio/station/train_bell.ogg", 0.8)
	train_event.emit("warning")


## A chegada em andamento (o HUD espera o "team_ready").
func team_arriving() -> bool:
	return _train_mode == 4


## Pula a chegada: todos no lugar, o trem já fora e as portas fechadas; o HUD segue para o relatório.
func finish_team_arrival() -> void:
	if _train_mode != 4:
		return
	for arrival in _arrivals:
		if arrival.card == null:
			_spawn_arrival(arrival)
		arrival.card.position = arrival.slot
		arrival.card.scale = Vector3.ONE
		arrival.card.set_facing(1.0)
	Sound.fade_out(_train_sound, 0.3)
	_warning_time = -1.0
	_door_open = 0.0
	_offset_wagon(TRAIN_OUT)
	_train_mode = 0
	train_event.emit("team_ready")


func _spawn_arrival(arrival: Dictionary) -> void:
	var card := AHSpriteCard.new()
	card.body_height = AHCharacterHeights.find(arrival.hero_id)
	card.show_art(arrival.art)
	add_child(card)
	card.position = Vector3(_train_door_x(), arrival.slot.y, arrival.slot.z)
	card.set_facing(signf(arrival.slot.x - card.position.x) if absf(arrival.slot.x - card.position.x) > 0.01 else 1.0)
	arrival.card = card
	# A sombra de contato anda junto (filha da carta), como a da fila.
	var contact := _contact(card.position, Vector2(0.9, 0.45))
	contact.reparent(card)
	_contacts.append(contact)
	# Na fila do relatório: some do cômodo enquanto está na plataforma (como _line_card), e a fila libera a carta.
	lineup.append({"hero_id": arrival.hero_id, "card": card})
	if residents.has(arrival.hero_id):
		residents[arrival.hero_id].visible = false


func _tick_team_arrival(_before: float, step: float) -> void:
	if _train_time < TRAIN_DOOR_END:
		return
	var time := Time.get_ticks_msec() * 0.001
	var placed := true
	# Quem vem atrás não passa de quem vai na frente (o ferido anda mais devagar): fica a um passo dele.
	var ahead_x := INF
	for arrival in _arrivals:
		if arrival.card == null:
			# Desce quando chega a vez e quem vai na frente já abriu espaço na porta (senão recuaria para o vagão).
			if _train_time - TRAIN_DOOR_END >= arrival.delay and ahead_x - _train_door_x() >= FOLLOW_GAP:
				_spawn_arrival(arrival)
			# Quem ainda não desceu (ou acabou de descer, na porta) segura os de trás.
			ahead_x = arrival.card.position.x if arrival.card != null else -INF
			placed = false
			continue
		var card: AHSpriteCard = arrival.card
		var gap: float = arrival.slot.x - card.position.x
		if absf(gap) < 0.02:
			card.position.x = arrival.slot.x
			card.scale = Vector3.ONE
			card.set_facing(1.0)
			ahead_x = card.position.x
			continue
		placed = false
		card.position.x = minf(card.position.x + signf(gap) * minf(absf(gap), arrival.speed * step), ahead_x - FOLLOW_GAP)
		ahead_x = card.position.x
		# O passo: quem está ferido balança mais devagar.
		card.scale = Vector3(1, 1.0 + 0.025 * absf(sin(time * (4.5 if arrival.hurt else 7.0))), 1)
	# Ninguém para descer (todos caíram): as portas abrem e o trem espera um instante vazio.
	if _arrivals.is_empty() and _train_time < TRAIN_DOOR_END + EMPTY_WAIT:
		placed = false
	if placed:
		train_event.emit("team_ready")
		_close_and_leave()
		_team_train_leaving = true


## O candidato esperando na plataforma, sem a chegada (o jogo foi reaberto com o trem parado).
func show_candidate(candidate_id: String) -> void:
	if is_instance_valid(_candidate) and _candidate_id == candidate_id:
		return
	_remove_candidate()
	_candidate_id = candidate_id
	_spawn_candidate(_departure_slot(1))
	_spawn_companion()
	_offset_wagon(0.0)


func clear_candidate() -> void:
	_remove_candidate()
	_candidate_id = ""


func _remove_candidate() -> void:
	if is_instance_valid(_candidate):
		_candidate.queue_free()
	_candidate = null
	if is_instance_valid(_companion):
		_companion.queue_free()
	_companion = null
	_walkers = _walkers.filter(func(w): return is_instance_valid(w.card))


## Decidido o primeiro do trem (#182), o segundo passa a esperar: o recusado volta andando ao vagão (o acolhido já foi
## para o cômodo), o segundo anda até o lugar do primeiro, e a câmera fecha nele.
func promote_companion(candidate_id: String, first_leaves: bool) -> void:
	if is_instance_valid(_candidate):
		if first_leaves:
			_set_door_open(1.0)
			var own: Array = _walkers.filter(func(w): return w.card == _candidate)
			var walker: Dictionary = own[0] if not own.is_empty() else {"card": _candidate, "phase": 0.0, "home_z": _candidate.position.z}
			if own.is_empty():
				_walkers.append(walker)
			walker.min = _train_door_x()
			walker.max = _candidate.position.x
			walker.target = _train_door_x()
			walker.wait = 0.0
			walker.stay = false
			walker.vanish = true
			walker.speed = TRAIN_WALK_SPEED * train_speed()
		else:
			_candidate.queue_free()
	_candidate = null
	_candidate_id = candidate_id
	if not is_instance_valid(_companion):
		show_candidate(candidate_id)
	else:
		_candidate = _companion
		_companion = null
		var slot := _departure_slot(1)
		var own: Array = _walkers.filter(func(w): return w.card == _candidate)
		var walker: Dictionary = own[0] if not own.is_empty() else {"card": _candidate, "phase": 0.0}
		if own.is_empty():
			_walkers.append(walker)
		walker.min = minf(slot.x, _candidate.position.x)
		walker.max = maxf(slot.x, _candidate.position.x)
		walker.target = slot.x
		walker.wait = 0.0
		walker.stay = true
		walker.home_z = slot.z
		walker.speed = TRAIN_WALK_SPEED * train_speed()
		_candidate.position.z = slot.z
	if on_platform:
		_go(_candidate_key(), true, false)


## O jogador escolheu decidir primeiro o outro dos dois (#182, S.bring_forward): as placas trocam de papel, cada uma no
## lugar onde está.
func swap_pair() -> void:
	var train: Dictionary = Campaign.state.station.train
	if train.candidate_id == _candidate_id or not is_instance_valid(_companion):
		return
	var first := _candidate
	_candidate = _companion
	_companion = first
	_candidate_id = train.candidate_id


## Os dois do trem (#182) na ordem em que estão na plataforma, da esquerda para a direita (as abas do painel seguem a
## cena, e trocar quem é decidido não as troca de lugar).
func pair_order(ids: Array) -> Array:
	var cards := {_candidate_id: _candidate}
	if is_instance_valid(_companion):
		for id in ids:
			if id != _candidate_id:
				cards[id] = _companion
	if ids.any(func(id): return not cards.has(id) or not is_instance_valid(cards[id])):
		return ids
	var sorted := ids.duplicate()
	sorted.sort_custom(func(a, b): return cards[a].position.x < cards[b].position.x)
	return sorted


## Os moradores de novo nos cômodos, num sorteio novo (o acolhido do trem vai para um deles).
func place_residents() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_place_residents(rng)


## A partida decidida, esperando o recusado (#182) entrar no vagão: o trem já conta como ocupado (a Preparação não
## abre com ele partindo atrás da fila).
var departure_pending := false


## O recusado (#182) ainda andando de volta ao vagão.
func boarding_back() -> bool:
	return _walkers.any(func(w): return w.get("vanish", false) and is_instance_valid(w.card) and not w.card.is_queued_for_deletion())


## Quem voltava ao vagão sai da cena de vez (a Preparação monta a fila na plataforma).
func _release_boarding() -> void:
	for walker in _walkers:
		if walker.get("vanish", false) and is_instance_valid(walker.card):
			walker.card.queue_free()


## O segundo animal do trem (#182), de pé ao lado de quem é decidido agora, até a vez dele.
func _spawn_companion(feet: Vector3 = Vector3.INF) -> AHSpriteCard:
	var second: Dictionary = Campaign.state.station.train.get("next", {})
	if second.is_empty():
		return null
	var art: Dictionary = AHCombatArena.hero_art_of(String(second.candidate_id), String(second.recruit.art_variant)).get("idle", {})
	if art.is_empty():
		return null
	_companion = AHSpriteCard.new()
	_companion.name = "TrainCompanion"
	_companion.body_height = AHCharacterHeights.find(String(second.candidate_id))
	_companion.show_art(art)
	add_child(_companion)
	_companion.position = _companion_slot() if feet == Vector3.INF else feet
	_companion.set_facing(1.0)
	return _companion


func _spawn_candidate(feet: Vector3) -> AHSpriteCard:
	var art: Dictionary = _civilian_art.get(_candidate_id, {})
	# O animal do trem (#122): a arte de luta da classe, na variação dele.
	var recruit: Dictionary = S.train_recruit(Campaign.state)
	if art.is_empty() and not recruit.is_empty() and Campaign.state.station.train.candidate_id == _candidate_id:
		art = AHCombatArena.hero_art_of(_candidate_id, String(recruit.art_variant)).get("idle", {})
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
	var step := delta * train_speed()
	if _warning_time >= 0.0:
		_warning_time += step
	var approaching := _warning_time >= 0.0
	# O sinal pisca na chegada; com "Reduzir efeitos", fica aceso sem piscar.
	var reduced: bool = Campaign.state.get("settings", {}).get("reduced_environment_effects", false)
	var bright := not approaching or reduced or fmod(_warning_time, 0.8) < 0.4
	if _build.signal_light:
		_build.signal_light.light_energy = (90.0 if bright else 9.0) / AHStationBuilder.LUMENS_PER_ENERGY
	if _build.signal_glow:
		_build.signal_glow.visible = bright
	if _train_mode == 0:
		return
	var before := _train_time
	_train_time += step
	match _train_mode:
		3:
			# O recusado anda de volta até a porta e entra; só então o trem fecha.
			if not is_instance_valid(_candidate) or absf(_candidate.position.x - _train_door_x()) < 0.05:
				_remove_candidate()
				train_event.emit("boarded")
				_close_and_leave()
		2:
			# Fecha primeiro; depois acelera para o túnel, com o som da partida.
			_door_open = clampf(1.0 - _train_time / TRAIN_CLOSE, 0.0, 1.0)
			if before < TRAIN_CLOSE and _train_time >= TRAIN_CLOSE:
				train_event.emit("doors_closed")
				_train_sound = Sound.play("res://audio/station/train_departure.ogg", 0.9)
				train_event.emit("leaving")
			var alpha := clampf((_train_time - TRAIN_CLOSE) / TRAIN_LEAVE, 0.0, 1.0)
			_offset_wagon(-36.0 * alpha * alpha)
			if _train_time >= TRAIN_CLOSE + TRAIN_LEAVE:
				_train_mode = 0
				_team_train_leaving = false
				# O arquivo do som é mais longo que a saída (a 2x, o dobro): some com o trem.
				Sound.fade_out(_train_sound, 0.8)
				train_event.emit("gone")
		1:
			_tick_arrival(before)
		4:
			_tick_slide_in(before)
			_tick_team_arrival(before, step)


func _tick_arrival(before: float) -> void:
	_tick_slide_in(before)
	var target := _departure_slot(1)
	if before < TRAIN_DOOR_END and _train_time >= TRAIN_DOOR_END:
		# Desce pela porta do metrô e anda até a plataforma.
		var card := _spawn_candidate(Vector3(_train_door_x(), target.y, target.z))
		if card:
			_walkers.append({"card": card, "min": target.x, "max": target.x, "target": target.x, "wait": 0.0, "phase": 0.0,
				"speed": TRAIN_WALK_SPEED * train_speed(), "stay": true, "home_z": target.z})
		# Desceram dois (#182): o segundo desce logo atrás e para ao lado.
		var beside := _companion_slot()
		var companion := _spawn_companion(Vector3(_train_door_x(), beside.y, beside.z))
		if companion:
			_walkers.append({"card": companion, "min": beside.x, "max": beside.x, "target": beside.x, "wait": 0.0, "phase": 0.0,
				"speed": TRAIN_WALK_SPEED * train_speed(), "stay": true, "home_z": beside.z})
		train_event.emit("candidate_out")
	if not _camera_pending and _train_time >= TRAIN_DOOR_END and (not is_instance_valid(_candidate) or absf(_candidate.position.x - target.x) < 0.05):
		_camera_pending = true
		train_event.emit("candidate_ready")
	if _camera_pending:
		_tick_camera_on_candidate()


## O trem chegando: o freio antes de parar, a parada e as portas abrindo (a chegada do candidato e a da equipe).
func _tick_slide_in(before: float) -> void:
	# O freio antes de parar e a parada.
	if before < TRAIN_STOP - BRAKE_LEAD and _train_time >= TRAIN_STOP - BRAKE_LEAD:
		Sound.play("res://audio/station/train_brake.ogg", 0.8)
		train_event.emit("brake")
	var slide := clampf((_train_time - TRAIN_WARNING) / (TRAIN_STOP - TRAIN_WARNING), 0.0, 1.0)
	_offset_wagon(TRAIN_OUT * (1.0 - slide) * (1.0 - slide))
	if before < TRAIN_STOP and _train_time >= TRAIN_STOP:
		_warning_time = -1.0
		# O ruído do trem rodando acaba quando ele para (o arquivo segue até 5,5 s; a 2x o trem para antes).
		Sound.fade_out(_train_sound, 0.5)
		train_event.emit("stop")
	_door_open = clampf((_train_time - TRAIN_DOOR_START) / (TRAIN_DOOR_END - TRAIN_DOOR_START), 0.0, 1.0)
	if before < TRAIN_DOOR_END and _train_time >= TRAIN_DOOR_END:
		train_event.emit("doors_open")


func _tick_reopen() -> void:
	if hud != null and hud.current != "train":
		_reopen_pending = false
		return
	if passage_moving():
		return
	var key := _candidate_key()
	if _key.pos.distance_to(key.pos) < 0.05 and absf(_key.fov - key.fov) < 0.3:
		_reopen_pending = false
		train_event.emit("camera_on_candidate")


## Depois de o candidato chegar ao lugar, a câmera fecha nele e só então a cena acaba (o painel abre). Se o jogador
## saiu do trem (um cômodo, as Opções), a câmera fica onde ele está e a cena acaba sem ela: o painel do trem, reaberto,
## vai direto ao candidato.
func _tick_camera_on_candidate() -> void:
	if hud != null and hud.current != "train":
		_camera_pending = false
		_train_mode = 0
		return
	if not on_platform or passage_moving():
		return
	var key := _candidate_key()
	if _goal != key:
		_set_goal(key)
	if _key.pos.distance_to(key.pos) < 0.05 and absf(_key.fov - key.fov) < 0.3:
		_camera_pending = false
		_train_mode = 0
		train_event.emit("camera_on_candidate")


# ---------------------------------------------------------------- moradores

## Quem dorme fica 30 cm à frente do beliche; na câmera da Estação isso o sobe uns 10 cm sobre o lençol (medido na
## captura da noite, #31). Desce o mesmo tanto para o corpo encostar no colchão.
const SLEEP_DROP := 10.0


## Os quatro lugares dos beliches (m): de baixo à esquerda, de baixo à direita, e os de cima.
static func sleep_slots() -> Array:
	var out: Array = []
	for tier in 2:
		for x in AHStationBuild.BUNK_X:
			# Um pouco para a cabeceira (o travesseiro fica à esquerda) e à frente da cama pintada.
			out.append(AHStationBuilder.vu(Vector3(x - 12.0, AHStationBuild.BUNK_Y + 30.0,
				AHStationBuild.BUNK_FLOOR + tier * AHStationBuild.BUNK_UPPER + AHStationBuild.MATTRESS_TOP - SLEEP_DROP)))
	return out


## Os leitos da Enfermaria (#121), na ordem em que enchem: o de baixo e o de cima do primeiro beliche, depois os do
## segundo (nível 2).
static func infirmary_slots() -> Array:
	var out: Array = []
	for x in AHStationBuild.INFIRMARY_BUNK_X:
		for tier in 2:
			out.append(AHStationBuilder.vu(Vector3(x - 12.0, AHStationBuild.BUNK_Y + 30.0,
				AHStationBuild.INFIRMARY_FLOOR + tier * AHStationBuild.BUNK_UPPER + AHStationBuild.MATTRESS_TOP - SLEEP_DROP)))
	return out


## Onde fica deitado quem está em recuperação (#118): o leito da Enfermaria, ou, sem leito, um beliche livre do
## Dormitório (os de baixo para cima, de trás para a frente, para não tomar o de quem dorme a noite). Vector3.INF sem
## lugar.
static func recovery_spot(campaign: Dictionary, hero_id: String) -> Vector3:
	var entry = S.hero(campaign, hero_id)
	var fallen := S.fallen(campaign)
	if S.in_bed(entry):
		var index: int = fallen.filter(func(h): return S.in_bed(h)).map(func(h): return h.id).find(hero_id)
		var slots := infirmary_slots()
		return slots[index] if index >= 0 and index < slots.size() else Vector3.INF
	var index: int = fallen.filter(func(h): return not S.in_bed(h)).map(func(h): return h.id).find(hero_id)
	var slots := sleep_slots()
	var taken: int = sleepers(campaign).size()
	var slot: int = slots.size() - 1 - index
	return slots[slot] if index >= 0 and slot >= taken else Vector3.INF


## Quem dorme esta noite: os participantes vivos da noite por resolver, menos o vigia (S.night_preview). Durante a
## cena da noite (#132), a regra já resolveu a noite, e quem dormiu continua deitado até a luz da manhã voltar.
static func sleepers(campaign: Dictionary) -> Array:
	if night_scene and campaign.night.phase == "dawn":
		return campaign.night.results.filter(func(row): return not row.watch).map(func(row): return row.hero_id)
	if campaign.night.phase != "planning":
		return []
	return S.night_preview(campaign).heroes.filter(func(row): return not row.watch).map(func(row): return row.hero_id)


## A cena da noite está passando (#132): quem dormiu fica deitado, e o vigia, de pé no Dormitório.
static var night_scene := false


func set_night_scene(on: bool) -> void:
	night_scene = on
	_update_sleepers()


## A cena não sobrevive à Estação (a troca de cena no meio da noite): quem dormiu não fica deitado por engano.
func _exit_tree() -> void:
	night_scene = false


## À noite, quem dorme deita no beliche (a pose de dormir aprovada pelo Lucas); o vigia fica de pé no Dormitório. Com a
## noite resolvida, todos voltam a passear.
func _update_sleepers() -> void:
	var campaign: Dictionary = Campaign.state
	var asleep := sleepers(campaign)
	var slots := sleep_slots()
	var watch: String = campaign.night.watch_hero_id if campaign.night.phase == "planning" or (night_scene and campaign.night.phase == "dawn") else ""
	var dorm := room_def(S.DORMITORY)
	var replace := false
	for walker in _walkers:
		if not walker.has("hero_id") or not is_instance_valid(walker.card):
			continue
		var card: AHSpriteCard = walker.card
		# Em recuperação (#118): deitado no leito da Enfermaria (ou num beliche do Dormitório), sem passear. Sem a pose
		# de dormir ou sem lugar, fica de pé, parado, no cômodo onde se recupera.
		if S.recovering(S.hero(campaign, walker.hero_id)):
			walker.sleeping = true
			walker.recovering = true
			var spot := recovery_spot(campaign, walker.hero_id)
			if spot != Vector3.INF and _poses.has(walker.hero_id + "_sleep"):
				card.show_art(_poses[walker.hero_id + "_sleep"])
				card.position = spot
			else:
				var place := room_def(S.INFIRMARY if S.in_bed(S.hero(campaign, walker.hero_id)) else S.DORMITORY)
				card.show_art(walker.idle)
				# Sem lugar no beliche, de pé no cômodo, cada um no seu ponto da faixa (nunca um por cima do outro).
				var order: int = S.fallen(campaign).map(func(h): return h.id).find(walker.hero_id)
				var along := fmod(0.15 + order * 0.29, 0.7) + 0.15
				card.position = Vector3(spot.x if spot != Vector3.INF else lerpf(place.lane[0], place.lane[1], along), place.floor, LANE_Z)
			card.set_facing(1.0)
			card.scale = Vector3.ONE
			continue
		if walker.get("recovering", false):
			# Recuperado: volta a passear (os cômodos são sorteados de novo).
			replace = true
			continue
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
	if replace:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_place_residents.call_deferred(rng)


## Cada herói vivo num cômodo sorteado (30% de chance de dividir um já ocupado, no máximo dois), passeando pela faixa
## do cômodo; os civis ficam no cômodo deles, alternando o idle e a pose de trabalho.
func _place_residents(rng: RandomNumberGenerator) -> void:
	# Quem voltava ao vagão (#182) não fica parado na plataforma sem o passeio.
	_release_boarding()
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
		if S.recovering(entry):
			# Quem se recupera não passeia (_update_sleepers deita no leito); não toma o cômodo de ninguém.
			room_id = S.INFIRMARY if S.in_bed(entry) else S.DORMITORY
		elif free_rooms.is_empty() or (not shared.is_empty() and rng.randf() < SHARE_ROOM_CHANCE):
			room_id = shared[rng.randi_range(0, shared.size() - 1)] if not shared.is_empty() else ROOMS[0].id
		else:
			room_id = free_rooms.pop_at(rng.randi_range(0, free_rooms.size() - 1))
		if not S.recovering(entry):
			occupancy[room_id] = int(occupancy.get(room_id, 0)) + 1
		var room := room_def(room_id)
		var card := AHSpriteCard.new()
		card.body_height = AHCharacterHeights.find(entry.id)
		card.show_art(art.idle)
		add_child(card)
		occlusion.track(card)
		var lane: Array = room.lane
		var occupants: int = int(occupancy.get(room_id, 1))
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
	# Ninguém começa em cima de outro (o morador fica no meio do cômodo, e o herói sorteado podia cair nele).
	for walker in _walkers:
		if walker.has("civilian") or not walker.has("hero_id"):
			continue
		var card: AHSpriteCard = walker.card
		if _crowded(walker, card.position.x):
			# O ponto mais folgado entre vários sorteados (numa faixa estreita, o primeiro livre podia não sair).
			var best := _clearance(walker, card.position.x)
			var spot := card.position.x
			for attempt in 16:
				var x := rng.randf_range(walker.min, walker.max)
				var room_left := _clearance(walker, x)
				if room_left > best:
					best = room_left
					spot = x
			card.position.x = spot
		walker.target = card.position.x
	# Refeitos os passeios (depois do trem, por exemplo), quem dorme volta para o beliche.
	_update_sleepers()
	if _residents_hidden:
		hide_residents(true)


## A arte do herói (o recruta, a variação da classe guardada no save; sem ela, a do fundador).
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
						# De volta à faixa, colado em alguém (o morador do cômodo): sai andando em vez de esperar ali.
						if _crowded(walker, card.position.x):
							walker.wait = 0.0
							_choose_target(walker)
					continue
				walker.pause -= delta
				# O posto do meio da faixa é de um só: com alguém trabalhando nele, espera a vez.
				if walker.pause <= 0.0 and walker.wait > 0.0 and _post_taken(walker):
					walker.pause = randf_range(3.0, 6.0)
				if walker.pause <= 0.0 and walker.wait > 0.0:
					card.show_art(_poses[walker.hero_id + "_work"])
					card.position = Vector3(_work_post(walker), walker.floor, -5.6)
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
			# O recusado que voltou ao vagão (#182) some na porta.
			if walker.get("vanish", false):
				card.queue_free()
				continue
			if walker.get("stay", false):
				walker.wait = INF
				continue
			if walker.get("seat", -1) >= 0:
				_sit_down(walker)
				continue
			# Chegou perto demais de alguém parado (que parou ali enquanto ele andava): segue para outro ponto. Numa
			# faixa estreita ou cheia (a Preparação, a Forja com o Otto), três voltas não bastavam para achar lugar; o
			# teto alto só vale para uma faixa sem lugar nenhum, onde andar para sempre seria pior que parar perto.
			if _crowded(walker, card.position.x) and walker.get("rerouted", 0) < REROUTE_LIMIT:
				_choose_target(walker, true)
				continue
			walker.rerouted = 0
			walker.wait = randf_range(2.5, 7.0)
			continue
		card.set_facing(signf(gap))
		card.position.x += signf(gap) * minf(absf(gap), speed * delta)
		card.scale = Vector3(1, 1.0 + 0.025 * absf(sin(time * 7.0 + walker.phase)), 1)


## retry: a busca de outro lugar de quem chegou num ponto cheio (conta para o REROUTE_LIMIT); qualquer outro passeio
## começa a contagem do zero.
func _choose_target(walker: Dictionary, retry: bool = false) -> void:
	walker.rerouted = walker.get("rerouted", 0) + 1 if retry else 0
	var card: AHSpriteCard = walker.card
	# Pelo menos 1 m de caminhada e longe de quem está parado ou indo parar na mesma faixa; perto de uma ponta, vai
	# para a outra.
	# Entre vários pontos sorteados, o mais folgado (numa faixa estreita, como a da Preparação, o primeiro livre podia
	# nem existir entre poucos sorteios).
	var target := randf_range(walker.min, walker.max)
	var best := -1.0
	for attempt in 16:
		var x := randf_range(walker.min, walker.max)
		if absf(x - card.position.x) < 1.0:
			continue
		var room_left := minf(_clearance(walker, x), STOP_GAP * 2.0)
		if room_left > best:
			best = room_left
			target = x
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


## Há alguém parado (ou indo parar) a menos de STOP_GAP de x, na mesma faixa (o mesmo andar e a mesma profundidade).
func _crowded(walker: Dictionary, x: float) -> bool:
	return _clearance(walker, x) < STOP_GAP


## A distância de x até o mais perto de quem está parado (ou indo parar) na mesma faixa.
func _clearance(walker: Dictionary, x: float) -> float:
	var card: AHSpriteCard = walker.card
	var nearest := INF
	for other in _walkers:
		if other == walker or not is_instance_valid(other.card) or not other.card.visible:
			continue
		var them: AHSpriteCard = other.card
		if absf(them.position.y - card.position.y) > 0.5 or absf(them.position.z - card.position.z) > 1.5:
			continue
		var moving: bool = not other.has("civilian") and other.get("wait", 0.0) <= 0.0 and other.get("sitting", 0.0) <= 0.0
		var spot: float = float(other.get("target", them.position.x)) if moving else them.position.x
		nearest = minf(nearest, minf(absf(spot - x), absf(them.position.x - x)))
	return nearest


## O posto de trabalho: o meio da faixa ou, com alguém ali (o morador do cômodo fica no meio), ao lado.
func _work_post(walker: Dictionary) -> float:
	var middle: float = (walker.min + walker.max) * 0.5
	for offset in [0.0, STOP_GAP + 0.4, -(STOP_GAP + 0.4)]:
		var x: float = clampf(middle + offset, walker.min, walker.max)
		if not _crowded(walker, x):
			return x
	return middle


## Alguém já trabalha no posto do meio da faixa deste cômodo.
func _post_taken(walker: Dictionary) -> bool:
	for other in _walkers:
		if other != walker and other.get("room", "") == walker.get("room", "") and other.get("working", 0.0) > 0.0:
			return true
	return false


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
	# Levantou na frente de alguém que parou ali enquanto estava sentado: sai andando.
	if _crowded(walker, card.position.x):
		walker.wait = 0.0
		_choose_target(walker)


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
	# O glow do perfil de ambiência da Estação (#153).
	AHAmbience.apply_env(env, AHAmbience.profile("Station"), env.glow_intensity)
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.04
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		env.ssao_enabled = Settings.effects().ssao
		env.ssao_radius = 0.9
		env.ssao_intensity = 1.4
	# A oclusão e o pós acompanham a qualidade das opções (Settings). Pelo método do nó: a conexão sai junto com a cena
	# (uma lambda que só usa env não é do nó e ficava conectada a cada visita à Estação).
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
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		_env.ssao_enabled = Settings.effects().ssao
	# O pós com a qualidade nova (no Baixo, sem o desfoque), ao vivo como na rua.
	if _post != null:
		AHAmbience.apply_post(_post, AHAmbience.profile("Station"), Settings.level)


func _build_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var post := ShaderMaterial.new()
	post.shader = preload("res://shaders/post_emberfall.gdshader")
	# O perfil de ambiência da Estação (#153): no refúgio o corte inteiro precisa ler, então foco largo e pouco
	# desfoque, só a cor e a vinheta do Emberfall.
	AHAmbience.apply_post(post, AHAmbience.profile("Station"), Settings.level)
	_post = post
	rect.material = post
	layer.add_child(rect)
	add_child(layer)
