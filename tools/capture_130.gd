## Fotos da barra de Admin (#130): cada aba na Estação e a de Combate por cima de uma luta.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_130.gd -- --out=<pasta> [--text-size=2] [--colorblind]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var colorblind := false
	var text_size := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--colorblind":
			colorblind = true
		elif arg.begins_with("--text-size="):
			text_size = int(arg.trim_prefix("--text-size="))
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	var admin = root.get_node("Admin")
	var J = load("res://scripts/flow/journey_rules.gd")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	root.get_node("Settings").set_colorblind(colorblind)
	root.get_node("Settings").set_text_size(text_size)
	campaign.state = campaign.create_initial(6)
	campaign.save()
	flow.change_to("station", {}, false)
	await _frames(10)
	while flow.busy:
		await process_frame
	await _frames(30)
	admin.open()
	for tab in ["Mapas", "Clima", "Ajustes", "Recursos", "Heróis", "Combate", "Jornada"]:
		admin.panel.show_tab(tab)
		await _frames(6)
		await _shot("station_%s" % tab.to_lower().replace("í", "i").replace("ó", "o"))
	admin.panel.show_tab("Recursos")
	admin.panel.press("add_seeds")
	await _frames(4)
	await _shot("station_armed")
	admin.close()
	# A luta, com a aba de Combate por cima.
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
	street.corridor._start_fight(campaign.state.session.expedition.corridor.index, true)
	for i in 900:
		if street._arena.hud.waiting:
			break
		await process_frame
	await _frames(20)
	admin.open()
	admin.panel.show_tab("Combate")
	await _frames(6)
	await _shot("fight_combate")
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
