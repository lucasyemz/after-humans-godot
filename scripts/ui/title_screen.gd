## A tela de título (#28, a entrega #19 do Codex: docs/design/title.md): o fundo pintado, o logo e três botões:
## Continuar (só com save; volta à Estação ou à rua da expedição em andamento, na última campanha usada), Nova campanha
## (escolhe um dos três espaços, #34, e pede confirmação para sobrescrever um ocupado), Campanhas (abre outro espaço,
## quando há mais de uma campanha) e Opções. Mouse, teclado, controle e toque. Em tela retrato, a composição vertical.
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
var load_button: Button
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
	load_button = null
	if can_continue():
		continue_button = _title_button(tr("Continuar"), true, _continue)
	new_button = _title_button(tr("Nova campanha"), continue_button == null, _ask_new_campaign)
	# Campanhas: quando há uma campanha que o Continuar não abre (outro espaço).
	var ok := range(1, Campaign.SLOT_COUNT + 1).filter(func(n): return Campaign.slot_summary(n).status == "ok").size()
	if ok > (1 if continue_button != null else 0):
		load_button = _title_button(tr("Campanhas"), false, _open_slots.bind(false))
	options_button = _title_button(tr("Opções"), false, _open_options)
	_note.text = Campaign.load_warning
	_note.visible = Campaign.load_warning != ""
	(continue_button if continue_button != null else new_button).grab_focus.call_deferred()


func _title_button(text: String, primary: bool, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	# O principal é o botão com a barra lateral dourada (button_primary); os outros, cobre (a proposta).
	H.style_button(button, S.GOLD, primary)
	button.add_theme_font_size_override("font_size", S.px(28))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBox = button.get_theme_stylebox(state).duplicate()
		style.content_margin_left = 32
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
	var count := _buttons.get_children().filter(func(c): return not c.is_queued_for_deletion()).size()
	_note.position = origin + (spec.buttons + Vector2(0, count * (spec.button.y + spec.gap) + 16)) * k
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
		Sound.play("res://audio/ui/panel_close.ogg")
	_modal = null
	_buttons.visible = true
	S.reset_focus(_buttons)
	var back: Button = _opener if _opener != null and is_instance_valid(_opener) and _opener.is_inside_tree() else \
		(continue_button if continue_button != null else new_button)
	back.grab_focus.call_deferred()


func _open_modal(width: float) -> VBoxContainer:
	if modal_open():
		_modal.queue_free()
	else:
		Sound.play("res://audio/ui/panel_open.ogg")
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


## Centraliza a janela pela largura de verdade (no texto Maior ela passa da largura pedida).
func _center_modal() -> void:
	if modal_open():
		_modal.position.x = (get_viewport_rect().size.x - _modal.size.x) * 0.5


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
	# Se a troca for recusada, o título volta a responder (em vez de ficar parado).
	if not await GameFlow.continue_game():
		_leaving = false


## Nova campanha: sem nenhum save em nenhum espaço, começa direto no espaço 1; senão, escolhe o espaço.
func _ask_new_campaign() -> void:
	if range(1, Campaign.SLOT_COUNT + 1).all(func(n): return not Campaign.slot_has_save(n)):
		_start_new_campaign(1)
		return
	_open_slots(true)


## Os três espaços com o resumo de cada um. Para a campanha nova, todos servem (o ocupado pergunta antes); para abrir,
## só os que têm uma campanha que abre.
func _open_slots(for_new: bool) -> void:
	var box := _open_modal(760)
	box.add_child(H.make_label(tr("Em qual espaço começar?") if for_new else tr("Campanhas"), 34, H.GOLD))
	var first: Button
	for number in range(1, Campaign.SLOT_COUNT + 1):
		var summary := Campaign.slot_summary(number)
		var button := _modal_button(slot_text(summary, number == Campaign.slot), _pick_slot.bind(number, for_new))
		button.name = "Slot%d" % number
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 84)
		button.disabled = not for_new and summary.status != "ok"
		# O espaço que não abre fica fora da navegação por teclado e controle.
		if button.disabled:
			button.focus_mode = Control.FOCUS_NONE
		box.add_child(button)
		if first == null and not button.disabled:
			first = button
	var back := _modal_button(tr("Voltar"), close_modal)
	box.add_child(back)
	(first if first != null else back).grab_focus.call_deferred()
	_center_modal.call_deferred()


