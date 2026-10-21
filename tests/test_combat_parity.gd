## Paridade com a web: repete as lutas gravadas em data/combat-parity.txt e compara o estado depois de cada ação,
## como Source/AfterHumans/Combat/AHCombatParityTest.cpp na referência Unreal. Usa os kits históricos (data/legacy_kits),
## porque a gravação é anterior aos kits aprovados.
extends RefCounted

const Unit = AHCombat.Unit


func _founders() -> Array:
	return [
		{"ClassId": "cao", "Name": "bento", "Perks": ["loyal", "machine-fear"]},
		{"ClassId": "gato", "Name": "nick", "Perks": ["agile", "anxious"]},
		{"ClassId": "capivara", "Name": "amora", "Perks": ["brave", "gloomy"]},
		{"ClassId": "coruja", "Name": "iris", "Perks": ["hopeful", "sluggish"]},
	]


func _scenario(key: String) -> Dictionary:
	var s := {"heroes": _founders(), "enemies": [], "fixed_ranks": [], "opening": false, "preserve": true,
		"hope": 80, "relationships": {}, "researched": []}
	var formation := func(ids: Array):
		for index in ids.size():
			s.enemies.append([ids[index], "enemy_%s_%d" % [ids[index], index]])
	match key:
		"A":
			formation.call(["robot", "cao_eco", "condutor_raiz", "sussurrador"])
			s.opening = true
		"B":
			s.enemies = [["porteiro", "enemy_porteiro"], ["condutor_raiz", "enemy_condutor_1"], ["condutor_raiz", "enemy_condutor_2"]]
			s.fixed_ranks = [1, 3, 4]
			s.hope = 20
			s.relationships = {"hero_cao_bento_hero_gato_nick": 3, "hero_capivara_amora_hero_coruja_iris": -3}
		"C":
			s.heroes[0].Hp = 10
			s.heroes[3].Instinct = 150
			s.heroes[3].Trauma = true
			formation.call(["vigia_enferrujado", "carcaca_colonizada", "robot", "robot_fungo"])
			s.preserve = false
			s.hope = 0
		_:
			formation.call(["rastejante_raiz", "ninho_errante", "robot_fungo"])
			s.opening = true
			s.hope = 60
			s.researched = ["cao_golpe", "gato_salto"]
	return s


func _unit_text(u: Unit) -> String:
	return "%s:%d:%d:%d:%d:%d,%d,%d,%d,%d:%d/%d:%d/%d:%d:%d:%d" % [u.id, u.rank, u.hp, 1 if u.deaths_door else 0, u.instinct,
		u.tokens.block, u.tokens.dodge, u.tokens.vuln, u.tokens.guard, u.tokens.mark,
		u.bleed.magnitude, u.bleed.duration, u.blight.magnitude, u.blight.duration, u.stun_turns, u.mark_duration, u.guard_target_rank]


func _snapshot(state: AHCombat.State, context: AHCombat.Context, draws: int) -> String:
	var keys: Array = context.relationships.keys()
	keys.sort_custom(func(a, b): return a.casecmp_to(b) < 0)
	var bonds := PackedStringArray()
	for key in keys:
		if context.relationships[key] != 0:
			bonds.append("%s=%d" % [key, context.relationships[key]])
	var parts := PackedStringArray(["r%d" % state.round, state.current_turn_unit_id,
		"%d%d%d" % [int(state.is_over), int(state.victory), int(state.escaped)], "p%d" % state.boss_phase, "d%d" % draws, ",".join(bonds)])
	for u in state.player_team:
		parts.append(_unit_text(u))
	for u in state.enemy_team:
		parts.append(_unit_text(u))
	return " ".join(parts)


