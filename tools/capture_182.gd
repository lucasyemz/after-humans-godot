## Fotos do trem (#182): a chegada com dois recrutas (os dois na plataforma e as duas abas no painel), a aba do segundo
## escolhida (ele vem à frente) e, decidido ele, o painel do primeiro. No código de antes, o trem traz um só.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_182.gd -- --out=<pasta> [--text-size=2]
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
	var S = load("res://scripts/flow/station_rules.gd")
	# A primeira chegada com dois (a mesma semente no antes, que traz um só).
	var c: Dictionary = {}
	for i in 200:
		c = campaign.create_initial(1900 + i)
		c.station.rooms[S.CHARACTERS] = 4
		c.inventory.seeds = 500
		if S.train_on_return(c, "two-%d" % i, "hero") and not c.station.train.get("next", {}).is_empty():
			break
	c.station.last_return = {}
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	for i in 600:
		await process_frame
		if not flow.busy and current_scene != null and i > 10:
			break
	var station = current_scene
	var hud = station.hud
	hud.open_service("train")
	var end := Time.get_ticks_msec() + 120000
	while (station.train_busy() or not hud._panel.visible) and Time.get_ticks_msec() < end:
		await process_frame
	await _frames(40)
	await _shot("arrival")
	if not c.station.train.get("next", {}).is_empty():
		var second_id: String = c.station.train.next.candidate_id
		var tab = hud._panel.find_child("Pair_%s" % second_id, true, false)
		if tab:
			tab.pressed.emit()
			await _frames(20)
			await _shot("chosen")
		hud._decide(second_id, true)
		await _frames(60)
		await _shot("second")
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
