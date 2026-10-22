## HUD de combate (a proposta de UX, etapa 1), montado em código na base de 1920x1080:
## - em cima, a ordem da rodada com o rosto de cada um (quem age agora em dourado, inimigos com aro de cobre);
## - sob os pés de cada personagem, uma placa com nome, vida em número e os estados por extenso;
## - embaixo, o herói da vez por inteiro (vida e instinto até a crise), os quatro cartões de habilidade (o número, de
##   quais posições sai e quais alcança, a tecla e o motivo quando não dá) e as ações com tecla;
## - ao apontar uma habilidade ou um alvo, a dica completa: o que faz, quem atinge, se derruba e os termos explicados;
## - o registro da luta à direita, legível.
class_name AHCombatHud
extends Control

signal command_chosen(command: Dictionary)
signal result_closed

const S = preload("res://scripts/ui/ui_style.gd")
const GOLD := S.GOLD
const INK := Color(0.055, 0.066, 0.074, 0.9)
const TEXT := S.TEXT
const MUTED := S.MUTED
## Onde fica o painel de baixo (a placa sob os pés não passa daqui).
const DOCK_TOP := 846.0
const ACTIONS := [["Mover", "move", "Q", "combat_move"], ["Defender", "defend", "W", "combat_defend"],
	["Mochila", "item", "I", "inventory"], ["Fugir", "flee", "F", "combat_flee"]]

var arena: AHCombatArena
var session: AHCombatSession
var _order: HBoxContainer
var _order_panel: PanelContainer
var _panel: PanelContainer
var _hero_face: TextureRect
var _hero_name: Label
var _hero_hp: ProgressBar
var _hero_hp_text: Label
var _hero_instinct: ProgressBar
var _hero_instinct_text: Label
var _hero_status: HFlowContainer
var _abilities: HBoxContainer
var _actions: VBoxContainer
var _description: Label
var _message: Label
var _log: Label
var _log_panel: PanelContainer
var _tip: PanelContainer
var _tip_box: VBoxContainer
var _result: PanelContainer
var _unit_bars := {}
var _markers: Array = []
## A prévia da habilidade mirada: uma marca sobre cada outro atingido (o par da granada, o vizinho do coquetel).
var _preview_marks: Array = []
var _actor_id := ""
var _options: Array = []
var _choosing := ""
var _bag: PanelContainer
var _crisis: Control
## Esperando o comando do herói (a captura usa para jogar por ele).
var waiting := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


# ---------------------------------------------------------------- peças (usadas também pelas outras telas)

static func panel_style(alpha: float = 0.9) -> StyleBox:
	return S.panel(alpha)


static func make_label(text: String, size: int, color: Color = TEXT) -> Label:
	return S.label(text, size, color)


static func make_bar(color: Color, height: float) -> ProgressBar:
	return S.bar(color, height)


## O botão do jogo com as molduras do Codex (#20): normal, sobre (hover), pressionado (filete interno), desligado e, para
## o comando principal, a barra lateral. O foco do teclado e do controle são as cantoneiras de fora (#25), na cor accent.
static func style_button(button: Button, accent: Color = GOLD, primary: bool = false) -> void:
	var margins := Vector4(20, 10, 20, 10)
	button.add_theme_stylebox_override("normal", S.frame("button_primary" if primary else "button_normal", 0.96, 1.0, margins))
	button.add_theme_stylebox_override("hover", S.frame("button_hover", 0.98, 1.0, margins))
	button.add_theme_stylebox_override("pressed", S.frame("button_pressed", 0.98, 1.0, margins + Vector4(0, 2, 0, -2)))
	button.add_theme_stylebox_override("disabled", S.frame("button_disabled", 0.9, 1.0, margins))
	var focus := AHFocusCorners.new()
	focus.color = Color(accent, 1.0) if accent != GOLD else TEXT
	AHFocusCorners.attach(button, focus)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_disabled_color", MUTED.darkened(0.3))
	button.add_theme_font_size_override("font_size", S.px(20))
	# O clique da interface em todo botão do jogo (SW_UI_Click).
	if not button.has_meta("click"):
		button.set_meta("click", true)
		button.pressed.connect(func(): Sound.click())


# ---------------------------------------------------------------- montagem

