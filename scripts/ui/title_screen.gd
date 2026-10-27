## A tela de título (#28, a entrega #19 do Codex: docs/design/title.md): o fundo pintado, o logo e três botões:
## Continuar (só com save; volta à Estação ou à rua da expedição em andamento, na última campanha usada), Nova campanha
## (escolhe um dos três espaços, #34, e pede confirmação para sobrescrever um ocupado), Campanhas (abre outro espaço,
## quando há mais de uma campanha) e Opções. Mouse, teclado, controle e toque. Em tela retrato, a composição vertical.
## Modo de captura: --capture-title=<pasta> tira as fotos (sem save e com save, texto Normal e Maior, Opções e a
## confirmação) numa pasta própria e sai.
class_name AHTitleScreen
extends Control

const S = preload("res://scripts/ui/ui_style.gd")
const ART := "res://art/ui/title/"
## As medidas da proposta (docs/design/title.md), na base de 1920x1080 e de 1080x1920.
const LANDSCAPE := {"logo": Vector2(65, 160), "logo_width": 880.0, "buttons": Vector2(100, 425), "button": Vector2(510, 60), "gap": 14.0}
const PORTRAIT := {"logo": Vector2(80, 190), "logo_width": 920.0, "buttons": Vector2(120, 1320), "button": Vector2(840, 96), "gap": 24.0}

var _background: TextureRect
var _logo: TextureRect
var _buttons: VBoxContainer
var _note: PanelContainer
var _note_label: Label
var _keys: PanelContainer
var _note_width := 510.0
var _modal: PanelContainer
## O que o Voltar (Esc, Cancelar) faz na janela aberta; vazio, fecha.
var _modal_back := Callable()
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
	ink.color = AHKit.STEEL
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
	# O aviso (um espaço que não abriu): a chapa com o triângulo, abaixo dos botões.
	_note = AHKit.panel_box("inset")
	_note.name = "Warning"
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var note_row := HBoxContainer.new()
	note_row.add_theme_constant_override("separation", 12)
	_note.add_child(note_row)
	var alert := AHKit.glyph("alert", 28, AHKit.alert_text())
	alert.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	note_row.add_child(alert)
	_note_label = AHKit.label("", "small", AHKit.TEXT)
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_row.add_child(_note_label)
	add_child(_note)
	_note.minimum_size_changed.connect(func(): _place_note.call_deferred(_note_width))
	# A barra das teclas, embaixo à esquerda: a do menu e a da janela aberta.
	_keys = AHKit.panel(AHKit.piece_of("key", "bar"))
	_keys.name = "Keys"
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_keys)
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
		continue_button = _title_button(tr("Continuar"), "route", true, _continue)
		# Embaixo do Continuar, a linha do espaço numa chapinha.
		_buttons.add_child(_slot_chip(Campaign.slot_summary(Campaign.slot)))
	new_button = _title_button(tr("Nova campanha"), "recruit", continue_button == null, _ask_new_campaign)
	# Campanhas: quando há uma campanha que o Continuar não abre (outro espaço).
	var ok := range(1, Campaign.SLOT_COUNT + 1).filter(func(n): return Campaign.slot_summary(n).status == "ok").size()
	if ok > (1 if continue_button != null else 0):
		load_button = _title_button(tr("Campanhas"), "station", false, _open_slots.bind(false))
	options_button = _title_button(tr("Opções"), "res://art/ui/icons/lobby-settings.svg", false, _open_options)
	_note_label.text = Campaign.warning_text()
	_note.visible = _note_label.text != ""
	_set_keys([[[tr("Setas")], tr("Navegar")], [["interact"], tr("Confirmar")]])
	(continue_button if continue_button != null else new_button).grab_focus.call_deferred()


## Um botão do menu: o principal é o âmbar com a tecla de Interagir dentro; os outros, de aço.
func _title_button(text: String, icon_name: String, primary: bool, callback: Callable) -> Button:
	var button: Button
	if primary:
		button = AHStationReport._primary(text, "", "interact")
		button.icon = null
		var key: Control = button.get_node("Key")
		button.remove_child(key)
		key.queue_free()
		_add_key(button, tr("%s / A") % S.key_name("interact"), "interact")
	else:
		button = AHKit.button(text, "secondary")
	button.add_theme_font_size_override("font_size", AHKit.size("row"))
	_icon_beside_text(button, load(icon_name) if icon_name.begins_with("res://") else AHKit.icon(icon_name), AHKit.ON_AMBER if primary else AHKit.TEXT)
	button.pressed.connect(func():
		if _leaving or GameFlow.busy:
			return
		_opener = button
		callback.call())
	_buttons.add_child(button)
	return button


