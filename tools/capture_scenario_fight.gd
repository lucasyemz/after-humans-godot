## Fotos de uma luta em cada cenário com os inimigos baixos (#48): a equipe contra Broto, Faísca e Pipoco, na zona da
## patrulha. Mede na tela onde fica o pé de cada um e se o cenário cobre algum deles (as peças opacas entre a câmera e o pé).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_scenario_fight.gd -- --out=<pasta> [--maps=FloodedDepot,...]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto. Sai com 1 se algum pé ficar coberto.
extends SceneTree

const PHASE_OF := {"RiverDock": ["fase_2", 0], "RootBridge": ["fase_2", 4], "SealedShelter": ["fase_3", 0],
	"TriageGate": ["fase_4", 0], "FloodedDepot": ["fase_5", 0], "SewerDucts": ["fase_5", 4]}
const ENEMIES := ["broto", "faisca", "pipoco", "broto"]

var out := ""
var failures := 0
var lines: Array[String] = []


func _initialize() -> void:
	var maps: Array = ["FloodedDepot", "SewerDucts"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--maps="):
			maps = Array(arg.trim_prefix("--maps=").split(","))
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	campaign.save_dir = out.path_join("save")
	root.get_node("Tips").set("enabled", false)
	for map in maps:
		await _fight(campaign, map)
	FileAccess.open(out.path_join("feet.txt"), FileAccess.WRITE).store_string("\n".join(lines) + "\n")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(1 if failures > 0 else 0)


func _fight(campaign, map: String) -> void:
	var spec: Array = PHASE_OF[map]
	var c: Dictionary = campaign.create_initial(7)
	c.completed_phases = ["fase_1", "fase_2", "fase_3", "fase_4"]
	load("res://scripts/flow/station_rules.gd").confirm_departure(c, c.preferred_formation.duplicate(), 0, 20261021, spec[0], "")
	var route: Dictionary = c.session.expedition.corridor
	for i in int(spec[1]):
		route.steps[i].resolved = true
	route.index = int(spec[1])
	campaign.state = c
	campaign.save()
	root.get_node("GameFlow").change_to("street", {}, false)
	await create_timer(2.0).timeout
	var street = root.get_children().filter(func(n): return n.name == "Street")[0]
	street.corridor.debug_next_fight()
	await create_timer(0.5).timeout
	street.corridor.busy = true
	# A patrulha do trecho some; no lugar dela, os baixinhos.
	for index in street.corridor.guards:
		for card in street.corridor.guards[index].cards:
			card.visible = false
		street.corridor.guards[index].mark.visible = false
	var cards: Array = []
	for id in ENEMIES:
		cards.append(street.corridor._enemy_card(id))
	var heroes: Array = street.party_ids.map(func(id): return campaign.hero(id))
	street.begin_fight()
	street._arena.speed = 0.0001
	street._arena.start(heroes, street._heroes, ENEMIES, cards, street._leader.position.x + 3.5)
	for i in 900:
		if street._arena.hud != null and street._arena.hud.waiting:
			break
		await process_frame
	for i in 30:
		await process_frame
	for mood in [["golden", false], ["night", true]]:
		street._mood = mood[0]
		street._raining = mood[1]
		street._wet = 1.0 if mood[1] else 0.0
		street._apply_weather()
		await create_timer(3.0).timeout
		root.get_viewport().get_texture().get_image().save_png(out.path_join("fight-%s-%s.png" % [map, mood[0]]))
	_measure(map, street)


## O pé de cada um na tela e se uma peça do cenário fica entre a câmera e ele (o segmento até 3 cm acima do pé).
func _measure(map: String, street) -> void:
	var camera: Camera3D = root.get_viewport().get_camera_3d()
	for unit in street._arena.session.units():
		var card: Node3D = street._arena.cards[unit.id]
		var foot: Vector3 = card.global_position + Vector3(0, 0.03, 0)
		var screen := camera.unproject_position(foot)
		var cover := AABB()
		for box: AABB in street.scenario.walls:
			if box.intersects_segment(camera.global_position, foot):
				cover = box
				break
		var covered := cover.size != Vector3.ZERO
		if covered:
			failures += 1
		var line := "%s %s %s foot=(%.0f, %.0f) y=%.2f z=%.2f lift=%.2f %s" % [map, unit.id, "COVERED" if covered else "ok", screen.x, screen.y,
			foot.y, foot.z, street.combat_lift, str(cover) if covered else ""]
		lines.append(line)
		print(line)
