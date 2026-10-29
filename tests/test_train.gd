## A cena do trem na ordem (#61). Na chegada: o aviso (o sino e o sinal), o freio, a parada, as portas, o candidato
## descendo, ele na plataforma e só então a câmera nele e o painel. Na recusa: o candidato volta ao trem, o sino, as
## portas fecham e só então o trem anda com o som da partida. Nenhum painel por cima durante a cena; a 2x a cena leva
## a metade; com "Reduzir efeitos" o sinal não pisca.
extends RefCounted

const ARRIVAL := ["warning", "brake", "stop", "doors_open", "candidate_out", "candidate_ready", "camera_on_candidate"]
const DEPARTURE := ["boarding", "boarded", "doors_closing", "doors_closed", "leaving", "gone"]

var t
var _tree: SceneTree
var _events: Array = []
var _times: Dictionary = {}
var _clock := 0.0
var _longest := 0.0


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var real_scale := Engine.time_scale
	Campaign.save_dir = "user://test-train-%d" % Time.get_ticks_usec()
	var tips: bool = Tips.enabled
	Tips.enabled = false
	await _scene(1, false)
	await _scene(2, true)
	Engine.time_scale = real_scale
	Tips.enabled = tips
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state


## A volta com um candidato: a Estação abre o trem sozinha. speed: a velocidade das Opções.
func _scene(speed: int, reduced: bool) -> void:
	var c: Dictionary = Campaign.create_initial(11)
	c.settings.battle_speed = speed
	c.settings.reduced_environment_effects = reduced
	AHStationRules.train_on_return(c, "test-train-%d" % speed, "civilian")
	var candidate: String = c.station.train.candidate_id
	Campaign.state = c
	Campaign.save()
	# O tempo do jogo acelerado só para o teste andar depressa (os tempos medidos são os do jogo).
	Engine.time_scale = 4.0
	GameFlow.change_to("station", {}, false)
	var station: AHStation = null
	for frame in 600:
		await _tree.process_frame
		if _tree.current_scene is AHStation and _tree.current_scene.hud != null:
			station = _tree.current_scene
			break
	if not t.check(station != null, "a Estação abre (%dx)" % speed):
		return
	_events.clear()
	_times.clear()
	_clock = 0.0
	_longest = 0.0
	station.train_event.connect(_on_event)
	var sounds: Array = []
	var seen: int = Sound._next_effect
	var panel_during := false
	var blink := false
	# O trem da Estação é o vagão verde em camadas (#256), e a faísca sai na freada (sem ela com Reduzir efeitos).
	var car: AHTrainCar = station._build.train_car
	t.check(car != null and car.is_inside_tree() and station._build.wagon_doors.is_empty(), "o trem da Estação é o vagão verde, sem o metrô (%dx)" % speed)
	var sparked := false
	var end := Time.get_ticks_msec() + 60000
	while not _events.has("camera_on_candidate") and Time.get_ticks_msec() < end:
		await _tree.process_frame
		_clock += _tree.root.get_process_delta_time()
		_longest = maxf(_longest, _tree.root.get_process_delta_time())
		seen = _sounds(seen, sounds)
		if _events.has("warning") and not _events.has("camera_on_candidate") and station.hud._panel.visible:
			panel_during = true
		if _events.has("warning") and not _events.has("stop") and station._build.signal_glow and not station._build.signal_glow.visible:
			blink = true
		if car != null and car.find_children("*", "CPUParticles3D", true, false).any(func(p): return p.emitting):
			sparked = true
	t.equal(_events.filter(func(e): return ARRIVAL.has(e)), ARRIVAL, "a chegada na ordem (%dx)" % speed)
	t.check(not panel_during, "nenhum painel por cima da chegada (%dx)" % speed)
	t.check(_index(sounds, "train_bell") >= 0 and _index(sounds, "train_bell") < _index(sounds, "train_brake"),
		"o sino avisa antes do freio %s" % [sounds])
	if reduced:
		t.check(not blink, "com Reduzir efeitos, o sinal não pisca")
		t.check(not sparked, "nem sai faísca na freada")
	else:
		t.check(blink, "o sinal pisca na chegada")
		t.check(sparked, "a faísca nas rodas na freada")
	t.check(car == null or is_zero_approx(car.position.x - car.get("_home").x), "o vagão parado no lugar")
	# As portas que abrem são as do lado da plataforma (o outro lado): as folhas à vista ficam fechadas, e a luz fria das
	# portas abertas acende na plataforma.
	t.check(car == null or (car.doors_open() <= 0.0 and station._build.train_door_lights.all(func(e): return (e[0] as OmniLight3D).light_energy > 0.0)),
		"as portas do lado da plataforma abertas: as deste lado fechadas e a luz delas na plataforma")
	t.check(station.passage_moving() == false and station._goal == station._candidate_key(), "a câmera termina no candidato")
	t.check(station._key.pos.distance_to(station._candidate_key().pos) < 0.1, "e o painel só abre com a câmera já nele")
	if speed == 2:
		var span: float = _times.stop - _times.warning
		# Com a folga de um quadro (com a máquina carregada um quadro pode passar de meio segundo de jogo).
		t.check(absf(span - AHStation.TRAIN_STOP / 2.0) <= _longest + 0.05, "a 2x a chegada leva a metade (%.2f s, quadro de %.2f s)" % [span, _longest])
	# O painel abre quando a câmera fecha no candidato.
	for i in 3:
		await _tree.process_frame
	t.check(station.hud._panel.visible and station.hud.current == "train", "e então o painel do trem abre (%dx)" % speed)
	if speed == 1:
		await _reopen(station)
	# A recusa: o candidato volta ao trem, o sino, as portas e só então o som da partida.
	_events.clear()
	sounds.clear()
	seen = Sound._next_effect
	panel_during = false
	station.hud._decide(candidate, false)
	var door_seen := false
	end = Time.get_ticks_msec() + 60000
	while not _events.has("gone") and Time.get_ticks_msec() < end:
		await _tree.process_frame
		seen = _sounds(seen, sounds)
		if not _events.has("gone") and station.hud._panel.visible:
			panel_during = true
		if _events.has("doors_closing") and not _events.has("leaving"):
			door_seen = door_seen or _on_screen(station, Vector3(station._train_door_x(), 1.2, AHStation.LINE_Z))
	t.check(door_seen, "a porta do vagão à vista quando fecha (%dx)" % speed)
	t.equal(_events.filter(func(e): return DEPARTURE.has(e)), DEPARTURE, "a partida na ordem (%dx)" % speed)
	t.check(not panel_during, "nenhum painel por cima da partida (%dx)" % speed)
	t.check(_index(sounds, "train_bell") >= 0 and _index(sounds, "train_bell") < _index(sounds, "train_departure"),
		"o sino antes do som da partida %s" % [sounds])
	await _tree.process_frame
	await _tree.process_frame
	t.equal(Campaign.state.station.train.phase, "none", "o trem foi embora (%dx)" % speed)
	t.check(not is_instance_valid(station._candidate), "levando o recusado")
	# O som do trem some com ele (o arquivo é mais longo que a saída).
	await _tree.create_timer(1.0).timeout
	t.check(Sound._effects.all(func(p): return not p.playing or not ["train_arrival.ogg", "train_departure.ogg"].has(String(p.stream.resource_path).get_file())),
		"nenhum som do trem depois que ele some (%dx)" % speed)
	# Pulada a volta da equipe no meio da freada, a faísca e a luz dela apagam com o trem fora (#256).
	if car != null:
		station._train_mode = 4
		car.brake(true, 1.0, 1.0)
		station.finish_team_arrival()
		var lit: bool = car.find_children("*", "CPUParticles3D", true, false).any(func(p): return p.emitting or (p.get_child(0) as OmniLight3D).light_energy > 0.0)
		t.check(not lit, "pulada a chegada na freada, a faísca apaga (%dx)" % speed)
	station.train_event.disconnect(_on_event)


