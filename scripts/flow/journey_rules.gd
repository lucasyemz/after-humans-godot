## Regras da jornada (expedição numa fase): port de FAHGameFlowRules (Source/AfterHumans/Flow/AHGameFlowSubsystem.cpp).
## Sem cena: tudo lê e altera o estado da campanha (Campaign.state) e os testes jogam com isto
## (tests/test_journey_rules.gd). Os sorteios usam o mesmo gerador (mulberry32) e as mesmas sementes do C++.
##
## Estado (dentro de campaign.session):
##   screen: "shelter", "corridor", "rest" (acampamento) ou "result"
##   result: "", "victory", "retreat", "fled" ou "defeat"
##   expedition: {id, seed, phase_id, scenario_id, level, team, food, hope, relationships, loot, opening_used,
##                objective_completed, corridor}
##   corridor: {node_id, node_type, seed, index, steps [{type, resolved}], weather, sites, current_house, effects, props}
##   site: {door, step, shop, spots [{choice, searched}], has_enemy, enemy_defeated, locked, forced, camp_site, camped}
##   event: null ou {event_id, from_search, resolution, pending_hard_combat}
class_name AHJourneyRules
extends RefCounted

const MASK := 0xFFFFFFFF
const FREE_FOOD := 4
const MAX_FOOD := 8
const LOCKED_HOUSE_CHANCE := 0.35
const CROWBAR_DROP_CHANCE := 0.5
const CROWBAR := "pe_de_cabra"
## Inimigos de uma casa usam índices a partir daqui no sorteio (HouseEnemyIndex).
const HOUSE_ENEMY_INDEX := 100

## Fases da campanha (FAHGameFlowRules::Phases): id, cenário, nome, nível, tipo do nó e o mapa de cada uma (#86, aprovado
## pelo Lucas): a rua na primeira ("" = a Rua das Vitrines), os cenários nas outras; com trecho de passagem, os primeiros
## transit_steps trechos ficam no mapa de passagem (o Cais antes da Ponte, o Depósito antes dos Dutos). A dificuldade, a
## posição no mapa de fases (no espaço 1100 x 660) e a descrição vêm da mesma tabela.
const PHASES := [
	{"id": "fase_1", "scenario": "rua-das-vitrines", "name": "Rua das Vitrines", "level": 1, "node_type": "combat", "map": "", "transit": "", "transit_steps": 0, "difficulty": 0, "map_pos": [330, 300],
		"description": "Vitrines tomadas por raízes ainda guardam comida e peças que a Estação não sabe mais fabricar. Os sensores das Galerias seguem separando clientes dos Antigos de fauna não autorizada."},
	{"id": "fase_2", "scenario": "ponte-das-raizes", "name": "Ponte das Raízes", "level": 3, "node_type": "combat", "map": "RootBridge", "transit": "RiverDock", "transit_steps": 4, "difficulty": 1, "map_pos": [520, 470],
		"description": "A ponte ligava bairros. Há pouco tempo, seus sensores voltaram a acender e a patrulha dobrou: a passagem livre agora pede permissões que ninguém na Estação possui."},
	{"id": "fase_3", "scenario": "sala-esquecida", "name": "Sala Esquecida", "level": 5, "node_type": "combat", "map": "SealedShelter", "transit": "", "transit_steps": 0, "difficulty": 2, "map_pos": [640, 210],
		"description": "Atrás da porta lacrada de uma Toca dos Antigos, um fichário: cães, gatos e outros bichos, medidos e numerados. Ninguém na Estação sabe por que os Antigos os estudavam."},
	{"id": "fase_4", "scenario": "laboratorio-silencioso", "name": "Laboratório Silencioso", "level": 7, "node_type": "combat", "map": "TriageGate", "transit": "", "transit_steps": 0, "difficulty": 2, "map_pos": [830, 430],
		"description": "Na Casa de Vidro silenciosa, dois relatórios sobre a Peste não batem: um culpa os animais portadores, o outro para no meio. As máquinas da triagem só conhecem o primeiro."},
	{"id": "fase_5", "scenario": "tuneis-do-eco", "name": "Túneis do Eco", "level": 9, "node_type": "boss", "map": "SewerDucts", "transit": "FloodedDepot", "transit_steps": 4, "difficulty": 3, "map_pos": [980, 190],
		"description": "Bombas antigas mantêm a água em movimento, e os filtros foram trocados há pouco tempo, não há gerações. Na eclusa central, o Porteiro guarda uma ordem de contenção que ninguém cancelou."},
]
const DIFFICULTY_NAMES := ["Fácil", "Moderada", "Difícil", "Muito difícil"]
## Os efeitos de fase dos eventos (corridor.effects) na luta (#78, decisão do Lucas: a luta aplica): cada herói começa a
## luta com os marcadores (vuln, block) e a velocidade a mais ou a menos (speed). once: vale só na próxima luta (sai da
## lista quando ela começa); sem once, até o fim da fase. good: bom para a equipe (o chip do resultado). text: o chip;
## log: a linha do Registro, já dentro da luta.
const PHASE_EFFECTS := {
	"exposto": {"vuln": 1, "once": true, "good": false, "text": "Exposto: próxima luta Vulnerável", "log": "Exposto: a equipe começa Vulnerável."},
	"cansado": {"speed": -1, "good": false, "text": "Cansado: -1 de velocidade até o fim da fase", "log": "Cansado: a equipe tem -1 de velocidade."},
	"preparado": {"block": 1, "once": true, "good": true, "text": "Preparado: 1 Bloqueio na próxima luta", "log": "Preparado: a equipe começa com 1 Bloqueio."},
}
## A escada da história (docs/narrative/narrative-design.md §7), uma camada por fase: 1 Sobrevivência, 2 O despertar,
## 3 Origem, 4 Contradição, 5 Presença humana (#64). O evento de história de cada fase abre na primeira Passagem dela.
const STORY_EVENTS := {"fase_2": "voz_interfone", "fase_3": "porta_espera", "fase_5": "sobrevivente_tuneis"}
## "O que a equipe viu": a linha do relatório da volta na primeira vitória de cada fase. Nenhuma mostra um humano nem
## cita Théo (bento-nick-arc §11): o máximo é a autenticação do fim da fase 5 (lore §25.4). A da fase 3 não lista "linhagem":
## desde a #227, é a palavra que a equipe usa na luta (decisão do Lucas no #285).
## As fases cuja linha cita o que o evento de história mostrou: só depois de ele aparecer.
const STORY_REPORT_AFTER_EVENT := ["fase_2"]
const STORY_REPORTS := {
	"fase_1": "A Estação aguenta mais alguns dias. O que os Antigos deixaram, ninguém aqui sabe fazer de novo.",
	"fase_2": "Na volta, alguém repete a frase do interfone: \"preservação humana\". Ninguém sabe por que a ponte acordou.",
	"fase_3": "As fichas passam de mão em mão no caminho de casa. Algumas palavras ninguém sabe o que querem dizer: \"edição\", \"incubação\".",
	"fase_4": "Os dois relatórios voltam na mochila. \"Um deles está errado, ou os dois estão incompletos.\"",
	"fase_5": "No painel da eclusa, uma linha nova piscava: AUTENTICAÇÃO HUMANA VÁLIDA · registro recente. Ninguém fala no caminho de casa.",
}
const WEATHERS := {
	"estacao-raiz": ["clear", "clear", "sunset", "mist", "night", "nightRain"],
	"rua-das-vitrines": ["clear", "sunset", "rain", "rain", "storm", "mist", "fog", "night", "nightRain"],
	"ponte-das-raizes": ["clear", "sunset", "rain", "storm", "mist", "fog", "night", "nightRain"],
	"sala-esquecida": ["clear", "sunset", "mist", "night", "night"],
	"laboratorio-silencioso": ["clear", "mist", "night", "night"],
	"tuneis-do-eco": ["night", "night", "night", "mist", "fog"],
}
## O que cada ponto de cada loja rende (FixedSpotOutcome): mercearia, oficina e cinema, na ordem dos pontos.
const FIXED_OUTCOMES := [
	["trouxa_pano", "racao_lacrada", "pote_sementes"],
	["primeiros_socorros", "pecas_motor", "pecas_motor"],
	["desenho_casa", "racao_lacrada", "primeiros_socorros"],
]
const SPOT_NAMES := [
	["o caixa", "a geladeira", "as prateleiras"],
	["a bancada", "o motor", "o armário de peças"],
	["a bilheteria", "o carrinho de pipoca", "a escada"],
]
const SHOP_NAMES := ["mercearia", "oficina", "cinema"]
## O tipo do objeto vasculhado, pelo nome (#7): os eventos dizem em que tipos cabem (Objects em data/events.json). Na
## ordem: o primeiro tipo com uma palavra no nome vence ("Armário de ferramentas" é armário; "Caixa de fusíveis",
## máquina; "o caixa" da mercearia, móvel). Sem tipo ("a escada", "Objeto"), o objeto não abre evento.
const OBJECT_KINDS := [
	["medico", ["socorros"]],
	["armario", ["armário"]],
	["maquina", ["motor", "fusíveis", "ferramentas", "pipoca"]],
	["bolsa", ["mochila", "bolsa", "maleta", "trouxa"]],
	["carga", ["caixote", "engradado", "palete", "sacos", "cesto", "mantimentos", "caixa amarrada", "baú"]],
	["movel", ["geladeira", "prateleira", "bancada", "fichário", "bilheteria", "cofre", "caixa"]],
]


static func _rand(seed_value: int) -> AHCombatRandom:
	return AHCombatRandom.new(seed_value & MASK)


static func _mul(a: int, b: int) -> int:
	return AHCombatRandom._mul32(a & MASK, b & MASK)


static func phase(phase_id: String) -> Dictionary:
	for entry in PHASES:
		if entry.id == phase_id:
			return entry
	# O tutorial (#144, #147) joga como uma fase, mas fora da lista: nem o Mapa da Rede nem o "Jogar de novo" o veem.
	if phase_id == AHTutorial.PHASE_ID:
		return AHTutorial.phase_info()
	return {}


## Quantos partem em cada jornada (#6): data/expedition-teams.json, por fase (MinTeam e MaxTeam). Sem linha, quatro.
## A luta tem quatro posições: o máximo nunca passa de 4.
static func team_limits(phase_id: String) -> Dictionary:
	var row = GameData.row("expedition_teams", phase_id)
	var most := clampi(int(row.get("MaxTeam", 4)) if row != null else 4, 1, 4)
	var least := clampi(int(row.get("MinTeam", 4)) if row != null else 4, 1, most)
	return {"min": least, "max": most}


## O lugar dos eventos (#7): o cenário da fase (a rua, a ponte, a sala, o laboratório, os túneis).
static func event_place(campaign: Dictionary) -> String:
	var expedition = campaign.get("session", {}).get("expedition")
	return String(phase(expedition.phase_id).get("scenario", "")) if expedition != null else ""


