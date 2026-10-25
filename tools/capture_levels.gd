## Fotos do nível dos heróis (#90): o Alojamento com o XP de cada um (o Bento pronto para treinar, o Nick no meio do
## caminho, a Íris já no nível 4), a escolha da melhoria do Treino e o Bento no nível novo; depois o relatório da volta
## com o XP de cada um. Numa versão sem o nível, as mesmas fotos mostram o Alojamento e o relatório de antes.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_levels.gd -- --out=<pasta>
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
	campaign.save_dir = out.path_join("save")
	root.get_node("Tips").set("enabled", false)
	var c: Dictionary = campaign.create_initial(90)
	var bento: Dictionary = S.hero(c, "hero_cao_bento")
	# Na versão sem o nível, os campos não existem e não mudam nada (a vida da Íris fica a de sempre).
	var leveled := bento.has("level")
	bento["xp"] = 64
	S.hero(c, "hero_gato_nick")["xp"] = 33
	var iris: Dictionary = S.hero(c, "hero_sapo_iris")
	iris["level"] = 4
	iris["xp"] = 22
	iris["upgrades"] = ["vida", "calma", "vida"]
	if leveled:
		iris.max_hp = int(iris.max_hp) + 4
		iris.hp = iris.max_hp
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	await _settle(flow)
	var hud = current_scene.hud
	hud.open_room(S.CHARACTERS)
	await _frames(20)
	await _shot("01-lodging")
	var train = _button(hud, "Treinar")
	if train != null:
		train.pressed.emit()
		await _frames(10)
		await _shot("02-choice")
		var choice = _button(hud, "Mais fôlego")
		if choice != null:
			choice.pressed.emit()
			await _frames(20)
			await _shot("03-trained")
	# O relatório da volta com o XP.
	hud.close_panel()
	c = campaign.state
	load("res://scripts/flow/journey_rules.gd").start_expedition(c, "fase_1", 90)
	c.session.expedition.stats = {"hero_cao_bento": {"damage": 41, "healing": 0, "downs": 3, "xp": 62}, "hero_sapo_iris": {"damage": 12, "healing": 18, "downs": 0, "xp": 51}}
	c.session.result = "victory"
	S.finish_return(c)
	campaign.save()
	flow.change_to("station", {}, false)
	await _settle(flow)
	var station = current_scene
	station.finish_team_arrival()
	# O debriefing (#88) vem antes do relatório: a captura passa por ele como o jogador.
	for i in 900:
		if station.hud.current == "report":
			break
		var skip = _button(station.hud, "Ver o relatório")
		if skip == null:
			skip = _button(station.hud, "Pular")
		if skip != null:
			skip.pressed.emit()
		await process_frame
	await _frames(40)
	await _shot("04-report")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _button(root_node: Node, prefix: String):
	for button in root_node.find_children("*", "Button", true, false):
		if not button.is_queued_for_deletion() and button.is_visible_in_tree() and button.text.begins_with(prefix):
			return button
	return null


func _settle(flow) -> void:
	for frame in 900:
		await process_frame
		if not flow.busy and flow.passage == null and current_scene != null and frame > 3:
			break
	await _frames(10)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
