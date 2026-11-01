## O HUD do acampamento (#77), na estrutura da Unreal com o kit da Awesomic (#109, docs/design/hud-ajustes.md):
## - no alto à esquerda, a Plaqueta "ACAMPAMENTO / Ponto seguro" (a Mochila e o Menu continuam no canto, #98);
## - embaixo, um Painel de ponta a ponta: as quatro cartas na ordem da cena (a escolhida com o nome âmbar e as
##   cantoneiras), o herói escolhido com o instinto e os dois cuidados grandes (RAÇÃO e CURATIVO, com o estoque) e, no
##   pé, a linha de estado, as teclas e CONTINUAR;
## - com o foco (ou o mouse) num cuidado, a carta mostra a vida prevista (AHJourneyRules.camp_preview), sem gastar;
## - o cuidado sem efeito ganha o véu com riscas, e a linha de estado diz por quê.
## - as habilidades de acampamento (#261): as 4 do herói escolhido, com o Tempo de fogueira que sobra; a de aliado pede o
##   alvo (as setas e Interagir, ou o clique na carta; Esc desiste), e a linha de estado diz o que muda ou por que não.
## ←/→ trocam de herói (em qualquer lugar do painel); ↑/↓ andam entre a carta, RAÇÃO, CURATIVO, as habilidades e
## CONTINUAR; Interagir confirma. O clique no corpo (ou na carta) também escolhe. Cada comida ou curativo responde no herói: o número verde
## subindo, o efeito da #80 e o som.
class_name AHCampHud
extends Control

## Os efeitos da #80 (docs/design/camp/contract.json): a comida, o curativo e, na Íris, a ampola.
const FOOD_EFFECT := "res://art/camp/food_morsel.webp"
const BANDAGE_EFFECT := "res://art/camp/bandage_wrap.webp"
const AMPOULE_EFFECT := "res://art/camp/iris_ampoule.webp"
const EFFECT_SIZE := 64.0
const EFFECT_MS := 600
const EFFECT_REDUCED_MS := 400
const FOOD_SOUND := "res://audio/ui/confirm.ogg"
const BANDAGE_SOUND := "res://audio/combat/RobotHeal.wav"
## O Painel de baixo: de ponta a ponta, com o pé em PANEL_BOTTOM; as cartas de CARD_WIDTH, a CARD_GAP uma da outra.
const PANEL_LEFT := 14.0
const PANEL_RIGHT := 1906.0
const PANEL_BOTTOM := 1066.0
const CARD_WIDTH := 252.0
const CARD_GAP := 12.0
const CARE_HEIGHT := 76.0

signal food(hero_id: String)
signal skill(hero_id: String, skill_id: String, target_id: String)
signal bandage(hero_id: String)
signal leave

var camp: AHCampScene
var _bodies := {}
var _cards := {}
var _bar: PanelContainer
var _plaque: PanelContainer
var _name: Label
var _instinct: Label
var eat_button: Button
var heal_button: Button
var leave_button: Button
var _status: RichTextLabel
## O cuidado com o foco ou o mouse ("food", "bandage" ou ""): a carta mostra a vida prevista.
var _previewing := ""
## O lado (−1, 1) que está apertado agora; 0 solto.
var _held := 0
## As habilidades de acampamento do herói escolhido (#261): a linha, o Tempo e os botões.
var _skill_row: HBoxContainer
var _time: Label
var skill_buttons: Array = []
## A habilidade com o foco ou o mouse ("" nenhuma): a linha de estado diz o que ela faz.
var _skill_preview := ""
## A habilidade de aliado esperando o alvo: {user, skill}; {} sem nenhuma.
var targeting := {}
## De quem são os botões agora (refeitos quando o escolhido muda).
var _skills_of := ""


func _init(scene: AHCampScene = null) -> void:
	camp = scene
	name = "CampHud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build_plaque()
	_build_bar()
	for member in camp.members:
		_add_member(member.hero_id)
	camp.selected_changed.connect(func(_i): refresh())
	refresh()
	focus_bar.call_deferred()


