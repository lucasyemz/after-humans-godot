## Revisão das lutas (#52): uma luta de verdade por zona de cada mapa (a Rua das Vitrines, os seis cenários e uma casa),
## começada pelo corredor como no jogo (a patrulha do trecho, o centro pela posição dela), fotografada na vez do
## jogador. Confere cada posição: dentro da zona (ou da sala), fora dos obstáculos da faixa e dentro da tela.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_fights.gd -- --out=<pasta> [--maps=Street,House,FloodedDepot,...]
## Grava <mapa>-<zona>.png e fights.txt (uma linha por unidade e uma PASS/FAIL por luta); sai com 1 se algo falhar.
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

const MAPS := {"Street": "fase_1", "House": "fase_1", "RiverDock": "fase_2", "RootBridge": "fase_2", "SealedShelter": "fase_3",
	"TriageGate": "fase_4", "FloodedDepot": "fase_5", "SewerDucts": "fase_5"}
## Folga da borda da zona (a mesma do corredor).
const EDGE := 0.4

var out := ""
var lines: Array[String] = []
var failures := 0
var J
var S


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var maps: Array = MAPS.keys()
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
	J = load("res://scripts/flow/journey_rules.gd")
	S = load("res://scripts/flow/station_rules.gd")
	var campaign = root.get_node("Campaign")
	campaign.save_dir = out.path_join("save")
	root.get_node("Tips").set("enabled", false)
	for map in maps:
		if map == "House":
			await _house(campaign)
			continue
		for index in await _combat_steps(campaign, map):
			await _fight(campaign, map, index)
	FileAccess.open(out.path_join("fights.txt"), FileAccess.WRITE).store_string("\n".join(lines) + "\n")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	print("%d lutas com falha" % failures)
	quit(1 if failures > 0 else 0)


## A campanha na fase do mapa, com a rota no primeiro trecho do mapa (os anteriores vencidos).
func _campaign(campaign, map: String) -> Dictionary:
	var phase: String = MAPS[map]
	var c: Dictionary = campaign.create_initial(7)
	c.completed_phases = ["fase_1", "fase_2", "fase_3", "fase_4"].slice(0, ["fase_1", "fase_2", "fase_3", "fase_4", "fase_5"].find(phase))
	S.confirm_departure(c, c.preferred_formation.duplicate(), 0, 20261021, phase, "")
	return c


## Os trechos de luta do mapa, um por zona (o primeiro de cada) e o do chefe.
func _combat_steps(campaign, map: String) -> Array:
	var c := _campaign(campaign, map)
	var route: Dictionary = c.session.expedition.corridor
	var found: Array = []
	var zones := {}
	for index in route.steps.size():
		var step: Dictionary = route.steps[index]
		if step.type != "combat" and step.type != "boss":
			continue
		var on: String = J.map_for_step(c.session.expedition.phase_id, index)
		if (map == "Street" and on != "") or (map != "Street" and on != map):
			continue
		found.append(index)
	# Um por zona: abre o mapa e vê a zona de cada trecho.
	campaign.state = c
	campaign.save()
	root.get_node("GameFlow").change_to("street", {}, false)
	await create_timer(2.0).timeout
	var street = current_scene
	var per_zone: Array = []
	for index in found:
		var zone: int = street.corridor.segments[street.corridor._segment_of(index)].zone if street.scenario else -1
		# O chefe sempre (a fila dele vai até a posição 4 mesmo com três unidades).
		var key := "%d" % zone if map != "Street" else "%d" % index
		if c.session.expedition.corridor.steps[index].type == "boss":
			key = "boss"
		if not zones.has(key):
			zones[key] = true
			per_zone.append(index)
	return per_zone


