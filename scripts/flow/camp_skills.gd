## As habilidades de acampamento (#261, aprovado pelo Orquestrador em nome do Lucas em 01/11): 7 por papel (2 comuns a
## todos e 5 do papel, data/camp-skills.json), separadas das 7 de combate (#259). A regra é a mesma para fundadores e
## recrutados (#189).
## - O catálogo: as comuns e as do papel (Class é o id da classe). Cada herói chega com as 3 Starter.
## - Aprender: em cada nível de Levels (2, 4, 6 e 8, data/hero-skills.json, linha camp), uma das que faltam, de graça e à
##   escolha do jogador, na Sala (picks diz quantas escolhas ele tem para fazer). Sem moeda nova.
## - Levar: MaxEquipped (4) equipadas, trocadas na Sala, fora da expedição (camp_loadout; [] são as primeiras que sabe).
## - No acampamento: Time (12) de Tempo de fogueira por acampamento; cada habilidade custa Cost, e cada herói usa cada uma
##   no máximo uma vez por acampamento. A Ração e o Curativo não gastam Tempo.
## - Os efeitos: a vida, o Instinto e a Esperança mudam na hora (até os limites de hoje); Bloqueio, Esquiva, velocidade, a
##   Marca no inimigo da frente e a abertura valem só na próxima luta (next_fight; saem quando ela começa).
## - A Noite mal dormida: ao levantar acampamento, BadNight de chance (o sorteio da semente da fase) de a equipe ficar com
##   BadNightEffect (Exposto, o efeito de fase de hoje), a menos que alguém tenha vigiado (watch).
## Save: no herói, camp_unlocked (as aprendidas) e camp_loadout; no trecho da expedição (corridor), camp (o acampamento
## de agora: o Tempo gasto, quem usou o quê e se alguém vigiou), camp_next (os bônus da próxima luta) e camp_night (como
## foi a última noite, para o aviso).
class_name AHCampSkills
extends RefCounted

const J := preload("res://scripts/flow/journey_rules.gd")


## As regras (data/hero-skills.json, linha camp).
static func rule(key: String, fallback = null):
	var row = GameData.row("hero_skills", "camp")
	return row.get(key, fallback) if row != null else fallback


static func max_equipped() -> int:
	return int(rule("MaxEquipped", 4))


static func time_budget() -> int:
	return int(rule("Time", 12))


## Uma habilidade (a linha de data/camp-skills.json), ou null.
static func skill(skill_id: String):
	var row = GameData.row("camp_skills", skill_id)
	return row if row != null and row.has("Cost") else null


## As 7 do papel: as 2 comuns e as 5 da classe, na ordem dos dados.
static func catalog(class_id: String) -> Array:
	var common: Array = []
	var own: Array = []
	for row in GameData.table("camp_skills").values():
		if not row.has("Cost"):
			continue
		if String(row.Class) == "":
			common.append(String(row.Name))
		elif String(row.Class) == class_id:
			own.append(String(row.Name))
	return common + own


## As 3 com que todo herói da classe chega.
static func starters(class_id: String) -> Array:
	return catalog(class_id).filter(func(id): return bool(skill(id).get("Starter", false)))


## As que ele sabe: as da chegada e as aprendidas.
static func known(hero: Dictionary) -> Array:
	var out: Array = starters(String(hero.get("class_id", "")))
	var own := catalog(String(hero.get("class_id", "")))
	for id in hero.get("camp_unlocked", []):
		if own.has(String(id)) and not out.has(String(id)):
			out.append(String(id))
	return out


## Quantas o nível deixa aprender (uma por nível de Levels já alcançado).
static func slots_at(level: int) -> int:
	return Array(rule("Levels", [])).filter(func(at): return int(at) <= level).size()