## O foco ao abrir: o primeiro cuidado com efeito; sem nenhum, CONTINUAR.
func focus_bar() -> void:
	if is_inside_tree():
		(eat_button if not eat_button.disabled else (heal_button if not heal_button.disabled else leave_button)).grab_focus()


func _build_plaque() -> void:
	_plaque = AHKit.plaque()
	_plaque.name = "Plaque"
	_plaque.position = Vector2(28, 14)
	_plaque.custom_minimum_size = Vector2(440, 96)
	_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plaque)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_plaque.add_child(row)
	var glyph := AHKit.glyph("sleep", 44, AHKit.AMBER)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -4)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(names)
	names.add_child(AHKit.label(tr("Acampamento"), "panel_title", AHKit.TEXT, true, true))
	names.add_child(AHKit.label(tr("Ponto seguro"), "text", AHKit.MUTED))


func _build_bar() -> void:
	_bar = AHKit.panel_box("large")
	_bar.name = "CampBar"
	_bar.custom_minimum_size = Vector2(PANEL_RIGHT - PANEL_LEFT, 0)
	add_child(_bar)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_bar.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	column.add_child(top)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	top.add_child(left)
	var cards := HBoxContainer.new()
	cards.name = "Cards"
	cards.add_theme_constant_override("separation", int(CARD_GAP))
	left.add_child(cards)
	# As habilidades de acampamento (#261): as 4 do escolhido, embaixo das cartas (o painel não cresce).
	_skill_row = HBoxContainer.new()
	_skill_row.name = "Skills"
	_skill_row.add_theme_constant_override("separation", int(CARD_GAP))
	left.add_child(_skill_row)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(right)
	var head := HBoxContainer.new()
	right.add_child(head)
	_name = AHKit.label("", "panel_title", AHKit.TEXT, true, true)
	_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_name)
	# O Tempo de fogueira (#261) ao lado do instinto: o painel não cresce.
	_time = AHKit.label("", "text", AHKit.AMBER, true)
	_time.name = "Time"
	_time.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_time)
	_instinct = AHKit.label("", "text", AHKit.MUTED)
	_instinct.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_instinct)
	right.add_child(_divider())
	var cares := HBoxContainer.new()
	cares.add_theme_constant_override("separation", 16)
	right.add_child(cares)
	eat_button = _care("food", tr("Ração"), tr("+10% vida · −5 instinto"), "lobby-food", func(): food.emit(camp.selected_id()))
	heal_button = _care("bandage", tr("Curativo"), tr("+8 vida"), "res-bandages", func(): bandage.emit(camp.selected_id()))
	cares.add_child(eat_button)
	cares.add_child(heal_button)
	column.add_child(_divider())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	column.add_child(foot)
	var info := AHKit.glyph("next_step", AHUiStyle.px(24), AHKit.AMBER)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(info)
	_status = AHKit.arrow_label("", "text", AHKit.TEXT)
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_status)
	var keys := AHKit.panel(AHKit.piece_of("key", "bar"))
	keys.name = "Keys"
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_row := HBoxContainer.new()
	key_row.add_theme_constant_override("separation", 10)
	keys.add_child(key_row)
	key_row.add_child(AHKitKey.make("", tr("Setas")))
	key_row.add_child(AHKit.label(tr("Herói e cuidados"), "text", AHKit.TEXT))
	key_row.add_child(AHKitKey.make("interact"))
	key_row.add_child(AHKit.label(tr("Escolher"), "text", AHKit.TEXT))
	keys.visible = not Settings.touch_visible()
	foot.add_child(keys)
	leave_button = AHStationReport._primary(tr("Continuar"), "route", "interact")
	leave_button.name = "Continue"
	var key := leave_button.get_node("Key")
	leave_button.remove_child(key)
	key.queue_free()
	leave_button.custom_minimum_size = Vector2(340, 64)
	leave_button.pressed.connect(func(): leave.emit())
	foot.add_child(leave_button)


