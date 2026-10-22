## HUD da Estação Raiz (o lobby do AHRefugeWidget, enxuto): identidade e recursos em cima, o menu dos cômodos à esquerda
## e, à direita, o painel do cômodo com a função, o estado, a melhoria e o serviço dele (elenco, preparação, forja,
## pesquisa, depósito, cantina, descanso), além do relatório da volta e do trem com um candidato. Tudo chama as regras
## de AHStationRules e grava pela Estação (station.commit()).
class_name AHRefugeHud
extends Control

const H := preload("res://scripts/ui/combat_hud.gd")
const U := preload("res://scripts/ui/ui_style.gd")
const S := preload("res://scripts/flow/station_rules.gd")
const J := preload("res://scripts/flow/journey_rules.gd")
const RESULT_NAMES := {"victory": "Vitória", "retreat": "Retirada", "fled": "Fuga", "defeat": "Derrota"}

var station: AHStation
var current := ""
var _title: Label
var _subtitle: Label
var _resources: HBoxContainer
var _menu: VBoxContainer
var _next_title: Label
var _next_text: Label
var _next_button: Button
var _pending: VBoxContainer
var _corner: HBoxContainer
var _overview_button: Button
## A seleção de cômodo da Unreal: só o cômodo apontado ganha os cantos dourados, o nome e o cartão embaixo à esquerda
## (com Gerenciar). O do próximo passo e o Dormitório com a noite pendente ficam com os cantos apagados.
var _room_marks: Control
var _room_tag: PanelContainer
var _room_tag_label: Label
var _room_card: PanelContainer
var _room_card_name: Label
var _room_card_role: Label
var _room_card_state: Label
var _hover_room := ""
var _room_rects := {}
## O cômodo escolhido pelo teclado ou pelo controle (setas e direcional); o mouse mexendo volta a mandar.
var _key_room := ""
var _last_mouse := Vector2(-1, -1)
var _key_hints: HBoxContainer
## Ocultar HUD (F2 ou Back no controle): a interface some para olhar a Estação; o aviso fica embaixo.
var _hud_hidden := false
var _hidden_hint: Label
var _next := {}
## A gaveta da Preparação e o cartão escolhido para trocar (-1: nenhum).
var _prep: PanelContainer
var _prep_selected := -1
## A relíquia escolhida na Forja (a lista à esquerda, o detalhe à direita).
var _forge_selected := ""
var _panel: PanelContainer
var _body: VBoxContainer
var _feedback: Label
var _feedback_tween: Tween
## Rascunho da Preparação: fase, equipe (da frente para trás), foco e suprimentos extras.
var _draft := {}
## Cartões sob cada um da fila na plataforma (relatório e partida), pelo id do herói.
var _tags: Control
var _tag_nodes := {}
var _lineup_signature := ""
## O candidato que o trem já trouxe nesta visita (a chegada toca uma vez).
var _arrived_candidate := ""
## Mapa de fases: Preparar expedição abre por cima de tudo; a fase escolhida vai para a Preparação.
var _map: AHPhaseMap


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A faixa escura do alto (como a barra da Unreal): o título e os recursos leem em cima de um cômodo claro.
	var shade := TextureRect.new()
	var fade := Gradient.new()
	fade.set_color(0, Color(U.INK, 0.85))
	fade.set_color(1, Color(U.INK, 0.0))
	var fade_texture := GradientTexture2D.new()
	fade_texture.gradient = fade
	fade_texture.fill_from = Vector2(0, 0)
	fade_texture.fill_to = Vector2(0, 1)
	shade.texture = fade_texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.position = Vector2.ZERO
	shade.size = Vector2(1920, 150)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_title = U.label("Estação Raiz", 36, U.GOLD, "display")
	_title.position = Vector2(32, 18)
	add_child(_title)
	_subtitle = U.label("", U.MIN_TEXT, U.MUTED)
	_subtitle.position = Vector2(34, 18 + U.px(48))
	add_child(_subtitle)
	# Em cima à direita: os materiais numa ficha só e Comida, Água e Energia com o que acontece na volta.
	_resources = HBoxContainer.new()
	_resources.add_theme_constant_override("separation", 22)
	_resources.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_resources)

	# À esquerda: o próximo passo com o botão principal e as pendências (a lista de doze botões saiu).
	_menu = VBoxContainer.new()
	_menu.position = Vector2(32, 112)
	_menu.custom_minimum_size = Vector2(420, 0)
	_menu.add_theme_constant_override("separation", 10)
	add_child(_menu)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", U.panel(0.9))
	_menu.add_child(card)
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 8)
	card.add_child(card_box)
	card_box.add_child(U.label("PRÓXIMO PASSO", 15, U.COPPER, "bold"))
	_next_title = U.label("", 26, U.TEXT, "bold")
	_next_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_title.custom_minimum_size = Vector2(390, 0)
	card_box.add_child(_next_title)
	_next_text = U.label("", 17, U.MUTED)
	_next_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_text.custom_minimum_size = Vector2(390, 0)
	card_box.add_child(_next_text)
	_next_button = Button.new()
	_next_button.custom_minimum_size = Vector2(0, 54)
	H.style_button(_next_button, U.GOLD)
	var gold := StyleBoxFlat.new()
	gold.bg_color = Color("d9ad62")
	gold.set_corner_radius_all(5)
	for state in ["normal", "focus"]:
		_next_button.add_theme_stylebox_override(state, gold)
	var gold_hover := gold.duplicate()
	gold_hover.bg_color = Color("f0cf8a")
	_next_button.add_theme_stylebox_override("hover", gold_hover)
	_next_button.add_theme_color_override("font_color", U.INK)
	_next_button.add_theme_color_override("font_hover_color", U.INK)
	_next_button.add_theme_color_override("font_focus_color", U.INK)
	_next_button.add_theme_font_override("font", U.font("bold"))
	_next_button.add_theme_font_size_override("font_size", AHUiStyle.px(22))
	_next_button.pressed.connect(_run_next)
	card_box.add_child(_next_button)
	_pending = VBoxContainer.new()
	_pending.add_theme_constant_override("separation", 6)
	_menu.add_child(_pending)

	# Embaixo à esquerda: a vista geral (com um cômodo aberto) e as Opções.
	_corner = HBoxContainer.new()
	_corner.position = Vector2(32, 1000)
	_corner.add_theme_constant_override("separation", 8)
	add_child(_corner)
	_overview_button = Button.new()
	_overview_button.text = "‹ Vista geral"
	_overview_button.custom_minimum_size = Vector2(190, 46)
	H.style_button(_overview_button)
	_overview_button.pressed.connect(close_panel)
	_corner.add_child(_overview_button)
	var options := Button.new()
	options.text = "Opções"
	options.custom_minimum_size = Vector2(150, 46)
	H.style_button(options)
	options.pressed.connect(func(): open_service("options"))
	_corner.add_child(options)
	var hide_button := Button.new()
	hide_button.text = "Ocultar HUD"
	hide_button.custom_minimum_size = Vector2(170, 46)
	H.style_button(hide_button)
	hide_button.pressed.connect(func(): set_hud_hidden(true))
	_corner.add_child(hide_button)

	_tags = Control.new()
	_tags.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tags)
	_build_room_selection()
	_build_key_hints()
	_hidden_hint = U.label("", 18, U.TEXT, "bold")
	_hidden_hint.modulate.a = 0.85
	_hidden_hint.visible = false
	get_parent().add_child.call_deferred(_hidden_hint)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", H.panel_style(0.9))
	_panel.position = Vector2(1210, 110)
	_panel.size = Vector2(676, 900)
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_body)
	_panel.visible = false

	_feedback = H.make_label("", 22, H.TEXT)
	_feedback.position = Vector2(380, 1024)
	_feedback.size = Vector2(800, 40)
	add_child(_feedback)

	_map = AHPhaseMap.new()
	_map.visible = false
	_map.phase_chosen.connect(_on_phase_chosen)
	_map.closed.connect(func(): _map.visible = false)
	add_child(_map)
	Tips.show_tip.call_deferred("station")


## Antes dos botões: a interface escondida volta com F2, Esc ou um clique; na vista geral, as setas (ou o direcional)
## andam entre os cômodos e Interagir abre o escolhido.
func _input(event: InputEvent) -> void:
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
	if current != "" or _map.visible:
		return
	for spec in [["move_left", Vector2.LEFT], ["move_right", Vector2.RIGHT], ["move_back", Vector2.UP], ["move_front", Vector2.DOWN]]:
		if event.is_action_pressed(spec[0], true):
			_step_room(spec[1])
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("interact") and _key_room != "":
		open_room(_key_room)
		get_viewport().set_input_as_handled()


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
	_hidden_hint.text = "%s mostra a interface" % U.key_name("hide_hud")
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


