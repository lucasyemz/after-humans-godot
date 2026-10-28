## QA por captura dos seis cenários (a contraparte do --capture da rua), pela cena da rua de verdade:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_scenarios.gd -- --out=<pasta> [--maps=RiverDock,...]
## Para cada mapa parte na fase dele (campanha própria, na pasta da saída: o save do jogador fica intacto) e, em cada
## zona, fotografa o fim de tarde seco e a noite com chuva, mede o quadro (média e p95 de 90 quadros) e confere:
## a equipe e as patrulhas no piso da zona, e o líder preso à faixa ao andar contra a ponta. Grava frames.txt com uma
## linha por foto e uma PASS/FAIL por conferência; sai com código 1 se alguma falhar.
extends SceneTree

const PHASE_OF := {"RiverDock": ["fase_2", 0], "RootBridge": ["fase_2", 4], "SealedShelter": ["fase_3", 0],
	"TriageGate": ["fase_4", 0], "FloodedDepot": ["fase_5", 0], "SewerDucts": ["fase_5", 4],
	"ContainmentCorridor": ["tutorial", 0]}

var out := ""
var lines: Array[String] = []
var failures := 0


func _initialize() -> void:
	var maps: Array = PHASE_OF.keys()
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
	# Sem vsync, para medir o custo real do quadro (como a captura da rua).
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var campaign = root.get_node("Campaign")
	campaign.save_dir = out.path_join("save")
	for map in maps:
		await _capture_map(campaign, map)
	var file := FileAccess.open(out.path_join("frames.txt"), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	var checks := lines.filter(func(l): return l.contains(" PASS ") or l.contains(" FAIL ")).size()
	print("%d conferências, %d com falha" % [checks, failures])
	quit(1 if failures > 0 or checks == 0 else 0)


func _capture_map(campaign, map: String) -> void:
	var spec: Array = PHASE_OF[map]
	var c: Dictionary = campaign.create_initial(7)
	c.completed_phases = ["fase_1", "fase_2", "fase_3", "fase_4"]
	# Carregado na hora: um script de -s não enxerga as classes globais antes dos autoloads.
	if spec[0] == "tutorial":
		# O mapa do tutorial (#147): a jornada do Bento, com o Nick já na equipe (as fotos mostram a equipe de quatro).
		var tutorial = load("res://scripts/flow/tutorial_rules.gd")
		tutorial.start_journey(c)
		c.session.expedition.team.append("hero_gato_nick")
	else:
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
	street.corridor.busy = true
	for zone_index in street.scenario.zones.size():
		street.set_scenario_zone(zone_index)
		var zone: Dictionary = street.scenario.zones[zone_index]
		street._place_leader(Vector3(minf(zone.x0 + 3.0, zone.x1 - 1.0), street.floor_y, street.lane_z))
		for mood in [["golden", false], ["night", true]]:
			street._mood = mood[0]
			street._raining = mood[1]
			street._wet = 1.0 if mood[1] else 0.0
			street._apply_weather()
			await create_timer(0.8).timeout
			var name := "%s-%d-%s" % [map, zone_index, "night-rain" if mood[1] else "golden"]
			await _measure(name)
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
		_check(map, zone_index, street)
		await _walk_check(map, zone_index, street)
	street.corridor.busy = false


func _measure(name: String) -> void:
	var times: Array[float] = []
	for i in 90:
		var start := Time.get_ticks_usec()
		await process_frame
		times.append((Time.get_ticks_usec() - start) / 1000.0)
	var avg: float = times.reduce(func(a, b): return a + b, 0.0) / times.size()
	times.sort()
	var line := "%s avg_ms=%.2f p95_ms=%.2f renderer=%s" % [name, avg, times[int(times.size() * 0.95)], RenderingServer.get_current_rendering_method()]
	lines.append(line)
	print(line)


## A equipe no piso da zona; as patrulhas da zona também.
func _check(map: String, zone_index: int, street) -> void:
	var floor_y: float = street.floor_y
	var off := 0
	for hero in street._heroes:
		if absf(hero.global_position.y - floor_y) > 0.05:
			off += 1
	var guards_off := 0
	for index in street.corridor.guards:
		var segment: Dictionary = street.corridor.segments[street.corridor._segment_of(index)]
		if segment.zone != zone_index:
			continue
		for card in street.corridor.guards[index].cards:
			if absf(card.global_position.y - floor_y) > 0.05:
				guards_off += 1
	_result("%s-%d-floor" % [map, zone_index], off == 0 and guards_off == 0, "heroes_off=%d guards_off=%d" % [off, guards_off])


## Andando contra a ponta direita, o líder para na faixa (nunca sai da zona nem do piso).
func _walk_check(map: String, zone_index: int, street) -> void:
	var zone: Dictionary = street.scenario.zones[zone_index]
	# O corredor parado (sem patrulha avistando nem viagem de zona), mas sem bloquear o andar.
	street.corridor.process_mode = Node.PROCESS_MODE_DISABLED
	street.corridor.busy = false
	street._place_leader(Vector3(zone.x1 - 1.5, street.floor_y, street.lane_z))
	Input.action_press("move_right")
	Input.action_press("move_front")
	await create_timer(1.2).timeout
	Input.action_release("move_right")
	Input.action_release("move_front")
	street.corridor.busy = true
	street.corridor.process_mode = Node.PROCESS_MODE_INHERIT
	var leader: Vector3 = street._leader.position
	var inside: bool = leader.x <= zone.x1 + 0.01 and leader.z <= street.walk_max.z + 0.01 and absf(leader.y - street.floor_y) < 0.05
	_result("%s-%d-lane" % [map, zone_index], inside, "reached=(%.2f, %.2f) limit=(%.2f, %.2f)" % [leader.x, leader.z, street.walk_max.x, street.walk_max.z])


func _result(name: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	var line := "%s %s %s" % [name, "PASS" if ok else "FAIL", detail]
	lines.append(line)
	print(line)