static func object_kind(object_name: String) -> String:
	var lower := object_name.to_lower()
	for entry in OBJECT_KINDS:
		for word in entry[1]:
			if lower.contains(word):
				return entry[0]
	return ""


## Os eventos de busca que combinam com o lugar e com o tipo do objeto (Places vazio: qualquer lugar; Objects vazio:
## qualquer objeto), em ordem fixa. Objeto sem tipo: nenhum.
static func event_pool(place: String, kind: String) -> Array:
	var pool: Array = []
	for id in GameData.table("events").keys():
		if not String(id).begins_with("busca_"):
			continue
		var row: Dictionary = GameData.row("events", id)
		var places: Array = row.get("Places", [])
		var objects: Array = row.get("Objects", [])
		if (places.is_empty() or places.has(place)) and (objects.is_empty() or (kind != "" and objects.has(kind))):
			pool.append(id)
	pool.sort()
	return pool


## A loja com o artigo, para a tela ("a mercearia"), no idioma do jogo (#35).
static func shop_the(shop: int) -> String:
	return (TranslationServer.translate("o ") if shop == 2 else TranslationServer.translate("a ")) + TranslationServer.translate(SHOP_NAMES[clampi(shop, 0, 2)])


# ---------------------------------------------------------------- partida e corredor

## Começa a expedição numa fase (ConfirmDeparture, sem a tela de preparação): a equipe é a formação viva.
static func start_expedition(campaign: Dictionary, phase_id: String, seed_value: int) -> bool:
	var info := phase(phase_id)
	if info.is_empty():
		return false
	var team: Array = []
	var most: int = team_limits(phase_id).max
	for hero_id in campaign.get("preferred_formation", []):
		for hero in campaign.roster:
			# Quem está em recuperação (#118), numa missão solo ou capturado (#183) fica na Estação.
			if hero.id == hero_id and hero.alive and int(hero.get("recovery_days", 0)) <= 0 and not AHSideMissions.away(hero) and team.size() < most:
				team.append(hero_id)
	if team.is_empty():
		return false
	for hero in campaign.roster:
		hero.expedition_uses = {}
		if team.has(hero.id):
			hero.instinct = 10 if hero.trauma else 0
	var expedition := {
		"id": "exp_%d" % seed_value, "seed": seed_value & 0x7FFFFFFF, "phase_id": phase_id, "scenario_id": info.scenario,
		"level": info.level, "team": team, "food": FREE_FOOD, "hope": 80, "relationships": {},
		"loot": {"seeds": 0, "scrap": 0, "fragments": 0}, "opening_used": false, "objective_completed": false,
	}
	expedition.corridor = create_corridor(expedition.seed, phase_id, info.node_type, info.scenario)
	campaign.session = {"screen": "corridor", "result": "", "expedition": expedition, "event": null}
	# O resgate da fase (#188): o capturado ou o pedido de ajuda vira um ponto num trecho de Suprimentos.
	AHRescue.assign(campaign)
	return true


## Os dez trechos (CreateCorridor): partida, quatro pares e o guardião. Menos lutas, cada uma mais forte (#292, Lucas,
## 01/11/2026): três pares têm uma patrulha e uma pausa (em ordem sorteada) e o par calmo, sorteado, tem duas pausas. As
## pausas e os pares que podem ser calmos vêm de data/corridor-pacing.json.
static func create_corridor(seed_value: int, node_id: String, node_type: String, scenario_id: String) -> Dictionary:
	var phase_seed := seed_value & MASK
	for i in node_id.length():
		phase_seed = (phase_seed * 31 + node_id.unicode_at(i)) & MASK
	var random := _rand(phase_seed)
	var pacing: Dictionary = pacing_row("corridor")
	var breaks: Array = pacing.get("Breaks", ["loot", "rest", "passage", "loot", "loot"]).duplicate()
	for i in range(breaks.size() - 1, 0, -1):
		var j := floori(random.next() * (i + 1))
		var swap = breaks[i]
		breaks[i] = breaks[j]
		breaks[j] = swap
	var calm_pairs: Array = pacing.get("CalmPairs", [2, 3, 4])
	var calm: int = int(calm_pairs[mini(calm_pairs.size() - 1, floori(random.next() * calm_pairs.size()))])
	var steps: Array = [{"type": "start", "resolved": true}]
	var next_break := 0
	for pair in range(1, 5):
		if pair == calm:
			steps.append({"type": breaks[next_break], "resolved": false})
			steps.append({"type": breaks[next_break + 1], "resolved": false})
			next_break += 2
		elif random.next() > 0.5:
			steps.append({"type": "combat", "resolved": false})
			steps.append({"type": breaks[next_break], "resolved": false})
			next_break += 1
		else:
			steps.append({"type": breaks[next_break], "resolved": false})
			steps.append({"type": "combat", "resolved": false})
			next_break += 1
	steps.append({"type": "boss", "resolved": false})
	var weathers: Array = WEATHERS.get(scenario_id, WEATHERS["rua-das-vitrines"])
	var weather_random := _rand(phase_seed ^ 0x73e28b19)
	return {
		"node_id": node_id, "node_type": node_type, "seed": phase_seed, "index": 0, "steps": steps,
		"weather": weathers[mini(weathers.size() - 1, floori(weather_random.next() * weathers.size()))],
		"sites": [], "current_house": -1, "effects": [], "props": {},
		# Cenários (#86): os props vasculháveis de cada mapa (o trecho de cada um), os já vasculhados, o do objetivo da
		# rota e o interior lateral aberto (a zona do mapa, -1 fora).
		"prop_steps": [], "prop_maps": [], "searched_props": [], "objective_prop": -1, "current_room": -1,
		# O desvio da fase (#289): {} sem desvio.
		"detour": _detour_plan(phase_seed, node_id),
	}


## Uma linha do ritmo do corredor (data/corridor-pacing.json), ou {} sem a tabela.
static func pacing_row(row_name: String) -> Dictionary:
	var row = GameData.row("corridor_pacing", row_name)
	return row if row is Dictionary else {}


## A linha da patrulha fight (0 = a primeira) de fights: contada a partir do guardião, a última é sempre patrol_N (a
## forte). Um corredor de save antigo, com mais patrulhas que linhas, repete a primeira no começo.
static func patrol_row(fight: int, fights: int) -> Dictionary:
	var rows := 0
	while not pacing_row("patrol_%d" % (rows + 1)).is_empty():
		rows += 1
	if rows == 0:
		return {}
	return pacing_row("patrol_%d" % clampi(rows - (fights - fight) + 1, 1, rows))


static func corridor(campaign: Dictionary):
	var expedition = campaign.get("session", {}).get("expedition")
	return expedition.corridor if expedition != null else null


static func in_corridor(campaign: Dictionary) -> bool:
	var session: Dictionary = campaign.get("session", {})
	return session.get("expedition") != null and session.get("screen") == "corridor" and session.get("result", "") == "" \
		and session.get("event") == null


## A formação na exploração (#129): troca dois heróis de lugar na ordem da equipe, fora da luta, dos eventos e do
## acampamento. A ordem vale para a fila da rua e para a próxima luta (as posições 1 a 4) e fica no save da expedição.
static func swap_team(campaign: Dictionary, a: String, b: String) -> bool:
	if not in_corridor(campaign) or a == b:
		return false
	var team: Array = campaign.session.expedition.team
	var i := team.find(a)
	var k := team.find(b)
	if i < 0 or k < 0:
		return false
	team[i] = b
	team[k] = a
	return true


## Entrar num trecho vizinho (EnterCorridorStep). Devolve "combat", "boss", "rest" ou "" (nada a fazer).
static func enter_step(campaign: Dictionary, index: int) -> String:
	if not in_corridor(campaign):
		return ""
	var route: Dictionary = corridor(campaign)
	if index < 0 or index >= route.steps.size() or absi(index - route.index) != 1 or route.current_house != -1:
		return ""
	# Avançar exige o trecho atual vencido; recuar sempre pode (o inimigo continua esperando no trecho dele).
	if index > route.index and not route.steps[route.index].resolved:
		return ""
	route.index = index
	_detour_moved(campaign, index)
	var step: Dictionary = route.steps[index]
	if step.resolved:
		return ""
	match step.type:
		"combat":
			return "combat"
		"boss":
			return "boss"
		"rest":
			step.resolved = true
			return "rest"
		"nick", "train":
			# O encontro com o Nick e o embarque (o tutorial, #144): resolvidos pela cena (a fala, o trem).
			return step.type
		"passage":
			step.resolved = true
			# Na primeira Passagem da fase (no mapa dela, não na travessia), o evento de história (#64).
			# A passagem do ramal tem o evento dela (#289), uma vez por campanha.
			if step.get("detour", false):
				var detour_story := detour_story_event(campaign)
				if detour_story != "":
					campaign.station.detour_events = campaign.station.get("detour_events", []) + [detour_story]
					campaign.session.event = {"event_id": detour_story, "from_search": false, "resolution": "",
						"pending_hard_combat": false, "object": ""}
					return "event"
				return ""
			var story := story_event(campaign) if route_map(campaign.session.expedition, index) == phase(campaign.session.expedition.phase_id).get("map", "") else ""
			if story != "":
				if not campaign.station.story_events.has(campaign.session.expedition.phase_id):
					campaign.station.story_events.append(campaign.session.expedition.phase_id)
				campaign.session.event = {"event_id": story, "from_search": false, "resolution": "", "pending_hard_combat": false,
					"object": ""}
				return "event"
			return ""
	step.resolved = true
	return ""


## O evento de história que a fase ainda deve mostrar ("" se não tem ou já mostrou). Uma vez por campanha; o que libera
## uma classe (o Sobrevivente dos Túneis libera o guaxinim) volta até a classe ser liberada, para ela não se perder de vez.
static func story_event(campaign: Dictionary) -> String:
	var phase_id: String = campaign.session.expedition.get("phase_id", "")
	var event_id: String = STORY_EVENTS.get(phase_id, "")
	var row = GameData.row("events", event_id) if event_id != "" else null
	if row == null:
		return ""
	if campaign.get("station", {}).get("story_events", []).has(phase_id):
		var locked := false
		for choice in row.get("Choices", []):
			var unlock: String = choice.get("Success", {}).get("UnlockClass", "")
			locked = locked or (unlock != "" and not campaign.unlocked_classes.has(unlock))
		if not locked:
			return ""
	return event_id


# ---------------------------------------------------------------- inimigos

## Quanto um inimigo pesa na luta: a vida e o dano médio do seu golpe mais forte (x3). O Pipoco (sem dano) é o mais
## leve; o Carrasco e o Coletor, os mais pesados.
static func enemy_strength(enemy_id: String) -> float:
	var row = GameData.row("enemies", enemy_id)
	if row == null:
		return 0.0
	var best := 0.0
	for action_id in row.get("ActionIds", []):
		var action = GameData.row("enemy_actions", action_id)
		var damage: Dictionary = action.get("DamageRange", {}) if action != null else {}
		if int(damage.get("Max", 0)) > 0:
			best = maxf(best, (float(damage.Min) + float(damage.Max)) * 0.5)
	return float(row.get("MaxHp", 0)) + best * 3.0


## O sorteio de uma vaga com a progressão da fase (progress de 0, a primeira patrulha, a 1, a última antes do
## guardião): a lista em ordem de força e uma janela de metade dela (pelo menos 2) que anda do mais fraco ao mais forte.
## Sem progressão (progress < 0, as casas), qualquer um.
static func _pick_by_progress(pool: Array, progress: float, random: AHCombatRandom) -> String:
	if pool.is_empty():
		return ""
	if progress < 0.0 or pool.size() == 1:
		return pool[floori(random.next() * pool.size())]
	var sorted := pool.duplicate()
	sorted.sort_custom(func(a, b): return enemy_strength(a) < enemy_strength(b) or (enemy_strength(a) == enemy_strength(b) and a < b))
	# A janela tem pelo menos 2 (com uma lista de 2, qualquer um): a mesma patrulha não se repete em toda partida.
	var window := mini(sorted.size(), maxi(2, ceili(sorted.size() * 0.5)))
	var start := roundi(clampf(progress, 0.0, 1.0) * (sorted.size() - window))
	return sorted[start + mini(window - 1, floori(random.next() * window))]


## Os ajudantes do John e o mestre de cada um: na patrulha de 2, o ajudante vem com o mestre se ele estiver na lista.
const HELPER_MASTERS := {"pipoco": "recreador", "faisca": "carrasco_industrial", "broto": "enraizado"}


## Formação de um encontro (GenerateEnemyTeam): do perfil do nó, da frente para trás.
## O perfil de patrulha (encounters.json): o da fase (fase_N) ou, numa casa, o da loja (fase_N_mercearia, _oficina,
## _cinema); sem perfil próprio, o node_1_combat de sempre. progress: onde a patrulha está na fase (ver _pick_by_progress).
static func generate_enemy_team(encounter: String, difficulty: int, node_id: String, random: AHCombatRandom, forced_count: int = 0,
		progress: float = -1.0) -> Array:
	if encounter == "boss":
		return [
			{"enemy_id": "porteiro", "unit_id": "enemy_porteiro", "rank": 1},
			{"enemy_id": "condutor_raiz", "unit_id": "enemy_condutor_1", "rank": 3, "suffix": " Alfa"},
			{"enemy_id": "condutor_raiz", "unit_id": "enemy_condutor_2", "rank": 4, "suffix": " Beta"},
		]
	var hard := encounter == "hard"
	var base_count := mini(4, 2 + maxi(0, difficulty - 1) / 2)
	var count := clampi(forced_count, 2, 4) if forced_count > 0 else mini(4, base_count + (1 if hard and difficulty > 2 else 0))
	var encounters := GameData.table("encounters")
	var profile = encounters.get(node_id, encounters.get("node_8_hard" if hard else "node_1_combat"))
	var formation: Array = []
	if hard and count == 4 and random.next() < 0.05:
		formation = ["vigia_enferrujado", "carcaca_colonizada", "robot", "robot_fungo"]
	elif profile != null:
		var pick := func(pool: Array) -> String:
			return _pick_by_progress(pool, progress, random)
		# Na primeira metade da fase, a patrulha de 2 é um da frente com um ajudante (os mais fracos, como o Pipoco e
		# o Broto), e o ajudante vem com o seu mestre se ele estiver na lista; da metade para o fim entra quem ataca de
		# longe.
		var front: Array = profile.get("Front", [])
		if count == 2 and progress >= 0.0 and progress < 0.5 and not profile.get("Support", []).is_empty():
			var helper: String = pick.call(profile.get("Support", []))
			var master: String = HELPER_MASTERS.get(helper, "")
			formation.append(master if front.has(master) else pick.call(front))
			formation.append(helper)
		else:
			formation.append(pick.call(front))
			if count == 4:
				formation.append(pick.call(["cao_eco", "rastejante_raiz"]))
			formation.append(pick.call(profile.get("Ranged", [])))
			if count >= 3:
				formation.append(pick.call(profile.get("Support", [])))
	var units: Array = []
	for index in formation.size():
		units.append({"enemy_id": formation[index], "unit_id": "enemy_%s_%d" % [formation[index], index], "rank": index + 1})
	return units


## Quem espera no trecho (ou na casa, com index >= HOUSE_ENEMY_INDEX), já com a vida e o dano do nível (CorridorEnemies).
## Cada um: {enemy_id, unit_id, rank, hp, max_hp, damage_bonus, display_name}.
static func corridor_enemies(expedition: Dictionary, index: int) -> Array:
	var route: Dictionary = expedition.corridor
	# As lutas do tutorial são fixas (data/tutorial.json).
	if route.get("node_type", "") == AHTutorial.PHASE_ID:
		return AHTutorial.enemies_at(expedition, index)
	var level: int = expedition.level
	var house := index >= HOUSE_ENEMY_INDEX
	var boss: bool = not house and index < route.steps.size() and route.steps[index].type == "boss"
	var final: bool = route.node_type == "boss"
	var random := _rand(route.seed ^ _mul(index + 1, 0x9e3779b9))
	var enemies := GameData.table("enemies")
	if boss and final:
		var group := generate_enemy_team("boss", 1, route.node_id, random)
		for unit in group.size():
			var spec: Dictionary = group[unit]
			var row: Dictionary = enemies[spec.enemy_id]
			spec.unit_id = "corridor_%d_%d_%d_%s" % [route.seed, index, unit, spec.enemy_id]
			spec.max_hp = int(row.MaxHp)
			spec.hp = spec.max_hp
			spec.damage_bonus = level / 4
			spec.display_name = row.DisplayName + spec.get("suffix", "")
		return group

	# A fase fica mais difícil até o guardião (Lucas, 22/10/2026; a escada da #292, 01/11/2026): as primeiras patrulhas
	# tiram os inimigos mais fracos de cada vaga e as últimas, os mais fortes; cada patrulha tem as posições, a vida e o
	# dano da sua linha em data/corridor-pacing.json, contada a partir do guardião (a última patrulha é sempre a forte).
	var count := 2
	var hp_mult := 0.75
	var damage := -1
	var progress := -1.0
	if boss:
		var boss_row := pacing_row("boss")
		count = int(boss_row.get("Count", 4))
		hp_mult = float(boss_row.get("HpScale", 1.0))
		damage = int(boss_row.get("Damage", 1))
		progress = 1.0
	elif house:
		count = mini(3, 1 + (1 if random.next() < 0.5 else 0) + (1 if level >= 6 else 0))
	else:
		var fight := 0
		for step in mini(index, route.steps.size()):
			fight += 1 if route.steps[step].type == "combat" else 0
		var fights := 0
		for step in route.steps:
			fights += 1 if step.type == "combat" else 0
		progress = float(fight) / float(maxi(1, fights - 1))
		var patrol := patrol_row(fight, fights)
		count = int(patrol.get("Count", 2)) + (1 if random.next() < float(patrol.get("ExtraChance", 0.0)) else 0)
		hp_mult = float(patrol.get("HpScale", 1.0))
		damage = int(patrol.get("Damage", 0))

	# Count é em posições: um inimigo grande ocupa duas; quem não cabe sai do grupo.
	var profile_id: String = route.node_id
	if not house and index < route.steps.size() and route.steps[index].get("detour", false):
		profile_id = String(detour_def(route.node_id).get("Encounter", profile_id))
	if house:
		var site_index := index - HOUSE_ENEMY_INDEX
		var shop: int = route.sites[site_index].get("shop", -1) if site_index < route.sites.size() else -1
		if shop >= 0 and shop < SHOP_NAMES.size() and GameData.table("encounters").has("%s_%s" % [route.node_id, SHOP_NAMES[shop]]):
			profile_id = "%s_%s" % [route.node_id, SHOP_NAMES[shop]]
	var generated := generate_enemy_team("combat", 1, profile_id, random, maxi(2, count), progress)
	var units: Array = []
	var next_rank := 1
	for spec in generated:
		var row = enemies.get(spec.enemy_id)
		var size: int = int(row.get("FormationSize", 0)) if row != null else 0
		size = size if size > 0 else 1
		if next_rank + size - 1 > count:
			continue
		spec.rank = next_rank
		next_rank += size
		units.append(spec)
	# Mais forte com o nível: vida da tabela (de ~metade no começo até um pouco acima) e dano.
	var hp_scale := minf(1.3, 0.45 + 0.06 * level)
	var leader: float = float(pacing_row("boss").get("LeaderHp", 1.8))
	for unit in units.size():
		var spec: Dictionary = units[unit]
		var row: Dictionary = enemies[spec.enemy_id]
		spec.unit_id = "corridor_%d_%d_%d_%s" % [route.seed, index, unit, spec.enemy_id]
		var scale := hp_scale * (leader if boss and unit == 0 else hp_mult)
		spec.max_hp = maxi(4, roundi(float(row.MaxHp) * scale))
		spec.hp = spec.max_hp
		spec.damage_bonus = maxi(0, level / 4 + damage)
		spec.display_name = row.DisplayName
	if boss and not units.is_empty():
		units[0].display_name += " · Guardião"
	# Sozinho (numa casa), um inimigo à distância começa onde tem um ataque.
	if units.size() == 1:
		for action_id in enemies[units[0].enemy_id].get("ActionIds", []):
			var action = GameData.row("enemy_actions", action_id)
			if action != null and action.get("DamageRange", {}).get("Max", 0) > 0:
				var origins: Array = action.get("OriginRanks", [])
				units[0].rank = 1 if origins.is_empty() else int(origins[0])
				break
	return units


## Começa a luta do trecho atual ou da casa (StartCorridorCombat). Devolve {enemies, opening, boss} ou {} se não há luta.
static func start_corridor_combat(campaign: Dictionary, party_advantage: bool) -> Dictionary:
	if not in_corridor(campaign):
		return {}
	var expedition: Dictionary = campaign.session.expedition
	var route: Dictionary = expedition.corridor
	var index: int = route.index
	var boss := false
	if route.current_house >= 0:
		var site: Dictionary = route.sites[route.current_house]
		if not site.has_enemy or site.enemy_defeated:
			return {}
		index = HOUSE_ENEMY_INDEX + route.current_house
	else:
		var step: Dictionary = route.steps[index]
		if step.resolved or (step.type != "combat" and step.type != "boss"):
			return {}
		boss = step.type == "boss"
	expedition.opening_used = true
	# No escuro do ramal (#289), a equipe não pega a patrulha desprevenida.
	if index < route.steps.size() and route.steps[index].get("detour", false):
		party_advantage = false
	# Rondar o Quarteirão (#261): a equipe age primeiro na luta seguinte ao acampamento (vale também no ramal).
	var opening := AHCampSkills.take_opening(campaign) or party_advantage
	return {"enemies": corridor_enemies(expedition, index), "opening": opening, "boss": boss}


