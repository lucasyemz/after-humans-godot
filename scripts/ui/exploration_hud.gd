## HUD da exploração no kit (#60, docs/design/hud-exploracao.md): a moldura da rua, dos interiores e dos cenários.
## - No alto, à esquerda: a plaqueta do lugar (o nome e a jornada) e o cartão OBJETIVO DA ROTA.
## - No alto, no meio: o corredor numa faixa só (corridor_strip), com as dez casas ligadas por elos: resolvida (o tipo em
##   verde com o check no canto), a de agora (a moldura âmbar), conhecida (o tipo), ainda não alcançada ("?") e o guardião,
##   sempre conhecido, em alerta.
## - No alto, à direita: Comida, Curativos e Esperança numa ficha e, embaixo, o Achado.
## - Embaixo: a equipe em plaquinhas (retrato, nome, vida e a barra) e, à direita, a barra das teclas (a dica da primeira
##   jornada, #56; com um painel aberto, as teclas dele), MOCHILA e MENU.
## - Por cima: o aviso de interação (a etiqueta do cômodo com a tecla, que também aceita toque), a patrulha à frente, o
##   achado que voa até o alto, os avisos e os painéis (o evento, a escolha de risco, o Menu da expedição, a Mochila, as
##   Opções e o resultado).
class_name AHExplorationHud
extends Control

signal event_choice(choice_id: String)
signal event_closed
signal camp_food(hero_id: String)
signal camp_bandage(hero_id: String)
signal camp_leave
signal result_continue
signal menu_return
signal menu_requested
signal inventory_requested
signal new_campaign
## A formação (#129): o botão FORMAÇÃO pediu para abrir; dois heróis escolhidos trocam de lugar.
signal formation_requested
signal formation_swap(a: String, b: String)

const S = preload("res://scripts/ui/ui_style.gd")
const STEP_LABELS := {"start": "Partida", "combat": "Patrulha", "loot": "Suprimentos", "rest": "Descanso", "passage": "Passagem",
	"boss": "Guardião", "nick": "Encontro", "train": "Trem"}

## O lugar da jornada (a Rua ou o cenário): muda os textos da volta e do resultado.
## A altura do Concluir jornada; no acampamento, ele sobe para cima da barra (camp_hud._process).
const FINISH_Y := 852.0
var place := "Rua das Vitrines"
## O mapa do cenário (AHScenarioWorld.map_name); "" na Rua das Vitrines. Escolhe a ilustração do cartão de evento.
var map_id := ""
## As ilustrações dos eventos por mapa (a entrega #22 do Codex, docs/design/events.md): 1200x500, no topo do cartão.
const EVENT_ART := {"": "street", "ShopfrontStreet": "street", "RiverDock": "river_dock", "RootBridge": "root_bridge",
	"SealedShelter": "sealed_shelter", "TriageGate": "triage_gate", "FloodedDepot": "flooded_depot", "SewerDucts": "sewer_ducts"}
var _place_name: Label
var _place_sub: Label
var _goal_head: Label
var _goal_icon: TextureRect
var _goal_title: Label
var _goal_text: Label
var _goal: PanelContainer
var _plaque: PanelContainer
var _route_title: Label
var _route_row: HBoxContainer
var _route_panel: PanelContainer
var _supplies: HBoxContainer
var _loot_row: HBoxContainer
var _party_box: HBoxContainer
var _prompt: PanelContainer
var _prompt_label: Label
var _prompt_key: Control
var _prompt_check: TextureRect
## No toque, a bússola do Usar no lugar da tecla.
var _prompt_touch: TextureRect
var _prompt_world = null
var _toast: PanelContainer
## O aviso da ferramenta nova (#143): o ícone grande, o nome e o que ela faz; some sozinho ou com uma tecla.
var _tool_notice: PanelContainer
var _tool_tween: Tween
const TOOL_NOTICE_SECONDS := 5.0
## O selo NOVO no botão MOCHILA, até ela abrir.
var _bag_new: Control
var _toast_label: Label
var _toast_tween: Tween
## Uma frase que vai na frente de todo aviso até esta hora (Time.get_ticks_msec): o fôlego do tutorial que não pode
## sumir sob o anúncio do trecho nem o aviso do começo da luta, que chegam logo em seguida.
var _held_line := ""
var _held_until := 0
var _modal: PanelContainer
## O HUD do acampamento aberto (#77), null fora dele.
var camp_hud: AHCampHud
var _menu_button: Button
var _bag_button: Button
var _formation_button: Button
## A formação aberta nas plaquinhas da equipe (#129): a ordem mostrada, o herói do cursor e o escolhido (-1: nenhum).
var _formation := false
var _formation_ids: Array = []
var _formation_cursor := 0
var _formation_pick := -1
var _formation_head: PanelContainer
var _formation_keys: Control
## As placas da equipe na rua, na ordem da fila (o corredor passa): o número da posição sobre a cabeça de cada um.
var formation_cards: Array = []
var _formation_heads: Array[Control] = []
## A moldura do cursor e do escolhido, por fora da plaquinha (px), e o espaço entre as plaquinhas com a formação aberta.
const FORMATION_FRAME := 7.0
const FORMATION_GAP := 22
## O analógico: um empurrão anda uma casa (o intervalo mínimo entre dois passos do cursor, ms).
const FORMATION_STEP_MS := 220
var _formation_moved_at := -1000
var _finish_button: Button
var _markers: Array[Control] = []
var _marker_points: Array = []
var _patrol: PanelContainer
var _patrol_bar: AHKitBar
var _patrol_text: Label
var _patrol_icon: TextureRect
var _patrol_world = null
## A dica das teclas da rua (a primeira jornada, #56) e a das teclas com um painel aberto.
var _hint: Control
var _panel_keys: Control
var _panel_keys_kind := ""
## O toque da última moldura (trocado nas Opções, MOCHILA e MENU tiram ou põem a tecla).
var _touch_shown := false
## O Menu da expedição (#109): a largura, o centro (à direita do cartão do objetivo) e o pé (acima das cabeças).
const MENU_WIDTH := 660.0
const MENU_CENTER_X := 862.0
const MENU_BOTTOM := 720.0
## Os botões do canto (Mochila e Menu): embaixo na rua, no alto no acampamento.
const CORNER_Y := 1002.0
const CAMP_CORNER_Y := 14.0
## A barra das teclas, acima dos botões do canto.
const KEYS_Y := 932.0
var _hint_time := 0.0
var _weather := ""
## Os ícones dos trechos da rota (os nós do mapa da Unreal).
const STEP_ICONS := {"start": "node-start", "combat": "node-combat", "loot": "node-loot", "rest": "node-rest",
	"passage": "node-event", "boss": "node-boss", "nick": "node-event", "train": "node-boss"}
