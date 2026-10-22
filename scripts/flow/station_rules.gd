## Regras da Estação Raiz e da campanha entre expedições, sem cena: port de FAHStationRooms, FAHStationEconomy,
## FAHStationCivilians, FAHNightRestRules, FAHShelterRules, FAHRouteFocus e da partida e da volta de FAHGameFlowRules
## (Source/AfterHumans/Flow). Os números são os aprovados pelo Lucas na Unreal (Docs/Systems/station-*.md).
##
## Estado (na campanha):
##   station: {water, rooms {id: nível}, cycle_number, last_cycle_expedition_id, last_cycle {...}, residents [],
##             candidate_queue [], hungry_civilians [], completed_requests [], train {phase, candidate_id,
##             expedition_id, accepted}, last_return {...}}
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
## Cômodos: básico (nível 1 desde o começo), nível máximo e o custo de cada nível (do N ao N+1). Sem custo, a
## recuperação chega numa próxima fase do jogo. A Forja é o piloto com dois níveis.
const ROOMS := [
	{"id": CANTEEN, "name": "Cantina", "basic": true, "max_level": 1, "costs": []},
	{"id": DEPOT, "name": "Depósito", "basic": true, "max_level": 2, "costs": [{}, {"scrap": 5, "fragments": 1}]},
	{"id": PREPARATION, "name": "Preparação", "basic": true, "max_level": 1, "costs": []},
	{"id": CHARACTERS, "name": "Sala dos Personagens", "basic": true, "max_level": 1, "costs": []},
	{"id": FORGE, "name": "Forja", "basic": false, "max_level": 2, "costs": [{"scrap": 4, "fragments": 0}, {"scrap": 6, "fragments": 2}]},
	{"id": RESEARCH, "name": "Centro de Pesquisa", "basic": false, "max_level": 1, "costs": [{"scrap": 3, "fragments": 2}]},
	{"id": DORMITORY, "name": "Dormitório", "basic": false, "max_level": 1, "costs": []},
	{"id": BAR, "name": "Bar", "basic": false, "max_level": 1, "costs": []},
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
		"need": "Quer recuperar um caderno de receitas numa cozinha abandonada.",
		"benefit": "Na Cantina com energia, produz mais 2 suprimentos por volta.",
		"drawback": "Cozinhar gasta água: bebe 2 por volta.",
		"request_item": "o caderno de receitas", "request_reward": "a Cantina rende mais 1 suprimento por volta",
		"food": 1, "water": 2, "room": CANTEEN},
	{"id": OTTO, "name": "Otto", "species": "Castor", "role": "Técnico", "trait": "Paciente, testa antes de improvisar.",
		"need": "Quer recuperar a maleta da equipe ferroviária.",
		"benefit": "Mantém o gerador: mais 1 de capacidade de energia. Recuperar e melhorar cômodos custa 1 sucata a menos.",
		"drawback": "Trabalho pesado: come 2 suprimentos por volta.",
		"request_item": "a maleta da equipe ferroviária", "request_reward": "mais 1 de capacidade de energia",
		"food": 2, "water": 1, "room": FORGE},
	{"id": CORA, "name": "Cora", "species": "Gambá", "role": "Pesquisadora", "trait": "Metódica e cética.",
		"need": "Quer recuperar registros de monitoramento para comparar a água local.",
		"benefit": "Com a Pesquisa recuperada e ligada, traz 1 fragmento por volta.",
		"drawback": "Equipamentos ligados o tempo todo: a Pesquisa gasta 1 de energia a mais.",
		"request_item": "os registros de monitoramento", "request_reward": "mais 1 fragmento por volta",
		"food": 1, "water": 1, "room": RESEARCH},
]

# ---------------------------------------------------------------- noite e refúgio

const SUPPLY_COST_SEEDS := 2
const MAX_ROSTER := 12
const RECRUIT_COST := 10
const TRAUMA_COST := 5
## Uma equipe leva no máximo dois animais da mesma classe.
const MAX_PER_CLASS := 2
## Suprimentos comprados na partida, além dos 4 de graça (FoodCost).
const FOOD_COST := 2
const NAME_POOLS := {
	"cao": ["Bento", "Brutus", "Argos", "Tobias", "Balto", "Rufus", "Lorde", "Barão", "Max", "Trovão", "Thor", "Snoopy", "Fumaça", "Pluto", "Bóris"],
	"gato": ["Nix", "Sombra", "Salem", "Bastet", "Maya", "Nuvem", "Loki", "Félix", "Chico", "Puma", "Luna", "Zelda", "Veludo", "Mimi", "Jasper"],
	"sapo": ["Íris", "Minerva", "Atena", "Garganta", "Hórus", "Bubo", "Estrela", "Eco", "Vigília", "Sábio", "Pluma", "Penumbra", "Gisela", "Noctis"],
	"coruja": ["Véspera", "Sereno", "Jasmim", "Pacato", "Rio", "Sol", "Dengoso", "Flora", "Paz", "Brisa", "Lótus", "Chico Rei", "Pingo", "Mel", "Cacau"],
	"rato": ["Risco", "Pólvora", "Chispola", "Pipeta", "Ferrugem", "Duto", "Pipoca", "Veneno", "Mola", "Faísca", "Fuligem", "Squeeze", "Engrenagem"],
	"tatu": ["Casco", "Carapaça", "Couraça", "Fortaleza", "Tromba", "Pedregulho", "Titan", "Escudo", "Baluarte", "Granito", "Tanque", "Rochedo"],
}

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
	campaign.station.candidate_queue = CIVILIANS.map(func(c): return c.id)
	campaign.night = _night_defaults()
	campaign.pending_offers = []
	campaign.completed_expeditions = 0
	campaign.last_completed_expedition_id = ""
	campaign.last_returned_expedition_id = ""


## Save anterior à Estação (fase 2): completa o que falta. Como na Unreal (MigrateLegacy), um save sem cômodos fica
## com todos recuperados, como o jogador já os usava. Idempotente.
static func migrate(campaign: Dictionary) -> void:
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
	for key in ["pending_offers"]:
		if typeof(campaign.get(key)) != TYPE_ARRAY:
			campaign[key] = []
	for key in ["completed_expeditions"]:
		campaign[key] = int(campaign.get(key, 0))
	for key in ["last_completed_expedition_id", "last_returned_expedition_id"]:
		campaign[key] = String(campaign.get(key, ""))
	if typeof(campaign.inventory.get("items")) != TYPE_DICTIONARY:
		campaign.inventory.items = {}
	# "departing" é só a animação do trem saindo (4 s na tela). Um save gravado nesse meio (o jogo fechou) abriria com o
	# trem partindo para sempre: a Preparação ficava bloqueada e a plataforma sem botão.
	finish_departure(campaign)


static func _station_defaults() -> Dictionary:
	return {
		"water": INITIAL_WATER, "rooms": {}, "cycle_number": 0, "last_cycle_expedition_id": "", "last_cycle": {},
		"residents": [], "candidate_queue": [], "hungry_civilians": [], "completed_requests": [],
		"train": _train_defaults(), "last_return": {},
	}


static func _night_defaults() -> Dictionary:
	return {"phase": "none", "number": 0, "expedition_id": "", "participants": [], "watch_hero_id": "", "event_id": "",
		"results": [], "supplies_consumed": 0, "thirsty": false}


static func _train_defaults() -> Dictionary:
	return {"phase": "none", "candidate_id": "", "expedition_id": "", "accepted": false}


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
	if room.is_empty() or current >= room.max_level or current >= room.costs.size() or room.costs[current].is_empty():
		return {}
	var cost: Dictionary = room.costs[current].duplicate()
	if civilian_working(campaign, OTTO):
		cost.scrap = maxi(0, int(cost.get("scrap", 0)) - OTTO_SCRAP_DISCOUNT)
	return cost


## "" se pode subir agora; senão, o que falta.
static func upgrade_block(campaign: Dictionary, room_id: String) -> String:
	var cost := next_level_cost(campaign, room_id)
	if cost.is_empty():
		var room := room_def(room_id)
		return "A recuperação deste cômodo chega numa próxima fase." if not room.is_empty() and room_level(campaign, room_id) < room.max_level \
			else "Este cômodo já está no nível máximo."
	var scrap := quantity(campaign, "scrap")
	var fragments := quantity(campaign, "fragments")
	if scrap < int(cost.get("scrap", 0)) or fragments < int(cost.get("fragments", 0)):
		return "Faltam %s." % cost_text({"scrap": maxi(0, int(cost.get("scrap", 0)) - scrap), "fragments": maxi(0, int(cost.get("fragments", 0)) - fragments)})
	return ""


