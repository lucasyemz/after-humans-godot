## A barra de Admin (#130): o F1 (admin_toggle) abre e fecha por cima da Estação, da rua e da luta; na build do jogador,
## nada abre; o que muda o save pede um segundo aperto; cada ação de regra muda o que deve (recursos, cura, XP, fases,
## cômodos, vencer a luta, o inimigo escolhido); fechar devolve o controle.
extends RefCounted

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-admin-%d" % Time.get_ticks_usec()
	_catalog()
	await _title()
	await _station()
	await _street()
	Admin.close()
	Admin.camera_zoom = {"explore": 1.0, "fight": 1.0, "station": 1.0}
	Admin.battle_speed = 0.0
	Admin.next_enemy = ""
	Tips.enabled = tips
	# A vitória abaixa a música por um instante (Sound.duck): o próximo teste começa com ela de volta.
	await _tree.create_timer(2.5).timeout
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


## As abas da Unreal e as novas, cada ação com aba conhecida, texto e onde vale.
func _catalog() -> void:
	var tabs := {}
	var ids := {}
	for action in AHAdminActions.all():
		tabs[action.tab] = true
		t.check(AHAdminActions.TABS.has(action.tab) and String(action.label) != "", "%s: aba e texto" % action.id)
		t.check(["any", "street", "explore", "station", "fight", "campaign"].has(action.where), "%s: onde vale" % action.id)
		t.check(not ids.has(action.id), "%s: id único" % action.id)
		ids[action.id] = true
	t.equal(tabs.keys().size(), AHAdminActions.TABS.size(), "todas as abas têm ações")
	t.check(InputMap.has_action("admin_toggle") and not InputMap.has_action("debug_toggle"), "a ação admin_toggle (e o F1 antigo saiu)")


## No título: o F1 abre e fecha, e pausa o jogo enquanto aberta.
func _title() -> void:
	GameFlow.change_to("title", {}, false)
	for frame in 300:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name.to_lower().contains("title") and frame > 3:
			break
	await _toggle()
	t.check(Admin.is_open() and _tree.paused, "o F1 abre no título (e o jogo fica pausado)")
	await _toggle()
	t.check(not Admin.is_open() and not _tree.paused, "e fecha, devolvendo o jogo")


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		_tree.root.push_input(event)
		await _tree.process_frame


