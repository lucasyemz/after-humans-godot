## A Estação viva (#207): as regras das falas e dos pensamentos dos moradores (data/station-chatter.json) e das tirinhas
## (data/comics.json). Aqui só se decide: quais condições valem agora (lidas do save, sem nada novo nele), quem pode dizer
## cada entrada, o sorteio pelo peso, quanto tempo cada balão fica e quando a tirinha vira o Próximo passo. Quem está em
## que cômodo e os balões na tela ficam na cena (AHStationLife).
##
## Cada entrada: Name, Kind ("say" fala; "think" pensa), Speakers (ids de herói ou de civil, ou "founder", "recruit",
## "recruit_new" e "any"), Lines ([{Who: o índice em Speakers, Text, Comic?}]), When (as condições, todas valendo), Room
## (o cômodo de quem fala primeiro, ou "") e Weight. {nome} no texto é o nome de quem a condição aponta (o caído).
class_name AHStationChatter
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")

const BENTO := "hero_cao_bento"
const NICK := "hero_gato_nick"
const FOUNDERS := [BENTO, NICK, "hero_sapo_iris", "hero_coruja_vespera"]
## O intervalo entre um balão e o seguinte (s), sorteado.
const GAP := Vector2(14.0, 28.0)
## Quanto um balão fica: 2,5 s mais 45 ms por letra, até 6 s; numa conversa, a folga entre as falas.
const LINE_BASE := 2.5
const LINE_PER_CHAR := 0.045
const LINE_MAX := 6.0
const LINE_GAP := 0.4
## O balão interativo fica mais (dá tempo de apontar e apertar).
const STORY_LINE := 9.0
## O mesmo texto não volta antes de 10 minutos.
const REPEAT_MS := 600000
const CONDITIONS := ["food_low", "water_low", "power_full", "fallen", "train_waiting", "night", "good_return", "recruit_new"]


## As entradas, na ordem do nome (o sorteio fica igual com a mesma semente).
static func entries() -> Array:
	var table: Dictionary = GameData.table("station_chatter")
	var names: Array = table.keys()
	names.sort()
	return names.map(func(name): return table[name])


static func entry(name: String) -> Dictionary:
	var row = GameData.row("station_chatter", name)
	return row if row != null else {}


## As condições que valem agora: {id: true}, e "fallen_names" (os caídos em recuperação, na ordem do elenco).
static func conditions(campaign: Dictionary) -> Dictionary:
	var out := {}
	var ready := mini(4, S.ready_heroes(campaign).size())
	var f := S.forecast(campaign, ready)
	# Os suprimentos não pagam a próxima volta: o que sobra depois dos civis não alimenta a equipe.
	if f.food + f.food_produced - f.food_civilians < maxi(1, ready):
		out.food_low = true
	if f.thirsty:
		out.water_low = true
	if f.power_used >= f.power_capacity or not f.unpowered_rooms.is_empty():
		out.power_full = true
	var fallen := S.fallen(campaign)
	if not fallen.is_empty():
		out.fallen = true
	out.fallen_names = fallen.map(func(h): return [String(h.id), String(h.display_name)])
	if S.visit_pending(campaign):
		out.train_waiting = true
	if campaign.night.phase != "none":
		out.night = true
	var report: Dictionary = campaign.station.get("last_return", {})
	if not report.is_empty() and ["victory", "retreat"].has(String(report.get("result", ""))) and report.get("fallen", []).is_empty():
		out.good_return = true
	if not new_recruits(campaign).is_empty():
		out.recruit_new = true
	return out


## Os recrutas que ainda não saíram em nenhuma expedição (chegaram nesta visita ou na anterior).
static func new_recruits(campaign: Dictionary) -> Array:
	return S.living(campaign).filter(func(h): return S.is_recruit(String(h.id)) and int(h.get("expeditions_count", 0)) == 0) \
		.map(func(h): return String(h.id))


## Se o id vale para o papel da entrada.
static func fits(token: String, id: String, campaign: Dictionary) -> bool:
	match token:
		"any":
			return true
		"founder":
			return FOUNDERS.has(id)
		"recruit":
			return S.is_recruit(id)
		"recruit_new":
			return new_recruits(campaign).has(id)
	return token == id


## Quem diz a entrada agora: [ids na ordem de Speakers], ou [] se ela não sai. present: {id: {room, say, think}} de quem
## está à vista (a cena monta: quem dorme, trabalha na pose ou está caído não fala; o caído também não pensa). Todos no
## mesmo cômodo; Room, se houver, é o de quem fala primeiro.
static func cast(row: Dictionary, present: Dictionary, campaign: Dictionary, exclude_first: String = "") -> Array:
	var speakers: Array = row.get("Speakers", [])
	if speakers.is_empty():
		return []
	var mode := "say" if String(row.get("Kind", "say")) == "say" else "think"
	var first_who: int = int(row.Lines[0].get("Who", 0)) if not row.get("Lines", []).is_empty() else 0
	var ids: Array = present.keys()
	ids.sort()
	for lead in ids:
		if not fits(String(speakers[0]), lead, campaign) or not present[lead].get(mode, false):
			continue
		var room: String = present[lead].get("room", "")
		if room == "" or (String(row.get("Room", "")) != "" and room != row.Room):
			continue
		var chosen: Array = [lead]
		for index in range(1, speakers.size()):
			for id in ids:
				if chosen.has(id) or not fits(String(speakers[index]), id, campaign):
					continue
				if present[id].get("room", "") != room or not present[id].get(mode, false):
					continue
				chosen.append(id)
				break
		if chosen.size() != speakers.size():
			continue
		# O mesmo morador não fala duas vezes seguidas.
		if exclude_first != "" and chosen[first_who] == exclude_first:
			continue
		return chosen
	return []


