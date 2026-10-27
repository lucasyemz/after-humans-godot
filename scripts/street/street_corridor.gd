## A jornada na Rua das Vitrines (port enxuto do AAHStreetCorridor): liga as regras (AHJourneyRules) à cena da rua.
## - Os 10 trechos ocupam 7,8 m cada a partir do começo da rua; a equipe só passa de um trecho com a patrulha vencida.
## - Cada patrulha espera em pé no trecho dela. O da frente vê num cone de 60° até 14 m (menos à noite, na chuva e na
##   névoa), e carros, props e paredes tapam a visão. A suspeita sobe enquanto vê e cai depois de um tempo sem ver:
##   "?" desconfiado, "!" detectado (ele avança sobre a equipe). Chegar até ele sem ser detectado dá a vantagem de
##   abertura (a equipe age primeiro).
## - As três casas sorteadas ficam com a porta aberta pintada; a trancada pede pé de cabra. Dentro, os pontos de busca,
##   a emboscada da patrulha da casa e o acampamento. Os trechos de suprimentos têm um objeto para vasculhar.
## - O começo da rua é a volta à Estação. Cada chegada a um trecho, luta, busca e acampamento salva a campanha.
## - Nos cenários (#86) o corredor é uma sequência de segmentos: cada zona caminhável do mapa é um segmento, e os trechos
##   do mapa se dividem entre elas pelo comprimento (pelo menos um em cada). No fim de uma zona, com o último trecho dela
##   vencido, a equipe segue para a próxima ("Seguindo para: Navio…"). Os interiores laterais (o navio e o galpão do Cais,
##   as salas do Depósito) ficam fora da sequência: entra-se pela porta. Os props do mapa são pontos de busca. No fim do
##   mapa de passagem a equipe viaja para o mapa da fase. Na rua há um segmento só, e nada muda.
class_name AHStreetCorridor
extends Node

const R = preload("res://scripts/flow/journey_rules.gd")
const STEP_LENGTH := 7.8
const MIN_X := 0.0
const GUARD_SPOT := 0.65
const ARRIVAL_SPOT := 0.25
const EDGE_MARGIN := 0.4
const CONTACT := 1.7
const AMBUSH_DELAY := 1.0
const SIGHT_RANGE := 14.0
const SIGHT_HALF_ANGLE := 60.0
const FULL_STRENGTH_FRACTION := 0.4
const MIN_STRENGTH := 0.3
const GAIN_PER_SECOND := 0.8
const DECAY_PER_SECOND := 0.25
const DECAY_DELAY := 1.5
const SUSPICIOUS := 0.35
const CHARGE_SPEED := 4.2
const EXIT_X := 1.2
const ROOMS_X := 300.0
const ROOM_GAP := 40.0
const SHOP_ART := ["grocery", "workshop", "cinema"]
## Os objetos de busca da rua (#50), alternados pelos trechos de busca, e o nome de cada um no aviso.
const PROP_NAMES := {"street_crates": "os caixotes", "street_trash_can": "a lixeira", "street_mailbox": "a caixa de correio"}
## Onde ficam na calçada (cm, eixos da Unreal: y é a profundidade, z a altura).
const PROP_Y := -285.0
## Distância mínima (m) entre um objeto de busca da rua e a porta de uma loja.
const PROP_DOOR_CLEARANCE := 1.6
## Folga das pontas de cada zona do cenário (ZoneMargin) e o espaço entre os da fila (PartySpacing).
const ZONE_MARGIN := 0.45
const PARTY_SPACING := 1.3
## Perto da porta de um interior lateral ou de um prop, o aviso aparece.
const REACH := 1.1
## O embarque no trem do tutorial: a que distância (m) da porta do vagão e quanto o trem leva para parar.
const BOARD_REACH := 2.5
const TRAIN_ARRIVAL_SECONDS := 4.0
## Quanto a recompensa fica à vista antes de o vagão partir.
const REWARD_SECONDS := 2.5

## O teto da espera pela troca de herói ao levantar acampamento (ms, pelo relógio; a troca leva uns 0,3 s).
const SWITCH_WAIT_MS := 2000
var street: Node3D
var hud: AHExplorationHud
var guards := {}
var doors: Array = []
var props := {}
var room: AHHouseRoom
var room_guards: Array = []
var busy := false
## O acampamento encenado (#77): a equipe em volta da fogueira enquanto ele estiver ativo.
var camp: AHCampScene
var _room_time := 0.0
var _fight := {}
var _action := Callable()
var _overlays := {}
## Segmentos do corredor neste mapa: {x0, x1, first, steps, length, zone (-1 na rua)}; o atual; os trechos deste mapa.
var segments: Array = []
var segment := 0
var map_first := 0
var map_last := 9
## Interiores laterais: {zone, door_x, door_segment, door_step}; o aberto (índice, -1 fora).
var side_rooms: Array = []
var side_room := -1
## Props do cenário: {prop (índice no corredor), local (no mapa), x, zone, step}.
var scenario_props: Array = []
## O guia das dicas do tutorial (#144; null fora dele) e onde fica o que o aviso de agora usa (null: sem lugar).
var guide: AHTutorialGuide
var _action_where = null


func setup(owner_street: Node3D, exploration_hud: AHExplorationHud) -> void:
	street = owner_street
	hud = exploration_hud
	camp = AHCampScene.new(street)
	add_child(camp)
	hud.event_choice.connect(_on_event_choice)
	hud.event_closed.connect(_on_event_closed)
	hud.camp_food.connect(func(id): _camp_care(id, "food"))
	hud.camp_bandage.connect(func(id): _camp_care(id, "bandage"))
	hud.camp_leave.connect(_on_camp_leave)
	hud.result_continue.connect(_on_result_continue)
	hud.menu_return.connect(_retreat)
	hud.menu_requested.connect(open_menu)
	hud.inventory_requested.connect(open_inventory)
	hud.new_campaign.connect(_new_campaign)
	street._arena.finished.connect(_on_combat_finished)
	doors = street.door_list()
	var campaign: Dictionary = Campaign.state
	if campaign.get("session", {}).get("expedition") == null:
		# Sem expedição a rua não tem o que mostrar: a partida é pela Preparação, na Estação.
		GameFlow.redirect("station")
		return
	var route: Dictionary = campaign.session.expedition.corridor
	_build_segments(campaign)
	R.assign_search_sites(route, doors.map(func(d): return d.step), doors.map(func(d): return d.shop), campaign.session.expedition.get("focus", ""))
	_assign_scenario_props(campaign)
	Campaign.save()
	street.apply_corridor_weather(route.weather)
	_spawn_guards()
	_spawn_props()
	# O trem do tutorial só aparece quando chega (com o trecho dele resolvido, já parado na plataforma).
	if street.scenario and not street.scenario.train.is_empty():
		var last: Dictionary = route.steps[route.steps.size() - 1]
		street.scenario.park_train(last.type == "train" and last.resolved)
	_refresh_doors()
	if route.current_house >= 0:
		_open_room(route.current_house)
	elif street.scenario and int(route.get("current_room", -1)) >= 0 and _side_room_of_zone(int(route.current_room)) >= 0:
		_show_side_room(_side_room_of_zone(int(route.current_room)))
	else:
		_enter_segment(_segment_of(route.index), _step_x(route.index, ARRIVAL_SPOT))
	hud.refresh(campaign)
	var session: Dictionary = campaign.session
	if tutorial():
		guide = AHTutorialGuide.new(self)
		add_child(guide)
	# Reaberto no meio do tutorial: o encontro ou a chegada do trem que ficou pela metade continua.
	var here: Dictionary = route.steps[route.index]
	if tutorial() and not here.resolved and session.result == "" and session.event == null:
		if here.type == "nick":
			_meet_nick.call_deferred()
		elif here.type == "train":
			_reach_platform.call_deferred()
	if session.result != "":
		_show_result()
	elif session.event != null:
		hud.show_event(campaign)
	elif session.screen == "rest" and room != null:
		# Reaberto no meio do acampamento: a equipe já em volta da fogueira, sem o fade.
		room.set_camp_lit(true)
		camp.begin(room, session.expedition.team, true)
		hud.show_camp(campaign, camp)
	elif AHFightRewards.cargo_pending(campaign):
		# Reaberto com o guardião vencido e a carga ainda fechada: as mesmas caixas de antes.
		open_cargo.call_deferred()


