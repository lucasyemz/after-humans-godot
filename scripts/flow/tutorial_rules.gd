## O tutorial da abertura (#144) no Corredor de Contenção (#147): a jornada curta do Bento, da Íris e da Véspera até o
## trem, com o Nick, que chega no aperto (docs/narrative/bento-nick-arc.md §3 e §26), como
## uma expedição de fase "tutorial" que a rua joga com o mesmo corredor. Sem cena: lê data/tutorial.json (as linhas pelo
## Name) e mexe no estado da campanha, como o AHJourneyRules.
##   journey: o mapa, o lugar dos eventos, o clima, os trechos (Steps, um por tipo), quantos trechos ficam em cada zona
##            do mapa (ZoneSteps), quem começa (StartTeam), quem chega no meio (JoinTeam) e o que a busca rende (Search,
##            com Heal: a fração da vida máxima que a equipe recupera)
##   fight_N: as lutas fixas (o trecho, os inimigos da frente para trás, o que cada uma ensina e o reforço só do
##            tutorial, Boost: por inimigo, Damage e Speed a mais ou a menos; o dano mínimo de cada ação fica em 1 ou mais)
## A fase do tutorial não está em AHJourneyRules.PHASES: não aparece no Mapa da Rede nem no "Jogar de novo".
class_name AHTutorial
extends RefCounted

const PHASE_ID := "tutorial"
const MAP := "ContainmentCorridor"


static func row(row_name: String) -> Dictionary:
	var found = GameData.row("tutorial", row_name)
	return found if found != null else {}


static func journey() -> Dictionary:
	return row("journey")


## A "fase" do tutorial no formato das de AHJourneyRules.PHASES (o mapa, o nível, o tipo do nó e o número de trechos).
static func phase_info() -> Dictionary:
	var data := journey()
	return {"id": PHASE_ID, "scenario": String(data.get("Place", "corredor-de-contencao")), "name": "Corredor de Contenção",
		"level": 1, "node_type": PHASE_ID, "map": String(data.get("Map", MAP)), "transit": "", "transit_steps": 0, "difficulty": 0,
		"steps": data.get("Steps", []).size(), "map_pos": [0, 0], "description": ""}


static func is_tutorial(campaign: Dictionary) -> bool:
	var expedition = campaign.get("session", {}).get("expedition")
	return expedition != null and String(expedition.get("phase_id", "")) == PHASE_ID


## Os trechos do tutorial (o corredor de AHJourneyRules.create_corridor, com os tipos fixos e o clima do subsolo).
static func corridor(seed_value: int) -> Dictionary:
	var data := journey()
	var steps: Array = []
	for kind in data.get("Steps", []):
		steps.append({"type": String(kind), "resolved": kind == "start"})
	return {
		"node_id": PHASE_ID, "node_type": PHASE_ID, "seed": seed_value & 0xFFFFFFFF, "index": 0, "steps": steps,
		"weather": String(data.get("Weather", "night")), "sites": [], "current_house": -1, "effects": [], "props": {},
		"prop_steps": [], "prop_maps": [], "searched_props": [], "objective_prop": -1, "current_room": -1, "choice_props": [],
	}


## Começa a jornada do tutorial: a equipe de StartTeam (os que existem no elenco), na partida do corredor.
static func start_journey(campaign: Dictionary, seed_value: int = 20261026) -> bool:
	var team: Array = []
	for hero_id in journey().get("StartTeam", []):
		var hero = AHStationRules.hero(campaign, hero_id)
		if hero != null and hero.get("alive", true):
			team.append(hero_id)
	if team.is_empty():
		return false
	for hero in campaign.roster:
		hero.expedition_uses = {}
		hero.instinct = 0
	var expedition := {
		"id": "tutorial_%d" % seed_value, "seed": seed_value & 0x7FFFFFFF, "phase_id": PHASE_ID, "scenario_id": phase_info().scenario,
		"level": 1, "team": team, "food": AHJourneyRules.FREE_FOOD, "hope": 80, "relationships": {},
		"loot": {"seeds": 0, "scrap": 0, "fragments": 0}, "opening_used": false, "objective_completed": false,
	}
	expedition.corridor = corridor(expedition.seed)
	campaign.session = {"screen": "corridor", "result": "", "expedition": expedition, "event": null}
	return true


## A luta fixa do trecho ({} se o trecho não tem luta do tutorial).
static func fight_at(step: int) -> Dictionary:
	for row_name in GameData.table("tutorial"):
		var entry: Dictionary = GameData.row("tutorial", row_name)
		if String(row_name).begins_with("fight_") and int(entry.get("Step", -1)) == step:
			return entry
	return {}


