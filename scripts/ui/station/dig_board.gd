## Escavar e construir (#284, o pedido do Lucas de 01/11: a planta como a tela de construir da base; a aba Escavação):
## os três subsolos em corte, uma linha de cartões por andar (as sete vagas e o patamar), cada cartão com a moldura, a
## imagem do que está ali, o nome e o estado. O bloco que dá para escavar mostra a ação e a recompensa; o que depende do vizinho, a moldura e o
## aviso em vermelho. Embaixo, o bloco escolhido, quem orienta e o botão grande (escavar, construir, abrir o cômodo).
## As regras ficam no AHStationGrid; os nomes e as imagens (um recorte das peças de art/scenarios até a arte da #275), em
## data/station-grid.json (block_looks).
class_name AHDigBoard
extends Control

## Entre a barra do alto e as teclas de baixo (a moldura da Estação fica: os recursos, as abas e VOLTAR).
const PANEL := Rect2(28, 104, 1864, 808)
const LABEL_WIDTH := 132.0
const CARD := Vector2(196, 172)
const GAP := 6.0
const ART_HEIGHT := 56.0
const SCENARIOS := "res://art/scenarios/%s.webp"

## As imagens já carregadas (abrir a planta de novo não decodifica as peças outra vez).
static var _textures := {}

## O HUD da Estação (as ações passam por ele: _act, open_room, close_panel).
var hud: Control
## O bloco escolhido ("1:3", "L2") ou o cômodo ("room:forge").
var selected := ""
var _first_focus: Control


static func make(owner: Control, key: String = "") -> AHDigBoard:
	var board := AHDigBoard.new()
	board.name = "DigBoard"
	board.hud = owner
	board.selected = key
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return board


func _ready() -> void:
	rebuild()


## O que cada bloco mostra: {Name, Art, Ground} (data/station-grid.json, block_looks).
static func look(key: String) -> Dictionary:
	var blocks: Dictionary = AHStationGrid.rule("block_looks").get("Blocks", {})
	return blocks.get(key, {})


## A fala do Nick na primeira escavação (data/station-grid.json, intro), a de quem orienta.
static func guide_line() -> String:
	for line in AHStationGrid.rule("intro").get("Lines", []):
		if String(line.get("Speaker", "")) == AHStationGrid.NICK:
			return String(line.get("Text", ""))
	return ""


## O nome do que está no bloco ("Bilheteria desabada"); sem a linha, o nome do lugar.
static func block_label(key: String) -> String:
	var name := String(look(key).get("Name", ""))
	return TranslationServer.translate(name) if name != "" else AHRefugeHud.block_title(key)


## O que o cartão diz: {state, tag, action, reward, alert}. state: "room", "free", "front", "dig" ou "buried".
static func card_info(c: Dictionary, key: String) -> Dictionary:
	var info := AHRefugeHud.block_info(c, key)
	var out := {"state": info.state, "tag": "", "action": "", "reward": "", "alert": ""}
	var least := AHStationGrid.finds_text({"scrap": int(AHStationGrid.block_rule(key).get("Scrap", 0)),
		"fragments": int(AHStationGrid.block_rule(key).get("Fragments", 0))})
	# No cartão, curta; a frase inteira ("às vezes um achado", como no painel do bloco) fica no escolhido.
	var reward := TranslationServer.translate("Rende %s") % least if least != "" else ""
	match String(info.state):
		"free":
			out.tag = TranslationServer.translate("Vaga livre")
			out.action = String(info.mark)
		"front":
			out.tag = TranslationServer.translate("(ESCAVANDO)")
			out.action = TranslationServer.translate("%d de %d · %s") % [AHStationGrid.block_progress(c, key),
				AHStationGrid.block_work(key), AHStationGrid.returns_text(AHStationGrid.returns_left(c, key))]
			out.reward = reward
		"dig":
			out.tag = TranslationServer.translate("(BLOQUEADO)")
			out.action = TranslationServer.translate("Escavar · %s") % AHStationGrid.returns_text(AHStationGrid.returns_left(c, key))
			out.reward = reward
		_:
			out.tag = TranslationServer.translate("(BLOQUEADO)")
			# No cartão, curto; o motivo inteiro fica embaixo, no escolhido.
			out.alert = TranslationServer.translate("Depende da escada") if neighbor_reason(c, key) != TranslationServer.translate("Escave o bloco vizinho para liberar") \
				else TranslationServer.translate("Depende do vizinho")
	return out


