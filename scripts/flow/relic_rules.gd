## As relíquias (#263): os dois slots de cada herói, o que cada slot aceita, o total dos bônus e de onde cada uma pode
## sair (os sorteios e a Forja).
##
## O herói guarda hero.relics = ["", ""] (o id de cada slot, "" vazio). O estoque é campaign.inventory.relics (uma lista
## de ids, com cópias). Equipar tira uma cópia do estoque e devolve a que saiu: nada se perde nem se duplica.
##
## Os campos de data/relics.json que valem aqui:
## - Rarity: "common", "uncommon", "rare", "personal" ou "keepsake". Os sorteios só escolhem as comuns e as incomuns.
## - Only: "" (todos), "role:<class_id>" (um papel) ou "hero:<hero_id>" (um fundador).
## - Sources: de onde ela sai ("forge", "cargo", "dig", "guardian", "solo", "merchant", "story").
## - Phase: opcional; com ela, a relíquia só cai num sorteio daquela fase (a carga da expedição).
## - Os efeitos: MaxHpBonus, SpeedBonus (o total das relíquias tem teto de SPEED_CAP), EventInstinctReduction e
##   VirtueBonus (pontos da chance de Superação, como o Virtue dos perks: 0.05 é +5 pp).
class_name AHRelics
extends RefCounted

const SLOTS := 2
## No máximo +2 de Velocidade vindo das relíquias (o desenho aprovado na #263). O que tira velocidade não tem piso.
const SPEED_CAP := 2
const RARITIES := ["common", "uncommon", "rare", "personal", "keepsake"]
## As raridades que um sorteio pode escolher (a carga, a escavação, a missão solo). A rara é troféu de guardião, a
## pessoal vem da missão do fundador e a lembrança, da história: nenhuma cai por sorte.
const DRAWABLE := ["common", "uncommon"]
## A Forja só fabrica as comuns que têm "forge" entre as origens.
const FORGE_RARITY := "common"


# ---------------------------------------------------------------- os slots

## Os dois slots do herói, sempre com SLOTS posições ("" vazio). Um herói de antes da migração lê o relic_id antigo.
static func slots(hero) -> Array:
	var out: Array = []
	if typeof(hero) != TYPE_DICTIONARY:
		out.resize(SLOTS)
		out.fill("")
		return out
	var raw = hero.get("relics")
	if typeof(raw) == TYPE_ARRAY:
		for value in raw:
			out.append(String(value) if value != null else "")
	elif String(hero.get("relic_id", "")) != "":
		out.append(String(hero.relic_id))
	while out.size() < SLOTS:
		out.append("")
	return out.slice(0, SLOTS)


## Os ids equipados (sem os slots vazios), na ordem dos slots.
static func equipped(hero) -> Array:
	return slots(hero).filter(func(id): return String(id) != "")


## A migração de um herói (roda no load, por AHStationRules.migrate): o relic_id antigo vira o slot 0 e a chave sai.
## Idempotente. O estoque não muda; só se o slot já estiver ocupado por outra (um save editado), a antiga volta a ele.
static func migrate_hero(campaign: Dictionary, hero: Dictionary) -> void:
	var fresh := slots({"relics": hero.get("relics")}) if typeof(hero.get("relics")) == TYPE_ARRAY else slots({})
	# Um save editado com mais slots que SLOTS, ou a mesma relíquia nos dois: o excesso e a cópia voltam ao estoque.
	if typeof(hero.get("relics")) == TYPE_ARRAY:
		var raw: Array = hero.relics
		for i in range(SLOTS, raw.size()):
			var extra := String(raw[i]) if raw[i] != null else ""
			if extra != "":
				campaign.inventory.relics.append(extra)
		for i in range(1, SLOTS):
			if fresh[i] != "" and fresh.slice(0, i).has(fresh[i]):
				campaign.inventory.relics.append(fresh[i])
				fresh[i] = ""
	var old := String(hero.get("relic_id", ""))
	if old != "" and not fresh.has(old):
		var free := fresh.find("")
		if free >= 0:
			fresh[free] = old
		else:
			campaign.inventory.relics.append(old)
	hero.relics = fresh
	hero.erase("relic_id")


# ---------------------------------------------------------------- equipar

## Põe relic_id no slot do herói ("" desequipa). Tira do estoque e devolve ao estoque a que saiu. Devolve "" ou o erro.
static func equip(campaign: Dictionary, hero_id: String, slot: int, relic_id: String) -> String:
	var hero = AHStationRules.hero(campaign, hero_id)
	if hero == null or not hero.get("alive", true):
		return TranslationServer.translate("Só animais vivos usam relíquias.")
	if slot < 0 or slot >= SLOTS:
		return TranslationServer.translate("Esse slot não existe.")
	var current := slots(hero)
	if current[slot] == relic_id:
		return TranslationServer.translate("Já está equipada.") if relic_id != "" else TranslationServer.translate("O slot já está vazio.")
	if relic_id != "":
		if GameData.row("relics", relic_id) == null:
			return TranslationServer.translate("Relíquia desconhecida.")
		if not campaign.inventory.relics.has(relic_id):
			return TranslationServer.translate("Essa relíquia não está no estoque.")
		var why := block(campaign, hero, slot, relic_id)
		if why != "":
			return why
		campaign.inventory.relics.erase(relic_id)
	if current[slot] != "":
		campaign.inventory.relics.append(current[slot])
	current[slot] = relic_id
	hero.relics = current
	hero.erase("relic_id")
	return ""


