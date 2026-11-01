## Os serviços dos cômodos aos personagens (#265, aprovado pelo Orquestrador em nome do Lucas em 01/11), os números
## em data/station-services.json:
## - o Bar: na volta, quem ficou na Estação perde Instinto (sem efeito colateral); a conversa trata o trauma (as
##   sementes saíram do Alojamento);
## - o Dormitório com os beliches: mais Instinto a menos na noite da volta;
## - a Enfermaria no nível 2: trata uma peculiaridade negativa, ocupando um leito por alguns dias.
## - o Treino: um herói treina por dia (dois no nível 2); o Bar conversa uma vez por dia (duas no nível 2).
## Save: no herói, quirk_treatment {perk, days} enquanto trata; na Estação, bar_talks e training {cycle, heroes}.
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


## As conversas que o Bar ainda faz hoje (o dia é o ciclo da Estação): uma no nível 1, duas no nível 2.
static func talks_left(campaign: Dictionary) -> int:
	if not S.room_available(campaign, S.BAR):
		return 0
	var per_day: Array = rule("bar").get("TalksPerDay", [1, 2])
	var level := clampi(S.room_level(campaign, S.BAR), 1, per_day.size())
	return maxi(0, int(per_day[level - 1]) - _today(campaign, "bar_talks").size())


## Quem já usou o serviço hoje (station[key] = {cycle, heroes}); de outro dia, ninguém.
static func _today(campaign: Dictionary, key: String) -> Array:
	var day = campaign.get("station", {}).get(key)
	if not _valid_day(day) or int(day.cycle) != int(campaign.station.get("cycle_number", 0)):
		return []
	return Array(day.heroes)


## {cycle: número, heroes: [ids]}: o que o save guarda de cada dia (o resto, de um save editado, é ignorado e limpo).
static func _valid_day(day) -> bool:
	if typeof(day) != TYPE_DICTIONARY or not [TYPE_INT, TYPE_FLOAT].has(typeof(day.get("cycle"))) or typeof(day.get("heroes")) != TYPE_ARRAY:
		return false
	return Array(day.heroes).all(func(id): return typeof(id) == TYPE_STRING)


## each: true conta cada vez (as conversas do Bar); false, cada herói uma vez (o Treino).
static func _mark_today(campaign: Dictionary, key: String, hero_id: String, each: bool = false) -> void:
	var heroes := _today(campaign, key)
	if each or not heroes.has(hero_id):
		heroes.append(hero_id)
	campaign.station[key] = {"cycle": int(campaign.station.get("cycle_number", 0)), "heroes": heroes}


static func mark_talk(campaign: Dictionary, hero_id: String) -> void:
	_mark_today(campaign, "bar_talks", hero_id, true)


# ---------------------------------------------------------------- o Treino

## Quantos heróis o Treino recebe por dia (1 no nível 1, 2 no nível 2).
static func trainees_per_day(campaign: Dictionary) -> int:
	var per_day: Array = rule("training").get("PerDay", [1, 2])
	return int(per_day[clampi(S.room_level(campaign, S.TRAINING), 1, per_day.size()) - 1])


## Por que o herói não treina hoje ("" treina): quem já treinou hoje continua; um novo só se o dia tiver vaga.
static func training_block(campaign: Dictionary, hero_id: String) -> String:
	var today := _today(campaign, "training")
	if today.has(hero_id) or today.size() < trainees_per_day(campaign):
		return ""
	return TranslationServer.translate("O Treino já recebeu %d herói hoje. Volte amanhã.") % trainees_per_day(campaign) \
		if trainees_per_day(campaign) == 1 else TranslationServer.translate("O Treino já recebeu %d heróis hoje. Volte amanhã.") % trainees_per_day(campaign)


static func mark_training(campaign: Dictionary, hero_id: String) -> void:
	_mark_today(campaign, "training", hero_id)


## Aprender uma de acampamento é no Treino (#265): respeita o dia do Treino e conta como o treino de hoje.
static func learn_camp(campaign: Dictionary, hero_id: String, skill_id: String) -> String:
	var block := training_block(campaign, hero_id)
	if block != "":
		return block
	var result := AHCampSkills.learn(campaign, hero_id, skill_id)
	if result == "":
		mark_training(campaign, hero_id)
	return result


# ---------------------------------------------------------------- o Dormitório

## Quanto Instinto a mais os beliches tiram de quem dorme na noite da volta (0 sem eles).
static func bunk_relief(campaign: Dictionary) -> int:
	return int(rule("dormitory").get("BunkInstinct", 3)) if S.room_level(campaign, S.DORMITORY) >= 2 else 0


# ---------------------------------------------------------------- a Enfermaria

static func treating(entry) -> bool:
	return entry != null and _valid_treatment(entry.get("quirk_treatment")) and int(entry.quirk_treatment.days) > 0


## {perk: texto, days: número}: o tratamento que o save guarda.
static func _valid_treatment(t) -> bool:
	return typeof(t) == TYPE_DICTIONARY and typeof(t.get("perk")) == TYPE_STRING and [TYPE_INT, TYPE_FLOAT].has(typeof(t.get("days")))


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


## Saves editados: o tratamento de outro tipo, sem dias ou de uma peculiaridade que não é negativa dele sai; os dias do
## Bar e do Treino de outro tipo também.
static func migrate(campaign: Dictionary) -> void:
	var station = campaign.get("station")
	if typeof(station) == TYPE_DICTIONARY:
		for key in ["bar_talks", "training"]:
			if station.has(key) and not _valid_day(station[key]):
				station.erase(key)
	for entry in campaign.get("roster", []):
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("quirk_treatment"):
			continue
		var t = entry.quirk_treatment
		if typeof(entry.get("perks")) != TYPE_ARRAY or not _valid_treatment(t) or int(t.days) <= 0 or not negative_perks(entry).has(t.perk):
			entry.erase("quirk_treatment")


## O que os serviços fizeram, para o relatório da volta e do Esperar um dia: quem terminou o tratamento e quem o Bar
## aliviou.
static func report_lines(campaign: Dictionary, report: Dictionary) -> Array:
	var lines: Array = []
	for done in report.get("treated", []):
		var entry = S.hero(campaign, String(done.get("hero_id", "")))
		var row = GameData.row("perks", String(done.get("perk", "")))
		if entry != null:
			lines.append(TranslationServer.translate("%s terminou o tratamento na Enfermaria: não tem mais %s.") % [entry.display_name,
				TranslationServer.translate(String(row.DisplayName)) if row != null else String(done.get("perk", ""))])
	var eased: Array = []
	var amount := 0
	for relief in report.get("bar", []):
		var entry = S.hero(campaign, String(relief.get("hero_id", "")))
		if entry != null:
			eased.append(String(entry.display_name))
			amount = maxi(amount, int(relief.get("instinct", 0)))
	if not eased.is_empty():
		lines.append(TranslationServer.translate("O Bar aliviou quem ficou na Estação (%s): −%d de Instinto.") % [", ".join(eased), amount])
	return lines