## O aviso em vermelho do bloco que ainda não dá para escavar: o vizinho ou o patamar.
static func neighbor_reason(c: Dictionary, key: String) -> String:
	var f := AHStationGrid.block_floor(key)
	var landing := "L%d" % (f - 1 if AHStationGrid.is_landing(key) else f)
	if f > 1 and not AHStationGrid.block_open(c, landing):
		return TranslationServer.translate("Escave a escada acima para liberar") if AHStationGrid.is_landing(key) \
			else TranslationServer.translate("Escave a escada deste andar para liberar")
	return TranslationServer.translate("Escave o bloco vizinho para liberar")


func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_first_focus = null
	var c: Dictionary = Campaign.state
	if selected == "" or not _valid(c, selected):
		selected = AHStationGrid.dig_target(c)
	var veil := AHKit.veil()
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	var panel := AHKit.panel_box("large")
	panel.name = "Board"
	panel.position = PANEL.position
	panel.size = PANEL.size
	panel.custom_minimum_size = PANEL.size
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	_head(c, column)
	var scroll := ScrollContainer.new()
	scroll.name = "Grid"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var floors := VBoxContainer.new()
	floors.add_theme_constant_override("separation", GAP)
	scroll.add_child(floors)
	for floor_number in range(1, AHStationGrid.FLOORS + 1):
		floors.add_child(_floor_row(c, floor_number))
	_bottom(c, column)
	if _first_focus != null and AHUiStyle.using_keys:
		AHKit.focus_later(_first_focus)


func _valid(c: Dictionary, key: String) -> bool:
	if key.begins_with("room:"):
		return AHStationGrid.placed(c, key.trim_prefix("room:"))
	# O patamar aberto vira só a passagem (sem cartão para escolher).
	return AHStationGrid.block_keys().has(key) and not (AHStationGrid.is_landing(key) and AHStationGrid.block_open(c, key))


## O alto: o título, o ritmo da escavação e quem orienta (o Nick, com a fala da primeira escavação).
func _head(c: Dictionary, column: VBoxContainer) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	column.add_child(head)
	head.add_child(AHKit.glyph("place_unlocked", 40, AHKit.AMBER))
	head.add_child(AHKit.label(tr("Escavar e construir"), "panel_title", AHKit.TEXT, true, true))
	var rate := AHStationGrid.dig_rate(c)
	var pace := AHKit.label(tr("A comunidade cava 1 ponto por dia.") if rate == 1
		else tr("A comunidade e o escavador cavam %d pontos por dia.") % rate, "small", AHKit.MUTED)
	# Só os dias de expedição cavam (#186): a ressalva fica ao lado do ritmo (#284).
	pace.text += " " + tr("Esperar um dia na Estação não cava.")
	pace.name = "Pace"
	pace.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pace.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(pace)
	var guide = AHStationRules.hero(c, AHStationGrid.NICK)
	if guide != null and guide.get("alive", true):
		var face := AHKit.portrait(AHUiStyle.face_texture(AHCombatArena.hero_art_of(String(guide.id), String(guide.get("art_variant", ""))).get("idle", {})), 56)
		face.name = "Guide"
		head.add_child(face)
		var line := AHKit.label(tr(guide_line()), "text", AHKit.TEXT)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(640, 0)
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(line)


