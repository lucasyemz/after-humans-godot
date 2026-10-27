## QA por captura da #140 (a água pintada do Cais e da Ponte das Raízes), pela cena de verdade:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_140.gd -- --out=<pasta>
## Campanha própria na pasta da saída e as opções só na memória. Roda também na main de antes. Para cada mapa: cada zona
## no fim de tarde e na noite com chuva (no Ultra), uma no Baixo, e uma sequência de 4 quadros (0,4 s) mostrando o
## movimento. Grava camera.txt com a distância e a altura da câmera até o líder em cada mapa.
extends SceneTree

const MAPS := [["RiverDock", "fase_2", 0], ["RootBridge", "fase_2", 4]]

var out := ""
var campaign
var flow
var settings
var S
var lines: Array = []


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
	settings = root.get_node("Settings")
	S = load("res://scripts/flow/station_rules.gd")
	root.get_node("Tips").enabled = false
	settings._persist = false
	campaign.save_dir = out.path_join("save")
	for spec in MAPS:
		await _map(spec)
	var file := FileAccess.open(out.path_join("camera.txt"), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	print("capturas da #140 em %s" % out)
	quit(0)


func _map(spec: Array) -> void:
	var c: Dictionary = campaign.create_initial(9)
	c.completed_phases = ["fase_1"]
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
	if street == null or street.scenario == null:
		return
	var corridor = street.corridor
	settings.set_level(3)
	await _wait(1.0)
	var camera: Camera3D = root.get_viewport().get_camera_3d()
	var leader: Vector3 = street._leader.global_position
	lines.append("%s distance=%.2f height=%.2f" % [spec[0], camera.global_position.distance_to(leader), camera.global_position.y - leader.y])
	for zone in street.scenario.zones.size():
		if corridor._side_room_of_zone(zone) >= 0:
			continue
		var segment := -1
		for i in corridor.segments.size():
			if corridor.segments[i].zone == zone:
				segment = i
				break
		if segment < 0:
			continue
		var part: Dictionary = corridor.segments[segment]
		corridor._enter_segment(segment, float(part.x0) + minf(8.0, (float(part.x1) - float(part.x0)) * 0.4))
		for mood in [["golden", false], ["night", true]]:
			street._mood = mood[0]
			street._raining = mood[1]
			street._apply_weather()
			await _wait(1.0)
			await _shot("%s-z%d-%s" % [spec[0], zone, mood[0]])
		if zone == 0:
			street._mood = "golden"
			street._raining = false
			street._apply_weather()
			for i in 4:
				await _wait(0.4)
				await _shot("%s-seq%d" % [spec[0], i])
			settings.set_level(0)
			await _wait(1.0)
			await _shot("%s-z0-low" % spec[0])
			settings.set_level(3)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print(name)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout
