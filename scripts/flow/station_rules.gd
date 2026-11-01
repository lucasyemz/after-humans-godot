## Regras da Estação Raiz e da campanha entre expedições, sem cena: port de FAHStationRooms, FAHStationEconomy,
## FAHStationCivilians, FAHNightRestRules, FAHShelterRules, FAHRouteFocus e da partida e da volta de FAHGameFlowRules
## (Source/AfterHumans/Flow). Os números são os aprovados pelo Lucas na Unreal (Docs/Systems/station-*.md).
##
## Estado (na campanha):
##   station: {water, rooms {id: nível}, cycle_number, last_cycle_expedition_id, last_cycle {...}, residents [],
##             candidate_queue [], hungry_civilians [], completed_requests [], train {phase, candidate_id,
##             expedition_id, accepted, recruit {}, next {}, trades {}}, train_dry (voltas sem ninguém no trem),
##             last_return {...}}
##   night: {phase ("none", "planning", "dawn"), number, expedition_id, participants [], watch_hero_id, event_id,
##           results [{hero_id, watch, fed, hp_recovered, instinct_reduced}], supplies_consumed, thirsty}
##   inventory.items["item_suprimentos"]: os suprimentos do refúgio (a comida da noite e da Cantina).
## As ações que o jogador escolhe devolvem "" quando valem, ou o motivo da recusa (o texto da tela).
class_name AHStationRules
extends RefCounted

const J := preload("res://scripts/flow/journey_rules.gd")

const SUPPLIES := "item_suprimentos"

# ---------------------------------------------------------------- cômodos (#70)

const CANTEEN := "canteen"
const DEPOT := "depot"
const PREPARATION := "preparation"
const CHARACTERS := "characters"
const DORMITORY := "dormitory"
const FORGE := "forge"
const RESEARCH := "research"
const BAR := "bar"
## A Enfermaria (#121): os leitos dos caídos (#118). O custo de cada nível fica em data/recovery.json.
const INFIRMARY := "infirmary"
## Cômodos: básico (nível 1 desde o começo), nível máximo e o custo de cada nível (do N ao N+1). Sem custo, a
## recuperação chega numa próxima fase do jogo. A Forja é o piloto com dois níveis.
## A grade (#186, AHStationGrid): slots, as vagas de 6 m que o cômodo ocupa (0: fora da grade, na plataforma); build, o
## nível em que ele entra numa vaga (construir). A Cantina e o Depósito de nível 1 são o fogareiro e os caixotes da
## plataforma; construídos, são o nível 2.
const ROOMS := [
	{"id": CANTEEN, "name": "Cantina", "basic": true, "max_level": 2, "costs": [], "data_costs": "canteen_level_%d", "data_table": "station_grid", "slots": 2, "build": 2},
	{"id": DEPOT, "name": "Depósito", "basic": true, "max_level": 2, "costs": [{}, {"scrap": 5, "fragments": 1}], "slots": 1, "build": 2},
	# O nível 2 abre as missões solo (#183).
	{"id": PREPARATION, "name": "Preparação", "basic": true, "max_level": 2, "costs": [{}, {"scrap": 4, "fragments": 1}], "slots": 0, "build": 0},
	# O Alojamento cresce (#119): cada nível comporta mais heróis (data/hero-jobs.json, limit_heroes e o custo).
	{"id": CHARACTERS, "name": "Alojamento", "basic": true, "max_level": 4, "costs": [], "data_costs": "characters_level_%d", "data_table": "hero_jobs", "slots": 1, "build": 1},
	{"id": FORGE, "name": "Forja", "basic": false, "max_level": 2, "costs": [{"scrap": 4, "fragments": 0}, {"scrap": 6, "fragments": 2}], "slots": 2, "build": 1},
	{"id": RESEARCH, "name": "Centro de Pesquisa", "basic": false, "max_level": 1, "costs": [{"scrap": 3, "fragments": 2}], "slots": 2, "build": 1},
	# O Dormitório existe desde o começo, sem camas: no nível 1 a equipe dorme no chão; os beliches são a melhoria (nível 2,
	# o custo em data/hero-jobs.json). Decisão do Lucas (28/10, #176).
	{"id": DORMITORY, "name": "Dormitório", "basic": true, "max_level": 2, "costs": [], "data_costs": "dormitory_level_%d", "data_table": "hero_jobs", "slots": 2, "build": 1},
	# O Bar tem custo para ser recuperado (#176; o número é proposta).
	{"id": BAR, "name": "Bar", "basic": false, "max_level": 1, "costs": [{"scrap": 4, "fragments": 1}], "slots": 1, "build": 1},
	{"id": INFIRMARY, "name": "Enfermaria", "basic": false, "max_level": 2, "costs": [], "data_costs": "infirmary_level_%d", "slots": 2, "build": 1},
]
const RELIC_COST_BASE := 3
const RELIC_COST_UPGRADED := 2

# ---------------------------------------------------------------- economia (#67)

const INITIAL_WATER := 6
const WATER_PER_RETURNING_HERO := 1
## Coletor de água: funciona sem energia, para a água nunca travar tudo.
const COLLECTOR_WATER := 2
const CANTEEN_FOOD := 2
const BASE_POWER_CAPACITY := 3
## Sem água, quem dorme reduz menos instinto.
const THIRST_INSTINCT_PENALTY := 10
const DEPOT_CAPACITY := 12
const DEPOT_CAPACITY_UPGRADED := 20

# ---------------------------------------------------------------- civis (#72)

const DORA := "civil_dora"
const OTTO := "civil_otto"
const CORA := "civil_cora"
const DORA_FOOD := 2
const OTTO_POWER := 1
const OTTO_SCRAP_DISCOUNT := 1
const CORA_FRAGMENTS := 1
const CORA_RESEARCH_POWER := 1
const REQUEST_BONUS := 1
const CIVILIANS := [
	{"id": DORA, "name": "Dora", "species": "Texugo", "role": "Cozinheira", "trait": "Prática, evita desperdício.",
		"need": "Quer recuperar um caderno de receitas esquecido numa mercearia abandonada.",
		"benefit": "Na Cantina com energia, produz mais 2 suprimentos por dia.",
		"drawback": "Cozinhar gasta água: bebe 2 por dia.",
		"request_item": "o caderno de receitas", "request_reward": "a Cantina rende mais 1 suprimento por dia",
		"food": 1, "water": 2, "room": CANTEEN},
	{"id": OTTO, "name": "Otto", "species": "Castor", "role": "Técnico", "trait": "Paciente, testa antes de improvisar.",
		"need": "Quer recuperar a maleta da equipe ferroviária.",
		"benefit": "Mantém o gerador: mais 1 de capacidade de energia. Recuperar e melhorar cômodos custa 1 sucata a menos.",
		"drawback": "Trabalho pesado: come 2 suprimentos por dia.",
		"request_item": "a maleta da equipe ferroviária", "request_reward": "mais 1 de capacidade de energia",
		"food": 2, "water": 1, "room": FORGE},
	{"id": CORA, "name": "Cora", "species": "Gambá", "role": "Pesquisadora", "trait": "Metódica e cética.",
		"need": "Quer recuperar registros de monitoramento para comparar a água local.",
		"benefit": "Com a Pesquisa recuperada e ligada, traz 1 fragmento por dia.",
		"drawback": "Equipamentos ligados o tempo todo: a Pesquisa gasta 1 de energia a mais.",
		"request_item": "os registros de monitoramento", "request_reward": "mais 1 fragmento por dia",
		"food": 1, "water": 1, "room": RESEARCH},
]

# ---------------------------------------------------------------- noite e refúgio

const SUPPLY_COST_SEEDS := 2
const MAX_ROSTER := 12
## O preço de antes do + RECRUTAR; o do trem (#122) fica em data/recruitment.json (recruit.Cost).
const RECRUIT_COST := 10
const TRAUMA_COST := 5
## Uma equipe leva no máximo dois animais da mesma classe.
const MAX_PER_CLASS := 2
## Suprimentos comprados na partida, além dos 4 de graça (FoodCost).
const FOOD_COST := 2

# ---------------------------------------------------------------- foco da rota (#73)

const FOCUS_WATER := "water"
const FOCUS_PARTS := "parts"
const FOCUS_PROVISIONS := "provisions"
## Foco: loja (0 mercearia, 1 oficina, 2 cinema), ponto da casa, quanto rende e o civil do pedido.
const FOCI := [
	{"id": FOCUS_WATER, "shop": 0, "spot": 1, "amount": 4, "civilian": ""},
	{"id": FOCUS_PARTS, "shop": 1, "spot": 2, "amount": 3, "civilian": ""},
	{"id": FOCUS_PROVISIONS, "shop": 2, "spot": 1, "amount": 3, "civilian": ""},
	{"id": "request_civil_dora", "shop": 0, "spot": 2, "amount": 1, "civilian": DORA},
	{"id": "request_civil_otto", "shop": 1, "spot": 1, "amount": 1, "civilian": OTTO},
	{"id": "request_civil_cora", "shop": 2, "spot": 0, "amount": 1, "civilian": CORA},
]


# ================================================================ estado

## O que uma campanha nova traz da Estação: só os cômodos básicos, a água inicial e a fila dos civis.
static func init_new_campaign(campaign: Dictionary) -> void:
	var rooms := {}
	for room in ROOMS:
		rooms[room.id] = 1 if room.basic else 0
	campaign.station = _station_defaults()
	campaign.station.rooms = rooms
	# A grade (#186): o Dormitório, o Alojamento e a Forja parada no 1º subsolo; o resto soterrado.
	AHStationGrid.init_new(campaign)
	campaign.station.candidate_queue = CIVILIANS.map(func(c): return c.id)
	campaign.night = _night_defaults()
	campaign.pending_offers = []
	campaign.completed_expeditions = 0
	campaign.last_completed_expedition_id = ""
	campaign.last_returned_expedition_id = ""
	campaign.unlocked_skins = []
	_grant_start_skins(campaign)


## Save anterior à Estação (fase 2): completa o que falta. Como na Unreal (MigrateLegacy), um save sem cômodos fica
## com todos recuperados, como o jogador já os usava. Idempotente.
static func migrate(campaign: Dictionary) -> void:
	# A espécie no indivíduo (#189): quem é de um save de antes fica com a padrão da classe (o rato, Guaxinim).
	for entry in campaign.get("roster", []):
		AHSpecies.ensure(entry)
	var station = campaign.get("station")
	if typeof(station) != TYPE_DICTIONARY or not station.has("rooms"):
		var rooms := {}
		for room in ROOMS:
			rooms[room.id] = 1
		var fresh := _station_defaults()
		fresh.rooms = rooms
		fresh.candidate_queue = CIVILIANS.map(func(c): return c.id)
		campaign.station = fresh
	else:
		var defaults := _station_defaults()
		for key in defaults:
			if not station.has(key):
				station[key] = defaults[key]
	if typeof(campaign.get("night")) != TYPE_DICTIONARY:
		campaign.night = _night_defaults()
	for key in ["pending_offers", "researched_skills"]:
		if typeof(campaign.get(key)) != TYPE_ARRAY:
			campaign[key] = []
	for key in ["completed_expeditions"]:
		campaign[key] = int(campaign.get(key, 0))
	for key in ["last_completed_expedition_id", "last_returned_expedition_id"]:
		campaign[key] = String(campaign.get(key, ""))
	if typeof(campaign.inventory.get("items")) != TYPE_DICTIONARY:
		campaign.inventory.items = {}
	# Saves anteriores à arte dos recrutas (#32): o fundador continua com a dele; o recruta ganha a variação da classe.
	for entry in campaign.get("roster", []):
		if not entry.has("art_variant"):
			entry.art_variant = _least_used_variant(campaign, String(entry.get("class_id", ""))) if is_recruit(String(entry.get("id", ""))) else ""
	# As sete habilidades (#259): os campos novos; o que um save editado traz e não vale volta ao padrão.
	AHHeroSkills.migrate(campaign)
	AHCampSkills.migrate(campaign)
	# As skins (#138): o herói de antes veste a padrão; a campanha ganha a lista das liberadas, com as do começo.
	for entry in campaign.get("roster", []):
		if String(entry.get("skin_id", "")) == "":
			entry.skin_id = AHSkins.DEFAULT
	if typeof(campaign.get("unlocked_skins")) != TYPE_ARRAY:
		campaign.unlocked_skins = []
	_grant_start_skins(campaign, true)
	# Ninguém morre (#118): o memorial dos saves antigos volta em recuperação.
	_migrate_fallen(campaign)
	_migrate_posts(campaign)
	# As missões solo (#183): o save de antes ganha a semente (tirada do elenco: a mesma a cada carga).
	AHSideMissions.state(campaign)
	# O trem de antes do #122 não tem o recruta: quem espera é um civil.
	if typeof(campaign.station.train.get("recruit")) != TYPE_DICTIONARY:
		campaign.station.train.recruit = {}
	# O trem de antes do #182 traz um só.
	if typeof(campaign.station.train.get("next")) != TYPE_DICTIONARY:
		campaign.station.train.next = {}
	# E sem o Mercador (#182, parte 2), nenhuma troca feita.
	if typeof(campaign.station.train.get("trades")) != TYPE_DICTIONARY:
		campaign.station.train.trades = {}
	campaign.station.train_dry = int(campaign.station.get("train_dry", 0))
	# A grade (#186): os saves de antes ganham a planta herdada, sem nenhum cômodo construído soterrado.
	AHStationGrid.migrate(campaign)
	# "departing" é só a animação do trem saindo (4 s na tela). Um save gravado nesse meio (o jogo fechou) abriria com o
	# trem partindo para sempre: a Preparação ficava bloqueada e a plataforma sem botão.
	finish_departure(campaign)


static func _station_defaults() -> Dictionary:
	return {
		"water": INITIAL_WATER, "rooms": {}, "cycle_number": 0, "last_cycle_expedition_id": "", "last_cycle": {},
		"residents": [], "candidate_queue": [], "hungry_civilians": [], "completed_requests": [],
		"train": _train_defaults(), "train_dry": 0, "last_return": {},
		# A escada da história (#64): as fases cujo evento de história já apareceu e as cuja linha "O que a equipe viu"
		# já saiu no relatório (uma vez por campanha).
		"story_events": [], "story_reports": [],
		# As missões solo (#183): o quadro do dia e os relatórios de quem voltou.
		# A semente nasce com a campanha (create_initial, ou AHSideMissions.state na migração).
		"side_missions": {"day": -1, "board": [], "reports": []},
		# As tirinhas já vistas pelo balão interativo da Estação viva (#207): saem do Próximo passo.
		"comics_seen": [],
	}


static func _night_defaults() -> Dictionary:
	return {"phase": "none", "number": 0, "expedition_id": "", "participants": [], "watch_hero_id": "", "event_id": "", "event": {}, "conditions": [],
		"results": [], "supplies_consumed": 0, "thirsty": false}


## recruit: o animal que o trem trouxe (#122), ainda fora do elenco ({class_id, display_name, perks, art_variant,
## origin}); vazio quando quem espera é um civil.
## next (#182): o segundo animal quando o trem traz dois ({candidate_id, recruit}, ou {}); decidido o primeiro, ele passa
## a ser quem espera.
## trades (#182, parte 2): com o Mercador na plataforma (candidate_id MERCHANT), quantas vezes cada troca já saiu nesta
## visita ({id da troca: vezes}).
static func _train_defaults() -> Dictionary:
	return {"phase": "none", "candidate_id": "", "expedition_id": "", "accepted": false, "recruit": {}, "next": {}, "trades": {}}


static func in_refuge(campaign: Dictionary) -> bool:
	var session: Dictionary = campaign.get("session", {})
	return session.get("expedition") == null and session.get("screen", "shelter") == "shelter"


static func hero(campaign: Dictionary, hero_id: String):
	for entry in campaign.roster:
		if entry.id == hero_id:
			return entry
	return null


static func living(campaign: Dictionary) -> Array:
	return campaign.roster.filter(func(h): return h.alive)


# ================================================================ estoque do refúgio

static func quantity(campaign: Dictionary, item: String) -> int:
	match item:
		"seeds", "scrap", "fragments", "bandages":
			return maxi(0, int(campaign.inventory.get(item, 0)))
	return maxi(0, int(campaign.inventory.items.get(item, 0)))


