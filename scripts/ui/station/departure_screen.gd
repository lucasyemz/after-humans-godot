## A partida na plataforma (#123): depois do Mapa da Rede, a equipe em fila na Plataforma 1, cada um de pé sobre a sua
## carta, como no relatório da volta (#111).
## - A faixa do alto: o lugar escolhido e o que o radar leu; à direita, o Foco da rota e a Comida.
## - As cartas no pé da tela (a posição 1, a frente, à direita): clicar em duas troca a ordem; com uma escolhida, quem
##   está na Estação entra no lugar dela. Quem não pode ir (o caído da #118, quem não tem arte de luta) aparece na lista
##   da Estação com o motivo, sem entrar.
## - INICIAR EXPEDIÇÃO (G / X) abre a confirmação com o resumo do lugar, da equipe e da comida; VOLTAR AO MAPA (Esc)
##   volta ao mapa com a escolha.
## O rascunho (draft: phase, team da frente para trás, focus, extra) é do HUD da Estação: esta tela só o muda e avisa.
class_name AHDepartureScreen
extends Control

## VOLTAR AO MAPA.
signal back_requested
## INICIAR EXPEDIÇÃO na confirmação.
signal start_confirmed
## A equipe mudou (a fila na plataforma acompanha).
signal team_changed

const S := preload("res://scripts/flow/station_rules.gd")
const J := preload("res://scripts/flow/journey_rules.gd")
const R := preload("res://scripts/flow/network_radar.gd")
const BAND := Rect2(36, 24, 1848, 216)
## As cartas: as mesmas medidas do relatório, para cada um da fila ficar de pé sobre a sua (AHStation.align_lineup).
const CARD_WIDTH := AHStationReport.CARD_WIDTH
const CARD_STEP := AHStationReport.CARD_STEP
const CARD_TOP := AHStationReport.CARD_TOP

var draft: Dictionary = {}
## A ficha do herói ao apontar uma carta (#89), a do HUD.
var sheet: AHCharacterSheet
## A carta escolhida para trocar (o índice na equipe, da frente para trás; -1: nenhuma).
var selected := -1
var _cards: HBoxContainer
## A lista da Estação: em linhas que quebram; compacta, uma linha só que rola para os lados.
var _bench: Container
var _start: Button
var _back: Button
var _confirm: Control
## A equipe ainda subindo para a plataforma ou o briefing por ler: a confirmação espera (o HUD diz a cada quadro).
var waiting := false
var _lineup: VBoxContainer
## A lista da Estação só com os nomes (o motivo na dica e no ícone): quando a lista inteira passaria dos botões de baixo
## (muitos na Estação, o texto Maior).
var _compact := false


static func make(team_draft: Dictionary, hero_sheet: AHCharacterSheet) -> AHDepartureScreen:
	var screen := AHDepartureScreen.new()
	screen.draft = team_draft
	screen.sheet = hero_sheet
	screen.name = "Departure"
	return screen


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rebuild()
	# No teclado e no controle, o foco começa na carta da frente (a posição 1).
	if AHUiStyle.using_keys:
		var front: Control = find_child("Slot1", true, false)
		if front != null:
			AHKit.focus_later(front)


## Quantas cartas: as vagas que a jornada aceita (no mínimo a equipe de agora).
func slots() -> int:
	return clampi(maxi(int(J.team_limits(draft.phase).max), draft.team.size()), 1, 4)


## O centro (x na tela) da carta de cada herói ({hero_id: x}), com a posição 1 à direita.
func card_centers() -> Dictionary:
	var count := slots()
	var out := {}
	for index in draft.team.size():
		var column: int = count - 1 - index
		out[draft.team[index]] = 960.0 + (column - (count - 1) * 0.5) * CARD_STEP
	return out


## A equipe na ordem da cena (da esquerda para a direita), para a fila da plataforma.
func scene_team() -> Array:
	return AHStationReport.scene_order(draft.team)