## Os botões das habilidades do herói escolhido (refeitos quando ele muda).
func _build_skills(hero) -> void:
	for button in skill_buttons:
		_skill_row.remove_child(button)
		button.queue_free()
	skill_buttons.clear()
	_skills_of = String(hero.id)
	for skill_id in AHCampSkills.equipped(hero):
		var row = AHCampSkills.skill(skill_id)
		if row == null:
			continue
		var button := AHKit.button("", "secondary")
		button.name = "Skill_" + skill_id
		button.set_meta("skill", skill_id)
		button.custom_minimum_size.x = CARD_WIDTH
		button.tooltip_text = tr(String(row.Description))
		var words := HBoxContainer.new()
		words.add_theme_constant_override("separation", 8)
		words.set_anchors_preset(Control.PRESET_FULL_RECT)
		words.offset_left = 12
		words.offset_right = -12
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(words)
		var title := AHKit.label(tr(String(row.DisplayName)), "text", AHKit.TEXT, true)
		title.name = "Title"
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		words.add_child(title)
		var cost := AHKit.label(str(int(row.Cost)), "text", AHKit.AMBER, true)
		cost.name = "Cost"
		cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		words.add_child(cost)
		var cover := AHKit.veil()
		cover.visible = false
		button.add_child(cover)
		button.pressed.connect(func(): _press_skill(skill_id))
		button.focus_entered.connect(func(): _preview_skill(skill_id))
		button.focus_exited.connect(func(): _preview_skill(""))
		button.mouse_entered.connect(func(): _preview_skill(skill_id))
		button.mouse_exited.connect(func(): _preview_skill(""))
		_skill_row.add_child(button)
		skill_buttons.append(button)


func _preview_skill(skill_id: String) -> void:
	_skill_preview = skill_id
	refresh()


## Apertar uma habilidade: a de aliado espera o alvo; as outras vão direto (a regra recusa o que não vale).
func _press_skill(skill_id: String) -> void:
	var user := camp.selected_id()
	if not targeting.is_empty():
		targeting = {}
	if AHCampSkills.needs_target(skill_id):
		targeting = {"user": user, "skill": skill_id}
		refresh()
		return
	skill.emit(user, skill_id, "")


## O alvo escolhido (a carta, o corpo ou Interagir com outro herói escolhido): usa e volta ao herói que usou.
func _choose_target(target_id: String) -> void:
	if targeting.is_empty():
		return
	var pending := targeting
	targeting = {}
	# Usa antes de voltar ao herói: a troca de herói (o fade) recusaria o uso no meio dela.
	skill.emit(String(pending.user), String(pending.skill), target_id)
	var index := camp.members.map(func(m): return m.hero_id).find(String(pending.user))
	if index >= 0 and camp.selected_id() != String(pending.user):
		camp.select(index)


func cancel_target() -> void:
	if not targeting.is_empty():
		targeting = {}
		refresh()


func _divider() -> TextureRect:
	var line := TextureRect.new()
	line.texture = AHKit.texture("divider")
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.custom_minimum_size = Vector2(0, 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## Um cuidado grande: o ícone, o nome, o efeito e o estoque ("x4"); o foco e o mouse mostram a vida prevista.
func _care(kind: String, title: String, effect: String, icon_name: String, action: Callable) -> Button:
	var button := AHKit.button("", "secondary")
	button.name = "Care_" + kind
	button.custom_minimum_size = Vector2(0, CARE_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	button.focus_entered.connect(func(): _preview(kind))
	button.focus_exited.connect(func(): _preview(""))
	button.mouse_entered.connect(func(): _preview(kind))
	button.mouse_exited.connect(func(): _preview(_focused_care()))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20
	row.offset_right = -22
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var icon := TextureRect.new()
	icon.name = "Icon"
	# A Ração e o Curativo pintados (#125), com as cores deles; sem eles, o glifo tingido.
	var painted := AHKit.painted(icon_name)
	icon.texture = painted if painted != null else AHKit.legacy_icon(icon_name)
	icon.set_meta("painted", painted != null)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(AHUiStyle.px(38), AHUiStyle.px(38))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -2)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	# O nome e o estoque numa linha; o efeito embaixo, na largura inteira (cabe numa linha também no Maior).
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(title_row)
	var name_label := AHKit.label(title, "primary", AHKit.TEXT, true, true)
	name_label.name = "Title"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_label)
	var stock := AHKit.label("", "card_name", AHKit.AMBER, true)
	stock.name = "Stock"
	title_row.add_child(stock)
	var effect_label := AHKit.label(effect, "text", AHKit.MUTED)
	effect_label.name = "Effect"
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.custom_minimum_size = Vector2(120, 0)
	words.add_child(effect_label)
	var cover := AHKit.veil()
	cover.visible = false
	button.add_child(cover)
	return button


