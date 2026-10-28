## O nível dos heróis (#90, a P3 da proposta do laço): XP por luta e por jornada, e o Treino no Alojamento, que sobe um
## nível (até o 10) com o XP do nível e sementes e dá uma de duas melhorias da espécie. As tabelas ficam em data/:
## hero-levels.json (o XP e as sementes de cada nível), hero-upgrades.json (as melhorias, por classe) e hero-xp.json
## (quanto vale cada coisa). A luta não muda: o nível só soma por cima (a vida no máximo do herói, a velocidade, o +1 numa
## habilidade e o instinto a menos no começo da luta), com tudo zerado num herói de nível 1.
## O herói guarda level, xp (o acumulado desde o último treino) e upgrades (as melhorias escolhidas, por id).
class_name AHHeroLevels
extends RefCounted

const MAX_LEVEL := 10


static func level(hero: Dictionary) -> int:
	return clampi(int(hero.get("level", 1)), 1, MAX_LEVEL)


static func xp(hero: Dictionary) -> int:
	return int(hero.get("xp", 0))


## O XP e as sementes para chegar ao próximo nível ({} no máximo).
static func next_cost(hero: Dictionary) -> Dictionary:
	if level(hero) >= MAX_LEVEL:
		return {}
	var row = GameData.row("hero_levels", "level_%d" % (level(hero) + 1))
	return {} if row == null else {"xp": int(row.Xp), "seeds": int(row.Seeds)}


## Quanto vale uma coisa (hero-xp.json): a linha inteira.
static func rule(rule_name: String) -> Dictionary:
	var row = GameData.row("hero_xp", rule_name)
	return row if row != null else {}


## O recruta (o id termina num número, hero_cao_2) ganha mais XP que os fundadores.
static func is_recruit(hero: Dictionary) -> bool:
	return String(hero.get("id", "")).get_slice("_", 2).is_valid_int()


## Soma XP no herói (com o multiplicador do recruta); no nível máximo, não acumula. Devolve o que entrou.
static func gain(hero: Dictionary, amount: int) -> int:
	if amount <= 0 or level(hero) >= MAX_LEVEL:
		return 0
	if is_recruit(hero):
		amount = roundi(amount * float(rule("recruit").get("Multiplier", 1.0)))
	hero.xp = xp(hero) + amount
	return amount


## O XP de uma luta pelo que o herói fez nela (o tally da AHCombatSession: damage, healing, downs).
static func fight_xp(entry: Dictionary) -> int:
	var total := int(rule("fight").get("Xp", 0))
	total += int(entry.get("downs", 0)) * int(rule("down").get("Xp", 0))
	total += int(entry.get("protects", 0)) * int(rule("protect").get("Xp", 0))
	for kind in ["healing", "damage"]:
		var per := maxi(1, int(rule(kind).get("Per", 1)))
		total += floori(float(entry.get(kind, 0)) / per) * int(rule(kind).get("Xp", 0))
	return total


## As duas melhorias que o herói pode escolher no próximo treino: as da espécie; com uma delas no limite (MaxStacks), as
## de reserva (Fallback: mais vida, sangue frio) completam as duas, para todos chegarem ao nível 10 escolhendo.
static func options(hero: Dictionary) -> Array:
	var out: Array = []
	var rows: Array = GameData.table("hero_upgrades").values()
	for upgrade in rows:
		if upgrade.get("Classes", []).has(String(hero.get("class_id", ""))) and _open(hero, upgrade):
			out.append(upgrade)
	for upgrade in rows:
		if out.size() >= 2:
			break
		if upgrade.get("Fallback", false) and not out.has(upgrade) and _open(hero, upgrade):
			out.append(upgrade)
	# O recruta, a partir do nível do fundador (#215): aprender a habilidade dele, uma opção a mais.
	var learn := AHRecruitSkills.founder_option(hero)
	if not learn.is_empty():
		out.append(learn)
	return out


static func _open(hero: Dictionary, upgrade: Dictionary) -> bool:
	# A melhoria de uma habilidade só para quem a tem (o recruta tem as da raça, não as do fundador, #215).
	if String(upgrade.get("Stat", "")) == "Ability" and not AHRecruitSkills.known(hero).has(String(upgrade.get("AbilityId", ""))):
		return false
	return stacks(hero, upgrade.Name) < int(upgrade.get("MaxStacks", 99))


static func stacks(hero: Dictionary, upgrade_id: String) -> int:
	return hero.get("upgrades", []).count(upgrade_id)


