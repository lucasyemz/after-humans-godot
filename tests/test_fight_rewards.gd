## O fim de luta que recompensa (#91): os critérios e as estrelas, a nota do guardião no save, a carga recuperada (a
## mesma depois de salvar e carregar, uma escolha só, o achado entrando na Estação), a tela do fim da luta com as
## estrelas e o XP, e as caixas no jogo (escolher, revelar, reabrir com a carga fechada).
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")
const J := preload("res://scripts/flow/journey_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-rewards-%d" % Time.get_ticks_usec()
	var tips: bool = Tips.enabled
	Tips.enabled = false
	_stars()
	_cargo()
	await _picker()
	await _reopen_with_cargo()
	await _result_screen()
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


func _stars() -> void:
	var c: Dictionary = Campaign.create_initial(91)
	Campaign.state = c
	var session := AHCombatSession.create([S.hero(c, "hero_cao_bento"), S.hero(c, "hero_gato_nick")], ["robot"], false, 1)
	session.state.victory = true
	session.state.round = 2
	session.last_down_by_hero = true
	var all := AHFightRewards.criteria(session, false)
	t.equal([all.met, all.stars], [4, 3], "os quatro critérios: 3 estrelas")
	session.state.player_team[0].hp = 0
	session.state.round = 9
	var two := AHFightRewards.criteria(session, false)
	t.equal([two.met, two.stars], [2, 1], "alguém caiu e a luta foi longa: só a estrela da vitória")
	session.state.round = 2
	t.equal(AHFightRewards.criteria(session, false).stars, 2, "três critérios (alguém caiu, mas foi rápida): 2 estrelas")
	session.state.round = 9
	t.check(not two.list.filter(func(c): return c.id == "no_falls")[0].met, "o critério de ninguém cair, não cumprido")
	session.last_down_by_hero = false
	session.state.round = 7
	session.state.player_team[1].crisis_outcome = AHCombat.Crisis.COLLAPSE
	var one := AHFightRewards.criteria(session, true)
	t.equal(one.stars, 1, "só um critério: a vitória dá 1 estrela")
	t.check(one.list.filter(func(c): return c.id == "rounds")[0].met, "o guardião tem um par de rodadas maior (7 rodadas cabem)")
	# O par de cada fase (data/fight-stars.json): o guardião da fase 5 aguenta mais rodadas que o da fase 1.
	t.check(AHFightRewards.rounds_par("fase_5", true) > AHFightRewards.rounds_par("fase_1", true), "o par do guardião cresce com a fase")
	t.equal(AHFightRewards.rounds_par("missao_sem_linha", false), AHFightRewards.rounds_par("", false), "fase sem linha usa o par geral")
	session.state.round = AHFightRewards.rounds_par("fase_1", true) + 1
	t.check(not AHFightRewards.criteria(session, true, "fase_1").list.filter(func(c): return c.id == "rounds")[0].met, "passou do par do guardião da fase 1")
	t.check(AHFightRewards.criteria(session, true, "fase_5").list.filter(func(c): return c.id == "rounds")[0].met, "e cabe no da fase 5")
	session.state.round = 7
	session.state.victory = false
	t.equal(AHFightRewards.criteria(session, false).stars, 0, "a derrota não dá estrela")
	# O golpe final: o sangramento na vez do inimigo não é golpe de herói.
	var death := AHCombat.Event.new()
	death.type = AHCombat.EventType.DEATH
	death.target_unit_id = session.state.enemy_team[0].id
	session._watch([death], true)
	t.check(session.last_down_by_hero, "o inimigo derrubado por um herói")
	session._watch([death], false)
	t.check(not session.last_down_by_hero, "o derrubado pelo sangramento, não")
	# A nota do guardião: a melhor fica.
	AHFightRewards.record_stars(c, "fase_1", 2)
	AHFightRewards.record_stars(c, "fase_1", 1)
	t.equal(AHFightRewards.stars_of(c, "fase_1"), 2, "a melhor nota da fase fica no save")


func _cargo() -> void:
	var c: Dictionary = Campaign.create_initial(92)
	Campaign.state = c
	J.start_expedition(c, "fase_1", 9292)
	t.check(not AHFightRewards.cargo_pending(c), "sem o guardião vencido, nada para escolher")
	c.session.expedition.objective_completed = true
	t.check(AHFightRewards.cargo_pending(c), "com o guardião vencido, a carga espera")
	var boxes: Array = AHFightRewards.cargo(c).boxes.duplicate(true)
	t.equal(boxes.size(), 6, "seis caixas")
	t.check(boxes.filter(func(b): return b.kind == "relic").size() <= 1 and boxes.all(func(b): return int(b.amount) > 0), "no máximo uma relíquia, todas com algo dentro")
	t.equal(AHFightRewards._draw(c, c.session.expedition), boxes, "o sorteio é o da semente da expedição")
	Campaign.save()
	var back = Campaign.read_file(Campaign.primary_path())
	t.equal(back.session.expedition.cargo.boxes, boxes, "a mesma carga depois de salvar e carregar")
	# O achado: sementes vão para o achado da rota e chegam na volta.
	c.session.expedition.cargo.boxes[2] = {"kind": "seeds", "amount": 5, "relic_id": ""}
	var loot_before := int(c.session.expedition.loot.seeds)
	t.equal(AHFightRewards.choose(c, 2), "", "escolhe a caixa")
	t.equal(int(c.session.expedition.loot.seeds), loot_before + 5, "as sementes entram no achado da rota")
	t.equal(AHFightRewards.choose(c, 3), "A carga já foi escolhida.", "não dá para escolher duas vezes")
	t.check(not AHFightRewards.cargo_pending(c), "e a carga fica fechada")
	Campaign.save()
	back = Campaign.read_file(Campaign.primary_path())
	t.equal(int(back.session.expedition.cargo.chosen), 2, "a escolha fica no save")
	c.session.result = "victory"
	var seeds := S.quantity(c, "seeds")
	var report := S.finish_return(c)
	t.equal(S.quantity(c, "seeds"), seeds + int(report.seeds), "o achado entra na Estação na volta")
	t.check(int(report.seeds) >= loot_before + 5, "com as sementes da carga")
	# Curativos e relíquia entram na hora.
	var d: Dictionary = Campaign.create_initial(93)
	J.start_expedition(d, "fase_1", 9393)
	d.session.expedition.objective_completed = true
	AHFightRewards.cargo(d)
	d.session.expedition.cargo.boxes[0] = {"kind": "relic", "amount": 1, "relic_id": "pena_vidro"}
	AHFightRewards.choose(d, 0)
	t.check(d.inventory.relics.has("pena_vidro"), "a relíquia vai para o Depósito")
	var e: Dictionary = Campaign.create_initial(94)
	J.start_expedition(e, "fase_1", 9494)
	e.session.expedition.objective_completed = true
	AHFightRewards.cargo(e)
	e.session.expedition.cargo.boxes[0] = {"kind": "bandages", "amount": 2, "relic_id": ""}
	var bandages := int(e.inventory.bandages)
	AHFightRewards.choose(e, 0)
	t.equal(int(e.inventory.bandages), bandages + 2, "os curativos vão para a Mochila")
	# Toda fase tem carga na tabela; uma fase sem linha não trava a equipe (não há o que escolher).
	var missing: Array = J.PHASES.filter(func(info): return not AHFightRewards.has_cargo(String(info.id)))
	t.equal(missing, [], "toda fase tem carga recuperada na tabela")
	var table: Dictionary = GameData.table("recovered_cargo")
	var kept = table.get("fase_1")
	table.erase("fase_1")
	var f: Dictionary = Campaign.create_initial(97)
	J.start_expedition(f, "fase_1", 9797)
	f.session.expedition.objective_completed = true
	t.check(not AHFightRewards.cargo_pending(f), "fase sem carga na tabela: nada para escolher")
	f.session.expedition.cargo = {"boxes": [], "chosen": -1}
	t.check(not AHFightRewards.cargo_pending(f), "e a carga vazia do save também não espera")
	table["fase_1"] = kept
	t.equal(AHFightRewards.icon_of({"kind": "relic", "relic_id": "pena_vidro"}), "relic-glass-feather", "a relíquia com o ícone dela")
	# O save de antes das estrelas abre com nenhuma.
	var old: Dictionary = Campaign.create_initial(95)
	old.erase("mission_stars")
	var envelope := {"format": Campaign.FORMAT, "version": Campaign.VERSION, "checksum": JSON.stringify(Campaign._normalize(old), "", true).sha256_text(), "campaign": old}
	var path := Campaign.save_dir.path_join("old.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope, "\t", true))
	file.close()
	var opened = Campaign.read_file(path)
	t.check(opened is Dictionary and opened.mission_stars == {}, "o save sem estrelas abre com nenhuma")


func _picker() -> void:
	var host := Control.new()
	_tree.root.add_child(host)
	var boxes: Array = []
	for i in 6:
		boxes.append({"kind": "seeds", "amount": i + 1, "relic_id": ""})
	var picker := AHCargoPicker.build(boxes)
	host.add_child(picker)
	await _tree.process_frame
	var picked := [-1]
	picker.chosen.connect(func(i): picked[0] = i)
	picker.buttons[4].pressed.emit()
	picker.buttons[1].pressed.emit()
	t.equal(picked[0], 4, "a escolha é a primeira caixa apertada")
	t.check(picker.buttons.all(func(b): return b.disabled), "depois de escolher, as caixas apagam")
	t.check(picker.buttons[4].text.begins_with("+5 sementes"), "a escolhida mostra o que tinha")
	var limit := Time.get_ticks_msec() + 4000
	while not picker.continue_button.visible and Time.get_ticks_msec() < limit:
		await _tree.process_frame
	t.check(picker.buttons.all(func(b): return b.has_meta("revealed")), "as outras se revelam em seguida")
	t.check(picker.continue_button.visible, "e o Continuar aparece")
	host.queue_free()
	await _tree.process_frame


## Reaberto com o guardião vencido e a carga fechada: as mesmas caixas, e escolher pelo jogo guarda.
func _reopen_with_cargo() -> void:
	var c: Dictionary = Campaign.create_initial(96)
	J.start_expedition(c, "fase_1", 9696)
	c.session.expedition.objective_completed = true
	Campaign.state = c
	# A primeira caixa com suprimentos, para conferir o Achado do HUD depois de escolher.
	c.session.expedition.cargo = {"boxes": AHFightRewards.cargo(c).boxes, "chosen": -1}
	c.session.expedition.cargo.boxes[0] = {"kind": "supplies", "amount": 3, "relic_id": ""}
	var boxes: Array = c.session.expedition.cargo.boxes.duplicate(true)
	Campaign.save()
	GameFlow.change_to("street", {}, false)
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			break
	await _frames(5)
	var street = _tree.current_scene
	var pickers: Array = street.exploration_hud.find_children("CargoPicker", "AHCargoPicker", true, false)
	if not t.check(pickers.size() == 1, "reaberto, a carga fechada abre"):
		return
	var picker: AHCargoPicker = pickers[0]
	t.equal(picker.boxes, boxes, "com as mesmas caixas")
	t.check(street.corridor.blocking(), "e a equipe espera a escolha")
	t.check(street.exploration_hud._goal_text.text.contains("compartimento"), "o objetivo pede a escolha da carga")
	var finish: Button = street.exploration_hud._finish_button
	t.check(not finish.visible, "o Concluir jornada some enquanto a carga espera")
	finish.pressed.emit()
	await _frames(3)
	t.check(Campaign.state.session.expedition != null and AHFightRewards.cargo_pending(Campaign.state) and is_instance_valid(picker) and picker.is_inside_tree(), "e concluir à força não fecha a expedição nem perde a carga")
	picker.buttons[0].pressed.emit()
	await _frames(2)
	finish.pressed.emit()
	await _frames(3)
	t.check(Campaign.state.session.result == "", "durante a revelação, concluir também espera")
	var saved = Campaign.read_file(Campaign.primary_path())
	t.equal(int(saved.session.expedition.cargo.chosen), 0, "a escolha pelo jogo fica no save")
	var limit := Time.get_ticks_msec() + 4000
	while not picker.continue_button.visible and Time.get_ticks_msec() < limit:
		await _tree.process_frame
	picker.continue_button.pressed.emit()
	await _frames(3)
	t.check(not street.corridor.blocking(), "Continuar fecha e a equipe anda")
	t.check(finish.visible, "e o Concluir jornada volta")
	t.check(street.exploration_hud._goal_text.text.contains("volte à Estação"), "e o objetivo volta a pedir a volta")
	t.check(_has_text(street.exploration_hud._loot_row, "3"), "os suprimentos da carga aparecem no Achado")


## Uma luta de verdade até a vitória: a tela do fim mostra as estrelas, os critérios e o XP.
func _result_screen() -> void:
	Campaign.state = Campaign.create_initial(6)
	J.start_expedition(Campaign.state, "fase_1", 4242)
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
	arena.auto_battle = true
	arena.speed = 8.0
	arena.hud.command_chosen.emit({"kind": "defend"})
	var seen := {}
	var limit := Time.get_ticks_msec() + 60000
	while arena.active and Time.get_ticks_msec() < limit:
		await _tree.process_frame
		if arena.hud._result.visible and seen.is_empty():
			var xp = arena.hud._result.find_child("Xp", true, false)
			seen = {"stars": arena.hud._result.find_child("Stars", true, false), "xp": xp.get_meta("xp", {}) if xp != null else {},
				"buttons": arena.hud._result.find_children("*", "BaseButton", true, false).size(), "victory": arena.session.state.victory,
				"text": xp.text if xp != null else "", "team": arena.session.state.player_team.map(func(u): return u.display_name)}
	if t.check(not seen.is_empty(), "o popup do fim da luta abre"):
		if seen.victory:
			t.check(seen.stars != null and seen.stars.get_child_count() == 3 and int(seen.stars.get_meta("stars")) >= 1, "com as três estrelas (as cheias e as vazias)")
		t.check(not seen.victory or seen.xp.size() >= 1, "e o XP de cada herói, numa linha")
		if seen.victory and seen.xp.size() >= 2:
			# Na ordem da cena: da esquerda (o fundo da formação) para a direita (a frente).
			var at: Array = seen.team.filter(func(n): return seen.text.contains(n)).map(func(n): return seen.text.find(n))
			var expected: Array = at.duplicate()
			expected.sort()
			expected.reverse()
			t.equal(at, expected, "o XP vem na ordem da cena, da esquerda para a direita")
		t.equal(seen.buttons, 0, "sem botão: qualquer tecla fecha")
	t.check(not seen.get("victory", false) or not arena.active, "e a vitória fecha sozinha, sem nenhum toque")


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame


func _has_text(node: Node, text: String) -> bool:
	for label in node.find_children("*", "Label", true, false):
		if label.text == text:
			return true
	return false
