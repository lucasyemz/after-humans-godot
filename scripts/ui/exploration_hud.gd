## HUD da exploração no corredor: os 10 trechos (só os alcançados mostram o que são), a mochila e o achado, a equipe, o
## aviso de interação (E), os avisos que somem sozinhos e os painéis do evento, do acampamento e do resultado.
## Mesmo estilo do HUD de combate (AHCombatHud).
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

const H = preload("res://scripts/ui/combat_hud.gd")
const S = preload("res://scripts/ui/ui_style.gd")
const STEP_LABELS := {"start": "Partida", "combat": "Patrulha", "loot": "Suprimentos", "rest": "Descanso", "passage": "Passagem",
	"boss": "Guardião"}

## O lugar da jornada (a Rua ou o cenário): muda os textos da volta e do resultado.
var place := "Rua das Vitrines"
var _place_name: Label
var _place_sub: Label
var _goal_title: Label
var _goal_text: Label
var _route_title: Label
var _route_row: HBoxContainer
var _route_panel: PanelContainer
var _supplies: HBoxContainer
var _loot_row: HBoxContainer
var _party_box: HBoxContainer
var _prompt: PanelContainer
var _prompt_label: Label
var _prompt_world = null
var _toast: Label
var _toast_tween: Tween
var _modal: PanelContainer
var _menu_button: Button
var _finish_button: Button
var _markers: Array[Control] = []
var _marker_points: Array = []
var _patrol: PanelContainer
var _patrol_bar: ProgressBar
var _patrol_text: Label
var _patrol_world = null
var _hint: HBoxContainer
var _hint_time := 0.0
var _weather := ""
## Os ícones dos trechos da rota (os nós do mapa da Unreal).
const STEP_ICONS := {"start": "node-start", "combat": "node-combat", "loot": "node-loot", "rest": "node-rest",
	"passage": "node-event", "boss": "node-boss"}
