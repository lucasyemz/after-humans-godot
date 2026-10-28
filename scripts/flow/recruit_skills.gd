## Os recrutas flexíveis (#189, decisões do Lucas): o fundador fica com o kit da história; o recruta tem 2 habilidades
## fixas da classe (o corpo: data/recruit-skills.json, Fixed) e 2 escolhidas, das outras da classe ou das que aprendeu
## com um fundador de outra classe (o mentor, depois de MentorExpeditions expedições na mesma equipe, ou a Pesquisa,
## "Ensinar a comunidade"). Leva no máximo MaxForeign de fora; troca livre na Estação. As 4 ficam na ordem da classe,
## cada escolha no lugar de uma das que não são fixas; sem escolha, o kit da classe (o recruta de antes não muda).
## O save do herói: "loadout" (as 2 escolhidas, [] = as da classe), "learned" (as de fora que sabe) e "mentor" ({id do
## fundador: expedições juntos}).
class_name AHRecruitSkills
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")
## O ramo da Pesquisa que ensina (research.json, Branch) e o SkillId de cada nó: teach_<classe>.
const TEACH_BRANCH := "teach"


static func rule(name: String, fallback = null):
	var row = GameData.row("recruit_skills", "rules")
	return row.get(name, fallback) if row != null else fallback


## O recruta é flexível; o fundador, não.
static func flexible(hero: Dictionary) -> bool:
	return S.is_recruit(String(hero.get("id", "")))


## Uma cópia (quem chama pode mudar a lista sem mexer na tabela das classes).
static func class_abilities(class_id: String) -> Array:
	var row = GameData.row("classes", class_id)
	return Array(row.get("AbilityIds", [])).duplicate() if row != null else []


static func fixed(class_id: String) -> Array:
	var row = GameData.row("recruit_skills", class_id)
	return Array(row.get("Fixed", [])).duplicate() if row != null else []


## As habilidades que o herói leva para a luta, na ordem da classe (o fundador e o recruta sem escolha: as da classe).
static func abilities(hero: Dictionary) -> Array:
	var out := class_abilities(String(hero.get("class_id", "")))
	if not flexible(hero):
		return out
	var chosen: Array = hero.get("loadout", [])
	if chosen.size() != 2:
		return out
	var slots := _free_slots(String(hero.class_id))
	for index in mini(slots.size(), chosen.size()):
		out[slots[index]] = String(chosen[index])
	return out


## As 2 escolhidas agora (as da classe, sem escolha).
static func loadout(hero: Dictionary) -> Array:
	var chosen: Array = hero.get("loadout", [])
	if chosen.size() == 2:
		return chosen.duplicate()
	var ids := class_abilities(String(hero.get("class_id", "")))
	return _free_slots(String(hero.get("class_id", ""))).map(func(i): return ids[i])


## Os lugares da ordem da classe que não são fixos (onde entram as escolhas).
static func _free_slots(class_id: String) -> Array:
	var ids := class_abilities(class_id)
	var locked := fixed(class_id)
	var out: Array = []
	for index in ids.size():
		if not locked.has(ids[index]):
			out.append(index)
	return out


## As habilidades de fora que o herói sabe: as que aprendeu com um mentor e as das classes que a Pesquisa ensina.
static func known_foreign(campaign: Dictionary, hero: Dictionary) -> Array:
	var own := class_abilities(String(hero.get("class_id", "")))
	var out: Array = []
	for ability_id in hero.get("learned", []):
		if not own.has(ability_id) and not out.has(ability_id):
			out.append(String(ability_id))
	for row in GameData.table("recruit_skills").values():
		if campaign.get("researched_skills", []).has("%s_%s" % [TEACH_BRANCH, row.Name]):
			for ability_id in row.get("Teaches", []):
				if not own.has(ability_id) and not out.has(ability_id):
					out.append(String(ability_id))
	return out


## O que pode entrar nas 2 escolhas: as da classe que não são fixas e as de fora que ele sabe.
static func options(campaign: Dictionary, hero: Dictionary) -> Array:
	var ids := class_abilities(String(hero.get("class_id", "")))
	var out: Array = _free_slots(String(hero.get("class_id", ""))).map(func(i): return ids[i])
	out.append_array(known_foreign(campaign, hero))
	return out


## Trocar as 2 escolhidas (na Estação, sem custo). Devolve o erro, ou "".
static func choose(campaign: Dictionary, hero_id: String, chosen: Array) -> String:
	var hero = S.hero(campaign, hero_id)
	if hero == null:
		return TranslationServer.translate("Esse herói não está na Estação.")
	if not flexible(hero):
		return TranslationServer.translate("Os fundadores lutam com as habilidades de sempre.")
	if campaign.get("session", {}).get("expedition") != null:
		return TranslationServer.translate("As habilidades se trocam na Estação, fora da expedição.")
	var error := invalid(campaign, hero, chosen)
	if error == "":
		hero.loadout = chosen.duplicate()
	return error


