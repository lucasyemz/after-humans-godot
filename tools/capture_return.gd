## Fotos da volta à Estação (#76): a Estação aberta na volta de uma vitória (um herói ferido, um caído) e fotografada
## em cada momento: o trem chegando, a equipe descendo, o relatório; depois Entrar no abrigo e a vista que vem em
## seguida. Com a chegada (#76), espera os estados da cena (sem GPU, o trem anda bem mais devagar que o relógio); numa
## versão anterior, sem ela, fotografa pelo relógio e só aperta botões pelo texto (as fotos de antes).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_return.gd -- --out=<pasta>
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
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
	var flow = root.get_node("GameFlow")
	var S = load("res://scripts/flow/station_rules.gd")
	var J = load("res://scripts/flow/journey_rules.gd")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	var c: Dictionary = campaign.create_initial(17)
	var team: Array = c.roster.slice(0, 4).map(func(h): return h.id)
	J.start_expedition(c, "fase_1", 17)
	c.session.expedition.team = team
	var hurt = S.hero(c, team[1])
	hurt.hp = maxi(1, int(hurt.max_hp) / 3)
	S.hero(c, team[3]).alive = false
	c.session.result = "victory"
	S.finish_return(c)
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	while flow.busy or current_scene == null:
		await process_frame
	var station = current_scene
	var opened := Time.get_ticks_msec()
	if station.has_method("team_arriving"):
		await _until(func(): return station._train_time >= 2.6)
		await _shot("01-train-coming")
		# Quem desce aparece saindo de trás do vagão (a porta é do lado da plataforma).
		await _until(func(): return station.lineup.size() >= 2 and station.lineup.any(func(e): return e.card.position.x > 12.2))
		await _shot("02-team-stepping-out")
		await _until(func(): return station.hud.current == "report")
		await _frames(20)
		await _shot("03-report")
	else:
		for mark in [[1.5, "01-train-coming"], [5.6, "02-team-stepping-out"], [12.0, "03-report"]]:
			while (Time.get_ticks_msec() - opened) / 1000.0 < mark[0]:
				await process_frame
			await _shot(mark[1])
	# Concluir o relatório e ver para onde a volta leva.
	for button in current_scene.find_children("*", "Button", true, false):
		if button.text == TranslationServer.translate("Entrar no abrigo") and button.is_visible_in_tree():
			button.pressed.emit()
			break
	var closed := Time.get_ticks_msec()
	if station.has_method("team_arriving"):
		# A câmera volta da plataforma ao abrigo pela passagem.
		await _until(func(): return station.hud.current == "" and not station.passage_moving() and station.hud._rest_tag.visible)
		await _frames(30)
	else:
		while (Time.get_ticks_msec() - closed) / 1000.0 < 9.0:
			await process_frame
	await _shot("04-after-report")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _until(condition: Callable) -> void:
	for i in 20000:
		if condition.call():
			return
		await process_frame


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