## Fechar o trem (a câmera desce ao abrigo) e reabrir: a passagem termina no candidato, e o painel só abre lá.
func _reopen(station) -> void:
	station.hud.close_panel()
	var end := Time.get_ticks_msec() + 60000
	while (station.passage_moving() or station.on_platform) and Time.get_ticks_msec() < end:
		await _tree.process_frame
	await _tree.create_timer(0.5).timeout
	_events.clear()
	station.hud.open_service("train")
	await _tree.process_frame
	var panel_early := false
	end = Time.get_ticks_msec() + 60000
	while not _events.has("camera_on_candidate") and Time.get_ticks_msec() < end:
		await _tree.process_frame
		if not _events.has("camera_on_candidate") and station.hud._panel.visible:
			panel_early = true
	t.check(_events.has("camera_on_candidate") and station._goal == station._candidate_key(), "reaberto, a câmera volta ao candidato")
	t.check(not panel_early, "e o painel não abre durante a passagem")
	await _tree.process_frame
	await _tree.process_frame
	t.check(station.hud._panel.visible and not station.train_busy(), "e abre quando ela chega")


func _on_screen(station, point: Vector3) -> bool:
	var camera: Camera3D = station.camera
	if camera.is_position_behind(point):
		return false
	return station.get_viewport().get_visible_rect().has_point(camera.unproject_position(point))


func _on_event(name: String) -> void:
	_events.append(name)
	_times[name] = _clock


func _sounds(seen: int, out: Array) -> int:
	while seen != Sound._next_effect:
		var player: AudioStreamPlayer = Sound._effects[seen]
		out.append(player.stream.resource_path.get_file().get_basename())
		seen = (seen + 1) % Sound._effects.size()
	return seen


func _index(list: Array, name: String) -> int:
	return list.find(name)
