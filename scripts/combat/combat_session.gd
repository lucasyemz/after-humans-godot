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
## O instinto que o Sangue frio tirou de cada herói no começo da luta (#90): volta no write_back, porque o desconto é só
## da luta. {hero_id: n}.
var calm := {}
## Quem derrubou o último inimigo até agora: um herói (true) ou outra coisa, como o sangramento na vez dele (#91, o
## critério do golpe final).
var last_down_by_hero := false
## O XP que cada herói ganhou nesta luta (o write_back preenche; a tela do fim da luta mostra, #91). {hero_id: n}.
var xp_gained := {}


## heroes: heróis da campanha (Campaign.state.roster) na ordem da formação. enemies: da frente para trás, cada um o id
## do inimigo ou já montado pelo corredor ({enemy_id, unit_id, rank, hp, max_hp, damage_bonus, display_name} e, no
## tutorial, speed_bonus).
## phase_effects: os efeitos de fase da expedição (AHJourneyRules.phase_effects, #78): a velocidade entra antes da
## iniciativa e os marcadores (Vulnerável, Bloqueio) já estão nos heróis quando a luta começa.
static func create(heroes: Array, enemies_in: Array, opening: bool = false, seed_value: int = -1, hope: int = 80,
		phase_effects: Array = []) -> AHCombatSession:
	var session := AHCombatSession.new()
	session.data = GameData.combat
	session.random = AHCombatRandom.new(seed_value if seed_value >= 0 else randi())
	session.context = AHCombat.Context.new()
	session.context.hope = hope
	var players: Array = []
	var marks := {"speed": 0, "vuln": 0, "block": 0}
	for id in phase_effects:
		var effect: Dictionary = AHJourneyRules.PHASE_EFFECTS.get(id, {})
		for key in marks:
			marks[key] += int(effect.get(key, 0))
	for index in heroes.size():
		var hero: Dictionary = heroes[index]
		# O nível (#90): a velocidade, o +1 numa habilidade e o instinto a menos no começo da luta (a vida já está no herói).
		var bonus := AHHeroLevels.combat_bonus(hero)
		session.calm[hero.id] = mini(int(bonus.calm), int(hero.get("instinct", 0)))
		players.append(AHCombatEngine.make_hero_unit({
			"Id": hero.id, "ClassId": hero.class_id, "DisplayName": hero.display_name, "MaxHp": hero.max_hp, "Hp": hero.hp,
			"Instinct": maxi(0, int(hero.get("instinct", 0)) - int(bonus.calm)), "Perks": hero.get("perks", []), "Trauma": hero.get("trauma", false),
			"RelicId": hero.get("relic_id", ""), "ExpeditionUses": hero.get("expedition_uses", {}),
			"AbilityIds": AHRecruitSkills.abilities(hero) if AHRecruitSkills.flexible(hero) else [],
			"SpeedBonus": int(bonus.speed) + marks.speed, "AbilityBonus": bonus.abilities,
		}, index + 1, session.data))
		var unit: Unit = players[-1]
		unit.tokens.vuln = mini(AHCombatEngine.TOKEN_CAP, marks.vuln)
		unit.tokens.block = mini(AHCombatEngine.TOKEN_CAP, marks.block)
	var enemies: Array = []
	var next_rank := 1
	for index in enemies_in.size():
		var spec = enemies_in[index]
		if typeof(spec) == TYPE_DICTIONARY:
			var built := AHCombatEngine.make_enemy_unit(spec.enemy_id, spec.unit_id, spec.rank, session.data)
			built.hp = spec.get("hp", built.hp)
			built.max_hp = spec.get("max_hp", built.max_hp)
			built.damage_bonus = spec.get("damage_bonus", 0)
			built.speed += int(spec.get("speed_bonus", 0))
			built.display_name = spec.get("display_name", built.display_name)
			enemies.append(built)
			continue
		var unit := AHCombatEngine.make_enemy_unit(spec, "enemy_%s_%d" % [spec, index], next_rank, session.data)
		enemies.append(unit)
		var row = session.data.enemies.get(spec)
		next_rank += row.FormationSize if row != null and row.FormationSize > 0 else 1
	session.state = AHCombatEngine.init_combat(players, enemies, session.context, session.data, session.random, opening)
	session.engine = AHCombatEngine.new(session.state, session.context, session.data, session.random)
	for id in phase_effects:
		if AHJourneyRules.PHASE_EFFECTS.has(id):
			session.state.combat_log.append(TranslationServer.translate(AHJourneyRules.PHASE_EFFECTS[id].log))
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

