## O tutorial da abertura (#144):
## - Pular tutorial deixa a campanha no mesmo estado que jogá-lo até o trem (a recompensa, o elenco, o relatório);
## - "Começar pela abertura" abre o cartão "Você precisa escapar." e o Corredor de Contenção com o Bento, a Íris e a
##   Véspera, com as dicas de primeira vez caladas;
## - a jornada pela cena de verdade: a dica de andar; a primeira luta trava as ações até a escolha da habilidade, com a
##   dica da habilidade e a do alvo; ninguém cai (a vida para em 1); o Nick chega com a conversa; a busca e a Mochila;
##   recuar de uma luta a recomeça; fechar o jogo no meio e voltar retoma do mesmo ponto; o embarque leva à Estação com a
##   recompensa e o debriefing do Bento e do Nick;
## - a fase do tutorial nunca conta como fase concluída da campanha.
extends RefCounted

const TIMEOUT := 30.0

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var real_tips: bool = Tips.enabled
	var real_seen: Dictionary = Tips._seen.duplicate()
	Campaign.save_dir = "user://test-tutorial-%d" % Time.get_ticks_usec()
	_skip_equals_play()
	_floor()
	await _title_opening()
	await _journey()
	_release_all()
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state
	Tips.enabled = real_tips
	Tips._seen = real_seen


## Pular e jogar dão o mesmo estado (fora o relatório já visto e o tempo jogado).
func _skip_equals_play() -> void:
	var skipped := Campaign.create_initial(31)
	var seeds: int = skipped.inventory.seeds
	var bandages: int = skipped.inventory.bandages
	AHTutorial.skip(skipped)
	t.equal(AHTutorial.stage(skipped), "done", "pulando, a abertura e a visita da Estação (#145) ficam para trás")
	var prize := AHTutorial.reward()
	t.equal(int(skipped.inventory.seeds), seeds + int(prize.seeds), "a recompensa: as sementes")
	t.equal(int(skipped.inventory.bandages), bandages + int(prize.bandages), "o curativo")
	t.check(prize.tool != "" and skipped.tools.has(prize.tool), "e a ferramenta")
	t.check(skipped.session.expedition == null and skipped.session.screen == "shelter", "e começa na Estação")
	t.equal(skipped.roster.size(), 4, "com os quatro fundadores")
	# Jogado: a jornada com as lutas (a vida gasta, o XP ganho, a busca feita) e o embarque.
	var played := Campaign.create_initial(31)
	t.check(AHTutorial.begin(played), "a abertura começa")
	t.equal(AHTutorial.stage(played), "journey", "no meio da fuga")
	t.check(AHTutorial.suppresses_tips(played), "com as dicas de primeira vez caladas")
	t.equal(played.session.expedition.team, ["hero_cao_bento", "hero_sapo_iris", "hero_coruja_vespera"], "o Bento, a Íris e a Véspera")
	AHTutorial.join(played)
	# Quem foi ao tutorial volta ferido; o resto do elenco ficou na Estação (o embarque só cura a equipe).
	for hero in played.roster.filter(func(h): return played.session.expedition.team.has(h.id)):
		hero.hp = 3
		hero.xp = 40
		hero.instinct = 70
	played.session.expedition.food = 2
	AHTutorial.complete(played)
	t.check(AHTutorial.suppresses_tips(played), "no fim da fuga, as dicas esperam a visita da Estação (#145)")
	var a: Dictionary = played.duplicate(true)
	var b: Dictionary = skipped.duplicate(true)
	for c in [a, b]:
		c.station.last_return.erase("seen")
		c.erase("tutorial")
	t.equal(JSON.stringify(a, "", true), JSON.stringify(b, "", true), "pular dá o mesmo estado que jogar até o trem")
	t.check(not played.completed_phases.has(AHTutorial.PHASE_ID), "o tutorial não vira fase concluída")
	# Fora da jornada (já na Estação, ou numa campanha com progresso), complete() recusa e não mexe em nada.
	var before := JSON.stringify(played, "", true)
	t.equal(AHTutorial.complete(played), {}, "complete() fora da jornada devolve {}")
	t.equal(JSON.stringify(played, "", true), before, "e deixa a campanha como estava")
	played.tutorial = {"stage": "done"}
	t.equal(AHTutorial.complete(played), {}, "nem com o tutorial já feito")
	played.tutorial = {"stage": "station"}
	var report: Dictionary = played.station.last_return
	t.equal(report.team, ["hero_cao_bento", "hero_sapo_iris", "hero_coruja_vespera", "hero_gato_nick"], "o relatório da chegada traz os quatro")
	var lines := AHBriefing.debriefing(played, report)
	t.equal(lines.map(func(l): return l.speaker.id), ["hero_cao_bento", "hero_gato_nick", "hero_cao_bento", "hero_gato_nick", "hero_cao_bento", "hero_gato_nick"], "o debriefing da chegada é do Bento e do Nick")
	t.equal(lines[0].text, "Obrigado.", "e começa com o Bento agradecendo")
	t.equal(lines[-1].text, "Só por uma noite.", "e termina com \"Só por uma noite.\"")
	# O relatório da chegada: sem guardião, com o curativo e a ferramenta à vista (#144).
	var screen := AHStationReport.new()
	screen.report = report
	var chips: Array = screen._chips(played, "victory").map(func(c): return c.icon)
	t.check(not chips.has("guardian_defeated") and chips.has("res-bandages") and chips.has(AHInventoryPanel.TOOL_ICONS[AHTutorial.reward().tool]), "o relatório da abertura diz a fuga, o curativo e a ferramenta, sem guardião")
	screen.free()
	# Um save de antes do tutorial (sem a marca) já passou dele.
	var old := Campaign.create_initial(32)
	t.equal(AHTutorial.stage(old), "done", "save sem a marca: tutorial já passado")


## A vida do herói para em 1 com min_hero_hp (o tutorial): nem o golpe direto nem o sangramento derrubam.
func _floor() -> void:
	var c := Campaign.create_initial(33)
	var bento = c.roster[0]
	var session := AHCombatSession.create([bento], ["carrasco_industrial"], false, 5)
	session.context.min_hero_hp = 1
	var unit: AHCombat.Unit = session.state.player_team[0]
	var events: Array = []
	unit.hp = 4
	session.engine._apply_damage(unit, 50, true, events, "teste")
	t.check(unit.hp == 1 and not unit.deaths_door, "o golpe que derrubaria deixa o herói com 1")
	session.engine._apply_damage(unit, 50, false, events, "sangramento")
	t.check(unit.hp == 1 and not unit.deaths_door, "o sangramento também para em 1")


## Pelo título: "Começar pela abertura" leva ao cartão da abertura e ao Corredor de Contenção.
func _title_opening() -> void:
	Campaign.state = Campaign.create_initial(34)
	for file in DirAccess.get_files_at(Campaign.save_dir) if DirAccess.dir_exists_absolute(Campaign.save_dir) else []:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	GameFlow.start()
	if not await _until(func(): return _tree.current_scene is AHTitleScreen and not GameFlow.busy, "o título"):
		return
	var title: AHTitleScreen = _tree.current_scene
	title.new_button.pressed.emit()
	await _frames(2)
	var opening := title._modal.find_child("Opening", true, false) as Button if title.modal_open() else null
	if not t.check(opening != null, "a campanha nova pergunta como começar"):
		return
	opening.pressed.emit()
	if not await _until(func(): return GameFlow.passage != null, "o cartão da abertura"):
		return
	t.equal(GameFlow.passage.title, "Você precisa escapar.", "o cartão da abertura (decisão do Lucas)")
	if not await _until(func(): return _street() != null and not GameFlow.busy, "o Corredor de Contenção abrir"):
		return
	t.equal(_street().scenario.map_name, AHTutorial.MAP, "a abertura joga no Corredor de Contenção")
	t.equal(Campaign.state.session.expedition.team, ["hero_cao_bento", "hero_sapo_iris", "hero_coruja_vespera"], "com o Bento, a Íris e a Véspera")
	var saved = Campaign.read_file(Campaign.primary_path())
	t.check(saved != null and AHTutorial.stage(saved) == "journey", "a campanha nova grava o ponto do tutorial")