## A casa do corredor (o lado do quadrado) e o elo entre duas.
const CELL := 46.0
const LINK := 12.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Em cima à esquerda: a plaqueta do lugar e o cartão do objetivo.
	_plaque = AHKit.plaque()
	_plaque.name = "Place"
	_plaque.position = Vector2(28, 14)
	_plaque.custom_minimum_size = Vector2(440, 96)
	_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plaque)
	var plaque_row := HBoxContainer.new()
	plaque_row.add_theme_constant_override("separation", 14)
	plaque_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque.add_child(plaque_row)
	var route_glyph := AHKit.glyph("route", 50, AHKit.TEXT)
	route_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plaque_row.add_child(route_glyph)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -4)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque_row.add_child(names)
	_place_name = AHKit.label(tr(place), "panel_title", AHKit.TEXT, true, true)
	names.add_child(_place_name)
	_place_sub = AHKit.label("", "text", AHKit.MUTED)
	names.add_child(_place_sub)
	_goal = AHKit.panel_box("large")
	_goal.name = "Goal"
	_goal.position = Vector2(28, 120)
	_goal.custom_minimum_size = Vector2(440, 0)
	_goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_goal)
	var goal_box := VBoxContainer.new()
	goal_box.add_theme_constant_override("separation", 4)
	goal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal.add_child(goal_box)
	var goal_head := HBoxContainer.new()
	goal_head.add_theme_constant_override("separation", 8)
	goal_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_box.add_child(goal_head)
	_goal_icon = _icon("marker-here", 24, AHKit.AMBER)
	goal_head.add_child(_goal_icon)
	_goal_head = AHKit.label(tr("Objetivo da rota"), "small", AHKit.AMBER, true, true)
	goal_head.add_child(_goal_head)
	_goal_title = AHKit.label("", "row", AHKit.TEXT, true)
	_goal_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal_title.custom_minimum_size = Vector2(392, 0)
	goal_box.add_child(_goal_title)
	_goal_text = AHKit.label("", "small", AHKit.TEXT)
	_goal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal_text.custom_minimum_size = Vector2(392, 0)
	goal_box.add_child(_goal_text)

	# Em cima no meio: o corredor numa faixa só.
	_route_panel = AHKit.panel("corridor_strip")
	_route_panel.name = "Corridor"
	_route_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_route_panel)
	var route_box := VBoxContainer.new()
	route_box.add_theme_constant_override("separation", 4)
	route_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_route_panel.add_child(route_box)
	_route_title = AHKit.label("", "text", AHKit.TEXT, true, true)
	_route_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	route_box.add_child(_route_title)
	_route_row = HBoxContainer.new()
	_route_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_route_row.add_theme_constant_override("separation", 0)
	_route_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route_box.add_child(_route_row)

	# Em cima à direita: Comida, Curativos e Esperança numa ficha e, embaixo, o Achado.
	var right := VBoxContainer.new()
	right.name = "Supplies"
	right.add_theme_constant_override("separation", 6)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	_supplies = HBoxContainer.new()
	_supplies.alignment = BoxContainer.ALIGNMENT_END
	_supplies.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_supplies)
	_loot_row = HBoxContainer.new()
	_loot_row.alignment = BoxContainer.ALIGNMENT_END
	_loot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_loot_row)

	# Embaixo à esquerda: a equipe em plaquinhas.
	_party_box = HBoxContainer.new()
	_party_box.name = "Party"
	_party_box.position = Vector2(28, 970)
	_party_box.add_theme_constant_override("separation", 10)
	_party_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_party_box)

	# A patrulha à frente, avisada da borda direita antes de entrar na tela.
	_patrol = AHKit.panel_box("inset")
	_patrol.name = "Patrol"
	_patrol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_patrol.visible = false
	add_child(_patrol)
	var patrol_box := VBoxContainer.new()
	patrol_box.add_theme_constant_override("separation", 6)
	patrol_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_patrol.add_child(patrol_box)
	var patrol_head := HBoxContainer.new()
	patrol_head.add_theme_constant_override("separation", 8)
	patrol_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patrol_box.add_child(patrol_head)
	patrol_head.add_child(_icon("node-combat", 24, AHKit.AMBER))
	patrol_head.add_child(AHKit.label(tr("Patrulha à frente"), "small", AHKit.TEXT, true, true))
	patrol_head.add_child(_icon("ui-arrow-right", 22, AHKit.AMBER))
	_patrol_bar = AHKit.bar("amber", 0.0, 1.0, "", "small")
	_patrol_bar.custom_minimum_size = Vector2(220, 16)
	patrol_box.add_child(_patrol_bar)
	var patrol_state := HBoxContainer.new()
	patrol_state.add_theme_constant_override("separation", 6)
	patrol_state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patrol_box.add_child(patrol_state)
	_patrol_icon = AHKit.glyph("alert", 20, AHKit.AMBER)
	_patrol_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	patrol_state.add_child(_patrol_icon)
	_patrol_text = AHKit.label("", "small", AHKit.MUTED)
	patrol_state.add_child(_patrol_text)

	# Embaixo à direita: a barra das teclas (a da rua e a de um painel aberto), MOCHILA e MENU.
	_hint = _keys_bar([[["move_left", "move_right"], tr("Andar")], [["run"], tr("Correr")], [["interact"], tr("Interagir")]])
	_hint.name = "Hint"
	_set_panel_keys("choose")
	_menu_button = _corner_button(tr("Menu"), "lobby-settings", "menu", func(): menu_requested.emit())
	_menu_button.name = "Menu"
	_bag_button = _corner_button(tr("Mochila"), "room_depot", "inventory", func(): inventory_requested.emit())
	_bag_button.name = "Bag"
	_formation_button = _corner_button(tr("Formação"), "nav_characters", "formation", func(): formation_requested.emit())
	_formation_button.name = "Formation"
	_bag_new = AHInventoryPanel.new_tag()
	_bag_new.position.y = -14.0
	_bag_new.visible = false
	_bag_button.add_child(_bag_new)
	_place_corner.call_deferred()

	# Concluir jornada (o guardião vencido): o botão âmbar, sem tecla (o Esc é do MENU, e a volta também sai pelo Menu).
	_finish_button = AHKit.button(tr("Concluir jornada · Voltar à Estação"), "primary", Vector4(10, 0, 0, 0))
	_finish_button.name = "Finish"
	_finish_button.icon = AHKit.icon("station")
	_finish_button.add_theme_constant_override("icon_max_width", 30)
	_finish_button.add_theme_constant_override("h_separation", 10)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "icon_normal_color", "icon_hover_color"]:
		_finish_button.add_theme_color_override(state, AHKit.ON_AMBER)
	_finish_button.add_theme_font_size_override("font_size", AHKit.size("row"))
	_finish_button.custom_minimum_size = Vector2(0, 60)
	_finish_button.focus_mode = Control.FOCUS_NONE
	_finish_button.visible = false
	_finish_button.pressed.connect(func(): menu_return.emit())
	add_child(_finish_button)

	# O aviso de interação: a etiqueta do cômodo (a ponta para baixo, no objeto) com a tecla; também é botão (o toque).
	_prompt = AHKit.panel(AHKit.piece_of("tag", "room"))
	_prompt.name = "Prompt"
	_prompt.mouse_filter = Control.MOUSE_FILTER_STOP
	_prompt.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			accept_event()
			var use := InputEventAction.new()
			use.action = "interact"
			use.pressed = true
			Input.parse_input_event(use))
	var prompt_row := HBoxContainer.new()
	prompt_row.add_theme_constant_override("separation", 10)
	prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_child(prompt_row)
	_prompt_key = AHKitKey.make("", "E / A")
	_prompt_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prompt_row.add_child(_prompt_key)
	_prompt_touch = AHKit.glyph("next_step", 26, AHKit.AMBER)
	_prompt_touch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prompt_row.add_child(_prompt_touch)
	_prompt_check = AHKit.glyph("state_active", 26, AHKit.good())
	_prompt_check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prompt_row.add_child(_prompt_check)
	_prompt_label = AHKit.label("", "text", AHKit.TEXT, true)
	_prompt_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prompt_row.add_child(_prompt_label)
	_prompt.visible = false
	add_child(_prompt)

	# Os avisos (a busca, o trecho, o tempo): uma chapa no alto, que some sozinha.
	_toast = AHKit.panel_box("inset")
	_toast.name = "Toast"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	add_child(_toast)
	_toast_label = AHKit.label("", "row", AHKit.TEXT)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_child(_toast_label)


## A barra das teclas do painel aberto, conforme ele: "menu" (o menu, a Mochila e as Opções, que a tecla do Menu e o B
## fecham), "choose" (o evento e as escolhas, que pedem uma escolha) e "continue" (os resultados, só Interagir).
func _set_panel_keys(kind: String) -> void:
	if _panel_keys != null and _panel_keys_kind == kind:
		return
	if _panel_keys != null:
		_panel_keys.queue_free()
	var groups: Array = [[["interact"], tr("Continuar")]]
	if kind != "continue":
		groups = [[[tr("Setas")], tr("Navegar")], [["interact"], tr("Escolher")]]
		if kind == "menu":
			groups.append([["menu"], tr("Fechar")])
	_panel_keys = _keys_bar(groups)
	_panel_keys.name = "PanelKeys"
	_panel_keys.visible = false
	_panel_keys_kind = kind


## A barra das teclas: os grupos [[ações ou teclas], o que faz]; uma ação mostra a tecla dela e acompanha a troca.
func _keys_bar(groups: Array) -> PanelContainer:
	var bar := AHKit.panel(AHKit.piece_of("key", "bar"))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)
	for group in groups:
		for key in group[0]:
			row.add_child(AHKitKey.make(key) if InputMap.has_action(key) else AHKitKey.make("", key))
		row.add_child(AHKit.label(group[1], "text", AHKit.TEXT))
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(6, 0)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(gap)
	add_child(bar)
	return bar


## Um botão do canto (MOCHILA, MENU): o ícone, o nome e a tecla dentro (sem a tecla no toque).
func _corner_button(text: String, icon_name: String, key_action: String, action: Callable) -> Button:
	var button := AHKit.button(text, "secondary", Vector4(4, 0, 0, 0))
	button.icon = load(icon_name) if icon_name.begins_with("res://") else AHKit.legacy_icon(icon_name)
	button.add_theme_constant_override("icon_max_width", 30)
	button.add_theme_constant_override("h_separation", 10)
	button.add_theme_font_size_override("font_size", AHKit.size("row"))
	button.custom_minimum_size = Vector2(0, 64)
	button.focus_mode = Control.FOCUS_NONE
	var key := AHKitKey.make(key_action, "", "button")
	key.name = "Key"
	button.add_child(key)
	button.pressed.connect(action)
	add_child(button)
	AHStationReport.fit_key(button, 14.0)
	return button


## MOCHILA e MENU no canto de baixo à direita (no alto, no acampamento), com a tecla dentro só fora do toque.
func _place_corner() -> void:
	var touch := Settings.touch_visible()
	var right := 1892.0
	for button in [_menu_button, _bag_button, _formation_button]:
		if button == null:
			continue
		# A formação não vale no acampamento: o botão sai de lá (a fogueira tem a ordem dela).
		if button == _formation_button:
			button.visible = not camp_open()
			if not button.visible:
				continue
		var key: Control = button.get_node("Key")
		key.visible = not touch
		AHStationReport.fit_key(button, 14.0)
		if touch:
			for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
				if button.has_theme_stylebox_override(state):
					button.get_theme_stylebox(state).content_margin_right = 24.0
			button.reset_size()
			button.size = button.get_combined_minimum_size()
		button.position = Vector2(right - button.size.x, CAMP_CORNER_Y if camp_open() else CORNER_Y)
		right = button.position.x - 12.0


func _icon(name: String, size: float, tint: Color = Color.WHITE) -> TextureRect:
	var rect := TextureRect.new()
	# O recurso pintado (#125) fica com as cores dele; o resto é glifo para tingir.
	var painted := AHKit.painted(name)
	rect.texture = painted if painted != null else AHKit.legacy_icon(name)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.modulate = Color.WHITE if painted != null else tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## O tempo do lugar (a rua avisa quando muda).
func set_weather(text: String) -> void:
	_weather = text
	_refresh_place()


func _refresh_place() -> void:
	if _place_name == null:
		return
	_place_name.text = tr(place)
	var expedition = Campaign.state.get("session", {}).get("expedition")
	var parts := PackedStringArray()
	if expedition != null:
		var info := AHJourneyRules.phase(expedition.phase_id)
		# O tutorial (#144) não é uma jornada da campanha: é a abertura, num subsolo (sem clima).
		parts.append(tr("Abertura") if expedition.phase_id == AHTutorial.PHASE_ID else tr("Jornada %d") % (AHJourneyRules.PHASES.find(info) + 1))
	if _weather != "" and (expedition == null or expedition.phase_id != AHTutorial.PHASE_ID):
		parts.append(_weather)
	_place_sub.text = " · ".join(parts)


# ---------------------------------------------------------------- estado

## O tamanho do texto ou as cores mudaram nas Opções (AHUiStyle.retune): a rota e a equipe se reposicionam.
func restyle() -> void:
	refresh(Campaign.state)


