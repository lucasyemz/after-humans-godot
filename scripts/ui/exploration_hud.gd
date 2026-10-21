## HUD da exploração no corredor: os 10 trechos (só os alcançados mostram o que são), a mochila e o achado, a equipe, o
## aviso de interação (E), os avisos que somem sozinhos e os painéis do evento, do acampamento e do resultado.
## Mesmo estilo do HUD de combate (AHCombatHud).
class_name AHExplorationHud
extends Control

signal event_choice(choice_id: String)
signal event_closed
signal camp_food(hero_id: String)
signal camp_bandage(hero_id: String)
signal camp_leave
signal result_continue

const H = preload("res://scripts/ui/combat_hud.gd")
const STEP_LABELS := {"start": "Partida", "combat": "Patrulha", "loot": "Suprimentos", "rest": "Descanso", "passage": "Passagem",
	"boss": "Guardião"}
const STEP_LETTERS := {"start": "P", "combat": "!", "loot": "S", "rest": "D", "passage": "·", "boss": "G"}

var _steps_row: HBoxContainer
var _step_title: Label
var _resources: Label
var _party_box: VBoxContainer
var _prompt: PanelContainer
var _prompt_label: Label
var _toast: Label
var _toast_tween: Tween
var _modal: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := VBoxContainer.new()
	top.position = Vector2(560, 14)
	top.size = Vector2(800, 0)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_step_title = H.make_label("", 20, H.GOLD)
	_step_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_step_title)
	_steps_row = HBoxContainer.new()
	_steps_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_steps_row.add_theme_constant_override("separation", 6)
	_steps_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_steps_row)

	_resources = H.make_label("", 18, H.TEXT)
	_resources.position = Vector2(1300, 66)
	_resources.size = Vector2(590, 60)
	_resources.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_resources.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_resources)

	_party_box = VBoxContainer.new()
	_party_box.position = Vector2(36, 790)
	_party_box.size = Vector2(300, 0)
	_party_box.add_theme_constant_override("separation", 4)
	_party_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_party_box)

	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", H.panel_style(0.85))
	_prompt.position = Vector2(660, 900)
	_prompt.custom_minimum_size = Vector2(600, 0)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label = H.make_label("", 22, H.TEXT)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.add_child(_prompt_label)
	_prompt.visible = false
	add_child(_prompt)

	_toast = H.make_label("", 24, H.TEXT)
	_toast.position = Vector2(360, 150)
	_toast.size = Vector2(1200, 80)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.modulate.a = 0.0
	add_child(_toast)


# ---------------------------------------------------------------- estado

## Atualiza trechos, mochila e equipe a partir da campanha.
func refresh(campaign: Dictionary) -> void:
	var expedition = campaign.get("session", {}).get("expedition")
	if expedition == null:
		return
	var route: Dictionary = expedition.corridor
	for child in _steps_row.get_children():
		child.queue_free()
	for index in route.steps.size():
		var step: Dictionary = route.steps[index]
		var known: bool = index <= route.index or step.resolved
		var chip := PanelContainer.new()
		var style := H.panel_style(0.85)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		style.border_color = H.GOLD if index == route.index else (Color(0.4, 0.62, 0.4) if step.resolved else Color(0.35, 0.33, 0.3))
		chip.add_theme_stylebox_override("panel", style)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(H.make_label(STEP_LETTERS.get(step.type, "?") if known else "?", 18, H.TEXT if known else H.MUTED))
		_steps_row.add_child(chip)
	var current: Dictionary = route.steps[route.index]
	var title := "Trecho %d de %d · %s" % [route.index + 1, route.steps.size(), STEP_LABELS.get(current.type, "")]
	if route.current_house >= 0:
		var site: Dictionary = route.sites[route.current_house]
		title = "Dentro %s" % ("do cinema" if site.shop == 2 else "da " + AHJourneyRules.SHOP_NAMES[site.shop])
	if expedition.objective_completed:
		title += " · Fase concluída: volte à Estação pelo começo da rua"
	_step_title.text = title
	var tools := PackedStringArray()
	for tool in campaign.get("tools", []):
		tools.append({"pe_de_cabra": "Pé de cabra", "lanterna": "Lanterna", "mascara": "Máscara"}.get(tool, tool))
	_resources.text = "Comida %d · Curativos %d · Esperança %d\nAchado: %d sementes · %d sucata · %d fragmentos%s" % [
		expedition.food, campaign.inventory.bandages, expedition.hope, expedition.loot.seeds, expedition.loot.scrap,
		expedition.loot.fragments, ("\nFerramentas: " + ", ".join(tools)) if not tools.is_empty() else ""]
	for child in _party_box.get_children():
		child.queue_free()
	for hero_id in expedition.team:
		var hero = Campaign.hero(hero_id)
		if hero == null or not hero.alive:
			continue
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := H.make_label("%s %d/%d" % [hero.display_name, hero.hp, hero.max_hp], 16, H.TEXT)
		name_label.custom_minimum_size = Vector2(150, 0)
		row.add_child(name_label)
		var bar := H.make_bar(Color(0.78, 0.2, 0.18), 10)
		bar.custom_minimum_size = Vector2(130, 10)
		bar.max_value = hero.max_hp
		bar.value = hero.hp
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		_party_box.add_child(row)


func show_prompt(text: String) -> void:
	_prompt.visible = text != ""
	_prompt_label.text = text


