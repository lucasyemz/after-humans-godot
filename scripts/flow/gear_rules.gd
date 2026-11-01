## A Arma e a Segunda Pele de cada herói (#262, aprovado pelo Orquestrador em nome do Lucas em 01/11): duas peças que só
## sobem, de 0 a 4, melhoradas na Forja, sem mudar o visual. Os números em data/gear.json.
## - A Arma soma nos limites de dano (nunca na cura) e no crítico.
## - A Segunda Pele soma Vida máxima (gravada no herói na compra, como o Treino) e as resistências a dano contínuo e a
##   atordoamento.
## - Cada nível pede o herói e a Forja num nível mínimo, sucata e fragmentos; a Forja faz 1 melhoria por dia (2 no
##   nível 2).
## Save: no herói, gear = {weapon: n, armor: n}; na Estação, forge {cycle, heroes} (o dia, como o Treino).
class_name AHGear
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")

const WEAPON := "weapon"
const ARMOR := "armor"
const PIECES := [WEAPON, ARMOR]
const MAX_LEVEL := 4
## O dia da Forja (station[DAY], como bar_talks e training da #265).
const DAY := "forge"
## Teto das resistências do herói (#258).
const RESIST_CAP := 0.8


static func rule(name: String) -> Dictionary:
	var row = GameData.row("gear", name)
	return row if row != null else {}


## O nível da peça no herói (0 sem melhoria).
static func level(hero: Dictionary, piece: String) -> int:
	var gear = hero.get("gear")
	if typeof(gear) != TYPE_DICTIONARY or not [TYPE_INT, TYPE_FLOAT].has(typeof(gear.get(piece))):
		return 0
	return clampi(int(gear[piece]), 0, MAX_LEVEL)


## A linha do nível n da peça ({} fora de 1..4).
static func step(piece: String, at: int) -> Dictionary:
	return rule("%s_%d" % [piece, at]) if at >= 1 and at <= MAX_LEVEL else {}


## O que as peças somam na luta: {damage, crit (pp), dot (pp), stun (pp)}. A vida já está no herói.
static func combat_bonus(hero: Dictionary) -> Dictionary:
	var out := {"damage": 0, "crit": 0, "dot": 0, "stun": 0, "max_hp": 0}
	for piece in PIECES:
		for at in range(1, level(hero, piece) + 1):
			var row := step(piece, at)
			out.damage += int(row.get("Damage", 0))
			out.crit += int(row.get("Crit", 0))
			out.dot += int(row.get("DotResist", 0))
			out.stun += int(row.get("StunResist", 0))
			out.max_hp += int(row.get("MaxHp", 0))
	return out


## Quantas melhorias a Forja faz hoje (1 no nível 1, 2 no nível 2) e quantas ainda faz.
static func per_day(campaign: Dictionary) -> int:
	var days: Array = rule("forge_day").get("PerDay", [1, 2])
	return int(days[clampi(S.room_level(campaign, S.FORGE), 1, days.size()) - 1])


static func left_today(campaign: Dictionary) -> int:
	if not S.room_available(campaign, S.FORGE):
		return 0
	return maxi(0, per_day(campaign) - AHStationServices.used_today(campaign, DAY))


## Por que o herói não chega à Forja agora ("" chega): a Forja não recuperada, a expedição ou a missão solo. O nível,
## os recursos e o dia a própria Forja mostra.
static func reach_block(campaign: Dictionary, hero_id: String) -> String:
	var hero = S.hero(campaign, hero_id)
	if hero == null or not hero.get("alive", true):
		return TranslationServer.translate("Herói não encontrado.")
	if not S.room_available(campaign, S.FORGE):
		return TranslationServer.translate("Recupere a Forja para melhorar as peças.")
	var expedition = campaign.get("session", {}).get("expedition")
	if expedition != null and Array(expedition.get("team", [])).has(hero_id):
		return TranslationServer.translate("%s está na expedição.") % hero.display_name
	if AHSideMissions.away(hero):
		return AHSideMissions.away_text(hero)
	return ""


## Por que a peça não melhora agora ("" melhora).
static func block(campaign: Dictionary, hero_id: String, piece: String) -> String:
	var hero = S.hero(campaign, hero_id)
	if hero == null or not hero.get("alive", true):
		return TranslationServer.translate("Herói não encontrado.")
	if not PIECES.has(piece):
		return TranslationServer.translate("Peça desconhecida.")
	var at := level(hero, piece) + 1
	if at > MAX_LEVEL:
		return TranslationServer.translate("%s já está no nível máximo.") % piece_name(piece)
	var reach := reach_block(campaign, hero_id)
	if reach != "":
		return reach
	var row := step(piece, at)
	if AHHeroLevels.level(hero) < int(row.get("HeroLevel", 1)):
		return TranslationServer.translate("Pede o herói no nível %d.") % int(row.get("HeroLevel", 1))
	if S.room_level(campaign, S.FORGE) < int(row.get("ForgeLevel", 1)):
		return TranslationServer.translate("Pede a Forja no nível %d.") % int(row.get("ForgeLevel", 1))
	if left_today(campaign) <= 0:
		return TranslationServer.translate("A Forja já fez o que dava hoje. Volte amanhã.")
	var scrap := int(row.get("Scrap", 0))
	var fragments := int(row.get("Fragments", 0))
	if S.quantity(campaign, "scrap") < scrap or S.quantity(campaign, "fragments") < fragments:
		return TranslationServer.translate("Faltam recursos: %s.") % S.cost_text({"scrap": scrap, "fragments": fragments})
	return ""


