## Motor de combate: port de Source/AfterHumans/Combat/AHCombatEngine.cpp (que já era o port de combatEngine.ts).
## Sem cena: lê os dados, altera o estado e devolve eventos. A ordem das chamadas a random.next() segue o C++ linha a
## linha: mudar a ordem quebra a paridade (tests/test_combat_parity.gd). Os textos do log seguem os do C++.
class_name AHCombatEngine
extends RefCounted

const CRITICAL_CHANCE := 0.1
const CRITICAL_MULTIPLIER := 1.5
const TOKEN_CAP := 3
const DOT_CAP := 6
const BLIND_MISS_PERCENT := 25
const WEAKNESS_REDUCTION_PERCENT := 25

const Unit = AHCombat.Unit
const EventType = AHCombat.EventType
const Outcome = AHCombat.Outcome

var state: AHCombat.State
var context: AHCombat.Context
var data: AHGameData
var random: AHCombatRandom
## Unidades que já tiveram crise neste lote de eventos.
var _crisis_batch := {}


func _init(in_state: AHCombat.State, in_context: AHCombat.Context, in_data: AHGameData, in_random: AHCombatRandom) -> void:
	state = in_state
	context = in_context
	data = in_data
	random = in_random


# ---------------------------------------------------------------- utilidades

static func alive_any(unit: Unit) -> bool:
	return unit.hp > 0 or unit.deaths_door


static func short_action_id(row_name: String) -> String:
	var dot := row_name.find(".")
	return row_name.substr(dot + 1) if dot >= 0 else row_name


## Peso de um caractere no localeCompare da web: pontuação < dígitos < letras, sem caixa.
static func _collation_weight(c: int) -> int:
	if c >= 48 and c <= 57:
		return 1000 + (c - 48)
	if (c >= 65 and c <= 90) or (c >= 97 and c <= 122):
		return 2000 + (c + 32 if c <= 90 else c)
	return c


static func compare_ids(a: String, b: String) -> int:
	for i in mini(a.length(), b.length()):
		var diff := _collation_weight(a.unicode_at(i)) - _collation_weight(b.unicode_at(i))
		if diff != 0:
			return diff
	return a.length() - b.length()


## Ordenação estável (Array.sort do JS e Algo::StableSort); sort_custom da Godot não é estável.
static func stable_sort(items: Array, less: Callable) -> void:
	for i in range(1, items.size()):
		var item = items[i]
		var j := i - 1
		while j >= 0 and less.call(item, items[j]):
			items[j + 1] = items[j]
			j -= 1
		items[j + 1] = item


static func _find(items: Array, predicate: Callable):
	for item in items:
		if predicate.call(item):
			return item
	return null


static func _any(items: Array, predicate: Callable) -> bool:
	return _find(items, predicate) != null


static func is_direct_attack(ability: Dictionary) -> bool:
	return ability.DamageRange.Max > 0 and (ability.TargetType == "SingleEnemy" or ability.TargetType == "MarkedEnemy")


static func status_damage(raw_damage: int, weak: bool) -> int:
	if raw_damage <= 0:
		return 0
	var reduced := raw_damage * (100 - WEAKNESS_REDUCTION_PERCENT) / 100 if weak else raw_damage
	return reduced if reduced > 0 else 1


static func can_move_voluntarily(unit: Unit, occupant: Unit = null) -> bool:
	return unit.immobilize_turns <= 0 and (occupant == null or occupant.immobilize_turns <= 0)


static func attack_status_description(unit: Unit, machine: bool) -> String:
	var parts := PackedStringArray()
	if unit.blind:
		parts.append(TranslationServer.translate("%s: %d%% de falhar por alvo no próximo ataque de dano direto.") % [TranslationServer.translate("Interferência") if machine else TranslationServer.translate("Cegueira"), BLIND_MISS_PERCENT])
	if unit.weak:
		parts.append(TranslationServer.translate("Fraqueza: -%d%% de dano no próximo ataque de dano direto (mínimo 1).") % WEAKNESS_REDUCTION_PERCENT)
	if unit.blind or unit.weak:
		parts.append(TranslationServer.translate("Consome ao tentar, mesmo se errar; não acumula. Cura, suporte e dano periódico não consomem. Até atacar ou limpar."))
	if unit.immobilize_turns > 0:
		parts.append(TranslationServer.translate("Imobilização: %d turno(s) sem trocar de posição, avançar ou recuar por habilidade; pode atacar. Empurrões e fuga coletiva ainda funcionam. Diminui ao fim do próprio turno, inclusive atordoado.") % unit.immobilize_turns)
	return " ".join(parts)


## Gasta cegueira e fraqueza numa ação de dano direto (uma vez por ação, para todos os alvos).
static func _consume_attempt(direct_hostile_attack: bool, unit: Unit) -> Dictionary:
	var attempt := {"blind": false, "weak": false}
	if direct_hostile_attack:
		attempt = {"blind": unit.blind, "weak": unit.weak}
		unit.blind = false
		unit.weak = false
	return attempt


static func _add_event(events: Array, text: String, type: int, target_id: String, amount: int = 0, ability_id: String = "") -> AHCombat.Event:
	var event := AHCombat.Event.new()
	event.text = text
	event.type = type
	event.target_unit_id = target_id
	event.amount = amount
	event.ability_id = ability_id
	events.append(event)
	return event


func _log(line: String) -> void:
	state.combat_log.append(line)


## O nome da unidade nas mensagens (#35): o do herói como está, o do inimigo traduzido (com o sufixo da rota).
func _n(unit: Unit) -> String:
	return unit.display_name if unit.is_player else AHCombatHud.unit_name(unit.display_name)


## A causa de uma morte (state.deaths, que vai para o memorial no save) fica em português, como os ids: esta função a
## traduz na hora de mostrar. "Robô (Golpe mecânico)" traduz as duas partes; um efeito ("Sangramento"), inteiro.
static func cause_text(cause: String) -> String:
	var open := cause.rfind(" (")
	if open > 0 and cause.ends_with(")"):
		var who := cause.substr(0, open)
		var what := cause.substr(open + 2, cause.length() - open - 3)
		return "%s (%s)" % [AHCombatHud.unit_name(who), TranslationServer.translate(what)]
	return AHCombatHud.unit_name(cause)


func _roll_range(min_value: int, max_value: int) -> int:
	return floori(random.next() * (max_value - min_value + 1)) + min_value


func _find_unit(unit_id: String) -> Unit:
	return state.find_unit(unit_id)


# ---------------------------------------------------------------- dados

func find_class(class_id: String):
	return data.classes.get(class_id)


func find_ability(ability_id: String):
	return data.abilities.get(ability_id)


func find_enemy(enemy_id: String):
	return data.enemies.get(enemy_id) if enemy_id != "" else null


func find_enemy_action(action_id: String):
	return data.enemy_actions.get(action_id)


func find_perk(perk_id: String):
	return data.perks.get(perk_id)


func instinct_rules() -> Dictionary:
	return data.instinct.get("Default", AHGameData._merge(AHGameData.INSTINCT, {}))


# ---------------------------------------------------------------- posições e status

func unit_size(unit: Unit) -> int:
	var enemy = find_enemy(unit.enemy_id)
	return enemy.FormationSize if enemy != null and enemy.FormationSize > 0 else 1


func occupies_rank(unit: Unit, rank: int) -> bool:
	return rank >= unit.rank and rank < unit.rank + unit_size(unit)


func can_reach(ranks: Array, unit: Unit) -> bool:
	for rank in ranks:
		if occupies_rank(unit, rank):
			return true
	return false


func is_machine(unit: Unit) -> bool:
	var enemy = find_enemy(unit.enemy_id)
	return enemy != null and enemy.Category == "Machine"


func status_name(effect: String, machine: bool) -> String:
	match effect:
		"bleed": return "Vazamento" if machine else "Sangramento"
		"blight": return "Corrosão" if machine else "Contaminação"
		"block": return "Blindagem ativa" if machine else "Bloqueio"
		"vuln": return "Estrutura exposta" if machine else "Vulnerável"
	return "Deslocamento"


func _resisted_effect(unit: Unit, dot: bool) -> bool:
	# Sangramento e contaminação usam dotResist (0,2 sem inimigo); só sorteia entre 0 e 1.
	var enemy = find_enemy(unit.enemy_id)
	var value: float = (enemy.DotResist if enemy != null else 0.2) if dot else 0.0
	return value >= 1.0 or (value > 0.0 and random.next() < value)


func relationship_key(a: String, b: String) -> String:
	# [a, b].sort().join('_'): ordem por código de caractere.
	return a + "_" + b if a.casecmp_to(b) <= 0 else b + "_" + a


func _sort_team(team: Array) -> void:
	# Estável: as unidades mortas (posição 0) vão para o começo.
	stable_sort(team, func(a, b): return a.rank < b.rank)


func _apply_control_effects(target: Unit, blind: bool, weak: bool, immobilize: int, events: Array) -> void:
	if not target.is_standing():
		return
	target.blind = target.blind or blind
	target.weak = target.weak or weak
	target.immobilize_turns = maxi(target.immobilize_turns, immobilize)
	if blind:
		_add_event(events, tr("Interferência") if is_machine(target) else tr("Cegueira"), EventType.INFO, target.id).outcome = Outcome.BLIND_APPLIED
	if weak:
		_add_event(events, tr("Fraqueza"), EventType.INFO, target.id)
	if immobilize > 0:
		_add_event(events, tr("Imobilização · %d turnos") % target.immobilize_turns, EventType.INFO, target.id)
	if blind or weak or immobilize > 0:
		_log(_n(target) + ": " + attack_status_description(target, is_machine(target)))


