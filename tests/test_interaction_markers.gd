## O indicador de interação igual em todos os mapas (#142):
## - todo prop vasculhável dos seis cenários dá o ponto da marca dele (scenario_world.prop_marker_point): em cima do
##   desenho do prop, no x dele e acima do piso;
## - na rua de verdade, em cada cenário, com a equipe perto de cada prop, de cada porta de interior e da saída para a
##   Estação, o ponto está nas marcas do HUD (ou é o do aviso, o da vez); vasculhado, sai das marcas;
## - dentro dos interiores laterais há marcas (os props e a porta de volta), como no corredor, e o aviso fica sobre o
##   objeto que a tecla vasculha;
## - com uma patrulha de pé, nada do trecho dela em diante tem marca; um objeto num trecho à frente do atual só ganha a
##   marca quando a tecla já o vasculha (R.step_open, a mesma regra);
## - nas casas da Rua das Vitrines, a fogueira e a porta de saída têm a marca, e o aviso delas fica sobre elas.
extends RefCounted

const R := preload("res://scripts/flow/journey_rules.gd")

const PHASE_OF := {"RiverDock": ["fase_2", 0], "RootBridge": ["fase_2", 4], "SealedShelter": ["fase_3", 0],
	"TriageGate": ["fase_4", 0], "FloodedDepot": ["fase_5", 0], "SewerDucts": ["fase_5", 4]}

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-markers-%d" % Time.get_ticks_usec()
	for map in PHASE_OF:
		await _map(map)
	await _patrol("RiverDock")
	await _house()
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _map(map: String) -> void:
	var spec: Array = PHASE_OF[map]
	var c := Campaign.create_initial(9)
	c.completed_phases = ["fase_1", "fase_2", "fase_3", "fase_4"]
	AHStationRules.confirm_departure(c, c.preferred_formation.duplicate(), 0, 4242, spec[0], "")
	var route: Dictionary = c.session.expedition.corridor
	# Os trechos do mapa vencidos: nada guardado por patrulha, tudo ao alcance.
	for i in route.steps.size() - 1:
		route.steps[i].resolved = true
	route.index = int(spec[1])
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("street", {}, false)
	var street = null
	for frame in 300:
		await _tree.process_frame
		var scene := _tree.current_scene
		if not GameFlow.busy and scene != null and scene.get("corridor") != null and scene.corridor != null and scene.scenario != null:
			street = scene
			break
	if not t.check(street != null and street.scenario.map_name == map, "%s abriu" % map):
		return
	var corridor: AHStreetCorridor = street.corridor
	corridor.process_mode = Node.PROCESS_MODE_DISABLED
	var scenario: AHScenarioWorld = street.scenario
	for local in scenario.props.size():
		var prop: Dictionary = scenario.props[local]
		var point := scenario.prop_marker_point(local)
		var zone := scenario.zone_at(float(prop.x))
		t.check(absf(point.x - float(prop.x)) < 1.6 and point.y > float(scenario.zones[maxi(zone, 0)].y) + 0.5,
			"%s: o prop %s tem a marca em cima dele" % [map, prop.name])
	# Pelo corredor: em cada zona do mapa, a equipe ao lado de cada coisa usável.
	route.index = corridor.map_first
	for entry in corridor.scenario_props:
		var room := corridor._side_room_of_zone(entry.zone)
		if room >= 0:
			corridor._show_side_room(room)
		else:
			corridor._enter_segment(corridor._segment_of(entry.step), float(entry.x) - 3.0)
		route.index = maxi(route.index, int(entry.step))
		street._place_leader(Vector3(float(entry.x) - 3.0, street.floor_y, street.lane_z))
		_frame(corridor, c, route)
		var point: Vector3 = corridor._scenario_prop_point(entry)
		t.check(_marked(street, point), "%s: %s marcado (a %s)" % [map, entry.name, "dentro do interior" if room >= 0 else "no corredor"])
		if room >= 0:
			t.check(street.exploration_hud._marker_points.size() >= 2, "%s: o interior tem as marcas dos props e da porta de volta" % map)
			# Andando pelo interior: o aviso fica sobre o objeto que a tecla vasculha (o mais perto).
			var wrong := ""
			var x0: float = float(entry.x) - 1.0
			for step in 21:
				street._place_leader(Vector3(x0 + step * 0.1, street.floor_y, street.lane_z))
				corridor._side_room_frame(c, route)
				var leader_x: float = street._leader.position.x
				var near = null
				for other in corridor.scenario_props:
					if other.zone == entry.zone and absf(other.x - leader_x) < AHStreetCorridor.REACH \
							and (near == null or absf(other.x - leader_x) < absf(near.x - leader_x)):
						near = other
				var anchor = street.exploration_hud._prompt_world
				if near != null and leader_x >= corridor.side_rooms[room].x0 + AHStreetCorridor.EXIT_X \
						and (anchor == null or anchor.distance_to(corridor._scenario_prop_point(near)) > 0.05):
					wrong = "%.1f" % leader_x
			t.check(wrong == "", "%s: no interior, o aviso fica sobre o objeto mais perto (%s)" % [map, wrong])
	for room_entry in corridor.side_rooms:
		corridor._enter_segment(room_entry.door_segment, float(room_entry.door_x) - 3.0)
		route.index = maxi(route.index, int(room_entry.door_step))
		street._place_leader(Vector3(float(room_entry.door_x) - 3.0, street.floor_y, street.lane_z))
		_frame(corridor, c, route)
		t.check(_marked(street, corridor._side_door_point(room_entry)), "%s: a porta de %s marcada" % [map, scenario.zones[room_entry.zone].name])
	# Um objeto num trecho à frente do atual (route.index): a marca concorda com a tecla (R.can_search_scenario_prop).
	var ahead: Array = corridor.scenario_props.filter(func(e): return corridor._side_room_of_zone(e.zone) < 0 and int(e.step) > corridor.segments[corridor._segment_of(int(e.step))].first)
	if not ahead.is_empty():
		var far: Dictionary = ahead[0]
		var part: Dictionary = corridor.segments[corridor._segment_of(int(far.step))]
		route.index = int(part.first)
		corridor._enter_segment(corridor._segment_of(int(far.step)), float(part.x0) + 0.5)
		_frame(corridor, c, route)
		var mark := corridor._scenario_prop_point(far)
		var can := R.can_search_scenario_prop(c, int(far.prop))
		t.check(not can, "%s: %s, à frente do trecho atual, ainda não se vasculha" % [map, far.name])
		t.equal(_marked(street, mark), can, "%s: %s, à frente, sem a marca (a marca e a tecla concordam)" % [map, far.name])
		# Chegando ao trecho dele, a marca e a tecla abrem juntas.
		route.index = int(far.step)
		_frame(corridor, c, route)
		t.check(R.can_search_scenario_prop(c, int(far.prop)) and (absf(mark.x - street._leader.position.x) >= 14.0 or _marked(street, mark)),
			"%s: %s, no trecho dele, marcado e vasculhável" % [map, far.name])
	# A saída para a Estação, no começo do mapa da fase (o de travessia não volta por ali).
	if corridor.map_first == 0:
		route.index = 0
		corridor._enter_segment(0, corridor.segments[0].x0 + 4.0)
		_frame(corridor, c, route)
		t.check(_marked(street, corridor._exit_point()), "%s: a volta à Estação marcada" % map)
	# Vasculhado, sai das marcas.
	if not corridor.scenario_props.is_empty():
		var entry: Dictionary = corridor.scenario_props[0]
		route.searched_props.append(entry.prop)
		var room := corridor._side_room_of_zone(entry.zone)
		if room >= 0:
			corridor._show_side_room(room)
		else:
			corridor._enter_segment(corridor._segment_of(entry.step), float(entry.x) - 3.0)
		street._place_leader(Vector3(float(entry.x) - 3.0, street.floor_y, street.lane_z))
		_frame(corridor, c, route)
		t.check(not _marked(street, corridor._scenario_prop_point(entry)), "%s: o prop vasculhado sai das marcas" % map)


