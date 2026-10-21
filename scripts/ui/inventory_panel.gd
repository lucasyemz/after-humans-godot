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

const H = preload("res://scripts/ui/combat_hud.gd")
const C = preload("res://scripts/flow/exploration_care.gd")
const ICONS := "res://art/ui/icons/%s.svg"
const KNOWN_TOOLS := ["pe_de_cabra", "lanterna", "mascara"]
const TOOL_NAMES := {"pe_de_cabra": "Pé de cabra", "lanterna": "Lanterna", "mascara": "Máscara com filtro"}
const TOOL_ICONS := {"pe_de_cabra": "tool-crowbar", "lanterna": "tool-flashlight", "mascara": "tool-mask"}
const RELIC_ICONS := {"botao_cobre": "relic-copper-button", "pena_vidro": "relic-glass-feather", "coleira_lembranca": "relic-memory-collar"}
const GROUPS := ["Suprimentos", "Ferramentas", "Recursos e relíquias"]

## Na luta, a sessão da arena (o herói da vez); fora dela, null.
var session: AHCombatSession
var hero_id := ""
var selected := "food"
var feedback := ""
var _slots: Array = []


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_validate_hero()
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_slots = _make_slots()
	if not _slots.any(func(s): return s.id == selected):
		selected = _slots[0].id
	var head := HBoxContainer.new()
	add_child(head)
	head.add_child(H.make_label("Mochila", 32, H.GOLD))
	var hint := H.make_label("   Na luta: ação livre do herói da vez, um item por vez." if session else "   Cuidados fora da luta: escolha o item e o aliado.", 16, H.MUTED)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	add_child(row)
	var grid_box := VBoxContainer.new()
	grid_box.add_theme_constant_override("separation", 8)
	grid_box.custom_minimum_size = Vector2(430, 0)
	row.add_child(grid_box)
	for group in GROUPS.size():
		grid_box.add_child(H.make_label(GROUPS[group], 19, H.GOLD.lightened(0.2)))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		grid_box.add_child(grid)
		for item in _slots.filter(func(s): return s.group == group):
			grid.add_child(_slot_button(item))
	row.add_child(_detail())
	var close := Button.new()
	close.text = "Fechar (Esc)"
	close.custom_minimum_size = Vector2(0, 46)
	H.style_button(close)
	close.pressed.connect(func(): closed.emit())
	add_child(close)


func _make_slots() -> Array:
	var campaign: Dictionary = Campaign.state
	var out: Array = []
	var food := AHJourneyRules.food(campaign)
	out.append({"id": "food", "name": "Comida", "icon": "lobby-food", "count": "%d / %d" % [food, AHJourneyRules.MAX_FOOD], "group": 0,
		"owned": food > 0, "text": "Da expedição: cura fora e dentro da luta. O que sobrar não volta ao refúgio."})
	var bandages: int = campaign.inventory.bandages
	out.append({"id": "bandages", "name": "Curativo", "icon": "res-bandages", "count": str(bandages), "group": 0, "owned": bandages > 0,
		"text": "Do refúgio: +8 de vida. O que sobrar e o que se achar voltam ao refúgio."})
	if C.iris(campaign) != null:
		var charges := C.ampoule_charges(campaign)
		out.append({"id": "ampoule", "name": "Ampola da Íris", "icon": "item-ampoule", "count": "%d cargas" % charges, "group": 0,
			"owned": charges > 0, "text": "Habilidade da Íris: cura um aliado orgânico. Recarrega após uma vitória."})
	var tools: Array = KNOWN_TOOLS.duplicate()
	for tool in campaign.get("tools", []):
		if not tools.has(tool):
			tools.append(tool)
	for tool in tools:
		var has := AHJourneyRules.has_tool(campaign, tool)
		out.append({"id": tool, "name": TOOL_NAMES.get(tool, tool.capitalize()), "icon": TOOL_ICONS.get(tool, "tool-generic"), "count": "",
			"group": 1, "owned": has, "text": "Reutilizável: abre escolhas nos eventos. Não se gasta." if has else "A equipe ainda não tem esta ferramenta."})
	for spec in [["seeds", "Sementes", "lobby-seed", "Moeda do refúgio: comida extra na preparação, pesquisa e obras."],
			["scrap", "Sucata", "lobby-scrap", "Matéria-prima da Forja."], ["fragments", "Fragmentos", "lobby-fragment", "Restos raros usados nas pesquisas."]]:
		out.append({"id": spec[0], "name": spec[1], "icon": spec[2], "count": str(int(campaign.inventory.get(spec[0], 0))), "group": 2,
			"owned": true, "text": spec[3]})
	var relics := {}
	for relic_id in campaign.inventory.get("relics", []):
		relics[relic_id] = int(relics.get(relic_id, 0)) + 1
	for relic_id in relics:
		var row = GameData.row("relics", relic_id)
		var name: String = row.get("DisplayName", relic_id) if row else relic_id
		var text: String = (row.get("Description", "") + " ") if row else ""
		out.append({"id": relic_id, "name": name, "icon": RELIC_ICONS.get(relic_id, "relic-generic"), "count": str(relics[relic_id]),
			"group": 2, "owned": true, "text": text + "Equipe no Depósito do refúgio."})
	return out


