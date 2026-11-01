## As habilidades de acampamento (#261, aprovado em 01/11): 7 por papel (2 comuns e 5 do papel), 3 na chegada, uma a
## aprender em cada nível par (2, 4, 6 e 8) na Sala, 4 levadas; no acampamento, o Tempo de fogueira (12), uma vez por
## herói por acampamento, os alvos (a si, um aliado, a equipe; "só Ferido"), o teto de 3 fichas, os bônus só na
## próxima luta e a Noite mal dormida (1 em 3, Exposto; quem vigia evita), sempre a mesma para a mesma semente.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const J = preload("res://scripts/flow/journey_rules.gd")
const C = preload("res://scripts/flow/camp_skills.gd")
const CLASSES := ["cao", "gato", "sapo", "coruja", "rato", "tatu"]
const EFFECTS := ["instinct", "heal_pct", "hope", "food", "bandage", "ampoule", "block", "dodge", "speed", "self_block",
	"mark_front", "opening", "watch", "phase", "clear", "wounded"]

var t


func run(context) -> void:
	t = context
	_data()
	_learning()
	_choose()
	_camp_use()
	_targets()
	_next_fight()
	_opening()
	_night()
	_save()


func _hero(c: Dictionary, class_id: String) -> Dictionary:
	for hero in c.roster:
		if hero.class_id == class_id:
			return hero
	var hero := Campaign.new_hero("hero_%s_9" % class_id, class_id, "Teste", 30, [])
	c.roster.append(hero)
	return hero


## Uma expedição com os quatro fundadores, acampada na casa do acampamento.
func _camp(seed_value: int) -> Dictionary:
	var c: Dictionary = Campaign.create_initial(seed_value)
	J.start_expedition(c, "fase_1", seed_value * 7919 + 13)
	J.assign_search_sites(c.session.expedition.corridor, [1, 2, 3, 5, 6, 8], [0, 1, 2, 0, 1, 2])
	c.session.expedition.team = c.roster.slice(0, 4).map(func(h): return h.id)
	var route: Dictionary = c.session.expedition.corridor
	var camp: int = route.sites.map(func(s): return s.camp_site).find(true)
	route.index = route.sites[camp].step
	J.enter_house(c, camp)
	route.sites[camp].enemy_defeated = true
	t.check(J.start_camp(c), "acampa (semente %d)" % seed_value)
	return c


func _data() -> void:
	var rows: Array = GameData.table("camp_skills").values().filter(func(r): return r.has("Cost"))
	t.equal(rows.size(), 32, "32 habilidades: 2 comuns e 5 de cada um dos 6 papéis")
	var bad: Array = []
	for class_id in CLASSES:
		var catalog := C.catalog(class_id)
		t.equal(catalog.size(), 7, "%s: 7 habilidades" % class_id)
		t.equal(catalog.filter(func(id): return String(C.skill(id).Class) == "").size(), 2, "%s: 2 comuns" % class_id)
		var start := C.starters(class_id)
		t.check(start.size() == 3 and start.has("camp_comum_conversa_ao_fogo"), "%s: 3 na chegada, com a Conversa ao Fogo" % class_id)
	for row in rows:
		if int(row.Cost) < 2 or int(row.Cost) > 4 or not ["self", "ally", "team"].has(String(row.Target)) or String(row.DisplayName) == "" \
				or String(row.Description) == "" or not String(row.Name).begins_with("camp_"):
			bad.append(row.Name)
		for key in row.Effects:
			if not EFFECTS.has(String(key)):
				bad.append("%s:%s" % [row.Name, key])
		for id in row.Effects.get("clear", []) + ([row.Effects.phase] if row.Effects.has("phase") else []):
			if not J.PHASE_EFFECTS.has(String(id)):
				bad.append("%s:%s" % [row.Name, id])
	t.equal(bad, [], "custo de 2 a 4, alvo conhecido, nome e texto, e só efeitos da lista")
	t.equal([C.time_budget(), C.max_equipped(), Array(C.rule("Levels")).map(func(x): return int(x))], [12, 4, [2, 4, 6, 8]], "Tempo 12, leva 4, aprende nos níveis 2, 4, 6 e 8")