## Um andar: o nome à esquerda e os cartões das sete vagas e do patamar (o cômodo duplo ocupa as duas).
func _floor_row(c: Dictionary, floor_number: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Floor_%d" % floor_number
	row.add_theme_constant_override("separation", GAP)
	var tag := AHKit.label(AHStationGrid.floor_name(floor_number), "row", AHKit.AMBER, true, true)
	tag.custom_minimum_size = Vector2(LABEL_WIDTH, CARD.y)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(tag)
	var slot := 1
	while slot <= AHStationGrid.SLOTS:
		var content := AHStationGrid.cell(c, floor_number, slot)
		if content != "" and content != AHStationGrid.FREE:
			var span := 1
			while slot + span <= AHStationGrid.SLOTS and AHStationGrid.cell(c, floor_number, slot + span) == content:
				span += 1
			row.add_child(_room_card(content, span))
			slot += span
			continue
		row.add_child(_block_card(c, "%d:%d" % [floor_number, slot]))
		slot += 1
	if floor_number > 1:
		var landing := "L%d" % floor_number
		row.add_child(_block_card(c, landing) if not AHStationGrid.block_open(c, landing) else _stairs_card(floor_number))
	else:
		row.add_child(_stairs_card(floor_number))
	return row


## O cartão de um bloco soterrado ou de uma vaga livre.
func _block_card(c: Dictionary, key: String) -> Button:
	var info := card_info(c, key)
	var card := _card_button("Block_%s" % key.replace(":", "_"), key, CARD.x)
	var box := _card_box(card)
	var looks := look(key)
	var buried: bool = info.state != "free"
	box.add_child(_art(String(looks.get("Art", "")), String(looks.get("Ground", "")), info.state))
	var name := AHKit.label(block_label(key) if buried else AHRefugeHud.block_title(key), "small", AHKit.TEXT, true)
	name.name = "Name"
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.max_lines_visible = 2
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.custom_minimum_size = Vector2(CARD.x - 28.0, 0)
	box.add_child(name)
	# O aviso vermelho, cortado no Maior, vai inteiro na dica.
	card.tooltip_text = name.text if String(info.alert) == "" else name.text + "\n" + neighbor_reason(c, key)
	var tone: Color = AHKit.AMBER if info.state == "front" else (AHKit.good() if info.state in ["free", "dig"] else AHKit.MUTED)
	var tag := AHKit.label(String(info.tag), "small", tone, true, true)
	tag.name = "Tag"
	box.add_child(tag)
	for part in [["Action", info.action, AHKit.AMBER if info.state == "front" else AHKit.TEXT], ["Reward", info.reward, AHKit.MUTED],
			["Alert", info.alert, AHKit.alert_text()]]:
		if String(part[1]) == "":
			continue
		# Uma linha cada (os três andares cabem no Normal); a frase inteira fica embaixo, no escolhido.
		var line := AHKit.label(String(part[1]), "small", part[2])
		line.name = part[0]
		line.clip_text = true
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.custom_minimum_size = Vector2(CARD.x - 28.0, 0)
		box.add_child(line)
	# A moldura do estado: vermelha no que depende do vizinho, âmbar na frente, clara no que dá para escavar.
	var edge: Color = {"buried": AHKit.alert_text(), "front": AHKit.AMBER, "dig": AHKit.good(), "free": AHKit.good()}.get(info.state, AHKit.MUTED)
	_frame(card, edge, 3 if info.state in ["buried", "front"] else 2)
	card.set_meta("state", info.state)
	_grow(card, box)
	return card


## O cartão de um cômodo construído: o ícone e o nome (abre o cômodo).
func _room_card(room_id: String, span: int) -> Button:
	var width := CARD.x * span + GAP * (span - 1)
	var card := _card_button("Room_%s" % room_id, "room:" + room_id, width)
	var box := _card_box(card)
	var icon := AHKit.glyph(AHRefugeHud.ROOM_ICONS.get(room_id, "station"), ART_HEIGHT - 20.0, AHKit.TEXT)
	icon.custom_minimum_size = Vector2(width - 28.0, ART_HEIGHT)
	box.add_child(icon)
	var name := AHKit.label(tr(AHStationRules.room_def(room_id).name), "small", AHKit.TEXT, true, true)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.custom_minimum_size = Vector2(width - 28.0, 0)
	box.add_child(name)
	box.add_child(AHKit.label(tr("Construído"), "small", AHKit.good(), true))
	card.set_meta("state", "room")
	_grow(card, box)
	return card


## A escada aberta: só a passagem, sem ação.
func _stairs_card(floor_number: int) -> Control:
	var box := AHKit.panel_box("inset")
	box.name = "Stairs_%d" % floor_number
	box.custom_minimum_size = CARD
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(words)
	words.add_child(AHKit.glyph("station", 48, AHKit.MUTED))
	var text := AHKit.label(tr("Escada") if floor_number == 1 else tr("Patamar aberto"), "small", AHKit.MUTED, true, true)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(text)
	return box


func _card_button(node_name: String, key: String, width: float) -> Button:
	var card := Button.new()
	card.name = node_name
	AHKit.style_as(card, "upgrade_selected" if key == selected else "upgrade")
	card.custom_minimum_size = Vector2(width, CARD.y)
	card.clip_contents = true
	card.set_meta("key", key)
	card.pressed.connect(func():
		# O escolhido apertado de novo (Interagir no teclado e no controle) aciona o botão grande.
		if key == selected:
			var big := find_child("BigAction", true, false) as Button
			if big != null and not big.disabled:
				big.pressed.emit()
				return
		selected = key
		rebuild()
		var again := find_child(node_name, true, false) as Control
		if again != null:
			AHKit.focus_later(again))
	if key == selected:
		card.add_child(AHKit.selected_overlay())
		_first_focus = card
	return card


func _card_box(card: Button) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 14
	box.offset_top = 12
	box.offset_right = -14
	box.offset_bottom = -12
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	return box


## A imagem do bloco: o fundo recortado e a peça por cima, mais escura no que ainda não dá para escavar.
func _art(art: String, ground: String, state: String) -> Control:
	var holder := Control.new()
	holder.name = "Art"
	holder.custom_minimum_size = Vector2(CARD.x - 28.0, ART_HEIGHT)
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for spec in [[ground, TextureRect.STRETCH_KEEP_ASPECT_COVERED], [art, TextureRect.STRETCH_KEEP_ASPECT_CENTERED]]:
		if String(spec[0]) == "" or not ResourceLoader.exists(SCENARIOS % spec[0]):
			continue
		var rect := TextureRect.new()
		rect.texture = texture_of(String(spec[0]))
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = spec[1]
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		if spec[1] == TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
			rect.offset_left = 6
			rect.offset_top = 6
			rect.offset_right = -6
			rect.offset_bottom = -4
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(rect)
	if state == "free":
		holder.modulate = AHKit.DIM
	elif state == "buried":
		holder.modulate = AHKit.FALLEN
	return holder


## A peça de art/scenarios, carregada uma vez.
static func texture_of(file: String) -> Texture2D:
	if not _textures.has(file):
		_textures[file] = load(SCENARIOS % file)
	return _textures[file]


## A moldura do estado, por cima do cartão.
func _frame(card: Button, color: Color, width: int) -> void:
	var frame := Panel.new()
	frame.name = "Edge"
	frame.add_theme_stylebox_override("panel", AHKit.outline(color, width))
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 4
	frame.offset_top = 4
	frame.offset_right = -4
	frame.offset_bottom = -4
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)


