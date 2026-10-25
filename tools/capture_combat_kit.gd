## Fotos da luta no kit (#60, docs/design/hud-target.md): a vez do herói, a mira (a aba "Escolha um alvo", o nome do
## alvo e a habilidade escolhida), a dica de uma habilidade e a tela do fim. Para comparar com o alvo nos quatro perfis.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_combat_kit.gd -- --out=<pasta> [--text-size=2] [--colorblind]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var colorblind := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--colorblind":
			colorblind = true
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	var J = load("res://scripts/flow/journey_rules.gd")
	var Rewards = load("res://scripts/flow/fight_rewards.gd")
	campaign.save_dir = out.path_join("save")
	root.get_node("Tips").set("enabled", false)
	if colorblind:
		root.get_node("Settings").set_colorblind(true)
	campaign.state = campaign.create_initial(6)
	J.start_expedition(campaign.state, "fase_1", 4242)
	flow.change_to("street", {}, false)
	for frame in 600:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.name == "Street" and frame > 10:
			break
	var street = current_scene
	street.apply_corridor_weather("sunset")
	street.corridor.debug_next_fight()
	await _frames(10)
	var route: Dictionary = campaign.state.session.expedition.corridor
	street.corridor._start_fight(route.index, true)
	var hud = street._arena.hud
	for i in 900:
		if hud != null and hud.waiting:
			break
		await process_frame
	await _frames(30)
	await _shot("1-turn")
	# A dica da primeira habilidade (o mouse em cima).
	var first: Button = hud._abilities.get_child(0)
	first.mouse_entered.emit()
	await _frames(6)
	await _shot("2-tip")
	first.mouse_exited.emit()
	# A mira: a primeira habilidade com alvo, e o primeiro alvo apontado.
	for option in hud._options:
		if option.usable and not option.self:
			hud._on_ability(option)
			break
	await _frames(4)
	if not hud._markers.is_empty():
		hud._markers[0].grab_focus()
		hud._hover_target(int(hud._markers[0].get_meta("rank")))
	await _frames(10)
	await _shot("3-target")
	hud._clear_markers()
	# A tela do fim (aberta à mão, sem fechar sozinha).
	var session = hud.session
	session.state.victory = true
	session.state.is_over = true
	hud.show_result("victory", false, Rewards.criteria(session, false, "fase_1"))
	await _frames(40)
	await _shot("4-result")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