## As escolhas que ele tem para fazer na Sala (o nível já deixou e ele ainda não escolheu).
static func picks(hero: Dictionary) -> int:
	var learned: int = known(hero).size() - starters(String(hero.get("class_id", ""))).size()
	var missing: int = catalog(String(hero.get("class_id", ""))).size() - known(hero).size()
	return clampi(slots_at(AHHeroLevels.level(hero)) - learned, 0, missing)


## O próximo nível que dá uma escolha (0 quando não há mais).
static func next_level(hero: Dictionary) -> int:
	var learned: int = known(hero).size() - starters(String(hero.get("class_id", ""))).size()
	var levels: Array = rule("Levels", [])
	return int(levels[learned]) if learned < levels.size() else 0


## As 4 que vão para o acampamento: a escolha dele, se valer; senão, as primeiras que sabe.
static func equipped(hero: Dictionary) -> Array:
	var chosen: Array = hero.get("camp_loadout", [])
	if not chosen.is_empty() and invalid(hero, chosen) == "":
		return chosen.duplicate()
	return known(hero).slice(0, max_equipped())


## Por que a escolha não vale ("" vale): quantas (as 4, ou todas que sabe se forem menos), sem repetir, só as que sabe.
static func invalid(hero: Dictionary, chosen: Array) -> String:
	var want := mini(max_equipped(), known(hero).size())
	if chosen.size() != want:
		return TranslationServer.translate("Leve %d habilidades de acampamento.") % want
	var seen := {}
	for id in chosen:
		if seen.has(String(id)):
			return TranslationServer.translate("Habilidade repetida.")
		seen[String(id)] = true
		if not known(hero).has(String(id)):
			return TranslationServer.translate("Essa habilidade ainda não foi aprendida.")
	return ""


static func _in_expedition(campaign: Dictionary) -> bool:
	return campaign.get("session", {}).get("expedition") != null


## Troca as que vão (na Sala, fora da expedição). Devolve o erro ("" deu certo).
static func choose(campaign: Dictionary, hero_id: String, chosen: Array) -> String:
	var hero = AHStationRules.hero(campaign, hero_id)
	if hero == null:
		return TranslationServer.translate("Herói não encontrado.")
	if _in_expedition(campaign):
		return TranslationServer.translate("As habilidades se trocam na Estação, fora da expedição.")
	var reason := invalid(hero, chosen)
	if reason != "":
		return reason
	hero.camp_loadout = [] if chosen == known(hero).slice(0, max_equipped()) else chosen.duplicate()
	return ""


## Aprende uma das que faltam (uma escolha do nível, na Sala). Com vaga entre as que leva, ela já vai. Devolve o erro.
static func learn(campaign: Dictionary, hero_id: String, skill_id: String) -> String:
	var hero = AHStationRules.hero(campaign, hero_id)
	if hero == null:
		return TranslationServer.translate("Herói não encontrado.")
	if _in_expedition(campaign):
		return TranslationServer.translate("As habilidades se trocam na Estação, fora da expedição.")
	if picks(hero) <= 0:
		var at := next_level(hero)
		return TranslationServer.translate("Nível %d · escolha no Treino.") % at if at > 0 else TranslationServer.translate("Já sabe todas.")
	if not catalog(String(hero.class_id)).has(skill_id) or known(hero).has(skill_id):
		return TranslationServer.translate("Essa habilidade já foi aprendida.")
	var before := equipped(hero)
	if typeof(hero.get("camp_unlocked")) != TYPE_ARRAY:
		hero.camp_unlocked = []
	hero.camp_unlocked.append(skill_id)
	# Com vaga entre as que leva, a nova vai junto; com as 4, ela fica na Estação (troca na Sala).
	if before.size() < max_equipped():
		hero.camp_loadout = [] if before + [skill_id] == known(hero).slice(0, max_equipped()) else before + [skill_id]
	return ""


