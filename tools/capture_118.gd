## Fotos de "ninguém morre" e da Enfermaria (#118, #121): o popup da luta com "Íris caiu", o relatório da volta com as
## cartas caídas, a Enfermaria na Estação com os caídos nos leitos e o painel com "Volta em N dias", a Sala dos
## Personagens e a Preparação com o herói em recuperação.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_118.gd -- --out=<pasta> [--text-size=2] [--colorblind]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
## --only=popup: só as fotos pedidas (as da Estação ou o popup).
var only: PackedStringArray = []
var S
var J


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	S = load("res://scripts/flow/station_rules.gd")
	J = load("res://scripts/flow/journey_rules.gd")
	var colorblind := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--colorblind":
			colorblind = true
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
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
	if not only.is_empty() and not only.has("station"):
		await _popup(campaign, flow)
		quit(0)
		return
	# A volta: a Íris e o Nick caídos, a Enfermaria recuperada (2 leitos).
	var c: Dictionary = campaign.create_initial(17)
	c.station.rooms[S.INFIRMARY] = 1
	var team: Array = c.roster.slice(0, 4).map(func(h): return h.id)
	J.start_expedition(c, "fase_1", 17)
	c.session.expedition.team = team
	c.session.expedition.loot = {"seeds": 6, "scrap": 3, "fragments": 1}
	S.hero(c, team[0]).hp = int(S.hero(c, team[0]).max_hp) / 2
	S.hero(c, "hero_sapo_iris").alive = false
	S.hero(c, "hero_gato_nick").alive = false
	c.session.result = "victory"
	S.finish_return(c)
	# Sem GPU, a chegada do trem anda devagar: o relatório abre direto (o mesmo da chegada).
	c.station.last_return.seen = true
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	while flow.busy or current_scene == null:
		await process_frame
	var station = current_scene
	print("estação")
	await _frames(20)
	station.hud.open_service("report")
	await _until(func(): return station.hud.current == "report", 600)
	await _frames(30)
	await _shot("report")
	station.hud._enter_shelter_then(Callable())
	await _until(func(): return station.hud.current == "" and not station.passage_moving(), 600)
	# A noite passa e o trem fica para depois: a Estação de um dia comum, com os dois na Enfermaria.
	S.resolve_night(c)
	S.finish_dawn(c)
	c.station.train = S._train_defaults()
	station.commit()
	await _frames(10)
	var hud = station.hud
	hud.open_room(S.INFIRMARY)
	station.focus_room(S.INFIRMARY, true)
	await _frames(30)
	await _shot("infirmary")
	hud.close_panel()
	station.focus_clean_overview()
	await _until(func(): return station.camera_settled())
	await _frames(30)
	await _shot("overview")
	hud.open_room(S.CHARACTERS)
	await _frames(20)
	if is_instance_valid(hud._room_screen):
		hud._room_screen.selected = "hero_sapo_iris"
		hud._room_screen.rebuild()
	await _frames(20)
	await _shot("characters")
	hud._close_room_screen()
	await _frames(20)
	hud.open_room(S.PREPARATION)
	await _frames(40)
	await _shot("preparation")
	if only.is_empty() or only.has("popup"):
		await _popup(campaign, flow)
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


## O popup da luta: a Íris cai numa patrulha vencida.
func _popup(campaign, flow) -> void:
	var fresh: Dictionary = campaign.create_initial(6)
	J.start_expedition(fresh, "fase_1", 4242)
	campaign.state = fresh
	flow.change_to("street", {}, false)
	await _frames(10)
	while flow.busy:
		await process_frame
	var street = current_scene
	print("rua")
	street.corridor.debug_next_fight()
	await _frames(10)
	street.corridor._start_fight(fresh.session.expedition.corridor.index, true)
	var fight = street._arena.hud
	for i in 900:
		if fight != null and fight.waiting:
			break
		await process_frame
	await _frames(10)
	# A vitória com a Íris caída de verdade: ela e as máquinas no chão (a pose de queda), as vidas em 0.
	var arena = street._arena
	for unit in fight.session.state.player_team + fight.session.state.enemy_team:
		if unit.hero_id == "hero_sapo_iris" or not unit.is_player:
			unit.hp = 0
			unit.deaths_door = false
			arena.rest_pose(unit)
	fight.refresh()
	await _frames(6)
	fight.show_result("victory", false, {})
	await _frames(12)
	await _shot("popup")
	fight.result_closed.emit()
	await _frames(4)


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