## Um quadro do corredor (as marcas do HUD), sem as patrulhas.
func _frame(corridor: AHStreetCorridor, c: Dictionary, route: Dictionary) -> void:
	if corridor.side_room >= 0:
		corridor._side_room_frame(c, route)
	else:
		corridor._choose_action(c, route, corridor.street._leader.position)


func _marked(street, point: Vector3) -> bool:
	var hud: AHExplorationHud = street.exploration_hud
	for p in hud._marker_points:
		if p.distance_to(point) < 0.05:
			return true
	return hud._prompt_world != null and hud._prompt_world.distance_to(point) < 0.05


## A rua de uma fase aberta com a campanha c.
func _open(c: Dictionary):
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("street", {}, false)
	for frame in 300:
		await _tree.process_frame
		var scene := _tree.current_scene
		if not GameFlow.busy and scene != null and scene.get("corridor") != null and scene.corridor != null and frame > 3:
			return scene
	return null


## Com a patrulha de pé num trecho de luta, nada do trecho dela em diante tem a marca (o caminho está fechado).
func _patrol(map: String) -> void:
	var spec: Array = PHASE_OF[map]
	var c := Campaign.create_initial(11)
	c.completed_phases = ["fase_1", "fase_2", "fase_3", "fase_4"]
	AHStationRules.confirm_departure(c, c.preferred_formation.duplicate(), 0, 4242, spec[0], "")
	var street = await _open(c)
	if not t.check(street != null, "%s abriu para a patrulha" % map):
		return
	var corridor: AHStreetCorridor = street.corridor
	corridor.process_mode = Node.PROCESS_MODE_DISABLED
	var route: Dictionary = c.session.expedition.corridor
	var checked := 0
	for index in range(corridor.map_first, route.steps.size()):
		if route.steps[index].type != "combat":
			continue
		for i in index:
			route.steps[i].resolved = true
		route.index = index
		var part: Dictionary = corridor.segments[corridor._segment_of(index)]
		corridor._enter_segment(corridor._segment_of(index), float(part.x0) + 0.5)
		_frame(corridor, c, route)
		var behind: Array = corridor.scenario_props.filter(func(e): return int(e.step) > index and corridor._side_room_of_zone(e.zone) < 0)
		var marked: Array = behind.filter(func(e): return _marked(street, corridor._scenario_prop_point(e)))
		t.equal(marked.map(func(e): return e.name), [], "%s: com a patrulha do trecho %d de pé, nada atrás dela tem marca" % [map, index + 1])
		checked += 1
	t.check(checked > 0, "%s: os trechos de luta conferidos" % map)


