## A tela de título (#28, a entrega #19 do Codex: docs/design/title.md): o fundo pintado, o logo e três botões:
## Continuar (só com save; volta à Estação ou à rua da expedição em andamento), Nova campanha (com confirmação quando
## há um save a perder) e Opções. Mouse, teclado, controle e toque. Em tela retrato, a composição vertical.
## Modo de captura: --capture-title=<pasta> tira as fotos (sem save e com save, texto Normal e Maior, Opções e a
## confirmação) numa pasta própria e sai.
class_name AHTitleScreen
extends Control

const H = preload("res://scripts/ui/combat_hud.gd")
const S = preload("res://scripts/ui/ui_style.gd")
const ART := "res://art/ui/title/"
## As medidas da proposta (docs/design/title.md), na base de 1920x1080 e de 1080x1920.
const LANDSCAPE := {"logo": Vector2(65, 160), "logo_width": 880.0, "buttons": Vector2(120, 500), "button": Vector2(640, 80), "gap": 24.0}
const PORTRAIT := {"logo": Vector2(80, 190), "logo_width": 920.0, "buttons": Vector2(120, 1320), "button": Vector2(840, 96), "gap": 24.0}

var _background: TextureRect
var _logo: TextureRect
var _buttons: VBoxContainer
var _note: Label
var _modal: PanelContainer
var _portrait := false
## Saindo do título (Continuar ou campanha nova): a troca de cena está em andamento e a tela não aceita mais nada.
var _leaving := false
## O botão que abriu a janela (Nova campanha, Opções): o foco volta para ele ao fechar.
var _opener: Button
var continue_button: Button
var new_button: Button
var options_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var ink := ColorRect.new()
	ink.color = S.INK
	ink.set_anchors_preset(Control.PRESET_FULL_RECT)
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ink)
	_background = TextureRect.new()
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_logo = TextureRect.new()
	_logo.texture = load(ART + "after_humans_logo.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)
	_buttons = VBoxContainer.new()
	add_child(_buttons)
	_note = S.label("", 20, Color(1.0, 0.75, 0.55))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_note)
	_build_buttons()
	get_viewport().size_changed.connect(_layout)
	_layout()
	var capture := _capture_dir()
	if capture != "":
		_capture.call_deferred(capture)


## Continuar só aparece com um save que abre (o principal ou a cópia); sem ele, Nova campanha é o botão principal.
func can_continue() -> bool:
	return Campaign.has_valid_save()


func _build_buttons() -> void:
	for child in _buttons.get_children():
		child.queue_free()
	continue_button = null
	if can_continue():
		continue_button = _title_button("Continuar", true, _continue)
	new_button = _title_button("Nova campanha", continue_button == null, _ask_new_campaign)
	options_button = _title_button("Opções", false, _open_options)
	_note.text = Campaign.load_warning
	_note.visible = Campaign.load_warning != ""
	(continue_button if continue_button != null else new_button).grab_focus.call_deferred()


func _title_button(text: String, primary: bool, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	H.style_button(button)
	button.add_theme_font_size_override("font_size", S.px(28))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# O principal tem o filete dourado; os outros, cobre (a proposta).
	for state in ["normal", "disabled"]:
		var style: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
		style.border_color = S.GOLD if primary else Color(S.COPPER, 0.7)
		style.content_margin_left = 28
		button.add_theme_stylebox_override(state, style)
	for state in ["hover", "pressed", "focus"]:
		var style: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
		style.content_margin_left = 28
		style.set_border_width_all(3)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(func():
		if _leaving or GameFlow.busy:
			return
		_opener = button
		callback.call())
	_buttons.add_child(button)
	return button


## Retrato quando a tela é mais alta que larga (celular em pé); senão, a composição de 1920x1080.
func _layout() -> void:
	var view := get_viewport_rect().size
	_portrait = view.y > view.x
	var spec: Dictionary = PORTRAIT if _portrait else LANDSCAPE
	var base := Vector2(1080, 1920) if _portrait else Vector2(1920, 1080)
	var k := minf(view.x / base.x, view.y / base.y)
	var origin := (view - base * k) * 0.5
	_background.texture = load(ART + ("title_background_portrait.png" if _portrait else "title_background.png"))
	var logo_size := Vector2(spec.logo_width, spec.logo_width * 560.0 / 2048.0)
	_logo.position = origin + spec.logo * k
	_logo.size = logo_size * k
	_buttons.position = origin + spec.buttons * k
	_buttons.add_theme_constant_override("separation", int(spec.gap * k))
	for button in _buttons.get_children():
		(button as Button).custom_minimum_size = spec.button * k
	_buttons.size = Vector2.ZERO
	_note.position = origin + (spec.buttons + Vector2(0, 3 * (spec.button.y + spec.gap) + 16)) * k
	_note.size = Vector2(spec.button.x * k, 0)


func _process(_delta: float) -> void:
	S.keep_focus(_modal if modal_open() else _buttons)


func _unhandled_input(event: InputEvent) -> void:
	var scope: Control = _modal if modal_open() else _buttons
	if S.press_focused(scope, event):
		get_viewport().set_input_as_handled()
	elif modal_open() and S.is_back(event):
		close_modal()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- janelas

func modal_open() -> bool:
	return _modal != null and is_instance_valid(_modal) and not _modal.is_queued_for_deletion()


func close_modal() -> void:
	if modal_open():
		_modal.queue_free()
	_modal = null
	_buttons.visible = true
	S.reset_focus(_buttons)
	var back: Button = _opener if _opener != null and is_instance_valid(_opener) and _opener.is_inside_tree() else \
		(continue_button if continue_button != null else new_button)
	back.grab_focus.call_deferred()


func _open_modal(width: float) -> VBoxContainer:
	if modal_open():
		_modal.queue_free()
	_buttons.visible = false
	_modal = PanelContainer.new()
	_modal.add_theme_stylebox_override("panel", H.panel_style(0.95))
	_modal.custom_minimum_size = Vector2(width, 0)
	var view := get_viewport_rect().size
	_modal.position = Vector2((view.x - width) * 0.5, 120 if not _portrait else 300)
	add_child(_modal)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_modal.add_child(box)
	return box


func _modal_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 56)
	H.style_button(button)
	button.add_theme_font_size_override("font_size", S.px(22))
	button.pressed.connect(callback)
	return button