## Os inimigos da luta do trecho, montados como os do corredor (AHJourneyRules.corridor_enemies).
static func enemies_at(expedition: Dictionary, step: int) -> Array:
	var out: Array = []
	var fight := fight_at(step)
	var ids: Array = fight.get("Enemies", [])
	for unit in ids.size():
		var row = GameData.row("enemies", ids[unit])
		if row == null:
			# Um id que não existe em enemies.json deixaria a luta mais curta sem aviso (test_tutorial_map confere os dados).
			push_error("Tutorial: inimigo %s da luta do trecho %d não existe em enemies.json." % [ids[unit], step])
			continue
		# O reforço só do tutorial (Boost, por inimigo): mais dano para a vida mexer na primeira luta e mais velocidade
		# para quem precisa agir antes de cair (o Drone que contamina); enemies.json fica como está.
		var boost: Dictionary = fight.get("Boost", {}).get(ids[unit], {})
		out.append({"enemy_id": ids[unit], "unit_id": "tutorial_%d_%d_%s" % [step, unit, ids[unit]], "rank": unit + 1,
			"max_hp": int(row.MaxHp), "hp": int(row.MaxHp), "damage_bonus": int(boost.get("Damage", 0)),
			"speed_bonus": int(boost.get("Speed", 0)), "display_name": row.DisplayName})
	return out


## Quantos trechos ficam em cada zona do mapa (o corredor do tutorial não divide pelo comprimento).
static func zone_steps() -> Array:
	return journey().get("ZoneSteps", [])


## A busca do tutorial rende sempre o mesmo (Search): nada de busca ruim enquanto se aprende a vasculhar.
static func search(campaign: Dictionary) -> String:
	var parts: Array = []
	var found: Dictionary = journey().get("Search", {})
	# As palavras do achado são as do efeito da busca na rua (street_corridor._show_gains), já traduzidas.
	for spec in [["bandages", "curativo", "curativos"], ["food", "comida", "comidas"]]:
		if int(found.get(spec[0], 0)) > 0:
			var got := AHJourneyRules.adjust(campaign, spec[0], int(found[spec[0]]))
			if got > 0:
				parts.append("+%d %s" % [got, TranslationServer.translate(spec[1] if got == 1 else spec[2])])
	return ", ".join(parts)


## O fôlego da busca (Search.Heal, a fração da vida máxima): entre a segunda e a terceira luta a equipe se recompõe, e o
## piso de vida 1 das lutas do tutorial fica só como rede, não como o que segura a luta do Drone. Devolve se alguém curou.
static func catch_breath(campaign: Dictionary) -> bool:
	var heal := float(journey().get("Search", {}).get("Heal", 0.0))
	var healed := false
	for hero_id in campaign.session.expedition.team:
		var hero = AHStationRules.hero(campaign, hero_id)
		if heal <= 0.0 or hero == null or int(hero.hp) >= int(hero.max_hp):
			continue
		hero.hp = mini(int(hero.max_hp), int(hero.hp) + ceili(float(hero.max_hp) * heal))
		healed = true
	return healed


## O Nick (JoinTeam) entra na equipe e o encontro fica resolvido. Devolve quem entrou.
static func join(campaign: Dictionary) -> Array:
	if not is_tutorial(campaign):
		return []
	var expedition: Dictionary = campaign.session.expedition
	var joined: Array = []
	for hero_id in journey().get("JoinTeam", []):
		var hero = AHStationRules.hero(campaign, hero_id)
		if hero != null and hero.get("alive", true) and not expedition.team.has(hero_id) and expedition.team.size() < 4:
			expedition.team.append(hero_id)
			hero.expedition_uses = {}
			joined.append(hero_id)
	resolve_step(campaign, "nick")
	return joined


## Resolve o trecho atual se ele é do tipo pedido (o encontro, a chegada do trem).
static func resolve_step(campaign: Dictionary, kind: String) -> bool:
	if not is_tutorial(campaign):
		return false
	var route: Dictionary = campaign.session.expedition.corridor
	var step: Dictionary = route.steps[route.index]
	if step.type != kind or step.resolved:
		return false
	step.resolved = true
	return true


## O embarque: a jornada termina e a campanha volta à Estação, com a equipe do tutorial inteira (vida cheia, instinto
## zerado). Só quem foi ao tutorial: o resto do elenco fica como está.
static func finish(campaign: Dictionary) -> void:
	var expedition = campaign.get("session", {}).get("expedition")
	var team: Array = expedition.get("team", []) if expedition != null else []
	for hero in campaign.get("roster", []):
		if not team.has(hero.id):
			continue
		hero.hp = int(hero.max_hp)
		hero.instinct = 0
		hero.trauma = false
		hero.expedition_uses = {}
	campaign.session = {"screen": "shelter", "result": "", "expedition": null, "event": null}