func _journey() -> void:
	var street = _street()
	if street == null:
		return
	var corridor: AHStreetCorridor = street.corridor
	var guide: AHTutorialGuide = corridor.guide
	if not t.check(guide != null, "o guia do tutorial está na rua"):
		return
	t.equal(guide.hint.step_id, "walk", "a primeira dica: andar")
	t.check(street.exploration_hud._goal_title.text.begins_with("Chegar ao trem"), "o objetivo da abertura: o trem")
	Input.action_press("move_right")
	await _until(func(): return guide.done("walk"), "a dica de andar fechar")
	Input.action_release("move_right")
	# A primeira luta, à mão até a escolha do alvo: as ações travadas, as dicas da habilidade e do alvo.
	corridor.debug_next_fight()
	await _frames(2)
	Input.action_press("move_right")
	await _until(func(): return street._arena.active, "a primeira luta")
	Input.action_release("move_right")
	var arena: AHCombatArena = street._arena
	arena.speed = 20.0
	if not await _until(func(): return arena.hud.waiting, "a vez de um herói"):
		return
	await _frames(2)
	t.equal(guide.hint.step_id, "ability", "na vez do herói, a dica da habilidade")
	var actions: Array = arena.hud._actions.get_children()
	t.check(actions.all(func(b): return b.disabled), "a primeira escolha trava as ações: só as habilidades")
	t.check(guide.hint._shades[0].visible and guide.hint._frame.visible, "com o resto da tela escurecido e o destaque nas habilidades")
	var option: Dictionary = arena.hud._options.filter(func(o): return o.usable and not o.self)[0]
	arena.hud._on_ability(option)
	await _frames(2)
	t.equal(guide.hint.step_id, "target", "escolhida a habilidade, a dica do alvo")
	# Voltar da mira: a dica volta à habilidade e as ações continuam travadas.
	var back := InputEventAction.new()
	back.action = "ui_cancel"
	back.pressed = true
	arena.hud._unhandled_input(back)
	await _frames(2)
	t.equal(guide.hint.step_id, "ability", "desfeita a mira, a dica volta à habilidade")
	t.check(arena.hud._actions.get_children().all(func(b): return b.disabled), "com as ações ainda travadas")
	arena.hud._on_ability(option)
	await _frames(2)
	arena.hud._via_mouse = false
	arena.hud._markers[0].pressed.emit()
	await _frames(2)
	t.check(guide.done("ability") and guide.done("target"), "as duas dicas cumpridas")
	t.equal(arena.hud.tutorial_locks, [], "e as ações voltam")
	if not await _auto_rest(arena):
		return
	_alive_check("primeira")
	# O Nick: a conversa com o retrato e ele entra na equipe.
	corridor.debug_next_fight()
	if await _until(func(): return _dialog(street) != null, "a conversa do Nick"):
		t.equal(_dialog(street).lines.size(), 4, "quatro falas no encontro")
		_dialog(street).skip_button.pressed.emit()
	await _until(func(): return Campaign.state.session.expedition.team.size() == 4 and not corridor.busy, "o Nick entrar")
	t.equal(street.party_ids, ["hero_cao_bento", "hero_sapo_iris", "hero_coruja_vespera", "hero_gato_nick"], "o Nick anda com os três")
	# A segunda patrulha à frente: a dica de chegar sem ser visto.
	t.check(await _until(func(): return guide.hint.step_id == "patrol", "a dica da patrulha", 8.0), "a patrulha da segunda luta abre a dica dela")
	corridor.open_menu()
	await _frames(3)
	t.check(not guide.hint.visible, "com o Menu aberto, a dica sai da frente")
	street.exploration_hud.close_modal()
	await _frames(3)
	t.check(guide.hint.visible, "e volta ao fechar")
	# A segunda luta: recuar recomeça a mesma luta, com a equipe inteira.
	corridor.debug_next_fight()
	await _frames(2)
	Input.action_press("move_right")
	await _until(func(): return street._arena.active, "a segunda luta")
	Input.action_release("move_right")
	arena = street._arena
	arena.speed = 20.0
	# A mesma arena da primeira luta, que terminou no automático: aqui quem escolhe é o teste.
	arena.auto_battle = false
	var step: int = Campaign.state.session.expedition.corridor.index
	if await _until(func():
		if arena.hud.waiting:
			arena.hud.command_chosen.emit({"kind": "flee"})
		return not arena.active, "a fuga", 90.0):
		await _frames(3)
		t.equal(Campaign.state.session.result, "", "recuar não encerra a abertura")
		t.check(not Campaign.state.session.expedition.corridor.steps[step].resolved and corridor.guards.has(step), "a patrulha continua no caminho")
		t.check(Campaign.state.roster.filter(func(h): return Campaign.state.session.expedition.team.has(h.id)).all(func(h): return h.hp == h.max_hp),
			"e a equipe volta inteira")
	corridor.debug_next_fight()
	await _frames(2)
	Input.action_press("move_right")
	await _until(func(): return street._arena.active, "a segunda luta, de novo")
	Input.action_release("move_right")
	arena = street._arena
	arena.speed = 20.0
	await _auto_rest(arena)
	_alive_check("luta 2")
	# A busca e a Mochila.
	var entry: Dictionary = corridor.scenario_props[0]
	street._place_leader(Vector3(entry.x, street.floor_y, street.lane_z))
	if await _until(func(): return guide.hint.step_id == "search", "a dica da busca"):
		corridor._action.call()
		await _frames(2)
		t.equal(guide.hint.step_id, "bag", "vasculhado, a dica da Mochila")
		corridor.open_inventory()
		await _frames(2)
		t.check(guide.done("bag"), "aberta a Mochila, a dica cumprida")
		street.exploration_hud.close_modal()
		await _frames(2)
	# Fechar no meio e voltar: o save retoma do mesmo trecho, com a mesma equipe.
	Campaign.save()
	var index: int = Campaign.state.session.expedition.corridor.index
	var saved = Campaign.read_file(Campaign.primary_path())
	Campaign.state = saved
	_tree.unload_current_scene()
	await _frames(2)
	GameFlow.continue_game()
	if not await _until(func(): return _street() != null and not GameFlow.busy, "a rua reabrir pelo Continuar"):
		return
	street = _street()
	corridor = street.corridor
	guide = corridor.guide
	t.equal(Campaign.state.session.expedition.corridor.index, index, "o save retoma do mesmo trecho")
	t.equal(street.party_ids, ["hero_cao_bento", "hero_sapo_iris", "hero_coruja_vespera", "hero_gato_nick"], "com os quatro")
	t.check(guide != null and guide.done("bag") and guide.hint.step_id != "walk", "e as dicas já vistas não voltam")
	# A terceira luta.
	corridor.debug_next_fight()
	await _frames(2)
	Input.action_press("move_right")
	await _until(func(): return street._arena.active, "a luta 3")
	Input.action_release("move_right")
	arena = street._arena
	arena.speed = 20.0
	await _auto_rest(arena)
	_alive_check("luta 3")
	# O trem e o embarque.
	corridor.debug_next_fight()
	var route: Dictionary = Campaign.state.session.expedition.corridor
	if not await _until(func(): return route.steps[6].resolved and not corridor.busy, "o trem parar"):
		return
	t.equal(guide.hint.step_id, "train", "a dica do embarque")
	street._place_leader(Vector3(float(street.scenario.train.x), street.floor_y, street.lane_z))
	await _frames(3)
	var seeds: int = Campaign.state.inventory.seeds
	corridor._action.call()
	if not await _until(func(): return _tree.current_scene is AHStation and not GameFlow.busy, "o vagão levar à Estação", 60.0):
		return
	t.equal(AHTutorial.stage(Campaign.state), "station", "a abertura terminou na Estação")
	t.equal(int(Campaign.state.inventory.seeds), seeds + int(AHTutorial.reward().seeds), "com a recompensa")
	t.check(Tips.seen("combat") and Tips.seen("search"), "as dicas que a abertura ensinou contam como vistas")
	t.check(Campaign.state.roster.all(func(h): return h.alive and h.hp == h.max_hp), "todos inteiros na chegada")
	# Nova campanha confirmada fora do título (a Estação, a rua): a mesma escolha da abertura.
	GameFlow.travel("title", {}, {"new_campaign": Campaign.slot})
	if await _until(func(): return _tree.current_scene is AHTitleScreen and not GameFlow.busy and _tree.current_scene.modal_open(), "o título com a escolha"):
		t.check(_tree.current_scene._modal.find_child("Opening", true, false) != null, "Nova campanha na Estação pergunta como começar")


