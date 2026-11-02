## O descanso no primeiro trecho do mapa da fase (#301): nas fases com travessia (2 e 5), a parada de descanso pode cair
## logo no trecho em que a equipe chega depois de viajar. A pergunta "Um lugar quieto" (com "Acampar aqui") aparece ao
## chegar, uma vez só: reabrir a rua no mesmo trecho não pergunta de novo.
extends RefCounted

const J := preload("res://scripts/flow/journey_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-rest-travel-%d" % Time.get_ticks_usec()
	# As sementes da issue: fase 2 (9) e fase 5 (1), com o descanso no 1º trecho do mapa da fase.
	await _arrive("fase_2", 9)
	await _arrive("fase_5", 1)
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Tips.enabled = tips
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _arrive(phase_id: String, seed_value: int) -> void:
	Campaign.state = Campaign.create_initial(seed_value)
	J.start_expedition(Campaign.state, phase_id, seed_value)
	var route: Dictionary = Campaign.state.session.expedition.corridor
	var first: int = -1
	for index in route.steps.size():
		if J.map_for_step(phase_id, index) == J.phase(phase_id).get("map", ""):
			first = index
			break
	if not t.check(first > 0 and route.steps[first].type == "rest",
			"%s/%d: o descanso é o 1º trecho do mapa da fase (trecho %d)" % [phase_id, seed_value, first + 1]):
		return
	# A travessia vencida: a equipe parada no último trecho dela.
	for index in first:
		route.steps[index].resolved = true
	route.index = first - 1
	GameFlow.change_to("street", {}, false)
	if not await _open_street():
		return
	var corridor = _tree.current_scene.corridor
	t.check(corridor.debug_next_fight(), "%s: a equipe segue para o mapa da fase" % phase_id)
	if not await _open_street():
		return
	await _frames(6)
	corridor = _tree.current_scene.corridor
	route = Campaign.state.session.expedition.corridor
	t.equal(route.index, first, "%s: chega no trecho do descanso" % phase_id)
	var modal = corridor.hud._modal
	t.check(modal != null and modal.visible and _contains(modal, "Um lugar quieto"), "%s: ao chegar, a pergunta do descanso aparece" % phase_id)
	var buttons: Array = modal.find_children("*", "Button", true, false) if modal != null else []
	t.check(buttons.any(func(b): return b.text.to_lower() == "acampar aqui"), "%s: com \"Acampar aqui\"" % phase_id)
	t.check(Campaign.state.session.expedition.get("asked", []).has("rest"), "%s: e o save sabe que já perguntou" % phase_id)
	# Seguir em frente fecha; reabrir a rua no mesmo trecho não pergunta de novo.
	for button in buttons:
		if button.text.to_lower() == "seguir em frente":
			button.pressed.emit()
	await _frames(3)
	GameFlow.change_to("street", {}, false)
	if not await _open_street():
		return
	await _frames(6)
	modal = _tree.current_scene.corridor.hud._modal
	t.check(modal == null or not modal.visible or not _contains(modal, "Um lugar quieto"), "%s: reaberta a rua, não pergunta de novo" % phase_id)
	# Com o objetivo concluído (a volta depois do guardião), reabrir no descanso não anuncia nada (QA da #301).
	var expedition: Dictionary = Campaign.state.session.expedition
	expedition.asked = []
	expedition.objective_completed = true
	expedition.cargo = {"boxes": [{}], "chosen": 0}
	Campaign.save()
	GameFlow.change_to("street", {}, false)
	if not await _open_street():
		return
	await _frames(6)
	var hud = _tree.current_scene.corridor.hud
	t.check(not hud._toast_label.text.contains("Descanso") and (hud._modal == null or not hud._modal.visible),
		"%s: com o objetivo concluído, reabrir no descanso não anuncia (\"%s\")" % [phase_id, hud._toast_label.text])


## Espera a troca em andamento terminar com a rua aberta.
func _open_street() -> bool:
	for frame in 1800:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			return true
	return t.check(false, "a rua abre")


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame


func _contains(node: Node, text: String) -> bool:
	for label in node.find_children("*", "Label", true, false):
		if label.text.contains(text):
			return true
	for label in node.find_children("*", "RichTextLabel", true, false):
		if label.text.contains(text):
			return true
	return false
