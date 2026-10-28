## Os recrutas flexíveis (#189): o fundador fica com o kit da história (a paridade fica no test_combat_parity); o
## recruta tem 2 fixas da classe e 2 escolhidas, das outras da classe ou das que aprendeu (o mentor, depois de
## MentorExpeditions expedições na mesma equipe, e a Pesquisa, "Ensinar a comunidade"); no máximo MaxForeign de fora;
## troca livre na Estação; a luta usa as que ele leva; a partida exige um ataque da posição; o save antigo abre com o
## kit da classe; e a Sala troca a habilidade.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const IRIS := "hero_sapo_iris"
const BENTO := "hero_cao_bento"
const AMPOLA := "sapo_ampola_reparo_vivo"

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_data()
	_rules()
	_mentor()
	_research()
	_combat()
	_save()
	await _screen()


func _campaign(seed_value: int) -> Dictionary:
	var c: Dictionary = Campaign.create_initial(seed_value)
	c.station.rooms[S.CHARACTERS] = 4
	c.inventory.seeds = 500
	return c


func _recruit(c: Dictionary, class_id: String) -> Dictionary:
	var made := S.recruit(c, class_id, RandomNumberGenerator.new(), "Teste")
	return S.hero(c, String(made.get("hero_id", "")))


## data/recruit-skills.json: cada classe com 2 fixas que são dela; o que cada fundador ensina é da classe dele.
func _data() -> void:
	for class_id in GameData.table("classes"):
		var fixed := AHRecruitSkills.fixed(class_id)
		var own := AHRecruitSkills.class_abilities(class_id)
		t.check(fixed.size() == 2 and fixed.all(func(id): return own.has(id)), "%s: 2 fixas da própria classe" % class_id)
		t.check(fixed.any(func(id): return GameData.row("abilities", id).get("DamageRange") != null), "%s: uma das fixas ataca" % class_id)
	for row in GameData.table("recruit_skills").values():
		if row.has("Teaches"):
			t.check(Array(row.Teaches).all(func(id): return AHRecruitSkills.class_abilities(String(row.Name)).has(id)) and S.hero(Campaign.create_initial(1), String(row.Mentor)) != null,
				"%s: o fundador ensina habilidades da classe dele" % row.Name)


## As regras: o fundador não muda; o recruta começa com o kit da classe; troca dentro das opções, com no máximo uma de fora.
func _rules() -> void:
	var c := _campaign(1891)
	var recruit := _recruit(c, "cao")
	if not t.check(recruit != null, "um recruta cão"):
		return
	t.equal(AHRecruitSkills.abilities(recruit), AHRecruitSkills.class_abilities("cao"), "o recruta começa com o kit da classe")
	t.equal(AHRecruitSkills.abilities(S.hero(c, BENTO)), AHRecruitSkills.class_abilities("cao"), "o fundador leva o kit da classe")
	t.check(AHRecruitSkills.choose(c, BENTO, ["cao_impacto_hidraulico", "cao_nao_estamos_sos"]) != "", "o fundador não troca")
	t.check(AHRecruitSkills.choose(c, recruit.id, [AMPOLA, "cao_nao_estamos_sos"]) != "", "não leva o que ainda não sabe")
	t.check(AHRecruitSkills.choose(c, recruit.id, ["cao_punho_sucata", "cao_nao_estamos_sos"]) != "", "a fixa não entra nas escolhas")
	t.check(AHRecruitSkills.choose(c, recruit.id, ["cao_nao_estamos_sos", "cao_nao_estamos_sos"]) != "", "nem a mesma duas vezes")
	recruit.learned = [AMPOLA, "sapo_antidoto_campo"]
	t.equal(AHRecruitSkills.choose(c, recruit.id, [AMPOLA, "cao_nao_estamos_sos"]), "", "aprendida, a de fora entra")
	var kit := AHRecruitSkills.abilities(recruit)
	t.check(kit.has(AMPOLA) and kit.has("cao_punho_sucata") and kit.has("cao_fique_atras_de_mim") and kit.size() == 4, "com as 2 fixas e as 2 escolhidas (%s)" % [kit])
	t.check(AHRecruitSkills.choose(c, recruit.id, [AMPOLA, "sapo_antidoto_campo"]) != "", "no máximo uma de fora")
	c.session.expedition = {"id": "x"}
	t.check(AHRecruitSkills.choose(c, recruit.id, ["cao_impacto_hidraulico", "cao_nao_estamos_sos"]) != "", "na expedição, não troca")
	c.session.expedition = null
	# A partida exige um ataque da posição: com a escolha de suporte, o cão segue atacando de 1 e 2 (a fixa).
	t.check(not S.attacks_from_rank("cao", 1, kit).is_empty(), "com a fixa de ataque, ele ataca da frente")


