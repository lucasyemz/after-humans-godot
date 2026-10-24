## Mapa de fases da Estação (port do UAHExpeditionMapWidget): o bairro alagado pintado, a Estação Raiz e as cinco fases
## como nós (concluída, disponível, bloqueada), o painel da fase escolhida (imagem, dificuldade, nível, descrição,
## Preparar expedição ou Jogar de novo) e a lista das fases. A fase escolhida segue para a Preparação.
class_name AHPhaseMap
extends Control

signal phase_chosen(phase_id: String)
signal closed

const H = preload("res://scripts/ui/combat_hud.gd")
const J = preload("res://scripts/flow/journey_rules.gd")
const S = preload("res://scripts/flow/station_rules.gd")
## Espaço das posições dos nós (railwayPositions da web).
const SPACE := Vector2(1100, 660)
const MAP_RECT := Rect2(36, 120, 1240, 744)
const REFUGE_POS := Vector2(140, 480)
const ICONS := "res://art/ui/icons/%s.svg"
const IMAGES := "res://art/ui/scenarios/%s.webp"

var selected := ""
var _nodes: Control
var _aside: VBoxContainer
var _header: Label
var _progress: ProgressBar
var _footer: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = Color("0f2224")
	back.position = Vector2.ZERO
	back.size = Vector2(1920, 1080)
	add_child(back)

	var title := H.make_label("Mapa ferroviário", 34, H.GOLD)
	title.position = Vector2(40, 28)
	add_child(title)
	_header = H.make_label("", 19, H.MUTED)
	_header.position = Vector2(40, 76)
	add_child(_header)
	_progress = H.make_bar(Color("e8b864"), 10)
	_progress.position = Vector2(420, 84)
	_progress.size = Vector2(260, 10)
	add_child(_progress)
	var close := Button.new()
	close.text = "Voltar à Estação"
	close.custom_minimum_size = Vector2(240, 48)
	close.position = Vector2(1036, 36)
	H.style_button(close)
	close.pressed.connect(func(): closed.emit())
	add_child(close)

	# O bairro alagado cobrindo a área do mapa (object-fit: cover), com o leve escurecimento da web.
	var frame := Control.new()
	frame.position = MAP_RECT.position
	frame.size = MAP_RECT.size
	frame.clip_contents = true
	add_child(frame)
	var art := TextureRect.new()
	art.texture = load("res://art/ui/map/flooded-railway-map.webp")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.size = MAP_RECT.size
	frame.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(0.008, 0.07, 0.08, 0.18)
	shade.size = MAP_RECT.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(shade)
	_nodes = Control.new()
	_nodes.size = MAP_RECT.size
	_nodes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_nodes)

	_footer = H.make_label("", 20, H.TEXT)
	_footer.position = Vector2(40, MAP_RECT.end.y + 18)
	add_child(_footer)

	var aside_panel := PanelContainer.new()
	aside_panel.add_theme_stylebox_override("panel", H.panel_style(0.94))
	aside_panel.position = Vector2(1300, 28)
	aside_panel.size = Vector2(584, 1024)
	add_child(aside_panel)
	var scroll := ScrollContainer.new()
	# A rolagem acompanha o foco do teclado e do controle (#5).
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	aside_panel.add_child(scroll)
	_aside = VBoxContainer.new()
	_aside.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aside.add_theme_constant_override("separation", 10)
	scroll.add_child(_aside)


func _ready() -> void:
	# A tela inteira do HUD (1920 x 1080): cobre a Estação e segura os cliques.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Abre na fase dada (a do rascunho da Preparação) ou na Estação.
func open(phase_id: String = "") -> void:
	AHUiStyle.reset_focus(self)
	selected = phase_id
	visible = true
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and AHUiStyle.is_back(event):
		get_viewport().set_input_as_handled()
		closed.emit()