func _add_member(hero_id: String) -> void:
	var hero = Campaign.hero(hero_id)
	# A carta, na ordem da cena (camp.members já vem da esquerda para a direita).
	var card := Button.new()
	card.name = "Card_" + hero_id
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	AHKit.style_button(card, AHKit.piece_of("card", "hero"))
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.pressed.connect(func(): _pick(hero_id))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 18
	column.offset_top = 14
	column.offset_right = -18
	column.offset_bottom = -14
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	var frame := AHKit.panel("square_portrait")
	frame.custom_minimum_size = Vector2(72, 72)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := TextureRect.new()
	face.texture = AHUiStyle.face_texture(AHCombatArena.hero_art_of(hero_id, String(hero.get("art_variant", ""))).get("idle", {}))
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.clip_contents = true
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(face)
	row.add_child(frame)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var name_label := AHKit.label(String(hero.display_name), "row", AHKit.TEXT, true, true)
	name_label.name = "Name"
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	words.add_child(name_label)
	var life := AHKit.arrow_label("", "text", AHKit.TEXT, true)
	life.name = "Life"
	words.add_child(life)
	var bar := AHKit.bar("life", hero.hp, hero.max_hp)
	bar.name = "Bar"
	bar.custom_minimum_size = Vector2(0, 26)
	column.add_child(bar)
	# A escolhida: as cantoneiras âmbar (as de quem age na luta), separadas do foco (a moldura inteira).
	var corners := Panel.new()
	corners.name = "Chosen"
	corners.add_theme_stylebox_override("panel", AHKit.style(AHKit.piece_of("focus", "corners")))
	corners.set_anchors_preset(Control.PRESET_FULL_RECT)
	corners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(corners)
	(_bar.find_child("Cards", true, false) as HBoxContainer).add_child(card)
	_cards[hero_id] = card
	# A área do clique: o corpo inteiro na tela (como o alvo da luta), sem fundo.
	var body := Button.new()
	body.name = "Body_" + hero_id
	body.focus_mode = Control.FOCUS_NONE
	body.tooltip_text = String(hero.display_name)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		body.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	body.pressed.connect(func(): _pick(hero_id))
	add_child(body)
	move_child(body, 0)
	_bodies[hero_id] = body


## O clique numa carta ou num corpo: escolhe o herói, ou, com uma habilidade de aliado esperando, o alvo dela.
func _pick(hero_id: String) -> void:
	if not targeting.is_empty() and hero_id != String(targeting.user):
		_choose_target(hero_id)
		return
	camp.select(camp.members.map(func(m): return m.hero_id).find(hero_id))


## O cuidado com o foco agora ("" nenhum).
func _focused_care() -> String:
	var owner := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	return "food" if owner == eat_button else ("bandage" if owner == heal_button else "")


func _preview(kind: String) -> void:
	_previewing = kind
	refresh()