## Atualiza o lugar, o objetivo, a rota, os recursos e a equipe a partir da campanha.
func refresh(campaign: Dictionary) -> void:
	var expedition = campaign.get("session", {}).get("expedition")
	if expedition == null:
		return
	if _bag_new != null:
		_bag_new.visible = not Array(campaign.get("new_tools", [])).is_empty()
	_refresh_place()
	var route: Dictionary = expedition.corridor
	# O objetivo: o foco escolhido na Preparação e o guardião no fim.
	var focus := AHStationRules.focus_def(expedition.get("focus", ""))
	var boss_step: int = route.steps.size()
	var done := false
	if expedition.phase_id == AHTutorial.PHASE_ID:
		# A abertura: fugir até o trem da plataforma.
		_goal_title.text = tr("Chegar ao trem (trecho %d)") % boss_step
		_goal_text.text = tr("A porta da contenção baixa atrás da equipe. A saída é a plataforma.")
	elif focus.is_empty():
		_goal_title.text = tr("Vencer o guardião (trecho %d)") % boss_step
		_goal_text.text = tr("Rota básica: o achado das buscas volta com a equipe.")
	elif expedition.get("objective_done", false):
		_goal_title.text = tr("%s: cumprido") % AHStationRules.focus_label(focus.id)
		_goal_text.text = tr("%s, entregue na volta. O guardião espera no trecho %d.") % [AHStationRules.focus_reward_text(focus.id), boss_step]
		done = true
	else:
		_goal_title.text = "%s · %s" % [AHStationRules.focus_label(focus.id), AHStationRules.focus_reward_text(focus.id)]
		_goal_text.text = (tr("Procure nas casas e nos caixotes.") if place == "Rua das Vitrines" else tr("Procure nos objetos marcados do caminho.")) + \
			tr(" O guardião espera no trecho %d.") % boss_step
	if expedition.objective_completed:
		_goal_title.text = tr("Guardião vencido")
		# Uma dica de tecla só: a volta sai pelo Menu (ou pelo Concluir jornada, que não tem tecla).
		_goal_text.text = tr("Abra um compartimento da carga do guardião antes de voltar.") if AHFightRewards.cargo_pending(campaign) \
			else tr("Fase concluída: volte à Estação com todo o achado pelo Menu (%s).") % S.key_name("menu")
		done = true
	# Cumprido: OBJETIVO CUMPRIDO com o check verde (a forma também diz).
	_goal_head.text = tr("Objetivo cumprido") if done else tr("Objetivo da rota")
	_goal_head.add_theme_color_override("font_color", AHKit.good() if done else AHKit.AMBER)
	_goal_icon.texture = AHKit.icon("objective_done") if done else AHKit.legacy_icon("marker-here")
	_goal_icon.modulate = AHKit.good() if done else AHKit.AMBER
	_goal.reset_size()
	# O corredor: cada casa com o tipo (as não alcançadas, "?"), ligadas por elos; a de agora com a moldura âmbar.
	_clear(_route_row)
	for index in route.steps.size():
		var step: Dictionary = route.steps[index]
		var known: bool = index <= route.index or step.resolved or step.type == "boss"
		if index > 0:
			var link := ColorRect.new()
			link.custom_minimum_size = Vector2(LINK, 3)
			link.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			link.color = AHKit.good() if route.steps[index - 1].resolved and index <= route.index else Color(AHKit.MUTED, 0.5)
			link.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_route_row.add_child(link)
		_route_row.add_child(_route_cell(step, index == route.index, known, route))
	var current: Dictionary = route.steps[route.index]
	var title := tr("Trecho %d de %d · %s") % [route.index + 1, route.steps.size(), _step_label(current)]
	if route.current_house >= 0:
		var site: Dictionary = route.sites[route.current_house]
		title = tr("Dentro %s") % (tr("do cinema") if site.shop == 2 else tr("da ") + tr(AHJourneyRules.SHOP_NAMES[site.shop]))
	_route_title.text = title
	_route_panel.reset_size()
	_route_panel.size = _route_panel.get_combined_minimum_size()
	_route_panel.position = Vector2(960 - _route_panel.size.x * 0.5, 14)
	_finish_button.visible = expedition.objective_completed and session_open(campaign) and not AHFightRewards.cargo_pending(campaign)
	# Preso pela direita: no texto Maior o botão cresce e não pode sair da tela.
	_finish_button.reset_size()
	_finish_button.position = Vector2(1892.0 - _finish_button.size.x, FINISH_Y)
	# Os recursos: Comida, Curativos e Esperança numa ficha, e o Achado embaixo.
	_clear(_supplies)
	var food: int = expedition.food
	var chip := AHKit.chip("resource")
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 22)
	chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(chip_row)
	chip_row.add_child(_supply("lobby-food", tr("Comida"), "%d/%d" % [food, AHJourneyRules.MAX_FOOD],
		tr("Da expedição: cura (Mochila, I) e o acampamento. O que sobrar não volta."), food == 0))
	chip_row.add_child(_supply("res-bandages", tr("Curativos"), str(campaign.inventory.bandages), tr("Do refúgio: +8 de vida. Voltam ao refúgio.")))
	chip_row.add_child(_supply("res-hope", tr("Esperança"), str(expedition.hope),
		tr("O ânimo da equipe: alto, a crise de instinto tende à superação; baixo, ao colapso.")))
	_supplies.add_child(chip)
	var loot_chip := AHKit.chip("cost")
	loot_chip.name = "Loot"
	loot_chip.tooltip_text = tr("Achado da jornada: sementes, sucata, fragmentos e suprimentos. Tudo chega com a fase concluída; metade, na retirada.")
	loot_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var loot_row := HBoxContainer.new()
	loot_row.add_theme_constant_override("separation", 8)
	loot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loot_chip.add_child(loot_row)
	loot_row.add_child(AHKit.label(tr("Achado"), "small", AHKit.MUTED, true, true))
	var specs := [["lobby-seed", expedition.loot.seeds], ["lobby-scrap", expedition.loot.scrap], ["lobby-fragment", expedition.loot.fragments]]
	# Os suprimentos (a carga do guardião, #91) só aparecem quando há algum: o achado de sempre não traz.
	if int(expedition.loot.get("supplies", 0)) > 0:
		specs.append(["lobby-food", int(expedition.loot.supplies)])
	for spec in specs:
		loot_row.add_child(_icon(spec[0], 22, AHKit.TEXT))
		loot_row.add_child(AHKit.label(str(spec[1]), "text", AHKit.TEXT, true))
	_clear(_loot_row)
	_loot_row.add_child(loot_chip)
	var right: Control = _supplies.get_parent()
	right.reset_size()
	right.size = right.get_combined_minimum_size()
	right.position = Vector2(1892.0 - right.size.x, 14)
	# A equipe: as plaquinhas com o retrato, o nome, a vida e a barra (e o instinto quando sobe); com a formação aberta,
	# as da formação.
	if _formation:
		_show_formation()
	else:
		_clear(_party_box)
		for hero_id in expedition.team:
			var hero = Campaign.hero(hero_id)
			if hero == null or not hero.alive:
				continue
			_party_box.add_child(_mate(hero))
		# Os levantados no mapa (#179) seguem com a equipe, sem lutar: um selo ao lado das plaquinhas.
		var carried: Array = AHJourneyRules.carried(campaign).map(func(id): return String(Campaign.hero(id).display_name))
		if not carried.is_empty():
			var carried_chip := _change_chip("bed", tr("A equipe carrega: %s") % ", ".join(carried), AHKit.TEXT)
			carried_chip.name = "Carried"
			carried_chip.size_flags_vertical = Control.SIZE_SHRINK_END
			_party_box.add_child(carried_chip)
		_party_box.reset_size()
		_party_box.position = Vector2(28, 1066 - _party_box.get_combined_minimum_size().y)
	_place_corner()


## Uma casa do corredor: o quadrado do retrato com o ícone do tipo; a de agora com a moldura âmbar, a resolvida com o
## tipo em verde e o check por cima do ícone, o guardião em alerta e a não alcançada com "?".
func _route_cell(step: Dictionary, now: bool, known: bool, route: Dictionary) -> Control:
	var cell := AHKit.panel("square_portrait")
	cell.custom_minimum_size = Vector2(CELL, CELL)
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var boss: bool = step.type == "boss"
	if known:
		var type: String = step.type
		# O guardião em alerta até ser vencido (#180); vencido, fica verde como os outros trechos resolvidos.
		var tint: Color = AHKit.good() if step.resolved else (AHKit.alert_text() if boss else (AHKit.AMBER if now else AHKit.TEXT))
		var glyph := _icon(STEP_ICONS.get(type, "node-event"), CELL * 0.56, tint)
		glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(glyph)
	else:
		var unknown := AHKit.label("?", "text", AHKit.MUTED, true)
		unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unknown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(unknown)
	if now:
		cell.add_child(AHKit.selected_overlay())
	# O check do resolvido; no trecho de agora só o do guardião vencido, que é o último e fica "agora" para sempre. Vem
	# depois da moldura de agora, por cima dela.
	if step.resolved and (not now or boss):
		# A casa é um PanelContainer: o check estica e fica centrado sobre o ícone, como nas outras resolvidas.
		cell.add_child(AHKit.glyph("state_active", 16, AHKit.good()))
	return cell


## O nome do trecho no título: o do tipo, ou "Guardião vencido" depois da vitória (#180).
func _step_label(step: Dictionary) -> String:
	if step.type == "boss" and step.resolved:
		return tr("Guardião vencido")
	return tr(STEP_LABELS.get(step.type, ""))


## Um recurso da ficha do alto: o ícone, o nome pequeno e o valor em âmbar (em alerta, quando acaba).
func _supply(icon: String, name: String, value: String, tip: String, warn: bool = false) -> HBoxContainer:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", 10)
	item.tooltip_text = tip
	item.mouse_filter = Control.MOUSE_FILTER_PASS
	item.add_child(_icon("alert" if warn else icon, 32, AHKit.alert_text() if warn else AHKit.TEXT))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", -2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(column)
	column.add_child(AHKit.label(name, "small", AHKit.MUTED, false, true))
	column.add_child(AHKit.label(value, "row", AHKit.alert_text() if warn else AHKit.AMBER, true))
	return item


