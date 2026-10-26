## O cartão da passagem (#74): o título do lugar ou da fase com um subtítulo curto, por cima do preto ou de uma cena de
## fundo, enquanto a cena seguinte carrega. Embaixo, "Carregando…" até ela estar pronta; depois, a dica de pular
## (Interagir, Esc, o botão do controle ou um toque). O GameFlow abre e fecha o cartão; pular só vale com a cena pronta.
## A arte (moldura e tipografia) vem da issue do Codex (#79); até lá, o estilo do AHUiStyle.
class_name AHPassageCard
extends Control

const S = preload("res://scripts/ui/ui_style.gd")
## Quanto o título sobe ao aparecer (sem movimento com "Reduzir efeitos").
const RISE := 18.0
## O losango da divisa (o do mapa).
const DIAMOND := preload("res://art/ui/icons/marker-available.svg")

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
## O título já está aceso na tela (o GameFlow não fecha o cartão antes disso, nem numa máquina lenta).
var title_lit := false
## Pular apertado durante o passeio (antes de a cena seguinte montar, que espera o título): o passeio acaba, o título
## acende na hora, a cena monta e o cartão fecha assim que ela estiver pronta (#75).
var skip_requested := false

var _text: VBoxContainer
var _hint: HBoxContainer
## A caixa da dica: escura por cima da cena de fundo (o chão claro do vagão), invisível sobre o preto.
var _hint_box: PanelContainer
## A entrada da dica mostrada (teclas ou toque): troca junto quando o jogador troca de entrada com o cartão aberto.
var _hint_keys := true
var _band: Control
## Quando o cartão abriu (pelo relógio, como o tempo mínimo do GameFlow) e se o título já começou a acender.
var _opened_ms := 0
var _revealing := false
var _reveal_tween: Tween
## O que a dica mostra agora: a de pular (true) ou "Carregando…".
var _hint_skip := false


func _init(card: Dictionary = {}, reduce_motion: bool = false) -> void:
	title = String(card.get("title", ""))
	subtitle = String(card.get("subtitle", ""))
	backdrop = card.get("backdrop")
	reduced = reduce_motion
	title_delay = float(card.get("title_delay", 0.0))
	# Já na criação: a dica do primeiro quadro conta a carência a partir daqui.
	_opened_ms = Time.get_ticks_msec()
	name = "Passage"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# O cartão fica com o mouse e o toque (nada por trás recebe o clique).
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var ink := ColorRect.new()
	ink.color = AHKit.STEEL
	ink.set_anchors_preset(Control.PRESET_FULL_RECT)
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ink)
	if backdrop != null and not reduced:
		_add_backdrop()
	elif backdrop != null:
		backdrop.free()
		backdrop = null
		title_delay = 0.0
	# A chapa do kit atrás do texto: o título lê em cima de qualquer fundo.
	var band := AHKit.panel_box("large")
	band.custom_minimum_size = Vector2(810, 0)
	band.set_anchors_preset(Control.PRESET_CENTER)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	_text = VBoxContainer.new()
	_text.alignment = BoxContainer.ALIGNMENT_CENTER
	_text.add_theme_constant_override("separation", 14)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(_text)
	var heading := AHKit.label(title, "panel_hero", AHKit.TEXT, true, true)
	heading.name = "Title"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.add_child(heading)
	# A divisa com o losango âmbar no meio.
	var divider := HBoxContainer.new()
	divider.alignment = BoxContainer.ALIGNMENT_CENTER
	divider.add_theme_constant_override("separation", 10)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_child(divider)
	for side in 3:
		if side == 1:
			var diamond := TextureRect.new()
			diamond.texture = DIAMOND
			diamond.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			diamond.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			diamond.custom_minimum_size = Vector2(14, 14)
			diamond.modulate = AHKit.AMBER
			diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
			divider.add_child(diamond)
			continue
		var line := ColorRect.new()
		line.color = AHKit.MUTED
		line.custom_minimum_size = Vector2(300, 1)
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		divider.add_child(line)
	if subtitle != "":
		var sub := AHKit.label(subtitle, "row", AHKit.TEXT)
		sub.name = "Subtitle"
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(900, 0)
		_text.add_child(sub)
	_hint_box = AHKit.panel(AHKit.piece_of("key", "bar"))
	_hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_box)
	_hint = HBoxContainer.new()
	_hint.name = "Hint"
	_hint.add_theme_constant_override("separation", 10)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_box.add_child(_hint)
	_show_hint()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_band = band
	if reduced:
		title_lit = true
	else:
		band.modulate.a = 0.0