func _build_key_hints() -> void:
	_key_hints = HBoxContainer.new()
	_key_hints.add_theme_constant_override("separation", 16)
	_key_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for spec in [[["move_left", "move_right", "move_back", "move_front"], "cômodos"], [["interact"], "abrir"], [["hide_hud"], "ocultar"]]:
		var group := HBoxContainer.new()
		group.add_theme_constant_override("separation", 4)
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for action in spec[0]:
			group.add_child(U.key_cap(_arrow_name(action)))
		group.add_child(U.label(spec[1], 16, U.MUTED))
		_key_hints.add_child(group)
	add_child(_key_hints)


## As setas no lugar das letras de andar (a dica fala dos cômodos); as outras ações, a tecla delas.
static func _arrow_name(action: String) -> String:
	var arrows := {"move_left": "←", "move_right": "→", "move_back": "↑", "move_front": "↓"}
	return arrows.get(action, U.key_name(action))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and current != "" and not _map.visible:
		close_panel()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and current == "" and not _map.visible:
		var room := _room_at(event.position)
		if room != "":
			open_room(room)
			get_viewport().set_input_as_handled()


func refresh() -> void:
	var c: Dictionary = Campaign.state
	var f := S.forecast(c, 4)
	for child in _resources.get_children():
		_resources.remove_child(child)
		child.queue_free()
	_resources.add_child(_materials_chip(c))
	for vital in S.vitals(c, 4):
		_resources.add_child(_vital(vital))
	_resources.size = _resources.get_combined_minimum_size()
	_resources.position = Vector2(1888 - _resources.size.x, 16)
	var status: Array[String] = ["Ciclo %d" % c.station.cycle_number, "%d no elenco" % S.living(c).size()]
	if c.night.phase != "none":
		status.append("noite por resolver no Dormitório")
	if S.visit_pending(c):
		status.append("alguém espera na plataforma")
	_subtitle.text = " · ".join(status)
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


## Os materiais numa ficha só: o ícone e o número de cada um (o nome na dica do mouse).
func _materials_chip(c: Dictionary) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := U.panel(0.86, Color(U.COPPER, 0.45), 1)
	style.content_margin_left = 12
	style.content_margin_right = 12
	chip.add_theme_stylebox_override("panel", style)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	for spec in [["lobby-seed", "seeds", "Sementes: moeda da Estação (comida extra na partida, recrutas e o trauma)."],
			["lobby-scrap", "scrap", "Sucata: recupera cômodos e fabrica relíquias na Forja."],
			["lobby-fragment", "fragments", "Fragmentos: restos raros para pesquisas e melhorias."],
			["res-bandages", "bandages", "Curativos: +8 de vida, na expedição e no acampamento."]]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 5)
		item.tooltip_text = spec[2]
		item.mouse_filter = Control.MOUSE_FILTER_PASS
		item.add_child(_glyph(spec[0], 22, U.GOLD))
		item.add_child(U.label(str(S.quantity(c, spec[1])), 19, U.TEXT, "bold"))
		row.add_child(item)
	return chip


## Comida, Água ou Energia: ícone, nome, o valor e a linha do que acontece na volta (cor de alerta quando falta).
func _vital(vital: Dictionary) -> Control:
	var color: Color = U.DANGER if vital.warn else U.OK
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.tooltip_text = vital.tip
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var glyph := _glyph(vital.icon, 32, color if vital.warn else U.TEXT)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(glyph)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(column)
	column.add_child(U.label(vital.label, 15, U.MUTED, "bold"))
	column.add_child(U.label(vital.value, 22, color, "bold"))
	column.add_child(U.label(vital.note, 15, U.DANGER if vital.warn else U.MUTED))
	return box


func _glyph(icon: String, size: int, color: Color) -> TextureRect:
	var glyph := TextureRect.new()
	glyph.texture = load("res://art/ui/icons/%s.svg" % icon)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.custom_minimum_size = Vector2(size, size)
	glyph.modulate = color
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return glyph


## O próximo passo (AHStationRules.next_step) e as pendências; o canto com a vista geral e as Opções.
func _build_left(c: Dictionary) -> void:
	_next = S.next_step(c)
	_next_title.text = _next.title
	_next_text.text = _next.text
	_next_button.text = _next.button
	for child in _pending.get_children():
		_pending.remove_child(child)
		child.queue_free()
	if S.visit_pending(c) and _next.action != "train":
		_pending.add_child(_pending_row("O trem chegou: alguém espera na plataforma", func(): open_service("train"), U.GOLD))
	if c.night.phase != "none" and _next.action != "dormitory":
		_pending.add_child(_pending_row("A noite espera no Dormitório", func(): open_room(S.DORMITORY), U.VIOLET))
	if _next.action != "depart" and S.preparation_block(c) == "":
		_pending.add_child(_pending_row("Preparar expedição", open_map, U.COPPER))
	_pending.add_child(_pending_row("Plano da Estação: o que cada cômodo destrava", func(): open_service("plan"), U.MUTED))
	_menu.visible = current == "" or current == "options"
	_overview_button.visible = current != ""
	_corner.visible = current != S.PREPARATION or S.preparation_block(c) != ""
	_refresh_room_card()