func _slot_button(item: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(138, 92)
	button.text = "\n\n%s%s" % [item.name, ("\n" + item.count) if item.count != "" else ""]
	button.add_theme_font_size_override("font_size", 15)
	H.style_button(button, H.GOLD if item.id == selected else Color(0.86, 0.69, 0.4))
	button.add_theme_font_size_override("font_size", 15)
	if item.id == selected:
		button.add_theme_color_override("font_color", H.GOLD)
	elif not item.owned:
		button.add_theme_color_override("font_color", H.MUTED.darkened(0.2))
	var icon := TextureRect.new()
	icon.texture = load(ICONS % item.icon)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(30, 30)
	icon.position = Vector2(54, 8)
	icon.size = Vector2(30, 30)
	icon.modulate = Color(0.96, 0.84, 0.6) if item.owned else Color(0.5, 0.48, 0.44)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var id: String = item.id
	button.pressed.connect(func():
		selected = id
		feedback = ""
		_build())
	return button


func _detail() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(400, 0)
	var item: Dictionary = _slots.filter(func(s): return s.id == selected)[0]
	box.add_child(H.make_label(item.name, 28, H.GOLD))
	if item.count != "":
		box.add_child(H.make_label(item.count, 19, H.TEXT))
	var text := H.make_label(item.text, 17, H.MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(400, 0)
	box.add_child(text)
	var actions := _actions(item.id)
	if not actions.is_empty():
		box.add_child(_target_row())
	for action in actions:
		var button := Button.new()
		button.text = action.label
		button.disabled = not action.enabled
		button.custom_minimum_size = Vector2(0, 46)
		H.style_button(button)
		button.pressed.connect(action.run)
		box.add_child(button)
		if not action.enabled and action.reason != "":
			var why := H.make_label(action.reason, 16, Color(1.0, 0.62, 0.5))
			why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			why.custom_minimum_size = Vector2(400, 0)
			box.add_child(why)
	if feedback != "":
		var said := H.make_label(feedback, 18, Color(0.55, 1.0, 0.6))
		said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		said.custom_minimum_size = Vector2(400, 0)
		box.add_child(said)
	return box


## Em quem o cuidado vai: na exploração troca o aliado (◀ ▶); na luta, o herói da vez.
func _target_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := ""
	if session:
		var unit := session.current_actor()
		label = "%s · Vida %d/%d" % [unit.display_name, unit.hp, unit.max_hp] if unit else "—"
	else:
		var hero = Campaign.hero(hero_id)
		label = "%s · Vida %d/%d" % [hero.display_name, hero.hp, hero.max_hp] if hero else "—"
		var back := Button.new()
		back.text = "◀"
		back.custom_minimum_size = Vector2(44, 40)
		H.style_button(back)
		back.pressed.connect(func(): cycle_hero(-1))
		row.add_child(back)
	var name := H.make_label(label, 19, H.TEXT)
	name.custom_minimum_size = Vector2(290, 0)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(name)
	if session == null:
		var next := Button.new()
		next.text = "▶"
		next.custom_minimum_size = Vector2(44, 40)
		H.style_button(next)
		next.pressed.connect(func(): cycle_hero(1))
		row.add_child(next)
	return row


func _actions(id: String) -> Array:
	var kinds: Array = []
	match id:
		"food":
			kinds = [[C.SMALL_MEAL, "Comer pouco"], [C.FULL_MEAL, "Comer bem"]]
		"bandages":
			kinds = [[C.BANDAGE, "Usar curativo"]]
		"ampoule":
			kinds = [[C.IRIS_AMPOULE, "Ampola da Íris"]]
	var out: Array = []
	for spec in kinds:
		var kind: String = spec[0]
		var q: Dictionary = C.combat_quote(Campaign.state, session, kind) if session else C.quote(Campaign.state, hero_id, kind)
		var cost := ""
		if q.food_cost > 0:
			cost = " · %d comida%s" % [q.food_cost, "s" if q.food_cost > 1 else ""]
		elif q.bandage_cost > 0:
			cost = " · 1 curativo"
		else:
			cost = " · %d cargas" % q.charges
		var heal := ""
		if q.heal_max > 0:
			heal = " · +%d vida" % q.heal_max if q.heal_min == q.heal_max else " · +%d–%d vida" % [q.heal_min, q.heal_max]
		out.append({"label": spec[1] + heal + cost, "enabled": q.available, "reason": q.reason, "run": _use.bind(kind)})
	return out


func _use(kind: String) -> void:
	if session:
		combat_item.emit(kind)
		return
	var hero = Campaign.hero(hero_id)
	var healed := C.use(Campaign.state, hero_id, kind)
	if healed > 0:
		Campaign.save()
		Sound.play("res://audio/ui/confirm.ogg")
		feedback = "%s recuperou %d de vida." % [hero.display_name, healed]
		used.emit()
	else:
		Sound.play("res://audio/ui/deny.ogg")
		feedback = "O item não pôde ser usado."
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
