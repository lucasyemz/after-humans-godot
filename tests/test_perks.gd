## As peculiaridades (#264, PR 1, aprovado em 02/11): o catálogo com as 8 novas e os efeitos, o limite de 3 + 3, as
## incompatíveis, as de cura só para quem cura, a positiva fixa dos fundadores nas campanhas novas, o save e a ficha.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const J = preload("res://scripts/flow/journey_rules.gd")
const P = preload("res://scripts/flow/perk_rules.gd")
const C = preload("res://scripts/flow/camp_skills.gd")

var t


func run(context) -> void:
	t = context
	_catalog()
	_limits()
	_founders()
	_combat()
	_camp()
	_search()
	_ampoule()
	_save()
	_sheet()


func _catalog() -> void:
	var rows: Dictionary = GameData.table("perks")
	t.equal(rows.size(), 16, "16 peculiaridades: as 8 de antes e as 8 novas")
	t.equal([rows.values().filter(func(r): return bool(r.bPositive)).size(), rows.values().filter(func(r): return not bool(r.bPositive)).size()], [8, 8], "8 positivas e 8 negativas")
	for pair in [["steady", "stumbling"], ["light-sleeper", "heavy-sleeper"], ["mender", "shaky"], ["agile", "sluggish"]]:
		t.check(Array(rows[pair[0]].Incompatible).has(pair[1]) and Array(rows[pair[1]].Incompatible).has(pair[0]), "%s e %s são incompatíveis" % pair)
	var odd: Array = []
	for id in rows:
		for other in rows[id].get("Incompatible", []):
			if not rows.has(other):
				odd.append("%s→%s" % [id, other])
	t.equal(odd, [], "toda incompatível existe")
	t.check(not rows.values().any(func(r): return r.has("MaxHpBonus") or String(r.get("Unit", "")) == "Damage"), "nenhuma mexe em Vida nem em dano direto")


func _limits() -> void:
	var hero := {"class_id": "cao", "perks": [], "fixed_perks": []}
	for id in ["agile", "brave", "hopeful"]:
		t.check(P.add(hero, id), "a positiva %s entra" % id)
	t.check(not P.add(hero, "loyal"), "a 4ª positiva não entra (limite de 3)")
	for id in ["short-fuse", "machine-fear", "stumbling"]:
		t.check(P.add(hero, id), "a negativa %s entra" % id)
	t.check(not P.add(hero, "heavy-sleeper"), "a 4ª negativa não entra")
	t.equal(hero.perks.size(), 6, "3 + 3")
	var other := {"class_id": "cao", "perks": ["agile"], "fixed_perks": []}
	t.check(not P.add(other, "sluggish"), "a incompatível não entra")
	t.check(not P.add(other, "agile"), "nem a repetida")
	# As de cura: o cão (Proteção) não cura; a Química cura.
	t.equal([P.class_heals("cao"), P.class_heals("sapo")], [false, true], "quem tem cura entre as 7 habilidades")
	t.check(not P.add({"class_id": "cao", "perks": []}, "mender"), "Mãos de remendo não vai para quem não cura")
	t.check(P.add({"class_id": "sapo", "perks": []}, "mender"), "e vai para quem cura")
	# O sorteio respeita tudo isso, em muitas sementes.
	var bad: Array = []
	for seed_value in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var class_id: String = ["cao", "gato", "sapo", "coruja", "rato", "tatu"][seed_value % 6]
		var rolled: Array = Campaign.roll_perks(GameData.table("perks"), rng, class_id)
		var check := {"class_id": class_id, "perks": []}
		for id in rolled:
			if not P.fits(check.perks, id, class_id):
				bad.append([seed_value, rolled])
				break
			check.perks.append(id)
		if rolled.size() < 2 or rolled.size() > 3 or not rolled.any(func(id): return P.positive(id)) or rolled.all(func(id): return P.positive(id)):
			bad.append([seed_value, rolled])
	t.equal(bad, [], "o sorteio dá 2 ou 3, com uma positiva e uma negativa, sem quebrar as regras")
	var fixed := {"class_id": "cao", "perks": ["loyal"], "fixed_perks": ["loyal"]}
	t.check(not P.remove(fixed, "loyal") and fixed.perks.has("loyal"), "a fixada não sai")