func _build() -> void:
	_order_panel = PanelContainer.new()
	var order_style := S.panel(0.86)
	order_style.content_margin_top = 6
	order_style.content_margin_bottom = 6
	_order_panel.add_theme_stylebox_override("panel", order_style)
	_order_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_order_panel)
	_order = HBoxContainer.new()
	_order.add_theme_constant_override("separation", 12)
	_order.alignment = BoxContainer.ALIGNMENT_CENTER
	_order.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_order_panel.add_child(_order)

	_message = S.label("", 28, TEXT, "bold")
	_message.position = Vector2(360, 150)
	_message.size = Vector2(1200, 44)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message)

	_log_panel = PanelContainer.new()
	var log_style := S.panel(0.78, Color(S.COPPER, 0.35), 1)
	_log_panel.add_theme_stylebox_override("panel", log_style)
	_log_panel.position = Vector2(1474, 132)
	_log_panel.custom_minimum_size = Vector2(420, 0)
	_log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_log_panel)
	var log_box := VBoxContainer.new()
	log_box.add_theme_constant_override("separation", 4)
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_panel.add_child(log_box)
	log_box.add_child(S.label("REGISTRO", 15, S.COPPER, "bold"))
	_log = S.label("", S.MIN_TEXT, TEXT)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.custom_minimum_size = Vector2(390, 0)
	log_box.add_child(_log)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", S.panel(0.92))
	_panel.position = Vector2(24, DOCK_TOP)
	_panel.size = Vector2(1872, 210)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_panel.add_child(row)

	# O herói da vez: rosto, nome, vida e instinto até a crise.
	var hero := HBoxContainer.new()
	hero.custom_minimum_size = Vector2(360, 0)
	hero.add_theme_constant_override("separation", 14)
	row.add_child(hero)
	_hero_face = TextureRect.new()
	_hero_face.custom_minimum_size = Vector2(104, 104)
	_hero_face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero.add_child(_hero_face)
	var hero_box := VBoxContainer.new()
	hero_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_box.add_theme_constant_override("separation", 4)
	hero.add_child(hero_box)
	_hero_name = S.label("", 30, GOLD, "display")
	hero_box.add_child(_hero_name)
	_hero_hp_text = S.label("", S.MIN_TEXT)
	hero_box.add_child(_hero_hp_text)
	_hero_hp = S.bar(Color(0.8, 0.27, 0.22), 14)
	hero_box.add_child(_hero_hp)
	_hero_instinct_text = S.label("", 16, S.VIOLET)
	_hero_instinct_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hero_instinct_text.custom_minimum_size = Vector2(230, 0)
	_hero_instinct_text.mouse_filter = Control.MOUSE_FILTER_PASS
	_hero_instinct_text.tooltip_text = S.GLOSSARY.Instinto
	hero_box.add_child(_hero_instinct_text)
	_hero_instinct = S.bar(Color(0.6, 0.48, 0.92), 8)
	_hero_instinct.max_value = 200
	hero_box.add_child(_hero_instinct)
	_hero_status = HFlowContainer.new()
	_hero_status.add_theme_constant_override("h_separation", 6)
	_hero_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_box.add_child(_hero_status)

	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 6)
	row.add_child(middle)
	_description = S.label("", S.MIN_TEXT, MUTED)
	_description.custom_minimum_size = Vector2(0, 26)
	middle.add_child(_description)
	_abilities = HBoxContainer.new()
	_abilities.add_theme_constant_override("separation", 10)
	middle.add_child(_abilities)

	_actions = VBoxContainer.new()
	_actions.custom_minimum_size = Vector2(236, 0)
	_actions.add_theme_constant_override("separation", 6)
	row.add_child(_actions)
	for spec in ACTIONS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(236, S.px(42))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = spec[0]
		style_button(button)
		var key := S.action_cap(spec[3])
		button.add_child(key)
		key.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
		button.pressed.connect(_on_action.bind(spec[1]))
		button.focus_entered.connect(_describe_action.bind(spec[1]))
		button.mouse_entered.connect(_describe_action.bind(spec[1]))
		button.mouse_exited.connect(_hide_tip)
		button.set_meta("kind", spec[1])
		_actions.add_child(button)

	_tip = PanelContainer.new()
	_tip.add_theme_stylebox_override("panel", S.panel(0.96, GOLD.darkened(0.2)))
	_tip.custom_minimum_size = Vector2(460, 0)
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	add_child(_tip)
	_tip_box = VBoxContainer.new()
	_tip_box.add_theme_constant_override("separation", 6)
	_tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(_tip_box)

	_result = PanelContainer.new()
	_result.add_theme_stylebox_override("panel", S.panel(0.95))
	_result.position = Vector2(660, 300)
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
		_unit_bars[unit.id] = _make_plate(unit)
	refresh()


func close() -> void:
	visible = false
	_close_bag()
	_clear_markers()
	_hide_tip()
	for bar in _unit_bars.values():
		bar.queue_free()
	_unit_bars.clear()


func _art_of(unit: AHCombat.Unit) -> Dictionary:
	return arena.hero_art(unit.hero_id).get("idle", {}) if unit.is_player else arena.enemy_art(unit.enemy_id).get("idle", {})