## Onde o foco do teclado e do controle fica: a confirmação aberta ou a tela.
func focus_root() -> Control:
	return _confirm if confirm_open() else self


func confirm_open() -> bool:
	return is_instance_valid(_confirm)


## O motivo de não poder partir ainda (a equipe, a comida, a fase), conferido numa cópia; "" quando dá.
func block() -> String:
	return S.confirm_departure(Campaign.state.duplicate(true), draft.team.duplicate(), int(draft.extra), 0, String(draft.phase), String(draft.focus))


func rebuild() -> void:
	var focused := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	var focus_name := String(focused.name) if focused != null and is_ancestor_of(focused) else ""
	# As cartas são refeitas: a ficha da carta de antes fecha (o mouse ou o foco a abrem de novo).
	if sheet != null:
		sheet.close()
	for child in get_children():
		if child != _confirm:
			remove_child(child)
			child.queue_free()
	_band()
	_build_cards()
	_buttons()
	if is_instance_valid(_confirm):
		move_child(_confirm, -1)
	elif focus_name != "":
		var again := find_child(focus_name, true, false)
		if again is Control and (again as Control).focus_mode != Control.FOCUS_NONE:
			AHKit.focus_later(again)


func restyle() -> void:
	if confirm_open():
		close_confirm()
	_compact = false
	rebuild()


## Arrumado o quadro: se as cartas e a lista passam dos botões de baixo, a lista fica numa linha só, com os nomes.
func _check_fit() -> void:
	if _compact or not is_instance_valid(_lineup) or not _lineup.is_inside_tree():
		return
	await get_tree().process_frame
	if _compact or not is_instance_valid(_lineup) or not _lineup.is_inside_tree():
		return
	if _lineup.get_global_rect().end.y > AHStationFrame.NAV_Y - 12.0:
		_compact = true
		rebuild()


# ---------------------------------------------------------------- a faixa do alto