## O requisito de uma que ainda não sabe ("Nível 4 · Treino", "Aprenda no Treino"), para a Sala e a ficha.
static func requirement(hero: Dictionary) -> String:
	if picks(hero) > 0:
		return TranslationServer.translate("Aprenda no Treino")
	var at := next_level(hero)
	return TranslationServer.translate("Nível %d · Treino") % at if at > 0 else ""


## O aviso depois do Treino num nível que dá uma escolha ("" nos outros).
static func level_notice(hero: Dictionary) -> String:
	if picks(hero) <= 0:
		return ""
	return TranslationServer.translate("Nova habilidade de acampamento: aprenda no Treino.")


## Saves de antes do #261 e editados: só ids do papel, sem repetir, até o que o nível deixa; o que levava e não vale
## volta para as primeiras que sabe. Quem já está no nível 2 ou acima fica com as escolhas para fazer no Treino.
static func migrate(campaign: Dictionary) -> void:
	for hero in campaign.get("roster", []):
		if typeof(hero) != TYPE_DICTIONARY:
			continue
		var own := catalog(String(hero.get("class_id", "")))
		var start := starters(String(hero.get("class_id", "")))
		# O save editado pode trazer outro tipo no lugar das listas: vira lista vazia, e só ids (texto) contam.
		var learned = hero.get("camp_unlocked", [])
		var kept: Array = []
		for id in (learned if typeof(learned) == TYPE_ARRAY else []):
			if typeof(id) == TYPE_STRING and own.has(id) and not start.has(id) and not kept.has(id):
				kept.append(id)
		hero.camp_unlocked = kept.slice(0, slots_at(AHHeroLevels.level(hero)))
		var loadout = hero.get("camp_loadout", [])
		var chosen: Array = []
		for id in (loadout if typeof(loadout) == TYPE_ARRAY else []):
			chosen.append(id if typeof(id) == TYPE_STRING else "")
		hero.camp_loadout = chosen if not chosen.is_empty() and invalid(hero, chosen) == "" else []


# ================================================================ no acampamento

## O acampamento de agora (no trecho): {time, used {hero_id: [ids]}, watch}. Nasce vazio a cada acampamento.
static func camp(campaign: Dictionary) -> Dictionary:
	var route = J.corridor(campaign)
	if route == null:
		return {}
	if typeof(route.get("camp")) != TYPE_DICTIONARY or typeof(route.camp.get("used")) != TYPE_DICTIONARY:
		route.camp = {"time": 0, "used": {}, "watch": false}
	return route.camp


## Um acampamento novo começa: o Tempo volta inteiro (e a noite passada não conta).
static func start(campaign: Dictionary) -> void:
	var route = J.corridor(campaign)
	if route != null:
		route.camp = {"time": 0, "used": {}, "watch": false}
		route.erase("camp_night")


static func time_left(campaign: Dictionary) -> int:
	return maxi(0, time_budget() - int(camp(campaign).get("time", 0)))


## Os bônus que valem na próxima luta: {heroes {hero_id: {block, dodge, speed}}, opening, mark_front}.
static func next_fight(campaign: Dictionary) -> Dictionary:
	var route = J.corridor(campaign)
	if route == null:
		return {}
	if typeof(route.get("camp_next")) != TYPE_DICTIONARY or typeof(route.camp_next.get("heroes")) != TYPE_DICTIONARY:
		route.camp_next = {"heroes": {}, "opening": false, "mark_front": false}
	return route.camp_next


## A luta começou: os bônus do acampamento já entraram e saem.
static func spend_next_fight(campaign: Dictionary) -> void:
	var route = J.corridor(campaign)
	if route != null:
		route.erase("camp_next")


## Se a próxima luta começa com a equipe agindo primeiro (Rondar o Quarteirão). Gasta a abertura.
static func take_opening(campaign: Dictionary) -> bool:
	var route = J.corridor(campaign)
	if route == null or typeof(route.get("camp_next")) != TYPE_DICTIONARY or not bool(route.camp_next.get("opening", false)):
		return false
	route.camp_next.opening = false
	return true


