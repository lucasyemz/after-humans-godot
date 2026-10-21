## A prévia de alvos (ability_hit_ids, que o HUD usa para marcar todos os atingidos) é igual a quem o ataque atinge:
## o Coquetel Corrosivo da Íris (alvo + vizinho) e a Granada de Fumaça da Véspera (o par 1-2 ou 3-4). Port do teste da
## Unreal AfterHumans.Combat.HitPreview, com os mesmos casos.
extends RefCounted

const CASES := [
	["sapo", "sapo_coquetel_corrosivo", 1, [1, 2]],
	["sapo", "sapo_coquetel_corrosivo", 3, [3, 4]],
	["coruja", "coruja_granada_fumaca", 2, [1, 2]],
	["coruja", "coruja_granada_fumaca", 4, [3, 4]],
]


func run(t) -> void:
	var campaign: Dictionary = Campaign.create_initial(3)
	for spec in CASES:
		var hero: Dictionary = campaign.roster.filter(func(h): return h.class_id == spec[0])[0]
		var ability = GameData.combat.abilities.get(spec[1])
		t.check(ability != null and not ability.OriginRanks.is_empty(), "%s existe e tem posição de origem" % spec[1])
		var session := AHCombatSession.create([hero], ["robot", "robot", "robot", "robot"], true, 11)
		var user: AHCombat.Unit = session.state.player_team[0]
		user.rank = ability.OriginRanks[0]
		session.state.current_turn_unit_id = user.id
		var preview: Array = session.hit_ids(user.id, spec[1], spec[2])
		var expected: Array = session.state.enemy_team.filter(func(u): return spec[3].has(u.rank)).map(func(u): return u.id)
		expected.sort()
		var got := preview.duplicate()
		got.sort()
		t.equal(got, expected, "%s na posição %d marca %s" % [spec[1], spec[2], spec[3]])
		# O ataque de verdade atinge exatamente os marcados.
		var result: Dictionary = session.use_ability(user.id, spec[1], spec[2])
		t.check(result.ok, "%s executa" % spec[1])
		var touched := {}
		for event in result.events:
			if String(event.target_unit_id).begins_with("enemy_"):
				touched[event.target_unit_id] = true
		t.check(touched.keys().all(func(id): return preview.has(id)), "%s: todo atingido estava na prévia" % spec[1])
	# Fora do alcance não marca nada.
	var bento: Dictionary = campaign.roster.filter(func(h): return h.class_id == "cao")[0]
	var single := AHCombatSession.create([bento], ["robot", "robot", "robot", "robot"], true, 11)
	single.state.current_turn_unit_id = single.state.player_team[0].id
	t.equal(single.hit_ids(single.state.player_team[0].id, "cao_punho_sucata", 4), [], "posição que a habilidade não alcança: sem prévia")
	var front: Array = single.hit_ids(single.state.player_team[0].id, "cao_punho_sucata", 1)
	t.equal(front.size(), 1, "golpe de alvo único marca só o alvo")
