## O radar do Mapa da Rede (#87): o terminal antigo da plataforma, que capta com falhas os sinais da VIGIA, lê o que a
## equipe vai encontrar em cada lugar. A leitura vem da própria rota da fase (a semente fixada na campanha quando o mapa
## a mostra pela primeira vez, a mesma que a partida usa), e não de outra sorteada: o guardião, os inimigos mais comuns
## das patrulhas, os pontos de busca, o evento de história e o clima são os que a fase vai ter.
##
## A leitura melhora com a Estação (decisão do Lucas, 24/10/2026): a Pesquisa recuperada lê o guardião e os inimigos, o
## Depósito melhorado lê os suprimentos e a Forja recuperada (a antena do terminal remendada na bancada) lê a história e o
## clima. As fases já
## concluídas ficam conhecidas. Sem o cômodo, "não lido"; com o cômodo e a fase ainda bloqueada, "parcial" (o terminal
## capta o sinal, mas não o identifica antes da hora).
class_name AHNetworkRadar
extends RefCounted

const J = preload("res://scripts/flow/journey_rules.gd")
const S = preload("res://scripts/flow/station_rules.gd")
const STREET = preload("res://scripts/street/street.gd")

## O cômodo que lê cada parte do radar e o nível que ele precisa (o Depósito é básico, nível 1 desde o começo: lê os
## suprimentos melhorado).
const READERS := {"boss": S.RESEARCH, "enemies": S.RESEARCH, "supplies": S.DEPOT, "story": S.FORGE, "weather": S.FORGE}
const READER_LEVEL := {S.DEPOT: 2}
const PARTS := ["boss", "enemies", "supplies", "story", "weather"]
## Os mapas com os objetos vasculháveis dos cenários (data/scenarios), na ordem em que a rota os encontra.
const SCENARIOS := "res://data/scenarios/%s.json"


## A semente da rota da fase: fixada na campanha na primeira vez que o radar a lê e usada na partida (start_expedition);
## depois da partida, a fase ganha outra. Um save de antes da #87 não tem a tabela: ela nasce aqui.
static func route_seed(campaign: Dictionary, phase_id: String) -> int:
	var station: Dictionary = campaign.get("station", {})
	if not station.has("route_seeds"):
		station.route_seeds = {}
	if not station.route_seeds.has(phase_id):
		station.route_seeds[phase_id] = randi() & 0x7FFFFFFF
	return int(station.route_seeds[phase_id])


## A partida usou a semente: a próxima ida à fase tem outra rota (o radar lê a nova).
static func spend_seed(campaign: Dictionary, phase_id: String) -> void:
	campaign.get("station", {}).get("route_seeds", {}).erase(phase_id)


## A rota que a partida vai montar (create_corridor com a mesma semente) e, na rua, as casas que a cena sorteia com ela
## (as portas são fixas: street.gd, door_specs). focus: o foco da rota escolhido na Preparação (troca uma porta).
static func preview_route(campaign: Dictionary, phase_id: String, focus: String = "") -> Dictionary:
	var info := J.phase(phase_id)
	var route := J.create_corridor(route_seed(campaign, phase_id) & 0x7FFFFFFF, phase_id, info.node_type, info.scenario)
	if String(info.get("map", "")) == "":
		var doors: Array = STREET.door_specs()
		J.assign_search_sites(route, doors.map(func(d): return d.step), doors.map(func(d): return d.shop), focus)
	return route