## Ajuste com sinal (nunca abaixo de zero). Devolve quanto mudou de fato.
static func adjust(campaign: Dictionary, item: String, delta: int) -> int:
	var before := quantity(campaign, item)
	var after := maxi(0, before + delta)
	match item:
		"seeds", "scrap", "fragments", "bandages":
			campaign.inventory[item] = after
		_:
			if after > 0:
				campaign.inventory.items[item] = after
			else:
				campaign.inventory.items.erase(item)
	return after - before


## Gasto exato: recusa quantidade inválida ou estoque curto, sem mudar nada.
static func consume(campaign: Dictionary, item: String, amount: int = 1) -> bool:
	if amount <= 0 or quantity(campaign, item) < amount:
		return false
	adjust(campaign, item, -amount)
	return true


# ================================================================ cômodos

static func room_def(room_id: String) -> Dictionary:
	for room in ROOMS:
		if room.id == room_id:
			return room
	return {}


static func room_level(campaign: Dictionary, room_id: String) -> int:
	var room := room_def(room_id)
	if room.is_empty():
		return 1
	var level := int(campaign.get("station", {}).get("rooms", {}).get(room_id, 0))
	# Básico nunca fica abaixo de 1, mas pode ser melhorado (Depósito).
	return clampi(level, 1 if room.basic else 0, room.max_level)


static func room_available(campaign: Dictionary, room_id: String) -> bool:
	return room_level(campaign, room_id) >= 1


## Custo do próximo nível ({scrap, fragments}), já com o desconto do Otto; {} se não há próximo nível com custo.
static func next_level_cost(campaign: Dictionary, room_id: String) -> Dictionary:
	var room := room_def(room_id)
	var current := room_level(campaign, room_id)
	var costs := room_costs(room)
	if room.is_empty() or current >= room.max_level or current >= costs.size() or costs[current].is_empty():
		return {}
	var cost: Dictionary = costs[current].duplicate()
	if civilian_working(campaign, OTTO):
		cost.scrap = maxi(0, int(cost.get("scrap", 0)) - OTTO_SCRAP_DISCOUNT)
	return cost


## O custo de cada nível: o da tabela ROOMS ou o de data/ (a Enfermaria em recovery.json, o Alojamento em hero-jobs.json).
static func room_costs(room: Dictionary) -> Array:
	if not room.has("data_costs"):
		return room.get("costs", [])
	var out: Array = []
	for level in range(1, int(room.max_level) + 1):
		var row = GameData.row(String(room.get("data_table", "recovery")), String(room.data_costs) % level)
		out.append({} if row == null else {"scrap": int(row.get("Scrap", 0)), "fragments": int(row.get("Fragments", 0))})
	return out


## "" se pode subir agora; senão, o que falta.
static func upgrade_block(campaign: Dictionary, room_id: String) -> String:
	var cost := next_level_cost(campaign, room_id)
	if cost.is_empty():
		var room := room_def(room_id)
		return TranslationServer.translate("A recuperação deste cômodo chega numa próxima fase.") if not room.is_empty() and room_level(campaign, room_id) < room.max_level \
			else TranslationServer.translate("Este cômodo já está no nível máximo.")
	# A grade (#186): construir pede uma vaga livre do tamanho do cômodo.
	var space := AHStationGrid.space_block(campaign, room_id)
	if space != "":
		return space
	var scrap := quantity(campaign, "scrap")
	var fragments := quantity(campaign, "fragments")
	if scrap < int(cost.get("scrap", 0)) or fragments < int(cost.get("fragments", 0)):
		return TranslationServer.translate("Faltam %s.") % cost_text({"scrap": maxi(0, int(cost.get("scrap", 0)) - scrap), "fragments": maxi(0, int(cost.get("fragments", 0)) - fragments)})
	return ""


## Sobe um nível e cobra uma vez. from_level é o nível que o jogador viu: clique repetido não compra o seguinte.
## No nível de construir (#186), o cômodo entra na vaga dada (spot, a da esquerda) ou na primeira vaga livre onde cabe.
static func upgrade_room(campaign: Dictionary, room_id: String, from_level: int, spot: String = "") -> String:
	if room_level(campaign, room_id) != from_level:
		return TranslationServer.translate("Este cômodo já mudou de nível.")
	var block := upgrade_block(campaign, room_id)
	if block != "":
		return block
	var place := ""
	if AHStationGrid.needs_place(campaign, room_id):
		if spot != "" and not AHStationGrid.spot_fits(campaign, room_id, spot):
			return _not_fit(room_id)
		place = spot if spot != "" else AHStationGrid.free_spots(campaign, room_id)[0]
	var cost := next_level_cost(campaign, room_id)
	adjust(campaign, "scrap", -int(cost.get("scrap", 0)))
	adjust(campaign, "fragments", -int(cost.get("fragments", 0)))
	campaign.station.rooms[room_id] = from_level + 1
	if place != "":
		AHStationGrid.place(campaign, room_id, place)
	# A Enfermaria recuperada ou melhorada: quem já espera no Dormitório vai na hora para os leitos novos.
	if room_id == INFIRMARY:
		_fill_beds(campaign)
	return ""


## Construir numa vaga livre (#186): o cômodo cujo próximo nível é o de entrar na grade, na vaga escolhida (a da
## esquerda, no duplo). Devolve "" ou o motivo.
static func build_room(campaign: Dictionary, room_id: String, spot: String) -> String:
	if not AHStationGrid.needs_place(campaign, room_id):
		return TranslationServer.translate("Este cômodo já tem lugar na Estação.")
	if not AHStationGrid.spot_fits(campaign, room_id, spot):
		return _not_fit(room_id)
	return upgrade_room(campaign, room_id, room_level(campaign, room_id), spot)


## "O Centro de Pesquisa não cabe nessa vaga."
static func _not_fit(room_id: String) -> String:
	var name := room_the(room_id)
	return TranslationServer.translate("%s não cabe nessa vaga.") % (name.left(1).to_upper() + name.substr(1))


## "a Cantina", "o Depósito": o cômodo com o artigo (ROOM_ARTICLE).
static func room_the(room_id: String) -> String:
	return TranslationServer.translate(ROOM_ARTICLE.get(room_id, "")) + TranslationServer.translate(room_def(room_id).get("name", ""))


static func relic_cost(campaign: Dictionary) -> int:
	return RELIC_COST_UPGRADED if room_level(campaign, FORGE) >= 2 else RELIC_COST_BASE


static func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	var scrap := int(cost.get("scrap", 0))
	var fragments := int(cost.get("fragments", 0))
	if scrap > 0:
		parts.append("%d %s" % [scrap, TranslationServer.translate("sucata") if scrap == 1 else TranslationServer.translate("sucatas")])
	if fragments > 0:
		parts.append("%d %s" % [fragments, TranslationServer.translate("fragmento") if fragments == 1 else TranslationServer.translate("fragmentos")])
	return TranslationServer.translate("sem custo") if parts.is_empty() else TranslationServer.translate(" e ").join(parts)


## O papel de cada cômodo em uma linha (os textos do AHShelterStation da Unreal), para o cartão da seleção.
const ROOM_ROLES := {
	CHARACTERS: "Conhecer e acompanhar os moradores do abrigo.",
	CANTEEN: "Preparo e consumo de alimentos.",
	BAR: "Um lugar para conversar e fazer uma pausa.",
	DORMITORY: "Descanso e abrigo para a comunidade.",
	FORGE: "Reparar e adaptar equipamentos recuperados.",
	DEPOT: "Guardar e organizar suprimentos.",
	RESEARCH: "Analisar materiais e organizar informações recuperadas.",
	PREPARATION: "Organizar a equipe e os suprimentos antes de sair.",
}


## A barra do alto da Estação (o cabeçalho do AHRefugeWidget): Comida, Água e Energia com o valor e o que acontece na
## volta. Cada item: {id, label, icon, value, note, warn, tip}. A noite pendente manda no texto da comida.
static func vitals(campaign: Dictionary, returning: int = 4) -> Array:
	var f := forecast(campaign, returning)
	var food: int = f.food
	var planning: bool = campaign.night.phase == "planning"
	var sleepers := 0
	if planning:
		for hero_id in campaign.night.participants:
			var entry = hero(campaign, hero_id)
			if entry != null and entry.alive and hero_id != campaign.night.watch_hero_id:
				sleepers += 1
	var food_short: bool = sleepers > food if planning else food + f.food_produced - f.food_civilians - f.food_spoiled < f.food_night_need
	var food_note := ""
	if planning:
		food_note = (TranslationServer.translate("! Faltam %d nesta noite") % (sleepers - food)) if food_short else TranslationServer.translate("Abastecida · demanda %d") % sleepers
	elif food > f.food_capacity:
		food_note = TranslationServer.translate("! %d acima de %d") % [food - f.food_capacity, f.food_capacity]
	elif food_short:
		food_note = TranslationServer.translate("! Falta na próxima expedição")
	else:
		food_note = TranslationServer.translate("Próxima expedição: %d") % f.food_after_night
	var power_short: bool = not f.unpowered_rooms.is_empty()
	return [
		{"id": "food", "label": TranslationServer.translate("COMIDA"), "icon": "lobby-food", "value": TranslationServer.translate("%d / %d suprimentos") % [food, f.food_capacity],
			"note": food_note, "warn": food_short or food > f.food_capacity,
			"tip": TranslationServer.translate("Estoque e capacidade do Depósito. Na próxima expedição, sem saque: +%d da Cantina, %d para os moradores, %d estragam, %d para a noite; restam %d.") % [
				f.food_produced, f.food_civilians, f.food_spoiled, f.food_night_need, f.food_after_night]},
		{"id": "water", "label": TranslationServer.translate("ÁGUA"), "icon": "lobby-water", "value": TranslationServer.translate("%d em estoque") % f.water,
			"note": TranslationServer.translate("! Falta na próxima expedição") if f.thirsty else TranslationServer.translate("Próxima expedição: %d") % f.water_after, "warn": f.thirsty,
			"tip": TranslationServer.translate("Na próxima expedição, sem saque: o coletor repõe %d e a equipe e os moradores bebem %d; restam %d. Sem água, o descanso reduz menos instinto.") % [
				f.water_produced, f.water_consumed, f.water_after]},
		{"id": "power", "label": TranslationServer.translate("ENERGIA"), "icon": "lobby-energy", "value": TranslationServer.translate("%d / %d em uso") % [f.power_used, f.power_capacity],
			"note": (TranslationServer.translate("! %d %s sem energia") % [f.unpowered_rooms.size(), TranslationServer.translate("sala") if f.unpowered_rooms.size() == 1 else TranslationServer.translate("salas")]) if power_short \
				else "%d %s" % [maxi(0, f.power_capacity - f.power_used), TranslationServer.translate("livre") if f.power_capacity - f.power_used == 1 else TranslationServer.translate("livres")],
			"warn": power_short, "tip": TranslationServer.translate("Os cômodos ligados gastam energia; sem ela, param.")},
	]


## O que o cômodo faz no nível dado (texto da tela). A Pesquisa, o Depósito melhorado e a Forja também dizem o que leem
## no Mapa da Rede (#87): o Plano e o Próximo passo mostram o motivo de recuperar.
static func room_benefit(room_id: String, level: int) -> String:
	var text := _room_benefit(room_id, level)
	# O nível que passa a ler: o Depósito melhorado (2); a Pesquisa e a Forja recuperadas (1, e só ele: melhorar a Forja
	# não lê mais).
	var reads := level == (2 if room_id == DEPOT else 1) and [RESEARCH, DEPOT, FORGE].has(room_id)
	return text + " " + AHNetworkRadar.room_reading(room_id) if reads else text


static func _room_benefit(room_id: String, level: int) -> String:
	match room_id:
		FORGE:
			if level <= 0:
				return TranslationServer.translate("Oficina vazia. Recuperada, fabrica relíquias e gasta 1 de energia.")
			return TranslationServer.translate("Fabrica relíquias por 3 sucatas. Gasta 1 de energia.") if level == 1 else TranslationServer.translate("Bancada melhorada: relíquias por 2 sucatas.")
		RESEARCH:
			return TranslationServer.translate("Laboratório vazio. Recuperado, libera as melhorias de classe e gasta 1 de energia.") if level <= 0 \
				else TranslationServer.translate("Melhorias de classe com fragmentos. Gasta 1 de energia.")
		DORMITORY:
			# Sem camas no nível 1 (a equipe dorme no chão); os beliches chegam com a melhoria (#176).
			if level <= 1:
				return TranslationServer.translate("Sem camas: a equipe dorme no chão depois de cada expedição. Com os beliches, cabem %d ajudantes.") % helper_limit_at(2)
			return TranslationServer.translate("Beliches de ferro: a equipe dorme neles depois de cada expedição. Cabem %d ajudantes.") % helper_limit_at(level)
		BAR:
			return TranslationServer.translate("Salão vazio. Recuperado, vira um lugar para conversar e fazer uma pausa.") if level <= 0 else TranslationServer.translate("Um lugar para conversar e fazer uma pausa.")
		CANTEEN:
			if level >= 2:
				return TranslationServer.translate("Cantina construída: com energia, produz %d suprimentos por dia.") % (CANTEEN_FOOD + int(AHStationGrid.rule("canteen_level_2").get("Food", 1)))
			return TranslationServer.translate("Com energia, produz 2 suprimentos por dia.")
		DEPOT:
			return TranslationServer.translate("Guarda até 12 suprimentos; o excesso estraga a cada dia.") if level <= 1 else TranslationServer.translate("Prateleiras extras: guarda até 20.")
		PREPARATION:
			# O nível 2 abre as missões solo (#183).
			return TranslationServer.translate("Escolher a fase, a equipe, o foco da rota e os suprimentos da partida.") if level <= 1 \
				else TranslationServer.translate("Escolher a partida e mandar heróis em missões solo.")
		CHARACTERS:
			# Cada nível comporta mais heróis (#119).
			return TranslationServer.translate("Elenco, treino, trauma e relíquias. Comporta %d heróis.") % hero_limit_at(level)
		INFIRMARY:
			if level <= 0:
				return TranslationServer.translate("Sala de primeiros socorros da estação, com as macas tombadas. Recuperada, os caídos se recuperam mais rápido num leito.")
			return TranslationServer.translate("As macas do antigo posto de primeiros socorros viraram leitos. %d leitos: no leito, quem caiu volta em %d dias, e cada curativo tira %d.") % [
				infirmary_beds_at(level), int(recovery_rule("infirmary").get("Days", 2)), int(recovery_rule("bandage").get("Days", 1))]
	return ""


# ================================================================ economia

## Salas que gastam energia, em ordem de prioridade, e quanto cada uma gasta.
static func powered_rooms(campaign: Dictionary) -> Array:
	# Com a Cora, os equipamentos da Pesquisa ficam ligados: 1 de energia a mais.
	var research_power := 1 + (CORA_RESEARCH_POWER if is_resident(campaign, CORA) else 0)
	return [[CANTEEN, 1], [RESEARCH, research_power], [FORGE, 1]]


static func power_capacity(campaign: Dictionary) -> int:
	var bonus := 0
	if civilian_working(campaign, OTTO):
		bonus = OTTO_POWER + (REQUEST_BONUS if has_completed_request(campaign, OTTO) else 0)
	return BASE_POWER_CAPACITY + bonus


## Salas com energia agora (cabem na capacidade, pela prioridade). Cômodo vazio não liga nem gasta.
static func running_rooms(campaign: Dictionary) -> Array:
	var running: Array = []
	var left := power_capacity(campaign)
	for room in powered_rooms(campaign):
		if not room_available(campaign, room[0]):
			continue
		if room[1] <= left:
			running.append(room[0])
			left -= room[1]
	return running


## O que a Cantina rende sozinha, com energia: o fogareiro da plataforma (nível 1) ou a Cantina construída (#186).
static func canteen_food(campaign: Dictionary) -> int:
	return CANTEEN_FOOD + (int(AHStationGrid.rule("canteen_level_2").get("Food", 1)) if room_level(campaign, CANTEEN) >= 2 else 0)


## Faixas do estoque visível: 0 vazio, 1 (1-3), 2 (4-7), 3 (8-11), 4 (12+).
static func supply_band(supplies: int) -> int:
	return 0 if supplies <= 0 else 1 if supplies <= 3 else 2 if supplies <= 7 else 3 if supplies <= 11 else 4


