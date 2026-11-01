## Fotos das duas poses paradas (#221), pela rua e pela luta de verdade:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_221.gd -- --out=<pasta> [--skin]
## street (a fila na rua, na pose de exploração), fight (a vez do jogador na primeira luta da fase 1, na guarda) e after
## (a fila de volta à rua, depois da vitória). Com --skin, o Bento na Ronda. Roda também na main de antes.
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var skin := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--skin":
			skin = true
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	root.get_node("Settings")._persist = false
	root.get_node("Tips").set("enabled", false)
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	var c: Dictionary = campaign.create_initial(6)
	if skin:
		c.roster[0].skin_id = "bento_watch"
	load("res://scripts/flow/journey_rules.gd").start_expedition(c, "fase_1", 4242)
	campaign.state = c
	flow.change_to("street", {}, false)
	for frame in 900:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.name == "Street" and frame > 3:
			break
	var street = current_scene
	await _frames(60)
	await _shot("street")
	street.corridor.debug_next_fight()
	await _frames(10)
	var route: Dictionary = c.session.expedition.corridor
	street.corridor._start_fight(route.index, true)
	var arena = street._arena
	for i in 1500:
		if arena.hud != null and arena.hud.waiting:
			break
		await process_frame
	await _frames(30)
	await _shot("fight")
	for unit in arena.session.state.enemy_team:
		unit.hp = 0
	arena.hud.command_chosen.emit({"kind": "defend"})
	for i in 2400:
		if not arena.active:
			break
		await process_frame
	await _frames(90)
	await _shot("after")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	print("capturas da #221 em %s" % out)
	quit(0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