## O ícone logo antes do texto centrado do botão (o ícone do Button iria para a borda).
static func _icon_beside_text(button: Button, texture: Texture2D, tint: Color, flip: bool = false) -> void:
	var glyph := TextureRect.new()
	glyph.name = "Glyph"
	glyph.texture = texture
	glyph.flip_h = flip
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.size = Vector2(26, 26)
	glyph.modulate = tint
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(glyph)
	var style: StyleBox = button.get_theme_stylebox("normal")
	var place := func():
		if not is_instance_valid(button):
			return
		var text_width: float = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			button.get_theme_font_size("font_size")).x
		var left := style.content_margin_left if style else 0.0
		var right := style.content_margin_right if style else 0.0
		var center := left + (button.size.x - left - right) * 0.5
		glyph.position = Vector2(center - text_width * 0.5 - 38.0, (button.size.y - 26.0) * 0.5)
	button.resized.connect(place)
	place.call_deferred()


## A chapinha do espaço do Continuar (Campaign.slot_summary): o número, o ciclo, as fases e os vivos.
func _slot_chip(summary: Dictionary) -> PanelContainer:
	var chip := AHKit.chip("cost")
	chip.name = "SlotChip"
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	chip.add_child(row)
	row.add_child(AHKit.glyph("station", 22, AHKit.AMBER))
	var line := tr("Espaço %d") % summary.slot
	if summary.status == "ok":
		line += " · " + tr("Ciclo %d") % summary.cycle + " · " + ((tr("%d fase") if summary.phases == 1 else tr("%d fases")) % summary.phases) \
			+ " · " + tr("%d de %d vivos") % [summary.alive, summary.roster]
	row.add_child(AHKit.label(line, "small", AHKit.TEXT))
	return chip


## A barra das teclas: os grupos [[ações ou teclas], o que faz]; uma ação mostra a tecla dela.
func _set_keys(groups: Array) -> void:
	for child in _keys.get_children():
		child.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys.add_child(row)
	for group in groups:
		for key in group[0]:
			row.add_child(AHKitKey.make(key) if InputMap.has_action(key) else AHKitKey.make("", key))
		row.add_child(AHKit.label(group[1], "text", AHKit.TEXT))
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(6, 0)
		row.add_child(gap)
	_place_keys.call_deferred()


func _place_keys() -> void:
	_keys.reset_size()
	_keys.size = _keys.get_combined_minimum_size()
	var view := get_viewport_rect().size
	_keys.position = Vector2(28, view.y - _keys.size.y - 24)


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
		if button is Button:
			(button as Button).custom_minimum_size = spec.button * k
	_buttons.size = Vector2.ZERO
	_buttons.reset_size.call_deferred()
	# A largura do aviso antes de medir; quando o texto quebra de novo, a chapa acompanha.
	_note_label.custom_minimum_size = Vector2(spec.button.x * k + 16.0, 0)
	_note_width = spec.button.x * k
	_place_note.call_deferred(_note_width)
	_place_keys.call_deferred()


func _place_note(width: float) -> void:
	_buttons.reset_size()
	_note_label.custom_minimum_size = Vector2(width + 80.0 - 64.0, 0)
	_note.reset_size()
	# A chapa cresce só até a altura do texto já quebrado na largura dele (sem o tamanho de uma palavra por linha).
	_note.size = Vector2(_note.get_combined_minimum_size().x, 0)
	_note.size = _note.get_combined_minimum_size()
	_note.position = _buttons.position + Vector2(0, _buttons.get_combined_minimum_size().y + 24)


func _process(_delta: float) -> void:
	S.keep_focus(_modal if modal_open() else _buttons)


func _unhandled_input(event: InputEvent) -> void:
	var scope: Control = _modal if modal_open() else _buttons
	if S.press_focused(scope, event):
		get_viewport().set_input_as_handled()
	elif modal_open() and S.is_back(event):
		_go_back()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- janelas

func modal_open() -> bool:
	return _modal != null and is_instance_valid(_modal) and not _modal.is_queued_for_deletion()


## Voltar (Esc): a confirmação da campanha nova volta para a lista dos espaços (#34); as outras janelas fecham.
func _go_back() -> void:
	if _modal_back.is_valid():
		_modal_back.call()
	else:
		close_modal()


