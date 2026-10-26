## A tela do título como o jogo mostra hoje (gl_compatibility), com e sem a logo, para as propostas do lote C
## (docs/design/hud-logo.md) entrarem no lugar dela. Paisagem 1920x1080 (o retrato
## não abre no xvfb: a janela fica em 1080x607):
##   xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     -s res://docs/design/hud-logo/capture.gd -- --out=<pasta>
## Nada de scripts/, data/ ou tests/ muda; o save do jogador fica intacto (a campanha não é tocada).
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var flow = root.get_node("GameFlow")
	var campaign = root.get_node("Campaign")
	# Sem save: o título sem "Continuar", como na primeira vez (o save do jogador fica de fora).
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	flow.change_to("title", {}, false)
	for frame in 600:
		await process_frame
		if not flow.busy and current_scene != null and frame > 3:
			break
	await _frames(60)
	var view: Vector2 = root.get_visible_rect().size
	for spec in [["portrait" if view.y > view.x else "landscape"]]:
		await _shot("title_%s" % spec[0])
		var logo: Control = current_scene._logo
		var rect := Rect2(logo.position, logo.size)
		logo.visible = false
		await _frames(4)
		await _shot("title_%s_clean" % spec[0])
		logo.visible = true
		var f := FileAccess.open(out.path_join("title_%s.json" % spec[0]), FileAccess.WRITE)
		f.store_string(JSON.stringify({"logo": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"buttons": [current_scene._buttons.position.x, current_scene._buttons.position.y]}))
		f.close()
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