## Por que essas 2 escolhas não valem para o herói ("" se valem), sem trocar nada (a Sala mostra só as que valem).
static func invalid(campaign: Dictionary, hero: Dictionary, chosen: Array) -> String:
	if chosen.size() != 2 or chosen[0] == chosen[1]:
		return TranslationServer.translate("Escolha duas habilidades diferentes.")
	var allowed := options(campaign, hero)
	var own := class_abilities(String(hero.class_id))
	var foreign := 0
	for ability_id in chosen:
		if not allowed.has(ability_id):
			return TranslationServer.translate("%s ainda não sabe essa habilidade.") % hero.display_name
		if not own.has(ability_id):
			foreign += 1
	var limit := int(rule("MaxForeign", 1))
	if foreign > limit:
		return TranslationServer.translate("No máximo %d habilidade de fora da classe.") % limit if limit == 1 \
			else TranslationServer.translate("No máximo %d habilidades de fora da classe.") % limit
	return ""


## A volta (S.finish_return): cada recruta conta mais uma expedição com cada fundador de outra classe na mesma equipe;
## ao chegar em MentorExpeditions, aprende a próxima que o fundador ensina (Teaches) e a conta recomeça. Devolve o que
## aprenderam: [{hero_id, mentor_id, ability_id}].
static func mentor_return(campaign: Dictionary, team: Array) -> Array:
	var learned: Array = []
	var needed := int(rule("MentorExpeditions", 2))
	for recruit_id in team:
		var recruit = S.hero(campaign, recruit_id)
		# Quem caiu na expedição também conta (o mentor e o recruta): a volta vale em qualquer resultado.
		if recruit == null or not flexible(recruit):
			continue
		for mentor_id in team:
			var mentor = S.hero(campaign, mentor_id)
			if mentor == null or flexible(mentor) or String(mentor.class_id) == String(recruit.class_id):
				continue
			var next := _next_lesson(campaign, recruit, String(mentor.class_id))
			if next == "":
				continue
			var progress: Dictionary = recruit.get("mentor", {})
			progress[mentor_id] = int(progress.get(mentor_id, 0)) + 1
			recruit.mentor = progress
			if int(progress[mentor_id]) >= needed:
				progress[mentor_id] = 0
				var known: Array = recruit.get("learned", [])
				known.append(next)
				recruit.learned = known
				learned.append({"hero_id": recruit_id, "mentor_id": mentor_id, "ability_id": next})
	return learned


## A próxima que o fundador da classe ensina e o recruta ainda não sabe ("" se já sabe todas).
static func _next_lesson(campaign: Dictionary, recruit: Dictionary, mentor_class: String) -> String:
	var row = GameData.row("recruit_skills", mentor_class)
	if row == null:
		return ""
	var known := known_foreign(campaign, recruit)
	for ability_id in row.get("Teaches", []):
		if not known.has(ability_id) and not class_abilities(String(recruit.class_id)).has(ability_id):
			return String(ability_id)
	return ""


## Quanto falta com cada mentor ([{mentor_id, done, needed, ability_id}]), para a Sala dos Personagens.
static func lessons(campaign: Dictionary, recruit: Dictionary) -> Array:
	var out: Array = []
	if not flexible(recruit):
		return out
	for mentor in S.living(campaign):
		if flexible(mentor) or String(mentor.class_id) == String(recruit.class_id):
			continue
		var next := _next_lesson(campaign, recruit, String(mentor.class_id))
		if next != "":
			out.append({"mentor_id": mentor.id, "done": int(recruit.get("mentor", {}).get(mentor.id, 0)),
				"needed": int(rule("MentorExpeditions", 2)), "ability_id": next})
	return out


## O save de antes do #189: o recruta vira flexível com o kit de hoje (as da classe, nada de fora); ninguém perde nada.
static func migrate(campaign: Dictionary) -> void:
	for entry in campaign.get("roster", []):
		if typeof(entry.get("loadout")) != TYPE_ARRAY:
			entry.loadout = []
		if typeof(entry.get("learned")) != TYPE_ARRAY:
			entry.learned = []
		if typeof(entry.get("mentor")) != TYPE_DICTIONARY:
			entry.mentor = {}
		# A escolha que não vale mais (um MaxForeign menor, uma fixa nova, um save editado, o fundador com escolha)
		# volta para o kit da classe ao abrir o save.
		if not entry.loadout.is_empty() and (not flexible(entry) or invalid(campaign, entry, entry.loadout) != ""):
			entry.loadout = []
