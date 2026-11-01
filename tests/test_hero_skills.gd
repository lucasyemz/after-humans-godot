## As sete habilidades de combate (#259, aprovada pelo Lucas em 01/11): 7 por classe (as 4 de base e 3 desbloqueios),
## a mesma regra para fundadores e recrutados; o Treino ensina nos níveis 3, 5 e 7; vão 4 para a luta, trocadas na Sala,
## e nenhuma escolha deixa uma posição sem habilidade. Os fundadores de loadout vazio lutam como sempre (a paridade fica
## no test_combat_parity).
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const BENTO := "hero_cao_bento"
const CLASSES := ["cao", "gato", "sapo", "coruja", "rato", "tatu"]

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_data()
	_balance()
	_coverage()
	_training()
	_choose()
	_combat()
	_auto_fights()
	_save()
	await _screen()


func _campaign(seed_value: int) -> Dictionary:
	var c: Dictionary = Campaign.create_initial(seed_value)
	c.station.rooms[S.CHARACTERS] = 4
	c.inventory.seeds = 500
	return c


## Um herói da classe: o fundador, ou um recrutado (o guaxinim e o tatu não têm fundador).
func _hero(c: Dictionary, class_id: String) -> Dictionary:
	for entry in c.roster:
		if entry.class_id == class_id:
			return entry
	if not c.unlocked_classes.has(class_id):
		c.unlocked_classes.append(class_id)
	var made := S.recruit(c, class_id, RandomNumberGenerator.new(), "Teste")
	return S.hero(c, String(made.get("hero_id", "")))


## data/classes.json e data/abilities.json: 7 por classe, as de base de sempre e 3 desbloqueios que existem, da classe, com
## a arte de uma da mesma classe.
func _data() -> void:
	for class_id in CLASSES:
		var all := AHHeroSkills.catalog(class_id)
		var unique: Array = []
		for id in all:
			if not unique.has(id):
				unique.append(id)
		t.check(all.size() == 7 and unique.size() == 7, "%s: 7 habilidades diferentes no catálogo" % class_id)
		t.equal(AHHeroSkills.base(class_id).size(), 4, "%s: 4 de base" % class_id)
		for id in AHHeroSkills.unlocks(class_id):
			var row = GameData.row("abilities", id)
			if not t.check(row != null, "%s: %s existe" % [class_id, id]):
				continue
			t.equal(String(row.ClassId), class_id, "%s: é da classe" % id)
			var art := String(row.get("ArtOf", ""))
			t.check(AHHeroSkills.base(class_id).has(art), "%s: usa a arte de uma da mesma classe (%s)" % [id, art])
			t.check(GameData.combat.abilities.has(id), "%s: a luta carrega" % id)
			t.check(String(row.get("Description", "")) != "", "%s: tem descrição" % id)


## Os desbloqueios ficam abaixo do golpe principal da classe e nenhum atordoa.
func _balance() -> void:
	for class_id in CLASSES:
		var best := 0.0
		for id in AHHeroSkills.base(class_id):
			var damage = GameData.row("abilities", id).get("DamageRange")
			if damage is Dictionary:
				best = maxf(best, (float(damage.get("Min", 0)) + float(damage.get("Max", 0))) * 0.5)
		for id in AHHeroSkills.unlocks(class_id):
			var data = GameData.row("abilities", id)
			var damage = data.get("DamageRange")
			var average: float = (float(damage.get("Min", 0)) + float(damage.get("Max", 0))) * 0.5 if damage is Dictionary else 0.0
			t.check(average < best, "%s: %s faz menos que o golpe principal (%.1f, %.1f)" % [class_id, id, average, best])
			var inflicts = data.get("Inflicts")
			t.equal(int(inflicts.get("Stun", 0)) if inflicts is Dictionary else 0, 0, "%s: não atordoa" % id)


