## Fotos do fim de luta que recompensa (#91): a tela do fim de uma patrulha vencida (as estrelas, os critérios e o XP
## de cada herói) e, com o guardião vencido, a carga recuperada antes e depois de escolher. Numa versão sem a #91, as
## mesmas fotos mostram o fim da luta de antes e a rua sem a carga.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_rewards.gd -- --out=<pasta>
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
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
	var flow = root.get_node("GameFlow")
	var J = load("res://scripts/flow/journey_rules.gd")
	campaign.save_dir = out.path_join("save")
	root.get_node("Tips").set("enabled", false)
	# Uma patrulha de verdade, no automático, até a tela do fim.
	campaign.state = campaign.create_initial(6)
	J.start_expedition(campaign.state, "fase_1", 4242)
	campaign.save()
	flow.change_to("street", {}, false)
	await _settle(flow)
	var street = current_scene
	street.corridor.debug_next_fight()
	await _frames(10)
	var route: Dictionary = campaign.state.session.expedition.corridor
	street.corridor._start_fight(route.index, true)
	var arena = street._arena
	for i in 900:
		if arena.hud != null and arena.hud.waiting:
			break
		await process_frame
	arena.auto_battle = true
	arena.speed = 8.0
	arena.hud.command_chosen.emit({"kind": "defend"})
	var limit := Time.get_ticks_msec() + 90000
	while arena.active and not arena.hud._result.visible and Time.get_ticks_msec() < limit:
		await process_frame
	# No automático, a tela do fim fecha sozinha em 1,5 s (no ritmo da luta, 8x aqui): a foto sai logo.
	await _frames(4)
	await _shot("01-result")
	while arena.active:
		await process_frame
	# O guardião vencido: reaberto, a carga espera a escolha.
	var c: Dictionary = campaign.create_initial(96)
	J.start_expedition(c, "fase_1", 9696)
	c.session.expedition.objective_completed = true
	campaign.state = c
	campaign.save()
	flow.change_to("street", {}, false)
	await _settle(flow)
	await _frames(20)
	await _shot("02-cargo")
	var pickers: Array = current_scene.exploration_hud.find_children("CargoPicker", "", true, false)
	if not pickers.is_empty():
		var picker = pickers[0]
		picker.buttons[1].pressed.emit()
		limit = Time.get_ticks_msec() + 5000
		while not picker.continue_button.visible and Time.get_ticks_msec() < limit:
			await process_frame
		await _frames(10)
		await _shot("03-chosen")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _settle(flow) -> void:
	for frame in 900:
		await process_frame
		if not flow.busy and flow.passage == null and current_scene != null and current_scene.name == "Street" and frame > 3:
			break
	await _frames(10)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
