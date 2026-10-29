## Fotos da #128: a vez do herói (a intenção das máquinas sem o alvo), a inspeção ligada num herói e numa máquina, os
## efeitos de impacto e de estados no corpo e o popup do fim. Para comparar antes e depois nos três perfis.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_128.gd -- --out=<pasta> [--text-size=2] [--colorblind]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto. Num branch sem a inspeção, as fotos
## dela saem sem o painel.
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var colorblind := false
	var text_size := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--colorblind":
			colorblind = true
		elif arg.begins_with("--text-size="):
			text_size = int(arg.trim_prefix("--text-size="))
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	var J = load("res://scripts/flow/journey_rules.gd")
	var Rewards = load("res://scripts/flow/fight_rewards.gd")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	root.get_node("Settings").set_colorblind(colorblind)
	root.get_node("Settings").set_text_size(text_size)
	campaign.state = campaign.create_initial(6)
	J.start_expedition(campaign.state, "fase_1", 4242)
	flow.change_to("street", {}, false)
	for frame in 600:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.name == "Street" and frame > 10:
			break
	var street = current_scene
	street.apply_corridor_weather("sunset")
	street.corridor.debug_next_fight()
	await _frames(10)
	var route: Dictionary = campaign.state.session.expedition.corridor
	street.corridor._start_fight(route.index, true)
	var arena = street._arena
	var hud = arena.hud
	for i in 900:
		if hud != null and hud.waiting:
			break
		await process_frame
	await _frames(30)
	await _shot("1-turn")
	var session = hud.session
	var enemy = session.state.enemy_team[0]
	var hero = session.state.player_team[0]
	# O mouse em cima de uma máquina: o nome numa plaqueta e a luz leve (sem a ficha).
	if "_hover_label" in hud:
		hud._mouse = hud._body_rect(street.get_viewport().get_camera_3d(), arena.cards[enemy.id]).get_center()
		await _frames(6)
		await _shot("1b-hover")
		hud._mouse = Vector2(960, 60)
		await _frames(4)
	# A inspeção: quem age, e a máquina escolhida pelo clique.
	if hud.has_method("toggle_inspect"):
		hud.toggle_inspect()
		await _frames(8)
		await _shot("2-inspect-hero")
		hud._examine_index = hud._examine.find(enemy.id)
		hud._paint_examine()
		await _frames(8)
		await _shot("3-inspect-machine")
		hud.stop_examine()
		await _frames(4)
	# Os efeitos no corpo: o acerto no robô e no herói, depois o crítico e a cura, e os estados em loop.
	var E := AHCombat.EventType
	arena.speed = 1.0
	var hit: float = arena.cards[enemy.id].position.x - 1.0
	arena._show_events([_event(E.DAMAGE, enemy.id, 3), _event(E.DAMAGE, hero.id, 2)], hit)
	await _frames(1)
	await _shot("4-vfx-hits")
	await _frames(30)
	var crit := _event(E.CRIT, enemy.id, 0)
	crit.critical_roll = true
	arena._show_events([crit, _event(E.DAMAGE, enemy.id, 5), _event(E.HEAL, hero.id, 3)], hit)
	await _frames(1)
	await _shot("5-vfx-critical-heal")
	await _frames(30)
	enemy.bleed.duration = 2
	enemy.bleed.magnitude = 1
	enemy.mark_duration = 2
	hero.blight.duration = 2
	hero.blight.magnitude = 1
	await _frames(12)
	await _shot("6-vfx-states")
	# O popup do fim (aberto à mão; a captura é lenta, e o mouse em cima segura a contagem para a foto).
	session.state.victory = true
	session.state.is_over = true
	hud.show_result("victory", false, Rewards.criteria(session, false, "fase_1"))
	await _frames(1)
	if "_mouse" in hud:
		hud._mouse = hud._result.get_global_rect().get_center()
	await _frames(20)
	await _shot("7-result")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _event(type: int, target: String, amount: int) -> AHCombat.Event:
	var event := AHCombat.Event.new()
	event.type = type
	event.target_unit_id = target
	event.amount = amount
	event.text = "-%d" % amount
	return event


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
