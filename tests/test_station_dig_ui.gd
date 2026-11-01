## A Estação em grade, a interface (#186; parte 3, #274): os marcadores dos blocos ("Escavando", "Escavar · N voltas",
## "Vaga livre · Construir" e um "Soterrado" por trecho), o bloco apontado com o cartão, as setas e o clique chegando aos
## blocos, o painel do bloco soterrado (a obra, a frente de escavação, o motivo e o posto de escavador), o painel da vaga
## livre (os cômodos que cabem, o tamanho, o custo, o que falta e CONSTRUIR), o chip curto do relatório, a fala da
## primeira volta (o Bento e o Nick, ou o cartão) e o aviso do achado. E a planta Escavar e construir (#284): um cartão por
## bloco, com a imagem própria, o nome, o estado, a ação e a recompensa, e o vermelho no que depende do vizinho.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const G = preload("res://scripts/flow/station_grid.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-station-dig-ui-%d" % Time.get_ticks_usec()
	Campaign.state = Campaign.create_initial(274)
	# Fora da abertura do tutorial (a visita guiada não disputa a vista geral).
	Campaign.state.tutorial = {"stage": "done"}
	Campaign.state.night.phase = "none"
	_rules()
	var station = await _open()
	if t.check(station != null, "a Estação abriu"):
		await _settle(station)
		await _marks(station)
		await _buried_panel(station)
		await _free_panel(station)
		await _return(station)
		await _board(station)
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Tips.enabled = tips
	Campaign.save_dir = real_dir
	Campaign.state = real_state


## O que o marcador e o painel leem (sem a cena): os estados, os nomes, os cômodos que cabem numa vaga e o chip curto.
func _rules() -> void:
	var c := Campaign.create_initial(2741)
	c.tutorial = {"stage": "done"}
	t.equal(G.dig_target(c), "1:2", "a frente da comunidade: o bloco ao lado da Forja")
	var front := AHRefugeHud.block_info(c, "1:2")
	t.equal([front.state, front.mark], ["front", tr("Escavando · %s") % G.returns_text(2)], "a frente: Escavando · 2 voltas")
	var landing := AHRefugeHud.block_info(c, "L2")
	t.equal([landing.state, landing.mark], ["dig", tr("Escavar · %s") % G.returns_text(3)], "o patamar: Escavar · 3 voltas")
	var deep := AHRefugeHud.block_info(c, "2:4")
	t.equal([deep.state, String(deep.mark)], ["buried", String(tr("Soterrado"))], "o 2º subsolo: soterrado")
	t.equal(deep.note, tr("Primeiro é preciso escavar %s.") % G.block_name("L2"), "o motivo: o patamar primeiro")
	t.equal(AHRefugeHud.block_info(c, "1:1").note, tr("Só dá para escavar ao lado de uma vaga aberta: escave antes um bloco vizinho."),
		"o bloco da ponta: só ao lado de uma vaga aberta")
	t.equal(AHRefugeHud.block_info(c, "L3").note, tr("Primeiro é preciso escavar %s.") % G.block_name("L2"), "o patamar do 3º: o do 2º antes")
	t.equal([AHRefugeHud.block_title("2:5"), AHRefugeHud.block_title("L2")], [tr("%dº subsolo, vaga %d") % [2, 5], tr("Patamar do %dº subsolo") % 2],
		"os nomes dos blocos no título")
	# Uma vaga livre: os cômodos sem lugar, com a vaga da esquerda do duplo e o que falta.
	c.station.grid.cells[0][1] = G.FREE
	var options := AHRefugeHud.build_options(c, "1:2")
	var rooms: Array = options.map(func(o): return o.room)
	t.equal(rooms, [S.CANTEEN, S.BAR, S.DEPOT, S.RESEARCH, S.INFIRMARY], "a vaga livre oferece os cômodos sem lugar, na ordem do menu")
	var by_room := {}
	for option in options:
		by_room[option.room] = option
	t.equal(by_room[S.BAR].spot, "1:2", "o Bar (1 vaga) cabe na própria vaga")
	t.equal(by_room[S.RESEARCH].spot, "", "a Pesquisa (2 vagas) não cabe sozinha na vaga 2")
	t.equal(by_room[S.RESEARCH].block, tr("%s precisa de duas vagas livres lado a lado.") % "O Centro de Pesquisa", "e diz o porquê")
	c.inventory.scrap = 0
	t.check(String(by_room[S.BAR].block).begins_with(tr("Faltam %s.").left(6)), "sem sucata, o Bar diz o que falta (%s)" % by_room[S.BAR].block)
	c.station.grid.cells[0][0] = G.FREE
	t.equal(AHRefugeHud.build_spot(c, S.RESEARCH, "1:2"), "1:1", "com a vaga 1 livre, a Pesquisa entra pela vaga da esquerda")
	t.equal(AHRefugeHud.build_spot(c, S.RESEARCH, "1:1"), "1:1", "e pela própria vaga 1")
	c.inventory.scrap = 20
	c.inventory.fragments = 5
	# Uma vaga simples isolada onde só sobram os duplos: Vaga livre, sem Construir.
	var lone := Campaign.create_initial(2742)
	lone.station.rooms[S.BAR] = 1
	lone.station.rooms[S.DEPOT] = 2
	AHStationGrid.heal(lone)
	lone.station.grid.cells[1][6] = G.FREE
	t.equal(String(AHRefugeHud.block_info(lone, "2:7").mark), String(tr("Vaga livre")), "a vaga isolada sem cômodo que caiba: só Vaga livre")
	var free := AHRefugeHud.block_info(c, "1:1")
	t.equal([free.state, String(free.mark), free.ready], ["free", String(tr("Vaga livre · Construir")), true], "a vaga livre com o que construir agora: acesa")
	# O chip curto do relatório (a linha inteira ia em quatro linhas no cartão estreito).
	t.equal(G.report_chip({"block": "1:2", "opened": true}), tr("Escavação: vaga aberta"), "o chip do bloco aberto")
	t.equal(G.report_chip({"block": "L2", "opened": true}), tr("Escavação: patamar aberto"), "o chip do patamar aberto")
	t.equal(G.report_chip({"block": "1:2", "progress": 1, "work": 2}), tr("Escavação: %d de %d pontos") % [1, 2], "o chip do andamento")
	# A fala da primeira volta: o Bento e o Nick em casa; com um deles caído, só o cartão.
	var lines := AHRefugeHud.intro_lines(c)
	t.equal(lines.map(func(l): return l.speaker.get("id", "")), [G.BENTO, G.NICK, G.BENTO], "a fala: Bento, Nick e Bento")
	S.hero(c, G.NICK).recovery_days = 2
	lines = AHRefugeHud.intro_lines(c)
	t.check(lines.size() == 1 and lines[0].speaker.is_empty() and lines[0].text == G.rule("intro").Card, "com o Nick caído, só o cartão")