## Sobe um nível e cobra uma vez. from_level é o nível que o jogador viu: clique repetido não compra o seguinte.
static func upgrade_room(campaign: Dictionary, room_id: String, from_level: int) -> String:
	if room_level(campaign, room_id) != from_level:
		return "Este cômodo já mudou de nível."
	var block := upgrade_block(campaign, room_id)
	if block != "":
		return block
	var cost := next_level_cost(campaign, room_id)
	adjust(campaign, "scrap", -int(cost.get("scrap", 0)))
	adjust(campaign, "fragments", -int(cost.get("fragments", 0)))
	campaign.station.rooms[room_id] = from_level + 1
	return ""


static func relic_cost(campaign: Dictionary) -> int:
	return RELIC_COST_UPGRADED if room_level(campaign, FORGE) >= 2 else RELIC_COST_BASE


static func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	var scrap := int(cost.get("scrap", 0))
	var fragments := int(cost.get("fragments", 0))
	if scrap > 0:
		parts.append("%d %s" % [scrap, "sucata" if scrap == 1 else "sucatas"])
	if fragments > 0:
		parts.append("%d %s" % [fragments, "fragmento" if fragments == 1 else "fragmentos"])
	return "sem custo" if parts.is_empty() else " e ".join(parts)


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
		food_note = ("! Faltam %d nesta noite" % (sleepers - food)) if food_short else "Abastecida · demanda %d" % sleepers
	elif food > f.food_capacity:
		food_note = "! %d acima de %d" % [food - f.food_capacity, f.food_capacity]
	elif food_short:
		food_note = "! Falta na volta"
	else:
		food_note = "Próxima volta: %d" % f.food_after_night
	var power_short: bool = not f.unpowered_rooms.is_empty()
	return [
		{"id": "food", "label": "COMIDA", "icon": "lobby-food", "value": "%d / %d suprimentos" % [food, f.food_capacity],
			"note": food_note, "warn": food_short or food > f.food_capacity,
			"tip": "Estoque e capacidade do Depósito. Na próxima volta, sem saque: +%d da Cantina, %d para os moradores, %d estragam, %d para a noite; restam %d." % [
				f.food_produced, f.food_civilians, f.food_spoiled, f.food_night_need, f.food_after_night]},
		{"id": "water", "label": "ÁGUA", "icon": "lobby-water", "value": "%d em estoque" % f.water,
			"note": "! Falta na volta" if f.thirsty else "Próxima volta: %d" % f.water_after, "warn": f.thirsty,
			"tip": "Na próxima volta, sem saque: o coletor repõe %d e a equipe e os moradores bebem %d; restam %d. Sem água, o descanso reduz menos instinto." % [
				f.water_produced, f.water_consumed, f.water_after]},
		{"id": "power", "label": "ENERGIA", "icon": "lobby-energy", "value": "%d / %d em uso" % [f.power_used, f.power_capacity],
			"note": ("! %d %s sem energia" % [f.unpowered_rooms.size(), "sala" if f.unpowered_rooms.size() == 1 else "salas"]) if power_short \
				else "%d %s" % [maxi(0, f.power_capacity - f.power_used), "livre" if f.power_capacity - f.power_used == 1 else "livres"],
			"warn": power_short, "tip": "Os cômodos ligados gastam energia; sem ela, param."},
	]


