## Fotos da volta no trem das missões solo (#183, segunda parte), pela Estação de verdade:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_183_train.gd -- --out=<pasta> [--text-size=2]
## O Nick e a Íris voltam das missões no mesmo dia, e o trem de sempre traz um recruta: arrival (o trem das missões, o
## Nick descendo e o painel com o relatório), received (depois de RECEBER, o trem de sempre com o recruta) e station (a
## vista da Estação com os dois de volta).
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
	var M = load("res://scripts/flow/side_mission_rules.gd")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	settings._persist = false
	settings.set_text_size(text_size)
	root.get_node("Tips").set("enabled", false)
	var c: Dictionary = campaign.create_initial(23)
	c.completed_phases = ["fase_1"]
	c.station.rooms[S.PREPARATION] = 2
	var nick: Dictionary = c.roster.filter(func(h): return h.class_id == "gato")[0]
	var iris: Dictionary = c.roster.filter(func(h): return h.class_id == "sapo")[0]
	# Os dois voltaram hoje (o relatório do dia) e chegam no trem; o trem de sempre traz um recruta.
	nick.on_train = true
	iris.on_train = true
	iris.hp = ceili(int(iris.max_hp) * 0.35)
	M.state(c).reports = [
		{"hero_id": nick.id, "mission": "fresta_galerias", "day": 1, "result": "success", "reward": {"kind": "seeds", "amount": 3, "relic_id": ""}, "xp": 10},
		{"hero_id": iris.id, "mission": "cisterna_turva", "day": 1, "result": "hurt", "reward": {"kind": "supplies", "amount": 1, "relic_id": ""}},
	]
	S.train_on_return(c, "exp_capture", "hero")
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	await _settle(flow)
	var hud = current_scene.hud
	var station = current_scene
	hud.open_service("train")
	for i in 900:
		await process_frame
		if not station.train_busy() or i > 600:
			break
	await _frames(60)
	await _shot("arrival")
	hud._mission_train_done()
	for i in 1200:
		await process_frame
		if hud.current == "train" and not M.train_pending(campaign.state) and i > 200 and not station.train_busy():
			break
	await _frames(60)
	await _shot("received")
	hud.close_panel()
	await _frames(90)
	await _shot("station")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	print("capturas do trem das missões em %s" % out)
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
