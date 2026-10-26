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
	t.check(not hud.sheet.showing(), "fechada sem ninguém apontado")
	# O mouse em cima do corpo abre; fora dele, fecha.
	await _move(body.get_center())
	t.check(hud.sheet.showing(enemy.id), "o mouse no corpo do inimigo abre a ficha dele")
	t.check(hud.sheet.find_child("Name", true, false).text == AHCombatHud.unit_name(enemy.display_name), "com o nome dele")
	await _move(Vector2(960, 60))
	t.check(not hud.sheet.showing(), "o mouse fora fecha")
	# O alvo com foco do teclado: a ficha de quem ele é.
	var option: Dictionary = {}
	for entry in arena.session.ability_options(arena.session.current_actor().id):
		if entry.usable and not entry.self and entry.enemy_side:
			option = entry
			break
	if t.check(not option.is_empty(), "uma habilidade com alvo inimigo"):
		AHUiStyle.using_keys = true
		hud._on_ability(option)
		await _frames(3)
		var focused := hud.get_viewport().gui_get_focus_owner()
		t.check(focused != null and focused.has_meta("unit_id") and hud.sheet.showing(focused.get_meta("unit_id")), "o alvo com foco do teclado abre a ficha dele")
		AHUiStyle.using_keys = false
		# Na mira, o toque longo no alvo já escolhido só mostra a ficha: soltar não usa a habilidade.
		var marker_body: Rect2 = hud._body_rect(camera, arena.cards[focused.get_meta("unit_id")])
		await _touch(marker_body.get_center(), true)
		await _touch(marker_body.get_center(), false)
		await _frames(3)
		var actor_before: String = arena.session.current_actor().id
		await _touch(marker_body.get_center(), true)
		await _wait(AHCharacterSheet.LONG_PRESS + 0.1)
		t.check(hud.sheet.showing(focused.get_meta("unit_id")), "na mira, o toque longo abre a ficha do alvo")
		await _touch(marker_body.get_center(), false)
		await _emulated_release(marker_body.get_center())
		await _frames(5)
		t.check(hud.waiting and arena.session.current_actor().id == actor_before and not hud._markers.is_empty(), "e soltar não usa a habilidade")
		AHUiStyle.using_keys = true
		await _press("cancel")
		await _frames(3)
		t.check(not hud.sheet.showing(), "Voltar da mira fecha")
	# Examinar (teclado e controle): a ação abre o foco nos personagens, as setas passam, Voltar fecha.
	AHUiStyle.using_keys = true
	var note: String = hud._description.text
	await _press("combat_examine")
	await _frames(2)
	var first: String = hud.sheet.info.get("id", "")
	t.check(hud.sheet.showing() and first == arena.session.current_actor().id, "Examinar abre a ficha de quem age")
	await _press("ui_right")
	await _frames(2)
	t.check(hud.sheet.showing() and hud.sheet.info.id != first, "a seta passa para o personagem ao lado")
	await _press("ui_left")
	await _press("ui_left")
	await _frames(2)
	t.check(hud.sheet.showing() and hud.sheet.info.id != first, "e para o outro lado")
	await _press("cancel")
	await _frames(2)
	t.check(not hud.sheet.showing() and hud.waiting, "Voltar fecha o Examinar, e a vez continua")
	t.equal(hud._description.text, note, "com a instrução da vez de volta")
	AHUiStyle.using_keys = false
	# O toque curto não abre; o longo abre até soltar.
	await _touch(body.get_center(), true)
	await _frames(2)
	t.check(not hud.sheet.showing(), "o toque curto não abre")
	await _wait(AHCharacterSheet.LONG_PRESS + 0.1)
	t.check(hud.sheet.showing(enemy.id), "o toque longo abre a ficha")
	await _touch(body.get_center(), false)
	await _frames(2)
	t.check(not hud.sheet.showing(), "soltar fecha")
	await _move(body.get_center(), true)
	t.check(not hud.sheet.showing(), "o mouse que a Godot emula do toque não abre a ficha")
	hud._clear_markers()


## Na Preparação: o mouse, o foco e o toque longo no cartão.
func _preparation() -> void:
	Campaign.state = Campaign.create_initial(89)
	Campaign.save()
	GameFlow.change_to("station", {}, false)
	for frame in 900:
		await _tree.process_frame
		if not GameFlow.busy and GameFlow.passage == null and _tree.current_scene != null and _tree.current_scene.name == "Station" and frame > 3:
			break
	var hud: AHRefugeHud = _tree.current_scene.hud
	hud.open_room(S.PREPARATION)
	await _frames(5)
	var cards: Array = hud._prep.find_children("*", "Button", true, false).filter(func(b): return String(b.name).begins_with("Slot"))
	if not t.check(cards.size() == 4, "os quatro cartões da Preparação"):
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
	var selected: int = hud._prep_selected
	var team: Array = hud._draft.team.duplicate()
	var center: Vector2 = card.get_global_rect().get_center()
	await _touch(center, true)
	await _wait(AHCharacterSheet.LONG_PRESS + 0.1)
	t.check(hud.sheet.showing(hero_id), "o toque longo no cartão abre a ficha")
	await _touch(center, false)
	await _emulated_release(center)
	await _frames(2)
	t.check(not hud.sheet.showing(), "soltar fecha")
	t.equal([hud._prep_selected, hud._draft.team], [selected, team], "e o toque longo não escolhe nem troca o cartão")


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
