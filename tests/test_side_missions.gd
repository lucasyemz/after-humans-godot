## As missões solo (#183): a Preparação nível 2 abre a aba; o quadro do dia (quantas, o sorteio estável e a troca no dia
## novo); a chance (a base pelo perigo, a aptidão da classe, o nível, a vida, os traços, o trauma e a crise, nos limites)
## e o selo; mandar (a comida, o posto, os bloqueios e o máximo de 2); quem está fora não parte, não pega posto, não
## passeia na Estação e deixa esperar um dia; a volta (o sucesso, o ferido, a captura, com o relatório) e o save de antes.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const M = preload("res://scripts/flow/side_mission_rules.gd")


func run(t) -> void:
	_unlock(t)
	_hurt_limit(t)
	_board(t)
	_chance(t)
	_send(t)
	_away(t)
	_resolve(t)
	_stable(t)
	_train_return(t)
	_migration(t)
	_screen(t)


## Uma campanha com a Preparação no nível 2 e comida de sobra.
func _campaign(seed_value: int) -> Dictionary:
	var c: Dictionary = Campaign.create_initial(seed_value)
	c.station.rooms[S.PREPARATION] = 2
	S.adjust(c, S.SUPPLIES, 10)
	M.state(c).seed = seed_value
	return c


func _unlock(t) -> void:
	var c: Dictionary = Campaign.create_initial(180)
	t.equal(S.room_level(c, S.PREPARATION), 1, "a Preparação começa no nível 1")
	t.check(not M.unlocked(c), "no nível 1, sem missões solo")
	t.equal(S.room_def(S.PREPARATION).max_level, 2, "a Preparação vai ao nível 2")
	t.equal(S.next_level_cost(c, S.PREPARATION), {"scrap": 4, "fragments": 1}, "o nível 2 custa 4 sucatas e 1 fragmento")
	t.check(M.send_block(c, c.roster[0].id, "fresta_galerias") != "", "sem o nível 2, ninguém sai em missão")
	c.station.rooms[S.PREPARATION] = 2
	t.check(M.unlocked(c), "no nível 2, a aba abre")


func _board(t) -> void:
	var c := _campaign(181)
	var board := M.board(c)
	t.equal(board.size(), 2, "na fase 1, duas missões no quadro")
	t.check(board.all(func(spot): return not M.mission(spot.id).is_empty()), "cada uma é uma missão dos dados")
	t.check(board.all(func(spot): return String(M.mission(spot.id).MinPhase) == "fase_1"), "só as da fase liberada")
	t.check(board[0].spot != board[1].spot, "cada uma num lugar do mapa")
	t.equal(M.board(c), board, "o mesmo dia, o mesmo quadro")
	var copy: Dictionary = JSON.parse_string(JSON.stringify(c))
	copy.station.side_missions.day = -1
	t.equal(M.board(copy).map(func(s): return s.id), board.map(func(s): return s.id), "o sorteio é estável (a semente da campanha e do dia)")
	# A decisão do Lucas (01/11): 2 missões por volta nas fases 1 e 2, 4 a partir da fase 3.
	c.completed_phases = ["fase_1"]
	c.station.cycle_number = int(c.station.cycle_number) + 1
	t.equal(M.board(c).size(), 2, "na fase 2, duas missões")
	c.completed_phases = ["fase_1", "fase_2"]
	c.station.cycle_number = int(c.station.cycle_number) + 1
	t.equal(M.board(c).size(), 4, "a partir da fase 3, quatro missões")
	c.completed_phases = ["fase_1", "fase_2", "fase_3", "fase_4"]
	c.station.cycle_number = int(c.station.cycle_number) + 1
	t.equal(M.board(c).size(), 4, "na fase 5, quatro missões")
	for mission in M.missions():
		t.check(M.mission_level(mission) >= 1, "%s tem o nível da fase" % mission.Name)
		t.check(Array(M.rules().Spots).size() >= 4, "há lugares para o quadro cheio")
		break