func _founders() -> void:
	var expected := {"cao": "loyal", "gato": "agile", "sapo": "mender", "coruja": "light-sleeper"}
	for seed_value in [1, 2, 3, 41, 99]:
		var c: Dictionary = Campaign.create_initial(seed_value)
		for hero in c.roster:
			var own: String = expected.get(String(hero.class_id), "")
			if own == "":
				continue
			t.check(Array(hero.perks).has(own) and Array(hero.fixed_perks) == [own], "%s chega com %s fixada (semente %d)" % [hero.display_name, own, seed_value])
			t.check(Array(hero.perks).any(func(id): return not P.positive(id)), "%s também sorteia uma negativa (semente %d)" % [hero.display_name, seed_value])
			t.check(Array(hero.perks).filter(func(id): return P.positive(id)).size() <= P.MAX_SIDE, "e fica no limite")


func _combat() -> void:
	var c: Dictionary = Campaign.create_initial(5)
	var tank: Dictionary = c.roster.filter(func(h): return h.class_id == "cao")[0]
	tank.perks = ["steady"]
	var session := AHCombatSession.create([tank], [], false, 3)
	var unit: AHCombat.Unit = session.state.player_team[0]
	var role = session.engine.find_class("cao")
	t.equal(snappedf(session.engine.hero_resist(unit, "DisplacementResist"), 0.001), snappedf(float(role.DisplacementResist) + 0.1, 0.001), "Pé firme: +10 pp de deslocamento")
	tank.perks = ["stumbling"]
	session = AHCombatSession.create([tank], [], false, 3)
	unit = session.state.player_team[0]
	t.equal(snappedf(session.engine.hero_resist(unit, "DisplacementResist"), 0.001), snappedf(float(role.DisplacementResist) - 0.1, 0.001), "Pé pesado: −10 pp")
	tank.perks = []
	session = AHCombatSession.create([tank], [], false, 3)
	unit = session.state.player_team[0]
	t.equal(session.engine.hero_resist(unit, "DisplacementResist"), float(role.DisplacementResist), "sem peculiaridade, o do papel")
	# A cura: Mãos de remendo +1, Mãos trêmulas −1, na faixa e no motor.
	var medic: Dictionary = c.roster.filter(func(h): return h.class_id == "sapo")[0]
	var heal_id := ""
	for id in AHHeroSkills.equipped(medic):
		if int(GameData.combat.abilities[id].HealRange.Max) > 0:
			heal_id = id
	if t.check(heal_id != "", "a Química leva uma cura"):
		var raw: Dictionary = GameData.combat.abilities[heal_id].HealRange
		for case in [[["mender"], 1], [["shaky"], -1], [[], 0]]:
			medic.perks = case[0]
			var s := AHCombatSession.create([medic], [], false, 3)
			var shown := s.effective_range(heal_id, "heal", s.state.player_team[0].id)
			t.equal([shown.Min, shown.Max], [maxi(0, int(raw.Min) + case[1]), maxi(0, int(raw.Max) + case[1])], "a faixa de cura com %s" % str(case[0]))
	# Pavio curto: é uma peculiaridade de Instinto, 1× por rodada, como o Temor das máquinas.
	var fuse = GameData.combat.perks.get("short-fuse")
	t.check(fuse != null and is_equal_approx(float(fuse.Value), 3.0), "Pavio curto: +3 Instinto")
	tank.perks = ["short-fuse"]
	var fight := AHCombatSession.create([tank], [], false, 3)
	var hit: AHCombat.Unit = fight.state.player_team[0]
	var before := hit.instinct
	fight.engine._activate_perk(hit, "short-fuse", [])
	fight.engine._activate_perk(hit, "short-fuse", [])
	t.equal(hit.instinct - before, 3, "uma vez por rodada")


