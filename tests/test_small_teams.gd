## Equipes menores (#6): cada jornada tem o mínimo e o máximo nos dados (data/expedition-teams.json). Com 1, 2, 3 e 4
## na fase 1: a partida, a luta, o acampamento, a derrota, a retirada, a noite, o save e a volta usam a equipe real, sem
## lugar fantasma. Fora do limite, a partida é recusada com o motivo.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const J = preload("res://scripts/flow/journey_rules.gd")
const FOUNDERS := ["hero_cao_bento", "hero_gato_nick", "hero_sapo_iris", "hero_coruja_vespera"]


func run(t) -> void:
	_limits(t)
	for size in [1, 2, 3, 4]:
		_journey(t, size)
	await _preparation(t)
	await _street(t)


func _limits(t) -> void:
	for phase in J.PHASES:
		var limits := J.team_limits(phase.id)
		t.check(limits.min >= 1 and limits.min <= limits.max and limits.max <= 4, "%s: limites válidos (%s)" % [phase.id, limits])
	t.equal(J.team_limits("não-existe"), {"min": 4, "max": 4}, "fase sem linha: quatro")
	t.equal(J.team_limits("fase_5"), {"min": 4, "max": 4}, "o Porteiro pede a equipe inteira")
	var c: Dictionary = Campaign.create_initial(5)
	c.completed_phases = ["fase_1", "fase_2", "fase_3", "fase_4"]
	t.equal(S.confirm_departure(c, FOUNDERS.slice(0, 3), 0, 11, "fase_5"), "Esta jornada pede 4 animais diferentes na equipe.",
		"três não partem para os Túneis do Eco")
	t.equal(S.confirm_departure(c, FOUNDERS.slice(0, 2), 0, 11, "fase_3"), "Esta jornada pede 3 ou 4 animais diferentes na equipe.",
		"dois não partem para a Sala Esquecida")
	t.equal(c.session.expedition, null, "nenhuma das recusadas começa")
	t.equal(S.confirm_departure(c, [FOUNDERS[0], FOUNDERS[0]], 0, 11, "fase_1"), "Esta jornada pede 1 a 4 animais diferentes na equipe.",
		"o mesmo herói duas vezes não conta")


