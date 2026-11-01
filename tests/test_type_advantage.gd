## A vantagem de tipo (#227): as linhagens dos animais (na classe) e as famílias mecânicas dos inimigos, e o ×1,25 no
## dano direto de quem vence o defensor.
## - a cobertura: toda classe tem linhagem e todo inimigo tem família (os protótipos também), e quem vence quem aponta
##   para classificações que existem; a linhagem vem da classe (o save não muda);
## - o arredondamento para o mais próximo (2 → 3, 3 → 4, 4 → 5, 6 → 8);
## - pelo motor de verdade, com o sorteio fixo: a vantagem, o neutro, a direção (Felidae contra Canidae é neutro), o lado
##   do inimigo (um Blindado num Felidae) e o acúmulo com o crítico, a Carga Voltaica, o Vulnerável e o Bloqueio, com os
##   números fechados; com a regra desligada, o dano de antes;
## - fora da regra: o dano contínuo, a cura e o Instinto.
extends RefCounted

## As posições como o JSON as lê (em float), para o _merge dos dados.
const RANKS := [1.0, 2.0, 3.0, 4.0]


## O sorteio fixo: sempre o mesmo número (0,99 não dá crítico; 0 dá).
class FixedRandom extends AHCombatRandom:
	var value := 0.99

	func next() -> float:
		draws += 1
		return value


var t


func run(context) -> void:
	t = context
	_coverage()
	_rounding()
	_hero_side()
	_enemy_side()
	_outside_the_rule()
	_sheet()


func _data(enabled: bool) -> AHGameData:
	var data := AHGameData.new()
	data.load_from("res://data")
	data.type_advantage.Enabled = enabled
	return data


func _coverage() -> void:
	var data := _data(true)
	t.check(data.type_advantage.has("Multiplier") and is_equal_approx(float(data.type_advantage.Multiplier), 1.25), "a chave e o multiplicador nos dados (TypeAdvantage)")
	var lineages: Array = data.type_classes.keys().filter(func(id): return data.type_classes[id].Kind == "lineage")
	var families: Array = data.type_classes.keys().filter(func(id): return data.type_classes[id].Kind == "family")
	t.equal([lineages.size(), families.size()], [6, 6], "seis linhagens e seis famílias mecânicas")
	var missing: Array = []
	for class_id in data.classes:
		if not lineages.has(String(data.classes[class_id].Lineage)):
			missing.append(class_id)
	for enemy_id in data.enemies:
		if not families.has(String(data.enemies[enemy_id].MechFamily)):
			missing.append(enemy_id)
	t.equal(missing, [], "toda classe com a linhagem e todo inimigo (os protótipos também) com a família")
	t.equal(data.enemies.size(), 26, "os 26 inimigos")
	var broken: Array = []
	for id in data.type_classes:
		for beaten in data.type_classes[id].Beats:
			if not data.type_classes.has(beaten):
				broken.append("%s → %s" % [id, beaten])
	t.equal(broken, [], "quem vence quem aponta para classificações que existem")
	# Cada classificação vence uma linhagem, e cada linhagem vence também uma família (a tabela do Lucas).
	t.check(lineages.all(func(id): return data.type_classes[id].Beats.size() == 2) and families.all(func(id): return data.type_classes[id].Beats.size() == 1),
		"cada linhagem vence uma linhagem e uma família; cada família, uma linhagem")
	# Os ids não mudam: o Guaxinim segue rato, e a máquina segue máquina.
	t.equal(String(data.classes.rato.Lineage), "Procyonidae", "o rato (o Guaxinim) na Linhagem dos Guaxinins")
	t.check(data.enemies.values().all(func(e): return e.Category == "Machine"), "os inimigos seguem máquinas")
	var hero: Dictionary = Campaign.create_initial(5).roster[0]
	t.check(not hero.has("Lineage") and not hero.has("lineage"), "a linhagem vem da classe: o save do herói não muda")


func _rounding() -> void:
	t.equal([2, 3, 4, 6].map(func(d): return AHCombatEngine.typed_damage(d, 1.25)), [3, 4, 5, 8], "para o mais próximo: 2 → 3, 3 → 4, 4 → 5, 6 → 8")
	t.equal(AHCombatEngine.typed_damage(7, 1.0), 7, "neutro, o mesmo dano")


