## QA por captura do tutorial da abertura (#144) no Corredor de Contenção (#147), pelas cenas de verdade:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_tutorial.gd -- --out=<pasta>
## Campanha própria na pasta da saída (o save do jogador fica intacto). Fotografa a escolha da campanha nova, o cartão da
## abertura, cada dica (andar, a habilidade e o alvo na primeira luta, a busca, a Mochila, a patrulha, a posição na
## segunda luta, o item na terceira, o trem), a conversa do Nick, a recompensa, o vagão e a chegada com o debriefing.
extends SceneTree

var out := ""
var shots := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	campaign.save_dir = out.path_join("save")
	campaign.state = campaign.create_initial(7)
	var flow = root.get_node("GameFlow")
	flow.start()
	await _until(func(): return current_scene != null and current_scene.name == "Title" and not flow.busy)
	await _wait(1.0)
	current_scene.new_button.pressed.emit()
	await _wait(0.6)
	await _shot("01-new-campaign")
	current_scene._modal.find_child("Opening", true, false).pressed.emit()
	await _until(func(): return flow.passage != null)
	await _wait(0.6)
	await _shot("02-opening-card")
	await _until(func(): return _street() != null and not flow.busy)
	var street = _street()
	var corridor = street.corridor
	var guide = corridor.guide
	await _wait(1.2)
	await _shot("03-walk-hint")
	Input.action_press("move_right")
	await _until(func(): return guide.done("walk"))
	Input.action_release("move_right")
	# A primeira luta: a dica da habilidade (travada) e a do alvo.
	corridor.debug_next_fight()
	await _wait(0.3)
	Input.action_press("move_right")
	await _until(func(): return street._arena.active)
	Input.action_release("move_right")
	var arena = street._arena
	await _until(func(): return arena.hud.waiting)
	await _wait(0.8)
	await _shot("04-fight1-ability-hint")
	var option: Dictionary = arena.hud._options.filter(func(o): return o.usable and not o.self)[0]
	arena.hud._on_ability(option)
	await _wait(0.8)
	await _shot("05-fight1-target-hint")
	arena.hud._via_mouse = false
	arena.hud._markers[0].pressed.emit()
	await _auto(arena)
	# O Nick.
	corridor.debug_next_fight()
	await _until(func(): return street.exploration_hud.find_child("Briefing", true, false) != null)
	await _wait(0.8)
	await _shot("06-nick-arrives")
	street.exploration_hud.find_child("Briefing", true, false).skip_button.pressed.emit()
	await _until(func(): return not corridor.busy)
	# A busca e a Mochila.
	var entry: Dictionary = corridor.scenario_props[0]
	street._place_leader(Vector3(entry.x - 0.4, street.floor_y, street.lane_z))
	await _until(func(): return guide.hint.step_id == "search")
	await _wait(0.6)
	await _shot("07-search-hint")
	corridor._action.call()
	await _wait(0.8)
	await _shot("08-bag-hint")
	corridor.open_inventory()
	await _wait(0.5)
	street.exploration_hud.close_modal()
	# A patrulha à frente e a segunda luta.
	street._place_leader(Vector3(entry.x + 1.0, street.floor_y, street.lane_z))
	await _until(func(): return guide.hint.step_id == "patrol", 6.0)
	await _wait(0.6)
	await _shot("09-patrol-hint")
	for fight in [["10-fight2-position-hint", "position"], ["11-fight3-item-hint", "item"]]:
		await _until(func(): return not corridor.busy and not street._arena.active and not street.exploration_hud.modal_open())
		await _wait(0.5)
		street._arena.auto_battle = false
		corridor.debug_next_fight()
		await _wait(0.3)
		Input.action_press("move_right")
		await _until(func(): return street._arena.active)
		Input.action_release("move_right")
		arena = street._arena
		await _until(func(): return arena.hud.waiting and guide.hint.step_id == fight[1], 20.0)
		await _wait(0.8)
		await _shot(fight[0])
		await _auto(arena)
	# O trem chega e o embarque.
	await _until(func(): return not corridor.busy and not street._arena.active)
	await _wait(0.5)
	corridor.debug_next_fight()
	await _until(func(): return guide.hint.step_id == "train" and not corridor.busy, 20.0)
	street._place_leader(Vector3(float(street.scenario.train.x) - 1.5, street.floor_y, street.lane_z))
	await _wait(0.8)
	await _shot("12-train-hint")
	corridor._action.call()
	await _wait(0.9)
	await _shot("13-reward")
	await _until(func(): return flow.passage != null and flow.passage.title_lit, 20.0)
	await _shot("14-wagon")
	await _until(func(): return current_scene != null and current_scene.name == "Station" and not flow.busy, 40.0)
	await _until(func(): return current_scene.find_child("Briefing", true, false) != null, 20.0)
	await _wait(0.8)
	await _shot("15-arrival-debriefing")
	print("%d capturas em %s" % [shots, out])
	quit(0)


func _auto(arena) -> void:
	arena.auto_battle = true
	arena.speed = 8.0
	await _until(func():
		if arena.hud.waiting:
			arena.hud.command_chosen.emit({"kind": "defend"})
		return not arena.active, 90.0)
	await _wait(0.5)


func _street():
	var scene := current_scene
	return scene if scene != null and scene.get("corridor") != null and scene.corridor != null and not scene.corridor.segments.is_empty() else null


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	shots += 1
	print(name)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _until(condition: Callable, seconds: float = 30.0) -> void:
	var limit := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < limit:
		await process_frame
	if not condition.call():
		push_warning("capture_tutorial: o passo não chegou a tempo")
