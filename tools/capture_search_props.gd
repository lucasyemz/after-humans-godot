## Prova dos objetos de busca (#50): uma loja de cada tipo e a rua, antes e depois de vasculhar, com a equipe na frente
## do primeiro ponto (o aviso e o losango sobre o objeto).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_search_props.gd -- --out=<pasta>
## Grava street-closed.png, street-open.png e shop<N>-closed.png, shop<N>-open.png. A campanha fica numa pasta dentro de
## <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
var J


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
	J = load("res://scripts/flow/journey_rules.gd")
	var campaign = root.get_node("Campaign")
	campaign.save_dir = out.path_join("save")
	root.get_node("Tips").set("enabled", false)
	campaign.state = campaign.create_initial(5)
	J.start_expedition(campaign.state, "fase_1", 5050)
	campaign.save()
	root.get_node("GameFlow").change_to("street", {}, false)
	await create_timer(2.0).timeout
	var street = current_scene
	var corridor = street.corridor
	var route: Dictionary = campaign.state.session.expedition.corridor
	# A rua: o primeiro trecho de busca, com a equipe ao lado.
	var first := -1
	for index in route.steps.size():
		if route.steps[index].type == "loot":
			first = index
			break
	for i in first:
		route.steps[i].resolved = true
	route.index = first
	street._place_leader(Vector3(corridor.props[first].global_position.x - 0.8, street.floor_y, street.lane_z))
	await _shot("street-closed")
	corridor._search_prop(first)
	await create_timer(1.5).timeout
	await _shot("street-open")
	# As lojas: uma de cada tipo (a casa da rota com aquela loja; sem ela, a primeira fazendo de conta que é).
	for shop in 3:
		var index := 0
		for i in route.sites.size():
			if int(route.sites[i].shop) == shop:
				index = i
				break
		var site: Dictionary = route.sites[index]
		site.shop = shop
		site.locked = false
		site.has_enemy = false
		for spot in site.spots:
			spot.searched = false
		for i in int(site.step):
			route.steps[i].resolved = true
		route.index = maxi(route.index, int(site.step))
		J.enter_house(campaign.state, index)
		corridor._open_room(index)
		var room = corridor.room
		street._place_leader(Vector3(room.spot_xs[0] - 0.8, 0, street.lane_z))
		await _shot("shop%d-closed" % shop)
		corridor._search_spot(index, 0)
		corridor.hud.close_modal()
		await create_timer(1.5).timeout
		await _shot("shop%d-open" % shop)
		J.leave_house(campaign.state)
		corridor._close_room()
		street.set_indoor(false)
		await process_frame
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _shot(name: String) -> void:
	await create_timer(1.0).timeout
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print(name)
