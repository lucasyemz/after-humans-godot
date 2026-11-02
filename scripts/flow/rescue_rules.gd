## O resgate (#188, com as missões solo da #183; decisão do Lucas de 28/10): o herói capturado pelos robôs numa missão
## solo e o pedido de ajuda (um animal desconhecido preso) ficam no Mapa das missões solo como pinos de resgate. Na
## próxima expedição à fase deles, a rota tem o preso num trecho de Suprimentos (nunca o primeiro), guardado pela
## patrulha. Solto, o jogador escolhe: entrar na equipe (cheia, alguém volta para a Estação, sem perder nada), ir para a
## Estação (chega na volta, até na derrota) ou, no pedido de ajuda, deixar (com um pouco de comida). Os números ficam em
## data/rescue.json; o pedido, em campaign.station.side_missions (help, help_misses); o resgate da rota, em
## expedition.corridor.rescue = {step, kind ("captured" ou "help"), hero_id, recruit, state, out}.
class_name AHRescue
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const J = preload("res://scripts/flow/journey_rules.gd")
const M = preload("res://scripts/flow/side_mission_rules.gd")

## O estado do resgate na rota: esperando (preso), solto (a escolha aberta) e o que se escolheu.
const WAITING := "waiting"
const FREED := "freed"
const JOINED := "joined"
const SENT := "station"
const LEFT := "left"


static func rules() -> Dictionary:
	var row = GameData.row("rescue", "rules")
	return row if row != null else {}


