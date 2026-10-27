## O indicador de interação igual em todos os mapas (#142):
## - todo prop vasculhável dos seis cenários dá o ponto da marca dele (scenario_world.prop_marker_point): em cima do
##   desenho do prop, no x dele e acima do piso;
## - na rua de verdade, em cada cenário, com a equipe perto de cada prop, de cada porta de interior e da saída para a
##   Estação, o ponto está nas marcas do HUD (ou é o do aviso, o da vez); vasculhado, sai das marcas;
## - dentro dos interiores laterais há marcas (os props e a porta de volta), como no corredor.
extends RefCounted

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
	for room_entry in corridor.side_rooms:
		corridor._enter_segment(room_entry.door_segment, float(room_entry.door_x) - 3.0)
		route.index = maxi(route.index, int(room_entry.door_step))
		street._place_leader(Vector3(float(room_entry.door_x) - 3.0, street.floor_y, street.lane_z))
		_frame(corridor, c, route)
		t.check(_marked(street, corridor._side_door_point(room_entry)), "%s: a porta de %s marcada" % [map, scenario.zones[room_entry.zone].name])
	# Com o caminho livre, o que está à frente na zona já tem a marca (antes, só ao pisar no trecho do objeto).
	var ahead: Array = corridor.scenario_props.filter(func(e): return corridor._side_room_of_zone(e.zone) < 0 and int(e.step) > corridor.segments[corridor._segment_of(int(e.step))].first)
	if not ahead.is_empty():
		var far: Dictionary = ahead[0]
		var part: Dictionary = corridor.segments[corridor._segment_of(int(far.step))]
		route.index = int(part.first)
		corridor._enter_segment(corridor._segment_of(int(far.step)), float(part.x0) + 0.5)
		_frame(corridor, c, route)
		var mark := corridor._scenario_prop_point(far)
		t.check(absf(mark.x - street._leader.position.x) >= 14.0 or _marked(street, mark), "%s: %s marcado de longe, com o caminho livre" % [map, far.name])
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
