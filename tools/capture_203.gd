## Fotos da passagem secreta da plataforma (#203): o que cobre a porta de manutenção, fechado, no meio do movimento e
## aberto, de perto e na vista da plataforma (a câmera parada; a descida com a câmera passando está no doc).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_203.gd -- --out=<pasta>
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
	var c: Dictionary = campaign.create_initial(203)
	c.station.last_return = {}
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	for i in 600:
		await process_frame
		if not flow.busy and current_scene != null and i > 10:
			break
	var station = current_scene
	station.hud.visible = false
	await _frames(30)
	for view in [["near", station.ue_key(2020, 820, 140, 40, -2)], ["platform", station._platform_key()]]:
		station._set_goal(view[1], true)
		for open in [0.0, 0.5, 1.0]:
			station._apply_panel(open)
			await _frames(6)
			await _shot("%s-%03d" % [view[0], roundi(open * 100)])
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