## A plaquinha de um da equipe: o retrato, o nome, a vida e a barra (e a do instinto quando sobe).
func _mate(hero: Dictionary) -> PanelContainer:
	var box := AHKit.plaque()
	box.name = "Mate_%s" % hero.id
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var art: Dictionary = AHCombatArena.hero_art_of(hero.id, String(hero.get("art_variant", ""))).get("idle", {})
	row.add_child(AHKit.portrait(S.face_texture(art), 52))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.custom_minimum_size = Vector2(140, 0)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(top)
	var name_label := AHKit.label(hero.display_name, "text", AHKit.TEXT, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	top.add_child(AHKit.label("%d/%d" % [hero.hp, hero.max_hp], "small", AHKit.TEXT))
	var bar := AHKit.bar("hero", hero.hp, hero.max_hp, "", "small")
	bar.custom_minimum_size = Vector2(140, 22)
	info.add_child(bar)
	if int(hero.get("instinct", 0)) > 0:
		var instinct := AHKit.bar("instinct", hero.instinct, 200, "", "small")
		instinct.custom_minimum_size = Vector2(140, 10)
		instinct.tooltip_text = S.GLOSSARY.Instinto
		info.add_child(instinct)
	return box


## A formação (#129) nas plaquinhas de baixo: a posição de cada um (1 vai na frente), o cursor e o escolhido; clicar em
## dois (ou as setas e Interagir) troca os dois. A tecla da formação, Voltar ou o Menu fecham.
func open_formation() -> void:
	var expedition = Campaign.state.get("session", {}).get("expedition")
	if _formation or expedition == null:
		return
	_formation = true
	_formation_cursor = 0
	_formation_pick = -1
	_party_box.add_theme_constant_override("separation", FORMATION_GAP)
	Sound.play("res://audio/ui/panel_open.ogg")
	_show_formation()


func close_formation() -> void:
	if not _formation:
		return
	_formation = false
	_formation_pick = -1
	_party_box.add_theme_constant_override("separation", 10)
	for node in [_formation_head, _formation_keys, _formation_button.get_node_or_null("On")] + _formation_heads:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_formation_head = null
	_formation_keys = null
	_formation_heads.clear()
	Sound.play("res://audio/ui/panel_close.ogg")
	refresh(Campaign.state)


func formation_open() -> bool:
	return _formation


func _show_formation() -> void:
	var expedition: Dictionary = Campaign.state.session.expedition
	_formation_ids = Array(expedition.team).filter(func(id):
		var hero = Campaign.hero(id)
		return hero != null and hero.alive)
	_formation_cursor = clampi(_formation_cursor, 0, maxi(0, _formation_ids.size() - 1))
	_clear(_party_box)
	for i in _formation_ids.size():
		var mate := _mate(Campaign.hero(_formation_ids[i]))
		mate.mouse_filter = Control.MOUSE_FILTER_STOP
		mate.gui_input.connect(_formation_click.bind(i))
		# Por cima da plaquinha (o PanelContainer estica os filhos: o que fica solto vai num Control comum).
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		mate.add_child(holder)
		# O medalhão da posição no canto de cima (1 vai na frente), como na Preparação: pequeno e meio para fora, sem
		# tapar o retrato.
		var rank := _rank_medal(i + 1, 26.0)
		rank.name = "Rank"
		rank.position = Vector2(-12, -14)
		holder.add_child(rank)
		if i == _formation_pick:
			# O escolhido: o nome em âmbar, além da moldura.
			for label in mate.find_children("", "Label", true, false):
				if label.text == Campaign.hero(_formation_ids[i]).display_name:
					label.add_theme_color_override("font_color", AHKit.AMBER)
		# As molduras do escolhido e do cursor por fora da plaquinha: não tapam o nome nem a vida.
		if i == _formation_pick:
			holder.add_child(_outside(AHKit.selected_overlay()))
		if i == _formation_cursor:
			var frame := Panel.new()
			frame.name = "Cursor"
			frame.add_theme_stylebox_override("panel", AHKit.style(AHKit.piece_of("focus", "focus")))
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(_outside(frame))
		_party_box.add_child(mate)
	_party_box.reset_size()
	_party_box.position = Vector2(28, 1066 - _party_box.get_combined_minimum_size().y)
	# Em cima das plaquinhas, a faixa: FORMAÇÃO e o que a tecla faz agora ("E troca Nick e Íris de lugar").
	if _formation_head == null:
		_formation_head = AHKit.plaque()
		_formation_head.name = "FormationHead"
		_formation_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_formation_head)
	_clear(_formation_head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_formation_head.add_child(row)
	row.add_child(_icon("nav_characters", 26, AHKit.AMBER))
	row.add_child(AHKit.label(tr("Formação"), "row", AHKit.AMBER, true, true))
	var line: String = tr("da frente para trás · escolha dois para trocar")
	if _formation_pick >= 0 and _formation_pick != _formation_cursor:
		var names := [Campaign.hero(_formation_ids[_formation_pick]).display_name, Campaign.hero(_formation_ids[_formation_cursor]).display_name]
		# No toque não há tecla: o toque no segundo troca.
		line = tr("Troca %s e %s de lugar") % names if Settings.touch_visible() else tr("%s troca %s e %s de lugar") % ([S.key_name("interact")] + names)
	elif _formation_pick >= 0:
		line = tr("Trocar %s com quem? Escolha o outro") % Campaign.hero(_formation_ids[_formation_pick]).display_name
	row.add_child(AHKit.label(line, "text", AHKit.TEXT))
	_formation_head.reset_size()
	_formation_head.size = _formation_head.get_combined_minimum_size()
	_formation_head.position = Vector2(28, _party_box.position.y - _formation_head.size.y - 22)
	if _formation_keys == null:
		_formation_keys = _keys_bar([[[tr("Setas")], tr("Escolher")], [["interact"], tr("Trocar")], [["menu"], tr("Fechar")]])
		_formation_keys.name = "FormationKeys"
	# O botão FORMAÇÃO aceso enquanto ela está aberta.
	if _formation_button.get_node_or_null("On") == null:
		var lit := AHKit.selected_overlay()
		lit.name = "On"
		_formation_button.add_child(lit)
	# O número de cada um sobre a cabeça, na rua.
	while _formation_heads.size() < formation_cards.size():
		var medal := _rank_medal(_formation_heads.size() + 1, 40.0)
		medal.name = "Head" + str(_formation_heads.size() + 1)
		add_child(medal)
		_formation_heads.append(medal)


## Uma moldura em volta da plaquinha, FORMATION_FRAME px por fora.
func _outside(frame: Control) -> Control:
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = -FORMATION_FRAME
	frame.offset_top = -FORMATION_FRAME
	frame.offset_right = FORMATION_FRAME
	frame.offset_bottom = FORMATION_FRAME
	return frame


## O medalhão da posição (o mesmo da Preparação): o número em âmbar no medalhão do kit.
func _rank_medal(rank: int, side: float) -> Control:
	var medal := AHKit.panel(AHKit.piece_of("medal", "level"))
	medal.custom_minimum_size = Vector2(side, side)
	medal.size = Vector2(side, side)
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var number := AHKit.label(str(rank), "small", AHKit.AMBER, true)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	medal.add_child(number)
	return medal


func _formation_click(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_formation_cursor = index
		_formation_choose()


## Interagir (ou o clique): o primeiro escolhe; o segundo troca os dois; o mesmo de novo desfaz a escolha.
func _formation_choose() -> void:
	if _formation_pick < 0:
		_formation_pick = _formation_cursor
		Sound.play("res://audio/ui/confirm.ogg")
	elif _formation_pick == _formation_cursor:
		_formation_pick = -1
	else:
		var a: String = _formation_ids[_formation_pick]
		var b: String = _formation_ids[_formation_cursor]
		_formation_pick = -1
		formation_swap.emit(a, b)
	_show_formation()


func _formation_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventAction):
		return
	if event.is_action_pressed("formation") or S.is_back(event) or event.is_action_pressed("menu"):
		close_formation()
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left") or event.is_action_pressed("move_right") \
			or event.is_action_pressed("ui_right"):
		var now := Time.get_ticks_msec()
		if now - _formation_moved_at >= FORMATION_STEP_MS or not event is InputEventJoypadMotion:
			_formation_moved_at = now
			var step := -1 if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left") else 1
			_formation_cursor = posmod(_formation_cursor + step, maxi(1, _formation_ids.size()))
			_show_formation()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_formation_choose()
	# Com a formação aberta, nenhuma tecla passa para a rua (andar, Mochila, Interagir).
	get_viewport().set_input_as_handled()


## O aviso de interação: perto do que se usa (where, no mundo), ou embaixo no meio quando não tem lugar. "E  Vasculhar"
## mostra a tecla (E / A, ou só o texto no toque); sem a tecla, o que já foi feito, com o check e o texto apagado.
func show_prompt(text: String, where = null) -> void:
	_prompt.visible = text != ""
	var usable := text.begins_with("E  ")
	if usable:
		text = text.substr(3)
	var touch := Settings.touch_visible()
	_prompt_key.visible = usable and not touch
	_prompt_touch.visible = usable and touch
	(_prompt_key.get_child(0) as Label).text = tr("%s / A") % S.key_name("interact")
	_prompt_check.visible = not usable and text != ""
	_prompt_label.text = text
	_prompt_label.add_theme_color_override("font_color", AHKit.TEXT if usable else AHKit.MUTED)
	_prompt_world = where
	_prompt.reset_size()
	_prompt.size = _prompt.get_combined_minimum_size()


func has_prompt() -> bool:
	return _prompt.visible


func prompt_rect() -> Rect2:
	return _prompt.get_global_rect() if _prompt.visible else Rect2()


## O achado de uma busca vira momento: cada item sobe da equipe num chip âmbar e voa para o Achado no alto.
## gains: [[ícone, texto]], where: o ponto no mundo de onde sai.
func loot_burst(gains: Array, where: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or gains.is_empty():
		return
	var view := get_viewport_rect().size
	var start := camera.unproject_position(where) * Vector2(1920.0 / view.x, 1080.0 / view.y)
	var target := _loot_row.global_position + Vector2(_loot_row.size.x * 0.5, 16)
	for i in gains.size():
		var chip := AHKit.panel(AHKit.piece_of("chip", "cost"), AHKit.AMBER_LIGHT)
		chip.name = "Gain"
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(row)
		row.add_child(_icon(gains[i][0], 26, AHKit.AMBER))
		row.add_child(AHKit.label(gains[i][1], "row", AHKit.AMBER, true))
		add_child(chip)
		chip.size = chip.get_combined_minimum_size()
		chip.pivot_offset = chip.size * 0.5
		chip.position = start - chip.size * 0.5 + Vector2(0, -44 * i)
		chip.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(0.18 * i)
		tween.tween_property(chip, "modulate:a", 1.0, 0.15)
		tween.parallel().tween_property(chip, "position:y", chip.position.y - 60, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.5)
		tween.tween_property(chip, "position", target - chip.size * 0.5, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(chip, "scale", Vector2(0.4, 0.4), 0.55)
		tween.tween_callback(chip.queue_free)


## As marcas sobre o que dá para usar por perto (o corredor manda a cada quadro): o losango âmbar dos nós do mapa.
func set_markers(points: Array) -> void:
	if camp_open():
		# No acampamento, sem as marcas dos objetos da sala (a escolha ali é o herói).
		points = []
	_marker_points = points
	while _markers.size() < points.size():
		var mark := _icon("marker-available", 22, AHKit.AMBER)
		mark.size = Vector2(22, 22)
		add_child(mark)
		move_child(mark, 0)
		_markers.append(mark)
	for i in _markers.size():
		_markers[i].visible = i < points.size()


## A patrulha do trecho: a suspeita dela e se já avistou (null esconde). O aviso só aparece com ela fora da tela.
func set_patrol(where, meter: float, detected: bool) -> void:
	_patrol_world = where
	_patrol_bar.set_value(meter, 1.0)
	_patrol_bar.kind = "enemy" if detected else "amber"
	_patrol_text.text = tr("avistou a equipe!") if detected else (tr("desconfiada") if meter > 0.25 else tr("não viu a equipe"))
	var tone: Color = AHKit.alert_text() if detected else (AHKit.AMBER if meter > 0.25 else AHKit.MUTED)
	_patrol_text.add_theme_color_override("font_color", tone)
	_patrol_icon.modulate = tone
	_patrol_icon.visible = meter > 0.25 or detected


## Teclado e controle (#5): com um painel aberto (menu, Mochila, evento, escolha, acampamento, resultado), Interagir
## confirma o botão com foco, além de Enter e do A; Voltar (B, Backspace) fecha o menu, a Mochila e as Opções (os
## eventos e o resultado pedem uma escolha).
func _input(event: InputEvent) -> void:
	if _formation:
		_formation_input(event)
		return
	if modal_open() and S.press_focused(_modal, event):
		get_viewport().set_input_as_handled()
	# O aviso da ferramenta sai com qualquer tecla, clique ou toque (sem engolir: andar continua andando).
	if tool_notice_shown() and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton
			or event is InputEventScreenTouch) and event.is_pressed():
		hide_tool_notice()


func _unhandled_input(event: InputEvent) -> void:
	if modal_open() and _modal.has_meta("menu") and S.is_back(event) and not event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		close_modal()


func _process(delta: float) -> void:
	if modal_open():
		S.keep_focus(_modal)
	# A ferramenta que chegou (a busca, o evento): o aviso, uma de cada vez, sem painel aberto por cima e fora do
	# acampamento (o HUD dele ocupa a tela; o aviso espera a equipe levantar).
	var notices: Array = Campaign.state.get("tool_notices", [])
	if not notices.is_empty() and not modal_open() and not camp_open() and not tool_notice_shown() and is_visible_in_tree():
		show_tool_notice(String(notices.pop_front()))
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var view := get_viewport_rect().size
	var to_hud := Vector2(1920.0 / view.x, 1080.0 / view.y)
	for i in _formation_heads.size():
		var card = formation_cards[i] if i < formation_cards.size() else null
		var shown: bool = card != null and is_instance_valid(card)
		_formation_heads[i].visible = shown
		if shown:
			var head: Vector3 = card.global_position + Vector3(0, card.body_height + 0.35, 0)
			_formation_heads[i].position = camera.unproject_position(head) * to_hud - _formation_heads[i].size * 0.5
	for i in _marker_points.size():
		var point: Vector3 = _marker_points[i]
		var screen := camera.unproject_position(point) * to_hud
		_markers[i].position = screen - Vector2(11, 11) + Vector2(0, sin(Time.get_ticks_msec() * 0.004 + i) * 4.0)
		_markers[i].visible = not camera.is_position_behind(point)
	if _prompt.visible:
		if _prompt_world != null:
			# A ponta da etiqueta (100,52 da peça) no objeto.
			var at := camera.unproject_position(_prompt_world) * to_hud
			_prompt.position = Vector2(clampf(at.x - _prompt.size.x * 0.5, 16, 1904 - _prompt.size.x), clampf(at.y - _prompt.size.y, 150, 880))
		else:
			_prompt.position = Vector2(960 - _prompt.size.x * 0.5, 860)
	var show_patrol := false
	if _patrol_world != null:
		var p := camera.unproject_position(_patrol_world) * to_hud
		show_patrol = p.x > 1890 or camera.is_position_behind(_patrol_world)
	_patrol.visible = show_patrol
	if show_patrol:
		_patrol.reset_size()
		_patrol.size = _patrol.get_combined_minimum_size()
		_patrol.position = Vector2(1892 - _patrol.size.x, 300)
	# A dica das teclas é da primeira jornada (#56): some depois de um tempo andando e não volta depois da primeira volta à
	# Estação. Com um painel aberto, a barra mostra as teclas dele.
	if Input.get_vector("move_left", "move_right", "move_back", "move_front").length() > 0.1:
		_hint_time += delta
	var touch := Settings.touch_visible()
	if touch != _touch_shown:
		_touch_shown = touch
		_place_corner()
	if modal_open():
		_set_panel_keys("menu" if _modal.has_meta("menu") else ("continue" if _modal.has_meta("continue") else "choose"))
	_hint.modulate.a = clampf(1.0 - (_hint_time - 12.0) / 2.0, 0.0, 1.0)
	_hint.visible = not touch and first_journey() and not camp_open() and not modal_open() and not _formation
	_panel_keys.visible = not touch and modal_open() and not camp_open()
	if _formation_keys != null and is_instance_valid(_formation_keys):
		_formation_keys.visible = not touch
	for bar in [_hint, _panel_keys, _formation_keys]:
		if bar != null and is_instance_valid(bar) and bar.visible:
			bar.reset_size()
			bar.size = bar.get_combined_minimum_size()
			bar.position = Vector2(1892 - bar.size.x, KEYS_Y)
	# Um painel alto (a Mochila no Maior) desce até a barra: ela sai, em vez de ficar por baixo dele.
	if _panel_keys.visible and _modal.get_global_rect().intersects(_panel_keys.get_global_rect()):
		_panel_keys.visible = false


## O aviso da ferramenta nova (#143), no meio do alto, abaixo do corredor: o ícone grande, FERRAMENTA NOVA, o nome, o
## que ela faz e onde ela fica. Some em TOOL_NOTICE_SECONDS ou com uma tecla.
func show_tool_notice(tool: String) -> void:
	hide_tool_notice()
	_tool_notice = AHKit.panel_box("large")
	_tool_notice.name = "ToolNotice"
	_tool_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tool_notice)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tool_notice.add_child(row)
	var tile := AHKit.panel(AHKit.piece_of("chip", "resource_tile"))
	tile.custom_minimum_size = Vector2(120, 120)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := AHKit.glyph(AHInventoryPanel.TOOL_ICONS.get(tool, "tool-generic"), 84, AHKit.AMBER)
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.add_child(glyph)
	row.add_child(tile)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 6)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	words.add_child(AHKit.label(tr("Ferramenta nova"), "small", AHKit.AMBER, true, true))
	words.add_child(AHKit.label(tr(AHInventoryPanel.TOOL_NAMES.get(tool, tool.capitalize())), "panel_title", AHKit.TEXT, true))
	var text := AHKit.label(AHInventoryPanel.tool_text(tool), "text", AHKit.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(560, 0)
	words.add_child(text)
	# A tecla só fora do toque (no toque, a Mochila é o botão).
	var where := tr("Fica na Mochila.") if Settings.touch_visible() else tr("Fica na Mochila (%s).") % S.key_name("inventory")
	words.add_child(AHKit.label(where, "small", AHKit.MUTED))
	_tool_notice.reset_size()
	_tool_notice.size = _tool_notice.get_combined_minimum_size()
	_tool_notice.position = Vector2(960 - _tool_notice.size.x * 0.5, maxf(132.0, _route_panel.get_global_rect().end.y + 14.0))
	Sound.play("res://audio/ui/confirm.ogg")
	_tool_tween = create_tween()
	_tool_tween.tween_interval(TOOL_NOTICE_SECONDS)
	_tool_tween.tween_property(_tool_notice, "modulate:a", 0.0, 0.5)
	_tool_tween.tween_callback(hide_tool_notice)


func tool_notice_shown() -> bool:
	return _tool_notice != null and is_instance_valid(_tool_notice)


func hide_tool_notice() -> void:
	if _tool_tween:
		_tool_tween.kill()
		_tool_tween = null
	if tool_notice_shown():
		_tool_notice.queue_free()
	_tool_notice = null


## Mostra a frase agora e a mantém na frente dos avisos seguintes até completar os segundos dela.
func hold_line(line: String, seconds: float) -> void:
	_held_line = line
	_held_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	toast(line, seconds)


## Solta a frase mantida: os avisos seguintes vêm sozinhos (a luta acabou antes do tempo dela).
func release_line() -> void:
	_held_line = ""
	_held_until = 0


## A chapa do aviso no tamanho do texto, centrada embaixo do objetivo (fora da árvore, a chamada adiada não mede nada).
func _fit_toast() -> void:
	if not is_inside_tree():
		return
	_toast.reset_size()
	_toast.size = _toast.get_combined_minimum_size()
	_toast.position = Vector2(960 - _toast.size.x * 0.5, maxf(132.0, _route_panel.get_global_rect().end.y + 14.0))


## Um aviso (a busca, o trecho, o tempo) numa chapa no alto, abaixo do corredor; some sozinho.
func toast(text: String, seconds: float = 3.5) -> void:
	if _toast_tween:
		_toast_tween.kill()
	var left := (_held_until - Time.get_ticks_msec()) / 1000.0
	if left > 0.0 and text != _held_line and not text.begins_with(_held_line):
		text = _held_line + " " + text
		seconds = maxf(seconds, left)
	_toast_label.text = text
	var width := minf(900.0, _toast_label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		_toast_label.get_theme_font_size("font_size")).x + 8.0)
	# Quebra só o que passa de 900 (com a quebra ligada, o rótulo curto pedia a altura de uma palavra por linha).
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if width >= 900.0 else TextServer.AUTOWRAP_OFF
	_toast_label.custom_minimum_size = Vector2(width, 0)
	# A altura do texto quebrado depende da largura do rótulo: aplica a final antes de medir (com a largura velha, a
	# chapa saía alta e meio vazia no texto Maior).
	_toast_label.size = Vector2(width, 0)
	_toast_label.size = Vector2(width, _toast_label.get_minimum_size().y)
	_fit_toast()
	# O rótulo que quebra mede a altura pela largura de agora: no primeiro aviso longo, ele ainda tinha 0 e media uma
	# palavra por linha (a caixa saía com milhares de px e o texto fora da tela). Depois do layout, mede de novo.
	_fit_toast.call_deferred()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


