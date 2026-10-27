## A água pintada do Cais e da Ponte das Raízes (#140):
## - o Cais e a Ponte usam a água pintada (water_painted.gdshader), com a margem, as estacas e os pilares na espuma;
## - o panorama da Ponte troca a água parada da pintura pela viva (scenario_card_water.gdshader), abaixo da linha d'água;
## - "Reduzir efeitos" deixa a água mais lenta e sem piscar, e volta ao desligar;
## - a câmera da Ponte é a dos outros cenários (EXPLORE_CAMERA.scenario): a mesma distância e a mesma altura.
extends RefCounted

const J := preload("res://scripts/flow/journey_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-water-%d" % Time.get_ticks_usec()
	_data()
	var views := {}
	for spec in [["RiverDock", 0], ["RootBridge", 4], ["SealedShelter", 0]]:
		views[spec[0]] = await _map(spec[0], spec[1])
	if views.RootBridge != null and views.SealedShelter != null and views.RiverDock != null:
		t.check(absf(views.RootBridge.x - views.SealedShelter.x) < 0.3 and absf(views.RootBridge.y - views.SealedShelter.y) < 0.3,
			"a câmera da Ponte igual à dos outros cenários (%.1f m e %.1f m; o Abrigo, %.1f m e %.1f m)" % [views.RootBridge.x, views.RootBridge.y, views.SealedShelter.x, views.SealedShelter.y])
		t.check(absf(views.RootBridge.x - views.RiverDock.x) < 0.3, "e à do Cais")
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _data() -> void:
	for map in ["RiverDock", "RootBridge"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/%s.json" % map))
		var water: Array = data.materials.filter(func(m): return m.kind == "water")
		t.check(not water.is_empty() and water.all(func(m): return m.get("painted", false)), "%s: a água pintada" % map)
		t.check(water.all(func(m): return not Array(m.get("foam_points", [])).is_empty()), "%s: a espuma nas estacas e nos pilares" % map)
	var bridge: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/RootBridge.json"))
	var panorama: Array = bridge.materials.filter(func(m): return String(m.get("albedo", "")).ends_with("T_BridgePanorama.webp"))
	t.check(not panorama.is_empty() and panorama.all(func(m): return m.get("waterline") != null), "a Ponte: o panorama com a água viva")
	t.check(not load("res://scripts/street/street.gd").EXPLORE_CAMERA.has("bridge"), "sem a câmera à parte da Ponte")


## Abre o mapa na fase dele e devolve (distância, altura) da câmera até o líder.
func _map(map: String, index: int):
	var phase := "fase_3" if map == "SealedShelter" else "fase_2"
	var c := Campaign.create_initial(12)
	c.completed_phases = ["fase_1", "fase_2"]
	J.start_expedition(c, phase, 12)
	var route: Dictionary = c.session.expedition.corridor
	for step in route.steps.size() - 1:
		route.steps[step].resolved = true
	route.index = index
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
	for frame in 30:
		await _tree.process_frame
	var scenario: AHScenarioWorld = street.scenario
	if map != "SealedShelter":
		var shaders: Array = scenario._waters.map(func(m): return m.shader.resource_path.get_file())
		t.check(shaders.has("water_painted.gdshader"), "%s: a água do chão é a pintada" % map)
		if map == "RootBridge":
			t.check(shaders.has("scenario_card_water.gdshader"), "a Ponte: o panorama com a água viva")
		# Reduzir efeitos: mais lenta e sem piscar; desligado, de volta.
		Campaign.state.settings.reduced_environment_effects = true
		Settings.changed.emit()
		t.check(scenario._waters.all(func(m): return float(m.get_shader_parameter("flow")) < 1.0 and float(m.get_shader_parameter("sparkle")) == 0.0),
			"%s: com Reduzir efeitos, a água anda devagar e não pisca" % map)
		Campaign.state.settings.reduced_environment_effects = false
		Settings.changed.emit()
		t.check(scenario._waters.all(func(m): return float(m.get_shader_parameter("flow")) == 1.0 and float(m.get_shader_parameter("sparkle")) == 1.0),
			"%s: desligado, volta" % map)
	var camera: Camera3D = street.get_viewport().get_camera_3d()
	var leader: Vector3 = street._leader.global_position
	return Vector2(camera.global_position.distance_to(leader), camera.global_position.y - leader.y)
