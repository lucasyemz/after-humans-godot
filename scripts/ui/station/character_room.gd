## A Sala dos Personagens no kit (#60, docs/design/hud-station.md): a tela inteira, com o cômodo ao fundo.
## - No alto: a plaqueta da Estação, Comida, Água e Energia, e a engrenagem (as Opções).
## - À esquerda: as abas dos heróis (e a de recrutar, com o Memorial), as HABILIDADES e o detalhe da escolhida.
## - No meio: o herói de corpo inteiro (a pose idle), sobre a sombra e um escurecido.
## - À direita: o painel PERSONAGEM (Fundador ou Recruta, o nível e o XP, o Treino, a vida, a velocidade e o instinto, a
##   relíquia, os contadores e os traços).
## - Embaixo: VOLTAR, as teclas, as abas da Estação e PREPARAR EXPEDIÇÃO (G/X, a ação station_prepare).
## O Treino abre o diálogo com as duas melhorias. As ações passam pelo HUD da Estação (hud), que mostra o aviso e salva.
class_name AHCharacterRoom
extends Control

const S := preload("res://scripts/flow/station_rules.gd")
const LEFT := Rect2(28, 132, 600, 772)
const RIGHT := Rect2(1296, 132, 596, 844)
const DIALOG := Rect2(620, 250, 680, 0)
const RECRUIT := "+recruit"
const MAX_INSTINCT := 200
const RELIC_ICONS := {"botao_cobre": "relic-copper-button", "pena_vidro": "relic-glass-feather", "coleira_lembranca": "relic-memory-collar"}
const TARGETS := {"SingleEnemy": "Inimigo", "SingleAlly": "Aliado", "SingleOtherAlly": "Outro aliado", "Self": "Si mesmo"}

## O HUD da Estação (refuge_hud): as ações, os avisos e as outras telas.
var hud: Control
var selected := ""
var ability := ""
var training := false
var _upgrade := ""
var _first_focus: Control
var _trait_ids := {}


static func make(owner: Control) -> AHCharacterRoom:
	var screen := AHCharacterRoom.new()
	screen.hud = owner
	screen.name = "CharacterRoom"
	return screen


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(AHKit.MANIFESTS[1]))
	_trait_ids = manifest.get("trait_ids", {})
	rebuild()


## Refaz a tela com os dados de agora (depois de treinar, trocar a relíquia, recrutar), na mesma escolha.
func rebuild() -> void:
	var owner := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	var focus_path := get_path_to(owner) if owner != null and is_ancestor_of(owner) else NodePath("")
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var c: Dictionary = Campaign.state
	var living: Array = S.living(c)
	if selected != RECRUIT and (selected == "" or S.hero(c, selected) == null or not S.hero(c, selected).alive):
		selected = living[0].id if not living.is_empty() else RECRUIT
	_first_focus = null
	_top(c)
	if selected != RECRUIT:
		_stage(S.hero(c, selected))
	_left(c)
	if selected != RECRUIT:
		_right(c, S.hero(c, selected))
	_bottom(c)
	# O painel PERSONAGEM termina acima de PREPARAR EXPEDIÇÃO (que cresce com o motivo do bloqueio e no Maior).
	var right := get_node_or_null("Right") as Control
	var prepare := get_node_or_null("Prepare") as Control
	if right != null and prepare != null:
		right.size.y = minf(RIGHT.size.y, prepare.position.y - 12.0 - RIGHT.position.y)
		right.custom_minimum_size.y = right.size.y
	if training and selected != RECRUIT:
		_training_dialog(c, S.hero(c, selected))
	var again := get_node_or_null(focus_path) if not focus_path.is_empty() else null
	var target: Control = again if again is Control and (again as Control).focus_mode != Control.FOCUS_NONE else _first_focus
	if target != null and AHUiStyle.using_keys:
		target.grab_focus.call_deferred()


func restyle() -> void:
	rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if training and AHUiStyle.is_back(event):
		get_viewport().set_input_as_handled()
		training = false
		rebuild()


# ---------------------------------------------------------------- o alto

func _top(c: Dictionary) -> void:
	AHStationFrame.top(self, c, tr("Sala dos Personagens"), func(): hud.open_from_room("options"))


# ---------------------------------------------------------------- o herói no meio

