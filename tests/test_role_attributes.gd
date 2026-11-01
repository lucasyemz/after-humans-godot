## Os atributos por papel (#258, a matriz aprovada na #189): a resistência a dano por turno, a deslocamento e a
## atordoamento e o crítico a mais de cada papel.
## - os dados: a matriz como foi aprovada; os kits históricos, sem as colunas, com os padrões de antes (0,2, 0,2, 0, 0);
## - o motor, com o sorteio fixo: o dano por turno e o empurrão contra a resistência do papel; o atordoamento só sorteia
##   com resistência acima de 0 (hoje nenhum inimigo atordoa herói); o crítico do Incursão com +5 pontos;
## - a ficha: a linha das resistências e a do crítico.
extends RefCounted

## [dano por turno, deslocamento, atordoamento, crítico a mais] de cada papel (a tabela da seção 5 da proposta).
const MATRIX := {
	"cao": [0.20, 0.40, 0.30, 0], "gato": [0.10, 0.10, 0.10, 5], "sapo": [0.40, 0.10, 0.10, 0],
	"coruja": [0.10, 0.20, 0.20, 3], "rato": [0.30, 0.20, 0.10, 2], "tatu": [0.30, 0.60, 0.40, 0],
}


## O sorteio fixo, que conta quantas vezes sorteou.
class FixedRandom extends AHCombatRandom:
	var value := 0.99

	func next() -> float:
		draws += 1
		return value


var t


func run(context) -> void:
	t = context
	_data()
	_engine()
	_sheet()


func _data() -> void:
	var data := AHGameData.new()
	data.load_from("res://data")
	var wrong: Array = []
	for class_id in MATRIX:
		var row: Dictionary = data.classes[class_id]
		var got := [row.DotResist, row.DisplacementResist, row.StunResist, row.CritBonus]
		for i in 4:
			if absf(float(got[i]) - float(MATRIX[class_id][i])) > 0.0001:
				wrong.append(class_id)
				break
	t.equal(wrong, [], "a matriz dos seis papéis como foi aprovada")
	# Os kits da paridade não têm as colunas: os padrões são o comportamento de antes.
	var legacy := AHGameData.new()
	legacy.load_from("res://data", "res://data/legacy_kits")
	var cao: Dictionary = legacy.classes.get("cao", {})
	t.check(is_equal_approx(float(cao.get("DotResist", -1)), 0.2) and is_equal_approx(float(cao.get("DisplacementResist", -1)), 0.2)
		and float(cao.get("StunResist", -1)) == 0.0 and int(cao.get("CritBonus", -1)) == 0, "o kit histórico com os padrões de antes")


func _engine() -> void:
	var data := AHGameData.new()
	data.load_from("res://data")
	var random := FixedRandom.new()
	var engine := AHCombatEngine.new(AHCombat.State.new(), AHCombat.Context.new(), data, random)
	var unit := func(class_id: String): return AHCombatEngine.make_hero_unit({"Id": class_id, "ClassId": class_id, "DisplayName": class_id, "Hp": 10, "MaxHp": 10}, 1, data)
	var tank: AHCombat.Unit = unit.call("tatu")
	var cat: AHCombat.Unit = unit.call("gato")
	var chemist: AHCombat.Unit = unit.call("sapo")
	# O dano por turno: o sapo (40%) resiste com 0,35 e não com 0,45.
	random.value = 0.35
	t.check(engine._resisted_effect(chemist, true), "a Química resiste ao dano por turno com 0,35 (40%)")
	random.value = 0.45
	t.check(not engine._resisted_effect(chemist, true), "e não com 0,45")
	# O empurrão: o Resgate (60%) segura com 0,5; o Incursão (10%), não. Sorteia sempre, como antes.
	random.value = 0.5
	t.equal([engine._hero_holds(tank), engine._hero_holds(cat)], [true, false], "o Resgate segura o empurrão com 0,5, o Incursão não")
	# O atordoamento: o Resgate (40%) resiste com 0,3; sem a resistência, não sorteia.
	random.value = 0.3
	t.check(engine._hero_resists_stun(tank), "o Resgate resiste ao atordoamento com 0,3 (40%)")
	var plain := AHGameData.new()
	plain.load_from("res://data", "res://data/legacy_kits")
	var plain_engine := AHCombatEngine.new(AHCombat.State.new(), AHCombat.Context.new(), plain, random)
	var legacy_unit := AHCombatEngine.make_hero_unit({"Id": "l", "ClassId": "cao", "DisplayName": "L", "Hp": 10, "MaxHp": 10}, 1, plain)
	var before := random.draws
	t.check(not plain_engine._hero_resists_stun(legacy_unit) and random.draws == before, "sem resistência ao atordoamento, não sorteia (a paridade)")
	# O crítico: 10% de todos, 15% no Incursão.
	t.check(is_equal_approx(engine.hero_crit_chance(cat), 0.15) and is_equal_approx(engine.hero_crit_chance(chemist), 0.1), "o crítico: 15% no Incursão, 10% na Química")
	# Hoje nenhum inimigo atordoa herói (só os heróis atordoam: o Impacto Hidráulico, a Poeira e a Investida). A
	# resistência fica pronta para quando houver, no mesmo lugar do Inflicts.Stun da ação do inimigo.


func _sheet() -> void:
	var rows := AHCharacterSheet.role_rows("tatu")
	t.equal(rows.size(), 1, "o Resgate: só a linha das resistências (sem crítico a mais)")
	t.equal(String(rows[0][1]), "dano por turno 30% · deslocamento 60% · atordoamento 40%", "as três resistências do Resgate")
	var cat := AHCharacterSheet.role_rows("gato")
	t.check(cat.size() == 2 and String(cat[1][1]).begins_with("15%"), "o Incursão mostra o crítico de 15%")
	var hero := Campaign.new_hero("hero_tatu_9", "tatu", "Teste", 38, [])
	t.check(AHCharacterSheet.from_hero(hero).passives.any(func(row): return String(row[0]) == "Resistências do papel"), "a ficha fora da luta mostra as resistências")
