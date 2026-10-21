## HUD de combate (port enxuto do UAHCombatHUDWidget), montado em código:
## - em cima, a ordem dos turnos da rodada;
## - sobre cada personagem, nome, vida, instinto (heróis) e status;
## - embaixo, o herói da vez com as 4 habilidades (ícone, recarga, usos e o motivo quando não dá), Mover, Defender e Fugir;
## - ao escolher, marcadores sobre os alvos válidos (mouse, teclado ou gamepad; Backspace ou B volta).
class_name AHCombatHud
extends Control

signal command_chosen(command: Dictionary)
signal result_closed

const GOLD := Color(0.86, 0.69, 0.4)
const INK := Color(0.07, 0.06, 0.07, 0.9)
const TEXT := Color(0.97, 0.9, 0.78)
const MUTED := Color(0.65, 0.6, 0.55)

var arena: AHCombatArena
var session: AHCombatSession
var _turn_row: HBoxContainer
var _round_label: Label
var _panel: PanelContainer
var _hero_name: Label
var _hero_hp: ProgressBar
var _hero_hp_text: Label
var _hero_instinct: ProgressBar
var _hero_status: Label
var _abilities: HBoxContainer
var _actions: VBoxContainer
var _description: Label
var _message: Label
var _log: Label
var _result: PanelContainer
var _unit_bars := {}
var _markers: Array = []
var _actor_id := ""
var _options: Array = []
var _choosing := ""
## Esperando o comando do herói (a captura usa para jogar por ele).
var waiting := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


# ---------------------------------------------------------------- montagem

static func panel_style(alpha: float = 0.9) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(INK.r, INK.g, INK.b, alpha)
	style.border_color = GOLD.darkened(0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


static func make_label(text: String, size: int, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.03))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func make_bar(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.02, 0.02, 0.02, 0.85)
	back.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


static func style_button(button: Button, accent: Color = GOLD) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := panel_style(0.92)
		match state:
			"hover", "focus":
				style.border_color = accent
				style.bg_color = Color(0.16, 0.12, 0.09, 0.95)
			"pressed":
				style.bg_color = Color(0.25, 0.18, 0.1, 0.95)
			"disabled":
				style.border_color = Color(0.3, 0.28, 0.26)
				style.bg_color = Color(0.06, 0.06, 0.06, 0.85)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_disabled_color", MUTED.darkened(0.3))
	button.add_theme_font_size_override("font_size", 20)
	# O clique da interface em todo botão do jogo (SW_UI_Click).
	if not button.has_meta("click"):
		button.set_meta("click", true)
		button.pressed.connect(func(): Sound.click())


func _build() -> void:
	# O HUD é desenhado na base de 1920x1080 (o projeto estica a tela inteira): posições fixas nessa base.
	var top := VBoxContainer.new()
	top.position = Vector2(360, 16)
	top.size = Vector2(1200, 0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(top)
	_round_label = make_label("", 20, GOLD)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_round_label)
	_turn_row = HBoxContainer.new()
	_turn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_turn_row.add_theme_constant_override("separation", 8)
	_turn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_turn_row)

	_message = make_label("", 26, TEXT)
	_message.position = Vector2(460, 112)
	_message.size = Vector2(1000, 40)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message)

	_log = make_label("", 17, MUTED)
	# O registro fica no canto de cima: embaixo ele cobria os pés de quem luta.
	_log.position = Vector2(36, 18)
	_log.size = Vector2(620, 60)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(_log)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", panel_style())
	_panel.position = Vector2(30, 838)
	_panel.size = Vector2(1860, 220)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	_panel.add_child(row)

	var hero_box := VBoxContainer.new()
	hero_box.custom_minimum_size = Vector2(360, 0)
	hero_box.add_theme_constant_override("separation", 6)
	row.add_child(hero_box)
	_hero_name = make_label("", 30, GOLD)
	hero_box.add_child(_hero_name)
	_hero_hp_text = make_label("", 18)
	hero_box.add_child(_hero_hp_text)
	_hero_hp = make_bar(Color(0.78, 0.2, 0.18), 16)
	hero_box.add_child(_hero_hp)
	hero_box.add_child(make_label("Instinto", 15, MUTED))
	_hero_instinct = make_bar(Color(0.55, 0.36, 0.85), 10)
	_hero_instinct.max_value = 200
	hero_box.add_child(_hero_instinct)
	_hero_status = make_label("", 16, MUTED)
	_hero_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_box.add_child(_hero_status)

	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 8)
	row.add_child(middle)
	_description = make_label("", 18, TEXT)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size = Vector2(0, 48)
	middle.add_child(_description)
	_abilities = HBoxContainer.new()
	_abilities.add_theme_constant_override("separation", 12)
	middle.add_child(_abilities)

	_actions = VBoxContainer.new()
	_actions.custom_minimum_size = Vector2(200, 0)
	_actions.add_theme_constant_override("separation", 8)
	row.add_child(_actions)
	for spec in [["Mover", "move"], ["Defender", "defend"], ["Fugir", "flee"]]:
		var button := Button.new()
		button.text = spec[0]
		button.custom_minimum_size = Vector2(200, 52)
		style_button(button)
		button.pressed.connect(_on_action.bind(spec[1]))
		button.focus_entered.connect(_describe_action.bind(spec[1]))
		button.mouse_entered.connect(_describe_action.bind(spec[1]))
		button.set_meta("kind", spec[1])
		_actions.add_child(button)

	_result = PanelContainer.new()
	_result.add_theme_stylebox_override("panel", panel_style(0.95))
	_result.position = Vector2(660, 330)
	_result.custom_minimum_size = Vector2(600, 0)
	_result.visible = false
	add_child(_result)