## Por que o slot do herói não aceita a relíquia ("" aceita): o mesmo id no outro slot, o papel ou o fundador errado.
static func block(campaign: Dictionary, hero, slot: int, relic_id: String) -> String:
	if relic_id == "" or hero == null:
		return ""
	var current := slots(hero)
	for other in SLOTS:
		if other != slot and current[other] == relic_id:
			return TranslationServer.translate("Já equipada no outro slot.")
	var row = GameData.row("relics", relic_id)
	var only := String(row.get("Only", "")) if row != null else ""
	if only.begins_with("role:"):
		var class_id := only.trim_prefix("role:")
		if String(hero.get("class_id", "")) != class_id:
			return TranslationServer.translate("Só para %s.") % AHSpecies.role(class_id)
	elif only.begins_with("hero:"):
		var owner_id := only.trim_prefix("hero:")
		if String(hero.get("id", "")) != owner_id:
			var owner = AHStationRules.hero(campaign, owner_id)
			return TranslationServer.translate("Só %s usa.") % (String(owner.display_name) if owner != null else owner_id)
	return ""


## As opções do slot, na ordem do ciclo do botão Trocar: "" (vazio), depois cada id do estoque uma vez (na ordem em que
## estão) e, por fim, o equipado ali. [aceitas, bloqueadas {id: motivo}].
static func options(campaign: Dictionary, hero, slot: int) -> Array:
	var accepted: Array = [""]
	var blocked := {}
	for relic_id in campaign.inventory.relics:
		var id := String(relic_id)
		if accepted.has(id) or blocked.has(id):
			continue
		var why: String = block(campaign, hero, slot, id) if GameData.row("relics", id) != null \
			else TranslationServer.translate("Relíquia desconhecida.")
		if why == "":
			accepted.append(id)
		else:
			blocked[id] = why
	var current: String = slots(hero)[slot]
	if current != "" and not accepted.has(current):
		accepted.append(current)
	return [accepted, blocked]


# ---------------------------------------------------------------- os bônus

## O total dos bônus de uma lista de ids, numa tabela de relíquias (a de GameData ou a tipada do motor): cada relíquia
## conta uma vez, e a Velocidade tem o teto de SPEED_CAP. {max_hp, speed, event_instinct, virtue}.
static func totals(ids: Array, table: Dictionary) -> Dictionary:
	var out := {"max_hp": 0, "speed": 0, "event_instinct": 0, "virtue": 0.0}
	var seen := {}
	for relic_id in ids:
		var id := String(relic_id)
		if id == "" or seen.has(id):
			continue
		seen[id] = true
		var row = table.get(id)
		if row == null:
			continue
		out.max_hp += int(row.get("MaxHpBonus", 0))
		out.speed += int(row.get("SpeedBonus", 0))
		out.event_instinct += int(row.get("EventInstinctReduction", 0))
		out.virtue += float(row.get("VirtueBonus", 0.0))
	out.speed = mini(SPEED_CAP, int(out.speed))
	return out


static func max_hp_bonus(hero) -> int:
	return int(totals(equipped(hero), GameData.table("relics")).max_hp)


static func speed_bonus(hero) -> int:
	return int(totals(equipped(hero), GameData.table("relics")).speed)


static func event_instinct_reduction(hero) -> int:
	return int(totals(equipped(hero), GameData.table("relics")).event_instinct)


static func virtue_bonus(hero) -> float:
	return float(totals(equipped(hero), GameData.table("relics")).virtue)


# ---------------------------------------------------------------- de onde saem

static func rarity(relic_id: String) -> String:
	var row = GameData.row("relics", relic_id)
	var value := String(row.get("Rarity", "common")) if row != null else ""
	return value if RARITIES.has(value) else "common"


static func has_source(relic_id: String, source: String) -> bool:
	var row = GameData.row("relics", relic_id)
	return row != null and Array(row.get("Sources", [])).has(source)


## Os ids que um sorteio daquela origem pode escolher, em ordem: com a origem nas Sources, comum ou incomum, e, se a
## relíquia tem Phase, só no sorteio daquela fase (phase_id "" exclui todas as de fase).
static func pool(source: String, phase_id: String = "") -> Array:
	var out: Array = []
	for relic_id in GameData.table("relics"):
		var id := String(relic_id)
		var row: Dictionary = GameData.row("relics", id)
		if not has_source(id, source) or not DRAWABLE.has(rarity(id)):
			continue
		var phase := String(row.get("Phase", ""))
		if phase != "" and phase != phase_id:
			continue
		out.append(id)
	out.sort()
	return out


## O que a Forja fabrica: as comuns com "forge" entre as origens, em ordem.
static func forgeable() -> Array:
	return pool("forge").filter(func(id): return rarity(id) == FORGE_RARITY)


static func can_forge(relic_id: String) -> bool:
	return forgeable().has(relic_id)
