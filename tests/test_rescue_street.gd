## O preso do resgate na cena de verdade (#188), nas fases 1 a 5 e em duas sementes: ele fica dentro do trecho dele, com
## o líder em cima a ação é soltar (nenhum objeto de busca nem porta toma o aviso) e, vencida a patrulha, a equipe um
## trecho atrás ainda solta.
extends RefCounted

const J := preload("res://scripts/flow/journey_rules.gd")
const S := preload("res://scripts/flow/station_rules.gd")
const SEEDS := [4242, 3333]

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-rescue-street-%d" % Time.get_ticks_usec()
	for info in J.PHASES:
		for seed_value in SEEDS:
			await _case(String(info.id), seed_value)
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _case(phase_id: String, seed_value: int) -> void:
	var c: Dictionary = Campaign.create_initial(seed_value)
	for info in J.PHASES:
		if info.id == phase_id:
			break
		c.completed_phases.append(info.id)
	var hero: Dictionary = c.roster[3]
	hero.captured = {"mission": "fresta_galerias", "spot": 0, "phase": phase_id, "day": 0}
	J.start_expedition(c, phase_id, seed_value)
	var rescue := AHRescue.current(c)
	var tag := "%s, semente %d" % [phase_id, seed_value]
	if not t.check(not rescue.is_empty(), "%s: a rota tem o preso" % tag):
		return
	var route: Dictionary = c.session.expedition.corridor
	var step := int(rescue.step)
	for index in step:
		route.steps[index].resolved = true
	route.index = step
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("street", {}, false)
	var street = null
	for frame in 900:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			street = _tree.current_scene
			break
	if not t.check(street != null, "%s: a rua abre" % tag):
		return
	var corridor: AHStreetCorridor = street.corridor
	for frame in 30:
		if corridor.prisoner != null:
			break
		await _tree.process_frame
	if not t.check(corridor.prisoner != null, "%s: o preso está no mapa (trecho %d)" % [tag, step]):
		return
	var x: float = corridor.prisoner.position.x
	t.check(x >= corridor._step_x(step, 0.0) and x <= corridor._step_x(step, 1.0),
		"%s: o preso fica no trecho %d (x %.2f entre %.2f e %.2f)" % [tag, step, x, corridor._step_x(step, 0.0), corridor._step_x(step, 1.0)])
	corridor._choose_action(c, route, corridor.prisoner.position)
	t.equal(corridor._action.get_method() if corridor._action.is_valid() else "", "_free_prisoner", "%s: com o líder em cima, a ação é soltar" % tag)
	# A equipe andou um trecho para trás: a patrulha já vencida, ainda solta.
	route.index = step - 1
	corridor._choose_action(c, route, corridor.prisoner.position)
	t.equal(corridor._action.get_method() if corridor._action.is_valid() else "", "_free_prisoner", "%s: um trecho atrás, ainda solta" % tag)