func _chance(t) -> void:
	var c := _campaign(182)
	var hero: Dictionary = c.roster[0].duplicate(true)
	hero.perks = []
	hero.class_id = "gato"
	hero.level = 1
	# A Fresta nas Galerias: perigo 1 (base 50), pede passagem estreita (o gato é forte).
	t.equal(M.mission_level(M.mission("fresta_galerias")), 1, "a Fresta é da fase 1")
	hero.hp = hero.max_hp
	t.equal(M.chance(c, hero, "fresta_galerias"), 70, "o gato, forte na estreita: a base do perigo 1 (50) + 20")
	hero.class_id = "tatu"
	var weak := M.chance(c, hero, "fresta_galerias")
	t.equal(weak, 50, "o tatu, sem a aptidão: só a base")
	t.equal(M.chance(c, _with(hero, "level", 4), "fresta_galerias"), weak + 9, "3 níveis acima: +9")
	t.equal(M.chance(c, _with(hero, "level", 10), "fresta_galerias"), weak + 15, "o bônus do nível para em +15")
	t.equal(M.chance(c, _with(hero, "hp", int(hero.max_hp) / 2), "fresta_galerias"), weak - roundi(30.0 * (int(hero.max_hp) - int(hero.max_hp) / 2) / int(hero.max_hp)), "a vida pela metade tira até 15")
	t.equal(M.chance(c, _with(hero, "trauma", true), "fresta_galerias"), weak - 10, "o trauma tira 10")
	t.equal(M.chance(c, _with(hero, "instinct", 120), "fresta_galerias"), weak - 10, "em crise, tira 10")
	t.equal(M.chance(c, _with(hero, "perks", ["brave"]), "fresta_galerias"), weak + 5, "corajoso: +5")
	t.equal(M.chance(c, _with(hero, "perks", ["agile"]), "fresta_galerias"), weak + 5, "ágil vale na estreita")
	t.equal(M.chance(c, _with(hero, "perks", ["loyal"]), "fresta_galerias"), weak, "leal não vale onde não há vigia")
	var low := _with(_with(_with(hero, "level", 1), "trauma", true), "hp", 1)
	low.instinct = 150
	t.equal(M.chance(c, low, "galeria_desabada"), int(M.rules().MinChance), "nunca abaixo de 5")
	var high := _with(_with(hero, "level", 10), "perks", ["brave", "hopeful", "agile"])
	high.class_id = "gato"
	t.check(M.chance(c, high, "fresta_galerias") <= int(M.rules().MaxChance), "nunca acima de 95")
	t.equal(M.hint(80), "good", "65 ou mais: boa escolha")
	t.equal(M.hint(50), "risky", "de 40 a 64: arriscado")
	t.equal(M.hint(20), "very_risky", "abaixo de 40: muito arriscado")


func _with(hero: Dictionary, key: String, value) -> Dictionary:
	var copy := hero.duplicate(true)
	copy[key] = value
	return copy


func _send(t) -> void:
	var c := _campaign(183)
	var board := M.board(c)
	var hero: Dictionary = c.roster[0]
	if not S.job_rooms(c).is_empty():
		S.set_post(c, hero.id, S.job_rooms(c)[0])
	var food := S.quantity(c, S.SUPPLIES)
	var mission_id: String = board[0].id
	t.check(M.send_block(c, hero.id, "nada") != "", "a missão fora do quadro não vale")
	t.equal(M.send(c, hero.id, mission_id), "", "mandar vale")
	t.equal(S.quantity(c, S.SUPPLIES), food - M.food_cost(mission_id), "a missão leva a comida dos dias")
	t.equal(S.post_of(hero), "", "quem sai deixa o posto")
	t.equal(int(hero.side_mission.back), int(c.station.cycle_number) + int(M.mission(mission_id).Days), "volta depois dos dias da missão")
	t.check(not M.board(c).any(func(spot): return spot.id == mission_id), "a missão sai do quadro")
	t.check(M.send_block(c, hero.id, board[1].id) != "", "quem já está em missão não sai de novo")
	t.equal(M.send(c, c.roster[1].id, board[1].id), "", "uma segunda missão vale")
	c.station.cycle_number = int(c.station.cycle_number) + 1
	var third: Array = M.board(c).filter(func(spot): return M.running(c).all(func(h): return h.side_mission.id != spot.id))
	t.check(not third.is_empty() and M.send_block(c, c.roster[2].id, third[0].id).contains("2"), "no máximo 2 em curso")
	var poor := _campaign(184)
	S.consume(poor, S.SUPPLIES, S.quantity(poor, S.SUPPLIES))
	t.check(M.send_block(poor, poor.roster[0].id, M.board(poor)[0].id).contains("suprimentos"), "sem comida, não sai")


