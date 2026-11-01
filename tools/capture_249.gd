## QA por captura da #249 (a roupa confortável do lobby), pela Estação de verdade:
##   xvfb-run -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     -s res://tools/capture_249.gd -- --out=<pasta> [--wait=2]
## Roda também na main de antes. Campanha própria na pasta da saída, apagada no fim.
## - lobby_*: o jogo aberto na Estação. Os moradores ficam onde o código da Estação os põe (a roupa é a que ele
##   escolhe); a foto só os para em lugares fixos: a Sala (de pé), a Cantina (Bento e Nick sentados, dois recrutas de
##   pé) e o Dormitório à noite (os quatro fundadores deitados).
## - chegada_*: a volta de uma expedição. A fila do relatório na plataforma e, depois de a equipe sair dela, os quatro
##   na Sala.
extends SceneTree

const FOUNDERS := ["hero_cao_bento", "hero_gato_nick", "hero_sapo_iris", "hero_coruja_vespera"]
const ROOMS := ["characters", "canteen", "dormitory", "research"]
## As câmeras das capturas do #249 (docs/design/lobby_poses/capture.json): a Sala, a Cantina e o Dormitório.
const ROOM_CAMERA := Vector3(3.6, -3.9, 6.2)
const CANTEEN_CAMERA := Vector3(20.5, -3.9, 6.2)
const DORM_CAMERA := Vector3(-8.47, -3.9587207, 6.2)
const STAND_X := [1.2, 2.8, 4.4, 6.0]

var out := ""
var wait := 2
## Carregados depois dos autoloads (um script de -s não compila com eles no preload).
var S
var campaign
var flow


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--wait="):
			wait = int(arg.trim_prefix("--wait="))
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	S = load("res://scripts/flow/station_rules.gd")
	campaign = root.get_node("Campaign")
	flow = root.get_node("GameFlow")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	root.get_node("Settings")._persist = false
	load("res://scripts/flow/briefing_rules.gd").enabled = false
	await _lobby()
	await _arrival()
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	print("capturas da #249 em %s" % out)
	quit(0)


func _campaign(seed_value: int) -> Dictionary:
	var c: Dictionary = campaign.create_initial(seed_value)
	for room in ROOMS:
		c.station.rooms[room] = maxi(1, int(c.station.rooms.get(room, 0)))
	for class_id in ["cao", "coruja"]:
		S._add_hero(c, S._next_hero_id(c, class_id), class_id, "Recruta %s" % class_id, [], S.pick_art_variant(c, class_id))
	return c


func _lobby() -> void:
	var c := _campaign(249)
	var station = await _open(c)
	station.set_process(false)
	station.hud.visible = false
	var camera := _camera(station)
	var walkers := {}
	for walker in station._walkers:
		if walker.has("hero_id"):
			walkers[walker.hero_id] = walker
	var recruits: Array = walkers.keys().filter(func(id): return not FOUNDERS.has(id))
	# A Sala: os quatro de pé.
	_only(station, FOUNDERS)
	for i in FOUNDERS.size():
		_stand(walkers[FOUNDERS[i]], Vector3(STAND_X[i], -5.2, -3.3))
	camera.position = ROOM_CAMERA
	await _shot("lobby_sala")
	# A Cantina: Bento e Nick no banco, os dois recrutas de pé.
	_only(station, ["hero_cao_bento", "hero_gato_nick"] + recruits)
	for i in 2:
		var walker: Dictionary = walkers[FOUNDERS[i]]
		walker.seat = i
		station._seats[i] = walker
		station._sit_down(walker)
	for i in recruits.size():
		_stand(walkers[recruits[i]], Vector3(21.8 + i * 1.6, -5.2, -3.3))
	camera.position = CANTEEN_CAMERA
	await _shot("lobby_cantina")
	# O Dormitório à noite: os quatro fundadores deitados.
	for i in 2:
		station._stand_up(walkers[FOUNDERS[i]])
	c.night.phase = "planning"
	c.night.participants = FOUNDERS.duplicate()
	c.night.watch_hero_id = ""
	station._update_sleepers()
	_only(station, FOUNDERS)
	camera.position = DORM_CAMERA
	await _shot("lobby_dormitorio")
	c.night.phase = "none"


func _arrival() -> void:
	var c := _campaign(250)
	load("res://scripts/flow/journey_rules.gd").start_expedition(c, "fase_1", 250)
	c.session.expedition.team = FOUNDERS.duplicate()
	c.session.result = "victory"
	S.finish_return(c)
	var station = await _open(c)
	var hud = station.hud
	for i in 600:
		if station.team_arriving():
			break
		await process_frame
	station.finish_team_arrival()
	for i in 600:
		if hud.current == "report":
			break
		await process_frame
	await _frames(wait)
	await _shot("chegada_relatorio")
	# A equipe sai da plataforma: cada um volta ao cômodo dele.
	hud._enter_shelter_then(Callable())
	for entry in station._leaving.duplicate():
		station._release_leaving(entry)
	station.set_process(false)
	hud.visible = false
	var camera := _camera(station)
	_only(station, FOUNDERS)
	for walker in station._walkers:
		if FOUNDERS.has(walker.get("hero_id", "")):
			_stand(walker, Vector3(STAND_X[FOUNDERS.find(walker.hero_id)], -5.2, -3.3))
	camera.position = ROOM_CAMERA
	await _shot("chegada_sala")


func _open(c: Dictionary):
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	for i in 600:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.has_method("play_team_arrival") and current_scene.hud != null and i > 3:
			break
	await _frames(wait)
	return current_scene


func _camera(station) -> Camera3D:
	var camera := Camera3D.new()
	camera.fov = 26.0
	camera.rotation_degrees = Vector3(-3.0, 0, 0)
	station.add_child(camera)
	camera.current = true
	return camera


## Só os moradores pedidos ficam à vista (os outros e os civis saem da foto).
func _only(station, ids: Array) -> void:
	for id in station.residents:
		station.residents[id].visible = ids.has(id)


## Parado de pé, na pose de parado da roupa que o código escolheu, virado para a direita.
func _stand(walker: Dictionary, feet: Vector3) -> void:
	walker.card.show_art(walker.idle)
	walker.card.position = feet
	walker.card.scale = Vector3.ONE
	walker.card.set_facing(1.0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(wait)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
