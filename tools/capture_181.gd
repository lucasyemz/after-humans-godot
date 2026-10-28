## Fotos da Sala dos Personagens (#181): o Bento escolhido, o Nick escolhido e a Estação depois de sair (cada um no seu
## cômodo). Roda também no código de antes (a figura grande por cima da tela), para o antes.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_181.gd -- --out=<pasta> [--text-size=2]
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
	var S = load("res://scripts/flow/station_rules.gd")
	campaign.new_game(5)
	flow.change_to("station", {}, false)
	for i in 600:
		await process_frame
		if not flow.busy and current_scene != null and i > 10:
			break
	await _frames(60)
	var station = current_scene
	var hud = station.hud
	hud.open_room(S.CHARACTERS)
	await _frames(90)
	await _shot("room_bento")
	var screen = hud._room_screen
	screen.selected = "hero_gato_nick"
	screen.rebuild()
	await _frames(60)
	await _shot("room_nick")
	hud.close_panel()
	await _frames(90)
	await _shot("after_close")
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
