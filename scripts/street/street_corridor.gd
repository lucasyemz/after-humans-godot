## A jornada na Rua das Vitrines (port enxuto do AAHStreetCorridor): liga as regras (AHJourneyRules) à cena da rua.
## - Os 10 trechos ocupam 7,8 m cada a partir do começo da rua; a equipe só passa de um trecho com a patrulha vencida.
## - Cada patrulha espera em pé no trecho dela. O da frente vê num cone de 60° até 14 m (menos à noite, na chuva e na
##   névoa), e carros, props e paredes tapam a visão. A suspeita sobe enquanto vê e cai depois de um tempo sem ver:
##   "?" desconfiado, "!" detectado (ele avança sobre a equipe). Chegar até ele sem ser detectado dá a vantagem de
##   abertura (a equipe age primeiro).
## - As três casas sorteadas ficam com a porta aberta pintada; a trancada pede pé de cabra. Dentro, os pontos de busca,
##   a emboscada da patrulha da casa e o acampamento. Os trechos de suprimentos têm um objeto para vasculhar.
## - O começo da rua é a volta à Estação. Cada chegada a um trecho, luta, busca e acampamento salva a campanha.
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
const PROP_ART := ["alley-props-v1.webp", Rect2(828, 119, 282, 360), 105.0, "os caixotes"]

var street: Node3D
var hud: AHExplorationHud
var guards := {}
var doors: Array = []
var props := {}
var room: AHHouseRoom
var room_guards: Array = []
var busy := false
var _room_time := 0.0
var _fight := {}
var _action := Callable()
var _overlays := {}


func setup(owner_street: Node3D, exploration_hud: AHExplorationHud) -> void:
	street = owner_street
	hud = exploration_hud
	hud.event_choice.connect(_on_event_choice)
	hud.event_closed.connect(_on_event_closed)
	hud.camp_food.connect(func(id): _camp_care(R.camp_use_food(Campaign.state, id)))
	hud.camp_bandage.connect(func(id): _camp_care(R.camp_use_bandage(Campaign.state, id)))
	hud.camp_leave.connect(_on_camp_leave)
	hud.result_continue.connect(_on_result_continue)
	street._arena.finished.connect(_on_combat_finished)
	doors = street.door_list()
	var campaign: Dictionary = Campaign.state
	if campaign.get("session", {}).get("expedition") == null:
		# Sem expedição a rua não tem o que mostrar: a partida é pela Preparação, na Estação.
		GameFlow.change_to.call_deferred("station", {}, false)
		return
	var route: Dictionary = campaign.session.expedition.corridor
	R.assign_search_sites(route, doors.map(func(d): return d.step), doors.map(func(d): return d.shop), campaign.session.expedition.get("focus", ""))
	Campaign.save()
	street.apply_corridor_weather(route.weather)
	_spawn_guards()
	_spawn_props()
	_refresh_doors()
	if route.current_house >= 0:
		_open_room(route.current_house)
	else:
		street._place_leader(Vector3(_step_x(route.index, ARRIVAL_SPOT), 0, 0.45))
	hud.refresh(campaign)
	var session: Dictionary = campaign.session
	if session.result != "":
		_show_result()
	elif session.event != null:
		hud.show_event(campaign)
	elif session.screen == "rest" and room != null:
		room.set_camp_lit(true)
		hud.show_camp(campaign)


## Bloqueia o movimento da equipe (painel aberto, transição ou luta).
func blocking() -> bool:
	return busy or hud.modal_open() or street._arena.active


static func _step_x(index: int, fraction: float) -> float:
	return MIN_X + STEP_LENGTH * (index + fraction)


# ---------------------------------------------------------------- montagem

func _spawn_guards() -> void:
	var expedition: Dictionary = Campaign.state.session.expedition
	var route: Dictionary = expedition.corridor
	for index in route.steps.size():
		var step: Dictionary = route.steps[index]
		if step.resolved or (step.type != "combat" and step.type != "boss"):
			continue
		var specs := R.corridor_enemies(expedition, index)
		var cards: Array = []
		for i in specs.size():
			var card := _enemy_card(specs[i].enemy_id)
			card.position = Vector3(_step_x(index, GUARD_SPOT) + i * 1.35, 0, -0.8 - 0.03 * i)
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