## A jornada do tutorial (#144) no Corredor de Contenção (#147).
func tutorial() -> bool:
	return AHTutorial.is_tutorial(Campaign.state)


## Bloqueia o movimento da equipe (painel aberto, transição ou luta).
func blocking() -> bool:
	return busy or hud.modal_open() or street._arena.active or camp.active


func _step_x(index: int, fraction: float) -> float:
	if segments.is_empty():
		return MIN_X + STEP_LENGTH * (index + fraction)
	var part: Dictionary = segments[_segment_of(index)]
	return part.x0 + part.length * (index - part.first + fraction)


func _segment_of(index: int) -> int:
	for part in range(segments.size() - 1, -1, -1):
		if index >= segments[part].first:
			return part
	return 0


## O trecho sob x no segmento atual (na rua, a rua inteira).
func _step_under(x: float) -> int:
	var part: Dictionary = segments[segment]
	return part.first + clampi(floori((x - part.x0) / part.length), 0, part.steps - 1)


## Os segmentos do mapa (SetupScenario): na rua, um só, de 7,8 m por trecho; no cenário, as zonas que não são interior
## lateral, com os trechos do mapa divididos pelo comprimento (pelo menos um em cada; a sobra vai para as maiores).
func _build_segments(campaign: Dictionary) -> void:
	segments.clear()
	side_rooms.clear()
	var expedition: Dictionary = campaign.session.expedition
	if street.scenario == null:
		segments.append({"x0": MIN_X, "x1": 79.0, "first": 0, "steps": 10, "length": STEP_LENGTH, "zone": -1})
		return
	var info := R.phase(expedition.phase_id)
	var transit_map: bool = street.scenario.map_name == info.get("transit", "")
	var step_range := R.step_range(expedition.phase_id, transit_map)
	map_first = step_range[0]
	map_last = step_range[0] + step_range[1] - 1
	var doors: Dictionary = {}
	for door in street.scenario.side_doors:
		doors[int(door.zone)] = float(door.x)
	var total := 0.0
	for zone in street.scenario.zones.size():
		var z: Dictionary = street.scenario.zones[zone]
		var part := {"x0": z.x0 + ZONE_MARGIN, "x1": z.x1 - ZONE_MARGIN, "zone": zone}
		if part.x1 - part.x0 < 3.0:
			continue
		if doors.has(zone):
			side_rooms.append({"zone": zone, "door_x": doors[zone], "x0": part.x0, "x1": part.x1})
			continue
		total += part.x1 - part.x0
		segments.append(part)
	var count: int = step_range[1]
	var counts: Array = []
	var assigned := 0
	# O tutorial diz quantos trechos ficam em cada zona (a luta na sala certa, o trem na plataforma).
	var fixed: Array = AHTutorial.zone_steps() if tutorial() else []
	for i in segments.size():
		counts.append(int(fixed[i]) if i < fixed.size() else maxi(1, roundi(count * (segments[i].x1 - segments[i].x0) / total)))
		assigned += counts[-1]
	while assigned != count and fixed.is_empty():
		var pick := 0
		for i in range(1, segments.size()):
			var per: float = (segments[i].x1 - segments[i].x0) / counts[i]
			var best: float = (segments[pick].x1 - segments[pick].x0) / counts[pick]
			if (per > best) if assigned < count else (counts[i] > 1 and (counts[pick] <= 1 or per < best)):
				pick = i
		if assigned > count and counts[pick] <= 1:
			break
		counts[pick] += 1 if assigned < count else -1
		assigned += 1 if assigned < count else -1
	var first := map_first
	for i in segments.size():
		segments[i].first = first
		segments[i].steps = counts[i]
		segments[i].length = (segments[i].x1 - segments[i].x0) / counts[i]
		first += counts[i]
	for room_entry in side_rooms:
		room_entry.door_segment = 0
		for i in segments.size():
			if room_entry.door_x >= segments[i].x0 and room_entry.door_x <= segments[i].x1:
				room_entry.door_segment = i
		var door_part: Dictionary = segments[room_entry.door_segment]
		room_entry.door_step = door_part.first + clampi(floori((room_entry.door_x - door_part.x0) / door_part.length), 0, door_part.steps - 1)


## Entra num segmento com a frente da fila em front_x (a chegada fica no trecho de entrada).
func _enter_segment(index: int, front_x: float) -> void:
	segment = index
	side_room = -1
	if street.scenario:
		street.set_scenario_zone(segments[index].zone)
		_refresh_security_doors()
		street._place_leader(Vector3(front_x, street.floor_y, street.lane_z))
	else:
		street._place_leader(Vector3(front_x, 0, 0.45))


## Os props do mapa viram pontos de busca: o trecho de cada um é o da posição dele (nos interiores laterais, o da porta).
func _assign_scenario_props(campaign: Dictionary) -> void:
	scenario_props.clear()
	if street.scenario == null:
		return
	var steps: Array = []
	var entries: Array = []
	for local in street.scenario.props.size():
		var prop: Dictionary = street.scenario.props[local]
		var zone: int = street.scenario.zone_at(prop.x)
		var step := -1
		var room_index := _side_room_of_zone(zone)
		if room_index >= 0:
			step = side_rooms[room_index].door_step
		else:
			for i in segments.size():
				if segments[i].zone == zone:
					step = segments[i].first + clampi(floori((prop.x - segments[i].x0) / segments[i].length), 0, segments[i].steps - 1)
		if step < 0:
			continue
		steps.append(step)
		entries.append({"local": local, "x": float(prop.x), "zone": zone, "step": step, "name": prop.name})
	var first := R.assign_scenario_props(campaign, street.scenario.map_name, steps, entries.map(func(e): return e.name))
	for i in entries.size():
		entries[i].prop = first + i
		scenario_props.append(entries[i])
		if campaign.session.expedition.corridor.searched_props.has(first + i):
			street.scenario.open_prop(entries[i].local)


func _side_room_of_zone(zone: int) -> int:
	for i in side_rooms.size():
		if side_rooms[i].zone == zone:
			return i
	return -1


# ---------------------------------------------------------------- montagem

func _spawn_guards() -> void:
	var expedition: Dictionary = Campaign.state.session.expedition
	var route: Dictionary = expedition.corridor
	for index in range(map_first, mini(map_last + 1, route.steps.size())):
		var step: Dictionary = route.steps[index]
		if step.resolved or (step.type != "combat" and step.type != "boss"):
			continue
		var specs := R.corridor_enemies(expedition, index)
		var cards: Array = []
		for i in specs.size():
			var card := _enemy_card(specs[i].enemy_id)
			card.position = _guard_position(index, i)
			cards.append(card)
		var mark := Label3D.new()
		mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mark.no_depth_test = true
		mark.font_size = 96
		mark.outline_size = 18
		mark.pixel_size = 0.005
		mark.visible = false
		street.add_child(mark)
		guards[index] = {"specs": specs, "cards": cards, "meter": 0.0, "unseen": 99.0, "detected": false, "mark": mark}


## Onde fica cada um da patrulha do trecho: na rua, na calçada; no cenário, no piso e na faixa da zona do trecho.
func _guard_position(index: int, order: int) -> Vector3:
	var x := _step_x(index, GUARD_SPOT) + order * 1.35
	if street.scenario == null:
		return Vector3(x, 0, -0.8 - 0.03 * order)
	var zone: Dictionary = street.scenario.zones[segments[_segment_of(index)].zone]
	return Vector3(x, zone.y, (zone.z0 + zone.z1) * 0.5 - 0.55 - 0.03 * order)