## A regra das posições (a QA da #259, com a #95): as 4 de base atacam das posições 1 a 4; das 35 combinações de 4, a
## Sala aceita exatamente as que têm um ataque partindo de cada posição.
func _coverage() -> void:
	var c := _campaign(2591)
	for class_id in CLASSES:
		var hero := _hero(c, class_id)
		hero.level = 7
		hero.unlocked = AHHeroSkills.unlocks(class_id)
		t.equal(AHHeroSkills.uncovered(AHHeroSkills.base(class_id)), [], "%s: as 4 de base cobrem as posições 1 a 4" % class_id)
		var all := AHHeroSkills.catalog(class_id)
		var accepted := 0
		var wrong: Array = []
		for combo in _combinations(all, 4):
			var covers := [1, 2, 3, 4].all(func(rank): return combo.any(func(id): return _damage(id) and _ranks(id).has(rank)))
			var error := AHHeroSkills.invalid(hero, combo)
			if covers:
				accepted += 1
			if (error == "") != covers:
				wrong.append(combo)
			elif not covers and not error.begins_with("Sem ataque da posição"):
				wrong.append(combo)
		t.equal(wrong, [], "%s: a Sala aceita só as combinações com ataque de cada posição, e diz a que falta" % class_id)
		t.check(accepted >= 16, "%s: %d de 35 combinações valem" % [class_id, accepted])
		# Com a regra, toda escolha aceita parte de qualquer posição (a #95 nunca recusa por causa das habilidades).
		var free_rank := true
		for combo in _combinations(all, 4):
			if AHHeroSkills.invalid(hero, combo) == "":
				for rank in [1, 2, 3, 4]:
					if S.attacks_from_rank(class_id, rank, combo).is_empty():
						free_rank = false
		t.check(free_rank, "%s: toda escolha aceita ataca de qualquer posição da formação" % class_id)
	# Os pontos fracos de hoje reforçados: o gato na posição 4, o sapo e a coruja na 1.
	for pair in [["gato", 4], ["sapo", 1], ["coruja", 1]]:
		var from_rank: Array = AHHeroSkills.unlocks(pair[0]).filter(func(id): return _ranks(id).has(pair[1]))
		t.check(not from_rank.is_empty(), "%s: um desbloqueio parte da posição %d" % pair)


func _damage(ability_id: String) -> bool:
	var damage = GameData.row("abilities", ability_id).get("DamageRange")
	return damage is Dictionary and int(damage.get("Max", 0)) > 0


func _ranks(ability_id: String) -> Array:
	return Array(GameData.row("abilities", ability_id).OriginRanks).map(func(r): return int(r))


func _combinations(items: Array, size: int) -> Array:
	if size == 0:
		return [[]]
	var out: Array = []
	for i in items.size():
		for tail in _combinations(items.slice(i + 1), size - 1):
			out.append([items[i]] + tail)
	return out