func _band() -> void:
	var c: Dictionary = Campaign.state
	var band := PanelContainer.new()
	band.name = "Band"
	band.add_theme_stylebox_override("panel", AHKit.style(AHKit.piece_of("panel", "band"), Color.WHITE, Vector4(32, 22, 32, 22)))
	band.position = BAND.position
	band.custom_minimum_size = BAND.size
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	band.add_child(row)
	var info := J.phase(draft.phase)
	var number := J.PHASES.map(func(p): return p.id).find(info.id) + 1
	# À esquerda: de onde, o lugar escolhido e a jornada.
	var place := VBoxContainer.new()
	place.name = "Place"
	place.add_theme_constant_override("separation", 4)
	place.custom_minimum_size = Vector2(440, 0)
	row.add_child(place)
	var kicker := HBoxContainer.new()
	kicker.add_theme_constant_override("separation", 10)
	place.add_child(kicker)
	kicker.add_child(AHKit.glyph("station", AHKit.size("text") + 6, AHKit.MUTED))
	kicker.add_child(AHKit.label(tr("Plataforma 1 · Partida"), "text", AHKit.MUTED, false, true))
	# O nome do lugar como no relatório da volta; o longo (ou o Maior) diminui até caber na coluna.
	var name_label := AHKit.label(tr(info.name), "phase_name", AHKit.TEXT, true, true)
	name_label.name = "PlaceName"
	var title_size := AHKit.size("phase_name")
	while title_size > AHKit.size("panel_title") and AHKit.font(true).get_string_size(name_label.text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > 440.0:
		title_size -= 2
	name_label.add_theme_font_size_override("font_size", title_size)
	place.add_child(name_label)
	place.add_child(_wrap(tr("Fase %d · %s · nível %d+") % [number, tr(J.DIFFICULTY_NAMES[info.difficulty]), info.level], "text", AHKit.MUTED, 440.0))
	place.add_child(_wrap(tr("Equipe: %s") % S.team_size_text(J.team_limits(draft.phase)), "text", AHKit.TEXT, 440.0))
	# O aviso da equipe inteira (ninguém cura); o que trava a partida fica dentro de INICIAR EXPEDIÇÃO.
	var warning := team_warning(c)
	# Quem espera no trem (#122) vai embora com ele se a equipe partir antes de decidir.
	var waiting_name := S.train_candidate_name(c)
	# O Mercador (#182) não vai embora com a partida: ele trava a partida até ser dispensado (o motivo fica no botão).
	if waiting_name != "" and not S.merchant_here(c):
		# Com dois (#182), os dois vão embora.
		warning = (tr("%s esperam no trem: se a equipe partir, vão embora.") if S.train_waiting_names(c).size() > 1
			else tr("%s espera no trem: se a equipe partir, vai embora.")) % waiting_name + ("\n" + warning if warning != "" else "")
	# Quem parte deixa o posto na Estação (#119).
	for hero_id in draft.team:
		var member = S.hero(c, hero_id)
		if member != null and S.post_of(member) != "":
			warning = tr("%s deixa o posto %s para partir.") % [member.display_name, S.room_in(S.post_of(member))] + ("\n" + warning if warning != "" else "")
	if warning != "":
		var note := HBoxContainer.new()
		note.name = "Warning"
		note.add_theme_constant_override("separation", 8)
		note.add_child(AHKit.glyph("alert", 22, AHKit.AMBER))
		note.add_child(_wrap(warning, "small", AHKit.AMBER, 410.0))
		place.add_child(note)
	row.add_child(_divider())
	# No meio: o que o radar leu do lugar (o mesmo do Mapa da Rede), em duas colunas.
	var read := R.reading(c, draft.phase, String(draft.focus))
	var radar := VBoxContainer.new()
	radar.name = "Radar"
	radar.add_theme_constant_override("separation", 6)
	radar.custom_minimum_size = Vector2(600, 0)
	row.add_child(radar)
	var overall := R.overall(read)
	var level_text := tr("leitura completa") if overall == "known" else (tr("leitura parcial") if overall == "partial" else tr("sem leitura"))
	radar.add_child(AHKit.label(tr("Mapa da Rede: %s") % level_text, "small", AHKit.MUTED, true, true))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 4)
	radar.add_child(grid)
	for part in R.PARTS:
		grid.add_child(AHPhaseMap.radar_row(part, read[part], 290.0))
	row.add_child(_divider())
	# À direita: o Foco da rota e a Comida.
	var supplies := VBoxContainer.new()
	supplies.name = "Supplies"
	supplies.add_theme_constant_override("separation", 8)
	supplies.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(supplies)
	supplies.add_child(AHKit.label(tr("Foco da rota"), "small", AHKit.MUTED, true, true))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	supplies.add_child(chips)
	var recommended := S.focus_recommended(c)
	var focus_icons := {S.FOCUS_WATER: "lobby-water", S.FOCUS_PARTS: "lobby-scrap", S.FOCUS_PROVISIONS: "lobby-food"}
	for focus_id in [""] + S.FOCI.map(func(f): return f.id):
		if not S.focus_available(c, focus_id):
			continue
		var id: String = focus_id
		var chip := _chip(S.focus_label(id))
		chip.name = "Focus_%s" % (id if id != "" else "basic")
		if focus_icons.has(id):
			chip.icon = AHKit.legacy_icon(focus_icons[id])
			chip.add_theme_constant_override("icon_max_width", 24)
		chip.tooltip_text = (S.focus_reward_text(id) if id != "" else tr("Sem objetivo extra.")) + (tr(" · recomendado") if id == recommended else "") \
			+ "\n" + S.focus_reason(c, id)
		chip.custom_minimum_size = Vector2(0, 52)
		if String(draft.focus) == id:
			for state in ["font_color", "font_hover_color", "font_focus_color"]:
				chip.add_theme_color_override(state, AHKit.AMBER)
			chip.add_child(AHKit.selected_overlay())
		chip.pressed.connect(func(): draft.focus = id; rebuild())
		chips.add_child(chip)
	var advice := HBoxContainer.new()
	advice.add_theme_constant_override("separation", 8)
	supplies.add_child(advice)
	advice.add_child(_icon("marker-here", 22, AHKit.AMBER))
	advice.add_child(AHKit.label(tr("Recomendado: %s.") % S.focus_label(recommended), "small", AHKit.AMBER, true))
	var food := HBoxContainer.new()
	food.name = "Food"
	food.add_theme_constant_override("separation", 10)
	supplies.add_child(food)
	food.add_child(_icon("lobby-food", 28, AHKit.TEXT))
	var food_words := VBoxContainer.new()
	food_words.add_theme_constant_override("separation", -2)
	food.add_child(food_words)
	var extra := int(draft.extra)
	food_words.add_child(AHKit.label(tr("Comida: %d grátis + %d extras") % [J.FREE_FOOD, extra], "text", AHKit.TEXT, true))
	food_words.add_child(AHKit.label(tr("%d sementes de %d") % [extra * S.FOOD_COST, S.quantity(c, "seeds")], "small", AHKit.MUTED))
	var less := _step_button("−", extra > 0)
	less.name = "FoodLess"
	less.pressed.connect(func(): draft.extra = maxi(0, int(draft.extra) - 1); rebuild())
	food.add_child(less)
	var more := _step_button("+", extra < J.MAX_FOOD - J.FREE_FOOD and (extra + 1) * S.FOOD_COST <= S.quantity(c, "seeds"))
	more.name = "FoodMore"
	more.pressed.connect(func(): draft.extra = mini(J.MAX_FOOD - J.FREE_FOOD, int(draft.extra) + 1); rebuild())
	food.add_child(more)