const ICONS := "res://art/ui/icons/%s.svg"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Em cima à esquerda: o lugar e o objetivo da rota.
	var left := VBoxContainer.new()
	left.position = Vector2(32, 24)
	left.custom_minimum_size = Vector2(440, 0)
	left.add_theme_constant_override("separation", 8)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)
	_place_name = S.label(place, 36, S.TEXT, "display")
	left.add_child(_place_name)
	_place_sub = S.label("", S.MIN_TEXT, S.TEXT)
	left.add_child(_place_sub)
	var goal := PanelContainer.new()
	goal.add_theme_stylebox_override("panel", S.panel(0.84))
	goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(goal)
	var goal_box := VBoxContainer.new()
	goal_box.add_theme_constant_override("separation", 3)
	goal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal.add_child(goal_box)
	goal_box.add_child(S.label("OBJETIVO DA ROTA", 15, S.COPPER, "bold"))
	_goal_title = S.label("", 21, S.TEXT, "bold")
	goal_box.add_child(_goal_title)
	_goal_text = S.label("", 17, S.MUTED)
	_goal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal_text.custom_minimum_size = Vector2(410, 0)
	goal_box.add_child(_goal_text)

	# Em cima no meio: a rota em trilho, com ícones.
	_route_panel = PanelContainer.new()
	_route_panel.add_theme_stylebox_override("panel", S.panel(0.84))
	_route_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_route_panel)
	var route_box := VBoxContainer.new()
	route_box.add_theme_constant_override("separation", 6)
	route_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_route_panel.add_child(route_box)
	_route_title = S.label("", 19, S.GOLD, "bold")
	_route_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	route_box.add_child(_route_title)
	_route_row = HBoxContainer.new()
	_route_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_route_row.add_theme_constant_override("separation", 0)
	_route_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route_box.add_child(_route_row)

	# Em cima à direita: os recursos com ícone e o achado.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.position = Vector2(1352, 24)
	right.custom_minimum_size = Vector2(540, 0)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	_supplies = HBoxContainer.new()
	_supplies.alignment = BoxContainer.ALIGNMENT_END
	_supplies.add_theme_constant_override("separation", 6)
	_supplies.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_supplies)
	_loot_row = HBoxContainer.new()
	_loot_row.alignment = BoxContainer.ALIGNMENT_END
	_loot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_loot_row)

	# Embaixo à esquerda: a equipe com rosto.
	_party_box = HBoxContainer.new()
	_party_box.position = Vector2(28, 970)
	_party_box.add_theme_constant_override("separation", 10)
	_party_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_party_box)

	# A patrulha à frente, avisada da borda direita antes de entrar na tela.
	_patrol = PanelContainer.new()
	var patrol_style := S.panel(0.88, Color(S.GOLD, 0.6))
	patrol_style.corner_radius_top_right = 0
	patrol_style.corner_radius_bottom_right = 0
	_patrol.add_theme_stylebox_override("panel", patrol_style)
	_patrol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_patrol.visible = false
	add_child(_patrol)
	var patrol_box := VBoxContainer.new()
	patrol_box.add_theme_constant_override("separation", 4)
	patrol_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_patrol.add_child(patrol_box)
	patrol_box.add_child(S.label("Patrulha à frente  ▶", S.MIN_TEXT, S.TEXT, "bold"))
	_patrol_bar = S.bar(S.GOLD, 8)
	_patrol_bar.max_value = 1.0
	_patrol_bar.custom_minimum_size = Vector2(200, 8)
	patrol_box.add_child(_patrol_bar)
	_patrol_text = S.label("", 16, S.MUTED)
	patrol_box.add_child(_patrol_text)

	# Embaixo no meio: só as teclas do jogo, até a pessoa pegar o jeito.
	_hint = HBoxContainer.new()
	_hint.add_theme_constant_override("separation", 18)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for spec in [[["move_left", "move_right"], "andar"], [["run"], "correr"], [["interact"], "interagir"]]:
		var group := HBoxContainer.new()
		group.add_theme_constant_override("separation", 5)
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for action in spec[0]:
			group.add_child(S.action_cap(action))
		group.add_child(S.label(spec[1], 17, S.TEXT))
		_hint.add_child(group)
	add_child(_hint)

	# Botões sempre à mão (mouse): a Mochila, o menu e, com o guardião vencido, concluir a jornada.
	_finish_button = Button.new()
	_finish_button.text = "Concluir jornada · Voltar à Estação"
	_finish_button.position = Vector2(1500, 900)
	_finish_button.custom_minimum_size = Vector2(392, 52)
	H.style_button(_finish_button)
	_finish_button.add_theme_color_override("font_color", S.GOLD)
	_finish_button.focus_mode = Control.FOCUS_NONE
	_finish_button.visible = false
	_finish_button.pressed.connect(func(): menu_return.emit())
	add_child(_finish_button)
	_menu_button = _corner_button("Menu", "menu", Vector2(1716, 974), func(): menu_requested.emit())
	_corner_button("Mochila", "inventory", Vector2(1524, 974), func(): inventory_requested.emit())

	# O aviso também é botão: tocar ou clicar nele usa o que está perto.
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", S.panel(0.9, S.GOLD))
	_prompt.mouse_filter = Control.MOUSE_FILTER_STOP
	_prompt.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			accept_event()
			var use := InputEventAction.new()
			use.action = "interact"
			use.pressed = true
			Input.parse_input_event(use))
	_prompt_label = S.label("", 20, S.TEXT, "bold")
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_child(_prompt_label)
	_prompt.visible = false
	add_child(_prompt)

	_toast = S.label("", 26, S.TEXT, "bold")
	_toast.position = Vector2(480, 250)
	_toast.size = Vector2(960, 80)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.modulate.a = 0.0
	add_child(_toast)