func _enemy_card(enemy_id: String) -> AHSpriteCard:
	var card := AHSpriteCard.new()
	card.body_height = AHCharacterHeights.find(enemy_id)
	card.show_art(street._combat_art.enemies[enemy_id].idle)
	card.set_facing(-1.0)
	street.add_child(card)
	return card


func _spawn_props() -> void:
	if street.scenario:
		return
	var route: Dictionary = Campaign.state.session.expedition.corridor
	var order := 0
	for index in route.steps.size():
		if route.steps[index].type != "loot":
			continue
		# O mesmo trecho sempre com o mesmo objeto (pela ordem dele entre os trechos de busca), aberto se já foi vasculhado.
		var prop := AHSearchProp.new().setup(AHSearchProp.street_prop(order), route.props.get(str(index), false))
		order += 1
		var x := _prop_x(_step_x(index, 0.45))
		prop.position = AHStreetSet.ue(x * 100.0, PROP_Y, AHStreetSet.SIDEWALK_TOP_Z)
		street.add_child(prop)
		props[index] = prop
		var box := prop.volume()
		var body: StaticBody3D = street._dynamic.add_collider(box.get_center(), box.size)
		# Posta depois de street._collect_set: a caixa entra à mão na lista da tecla C e do _free_spot.
		var debug: MeshInstance3D = body.get_node("DebugBox")
		debug.visible = not street._debug_colliders.is_empty() and street._debug_colliders[0].visible
		street._debug_colliders.append(debug)


## Onde o objeto de busca da rua fica: o ponto do trecho, ou o mais perto dele que está longe das portas das lojas (o
## objeto tapava a porta e os dois avisos disputavam o lugar) e dos objetos pintados da calçada.
func _prop_x(wanted: float) -> float:
	for step in 13:
		var x := wanted + 0.5 * ceilf(step / 2.0) * (1.0 if step % 2 == 0 else -1.0)
		var clear := doors.all(func(door): return absf(float(door.x) - x) >= PROP_DOOR_CLEARANCE)
		for painted in AHStreetSet.SIDEWALK_PROPS:
			var half: float = painted[4] * painted[1].size.x / painted[1].size.y * 0.005
			if absf(painted[2] * 0.01 - x) < half + 0.6:
				clear = false
		if clear:
			return x
	return wanted


## Portas das casas abertas (e da trancada depois de arrombada) com a pintura da porta aberta.
func _refresh_doors() -> void:
	var route: Dictionary = Campaign.state.session.expedition.corridor
	for i in route.sites.size():
		var site: Dictionary = route.sites[i]
		if _overlays.has(i) or (site.locked and not site.forced):
			continue
		var door: Dictionary = doors[site.door]
		var rect: Rect2 = AHStreetSet.DOOR_OVERLAYS[site.shop]
		var scale: float = AHStreetSet.FACADE_WIDTH / 1536.0
		var base: float = AHStreetSet.SIDEWALK_TOP_Z + (1024.0 - (rect.position.y + rect.size.y)) * scale
		var card: MeshInstance3D = street._dynamic.add_card("door-open-%s-crop.png" % SHOP_ART[site.shop], Rect2(),
			Vector3(door.x * 100.0, AHStreetSet.FACADE_FRONT_Y + 2, base), rect.size.y * scale, 0.0, door.mirror, false, true)
		_overlays[i] = card


# ---------------------------------------------------------------- quadro a quadro

func _process(delta: float) -> void:
	if street == null or street.capture_paused():
		return
	if blocking():
		hud.show_prompt("")
		return
	var campaign: Dictionary = Campaign.state
	if not R.in_corridor(campaign):
		return
	var route: Dictionary = campaign.session.expedition.corridor
	if room != null:
		_room_time += delta
		_house_frame(campaign, route)
	elif side_room >= 0:
		_side_room_frame(campaign, route)
	else:
		_street_frame(campaign, route, delta)


func _street_frame(campaign: Dictionary, route: Dictionary, delta: float) -> void:
	var leader: Vector3 = street._leader.position
	var part: Dictionary = segments[segment]
	# Trecho por vencer: a equipe não passa da patrulha.
	var high: float = part.x1 if route.steps[route.index].resolved else _step_x(route.index, 1.0) - EDGE_MARGIN
	street.walk_max.x = high
	if street.scenario:
		street.walk_min.x = part.x0
		# No fim da zona, com o último trecho dela vencido, segue para a próxima; no começo, volta para a anterior.
		var last: int = part.first + part.steps - 1
		if leader.x >= part.x1 - 0.15 and route.index == last and route.steps[last].resolved:
			if segment < segments.size() - 1:
				_travel_segment(1)
				return
			if last == map_last and map_last < route.steps.size() - 1:
				_travel_map(campaign, map_last + 1)
				return
		# No tutorial as portas baixam atrás da equipe: não há volta.
		if leader.x <= part.x0 + 0.15 and segment > 0 and not tutorial():
			_travel_segment(-1)
			return
	var under := _step_under(leader.x)
	if under != route.index:
		var next: int = route.index + (1 if under > route.index else -1)
		var was_resolved: bool = route.steps[next].resolved
		var outcome := R.enter_step(campaign, next)
		if route.index == next:
			Campaign.save()
			_announce(next, outcome, not was_resolved)
			hud.refresh(campaign)
			# A Passagem com o evento de história da fase (#64): ele abre ali mesmo.
			if outcome == "event":
				hud.show_event(campaign)
			elif outcome == "nick":
				_meet_nick()
			elif outcome == "train":
				_reach_platform()
	for index in [route.index, route.index + 1]:
		if guards.has(index) and _segment_of(index) == segment and _sight_frame(index, delta, leader):
			return
	var ahead = null
	for index in [route.index, route.index + 1]:
		if guards.has(index) and _segment_of(index) == segment:
			ahead = guards[index]
			break
	if ahead != null:
		hud.set_patrol(ahead.cards[0].global_position + Vector3(0, 1.5, 0), ahead.meter, ahead.detected)
	else:
		hud.set_patrol(null, 0.0, false)
	_choose_action(campaign, route, leader)


## A próxima (ou a anterior) zona do mapa, com fade: chega dentro do trecho de entrada, longe do inimigo dele.
func _travel_segment(direction: int) -> void:
	var to := segment + direction
	busy = true
	var area: String = street.scenario.zones[segments[to].zone].name
	hud.toast(tr("Seguindo em frente…") if area == "passagem" else tr("Seguindo para: %s…") % tr(area), 2.0)
	await GameFlow.fade(1.0)
	var part: Dictionary = segments[to]
	var entry: int = part.first if direction > 0 else part.first + part.steps - 1
	_enter_segment(to, _step_x(entry, ARRIVAL_SPOT if direction > 0 else 1.0 - ARRIVAL_SPOT))
	await GameFlow.fade(0.0)
	busy = false
	# A porta de segurança baixa atrás da equipe (#147): o estrondo, sem volta.
	if tutorial() and direction > 0:
		Sound.play("res://audio/world/security_door.ogg")


## Fim do mapa de passagem: a equipe entra no primeiro trecho do mapa da fase e viaja para ele (só de ida).
func _travel_map(campaign: Dictionary, next: int) -> void:
	busy = true
	R.enter_step(campaign, next)
	Campaign.save()
	# O cartão da passagem diz para onde a equipe segue (o lugar da fase e o trecho).
	GameFlow.travel("street")


