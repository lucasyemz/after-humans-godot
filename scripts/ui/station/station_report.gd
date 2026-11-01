## O relatório da volta no kit (#60, docs/design/hud-station.md): a tela inteira, por cima da fila na plataforma.
## - A faixa do alto (report_band): a fase e o resultado; os chips do que aconteceu (o guardião, o lugar liberado, o
##   objetivo) e a dica da noite; os recursos recuperados.
## - As cartas dos heróis (hero_card) no pé da tela, na ordem da fila, cada uma sob o seu herói (card_centers() diz onde;
##   a Estação põe cada um da fila sobre o centro da sua carta).
## - VER DETALHES (V/LB, a ação report_details) troca as cartas pela segunda faixa: o que a equipe viu, o que chegou, a
##   Estação no ciclo e o que dá para fazer agora.
## - ENTRAR NO ABRIGO (Interagir) segue para a noite, o trem ou o cômodo.
## Recebe o relatório pronto (campaign.station.last_return) e só mostra: as regras ficam em AHStationRules.
class_name AHStationReport
extends Control

signal enter_shelter
signal room_requested(room_id: String)

const S := preload("res://scripts/flow/station_rules.gd")
const J := preload("res://scripts/flow/journey_rules.gd")
const BAND := Rect2(36, 24, 1848, 216)
const DETAILS := Rect2(96, 668, 1728, 256)
const CARD_WIDTH := 380.0
const CARD_STEP := 416.0
const CARD_TOP := 678.0
const BUTTON_Y := 994.0
## Os recursos que a volta pode trazer: o ícone (pintado quando existir no kit, senão o SVG do jogo), a chave do
## relatório e os nomes.
const RESOURCES := [["resource_seeds", "lobby-seed", "seeds", "Semente", "Sementes"], ["resource_scrap", "lobby-scrap", "scrap", "Sucata", "Sucata"],
	["resource_fragments", "lobby-fragment", "fragments", "Fragmento", "Fragmentos"], ["resource_water", "lobby-water", "water", "Água", "Água"],
	["resource_supplies", "lobby-food", "supplies", "Suprimento", "Suprimentos"]]
const RELIC_ICONS := {"botao_cobre": "relic-copper-button", "pena_vidro": "relic-glass-feather", "coleira_lembranca": "relic-memory-collar"}

var report: Dictionary = {}
var details := false
var _animated := false
var _cards: HBoxContainer
var _details: PanelContainer
var _enter: Button
var _toggle: Button


static func make(last_return: Dictionary) -> AHStationReport:
	var screen := AHStationReport.new()
	screen.report = last_return
	screen.name = "StationReport"
	return screen


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


## O centro (x na tela) da carta de cada herói ({hero_id: x}): a Estação põe cada um da fila sobre a sua.
func card_centers() -> Dictionary:
	var team: Array = _team()
	var out := {}
	for i in team.size():
		out[team[i]] = 960.0 + (i - (team.size() - 1) * 0.5) * CARD_STEP
	return out


func _team() -> Array:
	var c: Dictionary = Campaign.state
	return scene_order(report.get("team", []).filter(func(id): return S.hero(c, id) != null))


## A equipe na ordem da cena (#131): a formação que o jogador deixou, com a posição 1 (a frente) à direita e a 4 à
## esquerda, como na Preparação e na luta. team vem da frente para trás.
static func scene_order(team: Array) -> Array:
	var out := team.duplicate()
	out.reverse()
	return out


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_band()
	_cards = HBoxContainer.new()
	_cards.name = "Cards"
	_cards.add_theme_constant_override("separation", int(CARD_STEP - CARD_WIDTH))
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cards)
	for hero_id in _team():
		_cards.add_child(_card(hero_id))
	_cards.reset_size()
	_cards.position = Vector2(960.0 - _cards.get_combined_minimum_size().x * 0.5, CARD_TOP - (4.0 if AHUiStyle.text_scale > 1.2 else 0.0))
	_details = _details_band()
	_details.visible = details
	_cards.visible = not details
	add_child(_details)
	_buttons()


func toggle_details() -> void:
	details = not details
	_details.visible = details
	_cards.visible = not details
	_toggle.text = tr("Ver a equipe").to_upper() if details else tr("Ver detalhes").to_upper()
	_fit_buttons()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("report_details"):
		get_viewport().set_input_as_handled()
		toggle_details()


