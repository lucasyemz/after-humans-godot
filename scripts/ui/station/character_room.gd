## A Sala dos Personagens no kit (#60, docs/design/hud-station.md): a tela inteira, com o cômodo ao fundo.
## - No alto: a plaqueta da Estação, Comida, Água e Energia, e a engrenagem (as Opções).
## - À esquerda: as abas dos heróis (e a de recrutar), as HABILIDADES e o detalhe da escolhida.
## - No meio: o cômodo com o herói escolhido de pé nele (a placa da Estação, #181).
## - À direita: o painel PERSONAGEM (Fundador ou Recruta, o nível e o XP, o Treino, a vida, a velocidade e o instinto, a
##   relíquia, os contadores e os traços).
## - Embaixo: VOLTAR, as teclas, as abas da Estação e IR AO MAPA (G/X, a ação station_prepare).
## O Treino abre o diálogo com as duas melhorias. As ações passam pelo HUD da Estação (hud), que mostra o aviso e salva.
class_name AHCharacterRoom
extends Control

const S := preload("res://scripts/flow/station_rules.gd")
## A coluna da esquerda, estreita (#181, o pedido do Lucas): o vão entre os painéis cabe a arte mais larga (o escudo do
## Tatu) na escala de todos, também no texto Maior; o que tem texto longo quebra a linha em vez de alargar a coluna.
const LEFT := Rect2(28, 132, 540, 772)
const HERO_TAB_WIDTH := 104.0
const RIGHT := Rect2(1296, 132, 596, 844)
const DIALOG := Rect2(620, 250, 680, 0)
## O diálogo do Treino com as de aprender (#259): os cartões lado a lado.
const WIDE_DIALOG := 1400.0
const MAX_INSTINCT := 200
const RELIC_ICONS := {"botao_cobre": "relic-copper-button", "pena_vidro": "relic-glass-feather", "coleira_lembranca": "relic-memory-collar"}
const TARGETS := {"SingleEnemy": "Inimigo", "SingleAlly": "Aliado", "SingleOtherAlly": "Outro aliado", "Self": "Si mesmo"}

## O HUD da Estação (refuge_hud): as ações, os avisos e as outras telas.
var hud: Control
var selected := ""
var ability := ""
var training := false
## A rolagem da coluna da esquerda entre um refazer e outro; apontada uma habilidade (#259, as 7 passam da altura da
## coluna), a coluna rola até o detalhe e a troca.
var _left_scroll := 0
var _reveal := false
var _upgrade := ""
var _first_focus: Control
var _trait_ids := {}
## O vão do último enquadramento (_frame_stage).
var _framing := Vector2(-1, -1)


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
	# O caminho tem nomes gerados que mudam a cada vez: o nome do botão (Post_research, GrowRoom) acha de novo.
	var focus_name := String(owner.name) if owner != null and is_ancestor_of(owner) and not String(owner.name).begins_with("@") else ""
	var old_scroll := get_node_or_null("Left/LeftScroll") as ScrollContainer
	if old_scroll != null:
		_left_scroll = old_scroll.scroll_vertical
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var c: Dictionary = Campaign.state
	var living: Array = S.living(c)
	if selected == "" or S.hero(c, selected) == null or not S.hero(c, selected).alive:
		# Sem ninguém no elenco (um save antigo, de antes da #118, com todos mortos), não há herói para mostrar.
		selected = living[0].id if not living.is_empty() else ""
	var hero = S.hero(c, selected) if selected != "" else null
	if hero == null:
		training = false
	_first_focus = null
	_top(c)
	if hero != null:
		_stage(hero)
	_left(c)
	if hero != null:
		_right(c, hero)
	_bottom(c)
	# O painel PERSONAGEM termina acima de IR AO MAPA (que cresce com o motivo do bloqueio e no Maior).
	var right := get_node_or_null("Right") as Control
	var prepare := get_node_or_null("Prepare") as Control
	if right != null and prepare != null:
		right.size.y = minf(RIGHT.size.y, prepare.position.y - 12.0 - RIGHT.position.y)
		right.custom_minimum_size.y = right.size.y
	if training:
		_training_dialog(c, S.hero(c, selected))
	_frame_stage()
	var again := get_node_or_null(focus_path) if not focus_path.is_empty() else null
	if again == null and focus_name != "":
		again = find_child(focus_name, true, false)
	var target: Control = again if again is Control and (again as Control).focus_mode != Control.FOCUS_NONE else _first_focus
	if target != null and AHUiStyle.using_keys:
		AHKit.focus_later(target)


