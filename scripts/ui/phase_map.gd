## O Mapa da Rede (#87; a arte e o contrato da #86, docs/design/phase-map.md; a tela, docs/design/hud-fluxo.md): o bairro
## alagado pintado, com cada lugar projetado pelo terminal da plataforma no estado dele (disponível, escolhido, concluído,
## bloqueado), a rota da Estação até o escolhido e, sobre cada lugar, os sinais do radar (AHNetworkRadar: o guardião, os
## inimigos, os suprimentos e a história). Clicar ou tocar no lugar escolhe a fase; à direita, o painel dela com a leitura
## do radar e PREPARAR NESTE LUGAR. O teclado e o controle andam pelos rótulos dos lugares (as setas) e escolhem com
## Interagir. A fase escolhida segue para a equipe na plataforma (#123).
class_name AHPhaseMap
extends Control

signal phase_chosen(phase_id: String)
signal closed

const J = preload("res://scripts/flow/journey_rules.gd")
const S = preload("res://scripts/flow/station_rules.gd")
const R = preload("res://scripts/flow/network_radar.gd")
const STREET = preload("res://scripts/street/street.gd")
const CONTRACT := "res://data/presentation/network_map.json"
const NETWORK := "res://art/ui/map/network/%s.webp"
## Onde a pintura (1120 x 630, sem escala) fica na tela, a moldura do mapa e o painel da fase.
const PAINT_POS := Vector2(60, 196)
const MAP_PANEL := Rect2(36, 130, 1164, 820)
const ASIDE := Rect2(1236, 130, 656, 820)
## Os sinais sobre cada lugar (o guardião, os inimigos, os suprimentos e a história).
const MARKS := ["boss", "enemies", "supplies", "story"]

