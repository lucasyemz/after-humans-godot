## O leitor de tirinhas (#207): abre pelo balão interativo da Estação viva e mostra os quadros de data/comics.json, um de
## cada vez, na chapa grande do kit: o título, o quadro (a imagem do quadro, ou o quadro provisório enquanto a arte não
## chega), a legenda (com quem fala, se é fala), a contagem em losangos e ANTERIOR / PRÓXIMO (no último, FECHAR).
## As setas (ou o direcional) trocam de quadro, Interagir passa e Voltar (Esc, B) fecha. Fechar no último quadro conta
## como vista (finished(true)); fechar antes, não: o Próximo passo continua pedindo.
class_name AHComicReader
extends Control

const U = preload("res://scripts/ui/ui_style.gd")
## O quadro na tela (px de 1080): a área da imagem, em 16:9.
const FRAME := Vector2(1120, 560)
## Logo que abre, o mesmo toque que apertou o balão não passa o quadro.
const GUARD_MS := 300

## read: chegou ao último quadro antes de fechar.
signal finished(read: bool)

var comic_name := ""
var panels: Array = []
var index := 0
var reached_end := false
var next_button: Button
var back_button: Button
var _box: PanelContainer
var _title: Label
var _image: TextureRect
var _placeholder: VBoxContainer
var _caption: Label
var _caption_row: HBoxContainer
## Sem a arte, a legenda vai grande no meio do quadro.
var _frame_caption: Label
var _speaker: Label
var _dots: HBoxContainer
var _page: Label
var _keys: PanelContainer
var _done := false
var _opened_ms := 0


static func open(parent: Node, name_id: String) -> AHComicReader:
	var reader := AHComicReader.new()
	reader.comic_name = name_id
	reader.panels = AHStationChatter.comic(name_id).get("Panels", [])
	parent.add_child(reader)
	return reader


func _init() -> void:
	name = "ComicReader"
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_opened_ms = Time.get_ticks_msec()
	global_position = Vector2.ZERO
	size = get_viewport_rect().size
	var dim := ColorRect.new()
	dim.color = Color(AHKit.SHADE, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_box = AHKit.panel_box("large")
	_box.name = "Comic"
	add_child(_box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	head.add_child(AHKit.glyph("night_talk", AHKit.size("panel_title"), AHKit.AMBER))
	_title = AHKit.label(tr(String(AHStationChatter.comic(comic_name).get("Title", ""))), "panel_title", AHKit.TEXT, true, true)
	head.add_child(_title)
	# O quadro: a imagem na moldura de dentro; sem ela, o quadro provisório (o desenho da conversa apagado e a legenda grande no meio).
	var frame := AHKit.panel_box("inset")
	frame.custom_minimum_size = FRAME
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(frame)
	_image = TextureRect.new()
	_image.name = "Image"
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_image)
	_placeholder = VBoxContainer.new()
	_placeholder.name = "Placeholder"
	_placeholder.alignment = BoxContainer.ALIGNMENT_CENTER
	_placeholder.add_theme_constant_override("separation", 12)
	_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_placeholder)
	var glyph := AHKit.glyph("night_talk", 96, Color(AHKit.MUTED, 0.6))
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_placeholder.add_child(glyph)
	_frame_caption = AHKit.label("", "panel_title", AHKit.TEXT)
	_frame_caption.name = "FrameCaption"
	_frame_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_frame_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_frame_caption.custom_minimum_size = Vector2(FRAME.x - 200, 0)
	_frame_caption.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_placeholder.add_child(_frame_caption)
	_caption_row = HBoxContainer.new()
	var caption_row := _caption_row
	caption_row.add_theme_constant_override("separation", 10)
	caption_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(caption_row)
	_speaker = AHKit.label("", "card_name", AHKit.AMBER, true)
	_speaker.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	caption_row.add_child(_speaker)
	_caption = AHKit.label("", "primary", AHKit.TEXT)
	_caption.name = "Caption"
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.custom_minimum_size = Vector2(FRAME.x - 40, 80)
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption_row.add_child(_caption)
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
	back_button = AHKit.button(tr("Anterior"), "secondary")
	back_button.name = "Previous"
	back_button.custom_minimum_size = Vector2(170, 56)
	back_button.add_theme_font_size_override("font_size", AHKit.size("row"))
	back_button.pressed.connect(previous)
	buttons.add_child(back_button)
	next_button = AHKit.button(tr("Próximo"), "primary")
	next_button.name = "Next"
	next_button.custom_minimum_size = Vector2(240, 56)
	next_button.add_theme_font_size_override("font_size", AHKit.size("row"))
	next_button.pressed.connect(advance)
	buttons.add_child(next_button)
	back_button.focus_neighbor_right = next_button.get_path()
	next_button.focus_neighbor_left = back_button.get_path()
	_keys = AHKit.panel(AHKit.piece_of("key", "bar"))
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_keys)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys.add_child(row)
	for pair in [[tr("Setas"), tr("Quadros")], ["interact", tr("Próximo")], ["Esc", tr("Fechar")]]:
		row.add_child(AHKitKey.make(pair[0]) if InputMap.has_action(pair[0]) else AHKitKey.make("", pair[0]))
		row.add_child(AHKit.label(pair[1], "text", AHKit.TEXT))
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(6, 0)
		row.add_child(gap)
	_show()
	AHKit.focus_later(next_button)


