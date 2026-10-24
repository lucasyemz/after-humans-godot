## A passagem (#74): o fade, o cartão com o título enquanto a cena seguinte carrega e o fade de volta.
## - Termina sozinha depois de GameFlow.CARD_SECONDS e abre a cena inteira: a de antes sai no preto e a nova monta por
##   baixo do cartão, parada, antes de dar para pular (o cartão cobre o carregamento todo, sem preto travado depois).
## - Pula com Interagir, Esc, clique ou toque, mas só com a cena seguinte carregada.
## - Os títulos: a Estação (o ciclo), a rua (a fase, o lugar e o trecho) e o título; em inglês com tr().
## - "Reduzir efeitos": sem movimento e sem a cena de fundo.
## - O Voltar ao título das Opções da Estação: a passagem chega ao título, a campanha em memória é a salva e o Continuar
##   volta para a Estação.
## - Não grava nada no save do jogador.
extends RefCounted

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var real_files := _snapshot(real_dir)
	Campaign.save_dir = "user://test-passage-%d" % Time.get_ticks_usec()
	Campaign.state = Campaign.create_initial(5)
	var tips: bool = Tips.enabled
	Tips.enabled = false
	_cards()
	await _card_skip()
	await _finishes()
	await _skips()
	await _reduced()
	await _back_to_title()
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
	t.check(_snapshot(real_dir) == real_files, "a passagem não grava nada no save do jogador")


## O que cada cena mostra no cartão.
func _cards() -> void:
	var station := GameFlow.card_for("station")
	t.equal([station.title, station.subtitle], ["Estação Raiz", "Ciclo %d" % Campaign.state.station.cycle_number], "o cartão da Estação: o nome e o ciclo")
	t.check(GameFlow.card_for("street").is_empty(), "sem expedição, a rua não tem cartão")
	AHJourneyRules.start_expedition(Campaign.state, "fase_2", 77)
	var street := GameFlow.card_for("street")
	t.check(street.title == "Ponte das Raízes" and street.subtitle.begins_with("Cais do Rio") and street.subtitle.contains("Trecho 1 de"),
		"o cartão da rua: a fase, o lugar do trecho e o trecho (%s / %s)" % [street.title, street.subtitle])
	# Só a fase da expedição: nenhuma outra (bloqueada ou não) aparece no cartão.
	var others: Array = AHJourneyRules.PHASES.filter(func(p): return p.id != "fase_2" and (street.title + street.subtitle).contains(p.name))
	t.check(others.is_empty(), "o cartão não cita outra fase")
	AHJourneyRules.start_expedition(Campaign.state, "fase_1", 77)
	street = GameFlow.card_for("street")
	t.check(street.title == "Rua das Vitrines" and not street.subtitle.contains("Rua das Vitrines"), "a fase com o nome do lugar não o repete")
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	t.equal(GameFlow.card_for("station").title, "Root Station", "o cartão em inglês")
	TranslationServer.set_locale(locale)
	Campaign.state.session.expedition = null


## O cartão sozinho: as teclas antes de a cena estar pronta não pulam; depois, Interagir, Esc, clique e toque pulam. E
## nenhuma tecla passa para trás dele.
func _card_skip() -> void:
	for kind in ["interact", "menu", "cancel", "click", "touch"]:
		var card := AHPassageCard.new({"title": "Teste", "subtitle": "Sub"})
		_tree.root.add_child(card)
		await _tree.process_frame
		await _push(kind)
		var early := card.skipped
		card.mark_ready()
		await _push(kind)
		t.check(not early and card.skipped, "%s só pula com a cena pronta" % kind)
		card.free()