func _station() -> void:
	var c: Dictionary = Campaign.create_initial(13)
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("station", {}, false)
	var station: AHStation = null
	for frame in 900:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene is AHStation and _tree.current_scene.hud != null and frame > 3:
			station = _tree.current_scene
			break
	if not t.check(station != null, "a Estação abre"):
		return
	# Na build do jogador, nada abre.
	Admin.player_build = true
	await _toggle()
	t.check(not Admin.is_open(), "na build do jogador, o F1 não abre")
	Admin.player_build = false
	# O foco de quem estava antes volta ao fechar.
	AHUiStyle.using_keys = true
	var before := _tree.root.gui_get_focus_owner()
	await _toggle()
	t.check(Admin.is_open(), "o F1 abre a barra na Estação")
	await _frames(2)
	var focus := _tree.root.gui_get_focus_owner()
	t.check(focus != null and Admin.panel.is_ancestor_of(focus), "aberta pelo teclado, o foco vai para a barra")
	# As teclas não vazam para a Estação: as setas, Interagir e Esc ficam na barra.
	var room: String = station.hud._key_room
	var screen: String = station.hud.current
	await _key(KEY_RIGHT)
	await _key(KEY_DOWN)
	await _key(KEY_E)
	t.check(station.hud._key_room == room and station.hud.current == screen, "as setas e o E não mexem na Estação por baixo")
	await _key(KEY_ESCAPE)
	t.check(not Admin.is_open() and station.hud.current == screen, "Esc fecha a barra sem abrir o Menu de baixo")
	await _frames(2)
	t.check(before == null or _tree.root.gui_get_focus_owner() == before, "e o foco volta a quem tinha")
	await _toggle()
	var panel: AHAdminPanel = Admin.panel
	t.check(panel.get_global_rect().size.x > 400 and panel.find_child("Box", true, false).get_global_rect().position.x > 1000, "à direita, por cima de tudo")
	# Recursos: o primeiro aperto arma, o segundo soma.
	panel.show_tab("Recursos")
	var seeds := int(c.inventory.seeds)
	panel.press("add_seeds")
	t.equal(int(c.inventory.seeds), seeds, "o que muda o save avisa antes (o primeiro aperto só arma)")
	t.check(panel._notice.text.contains("altera o save"), "com o aviso")
	panel.press("add_seeds")
	t.equal(int(c.inventory.seeds), seeds + 20, "o segundo aperto soma as sementes")
	t.check(Campaign.read_file(Campaign.primary_path()).inventory.seeds == seeds + 20, "e grava")
	# Heróis: cura e XP.
	var hero: Dictionary = c.roster[0]
	hero.hp = 1
	hero.instinct = 80
	_twice(panel, "heal_team")
	t.check(hero.hp == hero.max_hp and hero.instinct == 0, "curar todos devolve a vida e tira o instinto")
	var xp := AHHeroLevels.xp(hero)
	_twice(panel, "xp_team")
	t.equal(AHHeroLevels.xp(hero), xp + 100, "+100 de XP")
	# Jornada: liberar as fases e recuperar os cômodos.
	_twice(panel, "phase_unlock")
	t.check(AHStationRules.phase_unlocked(c, "fase_5"), "liberar todas as fases abre a fase 5")
	_twice(panel, "rooms_all")
	t.check(AHStationRules.room_level(c, AHStationRules.FORGE) >= 1 and AHStationRules.room_level(c, AHStationRules.RESEARCH) >= 1, "recuperar todos os cômodos")
	_twice(panel, "phase_reset")
	t.check(c.completed_phases.is_empty(), "desfazer as fases concluídas")
	# Heróis: recrutar agora (com o nome).
	var roster: int = c.roster.size()
	var said := ""
	panel.press("recruit_now")
	said = panel.press("recruit_now")
	t.check(c.roster.size() == roster + 1 and said.contains(String(c.roster[-1].display_name)), "recrutar agora chega com o nome (%s)" % said)
	# Ajustes: a câmera da Estação fecha o campo de visão (vale quando a barra fecha e o jogo volta).
	var fov: float = station.camera.fov
	panel.press("zoom_station_in")
	await _toggle()
	await _frames(3)
	t.check(station.camera.fov < fov, "a câmera da Estação aproxima (%.1f → %.1f)" % [fov, station.camera.fov])
	await _toggle()
	panel.press("zoom_reset")
	# O que não vale aqui fica apagado, com o motivo.
	panel.show_tab("Combate")
	var win: Button = panel.find_child("Action_fight_win", true, false)
	t.check(win != null and win.disabled, "vencer a luta, fora da luta, apagado")
	t.equal(panel.press("fight_win"), "", "e não faz nada")
	# Fechar devolve o controle: a barra some e a tela de baixo recebe as teclas.
	await _toggle()
	t.check(not Admin.is_open(), "o F1 fecha")
	t.check(not panel.visible, "e a barra some")