var selected := ""
## O foco da rota escolhido na Preparação: troca uma porta da rua (o radar lê as casas com ele).
var focus := ""
var _regions: Array = []
var _layers: Control
var _labels: Control
var _aside: VBoxContainer
var _footer: VBoxContainer
var _header: Label
var _stock: HBoxContainer
var _readings := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var data = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	_regions = data.regions if data is Dictionary else []
	var back := ColorRect.new()
	back.color = AHKit.STEEL
	back.size = Vector2(1920, 1080)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	# No alto: a plaqueta com o nome e a linha da campanha.
	var plaque := AHKit.plaque()
	plaque.name = "Plaque"
	plaque.position = Vector2(28, 14)
	plaque.custom_minimum_size = Vector2(560, 92)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plaque)
	var plaque_row := HBoxContainer.new()
	plaque_row.add_theme_constant_override("separation", 14)
	plaque_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_child(plaque_row)
	var glyph := AHKit.glyph("route", 46, AHKit.TEXT)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plaque_row.add_child(glyph)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -4)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque_row.add_child(names)
	names.add_child(AHKit.label(tr("Mapa da Rede"), "panel_title", AHKit.TEXT, true, true))
	_header = AHKit.label("", "text", AHKit.MUTED)
	_header.name = "Header"
	names.add_child(_header)

	# O mapa: a chapa com LUGARES e a rede, a pintura com o sombreado do terminal, as camadas e os rótulos.
	var frame := AHKit.panel_box("large")
	frame.name = "MapPanel"
	frame.position = MAP_PANEL.position
	frame.custom_minimum_size = MAP_PANEL.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var head := HBoxContainer.new()
	head.position = Vector2(MAP_PANEL.position.x + 24, MAP_PANEL.position.y + 18)
	head.custom_minimum_size = Vector2(MAP_PANEL.size.x - 48, 0)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)
	var places := AHKit.label(tr("Lugares"), "text", AHKit.TEXT, true, true)
	places.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(places)
	head.add_child(AHKit.label(tr("Rede antiga · sinal com falhas"), "small", AHKit.MUTED))
	var art := TextureRect.new()
	art.name = "Painting"
	art.texture = load(NETWORK % "network_map")
	art.position = PAINT_POS
	art.size = Vector2(1120, 630)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	# O sombreado do terminal (62/255 de preto por cima da pintura, phase-map.md).
	var shade := ColorRect.new()
	shade.color = AHKit.SHADE
	shade.modulate.a = 62.0 / 255.0
	shade.position = PAINT_POS
	shade.size = Vector2(1120, 630)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_layers = Control.new()
	_layers.name = "Layers"
	_layers.position = PAINT_POS
	_layers.size = Vector2(1120, 630)
	_layers.mouse_filter = Control.MOUSE_FILTER_STOP
	_layers.gui_input.connect(_on_map_input)
	add_child(_layers)
	_labels = Control.new()
	_labels.name = "Labels"
	_labels.position = PAINT_POS
	_labels.size = Vector2(1120, 630)
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_labels)
	# Embaixo da pintura: a legenda e o estoque da Estação.
	var legend := HBoxContainer.new()
	legend.name = "Legend"
	legend.position = Vector2(PAINT_POS.x, PAINT_POS.y + 642)
	legend.add_theme_constant_override("separation", 20)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(legend)
	for spec in [["state_active", AHKit.good(), tr("Concluída")], ["marker-here", AHKit.AMBER, tr("Escolhida")],
			["node-start", AHKit.hero_hp(), tr("Disponível")], ["lock", AHKit.MUTED, tr("Bloqueada")], ["?", AHKit.TEXT, tr("Não lido")]]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 6)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(_mark_icon(spec[0], 22, spec[1]) if spec[0] != "?" else AHKit.label("?", "text", AHKit.TEXT, true))
		item.add_child(AHKit.label(spec[2], "small", AHKit.TEXT))
		legend.add_child(item)
	_stock = HBoxContainer.new()
	_stock.name = "Stock"
	_stock.position = Vector2(PAINT_POS.x, PAINT_POS.y + 680)
	_stock.add_theme_constant_override("separation", 10)
	_stock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stock)

	# À direita: o painel da fase escolhida (ou a lista dos lugares).
	var aside_panel := AHKit.panel_box("large")
	aside_panel.name = "Aside"
	aside_panel.position = ASIDE.position
	aside_panel.custom_minimum_size = ASIDE.size
	aside_panel.size = ASIDE.size
	add_child(aside_panel)
	var aside_column := VBoxContainer.new()
	aside_column.add_theme_constant_override("separation", 12)
	aside_panel.add_child(aside_column)
	# O conteúdo rola (o Maior não cabe inteiro); PREPARAR NESTE LUGAR fica fixo no pé.
	var scroll := ScrollContainer.new()
	scroll.name = "AsideScroll"
	# A rolagem acompanha o foco do teclado e do controle (#5).
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(ASIDE.size.x - 48, 0)
	aside_column.add_child(scroll)
	_aside = VBoxContainer.new()
	_aside.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aside.add_theme_constant_override("separation", 10)
	scroll.add_child(_aside)
	_footer = VBoxContainer.new()
	_footer.name = "Footer"
	aside_column.add_child(_footer)
	aside_column.custom_minimum_size = Vector2(0, ASIDE.size.y - 48)

	# Embaixo: VOLTAR À ESTAÇÃO e a barra das teclas.
	var back_button := AHStationFrame.back_button(self, func(): closed.emit())
	back_button.name = "Close"
	back_button.text = tr("Voltar à Estação").to_upper()
	back_button.position = Vector2(28, 990)
	# A tecla de voltar dentro do botão (o Esc fixo, como na Estação).
	var back_key := AHKitKey.make("", "Esc / B", "button")
	back_key.name = "Key"
	back_button.add_child(back_key)
	# Largo o bastante para o texto centrado não chegar à tecla (a seta do VOLTAR acompanha o centro).
	back_button.custom_minimum_size.x = 470
	back_button.resized.connect(func():
		back_key.reset_size()
		back_key.position = Vector2(back_button.size.x - back_key.size.x - 18.0, (back_button.size.y - back_key.size.y) * 0.5))
	AHStationFrame.keys(self, [[tr("Setas"), tr("Lugar")], ["interact", tr("Escolher")]], 700.0, 420.0, 1200.0).position.y = 1000


func _ready() -> void:
	_cover()


## A tela inteira (1920 x 1080), qualquer que seja o pai (o HUD da Estação é um Control sem tamanho): cobre a Estação e
## segura os cliques.
func _cover() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	global_position = Vector2.ZERO
	size = get_viewport_rect().size