func _away(t) -> void:
	var c := _campaign(185)
	var hero: Dictionary = c.roster[0]
	M.send(c, hero.id, M.board(c)[0].id)
	t.check(not S.can_deploy(hero), "quem está em missão não parte")
	t.check(S.deploy_block(hero).contains(hero.display_name), "e a Preparação diz por quê")
	t.check(not S.ready_heroes(c).has(hero), "nem conta entre os prontos")
	if not S.job_rooms(c).is_empty():
		t.check(S.set_post(c, hero.id, S.job_rooms(c)[0]) != "", "nem pega posto")
	# Todos fora ou caídos: esperar um dia vale, para a missão voltar.
	for entry in c.roster:
		if entry != hero:
			entry.alive = true
	c.station.last_return = {}
	c.night = S._night_defaults()
	c.station.train = S._train_defaults()
	for entry in c.roster.slice(1):
		entry.side_mission = {"id": "x", "sent": 0, "back": 99}
	t.equal(S.rest_block(c), "", "com todos em missão e ninguém caído, dá para esperar um dia")
	c.roster.slice(1).map(func(entry): return entry.erase("side_mission"))
	var captured: Dictionary = c.roster[1]
	captured.captured = {"mission": "x", "phase": "fase_1", "day": 0}
	t.check(not S.can_deploy(captured), "quem foi capturado não parte")


func _resolve(t) -> void:
	# A captura ligada com o resgate (#188). Desligada, quem seria capturado volta com ferimentos e de mãos vazias.
	t.check(bool(M.rules().get("CaptureEnabled", false)), "a captura fica ligada nos dados, com o resgate")
	var rules := M.rules()
	rules.CaptureEnabled = false
	var off := _round(t, false)
	rules.CaptureEnabled = true
	t.check(off.has("success") and off.has("hurt") and not off.has("captured"), "desligada: o sucesso e o ferido, nunca a captura: %s" % str(off.keys()))
	t.check(off.has("empty"), "e há quem volte ferido de mãos vazias (a captura evitada)")
	var on := _round(t, true)
	t.check(on.has("success") and on.has("hurt") and on.has("captured"), "ligada: os três resultados aparecem: %s" % str(on.keys()))


## 40 campanhas, cada uma com um herói mandado em missão (alguns já feridos na saída). Devolve os resultados vistos.
func _round(t, capture: bool) -> Dictionary:
	var results := {}
	for seed_value in range(300, 340):
		var c := _campaign(seed_value)
		var hero: Dictionary = c.roster[seed_value % 4]
		# Um em cada três sai com 1 de vida: o ferimento nunca cura.
		if seed_value % 3 == 0:
			hero.hp = 1
		var hp_before := int(hero.hp)
		var mission_id: String = M.board(c)[0].id
		var seeds := int(c.inventory.seeds)
		M.send(c, hero.id, mission_id)
		var back := int(hero.side_mission.back)
		var expected := M.chance(c, hero, mission_id)
		while int(c.station.cycle_number) < back:
			S.run_cycle(c, "rest_%d" % (int(c.station.cycle_number) + 1), 0)
		t.check(not hero.has("side_mission"), "no dia da volta, a missão resolve")
		var report: Dictionary = c.station.last_cycle.missions[0]
		results[report.result] = true
		t.equal(report.hero_id, hero.id, "o relatório é do herói")
		t.check(M.report_line(c, report).contains(hero.display_name), "a linha do relatório diz quem")
		t.equal(M.state(c).reports, [report], "Quem voltou mostra o relatório do dia")
		match String(report.result):
			"success":
				t.check(int(report.xp) > 0, "o sucesso dá XP")
				if report.reward.kind == "seeds":
					t.equal(int(c.inventory.seeds), seeds + int(report.reward.amount), "a recompensa entra no estoque")
			"hurt":
				var hurt_hp := float(M.rules().HurtHp)
				t.equal(int(hero.hp), mini(hp_before, M.hurt_hp(int(hero.max_hp))), "o ferido volta com até %d%% da vida, sem sarar" % roundi(hurt_hp * 100))
				t.check(AHWounded.is_wounded(hero), "e volta ferido (#194): manca e desce no passo de quem manca")
				t.check(report.reward.relic_id == "", "o ferido não traz relíquia")
				if int(report.reward.amount) == 0:
					results["empty"] = true
			"captured":
				t.check(capture, "só há captura com ela ligada")
				t.check(M.away(hero) and not S.can_deploy(hero), "o capturado fica fora até o resgate")
				t.check(M.captured(c).has(hero), "e entra na lista dos capturados")
		t.check(expected >= 5 and expected <= 95, "a chance fica nos limites")
		# Recebido o trem, o dia seguinte, sem ninguém voltando, limpa Quem voltou.
		M.arrive(c)
		S.run_cycle(c, "rest_%d" % (int(c.station.cycle_number) + 1), 0)
		t.equal(M.state(c).reports, [], "no dia seguinte, Quem voltou fica vazio")
	return results