static func supply_capacity(campaign: Dictionary) -> int:
	return DEPOT_CAPACITY_UPGRADED if room_level(campaign, DEPOT) >= 2 else DEPOT_CAPACITY


## O que o próximo ciclo da Estação faria, pela mesma conta do RunCycle (a tela mostra antes da partida).
static func forecast(campaign: Dictionary, returning: int) -> Dictionary:
	returning = maxi(0, returning)
	var running := running_rooms(campaign)
	var f := {"power_capacity": power_capacity(campaign), "power_used": 0, "unpowered_rooms": []}
	for room in powered_rooms(campaign):
		if running.has(room[0]):
			f.power_used += room[1]
		elif room_available(campaign, room[0]):
			f.unpowered_rooms.append(room[0])
	f.food = quantity(campaign, SUPPLIES)
	var dora_food := DORA_FOOD + (REQUEST_BONUS if has_completed_request(campaign, DORA) else 0)
	f.food_produced = (canteen_food(campaign) + (dora_food if civilian_working(campaign, DORA) else 0)) if running.has(CANTEEN) else 0
	f.food_night_need = returning
	f.civilians = resident_count(campaign)
	f.water = maxi(0, int(campaign.station.water))
	f.water_produced = COLLECTOR_WATER
	var share := allocate(campaign, f.food + f.food_produced, f.water + f.water_produced)
	f.food_civilians = share.food
	f.hungry_civilians = share.hungry
	f.food_capacity = supply_capacity(campaign)
	# O que passa da capacidade estraga no ciclo, antes da noite.
	f.food_spoiled = maxi(0, f.food + f.food_produced - f.food_civilians - f.food_capacity)
	f.food_after_night = maxi(0, f.food + f.food_produced - f.food_civilians - f.food_spoiled - f.food_night_need)
	f.fragments_produced = 0
	if civilian_working(campaign, CORA) and running.has(RESEARCH):
		f.fragments_produced = CORA_FRAGMENTS + (REQUEST_BONUS if has_completed_request(campaign, CORA) else 0)
	f.water_consumed = returning * WATER_PER_RETURNING_HERO + share.water
	f.thirsty = f.water + f.water_produced < f.water_consumed
	f.water_after = maxi(0, f.water + f.water_produced - f.water_consumed)
	return f


## Aplica o ciclo da expedição uma vez só: produção, consumo, relatório e a sede na noite pendente dessa volta.
static func run_cycle(campaign: Dictionary, expedition_id: String, returning: int) -> bool:
	var station: Dictionary = campaign.station
	if expedition_id == "" or station.last_cycle_expedition_id == expedition_id:
		return false
	var f := forecast(campaign, returning)
	adjust(campaign, SUPPLIES, f.food_produced - f.food_civilians - f.food_spoiled)
	adjust(campaign, "fragments", f.fragments_produced)
	station.water = f.water_after
	station.last_cycle_expedition_id = expedition_id
	station.cycle_number = int(station.cycle_number) + 1
	station.hungry_civilians = f.hungry_civilians.duplicate()
	# Quem chegou ao dia da volta resolve a missão solo (#183).
	var missions := AHSideMissions.on_new_day(campaign)
	station.last_cycle = {
		"number": station.cycle_number, "expedition_id": expedition_id, "food_produced": f.food_produced,
		"food_spoiled": f.food_spoiled, "food_civilians": f.food_civilians, "fragments_produced": f.fragments_produced,
		"hungry_civilians": f.hungry_civilians.duplicate(), "water_produced": f.water_produced,
		"water_consumed": mini(f.water_consumed, f.water + f.water_produced), "thirsty": f.thirsty,
		"power_used": f.power_used, "power_capacity": f.power_capacity, "missions": missions,
	}
	if campaign.night.expedition_id == expedition_id:
		campaign.night.thirsty = f.thirsty
	return true


# ================================================================ civis

static func civilian(civilian_id: String) -> Dictionary:
	for entry in CIVILIANS:
		if entry.id == civilian_id:
			return entry
	return {}


static func is_resident(campaign: Dictionary, civilian_id: String) -> bool:
	return campaign.station.residents.has(civilian_id)


static func has_completed_request(campaign: Dictionary, civilian_id: String) -> bool:
	return campaign.station.completed_requests.has(civilian_id)


static func request_open(campaign: Dictionary, civilian_id: String) -> bool:
	return is_resident(campaign, civilian_id) and not has_completed_request(campaign, civilian_id)


## Mora aqui e comeu e bebeu no último ciclo: só assim o ponto forte vale (o ponto fraco vale sempre).
static func civilian_working(campaign: Dictionary, civilian_id: String) -> bool:
	return is_resident(campaign, civilian_id) and not campaign.station.hungry_civilians.has(civilian_id)


static func resident_count(campaign: Dictionary) -> int:
	return campaign.station.residents.size()


## Divide a comida e a água entre os moradores, na ordem em que chegaram. Quem não recebe tudo fica com fome.
static func allocate(campaign: Dictionary, food: int, water: int) -> Dictionary:
	var out := {"food": 0, "water": 0, "hungry": []}
	for civilian_id in campaign.station.residents:
		var entry := civilian(civilian_id)
		if entry.is_empty():
			continue
		var eats := clampi(food - out.food, 0, entry.food)
		var drinks := clampi(water - out.water, 0, entry.water)
		out.food += eats
		out.water += drinks
		if eats < entry.food or drinks < entry.water:
			out.hungry.append(civilian_id)
	return out


static func visit_pending(campaign: Dictionary) -> bool:
	# O trem das missões solo (#183) também: quem volta delas chega nele.
	return campaign.station.train.phase != "none" or AHSideMissions.train_pending(campaign)


## Um número do trem (#122) em data/recruitment.json.
static func train_rule(name: String, field: String, fallback: int) -> int:
	var row = GameData.row("recruitment", name)
	return int(row.get(field, fallback)) if row != null else fallback


## A chance (em %) de o trem trazer alguém na próxima volta: a base e mais um pouco a cada volta sem ninguém.
static func train_chance(campaign: Dictionary) -> int:
	return mini(train_rule("train", "ChanceMax", 90),
		train_rule("train", "Chance", 40) + train_rule("train", "ChanceStep", 15) * int(campaign.station.get("train_dry", 0)))


## As classes que podem chegar no trem: as liberadas e com arte de luta (quem não tem fica fora, como na partida).
static func train_classes(campaign: Dictionary) -> Array:
	# Com o Alojamento cheio, o trem não traz animal (#182): ele não teria onde ficar, ia embora na partida, e o trem
	# parecia parado. Sem variação livre da classe, também não (nenhum personagem repetido).
	if heroes_full(campaign):
		return []
	return campaign.unlocked_classes.filter(func(id): return GameData.row("classes", id) != null \
		and not AHCombatArena.hero_art_of("hero_%s_0" % id).is_empty() and not free_art_variants(campaign, id).is_empty())


## Na volta (#122): às vezes o trem traz alguém, às vezes não. Quem vem: um animal de uma classe liberada, o próximo
## civil da fila ou o Mercador (#182, parte 2). O sorteio sai da expedição (a mesma volta traz sempre o mesmo), uma vez
## por expedição.
## force ("hero", "civilian" ou "merchant", a barra de Admin): alguém chega, desse tipo quando houver.
static func train_on_return(campaign: Dictionary, expedition_id: String, force: String = "") -> bool:
	var station: Dictionary = campaign.station
	if expedition_id == "" or station.train.phase != "none" or station.train.expedition_id == expedition_id:
		return false
	station.candidate_queue = station.candidate_queue.filter(func(id): return not station.residents.has(id) and not civilian(id).is_empty())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:train" % expedition_id)
	station.train = _train_defaults()
	station.train.expedition_id = expedition_id
	var classes := train_classes(campaign)
	# O civil só vem com lugar para ajudante (#119).
	var civilians_open: bool = not station.candidate_queue.is_empty() and not helpers_full(campaign)
	var arrives := rng.randi_range(1, 100) <= train_chance(campaign) or force != ""
	# O Mercador (#182, parte 2): um sorteio à parte (o de quem vem não muda), contra o peso de vir um ou dois. Ele não
	# precisa de lugar, então vem também com a casa cheia e a fila vazia.
	if arrives and (force == "merchant" or (force == "" and _merchant_turn(expedition_id))):
		station.train_dry = 0
		station.train.phase = "waiting"
		station.train.candidate_id = MERCHANT
		return true
	if not arrives or (not civilians_open and classes.is_empty()):
		station.train_dry = int(station.get("train_dry", 0)) + 1
		return false
	station.train_dry = 0
	var civilian_turn := rng.randi_range(1, 100) <= train_rule("train", "CivilianShare", 50)
	if force != "":
		civilian_turn = force == "civilian"
	station.train.phase = "waiting"
	if civilians_open and (civilian_turn or classes.is_empty()):
		station.train.candidate_id = station.candidate_queue[0]
		return true
	var first := _train_animal(campaign, classes, rng, [])
	station.train.candidate_id = first.candidate_id
	station.train.recruit = first.recruit
	# Às vezes descem dois (#182): o segundo só com lugar para os dois e um rosto livre (sem repetir o do primeiro).
	var single := train_rule("train", "SingleWeight", 60)
	var pair := train_rule("train", "PairWeight", 0)
	var room_for_two: bool = hero_limit(campaign) - living(campaign).size() >= 2
	if room_for_two and pair > 0 and rng.randi_range(1, single + pair) > single:
		var others := train_classes(campaign)
		if not others.is_empty():
			station.train.next = _train_animal(campaign, others, rng, [first.candidate_id])
	return true


## O trem que chega traz o Mercador? MerchantWeight contra SingleWeight + PairWeight (data/recruitment.json), num
## sorteio da expedição só dele.
static func _merchant_turn(expedition_id: String) -> bool:
	var merchant := train_rule("train", "MerchantWeight", 0)
	if merchant <= 0:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:merchant" % expedition_id)
	var others := train_rule("train", "SingleWeight", 60) + train_rule("train", "PairWeight", 0)
	return rng.randi_range(1, others + merchant) > others


## Um animal do trem de uma das classes: {candidate_id, recruit}. taken: os ids já reservados nesta chegada.
static func _train_animal(campaign: Dictionary, classes: Array, rng: RandomNumberGenerator, taken: Array) -> Dictionary:
	var class_id: String = classes[rng.randi() % classes.size()]
	var origins: Array = GameData.table("recruitment").values().filter(func(r): return String(r.get("ClassId", "")) == class_id)
	origins.sort_custom(func(a, b): return String(a.Name) < String(b.Name))
	var candidate_id := _next_hero_id(campaign, class_id)
	var suffix: int = campaign.roster.size()
	while taken.has(candidate_id) or hero(campaign, candidate_id) != null:
		suffix += 1
		candidate_id = "hero_%s_%d" % [class_id, suffix]
	return {"candidate_id": candidate_id, "recruit": {"class_id": class_id, "display_name": hero_name(campaign, class_id),
		"perks": Campaign.roll_perks(GameData.table("perks"), rng), "art_variant": pick_art_variant(campaign, class_id),
		"origin": String(origins[rng.randi() % origins.size()].Text) if not origins.is_empty() else ""}}


## O nome de quem espera na plataforma (o civil ou o animal do trem), ou "". Com dois (#182), os dois: "Nix e Sereno".
static func train_candidate_name(campaign: Dictionary) -> String:
	var names := train_waiting_names(campaign)
	return names[0] if names.size() == 1 else (TranslationServer.translate("%s e %s") % names if names.size() == 2 else "")


## Os nomes de quem espera na plataforma: o de agora e, se desceram dois (#182), o outro.
static func train_waiting_names(campaign: Dictionary) -> Array:
	var train: Dictionary = campaign.station.train
	if train.phase != "waiting":
		return []
	if train.candidate_id == MERCHANT:
		return [TranslationServer.translate(MERCHANT_NAME)]
	var recruit: Dictionary = train.get("recruit", {})
	var names: Array = [String(recruit.display_name) if not recruit.is_empty() else String(civilian(train.candidate_id).get("name", ""))]
	var second: Dictionary = train.get("next", {}).get("recruit", {})
	if typeof(second) == TYPE_DICTIONARY and not second.is_empty():
		names.append(String(second.display_name))
	return names


## Quem espera no trem é um animal (#122), e não um civil.
static func train_recruit(campaign: Dictionary) -> Dictionary:
	var train: Dictionary = campaign.station.train
	return train.get("recruit", {}) if train.phase == "waiting" else {}


## O que o animal do trem pede para ficar (sementes): de graça enquanto o elenco não fecha uma equipe de quatro.
static func recruit_price(campaign: Dictionary, class_id: String) -> int:
	return 0 if can_recruit_volunteer(campaign, class_id) else train_rule("recruit", "Cost", RECRUIT_COST)


## Por que o animal do trem não pode ficar agora ("" quando pode): a casa cheia ou as sementes.
static func recruit_block(campaign: Dictionary) -> String:
	var recruit := train_recruit(campaign)
	if recruit.is_empty():
		return ""
	if heroes_full(campaign):
		return TranslationServer.translate("O Alojamento está cheio (%d de %d heróis): não há lugar para %s agora.") % [living(campaign).size(), hero_limit(campaign), recruit.display_name]
	var price := recruit_price(campaign, recruit.class_id)
	if quantity(campaign, "seeds") < price:
		return TranslationServer.translate("Faltam sementes: %s pede %d.") % [recruit.display_name, price]
	return ""


## Desceram dois (#182, a decisão do Lucas): o jogador decide os dois na ordem que quiser. Trazer à frente o segundo
## troca os dois de lugar no trem (quem é decidido agora e quem espera); devolve se trocou.
static func bring_forward(campaign: Dictionary, candidate_id: String) -> bool:
	var train: Dictionary = campaign.station.train
	var second: Dictionary = train.get("next", {})
	if train.phase != "waiting" or second.is_empty() or candidate_id == "" or second.get("candidate_id", "") != candidate_id:
		return false
	train.next = {"candidate_id": train.candidate_id, "recruit": train.recruit}
	train.candidate_id = second.candidate_id
	train.recruit = second.recruit
	return true


## Acolher ou recusar quem espera na plataforma (qualquer um dos dois, quando desceram dois). O civil recusado volta ao
## fim da fila; o animal recusado vai embora e não volta. Acolher o animal custa o que ele pede (recruit_price).
static func decide_candidate(campaign: Dictionary, candidate_id: String, accept: bool) -> String:
	var front: String = campaign.station.train.candidate_id
	var swapped := bring_forward(campaign, candidate_id)
	var error := _decide_front(campaign, candidate_id, accept)
	# A decisão não passou (sem sementes, sem lugar): os dois voltam à ordem de antes.
	if error != "" and swapped:
		bring_forward(campaign, front)
	return error


static func _decide_front(campaign: Dictionary, candidate_id: String, accept: bool) -> String:
	var station: Dictionary = campaign.station
	if station.train.phase != "waiting" or station.train.candidate_id != candidate_id or candidate_id == "":
		return TranslationServer.translate("Ninguém está esperando na plataforma.")
	# O Mercador não fica nem é recusado: ele troca e é dispensado (dismiss_merchant).
	if candidate_id == MERCHANT:
		return TranslationServer.translate("O Sr. dos Trilhos não fica na Estação: ele troca e segue no trem quando for dispensado.")
	var recruit: Dictionary = station.train.get("recruit", {})
	if not recruit.is_empty():
		if accept:
			var block := recruit_block(campaign)
			if block != "":
				return block
			adjust(campaign, "seeds", -recruit_price(campaign, recruit.class_id))
			# O id reservado na chegada pode ter sido usado depois (a barra de Admin recrutou da mesma classe).
			var hero_id := candidate_id if hero(campaign, candidate_id) == null else _next_hero_id(campaign, recruit.class_id)
			_add_hero(campaign, hero_id, recruit.class_id, recruit.display_name, recruit.perks, recruit.art_variant)
	else:
		if accept and helpers_full(campaign) and not station.residents.has(candidate_id):
			return TranslationServer.translate("Não há lugar para mais ajudantes (%d de %d).") % [station.residents.size(), helper_limit(campaign)]
		station.candidate_queue.erase(candidate_id)
		if accept:
			if not station.residents.has(candidate_id):
				station.residents.append(candidate_id)
		else:
			station.candidate_queue.append(candidate_id)
	station.train.accepted = accept
	# O outro do trem (#182): decidido um, o outro continua esperando (o trem ainda não parte).
	var second: Dictionary = station.train.get("next", {})
	if not second.is_empty():
		station.train.candidate_id = second.candidate_id
		station.train.recruit = second.recruit
		station.train.next = {}
		return ""
	station.train.phase = "departing"
	return ""