## Atualiza o escolhido, os cuidados, as cartas e a linha de estado (depois de cada comida e curativo, na troca de herói
## e com o foco num cuidado).
func refresh() -> void:
	if not camp.active or camp.members.is_empty():
		return
	var campaign: Dictionary = Campaign.state
	var hero_id := camp.selected_id()
	var hero = Campaign.hero(hero_id)
	if hero == null:
		return
	var food_left := AHJourneyRules.food(campaign)
	var bandages := int(campaign.inventory.bandages)
	var meal := AHJourneyRules.camp_preview(campaign, hero_id, "food")
	var wrap := AHJourneyRules.camp_preview(campaign, hero_id, "bandage")
	_name.text = String(hero.display_name)
	_instinct.text = tr("Instinto %d/200") % hero.instinct
	_style_care(eat_button, food_left, meal.effect)
	_style_care(heal_button, bandages, wrap.effect)
	eat_button.disabled = food_left <= 0 or not meal.effect
	heal_button.disabled = bandages <= 0 or not wrap.effect
	# A linha de estado: a prévia do cuidado com o foco; senão, por que um cuidado não serve; senão, o convite.
	var shown := meal if _previewing == "food" else (wrap if _previewing == "bandage" else {})
	var line := tr("%s: escolha um cuidado. A barra mostra a vida prevista antes de gastar.") % hero.display_name
	if not shown.is_empty() and shown.effect:
		var stock := food_left if _previewing == "food" else bandages
		if stock <= 0:
			line = tr("A comida acabou.") if _previewing == "food" else tr("Os curativos acabaram.")
		elif _previewing == "food" and shown.hp == hero.hp:
			line = tr("%s está com a vida cheia: a Ração só baixa o instinto (−5).") % hero.display_name
		else:
			line = (tr("Ração para %s: vida %d → %d de %d. Nada é gasto até confirmar.") if _previewing == "food" else tr("Curativo para %s: vida %d → %d de %d. Nada é gasto até confirmar.")) % [
				hero.display_name, hero.hp, shown.hp, hero.max_hp]
	elif _previewing == "bandage" and meal.effect:
		line = tr("%s está com a vida cheia.") % hero.display_name
	elif not meal.effect and not wrap.effect:
		line = tr("%s está com a vida cheia e o instinto em 0: nenhum cuidado faz efeito.") % hero.display_name
	elif not wrap.effect:
		line = tr("%s está com a vida cheia: a Ração só baixa o instinto (−5).") % hero.display_name
	line = _skills_refresh(campaign, hero, line)
	AHKit.set_arrow_text(_status, line)
	for member in camp.members:
		var card: Button = _cards.get(member.hero_id)
		var someone = Campaign.hero(member.hero_id)
		if card == null or someone == null:
			continue
		var chosen: bool = member.hero_id == hero_id
		(card.find_child("Name", true, false) as Label).add_theme_color_override("font_color", AHKit.AMBER if chosen else AHKit.TEXT)
		(card.get_node("Chosen") as Control).visible = chosen
		var bar: AHKitBar = card.find_child("Bar", true, false)
		bar.set_value(someone.hp, someone.max_hp)
		# Sem estoque, nada a prever: a carta não promete a vida que não vem.
		var stocked: bool = (food_left if _previewing == "food" else bandages) > 0
		var predicted: int = shown.hp if chosen and not shown.is_empty() and shown.effect and stocked and shown.hp > someone.hp else -1
		bar.preview = predicted
		var life: RichTextLabel = card.find_child("Life", true, false)
		AHKit.set_arrow_text(life, (tr("%d → %d / %d") % [someone.hp, predicted, someone.max_hp]) if predicted >= 0 else tr("%d / %d") % [someone.hp, someone.max_hp])
		# A carta tem a altura do conteúdo (o retrato, a vida e a barra), e não a da linha dos cuidados.
		card.custom_minimum_size.y = maxf((card.get_child(0) as Control).get_combined_minimum_size().y + 28.0, 72.0 + 26.0 + 36.0)
	# ↑/↓: a carta escolhida, RAÇÃO, CURATIVO e CONTINUAR, em roda; ←/→ são do herói (o _input).
	var chosen_card: Button = _cards.get(hero_id)
	var order: Array = [chosen_card, eat_button, heal_button] + skill_buttons + [leave_button]
	# Ao sair da árvore (o foco que sai do cuidado chama a prévia), os filhos saem antes: sem caminho, sem vizinhos.
	if (_cards.values() + order).any(func(control): return control == null or not control.is_inside_tree()):
		return
	for card in _cards.values():
		card.focus_neighbor_top = leave_button.get_path()
		card.focus_neighbor_bottom = eat_button.get_path()
	for i in range(1, order.size()):
		order[i].focus_neighbor_top = order[i - 1].get_path()
		order[i].focus_neighbor_bottom = order[(i + 1) % order.size()].get_path()
	for control in order:
		control.focus_neighbor_left = control.get_path()
		control.focus_neighbor_right = control.get_path()
	# ←/→ são do herói em todo o painel (o _input), também nas habilidades.
	# O botão com foco que ficou apagado (a comida acabou) passa o foco para o próximo que serve.
	var owner := get_viewport().gui_get_focus_owner() if get_viewport() else null
	if owner is Button and owner.disabled:
		for button in [eat_button, heal_button, leave_button]:
			if not button.disabled:
				button.grab_focus()
				break