func restyle() -> void:
	rebuild()


## O vão entre os dois painéis como ficaram na tela (no Maior, o da esquerda cresce com o texto), em px de 1080.
func stage_gap() -> Vector2:
	var gap := Vector2(LEFT.end.x, RIGHT.position.x)
	var left := get_node_or_null("Left") as Control
	var right := get_node_or_null("Right") as Control
	if left != null and not left.is_queued_for_deletion():
		gap.x = maxf(gap.x, left.position.x + left.size.x)
	if right != null and not right.is_queued_for_deletion():
		gap.y = minf(gap.y, right.position.x)
	return gap


## A câmera põe o meio da Sala no meio do vão real entre os painéis (#181), depois que eles tomam o tamanho. Só quando o
## vão muda: refazer a tela sem mudar o vão não mexe na câmera.
func _frame_stage() -> void:
	await get_tree().process_frame
	var station = hud.get("station") if hud != null else null
	if station == null or not is_inside_tree() or not is_visible_in_tree():
		return
	var gap := stage_gap()
	var framing := gap
	if framing == _framing:
		return
	_framing = framing
	station.focus_room_stage(S.CHARACTERS, gap.x, gap.y)


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

## O herói escolhido fica no próprio cômodo, de pé no chão da sala e na escala da Estação (#181): a placa é da Estação
## (AHStation.show_stage_hero), não uma figura da interface.
func _stage(hero: Dictionary) -> void:
	var station = hud.get("station") if hud != null else null
	if station != null:
		station.show_stage_hero(String(hero.id))


# ---------------------------------------------------------------- a coluna da esquerda

func _left(c: Dictionary) -> void:
	var panel := AHKit.panel_box("large")
	panel.name = "Left"
	panel.position = LEFT.position
	panel.size = LEFT.size
	panel.custom_minimum_size = LEFT.size
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.name = "LeftScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	scroll.set_deferred("scroll_vertical", _left_scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var tabs := HFlowContainer.new()
	tabs.name = "Heroes"
	tabs.add_theme_constant_override("h_separation", 10)
	tabs.add_theme_constant_override("v_separation", 10)
	column.add_child(tabs)
	for entry in S.living(c):
		tabs.add_child(_hero_tab(entry))
	_roster_line(c, column)
	column.add_child(_divider())
	var hero = S.hero(c, selected) if selected != "" else null
	if hero == null:
		var empty := AHKit.label(tr("Ninguém no Alojamento agora. Quem chegar no trem aparece aqui."), "text", AHKit.TEXT)
		empty.name = "EmptyRoster"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(300, 0)
		column.add_child(empty)
		return
	column.add_child(AHKit.label(tr("Habilidades"), "panel_title", AHKit.TEXT, true, true))
	# As 7 da classe (#259): as que vão para a luta, as que ficam na Estação e as bloqueadas, com o requisito.
	var ids := AHHeroSkills.catalog(String(hero.class_id))
	if ability == "" or not ids.has(ability):
		ability = AHHeroSkills.equipped(hero)[0] if not AHHeroSkills.equipped(hero).is_empty() else ""
	for ability_id in ids:
		column.add_child(_ability_row(ability_id))
	if ability != "":
		column.add_child(_ability_detail(c, hero, ability))
		_skill_choices(hero, column)
		if _reveal:
			_reveal = false
			_scroll_to_end.call_deferred()


