## Mede o equilíbrio das patrulhas (#10) sem mudar nada no jogo: joga no automático todas as lutas do corredor de cada
## fase (as 4 patrulhas e o guardião, com os inimigos de J.corridor_enemies) com os quatro fundadores.
##   Godot --headless --path . --script res://tools/measure_balance.gd -- [--seeds=40] [--policy=auto|weak] [--option=base]
## Equipe: os quatro fundadores. --gear diz o que eles levam (relíquias e treinos da Pesquisa):
##   none (padrão: como saem da campanha nova) · typical (o progresso suposto de cada fase, em GEAR_TYPICAL) · max (as
##   quatro relíquias e os quatro treinos em qualquer fase).
## --levels diz o nível dos fundadores (#90): none (padrão: nível 1) · typical (o nível ao entrar em cada fase jogando as
##   anteriores uma vez: tirado da curva e do XP médio que as jornadas dão, com as mesmas sementes; muda junto com os
##   JSON) · fixed (o nível suposto da primeira proposta, LEVELS_FIXED) · max (nível 10). Cada treino escolhe a primeira
##   melhoria que o Alojamento oferece; as sementes do Treino não limitam aqui.
##   O XP médio por jornada conta só os fundadores que voltam vivos: na fase em que ninguém volta, sai 0.
## Os treinos pesquisados valem na luta (use_expedition leva campaign.researched_skills para o contexto, desde 22/10).
## Três medidas por fase:
## - luta a luta, cada uma numa cópia limpa da expedição (os quatro vivos e de vida cheia): vitórias, rodadas e a vida
##   que sobra;
## - a jornada inteira com cuidados, levando a vida e as mortes de uma luta para a outra: depois de cada vitória, o mais
##   ferido (abaixo de 70% da vida) recebe a ampola da Íris, a refeição, o lanche ou o curativo, com a comida grátis e
##   os curativos de verdade: quantas chegam ao fim do guardião e quantos heróis voltam;
## - a mesma jornada sem cuidados nenhum (o pior caso).
## Políticas: auto (a política fixa da paridade, a mesma do modo automático) e weak (habilidade usável e alvo
## sorteados por luta: uma pessoa jogando mal). Opções (simuladas só aqui):
##   base · hp25 (inimigos com +25% de vida) · dmg1 (+1 de dano) · more (+1 inimigo, cópia do da frente, nas patrulhas
##   com menos de 4) · lesscare (metade da comida grátis, 1 curativo e a ampola sem recarga na vitória).
## A coluna da jornada com cuidados mostra também quantas ampolas, em média, a Íris usou fora da luta.
## --effects=exposto,cansado,preparado (#78) põe os efeitos de fase dos eventos na expedição, como o jogo: na medida luta a
##   luta, cada luta começa com eles; na jornada, o Exposto vale só na primeira luta e os outros até o fim. Sem a opção, nenhum.
## --types=on|off (#227) liga ou desliga a vantagem de tipo (TypeAdvantage.Enabled) só nesta medida; sem a opção, como
##   está nos dados.
## --stars (#91) troca a tabela pelas estrelas da luta: a média, quantas lutas vencidas dão 1, 2 e 3 estrelas e quanto
##   cada critério é cumprido (AHFightRewards.criteria, as mesmas regras da tela do fim).
extends SceneTree

const PHASES := ["fase_1", "fase_2", "fase_3", "fase_4", "fase_5"]
const FOUNDERS := ["hero_cao_bento", "hero_gato_nick", "hero_sapo_iris", "hero_coruja_vespera"]
const ROUND_LIMIT := 400
const POLICIES := ["auto", "weak"]
const GEARS := ["none", "typical", "max"]
## Relíquias na ordem da formação (posição 1 a 4): vida na frente e atrás, velocidade no meio.
const RELIC_ORDER := ["botao_cobre", "pena_vidro", "pena_vidro", "botao_cobre"]
const TRAINING_ORDER := ["res_cao_punho_sucata", "res_gato_corte_fase", "res_sapo_carga_voltaica", "res_coruja_recurso_emergencia"]
## O progresso suposto ao entrar em cada fase sem repetir fases: [relíquias, treinos]. Pela economia: começa com 0 de
## sucata e de fragmento; cada fase vencida rende 3 sucatas e 1 fragmento do guardião, mais umas 2 a 4 sucatas das
## buscas (mais o foco Peças e o desconto do Otto). A Forja (4) e as relíquias (3 cada) cabem a partir da fase 2. Os
## guardiões dão só 4 fragmentos até a fase 5; a Pesquisa (2) mais um treino (3) pedem o quinto, da Cora (+1 por volta
## com a Pesquisa ligada) ou do evento que dá fragmento. Para o Lucas ajustar; quem repete fases chega mais perto de max.
const GEAR_TYPICAL := {"fase_1": [0, 0], "fase_2": [1, 0], "fase_3": [2, 0], "fase_4": [3, 0], "fase_5": [4, 1]}
const LEVELS := ["none", "typical", "fixed", "max"]
## O nível suposto ao entrar em cada fase sem repetir fases (o XP de umas 5 lutas e da jornada por fase, hero-xp.json, e a
## curva de hero-levels.json): para o Lucas ajustar com a curva.
const LEVELS_FIXED := {"fase_1": 1, "fase_2": 3, "fase_3": 4, "fase_4": 6, "fase_5": 7}
const OPTIONS := ["base", "hp25", "dmg1", "more", "lesscare"]
## O mais ferido recebe cuidado enquanto estiver abaixo desta fração da vida.
const CARE_BELOW := 0.7
const CARE_ORDER := ["iris_ampoule", "full_meal", "small_meal", "bandage"]

