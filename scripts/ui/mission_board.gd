## A aba Missões solo do Mapa da Rede (#183): sobre a mesma pintura, os pinos das missões do dia (piscando), de quem
## está fora (o nome e os dias da volta) e dos capturados (o resgate); à direita, a lista ou a missão escolhida, com o
## texto, o que ela pede, a comida, a escolha do herói com o selo vago da chance e MANDAR. A tela é do AHPhaseMap: aqui
## só as peças (os pinos, o painel), que chamam de volta pick_mission, pick_hero e send_mission.
class_name AHMissionBoard
extends RefCounted

const M = preload("res://scripts/flow/side_mission_rules.gd")
const S = preload("res://scripts/flow/station_rules.gd")


## Os pinos sobre a pintura: as missões do quadro, quem está fora e os capturados. Cada pino é o farol (que pisca) e o
## rótulo (um botão). Devolve os botões (a ordem do teclado).
static func pins(map, c: Dictionary, parent: Control) -> Array:
	var buttons: Array = []
	for spot in M.board(c):
		var on: bool = map.mission == spot.id
		var pin := _pin(parent, "Mission_%s" % spot.id, TranslationServer.translate(String(M.mission(spot.id).Title)), "marker-here", AHKit.AMBER if on else AHKit.TEXT, M.spot_position(spot.spot), true)
		if on:
			pin.add_child(AHKit.selected_overlay())
		pin.pressed.connect(map.pick_mission.bind(String(spot.id)))
		buttons.append(pin)
	for entry in M.running(c):
		var days := M.days_left(c, entry)
		var pin := _pin(parent, "Away_%s" % entry.id, TranslationServer.translate("%s · volta em %d dia") % [entry.display_name, days] if days == 1 else TranslationServer.translate("%s · volta em %d dias") % [entry.display_name, days],
			"sleep", AHKit.MUTED, M.spot_position(int(entry.side_mission.get("spot", -1))), false)
		pin.focus_mode = Control.FOCUS_NONE
		pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for entry in M.captured(c):
		var pin := _pin(parent, "Captured_%s" % entry.id, TranslationServer.translate("Resgatar %s") % entry.display_name, "alert", AHKit.alert_text(), M.spot_position(int(entry.captured.get("spot", -1))), true)
		pin.pressed.connect(map.pick_mission.bind("captured:%s" % entry.id))
		buttons.append(pin)
	return buttons


## Um pino: a fileira com o farol e o rótulo, centrada no ponto da pintura sem sair dela. Devolve o rótulo.
static func _pin(parent: Control, pin_name: String, text: String, icon_name: String, tint: Color, at: Vector2, blink: bool) -> Button:
	var row := HBoxContainer.new()
	row.name = pin_name
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var beacon := AHPhaseMap._mark_icon(icon_name, 30, tint)
	beacon.name = "Beacon"
	row.add_child(beacon)
	var button := Button.new()
	button.name = "Label"
	AHKit.style_as(button, "list")
	button.text = text
	button.add_theme_font_override("font", AHKit.font(true))
	button.add_theme_font_size_override("font_size", AHKit.size("small"))
	button.add_theme_color_override("font_color", AHKit.MUTED if tint == AHKit.MUTED else AHKit.TEXT)
	button.custom_minimum_size = Vector2(0, 44)
	row.add_child(button)
	row.reset_size()
	row.size = row.get_combined_minimum_size()
	row.position = Vector2(clampf(at.x - row.size.x * 0.5, 4.0, 1116.0 - row.size.x), clampf(at.y - row.size.y * 0.5, 4.0, 626.0 - row.size.y))
	if blink:
		_blink(beacon)
	return button


## O farol pisca devagar (o alfa de 1 a 0,35 e de volta).
static func _blink(node: CanvasItem) -> void:
	var tween := node.create_tween().set_loops()
	tween.tween_property(node, "modulate:a", 0.35, 0.7).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------- o painel