## O cuidado: o estoque ("x4") e, sem efeito ou sem estoque, o véu com riscas e o texto no tom apagado (sem transparência).
func _style_care(button: Button, stock: int, effect: bool) -> void:
	var off := stock <= 0 or not effect
	# A chapa cresce com o texto (o Maior e o efeito em duas linhas): o conteúdo nunca encosta na borda.
	var row: Control = button.get_child(0)
	button.custom_minimum_size.y = maxf(AHUiStyle.px(CARE_HEIGHT), row.get_combined_minimum_size().y + 20.0)
	(button.find_child("Stock", true, false) as Label).text = tr("x%d") % stock
	(button.find_child("Stock", true, false) as Label).add_theme_color_override("font_color", AHKit.MUTED if off else AHKit.AMBER)
	(button.find_child("Title", true, false) as Label).add_theme_color_override("font_color", AHKit.MUTED if off else AHKit.TEXT)
	var icon := button.find_child("Icon", true, false) as Control
	if icon.get_meta("painted", false):
		icon.modulate = AHKit.DIM if off else Color.WHITE
	else:
		icon.modulate = AHKit.MUTED if off else AHKit.TEXT
	(button.get_node("Veil") as Control).visible = off


## As habilidades (#261): os botões do escolhido (o custo, o véu na que não serve agora), o Tempo que sobra e a linha de
## estado (o alvo esperado; senão, a da habilidade com o foco: o que muda ou por que não). Devolve a linha.
func _skills_refresh(campaign: Dictionary, hero, line: String) -> String:
	if _skills_of != String(hero.id) and targeting.is_empty():
		_build_skills(hero)
	_time.text = tr("Tempo de fogueira %d/%d ·") % [AHCampSkills.time_left(campaign), AHCampSkills.time_budget()]
	var user := String(targeting.get("user", hero.id))
	for button in skill_buttons:
		var skill_id: String = button.get_meta("skill")
		var q := AHCampSkills.quote(campaign, user, skill_id, "")
		# A de aliado: vale se houver um aliado em quem ela faz diferença.
		if q.needs_target and String(q.reason) == tr("Escolha o aliado."):
			q.available = camp.members.any(func(m): return m.hero_id != user and AHCampSkills.quote(campaign, user, skill_id, m.hero_id).available)
		var off: bool = not q.available
		button.disabled = off and targeting.is_empty()
		(button.get_node("Veil") as Control).visible = off
		(button.find_child("Title", true, false) as Label).add_theme_color_override("font_color", AHKit.MUTED if off else AHKit.TEXT)
		(button.find_child("Cost", true, false) as Label).add_theme_color_override("font_color", AHKit.MUTED if off else AHKit.AMBER)
		button.custom_minimum_size.y = maxf(AHUiStyle.px(44), (button.get_child(0) as Control).get_combined_minimum_size().y + 12.0)
	if not targeting.is_empty():
		var row = AHCampSkills.skill(String(targeting.skill))
		var aimed := camp.selected_id()
		if aimed != String(targeting.user):
			var q := AHCampSkills.quote(campaign, String(targeting.user), String(targeting.skill), aimed)
			var who = Campaign.hero(aimed)
			return (tr("%s em %s: %s. Interagir confirma; Esc desiste.") % [tr(String(row.DisplayName)), who.display_name, ", ".join(q.changes)]) if q.available \
				else tr("%s em %s: %s") % [tr(String(row.DisplayName)), who.display_name, q.reason]
		return tr("%s: escolha o aliado (setas ou o clique na carta). Esc desiste.") % tr(String(row.DisplayName))
	if _skill_preview != "":
		var row = AHCampSkills.skill(_skill_preview)
		var q := AHCampSkills.quote(campaign, String(hero.id), _skill_preview, "")
		var cost := tr("%d de Tempo") % int(row.Cost)
		if q.available:
			return tr(String(row.DisplayName)) + " (" + cost + "): " + ", ".join(q.changes) + "."
		if q.needs_target and String(q.reason) == tr("Escolha o aliado."):
			return tr(String(row.DisplayName)) + " (" + cost + "): " + tr(String(row.Description))
		return tr(String(row.DisplayName)) + " (" + cost + "): " + String(q.reason)
	return line


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not camp.active:
		return
	_bar.reset_size()
	_bar.size = Vector2(PANEL_RIGHT - PANEL_LEFT, _bar.get_combined_minimum_size().y)
	_bar.position = Vector2(PANEL_LEFT, PANEL_BOTTOM - _bar.size.y)
	# O Concluir jornada (guardião vencido) fica acima do painel.
	var finish = get_parent().get("_finish_button") if get_parent() != null else null
	if finish is Control and finish.visible:
		finish.position.y = _bar.position.y - finish.size.y - 12.0
	var clicks := click_rects(camera)
	for member in camp.members:
		var body: Button = _bodies.get(member.hero_id)
		if body != null and clicks.has(member.hero_id):
			body.position = clicks[member.hero_id].position
			body.size = clicks[member.hero_id].size


