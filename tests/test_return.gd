## A volta à Estação (#76): o trem chega com a equipe, os vivos descem e andam até a fila do relatório (quem está
## ferido, mais devagar; os mortos não descem), o relatório abre e, ao concluir, a vista geral com o descanso pendente.
## - Pular (Interagir, Esc, clique, toque) leva direto ao relatório, com todos na fila; nada abre por trás.
## - Sem ninguém vivo, o trem chega vazio e o relatório abre do mesmo jeito.
## - O jogo fechado no meio da chegada: reaberto, a chegada começa de novo e a Estação não trava.
## - Depois do relatório: Preparar expedição bloqueado com o motivo até a noite passar; depois, liberado.
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	# O briefing e o debriefing (#88) têm o teste deles; aqui, fora do caminho.
	var briefing: bool = AHBriefing.enabled
	AHBriefing.enabled = false
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-return-%d" % Time.get_ticks_usec()
	var tips: bool = Tips.enabled
	Tips.enabled = false
	await _walk_and_wounded()
	await _after_card()
	for kind in ["interact", "menu", "click", "touch"]:
		await _skip(kind)
	await _tip_open()
	await _double_skip()
	await _nobody_back()
	await _reopen_mid_arrival()
	await _esc_report()
	await _rest_unlocks()
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
	AHBriefing.enabled = briefing


## Uma volta de vitória com a equipe dos quatro fundadores: hurt fica ferido, dead caiu.
func _returned(hurt: Array = [], dead: Array = []) -> Dictionary:
	var c: Dictionary = Campaign.create_initial(17)
	var team: Array = c.roster.slice(0, 4).map(func(h): return h.id)
	AHJourneyRules.start_expedition(c, "fase_1", 17)
	c.session.expedition.team = team
	for id in hurt:
		var h = S.hero(c, id)
		h.hp = maxi(1, int(h.max_hp) / 3)
	for id in dead:
		S.hero(c, id).alive = false
	c.session.result = "victory"
	S.finish_return(c)
	return c


func _open(c: Dictionary) -> AHStation:
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("station", {}, false)
	for i in 600:
		await _tree.process_frame
		var scene := _tree.current_scene
		if scene is AHStation and scene.hud != null and not GameFlow.busy and i > 3:
			return scene
	return null


