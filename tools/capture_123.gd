## Fotos da saída em três passos (#123): o Mapa da Rede com o lugar escolhido, a equipe na plataforma sobre as cartas
## (com um caído na lista da Estação) e a confirmação.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_123.gd -- --out=<pasta> [--text-size=2] [--colorblind]
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
	# Cinco no elenco: a formação Bento (1), Véspera (2), Nick (3), Íris (4); um recruta caído na Enfermaria.
	var c: Dictionary = campaign.create_initial(23)
	c.preferred_formation = ["hero_cao_bento", "hero_coruja_vespera", "hero_gato_nick", "hero_sapo_iris"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	c.inventory.seeds = 20
	var recruit: Dictionary = S.recruit(c, "cao", rng)
	if recruit.error == "":
		S.admit_fallen(c, [recruit.hero_id])
	S.hero(c, "hero_coruja_vespera").hp = int(S.hero(c, "hero_coruja_vespera").max_hp) * 2 / 3
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	while flow.busy or current_scene == null:
		await process_frame
	var station = current_scene
	var hud = station.hud
	await _frames(30)
	hud.open_map()
	await _frames(20)
	hud._map._select("fase_1")
	await _frames(20)
	await _shot("map")
	hud._on_phase_chosen("fase_1")
	await _until(func(): return hud.briefing_open() or (station.camera_settled() and not station.passage_moving()), 2400)
	await _frames(20)
	if hud.briefing_open():
		await _shot("briefing")
		var dialog = hud.briefing
		dialog.finished.emit(true)
		dialog.queue_free()
		await _frames(10)
	await _frames(30)
	await _shot("platform")
	hud._departure.pick(0)
	await _frames(20)
	await _shot("swap")
	hud._departure.pick(0)
	hud._departure.open_confirm()
	await _frames(20)
	await _shot("confirm")
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