func close_modal() -> void:
	if modal_open():
		_modal.queue_free()
		Sound.play("res://audio/ui/panel_close.ogg")
	_modal = null
	_buttons.visible = true
	_note.visible = _note_label.text != ""
	_set_keys([[[tr("Setas")], tr("Navegar")], [["interact"], tr("Confirmar")]])
	S.refresh_keys(_buttons)
	S.reset_focus(_buttons)
	var back: Button = _opener if _opener != null and is_instance_valid(_opener) and _opener.is_inside_tree() else \
		(continue_button if continue_button != null else new_button)
	back.grab_focus.call_deferred()


## Uma janela do kit: a chapa grande com o título em maiúsculas e o ícone (as Campanhas, a campanha nova, as Opções).
func _open_modal(width: float, title: String, icon_name: String, alert: bool = false) -> VBoxContainer:
	if modal_open():
		_modal.queue_free()
	else:
		Sound.play("res://audio/ui/panel_open.ogg")
	_buttons.visible = false
	_note.visible = false
	_modal_back = Callable()
	_modal = AHKit.panel_box("large")
	_modal.name = "Window"
	_modal.custom_minimum_size = Vector2(width, 0)
	var view := get_viewport_rect().size
	_modal.position = Vector2((view.x - width) * 0.5, 150 if not _portrait else 300)
	add_child(_modal)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_modal.add_child(box)
	var head := HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	var glyph := TextureRect.new()
	glyph.texture = load(icon_name) if icon_name.begins_with("res://") else AHKit.icon(icon_name)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.custom_minimum_size = Vector2(34, 34)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.modulate = AHKit.alert_text() if alert else AHKit.AMBER
	head.add_child(glyph)
	var title_label := AHKit.label(title, "panel_title", AHKit.TEXT, true, true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	_set_keys([[[tr("Setas")], tr("Navegar")], [["interact"], tr("Confirmar")], [["Esc"], tr("Voltar")]])
	return box


## Centraliza a janela pela largura de verdade (no texto Maior ela passa da largura pedida).
func _center_modal() -> void:
	if modal_open():
		_modal.position.x = (get_viewport_rect().size.x - _modal.size.x) * 0.5


## Um botão de aço da janela, com a tecla de voltar dentro quando é o Voltar.
func _modal_button(text: String, callback: Callable, back_key: bool = false) -> Button:
	var button := AHKit.button(text, "secondary")
	button.custom_minimum_size = Vector2(0, 60)
	button.add_theme_font_size_override("font_size", AHKit.size("row"))
	if back_key:
		_add_key(button, "Esc / B")
	button.pressed.connect(callback)
	return button


## A tecla dentro do botão, logo depois do texto centrado: o texto e a tecla ficam juntos no meio do botão.
## action: a tecla segue a troca nas Opções (AHUiStyle.refresh_keys, com o formato "%s / A").
func _add_key(button: Button, text: String, action: String = "") -> void:
	var key := AHKitKey.make("", text, "button")
	key.name = "Key"
	if action != "":
		key.set_meta("ah_action", action)
		key.set_meta("ah_format", tr("%s / A"))
	button.add_child(key)
	var room := key.get_combined_minimum_size().x + 14.0
	# Um estilo pode servir a dois estados (o apertado e o apertado com o mouse): a margem soma uma vez só.
	var done: Array = []
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		if button.has_theme_stylebox_override(state):
			var style: StyleBox = button.get_theme_stylebox(state)
			if done.has(style):
				continue
			done.append(style)
			style.content_margin_right += room
	var place := func():
		if not is_instance_valid(button):
			return
		var style: StyleBox = button.get_theme_stylebox("normal")
		var text_width: float = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			button.get_theme_font_size("font_size")).x
		var center := style.content_margin_left + (button.size.x - style.content_margin_left - style.content_margin_right) * 0.5
		key.reset_size()
		key.position = Vector2(center + text_width * 0.5 + 14.0, (button.size.y - key.size.y) * 0.5)
	button.resized.connect(place)
	place.call_deferred()


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
func _open_slots(for_new: bool, focus_slot: int = 0) -> void:
	var box := _open_modal(760, tr("Em qual espaço começar?") if for_new else tr("Campanhas"), "station")
	var first: Button
	for number in range(1, Campaign.SLOT_COUNT + 1):
		var summary := Campaign.slot_summary(number)
		var button := _slot_row(summary, number == Campaign.slot)
		button.pressed.connect(_pick_slot.bind(number, for_new))
		button.disabled = not for_new and summary.status != "ok"
		# O espaço que não abre fica fora da navegação por teclado e controle.
		if button.disabled:
			button.focus_mode = Control.FOCUS_NONE
		box.add_child(button)
		if (first == null or number == focus_slot) and not button.disabled:
			first = button
	var back := _modal_button(tr("Voltar"), close_modal, true)
	_icon_beside_text(back, load("res://art/ui/icons/ui-arrow-right.svg"), AHKit.TEXT, true)
	back.name = "Back"
	box.add_child(back)
	(first if first != null else back).grab_focus.call_deferred()
	_center_modal.call_deferred()