static func _team(campaign: Dictionary) -> Array:
	var out: Array = []
	for hero_id in campaign.session.expedition.team:
		var hero = AHStationRules.hero(campaign, hero_id)
		if hero != null and hero.alive and int(hero.hp) > 0:
			out.append(hero)
	return out


static func needs_target(skill_id: String) -> bool:
	var row = skill(skill_id)
	return row != null and String(row.Target) == "ally"


## Quem recebe: o próprio (self), o aliado escolhido (ally) ou a equipe (team). [] se o alvo não vale.
static func targets(campaign: Dictionary, user_id: String, skill_id: String, target_id: String = "") -> Array:
	var row = skill(skill_id)
	if row == null:
		return []
	match String(row.Target):
		"self":
			var user = AHStationRules.hero(campaign, user_id)
			return [user] if user != null else []
		"ally":
			if target_id == user_id:
				return []
			for hero in _team(campaign):
				if hero.id == target_id:
					return [hero]
			return []
	return _team(campaign)


static func _heal(hero: Dictionary, pct: int) -> int:
	return mini(int(hero.max_hp) - int(hero.hp), maxi(1, int(hero.max_hp) * pct / 100))


## O que a habilidade faria agora, sem mudar nada: {available, reason, cost, changes [texto]}. user_id usa; target_id é
## o aliado (só nas de aliado).
static func quote(campaign: Dictionary, user_id: String, skill_id: String, target_id: String = "") -> Dictionary:
	var out := {"available": false, "reason": "", "cost": 0, "changes": [], "needs_target": needs_target(skill_id)}
	var row = skill(skill_id)
	if row == null or campaign.get("session", {}).get("screen") != "rest":
		out.reason = TranslationServer.translate("Só no acampamento.")
		return out
	out.cost = int(row.Cost)
	var user = AHStationRules.hero(campaign, user_id)
	if user == null or not user.alive or int(user.hp) <= 0 or not campaign.session.expedition.team.has(user_id):
		out.reason = TranslationServer.translate("Selecione um aliado vivo da equipe.")
		return out
	if not equipped(user).has(skill_id):
		out.reason = TranslationServer.translate("Essa habilidade não foi levada nesta expedição.")
		return out
	if Array(camp(campaign).get("used", {}).get(user_id, [])).has(skill_id):
		out.reason = TranslationServer.translate("Já usada neste acampamento.")
		return out
	if time_left(campaign) < out.cost:
		out.reason = TranslationServer.translate("Sem Tempo de fogueira: faltam %d.") % (out.cost - time_left(campaign))
		return out
	if needs_target(skill_id) and target_id == "":
		out.reason = TranslationServer.translate("Escolha o aliado.")
		return out
	var who := targets(campaign, user_id, skill_id, target_id)
	if who.is_empty():
		out.reason = TranslationServer.translate("Escolha outro aliado da equipe.")
		return out
	var effects: Dictionary = row.get("Effects", {})
	if effects.has("ampoule") and AHExplorationCare.iris(campaign) != user:
		out.reason = TranslationServer.translate("Só quem leva a Ampola entre as 4 da luta.")
		return out
	if bool(effects.get("wounded", false)) and not AHWounded.is_wounded(who[0]):
		out.reason = TranslationServer.translate("Só em quem está Ferido.")
		return out
	out.changes = _changes(campaign, user, who, effects)
	if out.changes.is_empty():
		out.reason = TranslationServer.translate("Não faria diferença agora.")
		return out
	out.available = true
	return out


