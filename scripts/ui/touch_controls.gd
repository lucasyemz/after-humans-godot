## Controles de toque da exploração (celular e tablet): um analógico que aparece onde o dedo encosta na metade esquerda
## (empurrar até a borda corre) e o botão Usar à direita, aceso quando há algo para usar. A luta, a Estação e os menus
## já aceitam o toque como clique. Aparecem com tela de toque ou com Opções > Controles de toque: Sempre.
##
## O analógico aperta as mesmas ações das teclas (move_*, run) com a força do dedo; o Usar manda a ação interact.
## O mouse de verdade também mexe neles (para testar no computador); o mouse que a Godot imita a partir do toque não.
class_name AHTouchControls
extends Control

## Onde o analógico pode começar: a metade esquerda, entre o HUD do alto e a equipe embaixo.
const STICK_ZONE := Rect2(0, 300, 900, 680)
const STICK_HOME := Vector2(230, 800)
const STICK_RADIUS := 110.0
## Além desta fração do raio a equipe corre.
const RUN_AT := 0.85
const USE_CENTER := Vector2(1790, 800)
const USE_RADIUS := 78.0

var street: Node
var _stick_finger := -2
var _stick_origin := STICK_HOME
var _stick_vector := Vector2.ZERO
var _use_finger := -2
var _use_icon: TextureRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# O ícone do Usar (a bússola do kit), por cima do octógono.
	_use_icon = AHKit.glyph("next_step", 40)
	_use_icon.position = USE_CENTER + Vector2(-20, -50)
	_use_icon.size = Vector2(40, 40)
	add_child(_use_icon)


func _process(_delta: float) -> void:
	var show: bool = Settings.touch_visible() and street != null and not street._arena.active \
		and not (street.corridor != null and street.corridor.blocking())
	if show != visible:
		visible = show
		if not show:
			_release_all()
	if visible:
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var finger := -2
	var at := Vector2.ZERO
	var pressed := false
	var moved := false
	if event is InputEventScreenTouch:
		finger = event.index
		at = _to_hud(event.position)
		pressed = event.pressed
	elif event is InputEventScreenDrag:
		finger = event.index
		at = _to_hud(event.position)
		moved = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		finger = -1
		at = _to_hud(event.position)
		pressed = event.pressed
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and _stick_finger == -1:
		finger = -1
		at = _to_hud(event.position)
		moved = true
	else:
		return

	if moved:
		if finger == _stick_finger:
			_move_stick(at)
			get_viewport().set_input_as_handled()
		return
	if pressed:
		if _use_finger == -2 and at.distance_to(USE_CENTER) <= USE_RADIUS * 1.15:
			_use_finger = finger
			_send_interact(true)
			get_viewport().set_input_as_handled()
		elif _stick_finger == -2 and STICK_ZONE.has_point(at) and not _on_prompt(at):
			_stick_finger = finger
			_stick_origin = at
			_move_stick(at)
			get_viewport().set_input_as_handled()
	else:
		if finger == _stick_finger:
			_stick_finger = -2
			_stick_origin = STICK_HOME
			_move_stick(STICK_HOME)
			get_viewport().set_input_as_handled()
		elif finger == _use_finger:
			_use_finger = -2
			_send_interact(false)
			get_viewport().set_input_as_handled()


## A tela de verdade pode ter outro tamanho; o HUD é desenhado na base de 1920x1080.
func _to_hud(position: Vector2) -> Vector2:
	var view := get_viewport_rect().size
	return position * Vector2(1920.0 / view.x, 1080.0 / view.y)


## O aviso de interação também é botão: o toque nele fica com ele.
func _on_prompt(at: Vector2) -> bool:
	return street.exploration_hud != null and street.exploration_hud.prompt_rect().has_point(at)