## Abre na fase dada (a do rascunho da Preparação) ou na Estação.
func open(phase_id: String = "", route_focus: String = "") -> void:
	AHUiStyle.reset_focus(self)
	_cover()
	selected = phase_id
	focus = route_focus
	visible = true
	refresh()
	# A leitura fixou as sementes das fases (AHNetworkRadar.route_seed): a partida usa as mesmas.
	Campaign.save()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if AHUiStyle.is_back(event):
		get_viewport().set_input_as_handled()
		closed.emit()
	elif event.is_action_pressed("station_prepare"):
		# G / X, como diz o botão: com uma fase aberta escolhida, segue para a plataforma.
		get_viewport().set_input_as_handled()
		var go: Button = _footer.get_node_or_null("Prepare")
		if go != null and not go.disabled:
			go.pressed.emit()


func refresh() -> void:
	var c: Dictionary = Campaign.state
	var completed := J.PHASES.filter(func(p): return c.completed_phases.has(p.id)).size()
	var living := S.living(c).size()
	_header.text = tr("Bairro Submerso · Fases concluídas %d / %d · Equipe: %d %s") % [completed, J.PHASES.size(), living, tr("vivo") if living == 1 else tr("vivos")]
	_readings = {}
	for info in J.PHASES:
		_readings[info.id] = R.reading(c, info.id, focus if info.id == selected else "")
	_build_stock(c)
	_build_layers(c)
	_build_labels(c)
	_build_aside(c)


## O tamanho do texto mudou nas Opções (AHUiStyle.retune).
func restyle() -> void:
	if visible:
		refresh()


## A região de cada fase (e a da Estação, phase_id null) no contrato.
func region_of(phase_id: String) -> Dictionary:
	for region in _regions:
		if String(region.phase_id if region.phase_id != null else "") == phase_id:
			return region
	return {}


func _state(c: Dictionary, phase_id: String) -> String:
	# A Estação é o ponto de partida: nunca "escolhida" (sem fase escolhida, nada fica em âmbar).
	if phase_id == "":
		return "available"
	if phase_id == selected:
		return "selected"
	if c.completed_phases.has(phase_id):
		return "completed"
	return "available" if S.phase_unlocked(c, phase_id) else "locked"


## A cor de cada estado na projeção (as camadas são brancas com alfa, para tingir; phase-map.md).
static func state_color(state: String) -> Color:
	match state:
		"selected":
			return AHKit.AMBER
		"completed":
			return AHKit.good()
		"locked":
			return AHKit.MUTED
	return AHKit.hero_hp()


## As projeções de cada lugar, a rota até o escolhido (a que falta, em claro com contorno) e as já feitas (em âmbar).
func _build_layers(c: Dictionary) -> void:
	for child in _layers.get_children():
		_layers.remove_child(child)
		child.queue_free()
	for region in _regions:
		var phase_id: String = region.phase_id if region.phase_id != null else ""
		if phase_id == "" and selected != "":
			continue
		var state := _state(c, phase_id)
		var spec: Dictionary = region.states[state]
		var layer := TextureRect.new()
		layer.name = "Area_%s" % region.key
		layer.texture = load("res://" + String(spec.file))
		layer.position = Vector2(spec.origin[0], spec.origin[1])
		layer.size = Vector2(spec.size[0], spec.size[1])
		layer.modulate = state_color(state)
		layer.modulate.a = 0.85 if state == "selected" else 0.6
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layers.add_child(layer)
	for region in _regions:
		if region.phase_id == null:
			continue
		var route_key: String = region.key
		var traversed: bool = c.completed_phases.has(region.phase_id)
		if traversed:
			_layers.add_child(_route(NETWORK % ("route_%s_traversed" % route_key), AHKit.AMBER))
		if region.phase_id == selected and not traversed:
			_layers.add_child(_route(NETWORK % ("route_%s_remaining_kit" % route_key), Color.WHITE))


func _route(path: String, tint: Color) -> TextureRect:
	var route := TextureRect.new()
	route.name = "Route"
	route.texture = load(path)
	route.size = Vector2(1120, 630)
	route.modulate = tint
	route.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return route


