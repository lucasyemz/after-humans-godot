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
	_stats(t)
	_intents(t, campaign)


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
	_relic_hp(t, campaign)
	_expedition_context(t, campaign)


## A relíquia de vida aumenta o máximo só na luta: curado até o máximo dela, o herói volta com a vida do máximo dele.
func _relic_hp(t, campaign: Dictionary) -> void:
	var copy: Dictionary = campaign.duplicate(true)
	var hero = copy.roster.filter(func(h): return h.id == "hero_cao_bento")[0]
	hero.relic_id = "botao_cobre"
	var session := AHCombatSession.create(copy.roster, PATROLS[0], false, 5)
	var bento := session.state.find_unit("unit_hero_cao_bento")
	t.check(bento.max_hp > hero.max_hp, "na luta, a relíquia aumenta a vida máxima (%d > %d)" % [bento.max_hp, hero.max_hp])
	bento.hp = bento.max_hp
	session.write_back(copy)
	t.equal(hero.hp, hero.max_hp, "fora da luta, a vida não passa do máximo do herói")


## A Esperança da expedição entra na luta, e os laços entre os heróis duram a expedição inteira (luta a luta).
func _expedition_context(t, campaign: Dictionary) -> void:
	var copy: Dictionary = campaign.duplicate(true)
	AHJourneyRules.start_expedition(copy, "fase_1", 77)
	copy.session.expedition.hope = 20
	copy.session.expedition.relationships = {"hero_cao_bento_hero_gato_nick": 2}
	var session := AHCombatSession.create(copy.roster, PATROLS[0], false, 5)
	session.use_expedition(copy)
	t.equal(session.context.hope, 20, "a luta usa a Esperança da expedição")
	t.equal(session.context.relationships, {"hero_cao_bento_hero_gato_nick": 2}, "a luta começa com os laços da expedição")
	session.context.relationships["hero_cao_bento_hero_gato_nick"] = 3
	session.write_back(copy)
	t.equal(copy.session.expedition.relationships, {"hero_cao_bento_hero_gato_nick": 3}, "os laços da luta voltam para a expedição")
	var free := AHCombatSession.create(campaign.duplicate(true).roster, PATROLS[0], false, 5)
	free.use_expedition({"session": {"expedition": null}})
	t.equal(free.context.hope, 80, "fora de expedição, a Esperança padrão")
	_researched(t, campaign)


## Os treinos da Pesquisa chegam à luta e dão +1 no dano da habilidade treinada (o mínimo e o máximo sobem um).
func _researched(t, campaign: Dictionary) -> void:
	var copy: Dictionary = campaign.duplicate(true)
	AHJourneyRules.start_expedition(copy, "fase_1", 77)
	copy.researched_skills = ["gato_corte_fase"]
	var session := AHCombatSession.create(copy.roster, PATROLS[0], false, 5)
	session.use_expedition(copy)
	t.equal(session.context.researched_skills, ["gato_corte_fase"], "a luta recebe os treinos da Pesquisa")
	var shown := session.effective_range("gato_corte_fase", "damage")
	var base: Dictionary = session.data.abilities["gato_corte_fase"].DamageRange
	t.equal([shown.Min, shown.Max, shown.trained], [int(base.Min) + 1, int(base.Max) + 1, true], "a faixa da tela soma o treino")
	t.check(session.describe("gato_corte_fase").begins_with("Dano %d–%d (treinado)" % [int(base.Min) + 1, int(base.Max) + 1]),
		"a descrição mostra a faixa treinada (%s)" % session.describe("gato_corte_fase").split("\n")[0])
	t.equal(session.effective_range("cao_punho_sucata", "damage").trained, false, "o que não foi treinado fica como nos dados")
	copy.researched_skills.append("cao_punho_sucata")
	t.equal(session.context.researched_skills, ["gato_corte_fase"], "a luta guarda uma cópia (a campanha não muda a luta no meio)")
	# O mesmo golpe, nas mesmas sementes, com e sem o treino: com ele, o dano nunca é menor e chega a mais.
	var hits := {false: [], true: []}
	for trained in [false, true]:
		for seed_value in range(30):
			var fight := AHCombatSession.create(campaign.duplicate(true).roster, ["robot_fungo"], false, seed_value)
			fight.context.researched_skills = ["gato_corte_fase"] if trained else []
			var nick = fight.state.player_team.filter(func(u): return u.hero_id == "hero_gato_nick")[0]
			var enemy = fight.state.enemy_team[0]
			enemy.tokens.dodge = 0
			enemy.tokens.block = 0
			fight.state.current_turn_unit_id = nick.id
			var before: int = enemy.hp
			fight.engine.execute_player_ability(nick.id, "gato_corte_fase", enemy.rank)
			hits[trained].append(before - fight.state.find_unit(enemy.id).hp)
	var sum_plain: int = hits[false].reduce(func(a, b): return a + b, 0)
	var sum_trained: int = hits[true].reduce(func(a, b): return a + b, 0)
	t.check(sum_trained > sum_plain, "o treino aumenta o dano do Corte de Fase (%d contra %d em 30 golpes)" % [sum_trained, sum_plain])


