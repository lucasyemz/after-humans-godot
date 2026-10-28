## AHStationRules: cômodos, economia, civis, noite da volta, refúgio, foco da rota, partida e volta. Como os testes da
## Unreal (AfterHumans.Flow.StationRooms, StationEconomy, StationCivilians, NightRest, Shelter, RouteFocus e StationLoop).
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const J = preload("res://scripts/flow/journey_rules.gd")
const DOOR_STEPS := [1, 2, 3, 5, 6, 8]
const DOOR_SHOPS := [0, 1, 2, 0, 1, 2]


func run(t) -> void:
	# O trem da volta (#122) é sorteado: aqui ele traz sempre o próximo civil da fila (o test_train_recruits sorteia).
	var train_rule: Dictionary = GameData.table("recruitment").get("train", {})
	var train_before := train_rule.duplicate()
	train_rule.Chance = 100
	train_rule.CivilianShare = 100
	_new_campaign(t)
	_rooms(t)
	_departure(t)
	_return_and_night(t)
	_civilians(t)
	_vitals(t)
	_night_preview(t)
	_sleepers(t)
	_thirst(t)
	_route_focus(t)
	_shelter(t)
	_defeat_and_migration(t)
	_loop(t)
	_next_step(t)
	_save_round_trip(t)
	_undeployable(t)
	train_rule.merge(train_before, true)


## O próximo passo da Estação: na ordem do que pede atenção (relatório, noite, trem, cômodo, sucata, fase).
func _next_step(t) -> void:
	var c := _campaign(9)
	var first := S.next_step(c)
	t.equal(first.action, "depart", "campanha nova: partir")
	t.check(first.title.contains("Forja"), "o primeiro passo é trazer sucata para a Forja")
	c.inventory.scrap = 10
	var afford := S.next_step(c)
	t.equal([afford.action, afford.room], ["room", S.FORGE], "com sucata: recuperar a Forja")
	c.station.rooms[S.FORGE] = 2
	c.station.rooms[S.RESEARCH] = 1
	c.station.rooms[S.DEPOT] = 2
	t.check(S.next_step(c).title.begins_with("Partir para"), "tudo recuperado: a próxima fase")
	c.station.train.phase = "waiting"
	c.station.train.candidate_id = S.DORA
	var train := S.next_step(c)
	t.equal(train.action, "train", "o trem vem antes")
	c.night.phase = "planning"
	t.equal(S.next_step(c).action, "dormitory", "a noite vem antes do trem")
	c.station.last_return = {"result": "victory", "seen": false}
	t.equal(S.next_step(c).action, "report", "o relatório vem antes de tudo")
	c.station.last_return.seen = true
	t.equal(S.next_step(c).action, "dormitory", "visto o relatório, a noite")


func _campaign(seed_value: int = 5) -> Dictionary:
	return Campaign.create_initial(seed_value)


## Parte com a formação, volta com o resultado e o saque dados e entrega. Devolve o que chegou.
func _trip(c: Dictionary, result: String, loot: Dictionary = {}, food_left: int = 2, seed_value: int = 101) -> Dictionary:
	var error := S.confirm_departure(c, c.preferred_formation.duplicate(), 0, seed_value, "fase_1")
	if error != "":
		return {"error": error}
	var expedition: Dictionary = c.session.expedition
	for key in loot:
		expedition.loot[key] = loot[key]
	expedition.food = food_left
	c.session.result = result
	c.session.screen = "result"
	return S.finish_return(c)


func _new_campaign(t) -> void:
	var c := _campaign()
	t.equal(c.station.water, S.INITIAL_WATER, "campanha nova começa com 6 de água")
	t.equal(c.station.cycle_number, 0, "nenhum ciclo ainda")
	t.equal([S.room_level(c, S.CANTEEN), S.room_level(c, S.DEPOT), S.room_level(c, S.FORGE), S.room_level(c, S.RESEARCH)], [1, 1, 0, 0],
		"jornada nova: só os cômodos básicos")
	t.equal(c.station.candidate_queue, [S.DORA, S.OTTO, S.CORA], "a fila dos civis")
	t.equal(c.night.phase, "none", "sem noite pendente")
	var f := S.forecast(c, 4)
	t.check(f.power_used == 1 and f.power_capacity == 3 and f.unpowered_rooms.is_empty(), "só a Cantina gasta energia (%d/%d)" % [f.power_used, f.power_capacity])
	t.check(S.in_refuge(c) and S.preparation_block(c) == "", "pode preparar uma partida")


