## QA por captura da #175 (os interiores e os cômodos fechados), pela cena de verdade:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_175.gd -- --out=<pasta> [--maps=RiverDock,...] [--shops]
## Campanha própria na pasta da saída e as opções só na memória. Roda também na main de antes.
## - As lojas da Rua (a mercearia, a oficina e o cinema): a sala aberta pelo caminho de verdade (_open_room), com a
##   equipe na entrada, no meio e no fundo, no fim de tarde e de noite.
## - Os cenários: cada zona, com a equipe na ponta esquerda, no meio e na ponta direita, no fim de tarde e de noite.
## O fim de tarde é o que mais mostra o problema (o sol baixo entrando por onde não há parede).
extends SceneTree

const PHASE_OF := {"RiverDock": ["fase_2", 0], "RootBridge": ["fase_2", 4], "SealedShelter": ["fase_3", 0],
	"TriageGate": ["fase_4", 0], "FloodedDepot": ["fase_5", 0], "SewerDucts": ["fase_5", 4]}
const SHOP_NAMES := ["grocery", "workshop", "cinema"]
const MOODS := [["golden", false], ["night", false]]

var out := ""
var campaign
var flow


func _initialize() -> void:
	var maps: Array = PHASE_OF.keys()
	var shops := true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--maps="):
			maps = Array(arg.trim_prefix("--maps=").split(",")).filter(func(m): return m != "")
			shops = OS.get_cmdline_user_args().has("--shops")
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	campaign = root.get_node("Campaign")
	flow = root.get_node("GameFlow")
	root.get_node("Tips").enabled = false
	root.get_node("Settings")._persist = false
	root.get_node("Settings").set_level(3)
	campaign.save_dir = out.path_join("save")
	if shops:
		await _shops()
	for map in maps:
		await _map(map)
	print("capturas da #175 em %s" % out)
	quit(0)


## As três lojas da Rua: acha na rota um sítio com cada arte e abre a sala dele.
func _shops() -> void:
	var c: Dictionary = campaign.create_initial(11)
	load("res://scripts/flow/journey_rules.gd").start_expedition(c, "fase_1", 11)
	campaign.state = c
	campaign.save()
	var street = await _open_street()
	if street == null:
		return
	var corridor = street.corridor
	corridor.busy = true
	var sites: Array = campaign.state.session.expedition.corridor.sites
	for shop in SHOP_NAMES.size():
		var index := -1
		for i in sites.size():
			if int(sites[i].get("shop", -1)) == shop:
				index = i
				break
		if index < 0:
			# Nenhum sítio com essa arte nesta rota: troca a arte de um sítio só para a foto.
			index = shop % sites.size()
			sites[index].shop = shop
		campaign.state.session.expedition.corridor.current_house = index
		corridor._open_room(index)
		var room = corridor.room
		for spot in [["door", room.entrance_x - 2.0], ["middle", room.position.x + room.WIDTH * 0.5], ["end", room.position.x + room.WIDTH - 1.2]]:
			street._place_leader(Vector3(float(spot[1]), 0, -0.5))
			for mood in MOODS:
				await _mood(street, mood)
				await _shot("shop-%s-%s-%s" % [SHOP_NAMES[shop], spot[0], mood[0]])
		corridor._close_room()
	corridor.busy = false


func _map(map: String) -> void:
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
	var street = await _open_street()
	if street == null or street.scenario == null:
		return
	street.corridor.busy = true
	for zone_index in street.scenario.zones.size():
		street.set_scenario_zone(zone_index)
		var zone: Dictionary = street.scenario.zones[zone_index]
		var left := float(zone.x0) + 2.0
		var right := float(zone.x1) - 2.0
		for spot in [["left", left], ["middle", (left + right) * 0.5], ["right", right]]:
			street._place_leader(Vector3(float(spot[1]), street.floor_y, street.lane_z))
			for mood in MOODS:
				await _mood(street, mood)
				await _shot("%s-z%d-%s-%s" % [map, zone_index, spot[0], mood[0]])
	street.corridor.busy = false


func _open_street():
	flow.change_to("street", {}, false)
	for frame in 900:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.name == "Street" and frame > 3:
			await _wait(1.0)
			return current_scene
	return null


func _mood(street, mood: Array) -> void:
	street._mood = mood[0]
	street._raining = mood[1]
	street._wet = 1.0 if mood[1] else 0.0
	street._apply_weather()
	await _wait(0.8)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print(name)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout
