## Fotos da #105 (docs/design/hud-estacao.md): as doze telas da Estação no kit, para comparar com as maquetes nos quatro
## perfis: a vista geral (com o Alojamento apontado), a Preparação, a Forja e o Centro de Pesquisa vazios, a noite no
## Dormitório (com as pendências), o Dormitório vazio, o trem com a Dora, o Plano, a Cantina, o Depósito, o Bar e as
## Opções (e as Opções roladas até o fim).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_105.gd -- --out=<pasta> [--text-size=2] [--colorblind]
##     [--only=overview,forge,...]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
var only: Array = []
var S
var J


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	S = load("res://scripts/flow/station_rules.gd")
	J = load("res://scripts/flow/journey_rules.gd")
	var colorblind := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--colorblind":
			colorblind = true
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
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
	# A Estação das maquetes: 30 sementes, 9 sucatas, 3 fragmentos, 2 curativos, nada recuperado.
	campaign.new_game(5)
	var c: Dictionary = campaign.state
	c.inventory.seeds = 30
	c.inventory.scrap = 9
	c.inventory.fragments = 3
	c.inventory.bandages = 2
	flow.change_to("station", {}, false)
	await _settle(flow)
	var station = current_scene
	var hud = station.hud
	if _want("overview"):
		hud._key_room = S.CHARACTERS
		hud._last_mouse = root.get_mouse_position()
		await _frames(20)
		await _shot("overview")
		hud._key_room = ""
	for spec in [["preparation", S.PREPARATION], ["forge", S.FORGE], ["research", S.RESEARCH], ["dormitory", S.DORMITORY], ["canteen", S.CANTEEN],
			["depot", S.DEPOT], ["bar", S.BAR]]:
		if not _want(spec[0]):
			continue
		hud.open_room(spec[1])
		station.focus_room(spec[1], true)
		await _shot(spec[0])
		hud.close_panel()
	for name in ["plan", "options"]:
		if not _want(name):
			continue
		hud.open_service(name)
		await _shot(name)
		if hud._scroll.get_v_scroll_bar().max_value > hud._scroll.size.y + 4:
			hud._scroll.scroll_vertical = int(hud._scroll.get_v_scroll_bar().max_value)
			await _shot(name + "_scrolled")
		hud.close_panel()
	# A noite (com o trem esperando) e o trem com a Dora.
	if _want("night") or _want("train"):
		J.start_expedition(c, "fase_1", 77)
		c.session.result = "victory"
		c.session.expedition.loot = {"seeds": 6, "scrap": 3, "fragments": 1}
		c.roster[1].hp = int(c.roster[1].max_hp / 3)
		S.finish_return(c)
		c.station.last_return.seen = true
		if c.station.train.phase == "none":
			c.station.train = {"phase": "waiting", "candidate_id": S.DORA, "expedition_id": "captura", "accepted": false}
		campaign.save()
		flow.change_to("station", {}, false)
		await _settle(flow)
		station = current_scene
		hud = station.hud
		if _want("night"):
			hud.open_room(S.DORMITORY)
			station.focus_room(S.DORMITORY, true)
			await _shot("night")
			hud.close_panel()
		if _want("train"):
			hud._arrived_candidate = c.station.train.candidate_id
			hud.open_service("train")
			for i in 600:
				await process_frame
				if hud._panel.visible and not station.passage_moving():
					break
			await _shot("train")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _want(name: String) -> bool:
	return only.is_empty() or only.has(name)


func _settle(flow) -> void:
	for i in 600:
		await process_frame
		if not flow.busy and current_scene != null and i > 10:
			break
	await _frames(30)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(24)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
