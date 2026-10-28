## Os recrutas (#189 e #215, decisões do Lucas de 28/10): o fundador fica com o kit da história; o recruta tem
## habilidades próprias, mais fracas (rec_*, em data/abilities.json). Chega com o Kit da raça (3: o golpe, o Remendo e o
## toque da raça), ganha a Level2 ao subir para o nível 2 e aprende a Founder no Treino a partir do nível FounderLevel
## (a do fundador da espécie; o Guaxinim e o Tatu, sem fundador, a de ofício do kit da classe), pagando
## FounderFragments além do custo do nível. Com mais de MaxCarried, leva MaxCarried para a luta: troca na Estação.
## O save do herói: "loadout" (as que leva, [] = as primeiras na ordem) e "learned" (as aprendidas no Treino).
class_name AHRecruitSkills
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")
## O id da opção de aprender no Treino (AHHeroLevels.options).
const LEARN := "learn_founder"


static func rule(name: String, fallback = null):
	var row = GameData.row("recruit_skills", "rules")
	return row.get(name, fallback) if row != null else fallback


## O recruta tem as habilidades da raça; o fundador, as da classe.
static func flexible(hero: Dictionary) -> bool:
	return S.is_recruit(String(hero.get("id", "")))


## Uma cópia (quem chama pode mudar a lista sem mexer na tabela das classes).
static func class_abilities(class_id: String) -> Array:
	var row = GameData.row("classes", class_id)
	return Array(row.get("AbilityIds", [])).duplicate() if row != null else []


static func race(class_id: String) -> Dictionary:
	var row = GameData.row("recruit_skills", class_id)
	return row if row != null else {}


## As que o herói sabe: o fundador, as da classe; o recruta, o kit da raça, a do nível 2 e a aprendida no Treino.
static func known(hero: Dictionary) -> Array:
	var class_id := String(hero.get("class_id", ""))
	if not flexible(hero):
		return class_abilities(class_id)
	var row := race(class_id)
	var out: Array = Array(row.get("Kit", [])).duplicate()
	if AHHeroLevels.level(hero) >= 2 and String(row.get("Level2", "")) != "":
		out.append(String(row.Level2))
	for ability_id in hero.get("learned", []):
		if not out.has(ability_id):
			out.append(String(ability_id))
	return out


## As que o herói leva para a luta: todas as que sabe, até MaxCarried; com mais, a escolha da Sala (ou as primeiras).
static func abilities(hero: Dictionary) -> Array:
	var all := known(hero)
	var limit := int(rule("MaxCarried", 4))
	if not flexible(hero) or all.size() <= limit:
		return all
	var chosen: Array = hero.get("loadout", [])
	if chosen.size() == limit and chosen.all(func(id): return all.has(id)):
		return all.filter(func(id): return chosen.has(id))
	return all.slice(0, limit)


static func loadout(hero: Dictionary) -> Array:
	return abilities(hero)


## A habilidade do fundador que o recruta aprende no Treino ("" sem ela na tabela).
static func founder_ability(class_id: String) -> String:
	return String(race(class_id).get("Founder", ""))


## Quem ensina, pelo nome do fundador da espécie (initial-heroes); "" para a de ofício (o Guaxinim e o Tatu).
static func teacher_name(class_id: String) -> String:
	var teacher := String(race(class_id).get("Teacher", ""))
	if teacher == "":
		return ""
	var founder = GameData.row("initial_heroes", teacher)
	return String(founder.DisplayName) if founder != null else ""


## A opção de aprender, no Treino que leva ao nível FounderLevel ou depois, até aprender: um item como os de
## hero-upgrades.json, com Stat "Learn" e o custo extra em fragmentos ({} sem a opção).
static func founder_option(hero: Dictionary) -> Dictionary:
	if not flexible(hero) or AHHeroLevels.next_cost(hero).is_empty():
		return {}
	var class_id := String(hero.get("class_id", ""))
	var ability_id := founder_ability(class_id)
	var data = GameData.row("abilities", ability_id)
	if data == null or hero.get("learned", []).has(ability_id) or AHHeroLevels.level(hero) + 1 < int(rule("FounderLevel", 4)):
		return {}
	var teacher := teacher_name(class_id)
	var name := TranslationServer.translate(String(data.DisplayName))
	return {"Name": LEARN, "Stat": "Learn", "AbilityId": ability_id, "Fragments": int(rule("FounderFragments", 3)),
		"DisplayName": TranslationServer.translate("Aprender com %s: %s") % [teacher, name] if teacher != ""
			else TranslationServer.translate("Aprender o ofício: %s") % name,
		# Curta, como as das melhorias (o cartão do Treino); o detalhe da habilidade fica na Sala.
		"Description": TranslationServer.translate("%s ensina a habilidade dele.") % teacher if teacher != ""
			else TranslationServer.translate("A oficina da Estação ensina o ofício.")}


## Trocar as que leva (na Estação, sem custo). Devolve o erro, ou "".
static func choose(campaign: Dictionary, hero_id: String, chosen: Array) -> String:
	var hero = S.hero(campaign, hero_id)
	if hero == null:
		return TranslationServer.translate("Esse herói não está na Estação.")
	if not flexible(hero):
		return TranslationServer.translate("Os fundadores lutam com as habilidades de sempre.")
	if campaign.get("session", {}).get("expedition") != null:
		return TranslationServer.translate("As habilidades se trocam na Estação, fora da expedição.")
	var error := invalid(hero, chosen)
	if error == "":
		hero.loadout = chosen.duplicate()
	return error


## Por que essa escolha não vale ("" se vale), sem trocar nada (a Sala mostra só as trocas que valem).
static func invalid(hero: Dictionary, chosen: Array) -> String:
	var limit := int(rule("MaxCarried", 4))
	var all := known(hero)
	var unique: Array = []
	for ability_id in chosen:
		if not unique.has(ability_id):
			unique.append(ability_id)
	if chosen.size() != limit or unique.size() != limit:
		return TranslationServer.translate("Escolha %d habilidades diferentes.") % limit
	for ability_id in chosen:
		if not all.has(ability_id):
			return TranslationServer.translate("%s ainda não sabe essa habilidade.") % hero.display_name
	return ""


## O save: os campos que faltam vazios; a escolha que não vale mais (um save editado, o fundador) volta ao padrão.
static func migrate(campaign: Dictionary) -> void:
	for entry in campaign.get("roster", []):
		if typeof(entry.get("loadout")) != TYPE_ARRAY:
			entry.loadout = []
		if typeof(entry.get("learned")) != TYPE_ARRAY:
			entry.learned = []
		if not entry.loadout.is_empty() and (not flexible(entry) or invalid(entry, entry.loadout) != ""):
			entry.loadout = []
