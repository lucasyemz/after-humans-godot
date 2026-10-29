## Fotos do herói Caído na luta (#178): a luta da Rua das Vitrines com o último da equipe caído (vida 0, sangrando) e,
## na outra, no Último Fôlego. Roda também no código de antes (a placa do Caído ainda aparece), para o antes.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_178.gd -- --out=<pasta> [--text-size=2] [--colorblind]
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
	J.start_expedition(campaign.state, "fase_1", 1)
	var route: Dictionary = campaign.state.session.expedition.corridor
	var step := 7
	for i in step:
		route.steps[i].resolved = true
	route.index = step - 1
	flow.change_to("street", {}, false)
	var street = null
	for frame in 600:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.name == "Street" and frame > 3:
			street = current_scene
			break
	for k in 4:
		street.corridor.debug_next_fight()
		await _frames(20)
		if street.corridor.guards.has(route.index) and route.index == step:
			break
	street.corridor._start_fight(route.index, true)
	var hud = street._arena.hud
	for i in 1500:
		if hud != null and hud.waiting:
			break
		await process_frame
	var state = hud.session.state
	var hero = state.player_team[state.player_team.size() - 1]
	# O Caído: vida 0, fora da luta, ainda sangrando (o estado com o contador que ficava embaixo dele).
	hero.hp = 0
	hero.deaths_door = false
	hero.bleed.duration = 2
	hero.bleed.magnitude = 1
	street._arena.rest_pose(hero)
	hud.refresh()
	await _frames(40)
	await _shot("fallen")
	# No Último Fôlego (vida 0, ainda na luta): a placa fica.
	hero.deaths_door = true
	street._arena.rest_pose(hero)
	hud.refresh()
	await _frames(40)
	await _shot("deaths_door")
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
