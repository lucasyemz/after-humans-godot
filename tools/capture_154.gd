## QA por captura da #154 (a luz prática na Rua das Vitrines), pela cena de verdade:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_154.gd -- --out=<pasta>
## Para a prova da luz, rodar no Forward+ (numa máquina com placa de vídeo): "$GODOT" --rendering-method forward_plus ...
## No Compatibility, as fontes ficam só com o halo e a poça desenhados (o que o jogador da web vê).
## Campanha própria na pasta da saída e as opções só na memória. Roda também na main de antes. A equipe na frente de cada
## fonte (o tambor no beco, com a emergência na quina; o lampião), no fim de tarde, de noite, na chuva e na noite com chuva, no
## Ultra; o tambor no Baixo e no Alto; e o drone passando de noite (6 quadros). Grava frames.txt com o tempo do quadro.
extends SceneTree

## Onde a equipe para (x na rua) para cada fonte.
const SPOTS := [["barrel", 49.5], ["lantern", 38.0]]
const MOODS := [["golden", "golden", false], ["night", "night", false], ["rain", "golden", true], ["nightrain", "night", true]]

var out := ""
var campaign
var flow
var settings
var J
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
	J = load("res://scripts/flow/journey_rules.gd")
	root.get_node("Tips").enabled = false
	settings._persist = false
	campaign.save_dir = out.path_join("save")
	settings.set_level(3)
	var street = await _open()
	if street != null:
		for spot in SPOTS:
			_go(street, float(spot[1]))
			for mood in MOODS:
				await _mood(street, mood)
				await _shot("%s-%s-ultra" % [spot[0], mood[0]])
		_go(street, float(SPOTS[0][1]))
		await _mood(street, MOODS[1])
		for level in [[0, "low"], [2, "high"]]:
			settings.set_level(level[0])
			await _wait(1.0)
			await _shot("barrel-night-%s" % level[1])
		settings.set_level(3)
		# O drone de noite: a equipe no meio da rua e 6 quadros enquanto ele passa por cima dela (de x 12 a 28).
		# Na main de antes não há fontes (_practical): as fotos do drone ficam de fora.
		var sources = street.get("_practical")
		var drone: Array = sources.filter(func(p): return p.kind == "drone") if sources != null else []
		if not drone.is_empty():
			drone[0]._time = 0.0
			_go(street, 20.0)
			for i in 6:
				drone[0]._time = drone[0].DRONE_PERIOD * drone[0].DRONE_PASS * (0.21 + i * 0.035)
				await _wait(0.5)
				await _shot("drone-%d" % i)
	var file := FileAccess.open(out.path_join("frames.txt"), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	print("capturas da #154 em %s" % out)
	quit(0)


## Leva a equipe ao trecho da rua que tem esse x (o líder fica preso à área de andar do trecho).
func _go(street, x: float) -> void:
	var corridor = street.corridor
	var segment := 0
	for i in corridor.segments.size():
		if float(corridor.segments[i].x0) <= x and x < float(corridor.segments[i].x1):
			segment = i
	corridor._enter_segment(segment, x)


func _mood(street, mood: Array) -> void:
	street._mood = mood[1]
	street._raining = mood[2]
	street._apply_weather()
	await _wait(1.5)


func _open():
	var c: Dictionary = campaign.create_initial(9)
	J.start_expedition(c, "fase_1", 9)
	var route: Dictionary = c.session.expedition.corridor
	for step in route.steps.size() - 1:
		route.steps[step].resolved = true
	route.index = 0
	campaign.state = c
	campaign.save()
	flow.change_to("street", {}, false)
	for frame in 900:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.name == "Street" and frame > 3:
			await _wait(1.0)
			return current_scene
	return null


func _shot(name: String) -> void:
	# O tempo do quadro: a média de 30 quadros antes da foto.
	var start := Time.get_ticks_usec()
	for i in 30:
		await process_frame
	var ms := (Time.get_ticks_usec() - start) / 30000.0
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	lines.append("%s avg_ms=%.1f renderer=%s" % [name, ms, RenderingServer.get_current_rendering_method()])
	print(name)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout
