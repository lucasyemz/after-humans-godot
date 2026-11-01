## Fotos da Estação em grade, parte 2 (#273): a cena. Três campanhas, cada uma numa execução (--case):
##   new:     a campanha nova depois da primeira volta (a vista geral, a vista arrastada até o 3º subsolo, o fogareiro e os
##            caixotes da plataforma e a Sala com o herói em pé no Alojamento de 6 m, #181);
##   digging: a mesma campanha mais adiante (uma vaga livre, a escavação em dois terços e o patamar do 2º subsolo aberto);
##   legacy:  um save de antes da grade (a planta herdada: a Forja de 12 m e 3,2 m, a Enfermaria de 12 m e a vaga livre).
## Roda também no código de antes (sem a cena da grade), para o antes e depois.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_273_grid.gd -- --out=<pasta> --case=<new|digging|legacy>
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
var case := "new"
var _log_file: FileAccess
var S


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--case="):
			case = arg.trim_prefix("--case=")
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	# Aqui (sem GPU) a Estação desenha devagar: o passo a passo vai para log.txt, para acompanhar.
	_log_file = FileAccess.open(out.path_join("log.txt"), FileAccess.WRITE)
	S = load("res://scripts/flow/station_rules.gd")
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	var c: Dictionary = _campaign(campaign)
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	while flow.busy or current_scene == null or current_scene.get("hud") == null:
		await process_frame
	_log("a Estação abriu")
	var station = current_scene
	var hud = station.hud
	await _frames(2)
	station.focus_overview(true)
	await _snap(station)
	await _frames(2)
	await _shot("overview")
	if station.get("pan_y") != null:
		var down: Vector2 = station.get_script().get_script_constant_map().get("PAN_Y_RANGE", Vector2.ZERO)
		_log("descendo a vista até %.1f m" % down.x)
		station.set_pan(station.pan, down.x)
		await _snap(station)
		await _frames(2)
		await _shot("overview_down")
		station.set_pan(station.pan, 0.0)
	var rooms: Array = {"new": [S.CANTEEN, S.DEPOT], "digging": [], "legacy": [S.FORGE, S.INFIRMARY]}.get(case, [])
	for room_id in rooms:
		_log("abrindo " + room_id)
		hud.open_room(room_id)
		await _snap(station)
		await _frames(2)
		await _shot("room_" + room_id)
		hud.close_panel()
	if case == "new":
		# A Sala (#181): o herói escolhido de pé no Alojamento de 6 m.
		hud.open_room(S.CHARACTERS)
		await _frames(2)
		await _snap(station)
		await _frames(4)
		await _shot("characters")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _campaign(campaign) -> Dictionary:
	var c: Dictionary = campaign.create_initial(273)
	if case == "legacy":
		# Um save de antes da grade, já com a Estação toda recuperada (a Forja, a Pesquisa, o Bar e a Enfermaria no nível
		# 2): sem a grade, ele abre com a planta herdada.
		for room_id in [S.FORGE, S.RESEARCH, S.BAR, S.INFIRMARY]:
			c.station.rooms[room_id] = 1
		c.station.rooms[S.INFIRMARY] = 2
		c.station.rooms[S.DEPOT] = 2
		if c.station.has("grid"):
			# Com cômodos recuperados, o save não está na abertura do tutorial: a planta herdada.
			c.station.erase("grid")
			load("res://scripts/flow/station_grid.gd").migrate(c)
	# A primeira volta: a comunidade escava o primeiro ponto (no código de antes, nada).
	load("res://scripts/flow/journey_rules.gd").start_expedition(c, "fase_1", 273)
	c.session.result = "victory"
	S.finish_return(c)
	S.resolve_night(c)
	S.finish_dawn(c)
	c.station.train = S._train_defaults()
	c.inventory.scrap = 20
	c.inventory.fragments = 5
	c.station.last_return.seen = true
	if case == "digging" and c.station.has("grid"):
		var g: Dictionary = c.station.grid
		# Duas voltas depois: a vaga 2 do 1º subsolo livre, a vaga 1 em dois terços e o patamar do 2º subsolo aberto.
		g.cells[0][1] = "free"
		g.landings[0] = true
		g.target = "1:1"
		g.progress["1:1"] = 2
		g.progress.erase("1:2")
	return c


func _snap(station) -> void:
	station._path.clear()
	station._set_goal(station._goal, true)
	await _frames(1)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		_log("sem janela: " + name)
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	_log("foto " + name)


func _log(text: String) -> void:
	_log_file.store_line("%d ms: %s" % [Time.get_ticks_msec(), text])
	_log_file.flush()