## O que muda (os textos curtos), sem mudar nada.
static func _changes(campaign: Dictionary, user: Dictionary, who: Array, effects: Dictionary) -> Array:
	var out: Array = []
	var expedition: Dictionary = campaign.session.expedition
	var route: Dictionary = expedition.corridor
	var next := next_fight(campaign)
	if effects.has("heal_pct") and who.any(func(h): return int(h.hp) < int(h.max_hp)):
		out.append(TranslationServer.translate("+%d%% de vida") % int(effects.heal_pct))
	if effects.has("instinct") and who.any(func(h): return int(h.get("instinct", 0)) > 0):
		out.append(TranslationServer.translate("%d de Instinto") % int(effects.instinct))
	if effects.has("hope") and int(expedition.get("hope", 0)) < 100:
		out.append(TranslationServer.translate("+%d de Esperança") % int(effects.hope))
	if effects.has("food") and J.food(campaign) < J.MAX_FOOD:
		out.append(TranslationServer.translate("+%d comida") % int(effects.food))
	if effects.has("bandage"):
		out.append(TranslationServer.translate("+%d curativo") % int(effects.bandage))
	if effects.has("ampoule") and AHExplorationCare.iris(campaign) == user:
		var row = GameData.combat.abilities.get(AHExplorationCare.AMPOULE)
		if row != null and AHExplorationCare.ampoule_charges(campaign) < int(row.UsesMax):
			out.append(TranslationServer.translate("+%d carga da Ampola") % int(effects.ampoule))
	for kind in ["block", "dodge"]:
		if effects.has(kind) and who.any(func(h): return _next_of(next, h.id, kind) < AHCombatEngine.TOKEN_CAP):
			out.append((TranslationServer.translate("+%d Bloqueio na próxima luta") if kind == "block" else TranslationServer.translate("+%d Esquiva na próxima luta")) % int(effects[kind]))
	if effects.has("self_block") and _next_of(next, user.id, "block") < AHCombatEngine.TOKEN_CAP:
		out.append(TranslationServer.translate("e +%d Bloqueio para quem usa") % int(effects.self_block))
	if effects.has("speed") and who.any(func(h): return _next_of(next, h.id, "speed") < int(effects.speed)):
		out.append(TranslationServer.translate("+%d de velocidade na próxima luta") % int(effects.speed))
	if bool(effects.get("mark_front", false)) and not bool(next.get("mark_front", false)):
		out.append(TranslationServer.translate("o inimigo da frente começa Marcado"))
	if bool(effects.get("opening", false)) and not bool(next.get("opening", false)):
		out.append(TranslationServer.translate("a equipe age primeiro na próxima luta"))
	if bool(effects.get("watch", false)) and not bool(camp(campaign).get("watch", false)):
		out.append(TranslationServer.translate("vigia a noite"))
	if effects.has("phase") and not Array(route.get("effects", [])).has(String(effects.phase)):
		out.append(TranslationServer.translate(String(J.PHASE_EFFECTS.get(String(effects.phase), {}).get("text", effects.phase))))
	for id in effects.get("clear", []):
		if Array(route.get("effects", [])).has(String(id)):
			out.append(TranslationServer.translate("tira %s") % TranslationServer.translate(String(J.PHASE_EFFECTS.get(String(id), {}).get("text", id))))
	return out


static func _next_of(next: Dictionary, hero_id: String, kind: String) -> int:
	return int(next.get("heroes", {}).get(hero_id, {}).get(kind, 0))


static func _add_next(next: Dictionary, hero_id: String, kind: String, amount: int, cap: int) -> void:
	if not next.heroes.has(hero_id):
		next.heroes[hero_id] = {}
	next.heroes[hero_id][kind] = mini(cap, _next_of(next, hero_id, kind) + amount)