func _pending_row(text: String, action: Callable, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(420, 44)
	H.style_button(button, color)
	var style: StyleBoxFlat = button.get_theme_stylebox("normal").duplicate()
	style.border_width_left = 4
	style.border_color = color
	button.add_theme_stylebox_override("normal", style)
	button.pressed.connect(action)
	return button


func _run_next() -> void:
	match _next.get("action", "depart"):
		"report":
			open_service("report")
		"dormitory":
			open_room(S.DORMITORY)
		"train":
			open_service("train")
		"room":
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
	_room_tag = PanelContainer.new()
	var tag_style := U.panel(0.92, U.GOLD, 1)
	tag_style.content_margin_top = 2
	tag_style.content_margin_bottom = 2
	tag_style.content_margin_left = 8
	tag_style.content_margin_right = 8
	_room_tag.add_theme_stylebox_override("panel", tag_style)
	_room_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room_tag_label = U.label("", 19, U.TEXT, "bold")
	_room_tag.add_child(_room_tag_label)
	_room_tag.visible = false
	_room_marks.add_child(_room_tag)
	# O cartão embaixo à esquerda: nome, papel, estado e Gerenciar.
	_room_card = PanelContainer.new()
	_room_card.add_theme_stylebox_override("panel", U.panel(0.92, Color(U.GOLD, 0.8), 1))
	_room_card.custom_minimum_size = Vector2(466, 0)
	_room_card.visible = false
	add_child(_room_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_room_card.add_child(row)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_room_card_name = U.label("", 24, U.TEXT, "bold")
	column.add_child(_room_card_name)
	_room_card_role = U.label("", 17, U.MUTED)
	_room_card_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_room_card_role.custom_minimum_size = Vector2(270, 0)
	column.add_child(_room_card_role)
	_room_card_state = U.label("", 16, U.GOLD)
	_room_card_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_room_card_state.custom_minimum_size = Vector2(270, 0)
	column.add_child(_room_card_state)
	var manage := Button.new()
	manage.text = "Gerenciar ›"
	manage.custom_minimum_size = Vector2(140, 46)
	manage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	manage.focus_mode = Control.FOCUS_NONE
	H.style_button(manage)
	manage.pressed.connect(func():
		if _hover_room != "":
			open_room(_hover_room))
	row.add_child(manage)


## O estado do cômodo numa linha: vazio, aberto, nível, o custo para recuperar ou a noite pendente.
func _room_state(c: Dictionary, id: String) -> String:
	var level := S.room_level(c, id)
	if id == S.DORMITORY and c.night.phase != "none":
		return "A noite espera aqui."
	var cost := S.next_level_cost(c, id)
	if level < 1:
		return "Vazio · recuperar por %s" % S.cost_text(cost) if not cost.is_empty() else "Vazio"
	return "Nível %d de %d" % [level, S.room_def(id).max_level] if S.room_def(id).max_level > 1 else "Aberto"


func _refresh_room_card() -> void:
	if _room_card == null:
		return
	var c: Dictionary = Campaign.state
	var show := _hover_room != "" and current == "" and not _map.visible
	_room_card.visible = show
	if not show:
		return
	_room_card_name.text = S.room_def(_hover_room).name
	_room_card_role.text = S.ROOM_ROLES.get(_hover_room, "")
	_room_card_state.text = _room_state(c, _hover_room)
	_room_card.size = _room_card.get_combined_minimum_size()
	_room_card.position = Vector2(32, 990 - _room_card.size.y)


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
		if over == null or over == self or over == _room_marks:
			hovered = _room_at(mouse)
		elif _room_card.visible and _room_card.get_global_rect().has_point(mouse):
			hovered = _hover_room
	if hovered != _hover_room:
		_hover_room = hovered
		_refresh_room_card()
	_room_marks.queue_redraw()
	_key_hints.visible = overview and not Settings.touch_visible()
	if _key_hints.visible:
		_key_hints.size = _key_hints.get_combined_minimum_size()
		_key_hints.position = Vector2(960 - _key_hints.size.x * 0.5, 1030)


func _draw_room_marks() -> void:
	_room_tag.visible = false
	if _room_rects.is_empty():
		return
	var c: Dictionary = Campaign.state
	# Os cantos apagados: o cômodo do próximo passo (dourado) e o Dormitório com a noite pendente (violeta).
	var hints := {}
	if _next.get("room", "") != "":
		hints[_next.room] = U.GOLD
	if c.night.phase != "none":
		hints[S.DORMITORY] = U.VIOLET
	for id in hints:
		if id != _hover_room and _room_rects.has(id):
			_corners(_room_rects[id], Color(hints[id], 0.5), 2.0, 18.0)
	if _hover_room == "" or not _room_rects.has(_hover_room):
		return
	var rect: Rect2 = _room_rects[_hover_room]
	_room_marks.draw_rect(rect, Color(U.GOLD, 0.06))
	_corners(rect, U.GOLD, 3.0, 26.0)
	_room_tag_label.text = S.room_def(_hover_room).name
	_room_tag.size = _room_tag.get_combined_minimum_size()
	_room_tag.position = rect.position + Vector2(10, -_room_tag.size.y * 0.5)
	_room_tag.visible = true


func _corners(rect: Rect2, color: Color, width: float, arm: float) -> void:
	var a := rect.position
	var b := rect.end
	for corner in [[a, Vector2(1, 1)], [Vector2(b.x, a.y), Vector2(-1, 1)], [Vector2(a.x, b.y), Vector2(1, -1)], [b, Vector2(-1, -1)]]:
		var p: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		_room_marks.draw_line(p, p + Vector2(arm * d.x, 0), color, width)
		_room_marks.draw_line(p, p + Vector2(0, arm * d.y), color, width)


func open_room(room_id: String) -> void:
	current = room_id
	if room_id == S.PREPARATION and _draft.is_empty():
		_reset_draft()
	station.focus_room(room_id)
	refresh()


func open_service(service: String) -> void:
	current = service
	match service:
		"report":
			Tips.show_tip("return")
			var report: Dictionary = Campaign.state.station.last_return
			station.show_report(report.get("team", []).filter(func(id): return S.hero(Campaign.state, id) != null and S.hero(Campaign.state, id).alive))
		"train":
			# O trem traz o candidato: chega do túnel uma vez por visita; depois ele só espera na plataforma.
			var train: Dictionary = Campaign.state.station.train
			if train.phase == "waiting" and not station.train_busy():
				station.open_train(train.candidate_id, _arrived_candidate != train.candidate_id)
				_arrived_candidate = train.candidate_id
	refresh()


func close_panel() -> void:
	current = ""
	_panel.visible = false
	_prep_selected = -1
	if _prep != null:
		_prep.visible = false
	station.clear_lineup()
	_lineup_signature = ""
	station.focus_overview()
	refresh()


## Preparar expedição (AAHHUD::OpenPhaseMap): com algo pendente (a noite, o trem), a Preparação diz o quê; senão, o mapa.
func open_map() -> void:
	if S.preparation_block(Campaign.state) != "":
		open_room(S.PREPARATION)
		return
	if _draft.is_empty():
		_reset_draft()
	_map.open(_draft.phase)


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
	var showing := current == "report" or current == "departure"
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


## O cartão sob cada um (o relatório no estilo XCOM 2 da Unreal): nome, vida e o estado; na partida, a posição.
func _make_tag(hero_id: String) -> Control:
	var entry = S.hero(Campaign.state, hero_id)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", H.panel_style(0.86))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Do tamanho do espaço de cada um na fila (2,1 m): os cartões não se sobrepõem.
	box.custom_minimum_size = Vector2(170, 0)
	box.size = Vector2(170, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	box.add_child(column)
	column.add_child(H.make_label(entry.display_name if entry else hero_id, 20, H.GOLD))
	if entry:
		column.add_child(H.make_label("Vida %d/%d" % [entry.hp, entry.max_hp], 16))
		if current == "departure":
			var rank: int = _draft.get("team", []).find(hero_id) + 1
			var attacks := S.attacks_from_rank(entry.class_id, rank)
			column.add_child(H.make_label("Posição %d" % rank, 15, H.MUTED))
			var attack := H.make_label(attacks[0] if not attacks.is_empty() else "sem ataque aqui", 15, H.MUTED if not attacks.is_empty() else Color(1.0, 0.6, 0.5))
			attack.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			attack.custom_minimum_size = Vector2(150, 0)
			column.add_child(attack)
		else:
			var state: Array[String] = ["%d expedições" % int(entry.get("completed_expeditions", 0))]
			if entry.trauma:
				state.append("trauma")
			elif entry.hp < entry.max_hp * 0.5:
				state.append("ferido")
			column.add_child(H.make_label(" · ".join(state), 15, H.MUTED))
	return box


func toast(text: String, error: bool = false) -> void:
	_feedback.text = text
	_feedback.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45) if error else H.GOLD)
	_feedback.modulate.a = 1.0
	if _feedback_tween:
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(3.2)
	_feedback_tween.tween_property(_feedback, "modulate:a", 0.0, 0.6)


## Aplica uma ação das regras: "" grava e atualiza; senão mostra o motivo.
func _act(error: String, success: String = "") -> void:
	if error != "":
		toast(error, true)
		return
	station.commit()
	if success != "":
		toast(success)


# ---------------------------------------------------------------- painel

func _show(key: String) -> void:
	for child in _body.get_children():
		child.queue_free()
	var c: Dictionary = Campaign.state
	if key == S.PREPARATION and S.preparation_block(c) == "" and S.room_level(c, S.PREPARATION) >= 1:
		_panel.visible = false
		_menu.visible = false
		_prep_drawer(c)
		Tips.show_tip("preparation")
		return
	if _prep != null:
		_prep.visible = false
	_panel.visible = true
	match key:
		"report":
			_report()
		"train":
			_train()
		"departure":
			_departure_view()
		"new_campaign":
			_new_campaign_view()
		"plan":
			_station_plan(c)
		"options":
			var options := AHOptionsPanel.new()
			options.width = 620
			options.allow_new_campaign = true
			options.closed.connect(close_panel)
			options.new_campaign_requested.connect(func(): open_service("new_campaign"))
			_body.add_child(options)
		_:
			_room(key)


## O plano da Estação: cada cômodo com o nível, o que faz, o que o próximo nível destrava e quanto custa.
func _station_plan(c: Dictionary) -> void:
	_heading("Plano da Estação", "A Estação cresce com o que as jornadas trazem. Sucata e fragmentos recuperam e melhoram os cômodos.")
	for room in AHStation.ROOMS:
		var id: String = room.id
		var room_def := S.room_def(id)
		var level := S.room_level(c, id)
		var cost := S.next_level_cost(c, id)
		var block := S.upgrade_block(c, id) if not cost.is_empty() else ""
		var box := PanelContainer.new()
		var ready: bool = not cost.is_empty() and block == ""
		box.add_theme_stylebox_override("panel", U.panel(0.7, U.GOLD if ready else Color(U.COPPER, 0.35), 2 if ready else 1))
		_body.add_child(box)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		box.add_child(column)
		var head := HBoxContainer.new()
		column.add_child(head)
		var name_label := U.label(room_def.name, 22, U.GOLD if ready else U.TEXT, "bold")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		head.add_child(U.label("vazio" if level < 1 else "nível %d de %d" % [level, room_def.max_level], 17, U.MUTED))
		var now := U.label(S.room_benefit(id, level) if level >= 1 else "Ainda vazio.", 17, U.TEXT)
		now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		now.custom_minimum_size = Vector2(600, 0)
		column.add_child(now)
		if not cost.is_empty():
			var next := U.label("%s: %s · %s%s" % ["Recuperar" if level == 0 else "Nível %d" % (level + 1), S.room_benefit(id, level + 1), S.cost_text(cost),
				"" if block == "" else " · " + block], 16, U.GOLD if ready else U.MUTED)
			next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			next.custom_minimum_size = Vector2(600, 0)
			column.add_child(next)
		var go := Button.new()
		go.text = "Ver %s" % room_def.name
		go.custom_minimum_size = Vector2(0, 38)
		H.style_button(go)
		go.pressed.connect(func(): open_room(id))
		column.add_child(go)


## Começar do zero (com confirmação): o save atual é substituído por uma campanha nova.
func _new_campaign_view() -> void:
	_heading("Nova campanha", "Recomeça a Estação, o elenco e as fases do zero.")
	_text("Todo o progresso salvo (fases concluídas, cômodos, recursos e heróis) é substituído por uma campanha nova.", 19, Color(1.0, 0.65, 0.5))
	_button("Cancelar", close_panel)
	_button("Começar do zero", func():
		Campaign.new_game()
		GameFlow.change_to("station"))


func _heading(text: String, subtitle: String = "") -> void:
	_body.add_child(H.make_label(text, 30, H.GOLD))
	if subtitle != "":
		_text(subtitle, 18, H.MUTED)


func _text(text: String, size: int = 19, color: Color = H.TEXT) -> Label:
	var label := H.make_label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(620, 0)
	_body.add_child(label)
	return label


func _section(text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_body.add_child(spacer)
	_body.add_child(H.make_label(text, 22, H.GOLD.lightened(0.2)))


func _button(text: String, action: Callable, enabled: bool = true, parent: Container = null) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.custom_minimum_size = Vector2(0, 44)
	# Numa linha (Trocar, ↑, −, +) o botão fica do tamanho do texto; sozinho, quebra o texto longo.
	if parent == null:
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		button.custom_minimum_size = Vector2(56, 44)
	H.style_button(button)
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
	_heading(room_def.name, ("Nível %d" % level) if level >= 1 else "Vazio")
	_text(S.room_benefit(room_id, level))
	var cost := S.next_level_cost(c, room_id)
	if not cost.is_empty():
		var block := S.upgrade_block(c, room_id)
		var verb := "Recuperar" if level == 0 else "Melhorar"
		_button("%s (%s)%s" % [verb, S.cost_text(cost), "" if block == "" else " · " + block],
			func(): _act(S.upgrade_room(Campaign.state, room_id, level), "%s: nível %d." % [room_def.name, level + 1]), block == "")
	for civilian_id in c.station.residents:
		var who := S.civilian(civilian_id)
		if who.room == room_id:
			_civilian_card(c, who)
	if level < 1 and room_id != S.DORMITORY:
		return
	match room_id:
		S.CHARACTERS:
			_characters(c)
		S.PREPARATION:
			_preparation(c)
		S.CANTEEN:
			_canteen(c)
		S.DEPOT:
			_depot(c)
		S.FORGE:
			_forge(c)
		S.RESEARCH:
			_research(c)
		S.DORMITORY:
			_dormitory(c)


func _civilian_card(c: Dictionary, who: Dictionary) -> void:
	_section("%s · %s (%s)" % [who.name, who.role, who.species])
	var working := S.civilian_working(c, who.id)
	_text(("Ponto forte: %s" % who.benefit) if working else "Sem comida ou água no último ciclo: o ponto forte está parado até a próxima volta.",
		18, H.TEXT if working else Color(1.0, 0.6, 0.5))
	_text("Ponto fraco: %s" % who.drawback, 18, H.MUTED)
	_text(("Pedido entregue: %s." % who.request_reward) if S.has_completed_request(c, who.id) else ("Pedido: %s" % who.need), 18, H.MUTED)


# ---------------------------------------------------------------- Sala dos Personagens

func _characters(c: Dictionary) -> void:
	_section("Elenco (%d de %d)" % [S.living(c).size(), S.MAX_ROSTER])
	for entry in S.living(c):
		var hero_class = GameData.row("classes", entry.class_id)
		var tags: Array[String] = ["Vida %d/%d" % [entry.hp, entry.max_hp], "Instinto %d" % entry.instinct,
			"%d expedições" % int(entry.get("completed_expeditions", 0))]
		if entry.trauma:
			tags.append("trauma")
		var relic = GameData.row("relics", entry.relic_id) if entry.relic_id != "" else null
		tags.append("relíquia: %s" % (relic.DisplayName if relic else "nenhuma"))
		_text("%s · %s" % [entry.display_name, hero_class.DisplayName if hero_class else entry.class_id], 20, H.GOLD.lightened(0.3))
		_text(" · ".join(tags), 17, H.MUTED)
		var row := _row()
		var hero_id: String = entry.id
		if entry.trauma:
			_button("Tratar trauma (%d sementes)" % S.TRAUMA_COST, func(): _act(S.treat_trauma(Campaign.state, hero_id), "Trauma tratado."), true, row)
		var stock: Array = c.inventory.relics
		if not stock.is_empty() or entry.relic_id != "":
			_button("Trocar relíquia", func(): _cycle_relic(hero_id), true, row)
	_section("Recrutar")
	for class_id in c.unlocked_classes:
		var hero_class = GameData.row("classes", class_id)
		var free := S.can_recruit_volunteer(c, class_id)
		var id: String = class_id
		_button("%s · %s" % [hero_class.DisplayName if hero_class else class_id, "voluntário, de graça" if free else "%d sementes" % S.RECRUIT_COST],
			func(): _recruit(id), free or S.quantity(c, "seeds") >= S.RECRUIT_COST)
	if not c.memorial.is_empty():
		_section("Memorial")
		for entry in c.memorial:
			_text("%s · %s · %s" % [entry.display_name, entry.get("mission_name", ""), entry.get("cause", "")], 17, H.MUTED)


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
	_act(S.equip_relic(c, hero_id, next), "%s: %s." % [entry.display_name, relic.DisplayName if relic else "sem relíquia"])


func _recruit(class_id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var result := S.recruit(Campaign.state, class_id, rng)
	_act(result.error, "%s chegou à Estação." % (S.hero(Campaign.state, result.get("hero_id", "")).display_name if result.error == "" else ""))
	if result.error == "":
		var rng2 := RandomNumberGenerator.new()
		rng2.randomize()
		station._place_residents(rng2)


# ---------------------------------------------------------------- Preparação

func _reset_draft() -> void:
	var c: Dictionary = Campaign.state
	var team: Array = c.preferred_formation.filter(func(id): return S.hero(c, id) != null and S.hero(c, id).alive)
	for entry in S.living(c):
		if team.size() < 4 and not team.has(entry.id):
			team.append(entry.id)
	# A fase sugerida: a primeira liberada que falta concluir (ou a última, com todas feitas).
	var next: String = J.PHASES[-1].id
	for info in J.PHASES:
		if S.phase_unlocked(c, info.id) and not c.completed_phases.has(info.id):
			next = info.id
			break
	_draft = {"phase": next, "team": team, "focus": S.focus_recommended(c), "extra": 0}


func _preparation(c: Dictionary) -> void:
	var block := S.preparation_block(c)
	if block != "":
		_text(block, 20, Color(1.0, 0.65, 0.5))
		if c.night.phase != "none":
			_button("Ir ao Dormitório", func(): open_room(S.DORMITORY))
		elif S.visit_pending(c):
			_button("Ir à plataforma", func(): open_service("train"))
		return
	if _draft.is_empty():
		_reset_draft()
	# Missão: o mapa de fases abre por cima; a fase escolhida volta para esta mesma escalação.
	_section("Missão")
	var mission := J.phase(_draft.phase)
	if not S.phase_unlocked(c, _draft.phase):
		_reset_draft()
		mission = J.phase(_draft.phase)
	_text("%s · nível %d · %s" % [mission.name, mission.level, J.DIFFICULTY_NAMES[mission.difficulty]], 20, H.GOLD)
	_button("Escolher no mapa", func(): _map.open(_draft.phase))
	_section("Equipe (da frente para trás)")
	for rank in 4:
		var hero_id: String = _draft.team[rank] if rank < _draft.team.size() else ""
		var entry = S.hero(c, hero_id)
		var row := _row()
		var label := H.make_label("%d. %s" % [rank + 1, entry.display_name if entry else "—"], 20, H.TEXT)
		label.custom_minimum_size = Vector2(250, 0)
		row.add_child(label)
		if entry and S.attacks_from_rank(entry.class_id, rank + 1).is_empty():
			label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
		var slot := rank
		_button("Trocar", func(): _cycle_slot(slot), S.living(c).size() > _draft.team.size() or _draft.team.size() > 1, row)
		if rank > 0:
			_button("↑", func(): _swap(slot, slot - 1), true, row)
	_section("Foco da rota")
	var recommended := S.focus_recommended(c)
	for focus_id in [""] + S.FOCI.map(func(f): return f.id):
		if not S.focus_available(c, focus_id):
			continue
		var id: String = focus_id
		var label := S.focus_label(id)
		if id != "":
			label += " · " + S.focus_reward_text(id)
		if id == recommended:
			label += " · recomendado"
		var button := _button(("▸ " if _draft.focus == id else "") + label, func(): _draft.focus = id; refresh())
		if _draft.focus == id:
			button.add_theme_color_override("font_color", H.GOLD)
	_text(S.focus_reason(c, _draft.focus), 17, H.MUTED)
	_section("Suprimentos")
	var row := _row()
	var food_label := H.make_label("%d de graça + %d extras (%d sementes)" % [J.FREE_FOOD, _draft.extra, _draft.extra * S.FOOD_COST], 19)
	food_label.custom_minimum_size = Vector2(400, 0)
	row.add_child(food_label)
	_button("−", func(): _draft.extra = maxi(0, _draft.extra - 1); refresh(), _draft.extra > 0, row)
	_button("+", func(): _draft.extra = mini(J.MAX_FOOD - J.FREE_FOOD, _draft.extra + 1); refresh(),
		_draft.extra < J.MAX_FOOD - J.FREE_FOOD and (_draft.extra + 1) * S.FOOD_COST <= S.quantity(c, "seeds"), row)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	_body.add_child(spacer)
	if current == "departure":
		_button("Voltar à Preparação", func():
			station.clear_lineup()
			_lineup_signature = ""
			open_room(S.PREPARATION))
	else:
		_button("Escalar a equipe na plataforma", open_departure)
	var depart := _button("Confirmar partida", _depart)
	depart.custom_minimum_size = Vector2(0, 56)
	depart.add_theme_font_size_override("font_size", AHUiStyle.px(24))


func _cycle_slot(rank: int) -> void:
	var c: Dictionary = Campaign.state
	var candidates: Array = S.living(c).map(func(h): return h.id)
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

## A arte de um herói (os recrutas usam a do fundador da mesma classe).
static func _hero_art(entry: Dictionary) -> Dictionary:
	return AHCombatArena.hero_art_of(entry.id).get("idle", {})


## A gaveta da Preparação: os quatro cartões no sentido da luta (o fundo à esquerda, a frente à direita), com rosto,
## papel, vida, as habilidades que funcionam daquela posição e os avisos; clicar em dois troca; os de fora ficam embaixo.
## À direita, a missão, o foco, a comida e Partir com o nome do destino.
func _prep_drawer(c: Dictionary) -> void:
	if _draft.is_empty():
		_reset_draft()
	if not S.phase_unlocked(c, _draft.phase):
		_reset_draft()
	if _prep == null:
		_prep = PanelContainer.new()
		_prep.add_theme_stylebox_override("panel", U.panel(0.94))
		_prep.position = Vector2(24, 512)
		_prep.size = Vector2(1872, 548)
		_tags.add_sibling(_prep)
	_prep.visible = true
	for child in _prep.get_children():
		_prep.remove_child(child)
		child.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	_prep.add_child(row)

	var lineup := VBoxContainer.new()
	lineup.add_theme_constant_override("separation", 10)
	lineup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lineup)
	var head := HBoxContainer.new()
	lineup.add_child(head)
	var back := Button.new()
	back.text = "‹ Vista geral"
	back.custom_minimum_size = Vector2(0, 36)
	H.style_button(back)
	back.pressed.connect(close_panel)
	head.add_child(back)
	var title := U.label("   EQUIPE · CLIQUE EM DOIS PARA TROCAR", 15, U.COPPER, "bold")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	head.add_child(U.label("← fundo · frente →", 16, U.MUTED))
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 12)
	lineup.add_child(slots)
	for rank in [4, 3, 2, 1]:
		slots.add_child(_prep_slot(c, rank))
	# Os de fora da equipe: com um cartão escolhido, clicar troca.
	var bench: Array = S.living(c).filter(func(h): return not _draft.team.has(h.id))
	if not bench.is_empty():
		var bench_row := HBoxContainer.new()
		bench_row.add_theme_constant_override("separation", 8)
		lineup.add_child(bench_row)
		bench_row.add_child(U.label("Fora da equipe:", 17, U.MUTED))
		for entry in bench:
			var id: String = entry.id
			var button := Button.new()
			button.text = "%s · %d/%d" % [entry.display_name, entry.hp, entry.max_hp]
			button.custom_minimum_size = Vector2(0, 40)
			H.style_button(button)
			button.disabled = _prep_selected < 0
			button.tooltip_text = "Escolha um cartão da equipe e clique aqui para trocar."
			button.pressed.connect(func(): _prep_bench(id))
			bench_row.add_child(button)
	var warning := _team_warning(c)
	if warning != "":
		lineup.add_child(U.label(warning, 17, U.GOLD))

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	side.custom_minimum_size = Vector2(440, 0)
	row.add_child(side)
	var mission := J.phase(_draft.phase)
	var place := AHScenarioWorld.display_of(mission.transit) + " e " + AHScenarioWorld.display_of(mission.map) if mission.transit != "" else AHScenarioWorld.display_of(mission.map)
	var mission_box := _side_box(side, "MISSÃO")
	mission_box.add_child(U.label(mission.name, 24, U.TEXT, "bold"))
	mission_box.add_child(U.label("Fase %d · %s · nível %d+ · %s" % [J.PHASES.map(func(p): return p.id).find(mission.id) + 1, J.DIFFICULTY_NAMES[mission.difficulty], mission.level, place], 16, U.MUTED))
	var map_button := Button.new()
	map_button.text = "Escolher no mapa"
	map_button.custom_minimum_size = Vector2(0, 34)
	H.style_button(map_button)
	map_button.pressed.connect(func(): _map.open(_draft.phase))
	mission_box.add_child(map_button)
	var focus_box := _side_box(side, "FOCO DA ROTA")
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	focus_box.add_child(chips)
	var recommended := S.focus_recommended(c)
	for focus_id in [""] + S.FOCI.map(func(f): return f.id):
		if not S.focus_available(c, focus_id):
			continue
		var id: String = focus_id
		var chip := Button.new()
		chip.text = S.focus_label(id) + (" ★" if id == recommended else "")
		chip.tooltip_text = (S.focus_reward_text(id) if id != "" else "Sem objetivo extra.") + (" · recomendado" if id == recommended else "")
		chip.custom_minimum_size = Vector2(0, 34)
		H.style_button(chip)
		chip.add_theme_font_size_override("font_size", AHUiStyle.px(17))
		if _draft.focus == id:
			chip.add_theme_color_override("font_color", U.GOLD)
			chip.add_theme_stylebox_override("normal", U.panel(0.92, U.GOLD))
		chip.pressed.connect(func(): _draft.focus = id; refresh())
		chips.add_child(chip)
	var reason := U.label(S.focus_reason(c, _draft.focus), 15, U.MUTED)
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.custom_minimum_size = Vector2(400, 0)
	focus_box.add_child(reason)
	var food_box := _side_box(side, "COMIDA")
	var food_row := HBoxContainer.new()
	food_row.add_theme_constant_override("separation", 8)
	food_box.add_child(food_row)
	var food_label := U.label("%d grátis + %d extras" % [J.FREE_FOOD, _draft.extra], 20, U.TEXT, "bold")
	food_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	food_row.add_child(food_label)
	_button("−", func(): _draft.extra = maxi(0, _draft.extra - 1); refresh(), _draft.extra > 0, food_row)
	_button("+", func(): _draft.extra = mini(J.MAX_FOOD - J.FREE_FOOD, _draft.extra + 1); refresh(),
		_draft.extra < J.MAX_FOOD - J.FREE_FOOD and (_draft.extra + 1) * S.FOOD_COST <= S.quantity(c, "seeds"), food_row)
	food_box.add_child(U.label("%d sementes · cura na Mochila e no acampamento" % (_draft.extra * S.FOOD_COST), 15, U.MUTED))
	var go := Button.new()
	go.text = "Partir · %s" % mission.name
	go.custom_minimum_size = Vector2(0, 56)
	H.style_button(go, U.GOLD)
	var gold := StyleBoxFlat.new()
	gold.bg_color = Color("d9ad62")
	gold.set_corner_radius_all(5)
	go.add_theme_stylebox_override("normal", gold)
	go.add_theme_stylebox_override("focus", gold)
	var hover := gold.duplicate()
	hover.bg_color = Color("f0cf8a")
	go.add_theme_stylebox_override("hover", hover)
	go.add_theme_color_override("font_color", U.INK)
	go.add_theme_color_override("font_hover_color", U.INK)
	go.add_theme_font_override("font", U.font("bold"))
	go.add_theme_font_size_override("font_size", AHUiStyle.px(22))
	go.pressed.connect(_depart)
	side.add_child(go)


func _side_box(parent: Container, title: String) -> VBoxContainer:
	var box := PanelContainer.new()
	var style := U.panel(0.7, Color(U.COPPER, 0.35), 1)
	box.add_theme_stylebox_override("panel", style)
	parent.add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	box.add_child(column)
	column.add_child(U.label(title, 14, U.COPPER, "bold"))
	return column


## Um cartão da fila: posição, rosto, papel, vida, as habilidades (apagadas as que não saem dali) e o aviso.
func _prep_slot(c: Dictionary, rank: int) -> Button:
	var hero_id: String = _draft.team[rank - 1] if rank - 1 < _draft.team.size() else ""
	var entry = S.hero(c, hero_id)
	var button := Button.new()
	button.custom_minimum_size = Vector2(318, 250)
	H.style_button(button)
	var chosen := _prep_selected == rank - 1
	if chosen:
		button.add_theme_stylebox_override("normal", U.panel(0.95, U.GOLD, 3))
	button.pressed.connect(func(): _prep_click(rank - 1))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12
	box.offset_top = 10
	box.offset_right = -12
	box.offset_bottom = -10
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var rank_label := U.label(str(rank), 40, Color(U.GOLD, 0.35), "display")
	rank_label.position = Vector2(270, 2)
	button.add_child(rank_label)
	if entry == null:
		box.add_child(U.label("Posição vazia", 20, U.MUTED))
		return button
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	var art := _hero_art(entry)
	if not art.is_empty():
		top.add_child(U.portrait(art, 72, U.GOLD if chosen else Color(1, 1, 1, 0.35)))
	var names := VBoxContainer.new()
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(names)
	names.add_child(U.label(entry.display_name, 26, U.TEXT, "display"))
	var hero_class = GameData.row("classes", entry.class_id)
	names.add_child(U.label(hero_class.get("Role", "") if hero_class else "", 15, U.MUTED))
	var hp := U.bar(Color(0.8, 0.27, 0.22), 10)
	hp.max_value = entry.max_hp
	hp.value = entry.hp
	box.add_child(hp)
	box.add_child(U.label("Vida %d/%d" % [entry.hp, entry.max_hp], 16, U.TEXT))
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 6)
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
			icon.modulate = Color(0.3, 0.3, 0.32)
		icons.add_child(icon)
	var note := ""
	var good := true
	if S.attacks_from_rank(entry.class_id, rank).is_empty():
		note = "! Sem ataque desta posição"
		good = false
	elif entry.hp < entry.max_hp * 0.5:
		note = "! Vida baixa: leve comida ou curativos"
		good = false
	elif entry.trauma:
		note = "! Com trauma: começa com instinto alto"
		good = false
	else:
		note = "✓ %d de %d habilidades daqui" % [usable, abilities.size()]
	var note_label := U.label(note, 16, U.OK if good else U.DANGER, "bold")
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.custom_minimum_size = Vector2(290, 0)
	box.add_child(note_label)
	if not good:
		button.add_theme_stylebox_override("normal", U.panel(0.95, U.DANGER if not chosen else U.GOLD, 2 if not chosen else 3))
	return button


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
	return "Ninguém na equipe cura em combate: leve curativos e comida."