## O título acende (e sobe um pouco) depois de title_delay, contado pelo relógio: numa máquina lenta os quadros chegam
## com o tempo cortado, e um atraso em tempo de jogo podia passar do tempo do cartão.
func _reveal() -> void:
	_revealing = true
	var tween := create_tween().set_parallel()
	_reveal_tween = tween
	tween.tween_property(_band, "modulate:a", 1.0, 0.45)
	tween.tween_property(_band, "position:y", _band.position.y, 0.6).from(_band.position.y + RISE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): title_lit = true)


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
	if skip_requested:
		skipped = true
	_show_hint()


## O passeio pulado: o título aceso de uma vez, no lugar.
func _light_title_now() -> void:
	if _reveal_tween != null:
		_reveal_tween.kill()
	_revealing = true
	title_lit = true
	if _band != null:
		_band.modulate.a = 1.0
		_layout()


func _show_hint() -> void:
	if _hint == null:
		return
	for child in _hint.get_children():
		_hint.remove_child(child)
		child.queue_free()
	_hint_keys = S.using_keys or not Settings.touch_visible()
	_hint_skip = _can_skip_now()
	if not _hint_skip:
		_hint.add_child(AHKit.label(tr("Carregando…"), "text", AHKit.MUTED))
	elif not _hint_keys:
		_hint.add_child(AHKit.label(tr("Toque para pular"), "text", AHKit.TEXT))
	else:
		_hint.add_child(AHKitKey.make("interact"))
		_hint.add_child(AHKit.label(tr("Pular"), "text", AHKit.TEXT))
	_layout.call_deferred()


## A dica de pular só aparece quando pular vale: passada a carência, com a cena pronta ou no passeio (a cena de fundo
## com o título atrasado, em que pular vale desde o começo).
func _can_skip_now() -> bool:
	if Time.get_ticks_msec() - _opened_ms < SKIP_GRACE_MS:
		return false
	return ready_to_skip or (title_delay > 0.0 and not skip_requested)


func _process(_delta: float) -> void:
	if _hint != null and _hint_skip != _can_skip_now():
		_show_hint()
	if not title_lit and not _revealing and Time.get_ticks_msec() - _opened_ms >= title_delay * 1000.0:
		_reveal()
	if _hint_skip and _hint_keys != (S.using_keys or not Settings.touch_visible()):
		_show_hint()


func _layout() -> void:
	if _text == null:
		return
	var view := get_viewport_rect().size
	var band: Control = _text.get_parent()
	band.reset_size()
	var band_size := band.get_combined_minimum_size()
	band.position = (view - band_size) * 0.5
	# Com a cena de fundo (o vagão), o título vai para o chão, à frente das pernas da equipe, em vez de cobrir os rostos.
	if backdrop != null:
		band.position.y = minf(view.y * 0.77 - band_size.y * 0.5, view.y - band_size.y - 16.0)
	_hint_box.reset_size()
	_hint_box.position = view - _hint_box.get_combined_minimum_size() - Vector2(36, 28)


func _input(event: InputEvent) -> void:
	# Enquanto o cartão está aberto, nenhuma tecla passa para trás dele.
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton
			or event is InputEventScreenTouch or event is InputEventAction):
		return
	get_viewport().set_input_as_handled()
	if not is_skip(event) or Time.get_ticks_msec() - _opened_ms < SKIP_GRACE_MS:
		return
	if ready_to_skip:
		skipped = true
	elif title_delay > 0.0 and not skip_requested:
		# No passeio a cena seguinte já carregou e só espera o título: o pedido vale e encerra o passeio.
		skip_requested = true
		_light_title_now()


## Logo que o cartão abre, pular ainda não vale: o mesmo Interagir que confirmou a partida, apertado duas vezes, pulava
## o vagão antes de ele aparecer.
const SKIP_GRACE_MS := 300


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