func _walk_and_wounded() -> void:
	var c := _returned()
	var team: Array = c.station.last_return.team
	c = _returned([team[1]], [team[3]])
	var station := await _open(c)
	if not t.check(station != null, "a Estação abre na volta"):
		return
	var hud: AHRefugeHud = station.hud
	t.equal(hud.current, AHRefugeHud.ARRIVAL, "a volta começa com a chegada de trem")
	t.check(station.team_arriving() and not hud._panel.visible and not hud._menu.visible, "na chegada, nenhum painel nem menu por cima")
	# Esc na chegada não abre nada (o menu, um cômodo): só pula.
	var heroes: Array = c.station.last_return.team
	var alive: Array = heroes.filter(func(id): return S.hero(c, id).alive)
	# Na descida, quem desce depois fica sempre à esquerda de quem desceu antes (ninguém atravessa ninguém).
	var crossed := false
	var limit := Time.get_ticks_msec() + 30000
	while station.team_arriving() and Time.get_ticks_msec() < limit:
		var xs: Array = station.lineup.filter(func(e): return is_instance_valid(e.card)).map(func(e): return e.card.position.x)
		if not _descending(xs):
			crossed = true
		if station.lineup.size() == alive.size() and station._arrivals.all(func(a): return is_instance_valid(a.card) and absf(a.card.position.x - a.slot.x) < 0.02):
			break
		await _tree.process_frame
	t.check(not crossed, "na descida, ninguém atravessa quem já está na fila")
	var down: Array = station.lineup.map(func(e): return e.hero_id)
	down.sort()
	var want: Array = alive.duplicate()
	want.sort()
	t.equal(down, want, "só os vivos descem do trem")
	# Desce primeiro quem vai para o lugar mais longe da porta: ninguém atravessa quem já parou.
	var slots: Array = station._arrivals.map(func(a): return a.slot.x)
	t.check(_descending(slots), "a ordem de descida vai do lugar mais longe ao mais perto (%s)" % [slots])
	# O ferido anda mais devagar.
	var pace := {}
	for arrival in station._arrivals:
		pace[arrival.hero_id] = arrival.speed
	t.check(pace[heroes[1]] < pace[heroes[0]], "quem está ferido anda mais devagar (%.2f contra %.2f m/s)" % [pace[heroes[1]], pace[heroes[0]]])
	t.check(await _until(func(): return hud.current == "report", 30.0), "sem pular, o relatório abre com todos na fila")
	# A fila na ordem da formação (#131): a posição 1 (a frente) à direita, como na Preparação e na luta.
	t.equal(station.lineup.map(func(e): return e.hero_id), AHStationReport.scene_order(alive), "a fila do relatório é a de quem desceu, na ordem da formação")
	var xs: Array = station.lineup.map(func(e): return e.card.position.x)
	t.check(xs[xs.size() - 1] == xs.max() and station.lineup[-1].hero_id == heroes[0], "a posição 1 fica à direita (%s)" % [xs])
	var cards: Dictionary = hud._report_screen.card_centers() if is_instance_valid(hud._report_screen) else {}
	t.check(not cards.is_empty() and cards[heroes[0]] > cards[heroes[1]], "e a carta dela também")
	# Concluído o relatório, a fila sai andando (#131): ninguém aparece no cômodo antes de sair da câmera.
	var leaving_ids: Array = station.lineup.map(func(e): return e.hero_id)
	hud._enter_shelter_then(Callable())
	await _frames(2)
	t.check(station.lineup_leaving() and station.lineup.is_empty(), "a fila sai andando, em vez de sumir")
	t.check(leaving_ids.all(func(id): return not station.residents.has(id) or not station.residents[id].visible), "quem está saindo ainda não aparece no cômodo")
	var first: Dictionary = station._leaving[0]
	t.equal(first.hero_id, heroes[0], "a frente sai primeiro")
	var start_x: float = first.card.position.x
	await _frames(20)
	t.check(not is_instance_valid(first.card) or first.card.position.x > start_x, "andando para a direita, para a porta")
	# A Sala aberta e fechada no meio da saída não traz ninguém para o cômodo antes da hora.
	hud.open_room(S.CHARACTERS)
	await _frames(3)
	hud.close_panel()
	await _frames(3)
	var early: Array = station._leaving.map(func(e): return e.hero_id).filter(func(id): return station.residents.has(id) and station.residents[id].visible)
	t.equal(early, [], "fechando a Sala no meio da saída, quem anda na plataforma não aparece no cômodo")
	t.check(await _until(func(): return not station.lineup_leaving(), 20.0), "e todos saem da plataforma")
	t.check(leaving_ids.all(func(id): return not station.residents.has(id) or station.residents[id].visible), "fora da câmera, cada um volta ao seu cômodo")


func _descending(values: Array) -> bool:
	for i in range(1, values.size()):
		if values[i] > values[i - 1]:
			return false
	return true


## Pela passagem de verdade (GameFlow.travel): a chegada (e o som do trem) só começa com o cartão fora da tela.
func _after_card() -> void:
	Campaign.state = _returned()
	Campaign.save()
	GameFlow.change_to("title", {}, false)
	await _frames(10)
	GameFlow.travel("station")
	var early := false
	while GameFlow.busy:
		await _tree.process_frame
		var scene := _tree.current_scene
		if scene is AHStation and scene.team_arriving():
			early = true
	t.check(not early, "a chegada não começa embaixo do cartão da passagem")
	await _frames(3)
	var station := _tree.current_scene as AHStation
	t.check(station != null and station.team_arriving(), "e começa assim que a Estação aparece")


func _skip(kind: String) -> void:
	var station := await _open(_returned())
	if not t.check(station != null, "a Estação abre (%s)" % kind):
		return
	var hud: AHRefugeHud = station.hud
	await _frames(5)
	t.check(station.team_arriving(), "a chegada em andamento (%s)" % kind)
	await _push(kind)
	await _frames(3)
	t.check(hud.current == "report" and not station.team_arriving(), "%s pula a chegada e abre o relatório" % kind)
	t.equal(station.lineup.size(), 4, "com a equipe inteira na fila (%s)" % kind)
	t.check(hud.find_children("*", "Button", true, false).any(func(b): return b.text.to_lower() == tr("Entrar no abrigo").to_lower() and b.is_visible_in_tree()),
		"o relatório completo, com Entrar no abrigo (%s)" % kind)