func _process(_delta: float) -> void:
	var view := get_viewport_rect().size
	global_position = Vector2.ZERO
	size = view
	_box.reset_size()
	_box.position = ((view - _box.size) * 0.5 - Vector2(0, 30)).round()
	_keys.reset_size()
	_keys.size = _keys.get_combined_minimum_size()
	_keys.position = Vector2((view.x - _keys.size.x) * 0.5, _box.position.y + _box.size.y + 14)
	if not _done:
		U.keep_focus(_box)


func guarded() -> bool:
	return Time.get_ticks_msec() - _opened_ms < GUARD_MS


func advance() -> void:
	if _done:
		return
	if index + 1 >= panels.size():
		_close()
		return
	index += 1
	Sound.play("res://audio/ui/click.ogg", 0.5)
	_show()


func previous() -> void:
	if _done or index <= 0:
		return
	index -= 1
	Sound.play("res://audio/ui/click.ogg", 0.5)
	_show()


func _show() -> void:
	if panels.is_empty():
		_close.call_deferred()
		return
	var panel: Dictionary = panels[index]
	reached_end = reached_end or index + 1 >= panels.size()
	var path := String(panel.get("Image", ""))
	var art: Texture2D = load(path) if path != "" and ResourceLoader.exists(path) else null
	_image.texture = art
	_image.visible = art != null
	_placeholder.visible = art == null
	var speaker := tr(String(panel.get("Speaker", ""))) if String(panel.get("Speaker", "")) != "" else ""
	_speaker.text = speaker + ":" if speaker != "" else ""
	_speaker.visible = speaker != ""
	var caption := tr(String(panel.get("Caption", "")))
	_caption.text = ("“%s”" % caption) if speaker != "" else caption
	_caption_row.visible = art != null
	_frame_caption.text = ("%s “%s”" % [_speaker.text, caption]) if speaker != "" else caption
	for child in _dots.get_children():
		child.queue_free()
	for i in panels.size():
		var dot := TextureRect.new()
		dot.texture = AHKit.legacy_icon("marker-available")
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dot.custom_minimum_size = Vector2.ONE * float(AHKit.size("small"))
		dot.modulate = AHKit.AMBER if i <= index else AHKit.MUTED
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dots.add_child(dot)
	_page.text = "%d/%d" % [index + 1, panels.size()]
	var last := index + 1 >= panels.size()
	next_button.text = (tr("Fechar") if last else tr("Próximo")).to_upper()
	back_button.disabled = index == 0


func _close() -> void:
	if _done:
		return
	_done = true
	finished.emit(reached_end)
	queue_free()


func _input(event: InputEvent) -> void:
	if _done or not is_visible_in_tree():
		return
	if guarded() and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		previous()
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		if index + 1 < panels.size():
			advance()
	elif U.press_focused(_box, event):
		get_viewport().set_input_as_handled()
	elif U.is_back(event):
		get_viewport().set_input_as_handled()
		_close()