func _fight(campaign, map: String, index: int) -> void:
	var c := _campaign(campaign, map)
	var route: Dictionary = c.session.expedition.corridor
	for i in index:
		route.steps[i].resolved = true
	route.index = index
	campaign.state = c
	campaign.save()
	root.get_node("GameFlow").change_to("street", {}, false)
	await create_timer(2.0).timeout
	var street = current_scene
	street.corridor.debug_next_fight()
	await create_timer(0.6).timeout
	if not street.corridor.guards.has(index):
		_result("%s-%d" % [map, index], false, "sem patrulha no trecho")
		return
	street.corridor._start_fight(index, true)
	await _wait_turn(street)
	var zone: Dictionary = street.scenario.zones[street.corridor.segments[street.corridor._segment_of(index)].zone] if street.scenario else {}
	var bounds := Vector2(zone.x0, zone.x1) if not zone.is_empty() else Vector2(street.corridor.MIN_X - 4.0, 83.0)
	await _shoot_and_check(street, "%s-%d" % [map, index], bounds, street.scenario.obstacles if street.scenario else [])


## Uma casa da rua com patrulha dentro.
func _house(campaign) -> void:
	# As casas nascem quando a rua abre (assign_search_sites): abre a rua e depois escolhe a casa.
	campaign.state = _campaign(campaign, "House")
	campaign.save()
	root.get_node("GameFlow").change_to("street", {}, false)
	await create_timer(2.0).timeout
	var street = current_scene
	var c: Dictionary = campaign.state
	var route: Dictionary = c.session.expedition.corridor
	if route.sites.is_empty():
		_result("House", false, "a rua não tem casas")
		return
	# A primeira casa, aberta e com patrulha dentro.
	var site_index := 0
	var site: Dictionary = route.sites[site_index]
	site.locked = false
	site.has_enemy = true
	for i in int(site.step):
		route.steps[i].resolved = true
	route.index = int(site.step)
	if not J.enter_house(c, site_index):
		_result("House", false, "não entrou na casa")
		return
	street.corridor._open_room(site_index)
	await create_timer(0.6).timeout
	street.corridor._start_fight(J.HOUSE_ENEMY_INDEX + site_index, true)
	await _wait_turn(street)
	var room = street.corridor.room
	await _shoot_and_check(street, "House-%d" % site_index, Vector2(room.position.x, room.position.x + float(load("res://scripts/world/house_room.gd").WIDTH)), [])


func _wait_turn(street) -> void:
	for i in 900:
		if street._arena.hud != null and street._arena.hud.waiting:
			break
		await process_frame
	for i in 30:
		await process_frame


func _shoot_and_check(street, name: String, bounds: Vector2, obstacles: Array) -> void:
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	var camera: Camera3D = root.get_viewport().get_camera_3d()
	var view := root.get_viewport().get_visible_rect().size
	var bad: Array = []
	var xs: Array = []
	for unit in street._arena.session.units():
		var card: Node3D = street._arena.cards[unit.id]
		var foot: Vector3 = card.global_position
		xs.append(foot.x)
		var inside := foot.x >= bounds.x + EDGE - 0.01 and foot.x <= bounds.y - EDGE + 0.01
		var blocked := false
		for box: AABB in obstacles:
			if box.grow(0.05).has_point(foot + Vector3(0, 0.2, 0)):
				blocked = true
		var screen := camera.unproject_position(foot + Vector3(0, 0.05, 0))
		var visible := not camera.is_position_behind(foot) and screen.x >= 0 and screen.x <= view.x and screen.y >= 0 and screen.y <= view.y
		var line := "%s %s x=%.2f zone=[%.1f, %.1f] inside=%s obstacle=%s screen=(%.0f, %.0f) visible=%s" % [name, unit.id, foot.x, bounds.x, bounds.y,
			inside, blocked, screen.x, screen.y, visible]
		lines.append(line)
		if not inside or blocked or not visible:
			bad.append(unit.display_name)
	xs.sort()
	_result(name, bad.is_empty(), "span=%.2f bad=%s" % [xs[-1] - xs[0], bad])


func _result(name: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	var line := "%s %s %s" % [name, "PASS" if ok else "FAIL", detail]
	lines.append(line)
	print(line)
