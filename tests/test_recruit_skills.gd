## Os recrutas (#189 e #215, decisões do Lucas de 28/10): o fundador fica com o kit da história (a paridade fica no
## test_combat_parity); o recruta tem habilidades próprias e mais fracas (rec_*): chega com 3 (o golpe, o Remendo e o
## toque da raça), ganha a 4ª no nível 2 e aprende a do fundador da espécie no Treino a partir do nível 4, pagando
## fragmentos (o Guaxinim e o Tatu, a de ofício); com 5, leva 4 para a luta e troca na Sala, fora da expedição.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const BENTO := "hero_cao_bento"
const FOUNDER_CAO := "cao_fique_atras_de_mim"

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_data()
	_balance()
	_levels()
	_training()
	_choose()
	_combat()
	_save()
	_old_saves()
	_ampoule()
	await _screen()


func _campaign(seed_value: int) -> Dictionary:
	var c: Dictionary = Campaign.create_initial(seed_value)
	c.station.rooms[S.CHARACTERS] = 4
	c.inventory.seeds = 500
	return c


func _recruit(c: Dictionary, class_id: String, level: int = 1) -> Dictionary:
	if not c.unlocked_classes.has(class_id):
		c.unlocked_classes.append(class_id)
	var made := S.recruit(c, class_id, RandomNumberGenerator.new(), "Teste")
	var hero = S.hero(c, String(made.get("hero_id", "")))
	hero.level = level
	return hero


## Um recruta com a do fundador aprendida (5 habilidades: leva 4).
func _veteran(c: Dictionary, class_id: String) -> Dictionary:
	var hero := _recruit(c, class_id, 4)
	hero.learned = [AHRecruitSkills.founder_ability(class_id)]
	return hero


## data/recruit-skills.json: cada classe com 3 da raça na chegada, a 4ª e a do fundador (do kit da classe), e quem ensina.
func _data() -> void:
	for class_id in GameData.table("classes"):
		var row := AHRecruitSkills.race(class_id)
		if not t.check(not row.is_empty(), "%s: tem as habilidades de recruta" % class_id):
			continue
		var kit: Array = row.get("Kit", [])
		t.check(kit.size() == 3 and kit.all(func(id): return GameData.row("abilities", id) != null), "%s: chega com 3 que existem" % class_id)
		t.check(kit.any(func(id): return int(GameData.row("abilities", id).DamageRange.Max) > 0), "%s: uma delas ataca" % class_id)
		t.check(kit.has("rec_remendo"), "%s: e o Remendo, a cura pequena em si" % class_id)
		var level2 = GameData.row("abilities", String(row.get("Level2", "")))
		t.check(level2 != null and not kit.has(row.Level2), "%s: a 4ª, no nível 2" % class_id)
		var own: Array = kit + [String(row.Level2)]
		t.check(own.all(func(id): return String(id).begins_with("rec_")), "%s: as da raça são próprias, não cópias das do fundador" % class_id)
		t.check(AHRecruitSkills.class_abilities(class_id).has(AHRecruitSkills.founder_ability(class_id)), "%s: a do Treino é do kit da classe" % class_id)
		var teacher := String(row.get("Teacher", ""))
		if teacher == "":
			t.check(["rato", "tatu"].has(class_id), "%s: sem fundador da espécie, a de ofício" % class_id)
		else:
			t.check(String(GameData.row("initial_heroes", teacher).get("ClassId", "")) == class_id, "%s: ensinada pelo fundador da espécie" % class_id)
	t.equal(AHRecruitSkills.teacher_name("cao"), "Bento", "o nome de quem ensina vem dos dados")
	for row in GameData.table("abilities").values():
		if String(row.Name).begins_with("rec_"):
			var art_of := String(row.get("ArtOf", ""))
			t.check(GameData.row("abilities", art_of) != null and AHCombatArena.icon_of(row.Name) != "", "%s: usa a arte de %s" % [row.Name, art_of])


## O equilíbrio (o recruta mais básico que o fundador): o dano médio de cada habilidade do recruta abaixo do melhor golpe
## do kit da classe, a cura abaixo da Ampola e nenhum atordoamento.
func _balance() -> void:
	var ampola = GameData.row("abilities", "sapo_ampola_reparo_vivo")
	for class_id in GameData.table("classes"):
		var best := 0.0
		for id in AHRecruitSkills.class_abilities(class_id):
			var damage: Dictionary = GameData.row("abilities", id).get("DamageRange", {})
			best = maxf(best, (float(damage.get("Min", 0)) + float(damage.get("Max", 0))) * 0.5)
		var row := AHRecruitSkills.race(class_id)
		for id in Array(row.get("Kit", [])) + [String(row.get("Level2", ""))]:
			var data = GameData.row("abilities", id)
			var damage: Dictionary = data.get("DamageRange", {})
			var average := (float(damage.get("Min", 0)) + float(damage.get("Max", 0))) * 0.5
			t.check(average < best, "%s: %s faz menos que o melhor golpe da classe (%.1f, %.1f)" % [class_id, id, average, best])
			t.check(int(data.get("HealRange", {}).get("Max", 0)) < int(ampola.HealRange.Min), "%s: %s cura menos que a Ampola" % [class_id, id])
			t.equal(int(data.get("Inflicts", {}).get("Stun", 0)), 0, "%s: %s não atordoa" % [class_id, id])


## Os níveis: 3 na chegada, 4 no nível 2; o fundador com o kit da classe.
func _levels() -> void:
	var c := _campaign(1891)
	var fresh := _recruit(c, "gato")
	t.equal(AHRecruitSkills.known(fresh), AHRecruitSkills.race("gato").Kit, "o recruta chega com as 3 da raça")
	t.equal(AHRecruitSkills.abilities(fresh), AHRecruitSkills.race("gato").Kit, "e luta com elas")
	fresh.level = 2
	t.check(AHRecruitSkills.abilities(fresh).has("rec_gato_bote") and AHRecruitSkills.abilities(fresh).size() == 4, "no nível 2, a 4ª")
	t.equal(AHRecruitSkills.abilities(S.hero(c, BENTO)), AHRecruitSkills.class_abilities("cao"), "o fundador, o kit da classe")
	t.check(S.attacks_from_rank("gato", 1, AHRecruitSkills.abilities(fresh)).size() > 0, "o recruta ataca da posição dele")


## O Treino: a partir do nível 4, aprender com o fundador é uma opção a mais, que custa fragmentos além do nível.
func _training() -> void:
	var c := _campaign(1892)
	var recruit := _recruit(c, "cao", 2)
	recruit.xp = 9999
	t.check(not AHHeroLevels.options(recruit).any(func(o): return o.Name == AHRecruitSkills.LEARN), "antes do nível 4, não aparece")
	recruit.level = 3
	var learn: Array = AHHeroLevels.options(recruit).filter(func(o): return o.Name == AHRecruitSkills.LEARN)
	if not t.check(learn.size() == 1 and learn[0].AbilityId == FOUNDER_CAO, "no treino para o nível 4, aprender com o Bento"):
		return
	t.check(String(learn[0].DisplayName).contains("Bento"), "a opção diz com quem (%s)" % learn[0].DisplayName)
	var fragments := int(AHRecruitSkills.rule("FounderFragments", 3))
	c.inventory.fragments = fragments - 1
	t.check(AHHeroLevels.train(c, recruit.id, AHRecruitSkills.LEARN) != "" and AHHeroLevels.level(recruit) == 3, "sem os fragmentos, não aprende")
	c.inventory.fragments = fragments + 2
	var seeds := S.quantity(c, "seeds")
	t.equal(AHHeroLevels.train(c, recruit.id, AHRecruitSkills.LEARN), "", "com os fragmentos, aprende")
	t.check(AHHeroLevels.level(recruit) == 4 and recruit.learned.has(FOUNDER_CAO), "sobe o nível e sabe a do fundador")
	t.equal(S.quantity(c, "fragments"), 2, "gasta os fragmentos")
	t.check(S.quantity(c, "seeds") < seeds, "e as sementes do nível")
	t.check(not AHHeroLevels.options(recruit).any(func(o): return o.Name == AHRecruitSkills.LEARN), "aprendida, a opção some")
	var bruiser := _recruit(c, "tatu", 3)
	var trade: Array = AHHeroLevels.options(bruiser).filter(func(o): return o.Name == AHRecruitSkills.LEARN)
	t.check(trade.size() == 1 and trade[0].AbilityId == "tatu_pancada", "o Tatu aprende a de ofício")
	var scout := _recruit(c, "gato", 2)
	t.check(not AHHeroLevels.options(scout).any(func(o): return String(o.get("Stat", "")) == "Ability"), "o recruta não recebe a melhoria de uma habilidade do fundador")