func restyle() -> void:
	var focused := get_viewport().gui_get_focus_owner() == _toggle if get_viewport() != null else false
	_build()
	if focused:
		AHKit.focus_later(_toggle)


# ---------------------------------------------------------------- a faixa do alto

func _band() -> void:
	var band := Panel.new()
	band.name = "Band"
	band.add_theme_stylebox_override("panel", AHKit.style(AHKit.piece_of("panel", "band")))
	band.position = BAND.position
	band.size = BAND.size
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	var c: Dictionary = Campaign.state
	var phase := J.phase(report.get("phase_id", ""))
	var result: String = report.get("result", "")
	# À esquerda: de onde, a fase e o resultado.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	left.position = Vector2(26, 20)
	left.size = Vector2(600, 176)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(left)
	var where := HBoxContainer.new()
	where.add_theme_constant_override("separation", 10)
	where.add_child(AHKit.glyph("station", AHKit.size("text") + 6, AHKit.MUTED))
	var kicker := AHKit.label(tr("Estação Raiz · Relatório da expedição"), "text", AHKit.MUTED, false, true)
	where.add_child(kicker)
	left.add_child(where)
	var title := AHKit.label(tr(phase.get("name", "")), "phase_name", AHKit.TEXT, true, true)
	title.name = "Phase"
	# O nome longo (Laboratório Silencioso, ou o Maior) diminui até caber na coluna.
	var title_size := AHKit.size("phase_name")
	while title_size > AHKit.size("panel_title") and AHKit.font(true).get_string_size(title.text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > 590.0:
		title_size -= 2
	title.add_theme_font_size_override("font_size", title_size)
	left.add_child(title)
	var outcome := _outcome(result)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.add_child(AHKit.glyph(outcome.icon, AHKit.size("card_name") - 4, outcome.color))
	var result_label := AHKit.label(outcome.text, "card_name", outcome.color, false)
	result_label.name = "Result"
	line.add_child(result_label)
	left.add_child(line)
	band.add_child(_divider(648))
	# À direita, o que chegou: a coluna tem a largura dos quadros (o nome inteiro embaixo de cada um), e o meio fica
	# com o resto.
	var shown: Array = RESOURCES.filter(func(spec): return int(report.get(spec[2], 0)) > 0)
	var tile_width := 104.0 if shown.size() <= 3 else 80.0
	var boxes: Array = []
	var right_width := 0.0
	for spec in shown:
		var amount := int(report.get(spec[2], 0))
		var name_width := AHKit.font(false).get_string_size(tr(spec[3] if amount == 1 else spec[4]), HORIZONTAL_ALIGNMENT_LEFT, -1, AHKit.size("small")).x
		var width := maxf(tile_width, ceilf(name_width) + 4.0)
		boxes.append(_resource(spec, amount, tile_width, width))
		right_width += width
	right_width += 8.0 * maxi(0, shown.size() - 1)
	var heading := AHKit.label(tr("Recursos recuperados"), "text", AHKit.MUTED, false, true)
	right_width = maxf(right_width, maxf(240.0, heading.get_minimum_size().x))
	var right_x := BAND.size.x - 30.0 - right_width
	# No meio: os chips e a dica da noite.
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 14)
	middle.position = Vector2(672, 30)
	middle.size = Vector2(right_x - 24.0 - 672.0 - 24.0, 170)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(middle)
	# Os chips em linhas (no Maior, quebram em duas): montadas à mão, para a faixa saber a altura já na montagem.
	var chips := VBoxContainer.new()
	chips.name = "Chips"
	chips.add_theme_constant_override("separation", 10)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(chips)
	var specs := _chips(c, result)
	var chip_width := clampf((middle.size.x - 12.0 * maxi(0, specs.size() - 1)) / maxf(1.0, specs.size()), 180.0, 232.0)
	var per_row := maxi(1, floori((middle.size.x + 12.0) / (chip_width + 12.0)))
	var chip_row: HBoxContainer
	for i in specs.size():
		if i % per_row == 0:
			chip_row = HBoxContainer.new()
			chip_row.add_theme_constant_override("separation", 12)
			chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chips.add_child(chip_row)
		chip_row.add_child(_result_chip(specs[i].icon, specs[i].text, specs[i].color, chip_width))
	var hint := _night_hint(c)
	if hint != "":
		var hint_row := HBoxContainer.new()
		hint_row.add_theme_constant_override("separation", 12)
		hint_row.add_child(AHKit.glyph("bed", AHKit.size("text") + 10, AHKit.TEXT))
		var hint_label := AHKit.label(hint, "text", AHKit.TEXT)
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_label.custom_minimum_size = Vector2(middle.size.x - 60.0, 0)
		hint_row.add_child(hint_label)
		middle.add_child(hint_row)
	band.add_child(_divider(right_x - 24.0))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.position = Vector2(right_x, 18)
	right.size = Vector2(right_width, 180)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(right)
	right.add_child(heading)
	var tiles := HBoxContainer.new()
	tiles.name = "Resources"
	tiles.add_theme_constant_override("separation", 8)
	right.add_child(tiles)
	if shown.is_empty():
		tiles.add_child(AHKit.label(tr("Nada chegou desta vez."), "text", AHKit.MUTED))
	for i in boxes.size():
		var tile: Control = boxes[i]
		tiles.add_child(tile)
		# O achado entra um a um, com o som das moedas (como no relatório antigo); só na primeira vez que a tela abre.
		if not _animated:
			tile.modulate.a = 0.0
			var tween := create_tween()
			tween.tween_interval(0.25 + 0.22 * i)
			tween.tween_property(tile, "modulate:a", 1.0, 0.25)
			tween.tween_callback(func(): Sound.play("res://audio/world/find_coins.ogg", 0.35, 1.0 + 0.06 * i))
	_animated = true
	# A faixa cresce para baixo quando o conteúdo pede (o Maior, os chips em duas linhas), e as divisões com ela.
	var height := maxf(BAND.size.y, maxf(20.0 + left.get_combined_minimum_size().y, maxf(30.0 + middle.get_combined_minimum_size().y,
		18.0 + right.get_combined_minimum_size().y)) + 22.0)
	band.size.y = height
	for divider in band.get_children():
		if divider is TextureRect and divider.has_meta("divider"):
			divider.size.y = height - 40.0


