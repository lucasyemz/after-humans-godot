## O resgate (#188, com a #183): o pedido de ajuda no dia novo (a chance, o passo, o máximo, só nas fases da lista, o
## sorteio estável); os resgates pendentes (o capturado primeiro); a partida põe o preso num trecho de Suprimentos que
## não é o primeiro, sem mudar a rota; soltar só com a patrulha vencida; as escolhas (entrar, com e sem a equipe cheia,
## quem dá o lugar; ir para a Estação, até na derrota; deixar, com a comida); o Alojamento cheio; o capturado volta como
## era, com a vida e o instinto do resgate; o save no meio.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const J = preload("res://scripts/flow/journey_rules.gd")
const M = preload("res://scripts/flow/side_mission_rules.gd")

var _seed := 900


func run(t) -> void:
	_help_request(t)
	_assign(t)
	_free(t)
	_join(t)
	_join_full(t)
	_station(t)
	_leave(t)
	_full_roster(t)
	_captured(t)
	_save(t)


## Uma campanha na Estação com a fase 2 liberada, a Preparação no nível 2 e a semente das missões fixa.
func _campaign(seed_value: int) -> Dictionary:
	var c: Dictionary = Campaign.create_initial(seed_value)
	c.completed_phases = ["fase_1"]
	c.station.rooms[S.PREPARATION] = 2
	M.state(c).seed = seed_value
	return c


## Um pedido de ajuda na fase 2, já no mapa.
func _with_help(c: Dictionary) -> void:
	var st := M.state(c)
	while AHRescue.help(c).is_empty():
		c.station.cycle_number = int(c.station.cycle_number) + 1
		AHRescue.on_new_day(c)
		if int(c.station.cycle_number) > 200:
			break
	st.help.phase = "fase_2"


## Parte para a fase com a equipe dos fundadores (até o máximo dela) e devolve o resgate da rota.
func _depart(c: Dictionary, phase_id: String = "fase_2") -> Dictionary:
	_seed += 1
	J.start_expedition(c, phase_id, _seed)
	return AHRescue.current(c)


## A equipe chega ao trecho do preso: as patrulhas de antes vencidas.
func _reach(c: Dictionary) -> void:
	var route: Dictionary = c.session.expedition.corridor
	route.index = int(AHRescue.current(c).step)
	for index in route.index:
		route.steps[index].resolved = true


func _help_request(t) -> void:
	var c: Dictionary = Campaign.create_initial(901)
	AHRescue.on_new_day(c)
	t.check(AHRescue.help(c).is_empty(), "só com a fase 2 liberada: na fase 1, nenhum pedido")
	c = _campaign(902)
	var r := AHRescue.rules()
	var days := 0
	var misses_seen := 0
	while AHRescue.help(c).is_empty() and days < 50:
		c.station.cycle_number = int(c.station.cycle_number) + 1
		AHRescue.on_new_day(c)
		days += 1
		misses_seen = maxi(misses_seen, int(M.state(c).get("help_misses", 0)))
	var help := AHRescue.help(c)
	t.check(not help.is_empty(), "um pedido surge em até 50 dias (%d)" % days)
	t.check(Array(r.Phases).has(help.phase) and S.phase_unlocked(c, help.phase), "numa fase da lista, liberada")
	t.check(not String(help.recruit.display_name).is_empty() and not AHCombatArena.hero_art_of("hero_%s_0" % help.recruit.class_id).is_empty(), "um animal de classe com arte, com nome")
	t.equal(int(M.state(c).help_misses), 0, "o pedido zera os dias sem pedido")
	var before: Dictionary = help.duplicate(true)
	c.station.cycle_number = int(c.station.cycle_number) + 1
	AHRescue.on_new_day(c)
	t.equal(AHRescue.help(c), before, "no máximo um pedido no mapa: o dia novo não troca")
	# O sorteio é estável: a mesma semente e o mesmo dia dão o mesmo pedido.
	var a := _campaign(903)
	var b := _campaign(903)
	for day in 30:
		for x in [a, b]:
			x.station.cycle_number = day
			AHRescue.on_new_day(x)
	t.equal(AHRescue.help(a), AHRescue.help(b), "o mesmo dia e a mesma semente, o mesmo pedido")
	# O trem não traz o mesmo nome nem a mesma arte do pedido no mapa (#182: nenhum personagem repetido).
	for seed_value in [904, 905, 906, 907, 908]:
		var d := _campaign(seed_value)
		_with_help(d)
		var recruit: Dictionary = AHRescue.help(d).recruit
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var train: Dictionary = S._train_animal(d, [recruit.class_id], rng, []).recruit
		t.check(train.display_name != recruit.display_name and (train.art_variant == "" or train.art_variant != recruit.art_variant),
			"semente %d: o trem não repete o pedido (%s/%s e %s/%s)" % [seed_value, recruit.display_name, recruit.art_variant, train.display_name, train.art_variant])
	# A chance cresce a cada dia sem pedido, até o máximo.
	var chance := func(misses: int): return mini(int(r.Chance) + int(r.ChanceStep) * misses, int(r.ChanceMax))
	t.equal([chance.call(0), chance.call(1), chance.call(10)], [25, 35, 60], "25%, mais 10 por dia sem pedido, até 60%")