## O corpo na tela: a caixa do alfa visível da pose (camp_poses.json, "visible"), e não o canvas inteiro (o da pose
## sentada tem o vazio de cima do idle); sem ela, do pé ao topo da placa.
static func body_rect(camera: Camera3D, card: AHSpriteCard) -> Rect2:
	var art: Dictionary = card.art()
	var corners: Array = []
	if art.has("visible"):
		var px_to_m: float = card.body_height / float(art.body_reference_pixels)
		var anchor := Vector2(art.anchor[0], art.anchor[1])
		var box: Array = art.visible
		for point in [Vector2(box[0], box[1]), Vector2(box[2], box[3])]:
			var local := Vector3((point.x - anchor.x) * px_to_m * card.facing, (anchor.y - point.y) * px_to_m, 0)
			corners.append(camera.unproject_position(card.global_position + local))
	else:
		var size: Vector2 = (card.mesh as QuadMesh).size
		var offset: Vector3 = (card.mesh as QuadMesh).center_offset
		corners.append(camera.unproject_position(card.global_position + Vector3(offset.x - size.x * 0.3, offset.y + size.y * 0.5, 0)))
		corners.append(camera.unproject_position(card.global_position + Vector3(offset.x + size.x * 0.3, 0, 0)))
	var low := Vector2(minf(corners[0].x, corners[1].x), minf(corners[0].y, corners[1].y))
	var high := Vector2(maxf(corners[0].x, corners[1].x), maxf(corners[0].y, corners[1].y))
	return Rect2(low, (high - low).max(Vector2(48, 24)))


## As áreas do clique de cada um: o corpo visível; onde dois se encostam na tela, a área se divide no meio da sobra,
## para cada clique ser de um só (a regra do contrato da #80).
func click_rects(camera: Camera3D) -> Dictionary:
	var out := {}
	for member in camp.members:
		if is_instance_valid(member.card):
			out[member.hero_id] = body_rect(camera, member.card)
	var ids: Array = out.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: Rect2 = out[ids[i]]
			var b: Rect2 = out[ids[j]]
			if not a.intersects(b):
				continue
			var left_id: String = ids[i] if a.get_center().x <= b.get_center().x else ids[j]
			var right_id: String = ids[j] if left_id == ids[i] else ids[i]
			var left: Rect2 = out[left_id]
			var right: Rect2 = out[right_id]
			var middle := (maxf(left.position.x, right.position.x) + minf(left.end.x, right.end.x)) * 0.5
			left.size.x = maxf(middle - left.position.x, 24.0)
			right.size.x = maxf(right.end.x - middle, 24.0)
			right.position.x = middle
			out[left_id] = left
			out[right_id] = right
	return out


