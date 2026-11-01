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
	_talks()
	_camp_learning()
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


## As conversas do Bar: uma por dia no nível 1, duas no nível 2; o dia novo (outro ciclo) zera a conta.
func _talks() -> void:
	var c: Dictionary = Campaign.create_initial(16)
	c.station.rooms[S.BAR] = 1
	S.adjust(c, "seeds", 50)
	for entry in c.roster:
		entry.trauma = true
	var a: Dictionary = c.roster[0]
	var b: Dictionary = c.roster[1]
	t.equal(V.talks_left(c), 1, "no nível 1, uma conversa por dia")
	t.equal(S.treat_trauma(c, a.id), "", "a primeira conversa trata")
	t.check(S.treat_trauma(c, b.id).contains("hoje"), "a segunda no mesmo dia espera")
	t.check(bool(b.trauma), "e o trauma dele fica")
	c.station.cycle_number = int(c.station.get("cycle_number", 0)) + 1
	t.equal(S.treat_trauma(c, b.id), "", "no dia seguinte, conversa de novo")
	c.station.rooms[S.BAR] = 2
	t.equal(V.talks_left(c), 1, "no nível 2, a segunda conversa do dia")
	t.equal(S.treat_trauma(c, c.roster[2].id), "", "e ela trata")
	t.equal(V.talks_left(c), 0, "duas e acabou")
	c.station.cycle_number = int(c.station.cycle_number) + 1
	var again: Dictionary = c.roster[3]
	S.treat_trauma(c, again.id)
	again.trauma = true
	S.treat_trauma(c, again.id)
	t.equal(V.talks_left(c), 0, "o mesmo herói duas vezes no dia também gasta as duas conversas")
	again.trauma = true
	c.station.rooms[S.BAR] = 0
	t.check(S.treat_trauma(c, c.roster[3].id).contains("Recupere o Bar"), "sem o Bar, não há conversa")


## Aprender uma de acampamento é no Treino (#265): conta como o treino do dia; com o dia cheio, espera.
func _camp_learning() -> void:
	var c: Dictionary = Campaign.create_initial(17)
	var a: Dictionary = c.roster[0]
	var b: Dictionary = c.roster[1]
	for hero in [a, b]:
		hero.level = 2
	var skill_a := String(AHCampSkills.catalog(String(a.class_id)).filter(func(id): return not AHCampSkills.known(a).has(id))[0])
	var skill_b := String(AHCampSkills.catalog(String(b.class_id)).filter(func(id): return not AHCampSkills.known(b).has(id))[0])
	t.equal(V.learn_camp(c, a.id, skill_a), "", "no Treino, o primeiro aprende")
	t.check(AHCampSkills.known(a).has(skill_a), "e sabe a nova")
	t.check(V.learn_camp(c, b.id, skill_b).contains("hoje"), "no nível 1, o segundo herói espera o dia seguinte")
	t.check(not AHCampSkills.known(b).has(skill_b), "e não aprende")
	c.station.rooms[S.TRAINING] = 2
	t.equal(V.learn_camp(c, b.id, skill_b), "", "no nível 2, dois heróis no mesmo dia")


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
	t.check(V.report_lines(c, {"treated": done}).any(func(l): return l.contains("Enfermaria") and l.contains(hero.display_name)), "o relatório diz quem terminou o tratamento")
	# Em tratamento, ele não trabalha num posto (o leito vem antes).
	var d: Dictionary = Campaign.create_initial(18)
	d.station.rooms[S.INFIRMARY] = 2
	d.station.rooms[S.RESEARCH] = 1
	var worker: Dictionary = d.roster[0]
	if not Array(worker.perks).has("anxious"):
		worker.perks = Array(worker.perks) + ["anxious"]
	t.equal(V.treat_quirk(d, worker.id, "anxious"), "", "começa o tratamento")
	t.check(S.post_block(d, worker.id, S.RESEARCH).contains("tratamento"), "em tratamento, o posto fica bloqueado")
	worker.post = S.RESEARCH
	t.check(not S.run_posts(d, []).any(func(r): return r.hero_id == worker.id), "e o posto dele não rende")


func _save() -> void:
	var c: Dictionary = Campaign.create_initial(15)
	var hero: Dictionary = c.roster[0]
	hero.quirk_treatment = 5
	V.migrate(c)
	t.check(not hero.has("quirk_treatment"), "o tratamento de outro tipo sai")
	hero.quirk_treatment = {"perk": "nada", "days": 2}
	V.migrate(c)
	t.check(not hero.has("quirk_treatment"), "o de uma peculiaridade que ele não tem também")
	# Saves editados com tipos errados: nada de erro de script, e o migrate limpa.
	if not Array(hero.perks).has("anxious"):
		hero.perks = Array(hero.perks) + ["anxious"]
	for bad in [{"perk": "anxious", "days": [1]}, {"perk": null, "days": 2}, {"perk": 7, "days": 2}, "x"]:
		hero.quirk_treatment = bad
		t.check(not V.treating(hero), "%s não conta como tratamento" % str(bad))
		V.migrate(c)
		t.check(not hero.has("quirk_treatment"), "e sai no migrate: %s" % str(bad))
	var positives: Array = Array(hero.perks).filter(func(id): return GameData.row("perks", String(id)) != null and not V.negative_perks(hero).has(id))
	if not positives.is_empty():
		hero.quirk_treatment = {"perk": String(positives[0]), "days": 2}
		V.migrate(c)
		t.check(not hero.has("quirk_treatment"), "o tratamento de uma positiva sai")
	for bad_day in [{"cycle": 0, "heroes": 5}, {"cycle": [0], "heroes": []}, {"cycle": 0, "heroes": {"a": 1}}, {"cycle": 0, "heroes": [3]}, 9]:
		c.station.training = bad_day
		c.station.bar_talks = bad_day
		t.equal([V.trainees_per_day(c) > 0, V.training_block(c, hero.id), V.talks_left(c) >= 0], [true, "", true], "o dia editado %s não quebra" % str(bad_day))
		V.migrate(c)
		t.check(not c.station.has("training") and not c.station.has("bar_talks"), "e sai no migrate: %s" % str(bad_day))
	c.station.training = {"cycle": 3.0, "heroes": ["hero_cao_bento"]}
	V.migrate(c)
	t.check(c.station.has("training"), "o dia válido (do JSON, com número decimal) fica")