func _misses_from_blind(attempt: Dictionary, target: Unit, events: Array) -> bool:
	# Sem sorteio extra quando não há cegueira: as lutas antigas mantêm a sequência.
	if not attempt.blind or not (random.next() < BLIND_MISS_PERCENT / 100.0):
		return false
	_add_event(events, tr("FALHOU · precisão reduzida"), EventType.INFO, target.id)
	_log(tr("O ataque falhou por cegueira/interferência contra ") + _n(target) + ".")
	return true


func _hit_ids_from(target: Unit, ability: Dictionary, target_rank: int, opposing: Array) -> Array:
	var hit_ids: Array = []
	if ability.bTargetPair:
		var start := 1 if target_rank <= 2 else 3
		for unit in opposing:
			if alive_any(unit) and unit.rank <= start + 1 and unit.rank + unit_size(unit) - 1 >= start and not hit_ids.has(unit.id):
				hit_ids.append(unit.id)
	else:
		hit_ids.append(target.id)
		if ability.bAdjacentTarget:
			var behind := target.rank + unit_size(target)
			var adjacent = _find(opposing, func(u): return u.id != target.id and alive_any(u) and occupies_rank(u, behind))
			if adjacent == null:
				adjacent = _find(opposing, func(u): return u.id != target.id and alive_any(u) and occupies_rank(u, target.rank - 1))
			if adjacent != null and not hit_ids.has(adjacent.id):
				hit_ids.append(adjacent.id)
	return hit_ids


# ---------------------------------------------------------------- início e rodadas

## Unidade de herói a partir da campanha. hero: Id, ClassId, DisplayName, MaxHp, Hp, Instinct, Perks, Trauma, RelicId.
static func make_hero_unit(hero: Dictionary, rank: int, game_data: AHGameData) -> Unit:
	var unit := Unit.new()
	unit.id = "unit_" + hero.Id
	unit.is_player = true
	unit.hero_id = hero.Id
	unit.class_id = hero.ClassId
	unit.display_name = hero.DisplayName
	unit.rank = rank
	unit.hp = hero.Hp
	unit.instinct = hero.get("Instinct", 0)
	unit.perks = hero.get("Perks", []).duplicate()
	unit.trauma = hero.get("Trauma", false)
	unit.deaths_door = hero.Hp <= 0
	unit.sprite_key = hero.ClassId
	unit.remaining_uses = hero.get("ExpeditionUses", {}).duplicate()
	# O nível do herói (#90): +1 numa habilidade (como o treino da Pesquisa) e a velocidade; sem nível, nada muda.
	unit.ability_bonus = hero.get("AbilityBonus", {}).duplicate()

	var hero_class = game_data.classes.get(hero.ClassId)
	var relic = game_data.relics.get(hero.get("RelicId", ""))
	var perk_speed := 0
	var seen := {}
	for perk_id in unit.perks:
		if seen.has(perk_id):
			continue
		seen[perk_id] = true
		var perk = game_data.perks.get(perk_id)
		if perk != null:
			perk_speed += perk.Speed
	unit.max_hp = mini(200, hero.MaxHp + (relic.MaxHpBonus if relic != null else 0))
	unit.speed = (hero_class.BaseSpeed if hero_class != null and hero_class.BaseSpeed != 0 else 2) + (relic.SpeedBonus if relic != null else 0) + perk_speed \
		+ int(hero.get("SpeedBonus", 0))
	return unit


static func make_enemy_unit(enemy_id: String, unit_id: String, rank: int, game_data: AHGameData) -> Unit:
	var unit := Unit.new()
	unit.id = unit_id
	unit.enemy_id = enemy_id
	unit.rank = rank
	var enemy = game_data.enemies.get(enemy_id)
	if enemy != null:
		unit.display_name = enemy.DisplayName
		unit.hp = enemy.MaxHp
		unit.max_hp = enemy.MaxHp
		unit.speed = enemy.Speed
		unit.sprite_key = enemy.SpriteKey
	return unit


## Monta o estado e sorteia a primeira rodada (initCombat).
static func init_combat(player_units: Array, enemy_units: Array, in_context: AHCombat.Context, game_data: AHGameData,
		in_random: AHCombatRandom, opening_ally_first: bool, preserve_enemy_formation: bool = true) -> AHCombat.State:
	var new_state := AHCombat.State.new()
	var engine := AHCombatEngine.new(new_state, in_context, game_data, in_random)
	enemy_units = enemy_units.duplicate()

	if not preserve_enemy_formation:
		# randomizeEnemyFormation: Fisher-Yates e posições seguidas pelo tamanho.
		for i in range(enemy_units.size() - 1, 0, -1):
			var j := floori(in_random.next() * (i + 1))
			var swap = enemy_units[i]
			enemy_units[i] = enemy_units[j]
			enemy_units[j] = swap
		var next_rank := 1
		for unit in enemy_units:
			unit.rank = next_rank
			next_rank += engine.unit_size(unit)

	# Habilidades limitadas recarregam a cada encontro, dos dois lados.
	for team in [player_units, enemy_units]:
		for unit in team:
			var unit_class = engine.find_class(unit.class_id)
			for ability_id in (unit_class.AbilityIds if unit_class != null else []):
				var ability = engine.find_ability(ability_id)
				if ability != null and ability.UsesMax > 0:
					if not ability.bUsesPerExpedition or not unit.remaining_uses.has(ability_id):
						unit.remaining_uses[ability_id] = ability.UsesMax

	new_state.player_team = player_units.duplicate()
	new_state.enemy_team = enemy_units
	new_state.combat_log.append(TranslationServer.translate("Combate iniciado nas ruínas do Bairro Submerso!"))
	engine._roll_initiative_for_round(opening_ally_first)
	return new_state


func _roll_initiative_for_round(opening_ally_first: bool = false) -> void:
	var queue: Array = []
	var add_roll := func(unit: Unit):
		var item := AHCombat.InitiativeItem.new()
		item.unit_id = unit.id
		item.is_player = unit.is_player
		item.initiative = unit.speed + floori(random.next() * 4)
		queue.append(item)
	for unit in state.player_team:
		if unit.hp > 0 or unit.deaths_door:
			add_roll.call(unit)
	for unit in state.enemy_team:
		if unit.hp > 0:
			add_roll.call(unit)

	stable_sort(queue, func(a, b): return a.initiative > b.initiative if a.initiative != b.initiative else compare_ids(a.unit_id, b.unit_id) < 0)

	# Vantagem de abertura: só na primeira rodada, um aliado não atordoado age primeiro.
	if opening_ally_first and state.round == 1:
		var eligible: Array = []
		for index in queue.size():
			var item = queue[index]
			var unit = _find(state.player_team, func(u): return u.id == item.unit_id) if item.is_player else null
			if item.is_player and not (unit != null and unit.stun_turns != 0):
				eligible.append(index)
		if not eligible.is_empty():
			var chosen: int = eligible[floori(random.next() * eligible.size())]
			var first = queue[chosen]
			queue.remove_at(chosen)
			queue.insert(0, first)
			_log(tr("Fase inicial: um aliado toma a iniciativa."))
	state.initiative_queue = queue
	_advance_to_next_actor()


func _advance_to_next_actor() -> void:
	var enemies_alive := _any(state.enemy_team, func(u): return u.hp > 0)
	var players_alive := _any(state.player_team, func(u): return u.hp > 0 or u.deaths_door)
	if not enemies_alive:
		state.is_over = true
		state.victory = true
		_log(tr("Vitória! A ameaça foi neutralizada."))
		return
	if not players_alive:
		state.is_over = true
		state.victory = false
		_log(tr("Todos os aliados caíram nas ruínas escuras..."))
		return

	var next = _find(state.initiative_queue, func(item):
		if item.acted:
			return false
		if item.is_player:
			return _any(state.player_team, func(u): return u.id == item.unit_id and (u.hp > 0 or u.deaths_door))
		return _any(state.enemy_team, func(u): return u.id == item.unit_id and u.hp > 0))
	if next == null:
		state.round += 1
		_log(tr("--- Rodada %d ---") % state.round)
		_roll_initiative_for_round()
		return

	state.current_turn_unit_id = next.unit_id
	var current := _find_unit(next.unit_id)
	if current == null:
		next.acted = true
		_advance_to_next_actor()
		return

	# Porteiro na fase 1: os Condutores vivos lhe dão Bloqueio no início do turno.
	if not current.is_player and current.enemy_id == "porteiro" and state.boss_phase == 1:
		var conductors := _any(state.enemy_team, func(u): return u.hp > 0 and u.enemy_id == "condutor_raiz")
		if conductors and current.hp > 45:
			current.tokens.block = mini(TOKEN_CAP, current.tokens.block + 1)
			_log(tr("O Porteiro canalizou energia dos Relés de Defesa e gerou Bloqueio!"))


## O alvo protegido de cada unidade, por identidade (guarda do turno) ou por posição.
func _guarded_ids(team: Array, candidates: Array) -> Dictionary:
	var guarded := {}
	for unit in team:
		var target = _find(candidates, func(t):
			return t.id == unit.guard_target_id if unit.guard_for_turn else (unit.guard_target_rank != 0 and t.rank == unit.guard_target_rank))
		guarded[unit.id] = target.id if target != null else ""
	return guarded


func _compact_team_ranks(team: Array) -> void:
	var alive: Array = []
	for unit in team:
		if unit.hp > 0 or (unit.is_player and unit.deaths_door):
			alive.append(unit)
	var guarded := _guarded_ids(team, alive)
	for unit in team:
		if not alive.has(unit):
			unit.rank = 0
			unit.tokens.guard = 0
			unit.guard_target_rank = 0
	stable_sort(alive, func(a, b): return a.rank < b.rank)
	var next_rank := 1
	for unit in alive:
		unit.rank = next_rank
		next_rank += unit_size(unit)
	for unit in alive:
		var guarded_id: String = guarded.get(unit.id, "")
		var target = _find(alive, func(t): return guarded_id != "" and t.id == guarded_id)
		unit.guard_target_rank = target.rank if target != null else 0
		if target == null:
			unit.tokens.guard = 0