## A leitura do lugar: cada parte com o estado ("unknown", "partial", "known") e o que o terminal captou.
## {boss: {state, id}, enemies: {state, ids}, supplies: {state, points, amount}, story: {state, has}, weather: {state, id}}
static func reading(campaign: Dictionary, phase_id: String, focus: String = "") -> Dictionary:
	var info := J.phase(phase_id)
	var route := preview_route(campaign, phase_id, focus)
	var expedition := {"corridor": route, "level": info.level}
	var out := {}
	for part in PARTS:
		out[part] = {"state": state_of(campaign, phase_id, part)}
	# O guardião: o primeiro do grupo do último trecho (o mesmo que a luta do guardião vai pôr em campo).
	var boss_index: int = route.steps.size() - 1
	var guard: Array = J.corridor_enemies(expedition, boss_index)
	out.boss.id = String(guard[0].enemy_id) if not guard.is_empty() else ""
	# Os inimigos das patrulhas, os mais comuns primeiro (empate pelo id, estável).
	var counts := {}
	for index in route.steps.size():
		if route.steps[index].type == "combat":
			for unit in J.corridor_enemies(expedition, index):
				counts[unit.enemy_id] = int(counts.get(unit.enemy_id, 0)) + 1
	var ids: Array = counts.keys()
	ids.sort_custom(func(a, b): return counts[a] > counts[b] or (counts[a] == counts[b] and String(a) < String(b)))
	out.enemies.ids = ids
	out.enemies.counts = counts
	var points := search_points(phase_id, route)
	out.supplies.points = points
	out.supplies.amount = "many" if points >= 7 else ("some" if points >= 4 else "few")
	out.story.has = story_ahead(campaign, phase_id, route)
	out.weather.id = String(route.weather)
	return out


## Quantos lugares para vasculhar a fase tem: na rua, os pontos das casas sorteadas (a trancada também) e os objetos dos
## trechos de suprimentos; nos cenários, os objetos vasculháveis dos mapas da fase (a travessia e o mapa dela).
static func search_points(phase_id: String, route: Dictionary) -> int:
	var info := J.phase(phase_id)
	if String(info.get("map", "")) == "":
		var spots := 0
		for site in route.sites:
			spots += site.spots.size()
		return spots + route.steps.filter(func(s): return s.type == "loot").size()
	var total := 0
	for map in [String(info.get("transit", "")), String(info.map)]:
		if map != "" and FileAccess.file_exists(SCENARIOS % map):
			var data = JSON.parse_string(FileAccess.get_file_as_string(SCENARIOS % map))
			total += (data.get("props", []) as Array).size() if data is Dictionary else 0
	return total


## A rota vai mostrar o evento de história: a fase ainda o tem (o mesmo critério de story_event, sem a expedição montada)
## e a Passagem da rota cai no mapa da fase, não na travessia (enter_step só o dispara lá).
static func story_ahead(campaign: Dictionary, phase_id: String, route: Dictionary) -> bool:
	var info := J.phase(phase_id)
	var passage := -1
	for index in route.steps.size():
		if route.steps[index].type == "passage":
			passage = index
	if passage < 0 or J.map_for_step(phase_id, passage) != String(info.get("map", "")):
		return false
	var probe := campaign.duplicate()
	probe.session = {"expedition": {"phase_id": phase_id}}
	return J.story_event(probe) != ""


## O que o terminal consegue ler de uma parte: a fase concluída, tudo; o cômodo que lê a parte recuperado, a leitura da
## fase aberta e o sinal sem identidade da bloqueada; sem o cômodo, nada.
static func state_of(campaign: Dictionary, phase_id: String, part: String) -> String:
	if campaign.get("completed_phases", []).has(phase_id):
		return "known"
	var room: String = READERS[part]
	if S.room_level(campaign, room) < int(READER_LEVEL.get(room, 1)):
		return "unknown"
	return "known" if S.phase_unlocked(campaign, phase_id) else "partial"


## O nível da leitura do lugar inteiro (o título do painel): completa, parcial ou sem leitura.
static func overall(read: Dictionary) -> String:
	var states: Array = PARTS.map(func(p): return read[p].state)
	if states.all(func(s): return s == "known"):
		return "known"
	return "unknown" if states.all(func(s): return s == "unknown") else "partial"


## O que o cômodo passa a ler no radar (o Plano e o Próximo passo mostram, para o jogador ver o motivo de recuperar).
static func room_reading(room_id: String) -> String:
	match room_id:
		S.RESEARCH:
			return TranslationServer.translate("No Mapa da Rede, lê o guardião e os inimigos de cada lugar.")
		S.DEPOT:
			return TranslationServer.translate("No Mapa da Rede, lê os suprimentos de cada lugar.")
		S.FORGE:
			return TranslationServer.translate("Remenda a antena do terminal: no Mapa da Rede, lê a história e o clima de cada lugar.")
	return ""