## Interagir (E, o A do controle) confirma o botão com foco, como na luta. Esquerda e direita trocam de herói uma vez por
## toque: o analógico só troca de novo depois de voltar ao centro, e segurar a tecla não gira a roda.
func _input(event: InputEvent) -> void:
	if not camp.active or not is_visible_in_tree():
		return
	# Com o menu ou a Mochila abertos por cima, as teclas são deles.
	var parent := get_parent()
	if parent != null and parent.has_method("modal_open") and parent.modal_open():
		return
	# A habilidade de aliado esperando o alvo: Interagir escolhe o herói escolhido; Esc desiste.
	if not targeting.is_empty():
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			if camp.selected_id() != String(targeting.user):
				_choose_target(camp.selected_id())
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
			cancel_target()
			get_viewport().set_input_as_handled()
			return
	if AHUiStyle.press_focused(self, event):
		get_viewport().set_input_as_handled()
		return
	# O eixo do analógico casa com as duas ações (esquerda e direita): cada lado olha só o seu.
	var handled := false
	for pair in [[-1, ["move_left", "ui_left"]], [1, ["move_right", "ui_right"]]]:
		for action in pair[1]:
			if not event.is_action(action):
				continue
			handled = true
			if event.is_action_pressed(action):
				if _held != pair[0]:
					_held = pair[0]
					camp.step(pair[0])
			elif event.is_action_released(action) and _held == pair[0]:
				_held = 0
	if handled:
		get_viewport().set_input_as_handled()


## A resposta no herói: o número verde (vida) e o do instinto subindo, o efeito e o som. Só a cena: os números já são
## os das regras (o que a vida e o instinto mudaram).
func respond(hero_id: String, kind: String, life_gain: int, instinct_change: int) -> void:
	var card := camp.member_card(hero_id)
	var camera := get_viewport().get_camera_3d()
	if card == null or camera == null:
		return
	var rect := body_rect(camera, card)
	var head := Vector2(rect.get_center().x, rect.position.y)
	var hero = Campaign.hero(hero_id)
	var file := FOOD_EFFECT if kind == "food" else (AMPOULE_EFFECT if hero != null and hero.id == "hero_sapo_iris" else BANDAGE_EFFECT)
	Sound.play(FOOD_SOUND if kind == "food" else BANDAGE_SOUND, 0.8)
	var reduced := GameFlow.reduced_effects()
	var effect := TextureRect.new()
	effect.name = "Effect"
	effect.add_to_group("camp_effect")
	effect.texture = load(file)
	effect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	effect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	effect.size = Vector2(EFFECT_SIZE, EFFECT_SIZE)
	effect.pivot_offset = effect.size * 0.5
	effect.position = head - Vector2(EFFECT_SIZE * 0.5, EFFECT_SIZE + 4)
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(effect)
	var numbers: Array = []
	if life_gain > 0:
		numbers.append(["+%d" % life_gain, AHKit.good(), "card_name"])
	if instinct_change != 0:
		numbers.append([tr("%+d instinto") % instinct_change, AHKit.INSTINCT.lightened(0.3), "text"])
	var labels: Array = []
	for i in numbers.size():
		var label := AHKit.label(numbers[i][0], numbers[i][2], numbers[i][1], true)
		label.name = "Gain"
		label.add_to_group("camp_gain")
		label.add_theme_constant_override("outline_size", 6)
		label.add_theme_color_override("font_outline_color", AHKit.STEEL)
		add_child(label)
		label.reset_size()
		label.position = head + Vector2(EFFECT_SIZE * 0.5 + 6, -EFFECT_SIZE + i * 30)
		labels.append(label)
	var nodes: Array = [effect] + labels
	if reduced:
		# Reduzir efeitos: parados por 400 ms, sem subir nem crescer.
		await get_tree().create_timer(EFFECT_REDUCED_MS / 1000.0).timeout
	else:
		effect.modulate.a = 0.0
		effect.scale = Vector2(0.8, 0.8)
		var tween := create_tween().set_parallel()
		tween.tween_property(effect, "modulate:a", 1.0, 0.1)
		tween.tween_property(effect, "scale", Vector2.ONE, 0.1)
		for node in nodes:
			tween.tween_property(node, "position:y", node.position.y - 20, EFFECT_MS / 1000.0)
			tween.tween_property(node, "modulate:a", 0.0, 0.2).set_delay(0.4)
		await tween.finished
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()