func refresh() -> void:
	var c: Dictionary = Campaign.state
	var completed := J.PHASES.filter(func(p): return c.completed_phases.has(p.id)).size()
	var living := S.living(c).size()
	_header.text = "Bairro Submerso · Fases concluídas %d / %d · Equipe: %d %s" % [completed, J.PHASES.size(), living, "vivo" if living == 1 else "vivos"]
	_header.size = Vector2(0, 0)
	_progress.max_value = J.PHASES.size()
	_progress.value = completed
	_progress.position.x = 40 + _header.get_minimum_size().x + 24
	_footer.text = "Estoque da Estação · Sementes %d · Sucata %d · Fragmentos %d" % [S.quantity(c, "seeds"), S.quantity(c, "scrap"), S.quantity(c, "fragments")]
	for child in _nodes.get_children():
		child.queue_free()
	_add_node("", "Estação Raiz", "node-start", "marker-here", "Refúgio", true, selected == "", true, REFUGE_POS)
	for i in J.PHASES.size():
		var info: Dictionary = J.PHASES[i]
		var done: bool = c.completed_phases.has(info.id)
		var open: bool = S.phase_unlocked(c, info.id)
		var marker := "marker-visited" if done else ("marker-available" if open else "")
		_add_node(info.id, info.name, _icon_of(info), marker, "Fase %d · %s" % [i + 1, _status(c, info)], open, info.id == selected,
			false, Vector2(info.map_pos[0], info.map_pos[1]))
	_build_aside(c)


## O tamanho do texto mudou nas Opções (AHUiStyle.retune).
func restyle() -> void:
	# Os nós medem o rótulo para ficar centrados no ponto da fase: refeitos com o texto novo (a fase escolhida fica).
	if visible:
		refresh()


func _status(c: Dictionary, info: Dictionary) -> String:
	return "Concluída" if c.completed_phases.has(info.id) else ("Disponível" if S.phase_unlocked(c, info.id) else "Bloqueada")


func _icon_of(info: Dictionary) -> String:
	return "node-boss" if info.node_type == "boss" else "node-combat"