## As habilidades do herói (as que ele leva, #189), na ordem: {id, name, description, usable, reason, targets, enemy_side, cooldown, uses}.
func ability_options(actor_id: String) -> Array:
	var actor := state.find_unit(actor_id)
	var options: Array = []
	if actor == null:
		return options
	for ability_id in engine.abilities_of(actor):
		var ability = data.abilities.get(ability_id)
		if ability == null:
			continue
		var cooldown: int = actor.cooldowns.get(ability_id, 0)
		var uses: int = actor.remaining_uses.get(ability_id, ability.UsesMax) if ability.UsesMax > 0 else -1
		var targets := engine.valid_targets(actor_id, ability_id)
		var reason := ""
		if actor.stun_turns > 0:
			reason = tr("Atordoado")
		elif not ability.OriginRanks.has(actor.rank):
			reason = tr("Usa das posições %s") % ", ".join(ability.OriginRanks.map(func(r): return str(r)))
		elif cooldown > 0:
			reason = tr("Recarga: %d turno(s)") % cooldown
		elif uses == 0:
			reason = tr("Sem usos")
		elif targets.is_empty():
			reason = tr("Sem alvo válido")
		options.append({
			"id": ability_id, "name": ability.DisplayName, "description": describe(ability_id, actor_id), "usable": reason == "",
			"reason": reason, "targets": targets, "enemy_side": ability.TargetType == "SingleEnemy" or ability.TargetType == "MarkedEnemy",
			"self": ability.TargetType == "Self", "cooldown": cooldown, "uses": uses,
		})
	return options


## A faixa que a habilidade causa de verdade nesta luta (kind "damage" ou "heal"): a dos dados, +1 nos dois limites se
## ela foi treinada na Pesquisa e mais a Mão treinada do nível de quem age (actor_id, #90): o mesmo bônus do motor.
## {Min, Max, trained}.
func effective_range(ability_id: String, kind: String = "damage", actor_id: String = "") -> Dictionary:
	var ability: Dictionary = data.abilities[ability_id]
	var base: Dictionary = ability.DamageRange if kind == "damage" else ability.HealRange
	var bonus := 1 if context.researched_skills.has(ability_id) else 0
	var actor := state.find_unit(actor_id) if actor_id != "" else null
	if actor != null:
		bonus += int(actor.ability_bonus.get(ability_id, 0))
	var trained: bool = base.Max > 0 and bonus > 0
	if not trained:
		bonus = 0
	return {"Min": int(base.Min) + bonus, "Max": int(base.Max) + bonus, "trained": trained}


## Texto curto da habilidade: o que faz em números (com o treino da Pesquisa e o nível de quem age) e a descrição de
## abilities.json.
func describe(ability_id: String, actor_id: String = "") -> String:
	var ability: Dictionary = data.abilities[ability_id]
	var parts := PackedStringArray()
	if ability.DamageRange.Max > 0:
		var damage := effective_range(ability_id, "damage", actor_id)
		parts.append(tr("Dano %d–%d%s") % [damage.Min, damage.Max, tr(" (treinado)") if damage.trained else ""])
	if ability.HealRange.Max > 0:
		var heal := effective_range(ability_id, "heal", actor_id)
		parts.append(tr("Cura %d–%d%s") % [heal.Min, heal.Max, tr(" (treinado)") if heal.trained else ""])
	if ability.Cooldown > 0:
		parts.append(tr("Recarga %d") % ability.Cooldown)
	if ability.UsesMax > 0:
		parts.append(tr("%d usos") % ability.UsesMax)
	var row = GameData.row("abilities", ability_id)
	var text: String = tr(row.get("Description", "")) if row != null and row.get("Description", "") != "" else ""
	var summary := " · ".join(parts)
	return summary + ("\n" if summary != "" and text != "" else "") + text


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
	_watch(events, false)
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
	var what: String = {AHExplorationCare.BANDAGE: tr("usou um curativo"), AHExplorationCare.SMALL_MEAL: tr("comeu pouco")}.get(kind, tr("comeu bem"))
	var event := AHCombat.Event.new()
	event.type = AHCombat.EventType.HEAL
	event.target_unit_id = actor.id
	event.amount = quote.heal_max
	event.text = "+%d" % quote.heal_max
	state.combat_log.append(tr("%s %s: +%d de vida.") % [actor.display_name, what, quote.heal_max])
	beat.events = [event]
	beat.ok = true
	beat.error = ""
	beat.text = tr("%s %s: +%d de vida.") % [actor.display_name, what, quote.heal_max]
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
	_watch(events, false)
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
	_watch(events, actor != null and actor.is_player)
	if actor == null or not actor.is_player:
		return
	var entry: Dictionary = tally.get(actor.hero_id, {"damage": 0, "healing": 0, "downs": 0, "protects": 0})
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
		# Proteger um aliado (#90): a guarda ou o bloqueio dado a outro herói.
		if target.is_player and target.id != actor.id and (event.outcome == AHCombat.Outcome.GUARD_GRANTED or event.outcome == AHCombat.Outcome.BLOCK_GRANTED):
			entry.protects = int(entry.get("protects", 0)) + 1
	tally[actor.hero_id] = entry