# ---------------------------------------------------------------- abrir, fechar e atualizar

func open(new_session: AHCombatSession) -> void:
	session = new_session
	visible = true
	_result.visible = false
	for bar in _unit_bars.values():
		bar.queue_free()
	_unit_bars.clear()
	for unit in session.units():
		_unit_bars[unit.id] = _make_unit_bar(unit)
	refresh()


func close() -> void:
	visible = false
	_clear_markers()
	for bar in _unit_bars.values():
		bar.queue_free()
	_unit_bars.clear()


func _make_unit_bar(unit: AHCombat.Unit) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(150, 0)
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := make_label(unit.display_name, 17, TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.name = "Name"
	box.add_child(name_label)
	var hp := make_bar(Color(0.78, 0.2, 0.18) if unit.is_player else Color(0.85, 0.45, 0.15), 9)
	hp.name = "Hp"
	box.add_child(hp)
	if unit.is_player:
		var instinct := make_bar(Color(0.55, 0.36, 0.85), 5)
		instinct.max_value = 200
		instinct.name = "Instinct"
		box.add_child(instinct)
	var status := make_label("", 14, Color(0.85, 0.82, 0.7))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.name = "Status"
	box.add_child(status)
	add_child(box)
	move_child(box, 0)
	return box


## Atualiza barras, ordem dos turnos, painel do herói e o registro.
func refresh() -> void:
	if session == null:
		return
	for unit in session.units():
		var box: Control = _unit_bars.get(unit.id)
		if box == null:
			continue
		var card: AHSpriteCard = arena.cards.get(unit.id)
		box.visible = card != null and card.visible and (unit.hp > 0 or unit.is_player)
		var hp: ProgressBar = box.get_node("Hp")
		hp.max_value = unit.max_hp
		hp.value = unit.hp
		if unit.is_player:
			(box.get_node("Instinct") as ProgressBar).value = unit.instinct
		var name_label: Label = box.get_node("Name")
		name_label.text = "%s %d/%d" % [unit.display_name, unit.hp, unit.max_hp]
		name_label.add_theme_color_override("font_color", GOLD if unit.id == session.state.current_turn_unit_id else TEXT)
		(box.get_node("Status") as Label).text = status_text(unit, true)
	_round_label.text = "Rodada %d" % session.state.round
	for child in _turn_row.get_children():
		child.queue_free()
	for item in session.state.initiative_queue:
		var unit := session.state.find_unit(item.unit_id)
		if unit == null or (unit.hp <= 0 and not unit.deaths_door) or (item.acted and item.unit_id != session.state.current_turn_unit_id):
			continue
		var chip := PanelContainer.new()
		var style := panel_style(0.85)
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		style.border_color = GOLD if item.unit_id == session.state.current_turn_unit_id else (Color(0.45, 0.6, 0.85) if unit.is_player else Color(0.8, 0.4, 0.3))
		chip.add_theme_stylebox_override("panel", style)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(make_label(unit.display_name, 17))
		_turn_row.add_child(chip)
	var lines := session.state.combat_log
	_log.text = "\n".join(lines.slice(maxi(0, lines.size() - 2)))
	var actor := session.current_actor()
	if actor != null and actor.is_player:
		_show_hero(actor)


func _show_hero(actor: AHCombat.Unit) -> void:
	_hero_name.text = actor.display_name
	_hero_hp.max_value = actor.max_hp
	_hero_hp.value = actor.hp
	_hero_hp_text.text = "Vida %d/%d%s" % [actor.hp, actor.max_hp, " · Último Fôlego" if actor.deaths_door else ""]
	_hero_instinct.value = actor.instinct
	_hero_status.text = status_text(actor, false)


## Fichas e efeitos da unidade em palavras curtas.
func status_text(unit: AHCombat.Unit, short: bool) -> String:
	var parts := PackedStringArray()
	var t := unit.tokens
	if t.block > 0: parts.append(("Bloq %d" if short else "Bloqueio %d") % t.block)
	if t.dodge > 0: parts.append(("Esq %d" if short else "Esquiva %d") % t.dodge)
	if t.vuln > 0: parts.append(("Vuln %d" if short else "Vulnerável %d") % t.vuln)
	if t.guard > 0: parts.append("Guarda")
	if unit.mark_duration > 0: parts.append("Marca")
	if unit.stun_turns > 0: parts.append("Atord")
	if unit.bleed.duration > 0: parts.append(("Sangr %d" if short else "Sangramento %d") % unit.bleed.magnitude)
	if unit.blight.duration > 0: parts.append(("Cont %d" if short else "Contaminação %d") % unit.blight.magnitude)
	if unit.blind: parts.append("Cego")
	if unit.weak: parts.append("Fraco")
	if unit.immobilize_turns > 0: parts.append("Imob")
	if unit.trauma and not short: parts.append("Trauma")
	return " · ".join(parts)


func _process(_delta: float) -> void:
	if not visible or session == null or arena == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for unit_id in _unit_bars:
		var box: Control = _unit_bars[unit_id]
		var card: AHSpriteCard = arena.cards.get(unit_id)
		if card == null or not box.visible:
			continue
		var point := camera.unproject_position(card.global_position + Vector3(0, card.head_height() + 0.25, 0))
		box.position = point - Vector2(box.size.x * 0.5, box.size.y)
	for marker in _markers:
		var target: Vector3 = marker.get_meta("world")
		var screen := camera.unproject_position(target)
		marker.position = screen - Vector2(marker.size.x * 0.5, marker.size.y + 70)


# ---------------------------------------------------------------- turno do herói

## Mostra as opções do herói e espera o comando: {kind: ability/move/defend/flee, ability_id, rank}.
func ask_command(actor_id: String) -> Dictionary:
	_actor_id = actor_id
	_message.text = ""
	_panel.visible = true
	_build_abilities()
	waiting = true
	var command: Dictionary = await command_chosen
	waiting = false
	# Durante o lance, o painel não mostra os botões de quem já agiu.
	for child in _abilities.get_children():
		child.queue_free()
	_description.text = ""
	_set_enabled(false)
	# Durante o lance o painel sai da frente: a luta fica inteira à vista.
	_panel.visible = false
	return command


func show_waiting(text: String) -> void:
	_message.text = text
	_clear_markers()
	_set_enabled(false)


func show_message(text: String) -> void:
	_message.text = text


func _set_enabled(enabled: bool) -> void:
	for child in _abilities.get_children() + _actions.get_children():
		if child is Button:
			child.disabled = not enabled or child.get_meta("locked", false)


func _build_abilities() -> void:
	for child in _abilities.get_children():
		child.queue_free()
	_options = session.ability_options(_actor_id)
	var first: Button
	for option in _options:
		var button := Button.new()
		button.custom_minimum_size = Vector2(250, 112)
		button.text = ""
		style_button(button)
		var box := HBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 10
		box.offset_top = 8
		box.offset_right = -8
		box.offset_bottom = -8
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 10)
		button.add_child(box)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(80, 80)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var path := arena.icon_path(option.id)
		if path != "":
			icon.texture = load(path)
		if not option.usable:
			icon.modulate = Color(0.45, 0.45, 0.45)
		box.add_child(icon)
		var text_box := VBoxContainer.new()
		text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(text_box)
		var name_label := make_label(option.name, 18, TEXT if option.usable else MUTED)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_box.add_child(name_label)
		var extra: String = option.reason
		if extra == "" and option.uses >= 0:
			extra = "%d uso(s)" % option.uses
		text_box.add_child(make_label(extra, 14, GOLD if option.usable else Color(0.85, 0.5, 0.4)))
		button.set_meta("locked", not option.usable)
		button.disabled = not option.usable
		button.pressed.connect(_on_ability.bind(option))
		button.focus_entered.connect(_describe.bind(option))
		button.mouse_entered.connect(_describe.bind(option))
		_abilities.add_child(button)
		if first == null and option.usable:
			first = button
	for child in _actions.get_children():
		var kind: String = child.get_meta("kind")
		var locked: bool = (kind == "move" and session.move_targets(_actor_id).is_empty()) or (kind == "flee" and not session.can_flee())
		child.set_meta("locked", locked)
		child.disabled = locked
	_description.text = "Escolha uma ação para %s." % session.state.find_unit(_actor_id).display_name
	(first if first else _actions.get_child(1)).grab_focus.call_deferred()