func _assign(t) -> void:
	var c := _campaign(910)
	_with_help(c)
	var rescue := _depart(c)
	var route: Dictionary = c.session.expedition.corridor
	t.equal(route.steps.size(), 10, "a rota continua com 10 trechos")
	t.check(not rescue.is_empty() and rescue.kind == "help", "a expedição à fase do pedido tem o preso")
	t.check(int(rescue.step) > 0 and route.steps[int(rescue.step)].type == "loot", "num trecho de Suprimentos que não é o primeiro")
	t.equal(rescue.state, AHRescue.WAITING, "preso, esperando")
	var other := _campaign(911)
	_with_help(other)
	other.completed_phases = ["fase_1", "fase_2"]
	t.check(_depart(other, "fase_1").is_empty(), "a expedição a outra fase não tem o preso")


func _free(t) -> void:
	var c := _campaign(920)
	_with_help(c)
	_depart(c)
	var route: Dictionary = c.session.expedition.corridor
	var step := int(AHRescue.current(c).step)
	var patrols: Array = range(step).filter(func(index): return String(route.steps[index].type) == "combat")
	t.check(not patrols.is_empty(), "o preso tem uma patrulha antes dele")
	route.index = step
	for index in step:
		route.steps[index].resolved = index != patrols[-1]
	t.check(not AHRescue.can_free(c) and not AHRescue.release(c), "com a patrulha de antes de pé, não dá para soltar")
	_reach(c)
	route.index = step - 1
	t.check(AHRescue.can_free(c), "vencida a patrulha, solta mesmo com a equipe um trecho atrás")
	t.check(AHRescue.release(c), "solta")
	t.equal(AHRescue.current(c).state, AHRescue.FREED, "solto, com a escolha aberta")
	t.check(AHRescue.can_free(c), "a escolha aberta continua ao alcance (o save no meio)")


func _join(t) -> void:
	var c := _campaign(930)
	_with_help(c)
	_depart(c)
	var team: Array = c.session.expedition.team.duplicate()
	# Deixa a equipe com um lugar livre.
	c.session.expedition.team = team.slice(0, mini(team.size(), int(J.team_limits("fase_2").max) - 1))
	_reach(c)
	AHRescue.release(c)
	var roster: int = c.roster.size()
	t.equal(AHRescue.choose(c, "join"), "", "com lugar na equipe, entra sem ninguém sair")
	var rescue := AHRescue.current(c)
	var entry = S.hero(c, String(rescue.hero_id))
	t.check(entry != null and c.roster.size() == roster + 1, "o resgatado entra no elenco")
	t.check(c.session.expedition.team.has(entry.id), "e na equipe")
	t.equal(int(entry.hp), maxi(1, ceili(int(entry.max_hp) * 0.5)), "com metade da vida")
	t.equal(int(entry.instinct), 20, "e 20 de instinto")
	t.check(AHRescue.help(c).is_empty(), "o pedido sai do mapa")
	t.check(AHRescue.on_return(c).contains(entry.display_name), "o relatório da volta conta")


func _join_full(t) -> void:
	var c := _campaign(940)
	_with_help(c)
	_depart(c)
	var expedition: Dictionary = c.session.expedition
	while expedition.team.size() < int(J.team_limits("fase_2").max):
		for entry in c.roster:
			if not expedition.team.has(entry.id):
				expedition.team.append(entry.id)
				break
	_reach(c)
	AHRescue.release(c)
	t.check(AHRescue.team_full(c), "a equipe está cheia")
	t.check(AHRescue.choose(c, "join") != "", "cheia, entrar pede quem dá o lugar")
	var down: String = expedition.team[0]
	expedition.downed = [{"hero_id": down, "map": "street", "x": 0, "y": 0, "z": 0, "house": -1}]
	S.hero(c, down).alive = false
	t.check(not AHRescue.can_leave_team(c).has(down), "o caído no mapa não pode dar o lugar")
	t.check(AHRescue.choose(c, "join", down) != "", "nem pela escolha")
	var out: String = AHRescue.can_leave_team(c)[0]
	var hp_out := int(S.hero(c, out).hp)
	t.equal(AHRescue.choose(c, "join", out), "", "quem dá o lugar sai, o resgatado entra")
	t.check(not expedition.team.has(out) and expedition.team.has(AHRescue.current(c).hero_id), "a troca na equipe")
	t.check(S.hero(c, out) != null and int(S.hero(c, out).hp) == hp_out, "quem saiu continua no elenco, com a vida que tinha")
	# A volta: quem saiu chega à Estação (no elenco, fora da equipe: sem o XP da jornada).
	c.session.result = "victory"
	c.session.screen = "result"
	var xp_out := int(S.hero(c, out).get("xp", 0))
	var report := S.finish_return(c)
	t.equal(int(S.hero(c, out).get("xp", 0)), xp_out, "quem saiu não ganha o XP da jornada")
	t.check(String(report.get("rescue", "")).contains(S.hero(c, out).display_name), "o relatório diz quem deu o lugar")