## Anota quem derrubou o último inimigo nestes eventos (by_hero: a ação de um herói).
func _watch(events: Array, by_hero: bool) -> void:
	for event in events:
		var target := state.find_unit(event.target_unit_id)
		if event.type == AHCombat.EventType.DEATH and target != null and not target.is_player:
			last_down_by_hero = by_hero


## A luta de uma expedição: os treinos da Pesquisa (+1 no dano ou na cura da habilidade treinada), a Esperança dela (a
## pressão de combate com ela baixa) e os laços entre os heróis, que as crises mudam e que valem a expedição inteira
## (Amizade e rivalidade pedem ±3, de luta em luta).
func use_expedition(campaign: Dictionary) -> void:
	context.researched_skills = Array(campaign.get("researched_skills", [])).duplicate()
	var expedition = campaign.get("session", {}).get("expedition")
	if expedition == null:
		return
	context.hope = int(expedition.get("hope", context.hope))
	context.relationships = Dictionary(expedition.get("relationships", {})).duplicate()


## Grava na campanha a vida, o instinto e o trauma de cada herói; quem caiu fica com alive = false até o fim da expedição (#118: volta Caído, não morre). Na vitória, a Íris
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
			# O Sangue frio vale só na luta: o instinto que ele tirou volta. Sem crise na luta, o que volta não leva à crise;
			# quem terminou a luta em crise (no máximo ou com o desfecho) continua nela.
			hero.instinct = unit.instinct
			var back := int(calm.get(unit.hero_id, 0))
			if back > 0:
				var top := int(engine.instinct_rules().Max)
				var in_crisis: bool = unit.instinct >= top or unit.crisis_outcome != AHCombat.Crisis.NONE
				hero.instinct = mini(unit.instinct + back, top if in_crisis else top - 1)
				# A luta acabou: a unidade fica com o instinto devolvido, e o calm é limpo abaixo (gravar de novo dá o mesmo).
				unit.instinct = hero.instinct
			hero.trauma = unit.trauma
			hero.alive = not dead
			hero.expedition_uses = {}
			for ability_id in unit.remaining_uses:
				var ability = data.abilities.get(ability_id)
				if ability != null and ability.bUsesPerExpedition:
					hero.expedition_uses[ability_id] = unit.remaining_uses[ability_id]
	# Limpo como o tally: o instinto do Sangue frio já voltou para a unidade e o herói, e não volta em dobro.
	calm.clear()
	AHExplorationCare.restore_iris_after_victory(campaign, self)
	# O que cada um fez soma na expedição (o relatório da volta destaca).
	var expedition = campaign.get("session", {}).get("expedition")
	if expedition != null:
		expedition.relationships = context.relationships.duplicate()
		var stats: Dictionary = expedition.get("stats", {})
		for hero_id in tally:
			var total: Dictionary = stats.get(hero_id, {"damage": 0, "healing": 0, "downs": 0})
			for key in ["damage", "healing", "downs", "protects"]:
				total[key] = int(total.get(key, 0)) + int(tally[hero_id].get(key, 0))
			stats[hero_id] = total
		# O XP da luta (#90): quem lutou e segue vivo, pelo que fez (o tally), soma no herói e no relatório. A fuga não dá.
		for unit in (state.player_team if not state.escaped else []):
			var hero = AHStationRules.hero(campaign, unit.hero_id)
			if hero == null or not hero.get("alive", true):
				continue
			var gained := AHHeroLevels.gain(hero, AHHeroLevels.fight_xp(tally.get(unit.hero_id, {})))
			xp_gained[unit.hero_id] = gained
			var total: Dictionary = stats.get(unit.hero_id, {"damage": 0, "healing": 0, "downs": 0})
			total.xp = int(total.get("xp", 0)) + gained
			stats[unit.hero_id] = total
		expedition.stats = stats
		tally.clear()