## A linha de um espaço: o número e, se tem campanha, o ciclo, as fases, o elenco vivo, a data e o tempo jogado.
static func slot_text(summary: Dictionary, last: bool) -> String:
	var head: String = TranslationServer.translate("Espaço %d") % summary.slot \
		+ (TranslationServer.translate(" (último usado)") if last and summary.status == "ok" else "")
	match summary.status:
		"empty":
			return TranslationServer.translate("%s — vazio") % head
		"broken":
			return TranslationServer.translate("%s — o save não abre") % head
	var date := Time.get_datetime_dict_from_unix_time(int(summary.saved_at) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
	var minutes := int(summary.played_seconds) / 60
	var played: String = (TranslationServer.translate("%d h %02d min") % [minutes / 60, minutes % 60]) if minutes >= 60 \
		else (TranslationServer.translate("%d min") % minutes)
	var phases: String = (TranslationServer.translate("%d fase") if summary.phases == 1 else TranslationServer.translate("%d fases")) % summary.phases
	return TranslationServer.translate("%s — Ciclo %d · %s · %d de %d vivos\n%02d/%02d/%d %02d:%02d · %s jogados%s") % [head, summary.cycle,
		phases, summary.alive, summary.roster, date.day, date.month, date.year, date.hour, date.minute, played,
		TranslationServer.translate(" · em expedição") if summary.in_expedition else ""]


func _pick_slot(number: int, for_new: bool) -> void:
	if _leaving or GameFlow.busy:
		return
	if not for_new:
		_leaving = true
		Campaign.use_slot(number)
		if not await GameFlow.continue_game():
			_leaving = false
		return
	if not Campaign.slot_has_save(number):
		_start_new_campaign(number)
		return
	var summary := Campaign.slot_summary(number)
	var box := _open_modal(680)
	box.add_child(H.make_label(tr("Começar uma campanha nova?"), 34, H.GOLD))
	var text := (tr("Todo o progresso salvo no espaço %d (fases concluídas, cômodos, recursos e heróis) é substituído por uma campanha do zero. Os outros espaços ficam como estão.") % number) \
		if summary.status == "ok" else (tr("O save do espaço %d não pôde ser aberto. Uma campanha nova grava por cima dele, e ele não volta mais.") % number)
	var note := H.make_label(text, 22, H.TEXT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(620, 0)
	box.add_child(note)
	var stay := _modal_button(tr("Cancelar"), close_modal)
	box.add_child(stay)
	box.add_child(_modal_button(tr("Começar do zero"), _start_new_campaign.bind(number)))
	stay.grab_focus.call_deferred()


## A campanha nova no espaço leva as opções mexidas no título (volumes, velocidade), que até aqui ficaram só na memória.
func _start_new_campaign(number: int) -> void:
	if _leaving or GameFlow.busy:
		return
	_leaving = true
	var settings: Dictionary = Campaign.state.get("settings", {}).duplicate(true)
	Campaign.new_game_in(number)
	Campaign.state.settings.merge(settings, true)
	Campaign.save()
	if not await GameFlow.change_to("station"):
		_leaving = false


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
## Normal e no Maior, os espaços de campanha (dois ocupados e um vazio), a confirmação da Nova campanha e as Opções.
func _capture(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Campaign.save_dir = dir.path_join("save")
	Campaign.slot = 1
	for size in [0, 2]:
		Settings.set_text_size(size)
		var suffix := "" if size == 0 else "-maior"
		Campaign.state = Campaign.create_initial(7)
		await _rebuild_for_capture()
		await _shot(dir, "title-new" + suffix)
		Campaign.new_game_in(2, 8)
		Campaign.state.completed_phases = ["fase_1"]
		Campaign.state.played_seconds = 4380
		Campaign.save()
		Campaign.new_game_in(1, 7)
		await _rebuild_for_capture()
		await _shot(dir, "title-continue" + suffix)
		_ask_new_campaign()
		await _shot(dir, "title-slots" + suffix)
		_pick_slot(1, true)
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