## Ninguém caiu na luta (a vida parou em 1).
func _alive_check(which: String) -> void:
	var team: Array = Campaign.state.session.expedition.team
	t.check(Campaign.state.roster.filter(func(h): return team.has(h.id)).all(func(h): return h.alive and h.hp >= 1), "ninguém cai na %s luta" % which)


## O resto da luta no automático; devolve se venceu.
func _auto_rest(arena: AHCombatArena) -> bool:
	arena.auto_battle = true
	var ok: bool = await _until(func():
		if arena.hud.waiting:
			var options: Array = arena.hud._options.filter(func(o): return o.usable and not o.self)
			arena.hud.command_chosen.emit({"kind": "defend"} if options.is_empty() else {"kind": "ability", "ability_id": options[0].id,
				"rank": arena.session.state.enemy_team.filter(func(u): return u.hp > 0).map(func(u): return u.rank).min()})
		return not arena.active, "a luta terminar", 90.0)
	if not ok:
		return false
	await _frames(2)
	t.equal(arena.session.result(), "victory", "a luta do tutorial é vencida")
	return arena.session.result() == "victory"


func _dialog(street) -> AHBriefingDialog:
	var found := street.exploration_hud.find_child("Briefing", true, false) as AHBriefingDialog
	return found if found != null and not found.is_queued_for_deletion() else null


func _street():
	var scene := _tree.current_scene
	return scene if scene != null and scene.get("corridor") != null and scene.corridor != null and not scene.corridor.segments.is_empty() else null


func _until(condition: Callable, what: String, seconds: float = TIMEOUT) -> bool:
	var limit := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > limit:
			t.check(false, "travou esperando %s" % what)
			return false
		await _tree.process_frame
	return true


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame


func _release_all() -> void:
	for action in ["move_left", "move_right", "move_back", "move_front", "run"]:
		Input.action_release(action)
