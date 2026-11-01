## O trem das missões solo na Estação de verdade (#183, segunda parte): com uma dupla de recrutas esperando o trem de
## sempre, só quem volta da missão desce (o segundo do recruta não), o ferido desce no passo de quem manca e, depois de
## RECEBER, o trem de sempre vem com o recruta.
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")
const M := preload("res://scripts/flow/side_mission_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-mission-train-%d" % Time.get_ticks_usec()
	await _arrival()
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _arrival() -> void:
	var c: Dictionary = Campaign.create_initial(23)
	var iris: Dictionary = c.roster.filter(func(h): return h.class_id == "sapo")[0]
	iris.on_train = true
	iris.hp = ceili(int(iris.max_hp) * 0.35)
	M.state(c).reports = [{"hero_id": iris.id, "mission": "cisterna_turva", "day": 1, "result": "hurt", "reward": {"kind": "supplies", "amount": 1, "relic_id": ""}}]
	# O trem de sempre com dois (#182), à força pela barra de Admin, até descerem dois.
	for attempt in 40:
		c.station.train = S._train_defaults()
		S.train_on_return(c, "exp_test_%d" % attempt, "hero")
		if not c.station.train.get("next", {}).is_empty():
			break
	t.check(not c.station.train.get("next", {}).is_empty(), "o trem de sempre tem uma dupla de recrutas esperando")
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("station", {}, false)
	var station = null
	for frame in 900:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene is AHStation and frame > 3:
			station = _tree.current_scene
			break
	if not t.check(station != null, "a Estação abre"):
		return
	await _frames(30)
	station.hud.open_service("train")
	# A cena anda pelo relógio: espera o trem parar e ela descer (com um limite).
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 20000:
		await _tree.process_frame
		if is_instance_valid(station._candidate) and Time.get_ticks_msec() - started > 1000:
			break
	t.check(is_instance_valid(station._candidate) and station._candidate_id == iris.id, "a Íris desce do trem das missões")
	t.check(not is_instance_valid(station._companion), "o segundo do recruta não desce junto")
	var walker: Array = station._walkers.filter(func(w): return w.card == station._candidate)
	t.check(walker.is_empty() or float(walker[0].speed) < AHStation.TRAIN_WALK_SPEED * station.train_speed(), "ferida, ela desce no passo de quem manca")
	# RECEBER: ela fica, o trem parte e o de sempre vem com o recruta.
	station.hud._mission_train_done()
	for frame in 1500:
		await _tree.process_frame
		if frame > 60 and not M.train_pending(Campaign.state) and station._candidate_id == String(Campaign.state.station.train.candidate_id) and not station.train_busy():
			break
	t.check(not M.train_pending(Campaign.state) and not M.away(iris), "depois de RECEBER, a Íris está na Estação")
	t.equal(station._candidate_id, String(Campaign.state.station.train.candidate_id), "e o trem de sempre traz o recruta")


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
