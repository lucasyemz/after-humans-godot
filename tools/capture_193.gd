## Fotos das caras (#193): a faixa da ordem numa luta de quatro máquinas e na fila mais cheia (os retratos repetidos até
## 14), e os moradores na Estação (a Dora na Cantina, o Otto na Oficina e a Dora no trem). Roda também no código de
## antes, para o antes.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_193.gd -- --out=<pasta> [--text-size=2]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
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
	var J = load("res://scripts/flow/journey_rules.gd")
	var S = load("res://scripts/flow/station_rules.gd")
	# A luta de quatro máquinas (a mesma do test_plates_crowd).
	campaign.state = campaign.create_initial(6)
	J.start_expedition(campaign.state, "fase_1", 1)
	var route: Dictionary = campaign.state.session.expedition.corridor
	var step := 7
	for i in step:
		route.steps[i].resolved = true
	route.index = step - 1
	flow.change_to("street", {}, false)
	var street = await _scene(flow, "Street")
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
	await _frames(20)
	await _shot("order")
	# A fila mais cheia: os mesmos retratos repetidos até 14 (mais que uma luta de verdade, que vai a 4 + 6).
	var queue: Array = hud.session.state.initiative_queue
	var extra: Array = queue.duplicate()
	while queue.size() < 14:
		var source = extra[queue.size() % extra.size()]
		var item = source.get_script().new()
		item.unit_id = source.unit_id
		item.is_player = source.is_player
		queue.append(item)
	hud._refresh_order(hud.session.current_actor().id if hud.session.current_actor() else "")
	await _frames(10)
	await _shot("order_crowd")
	# A Estação com os moradores.
	campaign.new_game(5)
	var c: Dictionary = campaign.state
	for who in [S.DORA, S.OTTO]:
		if not c.station.residents.has(who):
			c.station.residents.append(who)
	c.station.rooms[S.CANTEEN] = maxi(1, int(c.station.rooms.get(S.CANTEEN, 0)))
	c.station.rooms[S.FORGE] = maxi(1, int(c.station.rooms.get(S.FORGE, 0)))
	c.station.train = {"phase": "waiting", "candidate_id": "civil_cora", "expedition_id": "captura", "accepted": false}
	campaign.save()
	flow.change_to("station", {}, false)
	var station = await _scene(flow, "")
	var station_hud = station.hud
	for spec in [["canteen", S.CANTEEN], ["forge", S.FORGE]]:
		station_hud.open_room(spec[1])
		station.focus_room(spec[1], true)
		await _frames(30)
		await _shot(spec[0])
		station_hud.close_panel()
	station_hud._arrived_candidate = c.station.train.candidate_id
	station_hud.open_service("train")
	for i in 600:
		await process_frame
		if station_hud._panel.visible and not station.passage_moving():
			break
	await _frames(30)
	await _shot("train")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _scene(flow, name: String):
	for frame in 600:
		await process_frame
		if not flow.busy and current_scene != null and (name == "" or current_scene.name == name) and frame > 10:
			break
	await _frames(30)
	return current_scene


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