func _rooms(t) -> void:
	var c := _campaign()
	t.equal(S.upgrade_block(c, S.FORGE), "Faltam 4 sucatas.", "Forja sem sucata diz o que falta")
	c.inventory.scrap = 4
	t.equal(S.upgrade_room(c, S.FORGE, 0), "", "recupera a Forja por 4 sucatas")
	t.check(S.room_level(c, S.FORGE) == 1 and c.inventory.scrap == 0, "Forja no nível 1, sucata paga")
	t.check(S.upgrade_room(c, S.FORGE, 0) != "", "clique repetido não compra o nível seguinte")
	t.equal(S.relic_cost(c), 3, "relíquia por 3 sucatas")
	c.inventory.scrap = 6
	c.inventory.fragments = 2
	t.equal(S.upgrade_room(c, S.FORGE, 1), "", "melhora a Forja (6 sucatas e 2 fragmentos)")
	t.check(S.relic_cost(c) == 2 and c.inventory.scrap == 0 and c.inventory.fragments == 0, "relíquia por 2 sucatas")
	t.equal(S.upgrade_block(c, S.FORGE), "Este cômodo já está no nível máximo.", "Forja no máximo")
	t.equal(S.upgrade_block(c, S.DORMITORY), "A recuperação deste cômodo chega numa próxima fase.", "Dormitório chega depois")
	c.inventory.scrap = 3
	c.inventory.fragments = 2
	t.equal(S.upgrade_room(c, S.RESEARCH, 0), "", "recupera a Pesquisa")
	var f := S.forecast(c, 4)
	t.check(f.power_used == 3 and f.power_capacity == 3 and f.unpowered_rooms.is_empty(), "três salas ligadas: energia 3/3")
	t.equal(S.supply_capacity(c), 12, "Depósito guarda 12")
	c.inventory.scrap = 5
	c.inventory.fragments = 1
	t.equal(S.upgrade_room(c, S.DEPOT, 1), "", "Depósito com prateleiras extras")
	t.equal(S.supply_capacity(c), 20, "Depósito melhorado guarda 20")


func _departure(t) -> void:
	var c := _campaign()
	var team: Array = c.preferred_formation.duplicate()
	t.check(S.confirm_departure(c, [], 0, 1, "fase_1") != "", "sem ninguém não parte")
	t.check(S.confirm_departure(c, team + ["hero_cao_bento"], 0, 1, "fase_1") != "", "cinco (um repetido) não partem")
	t.check(S.confirm_departure(c, team, 0, 1, "fase_2") != "", "fase 2 bloqueada antes da 1")
	t.check(S.confirm_departure(c, team, 5, 1, "fase_1") != "", "não passa de 8 suprimentos")
	t.check(S.confirm_departure(c, team, 0, 1, "fase_1", "request_civil_dora") != "", "pedido fechado sem a Dora")
	t.equal(S.confirm_departure(c, team, 2, 77, "fase_1", S.FOCUS_WATER), "", "parte com 2 suprimentos extras e foco em água")
	var expedition: Dictionary = c.session.expedition
	t.check(expedition.food == 6 and c.inventory.seeds == 26 and expedition.focus == S.FOCUS_WATER, "4 de graça + 2 por 4 sementes")
	t.check(c.session.screen == "corridor" and expedition.corridor.steps.size() == 10, "vai direto para o corredor da fase")
	t.check(S.preparation_block(c) != "", "em expedição, não prepara outra")
	t.check(not S.in_refuge(c), "fora do refúgio")