## A volta no trem (decisão do Lucas): quem termina a missão chega depois da missão principal, no trem; até a chegada,
## fica fora; o Próximo passo leva à plataforma; receber traz todos à Estação; o capturado não vem no trem.
func _train_return(t) -> void:
	var c := _campaign(196)
	var hero: Dictionary = c.roster[0]
	M.send(c, hero.id, M.board(c)[0].id)
	var back := int(hero.side_mission.back)
	M.state(c).seed = 196
	# Força a volta (a chance no máximo): o herói volta, e chega no trem.
	var rules := M.rules()
	var saved := int(rules.MaxChance)
	rules.MaxChance = 100
	hero.level = 10
	while int(c.station.cycle_number) < back:
		S.run_cycle(c, "rest_%d" % (int(c.station.cycle_number) + 1), 0)
	rules.MaxChance = saved
	t.check(not hero.has("side_mission") and bool(hero.get("on_train", false)), "quem volta da missão chega no trem")
	t.check(M.train_pending(c) and S.visit_pending(c), "o trem das missões é uma visita pendente")
	t.check(M.away(hero) and not S.can_deploy(hero), "no trem, ainda não está na Estação")
	c.station.last_return = {}
	c.night = S._night_defaults()
	t.equal(S.next_step(c).action, "train", "o Próximo passo leva à plataforma")
	t.check(S.preparation_block(c) != "", "com o trem das missões pendente, a Preparação espera (o relatório chega com ele)")
	# Um dia sem receber: o relatório de quem ainda está no trem continua.
	var report: Dictionary = M.state(c).reports[0]
	S.run_cycle(c, "rest_%d" % (int(c.station.cycle_number) + 1), 0)
	t.check(M.state(c).reports.has(report), "um dia sem receber: o relatório de quem está no trem continua")
	t.equal(M.arrive(c), [hero.id], "receber traz quem estava no trem")
	t.check(not M.away(hero) and not M.train_pending(c), "e ele está na Estação")
	# O capturado não vem no trem.
	var d := _campaign(197)
	var other: Dictionary = d.roster[1]
	other.captured = {"mission": "x", "spot": 0, "phase": "fase_1", "day": 0}
	t.check(not bool(other.get("on_train", false)) and not M.train_pending(d), "o capturado não vem no trem")


## A semente nasce com a campanha: salvar e voltar (sem salvar o quadro) não troca o quadro; os pinos não se cobrem; a
## noite pendente bloqueia mandar.
func _stable(t) -> void:
	var c: Dictionary = Campaign.create_initial(191)
	c.station.rooms[S.PREPARATION] = 2
	t.check(c.station.side_missions.has("seed"), "a campanha nova já tem a semente das missões")
	var saved = Campaign._normalize(JSON.parse_string(JSON.stringify(c)))
	S.migrate(saved)
	var board: Array = M.board(c).map(func(spot): return spot.id)
	t.equal(M.board(saved).map(func(spot): return spot.id), board, "o quadro sorteado depois do save é o mesmo ao recarregar")
	var old: Dictionary = Campaign.create_initial(192)
	old.station.erase("side_missions")
	S.migrate(old)
	t.check(old.station.side_missions.has("seed"), "o save de antes ganha a semente na migração")
	# Os pinos: com alguém fora e alguém capturado, nenhuma missão cai nos lugares deles.
	var d := _campaign(193)
	d.completed_phases = ["fase_1", "fase_2", "fase_3", "fase_4"]
	d.roster[0].side_mission = {"id": "x", "spot": 0, "sent": 0, "back": 999}
	d.roster[1].captured = {"mission": "x", "spot": 5, "phase": "fase_1", "day": 0}
	var hits := 0
	for day in 60:
		d.station.cycle_number = day
		hits += M.board(d).filter(func(spot): return spot.spot == 0 or spot.spot == 5).size()
	t.equal(hits, 0, "em 60 dias, nenhuma missão no lugar de quem está fora ou capturado")
	# A noite pendente bloqueia mandar.
	var e := _campaign(194)
	e.night.phase = "pending"
	t.check(M.send_block(e, e.roster[0].id, M.board(e)[0].id) != "", "com a noite pendente, ninguém sai em missão")