func _divider() -> TextureRect:
	var line := TextureRect.new()
	line.texture = AHKit.texture("band_divider")
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.custom_minimum_size = Vector2(12, 0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


# ---------------------------------------------------------------- as cartas e a Estação

func _build_cards() -> void:
	var c: Dictionary = Campaign.state
	var column := VBoxContainer.new()
	_lineup = column
	column.name = "Lineup"
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_cards = HBoxContainer.new()
	_cards.name = "Cards"
	_cards.add_theme_constant_override("separation", int(CARD_STEP - CARD_WIDTH))
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_cards)
	var count := slots()
	for column_index in count:
		_cards.add_child(_card(c, count - column_index))
	# Os da Estação: com uma carta escolhida, clicar troca; quem não pode ir diz o motivo.
	var list_width := minf(float(count) * CARD_STEP, 1720.0)
	if _compact:
		column.add_child(_scrolling_bench(list_width))
	else:
		var flow := HFlowContainer.new()
		flow.name = "Bench"
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		flow.custom_minimum_size.x = list_width
		column.add_child(flow)
		_bench = flow
	var bench: Array = S.living(c).filter(func(h): return not draft.team.has(h.id))
	var can_leave: bool = selected >= 0 and selected < draft.team.size() and draft.team.size() > 1
	if not bench.is_empty() or can_leave:
		var label := AHKit.label(tr("Na Estação:") if selected < 0 else tr("Trocar por:"), "text", AHKit.MUTED, true)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_bench.add_child(label)
	for entry in bench:
		var id: String = entry.id
		var ready := S.can_deploy(entry)
		var text := "%s · %d/%d" % [entry.display_name, entry.hp, entry.max_hp]
		if S.recovering(entry):
			text = "%s · %s · %s" % [entry.display_name, tr("Caído"), S.return_text(S.recovery_days(entry))]
		elif not ready:
			text = "%s · %s" % [entry.display_name, tr("sem arte de combate")]
		# Compacta, o nome e o motivo curto (o toque e o controle não mostram a dica do mouse).
		if _compact:
			text = String(entry.display_name) if ready else "%s · %s" % [entry.display_name, tr("Caído") if S.recovering(entry) else tr("sem arte")]
		var button := _chip(text)
		button.name = "Bench_%s" % id
		button.custom_minimum_size = Vector2(0, 52)
		button.disabled = not ready or selected < 0
		button.tooltip_text = S.deploy_block(entry) if not ready else tr("Escolha uma carta da equipe e clique aqui para trocar.")
		if not ready:
			button.add_theme_color_override("font_disabled_color", AHKit.alert_text())
			button.icon = AHKit.legacy_icon("state_wounded") if S.recovering(entry) or _compact else null
			button.add_theme_constant_override("icon_max_width", 22)
		button.pressed.connect(func(): put_in(id))
		if sheet != null:
			sheet.attach(button, func(): return AHCharacterSheet.from_hero(S.hero(Campaign.state, id)))
		_bench.add_child(button)
	if can_leave:
		var leave := _chip(tr("Deixar na Estação"))
		leave.name = "Leave"
		leave.custom_minimum_size = Vector2(0, 52)
		leave.tooltip_text = tr("Parte com um a menos; os de trás andam uma posição para a frente.")
		leave.pressed.connect(leave_out)
		_bench.add_child(leave)
	column.reset_size()
	var width := maxf(column.get_combined_minimum_size().x, float(count) * CARD_STEP)
	column.size = Vector2(width, 0)
	column.position = Vector2(960.0 - width * 0.5, CARD_TOP - (4.0 if AHUiStyle.text_scale > 1.2 else 0.0))
	_check_fit.call_deferred()


