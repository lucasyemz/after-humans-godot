## Fotos da partida no vagão (#75): da Preparação confirmada na Estação, a passagem com a equipe sentada no metrô em
## movimento, o título da fase por cima e a fase aberta. Equipes de 1, 2 e 4 fundadores e uma com recrutas (de pé nas
## pontas), e "Reduzir efeitos" (só o título).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_departure.gd -- --out=<pasta>
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
var flow
var campaign


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
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
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	await _depart("01-four-founders", [0, 1, 2, 3], "fase_1", true)
	await _depart("02-one-hero", [0], "fase_1", false)
	await _depart("03-two-founders-two-recruits", [0, 4, 1, 5], "fase_1", false)
	await _depart("04-reduced-effects", [0, 1, 2, 3], "fase_1", false, true)
	var files := DirAccess.get_files_at(campaign.save_dir)
	for file in files:
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


## Uma campanha com os fundadores e dois recrutas; a Preparação confirmada na Estação e a passagem fotografada.
func _depart(name: String, picks: Array, phase: String, with_arrival: bool, reduced: bool = false) -> void:
	var R = load("res://scripts/flow/station_rules.gd")
	var c: Dictionary = campaign.create_initial(41)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for class_id in ["cao", "gato"]:
		R.recruit(c, class_id, rng, "Teste")
	c.settings.reduced_environment_effects = reduced
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	await _idle()
	var station = current_scene
	var team: Array = picks.map(func(i): return c.roster[i].id)
	station.hud._draft = {"phase": phase, "team": team, "focus": "", "extra": 0}
	station.hud._depart()
	# O briefing da saída (#88) abre antes da passagem: Pular parte.
	await process_frame
	if station.hud.get("briefing") != null and is_instance_valid(station.hud.briefing):
		station.hud.briefing.skip()
	await _wait(func(): return flow.passage != null and flow._fade.modulate.a <= 0.01)
	if not reduced:
		# Pelo relógio (a passagem conta pelo relógio; sem GPU, poucos quadros por segundo).
		await create_timer(1.2, true, false, true).timeout
		await _shot(name + "-ride")
	await _idle()
	# O título por cima do vagão (ou só o título, com Reduzir efeitos): o mesmo cartão, aberto sozinho. Sem GPU, a
	# passagem de verdade já está fechando quando o título acende.
	var W = load("res://scripts/station/wagon_ride.gd")
	var card: Dictionary = W.departure_card(campaign.state)
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var still = load("res://scripts/ui/passage_card.gd").new(card, reduced)
	layer.add_child(still)
	still.mark_ready()
	if not reduced:
		await create_timer(W.RIDE_SECONDS + 0.8, true, false, true).timeout
	await _frames(3)
	await _shot(name + ("" if reduced else "-title"))
	layer.free()
	if with_arrival:
		await _frames(20)
		await _shot(name + "-arrived")


func _idle() -> void:
	await _frames(3)
	await _wait(func(): return not flow.busy)
	await _frames(3)


func _wait(condition: Callable) -> void:
	for i in 3000:
		if condition.call():
			return
		await process_frame


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
