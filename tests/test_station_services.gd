## Os serviços dos cômodos (#265, aprovado em 01/11): o Bar alivia quem ficou na Estação e trata o trauma; os beliches
## aliviam na noite; a Enfermaria no nível 2 trata uma peculiaridade negativa num leito, por alguns dias. Os números
## vêm de data/station-services.json.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const V = preload("res://scripts/flow/station_services.gd")
const J = preload("res://scripts/flow/journey_rules.gd")

var t


func run(context) -> void:
	t = context
	_data()
	_bar()
	_bunks()
	_quirk()
	_save()


func _data() -> void:
	for name in ["bar", "dormitory", "infirmary_quirk"]:
		t.check(not V.rule(name).is_empty(), "a regra %s está nos dados" % name)
	t.equal([V.trauma_cost(), int(V.rule("bar").Instinct), int(V.rule("dormitory").BunkInstinct), int(V.rule("infirmary_quirk").Days)],
		[5, 5, 3, 2], "os números da proposta: trauma 5 sementes, Bar −5, beliches −3, peculiaridade 2 dias")


## Uma volta com a equipe dos dois primeiros: os outros ficaram na Estação.
## O Instinto de cada um (instinct: {índice: valor}) é posto depois da partida (que zera o da equipe).
func _returned(c: Dictionary, instinct: Dictionary) -> Dictionary:
	var team: Array = c.roster.slice(0, 2).map(func(h): return h.id)
	J.start_expedition(c, "fase_1", 17)
	c.session.expedition.team = team
	for index in instinct:
		c.roster[index].instinct = instinct[index]
	c.session.result = "victory"
	return S.finish_return(c)


func _bar() -> void:
	var c: Dictionary = Campaign.create_initial(11)
	var stayed: Dictionary = c.roster[3]
	c.station.rooms[S.BAR] = 0
	var report := _returned(c, {3: 30})
	t.equal(int(stayed.instinct), 30, "sem o Bar, quem ficou não muda")
	t.equal(report.get("bar", []), [], "e o relatório não fala do Bar")
	c = Campaign.create_initial(11)
	stayed = c.roster[3]
	var went: Dictionary = c.roster[0]
	c.station.rooms[S.BAR] = 1
	report = _returned(c, {0: 30, 3: 30})
	t.equal(int(stayed.instinct), 25, "com o Bar, quem ficou na Estação perde 5 de Instinto")
	t.check(report.bar.any(func(r): return r.hero_id == stayed.id and r.instinct == 5), "e o relatório diz quem")
	t.check(not report.bar.any(func(r): return r.hero_id == went.id), "quem foi na expedição não ganha o alívio do Bar")


func _bunks() -> void:
	var c: Dictionary = Campaign.create_initial(12)
	t.equal(V.bunk_relief(c), 0, "sem os beliches, nada a mais")
	c.station.rooms[S.DORMITORY] = 2
	t.equal(V.bunk_relief(c), 3, "com os beliches, −3 de Instinto a mais na noite")


func _quirk() -> void:
	var c: Dictionary = Campaign.create_initial(13)
	var hero: Dictionary = {}
	var bad := ""
	for entry in c.roster:
		var negatives := V.negative_perks(entry)
		if not negatives.is_empty():
			hero = entry
			bad = String(negatives[0])
			break
	if not t.check(not hero.is_empty(), "um fundador com peculiaridade negativa"):
		return
	c.station.rooms[S.INFIRMARY] = 1
	t.check(V.quirk_block(c, hero.id, bad).contains("nível 2"), "no nível 1, a Enfermaria não trata peculiaridades")
	c.station.rooms[S.INFIRMARY] = 2
	var good := Array(hero.perks).filter(func(id): return not V.negative_perks(hero).has(id))
	if not good.is_empty():
		t.check(V.quirk_block(c, hero.id, String(good[0])) != "", "a positiva não se trata")
	t.equal(V.treat_quirk(c, hero.id, bad), "", "começa o tratamento da negativa")
	t.check(V.treating(hero) and not S.can_deploy(hero), "em tratamento, ele não parte")
	t.check(S.deploy_block(hero).contains("tratamento"), "e o motivo diz o tratamento")
	t.check(V.treat_quirk(c, hero.id, bad) != "", "um tratamento por vez")
	# Os leitos: 4 no nível 2; o tratamento ocupa um.
	t.equal(V.beds_treating(c), 1, "o tratamento ocupa um leito")
	var others: Array = c.roster.filter(func(h): return h.id != hero.id)
	S.admit_fallen(c, others.slice(0, 3).map(func(h): return h.id))
	t.equal(S.fallen(c).filter(func(h): return S.in_bed(h)).size(), 3, "com um leito no tratamento, 3 caídos nos outros 3")
	var blocked := Campaign.create_initial(14)
	blocked.station.rooms[S.INFIRMARY] = 2
	S.admit_fallen(blocked, blocked.roster.slice(0, 4).map(func(h): return h.id))
	var extra := Campaign.new_hero("hero_rato_9", "rato", "Teste", 20, ["anxious"])
	blocked.roster.append(extra)
	t.check(V.quirk_block(blocked, extra.id, "anxious").contains("leito"), "sem leito livre, não começa")
	# Os dias: na volta (finish_return) e no Esperar um dia.
	t.equal(V.tick_treatments(c), [], "um dia: ainda em tratamento")
	var done := V.tick_treatments(c)
	t.check(done.size() == 1 and not Array(hero.perks).has(bad) and not V.treating(hero), "no segundo dia, a peculiaridade sai")
	t.check(S.can_deploy(hero), "e ele pode partir de novo")


func _save() -> void:
	var c: Dictionary = Campaign.create_initial(15)
	var hero: Dictionary = c.roster[0]
	hero.quirk_treatment = 5
	V.migrate(c)
	t.check(not hero.has("quirk_treatment"), "o tratamento de outro tipo sai")
	hero.quirk_treatment = {"perk": "nada", "days": 2}
	V.migrate(c)
	t.check(not hero.has("quirk_treatment"), "o de uma peculiaridade que ele não tem também")
