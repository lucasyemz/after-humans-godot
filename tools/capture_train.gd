## Gravação quadro a quadro do trem da Estação (#61): o jogador abre o trem com um candidato esperando, o trem chega e o
## candidato desce; depois o jogador recusa e o trem parte levando o candidato. Anota a cada quadro o tempo (s de jogo),
## o vagão, as portas, o candidato, a câmera, o painel do HUD e cada som tocado, e marca os eventos (som, parada,
## portas, candidato, câmera parada no candidato, painel). Fotografa a cada 0,5 s.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_train.gd -- --out=<pasta> [--speed=2] [--reduced] [--slow=0.25]
## Grava timeline.txt (um quadro por linha), events.txt (os eventos em ordem, com o tempo) e frame-<t>.png.
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
var speed := 1.0
var reduced := false
var slow := 1.0
var lines: Array[String] = []
var events: Array[String] = []
var _time := 0.0
var _seen_sound := 0
var _last: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--speed="):
			speed = float(arg.trim_prefix("--speed="))
		elif arg == "--reduced":
			reduced = true
		elif arg.begins_with("--slow="):
			# Nesta máquina (sem GPU) um quadro leva muito: o tempo do jogo anda mais devagar para a gravação ter quadros
			# mais finos. Os tempos anotados são os do jogo.
			slow = float(arg.trim_prefix("--slow="))
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	var S = load("res://scripts/flow/station_rules.gd")
	campaign.save_dir = out.path_join("save")
	root.get_node("Tips").set("enabled", false)
	var c: Dictionary = campaign.create_initial(11)
	c.settings.reduced_environment_effects = reduced
	c.settings.battle_speed = int(speed)
	S.train_on_return(c, "capture-train")
	campaign.state = c
	campaign.save()
	# A volta com um candidato: a Estação abre o trem sozinha (o fluxo do jogo).
	Engine.time_scale = slow
	root.get_node("GameFlow").change_to("station", {}, false)
	while not (current_scene != null and current_scene.has_method("train_busy") and current_scene.hud != null):
		await process_frame
	var station = current_scene
	var hud = station.hud
	if station.has_signal("train_event"):
		station.train_event.connect(func(name): _mark("trem: " + name))
	var candidate: String = c.station.train.candidate_id
	_taken = _game_time
	_mark("início (a Estação abre)")
	await _record(station, hud, 18.0 / maxf(speed, 1.0))
	_mark("o jogador recusa")
	hud._decide(candidate, false)
	await _record(station, hud, 9.0 / maxf(speed, 1.0))
	FileAccess.open(out.path_join("timeline.txt"), FileAccess.WRITE).store_string("\n".join(lines) + "\n")
	FileAccess.open(out.path_join("events.txt"), FileAccess.WRITE).store_string("\n".join(events) + "\n")
	print("\n".join(events))
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _mark(text: String) -> void:
	events.append("%6.2f  %s" % [_time, text])


func _record(station, hud, seconds: float) -> void:
	var end := _time + seconds
	var next_shot := snappedf(_time, 0.5)
	var sound = root.get_node("Sound")
	while _time < end:
		await process_frame
		_time += _delta()
		# Os sons tocados desde o quadro anterior (cada play ocupa o próximo tocador da fila).
		while _seen_sound != sound._next_effect:
			var player: AudioStreamPlayer = sound._effects[_seen_sound]
			_mark("som %s" % player.stream.resource_path.get_file())
			_seen_sound = (_seen_sound + 1) % sound._effects.size()
		var candidate = station._candidate
		var state := {
			"wagon": snappedf(station._wagon_x, 0.01), "door": snappedf(station._door_open, 0.01), "mode": station._train_mode,
			"candidate": snappedf(candidate.position.x, 0.01) if is_instance_valid(candidate) else null,
			"camera": station.camera.global_position.snapped(Vector3.ONE * 0.05), "passage": station.passage_moving(),
			"panel": hud._panel.visible, "warning": station._warning_time >= 0.0}
		_events_from(state)
		lines.append("%6.2f wagon=%s door=%s mode=%s candidate=%s camera=%s passage=%s panel=%s warning=%s" % [_time,
			state.wagon, state.door, state.mode, state.candidate, state.camera, state.passage, state.panel, state.warning])
		if _time >= next_shot:
			root.get_viewport().get_texture().get_image().save_png(out.path_join("frame-%05.2f.png" % next_shot))
			next_shot += 0.5
		_last = state


var _game_time := 0.0
var _taken := 0.0


## O tempo de jogo de cada quadro: o mesmo delta que as cenas recebem (já com a escala de tempo).
func _process(delta: float) -> bool:
	_game_time += delta
	return false


func _delta() -> float:
	var step := _game_time - _taken
	_taken = _game_time
	return step


func _events_from(state: Dictionary) -> void:
	if _last.is_empty():
		return
	if state.passage != _last.passage:
		_mark("a câmera %s a passagem" % ("começa" if state.passage else "termina"))
	if state.warning != _last.warning:
		_mark("o sinal %s" % ("começa a piscar" if state.warning else "para de piscar"))
	if _last.wagon != 0.0 and state.wagon == 0.0 and state.mode == 1:
		_mark("o trem para")
	if _last.wagon == 0.0 and state.wagon != 0.0:
		_mark("o trem sai do lugar")
	if _last.door == 0.0 and state.door > 0.0:
		_mark("as portas começam a abrir")
	if _last.door < 1.0 and state.door >= 1.0:
		_mark("as portas terminam de abrir")
	if _last.door > 0.0 and state.door == 0.0:
		_mark("as portas terminam de fechar")
	if _last.candidate == null and state.candidate != null:
		_mark("o candidato aparece em x=%.2f" % state.candidate)
	if _last.candidate != null and state.candidate == null:
		_mark("o candidato some")
	if state.mode != _last.mode:
		_mark("o trem passa ao modo %d" % state.mode)
	if state.panel != _last.panel:
		_mark("o painel %s" % ("abre" if state.panel else "fecha"))
	# A câmera: quando começa a mover e quando para (fora da passagem).
	var moving: bool = _last.camera.distance_to(state.camera) > 0.0
	state["moving"] = moving
	if moving and not _last.get("moving", false):
		_mark("a câmera começa a mover")
	elif not moving and _last.get("moving", false):
		_mark("a câmera para")
