## Fotos das telas da interface (#29): o título, a Estação (vista geral, plano, personagens, Preparação, mapa, Opções,
## noite e relatório da volta), a exploração (HUD, Mochila, Opções) e a luta. Serve para comparar antes e depois de
## mexer no estilo, no texto Normal, no Maior e com as cores para daltonismo. Precisa de janela (xvfb no Linux):
##   Godot --path . --resolution 1920x1080 --script res://tools/capture_ui.gd -- --out=<pasta> [--text-size=2] [--colorblind]
## A campanha e o save das fotos ficam numa pasta dentro de <pasta>; nada vai para a pasta de quem joga.
extends SceneTree

var out := ""
## Carregados na hora: com --script, o script compila antes dos autoloads (GameData) de que as regras dependem.
var S
var _frames_wait := 24


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	S = load("res://scripts/flow/station_rules.gd")
	var colorblind := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--colorblind":
			colorblind = true
	if out == "":
		push_error("Uso: --script res://tools/capture_ui.gd -- --out=<pasta> [--text-size=N] [--colorblind]")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var campaign_service = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	campaign_service.save_dir = out.path_join("save")
	if colorblind:
		root.get_node("Settings").set_colorblind(true)
	# As dicas da primeira vez não cobrem as telas.
	root.get_node("Tips").set("enabled", false)

	# Título, sem save.
	campaign_service.state = campaign_service.create_initial(5)
	flow.change_to("title", {}, false)
	await _settle(flow)
	await _shot("title")

	# Estação: vista geral, plano, personagens, Preparação, mapa e Opções.
	campaign_service.new_game(5)
	var c: Dictionary = campaign_service.state
	c.inventory.scrap = 9
	c.inventory.fragments = 3
	flow.change_to("station", {}, false)
	await _settle(flow)
	var hud = current_scene.hud
	await _shot("station")
	for spec in [["plan", "service"], ["characters", "room"], ["forge", "room"], ["options", "service"]]:
		if spec[1] == "service":
			hud.open_service(spec[0])
		else:
			hud.open_room(spec[0])
		await _shot("station-" + spec[0])
		hud.close_panel()
	hud.open_room(S.PREPARATION)
	await _shot("station-preparation")
	hud.close_panel()
	hud.open_map()
	await _shot("station-map")
	hud._map.visible = false

	# A volta: relatório e noite no Dormitório.
	var J = load("res://scripts/flow/journey_rules.gd")
	J.start_expedition(c, "fase_1", 77)
	c.session.result = "victory"
	c.session.expedition.loot = {"seeds": 6, "scrap": 3, "fragments": 1}
	c.roster[1].hp = int(c.roster[1].max_hp / 3)
	S.finish_return(c)
	campaign_service.save()
	flow.change_to("station", {}, false)
	await _settle(flow)
	hud = current_scene.hud
	hud.open_service("report")
	await _shot("station-report")
	hud.close_panel()
	c.station.last_return.seen = true
	hud.open_room(S.DORMITORY)
	await _shot("station-night")

	# Exploração: HUD, Mochila e Opções.
	campaign_service.state = campaign_service.create_initial(6)
	c = campaign_service.state
	J.start_expedition(c, "fase_1", 4242)
	flow.change_to("street", {}, false)
	await _settle(flow)
	for i in 40:
		await process_frame
	var street = current_scene
	street.apply_corridor_weather("sunset")
	await _shot("explore")
	street.exploration_hud.show_inventory()
	await _shot("explore-inventory")
	street.exploration_hud.close_modal()
	street.exploration_hud.show_options()
	await _shot("explore-options")
	street.exploration_hud.close_modal()

	# A luta: a primeira patrulha, na vez do jogador.
	street.corridor.debug_next_fight()
	for i in 10:
		await process_frame
	var route: Dictionary = c.session.expedition.corridor
	if street.corridor.guards.has(route.index):
		street.corridor._start_fight(route.index, true)
		for i in 600:
			if street._arena.hud != null and street._arena.hud.waiting:
				break
			await process_frame
		await _shot("combat")
	else:
		print("sem patrulha para a luta")

	for file in DirAccess.get_files_at(campaign_service.save_dir):
		DirAccess.remove_absolute(campaign_service.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign_service.save_dir)
	quit()


func _settle(flow) -> void:
	for i in 600:
		await process_frame
		if not flow.busy and current_scene != null and i > 10:
			break


func _shot(name: String) -> void:
	for i in _frames_wait:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)