## Ninguém decidiu antes da partida (#122): quem esperava vai embora no trem, como recusado, e a visita acaba.
static func train_leaves(campaign: Dictionary) -> void:
	var station: Dictionary = campaign.station
	# Os dois do trem (#182) vão embora juntos. Um trem inconsistente (sem candidato, num save velho) não trava a partida:
	# o erro da decisão encerra a visita.
	for attempt in 3:
		if station.train.phase != "waiting":
			break
		if decide_candidate(campaign, station.train.candidate_id, false) != "":
			station.train.phase = "departing"
	if station.train.phase == "waiting":
		station.train.phase = "departing"
	finish_departure(campaign)


## Fim da partida do trem: a visita acaba (guarda a expedição, para a mesma volta não trazer o trem de novo).
static func finish_departure(campaign: Dictionary) -> bool:
	var train: Dictionary = campaign.station.train
	if train.phase != "departing":
		return false
	campaign.station.train = _train_defaults()
	campaign.station.train.expedition_id = train.expedition_id
	return true


# ---------------------------------------------------------------- o Mercador (#182, parte 2)

## O Mercador, o Sr. dos Trilhos: o trem às vezes o traz no lugar de alguém. Ele não entra no elenco e não pode ser
## recrutado (decisão do Lucas, 28/10): fica na plataforma para trocar e vender até o jogador dispensá-lo, e a
## Preparação pede para dispensá-lo antes de partir. O id dele é o da arte (art/civilians/merchant).
const MERCHANT := "merchant"
const MERCHANT_NAME := "O Sr. dos Trilhos"


## O Mercador está na plataforma (chegou e não foi dispensado).
static func merchant_here(campaign: Dictionary) -> bool:
	var train: Dictionary = campaign.station.train
	return train.phase == "waiting" and train.candidate_id == MERCHANT


## As trocas do Mercador (data/merchant.json), na ordem da tabela: {Name, Give, GiveAmount, Get, GetAmount, Limit}.
static func merchant_trades() -> Array:
	return GameData.table("merchant").values()


## Quantas vezes a troca ainda sai nesta visita.
static func trades_left(campaign: Dictionary, trade_id: String) -> int:
	var row = GameData.row("merchant", trade_id)
	if row == null:
		return 0
	return maxi(0, int(row.get("Limit", 0)) - int(campaign.station.train.get("trades", {}).get(trade_id, 0)))


## Por que a troca não sai agora ("" quando sai): sem o Mercador, o limite da visita ou o que falta dar.
static func trade_block(campaign: Dictionary, trade_id: String) -> String:
	if not merchant_here(campaign):
		return TranslationServer.translate("O Sr. dos Trilhos não está na plataforma.")
	var row = GameData.row("merchant", trade_id)
	if row == null:
		return TranslationServer.translate("Troca desconhecida.")
	if trades_left(campaign, trade_id) <= 0:
		return TranslationServer.translate("Nesta visita, ele não faz mais essa troca.")
	var give := String(row.Give)
	var amount := int(row.GiveAmount)
	if quantity(campaign, give) < amount:
		return TranslationServer.translate("Faltam %s: a troca pede %s.") % [resource_noun(give), resource_amount(give, amount)]
	return ""


## Faz uma troca com o Mercador: dá o que ela pede e recebe o que oferece. Devolve "" ou o motivo.
static func merchant_trade(campaign: Dictionary, trade_id: String) -> String:
	var block := trade_block(campaign, trade_id)
	if block != "":
		return block
	var row = GameData.row("merchant", trade_id)
	adjust(campaign, String(row.Give), -int(row.GiveAmount))
	adjust(campaign, String(row.Get), int(row.GetAmount))
	var trades: Dictionary = campaign.station.train.trades
	trades[trade_id] = int(trades.get(trade_id, 0)) + 1
	return ""


## O jogador dispensa o Mercador: ele volta ao trem, que parte (como o recusado). Devolve "" ou o motivo.
static func dismiss_merchant(campaign: Dictionary) -> String:
	if not merchant_here(campaign):
		return TranslationServer.translate("O Sr. dos Trilhos não está na plataforma.")
	campaign.station.train.phase = "departing"
	return ""


## O nome de um recurso das trocas, no plural ("sementes", "sucatas", "fragmentos").
static func resource_noun(resource: String) -> String:
	match resource:
		"seeds":
			return TranslationServer.translate("sementes")
		"scrap":
			return TranslationServer.translate("sucatas")
		"fragments":
			return TranslationServer.translate("fragmentos")
	return resource


## Uma quantidade de um recurso das trocas ("1 fragmento", "4 sementes").
static func resource_amount(resource: String, amount: int) -> String:
	if resource == "seeds":
		return (TranslationServer.translate("%d semente") if amount == 1 else TranslationServer.translate("%d sementes")) % amount
	return cost_text({resource: amount})


## Previsão do próximo ciclo como se o candidato já morasse aqui (o impacto mostrado antes da escolha).
static func forecast_with(campaign: Dictionary, civilian_id: String, returning: int) -> Dictionary:
	var copy: Dictionary = campaign.duplicate(true)
	if not civilian(civilian_id).is_empty() and not copy.station.residents.has(civilian_id):
		copy.station.residents.append(civilian_id)
	return forecast(copy, returning)


# ================================================================ noite da volta

## Abre a noite da volta: quem voltou vivo participa e a comida que sobrou vira suprimento.
static func begin_night(campaign: Dictionary, expedition_id: String, team: Array, leftover_food: int) -> bool:
	var night: Dictionary = campaign.night
	if expedition_id == "" or night.expedition_id == expedition_id or night.phase != "none":
		return false
	var participants: Array = []
	for hero_id in team:
		var entry = hero(campaign, hero_id)
		if entry != null and entry.alive and not participants.has(hero_id):
			participants.append(hero_id)
	if participants.is_empty():
		return false
	var number := int(night.number) + 1
	campaign.night = _night_defaults()
	campaign.night.number = number
	campaign.night.expedition_id = expedition_id
	campaign.night.phase = "planning"
	campaign.night.participants = participants
	adjust(campaign, SUPPLIES, maxi(0, leftover_food))
	return true


## Quem fica de vigia ("" ninguém). Pelo menos um sobrevivente precisa dormir.
static func set_watch(campaign: Dictionary, hero_id: String) -> bool:
	var night: Dictionary = campaign.night
	if not in_refuge(campaign) or night.phase != "planning" or night.watch_hero_id == hero_id:
		return false
	if hero_id != "":
		var awake: Array = night.participants.filter(func(id): return hero(campaign, id) != null and hero(campaign, id).alive)
		var entry = hero(campaign, hero_id)
		if awake.size() <= 1 or entry == null or not entry.alive or entry.hp <= 0 or not night.participants.has(hero_id):
			return false
	night.watch_hero_id = hero_id
	return true


static func buy_supplies(campaign: Dictionary, amount: int = 1) -> bool:
	if not in_refuge(campaign) or amount <= 0 or not consume(campaign, "seeds", amount * SUPPLY_COST_SEEDS):
		return false
	adjust(campaign, SUPPLIES, amount)
	return true


## A noite: quem dorme come um suprimento e recupera vida e instinto; o vigia fica acordado. O evento da noite (#132)
## sai de data/night-events.json, sorteado pela semente da expedição; force (os testes) escolhe um.
static func resolve_night(campaign: Dictionary, force: String = "") -> bool:
	var night: Dictionary = campaign.night
	if not in_refuge(campaign) or night.phase != "planning":
		return false
	var awake: Array = night.participants.filter(func(id): return hero(campaign, id) != null and hero(campaign, id).alive)
	var watch = hero(campaign, night.watch_hero_id)
	if awake.size() <= 1 or watch == null or not watch.alive or watch.hp <= 0 or not night.participants.has(night.watch_hero_id):
		night.watch_hero_id = ""
	var event := _draw_night_event(campaign, awake, force)
	night.event = event
	night.event_id = String(event.id)
	night.results = []
	night.supplies_consumed = 0
	var hungry := false
	for hero_id in night.participants:
		var entry = hero(campaign, hero_id)
		if entry == null or not entry.alive:
			continue
		var result := {"hero_id": hero_id, "watch": hero_id == night.watch_hero_id, "fed": false, "hp_recovered": 0, "instinct_reduced": 0}
		if not result.watch:
			result.fed = consume(campaign, SUPPLIES)
			night.supplies_consumed += 1 if result.fed else 0
			hungry = hungry or not result.fed
			var before_hp: int = entry.hp
			var before_instinct: int = entry.instinct
			entry.hp = mini(entry.max_hp, entry.hp + maxi(1, entry.max_hp * (35 if result.fed else 15) / 100))
			var noise := int(event.get("amount", 0)) if event.id == "distant_noise" and not event.get("prevented", false) else 0
			var thirst := THIRST_INSTINCT_PENALTY if night.thirsty else 0
			entry.instinct = clampi(entry.instinct - (15 if result.fed else 5) + noise + thirst, 0, 200)
			# Quem não dormiu pelo trauma (#132) perde só o desconto do sono: a sede pesa igual.
			if event.id == "sleepless" and String(event.get("hero_id", "")) == hero_id:
				entry.instinct = clampi(before_instinct + thirst, 0, 200)
			result.hp_recovered = entry.hp - before_hp
			result.instinct_reduced = before_instinct - entry.instinct
		night.results.append(result)
	# As condições da noite ficam à parte do evento: a fome e a sede.
	night.conditions = []
	if hungry:
		night.conditions.append("short_supplies")
	if night.thirsty:
		night.conditions.append("no_water")
	_apply_night_event(campaign, event)
	night.phase = "dawn"
	return true


## Uma linha de data/night-events.json.
static func night_row(name: String) -> Dictionary:
	var row = GameData.row("night_events", name)
	return row if row != null else {}


