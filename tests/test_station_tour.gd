## A visita guiada da Estação (#145):
## - abre só na primeira vez, depois da abertura (#144) e do relatório dela; quem pula o tutorial não a vê;
## - cada passo espera a ação certa (o PRÓXIMO, abrir o cômodo, abrir a Sala, fechar o painel), que Interagir também faz;
## - o destaque está na parte certa da tela;
## - fechar o jogo no meio retoma do passo; pular encerra e não volta;
## - no fim a Estação responde de novo (nenhum passo a deixa travada) e a abertura termina.
extends RefCounted

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var real_seen: Dictionary = Tips._seen.duplicate()
	Campaign.save_dir = "user://test-station-tour-%d" % Time.get_ticks_usec()
	_rules()
	await _walk()
	await _skip()
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state
	Tips._seen = real_seen


func _rules() -> void:
	var skipped := Campaign.create_initial(41)
	AHTutorial.skip(skipped)
	t.check(not AHStationTour.pending(skipped), "quem pula o tutorial não vê a visita")
	t.equal(AHTutorial.stage(skipped), "done", "e a abertura fica terminada")
	var played := _after_opening(42)
	t.check(AHStationTour.pending(played), "depois da abertura jogada, a visita espera")
	t.check(AHTutorial.suppresses_tips(played), "com as dicas de primeira vez da Estação caladas")
	t.check(not AHStationTour.pending(Campaign.create_initial(43)), "um save sem a marca (de antes do tutorial) não abre a visita")


## A campanha no ponto da chegada da abertura, com o relatório já visto.
func _after_opening(seed_value: int) -> Dictionary:
	var c := Campaign.create_initial(seed_value)
	AHTutorial.begin(c)
	AHTutorial.join(c)
	AHTutorial.complete(c)
	c.station.last_return.seen = true
	return c


func _walk() -> void:
	Campaign.state = _after_opening(44)
	Campaign.save()
	var station = await _open()
	if not t.check(station != null and station.hud.tour != null, "a visita abre na primeira vez"):
		return
	var hud: AHRefugeHud = station.hud
	var tour: AHStationTour = hud.tour
	var ids: Array = AHTutorial.tour_steps().map(func(s): return s.Id)
	t.equal(ids[0], "overview", "o primeiro passo é a visão geral")
	await _frames(3)
	t.check(hud.tour_rect("overview").has_area() and tour._hint._frame.visible, "com o destaque nos cômodos")
	# Os três primeiros seguem pelo PRÓXIMO (Interagir); o clique num cômodo não passa.
	for i in 3:
		t.equal(tour.waiting_for(), "next", "o passo %s segue pelo Próximo" % ids[i])
		t.check(hud.tour_rect(String(AHTutorial.tour_steps()[i].Target)).has_area(), "o destaque do passo %s está na tela" % ids[i])
		await _action("interact")
	t.equal(tour.index, 3, "três passos vistos")
	# Fechar no meio: o save retoma do mesmo passo.
	var saved = Campaign.read_file(Campaign.primary_path())
	t.equal(int(saved.tutorial.get("tour", 0)), 3, "o passo da visita fica gravado")
	Campaign.state = saved
	station = await _open()
	if not t.check(station != null and station.hud.tour != null, "reaberta, a visita continua"):
		return
	hud = station.hud
	tour = hud.tour
	t.equal(tour.index, 3, "do mesmo passo")
	# O cômodo do próximo passo: o PRÓXIMO não aparece, e só abrir o cômodo segue.
	var room := tour.next_room()
	t.equal(tour.waiting_for(), "room:" + room, "o passo do cômodo espera abrir %s" % room)
	t.check(not tour._next.visible, "sem o Próximo: a ação segue")
	hud.open_room(AHStationRules.DORMITORY if room != AHStationRules.DORMITORY else AHStationRules.FORGE)
	await _frames(2)
	t.equal(tour.index, 3, "abrir outro cômodo não segue")
	hud.close_panel()
	await _frames(2)
	await _action("interact")
	await _frames(2)
	t.equal(hud.current, room, "Interagir abre o cômodo destacado")
	t.equal(tour.index, 4, "e a visita segue")
	await _action("ui_cancel")
	await _frames(2)
	t.check(hud.current == "" and tour.index == 5, "Voltar fecha o painel no passo de fechar")
	hud._nav("characters")
	await _frames(3)
	t.check(hud.current == AHStationRules.CHARACTERS and tour.index == 6, "a Sala aberta segue para o passo de dentro dela")
	hud.close_panel()
	await _frames(3)
	t.equal(tour.index, 7, "fechada a Sala, o Dormitório")
	await _action("interact")
	t.equal(tour._next.text, tr("Começar").to_upper(), "o último passo começa o jogo")
	await _action("interact")
	await _frames(2)
	t.check(hud.tour == null and AHTutorial.stage(Campaign.state) == "done", "no fim, a visita fecha e a abertura termina")
	t.check(Tips.seen("station"), "as dicas da Estação contam como vistas")
	hud.open_room(AHStationRules.FORGE)
	await _frames(2)
	t.equal(hud.current, AHStationRules.FORGE, "e a Estação responde de novo")
	hud.close_panel()
	station = await _open()
	t.check(station != null and station.hud.tour == null, "a visita não abre de novo")


func _skip() -> void:
	Campaign.state = _after_opening(45)
	Campaign.save()
	var station = await _open()
	if not t.check(station != null and station.hud.tour != null, "a visita abre"):
		return
	station.hud.tour._skip.pressed.emit()
	await _frames(2)
	t.check(station.hud.tour == null and AHTutorial.stage(Campaign.state) == "done", "Pular visita encerra")
	var saved = Campaign.read_file(Campaign.primary_path())
	t.check(saved != null and AHTutorial.stage(saved) == "done", "e grava")
	station = await _open()
	t.check(station != null and station.hud.tour == null, "e não volta")


func _open():
	GameFlow.change_to("station", {}, false)
	for frame in 300:
		await _tree.process_frame
		var scene := _tree.current_scene
		if not GameFlow.busy and scene is AHStation and scene.hud != null:
			await _frames(3)
			return scene
	return null


func _action(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
