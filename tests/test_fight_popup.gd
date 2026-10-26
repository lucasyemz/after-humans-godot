## O popup curto do fim da luta (#109, docs/design/hud-ajustes.md), com as decisões do Lucas:
## - a vitória e a fuga fecham sozinhas (POPUP_HOLD, metade no 2x) ou com qualquer tecla; a derrota espera um toque;
## - sem botão; no alto, no lugar da faixa da rodada (que some enquanto ele está aberto);
## - os recursos da luta são os que end_combat vai somar (combat_loot), e a fuga mostra o achado perdido.
extends RefCounted

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_loot_rule()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-fight-popup-%d" % Time.get_ticks_usec()
	await _popup()
	await _cargo_after_popup()
	Tips.enabled = tips
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


## combat_loot é o que end_combat soma: nada na patrulha; no guardião, os da luta e, na primeira vez, os da fase.
func _loot_rule() -> void:
	var c: Dictionary = Campaign.create_initial(3)
	AHJourneyRules.start_expedition(c, "fase_1", 3)
	t.equal(AHJourneyRules.combat_loot(c, "victory", false), {"seeds": 0, "scrap": 0, "fragments": 0}, "a patrulha não dá recurso")
	var preview := AHJourneyRules.combat_loot(c, "victory", true)
	var loot: Dictionary = c.session.expedition.loot
	var before := [int(loot.seeds), int(loot.scrap), int(loot.fragments)]
	c.session.expedition.corridor.index = c.session.expedition.corridor.steps.size() - 1
	AHJourneyRules.end_combat(c, "victory", true)
	t.equal([int(loot.seeds) - before[0], int(loot.scrap) - before[1], int(loot.fragments) - before[2]], [preview.seeds, preview.scrap, preview.fragments],
		"o popup mostra o mesmo que o guardião soma (%d sementes, %d sucata, %d fragmento)" % [preview.seeds, preview.scrap, preview.fragments])
	t.equal(AHJourneyRules.combat_loot(c, "defeat", true).seeds, 0, "a derrota não dá recurso")
	# O último golpe que vence e também derruba o último da equipe: end_combat conta como derrota, e o popup não promete.
	var fallen: Dictionary = Campaign.create_initial(4)
	AHJourneyRules.start_expedition(fallen, "fase_1", 4)
	for hero in fallen.roster:
		hero.alive = false
	t.equal(AHJourneyRules.combat_loot(fallen, "victory", true), {"seeds": 0, "scrap": 0, "fragments": 0}, "vitória sem ninguém de pé: nenhum recurso")


func _popup() -> void:
	Campaign.state = Campaign.create_initial(6)
	AHJourneyRules.start_expedition(Campaign.state, "fase_1", 4242)
	Campaign.state.session.expedition.loot.seeds = 7
	GameFlow.change_to("street", {}, false)
	var street = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			street = _tree.current_scene
			break
	if not t.check(street != null, "a rua abre"):
		return
	street.corridor.debug_next_fight()
	await _frames(10)
	street.corridor._start_fight(Campaign.state.session.expedition.corridor.index, true)
	var hud: AHCombatHud = street._arena.hud
	for i in 900:
		if hud != null and hud.waiting:
			break
		await _tree.process_frame
	if not t.check(hud.waiting, "a vez do jogador chega"):
		return
	# Vitória: fecha sozinha em ~2,5 s.
	var closed := [false]
	var watch := func(): closed[0] = true
	hud.result_closed.connect(watch)
	var started := Time.get_ticks_msec()
	hud.show_result("victory", false, AHFightRewards.criteria(hud.session, false, "fase_1"))
	await _frames(3)
	t.check(hud._result.visible and not hud._order_panel.visible, "o popup abre e a faixa da rodada sai")
	t.check(hud._result.position.y <= 60.0 and hud._result.get_rect().end.y < 700.0, "no alto, longe da equipe")
	t.equal(hud._result.find_children("*", "BaseButton", true, false).size(), 0, "sem botão")
	t.check(hud._result.find_child("NoLoot", true, false) != null, "na patrulha, \"Nenhum recurso nesta luta\"")
	await _until(func(): return closed[0], 6.0)
	var took := (Time.get_ticks_msec() - started) / 1000.0
	t.check(closed[0] and absf(took - AHCombatHud.POPUP_HOLD) < 0.6, "a vitória fecha sozinha em ~%.1f s (%.2f s)" % [AHCombatHud.POPUP_HOLD, took])
	await _frames(2)
	t.check(not hud._result.visible and hud._order_panel.visible, "e a faixa da rodada volta")
	# Qualquer tecla fecha antes.
	closed[0] = false
	hud.show_result("escaped", false, {})
	await _frames(2)
	t.check(hud._result.find_child("Loot", true, false) != null, "a fuga mostra o achado que se perdeu")
	await _tree.create_timer(0.4).timeout
	var count := [0]
	var tally := func(): count[0] += 1
	hud.result_closed.connect(tally)
	_key(KEY_SPACE)
	_key(KEY_ENTER)
	await _frames(2)
	t.check(closed[0], "qualquer tecla fecha antes")
	t.equal(count[0], 1, "e duas teclas no mesmo quadro fecham uma vez só")
	hud.result_closed.disconnect(tally)
	# Derrota: espera um toque.
	closed[0] = false
	hud.show_result("defeat", false, {})
	await _tree.create_timer(AHCombatHud.POPUP_HOLD + 0.6).timeout
	t.check(hud._result.visible and not closed[0] and hud._result.find_child("Timer", true, false) == null, "a derrota não fecha sozinha (nem tem a linha do tempo)")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(960, 540)
	_tree.root.push_input(touch)
	await _frames(2)
	t.check(closed[0], "e fecha com um toque")
	hud.result_closed.disconnect(watch)


