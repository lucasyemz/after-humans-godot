## O nível dos heróis (#90): o XP da luta e da jornada, o Treino (XP do nível e sementes, uma de duas melhorias da
## espécie), o limite no 10, o que o nível soma na luta (sem mudar a paridade), o save e a migração do save antigo, e o
## Alojamento com o XP e o Treino.
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")
const J := preload("res://scripts/flow/journey_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-levels-%d" % Time.get_ticks_usec()
	var tips: bool = Tips.enabled
	Tips.enabled = false
	_tables()
	_training()
	_combat()
	_xp_from_play()
	_save_and_migration()
	await _lodging()
	Tips.enabled = tips
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state


## As tabelas: os níveis do 2 ao 10 e duas melhorias para cada classe.
func _tables() -> void:
	for level in range(2, 11):
		var row = GameData.row("hero_levels", "level_%d" % level)
		t.check(row != null and int(row.Xp) > 0 and int(row.Seeds) > 0, "o nível %d tem XP e sementes" % level)
	for hero_class in GameData.table("classes").values():
		var count: int = GameData.table("hero_upgrades").values().filter(func(u): return u.Classes.has(hero_class.Name)).size()
		t.equal(count, 2, "%s escolhe entre duas melhorias" % hero_class.Name)


func _training() -> void:
	var c: Dictionary = Campaign.create_initial(90)
	Campaign.state = c
	var bento: Dictionary = S.hero(c, "hero_cao_bento")
	t.equal([AHHeroLevels.level(bento), AHHeroLevels.xp(bento), bento.upgrades], [1, 0, []], "o herói novo começa no nível 1, sem XP")
	t.check(AHHeroLevels.train_block(c, bento).begins_with("Falta XP"), "sem XP, não treina")
	var cost := AHHeroLevels.next_cost(bento)
	bento.xp = cost.xp + 5
	var seeds := S.quantity(c, "seeds")
	var max_hp: int = bento.max_hp
	t.equal(AHHeroLevels.options(bento).map(func(u): return u.Name), ["vida", "calma"], "o cão escolhe entre mais vida e sangue frio")
	t.equal(AHHeroLevels.train(c, "hero_cao_bento", "velocidade"), "Essa melhoria não é desta espécie.", "melhoria de outra espécie, não")
	t.equal(AHHeroLevels.train(c, "hero_cao_bento", "vida"), "", "treina com XP e sementes")
	t.equal([AHHeroLevels.level(bento), AHHeroLevels.xp(bento), S.quantity(c, "seeds")], [2, 5, seeds - cost.seeds], "nível 2, o XP do nível e as sementes gastos")
	t.equal(int(bento.max_hp), max_hp + 2, "mais fôlego: +2 de vida máxima")
	# O limite das melhorias: o gato tem um passo ligeiro (data/hero-upgrades.json), depois só a mão treinada.
	var nick: Dictionary = S.hero(c, "hero_gato_nick")
	c.inventory.seeds = 999
	var speed_limit := int(GameData.row("hero_upgrades", "velocidade").MaxStacks)
	for i in speed_limit:
		nick.xp = 999
		t.equal(AHHeroLevels.train(c, "hero_gato_nick", "velocidade"), "", "o passo ligeiro %d de %d" % [i + 1, speed_limit])
	nick.xp = 999
	t.check(AHHeroLevels.train(c, "hero_gato_nick", "velocidade") != "", "passou do limite (%d): o passo ligeiro é recusado" % speed_limit)
	# As melhorias (as de aprender, #259, vêm à parte: no treino para o nível 3 em diante).
	var upgrades: Array = AHHeroLevels.options(nick).filter(func(u): return String(u.get("Stat", "")) != "Learn")
	t.equal(upgrades.map(func(u): return u.Name), ["habilidade_gato", "vida"], "com a velocidade no limite, a reserva (mais vida) completa as duas")
	# A ficha da Preparação (#89) mostra a velocidade da luta, com o Passo ligeiro, e as melhorias.
	var sheet := AHCharacterSheet.from_hero(nick)
	var in_fight: int = AHCombatSession.create([nick], ["robot"], false, 3).state.player_team[0].speed
	t.equal(int(sheet.speed), in_fight, "a ficha mostra a mesma velocidade da luta (com o Passo ligeiro)")
	t.check(sheet.passives.any(func(p): return String(p[0]).begins_with("Passo ligeiro")), "e a melhoria nos passivos")
	# O limite no 10.
	for i in 20:
		nick.xp = 999
		var options := AHHeroLevels.options(nick)
		if options.is_empty() or AHHeroLevels.train(c, "hero_gato_nick", options[0].Name) != "":
			break
	t.equal(AHHeroLevels.level(nick), AHHeroLevels.MAX_LEVEL, "sobe até o nível 10")
	t.equal(AHHeroLevels.train_block(c, nick), "Nível máximo.", "e para no 10")
	t.equal(AHHeroLevels.gain(nick, 50), 0, "no 10, o XP não acumula")


func _combat() -> void:
	var c: Dictionary = Campaign.create_initial(91)
	Campaign.state = c
	var nick: Dictionary = S.hero(c, "hero_gato_nick")
	var base := AHCombatSession.create([nick], ["robot"], false, 3)
	var plain: AHCombat.Unit = base.state.player_team[0]
	nick.upgrades = ["velocidade", "habilidade_gato"]
	nick.level = 3
	nick.instinct = 25
	var leveled := AHCombatSession.create([nick], ["robot"], false, 3)
	var unit: AHCombat.Unit = leveled.state.player_team[0]
	t.equal(unit.speed, plain.speed + 1, "o passo ligeiro soma na velocidade da luta")
	t.equal(unit.ability_bonus, {"gato_corte_fase": 1}, "a mão treinada: +1 no Corte de Fase")
	var bento: Dictionary = S.hero(c, "hero_cao_bento")
	bento.instinct = 25
	bento.upgrades = ["calma"]
	var calm_session := AHCombatSession.create([bento], ["robot"], false, 3)
	t.equal(calm_session.state.player_team[0].instinct, 15, "o sangue frio: 10 de instinto a menos no começo da luta")
	J.start_expedition(c, "fase_1", 3)
	calm_session.write_back(c)
	t.equal(int(bento.instinct), 25, "e só na luta: o instinto gravado volta ao de antes")
	calm_session.write_back(c)
	t.equal(int(bento.instinct), 25, "gravar de novo não devolve o instinto do Sangue frio em dobro")
	# O Sangue frio não apaga a crise: quem terminou a luta em crise continua nela; sem crise, o que volta não a provoca.
	var crisis_session := AHCombatSession.create([bento], ["robot"], false, 3)
	var top := int(crisis_session.engine.instinct_rules().Max)
	var crisis_unit: AHCombat.Unit = crisis_session.state.player_team[0]
	crisis_unit.instinct = top
	crisis_unit.crisis_outcome = AHCombat.Crisis.COLLAPSE
	crisis_session.write_back(c)
	t.equal(int(bento.instinct), top, "terminou a luta em crise: a crise continua (o Sangue frio não a apaga)")
	bento.instinct = 25
	var near_session := AHCombatSession.create([bento], ["robot"], false, 3)
	near_session.state.player_team[0].instinct = top - 5
	near_session.write_back(c)
	t.equal(int(bento.instinct), top - 1, "sem crise na luta, o instinto que volta para antes dela")
	bento.instinct = 25
	# A tela da luta mostra a faixa com a Mão treinada de quem age.
	nick.upgrades = ["habilidade_gato", "habilidade_gato"]
	var shown_session := AHCombatSession.create([nick], ["robot"], false, 3)
	var nick_unit: AHCombat.Unit = shown_session.state.player_team[0]
	var base_range: Dictionary = GameData.combat.abilities["gato_corte_fase"].DamageRange
	var shown := shown_session.effective_range("gato_corte_fase", "damage", nick_unit.id)
	t.equal([shown.Min, shown.Max, shown.trained], [int(base_range.Min) + 2, int(base_range.Max) + 2, true], "a tela mostra a faixa com a Mão treinada")
	t.check(shown_session.describe("gato_corte_fase", nick_unit.id).begins_with("Dano %d–%d (treinado)" % [int(base_range.Min) + 2, int(base_range.Max) + 2]), "e a descrição também")
	# O +1 vale no dano: com a mesma semente, o golpe nunca sai menor e às vezes sai maior.
	var more := 0
	for seed_value in 30:
		nick.upgrades = []
		var a := _first_hit(nick, seed_value)
		nick.upgrades = ["habilidade_gato"]
		var b := _first_hit(nick, seed_value)
		if b < a:
			more = -999
		elif b > a:
			more += 1
	t.check(more > 0, "o +1 aumenta o dano do Corte de Fase (%d de 30 maiores, nenhum menor)" % more)


func _first_hit(hero: Dictionary, seed_value: int) -> int:
	var session := AHCombatSession.create([hero], ["robot"], true, seed_value)
	var actor := session.current_actor()
	if actor == null or not actor.is_player:
		return 0
	var result := session.use_ability(actor.id, "gato_corte_fase", 1)
	for event in result.events:
		if event.type == AHCombat.EventType.DAMAGE:
			return event.amount
	return 0


## O XP de jogar: a luta (quem lutou, pelo que fez, mais para o recruta) e a jornada concluída.
func _xp_from_play() -> void:
	var c: Dictionary = Campaign.create_initial(92)
	var rng := RandomNumberGenerator.new()
	rng.seed = 92
	var recruit_id: String = S.recruit(c, "cao", rng, "Teste").hero_id
	# O recruta pelo id (hero_<classe>_<n>): os fundadores nunca, um recruta de cada classe sempre.
	var founders: Array = GameData.table("initial_heroes").keys()
	t.check(not founders.is_empty() and founders.all(func(id): return not AHHeroLevels.is_recruit({"id": id})), "nenhum fundador conta como recruta")
	var recruits_ok := true
	for class_id in GameData.table("classes").keys():
		var fresh: Dictionary = Campaign.create_initial(140)
		fresh.unlocked_classes = GameData.table("classes").keys()
		var made: Dictionary = S.recruit(fresh, class_id, rng, "Teste")
		if not made.has("hero_id") or not AHHeroLevels.is_recruit(S.hero(fresh, made.hero_id)):
			recruits_ok = false
	t.check(recruits_ok, "o recruta de cada classe conta como recruta")
	Campaign.state = c
	J.start_expedition(c, "fase_1", 92)
	c.session.expedition.team = ["hero_cao_bento", recruit_id]
	var heroes: Array = c.session.expedition.team.map(func(id): return S.hero(c, id))
	var session := AHCombatSession.create(heroes, ["robot"], false, 4)
	session.tally = {"hero_cao_bento": {"damage": 20, "healing": 10, "downs": 1}}
	var expected := AHHeroLevels.fight_xp({"damage": 20, "healing": 10, "downs": 1})
	t.equal(expected, 8 + 3 + 2 + 2, "o XP da luta: lutar, derrubar, curar e o dano (hero-xp.json)")
	t.equal(AHHeroLevels.fight_xp({"protects": 2}), 8 + 2 * int(AHHeroLevels.rule("protect").Xp), "proteger um aliado também dá XP")
	session.write_back(c)
	t.equal(AHHeroLevels.xp(S.hero(c, "hero_cao_bento")), expected, "quem fez mais ganha mais")
	t.equal(AHHeroLevels.xp(S.hero(c, recruit_id)), roundi(8 * 1.5), "o recruta ganha mais que o fundador pelo mesmo")
	t.equal(int(c.session.expedition.stats.hero_cao_bento.xp), expected, "o relatório guarda o XP")
	c.session.result = "victory"
	var report := S.finish_return(c)
	var journey := int(AHHeroLevels.rule("journey").Xp)
	t.equal(AHHeroLevels.xp(S.hero(c, "hero_cao_bento")), expected + journey, "a jornada concluída dá XP")
	t.equal(int(report.stats.hero_cao_bento.xp), expected + journey, "e o relatório soma as duas")
	# Proteger conta no tally: o Fique Atrás de Mim do Bento num aliado.
	var guard_session := AHCombatSession.create([S.hero(c, "hero_cao_bento"), S.hero(c, recruit_id)], ["robot"], false, 4)
	var event := AHCombat.Event.new()
	event.type = AHCombat.EventType.INFO
	event.outcome = AHCombat.Outcome.GUARD_GRANTED
	event.target_unit_id = "unit_" + recruit_id
	guard_session._count("unit_hero_cao_bento", [event])
	t.equal(int(guard_session.tally.hero_cao_bento.protects), 1, "a guarda dada a um aliado conta como proteger")
	# A fuga não dá o XP da luta.
	var before := AHHeroLevels.xp(S.hero(c, "hero_cao_bento"))
	J.start_expedition(c, "fase_1", 5)
	var fled := AHCombatSession.create([S.hero(c, "hero_cao_bento")], ["robot"], false, 5)
	fled.state.escaped = true
	fled.write_back(c)
	t.equal(AHHeroLevels.xp(S.hero(c, "hero_cao_bento")), before, "a fuga não dá XP")


func _save_and_migration() -> void:
	var c: Dictionary = Campaign.create_initial(93)
	var bento: Dictionary = S.hero(c, "hero_cao_bento")
	bento.level = 4
	bento.xp = 17
	bento.upgrades = ["vida", "calma", "vida"]
	Campaign.state = c
	t.check(Campaign.save(), "grava")
	var back = Campaign.read_file(Campaign.primary_path())
	var loaded = null
	if back is Dictionary:
		for entry in back.roster:
			if entry.id == "hero_cao_bento":
				loaded = entry
	t.check(loaded != null and int(loaded.level) == 4 and int(loaded.xp) == 17 and loaded.upgrades == ["vida", "calma", "vida"], "o nível, o XP e as melhorias voltam do save")
	# O save da versão 1 (sem nível): abre no nível 1, com o XP das fases concluídas para treinar.
	var old: Dictionary = Campaign.create_initial(94)
	old.version = 1
	old.completed_phases = ["fase_1", "fase_2"]
	for entry in old.roster:
		entry.erase("level")
		entry.erase("xp")
		entry.erase("upgrades")
	var envelope := {"format": Campaign.FORMAT, "version": 1, "checksum": JSON.stringify(Campaign._normalize(old), "", true).sha256_text(), "campaign": old}
	var path := Campaign.save_dir.path_join("old.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope, "\t", true))
	file.close()
	var migrated = Campaign.read_file(path)
	if t.check(migrated is Dictionary, "o save da versão 1 abre"):
		t.equal(int(migrated.version), Campaign.VERSION, "migrado para a versão %d" % Campaign.VERSION)
		var per_phase := int(AHHeroLevels.rule("migration").Xp)
		t.check(migrated.roster.all(func(h): return int(h.level) == 1 and int(h.xp) == per_phase * 2 and h.upgrades == []), "cada herói no nível 1, com %d de XP (duas fases)" % (per_phase * 2))
	var future := envelope.duplicate(true)
	future.version = Campaign.VERSION + 1
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(future, "\t", true))
	file.close()
	t.equal(Campaign.read_file(path), null, "uma versão de depois não abre")


## O Alojamento: o nível, o XP, e o Treino com a escolha da melhoria.
func _lodging() -> void:
	var c: Dictionary = Campaign.create_initial(95)
	var bento: Dictionary = S.hero(c, "hero_cao_bento")
	bento.xp = int(AHHeroLevels.next_cost(bento).xp)
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("station", {}, false)
	for frame in 900:
		await _tree.process_frame
		if not GameFlow.busy and GameFlow.passage == null and _tree.current_scene != null and _tree.current_scene.name == "Station" and frame > 3:
			break
	var hud: AHRefugeHud = _tree.current_scene.hud
	hud.open_room(S.CHARACTERS)
	await _frames(3)
	t.check(_label(hud, "Nível 1 · XP %d / %d" % [bento.xp, bento.xp]), "a Sala dos Personagens mostra o nível e o XP")
	var train := _button(hud, "Treinar")
	if not t.check(train != null and not train.disabled, "o Treino do Bento está aberto"):
		return
	train.pressed.emit()
	await _frames(2)
	var choice := hud.find_child("Upgrade_vida", true, false) as Button
	t.check(choice != null and hud.find_child("Upgrade_calma", true, false) != null, "a escolha entre as duas melhorias")
	choice.pressed.emit()
	await _frames(2)
	var confirm := hud.find_child("Confirm", true, false) as Button
	if not t.check(confirm != null and confirm.is_visible_in_tree(), "o Treino confirma a escolhida"):
		return
	confirm.pressed.emit()
	await _frames(2)
	t.equal(AHHeroLevels.level(S.hero(Campaign.state, "hero_cao_bento")), 2, "escolhida, o Bento sobe para o nível 2")
	t.check(_label(hud, "Nível 2") and _label(hud, "Mais fôlego ×1"), "e a Sala mostra o nível novo e a melhoria")


func _label(root: Node, part: String) -> bool:
	return root.find_children("*", "Label", true, false).any(func(l): return not l.is_queued_for_deletion() and l.is_visible_in_tree() and l.text.contains(part))


func _button(root: Node, prefix: String) -> Button:
	for button in root.find_children("*", "Button", true, false):
		if not button.is_queued_for_deletion() and button.is_visible_in_tree() and button.text.to_lower().begins_with(prefix.to_lower()):
			return button
	return null


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