## Na vista geral: os marcadores dos blocos, o bloco apontado (a moldura, a etiqueta e o cartão), as setas e o clique.
func _marks(station) -> void:
	var hud: AHRefugeHud = station.hud
	var c: Dictionary = Campaign.state
	t.check(hud._block_rects.has("block:1:2") and hud._block_rects.has("block:1:1"), "os blocos do 1º subsolo na tela")
	var front: PanelContainer = hud._block_marks.get("block:1:2")
	if t.check(front != null and front.visible, "o marcador da frente de escavação"):
		t.equal((front.find_child("Text", true, false) as Label).text, tr("Escavando · %s") % G.returns_text(G.returns_left(c, "1:2")), "diz Escavando e as voltas")
		t.check(hud._block_rects["block:1:2"].has_point(front.get_global_rect().get_center()), "em cima do bloco")
	var landing: PanelContainer = hud._block_marks.get("block:L2")
	t.check(landing != null and String(landing.get_meta("state", "")) == "dig", "o patamar do 2º subsolo: Escavar")
	# Um "Soterrado" por trecho: o 2º subsolo inteiro é um trecho só.
	var floor_two: Array = hud._block_marks.keys().filter(func(id): return String(id).begins_with("run:2:"))
	t.equal(floor_two.size(), 1, "o 2º subsolo soterrado tem um marcador só (%s)" % [hud._block_marks.keys()])
	t.check(hud._block_marks.has("run:1:1"), "e a ponta do 1º subsolo, o dela")
	# As setas chegam aos blocos: da Forja para a esquerda, o bloco ao lado.
	hud._key_room = S.FORGE
	hud._last_mouse = hud.get_viewport().get_mouse_position()
	hud._step_room(Vector2.LEFT)
	t.equal(hud._key_room, "block:1:2", "a seta para a esquerda da Forja escolhe o bloco ao lado")
	await _settle(station)
	t.equal(hud._hover_room, "block:1:2", "o bloco escolhido fica apontado")
	var note := hud._room_card.find_child("BlockNote", true, false) as Label
	t.check(hud._room_card.visible and note != null and note.text == hud.block_info(c, "1:2").note, "o cartão do bloco diz o resumo")
	t.equal(hud._room_tag_label.text, tr("Escavando"), "a etiqueta do bloco apontado")
	t.check(not front.visible, "o marcador do bloco apontado sai (o cartão diz o resto)")
	# Interagir abre o painel do bloco.
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	hud._input(press)
	await _frames(3)
	t.equal(hud.current, "block:1:2", "Interagir abre o bloco escolhido")
	hud.close_panel()
	await _settle(station)
	# O clique abre o bloco.
	hud._key_room = ""
	var rect: Rect2 = hud._block_rects.get("block:L2", Rect2())
	hud._unhandled_input(_click(rect.get_center(), true))
	hud._input(_click(rect.get_center(), false))
	await _frames(3)
	t.equal(hud.current, "block:L2", "o clique abre o patamar")
	hud.close_panel()
	await _settle(station)


## O painel do bloco soterrado: a obra, a frente, escavar este bloco, o posto de escavador e o motivo.
func _buried_panel(station) -> void:
	var hud: AHRefugeHud = station.hud
	var c: Dictionary = Campaign.state
	hud.open_room("block:1:2")
	await _frames(3)
	t.check(hud._body.find_child("Work", true, false) is AHKitBar, "a obra numa barra")
	t.check(hud._body.find_child("Front", true, false) != null and hud._body.find_child("DigHere", true, false) == null,
		"a frente: sem o botão de escavar este bloco")
	t.check(hud._body.find_child("Workers", true, false) != null, "e quem cava (o posto de escavador)")
	# O vizinho direto (PageUp e PageDown): do bloco para a Forja, e da Forja de volta para o bloco.
	t.equal(hud.neighbor_place("block:1:2", 1), S.FORGE, "o vizinho à direita do bloco é a Forja")
	t.equal(hud.neighbor_place(S.FORGE, -1), "block:1:2", "e o da Forja à esquerda, o bloco")
	hud.open_room("block:L2")
	await _frames(3)
	var dig := hud._body.find_child("DigHere", true, false) as Button
	if t.check(dig != null and not dig.disabled, "o patamar: ESCAVAR ESTE BLOCO"):
		dig.pressed.emit()
		await _frames(3)
		t.equal(G.dig_target(c), "L2", "e ele vira a frente")
		t.check(hud._body.find_child("Front", true, false) != null, "o painel refeito diz que é a frente")
	var nick: Dictionary = S.hero(c, G.NICK)
	var chip := hud._body.find_child("Worker_%s" % nick.id, true, false) as Button
	if t.check(chip != null, "o Nick pode cavar"):
		chip.pressed.emit()
		await _frames(3)
		t.equal(S.post_of(nick), G.DIG, "e fica no posto de escavador")
		t.equal(G.dig_rate(c), G.community_work() + S.post_yield(nick, G.DIG), "o ritmo soma o dele")
	hud.open_room("block:2:3")
	await _frames(3)
	var why := hud._body.find_child("Why", true, false) as Label
	t.check(why != null and why.text == hud.dig_reason(c, "2:3") and hud._body.find_child("DigHere", true, false) == null,
		"o 2º subsolo ainda fechado: o motivo, sem escavar")
	S.set_post(c, nick.id, "")
	G.set_dig_target(c, "")
	hud.close_panel()
	await _settle(station)


## A vaga livre: os cômodos que cabem, o tamanho, o custo e CONSTRUIR; o que não cabe diz o porquê.
func _free_panel(station) -> void:
	var hud: AHRefugeHud = station.hud
	var c: Dictionary = Campaign.state
	c.station.grid.cells[0][1] = G.FREE
	c.inventory.scrap = 20
	c.inventory.fragments = 5
	station.commit()
	await _settle(station)
	var mark: PanelContainer = hud._block_marks.get("block:1:2")
	t.check(mark != null and (mark.find_child("Text", true, false) as Label).text == tr("Vaga livre · Construir"), "a vaga livre: Vaga livre · Construir")
	hud.open_room("block:1:2")
	await _frames(3)
	t.check(hud._body.find_child("Option_%s" % S.BAR, true, false) != null and hud._body.find_child("Option_%s" % S.RESEARCH, true, false) != null,
		"o painel lista os cômodos sem lugar")
	var research := hud._body.find_child("Build_%s" % S.RESEARCH, true, false) as Button
	t.check(research != null and research.disabled, "a Pesquisa (duas vagas) não cabe: CONSTRUIR apagado")
	var bar := hud._body.find_child("Build_%s" % S.BAR, true, false) as Button
	if t.check(bar != null and not bar.disabled, "o Bar cabe e dá para pagar"):
		var scrap := S.quantity(c, "scrap")
		bar.pressed.emit()
		await _frames(3)
		t.equal(G.cell(c, 1, 2), S.BAR, "construído na vaga 2 do 1º subsolo")
		t.equal(S.quantity(c, "scrap"), scrap - int(S.room_costs(S.room_def(S.BAR))[0].scrap), "e cobrado")
		t.equal(hud.current, S.BAR, "o painel passa para o Bar")
	hud.close_panel()
	await _settle(station)
	t.check(not hud._block_marks.has("block:1:2") and station.room_def(S.BAR).size() > 0, "a vaga virou o Bar na cena")


## A volta: a fala da primeira escavação (uma vez) e o aviso do bloco aberto (uma vez).
func _return(station) -> void:
	var hud: AHRefugeHud = station.hud
	var c: Dictionary = Campaign.state
	S.hero(c, G.NICK).recovery_days = 0
	c.station.grid.intro_seen = false
	c.station.last_return = {"seen": false, "team": [], "dig": {"block": "1:1", "points": 2, "work": 2, "progress": 2, "opened": true,
		"finds": {"scrap": 2, "seeds": 0, "fragments": 0, "bandages": 0, "tool": "", "relic": "", "texts": [G.rule("floor_1").Text]}}}
	hud._enter_shelter_then(Callable())
	await _frames(3)
	t.check(hud.briefing_open(), "a primeira volta com escavação abre a fala")
	t.check(not G.grid(c).intro_seen, "a fala só fica vista depois de passar (fechar o jogo no meio a repete)")
	t.check(not hud.dig_notice_shown(), "o aviso espera a fala")
	if hud.briefing != null:
		hud.briefing.skip()
	await _frames(3)
	t.check(G.grid(c).intro_seen, "passada a fala, ela fica vista")
	t.check(not hud.briefing_open() and hud.dig_notice_shown(), "fechada a fala, o aviso do achado na vista geral")
	t.check(c.station.last_return.dig.get("noticed", false), "visto depois de um quadro na tela")
	if hud.dig_notice_shown():
		var texts: Array = hud._dig_notice.find_children("*", "Label", true, false).map(func(l): return l.text)
		t.check(texts.has(tr("%s: vaga livre") % hud.block_title("1:1")) and texts.has(tr(G.rule("floor_1").Text)), "com o bloco e o achado (%s)" % [texts])
		t.check(texts.has(tr("Entrou no estoque: %s.") % G.finds_text(c.station.last_return.dig.finds)), "e o que entrou no estoque")
		var notice: Rect2 = hud._dig_notice.get_global_rect()
		t.check(notice.position.x >= hud.LEFT.end.x and notice.end.x <= hud.RIGHT.position.x, "entre a coluna da esquerda e o painel (%s)" % notice)
	# Sai com qualquer tecla (como o aviso da ferramenta nova, #143).
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	hud._input(key)
	t.check(not hud.dig_notice_shown(), "uma tecla tira o aviso")
	hud._enter_shelter_then(Callable())
	await _frames(3)
	t.check(not hud.briefing_open() and not hud.dig_notice_shown(), "na segunda vez, nem a fala nem o aviso")
	# O aviso que some no mesmo quadro em que nasce (a Sala indo ao mapa) não fica gasto: volta na vista geral.
	c.station.last_return.dig.noticed = false
	hud.show_dig_notice()
	hud.open_room(S.BAR)
	await _frames(2)
	t.check(not hud.dig_notice_shown() and not c.station.last_return.dig.get("noticed", false), "com o painel aberto, o aviso sai sem ficar visto")
	hud.close_panel()
	await _frames(2)
	t.check(hud.dig_notice_shown(), "e aparece de volta na vista geral")
	hud.hide_dig_notice()
	hud.close_panel()