# ---------------------------------------------------------------- instinto

func _change_instinct(unit: Unit, delta: int, reason: String) -> void:
	if is_machine(unit):
		return
	var max_value: int = instinct_rules().Max
	var before := clampi(unit.instinct, 0, max_value)
	unit.instinct = clampi(before + delta, 0, max_value)
	if unit.instinct != before:
		unit.instinct_history.append({"reason": reason, "delta": unit.instinct - before, "value": unit.instinct})
		while unit.instinct_history.size() > 6:
			unit.instinct_history.pop_front()


func _virtue_chance(perks: Array) -> float:
	var total: float = instinct_rules().Crisis.BaseVirtue
	var seen := {}
	for perk_id in perks:
		if seen.has(perk_id):
			continue
		seen[perk_id] = true
		var perk = find_perk(perk_id)
		if perk != null:
			total += perk.Virtue
	return maxf(0.1, minf(0.4, total))


func _activate_perk(unit: Unit, perk_id: String, out_events: Array) -> void:
	var perk = find_perk(perk_id)
	if perk == null or not unit.perks.has(perk_id) or unit.perk_activations.get(perk_id, -1) == state.round:
		return
	unit.perk_activations[perk_id] = state.round
	var value := floori(perk.Value + 0.5)
	_change_instinct(unit, value, perk.DisplayName)
	_add_event(out_events, tr("%s: %s%d Instinto") % [tr(perk.DisplayName), "+" if value > 0 else "", value], EventType.INSTINCT, unit.id)
	_log(tr("%s · %s: %d Instinto") % [_n(unit), tr(perk.DisplayName), value])


func _apply_instinct_crisis(unit: Unit, out_events: Array) -> void:
	var rules := instinct_rules()
	unit.instinct = clampi(unit.instinct, 0, rules.Max)
	if not unit.is_player or is_machine(unit) or (unit.hp <= 0 and not unit.deaths_door) or unit.instinct < rules.Max:
		return
	# Uma crise por unidade por lote de eventos; uma segunda só volta o instinto ao nível de reinício.
	if _crisis_batch.has(unit.id):
		unit.instinct = rules.Crisis.Reset
		return
	_crisis_batch[unit.id] = true

	var chance := _virtue_chance(unit.perks)
	unit.crisis_count += 1
	var collapse := random.next() >= chance
	_change_instinct(unit, rules.Crisis.Reset - unit.instinct, tr("Colapso") if collapse else tr("Superação"))
	unit.crisis_outcome = AHCombat.Crisis.COLLAPSE if collapse else AHCombat.Crisis.BREAKTHROUGH
	if collapse:
		unit.tokens.vuln = mini(TOKEN_CAP, unit.tokens.vuln + 1)
	else:
		unit.tokens.block = mini(TOKEN_CAP, unit.tokens.block + 1)

	var bond_delta := -1 if collapse else 1
	if collapse:
		unit.trauma = true
		var hp_loss := floori(unit.max_hp * rules.Crisis.HpLoss)
		if unit.hp > 0:
			unit.hp = maxi(1, unit.hp - hp_loss)
		_add_event(out_events, tr("%s · Colapso: “Não consigo!” · Trauma e Vulnerável") % _n(unit), EventType.CRISIS, unit.id)
		_log(tr("[COLAPSO] %s cedeu ao pânico e desespero! (-%d Vida, Trauma adquirido)") % [_n(unit), hp_loss])
	else:
		var hp_heal := mini(unit.max_hp - unit.hp, maxi(1, floori(unit.max_hp * rules.Crisis.HpHeal)))
		unit.hp = mini(unit.max_hp, unit.hp + hp_heal)
		if unit.deaths_door and unit.hp > 0:
			unit.deaths_door = false
		_add_event(out_events, tr("%s · Superação: “Ainda há esperança!” · Bloqueio") % _n(unit), EventType.CRISIS, unit.id)
		_log(tr("[SUPERAÇÃO] A coragem de %s resplandece na escuridão! (+%d Vida)") % [_n(unit), hp_heal])

	# Laços da expedição: colapso afasta, superação aproxima (-3 a +3).
	if unit.hero_id != "":
		for other in state.player_team:
			if other.hero_id != "" and other.hero_id != unit.hero_id:
				var key := relationship_key(unit.hero_id, other.hero_id)
				context.relationships[key] = clampi(context.relationships.get(key, 0) + bond_delta, -3, 3)


# ---------------------------------------------------------------- dano

func _process_turn_start_dot(unit: Unit, out_events: Array) -> bool:
	if unit.hp <= 0 and not unit.deaths_door:
		return false
	# Sangramento e depois contaminação.
	for bleed in [true, false]:
		var dot: AHCombat.Dot = unit.bleed if bleed else unit.blight
		if dot.magnitude > 0 and dot.duration > 0:
			var damage := dot.magnitude
			dot.duration -= 1
			if dot.duration <= 0:
				dot.clear()
			var dot_name := status_name("bleed" if bleed else "blight", is_machine(unit))
			var damaged_id := unit.id
			_apply_damage(unit, damage, false, out_events, dot_name)
			_add_event(out_events, "-%d %s" % [damage, tr(dot_name)], EventType.DAMAGE, damaged_id, damage)
			if not _find_unit(damaged_id).is_standing():
				return false
	if unit.stun_turns > 0:
		unit.stun_turns -= 1
		_add_event(out_events, tr("Atordoado · turno perdido"), EventType.INFO, unit.id).turn_skipped_stun = true
		_log(tr("%s perdeu o turno por atordoamento (%d restantes).") % [_n(unit), unit.stun_turns])
		return false
	return true


## Redução do bloqueio, em float32 como AHKitRules::BlockReduction.
static func _block_reduction(pierce_percent: int, corroded: bool) -> float:
	var pierce := clampi(pierce_percent, 0, 100)
	var base := AHGameData.f32(0.5 * AHGameData.f32(1.0 - AHGameData.f32(pierce / 100.0)))
	return AHGameData.f32(base * (0.5 if corroded else 1.0))


func _apply_damage(unit: Unit, raw_damage: int, direct_attack: bool, out_events: Array, source_label: String,
		armor_pierce_percent: int = 0, skip_vulnerability: bool = false) -> void:
	var damage := raw_damage
	if direct_attack:
		if unit.tokens.vuln > 0 and not skip_vulnerability:
			unit.tokens.vuln -= 1
			damage = floori(damage * 1.5)
			_add_event(out_events, tr("Vulnerável!"), EventType.INFO, unit.id)
		if unit.tokens.block > 0:
			unit.tokens.block -= 1
			if is_machine(unit):
				_add_event(out_events, tr("Blindagem consumida"), EventType.BLOCK, unit.id)
			var reduction := _block_reduction(armor_pierce_percent, unit.armor_break_turns > 0)
			damage = floori(AHGameData.f32(damage * AHGameData.f32(1.0 - reduction)))
			_add_event(out_events, tr("Bloqueio!"), EventType.BLOCK, unit.id)
		damage = maxi(1, damage)

	if unit.is_player:
		# Já na Porta da Morte: teste de morte de 50%.
		if unit.hp == 0 and unit.deaths_door:
			if random.next() < 0.5:
				unit.hp = 0
				unit.deaths_door = false
				unit.blind = false
				unit.weak = false
				unit.immobilize_turns = 0
				_add_event(out_events, tr("MORTE PERMANENTE!"), EventType.DEATH, unit.id)
				_log(tr("[MORTE] %s sucumbiu ao golpe fatal de %s!") % [_n(unit), cause_text(source_label)])
				if unit.hero_id != "":
					state.deaths.append({"hero_id": unit.hero_id, "cause": source_label})
				# Os sobreviventes recebem +20 de instinto uma vez.
				for ally in state.player_team:
					if ally.id != unit.id and (ally.hp > 0 or ally.deaths_door):
						_change_instinct(ally, 20, tr("Pressão de combate"))
						_apply_instinct_crisis(ally, out_events)
				_compact_team_ranks(state.player_team)
			else:
				_add_event(out_events, tr("Sobreviveu ao Último Fôlego!"), EventType.INFO, unit.id)
				_log(tr("%s resistiu à morte por um triz!") % _n(unit))
			return

		unit.hp = maxi(context.min_hero_hp, unit.hp - damage)
		if unit.hp == 0:
			unit.deaths_door = true
			_add_event(out_events, tr("ÚLTIMO FÔLEGO!"), EventType.INFO, unit.id)
			_log(tr("[ÚLTIMO FÔLEGO] %s está à beira da morte!") % _n(unit))
			for ally in state.player_team:
				if ally.id != unit.id and (ally.hp > 0 or ally.deaths_door):
					_change_instinct(ally, 8, tr("Pressão de combate"))
					_apply_instinct_crisis(ally, out_events)
			# Amizade (+3): o parceiro ergue a guarda.
			if unit.hero_id != "":
				for ally in state.player_team:
					if ally.hero_id != "" and ally.hero_id != unit.hero_id and context.relationships.get(relationship_key(unit.hero_id, ally.hero_id), 0) >= 3:
						ally.tokens.block = mini(TOKEN_CAP, ally.tokens.block + 1)
						_log(tr("[AMIZADE] %s ergueu a guarda para proteger %s!") % [_n(ally), _n(unit)])
		# Esperança baixa: golpes diretos pesam no instinto.
		if direct_attack:
			var hope_instinct := 4 if context.hope == 0 else (2 if context.hope <= 25 else 0)
			if hope_instinct > 0:
				_change_instinct(unit, hope_instinct, tr("Pressão de combate"))
				_apply_instinct_crisis(unit, out_events)
		return

	unit.hp = maxi(0, unit.hp - damage)
	# Porteiro em 45 de vida ou menos: fase 2, perde os bloqueios.
	if unit.enemy_id == "porteiro" and unit.hp <= 45 and state.boss_phase == 1:
		state.boss_phase = 2
		unit.tokens.block = 0
		_add_event(out_events, tr("SOBRECARGA DO PORTEIRO!"), EventType.CRIT, unit.id)
		_log(tr("[SOBRECARGA] Os cabos do Porteiro se romperam em chamas verdes! Seus bloqueios caíram e seu ataque tornou-se brutal!"))
	if unit.hp == 0:
		unit.blind = false
		unit.weak = false
		unit.immobilize_turns = 0
		_add_event(out_events, tr("Derrotado!"), EventType.DEATH, unit.id)
		_log(tr("%s foi destruído.") % _n(unit))
		_compact_team_ranks(state.enemy_team)