func _divider(x: float) -> TextureRect:
	var divider := TextureRect.new()
	divider.texture = AHKit.texture("band_divider")
	divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	divider.stretch_mode = TextureRect.STRETCH_SCALE
	divider.position = Vector2(x - 6, 20)
	divider.size = Vector2(12, 176)
	divider.set_meta("divider", true)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return divider


## O resultado da expedição: o ícone, o texto e a cor (concluída no verde do bom; retirada no âmbar; a fuga e a derrota
## no texto de alerta).
func _outcome(result: String) -> Dictionary:
	match result:
		"victory":
			return {"icon": "state_active", "text": tr("Expedição concluída"), "color": AHKit.good()}
		"retreat":
			return {"icon": "state_light_wound", "text": tr("Retirada: metade do achado"), "color": AHKit.AMBER}
		"fled":
			return {"icon": "objective_failed", "text": tr("Fuga: nada chegou"), "color": AHKit.alert_text()}
	return {"icon": "state_wounded", "text": tr("A equipe caiu"), "color": AHKit.alert_text()}


## Os chips do que aconteceu: o guardião derrotado, o lugar liberado (na primeira vitória da fase) e o objetivo da rota
## (cumprido, ou não, com a cor de perigo).
func _chips(c: Dictionary, result: String) -> Array:
	var out: Array = []
	if report.get("tutorial", false):
		# A chegada da abertura (#144): não há guardião; o que a fuga trouxe além das sementes (o curativo, a ferramenta).
		out.append({"icon": "objective_done", "text": tr("A fuga até o trem"), "color": AHKit.TEXT})
		if int(report.get("bandages", 0)) > 0:
			out.append({"icon": "res-bandages", "text": tr("+%d curativo") % report.bandages if int(report.bandages) == 1 else tr("+%d curativos") % report.bandages, "color": AHKit.TEXT})
		var tool := String(report.get("tool", ""))
		if tool != "":
			out.append({"icon": AHInventoryPanel.TOOL_ICONS.get(tool, "tool-generic"), "text": tr(AHInventoryPanel.TOOL_NAMES.get(tool, tool)), "color": AHKit.TEXT})
		return out
	if result == "victory":
		out.append({"icon": "guardian_defeated", "text": tr("Guardião derrotado"), "color": AHKit.TEXT})
	var unlocked := String(report.get("unlocked_phase", ""))
	if unlocked != "":
		out.append({"icon": "place_unlocked", "text": tr("%s liberada") % tr(J.phase(unlocked).get("name", "")), "color": AHKit.TEXT})
	# A roupa nova (#138): a skin que veio com a fase terminada; a Sala dos Personagens já mostra a aba dela.
	for skin_id in report.get("skins", []):
		var skin = GameData.row("skins", String(skin_id))
		if skin != null:
			# Curto (o nome da aba da Sala): no Maior, o nome inteiro quebrava em 7 linhas e a faixa cobria a plataforma.
			out.append({"icon": "room_quarters", "text": tr("Roupa nova: %s") % tr(String(skin.get("ShortName", skin.DisplayName))),
				"color": AHKit.AMBER})
	var focus := String(report.get("focus", ""))
	if focus != "":
		var done: bool = report.get("objective_done", false)
		var label := S.focus_label(focus)
		out.append({"icon": "objective_done" if done else "objective_failed",
			"text": (tr("Objetivo: %s cumprido") if done else tr("Objetivo: %s não cumprido")) % label.to_lower(),
			"color": AHKit.TEXT if done else AHKit.alert_text()})
	# Quem caiu (#118): ninguém morre, mas o relatório diz com clareza quem voltou em recuperação.
	var fell: Array = report.get("fallen", [])
	if fell.size() == 1:
		var hero = S.hero(c, String(fell[0].get("hero_id", "")))
		if hero != null:
			out.append({"icon": "state_wounded", "text": tr("%s caiu: em recuperação") % hero.display_name, "color": AHKit.alert_text()})
	elif fell.size() > 1:
		out.append({"icon": "state_wounded", "text": tr("%d caíram: em recuperação") % fell.size(), "color": AHKit.alert_text()})
	# Os postos de quem ficou na Estação (#119): o que renderam juntos.
	var posts: Array = report.get("posts", []).filter(func(p): return int(p.get("amount", 0)) > 0)
	if not posts.is_empty():
		out.append({"icon": "room_quarters", "text": tr("Postos: %s") % ", ".join(posts.map(func(p): return post_line(p))), "color": AHKit.TEXT})
	# A escavação (#186): o bloco aberto e o que ele devolveu, ou quanto andou.
	var dig: Dictionary = report.get("dig", {})
	if not dig.is_empty():
		out.append({"icon": "place_unlocked" if dig.get("opened", false) else "lock", "text": AHStationGrid.report_chip(dig),
			"color": AHKit.AMBER if dig.get("opened", false) else AHKit.TEXT})
	# O trem da volta (#122): chegou alguém, ou veio vazio (relatórios de antes não dizem nada).
	if report.has("train"):
		var arrived := String(report.train)
		# O Mercador (#182, parte 2) não é alguém que chega para ficar: ele veio trocar.
		var text := tr("Chegou alguém no trem: %s") % arrived if arrived != "" else tr("O trem veio vazio")
		if report.get("merchant", false):
			text = tr("O trem trouxe o Sr. dos Trilhos, o Mercador, para trocar")
		out.append({"icon": "train_arrival", "text": text, "color": AHKit.AMBER if arrived != "" else AHKit.MUTED})
	return out


