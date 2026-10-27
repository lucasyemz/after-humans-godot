## A moldura das telas da Estação no kit (#60, docs/design/hud-estacao.md, "O padrão das telas da Estação"), a mesma em
## todas: a vista geral, os cômodos, a Sala dos Personagens, as Opções e o Plano.
## - No alto: a plaqueta "ESTAÇÃO RAIZ" com o nome da tela; à direita, os materiais (sementes, sucata, fragmentos,
##   curativos) numa ficha, Comida, Água e Energia, e a engrenagem (as Opções). Faltando Comida, o chip troca o ícone
##   pelo alerta (a forma avisa no daltonismo).
## - Embaixo: VOLTAR (nos cômodos), a barra das teclas, as abas da Estação (a ativa sublinhada em âmbar) e o botão
##   principal, IR AO MAPA (G / X), bloqueado com o motivo dentro (AHStationRules.preparation_block).
## A moldura só monta as peças: as ações vêm de quem a usa (o HUD da Estação e a Sala).
class_name AHStationFrame
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")
## As abas de baixo: o id, o ícone e o nome.
const NAV := [["overview", "nav_overview", "Visão geral"], ["facilities", "nav_facilities", "Instalações"], ["characters", "nav_characters", "Personagens"],
	["research", "nav_research", "Pesquisa"], ["hide", "nav_hide", "Ocultar HUD"]]
## Os materiais da ficha do alto: o ícone, o id no estoque e a dica do mouse.
const MATERIALS := [["lobby-seed", "seeds", "Sementes: moeda da Estação (comida extra na partida, recrutas e o trauma)."],
	["lobby-scrap", "scrap", "Sucata: recupera cômodos e fabrica relíquias na Forja."],
	["lobby-fragment", "fragments", "Fragmentos: restos raros para pesquisas e melhorias."],
	["res-bandages", "bandages", "Curativos: +8 de vida, na expedição e no acampamento."]]
const TOP := 14.0
## O pé dos botões de baixo (VOLTAR, as abas e o principal).
const BACK_Y := 920.0
const NAV_Y := 994.0
const KEYS_Y := 928.0
const SCREEN_RIGHT := 1888.0
const SCREEN_BOTTOM := 1066.0


## O alto: a plaqueta (o nome da tela embaixo de "ESTAÇÃO RAIZ"), os materiais, Comida, Água e Energia e a engrenagem.
static func top(parent: Control, campaign: Dictionary, subtitle: String, on_options: Callable) -> Dictionary:
	var plaque := AHKit.plaque()
	plaque.name = "Plaque"
	plaque.position = Vector2(28, TOP)
	plaque.custom_minimum_size = Vector2(440, 96)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(plaque)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_child(row)
	var glyph := AHKit.glyph("station", 52, AHKit.TEXT)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -4)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(names)
	var title := AHKit.label(TranslationServer.translate("Estação Raiz"), "panel_title", AHKit.TEXT, true, true)
	title.name = "Title"
	names.add_child(title)
	var sub := AHKit.label(subtitle, "text", AHKit.MUTED)
	sub.name = "Subtitle"
	names.add_child(sub)
	# A engrenagem no canto; antes dela, da direita para a esquerda, Energia, Água, Comida e os materiais.
	var gear := Button.new()
	gear.name = "Options"
	gear.tooltip_text = TranslationServer.translate("Opções")
	var cog := TextureRect.new()
	cog.texture = AHKit.legacy_icon("lobby-settings")
	cog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cog.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cog.modulate = AHKit.TEXT
	cog.position = Vector2(20, 20)
	cog.size = Vector2(52, 52)
	cog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear.add_child(cog)
	AHKit.style_as(gear, "icon", Vector4(18, 18, 18, 18))
	gear.custom_minimum_size = Vector2(92, 92)
	gear.position = Vector2(1800, TOP)
	gear.pressed.connect(on_options)
	parent.add_child(gear)
	var chips := HBoxContainer.new()
	chips.name = "Resources"
	chips.add_theme_constant_override("separation", 10)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(chips)
	chips.add_child(materials(campaign))
	for vital in S.vitals(campaign, 4):
		chips.add_child(vital_chip(vital))
	chips.reset_size()
	chips.size = chips.get_combined_minimum_size()
	chips.position = Vector2(1790 - chips.size.x, TOP)
	return {"plaque": plaque, "title": title, "subtitle": sub, "resources": chips, "options": gear}


