## A visita guiada da Estação (#145): a primeira vez na Estação, logo depois da abertura (#144). Cada passo de
## data/tutorial.json (station_tour) destaca uma parte da tela (a moldura de foco do kit, o resto escurecido) e traz a
## fala curta com o retrato de quem guia (o Bento ou o Nick; a Dora quando já mora na Estação). Os passos com Wait "next" seguem pelo PRÓXIMO; os
## outros esperam a ação pedida (abrir o cômodo, a Sala, fechar o painel), que Interagir também faz. PULAR VISITA
## encerra de vez. O passo fica em campaign.tutorial.tour (fechar o jogo no meio retoma dali) e, no fim ou pulando, a
## abertura termina (stage "done").
## Os alvos: "overview" (os cômodos), "resources" (a barra do alto), "next_step" (o Próximo passo), "room:<id>" (um
## cômodo; "room:next" é o do próximo passo), "panel" (o painel aberto), "characters" (a aba da Sala) e "prepare"
## (Preparar expedição). As esperas: "next", "room:<id>" (o cômodo aberto), "room:characters" (a Sala), "close" e "map"
## (Preparar expedição aberto).
class_name AHStationTour
extends Control

const PORTRAIT := 120.0
const WIDTH := 860.0

## O HUD da Estação (AHRefugeHud): de onde vêm os alvos e quem faz as ações.
var hud: Control
var steps: Array = []
var index := 0
var _hint: AHTutorialHint
var _box: PanelContainer
var _face: Control
var _name: Label
var _text: Label
var _dots: HBoxContainer
var _page: Label
var _next: Button
var _skip: Button
var _blocker: Control
var _done := false

signal finished


func _init(owner_hud: Control) -> void:
	hud = owner_hud
	name = "StationTour"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## A visita começa (ou continua) se a campanha está no ponto dela.
## Sem passos nos dados (station_tour.Steps vazio), a visita acaba ali: a campanha não fica presa em "station" (com as
## dicas da Estação caladas).
static func pending(campaign: Dictionary) -> bool:
	if AHTutorial.stage(campaign) != "station":
		return false
	if AHTutorial.tour_steps().is_empty():
		AHTutorial.end_tour(campaign)
		return false
	return true


func _ready() -> void:
	steps = AHTutorial.tour_steps()
	index = clampi(int(Campaign.state.get("tutorial", {}).get("tour", 0)), 0, steps.size() - 1)
	# Retomada num passo de fechar (o painel que estava aberto não volta aberto): o passo de antes, o de abrir.
	while index > 0 and waiting_for() == "close" and hud.current == "":
		index -= 1
	# Nos passos do PRÓXIMO a tela de baixo não recebe o clique (a visita não sai do lugar por um clique perdido).
	_blocker = Control.new()
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_blocker)
	_hint = AHTutorialHint.new()
	add_child(_hint)
	_box = AHKit.panel_box("large")
	_box.custom_minimum_size = Vector2(WIDTH, 0)
	add_child(_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_box.add_child(row)
	_face = Control.new()
	_face.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	_face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_face)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	column.add_child(head)
	head.add_child(AHKit.label(tr("Visita"), "small", AHKit.AMBER, true, true))
	_name = AHKit.label("", "card_name", AHKit.TEXT, true, true)
	head.add_child(_name)
	_text = AHKit.label("", "text", AHKit.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH - PORTRAIT - 80.0, 0)
	column.add_child(_text)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	column.add_child(foot)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 4)
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_dots)
	_page = AHKit.label("", "small", AHKit.MUTED)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_page)
	_skip = AHKit.button(tr("Pular visita"), "secondary")
	_skip.name = "SkipTour"
	_skip.custom_minimum_size = Vector2(0, 56)
	_skip.add_theme_font_size_override("font_size", AHKit.size("row"))
	_skip.pressed.connect(skip)
	foot.add_child(_skip)
	_next = AHKit.button(tr("Próximo"), "primary")
	_next.name = "NextTour"
	_next.custom_minimum_size = Vector2(0, 56)
	_next.add_theme_font_size_override("font_size", AHKit.size("row"))
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		_next.add_theme_color_override(state, AHKit.ON_AMBER)
	_next.pressed.connect(advance)
	foot.add_child(_next)
	_show()


func current() -> Dictionary:
	return steps[index] if index < steps.size() else {}


func _show() -> void:
	var step := current()
	var who := _speaker(String(step.get("Speaker", "")))
	for child in _face.get_children():
		child.queue_free()
	if not who.get("art", {}).is_empty():
		_face.add_child(AHKit.portrait(AHUiStyle.face_texture(who.art), PORTRAIT))
	_name.text = String(who.get("name", ""))
	_text.text = tr(String(step.get("Text", "")))
	for child in _dots.get_children():
		child.queue_free()
	for i in steps.size():
		var dot := TextureRect.new()
		dot.texture = AHKit.legacy_icon("marker-available")
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dot.custom_minimum_size = Vector2.ONE * float(AHKit.size("small"))
		dot.modulate = AHKit.AMBER if i <= index else AHKit.MUTED
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dots.add_child(dot)
	var waits := waiting_for()
	_page.text = "%d/%d" % [index + 1, steps.size()] + ("" if waits == "next" else "  ·  " + tr(String(step.get("Do", ""))))
	var last := index + 1 >= steps.size()
	_next.text = (tr("Começar") if last else tr("Próximo")).to_upper()
	_next.visible = waits == "next"
	if last and waits != "next":
		_page.text = "%d/%d  ·  %s" % [index + 1, steps.size(), tr(String(step.get("Do", "")))]
	_skip.visible = not last
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP if waits == "next" else Control.MOUSE_FILTER_IGNORE
	if AHUiStyle.using_keys and _next.visible:
		_next.grab_focus.call_deferred()
	_place()