## O que uma luta vencida põe no achado (o que end_combat soma), sem mudar nada: o popup do fim da luta mostra antes de
## a luta fechar (#109). Só o guardião dá recursos: os da luta e, na primeira vez, os da fase concluída.
static func combat_loot(campaign: Dictionary, result: String, boss: bool) -> Dictionary:
	var out := {"seeds": 0, "scrap": 0, "fragments": 0}
	var expedition = campaign.get("session", {}).get("expedition")
	if result != "victory" or expedition == null or int(expedition.corridor.get("current_house", -1)) >= 0:
		return out
	# A vitória em que o último golpe também derruba o último da equipe: end_combat conta como derrota, sem achado.
	if not campaign.roster.any(func(h): return expedition.team.has(h.id) and h.alive):
		return out
	# A patrulha do ramal de um desvio (#289) rende o achado dela (o mesmo que end_combat soma).
	var route: Dictionary = expedition.corridor
	var index := int(route.get("index", 0))
	if not boss and index < route.get("steps", []).size() and route.steps[index].get("detour", false):
		out.fragments += int(detour_def(route.get("node_id", "")).get("FragmentsPerPatrol", 0))
	if not boss:
		return out
	out.seeds += 6
	out.scrap += 1
	if not expedition.get("objective_completed", false):
		out.seeds += 10
		out.scrap += 2
		out.fragments += 1
	return out


## Fim de uma luta do corredor (EndCombat). result: "victory", "defeat" ou "escaped". Ninguém morre (#118): quem caiu
## fica fora da expedição (alive = false) e volta à Estação Caído (AHStationRules.admit_fallen, no fim da volta).
static func end_combat(campaign: Dictionary, result: String, boss: bool, _cause: String = "") -> void:
	var session: Dictionary = campaign.session
	var expedition: Dictionary = session.expedition
	var route: Dictionary = expedition.corridor
	if result == "escaped":
		session.result = "fled"
		session.screen = "result"
		return
	var alive: bool = campaign.roster.any(func(h): return expedition.team.has(h.id) and h.alive)
	if result != "victory" or not alive:
		session.result = "defeat"
		session.screen = "result"
		return
	if route.current_house >= 0:
		route.sites[route.current_house].enemy_defeated = true
		return
	route.steps[route.index].resolved = true
	# Cada patrulha do ramal vencida rende o achado dela (#289).
	if route.steps[route.index].get("detour", false):
		expedition.loot.fragments += int(detour_def(route.node_id).get("FragmentsPerPatrol", 0))
	if boss:
		expedition.loot.seeds += 6
		expedition.loot.scrap += 1
		finish_corridor(campaign)


# ---------------------------------------------------------------- os caídos no mapa (#179)
# Quem cai na luta fica no lugar dela, deitado: expedition.downed guarda cada um com o mapa, a posição e a casa (-1 na
# rua). Levantar (lift) passa o caído para expedition.carried: ele segue com a equipe, sem lutar, e chega à Estação com
# menos dias de recuperação (data/recovery.json, carried). Quem fica no mapa chega com a recuperação inteira.

## Os caídos da expedição que ainda estão no mapa (sem os levantados): [{hero_id, map, x, y, z, house}].
static func downed_left(campaign: Dictionary) -> Array:
	var expedition = campaign.get("session", {}).get("expedition")
	if expedition == null:
		return []
	var carried: Array = expedition.get("carried", [])
	return expedition.get("downed", []).filter(func(entry): return not carried.has(entry.hero_id))


## Os levantados, carregados pela equipe até a volta.
static func carried(campaign: Dictionary) -> Array:
	var expedition = campaign.get("session", {}).get("expedition")
	return expedition.get("carried", []) if expedition != null else []


## Depois da luta: quem da equipe caiu e ainda não está no mapa fica onde caiu. places: {hero_id: Vector3} (onde fica o
## corpo de quem caiu nesta luta); map: o mapa da rua; house: a casa da luta (-1 na rua). Devolve os ids de quem caiu agora.
static func mark_downed(campaign: Dictionary, places: Dictionary, map: String, house: int = -1) -> Array:
	var expedition: Dictionary = campaign.session.expedition
	if not expedition.has("downed"):
		expedition.downed = []
	if not expedition.has("carried"):
		expedition.carried = []
	var known: Array = expedition.downed.map(func(entry): return entry.hero_id)
	var fresh: Array = []
	# Só quem estava nesta luta (places): quem já tinha caído antes, num save de antes do #179, não volta a cair.
	for hero_id in expedition.team:
		var entry = _hero(campaign, hero_id)
		if entry == null or entry.get("alive", true) or not places.has(hero_id) or known.has(hero_id) or expedition.carried.has(hero_id):
			continue
		var at: Vector3 = places[hero_id]
		expedition.downed.append({"hero_id": hero_id, "map": map, "x": at.x, "y": at.y, "z": at.z, "house": house})
		fresh.append(hero_id)
	return fresh


## Levanta o caído: ele sai do mapa e segue carregado pela equipe. false se ele não está no mapa.
static func lift(campaign: Dictionary, hero_id: String) -> bool:
	if not downed_left(campaign).any(func(entry): return entry.hero_id == hero_id):
		return false
	campaign.session.expedition.carried.append(hero_id)
	return true


static func _hero(campaign: Dictionary, hero_id: String):
	for entry in campaign.roster:
		if entry.id == hero_id:
			return entry
	return null


## O guardião vencido conclui a fase (FinishCorridor): saque completo na volta; as casas continuam abertas.
static func finish_corridor(campaign: Dictionary) -> bool:
	var expedition: Dictionary = campaign.session.expedition
	if expedition.objective_completed:
		return false
	expedition.loot.seeds += 10
	expedition.loot.scrap += 2
	expedition.loot.fragments += 1
	expedition.objective_completed = true
	if not campaign.completed_phases.has(expedition.phase_id):
		campaign.completed_phases.append(expedition.phase_id)
		# A primeira vitória na fase: o relatório da volta mostra a fase seguinte liberada (#60).
		expedition.first_clear = true
	for hero in campaign.roster:
		if expedition.team.has(hero.id) and hero.alive:
			hero.completed_expeditions = hero.get("completed_expeditions", 0) + 1
	return true


## Voltar à Estação (SafeRetreat): com a fase concluída é vitória; senão, retirada (metade do achado).
static func safe_retreat(campaign: Dictionary) -> bool:
	var session: Dictionary = campaign.get("session", {})
	if session.get("expedition") == null or session.get("result", "") != "" or session.get("event") != null \
			or not ["corridor", "rest"].has(session.get("screen")):
		return false
	session.result = "victory" if session.expedition.objective_completed else "retreat"
	session.screen = "result"
	return true


## Entrega o achado e fecha a expedição (FinishReturnToShelter): tudo na vitória, metade na retirada, nada na fuga e na
## derrota. A volta inteira (noite, ciclo da Estação, trem) fica em AHStationRules.finish_return. Devolve o resumo.
static func finish_return(campaign: Dictionary) -> Dictionary:
	return AHStationRules.finish_return(campaign)


# ---------------------------------------------------------------- estoque compartilhado

static func food(campaign: Dictionary) -> int:
	var expedition = campaign.get("session", {}).get("expedition")
	return maxi(0, expedition.food) if expedition != null else 0


static func has_tool(campaign: Dictionary, tool: String) -> bool:
	return campaign.get("tools", []).has(tool)


## Comida (da expedição, até 8), curativos (do refúgio), sementes e sucata (achado). Devolve quanto mudou.
static func adjust(campaign: Dictionary, item: String, delta: int) -> int:
	var expedition = campaign.get("session", {}).get("expedition")
	match item:
		"food":
			if expedition == null:
				return 0
			var before: int = expedition.food
			# Ganhar respeita o limite de 8; gastar nunca passa de zero.
			expedition.food = clampi(before + delta, 0, MAX_FOOD) if delta > 0 else maxi(0, before + delta)
			return expedition.food - before
		"bandages":
			var before: int = campaign.inventory.bandages
			campaign.inventory.bandages = maxi(0, before + delta)
			return campaign.inventory.bandages - before
		"seeds", "scrap", "fragments":
			if expedition == null:
				return 0
			var before: int = expedition.loot[item]
			expedition.loot[item] = maxi(0, before + delta)
			return expedition.loot[item] - before
	return 0


static func grant_tool(campaign: Dictionary, tool: String) -> bool:
	if tool == "" or has_tool(campaign, tool):
		return false
	campaign.tools.append(tool)
	# A novidade (#143): o aviso na exploração e o selo NOVO na Mochila até ela abrir.
	for key in ["new_tools", "tool_notices"]:
		var list: Array = campaign.get(key, [])
		if not list.has(tool):
			list.append(tool)
		campaign[key] = list
	return true


static func lose_tool(campaign: Dictionary, tool: String) -> void:
	campaign.tools.erase(tool)
	# Perdida antes de a Mochila abrir, ela deixa de ser novidade (#143).
	for key in ["new_tools", "tool_notices"]:
		if campaign.has(key):
			campaign[key].erase(tool)


## Os efeitos de fase que valem na próxima luta da expedição (os ids de PHASE_EFFECTS em corridor.effects).
static func phase_effects(campaign: Dictionary) -> Array:
	var expedition = campaign.get("session", {}).get("expedition")
	if expedition == null:
		return []
	return Array(expedition.get("corridor", {}).get("effects", [])).filter(func(id): return PHASE_EFFECTS.has(id))


## A luta começou: os efeitos de uma luta só (Exposto e Preparado) saem da lista; os da fase (Cansado) ficam.
static func spend_fight_effects(campaign: Dictionary) -> void:
	var expedition = campaign.get("session", {}).get("expedition")
	if expedition == null or not expedition.has("corridor"):
		return
	var effects: Array = expedition.corridor.get("effects", [])
	for id in effects.duplicate():
		if bool(PHASE_EFFECTS.get(id, {}).get("once", false)):
			effects.erase(id)


static func _team_alive(campaign: Dictionary) -> Array:
	var team: Array = campaign.session.expedition.team
	var out: Array = []
	for hero_id in team:
		for hero in campaign.roster:
			if hero.id == hero_id and hero.alive:
				out.append(hero)
	return out


# ---------------------------------------------------------------- casas