func _return_and_night(t) -> void:
	var c := _campaign()
	var delivered := _trip(c, "victory", {"seeds": 10, "scrap": 2, "fragments": 1}, 2)
	t.check(delivered.get("seeds", -1) == 10 and c.inventory.seeds == 40, "vitória entrega o saque inteiro")
	t.equal(S.quantity(c, S.SUPPLIES), 2 + S.CANTEEN_FOOD, "suprimentos: a comida que sobrou e a Cantina")
	t.equal(c.station.water, S.INITIAL_WATER + S.COLLECTOR_WATER - 4, "água: 6 + coletor 2 - equipe")
	t.check(c.station.cycle_number == 1 and c.station.last_cycle.expedition_id == delivered.get("cycle", {}).get("expedition_id", "?"), "ciclo 1 registrado")
	t.check(c.night.phase == "planning" and not c.night.thirsty, "noite aberta, sem sede")
	t.check(not S.run_cycle(c, c.night.expedition_id, 4), "o ciclo não roda duas vezes")
	t.check(S.finish_return(c).is_empty(), "a entrega não se repete")
	t.check(S.preparation_block(c) != "", "com a noite pendente, não parte")
	t.equal(c.station.train.phase, "waiting", "o trem trouxe um candidato")
	t.equal(c.station.train.candidate_id, S.DORA, "a primeira da fila é a Dora")
	t.equal(c.completed_expeditions, 1, "expedição concluída contada")
	# A noite: Bento de vigia, os outros três dormem e comem.
	for hero in c.roster:
		hero.hp = 10
		hero.instinct = 50
	t.check(S.set_watch(c, "hero_cao_bento"), "Bento fica de vigia")
	t.check(not S.set_watch(c, "hero_inexistente"), "só quem voltou fica de vigia")
	t.check(S.resolve_night(c), "a noite passa")
	var bento = S.hero(c, "hero_cao_bento")
	var nick = S.hero(c, "hero_gato_nick")
	t.check(bento.hp == 10 and bento.instinct == 50, "o vigia não descansa")
	t.equal(nick.hp, 10 + maxi(1, nick.max_hp * 35 / 100), "quem dorme e come recupera 35% da vida")
	t.equal(nick.instinct, 50 - 15 + (0 if c.night.event_id != "distant_noise" else 0), "e 15 de instinto")
	t.equal(S.quantity(c, S.SUPPLIES), 4 - 3, "três suprimentos comidos")
	t.check(c.night.phase == "dawn" and S.night_event_text(c) != "", "amanhecer com o relato da noite")
	t.check(S.finish_dawn(c) and c.night.phase == "none", "a noite termina")
	t.check(S.visit_pending(c) and S.preparation_block(c) == "", "o candidato ainda espera na plataforma, sem travar a partida (#122)")


