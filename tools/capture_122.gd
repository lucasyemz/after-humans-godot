## Fotos do recrutamento pelo trem (#122): o animal esperando na plataforma com a carta dele, o relatório da volta com
## alguém no trem e o da volta vazia, e a Sala sem o + RECRUTAR.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_122.gd -- --out=<pasta> [--text-size=2] [--colorblind]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
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
	var base: Dictionary = campaign.create_initial(122)
	base.inventory.seeds = 24
	# As duas voltas: uma com um animal no trem e uma vazia (o sorteio sai do id da expedição).
	var with_id := ""
	var empty_id := ""
	for i in 300:
		var probe: Dictionary = base.duplicate(true)
		_return(probe, "cap-%d" % i)
		var arrived: bool = not S.train_recruit(probe).is_empty()
		if arrived and with_id == "":
			with_id = "cap-%d" % i
		elif probe.station.train.phase == "none" and empty_id == "":
			empty_id = "cap-%d" % i
		if with_id != "" and empty_id != "":
			break
	for spec in [[empty_id, "report_empty"], [with_id, "report_train"]]:
		var c: Dictionary = base.duplicate(true)
		_return(c, spec[0])
		campaign.state = c
		campaign.save()
		flow.change_to("station", {}, false)
		while flow.busy or current_scene == null:
			await process_frame
		await _frames(20)
		c.station.last_return.seen = true
		current_scene.hud.open_service("report")
		await _until(func(): return current_scene.hud.current == "report", 600)
		await _frames(40)
		await _shot(spec[1])
	# O animal na plataforma: a chegada do trem e o painel dele.
	var c: Dictionary = base.duplicate(true)
	_return(c, with_id)
	S.resolve_night(c)
	S.finish_dawn(c)
	c.station.last_return.seen = true
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	while flow.busy or current_scene == null:
		await process_frame
	var station = current_scene
	var hud = station.hud
	await _frames(10)
	if hud.current != "train":
		hud.open_service("train")
	var end := Time.get_ticks_msec() + 120000
	while (station.train_busy() or not hud._panel.visible) and Time.get_ticks_msec() < end:
		await process_frame
	await _frames(40)
	await _shot("platform")
	hud.open_room(S.CHARACTERS)
	await _frames(40)
	await _shot("room")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _return(c: Dictionary, expedition_id: String) -> void:
	J.start_expedition(c, "fase_1", 7)
	c.session.expedition.id = expedition_id
	c.session.expedition.loot = {"seeds": 4, "scrap": 3}
	c.session.result = "victory"
	S.finish_return(c)


func _until(condition: Callable, frames: int = 2400) -> void:
	for i in frames:
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
