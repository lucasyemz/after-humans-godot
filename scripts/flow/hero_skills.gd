## As sete habilidades de combate (#259, aprovada pelo Lucas em 01/11): a mesma regra para fundadores e recrutados.
## Cada classe tem 7 no catálogo (data/classes.json): as 4 de base (AbilityIds, as de sempre) e 3 desbloqueios
## (UnlockIds). O Treino ensina um desbloqueio ao subir para cada nível de data/hero-skills.json (Levels), pelo custo do
## nível mais os fragmentos da vez; o jogador escolhe a ordem. Vão MaxEquipped para a luta, trocadas na Sala, fora da
## expedição, e nenhuma escolha deixa uma posição (1 a 4) sem um ataque que parta dela: a partida exige ataque da posição
## (#95), e assim o herói parte de qualquer lugar da formação (a QA da #259).
## O save do herói: "unlocked" (os desbloqueios aprendidos) e "loadout" (as que leva; [] = as 4 de base, como sempre).
class_name AHHeroSkills
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")
## O prefixo das opções de aprender no Treino (AHHeroLevels.options): "learn:<id da habilidade>".
const LEARN := "learn:"
const RANKS := [1, 2, 3, 4]


static func rule(name: String, fallback = null):
	var row = GameData.row("hero_skills", "unlocks")
	return row.get(name, fallback) if row != null else fallback


static func max_equipped() -> int:
	return int(rule("MaxEquipped", 4))


## As 4 de base da classe (uma cópia).
static func base(class_id: String) -> Array:
	var row = GameData.row("classes", class_id)
	return Array(row.get("AbilityIds", [])).duplicate() if row != null else []


## Os 3 desbloqueios da classe (uma cópia).
static func unlocks(class_id: String) -> Array:
	var row = GameData.row("classes", class_id)
	return Array(row.get("UnlockIds", [])).duplicate() if row != null else []


## As 7 da classe, na ordem: as de base e os desbloqueios.
static func catalog(class_id: String) -> Array:
	return base(class_id) + unlocks(class_id)


## As que o herói sabe: as de base e os desbloqueios aprendidos, na ordem do catálogo.
static func known(hero: Dictionary) -> Array:
	var class_id := String(hero.get("class_id", ""))
	var learned: Array = hero.get("unlocked", []) if typeof(hero.get("unlocked")) == TYPE_ARRAY else []
	return catalog(class_id).filter(func(id): return base(class_id).has(id) or learned.has(id))


## As que ele leva para a luta: a escolha da Sala, se vale; senão, as 4 de base (o fundador de sempre, a paridade).
static func equipped(hero: Dictionary) -> Array:
	var class_id := String(hero.get("class_id", ""))
	var chosen = hero.get("loadout", [])
	if typeof(chosen) == TYPE_ARRAY and not chosen.is_empty() and invalid(hero, chosen) == "":
		return catalog(class_id).filter(func(id): return chosen.has(id))
	return base(class_id)


## As posições (1 a 4) de onde nenhum ataque dessas habilidades parte (o mesmo critério da partida, #95).
static func uncovered(ability_ids: Array) -> Array:
	return RANKS.filter(func(rank): return not ability_ids.any(func(id): return attacks_from(String(id), rank)))


## A habilidade ataca (tem dano) partindo da posição.
static func attacks_from(ability_id: String, rank: int) -> bool:
	var row = GameData.row("abilities", ability_id)
	if row == null:
		return false
	var damage = row.get("DamageRange")
	return damage is Dictionary and int(damage.get("Max", 0)) > 0 and Array(row.get("OriginRanks", [])).map(func(r): return int(r)).has(rank)


## Por que essa escolha não vale ("" se vale), sem trocar nada.
static func invalid(hero: Dictionary, chosen: Array) -> String:
	var limit := max_equipped()
	var unique: Array = []
	for ability_id in chosen:
		if typeof(ability_id) != TYPE_STRING:
			return TranslationServer.translate("Escolha %d habilidades diferentes.") % limit
		if not unique.has(ability_id):
			unique.append(ability_id)
	if chosen.size() != limit or unique.size() != limit:
		return TranslationServer.translate("Escolha %d habilidades diferentes.") % limit
	var all := known(hero)
	for ability_id in chosen:
		if not all.has(ability_id):
			return TranslationServer.translate("%s ainda não sabe essa habilidade.") % String(hero.get("display_name", ""))
	var missing := uncovered(chosen)
	if not missing.is_empty():
		return TranslationServer.translate("Sem ataque da posição %d.") % int(missing[0])
	return ""


## Trocar as que leva (na Estação, fora da expedição, sem custo). Devolve o erro, ou "".
static func choose(campaign: Dictionary, hero_id: String, chosen: Array) -> String:
	var hero = S.hero(campaign, hero_id)
	if hero == null:
		return TranslationServer.translate("Esse herói não está na Estação.")
	if campaign.get("session", {}).get("expedition") != null:
		return TranslationServer.translate("As habilidades se trocam na Estação, fora da expedição.")
	var error := invalid(hero, chosen)
	if error == "":
		# As 4 de base de novo: o loadout volta a vazio (o padrão, como o save de antes).
		var sorted := catalog(String(hero.class_id)).filter(func(id): return chosen.has(id))
		hero.loadout = [] if sorted == base(String(hero.class_id)) else sorted
	return error


