## Fotos do Dormitório sem camas e do Bar com custo (#176): a vista geral com os marcadores, a noite no Dormitório (três
## dormem e um vigia; no chão no nível 1; com os beliches depois da melhoria), o painel do Dormitório e o do Bar. Roda também no código de
## antes (o Dormitório "por recuperar" com os beliches e o Bar "Fechado"), para o antes e depois.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_176.gd -- --out=<pasta> [--text-size=2] [--colorblind]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
var S
var _log_file: FileAccess


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	S = load("res://scripts/flow/station_rules.gd")
	var settings = root.get_node("Settings")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--colorblind":
			settings.set_colorblind(true)
		elif arg.begins_with("--text-size="):
			settings.set_text_size(int(arg.trim_prefix("--text-size=")))
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
	# Uma jornada nova, sem sucata: os marcadores dizem o que falta.
	var c: Dictionary = campaign.create_initial(17)
	c.inventory.scrap = 0
	c.inventory.fragments = 0
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	while flow.busy or current_scene == null or current_scene.get("hud") == null:
		await process_frame
	var station = current_scene
	var hud = station.hud
	_log("a Estação abriu")
	await _frames(2)
	_log("2 quadros")
	station.focus_overview(true)
	_log("vista geral pedida")
	await _snap(station)
	_log("câmera parada")
	await _frames(2)
	await _shot("marks")
	hud.open_room(S.BAR)
	await _snap(station)
	await _frames(2)
	await _shot("bar")
	hud.close_panel()
	# A noite: três deitam no Dormitório e o último da equipe vigia, de pé perto da porta.
	var team: Array = c.roster.slice(0, 4).map(func(h): return h.id)
	c.night.phase = "planning"
	c.night.participants = team
	c.night.watch_hero_id = team[3]
	station.commit()
	hud.open_room(S.DORMITORY)
	await _snap(station)
	await _frames(2)
	await _shot("dormitory_night")
	# Os beliches (a melhoria, só no código novo): a mesma noite com eles.
	if not S.next_level_cost(c, S.DORMITORY).is_empty():
		hud.close_panel()
		c.night.phase = "none"
		c.night.participants = []
		station.commit()
		hud.open_room(S.DORMITORY)
		await _snap(station)
		await _frames(2)
		await _shot("dormitory_panel")
		c.inventory.scrap = 3
		S.upgrade_room(c, S.DORMITORY, 1)
		c.night.phase = "planning"
		c.night.participants = team
		station.commit()
		hud.close_panel()
		hud.open_room(S.DORMITORY)
		await _snap(station)
		await _frames(2)
		await _shot("dormitory_bunks")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


## Aqui um quadro leva ~30 s: a câmera vai direto ao cômodo aberto, sem o caminho.
func _snap(station) -> void:
	station._path.clear()
	station._set_goal(station._goal, true)
	await _frames(1)


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
	_log("foto: " + name)


func _log(text: String) -> void:
	print(text)
	if _log_file:
		_log_file.store_line("%7.1f s  %s" % [Time.get_ticks_msec() / 1000.0, text])
		_log_file.flush()