## Interagir (ou Enter, ou Esc) duas vezes para pular a chegada: o segundo não conclui nem fecha o relatório.
func _double_skip() -> void:
	for action in ["interact", "ui_accept", "menu"]:
		var station := await _open(_returned())
		if station == null:
			return
		await _frames(5)
		await _push(action)
		await _frames(4)
		await _push(action)
		await _frames(4)
		t.check(station.hud.current == "report" and not Campaign.state.station.last_return.get("seen", false),
			"%s duas vezes pula a chegada e o relatório fica aberto, por ver" % action)
		# Passada a carência, o relatório responde normalmente: Interagir no botão com foco conclui o relatório.
		await _until(func(): return false, AHRefugeHud.REPORT_GUARD_MS / 1000.0 + 0.1)
		if action == "interact":
			await _push("interact")
			await _frames(4)
			t.check(Campaign.state.station.last_return.get("seen", false) and station.hud.current == "",
				"passada a carência, Interagir conclui o relatório")


## Uma dica da primeira vez aberta durante a chegada (a boss_down vem da rua): Esc e Voltar não derrubam a chegada,
## o relatório abre e ninguém some dos cômodos.
func _tip_open() -> void:
	var station := await _open(_returned())
	if station == null:
		return
	var hud: AHRefugeHud = station.hud
	await _frames(5)
	Tips.enabled = true
	Tips._seen.erase("boss_down")
	Tips.show_tip("boss_down")
	await _frames(3)
	for action in ["cancel", "ui_cancel", "menu"]:
		await _push(action)
	await _frames(2)
	t.check(Tips.showing() and hud.current == AHRefugeHud.ARRIVAL, "com a dica aberta, Esc e Voltar não mexem na chegada")
	await _push("interact")
	await _frames(2)
	t.check(not Tips.showing() and hud.current == AHRefugeHud.ARRIVAL, "Interagir fecha a dica sem pular a chegada")
	Tips.enabled = false
	t.check(await _until(func(): return hud.current == "report", 30.0), "e o relatório abre")
	hud._enter_shelter_then(Callable())
	await _until(func(): return not station.lineup_leaving(), 20.0)
	await _frames(3)
	var hidden: Array = station.residents.keys().filter(func(id): return not station.residents[id].visible)
	t.equal(hidden, [], "ninguém some dos cômodos")


func _nobody_back() -> void:
	var c := _returned()
	var team: Array = c.station.last_return.team
	c = _returned([], team)
	var station := await _open(c)
	if not t.check(station != null, "a Estação abre com a equipe toda caída"):
		return
	t.check(await _until(func(): return station.hud.current == "report", 30.0), "com a equipe toda caída, o relatório abre")
	# Ninguém morre (#118): a equipe caída desce do trem, devagar, e vai para a recuperação.
	t.equal(station.lineup.size(), team.size(), "quem caiu desce do trem")
	t.check(station._arrivals.all(func(a): return a.hurt), "e desce no passo de ferido")


## O jogo fecha no meio da chegada: o save tem o relatório não visto; reaberto, a chegada começa de novo.
func _reopen_mid_arrival() -> void:
	var station := await _open(_returned())
	if station == null:
		return
	await _frames(20)
	var disk = Campaign.read_file(Campaign.primary_path())
	t.check(disk is Dictionary and not disk.station.last_return.is_empty() and not disk.station.last_return.get("seen", false), "o save do meio da chegada tem o relatório por ver")
	_tree.unload_current_scene()
	await _frames(2)
	station = await _open(disk)
	if not t.check(station != null and station.hud.current == AHRefugeHud.ARRIVAL, "reaberto no meio, a chegada começa de novo"):
		return
	t.check(await _until(func(): return station.hud.current == "report", 30.0), "e chega ao relatório (a Estação não trava)")