## A lista compacta: uma linha que rola para os lados (o foco a acompanha; as setas do lado rolam com o mouse e o toque).
func _scrolling_bench(width: float) -> HBoxContainer:
	var holder := HBoxContainer.new()
	holder.name = "BenchRow"
	holder.add_theme_constant_override("separation", 8)
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	var scroll := ScrollContainer.new()
	scroll.name = "BenchScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(width - 128.0, 56)
	var row := HBoxContainer.new()
	row.name = "Bench"
	row.add_theme_constant_override("separation", 8)
	scroll.add_child(row)
	_bench = row
	for spec in [[true, -1], [false, 1]]:
		var arrow := AHKit.button("", "icon")
		arrow.name = "BenchLeft" if spec[0] else "BenchRight"
		arrow.custom_minimum_size = Vector2(52, 52)
		arrow.focus_mode = Control.FOCUS_NONE
		var glyph := AHKit.glyph("ui-arrow-right", 26, AHKit.TEXT)
		glyph.flip_h = spec[0]
		glyph.position = Vector2(13, 13)
		arrow.add_child(glyph)
		var step: int = spec[1]
		arrow.pressed.connect(func(): scroll.scroll_horizontal += step * 320)
		if spec[0]:
			holder.add_child(arrow)
			holder.add_child(scroll)
		else:
			holder.add_child(arrow)
	return holder


