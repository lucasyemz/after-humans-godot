## Fotos da vista de fora na saída do trem (#217): a plataforma, com a mesma câmera, nas quatro horas do dia da Estação
## (o amanhecer, o dia, o fim de tarde e a noite), e a vista geral de dia.
##   xvfb-run -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     -s res://tools/capture_217_outside.gd -- --out=<pasta>
## Roda também no código de antes (sem a vista): as mesmas câmeras, para a comparação.
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

## As horas e o estado da noite que leva a cada uma (a cena da noite liga AHStation.night_scene).
const HOURS := [["dawn", "dawn", false], ["day", "none", false], ["dusk", "planning", false], ["night", "planning", true]]

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
	var c: Dictionary = campaign.create_initial(217)
	c.station.cycle_number = 1
	c.station.last_return = {}
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	while flow.busy or current_scene == null or current_scene.get("hud") == null:
		await process_frame
	var station = current_scene
	station.hud.visible = false
	var life = station.get("life")
	if life != null:
		life.auto = false
	await _frames(30)
	station._set_goal(station._overview_key(), true)
	await _frames(6)
	await _shot("overview")
	for hour in HOURS:
		campaign.state.night.phase = hour[1]
		station.set_night_scene(hour[2])
		station.set_night_dim(0.15 if hour[2] else 1.0)
		if station.has_method("refresh_outside"):
			station.refresh_outside(true)
		for view in [["platform", station._platform_key()], ["exit", _exit_key(station)]]:
			station._set_goal(view[1], true)
			await _frames(6)
			await _shot("%s-%s" % [view[0], hour[0]])
	station.set_night_scene(false)
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


## De perto, a ponta da plataforma onde o trem sai (a mesma câmera antes e depois).
func _exit_key(station) -> Dictionary:
	return station.ue_key(420, 1500, 200, 50, -3)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
