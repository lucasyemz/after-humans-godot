## A caixa do briefing e do debriefing (#88): o retrato de quem fala, o nome, a fala e os botões Pular e Próximo (na
## última, o texto de quem chama: "Partir", "Ver o relatório"). Mouse e toque nos botões ou na caixa; Interagir (E, o A
## do controle, Enter) passa a fala; Voltar (Esc, B) pula. Com os tokens do AHUiStyle, para trocar pelo kit da #59/#60.
class_name AHBriefingDialog
extends Control

const U = preload("res://scripts/ui/ui_style.gd")
const PORTRAIT := 150.0
## O losango da contagem das falas (o do mapa).
## Logo que a caixa abre, o toque que pulou a cena de antes (a chegada, um clique duplo em Partir) não passa a fala.
const GUARD_MS := 300

## skipped: o jogador pulou (Voltar ou Pular) em vez de passar até a última.
signal finished(skipped: bool)

## Voltar desiste (cancelled) em vez de pular: no briefing, Voltar fica na Preparação, como no resto do jogo.
var cancel_on_back := false
var cancelled := false

var lines: Array = []
var index := 0
var last_text := ""
var next_button: Button
var skip_button: Button
var _box: PanelContainer
var _face: Control
var _name: Label
var _role: Label
var _text: Label
var _page: Label
var _dots: HBoxContainer
var _keys: PanelContainer
var _keys_state := ""
var _done := false
var _opened_ms := 0


## Abre a caixa sobre parent com as falas ([{speaker, text}] de AHBriefing). last_text: o botão da última fala.
static func open(parent: Node, briefing_lines: Array, last: String) -> AHBriefingDialog:
	var dialog := AHBriefingDialog.new()
	dialog.lines = briefing_lines
	dialog.last_text = last
	parent.add_child(dialog)
	return dialog


func _init() -> void:
	name = "Briefing"
	# Sem âncora: a posição e o tamanho vêm da tela (_ready, _process), qualquer que seja o pai.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_opened_ms = Time.get_ticks_msec()
	global_position = Vector2.ZERO
	size = get_viewport_rect().size
	# A tela de baixo escurecida (a Preparação, a plataforma).
	var dim := ColorRect.new()
	dim.color = AHKit.VEIL
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	# A caixa: a chapa grande, o retrato no quadro do kit, o nome em caixa alta com o papel em âmbar, a fala, a contagem
	# em losangos e, à direita, PULAR (de aço, sem tecla) e PRÓXIMO (âmbar, com a tecla).
	_box = AHKit.panel_box("large")
	_box.custom_minimum_size = Vector2(1240, 0)
	_box.gui_input.connect(_on_box_input)
	add_child(_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_box.add_child(row)
	_face = Control.new()
	_face.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	_face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_face)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(heading)
	_name = AHKit.label("", "panel_title", AHKit.TEXT, true, true)
	heading.add_child(_name)
	_role = AHKit.label("", "text", AHKit.AMBER, true)
	_role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(_role)
	_text = AHKit.label("", "primary", AHKit.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(980, 72)
	column.add_child(_text)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 6)
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.add_child(_dots)
	_page = AHKit.label("", "small", AHKit.TEXT)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons.add_child(_page)
	skip_button = AHKit.button(tr("Pular"), "secondary")
	skip_button.custom_minimum_size = Vector2(130, 56)
	skip_button.add_theme_font_size_override("font_size", AHKit.size("row"))
	skip_button.pressed.connect(skip)
	buttons.add_child(skip_button)
	next_button = AHStationReport._primary("", "", "interact")
	next_button.icon = null
	next_button.custom_minimum_size = Vector2(240, 56)
	next_button.add_theme_font_size_override("font_size", AHKit.size("row"))
	next_button.pressed.connect(advance)
	next_button.resized.connect(_fit_next)
	buttons.add_child(next_button)
	skip_button.focus_neighbor_right = next_button.get_path()
	next_button.focus_neighbor_left = skip_button.get_path()
	# Embaixo da caixa, a barra das teclas: o que o Interagir e o Esc fazem aqui.
	_keys = AHKit.panel(AHKit.piece_of("key", "bar"))
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_keys)
	_show()
	next_button.grab_focus.call_deferred()
	# Na carência, os botões também esperam (um duplo clique em Partir caía no Próximo por cima).
	_set_guard(true)
	get_tree().create_timer(GUARD_MS / 1000.0).timeout.connect(_set_guard.bind(false))


func _process(_delta: float) -> void:
	var view := get_viewport_rect().size
	# A tela inteira, qualquer que seja o pai (o HUD da Estação é um Control sem tamanho): o véu escurece e segura o
	# clique fora da caixa.
	global_position = Vector2.ZERO
	size = view
	_box.reset_size()
	_box.position = Vector2((view.x - _box.size.x) * 0.5, view.y - _box.size.y - 230)
	# O que o Esc faz muda com quem abriu (cancel_on_back vem depois do open): a barra acompanha.
	var keys_state := "%d/%s/%s" % [index, cancel_on_back, next_button.text]
	if keys_state != _keys_state:
		_keys_state = keys_state
		_build_keys()
	_keys.reset_size()
	_keys.size = _keys.get_combined_minimum_size()
	_keys.position = Vector2((view.x - _keys.size.x) * 0.5, _box.position.y + _box.size.y + 16)
	if not _done:
		U.keep_focus(_box)


## A tecla do PRÓXIMO logo depois do texto, e o texto terminando antes dela.
func _fit_next() -> void:
	var key: Control = next_button.get_node("Key")
	key.reset_size()
	var room := key.get_combined_minimum_size().x + 70.0
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		if next_button.has_theme_stylebox_override(state):
			next_button.get_theme_stylebox(state).content_margin_right = room
	key.position = Vector2(next_button.size.x - key.size.x - 52.0, (next_button.size.y - key.size.y) * 0.5)


func _build_keys() -> void:
	for child in _keys.get_children():
		child.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys.add_child(row)
	var last := index + 1 >= lines.size()
	var back := tr("Voltar à Preparação") if cancel_on_back else tr("Pular")
	# O Esc (ui_cancel) volta, fixo como no resto do jogo.
	for pair in [["interact", last_text if last else tr("Próximo")], ["Esc", back]]:
		row.add_child(AHKitKey.make(pair[0]) if InputMap.has_action(pair[0]) else AHKitKey.make("", pair[0]))
		row.add_child(AHKit.label(pair[1], "text", AHKit.TEXT))
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(6, 0)
		row.add_child(gap)


func _set_guard(on: bool) -> void:
	if is_instance_valid(next_button):
		next_button.disabled = on
		skip_button.disabled = on


func guarded() -> bool:
	return Time.get_ticks_msec() - _opened_ms < GUARD_MS


## A próxima fala; depois da última, fecha.
func advance() -> void:
	if _done:
		return
	if index + 1 >= lines.size():
		_close(false)
		return
	index += 1
	Sound.play("res://audio/ui/click.ogg", 0.5)
	_show()


func skip() -> void:
	_close(true)


func _show() -> void:
	if lines.is_empty():
		_close.call_deferred(false)
		return
	var line: Dictionary = lines[index]
	var who: Dictionary = line.speaker
	for child in _face.get_children():
		child.queue_free()
	if not who.get("art", {}).is_empty():
		_face.add_child(AHKit.portrait(U.face_texture(who.art), PORTRAIT))
	_name.text = String(who.get("name", ""))
	_role.text = tr(String(who.get("role", "")))
	_role.visible = _role.text != ""
	_text.text = tr(String(line.text))
	# A contagem: um losango por fala (a de agora em âmbar) e "1/3".
	for child in _dots.get_children():
		child.queue_free()
	for i in lines.size():
		var dot := TextureRect.new()
		dot.texture = AHKit.legacy_icon("marker-available")
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dot.custom_minimum_size = Vector2.ONE * float(AHKit.size("small"))
		dot.modulate = AHKit.AMBER if i <= index else AHKit.MUTED
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dots.add_child(dot)
	_page.text = "%d/%d" % [index + 1, lines.size()]
	var last := index + 1 >= lines.size()
	next_button.text = (last_text if last else tr("Próximo")).to_upper()
	next_button.icon = AHKit.icon("station") if last else null
	skip_button.visible = not last
	_fit_next.call_deferred()


func _close(skipped: bool) -> void:
	if _done:
		return
	_done = true
	finished.emit(skipped)
	queue_free()


## Clicar ou tocar na caixa (fora dos botões) passa a fala. O clique que a Godot cria do toque (emulate_mouse_from_touch)
## não conta: o toque já passou.
func _on_box_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		accept_event()
		if not guarded():
			advance()


func _input(event: InputEvent) -> void:
	if _done or not is_visible_in_tree():
		return
	if guarded() and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction):
		get_viewport().set_input_as_handled()
		return
	if U.press_focused(_box, event):
		get_viewport().set_input_as_handled()
	elif U.is_back(event):
		get_viewport().set_input_as_handled()
		cancelled = cancel_on_back
		skip()