func _apply_dot(target: Unit, bleed: bool, inflicted: Dictionary, out_events: Array, enemy_source: bool) -> void:
	var dot_name := status_name("bleed" if bleed else "blight", is_machine(target))
	if _resisted_effect(target, true):
		_add_event(out_events, tr("Resistiu ao ") + tr(dot_name), EventType.INFO, target.id)
		return
	var current: AHCombat.Dot = target.bleed if bleed else target.blight
	current.magnitude = mini(DOT_CAP, current.magnitude + inflicted.Magnitude)
	current.duration = maxi(current.duration, inflicted.Duration)
	if enemy_source:
		_add_event(out_events, "%s +%d" % [tr("Sangramento") if bleed else tr("Contaminação"), inflicted.Magnitude], EventType.INFO, target.id)
	else:
		_add_event(out_events, tr("%s aplicado · %d dano (%dt)") % [tr(dot_name), current.magnitude, current.duration], EventType.INFO, target.id)
		_log(tr("%s: %s aplicado!") % [_n(target), tr(dot_name)])


static func _dot_set(dot: Dictionary) -> bool:
	return dot.Duration > 0 and dot.Magnitude > 0


# ---------------------------------------------------------------- ações

## Termina o turno da unidade e passa ao próximo ator (endUnitTurn).
func end_unit_turn(unit: Unit, used_ability_id: String = "", ability_cooldown: int = 0) -> void:
	unit.immobilize_turns = maxi(0, unit.immobilize_turns - 1)
	unit.armor_break_turns = maxi(0, unit.armor_break_turns - 1)
	for key in unit.cooldowns:
		if unit.cooldowns[key] > 0:
			unit.cooldowns[key] -= 1
	if used_ability_id != "" and ability_cooldown > 0:
		unit.cooldowns[used_ability_id] = ability_cooldown
	if unit.mark_duration > 0:
		unit.mark_duration -= 1
		if unit.mark_duration <= 0:
			unit.tokens.mark = 0
	if not unit.guard_for_turn:
		unit.guard_target_rank = 0
	var item = _find(state.initiative_queue, func(i): return i.unit_id == unit.id and not i.acted)
	if item != null:
		item.acted = true
	_advance_to_next_actor()


func _clear_turn_guard(unit: Unit) -> void:
	if unit.guard_for_turn:
		unit.guard_for_turn = false
		unit.guard_target_rank = 0
		unit.guard_target_id = ""
		unit.tokens.guard = 0


## Início do turno de um herói atordoado ou com dano por turno. Retorna se ele pode agir.
func process_player_turn_start(out_events: Array) -> bool:
	var actor = _find(state.player_team, func(u): return u.id == state.current_turn_unit_id)
	var turn_key := "%d:%s" % [state.round, state.current_turn_unit_id]
	if actor == null or state.is_over or state.processed_player_turn_key == turn_key:
		return actor != null
	state.processed_player_turn_key = turn_key
	_clear_turn_guard(actor)
	if actor.stun_turns == 0 and actor.bleed.duration == 0 and actor.blight.duration == 0:
		return true
	_crisis_batch.clear()
	var actor_id: String = actor.id
	var can_act := _process_turn_start_dot(actor, out_events)
	if not can_act:
		end_unit_turn(_find_unit(actor_id))
	return can_act


func execute_move(unit_id: String, target_rank: int) -> AHCombat.ActionResult:
	var result := AHCombat.ActionResult.new()
	var unit := _find_unit(unit_id)
	if unit == null or not (unit.hp > 0 or unit.deaths_door):
		result.error = tr("Unidade não encontrada ou derrotada")
		return result
	if unit.stun_turns != 0:
		result.error = tr("Personagem atordoado.")
		return result
	if unit.rank == target_rank or target_rank < 1 or target_rank > 4:
		result.error = tr("Selecione outra posição da sua equipe.")
		return result
	var team: Array = state.player_team if unit.is_player else state.enemy_team
	var adjacent = _find(team, func(u): return occupies_rank(u, target_rank) and (u.hp > 0 or u.deaths_door))
	if not can_move_voluntarily(unit, adjacent):
		result.error = tr("Imobilização impede mover ou trocar de posição; ainda é possível atacar.")
		return result
	if unit_size(unit) > 1 or (adjacent != null and unit_size(adjacent) > 1):
		result.error = tr("Esta unidade grande não pode trocar de posição.")
		return result
	var guard_targets := {}
	for member in team:
		var target = _find(team, func(t):
			return alive_any(t) and (t.id == member.guard_target_id if member.guard_for_turn else (member.guard_target_rank != 0 and t.rank == member.guard_target_rank)))
		guard_targets[member.id] = target.id if target != null else ""
	if adjacent != null:
		adjacent.rank = unit.rank
	unit.rank = target_rank
	for member in team:
		var target_id: String = guard_targets.get(member.id, "")
		var target = null if target_id == "" else _find(team, func(t): return t.id == target_id)
		member.guard_target_rank = target.rank if target != null else 0
	var moved_name := unit.display_name
	_sort_team(team)
	_log(tr("%s manobrou para a posição %d.") % [_n(unit), target_rank])
	end_unit_turn(_find_unit(unit_id))
	result.success = true
	return result


func execute_defend(unit_id: String) -> AHCombat.ActionResult:
	var result := AHCombat.ActionResult.new()
	var unit := _find_unit(unit_id)
	if unit == null:
		result.error = tr("Unidade não encontrada")
		return result
	if unit.stun_turns != 0:
		result.error = tr("Personagem atordoado.")
		return result
	unit.tokens.block = mini(TOKEN_CAP, unit.tokens.block + 1)
	_log(tr("%s assumiu postura defensiva (+1 Bloqueio).") % _n(unit))
	end_unit_turn(unit)
	result.success = true
	return result


func execute_flee(unit_id: String) -> AHCombat.ActionResult:
	var result := AHCombat.ActionResult.new()
	var unit := _find_unit(unit_id)
	if unit == null or not unit.is_player:
		result.error = tr("Apenas aliados podem recuar.")
		return result
	if unit.stun_turns != 0:
		result.error = tr("Personagem atordoado.")
		return result
	if _any(state.enemy_team, func(u): return u.enemy_id == "porteiro"):
		result.error = tr("Impossível fugir de O Porteiro! As eclusas estão trancadas.")
		return result
	result.success = true
	if random.next() < 0.6:
		state.is_over = true
		state.escaped = true
		result.escaped = true
		_log(tr("A equipe conseguiu recuar pelas sombras e romper o combate!"))
		return result
	_log(tr("Tentativa de fuga falhou! Os inimigos bloquearam a passagem."))
	end_unit_turn(unit)
	return result


func _primary_target(user: Unit, ability: Dictionary, target_rank: int, friendly: Array, opposing: Array):
	match ability.TargetType:
		"Self":
			return user
		"SingleAlly":
			return _find(friendly, func(u): return occupies_rank(u, target_rank) and alive_any(u))
		"SingleOtherAlly":
			return _find(friendly, func(u): return occupies_rank(u, target_rank) and u.id != user.id and alive_any(u))
	return _find(opposing, func(u): return occupies_rank(u, target_rank) and alive_any(u))