func _enemy_card(enemy_id: String) -> AHSpriteCard:
	var card := AHSpriteCard.new()
	card.body_height = AHCharacterHeights.find(enemy_id)
	card.show_art(street._combat_art.enemies[enemy_id].idle)
	card.set_facing(-1.0)
	street.add_child(card)
	return card


func _spawn_props() -> void:
	var route: Dictionary = Campaign.state.session.expedition.corridor
	for index in route.steps.size():
		if route.steps[index].type != "loot":
			continue
		var card: MeshInstance3D = street._add_card(PROP_ART[0], PROP_ART[1], Vector3(_step_x(index, 0.45) * 100.0, -285, street.SIDEWALK_TOP_Z), PROP_ART[2])
		props[index] = card
		if route.props.get(str(index), false):
			_dim(card)


func _dim(card: MeshInstance3D) -> void:
	var material: StandardMaterial3D = card.material_override.duplicate()
	material.albedo_color = Color(0.45, 0.42, 0.4)
	card.material_override = material


## Portas das casas abertas (e da trancada depois de arrombada) com a pintura da porta aberta.
func _refresh_doors() -> void:
	var route: Dictionary = Campaign.state.session.expedition.corridor
	for i in route.sites.size():
		var site: Dictionary = route.sites[i]
		if _overlays.has(i) or (site.locked and not site.forced):
			continue
		var door: Dictionary = doors[site.door]
		var rect: Rect2 = street.DOOR_OVERLAYS[site.shop]
		var scale: float = street.FACADE_WIDTH / 1536.0
		var base: float = street.SIDEWALK_TOP_Z + (1024.0 - (rect.position.y + rect.size.y)) * scale
		var card: MeshInstance3D = street._add_card("door-open-%s-crop.png" % SHOP_ART[site.shop], Rect2(),
			Vector3(door.x * 100.0, street.FACADE_FRONT_Y + 2, base), rect.size.y * scale, 0.0, door.mirror, false, true)
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
	else:
		_street_frame(campaign, route, delta)


func _street_frame(campaign: Dictionary, route: Dictionary, delta: float) -> void:
	var leader: Vector3 = street._leader.position
	# Trecho por vencer: a equipe não passa da patrulha.
	var high := 79.0 if route.steps[route.index].resolved else _step_x(route.index, 1.0) - EDGE_MARGIN
	street.walk_max.x = high
	var under := clampi(floori((leader.x - MIN_X) / STEP_LENGTH), 0, route.steps.size() - 1)
	if under != route.index:
		var next: int = route.index + (1 if under > route.index else -1)
		var was_resolved: bool = route.steps[next].resolved
		var outcome := R.enter_step(campaign, next)
		if route.index == next:
			Campaign.save()
			_announce(next, outcome, not was_resolved)
			hud.refresh(campaign)
	for index in [route.index, route.index + 1]:
		if guards.has(index) and _sight_frame(index, delta, leader):
			return
	_choose_action(campaign, route, leader)


## Visão e suspeita do guarda do trecho; true se a luta começou.
func _sight_frame(index: int, delta: float, leader: Vector3) -> bool:
	var guard: Dictionary = guards[index]
	var front: AHSpriteCard = guard.cards[0]
	var strength := _sight_strength(front, leader)
	if strength > 0.0:
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
				where = " O acampamento fica %s do trecho %d." % [("no cinema" if route.sites[camp].shop == 2 else "na " + R.SHOP_NAMES[route.sites[camp].shop]), route.sites[camp].step + 1]
			hud.toast("Trecho %d · Descanso. Um lugar quieto.%s" % [index + 1, where], 5.0)
		"combat", "boss":
			hud.toast("Trecho %d · %s à frente. Chegue sem ser visto para agir primeiro." % [index + 1, label])
		_:
			if first_time:
				hud.toast("Trecho %d · %s" % [index + 1, label], 2.5)


# ---------------------------------------------------------------- interações