var seeds := 40
var policy := "auto"
var option := "base"
var gear := "none"
var levels := "none"
var stars := false
var effects: Array = []
## Por fase e tipo de luta: {wins, stars, by_stars [0, 1, 2, 3], criteria {id: cumpridos}}.
var _stars := {}
var _counting := false
## O nível típico de cada fase (--levels=typical), tirado da curva; e o XP médio de um fundador na jornada de cada fase.
var _typical := {}
var _journey_xp := {}
var _rng := RandomNumberGenerator.new()
## Ampolas da Íris usadas fora da luta nas jornadas com cuidados da fase (mostra o efeito do lesscare).
var _ampoules := 0
## Carregados na hora de rodar: com -s, o script compila antes dos autoloads (GameData) de que as regras dependem.
var J
var Session
var Care


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	J = load("res://scripts/flow/journey_rules.gd")
	Session = load("res://scripts/combat/combat_session.gd")
	Care = load("res://scripts/flow/exploration_care.gd")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = maxi(1, int(arg.trim_prefix("--seeds=")))
		elif arg.begins_with("--policy="):
			policy = arg.trim_prefix("--policy=")
		elif arg.begins_with("--option="):
			option = arg.trim_prefix("--option=")
		elif arg.begins_with("--gear="):
			gear = arg.trim_prefix("--gear=")
		elif arg.begins_with("--levels="):
			levels = arg.trim_prefix("--levels=")
		elif arg == "--stars":
			stars = true
		elif arg.begins_with("--types="):
			root.get_node("GameData").combat.type_advantage.Enabled = arg.trim_prefix("--types=") == "on"
		elif arg.begins_with("--effects="):
			effects = Array(arg.trim_prefix("--effects=").split(",", false))
	if not POLICIES.has(policy) or not OPTIONS.has(option) or not GEARS.has(gear) or not LEVELS.has(levels):
		push_error("Política (%s), opção (%s), gear (%s) ou níveis (%s) desconhecido." % [" | ".join(POLICIES), " | ".join(OPTIONS), " | ".join(GEARS), " | ".join(LEVELS)])
		quit(1)
		return
	var team_text := "fundadores iniciais, sem relíquias nem treinos"
	if gear == "typical":
		team_text = "progresso suposto (relíquias/treinos) " + ", ".join(PHASES.map(func(id): return "%s %d/%d" % [id, GEAR_TYPICAL[id][0], GEAR_TYPICAL[id][1]]))
	elif gear == "max":
		team_text = "as 4 relíquias e os 4 treinos"
	if levels != "none":
		if levels == "typical":
			_derive_typical()
		var table: Dictionary = _typical if levels == "typical" else LEVELS_FIXED
		team_text += " · níveis " + (", ".join(PHASES.map(func(id): return "%s %d" % [id, table[id]])) if levels != "max" else "10")
		if levels == "typical":
			team_text += " (XP por jornada: %s)" % ", ".join(PHASES.map(func(id): return "%.0f" % _journey_xp.get(id, 0.0)))
	for id in effects:
		if not J.PHASE_EFFECTS.has(id):
			push_error("Efeito desconhecido: %s (%s)." % [id, " | ".join(J.PHASE_EFFECTS.keys())])
			quit(1)
			return
	if not effects.is_empty():
		team_text += " · efeitos " + ", ".join(effects)
	team_text += " · vantagem de tipo " + ("ligada" if root.get_node("GameData").combat.type_advantage.Enabled else "desligada")
	print("política=%s opção=%s gear=%s níveis=%s sementes=%d · %s" % [policy, option, gear, levels, seeds, team_text])
	if stars:
		print("fase   | luta      | vitórias | estrelas | 1★ · 2★ · 3★          | ninguém caiu · rodadas · golpe final · instinto | rodadas das vitórias: 25% · mediana · 75%")
	else:
		print("fase   | luta      | vitórias | rodadas | vida que sobra | jornada com cuidados: termina · voltam | sem cuidados: termina · voltam")
	for phase_id in PHASES:
		_measure(phase_id)
	quit()


