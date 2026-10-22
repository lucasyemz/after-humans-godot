## Mede o equilíbrio das patrulhas (#10) sem mudar nada no jogo: joga no automático todas as lutas do corredor de cada
## fase (as 4 patrulhas e o guardião, com os inimigos de J.corridor_enemies) com os quatro fundadores.
##   Godot --headless --path . --script res://tools/measure_balance.gd -- [--seeds=40] [--policy=auto|weak] [--option=base]
## Duas medidas por fase:
## - luta a luta, com a equipe de vida cheia em cada uma: vitórias, rodadas e a vida que sobra;
## - a jornada inteira, levando a vida (e as mortes) de uma luta para a outra, sem comida, curativo nem acampamento:
##   quantas chegam ao fim do guardião e quantos heróis voltam.
## Políticas: auto (a política fixa da paridade, a mesma do modo automático) e weak (habilidade usável e alvo
## sorteados: uma pessoa jogando mal). Opções (simuladas só aqui, nos inimigos antes da luta):
##   base · hp25 (inimigos com +25% de vida) · dmg1 (+1 de dano) · more (+1 inimigo nas patrulhas comuns).
extends SceneTree

const PHASES := ["fase_1", "fase_2", "fase_3", "fase_4", "fase_5"]
const FOUNDERS := ["hero_cao_bento", "hero_gato_nick", "hero_sapo_iris", "hero_coruja_vespera"]
const ROUND_LIMIT := 400

var seeds := 40
var policy := "auto"
var option := "base"
var _rng := RandomNumberGenerator.new()
## Carregados na hora de rodar: com -s, o script compila antes dos autoloads (GameData) de que as regras dependem.
var J
var Session


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	J = load("res://scripts/flow/journey_rules.gd")
	Session = load("res://scripts/combat/combat_session.gd")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = maxi(1, int(arg.trim_prefix("--seeds=")))
		elif arg.begins_with("--policy="):
			policy = arg.trim_prefix("--policy=")
		elif arg.begins_with("--option="):
			option = arg.trim_prefix("--option=")
	_rng.seed = 1
	print("política=%s opção=%s sementes=%d" % [policy, option, seeds])
	print("fase   | luta      | vitórias | rodadas | vida que sobra | jornada inteira: termina | heróis que voltam")
	for phase_id in PHASES:
		_measure(phase_id)
	quit()


func _measure(phase_id: String) -> void:
	var campaign_service = root.get_node("Campaign")
	var stats := {}
	var journeys_done := 0
	var survivors := 0
	for seed_value in seeds:
		# Luta a luta, de vida cheia.
		var fresh: Dictionary = campaign_service.create_initial(seed_value)
		_unlock(fresh)
		J.start_expedition(fresh, phase_id, 1000 + seed_value * 7)
		var route: Dictionary = fresh.session.expedition.corridor
		for index in route.steps.size():
			var kind: String = route.steps[index].type
			if kind != "combat" and kind != "boss":
				continue
			var label := "guardião" if kind == "boss" else "patrulha"
			var outcome := _fight(fresh, index, seed_value, true)
			var entry: Dictionary = stats.get(label, {"fights": 0, "wins": 0, "rounds": 0, "hp": 0.0})
			entry.fights += 1
			entry.wins += 1 if outcome.result == "victory" else 0
			entry.rounds += outcome.rounds
			entry.hp += outcome.hp_left
			stats[label] = entry
		# A jornada inteira, levando a vida.
		var carry: Dictionary = campaign_service.create_initial(seed_value)
		_unlock(carry)
		J.start_expedition(carry, phase_id, 1000 + seed_value * 7)
		var steps: Array = carry.session.expedition.corridor.steps
		var done := true
		for index in steps.size():
			if steps[index].type != "combat" and steps[index].type != "boss":
				continue
			if _fight(carry, index, seed_value, false).result != "victory":
				done = false
				break
		journeys_done += 1 if done else 0
		survivors += carry.roster.filter(func(h): return FOUNDERS.has(h.id) and h.alive).size()
	for label in ["patrulha", "guardião"]:
		var entry: Dictionary = stats.get(label, {})
		if entry.is_empty():
			continue
		var fights: int = entry.fights
		print("%s | %-9s | %5.0f%%   | %5.1f   | %5.0f%%         | %s" % [phase_id, label, 100.0 * entry.wins / fights,
			float(entry.rounds) / fights, 100.0 * entry.hp / fights,
			("%5.0f%%                   | %.2f de 4" % [100.0 * journeys_done / seeds, float(survivors) / seeds]) if label == "guardião" else ""])


func _unlock(campaign: Dictionary) -> void:
	campaign.completed_phases = PHASES.slice(0, 4)


## Uma luta do corredor no automático. fresh: a equipe entra de vida cheia. Devolve {result, rounds, hp_left (0..1)}.
func _fight(campaign: Dictionary, index: int, seed_value: int, fresh: bool) -> Dictionary:
	var expedition: Dictionary = campaign.session.expedition
	expedition.corridor.index = index
	var heroes: Array = []
	for hero in campaign.roster:
		if FOUNDERS.has(hero.id) and hero.alive:
			if fresh:
				hero.hp = hero.max_hp
				hero.instinct = 0
			heroes.append(hero)
	if heroes.is_empty():
		return {"result": "defeat", "rounds": 0, "hp_left": 0.0}
	var enemies: Array = _apply_option(J.corridor_enemies(expedition, index), expedition.corridor.steps[index].type == "boss")
	var session = Session.create(heroes, enemies, false, seed_value * 131 + index)
	session.use_expedition(campaign)
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
	session.write_back(campaign)
	var hp := 0.0
	var max_hp := 0.0
	for unit in session.state.player_team:
		hp += maxi(0, unit.hp)
		max_hp += unit.max_hp
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
