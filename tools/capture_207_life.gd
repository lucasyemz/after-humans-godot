## Fotos da Estação viva (#207): um save com a planta herdada (todos os cômodos recuperados) depois da primeira volta.
##   overview: a vista geral com o Próximo passo (antes: o cômodo a recuperar; agora: Ouvir o Bento);
##   say:      dois cômodos de perto, o Bento e o Nick conversando (o balão da fala);
##   think:    o Bar aberto, o Nick pensando (o balão do pensamento);
##   story:    a conversa da tirinha no balão interativo;
##   comic:    a tirinha aberta no primeiro quadro (o quadro provisório);
##   door:     a porta aberta com quem sai do cômodo;
##   walk_NN:  os quadros de uma troca de cômodo (a porta abre, ele some, a outra porta abre e ele sai), para o gif.
## Roda também no código de antes (sem a Estação viva): só a vista geral e os cômodos de perto, sem balão.
##   xvfb-run -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     -s res://tools/capture_207_life.gd -- --out=<pasta> [--walk]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

const BENTO := "hero_cao_bento"
const NICK := "hero_gato_nick"

var out := ""
var walk := false
## Só uma parte (as fotos são lentas sem placa de vídeo): overview, say, think, story ou door; vazio faz todas.
var only := ""
var _log_file: FileAccess
var S


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--walk":
			walk = true
		elif arg.begins_with("--case="):
			only = arg.trim_prefix("--case=")
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	_log_file = FileAccess.open(out.path_join("log.txt"), FileAccess.WRITE)
	S = load("res://scripts/flow/station_rules.gd")
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	var c: Dictionary = campaign.create_initial(207)
	for room in S.ROOMS:
		c.station.rooms[room.id] = 1
	c.station.erase("grid")
	load("res://scripts/flow/station_grid.gd").migrate(c)
	c.station.cycle_number = 1
	c.station.last_return = {}
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	while flow.busy or current_scene == null or current_scene.get("hud") == null:
		await process_frame
	_log("a Estação abriu")
	var station = current_scene
	var hud = station.hud
	var life = station.get("life")
	if life != null:
		life.auto = false
	await _frames(30)
	station.focus_overview(true)
	await _snap(station)
	await _frames(3)
	if walk and life != null:
		await _walk(station, life)
		quit(0)
		return
	if _wants("overview"):
		await _shot("overview")
	# Dois cômodos de perto (o Bar e o vizinho do mesmo andar), com o Bento e o Nick no Bar.
	var pair := _pair(station)
	_log("de perto: %s" % [pair])
	if life != null:
		station.settle_in(_walker(station, BENTO), pair[0])
		station.settle_in(_walker(station, NICK), pair[0])
	if _wants("say"):
		_frame_rooms(station, pair)
		await _snap(station)
		await _frames(3)
	if life != null and _wants("say"):
		life.start_talk({"row": _chatter().entry("always_nick_bento_methods"), "ids": [NICK, BENTO], "name": ""})
		await _frames(8)
	if _wants("say"):
		await _shot("say")
	if life != null:
		life.stop_talk()
	if _wants("think"):
		hud.open_room(pair[0])
		await _snap(station)
		await _frames(5)
	if life != null and _wants("think"):
		life.start_talk({"row": _chatter().entry("bar_nick") if pair[0] == "bar" else _chatter().entry("always_nick_backpack"),
			"ids": [NICK], "name": ""})
		await _frames(8)
	if _wants("think"):
		await _shot("think")
	if life == null:
		quit(0)
		return
	life.stop_talk()
	if not _wants("story") and not _wants("door"):
		quit(0)
		return
	hud.close_panel()
	await _snap(station)
	await _frames(3)
	if not _wants("story"):
		await _door(station, life, pair)
		quit(0)
		return
	hud._run_next()
	for i in 400:
		await process_frame
		if life.bubble != null and not life.bubble.is_story():
			life._line_left = 0.0
		if life.story_bubble() != null:
			break
	await _snap(station)
	await _frames(8)
	await _shot("story")
	life.story_bubble().get_node("Open").pressed.emit()
	await _frames(8)
	await _shot("comic")
	hud._comic._close()
	await _frames(3)
	if _wants("door"):
		await _door(station, life, pair)
	quit(0)


func _door(station, life, pair: Array) -> void:
	# A porta abrindo: alguém do Bar sai pela porta do fundo.
	_frame_rooms(station, pair)
	await _snap(station)
	var who = _walker(station, NICK)
	life.start_trip(who, pair[1])
	life.set_process(false)
	while life.trip.phase != "in":
		life._tick_doors(0.05)
		life._tick_trip(0.05)
	for i in 6:
		life._tick_doors(0.05)
		life._tick_trip(0.05)
	await _frames(3)
	await _shot("door")


## Os quadros de uma troca de cômodo, para o gif: o Nick sai do Bar pela porta e chega ao vizinho do mesmo andar.
func _walk(station, life) -> void:
	var pair := _pair(station)
	var who = _walker(station, NICK)
	station.settle_in(who, pair[0])
	_frame_rooms(station, pair)
	await _snap(station)
	await _frames(5)
	life.start_trip(who, pair[1])
	life.set_process(false)
	var index := 0
	var step := 0
	while not life.trip.is_empty() and step < 2000:
		step += 1
		life._tick_doors(0.05)
		life._tick_trip(0.05)
		# 10 quadros por segundo de jogo; entre as portas, o tempo do corredor passa rápido (só 1 em 4).
		var away: bool = not life.trip.is_empty() and life.trip.phase == "away"
		if step % 2 == 0 and (not away or step % 8 == 0):
			await _frames(1)
			await _shot("walk_%03d" % index)
			index += 1
	for i in 8:
		life._tick_doors(0.05)
		life._tick_trip(0.05)
		await _frames(1)
		await _shot("walk_%03d" % index)
		index += 1


## O primeiro cômodo da grade com um vizinho recuperado no mesmo andar (o Bar, se der).
func _pair(station) -> Array:
	var rooms: Array = current_scene.rooms().filter(func(r): return r.place == "grid" and S.room_level(root.get_node("Campaign").state, r.id) >= 1)
	rooms.sort_custom(func(a, b): return a.id == "bar" and b.id != "bar")
	for room in rooms:
		for other in rooms:
			if other.id != room.id and is_equal_approx(other.floor, room.floor) and (is_equal_approx(other.x0, room.x1) or is_equal_approx(other.x1, room.x0)):
				return [room.id, other.id]
	return [rooms[0].id, rooms[1].id]


func _frame_rooms(station, pair: Array) -> void:
	var a: Dictionary = current_scene.room_def(pair[0])
	var b: Dictionary = current_scene.room_def(pair[1])
	station._in_overview = false
	station._set_goal(station._framed_key(minf(a.x0, b.x0), maxf(a.x1, b.x1), a.floor + 1.55, 560.0, 1880.0), true)


func _walker(station, id: String):
	for walker in station.walkers():
		if String(walker.get("hero_id", "")) == id:
			return walker
	return null


func _snap(station) -> void:
	station._path.clear()
	station._set_goal(station._goal, true)
	await _frames(1)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		_log("sem janela: " + name)
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	_log("foto " + name)


func _log(text: String) -> void:
	_log_file.store_line("%d ms: %s" % [Time.get_ticks_msec(), text])
	_log_file.flush()


## As regras das falas, carregadas na hora (o código de antes não tem a classe).
func _chatter():
	return load("res://scripts/flow/station_chatter.gd")


func _wants(name: String) -> bool:
	return only == "" or only == name