## O Treino: nos níveis 3, 5 e 7, aprender um dos bloqueados, pelo custo do nível mais 1, 2 e 3 fragmentos; a ordem é do
## jogador; a vaga não se perde; aprender não equipa.
func _training() -> void:
	var c := _campaign(2592)
	var bento: Dictionary = S.hero(c, BENTO)
	bento.xp = 99999
	t.check(AHHeroLevels.options(bento).all(func(o): return String(o.get("Stat", "")) != "Learn"), "no treino para o nível 2, nada a aprender")
	bento.level = 2
	var learn: Array = AHHeroLevels.options(bento).filter(func(o): return String(o.get("Stat", "")) == "Learn")
	t.equal(learn.map(func(o): return o.AbilityId), AHHeroSkills.unlocks("cao"), "no treino para o nível 3, os 3 desbloqueios")
	t.check(learn.all(func(o): return int(o.Fragments) == 1), "o primeiro custa 1 fragmento a mais")
	c.inventory.fragments = 0
	var seeds := S.quantity(c, "seeds")
	t.check(AHHeroLevels.train(c, BENTO, AHHeroSkills.LEARN + "cao_alerta_de_perigo") != "", "sem o fragmento, não aprende")
	t.check(AHHeroLevels.level(bento) == 2 and S.quantity(c, "seeds") == seeds, "e não gasta nada nem sobe")
	c.inventory.fragments = 6
	t.equal(AHHeroLevels.train(c, BENTO, AHHeroSkills.LEARN + "cao_alerta_de_perigo"), "", "aprende o terceiro primeiro: a ordem é do jogador")
	t.check(AHHeroLevels.level(bento) == 3 and bento.unlocked == ["cao_alerta_de_perigo"] and S.quantity(c, "fragments") == 5, "sobe, sabe e paga 1")
	t.equal(AHHeroSkills.equipped(bento), AHHeroSkills.base("cao"), "aprender não equipa: continua com as 4 de base")
	t.check(AHHeroSkills.known(bento).size() == 5, "e sabe 5")
	t.check(AHHeroLevels.options(bento).all(func(o): return String(o.get("Stat", "")) != "Learn"), "no treino para o nível 4, nada a aprender")
	bento.level = 4
	learn = AHHeroLevels.options(bento).filter(func(o): return String(o.get("Stat", "")) == "Learn")
	t.check(learn.size() == 2 and learn.all(func(o): return int(o.Fragments) == 2), "no treino para o 5, os 2 que faltam, por 2 fragmentos")
	t.check(AHHeroLevels.options(bento).any(func(o): return String(o.get("Stat", "")) != "Learn"), "as melhorias de sempre continuam como opção")
	# Quem escolhe uma melhoria no nível 5 não perde a vaga: ela continua no treino seguinte.
	var other: Dictionary = AHHeroLevels.options(bento).filter(func(o): return String(o.get("Stat", "")) != "Learn")[0]
	t.equal(AHHeroLevels.train(c, BENTO, String(other.Name)), "", "no nível 5, escolhe uma melhoria")
	learn = AHHeroLevels.options(bento).filter(func(o): return String(o.get("Stat", "")) == "Learn")
	t.check(learn.size() == 2, "a vaga continua no treino para o nível 6")
	t.equal(AHHeroSkills.requirement(bento), "Nível 6 · Treino · +2 fragmentos", "e o requisito diz quando e quanto")
	# No nível máximo, a vaga que sobrou continua: o Treino ensina pelos fragmentos e pelas sementes de um nível (#299),
	# sem subir de nível.
	var tc: Dictionary = _campaign(2603)
	var top: Dictionary = S.hero(tc, "hero_gato_nick")
	top.level = AHHeroLevels.MAX_LEVEL
	top.xp = 0
	tc.inventory.fragments = 1
	var level_seeds: int = int(GameData.row("hero_levels", "level_%d" % AHHeroLevels.MAX_LEVEL).Seeds)
	t.equal(AHHeroSkills.max_level_seeds(), level_seeds, "no nível 10, aprender custa as sementes de um nível (as do nível 10)")
	t.equal(AHHeroSkills.requirement(top), "Treino · +1 fragmento · %d sementes" % level_seeds, "no nível 10, o requisito não pede um nível que não existe e diz as sementes")
	learn = AHHeroLevels.options(top)
	t.check(learn.size() == 3 and learn.all(func(o): return String(o.get("Stat", "")) == "Learn"), "no nível 10, o Treino só ensina")
	# Sem as sementes, não aprende e nada é gasto.
	tc.inventory.seeds = level_seeds - 1
	t.equal(AHHeroLevels.train(tc, String(top.id), AHHeroSkills.LEARN + "gato_rasgo_rapido"), TranslationServer.translate("Sementes insuficientes para o treino."),
		"no nível 10, sem as sementes de um nível, não aprende")
	t.check(S.quantity(tc, "seeds") == level_seeds - 1 and S.quantity(tc, "fragments") == 1 and Array(top.get("unlocked", [])).is_empty(), "e nada é gasto")
	tc.inventory.seeds = level_seeds + 2
	t.equal(AHHeroLevels.train(tc, String(top.id), AHHeroSkills.LEARN + "gato_rasgo_rapido"), "", "aprende no nível 10")
	t.check(AHHeroLevels.level(top) == AHHeroLevels.MAX_LEVEL and S.quantity(tc, "seeds") == 2 and S.quantity(tc, "fragments") == 0,
		"sem subir de nível: gasta o fragmento e as sementes de um nível")
	# Adiar não sai mais barato: aprender no nível 10 custa o mesmo que o nível 10 em sementes.
	t.check(AHHeroSkills.max_level_seeds() >= int(GameData.row("hero_levels", "level_%d" % (AHHeroLevels.MAX_LEVEL - 1)).Seeds), "o custo do nível 10 não é menor que o de um nível antes")
	tc.inventory.seeds = 50
	t.check(AHHeroLevels.train(tc, String(top.id), AHHeroSkills.LEARN + "gato_rasgo_rapido").contains("já foi aprendida"), "aprender de novo diz o motivo")
	t.check(not AHHeroSkills.learned_notice(top, "gato_rasgo_rapido", false).contains("nível"), "e o aviso não fala de subir de nível")
	var notice := AHHeroSkills.learned_notice(bento, "cao_ombro_de_carga")
	t.check(notice.contains("Ombro de Carga") and notice.contains("Sala"), "o aviso de aprender diz a habilidade e onde escolher (%s)" % notice)
	# Os recrutados seguem a mesma regra.
	var raccoon := _hero(c, "rato")
	raccoon.level = 2
	raccoon.xp = 99999
	t.equal(AHHeroLevels.options(raccoon).filter(func(o): return String(o.get("Stat", "")) == "Learn").map(func(o): return o.AbilityId),
		AHHeroSkills.unlocks("rato"), "o recrutado aprende pela mesma regra")


