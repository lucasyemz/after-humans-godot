## HUD da Estação Raiz no kit (#60, docs/design/hud-estacao.md): a moldura das telas da Estação (AHStationFrame: a
## plaqueta e os recursos no alto, VOLTAR, as teclas, as abas e PREPARAR EXPEDIÇÃO embaixo), a coluna da esquerda (o
## PRÓXIMO PASSO, o Plano da Estação e as PENDÊNCIAS) e, à direita, o painel do cômodo (o ícone, o nome, o estado num
## chip, o X e o conteúdo, que rola no texto Maior), no lugar do painel PERSONAGEM da Sala. Cada cômodo só preenche o
## conteúdo: a Forja, a Pesquisa, o Depósito, a Cantina, o Bar, o Dormitório (a noite e o amanhecer), o trem com um
## candidato, o Plano e as Opções; a Preparação é a gaveta de baixo, com PARTIR no botão principal. O relatório da volta
## e a Sala dos Personagens são telas inteiras do kit (AHStationReport, AHCharacterRoom). Tudo chama as regras de
## AHStationRules e grava pela Estação (station.commit()).
class_name AHRefugeHud
extends Control

## Abrir e fechar um painel (#36).
const PANEL_OPEN := "res://audio/ui/panel_open.ogg"
const PANEL_CLOSE := "res://audio/ui/panel_close.ogg"
const U := preload("res://scripts/ui/ui_style.gd")
const S := preload("res://scripts/flow/station_rules.gd")
const J := preload("res://scripts/flow/journey_rules.gd")
## A chegada da equipe de trem na volta (#76), antes do relatório: sem painel, só a dica de pular.
const ARRIVAL := "arrival"
const REPORT_GUARD_MS := 500
## A coluna da esquerda e o painel do cômodo (o lugar e a chapa do painel PERSONAGEM da Sala).
const LEFT := Rect2(28, 132, 500, 0)
const RIGHT := Rect2(1296, 132, 596, 844)
## A largura do conteúdo do painel (a chapa menos as margens dela e a barra de rolagem).
const BODY_WIDTH := 530.0
## O ícone do kit de cada cômodo e de cada tela de serviço.
const ROOM_ICONS := {S.CHARACTERS: "room_quarters", S.CANTEEN: "room_canteen", S.BAR: "room_bar", S.DORMITORY: "bed", S.FORGE: "room_forge",
	S.DEPOT: "room_depot", S.RESEARCH: "room_research", S.INFIRMARY: "intent-heal", S.PREPARATION: "expeditions", "plan": "plan", "train": "train_arrival",
	"new_campaign": "alert", "departure": "expeditions"}
const RELIC_ICONS := {"botao_cobre": "relic-copper-button", "pena_vidro": "relic-glass-feather", "coleira_lembranca": "relic-memory-collar"}
## Os ícones dos recursos nos chips de custo e no estoque.
const RESOURCE_ICONS := {"scrap": "lobby-scrap", "fragments": "lobby-fragment", "seeds": "lobby-seed", "bandages": "res-bandages",
	"water": "lobby-water", "food": "lobby-food", "power": "lobby-energy"}
const FEEDBACK_WIDTH := 900.0
const FEEDBACK_TOP := 132.0

var station: AHStation
var current := ""
## O quadro em que o painel abriu (o som de fechar não toca se ele fechar nesse mesmo quadro).
var _opened_frame := -1
## A moldura (o alto e o pé), refeita a cada refresh; as peças de que o resto precisa.
var _frame: Control
var _title: Label
var _subtitle: Label
var _resources: HBoxContainer
var _prepare: Button
## A coluna da esquerda: o próximo passo, o Plano e as pendências.
var _menu: VBoxContainer
var _next_title: Label
var _next_text: Label
var _next_button: Button
var _pending: VBoxContainer
## O pé da tela (VOLTAR, as abas e o botão principal): onde o foco fica quando o painel só tem texto.
var _corner: Control
var _rest_tag: PanelContainer
## O relatório abrindo logo depois da chegada (a câmera desliza até a fila).
var _after_arrival := false
## O herói escolhendo a melhoria do treino no Alojamento (#90), ou "".
var _training := ""
## A caixa do briefing ou do debriefing aberta (#88), ou null.
var briefing: AHBriefingDialog
## A ficha do herói ao apontar um cartão da Preparação (#89).
var sheet: AHCharacterSheet
## Até quando (relógio, ms) o relatório recém-aberto pela chegada ignora pular e voltar.
var _report_guard_ms := 0
## Pular apertado na chegada (também antes de ela começar, com o cartão da passagem ainda saindo).
var _arrival_skip := false
## A dica de pular a chegada (embaixo à direita).
var _arrival_hint: PanelContainer
## A seleção de cômodo da Unreal: só o cômodo apontado ganha os cantos âmbar, a etiqueta e o cartão embaixo à esquerda
## (com GERENCIAR). O do próximo passo e o Dormitório com a noite pendente ficam com os cantos apagados.
var _room_marks: Control
var _room_tag: PanelContainer
var _room_tag_icon: TextureRect
var _room_tag_label: Label
var _room_card: PanelContainer
var _hover_room := ""
var _room_rects := {}
## O cômodo escolhido pelo teclado ou pelo controle (setas e direcional); o mouse mexendo volta a mandar.
var _key_room := ""
var _last_mouse := Vector2(-1, -1)
## Ocultar HUD (F2 ou Back no controle): a interface some para olhar a Estação; o aviso fica embaixo.
var _hud_hidden := false
var _hidden_hint: Label
var _next := {}
## A gaveta da Preparação e o cartão escolhido para trocar (-1: nenhum).
var _prep: PanelContainer
var _prep_selected := -1
## O painel do cômodo: o cabeçalho (ícone, nome, estado e X), o conteúdo que rola e o pé fixo (as ações da noite e do
## trem).
var _panel: PanelContainer
var _panel_icon: TextureRect
var _panel_title: Label
var _panel_state: PanelContainer
var _panel_close: Button
## O vão entre o chip do estado e o X (some quando o título quebra a linha).
var _panel_gap: Control
var _scroll: ScrollContainer
var _body: VBoxContainer
var _footer: VBoxContainer
## O botão que recebe o foco ao abrir o painel (o principal do pé), ou null.
var _panel_focus: Control
var _feedback: Label
var _feedback_tween: Tween
## Rascunho da Preparação: fase, equipe (da frente para trás), foco e suprimentos extras.
var _draft := {}
## Cartões sob cada um da fila na plataforma (a partida), pelo id do herói.
var _tags: Control
## O relatório da volta no kit (#60): a tela inteira por cima da fila, no lugar do painel.
var _report_screen: AHStationReport
## A Sala dos Personagens no kit (#60): a tela inteira, com o cômodo ao fundo.
var _room_screen: AHCharacterRoom
## A tela do kit de onde as Opções ou o Plano foram abertos (a Sala): fechar volta para ela.
var _back_to := ""
var _tag_nodes := {}
var _lineup_signature := ""
## O candidato que o trem já trouxe nesta visita (a chegada toca uma vez).
var _arrived_candidate := ""
## Mapa de fases: Preparar expedição abre por cima de tudo; a fase escolhida vai para a Preparação.
var _map: AHPhaseMap
## A visita guiada da primeira vez (#145), aberta por cima da Estação, ou null.
var tour: AHStationTour


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet = AHCharacterSheet.new()
	add_child.call_deferred(sheet)
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_corner = _frame
	# À esquerda: o próximo passo com o botão dele, o Plano da Estação e as pendências.
	_menu = VBoxContainer.new()
	_menu.name = "Left"
	_menu.position = LEFT.position
	_menu.custom_minimum_size = Vector2(LEFT.size.x, 0)
	_menu.add_theme_constant_override("separation", 16)
	add_child(_menu)
	_tags = Control.new()
	_tags.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tags)
	_build_room_selection()
	_hidden_hint = AHKit.label("", "row", AHKit.TEXT, true)
	_hidden_hint.visible = false
	get_parent().add_child.call_deferred(_hidden_hint)
	_build_panel()
	_feedback = AHKit.label("", "row", AHKit.AMBER, true)
	# Sobre a cena (não sobre um painel): contorno escuro para ler em cima de qualquer cômodo.
	_feedback.add_theme_constant_override("outline_size", 8)
	_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feedback)
	_map = AHPhaseMap.new()
	_map.visible = false
	_map.phase_chosen.connect(_on_phase_chosen)
	_map.closed.connect(func(): _map.visible = false)
	add_child(_map)
	Tips.show_tip.call_deferred("station")
	_maybe_tour.call_deferred()


## O painel do cômodo: a chapa grande no lugar do painel PERSONAGEM, com o cabeçalho, o divisor, o conteúdo que rola e o
## pé fixo.
func _build_panel() -> void:
	_panel = AHKit.panel_box("large")
	_panel.name = "RoomPanel"
	_panel.position = RIGHT.position
	_panel.custom_minimum_size = Vector2(RIGHT.size.x, 0)
	_panel.visible = false
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	var head := HBoxContainer.new()
	head.name = "Header"
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	_panel_icon = AHKit.glyph("plan", 44, AHKit.AMBER)
	_panel_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_panel_icon)
	# O título quebra a linha antes de empurrar o X para fora (a Pesquisa no Maior).
	_panel_title = AHKit.label("", "panel_title", AHKit.TEXT, true, true)
	_panel_title.name = "Title"
	_panel_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_panel_title)
	_panel_state = _status_chip("", AHKit.MUTED)
	_panel_state.name = "State"
	_panel_state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_panel_state)
	_panel_gap = Control.new()
	_panel_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_panel_gap)
	_panel_close = AHKit.button("X", "icon")
	_panel_close.name = "Close"
	_panel_close.tooltip_text = tr("Fechar")
	_panel_close.custom_minimum_size = Vector2(56, 56)
	_panel_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_panel_close.focus_mode = Control.FOCUS_NONE
	_panel_close.pressed.connect(close_panel)
	head.add_child(_panel_close)
	box.add_child(_divider())
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	# A rolagem acompanha o foco do teclado e do controle (#5).
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.name = "Body"
	_body.custom_minimum_size = Vector2(BODY_WIDTH, 0)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	_scroll.add_child(_body)
	_footer = VBoxContainer.new()
	_footer.name = "Footer"
	_footer.add_theme_constant_override("separation", 10)
	box.add_child(_footer)
	# Os textos que quebram a linha só sabem a altura depois de arrumados: o painel se ajusta de novo quando ela muda.
	_body.minimum_size_changed.connect(_queue_fit)
	_footer.minimum_size_changed.connect(_queue_fit)


var _fit_queued := false
## A tela que o painel mostra (outra tela volta a rolagem para o alto).
var _shown := ""


func _queue_fit() -> void:
	if _fit_queued:
		return
	_fit_queued = true
	(func():
		_fit_queued = false
		_fit_panel()).call_deferred()


## Antes dos botões: a interface escondida volta com F2, Esc ou um clique; na vista geral, as setas (ou o direcional)
## andam entre os cômodos e Interagir abre o escolhido. Menu (Esc ou Start) leva o foco à coluna da esquerda (Próximo
## passo, o Plano, as pendências), que as setas percorrem; Voltar devolve aos cômodos. Com um painel ou o mapa aberto,
## o foco fica nos botões dele e Interagir confirma o botão com foco.
func _input(event: InputEvent) -> void:
	# Com o briefing aberto (#88), a caixa dele fica com o teclado, o controle, o clique e o toque.
	if briefing_open():
		return
	# Logo que o relatório abre depois da chegada, o segundo toque do pular (Interagir, Enter, Esc, clique) não conclui
	# nem fecha o relatório: quem pulou a cena ainda vê o que a equipe trouxe.
	if Time.get_ticks_msec() < _report_guard_ms and (AHPassageCard.is_skip(event) or U.is_back(event)):
		get_viewport().set_input_as_handled()
		return
	# Na chegada da equipe, nada abre por trás: Interagir, Esc, Voltar, um clique ou um toque pulam para o relatório.
	if current == ARRIVAL:
		# A dica da primeira vez aberta por cima fica com o que a fecha (clique, toque, Interagir, Enter) e não pula a
		# chegada; o resto (Esc, Voltar) não passa para trás.
		if Tips.showing():
			if not (event is InputEventMouseButton or event is InputEventScreenTouch or event.is_action("interact") or event.is_action("ui_accept")):
				get_viewport().set_input_as_handled()
			return
		if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton or event is InputEventScreenTouch \
				or event is InputEventAction:
			get_viewport().set_input_as_handled()
			if AHPassageCard.is_skip(event):
				_arrival_skip = true
				station.finish_team_arrival()
		return
	if _hud_hidden:
		var click: bool = event is InputEventMouseButton and event.pressed
		if event.is_action_pressed("hide_hud") or event.is_action_pressed("menu") or click:
			set_hud_hidden(false)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("hide_hud") and not _map.visible:
		set_hud_hidden(true)
		get_viewport().set_input_as_handled()
		return
	# A dica da primeira vez aberta fica com Interagir (ela fecha), sem abrir um cômodo por trás.
	if Tips.showing() and event.is_action_pressed("interact"):
		return
	# O botão principal (G/X, só nas telas da Estação, #60): PARTIR na Preparação; nas outras, PREPARAR EXPEDIÇÃO.
	var training: bool = is_instance_valid(_room_screen) and _room_screen.training
	if event.is_action_pressed("station_prepare") and not _map.visible and not training and current != "report":
		get_viewport().set_input_as_handled()
		if _prep != null and _prep.visible:
			if is_instance_valid(_prepare) and not _prepare.disabled:
				_depart()
			else:
				Sound.play("res://audio/ui/deny.ogg")
			return
		var block := S.preparation_block(Campaign.state)
		if block != "":
			toast(block, true)
			Sound.play("res://audio/ui/deny.ogg")
		else:
			open_map()
		return
	var scope := focus_scope()
	if scope != null:
		if U.press_focused(scope, event):
			get_viewport().set_input_as_handled()
		return
	if _menu_focused():
		if U.press_focused(self, event):
			get_viewport().set_input_as_handled()
		elif U.is_back(event):
			get_viewport().gui_release_focus()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu"):
		U.using_keys = true
		_next_button.grab_focus()
		get_viewport().set_input_as_handled()
		return
	for spec in [["move_left", Vector2.LEFT], ["move_right", Vector2.RIGHT], ["move_back", Vector2.UP], ["move_front", Vector2.DOWN]]:
		if event.is_action_pressed(spec[0], true):
			_step_room(spec[1])
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("interact") and _key_room != "":
		open_room(_key_room)
		get_viewport().set_input_as_handled()


func _reset_focus() -> void:
	for scope in [_panel, _prep, _corner]:
		if scope != null:
			U.reset_focus(scope)


## A tela de cima, onde o foco do teclado e do controle fica: o mapa de fases, a Preparação ou o painel aberto (com o
## pé da tela). Na vista geral, nenhuma (as setas andam entre os cômodos).
func focus_scope() -> Control:
	# O briefing (#88) cuida do foco dele.
	if briefing_open():
		return null
	if _map.visible:
		return _map
	if current == "":
		return null
	if _prep != null and _prep.visible:
		return _prep
	if current == "report" and is_instance_valid(_report_screen):
		return _report_screen
	if current == S.CHARACTERS and is_instance_valid(_room_screen):
		return _room_screen
	# Na cena do trem, sem painel: o foco fica no pé (as setas não andam entre os cômodos por trás da cena, #61).
	if current == "train" and not _panel.visible:
		return _corner
	if not _panel.visible:
		return null
	# Um cômodo só com texto (o Bar vazio): o foco fica no pé da tela (VOLTAR, as abas).
	return _panel if not U.focusable(_panel).is_empty() else _corner


## O foco está na coluna da esquerda ou no pé da tela (na vista geral).
func _menu_focused() -> bool:
	var owner := get_viewport().gui_get_focus_owner()
	return owner != null and owner.is_visible_in_tree() and (_menu.is_ancestor_of(owner) or _corner.is_ancestor_of(owner) or _room_card.is_ancestor_of(owner))


func set_hud_hidden(on: bool) -> void:
	_hud_hidden = on
	visible = not on
	if current == "":
		if on:
			station.focus_clean_overview()
		else:
			station.focus_overview()
	if _hidden_hint == null:
		return
	_hidden_hint.text = tr("%s mostra a interface") % U.key_name("hide_hud")
	_hidden_hint.visible = on
	_hidden_hint.size = _hidden_hint.get_combined_minimum_size()
	_hidden_hint.position = Vector2(960 - _hidden_hint.size.x * 0.5, 1030)


## O próximo cômodo na direção: o mais perto, com o desvio para o lado contando o dobro; sem nenhum escolhido, começa
## pelo do próximo passo (ou o primeiro da esquerda).
func _step_room(direction: Vector2) -> void:
	if _room_rects.is_empty():
		return
	if _key_room == "" or not _room_rects.has(_key_room):
		var start: String = _hover_room if _hover_room != "" else _next.get("room", "")
		if not _room_rects.has(start):
			var ids: Array = _room_rects.keys()
			ids.sort_custom(func(a, b): return _room_rects[a].position.x < _room_rects[b].position.x)
			start = ids[0]
		_key_room = start
	else:
		var from: Vector2 = _room_rects[_key_room].get_center()
		var best := ""
		var best_score := INF
		for id in _room_rects:
			if id == _key_room:
				continue
			var offset: Vector2 = _room_rects[id].get_center() - from
			var along := offset.dot(direction)
			if along <= 1.0:
				continue
			var score := along + absf(offset.dot(Vector2(direction.y, -direction.x))) * 2.0
			if score < best_score:
				best_score = score
				best = id
		if best != "":
			_key_room = best
	_last_mouse = get_viewport().get_mouse_position()


func _unhandled_input(event: InputEvent) -> void:
	# Na chegada não há painel para fechar (Voltar pula a chegada, no _input).
	if U.is_back(event) and current != "" and current != ARRIVAL and not _map.visible:
		close_panel()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and current == "" and not _map.visible:
		var room := _room_at(event.position)
		if room != "":
			open_room(room)
			get_viewport().set_input_as_handled()


## O tamanho do texto ou as cores mudaram nas Opções (AHUiStyle.retune): a moldura e o painel aberto (e a gaveta da
## Preparação) são refeitos com o tamanho novo, na mesma rolagem; o relatório (que anima a chegada do achado, com som)
## e as Opções (que se refazem sozinhas) ficam como estão.
func restyle() -> void:
	if _hidden_hint != null:
		_hidden_hint.size = _hidden_hint.get_combined_minimum_size()
		_hidden_hint.position.x = 960 - _hidden_hint.size.x * 0.5
	_build_frame(Campaign.state)
	if current == "" or current == "report" or current == "options":
		_build_left(Campaign.state)
		_fit_panel.call_deferred()
		return
	var at := _scroll.scroll_vertical
	refresh()
	var tree := get_tree()
	await tree.process_frame
	await tree.process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = at


func refresh() -> void:
	var c: Dictionary = Campaign.state
	_build_frame(c)
	_build_left(c)
	if current == "departure" and not _draft.is_empty():
		# A fila acompanha a equipe do rascunho (trocas e mudanças de ordem).
		var signature := ",".join(_draft.team)
		if signature != _lineup_signature:
			_lineup_signature = signature
			station.show_departure(_draft.team)
			for tag in _tag_nodes.values():
				tag.queue_free()
			_tag_nodes.clear()
	if current != "":
		_show(current)
	_fit_panel.call_deferred()


# ---------------------------------------------------------------- a moldura

## O nome da tela embaixo de "ESTAÇÃO RAIZ": na vista geral, o ciclo e o elenco; nos cômodos, o nome dele.
func _screen_name(c: Dictionary) -> String:
	match current:
		"", "options", "new_campaign":
			return tr("Ciclo %d · %d no elenco") % [c.station.cycle_number, S.living(c).size()]
		"plan":
			return tr("Plano da Estação")
		"train":
			return tr("Plataforma 1")
		"departure":
			return tr("Partida")
	if not S.room_def(current).is_empty():
		return tr(S.room_def(current).name)
	return ""


## A aba acesa: a vista geral, as instalações (os cômodos e o Plano), a Pesquisa; nenhuma na Preparação.
func _active_tab() -> String:
	match current:
		"", "options", "train", "new_campaign", "departure":
			return "overview"
		S.RESEARCH:
			return "research"
		S.PREPARATION:
			return ""
	return "facilities"


func _build_frame(c: Dictionary) -> void:
	for child in _frame.get_children():
		_frame.remove_child(child)
		child.queue_free()
	_prepare = null
	# O relatório e a Sala têm a moldura deles; a chegada fica sem nada por cima.
	var kit_screen := current == "report" or current == S.CHARACTERS
	_frame.visible = not kit_screen and current != ARRIVAL
	if not _frame.visible:
		return
	var top := AHStationFrame.top(_frame, c, _screen_name(c), func(): open_service("options"))
	_title = top.title
	_subtitle = top.subtitle
	_resources = top.resources
	var drawer := current == S.PREPARATION and S.preparation_block(c) == ""
	if drawer:
		if _draft.is_empty() or not S.phase_unlocked(c, _draft.get("phase", "")):
			_reset_draft()
		var mission := J.phase(_draft.phase)
		_prepare = AHStationFrame.prepare(_frame, tr("Partir · %s") % tr(mission.name), "station", _size_block(), _depart)
	else:
		_prepare = AHStationFrame.prepare(_frame, tr("Preparar expedição"), "station", S.preparation_block(c), open_map)
	AHStationFrame.tabs(_frame, _active_tab(), _nav)
	var pairs: Array
	if current == "":
		pairs = [[tr("Setas"), tr("Cômodos")], ["interact", tr("Abrir")], ["menu", tr("Menu")], ["hide_hud", tr("Ocultar")]]
		AHStationFrame.keys(_frame, pairs, LEFT.end.x + 300.0, LEFT.end.x + 32.0, _prepare.position.x - 24.0)
		return
	AHStationFrame.back_button(_frame, close_panel)
	if current == "options":
		pairs = [[tr("Setas"), tr("Navegar")], ["interact", tr("Mudar")], ["Esc", tr("Fechar")]]
	else:
		pairs = [[tr("Setas"), tr("Navegar")], ["interact", tr("Selecionar")], ["Esc", tr("Voltar")], ["hide_hud", tr("Ocultar")]]
	AHStationFrame.keys(_frame, pairs, 962.0, 268.0, (RIGHT.position.x if _panel.visible or current != S.PREPARATION else 1400.0) - 24.0)


## As abas de baixo: a vista geral, as instalações (o Plano), os personagens (a Sala), a pesquisa e ocultar.
func _nav(id: String) -> void:
	match id:
		"overview":
			close_panel()
		"facilities":
			open_service("plan")
		"characters":
			open_room(S.CHARACTERS)
		"research":
			open_room(S.RESEARCH)
		"hide":
			set_hud_hidden(true)


# ---------------------------------------------------------------- a coluna da esquerda

## O próximo passo (AHStationRules.next_step), o Plano da Estação e as pendências (a noite, o trem). Num cômodo, só as
## pendências.
func _build_left(c: Dictionary) -> void:
	_next = S.next_step(c)
	for child in _menu.get_children():
		_menu.remove_child(child)
		child.queue_free()
	_next_button = null
	var overview := current == ""
	var kit_screen := current == "report" or current == S.CHARACTERS
	_menu.visible = not kit_screen and current != ARRIVAL and current != "options" and not (_prep != null and _prep.visible)
	if overview:
		_menu.add_child(_next_card(c))
		_menu.add_child(_plan_card())
	var pending: Array = []
	if S.visit_pending(c) and current != "train" and not (overview and _next.action == "train"):
		pending.append([tr("O trem chegou: alguém espera na plataforma"), "train_arrival", func(): open_service("train")])
	if c.night.phase != "none" and current != S.DORMITORY and not (overview and _next.action == "dormitory"):
		pending.append([tr("A noite espera no Dormitório"), "sleep", func(): open_room(S.DORMITORY)])
	# Quem volta da recuperação no próximo dia (#121): "Íris volta amanhã".
	if current != S.INFIRMARY:
		for entry in S.fallen(c):
			if S.recovery_days(entry) == 1:
				var name: String = entry.display_name
				pending.append([tr("%s volta amanhã") % name, "bed", func(): open_room(S.INFIRMARY)])
	_pending = null
	if not pending.is_empty():
		_menu.add_child(_pending_card(pending))
	if _menu.get_child_count() == 0:
		_menu.visible = false
	_fit_overview_to_menu.call_deferred()
	_show_arrival_hint(current == ARRIVAL and not briefing_open())
	_refresh_room_card()


## O cartão PRÓXIMO PASSO: o título, o que muda, o custo em chips (com o que se tem) e o botão.
func _next_card(c: Dictionary) -> PanelContainer:
	var card := AHKit.panel_box("large")
	card.name = "NextStep"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	head.add_child(AHKit.glyph("next_step", 30, AHKit.AMBER))
	head.add_child(AHKit.label(tr("Próximo passo"), "text", AHKit.AMBER, true, true))
	_next_title = _wrapped(_next.title, "card_name", AHKit.TEXT, true, LEFT.size.x - 48.0)
	box.add_child(_next_title)
	_next_text = _wrapped(_next.get("benefit", _next.text), "text", AHKit.TEXT, false, LEFT.size.x - 48.0)
	box.add_child(_next_text)
	if _next.has("cost"):
		box.add_child(_cost_chips(c, _next.cost))
	var room: String = _next.get("room", "")
	_next_button = _primary_button(_next.button, ROOM_ICONS.get(room, "next_step") if _next.action == "room" else "next_step")
	_next_button.name = "NextButton"
	_next_button.pressed.connect(_run_next)
	box.add_child(_next_button)
	return card


## O Plano da Estação: o que cada cômodo destrava.
func _plan_card() -> Button:
	var button := Button.new()
	button.name = "PlanCard"
	AHKit.style_as(button, "plaque", Vector4(4, 4, 4, 4))
	button.custom_minimum_size = Vector2(LEFT.size.x, 76)
	button.pressed.connect(func(): open_service("plan"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 22
	row.offset_right = -16
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var glyph := AHKit.glyph("plan", 38, AHKit.TEXT)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -2)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(names)
	names.add_child(AHKit.label(tr("Plano da Estação"), "row", AHKit.TEXT, true, true))
	names.add_child(AHKit.label(tr("o que cada cômodo destrava"), "small", AHKit.MUTED))
	var grow := func(): button.custom_minimum_size.y = maxf(76.0, row.get_combined_minimum_size().y + 16.0)
	row.minimum_size_changed.connect(grow)
	grow.call()
	return button


## As PENDÊNCIAS: uma linha por pendência (a noite, o trem), que abre o que ela pede.
func _pending_card(rows: Array) -> PanelContainer:
	var card := AHKit.panel_box("large")
	card.name = "Pending"
	_pending = VBoxContainer.new()
	_pending.add_theme_constant_override("separation", 10)
	card.add_child(_pending)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_pending.add_child(head)
	head.add_child(AHKit.glyph("alert", 28, AHKit.AMBER))
	head.add_child(AHKit.label(tr("Pendências"), "text", AHKit.AMBER, true, true))
	for spec in rows:
		var button := Button.new()
		button.name = "Pending_%s" % spec[1]
		AHKit.style_as(button, "list")
		button.custom_minimum_size = Vector2(0, 56)
		button.pressed.connect(spec[2])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 16
		row.offset_right = -12
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(row)
		var glyph := AHKit.glyph(spec[1], 30, AHKit.AMBER)
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
		var text := _wrapped(spec[0], "text", AHKit.TEXT, false, LEFT.size.x - 120.0)
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(text)
		# A altura acompanha o texto, que só sabe quantas linhas tem depois de arrumado (o Maior, o inglês).
		var grow := func(): button.custom_minimum_size.y = maxf(56.0, row.get_combined_minimum_size().y + 14.0)
		row.minimum_size_changed.connect(grow)
		grow.call()
		_pending.add_child(button)
	return card


## A vista geral enquadra a Estação à direita da coluna da esquerda (que cresce com o texto e o idioma): medida a
## coluna, a câmera ajusta (#76; o Dormitório da ponta ficava embaixo do menu).
func _fit_overview_to_menu() -> void:
	if station == null or not _menu.visible:
		return
	var right := maxf(AHStation.SCREEN_MENU_RIGHT, _menu.get_global_rect().end.x + 16.0)
	if absf(right - station.menu_right) < 4.0:
		return
	station.menu_right = right
	if current == "":
		station.refit_overview()


## A dica de pular a chegada: a tecla de Interagir (ou "Toque para pular") embaixo à direita.
func _show_arrival_hint(show: bool) -> void:
	if not show:
		if _arrival_hint != null:
			_arrival_hint.visible = false
		return
	if _arrival_hint == null:
		_arrival_hint = AHKit.panel(AHKit.piece_of("key", "bar"))
		_arrival_hint.name = "ArrivalHint"
		_arrival_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_arrival_hint)
	for child in _arrival_hint.get_children():
		_arrival_hint.remove_child(child)
		child.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrival_hint.add_child(row)
	if Settings.touch_visible() and not U.using_keys:
		row.add_child(AHKit.label(tr("Toque para pular"), "text", AHKit.MUTED))
	else:
		row.add_child(AHKitKey.make("interact"))
		row.add_child(AHKit.label(tr("pular"), "text", AHKit.TEXT))
	_arrival_hint.visible = true
	_arrival_hint.reset_size()
	_arrival_hint.position = Vector2(1920, 1080) - _arrival_hint.get_combined_minimum_size() - Vector2(36, 28)


## A volta (#76): a equipe chega de trem e desce na plataforma; com todos no lugar (ou pulada), o relatório abre.
func play_arrival() -> void:
	_reset_focus()
	current = ARRIVAL
	_panel.visible = false
	var report: Dictionary = Campaign.state.station.last_return
	_arrival_skip = false
	refresh()
	# A chegada (e o som do trem) começa com a Estação na tela, não embaixo do cartão da passagem.
	while GameFlow.busy and is_inside_tree():
		await get_tree().process_frame
	if current != ARRIVAL or not is_inside_tree():
		return
	station.play_team_arrival(report.get("team", []))
	# Pulada ainda embaixo do cartão: vai direto ao fim.
	if _arrival_skip:
		station.finish_team_arrival()
	else:
		await station.train_event_named("team_ready")
	# O debriefing (#88): na plataforma, uma fala sobre o que se conseguiu e o que muda; depois, o relatório.
	var lines := AHBriefing.debriefing(Campaign.state, report) if current == ARRIVAL else []
	if not lines.is_empty() and is_inside_tree():
		# A dica de pular a chegada sai: a caixa tem os botões dela.
		_show_arrival_hint(false)
		briefing = AHBriefingDialog.open(self, lines, tr("Ver o relatório"))
		await briefing.finished
		briefing = null
	if current == ARRIVAL and is_inside_tree():
		current = ""
		_after_arrival = true
		_report_guard_ms = Time.get_ticks_msec() + REPORT_GUARD_MS
		open_service("report")


func _run_next() -> void:
	match _next.get("action", "depart"):
		"report":
			open_service("report")
		"dormitory":
			open_room(S.DORMITORY)
		"train":
			open_service("train")
		"room", "rest":
			open_room(_next.room)
		_:
			open_map()


# ---------------------------------------------------------------- seleção de cômodo (como na Unreal)

func _build_room_selection() -> void:
	_room_marks = Control.new()
	_room_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_room_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room_marks.draw.connect(_draw_room_marks)
	_tags.add_sibling(_room_marks)
	# A etiqueta do cômodo apontado, com a ponta para baixo, em cima dele.
	_room_tag = AHKit.panel(AHKit.piece_of("tag", "room"))
	_room_tag.name = "RoomTag"
	_room_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag_row := HBoxContainer.new()
	tag_row.add_theme_constant_override("separation", 8)
	tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room_tag.add_child(tag_row)
	_room_tag_icon = AHKit.glyph("room_quarters", 26, AHKit.AMBER)
	tag_row.add_child(_room_tag_icon)
	_room_tag_label = AHKit.label("", "text", AHKit.TEXT, true)
	tag_row.add_child(_room_tag_label)
	_room_tag.visible = false
	_room_marks.add_child(_room_tag)
	# O Dormitório em destaque com a noite pendente (#76): a etiqueta diz que a equipe precisa dormir.
	_rest_tag = AHKit.panel(AHKit.piece_of("tag", "room"))
	_rest_tag.name = "RestTag"
	_rest_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rest_row := HBoxContainer.new()
	rest_row.add_theme_constant_override("separation", 8)
	rest_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rest_tag.add_child(rest_row)
	rest_row.add_child(AHKit.glyph("sleep", 26, AHKit.NIGHT))
	rest_row.add_child(AHKit.label(tr("A equipe precisa dormir aqui"), "text", AHKit.TEXT, true))
	_rest_tag.visible = false
	_room_marks.add_child(_rest_tag)
	# O cartão embaixo à esquerda: o ícone, o nome, o estado, o papel e GERENCIAR.
	_room_card = AHKit.panel_box("large")
	_room_card.name = "RoomCard"
	_room_card.custom_minimum_size = Vector2(LEFT.size.x, 0)
	_room_card.visible = false
	add_child(_room_card)


## O estado do cômodo num chip: Vazio, Aberto, Nível N ou Nível N de M.
func _room_state(c: Dictionary, id: String) -> String:
	var level := S.room_level(c, id)
	if level < 1:
		return tr("Vazio")
	var top: int = S.room_def(id).max_level
	if top > 1:
		return tr("Nível %d de %d") % [level, top]
	return tr("Aberto") if id == S.CHARACTERS or id == S.PREPARATION else tr("Nível %d") % level


func _refresh_room_card() -> void:
	if _room_card == null:
		return
	var c: Dictionary = Campaign.state
	var show := _hover_room != "" and current == "" and not _map.visible
	_room_card.visible = show
	if not show:
		return
	if String(_room_card.get_meta("room", "")) == _hover_room and _room_card.get_child_count() > 0:
		return
	_room_card.set_meta("room", _hover_room)
	for child in _room_card.get_children():
		_room_card.remove_child(child)
		child.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_room_card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	head.add_child(AHKit.glyph(ROOM_ICONS.get(_hover_room, "station"), 40, AHKit.AMBER))
	var name_label := AHKit.label(tr(S.room_def(_hover_room).name), "card_name", AHKit.TEXT, true, true)
	name_label.name = "Name"
	head.add_child(name_label)
	var level := S.room_level(c, _hover_room)
	var state := _status_chip(_room_state(c, _hover_room), AHKit.good() if level >= 1 else AHKit.MUTED)
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(state)
	box.add_child(_wrapped(tr(S.ROOM_ROLES.get(_hover_room, "")), "text", AHKit.TEXT, false, LEFT.size.x - 48.0))
	var manage := AHKit.button(tr("Gerenciar"), "secondary")
	manage.name = "Manage"
	manage.custom_minimum_size = Vector2(0, 60)
	manage.focus_mode = Control.FOCUS_NONE
	manage.pressed.connect(func():
		if _hover_room != "":
			open_room(_hover_room))
	box.add_child(manage)
	_room_card.reset_size()
	_room_card.size = _room_card.get_combined_minimum_size()
	_room_card.position = Vector2(LEFT.position.x, AHStationFrame.BACK_Y + 56.0 - _room_card.size.y)


## O cômodo debaixo de um ponto da tela ("" se nenhum).
func _room_at(point: Vector2) -> String:
	for id in _room_rects:
		if _room_rects[id].has_point(point):
			return id
	return ""


func _update_room_hover() -> void:
	var overview := current == "" and not _map.visible
	_room_rects = station.room_screen_rects() if overview else {}
	var hovered := ""
	var mouse := get_viewport().get_mouse_position()
	if mouse.distance_to(_last_mouse) > 2.0:
		_key_room = ""
	if overview and _key_room != "" and _room_rects.has(_key_room):
		hovered = _key_room
	elif overview:
		var over := get_viewport().gui_get_hovered_control()
		# Em cima de um botão ou cartão do HUD, o cômodo de trás não acende (o cartão da seleção mantém a escolha).
		if over == null or over == self or over == _room_marks or over == _frame:
			hovered = _room_at(mouse)
		elif _room_card.visible and _room_card.get_global_rect().has_point(mouse):
			hovered = _hover_room
	if hovered != _hover_room:
		_hover_room = hovered
		_refresh_room_card()
	_room_marks.queue_redraw()
	if overview:
		_fit_overview_to_menu()
	# A etiqueta do Dormitório com a noite pendente (fora do desenho: acompanha a vista geral a cada quadro).
	var rest: bool = Campaign.state.night.phase != "none" and _room_rects.has(S.DORMITORY) and _hover_room != S.DORMITORY
	_rest_tag.visible = rest
	if rest:
		_rest_tag.size = _rest_tag.get_combined_minimum_size()
		# Acima do cômodo (a etiqueta do cômodo escolhido, o vizinho, fica na borda) e nunca por cima da coluna da
		# esquerda.
		var dorm: Rect2 = _room_rects[S.DORMITORY]
		var left := dorm.get_center().x - _rest_tag.size.x * 0.5
		if _menu.visible:
			left = maxf(left, _menu.get_global_rect().end.x + 12.0)
		_rest_tag.position = Vector2(left, dorm.position.y - _rest_tag.size.y + 6.0)


func _draw_room_marks() -> void:
	_room_tag.visible = false
	if _room_rects.is_empty():
		return
	var c: Dictionary = Campaign.state
	# Com a noite pendente, o Dormitório fica em destaque na vista geral: a luz, os cantos cheios e a etiqueta.
	if c.night.phase != "none" and _room_rects.has(S.DORMITORY):
		var dorm: Rect2 = _room_rects[S.DORMITORY]
		_room_marks.draw_rect(dorm, Color(AHKit.NIGHT, 0.08))
		_corners(dorm, Color(AHKit.NIGHT, 0.9), 3.0, 26.0)
	# Os cantos apagados: o cômodo do próximo passo (âmbar) e o Dormitório com a noite pendente.
	var hints := {}
	if _next.get("room", "") != "":
		hints[_next.room] = AHKit.AMBER
	if c.night.phase != "none":
		hints[S.DORMITORY] = AHKit.NIGHT
	for id in hints:
		if id != _hover_room and _room_rects.has(id):
			_corners(_room_rects[id], Color(hints[id], 0.5), 2.0, 18.0)
	if _hover_room == "" or not _room_rects.has(_hover_room):
		return
	var rect: Rect2 = _room_rects[_hover_room]
	_room_marks.draw_rect(rect, Color(AHKit.AMBER, 0.06))
	_corners(rect, AHKit.AMBER, 4.0, 30.0)
	_room_tag_label.text = tr(S.room_def(_hover_room).name)
	_room_tag_icon.texture = AHKit.icon(ROOM_ICONS.get(_hover_room, "station"))
	_room_tag.reset_size()
	_room_tag.size = _room_tag.get_combined_minimum_size()
	_room_tag.position = Vector2(rect.get_center().x - _room_tag.size.x * 0.5, rect.position.y - _room_tag.size.y + 6.0)
	_room_tag.visible = true
	# Com o texto Maior, a etiqueta do Dormitório pode encostar na do cômodo vizinho apontado: a do apontado fica.
	if _rest_tag.visible and _rest_tag.get_rect().intersects(_room_tag.get_rect()):
		_rest_tag.visible = false


func _corners(rect: Rect2, color: Color, width: float, arm: float) -> void:
	var a := rect.position
	var b := rect.end
	for corner in [[a, Vector2(1, 1)], [Vector2(b.x, a.y), Vector2(-1, 1)], [Vector2(a.x, b.y), Vector2(1, -1)], [b, Vector2(-1, -1)]]:
		var p: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		_room_marks.draw_line(p, p + Vector2(arm * d.x, 0), color, width)
		_room_marks.draw_line(p, p + Vector2(0, arm * d.y), color, width)


func open_room(room_id: String) -> void:
	# Outra tela pedida (o "Ver" do Plano): a volta à Sala que abriu o Plano não vale mais.
	_back_to = ""
	_reset_focus()
	if current == "" and _opened_frame != Engine.get_process_frames():
		_opened_frame = Engine.get_process_frames()
		_sound_open.call_deferred()
	current = room_id
	if room_id == S.PREPARATION and _draft.is_empty():
		_reset_draft()
	station.focus_room(room_id)
	refresh()
	_tour_moment("room:" + room_id)


func open_service(service: String) -> void:
	_back_to = ""
	_reset_focus()
	if current == "" and _opened_frame != Engine.get_process_frames():
		_opened_frame = Engine.get_process_frames()
		_sound_open.call_deferred()
	current = service
	match service:
		"report":
			Tips.show_tip("return")
			var report: Dictionary = Campaign.state.station.last_return
			# Depois da chegada, a câmera desliza da plataforma inteira até a fila (sem corte).
			station.show_report(report.get("team", []).filter(func(id): return S.hero(Campaign.state, id) != null and S.hero(Campaign.state, id).alive),
				not _after_arrival)
			_after_arrival = false
		"train":
			# O trem traz o candidato: chega do túnel uma vez por visita; depois ele só espera na plataforma.
			var train: Dictionary = Campaign.state.station.train
			if train.phase == "waiting" and not station.train_busy():
				station.open_train(train.candidate_id, _arrived_candidate != train.candidate_id)
				_arrived_candidate = train.candidate_id
			elif station.train_busy():
				# Reaberto no meio da cena (depois de um cômodo): a câmera volta para a plataforma e segue a cena dali.
				station.follow_train()
	refresh()


## O som de abrir só se o painel ficou aberto (o relatório vazio e o trem sem candidato fecham no mesmo quadro).
func _sound_open() -> void:
	if current != "":
		Sound.play(PANEL_OPEN)


func close_panel() -> void:
	# A escolha do Treino (#90) não fica aberta para a próxima vez.
	_training = ""
	if sheet != null:
		sheet.close()
	# A chegada termina no relatório, nunca no meio: fechar não vale (a fila e os cômodos ficariam pela metade).
	if current == ARRIVAL:
		return
	# O de fechar só se o de abrir tocou: o painel que fecha no mesmo quadro em que abriu não faz som nenhum (#36).
	if current != "" and Engine.get_process_frames() != _opened_frame:
		Sound.play(PANEL_CLOSE)
	current = ""
	_panel.visible = false
	_close_report_screen()
	_close_room_screen()
	var back := _back_to
	_back_to = ""
	if back != "":
		open_room(back)
		return
	_prep_selected = -1
	if _prep != null:
		_prep.visible = false
	station.clear_lineup()
	_lineup_signature = ""
	station.focus_overview()
	refresh()
	# De volta à vista geral, as setas voltam a andar entre os cômodos.
	if get_viewport() != null:
		get_viewport().gui_release_focus()
	_tour_moment("close")
	# Fechado o relatório da chegada da abertura, começa a visita guiada (#145).
	_maybe_tour()


# ---------------------------------------------------------------- a visita guiada (#145)

## A visita abre na vista geral, com a chegada e o relatório da abertura já vistos.
func _maybe_tour() -> void:
	if tour != null or current != "" or briefing_open() or not is_inside_tree() or not AHStationTour.pending(Campaign.state):
		return
	var report: Dictionary = Campaign.state.station.get("last_return", {})
	if not report.is_empty() and not report.get("seen", false):
		return
	tour = AHStationTour.new(self)
	tour.finished.connect(func(): tour = null)
	add_child(tour)


func _tour_moment(what: String) -> void:
	if tour != null:
		tour.moment(what)


## O que a visita destaca, na tela de 1920 x 1080 (vazio se não está à vista).
func tour_rect(target: String) -> Rect2:
	match target:
		"overview":
			var all := Rect2()
			for rect: Rect2 in station.room_screen_rects().values():
				all = rect if not all.has_area() else all.merge(rect)
			return all
		"resources":
			return _resources.get_global_rect() if is_instance_valid(_resources) and _resources.is_visible_in_tree() else Rect2()
		"next_step":
			var card := _menu.get_node_or_null("NextStep") as Control
			return card.get_global_rect() if card != null and card.is_visible_in_tree() else Rect2()
		"panel":
			# Na Sala, a coluna da direita (o nível e o Treino, que a fala explica).
			if is_instance_valid(_room_screen):
				return AHCharacterRoom.RIGHT
			return _panel.get_global_rect() if _panel.visible else Rect2()
		"characters", "prepare":
			var node := _frame.find_child("Nav_characters" if target == "characters" else "Prepare*", true, false) as Control
			return node.get_global_rect() if node != null and node.is_visible_in_tree() else Rect2()
	if target.begins_with("room:") and current == "":
		return station.room_screen_rects().get(target.substr(5), Rect2())
	return Rect2()


## A ação que a visita espera, pelo teclado ou pelo controle (Interagir): abrir o cômodo, fechar o painel ou o mapa.
func tour_act(wait: String) -> void:
	if wait.begins_with("room:") and current == "":
		open_room(wait.substr(5))
	elif wait == "close" and current != "":
		close_panel()
	elif wait == "map" and current == "":
		open_map()


## Tira a seleção de cômodo do teclado (a visita tem o destaque dela).
func clear_room_selection() -> void:
	_key_room = ""


## Preparar expedição (AAHHUD::OpenPhaseMap): com algo pendente (a noite, o trem), a Preparação diz o quê; senão, o mapa.
func open_map() -> void:
	_tour_moment("map")
	if S.preparation_block(Campaign.state) != "":
		open_room(S.PREPARATION)
		return
	if _draft.is_empty():
		_reset_draft()
	_map.open(_draft.phase, _draft.get("focus", ""))


func _on_phase_chosen(phase_id: String) -> void:
	_map.visible = false
	if _draft.is_empty():
		_reset_draft()
	_draft.phase = phase_id
	open_room(S.PREPARATION)


## A equipe da Preparação em fila na plataforma, esperando a partida (a câmera sobe pela passagem).
func open_departure() -> void:
	if _draft.is_empty():
		_reset_draft()
	current = "departure"
	_lineup_signature = ""
	refresh()


func _process(_delta: float) -> void:
	_update_room_hover()
	if _feedback.modulate.a > 0.0 and _feedback.text != "":
		_place_feedback()
	U.keep_focus(focus_scope())
	# No relatório, as cartas do kit ficam embaixo e cada um da fila fica de pé sobre a sua (#60).
	if current == "report" and is_instance_valid(_report_screen):
		station.align_lineup(_report_screen.card_centers())
	var showing := current == "departure"
	_tags.visible = showing
	if not showing:
		return
	var seen := {}
	for entry in station.lineup_screen_positions():
		seen[entry.hero_id] = true
		if not _tag_nodes.has(entry.hero_id):
			_tag_nodes[entry.hero_id] = _make_tag(entry.hero_id)
			_tags.add_child(_tag_nodes[entry.hero_id])
		var tag: Control = _tag_nodes[entry.hero_id]
		tag.position = entry.at + Vector2(-tag.size.x * 0.5, 14)
	for hero_id in _tag_nodes.keys():
		if not seen.has(hero_id):
			_tag_nodes[hero_id].queue_free()
			_tag_nodes.erase(hero_id)


## O cartão sob cada um da fila na partida: o nome, a vida, a posição e o ataque dali.
func _make_tag(hero_id: String) -> Control:
	var entry = S.hero(Campaign.state, hero_id)
	var box := AHKit.panel_box("inset")
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Do tamanho do espaço de cada um na fila (2,1 m): os cartões não se sobrepõem.
	box.custom_minimum_size = Vector2(190, 0)
	box.size = Vector2(190, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(column)
	column.add_child(AHKit.label(entry.display_name if entry else hero_id, "row", AHKit.AMBER, true))
	if entry:
		column.add_child(AHKit.label(tr("Vida %d/%d") % [entry.hp, entry.max_hp], "small", AHKit.TEXT))
		var rank: int = _draft.get("team", []).find(hero_id) + 1
		var attacks := S.attacks_from_rank(entry.class_id, rank)
		column.add_child(AHKit.label(tr("Posição %d") % rank, "small", AHKit.MUTED))
		column.add_child(_wrapped(attacks[0] if not attacks.is_empty() else tr("sem ataque aqui"), "small",
			AHKit.MUTED if not attacks.is_empty() else AHKit.alert_text(), false, 160.0))
	return box


func toast(text: String, error: bool = false) -> void:
	_feedback.text = text
	_place_feedback()
	_feedback.add_theme_color_override("font_color", AHKit.alert_text() if error else AHKit.AMBER)
	_feedback.modulate.a = 1.0
	if _feedback_tween:
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(3.2)
	_feedback_tween.tween_property(_feedback, "modulate:a", 0.0, 0.6)


## O aviso logo abaixo do alto, no meio da cena entre a coluna da esquerda e o painel aberto (#63). Refeito a cada
## quadro enquanto aparece (o painel abre e fecha por baixo dele).
func _place_feedback() -> void:
	var right := _panel.get_global_rect().position.x - 24.0 if _panel.visible else 1920.0
	var left := _menu.get_global_rect().end.x + 24.0 if _menu.visible else 0.0
	var width := minf(FEEDBACK_WIDTH, right - left - 32.0)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.custom_minimum_size.x = width
	_feedback.size = Vector2(width, 0)
	_feedback.position = Vector2(left + (right - left - width) * 0.5, FEEDBACK_TOP)


## Aplica uma ação das regras: "" grava e atualiza; senão mostra o motivo.
func _act(error: String, success: String = "", sound: String = "") -> void:
	if error != "":
		toast(error, true)
		Sound.play("res://audio/ui/deny.ogg")
		return
	station.commit()
	if sound != "":
		Sound.play(sound, 1.0, 1.0, "UI")
	if success != "":
		toast(success)


# ---------------------------------------------------------------- as peças do kit para o conteúdo

## Um texto do kit que quebra a linha na largura dada.
func _wrapped(text: String, role: String, color: Color, emphasis: bool, width: float) -> Label:
	var label := AHKit.label(text, role, color, emphasis)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	return label


## Um ícone do kit (art/ui/kit/station/icons) ou, sem ele, o svg de art/ui/icons.
func _icon(name: String, side: float, tint: Color) -> TextureRect:
	var rect := AHKit.glyph(name, side, tint)
	if rect.texture == null:
		rect.texture = AHKit.legacy_icon(name)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect


## O chip de estado (Vazio, Nível 1, Noite 1): o texto pequeno em caixa alta, na cor do estado.
func _status_chip(text: String, color: Color) -> PanelContainer:
	var chip := AHKit.chip("cost")
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := AHKit.label(text, "small", color, true, true)
	label.name = "Text"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(label)
	return chip


## Um chip de quantidade: o ícone e o texto (na cor de alerta quando falta).
func _chip(icon_name: String, text: String, color: Color = AHKit.TEXT) -> PanelContainer:
	var chip := AHKit.chip("cost")
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	if icon_name != "":
		row.add_child(_icon(icon_name, 24, color))
	row.add_child(AHKit.label(text, "text", color, true))
	return chip


## Os chips de um custo, um por recurso, com o que se tem ("4 sucatas · tem 9"); o que falta, na cor de alerta.
func _cost_chips(c: Dictionary, cost: Dictionary) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.name = "Cost"
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for resource in ["scrap", "fragments", "seeds"]:
		var amount := int(cost.get(resource, 0))
		if amount <= 0:
			continue
		var have := S.quantity(c, resource)
		var noun := S.cost_text({resource: amount}) if resource != "seeds" else tr("%d sementes") % amount
		var chip := _chip(RESOURCE_ICONS[resource], tr("%s · tem %d") % [noun, have], AHKit.TEXT if have >= amount else AHKit.alert_text())
		chip.name = "Cost_%s" % resource
		flow.add_child(chip)
	return flow


## Um botão pequeno do kit (Ver, Dormir, Fabricar, as opções) com o texto no tamanho dos rótulos.
func _chip_button(text: String) -> Button:
	var button := AHKit.button(text, "chip")
	AHOptionsPanel._chip_font(button)
	return button


## O botão principal âmbar com as divisas e o ícone, sem tecla (a tecla é a do botão de baixo).
func _primary_button(text: String, icon_name: String) -> Button:
	var button := AHKit.button(text, "primary", Vector4(10, 0, 0, 0))
	button.icon = AHKit.icon(icon_name)
	button.add_theme_constant_override("icon_max_width", 32)
	button.add_theme_constant_override("h_separation", 12)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "icon_normal_color", "icon_focus_color", "icon_hover_color"]:
		button.add_theme_color_override(state, AHKit.STEEL)
	button.custom_minimum_size = Vector2(0, 64)
	return button


## O botão principal do pé do painel, com a tecla de Interagir dentro (INICIAR DESCANSO, ACOLHER).
func _footer_primary(text: String, icon_name: String, action: Callable) -> Button:
	var button := AHStationReport._primary(text, icon_name, "interact")
	button.pressed.connect(action)
	_footer.add_child(button)
	AHStationReport.fit_key(button, 52.0)
	button.custom_minimum_size = Vector2(BODY_WIDTH, 64)
	# A tecla no fim do botão, que estica na largura do painel: ela acompanha o tamanho dele.
	button.resized.connect(func():
		var key: Control = button.get_node("Key")
		key.reset_size()
		key.position = Vector2(button.size.x - key.size.x - 52.0, (button.size.y - key.size.y) * 0.5))
	_panel_focus = button
	return button


func _divider() -> TextureRect:
	var line := TextureRect.new()
	line.texture = AHKit.texture("divider")
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.custom_minimum_size = Vector2(0, 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## Um painel de dentro (as caixas dos civis, do trem, da Cantina), com a coluna em que vai o conteúdo.
func _inset(parent: Container = null) -> VBoxContainer:
	var box := AHKit.panel_box("inset")
	(parent if parent != null else _body).add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	box.add_child(column)
	return column


# ---------------------------------------------------------------- painel

## O cabeçalho do painel: o ícone, o nome e o estado (vazio, sem chip).
func _header(icon_name: String, title: String, state: String = "", tone: Color = AHKit.MUTED) -> void:
	_panel_icon.texture = AHKit.icon(icon_name)
	if _panel_icon.texture == null:
		_panel_icon.texture = AHKit.legacy_icon(icon_name)
	_panel_icon.modulate = AHKit.AMBER
	_panel_title.text = title
	_panel_state.visible = state != ""
	var label: Label = _panel_state.get_node("Text")
	label.text = state
	label.add_theme_color_override("font_color", tone)
	# O chip logo depois do nome; o nome que não cabe na linha (a Pesquisa no Maior) quebra antes de empurrar o X.
	var room := BODY_WIDTH - 44.0 - 56.0 - 36.0 - (_panel_state.get_combined_minimum_size().x + 12.0 if _panel_state.visible else 0.0)
	var wide := _panel_title.get_theme_font("font").get_string_size(title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1,
		_panel_title.get_theme_font_size("font_size")).x > room
	_panel_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wide else TextServer.AUTOWRAP_OFF
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL if wide else Control.SIZE_SHRINK_BEGIN
	# Quebrando, o título fica com o espaço todo até o chip (o vão não divide com ele).
	_panel_gap.visible = not wide


## O painel do tamanho do conteúdo, até acima do botão principal: o que passa rola.
func _fit_panel() -> void:
	if not is_instance_valid(_panel) or not _panel.visible:
		return
	var bottom: float = (_prepare.position.y if is_instance_valid(_prepare) else AHStationFrame.SCREEN_BOTTOM) - 12.0
	var room := bottom - RIGHT.position.y
	var box: VBoxContainer = _panel.get_child(0)
	var other := 0.0
	var shown := 0
	for child in box.get_children():
		if child == _scroll or not (child as Control).visible:
			continue
		other += (child as Control).get_combined_minimum_size().y
		shown += 1
	var margins := 44.0 + 10.0 * shown
	var content := _body.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = clampf(content, 40.0, maxf(40.0, room - margins - other))
	_panel.reset_size()
	_panel.size = Vector2(RIGHT.size.x, _panel.get_combined_minimum_size().y)
	_panel.position = RIGHT.position


func _show(key: String) -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	for child in _footer.get_children():
		_footer.remove_child(child)
		child.queue_free()
	_panel_focus = null
	var c: Dictionary = Campaign.state
	if key == S.PREPARATION and S.preparation_block(c) == "" and S.room_level(c, S.PREPARATION) >= 1:
		_panel.visible = false
		_menu.visible = false
		_prep_drawer(c)
		Tips.show_tip("preparation")
		return
	if _prep != null:
		_prep.visible = false
	# Durante a cena do trem (o aviso, a chegada, o candidato descendo, a partida), nenhum painel por cima: o do trem
	# abre quando a câmera fecha no candidato (#61).
	# Na chegada da equipe (#76), também: o relatório abre quando todos estão na fila.
	if key == ARRIVAL:
		_panel.visible = false
		return
	if key == "train" and station != null and station.train_busy():
		_panel.visible = false
		_watch_train()
		return
	if key == "report":
		_panel.visible = false
		_report()
		return
	_close_report_screen()
	if key == S.CHARACTERS:
		_panel.visible = false
		_character_room()
		return
	_close_room_screen()
	_panel.visible = true
	# Outra tela: a lista começa do alto (a mesma tela refeita fica na mesma rolagem).
	if key != _shown:
		_shown = key
		_scroll.scroll_vertical = 0
	_header("plan", "")
	match key:
		"train":
			_train()
		"departure":
			_departure_view()
		"new_campaign":
			_new_campaign_view()
		"plan":
			_station_plan(c)
		"options":
			_header("opt_controls", tr("Opções"))
			_panel_icon.texture = AHKit.legacy_icon("lobby-settings")
			var options := AHOptionsPanel.new()
			options.width = int(BODY_WIDTH)
			options.allow_new_campaign = true
			options.closed.connect(close_panel)
			options.new_campaign_requested.connect(func(): open_service("new_campaign"))
			options.allow_title = true
			options.show_title = false
			options.title_requested.connect(func(): GameFlow.travel("title"))
			_body.add_child(options)
		_:
			_room(key)
	_footer.visible = _footer.get_child_count() > 0
	_fit_panel()
	if _panel_focus != null and U.using_keys:
		_panel_focus.grab_focus.call_deferred()


## O plano da Estação: um bloco por cômodo, na ordem do jogo, com o ícone, o nome, o nível ou Vazio, o que faz, o custo
## para recuperar (um chip por recurso) e VER.
func _station_plan(c: Dictionary) -> void:
	_header("plan", tr("Plano da Estação"))
	_text(tr("A Estação cresce com o que as jornadas trazem. Sucata e fragmentos recuperam e melhoram os cômodos."))
	for room in AHStation.ROOMS:
		var id: String = room.id
		var room_def := S.room_def(id)
		var level := S.room_level(c, id)
		var cost := S.next_level_cost(c, id)
		var column := _inset()
		column.get_parent().name = "Plan_%s" % id
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 12)
		column.add_child(head)
		head.add_child(_icon(ROOM_ICONS.get(id, "station"), 36, AHKit.AMBER))
		var name_label := AHKit.label(tr(room_def.name), "row", AHKit.TEXT, true)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		head.add_child(_status_chip(_room_state(c, id), AHKit.good() if level >= 1 else AHKit.MUTED))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		column.add_child(row)
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", 6)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		words.add_child(_wrapped(S.room_benefit(id, level) if level >= 1 else tr("Ainda vazio."), "small", AHKit.TEXT, false, BODY_WIDTH - 150.0))
		if not cost.is_empty():
			words.add_child(_wrapped("%s: %s" % [tr("Recuperar") if level == 0 else tr("Nível %d") % (level + 1), S.room_benefit(id, level + 1)], "small",
				AHKit.MUTED, false, BODY_WIDTH - 150.0))
			words.add_child(_cost_chips(c, cost))
		var go := _chip_button(tr("Ver"))
		go.name = "See_%s" % id
		go.tooltip_text = tr("Ver %s") % tr(room_def.name)
		go.custom_minimum_size = Vector2(64, 56)
		go.size_flags_vertical = Control.SIZE_SHRINK_END
		go.pressed.connect(func(): open_room(id))
		row.add_child(go)


## Começar do zero (com confirmação): o save atual é substituído por uma campanha nova.
func _new_campaign_view() -> void:
	_header("alert", tr("Nova campanha"))
	_text(tr("Recomeça a Estação, o elenco e as fases do zero."), AHKit.MUTED)
	# Diz qual espaço é trocado (#34): os outros ficam como estão.
	_text(tr("Todo o progresso salvo no espaço %d (fases concluídas, cômodos, recursos e heróis) é substituído por uma campanha nova. Os outros espaços ficam como estão.") % Campaign.slot,
		AHKit.alert_text())
	_button(tr("Cancelar"), close_panel)
	var go := _button(tr("Começar do zero"), func():
		# A campanha nova passa pela escolha do título (#144): a abertura ou Pular tutorial, no mesmo espaço.
		GameFlow.travel("title", {}, {"new_campaign": Campaign.slot}))
	go.add_theme_color_override("font_color", AHKit.alert_text())


## O título de uma tela sem cômodo (o trem, a partida) e o texto embaixo dele.
func _heading(text: String, subtitle: String = "") -> void:
	_header(ROOM_ICONS.get(current, "station"), text)
	if subtitle != "":
		_text(subtitle, AHKit.MUTED)


func _text(text: String, color: Color = AHKit.TEXT, role: String = "text") -> Label:
	var label := _wrapped(text, role, color, false, BODY_WIDTH)
	_body.add_child(label)
	return label