func _icon(name: String, size: float, color: Color) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load(ICONS % name)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	rect.modulate = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _box(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


## Um nó (.rail-node): círculo com o ícone e o marcador, a plaquinha com o nome e a etiqueta com o estado; clicável.
func _add_node(id: String, title: String, icon: String, marker: String, status: String, open: bool, chosen: bool, here: bool, pos: Vector2) -> void:
	var ring := Color("ffdb91") if chosen else (Color("ffe0a0") if here else (Color("f0c881") if open else Color("81785f")))
	var icon_color := Color("ffe8b2") if chosen else (Color("f6d698") if open or here else Color("8f8873"))
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "%s · %s" % [title, status]
	button.pressed.connect(func(): _select(id))
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	var symbol := Control.new()
	symbol.custom_minimum_size = Vector2(60, 60)
	symbol.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(symbol)
	var circle := Panel.new()
	circle.add_theme_stylebox_override("panel", _box(Color("6a4a20") if chosen else (Color("142a2c") if open or here else Color("0d1a1b")), ring, 30, 3 if here or chosen else 2))
	circle.size = Vector2(60, 60)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	symbol.add_child(circle)
	var glyph := _icon(icon, 28, icon_color)
	glyph.position = Vector2(16, 16)
	glyph.size = Vector2(28, 28)
	symbol.add_child(glyph)
	if marker != "":
		var badge := Panel.new()
		badge.add_theme_stylebox_override("panel", _box(Color("45351d") if here else Color("0b1c1e"), Color("c9a772"), 12, 1))
		badge.position = Vector2(46, -12)
		badge.size = Vector2(24, 24)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		symbol.add_child(badge)
		var mark := _icon(marker, 16, Color("ffe0a0") if here else Color("f6cb7d"))
		mark.position = Vector2(4, 4)
		mark.size = Vector2(16, 16)
		badge.add_child(mark)
	var plate := PanelContainer.new()
	var plate_style := _box(Color("4a371e", 0.96) if chosen else Color("081719", 0.95), Color("f3c17b") if chosen else (Color("d4a65f") if open else Color("6f6247")), 4, 1)
	plate_style.content_margin_left = 8
	plate_style.content_margin_right = 8
	plate_style.content_margin_top = 3
	plate_style.content_margin_bottom = 3
	plate.add_theme_stylebox_override("panel", plate_style)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(H.make_label(title, 17, Color("ffdfaa") if open or here else Color("a89c84")))
	column.add_child(plate)
	var tag := PanelContainer.new()
	var tag_style := _box(Color("e9b45e") if here else (Color("edbd72") if open else Color("7d735d")), Color(0, 0, 0, 0), 3, 0)
	tag_style.content_margin_left = 8
	tag_style.content_margin_right = 8
	tag.add_theme_stylebox_override("panel", tag_style)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(H.make_label(status, 15, Color("1d1a10")))
	column.add_child(tag)
	_nodes.add_child(button)
	# Centro do círculo no ponto do mapa (alinhamento 0,5 x 0, 30 px acima).
	var scale := MAP_RECT.size / SPACE
	var width := maxf(column.get_combined_minimum_size().x, 60.0)
	column.size = Vector2(width, column.get_combined_minimum_size().y)
	button.size = column.size
	button.position = Vector2(pos.x * scale.x - width * 0.5, pos.y * scale.y - 30)


func _select(id: String) -> void:
	selected = id
	refresh()


## Painel da fase escolhida (ou da Estação) e a lista das fases.
func _build_aside(c: Dictionary) -> void:
	for child in _aside.get_children():
		child.queue_free()
	var info := J.phase(selected) if selected != "" else {}
	var image := TextureRect.new()
	image.texture = load(IMAGES % (info.scenario if not info.is_empty() else "estacao-raiz"))
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.custom_minimum_size = Vector2(560, 300)
	_aside.add_child(image)
	if info.is_empty():
		_aside.add_child(H.make_label("REFÚGIO", 16, H.MUTED))
		_aside.add_child(H.make_label("Estação Raiz", 32, H.GOLD))
		_aside.add_child(H.make_label("Vida restaurada ao voltar", 18, Color("e8b864")))
		_aside.add_child(_wrap("A comunidade mantém trilhos, oficinas e cuidado com ferramentas herdadas. Escolha uma fase no mapa para partir com a equipe.", 19, H.TEXT))
	else:
		var number := J.PHASES.map(func(p): return p.id).find(info.id) + 1
		var done: bool = c.completed_phases.has(info.id)
		var open: bool = S.phase_unlocked(c, info.id)
		_aside.add_child(H.make_label("FASE %d · DIFICULDADE: %s" % [number, J.DIFFICULTY_NAMES[info.difficulty].to_upper()], 16, H.MUTED))
		_aside.add_child(H.make_label(info.name, 32, H.GOLD))
		_aside.add_child(H.make_label("Concluída · dá para jogar de novo" if done else ("Disponível" if open else "Bloqueada · vença a fase anterior"), 18, Color("e8b864") if open else H.MUTED))
		_aside.add_child(_wrap(info.description, 19, H.TEXT))
		var guard := "O Porteiro e seus Relés de Defesa guardam a eclusa." if info.node_type == "boss" else "Um guardião protege a saída; vencê-lo conclui a fase."
		var place := AHScenarioWorld.display_of(info.transit) + " e " + AHScenarioWorld.display_of(info.map) if info.transit != "" else AHScenarioWorld.display_of(info.map)
		_aside.add_child(_wrap("Nível recomendado dos personagens: %d ou mais.\nLocal: %s. Travessia de 10 trechos · patrulhas, coisas para vasculhar e descanso. %s" % [info.level, place, guard], 17, H.MUTED))
		if open:
			var go := Button.new()
			go.text = "Jogar de novo" if done else "Preparar expedição"
			go.custom_minimum_size = Vector2(0, 54)
			go.add_theme_font_size_override("font_size", AHUiStyle.px(22))
			H.style_button(go)
			var id: String = info.id
			go.pressed.connect(func(): phase_chosen.emit(id))
			_aside.add_child(go)
			go.grab_focus.call_deferred()
	var stops := H.make_label("Fases", 22, H.GOLD)
	_aside.add_child(stops)
	for i in J.PHASES.size():
		var phase: Dictionary = J.PHASES[i]
		var open: bool = S.phase_unlocked(c, phase.id)
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s\nFase %d · %s · Nível %d+ · %s" % [phase.name, i + 1, J.DIFFICULTY_NAMES[phase.difficulty], phase.level, _status(c, phase)]
		button.icon = load(ICONS % ("marker-visited" if c.completed_phases.has(phase.id) else _icon_of(phase)))
		button.expand_icon = false
		button.add_theme_constant_override("icon_max_width", 22)
		button.custom_minimum_size = Vector2(0, 62)
		H.style_button(button)
		# As duas linhas e o ícone cabem no painel no texto Maior com a margem lateral menor (#29).
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style: StyleBox = button.get_theme_stylebox(state)
			style.content_margin_left = 12
			style.content_margin_right = 12
		if phase.id == selected:
			button.add_theme_color_override("font_color", H.GOLD)
		elif not open:
			button.add_theme_color_override("font_color", Color("9b917b"))
		var id: String = phase.id
		button.pressed.connect(func(): _select(id))
		_aside.add_child(button)


func _wrap(text: String, size: int, color: Color) -> Label:
	var label := H.make_label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(540, 0)
	return label