## O pedido de ajuda no mapa ({} sem nenhum): {phase, recruit {class_id, display_name, perks, art_variant, origin}, day}.
static func help(campaign: Dictionary) -> Dictionary:
	var value = M.state(campaign).get("help", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


## Um dia novo: sem pedido no mapa, o rádio pode captar um (Chance, mais ChanceStep a cada dia sem, até ChanceMax), numa
## das fases liberadas da lista. O animal é de uma classe com arte e lugar no Alojamento, como o do trem.
static func on_new_day(campaign: Dictionary) -> void:
	var state := M.state(campaign)
	if not help(campaign).is_empty():
		return
	var r := rules()
	var phases: Array = Array(r.get("Phases", [])).filter(func(id): return S.phase_unlocked(campaign, id))
	if phases.is_empty():
		return
	var misses := int(state.get("help_misses", 0))
	var chance := mini(int(r.get("Chance", 25)) + int(r.get("ChanceStep", 10)) * misses, int(r.get("ChanceMax", 60)))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("help:%d:%d" % [int(state.seed), M.day(campaign)])
	var classes := S.train_classes(campaign)
	if rng.randi_range(1, 100) > chance or classes.is_empty():
		state.help_misses = misses + 1
		return
	var drawn := S._train_animal(campaign, classes, rng, [])
	state.help = {"phase": phases[rng.randi() % phases.size()], "recruit": drawn.recruit, "day": M.day(campaign)}
	state.help_misses = 0


## Os resgates pendentes, os capturados primeiro (são nossos): [{kind, phase, name, hero_id, recruit}].
static func pending(campaign: Dictionary) -> Array:
	var out: Array = []
	for entry in M.captured(campaign):
		out.append({"kind": "captured", "phase": String(entry.captured.get("phase", "fase_1")), "name": String(entry.display_name),
			"hero_id": String(entry.id), "recruit": {}})
	var request := help(campaign)
	if not request.is_empty():
		out.append({"kind": "help", "phase": String(request.phase), "name": String(request.recruit.display_name), "hero_id": "",
			"recruit": request.recruit})
	return out


## Na partida: se há um resgate na fase, o primeiro da lista vai para um trecho de Suprimentos que não é o primeiro da
## rota (o sorteio da expedição, à parte: a rota de 10 trechos não muda). O tutorial não tem resgate.
static func assign(campaign: Dictionary) -> void:
	var expedition: Dictionary = campaign.session.expedition
	var route: Dictionary = expedition.corridor
	var targets := pending(campaign).filter(func(target): return target.phase == String(expedition.phase_id))
	if targets.is_empty():
		return
	# Um trecho de Suprimentos com uma patrulha antes ("guardado pela patrulha"); sem nenhum, qualquer um depois da
	# partida.
	var loots: Array = range(1, route.steps.size()).filter(func(index): return String(route.steps[index].type) == "loot")
	# De preferência fora dos trechos que o desvio do bueiro (#289) pode pular; sem nenhum, num deles, e descendo, o preso
	# passa para a busca do ramal (AHJourneyRules.take_detour).
	var skippable: Array = AHJourneyRules.detour_skippable(route)
	var outside: Array = loots.filter(func(index): return not skippable.has(index))
	if not outside.is_empty():
		loots = outside
	var guarded: Array = loots.filter(func(index): return range(index).any(func(before): return String(route.steps[before].type) == "combat"))
	if not guarded.is_empty():
		loots = guarded
	if loots.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:rescue" % String(expedition.id))
	var target: Dictionary = targets[0]
	route.rescue = {"step": loots[rng.randi() % loots.size()], "kind": target.kind, "hero_id": target.hero_id,
		"recruit": target.recruit.duplicate(true), "state": WAITING, "out": ""}


## O resgate da rota de agora ({} sem nenhum).
static func current(campaign: Dictionary) -> Dictionary:
	var expedition = campaign.get("session", {}).get("expedition")
	if typeof(expedition) != TYPE_DICTIONARY or typeof(expedition.get("corridor")) != TYPE_DICTIONARY:
		return {}
	var value = expedition.corridor.get("rescue", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


## O nome de quem está preso.
static func prisoner_name(campaign: Dictionary) -> String:
	var rescue := current(campaign)
	if rescue.is_empty():
		return ""
	if rescue.kind == "captured":
		var entry = S.hero(campaign, String(rescue.hero_id))
		return String(entry.display_name) if entry != null else ""
	return String(rescue.recruit.get("display_name", ""))


## Quem é o preso: "Gato · Incursão · Ágil, Ansioso" (a espécie, o papel e os traços).
static func profile_text(campaign: Dictionary) -> String:
	var rescue := current(campaign)
	var class_id := ""
	var perks: Array = []
	if rescue.get("kind", "") == "captured":
		var entry = S.hero(campaign, String(rescue.hero_id))
		if entry != null:
			class_id = String(entry.class_id)
			perks = entry.get("perks", [])
	else:
		class_id = String(rescue.get("recruit", {}).get("class_id", ""))
		perks = rescue.get("recruit", {}).get("perks", [])
	var names: Array = perks.map(func(id):
		var perk = GameData.row("perks", String(id))
		return TranslationServer.translate(String(perk.DisplayName)) if perk != null else String(id))
	# A espécie e o papel (#189): "Coruja · Tiro".
	var who = S.hero(campaign, String(rescue.get("hero_id", ""))) if rescue.kind == "captured" else rescue.get("recruit", {})
	var kind: String = AHSpecies.kind_text(who) if GameData.row("classes", class_id) != null else class_id
	return kind if names.is_empty() else " · ".join([kind, ", ".join(names)])


## Dá para soltar: o preso espera (ou já solto, com a escolha por fazer) e as patrulhas até o trecho dele foram
## vencidas (andar para trás na rua não o prende de novo).
static func can_free(campaign: Dictionary) -> bool:
	var rescue := current(campaign)
	if rescue.is_empty() or not [WAITING, FREED].has(String(rescue.state)):
		return false
	var steps: Array = campaign.session.expedition.corridor.steps
	return range(mini(int(rescue.step), steps.size())).all(func(index): return bool(steps[index].resolved) or not ["combat", "boss"].has(String(steps[index].type)))


## Solta o preso: a escolha fica aberta (o save no meio volta com ela).
static func release(campaign: Dictionary) -> bool:
	if not can_free(campaign):
		return false
	current(campaign).state = FREED
	return true


## Cabe mais um no Alojamento? O capturado já é do elenco; o pedido de ajuda precisa de lugar.
static func has_room(campaign: Dictionary) -> bool:
	return current(campaign).get("kind", "") == "captured" or not S.heroes_full(campaign)


## A equipe está cheia (o máximo da fase)?
static func team_full(campaign: Dictionary) -> bool:
	var expedition: Dictionary = campaign.session.expedition
	return expedition.team.size() >= int(J.team_limits(String(expedition.phase_id)).max)


## Quem pode sair para dar lugar: da equipe, de pé (o caído no mapa e o levantado não).
static func can_leave_team(campaign: Dictionary) -> Array:
	var expedition: Dictionary = campaign.session.expedition
	var down: Array = expedition.get("downed", []).map(func(entry): return entry.hero_id)
	return expedition.team.filter(func(id):
		var entry = S.hero(campaign, id)
		return entry != null and entry.alive and not down.has(id))


## Por que a opção não vale ("" vale): "join", "station" ou "leave".
static func choice_block(campaign: Dictionary, option: String) -> String:
	var rescue := current(campaign)
	if rescue.is_empty() or rescue.state != FREED:
		return TranslationServer.translate("Ninguém foi solto aqui.")
	match option:
		"join", "station":
			if not has_room(campaign):
				return TranslationServer.translate("O Alojamento está cheio: não há onde ficar na Estação.")
			if option == "join" and team_full(campaign) and can_leave_team(campaign).is_empty():
				return TranslationServer.translate("Ninguém da equipe pode dar o lugar agora.")
		"leave":
			if rescue.kind == "captured":
				return TranslationServer.translate("Ninguém da Estação fica para trás.")
	return ""


## A escolha depois de soltar. out_id: quem sai da equipe para dar lugar (só com ela cheia). Devolve "" ou o motivo.
## Entrar: o resgatado entra agora, com HpRatio da vida e Instinct de instinto; quem sai volta à Estação na volta (fica
## fora da equipe, com a vida que tinha, sem o XP da jornada). Estação: chega na volta, até na derrota. Deixar: a
## equipe deixa LeaveFood de comida com ele.
static func choose(campaign: Dictionary, option: String, out_id: String = "") -> String:
	var block := choice_block(campaign, option)
	if block != "":
		return block
	var rescue := current(campaign)
	var expedition: Dictionary = campaign.session.expedition
	match option:
		"join":
			if team_full(campaign):
				if not can_leave_team(campaign).has(out_id):
					return TranslationServer.translate("Escolha quem da equipe dá o lugar.")
				expedition.team.erase(out_id)
				rescue.out = out_id
			var entry = _bring(campaign, rescue)
			expedition.team.append(entry.id)
			rescue.hero_id = entry.id
			rescue.state = JOINED
		"station":
			rescue.state = SENT
		"leave":
			# Sem comida, a equipe segue sem deixar nada (food_left 0: o relatório não fala de comida).
			var leave := mini(int(rules().get("LeaveFood", 1)), maxi(0, int(expedition.food)))
			expedition.food = int(expedition.food) - leave
			rescue.food_left = leave
			rescue.state = LEFT
	# O pin sai do Mapa das missões: o pedido decidido não volta (§14.4); o capturado sai da lista ao chegar.
	if rescue.kind == "help":
		M.state(campaign).help = {}
	return ""


## Põe o resgatado no elenco (o pedido vira herói) ou o tira do cativeiro (o capturado), com a vida e o instinto do
## resgate.
static func _bring(campaign: Dictionary, rescue: Dictionary) -> Dictionary:
	var entry
	if rescue.kind == "captured":
		entry = S.hero(campaign, String(rescue.hero_id))
		entry.erase("captured")
	else:
		var recruit: Dictionary = rescue.recruit
		var class_id := String(recruit.class_id)
		var hero_id := S._next_hero_id(campaign, class_id)
		S._add_hero(campaign, hero_id, class_id, String(recruit.display_name), Array(recruit.get("perks", [])), String(recruit.get("art_variant", "")))
		entry = S.hero(campaign, hero_id)
	var r := rules()
	entry.hp = maxi(1, ceili(int(entry.max_hp) * float(r.get("HpRatio", 0.5))))
	entry.instinct = int(r.get("Instinct", 20))
	entry.alive = true
	return entry


## Na volta (finish_return): quem foi mandado para a Estação chega (até na derrota). Devolve a linha do relatório ("" sem
## resgate). O preso que ninguém soltou continua no mapa.
static func on_return(campaign: Dictionary) -> String:
	var rescue := current(campaign)
	if rescue.is_empty():
		return ""
	match String(rescue.state):
		SENT:
			var entry := _bring(campaign, rescue)
			rescue.hero_id = entry.id
			return TranslationServer.translate("%s saiu do cativeiro e chegou à Estação.") % entry.display_name
		JOINED:
			var entry = S.hero(campaign, String(rescue.hero_id))
			var line: String = TranslationServer.translate("%s saiu do cativeiro e voltou com a equipe.") % (entry.display_name if entry != null else "?")
			var out = S.hero(campaign, String(rescue.out)) if String(rescue.out) != "" else null
			if out != null:
				line += " " + TranslationServer.translate("%s deu o lugar e voltou pelo caminho já limpo.") % out.display_name
			return line
		LEFT:
			var who := String(rescue.recruit.get("display_name", ""))
			return TranslationServer.translate("A equipe deixou %s com um pouco de comida.") % who if int(rescue.get("food_left", 1)) > 0 \
				else TranslationServer.translate("A equipe deixou %s para trás, sem comida para dividir.") % who
	return ""