## O que cada herói fez na luta soma na expedição (o destaque do relatório da volta).
func _stats(t) -> void:
	var campaign: Dictionary = Campaign.create_initial(12)
	AHJourneyRules.start_expedition(campaign, "fase_1", 7)
	var session := AHCombatSession.create(campaign.roster.slice(0, 4), PATROLS[0], false, 3)
	var beats := 0
	while not session.is_over() and beats < 400:
		if session.is_player_turn():
			session.auto_player_turn()
		else:
			session.enemy_turn()
		beats += 1
	var damage := 0
	for hero_id in session.tally:
		damage += int(session.tally[hero_id].damage)
	t.check(damage > 0, "os heróis causaram dano contado (%d)" % damage)
	session.write_back(campaign)
	var stats: Dictionary = campaign.session.expedition.get("stats", {})
	var total := 0
	for hero_id in stats:
		total += int(stats[hero_id].damage)
	t.equal(total, damage, "a soma vai para a expedição")
	t.check(session.tally.is_empty(), "a contagem da luta zera depois de gravar")


## A intenção do HUD (engine.enemy_intent) é o que o inimigo faz: quando ela tem certeza, a ação usada é a mesma e o
## alvo (depois da proteção) também. Em 12 lutas, todas as vezes que o inimigo age.
func _intents(t, campaign: Dictionary) -> void:
	var checked := 0
	var checked_either := 0
	var mismatches: Array = []
	for patrol in PATROLS + [["porteiro"]]:
		for seed_value in range(6):
			var session := AHCombatSession.create(campaign.roster.duplicate(true), patrol, false, seed_value)
			var beats := 0
			while not session.is_over() and beats < 400:
				beats += 1
				if session.is_player_turn():
					session.auto_player_turn()
					continue
				var actor := session.current_actor()
				var intent := session.engine.enemy_intent(actor.id) if actor else {}
				# O sangramento e o veneno do começo do turno podem mudar tudo: compara só quem não sofre nada disso.
				var clean: bool = actor != null and not actor.bleed.is_set() and not actor.blight.is_set()
				var beat := session.enemy_turn()
				if clean and intent.get("either", false):
					var hit_any: Array = session.state.enemy_target_history
					checked_either += 1
					if beat.ability_id != intent.id or hit_any.is_empty() or not intent.target_ids.has(hit_any.back()):
						mismatches.append("%s: um de %s com %s, fez %s" % [actor.display_name, intent.target_ids, intent.id, beat.ability_id])
					continue
				if not clean or not intent.get("sure", false) or intent.kind != "attack":
					continue
				checked += 1
				var history: Array = session.state.enemy_target_history
				var hit: String = history.back() if not history.is_empty() else ""
				if beat.ability_id != intent.id or (intent.target_ids.size() == 1 and hit != intent.target_ids[0]):
					mismatches.append("%s: previsto %s em %s, fez %s em %s" % [actor.display_name, intent.id, intent.target_ids, beat.ability_id, hit])
	t.check(checked > 20, "a intenção foi conferida em %d ataques" % checked)
	t.check(checked_either > 0, "e em %d com um alvo ou outro (o golpe cai num deles)" % checked_either)
	t.check(mismatches.is_empty(), "a intenção certa é o que o inimigo faz (%s)" % ", ".join(mismatches.slice(0, 3)))