## Visão e suspeita do guarda do trecho; true se a luta começou.
func _sight_frame(index: int, delta: float, leader: Vector3) -> bool:
	var guard: Dictionary = guards[index]
	var front: AHSpriteCard = guard.cards[0]
	var strength := _sight_strength(front, leader)
	if strength > 0.0:
		Tips.show_tip("patrol")
		guard.meter = minf(1.0, guard.meter + GAIN_PER_SECOND * strength * delta)
		guard.unseen = 0.0
	else:
		guard.unseen += delta
		if guard.unseen > DECAY_DELAY:
			guard.meter = maxf(0.0, guard.meter - DECAY_PER_SECOND * delta)
	if guard.meter >= 1.0:
		guard.detected = true
	elif guard.meter < SUSPICIOUS:
		guard.detected = false
	var mark: Label3D = guard.mark
	mark.visible = guard.meter > 0.05
	mark.text = "!" if guard.detected else "?"
	mark.modulate = Color(1.0, 0.25, 0.2) if guard.detected else Color(1.0, 0.85, 0.3, clampf(guard.meter / SUSPICIOUS, 0.3, 1.0))
	mark.global_position = front.global_position + Vector3(0, front.head_height() + 0.6, 0)
	# Detectado: a patrulha avança sobre a equipe.
	if guard.detected and index == Campaign.state.session.expedition.corridor.index:
		for card in guard.cards:
			card.position.x -= CHARGE_SPEED * delta
	if index == Campaign.state.session.expedition.corridor.index and absf(front.position.x - leader.x) < CONTACT:
		_start_fight(index, not guard.detected)
		return true
	return false


## Força do avistamento (0 = não vê): distância, cone e linha de visão até o líder.
func _sight_strength(front: AHSpriteCard, leader: Vector3) -> float:
	var eye := front.global_position + Vector3(0, front.body_height * 0.8, 0)
	var target := leader + Vector3(0, 1.0, 0)
	var to_target := target - eye
	var sight_range: float = SIGHT_RANGE * street.sight_multiplier()
	var distance := to_target.length()
	if distance > sight_range:
		return 0.0
	var flat := Vector2(to_target.x, to_target.z)
	var facing := Vector2(front.facing, 0)
	if flat.length() > 0.01 and rad_to_deg(absf(facing.angle_to(flat.normalized()))) > SIGHT_HALF_ANGLE:
		return 0.0
	var query := PhysicsRayQueryParameters3D.create(eye, target)
	query.exclude = [street._leader.get_rid()]
	if not street.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return 0.0
	var fraction := distance / sight_range
	if fraction <= FULL_STRENGTH_FRACTION:
		return 1.0
	return lerpf(1.0, MIN_STRENGTH, (fraction - FULL_STRENGTH_FRACTION) / (1.0 - FULL_STRENGTH_FRACTION))


func _announce(index: int, outcome: String, first_time: bool) -> void:
	var route: Dictionary = Campaign.state.session.expedition.corridor
	var label: String = AHExplorationHud.STEP_LABELS.get(route.steps[index].type, "")
	match outcome:
		"rest":
			var camp: int = route.sites.map(func(s): return s.camp_site).find(true)
			var where := ""
			if camp >= 0:
				where = tr(" O acampamento fica %s do trecho %d.") % [(tr("no cinema") if route.sites[camp].shop == 2 else tr("na ") + tr(R.SHOP_NAMES[route.sites[camp].shop])), route.sites[camp].step + 1]
			hud.toast(tr("Trecho %d · Descanso. Um lugar quieto.%s") % [index + 1, where], 5.0)
			_ask_risk("rest", tr("Um lugar quieto"), tr("A equipe para no descanso.%s Daqui dá para seguir até o guardião ou voltar à Estação com metade do achado.") % where)
		"combat", "boss":
			hud.toast(tr("Trecho %d · %s à frente. Chegue sem ser visto para agir primeiro.") % [index + 1, tr(label)])
			if outcome == "boss":
				_ask_risk("boss", tr("O guardião está à frente"), tr("Vencer o guardião conclui a fase e leva todo o achado. Se a equipe cair, o achado fica para trás; voltar agora leva metade."))
		_:
			if first_time:
				hud.toast(tr("Trecho %d · %s") % [index + 1, tr(label)], 2.5)


## A pergunta de risco, uma vez por jornada em cada ponto: seguir com a equipe como está ou voltar com metade.
func _ask_risk(key: String, title: String, text: String) -> void:
	var expedition: Dictionary = Campaign.state.session.expedition
	var asked: Array = expedition.get("asked", [])
	if asked.has(key) or street._capture_dir != "" or expedition.objective_completed:
		return
	asked.append(key)
	expedition.asked = asked
	Campaign.save()
	hud.show_choice(title, text, [[tr("Seguir em frente"), func(): pass],
		[tr("Voltar à Estação (metade do achado)"), _retreat]])


# ---------------------------------------------------------------- interações

func _choose_action(campaign: Dictionary, route: Dictionary, leader: Vector3) -> void:
	var text := ""
	var action := Callable()
	var where = null
	var best := 1.3
	for i in route.sites.size():
		var site: Dictionary = route.sites[i]
		var distance := absf(doors[site.door].x - leader.x)
		if distance >= best or site.step > route.index:
			continue
		var shop := R.shop_the(site.shop)
		where = _door_point(site)
		if R.can_enter_house(campaign, i):
			text = tr("E  Entrar n%s") % shop
			action = _enter_house.bind(i)
		elif R.can_force_house(campaign, i):
			text = tr("E  Arrombar a porta d%s (o pé de cabra quebra)") % shop
			action = _force_house.bind(i)
		elif site.locked and not site.forced:
			text = tr("Porta trancada · Precisa de um pé de cabra para arrombar")
			action = Callable()
		best = distance
	for index in props:
		if absf(props[index].position.x - leader.x) < best and index <= route.index and not route.props.get(str(index), false):
			best = absf(props[index].position.x - leader.x)
			text = tr("E  Vasculhar %s") % tr(PROP_NAMES[props[index].prop_name])
			action = _search_prop.bind(index)
			where = _prop_point(index)
	if street.scenario:
		best = REACH
		for entry in scenario_props:
			if entry.zone != segments[segment].zone or absf(entry.x - leader.x) >= best:
				continue
			best = absf(entry.x - leader.x)
			where = _scenario_prop_point(entry)
			if route.searched_props.has(entry.prop):
				text = tr("%s (já vasculhado)") % tr(entry.name)
				action = Callable()
			elif R.can_search_scenario_prop(campaign, entry.prop):
				text = tr("E  Vasculhar: %s") % tr(entry.name)
				action = _search_scenario_prop.bind(entry)
		for i in side_rooms.size():
			var room_entry: Dictionary = side_rooms[i]
			if room_entry.door_segment != segment or absf(room_entry.door_x - leader.x) >= best:
				continue
			best = absf(room_entry.door_x - leader.x)
			where = _side_door_point(room_entry)
			var area: String = street.scenario.zones[room_entry.zone].name
			if R.can_enter_scenario_room(campaign, room_entry.door_step):
				text = tr("E  Entrar: %s") % tr(area)
				action = _enter_side_room.bind(i)
			else:
				text = tr("%s · a patrulha guarda a porta") % tr(area)
				action = Callable()
	var exit_x: float = EXIT_X if street.scenario == null else segments[0].x0 + EXIT_X
	# No cenário, com o guardião vencido, a volta vale de qualquer ponto (RequestExpeditionReturn da Unreal).
	var done_here: bool = street.scenario != null and campaign.session.expedition.objective_completed and text == ""
	if tutorial():
		_tutorial_action(campaign, route, leader, text, action, where)
		return
	if done_here or (leader.x < exit_x and segment == 0 and map_first == 0):
		text = tr("E  Voltar à Estação (%s)") % (tr("fase concluída: todo o achado") if campaign.session.expedition.objective_completed else tr("retirada: metade do achado"))
		action = _retreat
		where = null
	hud.show_prompt(text, where)
	if text.begins_with(tr("E  Vasculhar")):
		Tips.show_tip("search")
	_action = action
	_action_where = where
	hud.set_markers(_marker_points(campaign, route, leader, where))


