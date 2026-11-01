## O pulso do Último Fôlego (#281) acaba com a luta: o herói que sobrevive volta para a rua com 1 de vida, de pé e sem a
## luz vermelha. Numa luta de verdade da rua, terminada em vitória pelo caminho do Admin.
extends RefCounted


func run(t) -> void:
	var tree: SceneTree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	Campaign.save_dir = "user://test-deaths-door-fight-%d" % Time.get_ticks_usec()
	Tips.enabled = false
	Campaign.state = Campaign.create_initial(12)
	AHJourneyRules.start_expedition(Campaign.state, "fase_1", 1)
	GameFlow.change_to("street", {}, false)
	await _until(tree, func(): return tree.current_scene != null and tree.current_scene.get("corridor") != null and not GameFlow.busy, 20.0)
	var street = tree.current_scene
	if t.check(street != null and street.get("corridor") != null, "a rua abriu"):
		street.corridor.debug_next_fight()
		var route: Dictionary = Campaign.state.session.expedition.corridor
		street.corridor._start_fight(route.index, true)
		var arena: AHCombatArena = street._arena
		await _until(tree, func(): return arena.hud.waiting, 20.0)
		if t.check(arena.active and arena.hud.waiting, "a luta pede o comando do herói"):
			var unit: AHCombat.Unit = arena.session.state.player_team[1]
			var card: AHSpriteCard = arena.cards[unit.id]
			unit.hp = 0
			unit.deaths_door = true
			arena.rest_pose(unit)
			t.check(card.in_danger(), "no Último Fôlego, o pulso liga")
			var results: Array = []
			arena.finished.connect(func(result): results.append(result))
			AHAdminActions._end_fight(arena, "win")
			await _until(tree, func(): return not results.is_empty() or arena.hud._result.visible, 15.0)
			if arena.hud._result.visible:
				arena.hud._result.visible = false
				arena.hud.result_closed.emit()
			await _until(tree, func(): return not results.is_empty(), 15.0)
			t.equal(results, ["victory"], "a luta acaba em vitória")
			t.check(not card.in_danger(), "acabada a luta, o pulso apaga")
			t.equal(card._material.emission, Color.BLACK, "e a luz vermelha some do herói")
		tree.unload_current_scene()
		await tree.process_frame
	Tips.enabled = tips
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _until(tree: SceneTree, condition: Callable, seconds: float) -> void:
	var limit := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < limit:
		await tree.process_frame