## O título de uma parte do painel: âmbar, em caixa alta, com o ícone.
func _section(text: String, icon_name: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_body.add_child(row)
	if icon_name != "":
		row.add_child(_icon(icon_name, 28, AHKit.AMBER))
	row.add_child(_wrapped(text, "row", AHKit.AMBER, true, 0.0))
	(row.get_child(-1) as Label).uppercase = true
	(row.get_child(-1) as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
	return row


## Um botão do kit: sozinho, o de aço na largura do painel; numa linha (−, +), o pequeno de ícone.
func _button(text: String, action: Callable, enabled: bool = true, parent: Container = null) -> Button:
	var button := AHKit.button(text, "secondary" if parent == null else "icon")
	button.disabled = not enabled
	if parent == null:
		button.custom_minimum_size = Vector2(0, 64)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		button.text = text
		button.custom_minimum_size = Vector2(56, 56)
	button.pressed.connect(action)
	(parent if parent else _body).add_child(button)
	return button


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_body.add_child(row)
	return row


func _room(room_id: String) -> void:
	var c: Dictionary = Campaign.state
	var level := S.room_level(c, room_id)
	var room_def := S.room_def(room_id)
	_header(ROOM_ICONS.get(room_id, "station"), tr(room_def.name), _room_state(c, room_id), AHKit.good() if level >= 1 else AHKit.MUTED)
	# O Bar vazio: só o ícone do cômodo e o texto do jogo (o efeito dele segue em aberto, #11).
	if room_id == S.BAR and level < 1:
		var empty := _inset()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		empty.add_child(row)
		row.add_child(_icon("room_bar", 40, AHKit.MUTED))
		var line := _wrapped(S.room_benefit(room_id, level), "text", AHKit.TEXT, false, BODY_WIDTH - 90.0)
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(line)
	else:
		_text(S.room_benefit(room_id, level))
	if room_id == S.DEPOT:
		_supplies_bar(c)
	var cost := S.next_level_cost(c, room_id)
	if not cost.is_empty():
		var block := S.upgrade_block(c, room_id)
		var verb := tr("Recuperar") if level == 0 else tr("Melhorar")
		if level == 0:
			_section(verb, ROOM_ICONS.get(room_id, "station"))
		_body.add_child(_cost_chips(c, cost))
		var upgrade := AHKit.button(verb, "secondary")
		upgrade.name = "Upgrade"
		upgrade.icon = AHKit.icon(ROOM_ICONS.get(room_id, "station"))
		upgrade.add_theme_constant_override("icon_max_width", 30)
		upgrade.alignment = HORIZONTAL_ALIGNMENT_LEFT
		upgrade.custom_minimum_size = Vector2(0, 64)
		if level >= 1:
			upgrade.text = tr("%s · %s") % [verb.to_upper(), tr("para o nível %d") % (level + 1)]
		upgrade.disabled = block != ""
		upgrade.tooltip_text = block
		upgrade.pressed.connect(func(): _act(S.upgrade_room(Campaign.state, room_id, level), tr("%s: nível %d.") % [tr(room_def.name), level + 1]))
		_body.add_child(upgrade)
		_body.add_child(_divider())
	for civilian_id in c.station.residents:
		var who := S.civilian(civilian_id)
		if who.room == room_id:
			_civilian_card(c, who)
	match room_id:
		S.PREPARATION:
			_preparation(c)
		S.CANTEEN:
			_canteen(c)
		S.DEPOT:
			_depot(c)
		S.FORGE:
			_forge(c, level)
		S.RESEARCH:
			_research(c, level)
		S.DORMITORY:
			_dormitory(c)
		S.INFIRMARY:
			_infirmary(c, level)


func _civilian_card(c: Dictionary, who: Dictionary) -> void:
	var box := _inset()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	head.add_child(AHKit.portrait(_civilian_face(who.id), 64))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	head.add_child(names)
	names.add_child(AHKit.label(who.name, "row", AHKit.TEXT, true))
	names.add_child(AHKit.label(tr("%s · %s") % [tr(who.role), tr(who.species)], "small", AHKit.AMBER))
	var working := S.civilian_working(c, who.id)
	box.add_child(_wrapped((tr("Ponto forte: %s") % tr(who.benefit)) if working else tr("Sem comida ou água no último ciclo: o ponto forte está parado até a próxima volta."),
		"small", AHKit.TEXT if working else AHKit.alert_text(), false, BODY_WIDTH - 40.0))
	box.add_child(_wrapped(tr("Ponto fraco: %s") % tr(who.drawback), "small", AHKit.MUTED, false, BODY_WIDTH - 40.0))
	box.add_child(_wrapped((tr("Pedido entregue: %s.") % tr(who.request_reward)) if S.has_completed_request(c, who.id) else (tr("Pedido: %s") % tr(who.need)),
		"small", AHKit.MUTED, false, BODY_WIDTH - 40.0))


static func _civilian_face(civilian_id: String) -> Texture2D:
	var path := "res://art/civilians/%s.webp" % civilian_id
	return load(path) if ResourceLoader.exists(path) else null


# ---------------------------------------------------------------- Alojamento (a Sala dos Personagens)

func _train_hero(hero_id: String, upgrade_id: String) -> void:
	_training = ""
	var entry = S.hero(Campaign.state, hero_id)
	var upgrade = GameData.row("hero_upgrades", upgrade_id)
	var next := AHHeroLevels.level(entry) + 1
	_act(AHHeroLevels.train(Campaign.state, hero_id, upgrade_id),
		tr("%s subiu para o nível %d: %s.") % [entry.display_name, next, tr(upgrade.DisplayName) if upgrade else ""], "res://audio/ui/forge_confirm.ogg")


func _cycle_relic(hero_id: String) -> void:
	var c: Dictionary = Campaign.state
	var entry = S.hero(c, hero_id)
	var options: Array = [""]
	for relic_id in c.inventory.relics:
		if not options.has(relic_id):
			options.append(relic_id)
	if entry.relic_id != "" and not options.has(entry.relic_id):
		options.append(entry.relic_id)
	var index := options.find(entry.relic_id)
	var next: String = options[(index + 1) % options.size()]
	var relic = GameData.row("relics", next)
	_act(S.equip_relic(c, hero_id, next), tr("%s: %s.") % [entry.display_name, tr(relic.DisplayName) if relic else tr("sem relíquia")])


func _recruit(class_id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var result := S.recruit(Campaign.state, class_id, rng)
	_act(result.error, tr("%s chegou à Estação.") % (S.hero(Campaign.state, result.get("hero_id", "")).display_name if result.error == "" else ""))
	if result.error == "":
		var rng2 := RandomNumberGenerator.new()
		rng2.randomize()
		station._place_residents(rng2)


# ---------------------------------------------------------------- Preparação

func _reset_draft() -> void:
	var c: Dictionary = Campaign.state
	# A fase sugerida: a primeira liberada que falta concluir (ou a última, com todas feitas).
	var next: String = J.PHASES[-1].id
	for info in J.PHASES:
		if S.phase_unlocked(c, info.id) and not c.completed_phases.has(info.id):
			next = info.id
			break
	# A equipe da última partida (pode ser menor, #6); quem caiu é reposto até o tamanho dela, no mínimo o da jornada.
	var limits := J.team_limits(next)
	var size: int = clampi(maxi(c.preferred_formation.size(), limits.min), 1, limits.max)
	var team: Array = c.preferred_formation.filter(func(id): return S.hero(c, id) != null and S.hero(c, id).alive and S.can_deploy(S.hero(c, id)))
	for entry in S.living(c):
		if team.size() < size and not team.has(entry.id) and S.can_deploy(entry):
			team.append(entry.id)
	_draft = {"phase": next, "team": team, "focus": S.focus_recommended(c), "extra": 0}


## A Preparação sem a gaveta: bloqueada (a noite, o trem), ela diz o quê e leva até lá; na partida pela plataforma, a
## missão, a equipe, o foco e a comida, numa coluna.
func _preparation(c: Dictionary) -> void:
	var block := S.preparation_block(c)
	if block != "":
		_text(block, AHKit.alert_text())
		if c.night.phase != "none":
			_button(tr("Ir ao Dormitório"), func(): open_room(S.DORMITORY))
		elif S.visit_pending(c):
			_button(tr("Ir à plataforma"), func(): open_service("train"))
		return
	if _draft.is_empty():
		_reset_draft()
	# Missão: o mapa de fases abre por cima; a fase escolhida volta para esta mesma escalação.
	_section(tr("Missão"), "route")
	var mission := J.phase(_draft.phase)
	if not S.phase_unlocked(c, _draft.phase):
		_reset_draft()
		mission = J.phase(_draft.phase)
	_text(tr("%s · nível %d · %s") % [tr(mission.name), mission.level, tr(J.DIFFICULTY_NAMES[mission.difficulty])], AHKit.AMBER)
	_button(tr("Escolher no mapa"), func(): _map.open(_draft.phase, _draft.get("focus", "")))
	_section(tr("Equipe (da frente para trás)"))
	for rank in 4:
		var hero_id: String = _draft.team[rank] if rank < _draft.team.size() else ""
		var entry = S.hero(c, hero_id)
		var row := _row()
		var label := AHKit.label(tr("%d. %s") % [rank + 1, entry.display_name if entry else "—"], "row", AHKit.TEXT, true)
		label.custom_minimum_size = Vector2(250, 0)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)
		if entry and S.attacks_from_rank(entry.class_id, rank + 1).is_empty():
			label.add_theme_color_override("font_color", AHKit.alert_text())
		var slot := rank
		var swap := _button(tr("Trocar"), func(): _cycle_slot(slot), S.living(c).size() > _draft.team.size() or _draft.team.size() > 1, row)
		swap.custom_minimum_size = Vector2(120, 56)
		if rank > 0:
			_button("↑", func(): _swap(slot, slot - 1), true, row)
	_section(tr("Foco da rota"))
	var recommended := S.focus_recommended(c)
	for focus_id in [""] + S.FOCI.map(func(f): return f.id):
		if not S.focus_available(c, focus_id):
			continue
		var id: String = focus_id
		var label := S.focus_label(id)
		if id != "":
			label += " · " + S.focus_reward_text(id)
		if id == recommended:
			label += tr(" · recomendado")
		var button := _button(label, func(): _draft.focus = id; refresh())
		if _draft.focus == id:
			button.add_theme_color_override("font_color", AHKit.AMBER)
			button.add_child(AHKit.selected_overlay())
	_text(S.focus_reason(c, _draft.focus), AHKit.MUTED, "small")
	_section(tr("Suprimentos"))
	var row := _row()
	var food_label := AHKit.label(tr("%d de graça + %d extras (%d sementes)") % [J.FREE_FOOD, _draft.extra, _draft.extra * S.FOOD_COST], "text", AHKit.TEXT)
	food_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	food_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(food_label)
	_button("−", func(): _draft.extra = maxi(0, _draft.extra - 1); refresh(), _draft.extra > 0, row)
	_button("+", func(): _draft.extra = mini(J.MAX_FOOD - J.FREE_FOOD, _draft.extra + 1); refresh(),
		_draft.extra < J.MAX_FOOD - J.FREE_FOOD and (_draft.extra + 1) * S.FOOD_COST <= S.quantity(c, "seeds"), row)
	if current == "departure":
		_button(tr("Voltar à Preparação"), func():
			station.clear_lineup()
			_lineup_signature = ""
			open_room(S.PREPARATION))
	else:
		_button(tr("Escalar a equipe na plataforma"), open_departure)
	_footer_primary(tr("Confirmar partida"), "station", _depart)


func _cycle_slot(rank: int) -> void:
	var c: Dictionary = Campaign.state
	var candidates: Array = S.living(c).filter(func(h): return S.can_deploy(h)).map(func(h): return h.id)
	var current_id: String = _draft.team[rank] if rank < _draft.team.size() else ""
	var start := candidates.find(current_id)
	for step in range(1, candidates.size() + 1):
		var candidate: String = candidates[(start + step) % candidates.size()]
		if not _draft.team.has(candidate):
			if rank < _draft.team.size():
				_draft.team[rank] = candidate
			else:
				_draft.team.append(candidate)
			refresh()
			return
	# Todos já estão na equipe: troca de lugar com o próximo.
	_swap(rank, (rank + 1) % _draft.team.size())


func _swap(a: int, b: int) -> void:
	if a >= _draft.team.size() or b >= _draft.team.size():
		return
	var keep = _draft.team[a]
	_draft.team[a] = _draft.team[b]
	_draft.team[b] = keep
	refresh()


# ---------------------------------------------------------------- Preparação numa tela (a proposta de UX, tela 4)

## A arte de um herói (o recruta, a variação da classe guardada no save; sem ela, a do fundador).
static func _hero_art(entry: Dictionary) -> Dictionary:
	return AHCombatArena.hero_art_of(entry.id, String(entry.get("art_variant", ""))).get("idle", {})


## O que trava a partida pelo tamanho da equipe (a fase pede de N a M animais), ou "".
func _size_block() -> String:
	if _draft.is_empty():
		return ""
	var limits := J.team_limits(_draft.phase)
	if _draft.team.size() < limits.min or _draft.team.size() > limits.max:
		return tr("%s pede %s na equipe.") % [J.phase(_draft.phase).get("name", tr("Esta jornada")), S.team_size_text(limits)]
	return ""


## A gaveta da Preparação: os quatro cartões no sentido da luta (o fundo à esquerda, a frente à direita), com o
## medalhão da posição, o rosto, o papel, a vida, as habilidades que funcionam daquela posição e os avisos; clicar em
## dois troca; os de fora ficam embaixo. À direita, a Missão, o Foco da rota e a Comida; PARTIR é o botão principal.
func _prep_drawer(c: Dictionary) -> void:
	if _draft.is_empty():
		_reset_draft()
	if not S.phase_unlocked(c, _draft.phase):
		_reset_draft()
	if _prep == null:
		_prep = AHKit.panel_box("large")
		_prep.name = "Preparation"
		_prep.minimum_size_changed.connect(_fit_prep)
		_tags.add_sibling(_prep)
	_prep.visible = true
	_fit_prep.call_deferred()
	# Os cartões são refeitos: a ficha do cartão de antes fecha (o mouse ou o foco a abrem de novo).
	sheet.close()
	for child in _prep.get_children():
		_prep.remove_child(child)
		child.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	_prep.add_child(row)

	var lineup := VBoxContainer.new()
	lineup.add_theme_constant_override("separation", 12)
	lineup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lineup)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	lineup.add_child(head)
	var limits := J.team_limits(_draft.phase)
	var title := AHKit.label(tr("Equipe · %s") % S.team_size_text(limits), "row", AHKit.AMBER, true, true)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	var hint := AHKit.label(tr("Clique em dois para trocar"), "text", AHKit.MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hint)
	# O sentido da luta: o fundo à esquerda, a frente à direita (as setas são ícones: a Barlow não tem o caractere).
	var back_arrow := _icon("ui-arrow-right", 22, AHKit.MUTED)
	back_arrow.flip_h = true
	head.add_child(back_arrow)
	head.add_child(AHKit.label(tr("fundo · frente"), "text", AHKit.MUTED))
	head.add_child(_icon("ui-arrow-right", 22, AHKit.MUTED))
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 14)
	lineup.add_child(slots)
	for rank in [4, 3, 2, 1]:
		slots.add_child(_prep_slot(c, rank))
	# Os de fora da equipe: com um cartão escolhido, clicar troca.
	var bench: Array = S.living(c).filter(func(h): return not _draft.team.has(h.id))
	var can_leave: bool = _prep_selected >= 0 and _prep_selected < _draft.team.size() and _draft.team.size() > 1
	if not bench.is_empty() or can_leave:
		# Quebra em linhas: com a equipe pequena e muitos na Estação (e o texto Maior), a gaveta continua na tela.
		var bench_row := HFlowContainer.new()
		bench_row.add_theme_constant_override("h_separation", 8)
		bench_row.add_theme_constant_override("v_separation", 8)
		lineup.add_child(bench_row)
		var label := AHKit.label(tr("Fora da equipe:"), "text", AHKit.MUTED)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bench_row.add_child(label)
		for entry in bench:
			var id: String = entry.id
			var button := _chip_button("%s · %d/%d" % [entry.display_name, entry.hp, entry.max_hp])
			button.custom_minimum_size = Vector2(0, 56)
			button.disabled = _prep_selected < 0 or not S.can_deploy(entry)
			button.tooltip_text = tr("Escolha um cartão da equipe e clique aqui para trocar.") if S.can_deploy(entry) else S.deploy_block(entry)
			if S.recovering(entry):
				button.text += " · " + S.return_text(S.recovery_days(entry))
				button.add_theme_color_override("font_disabled_color", AHKit.alert_text())
			elif not S.can_deploy(entry):
				button.text += tr(" · sem arte de combate")
			button.pressed.connect(func(): _prep_bench(id))
			sheet.attach(button, func(): return AHCharacterSheet.from_hero(S.hero(Campaign.state, id)))
			bench_row.add_child(button)
		# Equipe menor (#6): o escolhido fica na Estação e a vaga fica vazia (os de trás andam para a frente).
		if can_leave:
			var leave := _chip_button(tr("Deixar na Estação"))
			leave.custom_minimum_size = Vector2(0, 56)
			leave.tooltip_text = tr("Parte com um a menos; os de trás andam uma posição para a frente.")
			leave.pressed.connect(_prep_leave)
			bench_row.add_child(leave)
	var size_block := _size_block()
	if size_block != "":
		lineup.add_child(_alert_line(size_block))
	var warning := _team_warning(c)
	if warning != "":
		lineup.add_child(_alert_line(warning, AHKit.AMBER))

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 12)
	side.custom_minimum_size = Vector2(490, 0)
	row.add_child(side)
	var mission := J.phase(_draft.phase)
	var mission_box := _side_box(side, tr("Missão"))
	var mission_row := HBoxContainer.new()
	mission_row.add_theme_constant_override("separation", 12)
	mission_box.add_child(mission_row)
	mission_row.add_child(_icon("route", 40, AHKit.TEXT))
	var mission_names := VBoxContainer.new()
	mission_names.add_theme_constant_override("separation", -2)
	mission_row.add_child(mission_names)
	mission_names.add_child(AHKit.label(tr(mission.name), "card_name", AHKit.TEXT, true))
	mission_names.add_child(_wrapped(tr("Fase %d · %s · nível %d+") % [J.PHASES.map(func(p): return p.id).find(mission.id) + 1, tr(J.DIFFICULTY_NAMES[mission.difficulty]),
		mission.level], "text", AHKit.MUTED, false, 380.0))
	var map_button := AHKit.button(tr("Escolher no mapa"), "secondary")
	map_button.text = tr("Escolher no mapa")
	map_button.icon = AHKit.legacy_icon("marker-here")
	map_button.add_theme_constant_override("icon_max_width", 26)
	map_button.custom_minimum_size = Vector2(0, 60)
	map_button.pressed.connect(func(): _map.open(_draft.phase, _draft.get("focus", "")))
	mission_box.add_child(map_button)
	var focus_box := _side_box(side, tr("Foco da rota"))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	focus_box.add_child(chips)
	var recommended := S.focus_recommended(c)
	var focus_icons := {S.FOCUS_WATER: "lobby-water", S.FOCUS_PARTS: "lobby-scrap", S.FOCUS_PROVISIONS: "lobby-food"}
	for focus_id in [""] + S.FOCI.map(func(f): return f.id):
		if not S.focus_available(c, focus_id):
			continue
		var id: String = focus_id
		var chip := _chip_button(S.focus_label(id))
		chip.name = "Focus_%s" % (id if id != "" else "basic")
		if focus_icons.has(id):
			chip.icon = AHKit.legacy_icon(focus_icons[id])
			chip.add_theme_constant_override("icon_max_width", 24)
		chip.tooltip_text = (S.focus_reward_text(id) if id != "" else tr("Sem objetivo extra.")) + (tr(" · recomendado") if id == recommended else "")
		chip.custom_minimum_size = Vector2(0, 56)
		if _draft.focus == id:
			for state in ["font_color", "font_hover_color", "font_focus_color"]:
				chip.add_theme_color_override(state, AHKit.AMBER)
			chip.add_child(AHKit.selected_overlay())
		chip.pressed.connect(func(): _draft.focus = id; refresh())
		chips.add_child(chip)
	# A recomendada numa linha à parte, com o pino: a escolha e a recomendação não se confundem.
	var advice := HBoxContainer.new()
	advice.add_theme_constant_override("separation", 10)
	focus_box.add_child(advice)
	advice.add_child(_icon("marker-here", 24, AHKit.AMBER))
	var reason := RichTextLabel.new()
	reason.bbcode_enabled = true
	reason.fit_content = true
	reason.scroll_active = false
	reason.custom_minimum_size = Vector2(420, 0)
	reason.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reason.add_theme_font_override("normal_font", AHKit.font())
	reason.add_theme_font_override("bold_font", AHKit.font(true))
	reason.add_theme_font_size_override("normal_font_size", AHKit.size("small"))
	reason.add_theme_font_size_override("bold_font_size", AHKit.size("small"))
	reason.add_theme_color_override("default_color", AHKit.TEXT)
	reason.text = "[b][color=#%s]%s[/color][/b] %s" % [AHKit.AMBER.to_html(false), tr("Recomendado: %s.") % S.focus_label(recommended),
		S.focus_reason(c, recommended).replace("[", "[lb]")]
	advice.add_child(reason)
	var food_box := _side_box(side, tr("Comida"))
	var food_row := HBoxContainer.new()
	food_row.add_theme_constant_override("separation", 10)
	food_box.add_child(food_row)
	var food_label := AHKit.label(tr("%d grátis + %d extras") % [J.FREE_FOOD, _draft.extra], "card_name", AHKit.TEXT, true)
	food_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	food_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	food_row.add_child(food_label)
	_button("−", func(): _draft.extra = maxi(0, _draft.extra - 1); refresh(), _draft.extra > 0, food_row)
	_button("+", func(): _draft.extra = mini(J.MAX_FOOD - J.FREE_FOOD, _draft.extra + 1); refresh(),
		_draft.extra < J.MAX_FOOD - J.FREE_FOOD and (_draft.extra + 1) * S.FOOD_COST <= S.quantity(c, "seeds"), food_row)
	food_box.add_child(AHKit.label(tr("%d sementes · cura na Mochila e no acampamento") % (_draft.extra * S.FOOD_COST), "small", AHKit.MUTED))