## Três portas sorteadas pela fase, uma casa trancada a mais em 35% das fases e a casa do acampamento (AssignSearchSites).
## door_steps e door_shops vêm da cena: em que trecho fica cada porta e de que loja ela é.
static func assign_search_sites(route: Dictionary, door_steps: Array, door_shops: Array, focus: String = "") -> void:
	if not route.sites.is_empty() or door_steps.is_empty():
		assign_camp_site(route)
		return
	var random := _rand(route.seed ^ 0x5bd1e995)
	var doors: Array = range(door_steps.size())
	for i in range(doors.size() - 1, 0, -1):
		var j := floori(random.next() * (i + 1))
		var swap = doors[i]
		doors[i] = doors[j]
		doors[j] = swap
	doors.resize(mini(3, doors.size()))
	doors.sort()
	# O foco da rota garante uma casa da loja certa (troca a última porta sorteada), nunca num trecho que o desvio pula
	# (#289): lá a porta não conta como da loja.
	var skippable: Array = detour_skippable(route)
	var focus_shops: Array = range(door_shops.size()).map(func(d): return -1 if skippable.has(int(door_steps[d])) else door_shops[d])
	AHStationRules.choose_doors(focus, doors, focus_shops)
	for door in doors:
		var spots: Array = []
		for s in 1 + mini(2, floori(random.next() * 3)):
			spots.append({"choice": false, "searched": false})
		route.sites.append({"door": door, "step": door_steps[door], "shop": door_shops[door], "spots": spots,
			"has_enemy": random.next() < 0.4, "enemy_defeated": false, "locked": false, "forced": false,
			"camp_site": false, "camped": false})
	# Metade das fases tem um ponto com escolha, numa das casas, num objeto que tem evento da rua (#7: a geladeira
	# pode ter a Caixa Lacrada; a escada do cinema, nenhum).
	if random.next() < 0.5:
		var candidates: Array = []
		for site in route.sites:
			for spot_index in site.spots.size():
				if spot_index < 3 and not event_pool("rua-das-vitrines", object_kind(SPOT_NAMES[site.shop][spot_index])).is_empty():
					candidates.append(site.spots[spot_index])
		if not candidates.is_empty():
			candidates[mini(candidates.size() - 1, floori(random.next() * candidates.size()))].choice = true
	# Casa trancada numa porta livre: a loja inteira (3 pontos), sem patrulha. Gerador próprio.
	var lock := _rand(route.seed ^ 0x2545f491)
	var free: Array = range(door_steps.size()).filter(func(d): return not doors.has(d))
	if lock.next() < LOCKED_HOUSE_CHANCE and not free.is_empty():
		var door: int = free[mini(free.size() - 1, floori(lock.next() * free.size()))]
		route.sites.append({"door": door, "step": door_steps[door], "shop": door_shops[door],
			"spots": [{"choice": false, "searched": false}, {"choice": false, "searched": false}, {"choice": false, "searched": false}],
			"has_enemy": false, "enemy_defeated": false, "locked": true, "forced": false, "camp_site": false, "camped": false})
	AHStationRules.mark_objective(focus, route, skippable)
	assign_camp_site(route)


## Uma das casas abertas é a do acampamento (nunca a trancada). Gerador próprio.
static func assign_camp_site(route: Dictionary) -> void:
	if route.sites.any(func(s): return s.camp_site):
		return
	var open: Array = range(route.sites.size()).filter(func(i): return not route.sites[i].locked)
	if open.is_empty():
		return
	var random := _rand(route.seed ^ 0x632be59b)
	route.sites[open[mini(open.size() - 1, floori(random.next() * open.size()))]].camp_site = true


static func can_enter_house(campaign: Dictionary, site_index: int) -> bool:
	if not in_corridor(campaign):
		return false
	var route: Dictionary = corridor(campaign)
	if route.current_house != -1 or site_index < 0 or site_index >= route.sites.size():
		return false
	var site: Dictionary = route.sites[site_index]
	# A casa de um trecho que o desvio pulou ficou para trás (#289).
	return site.step <= route.index and (not site.locked or site.forced) and not site.get("skipped", false)


static func enter_house(campaign: Dictionary, site_index: int) -> bool:
	if not can_enter_house(campaign, site_index):
		return false
	corridor(campaign).current_house = site_index
	return true


static func leave_house(campaign: Dictionary) -> bool:
	if not in_corridor(campaign) or corridor(campaign).current_house == -1:
		return false
	corridor(campaign).current_house = -1
	return true


static func can_force_house(campaign: Dictionary, site_index: int) -> bool:
	if not in_corridor(campaign):
		return false
	var route: Dictionary = corridor(campaign)
	if route.current_house != -1 or site_index < 0 or site_index >= route.sites.size():
		return false
	var site: Dictionary = route.sites[site_index]
	return site.step <= route.index and site.locked and not site.forced and has_tool(campaign, CROWBAR) and not site.get("skipped", false)


## Arrombar a casa trancada: o pé de cabra quebra e a casa fica aberta até o fim da fase.
static func force_house(campaign: Dictionary, site_index: int) -> bool:
	if not can_force_house(campaign, site_index):
		return false
	lose_tool(campaign, CROWBAR)
	corridor(campaign).sites[site_index].forced = true
	return true


static func can_search(campaign: Dictionary, site_index: int, spot_index: int) -> bool:
	if not in_corridor(campaign):
		return false
	var route: Dictionary = corridor(campaign)
	if route.current_house != site_index or site_index < 0 or site_index >= route.sites.size():
		return false
	var site: Dictionary = route.sites[site_index]
	return spot_index >= 0 and spot_index < site.spots.size() and not site.spots[spot_index].searched \
		and (not site.has_enemy or site.enemy_defeated)


## Vasculhar um ponto da casa (SearchHouseSpot). Devolve {ok, text, event}: com escolha, abre um evento busca_*.
static func search_spot(campaign: Dictionary, site_index: int, spot_index: int) -> Dictionary:
	if not can_search(campaign, site_index, spot_index):
		return {"ok": false}
	var route: Dictionary = corridor(campaign)
	var site: Dictionary = route.sites[site_index]
	var spot: Dictionary = site.spots[spot_index]
	var random := _rand(route.seed ^ _mul((site.door + 1) * 8 + spot_index + 1, 0x85ebca6b))
	if spot.choice:
		# O evento combina com o lugar e com o que se vasculha (#7): nada de esporos na mercearia.
		var choices := event_pool(event_place(campaign), object_kind(SPOT_NAMES[site.shop][spot_index] if site.shop >= 0 and site.shop < 3 and spot_index < 3 else ""))
		if not choices.is_empty():
			spot.searched = true
			var event_id: String = choices[mini(choices.size() - 1, floori(random.next() * choices.size()))]
			campaign.session.event = {"event_id": event_id, "from_search": true, "resolution": "", "pending_hard_combat": false,
				"object": SPOT_NAMES[site.shop][spot_index] if site.shop >= 0 and site.shop < 3 and spot_index < 3 else ""}
			return {"ok": true, "text": "", "event": event_id}
	var fixed_id: String = FIXED_OUTCOMES[site.shop][spot_index] if site.shop >= 0 and site.shop < 3 and spot_index < 3 else ""
	var fixed = GameData.row("search_outcomes", fixed_id) if fixed_id != "" else null
	spot.searched = true
	var text := apply_search_outcome(campaign, random, fixed)
	# A bancada da oficina pode ter um pé de cabra, se a equipe ainda não tem (sorteio próprio do ponto).
	if fixed != null and site.shop == 1 and spot_index == 0 and not has_tool(campaign, CROWBAR):
		var drop := _rand(route.seed ^ _mul(site.door + 1, 0x9e3779b9))
		if drop.next() < CROWBAR_DROP_CHANCE and grant_tool(campaign, CROWBAR):
			text += TranslationServer.translate(" Embaixo da bancada, um pé de cabra. (Ferramenta: Pé de cabra)")
	text += AHStationRules.on_search(campaign, site_index, spot_index)
	return {"ok": true, "text": text, "event": ""}


## Aplica um resultado de busca (ApplySearchOutcome). Sem resultado fixo: sorteia da tabela, 1 em 3 ruim.
static func apply_search_outcome(campaign: Dictionary, random: AHCombatRandom, fixed) -> String:
	var expedition: Dictionary = campaign.session.expedition
	var outcome = fixed
	if outcome == null:
		var bad := random.next() < 1.0 / 3.0
		var pool: Array = GameData.table("search_outcomes").values().filter(func(r): return bool(r.get("bBad", false)) == bad)
		if pool.is_empty():
			adjust(campaign, "food", 1)
			adjust(campaign, "seeds", 1)
			return TranslationServer.translate("Suprimentos recolhidos · +1 alimento e +1 semente")
		outcome = pool[mini(pool.size() - 1, floori(random.next() * pool.size()))]
	adjust(campaign, "food", int(outcome.get("FoodDelta", 0)))
	adjust(campaign, "bandages", int(outcome.get("BandagesDelta", 0)))
	adjust(campaign, "seeds", int(outcome.get("SeedsDelta", 0)))
	adjust(campaign, "scrap", int(outcome.get("ScrapDelta", 0)))
	# Faro de busca (#264): +1 sucata na busca que traz sucata, se alguém da equipe tem.
	if int(outcome.get("ScrapDelta", 0)) > 0 and _team_alive(campaign).any(func(h): return AHPerks.total(AHPerks.of(h), "SearchScrap") > 0):
		adjust(campaign, "scrap", 1)
	expedition.hope = clampi(expedition.hope + int(outcome.get("HopeDelta", 0)), 0, 100)
	var team := _team_alive(campaign)
	var hero_name := ""
	if not team.is_empty():
		var hero: Dictionary = team[mini(team.size() - 1, floori(random.next() * team.size()))]
		hero_name = hero.display_name
		hero.instinct = clampi(hero.instinct + int(outcome.get("InstinctDelta", 0)), 0, 200)
		grant_tool(campaign, String(outcome.get("GrantTool", "")))
		if int(outcome.get("Damage", 0)) > 0:
			hero.hp = maxi(1, hero.hp - int(outcome.Damage))
	return TranslationServer.translate(String(outcome.get("Text", ""))).replace("{Heroi}", hero_name)


## Vasculhar o objeto de um trecho de suprimentos (uma vez por fase): sorteio da tabela.
static func search_prop(campaign: Dictionary, step: int) -> Dictionary:
	if not in_corridor(campaign):
		return {"ok": false}
	var route: Dictionary = corridor(campaign)
	if step < 0 or step >= route.steps.size() or route.steps[step].type != "loot" or step > route.index \
			or route.props.get(str(step), false) or route.current_house != -1:
		return {"ok": false}
	route.props[str(step)] = true
	var random := _rand(route.seed ^ _mul(step + 1, 0xc2b2ae35))
	return {"ok": true, "text": apply_search_outcome(campaign, random, null)}


# ---------------------------------------------------------------- o desvio (#289)
## Quantas casas com "?" a barra mostra no ramal antes de descer (o número de verdade só aparece lá embaixo).
const DETOUR_PREVIEW_CELLS := 3
# Um caminho opcional que leva ao mesmo destino: no trecho Entry, quem fareja (uma das RevealClasses) acha o bueiro; a
# equipe desce, atravessa o ramal noutro mapa (uma busca, uma passagem e 1 a 3 patrulhas) e sobe no trecho Exit. Os
# trechos entre os dois ficam para trás. Os números vêm de data/detours.json (uma linha por fase).
#
# corridor.detour: {} sem desvio, ou {state, entry, exit, map, plan [tipos do ramal], patrols, luck, blind, sniffer,
#   first, count, shift, skipped}. state: "hidden" (a equipe ainda não chegou), "revealed" (achado: a escolha está aberta
#   no trecho Entry), "none" (ninguém achou), "declined" (seguiu pela rua), "taken" (no ramal) ou "done" (subiu).
# Ao descer, os trechos do ramal entram no lugar dos pulados (first..first+count-1) e os de depois andam shift posições;
# os pulados ficam em skipped, para a barra.

