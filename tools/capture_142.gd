## QA por captura da #142 (a marca de interação igual em todos os mapas), pela cena de verdade:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_142.gd -- --out=<pasta>
## Campanha própria na pasta da saída. Roda também na main de antes: a Rua das Vitrines, a casa do acampamento, os seis
## cenários (com os trechos vencidos, para tudo estar ao alcance) e um interior lateral (o do Cais).
extends SceneTree

const MAPS := [["street", "fase_1", 0], ["RiverDock", "fase_2", 0], ["RootBridge", "fase_2", 4], ["SealedShelter", "fase_3", 0],
	["TriageGate", "fase_4", 0], ["FloodedDepot", "fase_5", 0], ["SewerDucts", "fase_5", 4]]

var out := ""
var campaign
var flow
var S


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	campaign = root.get_node("Campaign")
	flow = root.get_node("GameFlow")
	S = load("res://scripts/flow/station_rules.gd")
	root.get_node("Tips").enabled = false
	root.get_node("Settings")._persist = false
	campaign.save_dir = out.path_join("save")
	for i in MAPS.size():
		await _map(i)
	print("capturas da #142 em %s" % out)
	quit(0)


func _map(i: int) -> void:
	var spec: Array = MAPS[i]
	var c: Dictionary = campaign.create_initial(9)
	c.completed_phases = ["fase_1", "fase_2", "fase_3", "fase_4"]
	S.confirm_departure(c, c.preferred_formation.duplicate(), 0, 4242, spec[1], "")
	var route: Dictionary = c.session.expedition.corridor
	for step in route.steps.size() - 1:
		route.steps[step].resolved = true
	route.index = int(spec[2])
	campaign.state = c
	campaign.save()
	flow.change_to("street", {}, false)
	var street = null
	for frame in 900:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.name == "Street" and frame > 3:
			street = current_scene
			break
	if street == null:
		return
	var corridor = street.corridor
	# Um pouco à frente da chegada, com o primeiro objeto da zona perto.
	if street.scenario != null and not corridor.scenario_props.is_empty():
		var first = corridor.scenario_props.filter(func(e): return corridor._side_room_of_zone(e.zone) < 0 and int(e.step) >= route.index)
		if not first.is_empty():
			corridor._enter_segment(corridor._segment_of(int(first[0].step)), float(first[0].x) - 2.5)
	await _wait(1.5)
	await _shot("%02d-%s" % [i + 1, spec[0]])
	if spec[0] == "street":
		var site: int = route.sites.map(func(s): return s.camp_site).find(true)
		if site >= 0:
			route.index = maxi(route.index, int(route.sites[site].step))
			route.sites[site].has_enemy = false
			await corridor._enter_house(site)
			street._place_leader(Vector3(corridor.room.camp_x + 2.5, 0, -0.5))
			await _wait(1.0)
			await _shot("01b-house")
	if spec[0] == "RiverDock" and not corridor.side_rooms.is_empty():
		corridor._show_side_room(0)
		await _wait(1.0)
		await _shot("02b-side-room")


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print(name)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout
