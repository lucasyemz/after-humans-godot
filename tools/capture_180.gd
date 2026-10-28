## QA por captura da #180 (a casa do guardião na barra de trechos), pela cena de verdade:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_180.gd -- --out=<pasta>
## Campanha própria na pasta da saída. Roda também na main de antes. A Rua no trecho do guardião, antes da luta (em
## alerta) e depois da vitória (os dez trechos concluídos e o "Concluir jornada" na tela).
extends SceneTree

var out := ""


func _initialize() -> void:
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
	var flow = root.get_node("GameFlow")
	root.get_node("Tips").enabled = false
	root.get_node("Settings")._persist = false
	campaign.save_dir = out.path_join("save")
	for won in [false, true]:
		var c: Dictionary = campaign.create_initial(9)
		load("res://scripts/flow/journey_rules.gd").start_expedition(c, "fase_1", 9)
		var route: Dictionary = c.session.expedition.corridor
		for step in route.steps.size() - 1:
			route.steps[step].resolved = true
		route.index = route.steps.size() - 1
		if won:
			route.steps[-1].resolved = true
			c.session.expedition.objective_completed = true
		campaign.state = c
		campaign.save()
		flow.change_to("street", {}, false)
		for frame in 900:
			await process_frame
			if not flow.busy and current_scene != null and current_scene.name == "Street" and frame > 3:
				break
		await create_timer(1.5).timeout
		current_scene.exploration_hud.refresh(campaign.state)
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		var image: Image = root.get_viewport().get_texture().get_image()
		image.save_png(out.path_join("boss-%s.png" % ("won" if won else "ahead")))
		image.get_region(Rect2i(560, 0, 800, 110)).save_png(out.path_join("bar-%s.png" % ("won" if won else "ahead")))
	print("capturas da #180 em %s" % out)
	quit(0)