## O detalhe e a troca ficam no fim da coluna: depois de ela se montar (um quadro), rola até lá.
func _scroll_to_end() -> void:
	await get_tree().process_frame
	var scroll := get_node_or_null("Left/LeftScroll") as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _hero_tab(entry: Dictionary) -> Button:
	var tab := Button.new()
	tab.name = "Tab_%s" % entry.id
	tab.toggle_mode = false
	AHKit.style_as(tab, "hero_selected" if entry.id == selected else "hero")
	# Quatro por linha na coluna estreita.
	tab.custom_minimum_size = Vector2(HERO_TAB_WIDTH, 132)
	tab.clip_contents = true
	tab.set_meta("hero_id", entry.id)
	var face := TextureRect.new()
	face.texture = AHUiStyle.face_texture(AHCombatArena.hero_art_of(entry.id, String(entry.get("art_variant", ""))).get("idle", {}))
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.position = Vector2(6, 6)
	face.size = Vector2(HERO_TAB_WIDTH - 12, 92)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.add_child(face)
	# Em recuperação (#118): o retrato apagado, o ícone de Caído e os dias no canto.
	if S.recovering(entry):
		face.modulate = AHKit.FALLEN
		var badge := HBoxContainer.new()
		badge.name = "Recovering"
		badge.add_theme_constant_override("separation", 2)
		badge.position = Vector2(8, 6)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(AHKit.glyph("state_wounded", 26, AHKit.alert_text()))
		badge.add_child(AHKit.label(tr("%d d") % S.recovery_days(entry), "small", AHKit.alert_text(), true))
		tab.add_child(badge)
	var name := AHKit.label(String(entry.display_name), "small" if AHUiStyle.text_scale > 1.2 else "tab", AHKit.AMBER if entry.id == selected else AHKit.TEXT)
	name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.position = Vector2(4, 98)
	name.size = Vector2(HERO_TAB_WIDTH - 8, 30)
	tab.add_child(name)
	tab.tooltip_text = String(entry.display_name) if not S.recovering(entry) else S.recovery_block(entry)
	var id: String = entry.id
	tab.pressed.connect(func(): _select(id))
	if entry.id == selected:
		_first_focus = tab
	return tab


func _select(hero_id: String) -> void:
	if hero_id == selected:
		return
	Sound.play("res://audio/ui/click.ogg", 0.6, 1.0, "UI") if ResourceLoader.exists("res://audio/ui/click.ogg") else null
	selected = hero_id
	ability = ""
	training = false
	# Outro herói: a coluna volta para o alto.
	var old_scroll := get_node_or_null("Left/LeftScroll") as ScrollContainer
	if old_scroll != null:
		old_scroll.scroll_vertical = 0
	rebuild()
	var tab := find_child("Tab_%s" % hero_id, true, false) as Control
	if tab != null:
		AHKit.focus_later(tab)


func _ability_row(ability_id: String) -> Button:
	var row := Button.new()
	row.name = "Ability_%s" % ability_id
	var data = GameData.row("abilities", ability_id)
	row.text = tr(String(data.DisplayName)) if data != null else ability_id
	# O estado (#259): a que fica na Estação e a bloqueada aparecem apagadas, com o estado no fim.
	var owner = S.hero(Campaign.state, selected)
	if owner != null:
		var state := skill_state(owner, ability_id)
		row.set_meta("state", state)
		if state != "equipped":
			row.text = tr("%s · %s") % [row.text, tr("na Estação") if state == "resting" else tr("bloqueada")]
			row.modulate = AHKit.FALLEN
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
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var id := ability_id
	row.pressed.connect(func():
		ability = id
		_reveal = true
		rebuild())
	return row


## O estado da habilidade no herói (#259): "equipped" (vai para a luta), "resting" (sabe, mas fica na Estação) ou
## "locked" (ainda não aprendeu).
static func skill_state(hero: Dictionary, ability_id: String) -> String:
	if AHHeroSkills.equipped(hero).has(ability_id):
		return "equipped"
	return "resting" if AHHeroSkills.known(hero).has(ability_id) else "locked"