func _station(t) -> void:
	var c := _campaign(950)
	_with_help(c)
	_depart(c)
	_reach(c)
	AHRescue.release(c)
	var roster: int = c.roster.size()
	var name: String = AHRescue.prisoner_name(c)
	t.equal(AHRescue.choose(c, "station"), "", "seguir para a Estação vale")
	t.equal(c.roster.size(), roster, "ainda não chegou")
	# Até na derrota, chega.
	c.session.result = "defeat"
	c.session.screen = "result"
	for hero_id in c.session.expedition.team:
		S.hero(c, hero_id).alive = false
	var report := S.finish_return(c)
	t.equal(c.roster.size(), roster + 1, "na volta, até na derrota, ele chega à Estação")
	t.check(c.roster.any(func(entry): return entry.display_name == name), "com o nome do pedido")
	t.check(String(report.get("rescue", "")).contains(name), "e a linha no relatório")


func _leave(t) -> void:
	var c := _campaign(960)
	_with_help(c)
	_depart(c)
	_reach(c)
	AHRescue.release(c)
	var food := int(c.session.expedition.food)
	var roster: int = c.roster.size()
	t.equal(AHRescue.choose(c, "leave"), "", "deixar vale no pedido de ajuda")
	t.equal(int(c.session.expedition.food), maxi(0, food - 1), "a equipe deixa 1 de comida")
	t.equal(c.roster.size(), roster, "ninguém entra")
	t.check(AHRescue.help(c).is_empty(), "o pedido não volta")


func _full_roster(t) -> void:
	var c := _campaign(970)
	_with_help(c)
	_depart(c)
	_reach(c)
	AHRescue.release(c)
	# Enche o Alojamento.
	while not S.heroes_full(c):
		S._add_hero(c, S._next_hero_id(c, "cao"), "cao", "Extra", [], "")
	t.check(AHRescue.choice_block(c, "join") != "" and AHRescue.choice_block(c, "station") != "", "com o Alojamento cheio, o pedido não entra nem segue")
	t.equal(AHRescue.choice_block(c, "leave"), "", "só deixar")


func _captured(t) -> void:
	var c := _campaign(980)
	var hero: Dictionary = c.roster[3]
	var level := int(hero.get("level", 1))
	var perks: Array = hero.perks.duplicate()
	hero.captured = {"mission": "cisterna_turva", "spot": 2, "phase": "fase_2", "day": 0}
	_with_help(c)
	var pending := AHRescue.pending(c)
	t.equal(pending[0].kind, "captured", "o capturado vem primeiro (prioridade)")
	var rescue := _depart(c)
	t.check(rescue.kind == "captured" and rescue.hero_id == hero.id, "a rota resgata o capturado primeiro")
	t.check(not c.session.expedition.team.has(hero.id), "o capturado não parte na equipe")
	_reach(c)
	AHRescue.release(c)
	t.check(AHRescue.choice_block(c, "leave") != "", "o capturado não é deixado: é nosso")
	t.equal(AHRescue.choose(c, "station"), "", "segue para a Estação")
	c.session.result = "retreat"
	c.session.screen = "result"
	S.finish_return(c)
	t.check(not hero.has("captured") and not M.away(hero), "na volta, sai do cativeiro")
	t.check(int(hero.get("level", 1)) == level and hero.perks == perks, "como era: o nível e os traços")
	t.equal(int(hero.hp), maxi(1, ceili(int(hero.max_hp) * 0.5)), "com metade da vida")
	t.check(not AHRescue.help(c).is_empty(), "o pedido de ajuda continua no mapa para outra vez")


func _save(t) -> void:
	var c := _campaign(990)
	_with_help(c)
	_depart(c)
	_reach(c)
	AHRescue.release(c)
	var loaded = Campaign._normalize(JSON.parse_string(JSON.stringify(c)))
	S.migrate(loaded)
	t.equal(AHRescue.current(loaded).state, AHRescue.FREED, "o save no meio volta com a escolha aberta")
	t.equal(AHRescue.choose(loaded, "station"), "", "e a escolha segue de onde parou")
	# O save de antes (sem resgate na rota) abre sem resgate.
	var old := _campaign(991)
	J.start_expedition(old, "fase_1", 5)
	old.session.expedition.corridor.erase("rescue")
	t.check(AHRescue.current(old).is_empty() and not AHRescue.can_free(old), "o save de antes abre sem resgate")
	t.equal(AHRescue.on_return(old), "", "e a volta segue como era")