func execute_player_ability(unit_id: String, ability_id: String, target_rank: int) -> AHCombat.ActionResult:
	var result := AHCombat.ActionResult.new()
	var events := result.events
	_crisis_batch.clear()

	var user := _find_unit(unit_id)
	if user == null:
		result.error = tr("Ator não encontrado")
		return result
	if user.stun_turns != 0:
		result.error = tr("Personagem atordoado.")
		return result
	var friendly: Array = state.player_team if user.is_player else state.enemy_team
	var opposing: Array = state.enemy_team if user.is_player else state.player_team

	var user_class = find_class(user.class_id)
	var ability = find_ability(ability_id) if user_class != null and user_class.AbilityIds.has(ability_id) else null
	if ability == null:
		result.error = tr("Habilidade não encontrada")
		return result
	if not ability.OriginRanks.has(user.rank):
		result.error = tr("Habilidade exige outra posição de origem. Posição atual: %d") % user.rank
		return result
	if user.cooldowns.get(ability_id, 0) > 0:
		result.error = tr("Habilidade em recarga (%d turnos).") % user.cooldowns[ability_id]
		return result
	var remaining: int = user.remaining_uses.get(ability_id, ability.UsesMax)
	if ability.UsesMax > 0 and remaining <= 0:
		result.error = tr("Limite de usos desta habilidade esgotado.")
		return result

	var target = _primary_target(user, ability, target_rank, friendly, opposing)
	if ability.TargetType == "SingleEnemy" or ability.TargetType == "MarkedEnemy":
		if target == null:
			result.error = tr("Não há inimigo na posição selecionada.")
			return result
		if ability.TargetType == "MarkedEnemy" and target.mark_duration <= 0:
			result.error = tr("Esta habilidade exige que o alvo esteja MARCADO.")
			return result
	if target == null:
		result.error = tr("Alvo inválido para esta habilidade.")
		return result
	if ability.TargetType != "Self" and not can_reach(ability.TargetRanks, target):
		result.error = tr("Alvo fora de alcance.")
		return result
	if (ability.bOrganicOnly and is_machine(target)) or (ability.bRequiresMarkOrVuln and target.mark_duration <= 0 and target.tokens.vuln <= 0):
		result.error = tr("Exige aliado orgânico ou inimigo Marcado/Vulnerável, conforme a habilidade.")
		return result

	if ability.UsesMax > 0:
		user.remaining_uses[ability_id] = remaining - 1

	var attempt := _consume_attempt(is_direct_attack(ability), user)
	var has_damage: bool = ability.DamageRange.Max > 0
	var has_heal: bool = ability.HealRange.Max > 0
	var inflicts: Dictionary = ability.Inflicts
	var cleanses: Dictionary = ability.Cleanses

	var hit_ids := _hit_ids_from(target, ability, target_rank, opposing)
	var hit_any_target := false
	for hit_target_id in hit_ids:
		target = _find_unit(hit_target_id)
		user = _find_unit(unit_id)
		if target == null or not target.is_standing():
			continue

		# Proteção: quem guarda o alvo intercepta o golpe.
		if target.is_player != user.is_player and has_damage and not ability.bAdjacentTarget:
			var target_rank_now: int = target.rank
			var target_id: String = target.id
			var protector = _find(opposing, func(u):
				return alive_any(u) and u.id != target_id and (u.guard_target_id == target_id if u.guard_for_turn else u.guard_target_rank == target_rank_now) and u.tokens.guard > 0)
			if protector != null:
				target = protector
				if not protector.guard_for_turn:
					protector.tokens.guard = maxi(0, protector.tokens.guard - 1)
				_log(tr("%s interceptou o golpe para proteger seu aliado!") % _n(protector))

		if _misses_from_blind(attempt, target, events):
			continue

		# Esquiva: 50% de evitar o golpe, gastando a ficha.
		if target.is_player != user.is_player and target.tokens.dodge > 0 and not ability.bTargetPair:
			target.tokens.dodge -= 1
			if random.next() < 0.5:
				_add_event(events, tr("ESQUIVOU!"), EventType.DODGE, target.id)
				_log(tr("%s esquivou do ataque de %s!") % [_n(target), _n(user)])
				continue

		var researched: bool = context.researched_skills.has(ability_id)
		var ability_name: String = ability.DisplayName
		hit_any_target = true
		if has_damage:
			var bonus: int = (1 if researched else 0) + int(user.ability_bonus.get(ability_id, 0))
			var rolled := _roll_range(ability.DamageRange.Min + bonus, ability.DamageRange.Max + bonus)
			if random.next() < CRITICAL_CHANCE:
				rolled = floori(rolled * CRITICAL_MULTIPLIER)
				_add_event(events, tr("CRÍTICO!"), EventType.CRIT, target.id).critical_roll = true
				_log(tr("[CRÍTICO!] %s desferiu um ataque devastador!") % _n(user))
			rolled = status_damage(rolled, attempt.weak)
			if is_machine(target):
				rolled = maxi(1, rolled * ability.MachineDamagePercent / 100)
			target.tokens.block = maxi(0, target.tokens.block - ability.RemoveBlock)
			if ability.bRequiresMarkOrVuln:
				if target.mark_duration > 0:
					target.mark_duration = 0
					target.tokens.mark = 0
				else:
					target.tokens.vuln = maxi(0, target.tokens.vuln - 1)
			var hit_id: String = target.id
			_apply_damage(target, rolled, true, events, "%s (%s)" % [user.display_name, ability_name], ability.ArmorPiercePercent, ability.bRequiresMarkOrVuln)
			target = _find_unit(hit_id)
			user = _find_unit(unit_id)
			_add_event(events, "-%d" % rolled, EventType.DAMAGE, target.id, rolled)
			_log(tr("%s usou %s em %s causando %d de dano.") % [_n(user), tr(ability_name), _n(target), rolled])

		if has_heal:
			var heal_bonus: int = (1 if researched else 0) + int(user.ability_bonus.get(ability_id, 0))
			var healed := mini(target.max_hp - target.hp, _roll_range(ability.HealRange.Min + heal_bonus, ability.HealRange.Max + heal_bonus))
			target.hp = mini(target.max_hp, target.hp + healed)
			if target.deaths_door and target.hp > 0:
				target.deaths_door = false
				_log(tr("%s recuperou o fôlego e saiu de perigo!") % _n(target))
			_add_event(events, tr("+%d Vida") % healed, EventType.HEAL, target.id, healed)
			_log(tr("%s tratou %s, restaurando %d de Vida.") % [_n(user), _n(target), healed])

		if ability.InstinctDelta != 0 and not is_machine(target):
			_change_instinct(target, ability.InstinctDelta, ability_name)
			var instinct_event := _add_event(events, tr("%d Instinto") % ability.InstinctDelta, EventType.INSTINCT, target.id)
			if ability.InstinctDelta < 0:
				instinct_event.outcome = Outcome.INSTINCT_REDUCED
			_log(tr("%s acalmou %s (%d Instinto).") % [_n(user), _n(target), ability.InstinctDelta])

		if target.is_standing() and inflicts.ArmorBreakTurns > 0:
			target.armor_break_turns = maxi(target.armor_break_turns, inflicts.ArmorBreakTurns)
			_add_event(events, tr("Armadura reduzida"), EventType.INFO, target.id)
		if cleanses.bMark:
			target.tokens.mark = 0
			target.mark_duration = 0
		_apply_control_effects(target, inflicts.bBlind, inflicts.bWeak, inflicts.Immobilize, events)
		if inflicts.Stun > 0 and alive_any(target):
			target.stun_turns = maxi(target.stun_turns, inflicts.Stun)
			_add_event(events, tr("Atordoado · %d turnos") % target.stun_turns, EventType.INFO, target.id).outcome = Outcome.STUN_APPLIED
		if _dot_set(inflicts.Bleed):
			_apply_dot(target, true, inflicts.Bleed, events, false)
		if _dot_set(inflicts.Blight):
			_apply_dot(target, false, inflicts.Blight, events, false)
		if inflicts.bVuln:
			target.tokens.vuln = mini(TOKEN_CAP, target.tokens.vuln + 1)
			_add_event(events, tr("Vulnerável!"), EventType.INFO, target.id)
			_log(tr("%s ficou Vulnerável!") % _n(target))
		if inflicts.bMark:
			target.mark_duration = 2
			target.tokens.mark = 1
			_add_event(events, tr("MARCADO!"), EventType.INFO, target.id).outcome = Outcome.MARK_APPLIED
			_log(tr("%s foi MARCADO por 2 turnos!") % _n(target))
		if inflicts.bDodge:
			target.tokens.dodge = mini(TOKEN_CAP, target.tokens.dodge + 1)
			_add_event(events, tr("+1 esquiva"), EventType.INFO, target.id).outcome = Outcome.DODGE_GRANTED
		if inflicts.Block > 0:
			var recipient: Unit = target if ability.TargetType == "SingleOtherAlly" and not ability.bBlockToSelf else user
			recipient.tokens.block = mini(TOKEN_CAP, recipient.tokens.block + inflicts.Block)
			_add_event(events, tr("+%d Bloqueio") % inflicts.Block, EventType.BLOCK, recipient.id).outcome = Outcome.BLOCK_GRANTED
		if inflicts.bGuard:
			user.guard_target_rank = target.rank
			user.guard_target_id = target.id
			user.guard_for_turn = ability.bGuardForTurn
			user.tokens.guard = 1
			_add_event(events, tr("protegido por %s") % _n(user), EventType.INFO, target.id).outcome = Outcome.GUARD_GRANTED
			if target.id != user.id:
				_activate_perk(user, "loyal", events)
			_log(tr("%s está guardando %s!") % [_n(user), _n(target)])

		if cleanses.bBlind and target.blind:
			target.blind = false
			_add_event(events, tr("Interferência removida") if is_machine(target) else tr("Cegueira removida"), EventType.INFO, target.id)
		if cleanses.bWeak and target.weak:
			target.weak = false
			_add_event(events, tr("Fraqueza removida"), EventType.INFO, target.id)
		if cleanses.bImmobilize and target.immobilize_turns > 0:
			target.immobilize_turns = 0
			_add_event(events, tr("Imobilização removida"), EventType.INFO, target.id)
		if cleanses.bVuln and target.tokens.vuln > 0:
			target.tokens.vuln = maxi(0, target.tokens.vuln - ability.CleanseVulnCharges) if ability.CleanseVulnCharges > 0 else 0
			_add_event(events, tr("Vulnerável Removido"), EventType.INFO, target.id).outcome = Outcome.VULNERABILITY_REMOVED
		if cleanses.bDot:
			var removed_dot: bool = target.bleed.duration > 0 or target.blight.duration > 0
			target.bleed.clear()
			target.blight.clear()
			var dot_event := _add_event(events, tr("Efeitos Periódicos Curados"), EventType.HEAL, target.id)
			if removed_dot:
				dot_event.outcome = Outcome.DOT_CLEANSED
			_log(tr("%s foi purificado de toxinas e feridas.") % _n(target))
		if ability.bConsumesMark and target.mark_duration != 0:
			target.mark_duration = 0
			target.tokens.mark = 0

		# Empurrar ou puxar o alvo (20% de resistir; imunes não sorteiam).
		if ability.PushTarget != 0 and alive_any(target):
			var target_enemy = null if target.is_player else find_enemy(target.enemy_id)
			var immune: bool = target_enemy != null and target_enemy.DisplacementResist >= 1.0
			if not immune and not (random.next() < 0.2):
				var team: Array = state.player_team if target.is_player else state.enemy_team
				var new_rank := clampi(target.rank + ability.PushTarget, 1, 4)
				if new_rank != target.rank:
					var pushed_id: String = target.id
					var occupant = _find(team, func(u): return u.id != pushed_id and occupies_rank(u, new_rank) and alive_any(u))
					if occupant != null and unit_size(occupant) > 1:
						_log(tr("%s: deslocamento bloqueado por uma unidade grande.") % _n(target))
					elif occupant != null:
						occupant.rank = target.rank
						target.rank = new_rank
						_sort_team(team)
						_log(tr("%s foi empurrado para a posição %d!") % [_n(target), new_rank])

	user = _find_unit(unit_id)
	if hit_any_target and ability.AdvanceSelf != 0 and can_move_voluntarily(user):
		var team: Array = state.player_team if user.is_player else state.enemy_team
		var new_rank := clampi(user.rank - ability.AdvanceSelf, 1, 4)
		var destination = _find(team, func(u): return occupies_rank(u, new_rank) and alive_any(u))
		if new_rank != user.rank and can_move_voluntarily(user, destination):
			# Aliados na Porta da Morte ocupam a posição e trocam junto; as gravações antigas da web só moviam um vivo.
			if context.legacy_web_advance_swap:
				destination = _find(team, func(u): return occupies_rank(u, new_rank) and u.hp > 0)
			if destination != null:
				destination.rank = user.rank
			user.rank = new_rank
			_sort_team(team)
			_log(tr("%s mudou para a posição %d.") % [_n(user), new_rank])

	end_unit_turn(user, ability_id, ability.Cooldown)
	result.success = true
	result.used_ability_id = ability_id
	return result