## O mentor: 2 expedições na mesma equipe com um fundador de outra classe ensinam a próxima habilidade dele.
func _mentor() -> void:
	var c := _campaign(1892)
	var recruit := _recruit(c, "cao")
	var team: Array = [recruit.id, IRIS, BENTO]
	var needed := int(AHRecruitSkills.rule("MentorExpeditions", 2))
	var learned: Array = []
	for i in needed - 1:
		learned = AHRecruitSkills.mentor_return(c, team)
	t.check(learned.is_empty() and int(recruit.mentor.get(IRIS, 0)) == needed - 1, "antes de completar, só conta")
	t.check(not recruit.mentor.has(BENTO), "o fundador da mesma classe não ensina")
	learned = AHRecruitSkills.mentor_return(c, team)
	t.check(learned.size() == 1 and learned[0].mentor_id == IRIS and recruit.learned.has(learned[0].ability_id), "completa a conta, aprende com a Íris (%s)" % [learned])
	t.equal(int(recruit.mentor.get(IRIS, -1)), 0, "e a conta recomeça para a próxima")
	t.check(AHRecruitSkills.options(c, recruit).has(String(learned[0].ability_id)), "a aprendida vira opção")
	t.check(AHRecruitSkills.mentor_return(c, [BENTO, IRIS]).is_empty(), "fundador não aprende")
	# Quem caiu também conta: a volta vale em qualquer resultado (o mentor caído ensina, o recruta caído aprende).
	var fallen := _recruit(c, "gato")
	fallen.alive = false
	AHRecruitSkills.mentor_return(c, [fallen.id, IRIS])
	t.equal(int(fallen.mentor.get(IRIS, 0)), 1, "o recruta caído conta a expedição")
	# De ponta a ponta: a volta (S.finish_return) ensina e o relatório mostra o chip.
	var d := _campaign(1898)
	var pupil := _recruit(d, "cao")
	pupil.mentor = {IRIS: needed - 1}
	var team2: Array = [pupil.id, IRIS, "hero_gato_nick"]
	t.equal(S.confirm_departure(d, team2, 0, 9, "fase_1"), "", "parte com o recruta e a Íris")
	d.session.expedition.loot = {}
	d.session.result = "retreat"
	var delivered: Dictionary = S.finish_return(d)
	var lessons: Array = delivered.get("learned", [])
	t.check(lessons.size() == 1 and lessons[0].hero_id == pupil.id and lessons[0].mentor_id == IRIS and pupil.learned.has(lessons[0].ability_id),
		"a volta ensina e o relatório guarda o que ele aprendeu (%s)" % [lessons])
	var report := AHStationReport.new()
	report.report = delivered
	var real_state: Dictionary = Campaign.state
	Campaign.state = d
	var chips: Array = report._chips(d, String(delivered.result))
	Campaign.state = real_state
	report.free()
	t.check(chips.any(func(chip): return String(chip.text).contains(String(pupil.display_name)) and String(chip.text).contains("Íris")),
		"o relatório da volta mostra o chip do que ele aprendeu")


## A Pesquisa: o nó de um fundador ensina todas as dele aos recrutas de outras classes.
func _research() -> void:
	var c := _campaign(1893)
	var recruit := _recruit(c, "gato")
	t.check(not AHRecruitSkills.options(c, recruit).has(AMPOLA), "sem a Pesquisa, a Ampola não está nas opções")
	c.station.rooms[S.RESEARCH] = 1
	c.inventory.fragments = 20
	t.equal(S.research(c, "res_teach_sapo"), "", "pesquisa Ensinar a comunidade: Íris")
	t.check(AHRecruitSkills.options(c, recruit).has(AMPOLA) and AHRecruitSkills.options(c, recruit).has("sapo_antidoto_campo"), "e o recruta pode levar as dela")
	# O nó ensina os de outras classes: não é treino da classe na ficha (nem da Íris, nem de um recruta sapo).
	var frog := _recruit(c, "sapo")
	var real_state: Dictionary = Campaign.state
	Campaign.state = c
	var passives: Array = AHCharacterSheet._hero_passives(S.hero(c, IRIS), [], "sapo") + AHCharacterSheet._hero_passives(frog, [], "sapo")
	Campaign.state = real_state
	t.check(not passives.any(func(p): return String(p[0]).contains("Ensinar")), "a ficha não lista o nó como treino da classe (%s)" % [passives])