## Os rótulos dos lugares (botões: o mouse, o toque, o teclado e o controle) e, sobre cada fase, os sinais do radar.
func _build_labels(c: Dictionary) -> void:
	for child in _labels.get_children():
		_labels.remove_child(child)
		child.queue_free()
	var buttons: Array = []
	for region in _regions:
		var phase_id: String = region.phase_id if region.phase_id != null else ""
		var anchor := Vector2(region.anchor[0], region.anchor[1])
		var state := _state(c, phase_id)
		var number := J.PHASES.map(func(p): return p.id).find(phase_id) + 1
		var button := Button.new()
		button.name = "Place_%s" % (phase_id if phase_id != "" else "refuge")
		AHKit.style_as(button, "list")
		button.text = tr("Estação Raiz") if phase_id == "" else tr("Fase %d") % number
		button.icon = _icon_texture({"completed": "state_active", "selected": "marker-here", "available": "node-start", "locked": "lock"}[state])
		button.add_theme_constant_override("icon_max_width", 22)
		button.add_theme_constant_override("h_separation", 8)
		button.add_theme_font_override("font", AHKit.font(true))
		button.add_theme_font_size_override("font_size", AHKit.size("text"))
		for color in ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color"]:
			button.add_theme_color_override(color, state_color(state) if state != "available" else AHKit.hero_hp())
		button.add_theme_color_override("font_color", AHKit.MUTED if state == "locked" else AHKit.TEXT)
		if state == "selected":
			button.add_child(AHKit.selected_overlay())
		button.tooltip_text = tr(region.name)
		button.pressed.connect(_select.bind(phase_id))
		_labels.add_child(button)
		button.reset_size()
		button.size = Vector2(maxf(150.0, button.get_combined_minimum_size().x), maxf(48.0, button.get_combined_minimum_size().y))
		button.position = anchor + Vector2(-button.size.x * 0.5, 48 - 24)
		buttons.append(button)
		if phase_id != "":
			var marks := _marks(_readings[phase_id])
			_labels.add_child(marks)
			marks.reset_size()
			marks.size = marks.get_combined_minimum_size()
			marks.position = anchor + Vector2(-marks.size.x * 0.5, 48 - 24 - marks.size.y - 6)
	# As setas andam pelos lugares na ordem da rede (a Estação e as fases, em volta): ↓ e → para o próximo, ↑ e ← para o
	# de antes. Interagir escolhe o lugar; com ele escolhido, o foco vai para PREPARAR NESTE LUGAR.
	for i in buttons.size():
		var button: Button = buttons[i]
		button.focus_mode = Control.FOCUS_ALL
		var next: NodePath = buttons[(i + 1) % buttons.size()].get_path()
		var previous: NodePath = buttons[(i - 1 + buttons.size()) % buttons.size()].get_path()
		button.focus_neighbor_bottom = next
		button.focus_neighbor_right = next
		button.focus_next = next
		button.focus_neighbor_top = previous
		button.focus_neighbor_left = previous
		button.focus_previous = previous
	var focus_on: Button = _labels.get_node_or_null("Place_%s" % (selected if selected != "" else "refuge"))
	if focus_on != null and AHUiStyle.using_keys:
		AHKit.focus_later(focus_on)


## Os sinais de uma fase, numa chapinha: o guardião, os inimigos, os suprimentos e a história, cada um no estado da leitura
## (o rosto quando conhecido; a pergunta, com ou sem interrupção, quando não).
func _marks(read: Dictionary) -> PanelContainer:
	var chip := AHKit.chip("cost")
	chip.name = "Signals"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	for part in MARKS:
		row.add_child(_signal(part, read[part], 34))
	return chip


## Um sinal: o rosto do guardião ou do inimigo mais comum (conhecido), o marcador da leitura (não lido, parcial, conhecido
## ou, na história, a ausência conhecida).
static func _signal(part: String, entry: Dictionary, side: float) -> Control:
	var state: String = entry.state
	if state == "known" and (part == "boss" or part == "enemies"):
		var enemy_id: String = entry.id if part == "boss" else (entry.ids[0] if not entry.ids.is_empty() else "")
		var face := portrait_of(enemy_id)
		if face != null:
			var rect := TextureRect.new()
			rect.texture = face
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.custom_minimum_size = Vector2(side, side)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return rect
	var file := "marker_%s_%s" % [part, state]
	if part == "story" and state == "known" and not entry.has:
		file = "marker_story_none"
	var mark := TextureRect.new()
	mark.texture = load(NETWORK % file)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(side, side)
	mark.modulate = AHKit.TEXT if state != "unknown" else AHKit.MUTED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return mark