func modal_open() -> bool:
	return _modal != null and is_instance_valid(_modal) and not _modal.is_queued_for_deletion()


func close_modal() -> void:
	if modal_open():
		_modal.queue_free()
		Sound.play("res://audio/ui/panel_close.ogg")
		# Fechou o menu ou a Mochila no acampamento: a barra dele volta com o que mudou (a comida, os curativos).
		if camp_open():
			camp_hud.refresh()
			camp_hud.focus_bar.call_deferred()
	_modal = null


## Um painel do kit no meio (a chapa grande), à direita do cartão do objetivo e acima da equipe.
func _open_modal(width: float) -> VBoxContainer:
	if modal_open():
		_modal.queue_free()
	else:
		Sound.play("res://audio/ui/panel_open.ogg")
	_modal = AHKit.panel_box("large")
	_modal.name = "Panel"
	_modal.custom_minimum_size = Vector2(width, 0)
	_modal.position = Vector2(960 - width * 0.5, 230)
	add_child(_modal)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_modal.add_child(box)
	return box


## O título de um painel: o ícone e o nome em caixa alta.
func _modal_title(box: VBoxContainer, text: String, icon_name: String = "", color: Color = AHKit.TEXT) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	if icon_name != "":
		head.add_child(_icon(icon_name, 34, AHKit.alert_text() if icon_name == "alert" else AHKit.AMBER))
	head.add_child(AHKit.label(text, "panel_title", color, true, true))


