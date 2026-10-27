## Fotos da ficha ao apontar (#89): na rua, a equipe contra um robô e um rastreador, e na vez do jogador o mouse em cima
## do Bento (com um traço e uma relíquia), do robô (sangrando e marcado) e, numa segunda luta, do Porteiro (o guardião);
## depois a Preparação com o mouse num cartão. Numa versão sem a ficha, as mesmas fotos mostram a luta sem ela (as de
## antes).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_sheet.gd -- --out=<pasta> [--big] [--colorblind]
## A campanha e as opções ficam em pastas temporárias; o save do jogador fica intacto (rode com XDG_DATA_HOME de teste).
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var big := false
	var colorblind := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--big":
			big = true
		elif arg == "--colorblind":
			colorblind = true
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	var settings = root.get_node("Settings")
	settings.set_text_size(2 if big else 0)
	settings.set_colorblind(colorblind)
	campaign.save_dir = out.path_join("save")
	root.get_node("Tips").set("enabled", false)
	var S = load("res://scripts/flow/station_rules.gd")
	var c: Dictionary = campaign.create_initial(6)
	var bento: Dictionary = S.hero(c, "hero_cao_bento")
	bento.perks = ["agile"]
	bento.relic_id = "botao_cobre"
	load("res://scripts/flow/journey_rules.gd").start_expedition(c, "fase_1", 4242)
	campaign.state = c
	flow.change_to("street", {}, false)
	for i in 120:
		await process_frame
	var street = current_scene
	street.apply_corridor_weather("sunset")
	street.corridor.busy = true
	for index in street.corridor.guards:
		for card in street.corridor.guards[index].cards:
			card.visible = false
	var heroes: Array = street.party_ids.map(func(id): return campaign.hero(id))
	var arena = street._arena
	await _fight(street, arena, heroes, ["robot", "cao_eco"], false)
	var state = arena.session.state
	state.enemy_team[0].bleed.duration = 2
	state.enemy_team[0].bleed.magnitude = 2
	state.enemy_team[0].mark_duration = 2
	state.player_team[0].tokens.block = 1
	arena.hud.refresh()
	await _point(arena, state.player_team[0].id)
	await _shot("01-hero")
	await _point(arena, state.enemy_team[0].id)
	await _shot("02-enemy")
	await _point(arena, "")
	await _shot("00-none")
	# O guardião: uma luta com o Porteiro.
	arena.hud.close()
	arena.active = false
	for card in arena.cards.values():
		if not street._heroes.has(card):
			card.visible = false
	await _fight(street, arena, heroes, ["porteiro"], true)
	await _point(arena, arena.session.state.enemy_team[0].id)
	await _shot("03-boss")
	# O chefe cheio de estados: a ficha encolhe para caber acima do painel.
	var porteiro = arena.session.state.enemy_team[0]
	porteiro.bleed.duration = 2
	porteiro.bleed.magnitude = 3
	porteiro.blight.duration = 2
	porteiro.blight.magnitude = 2
	porteiro.mark_duration = 2
	porteiro.stun_turns = 1
	porteiro.tokens.vuln = 2
	porteiro.tokens.block = 1
	arena.hud.refresh()
	await _point(arena, "")
	await _point(arena, porteiro.id)
	await _shot("05-boss-states")
	# Examinar pelo teclado: a ficha de quem age, e a seta passa ao lado.
	await _point(arena, "")
	load("res://scripts/ui/ui_style.gd").using_keys = true
	for action in ["combat_examine", "ui_left"]:
		for pressed in [true, false]:
			var event := InputEventAction.new()
			event.action = action
			event.pressed = pressed
			root.push_input(event)
			await process_frame
	await _frames(6)
	await _shot("06-examine")
	# A Preparação.
	arena.hud.close()
	campaign.state = campaign.create_initial(89)
	S.hero(campaign.state, "hero_cao_bento").perks = ["agile"]
	S.hero(campaign.state, "hero_cao_bento").relic_id = "botao_cobre"
	campaign.save()
	flow.change_to("station", {}, false)
	for frame in 900:
		await process_frame
		if not flow.busy and flow.passage == null and current_scene != null and current_scene.name == "Station" and frame > 3:
			break
	await _frames(20)
	var hud = current_scene.hud
	hud.open_departure()
	hud._briefed = hud._draft.phase
	await _frames(20)
	var cards: Array = hud._departure.find_children("Slot*", "Button", true, false)
	if not cards.is_empty():
		var motion := InputEventMouseMotion.new()
		motion.position = cards.back().get_global_rect().get_center()
		motion.global_position = motion.position
		root.push_input(motion, true)
	await _frames(5)
	await _shot("04-preparation")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _fight(street, arena, heroes: Array, enemies: Array, boss: bool) -> void:
	var cards: Array = []
	for id in enemies:
		cards.append(street.corridor._enemy_card(id))
	street.begin_fight()
	arena.set("boss_fight", boss)
	arena.start(heroes, street._heroes, enemies, cards, street._leader.position.x + 3.0, true, 7)
	for i in 900:
		if arena.hud != null and arena.hud.waiting:
			break
		await process_frame
	await _frames(30)


## O mouse no corpo de quem (unit_id; "" tira o mouse de todos).
func _point(arena, unit_id: String) -> void:
	var camera = arena.get_viewport().get_camera_3d()
	var point := Vector2(960, 60)
	if unit_id != "":
		point = arena.hud._body_rect(camera, arena.cards[unit_id]).get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await _frames(6)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
