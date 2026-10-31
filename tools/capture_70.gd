## QA por captura da #70 (o ALVO na altura da pose atual), pela luta de verdade:
##   xvfb-run -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     -s res://tools/capture_70.gd -- --out=<pasta> [--wait=2]
## Roda também na main de antes. Campanha própria na pasta da saída, apagada no fim. A primeira luta da Rua das
## Vitrines (a do test_target_kneel); cada fundador vai, um de cada vez, para o Último Fôlego (ajoelhado), e a mira de
## um aliado aponta para ele: alvo_<herói>.png. Também a mira num inimigo de pé (alvo_inimigo.png), que não muda.
## Grava em pontos.json, para cada foto, o pé e as cabeças de pé e ajoelhada na tela (para recortar).
extends SceneTree

var out := ""
var wait := 2
var points := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--wait="):
			wait = int(arg.trim_prefix("--wait="))
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
	campaign.save_time_on_quit = false
	campaign.save_dir = out.path_join("save")
	var c: Dictionary = campaign.create_initial(6)
	load("res://scripts/flow/journey_rules.gd").start_expedition(c, "fase_1", 4242)
	campaign.state = c
	flow.change_to("street", {}, false)
	for frame in 900:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.name == "Street" and frame > 3:
			break
	var street = current_scene
	street.corridor.debug_next_fight()
	await _frames(10)
	street.corridor._start_fight(c.session.expedition.corridor.index, true)
	var arena = street._arena
	for i in 1500:
		if arena.hud != null and arena.hud.waiting:
			break
		await process_frame
	var hud = arena.hud
	var camera: Camera3D = root.get_viewport().get_camera_3d()
	for unit in arena.session.state.player_team:
		if not arena.cards.has(unit.id) or not arena.hero_art(unit.hero_id).get("reactions", {}).has("death"):
			continue
		var hp: int = unit.hp
		unit.hp = 0
		unit.deaths_door = true
		arena.rest_pose(unit)
		hud.refresh()
		hud._show_markers([unit.rank], false, func(_rank): pass, "")
		await process_frame
		hud._select_target(unit.rank)
		var name := "alvo_" + String(unit.hero_id).get_slice("_", 2)
		await _shot(name)
		var card = arena.cards[unit.id]
		points[name] = _points(camera, card)
		hud._clear_markers()
		hud._set_enabled(true)
		unit.hp = hp
		unit.deaths_door = false
		arena.rest_pose(unit)
		hud.refresh()
	# Um inimigo de pé, para conferir que nada muda nele.
	var enemy = arena.session.state.enemy_team.filter(func(u): return u.hp > 0)[0]
	hud._show_markers([enemy.rank], true, func(_rank): pass, "")
	await process_frame
	hud._select_target(enemy.rank)
	await _shot("alvo_inimigo")
	points["alvo_inimigo"] = _points(camera, arena.cards[enemy.id])
	hud._clear_markers()
	var file := FileAccess.open(out.path_join("pontos.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(points, "\t"))
	file.close()
	var dir := ProjectSettings.globalize_path(out.path_join("save"))
	if DirAccess.dir_exists_absolute(dir):
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))
		DirAccess.remove_absolute(dir)
	quit(0)


func _points(camera: Camera3D, card) -> Dictionary:
	var feet := camera.unproject_position(card.global_position)
	var head := camera.unproject_position(card.global_position + Vector3(0, card.body_height, 0))
	return {"feet": [feet.x, feet.y], "standing_head": [head.x, head.y]}


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(wait)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