func _prep_click(index: int) -> void:
	if _prep_selected < 0:
		_prep_selected = index
	elif _prep_selected == index:
		_prep_selected = -1
	else:
		_swap(_prep_selected, index)
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
	var c: Dictionary = Campaign.state
	var error := S.confirm_departure(c, _draft.team.duplicate(), _draft.extra, randi(), _draft.phase, _draft.focus)
	if error != "":
		toast(error, true)
		return
	_draft = {}
	Campaign.save()
	GameFlow.change_to("street")


## A partida na plataforma: a equipe em fila e o mesmo painel da Preparação (equipe, foco, suprimentos, confirmar).
func _departure_view() -> void:
	_heading("Partida", "A equipe espera na plataforma, da frente (direita) para trás.")
	_preparation(Campaign.state)


# ---------------------------------------------------------------- Cantina, Depósito, Forja, Pesquisa

func _canteen(c: Dictionary) -> void:
	var f := S.forecast(c, 4)
	_section("Próxima volta (equipe de 4)")
	_text("Suprimentos: %d no estoque, +%d da Cantina, %d para os moradores, a noite pede %d → %d depois da noite." % [
		f.food, f.food_produced, f.food_civilians, f.food_night_need, f.food_after_night])
	if f.food_spoiled > 0:
		_text("Acima da capacidade do Depósito (%d): %d estragam." % [f.food_capacity, f.food_spoiled], 18, Color(1.0, 0.65, 0.5))
	_text("Água: %d na estação, +%d do coletor, a equipe e os moradores bebem %d → %d%s." % [
		f.water, f.water_produced, f.water_consumed, f.water_after, " (vai faltar)" if f.thirsty else ""])
	_text("Energia: %d de %d.%s" % [f.power_used, f.power_capacity,
		"" if f.unpowered_rooms.is_empty() else " Sem energia: %s." % ", ".join(f.unpowered_rooms.map(func(id): return S.room_def(id).name))])
	if not c.station.last_cycle.is_empty():
		var cycle: Dictionary = c.station.last_cycle
		_section("Último ciclo (%d)" % cycle.number)
		_text("A Cantina produziu %d; os moradores comeram %d; estragaram %d; a água foi %d de consumo para %d do coletor%s." % [
			cycle.food_produced, cycle.food_civilians, cycle.food_spoiled, cycle.water_consumed, cycle.water_produced,
			" e faltou" if cycle.thirsty else ""], 18, H.MUTED)


