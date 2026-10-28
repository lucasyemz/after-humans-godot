## QA por captura da visita guiada da Estação (#145), pela cena de verdade, no Normal, no Maior e no daltonismo:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_station_tour.gd -- --out=<pasta>
## Campanha própria na pasta da saída (o save do jogador fica intacto) e as opções só na memória. Uma foto por passo e
## perfil (<perfil>-<nn>-<passo>.png); cada passo é cumprido do jeito que ele pede (o PRÓXIMO ou a ação).
extends SceneTree

const PROFILES := [["normal", 0, false], ["large", 1, false], ["colorblind", 0, true]]

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
	var settings = root.get_node("Settings")
	var tutorial = load("res://scripts/flow/tutorial_rules.gd")
	settings._persist = false
	campaign.save_dir = out.path_join("save")
	for profile in PROFILES:
		settings.set_text_size(profile[1])
		settings.set_colorblind(profile[2])
		var c: Dictionary = campaign.create_initial(7)
		tutorial.begin(c)
		tutorial.join(c)
		tutorial.complete(c)
		c.station.last_return.seen = true
		campaign.state = c
		campaign.save()
		root.get_node("GameFlow").change_to("station", {}, false)
		await _until(func(): return current_scene != null and current_scene.get("hud") != null and current_scene.hud.tour != null)
		await _wait(1.5)
		var hud = current_scene.hud
		var steps: Array = tutorial.tour_steps()
		for i in steps.size():
			var tour = hud.tour
			if tour == null:
				break
			await _wait(0.8)
			await _shot("%s-%02d-%s" % [profile[0], i + 1, steps[i].Id])
			var wait: String = tour.waiting_for()
			if wait == "next":
				tour.advance()
			else:
				hud.tour_act(wait)
			await _wait(0.6)
	settings.set_text_size(0)
	settings.set_colorblind(false)
	print("visita capturada em %s" % out)
	quit(0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print(name)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _until(condition: Callable, seconds: float = 40.0) -> void:
	var limit := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < limit:
		await process_frame
