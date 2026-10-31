## Fotos da Estação em grade, parte 1 (#272): a vista geral da campanha nova depois da primeira volta (os marcadores
## dos cômodos soterrados), o painel do Depósito com material de sobra (o motivo da vaga e a escolha do bloco a escavar)
## e o relatório da volta com a linha da escavação. No código de antes (sem a grade), a mesma campanha.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_272_grid.gd -- --out=<pasta>
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
var _log_file: FileAccess


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
	# Aqui (sem GPU) a Estação desenha devagar: o passo a passo vai para log.txt, para acompanhar.
	_log_file = FileAccess.open(out.path_join("log.txt"), FileAccess.WRITE)
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	var S = load("res://scripts/flow/station_rules.gd")
	var c: Dictionary = campaign.create_initial(272)
	# A primeira volta: a comunidade escava o primeiro ponto (no código de antes, nada).
	load("res://scripts/flow/journey_rules.gd").start_expedition(c, "fase_1", 272)
	c.session.result = "victory"
	S.finish_return(c)
	S.resolve_night(c)
	S.finish_dawn(c)
	c.station.train = S._train_defaults()
	c.inventory.scrap = 20
	c.inventory.fragments = 5
	# O relatório abre direto, sem a chegada do trem (que aqui levaria muitos minutos).
	c.station.last_return.seen = true
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	while flow.busy or current_scene == null or current_scene.get("hud") == null:
		await process_frame
	_log("a Estação abriu")
	var station = current_scene
	var hud = station.hud
	await _frames(2)
	hud.open_service("report")
	await _snap(station)
	await _frames(2)
	await _shot("report")
	hud.close_panel()
	station.focus_overview(true)
	await _snap(station)
	await _frames(2)
	await _shot("overview")
	hud.open_room(S.DEPOT)
	await _snap(station)
	await _frames(2)
	await _shot("depot")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


## A câmera direto no destino, sem o deslize (aqui cada quadro leva segundos).
func _snap(station) -> void:
	station._path.clear()
	station._set_goal(station._goal, true)
	await _frames(1)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	_log("foto " + name)


func _log(text: String) -> void:
	_log_file.store_line("%d ms: %s" % [Time.get_ticks_msec(), text])
	_log_file.flush()