## O que o cômodo faz no nível dado (texto da tela).
static func room_benefit(room_id: String, level: int) -> String:
	match room_id:
		FORGE:
			if level <= 0:
				return "Oficina vazia. Recuperada, fabrica relíquias e gasta 1 de energia."
			return "Fabrica relíquias por 3 sucatas. Gasta 1 de energia." if level == 1 else "Bancada melhorada: relíquias por 2 sucatas."
		RESEARCH:
			return "Laboratório vazio. Recuperado, libera as melhorias de classe e gasta 1 de energia." if level <= 0 \
				else "Melhorias de classe com fragmentos. Gasta 1 de energia."
		DORMITORY:
			return "Quarto por recuperar: só os beliches de ferro. A equipe dorme aqui depois de cada volta." if level <= 0 \
				else "Descanso da comunidade."
		BAR:
			return "Salão vazio, sem uso por enquanto." if level <= 0 else "Um lugar para conversar e fazer uma pausa."
		CANTEEN:
			return "Com energia, produz 2 suprimentos por expedição."
		DEPOT:
			return "Guarda até 12 suprimentos; o excesso estraga na volta." if level <= 1 else "Prateleiras extras: guarda até 20."
		PREPARATION:
			return "Escolher a fase, a equipe, o foco da rota e os suprimentos da partida."
		CHARACTERS:
			return "Elenco, recrutar, tratar trauma, relíquias e o memorial."
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
	f.food_produced = (CANTEEN_FOOD + (dora_food if civilian_working(campaign, DORA) else 0)) if running.has(CANTEEN) else 0
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
	station.last_cycle = {
		"number": station.cycle_number, "expedition_id": expedition_id, "food_produced": f.food_produced,
		"food_spoiled": f.food_spoiled, "food_civilians": f.food_civilians, "fragments_produced": f.fragments_produced,
		"hungry_civilians": f.hungry_civilians.duplicate(), "water_produced": f.water_produced,
		"water_consumed": mini(f.water_consumed, f.water + f.water_produced), "thirsty": f.thirsty,
		"power_used": f.power_used, "power_capacity": f.power_capacity,
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
	return campaign.station.train.phase != "none"


## Na volta: o trem traz o primeiro da fila, uma vez por expedição.
static func train_on_return(campaign: Dictionary, expedition_id: String) -> bool:
	var station: Dictionary = campaign.station
	if expedition_id == "" or station.train.phase != "none" or station.train.expedition_id == expedition_id:
		return false
	station.candidate_queue = station.candidate_queue.filter(func(id): return not station.residents.has(id) and not civilian(id).is_empty())
	if station.candidate_queue.is_empty():
		return false
	station.train = {"phase": "waiting", "candidate_id": station.candidate_queue[0], "expedition_id": expedition_id, "accepted": false}
	return true


## Acolher ou recusar o candidato que espera na plataforma. Recusado, volta ao fim da fila.
static func decide_candidate(campaign: Dictionary, candidate_id: String, accept: bool) -> String:
	var station: Dictionary = campaign.station
	if station.train.phase != "waiting" or station.train.candidate_id != candidate_id or candidate_id == "":
		return "Ninguém está esperando na plataforma."
	station.candidate_queue.erase(candidate_id)
	if accept:
		if not station.residents.has(candidate_id):
			station.residents.append(candidate_id)
	else:
		station.candidate_queue.append(candidate_id)
	station.train.accepted = accept
	station.train.phase = "departing"
	return ""


## Fim da partida do trem: a visita acaba (guarda a expedição, para a mesma volta não trazer o trem de novo).
static func finish_departure(campaign: Dictionary) -> bool:
	var train: Dictionary = campaign.station.train
	if train.phase != "departing":
		return false
	campaign.station.train = {"phase": "none", "candidate_id": "", "expedition_id": train.expedition_id, "accepted": false}
	return true


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


## A noite: quem dorme come um suprimento e recupera vida e instinto; o vigia fica acordado. O evento sai do número.
static func resolve_night(campaign: Dictionary) -> bool:
	var night: Dictionary = campaign.night
	if not in_refuge(campaign) or night.phase != "planning":
		return false
	var awake: Array = night.participants.filter(func(id): return hero(campaign, id) != null and hero(campaign, id).alive)
	var watch = hero(campaign, night.watch_hero_id)
	if awake.size() <= 1 or watch == null or not watch.alive or watch.hp <= 0 or not night.participants.has(night.watch_hero_id):
		night.watch_hero_id = ""
	night.event_id = "distant_noise" if int(night.number) % 2 == 0 else "quiet"
	var sleepers: int = awake.filter(func(id): return id != night.watch_hero_id).size()
	if quantity(campaign, SUPPLIES) < sleepers:
		night.event_id = "short_supplies"
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
			var noise := 3 if night.event_id == "distant_noise" and night.watch_hero_id == "" else 0
			var thirst := THIRST_INSTINCT_PENALTY if night.thirsty else 0
			entry.instinct = clampi(entry.instinct - (15 if result.fed else 5) + noise + thirst, 0, 200)
			result.hp_recovered = entry.hp - before_hp
			result.instinct_reduced = before_instinct - entry.instinct
		night.results.append(result)
	if hungry:
		night.event_id = "short_supplies"
	elif night.thirsty:
		night.event_id = "no_water"
	night.phase = "dawn"
	return true


## A prévia da noite (os cartões do Dormitório): para cada participante vivo, se vigia, se come e quanto recupera, na
## mesma ordem e com as mesmas contas de resolve_night. {heroes: [{hero_id, watch, fed, hp_gain, instinct_change}],
## needed, available}.
static func night_preview(campaign: Dictionary) -> Dictionary:
	var night: Dictionary = campaign.night
	var supplies := quantity(campaign, SUPPLIES)
	var awake: Array = night.participants.filter(func(id): return hero(campaign, id) != null and hero(campaign, id).alive)
	var watch_id: String = night.watch_hero_id if awake.size() > 1 and awake.has(night.watch_hero_id) else ""
	var event_noise: bool = int(night.number) % 2 == 0 and watch_id == ""
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
			var change := -(15 if row.fed else 5) + (3 if event_noise else 0) + (THIRST_INSTINCT_PENALTY if night.thirsty else 0)
			row.instinct_change = clampi(int(entry.instinct) + change, 0, 200) - int(entry.instinct)
		out.heroes.append(row)
	return out


static func finish_dawn(campaign: Dictionary) -> bool:
	if not in_refuge(campaign) or campaign.night.phase != "dawn":
		return false
	campaign.night.phase = "none"
	return true


static func night_event_text(campaign: Dictionary) -> String:
	match campaign.night.event_id:
		"short_supplies":
			return "Os suprimentos não bastaram para todos. Quem dormiu sem comida recuperou menos."
		"no_water":
			return "Faltou água para quem voltou. O descanso foi pior: menos Instinto recuperado."
		"distant_noise":
			return "Ruídos distantes inquietaram os adormecidos: recuperação de Instinto reduzida em 3." if campaign.night.watch_hero_id == "" \
				else "O vigia verificou os ruídos distantes. Os demais puderam descansar em segurança."
	return "A noite passou tranquila. O abrigo permaneceu seguro."


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


## Nome livre da classe (nem no elenco nem no memorial).
static func hero_name(campaign: Dictionary, class_id: String) -> String:
	var used := {}
	for entry in campaign.roster:
		used[String(entry.display_name).to_lower()] = true
	for entry in campaign.memorial:
		used[String(entry.display_name).to_lower()] = true
	var pool: Array = NAME_POOLS.get(class_id, ["Recruta"])
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
		return {"error": "Essa classe ainda não chegou à Estação."}
	if living(campaign).size() >= MAX_ROSTER:
		return {"error": "Limite de 12 animais vivos na Estação Raiz."}
	var free := given_name != "" or can_recruit_volunteer(campaign, class_id)
	if not free and quantity(campaign, "seeds") < RECRUIT_COST:
		return {"error": "Sementes insuficientes (custa 10 sementes)."}
	if not free:
		adjust(campaign, "seeds", -RECRUIT_COST)
	var suffix: int = campaign.roster.size()
	while hero(campaign, "hero_%s_%d" % [class_id, suffix]) != null:
		suffix += 1
	var hero_id := "hero_%s_%d" % [class_id, suffix]
	var display := given_name if given_name != "" else hero_name(campaign, class_id)
	campaign.roster.append(Campaign.new_hero(hero_id, class_id, display, int(hero_class.BaseMaxHp), Campaign.roll_perks(GameData.table("perks"), rng)))
	return {"error": "", "hero_id": hero_id}


## Os voluntários a caminho entram no elenco, enquanto houver vaga.
static func receive_volunteers(campaign: Dictionary, rng: RandomNumberGenerator) -> int:
	var arrived := 0
	while not campaign.pending_offers.is_empty() and living(campaign).size() < MAX_ROSTER:
		var offer: Dictionary = campaign.pending_offers.pop_front()
		if not campaign.unlocked_classes.has(offer.class_id):
			campaign.unlocked_classes.append(offer.class_id)
		arrived += 1 if recruit(campaign, offer.class_id, rng, offer.display_name).error == "" else 0
	return arrived


static func treat_trauma(campaign: Dictionary, hero_id: String) -> String:
	var entry = hero(campaign, hero_id)
	if entry == null or not entry.alive:
		return "Somente sobreviventes podem ser tratados."
	if not entry.trauma:
		return "%s não tem trauma." % entry.display_name
	if not consume(campaign, "seeds", TRAUMA_COST):
		return "Sementes insuficientes (custa 5 sementes)."
	entry.trauma = false
	return ""


static func research(campaign: Dictionary, research_id: String) -> String:
	var row = GameData.row("research", research_id)
	if row == null:
		return "Pesquisa desconhecida."
	if not room_available(campaign, RESEARCH):
		return "Recupere o Centro de Pesquisa para pesquisar."
	if campaign.researched_skills.has(row.SkillId):
		return "Essa melhoria já foi pesquisada."
	if not consume(campaign, "fragments", int(row.CostFragments)):
		return "Fragmentos insuficientes (custa %d)." % int(row.CostFragments)
	campaign.researched_skills.append(row.SkillId)
	return ""


static func craft_relic(campaign: Dictionary, relic_id: String) -> String:
	if GameData.row("relics", relic_id) == null:
		return "Relíquia desconhecida."
	if not room_available(campaign, FORGE):
		return "Recupere a Forja para fabricar relíquias."
	var cost := relic_cost(campaign)
	if not consume(campaign, "scrap", cost):
		return "Sucata insuficiente (custa %d sucatas)." % cost
	campaign.inventory.relics.append(relic_id)
	return ""


## Troca a relíquia do animal ("" tira); a antiga volta ao estoque.
static func equip_relic(campaign: Dictionary, hero_id: String, relic_id: String) -> String:
	var entry = hero(campaign, hero_id)
	if entry == null or not entry.alive:
		return "Só animais vivos usam relíquias."
	if entry.relic_id == relic_id:
		return "Já está equipada."
	if relic_id != "" and not campaign.inventory.relics.has(relic_id):
		return "Essa relíquia não está no estoque."
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


## Quatro vivos diferentes e no máximo dois por classe.
static func validate_team(campaign: Dictionary, hero_ids: Array) -> String:
	var unique := {}
	for hero_id in hero_ids:
		unique[hero_id] = true
	if hero_ids.size() != 4 or unique.size() != 4:
		return "A expedição requer exatamente 4 animais vivos na formação."
	var counts := {}
	for hero_id in hero_ids:
		var entry = hero(campaign, hero_id)
		if entry == null or not entry.alive:
			return "A expedição requer exatamente 4 animais vivos na formação."
		counts[entry.class_id] = int(counts.get(entry.class_id, 0)) + 1
		if counts[entry.class_id] > MAX_PER_CLASS:
			return "No máximo dois animais da mesma classe na mesma equipe."
	return ""


## Os ataques que a classe tem na posição (#95): cada um precisa de um ataque na posição em que parte.
static func attacks_from_rank(class_id: String, rank: int) -> Array:
	var out: Array = []
	var hero_class = GameData.row("classes", class_id)
	if hero_class == null:
		return out
	for ability_id in hero_class.AbilityIds:
		var ability = GameData.row("abilities", ability_id)
		if ability != null and ability.get("DamageRange") != null and Array(ability.get("OriginRanks", [])).map(func(r): return int(r)).has(rank):
			out.append(ability.DisplayName)
	return out


## Admin e testes: larga a expedição em andamento (sem saque) e volta ao refúgio com a equipe descansada.
static func abandon_to_refuge(campaign: Dictionary) -> bool:
	if in_refuge(campaign):
		return false
	for entry in living(campaign):
		entry.hp = entry.max_hp
		entry.instinct = 0
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
## button, room}; action: "report", "dormitory", "train", "room" ou "depart".
static func next_step(campaign: Dictionary) -> Dictionary:
	var report: Dictionary = campaign.station.get("last_return", {})
	if not report.is_empty() and not report.get("seen", false):
		return {"title": "Ver o que a equipe trouxe", "text": "O relatório da última expedição está pronto: o achado, quem voltou e como a Estação passou o ciclo.",
			"action": "report", "button": "Ver o relatório", "room": ""}
	if campaign.night.phase != "none":
		return {"title": "Passar a noite", "text": "A equipe descansa no Dormitório: escolha quem vigia e durma. Quem dorme come e recupera vida e instinto.",
			"action": "dormitory", "button": "Ir ao Dormitório", "room": DORMITORY}
	if visit_pending(campaign):
		return {"title": "Alguém espera na plataforma", "text": "Um candidato chegou de trem. Veja o que ele traz para a Estação e decida se fica.",
			"action": "train", "button": "Ir à plataforma", "room": ""}
	var missing := {}
	for room_id in NEXT_ROOMS:
		var cost := next_level_cost(campaign, room_id)
		if cost.is_empty():
			continue
		var level := room_level(campaign, room_id)
		var name: String = ROOM_ARTICLE.get(room_id, "") + room_def(room_id).name
		if upgrade_block(campaign, room_id) == "":
			return {"title": "%s %s" % ["Recuperar" if level == 0 else "Melhorar", name], "text": "%s Custa %s." % [room_benefit(room_id, level + 1), cost_text(cost)],
				"action": "room", "button": "Ver %s" % name, "room": room_id}
		if missing.is_empty():
			missing = {"title": "Trazer %s para %s %s" % [cost_text(cost), "reabrir" if level == 0 else "melhorar", name],
				"text": "%s As jornadas trazem sucata e fragmentos das buscas." % room_benefit(room_id, level + 1), "action": "depart",
				"button": "Preparar expedição", "room": room_id}
	if not missing.is_empty():
		return missing
	for info in AHJourneyRules.PHASES:
		if phase_unlocked(campaign, info.id) and not campaign.completed_phases.has(info.id):
			return {"title": "Partir para %s" % info.name, "text": info.description, "action": "depart", "button": "Preparar expedição", "room": ""}
	return {"title": "Voltar às ruas", "text": "Todas as fases foram concluídas. Dá para jogar qualquer uma de novo pelo mapa.", "action": "depart",
		"button": "Preparar expedição", "room": ""}


## A ordem em que o próximo passo sugere recuperar os cômodos, e o artigo de cada um no texto.
const NEXT_ROOMS := [FORGE, RESEARCH, DEPOT]
const ROOM_ARTICLE := {FORGE: "a ", RESEARCH: "o ", DEPOT: "o "}


## Por que não dá para preparar uma partida agora ("" se dá).
static func preparation_block(campaign: Dictionary) -> String:
	if campaign.night.phase != "none":
		return "Conclua a noite no Dormitório antes de partir."
	if visit_pending(campaign):
		return "Há alguém esperando na plataforma: decida antes de partir."
	if not in_refuge(campaign):
		return "A equipe já está numa expedição."
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
	if team.size() != 4 or unique.size() != 4:
		return "Escolha quatro integrantes diferentes."
	for rank in range(1, 5):
		var entry = hero(campaign, team[rank - 1])
		if entry == null or not entry.alive:
			return "Só integrantes vivos podem partir."
		if attacks_from_rank(entry.class_id, rank).is_empty():
			return "%s não tem ataque na posição %d." % [entry.display_name, rank]
	var team_block := validate_team(campaign, team)
	if team_block != "":
		return team_block
	if focus != "" and focus_def(focus).is_empty():
		return "Foco de rota desconhecido."
	if not focus_available(campaign, focus):
		return "Esse pedido não está aberto: o morador não está na Estação ou já recebeu o item."
	if extra_food < 0 or J.FREE_FOOD + extra_food > J.MAX_FOOD:
		return "Suprimentos acima do limite."
	if extra_food * FOOD_COST > quantity(campaign, "seeds"):
		return "Sementes insuficientes para os suprimentos selecionados."
	if J.phase(phase_id).is_empty() or not phase_unlocked(campaign, phase_id):
		return "Essa fase ainda está bloqueada."
	adjust(campaign, "seeds", -extra_food * FOOD_COST)
	campaign.preferred_formation = team.duplicate()
	if not J.start_expedition(campaign, phase_id, seed_value):
		return "A expedição não pôde começar."
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
		"food_left": maxi(0, int(expedition.food)), "stats": expedition.get("stats", {}).duplicate(true)}
	adjust(campaign, "seeds", delivered.seeds)
	adjust(campaign, "scrap", delivered.scrap)
	adjust(campaign, "fragments", delivered.fragments)
	campaign.station.water = int(campaign.station.water) + delivered.water
	adjust(campaign, SUPPLIES, delivered.supplies)
	# Pedido pessoal: o item volta inteiro na vitória e na retirada; na derrota fica para trás.
	var request: String = loot.get("request_item", "")
	if factor > 0.0 and is_resident(campaign, request) and not campaign.station.completed_requests.has(request):
		campaign.station.completed_requests.append(request)
		delivered.request = request
	for entry in campaign.roster:
		entry.expedition_uses = {}
	if session.result == "victory" and campaign.last_completed_expedition_id != expedition.id:
		campaign.last_completed_expedition_id = expedition.id
		campaign.completed_expeditions = int(campaign.completed_expeditions) + 1
	# A comida que sobrou vira suprimento e abre a noite; depois o ciclo da Estação e o trem.
	begin_night(campaign, expedition.id, expedition.team, int(expedition.food))
	var returning: int = expedition.team.filter(func(id): return hero(campaign, id) != null and hero(campaign, id).alive).size()
	delivered.returning = returning
	run_cycle(campaign, expedition.id, returning)
	delivered.cycle = campaign.station.last_cycle.duplicate()
	train_on_return(campaign, expedition.id)
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
		return "Pedido: %s" % civilian(entry.civilian).name
	return {FOCUS_WATER: "Água", FOCUS_PARTS: "Peças", FOCUS_PROVISIONS: "Provisões"}.get(focus_id, "Rota básica")


