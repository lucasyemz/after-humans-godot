## O cartão da passagem (#74): o título do lugar ou da fase com um subtítulo curto, por cima do preto ou de uma cena de
## fundo, enquanto a cena seguinte carrega. Embaixo, "Carregando…" até ela estar pronta; depois, a dica de pular
## (Interagir, Esc, o botão do controle ou um toque). O GameFlow abre e fecha o cartão; pular só vale com a cena pronta.
## A arte (moldura e tipografia) vem da issue do Codex (#79); até lá, o estilo do AHUiStyle.
class_name AHPassageCard
extends Control

const S = preload("res://scripts/ui/ui_style.gd")
## Quanto o título sobe ao aparecer (sem movimento com "Reduzir efeitos").
const RISE := 18.0

var title := ""
var subtitle := ""
## Uma cena de fundo no lugar do preto: um Node3D com a própria câmera (desenhado num SubViewport com mundo próprio) ou
## um Control. Com "Reduzir efeitos" fica de fora: só o título.
var backdrop: Node
var reduced := false
## Com a cena de fundo: quanto tempo ela fica sozinha antes de o título aparecer (a partida no vagão, #75).
var title_delay := 0.0
## A cena seguinte terminou de carregar: daqui em diante dá para pular.
var ready_to_skip := false
## O jogador pediu para pular (só depois de ready_to_skip).
var skipped := false

var _text: VBoxContainer
var _hint: HBoxContainer
## A entrada da dica mostrada (teclas ou toque): troca junto quando o jogador troca de entrada com o cartão aberto.
var _hint_keys := true


func _init(card: Dictionary = {}, reduce_motion: bool = false) -> void:
	title = String(card.get("title", ""))
	subtitle = String(card.get("subtitle", ""))
	backdrop = card.get("backdrop")
	reduced = reduce_motion
	title_delay = float(card.get("title_delay", 0.0))
	name = "Passage"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# O cartão fica com o mouse e o toque (nada por trás recebe o clique).
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var ink := ColorRect.new()
	ink.color = S.INK
	ink.set_anchors_preset(Control.PRESET_FULL_RECT)
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ink)
	if backdrop != null and not reduced:
		_add_backdrop()
	elif backdrop != null:
		backdrop.free()
		backdrop = null
		title_delay = 0.0
	# Uma faixa escura atrás do texto: o título lê em cima de qualquer fundo.
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", S.flat(0.72 if backdrop != null else 0.0, Color(S.COPPER, 0.0), 0))
	band.set_anchors_preset(Control.PRESET_CENTER)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	_text = VBoxContainer.new()
	_text.alignment = BoxContainer.ALIGNMENT_CENTER
	_text.add_theme_constant_override("separation", 14)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(_text)
	var heading := S.label(title, 60, S.GOLD, "display")
	heading.name = "Title"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.add_child(heading)
	var line := ColorRect.new()
	line.color = Color(S.COPPER, 0.8)
	line.custom_minimum_size = Vector2(260, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_child(line)
	if subtitle != "":
		var sub := S.label(subtitle, 26, S.TEXT)
		sub.name = "Subtitle"
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(900, 0)
		_text.add_child(sub)
	_hint = HBoxContainer.new()
	_hint.name = "Hint"
	_hint.add_theme_constant_override("separation", 10)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_show_hint()
	get_viewport().size_changed.connect(_layout)
	_layout()
	if not reduced:
		band.modulate.a = 0.0
		var tween := create_tween().set_parallel()
		tween.tween_property(band, "modulate:a", 1.0, 0.45).set_delay(title_delay)
		tween.tween_property(band, "position:y", band.position.y, 0.6).from(band.position.y + RISE).set_delay(title_delay) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _add_backdrop() -> void:
	if backdrop is Control:
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(backdrop)
		return
	var holder := SubViewportContainer.new()
	holder.name = "Backdrop"
	holder.stretch = true
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var view := SubViewport.new()
	view.own_world_3d = true
	view.handle_input_locally = false
	holder.add_child(view)
	view.add_child(backdrop)


## A cena seguinte está pronta: a dica troca de "Carregando…" para a de pular.
func mark_ready() -> void:
	if ready_to_skip:
		return
	ready_to_skip = true
	_show_hint()


func _show_hint() -> void:
	if _hint == null:
		return
	for child in _hint.get_children():
		_hint.remove_child(child)
		child.queue_free()
	_hint_keys = S.using_keys or not Settings.touch_visible()
	if not ready_to_skip:
		_hint.add_child(S.label(tr("Carregando…"), 20, S.MUTED))
	elif not _hint_keys:
		_hint.add_child(S.label(tr("Toque para pular"), 20, S.MUTED))
	else:
		_hint.add_child(S.action_cap("interact"))
		_hint.add_child(S.label(tr("pular"), 20, S.MUTED))
	_layout.call_deferred()


func _process(_delta: float) -> void:
	if ready_to_skip and _hint_keys != (S.using_keys or not Settings.touch_visible()):
		_show_hint()


func _layout() -> void:
	if _text == null:
		return
	var view := get_viewport_rect().size
	var band: Control = _text.get_parent()
	band.reset_size()
	band.position = (view - band.get_combined_minimum_size()) * 0.5
	_hint.reset_size()
	_hint.position = view - _hint.get_combined_minimum_size() - Vector2(48, 40)


func _input(event: InputEvent) -> void:
	# Enquanto o cartão está aberto, nenhuma tecla passa para trás dele.
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton
			or event is InputEventScreenTouch or event is InputEventAction):
		return
	get_viewport().set_input_as_handled()
	if ready_to_skip and is_skip(event):
		skipped = true


## Interagir (A no controle), Esc ou Start (menu), Voltar (Backspace ou B), um clique ou um toque.
static func is_skip(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return event.pressed
	if event.is_echo():
		return false
	return event.is_action_pressed("interact") or event.is_action_pressed("menu") or event.is_action_pressed("cancel") \
		or event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")