## As 4 da luta: trocadas na Estação, fora da expedição, só com as que sabe e cobrindo as posições.
func _choose() -> void:
	var c := _campaign(2593)
	var bento: Dictionary = S.hero(c, BENTO)
	bento.level = 7
	bento.unlocked = AHHeroSkills.unlocks("cao")
	var pick := ["cao_punho_sucata", "cao_impacto_hidraulico", "cao_ombro_de_carga", "cao_postura_firme"]
	t.equal(AHHeroSkills.choose(c, BENTO, pick), "", "troca as que leva")
	t.equal(AHHeroSkills.equipped(bento), pick, "e a luta leva a escolha, na ordem do catálogo")
	t.check(AHHeroSkills.choose(c, BENTO, ["cao_punho_sucata", "cao_punho_sucata", "cao_postura_firme", "cao_ombro_de_carga"]) != "", "repetida, não")
	t.check(AHHeroSkills.choose(c, BENTO, ["gato_corte_fase", "cao_impacto_hidraulico", "cao_postura_firme", "cao_ombro_de_carga"]) != "", "de outra classe, não")
	t.check(AHHeroSkills.choose(c, BENTO, pick.slice(0, 3)) != "", "menos de 4, não")
	var gap := ["cao_punho_sucata", "cao_fique_atras_de_mim", "cao_ombro_de_carga", "cao_alerta_de_perigo"]
	t.equal(AHHeroSkills.choose(c, BENTO, gap), "Sem ataque da posição 3.", "deixar a posição 3 sem ataque, não")
	var support := ["cao_fique_atras_de_mim", "cao_nao_estamos_sos", "cao_postura_firme", "cao_alerta_de_perigo"]
	t.check(AHHeroSkills.choose(c, BENTO, support) != "", "só apoio, sem ataque nenhum, não")
	t.equal(AHHeroSkills.equipped(bento), pick, "e a escolha de antes fica")
	t.equal(AHHeroSkills.choose(c, BENTO, AHHeroSkills.base("cao")), "", "voltar para as 4 de base")
	t.equal(bento.loadout, [], "volta ao padrão (o loadout vazio)")
	var fresh := _hero(c, "tatu")
	t.check(AHHeroSkills.choose(c, fresh.id, ["tatu_pancada", "tatu_enrolar", "tatu_investida", "tatu_avanco_de_resgate"]) != "", "um desbloqueio que ainda não sabe, não")
	c.session.expedition = {"id": "test"}
	t.check(AHHeroSkills.choose(c, BENTO, pick) != "", "na expedição, não troca")