func _result_chip(icon_name: String, text: String, color: Color, width: float = 232.0) -> PanelContainer:
	var chip := AHKit.chip("result")
	chip.custom_minimum_size = Vector2(width, 88)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	row.add_child(AHKit.glyph(icon_name, 44, color))
	var label := AHKit.label(text, "text", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width - 82.0, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return chip


## A dica da noite: com a noite pendente, o Dormitório antes de partir.
func _night_hint(c: Dictionary) -> String:
	if c.get("night", {}).get("phase", "none") != "none":
		return tr("Descanse no Dormitório antes da próxima expedição.")
	return ""


## O recurso recuperado: o quadro com o ícone (pintado, se o kit tiver; senão o do jogo, em âmbar), o número âmbar e o
## nome embaixo.
func _resource(spec: Array, amount: int, width: float, column: float) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(column, 0)
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_meta("resource", spec[2])
	var tile := AHKit.chip("resource_tile")
	tile.custom_minimum_size = Vector2(width, 84.0 * width / 104.0)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var painted := AHKit.icon(spec[0])
	var icon := TextureRect.new()
	icon.texture = painted if painted != null else AHKit.legacy_icon(spec[1])
	icon.modulate = Color.WHITE if painted != null else AHKit.TEXT
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(46, 46)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(icon)
	box.add_child(tile)
	var number := AHKit.label("+%d" % amount, "card_name", AHKit.AMBER, true)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(number)
	var name := AHKit.label(tr(spec[3] if amount == 1 else spec[4]), "small", AHKit.TEXT)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name)
	return box