func _depot(c: Dictionary) -> void:
	_section("Estoque")
	_text("Suprimentos: %d de %d" % [S.quantity(c, S.SUPPLIES), S.supply_capacity(c)])
	_text("Curativos: %d · Sementes: %d · Sucata: %d · Fragmentos: %d" % [S.quantity(c, "bandages"), S.quantity(c, "seeds"),
		S.quantity(c, "scrap"), S.quantity(c, "fragments")])
	_text("Água: %d" % c.station.water)
	var relics: Array = c.inventory.relics.map(func(id): return GameData.row("relics", id).DisplayName if GameData.row("relics", id) else id)
	_text("Relíquias no estoque: %s" % (", ".join(relics) if not relics.is_empty() else "nenhuma"))
	_text("Ferramentas: %s" % (", ".join(c.tools) if not c.tools.is_empty() else "nenhuma"))


const RELIC_ICONS := {"botao_cobre": "relic-copper-button", "pena_vidro": "relic-glass-feather", "coleira_lembranca": "relic-memory-collar"}


## Forja de Relíquias (como a da Unreal): à esquerda as relíquias com o ícone e o estoque; à direita a escolhida, com o
## efeito, a descrição, o estoque, a sucata e Fabricar (ou o que falta).
func _forge(c: Dictionary) -> void:
	var ids: Array = GameData.table("relics").keys()
	if not ids.has(_forge_selected):
		_forge_selected = ids[0] if not ids.is_empty() else ""
	_section("Relíquias")
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	_body.add_child(columns)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.custom_minimum_size = Vector2(250, 0)
	columns.add_child(list)
	for relic_id in ids:
		var relic: Dictionary = GameData.row("relics", relic_id)
		var id: String = relic_id
		var chosen := id == _forge_selected
		var button := Button.new()
		button.custom_minimum_size = Vector2(250, U.px(72))
		button.focus_mode = Control.FOCUS_NONE
		H.style_button(button)
		if chosen:
			button.add_theme_stylebox_override("normal", U.panel(0.92, U.GOLD, 2))
		button.pressed.connect(func():
			_forge_selected = id
			_show(current))
		var row := HBoxContainer.new()
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 12
		row.offset_right = -8
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(row)
		var glyph := _glyph(RELIC_ICONS.get(id, "relic-generic"), 36, U.GOLD if chosen else U.COPPER)
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
		var names := VBoxContainer.new()
		names.alignment = BoxContainer.ALIGNMENT_CENTER
		names.add_theme_constant_override("separation", 0)
		names.mouse_filter = Control.MOUSE_FILTER_IGNORE
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(names)
		var title := U.label(relic.DisplayName, 18, U.TEXT, "bold")
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.custom_minimum_size = Vector2(170, 0)
		names.add_child(title)
		names.add_child(U.label("Estoque: %d" % c.inventory.relics.count(id), 15, U.MUTED))
		list.add_child(button)
	if _forge_selected == "":
		return
	var relic: Dictionary = GameData.row("relics", _forge_selected)
	var detail := PanelContainer.new()
	detail.add_theme_stylebox_override("panel", U.panel(0.7, Color(U.COPPER, 0.4), 1))
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(detail)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	detail.add_child(box)
	box.add_child(_glyph(RELIC_ICONS.get(_forge_selected, "relic-generic"), 64, U.GOLD))
	var name_label := U.label(relic.DisplayName, 28, U.TEXT, "bold")
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(300, 0)
	box.add_child(name_label)
	box.add_child(U.label(_relic_effect(relic), 22, U.OK, "bold"))
	var about := U.label(relic.get("Description", ""), 17, U.MUTED)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size = Vector2(300, 0)
	box.add_child(about)
	var cost := S.relic_cost(c)
	var scrap := S.quantity(c, "scrap")
	box.add_child(U.label("Em estoque: %d · Sucata: %d" % [c.inventory.relics.count(_forge_selected), scrap], 17, U.TEXT))
	var id: String = _forge_selected
	var craft := Button.new()
	craft.text = "Fabricar · %d sucatas" % cost
	craft.custom_minimum_size = Vector2(0, 48)
	craft.disabled = scrap < cost
	H.style_button(craft, U.GOLD)
	craft.pressed.connect(func(): _act(S.craft_relic(Campaign.state, id), "%s pronta. Equipe na Sala dos Personagens." % relic.DisplayName))
	box.add_child(craft)
	if scrap < cost:
		box.add_child(U.label("Faltam %d %s" % [cost - scrap, "sucata" if cost - scrap == 1 else "sucatas"], 17, U.DANGER))