func _civilians(t) -> void:
	var c := _campaign()
	_trip(c, "victory")
	S.resolve_night(c)
	S.finish_dawn(c)
	var with := S.forecast_with(c, S.DORA, 4)
	var without := S.forecast(c, 4)
	t.equal(with.food_produced - without.food_produced, S.DORA_FOOD, "previsão: a Dora produz mais 2 na Cantina")
	t.check(S.decide_candidate(c, S.OTTO, true) != "", "só decide quem está esperando")
	t.equal(S.decide_candidate(c, S.DORA, true), "", "acolhe a Dora")
	t.check(S.is_resident(c, S.DORA) and c.station.train.phase == "departing", "a Dora mora aqui; o trem parte")
	t.check(S.finish_departure(c) and S.preparation_block(c) == "", "o trem partiu: livre para sair")
	t.check(S.focus_available(c, "request_civil_dora"), "o pedido da Dora abre")
	var f := S.forecast(c, 4)
	t.equal(f.food_produced, S.CANTEEN_FOOD + S.DORA_FOOD, "Cantina com a Dora: 4 suprimentos")
	t.equal(f.water_consumed, 4 + 2, "a Dora bebe 2")
	# Próxima volta: o Otto chega e é recusado; volta para o fim da fila.
	_trip(c, "retreat", {}, 0, 202)
	S.resolve_night(c)
	S.finish_dawn(c)
	t.equal(c.station.train.candidate_id, S.OTTO, "o trem traz o Otto")
	t.equal(S.decide_candidate(c, S.OTTO, false), "", "recusa o Otto")
	t.equal(c.station.candidate_queue, [S.CORA, S.OTTO], "o Otto volta ao fim da fila")
	S.finish_departure(c)
	# O jogo fechou com o trem partindo (o save tem "departing"): ao abrir, a partida termina e a Estação fica livre.
	_trip(c, "retreat", {}, 0, 303)
	S.resolve_night(c)
	S.finish_dawn(c)
	var waiting: String = c.station.train.candidate_id
	t.equal(S.decide_candidate(c, waiting, true), "", "acolhe quem o trem trouxe")
	var reopened = Campaign._normalize(JSON.parse_string(JSON.stringify(c)))
	S.migrate(reopened)
	t.equal(reopened.station.train.phase, "none", "save com o trem partindo: ao abrir, o trem já foi")
	t.check(S.is_resident(reopened, waiting) and S.preparation_block(reopened) == "", "o acolhido mora aqui e a partida fica livre")
	t.equal(reopened.station.train.expedition_id, c.station.train.expedition_id, "a visita continua contada para essa volta")
	# Otto morando: mais 1 de energia e cômodos 1 sucata mais baratos.
	var o := _campaign()
	o.station.residents = [S.OTTO]
	t.equal(S.power_capacity(o), 4, "o Otto mantém o gerador")
	t.equal(S.next_level_cost(o, S.FORGE).scrap, 3, "Forja por 3 sucatas com o Otto")
	o.station.hungry_civilians = [S.OTTO]
	t.equal(S.power_capacity(o), 3, "com fome, o Otto não ajuda")


func _thirst(t) -> void:
	var dry := _campaign()
	dry.station.water = 0
	_trip(dry, "victory", {}, 4)
	t.check(dry.night.thirsty and dry.station.water == 0, "voltou sem água: noite com sede")
	for hero in dry.roster:
		hero.instinct = 50
	S.resolve_night(dry)
	var sleeper = S.hero(dry, "hero_gato_nick")
	t.equal(sleeper.instinct, 50 - 15 + S.THIRST_INSTINCT_PENALTY, "com sede, 10 de instinto a menos recuperados")
	t.check(dry.night.conditions.has("no_water") and S.night_conditions_text(dry)[-1].contains("água"), "o relato explica a sede")


func _route_focus(t) -> void:
	var c := _campaign()
	S.confirm_departure(c, c.preferred_formation.duplicate(), 0, 9, "fase_1", S.FOCUS_WATER)
	var route: Dictionary = c.session.expedition.corridor
	J.assign_search_sites(route, DOOR_STEPS, DOOR_SHOPS, S.FOCUS_WATER)
	var target := -1
	for i in route.sites.size():
		if int(route.sites[i].get("objective_spot", -1)) >= 0:
			target = i
	t.check(target >= 0 and route.sites[target].shop == 0 and not route.sites[target].locked, "o foco garante uma mercearia aberta com objetivo")
	var spot: int = route.sites[target].objective_spot
	t.check(not route.sites[target].spots[spot].choice, "o objetivo é um achado fixo")
	t.check(S.on_search(c, target, spot).contains("Objetivo cumprido"), "vasculhar o objetivo avisa")
	t.equal(c.session.expedition.loot.get("water", 0), 4, "o objetivo rende 4 de água no saque")
	t.equal(S.on_search(c, target, spot), "", "uma vez só")
	var fresh := _campaign()
	t.equal(S.focus_recommended(fresh), S.FOCUS_PROVISIONS, "refúgio sem suprimentos para a noite: recomenda provisões")
	S.adjust(fresh, S.SUPPLIES, 6)
	t.equal(S.focus_recommended(fresh), S.FOCUS_PARTS, "com água e suprimentos, recomenda peças para a Forja")
	var thirsty := _campaign()
	thirsty.station.water = 0
	t.equal(S.focus_recommended(thirsty), S.FOCUS_WATER, "sem água, recomenda água")
	t.check(S.focus_reason(thirsty, S.FOCUS_WATER).contains("vai faltar"), "o motivo explica a falta")
	# Na volta, a carga do objetivo entra antes do ciclo: 4 + o que já havia.
	c.session.result = "victory"
	var water_before: int = c.station.water
	S.finish_return(c)
	t.equal(c.station.water, water_before + 4 + S.COLLECTOR_WATER - 4, "a água do objetivo chega na volta")