# ---------------------------------------------------------------- as cartas

func _card(hero_id: String) -> Control:
	var c: Dictionary = Campaign.state
	var hero = S.hero(c, hero_id)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_meta("hero_id", hero_id)
	var card := AHKit.card("hero")
	card.name = "Card"
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	column.add_child(top)
	var frame := AHKit.panel("square_portrait")
	frame.custom_minimum_size = Vector2(92, 92)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var face := TextureRect.new()
	face.texture = AHUiStyle.face_texture(AHCombatArena.hero_art_of(hero.id, String(hero.get("art_variant", ""))).get("idle", {}))
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.clip_contents = true
	# Quem caiu nesta expedição (#118) volta Caído: o retrato apagado e o estado em vermelho.
	var fell := fell_here(hero_id)
	if fell or not hero.alive:
		face.modulate = AHKit.FALLEN
	frame.add_child(face)
	top.add_child(frame)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	var stats: Dictionary = report.get("stats", {}).get(hero_id, {})
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	names.add_child(name_row)
	var name_label := AHKit.label(String(hero.display_name), "card_name", AHKit.TEXT, true, true)
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_row.add_child(name_label)
	# O destaque da volta (quem mais fez: dano, cura em dobro e quedas valendo cinco) ganha a estrela âmbar.
	if hero_id == _best() and not fell:
		var star := AHKit.label("★", "card_name", AHKit.AMBER, true)
		star.name = "Best"
		star.tooltip_text = tr("Destaque da expedição")
		star.mouse_filter = Control.MOUSE_FILTER_PASS
		name_row.add_child(star)
	# O XP desta volta, ao lado do nome.
	if not fell and int(stats.get("xp", 0)) > 0:
		var xp := AHKit.label(tr("+%d XP") % int(stats.xp), "text", AHKit.XP, true)
		xp.name = "Xp"
		xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_row.add_child(xp)
	var hero_class = GameData.row("classes", String(hero.class_id))
	if hero_class != null:
		names.add_child(AHKit.label(tr(String(hero_class.DisplayName)), "text", AHKit.MUTED))
	if fell:
		names.add_child(fallen_line(hero))
	else:
		var state_row := HBoxContainer.new()
		state_row.add_theme_constant_override("separation", 12)
		names.add_child(state_row)
		var pill := AHKitPill.make(int(hero.hp), int(hero.max_hp))
		state_row.add_child(pill)
	# A vida: no texto Maior, o número vai na linha da barra (a carta não cresce para cima da fila).
	var big := AHUiStyle.text_scale > 1.2
	var life_row := HBoxContainer.new() if big else null
	var life := HBoxContainer.new()
	life.add_theme_constant_override("separation", 10)
	life.add_child(AHKit.label(tr("Vida"), "text", AHKit.MUTED, false, true))
	life.add_child(AHKit.label("%d / %d" % [hero.hp, hero.max_hp], "text", AHKit.TEXT, true))
	var bar := AHKit.bar("life", hero.hp, hero.max_hp)
	bar.custom_minimum_size = Vector2(0, 28)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if big:
		life_row.add_theme_constant_override("separation", 10)
		life_row.add_child(life)
		life_row.add_child(bar)
		column.add_child(life_row)
	else:
		column.add_child(life)
		column.add_child(bar)
	# As expedições e os abates da carreira; o XP desta volta.
	var counters := HBoxContainer.new()
	counters.add_theme_constant_override("separation", 8)
	counters.add_child(AHKit.glyph("expeditions", 26, AHKit.MUTED))
	counters.add_child(AHKit.label(tr("Expedições"), "text", AHKit.MUTED))
	counters.add_child(AHKit.label(str(int(hero.get("completed_expeditions", 0))), "text", AHKit.TEXT, true))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(8, 0)
	counters.add_child(gap)
	counters.add_child(AHKit.glyph("kills", 26, AHKit.MUTED))
	counters.add_child(AHKit.label(tr("Abates"), "text", AHKit.MUTED))
	counters.add_child(AHKit.label(str(int(hero.get("kills_count", 0))), "text", AHKit.TEXT, true))
	column.add_child(counters)
	var relic_row := HBoxContainer.new()
	relic_row.add_theme_constant_override("separation", 10)
	var relic = GameData.row("relics", String(hero.get("relic_id", "")))
	if relic != null:
		var relic_icon := TextureRect.new()
		relic_icon.texture = AHKit.legacy_icon(RELIC_ICONS.get(String(hero.relic_id), "relic-generic"))
		relic_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		relic_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		relic_icon.custom_minimum_size = Vector2(26, 26)
		relic_icon.modulate = AHKit.AMBER
		relic_row.add_child(relic_icon)
		relic_row.add_child(AHKit.label(tr(String(relic.DisplayName)), "text", AHKit.TEXT))
	else:
		relic_row.add_child(AHKit.glyph("relic_empty", 26, AHKit.MUTED))
		relic_row.add_child(AHKit.label(tr("Sem relíquia"), "text", AHKit.TEXT))
	column.add_child(relic_row)
	# A aba da melhoria da classe (a Pesquisa): quando há o que pesquisar para ela.
	var research := _research_for(c, String(hero.class_id))
	if not fell and not research.is_empty():
		var tab := AHKit.tab("card")
		tab.name = "Tab"
		tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tab_row := HBoxContainer.new()
		tab_row.add_theme_constant_override("separation", 8)
		tab_row.add_child(AHKit.glyph("train", 24, AHKit.AMBER))
		tab_row.add_child(AHKit.label(tr("Melhoria · %d frag.") % int(research.CostFragments), "text", AHKit.AMBER))
		tab.add_child(tab_row)
		holder.add_child(tab)
		tab.position = Vector2(28, -38)
	holder.custom_minimum_size.y = card.get_combined_minimum_size().y
	return holder