## A troca das 4 que vão para a luta (#259), pela habilidade apontada: a bloqueada diz o requisito; a que vai troca por
## uma que fica ("Trocar por"); a que fica entra no lugar de uma que vai ("Levar no lugar de"). A troca que deixaria
## uma posição sem habilidade fica apagada, com o motivo.
func _skill_choices(hero: Dictionary, column: VBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.name = "SkillChoices"
	box.add_theme_constant_override("separation", 6)
	column.add_child(box)
	var state := skill_state(hero, ability)
	if state == "locked":
		var need := AHHeroSkills.requirement(hero)
		box.add_child(_note(tr("Bloqueada · %s") % need if need != "" else tr("Bloqueada.")))
		return
	var carried := AHHeroSkills.equipped(hero)
	var resting: Array = AHHeroSkills.known(hero).filter(func(id): return not carried.has(id))
	if resting.is_empty():
		if AHHeroSkills.known(hero).size() < AHHeroSkills.catalog(String(hero.class_id)).size():
			box.add_child(_note(tr("As outras se aprendem no Treino: %s.") % AHHeroSkills.requirement(hero)))
		return
	var incoming := String(ability)
	var swaps: Array = []
	if state == "equipped":
		box.add_child(AHKit.label(tr("Trocar por"), "text", AHKit.AMBER, true, true))
		var slot := carried.find(incoming)
		for option in resting:
			var chosen := carried.duplicate()
			chosen[slot] = option
			swaps.append([String(option), chosen, String(option)])
	else:
		box.add_child(AHKit.label(tr("Levar no lugar de"), "text", AHKit.AMBER, true, true))
		for index in carried.size():
			var chosen := carried.duplicate()
			chosen[index] = incoming
			swaps.append([String(carried[index]), chosen, incoming])
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 8)
	box.add_child(row)
	var reasons: Array = []
	var hero_id := String(hero.id)
	for swap in swaps:
		var data = GameData.row("abilities", swap[0])
		var button := _small_button(tr(String(data.DisplayName)) if data != null else String(swap[0]))
		button.name = ("Swap_%s" if state == "equipped" else "Replace_%s") % swap[0]
		var error := AHHeroSkills.invalid(hero, swap[1])
		if error != "":
			button.disabled = true
			button.tooltip_text = error
			if not reasons.has(error):
				reasons.append(error)
		var chosen: Array = swap[1]
		var picked: String = swap[2]
		button.pressed.connect(func():
			var result := AHHeroSkills.choose(Campaign.state, hero_id, chosen)
			if result == "":
				ability = picked
			var taken = GameData.row("abilities", picked)
			hud._act(result, "" if result != "" else tr("%s leva %s.") % [String(S.hero(Campaign.state, hero_id).display_name),
				tr(String(taken.DisplayName)) if taken != null else picked]))
		row.add_child(button)
	for reason in reasons:
		var why := _note(reason, AHKit.alert_text())
		why.name = "SwapBlocked"
		box.add_child(why)


func _note(text: String, tint: Color = AHKit.MUTED) -> Label:
	var label := AHKit.label(text, "small", tint)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(300, 0)
	return label


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
	var title := AHKit.label(tr(String(data.DisplayName)), "panel_title", AHKit.TEXT, true)
	# Quebra a linha em vez de alargar a coluna estreita ("Emergency Sledgehammer" no inglês Maior).
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(400, 0)
	box.add_child(title)
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
	text.custom_minimum_size = Vector2(400, 0)
	box.add_child(text)
	var enemy: bool = String(data.TargetType) == "SingleEnemy"
	box.add_child(AHKit.label(tr(TARGETS.get(String(data.TargetType), "")), "text", AHKit.alert_text() if enemy else AHKit.good()))
	return inset


## Os limites da Estação (#119: heróis pelo Alojamento, ajudantes pelo Dormitório), como os novos chegam (#122: de trem)
## e ampliar o Alojamento. Com alguém esperando na plataforma, o caminho até lá.
func _roster_line(c: Dictionary, column: VBoxContainer) -> void:
	var note := AHKit.label("%s · %s" % [S.limits_text(c), tr("os novos chegam de trem, na volta das expedições")], "text", AHKit.MUTED)
	note.name = "Roster"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(300, 0)
	column.add_child(note)
	var cost := S.next_level_cost(c, S.CHARACTERS)
	if not cost.is_empty():
		var level := S.room_level(c, S.CHARACTERS)
		var block := S.upgrade_block(c, S.CHARACTERS)
		var grow := AHKit.button(tr("Ampliar o Alojamento · %s") % S.cost_text(cost), "secondary")
		grow.name = "GrowRoom"
		grow.custom_minimum_size = Vector2(0, 56)
		grow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grow.disabled = block != ""
		grow.tooltip_text = block if block != "" else tr("Nível %d: %d heróis.") % [level + 1, S.hero_limit_at(level + 1)]
		grow.pressed.connect(func(): hud._act(S.upgrade_room(Campaign.state, S.CHARACTERS, level), tr("O Alojamento cresceu: %s.") % S.limits_text(Campaign.state)))
		column.add_child(grow)
		# O motivo à vista (o toque não mostra a dica).
		if block != "":
			var reason := AHKit.label(block, "small", AHKit.alert_text())
			reason.name = "GrowBlock"
			reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			reason.custom_minimum_size = Vector2(300, 0)
			column.add_child(reason)
	var waiting := S.train_candidate_name(c)
	if waiting != "":
		var go := AHKit.button((tr("%s esperam na plataforma") if S.train_waiting_names(c).size() > 1 else tr("%s espera na plataforma")) % waiting, "secondary")
		go.name = "ToTrain"
		go.custom_minimum_size = Vector2(0, 60)
		go.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		go.pressed.connect(func(): hud.open_service("train"))
		column.add_child(go)


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
	_skins(c, hero, column)
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
	if S.recovering(hero):
		var down := AHStationReport.fallen_line(hero)
		down.name = "Recovery"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		down.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(down)
		var care := _small_button(tr("Ver a Enfermaria"))
		care.pressed.connect(func(): hud.open_room(S.INFIRMARY))
		row.add_child(care)
		column.add_child(row)
		column.add_child(_divider())
	_relic(c, hero, column)
	_post(c, hero, column)
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