func _choose_action(campaign: Dictionary, route: Dictionary, leader: Vector3) -> void:
	var text := ""
	var action := Callable()
	var best := 1.3
	for i in route.sites.size():
		var site: Dictionary = route.sites[i]
		var distance := absf(doors[site.door].x - leader.x)
		if distance >= best or site.step > route.index:
			continue
		var shop := R.shop_the(site.shop)
		if R.can_enter_house(campaign, i):
			text = "E  Entrar n%s" % shop
			action = _enter_house.bind(i)
		elif R.can_force_house(campaign, i):
			text = "E  Arrombar a porta d%s (o pé de cabra quebra)" % shop
			action = _force_house.bind(i)
		elif site.locked and not site.forced:
			text = "Porta trancada · Precisa de um pé de cabra para arrombar"
			action = Callable()
		best = distance
	for index in props:
		if absf(_step_x(index, 0.45) - leader.x) < best and index <= route.index and not route.props.get(str(index), false):
			best = absf(_step_x(index, 0.45) - leader.x)
			text = "E  Vasculhar %s" % PROP_ART[3]
			action = _search_prop.bind(index)
	if leader.x < EXIT_X:
		text = "E  Voltar à Estação (%s)" % ("fase concluída: todo o achado" if campaign.session.expedition.objective_completed else "retirada: metade do achado")
		action = _retreat
	hud.show_prompt(text)
	_action = action


func _house_frame(campaign: Dictionary, route: Dictionary) -> void:
	var site: Dictionary = route.sites[route.current_house]
	if site.has_enemy and not site.enemy_defeated and not room_guards.is_empty() and _room_time > AMBUSH_DELAY:
		# Patrulha dentro da loja: emboscada logo depois de entrar (os inimigos agem primeiro).
		hud.toast("Emboscada!", 1.5)
		_start_fight(R.HOUSE_ENEMY_INDEX + route.current_house, false)
		return
	var leader: Vector3 = street._leader.position
	var text := ""
	var action := Callable()
	var best := 0.9
	for i in room.spot_xs.size():
		var distance := absf(room.spot_xs[i] - leader.x)
		if distance < best:
			best = distance
			var name: String = R.SPOT_NAMES[site.shop][i] if i < 3 else "o canto"
			if site.spots[i].searched:
				text = "%s (já vasculhado)" % name.capitalize()
				action = Callable()
			else:
				text = "E  Vasculhar %s" % name
				action = _search_spot.bind(route.current_house, i)
	if site.camp_site and absf(room.camp_x - leader.x) < best:
		if R.can_start_camp(campaign):
			text = "E  Acampar (fechar a porta e acender a fogueira)"
			action = _start_camp
		elif site.camped:
			text = "Acampamento já feito nesta fase"
			action = Callable()
	if leader.x < room.exit_x:
		text = "E  Sair para a rua"
		action = _leave_house
	hud.show_prompt(text)
	_action = action


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not blocking() and _action.is_valid():
		get_viewport().set_input_as_handled()
		var action := _action
		_action = Callable()
		action.call()


func _search_prop(index: int) -> void:
	var result := R.search_prop(Campaign.state, index)
	if result.ok:
		_dim(props[index])
		Campaign.save()
		hud.toast(result.text, 5.0)
		hud.refresh(Campaign.state)


func _force_house(site_index: int) -> void:
	if R.force_house(Campaign.state, site_index):
		Campaign.save()
		_refresh_doors()
		hud.toast("O pé de cabra entorta e quebra, mas a porta cede.")
		hud.refresh(Campaign.state)


func _retreat() -> void:
	if R.safe_retreat(Campaign.state):
		_show_result()


# ---------------------------------------------------------------- casas

func _enter_house(site_index: int) -> void:
	busy = true
	await GameFlow.fade(1.0)
	if R.enter_house(Campaign.state, site_index):
		Campaign.save()
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
	room.build(site.shop, ROOMS_X + site_index * ROOM_GAP, site.spots.size(), site.camp_site)
	var showing: bool = not street._debug_colliders.is_empty() and street._debug_colliders[0].visible
	for debug in room.debug_colliders:
		debug.visible = showing
		street._debug_colliders.append(debug)
	street.set_indoor(true, room.position.x, AHHouseRoom.WIDTH)
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
		for debug in room.debug_colliders:
			street._debug_colliders.erase(debug)
		room.queue_free()
	room = null
	street.set_indoor(false)