## Por que o herói não pode treinar agora ("" pode).
static func train_block(campaign: Dictionary, hero: Dictionary) -> String:
	var cost := next_cost(hero)
	if cost.is_empty():
		return TranslationServer.translate("Nível máximo.")
	if xp(hero) < cost.xp:
		return TranslationServer.translate("Falta XP: %d de %d.") % [xp(hero), cost.xp]
	if AHStationRules.quantity(campaign, "seeds") < cost.seeds:
		return TranslationServer.translate("Sementes insuficientes para o treino.")
	if options(hero).is_empty():
		return TranslationServer.translate("Nenhuma melhoria disponível.")
	return ""


## Treina: gasta o XP do nível e as sementes, sobe um nível e aplica a melhoria escolhida. Devolve o erro ("" deu certo).
static func train(campaign: Dictionary, hero_id: String, upgrade_id: String) -> String:
	var hero = AHStationRules.hero(campaign, hero_id)
	if hero == null:
		return TranslationServer.translate("Herói não encontrado.")
	if not hero.get("alive", true):
		return TranslationServer.translate("Só quem está vivo treina.")
	var block := train_block(campaign, hero)
	if block != "":
		return block
	var upgrade = null
	for option in options(hero):
		if option.Name == upgrade_id:
			upgrade = option
	if upgrade == null:
		return TranslationServer.translate("Essa melhoria não é desta espécie.")
	var fragments := int(upgrade.get("Fragments", 0))
	if AHStationRules.quantity(campaign, "fragments") < fragments:
		return TranslationServer.translate("Fragmentos insuficientes: aprender custa %d.") % fragments
	var cost := next_cost(hero)
	AHStationRules.adjust(campaign, "seeds", -int(cost.seeds))
	if fragments > 0:
		AHStationRules.adjust(campaign, "fragments", -fragments)
	hero.xp = xp(hero) - int(cost.xp)
	hero.level = level(hero) + 1
	# Aprender (#215): a habilidade entra no que o recruta sabe; não é uma melhoria que se acumula.
	if String(upgrade.Stat) == "Learn":
		if typeof(hero.get("learned")) != TYPE_ARRAY:
			hero.learned = []
		hero.learned.append(String(upgrade.AbilityId))
		if level(hero) >= MAX_LEVEL:
			hero.xp = 0
		return ""
	if not hero.has("upgrades"):
		hero.upgrades = []
	hero.upgrades.append(upgrade_id)
	# A vida máxima fica no herói (a luta, o Dormitório e a comida já leem dela).
	if String(upgrade.Stat) == "MaxHp":
		hero.max_hp = int(hero.max_hp) + int(upgrade.Value)
		hero.hp = int(hero.hp) + int(upgrade.Value)
	if level(hero) >= MAX_LEVEL:
		hero.xp = 0
	return ""


## O que as melhorias somam na luta: {speed, calm, abilities {ability_id: +n}} (a vida já está no herói).
static func combat_bonus(hero: Dictionary) -> Dictionary:
	var out := {"speed": 0, "calm": 0, "abilities": {}}
	for upgrade_id in hero.get("upgrades", []):
		var upgrade = GameData.row("hero_upgrades", upgrade_id)
		if upgrade == null:
			continue
		match String(upgrade.Stat):
			"Speed":
				out.speed += int(upgrade.Value)
			"Calm":
				out.calm += int(upgrade.Value)
			"Ability":
				# O recruta de antes (#215): a melhoria paga para a habilidade do fundador vale na dele que a substitui.
				var target := AHRecruitSkills.bonus_target(hero, String(upgrade.AbilityId))
				if target != "":
					out.abilities[target] = int(out.abilities.get(target, 0)) + int(upgrade.Value)
	return out


## O save antigo (#90): cada herói vivo começa no nível 1, sem melhorias, com o XP das fases já concluídas (o de uma
## fase jogada, para treinar e escolher as melhorias ele mesmo, em vez de ganhar níveis prontos). O save não diz quando
## cada um chegou: o recruta recebe o mesmo.
static func migrate(campaign: Dictionary) -> void:
	var per_phase := int(rule("migration").get("Xp", 0))
	var phases: int = campaign.get("completed_phases", []).size()
	for hero in campaign.get("roster", []):
		if not hero.has("level"):
			hero.level = 1
			hero.upgrades = []
			hero.xp = per_phase * phases if hero.get("alive", true) else 0
