## Os serviços dos cômodos aos personagens (#265, aprovado pelo Orquestrador em nome do Lucas em 01/11), os números
## em data/station-services.json:
## - o Bar: na volta, quem ficou na Estação perde Instinto (sem efeito colateral); a conversa trata o trauma (as
##   sementes saíram do Alojamento);
## - o Dormitório com os beliches: mais Instinto a menos na noite da volta;
## - a Enfermaria no nível 2: trata uma peculiaridade negativa, ocupando um leito por alguns dias.
## O Treino como cômodo novo espera as respostas da issue (o custo e o que ensina em cada nível).
## Save: no herói, quirk_treatment {perk, days} enquanto trata.
class_name AHStationServices
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")


static func rule(name: String) -> Dictionary:
	var row = GameData.row("station_services", name)
	return row if row != null else {}


static func trauma_cost() -> int:
	return int(rule("bar").get("TraumaSeeds", 5))


# ---------------------------------------------------------------- o Bar

## O alívio do Bar na volta: quem ficou na Estação (vivo, fora da recuperação, da missão solo e do tratamento) perde
## Instinto. Sem o Bar recuperado, nada. Devolve [{hero_id, instinct}] (quanto baixou) para o relatório.
static func bar_relief(campaign: Dictionary, team: Array) -> Array:
	var out: Array = []
	if not S.room_available(campaign, S.BAR):
		return out
	var amount := int(rule("bar").get("Instinct", 5))
	for entry in campaign.roster:
		if team.has(entry.id) or not entry.get("alive", true) or S.recovering(entry) or AHSideMissions.away(entry) or treating(entry):
			continue
		var before := int(entry.get("instinct", 0))
		entry.instinct = clampi(before - amount, 0, 200)
		if entry.instinct != before:
			out.append({"hero_id": entry.id, "instinct": before - entry.instinct})
	return out


# ---------------------------------------------------------------- o Dormitório

## Quanto Instinto a mais os beliches tiram de quem dorme na noite da volta (0 sem eles).
static func bunk_relief(campaign: Dictionary) -> int:
	return int(rule("dormitory").get("BunkInstinct", 3)) if S.room_level(campaign, S.DORMITORY) >= 2 else 0


# ---------------------------------------------------------------- a Enfermaria

static func treating(entry) -> bool:
	return entry != null and typeof(entry.get("quirk_treatment")) == TYPE_DICTIONARY and int(entry.quirk_treatment.get("days", 0)) > 0


## As peculiaridades negativas do herói (perks.json, bPositive falso).
static func negative_perks(entry: Dictionary) -> Array:
	return Array(entry.get("perks", [])).filter(func(id):
		var row = GameData.row("perks", String(id))
		return row != null and not bool(row.get("bPositive", true)))


## Os leitos ocupados por quem trata uma peculiaridade.
static func beds_treating(campaign: Dictionary) -> int:
	return campaign.roster.filter(func(h): return treating(h)).size()


## Por que o tratamento não começa ("" começa).
static func quirk_block(campaign: Dictionary, hero_id: String, perk_id: String) -> String:
	var entry = S.hero(campaign, hero_id)
	var info := rule("infirmary_quirk")
	if S.room_level(campaign, S.INFIRMARY) < int(info.get("Level", 2)):
		return TranslationServer.translate("A Enfermaria trata peculiaridades no nível %d.") % int(info.get("Level", 2))
	if entry == null or not entry.get("alive", true):
		return TranslationServer.translate("Herói não encontrado.")
	if not negative_perks(entry).has(perk_id):
		return TranslationServer.translate("Só uma peculiaridade negativa dele se trata.")
	if treating(entry):
		return TranslationServer.translate("%s já está em tratamento.") % entry.display_name
	if S.recovering(entry):
		return S.recovery_block(entry)
	if AHSideMissions.away(entry):
		return AHSideMissions.away_text(entry)
	var expedition = campaign.get("session", {}).get("expedition")
	if expedition != null and expedition.team.has(hero_id):
		return TranslationServer.translate("%s está na expedição.") % entry.display_name
	var used: int = S.fallen(campaign).filter(func(h): return S.in_bed(h)).size() + beds_treating(campaign)
	if used >= S.infirmary_beds(campaign):
		return TranslationServer.translate("Nenhum leito livre na Enfermaria.")
	return ""


## Começa o tratamento: ocupa um leito pelos dias da regra e sai do posto. Devolve o erro ("" começou).
static func treat_quirk(campaign: Dictionary, hero_id: String, perk_id: String) -> String:
	var reason := quirk_block(campaign, hero_id, perk_id)
	if reason != "":
		return reason
	var entry = S.hero(campaign, hero_id)
	entry.quirk_treatment = {"perk": perk_id, "days": maxi(1, int(rule("infirmary_quirk").get("Days", 2)))}
	entry.post = ""
	return ""


## Passa um dia: cada tratamento fica um dia mais perto; no fim, a peculiaridade sai. Devolve [{hero_id, perk}] dos
## que terminaram.
static func tick_treatments(campaign: Dictionary) -> Array:
	var done: Array = []
	for entry in campaign.roster:
		if not treating(entry):
			continue
		entry.quirk_treatment.days = int(entry.quirk_treatment.days) - 1
		if int(entry.quirk_treatment.days) <= 0:
			var perk := String(entry.quirk_treatment.get("perk", ""))
			entry.perks = Array(entry.get("perks", [])).filter(func(id): return String(id) != perk)
			entry.erase("quirk_treatment")
			done.append({"hero_id": entry.id, "perk": perk})
	return done


## O texto do tratamento ("Em tratamento: Medo de máquinas · 2 dias").
static func treatment_text(entry: Dictionary) -> String:
	if not treating(entry):
		return ""
	var row = GameData.row("perks", String(entry.quirk_treatment.perk))
	var name: String = TranslationServer.translate(String(row.DisplayName)) if row != null else String(entry.quirk_treatment.perk)
	return TranslationServer.translate("Em tratamento na Enfermaria: %s · %s") % [name, S.return_text(int(entry.quirk_treatment.days)).to_lower()]


## Saves editados: o tratamento de outro tipo ou de uma peculiaridade que ele não tem sai.
static func migrate(campaign: Dictionary) -> void:
	for entry in campaign.get("roster", []):
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("quirk_treatment"):
			continue
		var t = entry.quirk_treatment
		if typeof(t) != TYPE_DICTIONARY or not Array(entry.get("perks", [])).has(String(t.get("perk", ""))) or int(t.get("days", 0)) <= 0:
			entry.erase("quirk_treatment")
