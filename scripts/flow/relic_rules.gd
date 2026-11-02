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
## - Os gatilhos da luta (parte 2): StartBlock e StartDodge (as fichas com que a unidade entra na luta), FirstTurnSpeed
##   (a Velocidade a mais só na iniciativa da primeira rodada, dentro do mesmo teto), AllyDownInstinct (o Instinto a mais
##   quando um aliado cai no Último Fôlego), MachineDamageBonus (os pontos percentuais a mais no dano direto contra a
##   família mecânica, #227) e o "+N" numa habilidade: Ability (o id) com AbilityUses (cargas e usos), AbilityDamage,
##   AbilityBlock, AbilityRemoveBlock, AbilityMarkTurns (a duração da Marca) e AbilitySelfInstinct (no próprio usuário).
## - Guardian: o inimigo que dá a rara na vitória sobre o guardião, uma vez (campaign.relic_given). Effect: o efeito na
##   tela quando a Description é só o texto do objeto (o Colar de Circuito).
##
## A perda na derrota (parte 2): o que entra no estoque durante a expedição (a carga, o evento, o guardião) fica anotado
## em expedition.found_relics; a derrota total tira de volta essas cópias, menos a Lembrança, que nunca se perde.
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

## Os campos do "+N" numa habilidade (Ability) e a chave de cada um em totals().abilities.
const ABILITY_FIELDS := {"AbilityUses": "uses", "AbilityDamage": "damage", "AbilityBlock": "block",
	"AbilityRemoveBlock": "remove_block", "AbilityMarkTurns": "mark_turns", "AbilitySelfInstinct": "self_instinct"}


## O total dos bônus de uma lista de ids, numa tabela de relíquias (a de GameData ou a tipada do motor): cada relíquia
## conta uma vez, e a Velocidade tem o teto de SPEED_CAP (a da primeira rodada também, somada à de sempre).
## {max_hp, speed, event_instinct, virtue, start_block, start_dodge, first_turn_speed, ally_down_instinct,
## machine_damage, abilities: {ability_id: {uses, damage, block, remove_block, mark_turns, self_instinct}}}.
static func totals(ids: Array, table: Dictionary) -> Dictionary:
	var out := {"max_hp": 0, "speed": 0, "event_instinct": 0, "virtue": 0.0, "start_block": 0, "start_dodge": 0,
		"first_turn_speed": 0, "ally_down_instinct": 0, "machine_damage": 0, "abilities": {}}
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
		out.start_block += int(row.get("StartBlock", 0))
		out.start_dodge += int(row.get("StartDodge", 0))
		out.first_turn_speed += int(row.get("FirstTurnSpeed", 0))
		out.ally_down_instinct += int(row.get("AllyDownInstinct", 0))
		out.machine_damage += int(row.get("MachineDamageBonus", 0))
		var ability := String(row.get("Ability", ""))
		if ability != "":
			var mods: Dictionary = out.abilities.get(ability, {})
			for field in ABILITY_FIELDS:
				var key: String = ABILITY_FIELDS[field]
				mods[key] = int(mods.get(key, 0)) + int(row.get(field, 0))
			out.abilities[ability] = mods
	out.speed = mini(SPEED_CAP, int(out.speed))
	out.first_turn_speed = clampi(int(out.first_turn_speed), 0, maxi(0, SPEED_CAP - maxi(0, int(out.speed))))
	return out


## O "+N" de uma habilidade ({uses, damage, ...}) das relíquias do herói; {} sem nenhum.
static func ability_mods(hero, ability_id: String) -> Dictionary:
	return totals(equipped(hero), GameData.table("relics")).abilities.get(ability_id, {})


## As cargas ou os usos a mais de uma habilidade (a Rolha de Cisterna na Ampola, o Caderno no Antídoto).
static func extra_uses(hero, ability_id: String) -> int:
	return int(ability_mods(hero, ability_id).get("uses", 0))


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


# ---------------------------------------------------------------- as origens especiais (parte 2)

## As relíquias que só saem uma vez por campanha e já saíram: a rara de cada guardião e a pessoal de cada fundador.
static func given(campaign: Dictionary) -> Array:
	if typeof(campaign.get("relic_given")) != TYPE_ARRAY:
		campaign.relic_given = []
	return campaign.relic_given


## A relíquia está com a equipe: no estoque ou num slot de alguém do elenco.
static func owned(campaign: Dictionary, relic_id: String) -> bool:
	if campaign.get("inventory", {}).get("relics", []).has(relic_id):
		return true
	return campaign.get("roster", []).any(func(entry): return slots(entry).has(relic_id))


## A relíquia que a equipe acha na expedição (a carga, o evento, o guardião): entra no estoque e fica anotada no achado
## da expedição (expedition.found_relics), para a derrota total tirar de volta. Fora da expedição, só entra no estoque.
static func find(campaign: Dictionary, relic_id: String) -> void:
	if relic_id == "":
		return
	campaign.inventory.relics.append(relic_id)
	var expedition = campaign.get("session", {}).get("expedition")
	if typeof(expedition) == TYPE_DICTIONARY:
		if typeof(expedition.get("found_relics")) != TYPE_ARRAY:
			expedition.found_relics = []
		expedition.found_relics.append(relic_id)