## Melhora a peça um nível: confere tudo antes, cobra uma vez, sobe o nível, soma a vida (se houver) e marca o dia.
## Devolve o erro ("" melhorou).
static func upgrade(campaign: Dictionary, hero_id: String, piece: String) -> String:
	var reason := block(campaign, hero_id, piece)
	if reason != "":
		return reason
	var hero = S.hero(campaign, hero_id)
	var at := level(hero, piece) + 1
	var row := step(piece, at)
	S.adjust(campaign, "scrap", -int(row.get("Scrap", 0)))
	S.adjust(campaign, "fragments", -int(row.get("Fragments", 0)))
	var gear := {WEAPON: level(hero, WEAPON), ARMOR: level(hero, ARMOR)}
	gear[piece] = at
	hero.gear = gear
	var life := int(row.get("MaxHp", 0))
	if life > 0:
		hero.max_hp = int(hero.max_hp) + life
		hero.hp = int(hero.hp) + life
	AHStationServices.mark_use(campaign, DAY, hero_id)
	return ""


static func piece_name(piece: String) -> String:
	return TranslationServer.translate("Arma") if piece == WEAPON else TranslationServer.translate("Segunda Pele")


## O que a peça faz, em palavras.
static func piece_about(piece: String) -> String:
	return TranslationServer.translate("Remendada na Forja: bate um pouco mais forte.") if piece == WEAPON \
		else TranslationServer.translate("Placas e reforços costurados na roupa.")


## O efeito de um nível da peça ("+1 de dano", "+3 de Vida máxima").
static func step_text(piece: String, at: int) -> String:
	var row := step(piece, at)
	var parts: Array[String] = []
	if int(row.get("Damage", 0)) > 0:
		parts.append(TranslationServer.translate("+%d de dano") % int(row.Damage))
	if int(row.get("Crit", 0)) > 0:
		parts.append(TranslationServer.translate("+%d%% de crítico") % int(row.Crit))
	if int(row.get("MaxHp", 0)) > 0:
		parts.append(TranslationServer.translate("+%d de Vida máxima") % int(row.MaxHp))
	if int(row.get("DotResist", 0)) > 0:
		parts.append(TranslationServer.translate("+%d%% de resistência a dano contínuo") % int(row.DotResist))
	if int(row.get("StunResist", 0)) > 0:
		parts.append(TranslationServer.translate("+%d%% de resistência a atordoamento") % int(row.StunResist))
	return ", ".join(parts)


## O total da peça no nível de agora ("" no nível 0).
static func total_text(hero: Dictionary, piece: String) -> String:
	var parts: Array[String] = []
	var bonus := {"Damage": 0, "Crit": 0, "MaxHp": 0, "DotResist": 0, "StunResist": 0}
	for at in range(1, level(hero, piece) + 1):
		for key in bonus:
			bonus[key] += int(step(piece, at).get(key, 0))
	if bonus.Damage > 0:
		parts.append(TranslationServer.translate("+%d de dano") % bonus.Damage)
	if bonus.Crit > 0:
		parts.append(TranslationServer.translate("+%d%% de crítico") % bonus.Crit)
	if bonus.MaxHp > 0:
		parts.append(TranslationServer.translate("+%d de Vida máxima") % bonus.MaxHp)
	if bonus.DotResist > 0:
		parts.append(TranslationServer.translate("+%d%% de resistência a dano contínuo") % bonus.DotResist)
	if bonus.StunResist > 0:
		parts.append(TranslationServer.translate("+%d%% de resistência a atordoamento") % bonus.StunResist)
	return ", ".join(parts)


## O próximo nível da peça, para a ficha da Sala ("" no máximo): "Próximo: nível 2, +2% de crítico (herói nível 4,
## Forja nível 1, 4 sucatas e 1 fragmento)".
static func next_text(hero: Dictionary, piece: String) -> String:
	var at := level(hero, piece) + 1
	if at > MAX_LEVEL:
		return ""
	var row := step(piece, at)
	return TranslationServer.translate("Próximo: nível %d, %s (herói nível %d, Forja nível %d, %s)") % [at, step_text(piece, at),
		int(row.get("HeroLevel", 1)), int(row.get("ForgeLevel", 1)), S.cost_text({"scrap": int(row.get("Scrap", 0)), "fragments": int(row.get("Fragments", 0))})]


## A resistência com a peça, como na luta (AHCombatEngine.hero_resist): até o teto, nunca abaixo da do papel.
static func resist_with(role_value: float, extra_pp: int) -> float:
	return maxf(role_value, minf(RESIST_CAP, role_value + extra_pp / 100.0)) if extra_pp > 0 else role_value


## Saves de antes da #262 e editados: o gear que não é {weapon, armor} com números de 0 a 4 vira esses números (o que
## não for número vira 0; a vida já somada fica, para não cobrar de novo).
static func migrate(campaign: Dictionary) -> void:
	for hero in campaign.get("roster", []):
		if typeof(hero) != TYPE_DICTIONARY:
			continue
		hero.gear = {WEAPON: level(hero, WEAPON), ARMOR: level(hero, ARMOR)}
