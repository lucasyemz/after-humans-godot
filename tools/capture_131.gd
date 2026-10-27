## Fotos da Estação depois de jogar (#131): a fila do relatório na ordem da formação, a fila saindo andando, os
## marcadores dos cômodos por recuperar, a vista geral andada para o lado e um cômodo aproximado.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_131.gd -- --out=<pasta> [--text-size=2] [--colorblind]
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
	# A volta de uma vitória: a formação Bento (1), Véspera (2), Nick (3), Íris (4); a Véspera ferida.
	var c: Dictionary = campaign.create_initial(17)
	var team: Array = ["hero_cao_bento", "hero_coruja_vespera", "hero_gato_nick", "hero_sapo_iris"]
	c.preferred_formation = team.duplicate()
	J.start_expedition(c, "fase_1", 17)
	c.session.expedition.team = team.duplicate()
	c.session.expedition.loot = {"seeds": 6, "scrap": 4, "fragments": 1}
	S.hero(c, "hero_coruja_vespera").hp = int(S.hero(c, "hero_coruja_vespera").max_hp) / 2
	c.session.result = "victory"
	S.finish_return(c)
	# Sem GPU, a chegada do trem anda devagar: o relatório abre direto (a mesma fila da chegada).
	c.station.last_return.seen = true
	c.inventory.scrap = 9
	c.inventory.fragments = 1
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	while flow.busy or current_scene == null:
		await process_frame
	var station = current_scene
	var hud = station.hud
	await _frames(20)
	hud.open_service("report")
	await _until(func(): return hud.current == "report", 600)
	await _frames(40)
	await _shot("report_order")
	hud._enter_shelter_then(Callable())
	# A fila andando: a frente já perto da porta, os outros saindo atrás.
	await _until(func(): return station._leaving.size() >= 1 and station._leaving.size() <= 3, 900)
	await _shot("leaving")
	await _until(func(): return hud.current == "" and not station.passage_moving() and not station.lineup_leaving(), 2400)
	# A noite passa e o trem fica para depois: a vista geral de um dia comum, com os marcadores.
	S.resolve_night(c)
	S.finish_dawn(c)
	c.station.train = S._train_defaults()
	station.commit()
	station.focus_overview()
	await _until(func(): return station.camera_settled(), 900)
	await _frames(30)
	await _shot("marks")
	station.set_pan(station.PAN_RANGE.y)
	await _until(func(): return station.camera_settled(), 900)
	await _frames(20)
	await _shot("panned")
	station.set_pan(0.0)
	await _until(func(): return station.camera_settled(), 900)
	hud.open_room(S.CANTEEN)
	await _until(func(): return station.camera_settled(), 900)
	await _frames(30)
	await _shot("room")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


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