func _learning() -> void:
	var c: Dictionary = Campaign.create_initial(5)
	var bento := _hero(c, "cao")
	bento.level = 1
	t.equal([C.known(bento).size(), C.equipped(bento).size(), C.picks(bento)], [3, 3, 0], "no nível 1: sabe as 3 da chegada e leva as 3")
	t.equal(C.requirement(bento), "Nível 2 · Treino", "a que falta diz o nível")
	t.check(C.learn(c, bento.id, "camp_cao_palavra_firme") != "", "sem a escolha do nível, não aprende")
	bento.level = 2
	t.equal(C.picks(bento), 1, "no nível 2, uma escolha")
	t.check(C.level_notice(bento) != "", "e o aviso do Treino diz para escolher na Sala")
	t.equal(C.learn(c, bento.id, "camp_cao_palavra_firme"), "", "aprende a que escolheu")
	t.check(C.known(bento).has("camp_cao_palavra_firme") and C.equipped(bento).size() == 4, "e ela já vai junto (a 4ª)")
	t.check(C.learn(c, bento.id, "camp_cao_dividir_a_carga") != "", "uma por nível par")
	bento.level = 9
	t.equal(C.picks(bento), 3, "no nível 9, as escolhas dos níveis 4, 6 e 8 esperam na Sala")
	for id in ["camp_cao_dividir_a_carga", "camp_comum_remendo_de_campo", "camp_cao_reforcar_a_segunda_pele"]:
		t.equal(C.learn(c, bento.id, id), "", "aprende %s" % id)
	t.equal([C.known(bento).size(), C.picks(bento), C.equipped(bento).size()], [7, 0, 4], "sabe as 7 e leva 4")
	t.check(C.learn(c, bento.id, "camp_cao_palavra_firme") != "", "não aprende duas vezes")
	J.start_expedition(c, "fase_1", 77)
	var nick := _hero(c, "gato")
	nick.level = 2
	t.check(C.learn(c, nick.id, "camp_gato_treino_de_queda") != "", "na expedição, não aprende (é na Sala)")


func _choose() -> void:
	var c: Dictionary = Campaign.create_initial(6)
	var iris := _hero(c, "sapo")
	iris.level = 6
	for id in ["camp_sapo_limpar_feridas", "camp_sapo_vapor_calmante", "camp_sapo_sais_de_alerta"]:
		C.learn(c, iris.id, id)
	var swap: Array = ["camp_comum_conversa_ao_fogo", "camp_sapo_limpar_feridas", "camp_sapo_vapor_calmante", "camp_sapo_sais_de_alerta"]
	t.equal(C.choose(c, iris.id, swap), "", "troca as 4 na Sala")
	t.equal(C.equipped(iris), swap, "e leva as escolhidas")
	t.check(C.choose(c, iris.id, swap.slice(0, 3)) != "", "leva 4 (com 4 ou mais sabidas)")
	t.check(C.choose(c, iris.id, [swap[0], swap[0], swap[1], swap[2]]) != "", "sem repetir")
	t.check(C.choose(c, iris.id, [swap[0], swap[1], swap[2], "camp_gato_cochilo_leve"]) != "", "só as que ele sabe")
	J.start_expedition(c, "fase_1", 78)
	t.check(C.choose(c, iris.id, C.known(iris).slice(0, 4)) != "", "na expedição, não troca")