## A linha do desvio da fase ({} sem desvio).
static func detour_def(phase_id: String) -> Dictionary:
	var row = GameData.row("detours", phase_id)
	return row if row is Dictionary else {}


## O desvio sorteado com a rota: quantas patrulhas o ramal tem, a ordem dele e a sorte de achar a tampa sem farejador.
static func _detour_plan(seed_value: int, node_id: String) -> Dictionary:
	var def := detour_def(node_id)
	if def.is_empty():
		return {}
	var random := _rand(seed_value ^ 0x6d2b79f5)
	var chances: Array = def.get("Patrols", [1.0])
	var roll := random.next()
	var patrols := chances.size()
	var sum := 0.0
	for i in chances.size():
		sum += float(chances[i])
		if roll < sum:
			patrols = i + 1
			break
	var plan: Array = ["loot"]
	for i in patrols:
		plan.append("combat")
	for i in range(plan.size() - 1, 0, -1):
		var j := floori(random.next() * (i + 1))
		var swap = plan[i]
		plan[i] = plan[j]
		plan[j] = swap
	# A passagem é a última: a história e, no fim dela, a escada de subida.
	plan.append("passage")
	return {"state": "hidden", "entry": int(def.Entry), "exit": int(def.Exit), "map": String(def.Map), "plan": plan,
		"patrols": patrols, "luck": random.next() < float(def.get("LuckChance", 0.0)), "blind": false, "sniffer": ""}


static func detour(route: Dictionary) -> Dictionary:
	var value = route.get("detour", {})
	return value if value is Dictionary else {}


## A equipe está no ramal (desceu e ainda não subiu).
static func in_detour(route: Dictionary) -> bool:
	var d := detour(route)
	return d.get("state", "") == "taken" and route.index >= int(d.first) and route.index < int(d.first) + int(d.count)


## Os trechos que o desvio pode pular (os de entre a entrada e a saída), enquanto ele não foi recusado: o objetivo da
## rota nunca cai neles. Depois de descer, os índices são os de antes (a rua não os tem mais).
static func detour_skippable(route: Dictionary) -> Array:
	var d := detour(route)
	if d.is_empty():
		return []
	return range(int(d.entry) + 1, int(d.exit))


## O índice que o trecho tinha antes do desvio (o da rua, de 0 a 9).
static func original_index(route: Dictionary, index: int) -> int:
	var d := detour(route)
	if not ["taken", "done"].has(d.get("state", "")):
		return index
	if index >= int(d.first) + int(d.count):
		return index - int(d.shift)
	return index


## O mapa do trecho, com o desvio: o do ramal nos trechos dele; fora, o da fase (map_for_step).
static func route_map(expedition: Dictionary, index: int) -> String:
	var route: Dictionary = expedition.corridor
	var d := detour(route)
	if ["taken", "done"].has(d.get("state", "")) and index >= int(d.first) and index < int(d.first) + int(d.count):
		return String(d.map)
	return map_for_step(expedition.phase_id, original_index(route, index))


## O nome do lugar do trecho: o do ramal pela linha do desvio (a Galeria, na fase 1), os outros pelo mapa.
static func route_place(expedition: Dictionary, index: int) -> String:
	var route: Dictionary = expedition.corridor
	if in_detour(route) or (detour(route).get("state", "") == "taken" and index >= int(detour(route).first)
			and index < int(detour(route).first) + int(detour(route).count)):
		return TranslationServer.translate(String(detour_def(route.node_id).get("Display", "")))
	return AHScenarioWorld.display_of(route_map(expedition, index))


## O número do trecho na tela, o mesmo da barra: na rua, o de antes do desvio ("Trecho 8 de 10"); no ramal, a posição
## nele ("Trecho 2 de 4 na Galeria"). with_total: com o "de N".
static func step_text(route: Dictionary, index: int, with_total: bool = true) -> String:
	var d := detour(route)
	if ["taken", "done"].has(d.get("state", "")) and index >= int(d.first) and index < int(d.first) + int(d.count):
		var where := TranslationServer.translate(String(detour_def(route.node_id).get("ShortName", "")))
		if with_total:
			return TranslationServer.translate("Trecho %d de %d na %s") % [index - int(d.first) + 1, int(d.count), where]
		return TranslationServer.translate("Trecho %d na %s") % [index - int(d.first) + 1, where]
	if with_total:
		return TranslationServer.translate("Trecho %d de %d") % [original_index(route, index) + 1, original_index(route, route.steps.size() - 1) + 1]
	return TranslationServer.translate("Trecho %d") % (original_index(route, index) + 1)


## Os trechos de um mapa do desvio: [primeiro, quantos], ou [] se o mapa não é o do ramal descido.
static func detour_range(route: Dictionary, map: String) -> Array:
	var d := detour(route)
	if not ["taken", "done"].has(d.get("state", "")) or String(d.map) != map:
		return []
	return [int(d.first), int(d.count)]


## Quem fareja na equipe: o primeiro vivo e de pé de uma das classes que revelam ({} sem ninguém).
static func detour_sniffer(campaign: Dictionary) -> Dictionary:
	var classes: Array = detour_def(campaign.session.expedition.phase_id).get("RevealClasses", [])
	for hero in _team_alive(campaign):
		if classes.has(String(hero.class_id)) and int(hero.get("hp", 1)) > 0:
			return hero
	return {}


## Chegando ao trecho da entrada com ele vencido: quem fareja acha o bueiro ("scent"); sem ninguém, a sorte da rota
## ("blind", às cegas); ou nada (""). Só uma vez por rota.
static func reveal_detour(campaign: Dictionary) -> String:
	if not in_corridor(campaign):
		return ""
	var route: Dictionary = corridor(campaign)
	var d := detour(route)
	if d.get("state", "") != "hidden" or route.index != int(d.entry) or not route.steps[route.index].resolved \
			or route.current_house != -1:
		return ""
	var sniffer := detour_sniffer(campaign)
	if not sniffer.is_empty():
		d.state = "revealed"
		d.sniffer = String(sniffer.id)
		return "scent"
	if d.luck:
		d.state = "revealed"
		d.blind = true
		return "blind"
	d.state = "none"
	return ""


## A escolha do bueiro está aberta: achado, e a equipe no trecho da entrada (fora das casas).
static func detour_open(campaign: Dictionary) -> bool:
	if not in_corridor(campaign):
		return false
	var route: Dictionary = corridor(campaign)
	var d := detour(route)
	return d.get("state", "") == "revealed" and route.index == int(d.entry) and route.steps[route.index].resolved \
		and route.current_house == -1


## As patrulhas dos trechos da rua que o desvio pula.
static func detour_street_patrols(route: Dictionary) -> int:
	var d := detour(route)
	var steps: Array = d.get("skipped", []) if d.get("state", "") in ["taken", "done"] \
		else route.steps.slice(int(d.get("entry", 0)) + 1, int(d.get("exit", 0)))
	return steps.filter(func(s): return s.type == "combat").size()


## A dica: o barulho de cada lado (menos, o mesmo tanto ou mais patrulhas lá embaixo), sem dizer quantas.
static func detour_hint(route: Dictionary) -> String:
	var d := detour(route)
	if d.is_empty():
		return ""
	var below: int = int(d.patrols)
	var above := detour_street_patrols(route)
	var key := "less" if below < above else ("same" if below == above else "more")
	return TranslationServer.translate(String(detour_def(route.node_id).get("Hints", {}).get(key, "")))


## A fala de quem achou o bueiro (o farejador pelo nome; às cegas, a tampa solta).
static func detour_line(campaign: Dictionary) -> String:
	var route: Dictionary = corridor(campaign)
	var d := detour(route)
	var lines: Dictionary = detour_def(campaign.session.expedition.phase_id).get("Lines", {})
	if d.get("blind", false):
		return TranslationServer.translate(String(lines.get("Blind", "")))
	var hero = _hero(campaign, String(d.get("sniffer", "")))
	if hero == null:
		return ""
	# O fundador tem artigo ("O Bento parou"); o recruta, só o nome.
	var key := "Sniff" if AHStationRules.is_recruit(String(hero.id)) else "SniffFounder"
	return TranslationServer.translate(String(lines.get(key, lines.get("Sniff", "%s")))) % String(hero.display_name)


static func detour_text(phase_id: String, key: String) -> String:
	return TranslationServer.translate(String(detour_def(phase_id).get("Lines", {}).get(key, "")))


## Descer pelo bueiro: os trechos do ramal entram no lugar dos pulados, as casas puladas saem do caminho, as de depois
## andam junto, e a equipe paga o Instinto da descida. A equipe ainda está no trecho da entrada: o próximo (o primeiro do
## ramal) é a viagem para o mapa dele.
static func take_detour(campaign: Dictionary) -> bool:
	if not detour_open(campaign):
		return false
	var route: Dictionary = corridor(campaign)
	var d := detour(route)
	var entry := int(d.entry)
	var exit := int(d.exit)
	var ramal: Array = []
	for kind in d.plan:
		ramal.append({"type": kind, "resolved": false, "detour": true})
	d.skipped = route.steps.slice(entry + 1, exit).duplicate(true)
	d.first = entry + 1
	d.count = ramal.size()
	d.shift = d.first + d.count - exit
	route.steps = route.steps.slice(0, entry + 1) + ramal + route.steps.slice(exit)
	for site in route.sites:
		var step := int(site.step)
		if step > entry and step < exit:
			site.skipped = true
		elif step >= exit:
			site.step = step + int(d.shift)
	var moved := {}
	for key in route.props:
		moved[str(int(key) + int(d.shift)) if int(key) >= exit else key] = route.props[key]
	route.props = moved
	d.state = "taken"
	d.announce_down = true
	var cost := int(detour_def(campaign.session.expedition.phase_id).get("InstinctCost", 0))
	for hero in _team_alive(campaign):
		hero.instinct = clampi(int(hero.instinct) + cost, 0, int(AHGameData.INSTINCT.Max))
	return true


## A equipe andou para o trecho index: passar da entrada pela rua fecha o bueiro; subir do ramal o encerra.
static func _detour_moved(campaign: Dictionary, index: int) -> void:
	var route: Dictionary = corridor(campaign)
	var d := detour(route)
	match d.get("state", ""):
		"hidden", "revealed":
			if index > int(d.entry):
				d.state = "declined" if d.state == "revealed" else "none"
		"taken":
			if index >= int(d.first) + int(d.count):
				d.state = "done"
				d.announce_up = true


## O evento da passagem do ramal ("" se a campanha já o viu).
static func detour_story_event(campaign: Dictionary) -> String:
	var event_id := String(detour_def(campaign.session.expedition.phase_id).get("StoryEvent", ""))
	if event_id == "" or GameData.row("events", event_id) == null:
		return ""
	return "" if campaign.get("station", {}).get("detour_events", []).has(event_id) else event_id