func _describe(option: Dictionary) -> void:
	_description.text = "%s — %s" % [option.name, option.description.replace("\n", " · ")] + ("" if option.usable else "  (%s)" % option.reason)


func _describe_action(kind: String) -> void:
	_description.text = {"move": "Mover — troca de posição com o aliado vizinho.", "defend": "Defender — +1 Bloqueio e passa a vez.",
		"flee": "Fugir — 60% de chance de a equipe recuar e sair da luta."}[kind]


func _on_ability(option: Dictionary) -> void:
	if option.self:
		command_chosen.emit({"kind": "ability", "ability_id": option.id, "rank": session.state.find_unit(_actor_id).rank})
		return
	_choosing = option.id
	_show_markers(option.targets, option.enemy_side, func(rank): command_chosen.emit({"kind": "ability", "ability_id": option.id, "rank": rank}))


func _on_action(kind: String) -> void:
	match kind:
		"move":
			_choosing = "move"
			_show_markers(session.move_targets(_actor_id), false, func(rank): command_chosen.emit({"kind": "move", "rank": rank}))
		_:
			command_chosen.emit({"kind": kind})


# ---------------------------------------------------------------- alvos

func _show_markers(ranks: Array, enemy_side: bool, on_pick: Callable) -> void:
	_clear_markers()
	_set_enabled(false)
	var team: Array = session.state.enemy_team if enemy_side else session.state.player_team
	for rank in ranks:
		var unit = AHCombatEngine._find(team, func(u): return session.engine.occupies_rank(u, rank) and AHCombatEngine.alive_any(u))
		var world: Vector3
		var label := "Posição %d" % rank
		if unit != null and arena.cards.has(unit.id):
			var card: AHSpriteCard = arena.cards[unit.id]
			world = card.global_position + Vector3(0, card.head_height() + 0.3, 0)
			label = unit.display_name
		else:
			var probe := AHCombat.Unit.new()
			probe.is_player = not enemy_side
			probe.rank = rank
			world = arena.slot_position(probe) + Vector3(0, 2.2, 0)
		var marker := Button.new()
		marker.text = "▼ " + label
		marker.custom_minimum_size = Vector2(170, 44)
		style_button(marker, Color(1.0, 0.85, 0.45))
		marker.set_meta("world", world)
		marker.pressed.connect(func():
			_clear_markers()
			_set_enabled(true)
			on_pick.call(rank))
		add_child(marker)
		_markers.append(marker)
	for i in _markers.size():
		_markers[i].focus_neighbor_left = _markers[(i - 1 + _markers.size()) % _markers.size()].get_path()
		_markers[i].focus_neighbor_right = _markers[(i + 1) % _markers.size()].get_path()
	_description.text = "Escolha o alvo (Backspace ou B volta)."
	if not _markers.is_empty():
		_markers[0].grab_focus.call_deferred()