## O aviso e as marcas no tutorial: sem a volta à Estação pelo começo (as portas baixaram atrás); na plataforma, com o
## trem parado, o embarque.
func _tutorial_action(campaign: Dictionary, route: Dictionary, leader: Vector3, text: String, action: Callable, where) -> void:
	var boarding = _train_point()
	if boarding != null and absf(boarding.x - leader.x) < BOARD_REACH:
		text = tr("E  Embarcar no trem")
		action = _board_train
		where = boarding
	hud.show_prompt(text, where)
	if text.begins_with(tr("E  Vasculhar")):
		Tips.show_tip("search")
	_action = action
	_action_where = where
	var points := _marker_points(campaign, route, leader, where)
	if boarding != null and where != boarding and absf(boarding.x - leader.x) < 14.0:
		points.append(boarding)
	hud.set_markers(points)


## Onde fica o que o aviso de agora usa (o armário, a porta do vagão), ou null.
func _action_point():
	return _action_where


## A porta do vagão onde se embarca (a marca), ou null fora da plataforma ou com o trem ainda chegando.
func _train_point():
	if street.scenario == null or street.scenario.train.is_empty() or segments.is_empty():
		return null
	var route: Dictionary = Campaign.state.session.expedition.corridor
	var step: Dictionary = route.steps[route.index]
	if segments[segment].zone != int(street.scenario.train.zone) or step.type != "train" or not step.resolved:
		return null
	return Vector3(float(street.scenario.train.x), street.floor_y + 2.6, street.lane_z - 1.2)


## As portas de segurança da zona: a de entrada baixada (a equipe veio por ela) e a de saída aberta só com os trechos da
## zona vencidos. sound: toca a porta que abriu agora.
func _refresh_security_doors(sound: bool = false) -> void:
	if street.scenario == null or street.scenario.security_doors.is_empty() or segments.is_empty():
		return
	var route: Dictionary = Campaign.state.session.expedition.corridor
	var part: Dictionary = segments[segment]
	var done := true
	for step in range(part.first, mini(part.first + part.steps, route.steps.size())):
		done = done and route.steps[step].resolved
	for index in street.scenario.doors_of(part.zone, "entry"):
		street.scenario.set_door(index, false)
	# O painel da sala das celas: a alavanca embaixo, depois que as portas baixaram atrás da equipe.
	street.scenario.set_panel_down(part.zone >= int(street.scenario.door_panel.get("zone", 0)))
	for index in street.scenario.doors_of(part.zone, "exit"):
		if sound and done and not street.scenario.door_open(index):
			Sound.play("res://audio/world/security_door_open.ogg")
		street.scenario.set_door(index, done)


## O encontro com o Nick (o tutorial): ele aparece adiante, a conversa curta com o retrato (a caixa do briefing, #88) e
## ele entra na equipe; o trecho fica resolvido. Fechar o jogo no meio da conversa repete o encontro.
func _meet_nick() -> void:
	if busy:
		return
	busy = true
	var team: Array = Campaign.state.session.expedition.team.duplicate()
	var arriving: Array = AHTutorial.journey().get("JoinTeam", []).filter(func(id): return not team.has(id))
	for hero_id in arriving:
		street.add_hero(hero_id, Vector3(street._leader.position.x + 2.2, street.floor_y, street.lane_z - 0.6))
	var lines := AHBriefing.departure(Campaign.state, "tutorial_nick", team + arriving)
	if not lines.is_empty() and street._capture_dir == "":
		var dialog := AHBriefingDialog.open(hud, lines, tr("Seguir"))
		await dialog.finished
	AHTutorial.join(Campaign.state)
	Campaign.save()
	busy = false
	hud.refresh(Campaign.state)
	_refresh_security_doors(true)


## Recuou de uma luta do tutorial: a equipe volta inteira um pouco antes da patrulha, que retoma o posto.
func _restart_fight() -> void:
	street.end_fight()
	var index: int = _fight.get("index", -1)
	for hero_id in Campaign.state.session.expedition.team:
		var hero = Campaign.hero(hero_id)
		if hero != null:
			hero.hp = int(hero.max_hp)
			hero.alive = true
	if guards.has(index):
		var guard: Dictionary = guards[index]
		for i in guard.cards.size():
			var card: AHSpriteCard = guard.cards[i]
			card.position = _guard_position(index, i)
			card.show_art(street._combat_art.enemies[guard.specs[i].enemy_id].idle)
			card.set_facing(-1.0)
			card.set_tint(Color.WHITE)
			card.visible = true
		guard.meter = 0.0
		guard.detected = false
		street._place_leader(Vector3(_step_x(index, 0.05), street.floor_y, street.lane_z))
	street.remove_dead_heroes()
	if guide != null:
		guide.event("fight_end")
	Campaign.save()
	hud.refresh(Campaign.state)
	hud.toast(tr("A equipe recua e se recompõe. A patrulha continua no caminho: tente de novo."), 4.0)


## A plataforma: o trem chega (o som e o vagão entrando no fosso) e para com as portas abertas.
func _reach_platform() -> void:
	busy = true
	Sound.play("res://audio/station/train_arrival.ogg")
	await street.scenario.arrive_train(TRAIN_ARRIVAL_SECONDS)
	AHTutorial.resolve_step(Campaign.state, "train")
	Campaign.save()
	busy = false
	hud.refresh(Campaign.state)
	if guide != null:
		guide.event("platform")


## O embarque: a recompensa da fuga à vista (o que se ganhou voa para o alto, #143), e o vagão leva a equipe à Estação,
## que abre com a chegada, o debriefing do Bento e do Nick e o relatório.
func _board_train() -> void:
	if busy:
		return
	busy = true
	if guide != null:
		guide.event("board")
	Sound.play("res://audio/station/train_bell.ogg")
	var team: Array = Campaign.state.session.expedition.team.duplicate()
	var prize := AHTutorial.complete(Campaign.state)
	Tips.mark_seen(AHTutorial.COVERED_TIPS)
	Campaign.save()
	var gains: Array = []
	if int(prize.seeds) > 0:
		gains.append(["lobby-seed", "+%d %s" % [prize.seeds, tr("sementes")]])
	if int(prize.bandages) > 0:
		gains.append(["res-bandages", "+%d %s" % [prize.bandages, tr("curativo") if int(prize.bandages) == 1 else tr("curativos")]])
	if prize.tool != "":
		gains.append([AHInventoryPanel.TOOL_ICONS.get(prize.tool, "tool-generic"), tr(AHInventoryPanel.TOOL_NAMES.get(prize.tool, prize.tool))])
	hud.loot_burst(gains, street._leader.global_position + Vector3(0, 1.9, 0))
	hud.toast(tr("Recompensa da fuga: %s.") % ", ".join(gains.map(func(g): return g[1])), REWARD_SECONDS)
	await get_tree().create_timer(REWARD_SECONDS if street._capture_dir == "" else 0.1).timeout
	var card: Dictionary = GameFlow.card_for("station")
	card.backdrop = AHWagonRide.new(team)
	card.title_delay = AHWagonRide.RIDE_SECONDS
	card.hold = AHWagonRide.RIDE_SECONDS + GameFlow.CARD_SECONDS
	GameFlow.travel("station", card)


## Onde fica, no mundo, a marca de cada coisa usável: a porta da loja, os caixotes, os props e as portas dos cenários.
func _door_point(site: Dictionary) -> Vector3:
	return Vector3(doors[site.door].x, 2.6, -0.7)


func _prop_point(index: int) -> Vector3:
	return props[index].marker_point()


func _scenario_prop_point(entry: Dictionary) -> Vector3:
	return Vector3(entry.x, street.floor_y + 1.9, street.lane_z - 0.7)


func _side_door_point(room_entry: Dictionary) -> Vector3:
	return Vector3(room_entry.door_x, street.floor_y + 2.6, street.lane_z - 0.9)