func _camp() -> void:
	var c: Dictionary = Campaign.create_initial(7)
	J.start_expedition(c, "fase_1", 7 * 7919 + 13)
	J.assign_search_sites(c.session.expedition.corridor, [1, 2, 3, 5, 6, 8], [0, 1, 2, 0, 1, 2])
	c.session.expedition.team = c.roster.slice(0, 4).map(func(h): return h.id)
	var route: Dictionary = c.session.expedition.corridor
	var site: int = route.sites.map(func(s): return s.camp_site).find(true)
	route.index = route.sites[site].step
	J.enter_house(c, site)
	route.sites[site].enemy_defeated = true
	if not t.check(J.start_camp(c), "acampa"):
		return
	var bento: Dictionary = S.hero(c, "hero_cao_bento")
	bento.perks = ["heavy-sleeper"]
	bento.instinct = 40
	t.check(C.known(bento).has("camp_cao_primeiro_turno"), "o Bento sabe o Primeiro Turno (vigiar)")
	t.equal(C.use(c, bento.id, "camp_cao_primeiro_turno"), "", "usa o Primeiro Turno")
	bento.instinct = 40
	t.check(not bool(C.camp(c).get("watch", false)), "Sono pesado: quem dorme pesado não vigia")
	var light: Dictionary = c.roster[1]
	light.perks = ["light-sleeper"]
	light.instinct = 40
	C.night(c)
	t.equal([int(bento.instinct), int(light.instinct)], [45, 35], "na noite: Sono pesado +5, Sono leve −5")
	# Uma habilidade que só vigia (o Posto Alto da coruja): com Sono pesado, não fica disponível, com o motivo.
	var d: Dictionary = Campaign.create_initial(17)
	J.start_expedition(d, "fase_1", 17 * 7919 + 13)
	J.assign_search_sites(d.session.expedition.corridor, [1, 2, 3, 5, 6, 8], [0, 1, 2, 0, 1, 2])
	d.session.expedition.team = d.roster.slice(0, 4).map(func(h): return h.id)
	var other_route: Dictionary = d.session.expedition.corridor
	var other_site: int = other_route.sites.map(func(s): return s.camp_site).find(true)
	other_route.index = other_route.sites[other_site].step
	J.enter_house(d, other_site)
	other_route.sites[other_site].enemy_defeated = true
	if t.check(J.start_camp(d), "acampa de novo"):
		var owl: Dictionary = d.roster.filter(func(h): return h.class_id == "coruja")[0]
		owl.perks = ["heavy-sleeper"]
		owl.camp_unlocked = ["camp_coruja_posto_alto"]
		owl.camp_loadout = C.known(owl).slice(0, C.max_equipped()) if C.known(owl).size() <= C.max_equipped() else []
		if not C.equipped(owl).has("camp_coruja_posto_alto"):
			owl.camp_loadout = C.known(owl).filter(func(id): return id != C.known(owl)[0]).slice(0, C.max_equipped())
		var q := C.quote(d, owl.id, "camp_coruja_posto_alto")
		var time := C.time_left(d)
		t.check(not q.available and String(q.reason).contains("Sono pesado"), "o Posto Alto com Sono pesado: indisponível (%s)" % q.reason)
		t.check(C.use(d, owl.id, "camp_coruja_posto_alto") != "" and C.time_left(d) == time, "e não gasta Tempo")
		owl.perks = []
		t.check(C.quote(d, owl.id, "camp_coruja_posto_alto").available, "sem o Sono pesado, vigia")