## A barra com o desvio (para a HUD): main, os 10 trechos da rua como eram (cada um {step, live: índice de agora ou -1
## se ficou para trás}); sub, os do ramal ({step, live}, os tipos escondidos até a equipe chegar); from e to, os trechos
## da rua de onde o ramal sai e onde sobe; shown: se a linha de baixo aparece (achado, descido ou subido).
static func detour_view(route: Dictionary) -> Dictionary:
	var d := detour(route)
	var state: String = d.get("state", "")
	if not ["revealed", "taken", "done"].has(state):
		return {"shown": false}
	var main: Array = []
	var sub: Array = []
	var entry := int(d.entry)
	var exit := int(d.exit)
	if state == "revealed":
		for i in route.steps.size():
			main.append({"step": route.steps[i], "live": i})
		# Antes de descer, o ramal não diz quantos trechos tem (a dica é só o barulho): casas fixas com "?", e uma só às
		# cegas (sem o faro, nem o caminho aparece).
		for i in (1 if d.get("blind", false) else DETOUR_PREVIEW_CELLS):
			sub.append({"step": {"type": "", "resolved": false}, "live": -1})
	else:
		for i in entry + 1:
			main.append({"step": route.steps[i], "live": i})
		for step in d.skipped:
			main.append({"step": step, "live": -1})
		for i in range(int(d.first) + int(d.count), route.steps.size()):
			main.append({"step": route.steps[i], "live": i})
		for i in int(d.count):
			sub.append({"step": route.steps[int(d.first) + i], "live": int(d.first) + i})
	return {"shown": true, "main": main, "sub": sub, "from": entry, "to": exit, "taken": state != "revealed",
		"blind": d.get("blind", false)}


# ---------------------------------------------------------------- cenários (#86)

## O mapa do trecho: o de passagem nos primeiros trechos, depois o da fase ("" = a rua).
static func map_for_step(phase_id: String, step: int) -> String:
	var info := phase(phase_id)
	if info.is_empty():
		return ""
	return info.transit if info.transit != "" and step < int(info.transit_steps) else info.map


## Os trechos que ficam no mapa: [primeiro, quantos] (PhaseStepRange).
static func step_range(phase_id: String, transit_map: bool) -> Array:
	var info := phase(phase_id)
	var total := int(info.get("steps", 10))
	var transit: int = clampi(int(info.get("transit_steps", 0)), 0, total - 1) if info.get("transit", "") != "" else 0
	return [0, transit] if transit_map else [transit, total - transit]


## Campos dos cenários num corredor de save anterior a eles.
static func _scenario_fields(route: Dictionary) -> void:
	for key in ["prop_steps", "prop_maps", "searched_props", "choice_props"]:
		if not route.has(key):
			route[key] = []
	for key in ["objective_prop", "current_room"]:
		if not route.has(key):
			route[key] = -1


## Os props do mapa entram no corredor (AssignScenarioProps); voltando ao mesmo mapa, os mesmos (e os já vasculhados).
## O objetivo da rota cai num prop da segunda metade (trecho >= 4), fixo pela semente. Devolve o índice do primeiro.
## names: os nomes dos props (o objeto com escolha só cai num que tem evento do lugar; sem nomes, qualquer um).
static func assign_scenario_props(campaign: Dictionary, map: String, steps: Array, names: Array = []) -> int:
	var expedition: Dictionary = campaign.session.expedition
	var route: Dictionary = expedition.corridor
	_scenario_fields(route)
	var prop_steps: Array = route.prop_steps
	var prop_maps: Array = route.prop_maps
	var existing := prop_maps.find(map)
	if existing >= 0:
		var count := prop_maps.count(map)
		if prop_steps.slice(existing, existing + count) == steps:
			return existing
		for i in range(existing + count - 1, existing - 1, -1):
			prop_steps.remove_at(i)
			prop_maps.remove_at(i)
		route.searched_props = []
		route.choice_props = []
		route.objective_prop = -1
	var first := prop_steps.size()
	for step in steps:
		prop_steps.append(step)
		prop_maps.append(map)
	# Metade dos mapas tem um objeto com escolha (#7), como as casas da rua: vasculhá-lo abre um evento do lugar.
	var choice_random := _rand(route.seed ^ _mul(hash(map) & MASK, 0x2c1b3c6d))
	var compatible: Array = []
	for i in steps.size():
		if names.is_empty() or not event_pool(event_place(campaign), object_kind(String(names[i]) if i < names.size() else "")).is_empty():
			compatible.append(first + i)
	if not compatible.is_empty() and choice_random.next() < 0.5 and route.get("node_type", "") != AHTutorial.PHASE_ID:
		route.choice_props.append(compatible[mini(compatible.size() - 1, floori(choice_random.next() * compatible.size()))])
	# O ramal de um desvio (#289) não tem objetivo: o da rota fica no caminho da fase (na rua, numa casa).
	if int(route.objective_prop) != -1 or steps.is_empty() or AHStationRules.focus_def(expedition.get("focus", "")).is_empty() \
			or not detour_range(route, map).is_empty():
		return first
	var later: Array = []
	for i in range(first, prop_steps.size()):
		if prop_steps[i] >= 4 and not detour_skippable(route).has(int(prop_steps[i])):
			later.append(i)
	var info := phase(expedition.phase_id)
	if later.is_empty() and not (info.get("transit", "") != "" and steps[0] < int(info.transit_steps)):
		later = range(first, prop_steps.size())
	if later.is_empty():
		return first
	var random := _rand(route.seed ^ 0x51ed27)
	route.objective_prop = later[mini(later.size() - 1, floori(random.next() * later.size()))]
	return first


## O trecho guardado pela patrulha de pé: nada nele abre ainda.
static func _guarded(route: Dictionary, step: int) -> bool:
	return route.index == step and step < route.steps.size() and not route.steps[step].resolved \
		and (route.steps[step].type == "combat" or route.steps[step].type == "boss")


## O trecho já está aberto para usar o que tem nele (vasculhar um objeto, entrar num interior): a equipe chegou até ele
## e não há patrulha de pé guardando. A marca de interação (#142) e a tecla usam a mesma regra.
static func step_open(route: Dictionary, step: int) -> bool:
	return route.index >= step and not _guarded(route, step)


static func can_search_scenario_prop(campaign: Dictionary, prop: int) -> bool:
	if not in_corridor(campaign):
		return false
	var route: Dictionary = corridor(campaign)
	_scenario_fields(route)
	if prop < 0 or prop >= route.prop_steps.size() or route.searched_props.has(prop) or route.current_house != -1:
		return false
	return step_open(route, route.prop_steps[prop])


## Vasculha o prop (SearchScenarioProp): a tabela das casas (1 em 3 ruim) e o objetivo da rota. Devolve {ok, text}.
static func search_scenario_prop(campaign: Dictionary, prop: int, object_name: String = "") -> Dictionary:
	if not can_search_scenario_prop(campaign, prop):
		return {"ok": false}
	var route: Dictionary = corridor(campaign)
	route.searched_props.append(prop)
	if route.get("node_type", "") == AHTutorial.PHASE_ID:
		var found := AHTutorial.search(campaign)
		if AHTutorial.catch_breath(campaign):
			var breath := TranslationServer.translate("A equipe recupera o fôlego.")
			found = breath if found == "" else found + ". " + breath
		return {"ok": true, "text": found, "event": ""}
	# O objeto com escolha abre um evento do lugar (o do objetivo da rota fica com o achado dele).
	if route.choice_props.has(prop) and prop != int(route.objective_prop):
		var choices := event_pool(event_place(campaign), object_kind(object_name))
		if not choices.is_empty():
			var pick := _rand(route.seed ^ _mul(prop + 1, 0x165667b1))
			var event_id: String = choices[mini(choices.size() - 1, floori(pick.next() * choices.size()))]
			campaign.session.event = {"event_id": event_id, "from_search": true, "resolution": "", "pending_hard_combat": false,
				"object": object_name}
			return {"ok": true, "text": "", "event": event_id}
	var random := _rand(route.seed ^ _mul(prop + 1, 0x27d4eb2d))
	var text := apply_search_outcome(campaign, random, null)
	if prop == int(route.objective_prop):
		text += AHStationRules.grant_objective(campaign)
	return {"ok": true, "text": text, "event": ""}


## A porta de um interior lateral abre do trecho dela em diante, sem a patrulha dele de pé (CanEnterScenarioRoom).
static func can_enter_scenario_room(campaign: Dictionary, door_step: int) -> bool:
	if not in_corridor(campaign):
		return false
	var route: Dictionary = corridor(campaign)
	_scenario_fields(route)
	return route.current_house == -1 and int(route.current_room) == -1 and step_open(route, door_step)


static func enter_scenario_room(campaign: Dictionary, zone: int, door_step: int) -> bool:
	if zone < 0 or not can_enter_scenario_room(campaign, door_step):
		return false
	corridor(campaign).current_room = zone
	return true


static func leave_scenario_room(campaign: Dictionary) -> bool:
	if not in_corridor(campaign) or int(corridor(campaign).get("current_room", -1)) == -1:
		return false
	corridor(campaign).current_room = -1
	return true


# ---------------------------------------------------------------- eventos

static func can_choose(campaign: Dictionary, choice: Dictionary) -> bool:
	var unavailable: String = choice.get("UnavailableIfUnlocked", "")
	if unavailable != "" and campaign.unlocked_classes.has(unavailable):
		return false
	var expedition: Dictionary = campaign.session.expedition
	match choice.get("Requirement", ""):
		"ClassInTeam":
			return _team_alive(campaign).any(func(h): return h.class_id == choice.get("RequirementClass", ""))
		"ClassUnlocked":
			return campaign.unlocked_classes.has(choice.get("RequirementClass", ""))
		"FoodAtLeast":
			return food(campaign) >= int(choice.get("RequirementAmount", 0))
		"ScrapAtLeast":
			return expedition.loot.scrap >= int(choice.get("RequirementAmount", 0))
		"HasTool":
			return has_tool(campaign, choice.get("RequirementTool", ""))
	return true