func _corner_button(text: String, key_action: String, at: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.position = at
	button.custom_minimum_size = Vector2(180, 46)
	H.style_button(button)
	button.focus_mode = Control.FOCUS_NONE
	var cap := S.action_cap(key_action)
	cap.position = Vector2(180 - 16 - (24 if S.key_name(key_action).length() == 1 else 44), 9)
	button.add_child(cap)
	button.pressed.connect(action)
	add_child(button)
	return button


func _icon(name: String, size: float, tint: Color = Color.WHITE) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load(ICONS % name)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	rect.modulate = tint
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
	_place_name.text = place
	var expedition = Campaign.state.get("session", {}).get("expedition")
	var parts := PackedStringArray()
	if expedition != null:
		var info := AHJourneyRules.phase(expedition.phase_id)
		parts.append("Jornada %d · %s" % [AHJourneyRules.PHASES.find(info) + 1, info.get("name", "")])
	if _weather != "":
		parts.append(_weather)
	_place_sub.text = " · ".join(parts)


# ---------------------------------------------------------------- estado

## Atualiza o lugar, o objetivo, a rota, os recursos e a equipe a partir da campanha.
## O tamanho do texto ou as cores mudaram nas Opções (AHUiStyle.retune): a rota e a equipe se reposicionam.
func restyle() -> void:
	refresh(Campaign.state)


func refresh(campaign: Dictionary) -> void:
	var expedition = campaign.get("session", {}).get("expedition")
	if expedition == null:
		return
	_refresh_place()
	var route: Dictionary = expedition.corridor
	# O objetivo: o foco escolhido na Preparação e o guardião no fim.
	var focus := AHStationRules.focus_def(expedition.get("focus", ""))
	var boss_step: int = route.steps.size()
	if focus.is_empty():
		_goal_title.text = "Vencer o guardião (trecho %d)" % boss_step
		_goal_text.text = "Rota básica: o achado das buscas volta com a equipe."
	elif expedition.get("objective_done", false):
		_goal_title.text = "✓ %s: cumprido" % AHStationRules.focus_label(focus.id)
		_goal_text.text = "%s, entregue na volta. O guardião espera no trecho %d." % [AHStationRules.focus_reward_text(focus.id), boss_step]
	else:
		_goal_title.text = "%s · %s" % [AHStationRules.focus_label(focus.id), AHStationRules.focus_reward_text(focus.id)]
		_goal_text.text = ("Procure nas casas e nos caixotes." if place == "Rua das Vitrines" else "Procure nos objetos marcados do caminho.") + \
			" O guardião espera no trecho %d." % boss_step
	if expedition.objective_completed:
		_goal_title.text = "✓ Guardião vencido"
		_goal_text.text = "Fase concluída: volte à Estação com todo o achado (botão ou %s)." % S.key_name("menu")
	# A rota: cada trecho com o ícone do que é (os não alcançados ficam como "?"), ligados como trilho.
	_clear(_route_row)
	for index in route.steps.size():
		var step: Dictionary = route.steps[index]
		var known: bool = index <= route.index or step.resolved or step.type == "boss"
		if index > 0:
			var link := ColorRect.new()
			link.custom_minimum_size = Vector2(10, 3)
			link.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			link.color = S.OK if route.steps[index - 1].resolved and index <= route.index else S.LINE
			link.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_route_row.add_child(link)
		var now: bool = index == route.index
		var node := PanelContainer.new()
		var style := StyleBoxFlat.new()
		var size := 42.0 if now else 32.0
		style.set_corner_radius_all(int(size * 0.5))
		style.set_border_width_all(2)
		style.bg_color = S.GOLD if now else Color(0, 0, 0, 0.6)
		style.border_color = S.GOLD if now else (S.DANGER if step.type == "boss" else (S.OK if step.resolved else Color(S.MUTED, 0.7)))
		node.add_theme_stylebox_override("panel", style)
		node.custom_minimum_size = Vector2(size, size)
		node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if known:
			var tint: Color = S.INK if now else (S.DANGER if step.type == "boss" else (S.OK if step.resolved else S.TEXT))
			var glyph := _icon(STEP_ICONS.get(step.type, "node-event"), size * 0.55, tint)
			glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			node.add_child(glyph)
		else:
			var q := S.label("?", 18, S.MUTED, "bold")
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			node.add_child(q)
		_route_row.add_child(node)
	var current: Dictionary = route.steps[route.index]
	var title := "Trecho %d de %d · %s" % [route.index + 1, route.steps.size(), STEP_LABELS.get(current.type, "")]
	if route.current_house >= 0:
		var site: Dictionary = route.sites[route.current_house]
		title = "Dentro %s" % ("do cinema" if site.shop == 2 else "da " + AHJourneyRules.SHOP_NAMES[site.shop])
	_route_title.text = title
	_route_panel.size = _route_panel.get_combined_minimum_size()
	_route_panel.position = Vector2(960 - _route_panel.size.x * 0.5, 16)
	_finish_button.visible = expedition.objective_completed and session_open(campaign)
	# Os recursos: comida, curativos, esperança e o achado, com ícone e dica.
	_clear(_supplies)
	var food: int = expedition.food
	_supplies.add_child(_supply("lobby-food", "Comida", "%d/%d" % [food, AHJourneyRules.MAX_FOOD], "Da expedição: cura (Mochila, I) e o acampamento. O que sobrar não volta.", S.DANGER if food == 0 else S.GOLD))
	_supplies.add_child(_supply("res-bandages", "Curativos", str(campaign.inventory.bandages), "Do refúgio: +8 de vida. Voltam ao refúgio."))
	_supplies.add_child(_supply("res-hope", "Esperança", str(expedition.hope), "O ânimo da equipe: alto, a crise de instinto tende à superação; baixo, ao colapso."))
	var loot := HBoxContainer.new()
	loot.add_theme_constant_override("separation", 4)
	loot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for spec in [["lobby-seed", expedition.loot.seeds], ["lobby-scrap", expedition.loot.scrap], ["lobby-fragment", expedition.loot.fragments]]:
		loot.add_child(_icon(spec[0], 20, S.GOLD))
		loot.add_child(S.label(str(spec[1]), S.MIN_TEXT, S.TEXT, "bold"))
	var loot_chip := PanelContainer.new()
	loot_chip.add_theme_stylebox_override("panel", _chip_style())
	loot_chip.tooltip_text = "Achado da jornada: sementes, sucata e fragmentos. Tudo chega com a fase concluída; metade, na retirada."
	loot_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var loot_row := HBoxContainer.new()
	loot_row.add_theme_constant_override("separation", 6)
	loot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loot_row.add_child(S.label("Achado", S.MIN_TEXT, S.MUTED))
	loot_row.add_child(loot)
	loot_chip.add_child(loot_row)
	_clear(_loot_row)
	_loot_row.add_child(loot_chip)
	# A equipe: rosto, nome, vida em número e o instinto quando sobe.
	_clear(_party_box)
	for hero_id in expedition.team:
		var hero = Campaign.hero(hero_id)
		if hero == null or not hero.alive:
			continue
		_party_box.add_child(_mate(hero))
	_party_box.position = Vector2(28, 1060 - _party_box.get_combined_minimum_size().y)


func _chip_style() -> StyleBoxFlat:
	var style := S.panel(0.86, Color(S.COPPER, 0.45), 1)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


func _supply(icon: String, name: String, value: String, tip: String, color: Color = S.GOLD) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _chip_style())
	chip.tooltip_text = tip
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon(icon, 22, S.GOLD))
	row.add_child(S.label(name, S.MIN_TEXT, S.TEXT))
	row.add_child(S.label(value, S.MIN_TEXT, color, "bold"))
	chip.add_child(row)
	return chip