## O sorteio do evento da noite (#132): os eventos com peso e com o que pedem (o vigia, um morador, alguém com trauma
## dormindo); com vigia, os ruins pesam menos. {id, amount, hero_id, civilian_id, phase_id, prevented, protected}.
static func _draw_night_event(campaign: Dictionary, awake: Array, force: String = "") -> Dictionary:
	var night: Dictionary = campaign.night
	var watch := String(night.watch_hero_id)
	var troubled: Array = awake.filter(func(id): return id != watch and bool(hero(campaign, id).get("trauma", false)))
	var sighting := _next_sighting(campaign)
	# O sorteio usa os pesos cheios, sem olhar o vigia: trocar quem vigia não escolhe a noite. O vigia só muda o que o
	# evento sorteado faz (evita as perdas) e se ele vê algo.
	var options: Array = []
	for row in GameData.table("night_events").values():
		if row.has("Weight"):
			options.append([String(row.Name), float(row.Weight)])
	options.sort_custom(func(a, b): return a[0] < b[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:night" % night.expedition_id)
	var total := 0.0
	for option in options:
		total += option[1]
	var roll := rng.randf() * total
	var id := "quiet"
	for option in options:
		roll -= option[1]
		if roll < 0.0:
			id = option[0]
			break
	if force != "":
		id = force
	# Sem quem o evento pede (o vigia e um lugar por ver, um morador, alguém com trauma que dormiu), a noite é tranquila.
	match String(night_row(id).get("Requires", "")):
		"watch":
			if watch == "" or sighting == "":
				id = "quiet"
		"resident":
			if campaign.station.residents.is_empty():
				id = "quiet"
		"trauma":
			if troubled.is_empty():
				id = "quiet"
	var row := night_row(id)
	var event := {"id": id, "amount": int(row.get("Amount", 0)), "hero_id": "", "civilian_id": "", "phase_id": "",
		"prevented": bool(row.get("Bad", false)) and watch != "" and row.has("TextWatched"), "protected": false}
	match id:
		"watcher_sees":
			event.hero_id = watch
			event.phase_id = sighting
		"resident_talk":
			var residents: Array = campaign.station.residents.duplicate()
			residents.sort()
			event.civilian_id = residents[rng.randi() % residents.size()] if not residents.is_empty() else ""
		"sleepless":
			event.hero_id = troubled[rng.randi() % troubled.size()] if not troubled.is_empty() else ""
		"pests":
			event.protected = room_level(campaign, DEPOT) >= 2
	return event


## O lugar que o vigia pode avistar: o próximo liberado e não concluído, ainda sem o guardião lido.
static func _next_sighting(campaign: Dictionary) -> String:
	for info in J.PHASES:
		if phase_unlocked(campaign, info.id) and not campaign.completed_phases.has(info.id) and not campaign.station.get("sightings", []).has(info.id) \
				and AHNetworkRadar.state_of(campaign, info.id, "boss") != "known":
			return info.id
	return ""


## O efeito do evento na Estação (o instinto fica no laço de resolve_night).
static func _apply_night_event(campaign: Dictionary, event: Dictionary) -> void:
	if event.get("prevented", false):
		return
	match String(event.id):
		"leak":
			# O que de fato se perdeu (com pouca água, menos; sem água, nada a perder).
			var lost := mini(int(campaign.station.water), int(event.amount))
			campaign.station.water = int(campaign.station.water) - lost
			event.amount = lost
			event.empty = lost == 0
		"pests":
			if not event.protected:
				event.amount = -adjust(campaign, SUPPLIES, -int(event.amount))
				event.empty = int(event.amount) == 0
		"platform_noise":
			campaign.station.train_dry = int(campaign.station.get("train_dry", 0)) + 1
		"watcher_sees":
			if event.phase_id != "":
				if not campaign.station.has("sightings"):
					campaign.station.sightings = []
				campaign.station.sightings.append(event.phase_id)


## A prévia da noite (os cartões do Dormitório): para cada participante vivo, se vigia, se come e quanto recupera, na
## mesma ordem e com as mesmas contas de resolve_night. {heroes: [{hero_id, watch, fed, hp_gain, instinct_change}],
## needed, available}.
static func night_preview(campaign: Dictionary) -> Dictionary:
	var night: Dictionary = campaign.night
	var supplies := quantity(campaign, SUPPLIES)
	var awake: Array = night.participants.filter(func(id): return hero(campaign, id) != null and hero(campaign, id).alive)
	var watch_id: String = night.watch_hero_id if awake.size() > 1 and awake.has(night.watch_hero_id) else ""
	var out := {"heroes": [], "needed": 0, "available": supplies}
	for hero_id in awake:
		var entry = hero(campaign, hero_id)
		var row := {"hero_id": hero_id, "watch": hero_id == watch_id, "fed": false, "hp_gain": 0, "instinct_change": 0}
		if not row.watch:
			out.needed += 1
			row.fed = supplies > 0
			supplies -= 1 if row.fed else 0
			var gain := maxi(1, int(entry.max_hp) * (35 if row.fed else 15) / 100)
			row.hp_gain = mini(int(entry.max_hp), int(entry.hp) + gain) - int(entry.hp)
			var change := -(15 if row.fed else 5) + (THIRST_INSTINCT_PENALTY if night.thirsty else 0)
			row.instinct_change = clampi(int(entry.instinct) + change, 0, 200) - int(entry.instinct)
		out.heroes.append(row)
	return out


static func finish_dawn(campaign: Dictionary) -> bool:
	if not in_refuge(campaign) or campaign.night.phase != "dawn":
		return false
	campaign.night.phase = "none"
	return true


## O que a noite contou (#132): o texto do evento sorteado, com quem e quanto.
static func night_event_text(campaign: Dictionary) -> String:
	var event: Dictionary = campaign.night.get("event", {})
	if not event.is_empty():
		var row := night_row(String(event.id))
		var text := TranslationServer.translate(String(row.get("Text", "")))
		if event.get("prevented", false):
			return TranslationServer.translate(String(row.get("TextWatched", "")))
		match String(event.id):
			"leak", "pests":
				if event.get("protected", false):
					return TranslationServer.translate(String(row.get("TextProtected", "")))
				if event.get("empty", false):
					return TranslationServer.translate(String(row.get("TextEmpty", "")))
				if int(event.amount) == 1:
					return TranslationServer.translate(String(row.get("TextOne", "")))
				return text % int(event.amount)
			"watcher_sees":
				var watcher = hero(campaign, String(event.hero_id))
				return text % [watcher.display_name if watcher != null else "", TranslationServer.translate(String(J.phase(String(event.phase_id)).get("name", "")))]
			"sleepless":
				var troubled = hero(campaign, String(event.hero_id))
				return text % (troubled.display_name if troubled != null else "")
			"resident_talk":
				return TranslationServer.translate(String(night_row("talk_%s" % String(event.civilian_id).trim_prefix("civil_")).get("Text", "")))
		return text
	# Saves de antes do #132: o evento antigo.
	match campaign.night.event_id:
		"short_supplies":
			return TranslationServer.translate("Os suprimentos não bastaram para todos. Quem dormiu sem comida recuperou menos.")
		"no_water":
			return TranslationServer.translate("Faltou água para quem voltou. O descanso foi pior: menos Instinto recuperado.")
		"distant_noise":
			return TranslationServer.translate("Ruídos distantes inquietaram os adormecidos: recuperação de Instinto reduzida em 3.") if campaign.night.watch_hero_id == "" \
				else TranslationServer.translate("O vigia verificou os ruídos distantes. Os demais puderam descansar em segurança.")
	return TranslationServer.translate("A noite passou tranquila. O abrigo permaneceu seguro.")


## As condições da noite (a fome, a sede), à parte do evento.
static func night_conditions_text(campaign: Dictionary) -> Array:
	var out: Array = []
	for condition in campaign.night.get("conditions", []):
		match String(condition):
			"short_supplies":
				out.append(TranslationServer.translate("Os suprimentos não bastaram para todos. Quem dormiu sem comida recuperou menos."))
			"no_water":
				out.append(TranslationServer.translate("Faltou água para quem voltou. O descanso foi pior: menos Instinto recuperado."))
	return out


## O evento da noite é ruim e aconteceu (não foi evitado pelo vigia nem pelo Depósito)?
static func night_event_bad(campaign: Dictionary) -> bool:
	var event: Dictionary = campaign.night.get("event", {})
	return not event.is_empty() and bool(night_row(String(event.id)).get("Bad", false)) and not event.get("prevented", false) \
		and not event.get("protected", false) and not event.get("empty", false)


# ================================================================ refúgio: elenco, enfermaria, pesquisa, forja

## Voluntário gratuito: o elenco ainda não fecha uma equipe de quatro (dois por classe, no máximo).
static func can_recruit_volunteer(campaign: Dictionary, class_id: String) -> bool:
	var counts := _class_counts(campaign)
	var usable := 0
	for count in counts.values():
		usable += mini(MAX_PER_CLASS, count)
	return usable < 4 and int(counts.get(class_id, 0)) < MAX_PER_CLASS


static func _class_counts(campaign: Dictionary) -> Dictionary:
	var counts := {}
	for entry in living(campaign):
		counts[entry.class_id] = int(counts.get(entry.class_id, 0)) + 1
	return counts


## Nome livre da classe (nem no elenco nem no memorial dos saves antigos).
static func hero_name(campaign: Dictionary, class_id: String) -> String:
	var used := {}
	for entry in campaign.roster:
		used[String(entry.display_name).to_lower()] = true
	# Quem espera no trem também tem nome (#182: os dois que chegam juntos não se chamam igual).
	for waiting in waiting_recruits(campaign):
		used[String(waiting.get("display_name", "")).to_lower()] = true
	for entry in campaign.get("memorial", []):
		used[String(entry.display_name).to_lower()] = true
	# Os nomes vêm da cultura da espécie (#189), a padrão da classe enquanto o recruta chega com ela.
	var pool: Array = AHSpecies.names(AHSpecies.default_for(class_id))
	if pool.is_empty():
		pool = ["Recruta"]
	for candidate in pool:
		if not used.has(String(candidate).to_lower()):
			return candidate
	var counter := 2
	while used.has(("%s %d" % [pool[0], counter]).to_lower()):
		counter += 1
	return "%s %d" % [pool[0], counter]


## Novo animal de uma classe liberada: 10 sementes, ou de graça como voluntário. Devolve {error, hero_id}.
static func recruit(campaign: Dictionary, class_id: String, rng: RandomNumberGenerator, given_name: String = "") -> Dictionary:
	var hero_class = GameData.row("classes", class_id)
	if hero_class == null or not campaign.unlocked_classes.has(class_id):
		return {"error": TranslationServer.translate("Essa classe ainda não chegou à Estação.")}
	if heroes_full(campaign):
		return {"error": TranslationServer.translate("O Alojamento está cheio (%d de %d heróis).") % [living(campaign).size(), hero_limit(campaign)]}
	# Nenhum personagem repetido (#182): sem variação livre da classe, ninguém novo dela chega (a classe sem nenhum
	# recruta desenhado, o Guaxinim e o Tatu, segue como antes).
	var variant := pick_art_variant(campaign, class_id)
	if variant == "" and not art_variants(class_id).is_empty():
		return {"error": TranslationServer.translate("Ninguém novo dessa classe chega agora: todos os rostos dela já estão na Estação.")}
	var free := given_name != "" or can_recruit_volunteer(campaign, class_id)
	if not free and quantity(campaign, "seeds") < RECRUIT_COST:
		return {"error": TranslationServer.translate("Sementes insuficientes (custa 10 sementes).")}
	if not free:
		adjust(campaign, "seeds", -RECRUIT_COST)
	var hero_id := _next_hero_id(campaign, class_id)
	var display := given_name if given_name != "" else hero_name(campaign, class_id)
	_add_hero(campaign, hero_id, class_id, display, Campaign.roll_perks(GameData.table("perks"), rng), variant)
	return {"error": "", "hero_id": hero_id}


## O próximo id livre de recruta da classe (hero_cao_5), fora do elenco e dos ids reservados de quem espera no trem
## (#182: a barra de Admin recrutando no meio não toma o id do segundo).
static func _next_hero_id(campaign: Dictionary, class_id: String) -> String:
	var train: Dictionary = campaign.get("station", {}).get("train", {})
	var reserved: Array = [String(train.get("candidate_id", "")), String(train.get("next", {}).get("candidate_id", ""))]
	var suffix: int = campaign.roster.size()
	while hero(campaign, "hero_%s_%d" % [class_id, suffix]) != null or reserved.has("hero_%s_%d" % [class_id, suffix]):
		suffix += 1
	return "hero_%s_%d" % [class_id, suffix]


static func _add_hero(campaign: Dictionary, hero_id: String, class_id: String, display: String, perks: Array, variant: String) -> void:
	var hero_class = GameData.row("classes", class_id)
	campaign.roster.append(Campaign.new_hero(hero_id, class_id, display, int(hero_class.BaseMaxHp), perks))
	campaign.roster[-1].art_variant = variant


# ---------------------------------------------------------------- arte dos recrutas (#32)

const ART_MANIFEST := "res://data/presentation/combat_art.json"
static var _recruit_art := {}


## As variações de arte de uma classe (a seção recruits do manifesto, a entrega #14 do Codex), em ordem.
static func art_variants(class_id: String) -> Array:
	if _recruit_art.is_empty():
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(ART_MANIFEST))
		_recruit_art = manifest.get("recruits", {}) if typeof(manifest) == TYPE_DICTIONARY else {}
	var out: Array = _recruit_art.keys().filter(func(v): return _recruit_art[v].get("class_id", "") == class_id)
	out.sort()
	return out


## Nenhum personagem repetido (#182, decisão do Lucas): as variações da classe que ninguém usa, nem no elenco (vivo,
## caído ou em recuperação) nem o animal que espera no trem. Cada arte é uma pessoa só.
static func free_art_variants(campaign: Dictionary, class_id: String) -> Array:
	var taken: Array = campaign.roster.map(func(h): return String(h.get("art_variant", "")))
	for waiting in waiting_recruits(campaign):
		taken.append(String(waiting.get("art_variant", "")))
	return art_variants(class_id).filter(func(v): return not taken.has(v))


## Os animais que esperam no trem (#182): quem é decidido agora e quem desceu junto. O rosto e o nome deles ficam
## reservados até a decisão.
static func waiting_recruits(campaign: Dictionary) -> Array:
	var train: Dictionary = campaign.get("station", {}).get("train", {})
	var out: Array = []
	# O animal do pedido de ajuda (#188) também: o trem não traz o mesmo nome nem a mesma arte.
	var help = campaign.get("station", {}).get("side_missions", {}).get("help", {})
	var help_recruit = help.get("recruit", {}) if typeof(help) == TYPE_DICTIONARY else {}
	for recruit in [train.get("recruit", {}), train.get("next", {}).get("recruit", {}), help_recruit]:
		if typeof(recruit) == TYPE_DICTIONARY and not recruit.is_empty():
			out.append(recruit)
	return out


## A variação para um recruta novo: a primeira livre (free_art_variants), sem sortear, para o recrutamento continuar com
## as mesmas sementes. "" sem nenhuma livre: não vem ninguém dessa classe.
static func pick_art_variant(campaign: Dictionary, class_id: String) -> String:
	var free := free_art_variants(campaign, class_id)
	return free[0] if not free.is_empty() else ""


## A variação de um recruta de save antigo sem o campo (#32): a menos usada pelos vivos da classe. Quem já é repetido
## num save antigo continua como está (#182: ninguém some).
static func _least_used_variant(campaign: Dictionary, class_id: String) -> String:
	var variants := art_variants(class_id)
	if variants.is_empty():
		return ""
	var best := ""
	var best_count := 1 << 30
	for variant in variants:
		var count: int = campaign.roster.filter(func(h): return h.get("alive", true) and h.get("art_variant", "") == variant).size()
		if count < best_count:
			best = variant
			best_count = count
	return best


## O recruta (hero_cao_4) e não um fundador (hero_cao_bento): o fim do id é um número.
static func is_recruit(hero_id: String) -> bool:
	return hero_id.get_slice("_", 2).is_valid_int()


## Os voluntários a caminho entram no elenco, enquanto houver vaga.
static func receive_volunteers(campaign: Dictionary, rng: RandomNumberGenerator) -> int:
	var arrived := 0
	var waiting: Array = []
	while not campaign.pending_offers.is_empty() and not heroes_full(campaign):
		var offer: Dictionary = campaign.pending_offers.pop_front()
		if not campaign.unlocked_classes.has(offer.class_id):
			campaign.unlocked_classes.append(offer.class_id)
		# Sem rosto livre da classe (#182, nenhum personagem repetido), o voluntário espera a vez, sem se perder.
		if pick_art_variant(campaign, offer.class_id) == "" and not art_variants(offer.class_id).is_empty():
			waiting.append(offer)
			continue
		arrived += 1 if recruit(campaign, offer.class_id, rng, offer.display_name).error == "" else 0
	campaign.pending_offers = waiting + campaign.pending_offers
	return arrived


static func treat_trauma(campaign: Dictionary, hero_id: String) -> String:
	var entry = hero(campaign, hero_id)
	if entry == null or not entry.alive:
		return TranslationServer.translate("Somente sobreviventes podem ser tratados.")
	if not entry.trauma:
		return TranslationServer.translate("%s não tem trauma.") % entry.display_name
	if not consume(campaign, "seeds", TRAUMA_COST):
		return TranslationServer.translate("Sementes insuficientes (custa 5 sementes).")
	entry.trauma = false
	return ""


static func research(campaign: Dictionary, research_id: String) -> String:
	var row = GameData.row("research", research_id)
	if row == null:
		return TranslationServer.translate("Pesquisa desconhecida.")
	if not room_available(campaign, RESEARCH):
		return TranslationServer.translate("Recupere o Centro de Pesquisa para pesquisar.")
	if campaign.researched_skills.has(row.SkillId):
		return TranslationServer.translate("Essa melhoria já foi pesquisada.")
	if not consume(campaign, "fragments", int(row.CostFragments)):
		return TranslationServer.translate("Fragmentos insuficientes (custa %d).") % int(row.CostFragments)
	campaign.researched_skills.append(row.SkillId)
	return ""


static func craft_relic(campaign: Dictionary, relic_id: String) -> String:
	if GameData.row("relics", relic_id) == null:
		return TranslationServer.translate("Relíquia desconhecida.")
	if not room_available(campaign, FORGE):
		return TranslationServer.translate("Recupere a Forja para fabricar relíquias.")
	var cost := relic_cost(campaign)
	if not consume(campaign, "scrap", cost):
		return TranslationServer.translate("Sucata insuficiente (custa %d sucatas).") % cost
	campaign.inventory.relics.append(relic_id)
	return ""


## Troca a relíquia do animal ("" tira); a antiga volta ao estoque.
static func equip_relic(campaign: Dictionary, hero_id: String, relic_id: String) -> String:
	var entry = hero(campaign, hero_id)
	if entry == null or not entry.alive:
		return TranslationServer.translate("Só animais vivos usam relíquias.")
	if entry.relic_id == relic_id:
		return TranslationServer.translate("Já está equipada.")
	if relic_id != "" and not campaign.inventory.relics.has(relic_id):
		return TranslationServer.translate("Essa relíquia não está no estoque.")
	if entry.relic_id != "":
		campaign.inventory.relics.append(entry.relic_id)
	if relic_id != "":
		campaign.inventory.relics.erase(relic_id)
	entry.relic_id = relic_id
	return ""


## Formação salva (até quatro vivos, sem repetir), da frente para trás.
static func set_formation(campaign: Dictionary, hero_ids: Array) -> bool:
	var formation: Array = []
	for hero_id in hero_ids:
		var entry = hero(campaign, hero_id)
		if entry == null or not entry.alive or formation.has(hero_id) or formation.size() >= 4:
			return false
		formation.append(hero_id)
	campaign.preferred_formation = formation
	return true


## Vivos diferentes, no máximo dois por classe, e quantos a jornada pede (#6: o mínimo e o máximo de cada fase; sem
## fase, quatro).
static func validate_team(campaign: Dictionary, hero_ids: Array, phase_id: String = "") -> String:
	var unique := {}
	for hero_id in hero_ids:
		unique[hero_id] = true
	var limits := J.team_limits(phase_id)
	var size_text := team_size_text(limits)
	if unique.size() != hero_ids.size() or hero_ids.size() < limits.min or hero_ids.size() > limits.max:
		return TranslationServer.translate("Esta jornada pede %s vivos na equipe.") % size_text
	var counts := {}
	for hero_id in hero_ids:
		var entry = hero(campaign, hero_id)
		if entry == null or not entry.alive:
			return TranslationServer.translate("Esta jornada pede %s vivos na equipe.") % size_text
		if recovering(entry):
			return recovery_block(entry)
		counts[entry.class_id] = int(counts.get(entry.class_id, 0)) + 1
		if counts[entry.class_id] > MAX_PER_CLASS:
			return TranslationServer.translate("No máximo dois animais da mesma classe na mesma equipe.")
	return ""


## Quem pode ir para a rua: a rua e a luta mostram cada herói com a arte dele (o recruta, com a variação da classe ou,
## sem ela, a do fundador).
## Uma classe sem arte nenhuma ainda (o rato e o tatu, liberados por eventos) fica na Estação até a arte chegar: antes
## ela partia na equipe e sumia da rua e da luta, e a expedição lutava com três.
## Quem está em recuperação (#118) também fica: só volta à equipe depois dos dias da Enfermaria.
## Quem está numa missão solo ou capturado (#183) também fica fora.
static func can_deploy(entry) -> bool:
	return entry != null and not recovering(entry) and not AHSideMissions.away(entry) and not AHCombatArena.hero_art_of(String(entry.id)).is_empty()


static func deploy_block(entry) -> String:
	if can_deploy(entry):
		return ""
	if AHSideMissions.away(entry):
		return AHSideMissions.away_text(entry)
	if recovering(entry):
		return recovery_block(entry)
	return TranslationServer.translate("%s ainda não tem arte de combate e fica na Estação por enquanto.") % entry.display_name


## "1 a 4", "3 ou 4", "4": quantos a jornada aceita, para as telas.
static func team_size_text(limits: Dictionary) -> String:
	if limits.min == limits.max:
		return "%d %s" % [limits.max, TranslationServer.translate("animal") if limits.max == 1 else TranslationServer.translate("animais")]
	if limits.max - limits.min == 1:
		return TranslationServer.translate("%d ou %d animais") % [limits.min, limits.max]
	return TranslationServer.translate("%d a %d animais") % [limits.min, limits.max]


## Os ataques que a classe tem na posição (#95): cada um precisa de um ataque na posição em que parte.
## ability_ids: as que o herói leva (#259); vazio, as 4 de base da classe.
static func attacks_from_rank(class_id: String, rank: int, ability_ids: Array = []) -> Array:
	var out: Array = []
	var hero_class = GameData.row("classes", class_id)
	if hero_class == null:
		return out
	for ability_id in (ability_ids if not ability_ids.is_empty() else hero_class.AbilityIds):
		var ability = GameData.row("abilities", ability_id)
		if ability != null and ability.get("DamageRange") != null and Array(ability.get("OriginRanks", [])).map(func(r): return int(r)).has(rank):
			out.append(ability.DisplayName)
	return out


## Admin e testes: larga a expedição em andamento (sem saque) e volta ao refúgio com a equipe descansada.
static func abandon_to_refuge(campaign: Dictionary) -> bool:
	if in_refuge(campaign):
		return false
	# Quem caiu na expedição largada volta Caído (#118); quem já se recuperava continua com a vida e os dias que tinha.
	var expedition = campaign.get("session", {}).get("expedition")
	var fell: Array = expedition.team.filter(func(id): return hero(campaign, id) != null and not hero(campaign, id).alive) if expedition != null else []
	for entry in living(campaign):
		if recovering(entry):
			continue
		entry.hp = entry.max_hp
		entry.instinct = 0
	admit_fallen(campaign, fell, expedition.get("carried", []) if expedition != null else [])
	campaign.session = {"screen": "shelter", "result": "", "expedition": null, "event": null}
	return true


# ================================================================ fases, preparação e partida

static func phase_unlocked(campaign: Dictionary, phase_id: String) -> bool:
	for i in J.PHASES.size():
		if J.PHASES[i].id == phase_id:
			return i == 0 or campaign.completed_phases.has(J.PHASES[i - 1].id)
	return false


## O que a Estação pede primeiro (o cartão "Próximo passo" da proposta de UX): o relatório da volta, a noite, o trem, um
## cômodo que já dá para recuperar, o que falta para o próximo e, por fim, a próxima fase. Devolve {title, text, action,
## button, room} e, no cômodo que já dá para recuperar, benefit (o que ele passa a fazer) e cost (os chips do cartão);
## action: "report", "dormitory", "train", "room" ou "depart".
static func next_step(campaign: Dictionary) -> Dictionary:
	var report: Dictionary = campaign.station.get("last_return", {})
	if not report.is_empty() and not report.get("seen", false):
		return {"title": TranslationServer.translate("Ver o que a equipe trouxe"), "text": TranslationServer.translate("O relatório da última expedição está pronto: o achado, quem voltou e como a Estação passou o ciclo."),
			"action": "report", "button": TranslationServer.translate("Ver o relatório"), "room": ""}
	if campaign.night.phase != "none":
		return {"title": TranslationServer.translate("Passar a noite"), "text": TranslationServer.translate("A equipe precisa dormir antes de partir de novo. No Dormitório, escolha quem vigia e durma: quem dorme come e recupera vida e instinto."),
			"action": "dormitory", "button": TranslationServer.translate("Ir ao Dormitório"), "room": DORMITORY}
	# A volta das missões solo (#183): o trem traz quem terminou a missão, com o relatório.
	if AHSideMissions.train_pending(campaign):
		return {"title": TranslationServer.translate("O trem trouxe quem estava em missão"), "text": TranslationServer.translate("Quem terminou a missão solo voltou no trem, com o relatório do que achou lá fora."),
			"action": "train", "button": TranslationServer.translate("Ir à plataforma"), "room": ""}
	if merchant_here(campaign):
		return {"title": TranslationServer.translate("O Mercador está na plataforma"), "text": TranslationServer.translate("O Sr. dos Trilhos veio no trem para trocar sementes, sucata e fragmentos. Troque o que quiser e dispense-o antes de preparar a expedição."),
			"action": "train", "button": TranslationServer.translate("Ir à plataforma"), "room": ""}
	if train_candidate_name(campaign) != "":
		var many := train_waiting_names(campaign).size() > 1
		return {"title": TranslationServer.translate("Chegou alguém no trem"), "text": (TranslationServer.translate("%s esperam na plataforma. Veja o que trazem e decida quem fica; se a equipe partir antes, vão embora no trem.") if many
			else TranslationServer.translate("%s espera na plataforma. Veja o que traz e decida se fica; se a equipe partir antes, vai embora no trem.")) % train_candidate_name(campaign),
			"action": "train", "button": TranslationServer.translate("Ir à plataforma"), "room": ""}
	# A tirinha do balão interativo (#207, decisão do Lucas): o objetivo leva o jogador a ver.
	var story := AHStationChatter.story_step(campaign)
	if not story.is_empty():
		return story
	if rest_block(campaign) == "":
		return {"title": TranslationServer.translate("Esperar a recuperação"), "text": TranslationServer.translate("Ninguém pode partir: a equipe está em recuperação. Passe um dia na Estação, e cada caído fica um dia mais perto de voltar."),
			"action": "rest", "button": TranslationServer.translate("Ver a Enfermaria"), "room": INFIRMARY}
	var missing := {}
	# A grade (#186, ponto 7): construir só quando há uma vaga livre do tamanho certo; senão, escavar. Escavar vem antes
	# de juntar material para melhorar um cômodo que já funciona, mas depois de reabrir um parado (a Forja da visita
	# guiada).
	var dig_first := false
	var first := {}
	for room_id in NEXT_ROOMS:
		var cost := next_level_cost(campaign, room_id)
		if cost.is_empty():
			continue
		if AHStationGrid.buried(campaign, room_id):
			dig_first = true
			continue
		var level := room_level(campaign, room_id)
		var name: String = TranslationServer.translate(ROOM_ARTICLE.get(room_id, "")) + TranslationServer.translate(room_def(room_id).name)
		if upgrade_block(campaign, room_id) == "":
			return {"title": "%s %s" % [TranslationServer.translate("Recuperar") if level == 0 else TranslationServer.translate("Melhorar"), name], "text": TranslationServer.translate("%s Custa %s.") % [room_benefit(room_id, level + 1), cost_text(cost)],
				"action": "room", "button": TranslationServer.translate("Ver %s") % name, "room": room_id, "benefit": room_benefit(room_id, level + 1), "cost": cost}
		var bring := {"title": TranslationServer.translate("Trazer %s para %s %s") % [cost_text(cost), TranslationServer.translate("reabrir") if level == 0 else TranslationServer.translate("melhorar"), name],
			"text": TranslationServer.translate("%s As jornadas trazem sucata e fragmentos das buscas.") % room_benefit(room_id, level + 1), "action": "depart",
			"button": TranslationServer.translate("Ir ao mapa"), "room": room_id}
		if first.is_empty():
			first = bring
		if level == 0 and missing.is_empty():
			missing = bring
	var dig := AHStationGrid.dig_step(campaign)
	if dig_first and not dig.is_empty():
		return missing if not missing.is_empty() else dig
	if not first.is_empty():
		return first
	for info in AHJourneyRules.PHASES:
		if phase_unlocked(campaign, info.id) and not campaign.completed_phases.has(info.id):
			return {"title": TranslationServer.translate("Partir para %s") % TranslationServer.translate(info.name), "text": TranslationServer.translate(info.description), "action": "depart", "button": TranslationServer.translate("Ir ao mapa"), "room": ""}
	# Nada para construir e nenhuma fase nova: o que falta escavar (no save antigo, o patamar do 3º subsolo).
	if not dig.is_empty():
		return dig
	return {"title": TranslationServer.translate("Voltar às ruas"), "text": TranslationServer.translate("Os Antigos ainda existem? A pergunta voltou com a equipe. Dá para jogar qualquer fase de novo pelo mapa."), "action": "depart",
		"button": TranslationServer.translate("Ir ao mapa"), "room": ""}


# ================================================================ recuperação dos caídos (#118, #121)
# Ninguém morre: quem cai na luta fica fora até o fim da expedição (alive = false, como antes) e volta à Estação Caído,
# com a vida baixa e em recuperação por alguns dias (recovery_days; um dia é um ciclo da Estação, uma volta). Num leito
# da Enfermaria (recovery_bed) a recuperação é mais curta; sem leito, no Dormitório, mais longa. Os números ficam em
# data/recovery.json, como propostas.

static func recovery_rule(rule_name: String) -> Dictionary:
	var row = GameData.row("recovery", rule_name)
	return row if row != null else {}


static func recovering(entry) -> bool:
	return entry != null and int(entry.get("recovery_days", 0)) > 0


static func recovery_days(entry) -> int:
	return maxi(0, int(entry.get("recovery_days", 0))) if entry != null else 0


static func in_bed(entry) -> bool:
	return recovering(entry) and bool(entry.get("recovery_bed", false))


## "Volta amanhã", "Volta em 3 dias".
static func return_text(days: int) -> String:
	return TranslationServer.translate("Volta amanhã") if days <= 1 else TranslationServer.translate("Volta em %d dias") % days


## Por que o herói em recuperação não parte (a Sala, a Preparação e a partida dizem o mesmo).
static func recovery_block(entry) -> String:
	var days := recovery_days(entry)
	var place := TranslationServer.translate("na Enfermaria") if in_bed(entry) else TranslationServer.translate("em recuperação no Dormitório")
	return TranslationServer.translate("%s está %s: %s.") % [entry.display_name, place, return_text(days).to_lower()]


static func infirmary_beds_at(level: int) -> int:
	var rule := recovery_rule("infirmary")
	if level <= 0:
		return 0
	return int(rule.get("Beds", 2)) if level == 1 else int(rule.get("BedsLevel2", 4))


static func infirmary_beds(campaign: Dictionary) -> int:
	return infirmary_beds_at(room_level(campaign, INFIRMARY))


## Os caídos em recuperação, na ordem do elenco.
static func fallen(campaign: Dictionary) -> Array:
	return campaign.roster.filter(func(h): return recovering(h))


## Quem pode partir agora (vivo, fora da recuperação e com arte).
static func ready_heroes(campaign: Dictionary) -> Array:
	return living(campaign).filter(func(h): return can_deploy(h))


## Os leitos livres vão para quem espera no Dormitório, na ordem do elenco; no leito, os dias nunca passam dos da
## Enfermaria.
static func _fill_beds(campaign: Dictionary) -> void:
	var free := infirmary_beds(campaign) - fallen(campaign).filter(func(h): return in_bed(h)).size()
	var bed_days := int(recovery_rule("infirmary").get("Days", 2))
	for entry in fallen(campaign):
		if free <= 0:
			return
		if not in_bed(entry):
			entry.recovery_bed = true
			# O carregado (#179) tem a parte dos dias também no leito (decisão do Lucas, 28/10).
			entry.recovery_days = mini(recovery_days(entry), _carried_part(entry, bed_days))
			free -= 1


## Os dias de quem a equipe carregou (#179): a parte do recovery.json (carried: Factor, para cima, no mínimo 1); os
## outros, os dias inteiros.
static func _carried_part(entry: Dictionary, days: int) -> int:
	if not entry.get("recovery_carried", false):
		return days
	return maxi(1, ceili(days * float(recovery_rule("carried").get("Factor", 1.0))))


## Os caídos de uma expedição chegam à Estação: vivos, com a vida baixa e os dias de recuperação. Devolve
## [{hero_id, days, bed}] para o relatório.
## carried (#179): os que a equipe levantou e carregou; chegam com uma parte dos dias (recovery.json, carried: Factor, para
## cima, no mínimo 1), na cama ou no Dormitório.
static func admit_fallen(campaign: Dictionary, hero_ids: Array, carried: Array = []) -> Array:
	var rule := recovery_rule("fallen")
	for hero_id in hero_ids:
		var entry = hero(campaign, hero_id)
		if entry == null:
			continue
		entry.alive = true
		entry.hp = clampi(int(rule.get("Hp", 1)), 1, int(entry.max_hp))
		entry.recovery_carried = carried.has(hero_id)
		entry.recovery_days = _carried_part(entry, maxi(1, int(rule.get("Days", 3))))
		entry.recovery_bed = false
		# Em recuperação, ninguém fica no posto (#119).
		entry.post = ""
		entry.recovery_treated = -1
	_fill_beds(campaign)
	var out: Array = []
	for hero_id in hero_ids:
		var entry = hero(campaign, hero_id)
		if entry == null:
			continue
		out.append({"hero_id": hero_id, "days": recovery_days(entry), "bed": in_bed(entry), "carried": carried.has(hero_id)})
	return out


static func _recover(entry: Dictionary) -> void:
	entry.recovery_days = 0
	entry.recovery_bed = false
	entry.recovery_carried = false
	# Os dias de cuidado fecham as feridas: volta ao Alojamento com a vida cheia.
	entry.hp = int(entry.max_hp)


## Passa um dia (um ciclo da Estação): cada caído fica um dia mais perto; quem chega a zero volta ao Alojamento, e o
## leito vago vai para quem espera. Devolve os ids de quem voltou.
static func tick_recovery(campaign: Dictionary) -> Array:
	var back: Array = []
	for entry in fallen(campaign):
		entry.recovery_days = recovery_days(entry) - 1
		if entry.recovery_days <= 0:
			_recover(entry)
			back.append(entry.id)
	_fill_beds(campaign)
	return back


## O curativo no leito ("" se pode): um por dia em cada herói, só num leito da Enfermaria.
static func treat_block(campaign: Dictionary, hero_id: String) -> String:
	var entry = hero(campaign, hero_id)
	if not recovering(entry):
		return TranslationServer.translate("Ninguém para tratar.")
	if not in_bed(entry):
		return TranslationServer.translate("O curativo só faz efeito num leito da Enfermaria.")
	if int(entry.get("recovery_treated", -1)) == int(campaign.station.cycle_number):
		return TranslationServer.translate("%s já recebeu um curativo hoje.") % entry.display_name
	var cost := int(recovery_rule("bandage").get("Cost", 1))
	if quantity(campaign, "bandages") < cost:
		return TranslationServer.translate("Sem curativos no estoque.")
	return ""


static func treat_fallen(campaign: Dictionary, hero_id: String) -> String:
	var block := treat_block(campaign, hero_id)
	if block != "":
		return block
	var entry = hero(campaign, hero_id)
	consume(campaign, "bandages", int(recovery_rule("bandage").get("Cost", 1)))
	entry.recovery_treated = int(campaign.station.cycle_number)
	entry.recovery_days = recovery_days(entry) - int(recovery_rule("bandage").get("Days", 1))
	if entry.recovery_days <= 0:
		_recover(entry)
		_fill_beds(campaign)
	return ""


## Esperar um dia sem expedição ("" se pode): só quando ninguém pode partir e há caídos (sem isso, o jogo travava com
## a equipe toda em recuperação). O dia passa como uma volta: a Estação gasta e produz, e a recuperação anda.
static func rest_block(campaign: Dictionary) -> String:
	# Esperar um dia não mexe no trem: com o Mercador na plataforma, também dá (#182).
	var block := _day_block(campaign)
	if block != "":
		return block
	# Quem está numa missão solo (#183) também volta com os dias.
	if fallen(campaign).is_empty() and AHSideMissions.running(campaign).is_empty():
		return TranslationServer.translate("Ninguém em recuperação.")
	if ready_heroes(campaign).size() >= _smallest_team(campaign):
		return TranslationServer.translate("Ainda há quem possa partir.")
	return ""


static func _smallest_team(campaign: Dictionary) -> int:
	var least := 4
	for info in AHJourneyRules.PHASES:
		if phase_unlocked(campaign, info.id):
			least = mini(least, int(J.team_limits(info.id).min))
	return least


static func rest_day(campaign: Dictionary) -> String:
	var block := rest_block(campaign)
	if block != "":
		return block
	run_cycle(campaign, "rest_%d" % (int(campaign.station.cycle_number) + 1), 0)
	campaign.station.last_rest = {"cycle": int(campaign.station.cycle_number), "recovered": tick_recovery(campaign)}
	return ""


## Saves de antes do #118: quem estava no memorial (ou caído fora de uma expedição) volta Caído e em recuperação, e o
## memorial fica vazio. Quem caiu na expedição em andamento volta Caído no fim dela. Idempotente.
static func _migrate_fallen(campaign: Dictionary) -> void:
	var expedition = campaign.get("session", {}).get("expedition")
	var team: Array = expedition.get("team", []) if typeof(expedition) == TYPE_DICTIONARY else []
	var back: Array = []
	for entry in campaign.get("memorial", []):
		var hero_id := String(entry.get("hero_id", ""))
		if hero_id == "" or team.has(hero_id):
			continue
		if hero(campaign, hero_id) == null:
			# O herói do memorial que não está mais no elenco volta com a classe e o nome de antes.
			var hero_class = GameData.row("classes", String(entry.get("class_id", "")))
			if hero_class == null:
				continue
			campaign.roster.append(Campaign.new_hero(hero_id, String(entry.class_id), String(entry.get("display_name", hero_id)), int(hero_class.BaseMaxHp), []))
		hero(campaign, hero_id).alive = false
	for entry in campaign.roster:
		for key in ["recovery_days", "recovery_treated"]:
			if not entry.has(key):
				entry[key] = 0 if key == "recovery_days" else -1
		if not entry.has("recovery_bed"):
			entry.recovery_bed = false
		if not entry.get("alive", true) and not team.has(entry.id):
			back.append(entry.id)
	admit_fallen(campaign, back)
	campaign.memorial = []


## A ordem em que o próximo passo sugere recuperar os cômodos, e o artigo de cada um no texto.
const NEXT_ROOMS := [FORGE, RESEARCH, DEPOT]
const ROOM_ARTICLE := {FORGE: "a ", RESEARCH: "o ", DEPOT: "o ", CANTEEN: "a ", BAR: "o ", INFIRMARY: "a ", DORMITORY: "o ",
	CHARACTERS: "o ", PREPARATION: "a "}


## Por que não dá para preparar uma partida agora ("" se dá).
static func preparation_block(campaign: Dictionary) -> String:
	var block := _day_block(campaign)
	# O Mercador (#182, parte 2, decisão do Lucas): ele é dispensado antes da Preparação. O motivo é curto: ele aparece
	# também no botão IR AO MAPA, numa linha.
	if block == "" and merchant_here(campaign):
		return TranslationServer.translate("Dispense o Sr. dos Trilhos antes de partir.")
	# O trem das missões solo (#183): quem voltou nele é recebido antes (o relatório chega com ele). Curto como o do
	# Mercador: numa linha no botão IR AO MAPA, também no texto Maior.
	if block == "" and AHSideMissions.train_pending(campaign):
		return TranslationServer.translate("Receba o trem antes de partir.")
	return block


## O que impede qualquer coisa do dia na Estação (partir, esperar um dia): a noite pendente ou a equipe fora.
static func _day_block(campaign: Dictionary) -> String:
	if campaign.night.phase != "none":
		return TranslationServer.translate("Conclua a noite no Dormitório antes de partir.")
	if not in_refuge(campaign):
		return TranslationServer.translate("A equipe já está numa expedição.")
	return ""


## A partida (ConfirmDeparture): equipe de quatro com ataque na posição, fase liberada, foco aberto e os suprimentos
## extras pagos em sementes. Monta a expedição e o corredor da fase. Devolve "" ou o motivo.
static func confirm_departure(campaign: Dictionary, team: Array, extra_food: int, seed_value: int, phase_id: String, focus: String = "") -> String:
	var block := preparation_block(campaign)
	if block != "":
		return block
	var unique := {}
	for hero_id in team:
		unique[hero_id] = true
	var limits := J.team_limits(phase_id)
	if unique.size() != team.size() or team.size() < limits.min or team.size() > limits.max:
		return TranslationServer.translate("Esta jornada pede %s diferentes na equipe.") % team_size_text(limits)
	for rank in range(1, team.size() + 1):
		var entry = hero(campaign, team[rank - 1])
		if entry == null or not entry.alive:
			return TranslationServer.translate("Só integrantes vivos podem partir.")
		if not can_deploy(entry):
			return deploy_block(entry)
		if attacks_from_rank(entry.class_id, rank, AHHeroSkills.equipped(entry)).is_empty():
			return TranslationServer.translate("%s não tem ataque na posição %d.") % [entry.display_name, rank]
	var team_block := validate_team(campaign, team, phase_id)
	if team_block != "":
		return team_block
	if focus != "" and focus_def(focus).is_empty():
		return TranslationServer.translate("Foco de rota desconhecido.")
	if not focus_available(campaign, focus):
		return TranslationServer.translate("Esse pedido não está aberto: o morador não está na Estação ou já recebeu o item.")
	if extra_food < 0 or J.FREE_FOOD + extra_food > J.MAX_FOOD:
		return TranslationServer.translate("Suprimentos acima do limite.")
	if extra_food * FOOD_COST > quantity(campaign, "seeds"):
		return TranslationServer.translate("Sementes insuficientes para os suprimentos selecionados.")
	if J.phase(phase_id).is_empty() or not phase_unlocked(campaign, phase_id):
		return TranslationServer.translate("Essa fase ainda está bloqueada.")
	adjust(campaign, "seeds", -extra_food * FOOD_COST)
	campaign.preferred_formation = team.duplicate()
	if not J.start_expedition(campaign, phase_id, seed_value):
		return TranslationServer.translate("A expedição não pôde começar.")
	# Só com a expedição começada: quem esperava no trem e ninguém decidiu vai embora com ele (#122), e quem parte deixa
	# o posto na Estação (#119).
	train_leaves(campaign)
	leave_posts(campaign, team)
	var expedition: Dictionary = campaign.session.expedition
	expedition.food = J.FREE_FOOD + extra_food
	expedition.focus = focus
	for entry in campaign.roster:
		if team.has(entry.id):
			entry.expeditions_count = int(entry.get("expeditions_count", 0)) + 1
	return ""


# ================================================================ volta à Estação

## Entrega da volta (FinishReturnToShelter): o saque pelo resultado (inteiro, metade ou nada), a carga do objetivo, o
## pedido do civil, a noite da volta, o ciclo da Estação e o trem com um candidato. Uma vez por expedição. Devolve o
## resumo para o relatório (também guardado em station.last_return).
static func finish_return(campaign: Dictionary) -> Dictionary:
	if campaign.night.phase != "none":
		return {}
	var session: Dictionary = campaign.get("session", {})
	var expedition = session.get("expedition")
	if expedition == null or session.get("result", "") == "" or campaign.last_returned_expedition_id == expedition.id:
		return {}
	campaign.last_returned_expedition_id = expedition.id
	var factor: float = {"victory": 1.0, "retreat": 0.5}.get(session.result, 0.0)
	var loot: Dictionary = expedition.loot
	# Em porcentagem inteira: o save volta com os números inteiros, e o relatório guardado precisa voltar igual.
	var delivered := {"result": session.result, "percent": roundi(factor * 100.0), "phase_id": expedition.phase_id,
		"seeds": floori(loot.get("seeds", 0) * factor), "scrap": floori(loot.get("scrap", 0) * factor),
		"fragments": floori(loot.get("fragments", 0) * factor), "water": floori(loot.get("water", 0) * factor),
		"supplies": floori(loot.get("supplies", 0) * factor), "request": "", "team": expedition.team.duplicate(),
		"food_left": maxi(0, int(expedition.food)), "stats": expedition.get("stats", {}).duplicate(true),
		"focus": String(expedition.get("focus", "")), "objective_done": bool(expedition.get("objective_done", false)), "unlocked_phase": ""}
	# A fase seguinte liberada pela primeira vitória (as expedições salvas antes do #60 não têm a marca: sem o chip).
	if session.result == "victory" and expedition.get("first_clear", false):
		for i in AHJourneyRules.PHASES.size() - 1:
			if AHJourneyRules.PHASES[i].id == expedition.phase_id:
				delivered.unlocked_phase = AHJourneyRules.PHASES[i + 1].id
	adjust(campaign, "seeds", delivered.seeds)
	adjust(campaign, "scrap", delivered.scrap)
	adjust(campaign, "fragments", delivered.fragments)
	campaign.station.water = int(campaign.station.water) + delivered.water
	adjust(campaign, SUPPLIES, delivered.supplies)
	# O resgate (#188): quem foi mandado para a Estação chega, até na derrota; a linha do relatório.
	delivered.rescue = AHRescue.on_return(campaign)
	# Pedido pessoal: o item volta inteiro na vitória e na retirada; na derrota fica para trás.
	var request: String = loot.get("request_item", "")
	if factor > 0.0 and is_resident(campaign, request) and not campaign.station.completed_requests.has(request):
		campaign.station.completed_requests.append(request)
		delivered.request = request
	# A skin que vem com a fase terminada (#138): liberada agora, com o aviso no relatório.
	delivered.skins = _grant_start_skins(campaign)
	for entry in campaign.roster:
		entry.expedition_uses = {}
		# Os abates da carreira (o campo já existia no herói, sem conta): as máquinas derrubadas nesta jornada (#60).
		entry.kills_count = int(entry.get("kills_count", 0)) + int(delivered.stats.get(entry.id, {}).get("downs", 0))
	if session.result == "victory" and campaign.last_completed_expedition_id != expedition.id:
		# O XP da jornada concluída (#90): cada um da equipe que voltou vivo; o relatório mostra junto com o das lutas.
		for hero_id in expedition.team:
			var member = hero(campaign, hero_id)
			if member != null and member.get("alive", true):
				var gained := AHHeroLevels.gain(member, int(AHHeroLevels.rule("journey").get("Xp", 0)))
				var line: Dictionary = delivered.stats.get(hero_id, {"damage": 0, "healing": 0, "downs": 0})
				line.xp = int(line.get("xp", 0)) + gained
				delivered.stats[hero_id] = line
		campaign.last_completed_expedition_id = expedition.id
		campaign.completed_expeditions = int(campaign.completed_expeditions) + 1
	# A primeira vitória em cada fase traz o que a equipe viu lá (#64): a camada da escada da fase, uma vez.
	delivered.story = ""
	var phase_id: String = expedition.get("phase_id", "")
	# A linha que cita o evento de história (a do interfone) só vem depois de a equipe ter visto o evento: a rota com a
	# Passagem só na travessia não abre o evento, e a linha fica para a próxima vitória.
	var story_seen: bool = not AHJourneyRules.STORY_REPORT_AFTER_EVENT.has(phase_id) or campaign.station.story_events.has(phase_id)
	if session.result == "victory" and story_seen and AHJourneyRules.STORY_REPORTS.has(phase_id) and not campaign.station.story_reports.has(phase_id):
		campaign.station.story_reports.append(phase_id)
		delivered.story = AHJourneyRules.STORY_REPORTS[phase_id]
	# A comida que sobrou vira suprimento e abre a noite; depois o ciclo da Estação e o trem.
	begin_night(campaign, expedition.id, expedition.team, int(expedition.food))
	var returning: int = expedition.team.filter(func(id): return hero(campaign, id) != null and hero(campaign, id).alive).size()
	delivered.returning = returning
	run_cycle(campaign, expedition.id, returning)
	# Ninguém morre (#118): o dia passa para quem já estava em recuperação, e quem caiu nesta expedição chega Caído
	# (fora da noite: dorme na Enfermaria ou no Dormitório, sem vigiar nem comer da noite).
	delivered.recovered = tick_recovery(campaign)
	# Os postos de quem ficou (#119): o que cada um rendeu; quem a Enfermaria pôs de pé volta no relatório.
	delivered.posts = run_posts(campaign, expedition.team)
	var digger_points := 0
	for post in delivered.posts:
		delivered.recovered.append_array(post.recovered)
		if post.room == AHStationGrid.DIG:
			digger_points += int(post.amount)
	# A escavação (#186): a comunidade e o escavador cavam a frente; o bloco aberto devolve o achado. Só as voltas contam.
	delivered.dig = AHStationGrid.run_dig(campaign, expedition.id, digger_points)
	delivered.fallen = admit_fallen(campaign, expedition.team.filter(func(id): return hero(campaign, id) != null and not hero(campaign, id).alive),
		expedition.get("carried", []))
	delivered.cycle = campaign.station.last_cycle.duplicate()
	# O trem da volta (#122): quem chegou, ou ninguém; o relatório diz.
	delivered.train = train_candidate_name(campaign) if train_on_return(campaign, expedition.id) else ""
	delivered.merchant = merchant_here(campaign)
	campaign.session = {"screen": "shelter", "result": "", "expedition": null, "event": null}
	campaign.station.last_return = delivered
	return delivered


# ================================================================ foco da rota

static func focus_def(focus_id: String) -> Dictionary:
	for entry in FOCI:
		if entry.id == focus_id:
			return entry
	return {}


static func focus_available(campaign: Dictionary, focus_id: String) -> bool:
	if focus_id == "":
		return true
	var entry := focus_def(focus_id)
	return not entry.is_empty() and (entry.civilian == "" or request_open(campaign, entry.civilian))


static func focus_label(focus_id: String) -> String:
	var entry := focus_def(focus_id)
	if not entry.is_empty() and entry.civilian != "":
		return TranslationServer.translate("Pedido: %s") % civilian(entry.civilian).name
	return {FOCUS_WATER: TranslationServer.translate("Água"), FOCUS_PARTS: TranslationServer.translate("Peças"), FOCUS_PROVISIONS: TranslationServer.translate("Provisões")}.get(focus_id, TranslationServer.translate("Rota básica"))


static func focus_reward_text(focus_id: String) -> String:
	var entry := focus_def(focus_id)
	if entry.is_empty():
		return ""
	if entry.civilian != "":
		return TranslationServer.translate(civilian(entry.civilian).request_item)
	return {FOCUS_WATER: TranslationServer.translate("+%d água"), FOCUS_PARTS: TranslationServer.translate("+%d sucata"), FOCUS_PROVISIONS: TranslationServer.translate("+%d suprimentos")}[focus_id] % entry.amount


## Próximo cômodo que a sucata ajudaria a recuperar ou melhorar, e quanta falta.
static func _needed_room(campaign: Dictionary) -> Array:
	var scrap := quantity(campaign, "scrap")
	for room_id in [FORGE, RESEARCH, DEPOT]:
		var cost := next_level_cost(campaign, room_id)
		# Soterrado (#186): a sucata não ajuda enquanto não houver vaga.
		if not cost.is_empty() and int(cost.get("scrap", 0)) > scrap and not AHStationGrid.buried(campaign, room_id):
			return [room_id, int(cost.scrap) - scrap]
	return ["", 0]


## O que a Estação mais precisa agora: água, provisões ou peças para um cômodo.
static func focus_recommended(campaign: Dictionary, team: int = 4) -> String:
	var f := forecast(campaign, team)
	if f.water + f.water_produced < f.water_consumed + team:
		return FOCUS_WATER
	if f.food + f.food_produced - f.food_civilians < f.food_night_need:
		return FOCUS_PROVISIONS
	if _needed_room(campaign)[0] != "":
		return FOCUS_PARTS
	return FOCUS_PROVISIONS


## Por que este foco importa agora (texto da Preparação).
static func focus_reason(campaign: Dictionary, focus_id: String, team: int = 4) -> String:
	var entry := focus_def(focus_id)
	if not entry.is_empty() and entry.civilian != "":
		var who := civilian(entry.civilian)
		return TranslationServer.translate("%s: %s Entregue, %s.") % [who.name, TranslationServer.translate(who.need), TranslationServer.translate(who.request_reward)]
	var f := forecast(campaign, team)
	match focus_id:
		FOCUS_WATER:
			return (TranslationServer.translate("Água: %d na estação; a equipe bebe %d na próxima expedição e vai faltar.") % [f.water, f.water_consumed]) if f.thirsty \
				else (TranslationServer.translate("Água: %d na estação, %d depois da próxima expedição.") % [f.water, f.water_after])
		FOCUS_PARTS:
			var need := _needed_room(campaign)
			return TranslationServer.translate("Sucata para relíquias e melhorias.") if need[0] == "" else TranslationServer.translate("Faltam %d sucatas para %s.") % [need[1], _room_the(need[0])]
		FOCUS_PROVISIONS:
			return TranslationServer.translate("Suprimentos: %d de %d; a noite da volta pede %d.") % [f.food, f.food_capacity, f.food_night_need]
	return TranslationServer.translate("Sem objetivo: só o que aparecer nas casas.")


static func _room_the(room_id: String) -> String:
	return {FORGE: TranslationServer.translate("a Forja"), RESEARCH: TranslationServer.translate("a Pesquisa"), DEPOT: TranslationServer.translate("o Depósito")}.get(room_id, TranslationServer.translate("um cômodo"))


## Depois do sorteio das três casas: garante uma casa da loja do foco (troca a última porta por uma dessa loja).
static func choose_doors(focus_id: String, doors: Array, door_shops: Array) -> void:
	var entry := focus_def(focus_id)
	if entry.is_empty() or doors.is_empty():
		return
	if doors.any(func(d): return d < door_shops.size() and door_shops[d] == entry.shop):
		return
	for door in door_shops.size():
		if door_shops[door] == entry.shop and not doors.has(door):
			doors[doors.size() - 1] = door
			doors.sort()
			return


## Marca o ponto-objetivo na primeira casa aberta da loja do foco (sempre um achado fixo, nunca o ponto com escolha).
static func mark_objective(focus_id: String, route: Dictionary) -> void:
	var entry := focus_def(focus_id)
	if entry.is_empty():
		return
	for site in route.sites:
		if site.shop != entry.shop or site.locked:
			continue
		while site.spots.size() <= entry.spot:
			site.spots.append({"choice": false, "searched": false})
		site.spots[entry.spot].choice = false
		site.objective_spot = entry.spot
		return


## Ponto vasculhado: se for o objetivo, soma o achado ao saque uma vez só. Devolve o texto do objetivo ("" se não).
static func on_search(campaign: Dictionary, site_index: int, spot_index: int) -> String:
	var expedition: Dictionary = campaign.session.expedition
	var entry := focus_def(expedition.get("focus", ""))
	var sites: Array = expedition.corridor.sites
	if entry.is_empty() or expedition.get("objective_done", false) or site_index < 0 or site_index >= sites.size() \
			or int(sites[site_index].get("objective_spot", -1)) != spot_index:
		return ""
	return grant_objective(campaign)


## Soma o achado do foco ao saque uma vez só e devolve o texto do objetivo (GrantObjective): a casa da rua ou o prop do
## cenário.
static func grant_objective(campaign: Dictionary) -> String:
	var expedition: Dictionary = campaign.session.expedition
	var entry := focus_def(expedition.get("focus", ""))
	if entry.is_empty() or expedition.get("objective_done", false):
		return ""
	expedition.objective_done = true
	var loot: Dictionary = expedition.loot
	if entry.civilian != "":
		loot.request_item = entry.civilian
	else:
		var key: String = {FOCUS_WATER: "water", FOCUS_PARTS: "scrap", FOCUS_PROVISIONS: "supplies"}[entry.id]
		loot[key] = int(loot.get(key, 0)) + entry.amount
	return TranslationServer.translate(" Objetivo cumprido (%s): %s, entregue na volta.") % [focus_label(entry.id), focus_reward_text(entry.id)]


# ================================================================ limites e postos (#119)

## Os cômodos com um posto para quem fica na Estação (um herói por cômodo).
const JOB_ROOMS := [RESEARCH, FORGE, CANTEEN, INFIRMARY]


static func _job_level_value(name: String, index: int, fallback: int) -> int:
	var row = GameData.row("hero_jobs", name)
	var levels: Array = row.get("Levels", []) if row != null else []
	if levels.is_empty():
		return fallback
	return int(levels[clampi(index, 0, levels.size() - 1)])


## Quantos heróis a Estação comporta: o nível do Alojamento (data/hero-jobs.json). Quem está em recuperação conta.
static func hero_limit(campaign: Dictionary) -> int:
	return hero_limit_at(room_level(campaign, CHARACTERS))


## Quantos heróis o Alojamento comporta num nível (1 a 4).
static func hero_limit_at(level: int) -> int:
	return mini(MAX_ROSTER, _job_level_value("limit_heroes", level - 1, MAX_ROSTER))


## Quantos ajudantes (os civis) a Estação comporta: o nível do Dormitório.
static func helper_limit(campaign: Dictionary) -> int:
	return helper_limit_at(room_level(campaign, DORMITORY))


## Quantos ajudantes cabem num nível do Dormitório (1, no chão; 2, com os beliches).
static func helper_limit_at(level: int) -> int:
	return _job_level_value("limit_helpers", level - 1, CIVILIANS.size())


static func heroes_full(campaign: Dictionary) -> bool:
	return living(campaign).size() >= hero_limit(campaign)


static func helpers_full(campaign: Dictionary) -> bool:
	return campaign.station.residents.size() >= helper_limit(campaign)


## "Heróis 5 de 6 · Ajudantes 1 de 3": a barra da Estação e a Sala.
static func limits_text(campaign: Dictionary) -> String:
	return TranslationServer.translate("Heróis %d de %d · Ajudantes %d de %d") % [living(campaign).size(), hero_limit(campaign),
		campaign.station.residents.size(), helper_limit(campaign)]


## Os postos abertos: os cômodos com posto já recuperados e, com entulho para cavar, o de escavador (#186).
static func job_rooms(campaign: Dictionary) -> Array:
	var out: Array = JOB_ROOMS.filter(func(id): return room_available(campaign, id))
	if AHStationGrid.dig_target(campaign) != "":
		out.append(AHStationGrid.DIG)
	return out


## O nome do posto: o do cômodo ou "Escavação".
static func post_name(room_id: String) -> String:
	if room_id == AHStationGrid.DIG:
		return TranslationServer.translate("Escavação")
	return TranslationServer.translate(room_def(room_id).get("name", ""))


static func job_rule(room_id: String) -> Dictionary:
	var row = GameData.row("hero_jobs", "job_%s" % room_id)
	return row if row != null else {}


## O posto do herói ("" sem posto).
static func post_of(entry) -> String:
	return String(entry.get("post", "")) if entry != null else ""


## "na Forja", "no Centro de Pesquisa": o cômodo com a preposição certa (o artigo de ROOM_ARTICLE).
static func room_in(room_id: String) -> String:
	if room_id == AHStationGrid.DIG:
		return TranslationServer.translate("na escavação")
	var name := TranslationServer.translate(room_def(room_id).name)
	return (TranslationServer.translate("no %s") if ROOM_ARTICLE.get(room_id, "") == "o " else TranslationServer.translate("na %s")) % name


## "da Forja", "do Centro de Pesquisa".
static func room_from(room_id: String) -> String:
	if room_id == AHStationGrid.DIG:
		return TranslationServer.translate("da escavação")
	var name := TranslationServer.translate(room_def(room_id).name)
	return (TranslationServer.translate("do %s") if ROOM_ARTICLE.get(room_id, "") == "o " else TranslationServer.translate("da %s")) % name


## Quem trabalha no cômodo, ou null.
static func worker(campaign: Dictionary, room_id: String):
	for entry in living(campaign):
		if post_of(entry) == room_id:
			return entry
	return null


## O que o herói rende no posto a cada volta: a base, mais a espécie e os traços (data/hero-jobs.json), nunca menos que 0.
static func post_yield(entry: Dictionary, room_id: String) -> int:
	var amount := int(job_rule(room_id).get("Base", 0))
	for row in GameData.table("hero_jobs").values():
		if String(row.get("Room", "")) == room_id and String(row.get("ClassId", "")) == String(entry.class_id):
			amount += int(row.get("Add", 0))
		elif row.has("Perk") and entry.get("perks", []).has(String(row.Perk)):
			amount += int(row.get("Add", 0))
	return maxi(0, amount)


## "+2 fragmentos por volta": o rendimento em texto.
static func yield_text(room_id: String, amount: int) -> String:
	match String(job_rule(room_id).get("Unit", "")):
		"fragments":
			return TranslationServer.translate("+%d fragmento por dia") % amount if amount == 1 else TranslationServer.translate("+%d fragmentos por dia") % amount
		"scrap":
			return TranslationServer.translate("+%d sucata por dia") % amount if amount == 1 else TranslationServer.translate("+%d sucatas por dia") % amount
		"supplies":
			return TranslationServer.translate("+%d suprimento por dia") % amount if amount == 1 else TranslationServer.translate("+%d suprimentos por dia") % amount
		"days":
			return TranslationServer.translate("−1 dia de recuperação para %d caído por dia") % amount if amount == 1 \
				else TranslationServer.translate("−1 dia de recuperação para %d caídos por dia") % amount
		"dig":
			return TranslationServer.translate("+%d ponto de obra por dia") % amount if amount == 1 else TranslationServer.translate("+%d pontos de obra por dia") % amount
	return ""


## Por que o herói não pode ficar no posto ("" quando pode). room_id "" tira do posto.
static func post_block(campaign: Dictionary, hero_id: String, room_id: String) -> String:
	var entry = hero(campaign, hero_id)
	if entry == null or not entry.alive:
		return TranslationServer.translate("Esse herói não está na Estação.")
	if room_id == "":
		return ""
	if recovering(entry):
		return TranslationServer.translate("%s está em recuperação e não trabalha agora.") % entry.display_name
	if AHSideMissions.away(entry):
		return AHSideMissions.away_text(entry)
	if room_id == AHStationGrid.DIG and AHStationGrid.dig_target(campaign) == "":
		return TranslationServer.translate("Não há entulho para escavar.")
	if not job_rooms(campaign).has(room_id):
		return TranslationServer.translate("Esse cômodo ainda não tem posto.")
	return ""


## Põe o herói no posto do cômodo (quem estava lá fica sem posto) ou o tira ("" ).
static func set_post(campaign: Dictionary, hero_id: String, room_id: String) -> String:
	var block := post_block(campaign, hero_id, room_id)
	if block != "":
		return block
	var previous = worker(campaign, room_id) if room_id != "" else null
	if previous != null and previous.id != hero_id:
		previous.post = ""
	hero(campaign, hero_id).post = room_id
	return ""


## Quem parte na equipe deixa o posto (a Preparação avisa antes).
static func leave_posts(campaign: Dictionary, team: Array) -> void:
	for hero_id in team:
		var entry = hero(campaign, hero_id)
		if entry != null:
			entry.post = ""


## Na volta: cada posto ocupado por quem ficou rende o seu. Devolve [{hero_id, room, amount}].
static func run_posts(campaign: Dictionary, team: Array) -> Array:
	var out: Array = []
	for room_id in job_rooms(campaign):
		var entry = worker(campaign, room_id)
		if entry == null or team.has(entry.id) or recovering(entry):
			continue
		var amount := post_yield(entry, room_id)
		match String(job_rule(room_id).get("Unit", "")):
			"fragments":
				adjust(campaign, "fragments", amount)
			"scrap":
				adjust(campaign, "scrap", amount)
			"supplies":
				# Até o que o Depósito guarda: o excesso estraga, como o da Cantina.
				var room := maxi(0, supply_capacity(campaign) - quantity(campaign, SUPPLIES))
				amount = mini(amount, room)
				adjust(campaign, SUPPLIES, amount)
		var back: Array = []
		if String(job_rule(room_id).get("Unit", "")) == "days":
			var helped := 0
			for patient in fallen(campaign):
				if helped >= amount:
					break
				patient.recovery_days = recovery_days(patient) - 1
				if patient.recovery_days <= 0:
					_recover(patient)
					back.append(patient.id)
				helped += 1
			amount = helped
			_fill_beds(campaign)
		out.append({"hero_id": entry.id, "room": room_id, "amount": amount, "recovered": back})
	return out


## Saves de antes do #119: ninguém tem posto, e o Alojamento cresce até caber quem já mora lá.
static func _migrate_posts(campaign: Dictionary) -> void:
	for entry in campaign.get("roster", []):
		if not entry.has("post"):
			entry.post = ""
	var rooms: Dictionary = campaign.station.rooms
	while hero_limit(campaign) < living(campaign).size() and room_level(campaign, CHARACTERS) < int(room_def(CHARACTERS).max_level):
		rooms[CHARACTERS] = room_level(campaign, CHARACTERS) + 1


# ---------------------------------------------------------------- skins (#138)

## As skins que a campanha já ganhou (data/skins.json, Unlock): "start" vem liberada; "phase:<id>" vem ao terminar a
## fase (a Ronda do Bento, na fase 4: decisão do Lucas, #138). Na campanha nova, nos saves antigos (quem já terminou a
## fase ganha ao abrir) e na volta da expedição. Devolve as que liberou agora, para o aviso do relatório.
## Ao abrir o save (on_load), a fase da expedição em curso fica para a volta: o guardião caiu, mas o aviso vem no
## relatório, não em silêncio ao reabrir o jogo no meio da jornada.
static func _grant_start_skins(campaign: Dictionary, on_load: bool = false) -> Array:
	var granted: Array = []
	var open = campaign.get("session", {}).get("expedition") if on_load else null
	var pending := String(open.get("phase_id", "")) if typeof(open) == TYPE_DICTIONARY else ""
	for row in GameData.table("skins").values():
		var unlock := String(row.get("Unlock", ""))
		var phase := unlock.trim_prefix("phase:")
		var earned: bool = unlock == "start" or (unlock.begins_with("phase:") and phase != pending and campaign.get("completed_phases", []).has(phase))
		if earned and not campaign.unlocked_skins.has(String(row.Name)):
			campaign.unlocked_skins.append(String(row.Name))
			granted.append(String(row.Name))
	return granted


## A skin está liberada nesta campanha (a padrão sempre está).
static func skin_unlocked(campaign: Dictionary, skin_id: String) -> bool:
	return skin_id == AHSkins.DEFAULT or campaign.get("unlocked_skins", []).has(skin_id)


## Por que a skin ainda não se escolhe ("" se já está liberada).
static func skin_lock_reason(campaign: Dictionary, skin_id: String) -> String:
	if skin_unlocked(campaign, skin_id):
		return ""
	var row = GameData.row("skins", skin_id)
	# Unlock "phase:<id>": o motivo diz qual fase termina; "boss:<id>" (os desafios dos chefes, #95), de onde vem; as
	# outras ficam só bloqueadas.
	if row != null and String(row.get("Unlock", "")).begins_with("phase:"):
		var phase: Dictionary = AHJourneyRules.phase(String(row.Unlock).trim_prefix("phase:"))
		return TranslationServer.translate("Ainda bloqueada: vem ao terminar %s.") % TranslationServer.translate(String(phase.get("name", "")))
	if row != null and String(row.get("Unlock", "")).begins_with("boss"):
		return TranslationServer.translate("Ainda bloqueada: vem com os desafios dos chefes.")
	return TranslationServer.translate("Ainda bloqueada.")


## Vestir uma skin (só visual, fora da expedição e sem custo). Devolve o erro, ou "".
static func choose_skin(campaign: Dictionary, hero_id: String, skin_id: String) -> String:
	var entry = hero(campaign, hero_id)
	if entry == null:
		return TranslationServer.translate("Esse herói não está na Estação.")
	if skin_id != AHSkins.DEFAULT:
		var row = GameData.row("skins", skin_id)
		if row == null or String(row.get("HeroId", "")) != hero_id:
			return TranslationServer.translate("Essa roupa não é desse herói.")
		if not AHSkins.has_art(skin_id):
			return TranslationServer.translate("Essa roupa ainda não chegou.")
	if not skin_unlocked(campaign, skin_id):
		return skin_lock_reason(campaign, skin_id)
	if campaign.get("session", {}).get("expedition") != null:
		return TranslationServer.translate("A roupa se troca na Estação, fora da expedição.")
	entry.skin_id = skin_id
	return ""


## Libera todas as skins (a barra de Admin). Devolve quantas eram novas.
static func unlock_all_skins(campaign: Dictionary) -> int:
	var added := 0
	# Só as que têm arte: a skin sem arte não aparece na Sala nem se veste, e não conta como liberada.
	for row in GameData.table("skins").values():
		if AHSkins.has_art(String(row.Name)) and not campaign.unlocked_skins.has(String(row.Name)):
			campaign.unlocked_skins.append(String(row.Name))
			added += 1
	return added

