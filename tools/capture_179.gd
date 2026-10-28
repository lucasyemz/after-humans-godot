## Fotos dos caídos no mapa (#179): a rua logo depois da luta em que um da equipe caiu (o corpo no chão e o aviso), o
## líder perto dele (Levantar), o lembrete da volta com ele ainda no chão, a equipe carregando e o resumo da volta.
## Roda também no código de antes (o caído some da rua), para o antes: só a primeira foto e o resumo.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_179.gd -- --out=<pasta> [--text-size=2] [--colorblind]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
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
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	if colorblind:
		root.get_node("Settings").set_colorblind(true)
	var J = load("res://scripts/flow/journey_rules.gd")
	campaign.state = campaign.create_initial(6)
	J.start_expedition(campaign.state, "fase_1", 4242)
	flow.change_to("street", {}, false)
	var street = null
	for frame in 600:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.name == "Street" and frame > 3:
			street = current_scene
			break
	var corridor = street.corridor
	corridor.debug_next_fight()
	await _frames(10)
	corridor._start_fight(campaign.state.session.expedition.corridor.index, true)
	var arena = street._arena
	for i in 1500:
		if arena.hud != null and arena.hud.waiting:
			break
		await process_frame
	# O segundo da fila cai; os inimigos ficam a um golpe, e a luta corre sozinha até a vitória.
	var fallen = arena.session.state.player_team[1]
	fallen.hp = 0
	fallen.deaths_door = false
	for unit in arena.session.state.enemy_team:
		unit.hp = 1
	arena.auto_battle = true
	arena.speed = 8.0
	arena.hud.command_chosen.emit({"kind": "defend"})
	while arena.active:
		await process_frame
	await _frames(30)
	await _shot("after_fight")
	var hero_id: String = fallen.hero_id
	if "bodies" in corridor and corridor.bodies.has(hero_id):
		# O líder vai até o corpo: o aviso pede para levantar.
		street._leader.position.x = corridor.bodies[hero_id].position.x + 0.6
		await _frames(30)
		await _shot("lift_prompt")
		corridor._retreat()
		await _frames(20)
		await _shot("reminder")
		corridor.hud.close_modal()
		corridor._action.call()
		await _frames(30)
		await _shot("carried")
	corridor._retreat()
	await _frames(30)
	await _shot("summary")
	_remove(campaign.save_dir)
	quit(0)


func _remove(dir: String) -> void:
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