func run(t) -> void:
	var data := AHGameData.new()
	if not t.check(data.load_from("res://data", "res://data/legacy_kits"), "dados do combate e kits históricos carregam"):
		return
	var lines := FileAccess.get_file_as_string("res://data/combat-parity.txt").split("\n")
	for i in lines.size():
		lines[i] = lines[i].strip_edges(false, true)

	var fights := 0
	var matched := 0
	var steps := 0
	var line_index := 0
	while line_index < lines.size():
		var header := lines[line_index].split(" ")
		if header.size() != 3 or header[0] != "FIGHT":
			line_index += 1
			continue
		fights += 1
		var key := header[1]
		var seed_index := int(header[2])
		var scenario := _scenario(key)

		var random := AHCombatRandom.new(seed_index * 7919 + key.unicode_at(0))
		var context := AHCombat.Context.new()
		context.hope = scenario.hope
		context.relationships = scenario.relationships.duplicate()
		context.researched_skills = scenario.researched
		context.legacy_web_advance_swap = true

		var players: Array = []
		for index in scenario.heroes.size():
			var setup: Dictionary = scenario.heroes[index]
			var hero_class: Dictionary = data.classes[setup.ClassId]
			var hero := {
				"Id": "hero_%s_%s" % [setup.ClassId, setup.Name], "ClassId": setup.ClassId, "DisplayName": setup.Name,
				"MaxHp": hero_class.BaseMaxHp, "Hp": setup.get("Hp", hero_class.BaseMaxHp),
				"Instinct": setup.get("Instinct", 0), "Perks": setup.Perks, "Trauma": setup.get("Trauma", false),
			}
			players.append(AHCombatEngine.make_hero_unit(hero, index + 1, data))
		var enemies: Array = []
		var next_rank := 1
		for index in scenario.enemies.size():
			var enemy_id: String = scenario.enemies[index][0]
			var rank: int = scenario.fixed_ranks[index] if index < scenario.fixed_ranks.size() else next_rank
			enemies.append(AHCombatEngine.make_enemy_unit(enemy_id, scenario.enemies[index][1], rank, data))
			var enemy = data.enemies.get(enemy_id)
			next_rank = rank + (enemy.FormationSize if enemy != null and enemy.FormationSize > 0 else 1)

		var state := AHCombatEngine.init_combat(players, enemies, context, data, random, scenario.opening, scenario.preserve)
		var engine := AHCombatEngine.new(state, context, data, random)

		var step_index := 0
		var cursor := line_index + 1
		var fight_ok := _compare(t, key, seed_index, step_index, lines[cursor], _snapshot(state, context, random.draws))
		cursor += 1
		steps += 1
		step_index += 1
		while fight_ok and cursor < lines.size() and not lines[cursor].begins_with("END"):
			if state.is_over:
				fight_ok = t.check(false, "Luta %s %d: a Godot terminou antes da web (passo %d)." % [key, seed_index, step_index])
				break
			var actor_id := state.current_turn_unit_id
			var actor := state.find_unit(actor_id)
			if actor != null and actor.is_player:
				if engine.process_player_turn_start([]):
					engine.play_auto_turn(actor_id)
			else:
				engine.execute_enemy_turn()
			fight_ok = _compare(t, key, seed_index, step_index, lines[cursor], _snapshot(state, context, random.draws))
			cursor += 1
			steps += 1
			step_index += 1
		if fight_ok and cursor < lines.size():
			var deaths := PackedStringArray()
			for u in state.player_team:
				if u.hp <= 0 and not u.deaths_door:
					deaths.append(u.hero_id)
			var actual := "END %d %d %s" % [int(state.victory), int(state.escaped), ",".join(deaths)]
			fight_ok = t.equal(actual.strip_edges(false, true), lines[cursor], "Luta %s %d: fim" % [key, seed_index])
		matched += 1 if fight_ok else 0
		line_index = cursor + 1

	t.equal(matched, fights, "lutas iguais à gravação da web")
	t.equal(fights, 48, "a gravação tem as 48 lutas")
	t.note("%d de %d lutas, %d passos" % [matched, fights, steps])


## Uma verificação por passo só quando diverge (são 3.351 passos): a contagem fica legível.
func _compare(t, key: String, seed_index: int, step: int, expected: String, actual: String) -> bool:
	if actual == expected:
		return true
	return t.check(false, "Luta %s %d diverge no passo %d.\n      web:   %s\n      godot: %s" % [key, seed_index, step, expected.left(400), actual.left(400)])