func _shelter(t) -> void:
	var c := _campaign()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	t.check(not S.can_recruit_volunteer(c, "cao"), "com quatro fundadores, não há voluntário gratuito")
	c.inventory.seeds = 10
	var recruited := S.recruit(c, "cao", rng)
	t.check(recruited.error == "" and c.inventory.seeds == 0, "recruta por 10 sementes")
	var newcomer = S.hero(c, recruited.hero_id)
	t.check(newcomer != null and newcomer.display_name != "Bento" and newcomer.display_name != "", "com um nome livre (%s)" % newcomer.display_name)
	t.check(S.recruit(c, "cao", rng).error != "", "sem sementes não recruta")
	t.check(S.recruit(c, "tatu", rng).error != "", "classe bloqueada")
	c.pending_offers.append({"class_id": "tatu", "display_name": "Casco"})
	t.equal(S.receive_volunteers(c, rng), 1, "o Casco chega")
	t.check(c.unlocked_classes.has("tatu") and c.roster.any(func(h): return h.display_name == "Casco"), "tatu liberado, Casco no elenco")
	t.check(S.treat_trauma(c, "hero_cao_bento") != "", "sem trauma não trata")
	S.hero(c, "hero_cao_bento").trauma = true
	t.check(S.treat_trauma(c, "hero_cao_bento") != "", "sem sementes não trata")
	c.inventory.seeds = 5
	t.equal(S.treat_trauma(c, "hero_cao_bento"), "", "trata o trauma")
	var project: Dictionary = GameData.table("research").values()[0]
	var research_id: String = GameData.table("research").keys()[0]
	c.inventory.fragments = int(project.CostFragments)
	t.check(S.research(c, research_id) != "", "sem a Pesquisa recuperada não pesquisa")
	c.station.rooms[S.RESEARCH] = 1
	t.equal(S.research(c, research_id), "", "pesquisa")
	t.check(c.researched_skills.has(project.SkillId) and S.research(c, research_id) != "", "melhoria ativa, não repete")
	t.check(S.craft_relic(c, "botao_cobre") != "", "sem a Forja não fabrica")
	c.station.rooms[S.FORGE] = 1
	c.inventory.scrap = 3
	t.equal(S.craft_relic(c, "botao_cobre"), "", "fabrica um Botão de Cobre")
	t.equal(S.equip_relic(c, "hero_cao_bento", "botao_cobre"), "", "equipa")
	t.check(c.inventory.relics.is_empty() and S.hero(c, "hero_cao_bento").relic_id == "botao_cobre", "saiu do estoque")
	t.equal(S.equip_relic(c, "hero_cao_bento", ""), "", "tira")
	t.check(c.inventory.relics == ["botao_cobre"], "voltou ao estoque")
	c.inventory.seeds = 10
	# O Alojamento ampliado (#119): cabem os recrutas do teste.
	c.station.rooms[S.CHARACTERS] = 4
	S.recruit(c, "cao", rng)
	var dogs: Array = c.roster.filter(func(h): return h.class_id == "cao").map(func(h): return h.id)
	t.check(S.validate_team(c, [dogs[0], dogs[1], dogs[2], "hero_gato_nick"]) != "", "três cães não partem juntos")
	t.equal(S.validate_team(c, ["hero_cao_bento", "hero_gato_nick", "hero_sapo_iris", "hero_coruja_vespera"]), "", "a formação inicial parte")
	t.check(not S.set_formation(c, [dogs[0], dogs[0]]), "formação sem repetir")
	t.check(S.set_formation(c, [dogs[1], dogs[0]]), "formação parcial salva")
	t.check(not S.attacks_from_rank("cao", 1).is_empty() and not S.attacks_from_rank("coruja", 4).is_empty(), "cada fundador ataca da posição")