## Um herói na posição 1 contra um inimigo na 1, com uma habilidade de dano fixo (4) e o sorteio fixo. Devolve o dano.
func _hit(enabled: bool, class_id: String, enemy_id: String, roll: float, extra := {}, setup := Callable()) -> int:
	var data := _data(enabled)
	var row := {"Name": "qa_hit", "ClassId": class_id, "OriginRanks": RANKS, "TargetRanks": RANKS,
		"TargetType": "SingleEnemy", "DamageRange": {"Min": 4, "Max": 4}}
	row.merge(extra, true)
	data.abilities["qa_hit"] = AHGameData._merge(AHGameData.ABILITY, row)
	data.classes[class_id].AbilityIds = data.classes[class_id].AbilityIds + ["qa_hit"]
	var hero := AHCombatEngine.make_hero_unit({"Id": "qa", "ClassId": class_id, "DisplayName": "QA", "Hp": 100, "MaxHp": 100}, 1, data)
	var enemy := AHCombatEngine.make_enemy_unit(enemy_id, "qa_enemy", 1, data)
	enemy.hp = 100
	enemy.max_hp = 100
	var state := AHCombat.State.new()
	state.player_team = [hero]
	state.enemy_team = [enemy]
	var random := FixedRandom.new()
	random.value = roll
	var engine := AHCombatEngine.new(state, AHCombat.Context.new(), data, random)
	if setup.is_valid():
		setup.call(enemy)
	var result := engine.execute_player_ability(hero.id, "qa_hit", 1)
	if result.error != "":
		t.check(false, "a habilidade de teste falhou: %s" % result.error)
	return 100 - engine._find_unit("qa_enemy").hp


func _hero_side() -> void:
	# O gato (Felidae) vence a família Degradada (o Robô Fúngico); a Perseguidora não.
	t.equal(_hit(false, "gato", "robot_fungo", 0.99), 4, "desligada: o dano de antes (4)")
	t.equal(_hit(true, "gato", "robot_fungo", 0.99), 5, "Felidae na Degradada: 4 × 1,25 = 5")
	t.equal(_hit(true, "gato", "cao_eco", 0.99), 4, "Felidae na Perseguidora: neutro (4)")
	# O acúmulo, na ordem: crítico ×1,5 (4 → 6), o tipo (6 → 8), o Vulnerável ×1,5 (8 → 12), o Bloqueio pela metade (6).
	t.equal(_hit(true, "gato", "robot_fungo", 0.0), 8, "crítico e tipo: 4 → 6 → 8")
	t.equal(_hit(true, "gato", "robot_fungo", 0.0, {}, func(e): e.tokens.vuln = 1), 12, "crítico, tipo e Vulnerável: 8 → 12")
	t.equal(_hit(true, "gato", "robot_fungo", 0.0, {}, func(e): e.tokens.vuln = 1; e.tokens.block = 1), 6, "e o Bloqueio: 12 → 6")
	# A Carga Voltaica (125% contra máquina) antes do tipo: o sapo (Anura) vence a Industrial (o Robô).
	t.equal(_hit(true, "sapo", "robot", 0.99, {"MachineDamagePercent": 125}), 6, "Carga Voltaica e tipo: 4 → 5 → 6")
	t.equal(_hit(false, "sapo", "robot", 0.99, {"MachineDamagePercent": 125}), 5, "desligada, só a Carga Voltaica: 4 → 5")
	# A direção: Felidae contra Canidae é neutro (é o cão que vence o gato), pela função do motor.
	var data := _data(true)
	var engine := AHCombatEngine.new(AHCombat.State.new(), AHCombat.Context.new(), data, FixedRandom.new())
	var cat := AHCombatEngine.make_hero_unit({"Id": "c", "ClassId": "gato", "DisplayName": "C", "Hp": 10, "MaxHp": 10}, 1, data)
	var dog := AHCombatEngine.make_hero_unit({"Id": "d", "ClassId": "cao", "DisplayName": "D", "Hp": 10, "MaxHp": 10}, 1, data)
	t.equal([engine.type_multiplier(cat, dog), engine.type_multiplier(dog, cat)], [1.0, 1.25], "a direção: Felidae em Canidae neutro, Canidae em Felidae ×1,25")