func _mate(hero: Dictionary) -> PanelContainer:
	var box := PanelContainer.new()
	var style := _chip_style()
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var art: Dictionary = AHCombatArena.hero_art_of(hero.id).get("idle", {})
	if not art.is_empty():
		row.add_child(S.portrait(art, 52, Color(1, 1, 1, 0.35)))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	info.custom_minimum_size = Vector2(150, 0)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(top)
	var name_label := S.label(hero.display_name, S.MIN_TEXT, S.TEXT, "bold")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	top.add_child(S.label("%d/%d" % [hero.hp, hero.max_hp], 17, S.MUTED))
	var bar := S.bar(Color(0.8, 0.27, 0.22), 10)
	bar.max_value = hero.max_hp
	bar.value = hero.hp
	info.add_child(bar)
	if int(hero.get("instinct", 0)) > 0:
		var instinct := S.bar(Color(0.6, 0.48, 0.92), 5)
		instinct.max_value = 200
		instinct.value = hero.instinct
		instinct.tooltip_text = S.GLOSSARY.Instinto
		info.add_child(instinct)
	return box


## O aviso de interação: perto do que se usa (where, no mundo), ou embaixo no meio quando não tem lugar.
func show_prompt(text: String, where = null) -> void:
	_prompt.visible = text != ""
	if text.begins_with("E  "):
		var key := "Toque" if Settings.touch_visible() else S.key_name("interact")
		text = "[%s]  %s" % [key, text.substr(3)]
	_prompt_label.text = text
	_prompt_world = where
	_prompt.size = _prompt.get_combined_minimum_size()