func _journey(t, size: int) -> void:
	var c: Dictionary = Campaign.create_initial(20 + size)
	var team: Array = FOUNDERS.slice(0, size)
	if not t.equal(S.confirm_departure(c, team, 0, 100 + size, "fase_1"), "", "%d: parte para a fase 1" % size):
		return
	var expedition: Dictionary = c.session.expedition
	t.equal(expedition.team, team, "%d: a expedição leva só quem foi escalado" % size)
	# A luta com a equipe real (sem lugar vazio), até o fim.
	var heroes: Array = team.map(func(id): return S.hero(c, id))
	var session := AHCombatSession.create(heroes, ["robot", "robot_fungo"], false, 7)
	t.equal(session.state.player_team.size(), size, "%d: a luta tem %d heróis" % [size, size])
	t.equal(session.state.player_team.map(func(u): return u.rank), range(1, size + 1), "%d: nas posições 1 a %d" % [size, size])
	var beats := 0
	while not session.is_over() and beats < 400:
		if session.is_player_turn():
			session.auto_player_turn()
		else:
			session.enemy_turn()
		beats += 1
	t.check(session.is_over(), "%d: a luta termina" % size)
	session.write_back(c)
	# O acampamento cuida só de quem está na equipe.
	for hero_id in team:
		S.hero(c, hero_id).hp = maxi(1, S.hero(c, hero_id).hp)
		S.hero(c, hero_id).alive = true
	c.session.screen = "corridor"
	c.session.result = ""
	var route: Dictionary = expedition.corridor
	J.assign_search_sites(route, [1, 2, 3, 5, 6, 8], [0, 1, 2, 0, 1, 2])
	var camp: int = route.sites.map(func(s): return s.camp_site).find(true)
	route.index = route.sites[camp].step
	for i in route.index + 1:
		route.steps[i].resolved = true
	route.sites[camp].has_enemy = false
	t.check(J.enter_house(c, camp), "%d: entra na casa do acampamento" % size)
	if t.check(J.start_camp(c), "%d: acampa" % size):
		var hero = S.hero(c, team[0])
		hero.hp = hero.max_hp - 10
		hero.instinct = 50
		var food_before: int = expedition.food
		var hp_before: int = hero.hp
		t.check(J.camp_use_food(c, team[0]), "%d: %s come no acampamento" % [size, hero.display_name])
		t.equal(expedition.food, food_before - 1, "%d: a comida cai 1" % size)
		t.check(hero.hp > hp_before, "%d: e a vida sobe" % size)
		if not team.has("hero_coruja_vespera"):
			t.check(not J.camp_use_food(c, "hero_coruja_vespera"), "%d: quem ficou na Estação não come no acampamento" % size)
		J.leave_camp(c, 3)
		J.leave_house(c)
	# Save e load no meio da expedição.
	var back = Campaign._normalize(JSON.parse_string(JSON.stringify(c)))
	t.equal(back.session.expedition.team, team, "%d: o save guarda a equipe real" % size)
	# A volta: retirada; a noite é só de quem foi; a água conta quem voltou.
	c.session.result = "retreat"
	c.session.screen = "result"
	var delivered := S.finish_return(c)
	t.equal(delivered.get("returning", -1), size, "%d: voltaram %d" % [size, size])
	t.equal(c.night.participants, team, "%d: a noite é de quem foi" % size)
	t.check(S.resolve_night(c), "%d: a noite passa" % size)
	t.equal(c.night.results.size(), size, "%d: um resultado da noite por herói" % size)
	S.finish_dawn(c)
	# A derrota com a equipe pequena: todos caem e voltam Caídos (#118), ninguém fica no memorial.
	var d: Dictionary = Campaign.create_initial(40 + size)
	t.equal(S.confirm_departure(d, team, 0, 200 + size, "fase_1"), "", "%d: parte para a derrota" % size)
	for hero_id in team:
		S.hero(d, hero_id).alive = false
	J.end_combat(d, "defeat", false, "teste")
	t.equal(d.session.result, "defeat", "%d: a derrota fecha a expedição" % size)
	S.finish_return(d)
	t.equal(d.memorial.size(), 0, "%d: ninguém vai para o memorial" % size)
	t.equal(S.fallen(d).map(func(h): return h.id), team, "%d: quem foi volta Caído, e só quem foi" % size)