## Um inimigo com uma ação fixa contra um herói (a posição 1 dos dois). Devolve {dano, instinto}.
func _enemy_hits(enabled: bool, enemy_id: String, class_id: String, action: Dictionary) -> Dictionary:
	var data := _data(enabled)
	var row := {"Name": "qa_action", "EnemyId": enemy_id, "OriginRanks": RANKS, "TargetRanks": RANKS, "TargetType": "SingleAlly"}
	row.merge(action, true)
	data.enemy_actions[enemy_id + "_qa_action"] = AHGameData._merge(AHGameData.ENEMY_ACTION, row)
	data.enemies[enemy_id].ActionIds = [enemy_id + "_qa_action"]
	var hero := AHCombatEngine.make_hero_unit({"Id": "qa", "ClassId": class_id, "DisplayName": "QA", "Hp": 100, "MaxHp": 100}, 1, data)
	var enemy := AHCombatEngine.make_enemy_unit(enemy_id, "qa_enemy", 1, data)
	var state := AHCombat.State.new()
	state.player_team = [hero]
	state.enemy_team = [enemy]
	state.current_turn_unit_id = enemy.id
	var engine := AHCombatEngine.new(state, AHCombat.Context.new(), data, FixedRandom.new())
	engine.execute_enemy_turn()
	var after := engine._find_unit(hero.id)
	return {"damage": 100 - after.hp, "instinct": after.instinct}


func _enemy_side() -> void:
	# A família Blindada (a Vigia Enferrujada) vence a Linhagem dos Gatos.
	t.equal(_enemy_hits(true, "vigia_enferrujado", "gato", {"DamageRange": {"Min": 4, "Max": 4}}).damage, 5, "Blindado no Felidae: 4 × 1,25 = 5")
	t.equal(_enemy_hits(false, "vigia_enferrujado", "gato", {"DamageRange": {"Min": 4, "Max": 4}}).damage, 4, "desligada: 4")
	t.equal(_enemy_hits(true, "vigia_enferrujado", "cao", {"DamageRange": {"Min": 4, "Max": 4}}).damage, 4, "Blindado no Canidae: neutro")


func _outside_the_rule() -> void:
	# O dano contínuo: o sangramento do gato na Degradada fica com a magnitude do dado (3), sem o tipo.
	t.equal([_bleed_after(false), _bleed_after(true)], [3, 3], "o sangramento na Degradada não muda com o tipo (3 e 3)")
	# A cura: o sapo (Anura, que vence Canidae) cura o cão sem o tipo.
	t.equal([_heal(false), _heal(true)], [4, 4], "a cura do sapo no cão não muda (4 e 4)")
	# O Instinto: a família Emissora (vence Canidae) põe o mesmo Instinto no cão.
	var push := {"DamageRange": {"Min": 0, "Max": 0}, "InstinctAdd": 10}
	t.equal([_enemy_hits(false, "sussurrador", "cao", push).instinct, _enemy_hits(true, "sussurrador", "cao", push).instinct], [10, 10],
		"o Instinto do Emissor no cão não muda (10 e 10)")


## O sangramento que fica no Robô Fúngico depois do golpe do gato.
func _bleed_after(enabled: bool) -> int:
	var data := _data(enabled)
	var row := {"Name": "qa_bleed", "ClassId": "gato", "OriginRanks": RANKS, "TargetRanks": RANKS, "TargetType": "SingleEnemy",
		"DamageRange": {"Min": 0, "Max": 0}, "Inflicts": {"Bleed": {"Magnitude": 3, "Duration": 2}}}
	data.abilities["qa_bleed"] = AHGameData._merge(AHGameData.ABILITY, row)
	data.classes.gato.AbilityIds = data.classes.gato.AbilityIds + ["qa_bleed"]
	data.enemies.robot_fungo.DotResist = 0.0
	var hero := AHCombatEngine.make_hero_unit({"Id": "qa", "ClassId": "gato", "DisplayName": "QA", "Hp": 100, "MaxHp": 100}, 1, data)
	var enemy := AHCombatEngine.make_enemy_unit("robot_fungo", "qa_enemy", 1, data)
	var state := AHCombat.State.new()
	state.player_team = [hero]
	state.enemy_team = [enemy]
	var engine := AHCombatEngine.new(state, AHCombat.Context.new(), data, FixedRandom.new())
	engine.execute_player_ability(hero.id, "qa_bleed", 1)
	return engine._find_unit("qa_enemy").bleed.magnitude