## Com 5, leva 4: troca na Estação, fora da expedição; o fundador não troca.
func _choose() -> void:
	var c := _campaign(1893)
	var vet := _veteran(c, "cao")
	t.equal(AHRecruitSkills.known(vet).size(), 5, "com a do fundador, sabe 5")
	t.equal(AHRecruitSkills.abilities(vet).size(), 4, "e leva 4")
	var pick: Array = [FOUNDER_CAO, "rec_cao_patada", "rec_remendo", "rec_cao_empurrao"]
	t.equal(AHRecruitSkills.choose(c, vet.id, pick), "", "troca a que leva")
	t.check(AHRecruitSkills.abilities(vet).has(FOUNDER_CAO) and not AHRecruitSkills.abilities(vet).has("rec_cao_escudo_lata"), "e a luta leva a escolha")
	t.check(AHRecruitSkills.choose(c, vet.id, [FOUNDER_CAO, FOUNDER_CAO, "rec_remendo", "rec_cao_patada"]) != "", "repetida, não")
	t.check(AHRecruitSkills.choose(c, vet.id, ["gato_corte_fase", "rec_cao_patada", "rec_remendo", "rec_cao_empurrao"]) != "", "uma que não sabe, não")
	t.check(AHRecruitSkills.choose(c, BENTO, pick) != "", "o fundador não troca")
	c.session.expedition = {"id": "test"}
	t.check(AHRecruitSkills.choose(c, vet.id, pick) != "", "na expedição, não troca")


## A luta usa as que o recruta leva; o fundador, o kit da classe.
func _combat() -> void:
	var c := _campaign(1894)
	var vet := _veteran(c, "cao")
	AHRecruitSkills.choose(c, vet.id, [FOUNDER_CAO, "rec_cao_patada", "rec_remendo", "rec_cao_empurrao"])
	Campaign.state = c
	var session := AHCombatSession.create([vet], ["robot"], false, 7)
	var unit_id := "unit_" + String(vet.id)
	var ids: Array = session.ability_options(unit_id).map(func(o): return o.id)
	t.check(ids.has(FOUNDER_CAO) and not ids.has("rec_cao_escudo_lata") and not ids.has("cao_punho_sucata"), "na luta, as opções são as que ele leva (%s)" % [ids])
	t.equal(session.engine.abilities_of(session.state.find_unit(unit_id)), AHRecruitSkills.abilities(vet), "e o motor também")
	var founder_session := AHCombatSession.create([S.hero(c, BENTO)], ["robot"], false, 7)
	t.equal(founder_session.engine.abilities_of(founder_session.state.find_unit("unit_" + BENTO)), AHRecruitSkills.class_abilities("cao"), "o fundador luta com o kit da classe")


