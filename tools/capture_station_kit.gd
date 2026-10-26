## Fotos das telas da Estação no kit (#60, docs/design/hud-station.md): o relatório da volta (e os detalhes) e a Sala
## dos Personagens (e o Treino). Para comparar com o alvo nos quatro perfis.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_station_kit.gd -- --out=<pasta> [--text-size=2] [--colorblind]
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
	var S = load("res://scripts/flow/station_rules.gd")
	var J = load("res://scripts/flow/journey_rules.gd")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	if colorblind:
		root.get_node("Settings").set_colorblind(true)
	# A volta da primeira vitória na Rua das Vitrines, com o objetivo de água cumprido: um herói em forma, um com
	# ferimento leve, um com ferimento grave e um recruta.
	var c: Dictionary = campaign.create_initial(17)
	var team: Array = c.roster.slice(0, 4).map(func(h): return h.id)
	J.start_expedition(c, "fase_1", 17)
	var expedition: Dictionary = c.session.expedition
	expedition.team = team
	expedition.focus = S.FOCUS_WATER
	expedition.objective_done = true
	expedition.loot = {"seeds": 14, "scrap": 6, "fragments": 3, "water": 4, "supplies": 2}
	S.hero(c, team[1]).hp = int(S.hero(c, team[1]).max_hp * 0.6)
	S.hero(c, team[2]).hp = int(S.hero(c, team[2]).max_hp * 0.3)
	expedition.stats = {team[0]: {"damage": 18, "healing": 0, "downs": 3}, team[1]: {"damage": 9, "healing": 0, "downs": 1},
		team[2]: {"damage": 0, "healing": 12, "downs": 0}, team[3]: {"damage": 5, "healing": 0, "downs": 1}}
	# O Centro de Pesquisa recuperado: a aba "Melhoria · 3 frag." sobre a carta.
	c.station.rooms[S.RESEARCH] = 1
	J.finish_corridor(c)
	c.session.result = "victory"
	S.finish_return(c)
	c.station.last_return.seen = false
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	while flow.busy or current_scene == null:
		await process_frame
	var station = current_scene
	await _until(func(): return station.hud.current == "arrival" or station.hud.current == "report")
	if station.hud.current == "arrival":
		station.finish_team_arrival()
	await _until(func(): return station.hud.current == "report" or station.hud.briefing_open())
	if station.hud.briefing_open():
		station.hud.briefing.skip()
		await _until(func(): return station.hud.current == "report")
	await _frames(150)
	await _shot("1-report")
	station.hud._report_screen.toggle_details()
	await _frames(10)
	await _shot("2-report-details")
	# A Sala dos Personagens: o Bento com XP para treinar, um traço de cada lado; depois o Treino.
	station.hud._report_screen.enter_shelter.emit()
	await _until(func(): return station.hud.current == "")
	var bento = S.hero(c, team[0])
	bento.xp = 90
	c.inventory.seeds = maxi(5, int(c.inventory.get("seeds", 0)))
	station.hud.open_room(S.CHARACTERS)
	# A foto com a câmera já no cômodo (ela vem pela passagem).
	await _frames(10)
	await _until(func(): return station.camera_settled())
	await _frames(20)
	await _shot("3-characters")
	station.hud._room_screen.training = true
	station.hud._room_screen.rebuild()
	await _frames(10)
	await _shot("4-training")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _until(condition: Callable) -> void:
	for i in 20000:
		if condition.call():
			return
		await process_frame


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