## O rosto do inimigo no mapa (os recortes da #86) ou, sem um, o da arte de luta.
static func portrait_of(enemy_id: String) -> Texture2D:
	var row = GameData.row("enemies", enemy_id)
	var key: String = String(row.get("SpriteKey", enemy_id)) if row != null else enemy_id
	var path := NETWORK % ("portrait_" + key)
	if ResourceLoader.exists(path):
		return load(path)
	var art: Dictionary = AHCombatArena.enemy_art_of(key).get("idle", {})
	return AHUiStyle.face_texture(art) if not art.is_empty() else null


static func _icon_texture(name: String) -> Texture2D:
	if name == "lock":
		return load(NETWORK % "lock_32")
	return AHKit.legacy_icon(name)


static func _mark_icon(name: String, side: float, tint: Color) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = _icon_texture(name)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(side, side)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## O clique ou o toque no próprio lugar escolhe a fase (o polígono do contrato, em pixels da pintura).
func _on_map_input(event: InputEvent) -> void:
	# O clique que a Godot cria do toque não conta duas vezes (o toque já escolheu).
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var press: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not press:
		return
	var id = phase_at(event.position)
	if id != null:
		_layers.accept_event()
		_select(id)


## A fase do lugar no ponto da pintura ("" a Estação, null fora dos lugares).
func phase_at(point: Vector2):
	for region in _regions:
		if Geometry2D.is_point_in_polygon(point, PackedVector2Array(region.hit_polygon.map(func(p): return Vector2(p[0], p[1])))):
			return region.phase_id if region.phase_id != null else ""
	return null


func _select(id: String) -> void:
	selected = id
	Sound.play("res://audio/ui/click.ogg", 0.5)
	refresh()


func _build_stock(c: Dictionary) -> void:
	for child in _stock.get_children():
		child.queue_free()
	_stock.add_child(AHKit.label(tr("Estoque da Estação"), "small", AHKit.MUTED))
	for spec in [["lobby-seed", "seeds"], ["lobby-scrap", "scrap"], ["lobby-fragment", "fragments"]]:
		var chip := AHKit.chip("cost")
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		chip.add_child(row)
		row.add_child(_mark_icon(spec[0], 20, AHKit.TEXT))
		row.add_child(AHKit.label(str(S.quantity(c, spec[1])), "small", AHKit.TEXT, true))
		_stock.add_child(chip)


# ---------------------------------------------------------------- painel

