## Mochila da equipe (port do UAHInventoryWidget, #37): o estoque compartilhado por grupo (suprimentos da expedição,
## ferramentas, recursos e relíquias) e, à direita, o item escolhido com as ações, o alvo, a cura, o custo e o motivo
## quando não dá. Não guarda estoque: lê a campanha e usa as regras do AHExplorationCare. Na exploração escolhe o aliado
## (o mais ferido primeiro); na luta é o herói da vez e o uso volta como comando (ação livre).
class_name AHInventoryPanel
extends VBoxContainer

signal closed
## Na luta: o item escolhido vira comando da arena ({kind: "item", item}).
signal combat_item(kind: String)
## Na exploração: um cuidado mudou a vida ou o estoque (o HUD se atualiza).
signal used

const C = preload("res://scripts/flow/exploration_care.gd")
const KNOWN_TOOLS := ["pe_de_cabra", "lanterna", "mascara"]
const TOOL_NAMES := {"pe_de_cabra": "Pé de cabra", "lanterna": "Lanterna", "mascara": "Máscara com filtro"}
const TOOL_ICONS := {"pe_de_cabra": "tool-crowbar", "lanterna": "tool-flashlight", "mascara": "tool-mask"}
## O que cada ferramenta faz (o aviso de quando chega e a Mochila, #143).
const TOOL_TEXTS := {"pe_de_cabra": "Abre portas e gavetas emperradas nos eventos e arromba uma loja trancada (aí ele quebra).",
	"lanterna": "Ilumina poços e cantos escuros: abre escolhas nos eventos.",
	"mascara": "Filtra o ar tomado de esporos: abre escolhas nos eventos."}
const RELIC_ICONS := {"botao_cobre": "relic-copper-button", "pena_vidro": "relic-glass-feather", "coleira_lembranca": "relic-memory-collar"}
const GROUPS := ["Suprimentos", "Ferramentas", "Recursos e relíquias"]
## O lado do quadrado de um item e a largura do detalhe.
const SLOT := 112.0
const DETAIL := 520.0

## Na luta, a sessão da arena (o herói da vez); fora dela, null.
var session: AHCombatSession
var hero_id := ""
var selected := "food"
var feedback := ""
## As ferramentas que chegaram desde a última vez que a Mochila abriu (#143): ficam com o selo NOVO, e a primeira abre
## escolhida.
var fresh: Array = []
var _slots: Array = []


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	if not fresh.is_empty():
		selected = fresh[0]
	_validate_hero()
	_build()


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_slots = _make_slots()
	if not _slots.any(func(s): return s.id == selected):
		selected = _slots[0].id
	# O título: o ícone, MOCHILA, a dica e FECHAR com a tecla do Menu.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	add_child(head)
	head.add_child(_icon("room_depot", 40, AHKit.AMBER))
	head.add_child(AHKit.label(tr("Mochila"), "panel_title", AHKit.TEXT, true, true))
	var hint := AHKit.label(tr("Na luta: ação livre do herói da vez, um item por vez.") if session else tr("Cuidados fora da luta: escolha o item e o aliado."), "small", AHKit.MUTED)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(hint)
	var close := AHKit.button(tr("Fechar"), "secondary")
	close.name = "Close"
	close.custom_minimum_size = Vector2(0, 56)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var key := AHKitKey.make("", tr("%s / B") % AHUiStyle.key_name("menu"), "button")
	key.name = "Key"
	close.add_child(key)
	close.pressed.connect(func(): closed.emit())
	head.add_child(close)
	close.resized.connect(func():
		key.reset_size()
		key.position = Vector2(close.size.x - key.size.x - 12.0, (close.size.y - key.size.y) * 0.5))
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		if close.has_theme_stylebox_override(state):
			close.get_theme_stylebox(state).content_margin_right = key.get_combined_minimum_size().x + 28.0
	var rule := ColorRect.new()
	rule.color = Color(AHKit.MUTED, 0.35)
	rule.custom_minimum_size = Vector2(0, 2)
	add_child(rule)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	add_child(row)
	# À esquerda, os quadrados por grupo; à direita, o detalhe do escolhido.
	var grid_box := VBoxContainer.new()
	grid_box.add_theme_constant_override("separation", 10)
	row.add_child(grid_box)
	for group in GROUPS.size():
		grid_box.add_child(AHKit.label(tr(GROUPS[group]), "row", AHKit.AMBER, true, true))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 10)
		grid_box.add_child(grid)
		for item in _slots.filter(func(s): return s.group == group):
			grid.add_child(_slot_button(item))
	var detail := _detail()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)