## O que um posto rendeu, curto: "+2 fragmentos", "1 dia a menos".
static func post_line(entry: Dictionary) -> String:
	var amount := int(entry.get("amount", 0))
	match String(S.job_rule(String(entry.get("room", ""))).get("Unit", "")):
		"fragments":
			return TranslationServer.translate("+%d fragmento") % amount if amount == 1 else TranslationServer.translate("+%d fragmentos") % amount
		"scrap":
			return TranslationServer.translate("+%d sucata") % amount if amount == 1 else TranslationServer.translate("+%d sucatas") % amount
		"supplies":
			return TranslationServer.translate("+%d suprimento") % amount if amount == 1 else TranslationServer.translate("+%d suprimentos") % amount
		"days":
			return TranslationServer.translate("%d caído mais perto de voltar") % amount if amount == 1 else TranslationServer.translate("%d caídos mais perto de voltar") % amount
		"dig":
			return TranslationServer.translate("+%d ponto de obra") % amount if amount == 1 else TranslationServer.translate("+%d pontos de obra") % amount
	return ""


## Caiu nesta expedição (o relatório guarda quem chegou Caído).
func fell_here(hero_id: String) -> bool:
	return report.get("fallen", []).any(func(e): return String(e.get("hero_id", "")) == hero_id)