## O painel da fase escolhida (ou da Estação, com a lista dos lugares).
func _build_aside(c: Dictionary) -> void:
	for box in [_aside, _footer]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	var info := J.phase(selected) if selected != "" else {}
	var width := ASIDE.size.x - 64
	if info.is_empty():
		_aside_head("node-start", tr("Estação Raiz"), false)
		_aside.add_child(_wrap(tr("A comunidade mantém trilhos, oficinas e cuidado com ferramentas herdadas. Escolha um lugar no mapa para partir com a equipe."), "text", AHKit.TEXT, width))
		_aside.add_child(_wrap(tr("O terminal da plataforma capta, com falhas, os sinais da rede antiga de vigilância em cada lugar. A Pesquisa, o Depósito melhorado e a Forja melhoram a leitura."), "small", AHKit.MUTED, width))
		_aside.add_child(AHKit.label(tr("Lugares"), "text", AHKit.AMBER, true, true))
		for i in J.PHASES.size():
			var phase: Dictionary = J.PHASES[i]
			var row := AHKit.button("", "secondary")
			row.name = "List_%s" % phase.id
			AHKit.style_as(row, "list", Vector4(16, 0, 16, 0))
			row.alignment = HORIZONTAL_ALIGNMENT_LEFT
			row.text = tr("Fase %d · %s · %s") % [i + 1, tr(phase.name), _status(c, phase.id)]
			row.add_theme_font_size_override("font_size", AHKit.size("text"))
			row.add_theme_color_override("font_color", AHKit.TEXT if S.phase_unlocked(c, phase.id) else AHKit.MUTED)
			row.custom_minimum_size = Vector2(0, 52)
			row.pressed.connect(_select.bind(phase.id))
			_aside.add_child(row)
		return
	var number := J.PHASES.map(func(p): return p.id).find(info.id) + 1
	var done: bool = c.completed_phases.has(info.id)
	var open: bool = S.phase_unlocked(c, info.id)
	_aside_head("alert" if not open else "marker-here", tr(info.name), true)
	_aside.add_child(AHKit.label(tr("Fase %d · Dificuldade: %s") % [number, tr(J.DIFFICULTY_NAMES[info.difficulty])], "small", AHKit.MUTED, true, true))
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 8)
	_aside.add_child(status)
	var state := "completed" if done else ("available" if open else "locked")
	status.add_child(_mark_icon({"completed": "state_active", "available": "node-start", "locked": "lock"}[state], 22, state_color(state) if state != "available" else AHKit.hero_hp()))
	status.add_child(AHKit.label(tr("Concluída · dá para jogar de novo") if done else (tr("Disponível") if open else tr("Bloqueada · vença a fase anterior")),
		"small", state_color(state) if state != "available" else AHKit.hero_hp(), true))
	# A descrição conta a camada da história da fase (#64): bloqueada, ainda não (narrative-design §14.2).
	_aside.add_child(_wrap(tr(info.description) if open else tr("O que há lá, a equipe só descobre quando chegar."), "small", AHKit.TEXT if open else AHKit.MUTED, width))
	var level := AHKit.chip("cost")
	level.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 6)
	level.add_child(level_row)
	level_row.add_child(_mark_icon("state_active", 18, AHKit.TEXT))
	level_row.add_child(AHKit.label(tr("Nível recomendado %d") % info.level, "small", AHKit.TEXT))
	_aside.add_child(level)
	# O radar: o título com o nível da leitura e uma linha por sinal.
	var read: Dictionary = _readings[info.id]
	var overall := R.overall(read)
	var level_text := tr("leitura completa") if overall == "known" else (tr("leitura parcial") if overall == "partial" else tr("sem leitura"))
	_aside.add_child(AHKit.label(tr("Mapa da Rede: %s") % level_text, "small", AHKit.TEXT, true))
	var radar := VBoxContainer.new()
	radar.name = "Radar"
	radar.add_theme_constant_override("separation", 6)
	_aside.add_child(radar)
	for part in R.PARTS:
		radar.add_child(radar_row(part, read[part], width))
	# PREPARAR NESTE LUGAR (G / X): o botão principal; bloqueado, com o motivo dentro.
	var go := AHStationReport._primary(tr("Preparar neste lugar"), "station", "station_prepare")
	go.name = "Prepare"
	go.custom_minimum_size = Vector2(0, 64)
	go.add_theme_font_size_override("font_size", AHKit.size("row"))
	go.get_node("Key").set_meta("ah_action", "station_prepare")
	go.get_node("Key").set_meta("ah_format", tr("%s / X"))
	(go.get_node("Key").get_child(0) as Label).text = tr("%s / X") % AHUiStyle.key_name("station_prepare")
	# A tecla no fim do botão, e o texto terminando antes dela.
	var key: Control = go.get_node("Key")
	var room: float = key.get_combined_minimum_size().x + 70.0
	var seen: Array = []
	for look in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		var style: StyleBox = go.get_theme_stylebox(look) if go.has_theme_stylebox_override(look) else null
		if style != null and not seen.has(style):
			seen.append(style)
			style.content_margin_right = room
	go.resized.connect(func():
		key.reset_size()
		key.position = Vector2(go.size.x - key.size.x - 52.0, (go.size.y - key.size.y) * 0.5))
	go.disabled = not open
	if not open:
		go.tooltip_text = tr("Bloqueada · vença a fase anterior")
	var id: String = info.id
	go.pressed.connect(func(): phase_chosen.emit(id))
	_footer.add_child(go)
	# Do botão, as setas voltam ao lugar escolhido no mapa.
	var place: Button = _labels.get_node_or_null("Place_%s" % info.id)
	if place != null:
		for side in ["focus_neighbor_top", "focus_neighbor_bottom", "focus_neighbor_left", "focus_neighbor_right"]:
			go.set(side, place.get_path())
	if open and AHUiStyle.using_keys:
		AHKit.focus_later(go)