## Um aviso numa linha, com o ícone de alerta (a forma avisa também no daltonismo).
func _alert_line(text: String, color: Color = AHKit.alert_text()) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(AHKit.glyph("alert", 26, color))
	row.add_child(AHKit.label(text, "text", color, true))
	return row


## A gaveta termina acima de VOLTAR e cresce para cima quando o conteúdo pede (texto Maior, banco cheio).
func _fit_prep() -> void:
	if _prep == null or not is_instance_valid(_prep):
		return
	var bottom := AHStationFrame.BACK_Y - 14.0
	var height := maxf(560.0, _prep.get_combined_minimum_size().y)
	_prep.size = Vector2(1864, height)
	_prep.position = Vector2(28, maxf(8.0, bottom - height))


func _side_box(parent: Container, title: String) -> VBoxContainer:
	var column := _inset(parent)
	column.add_theme_constant_override("separation", 10)
	column.add_child(AHKit.label(title, "text", AHKit.AMBER, true, true))
	return column


## Um cartão da fila: o medalhão da posição, o rosto, o papel, a vida, as habilidades (apagadas as que não saem dali) e
## o aviso.
func _prep_slot(c: Dictionary, rank: int) -> Button:
	var hero_id: String = _draft.team[rank - 1] if rank - 1 < _draft.team.size() else ""
	var entry = S.hero(c, hero_id)
	var button := Button.new()
	button.name = "Slot%d" % rank
	AHKit.style_as(button, "upgrade")
	button.custom_minimum_size = Vector2(300, 262)
	var chosen := _prep_selected == rank - 1
	button.pressed.connect(func(): _prep_click(rank - 1))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 18
	box.offset_top = 14
	box.offset_right = -18
	box.offset_bottom = -12
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	if chosen:
		button.add_child(AHKit.selected_overlay())
	if entry == null:
		# No meio do cartão: no canto, a medalha da posição cobria o começo do texto.
		var empty := AHKit.label(tr("Posição vazia"), "row", AHKit.MUTED)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(empty)
		button.add_child(_rank_medal(rank))
		return button
	# A ficha ao apontar o cartão (#89): os traços, a relíquia e a velocidade, que o cartão não mostra.
	sheet.attach(button, func(): return AHCharacterSheet.from_hero(S.hero(Campaign.state, hero_id)))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	top.add_child(AHKit.portrait(U.face_texture(_hero_art(entry)), 76))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -2)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(names)
	var name_label := AHKit.label(entry.display_name, "card_name", AHKit.TEXT, true, true)
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	names.add_child(name_label)
	var hero_class = GameData.row("classes", entry.class_id)
	names.add_child(_wrapped(tr(hero_class.get("Role", "")) if hero_class else "", "small", AHKit.MUTED, false, 160.0))
	var life := HBoxContainer.new()
	life.add_theme_constant_override("separation", 10)
	life.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(life)
	life.add_child(AHKit.label(tr("Vida"), "small", AHKit.MUTED, false, true))
	life.add_child(AHKit.label("%d / %d" % [entry.hp, entry.max_hp], "row", AHKit.TEXT, true))
	var bar := AHKit.bar("hero", entry.hp, entry.max_hp, "", "small")
	bar.custom_minimum_size = Vector2(0, 22)
	box.add_child(bar)
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 8)
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icons)
	var usable := 0
	var abilities: Array = hero_class.get("AbilityIds", []) if hero_class else []
	for ability_id in abilities:
		var ability = GameData.combat.abilities.get(ability_id)
		var icon := TextureRect.new()
		var path := "res://art/combat/icons/%s.webp" % ability_id
		if ResourceLoader.exists(path):
			icon.texture = load(path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(52, 52)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var works: bool = ability != null and ability.OriginRanks.has(rank)
		if works:
			usable += 1
		else:
			icon.modulate = AHKit.DIM
		icons.add_child(icon)
	var note := ""
	var good := true
	if S.attacks_from_rank(entry.class_id, rank).is_empty():
		note = tr("Sem ataque desta posição")
		good = false
	elif entry.hp < entry.max_hp * 0.5:
		note = tr("Vida baixa: leve comida ou curativos")
		good = false
	elif entry.trauma:
		note = tr("Com trauma: começa com instinto alto")
		good = false
	else:
		note = tr("%d de %d habilidades daqui") % [usable, abilities.size()]
	var note_row := HBoxContainer.new()
	note_row.add_theme_constant_override("separation", 8)
	note_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(note_row)
	var tone: Color = AHKit.good() if good else AHKit.alert_text()
	note_row.add_child(AHKit.glyph("state_active" if good else "alert", 24, tone))
	var note_label := _wrapped(note, "small", tone, true, 230.0)
	note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note_row.add_child(note_label)
	button.add_child(_rank_medal(rank))
	# O cartão cresce com o conteúdo (o Maior): o aviso de baixo fica dentro dele e clicar ali escolhe o cartão.
	var grow := func(): button.custom_minimum_size.y = maxf(262.0, box.get_combined_minimum_size().y + 26.0)
	box.minimum_size_changed.connect(grow)
	grow.call()
	return button


## O medalhão da posição no canto do retrato.
func _rank_medal(rank: int) -> Control:
	var medal := AHKit.panel(AHKit.piece_of("medal", "level"))
	medal.custom_minimum_size = Vector2(46, 46)
	medal.size = Vector2(46, 46)
	medal.position = Vector2(4, 4)
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var number := AHKit.label(str(rank), "text", AHKit.AMBER, true)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	medal.add_child(number)
	return medal


## O aviso da equipe inteira: ninguém cura (leve curativos).
func _team_warning(c: Dictionary) -> String:
	for hero_id in _draft.team:
		var entry = S.hero(c, hero_id)
		if entry == null:
			continue
		var hero_class = GameData.row("classes", entry.class_id)
		for ability_id in (hero_class.get("AbilityIds", []) if hero_class else []):
			var ability = GameData.combat.abilities.get(ability_id)
			if ability != null and ability.HealRange.Max > 0:
				return ""
	return tr("Ninguém na equipe cura em combate: leve curativos e comida.")


func _prep_click(index: int) -> void:
	if _prep_selected < 0:
		_prep_selected = index
	elif _prep_selected == index:
		_prep_selected = -1
	else:
		_swap(_prep_selected, index)
		_prep_selected = -1
	refresh()


func _prep_leave() -> void:
	if _prep_selected < 0 or _prep_selected >= _draft.team.size() or _draft.team.size() <= 1:
		return
	_draft.team.remove_at(_prep_selected)
	_prep_selected = -1
	refresh()


func _prep_bench(hero_id: String) -> void:
	if _prep_selected < 0:
		return
	if _prep_selected < _draft.team.size():
		_draft.team[_prep_selected] = hero_id
	else:
		_draft.team.append(hero_id)
	_prep_selected = -1
	refresh()


func _depart() -> void:
	# O segundo clique em Partir, durante o fade da saída ou com o briefing aberto, já não parte de novo.
	if _draft.is_empty() or GameFlow.busy or briefing_open():
		return
	var c: Dictionary = Campaign.state
	# A partida conferida numa cópia (nada muda ainda): o briefing só abre para uma saída que vale.
	var error := S.confirm_departure(c.duplicate(true), _draft.team.duplicate(), _draft.extra, 0, _draft.phase, _draft.focus)
	if error != "":
		toast(error, true)
		return
	# O briefing (#88): quem pede fala antes de a equipe embarcar; pular também parte, Voltar fica na Preparação.
	var lines := AHBriefing.departure(c, _draft.phase, _draft.team)
	if not lines.is_empty():
		briefing = AHBriefingDialog.open(self, lines, tr("Partir"))
		briefing.cancel_on_back = true
		await briefing.finished
		var cancelled := briefing.cancelled
		briefing = null
		if cancelled or not is_inside_tree() or _draft.is_empty() or GameFlow.busy:
			return
	# A rota é a que o Mapa da Rede leu (#87): a semente fixada da fase; depois da partida, a fase ganha outra.
	var phase_id: String = _draft.phase
	error = S.confirm_departure(c, _draft.team.duplicate(), _draft.extra, AHNetworkRadar.route_seed(c, phase_id), phase_id, _draft.focus)
	if error != "":
		toast(error, true)
		return
	AHNetworkRadar.spend_seed(c, phase_id)
	_draft = {}
	Campaign.save()
	# A partida no vagão (#75): a equipe sentada no metrô a caminho da fase, depois o título dela.
	GameFlow.travel("street", AHWagonRide.departure_card(c))


func briefing_open() -> bool:
	return briefing != null and is_instance_valid(briefing)


## A partida na plataforma: a equipe em fila e o mesmo painel da Preparação (equipe, foco, suprimentos, confirmar).
func _departure_view() -> void:
	_heading(tr("Partida"), tr("A equipe espera na plataforma, da frente (direita) para trás."))
	_preparation(Campaign.state)


# ---------------------------------------------------------------- Cantina, Depósito, Forja, Pesquisa

## A Cantina: a conta da próxima volta por recurso (o que entra em verde, o que sai no tom normal) e o resultado num
## chip, em alerta só quando falta.
func _canteen(c: Dictionary) -> void:
	var f := S.forecast(c, 4)
	_section(tr("Próxima volta (equipe de 4)"))
	var food := _inset()
	food.get_parent().name = "Supplies"
	_resource_head(food, "lobby-food", tr("Suprimentos"))
	food.add_child(_account([[tr("%d no estoque") % f.food, AHKit.TEXT], [tr("+%d da Cantina") % f.food_produced, AHKit.good()],
		[tr("%d para os moradores") % f.food_civilians, AHKit.TEXT], [tr("a noite pede %d") % f.food_night_need, AHKit.TEXT]],
		_chip("lobby-food", tr("%d depois da noite") % f.food_after_night, AHKit.alert_text() if f.food_after_night < f.food_night_need else AHKit.TEXT)))
	if f.food_spoiled > 0:
		food.add_child(_wrapped(tr("Acima da capacidade do Depósito (%d): %d estragam.") % [f.food_capacity, f.food_spoiled], "small", AHKit.alert_text(), false, BODY_WIDTH - 40.0))
	var water := _inset()
	water.get_parent().name = "Water"
	_resource_head(water, "lobby-water", tr("Água"))
	water.add_child(_account([[tr("%d na estação") % f.water, AHKit.TEXT], [tr("+%d do coletor") % f.water_produced, AHKit.good()],
		[tr("a equipe e os moradores bebem %d") % f.water_consumed, AHKit.TEXT]],
		_chip("lobby-water", str(f.water_after), AHKit.alert_text() if f.thirsty else AHKit.TEXT)))
	if f.thirsty:
		water.add_child(_wrapped(tr("A água vai faltar na volta."), "small", AHKit.alert_text(), false, BODY_WIDTH - 40.0))
	var power := _inset()
	power.get_parent().name = "Power"
	_resource_head(power, "lobby-energy", tr("Energia"))
	var free := maxi(0, f.power_capacity - f.power_used)
	power.add_child(_account([[tr("%d de %d em uso") % [f.power_used, f.power_capacity], AHKit.TEXT]],
		_chip("lobby-energy", tr("%d livres") % free if free != 1 else tr("1 livre"), AHKit.TEXT if f.unpowered_rooms.is_empty() else AHKit.alert_text())))
	if not f.unpowered_rooms.is_empty():
		power.add_child(_wrapped(tr("Sem energia: %s.") % ", ".join(f.unpowered_rooms.map(func(id): return tr(S.room_def(id).name))), "small", AHKit.alert_text(), false,
			BODY_WIDTH - 40.0))
	if not c.station.last_cycle.is_empty():
		var cycle: Dictionary = c.station.last_cycle
		_section(tr("Último ciclo (%d)") % cycle.number)
		_text(tr("A Cantina produziu %d; os moradores comeram %d; estragaram %d; a água foi %d de consumo para %d do coletor%s.") % [
			cycle.food_produced, cycle.food_civilians, cycle.food_spoiled, cycle.water_consumed, cycle.water_produced,
			tr(" e faltou") if cycle.thirsty else ""], AHKit.MUTED, "small")


func _resource_head(box: VBoxContainer, icon_name: String, title: String) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	head.add_child(_icon(icon_name, 26, AHKit.TEXT))
	head.add_child(AHKit.label(title, "row", AHKit.TEXT, true, true))


## Uma conta numa linha que quebra: as partes separadas por ·, a seta (o ícone) e o chip do resultado.
func _account(parts: Array, result: Control) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	for i in parts.size():
		var label := AHKit.label(parts[i][0] + (" ·" if i < parts.size() - 1 else ""), "small", parts[i][1])
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		flow.add_child(label)
	# A seta fica sempre junto do chip do resultado.
	var tail := HBoxContainer.new()
	tail.add_theme_constant_override("separation", 8)
	tail.add_child(_icon("ui-arrow-right", 22, AHKit.AMBER))
	result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tail.add_child(result)
	flow.add_child(tail)
	return flow


## O Depósito: a barra de suprimentos (no alto, antes de MELHORAR).
func _supplies_bar(c: Dictionary) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_body.add_child(head)
	head.add_child(AHKit.label(tr("Suprimentos"), "small", AHKit.MUTED, true, true))
	var have := S.quantity(c, S.SUPPLIES)
	var top := S.supply_capacity(c)
	head.add_child(AHKit.label("%d / %d" % [have, top], "small", AHKit.alert_text() if have == 0 else AHKit.AMBER, true))
	var bar := AHKit.bar("amber", have, top, "", "small")
	bar.name = "SuppliesBar"
	bar.custom_minimum_size = Vector2(BODY_WIDTH, 20)
	_body.add_child(bar)


## O Depósito: o estoque em quadrados de recurso, as relíquias e as ferramentas.
func _depot(c: Dictionary) -> void:
	_section(tr("Estoque"))
	var grid := GridContainer.new()
	grid.name = "Stock"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	_body.add_child(grid)
	for spec in [["res-bandages", S.quantity(c, "bandages"), tr("Curativos")], ["lobby-seed", S.quantity(c, "seeds"), tr("Sementes")],
			["lobby-scrap", S.quantity(c, "scrap"), tr("Sucata")], ["lobby-fragment", S.quantity(c, "fragments"), tr("Fragmentos")],
			["lobby-water", int(c.station.water), tr("Água")]]:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		grid.add_child(cell)
		var tile := AHKit.chip("resource_tile")
		tile.custom_minimum_size = Vector2(112, 96)
		cell.add_child(tile)
		var center := CenterContainer.new()
		tile.add_child(center)
		center.add_child(_icon(spec[0], 46, AHKit.TEXT))
		var amount := AHKit.label(str(spec[1]), "row", AHKit.AMBER, true)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(amount)
		var name_label := AHKit.label(spec[2], "small", AHKit.TEXT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(name_label)
	var relics: Array = c.inventory.relics.map(func(id): return tr(GameData.row("relics", id).DisplayName) if GameData.row("relics", id) else id)
	_icon_line("relic-generic", tr("Relíquias no estoque: %s") % (", ".join(relics) if not relics.is_empty() else tr("nenhuma")))
	_icon_line("tool-generic", tr("Ferramentas: %s") % (", ".join(c.tools) if not c.tools.is_empty() else tr("nenhuma")))


func _icon_line(icon_name: String, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_body.add_child(row)
	row.add_child(_icon(icon_name, 24, AHKit.MUTED))
	row.add_child(_wrapped(text, "small", AHKit.TEXT, false, BODY_WIDTH - 40.0))


## Uma linha de lista (as relíquias, as melhorias de classe): o ícone, o nome, o efeito e, à direita, o custo ou a ação.
func _list_item(icon: Control, title: String, effect: String, dim: bool) -> HBoxContainer:
	var box := AHKit.panel(AHKit.piece_of("row", "list"))
	box.custom_minimum_size = Vector2(0, 72)
	_body.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(words)
	# O texto fica com a largura que sobra entre o ícone e o botão (o painel nunca passa da largura dele).
	words.add_child(_wrapped(title, "row", AHKit.TEXT, true, 0.0))
	words.add_child(_wrapped(effect, "small", AHKit.MUTED if dim else AHKit.TEXT, false, 0.0))
	return row


## A Forja: as relíquias com o efeito e o estoque e FABRICAR com o custo; vazia, o que ela libera, apagado.
func _forge(c: Dictionary, level: int) -> void:
	var cost := S.relic_cost(c)
	var scrap := S.quantity(c, "scrap")
	_section(tr("Relíquias") if level >= 1 else tr("Depois de recuperar"))
	for relic_id in GameData.table("relics").keys():
		var relic: Dictionary = GameData.row("relics", relic_id)
		var id: String = relic_id
		# O efeito: a primeira frase da descrição ("+3 de Vida Máxima."); o resto (a história da peça) fica no Alojamento.
		var about := tr(relic.get("Description", ""))
		var effect := about.substr(0, about.find(". ") + 1) if about.find(". ") > 0 else (about if about != "" else _relic_effect(relic))
		var row := _list_item(_icon(RELIC_ICONS.get(id, "relic-generic"), 40, AHKit.MUTED if level < 1 else AHKit.AMBER), tr(relic.DisplayName),
			effect if level < 1 else tr("%s · %s") % [effect, tr("Estoque: %d") % c.inventory.relics.count(id)], level < 1)
		row.get_parent().name = "Relic_%s" % id
		if level < 1:
			row.add_child(_chip("lobby-scrap", str(cost)))
			continue
		var craft := _chip_button(tr("Fabricar"))
		craft.name = "Craft"
		craft.icon = AHKit.legacy_icon("lobby-scrap")
		craft.add_theme_constant_override("icon_max_width", 22)
		craft.text = "%s · %d" % [tr("Fabricar"), cost]
		craft.custom_minimum_size = Vector2(0, 56)
		craft.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		craft.disabled = scrap < cost
		craft.tooltip_text = (tr("Faltam %d sucata") if cost - scrap == 1 else tr("Faltam %d sucatas")) % (cost - scrap) if scrap < cost else ""
		craft.pressed.connect(func(): _act(S.craft_relic(Campaign.state, id), tr("%s pronta. Equipe no Alojamento.") % tr(relic.DisplayName), "res://audio/ui/forge_confirm.ogg"))
		row.add_child(craft)


## O efeito da relíquia em poucas palavras, a partir dos números dela.
static func _relic_effect(relic: Dictionary) -> String:
	if int(relic.get("MaxHpBonus", 0)) != 0:
		return TranslationServer.translate("+%d Vida Máxima") % int(relic.MaxHpBonus)
	if int(relic.get("SpeedBonus", 0)) != 0:
		return TranslationServer.translate("+%d Velocidade") % int(relic.SpeedBonus)
	if int(relic.get("EventInstinctReduction", 0)) != 0:
		return TranslationServer.translate("−%d Instinto de eventos") % int(relic.EventInstinctReduction)
	return ""


## Os ramos da Pesquisa, na ordem do painel (a árvore da #94: Classe, Estação e Radar). Uma pesquisa sem "Branch" no
## research.json é de Classe (as melhorias de hoje).
const RESEARCH_BRANCHES := [["class", "Melhorias de classe"], ["station", "Estação"], ["radar", "Radar"]]


## O Centro de Pesquisa: as pesquisas de research.json por ramo, cada uma com o ícone, o nome, o efeito e PESQUISAR com
## o custo; vazio, o que ele libera, apagado. Pronto para a árvore da #94: os campos opcionais "Branch" (o ramo),
## "Requires" (o id da pesquisa que vem antes: até ela sair, a linha fica trancada com o nome dela), "CostScrap" (a
## sucata, além dos fragmentos) e "Expeditions" (quantas expedições leva) aparecem quando os dados os tiverem.
func _research(c: Dictionary, level: int) -> void:
	var table: Dictionary = GameData.table("research")
	for branch in RESEARCH_BRANCHES:
		var ids: Array = table.keys().filter(func(id): return String(table[id].get("Branch", "class")) == branch[0])
		if ids.is_empty():
			continue
		var title: String = tr(branch[1])
		_section(title if level >= 1 else tr("Depois de recuperar: %s") % title.to_lower())
		for research_id in ids:
			_research_row(c, level, research_id, table)


func _research_row(c: Dictionary, level: int, id: String, table: Dictionary) -> void:
	var row_data: Dictionary = table[id]
	var done: bool = c.researched_skills.has(row_data.get("SkillId", id))
	var needs := String(row_data.get("Requires", ""))
	var locked: bool = needs != "" and table.has(needs) and not c.researched_skills.has(table[needs].get("SkillId", needs))
	var art := "res://art/combat/icons/%s.webp" % row_data.get("SkillId", "")
	var icon := TextureRect.new()
	icon.texture = load(art) if ResourceLoader.exists(art) else AHKit.icon("room_research")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(52, 52)
	if level < 1 or locked:
		icon.modulate = AHKit.DIM
	var effect := tr(row_data.get("Description", ""))
	if int(row_data.get("Expeditions", 0)) > 0:
		effect += " · " + (tr("leva %d expedições") % int(row_data.Expeditions) if int(row_data.Expeditions) != 1 else tr("leva 1 expedição"))
	var row := _list_item(icon, tr(row_data.DisplayName), effect, level < 1 or done or locked)
	row.get_parent().name = "Research_%s" % id
	var price := int(row_data.get("CostFragments", 0))
	var scrap := int(row_data.get("CostScrap", 0))
	if level < 1:
		row.add_child(_chip("lobby-fragment", str(price)))
		return
	if done:
		row.add_child(_status_chip(tr("Pesquisado"), AHKit.good()))
		return
	if locked:
		var lock := _status_chip(tr("Requer %s") % tr(table[needs].DisplayName), AHKit.MUTED)
		lock.name = "Locked"
		row.add_child(lock)
		return
	var go := _chip_button(tr("Pesquisar"))
	go.name = "Research"
	go.icon = AHKit.legacy_icon("lobby-fragment")
	go.add_theme_constant_override("icon_max_width", 22)
	go.text = tr("%s · %d") % [tr("Pesquisar"), price] + (tr(" + %d sucata") % scrap if scrap > 0 else "")
	go.custom_minimum_size = Vector2(0, 56)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.disabled = S.quantity(c, "fragments") < price or S.quantity(c, "scrap") < scrap
	go.pressed.connect(func(): _act(S.research(Campaign.state, id), tr("%s concluída.") % tr(row_data.DisplayName), "res://audio/station/research_beep.ogg"))
	row.add_child(go)


# ---------------------------------------------------------------- Dormitório: a noite da volta

func _dormitory(c: Dictionary) -> void:
	var night: Dictionary = c.night
	match night.phase:
		"planning":
			_night_plan(c)
		"dawn":
			_section(tr("Amanhecer"), "sleep")
			_text(S.night_event_text(c))
			for result in night.results:
				var entry = S.hero(c, result.hero_id)
				if entry == null:
					continue
				_text((tr("%s ficou de vigia.") % entry.display_name) if result.watch else tr("%s: +%d de vida, −%d de instinto%s.") % [
					entry.display_name, result.hp_recovered, result.instinct_reduced, "" if result.fed else tr(" (sem comida)")], AHKit.TEXT, "small")
			_footer_primary(tr("Começar o dia"), "next_step", func():
				_act("" if S.finish_dawn(Campaign.state) else tr("Ainda não amanheceu."))
				if S.visit_pending(Campaign.state):
					open_service("train"))
		_:
			var empty := _inset()
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			empty.add_child(row)
			row.add_child(_icon("sleep", 40, AHKit.MUTED))
			row.add_child(_wrapped(tr("Ninguém precisa descansar agora. Depois de cada expedição, a equipe passa a noite aqui."), "small", AHKit.TEXT, false,
				BODY_WIDTH - 90.0))


## A Enfermaria (#121): os leitos, cada caído com a vida, onde se recupera e quando volta, o curativo no leito e, quando
## ninguém pode partir, esperar um dia.
func _infirmary(c: Dictionary, level: int) -> void:
	var fallen := S.fallen(c)
	var beds := S.infirmary_beds(c)
	if level >= 1:
		_section(tr("Leitos: %d de %d ocupados") % [fallen.filter(func(h): return S.in_bed(h)).size(), beds], "bed")
	if fallen.is_empty():
		var empty := _inset()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		empty.add_child(row)
		row.add_child(_icon("bed", 40, AHKit.MUTED))
		var empty_text := tr("Ninguém em recuperação. Quem cair numa expedição volta para cá antes de lutar de novo.") if level >= 1 \
			else tr("Ninguém em recuperação. Sem a Enfermaria, quem cair numa expedição se recupera no Dormitório.")
		row.add_child(_wrapped(empty_text, "small", AHKit.TEXT, false, BODY_WIDTH - 90.0))
		return
	if level < 1:
		_text(tr("Sem a Enfermaria, quem caiu se recupera devagar no Dormitório."), AHKit.MUTED, "small")
	for entry in fallen:
		_body.add_child(_fallen_card(c, entry))
	if S.rest_block(c) == "":
		_text(tr("Ninguém pode partir agora. Passar um dia na Estação gasta e produz como uma volta, e cada caído fica um dia mais perto."), AHKit.TEXT, "small")
		_footer_primary(tr("Esperar um dia"), "sleep", func(): _act(S.rest_day(Campaign.state), tr("Um dia passou na Estação.")))


func _fallen_card(c: Dictionary, entry: Dictionary) -> Control:
	var card := AHKit.panel(AHKit.piece_of("row", "list"))
	card.name = "Fallen_%s" % entry.id
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	var face := AHKit.portrait(U.face_texture(_hero_art(entry)), 56)
	face.modulate = AHKit.FALLEN
	top.add_child(face)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(names)
	names.add_child(_wrapped(entry.display_name, "row", AHKit.TEXT, true, 0.0))
	names.add_child(_wrapped(tr("Vida %d/%d · %s") % [entry.hp, entry.max_hp, tr("no leito") if S.in_bed(entry) else tr("no Dormitório")], "small", AHKit.MUTED, false, 0.0))
	var days := AHKit.label(S.return_text(S.recovery_days(entry)), "row", AHKit.alert_text(), true)
	days.name = "Days"
	days.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(days)
	var hero_id: String = entry.id
	var block := S.treat_block(c, hero_id)
	var bandage := S.recovery_rule("bandage")
	var days_off := int(bandage.get("Days", 1))
	var treat := _chip_button((tr("Curativo · −%d dia") if days_off == 1 else tr("Curativo · −%d dias")) % days_off)
	treat.name = "Treat"
	treat.icon = AHKit.icon("resource_bandages")
	treat.add_theme_constant_override("icon_max_width", 24)
	treat.custom_minimum_size = Vector2(0, 56)
	treat.disabled = block != ""
	treat.tooltip_text = block if block != "" else tr("Gasta %d curativo(s) (tem %d).") % [int(bandage.get("Cost", 1)), S.quantity(c, "bandages")]
	treat.pressed.connect(func(): _act(S.treat_fallen(Campaign.state, hero_id), tr("Curativo aplicado.")))
	box.add_child(treat)
	if block != "":
		box.add_child(_wrapped(block, "small", AHKit.MUTED, false, BODY_WIDTH - 40.0))
	return card


## O planejamento da noite (como o da Unreal): a contagem, o custo do suprimento extra, uma linha por herói com rosto,
## vida e instinto, DORMIR e VIGIAR e o que a noite rende para ele; no pé, fixos, quantos suprimentos a noite pede e
## INICIAR DESCANSO.
func _night_plan(c: Dictionary) -> void:
	var night: Dictionary = c.night
	var preview := S.night_preview(c)
	var counts := HBoxContainer.new()
	counts.add_theme_constant_override("separation", 10)
	_body.add_child(counts)
	counts.add_child(_status_chip(tr("Noite %d") % night.number, AHKit.AMBER))
	var watchers: int = preview.heroes.filter(func(row): return row.watch).size()
	counts.add_child(_status_chip(tr("%d dormindo · %d vigiando") % [preview.heroes.size() - watchers, watchers], AHKit.TEXT))
	var buy := _chip_button(tr("+1 suprimento · %d sementes") % S.SUPPLY_COST_SEEDS)
	buy.name = "BuySupply"
	buy.icon = AHKit.legacy_icon("lobby-food")
	buy.add_theme_constant_override("icon_max_width", 24)
	buy.disabled = S.quantity(c, "seeds") < S.SUPPLY_COST_SEEDS
	buy.custom_minimum_size = Vector2(0, 56)
	buy.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	buy.pressed.connect(func(): _act("" if S.buy_supplies(Campaign.state) else tr("Sementes insuficientes."), tr("Suprimento comprado.")))
	_body.add_child(buy)
	if night.thirsty:
		_text(tr("Faltou água na volta: o descanso rende menos instinto."), AHKit.alert_text(), "small")
	for row in preview.heroes:
		_body.add_child(_night_card(c, row, preview.heroes.size() > 1))
	var short: int = maxi(0, preview.needed - preview.available)
	var supplies := HBoxContainer.new()
	supplies.add_theme_constant_override("separation", 10)
	_footer.add_child(_divider())
	_footer.add_child(supplies)
	supplies.add_child(_icon("lobby-food", 26, AHKit.TEXT))
	supplies.add_child(AHKit.label(tr("Suprimentos: %d %s · %d %s") % [preview.needed, tr("necessário") if preview.needed == 1 else tr("necessários"), preview.available,
		tr("disponível") if preview.available == 1 else tr("disponíveis")], "text", AHKit.TEXT, true))
	if short > 0:
		_footer.add_child(_wrapped(tr("Faltam %d: os cartões marcados recuperam menos.") % short, "small", AHKit.alert_text(), false, BODY_WIDTH))
	_footer.add_child(_wrapped(tr("Quem vigia não descansa, mas protege os outros dos ruídos da noite."), "small", AHKit.MUTED, false, BODY_WIDTH))
	_footer_primary(tr("Iniciar descanso"), "sleep", func(): _act("" if S.resolve_night(Campaign.state) else tr("A noite não pode passar agora.")))


func _night_card(c: Dictionary, row: Dictionary, can_watch: bool) -> Control:
	var entry = S.hero(c, row.hero_id)
	var card := AHKit.panel(AHKit.piece_of("row", "list"))
	card.name = "Night_%s" % row.hero_id
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	top.add_child(AHKit.portrait(U.face_texture(_hero_art(entry)), 56))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(names)
	names.add_child(_wrapped(entry.display_name, "row", AHKit.TEXT, true, 0.0))
	names.add_child(_wrapped(tr("Vida %d/%d  Instinto %d") % [entry.hp, entry.max_hp, entry.instinct], "small", AHKit.MUTED, false, 0.0))
	var hero_id: String = row.hero_id
	for spec in [["Dormir", "sleep", not row.watch], ["Vigiar", "watch", row.watch]]:
		var button := _chip_button(tr(spec[0]))
		button.name = spec[0]
		button.icon = AHKit.icon(spec[1])
		button.add_theme_constant_override("icon_max_width", 24)
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if spec[2]:
			for state in ["font_color", "font_hover_color", "font_focus_color"]:
				button.add_theme_color_override(state, AHKit.AMBER)
			button.add_theme_color_override("icon_normal_color", AHKit.AMBER)
			button.add_child(AHKit.selected_overlay())
		var watch: bool = spec[0] == "Vigiar"
		button.disabled = watch and not can_watch
		button.pressed.connect(func():
			if watch != row.watch:
				S.set_watch(Campaign.state, hero_id if watch else "")
				station.commit())
		top.add_child(button)
	var outcome := ""
	if row.watch:
		outcome = tr("Vigiando · não descansa e protege dos ruídos")
	else:
		outcome = tr("%s · +%d de vida, %+d de instinto") % [tr("Alimentado") if row.fed else tr("Sem alimentação"), row.hp_gain, row.instinct_change]
	box.add_child(_wrapped(outcome, "small", AHKit.TEXT if row.fed or row.watch else AHKit.alert_text(), false, BODY_WIDTH - 40.0))
	return card


# ---------------------------------------------------------------- relatório da volta e trem

func _report() -> void:
	var report: Dictionary = Campaign.state.station.last_return
	if report.is_empty():
		close_panel()
		return
	# O refresh passa por aqui a cada mudança: a tela fica a mesma (com os detalhes abertos ou não).
	if is_instance_valid(_report_screen):
		return
	_report_screen = AHStationReport.make(report)
	_report_screen.enter_shelter.connect(func(): _enter_shelter_then(Callable()))
	_report_screen.room_requested.connect(func(id: String): _enter_shelter_then(func(): open_room(id)))
	add_child(_report_screen)
	move_child(_report_screen, _panel.get_index())


## A Sala dos Personagens: aberta uma vez e refeita a cada refresh (depois de treinar, trocar a relíquia, recrutar).
func _character_room() -> void:
	if is_instance_valid(_room_screen):
		_room_screen.rebuild()
		return
	_room_screen = AHCharacterRoom.make(self)
	add_child(_room_screen)
	move_child(_room_screen, _panel.get_index())
	station.focus_room_stage(S.CHARACTERS, AHCharacterRoom.LEFT.end.x, AHCharacterRoom.RIGHT.position.x)
	station.hide_residents(true)


## Abre as Opções ou o Plano a partir da Sala: fechar volta para a Sala.
func open_from_room(service: String) -> void:
	open_service(service)
	_back_to = S.CHARACTERS


func _close_room_screen() -> void:
	if is_instance_valid(_room_screen):
		_room_screen.queue_free()
		station.hide_residents(false)
	_room_screen = null


func _close_report_screen() -> void:
	if is_instance_valid(_report_screen):
		_report_screen.queue_free()
	_report_screen = null


## Fecha o relatório (visto) e segue: a noite, o trem ou o que foi pedido (then).
func _enter_shelter_then(then: Callable) -> void:
	Campaign.state.station.last_return.seen = true
	station.clear_lineup()
	station.commit()
	if Campaign.state.night.phase != "none":
		# A câmera volta à vista geral: o Próximo passo e o Dormitório em destaque dizem que a equipe precisa dormir,
		# e Preparar expedição fica bloqueado com o motivo (#76).
		close_panel()
	elif S.visit_pending(Campaign.state):
		open_service("train")
	elif then.is_valid():
		then.call()
	else:
		close_panel()


## O trem chegou: o retrato do civil, o nome e o papel, o ponto forte e o fraco, o pedido, o que muda na próxima volta e,
## no pé, ACOLHER (âmbar, com a tecla) e RECUSAR (de aço, sem tecla: Esc fecha o painel e não recusa sem querer).
func _train() -> void:
	var c: Dictionary = Campaign.state
	var train: Dictionary = c.station.train
	if train.phase == "departing":
		_header("train_arrival", tr("O trem parte"))
		_text(tr("As portas fecham; o trem volta para o túnel."), AHKit.MUTED)
		return
	if train.phase != "waiting":
		close_panel()
		return
	var who := S.civilian(train.candidate_id)
	_header("train_arrival", tr("O trem chegou"))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	_body.add_child(head)
	head.add_child(AHKit.portrait(_civilian_face(who.id), 116))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 2)
	head.add_child(names)
	names.add_child(_wrapped(tr("%s quer morar na Estação") % who.name, "small", AHKit.AMBER, true, 380.0))
	(names.get_child(-1) as Label).uppercase = true
	names.add_child(AHKit.label(who.name, "card_name", AHKit.TEXT, true))
	names.add_child(AHKit.label(tr("%s · %s") % [tr(who.role), tr(who.species)], "row", AHKit.AMBER))
	names.add_child(_wrapped(tr(who.trait), "text", AHKit.MUTED, false, 380.0))
	_trait_box("+", tr("Ponto forte"), tr(who.benefit), AHKit.good())
	_trait_box("−", tr("Ponto fraco"), tr(who.drawback), AHKit.alert_text())
	_trait_box("", tr("Pedido"), tr(who.need), AHKit.AMBER)
	var before := S.forecast(c, 4)
	var after := S.forecast_with(c, who.id, 4)
	_section(tr("Na próxima volta"))
	for spec in [[tr("Suprimentos depois da noite"), "lobby-food", before.food_after_night, after.food_after_night],
			[tr("Água depois da noite"), "lobby-water", before.water_after, after.water_after],
			[tr("Energia"), "lobby-energy", before.power_capacity, after.power_capacity]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_body.add_child(row)
		var label := AHKit.label(spec[0], "text", AHKit.TEXT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)
		# O antes e o depois; o que cai fica na cor de alerta (a água que a Dora bebe).
		var tone: Color = AHKit.alert_text() if int(spec[3]) < int(spec[2]) else AHKit.TEXT
		var chip := AHKit.chip("cost")
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		chip.add_child(line)
		line.add_child(_icon(spec[1], 22, tone))
		line.add_child(AHKit.label(str(spec[2]), "text", AHKit.TEXT, true))
		line.add_child(_icon("ui-arrow-right", 20, AHKit.AMBER))
		line.add_child(AHKit.label(str(spec[3]), "text", tone, true))
		row.add_child(chip)
	if c.night.phase != "none":
		_text(tr("A equipe ainda precisa passar a noite: decida depois do Dormitório, se preferir."), AHKit.MUTED, "small")
	var id: String = who.id
	_footer_primary(tr("Acolher %s") % who.name, "recruit", func(): _decide(id, true))
	var refuse := AHKit.button(tr("Recusar"), "secondary")
	refuse.name = "Refuse"
	refuse.custom_minimum_size = Vector2(BODY_WIDTH, 60)
	refuse.pressed.connect(func(): _decide(id, false))
	_footer.add_child(refuse)


## Uma caixa do trem: o quadradinho de + ou − (ou o ícone do pedido), o título na cor e o texto.
func _trait_box(sign: String, title: String, text: String, color: Color) -> void:
	var box := _inset()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	if sign != "":
		var mark := AHKit.chip("cost")
		mark.custom_minimum_size = Vector2(28, 28)
		var label := AHKit.label(sign, "text", color, true)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.add_child(label)
		head.add_child(mark)
	else:
		head.add_child(_icon("plan", 26, color))
	head.add_child(AHKit.label(title, "text", color, true, true))
	box.add_child(_wrapped(text, "text", AHKit.TEXT, false, BODY_WIDTH - 40.0))


## Reabre o painel do trem quando a cena acaba (a câmera no candidato).
func _watch_train() -> void:
	if not station.train_event.is_connected(_on_train_event):
		station.train_event.connect(_on_train_event)


func _on_train_event(name: String) -> void:
	if name == "camera_on_candidate" and current == "train":
		refresh()


func _decide(candidate_id: String, accept: bool) -> void:
	var c: Dictionary = Campaign.state
	var error := S.decide_candidate(c, candidate_id, accept)
	if error != "":
		toast(error, true)
		return
	var who := S.civilian(candidate_id)
	station.commit()
	toast((tr("%s vai morar na Estação.") % who.name) if accept else tr("%s segue no trem. Pode voltar numa próxima viagem.") % who.name)
	# O trem fecha e parte (o recusado volta para ele); acolhido, o civil fica e vai para o cômodo dele. O painel sai da
	# frente da cena e o resto espera o trem sumir no túnel.
	station.play_train_departure(not accept)
	_panel.visible = false
	await station.train_event_named("gone")
	S.finish_departure(c)
	station.commit()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	station.clear_candidate()
	station._place_residents(rng)
	# O jogador abriu outra coisa durante a partida (um cômodo, as Opções): ela fica aberta.
	if current != "train":
		return
	if Campaign.state.night.phase != "none":
		open_room(S.DORMITORY)
	else:
		close_panel()