## Os materiais numa ficha só: o ícone e o número de cada um (o nome na dica do mouse).
static func materials(campaign: Dictionary) -> PanelContainer:
	var chip := AHKit.chip("resource")
	chip.name = "Materials"
	chip.custom_minimum_size = Vector2(0, 96)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	for spec in MATERIALS:
		var item := HBoxContainer.new()
		item.name = "Material_%s" % spec[1]
		item.add_theme_constant_override("separation", 6)
		item.tooltip_text = TranslationServer.translate(spec[2])
		item.mouse_filter = Control.MOUSE_FILTER_PASS
		var icon := TextureRect.new()
		# Os materiais pintados (#125), como Comida, Água e Energia ao lado: a barra num estilo só.
		var painted := AHKit.painted(spec[0])
		icon.texture = painted if painted != null else AHKit.legacy_icon(spec[0])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(30, 30)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.modulate = Color.WHITE if painted != null else AHKit.TEXT
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(icon)
		item.add_child(AHKit.label(str(S.quantity(campaign, spec[1])), "row", AHKit.TEXT, true))
		row.add_child(item)
	return chip


## Comida, Água ou Energia: o ícone, o nome, o valor e o que acontece na volta (faltando, a cor e o ícone de alerta).
static func vital_chip(vital: Dictionary) -> PanelContainer:
	var chip := AHKit.chip("resource")
	chip.name = "Vital_%s" % vital.id
	chip.custom_minimum_size = Vector2(236, 96)
	chip.tooltip_text = vital.tip
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	var icon := TextureRect.new()
	var painted := AHKit.icon("resource_%s" % vital.id)
	icon.texture = painted if painted != null else AHKit.legacy_icon(vital.icon)
	icon.modulate = Color.WHITE if painted != null else AHKit.TEXT
	# Faltando, o ícone também vira o alerta (o triângulo): a forma avisa no daltonismo (hud-estacao.md).
	if vital.warn:
		icon.name = "Alert"
		icon.texture = AHKit.icon("alert")
		icon.modulate = AHKit.alert_text()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", -2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	column.add_child(AHKit.label(vital.label, "small", AHKit.MUTED, false, true))
	column.add_child(AHKit.label(vital.value, "row", AHKit.alert_text() if vital.warn else AHKit.AMBER, true))
	column.add_child(AHKit.label(vital.note.trim_prefix("! "), "small", AHKit.alert_text() if vital.warn else AHKit.MUTED))
	return chip


## VOLTAR (nos cômodos): o botão de aço com a seta, embaixo à esquerda.
static func back_button(parent: Control, action: Callable) -> Button:
	var back := Button.new()
	back.name = "Back"
	back.text = TranslationServer.translate("Voltar").to_upper()
	AHKit.style_as(back, "secondary", Vector4(36, 0, 0, 0))
	# A seta para trás: a da direita espelhada (não há a da esquerda nos ícones).
	var arrow := TextureRect.new()
	arrow.name = "Arrow"
	arrow.texture = AHKit.legacy_icon("ui-arrow-right")
	arrow.flip_h = true
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow.modulate = AHKit.TEXT
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.custom_minimum_size = Vector2(28, 28)
	arrow.size = Vector2(28, 28)
	back.add_child(arrow)
	var place := func():
		if not is_instance_valid(back):
			return
		arrow.position = Vector2(back.size.x * 0.5 - back.get_theme_font("font").get_string_size(back.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		back.get_theme_font_size("font_size")).x * 0.5 - 26.0, (back.size.y - 28.0) * 0.5)
	back.resized.connect(place)
	place.call_deferred()
	back.add_theme_font_override("font", AHKit.font(true))
	back.add_theme_font_size_override("font_size", AHKit.size("primary"))
	back.custom_minimum_size = Vector2(216, 64)
	back.position = Vector2(28, BACK_Y)
	back.pressed.connect(action)
	parent.add_child(back)
	return back