## O herói de corpo inteiro: a pose idle, sobre a sombra no chão e um escurecido atrás (a câmera do cômodo não chega a
## esse tamanho).
func _stage(hero: Dictionary) -> void:
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(AHKit.SHADE, 0.55))
	gradient.set_color(1, Color(AHKit.SHADE, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.55)
	texture.fill_to = Vector2(1.0, 0.55)
	shade.texture = texture
	shade.position = Vector2(628, 120)
	shade.size = Vector2(668, 860)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var ground := TextureRect.new()
	var ground_gradient := Gradient.new()
	ground_gradient.set_color(0, Color(AHKit.SHADE, 0.6))
	ground_gradient.set_color(1, Color(AHKit.SHADE, 0.0))
	var ground_texture := GradientTexture2D.new()
	ground_texture.gradient = ground_gradient
	ground_texture.fill = GradientTexture2D.FILL_RADIAL
	ground_texture.fill_from = Vector2(0.5, 0.5)
	ground_texture.fill_to = Vector2(1.0, 0.5)
	ground.texture = ground_texture
	ground.position = Vector2(962 - 220, 858)
	ground.size = Vector2(440, 64)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	var figure := Figure.new()
	figure.name = "Hero"
	figure.art = AHCombatArena.hero_art_of(hero.id, String(hero.get("art_variant", ""))).get("idle", {})
	# Os pés no chão do meio (y 890), o corpo na altura do herói (o de referência, 1,64 m, com 620 px).
	figure.body_px = 620.0 * AHCharacterHeights.find(hero.id) / AHCharacterHeights.REFERENCE
	figure.feet = Vector2(962, 890)
	add_child(figure)


## O herói de corpo inteiro na interface: a arte idle do manifesto (com os quadros da respiração), o pé na âncora.
class Figure extends Control:
	var art := {}
	var body_px := 620.0
	var feet := Vector2.ZERO
	var _texture: Texture2D
	var _frame := 0
	var _time := 0.0

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_texture = load(art.file) if art.has("file") else null

	func _process(delta: float) -> void:
		if not art.has("frames"):
			return
		_time += delta
		var step := 1.0 / float(art.get("fps", 10))
		if _time >= step:
			_time -= step
			_frame = (_frame + 1) % art.frames.size()
			queue_redraw()

	func _draw() -> void:
		if _texture == null:
			return
		var canvas := Vector2(art.canvas[0], art.canvas[1])
		var region := Rect2(Vector2.ZERO, canvas)
		var texture_scale := float(_texture.get_width()) / canvas.x
		if art.has("frames"):
			var f: Array = art.frames[_frame]
			region = Rect2(f[0], f[1], f[2], f[3])
			texture_scale = 1.0
		var scale := body_px / float(art.body_reference_pixels)
		var anchor := Vector2(art.anchor[0], art.anchor[1])
		draw_texture_rect_region(_texture, Rect2(feet - anchor * scale, region.size * scale),
			Rect2(region.position * texture_scale, region.size * texture_scale))


# ---------------------------------------------------------------- a coluna da esquerda

func _left(c: Dictionary) -> void:
	var panel := AHKit.panel_box("large")
	panel.name = "Left"
	panel.position = LEFT.position
	panel.size = LEFT.size
	panel.custom_minimum_size = LEFT.size
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var tabs := HFlowContainer.new()
	tabs.name = "Heroes"
	tabs.add_theme_constant_override("h_separation", 14)
	tabs.add_theme_constant_override("v_separation", 10)
	column.add_child(tabs)
	for entry in S.living(c):
		tabs.add_child(_hero_tab(entry))
	column.add_child(_divider())
	if selected == RECRUIT:
		_recruit_list(c, column)
		return
	var hero = S.hero(c, selected)
	column.add_child(AHKit.label(tr("Habilidades"), "panel_title", AHKit.TEXT, true, true))
	var hero_class = GameData.row("classes", String(hero.class_id))
	var ids: Array = hero_class.get("AbilityIds", []) if hero_class != null else []
	if ability == "" or not ids.has(ability):
		ability = ids[0] if not ids.is_empty() else ""
	for ability_id in ids:
		column.add_child(_ability_row(ability_id))
	if ability != "":
		column.add_child(_ability_detail(c, hero, ability))


func _hero_tab(entry: Dictionary) -> Button:
	var tab := Button.new()
	tab.name = "Tab_%s" % entry.id
	tab.toggle_mode = false
	AHKit.style_as(tab, "hero_selected" if entry.id == selected else "hero")
	tab.custom_minimum_size = Vector2(116, 132)
	tab.clip_contents = true
	tab.set_meta("hero_id", entry.id)
	var face := TextureRect.new()
	face.texture = AHUiStyle.face_texture(AHCombatArena.hero_art_of(entry.id, String(entry.get("art_variant", ""))).get("idle", {}))
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.position = Vector2(6, 6)
	face.size = Vector2(104, 92)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.add_child(face)
	var name := AHKit.label(String(entry.display_name), "small" if AHUiStyle.text_scale > 1.2 else "tab", AHKit.AMBER if entry.id == selected else AHKit.TEXT)
	name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.position = Vector2(4, 98)
	name.size = Vector2(108, 30)
	tab.add_child(name)
	tab.tooltip_text = String(entry.display_name)
	var id: String = entry.id
	tab.pressed.connect(func(): _select(id))
	if entry.id == selected:
		_first_focus = tab
	return tab


## Recrutar e o Memorial: o botão ao lado de VOLTAR (as quatro abas dos heróis enchem a coluna, como no alvo).
func _recruit_button() -> Button:
	var button := Button.new()
	button.name = "Tab_recruit"
	button.text = ("+ " + tr("Recrutar")).to_upper()
	button.tooltip_text = tr("Recrutar e Memorial")
	AHKit.style_as(button, "secondary")
	button.add_theme_font_override("font", AHKit.font(true))
	button.add_theme_font_size_override("font_size", AHKit.size("primary"))
	if selected == RECRUIT:
		for state in ["font_color", "font_hover_color", "font_focus_color"]:
			button.add_theme_color_override(state, AHKit.AMBER)
	button.custom_minimum_size = Vector2(216, 64)
	button.pressed.connect(func(): _select(RECRUIT))
	if selected == RECRUIT:
		_first_focus = button
	return button


func _select(hero_id: String) -> void:
	if hero_id == selected:
		return
	Sound.play("res://audio/ui/click.ogg", 0.6, 1.0, "UI") if ResourceLoader.exists("res://audio/ui/click.ogg") else null
	selected = hero_id
	ability = ""
	training = false
	rebuild()
	var tab := find_child("Tab_%s" % ("recruit" if hero_id == RECRUIT else hero_id), true, false) as Control
	if tab != null:
		tab.grab_focus.call_deferred()


func _ability_row(ability_id: String) -> Button:
	var row := Button.new()
	row.name = "Ability_%s" % ability_id
	var data = GameData.row("abilities", ability_id)
	row.text = tr(String(data.DisplayName)) if data != null else ability_id
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var path := AHCombatArena.icon_of(ability_id)
	row.icon = load(path) if path != "" else null
	row.expand_icon = true
	row.add_theme_constant_override("icon_max_width", 44)
	row.add_theme_constant_override("h_separation", 14)
	AHKit.style_as(row, "list_selected" if ability_id == ability else "list")
	row.add_theme_font_override("font", AHKit.font(false))
	row.add_theme_font_size_override("font_size", AHKit.size("row"))
	row.custom_minimum_size = Vector2(0, 60)
	var id := ability_id
	row.pressed.connect(func():
		ability = id
		rebuild())
	return row


## O detalhe da habilidade: o nome, a faixa (com o treino da Pesquisa e as melhorias do nível), as posições, o texto e
## em quem ela vale.
func _ability_detail(c: Dictionary, hero: Dictionary, ability_id: String) -> PanelContainer:
	var data = GameData.row("abilities", ability_id)
	var inset := AHKit.panel_box("inset")
	inset.name = "Detail"
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	inset.add_child(box)
	if data == null:
		return inset
	box.add_child(AHKit.label(tr(String(data.DisplayName)), "panel_title", AHKit.TEXT, true))
	var bonus := (1 if c.get("researched_skills", []).has(ability_id) else 0) + int(AHHeroLevels.combat_bonus(hero).get("abilities", {}).get(ability_id, 0))
	var star := " ★" if bonus > 0 else ""
	var damage: Dictionary = data.get("DamageRange", {})
	var heal: Dictionary = data.get("HealRange", {})
	if int(damage.get("Max", 0)) > 0:
		box.add_child(AHKit.label(tr("Dano %d–%d") % [int(damage.Min) + bonus, int(damage.Max) + bonus] + star, "card_name", AHKit.AMBER, true))
	elif int(heal.get("Max", 0)) > 0:
		box.add_child(AHKit.label(tr("Cura %d–%d") % [int(heal.Min) + bonus, int(heal.Max) + bonus] + star, "card_name", AHKit.good(), true))
	var ranks := HFlowContainer.new()
	ranks.add_theme_constant_override("h_separation", 24)
	ranks.add_child(AHKit.label(tr("Origem: posições %s") % " · ".join(data.get("OriginRanks", []).map(func(r): return str(int(r)))), "text", AHKit.MUTED))
	if String(data.TargetType) != "Self":
		ranks.add_child(AHKit.label(tr("Alvo: posições %s") % " · ".join(data.get("TargetRanks", []).map(func(r): return str(int(r)))), "text", AHKit.MUTED))
	box.add_child(ranks)
	var text := AHKit.label(tr(String(data.Description)), "text", AHKit.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(480, 0)
	box.add_child(text)
	var enemy: bool = String(data.TargetType) == "SingleEnemy"
	box.add_child(AHKit.label(tr(TARGETS.get(String(data.TargetType), "")), "text", AHKit.alert_text() if enemy else AHKit.good()))
	return inset


## Recrutar (as classes liberadas, de graça com o voluntário) e o Memorial.
func _recruit_list(c: Dictionary, column: VBoxContainer) -> void:
	column.add_child(AHKit.label(tr("Recrutar"), "panel_title", AHKit.TEXT, true, true))
	column.add_child(AHKit.label(tr("Elenco: %d de %d") % [S.living(c).size(), S.MAX_ROSTER], "text", AHKit.MUTED))
	for class_id in c.unlocked_classes:
		var hero_class = GameData.row("classes", class_id)
		var free := S.can_recruit_volunteer(c, class_id)
		var id: String = class_id
		var button := Button.new()
		button.text = "%s · %s" % [tr(hero_class.DisplayName) if hero_class else class_id, tr("voluntário, de graça") if free else tr("%d sementes") % S.RECRUIT_COST]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		AHKit.style_as(button, "list")
		button.add_theme_font_override("font", AHKit.font(false))
		button.add_theme_font_size_override("font_size", AHKit.size("row"))
		button.custom_minimum_size = Vector2(0, 60)
		button.disabled = not (free or S.quantity(c, "seeds") >= S.RECRUIT_COST)
		button.pressed.connect(func(): hud._recruit(id))
		column.add_child(button)
	if c.memorial.is_empty():
		return
	column.add_child(_divider())
	column.add_child(AHKit.label(tr("Memorial"), "panel_title", AHKit.TEXT, true, true))
	for entry in c.memorial:
		var line := AHKit.label("%s · %s · %s" % [entry.display_name, tr(entry.get("mission_name", "")), AHCombatEngine.cause_text(entry.get("cause", ""))], "text", AHKit.MUTED)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(500, 0)
		column.add_child(line)


func _divider() -> TextureRect:
	var line := TextureRect.new()
	line.texture = AHKit.texture("divider")
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.custom_minimum_size = Vector2(0, 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


# ---------------------------------------------------------------- o painel PERSONAGEM

func _right(c: Dictionary, hero: Dictionary) -> void:
	var panel := AHKit.panel_box("large")
	panel.name = "Right"
	panel.position = RIGHT.position
	panel.size = RIGHT.size
	panel.custom_minimum_size = RIGHT.size
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var title := AHKit.label(tr("Personagem"), "panel_title", AHKit.TEXT, true, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.name = "Close"
	close.text = "X"
	close.tooltip_text = tr("Voltar")
	AHKit.style_as(close, "icon")
	close.add_theme_font_override("font", AHKit.font(true))
	close.add_theme_font_size_override("font_size", AHKit.size("tab"))
	close.custom_minimum_size = Vector2(56, 56)
	close.pressed.connect(func(): hud.close_panel())
	head.add_child(close)
	column.add_child(_divider())
	# Fundador nos quatro do começo, Recruta em quem veio pelo trem (decisão do Lucas).
	column.add_child(AHKit.label(tr("Recruta") if AHHeroLevels.is_recruit(hero) else tr("Fundador"), "text", AHKit.AMBER, true, true))
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 18)
	column.add_child(name_row)
	var name := AHKit.label(String(hero.display_name), "panel_hero", AHKit.TEXT, true)
	name.name = "Name"
	name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_row.add_child(name)
	name_row.add_child(_medal(AHHeroLevels.level(hero)))
	var level_box := VBoxContainer.new()
	level_box.add_theme_constant_override("separation", 4)
	level_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(level_box)
	var cost := AHHeroLevels.next_cost(hero)
	if cost.is_empty():
		level_box.add_child(AHKit.label(tr("Nível %d · máximo") % AHHeroLevels.level(hero), "small", AHKit.MUTED, false, true))
	else:
		level_box.add_child(AHKit.label(tr("Nível %d · XP %d / %d") % [AHHeroLevels.level(hero), AHHeroLevels.xp(hero), cost.xp], "small", AHKit.MUTED, false, true))
		var xp := AHKit.bar("xp", mini(AHHeroLevels.xp(hero), cost.xp), cost.xp)
		xp.name = "Xp"
		xp.custom_minimum_size = Vector2(170, 22)
		xp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		level_box.add_child(xp)
	var hero_class = GameData.row("classes", String(hero.class_id))
	if hero_class != null:
		var line := AHKit.label("%s · %s" % [tr(String(hero_class.DisplayName)), tr(String(hero_class.Role))], "row", AHKit.AMBER)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(300, 0)
		column.add_child(line)
	# As melhorias escolhidas nos treinos, com quantas vezes cada uma.
	var counts := {}
	for upgrade_id in hero.get("upgrades", []):
		counts[upgrade_id] = int(counts.get(upgrade_id, 0)) + 1
	var chosen: Array = []
	for upgrade_id in counts:
		var upgrade = GameData.row("hero_upgrades", upgrade_id)
		if upgrade != null:
			chosen.append(tr("%s ×%d") % [tr(upgrade.DisplayName), counts[upgrade_id]])
	if not chosen.is_empty():
		var upgrades := AHKit.label(tr("Melhorias: %s") % ", ".join(chosen), "small", AHKit.MUTED)
		upgrades.name = "Upgrades"
		upgrades.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		upgrades.custom_minimum_size = Vector2(300, 0)
		column.add_child(upgrades)
	var state_row := HFlowContainer.new()
	state_row.add_theme_constant_override("h_separation", 14)
	state_row.add_theme_constant_override("v_separation", 8)
	column.add_child(state_row)
	var pill := AHKitPill.make(int(hero.hp), int(hero.max_hp))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	state_row.add_child(pill)
	state_row.add_child(_train_button(c, hero))
	# A vida, a velocidade e o instinto.
	var life := HBoxContainer.new()
	life.add_theme_constant_override("separation", 10)
	life.add_child(AHKit.label(tr("Vida"), "row", AHKit.TEXT, true, true))
	life.add_child(AHKit.label("%d / %d" % [hero.hp, hero.max_hp], "row", AHKit.TEXT, true))
	column.add_child(life)
	var life_bar := AHKit.bar("life", hero.hp, hero.max_hp)
	life_bar.name = "Life"
	life_bar.custom_minimum_size = Vector2(0, 28)
	column.add_child(life_bar)
	var stats := HFlowContainer.new()
	stats.add_theme_constant_override("h_separation", 30)
	stats.add_child(AHKit.label(tr("Velocidade %d") % _speed(hero), "row", AHKit.TEXT, true, true))
	stats.add_child(AHKit.label(tr("Instinto %d / %d") % [int(hero.instinct), MAX_INSTINCT], "row", AHKit.TEXT, true, true))
	column.add_child(stats)
	var instinct := AHKit.bar("instinct", int(hero.instinct), MAX_INSTINCT)
	instinct.name = "Instinct"
	instinct.custom_minimum_size = Vector2(0, 28)
	column.add_child(instinct)
	column.add_child(_divider())
	_relic(c, hero, column)
	if hero.get("trauma", false):
		var trauma := HBoxContainer.new()
		trauma.add_theme_constant_override("separation", 12)
		var note := AHKit.label(tr("Trauma da última crise"), "text", AHKit.alert_text())
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		trauma.add_child(note)
		var treat := _small_button(tr("Tratar (%d sementes)") % S.TRAUMA_COST)
		var id: String = hero.id
		treat.pressed.connect(func(): hud._act(S.treat_trauma(Campaign.state, id), tr("Trauma tratado.")))
		trauma.add_child(treat)
		column.add_child(trauma)
	var counters := HBoxContainer.new()
	counters.add_theme_constant_override("separation", 10)
	counters.add_child(AHKit.glyph("expeditions", 28, AHKit.MUTED))
	counters.add_child(AHKit.label(tr("Expedições %d") % int(hero.get("completed_expeditions", 0)), "text", AHKit.TEXT))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(20, 0)
	counters.add_child(gap)
	counters.add_child(AHKit.glyph("kills", 28, AHKit.MUTED))
	counters.add_child(AHKit.label(tr("Abates %d") % int(hero.get("kills_count", 0)), "text", AHKit.TEXT))
	column.add_child(counters)
	column.add_child(_divider())
	_traits(hero, column)


func _medal(level: int) -> Control:
	var medal := TextureRect.new()
	medal.name = "Medal"
	medal.texture = AHKit.texture("level_medal")
	medal.custom_minimum_size = Vector2(72, 72)
	medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var number := AHKit.label(str(level), "panel_hero", AHKit.AMBER, true)
	number.add_theme_font_size_override("font_size", AHKit.size("card_name"))
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.set_anchors_preset(Control.PRESET_FULL_RECT)
	medal.add_child(number)
	return medal


## TREINAR com o custo; bloqueado, apagado e com o que falta (o motivo inteiro na dica).
func _train_button(c: Dictionary, hero: Dictionary) -> Button:
	var button := Button.new()
	button.name = "Train"
	var cost := AHHeroLevels.next_cost(hero)
	var block := AHHeroLevels.train_block(c, hero)
	var detail := ""
	if cost.is_empty():
		detail = tr("nível máximo")
	elif AHHeroLevels.xp(hero) < int(cost.xp):
		detail = tr("faltam %d XP") % (int(cost.xp) - AHHeroLevels.xp(hero))
	elif block != "":
		detail = tr("faltam sementes") if S.quantity(c, "seeds") < int(cost.seeds) else block
	else:
		detail = tr("1 semente") if int(cost.seeds) == 1 else tr("%d sementes") % cost.seeds
	button.text = "%s  %s" % [tr("Treinar").to_upper(), detail]
	button.icon = AHKit.icon("train")
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", 30)
	AHKit.style_as(button, "train")
	button.add_theme_font_override("font", AHKit.font(true))
	button.add_theme_font_size_override("font_size", AHKit.size("tab"))
	button.add_theme_color_override("icon_normal_color", AHKit.AMBER)
	button.custom_minimum_size = Vector2(240, 56)
	button.disabled = block != ""
	button.tooltip_text = block
	button.pressed.connect(func():
		training = true
		_upgrade = ""
		rebuild())
	return button


func _speed(hero: Dictionary) -> int:
	var hero_class = GameData.row("classes", String(hero.class_id))
	var speed := int(hero_class.get("BaseSpeed", 0)) if hero_class != null else 0
	for perk_id in hero.get("perks", []):
		var perk = GameData.row("perks", perk_id)
		if perk != null:
			speed += int(perk.get("Speed", 0))
	return speed + int(AHHeroLevels.combat_bonus(hero).get("speed", 0))


func _relic(c: Dictionary, hero: Dictionary, column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var relic = GameData.row("relics", String(hero.get("relic_id", ""))) if String(hero.get("relic_id", "")) != "" else null
	if relic != null:
		var icon := TextureRect.new()
		icon.texture = AHKit.legacy_icon(RELIC_ICONS.get(String(hero.relic_id), "relic-generic"))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(36, 36)
		icon.modulate = AHKit.AMBER
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(icon)
	else:
		var empty := AHKit.glyph("relic_empty", 36, AHKit.MUTED)
		empty.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(empty)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(AHKit.label(tr("Relíquia: %s") % (tr(String(relic.DisplayName)) if relic != null else tr("Sem relíquia")), "row", AHKit.TEXT))
	var hint := AHKit.label(tr(String(relic.get("Description", ""))) if relic != null else tr("Equipe uma relíquia ao preparar a expedição."), "small", AHKit.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(260, 0)
	text.add_child(hint)
	if not c.inventory.relics.is_empty() or relic != null:
		var swap := _small_button(tr("Trocar"))
		swap.name = "Relic"
		var id: String = hero.id
		swap.pressed.connect(func(): hud._cycle_relic(id))
		row.add_child(swap)


func _small_button(text: String) -> Button:
	var button := Button.new()
	button.text = text.to_upper()
	AHKit.style_as(button, "secondary")
	button.add_theme_font_override("font", AHKit.font(true))
	button.add_theme_font_size_override("font_size", AHKit.size("text"))
	button.custom_minimum_size = Vector2(0, 56)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return button


## Os traços: os pontos fortes e fracos em duas colunas, com o ícone pintado no quadrado, o nome e o efeito; o + e o −
## também separam as colunas no daltonismo.
func _traits(hero: Dictionary, column: VBoxContainer) -> void:
	column.add_child(AHKit.label(tr("Traços"), "panel_title", AHKit.TEXT, true, true))
	var sides := HBoxContainer.new()
	sides.name = "Traits"
	sides.add_theme_constant_override("separation", 16)
	column.add_child(sides)
	for positive in [true, false]:
		var side := VBoxContainer.new()
		side.add_theme_constant_override("separation", 10)
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sides.add_child(side)
		var color: Color = AHKit.good() if positive else AHKit.alert_text()
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		var sign := AHKit.label("+" if positive else "−", "text", AHKit.STEEL, true)
		sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sign.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var square := AHKit.panel(AHKit.piece_of("chip", "cost"), color)
		square.custom_minimum_size = Vector2(24, 24)
		square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		square.add_child(sign)
		head.add_child(square)
		head.add_child(AHKit.label(tr("Pontos fortes") if positive else tr("Pontos fracos"), "text", color, true, true))
		side.add_child(head)
		var count := 0
		for perk_id in hero.get("perks", []):
			var perk = GameData.row("perks", perk_id)
			if perk == null or bool(perk.get("bPositive", false)) != positive:
				continue
			count += 1
			side.add_child(_trait(perk, color))
		if count == 0:
			side.add_child(AHKit.label(tr("Nenhum"), "text", AHKit.MUTED))


func _trait(perk: Dictionary, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.tooltip_text = tr(String(perk.get("Condition", "")))
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var tile := AHKit.chip("trait")
	tile.custom_minimum_size = Vector2(80, 80)
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = AHKit.icon(String(_trait_ids.get(String(perk.Name), "")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(icon)
	row.add_child(tile)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var name := AHKit.label(tr(String(perk.DisplayName)), "row", color, true)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.custom_minimum_size = Vector2(110, 0)
	text.add_child(name)
	var effect := AHKit.label(tr(String(perk.Description)), "small", AHKit.TEXT)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.custom_minimum_size = Vector2(110, 0)
	text.add_child(effect)
	return row


# ---------------------------------------------------------------- o Treino

## O diálogo do Treino: as duas melhorias da espécie (a escolhida com a moldura âmbar), CANCELAR e TREINAR.
func _training_dialog(c: Dictionary, hero: Dictionary) -> void:
	var options := AHHeroLevels.options(hero)
	if options.is_empty() or AHHeroLevels.train_block(c, hero) != "":
		training = false
		return
	if _upgrade == "" or not options.any(func(o): return o.Name == _upgrade):
		_upgrade = options[0].Name
	var dim := ColorRect.new()
	dim.color = Color(AHKit.SHADE, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var dialog := AHKit.panel_box("large")
	dialog.name = "Training"
	dialog.position = DIALOG.position
	dialog.custom_minimum_size = Vector2(DIALOG.size.x, 0)
	add_child(dialog)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	dialog.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(AHKit.glyph("train", 36, AHKit.AMBER))
	head.add_child(AHKit.label(tr("Treino · nível %d") % (AHHeroLevels.level(hero) + 1), "panel_title", AHKit.TEXT, true, true))
	column.add_child(head)
	var cost := AHHeroLevels.next_cost(hero)
	var intro := AHKit.label(tr("Escolha uma melhoria. O treino gasta o XP do nível e %s.") % (tr("1 semente") if int(cost.seeds) == 1 else tr("%d sementes") % cost.seeds), "text", AHKit.TEXT)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(600, 0)
	column.add_child(intro)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	column.add_child(cards)
	var first: Button
	for option in options:
		var card := Button.new()
		card.name = "Upgrade_%s" % option.Name
		AHKit.style_as(card, "upgrade_selected" if option.Name == _upgrade else "upgrade")
		card.custom_minimum_size = Vector2(296, 200)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 24
		box.offset_top = 22
		box.offset_right = -24
		box.offset_bottom = -22
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(box)
		box.add_child(AHKit.label(tr(String(option.DisplayName)), "ability_name", AHKit.AMBER if option.Name == _upgrade else AHKit.TEXT, true))
		var effect := AHKit.label(tr(String(option.Description)), "text", AHKit.TEXT)
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect.custom_minimum_size = Vector2(240, 0)
		box.add_child(effect)
		box.add_child(AHKit.label(tr("Já tem: %d") % AHHeroLevels.stacks(hero, option.Name), "small", AHKit.MUTED))
		var id: String = option.Name
		card.pressed.connect(func():
			_upgrade = id
			rebuild()
			var again := find_child("Upgrade_%s" % id, true, false) as Control
			if again != null:
				again.grab_focus.call_deferred())
		cards.add_child(card)
		if first == null or option.Name == _upgrade:
			first = card
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.text = tr("Cancelar").to_upper()
	AHKit.style_as(cancel, "secondary")
	cancel.add_theme_font_override("font", AHKit.font(true))
	cancel.add_theme_font_size_override("font_size", AHKit.size("primary"))
	cancel.custom_minimum_size = Vector2(0, 64)
	cancel.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var cancel_key := AHKitKey.make("", "Esc / B", "button")
	cancel_key.name = "Key"
	cancel.add_child(cancel_key)
	cancel.pressed.connect(func():
		training = false
		rebuild())
	buttons.add_child(cancel)
	var confirm := AHStationReport._primary(tr("Treinar"), "train", "interact")
	confirm.name = "Confirm"
	confirm.custom_minimum_size = Vector2(0, 64)
	var hero_id: String = hero.id
	confirm.pressed.connect(func():
		training = false
		hud._train_hero(hero_id, _upgrade))
	buttons.add_child(confirm)
	_fit_keys([cancel, confirm])
	_first_focus = first


## A tecla no fim de cada botão do diálogo.
func _fit_keys(buttons: Array) -> void:
	for button in buttons:
		if is_instance_valid(button):
			AHStationReport.fit_key(button, 52.0 if button.name == "Confirm" else 14.0)


# ---------------------------------------------------------------- embaixo

func _bottom(c: Dictionary) -> void:
	var back := AHStationFrame.back_button(self, func(): hud.close_panel())
	var recruit := _recruit_button()
	add_child(recruit)
	recruit.reset_size()
	recruit.position = Vector2(back.position.x + maxf(216.0, back.get_combined_minimum_size().x) + 12.0, AHStationFrame.BACK_Y)
	# As teclas entre os dois painéis (Voltar mostra o Esc: ui_cancel volta sempre, com qualquer troca nas Opções).
	AHStationFrame.keys(self, [[tr("Setas"), tr("Navegar")], ["interact", tr("Selecionar")], ["Esc", tr("Voltar")],
		["hide_hud", tr("Ocultar")]], 962.0, LEFT.end.x + 12.0, RIGHT.position.x - 12.0)
	AHStationFrame.tabs(self, "characters", _nav)
	AHStationFrame.prepare(self, tr("Preparar expedição"), "station", S.preparation_block(c), func(): hud.open_map())


func _nav(id: String) -> void:
	match id:
		"overview":
			hud.close_panel()
		"facilities":
			hud.open_from_room("plan")
		"research":
			hud.open_room(S.RESEARCH)
		"hide":
			hud.set_hud_hidden(true)
