## As peculiaridades (#264, aprovado pelo Orquestrador em nome do Lucas em 02/11): tendências que pesam no jogo, curtas
## e legíveis na ficha (a personalidade é texto, #189). O catálogo em data/perks.json.
## - Até MAX_SIDE positivas e MAX_SIDE negativas por herói; sem repetir e sem incompatíveis.
## - As de cura (NeedsHeal) só para quem tem cura entre as habilidades do papel.
## - A fixada (fixed_perks) não se perde: a positiva fixa dos fundadores (data/initial-heroes.json, FixedPerk) nas
##   campanhas novas, marcada para o Lucas revisar; fixar no Bar e ganhar ou perder na volta vêm nos PRs 2 e 3.
## Save: no herói, perks (como antes) e fixed_perks (as fixadas, sempre dentro de perks).
class_name AHPerks
extends RefCounted

const MAX_SIDE := 3


static func row(perk_id: String):
	return GameData.row("perks", perk_id)


static func positive(perk_id: String) -> bool:
	var data = row(perk_id)
	return data != null and bool(data.get("bPositive", true))


static func of(hero: Dictionary) -> Array:
	var perks = hero.get("perks", [])
	return Array(perks).filter(func(id): return typeof(id) == TYPE_STRING) if typeof(perks) == TYPE_ARRAY else []


static func fixed(hero: Dictionary) -> Array:
	var kept = hero.get("fixed_perks", [])
	return Array(kept).filter(func(id): return typeof(id) == TYPE_STRING) if typeof(kept) == TYPE_ARRAY else []


static func is_fixed(hero: Dictionary, perk_id: String) -> bool:
	return fixed(hero).has(perk_id)


## O papel tem cura entre as habilidades (as 7 do catálogo, #259)?
static func class_heals(class_id: String) -> bool:
	for ability_id in AHHeroSkills.catalog(class_id):
		var ability = GameData.combat.abilities.get(ability_id)
		if ability != null and int(ability.HealRange.Max) > 0:
			return true
	return false


## A peculiaridade cabe nesse conjunto? (sem repetir, sem incompatível, o limite do lado, a cura para quem cura)
static func fits(perks: Array, perk_id: String, class_id: String = "") -> bool:
	var data = row(perk_id)
	if data == null or perks.has(perk_id):
		return false
	if bool(data.get("NeedsHeal", false)) and class_id != "" and not class_heals(class_id):
		return false
	for other in perks:
		var other_row = row(String(other))
		if Array(data.get("Incompatible", [])).has(other) or (other_row != null and Array(other_row.get("Incompatible", [])).has(perk_id)):
			return false
	var side := positive(perk_id)
	return perks.filter(func(id): return positive(String(id)) == side).size() < MAX_SIDE


## Dá a peculiaridade ao herói, se couber (true se deu). fix: já fixada.
static func add(hero: Dictionary, perk_id: String, fix: bool = false) -> bool:
	var perks := of(hero)
	if not fits(perks, perk_id, String(hero.get("class_id", ""))):
		return false
	perks.append(perk_id)
	hero.perks = perks
	if fix:
		var kept := fixed(hero)
		kept.append(perk_id)
		hero.fixed_perks = kept
	return true


## Tira a peculiaridade (a fixada não sai; true se tirou).
static func remove(hero: Dictionary, perk_id: String) -> bool:
	if is_fixed(hero, perk_id) or not of(hero).has(perk_id):
		return false
	hero.perks = of(hero).filter(func(id): return id != perk_id)
	return true


## A soma de um campo numérico das peculiaridades (DisplacementResist, HealBonus, CampInstinct, SearchScrap), uma vez
## cada.
static func total(perks: Array, field: String) -> float:
	var out := 0.0
	var seen := {}
	for perk_id in perks:
		if seen.has(perk_id):
			continue
		seen[perk_id] = true
		var data = row(String(perk_id))
		if data != null:
			out += float(data.get(field, 0))
	return out


static func flag(perks: Array, field: String) -> bool:
	return perks.any(func(id): return row(String(id)) != null and bool(row(String(id)).get(field, false)))


## A positiva fixa do fundador (data/initial-heroes.json), "" se não tem.
static func founder_fixed(class_id: String) -> String:
	for founder in GameData.table("initial_heroes").values():
		if String(founder.get("ClassId", "")) == class_id:
			return String(founder.get("FixedPerk", ""))
	return ""


## Saves de antes e editados: perks fica só com ids de texto; fixed_perks, só com as que estão em perks. Ninguém ganha
## nem perde peculiaridade ao carregar (a positiva fixa dos fundadores vale só nas campanhas novas).
static func migrate(campaign: Dictionary) -> void:
	for hero in campaign.get("roster", []):
		if typeof(hero) != TYPE_DICTIONARY:
			continue
		var perks := of(hero)
		hero.perks = perks
		hero.fixed_perks = fixed(hero).filter(func(id): return perks.has(id))