func _measure(phase_id: String) -> void:
	var stats := {}
	var journeys := {true: [0, 0], false: [0, 0]}
	_ampoules = 0
	for seed_value in seeds:
		# Luta a luta: cada uma numa cópia da expedição recém-criada.
		var base := _new_campaign(seed_value, phase_id)
		var steps: Array = base.session.expedition.corridor.steps
		for index in steps.size():
			var kind: String = steps[index].type
			if kind != "combat" and kind != "boss":
				continue
			var label := "guardião" if kind == "boss" else "patrulha"
			_counting = true
			var outcome := _fight(base.duplicate(true), index, seed_value)
			_counting = false
			var entry: Dictionary = stats.get(label, {"fights": 0, "wins": 0, "rounds": 0, "hp": 0.0})
			entry.fights += 1
			entry.wins += 1 if outcome.result == "victory" else 0
			entry.rounds += outcome.rounds
			entry.hp += outcome.hp_left
			stats[label] = entry
		# A jornada inteira, levando a vida, com e sem cuidados.
		for care in [true, false]:
			var carry := _new_campaign(seed_value, phase_id)
			var done := true
			for index in steps.size():
				if steps[index].type != "combat" and steps[index].type != "boss":
					continue
				if _fight(carry, index, seed_value).result != "victory":
					done = false
					break
				if care:
					_care(carry)
			journeys[care][0] += 1 if done else 0
			journeys[care][1] += carry.roster.filter(func(h): return FOUNDERS.has(h.id) and h.alive).size()
	if stars:
		_print_stars(phase_id, stats)
		return
	for label in ["patrulha", "guardião"]:
		var entry: Dictionary = stats.get(label, {})
		if entry.is_empty():
			continue
		var fights: int = entry.fights
		var tail := ""
		if label == "guardião":
			tail = "%5.0f%% · %.2f de 4 · %.1f ampolas     | %5.0f%% · %.2f de 4" % [100.0 * journeys[true][0] / seeds,
				float(journeys[true][1]) / seeds, float(_ampoules) / seeds, 100.0 * journeys[false][0] / seeds, float(journeys[false][1]) / seeds]
		print("%s | %-9s | %5.0f%%   | %5.1f   | %5.0f%%         | %s" % [phase_id, label, 100.0 * entry.wins / fights,
			float(entry.rounds) / fights, 100.0 * entry.hp / fights, tail])


func _new_campaign(seed_value: int, phase_id: String, level: int = 0) -> Dictionary:
	var campaign: Dictionary = root.get_node("Campaign").create_initial(seed_value)
	_unlock(campaign)
	_equip(campaign, phase_id)
	_level_up(campaign, phase_id, level)
	J.start_expedition(campaign, phase_id, 1000 + seed_value * 7)
	campaign.session.expedition.corridor.effects = effects.duplicate()
	if option == "lesscare":
		campaign.session.expedition.food = int(campaign.session.expedition.food) / 2
		campaign.inventory.bandages = mini(1, int(campaign.inventory.bandages))
	return campaign


## Depois da vitória, como um jogador cuidadoso: o mais ferido abaixo de CARE_BELOW recebe o primeiro cuidado que der.
func _care(campaign: Dictionary) -> void:
	for guard in 20:
		var worst = null
		for hero in campaign.roster:
			if FOUNDERS.has(hero.id) and hero.alive and hero.hp > 0 and float(hero.hp) / hero.max_hp < CARE_BELOW:
				if worst == null or float(hero.hp) / hero.max_hp < float(worst.hp) / worst.max_hp:
					worst = hero
		if worst == null:
			return
		var used := false
		for kind in CARE_ORDER:
			if Care.quote(campaign, worst.id, kind).available and Care.use(campaign, worst.id, kind) > 0:
				_ampoules += 1 if kind == "iris_ampoule" else 0
				used = true
				break
		if not used:
			return