func _defeat_and_migration(t) -> void:
	var lost := _campaign()
	var delivered := _trip(lost, "defeat", {"seeds": 10, "scrap": 3})
	t.check(delivered.get("seeds", -1) == 0 and lost.inventory.seeds == 30, "derrota não entrega saque")
	t.equal(lost.station.cycle_number, 1, "o ciclo roda mesmo na derrota")
	var admin := _campaign()
	S.confirm_departure(admin, admin.preferred_formation.duplicate(), 0, 3, "fase_1")
	S.hero(admin, "hero_cao_bento").hp = 1
	t.check(S.abandon_to_refuge(admin) and S.in_refuge(admin), "admin larga a expedição")
	t.check(admin.station.cycle_number == 0 and S.hero(admin, "hero_cao_bento").hp == S.hero(admin, "hero_cao_bento").max_hp, "sem ciclo e com a equipe curada")
	# Save de antes da Estação: todos os cômodos recuperados, como já eram usados.
	var legacy := _campaign()
	legacy.station = {}
	legacy.erase("night")
	S.migrate(legacy)
	t.check(S.room_level(legacy, S.FORGE) == 1 and S.room_level(legacy, S.RESEARCH) == 1 and legacy.night.phase == "none", "save antigo migra com tudo recuperado")
	var once: Dictionary = legacy.duplicate(true)
	S.migrate(legacy)
	t.equal(legacy, once, "migrar de novo não muda nada")


## Três viagens seguidas (como AfterHumans.Flow.StationLoop): três ciclos e os três civis acolhidos.
func _loop(t) -> void:
	var c := _campaign(9)
	for trip in 3:
		var delivered := _trip(c, "victory", {"seeds": 4}, 2, 1000 + trip)
		t.check(delivered.get("result", "") == "victory", "viagem %d volta" % (trip + 1))
		S.resolve_night(c)
		S.finish_dawn(c)
		if c.station.train.phase == "waiting":
			S.decide_candidate(c, c.station.train.candidate_id, true)
			S.finish_departure(c)
	t.equal(c.station.cycle_number, 3, "três ciclos, um por viagem")
	t.equal(c.station.residents.size(), 3, "três civis chegaram e ficaram")
	t.equal(S.preparation_block(c), "", "livre para partir depois do ciclo")


func _save_round_trip(t) -> void:
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var dir := "user://test-station-%d" % Time.get_ticks_usec()
	Campaign.save_dir = dir
	var c := _campaign()
	_trip(c, "victory", {"seeds": 6})
	Campaign.state = c
	t.check(Campaign.save(), "grava com a noite pendente")
	var saved: Dictionary = c.duplicate(true)
	Campaign.state = {}
	Campaign.load_or_new()
	t.equal(Campaign.state, saved, "a Estação e a noite voltam iguais")
	t.check(not S.run_cycle(Campaign.state, Campaign.state.night.expedition_id, 4), "o save carregado não repete o ciclo")
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state