## Uma carta da fila: a posição, o rosto, o papel, a vida e o que funciona dali. Escolhida, os cantos âmbar.
func _card(c: Dictionary, rank: int) -> Button:
	var hero_id: String = draft.team[rank - 1] if rank - 1 < draft.team.size() else ""
	var hero = S.hero(c, hero_id)
	var button := Button.new()
	button.name = "Slot%d" % rank
	AHKit.style_button(button, AHKit.piece_of("card", "hero"))
	button.custom_minimum_size = Vector2(CARD_WIDTH, 150)
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(func(): pick(rank - 1))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 18
	column.offset_top = 14
	column.offset_right = -18
	column.offset_bottom = -14
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	if hero == null:
		var empty := AHKit.label(tr("Posição vazia"), "row", AHKit.MUTED, true)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(empty)
		var hint := _wrap(tr("Escolha esta carta e alguém da Estação."), "small", AHKit.MUTED, CARD_WIDTH - 36.0)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(hint)
	else:
		if sheet != null:
			sheet.attach(button, func(): return AHCharacterSheet.from_hero(S.hero(Campaign.state, hero_id)))
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 14)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(top)
		# O espaço da medalha da posição, no canto do retrato.
		var art: Dictionary = AHCombatArena.hero_art_of(hero.id, String(hero.get("art_variant", ""))).get("idle", {})
		var face := AHKit.portrait(AHUiStyle.face_texture(art), 76)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(face)
		var names := VBoxContainer.new()
		names.add_theme_constant_override("separation", 0)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(names)
		var name_label := AHKit.label(String(hero.display_name), "card_name", AHKit.TEXT, true, true)
		name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		names.add_child(name_label)
		# A espécie e o papel (#189): "Cão · Proteção".
		names.add_child(AHKit.label(AHSpecies.kind_text(hero), "text", AHKit.MUTED))
		names.add_child(AHKit.label(tr("Vida %d / %d") % [hero.hp, hero.max_hp], "text", AHKit.TEXT, true))
		var bar := AHKit.bar("life", hero.hp, hero.max_hp)
		bar.custom_minimum_size = Vector2(0, 22)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(bar)
		var note := _note(hero, rank)
		var note_row := HBoxContainer.new()
		note_row.add_theme_constant_override("separation", 8)
		note_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(note_row)
		var tone: Color = AHKit.good() if note.good else AHKit.alert_text()
		note_row.add_child(AHKit.glyph("state_active" if note.good else "alert", 22, tone))
		var note_label := _wrap(note.text, "small", tone, CARD_WIDTH - 80.0)
		note_label.name = "Note"
		note_row.add_child(note_label)
	button.add_child(_rank_medal(rank))
	if selected == rank - 1:
		button.add_child(AHKit.selected_overlay())
	for child in button.find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A carta cresce com o conteúdo (o texto Maior).
	var grow := func(): button.custom_minimum_size.y = maxf(150.0, column.get_combined_minimum_size().y + 28.0)
	column.minimum_size_changed.connect(grow)
	grow.call()
	return button


## O que a carta avisa: sem ataque dali, a vida baixa, o trauma; senão, quantas habilidades funcionam dali.
func _note(hero: Dictionary, rank: int) -> Dictionary:
	if S.attacks_from_rank(hero.class_id, rank).is_empty():
		return {"text": tr("Sem ataque desta posição"), "good": false}
	if hero.hp < hero.max_hp * 0.5:
		return {"text": tr("Vida baixa: leve comida ou curativos"), "good": false}
	if hero.trauma:
		return {"text": tr("Com trauma: começa com instinto alto"), "good": false}
	var hero_class = GameData.row("classes", String(hero.class_id))
	var abilities: Array = hero_class.get("AbilityIds", []) if hero_class != null else []
	var usable := abilities.filter(func(id):
		var ability = GameData.combat.abilities.get(id)
		return ability != null and ability.OriginRanks.has(rank)).size()
	return {"text": tr("%d de %d habilidades daqui") % [usable, abilities.size()], "good": true}


## O medalhão da posição no canto do retrato.
func _rank_medal(rank: int) -> Control:
	var medal := AHKit.panel(AHKit.piece_of("medal", "level"))
	medal.name = "Rank"
	medal.custom_minimum_size = Vector2(42, 42)
	medal.size = Vector2(42, 42)
	medal.position = Vector2(4, 4)
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var number := AHKit.label(str(rank), "text", AHKit.AMBER, true)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	medal.add_child(number)
	return medal


## O aviso da equipe inteira: ninguém cura (leve curativos).
func team_warning(c: Dictionary) -> String:
	for hero_id in draft.team:
		var entry = S.hero(c, hero_id)
		if entry == null:
			continue
		var hero_class = GameData.row("classes", entry.class_id)
		for ability_id in (hero_class.get("AbilityIds", []) if hero_class else []):
			var ability = GameData.combat.abilities.get(ability_id)
			if ability != null and ability.HealRange.Max > 0:
				return ""
	return tr("Ninguém na equipe cura em combate: leve curativos e comida.")


