## A caixa do briefing e do debriefing (#88): o retrato de quem fala, o nome, a fala e os botões Pular e Próximo (na
## última, o texto de quem chama: "Partir", "Ver o relatório"). Mouse e toque nos botões ou na caixa; Interagir (E, o A
## do controle, Enter) passa a fala; Voltar (Esc, B) pula. Com os tokens do AHUiStyle, para trocar pelo kit da #59/#60.
class_name AHBriefingDialog
extends Control

const U = preload("res://scripts/ui/ui_style.gd")
const H = preload("res://scripts/ui/combat_hud.gd")
const PORTRAIT := 132.0
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
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_opened_ms = Time.get_ticks_msec()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", U.panel(0.94, U.GOLD, 2))
	_box.custom_minimum_size = Vector2(1080, 0)
	_box.gui_input.connect(_on_box_input)
	add_child(_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_box.add_child(row)
	_face = Control.new()
	_face.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_face)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	column.add_child(heading)
	_name = U.label("", 28, U.GOLD, "display")
	heading.add_child(_name)
	_role = U.label("", 17, U.MUTED)
	_role.size_flags_vertical = Control.SIZE_SHRINK_END
	heading.add_child(_role)
	_text = U.label("", 22, U.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(820, 84)
	column.add_child(_text)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	_page = U.label("", 16, U.MUTED)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_page)
	skip_button = Button.new()
	skip_button.text = tr("Pular")
	skip_button.custom_minimum_size = Vector2(150, 46)
	H.style_button(skip_button, U.MUTED)
	skip_button.pressed.connect(skip)
	buttons.add_child(skip_button)
	next_button = Button.new()
	next_button.custom_minimum_size = Vector2(220, 46)
	H.style_button(next_button, U.GOLD, true)
	next_button.pressed.connect(advance)
	buttons.add_child(next_button)
	skip_button.focus_neighbor_right = next_button.get_path()
	next_button.focus_neighbor_left = skip_button.get_path()
	_show()
	next_button.grab_focus.call_deferred()
	# Na carência, os botões também esperam (um duplo clique em Partir caía no Próximo por cima).
	_set_guard(true)
	get_tree().create_timer(GUARD_MS / 1000.0).timeout.connect(_set_guard.bind(false))


func _process(_delta: float) -> void:
	var view := get_viewport_rect().size
	_box.reset_size()
	_box.position = Vector2((view.x - _box.size.x) * 0.5, view.y - _box.size.y - 48)
	if not _done:
		U.keep_focus(_box)


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
		_face.add_child(U.portrait(who.art, PORTRAIT, U.GOLD, 0.05))
	_name.text = String(who.get("name", ""))
	_role.text = tr(String(who.get("role", "")))
	_role.visible = _role.text != ""
	_text.text = tr(String(line.text))
	_page.text = "%d/%d" % [index + 1, lines.size()]
	next_button.text = last_text if index + 1 >= lines.size() else tr("Próximo")
	skip_button.visible = index + 1 < lines.size()


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