static func focus_reward_text(focus_id: String) -> String:
	var entry := focus_def(focus_id)
	if entry.is_empty():
		return ""
	if entry.civilian != "":
		return civilian(entry.civilian).request_item
	return {FOCUS_WATER: "+%d água", FOCUS_PARTS: "+%d sucata", FOCUS_PROVISIONS: "+%d suprimentos"}[focus_id] % entry.amount


## Próximo cômodo que a sucata ajudaria a recuperar ou melhorar, e quanta falta.
static func _needed_room(campaign: Dictionary) -> Array:
	var scrap := quantity(campaign, "scrap")
	for room_id in [FORGE, RESEARCH, DEPOT]:
		var cost := next_level_cost(campaign, room_id)
		if not cost.is_empty() and int(cost.get("scrap", 0)) > scrap:
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
		return "%s: %s Entregue, %s." % [who.name, who.need, who.request_reward]
	var f := forecast(campaign, team)
	match focus_id:
		FOCUS_WATER:
			return ("Água: %d na estação; a equipe bebe %d na volta e vai faltar." % [f.water, f.water_consumed]) if f.thirsty \
				else ("Água: %d na estação, %d depois da próxima volta." % [f.water, f.water_after])
		FOCUS_PARTS:
			var need := _needed_room(campaign)
			return "Sucata para relíquias e melhorias." if need[0] == "" else "Faltam %d sucatas para %s." % [need[1], _room_the(need[0])]
		FOCUS_PROVISIONS:
			return "Suprimentos: %d de %d; a noite da volta pede %d." % [f.food, f.food_capacity, f.food_night_need]
	return "Sem objetivo: só o que aparecer nas casas."


static func _room_the(room_id: String) -> String:
	return {FORGE: "a Forja", RESEARCH: "a Pesquisa", DEPOT: "o Depósito"}.get(room_id, "um cômodo")


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
	return " Objetivo cumprido (%s): %s, entregue na volta." % [focus_label(entry.id), focus_reward_text(entry.id)]
