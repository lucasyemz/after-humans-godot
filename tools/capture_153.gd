## QA por captura da #153 (a câmera de cinema por lugar), pela cena de verdade:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_153.gd -- --out=<pasta>
## Campanha própria na pasta da saída e as opções só na memória. Roda também na main de antes. A Rua das Vitrines (o
## piloto) no fim de tarde, de noite, na chuva e na noite com chuva, no Ultra; o fim de tarde no Baixo e no Alto; uma
## luta; e o Cais, para ver um mapa com o perfil de partida. Grava frames.txt com o tempo do quadro de cada foto.
extends SceneTree

var out := ""
var campaign
var flow
var settings
var J
var lines: Array = []


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
	campaign = root.get_node("Campaign")
	flow = root.get_node("GameFlow")
	settings = root.get_node("Settings")
	J = load("res://scripts/flow/journey_rules.gd")
	root.get_node("Tips").enabled = false
	settings._persist = false
	campaign.save_dir = out.path_join("save")
	settings.set_level(3)
	var street = await _open("fase_1", 0)
	if street != null:
		for mood in [["golden", false], ["night", false], ["rain", true], ["nightrain", true]]:
			street._mood = "night" if mood[0].begins_with("night") else "golden"
			street._raining = mood[1]
			street._apply_weather()
			await _wait(1.5)
			await _shot("street-%s-ultra" % mood[0])
		street._mood = "golden"
		street._raining = false
		street._apply_weather()
		for level in [[0, "low"], [2, "high"]]:
			settings.set_level(level[0])
			await _wait(1.2)
			await _shot("street-golden-%s" % level[1])
		settings.set_level(3)
		street.corridor.debug_next_fight()
		await _wait(0.5)
		street.corridor._start_fight(campaign.state.session.expedition.corridor.index, true)
		var limit := Time.get_ticks_msec() + 30000
		while (street._arena.hud == null or not street._arena.hud.waiting) and Time.get_ticks_msec() < limit:
			await process_frame
		await _wait(1.0)
		await _shot("street-fight")
	var dock = await _open("fase_2", 0)
	if dock != null:
		await _wait(1.0)
		await _shot("riverdock-golden-ultra")
	var file := FileAccess.open(out.path_join("frames.txt"), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	print("capturas da #153 em %s" % out)
	quit(0)


func _open(phase: String, index: int):
	var c: Dictionary = campaign.create_initial(9)
	c.completed_phases = ["fase_1"]
	J.start_expedition(c, phase, 9)
	var route: Dictionary = c.session.expedition.corridor
	for step in route.steps.size() - 1:
		route.steps[step].resolved = true
	route.index = index
	campaign.state = c
	campaign.save()
	flow.change_to("street", {}, false)
	for frame in 900:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.name == "Street" and frame > 3:
			await _wait(1.0)
			return current_scene
	return null


func _shot(name: String) -> void:
	# O tempo do quadro: a média de 30 quadros antes da foto.
	var start := Time.get_ticks_usec()
	for i in 30:
		await process_frame
	var ms := (Time.get_ticks_usec() - start) / 30000.0
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	lines.append("%s avg_ms=%.1f renderer=%s" % [name, ms, RenderingServer.get_current_rendering_method()])
	print(name)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout
