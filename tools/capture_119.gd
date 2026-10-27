## Fotos dos limites e dos postos da Estação (#119): a barra com os limites, a Sala com o Posto, a Forja com "Quem
## trabalha aqui" e o relatório com o que os postos renderam. Roda também no código de antes (sem os postos), para o antes.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_119.gd -- --out=<pasta> [--text-size=2] [--colorblind]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
var S
var J


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	S = load("res://scripts/flow/station_rules.gd")
	J = load("res://scripts/flow/journey_rules.gd")
	var posts: bool = S.get_script_method_list().any(func(m): return m.name == "set_post")
	var colorblind := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--colorblind":
			colorblind = true
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	if colorblind:
		root.get_node("Settings").set_colorblind(true)
	# Os fundadores, uma coruja e um cão; a Pesquisa, a Forja e a Enfermaria recuperadas; o Alojamento no nível 2.
	var c: Dictionary = campaign.create_initial(119)
	c.station.rooms[S.CHARACTERS] = 2
	for room in [S.RESEARCH, S.FORGE, S.INFIRMARY]:
		c.station.rooms[room] = 1
	c.inventory.scrap = 6
	c.inventory.fragments = 2
	var sereno: String = S.recruit(c, "coruja", RandomNumberGenerator.new(), "Sereno").hero_id
	var brasa: String = S.recruit(c, "cao", RandomNumberGenerator.new(), "Brasa").hero_id
	var lupa: String = S.recruit(c, "sapo", RandomNumberGenerator.new(), "Lupa").hero_id
	if posts:
		S.set_post(c, sereno, S.RESEARCH)
		S.set_post(c, brasa, S.FORGE)
		S.set_post(c, lupa, S.CANTEEN)
	# A volta com os postos: a equipe dos fundadores parte e volta; quem ficou rende.
	S.confirm_departure(c, c.preferred_formation.duplicate(), 0, 9, "fase_1")
	c.session.expedition.loot = {"seeds": 3, "scrap": 2}
	c.session.result = "victory"
	S.finish_return(c)
	c.station.last_return.seen = true
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	while flow.busy or current_scene == null:
		await process_frame
	var station = current_scene
	var hud = station.hud
	await _frames(20)
	hud.open_service("report")
	await _until(func(): return hud.current == "report", 600)
	await _frames(40)
	await _shot("report")
	S.resolve_night(c)
	S.finish_dawn(c)
	c.station.train = S._train_defaults()
	hud.close_panel()
	station.commit()
	station.focus_overview(true)
	await _frames(40)
	await _shot("overview")
	hud.open_room(S.CHARACTERS)
	await _frames(20)
	hud._room_screen._select(sereno)
	await _frames(40)
	await _shot("room")
	hud.close_panel()
	await _frames(10)
	hud.open_room(S.FORGE)
	await _until(func(): return station.camera_settled(), 900)
	await _frames(30)
	# O painel rola até "Quem trabalha aqui" (no Maior, fica abaixo da dobra).
	var workers_forge = hud._panel.find_child("Workers", true, false)
	if workers_forge != null:
		hud._scroll.ensure_control_visible(workers_forge)
		await _frames(10)
	await _shot("forge")
	# A Cantina tem menos conteúdo: "Quem trabalha aqui" fica à vista também no Maior.
	hud.open_room(S.CANTEEN)
	await _until(func(): return station.camera_settled(), 900)
	await _frames(30)
	# O painel rola até "Quem trabalha aqui" (no Maior, fica abaixo da dobra).
	var workers_canteen = hud._panel.find_child("Workers", true, false)
	if workers_canteen != null:
		hud._scroll.ensure_control_visible(workers_canteen)
		await _frames(10)
	await _shot("canteen")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _until(condition: Callable, frames: int = 2400) -> void:
	for i in frames:
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
