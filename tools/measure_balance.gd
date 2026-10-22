## Mede o equilíbrio das patrulhas (#10) sem mudar nada no jogo: joga no automático todas as lutas do corredor de cada
## fase (as 4 patrulhas e o guardião, com os inimigos de J.corridor_enemies) com os quatro fundadores.
##   Godot --headless --path . --script res://tools/measure_balance.gd -- [--seeds=40] [--policy=auto|weak] [--option=base]
## Equipe: os quatro fundadores. --gear diz o que eles levam (relíquias e treinos da Pesquisa):
##   none (padrão: como saem da campanha nova) · typical (o progresso suposto de cada fase, em GEAR_TYPICAL) · max (as
##   quatro relíquias e os quatro treinos em qualquer fase).
## A luta do jogo não lê os treinos pesquisados (campaign.researched_skills não chega a context.researched_skills; só a
## paridade preenche). --wire-research simula essa ligação, para medir o que o treino daria.
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
## buscas. A Forja (4) e as relíquias (3 cada) cabem a partir da fase 2; a Pesquisa (3 sucatas e 2 fragmentos) mais um
## treino (3 fragmentos) só antes da fase 5. Para o Lucas ajustar; quem repete fases chega mais perto de max.
const GEAR_TYPICAL := {"fase_1": [0, 0], "fase_2": [1, 0], "fase_3": [2, 0], "fase_4": [3, 0], "fase_5": [4, 1]}
const OPTIONS := ["base", "hp25", "dmg1", "more", "lesscare"]
## O mais ferido recebe cuidado enquanto estiver abaixo desta fração da vida.
const CARE_BELOW := 0.7
const CARE_ORDER := ["iris_ampoule", "full_meal", "small_meal", "bandage"]

var seeds := 40
var policy := "auto"
var option := "base"
var gear := "none"
var wire_research := false
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
		elif arg == "--wire-research":
			wire_research = true
	if not POLICIES.has(policy) or not OPTIONS.has(option) or not GEARS.has(gear):
		push_error("Política (%s), opção (%s) ou gear (%s) desconhecido." % [" | ".join(POLICIES), " | ".join(OPTIONS), " | ".join(GEARS)])
		quit(1)
		return
	var team_text := "fundadores iniciais, sem relíquias nem treinos"
	if gear == "typical":
		team_text = "progresso suposto (relíquias/treinos) " + ", ".join(PHASES.map(func(id): return "%s %d/%d" % [id, GEAR_TYPICAL[id][0], GEAR_TYPICAL[id][1]]))
	elif gear == "max":
		team_text = "as 4 relíquias e os 4 treinos"
	print("política=%s opção=%s gear=%s sementes=%d · %s · treinos %s" % [policy, option, gear, seeds, team_text,
		"ligados na luta (simulado)" if wire_research else "como o jogo está (sem efeito na luta)"])
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
			var outcome := _fight(base.duplicate(true), index, seed_value)
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


func _new_campaign(seed_value: int, phase_id: String) -> Dictionary:
	var campaign: Dictionary = root.get_node("Campaign").create_initial(seed_value)
	_unlock(campaign)
	_equip(campaign, phase_id)
	J.start_expedition(campaign, phase_id, 1000 + seed_value * 7)
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
	var session = Session.create(heroes, enemies, false, seed_value * 131 + index)
	session.use_expedition(campaign)
	if wire_research:
		session.context.researched_skills = campaign.researched_skills.duplicate()
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