## Clicar numa carta: a primeira escolhe, a mesma solta, outra troca as duas de lugar (com a vaga vazia, o herói vai para
## a última posição ocupada: a fila não fica com buraco).
func pick(index: int) -> void:
	if selected < 0:
		selected = index
	elif selected == index:
		selected = -1
	else:
		var a := mini(selected, index)
		var b := maxi(selected, index)
		selected = -1
		if b < draft.team.size():
			var keep = draft.team[a]
			draft.team[a] = draft.team[b]
			draft.team[b] = keep
			team_changed.emit()
		elif a < draft.team.size() and a != draft.team.size() - 1:
			draft.team.append(draft.team[a])
			draft.team.remove_at(a)
			team_changed.emit()
	rebuild()


## Com uma carta escolhida, quem está na Estação entra no lugar dela (ou na vaga vazia).
func put_in(hero_id: String) -> void:
	var entry = S.hero(Campaign.state, hero_id)
	if selected < 0 or not S.can_deploy(entry) or draft.team.has(hero_id):
		return
	if selected < draft.team.size():
		draft.team[selected] = hero_id
	else:
		draft.team.append(hero_id)
	selected = -1
	team_changed.emit()
	rebuild()


## A escolhida fica na Estação: parte com um a menos, e os de trás andam uma posição para a frente.
func leave_out() -> void:
	if selected < 0 or selected >= draft.team.size() or draft.team.size() <= 1:
		return
	draft.team.remove_at(selected)
	selected = -1
	team_changed.emit()
	rebuild()


# ---------------------------------------------------------------- os botões e a confirmação

func _buttons() -> void:
	_back = AHStationFrame.back_button(self, func(): back_requested.emit())
	_back.text = tr("Voltar ao mapa").to_upper()
	_back.position.y = AHStationFrame.NAV_Y
	var back_key := AHKitKey.make("", "Esc / B", "button")
	back_key.name = "Key"
	_back.add_child(back_key)
	# Largo o bastante para o texto centrado não chegar à tecla (no Maior também).
	back_key.reset_size()
	var text_width := _back.get_theme_font("font").get_string_size(_back.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _back.get_theme_font_size("font_size")).x
	_back.custom_minimum_size.x = maxf(420.0, text_width + 2.0 * back_key.get_combined_minimum_size().x + 110.0)
	_back.resized.connect(func():
		back_key.reset_size()
		back_key.position = Vector2(_back.size.x - back_key.size.x - 18.0, (_back.size.y - back_key.size.y) * 0.5))
	_start = AHStationFrame.prepare(self, tr("Iniciar expedição"), "station", block(), open_confirm)
	_start.name = "Start" if not _start.disabled else "StartBlocked"
	var keys := AHStationFrame.keys(self, [[tr("Setas"), tr("Navegar")], ["interact", tr("Escolher")], ["hide_hud", tr("Ocultar")]], 960.0,
		_back.position.x + _back.custom_minimum_size.x + 24.0, _start.position.x - 24.0)
	keys.position.y = AHStationFrame.NAV_Y + 8.0


