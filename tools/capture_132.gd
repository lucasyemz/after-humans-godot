## Fotos da noite e do amanhecer (#132): o Dormitório antes de dormir, a cena da noite (a Estação escura e o cartão) e o
## amanhecer com o resumo, numa noite sem nada e em duas com evento (o vigia vê algo, baratas na despensa). Roda também
## no código de antes (sem a cena e sem os eventos), para o antes.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_132.gd -- --out=<pasta> [--text-size=2] [--colorblind]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
var S


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	S = load("res://scripts/flow/station_rules.gd")
	var events: bool = S.get_script_method_list().any(func(m): return m.name == "night_row")
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
	# A volta da primeira expedição: a equipe dos fundadores no Dormitório, com a Véspera de vigia.
	var c: Dictionary = campaign.create_initial(132)
	c.station.rooms[S.DORMITORY] = 1
	S.confirm_departure(c, c.preferred_formation.duplicate(), 0, 9, "fase_1")
	c.session.expedition.loot = {"seeds": 3, "scrap": 2}
	c.session.result = "victory"
	S.finish_return(c)
	c.station.last_return.seen = true
	S.set_watch(c, "hero_coruja_vespera")
	var planning: Dictionary = c.duplicate(true)
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	while flow.busy or current_scene == null:
		await process_frame
	var station = current_scene
	var hud = station.hud
	await _frames(20)
	hud.open_room(S.DORMITORY)
	await _until(func(): return station.camera_settled(), 900)
	await _frames(30)
	await _shot("dormitory")
	# Iniciar descanso: a cena da noite (antes, o amanhecer abria direto).
	var start: Array = hud._footer.find_children("*", "Button", true, false).filter(func(b): return String(b.text).to_lower().begins_with("iniciar descanso"))
	if not start.is_empty():
		start[0].pressed.emit()
	if events:
		# No meio da noite: a Estação escura, o cartão inteiro e o relógio andando. O xvfb desenha devagar, então a foto
		# para a cena e a leva até o meio, sem depender do relógio.
		await _until(func(): return hud.night_scene_open(), 600)
		hud._night_tween.pause()
		hud._night_tween.custom_step(0.9 + 0.35 + 1.2)
		await _frames(10)
		await _shot("night")
		hud._finish_night()
	await _frames(30)
	await _shot("dawn")
	# O mesmo amanhecer com cada evento escolhido.
	if events:
		for id in ["quiet", "watcher_sees", "pests"]:
			var v: Dictionary = planning.duplicate(true)
			# As baratas sem vigia (com ele, ele as espanta).
			if id == "pests":
				v.night.watch_hero_id = ""
			S.resolve_night(v, id)
			campaign.state = v
			station.commit()
			hud.open_room(S.DORMITORY)
			await _frames(30)
			await _shot("dawn_" + id)
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
