## QA por captura da #141 (o Armazém e o Navio do Cais em camadas e as portas dos interiores), pela cena de verdade:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_141.gd -- --out=<pasta>
## Campanha própria na pasta da saída. Roda também na main de antes. Para o Armazém e o Navio: a equipe à esquerda e à
## direita da fachada (a profundidade aparece na troca de ângulo), no fim de tarde e na noite, cada um seco e com chuva;
## depois a sequência de entrar e sair de cada interior, com a porta de dentro também na noite com chuva.
extends SceneTree

const FACADES := [["warehouse", 14.0, 2], ["ship", 44.6, 1]]

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
	var c: Dictionary = campaign.create_initial(9)
	c.completed_phases = ["fase_1"]
	S.confirm_departure(c, c.preferred_formation.duplicate(), 0, 4242, "fase_2", "")
	var route: Dictionary = c.session.expedition.corridor
	for step in route.steps.size() - 1:
		route.steps[step].resolved = true
	route.index = 0
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
		quit(1)
		return
	var corridor = street.corridor
	route.index = route.steps.size() - 2
	for facade in FACADES:
		for mood in [["golden", false], ["golden-rain", true], ["night", false], ["night-rain", true]]:
			street._mood = String(mood[0]).trim_suffix("-rain")
			street._raining = mood[1]
			street._apply_weather()
			for side in [["left", -5.0], ["right", 5.0]]:
				corridor._enter_segment(corridor._segment_of(0), float(facade[1]) + float(side[1]))
				await _wait(1.2)
				await _shot("%s-%s-%s" % [facade[0], mood[0], side[0]])
	# Entrar e sair: a equipe na frente da porta, Interagir, e as fotos ao longo da passagem.
	street._mood = "golden"
	street._raining = false
	street._apply_weather()
	for facade in FACADES:
		var room := -1
		for i in corridor.side_rooms.size():
			if corridor.side_rooms[i].zone == int(facade[2]):
				room = i
		if room < 0:
			continue
		var entry: Dictionary = corridor.side_rooms[room]
		corridor._enter_segment(corridor._segment_of(0), float(entry.door_x) + 0.2)
		await _wait(1.0)
		await _shot("%s-enter-0" % facade[0])
		corridor._enter_side_room(room)
		for i in range(1, 5):
			await _wait(0.55)
			await _shot("%s-enter-%d" % [facade[0], i])
		await _until(func(): return not corridor.busy)
		await _wait(0.8)
		await _shot("%s-inside" % facade[0])
		# A porta de dentro mostra a hora e a chuva de fora.
		street._mood = "night"
		street._raining = true
		street._apply_weather()
		await _wait(0.8)
		await _shot("%s-inside-night-rain" % facade[0])
		street._mood = "golden"
		street._raining = false
		street._apply_weather()
		corridor._leave_side_room()
		for i in range(1, 5):
			await _wait(0.55)
			await _shot("%s-leave-%d" % [facade[0], i])
		await _until(func(): return not corridor.busy)
		await _wait(0.6)
		await _shot("%s-outside" % facade[0])
	print("capturas da #141 em %s" % out)
	quit(0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print(name)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _until(condition: Callable, seconds: float = 20.0) -> void:
	var limit := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < limit:
		await process_frame