## O selo NOVO no canto de cima à direita (a ferramenta que acabou de chegar e o botão MOCHILA, #143).
static func new_tag() -> PanelContainer:
	var tag := AHKit.chip("cost")
	tag.name = "New"
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(AHKit.label(TranslationServer.translate("Novo").to_upper(), "small", AHKit.AMBER, true))
	tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 2)
	tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# Meio para fora da borda de cima: no texto Maior ele não cobre o ícone.
	var height := tag.get_combined_minimum_size().y
	tag.offset_top = -height * 0.55
	tag.offset_bottom = tag.offset_top + height
	return tag


## Um ícone do kit (ou dos ícones antigos, que o kit ainda não tem).
func _icon(name: String, side: float, tint: Color) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = AHKit.legacy_icon(name)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(side, side)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _make_slots() -> Array:
	var campaign: Dictionary = Campaign.state
	var out: Array = []
	var food := AHJourneyRules.food(campaign)
	out.append({"id": "food", "name": tr("Comida"), "icon": "lobby-food", "count": "%d / %d" % [food, AHJourneyRules.MAX_FOOD], "group": 0,
		"owned": food > 0, "text": tr("Da expedição: cura fora e dentro da luta. O que sobrar não volta ao refúgio.")})
	var bandages: int = campaign.inventory.bandages
	out.append({"id": "bandages", "name": tr("Curativo"), "icon": "res-bandages", "count": str(bandages), "group": 0, "owned": bandages > 0,
		"text": tr("Do refúgio: +8 de vida. O que sobrar e o que se achar voltam ao refúgio.")})
	if C.iris(campaign) != null:
		var charges := C.ampoule_charges(campaign)
		# No acampamento (decisão do Lucas, #98), o que se usa sai das cargas da próxima luta: a Mochila diz isso.
		var text := tr("Habilidade do sapo: cura um aliado orgânico. Recarrega após uma vitória.")
		if _camping():
			text += " " + tr("No acampamento, cada uso sai das cargas da próxima luta.")
		# O quadrado e o botão ficam curtos ("3 cargas", a Mochila não alarga); a linha do detalhe diz a próxima luta.
		out.append({"id": "ampoule", "name": tr("Ampola de Reparo"), "icon": "item-ampoule", "count": tr("%d cargas") % charges, "group": 0,
			"owned": charges > 0, "text": text, "detail": _charges_text(charges)})
	var tools: Array = KNOWN_TOOLS.duplicate()
	for tool in campaign.get("tools", []):
		if not tools.has(tool):
			tools.append(tool)
	for tool in tools:
		var has := AHJourneyRules.has_tool(campaign, tool)
		out.append({"id": tool, "name": tr(TOOL_NAMES.get(tool, tool.capitalize())), "icon": TOOL_ICONS.get(tool, "tool-generic"), "count": "",
			"group": 1, "owned": has, "text": tool_text(tool) if has else tr("A equipe ainda não tem esta ferramenta.")})
	for spec in [["seeds", "Sementes", "lobby-seed", "Moeda do refúgio: comida extra na preparação, pesquisa e obras."],
			["scrap", "Sucata", "lobby-scrap", "Matéria-prima da Forja."], ["fragments", "Fragmentos", "lobby-fragment", "Restos raros usados nas pesquisas."]]:
		out.append({"id": spec[0], "name": tr(spec[1]), "icon": spec[2], "count": str(int(campaign.inventory.get(spec[0], 0))), "group": 2,
			"owned": true, "text": tr(spec[3])})
	var relics := {}
	for relic_id in campaign.inventory.get("relics", []):
		relics[relic_id] = int(relics.get(relic_id, 0)) + 1
	for relic_id in relics:
		var row = GameData.row("relics", relic_id)
		var name: String = tr(row.get("DisplayName", relic_id)) if row else relic_id
		# O que faz e o texto (#263: o Effect do colar antes da descrição).
		var text: String = (AHRelics.text(relic_id) + " ") if row else ""
		out.append({"id": relic_id, "name": name, "icon": RELIC_ICONS.get(relic_id, "relic-generic"), "count": str(relics[relic_id]),
			"group": 2, "owned": true, "text": text + tr("Equipe no Alojamento.")})
	return out


## O que a ferramenta faz, traduzido.
static func tool_text(tool: String) -> String:
	return TranslationServer.translate(TOOL_TEXTS.get(tool, "Reutilizável: abre escolhas nos eventos."))