## A barra das teclas: pares [ação ou tecla, o que faz], centrada em center entre left e right (o que não cabe sai do fim, par a
## par). Com os controles de toque na tela, ela some.
static func keys(parent: Control, pairs: Array, center: float, left: float, right: float) -> PanelContainer:
	var bar := AHKit.panel(AHKit.piece_of("key", "bar"))
	bar.name = "Keys"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)
	for spec in pairs:
		# Uma ação ("interact") mostra a tecla dela e acompanha a troca nas Opções; o resto ("Setas", "Esc") é fixo.
		row.add_child(AHKitKey.make(spec[0]) if InputMap.has_action(spec[0]) else AHKitKey.make("", spec[0]))
		row.add_child(AHKit.label(spec[1], "text", AHKit.TEXT))
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(8, 0)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(gap)
	parent.add_child(bar)
	while bar.get_combined_minimum_size().x > right - left and row.get_child_count() > 3:
		for i in 3:
			var last := row.get_child(row.get_child_count() - 1)
			row.remove_child(last)
			last.queue_free()
	bar.reset_size()
	bar.size = bar.get_combined_minimum_size()
	bar.position = Vector2(clampf(center - bar.size.x * 0.5, left, maxf(left, right - bar.size.x)), KEYS_Y)
	bar.visible = not Settings.touch_visible()
	return bar


## As abas da Estação (active: o id da aba acesa, ou "" na Preparação); nav recebe o id apertado.
static func tabs(parent: Control, active: String, nav: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Nav"
	row.add_theme_constant_override("separation", 6)
	row.position = Vector2(28, NAV_Y)
	parent.add_child(row)
	for spec in NAV:
		var tab := Button.new()
		tab.name = "Nav_%s" % spec[0]
		tab.text = TranslationServer.translate(spec[2]).to_upper()
		tab.icon = AHKit.icon(spec[1])
		tab.add_theme_constant_override("icon_max_width", 30)
		var on: bool = spec[0] == active
		AHKit.style_as(tab, "nav_active" if on else "nav")
		tab.add_theme_font_override("font", AHKit.font(true))
		tab.add_theme_font_size_override("font_size", AHKit.size("tab"))
		if on:
			for state in ["font_color", "font_hover_color", "font_focus_color"]:
				tab.add_theme_color_override(state, AHKit.AMBER)
			tab.add_theme_color_override("icon_normal_color", AHKit.AMBER)
		tab.custom_minimum_size = Vector2(0, 72)
		var id: String = spec[0]
		tab.pressed.connect(func(): nav.call(id))
		row.add_child(tab)
	return row


## O botão principal embaixo à direita: IR AO MAPA (ou o texto pedido, INICIAR EXPEDIÇÃO na plataforma), com a tecla
## G / X; com block, apagado e com o motivo dentro, embaixo do título.
static func prepare(parent: Control, text: String, icon_name: String, block: String, action: Callable) -> Button:
	var button := AHStationReport._primary(text, icon_name, "station_prepare")
	# Bloqueado, o nome diz (os testes e a QA acham o motivo por ele).
	button.name = "Prepare" if block == "" else "PrepareBlocked"
	if block != "":
		for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			if button.has_theme_stylebox_override(state):
				button.get_theme_stylebox(state).content_margin_bottom += AHUiStyle.px(26)
	# A tecla G com o X do controle, que acompanha a troca nas Opções (refresh_keys com ah_format).
	var key: Control = button.get_node("Key")
	key.set_meta("ah_action", "station_prepare")
	key.set_meta("ah_format", "%s / X")
	(key.get_child(0) as Label).text = "%s / X" % AHUiStyle.key_name("station_prepare")
	button.disabled = block != ""
	if block != "":
		button.tooltip_text = block
		var reason := AHKit.label(block, "small", AHKit.TEXT)
		reason.name = "Reason"
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reason.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		reason.offset_left = 40
		reason.offset_right = -40
		reason.offset_top = -AHUiStyle.px(26) - 16
		reason.offset_bottom = -14
		button.add_child(reason)
		button.add_theme_color_override("font_disabled_color", AHKit.TEXT)
	button.pressed.connect(action)
	parent.add_child(button)
	AHStationReport.fit_key(button, 52.0)
	button.position = Vector2(SCREEN_RIGHT - button.size.x, SCREEN_BOTTOM - button.size.y)
	if block != "":
		# Bloqueado, a tecla fica na linha do título, acima do motivo.
		var title_band: float = button.size.y - AHUiStyle.px(26) - 14.0
		key.position.y = (title_band - key.size.y) * 0.5 + 4.0
	return button