## A roupa (#138): as skins completas do herói, a padrão e as de data/skins.json, com o rosto de cada uma, o nome e o
## estado. A liberada se veste na hora (só visual, sem custo); a bloqueada diz o motivo. Sem skin além da padrão, nada.
func _skins(c: Dictionary, hero: Dictionary, column: VBoxContainer) -> void:
	var rows := AHSkins.of_hero(String(hero.id))
	if rows.is_empty():
		return
	var box := VBoxContainer.new()
	box.name = "Skins"
	box.add_theme_constant_override("separation", 6)
	column.add_child(box)
	box.add_child(AHKit.label(tr("Roupa"), "text", AHKit.AMBER, true, true))
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 12)
	tabs.add_theme_constant_override("v_separation", 8)
	box.add_child(tabs)
	var current := String(hero.get("skin_id", AHSkins.DEFAULT))
	var chosen_text := tr("Padrão")
	var locked_reason := ""
	# A aba leva o nome curto (cabe numa linha também no Maior); o nome inteiro vai no texto embaixo.
	for spec in [[AHSkins.DEFAULT, tr("Padrão"), tr("Padrão")]] + rows.map(func(row): return [String(row.Name),
			tr(String(row.get("ShortName", row.DisplayName))), tr(String(row.DisplayName))]):
		var skin_id: String = spec[0]
		var tab := _skin_tab(hero, skin_id, spec[1], spec[2], skin_id == current, S.skin_unlocked(c, skin_id))
		tabs.add_child(tab)
		if skin_id == current:
			chosen_text = spec[2]
		elif not S.skin_unlocked(c, skin_id) and locked_reason == "":
			locked_reason = S.skin_lock_reason(c, skin_id)
	var row = GameData.row("skins", current)
	var about := AHKit.label(tr("%s: %s") % [chosen_text, tr(String(row.Text))] if row != null else tr("A roupa de sempre."), "small", AHKit.MUTED)
	about.name = "SkinText"
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size = Vector2(300, 0)
	box.add_child(about)
	if locked_reason != "":
		var lock := AHKit.label(locked_reason, "small", AHKit.MUTED)
		lock.name = "SkinLock"
		lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lock.custom_minimum_size = Vector2(300, 0)
		box.add_child(lock)
	column.add_child(_divider())


## A aba de uma skin: o rosto dela, o nome e, bloqueada, apagada e sem vestir.
func _skin_tab(hero: Dictionary, skin_id: String, label: String, full_name: String, chosen: bool, unlocked: bool) -> Button:
	var tab := Button.new()
	tab.name = "Skin_%s" % skin_id
	tab.toggle_mode = false
	AHKit.style_as(tab, "hero_selected" if chosen else "hero")
	tab.custom_minimum_size = Vector2(104, 122)
	tab.clip_contents = true
	tab.tooltip_text = full_name if unlocked else "%s · %s" % [full_name, tr("Bloqueada")]
	var face := TextureRect.new()
	var founder := _founder_art(String(hero.id))
	face.texture = AHUiStyle.face_texture(AHSkins.dress(founder, skin_id).get("idle", {}))
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.position = Vector2(6, 6)
	face.size = Vector2(92, 82)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked:
		face.modulate = AHKit.LOCKED
	tab.add_child(face)
	var name := AHKit.label(label if unlocked else tr("Bloqueada"), "small", AHKit.AMBER if chosen else (AHKit.TEXT if unlocked else AHKit.MUTED))
	name.name = "SkinName"
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.position = Vector2(2, 90)
	name.size = Vector2(100, 30)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.add_child(name)
	var hero_id := String(hero.id)
	tab.pressed.connect(func(): _choose_skin(hero_id, skin_id, full_name))
	return tab