## Um item: o quadrado de recurso com o ícone (o escolhido com a moldura âmbar) e, embaixo, o nome e a quantidade. O
## que a equipe não tem fica no tom apagado, sem transparência. O botão é o quadrado; o nome quebra na largura dele.
func _slot_button(item: Dictionary) -> Button:
	var button := Button.new()
	button.name = "Slot_%s" % item.id
	AHKit.style_button(button, AHKit.piece_of("chip", "resource_tile"))
	button.custom_minimum_size = Vector2(SLOT, 0)
	button.tooltip_text = item.name
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	var tile := AHKit.panel(AHKit.piece_of("chip", "resource_tile"))
	tile.custom_minimum_size = Vector2(SLOT, 80)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(tile)
	var chosen: bool = item.id == selected
	var tone: Color = AHKit.AMBER if chosen else (AHKit.TEXT if item.owned else AHKit.MUTED)
	var glyph := _icon(item.icon, 40, tone)
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.add_child(glyph)
	if chosen:
		tile.add_child(AHKit.selected_overlay())
	if fresh.has(item.id):
		button.add_child(new_tag())
	var name := AHKit.label(item.name, "small", AHKit.TEXT if item.owned else AHKit.MUTED)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.custom_minimum_size = Vector2(SLOT, 0)
	column.add_child(name)
	if item.count != "":
		var count := AHKit.label(item.count, "row", AHKit.AMBER if item.owned else AHKit.MUTED, true)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(count)
	# O fundo da peça fica no quadrado de dentro; o botão só leva o foco (os cantos âmbar).
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var grow := func(): button.custom_minimum_size.y = column.get_combined_minimum_size().y
	column.minimum_size_changed.connect(grow)
	grow.call()
	var id: String = item.id
	button.pressed.connect(func():
		selected = id
		feedback = ""
		_build())
	return button


func _detail() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(DETAIL, 0)
	var item: Dictionary = _slots.filter(func(s): return s.id == selected)[0]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	head.add_child(_icon(item.icon, 36, AHKit.AMBER))
	head.add_child(AHKit.label(item.name, "card_name", AHKit.TEXT, true))
	if item.count != "":
		var chip := AHKit.chip("cost")
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(AHKit.label(item.get("detail", item.count), "small", AHKit.AMBER, true))
		head.add_child(chip)
	var text := AHKit.label(item.text, "text", AHKit.MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(DETAIL, 0)
	box.add_child(text)
	var actions := _actions(item.id)
	if not actions.is_empty():
		box.add_child(_target_row())
	var reasons: Array = []
	for action in actions:
		var button := Button.new()
		button.text = action.label
		button.disabled = not action.enabled
		AHKit.style_as(button, "list", Vector4(56, 0, 16, 0))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 56)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", AHKit.size("row"))
		button.add_theme_color_override("font_color", AHKit.TEXT)
		button.add_theme_color_override("font_disabled_color", AHKit.MUTED)
		var glyph := _icon(item.icon, 26, AHKit.TEXT if action.enabled else AHKit.MUTED)
		glyph.size = Vector2(26, 26)
		button.add_child(glyph)
		button.resized.connect(func(): glyph.position = Vector2(18, (button.size.y - 26.0) * 0.5))
		button.pressed.connect(action.run)
		box.add_child(button)
		if not action.enabled and action.reason != "" and not reasons.has(action.reason):
			reasons.append(action.reason)
	# O motivo de não dar, uma vez só embaixo das ações ("O aliado já está com a vida cheia.").
	for reason in reasons:
		box.add_child(_note(reason, "state_active", AHKit.MUTED))
	if feedback != "":
		box.add_child(_note(feedback, "state_active", AHKit.good()))
	return box


## Uma linha curta com o ícone (o motivo de não dar, o que o cuidado fez).
func _note(text: String, icon_name: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_icon(icon_name, 22, color))
	var label := AHKit.label(text, "small", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


## Em quem o cuidado vai: na exploração troca o aliado (as setas); na luta, o herói da vez. O retrato, o nome e a vida.
func _target_row() -> PanelContainer:
	var panel := AHKit.panel_box("inset")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var unit = session.current_actor() if session else Campaign.hero(hero_id)
	if session == null:
		row.add_child(_arrow(true, func(): cycle_hero(-1)))
	var middle := HBoxContainer.new()
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 12)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(middle)
	if unit != null:
		var hero_id_of: String = unit.hero_id if session else unit.id
		var hero = Campaign.hero(hero_id_of)
		var art: Dictionary = AHCombatArena.hero_art_of(hero_id_of, String(hero.get("art_variant", "")) if hero else "").get("idle", {})
		middle.add_child(AHKit.portrait(AHUiStyle.face_texture(art), 48))
		var names := VBoxContainer.new()
		names.add_theme_constant_override("separation", -2)
		names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		middle.add_child(names)
		names.add_child(AHKit.label(unit.display_name, "row", AHKit.TEXT, true))
		names.add_child(AHKit.label(tr("Vida %d/%d") % [unit.hp, unit.max_hp], "small", AHKit.MUTED))
	else:
		middle.add_child(AHKit.label("—", "row", AHKit.MUTED))
	if session == null:
		row.add_child(_arrow(false, func(): cycle_hero(1)))
	return panel