## A barra do alto (o cabeçalho da Unreal): a previsão normal, o excesso acima do Depósito, a falta na noite e a água.
func _vitals(t) -> void:
	var c: Dictionary = Campaign.create_initial(5)
	var vitals: Array = S.vitals(c, 4)
	t.equal(vitals.map(func(v): return v.id), ["food", "water", "power"], "Comida, Água e Energia, nessa ordem")
	var f := S.forecast(c, 4)
	t.equal(vitals[0].value, "%d / %d suprimentos" % [f.food, f.food_capacity], "comida: estoque e capacidade")
	S.adjust(c, S.SUPPLIES, 20 - S.quantity(c, S.SUPPLIES))
	t.equal(S.vitals(c, 4)[0].note, "! 8 acima de 12", "comida acima do Depósito avisa o excesso")
	S.adjust(c, S.SUPPLIES, -S.quantity(c, S.SUPPLIES))
	var empty: Dictionary = S.vitals(c, 4)[0]
	var short := S.forecast(c, 4)
	var expected: bool = short.food + short.food_produced - short.food_civilians - short.food_spoiled < short.food_night_need
	t.equal(empty.warn, expected, "comida zerada avisa quando a próxima volta não fecha")
	# Os moradores comem antes da noite: com o Otto e 3 suprimentos, a Cantina (2) dá para ele e sobram 3 para 4.
	var fed := Campaign.create_initial(5)
	fed.station.residents = [S.OTTO]
	fed.station.water = 20
	S.adjust(fed, S.SUPPLIES, 3 - S.quantity(fed, S.SUPPLIES))
	var tight := S.forecast(fed, 4)
	t.check(tight.food_civilians > 0 and tight.food + tight.food_produced - tight.food_civilians < 4, "o Otto come da Cantina (%s)" % tight)
	t.check(S.vitals(fed, 4)[0].warn, "a falta na volta conta o que os moradores comem")
	t.equal(S.focus_recommended(fed), S.FOCUS_PROVISIONS, "e o foco recomendado são as provisões")
	c.night.phase = "planning"
	c.night.participants = c.roster.slice(0, 3).map(func(h): return h.id)
	c.night.watch_hero_id = ""
	S.adjust(c, S.SUPPLIES, 1)
	var night: Dictionary = S.vitals(c, 4)[0]
	t.equal(night.note, "! Faltam 2 nesta noite", "na noite, a falta conta quem dorme (%s)" % night.note)
	S.adjust(c, S.SUPPLIES, 2)
	t.equal(S.vitals(c, 4)[0].note, "Abastecida · demanda 3", "na noite abastecida, a demanda")
	c.station.water = 0
	var water: Dictionary = S.vitals(c, 4)[1]
	t.equal(water.warn, S.forecast(c, 4).thirsty, "água avisa quando falta na volta")
	t.check(water.note.begins_with("! Falta") == water.warn, "a linha da água diz a falta (%s)" % water.note)


## A prévia dos cartões do Dormitório é o que a noite faz de verdade: quem come, quanto recupera e o instinto, com um
## vigia, com comida faltando e com sede.
func _night_preview(t) -> void:
	for spec in [[2, "", false], [1, "hero_gato_nick", false], [4, "", true], [0, "hero_cao_bento", false]]:
		var c: Dictionary = Campaign.create_initial(9)
		var team: Array = c.roster.slice(0, 4).map(func(h): return h.id)
		for entry in c.roster:
			entry.hp = maxi(1, int(entry.max_hp) / 3)
			entry.instinct = 60
		c.night.phase = "planning"
		c.night.number = 1
		c.night.participants = team
		c.night.thirsty = spec[2]
		S.adjust(c, S.SUPPLIES, spec[0] - S.quantity(c, S.SUPPLIES))
		if spec[1] != "" and team.has(spec[1]):
			S.set_watch(c, spec[1])
		var preview := S.night_preview(c)
		t.equal(preview.needed, team.size() - (1 if c.night.watch_hero_id != "" else 0), "a noite pede um por quem dorme (%s)" % [spec])
		var before := {}
		for entry in c.roster:
			before[entry.id] = [int(entry.hp), int(entry.instinct)]
		S.resolve_night(c)
		for row in preview.heroes:
			var entry = S.hero(c, row.hero_id)
			var result: Dictionary = c.night.results.filter(func(r): return r.hero_id == row.hero_id)[0]
			t.check(result.watch == row.watch and result.fed == row.fed, "%s: vigia e comida batem (%s)" % [row.hero_id, spec])
			t.equal([int(entry.hp) - before[row.hero_id][0], int(entry.instinct) - before[row.hero_id][1]], [row.hp_gain, row.instinct_change],
				"%s: vida e instinto batem (%s)" % [row.hero_id, spec])