## O efeito da relíquia em poucas palavras, a partir dos números dela.
static func _relic_effect(relic: Dictionary) -> String:
	if int(relic.get("MaxHpBonus", 0)) != 0:
		return "+%d Vida Máxima" % int(relic.MaxHpBonus)
	if int(relic.get("SpeedBonus", 0)) != 0:
		return "+%d Velocidade" % int(relic.SpeedBonus)
	if int(relic.get("EventInstinctReduction", 0)) != 0:
		return "−%d Instinto de eventos" % int(relic.EventInstinctReduction)
	return ""


func _research(c: Dictionary) -> void:
	_section("Melhorias de classe")
	for research_id in GameData.table("research"):
		var row: Dictionary = GameData.row("research", research_id)
		var done: bool = c.researched_skills.has(row.SkillId)
		var id: String = research_id
		_text("%s · %s" % [row.DisplayName, row.get("Description", "")], 18, H.MUTED if done else H.TEXT)
		_button("Pesquisado" if done else "Pesquisar (%d fragmentos)" % int(row.CostFragments),
			func(): _act(S.research(Campaign.state, id), "%s concluída." % row.DisplayName), not done and S.quantity(c, "fragments") >= int(row.CostFragments))


# ---------------------------------------------------------------- Dormitório: a noite da volta