## Os losangos do HUD: o que dá para usar a até 14 m da equipe, menos o que já está ao alcance (esse ganha o aviso).
func _marker_points(campaign: Dictionary, route: Dictionary, leader: Vector3, active) -> Array:
	var points: Array = []
	for i in route.sites.size():
		var site: Dictionary = route.sites[i]
		if site.step <= route.index and (R.can_enter_house(campaign, i) or R.can_force_house(campaign, i)):
			points.append(_door_point(site))
	for index in props:
		if index <= route.index and not route.props.get(str(index), false):
			points.append(_prop_point(index))
	if street.scenario:
		for entry in scenario_props:
			if entry.zone == segments[segment].zone and R.can_search_scenario_prop(campaign, entry.prop):
				points.append(_scenario_prop_point(entry))
		for room_entry in side_rooms:
			if room_entry.door_segment == segment and R.can_enter_scenario_room(campaign, room_entry.door_step):
				points.append(_side_door_point(room_entry))
	return points.filter(func(p): return absf(p.x - leader.x) < 14.0 and (active == null or p.distance_to(active) > 0.05))


func _house_frame(campaign: Dictionary, route: Dictionary) -> void:
	var site: Dictionary = route.sites[route.current_house]
	if site.has_enemy and not site.enemy_defeated and not room_guards.is_empty() and _room_time > AMBUSH_DELAY:
		# Patrulha dentro da loja: emboscada logo depois de entrar (os inimigos agem primeiro).
		hud.toast(tr("Emboscada!"), 1.5)
		_start_fight(R.HOUSE_ENEMY_INDEX + route.current_house, false)
		return
	var leader: Vector3 = street._leader.position
	var text := ""
	var action := Callable()
	var best := 0.9
	var where = null
	for i in room.spot_xs.size():
		var distance := absf(room.spot_xs[i] - leader.x)
		if distance < best:
			best = distance
			var name: String = R.SPOT_NAMES[site.shop][i] if i < 3 else "o canto"
			where = room.search_props[i].marker_point() if i < room.search_props.size() else null
			if site.spots[i].searched:
				text = tr("%s (já vasculhado)") % tr(name).capitalize()
				action = Callable()
			else:
				text = tr("E  Vasculhar %s") % tr(name)
				action = _search_spot.bind(route.current_house, i)
	if site.camp_site and absf(room.camp_x - leader.x) < best:
		if R.can_start_camp(campaign):
			text = tr("E  Acampar (fechar a porta e acender a fogueira)")
			action = _start_camp
		elif site.camped:
			text = tr("Acampamento já feito nesta fase")
			action = Callable()
		where = null
	if leader.x < room.exit_x:
		text = tr("E  Sair para a rua")
		action = _leave_house
		where = null
	hud.show_prompt(text, where)
	# O losango de cada objeto ainda fechado fica sobre ele (#50); o do que está ao alcance vira o do aviso.
	var points: Array = []
	for i in mini(room.search_props.size(), site.spots.size()):
		if not site.spots[i].searched and (where == null or room.search_props[i].marker_point().distance_to(where) > 0.05):
			points.append(room.search_props[i].marker_point())
	hud.set_markers(points)
	hud.set_patrol(null, 0.0, false)
	_action = action


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") and not busy and not street._arena.active:
		get_viewport().set_input_as_handled()
		if hud.menu_shown():
			# Esc fecha o menu (e só ele: o resultado e os eventos pedem uma escolha).
			hud.close_modal()
		else:
			open_menu()
		return
	if event.is_action_pressed("inventory") and not busy and not street._arena.active:
		get_viewport().set_input_as_handled()
		if hud.inventory_shown():
			hud.close_modal()
		else:
			open_inventory()
		return
	if event.is_action_pressed("interact") and not blocking() and _action.is_valid() and not Tips.showing():
		get_viewport().set_input_as_handled()
		var action := _action
		_action = Callable()
		action.call()


## O menu da exploração (Esc ou o botão): continuar, voltar à Estação ou começar uma campanha nova.
func open_menu() -> void:
	# No acampamento também (#98): voltar à Estação e as Opções não podem esperar o levantar acampamento.
	if busy or street._arena.active or hud.modal_open() or camp.switching():
		return
	var session: Dictionary = Campaign.state.session
	if not AHExplorationHud.session_open(Campaign.state):
		return
	if tutorial():
		# Na abertura a volta é o trem: o menu fica com as Opções e a campanha nova.
		hud.show_menu(false, false, tr("Na abertura, a saída é o trem da plataforma."))
		return
	hud.show_menu(session.expedition.objective_completed, session.get("event") == null and ["corridor", "rest"].has(session.get("screen")))


## A Mochila da exploração (I ou o botão): fora de luta, evento e resultado.
func open_inventory() -> void:
	if busy or street._arena.active or hud.modal_open() or camp.switching() or not AHExplorationHud.session_open(Campaign.state):
		return
	Sound.play("res://audio/ui/bag_open.ogg")
	hud.show_inventory()
	Tips.show_tip("bag")
	if guide != null:
		guide.event("bag")


func _new_campaign() -> void:
	# A campanha nova passa pela escolha do título (#144): a abertura ou Pular tutorial, no mesmo espaço.
	GameFlow.travel("title", {}, {"new_campaign": Campaign.slot})


func _search_scenario_prop(entry: Dictionary) -> void:
	var objective_before: bool = Campaign.state.session.expedition.get("objective_done", false)
	var stock := _loot_snapshot()
	var result := R.search_scenario_prop(Campaign.state, entry.prop, entry.name)
	if result.ok:
		# O prop que abre faz o clique de metal; o achado do objetivo, as moedas; o resto, o pano.
		_search_sound(objective_before, int(street.scenario.props[entry.local].open) >= 0)
		_show_gains(stock)
		street.scenario.open_prop(entry.local)
		if guide != null:
			guide.event("searched")
		Campaign.save()
		hud.refresh(Campaign.state)
		# O objeto com escolha abre o evento ali mesmo (#7).
		if result.event != "":
			hud.show_event(Campaign.state)
		else:
			hud.toast("%s: %s" % [tr(entry.name), result.text], 5.0)


# ---------------------------------------------------------------- interiores laterais dos cenários

func _enter_side_room(index: int) -> void:
	var room_entry: Dictionary = side_rooms[index]
	if not R.enter_scenario_room(Campaign.state, room_entry.zone, room_entry.door_step):
		return
	busy = true
	Campaign.save()
	Sound.play("res://audio/world/door_open.ogg")
	hud.toast(tr("Entrando: %s…") % tr(street.scenario.zones[room_entry.zone].name), 1.5)
	await GameFlow.fade(1.0)
	_show_side_room(index)
	await GameFlow.fade(0.0)
	busy = false


func _show_side_room(index: int) -> void:
	side_room = index
	var room_entry: Dictionary = side_rooms[index]
	street.set_scenario_zone(room_entry.zone)
	street._place_leader(Vector3(room_entry.x0 + 1.6, street.floor_y, street.lane_z))


func _side_room_frame(campaign: Dictionary, route: Dictionary) -> void:
	var room_entry: Dictionary = side_rooms[side_room]
	var leader: Vector3 = street._leader.position
	var text := ""
	var action := Callable()
	var best := REACH
	for entry in scenario_props:
		if entry.zone != room_entry.zone or absf(entry.x - leader.x) >= best:
			continue
		best = absf(entry.x - leader.x)
		if route.searched_props.has(entry.prop):
			text = tr("%s (já vasculhado)") % tr(entry.name)
		elif R.can_search_scenario_prop(campaign, entry.prop):
			text = tr("E  Vasculhar: %s") % tr(entry.name)
			action = _search_scenario_prop.bind(entry)
	if leader.x < room_entry.x0 + EXIT_X:
		text = tr("E  Voltar: %s") % tr(street.scenario.zones[segments[room_entry.door_segment].zone].name)
		action = _leave_side_room
	hud.show_prompt(text)
	hud.set_markers([])
	hud.set_patrol(null, 0.0, false)
	_action = action


func _leave_side_room() -> void:
	var room_entry: Dictionary = side_rooms[side_room]
	if not R.leave_scenario_room(Campaign.state):
		return
	busy = true
	Campaign.save()
	Sound.play("res://audio/world/door_close.ogg")
	await GameFlow.fade(1.0)
	_enter_segment(room_entry.door_segment, room_entry.door_x)
	await GameFlow.fade(0.0)
	busy = false