## A cura do sapo no cão (a posição 2 do cão, o sapo na 1).
func _heal(enabled: bool) -> int:
	var data := _data(enabled)
	var row := {"Name": "qa_heal", "ClassId": "sapo", "OriginRanks": RANKS, "TargetRanks": RANKS, "TargetType": "SingleOtherAlly",
		"DamageRange": {"Min": 0, "Max": 0}, "HealRange": {"Min": 4, "Max": 4}}
	data.abilities["qa_heal"] = AHGameData._merge(AHGameData.ABILITY, row)
	data.classes.sapo.AbilityIds = data.classes.sapo.AbilityIds + ["qa_heal"]
	var frog := AHCombatEngine.make_hero_unit({"Id": "frog", "ClassId": "sapo", "DisplayName": "S", "Hp": 50, "MaxHp": 50}, 1, data)
	var dog := AHCombatEngine.make_hero_unit({"Id": "dog", "ClassId": "cao", "DisplayName": "C", "Hp": 10, "MaxHp": 50}, 2, data)
	var state := AHCombat.State.new()
	state.player_team = [frog, dog]
	state.enemy_team = [AHCombatEngine.make_enemy_unit("robot", "qa_enemy", 1, data)]
	var engine := AHCombatEngine.new(state, AHCombat.Context.new(), data, FixedRandom.new())
	var result := engine.execute_player_ability(frog.id, "qa_heal", 2)
	if result.error != "":
		t.check(false, "a cura de teste falhou: %s" % result.error)
	return engine._find_unit(dog.id).hp - 10


## Na ficha (a do apontar, a da inspeção e a da Preparação): a linhagem com em quem causa mais dano e de quem recebe; a
## família do inimigo, igual; desligada, nada.
func _sheet() -> void:
	var real: bool = GameData.combat.type_advantage.Enabled
	GameData.combat.type_advantage.Enabled = true
	var cat := {"id": "qa_cat", "display_name": "QA", "class_id": "gato", "hp": 10, "max_hp": 10, "perks": []}
	var sheet := AHCharacterSheet.from_hero(cat)
	var titles: Array = sheet.passives.map(func(row): return String(row[0]))
	t.equal(sheet.type, TranslationServer.translate("Linhagem dos Gatos"), "a ficha do gato com a linhagem")
	t.check(titles.has(TranslationServer.translate("Dano +%d%% em %s") % [25, TranslationServer.translate("%s e %s") % [AHTypes.short("Strigiformes"), AHTypes.short("Degradado")]]),
		"em quem o gato causa mais dano, com o número, no título curto %s" % [titles])
	t.check(titles.has(TranslationServer.translate("Recebe +%d%% de %s") % [25, TranslationServer.translate("%s e %s") % [AHTypes.short("Canidae"), AHTypes.short("Blindado")]]),
		"e de quem ele recebe mais dano")
	t.equal(AHTypes.beaten_by("Felidae"), [AHTypes.display("Canidae"), AHTypes.display("Blindado")], "o gato recebe mais dano da Linhagem dos Cães e da Família Blindada")
	var data := GameData.combat
	var enemy := AHCombatEngine.make_enemy_unit("porteiro", "qa_boss", 1, data)
	var info := AHCharacterSheet.from_unit(null, enemy, true)
	t.check(info.type == TranslationServer.translate("Família Blindada") and info.passives.any(func(row): return String(row[0]).contains(AHTypes.short("Felidae"))),
		"a inspeção do Porteiro: a Família Blindada e em quem ela causa mais dano")
	GameData.combat.type_advantage.Enabled = false
	t.check(AHTypes.sheet_rows("Felidae").is_empty() and AHTypes.label("Felidae") == "", "desligada, a ficha não fala de vantagem")
	GameData.combat.type_advantage.Enabled = real
