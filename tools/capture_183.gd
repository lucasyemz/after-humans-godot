## Fotos das missões solo (#183), no Mapa da Rede de verdade: a aba fechada (Preparação nível 1), a lista do dia, uma
## missão escolhida com um herói (o selo), uma missão em curso (o pino de quem está fora), a volta (o relatório) e um
## capturado (o pino do resgate). Nos textos Normal e Maior.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_183.gd -- --out=<pasta>
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
	var settings = root.get_node("Settings")
	var S = load("res://scripts/flow/station_rules.gd")
	var M = load("res://scripts/flow/side_mission_rules.gd")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	settings._persist = false
	root.get_node("Tips").set("enabled", false)
	var c: Dictionary = campaign.create_initial(23)
	c.completed_phases = ["fase_1", "fase_2"]
	S.adjust(c, S.SUPPLIES, 8)
	c.station.side_missions = {"day": -1, "board": [], "reports": [], "seed": 7}
	c.station.route_seeds = {"fase_1": 4242, "fase_2": 4242, "fase_3": 4242, "fase_4": 4242, "fase_5": 4242}
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	await _frames(10)
	while flow.busy:
		await process_frame
	await _frames(30)
	var map = current_scene.hud._map
	for size in [0, 2]:
		settings.set_text_size(size)
		var tag := "maior" if size == 2 else "normal"
		c.station.rooms[S.PREPARATION] = 1
		map.open("")
		await _frames(8)
		await _shot("locked-" + tag)
		c.station.rooms[S.PREPARATION] = 2
		map.open("")
		map.show_tab("missions")
		await _frames(8)
		await _shot("board-" + tag)
		var board: Array = M.board(c)
		map.pick_mission(board[0].id)
		map.pick_hero(c.roster[1].id)
		await _frames(8)
		await _shot("mission-" + tag)
	# Em curso: a Íris na primeira missão; depois o dia vira e ela volta (o relatório); por fim, um capturado.
	# A missão e a Íris já estão escolhidas (a última foto); pick_mission de novo tiraria a escolha.
	map.send_mission()
	await _frames(8)
	await _shot("running")
	var hero: Dictionary = c.roster[1]
	while hero.has("side_mission"):
		S.run_cycle(c, "rest_%d" % (int(c.station.cycle_number) + 1), 0)
	map.refresh()
	await _frames(8)
	await _shot("returned-" + String(c.station.last_cycle.missions[0].result))
	c.roster[2].captured = {"mission": "cisterna_turva", "spot": 5, "phase": "fase_2", "day": int(c.station.cycle_number)}
	map.refresh()
	await _frames(8)
	await _shot("captured")
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
