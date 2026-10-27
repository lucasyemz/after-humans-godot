## O Armazém e o Navio do Cais em camadas e os interiores ligados ao Cais (#141):
## - os dois cards chapados viram camadas da mesma pintura em profundidades diferentes (o Armazém em pedaços, com o vão
##   recuado; o Navio inteiro, com a silhueta escura atrás), sem pedaço dobrado, e os volumes novos ficam fora da faixa
##   de andar;
## - cada interior tem a porta de dentro, com o lado de fora (o céu e a água pintada) e a luz de fora;
## - entrar leva a equipe até a porta do Cais e a faz sair da porta de dentro; sair faz o caminho de volta e deixa a
##   equipe na frente da mesma porta do Cais, na faixa de andar.
extends RefCounted

const J := preload("res://scripts/flow/journey_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-dock-depth-%d" % Time.get_ticks_usec()
	_data()
	await _scene()
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
	var zone: Dictionary = data.zones[0]
	var inside_lane: Array = data.parts.filter(func(p): return p.get("layer") == "141" and p.mesh == 0 and float(p.origin[2]) + absf(float(p.basis[8])) * 0.5 > float(zone.z0))
	t.equal(inside_lane.size(), 0, "os volumes novos ficam atrás da faixa de andar")
	t.equal(Array(data.get("doorways", [])).size(), 2, "as portas de dentro dos dois interiores")


func _scene() -> void:
	var c := Campaign.create_initial(14)
	c.completed_phases = ["fase_1"]
	J.start_expedition(c, "fase_2", 14)
	var route: Dictionary = c.session.expedition.corridor
	for step in route.steps.size() - 1:
		route.steps[step].resolved = true
	# A fase 2 tem o Cais e depois a Ponte: abre no começo (o Cais), com o resto vencido.
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
	if not t.check(street != null and street.scenario.map_name == "RiverDock", "o Cais abriu"):
		return
	var scenario: AHScenarioWorld = street.scenario
	t.equal(scenario.find_children("Layered_*", "MeshInstance3D", true, false).size(), 2, "cada fachada numa malha só")
	t.equal(scenario.find_children("*", "MeshInstance3D", true, false).filter(func(n): return n.material_override is ShaderMaterial and n.material_override.shader.resource_path.ends_with("door_view.gdshader")).size(), 2, "as duas portas de dentro na cena")
	t.equal(scenario.find_children("*", "OmniLight3D", true, false).filter(func(n): return String(n.name).begins_with("DoorwayLight")).size(), 2, "com a luz de fora")
	var corridor: AHStreetCorridor = street.corridor
	for room in corridor.side_rooms.size():
		var entry: Dictionary = corridor.side_rooms[room]
		var name: String = scenario.zones[entry.zone].name
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
		t.check(deepest < -1.0, "%s: a equipe anda até a porta do Cais antes de entrar (%.1f m para o fundo)" % [name, -deepest])
		t.check(corridor.side_room == room and absf(street._leader.position.x - (float(entry.x0) + 1.6)) < 0.2,
			"%s: e sai da porta de dentro para a sala" % name)
		corridor._leave_side_room()
		await _tree.process_frame
		limit = Time.get_ticks_msec() + 15000
		while corridor.busy and Time.get_ticks_msec() < limit:
			await _tree.process_frame
		t.check(corridor.side_room < 0 and absf(street._leader.position.x - float(entry.door_x)) < 0.3, "%s: a volta deixa a equipe na mesma porta do Cais" % name)
		t.check(absf(street._leader.position.z - street.lane_z) < 0.5, "%s: na faixa de andar" % name)