## À noite, quem dorme deita no beliche: todos menos o vigia, um lugar para cada um da equipe e a pose de cada herói;
## com a noite resolvida, ninguém fica deitado.
func _sleepers(t) -> void:
	var c: Dictionary = Campaign.create_initial(4)
	var team: Array = c.roster.slice(0, 4).map(func(h): return h.id)
	c.night.phase = "planning"
	c.night.participants = team
	t.equal(AHStation.sleepers(c), team, "sem vigia, os quatro dormem")
	S.set_watch(c, team[1])
	t.check(not AHStation.sleepers(c).has(team[1]) and AHStation.sleepers(c).size() == 3, "o vigia não deita")
	t.equal(AHStation.sleep_slots().size(), 4, "quatro lugares nos beliches")
	# O beliche é o card inteiro da entrega #1: quem dorme encosta na linha do colchão de baixo e na do de cima, medidas
	# na arte (docs/design/bunk.md), em cm pela escala do card.
	t.check(ResourceLoader.exists("res://art/station/cards/%s.webp" % AHStationBuild.BUNK_CARD), "o card do beliche existe")
	var unit := AHStationBuild.BUNK_SCALE
	var slots := AHStation.sleep_slots()
	var lower_z := (AHStationBuild.BUNK_FLOOR + (AHStationBuild.BUNK_FLOOR_PX - AHStationBuild.BUNK_LOWER_PX) * unit - AHStation.SLEEP_DROP) * 0.01
	var upper_z := (AHStationBuild.BUNK_FLOOR + (AHStationBuild.BUNK_FLOOR_PX - AHStationBuild.BUNK_UPPER_PX) * unit - AHStation.SLEEP_DROP) * 0.01
	t.check(absf(slots[0].y - lower_z) < 0.001 and absf(slots[1].y - lower_z) < 0.001, "embaixo, o corpo encosta no lençol de baixo")
	t.check(absf(slots[2].y - upper_z) < 0.001 and absf(slots[3].y - upper_z) < 0.001, "em cima, no lençol de cima")
	var poses: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/station_poses.json"))
	for hero_id in team:
		var pose: Dictionary = poses.get(hero_id + "_sleep", {})
		t.check(not pose.is_empty() and ResourceLoader.exists(pose.file), "%s tem a pose de dormir" % hero_id)
	c.night.phase = "dawn"
	t.equal(AHStation.sleepers(c), [], "no amanhecer ninguém fica deitado")


## Uma classe sem arte de combate (o rato do evento dos túneis, com a arte tirada do manifesto) não parte: a rua e a luta não teriam como mostrá-la.
func _undeployable(t) -> void:
	# O rato tem arte desde a #187: aqui o recruta desenhado dele sai do manifesto, para ele seguir sem arte de luta.
	S.art_variants("rato")
	var recruit_art: Dictionary = S._recruit_art.duplicate(true)
	S._recruit_art.erase("raccoon_recruit_01")
	var c := _campaign(13)
	c.unlocked_classes.append("rato")
	var risco := S.recruit(c, "rato", RandomNumberGenerator.new(), "Risco")
	t.equal(risco.error, "", "o Risco chega à Estação")
	var entry = S.hero(c, risco.hero_id)
	t.check(not S.can_deploy(entry), "o rato ainda não tem arte de combate")
	t.check(S.can_deploy(S.hero(c, "hero_cao_bento")), "os fundadores têm")
	var cao := S.recruit(c, "cao", RandomNumberGenerator.new(), "Rex")
	t.check(S.can_deploy(S.hero(c, cao.hero_id)), "o recruta cão usa a arte do Bento")
	var team := [risco.hero_id, "hero_gato_nick", "hero_sapo_iris", "hero_coruja_vespera"]
	t.equal(S.confirm_departure(c, team, 0, 4242, "fase_1"), "Risco ainda não tem arte de combate e fica na Estação por enquanto.",
		"a partida com o Risco é recusada, com o motivo")
	t.equal(c.session.expedition, null, "e a expedição não começa")
	S._recruit_art = recruit_art