## "Caído · Volta em 2 dias", com o lugar embaixo ("Na Enfermaria" ou "No Dormitório"); já recuperado, "Recuperado".
static func fallen_line(hero: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Fallen"
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	row.add_child(AHKit.glyph("state_wounded", 24, AHKit.alert_text()))
	var days: int = S.recovery_days(hero)
	var text: String = (TranslationServer.translate("Caído") + " · " + S.return_text(days)) if days > 0 else TranslationServer.translate("Caído · recuperado")
	var label := AHKit.label(text, "text", AHKit.alert_text(), true)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(180, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	if days > 0:
		box.add_child(AHKit.label(TranslationServer.translate("Em recuperação na Enfermaria") if S.in_bed(hero) else TranslationServer.translate("Em recuperação no Dormitório"), "small", AHKit.MUTED))
	return box


## O destaque da volta ("" sem ninguém que tenha feito nada): o mesmo cálculo do relatório antigo.
func _best() -> String:
	var best := ""
	var best_score := 0
	var stats: Dictionary = report.get("stats", {})
	for hero_id in stats:
		var line: Dictionary = stats[hero_id]
		var score: int = int(line.get("damage", 0)) + int(line.get("healing", 0)) * 2 + int(line.get("downs", 0)) * 5
		if score > best_score:
			best_score = score
			best = hero_id
	return best


## A melhoria da Pesquisa ainda não feita para a classe ({} sem nenhuma, ou sem o Centro de Pesquisa).
func _research_for(c: Dictionary, class_id: String) -> Dictionary:
	if not S.room_available(c, S.RESEARCH):
		return {}
	for row in GameData.table("research").values():
		if String(row.get("ClassId", "")) == class_id and not c.get("researched_skills", []).has(String(row.get("SkillId", ""))):
			return row
	return {}


# ---------------------------------------------------------------- os detalhes

func _details_band() -> PanelContainer:
	var c: Dictionary = Campaign.state
	var band := AHKit.panel_box("band")
	band.name = "Details"
	band.position = DETAILS.position
	band.custom_minimum_size = DETAILS.size
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	band.add_child(columns)
	var story := String(report.get("story", ""))
	if story != "":
		columns.add_child(_detail_column(tr("O que a equipe viu"), [tr(story)]))
	var arrived: Array = []
	var percent := int(report.get("percent", 0))
	for spec in RESOURCES:
		var amount := int(report.get(spec[2], 0))
		if amount > 0:
			arrived.append("+%d %s" % [amount, tr(spec[3] if amount == 1 else spec[4]).to_lower()])
	if String(report.get("request", "")) != "":
		var who := S.civilian(report.request)
		arrived.append(tr("%s recebeu %s: %s") % [who.name, tr(who.request_item), tr(who.request_reward)])
	if arrived.is_empty():
		arrived.append(tr("Nada chegou desta vez."))
	columns.add_child(_detail_column(tr("O que chegou%s") % ("" if percent >= 100 else tr(" (%d%% do achado)") % percent), arrived))
	var cycle: Dictionary = report.get("cycle", {})
	# A escavação (#274): a linha inteira do chip, com a Estação do ciclo (uma coluna a
	# mais não cabe na faixa).
	var dug: Array = []
	var dig: Dictionary = report.get("dig", {})
	if not dig.is_empty():
		# Os textos do achado ficam no aviso, na vista geral (aqui a coluna passava da faixa).
		dug.append(AHStationGrid.report_line(dig))
	if cycle.is_empty() and not dug.is_empty():
		columns.add_child(_detail_column(tr("Escavação"), dug))
	if not cycle.is_empty():
		var lines: Array = [tr("A Cantina produziu %d suprimentos; os moradores comeram %d; estragaram %d. Água: %d bebida, %d do coletor%s.") % [
			cycle.food_produced, cycle.food_civilians, cycle.food_spoiled, cycle.water_consumed, cycle.water_produced, tr("; faltou para alguém") if cycle.thirsty else ""]]
		if int(cycle.get("fragments_produced", 0)) > 0:
			lines.append(tr("A Cora trouxe %d fragmento.") % cycle.fragments_produced)
		lines.append_array(dug)
		columns.add_child(_detail_column(tr("A Estação no ciclo %d") % cycle.number, lines))
	# O resgate (#188): quem saiu do cativeiro, entrou na equipe ou ficou.
	if String(report.get("rescue", "")) != "":
		columns.add_child(_detail_column(tr("Resgate"), [String(report.rescue)]))
	# As missões solo (#183): quem volta chega no trem, com o relatório, depois da missão principal; aqui fica só quem foi
	# capturado (não vem no trem).
	var captured: Array = cycle.get("missions", []).filter(func(entry): return String(entry.get("result", "")) == "captured")
	if not captured.is_empty():
		columns.add_child(_detail_column(tr("Com os robôs"), captured.map(func(entry): return AHSideMissions.report_line(c, entry))))
	var care := recovery_lines(c, report)
	if not care.is_empty():
		columns.add_child(_detail_column(tr("Recuperação"), care))
	var unlocks: Array = []
	for room_id in S.NEXT_ROOMS:
		if not S.next_level_cost(c, room_id).is_empty() and S.upgrade_block(c, room_id) == "":
			unlocks.append(room_id)
	if not unlocks.is_empty():
		var column := _detail_column(tr("Agora dá para"), [])
		for room_id in unlocks:
			var id: String = room_id
			var level := S.room_level(c, id)
			var button := Button.new()
			# Na grade (#186), o cômodo que entra numa vaga livre é construído (o Depósito saindo dos caixotes, a Cantina).
			var verb := tr("Construir") if AHStationGrid.needs_place(c, id) else (tr("Recuperar") if level == 0 else tr("Melhorar"))
			button.text = tr("%s %s%s (%s)") % [verb, tr(S.ROOM_ARTICLE.get(id, "")), tr(S.room_def(id).name), S.cost_text(S.next_level_cost(c, id))]
			AHKit.style_as(button, "secondary")
			button.add_theme_font_size_override("font_size", AHKit.size("text"))
			button.pressed.connect(func(): room_requested.emit(id))
			column.add_child(button)
		columns.add_child(column)
	return band


## As linhas da recuperação (#121): quem chegou Caído e para onde foi, e quem voltou da Enfermaria nesta volta.
static func recovery_lines(c: Dictionary, last_return: Dictionary) -> Array:
	var lines: Array = []
	for entry in last_return.get("fallen", []):
		var hero = S.hero(c, String(entry.get("hero_id", "")))
		if hero == null:
			continue
		var place := TranslationServer.translate("a Enfermaria") if bool(entry.get("bed", false)) else TranslationServer.translate("o Dormitório, sem leito livre")
		lines.append(TranslationServer.translate("%s foi para %s: %s.") % [hero.display_name, place, S.return_text(int(entry.get("days", 1))).to_lower()])
	for hero_id in last_return.get("recovered", []):
		var hero = S.hero(c, String(hero_id))
		if hero != null:
			lines.append(TranslationServer.translate("%s se recuperou e voltou ao Alojamento.") % hero.display_name)
	return lines


func _detail_column(title: String, lines: Array) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(AHKit.label(title, "row", AHKit.AMBER, true, true))
	for line in lines:
		var label := AHKit.label(line, "text", AHKit.TEXT)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(360, 0)
		column.add_child(label)
	return column


# ---------------------------------------------------------------- os botões

func _buttons() -> void:
	_enter = _primary(tr("Entrar no abrigo"), "station", "interact")
	_enter.name = "Enter"
	_enter.pressed.connect(func(): enter_shelter.emit())
	add_child(_enter)
	_toggle = Button.new()
	_toggle.name = "Details"
	_toggle.text = tr("Ver a equipe").to_upper() if details else tr("Ver detalhes").to_upper()
	_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	AHKit.style_as(_toggle, "secondary", Vector4(0, 0, 0, 0))
	_toggle.custom_minimum_size = Vector2(240, 64)
	var key := AHKitKey.make("", "%s / LB" % AHUiStyle.key_name("report_details"), "button")
	key.name = "Key"
	_toggle.add_child(key)
	_toggle.pressed.connect(toggle_details)
	add_child(_toggle)
	_fit_buttons()
	AHKit.focus_later(_enter)


## O botão principal âmbar com as divisas: o ícone, o texto e a tecla dentro (que cresce com o texto Maior).
static func _primary(text: String, icon_name: String, action: String) -> Button:
	var button := Button.new()
	button.text = text.to_upper()
	button.icon = AHKit.icon(icon_name)
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", 34)
	# O ícone afastado do título (no Maior, encostava).
	button.add_theme_constant_override("h_separation", 14)
	button.add_theme_color_override("icon_normal_color", AHKit.ON_AMBER)
	button.add_theme_color_override("icon_focus_color", AHKit.ON_AMBER)
	button.add_theme_color_override("icon_hover_color", AHKit.ON_AMBER)
	AHKit.style_as(button, "primary", Vector4(10, 0, 0, 0))
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(state, AHKit.ON_AMBER)
	button.custom_minimum_size = Vector2(480, 72)
	var key := AHKitKey.make("", "%s / A" % AHUiStyle.key_name(action), "button")
	key.name = "Key"
	button.add_child(key)
	return button


## A tecla no fim do botão, e o texto terminando antes dela (a tecla cresce com o Maior e com a troca nas Opções).
## inset: a distância da tecla até a borda direita (no botão principal, depois da divisa).
static func fit_key(button: Button, inset: float) -> void:
	var key: Control = button.get_node("Key")
	key.reset_size()
	var room := key.get_combined_minimum_size().x + inset + 16.0
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		if button.has_theme_stylebox_override(state):
			button.get_theme_stylebox(state).content_margin_right = room
	button.reset_size()
	button.size = button.get_combined_minimum_size()
	key.reset_size()
	key.position = Vector2(button.size.x - key.size.x - inset, (button.size.y - key.size.y) * 0.5)


## Os dois botões numa linha centrada no pé da tela (y 994), com 24 entre eles; as teclas no fim de cada um.
func _fit_buttons() -> void:
	for button in [_enter, _toggle]:
		fit_key(button, 52.0 if button == _enter else 14.0)
	var total := _enter.size.x + 24.0 + _toggle.size.x
	_enter.position = Vector2(960.0 - total * 0.5, BUTTON_Y + (64.0 - _enter.size.y) * 0.5)
	_toggle.position = Vector2(_enter.position.x + _enter.size.x + 24.0, BUTTON_Y)