## Voltar (Esc) no relatório conclui como Entrar no abrigo (#131): a fila sai andando e o relatório fica visto.
func _esc_report() -> void:
	var station := await _open(_returned())
	if station == null:
		return
	var hud: AHRefugeHud = station.hud
	station.finish_team_arrival()
	await _until(func(): return hud.current == "report", 5.0)
	await _until(func(): return false, AHRefugeHud.REPORT_GUARD_MS / 1000.0 + 0.1)
	var back := InputEventAction.new()
	back.action = "ui_cancel"
	back.pressed = true
	hud._unhandled_input(back)
	await _frames(2)
	t.check(Campaign.state.station.last_return.get("seen", false), "Voltar no relatório deixa o relatório visto")
	t.check(station.lineup_leaving() and station.lineup.is_empty(), "e a fila sai andando, em vez de sumir")
	# Uma chegada nova no meio da saída: quem saía sai de vez, sem carta velha junto da fila nova.
	var old: Array = station._leaving.map(func(e): return e.card)
	station.play_team_arrival(Campaign.state.station.last_return.team)
	t.check(not station.lineup_leaving() and old.all(func(card): return not is_instance_valid(card) or card.is_queued_for_deletion()), "uma chegada nova no meio da saída tira a fila velha")
	station.finish_team_arrival()


## Depois do relatório: a vista geral, Preparar expedição bloqueado com o motivo; passada a noite, liberado.
func _rest_unlocks() -> void:
	var station := await _open(_returned())
	if station == null:
		return
	var hud: AHRefugeHud = station.hud
	station.finish_team_arrival()
	await _until(func(): return hud.current == "report", 5.0)
	hud._enter_shelter_then(Callable())
	# A fila sai andando (#131) e só então a câmera desce à vista geral.
	await _until(func(): return not station.on_platform, 10.0)
	t.equal(hud.current, "", "concluído o relatório, a vista geral")
	var blocked: Button = hud.find_child("PrepareBlocked", true, false)
	t.check(blocked != null and blocked.disabled, "Preparar expedição bloqueado com a noite pendente")
	t.equal(blocked.tooltip_text if blocked != null else "", S.preparation_block(Campaign.state), "com o motivo")
	t.equal(hud._next.get("action", ""), "dormitory", "o Próximo passo é dormir")
	# O Dormitório em destaque, à direita do menu (a vista geral enquadra a Estação depois dele) e com a etiqueta sem
	# cobrir nenhum botão, também com o texto Maior.
	for size in [0, 2]:
		Settings.set_text_size(size)
		hud.refresh()
		await _until(func(): return hud._rest_tag.visible and not station.on_platform and not station.passage_moving() and station.camera_settled(), 15.0)
		await _frames(30)
		var menu: Rect2 = hud._menu.get_global_rect()
		var tag: Rect2 = hud._rest_tag.get_global_rect()
		var dorm: Rect2 = hud._room_rects.get(S.DORMITORY, Rect2())
		t.check(hud._rest_tag.visible and not tag.intersects(menu), "a etiqueta do Dormitório fora do menu (texto %d: %s, menu %s)" % [size, tag, menu])
		t.check(dorm.position.x >= menu.end.x - 1.0, "o Dormitório inteiro à direita do menu (texto %d: %s)" % [size, dorm])
	Settings.set_text_size(0)
	# Reaberto com o relatório visto e a noite pendente: a mesma vista geral (não o painel do Dormitório).
	var saved = Campaign.read_file(Campaign.primary_path())
	_tree.unload_current_scene()
	await _frames(2)
	var again := await _open(saved)
	if again != null:
		await _frames(3)
		t.check(again.hud.current == "" and again.hud.find_child("PrepareBlocked", true, false) != null, "reaberto com a noite pendente, a vista geral com o bloqueio")
		station = again
		hud = again.hud
	# A noite passa (e o candidato do trem, que também segura a partida, já foi decidido): o bloqueio sai.
	Campaign.state.night.phase = "none"
	Campaign.state.station.train.phase = "none"
	hud.refresh()
	await _frames(2)
	t.check(hud.find_child("PrepareBlocked", true, false) == null, "passada a noite, Preparar expedição libera")


func _push(kind: String) -> void:
	var events: Array = []
	for pressed in [true, false]:
		var e: InputEvent
		match kind:
			"click":
				e = InputEventMouseButton.new()
				e.button_index = MOUSE_BUTTON_LEFT
			"touch":
				e = InputEventScreenTouch.new()
			_:
				e = InputEventAction.new()
				e.action = kind
		e.pressed = pressed
		events.append(e)
	for e in events:
		_tree.root.push_input(e)
		await _tree.process_frame


func _until(condition: Callable, seconds: float) -> bool:
	var limit := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > limit:
			return false
		await _tree.process_frame
	return true


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