# ---------------------------------------------------------------- IA dos inimigos

func _intercepted_target(target: Unit, team: Array) -> Unit:
	var guard = _find(team, func(u):
		return u.id != target.id and alive_any(u) and u.tokens.guard > 0 and (u.guard_target_id == target.id if u.guard_for_turn else u.guard_target_rank == target.rank))
	return guard if guard != null else target


func _remember_enemy_target(target_id: String) -> void:
	state.enemy_target_history.append(target_id)
	while state.enemy_target_history.size() > 3:
		state.enemy_target_history.pop_front()


func _attack_priority(damage_range: Dictionary, instinct_add: int, stun: int, bleed_magnitude: int, blight_magnitude: int, vuln: bool,
		target: Unit, team: Array) -> float:
	var recipient := _intercepted_target(target, team)
	var has_damage: bool = damage_range.Max > 0
	var damage: float = (damage_range.Min + damage_range.Max) / 2.0 if has_damage else 0.0
	if recipient.tokens.vuln != 0:
		damage = floorf(damage * 1.5)
	if recipient.tokens.block != 0:
		damage = floorf(damage * 0.5)
	if has_damage:
		damage = maxf(1.0, damage)
	var hit_chance := 0.5 if recipient.tokens.dodge != 0 else 1.0
	var lethal := damage > 0 and damage >= recipient.hp
	var pressure := (1.0 - float(recipient.hp) / recipient.max_hp) * 10.0 if damage > 0 else 0.0
	var dots := bleed_magnitude + blight_magnitude
	var repetition := 0.0
	var history := state.enemy_target_history
	for index in history.size():
		if history[index] == recipient.id:
			repetition += 10.0 if index == history.size() - 1 else 5.0
	repetition = minf(18.0, repetition)
	return hit_chance * (damage * 2.0 + pressure + (35.0 if lethal else 0.0) + dots * 2.0
		+ (8.0 if stun != 0 and recipient.stun_turns == 0 else 0.0)
		+ (5.0 if vuln and recipient.tokens.vuln == 0 else 0.0)
		+ instinct_add * 0.5 + (20.0 if instinct_add != 0 and recipient.instinct + instinct_add >= 200 else 0.0)) - repetition


## As escolhas de um inimigo de classe agora, sem mexer em nada: as habilidades, o parceiro de troca (quando não
## dá para atacar) e as opções com a nota, da melhor para a pior. O turno e a intenção do HUD usam a mesma conta.
func _class_enemy_options(enemy: Unit) -> Dictionary:
	var enemy_class = find_class(enemy.class_id)
	var abilities: Array = []
	var ability_ids: Array = []
	for ability_id in (enemy_class.AbilityIds if enemy_class != null else []):
		var ability = find_ability(ability_id)
		if ability != null:
			abilities.append(ability)
			ability_ids.append(ability_id)

	var swap_partner = _find(state.enemy_team, func(u):
		return u.hp > 0 and u.id != enemy.id and ((u.rank < enemy.rank and u.max_hp < enemy.max_hp) or (u.rank > enemy.rank and u.max_hp > enemy.max_hp)))
	var can_attack := false
	for index in abilities.size():
		var ability: Dictionary = abilities[index]
		can_attack = can_attack or (ability.DamageRange.Max > 0 and ability.OriginRanks.has(enemy.rank) and not (enemy.cooldowns.get(ability_ids[index], 0) > 0)
			and _any(state.player_team, func(t): return alive_any(t) and ability.TargetRanks.has(t.rank)))
	var swap = swap_partner if swap_partner != null and not can_attack and can_move_voluntarily(enemy, swap_partner) else null
	var options: Array = []
	for index in abilities.size():
		var ability: Dictionary = abilities[index]
		var uses: int = enemy.remaining_uses.get(ability_ids[index], ability.UsesMax)
		if not ability.OriginRanks.has(enemy.rank) or enemy.cooldowns.get(ability_ids[index], 0) > 0 or (ability.UsesMax > 0 and uses <= 0):
			continue
		var offensive: bool = ability.TargetType == "SingleEnemy" or ability.TargetType == "MarkedEnemy"
		for target in (state.player_team if offensive else state.enemy_team):
			var valid: bool = alive_any(target) \
				and (target.id == enemy.id if ability.TargetType == "Self" else ability.TargetRanks.has(target.rank)) \
				and (ability.TargetType != "SingleOtherAlly" or target.id != enemy.id) \
				and (ability.TargetType != "MarkedEnemy" or target.mark_duration > 0) \
				and (ability.HealRange.Max <= 0 or target.hp < target.max_hp) \
				and (not ability.bRequiresMarkOrVuln or target.mark_duration > 0 or target.tokens.vuln > 0) \
				and (not ability.bOrganicOnly or not is_machine(target))
			if not valid:
				continue
			var inf: Dictionary = ability.Inflicts
			var score: float
			if ability.DamageRange.Max > 0:
				score = _attack_priority(ability.DamageRange, 0, inf.Stun, inf.Bleed.Magnitude, inf.Blight.Magnitude, inf.bVuln, target, state.player_team)
			elif ability.HealRange.Max > 0:
				score = minf(float(target.max_hp - target.hp), (ability.HealRange.Min + ability.HealRange.Max) / 2.0) * 2.0
			else:
				score = 2.0
			options.append({"index": index, "target": target, "score": score})
	stable_sort(options, func(a, b): return a.score > b.score)
	return {"abilities": abilities, "ability_ids": ability_ids, "swap": swap, "options": options}


## Inimigo com habilidades de classe (ramo enemy.classId da web).
func _execute_class_enemy_turn(enemy: Unit, events: Array) -> Array:
	var choices := _class_enemy_options(enemy)
	var abilities: Array = choices.abilities
	var ability_ids: Array = choices.ability_ids
	var options: Array = choices.options
	var enemy_id := enemy.id
	if choices.swap != null:
		var swap_partner = choices.swap
		var partner_id: String = swap_partner.id
		execute_move(enemy_id, swap_partner.rank)
		_add_event(events, tr("Troca de posição"), EventType.INFO, enemy_id)
		_add_event(events, tr("Troca de posição"), EventType.INFO, partner_id)
		return events
	if options.is_empty():
		execute_defend(enemy_id)
		_add_event(events, tr("+1 bloqueio"), EventType.BLOCK, enemy_id)
		return events
	var choice: Dictionary = options[0]
	var chosen_ability: Dictionary = abilities[choice.index]
	var chosen_rank: int = choice.target.rank
	if chosen_ability.TargetType == "SingleEnemy" or chosen_ability.TargetType == "MarkedEnemy":
		_remember_enemy_target(_intercepted_target(choice.target, state.player_team).id)
	var chosen_id: String = ability_ids[choice.index]
	_add_event(events, chosen_ability.DisplayName, EventType.INFO, enemy_id, 0, chosen_id)
	events.append_array(execute_player_ability(enemy_id, chosen_id, chosen_rank).events)
	return events