## O botão não cresce com o que tem dentro: a altura segue o texto (o Maior quebra mais linhas).
func _grow(card: Button, box: VBoxContainer) -> void:
	var grow := func(): card.custom_minimum_size.y = maxf(CARD.y, box.get_combined_minimum_size().y + 24.0)
	box.minimum_size_changed.connect(grow)
	grow.call()


## Embaixo: o escolhido (o nome, o estado e o que falta) e os botões: VOLTAR e a ação grande dele.
func _bottom(c: Dictionary, column: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.name = "Bottom"
	bar.add_theme_constant_override("separation", 16)
	column.add_child(bar)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(words)
	# Os detalhes do bloco: a obra, o posto de escavador e o que ele devolve (o painel do bloco).
	var details := AHKit.button(tr("Detalhes"), "secondary")
	details.name = "Details"
	details.custom_minimum_size = Vector2(200, 64)
	details.visible = selected != "" and not selected.begins_with("room:")
	var shown := selected
	details.pressed.connect(func(): hud.open_from_board(AHRefugeHud.block_place(shown)))
	var action := AHStationReport._primary(tr("Escolha um bloco"), "next_step", "interact")
	action.name = "BigAction"
	action.custom_minimum_size = Vector2(380, 64)
	action.disabled = true
	if selected.begins_with("room:"):
		var room_id := selected.trim_prefix("room:")
		words.add_child(AHKit.label(tr(AHStationRules.room_def(room_id).name), "card_name", AHKit.TEXT, true, true))
		words.add_child(AHKit.label(tr("Construído"), "text", AHKit.good()))
		action.text = tr("Abrir o cômodo").to_upper()
		action.disabled = false
		action.pressed.connect(func(): hud.open_from_board(room_id))
	elif selected != "":
		var info := AHRefugeHud.block_info(c, selected)
		var card := card_info(c, selected)
		var title := block_label(selected) if info.state != "free" else AHRefugeHud.block_title(selected)
		words.add_child(AHKit.label(title + " · " + AHRefugeHud.block_title(selected) if info.state != "free" else title, "card_name", AHKit.TEXT, true, true))
		var alert := neighbor_reason(c, selected) if info.state == "buried" else ""
		var note := AHKit.label(alert if alert != "" else String(info.note), "text", AHKit.alert_text() if alert != "" else AHKit.TEXT)
		note.name = "Note"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(700, 0)
		words.add_child(note)
		var least := AHStationGrid.finds_text({"scrap": int(AHStationGrid.block_rule(selected).get("Scrap", 0)),
			"fragments": int(AHStationGrid.block_rule(selected).get("Fragments", 0))})
		if info.state in ["dig", "front"] and least != "":
			var reward := AHKit.label(tr("Recompensa: %s, e às vezes um achado.") % least, "small", AHKit.MUTED)
			reward.name = "RewardNote"
			words.add_child(reward)
		var key := selected
		match String(info.state):
			"free":
				action.text = tr("Construir aqui").to_upper()
				action.disabled = false
				action.pressed.connect(func(): hud.open_from_board(AHRefugeHud.block_place(key)))
			"front":
				action.text = tr("É a frente de escavação").to_upper()
			"dig":
				action.text = tr("Escavar este bloco").to_upper()
				action.disabled = false
				action.pressed.connect(func():
					hud._act(AHStationGrid.set_dig_target(Campaign.state, key), tr("Escavação: a frente agora é %s.") % AHStationGrid.block_name(key))
					rebuild())
			_:
				action.text = tr("Ainda bloqueado").to_upper()
	bar.add_child(details)
	bar.add_child(action)
	AHStationReport.fit_key(action, 52.0)