func _dormitory(c: Dictionary) -> void:
	var night: Dictionary = c.night
	match night.phase:
		"planning":
			_night_plan(c)
		"dawn":
			_section("Amanhecer")
			_text(S.night_event_text(c))
			for result in night.results:
				var entry = S.hero(c, result.hero_id)
				if entry == null:
					continue
				_text(("%s ficou de vigia." % entry.display_name) if result.watch else "%s: +%d de vida, −%d de instinto%s." % [
					entry.display_name, result.hp_recovered, result.instinct_reduced, "" if result.fed else " (sem comida)"], 18)
			_button("Começar o dia", func():
				_act("" if S.finish_dawn(Campaign.state) else "Ainda não amanheceu.")
				if S.visit_pending(Campaign.state):
					open_service("train"))
		_:
			_text("Ninguém precisa descansar agora. Depois de cada expedição, a equipe passa a noite aqui.", 18, H.MUTED)


## O planejamento da noite (como o da Unreal): um cartão por herói com rosto, vida e instinto, Dormir ou Vigiar e o que
## a noite rende para ele; embaixo, quantos suprimentos a noite pede e o botão Iniciar descanso.
func _night_plan(c: Dictionary) -> void:
	var night: Dictionary = c.night
	var preview := S.night_preview(c)
	var head := HBoxContainer.new()
	_body.add_child(head)
	var head_text := VBoxContainer.new()
	head_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_text)
	head_text.add_child(U.label("NOITE %d" % night.number, 15, U.COPPER, "bold"))
	var watchers: int = preview.heroes.filter(func(row): return row.watch).size()
	head_text.add_child(U.label("%d dormindo · %d vigiando" % [preview.heroes.size() - watchers, watchers], 18, U.TEXT, "bold"))
	var buy := Button.new()
	buy.text = "+1 suprimento · %d sementes" % S.SUPPLY_COST_SEEDS
	buy.disabled = S.quantity(c, "seeds") < S.SUPPLY_COST_SEEDS
	buy.custom_minimum_size = Vector2(0, 42)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	H.style_button(buy)
	buy.pressed.connect(func(): _act("" if S.buy_supplies(Campaign.state) else "Sementes insuficientes.", "Suprimento comprado."))
	head.add_child(buy)
	if night.thirsty:
		_text("Faltou água na volta: o descanso rende menos instinto.", 17, U.DANGER)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_body.add_child(grid)
	for row in preview.heroes:
		grid.add_child(_night_card(c, row, preview.heroes.size() > 1))
	var short: int = maxi(0, preview.needed - preview.available)
	_text("Suprimentos: %d %s · %d %s" % [preview.needed, "necessário" if preview.needed == 1 else "necessários", preview.available,
		"disponível" if preview.available == 1 else "disponíveis"], 18, U.TEXT)
	if short > 0:
		_text("Faltam %d: os cartões marcados recuperam menos." % short, 17, U.DANGER)
	_text("Quem vigia não descansa, mas protege os outros dos ruídos da noite.", 16, U.MUTED)
	var rest := Button.new()
	rest.text = "Iniciar descanso"
	rest.custom_minimum_size = Vector2(0, 54)
	H.style_button(rest, U.GOLD)
	rest.add_theme_color_override("font_color", U.GOLD)
	rest.pressed.connect(func(): _act("" if S.resolve_night(Campaign.state) else "A noite não pode passar agora."))
	_body.add_child(rest)