func toast(text: String, seconds: float = 3.5) -> void:
	if _toast_tween:
		_toast_tween.kill()
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


func modal_open() -> bool:
	return _modal != null and is_instance_valid(_modal)


func close_modal() -> void:
	if modal_open():
		_modal.queue_free()
	_modal = null


func _open_modal(width: float) -> VBoxContainer:
	close_modal()
	_modal = PanelContainer.new()
	_modal.add_theme_stylebox_override("panel", H.panel_style(0.95))
	_modal.custom_minimum_size = Vector2(width, 0)
	_modal.position = Vector2(960 - width * 0.5, 230)
	add_child(_modal)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_modal.add_child(box)
	return box


func _button(text: String, callback: Callable, enabled: bool = true) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.disabled = not enabled
	H.style_button(button)
	button.pressed.connect(callback)
	return button


# ---------------------------------------------------------------- evento

## Evento aberto (busca_*): título, descrição e as escolhas (as indisponíveis aparecem com o requisito).
func show_event(campaign: Dictionary) -> void:
	var event: Dictionary = campaign.session.event
	var row = GameData.row("events", event.event_id)
	if row == null:
		return
	var box := _open_modal(820)
	var title := H.make_label(row.get("Title", ""), 34, H.GOLD)
	box.add_child(title)
	var text := H.make_label(event.resolution if event.resolution != "" else row.get("Description", ""), 20, H.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(780, 0)
	box.add_child(text)
	var first: Button
	if event.resolution != "":
		first = _button("Continuar", func(): event_closed.emit())
		box.add_child(first)
	else:
		for choice in row.get("Choices", []):
			var available := AHJourneyRules.can_choose(campaign, choice)
			var label: String = choice.get("Text", "")
			var requirement: String = choice.get("RequirementText", "")
			if requirement != "":
				label += "  (%s)" % requirement
			var button := _button(label, func(): event_choice.emit(choice.Id), available)
			box.add_child(button)
			if first == null and available:
				first = button
	if first:
		first.grab_focus.call_deferred()


# ---------------------------------------------------------------- acampamento

## Painel do acampamento: cada herói com vida e instinto, comer e curativo; levantar acampamento.
func show_camp(campaign: Dictionary) -> void:
	var box := _open_modal(860)
	box.add_child(H.make_label("Acampamento", 34, H.GOLD))
	var note := H.make_label("A porta fechada e a fogueira acesa. Comer: +10%% de vida e -5 de instinto (comida %d). Curativo: +8 de vida (curativos %d)." % [
		AHJourneyRules.food(campaign), campaign.inventory.bandages], 18, H.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(820, 0)
	box.add_child(note)
	var first: Button
	for hero_id in campaign.session.expedition.team:
		var hero = Campaign.hero(hero_id)
		if hero == null or not hero.alive:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var label := H.make_label("%s · Vida %d/%d · Instinto %d" % [hero.display_name, hero.hp, hero.max_hp, hero.instinct], 20, H.TEXT)
		label.custom_minimum_size = Vector2(420, 0)
		row.add_child(label)
		var eat := _button("Comer", func(): camp_food.emit(hero_id),
			AHJourneyRules.food(campaign) > 0 and (hero.hp < hero.max_hp or hero.instinct > 0))
		eat.custom_minimum_size = Vector2(150, 44)
		row.add_child(eat)
		var heal := _button("Curativo", func(): camp_bandage.emit(hero_id), campaign.inventory.bandages > 0 and hero.hp < hero.max_hp)
		heal.custom_minimum_size = Vector2(150, 44)
		row.add_child(heal)
		box.add_child(row)
		if first == null:
			first = eat if not eat.disabled else (heal if not heal.disabled else null)
	var leave := _button("Levantar acampamento", func(): camp_leave.emit())
	box.add_child(leave)
	(first if first else leave).grab_focus.call_deferred()


# ---------------------------------------------------------------- resultado

## Fim da expedição: o que aconteceu e o que chega ao refúgio. delivered vem de AHJourneyRules.finish_return.
func show_result(result: String, delivered: Dictionary, campaign: Dictionary, button_text: String) -> void:
	var box := _open_modal(720)
	var titles := {"victory": "Vitória", "retreat": "Retirada", "fled": "Fuga", "defeat": "Derrota"}
	var notes := {"victory": "A Rua das Vitrines está liberada. Todo o achado chega à Estação.",
		"retreat": "A equipe volta antes do guardião: metade do achado chega à Estação.",
		"fled": "Na fuga, a equipe larga o que carregava.", "defeat": "A equipe caiu na rua. O achado ficou para trás."}
	box.add_child(H.make_label(titles.get(result, result), 44, H.GOLD))
	var note := H.make_label(notes.get(result, ""), 20, H.TEXT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(680, 0)
	box.add_child(note)
	box.add_child(H.make_label("Chegou à Estação: %d sementes · %d sucata · %d fragmentos" % [delivered.get("seeds", 0),
		delivered.get("scrap", 0), delivered.get("fragments", 0)], 20, H.MUTED))
	var alive: Array = campaign.roster.filter(func(h): return h.alive)
	box.add_child(H.make_label("Heróis vivos: %d · No memorial: %d" % [alive.size(), campaign.memorial.size()], 18, H.MUTED))
	var button := _button(button_text, func(): result_continue.emit())
	box.add_child(button)
	button.grab_focus.call_deferred()