## Na Preparação: escolher um cartão e "Deixar na Estação" parte com um a menos; a fase que pede mais avisa e trava o
## Partir.
func _preparation(t) -> void:
	var tree: SceneTree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-small-prep-%d" % Time.get_ticks_usec()
	Campaign.state = Campaign.create_initial(78)
	GameFlow.change_to("station", {}, false)
	for frame in 600:
		await tree.process_frame
		if not GameFlow.busy and tree.current_scene is AHStation and tree.current_scene.hud != null:
			break
	var hud: AHRefugeHud = tree.current_scene.hud
	hud.open_departure()
	hud._briefed = hud._draft.phase
	await tree.process_frame
	hud._departure.pick(3)
	await tree.process_frame
	var leave := _button(hud._departure, "Deixar na Estação")
	if t.check(leave != null, "com uma carta escolhida, aparece Deixar na Estação"):
		leave.pressed.emit()
		await tree.process_frame
		t.equal(hud._draft.team, FOUNDERS.slice(0, 3), "a Vespera fica na Estação; partem três")
	Campaign.state.completed_phases = ["fase_1", "fase_2", "fase_3", "fase_4"]
	hud._draft.phase = "fase_5"
	hud.refresh()
	await tree.process_frame
	var go: Button = hud.find_child("StartBlocked", true, false)
	t.check(go != null and go.disabled and go.text.begins_with("INICIAR EXPEDIÇÃO"), "Túneis do Eco com três: Iniciar expedição travado")
	t.check(_label(hud._departure, "pede 4 animais"), "e o motivo na tela")
	# Texto Maior, doze na Estação e um só na equipe: a lista da Estação quebra em linhas e cabe acima dos botões.
	var classes := ["cao", "gato", "sapo", "coruja", "cao", "gato", "sapo", "coruja"]
	# O Alojamento no nível máximo (#119): cabem doze.
	Campaign.state.station.rooms[S.CHARACTERS] = 4
	# Direto no elenco, como num save antigo: com um rosto por classe, o recrutamento para em oito (#182).
	for i in classes.size():
		S._add_hero(Campaign.state, S._next_hero_id(Campaign.state, classes[i]), classes[i], "Voluntário %d" % (i + 1), [], "")
	t.equal(S.living(Campaign.state).size(), 12, "doze na Estação")
	Settings.set_text_size(2)
	hud._draft.phase = "fase_1"
	hud._draft.team = [FOUNDERS[0]]
	hud._departure.selected = 0
	hud.refresh()
	for frame in 4:
		await tree.process_frame
	var lineup: Control = hud._departure.find_child("Lineup", true, false)
	var start: Button = hud._departure.find_child("Start", true, false)
	t.check(lineup != null and lineup.get_global_rect().position.x >= 0.0 and lineup.get_global_rect().end.x <= 1920.0,
		"as cartas e a lista cabem na largura da tela")
	t.check(lineup != null and start != null and lineup.get_global_rect().end.y <= start.get_global_rect().position.y,
		"e terminam acima de Iniciar expedição (%.0f)" % (lineup.get_global_rect().end.y if lineup else 0.0))
	var plus := _button(hud._departure, "+")
	t.check(plus != null and plus.get_global_rect().end.x <= 1920.0, "o + da comida fica na tela")
	Settings.set_text_size(0)
	# A Preparação lembra a equipe pequena da última partida.
	Campaign.state.preferred_formation = [FOUNDERS[1]]
	Campaign.state.completed_phases = []
	hud._draft = {}
	hud._reset_draft()
	t.equal(hud._draft.team, [FOUNDERS[1]], "a Preparação começa com a equipe da última partida (um só)")
	tree.unload_current_scene()
	await tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _button(root: Node, prefix: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if node.is_visible_in_tree() and not node.is_queued_for_deletion() and node.text.begins_with(prefix):
			return node
	return null


func _label(root: Node, part: String) -> bool:
	for node in root.find_children("*", "Label", true, false):
		if not node.is_queued_for_deletion() and node.text.contains(part):
			return true
	return false


## Na rua, com dois: a equipe anda e luta com dois cartões.
func _street(t) -> void:
	var tree: SceneTree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-small-teams-%d" % Time.get_ticks_usec()
	Campaign.state = Campaign.create_initial(77)
	t.equal(S.confirm_departure(Campaign.state, FOUNDERS.slice(0, 2), 0, 4321, "fase_1"), "", "dois partem")
	GameFlow.change_to("street", {}, false)
	for frame in 600:
		await tree.process_frame
		if not GameFlow.busy and tree.current_scene != null and tree.current_scene.get("corridor") != null:
			break
	var street = tree.current_scene
	if t.check(street != null and street.get("corridor") != null, "a rua abriu com dois"):
		t.equal(street.party_ids, FOUNDERS.slice(0, 2), "dois andam na rua")
		street.corridor.debug_next_fight()
		street.corridor._start_fight(Campaign.state.session.expedition.corridor.index, true)
		await tree.process_frame
		t.equal(street._arena.session.state.player_team.size(), 2, "e lutam dois")
		tree.unload_current_scene()
		await tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state