## A derrota total: as relíquias achadas nesta expedição saem de novo (do estoque ou, se alguém já a pôs num slot, do
## slot), menos a Lembrança, que nunca se perde. A rara e a pessoal voltam a poder sair (relic_given). As equipadas
## antes e o estoque de antes ficam. Devolve os ids perdidos, na ordem em que foram achados.
static func lose_finds(campaign: Dictionary, expedition: Dictionary) -> Array:
	var lost: Array = []
	for relic_id in expedition.get("found_relics", []):
		var id := String(relic_id)
		if rarity(id) == "keepsake":
			continue
		if campaign.inventory.relics.has(id):
			campaign.inventory.relics.erase(id)
		else:
			var taken := false
			for entry in campaign.roster:
				var current := slots(entry)
				var at := current.find(id)
				if at >= 0 and not taken:
					current[at] = ""
					entry.relics = current
					taken = true
			if not taken:
				continue
		given(campaign).erase(id)
		lost.append(id)
	expedition.found_relics = []
	return lost


## A rara de cada guardião vencido (Guardian com o id do inimigo), uma vez por campanha. enemy_ids: quem estava na luta.
## Devolve as que saíram agora (achadas na expedição: a derrota total as tira).
static func guardian_trophies(campaign: Dictionary, enemy_ids: Array) -> Array:
	var out: Array = []
	for id in _sorted_ids():
		var row: Dictionary = GameData.row("relics", id)
		if rarity(id) != "rare" or not has_source(id, "guardian") or not enemy_ids.has(String(row.get("Guardian", ""))):
			continue
		if given(campaign).has(id):
			continue
		given(campaign).append(id)
		find(campaign, id)
		out.append(id)
	return out


## A rara que o guardião desta luta ainda daria (sem mudar nada): o popup do fim da luta mostra antes de ela fechar.
static func guardian_preview(campaign: Dictionary, enemy_ids: Array) -> Array:
	return _sorted_ids().filter(func(id): return rarity(id) == "rare" and has_source(id, "guardian") \
		and enemy_ids.has(String(GameData.row("relics", id).get("Guardian", ""))) and not given(campaign).has(id))


## A pessoal do fundador (Only "hero:<id>", origem "solo") na primeira missão solo que ele cumpre, uma vez. Devolve o
## id ("" sem nenhuma, ou já dada). Fica na Estação: a missão solo não é a expedição, e nada a tira.
static func solo_personal(campaign: Dictionary, hero_id: String) -> String:
	for id in _sorted_ids():
		var row: Dictionary = GameData.row("relics", id)
		if rarity(id) != "personal" or not has_source(id, "solo") or String(row.get("Only", "")) != "hero:" + hero_id:
			continue
		if given(campaign).has(id):
			continue
		given(campaign).append(id)
		campaign.inventory.relics.append(id)
		return id
	return ""


## A Incomum que o Mercador traz nesta visita ("" sem nenhuma): uma das de origem "merchant", sorteada à parte pela
## expedição da visita (o mesmo ao salvar e voltar; nenhum outro sorteio muda).
static func merchant_offer(campaign: Dictionary) -> String:
	var offers: Array = pool("merchant").filter(func(id): return rarity(id) == "uncommon")
	if offers.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:merchant_relic" % String(campaign.get("station", {}).get("train", {}).get("expedition_id", "")))
	return offers[rng.randi_range(0, offers.size() - 1)]


# ---------------------------------------------------------------- na tela

const RARITY_NAMES := {"common": "Comum", "uncommon": "Incomum", "rare": "Rara", "personal": "Pessoal", "keepsake": "Lembrança"}


## O nome da raridade, no idioma do jogo.
static func rarity_name(relic_id: String) -> String:
	return TranslationServer.translate(RARITY_NAMES.get(rarity(relic_id), "Comum"))


## O que a relíquia faz e o texto dela, no idioma do jogo: o Effect antes, quando a Description é só o objeto.
static func text(relic_id: String) -> String:
	var row = GameData.row("relics", relic_id)
	if row == null:
		return ""
	var description := TranslationServer.translate(String(row.get("Description", "")))
	var effect := String(row.get("Effect", ""))
	return description if effect == "" else "%s %s" % [TranslationServer.translate(effect), description]


## A relíquia piora algum número (a Vida, a Velocidade ou a Superação): a ficha a mostra no tom de custo.
static func has_cost(relic_id: String) -> bool:
	var row = GameData.row("relics", relic_id)
	return row != null and (int(row.get("MaxHpBonus", 0)) < 0 or int(row.get("SpeedBonus", 0)) < 0 or float(row.get("VirtueBonus", 0.0)) < 0.0)


static func _sorted_ids() -> Array:
	var ids: Array = GameData.table("relics").keys().map(func(id): return String(id))
	ids.sort()
	return ids