func _search_prop(index: int) -> void:
	var objective_before: bool = Campaign.state.session.expedition.get("objective_done", false)
	var stock := _loot_snapshot()
	var result := R.search_prop(Campaign.state, index)
	if result.ok:
		_search_sound(objective_before, false)
		_show_gains(stock)
		props[index].set_open(true)
		Campaign.save()
		hud.toast(result.text, 5.0)
		hud.refresh(Campaign.state)


func _force_house(site_index: int) -> void:
	if R.force_house(Campaign.state, site_index):
		Campaign.save()
		_refresh_doors()
		hud.toast(tr("O pé de cabra entorta e quebra, mas a porta cede."))
		hud.refresh(Campaign.state)


func _retreat() -> void:
	# No tutorial não há retirada: a saída é o trem.
	if tutorial():
		return
	# Com a carga do guardião na tela, só sai depois de escolher e fechar (a carga não se perde).
	if busy or AHFightRewards.cargo_pending(Campaign.state):
		return
	if not R.safe_retreat(Campaign.state):
		return
	# Voltar à Estação de dentro do acampamento: a cena da fogueira fecha antes do resultado.
	if camp.active:
		busy = true
		hud.hide_camp()
		await camp.end()
		room.set_camp_lit(false)
		busy = false
	_show_result()


# ---------------------------------------------------------------- casas

func _enter_house(site_index: int) -> void:
	busy = true
	await GameFlow.fade(1.0)
	if R.enter_house(Campaign.state, site_index):
		Campaign.save()
		Sound.play("res://audio/world/door_open.ogg")
		_open_room(site_index)
	await GameFlow.fade(0.0)
	busy = false
	hud.refresh(Campaign.state)


func _open_room(site_index: int) -> void:
	var expedition: Dictionary = Campaign.state.session.expedition
	var site: Dictionary = expedition.corridor.sites[site_index]
	room = AHHouseRoom.new()
	room.debug_material = street._debug_material
	street.add_child(room)
	room.build(site.shop, ROOMS_X + site_index * ROOM_GAP, site.spots.size(), site.camp_site, site.spots.map(func(spot): return spot.searched))
	var showing: bool = not street._debug_colliders.is_empty() and street._debug_colliders[0].visible
	for debug in room.debug_colliders:
		debug.visible = showing
		street._debug_colliders.append(debug)
	street.set_indoor(true, room.position.x, AHHouseRoom.WIDTH)
	street.occlusion.scan(room)
	street._place_leader(Vector3(room.entrance_x, 0, -0.5))
	_room_time = 0.0
	room_guards.clear()
	if site.has_enemy and not site.enemy_defeated:
		var specs := R.corridor_enemies(expedition, R.HOUSE_ENEMY_INDEX + site_index)
		for i in specs.size():
			var card := _enemy_card(specs[i].enemy_id)
			card.position = Vector3(room.guard_x + i * 1.35, 0, -0.8 - 0.03 * i)
			room_guards.append(card)


func _leave_house() -> void:
	busy = true
	await GameFlow.fade(1.0)
	var route: Dictionary = Campaign.state.session.expedition.corridor
	var site: Dictionary = route.sites[route.current_house]
	if R.leave_house(Campaign.state):
		Campaign.save()
		Sound.play("res://audio/world/door_close.ogg")
		_close_room()
		street._place_leader(Vector3(doors[site.door].x, 0, 0.45))
	await GameFlow.fade(0.0)
	busy = false
	hud.refresh(Campaign.state)


func _close_room() -> void:
	for card in room_guards:
		card.queue_free()
	room_guards.clear()
	if room != null:
		street.occlusion.forget(room)
		for debug in room.debug_colliders:
			street._debug_colliders.erase(debug)
		room.queue_free()
	room = null
	street.set_indoor(false)


func _search_spot(site_index: int, spot_index: int) -> void:
	var objective_before: bool = Campaign.state.session.expedition.get("objective_done", false)
	var stock := _loot_snapshot()
	var result := R.search_spot(Campaign.state, site_index, spot_index)
	if not result.ok:
		return
	if spot_index < room.search_props.size():
		room.search_props[spot_index].set_open(true)
	_search_sound(objective_before, false)
	_show_gains(stock)
	Campaign.save()
	hud.refresh(Campaign.state)
	if result.event != "":
		hud.show_event(Campaign.state)
	else:
		hud.toast(result.text, 5.0)


## O que a equipe tem agora (para mostrar o que uma busca trouxe).
func _loot_snapshot() -> Dictionary:
	var expedition: Dictionary = Campaign.state.session.expedition
	return {"seeds": int(expedition.loot.seeds), "scrap": int(expedition.loot.scrap), "fragments": int(expedition.loot.fragments),
		"food": int(expedition.food), "bandages": int(Campaign.state.inventory.bandages), "tools": Campaign.state.get("tools", []).size()}


## A diferença vira o efeito do achado no HUD (só o que subiu).
func _show_gains(before: Dictionary) -> void:
	var after := _loot_snapshot()
	var gains: Array = []
	for spec in [["seeds", "lobby-seed", "semente", "sementes"], ["scrap", "lobby-scrap", "sucata", "sucatas"],
			["fragments", "lobby-fragment", "fragmento", "fragmentos"], ["food", "lobby-food", "comida", "comidas"],
			["bandages", "res-bandages", "curativo", "curativos"], ["tools", "tool-generic", "ferramenta", "ferramentas"]]:
		var delta: int = after[spec[0]] - before[spec[0]]
		if delta > 0:
			gains.append([spec[1], "+%d %s" % [delta, tr(spec[2]) if delta == 1 else tr(spec[3])]])
	hud.loot_burst(gains, street._leader.global_position + Vector3(0, 1.9, 0))
	# O achado raro (fragmento ou ferramenta) tem o brilho dele por cima do som da busca (#36).
	if after.fragments > before.fragments or after.tools > before.tools:
		Sound.play("res://audio/world/find_rare.ogg")


## O som da busca (como na Unreal): moedas quando ela cumpriu o objetivo da rota, o clique de metal num prop que abre,
## o pano no resto.
func _search_sound(objective_before: bool, opens: bool) -> void:
	if not objective_before and Campaign.state.session.expedition.get("objective_done", false):
		Sound.play("res://audio/world/find_coins.ogg")
	elif opens:
		Sound.play("res://audio/world/prop_open.ogg")
	else:
		Sound.play("res://audio/world/search_cloth_%d.ogg" % randi_range(1, 2))


func _on_event_choice(choice_id: String) -> void:
	if R.choose_event_option(Campaign.state, choice_id, randi()):
		Campaign.save()
		hud.show_event(Campaign.state)
		hud.refresh(Campaign.state)


func _on_event_closed() -> void:
	if R.finish_event(Campaign.state):
		Campaign.save()
	hud.close_modal()
	hud.refresh(Campaign.state)


## Acampar (#77): a fogueira acende e um fade leva a equipe às posições de descanso em volta dela.
func _start_camp() -> void:
	if not R.start_camp(Campaign.state):
		return
	Campaign.save()
	busy = true
	room.set_camp_lit(true)
	await camp.begin(room, Campaign.state.session.expedition.team)
	busy = false
	hud.show_camp(Campaign.state, camp)


## Comer ou curar o herói escolhido: as regras de sempre; a cena responde com o que a vida e o instinto mudaram.
func _camp_care(hero_id: String, kind: String) -> void:
	var hero = Campaign.hero(hero_id)
	if hero == null or camp.switching():
		return
	var hp_before: int = hero.hp
	var instinct_before: int = hero.instinct
	var ok := R.camp_use_food(Campaign.state, hero_id) if kind == "food" else R.camp_use_bandage(Campaign.state, hero_id)
	if ok:
		Campaign.save()
		hud.camp_respond(hero_id, kind, hero.hp - hp_before, hero.instinct - instinct_before)
	hud.show_camp(Campaign.state, camp)
	hud.refresh(Campaign.state)


