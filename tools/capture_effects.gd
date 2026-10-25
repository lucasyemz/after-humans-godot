## Fotos dos efeitos da luta (#84): a equipe contra um robô e um rastreador na rua, a luta com semente fixa e, na vez do
## jogador, cada efeito curto num alvo (o acerto no robô, faíscas, e no Bento, poeira; o crítico, a cura, o bloqueio e a esquiva) e depois os
## estados em loop (sangramento no herói e no robô, veneno, atordoado e marcado). Com --fixed-fps 30, a foto do curto sai
## no mesmo quadro em qualquer máquina (o efeito dura 0,5 s). Numa versão sem os efeitos, as mesmas
## fotos mostram só os números (as fotos de antes).
##   "$GODOT" --path . --resolution 1920x1080 --fixed-fps 30 -s res://tools/capture_effects.gd -- --out=<pasta> [--reduced]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

const ENEMIES := ["robot", "cao_eco"]
const T := preload("res://scripts/combat/combat_types.gd")

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var reduced := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--reduced":
			reduced = true
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	campaign.save_dir = out.path_join("save")
	root.get_node("Tips").set("enabled", false)
	var c: Dictionary = campaign.create_initial(6)
	c.settings.reduced_environment_effects = reduced
	load("res://scripts/flow/journey_rules.gd").start_expedition(c, "fase_1", 4242)
	campaign.state = c
	root.get_node("GameFlow").change_to("street", {}, false)
	for i in 120:
		await process_frame
	var street = current_scene
	street.apply_corridor_weather("sunset")
	street.corridor.busy = true
	for index in street.corridor.guards:
		for card in street.corridor.guards[index].cards:
			card.visible = false
	var cards: Array = []
	for id in ENEMIES:
		cards.append(street.corridor._enemy_card(id))
	var heroes: Array = street.party_ids.map(func(id): return campaign.hero(id))
	street.begin_fight()
	var arena = street._arena
	arena.auto_battle = false
	arena.start(heroes, street._heroes, ENEMIES, cards, street._leader.position.x + 3.0, true, 7)
	for i in 900:
		if arena.hud != null and arena.hud.waiting:
			break
		await process_frame
	await _frames(20)
	var state = arena.session.state
	var robot = state.enemy_team[0]
	var dog = state.enemy_team[1]
	var bento = state.player_team[0]
	var iris = state.player_team[2] if state.player_team.size() > 2 else state.player_team[0]
	var nick = state.player_team[1]
	# Os curtos: no meio da animação (o terceiro quadro de 12 fps: 6 quadros de 30 fps).
	await _shot("01-hit-metal-dust", arena, [_event(T.EventType.DAMAGE, robot.id, 3), _event(T.EventType.DAMAGE, bento.id, 3)])
	await _shot("02-critical-heal", arena, [_event(T.EventType.CRIT, robot.id, 0, true), _event(T.EventType.DAMAGE, robot.id, 6), _event(T.EventType.HEAL, iris.id, 5)])
	await _shot("03-block-dodge", arena, [_event(T.EventType.BLOCK, bento.id, 0), _event(T.EventType.DAMAGE, bento.id, 1), _event(T.EventType.DODGE, nick.id, 0)])
	# Os estados em loop.
	bento.bleed.duration = 2
	bento.bleed.magnitude = 2
	robot.bleed.duration = 2
	robot.bleed.magnitude = 2
	dog.blight.duration = 2
	dog.blight.magnitude = 2
	dog.stun_turns = 1
	dog.mark_duration = 2
	nick.blight.duration = 2
	arena.hud.refresh()
	await _frames(40)
	await _save("04-states")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit()


func _event(type: int, target: String, amount: int, critical := false):
	var event = T.Event.new()
	event.type = type
	event.target_unit_id = target
	event.amount = amount
	event.critical_roll = critical
	event.text = {T.EventType.DAMAGE: "-%d" % amount, T.EventType.HEAL: "+%d" % amount, T.EventType.CRIT: "CRÍTICO!",
		T.EventType.BLOCK: "Bloqueou", T.EventType.DODGE: "Esquivou"}.get(type, "")
	return event


func _shot(name: String, arena, events: Array) -> void:
	arena.auto_battle = true
	# Como num golpe (o contato do lado da equipe): o acerto só toca num golpe.
	arena._show_events(events, arena.center_x)
	await _frames(6)
	await _save(name)
	await _frames(60)


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)


func _frames(count: int) -> void:
	for i in count:
		await process_frame