## A casa do acampamento na Rua das Vitrines: a fogueira e a porta de saída marcadas, e o aviso delas sobre elas.
func _house() -> void:
	var c := Campaign.create_initial(23)
	AHJourneyRules.start_expedition(c, "fase_1", 23)
	var street = await _open(c)
	if not t.check(street != null, "a Rua das Vitrines abriu"):
		return
	var corridor: AHStreetCorridor = street.corridor
	corridor.process_mode = Node.PROCESS_MODE_DISABLED
	var route: Dictionary = c.session.expedition.corridor
	var site: int = route.sites.map(func(s): return s.camp_site).find(true)
	if not t.check(site >= 0, "a rua tem a casa do acampamento"):
		return
	route.index = route.sites[site].step
	for i in route.index + 1:
		route.steps[i].resolved = true
	route.sites[site].has_enemy = false
	await corridor._enter_house(site)
	var room: AHHouseRoom = corridor.room
	var hud: AHExplorationHud = street.exploration_hud
	street._place_leader(Vector3(room.camp_x + 3.0, 0, -0.5))
	corridor._house_frame(c, route)
	t.check(_marked(street, corridor._camp_point()) and _marked(street, corridor._house_exit_point()), "a casa: a fogueira e a porta marcadas de longe")
	street._place_leader(Vector3(room.camp_x + 0.3, 0, -0.5))
	corridor._house_frame(c, route)
	t.check(hud._prompt_world != null and hud._prompt_world.distance_to(corridor._camp_point()) < 0.05, "perto da fogueira, o aviso Acampar fica sobre ela")
	street._place_leader(Vector3(room.exit_x - 0.3, 0, -0.5))
	corridor._house_frame(c, route)
	t.check(hud._prompt_world != null and hud._prompt_world.distance_to(corridor._house_exit_point()) < 0.05, "na porta, o aviso Sair fica sobre ela")
	route.sites[site].camped = true
	street._place_leader(Vector3(room.camp_x + 3.0, 0, -0.5))
	corridor._house_frame(c, route)
	t.check(not _marked(street, corridor._camp_point()), "acampamento feito: a fogueira sai das marcas")
	t.check(corridor._camp_point().y < 1.2, "a marca da fogueira fica logo acima dela")
