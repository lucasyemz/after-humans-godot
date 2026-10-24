## Cuidados com a Mochila (port do FAHExplorationCare e do CombatUseItem da Unreal, #37): comer pouco ou bem (15% ou 35%
## da vida, 1 ou 3 de comida da expedição), curativo do refúgio (+8) e a Ampola de Reparo (a habilidade do sapo, de 5 a 8,
## com as cargas da expedição). Fora da luta, num aliado vivo da equipe; na luta, ação livre no herói da vez, um item por
## vez dele (a ampola lá é habilidade). quote() diz o que acontece e por que não; use() aplica.
class_name AHExplorationCare

const SMALL_MEAL := "small_meal"
const FULL_MEAL := "full_meal"
const BANDAGE := "bandage"
const IRIS_AMPOULE := "iris_ampoule"
const AMPOULE := "sapo_ampola_reparo_vivo"
## O mesmo curativo do acampamento.
const BANDAGE_HEAL := 8


static func _empty(kind: String) -> Dictionary:
	return {"available": false, "reason": "", "heal_min": 0, "heal_max": 0,
		"food_cost": 1 if kind == SMALL_MEAL else (3 if kind == FULL_MEAL else 0), "bandage_cost": 1 if kind == BANDAGE else 0,
		"charges": 0}


static func _hero(campaign: Dictionary, hero_id: String):
	for hero in campaign.get("roster", []):
		if hero.id == hero_id:
			return hero
	return null


static func _ampoule_row():
	return GameData.combat.abilities.get(AMPOULE)


## A Íris viva e na equipe (ou null).
static func iris(campaign: Dictionary):
	var expedition = campaign.get("session", {}).get("expedition")
	if expedition == null:
		return null
	for hero in campaign.roster:
		if hero.class_id == "sapo" and hero.alive and hero.hp > 0 and expedition.team.has(hero.id):
			return hero
	return null


## Cargas da ampola que a Íris ainda tem nesta expedição (sem reservar nada).
static func ampoule_charges(campaign: Dictionary) -> int:
	var healer = iris(campaign)
	var row = _ampoule_row()
	if healer == null or row == null:
		return 0
	var uses: Dictionary = healer.get("expedition_uses", {})
	return clampi(int(uses[AMPOULE]), 0, row.UsesMax) if uses.has(AMPOULE) else row.UsesMax


static func _meal_heal(kind: String, max_hp: int, missing: int) -> int:
	return mini(missing, maxi(1, max_hp * (15 if kind == SMALL_MEAL else 35) / 100))


## Fora da luta (Quote): o que o cuidado faz no aliado e por que não, se não der.
static func quote(campaign: Dictionary, hero_id: String, kind: String) -> Dictionary:
	var q := _empty(kind)
	if kind == IRIS_AMPOULE:
		q.charges = ampoule_charges(campaign)
	var session: Dictionary = campaign.get("session", {})
	if session.get("expedition") == null or session.get("result", "") != "" or session.get("event") != null \
			or session.get("screen") != "corridor":
		q.reason = "Disponível fora de combate e eventos, durante a exploração."
		return q
	var target = _hero(campaign, hero_id)
	if target == null or not target.alive or target.hp <= 0 or not session.expedition.team.has(hero_id):
		q.reason = "Selecione um aliado vivo da expedição."
		return q
	if target.hp >= target.max_hp:
		q.reason = "O aliado já está com a vida cheia."
		return q
	var missing: int = target.max_hp - target.hp
	match kind:
		BANDAGE:
			q.heal_min = mini(missing, BANDAGE_HEAL)
			q.heal_max = q.heal_min
			if int(campaign.inventory.bandages) <= 0:
				q.reason = "Sem curativos no estoque."
				return q
		IRIS_AMPOULE:
			var row = _ampoule_row()
			if iris(campaign) == null or row == null or row.UsesMax <= 0 or row.HealRange.Max <= 0:
				q.reason = "Um sapo vivo precisa estar na equipe."
				return q
			# Os heróis jogáveis são orgânicos; uma classe fora da tabela não passa.
			if GameData.row("classes", target.class_id) == null:
				q.reason = "A ampola trata somente aliados orgânicos."
				return q
			var bonus := 1 if campaign.get("researched_skills", []).has(AMPOULE) else 0
			q.heal_min = mini(missing, row.HealRange.Min + bonus)
			q.heal_max = mini(missing, row.HealRange.Max + bonus)
			if q.charges <= 0:
				q.reason = "Sem cargas. A ampola recarrega após uma vitória."
				return q
		_:
			q.heal_min = _meal_heal(kind, target.max_hp, missing)
			q.heal_max = q.heal_min
			if AHJourneyRules.food(campaign) < q.food_cost:
				q.reason = "Comida insuficiente."
				return q
	q.available = true
	return q