func _finishes() -> void:
	GameFlow.change_to("title", {}, false)
	await _settle()
	var started := Time.get_ticks_msec()
	GameFlow.travel("station")
	var seen := await _watch()
	t.check(seen.card and seen.title == "Estação Raiz", "a passagem mostra o cartão com o título (%s)" % seen.title)
	t.check(seen.empty_behind, "no cartão, a cena de antes já saiu e a nova só monta por baixo, parada (nada pela metade)")
	t.check(seen.mounted_before_ready, "dá para pular só com a cena nova já montada por baixo do cartão")
	t.check(seen.after_card < 0.5, "depois do cartão, nada de preto travado montando a cena (%.2f s)" % seen.after_card)
	t.check(seen.refused, "outra troca é recusada durante a passagem")
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	t.check(_tree.current_scene != null and _tree.current_scene.name == "Station" and not GameFlow.busy and GameFlow.passage == null,
		"a passagem termina na Estação inteira")
	t.check(elapsed >= GameFlow.CARD_SECONDS, "sem pular, o cartão fica %.1f s (%.2f s)" % [GameFlow.CARD_SECONDS, elapsed])
	# O mínimo conta desde que o cartão abriu, com a montagem dentro: sem pular, o fim fica perto do maior entre o
	# mínimo e o tempo até a cena ficar pronta (mais os fades).
	var expected: float = maxf(GameFlow.CARD_SECONDS, seen.until_ready) + GameFlow.FADE_SECONDS * 3
	t.check(seen.card_time <= expected + 0.6, "o mínimo do cartão inclui a montagem da cena (%.2f s; esperado até %.2f s)" % [seen.card_time, expected])
	t.equal(GameFlow.current_id, "station", "o id da cena atual")
	t.check(not seen.loaded_before_ready, "não dá para pular antes de a cena estar carregada")


func _skips() -> void:
	var started := Time.get_ticks_msec()
	GameFlow.travel("title")
	while GameFlow.passage == null or not GameFlow.passage.ready_to_skip:
		await _tree.process_frame
	await _push("interact")
	while GameFlow.busy:
		await _tree.process_frame
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	t.check(_tree.current_scene is AHTitleScreen, "pulada, a passagem abre o título")
	t.check(elapsed < GameFlow.CARD_SECONDS + GameFlow.FADE_SECONDS * 2, "e termina antes do tempo do cartão (%.2f s)" % elapsed)


## "Reduzir efeitos": o título parado e sem a cena de fundo; sem ele, a cena de fundo num SubViewport.
func _reduced() -> void:
	var moving := AHPassageCard.new({"title": "Teste", "backdrop": Node3D.new()}, false)
	_tree.root.add_child(moving)
	await _tree.process_frame
	var heading: Control = moving.find_child("Title", true, false)
	var band: Control = heading.get_parent().get_parent() if heading != null else null
	t.check(moving.has_node("Backdrop") and moving.get_node("Backdrop").get_child(0).get_child(0) is Node3D, "a cena de fundo entra num SubViewport")
	t.check(band != null and band.modulate.a < 1.0, "sem Reduzir efeitos, o título aparece com movimento")
	moving.free()
	var still := AHPassageCard.new({"title": "Teste", "backdrop": Node3D.new()}, true)
	_tree.root.add_child(still)
	await _tree.process_frame
	var title: Control = still.find_child("Title", true, false)
	t.check(not still.has_node("Backdrop") and still.backdrop == null, "com Reduzir efeitos, sem a cena de fundo")
	t.check(title != null and title.get_parent().get_parent().modulate.a == 1.0, "e o título já parado na tela")
	still.free()
	Campaign.state.settings.reduced_environment_effects = true
	GameFlow.travel("station")
	while GameFlow.passage == null:
		await _tree.process_frame
	t.check(GameFlow.passage.reduced, "a passagem lê Reduzir efeitos das Opções")
	while GameFlow.busy:
		await _tree.process_frame
	Campaign.state.settings.reduced_environment_effects = false