## O save: guarda a escolha e o que aprendeu; o save de antes abre sem nada (e o recruta com as da raça).
func _save() -> void:
	var c := _campaign(1895)
	var vet := _veteran(c, "sapo")
	var pick: Array = AHRecruitSkills.known(vet).slice(1, 5)
	AHRecruitSkills.choose(c, vet.id, pick)
	var back = Campaign._normalize(JSON.parse_string(JSON.stringify(c)))
	S.migrate(back)
	var again = S.hero(back, vet.id)
	t.check(again.learned == vet.learned and AHRecruitSkills.abilities(again) == AHRecruitSkills.abilities(vet), "o save guarda a escolha e o que aprendeu")
	var old: Dictionary = _campaign(1896)
	var old_recruit := _recruit(old, "coruja")
	for key in ["loadout", "learned"]:
		old_recruit.erase(key)
	var reopened = Campaign._normalize(JSON.parse_string(JSON.stringify(old)))
	S.migrate(reopened)
	var migrated = S.hero(reopened, old_recruit.id)
	t.check(migrated.loadout == [] and migrated.learned == [] and AHRecruitSkills.abilities(migrated) == AHRecruitSkills.race("coruja").Kit,
		"o recruta de antes abre com as da raça")
	migrated.loadout = ["gato_corte_fase", "rec_remendo", "rec_coruja_bicada", "rec_coruja_estilingue"]
	S.migrate(reopened)
	t.equal(migrated.loadout, [], "uma escolha que não vale (um save editado) volta ao padrão ao abrir")


## A QA da #215: o save de antes e o editado não perdem nem inventam nada.
func _old_saves() -> void:
	# A "Mão treinada" que o gato recruta pagou para o Corte de Fase vale no Arranhão (que usa a arte dele).
	var c := _campaign(1898)
	var cat := _recruit(c, "gato", 3)
	cat.upgrades = ["habilidade_gato", "habilidade_gato"]
	for key in ["loadout", "learned"]:
		cat.erase(key)
	var back = Campaign._normalize(JSON.parse_string(JSON.stringify(c)))
	S.migrate(back)
	var again = S.hero(back, cat.id)
	t.equal(AHHeroLevels.combat_bonus(again).abilities, {"rec_gato_arranhao": 2}, "a Mão treinada de antes vale no Arranhão")
	var sheet: Array = AHCharacterSheet._hero_passives(again, [], "gato")
	var texts: String = " ".join(sheet.map(func(row): return "%s %s" % [row[0], row[1]]))
	t.check(texts.contains("Arranhão") and not texts.contains("Corte de Fase"), "a ficha diz onde ela vale (%s)" % texts)
	# A Pesquisa do Corte de Fase não aparece na ficha do recruta, que não o sabe.
	var real_state: Dictionary = Campaign.state
	back.researched_skills = ["gato_corte_fase"]
	Campaign.state = back
	sheet = AHCharacterSheet._hero_passives(again, [], "gato")
	t.check(not sheet.any(func(row): return String(row[0]).contains("Corte de Fase")), "nem o treino da Pesquisa que ele não usa")
	Campaign.state = real_state
	# O learned editado: só a do fundador da espécie, em texto.
	for bad in [[5], [null], ["bogus"], ["sapo_ampola_reparo_vivo"], ["cao_fique_atras_de_mim", "cao_fique_atras_de_mim"]]:
		var edited := _campaign(1899)
		var dog := _recruit(edited, "cao", 4)
		dog.learned = bad
		var race: Array = AHRecruitSkills.race("cao").Kit + [AHRecruitSkills.race("cao").Level2]
		t.equal(AHRecruitSkills.known(dog).slice(0, 4), race, "antes de abrir, não perde as da raça (%s)" % [bad])
		var reopened = Campaign._normalize(JSON.parse_string(JSON.stringify(edited)))
		S.migrate(reopened)
		var fixed = S.hero(reopened, dog.id)
		t.equal(fixed.learned, [FOUNDER_CAO] if bad.has(FOUNDER_CAO) else [], "o learned editado volta ao que vale (%s)" % [bad])
		t.equal(AHRecruitSkills.abilities(fixed).size(), 4, "e ele luta com 4 (%s)" % [bad])
	# A formação de antes com o recruta cão na posição 4: troca de ordem ao abrir, e a partida vale.
	var formed := _campaign(1900)
	var front := _recruit(formed, "cao")
	formed.preferred_formation = ["hero_cao_bento", "hero_gato_nick", "hero_sapo_iris", front.id]
	t.check(S.confirm_departure(formed.duplicate(true), formed.preferred_formation, 0, 1, "fase_1") != "", "antes: o cão recruta não ataca da posição 4")
	S.migrate(formed)
	t.equal(formed.preferred_formation.size(), 4, "a formação continua com os 4")
	t.equal(S.confirm_departure(formed.duplicate(true), formed.preferred_formation, 0, 1, "fase_1"), "", "depois de abrir, a formação parte (%s)" % [formed.preferred_formation])
	var valid: Array = formed.preferred_formation.duplicate()
	S.migrate(formed)
	t.equal(formed.preferred_formation, valid, "uma formação que vale não muda")
	# O aviso de aprender diz a habilidade e onde escolher.
	var learner := _recruit(_campaign(1901), "cao", 3)
	var notice := AHRecruitSkills.learned_notice(learner)
	t.check(notice.contains("nível 4") and notice.contains("Fique Atrás de Mim") and notice.contains("Sala"), "o aviso de aprender (%s)" % notice)