## Usa o cuidado no aliado (Use). Devolve quanto curou (0 se não deu).
static func use(campaign: Dictionary, hero_id: String, kind: String) -> int:
	var q := quote(campaign, hero_id, kind)
	if not q.available:
		return 0
	var target = _hero(campaign, hero_id)
	var heal: int = q.heal_min
	match kind:
		IRIS_AMPOULE:
			var row = _ampoule_row()
			var bonus := 1 if campaign.get("researched_skills", []).has(AMPOULE) else 0
			# A cura sorteada sai da semente da rota e de quantas cargas já foram (o mesmo resultado ao repetir).
			var route: Dictionary = campaign.session.expedition.corridor
			var random := AHJourneyRules._rand(int(route.seed) ^ AHJourneyRules._mul(q.charges + 1, 0x6a09e667) ^ hash(hero_id))
			heal = row.HealRange.Min + bonus + floori(random.next() * (row.HealRange.Max - row.HealRange.Min + 1))
			iris(campaign).expedition_uses[AMPOULE] = q.charges - 1
		BANDAGE:
			AHJourneyRules.adjust(campaign, "bandages", -1)
		_:
			AHJourneyRules.adjust(campaign, "food", -q.food_cost)
	var before: int = target.hp
	target.hp = mini(target.max_hp, target.hp + heal)
	return target.hp - before


## Na luta (CombatQuote): o item no herói da vez, enquanto ele decide; um por vez dele.
static func combat_quote(campaign: Dictionary, session: AHCombatSession, kind: String) -> Dictionary:
	var q := _empty(kind)
	if session == null or session.is_over():
		q.reason = "Nenhuma luta em andamento."
		return q
	if kind == IRIS_AMPOULE:
		q.reason = "Na luta, a ampola é uma habilidade do sapo."
		return q
	var unit := session.current_actor()
	if unit == null or not unit.is_player or session.processed_turn_key != session.turn_key():
		q.reason = "Espere a vez de um aliado."
		return q
	if session.item_used_turn_key == session.turn_key():
		q.reason = "%s já usou um item nesta vez." % unit.display_name
		return q
	if unit.hp <= 0:
		q.reason = "No Limiar da Morte, só uma habilidade de cura salva."
		return q
	if unit.hp >= unit.max_hp:
		q.reason = "%s está com a vida cheia." % unit.display_name
		return q
	var missing := unit.max_hp - unit.hp
	if kind == BANDAGE:
		q.heal_min = mini(missing, BANDAGE_HEAL)
		q.heal_max = q.heal_min
		if int(campaign.inventory.bandages) <= 0:
			q.reason = "Sem curativos no estoque."
			return q
	else:
		q.heal_min = _meal_heal(kind, unit.max_hp, missing)
		q.heal_max = q.heal_min
		if AHJourneyRules.food(campaign) < q.food_cost:
			q.reason = "Comida insuficiente."
			return q
	q.available = true
	return q


## A Íris recarrega a ampola depois de uma vitória (não de fuga nem derrota): na campanha e na foto da luta.
static func restore_iris_after_victory(campaign: Dictionary, session: AHCombatSession) -> void:
	if session == null or session.result() != "victory":
		return
	var row = _ampoule_row()
	if row == null:
		return
	for unit in session.state.player_team:
		var hero = _hero(campaign, unit.hero_id)
		if hero != null and hero.alive and hero.hp > 0 and hero.class_id == "sapo":
			hero.expedition_uses[AMPOULE] = row.UsesMax
			unit.remaining_uses[AMPOULE] = row.UsesMax