## Uma formação em que cada um tem ataque da sua posição (#95), com as habilidades que leva: a mesma, se já vale; senão,
## a primeira ordem que vale (quem entra no lugar de quem caiu, um save de antes); [] se nenhuma vale.
static func valid_order(campaign: Dictionary, team: Array) -> Array:
	var heroes: Array = []
	for hero_id in team:
		var entry = S.hero(campaign, hero_id)
		if entry == null:
			return []
		heroes.append(entry)
	for order in _orders(range(team.size())):
		var ok := true
		for rank in order.size():
			var entry: Dictionary = heroes[order[rank]]
			if S.attacks_from_rank(String(entry.class_id), rank + 1, equipped(entry)).is_empty():
				ok = false
				break
		if ok:
			return order.map(func(i): return team[i])
	return []


## As ordens possíveis, a de hoje primeiro.
static func _orders(items: Array) -> Array:
	if items.size() <= 1:
		return [items.duplicate()]
	var out: Array = []
	for i in items.size():
		var rest := items.duplicate()
		var first = rest.pop_at(i)
		for tail in _orders(rest):
			out.append([first] + tail)
	return out


# ---------------------------------------------------------------- o Treino

## Quantos desbloqueios o herói pode ter aprendido até um nível.
static func slots_at(level: int) -> int:
	return Array(rule("Levels", [])).filter(func(at): return level >= int(at)).size()


## Os fragmentos do próximo desbloqueio (o 1º, o 2º ou o 3º).
static func next_fragments(hero: Dictionary) -> int:
	var costs: Array = rule("Fragments", [])
	var index: int = Array(hero.get("unlocked", [])).size()
	return int(costs[index]) if index < costs.size() else 0


## As opções de aprender do próximo treino: uma por desbloqueio ainda bloqueado, enquanto o nível que ele alcança deixa
## (um item como os de hero-upgrades.json, com Stat "Learn"). [] sem vaga.
static func learn_options(hero: Dictionary) -> Array:
	var learned: Array = hero.get("unlocked", [])
	# No nível máximo, as vagas que sobraram continuam no Treino (só os fragmentos): nenhuma se perde.
	var at := AHHeroLevels.level(hero) + (0 if at_max(hero) else 1)
	if slots_at(at) <= learned.size():
		return []
	var out: Array = []
	for ability_id in unlocks(String(hero.get("class_id", ""))):
		if learned.has(ability_id):
			continue
		var data = GameData.row("abilities", ability_id)
		if data == null:
			continue
		out.append({"Name": LEARN + ability_id, "Stat": "Learn", "AbilityId": ability_id, "Fragments": next_fragments(hero),
			"DisplayName": TranslationServer.translate("Aprender: %s") % TranslationServer.translate(String(data.DisplayName)),
			"Description": TranslationServer.translate(String(data.get("Description", "")))})
	return out


## No nível máximo: o Treino só ensina (sem XP nem sementes).
static func at_max(hero: Dictionary) -> bool:
	return AHHeroLevels.level(hero) >= AHHeroLevels.MAX_LEVEL


## "1 fragmento" ou "N fragmentos".
static func fragments_text(count: int) -> String:
	return TranslationServer.translate("+1 fragmento") if count == 1 else TranslationServer.translate("+%d fragmentos") % count


## O que fica bloqueado e o requisito ("Nível 5 · Treino · +2 fragmentos"), para a ficha e a Sala; no nível máximo, só
## "Treino · +3 fragmentos" (nunca um nível que não existe).
static func requirement(hero: Dictionary) -> String:
	var learned: int = Array(hero.get("unlocked", [])).size()
	var levels: Array = rule("Levels", [])
	if learned >= levels.size():
		return ""
	if at_max(hero):
		return TranslationServer.translate("Treino · %s") % fragments_text(next_fragments(hero))
	var at := maxi(int(levels[learned]), AHHeroLevels.level(hero) + 1)
	return TranslationServer.translate("Nível %d · Treino · %s") % [at, fragments_text(next_fragments(hero))]


## O aviso depois de aprender: o nível (sem ele, no nível máximo), a habilidade e onde escolher as que leva.
static func learned_notice(hero: Dictionary, ability_id: String, leveled: bool = true) -> String:
	var data = GameData.row("abilities", ability_id)
	var name: String = TranslationServer.translate(String(data.DisplayName)) if data != null else ability_id
	if not leveled:
		return TranslationServer.translate("%s aprendeu %s. Na Sala, escolha as %d que leva.") % [String(hero.get("display_name", "")), name, max_equipped()]
	return TranslationServer.translate("%s subiu para o nível %d e aprendeu %s. Na Sala, escolha as %d que leva.") % [
		String(hero.get("display_name", "")), AHHeroLevels.level(hero), name, max_equipped()]


# ---------------------------------------------------------------- o save

## Os campos que faltam vazios; o que não vale mais (um save editado) volta ao padrão: os desbloqueios só os da classe,
## sem repetir e no máximo os da vaga do nível; a escolha que quebra a regra volta para as 4 de base.
static func migrate(campaign: Dictionary) -> void:
	for entry in campaign.get("roster", []):
		var class_id := String(entry.get("class_id", ""))
		var learned = entry.get("unlocked")
		var clean: Array = []
		if typeof(learned) == TYPE_ARRAY:
			for ability_id in learned:
				if typeof(ability_id) == TYPE_STRING and unlocks(class_id).has(ability_id) and not clean.has(ability_id):
					clean.append(ability_id)
		entry.unlocked = clean.slice(0, slots_at(AHHeroLevels.level(entry)))
		if typeof(entry.get("loadout")) != TYPE_ARRAY:
			entry.loadout = []
		if not entry.loadout.is_empty() and invalid(entry, entry.loadout) != "":
			entry.loadout = []
	# A formação salva com alguém numa posição de onde as 4 dele não atacam troca de ordem.
	var formation = campaign.get("preferred_formation")
	if typeof(formation) == TYPE_ARRAY and not formation.is_empty():
		var order := valid_order(campaign, formation)
		if not order.is_empty():
			campaign.preferred_formation = order