func _camp_use() -> void:
	var c := _camp(31)
	var bento := _hero(c, "cao")
	var nick := _hero(c, "gato")
	var iris := _hero(c, "sapo")
	t.equal(C.time_left(c), 12, "o acampamento começa com 12 de Tempo")
	nick.instinct = 30
	var talk := C.quote(c, bento.id, "camp_comum_conversa_ao_fogo")
	t.check(not talk.available and talk.needs_target, "a de aliado pede o alvo")
	t.check(not C.quote(c, bento.id, "camp_comum_conversa_ao_fogo", bento.id).available, "o aliado não é ele mesmo")
	t.equal(C.use(c, bento.id, "camp_comum_conversa_ao_fogo", nick.id), "", "a Conversa ao Fogo no Nick")
	t.equal([nick.instinct, C.time_left(c)], [15, 10], "−15 de Instinto e 2 de Tempo")
	t.check(C.quote(c, bento.id, "camp_comum_conversa_ao_fogo", iris.id).reason.contains("Já usada"), "cada herói usa cada uma uma vez por acampamento")
	nick.instinct = 0
	t.check(C.quote(c, nick.id, "camp_gato_cochilo_leve").reason.contains("diferença"), "sem Instinto, o cochilo não faria diferença")
	t.check(not C.quote(c, nick.id, "camp_gato_treino_de_queda", bento.id).available, "a que ele não leva não vale")
	t.equal(C.use(c, bento.id, "camp_cao_primeiro_turno"), "", "o Primeiro Turno (vigiar)")
	t.check(C.camp(c).watch and C.time_left(c) == 6, "vigia, e o Tempo cai para 6")
	iris.expedition_uses = {AHExplorationCare.AMPOULE: 1}
	t.equal(C.use(c, iris.id, "camp_sapo_preparar_ampola"), "", "Preparar Ampola")
	t.equal(AHExplorationCare.ampoule_charges(c), 2, "+1 carga da Ampola")
	t.equal(C.time_left(c), 3, "Tempo 3")
	nick.hp = 1
	t.equal(C.use(c, iris.id, "camp_sapo_cha_de_raizes", nick.id), "", "o Chá de Raízes ainda cabe (3)")
	nick.hp = 1
	t.check(C.quote(c, bento.id, "camp_cao_ombro_a_ombro", nick.id).reason.contains("Tempo"), "sem Tempo, recusa com o motivo")
	t.check(J.camp_use_food(c, nick.id), "a Ração não gasta Tempo")
	J.leave_camp(c, 9)
	t.check(not C.quote(c, bento.id, "camp_cao_ombro_a_ombro", nick.id).available, "fora do acampamento, nada")


func _targets() -> void:
	var c := _camp(32)
	var tatu := _hero(c, "tatu")
	c.session.expedition.team.append(tatu.id)
	var bento := _hero(c, "cao")
	bento.hp = int(bento.max_hp) * 6 / 10
	t.check(C.quote(c, tatu.id, "camp_tatu_maca_improvisada", bento.id).reason.contains("Ferido"), "a Maca só em quem está Ferido")
	bento.hp = maxi(1, int(bento.max_hp) / 5)
	var before: int = bento.hp
	t.equal(C.use(c, tatu.id, "camp_tatu_maca_improvisada", bento.id), "", "no Ferido, a Maca vale")
	t.equal(bento.hp, before + maxi(1, int(bento.max_hp) * 25 / 100), "+25% da vida")
	var hope: int = c.session.expedition.hope
	t.equal(C.use(c, tatu.id, "camp_tatu_plano_de_resgate"), "", "o Plano de Resgate (a equipe)")
	t.check(c.session.expedition.corridor.effects.has("preparado"), "a equipe fica Preparada")
	t.equal(c.session.expedition.hope, hope, "e a Esperança não mudou")
	c.session.expedition.corridor.effects.append("cansado")
	var nick := _hero(c, "gato")
	nick.level = 2
	nick.camp_unlocked = ["camp_gato_sacudir_o_cansaco"]
	t.equal(C.use(c, nick.id, "camp_gato_sacudir_o_cansaco"), "", "Sacudir o Cansaço")
	t.check(not c.session.expedition.corridor.effects.has("cansado"), "tira o Cansado")