func _aside_head(icon_name: String, title: String, closable: bool) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_aside.add_child(head)
	head.add_child(_mark_icon(icon_name, 34, AHKit.alert_text() if icon_name == "alert" else AHKit.AMBER))
	var name_label := AHKit.label(title, "panel_title", AHKit.TEXT, true, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(name_label)
	if closable:
		# O X tira a escolha (volta aos Lugares); o teclado e o controle fazem isso pela lista.
		var close := AHKit.button("X", "icon")
		close.name = "Deselect"
		close.custom_minimum_size = Vector2(52, 52)
		close.focus_mode = Control.FOCUS_NONE
		close.pressed.connect(_select.bind(""))
		head.add_child(close)


## Uma linha do radar (também na faixa da partida, #123): o marcador no estado da leitura, a parte em caixa alta e o que o terminal captou.
static func radar_row(part: String, entry: Dictionary, width: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Read_%s" % part
	row.add_theme_constant_override("separation", 12)
	if part == "weather":
		# O clima não tem marcador próprio: conhecido, o ícone da noite ou o do descanso; senão, a pergunta da leitura.
		if entry.state == "known":
			row.add_child(_mark_icon("sleep" if String(entry.id).begins_with("night") else "node-rest", 34, AHKit.TEXT))
		else:
			row.add_child(_signal("story", {"state": entry.state, "has": true}, 34))
	else:
		row.add_child(_signal(part, entry, 34))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", -2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	column.add_child(AHKit.label(part_name(part), "small", AHKit.MUTED, true, true))
	var value := AHKit.label(radar_text(part, entry), "text", AHKit.TEXT if entry.state == "known" else AHKit.MUTED)
	value.name = "Value"
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.custom_minimum_size = Vector2(width - 60, 0)
	column.add_child(value)
	return row


## O nome de cada parte da leitura.
static func part_name(part: String) -> String:
	match part:
		"boss":
			return TranslationServer.translate("Chefe")
		"enemies":
			return TranslationServer.translate("Inimigos")
		"supplies":
			return TranslationServer.translate("Suprimentos")
		"story":
			return TranslationServer.translate("História")
	return TranslationServer.translate("Clima")


## O que o terminal diz de uma parte: leitura e não profecia (ícones e poucas palavras; o número só onde ajuda a decidir).
static func radar_text(part: String, entry: Dictionary) -> String:
	if entry.state == "unknown":
		return TranslationServer.translate("Não lido")
	var partial: bool = entry.state == "partial"
	match part:
		"boss":
			if partial:
				return TranslationServer.translate("Um sinal grande, sem identificação")
			return _enemy_name(entry.id)
		"enemies":
			if partial:
				return TranslationServer.translate("Sinais de máquinas") if _machines(entry.ids) else TranslationServer.translate("Sinais vivos, sem identificação")
			var names: Array = entry.ids.slice(0, 2).map(func(id): return _enemy_name(id))
			return " · ".join(names)
		"supplies":
			if partial:
				return TranslationServer.translate("Sinal parcial")
			if entry.amount == "many":
				return TranslationServer.translate("Muitos pontos de busca (%d)") % entry.points
			if entry.amount == "some":
				return TranslationServer.translate("Alguns pontos de busca (%d)") % entry.points
			return TranslationServer.translate("Poucos pontos de busca (%d)") % entry.points
		"story":
			if partial:
				return TranslationServer.translate("Interferência no rádio")
			return TranslationServer.translate("Algo fala no rádio") if entry.has else TranslationServer.translate("Nada a ler")
		"weather":
			if partial:
				return TranslationServer.translate("Sinal parcial")
			var weather := TranslationServer.translate(String(STREET.WEATHER_NAMES.get(entry.id, entry.id)))
			return weather.left(1).to_upper() + weather.substr(1)
	return ""


static func _enemy_name(enemy_id: String) -> String:
	var row = GameData.row("enemies", enemy_id)
	return AHCombatHud.unit_name(TranslationServer.translate(String(row.DisplayName))) if row != null else enemy_id


static func _machines(ids: Array) -> bool:
	var machines := ids.filter(func(id):
		var row = GameData.row("enemies", id)
		return row != null and String(row.get("Category", "")) == "Machine")
	return machines.size() * 2 >= ids.size()


func _status(c: Dictionary, phase_id: String) -> String:
	return tr("Concluída") if c.completed_phases.has(phase_id) else (tr("Disponível") if S.phase_unlocked(c, phase_id) else tr("Bloqueada"))


func _wrap(text: String, role: String, color: Color, width: float) -> Label:
	var label := AHKit.label(text, role, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	return label