## A luta usa as que o recruta leva; a que ele não leva não sai.
func _combat() -> void:
	var c := _campaign(1894)
	var recruit := _recruit(c, "cao")
	recruit.learned = [AMPOLA]
	AHRecruitSkills.choose(c, recruit.id, [AMPOLA, "cao_nao_estamos_sos"])
	Campaign.state = c
	var session := AHCombatSession.create([recruit], ["robot"], false, 7)
	var unit_id := "unit_" + String(recruit.id)
	var ids: Array = session.ability_options(unit_id).map(func(o): return o.id)
	t.check(ids.has(AMPOLA) and not ids.has("cao_impacto_hidraulico"), "na luta, as opções são as que ele leva (%s)" % [ids])
	t.equal(session.engine.abilities_of(session.state.find_unit(unit_id)), AHRecruitSkills.abilities(recruit), "e o motor também")
	var founder_session := AHCombatSession.create([S.hero(c, BENTO)], ["robot"], false, 7)
	t.equal(founder_session.engine.abilities_of(founder_session.state.find_unit("unit_" + BENTO)), AHRecruitSkills.class_abilities("cao"), "o fundador luta com o kit da classe")


## O save: guarda a escolha, o que aprendeu e a conta; o save antigo abre com o kit da classe.
func _save() -> void:
	var c := _campaign(1895)
	var recruit := _recruit(c, "cao")
	recruit.learned = [AMPOLA]
	recruit.mentor = {IRIS: 1}
	AHRecruitSkills.choose(c, recruit.id, [AMPOLA, "cao_nao_estamos_sos"])
	var back = Campaign._normalize(JSON.parse_string(JSON.stringify(c)))
	S.migrate(back)
	var again = S.hero(back, recruit.id)
	t.check(again.loadout == recruit.loadout and again.learned == [AMPOLA] and int(again.mentor.get(IRIS, 0)) == 1, "o save guarda a escolha, o que aprendeu e a conta")
	var old: Dictionary = _campaign(1896)
	var old_recruit := _recruit(old, "sapo")
	for key in ["loadout", "learned", "mentor"]:
		old_recruit.erase(key)
	var reopened = Campaign._normalize(JSON.parse_string(JSON.stringify(old)))
	S.migrate(reopened)
	var migrated = S.hero(reopened, old_recruit.id)
	t.check(migrated.loadout == [] and migrated.learned == [] and AHRecruitSkills.abilities(migrated) == AHRecruitSkills.class_abilities("sapo"),
		"o recruta de antes abre com o kit da classe, sem perder nada")


## Na Sala dos Personagens: o recruta mostra as que leva, a escolhida se troca, a fixa não.
func _screen() -> void:
	var real_state: Dictionary = Campaign.state
	var real_dir: String = Campaign.save_dir
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-recruit-skills-%d" % Time.get_ticks_usec()
	var c := _campaign(1897)
	var recruit := _recruit(c, "cao")
	recruit.learned = [AMPOLA]
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
		screen.selected = recruit.id
		screen.ability = "cao_impacto_hidraulico"
		screen.rebuild()
		await _frames(3)
		var swap: Button = screen.find_child("Swap_%s" % AMPOLA, true, false)
		if t.check(swap != null, "a escolhida mostra Trocar por, com a Ampola que ele aprendeu"):
			swap.pressed.emit()
			await _frames(4)
		t.check(AHRecruitSkills.abilities(S.hero(Campaign.state, recruit.id)).has(AMPOLA), "trocar pela Sala vale")
		t.check(hud._room_screen.find_child("Ability_%s" % AMPOLA, true, false) != null, "e a lista mostra a nova")
		# Já com uma de fora (MaxForeign 1): no outro lugar escolhido, a outra de fora não aparece (falharia).
		S.hero(Campaign.state, recruit.id).learned.append("gato_sumir_na_sombra")
		screen = hud._room_screen
		screen.ability = "cao_nao_estamos_sos"
		screen.rebuild()
		await _frames(3)
		t.check(screen.find_child("Swap_gato_sumir_na_sombra", true, false) == null and screen.find_child("Swap_cao_impacto_hidraulico", true, false) != null,
			"com uma de fora já escolhida, a Sala só oferece as que valem")
		screen.ability = AMPOLA
		screen.rebuild()
		await _frames(3)
		t.check(screen.find_child("Swap_gato_sumir_na_sombra", true, false) != null, "no lugar da de fora, a outra de fora entra")
		screen.ability = "cao_punho_sucata"
		screen.rebuild()
		await _frames(3)
		t.check(screen.find_children("Swap_*", "Button", true, false).is_empty(), "a fixa não se troca")
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