func _continue() -> void:
	_leaving = true
	GameFlow.continue_game()


## Nova campanha: sem nenhum arquivo de save, começa direto; com arquivo (mesmo um que não abre), pergunta antes.
func _ask_new_campaign() -> void:
	if not Campaign.has_save():
		_start_new_campaign()
		return
	var box := _open_modal(680)
	box.add_child(H.make_label("Começar uma campanha nova?", 34, H.GOLD))
	var text := "Todo o progresso salvo (fases concluídas, cômodos, recursos e heróis) é substituído por uma campanha do zero." \
		if can_continue() else "O save que existe não pôde ser aberto. Uma campanha nova grava por cima dele, e ele não volta mais."
	var note := H.make_label(text, 22, H.TEXT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(620, 0)
	box.add_child(note)
	var stay := _modal_button("Cancelar", close_modal)
	box.add_child(stay)
	box.add_child(_modal_button("Começar do zero", _start_new_campaign))
	stay.grab_focus.call_deferred()


## A campanha nova leva as opções mexidas no título (volumes, velocidade), que até aqui ficaram só na memória.
func _start_new_campaign() -> void:
	if _leaving or GameFlow.busy:
		return
	_leaving = true
	var settings: Dictionary = Campaign.state.get("settings", {}).duplicate(true)
	Campaign.new_game()
	Campaign.state.settings.merge(settings, true)
	Campaign.save()
	GameFlow.change_to("station")


func _open_options() -> void:
	var box := _open_modal(720)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(680, minf(840.0, get_viewport_rect().size.y - 240.0))
	box.add_child(scroll)
	var options := AHOptionsPanel.new()
	options.width = 660
	# Sem campanha que abre, as Opções não gravam (nem criam save, nem regravam um que não abre).
	options.save_campaign = can_continue()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.closed.connect(close_modal)
	scroll.add_child(options)


# ---------------------------------------------------------------- captura

func _capture_dir() -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--capture-title="):
			return String(arg).trim_prefix("--capture-title=")
	return ""


## As fotos da proposta: sem save e com save (um save numa pasta dentro da de captura, nunca a do jogador), no texto
## Normal e no Maior, e as Opções e a confirmação da Nova campanha.
func _capture(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Campaign.save_dir = dir.path_join("save")
	for size in [0, 2]:
		Settings.set_text_size(size)
		var suffix := "" if size == 0 else "-maior"
		Campaign.state = Campaign.create_initial(7)
		await _rebuild_for_capture()
		await _shot(dir, "title-new" + suffix)
		Campaign.new_game(7)
		await _rebuild_for_capture()
		await _shot(dir, "title-continue" + suffix)
		_ask_new_campaign()
		await _shot(dir, "title-confirm" + suffix)
		close_modal()
		_open_options()
		await _shot(dir, "title-options" + suffix)
		close_modal()
		for file in DirAccess.get_files_at(Campaign.save_dir):
			DirAccess.remove_absolute(Campaign.save_dir.path_join(file))
	get_tree().quit()


func _rebuild_for_capture() -> void:
	_build_buttons()
	await get_tree().process_frame
	_layout()


func _shot(dir: String, name: String) -> void:
	for i in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("shot ", name)
