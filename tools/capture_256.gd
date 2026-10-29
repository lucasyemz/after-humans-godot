## QA por captura do trem 2D no jogo (#256), pelas cenas de verdade, com o antes e depois na mesma sequência:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_256.gd -- --out=<pasta> [--part=platform|passage]
## Campanha própria na pasta da saída (o save do jogador fica intacto).
## - platform: o tutorial direto na plataforma (as lutas resolvidas, o Nick na equipe). O trem chega freando, para com as
##   portas abertas, a equipe embarca pela porta da direita, as portas fecham e o vagão parte; e a passagem para a
##   Estação.
## - passage: a partida da Estação pela Preparação, com a viagem: a partida no túnel, o interior com a equipe sentada, o
##   título e a chegada freando.
## Os mesmos instantes rodam na main de antes (sem o vagão em camadas), para o antes e depois.
extends SceneTree

var out := ""
var part := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--part="):
			part = arg.trim_prefix("--part=")
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	campaign.save_dir = out.path_join("save")
	root.get_node("Tips").enabled = false
	if part == "" or part == "platform":
		await _platform()
	if part == "" or part == "passage":
		await _passage()
	quit(0)


func _platform() -> void:
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	campaign.state = campaign.create_initial(7)
	var tutorial = load("res://scripts/flow/tutorial_rules.gd")
	tutorial.begin(campaign.state)
	campaign.save()
	flow.change_to("street", {}, false)
	await _until(func(): return _street() != null and not flow.busy)
	# Direto na plataforma: os trechos antes do trem resolvidos, o Nick na equipe, e a rua de novo, que retoma a
	# chegada do trem.
	var c: Dictionary = campaign.state
	var route: Dictionary = c.session.expedition.corridor
	for index in route.steps.size() - 1:
		route.steps[index].resolved = true
	route.index = route.steps.size() - 1
	if not c.session.expedition.team.has("hero_gato_nick"):
		c.session.expedition.team.append("hero_gato_nick")
	campaign.save()
	flow.change_to("street", {}, false)
	await _until(func(): return _street() != null and not flow.busy)
	var street = _street()
	var corridor = street.corridor
	street._place_leader(Vector3(float(street.scenario.train.x) - 2.6, street.floor_y, street.lane_z))
	# A chegada: a freada (com a faísca na metade de baixo da velocidade) e as portas abrindo.
	await _until(func(): return corridor.busy, 5.0)
	await _wait(float(corridor.TRAIN_ARRIVAL_SECONDS) * 0.72)
	await _shot("platform-1-brake")
	await _until(func(): return not corridor.busy, 20.0)
	await _wait(0.5)
	await _shot("platform-2-open")
	street._place_leader(Vector3(float(street.scenario.train.x) - 1.2, street.floor_y, street.lane_z))
	await _wait(0.5)
	corridor._action.call()
	await _wait(1.4)
	await _shot("platform-3-boarding")
	await _wait(2.0)
	await _shot("platform-4-inside")
	await _until(func(): return flow.passage != null or _doors_closed(street), 10.0)
	await _wait(0.6)
	await _shot("platform-5-departure")
	await _until(func(): return flow.passage != null, 15.0)
	await _wait(1.0)
	await _shot("platform-6-passage")
	await _until(func(): return current_scene != null and current_scene.name == "Station" and not flow.busy, 60.0)


func _doors_closed(street) -> bool:
	var car = street.scenario.get("train_car")
	return car != null and car.doors_open() <= 0.0


func _passage() -> void:
	var campaign = root.get_node("Campaign")
	campaign.state = campaign.create_initial(31)
	var c: Dictionary = campaign.state
	load("res://scripts/flow/journey_rules.gd").start_expedition(c, "fase_1", 9)
	c.session.expedition.team = c.roster.slice(0, 4).map(func(h): return h.id)
	if current_scene != null:
		current_scene.queue_free()
	await process_frame
	# O cartão da partida, como a Preparação abre (a viagem por trás e o título da fase), sem a troca de cena.
	var ride_script = load("res://scripts/station/wagon_ride.gd")
	var card: Dictionary = ride_script.departure_card(c)
	var passage = load("res://scripts/ui/passage_card.gd").new(card, false)
	root.add_child(passage)
	var hold: float = float(card.get("hold", 4.6))
	var opened := Time.get_ticks_msec()
	for spot in [[0.6, "passage-1-depart"], [2.0, "passage-2-inside"], [3.6, "passage-3-title"], [hold - 0.75, "passage-4-arrive"]]:
		while (Time.get_ticks_msec() - opened) / 1000.0 < spot[0]:
			# A fase "monta" com o título aceso, como no GameFlow: a chegada só começa depois disso.
			if passage.title_lit and passage.has_method("backdrop_done"):
				passage.mark_ready()
			await process_frame
		await _shot(spot[1])
	passage.queue_free()


func _street():
	var scene := current_scene
	return scene if scene != null and scene.get("corridor") != null and scene.corridor != null and not scene.corridor.segments.is_empty() else null


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print(name)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _until(condition: Callable, seconds: float = 30.0) -> void:
	var limit := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < limit:
		await process_frame
	if not condition.call():
		push_warning("capture_256: o passo não chegou a tempo")
