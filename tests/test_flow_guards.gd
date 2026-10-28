## As saídas limpas da troca de cena (#72, pendências do #85):
## - a passagem recusada (outra troca em andamento) libera a cena de fundo do cartão (o vagão), que não fica órfã;
## - a cena que não carrega termina a passagem com push_error, sem prender o GameFlow.busy;
## - o corredor não avança o trecho nem fica preso no busy quando a troca de mapa seria recusada.
extends RefCounted

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-flow-guards-%d" % Time.get_ticks_usec()
	var tips: bool = Tips.enabled
	Tips.enabled = false
	await _refused_backdrop()
	await _missing_scene()
	await _corridor_waits()
	Tips.enabled = tips
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _refused_backdrop() -> void:
	var backdrop := Node3D.new()
	GameFlow.busy = true
	var went: bool = await GameFlow.travel("street", {"title": "Teste", "backdrop": backdrop})
	GameFlow.busy = false
	t.check(not went, "com outra troca em andamento, a passagem é recusada")
	t.check(not is_instance_valid(backdrop), "e a cena de fundo do cartão sai junto, sem ficar órfã")


func _missing_scene() -> void:
	GameFlow.test_scenes["broken"] = "res://tests/nao_existe.tscn"
	var went: bool = await GameFlow.travel("broken", {"title": "Teste"})
	GameFlow.test_scenes.erase("broken")
	t.check(not went, "a cena que não carrega devolve false")
	t.check(not GameFlow.busy, "e solta o busy (a próxima troca anda)")
	t.check(GameFlow.passage == null, "sem o cartão preso na tela")


func _corridor_waits() -> void:
	var c: Dictionary = Campaign.create_initial(5)
	AHJourneyRules.start_expedition(c, "fase_1", 5)
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("street", {}, false)
	var street = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			street = _tree.current_scene
			break
	if not t.check(street != null, "a rua abre"):
		return
	var route: Dictionary = c.session.expedition.corridor
	var index: int = route.index
	route.steps[index].resolved = true
	GameFlow.busy = true
	street.corridor._travel_map(c, index + 1)
	GameFlow.busy = false
	t.check(route.index == index, "com a troca em andamento, o trecho não avança")
	t.check(not street.corridor.busy, "e o corredor não fica preso no busy")