func _search_spot(site_index: int, spot_index: int) -> void:
	var result := R.search_spot(Campaign.state, site_index, spot_index)
	if not result.ok:
		return
	Campaign.save()
	hud.refresh(Campaign.state)
	if result.event != "":
		hud.show_event(Campaign.state)
	else:
		hud.toast(result.text, 5.0)


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


func _start_camp() -> void:
	if R.start_camp(Campaign.state):
		Campaign.save()
		room.set_camp_lit(true)
		hud.show_camp(Campaign.state)


func _camp_care(ok: bool) -> void:
	if ok:
		Campaign.save()
	hud.show_camp(Campaign.state)
	hud.refresh(Campaign.state)


func _on_camp_leave() -> void:
	if R.leave_camp(Campaign.state, randi()):
		var weather: String = Campaign.state.session.expedition.corridor.weather
		Campaign.save()
		room.set_camp_lit(false)
		street.apply_corridor_weather(weather)
		hud.close_modal()
		hud.toast("A equipe descansou. Lá fora, o tempo mudou: %s." % street.WEATHER_NAMES.get(weather, weather), 4.0)
		hud.refresh(Campaign.state)


# ---------------------------------------------------------------- lutas

## Começa a luta do trecho (index) ou da casa (index >= HOUSE_ENEMY_INDEX). advantage: a equipe chegou sem ser vista.
func _start_fight(index: int, advantage: bool) -> void:
	var fight := R.start_corridor_combat(Campaign.state, advantage)
	if fight.is_empty():
		return
	var house := index >= R.HOUSE_ENEMY_INDEX
	var cards: Array = room_guards if house else guards[index].cards
	if not house:
		guards[index].mark.visible = false
	_fight = {"index": index, "boss": fight.boss, "house": house, "cards": cards,
		"cause": fight.enemies[0].display_name if not fight.enemies.is_empty() else "patrulha"}
	street.begin_fight()
	if fight.opening:
		hud.toast("A equipe chegou sem ser vista: age primeiro.", 2.5)
	var heroes: Array = street.party_ids.map(func(id): return Campaign.hero(id))
	var center: float = (room.guard_x if house else cards[0].position.x) - 1.0
	street._arena.start(heroes, street._heroes, fight.enemies, cards, center, fight.opening)


func _on_combat_finished(result: String) -> void:
	var campaign: Dictionary = Campaign.state
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
		if campaign.session.expedition.objective_completed and _fight.boss:
			hud.toast("O guardião caiu. A Rua das Vitrines está livre: explore as casas ou volte à Estação pelo começo da rua.", 6.0)
	Campaign.save()
	hud.refresh(campaign)


## K (teste): anda pelos trechos já liberados até a próxima patrulha e para na frente dela.
func debug_next_fight() -> void:
	var campaign: Dictionary = Campaign.state
	if not R.in_corridor(campaign) or room != null:
		return
	var route: Dictionary = campaign.session.expedition.corridor
	while route.steps[route.index].resolved and route.index < route.steps.size() - 1:
		R.enter_step(campaign, route.index + 1)
	Campaign.save()
	if guards.has(route.index):
		street._place_leader(Vector3(guards[route.index].cards[0].position.x - CONTACT - 2.5, 0, 0.45))
	hud.refresh(campaign)


# ---------------------------------------------------------------- resultado

func _show_result() -> void:
	var campaign: Dictionary = Campaign.state
	var result: String = campaign.session.result
	var delivered := R.finish_return(campaign)
	Campaign.save()
	hud.show_result(result, delivered, campaign, "Voltar à Estação")


## A equipe volta pelo trem: o relatório, a noite e o ciclo da Estação ficam lá. Sem nenhum vivo, a Estação recebe
## voluntários de graça (FAHShelterRules::CanRecruitVolunteer), então a campanha continua.
func _on_result_continue() -> void:
	hud.close_modal()
	GameFlow.change_to("station")