## Uma vitória de verdade contra o guardião: a carga abre só depois que o popup fecha sozinho, e o popup com os quatro de
## Treino pronto não cobre ninguém, no Normal e no Maior.
func _cargo_after_popup() -> void:
	Campaign.state = Campaign.create_initial(6)
	AHJourneyRules.start_expedition(Campaign.state, "fase_1", 4242)
	GameFlow.change_to("street", {}, false)
	var street = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			street = _tree.current_scene
			break
	if not t.check(street != null, "a rua abre para o guardião"):
		return
	street.corridor.debug_next_fight()
	await _frames(10)
	street.corridor._start_fight(Campaign.state.session.expedition.corridor.index, true)
	var arena: AHCombatArena = street._arena
	var hud: AHCombatHud = arena.hud
	for i in 900:
		if hud != null and hud.waiting:
			break
		await _tree.process_frame
	# A luta vira a do guardião (a carga depende dela), e os quatro ficam a um passo do nível.
	arena.boss_fight = true
	street.corridor._fight.boss = true
	# O pior caso: os quatro nomes mais longos dos recrutas (NAME_POOLS), os quatro de Treino pronto, o XP e a carga.
	var long_names: Array = []
	for pool in load("res://scripts/flow/station_rules.gd").NAME_POOLS.values():
		long_names.append_array(pool)
	long_names.sort_custom(func(a, b): return a.length() > b.length())
	for i in hud.session.state.player_team.size():
		var unit = hud.session.state.player_team[i]
		unit.display_name = long_names[i % long_names.size()]
		Campaign.hero(unit.hero_id).display_name = unit.display_name
	for unit in hud.session.state.player_team:
		var hero = Campaign.hero(unit.hero_id)
		hero.xp = int(AHHeroLevels.next_cost(hero).get("xp", 0))
		hud.session.xp_gained[unit.hero_id] = 11
	var locale := TranslationServer.get_locale()
	for case in [[0, "pt"], [2, "pt"], [2, "en"]]:
		var size: int = case[0]
		Settings.set_text_size(size)
		TranslationServer.set_locale(case[1])
		hud.show_result("victory", false, AHFightRewards.criteria(hud.session, true, "fase_1"))
		await _frames(3)
		var popup: Rect2 = hud._result.get_global_rect()
		var camera := _tree.root.get_camera_3d()
		var covered: Array = hud.session.state.player_team.filter(func(u): return AHCampHud.body_rect(camera, arena.cards[u.id]).intersects(popup.grow_individual(0, 0, 0, 8))).map(func(u): return u.hero_id)
		t.equal(covered, [], "o popup com quatro de Treino pronto, nomes longos e a carga não cobre ninguém, com folga (texto %d, %s)" % case)
		t.equal(hud._result.find_children("TrainingReady", "", true, false).size(), 1, "os prontos numa linha só (texto %d, %s)" % case)
		hud.result_closed.emit()
		await _frames(2)
	Settings.set_text_size(0)
	TranslationServer.set_locale(locale)
	for unit in hud.session.state.enemy_team:
		unit.hp = 1
	arena.auto_battle = true
	arena.speed = 8.0
	hud.command_chosen.emit({"kind": "defend"})
	var popup_closed_at := -1
	var cargo_at := -1
	var seen_popup := false
	var limit := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < limit and cargo_at < 0:
		await _tree.process_frame
		if hud._result.visible:
			seen_popup = true
			popup_closed_at = -1
		elif popup_closed_at < 0 and seen_popup:
			popup_closed_at = Time.get_ticks_msec()
		var picker = street.exploration_hud.find_child("CargoPicker", true, false)
		if picker != null and picker.visible:
			cargo_at = Time.get_ticks_msec()
			t.check(not hud._result.visible, "quando a carga abre, o popup já fechou")
	t.check(cargo_at > 0 and popup_closed_at > 0 and cargo_at >= popup_closed_at, "a carga do guardião abre depois do popup")


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	_tree.root.push_input(event)
	var release := event.duplicate()
	release.pressed = false
	_tree.root.push_input(release)


func _until(condition: Callable, seconds: float) -> bool:
	var limit := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < limit:
		if condition.call():
			return true
		await _tree.process_frame
	return condition.call()


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
