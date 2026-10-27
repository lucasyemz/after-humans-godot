## A dica do tutorial (#144, a tela da #146 em docs/design/tutorial.md): a chapa do kit com "Tutorial" e o passo
## ("1 de 9"), o que fazer, a explicação de uma linha e as teclas; em volta do que se deve usar, a moldura de foco do kit
## e a seta âmbar apontando para ela. Nos passos que travam (a primeira habilidade e o primeiro alvo), o resto da tela
## escurece pela metade. Sem "Entendi": a dica some quando o jogador faz o que ela pede (quem a abre chama hide_hint).
class_name AHTutorialHint
extends Control

const WIDTH := 600.0
## Os lugares da chapa: no alto, no meio (a exploração, abaixo da rota) ou à esquerda (a luta, acima das cabeças).
const PLACES := {"top": Vector2(660, 116), "left": Vector2(40, 116)}
const ARROW := 40.0
## A folga da moldura em volta do alvo.
const FRAME_PAD := 10.0

## O passo aberto ("" sem dica) e o alvo do destaque (vazio: sem moldura).
var step_id := ""
var focus_rect := Rect2()
var _plate: PanelContainer
var _count: Label
var _title: Label
var _text: Label
var _keys: HBoxContainer
var _frame: Panel
var _arrow: TextureRect
var _shades: Array[ColorRect] = []
var _dim := false
var _place := "top"


func _init() -> void:
	name = "TutorialHint"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	# O escuro em volta do destaque: quatro faixas (a de cima, a de baixo e as dos lados), o buraco é o alvo.
	for i in 4:
		var shade := ColorRect.new()
		shade.color = Color(AHKit.SHADE, 0.5)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.visible = false
		add_child(shade)
		_shades.append(shade)
	_frame = Panel.new()
	_frame.add_theme_stylebox_override("panel", AHKit.style(AHKit.piece_of("focus", "focus")))
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.visible = false
	add_child(_frame)
	_arrow = TextureRect.new()
	_arrow.texture = load("res://art/ui/icons/ui-arrow-right.svg")
	_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_arrow.size = Vector2(ARROW, ARROW)
	_arrow.modulate = AHKit.AMBER
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.pivot_offset = Vector2(ARROW, ARROW) * 0.5
	_arrow.visible = false
	add_child(_arrow)
	_plate = AHKit.panel_box("large")
	_plate.custom_minimum_size = Vector2(WIDTH, 0)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.visible = false
	add_child(_plate)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_plate.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	head.add_child(AHKit.label(tr("Tutorial"), "small", AHKit.AMBER, true, true))
	_count = AHKit.label("", "small", AHKit.MUTED)
	head.add_child(_count)
	_title = AHKit.label("", "card_name", AHKit.TEXT, true)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(WIDTH - 40.0, 0)
	box.add_child(_title)
	_text = AHKit.label("", "text", AHKit.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH - 40.0, 0)
	box.add_child(_text)
	_keys = HBoxContainer.new()
	_keys.add_theme_constant_override("separation", 8)
	box.add_child(_keys)


## Abre o passo (number de total): {Id, Title, Text, Keys, Blocking}. place: "top" ou "left".
func show_step(step: Dictionary, number: int, total: int, place: String = "top") -> void:
	step_id = String(step.get("Id", ""))
	_place = place
	_count.text = tr("%d de %d") % [number, total]
	_title.text = tr(String(step.get("Title", "")))
	_text.text = tr(String(step.get("Text", "")))
	for child in _keys.get_children():
		child.queue_free()
	for action in step.get("Keys", []):
		_keys.add_child(AHKitKey.make(String(action)))
	_dim = bool(step.get("Blocking", false))
	_plate.visible = true
	_plate.reset_size()
	_plate.position = PLACES.get(place, PLACES.top)
	_plate.modulate.a = 0.0
	create_tween().tween_property(_plate, "modulate:a", 1.0, 0.25)
	_layout()


## Só o destaque, sem a chapa (a visita da Estação, #145, tem a fala dela): a moldura em rect e, com dim, o resto
## escurecido. block: o escuro segura o mouse (só o destaque recebe o clique).
func show_frame(rect: Rect2, dim: bool, block: bool) -> void:
	step_id = "frame"
	_plate.visible = false
	_dim = dim
	for shade in _shades:
		shade.mouse_filter = Control.MOUSE_FILTER_STOP if block else Control.MOUSE_FILTER_IGNORE
	focus_rect = rect
	_layout()


func hide_hint() -> void:
	step_id = ""
	focus_rect = Rect2()
	_plate.visible = false
	_frame.visible = false
	_arrow.visible = false
	for shade in _shades:
		shade.visible = false


func showing() -> bool:
	return step_id != ""


## O alvo do destaque (na tela de 1920 x 1080); vazio tira a moldura.
func set_focus(rect: Rect2) -> void:
	if rect == focus_rect:
		return
	focus_rect = rect
	_layout()


func _layout() -> void:
	var has_focus := showing() and focus_rect.has_area()
	var hole := focus_rect.grow(FRAME_PAD)
	_frame.visible = has_focus
	_arrow.visible = has_focus
	var view := Vector2(1920, 1080)
	var bands := [Rect2(0, 0, view.x, hole.position.y), Rect2(0, hole.end.y, view.x, view.y - hole.end.y),
		Rect2(0, hole.position.y, hole.position.x, hole.size.y), Rect2(hole.end.x, hole.position.y, view.x - hole.end.x, hole.size.y)]
	for i in 4:
		_shades[i].visible = has_focus and _dim
		_shades[i].position = bands[i].position
		_shades[i].size = bands[i].size.max(Vector2.ZERO)
	if not has_focus:
		return
	_frame.position = hole.position
	_frame.size = hole.size
	# A seta fica do lado da moldura que olha para a chapa (acima dela, ou à esquerda) e aponta para o alvo.
	var plate := Rect2(_plate.position, _plate.size) if _plate.visible else Rect2(Vector2(960, 0), Vector2.ZERO)
	if hole.position.y > plate.end.y + ARROW:
		_arrow.rotation_degrees = 90.0
		_arrow.position = Vector2(hole.get_center().x - ARROW * 0.5, hole.position.y - ARROW - 6.0)
	elif hole.end.y < plate.position.y - ARROW:
		_arrow.rotation_degrees = -90.0
		_arrow.position = Vector2(hole.get_center().x - ARROW * 0.5, hole.end.y + 6.0)
	else:
		_arrow.rotation_degrees = 0.0
		_arrow.position = Vector2(hole.position.x - ARROW - 6.0, hole.get_center().y - ARROW * 0.5)
	# A chapa nunca cobre o alvo: se cobriria, desce para baixo dele (ou sobe acima).
	if _plate.visible and plate.intersects(hole):
		_plate.position.y = hole.end.y + 24.0 if hole.end.y + 24.0 + plate.size.y < view.y - 200.0 else maxf(20.0, hole.position.y - plate.size.y - 24.0)
