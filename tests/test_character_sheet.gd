## A ficha do personagem ao apontar (#89).
## - O que ela diz: espécie e papel (ou a máquina e o guardião do trecho), vida, instinto, velocidade, os traços, a
##   relíquia, os laços da jornada e os estados com o que cada um faz; bom e ruim na cor do daltonismo.
## - Na luta: abre e fecha pelo mouse no corpo, pelo alvo com foco do teclado e pelo toque longo; o toque curto não abre.
## - Na Preparação: abre e fecha pelo mouse, pelo foco e pelo toque longo, que não troca o herói ao soltar.
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var keys: bool = AHUiStyle.using_keys
	Campaign.save_dir = "user://test-sheet-%d" % Time.get_ticks_usec()
	var tips: bool = Tips.enabled
	Tips.enabled = false
	_info()
	await _combat()
	await _preparation()
	Tips.enabled = tips
	AHUiStyle.using_keys = keys
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _info() -> void:
	var c: Dictionary = Campaign.create_initial(89)
	Campaign.state = c
	var bento: Dictionary = S.hero(c, "hero_cao_bento")
	bento.perks = ["agile"]
	bento.relic_id = "botao_cobre"
	var info := AHCharacterSheet.from_hero(bento)
	t.equal(info.kind, "Cão · Tanque e Proteção", "a espécie e o papel")
	t.check(info.passives.any(func(p): return p[0] == "Ágil" and p[1].contains("Velocidade")), "o traço com o que faz")
	t.check(info.passives.any(func(p): return p[0].contains("Botão de Cobre")), "a relíquia")
	var base := int(GameData.row("classes", "cao").BaseSpeed)
	t.equal(info.speed, base + 1, "a velocidade com o traço Ágil")
	t.check(info.instinct >= 0, "o instinto do herói")
	c.researched_skills = ["cao_punho_sucata"]
	info = AHCharacterSheet.from_hero(bento)
	t.check(info.passives.any(func(p): return p[0].contains("Punho de Sucata")), "o treino da Pesquisa (researched_skills)")
	bento.trauma = true
	t.check(AHCharacterSheet.from_hero(bento).states.any(func(s): return s[0] == "Trauma" and s[1] != ""), "o trauma, com o que faz")
	var fallen := AHCombat.Unit.new()
	fallen.is_player = true
	fallen.hero_id = "hero_cao_bento"
	fallen.class_id = "cao"
	fallen.display_name = "Bento"
	fallen.hp = 0
	fallen.max_hp = 37
	fallen.deaths_door = true
	fallen.trauma = true
	var states: Array = AHCharacterSheet.from_unit(null, fallen).states.map(func(s): return s[0])
	t.check(states.has("Último Fôlego") and states.has("Trauma"), "na luta, o Último Fôlego e o trauma: %s" % [states])
	# Um inimigo com estados.
	var robot := AHCombat.Unit.new()
	robot.id = "e1"
	robot.enemy_id = "robot"
	robot.display_name = "Robô"
	robot.hp = 10
	robot.max_hp = 26
	robot.bleed.duration = 2
	robot.bleed.magnitude = 2
	robot.mark_duration = 1
	info = AHCharacterSheet.from_unit(null, robot)
	t.equal(info.kind, "Máquina", "a máquina")
	t.equal(info.instinct, -1, "sem instinto")
	t.check(info.passives.any(func(p): return p[0] == "Resiste a dano por turno"), "a resistência da máquina")
	t.check(info.states.any(func(s): return s[0].begins_with("Sangra") and s[1] != "" and not s[2]), "o sangramento com o que faz, ruim")
	t.check(info.states.any(func(s): return s[0] == "Marcado"), "a marca")
	t.check(AHCharacterSheet.from_unit(null, robot, true).kind.contains("guardião do trecho"), "o chefe: o guardião do trecho")
	# A ficha desenhada: bom e ruim na cor de agora (o daltonismo troca).
	var host := Control.new()
	_tree.root.add_child(host)
	var sheet := AHCharacterSheet.new()
	host.add_child(sheet)
	var colorblind: bool = Settings.colorblind
	for blind in [false, true]:
		AHUiStyle.set_colorblind(blind)
		sheet.close()
		sheet.show_info(info, Rect2(400, 300, 100, 200))
		var rows: Array = sheet.find_children("*", "Label", true, false).filter(func(l): return l.get_meta("part", "") == "Row")
		var bad: Array = rows.filter(func(l): return l.text.begins_with("Sangra"))
		t.check(not bad.is_empty() and bad[0].get_theme_color("font_color").is_equal_approx(AHUiStyle.DANGER), "o estado ruim na cor de ruim (daltonismo %s)" % blind)
	AHUiStyle.set_colorblind(colorblind)
	t.check(sheet.position.x >= 500, "a ficha ao lado de quem descreve")
	# Muitos estados no texto Maior: a ficha encolhe e cabe acima do painel de baixo.
	var scale: float = AHUiStyle.text_scale
	AHUiStyle.text_scale = 1.5
	var crowded: Dictionary = info.duplicate(true)
	crowded.description = "Guardião industrial da eclusa, formado por portas blindadas, pistões e uma lente central de vigilância. " .repeat(2)
	for i in 8:
		crowded.states.append(["Estado %d" % i, "Uma explicação longa do que o estado faz com quem o carrega na luta.", false])
	sheet.close()
	sheet.show_info(crowded, Rect2(400, 300, 100, 200), 780.0)
	t.check(sheet.position.y >= 16 and sheet.position.y + sheet.size.y <= 781, "com muitos estados e o texto Maior, a ficha cabe acima do painel (%.0f a %.0f)" % [sheet.position.y, sheet.position.y + sheet.size.y])
	AHUiStyle.text_scale = scale
	host.queue_free()