## Da Estação, Opções → Voltar ao título: a passagem chega ao título com a campanha salva igual à da memória, e o
## Continuar volta para a Estação.
func _back_to_title() -> void:
	Campaign.state = Campaign.create_initial(8)
	Campaign.save()
	GameFlow.change_to("station", {}, false)
	await _settle()
	var station = _tree.current_scene
	if not t.check(station != null and station.name == "Station", "a Estação abre"):
		return
	station.hud.open_service("options")
	await _tree.process_frame
	var back: Button = null
	for button in station.hud.find_children("*", "Button", true, false):
		if button.text == "Voltar ao título":
			back = button
	if not t.check(back != null, "as Opções da Estação têm o Voltar ao título"):
		return
	back.pressed.emit()
	await _settle()
	var title = _tree.current_scene
	t.check(title is AHTitleScreen, "o Voltar ao título passa pela passagem e abre o título")
	var disk = Campaign.read_file(Campaign.primary_path())
	var memory = Campaign._normalize(JSON.parse_string(JSON.stringify(Campaign.state)))
	t.check(disk is Dictionary and JSON.stringify(disk, "", true) == JSON.stringify(memory, "", true), "a campanha em memória é a salva")
	if not t.check(title is AHTitleScreen and title.continue_button != null, "o título tem o Continuar"):
		return
	title.continue_button.pressed.emit()
	await _settle()
	t.check(_tree.current_scene != null and _tree.current_scene.name == "Station", "e o Continuar volta para a Estação")


## Acompanha uma passagem até o fim: o que se viu no cartão.
func _watch() -> Dictionary:
	var seen := {"card": false, "title": "", "empty_behind": true, "refused": false, "loaded_before_ready": false,
		"mounted_before_ready": true, "after_card": 0.0, "until_ready": 0.0, "card_time": 0.0}
	var card_open := -1
	var tried := false
	var old: Node = _tree.current_scene
	var card_gone := -1
	while GameFlow.busy:
		await _tree.process_frame
		var card: AHPassageCard = GameFlow.passage
		if card == null:
			if seen.card and card_gone < 0:
				card_gone = Time.get_ticks_msec()
			continue
		seen.card = true
		seen.title = card.title
		if card_open < 0:
			card_open = Time.get_ticks_msec()
		if card.ready_to_skip and seen.until_ready == 0.0:
			seen.until_ready = (Time.get_ticks_msec() - card_open) / 1000.0
		var behind: Node = _tree.current_scene
		if behind != null and (behind == old or behind.can_process()):
			seen.empty_behind = false
		if card.ready_to_skip and behind == null:
			seen.mounted_before_ready = false
		if not tried:
			tried = true
			seen.refused = not await GameFlow.change_to("street", {}, false)
			if not card.ready_to_skip:
				await _push("interact")
				seen.loaded_before_ready = card.skipped
	if card_gone >= 0:
		seen.after_card = (Time.get_ticks_msec() - card_gone) / 1000.0
	if card_open >= 0:
		seen.card_time = (Time.get_ticks_msec() - card_open) / 1000.0
	return seen


func _push(kind: String) -> void:
	var events: Array = []
	match kind:
		"click":
			for pressed in [true, false]:
				var e := InputEventMouseButton.new()
				e.button_index = MOUSE_BUTTON_LEFT
				e.pressed = pressed
				events.append(e)
		"touch":
			for pressed in [true, false]:
				var e := InputEventScreenTouch.new()
				e.pressed = pressed
				events.append(e)
		_:
			for pressed in [true, false]:
				var e := InputEventAction.new()
				e.action = kind
				e.pressed = pressed
				events.append(e)
	for e in events:
		_tree.root.push_input(e)
		await _tree.process_frame


func _settle() -> void:
	for i in 10:
		await _tree.process_frame
	while GameFlow.busy:
		await _tree.process_frame


## Os arquivos de uma pasta com a data de cada um.
func _snapshot(dir: String) -> Dictionary:
	var out := {}
	var path := ProjectSettings.globalize_path(dir)
	if DirAccess.dir_exists_absolute(path):
		for file in DirAccess.get_files_at(path):
			out[file] = FileAccess.get_modified_time(path.path_join(file))
	return out
