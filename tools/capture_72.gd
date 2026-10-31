## QA por captura da #72 (as placas no lugar mais apertado), pela cena de verdade:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_72.gd -- --out=<pasta>
## (no Linux sem tela: xvfb-run -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 ...)
## Campanha própria na pasta da saída. Roda também na main de antes. A luta cheia do passo 7 da Rua das Vitrines (a do
## test_plates_crowd) com os espaços no mínimo (MIN_GAP_SCALE), nos textos Normal e Maior:
## - tight-*: a câmera presa na distância do espaço normal (o aperto que sobra);
## - tight-mira-*: o mesmo aperto, mirando o segundo inimigo;
## - reframed-*: enquadrada de novo, como no começo de uma luta nesse lugar (a câmera chega mais perto, #72).
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
	var settings = root.get_node("Settings")
	root.get_node("Tips").enabled = false
	settings._persist = false
	campaign.save_dir = out.path_join("save")
	var c: Dictionary = campaign.create_initial(6)
	load("res://scripts/flow/journey_rules.gd").start_expedition(c, "fase_1", 1)
	var route: Dictionary = c.session.expedition.corridor
	for i in 7:
		route.steps[i].resolved = true
	route.index = 6
	campaign.state = c
	flow.change_to("street", {}, false)
	for frame in 900:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.name == "Street" and frame > 3:
			break
	var street = current_scene
	for k in 4:
		street.corridor.debug_next_fight()
		for i in 20:
			await process_frame
		if street.corridor.guards.has(route.index) and route.index == 7:
			break
	street.corridor._start_fight(route.index, true)
	var hud = street._arena.hud
	for i in 1500:
		if hud != null and hud.waiting:
			break
		await process_frame
	var arena = street._arena
	arena.gap_scale = 0.6
	await arena._sync_positions(0.05)
	for size in [0, 2]:
		var label := "maior" if size == 2 else "normal"
		settings.set_text_size(size)
		await _shot("tight-%s" % label)
		var ranks: Array = arena.session.state.enemy_team.filter(func(u): return u.rank > 0).map(func(u): return u.rank)
		ranks.sort()
		hud._show_markers(ranks, true, func(_rank): pass, "")
		await process_frame
		hud._select_target(ranks[1])
		await _shot("tight-mira-%s" % label)
		hud._clear_markers()
		hud._set_enabled(true)
	var far: float = arena.view_distance
	arena._frame_arena()
	print("distância da câmera: %.2f m, antes %.2f m" % [arena.view_distance, far])
	for size in [0, 2]:
		settings.set_text_size(size)
		await _shot("reframed-%s" % ("maior" if size == 2 else "normal"))
	print("capturas da #72 em %s" % out)
	quit(0)


func _shot(name: String) -> void:
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
