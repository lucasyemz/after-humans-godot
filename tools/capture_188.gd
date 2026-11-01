## Fotos do resgate (#188), pelas cenas de verdade:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_188.gd -- --out=<pasta> [--text-size=2]
## A Véspera capturada numa missão solo e um pedido de ajuda, os dois na fase 2: board (os pinos vermelhos e a lista),
## rescue (o painel do resgate); na rota da fase 2, near (o preso guardado ou ao alcance, com o aviso), choice (a
## escolha depois de soltar), swap (a equipe cheia: quem dá o lugar) e joined (a Véspera de volta na fila).
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var text_size := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
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
	var settings = root.get_node("Settings")
	var S = load("res://scripts/flow/station_rules.gd")
	var J = load("res://scripts/flow/journey_rules.gd")
	var M = load("res://scripts/flow/side_mission_rules.gd")
	var Rescue = load("res://scripts/flow/rescue_rules.gd")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	settings._persist = false
	settings.set_text_size(text_size)
	root.get_node("Tips").set("enabled", false)
	var c: Dictionary = campaign.create_initial(23)
	c.completed_phases = ["fase_1"]
	c.station.rooms[S.PREPARATION] = 2
	S.adjust(c, S.SUPPLIES, 8)
	M.state(c).seed = 7
	var vespera: Dictionary = c.roster.filter(func(h): return h.class_id == "coruja")[0]
	vespera.captured = {"mission": "cisterna_turva", "spot": 2, "phase": "fase_2", "day": 0}
	# O pedido de ajuda: o primeiro dia em que o rádio capta um, posto na fase 2.
	for day in 200:
		c.station.cycle_number = day
		Rescue.on_new_day(c)
		if not Rescue.help(c).is_empty():
			break
	M.state(c).help.phase = "fase_2"
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	await _settle(flow)
	var map = current_scene.hud._map
	map.open("")
	map.show_tab("missions")
	await _frames(8)
	await _shot("board")
	map.pick_mission("rescue:0")
	await _frames(8)
	await _shot("rescue")
	map.visible = false
	# A expedição à fase 2 com a equipe cheia (a Véspera fora, um recruta no lugar): o preso no trecho de Suprimentos.
	S._add_hero(c, S._next_hero_id(c, "gato"), "gato", "Sereno", [], S.pick_art_variant(c, "gato"))
	J.start_expedition(c, "fase_2", 4242)
	var expedition: Dictionary = c.session.expedition
	for entry in c.roster:
		if expedition.team.size() < int(J.team_limits("fase_2").max) and not expedition.team.has(entry.id) and not M.away(entry):
			expedition.team.append(entry.id)
	var route: Dictionary = expedition.corridor
	var step := int(Rescue.current(c).step)
	for index in step:
		route.steps[index].resolved = true
	route.index = step
	campaign.save()
	flow.change_to("street", {}, false)
	await _settle(flow)
	var street = current_scene
	var corridor = street.corridor
	for i in 60:
		if corridor.prisoner != null:
			break
		await process_frame
	if corridor.prisoner == null:
		push_error("O preso não apareceu no trecho %d." % step)
		quit(1)
		return
	street._place_leader(corridor.prisoner.position - Vector3(0.8, 0, 0))
	await _frames(30)
	await _shot("near")
	corridor._free_prisoner()
	await _frames(10)
	await _shot("choice")
	corridor.hud.close_modal()
	corridor._rescue_pick("join")
	await _frames(10)
	await _shot("swap")
	corridor.hud.close_modal()
	var out_id: String = Rescue.can_leave_team(c)[0]
	corridor._rescue_join(out_id)
	await _frames(40)
	await _shot("joined")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	print("capturas da #188 em %s" % out)
	quit(0)


func _settle(flow) -> void:
	await _frames(10)
	while flow.busy:
		await process_frame
	await _frames(30)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