## Numa luta de verdade na rua: o mouse, o alvo do teclado e o toque longo.
func _combat() -> void:
	Campaign.state = Campaign.create_initial(6)
	AHJourneyRules.start_expedition(Campaign.state, "fase_1", 4242)
	GameFlow.change_to("street", {}, false)
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			break
	var street = _tree.current_scene
	street.corridor.debug_next_fight()
	await _frames(10)
	var route: Dictionary = Campaign.state.session.expedition.corridor
	if not t.check(street.corridor.guards.has(route.index), "há patrulha para a luta"):
		return
	street.corridor._start_fight(route.index, true)
	var arena: AHCombatArena = street._arena
	for i in 900:
		if arena.hud != null and arena.hud.waiting:
			break
		await _tree.process_frame
	if not t.check(arena.hud.waiting, "a vez do jogador chega"):
		return
	var hud: AHCombatHud = arena.hud
	var camera := street.get_viewport().get_camera_3d()
	var enemy: AHCombat.Unit = arena.session.state.enemy_team[0]
	var body: Rect2 = hud._body_rect(camera, arena.cards[enemy.id])
	AHUiStyle.using_keys = false
	# #128: o mouse em cima só marca quem é (o nome numa plaqueta acima da cabeça); a ficha não abre na luta.
	await _move(body.get_center())
	t.check(not hud.sheet.showing() and not hud.inspecting(), "o mouse no corpo do inimigo não abre a ficha")
	t.check(hud._hover_label.visible and hud._hover_label.text == AHCombatHud.unit_name(enemy.display_name), "e mostra o nome dele (%s)" % hud._hover_label.text)
	t.check(hud._hover_label.get_global_rect().end.y <= body.position.y + body.size.y * 0.25, "acima do corpo")
	await _move(Vector2(960, 60))
	t.check(not hud._hover_label.visible, "fora dele, o nome some")
	await _move(body.get_center())
	await _touch(body.get_center(), true)
	await _wait(AHCharacterSheet.LONG_PRESS + 0.1)
	t.check(not hud.sheet.showing(), "nem o toque longo")
	await _touch(body.get_center(), false)
	await _emulated_release(body.get_center())
	await _frames(3)
	t.check(hud.waiting, "e a vez continua")
	# O botão INSPECIONAR liga: o painel de baixo, no lugar do herói da vez, com quem age.
	var button: Button = hud._panel.find_child("Inspect", true, false)
	t.check(button != null and button.text == "INSPECIONAR" and button.find_child("Key", true, false) != null, "o botão INSPECIONAR, com a tecla")
	await _move(Vector2(960, 60))
	button.pressed.emit()
	await _frames(3)
	var panel: Control = hud._panel.find_child("InspectPanel", true, false)
	var actor: AHCombat.Unit = arena.session.current_actor()
	t.check(hud.inspecting() and panel.visible, "ligado, o painel abre")
	t.check(panel.get_global_rect().encloses(hud._panel.find_child("HeroPanel", true, false).get_global_rect()), "no lugar do painel do herói da vez")
	t.equal(_inspect_name(panel), AHCombatHud.unit_name(actor.display_name), "com quem age")
	for part in ["Life", "Instinct", "Speed", "Passives", "States"]:
		t.check(panel.find_child(part, true, false) != null, "com %s" % part)
	t.check(not hud.sheet.showing(), "sem a ficha solta")
	# O mouse em cima de outro mostra ele; o clique escolhe.
	await _move(body.get_center())
	t.equal(_inspect_name(panel), AHCombatHud.unit_name(enemy.display_name), "o mouse em cima mostra o inimigo")
	t.check(panel.find_child("Instinct", true, false) == null, "a máquina sem instinto")
	await _click(body.get_center())
	await _move(Vector2(960, 60))
	t.equal(_inspect_name(panel), AHCombatHud.unit_name(enemy.display_name), "o clique escolhe: ele fica sem o mouse")
	t.check(hud.waiting and arena.session.current_actor() == actor, "e não age")
	await _inspect_fits(hud, arena, panel)
	# As setas passam; a tecla fecha; Voltar também.
	AHUiStyle.using_keys = true
	var before := _inspect_name(panel)
	await _press("ui_right")
	await _frames(2)
	t.check(_inspect_name(panel) != before, "a seta passa para o personagem ao lado")
	await _press("combat_examine")
	await _frames(2)
	t.check(not hud.inspecting() and not panel.visible and hud.waiting, "a tecla desliga, e a vez continua")
	var note: String = hud._description.text
	await _press("combat_examine")
	await _frames(2)
	t.check(hud.inspecting(), "a tecla liga")
	await _press("cancel")
	await _frames(2)
	t.check(not hud.inspecting(), "Voltar desliga")
	t.equal(hud._description.text, note, "com a instrução da vez de volta")
	# Na mira, a inspeção não liga (o alvo é o foco).
	var option: Dictionary = {}
	for entry in arena.session.ability_options(arena.session.current_actor().id):
		if entry.usable and not entry.self and entry.enemy_side:
			option = entry
			break
	if t.check(not option.is_empty(), "uma habilidade com alvo inimigo"):
		hud._on_ability(option)
		await _frames(3)
		await _press("combat_examine")
		await _frames(2)
		t.check(not hud.inspecting() and not hud.sheet.showing(), "na mira, nem a inspeção nem a ficha")
		await _press("cancel")
		await _frames(3)
	AHUiStyle.using_keys = false
	hud._clear_markers()


