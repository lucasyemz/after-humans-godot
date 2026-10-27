## O Armazém e o Navio do Cais em camadas e os interiores ligados ao Cais (#141):
## - os dois cards chapados viram camadas da mesma pintura em profundidades diferentes (o Armazém em pedaços, com o vão
##   recuado; o Navio inteiro, com a silhueta escura atrás), sem pedaço dobrado, e os volumes novos (os pedaços e as
##   caixas do recuo) ficam atrás de onde a equipe anda, até no passo para a porta;
## - cada interior tem a porta de dentro, com o lado de fora (o céu e a água pintada) com a hora e a chuva de fora,
##   mesmo com a equipe dentro, e a luz de fora acompanhando;
## - entrar leva a equipe até a porta do Cais e a faz sair da porta de dentro, parando ao lado dela; sair faz o caminho
##   de volta e deixa a equipe na frente da mesma porta do Cais, na faixa de andar;
## - empurrada para o fundo na frente do Armazém e do Navio, a equipe para na faixa, antes dos volumes;
## - um mapa sem porta de dentro (o Depósito) entra e sai do jeito antigo, sem andar para o fundo.
extends RefCounted

const J := preload("res://scripts/flow/journey_rules.gd")
const LANE := 1.2
## As fachadas do Cais (x da frente delas) para o empurrão para o fundo.
const FACADES := [["o Armazém", 14.0], ["o Navio", 44.6]]

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-dock-depth-%d" % Time.get_ticks_usec()
	_data()
	var street = await _open("fase_2", ["fase_1"], "RiverDock")
	if street != null:
		_volumes_behind(street)
		await _push_back(street)
		await _weather(street)
		await _rooms(street, true)
	street = await _open("fase_5", ["fase_1", "fase_2", "fase_3", "fase_4"], "FloodedDepot")
	if street != null:
		await _rooms(street, false)
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _data() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/RiverDock.json"))
	t.check(data.parts[1].get("hidden", false) and data.parts[2].get("hidden", false), "os dois cards chapados saem")
	for layered in data.get("layered_cards", []):
		var area := 0.0
		var depths := {}
		for piece in layered.pieces:
			depths[snappedf(float(piece.z), 0.01)] = true
			# A silhueta escura de trás (shade) não conta: a pintura aparece uma vez só.
			if float(piece.get("shade", 1.0)) >= 1.0:
				area += (float(piece.rect[2]) - float(piece.rect[0])) * (float(piece.rect[3]) - float(piece.rect[1]))
		t.check(absf(area - 1.0) < 0.001, "%s: os pedaços cobrem a pintura uma vez (%.3f)" % [layered.name, area])
		t.check(depths.size() >= 2, "%s: em %d profundidades" % [layered.name, depths.size()])
	t.equal(Array(data.get("layered_cards", [])).map(func(l): return l.name), ["warehouse", "ship"], "o Armazém e o Navio em camadas")
	var boxes: Array = data.parts.filter(func(p): return p.get("layer") == "141" and p.mesh == 0)
	t.check(boxes.size() == 4 and boxes.all(func(p): return p.get("no_shadow", false)), "as caixas do recuo não fazem sombra no vão")
	# Todo volume gerado (o do Armazém hoje, e o do Navio quando a arte da #164 trouxer o casco em planos) fica atrás da
	# faixa de andar: o fundo dela (lane - 1,2 m) menos o raio do líder.
	var zone0: Dictionary = data.zones[0]
	var lane_back: float = (float(zone0.z0) + float(zone0.z1)) * 0.5 - 1.2 - 0.28
	var in_lane: Array = data.parts.filter(func(p): return p.get("layer") == "141" and float(p.origin[2]) + absf(float(p.basis[8])) * 0.5 > lane_back)
	for layered in data.get("layered_cards", []):
		in_lane.append_array(Array(layered.pieces).filter(func(piece): return float(piece.z) > lane_back))
	t.equal(in_lane.size(), 0, "nenhum volume nem pedaço gerado (Armazém ou Navio) dentro da faixa de andar")
	t.equal(Array(data.get("doorways", [])).size(), 2, "as portas de dentro dos dois interiores")
	t.equal(Array(JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/FloodedDepot.json")).get("doorways", [])).size(), 0,
		"o Depósito não tem porta de dentro")


func _open(phase: String, done: Array, map: String):
	var c := Campaign.create_initial(14)
	c.completed_phases = done
	J.start_expedition(c, phase, 14)
	var route: Dictionary = c.session.expedition.corridor
	for step in route.steps.size() - 1:
		route.steps[step].resolved = true
	# Abre no começo da fase (o primeiro mapa), com o resto vencido.
	route.index = 0
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("street", {}, false)
	var street = null
	for frame in 600:
		await _tree.process_frame
		var scene := _tree.current_scene
		if not GameFlow.busy and scene != null and scene.get("scenario") != null and scene.scenario != null and frame > 3:
			street = scene
			break
	if not t.check(street != null and street.scenario.map_name == map, "%s abriu" % map):
		return null
	return street


## O que fica mais à frente nos volumes novos (os pedaços em camadas e as caixas do recuo), em z.
func _front_of_volumes(street) -> float:
	var front := -INF
	for node in street.scenario.find_children("Layered_*", "MeshInstance3D", true, false):
		front = maxf(front, (node as MeshInstance3D).get_aabb().end.z)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/RiverDock.json"))
	for part in data.parts:
		if part.get("layer") == "141":
			front = maxf(front, float(part.origin[2]) + absf(float(part.basis[8])) * 0.5)
	return front


func _volumes_behind(street) -> void:
	var scenario: AHScenarioWorld = street.scenario
	t.equal(scenario.find_children("Layered_*", "MeshInstance3D", true, false).size(), 2, "cada fachada numa malha só")
	var front := _front_of_volumes(street)
	var deepest: float = street.lane_z - LANE
	t.check(deepest - street.LEADER_RADIUS > front, "os volumes novos (até z %.2f) ficam atrás da faixa de andar (%.2f)" % [front, deepest])
	var door_step: float = street.lane_z - AHStreetCorridor.DOOR_WALK_DEPTH
	t.check(door_step - street.LEADER_RADIUS > front, "e atrás do passo para a porta (%.2f)" % door_step)
	# O walk_leader anda sem a colisão (a porta fica fora da área de andar): os caminhos dele, por fora e por dentro, não
	# podem cruzar nenhuma caixa de colisão.
	var corridor: AHStreetCorridor = street.corridor
	for entry in corridor.side_rooms:
		var x0 := float(entry.x0)
		var stop: float = corridor._room_stop(entry)
		var paths := {
			"o passo para a porta do Cais": [Vector3(float(entry.door_x), street.floor_y, street.lane_z), Vector3(float(entry.door_x), street.floor_y, door_step)],
			"a saída da porta de dentro": [Vector3(x0 + 0.5, street.floor_y, street.lane_z - AHStreetCorridor.DOOR_WALK_DEPTH * 0.5), Vector3(x0 + stop, street.floor_y, street.lane_z)],
			"a volta para a porta de dentro": [Vector3(x0 + stop, street.floor_y, street.lane_z), Vector3(x0 + 0.3, street.floor_y, street.lane_z - AHStreetCorridor.DOOR_WALK_DEPTH * 0.5)],
		}
		for label in paths:
			var hits := []
			for i in 21:
				var spot: Vector3 = paths[label][0].lerp(paths[label][1], i / 20.0)
				if street._blocked(spot):
					hits.append("%.1f, %.1f" % [spot.x, spot.z])
			t.equal(hits, [], "x %.1f, %s: sem caixa no caminho" % [float(entry.door_x), label])


## Empurra o líder para o fundo na frente de cada fachada: ele para na faixa, sem entrar num volume.
func _push_back(street) -> void:
	var corridor: AHStreetCorridor = street.corridor
	var front := _front_of_volumes(street)
	for facade in FACADES:
		var segment := 0
		for i in corridor.segments.size():
			if float(corridor.segments[i].x0) <= float(facade[1]) and float(facade[1]) < float(corridor.segments[i].x1):
				segment = i
		corridor._enter_segment(segment, float(facade[1]))
		await _tree.process_frame
		Input.action_press("move_back")
		var deepest := INF
		var limit := Time.get_ticks_msec() + 1500
		while Time.get_ticks_msec() < limit:
			await _tree.process_frame
			deepest = minf(deepest, street._leader.position.z)
		Input.action_release("move_back")
		await _tree.process_frame
		t.check(deepest < street.lane_z - 0.5, "%s: o líder anda para o fundo (z %.2f)" % [facade[0], deepest])
		t.check(deepest - street.LEADER_RADIUS > front and deepest >= street.walk_min.z - 0.01,
			"%s: e para na faixa, antes dos volumes (z %.2f)" % [facade[0], deepest])


## A porta de dentro mostra o lado de fora com a hora e a chuva de lá, mesmo com a equipe dentro.
func _weather(street) -> void:
	var scenario: AHScenarioWorld = street.scenario
	var views: Array = scenario.find_children("DoorwayView_*", "MeshInstance3D", true, false)
	var lights: Array = scenario.find_children("DoorwayLight_*", "OmniLight3D", true, false)
	t.equal(views.size(), 2, "as duas portas de dentro na cena")
	t.equal(lights.size(), 2, "com a luz de fora")
	if views.is_empty() or lights.is_empty():
		return
	var view: ShaderMaterial = views[0].material_override
	var corridor: AHStreetCorridor = street.corridor
	var live: Dictionary = Campaign.state.session.expedition.corridor
	var entry: Dictionary = corridor.side_rooms[0]
	live.index = maxi(int(live.index), int(entry.door_step))
	corridor._enter_segment(corridor._segment_of(int(entry.door_step)), float(entry.door_x))
	corridor._show_side_room(0)
	await _tree.process_frame
	var seen := {}
	for mood in [["golden", false], ["night", true]]:
		street._mood = mood[0]
		street._raining = mood[1]
		street._apply_weather()
		var weather: Vector4 = view.get_shader_parameter("weather")
		seen[mood[0]] = [weather, float(view.get_shader_parameter("brightness")), float(view.get_shader_parameter("wet")),
			(lights[0] as OmniLight3D).light_energy]
	t.check(seen.golden[1] > 1.0 and seen.golden[0].x > seen.golden[0].z, "no fim de tarde, a porta é mais clara que a sala e quente como o cais")
	t.check(seen.night[0].x < seen.golden[0].x and seen.night[2] > 0.0, "na noite com chuva, a porta escurece e mostra a chuva")
	t.check(seen.night[3] < seen.golden[3], "e a luz de fora acompanha a hora")
	street._mood = "golden"
	street._raining = false
	street._apply_weather()
	corridor._leave_side_room()
	var limit := Time.get_ticks_msec() + 15000
	while corridor.busy and Time.get_ticks_msec() < limit:
		await _tree.process_frame


func _rooms(street, doorway: bool) -> void:
	var scenario: AHScenarioWorld = street.scenario
	var corridor: AHStreetCorridor = street.corridor
	for room in corridor.side_rooms.size():
		var entry: Dictionary = corridor.side_rooms[room]
		var name: String = scenario.zones[entry.zone].name
		t.equal(scenario.has_doorway(entry.zone), doorway, "%s: %s porta de dentro" % [name, "com" if doorway else "sem"])
		var live: Dictionary = Campaign.state.session.expedition.corridor
		live.index = maxi(int(live.index), int(entry.door_step))
		corridor._enter_segment(corridor._segment_of(int(entry.door_step)), float(entry.door_x))
		var deepest := 0.0
		corridor._enter_side_room(room)
		var limit := Time.get_ticks_msec() + 15000
		while (corridor.busy or corridor.side_room != room) and Time.get_ticks_msec() < limit:
			await _tree.process_frame
			if corridor.side_room < 0:
				deepest = minf(deepest, street._leader.position.z - street.lane_z)
		var stop: float = corridor._room_stop(entry)
		if doorway:
			t.check(deepest < -1.0, "%s: a equipe anda até a porta do Cais antes de entrar (%.1f m para o fundo)" % [name, -deepest])
		else:
			t.check(deepest > -LANE - 0.01, "%s: sem a porta de dentro, ninguém anda para o fundo (%.1f m)" % [name, -deepest])
		if doorway:
			var near: Array = corridor.scenario_props.filter(func(p): return p.zone == entry.zone and absf(float(p.x) - (float(entry.x0) + stop)) < AHStreetCorridor.REACH)
			t.equal(near.map(func(p): return p.name), [], "%s: a parada fica longe dos objetos de busca" % name)
		t.check(corridor.side_room == room and absf(street._leader.position.x - (float(entry.x0) + stop)) < 0.2,
			"%s: e fica na sala, %s" % [name, "ao lado da porta de dentro" if doorway else "na entrada"])
		corridor._leave_side_room()
		await _tree.process_frame
		limit = Time.get_ticks_msec() + 15000
		while corridor.busy and Time.get_ticks_msec() < limit:
			await _tree.process_frame
		t.check(corridor.side_room < 0 and absf(street._leader.position.x - float(entry.door_x)) < 0.3, "%s: a volta deixa a equipe na mesma porta" % name)
		t.check(absf(street._leader.position.z - street.lane_z) < 0.5, "%s: na faixa de andar" % name)