## A Ampola fora da luta é de quem a leva: o sapo recruta não conta como a Íris.
func _ampoule() -> void:
	var c := _campaign(1902)
	var frog := _recruit(c, "sapo")
	S.confirm_departure(c, [frog.id, "hero_cao_bento", "hero_gato_nick", "hero_coruja_vespera"], 0, 1, "fase_1")
	t.equal(AHExplorationCare.iris(c), null, "o sapo recruta sem a Ampola não cura fora da luta")
	t.equal(AHExplorationCare.ampoule_charges(c), 0, "e não tem cargas")


## Na Sala: o recruta mostra as que sabe e o que vem; com 5, a que fica na Estação e a troca.
func _screen() -> void:
	var real_state: Dictionary = Campaign.state
	var real_dir: String = Campaign.save_dir
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-recruit-skills-%d" % Time.get_ticks_usec()
	var c := _campaign(1897)
	var fresh := _recruit(c, "cao")
	var vet := _veteran(c, "cao")
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
		screen.selected = fresh.id
		screen.rebuild()
		await _frames(3)
		t.equal(screen.find_children("Ability_*", "Button", true, false).size(), 3, "o recém-chegado mostra as 3")
		var notes: Array = screen.find_child("SkillChoices", true, false).find_children("*", "Label", true, false).map(func(l): return l.text)
		t.check(notes.any(func(n): return n.contains("Empurrão")) and notes.any(func(n): return n.contains("Bento")), "e o que vem: a 4ª e a do Bento no Treino (%s)" % [notes])
		screen.selected = vet.id
		screen.ability = "rec_cao_patada"
		screen.rebuild()
		await _frames(3)
		# Sem escolha, leva as 4 primeiras: a do fundador, aprendida por último, fica na Estação.
		var resting: Button = screen.find_child("Ability_%s" % FOUNDER_CAO, true, false)
		t.check(resting != null and resting.text.contains(tr("fica na Estação")), "com 5, a que não vai para a luta diz que fica")
		t.check(resting != null and resting.text.contains("Bento"), "a do fundador diz de quem veio")
		var swap: Button = screen.find_child("Swap_%s" % FOUNDER_CAO, true, false)
		if t.check(swap != null, "a escolhida mostra Trocar por, com a que ficou"):
			swap.pressed.emit()
			await _frames(4)
		t.check(AHRecruitSkills.abilities(S.hero(Campaign.state, vet.id)).has(FOUNDER_CAO)
			and not AHRecruitSkills.abilities(S.hero(Campaign.state, vet.id)).has("rec_cao_patada"), "trocar pela Sala vale")
		# Pela que fica na Estação: "Levar no lugar de" e as que vão.
		screen = hud._room_screen
		screen.selected = vet.id
		screen.ability = "rec_cao_patada"
		screen.rebuild()
		await _frames(3)
		var replace: Button = screen.find_child("Replace_%s" % FOUNDER_CAO, true, false)
		if t.check(replace != null, "a que ficou mostra Levar no lugar de, com as que vão"):
			replace.pressed.emit()
			await _frames(4)
		t.check(AHRecruitSkills.abilities(S.hero(Campaign.state, vet.id)).has("rec_cao_patada"), "e trocar por ela também vale")
		screen = hud._room_screen
		screen.selected = BENTO
		screen.rebuild()
		await _frames(3)
		t.check(screen.find_child("SkillChoices", true, false) == null, "o fundador não tem escolhas")
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