## A placa sob os pés: nome e vida em número, a barra, o instinto (heróis) e os estados por extenso.
func _make_plate(unit: AHCombat.Unit) -> Control:
	var plate := PanelContainer.new()
	var style := S.flat(0.84, Color(S.COPPER, 0.4), 1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 5
	plate.add_theme_stylebox_override("panel", style)
	plate.custom_minimum_size = Vector2(176 if unit.is_player else 246, 0)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(box)
	var top := HBoxContainer.new()
	top.name = "Top"
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	var name_label := S.label(unit.display_name, 17, TEXT, "bold")
	name_label.name = "Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	top.add_child(name_label)
	var hp_text := S.label("", 17, MUTED)
	hp_text.name = "HpText"
	top.add_child(hp_text)
	var hp := S.bar(Color(0.8, 0.27, 0.22) if unit.is_player else S.ENEMY, 9)
	hp.name = "Hp"
	box.add_child(hp)
	if unit.is_player:
		var instinct := S.bar(Color(0.6, 0.48, 0.92), 4)
		instinct.max_value = 200
		instinct.name = "Instinct"
		box.add_child(instinct)
	else:
		# A intenção: o que ele faria se a vez dele fosse agora (engine.enemy_intent); muda conforme a luta. O ícone da
		# entrega #18 vem antes do texto.
		var intent_row := HBoxContainer.new()
		intent_row.name = "IntentRow"
		intent_row.add_theme_constant_override("separation", 6)
		intent_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(intent_row)
		var intent_icon := TextureRect.new()
		intent_icon.name = "IntentIcon"
		intent_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		intent_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		intent_icon.custom_minimum_size = Vector2.ONE * S.px(22)
		intent_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		intent_icon.mouse_filter = Control.MOUSE_FILTER_PASS
		intent_row.add_child(intent_icon)
		var intent := S.label("", 15, S.ENEMY, "bold")
		intent.name = "Intent"
		intent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		intent.custom_minimum_size = Vector2(200, 0)
		intent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		intent.mouse_filter = Control.MOUSE_FILTER_PASS
		intent_row.add_child(intent)
	var status := HFlowContainer.new()
	status.name = "Status"
	status.add_theme_constant_override("h_separation", 4)
	status.add_theme_constant_override("v_separation", 3)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(status)
	plate.set_meta("style", style)
	add_child(plate)
	move_child(plate, 0)
	return plate


## Tira os filhos já (não só no fim do quadro), para o painel medir o tamanho novo na hora.
static func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## Um estado (S.statuses): o ícone da entrega #18 tingido de bom ou ruim (a forma também diz: bom tem cantoneiras retas
## no topo, ruim tem o topo chanfrado), com o número de fichas ou de vezes; o nome e a explicação ficam na dica do mouse
## (e na do foco, ao mirar). Sem ícone (Cego, Fraco, Imobilizado, Trauma), a ficha escrita de antes.
func _status_chip(entry: Array, size: int = 15) -> PanelContainer:
	var good: bool = entry[1]
	var icon_name: String = entry[2] if entry.size() > 2 else ""
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	style.border_color = Color(S.OK if good else S.DANGER, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 3 if icon_name != "" else 5
	style.content_margin_right = 4 if icon_name != "" else 5
	chip.add_theme_stylebox_override("panel", style)
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	chip.tooltip_text = S.status_tip(entry) if entry.size() > 4 else String(entry[0])
	var texture := S.combat_icon("status-%s_%s" % [icon_name, "good" if good else "bad"]) if icon_name != "" else null
	if texture == null:
		chip.add_child(S.label(entry[0], size, TEXT))
		return chip
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * S.px(size + 7)
	icon.modulate = S.OK if good else S.DANGER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.name = "Icon"
	row.add_child(icon)
	if int(entry[3]) > 0:
		var count := S.label(str(entry[3]), size, TEXT, "bold")
		count.name = "Count"
		row.add_child(count)
	return chip


## Atualiza placas, ordem dos turnos, painel do herói e o registro.
func refresh() -> void:
	if session == null:
		return
	var current := session.state.current_turn_unit_id
	for unit in session.units():
		var plate: PanelContainer = _unit_bars.get(unit.id)
		if plate == null:
			continue
		var card: AHSpriteCard = arena.cards.get(unit.id)
		plate.visible = card != null and card.visible and (unit.hp > 0 or unit.is_player)
		var box := plate.get_child(0)
		var hp: ProgressBar = box.get_node("Hp")
		hp.max_value = unit.max_hp
		hp.value = unit.hp
		(box.get_node("Top/HpText") as Label).text = "%d/%d" % [unit.hp, unit.max_hp] if not unit.deaths_door else "Último Fôlego"
		if unit.is_player:
			(box.get_node("Instinct") as ProgressBar).value = unit.instinct
		elif unit.hp > 0:
			_show_intent(box.get_node("IntentRow/Intent"), session.engine.enemy_intent(unit.id))
		var style: StyleBoxFlat = plate.get_meta("style")
		style.border_color = GOLD if unit.id == current else Color(S.COPPER, 0.4)
		style.set_border_width_all(2 if unit.id == current else 1)
		var status: HFlowContainer = box.get_node("Status")
		for child in status.get_children():
			child.queue_free()
		for entry in S.statuses(unit):
			status.add_child(_status_chip(entry))
		# A placa encolhe de volta quando a intenção ou os estados ficam mais curtos.
		plate.reset_size.call_deferred()
	_refresh_order(current)
	var lines := session.state.combat_log
	_log.text = "\n".join(lines.slice(maxi(0, lines.size() - 3)))
	_log_panel.visible = not lines.is_empty()
	var actor := session.current_actor()
	if actor != null and actor.is_player:
		_show_hero(actor)


## A linha da intenção na placa do inimigo: a ação e em quem (com "?" quando ele está entre dois planos parecidos).
func _show_intent(label: Label, intent: Dictionary) -> void:
	var names: Array = intent.target_ids.map(func(id): return session.state.find_unit(id).display_name if session.state.find_unit(id) else id)
	var text := ""
	var color: Color = S.ENEMY
	# O ícone da intenção (art/ui/icons/intent-*): ataque, ataque em área (mais de um alvo de uma vez), cura, bloqueio,
	# mover, atordoado; sem plano claro, a interrogação.
	var icon := "unknown"
	match intent.kind:
		"attack":
			text = "%s → %s" % [intent.name, (" ou " if intent.either else " e ").join(names)] if not names.is_empty() else intent.name
			icon = "attack_area" if names.size() > 1 and not intent.either else "attack"
		"heal":
			text = "%s (se cura)" % intent.name
			color = S.OK
			icon = "heal"
		"defend":
			text = "%s (bloqueio)" % intent.name
			color = S.BLUE
			icon = "block"
		"move":
			text = intent.name
			color = S.MUTED
			icon = "move"
		"stunned":
			text = intent.name
			color = S.MUTED
			icon = "stunned"
	if text != "" and not intent.sure and not intent.either:
		text += " ?"
	label.text = text
	label.add_theme_color_override("font_color", color)
	var tip := "Intenção: o que ele faria se a vez fosse agora. Muda conforme a luta (quem cai, quem protege, a posição)%s." % (
		"" if intent.sure else "; com \"?\", ele está entre dois planos parecidos")
	label.tooltip_text = tip
	var icon_rect := label.get_parent().get_node_or_null("IntentIcon") as TextureRect
	if icon_rect != null:
		icon_rect.texture = S.combat_icon("intent-" + icon) if text != "" else null
		icon_rect.modulate = color
		icon_rect.visible = text != ""
		icon_rect.tooltip_text = tip


## A ordem da rodada com rostos: quem age agora maior e dourado; quem já agiu sai da fila.
func _refresh_order(current: String) -> void:
	_clear(_order)
	var round_label := S.label("RODADA %d" % session.state.round, 17, S.COPPER, "bold")
	round_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_order.add_child(round_label)
	for item in session.state.initiative_queue:
		var unit := session.state.find_unit(item.unit_id)
		if unit == null or (unit.hp <= 0 and not unit.deaths_door) or (item.acted and item.unit_id != current):
			continue
		var now: bool = item.unit_id == current
		var who := VBoxContainer.new()
		who.add_theme_constant_override("separation", 2)
		who.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ring: Color = GOLD if now else (S.ENEMY if not unit.is_player else Color(1, 1, 1, 0.35))
		var face := S.portrait(_art_of(unit), 72 if now else 54, ring, 0.07 if now else 0.06)
		face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		who.add_child(face)
		var name_label := S.label(unit.display_name.split(" ")[0] + (" · agora" if now else ""), 16 if now else 15, GOLD if now else MUTED, "bold" if now else "body")
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		who.add_child(name_label)
		_order.add_child(who)
	_order_panel.size = _order_panel.get_combined_minimum_size()
	_order_panel.position = Vector2(960 - _order_panel.size.x * 0.5, 12)


func _show_hero(actor: AHCombat.Unit) -> void:
	var art := _art_of(actor)
	if _hero_face.get_meta("unit", "") != actor.id:
		var face := S.portrait(art, 104, GOLD, 0.05)
		_hero_face.texture = face.texture
		_hero_face.material = face.material
		_hero_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_hero_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_hero_face.set_meta("unit", actor.id)
	_hero_name.text = actor.display_name
	_hero_hp.max_value = actor.max_hp
	_hero_hp.value = actor.hp
	_hero_hp_text.text = "Vida %d/%d%s" % [actor.hp, actor.max_hp, " · Último Fôlego" if actor.deaths_door else ""]
	_hero_instinct.value = actor.instinct
	_hero_instinct_text.text = "Instinto %d/200 · em 200, crise" % actor.instinct
	for child in _hero_status.get_children():
		child.queue_free()
	for entry in S.statuses(actor):
		_hero_status.add_child(_status_chip(entry, 16))
	if actor.trauma:
		_hero_status.add_child(_status_chip(["Trauma", false], 16))


## Fichas e efeitos da unidade em palavras curtas (o registro e os testes usam).
func status_text(unit: AHCombat.Unit, _short: bool) -> String:
	return " · ".join(S.statuses(unit).map(func(e): return e[0]))


## Teclado e controle (#5): a tela de cima da luta, onde o foco fica e onde Interagir confirma o botão com foco.
func _focus_scope() -> Control:
	if _bag != null:
		return _bag
	if _result.visible:
		return _result
	# Escolhendo o alvo: os marcadores ficam no próprio HUD.
	if _choosing != "":
		return self
	return _panel if waiting else null


func _input(event: InputEvent) -> void:
	if visible and S.press_focused(_focus_scope(), event):
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _bag != null or _result.visible or (waiting and _choosing == ""):
		S.keep_focus(_focus_scope())
	if not visible or session == null or arena == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var short_plates: Array[Rect2] = []
	for unit_id in _unit_bars:
		var plate: Control = _unit_bars[unit_id]
		var card: AHSpriteCard = arena.cards.get(unit_id)
		if card == null or not plate.visible:
			continue
		var feet := camera.unproject_position(card.global_position)
		var head := camera.unproject_position(card.global_position + Vector3(0, card.body_height * 1.05, 0))
		var short := card.body_height < SHORT_HEIGHT
		var y := plate_y(feet.y, head.y, short, plate.size.y, _dock_top() - plate.size.y - 6 if _panel.visible else INF)
		plate.position = Vector2(feet.x - plate.size.x * 0.5, y)
		if short:
			short_plates.append(Rect2(plate.position, plate.size))
	for marker in _markers + _preview_marks:
		var target: Vector3 = marker.get_meta("world")
		var screen := camera.unproject_position(target)
		marker.position = screen - Vector2(marker.size.x * 0.5, marker.size.y + 24)
		# O marcador do alvo não cobre a placa de um baixinho (que fica acima da cabeça): sobe para cima dela.
		for rect in short_plates:
			if rect.intersects(Rect2(marker.position, marker.size)):
				marker.position.y = rect.position.y - marker.size.y - 6


## Abaixo desta altura (m) o personagem é baixinho (os ajudantes do John, o Rastejante de Cabos): a placa sob os pés
## subiria por cima do corpo quando encosta no painel de baixo.
const SHORT_HEIGHT := 0.9


## Onde fica a placa (y na tela): o baixinho, sempre acima da cabeça (não pula entre cima e baixo a cada lance); os
## outros, sob os pés, sem passar do limite do painel de baixo (dock_limit; INF sem o painel).
static func plate_y(feet_y: float, head_y: float, short: bool, plate_height: float, dock_limit: float) -> float:
	if short:
		return head_y - plate_height - 8.0
	return minf(feet_y + 10.0, dock_limit)


# ---------------------------------------------------------------- turno do herói

## Mostra as opções do herói e espera o comando: {kind: ability/move/defend/flee/item, ability_id, rank}.
## note: um aviso que fica na tela enquanto ele decide (o item da Mochila que acabou de usar).
func ask_command(actor_id: String, note: String = "") -> Dictionary:
	_actor_id = actor_id
	_message.text = note
	_panel.visible = true
	_build_abilities()
	waiting = true
	var command: Dictionary = await command_chosen
	waiting = false
	# A Mochila não é modal: um comando escolhido com ela aberta (Defender, uma habilidade) fecha ela também. Aberta, ela
	# travava os atalhos dos próximos heróis e passava para a luta seguinte.
	_close_bag()
	# Durante o lance, o painel não mostra os botões de quem já agiu.
	for child in _abilities.get_children():
		child.queue_free()
	_description.text = ""
	_set_enabled(false)
	_hide_tip()
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
			if child.has_meta("ability_id"):
				_style_ability(child)


## O cartão de habilidade com as molduras do Codex (#20, #25): normal; escolhida (o canto triangular) enquanto o jogador
## escolhe o alvo; bloqueada (o corte diagonal, com o motivo escrito no cartão); e, desligada só porque outra foi
## escolhida, a normal apagada.
func _style_ability(button: Button) -> void:
	var margins := Vector4(10, 8, 10, 8)
	var chosen: bool = _choosing != "" and button.get_meta("ability_id", "") == _choosing
	button.add_theme_stylebox_override("normal", S.frame("ability_normal", 0.96, 1.0, margins))
	var hover := S.frame("ability_normal", 1.0, 1.0, margins)
	hover.modulate_color = Color(1.18, 1.12, 1.0)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", S.frame("ability_selected", 1.0, 1.0, margins))
	var disabled: StyleBoxTexture
	if chosen:
		disabled = S.frame("ability_selected", 1.0, 1.0, margins)
	elif button.get_meta("locked", false):
		disabled = S.frame("ability_locked", 0.92, 1.0, margins)
	else:
		disabled = S.frame("ability_normal", 0.6, 1.0, margins)
	button.add_theme_stylebox_override("disabled", disabled)


## As bolinhas de posição: as do herói da direita (frente) para a esquerda, como na tela; as do inimigo da esquerda
## (frente) para a direita.
func _pips(caption: String, ranks: Array, hero_side: bool, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag := S.label(caption, 14, MUTED, "bold")
	tag.custom_minimum_size = Vector2(24, 0)
	row.add_child(tag)
	var order: Array = [4, 3, 2, 1] if hero_side else [1, 2, 3, 4]
	for rank in order:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(13, 13)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(7)
		style.set_border_width_all(2)
		style.border_color = color if ranks.has(rank) else Color(MUTED, 0.6)
		style.bg_color = color if ranks.has(rank) else Color(0, 0, 0, 0)
		dot.add_theme_stylebox_override("panel", style)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
	return row


## O número do cartão e da dica: a faixa de verdade nesta luta (com o treino da Pesquisa, uma ★ ao lado; a descrição
## diz "treinado" por extenso).
func _number_of(ability_id: String) -> Array:
	var ability: Dictionary = session.data.abilities[ability_id]
	if ability.DamageRange.Max > 0:
		var damage := session.effective_range(ability_id, "damage")
		return ["%d–%d" % [damage.Min, damage.Max], "dano ★" if damage.trained else "dano", GOLD]
	if ability.HealRange.Max > 0:
		var heal := session.effective_range(ability_id, "heal")
		return ["+%d–%d" % [heal.Min, heal.Max], "cura ★" if heal.trained else "cura", S.OK]
	return ["", "", GOLD]


## take_focus: a primeira carta ganha o foco (false quando a Mochila está aberta por cima: o foco fica nela).
func _build_abilities(take_focus: bool = true) -> void:
	for child in _abilities.get_children():
		child.queue_free()
	_options = session.ability_options(_actor_id)
	var first: Button
	for index in _options.size():
		var option: Dictionary = _options[index]
		var ability: Dictionary = session.data.abilities[option.id]
		var button := Button.new()
		button.custom_minimum_size = Vector2(296, S.px(150))
		button.text = ""
		style_button(button)
		var box := HBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 10
		box.offset_top = 8
		# À direita fica a tecla, por cima do nome.
		box.offset_right = -S.px(26)
		box.offset_bottom = -8
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 10)
		button.add_child(box)
		var icon := TextureRect.new()
		# Com o texto maior o ícone encolhe e o cartão continua com a mesma largura.
		var icon_size := roundf(76.0 / S.text_scale)
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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
		text_box.add_theme_constant_override("separation", 2)
		box.add_child(text_box)
		var name_label := S.label(option.name, 18, TEXT if option.usable else MUTED, "bold")
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.custom_minimum_size = Vector2(170, 0)
		text_box.add_child(name_label)
		var number := _number_of(option.id)
		if number[0] != "":
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 6)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.add_child(S.label(number[0], 24, number[2] if option.usable else MUTED, "bold"))
			var unit_label := S.label(number[1], 15, MUTED)
			unit_label.size_flags_vertical = Control.SIZE_SHRINK_END
			line.add_child(unit_label)
			text_box.add_child(line)
		if option.usable:
			text_box.add_child(_pips("de", ability.OriginRanks, true, GOLD))
			if option.self:
				text_box.add_child(S.label("em si mesmo", 14, MUTED))
			else:
				text_box.add_child(_pips("em", ability.TargetRanks, not option.enemy_side, S.DANGER if option.enemy_side else S.OK))
			var extra := ""
			if option.cooldown > 0:
				extra = "Recarga %d" % option.cooldown
			elif option.uses >= 0:
				extra = "%d uso(s)" % option.uses
			if extra != "":
				text_box.add_child(S.label(extra, 14, GOLD))
		else:
			var why := S.label(option.reason, 15, Color(1.0, 0.6, 0.5))
			why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			why.custom_minimum_size = Vector2(170, 0)
			text_box.add_child(why)
		var key := S.action_cap("combat_ability_%d" % (index + 1))
		button.add_child(key)
		key.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
		button.set_meta("locked", not option.usable)
		button.set_meta("ability_id", option.id)
		button.disabled = not option.usable
		_style_ability(button)
		button.pressed.connect(_on_ability.bind(option))
		button.focus_entered.connect(_describe.bind(option, button))
		button.mouse_entered.connect(_describe.bind(option, button))
		button.mouse_exited.connect(_hide_tip)
		_abilities.add_child(button)
		if first == null and option.usable:
			first = button
	for child in _actions.get_children():
		var kind: String = child.get_meta("kind")
		var locked: bool = (kind == "move" and session.move_targets(_actor_id).is_empty()) or (kind == "flee" and not session.can_flee())
		child.set_meta("locked", locked)
		child.disabled = locked
		if kind == "item":
			child.text = "Mochila · %d" % AHJourneyRules.food(Campaign.state)
			child.tooltip_text = "%d de comida na Mochila" % AHJourneyRules.food(Campaign.state)
	_description.text = "Vez de %s: escolha uma habilidade (1–4) ou uma ação." % session.state.find_unit(_actor_id).display_name
	# O painel se ajusta antes do foco, que posiciona a dica acima dele.
	_fit_dock.call_deferred()
	if take_focus:
		(first if first else _actions.get_child(1)).grab_focus.call_deferred()


## O painel de baixo cresce para cima quando o texto é maior (a base é 210 px, colada a 24 px da borda).
func _fit_dock() -> void:
	var height := maxf(210.0, _panel.get_combined_minimum_size().y)
	_panel.size = Vector2(1872, height)
	_panel.position = Vector2(24, 1056.0 - height)


func _dock_top() -> float:
	return _panel.position.y


## O tamanho do texto ou as cores mudaram nas Opções (AHUiStyle.retune): as fichas e o painel se ajustam ao texto novo.
## As cartas de habilidade (altura, recuo e ícone pelo tamanho do texto) são refeitas com a mesma carta em foco; os
## botões de ação crescem junto.
func restyle() -> void:
	refresh()
	for button in _actions.get_children():
		button.custom_minimum_size.y = S.px(42)
	if waiting and _choosing == "":
		var owner := get_viewport().gui_get_focus_owner()
		var focused: int = _abilities.get_children().find(owner)
		# Com a Mochila aberta, o foco continua nela (o Enter não escolhe uma carta por trás).
		_build_abilities(_bag == null)
		if focused >= 0 and _bag == null:
			await get_tree().process_frame
			if focused < _abilities.get_child_count():
				(_abilities.get_child(focused) as Control).grab_focus()
	_fit_dock.call_deferred()


# ---------------------------------------------------------------- dicas

func _hide_tip() -> void:
	if _choosing == "":
		_tip.visible = false


## A dica completa da habilidade sobre o cartão: o número, o texto, quem atinge (ao mirar) e os termos explicados.
func _describe(option: Dictionary, button: Control = null, rank: int = -1) -> void:
	var ability: Dictionary = session.data.abilities[option.id]
	_clear(_tip_box)
	_tip_box.add_child(S.label(option.name, 26, GOLD, "display"))
	var number := _number_of(option.id)
	var facts := PackedStringArray()
	if number[0] != "":
		facts.append("%s de %s" % [number[0], number[1]])
	if ability.Cooldown > 0:
		facts.append("recarga %d" % ability.Cooldown)
	if ability.UsesMax > 0:
		facts.append("%d usos por expedição" % ability.UsesMax if ability.bUsesPerExpedition else "%d usos" % ability.UsesMax)
	if not facts.is_empty():
		_tip_box.add_child(S.label(" · ".join(facts), S.MIN_TEXT, TEXT, "bold"))
	var row = GameData.row("abilities", option.id)
	var text: String = row.get("Description", "") if row != null else ""
	var body := S.label(text, S.MIN_TEXT, TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(430, 0)
	_tip_box.add_child(body)
	if not option.usable:
		_tip_box.add_child(S.label(option.reason, S.MIN_TEXT, Color(1.0, 0.6, 0.5)))
	# Os termos a explicar, cada um uma vez só: os estados (dos alvos, ao mirar; senão, do herói da vez e dos inimigos) e
	# os que o texto da habilidade cita.
	var terms: Array = []
	if rank > 0:
		var ids: Array = session.hit_ids(_actor_id, option.id, rank)
		var hits := PackedStringArray()
		for id in ids:
			var unit := session.state.find_unit(id)
			if unit == null:
				continue
			var note := "%s (vida %d)" % [unit.display_name, unit.hp]
			if not unit.is_player and ability.DamageRange.Max > 0 and session.effective_range(option.id, "damage").Max >= unit.hp:
				note += " · pode cair"
			# Os estados do alvo por extenso: no foco, a dica faz o papel da dica do mouse sobre os ícones (#30).
			note += _status_words(unit, terms)
			hits.append(note)
		if not hits.is_empty():
			_tip_line("Atinge: " + "; ".join(hits), S.MIN_TEXT, S.DANGER if option.enemy_side else S.OK, "bold")
	else:
		# Sem mirar (o cartão com foco): os estados de quem está na luta, para quem joga no teclado, no controle ou no toque.
		var actor := session.state.find_unit(_actor_id)
		var mine := _status_words(actor, terms) if actor != null else ""
		if mine != "":
			_tip_line("Você:" + mine.trim_prefix(" ·"), 17, TEXT)
		var others := PackedStringArray()
		for enemy in session.state.enemy_team:
			if enemy.hp > 0:
				var words := _status_words(enemy, terms)
				if words != "":
					others.append(enemy.display_name + ":" + words.trim_prefix(" ·"))
		if not others.is_empty():
			_tip_line("; ".join(others), 17, MUTED)
	for word in S.GLOSSARY:
		if not terms.has(word) and (text.contains(word) or text.to_lower().contains(word.to_lower().substr(0, 6))):
			terms.append(word)
	var glosses: Array = []
	for word in terms:
		glosses.append(_tip_line("%s: %s" % [word, S.GLOSSARY.get(word, "")], 16, S.VIOLET))
	# A dica cabe entre o alto da tela e a doca: o que não couber das explicações sai, de baixo para cima.
	var room := _dock_top() - 96.0 - 130.0
	while not glosses.is_empty() and _tip_box.get_combined_minimum_size().y + 24.0 > room:
		var last: Control = glosses.pop_back()
		_tip_box.remove_child(last)
		last.queue_free()
	_place_tip(button)


## " · Sangra 2, Marcado" (vazio sem estados), e os termos de cada estado entram em terms, uma vez só.
func _status_words(unit: AHCombat.Unit, terms: Array) -> String:
	var marks := S.statuses(unit)
	for entry in marks:
		if not terms.has(entry[4]):
			terms.append(entry[4])
	return "" if marks.is_empty() else " · " + ", ".join(marks.map(func(e): return e[0]))


func _tip_line(text: String, size: int, color: Color, kind: String = "body") -> Label:
	var line := S.label(text, size, color, kind)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(430, 0)
	_tip_box.add_child(line)
	return line


func _place_tip(button: Control) -> void:
	_tip.visible = true
	_tip.size = _tip.get_combined_minimum_size()
	var x := 420.0
	if button != null and is_instance_valid(button) and button.is_inside_tree():
		x = button.global_position.x + button.size.x * 0.5 - _tip.size.x * 0.5
	_tip.position = Vector2(clampf(x, 16, 1904 - _tip.size.x), maxf(130, _dock_top() - 96 - _tip.size.y))


func _describe_action(kind: String) -> void:
	var texts := {"move": ["Mover", "Troca de posição com o aliado vizinho. Gasta a vez."],
		"defend": ["Defender", "+1 Bloqueio e passa a vez. " + S.GLOSSARY.Bloqueio],
		"flee": ["Fugir", "60% de chance de a equipe recuar e sair da luta. Na fuga, larga o que carregava."],
		"item": ["Mochila", "Comida ou curativo no herói da vez. Ação livre: a vez continua, um item por vez dele."]}
	_clear(_tip_box)
	_tip_box.add_child(S.label(texts[kind][0], 26, GOLD, "display"))
	var body := S.label(texts[kind][1], S.MIN_TEXT, TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(430, 0)
	_tip_box.add_child(body)
	_place_tip(_actions)
	_tip.position.x = 1904 - _tip.size.x


func _on_ability(option: Dictionary) -> void:
	if option.self:
		command_chosen.emit({"kind": "ability", "ability_id": option.id, "rank": session.state.find_unit(_actor_id).rank})
		return
	_choosing = option.id
	_show_markers(option.targets, option.enemy_side, func(rank): command_chosen.emit({"kind": "ability", "ability_id": option.id, "rank": rank}), option.id)


func _on_action(kind: String) -> void:
	match kind:
		"item":
			_open_bag()
		"move":
			_choosing = "move"
			_show_markers(session.move_targets(_actor_id), false, func(rank): command_chosen.emit({"kind": "move", "rank": rank}))
		_:
			command_chosen.emit({"kind": kind})


## A faixa da crise de instinto: "CRISE DE INSTINTO" e o resultado (superação em dourado, colapso em vermelho).
func show_crisis(text: String, breakthrough: bool) -> void:
	hide_crisis()
	_crisis = ColorRect.new()
	_crisis.color = Color(0, 0, 0, 0.55)
	_crisis.position = Vector2(0, 182)
	_crisis.size = Vector2(1920, 112)
	_crisis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crisis)
	var title := S.label("CRISE DE INSTINTO", 22, S.VIOLET, "bold")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 10)
	title.size = Vector2(1920, 30)
	_crisis.add_child(title)
	var result := S.label(text, 40, Color("fde68a") if breakthrough else Color("f87171"), "display")
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.position = Vector2(0, 42)
	result.size = Vector2(1920, 60)
	_crisis.add_child(result)
	_crisis.modulate.a = 0.0
	create_tween().tween_property(_crisis, "modulate:a", 1.0, 0.2)


func hide_crisis() -> void:
	if _crisis != null:
		_crisis.queue_free()
	_crisis = null


## A Mochila por cima do painel, no herói da vez; o item escolhido vira comando (ação livre: a vez continua).
func _open_bag() -> void:
	if _bag != null:
		return
	_hide_tip()
	Tips.show_tip("bag")
	Sound.play("res://audio/ui/bag_open.ogg")
	_bag = PanelContainer.new()
	_bag.add_theme_stylebox_override("panel", S.panel(0.96))
	_bag.position = Vector2(510, 140)
	_bag.custom_minimum_size = Vector2(900, 0)
	var panel := AHInventoryPanel.new()
	panel.session = session
	panel.closed.connect(_close_bag)
	panel.combat_item.connect(func(kind):
		_close_bag()
		command_chosen.emit({"kind": "item", "item": kind}))
	_bag.add_child(panel)
	add_child(_bag)


func _close_bag() -> void:
	if _bag != null:
		_bag.queue_free()
	_bag = null


func bag_open() -> bool:
	return _bag != null


# ---------------------------------------------------------------- alvos

## ability_id: a habilidade mirada; apontar uma posição mostra todos que ela atinge dali e a dica com o resultado.
func _show_markers(ranks: Array, enemy_side: bool, on_pick: Callable, ability_id: String = "") -> void:
	_clear_markers()
	# Antes de desligar os cartões: o escolhido ganha a moldura de escolhida (_style_ability lê _choosing).
	_choosing = ability_id if ability_id != "" else "move"
	_set_enabled(false)
	var team: Array = session.state.enemy_team if enemy_side else session.state.player_team
	for rank in ranks:
		var unit = AHCombatEngine._find(team, func(u): return session.engine.occupies_rank(u, rank) and AHCombatEngine.alive_any(u))
		var world: Vector3
		var label := "Posição %d" % rank
		if unit != null and arena.cards.has(unit.id):
			var card: AHSpriteCard = arena.cards[unit.id]
			world = card.global_position + Vector3(0, card.head_height() + 0.2, 0)
			label = unit.display_name
		else:
			var probe := AHCombat.Unit.new()
			probe.is_player = not enemy_side
			probe.rank = rank
			world = arena.slot_position(probe) + Vector3(0, 2.0, 0)
		var marker := Button.new()
		marker.text = "▼ " + label
		marker.custom_minimum_size = Vector2(180, 46)
		style_button(marker, Color(1.0, 0.85, 0.45))
		marker.set_meta("world", world)
		marker.set_meta("rank", rank)
		marker.set_meta("label", marker.text)
		if ability_id != "":
			marker.mouse_entered.connect(_preview_hits.bind(ability_id, rank))
			marker.focus_entered.connect(_preview_hits.bind(ability_id, rank))
		marker.pressed.connect(func():
			_clear_markers()
			_set_enabled(true)
			on_pick.call(rank))
		add_child(marker)
		_markers.append(marker)
	for i in _markers.size():
		_markers[i].focus_neighbor_left = _markers[(i - 1 + _markers.size()) % _markers.size()].get_path()
		_markers[i].focus_neighbor_right = _markers[(i + 1) % _markers.size()].get_path()
	_description.text = "Escolha o alvo (%s ou B volta)." % S.key_name("cancel")
	if not _markers.is_empty():
		_markers[0].grab_focus.call_deferred()


func _clear_markers() -> void:
	for marker in _markers:
		marker.queue_free()
	_markers.clear()
	_clear_preview()
	_choosing = ""
	_tip.visible = false


## Quem a habilidade atinge mirando nesta posição (CombatSession.hit_ids, a mesma conta do ataque): a dica mostra todos
## com a vida e se podem cair; cada outro atingido acende o próprio marcador ou ganha a marca "também atingido".
func _preview_hits(ability_id: String, rank: int) -> void:
	_clear_preview()
	var option: Array = _options.filter(func(o): return o.id == ability_id)
	if not option.is_empty():
		var index := _options.find(option[0])
		_describe(option[0], _abilities.get_child(index) if index < _abilities.get_child_count() else null, rank)
	var ids: Array = session.hit_ids(_actor_id, ability_id, rank)
	if ids.size() <= 1:
		return
	for id in ids:
		var unit = session.state.find_unit(id)
		if unit == null or session.engine.occupies_rank(unit, rank) or not arena.cards.has(id):
			continue
		var own: Array = _markers.filter(func(m): return session.engine.occupies_rank(unit, int(m.get_meta("rank"))))
		if not own.is_empty():
			own[0].text = "◆ %s · também" % unit.display_name
			own[0].add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
			continue
		var card: AHSpriteCard = arena.cards[id]
		var mark := S.label("◆ também atingido", S.MIN_TEXT, Color(1.0, 0.85, 0.45), "bold")
		mark.add_theme_constant_override("outline_size", 8)
		mark.set_meta("world", card.global_position + Vector3(0, card.head_height() + 0.2, 0))
		add_child(mark)
		_preview_marks.append(mark)


func _clear_preview() -> void:
	for mark in _preview_marks:
		mark.queue_free()
	_preview_marks.clear()
	for marker in _markers:
		marker.text = marker.get_meta("label")
		marker.add_theme_color_override("font_color", TEXT)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# A Mochila: I abre na vez de um herói; Esc, Backspace ou I fecham.
	if _bag != null and (S.is_back(event) or event.is_action_pressed("menu") or event.is_action_pressed("inventory")):
		_close_bag()
		get_viewport().set_input_as_handled()
		return
	if waiting and _choosing == "" and _bag == null:
		for i in 4:
			if event.is_action_pressed("combat_ability_%d" % (i + 1)) and i < _abilities.get_child_count():
				var button: Button = _abilities.get_child(i)
				if not button.disabled:
					get_viewport().set_input_as_handled()
					button.pressed.emit()
				return
		for spec in ACTIONS:
			if event.is_action_pressed(spec[3]):
				var action: Button = _actions.get_children().filter(func(b): return b.get_meta("kind") == spec[1])[0]
				get_viewport().set_input_as_handled()
				if not action.disabled:
					action.pressed.emit()
				return
	if _choosing != "" and S.is_back(event):
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
	box.add_theme_constant_override("separation", 14)
	_result.add_child(box)
	var titles := {"victory": "Vitória", "defeat": "Derrota", "escaped": "Fuga"}
	var notes := {"victory": "A patrulha foi neutralizada.", "defeat": "Todos caíram nas ruínas.", "escaped": "A equipe recuou pelas sombras."}
	var title := S.label(titles.get(result, result), 48, GOLD if result == "victory" else S.DANGER, "display")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var note := S.label(notes.get(result, ""), 22)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	var team := HBoxContainer.new()
	team.alignment = BoxContainer.ALIGNMENT_CENTER
	team.add_theme_constant_override("separation", 18)
	box.add_child(team)
	for unit in session.state.player_team:
		var who := VBoxContainer.new()
		who.add_theme_constant_override("separation", 4)
		var fallen: bool = unit.hp <= 0
		var face := S.portrait(_art_of(unit), 64, S.DANGER if fallen else Color(1, 1, 1, 0.35))
		face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if fallen:
			face.modulate = Color(0.55, 0.55, 0.6)
		who.add_child(face)
		var line := S.label("%s\n%s" % [unit.display_name, "caído" if fallen else "%d/%d" % [unit.hp, unit.max_hp]], 16, MUTED if fallen else TEXT)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		who.add_child(line)
		team.add_child(who)
	var button := Button.new()
	button.text = "Continuar"
	button.custom_minimum_size = Vector2(240, 52)
	style_button(button)
	button.pressed.connect(func(): result_closed.emit())
	box.add_child(button)
	_result.visible = true
	button.grab_focus.call_deferred()
	if automatic:
		get_tree().create_timer(1.5).timeout.connect(func(): result_closed.emit())
	await result_closed
	_result.visible = false
