## AHCombatSession com os kits aprovados e as patrulhas da rua: lutas inteiras terminam, as opções do herói batem com as
## regras, a fuga funciona e o resultado volta para a campanha.
extends RefCounted

const PATROLS := [["robot", "robot_fungo"], ["vigia_enferrujado", "robot"]]


func run(t) -> void:
	var campaign: Dictionary = Campaign.create_initial(11)
	var results := {}
	for patrol in PATROLS:
		for seed_value in range(12):
			var outcome := _auto_fight(t, campaign.roster.duplicate(true), patrol, seed_value)
			results[outcome] = results.get(outcome, 0) + 1
	t.check(results.get("victory", 0) > 0, "a equipe vence pelo menos uma luta automática (%s)" % results)
	t.note("24 lutas automáticas: %s" % results)
	_options(t, campaign)
	_flee(t, campaign)
	_write_back(t, campaign)


## Uma luta jogada pelos dois lados (os heróis pela política fixa da paridade). Devolve o resultado.
func _auto_fight(t, heroes: Array, patrol: Array, seed_value: int) -> String:
	var session := AHCombatSession.create(heroes, patrol, false, seed_value)
	var beats := 0
	while not session.is_over() and beats < 400:
		var beat: Dictionary = session.auto_player_turn() if session.is_player_turn() else session.enemy_turn()
		if beats == 0:
			t.check(beat.has("events") and beat.has("source_id"), "o lance tem eventos e quem agiu")
		beats += 1
	t.check(session.is_over(), "a luta %s (semente %d) termina em até 400 lances" % [patrol, seed_value])
	t.check(["victory", "defeat"].has(session.result()), "resultado válido: %s" % session.result())
	return session.result()


func _options(t, campaign: Dictionary) -> void:
	var session := AHCombatSession.create(campaign.roster.duplicate(true), PATROLS[0], false, 3)
	# Até achar o turno de um herói.
	while not session.is_player_turn():
		session.enemy_turn()
	var actor := session.current_actor()
	var options := session.ability_options(actor.id)
	t.equal(options.size(), 4, "%s tem 4 habilidades" % actor.display_name)
	for option in options:
		var ability: Dictionary = session.data.abilities[option.id]
		t.check(option.description != "", "%s tem descrição" % option.id)
		t.equal(option.usable, option.reason == "", "%s: usável só sem motivo" % option.id)
		if not ability.OriginRanks.has(actor.rank):
			t.check(not option.usable, "%s: fora da posição de origem não é usável" % option.id)
		if option.usable:
			t.check(not option.targets.is_empty(), "%s: usável tem alvo" % option.id)
	var usable: Array = options.filter(func(o): return o.usable and not o.self)
	if t.check(not usable.is_empty(), "%s tem uma habilidade com alvo" % actor.display_name):
		var option: Dictionary = usable[0]
		var beat := session.use_ability(actor.id, option.id, option.targets[0])
		t.check(beat.ok, "usar %s no alvo válido funciona (%s)" % [option.id, beat.error])
		t.check(session.state.current_turn_unit_id != actor.id or session.is_over(), "a vez passa depois da ação")
	t.check(session.can_flee(), "dá para fugir da patrulha da rua")


func _flee(t, campaign: Dictionary) -> void:
	var escaped := false
	for seed_value in range(20):
		var session := AHCombatSession.create(campaign.roster.duplicate(true), PATROLS[0], false, seed_value)
		while not session.is_player_turn() and not session.is_over():
			session.enemy_turn()
		if session.is_over():
			continue
		session.begin_player_turn()
		var beat := session.flee(session.current_actor().id)
		t.check(beat.ok, "fugir é aceito")
		if beat.get("escaped", false):
			t.equal(session.result(), "escaped", "fuga bem-sucedida termina a luta")
			escaped = true
			break
	t.check(escaped, "alguma fuga dá certo em 20 tentativas (60% cada)")


func _write_back(t, campaign: Dictionary) -> void:
	var copy: Dictionary = campaign.duplicate(true)
	var session := AHCombatSession.create(copy.roster, PATROLS[0], false, 5)
	var bento := session.state.find_unit("unit_hero_cao_bento")
	bento.hp = 7
	bento.instinct = 40
	var nick := session.state.find_unit("unit_hero_gato_nick")
	nick.hp = 0
	nick.deaths_door = false
	session.write_back(copy)
	var hero = copy.roster.filter(func(h): return h.id == "hero_cao_bento")[0]
	t.equal([hero.hp, hero.instinct, hero.alive], [7, 40, true], "vida e instinto voltam para a campanha")
	var dead = copy.roster.filter(func(h): return h.id == "hero_gato_nick")[0]
	t.equal(dead.alive, false, "quem morreu na luta fica com alive = false")
	t.check(Campaign.is_usable(copy), "a campanha continua utilizável depois da luta")