func _migration(t) -> void:
	var c: Dictionary = Campaign.create_initial(190)
	c.station.erase("side_missions")
	var old = Campaign._normalize(JSON.parse_string(JSON.stringify(c)))
	S.migrate(old)
	t.check(typeof(old.station.get("side_missions")) == TYPE_DICTIONARY, "o save de antes ganha o estado das missões")
	t.check(M.running(old).is_empty() and M.captured(old).is_empty(), "sem ninguém fora")


## A aba no Mapa da Rede (sem janela): PgDn / RB troca a aba; com todos fora, Esperar um dia aparece e traz a missão de
## volta; a cadeia do teclado passa dos pinos aos heróis e a MANDAR.
func _screen(t) -> void:
	var saved = Campaign.state
	var c := _campaign(195)
	Campaign.state = c
	var map := AHPhaseMap.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(map)
	map.visible = true
	map.refresh()
	var next := InputEventAction.new()
	next.action = "station_room_next"
	next.pressed = true
	map._unhandled_input(next)
	t.equal(map.tab, "missions", "PgDn / RB abre a aba das missões")
	map._unhandled_input(next)
	t.equal(map.tab, "places", "e volta aos lugares")
	map.show_tab("missions")
	var first: Button = map._labels.find_children("Label", "Button", true, false)[0]
	t.check(first.focus_neighbor_right != NodePath(""), "do pino, → leva ao painel")
	map.pick_mission(M.board(c)[0].id)
	var heroes: Array = map._aside.find_children("Hero_*", "Button", true, false)
	t.equal(heroes.size(), 4, "a missão lista os quatro heróis")
	map.pick_hero(c.roster[0].id)
	var send: Button = map._footer.get_node_or_null("Send")
	t.check(send != null and not send.disabled, "com a missão e o herói, MANDAR acende")
	t.check(map.get_node(heroes[0].focus_neighbor_bottom) != null, "os heróis estão na cadeia do teclado")
	var chain_reaches_send := false
	var node: Control = first
	for step in 20:
		node = map.get_node(node.focus_neighbor_bottom)
		if node == send:
			chain_reaches_send = true
			break
	t.check(chain_reaches_send, "↓ desde o primeiro pino chega a MANDAR")
	map.send_mission()
	t.check(M.running(c).size() == 1, "MANDAR manda")
	# Todos os outros fora (em missão): Esperar um dia aparece na lista e passa o dia.
	for entry in c.roster.slice(1):
		entry.side_mission = {"id": "fresta_galerias", "spot": -1, "sent": 0, "back": 999}
	map.refresh()
	var rest: Button = map._aside.find_child("Rest", true, false)
	t.check(rest != null, "com ninguém para partir, Esperar um dia aparece na aba")
	var cycle := int(c.station.cycle_number)
	if rest != null:
		rest.pressed.emit()
	t.equal(int(c.station.cycle_number), cycle + 1, "e o dia passa")
	map.free()
	Campaign.state = saved


## Quem volta ferido da missão (HurtHp) fica abaixo do limite de ferido (data/wounded.json, #194): manca na chegada, como o
## #288 prometeu. Vale para a vida máxima de qualquer herói do elenco inicial e dos recrutas (o arredondamento para cima).
func _hurt_limit(t) -> void:
	var hurt_hp := float(M.rules().HurtHp)
	var threshold := float(AHWounded.rules().Threshold)
	t.check(hurt_hp < threshold, "HurtHp (%.2f) fica abaixo do limite de ferido (%.2f)" % [hurt_hp, threshold])
	var above: Array = []
	for max_hp in range(12, 61):
		var hero := {"alive": true, "max_hp": max_hp, "hp": M.hurt_hp(max_hp)}
		if not AHWounded.is_wounded(hero):
			above.append(max_hp)
	t.equal(above, [], "com qualquer vida máxima de 12 a 60, quem volta ferido manca")