## O nome que {nome} mostra: o primeiro caído que não está falando ("" se a entrada não precisa ou não há quem).
static func named(row: Dictionary, ids: Array, conditions_now: Dictionary) -> String:
	if not needs_name(row):
		return ""
	for pair in conditions_now.get("fallen_names", []):
		if not ids.has(pair[0]):
			return pair[1]
	return ""


## A entrada mostra {nome} (só sai com alguém para nomear).
static func needs_name(row: Dictionary) -> bool:
	for line in row.get("Lines", []):
		if String(line.Text).contains("{nome}"):
			return true
	return false


## Se a entrada pode sair agora, sem olhar quem está à vista: as condições valem e o texto não saiu nos últimos 10 min.
static func open(row: Dictionary, conditions_now: Dictionary, history: Dictionary, now_ms: int) -> bool:
	for condition in row.get("When", []):
		if not conditions_now.get(condition, false):
			return false
	var said = history.get(String(row.Name), null)
	return said == null or now_ms - int(said) >= REPEAT_MS


## O sorteio pelo peso entre as entradas que saem agora: {row, ids, name}, ou {} se nenhuma sai. last: quem falou por
## último (não abre a próxima).
static func pick(campaign: Dictionary, present: Dictionary, history: Dictionary, last: String, now_ms: int,
		rng: RandomNumberGenerator) -> Dictionary:
	var conditions_now := conditions(campaign)
	var options: Array = []
	var total := 0.0
	for row in entries():
		if not open(row, conditions_now, history, now_ms):
			continue
		var ids := cast(row, present, campaign, last)
		if ids.is_empty():
			continue
		var name := named(row, ids, conditions_now)
		if name == "" and needs_name(row):
			continue
		var weight := maxf(0.0, float(row.get("Weight", 1)))
		if weight <= 0.0:
			continue
		options.append({"row": row, "ids": ids, "name": name, "weight": weight})
		total += weight
	if options.is_empty():
		return {}
	var roll := rng.randf() * total
	for option in options:
		roll -= option.weight
		if roll <= 0.0:
			return option
	return options[-1]


## O texto da fala na língua do jogo, com o nome no lugar de {nome}.
static func line_text(line: Dictionary, name: String = "") -> String:
	return TranslationServer.translate(String(line.Text)).replace("{nome}", name)


## Quanto o balão fica na tela (s).
static func line_seconds(text: String) -> float:
	return minf(LINE_MAX, LINE_BASE + LINE_PER_CHAR * text.length())


# ---------------------------------------------------------------- as tirinhas

static func comic(name: String) -> Dictionary:
	var row = GameData.row("comics", name)
	return row if row != null else {}


static func comic_seen(campaign: Dictionary, name: String) -> bool:
	return campaign.station.get("comics_seen", []).has(name)


## Viu a tirinha (o balão apertado e o leitor fechado): sai do Próximo passo. O único rastro no save.
static func mark_seen(campaign: Dictionary, name: String) -> bool:
	if comic(name).is_empty() or comic_seen(campaign, name):
		return false
	if typeof(campaign.station.get("comics_seen")) != TYPE_ARRAY:
		campaign.station.comics_seen = []
	campaign.station.comics_seen.append(name)
	return true


## A tirinha que espera no Próximo passo ("" se nenhuma): liberada (Unlock.Returns: quantas voltas da expedição já
## houve), ainda não vista, sem a noite pendente e com quem conversa em casa e de pé (nenhum caído em recuperação).
static func story_pending(campaign: Dictionary) -> String:
	if campaign.night.phase != "none":
		return ""
	var names: Array = GameData.table("comics").keys()
	names.sort()
	for name in names:
		var row: Dictionary = comic(name)
		if comic_seen(campaign, name) or chatter_for(name).is_empty():
			continue
		if int(campaign.station.get("cycle_number", 0)) < int(row.get("Unlock", {}).get("Returns", 1)):
			continue
		var home := true
		for id in row.get("Speakers", []):
			var entry = S.hero(campaign, id)
			home = home and entry != null and entry.get("alive", true) and not S.recovering(entry)
		if home:
			return name
	return ""


## A conversa que leva à tirinha (a entrada com Comic numa das falas).
static func chatter_for(comic_name: String) -> Dictionary:
	for row in entries():
		for line in row.get("Lines", []):
			if String(line.get("Comic", "")) == comic_name:
				return row
	return {}


## O Próximo passo da tirinha (AHStationRules.next_step): ouvir a conversa e apertar o balão.
static func story_step(campaign: Dictionary) -> Dictionary:
	var name := story_pending(campaign)
	if name == "":
		return {}
	return {"title": TranslationServer.translate("Ouvir o Bento"), "text": TranslationServer.translate("O Bento e o Nick estão conversando. Chegue perto: o Bento vai falar do irmão. Aperte o balão em destaque para ver a história."),
		"action": "story", "button": TranslationServer.translate("Ouvir a conversa"), "room": "", "story": name}