func has_prompt() -> bool:
	return _prompt.visible


func prompt_rect() -> Rect2:
	return _prompt.get_global_rect() if _prompt.visible else Rect2()


## O achado de uma busca vira momento: cada item sobe da equipe com o ícone e voa para o achado no alto.
## gains: [[ícone, texto]], where: o ponto no mundo de onde sai.
func loot_burst(gains: Array, where: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or gains.is_empty():
		return
	var view := get_viewport_rect().size
	var start := camera.unproject_position(where) * Vector2(1920.0 / view.x, 1080.0 / view.y)
	var target := _loot_row.global_position + Vector2(_loot_row.size.x * 0.5, 16)
	for i in gains.size():
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", _chip_style())
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(row)
		row.add_child(_icon(gains[i][0], 26, S.GOLD))
		row.add_child(S.label(gains[i][1], 22, S.GOLD, "bold"))
		add_child(chip)
		chip.size = chip.get_combined_minimum_size()
		chip.pivot_offset = chip.size * 0.5
		chip.position = start - chip.size * 0.5 + Vector2(0, -40 * i)
		chip.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(0.18 * i)
		tween.tween_property(chip, "modulate:a", 1.0, 0.15)
		tween.parallel().tween_property(chip, "position:y", chip.position.y - 60, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.5)
		tween.tween_property(chip, "position", target - chip.size * 0.5, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(chip, "scale", Vector2(0.4, 0.4), 0.55)
		tween.tween_callback(chip.queue_free)


## Os losangos sobre o que dá para usar por perto (o corredor manda a cada quadro).
func set_markers(points: Array) -> void:
	_marker_points = points
	while _markers.size() < points.size():
		var dia := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(S.GOLD, 0.28)
		style.border_color = S.GOLD
		style.set_border_width_all(3)
		style.shadow_color = Color(S.GOLD, 0.55)
		style.shadow_size = 8
		dia.add_theme_stylebox_override("panel", style)
		dia.size = Vector2(20, 20)
		dia.pivot_offset = Vector2(10, 10)
		dia.rotation_degrees = 45
		dia.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dia)
		move_child(dia, 0)
		_markers.append(dia)
	for i in _markers.size():
		_markers[i].visible = i < points.size()


## A patrulha do trecho: a suspeita dela e se já avistou (null esconde). O aviso só aparece com ela fora da tela.
func set_patrol(where, meter: float, detected: bool) -> void:
	_patrol_world = where
	_patrol_bar.value = meter
	_patrol_text.text = "avistou a equipe!" if detected else ("desconfiada" if meter > 0.25 else "não viu a equipe")
	_patrol_text.add_theme_color_override("font_color", S.DANGER if detected else (S.GOLD if meter > 0.25 else S.MUTED))


## Teclado e controle (#5): com um painel aberto (menu, Mochila, evento, escolha, acampamento, resultado), Interagir
## confirma o botão com foco, além de Enter e do A; Voltar (B, Backspace) fecha o menu, a Mochila e as Opções (os
## eventos e o resultado pedem uma escolha).
func _input(event: InputEvent) -> void:
	if modal_open() and S.press_focused(_modal, event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if modal_open() and _modal.has_meta("menu") and S.is_back(event) and not event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		close_modal()


func _process(delta: float) -> void:
	if modal_open():
		S.keep_focus(_modal)
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var view := get_viewport_rect().size
	var to_hud := Vector2(1920.0 / view.x, 1080.0 / view.y)
	for i in _marker_points.size():
		var point: Vector3 = _marker_points[i]
		var screen := camera.unproject_position(point) * to_hud
		_markers[i].position = screen - Vector2(10, 10) + Vector2(0, sin(Time.get_ticks_msec() * 0.004 + i) * 4.0)
		_markers[i].visible = not camera.is_position_behind(point)
	if _prompt.visible:
		if _prompt_world != null:
			var at := camera.unproject_position(_prompt_world) * to_hud
			_prompt.position = Vector2(clampf(at.x - _prompt.size.x * 0.5, 16, 1904 - _prompt.size.x), clampf(at.y - _prompt.size.y - 14, 150, 900))
		else:
			_prompt.position = Vector2(960 - _prompt.size.x * 0.5, 890)
	var show_patrol := false
	if _patrol_world != null:
		var p := camera.unproject_position(_patrol_world) * to_hud
		show_patrol = p.x > 1890 or camera.is_position_behind(_patrol_world)
	_patrol.visible = show_patrol
	if show_patrol:
		_patrol.size = _patrol.get_combined_minimum_size()
		_patrol.position = Vector2(1920 - _patrol.size.x, 470)
	# A dica das teclas some depois de um tempo andando (volta numa jornada nova).
	if Input.get_vector("move_left", "move_right", "move_back", "move_front").length() > 0.1:
		_hint_time += delta
	_hint.modulate.a = clampf(1.0 - (_hint_time - 12.0) / 2.0, 0.0, 1.0)
	_hint.visible = not Settings.touch_visible()
	var party_end := _party_box.position.x + _party_box.get_combined_minimum_size().x
	_hint.position = Vector2(party_end + 28, 1036)


func toast(text: String, seconds: float = 3.5) -> void:
	if _toast_tween:
		_toast_tween.kill()
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


func modal_open() -> bool:
	return _modal != null and is_instance_valid(_modal)


func close_modal() -> void:
	if modal_open():
		_modal.queue_free()
	_modal = null


func _open_modal(width: float) -> VBoxContainer:
	close_modal()
	_modal = PanelContainer.new()
	_modal.add_theme_stylebox_override("panel", H.panel_style(0.95))
	_modal.custom_minimum_size = Vector2(width, 0)
	_modal.position = Vector2(960 - width * 0.5, 230)
	add_child(_modal)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_modal.add_child(box)
	return box


func _button(text: String, callback: Callable, enabled: bool = true) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.disabled = not enabled
	H.style_button(button)
	button.pressed.connect(callback)
	return button


# ---------------------------------------------------------------- evento

## Evento aberto (busca_*): título, descrição e as escolhas (as indisponíveis aparecem com o requisito).
func show_event(campaign: Dictionary) -> void:
	var event: Dictionary = campaign.session.event
	var row = GameData.row("events", event.event_id)
	if row == null:
		return
	var box := _open_modal(820)
	var title := H.make_label(row.get("Title", ""), 34, H.GOLD)
	box.add_child(title)
	# O que se vasculhou (#7): o evento vem do objeto.
	if String(event.get("object", "")) != "":
		box.add_child(H.make_label("Ao vasculhar %s" % String(event.object).to_lower(), 17, H.MUTED))
	var text := H.make_label(event.resolution if event.resolution != "" else row.get("Description", ""), 20, H.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(780, 0)
	box.add_child(text)
	var first: Button
	if event.resolution != "":
		first = _button("Continuar", func(): event_closed.emit())
		box.add_child(first)
	else:
		for choice in row.get("Choices", []):
			var available := AHJourneyRules.can_choose(campaign, choice)
			var label: String = choice.get("Text", "")
			var requirement: String = choice.get("RequirementText", "")
			if requirement != "":
				label += "  (%s)" % requirement
			var button := _button(label, func(): event_choice.emit(choice.Id), available)
			box.add_child(button)
			if first == null and available:
				first = button
	if first:
		first.grab_focus.call_deferred()


# ---------------------------------------------------------------- acampamento

## Painel do acampamento: cada herói com vida e instinto, comer e curativo; levantar acampamento.
func show_camp(campaign: Dictionary) -> void:
	var box := _open_modal(860)
	box.add_child(H.make_label("Acampamento", 34, H.GOLD))
	var note := H.make_label("A porta fechada e a fogueira acesa. Comer: +10%% de vida e -5 de instinto (comida %d). Curativo: +8 de vida (curativos %d)." % [
		AHJourneyRules.food(campaign), campaign.inventory.bandages], 18, H.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(820, 0)
	box.add_child(note)
	var first: Button
	for hero_id in campaign.session.expedition.team:
		var hero = Campaign.hero(hero_id)
		if hero == null or not hero.alive:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var label := H.make_label("%s · Vida %d/%d · Instinto %d" % [hero.display_name, hero.hp, hero.max_hp, hero.instinct], 20, H.TEXT)
		label.custom_minimum_size = Vector2(420, 0)
		row.add_child(label)
		var eat := _button("Comer", func(): camp_food.emit(hero_id),
			AHJourneyRules.food(campaign) > 0 and (hero.hp < hero.max_hp or hero.instinct > 0))
		eat.custom_minimum_size = Vector2(150, 44)
		row.add_child(eat)
		var heal := _button("Curativo", func(): camp_bandage.emit(hero_id), campaign.inventory.bandages > 0 and hero.hp < hero.max_hp)
		heal.custom_minimum_size = Vector2(150, 44)
		row.add_child(heal)
		box.add_child(row)
		if first == null:
			first = eat if not eat.disabled else (heal if not heal.disabled else null)
	var leave := _button("Levantar acampamento", func(): camp_leave.emit())
	box.add_child(leave)
	(first if first else leave).grab_focus.call_deferred()


# ---------------------------------------------------------------- menu

## Esc na exploração: continuar ou voltar à Estação. Antes do guardião a volta é uma retirada (metade do achado) e
## pergunta antes, como o Retornar da Unreal ("Abandonar a expedição?").
func show_menu(completed: bool, can_return: bool) -> void:
	var box := _open_modal(620)
	_modal.set_meta("menu", true)
	box.add_child(H.make_label("Pausa", 34, H.GOLD))
	var resume := _button("Continuar", close_modal)
	box.add_child(resume)
	var text := "Voltar à Estação (fase concluída: todo o achado)" if completed else "Voltar à Estação (retirada: metade do achado)"
	var back := _button(text, func(): _confirm_return(completed), can_return)
	box.add_child(back)
	if not can_return:
		box.add_child(H.make_label("Termine a luta ou o evento antes de voltar.", 18, H.MUTED))
	box.add_child(_button("Opções", show_options))
	box.add_child(_button("Nova campanha", _confirm_new_campaign))
	resume.grab_focus.call_deferred()


## A Mochila por cima da exploração (cuidados no aliado, ferramentas, recursos); Fechar, Esc ou I fecha.
func show_inventory() -> void:
	var box := _open_modal(900)
	_modal.set_meta("menu", true)
	_modal.set_meta("inventory", true)
	_modal.position.y = 120
	var bag := AHInventoryPanel.new()
	bag.closed.connect(close_modal)
	bag.used.connect(func(): refresh(Campaign.state))
	box.add_child(bag)


func inventory_shown() -> bool:
	return modal_open() and _modal.has_meta("inventory")


## Uma escolha de risco (no descanso e diante do guardião): o título, a equipe como está e as opções [[texto, ação]];
## a primeira é a principal.
func show_choice(title: String, text: String, options: Array) -> void:
	var box := _open_modal(720)
	box.add_child(S.label(title, 34, S.GOLD, "display"))
	var body := S.label(text, 20, S.TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(680, 0)
	box.add_child(body)
	var team := HBoxContainer.new()
	team.add_theme_constant_override("separation", 8)
	box.add_child(team)
	var expedition = Campaign.state.session.expedition
	for hero_id in expedition.team:
		var hero = Campaign.hero(hero_id)
		if hero != null and hero.alive:
			team.add_child(_mate(hero))
	box.add_child(S.label("Comida %d/%d · Curativos %d · Achado: %d sementes, %d sucata, %d fragmentos" % [expedition.food, AHJourneyRules.MAX_FOOD,
		Campaign.state.inventory.bandages, expedition.loot.seeds, expedition.loot.scrap, expedition.loot.fragments], 17, S.MUTED))
	var first: Button
	for option in options:
		var button := _button(option[0], func():
			close_modal()
			option[1].call())
		box.add_child(button)
		if first == null:
			first = button
			button.add_theme_color_override("font_color", S.GOLD)
	first.grab_focus.call_deferred()


## As opções por cima da exploração (som, gráficos, jogo, controles); Fechar ou Esc fecha.
func show_options() -> void:
	var box := _open_modal(700)
	_modal.set_meta("menu", true)
	_modal.position.y = 40
	var scroll := ScrollContainer.new()
	# A rolagem acompanha o foco do teclado e do controle (#5).
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(660, 960)
	box.add_child(scroll)
	var options := AHOptionsPanel.new()
	options.width = 640
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.closed.connect(close_modal)
	scroll.add_child(options)


func _confirm_new_campaign() -> void:
	var box := _open_modal(620)
	_modal.set_meta("menu", true)
	box.add_child(H.make_label("Começar uma campanha nova?", 34, H.GOLD))
	var note := H.make_label("A expedição e todo o progresso salvo são substituídos por uma campanha do zero, na Estação.", 20, H.TEXT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(580, 0)
	box.add_child(note)
	var stay := _button("Cancelar", close_modal)
	box.add_child(stay)
	box.add_child(_button("Começar do zero", func():
		close_modal()
		new_campaign.emit()))
	stay.grab_focus.call_deferred()


## A expedição ainda está na rua (sem resultado): concluir ou sair faz sentido.
static func session_open(campaign: Dictionary) -> bool:
	var session: Dictionary = campaign.get("session", {})
	return session.get("expedition") != null and session.get("result", "") == ""


func menu_shown() -> bool:
	return modal_open() and _modal.has_meta("menu")


func _confirm_return(completed: bool) -> void:
	if completed:
		close_modal()
		menu_return.emit()
		return
	var box := _open_modal(620)
	_modal.set_meta("menu", true)
	box.add_child(H.make_label("Abandonar a expedição?", 34, H.GOLD))
	var note := H.make_label("A equipe volta pelo trem sem enfrentar o guardião: só metade do achado chega à Estação.", 20, H.TEXT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(580, 0)
	box.add_child(note)
	var stay := _button("Continuar a expedição", close_modal)
	box.add_child(stay)
	box.add_child(_button("Voltar à Estação", func():
		close_modal()
		menu_return.emit()))
	stay.grab_focus.call_deferred()


# ---------------------------------------------------------------- resultado

## Fim da expedição: o que aconteceu e o que chega ao refúgio. delivered vem de AHJourneyRules.finish_return.
func show_result(result: String, delivered: Dictionary, campaign: Dictionary, button_text: String) -> void:
	var box := _open_modal(720)
	var titles := {"victory": "Vitória", "retreat": "Retirada", "fled": "Fuga", "defeat": "Derrota"}
	var notes := {"victory": ("A Rua das Vitrines está liberada." if place == "Rua das Vitrines" else "%s: o guardião caiu." % place) + " Todo o achado chega à Estação.",
		"retreat": "A equipe volta antes do guardião: metade do achado chega à Estação.",
		"fled": "Na fuga, a equipe larga o que carregava.", "defeat": "A equipe caiu %s. O achado ficou para trás." % ("na rua" if place == "Rua das Vitrines" else "no caminho")}
	box.add_child(H.make_label(titles.get(result, result), 44, H.GOLD))
	var note := H.make_label(notes.get(result, ""), 20, H.TEXT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(680, 0)
	box.add_child(note)
	box.add_child(H.make_label("Chegou à Estação: %d sementes · %d sucata · %d fragmentos" % [delivered.get("seeds", 0),
		delivered.get("scrap", 0), delivered.get("fragments", 0)], 20, H.MUTED))
	var alive: Array = campaign.roster.filter(func(h): return h.alive)
	box.add_child(H.make_label("Heróis vivos: %d · No memorial: %d" % [alive.size(), campaign.memorial.size()], 18, H.MUTED))
	var button := _button(button_text, func(): result_continue.emit())
	box.add_child(button)
	button.grab_focus.call_deferred()
