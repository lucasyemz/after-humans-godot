## Gravação curta de um golpe (#33): a equipe contra dois robôs na rua, a luta com semente fixa, e o primeiro herói usa a
## primeira habilidade com alvo. Grava um PNG por quadro, do comando até a vez seguinte (ou 3 s), para comparar o
## impacto antes e depois. Rode com --fixed-fps para os quadros terem o mesmo passo de tempo em qualquer máquina:
##   "$GODOT" --path . --resolution 960x540 --fixed-fps 30 -s res://tools/capture_impact.gd -- --out=<pasta> [--speed=2]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

const ENEMIES := ["robot", "robot"]
const MAX_FRAMES := 90

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var battle_speed := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--speed="):
			battle_speed = int(arg.trim_prefix("--speed="))
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
	c.settings.battle_speed = battle_speed
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
	arena.start(heroes, street._heroes, ENEMIES, cards, street._leader.position.x + 3.0, true, 7)
	for i in 900:
		if arena.hud != null and arena.hud.waiting:
			break
		await process_frame
	for i in 20:
		await process_frame
	var actor = arena.session.current_actor()
	var command := {}
	for option in arena.session.ability_options(actor.id):
		if option.usable and not option.self and option.enemy_side:
			command = {"kind": "ability", "ability_id": option.id, "rank": option.targets[0]}
			break
	print("golpe: %s usa %s" % [actor.display_name, command])
	arena.hud.command_chosen.emit(command)
	for frame in MAX_FRAMES:
		await process_frame
		root.get_texture().get_image().save_png(out.path_join("frame-%03d.png" % frame))
		if frame > 5 and arena.hud.waiting:
			break
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit()
