## Fotos do briefing e do debriefing (#88): na Estação, a Preparação da fase 1 com a Dora morando lá, o Partir e as
## falas do briefing (a Dora, a Íris e o Nick); depois a volta com a vitória, a chegada e a fala do debriefing antes do
## relatório. Numa versão sem o briefing, as mesmas fotos mostram a partida e o relatório direto (as de antes).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_briefing.gd -- --out=<pasta> [--phase=fase_1]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var phase := "fase_1"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	var S = load("res://scripts/flow/station_rules.gd")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	var c: Dictionary = campaign.create_initial(88)
	c.station.residents = [S.DORA, S.OTTO, S.CORA]
	for id in ["fase_1", "fase_2", "fase_3", "fase_4"]:
		if id != phase and not c.completed_phases.has(id) and int(id.trim_prefix("fase_")) < int(phase.trim_prefix("fase_")):
			c.completed_phases.append(id)
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	await _settle(flow)
	var hud = current_scene.hud
	var team: Array = c.roster.slice(0, 4).map(func(h): return h.id)
	# A equipe sobe para a plataforma (#123): o briefing abre quando ela chega.
	hud._draft = {"phase": phase, "team": team, "focus": "", "extra": 0}
	hud.open_departure()
	var deadline := Time.get_ticks_msec() + 60000
	while not hud.briefing_open() and Time.get_ticks_msec() < deadline:
		await process_frame
	await _frames(20)
	if hud.briefing_open():
		for i in hud.briefing.lines.size():
			await _shot("01-briefing-%d" % (i + 1))
			if i + 1 < hud.briefing.lines.size():
				hud.briefing.next_button.pressed.emit()
				await _frames(6)
		hud.briefing.next_button.pressed.emit()
	await _frames(10)
	await _shot("00-preparation")
	hud._depart()
	await _settle(flow)
	await _frames(30)
	await _shot("02-street")
	# A volta com a vitória.
	c = campaign.state
	c.session.result = "victory"
	S.finish_return(c)
	campaign.save()
	flow.change_to("station", {}, false)
	await _settle(flow)
	var station = current_scene
	hud = station.hud
	station.finish_team_arrival()
	for i in 900:
		if (hud.get("briefing") != null and hud.briefing_open()) or hud.current == "report":
			break
		await process_frame
	await _frames(20)
	await _shot("03-debriefing")
	if hud.get("briefing") != null and hud.briefing_open():
		hud.briefing.next_button.pressed.emit()
	for i in 300:
		if hud.current == "report":
			break
		await process_frame
	await _frames(40)
	await _shot("04-report")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _settle(flow) -> void:
	for frame in 900:
		await process_frame
		if not flow.busy and flow.passage == null and current_scene != null and frame > 3:
			break
	await _frames(5)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
