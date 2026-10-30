## Fotos do Mercador (#182, parte 2): o trem chega com o Sr. dos Trilhos (ele oferece a mercadoria ao lado do painel das
## trocas), uma troca feita e esgotada, a Preparação pedindo para dispensá-lo, ele voltando ao vagão de passada e o
## relatório da volta que o trouxe. No código de antes (sem o Mercador), a mesma volta pela barra de Admin traz um animal.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_182_merchant.gd -- --out=<pasta> [--text-size=2] [--colorblind]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var text_size := -1
	var colorblind := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--text-size="):
			text_size = int(arg.trim_prefix("--text-size="))
		elif arg == "--colorblind":
			colorblind = true
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	var settings = root.get_node("Settings")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	if text_size >= 0:
		settings.set_text_size(text_size)
	if colorblind:
		settings.set_colorblind(true)
	var S = load("res://scripts/flow/station_rules.gd")
	var merchant: bool = S.get_script_constant_map().has("MERCHANT")
	var c: Dictionary = campaign.create_initial(218)
	c.station.rooms[S.CHARACTERS] = 2
	c.inventory.seeds = 30
	c.inventory.scrap = 5
	c.inventory.fragments = 2
	S.train_on_return(c, "capture-merchant", "merchant" if merchant else "hero")
	c.station.last_return = {}
	# A cena do trem em 2x (a velocidade da luta nas Opções): a mesma chegada, em metade do tempo.
	if typeof(c.get("settings")) != TYPE_DICTIONARY:
		c.settings = {}
	c.settings.battle_speed = 2
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	for i in 600:
		await process_frame
		if not flow.busy and current_scene != null and i > 10:
			break
	var station = current_scene
	var hud = station.hud
	# A câmera já na plataforma (sem a passagem secreta): a chegada começa direto.
	station.focus_platform(true)
	await _frames(2)
	hud.open_service("train")
	var end := Time.get_ticks_msec() + 2400000
	while (station.train_busy() or not hud._panel.visible) and Time.get_ticks_msec() < end:
		await process_frame
	await _frames(8)
	await _shot("arrival")
	if merchant:
		var buy = hud._body.find_child("Trade_buy_fragments", true, false)
		var button = buy.find_child("Do", true, false) if buy else null
		if button:
			button.pressed.emit()
		await _frames(6)
		await _shot("traded")
		hud.open_map()
		await _frames(8)
		await _shot("preparation")
		hud.open_service("train")
		end = Time.get_ticks_msec() + 1800000
		while (station.train_busy() or not hud._panel.visible) and Time.get_ticks_msec() < end:
			await process_frame
		await _frames(6)
		hud._dismiss_merchant()
		# A meio caminho do vagão, de passada.
		end = Time.get_ticks_msec() + 1200000
		var start_x: float = station._candidate.position.x if is_instance_valid(station._candidate) else 0.0
		while is_instance_valid(station._candidate) and absf(station._candidate.position.x - start_x) < 1.2 and Time.get_ticks_msec() < end:
			await process_frame
		await _shot("dismissed")
		end = Time.get_ticks_msec() + 1800000
		while campaign.state.station.train.phase != "none" and Time.get_ticks_msec() < end:
			await process_frame
		hud.close_panel()
		await _frames(30)
		# O relatório da volta que trouxe o Mercador.
		var report: Dictionary = {}
		for i in 200:
			var probe: Dictionary = campaign.create_initial(300 + i)
			probe.station.rooms[S.DORMITORY] = 1
			load("res://scripts/flow/journey_rules.gd").start_expedition(probe, "fase_1", 500 + i)
			probe.session.result = "victory"
			report = S.finish_return(probe)
			if report.get("merchant", false):
				campaign.state = probe
				break
		if report.get("merchant", false):
			campaign.save()
			flow.change_to("station", {}, false)
			for i in 600:
				await process_frame
				if not flow.busy and current_scene != null and i > 10:
					break
			current_scene.hud.open_service("report")
			end = Time.get_ticks_msec() + 1200000
			while current_scene.hud.current != "report" and Time.get_ticks_msec() < end:
				await process_frame
			await _frames(10)
			await _shot("report")
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