func _move_stick(at: Vector2) -> void:
	var offset := (at - _stick_origin).limit_length(STICK_RADIUS)
	_stick_vector = offset / STICK_RADIUS
	_set_axis("move_left", "move_right", _stick_vector.x)
	# Na tela, para cima é para o fundo.
	_set_axis("move_back", "move_front", _stick_vector.y)
	if _stick_vector.length() >= RUN_AT:
		Input.action_press("run")
	else:
		Input.action_release("run")


func _set_axis(negative: String, positive: String, value: float) -> void:
	var dead := 0.18
	if value < -dead:
		_press(negative, -value)
		Input.action_release(positive)
	elif value > dead:
		_press(positive, value)
		Input.action_release(negative)
	else:
		Input.action_release(negative)
		Input.action_release(positive)


## A força passa por cima da zona morta da ação: o quanto o dedo empurra é o quanto a equipe anda.
func _press(action: String, strength: float) -> void:
	var dead := InputMap.action_get_deadzone(action)
	Input.action_press(action, dead + (1.0 - dead) * minf(1.0, strength))


func _send_interact(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = pressed
	Input.parse_input_event(event)


func _release_all() -> void:
	_stick_finger = -2
	_stick_origin = STICK_HOME
	_stick_vector = Vector2.ZERO
	for action in ["move_left", "move_right", "move_back", "move_front", "run"]:
		Input.action_release(action)
	if _use_finger != -2:
		_use_finger = -2
		_send_interact(false)


## As peças do kit (art/ui/kit/station, hud-exploracao.md): o analógico é o octógono de aço meio transparente com o
## pegador da cruz âmbar; o Usar, o octógono apagado e, quando há o que usar, o âmbar por cima. As áreas de toque não
## mudam com a arte.
const RING := 120.0
const KNOB := 42.0
const BUTTON := 85.0


func _piece(name: String, center: Vector2, radius: float, alpha: float = 1.0) -> void:
	var tint := Color.WHITE
	tint.a = alpha
	draw_texture_rect(AHKit.texture(name), Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, tint)


func _draw() -> void:
	var active := _stick_finger != -2
	_piece("touch_ring", _stick_origin, RING, 1.0 if active else 0.8)
	var knob := _stick_origin + _stick_vector * STICK_RADIUS
	var running := _stick_vector.length() >= RUN_AT
	_piece("touch_knob", knob, KNOB, 1.0 if active else 0.85)
	if active and running:
		_tag(tr("Correr"), _stick_origin + Vector2(0, RING + 24), AHKit.AMBER)
	elif not active:
		_tag(tr("Andar"), _stick_origin + Vector2(0, RING + 24), AHKit.TEXT)

	var can_use: bool = street.exploration_hud != null and street.exploration_hud.has_prompt()
	var held := _use_finger != -2
	_piece("touch_button", USE_CENTER, BUTTON, 1.0 if can_use or held else 0.8)
	if can_use or held:
		_piece("touch_button_active", USE_CENTER, BUTTON * (0.94 if held else 1.0))
	var tone: Color = AHKit.AMBER if can_use else AHKit.MUTED
	_use_icon.modulate = tone
	_text(tr("Usar").to_upper(), USE_CENTER + Vector2(0, 26), AHKit.size("card_name"), AHKit.TEXT if can_use else AHKit.MUTED)


## O nome embaixo do analógico, numa etiqueta pequena (a tecla do kit).
func _tag(text: String, center: Vector2, color: Color) -> void:
	var font := AHKit.font()
	var px := AHKit.size("small")
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var box := Rect2(center - Vector2(width * 0.5 + 10, px * 0.5 + 8), Vector2(width + 20, px + 16))
	draw_style_box(AHKit.style(AHKit.piece_of("key", "tab")), box)
	_text(text, center + Vector2(0, px * 0.35), px, color)


func _text(text: String, at_center: Vector2, px: int, color: Color) -> void:
	var font := AHKit.font(true)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var at := at_center - Vector2(width * 0.5, 0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 6, AHKit.INK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