func _night_card(c: Dictionary, row: Dictionary, can_watch: bool) -> Control:
	var entry = S.hero(c, row.hero_id)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", U.panel(0.7, Color(U.COPPER, 0.4) if row.fed or row.watch else Color(U.DANGER, 0.6), 1))
	card.custom_minimum_size = Vector2(305, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	var art := _hero_art(entry)
	if not art.is_empty():
		top.add_child(U.portrait(art, 52, Color(1, 1, 1, 0.35)))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	names.add_child(U.label(entry.display_name, 20, U.TEXT, "bold"))
	names.add_child(U.label("Vida %d/%d · Instinto %d" % [entry.hp, entry.max_hp, entry.instinct], 15, U.MUTED))
	var hp := U.bar(Color(0.8, 0.27, 0.22), 6)
	hp.max_value = entry.max_hp
	hp.value = entry.hp
	names.add_child(hp)
	var choice := HBoxContainer.new()
	choice.add_theme_constant_override("separation", 6)
	box.add_child(choice)
	var hero_id: String = row.hero_id
	for spec in [["Dormir", not row.watch], ["Vigiar", row.watch]]:
		var button := Button.new()
		button.text = spec[0]
		button.custom_minimum_size = Vector2(0, 40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		H.style_button(button)
		if spec[1]:
			button.add_theme_stylebox_override("normal", U.panel(0.92, U.GOLD, 2))
			button.add_theme_color_override("font_color", U.GOLD)
		var watch: bool = spec[0] == "Vigiar"
		button.disabled = watch and not can_watch
		button.pressed.connect(func():
			if watch != row.watch:
				S.set_watch(Campaign.state, hero_id if watch else "")
				station.commit())
		choice.add_child(button)
	var outcome := ""
	if row.watch:
		outcome = "Vigiando · não descansa e protege dos ruídos"
	else:
		outcome = "%s · +%d de vida, %+d de instinto" % ["Alimentado" if row.fed else "Sem alimentação", row.hp_gain, row.instinct_change]
	var line := U.label(outcome, 15, U.MUTED if row.fed or row.watch else U.DANGER)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(280, 0)
	box.add_child(line)
	return card


# ---------------------------------------------------------------- relatório da volta e trem

func _report() -> void:
	var c: Dictionary = Campaign.state
	var report: Dictionary = c.station.last_return
	if report.is_empty():
		close_panel()
		return
	var phase := J.phase(report.get("phase_id", ""))
	var won: bool = report.result == "victory"
	_body.add_child(U.label(RESULT_NAMES.get(report.result, report.result), 44, U.GOLD if won else (U.MUTED if report.result == "retreat" else U.DANGER), "display"))
	_text("%s · %s" % [phase.get("name", ""), "fase concluída" if won else ("a equipe voltou antes do guardião" if report.result == "retreat" else "a equipe caiu")], 18, U.MUTED)
	# O que chegou, item a item (cada linha entra um pouco depois da outra).
	var percent := int(report.get("percent", 0))
	_section("O que chegou%s" % ("" if percent >= 100 else " (%d%% do achado)" % percent))
	var items: Array = []
	for spec in [["lobby-seed", "seeds", "semente", "sementes"], ["lobby-scrap", "scrap", "sucata", "sucatas"], ["lobby-fragment", "fragments", "fragmento", "fragmentos"],
			["lobby-water", "water", "água", "água"], ["lobby-food", "supplies", "suprimento", "suprimentos"]]:
		var amount := int(report.get(spec[1], 0))
		if amount > 0:
			items.append([spec[0], "+%d %s" % [amount, spec[2] if amount == 1 else spec[3]]])
	if report.get("request", "") != "":
		var who := S.civilian(report.request)
		items.append(["item-generic", "%s recebeu %s: %s" % [who.name, who.request_item, who.request_reward]])
	if items.is_empty():
		_text("Nada chegou desta vez.", 18, U.MUTED)
	for i in items.size():
		var row := _row()
		var glyph := TextureRect.new()
		glyph.texture = load("res://art/ui/icons/%s.svg" % items[i][0])
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.custom_minimum_size = Vector2(30, 30)
		glyph.modulate = U.GOLD
		row.add_child(glyph)
		var line := U.label(items[i][1], 22, U.TEXT, "bold")
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(560, 0)
		row.add_child(line)
		row.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(0.25 + 0.22 * i)
		tween.tween_property(row, "modulate:a", 1.0, 0.25)
		tween.tween_callback(func(): Sound.play("res://audio/world/find_coins.ogg", 0.35, 1.0 + 0.06 * i))
	# O que isso destrava na Estação agora.
	var unlocks: Array = []
	for room_id in S.NEXT_ROOMS:
		if not S.next_level_cost(c, room_id).is_empty() and S.upgrade_block(c, room_id) == "":
			unlocks.append(room_id)
	if not unlocks.is_empty():
		_section("Agora dá para")
		for room_id in unlocks:
			var id: String = room_id
			var level := S.room_level(c, id)
			_button("%s %s%s (%s)" % ["Recuperar" if level == 0 else "Melhorar", S.ROOM_ARTICLE.get(id, ""), S.room_def(id).name, S.cost_text(S.next_level_cost(c, id))],
				func(): _enter_shelter_then(func(): open_room(id)))
	# A equipe: quem fez o quê; o destaque ganha a estrela.
	_section("A equipe")
	var stats: Dictionary = report.get("stats", {})
	var best := ""
	var best_score := 0
	for hero_id in stats:
		var score: int = int(stats[hero_id].get("damage", 0)) + int(stats[hero_id].get("healing", 0)) * 2 + int(stats[hero_id].get("downs", 0)) * 5
		if score > best_score:
			best_score = score
			best = hero_id
	for hero_id in report.team:
		var entry = S.hero(c, hero_id)
		if entry == null:
			continue
		var row := _row()
		var art := _hero_art(entry)
		if not art.is_empty():
			var face := U.portrait(art, 56, U.GOLD if hero_id == best else (U.DANGER if not entry.alive else Color(1, 1, 1, 0.35)))
			if not entry.alive:
				face.modulate = Color(0.55, 0.55, 0.6)
			row.add_child(face)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)
		info.add_child(U.label("%s%s" % [entry.display_name, "  ★ destaque" if hero_id == best else ""], 20, U.GOLD if hero_id == best else U.TEXT, "bold"))
		var parts := PackedStringArray()
		var s: Dictionary = stats.get(hero_id, {})
		if int(s.get("damage", 0)) > 0:
			parts.append("causou %d de dano" % s.damage)
		if int(s.get("downs", 0)) > 0:
			parts.append("derrubou %d" % s.downs)
		if int(s.get("healing", 0)) > 0:
			parts.append("curou %d" % s.healing)
		var line: String = ("Vida %d/%d" % [entry.hp, entry.max_hp]) if entry.alive else "Não voltou: está no Memorial."
		if not parts.is_empty():
			line += " · " + ", ".join(parts)
		var detail := U.label(line, 17, U.MUTED if entry.alive else U.DANGER)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.custom_minimum_size = Vector2(540, 0)
		info.add_child(detail)
	var cycle: Dictionary = report.get("cycle", {})
	if not cycle.is_empty():
		_section("A Estação no ciclo %d" % cycle.number)
		_text("A Cantina produziu %d suprimentos; os moradores comeram %d; estragaram %d. Água: %d bebida, %d do coletor%s." % [
			cycle.food_produced, cycle.food_civilians, cycle.food_spoiled, cycle.water_consumed, cycle.water_produced,
			"; faltou para alguém" if cycle.thirsty else ""], 17, U.MUTED)
		if cycle.fragments_produced > 0:
			_text("A Cora trouxe %d fragmento." % cycle.fragments_produced, 17, U.MUTED)
	_button("Entrar no abrigo", func(): _enter_shelter_then(Callable()))


## Fecha o relatório (visto) e segue: a noite, o trem ou o que foi pedido (then).
func _enter_shelter_then(then: Callable) -> void:
	Campaign.state.station.last_return.seen = true
	station.clear_lineup()
	station.commit()
	if Campaign.state.night.phase != "none":
		open_room(S.DORMITORY)
	elif S.visit_pending(Campaign.state):
		open_service("train")
	elif then.is_valid():
		then.call()
	else:
		close_panel()


func _train() -> void:
	var c: Dictionary = Campaign.state
	var train: Dictionary = c.station.train
	if train.phase == "departing":
		_heading("O trem parte", "As portas fecham; o trem volta para o túnel.")
		return
	if train.phase != "waiting":
		close_panel()
		return
	var who := S.civilian(train.candidate_id)
	_heading("O trem chegou", "%s quer morar na Estação" % who.name)
	_text("%s · %s (%s). %s" % [who.name, who.role, who.species, who.trait])
	_text("Ponto forte: %s" % who.benefit)
	_text("Ponto fraco: %s" % who.drawback, 19, H.MUTED)
	_text("Pedido: %s" % who.need, 18, H.MUTED)
	var before := S.forecast(c, 4)
	var after := S.forecast_with(c, who.id, 4)
	_section("Na próxima volta")
	_text("Suprimentos depois da noite: %d → %d · Água depois: %d → %d%s · Energia: %d → %d" % [
		before.food_after_night, after.food_after_night, before.water_after, after.water_after,
		" (vai faltar)" if after.thirsty else "", before.power_capacity, after.power_capacity], 18)
	if c.night.phase != "none":
		_text("A equipe ainda precisa passar a noite: decida depois do Dormitório, se preferir.", 17, H.MUTED)
	var row := _row()
	var id: String = who.id
	_button("Acolher %s" % who.name, func(): _decide(id, true), true, row)
	_button("Recusar", func(): _decide(id, false), true, row)


func _decide(candidate_id: String, accept: bool) -> void:
	var c: Dictionary = Campaign.state
	var error := S.decide_candidate(c, candidate_id, accept)
	if error != "":
		toast(error, true)
		return
	var who := S.civilian(candidate_id)
	station.commit()
	toast(("%s vai morar na Estação." % who.name) if accept else "%s segue no trem. Pode voltar numa próxima viagem." % who.name)
	# O trem fecha e parte (o recusado vai junto); acolhido, o civil fica e vai para o cômodo dele.
	station.play_train_departure(not accept)
	await get_tree().create_timer(4.0).timeout
	S.finish_departure(c)
	station.commit()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	station.clear_candidate()
	station._place_residents(rng)
	if Campaign.state.night.phase != "none":
		open_room(S.DORMITORY)
	else:
		close_panel()