## O painel da direita: sem missão escolhida, a lista (as do dia, quem está fora, os capturados e os relatórios); com
## uma, a missão e a escolha do herói.
static func aside(map, c: Dictionary, box: VBoxContainer, footer: VBoxContainer, width: float) -> void:
	var picked: String = map.mission
	if picked.begins_with("captured:"):
		_captured_aside(map, c, box, picked.trim_prefix("captured:"), width)
		return
	var row := M.mission(picked)
	if row.is_empty() or not M.board(c).any(func(spot): return spot.id == picked):
		_list_aside(map, c, box, width)
		return
	map._aside_head("marker-here", TranslationServer.translate(String(row.Title)), true)
	var facts := HBoxContainer.new()
	facts.add_theme_constant_override("separation", 8)
	box.add_child(facts)
	facts.add_child(_chip("sleep", TranslationServer.translate("%d dia") % int(row.Days) if int(row.Days) == 1 else TranslationServer.translate("%d dias") % int(row.Days)))
	facts.add_child(_chip("alert", danger_text(int(row.Danger))))
	facts.add_child(_chip("resource_supplies", TranslationServer.translate("Comida: %d") % M.food_cost(picked)))
	box.add_child(map._wrap(TranslationServer.translate(String(row.Text)), "small", AHKit.TEXT, width))
	box.add_child(AHKit.label(TranslationServer.translate("O que ela pede"), "small", AHKit.MUTED, true, true))
	var aptitudes: Dictionary = M.rules().get("Aptitudes", {})
	for need in row.get("Needs", []):
		box.add_child(map._wrap("· " + TranslationServer.translate(String(aptitudes.get(need, {}).get("Hint", ""))), "small", AHKit.TEXT, width))
	box.add_child(map._wrap(TranslationServer.translate("Recompensa: %s") % reward_text(String(row.Reward)), "small", AHKit.TEXT, width))
	box.add_child(AHKit.label(TranslationServer.translate("Quem vai"), "text", AHKit.AMBER, true, true))
	var heroes: Array = S.living(c).filter(func(entry): return not M.away(entry))
	if not heroes.any(func(entry): return entry.id == map.hero_pick):
		map.hero_pick = ""
	for entry in heroes:
		box.add_child(_hero_row(map, c, entry, picked))
	if heroes.is_empty():
		box.add_child(map._wrap(TranslationServer.translate("Ninguém na Estação pode ir agora."), "small", AHKit.MUTED, width))
	var block: String = M.send_block(c, map.hero_pick, picked) if map.hero_pick != "" else TranslationServer.translate("Escolha quem vai.")
	var go := AHStationReport._primary(TranslationServer.translate("Mandar em missão"), "route", "interact")
	go.name = "Send"
	go.custom_minimum_size = Vector2(0, 64)
	go.add_theme_font_size_override("font_size", AHKit.size("row"))
	AHPhaseMap.key_at_end(go)
	go.disabled = block != ""
	go.tooltip_text = block
	go.pressed.connect(map.send_mission)
	footer.add_child(go)
	if block != "" and map.hero_pick != "":
		footer.add_child(map._wrap(block, "small", AHKit.alert_text(), width))


## Uma linha por herói: o nome, a classe e o selo (ou o motivo de não poder ir).
static func _hero_row(map, c: Dictionary, entry: Dictionary, mission_id: String) -> Button:
	var button := AHKit.button("", "secondary")
	button.name = "Hero_%s" % entry.id
	AHKit.style_as(button, "list", Vector4(16, 0, 16, 0))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override("font_size", AHKit.size("text"))
	var block := S.deploy_block(entry)
	var seal := ""
	if block == "":
		var hint := M.hint(M.chance(c, entry, mission_id))
		seal = M.hint_text(hint)
		button.add_theme_color_override("font_color", hint_color(hint))
	else:
		button.disabled = true
		button.tooltip_text = block
	button.text = " · ".join([entry.display_name, seal if seal != "" else TranslationServer.translate("não pode ir")])
	if map.hero_pick == entry.id:
		button.add_child(AHKit.selected_overlay())
	button.pressed.connect(map.pick_hero.bind(String(entry.id)))
	return button


static func hint_color(hint: String) -> Color:
	match hint:
		"good":
			return AHKit.good()
		"risky":
			return AHKit.AMBER
	return AHKit.alert_text()


static func danger_text(danger: int) -> String:
	match danger:
		1:
			return TranslationServer.translate("Perigo baixo")
		2:
			return TranslationServer.translate("Perigo médio")
	return TranslationServer.translate("Perigo alto")


static func reward_text(kind: String) -> String:
	match kind:
		"seeds":
			return TranslationServer.translate("sementes")
		"scrap":
			return TranslationServer.translate("sucata")
		"fragments":
			return TranslationServer.translate("fragmentos")
		"supplies":
			return TranslationServer.translate("suprimentos")
		"bandages":
			return TranslationServer.translate("curativos")
	return kind


