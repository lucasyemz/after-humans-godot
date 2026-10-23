## Prova da silhueta e do esmaecimento (#51): um personagem atrás de um objeto na rua, num cenário e na Estação, com
## e sem o efeito, e o tempo de quadro dos dois (média de 60 quadros, sem vsync).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_occlusion.gd -- --out=<pasta> [--only=street|scenario|station] [--phase=fase_3]
## Grava <lugar>-off.png, <lugar>-on.png e occlusion.txt (o objeto esmaecido e os tempos); sai com 1 se em algum lugar
## nada esmaeceu. A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
var lines: Array[String] = []
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var only := ""
	var scenario_phase := "fase_3"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
		elif arg.begins_with("--phase="):
			scenario_phase = arg.trim_prefix("--phase=")
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var campaign = root.get_node("Campaign")
	campaign.save_dir = out.path_join("save")
	root.get_node("Tips").set("enabled", false)
	if only == "" or only == "street":
		await _street(campaign, "street", "fase_1")
	if only == "" or only == "scenario":
		await _street(campaign, "scenario", scenario_phase)
	if only == "" or only == "station":
		await _station(campaign)
	FileAccess.open(out.path_join("occlusion.txt"), FileAccess.WRITE).store_string("\n".join(lines) + "\n")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	print("%d lugares sem esmaecimento" % failures)
	quit(1 if failures > 0 else 0)


func _street(campaign, name: String, phase: String) -> void:
	var c: Dictionary = campaign.create_initial(7)
	c.completed_phases = ["fase_1", "fase_2", "fase_3", "fase_4"].slice(0, ["fase_1", "fase_2", "fase_3", "fase_4", "fase_5"].find(phase))
	load("res://scripts/flow/station_rules.gd").confirm_departure(c, c.preferred_formation.duplicate(), 0, 20261021, phase, "")
	campaign.state = c
	campaign.save()
	root.get_node("GameFlow").change_to("street", {}, false)
	await create_timer(2.5).timeout
	var street = current_scene
	var occlusion = street.occlusion
	# Um objeto que pode tapar alguém, perto do começo: a equipe vai para trás dele.
	for o in _sorted(occlusion._occluders, street._leader.position.x):
		if not is_instance_valid(o.node):
			continue
		var box: AABB = o.box
		# Um objeto que tape o corpo de verdade (um carro, um poste, um móvel), não a fogueira.
		if box.size.y < (0.6 if street.scenario else 1.2) or box.size.y > 4.5 or box.size.x < 0.6 or box.size.x > 6.0 or o.node.get_parent().name == "Campfire":
			continue
		# Num cenário, só os da zona onde a equipe está (a faixa de andar e a câmera são as da zona).
		if street.scenario and street.scenario.zone_at(box.get_center().x) != street.scenario.zone_at(street._leader.position.x):
			continue
		# Atrás dele (a colisão do objeto pode ser mais funda que a placa: tenta mais para trás).
		var hidden := false
		for back in [0.4, 1.1, 1.7]:
			var behind := Vector3(box.get_center().x, street.floor_y, box.position.z - back)
			if behind.z < street.walk_min.z or behind.z > street.walk_max.z or behind.x < street.walk_min.x or behind.x > street.walk_max.x:
				continue
			street._place_leader(behind)
			await create_timer(0.6).timeout
			if occlusion.faded().has(o.node):
				hidden = true
				break
		if hidden:
			break
	await _compare(name, occlusion, street._heroes)


func _station(campaign) -> void:
	campaign.state = campaign.create_initial(7)
	campaign.save()
	root.get_node("GameFlow").change_to("station", {}, false)
	await create_timer(3.0).timeout
	var station = current_scene
	var occlusion = station.occlusion
	var cards: Array = []
	for walker in station._walkers:
		if walker.has("hero_id"):
			cards.append(walker.card)
	if cards.is_empty():
		_line("station", false, "sem heróis na Estação")
		return
	# Um herói parado atrás de um móvel do andar dele.
	var placed := false
	for walker in station._walkers:
		if not walker.has("hero_id") or placed:
			continue
		var card: Node3D = walker.card
		for o in _sorted(occlusion._occluders, card.position.x):
			var box: AABB = o.box
			if box.position.z <= card.position.z or box.position.y > walker.floor + 1.2 or box.end.y < walker.floor + 0.3 \
					or box.size.x > 4.0 or box.size.y > 3.0 or absf(box.get_center().x - card.position.x) > 6.0:
				continue
			for key in ["min", "max", "target"]:
				walker[key] = box.get_center().x
			walker.wait = 999.0
			card.position.x = box.get_center().x
			station.focus_room(walker.room)
			await create_timer(0.6).timeout
			if not occlusion.faded().is_empty():
				placed = true
				break
	await _compare("station", occlusion, cards)


## Fotografa sem e com o efeito no mesmo lugar e mede os dois.
func _compare(name: String, occlusion, cards: Array) -> void:
	var faded: Array = occlusion.faded()
	var what := ", ".join(faded.map(func(n): return str(n.name)))
	occlusion.set_process(false)
	for node in faded:
		node.transparency = 0.0
	for card in cards:
		card.set_silhouette(null)
	await create_timer(0.4).timeout
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + "-off.png"))
	var off := await _frame_ms()
	var calls_off := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	for card in cards:
		occlusion.track(card)
	occlusion.set_process(true)
	await create_timer(0.6).timeout
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + "-on.png"))
	var on := await _frame_ms()
	var calls_on := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	# O custo do teste a cada quadro, no processador (o que pesa na web): média de 200 chamadas.
	var started := Time.get_ticks_usec()
	for i in 200:
		occlusion._process(0.0)
	var cpu := (Time.get_ticks_usec() - started) / 200.0
	_line(name, not faded.is_empty(), "esmaecido=[%s] quadro sem=%.2f ms com=%.2f ms, chamadas de desenho %d -> %d, teste %.0f us/quadro (%d objetos registrados)" % [
		what, off, on, calls_off, calls_on, cpu, occlusion._occluders.size()])


func _frame_ms() -> float:
	await process_frame
	var started := Time.get_ticks_usec()
	for i in 60:
		await process_frame
	return (Time.get_ticks_usec() - started) / 60000.0


func _sorted(occluders: Array, x: float) -> Array:
	var list := occluders.duplicate()
	list.sort_custom(func(a, b): return absf(a.box.get_center().x - x) < absf(b.box.get_center().x - x))
	return list


func _line(name: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	var line := "%s %s %s" % [name, "PASS" if ok else "FAIL", detail]
	lines.append(line)
	print(line)
