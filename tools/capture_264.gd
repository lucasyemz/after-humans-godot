## Fotos das peculiaridades (#264, PR 1): a Sala com os traços da Íris (a positiva fixa, Mãos de remendo, com o selo, e
## as sorteadas) e a ficha.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_264.gd -- --out=<pasta> [--text-size=2]
## Roda também antes da #264 (só lê o que a campanha nova sorteia). O save do jogador fica intacto.
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	campaign.save_dir = out.path_join("save-264")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	var S = load("res://scripts/flow/station_rules.gd")
	var c: Dictionary = campaign.create_initial(264)
	c.station.last_return = {}
	campaign.state = c
	campaign.save()
	var flow = root.get_node("GameFlow")
	flow.change_to("station", {}, false)
	await _frames(10)
	while flow.busy:
		await process_frame
	await _frames(20)
	var hud = current_scene.hud
	hud.open_room(S.CHARACTERS)
	await _frames(10)
	var screen = hud._room_screen
	screen.selected = "hero_sapo_iris"
	screen.rebuild()
	await _frames(20)
	var target := screen.find_child("Traits", true, false) as Control
	if target != null:
		var scroll: Node = target.get_parent()
		while scroll != null and not scroll is ScrollContainer:
			scroll = scroll.get_parent()
		if scroll != null:
			(scroll as ScrollContainer).ensure_control_visible(target)
	await _frames(10)
	await _shot("10-traits")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
