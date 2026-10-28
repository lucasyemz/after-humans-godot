## O herói Caído perde a placa no combate (#178): a barra, a moldura de quem age e os estados somem, como no inimigo
## derrubado. O herói no Último Fôlego (vida 0, ainda na luta) e o curado ficam com ela; o inimigo vivo também. No texto
## Normal e no Maior.
extends RefCounted

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var real_size: int = Settings.text_size
	var tips: bool = Tips.enabled
	Campaign.save_dir = "user://test-fallen-plate-%d" % Time.get_ticks_usec()
	Tips.enabled = false
	await _fight()
	Settings.set_text_size(real_size)
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


## Uma luta da Rua das Vitrines (a do test_plates_crowd).
func _fight() -> void:
	Campaign.state = Campaign.create_initial(6)
	AHJourneyRules.start_expedition(Campaign.state, "fase_1", 1)
	var route: Dictionary = Campaign.state.session.expedition.corridor
	var step := 7
	for i in step:
		route.steps[i].resolved = true
	route.index = step - 1
	GameFlow.change_to("street", {}, false)
	var street = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			street = _tree.current_scene
			break
	if not t.check(street != null, "a rua abre"):
		return
	for k in 4:
		street.corridor.debug_next_fight()
		for i in 20:
			await _tree.process_frame
		if street.corridor.guards.has(route.index) and route.index == step:
			break
	street.corridor._start_fight(route.index, true)
	var hud: AHCombatHud = street._arena.hud
	for i in 1500:
		if hud != null and hud.waiting:
			break
		await _tree.process_frame
	if not t.check(hud != null and hud.waiting, "a vez do jogador chega"):
		return
	for size in [0, 2]:
		Settings.set_text_size(size)
		for i in 6:
			await _tree.process_frame
		await _check(hud, "Maior" if size == 2 else "Normal")


func _check(hud: AHCombatHud, profile: String) -> void:
	var state = hud.session.state
	var hero = state.player_team[state.player_team.size() - 1]
	var enemy = state.enemy_team[0]
	var other_enemy = state.enemy_team[1]
	var hp: int = hero.hp
	var enemy_hp: int = enemy.hp
	# O herói cai: vida 0, sem o Último Fôlego.
	hero.hp = 0
	hero.deaths_door = false
	hud.refresh()
	await _tree.process_frame
	t.check(not hud._unit_bars[hero.id].visible, "%s: o herói Caído não tem placa (nem barra, nem estados)" % profile)
	t.check(hud.arena.cards[hero.id].visible, "%s: o corpo dele continua na cena" % profile)
	# No Último Fôlego (vida 0, ainda na luta), a placa fica.
	hero.deaths_door = true
	hud.refresh()
	await _tree.process_frame
	t.check(hud._unit_bars[hero.id].visible, "%s: no Último Fôlego, a placa fica" % profile)
	# Curado, a placa volta.
	hero.deaths_door = false
	hero.hp = hp
	hud.refresh()
	await _tree.process_frame
	t.check(hud._unit_bars[hero.id].visible, "%s: de volta à luta, a placa volta" % profile)
	# O inimigo derrubado perde a placa, como antes; o vivo continua com ela.
	enemy.hp = 0
	hud.refresh()
	await _tree.process_frame
	t.check(not hud._unit_bars[enemy.id].visible and hud._unit_bars[other_enemy.id].visible, "%s: o inimigo derrubado sem placa, o vivo com ela" % profile)
	enemy.hp = enemy_hp
	hud.refresh()
	await _tree.process_frame