## Escolher uma opção do evento aberto (ChooseEventOption). Arriscada, pode dar errado (a chance não aparece).
static func choose_event_option(campaign: Dictionary, choice_id: String, seed_value: int) -> bool:
	var session: Dictionary = campaign.session
	var event = session.get("event")
	if event == null or event.resolution != "" or session.result != "":
		return false
	var row = GameData.row("events", event.event_id)
	var choice = null
	for option in (row.get("Choices", []) if row != null else []):
		if option.Id == choice_id:
			choice = option
	if choice == null or not can_choose(campaign, choice):
		return false
	var random := _rand(seed_value)
	var failed: bool = float(choice.get("FailChance", 0.0)) > 0.0 and random.next() < float(choice.FailChance)
	var effects: Dictionary = choice.get("Failure", {}) if failed else choice.get("Success", {})
	var expedition: Dictionary = session.expedition
	# O que mudou de fato (com os limites), para os chips do resultado (#106): [{kind, amount, hero}].
	var changes: Array = []
	var hope_before: int = expedition.hope
	expedition.hope = clampi(expedition.hope + int(effects.get("HopeDelta", 0)), 0, 100)
	if expedition.hope != hope_before:
		changes.append({"kind": "hope", "amount": expedition.hope - hope_before, "hero": ""})
	for spec in [["FoodDelta", "food"], ["BandagesDelta", "bandages"], ["ScrapDelta", "scrap"], ["FragmentsDelta", "fragments"], ["SeedsDelta", "seeds"]]:
		var moved := adjust(campaign, spec[1], int(effects.get(spec[0], 0)))
		if moved != 0:
			changes.append({"kind": spec[1], "amount": moved, "hero": ""})
	var instinct := 0
	if int(effects.get("InstinctDelta", 0)) != 0 and choice.get("Requirement", "") == "ClassInTeam":
		for hero in _team_alive(campaign):
			if hero.class_id == choice.get("RequirementClass", ""):
				var relic = GameData.row("relics", hero.get("relic_id", ""))
				instinct = maxi(0, int(effects.InstinctDelta) - (int(relic.get("EventInstinctReduction", 0)) if relic != null else 0))
				var instinct_before: int = hero.instinct
				hero.instinct = clampi(hero.instinct + instinct, 0, 200)
				# O texto ({Instinto}) e o chip dizem a mudança de fato (no limite de 200, menos que a dos dados).
				instinct = hero.instinct - instinct_before
				if hero.instinct != instinct_before:
					changes.append({"kind": "instinct", "amount": hero.instinct - instinct_before, "hero": hero.display_name})
				break
	var hurt := ""
	# O herói sorteado leva o dano; sem dano, só empresta o nome ao texto ({Heroi}).
	if int(effects.get("Damage", 0)) > 0 or String(effects.get("Result", "")).contains("{Heroi}"):
		var team := _team_alive(campaign)
		if not team.is_empty():
			var hero: Dictionary = team[mini(team.size() - 1, floori(random.next() * team.size()))]
			var hp_before: int = hero.hp
			hero.hp = maxi(1, hero.hp - int(effects.get("Damage", 0)))
			hurt = hero.display_name
			if hero.hp != hp_before:
				changes.push_front({"kind": "life", "amount": hero.hp - hp_before, "hero": hurt})
	if grant_tool(campaign, String(effects.get("GrantTool", ""))):
		changes.append({"kind": "tool", "amount": 1, "hero": "", "id": String(effects.GrantTool)})
	if bool(effects.get("bLoseTool", false)) and String(choice.get("RequirementTool", "")) != "" and has_tool(campaign, choice.RequirementTool):
		lose_tool(campaign, choice.RequirementTool)
		changes.append({"kind": "tool", "amount": -1, "hero": "", "id": String(choice.RequirementTool)})
	var unlock: String = effects.get("UnlockClass", "")
	if unlock != "" and not campaign.unlocked_classes.has(unlock):
		campaign.unlocked_classes.append(unlock)
	for effect in effects.get("PhaseEffects", []):
		if not expedition.corridor.effects.has(effect):
			expedition.corridor.effects.append(effect)
		# O chip diz o efeito, mesmo se ele já valia (o texto do resultado o promete de novo).
		if PHASE_EFFECTS.has(effect):
			changes.append({"kind": "effect", "amount": 1 if PHASE_EFFECTS[effect].good else -1, "hero": "", "id": String(effect)})
	var resolution := String(effects.get("Result", "")).replace("{Instinto}", str(instinct)).replace("{Heroi}", hurt)
	event.resolution = resolution if resolution != "" else String(choice.get("Text", "…"))
	# O modelo em português e o que entra nele, para a tela traduzir (#35, #64): o save continua em português.
	event.result_key = String(effects.get("Result", "")) if resolution != "" else String(choice.get("Text", "…"))
	event.hero = hurt
	event.instinct = instinct
	event.pending_hard_combat = bool(effects.get("bHardCombat", false))
	# Opcional no save: um evento salvo antes não tem a lista, e o resultado mostra só o texto.
	event.changes = changes
	return true


## O resultado do evento na tela, no idioma do jogo: o modelo traduzido com o herói e o instinto dele; um evento de um
## save anterior (sem o modelo), o texto gravado.
static func resolution_text(event: Dictionary) -> String:
	var key := String(event.get("result_key", ""))
	if key == "":
		return TranslationServer.translate(String(event.get("resolution", "")))
	return TranslationServer.translate(key).replace("{Instinto}", str(event.get("instinct", 0))).replace("{Heroi}", String(event.get("hero", "")))


## Fecha o evento resolvido. Do objeto de uma casa, a fase continua.
static func finish_event(campaign: Dictionary) -> bool:
	var event = campaign.session.get("event")
	if event == null or event.resolution == "":
		return false
	campaign.session.event = null
	campaign.session.screen = "corridor"
	return true


# ---------------------------------------------------------------- acampamento

static func can_start_camp(campaign: Dictionary) -> bool:
	if not in_corridor(campaign):
		return false
	var route: Dictionary = corridor(campaign)
	if route.current_house < 0 or route.current_house >= route.sites.size():
		return false
	var site: Dictionary = route.sites[route.current_house]
	return site.camp_site and not camped(route) and (not site.has_enemy or site.enemy_defeated)


static func start_camp(campaign: Dictionary) -> bool:
	if not can_start_camp(campaign):
		return false
	campaign.session.screen = "rest"
	# As habilidades de acampamento (#261): o Tempo de fogueira volta inteiro.
	AHCampSkills.start(campaign)
	return true


## Um acampamento por fase: o da casa ou o da parada de descanso (#143), o que vier primeiro.
static func camped(route: Dictionary) -> bool:
	return bool(route.get("stop_camped", false)) or route.sites.any(func(s): return s.camped)


## A casa do acampamento na mesma parada de descanso (o trecho dela), aberta e sem patrulha de pé; -1 se não houver.
## Aí as duas viram uma parada só: Acampar aqui entra nela.
static func stop_camp_house(campaign: Dictionary) -> int:
	var route: Dictionary = corridor(campaign)
	for i in route.sites.size():
		var site: Dictionary = route.sites[i]
		if site.camp_site and site.step == route.index and (not site.locked or site.forced) and (not site.has_enemy or site.enemy_defeated):
			return i
	return -1


## Acampar na parada de descanso (#143): só no trecho de descanso em que a equipe está, uma vez por fase.
static func can_camp_at_stop(campaign: Dictionary) -> bool:
	if not in_corridor(campaign):
		return false
	var route: Dictionary = corridor(campaign)
	return route.current_house == -1 and route.steps[route.index].type == "rest" and not camped(route)


## Acende a fogueira na parada (x: a fogueira; leave: onde a fila recomeça). A volta ao jogo no meio do acampamento a
## refaz no mesmo lugar.
static func start_stop_camp(campaign: Dictionary, x: float, leave: float) -> bool:
	if not can_camp_at_stop(campaign):
		return false
	corridor(campaign).stop_camp = {"step": corridor(campaign).index, "x": x, "leave": leave}
	campaign.session.screen = "rest"
	AHCampSkills.start(campaign)
	return true


static func _camp_hero(campaign: Dictionary, hero_id: String):
	if campaign.session.get("screen") != "rest" or not campaign.session.expedition.team.has(hero_id):
		return null
	for hero in campaign.roster:
		if hero.id == hero_id and hero.alive:
			return hero
	return null


## Quanto o comer do acampamento tira de instinto (a barra e a Mochila, decisão do Lucas, #98).
const CAMP_MEAL_INSTINCT := 5


## A cura do comer do acampamento: +10% da vida, mínimo 1.
static func camp_meal_heal(max_hp: int) -> int:
	return maxi(1, max_hp / 10)


## O que um cuidado faria no herói, sem gastar nada (#109): {hp, instinct, effect}. "food" é a Ração (+10% da vida e −5
## de instinto; sem efeito só com a vida cheia e o instinto em 0), "bandage" o Curativo (+8; sem efeito com a vida
## cheia). O estoque não entra: a tela diz à parte quando ele acabou. As mesmas contas de camp_use_food e
## camp_use_bandage.
static func camp_preview(campaign: Dictionary, hero_id: String, kind: String) -> Dictionary:
	var hero = _camp_hero(campaign, hero_id)
	if hero == null:
		return {"hp": 0, "instinct": 0, "effect": false}
	if kind == "food":
		return {"hp": mini(hero.max_hp, hero.hp + camp_meal_heal(hero.max_hp)), "instinct": clampi(hero.instinct - CAMP_MEAL_INSTINCT, 0, 200),
			"effect": not (hero.hp >= hero.max_hp and hero.instinct <= 0)}
	return {"hp": mini(hero.max_hp, hero.hp + 8), "instinct": int(hero.instinct), "effect": hero.hp < hero.max_hp}


## Comer no acampamento: +10% da vida (mínimo 1) e -5 de instinto; gasta uma comida.
static func camp_use_food(campaign: Dictionary, hero_id: String) -> bool:
	var hero = _camp_hero(campaign, hero_id)
	if hero == null or food(campaign) <= 0 or (hero.hp >= hero.max_hp and hero.instinct <= 0):
		return false
	adjust(campaign, "food", -1)
	hero.hp = mini(hero.max_hp, hero.hp + camp_meal_heal(hero.max_hp))
	hero.instinct = clampi(hero.instinct - CAMP_MEAL_INSTINCT, 0, 200)
	return true


## Curativo no acampamento: +8 de vida; gasta um curativo do refúgio.
static func camp_use_bandage(campaign: Dictionary, hero_id: String) -> bool:
	var hero = _camp_hero(campaign, hero_id)
	if hero == null or campaign.inventory.bandages <= 0 or hero.hp >= hero.max_hp:
		return false
	adjust(campaign, "bandages", -1)
	hero.hp = mini(hero.max_hp, hero.hp + 8)
	return true


## Levantar acampamento: a casa fica acampada nesta fase e o tempo passa (nunca o mesmo clima).
static func leave_camp(campaign: Dictionary, seed_value: int) -> bool:
	if campaign.session.get("screen") != "rest":
		return false
	var expedition: Dictionary = campaign.session.expedition
	var route: Dictionary = expedition.corridor
	if route.current_house >= 0:
		route.sites[route.current_house].camped = true
	if route.has("stop_camp"):
		route.erase("stop_camp")
		route.stop_camped = true
	# A noite (#261): a Noite mal dormida, a menos que alguém tenha vigiado (o resultado fica em camp_night, para o aviso).
	AHCampSkills.night(campaign)
	var options: Array = WEATHERS.get(expedition.scenario_id, WEATHERS["rua-das-vitrines"]).filter(func(w): return w != route.weather)
	var random := _rand(seed_value)
	route.weather = options[clampi(floori(random.next() * options.size()), 0, options.size() - 1)]
	campaign.session.screen = "corridor"
	return true