## Usa: gasta o Tempo, marca o uso e aplica. Devolve o erro ("" deu certo).
static func use(campaign: Dictionary, user_id: String, skill_id: String, target_id: String = "") -> String:
	var q := quote(campaign, user_id, skill_id, target_id)
	if not q.available:
		return q.reason
	var row = skill(skill_id)
	var effects: Dictionary = row.get("Effects", {})
	var user = AHStationRules.hero(campaign, user_id)
	var who := targets(campaign, user_id, skill_id, target_id)
	var expedition: Dictionary = campaign.session.expedition
	var route: Dictionary = expedition.corridor
	var state := camp(campaign)
	state.time = int(state.get("time", 0)) + int(row.Cost)
	if not state.used.has(user_id):
		state.used[user_id] = []
	state.used[user_id].append(skill_id)
	var next := next_fight(campaign)
	for hero in who:
		if effects.has("heal_pct"):
			hero.hp = int(hero.hp) + _heal(hero, int(effects.heal_pct))
		if effects.has("instinct"):
			hero.instinct = clampi(int(hero.get("instinct", 0)) + int(effects.instinct), 0, 200)
		for kind in ["block", "dodge"]:
			if effects.has(kind):
				_add_next(next, hero.id, kind, int(effects[kind]), AHCombatEngine.TOKEN_CAP)
		if effects.has("speed"):
			_add_next(next, hero.id, "speed", int(effects.speed), int(effects.speed))
	if effects.has("self_block"):
		_add_next(next, user_id, "block", int(effects.self_block), AHCombatEngine.TOKEN_CAP)
	if effects.has("hope"):
		expedition.hope = clampi(int(expedition.get("hope", 0)) + int(effects.hope), 0, 100)
	if effects.has("food"):
		J.adjust(campaign, "food", int(effects.food))
	if effects.has("bandage"):
		J.adjust(campaign, "bandages", int(effects.bandage))
	if effects.has("ampoule"):
		var row_ampoule = GameData.combat.abilities.get(AHExplorationCare.AMPOULE)
		if typeof(user.get("expedition_uses")) != TYPE_DICTIONARY:
			user.expedition_uses = {}
		user.expedition_uses[AHExplorationCare.AMPOULE] = mini(int(row_ampoule.UsesMax), AHExplorationCare.ampoule_charges(campaign) + int(effects.ampoule))
	if bool(effects.get("mark_front", false)):
		next.mark_front = true
	if bool(effects.get("opening", false)):
		next.opening = true
	if bool(effects.get("watch", false)):
		state.watch = true
	if typeof(route.get("effects")) != TYPE_ARRAY:
		route.effects = []
	if effects.has("phase") and not route.effects.has(String(effects.phase)):
		route.effects.append(String(effects.phase))
	for id in effects.get("clear", []):
		route.effects.erase(String(id))
	return ""


## A noite ao levantar acampamento (#261): BadNight de chance, pelo sorteio da semente da fase, de a equipe ficar com
## BadNightEffect; quem vigiou evita. Devolve "bad", "watched" ou "good" (e guarda em camp_night, para o aviso).
static func night(campaign: Dictionary) -> String:
	var route = J.corridor(campaign)
	if route == null:
		return "good"
	var state := camp(campaign)
	var where: int = int(route.current_house) + 1 if int(route.current_house) >= 0 else 100 + int(route.index)
	var roll := J._rand(int(route.get("seed", 0)) ^ J._mul(where, 0x3c6ef372)).next()
	var result := "good"
	if roll < float(rule("BadNight", 0.3333)):
		result = "watched" if bool(state.get("watch", false)) else "bad"
	if result == "bad":
		if typeof(route.get("effects")) != TYPE_ARRAY:
			route.effects = []
		var effect := String(rule("BadNightEffect", "exposto"))
		if not route.effects.has(effect):
			route.effects.append(effect)
	route.camp_night = result
	route.erase("camp")
	return result


## O aviso da noite, para o fim do acampamento ("" na noite boa sem vigia).
static func night_notice(result: String) -> String:
	match result:
		"bad":
			return TranslationServer.translate("Noite mal dormida: a equipe começa a próxima luta Exposta.")
		"watched":
			return TranslationServer.translate("A noite foi agitada, mas quem vigiou segurou a equipe.")
	return ""