## A luta usa as 4 que ele leva; com o loadout vazio, as 4 de base, como sempre.
func _combat() -> void:
	var c := _campaign(2594)
	var bento: Dictionary = S.hero(c, BENTO)
	var founder := AHCombatSession.create([bento], ["robot"], false, 7)
	var unit = founder.state.find_unit("unit_" + BENTO)
	t.equal(unit.ability_ids, [], "o fundador de loadout vazio não leva lista: a luta é a de sempre")
	t.equal(founder.engine.abilities_of(unit), AHHeroSkills.base("cao"), "e usa as 4 de base")
	bento.level = 7
	bento.unlocked = AHHeroSkills.unlocks("cao")
	AHHeroSkills.choose(c, BENTO, ["cao_punho_sucata", "cao_impacto_hidraulico", "cao_ombro_de_carga", "cao_postura_firme"])
	var session := AHCombatSession.create([bento], ["robot"], false, 7)
	var ids: Array = session.ability_options("unit_" + BENTO).map(func(o): return o.id)
	t.equal(ids, AHHeroSkills.equipped(bento), "na luta, as opções são as que ele leva")
	# A Ampola fora da luta só com ela equipada.
	var iris: Dictionary = S.hero(c, "hero_sapo_iris")
	iris.level = 7
	iris.unlocked = AHHeroSkills.unlocks("sapo")
	S.confirm_departure(c, ["hero_cao_bento", "hero_gato_nick", "hero_sapo_iris", "hero_coruja_vespera"], 0, 1, "fase_1")
	t.check(AHExplorationCare.iris(c) != null, "a Íris com a Ampola cura fora da luta")
	c.session.expedition = null
	AHHeroSkills.choose(c, "hero_sapo_iris", ["sapo_carga_voltaica", "sapo_coquetel_corrosivo", "sapo_antidoto_campo", "sapo_curativo_rapido"])
	S.confirm_departure(c, ["hero_cao_bento", "hero_gato_nick", "hero_sapo_iris", "hero_coruja_vespera"], 0, 2, "fase_1")
	t.equal(AHExplorationCare.iris(c), null, "sem a Ampola entre as 4, ninguém cura fora da luta")


## Lutas automáticas: cada classe, com cada combinação de 4 que a Sala aceita, numa equipe de quatro dela; todas terminam
## sem erro, e os 18 desbloqueios entram em ação.
func _auto_fights() -> void:
	var c := _campaign(2595)
	var used := {}
	var fights := 0
	var broken: Array = []
	for class_id in CLASSES:
		var hero := _hero(c, class_id)
		hero.level = 7
		hero.unlocked = AHHeroSkills.unlocks(class_id)
		for combo in _combinations(AHHeroSkills.catalog(class_id), 4):
			if AHHeroSkills.invalid(hero, combo) != "":
				continue
			var team: Array = []
			for index in 4:
				var copy: Dictionary = hero.duplicate(true)
				copy.id = "%s_%d" % [hero.id, index]
				copy.loadout = combo.duplicate()
				team.append(copy)
			var session := AHCombatSession.create(team, ["robot", "robot_fungo"], false, 100 + fights)
			var beats := 0
			while not session.is_over() and beats < 1500:
				var beat: Dictionary = session.auto_player_turn() if session.is_player_turn() else session.enemy_turn()
				if String(beat.get("ability_id", "")) != "":
					used[beat.ability_id] = true
				beats += 1
			if not session.is_over():
				broken.append(combo)
			fights += 1
	t.equal(broken, [], "as %d lutas automáticas terminam" % fights)
	var unused: Array = []
	for class_id in CLASSES:
		for id in AHHeroSkills.unlocks(class_id):
			if not used.has(id):
				unused.append(id)
	t.equal(unused, [], "os 18 desbloqueios entram em ação nas lutas automáticas")
	t.note("%d lutas automáticas" % fights)