func _street() -> void:
	var c: Dictionary = Campaign.create_initial(14)
	Campaign.state = c
	AHJourneyRules.start_expedition(c, "fase_1", 4242)
	Campaign.save()
	GameFlow.change_to("street", {}, false)
	var street = null
	for frame in 900:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			street = _tree.current_scene
			break
	if not t.check(street != null, "a rua abre"):
		return
	await _toggle()
	t.check(Admin.is_open(), "o F1 abre na rua")
	var panel: AHAdminPanel = Admin.panel
	panel.show_tab("Recursos")
	var food := int(c.session.expedition.food)
	_twice(panel, "add_food")
	t.equal(int(c.session.expedition.food), mini(AHJourneyRules.MAX_FOOD, food + 4), "a comida da jornada")
	# Com a barra aberta, a equipe não anda.
	var leader: Vector3 = street._leader.global_position
	Input.action_press("move_right")
	await _frames(20)
	Input.action_release("move_right")
	t.check(street._leader.global_position.distance_to(leader) < 0.01, "com a barra aberta, a equipe não anda")
	# O inimigo escolhido quando a patrulha não vem (ocupado): nada fica armado.
	street.corridor.busy = true
	_twice(panel, "enemy_porteiro")
	t.check(Admin.next_enemy == "", "a patrulha não veio: o inimigo escolhido não fica armado")
	street.corridor.busy = false
	# O grande (tamanho 2) entra nas posições certas: 1 e 3, sem sobrepor.
	Admin.next_enemy = "porteiro"
	var ranks: Array = Admin.override_enemies([{"enemy_id": "robot", "unit_id": "a", "rank": 1, "display_name": "Robô"},
		{"enemy_id": "robot", "unit_id": "b", "rank": 2, "display_name": "Robô"}, {"enemy_id": "robot", "unit_id": "c", "rank": 3, "display_name": "Robô"}]).map(func(u): return u.rank)
	t.equal(ranks, [1, 3], "o inimigo grande ocupa duas posições, sem sobrepor")
	# As teclas de teste antigas da rua saíram (#129): o que elas faziam está na barra, e R não liga mais a chuva.
	Admin.close()
	var rain: bool = street._raining
	await _key(KEY_R)
	t.check(street._raining == rain, "R não liga a chuva")
	if street.exploration_hud.formation_open():
		street.exploration_hud.close_formation()
	var old: Array = InputMap.get_actions().filter(func(a): return String(a).begins_with("debug_"))
	t.equal(old, [], "nenhuma ação debug_* antiga sobra")
	t.check(not "dev_mode" in Settings, "nem o modo de desenvolvedor antigo")
	await _toggle()
	panel = Admin.panel
	# A luta contra o inimigo escolhido: a próxima patrulha vem toda com ele.
	_twice(panel, "enemy_cao_eco")
	await _toggle()
	t.check(not Admin.is_open(), "o F1 fecha, e a equipe segue para a patrulha")
	var arena: AHCombatArena = street._arena
	var hud: AHCombatHud = arena.hud
	# A equipe anda até a patrulha no tempo do jogo: espera pelo relógio, não por quadros (sem janela, os quadros correm
	# mais rápido que a caminhada, e 900 quadros às vezes acabavam antes de ela chegar).
	var limit := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < limit:
		if arena.active and hud.waiting:
			break
		if not arena.active and street.exploration_hud.modal_open():
			street.exploration_hud.close_modal()
		await _tree.process_frame
	if not t.check(arena.active and hud.waiting, "a luta da próxima patrulha começa"):
		return
	t.check(arena.session.state.enemy_team.all(func(u): return u.enemy_id == "cao_eco"), "toda com o inimigo escolhido")
	await _toggle()
	t.check(Admin.is_open(), "o F1 abre por cima da luta")
	panel.show_tab("Combate")
	var patrol: Button = panel.find_child("Action_next_patrol", true, false)
	t.check(patrol != null and patrol.disabled, "na luta, a próxima patrulha fica apagada")
	var actor: AHCombat.Unit = arena.session.current_actor()
	# A pausa segura a luta: com a barra aberta no turno do inimigo, ninguém age por trás (#130, a QA).
	await _toggle()
	hud.command_chosen.emit({"kind": "defend"})
	await _frames(2)
	await _toggle()
	var state: AHCombat.State = arena.session.state
	var before := [state.current_turn_unit_id, state.combat_log.size(), state.player_team.map(func(u): return u.hp)]
	await _tree.create_timer(2.5, true).timeout
	t.equal([state.current_turn_unit_id, state.combat_log.size(), state.player_team.map(func(u): return u.hp)], before, "com a barra aberta, a luta não anda")
	await _toggle()
	await _until(func(): return hud.waiting, 20.0)
	t.check(hud.waiting, "fechada, a luta segue até a vez de um herói")
	await _toggle()
	actor = arena.session.current_actor()
	# As teclas não vão para a luta por baixo: Enter não escolhe a habilidade.
	await _key(KEY_ENTER)
	await _key(KEY_1)
	t.equal(hud._choosing, "", "com a barra aberta, as teclas não agem na luta")
	var instinct := actor.instinct
	panel.press("instinct_50")
	t.equal(actor.instinct, mini(200, instinct + 50), "+50 de Instinto em quem age")
	panel.press("breakthrough")
	t.equal(actor.crisis_outcome, AHCombat.Crisis.BREAKTHROUGH, "forçar a Superação")
	panel.press("collapse")
	t.equal(actor.crisis_outcome, AHCombat.Crisis.COLLAPSE, "forçar o Colapso")
	var results: Array = []
	arena.finished.connect(func(result): results.append(result))
	_twice(panel, "fight_win")
	# A luta termina quando a barra fecha (aberta, o jogo fica pausado).
	Admin.close()
	await _until(func(): return not results.is_empty() or hud._result.visible, 10.0)
	t.check(arena.session.result() == "victory", "vencer a luta (%s)" % arena.session.result())
	if hud._result.visible:
		hud._result.visible = false
		hud.result_closed.emit()
	await _until(func(): return not results.is_empty(), 10.0)
	t.equal(results, ["victory"], "e a luta acaba em vitória")
	await _toggle()
	t.check(Admin.is_open(), "o F1 abre de novo na rua")
	await _toggle()
	t.check(not Admin.is_open(), "o F1 fecha na rua")


func _twice(panel: AHAdminPanel, id: String) -> void:
	panel.press(id)
	panel.press(id)


func _toggle() -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = "admin_toggle"
		event.pressed = pressed
		_tree.root.push_input(event)
		await _tree.process_frame


func _until(condition: Callable, seconds: float) -> void:
	var limit := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < limit:
		await _tree.process_frame


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