func _next_fight() -> void:
	var c := _camp(33)
	var bento := _hero(c, "cao")
	var nick := _hero(c, "gato")
	var owl := _hero(c, "coruja")
	t.equal(C.use(c, bento.id, "camp_cao_ombro_a_ombro", nick.id), "", "Ombro a Ombro no Nick")
	var next := C.next_fight(c)
	t.equal([C._next_of(next, bento.id, "block"), C._next_of(next, nick.id, "block")], [1, 1], "os dois com 1 Bloqueio na próxima luta")
	t.equal(C.use(c, owl.id, "camp_coruja_limpar_a_mira"), "", "Limpar a Mira")
	# O teto de 3 fichas.
	next.heroes[nick.id].block = 3
	var team: Array = c.session.expedition.team.map(func(id): return S.hero(c, id))
	var session := AHCombatSession.create(team, ["robot", "robot"], false, 7, 80, [], C.next_fight(c).duplicate(true))
	var units := {}
	for unit in session.state.player_team:
		units[unit.hero_id] = unit
	t.equal([units[bento.id].tokens.block, units[nick.id].tokens.block, units[owl.id].tokens.block], [1, 3, 0], "a luta começa com as fichas de cada um, até 3")
	var front = session.state.enemy_team.filter(func(e): return e.rank == 1)
	t.check(not front.is_empty() and front[0].tokens.mark == 1, "o inimigo da posição 1 começa Marcado")
	C.spend_next_fight(c)
	t.check(not c.session.expedition.corridor.has("camp_next"), "e os bônus saem quando a luta começa")


func _opening() -> void:
	var c := _camp(34)
	var nick := _hero(c, "gato")
	t.equal(C.use(c, nick.id, "camp_gato_rondar_o_quarteirao"), "", "Rondar o Quarteirão")
	J.leave_camp(c, 9)
	var route: Dictionary = c.session.expedition.corridor
	route.current_house = -1
	var fight_step: int = route.steps.map(func(s): return s.type).find("combat", route.index)
	if fight_step < 0:
		t.check(true, "sem luta depois do acampamento nesta semente")
		return
	route.index = fight_step
	t.check(J.start_corridor_combat(c, false).get("opening", false), "a luta seguinte começa com a equipe agindo primeiro")
	t.check(not C.take_opening(c), "uma luta só")


func _night() -> void:
	var bad := 0
	var watched_bad := 0
	for seed_value in 60:
		var c := _camp(100 + seed_value)
		var result := C.night(c)
		var again := _camp(100 + seed_value)
		if seed_value < 3:
			t.equal(C.night(again), result, "a mesma noite para a mesma semente (%d)" % seed_value)
		if result == "bad":
			bad += 1
			t.check(c.session.expedition.corridor.effects.has("exposto"), "noite mal dormida: Exposto")
		var guarded := _camp(100 + seed_value)
		C.camp(guarded).watch = true
		if C.night(guarded) == "bad":
			watched_bad += 1
	t.check(bad > 8 and bad < 32, "cerca de 1 em 3 noites mal dormidas (%d de 60)" % bad)
	t.equal(watched_bad, 0, "quem vigia evita a Noite mal dormida")
	t.check(C.night_notice("bad") != "" and C.night_notice("watched") != "" and C.night_notice("good") == "", "o aviso da noite")


func _save() -> void:
	var c: Dictionary = Campaign.create_initial(8)
	var hero := _hero(c, "rato")
	t.check(hero.has("camp_unlocked") and hero.has("camp_loadout"), "o herói novo nasce com as listas")
	var old: Dictionary = c.roster[0]
	old.erase("camp_unlocked")
	old.erase("camp_loadout")
	t.equal(C.equipped(old), C.starters(old.class_id), "o save de antes leva as 3 da chegada")
	old.level = 1
	old.camp_unlocked = ["camp_cao_palavra_firme", "nada", "camp_gato_cochilo_leve"]
	old.camp_loadout = ["nada"]
	C.migrate(c)
	t.equal([old.camp_unlocked, old.camp_loadout], [[], []], "o editado sai limpo (nível 1: nenhuma aprendida)")
	old.level = 4
	t.equal(C.picks(old), 2, "quem já está no nível 4 tem as escolhas dos níveis 2 e 4 para fazer na Sala")