## O que o inimigo faria se a vez dele fosse agora (a intenção do HUD): {kind: "attack"|"heal"|"defend"|"move"|
## "stunned"|"none", name, id (a ação), target_ids, sure, either (os alvos são um ou outro)}. Mesma conta do turno, sem sorteio: com empate, o primeiro candidato e sure
## falso. Muda conforme a luta (quem cai, quem se protege, a posição).
func enemy_intent(enemy_id: String) -> Dictionary:
	var enemy = _find(state.enemy_team, func(u): return u.id == enemy_id)
	var out := {"kind": "none", "name": "", "id": "", "target_ids": [], "sure": true, "either": false}
	if enemy == null or enemy.hp <= 0:
		return out
	if enemy.stun_turns > 0:
		out.kind = "stunned"
		out.name = "Atordoado: perde a vez"
		return out
	if enemy.class_id != "":
		var choices := _class_enemy_options(enemy)
		if choices.swap != null:
			out.kind = "move"
			out.name = "Troca de posição"
			return out
		if choices.options.is_empty():
			out.kind = "defend"
			out.name = "Defender"
			return out
		var choice: Dictionary = choices.options[0]
		var ability: Dictionary = choices.abilities[choice.index]
		out.name = ability.DisplayName
		out.id = choices.ability_ids[choice.index]
		out.kind = "attack" if ability.DamageRange.Max > 0 else ("heal" if ability.HealRange.Max > 0 else "move")
		out.target_ids = [choice.target.id]
		out.sure = choices.options.size() < 2 or choices.options[1].score < choice.score
		return out
	var definition = find_enemy(enemy.enemy_id)
	if definition == null or definition.ActionIds.is_empty():
		out.kind = "defend"
		out.name = "Defender"
		return out
	var planned := _enemy_plans(enemy)
	if planned.contenders.is_empty():
		out.kind = "move" if enemy.rank > 1 else "defend"
		out.name = "Avançar" if enemy.rank > 1 else "Defender"
		return out
	var plan: Dictionary = planned.contenders[0]
	var action: Dictionary = planned.actions[plan.index]
	out.name = action.DisplayName
	out.id = planned.short_ids[plan.index]
	out.sure = planned.contenders.size() == 1
	if action.TargetType == "Self":
		out.kind = "heal" if action.HealRange.Max > 0 else ("defend" if action.bIsDefend else "move")
		return out
	out.kind = "attack"
	if action.TargetType == "MultiAlly":
		var inflicts: Dictionary = action.Inflicts
		var targets: Array = state.player_team.filter(func(u): return alive_any(u) and action.TargetRanks.has(u.rank))
		var priority := func(t): return _attack_priority(action.DamageRange, action.InstinctAdd, inflicts.Stun, inflicts.Bleed.Magnitude, inflicts.Blight.Magnitude, inflicts.bVuln, t, [t])
		stable_sort(targets, func(a, b): return priority.call(a) > priority.call(b))
		for index in mini(2, targets.size()):
			out.target_ids.append(targets[index].id)
	elif plan.target != null:
		out.target_ids = [_intercepted_target(plan.target, state.player_team).id]
		# Empate só entre alvos da mesma ação: a intenção lista os alvos possíveis ("either") em vez da dúvida.
		var same_action: bool = planned.contenders.all(func(c): return c.index == plan.index and c.target != null)
		if not out.sure and same_action:
			for candidate in planned.contenders:
				var who := _intercepted_target(candidate.target, state.player_team).id
				if not out.target_ids.has(who):
					out.target_ids.append(who)
			out.either = true
	return out


func execute_enemy_turn() -> Array:
	var events: Array = []
	_crisis_batch.clear()
	if state.current_turn_unit_id == "":
		return events
	var enemy = _find(state.enemy_team, func(u): return u.id == state.current_turn_unit_id)
	if enemy == null or enemy.hp <= 0:
		if enemy != null:
			end_unit_turn(enemy)
		return events

	_clear_turn_guard(enemy)
	var turn_enemy_id: String = enemy.id
	var can_act := _process_turn_start_dot(enemy, events)
	enemy = _find_unit(turn_enemy_id)
	if not can_act or enemy.hp <= 0:
		end_unit_turn(enemy)
		return events

	if enemy.class_id != "":
		return _execute_class_enemy_turn(enemy, events)

	var definition = find_enemy(enemy.enemy_id)
	if definition == null or definition.ActionIds.is_empty():
		enemy.tokens.block = mini(TOKEN_CAP, enemy.tokens.block + 1)
		end_unit_turn(enemy)
		return events

	var planned := _enemy_plans(enemy)
	var actions: Array = planned.actions
	var action_short_ids: Array = planned.short_ids
	var plan = null
	var contenders: Array = planned.contenders
	if not contenders.is_empty():
		plan = contenders[mini(contenders.size() - 1, floori(random.next() * contenders.size()))]

	var enemy_id: String = enemy.id
	if plan == null:
		# Sem ação possível: avança se estiver atrás, senão defende.
		if enemy.rank > 1 and execute_move(enemy_id, enemy.rank - 1).success:
			return events
		execute_defend(enemy_id)
		return events
	return _execute_enemy_plan(enemy, actions[plan.index], action_short_ids[plan.index], plan, events)


## As ações válidas de um inimigo comum agora e os planos com a nota (chooseEnemyPlan), sem mexer em nada; os
## candidatos são os que ficam a 1 ponto do melhor (o turno sorteia entre eles). O Porteiro troca de repertório na
## fase 2.
func _enemy_plans(enemy: Unit) -> Dictionary:
	var definition = find_enemy(enemy.enemy_id)
	var actions: Array = []
	var action_short_ids: Array = []
	for action_id in definition.ActionIds:
		var action = find_enemy_action(action_id)
		if action == null or not action.OriginRanks.has(enemy.rank):
			continue
		var short_id := short_action_id(action_id)
		if enemy.enemy_id == "porteiro":
			var phase_two := short_id == "porteiro_esmagamento_brutal" or short_id == "porteiro_impacto_hidraulico"
			var phase_one := short_id == "porteiro_golpe_escotilha" or short_id == "porteiro_sirene"
			if (not phase_two) if state.boss_phase == 2 else (not phase_one):
				continue
		actions.append(action)
		action_short_ids.append(short_id)

	# chooseEnemyPlan.
	var living: Array = state.player_team.filter(func(u): return alive_any(u))
	var plans: Array = []
	for index in actions.size():
		var action: Dictionary = actions[index]
		var inf: Dictionary = action.Inflicts
		if action.TargetType == "Self":
			var hp_ratio: float = float(enemy.hp) / enemy.max_hp
			if action.HealRange.Max > 0:
				var restored := minf(float(enemy.max_hp - enemy.hp), (action.HealRange.Min + action.HealRange.Max) / 2.0)
				if restored > 0:
					plans.append({"index": index, "target": null, "score": restored * (7.0 if hp_ratio < 0.4 else 1.5)})
			elif action.bIsDefend:
				if enemy.tokens.block < 1:
					plans.append({"index": index, "target": null, "score": 12.0 if hp_ratio < 0.4 else 3.0})
			elif (action.Advances != 0 or action.Retreats != 0) and can_move_voluntarily(enemy):
				var rank := maxi(1, mini(4, enemy.rank - action.Advances + action.Retreats))
				var destination = _find(state.enemy_team, func(u): return occupies_rank(u, rank) and alive_any(u))
				if rank != enemy.rank and can_move_voluntarily(enemy, destination):
					plans.append({"index": index, "target": null, "score": 2.0})
			continue
		var legal: Array = living.filter(func(t): return action.TargetRanks.has(t.rank))
		if action.TargetType == "MultiAlly":
			if not legal.is_empty():
				var scores: Array = []
				for target in legal:
					scores.append(_attack_priority(action.DamageRange, action.InstinctAdd, inf.Stun, inf.Bleed.Magnitude, inf.Blight.Magnitude, inf.bVuln, target, [target]))
				scores.sort_custom(func(a, b): return a > b)
				var total := 0.0
				for s in mini(2, scores.size()):
					total += scores[s]
				plans.append({"index": index, "target": null, "score": total})
			continue
		for target in legal:
			plans.append({"index": index, "target": target, "score": _attack_priority(action.DamageRange, action.InstinctAdd, inf.Stun, inf.Bleed.Magnitude, inf.Blight.Magnitude, inf.bVuln, target, living)})

	var contenders: Array = []
	if not plans.is_empty():
		var best: float = plans[0].score
		for candidate in plans:
			best = maxf(best, candidate.score)
		contenders = plans.filter(func(c): return c.score >= best - 1)
	return {"actions": actions, "short_ids": action_short_ids, "contenders": contenders}