## O painel cabe no espaço dele e não cobre o botão, com três estados em todos, no Normal e no Maior (a QA da #128).
func _inspect_fits(hud: AHCombatHud, arena: AHCombatArena, panel: Control) -> void:
	var saved: Array = []
	for unit in arena.session.units():
		saved.append([unit.bleed.duration, unit.bleed.magnitude, unit.blight.duration, unit.blight.magnitude, unit.mark_duration])
		unit.bleed.duration = 2
		unit.bleed.magnitude = 1
		unit.blight.duration = 2
		unit.blight.magnitude = 1
		unit.mark_duration = 2
	var size := Settings.text_size
	for text_size in [0, 2]:
		Settings.set_text_size(text_size)
		await _frames(4)
		var button: Control = hud._panel.find_child("Inspect", true, false)
		for index in hud._examine.size():
			hud._examine_index = index
			hud._inspect_info = {}
			await _frames(3)
			var rect: Rect2 = panel.get_global_rect()
			t.check(rect.size.x <= AHCombatHud.KIT_INSPECT_PANEL.size.x + 0.5 and rect.size.y <= AHCombatHud.KIT_INSPECT_PANEL.size.y + 0.5
				and not rect.intersects(button.get_global_rect()),
				"texto %d, %s: o painel cabe (%s) e não cobre o botão" % [text_size, hud._examine[index], rect.size])
	Settings.set_text_size(size)
	await _frames(3)
	for i in arena.session.units().size():
		var unit: AHCombat.Unit = arena.session.units()[i]
		unit.bleed.duration = saved[i][0]
		unit.bleed.magnitude = saved[i][1]
		unit.blight.duration = saved[i][2]
		unit.blight.magnitude = saved[i][3]
		unit.mark_duration = saved[i][4]


