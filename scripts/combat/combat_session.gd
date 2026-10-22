## Uma luta: monta o combate a partir da equipe da campanha, diz o que o herói da vez pode fazer e executa os comandos.
## Cada ação volta como um lance ({source_id, kind, ability_id, events, ok, error}) para a arena animar. Sem cena: os
## testes jogam lutas inteiras com isto (tests/test_combat_session.gd).
class_name AHCombatSession
extends RefCounted

const Unit = AHCombat.Unit

var data: AHGameData
var state: AHCombat.State
var context: AHCombat.Context
var random: AHCombatRandom
var engine: AHCombatEngine
## A vez do herói que está decidindo (rodada:unidade) e a vez em que ele já usou um item da Mochila.
var processed_turn_key := ""
var item_used_turn_key := ""
## O que cada herói fez nesta luta (o destaque do relatório da volta): {hero_id: {damage, healing, downs}}.
var tally := {}


## heroes: heróis da campanha (Campaign.state.roster) na ordem da formação. enemies: da frente para trás, cada um o id
## do inimigo ou já montado pelo corredor ({enemy_id, unit_id, rank, hp, max_hp, damage_bonus, display_name}).
static func create(heroes: Array, enemies_in: Array, opening: bool = false, seed_value: int = -1, hope: int = 80) -> AHCombatSession:
	var session := AHCombatSession.new()
	session.data = GameData.combat
	session.random = AHCombatRandom.new(seed_value if seed_value >= 0 else randi())
	session.context = AHCombat.Context.new()
	session.context.hope = hope
	var players: Array = []
	for index in heroes.size():
		var hero: Dictionary = heroes[index]
		players.append(AHCombatEngine.make_hero_unit({
			"Id": hero.id, "ClassId": hero.class_id, "DisplayName": hero.display_name, "MaxHp": hero.max_hp, "Hp": hero.hp,
			"Instinct": hero.get("instinct", 0), "Perks": hero.get("perks", []), "Trauma": hero.get("trauma", false),
			"RelicId": hero.get("relic_id", ""), "ExpeditionUses": hero.get("expedition_uses", {}),
		}, index + 1, session.data))
	var enemies: Array = []
	var next_rank := 1
	for index in enemies_in.size():
		var spec = enemies_in[index]
		if typeof(spec) == TYPE_DICTIONARY:
			var built := AHCombatEngine.make_enemy_unit(spec.enemy_id, spec.unit_id, spec.rank, session.data)
			built.hp = spec.get("hp", built.hp)
			built.max_hp = spec.get("max_hp", built.max_hp)
			built.damage_bonus = spec.get("damage_bonus", 0)
			built.display_name = spec.get("display_name", built.display_name)
			enemies.append(built)
			continue
		var unit := AHCombatEngine.make_enemy_unit(spec, "enemy_%s_%d" % [spec, index], next_rank, session.data)
		enemies.append(unit)
		var row = session.data.enemies.get(spec)
		next_rank += row.FormationSize if row != null and row.FormationSize > 0 else 1
	session.state = AHCombatEngine.init_combat(players, enemies, session.context, session.data, session.random, opening)
	session.engine = AHCombatEngine.new(session.state, session.context, session.data, session.random)
	return session


func current_actor() -> Unit:
	return state.find_unit(state.current_turn_unit_id)


func is_player_turn() -> bool:
	var actor := current_actor()
	return actor != null and actor.is_player and not state.is_over


func is_over() -> bool:
	return state.is_over


## "victory", "defeat", "escaped" ou "" durante a luta.
func result() -> String:
	if not state.is_over:
		return ""
	return "escaped" if state.escaped else ("victory" if state.victory else "defeat")


func units() -> Array:
	return state.player_team + state.enemy_team


# ---------------------------------------------------------------- opções do herói da vez

## As habilidades do herói, na ordem da classe: {id, name, description, usable, reason, targets, enemy_side, cooldown, uses}.
func ability_options(actor_id: String) -> Array:
	var actor := state.find_unit(actor_id)
	var options: Array = []
	if actor == null:
		return options
	var hero_class = data.classes.get(actor.class_id)
	for ability_id in (hero_class.AbilityIds if hero_class != null else []):
		var ability = data.abilities.get(ability_id)
		if ability == null:
			continue
		var cooldown: int = actor.cooldowns.get(ability_id, 0)
		var uses: int = actor.remaining_uses.get(ability_id, ability.UsesMax) if ability.UsesMax > 0 else -1
		var targets := engine.valid_targets(actor_id, ability_id)
		var reason := ""
		if actor.stun_turns > 0:
			reason = "Atordoado"
		elif not ability.OriginRanks.has(actor.rank):
			reason = "Usa das posições %s" % ", ".join(ability.OriginRanks.map(func(r): return str(r)))
		elif cooldown > 0:
			reason = "Recarga: %d turno(s)" % cooldown
		elif uses == 0:
			reason = "Sem usos"
		elif targets.is_empty():
			reason = "Sem alvo válido"
		options.append({
			"id": ability_id, "name": ability.DisplayName, "description": describe(ability_id), "usable": reason == "",
			"reason": reason, "targets": targets, "enemy_side": ability.TargetType == "SingleEnemy" or ability.TargetType == "MarkedEnemy",
			"self": ability.TargetType == "Self", "cooldown": cooldown, "uses": uses,
		})
	return options