func _text(box: VBoxContainer, text: String, width: float, color: Color = AHKit.TEXT, role: String = "text") -> Label:
	var label := AHKit.label(text, role, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	box.add_child(label)
	return label


## Um botão de aço do kit, na largura do painel.
func _button(text: String, callback: Callable, enabled: bool = true) -> Button:
	var button := AHKit.button(text, "secondary")
	button.custom_minimum_size = Vector2(0, 60)
	button.add_theme_font_size_override("font_size", AHKit.size("row"))
	button.disabled = not enabled
	button.pressed.connect(callback)
	return button


## O botão âmbar do painel, com a tecla dentro (key: "E / A", "Esc / B").
func _primary(text: String, icon_name: String, key: String, callback: Callable) -> Button:
	var button := AHStationReport._primary(text, icon_name, "interact")
	(button.get_node("Key").get_child(0) as Label).text = key
	button.get_node("Key").remove_meta("ah_action")
	button.custom_minimum_size = Vector2(0, 64)
	button.add_theme_font_size_override("font_size", AHKit.size("row"))
	# O texto termina antes da tecla (ela fica a 52 da borda, depois da divisa).
	var room: float = button.get_node("Key").get_combined_minimum_size().x + 64.0
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		if button.has_theme_stylebox_override(state):
			button.get_theme_stylebox(state).content_margin_right = room
			button.get_theme_stylebox(state).content_margin_left = maxf(button.get_theme_stylebox(state).content_margin_left, 40.0)
	button.pressed.connect(callback)
	button.resized.connect(func():
		var cap: Control = button.get_node("Key")
		cap.reset_size()
		cap.position = Vector2(button.size.x - cap.size.x - 52.0, (button.size.y - cap.size.y) * 0.5))
	return button


# ---------------------------------------------------------------- carga recuperada (#91)

## Abre a carga recuperada do guardião no modal: o corredor espera a escolha (chosen) e o Continuar (closed).
func show_cargo(campaign: Dictionary) -> AHCargoPicker:
	var box := _open_modal(780)
	_modal.position.y = 140
	var picker := AHCargoPicker.build(AHFightRewards.cargo(campaign).boxes)
	box.add_child(picker)
	picker.closed.connect(close_modal)
	return picker


# ---------------------------------------------------------------- evento

## A ilustração do cenário em que se está (null se o mapa não tem uma).
func event_art() -> Texture2D:
	var path := "res://art/ui/events/%s.webp" % EVENT_ART.get(map_id, "street")
	return load(path) if ResourceLoader.exists(path) else null


## O marcador que o efeito de fase dá na luta (#78).
const EFFECT_ICONS := {"exposto": "status-vulnerable_bad", "cansado": "intent-move", "preparado": "status-block_good"}
## Os ícones das mudanças do resultado do evento (journey_rules, event.changes).
const CHANGE_ICONS := {"life": "intent-heal", "hope": "res-hope", "food": "lobby-food", "bandages": "res-bandages",
	"scrap": "lobby-scrap", "fragments": "lobby-fragment", "seeds": "lobby-seed", "instinct": "intent-unknown"}


## O ícone do chip: o da ferramenta, o do marcador do efeito de fase ou o do recurso.
func _change_icon(change: Dictionary) -> String:
	match String(change.kind):
		"tool":
			return AHInventoryPanel.TOOL_ICONS.get(String(change.get("id", "")), "tool-generic")
		"effect":
			return EFFECT_ICONS.get(String(change.get("id", "")), "intent-unknown")
	return CHANGE_ICONS.get(String(change.kind), "intent-unknown")


## O texto de uma mudança do evento ("+2 Comida", "-6 de vida", "+ Máscara com filtro", "Exposto: …"). id: a ferramenta
## ou o efeito de fase.
func _change_text(kind: String, amount: int, id: String = "") -> String:
	match kind:
		"tool":
			var tool := tr(AHInventoryPanel.TOOL_NAMES.get(id, id.capitalize()))
			return (tr("+ %s") if amount > 0 else tr("- %s")) % tool
		"effect":
			return tr(String(AHJourneyRules.PHASE_EFFECTS.get(id, {}).get("text", id)))
		"life": return tr("%+d de vida") % amount
		"hope": return tr("%+d de Esperança") % amount
		"food": return tr("%+d Comida") % amount
		"bandages": return tr("%+d Curativos") % amount
		"scrap": return tr("%+d Sucata") % amount
		"fragments": return tr("%+d Fragmentos") % amount
		"seeds": return tr("%+d Sementes") % amount
		"instinct": return tr("%+d de Instinto") % amount
	return "%+d" % amount


## Evento aberto (busca_*): a ilustração do cenário na moldura dos retratos, onde foi, o título, o texto e as escolhas
## numa lista: a que pede ferramenta fica apagada, com o que pede num chip; a arriscada leva o triângulo e o chip
## ARRISCADO. Resolvido: o texto da resolução, o que mudou em chips e CONTINUAR.
func show_event(campaign: Dictionary) -> void:
	var event: Dictionary = campaign.session.event
	var row = GameData.row("events", event.event_id)
	if row == null:
		return
	var box := _open_modal(820)
	box.add_theme_constant_override("separation", 10)
	var art := event_art()
	if art != null:
		# 12:5, como a pintura; o texto fica abaixo, nunca por cima.
		var frame := AHKit.panel("square_portrait")
		frame.name = "EventFrame"
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(frame)
		var picture := TextureRect.new()
		picture.name = "EventArt"
		picture.texture = art
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.clip_contents = true
		picture.custom_minimum_size = Vector2(0, 250)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(picture)
		# Com a ilustração, o cartão sobe para as escolhas caberem na tela, logo abaixo da barra de trechos.
		_modal.position.y = 125
	# O que se vasculhou (#7): o evento vem do objeto.
	if String(event.get("object", "")) != "":
		box.add_child(AHKit.label(tr("Ao vasculhar: %s") % tr(String(event.object)), "small", AHKit.AMBER, true, true))
	box.add_child(AHKit.label(tr(row.get("Title", "")), "card_name", AHKit.TEXT, true))
	_text(box, AHJourneyRules.resolution_text(event) if event.resolution != "" else tr(row.get("Description", "")), 772.0)
	var first: Button
	if event.resolution != "":
		# O que mudou, em chips na cor de alerta quando foi perda (um evento salvo antes não tem a lista).
		var changes: Array = event.get("changes", [])
		if not changes.is_empty():
			var flow := HFlowContainer.new()
			flow.name = "Changes"
			flow.add_theme_constant_override("h_separation", 8)
			flow.add_theme_constant_override("v_separation", 8)
			box.add_child(flow)
			for change in changes:
				var amount := int(change.amount)
				var text := _change_text(String(change.kind), amount, String(change.get("id", "")))
				if String(change.get("hero", "")) != "":
					text += " · " + String(change.hero)
				# O instinto que sobe é perda; o resto, quando baixa (a ferramenta perdida e o efeito ruim também).
				var loss := amount > 0 if change.kind == "instinct" else amount < 0
				flow.add_child(_change_chip(_change_icon(change), text, AHKit.alert_text() if loss else AHKit.good()))
		_modal.set_meta("continue", true)
		first = _primary(tr("Continuar"), "", tr("%s / A") % S.key_name("interact"), func(): event_closed.emit())
		first.name = "Continue"
		box.add_child(first)
	else:
		for choice in row.get("Choices", []):
			var available := AHJourneyRules.can_choose(campaign, choice)
			# A escolha de quem já liberou uma classe (trocar com Risco) só aparece quando dá para escolher: desligada, ela
			# prometia algo que o evento de história, uma vez por campanha, não deixaria acontecer (#64).
			if not available and choice.get("Requirement", "") == "ClassUnlocked":
				continue
			var button := _choice_row(campaign, choice, available)
			button.pressed.connect(func(): event_choice.emit(choice.Id))
			box.add_child(button)
			if first == null and available:
				first = button
	if first:
		AHKit.focus_later(first)


## Uma escolha do evento: a linha de lista com o ícone (a ferramenta, o triângulo do risco ou a seta), o texto e, à
## direita, o chip (o que ela pede ou ARRISCADO). Apagada no tom, sem transparência, quando não dá.
func _choice_row(campaign: Dictionary, choice: Dictionary, available: bool) -> Button:
	var button := Button.new()
	button.name = "Choice_%s" % choice.Id
	AHKit.style_as(button, "list")
	button.custom_minimum_size = Vector2(772, 60)
	button.disabled = not available
	# O texto da escolha no botão (o teclado e os testes leem por ele), desenhado pela linha de dentro.
	button.text = tr(choice.get("Text", ""))
	button.add_theme_color_override("font_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_focus_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_disabled_color", Color.TRANSPARENT)
	var risky := float(choice.get("FailChance", 0.0)) > 0.0
	var tool := String(choice.get("RequirementTool", ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -12
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var tone: Color = AHKit.TEXT if available else AHKit.MUTED
	var icon_name: String = "alert" if risky else (AHInventoryPanel.TOOL_ICONS.get(tool, "tool-generic") if tool != "" else "ui-arrow-right")
	row.add_child(_icon(icon_name, 26, AHKit.alert_text() if risky else (tone if tool != "" else AHKit.AMBER)))
	var text := AHKit.label(tr(choice.get("Text", "")), "text", tone)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	var requirement: String = tr(choice.get("RequirementText", ""))
	if risky:
		row.add_child(_change_chip("", tr("Arriscado"), AHKit.alert_text(), true))
	elif requirement != "":
		row.add_child(_change_chip(icon_name if tool != "" else "", requirement, AHKit.TEXT if available else AHKit.MUTED))
	# A linha cresce com o texto que quebra (o Maior).
	var grow := func(): button.custom_minimum_size.y = maxf(60.0, row.get_combined_minimum_size().y + 16.0)
	row.minimum_size_changed.connect(grow)
	grow.call()
	return button


## Um chip do kit com o ícone e o texto na cor dada (o que mudou, o que a escolha pede, ARRISCADO).
func _change_chip(icon_name: String, text: String, color: Color, upper: bool = false) -> PanelContainer:
	var chip := AHKit.chip("cost")
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	if icon_name != "":
		row.add_child(_icon(icon_name, 22, color))
	row.add_child(AHKit.label(text, "small", color, true, upper))
	return chip


# ---------------------------------------------------------------- acampamento

## O acampamento encenado (#77): o HUD do acampamento (AHCampHud) sobre a equipe em volta da fogueira (AHCampScene).
## Chamado de novo depois de cada comida e curativo, só atualiza.
func show_camp(_campaign: Dictionary, camp: AHCampScene) -> void:
	close_modal()
	if camp_open():
		camp_hud.refresh()
		return
	camp_hud = AHCampHud.new(camp)
	camp_hud.food.connect(func(id): camp_food.emit(id))
	camp_hud.bandage.connect(func(id): camp_bandage.emit(id))
	camp_hud.leave.connect(func(): camp_leave.emit())
	add_child(camp_hud)
	# Embaixo, a barra do acampamento no lugar da fila da equipe; o Menu e a Mochila continuam no canto.
	_set_camp_layout(true)


func hide_camp() -> void:
	if camp_open():
		camp_hud.queue_free()
	camp_hud = null
	_set_camp_layout(false)


func _set_camp_layout(camping: bool) -> void:
	# No acampamento (#109), a moldura da rua sai: o lugar, o objetivo, o corredor, os suprimentos e a equipe. A Mochila
	# e o Menu vão para o alto à direita (o painel do acampamento ocupa o pé da tela).
	for node in [_party_box, _route_panel, _plaque, _goal, _supplies.get_parent() if _supplies != null else null]:
		if node != null:
			node.visible = not camping
	for button in [_bag_button, _menu_button]:
		if button != null:
			button.position.y = CAMP_CORNER_Y if camping else CORNER_Y
	# A formação não vale no acampamento (a fogueira tem a ordem dela).
	if _formation_button != null:
		_formation_button.visible = not camping
	if camping:
		set_markers([])


func camp_open() -> bool:
	return camp_hud != null and is_instance_valid(camp_hud) and not camp_hud.is_queued_for_deletion()


## A resposta de comer ou curar no herói (o número verde, o efeito e o som).
func camp_respond(hero_id: String, kind: String, life_gain: int, instinct_change: int) -> void:
	if camp_open():
		camp_hud.respond(hero_id, kind, life_gain, instinct_change)


# ---------------------------------------------------------------- menu

## Esc na exploração: continuar ou voltar à Estação. Antes do guardião a volta é uma retirada (metade do achado) e
## pergunta antes, como o Retornar da Unreal ("Abandonar a expedição?").
func show_menu(completed: bool, can_return: bool, blocked_note: String = "") -> void:
	# O Menu da expedição (#109, docs/design/hud-ajustes.md; decisão do Lucas: fica o menu), no Painel do kit: à direita
	# do cartão do objetivo, com o pé acima das cabeças da equipe; cresce para cima no texto Maior.
	var box := _open_modal(MENU_WIDTH)
	_modal.set_meta("menu", true)
	_modal.add_theme_stylebox_override("panel", AHKit.style(AHKit.piece_of("panel", "large")))
	_modal.name = "ExpeditionMenu"
	box.add_theme_constant_override("separation", 12)
	var head := HBoxContainer.new()
	box.add_child(head)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(AHKit.label(tr("Menu da expedição"), "small", AHKit.AMBER, true, true))
	var expedition = Campaign.state.get("session", {}).get("expedition")
	if expedition != null:
		titles.add_child(AHKit.label(tr(String(AHJourneyRules.phase(expedition.phase_id).get("name", ""))), "panel_title", AHKit.TEXT, true, true))
		var route: Dictionary = expedition.corridor
		if not route.steps.is_empty():
			var step: Dictionary = route.steps[clampi(route.index, 0, route.steps.size() - 1)]
			titles.add_child(AHKit.label(tr("Trecho %d de %d · %s") % [route.index + 1, route.steps.size(), _step_label(step)], "text", AHKit.MUTED))
	var close := AHKit.button("X", "icon")
	close.name = "Close"
	close.tooltip_text = tr("Fechar")
	close.custom_minimum_size = Vector2(56, 56)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(close_modal)
	head.add_child(close)
	var line := TextureRect.new()
	line.texture = AHKit.texture("divider")
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.custom_minimum_size = Vector2(0, 8)
	box.add_child(line)
	# Voltar à Estação com o custo numa sublinha (não quebra o botão no Maior); no meio da luta ou do evento, apagado.
	var sub := (tr("Fase concluída: todo o achado") if completed else tr("Retirada: metade do achado")) if can_return \
		else (blocked_note if blocked_note != "" else tr("Termine a luta ou o evento antes de voltar."))
	var back := _menu_entry(tr("Voltar à Estação"), "station", func(): _confirm_return(completed), sub)
	back.name = "Return"
	back.disabled = not can_return
	if not can_return:
		# Apagado no tom (sem transparência), como os cuidados sem efeito do acampamento.
		(back.find_child("Title", true, false) as Label).add_theme_color_override("font_color", AHKit.MUTED)
		(back.find_child("Glyph", true, false) as Control).modulate = AHKit.MUTED
	box.add_child(back)
	var options := _menu_entry(tr("Opções"), "lobby-settings", show_options)
	options.name = "Options"
	box.add_child(options)
	var restart := _menu_entry(tr("Nova campanha"), "alert", _confirm_new_campaign, "", AHKit.alert_text())
	restart.name = "NewCampaign"
	box.add_child(restart)
	var resume := AHStationReport._primary(tr("Fechar"), "", "menu")
	resume.name = "Resume"
	resume.icon = null
	resume.alignment = HORIZONTAL_ALIGNMENT_CENTER
	# A tecla do Menu (a das Opções, se o jogador trocou) e o B do controle.
	var resume_key: Control = resume.get_node("Key")
	resume_key.remove_meta("ah_action")
	(resume_key.get_child(0) as Label).text = tr("%s / B") % AHUiStyle.key_name("menu")
	resume.custom_minimum_size = Vector2(0, 64)
	resume.pressed.connect(close_modal)
	# A tecla no fim do botão, que estica na largura do painel: ela acompanha o tamanho dele.
	resume.resized.connect(func():
		var key: Control = resume.get_node("Key")
		key.reset_size()
		key.position = Vector2(resume.size.x - key.size.x - 52.0, (resume.size.y - key.size.y) * 0.5))
	box.add_child(resume)
	_place_menu.call_deferred()
	AHKit.focus_later(resume)


## O pé do Menu acima das cabeças (MENU_BOTTOM), centrado à direita do cartão do objetivo (MENU_CENTER_X).
func _place_menu() -> void:
	if not modal_open() or not _modal.has_meta("menu") or _modal.name != "ExpeditionMenu":
		return
	_modal.reset_size()
	_modal.size = _modal.get_combined_minimum_size()
	_modal.position = Vector2(MENU_CENTER_X - _modal.size.x * 0.5, maxf(16.0, MENU_BOTTOM - _modal.size.y))



## Um botão do Menu: o ícone, o título e, se houver, a sublinha menor; tone tinge o título (a Nova campanha em alerta).
func _menu_entry(text: String, icon_name: String, callback: Callable, sub: String = "", tone: Color = AHKit.TEXT) -> Button:
	var button := AHKit.button("", "secondary")
	button.custom_minimum_size = Vector2(0, 64)
	button.pressed.connect(callback)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var glyph := AHKit.glyph(icon_name, AHUiStyle.px(28), tone)
	if icon_name.begins_with("res://"):
		glyph.texture = load(icon_name)
	glyph.name = "Glyph"
	row.add_child(glyph)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -4)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var title := AHKit.label(text, "primary", tone, true, true)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(title)
	if sub != "":
		var note := AHKit.label(sub, "small", AHKit.MUTED)
		note.name = "Sub"
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.add_child(note)
		button.custom_minimum_size.y = maxf(64.0, title.get_minimum_size().y + note.get_minimum_size().y + 28.0)
	return button


## A Mochila por cima da exploração (cuidados no aliado, ferramentas, recursos); Fechar, Esc ou I fecha. O painel começa
## depois do cartão do objetivo (x 500) e termina antes do chip do Achado.
func show_inventory() -> void:
	var box := _open_modal(1000)
	_modal.set_meta("menu", true)
	_modal.set_meta("inventory", true)
	_modal.position = Vector2(500, 132)
	var bag := AHInventoryPanel.new()
	# A novidade (#143): as ferramentas novas abrem destacadas, e o selo do botão sai.
	bag.fresh = Array(Campaign.state.get("new_tools", [])).duplicate()
	Campaign.state.new_tools = []
	hide_tool_notice()
	if _bag_new != null:
		_bag_new.visible = false
	# No acampamento, a Mochila abre no herói escolhido na fogueira.
	if camp_open():
		bag.hero_id = camp_hud.camp.selected_id()
	bag.closed.connect(close_modal)
	bag.used.connect(func(): refresh(Campaign.state))
	box.add_child(bag)


func inventory_shown() -> bool:
	return modal_open() and _modal.has_meta("inventory")


## Uma escolha de risco (no descanso e diante do guardião): o título, o texto, a equipe como está, os suprimentos e o
## achado em chips e as opções [[texto, ação]]; a primeira é a principal (âmbar, com a tecla), as outras de aço.
func show_choice(title: String, text: String, options: Array) -> void:
	var box := _open_modal(820)
	_modal.position.y = 132
	_modal_title(box, title, "node-boss")
	_text(box, text, 772.0)
	var team := HBoxContainer.new()
	team.add_theme_constant_override("separation", 10)
	box.add_child(team)
	var expedition = Campaign.state.session.expedition
	for hero_id in expedition.team:
		var hero = Campaign.hero(hero_id)
		if hero != null and hero.alive:
			team.add_child(_mate(hero))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	box.add_child(chips)
	chips.add_child(_change_chip("lobby-food", tr("Comida %d/%d") % [expedition.food, AHJourneyRules.MAX_FOOD], AHKit.TEXT))
	chips.add_child(_change_chip("res-bandages", tr("Curativos %d") % Campaign.state.inventory.bandages, AHKit.TEXT))
	chips.add_child(_change_chip("lobby-seed", tr("%d sementes") % expedition.loot.seeds, AHKit.TEXT))
	chips.add_child(_change_chip("lobby-scrap", tr("%d sucata") % expedition.loot.scrap, AHKit.TEXT))
	chips.add_child(_change_chip("lobby-fragment", tr("%d fragmentos") % expedition.loot.fragments, AHKit.TEXT))
	var first: Button
	for option in options:
		var run: Callable = option[1]
		var close_and_run := func():
			close_modal()
			run.call()
		var button: Button
		if first == null:
			button = _primary(option[0], "", tr("%s / A") % S.key_name("interact"), close_and_run)
			first = button
		else:
			button = _button(option[0], close_and_run)
			button.icon = AHKit.icon("station")
			button.add_theme_constant_override("icon_max_width", 28)
		box.add_child(button)
	AHKit.focus_later(first)
	# No Maior a equipe alarga o painel: ele fica centrado na largura de verdade, sem cobrir o cartão do objetivo.
	_center_modal.call_deferred()


func _center_modal() -> void:
	if modal_open():
		_modal.reset_size()
		_modal.position.x = clampf(960.0 - _modal.size.x * 0.5, _goal.get_global_rect().end.x + 24.0, 1892.0 - _modal.size.x)


## A primeira jornada da campanha: nenhuma volta à Estação ainda (o ciclo conta as voltas).
static func first_journey() -> bool:
	return int(Campaign.state.get("station", {}).get("cycle_number", 0)) == 0


## As opções por cima da exploração (som, gráficos, jogo, controles); Fechar ou Esc fecha.
func show_options() -> void:
	var box := _open_modal(700)
	_modal.set_meta("menu", true)
	# Abaixo da faixa dos trechos (ficava por cima dela, #63), até a altura da barra da equipe; a faixa cresce com o texto.
	_modal.position.y = maxf(128.0, _route_panel.get_global_rect().end.y + 8.0)
	var scroll := ScrollContainer.new()
	# A rolagem acompanha o foco do teclado e do controle (#5).
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(652, minf(780.0, 900.0 - _modal.position.y))
	box.add_child(scroll)
	var options := AHOptionsPanel.new()
	options.width = 620
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.closed.connect(close_modal)
	scroll.add_child(options)


func _confirm_new_campaign() -> void:
	var box := _open_modal(660)
	_modal.set_meta("menu", true)
	_modal_title(box, tr("Começar uma campanha nova?"), "alert", AHKit.alert_text())
	_text(box, tr("A expedição e todo o progresso salvo no espaço %d são substituídos por uma campanha do zero, na Estação. Os outros espaços ficam como estão.") % Campaign.slot, 612.0)
	var stay := _primary(tr("Cancelar"), "", tr("%s / B") % S.key_name("menu"), close_modal)
	box.add_child(stay)
	var go := _button(tr("Começar do zero"), func():
		close_modal()
		new_campaign.emit())
	go.add_theme_color_override("font_color", AHKit.alert_text())
	box.add_child(go)
	AHKit.focus_later(stay)


## A expedição ainda está na rua (sem resultado): concluir ou sair faz sentido.
static func session_open(campaign: Dictionary) -> bool:
	var session: Dictionary = campaign.get("session", {})
	return session.get("expedition") != null and session.get("result", "") == ""


func menu_shown() -> bool:
	return modal_open() and _modal.has_meta("menu")


## Abandonar a expedição: o triângulo, a pergunta e a consequência; CONTINUAR é o botão âmbar e fica na tecla de voltar
## (Esc / B); VOLTAR À ESTAÇÃO é de aço, sem tecla, para não sair sem querer.
func _confirm_return(completed: bool) -> void:
	if completed:
		close_modal()
		menu_return.emit()
		return
	var box := _open_modal(760)
	_modal.set_meta("menu", true)
	_modal.name = "Abandon"
	_modal_title(box, tr("Abandonar a expedição?"), "alert")
	_text(box, tr("A equipe volta pelo trem sem enfrentar o guardião: só metade do achado chega à Estação."), 712.0)
	# No texto maior, um botão embaixo do outro (lado a lado, a tecla cobria o texto).
	var row: BoxContainer = VBoxContainer.new() if Settings.text_size > 0 else HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var stay := _primary(tr("Continuar a expedição"), "", tr("%s / B") % S.key_name("menu"), close_modal)
	stay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stay)
	var back := _button(tr("Voltar à Estação"), func():
		close_modal()
		menu_return.emit())
	back.icon = AHKit.icon("station")
	back.add_theme_constant_override("icon_max_width", 28)
	row.add_child(back)
	AHKit.focus_later(stay)


# ---------------------------------------------------------------- resultado

## Fim da expedição: o que aconteceu e o que chega ao refúgio. delivered vem de AHJourneyRules.finish_return.
func show_result(result: String, delivered: Dictionary, campaign: Dictionary, button_text: String) -> void:
	var box := _open_modal(760)
	_modal.set_meta("continue", true)
	var titles := {"victory": tr("Vitória"), "retreat": tr("Retirada"), "fled": tr("Fuga"), "defeat": tr("Derrota")}
	var notes := {"victory": (tr("A Rua das Vitrines está liberada.") if place == "Rua das Vitrines" else tr("%s: o guardião caiu.") % tr(place)) + tr(" Todo o achado chega à Estação."),
		"retreat": tr("A equipe volta antes do guardião: metade do achado chega à Estação."),
		"fled": tr("Na fuga, a equipe larga o que carregava."), "defeat": tr("A equipe caiu %s. O achado ficou para trás.") % (tr("na rua") if place == "Rua das Vitrines" else tr("no caminho"))}
	var tone: Color = AHKit.AMBER if result == "victory" else (AHKit.alert_text() if result == "defeat" else AHKit.TEXT)
	_modal_title(box, titles.get(result, result), "objective_done" if result == "victory" else ("alert" if result == "defeat" else "station"), tone)
	_text(box, notes.get(result, ""), 712.0)
	box.add_child(AHKit.label(tr("Chegou à Estação"), "small", AHKit.MUTED, true, true))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	box.add_child(chips)
	chips.add_child(_change_chip("lobby-seed", tr("%d sementes") % delivered.get("seeds", 0), AHKit.TEXT))
	chips.add_child(_change_chip("lobby-scrap", tr("%d sucata") % delivered.get("scrap", 0), AHKit.TEXT))
	chips.add_child(_change_chip("lobby-fragment", tr("%d fragmentos") % delivered.get("fragments", 0), AHKit.TEXT))
	# Ninguém morre (#118): quem caiu volta em recuperação. Os levantados no mapa (#179) chegam carregados, com menos dias;
	# os outros, com a recuperação inteira, na Enfermaria (com leito) ou no Dormitório.
	var fallen: Array = delivered.get("fallen", [])
	if fallen.is_empty():
		box.add_child(AHKit.label(tr("Toda a equipe voltou de pé."), "text", AHKit.MUTED))
	# [o texto com um nome, o texto com vários, quem]: "A equipe carregou" vale para os dois (sem gênero no nome).
	var lines := [[tr("A equipe carregou: %s"), tr("A equipe carregou: %s"), fallen.filter(func(e): return e.get("carried", false))],
		[tr("Foi para a Enfermaria: %s"), tr("Foram para a Enfermaria: %s"), fallen.filter(func(e): return not e.get("carried", false) and e.get("bed", false))],
		[tr("Foi para o Dormitório, em recuperação: %s"), tr("Foram para o Dormitório, em recuperação: %s"),
			fallen.filter(func(e): return not e.get("carried", false) and not e.get("bed", false))]]
	for line in lines:
		if line[2].is_empty():
			continue
		var names: Array = line[2].map(func(e): var h = AHStationRules.hero(campaign, String(e.hero_id)); return "%s (%s)" % [String(h.display_name) if h != null else "", AHStationRules.return_text(int(e.days)).to_lower()])
		var label := AHKit.label((line[0] if names.size() == 1 else line[1]) % ", ".join(names), "text", AHKit.alert_text())
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
	var button := _primary(button_text, "station", tr("%s / A") % S.key_name("interact"), func(): result_continue.emit())
	box.add_child(button)
	AHKit.focus_later(button)