## Levantar acampamento: um fade devolve a equipe à fila; lá fora, o tempo mudou.
func _on_camp_leave() -> void:
	if busy:
		return
	# O busy fica ligado do começo ao fim: nenhum quadro em que a equipe ande no meio da saída.
	busy = true
	# A troca de herói termina antes (os dois fades usam o mesmo preto); com teto, para nunca prender a saída.
	var limit := Time.get_ticks_msec() + SWITCH_WAIT_MS
	while camp.switching() and Time.get_ticks_msec() < limit:
		await get_tree().process_frame
	if not R.leave_camp(Campaign.state, randi()):
		busy = false
		return
	var weather: String = Campaign.state.session.expedition.corridor.weather
	Campaign.save()
	hud.hide_camp()
	await camp.end()
	room.set_camp_lit(false)
	street.apply_corridor_weather(weather)
	busy = false
	hud.toast(tr("A equipe descansou. Lá fora, o tempo mudou: %s.") % tr(street.WEATHER_NAMES.get(weather, weather)), 4.0)
	hud.refresh(Campaign.state)
	# Reaberto no acampamento com o guardião vencido e a carga ainda fechada: as caixas abrem ao levantar acampamento.
	if AHFightRewards.cargo_pending(Campaign.state):
		await open_cargo()


# ---------------------------------------------------------------- lutas

## Começa a luta do trecho (index) ou da casa (index >= HOUSE_ENEMY_INDEX). advantage: a equipe chegou sem ser vista.
func _start_fight(index: int, advantage: bool) -> void:
	if street._arena.active:
		return
	var fight := R.start_corridor_combat(Campaign.state, advantage)
	if fight.is_empty():
		return
	# A barra de Admin (#130): a luta contra o inimigo escolhido, com os cartões dele (o tamanho e o desenho certos).
	var chosen: String = Admin.next_enemy
	fight.enemies = Admin.override_enemies(fight.enemies)
	var house := index >= R.HOUSE_ENEMY_INDEX
	var cards: Array = room_guards if house else guards[index].cards
	if chosen != "" and not fight.enemies.is_empty() and fight.enemies[0].enemy_id == chosen:
		var swapped: Array = []
		for i in fight.enemies.size():
			var old: AHSpriteCard = cards[mini(i, cards.size() - 1)]
			var card := _enemy_card(chosen)
			card.position = old.position
			swapped.append(card)
		for old in cards:
			old.queue_free()
		cards = swapped
		if house:
			room_guards = swapped
		else:
			guards[index].cards = swapped
	if not house:
		guards[index].mark.visible = false
	_fight = {"index": index, "boss": fight.boss, "house": house, "cards": cards,
		"cause": fight.enemies[0].display_name if not fight.enemies.is_empty() else "patrulha"}
	street.begin_fight()
	if guide != null:
		guide.event("fight_start")
	if fight.opening:
		hud.toast(tr("A equipe chegou sem ser vista: age primeiro."), 2.5)
	var heroes: Array = street.party_ids.map(func(id): return Campaign.hero(id))
	var center: float = (room.guard_x if house else cards[0].position.x) - 1.0
	street._arena.boss_fight = bool(fight.boss)
	street._arena.start(heroes, street._heroes, fight.enemies, cards, center, fight.opening)


func _on_combat_finished(result: String) -> void:
	var campaign: Dictionary = Campaign.state
	# No tutorial ninguém cai e não há fuga que encerre a jornada: quem recua tenta a mesma luta de novo.
	if tutorial() and result != "victory":
		_restart_fight()
		return
	R.end_combat(campaign, result, _fight.get("boss", false), "%s (%s)" % [_fight.get("cause", ""), R.phase(campaign.session.expedition.phase_id).get("name", "")])
	street.end_fight()
	street.remove_dead_heroes()
	if campaign.session.result != "":
		Campaign.save()
		_show_result()
		return
	if result == "victory":
		for card in _fight.cards:
			card.visible = false
		if _fight.house:
			room_guards.clear()
		else:
			guards[_fight.index].mark.queue_free()
			guards.erase(_fight.index)
		_refresh_security_doors(true)
		if guide != null:
			guide.event("fight_end")
		if campaign.session.expedition.objective_completed and _fight.boss:
			# A carga recuperada (#91): seis caixas com o que o guardião guardava; escolhida uma vez.
			Campaign.save()
			await open_cargo()
			Tips.show_tip("boss_down")
			if street.scenario:
				hud.toast(tr("O guardião caiu. Vasculhe o que restou ou volte à Estação pelo Menu (%s).") % AHUiStyle.key_name("menu"), 6.0)
			else:
				hud.toast(tr("O guardião caiu. A Rua das Vitrines está livre: explore as casas ou volte à Estação pelo começo da rua."), 6.0)
	Campaign.save()
	hud.refresh(campaign)


## A carga recuperada do guardião (#91), se ainda não foi escolhida: as caixas viradas, a escolha e a revelação.
func open_cargo() -> void:
	var campaign: Dictionary = Campaign.state
	if not AHFightRewards.cargo_pending(campaign):
		return
	AHFightRewards.cargo(campaign)
	Campaign.save()
	busy = true
	var picker := hud.show_cargo(campaign)
	await picker.chosen
	AHFightRewards.choose(campaign, picker.index)
	Campaign.save()
	await picker.closed
	busy = false
	hud.refresh(campaign)


## K (teste): anda pelos trechos já liberados até a próxima patrulha e para na frente dela. Devolve se andou (false: fora
## do corredor, numa casa ou ocupado).
func debug_next_fight() -> bool:
	var campaign: Dictionary = Campaign.state
	if not R.in_corridor(campaign) or room != null or side_room >= 0 or busy:
		return false
	var route: Dictionary = campaign.session.expedition.corridor
	while route.steps[route.index].resolved and route.index < mini(map_last, route.steps.size() - 1):
		# A Passagem com o evento de história para ali, com o cartão aberto (o laço não saía com o evento aberto).
		var outcome := R.enter_step(campaign, route.index + 1)
		if outcome == "event":
			Campaign.save()
			hud.refresh(campaign)
			hud.show_event(campaign)
			return true
		# O encontro do tutorial resolve ali (o Nick entra); o trem para a caminhada.
		if outcome == "nick":
			_enter_segment(_segment_of(route.index), _step_x(route.index, ARRIVAL_SPOT))
			_meet_nick()
		elif outcome == "train":
			Campaign.save()
			_enter_segment(_segment_of(route.index), _step_x(route.index, ARRIVAL_SPOT))
			_reach_platform()
			return false
	Campaign.save()
	# Passou do mapa de passagem: viaja para o da fase.
	if route.steps[route.index].resolved and route.index == map_last and map_last < route.steps.size() - 1:
		_travel_map(campaign, map_last + 1)
		return true
	if guards.has(route.index):
		var front: AHSpriteCard = guards[route.index].cards[0]
		var to := _segment_of(route.index)
		if to != segment:
			_enter_segment(to, front.position.x - CONTACT - 2.5)
		else:
			street._place_leader(Vector3(front.position.x - CONTACT - 2.5, street.floor_y if street.scenario else 0.0, street.lane_z if street.scenario else 0.45))
	hud.refresh(campaign)
	# Sem patrulha à frente (tudo vencido), não houve aonde ir.
	return guards.has(route.index)


# ---------------------------------------------------------------- resultado

func _show_result() -> void:
	var campaign: Dictionary = Campaign.state
	var result: String = campaign.session.result
	var delivered := R.finish_return(campaign)
	Campaign.save()
	hud.show_result(result, delivered, campaign, tr("Voltar à Estação"))


## A equipe volta pelo trem: o relatório, a noite e o ciclo da Estação ficam lá. Sem nenhum vivo, a Estação recebe
## voluntários de graça (FAHShelterRules::CanRecruitVolunteer), então a campanha continua.
func _on_result_continue() -> void:
	hud.close_modal()
	GameFlow.travel("station")