func _inspect_name(panel: Control) -> String:
	var label := panel.find_child("Name", true, false) as Label
	return label.text if label != null else ""


func _click(point: Vector2) -> void:
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = point
		click.global_position = point
		_tree.root.push_input(click, true)
		await _frames(2)


## Na plataforma (#123): o mouse, o foco e o toque longo na carta.
func _preparation() -> void:
	Campaign.state = Campaign.create_initial(89)
	Campaign.save()
	GameFlow.change_to("station", {}, false)
	for frame in 900:
		await _tree.process_frame
		if not GameFlow.busy and GameFlow.passage == null and _tree.current_scene != null and _tree.current_scene.name == "Station" and frame > 3:
			break
	var hud: AHRefugeHud = _tree.current_scene.hud
	hud.open_departure()
	hud._briefed = hud._draft.phase
	await _frames(5)
	var cards: Array = hud._departure.find_children("*", "Button", true, false).filter(func(b): return String(b.name).begins_with("Slot"))
	if not t.check(cards.size() == 4, "as quatro cartas da plataforma"):
		return
	var card: Button = cards[0]
	var hero_id: String = hud._draft.team[3]
	AHUiStyle.using_keys = false
	card.mouse_entered.emit()
	t.check(hud.sheet.showing(hero_id), "o mouse no cartão abre a ficha do herói")
	t.check(hud.sheet.find_child("Speed", true, false) != null, "com a velocidade (que o cartão não mostra)")
	card.mouse_exited.emit()
	t.check(not hud.sheet.showing(), "sair do cartão fecha")
	AHUiStyle.using_keys = true
	card.grab_focus()
	await _frames(1)
	t.check(hud.sheet.showing(hero_id), "o foco do teclado no cartão abre a ficha")
	AHUiStyle.using_keys = false
	card.release_focus()
	await _frames(1)
	t.check(not hud.sheet.showing(), "o foco que sai fecha")
	# O toque longo pela tela: abre segurando e, ao soltar, não escolhe o cartão.
	var selected: int = hud._departure.selected
	var team: Array = hud._draft.team.duplicate()
	var center: Vector2 = card.get_global_rect().get_center()
	await _touch(center, true)
	await _wait(AHCharacterSheet.LONG_PRESS + 0.1)
	t.check(hud.sheet.showing(hero_id), "o toque longo no cartão abre a ficha")
	await _touch(center, false)
	await _emulated_release(center)
	await _frames(2)
	t.check(not hud.sheet.showing(), "soltar fecha")
	t.equal([hud._departure.selected, hud._draft.team], [selected, team], "e o toque longo não escolhe nem troca a carta")


## O mouse até o ponto (nas coordenadas da tela do jogo); emulated: o mouse que a Godot cria do toque.
func _move(point: Vector2, emulated: bool = false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.device = InputEvent.DEVICE_ID_EMULATION if emulated else 0
	motion.position = point
	motion.global_position = point
	_tree.root.push_input(motion, true)
	await _frames(3)


func _emulated_release(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.device = InputEvent.DEVICE_ID_EMULATION
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = false
	_tree.root.push_input(event, true)
	await _tree.process_frame


func _touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = pressed
	_tree.root.push_input(event, true)
	await _tree.process_frame


func _press(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		_tree.root.push_input(event)
		await _tree.process_frame


func _wait(seconds: float) -> void:
	var limit := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < limit:
		await _tree.process_frame


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