## A entrada do fundador no manifesto, sem skin (a base para vestir cada aba).
func _founder_art(hero_id: String) -> Dictionary:
	return AHCombatArena.founder_art_of(hero_id)


func _choose_skin(hero_id: String, skin_id: String, label: String) -> void:
	var c: Dictionary = Campaign.state
	if String(S.hero(c, hero_id).get("skin_id", AHSkins.DEFAULT)) == skin_id:
		return
	var error := S.choose_skin(c, hero_id, skin_id)
	var who := String(S.hero(c, hero_id).display_name)
	var done := tr("%s volta à roupa de sempre.") % who if skin_id == AHSkins.DEFAULT else tr("%s veste %s.") % [who, label]
	hud._act(error, "" if error != "" else done)
	# A placa dele na Estação veste a nova também (a tela já se refez pelo refresh do _act).
	var station = hud.get("station") if error == "" else null
	if station != null:
		station.redress(hero_id)


## O posto na Estação (#119): onde o herói trabalha enquanto a equipe está fora, e o que rende a cada volta. Um posto
## por herói e um herói por cômodo; quem parte na equipe deixa o posto.
func _post(c: Dictionary, hero: Dictionary, column: VBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.name = "Post"
	box.add_theme_constant_override("separation", 6)
	column.add_child(box)
	box.add_child(AHKit.label(tr("Posto"), "text", AHKit.AMBER, true, true))
	var current := S.post_of(hero)
	var text := ""
	if S.recovering(hero):
		text = tr("Em recuperação: sem posto até voltar.")
	elif current == "":
		text = tr("Sem posto: descansa enquanto a equipe está fora.")
	else:
		text = "%s · %s" % [S.post_name(current), S.yield_text(current, S.post_yield(hero, current))]
	var line := AHKit.label(text, "text", AHKit.MUTED if current == "" else AHKit.TEXT)
	line.name = "PostText"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(300, 0)
	box.add_child(line)
	var rooms := S.job_rooms(c)
	if S.recovering(hero) or rooms.is_empty():
		column.add_child(_divider())
		return
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	box.add_child(chips)
	var id: String = hero.id
	for room_id in [""] + rooms:
		var room: String = room_id
		# O rendimento no próprio chip: o toque e o controle não mostram a dica do mouse.
		var chip := AHKit.button(tr("Nenhum") if room == "" else "%s · +%d" % [S.post_name(room), S.post_yield(hero, room)], "chip")
		AHOptionsPanel._chip_font(chip)
		chip.name = "Post_%s" % (room if room != "" else "none")
		chip.custom_minimum_size = Vector2(0, 52)
		if room != "":
			var other = S.worker(c, room)
			chip.tooltip_text = S.yield_text(room, S.post_yield(hero, room)) + ((tr(" · %s sai de lá") % other.display_name) if other != null and other.id != id else "")
		if room == current:
			for state in ["font_color", "font_hover_color", "font_focus_color"]:
				chip.add_theme_color_override(state, AHKit.AMBER)
			chip.add_child(AHKit.selected_overlay())
		chip.pressed.connect(func(): hud._act(S.set_post(Campaign.state, id, room)))
		chips.add_child(chip)
	column.add_child(_divider())


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
		# No nível máximo, ainda aprende o que falta (#259), pelas sementes de um nível (#299).
		if AHHeroSkills.learn_options(hero).is_empty():
			detail = tr("nível máximo")
		elif block != "":
			detail = tr("faltam sementes")
		else:
			detail = AHHeroSkills.seeds_text(AHHeroSkills.max_level_seeds())
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
	# Com as de aprender (#259, até 5 cartões), o diálogo se abre na largura da tela, centrado.
	var wide := options.any(func(o): return String(o.get("Stat", "")) == "Learn")
	var dialog_width: float = WIDE_DIALOG if wide else DIALOG.size.x
	dialog.position = Vector2((1920.0 - dialog_width) * 0.5, DIALOG.position.y) if wide else DIALOG.position
	dialog.custom_minimum_size = Vector2(dialog_width, 0)
	add_child(dialog)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	dialog.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(AHKit.glyph("train", 36, AHKit.AMBER))
	var cost := AHHeroLevels.next_cost(hero)
	head.add_child(AHKit.label(tr("Treino · nível %d") % (AHHeroLevels.level(hero) + 1) if not cost.is_empty() else tr("Treino"), "panel_title", AHKit.TEXT, true, true))
	column.add_child(head)
	var intro_text := tr("No nível máximo, o treino ensina o que falta: custa os fragmentos e %s.") % AHHeroSkills.seeds_text(AHHeroSkills.max_level_seeds())
	if not cost.is_empty():
		var seeds_text: String = tr("1 semente") if int(cost.seeds) == 1 else tr("%d sementes") % cost.seeds
		intro_text = (tr("Escolha uma melhoria ou uma habilidade para aprender. O treino gasta o XP do nível e %s.") if wide
			else tr("Escolha uma melhoria. O treino gasta o XP do nível e %s.")) % seeds_text
	var intro := AHKit.label(intro_text, "text", AHKit.TEXT)
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
		# Com mais cartões, cada um fica mais estreito; a altura acompanha o texto.
		var card_width: float = 296.0 if not wide else floorf((dialog_width - 72.0 - 16.0 * (options.size() - 1)) / options.size())
		card.custom_minimum_size = Vector2(card_width, 200)
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
		var title := AHKit.label(tr(String(option.DisplayName)), "ability_name", AHKit.AMBER if option.Name == _upgrade else AHKit.TEXT, true)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.custom_minimum_size = Vector2(card_width - 56.0, 0)
		box.add_child(title)
		var effect := AHKit.label(tr(String(option.Description)), "text", AHKit.TEXT)
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect.custom_minimum_size = Vector2(card_width - 56.0, 0)
		box.add_child(effect)
		if String(option.get("Stat", "")) == "Learn":
			# Aprender (#259): custa fragmentos além do nível; faltando, o preço fica na cor de alerta.
			var fragments := int(option.get("Fragments", 0))
			var short := S.quantity(c, "fragments") < fragments
			var price := AHKit.label(tr("Custa também %d fragmentos") % fragments if fragments != 1 else tr("Custa também 1 fragmento"), "small", AHKit.alert_text() if short else AHKit.MUTED)
			price.name = "Price"
			price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			price.custom_minimum_size = Vector2(card_width - 56.0, 0)
			box.add_child(price)
		else:
			box.add_child(AHKit.label(tr("Já tem: %d") % AHHeroLevels.stacks(hero, option.Name), "small", AHKit.MUTED))
		# O botão não cresce com o que tem dentro: a altura segue o texto (quebrado na largura do cartão).
		var grow := func(): card.custom_minimum_size.y = maxf(200.0, box.get_combined_minimum_size().y + 44.0)
		box.minimum_size_changed.connect(grow)
		grow.call()
		var id: String = option.Name
		card.pressed.connect(func():
			_upgrade = id
			rebuild()
			var again := find_child("Upgrade_%s" % id, true, false) as Control
			if again != null:
				AHKit.focus_later(again))
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
	AHStationFrame.back_button(self, func(): hud.close_panel())
	# As teclas entre os dois painéis (Voltar mostra o Esc: ui_cancel volta sempre, com qualquer troca nas Opções).
	# O cômodo ao lado (#131): o Dormitório e o Bar, sem voltar à vista geral.
	AHStationFrame.keys(self, [[tr("Setas"), tr("Navegar")], ["interact", tr("Selecionar")], ["Esc", tr("Voltar")],
		["station_room_next", tr("Ao lado")], ["hide_hud", tr("Ocultar")]], 962.0, LEFT.end.x + 12.0, RIGHT.position.x - 12.0)
	AHStationFrame.tabs(self, "characters", _nav)
	AHStationFrame.prepare(self, tr("Ir ao mapa"), "station", S.preparation_block(c), func(): hud.open_map())


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