## A planta (#284): a aba Escavação abre os três andares em cartões; cada bloco com a sua imagem; o que dá para escavar
## mostra a ação e a recompensa e vira a frente pelo botão grande; o que depende do vizinho fica em vermelho.
func _board(station) -> void:
	var hud: AHRefugeHud = station.hud
	var looks: Dictionary = G.rule("block_looks").get("Blocks", {})
	t.equal(looks.keys().size(), G.block_keys().size(), "cada bloco tem o seu nome e a sua imagem")
	var pairs := {}
	for key in looks:
		var entry: Dictionary = looks[key]
		pairs["%s+%s" % [entry.Art, entry.Ground]] = true
		t.check(ResourceLoader.exists(AHDigBoard.SCENARIOS % entry.Art) and ResourceLoader.exists(AHDigBoard.SCENARIOS % entry.Ground), "%s: as peças existem" % key)
	t.equal(pairs.size(), looks.size(), "nenhum bloco repete a imagem de outro")
	var c: Dictionary = Campaign.state
	c.station.grid.landings[0] = false
	c.station.grid.target = ""
	var tab: Button = hud._frame.find_child("Nav_dig", true, false)
	if not t.check(tab != null, "a aba Escavação"):
		return
	tab.pressed.emit()
	await _frames(4)
	var board: AHDigBoard = hud._dig_board
	if not t.check(board != null and hud.current == "dig", "a aba abre Escavar e construir"):
		return
	for floor_number in [1, 2, 3]:
		t.check(board.find_child("Floor_%d" % floor_number, true, false) != null, "o %dº subsolo em cartões" % floor_number)
	var deep: Button = board.find_child("Block_2_4", true, false)
	t.check(deep != null and deep.get_meta("state", "") == "buried", "o 2º subsolo, preso ao patamar")
	var alert: Label = deep.find_child("Alert", true, false) if deep else null
	t.check(alert != null and alert.text == tr("Depende da escada"), "em vermelho, o motivo curto (%s)" % (alert.text if alert else ""))
	t.check(deep != null and deep.find_child("Name", true, false).text == tr(String(looks["2:4"].Name)), "o nome do que está no bloco")
	var landing: Button = board.find_child("Block_L2", true, false)
	t.check(landing != null and landing.get_meta("state", "") == "dig", "o patamar dá para escavar")
	var reward: Label = landing.find_child("Reward", true, false) if landing else null
	t.check(reward != null and reward.text.begins_with(tr("Recompensa: %s e um achado").get_slice("%", 0)), "com a recompensa à vista")
	landing.pressed.emit()
	await _frames(3)
	var action: Button = hud._dig_board.find_child("BigAction", true, false)
	t.check(action != null and not action.disabled, "escolhido, o botão grande escava")
	action.pressed.emit()
	await _frames(3)
	t.equal(G.dig_target(Campaign.state), "L2", "e o patamar vira a frente")
	deep = hud._dig_board.find_child("Block_2_4", true, false)
	deep.pressed.emit()
	await _frames(3)
	action = hud._dig_board.find_child("BigAction", true, false)
	var note: Label = hud._dig_board.find_child("Note", true, false)
	t.check(action != null and action.disabled and note != null and note.text == tr("Escave a escada deste andar para liberar"),
		"o bloco preso não escava, com o motivo inteiro embaixo")
	var details: Button = hud._dig_board.find_child("Details", true, false)
	details.pressed.emit()
	await _frames(3)
	t.equal(hud.current, AHRefugeHud.block_place("2:4"), "Detalhes abre o painel do bloco")
	t.check(hud._dig_board == null, "e a planta fecha")
	hud.close_panel()
	await _frames(3)


func _click(at: Vector2, down: bool) -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = down
	click.position = at
	return click


func _open():
	GameFlow.change_to("station", {}, false)
	for frame in 300:
		await _tree.process_frame
		var scene := _tree.current_scene
		if not GameFlow.busy and scene is AHStation and scene.hud != null:
			await _tree.process_frame
			return scene
	return null


func _settle(station) -> void:
	for i in 600:
		await _tree.process_frame
		if station.camera_settled() and not station.passage_moving() and i > 4:
			break
	await _frames(3)


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