## O save: guarda o que aprendeu e o que leva; o save de antes abre com as 4 de base; o editado volta ao que vale; a
## formação com alguém sem ataque da posição troca de ordem.
func _save() -> void:
	var c := _campaign(2596)
	var bento: Dictionary = S.hero(c, BENTO)
	bento.level = 5
	bento.unlocked = ["cao_postura_firme", "cao_ombro_de_carga"]
	var pick := ["cao_punho_sucata", "cao_impacto_hidraulico", "cao_ombro_de_carga", "cao_postura_firme"]
	AHHeroSkills.choose(c, BENTO, pick)
	var back = Campaign._normalize(JSON.parse_string(JSON.stringify(c)))
	S.migrate(back)
	var again = S.hero(back, BENTO)
	t.check(again.unlocked == bento.unlocked and AHHeroSkills.equipped(again) == pick, "o save guarda o que aprendeu e o que leva")
	var old := _campaign(2597)
	for entry in old.roster:
		entry.erase("unlocked")
		entry.erase("loadout")
	var reopened = Campaign._normalize(JSON.parse_string(JSON.stringify(old)))
	S.migrate(reopened)
	t.check(reopened.roster.all(func(e): return e.unlocked == [] and e.loadout == [] and AHHeroSkills.equipped(e) == AHHeroSkills.base(e.class_id)),
		"o save de antes abre com as 4 de base, sem perder nada")
	# O save editado.
	var bad_cases := [[5], [null], ["bogus"], ["gato_corte_fase"], ["cao_postura_firme", "cao_postura_firme"], AHHeroSkills.unlocks("cao")]
	for bad in bad_cases:
		var edited := _campaign(2598)
		var dog: Dictionary = S.hero(edited, BENTO)
		dog.level = 3
		dog.unlocked = bad
		var opened = Campaign._normalize(JSON.parse_string(JSON.stringify(edited)))
		S.migrate(opened)
		var fixed = S.hero(opened, BENTO)
		# No nível 3 cabe 1: o primeiro que vale, na ordem do save.
		var expected: Array = ["cao_ombro_de_carga"] if bad == AHHeroSkills.unlocks("cao") else (["cao_postura_firme"] if bad.has("cao_postura_firme") else [])
		t.equal(fixed.unlocked, expected, "unlocked editado volta ao que vale no nível 3 (%s)" % [bad])
	var gap := _campaign(2599)
	var dog2: Dictionary = S.hero(gap, BENTO)
	dog2.level = 7
	dog2.unlocked = AHHeroSkills.unlocks("cao")
	dog2.loadout = ["cao_punho_sucata", "cao_fique_atras_de_mim", "cao_ombro_de_carga", "cao_alerta_de_perigo"]
	var gapped = Campaign._normalize(JSON.parse_string(JSON.stringify(gap)))
	S.migrate(gapped)
	t.equal(S.hero(gapped, BENTO).loadout, [], "o loadout editado que deixa a posição 4 sem nada volta para as 4 de base")
	# A formação: com a regra, a coruja com desbloqueios parte de qualquer posição, até a da frente.
	var formed := _campaign(2600)
	var owl: Dictionary = S.hero(formed, "hero_coruja_vespera")
	owl.level = 7
	owl.unlocked = AHHeroSkills.unlocks("coruja")
	t.equal(AHHeroSkills.choose(formed, owl.id, ["coruja_disparo_perfurante", "coruja_olho_nas_ruinas", "coruja_tiro_de_aviso", "coruja_posicao_elevada"]), "", "a coruja leva o Tiro de Aviso")
	t.check(AHHeroSkills.choose(formed, owl.id, ["coruja_disparo_perfurante", "coruja_olho_nas_ruinas", "coruja_mira_no_marcado", "coruja_posicao_elevada"]) != "",
		"mas não fica sem ataque da frente")
	formed.preferred_formation = ["hero_coruja_vespera", "hero_cao_bento", "hero_gato_nick", "hero_sapo_iris"]
	t.equal(S.confirm_departure(formed.duplicate(true), formed.preferred_formation, 0, 1, "fase_1"), "", "a coruja na frente parte")


