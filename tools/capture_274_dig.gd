## Fotos da Estação em grade, parte 3 (#274): a interface de escavar e construir. Três campanhas, cada uma numa execução
## (--case):
##   new:    a campanha nova depois da primeira volta: a vista geral com os marcadores, o bloco apontado com o cartão, o
##           painel da frente de escavação e o do patamar (com o posto de escavador);
##   free:   a mesma campanha com duas vagas livres no 1º subsolo e material: a vista geral e o painel da vaga livre;
##   return: a volta que abre um bloco: o relatório (o chip curto e os detalhes), a fala da primeira volta e o aviso do
##           achado.
## Roda também no código de antes (sem a interface da #274): no lugar dos painéis novos, o painel do cômodo onde a escolha
## ficava (o Depósito, o Bar).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_274_dig.gd -- --out=<pasta> --case=<new|free|return>
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
var case := "new"
var _log_file: FileAccess
var S
var G


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
	G = load("res://scripts/flow/station_grid.gd")
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
	var after: bool = hud.has_method("block_info")
	await _frames(2)
	station.focus_overview(true)
	await _snap(station)
	await _frames(2)
	match case:
		"new":
			await _shot("overview")
			if after:
				# O bloco ao lado da Forja apontado pelas setas: a moldura, a etiqueta e o cartão.
				hud._key_room = "block:1:2"
				hud._last_mouse = hud.get_viewport().get_mouse_position()
				await _frames(3)
				await _shot("hover")
			await _open(station, hud, "block:1:2" if after else S.DEPOT, "front")
			if after:
				await _open(station, hud, "block:L2", "landing")
		"free":
			await _shot("overview")
			await _open(station, hud, "block:1:2" if after else S.BAR, "slot")
		"return":
			hud.open_service("report")
			await _frames(6)
			await _shot("report")
			hud._report_screen.toggle_details()
			await _frames(4)
			await _shot("report_details")
			if after:
				hud._enter_shelter_then(Callable())
				await _frames(6)
				await _shot("intro")
				hud.briefing.skip()
				await _frames(4)
				station.focus_overview(true)
				await _snap(station)
				await _frames(2)
				await _shot("notice")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _open(station, hud, place: String, name: String) -> void:
	_log("abrindo " + place)
	hud.open_room(place)
	await _snap(station)
	await _frames(3)
	await _shot("panel_" + name)
	hud.close_panel()
	station.focus_overview(true)
	await _snap(station)


func _campaign(campaign) -> Dictionary:
	var c: Dictionary = campaign.create_initial(274)
	# A primeira volta: a comunidade escava o primeiro ponto.
	load("res://scripts/flow/journey_rules.gd").start_expedition(c, "fase_1", 274)
	c.session.result = "victory"
	S.finish_return(c)
	S.resolve_night(c)
	S.finish_dawn(c)
	c.station.train = S._train_defaults()
	c.inventory.scrap = 20
	c.inventory.fragments = 5
	c.station.last_return.seen = true
	c.station.grid.intro_seen = true
	if case == "free":
		# Duas voltas depois: as vagas 1 e 2 do 1º subsolo livres.
		c.station.grid.cells[0][0] = "free"
		c.station.grid.cells[0][1] = "free"
		c.station.grid.progress.clear()
	elif case == "return":
		# A volta que abre a vaga 2 do 1º subsolo, a primeira com escavação: a fala ainda não apareceu.
		c.station.grid.intro_seen = false
		c.station.grid.cells[0][1] = "free"
		c.station.grid.progress.clear()
		var row: Dictionary = G.rule("floor_1")
		c.station.last_return.seen = false
		c.station.last_return.dig = {"block": "1:2", "points": 2, "work": 2, "progress": 2, "opened": true,
			"finds": {"scrap": 2, "seeds": 0, "fragments": 0, "bandages": 0, "tool": "", "relic": "", "texts": [row.Text, row.Rolls[0].Text]}}
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