func _execute_enemy_plan(enemy: Unit, action: Dictionary, action_short_id: String, plan: Dictionary, events: Array) -> Array:
	var enemy_id: String = enemy.id
	var definition = find_enemy(enemy.enemy_id)
	var action_name: String = action.DisplayName
	var plan_target_id: String = plan.target.id if plan.target != null else ""
	_add_event(events, tr(action_name), EventType.INFO, enemy_id, 0, action_short_id)

	if action.TargetType == "Self" and action.HealRange.Max > 0:
		var heal_roll: int = action.HealRange.Min + floori(random.next() * (action.HealRange.Max - action.HealRange.Min + 1))
		var healed := mini(heal_roll, maxi(0, enemy.max_hp - enemy.hp))
		enemy.hp += healed
		_add_event(events, "+%d" % healed, EventType.HEAL, enemy_id, healed)
		_log(tr("%s usou %s e recuperou %d de vida.") % [_n(enemy), tr(action_name), healed])
		end_unit_turn(enemy)
		return events
	if action.bIsDefend:
		enemy.tokens.block = mini(TOKEN_CAP, enemy.tokens.block + 1)
		_add_event(events, tr("blindagem +1"), EventType.INFO, enemy_id)
		_log(tr("%s assumiu Postura Blindada (+1 Bloqueio).") % _n(enemy))
		end_unit_turn(enemy)
		return events
	if action.Advances > 0:
		execute_move(enemy_id, maxi(1, enemy.rank - action.Advances))
		_add_event(events, tr("Troca de posição"), EventType.INFO, enemy_id)
		return events
	if action.Retreats > 0:
		execute_move(enemy_id, mini(4, enemy.rank + action.Retreats))
		return events

	var legal_targets: Array = state.player_team.filter(func(u): return alive_any(u) and action.TargetRanks.has(u.rank))
	if legal_targets.is_empty():
		enemy.tokens.block = mini(TOKEN_CAP, enemy.tokens.block + 1)
		end_unit_turn(enemy)
		return events

	var inflicts: Dictionary = action.Inflicts
	var target_ids: Array = []
	var multi: bool = action.TargetType == "MultiAlly"
	if multi:
		# Até dois aliados diferentes, os de maior prioridade.
		var targets := legal_targets.duplicate()
		var priority := func(t): return _attack_priority(action.DamageRange, action.InstinctAdd, inflicts.Stun, inflicts.Bleed.Magnitude, inflicts.Blight.Magnitude, inflicts.bVuln, t, [t])
		stable_sort(targets, func(a, b): return priority.call(a) > priority.call(b))
		targets.resize(mini(2, targets.size()))
		for target in targets:
			target_ids.append(target.id)
		_log(tr("%s ativou %s, emitindo ruídos ensurdecedores do Eco!") % [_n(enemy), tr(action_name)])
	else:
		target_ids.append(legal_targets[0].id if plan_target_id == "" else plan_target_id)
	# Uma vez por ação, nunca por alvo. Os ids sobrevivem a mortes e trocas forçadas.
	var attempt := _consume_attempt(action.TargetType != "Self" and action.DamageRange.Max > 0, enemy)
	for target_id in target_ids:
		var chosen := _find_unit(target_id)
		if chosen == null or not chosen.is_standing():
			continue
		var chosen_id := chosen.id
		var chosen_rank := chosen.rank
		var protector = null if multi else _find(state.player_team, func(u):
			return alive_any(u) and u.id != chosen_id and (u.guard_target_id == chosen_id if u.guard_for_turn else u.guard_target_rank == chosen_rank) and u.tokens.guard > 0)
		if protector != null:
			chosen = protector
			if not protector.guard_for_turn:
				protector.tokens.guard = maxi(0, protector.tokens.guard - 1)
			_log(tr("%s interceptou o golpe para salvar o companheiro!") % _n(protector))
		_remember_enemy_target(chosen.id)

		if _misses_from_blind(attempt, chosen, events):
			continue
		if (not multi or action.DamageRange.Max > 0) and chosen.tokens.dodge > 0:
			chosen.tokens.dodge -= 1
			if random.next() < 0.5:
				_add_event(events, tr("ESQUIVOU!"), EventType.DODGE, chosen.id)
				_log(tr("%s esquivou com agilidade do ataque de %s!") % [_n(chosen), _n(enemy)])
				continue

		if action.DamageRange.Max > 0:
			var rolled := _roll_range(action.DamageRange.Min + enemy.damage_bonus, action.DamageRange.Max + enemy.damage_bonus)
			if random.next() < CRITICAL_CHANCE:
				rolled = floori(rolled * CRITICAL_MULTIPLIER)
				_add_event(events, tr("CRÍTICO INIMIGO!"), EventType.CRIT, chosen.id).critical_roll = true
				_log(tr("[CRÍTICO!] %s desferiu um golpe brutal em %s!") % [_n(enemy), _n(chosen)])
				_change_instinct(chosen, 12, tr("Pressão de combate"))
				# Rivalidade (-3): o rival estremece ao ver a falha.
				if chosen.hero_id != "":
					for other in state.player_team:
						if other.hero_id != "" and other.hero_id != chosen.hero_id and context.relationships.get(relationship_key(chosen.hero_id, other.hero_id), 0) <= -3:
							_change_instinct(other, 5, tr("Pressão de combate"))
							_log(tr("[RIVALIDADE] %s estremeceu ao ver a falha do rival (+5 Instinto).") % _n(other))
							_apply_instinct_crisis(other, events)
			rolled = status_damage(rolled, attempt.weak)
			var hit_id := chosen.id
			_apply_damage(chosen, rolled, true, events, "%s (%s)" % [enemy.display_name, action_name])
			chosen = _find(state.player_team, func(u): return u.id == hit_id)
			_add_event(events, "-%d" % rolled, EventType.DAMAGE, hit_id, rolled)
			if definition.Category == "Machine" and alive_any(chosen):
				_activate_perk(chosen, "machine-fear", events)
			_apply_instinct_crisis(chosen, events)
			_log(tr("%s atacou %s causando %d de dano.") % [_n(enemy), _n(chosen), rolled])

		if action.InstinctAdd != 0:
			_change_instinct(chosen, action.InstinctAdd, tr("Pressão de combate"))
			_add_event(events, tr("+%d Instinto") % action.InstinctAdd, EventType.INSTINCT, chosen.id)
			_log(tr("%s desferiu terror psicológico em %s (+%d Instinto).") % [_n(enemy), _n(chosen), action.InstinctAdd])
			_apply_instinct_crisis(chosen, events)

		_apply_control_effects(chosen, inflicts.bBlind, inflicts.bWeak, inflicts.Immobilize, events)
		if inflicts.Stun > 0 and alive_any(chosen):
			chosen.stun_turns = maxi(chosen.stun_turns, inflicts.Stun)
			_add_event(events, tr("Atordoado · %d turnos") % chosen.stun_turns, EventType.INFO, chosen.id)
		if _dot_set(inflicts.Bleed):
			_apply_dot(chosen, true, inflicts.Bleed, events, true)
		if _dot_set(inflicts.Blight):
			_apply_dot(chosen, false, inflicts.Blight, events, true)
		if inflicts.bVuln:
			chosen.tokens.vuln = mini(TOKEN_CAP, chosen.tokens.vuln + 1)
			_add_event(events, tr("Vulnerável!"), EventType.INFO, chosen.id)
		if inflicts.Push > 0 and alive_any(chosen):
			if not (random.next() < 0.2):
				var new_rank := mini(4, chosen.rank + inflicts.Push)
				if new_rank != chosen.rank:
					var pushed_id := chosen.id
					var occupant = _find(state.player_team, func(u): return u.id != pushed_id and occupies_rank(u, new_rank) and alive_any(u))
					if occupant != null and unit_size(occupant) == 1:
						occupant.rank = chosen.rank
						chosen.rank = new_rank
						_sort_team(state.player_team)
						_log(tr("%s foi arremessado para trás!") % _n(chosen))

	end_unit_turn(_find_unit(enemy_id))
	return events


# ---------------------------------------------------------------- alvos e modo automático

## Quem a habilidade atinge mirando na posição (AbilityHitIds): o alvo e, nas de área, o par (1-2 ou 3-4) ou o vizinho.
## A prévia do HUD marca todos; é a mesma conta do ataque de verdade (_hit_ids_from). Vazio se a posição não vale.
func ability_hit_ids(actor_id: String, ability_id: String, target_rank: int) -> Array:
	var user := _find_unit(actor_id)
	var ability = find_ability(ability_id)
	if user == null or ability == null or (ability.TargetType != "Self" and not valid_targets(actor_id, ability_id).has(target_rank)):
		return []
	var friendly: Array = state.player_team if user.is_player else state.enemy_team
	var opposing: Array = state.enemy_team if user.is_player else state.player_team
	var target = null
	match ability.TargetType:
		"Self":
			target = user
		"SingleAlly":
			target = _find(friendly, func(u): return occupies_rank(u, target_rank) and alive_any(u))
		"SingleOtherAlly":
			target = _find(friendly, func(u): return occupies_rank(u, target_rank) and u.id != user.id and alive_any(u))
		_:
			target = _find(opposing, func(u): return occupies_rank(u, target_rank) and alive_any(u))
	return _hit_ids_from(target, ability, target_rank, opposing) if target != null else []


## Todas as posições válidas para a habilidade, da frente para trás (a própria, se for em si).
func valid_targets(actor_id: String, ability_id: String) -> Array:
	var targets: Array = []
	var actor := _find_unit(actor_id)
	var ability = find_ability(ability_id)
	if actor == null or ability == null:
		return targets
	if ability.TargetType == "Self":
		targets.append(actor.rank)
		return targets
	var enemy_side: bool = ability.TargetType == "SingleEnemy" or ability.TargetType == "MarkedEnemy"
	var team: Array = state.enemy_team if enemy_side else state.player_team
	for rank in range(1, 5):
		if not ability.TargetRanks.has(rank):
			continue
		if _any(team, func(u):
				return occupies_rank(u, rank) and alive_any(u) \
					and (ability.TargetType != "SingleOtherAlly" or u.id != actor_id) \
					and (ability.TargetType != "MarkedEnemy" or u.mark_duration > 0) \
					and (not ability.bRequiresMarkOrVuln or u.mark_duration > 0 or u.tokens.vuln > 0) \
					and (not ability.bOrganicOnly or not is_machine(u))):
			targets.append(rank)
	return targets


func first_valid_target(actor_id: String, ability_id: String) -> int:
	var targets := valid_targets(actor_id, ability_id)
	return 0 if targets.is_empty() else targets[0]


## Turno do herói com a política fixa da paridade: a partir de (rodada + posição) % n, a primeira habilidade com
## alvo válido; senão, defende.
func play_auto_turn(actor_id: String) -> AHCombat.ActionResult:
	var actor := _find_unit(actor_id)
	var actor_class = find_class(actor.class_id) if actor != null else null
	if actor_class == null or actor_class.AbilityIds.is_empty():
		return execute_defend(actor_id)
	var ids: Array = actor_class.AbilityIds
	var start: int = (state.round + actor.rank) % ids.size()
	for offset in ids.size():
		actor = _find_unit(actor_id)
		var ability_id: String = ids[(start + offset) % ids.size()]
		var ability = find_ability(ability_id)
		if ability == null or not ability.OriginRanks.has(actor.rank) or actor.cooldowns.get(ability_id, 0) > 0:
			continue
		if ability.UsesMax > 0 and actor.remaining_uses.get(ability_id, ability.UsesMax) <= 0:
			continue
		var target_rank := first_valid_target(actor_id, ability_id)
		if target_rank == 0:
			continue
		var result := execute_player_ability(actor_id, ability_id, target_rank)
		if result.success:
			return result
	return execute_defend(actor_id)