## A Ampola fora da luta (a mesma da luta): as Mãos de quem a leva somam, como na luta.
func _ampoule() -> void:
	var c: Dictionary = Campaign.create_initial(12)
	J.start_expedition(c, "fase_1", 12)
	c.session.expedition.team = c.roster.slice(0, 4).map(func(h): return h.id)
	c.session.screen = "corridor"
	var hurt: Dictionary = S.hero(c, "hero_cao_bento")
	hurt.hp = 5
	var iris = AHExplorationCare.iris(c)
	if not t.check(iris != null, "a Íris está na equipe"):
		return
	var row = GameData.combat.abilities[AHExplorationCare.AMPOULE]
	var ranges: Array = []
	for hands in [["mender"], ["shaky"], []]:
		iris.perks = hands
		var q := AHExplorationCare.quote(c, hurt.id, AHExplorationCare.IRIS_AMPOULE)
		ranges.append([q.heal_min, q.heal_max])
	t.equal(ranges, [[int(row.HealRange.Min) + 1, int(row.HealRange.Max) + 1], [int(row.HealRange.Min) - 1, int(row.HealRange.Max) - 1],
		[int(row.HealRange.Min), int(row.HealRange.Max)]], "a Ampola no mapa: Mãos de remendo +1, Mãos trêmulas −1")
	# A ficha: Pé firme no deslocamento, como na luta.
	var role = GameData.combat.classes.get("cao")
	var rows := AHCharacterSheet.role_rows("cao", ["steady"])
	t.check(String(rows[0][0]).contains("deslocamento %d%%" % roundi((float(role.DisplacementResist) + 0.1) * 100.0)), "a ficha mostra o deslocamento com Pé firme")


func _search() -> void:
	var c: Dictionary = Campaign.create_initial(8)
	J.start_expedition(c, "fase_1", 8)
	var outcome := {"ScrapDelta": 2, "Text": "teste"}
	var loot := func() -> int: return int(c.session.expedition.loot.scrap)
	var team: Array = c.session.expedition.team
	for id in team:
		S.hero(c, id).perks = []
	var before: int = loot.call()
	J.apply_search_outcome(c, AHCombatRandom.new(1), outcome)
	var plain: int = loot.call() - before
	S.hero(c, team[0]).perks = ["scavenger"]
	before = loot.call()
	J.apply_search_outcome(c, AHCombatRandom.new(1), outcome)
	t.equal([plain, loot.call() - before], [2, 3], "Faro de busca: +1 sucata na busca que traz sucata")
	before = loot.call()
	J.apply_search_outcome(c, AHCombatRandom.new(1), {"FoodDelta": 1, "Text": "teste"})
	t.equal(loot.call() - before, 0, "e nada na busca sem sucata")


func _save() -> void:
	var c: Dictionary = Campaign.create_initial(9)
	var hero: Dictionary = c.roster[0]
	var perks: Array = hero.perks.duplicate()
	hero.erase("fixed_perks")
	S.migrate(c)
	t.equal([hero.perks, hero.fixed_perks], [perks, []], "o save de antes não ganha nem perde peculiaridade, e nada fica fixado")
	for bad in [5, "x", ["loyal", 3], {"a": 1}]:
		hero.fixed_perks = bad
		hero.perks = ["loyal", 7] if typeof(bad) == TYPE_ARRAY else perks.duplicate()
		S.migrate(c)
		t.check(Array(hero.perks).all(func(id): return typeof(id) == TYPE_STRING) and Array(hero.fixed_perks).all(func(id): return Array(hero.perks).has(id)),
			"o save editado %s fica limpo" % str(bad))
	hero.perks = ["loyal"]
	hero.fixed_perks = ["agile"]
	S.migrate(c)
	t.equal(hero.fixed_perks, [], "a fixada que ele não tem sai")
	var copy: Dictionary = JSON.parse_string(JSON.stringify(Campaign.create_initial(10)))
	S.migrate(copy)
	t.check(copy.roster.any(func(h): return Array(h.fixed_perks).size() == 1), "a fixada sobrevive ao JSON do save")


func _sheet() -> void:
	var c: Dictionary = Campaign.create_initial(11)
	var bento: Dictionary = S.hero(c, "hero_cao_bento")
	var sheet := AHCharacterSheet.from_hero(bento)
	t.check(sheet.passives.any(func(r): return String(r[0]).contains("Companheiro fiel") and String(r[0]).contains("fixada")), "a ficha marca a fixada")
	t.check(not sheet.passives.any(func(r): return String(r[0]).contains("fixada") and not String(r[0]).contains("Companheiro fiel")), "e só ela")