## Uma seta de trocar o aliado: o botão de ícone com a seta (a da esquerda é a da direita espelhada).
func _arrow(back: bool, action: Callable) -> Button:
	var button := Button.new()
	button.name = "Previous" if back else "Next"
	AHKit.style_as(button, "icon")
	button.custom_minimum_size = Vector2(56, 56)
	var arrow := _icon("ui-arrow-right", 28, AHKit.TEXT)
	arrow.flip_h = back
	arrow.size = Vector2(28, 28)
	arrow.position = Vector2(14, 14)
	button.add_child(arrow)
	button.pressed.connect(action)
	return button


func _actions(id: String) -> Array:
	var kinds: Array = []
	match id:
		"food":
			kinds = [[C.SMALL_MEAL, tr("Comer pouco")], [C.FULL_MEAL, tr("Comer bem")]]
		"bandages":
			kinds = [[C.BANDAGE, tr("Usar curativo")]]
		"ampoule":
			kinds = [[C.IRIS_AMPOULE, tr("Ampola de Reparo")]]
	var out: Array = []
	for spec in kinds:
		var kind: String = spec[0]
		var q: Dictionary = C.combat_quote(Campaign.state, session, kind) if session else C.quote(Campaign.state, hero_id, kind)
		var cost := ""
		if q.food_cost > 0:
			cost = (tr(" · %d comidas") if q.food_cost > 1 else tr(" · %d comida")) % q.food_cost
		elif q.bandage_cost > 0:
			cost = tr(" · 1 curativo")
		else:
			cost = tr(" · %d cargas") % q.charges
		var heal := ""
		if q.heal_max > 0:
			heal = tr(" · +%d vida") % q.heal_max if q.heal_min == q.heal_max else tr(" · +%d–%d vida") % [q.heal_min, q.heal_max]
		if q.get("instinct", 0) < 0:
			heal += tr(" · %d instinto") % q.instinct
		out.append({"label": spec[1] + heal + cost, "enabled": q.available, "reason": q.reason, "run": _use.bind(kind)})
	return out


func _use(kind: String) -> void:
	if session:
		combat_item.emit(kind)
		return
	var hero = Campaign.hero(hero_id)
	var q := C.quote(Campaign.state, hero_id, kind)
	var healed := C.use(Campaign.state, hero_id, kind)
	if healed > 0 or (q.available and q.instinct < 0):
		Campaign.save()
		Sound.play("res://audio/ui/confirm.ogg")
		feedback = tr("%s recuperou %d de vida.") % [hero.display_name, healed] if healed > 0 \
			else tr("%s se acalmou: %d de instinto.") % [hero.display_name, q.instinct]
		used.emit()
	else:
		Sound.play("res://audio/ui/deny.ogg")
		feedback = tr("O item não pôde ser usado.")
	_validate_hero()
	_build()


func _team() -> Array:
	var expedition = Campaign.state.session.expedition
	if expedition == null:
		return []
	return expedition.team.filter(func(id):
		var hero = Campaign.hero(id)
		return hero != null and hero.alive and hero.hp > 0)


## O aliado de antes se ainda está de pé; senão, o mais ferido (quem mais precisa de cuidado).
func _validate_hero() -> void:
	if session:
		return
	var team := _team()
	if team.has(hero_id):
		return
	hero_id = ""
	var most := -1
	for id in team:
		var hero = Campaign.hero(id)
		if hero.max_hp - hero.hp > most:
			most = hero.max_hp - hero.hp
			hero_id = id


func cycle_hero(direction: int) -> void:
	var team := _team()
	if team.is_empty():
		return
	hero_id = team[(maxi(0, team.find(hero_id)) + direction + team.size()) % team.size()]
	feedback = ""
	_build()


## Fora da luta, no acampamento: a Mochila mostra a ampola como as cargas que sobram para a próxima luta.
func _camping() -> bool:
	return session == null and String(Campaign.state.get("session", {}).get("screen", "")) == "rest"


func _charges_text(charges: int) -> String:
	if _camping():
		return tr("%d cargas para a próxima luta") % charges if charges != 1 else tr("1 carga para a próxima luta")
	return tr("%d cargas") % charges