func _clear_markers() -> void:
	for marker in _markers:
		marker.queue_free()
	_markers.clear()
	_choosing = ""


func _unhandled_input(event: InputEvent) -> void:
	if visible and _choosing != "" and event.is_action_pressed("cancel"):
		_clear_markers()
		_set_enabled(true)
		_build_abilities()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- resultado

## Mostra o fim da luta e espera "Continuar" (no modo automático, segue sozinho).
func show_result(result: String, automatic: bool) -> void:
	_panel.visible = false
	_message.text = ""
	_clear_markers()
	for child in _result.get_children():
		child.queue_free()
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	_result.add_child(box)
	var titles := {"victory": "Vitória", "defeat": "Derrota", "escaped": "Fuga"}
	var notes := {"victory": "A patrulha foi neutralizada.", "defeat": "Todos caíram nas ruínas.", "escaped": "A equipe recuou pelas sombras."}
	var title := make_label(titles.get(result, result), 48, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var note := make_label(notes.get(result, ""), 22)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	var summary := PackedStringArray()
	for unit in session.state.player_team:
		summary.append("%s %d/%d%s" % [unit.display_name, unit.hp, unit.max_hp, " (caído)" if unit.hp <= 0 else ""])
	var lines := make_label("\n".join(summary), 18, MUTED)
	lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(lines)
	var button := Button.new()
	button.text = "Continuar"
	button.custom_minimum_size = Vector2(220, 52)
	style_button(button)
	button.pressed.connect(func(): result_closed.emit())
	box.add_child(button)
	_result.visible = true
	button.grab_focus.call_deferred()
	if automatic:
		get_tree().create_timer(1.5).timeout.connect(func(): result_closed.emit())
	await result_closed
	_result.visible = false