static func _chip(icon_name: String, text: String) -> PanelContainer:
	var chip := AHKit.chip("cost")
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	chip.add_child(line)
	line.add_child(AHPhaseMap._mark_icon(icon_name, 18, AHKit.TEXT))
	line.add_child(AHKit.label(text, "small", AHKit.TEXT))
	return chip


static func _list_aside(map, c: Dictionary, box: VBoxContainer, width: float) -> void:
	map._aside_head("route", TranslationServer.translate("Missões solo"), false)
	box.add_child(map._wrap(TranslationServer.translate("O rádio da Preparação capta pedidos e achados pelo bairro. Mande um herói sozinho: ele fica fora da equipe, do posto e da noite até voltar."), "small", AHKit.TEXT, width))
	box.add_child(map._wrap(TranslationServer.translate("Ninguém sabe ao certo o que espera lá fora: o selo diz só se a escolha parece boa."), "small", AHKit.MUTED, width))
	var reports: Array = M.state(c).get("reports", [])
	if not reports.is_empty():
		box.add_child(AHKit.label(TranslationServer.translate("Quem voltou"), "text", AHKit.AMBER, true, true))
		for report in reports:
			box.add_child(map._wrap(M.report_line(c, report), "small", AHKit.TEXT, width))
	var captured := M.captured(c)
	if not captured.is_empty():
		box.add_child(AHKit.label(TranslationServer.translate("Capturados"), "text", AHKit.alert_text(), true, true))
		for entry in captured:
			box.add_child(map._wrap(M.away_text(entry), "small", AHKit.TEXT, width))
	var running := M.running(c)
	if not running.is_empty():
		box.add_child(AHKit.label(TranslationServer.translate("Fora da Estação"), "text", AHKit.AMBER, true, true))
		for entry in running:
			var days := M.days_left(c, entry)
			box.add_child(map._wrap(TranslationServer.translate("%s: %s Volta em %d dia.") % [entry.display_name, TranslationServer.translate(String(M.mission(String(entry.side_mission.id)).get("Title", ""))) + ".", days] if days == 1
				else TranslationServer.translate("%s: %s Volta em %d dias.") % [entry.display_name, TranslationServer.translate(String(M.mission(String(entry.side_mission.id)).get("Title", ""))) + ".", days], "small", AHKit.TEXT, width))
	# Ninguém para partir (todos fora ou caídos): o dia passa daqui, para as missões voltarem.
	if S.rest_block(c) == "":
		box.add_child(map._wrap(TranslationServer.translate("Ninguém pode partir agora. Esperar um dia traz de volta quem está em missão."), "small", AHKit.TEXT, width))
		var wait := AHKit.button(TranslationServer.translate("Esperar um dia"), "secondary")
		wait.name = "Rest"
		wait.custom_minimum_size = Vector2(0, 56)
		wait.pressed.connect(map.rest_day)
		box.add_child(wait)
	box.add_child(AHKit.label(TranslationServer.translate("Hoje no rádio"), "text", AHKit.AMBER, true, true))
	var board := M.board(c)
	if board.is_empty():
		box.add_child(map._wrap(TranslationServer.translate("Nenhum pedido novo hoje."), "small", AHKit.MUTED, width))
	for spot in board:
		var row := M.mission(spot.id)
		var item := AHKit.button("", "secondary")
		item.name = "List_%s" % spot.id
		AHKit.style_as(item, "list", Vector4(16, 0, 16, 0))
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.text = " · ".join([TranslationServer.translate(String(row.Title)), danger_text(int(row.Danger))])
		item.add_theme_font_size_override("font_size", AHKit.size("text"))
		item.custom_minimum_size = Vector2(0, 52)
		item.pressed.connect(map.pick_mission.bind(String(spot.id)))
		box.add_child(item)


static func _captured_aside(map, c: Dictionary, box: VBoxContainer, hero_id: String, width: float) -> void:
	var entry = S.hero(c, hero_id)
	if entry == null or not M.captured(c).has(entry):
		map.mission = ""
		_list_aside(map, c, box, width)
		return
	map._aside_head("alert", TranslationServer.translate("Resgatar %s") % entry.display_name, true)
	var row := M.mission(String(entry.captured.mission))
	box.add_child(map._wrap(TranslationServer.translate("Os robôs levaram %s em %s.") % [entry.display_name, TranslationServer.translate(String(row.get("Title", "")))], "small", AHKit.TEXT, width))
	box.add_child(map._wrap(TranslationServer.translate("O sinal segue no rádio. O resgate entra na rota da fase, sem prazo: ninguém se perde esperando."), "small", AHKit.MUTED, width))