## Relíquias na formação (RELIC_ORDER) e treinos pesquisados (TRAINING_ORDER), conforme --gear.
func _equip(campaign: Dictionary, phase_id: String) -> void:
	var counts: Array = [0, 0]
	if gear == "typical":
		counts = GEAR_TYPICAL[phase_id]
	elif gear == "max":
		counts = [RELIC_ORDER.size(), TRAINING_ORDER.size()]
	var formation: Array = campaign.preferred_formation
	for index in mini(counts[0], formation.size()):
		for hero in campaign.roster:
			if hero.id == formation[index]:
				hero.relic_id = RELIC_ORDER[index]
	for index in counts[1]:
		var row = root.get_node("GameData").row("research", TRAINING_ORDER[index])
		if not campaign.researched_skills.has(row.SkillId):
			campaign.researched_skills.append(row.SkillId)


## Os fundadores no nível de --levels: cada treino com a primeira melhoria oferecida (o XP e as sementes não contam aqui).
func _level_up(campaign: Dictionary, phase_id: String, forced: int = 0) -> void:
	var target: int = forced if forced > 0 else {"none": 1, "typical": int(_typical.get(phase_id, 1)), "fixed": LEVELS_FIXED[phase_id], "max": 10}[levels]
	var Levels = load("res://scripts/flow/hero_levels.gd")
	campaign.inventory.seeds = 9999
	for hero in campaign.roster:
		while Levels.level(hero) < target:
			hero.xp = 9999
			var options: Array = Levels.options(hero)
			if options.is_empty() or Levels.train(campaign, hero.id, options[0].Name) != "":
				break
		hero.xp = 0
	campaign.inventory.seeds = 30


func _unlock(campaign: Dictionary) -> void:
	campaign.completed_phases = PHASES.slice(0, 4)


## Uma luta do corredor no automático, com os fundadores vivos como estão. Devolve {result, rounds, hp_left (0..1)}.
func _fight(campaign: Dictionary, index: int, seed_value: int) -> Dictionary:
	var expedition: Dictionary = campaign.session.expedition
	expedition.corridor.index = index
	var heroes: Array = []
	for hero in campaign.roster:
		if FOUNDERS.has(hero.id) and hero.alive:
			heroes.append(hero)
	if heroes.is_empty():
		return {"result": "defeat", "rounds": 0, "hp_left": 0.0}
	var enemies: Array = _apply_option(J.corridor_enemies(expedition, index), expedition.corridor.steps[index].type == "boss")
	var session = Session.create(heroes, enemies, false, seed_value * 131 + index, 80, J.phase_effects(campaign))
	J.spend_fight_effects(campaign)
	session.use_expedition(campaign)
	# O sorteio da política fraca depende só da luta: as opções comparam as mesmas escolhas.
	_rng.seed = seed_value * 131 + index
	var beats := 0
	while not session.is_over() and beats < ROUND_LIMIT:
		if session.is_player_turn():
			if policy == "weak":
				_weak_turn(session)
			else:
				session.auto_player_turn()
		else:
			session.enemy_turn()
		beats += 1
	if stars and session.is_over():
		_count_stars(String(campaign.session.expedition.phase_id), expedition.corridor.steps[index].type == "boss", session)
	# write_back recarrega a ampola da Íris na vitória; em lesscare ela fica com as cargas que sobraram da luta.
	var kept := {}
	if option == "lesscare":
		for unit in session.state.player_team:
			if unit.remaining_uses.has(Care.AMPOULE):
				kept[unit.hero_id] = unit.remaining_uses[Care.AMPOULE]
	session.write_back(campaign)
	for hero in campaign.roster:
		if kept.has(hero.id) and hero.alive:
			hero.expedition_uses[Care.AMPOULE] = kept[hero.id]
	# Pela vida da campanha depois do write_back: a relíquia de vida aumenta o máximo só dentro da luta.
	var hp := 0.0
	var max_hp := 0.0
	for hero in heroes:
		hp += maxi(0, hero.hp) if hero.alive else 0
		max_hp += hero.max_hp
	return {"result": session.result() if session.is_over() else "timeout", "rounds": session.state.round,
		"hp_left": hp / max_hp if max_hp > 0.0 else 0.0}


## Uma pessoa jogando mal: habilidade usável e alvo sorteados; sem nenhuma, defende.
func _weak_turn(session) -> void:
	var actor = session.current_actor()
	var start: Dictionary = session.begin_player_turn()
	if not start.can_act or session.is_over():
		return
	var usable: Array = session.ability_options(actor.id).filter(func(o): return o.usable)
	if usable.is_empty():
		session.defend(actor.id)
		return
	var option_row: Dictionary = usable[_rng.randi_range(0, usable.size() - 1)]
	var rank: int = actor.rank if option_row.self else option_row.targets[_rng.randi_range(0, option_row.targets.size() - 1)]
	if not session.use_ability(actor.id, option_row.id, rank).get("ok", true):
		session.defend(actor.id)