## Texto curto da habilidade: o que faz em números e a descrição de abilities.json.
func describe(ability_id: String) -> String:
	var ability: Dictionary = data.abilities[ability_id]
	var parts := PackedStringArray()
	if ability.DamageRange.Max > 0:
		parts.append("Dano %d–%d" % [ability.DamageRange.Min, ability.DamageRange.Max])
	if ability.HealRange.Max > 0:
		parts.append("Cura %d–%d" % [ability.HealRange.Min, ability.HealRange.Max])
	if ability.Cooldown > 0:
		parts.append("Recarga %d" % ability.Cooldown)
	if ability.UsesMax > 0:
		parts.append("%d usos" % ability.UsesMax)
	var row = GameData.row("abilities", ability_id)
	var text: String = row.get("Description", "") if row != null else ""
	var summary := " · ".join(parts)
	return summary + ("
" if summary != "" and text != "" else "") + text


## Posições da própria equipe para onde o herói pode trocar (vizinhas, sem unidade grande nem imobilização).
func move_targets(actor_id: String) -> Array:
	var actor := state.find_unit(actor_id)
	var ranks: Array = []
	if actor == null or actor.stun_turns > 0 or actor.immobilize_turns > 0:
		return ranks
	for rank in [actor.rank - 1, actor.rank + 1]:
		if rank >= 1 and rank <= 4:
			var occupant = AHCombatEngine._find(state.player_team, func(u): return engine.occupies_rank(u, rank) and AHCombatEngine.alive_any(u))
			if occupant == null or (occupant.immobilize_turns <= 0 and engine.unit_size(occupant) == 1):
				ranks.append(rank)
	return ranks


func can_flee() -> bool:
	return not state.enemy_team.any(func(u): return u.enemy_id == "porteiro")


# ---------------------------------------------------------------- comandos

## Início do turno do herói (atordoamento, sangramento). Lance com can_act; se ele não puder agir, o turno já passou.
func begin_player_turn() -> Dictionary:
	var actor := current_actor()
	var events: Array = []
	var can_act := engine.process_player_turn_start(events)
	processed_turn_key = turn_key() if can_act else ""
	return {"source_id": actor.id if actor else "", "kind": "turn_start", "ability_id": "", "events": events, "ok": true, "error": "", "can_act": can_act}


## Quem a habilidade atinge mirando na posição (a prévia do alvo: par da granada, vizinho do coquetel).
func hit_ids(actor_id: String, ability_id: String, target_rank: int) -> Array:
	return engine.ability_hit_ids(actor_id, ability_id, target_rank)


func turn_key() -> String:
	return "%d:%s" % [state.round, state.current_turn_unit_id]


## Um item da Mochila no herói da vez (CombatUseItem): ação livre, a vez continua com ele. Gasta da campanha.
func use_item(campaign: Dictionary, kind: String) -> Dictionary:
	var quote := AHExplorationCare.combat_quote(campaign, self, kind)
	var actor := current_actor()
	var beat := {"source_id": actor.id if actor else "", "kind": "item", "ability_id": "", "events": [], "ok": false,
		"error": quote.reason, "escaped": false}
	if not quote.available:
		return beat
	if kind == AHExplorationCare.BANDAGE:
		AHJourneyRules.adjust(campaign, "bandages", -1)
	else:
		AHJourneyRules.adjust(campaign, "food", -quote.food_cost)
	actor.hp = mini(actor.max_hp, actor.hp + quote.heal_max)
	item_used_turn_key = turn_key()
	var what: String = {AHExplorationCare.BANDAGE: "usou um curativo", AHExplorationCare.SMALL_MEAL: "comeu pouco"}.get(kind, "comeu bem")
	var event := AHCombat.Event.new()
	event.type = AHCombat.EventType.HEAL
	event.target_unit_id = actor.id
	event.amount = quote.heal_max
	event.text = "+%d" % quote.heal_max
	state.combat_log.append("%s %s: +%d de vida." % [actor.display_name, what, quote.heal_max])
	beat.events = [event]
	beat.ok = true
	beat.error = ""
	beat.text = "%s %s: +%d de vida." % [actor.display_name, what, quote.heal_max]
	return beat


func use_ability(actor_id: String, ability_id: String, target_rank: int) -> Dictionary:
	var result := engine.execute_player_ability(actor_id, ability_id, target_rank)
	return _beat(actor_id, "ability", ability_id, result)


func move(actor_id: String, target_rank: int) -> Dictionary:
	return _beat(actor_id, "move", "", engine.execute_move(actor_id, target_rank))


func defend(actor_id: String) -> Dictionary:
	return _beat(actor_id, "defend", "", engine.execute_defend(actor_id))


func flee(actor_id: String) -> Dictionary:
	return _beat(actor_id, "flee", "", engine.execute_flee(actor_id))


## Turno do inimigo da vez. ability_id é a ação usada (id curto, como em enemy-actions.json depois do ponto).
func enemy_turn() -> Dictionary:
	var actor := current_actor()
	var actor_id := actor.id if actor else ""
	var events := engine.execute_enemy_turn()
	var ability_id := ""
	for event in events:
		if event.ability_id != "":
			ability_id = event.ability_id
			break
	return {"source_id": actor_id, "kind": "enemy", "ability_id": ability_id, "events": events, "ok": true, "error": ""}


## Turno automático do herói (a política fixa da paridade): para testes e para acelerar a QA.
func auto_player_turn() -> Dictionary:
	var actor := current_actor()
	var start := begin_player_turn()
	if not start.can_act or state.is_over:
		return start
	var result := engine.play_auto_turn(actor.id)
	var beat := _beat(actor.id, "ability" if result.used_ability_id != "" else "defend", result.used_ability_id, result)
	beat.events = start.events + beat.events
	return beat


## A ação de inimigo usada, pela linha de enemy-actions.json ("inimigo.acao").
func enemy_action(enemy_id: String, short_id: String):
	return data.enemy_actions.get("%s.%s" % [enemy_id, short_id])


func _beat(actor_id: String, kind: String, ability_id: String, result: AHCombat.ActionResult) -> Dictionary:
	_count(actor_id, result.events)
	return {"source_id": actor_id, "kind": kind, "ability_id": ability_id, "events": result.events, "ok": result.success,
		"error": result.error, "escaped": result.escaped}


# ---------------------------------------------------------------- fim da luta

## Soma o dano, a cura e quem caiu pelas mãos do herói (só os heróis contam).
func _count(actor_id: String, events: Array) -> void:
	var actor := state.find_unit(actor_id)
	if actor == null or not actor.is_player:
		return
	var entry: Dictionary = tally.get(actor.hero_id, {"damage": 0, "healing": 0, "downs": 0})
	for event in events:
		var target := state.find_unit(event.target_unit_id)
		if target == null:
			continue
		match event.type:
			AHCombat.EventType.DAMAGE:
				if not target.is_player:
					entry.damage += event.amount
			AHCombat.EventType.HEAL:
				if target.is_player:
					entry.healing += event.amount
			AHCombat.EventType.DEATH:
				if not target.is_player:
					entry.downs += 1
	tally[actor.hero_id] = entry


## A luta de uma expedição: a Esperança dela (a pressão de combate com ela baixa) e os laços entre os heróis, que as
## crises mudam e que valem a expedição inteira (Amizade e rivalidade pedem ±3, de luta em luta).
func use_expedition(campaign: Dictionary) -> void:
	var expedition = campaign.get("session", {}).get("expedition")
	if expedition == null:
		return
	context.hope = int(expedition.get("hope", context.hope))
	context.relationships = Dictionary(expedition.get("relationships", {})).duplicate()


## Grava na campanha a vida, o instinto e o trauma de cada herói; quem morreu fica com alive = false. Na vitória, a Íris
## recarrega a ampola.
func write_back(campaign: Dictionary) -> void:
	for unit in state.player_team:
		for hero in campaign.get("roster", []):
			if hero.id != unit.hero_id:
				continue
			var dead: bool = unit.hp <= 0 and not unit.deaths_door
			# A relíquia de vida aumenta o máximo só na luta: fora dela a vida volta ao máximo do herói (senão a noite e a
			# comida "curavam" para baixo).
			hero.hp = clampi(unit.hp, 1 if unit.deaths_door else 0, int(hero.max_hp))
			hero.instinct = unit.instinct
			hero.trauma = unit.trauma
			hero.alive = not dead
			hero.expedition_uses = {}
			for ability_id in unit.remaining_uses:
				var ability = data.abilities.get(ability_id)
				if ability != null and ability.bUsesPerExpedition:
					hero.expedition_uses[ability_id] = unit.remaining_uses[ability_id]
	AHExplorationCare.restore_iris_after_victory(campaign, self)
	# O que cada um fez soma na expedição (o relatório da volta destaca).
	var expedition = campaign.get("session", {}).get("expedition")
	if expedition != null:
		expedition.relationships = context.relationships.duplicate()
		var stats: Dictionary = expedition.get("stats", {})
		for hero_id in tally:
			var total: Dictionary = stats.get(hero_id, {"damage": 0, "healing": 0, "downs": 0})
			for key in ["damage", "healing", "downs"]:
				total[key] = int(total.get(key, 0)) + int(tally[hero_id][key])
			stats[hero_id] = total
		expedition.stats = stats
		tally.clear()
