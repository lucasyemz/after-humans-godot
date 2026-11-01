## Fotos do Último Fôlego (#281): a luta da Rua das Vitrines com a equipe toda no Último Fôlego (de pé e piscando em
## vermelho, no pulso mais forte e no mais fraco) e o primeiro derrotado de vez. Roda também no código de antes (todos
## caídos, sem pulso), para o antes.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_281.gd -- --out=<pasta>
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
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
	var J = load("res://scripts/flow/journey_rules.gd")
	campaign.state = campaign.create_initial(6)
	J.start_expedition(campaign.state, "fase_1", 1)
	var route: Dictionary = campaign.state.session.expedition.corridor
	var step := 7
	for i in step:
		route.steps[i].resolved = true
	route.index = step - 1
	flow.change_to("street", {}, false)
	var street = null
	for frame in 600:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.name == "Street" and frame > 3:
			street = current_scene
			break
	for k in 4:
		street.corridor.debug_next_fight()
		await _frames(20)
		if street.corridor.guards.has(route.index) and route.index == step:
			break
	street.corridor._start_fight(route.index, true)
	var hud = street._arena.hud
	for i in 1500:
		if hud != null and hud.waiting:
			break
		await process_frame
	var state = hud.session.state
	var arena = street._arena
	# Os dois fundadores da frente e o último (o recruta) no Último Fôlego; a câmera perto do primeiro.
	var heroes: Array = state.player_team
	for hero in heroes:
		hero.hp = 0
		hero.deaths_door = true
		arena.rest_pose(hero)
	hud.refresh()
	await _frames(30)
	var card = arena.cards[heroes[0].id]
	# O pulso no mais claro e no mais fraco (no código de antes, sem pulso, as duas fotos são iguais).
	await _at_phase(card, 0.5)
	await _shot("pulso_alto")
	await _at_phase(card, 0.0)
	await _shot("pulso_baixo")
	# Derrotado de vez depois do Último Fôlego: cai e fica cinza.
	heroes[0].deaths_door = false
	arena.rest_pose(heroes[0])
	hud.refresh()
	await _frames(20)
	await _at_phase(arena.cards[heroes[1].id], 0.5)
	await _shot("derrotado")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


## Espera o pulso chegar na fração do ciclo (0: o mais fraco, 0,5: o mais forte); sem pulso, só uns quadros.
func _at_phase(card, phase: float) -> void:
	if not card.has_method("in_danger") or not card.in_danger():
		await _frames(10)
		return
	for i in 600:
		var at: float = card._danger_time / card.DANGER_PERIOD
		if absf(at - phase) < 0.03:
			return
		await process_frame


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