func open_confirm() -> void:
	# Antes da chegada e do briefing, o clique só nega (o botão continua o mesmo: a espera dura segundos).
	if waiting:
		Sound.play("res://audio/ui/deny.ogg")
		return
	if confirm_open() or block() != "":
		return
	var c: Dictionary = Campaign.state
	# A tela inteira (1920 x 1080): o HUD da Estação é um Control sem tamanho.
	_confirm = Control.new()
	_confirm.name = "Confirm"
	_confirm.position = Vector2.ZERO
	_confirm.size = Vector2(1920, 1080)
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_confirm)
	var dim := ColorRect.new()
	dim.color = AHKit.VEIL
	dim.size = Vector2(1920, 1080)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(dim)
	var box := AHKit.panel_box("large")
	box.custom_minimum_size = Vector2(820, 0)
	_confirm.add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	box.add_child(column)
	column.add_child(AHKit.label(tr("Iniciar expedição"), "panel_title", AHKit.TEXT, true, true))
	var info := J.phase(draft.phase)
	column.add_child(_summary_line("route", tr("Lugar"), "%s · %s" % [tr(info.name), tr("nível %d+") % info.level]))
	var names: Array = []
	for index in draft.team.size():
		var entry = S.hero(c, draft.team[index])
		names.append("%d. %s" % [index + 1, entry.display_name if entry != null else draft.team[index]])
	column.add_child(_summary_line("nav_characters", tr("Equipe"), " · ".join(names)))
	column.add_child(_summary_line("lobby-food", tr("Comida"), tr("%d grátis + %d extras · %d sementes") % [J.FREE_FOOD, int(draft.extra), int(draft.extra) * S.FOOD_COST]))
	column.add_child(_summary_line("marker-here", tr("Foco da rota"), S.focus_label(String(draft.focus))))
	var warning := team_warning(c)
	if warning != "":
		var note := HBoxContainer.new()
		note.add_theme_constant_override("separation", 10)
		note.add_child(AHKit.glyph("alert", 24, AHKit.AMBER))
		note.add_child(_wrap(warning, "text", AHKit.AMBER, 680.0))
		column.add_child(note)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	# Os dois com a tecla dentro, como os botões do kit: VOLTAR (Esc / B) e INICIAR EXPEDIÇÃO (G / X).
	var cancel := AHKit.button(tr("Voltar"), "secondary")
	cancel.name = "Cancel"
	cancel.custom_minimum_size = Vector2(220, 64)
	var cancel_key := AHKitKey.make("", "Esc / B", "button")
	cancel_key.name = "Key"
	cancel.add_child(cancel_key)
	cancel.pressed.connect(close_confirm)
	buttons.add_child(cancel)
	AHStationReport.fit_key(cancel, 14.0)
	var go := AHStationReport._primary(tr("Iniciar expedição"), "station", "station_prepare")
	go.name = "Go"
	var key: Control = go.get_node("Key")
	key.set_meta("ah_action", "station_prepare")
	key.set_meta("ah_format", "%s / X")
	(key.get_child(0) as Label).text = "%s / X" % AHUiStyle.key_name("station_prepare")
	go.pressed.connect(func():
		close_confirm()
		start_confirmed.emit())
	buttons.add_child(go)
	AHStationReport.fit_key(go, 52.0)
	box.reset_size()
	box.size = box.get_combined_minimum_size()
	box.position = (Vector2(1920, 1080) - box.size) * 0.5
	AHKit.focus_later(go)
	Sound.play("res://audio/ui/click.ogg", 0.5)


## G / X: a confirmação abre; com ela aberta, inicia.
func press_start() -> void:
	if not confirm_open():
		open_confirm()
		return
	close_confirm()
	start_confirmed.emit()


func close_confirm() -> void:
	if is_instance_valid(_confirm):
		_confirm.queue_free()
		remove_child(_confirm)
	_confirm = null


func _summary_line(icon_name: String, title: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_icon(icon_name, 28, AHKit.MUTED))
	var head := AHKit.label(title, "text", AHKit.MUTED, true)
	head.custom_minimum_size = Vector2(170, 0)
	row.add_child(head)
	row.add_child(_wrap(text, "text", AHKit.TEXT, 540.0))
	return row


# ---------------------------------------------------------------- peças

func _chip(text: String) -> Button:
	var button := AHKit.button(text, "chip")
	AHOptionsPanel._chip_font(button)
	return button


func _step_button(text: String, enabled: bool) -> Button:
	var button := AHKit.button(text, "icon")
	button.text = text
	button.custom_minimum_size = Vector2(52, 52)
	button.disabled = not enabled
	return button


func _icon(name: String, side: float, tint: Color) -> TextureRect:
	var rect := AHKit.glyph(name, side, tint)
	if rect.texture == null:
		rect.texture = AHKit.legacy_icon(name)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect


func _wrap(text: String, role: String, color: Color, width: float) -> Label:
	var label := AHKit.label(text, role, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	return label