## Quem fala: o morador ou o herói (AHBriefing.speaker); sem ele na Estação, o Bento.
func _speaker(id: String) -> Dictionary:
	var who := AHBriefing.speaker(Campaign.state, id)
	if who.is_empty():
		who = AHBriefing.speaker(Campaign.state, "hero_cao_bento")
	return who


## A espera do passo: "next" ou a ação ("room:forge", "room:characters", "close").
func waiting_for() -> String:
	var wait := String(current().get("Wait", "next"))
	return wait.replace("room:next", "room:" + next_room())


## O cômodo do Próximo passo (o primeiro a recuperar), ou a Forja.
func next_room() -> String:
	var room := String(AHStationRules.next_step(Campaign.state).get("room", ""))
	return room if room != "" else AHStationRules.FORGE


func _target() -> String:
	return String(current().get("Target", "")).replace("room:next", "room:" + next_room())


func _process(_delta: float) -> void:
	if _done:
		return
	# A seleção de cômodo da Estação (a moldura do teclado) não disputa com o destaque da visita.
	hud.clear_room_selection()
	var rect: Rect2 = hud.tour_rect(_target())
	# Logo depois da chegada a câmera ainda vem da plataforma: a fala já aparece (e diz por que a tela espera), e o
	# destaque entra quando a vista em corte chega.
	_hint.show_frame(rect, true, waiting_for() != "next")
	_place()


## A fala no primeiro lugar que não cobre o destaque (embaixo no meio, no alto, à esquerda, à direita); se todos cobrem
## (o painel alto), no que cobre menos.
func _place() -> void:
	_box.reset_size()
	var box := _box.get_combined_minimum_size()
	var rect := _hint.focus_rect.grow(24.0)
	# A tela de verdade (a visita ocupa a tela inteira), não 1920 × 1080 fixo: a fala cabe em qualquer tamanho.
	var screen: Vector2 = size if size.x > 0.0 and size.y > 0.0 else get_viewport_rect().size
	var spots := [Vector2((screen.x - box.x) * 0.5, screen.y - 150.0 - box.y), Vector2((screen.x - box.x) * 0.5, 130.0),
		Vector2(28.0, (screen.y - box.y) * 0.5), Vector2(screen.x - 28.0 - box.x, (screen.y - box.y) * 0.5),
		Vector2(28.0, screen.y - 150.0 - box.y)]
	var best: Vector2 = spots[0]
	var least := INF
	for spot: Vector2 in spots:
		var overlap := Rect2(spot, box).intersection(rect).get_area() if rect.has_area() else 0.0
		if overlap < least:
			least = overlap
			best = spot
	_box.position = best


## O que o HUD da Estação avisa (open_room, open_service, close_panel): se é a espera do passo, ele segue.
func moment(what: String) -> void:
	if _done or what != waiting_for():
		return
	advance()


func advance() -> void:
	if _done:
		return
	Sound.play("res://audio/ui/click.ogg", 0.5)
	if index + 1 >= steps.size():
		_finish()
		return
	index += 1
	Campaign.state.tutorial.tour = index
	Campaign.save()
	_show()


func skip() -> void:
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	AHTutorial.end_tour(Campaign.state)
	Tips.mark_seen(AHTutorial.TOUR_TIPS)
	Campaign.save()
	finished.emit()
	queue_free()


## Interagir faz o que o passo pede (o PRÓXIMO, ou a ação esperada); Voltar fecha o painel no passo de fechar e, nos
## outros, pula a visita. As outras teclas não passam para a Estação enquanto a visita está aberta.
func _input(event: InputEvent) -> void:
	if _done or not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction) or not event.is_pressed():
		return
	var wait := waiting_for()
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		# Com a fala ainda esperando a câmera, nada segue.
		if not _box.visible:
			return
		# Com o foco no PULAR VISITA (o teclado ou o controle chegaram nele), confirmar pula, como o clique.
		if _skip.is_visible_in_tree() and get_viewport().gui_get_focus_owner() == _skip:
			skip()
			return
		if wait == "next":
			advance()
		else:
			hud.tour_act(wait)
	elif AHUiStyle.is_back(event):
		get_viewport().set_input_as_handled()
		if wait == "close" and hud.current != "":
			hud.tour_act(wait)
		else:
			skip()
	elif not event.is_action_pressed("hide_hud"):
		get_viewport().set_input_as_handled()