func _apply_option(enemies: Array, boss: bool) -> Array:
	match option:
		"hp25":
			for spec in enemies:
				spec.max_hp = roundi(spec.max_hp * 1.25)
				spec.hp = spec.max_hp
		"dmg1":
			for spec in enemies:
				spec.damage_bonus = int(spec.get("damage_bonus", 0)) + 1
		"more":
			if not boss and enemies.size() < 4:
				var copy: Dictionary = enemies[0].duplicate()
				copy.unit_id += "_extra"
				copy.rank = enemies.size() + 1
				enemies.append(copy)
	return enemies


## As estrelas de uma luta acabada (só a luta a luta conta; a jornada passa pelas mesmas lutas e repetiria).
func _count_stars(phase_id: String, boss: bool, session) -> void:
	if not _counting:
		return
	var key := "%s:%s" % [phase_id, "guardião" if boss else "patrulha"]
	var entry: Dictionary = _stars.get(key, {"fights": 0, "wins": 0, "stars": 0, "by_stars": [0, 0, 0, 0], "criteria": {}, "rounds": []})
	var rewards: Dictionary = load("res://scripts/flow/fight_rewards.gd").criteria(session, boss, phase_id)
	entry.fights += 1
	if session.state.victory:
		entry.wins += 1
		entry.stars += rewards.stars
		entry.by_stars[rewards.stars] += 1
		entry.rounds.append(int(session.state.round))
		for criterion in rewards.list:
			entry.criteria[criterion.id] = int(entry.criteria.get(criterion.id, 0)) + (1 if criterion.met else 0)
	_stars[key] = entry


func _print_stars(phase_id: String, _stats: Dictionary) -> void:
	for label in ["patrulha", "guardião"]:
		var entry: Dictionary = _stars.get("%s:%s" % [phase_id, label], {})
		if entry.is_empty() or entry.fights == 0:
			continue
		var wins: int = maxi(1, entry.wins)
		var rate := func(id: String) -> float: return 100.0 * int(entry.criteria.get(id, 0)) / wins
		var rounds: Array = entry.rounds.duplicate()
		rounds.sort()
		var at := func(share: float) -> int: return int(rounds[mini(rounds.size() - 1, int(share * rounds.size()))]) if not rounds.is_empty() else 0
		print("%s | %-9s | %5.0f%%   | %5.2f    | %3.0f%% · %3.0f%% · %3.0f%%   | %5.0f%% · %5.0f%% · %5.0f%% · %5.0f%% | rodadas %d · %d · %d" % [phase_id, label,
			100.0 * entry.wins / entry.fights, float(entry.stars) / wins, 100.0 * entry.by_stars[1] / wins,
			100.0 * entry.by_stars[2] / wins, 100.0 * entry.by_stars[3] / wins, rate.call("no_falls"), rate.call("rounds"),
			rate.call("final_blow"), rate.call("calm"), at.call(0.25), at.call(0.5), at.call(0.75)])


## O nível típico (--levels=typical): joga as fases em ordem, uma vez cada. Ao entrar numa fase, cada fundador está no
## nível que o XP acumulado das anteriores paga na curva (hero-levels.json); o XP de uma fase é a média, nas sementes, do
## que um fundador vivo ganha na jornada com cuidados naquele nível (as lutas e, concluída, a jornada).
func _derive_typical() -> void:
	var Levels = load("res://scripts/flow/hero_levels.gd")
	var total := 0.0
	for phase_id in PHASES:
		var level := 1
		var spent := 0
		while level < Levels.MAX_LEVEL:
			var row = root.get_node("GameData").row("hero_levels", "level_%d" % (level + 1))
			if row == null or spent + int(row.Xp) > total:
				break
			spent += int(row.Xp)
			level += 1
		_typical[phase_id] = level
		var gained := 0.0
		var heroes := 0
		for seed_value in seeds:
			var carry := _new_campaign(seed_value, phase_id, level)
			var steps: Array = carry.session.expedition.corridor.steps
			var done := true
			for index in steps.size():
				if steps[index].type != "combat" and steps[index].type != "boss":
					continue
				if _fight(carry, index, seed_value).result != "victory":
					done = false
					break
				_care(carry)
			for hero in carry.roster:
				if FOUNDERS.has(hero.id) and hero.alive:
					gained += Levels.xp(hero) + (int(Levels.rule("journey").get("Xp", 0)) if done else 0)
					heroes += 1
		_journey_xp[phase_id] = gained / maxi(1, heroes)
		total += _journey_xp[phase_id]