## Na Sala: as 7 com o estado (na luta, na Estação, bloqueada); a troca pela que fica vale; a que deixaria uma posição
## sem nada fica apagada, com o motivo; o Treino mostra as de aprender, com o preço em fragmentos.
func _screen() -> void:
	var real_state: Dictionary = Campaign.state
	var real_dir: String = Campaign.save_dir
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-hero-skills-%d" % Time.get_ticks_usec()
	var c := _campaign(2601)
	var bento: Dictionary = S.hero(c, BENTO)
	bento.level = 5
	bento.unlocked = ["cao_postura_firme", "cao_ombro_de_carga"]
	var nick: Dictionary = S.hero(c, "hero_gato_nick")
	nick.level = 2
	nick.xp = 99999
	c.inventory.fragments = 0
	c.station.last_return = {}
	Campaign.state = c
	GameFlow.change_to("station", {}, false)
	var station: AHStation = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene is AHStation and frame > 3:
			station = _tree.current_scene
			break
	if t.check(station != null, "a Estação abriu"):
		var hud: AHRefugeHud = station.hud
		hud.open_room(S.CHARACTERS)
		await _frames(4)
		var screen: AHCharacterRoom = hud._room_screen
		screen.selected = BENTO
		screen.ability = "cao_fique_atras_de_mim"
		screen.rebuild()
		await _frames(3)
		var rows: Array = screen.find_children("Ability_*", "Button", true, false)
		t.equal(rows.size(), 7, "a Sala mostra as 7 da classe")
		var states := {}
		for row in rows:
			states[String(row.get_meta("state", ""))] = int(states.get(String(row.get_meta("state", "")), 0)) + 1
		t.equal(states, {"equipped": 4, "resting": 2, "locked": 1}, "4 na luta, 2 na Estação e 1 bloqueada")
		var faro: Button = screen.find_child("Ability_cao_alerta_de_perigo", true, false)
		t.check(faro != null and faro.text.contains(tr("bloqueada")), "a bloqueada diz que está bloqueada (%s)" % (faro.text if faro else ""))
		var swap: Button = screen.find_child("Swap_cao_postura_firme", true, false)
		if t.check(swap != null and not swap.disabled, "a que vai mostra Trocar por, com as que ficam"):
			swap.pressed.emit()
			await _frames(4)
		t.check(AHHeroSkills.equipped(S.hero(Campaign.state, BENTO)).has("cao_postura_firme")
			and not AHHeroSkills.equipped(S.hero(Campaign.state, BENTO)).has("cao_fique_atras_de_mim"), "a troca pela Sala vale")
		# Com os 3 aprendidos.
		bento = S.hero(Campaign.state, BENTO)
		bento.level = 7
		bento.unlocked = AHHeroSkills.unlocks("cao")
		AHHeroSkills.choose(Campaign.state, BENTO, ["cao_punho_sucata", "cao_impacto_hidraulico", "cao_fique_atras_de_mim", "cao_ombro_de_carga"])
		screen = hud._room_screen
		screen.selected = BENTO
		screen.ability = "cao_impacto_hidraulico"
		screen.rebuild()
		await _frames(3)
		# O Impacto é o único ataque das posições 3 e 4: trocar por qualquer outra deixa a 3 sem ataque.
		var gap: Button = screen.find_child("Swap_cao_alerta_de_perigo", true, false)
		var reason: Label = screen.find_child("SwapBlocked", true, false)
		t.check(gap != null and gap.disabled and gap.tooltip_text.contains("posição 3"), "trocar o Impacto pelo Alerta deixa a 3 sem ataque: apagado")
		t.check(reason != null and reason.text.contains("posição 3"), "e o motivo fica à vista (%s)" % (reason.text if reason else ""))
		screen.ability = "cao_fique_atras_de_mim"
		screen.rebuild()
		await _frames(3)
		var fine: Button = screen.find_child("Swap_cao_postura_firme", true, false)
		t.check(fine != null and not fine.disabled, "trocar o Fique pelas Postura Firme vale (o Impacto continua)")
		# A que fica, apontada, entra no lugar de uma que vai.
		screen.ability = "cao_nao_estamos_sos"
		screen.rebuild()
		await _frames(3)
		t.check(screen.find_child("Replace_cao_punho_sucata", true, false) != null, "a que fica mostra Levar no lugar de")
		# O Treino do Nick para o nível 3: as de aprender, com o preço na cor de alerta (sem fragmentos).
		screen.selected = "hero_gato_nick"
		screen.training = true
		screen.rebuild()
		await _frames(4)
		var dialog: Control = screen.find_child("Training", true, false)
		var learn: Array = screen.find_children("Upgrade_learn_*", "Button", true, false)
		t.equal(learn.size(), 3, "o Treino mostra as 3 de aprender")
		if dialog != null:
			var rect := dialog.get_global_rect()
			t.check(rect.position.x >= 0.0 and rect.end.x <= 1920.0 and rect.end.y <= 1080.0, "o diálogo cabe na tela (%s)" % rect)
		var price: Label = learn[0].find_child("Price", true, false) if not learn.is_empty() else null
		t.check(price != null and price.text.contains("1 fragmento"), "com o preço em fragmentos")
		screen.training = false
		hud.close_panel()
		await _frames(3)
	_tree.unload_current_scene()
	await _tree.process_frame
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Tips.enabled = tips
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