## Um espaço na lista: o ícone (a Estação, ou o vazio), o nome e as linhas do resumo. O texto do botão é o de slot_text
## (o teclado e os testes leem por ele), desenhado pelas linhas de dentro; o vazio e o que não abre ficam apagados.
func _slot_row(summary: Dictionary, last: bool) -> Button:
	var button := Button.new()
	button.name = "Slot%d" % summary.slot
	AHKit.style_as(button, "list")
	button.text = slot_text(summary, last)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_disabled_color"]:
		button.add_theme_color_override(state, Color.TRANSPARENT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -14
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var ok: bool = summary.status == "ok"
	var tone: Color = AHKit.TEXT if ok else AHKit.MUTED
	var glyph := TextureRect.new()
	glyph.texture = AHKit.icon("station") if ok else AHKit.icon("alert" if summary.status == "broken" else "relic_empty")
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.custom_minimum_size = Vector2(32, 32)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.modulate = AHKit.AMBER if ok else (AHKit.alert_text() if summary.status == "broken" else AHKit.MUTED)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lines)
	var parts := slot_text(summary, last).split("\n")
	var head: String = parts[0]
	var slot_name: String = TranslationServer.translate("Espaço %d") % summary.slot
	lines.add_child(AHKit.label(slot_name, "row", tone, true))
	var rest := head.substr(head.find(" — ") + 3) if head.contains(" — ") else ""
	if summary.status == "empty":
		rest = tr("Vazio")
	elif summary.status == "broken":
		rest = tr("O save não abre")
	if rest != "":
		lines.add_child(AHKit.label(rest, "small", tone))
	if parts.size() > 1:
		var tail: String = parts[1]
		if last and ok:
			tail += " · " + tr("último usado")
		lines.add_child(AHKit.label(tail, "small", AHKit.MUTED))
	var grow := func(): button.custom_minimum_size.y = maxf(64.0, lines.get_combined_minimum_size().y + 20.0)
	lines.minimum_size_changed.connect(grow)
	grow.call()
	return button


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
	var box := _open_modal(720, tr("Começar uma campanha nova?"), "alert", true)
	var text := (tr("Todo o progresso salvo no espaço %d (fases concluídas, cômodos, recursos e heróis) é substituído por uma campanha do zero. Os outros espaços ficam como estão.") % number) \
		if summary.status == "ok" else (tr("O save do espaço %d não pôde ser aberto. Uma campanha nova grava por cima dele, e ele não volta mais.") % number)
	var note := AHKit.label(text, "text", AHKit.TEXT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(672, 0)
	box.add_child(note)
	_modal_back = _open_slots.bind(true, number)
	# CANCELAR é o âmbar, na tecla de voltar; COMEÇAR DO ZERO é de aço, em alerta e sem tecla.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var stay := AHStationReport._primary(tr("Cancelar"), "", "interact")
	stay.custom_minimum_size = Vector2(0, 60)
	stay.add_theme_font_size_override("font_size", AHKit.size("row"))
	stay.get_node("Key").queue_free()
	stay.remove_child(stay.get_node("Key"))
	_add_key(stay, "Esc / B")
	stay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stay.pressed.connect(_go_back)
	row.add_child(stay)
	var go := _modal_button(tr("Começar do zero"), _start_new_campaign.bind(number))
	_icon_beside_text(go, AHKit.icon("alert"), AHKit.alert_text())
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		go.add_theme_color_override(state, AHKit.alert_text())
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(go)
	stay.grab_focus.call_deferred()
	_center_modal.call_deferred()


## A campanha nova (#144): começar pela abertura (o tutorial, o padrão) ou pular para a Estação, com a mesma recompensa.
## Cada escolha numa linha do kit, com o que ela faz; a da abertura vem escolhida.
func _start_new_campaign(number: int) -> void:
	if _leaving or GameFlow.busy:
		return
	var box := _open_modal(760, tr("Como começar?"), "recruit")
	# Voltar leva à lista dos espaços (quando ela abriu antes) ou fecha.
	var any_save := range(1, Campaign.SLOT_COUNT + 1).any(func(n): return Campaign.slot_has_save(n))
	_modal_back = _open_slots.bind(true, number) if any_save else close_modal
	var opening := _choice_row(tr("Começar pela abertura (recomendado)"),
		tr("A fuga do Bento e do Nick pelo Corredor de Contenção: três lutas curtas que ensinam a jogar."), true)
	opening.name = "Opening"
	opening.pressed.connect(_begin_campaign.bind(number, true))
	box.add_child(opening)
	var skip := _choice_row(tr("Pular tutorial"),
		tr("Começa direto na Estação Raiz, como depois da abertura e com a mesma recompensa."), false)
	skip.name = "Skip"
	skip.pressed.connect(_begin_campaign.bind(number, false))
	box.add_child(skip)
	var back := _modal_button(tr("Voltar"), _go_back, true)
	_icon_beside_text(back, load("res://art/ui/icons/ui-arrow-right.svg"), AHKit.TEXT, true)
	back.name = "Back"
	box.add_child(back)
	opening.grab_focus.call_deferred()
	_center_modal.call_deferred()


## Uma escolha da campanha nova: a linha do kit (a escolhida com a moldura), o nome e o que ela faz embaixo. O texto do
## botão é o nome (o teclado e os testes leem por ele), desenhado pelas linhas de dentro.
func _choice_row(text: String, detail: String, chosen: bool) -> Button:
	var button := Button.new()
	AHKit.style_as(button, "list_selected" if chosen else "list")
	button.text = text
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_disabled_color"]:
		button.add_theme_color_override(state, Color.TRANSPARENT)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.offset_left = 20
	lines.offset_right = -16
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(lines)
	lines.add_child(AHKit.label(text, "row", AHKit.TEXT, true))
	var note := AHKit.label(detail, "small", AHKit.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(680, 0)
	lines.add_child(note)
	var grow := func(): button.custom_minimum_size.y = maxf(72.0, lines.get_combined_minimum_size().y + 20.0)
	lines.minimum_size_changed.connect(grow)
	grow.call()
	return button


## A campanha nova no espaço leva as opções mexidas no título (volumes, velocidade), que até aqui ficaram só na memória.
## Pela abertura, o cartão "Você precisa escapar." e o Corredor de Contenção; pulando, a Estação.
func _begin_campaign(number: int, tutorial: bool) -> void:
	if _leaving or GameFlow.busy:
		return
	_leaving = true
	var settings: Dictionary = Campaign.state.get("settings", {}).duplicate(true)
	Campaign.new_game_in(number)
	Campaign.state.settings.merge(settings, true)
	if tutorial:
		AHTutorial.begin(Campaign.state)
	else:
		AHTutorial.skip(Campaign.state)
	Campaign.save()
	var travelled: bool
	if tutorial:
		travelled = await GameFlow.travel("street", AHTutorial.opening_card())
	else:
		travelled = await GameFlow.travel("station")
	if not travelled:
		_leaving = false


## As Opções do título: o mesmo painel das da Estação, numa janela à direita (a logo fica à vista), com o X.
func _open_options() -> void:
	var box := _open_modal(700, tr("Opções"), "res://art/ui/icons/lobby-settings.svg")
	var view := get_viewport_rect().size
	if not _portrait:
		_modal.position = Vector2(view.x - 700.0 - 60.0, 40)
	var close := AHKit.button("X", "icon")
	close.name = "Close"
	close.custom_minimum_size = Vector2(52, 52)
	close.pressed.connect(close_modal)
	# O X é do mouse e do toque: o teclado e o controle fecham com o Esc e começam na primeira opção.
	close.focus_mode = Control.FOCUS_NONE
	box.get_node("Head").add_child(close)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(660, minf(860.0, view.y - 220.0))
	box.add_child(scroll)
	var options := AHOptionsPanel.new()
	options.width = 630
	options.show_title = false
	# Sem campanha que abre, as Opções não gravam (nem criam save, nem regravam um que não abre).
	options.save_campaign = can_continue()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.closed.connect(close_modal)
	scroll.add_child(options)
	_set_keys([[[tr("Setas")], tr("Navegar")], [["interact"], tr("Mudar")], [["Esc"], tr("Fechar")]])


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
		# O aviso de um espaço que não abriu (o que load_or_new marca), por cima do mesmo título.
		Campaign._warning_kind = "slot"
		Campaign._warning_slot = 2
		await _rebuild_for_capture()
		await _shot(dir, "title-warning" + suffix)
		Campaign._warning_kind = ""
		await _rebuild_for_capture()
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
