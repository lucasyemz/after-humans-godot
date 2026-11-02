## O desvio pelo esgoto da Rua das Vitrines (#289): o ramal sorteado com a rota (1 a 3 patrulhas, uma busca e a
## passagem por último), quem acha o bueiro (um cão vivo e de pé; sem ele, a sorte da rota, às cegas), a dica do
## barulho, a descida (os trechos do ramal no lugar dos pulados, as casas puladas fora do caminho, o Instinto), o mapa
## de cada trecho, a passagem com o evento dela, o achado das patrulhas de lá, a subida, o objetivo da rota fora dos
## trechos pulados e o save no meio do ramal.
extends RefCounted

const R = preload("res://scripts/flow/journey_rules.gd")
const S = preload("res://scripts/flow/station_rules.gd")
## As portas da rua (o trecho e a loja de cada uma), como a cena informa (street.door_specs).
const DOOR_STEPS := [1, 2, 4, 5, 7, 8]
const DOOR_SHOPS := [0, 1, 2, 0, 1, 2]
const BENTO := "hero_cao_bento"


func run(t) -> void:
	_plan(t)
	_reveal(t)
	_hint(t)
	_take(t)
	_walk_through(t)
	_objective(t)
	_save(t)
	_old_corridor(t)
	_gallery_props(t)
	_rescue(t)


func _campaign(seed_value: int, team: Array = []) -> Dictionary:
	var campaign: Dictionary = Campaign.create_initial(seed_value)
	R.start_expedition(campaign, "fase_1", seed_value * 7919 + 13)
	if not team.is_empty():
		campaign.session.expedition.team = team
	R.assign_search_sites(campaign.session.expedition.corridor, DOOR_STEPS, DOOR_SHOPS)
	return campaign


## Leva a equipe ao trecho da entrada, com ele vencido.
func _at_entry(campaign: Dictionary) -> Dictionary:
	var route: Dictionary = campaign.session.expedition.corridor
	var d := R.detour(route)
	for i in int(d.entry) + 1:
		route.steps[i].resolved = true
	route.index = int(d.entry)
	return route


func _plan(t) -> void:
	var counts := {1: 0, 2: 0, 3: 0}
	var lucky := 0
	var bad := 0
	for seed_value in 600:
		var route := R.create_corridor(seed_value * 131 + 7, "fase_1", "combat", "rua-das-vitrines")
		var d := R.detour(route)
		counts[int(d.patrols)] += 1
		lucky += 1 if d.luck else 0
		var plan: Array = d.plan
		if plan.size() != int(d.patrols) + 2 or plan[-1] != "passage" or plan.count("loot") != 1 or plan.count("combat") != int(d.patrols):
			bad += 1
	t.equal(bad, 0, "600 rotas: o ramal tem as patrulhas, uma busca e a passagem por último")
	t.check(absf(counts[1] / 600.0 - 0.45) < 0.06 and absf(counts[2] / 600.0 - 0.35) < 0.06 and absf(counts[3] / 600.0 - 0.2) < 0.05,
		"1, 2 ou 3 patrulhas em ~45%%, 35%% e 20%% das rotas (%s)" % [counts])
	t.check(lucky > 600 * 0.1 and lucky < 600 * 0.2, "a tampa solta sem farejador em ~15%% das rotas (%d de 600)" % lucky)
	t.equal(R.detour(R.create_corridor(5, "fase_2", "combat", "ponte-das-raizes")), {}, "fase sem desvio: nada")
	t.equal(R.create_corridor(42, "fase_1", "combat", "rua-das-vitrines").detour, R.create_corridor(42, "fase_1", "combat", "rua-das-vitrines").detour,
		"a mesma semente dá o mesmo ramal")


func _reveal(t) -> void:
	# Com o Bento: ele fareja, a escolha abre só no trecho da entrada.
	var campaign := _campaign(3)
	var route: Dictionary = campaign.session.expedition.corridor
	t.equal(R.reveal_detour(campaign), "", "antes do trecho da entrada, nada")
	_at_entry(campaign)
	t.equal(R.reveal_detour(campaign), "scent", "no trecho da entrada vencido, o cão fareja")
	t.check(R.detour_open(campaign), "e a escolha de descer abre")
	t.check(R.detour_line(campaign).begins_with("O Bento parou"), "a fala é do Bento (%s)" % R.detour_line(campaign))
	t.equal(R.reveal_detour(campaign), "", "só uma vez")
	# Seguir pela rua fecha o bueiro.
	R.enter_step(campaign, route.index + 1)
	t.equal(R.detour(route).state, "declined", "passando do trecho pela rua, o bueiro fica para trás")
	t.check(not R.take_detour(campaign), "e não dá mais para descer")
	# Um cão recrutado também fareja, com o nome dele.
	campaign = _campaign(4)
	var recruit: Dictionary = S.recruit(campaign, "cao", RandomNumberGenerator.new(), "Brutus")
	t.equal(recruit.get("error", "?"), "", "um cão recrutado (%s)" % recruit.get("error", ""))
	campaign.session.expedition.team = [String(recruit.get("hero_id", "")), "hero_gato_nick"]
	_at_entry(campaign)
	t.equal(R.reveal_detour(campaign), "scent", "um cão recrutado também fareja")
	t.check(R.detour_line(campaign).begins_with("Brutus parou"), "com o nome dele, sem artigo (%s)" % R.detour_line(campaign))
	# O cão caído não fareja; sem cão, a sorte da rota decide.
	for luck in [false, true]:
		campaign = _campaign(5, [BENTO, "hero_gato_nick"])
		S.hero(campaign, BENTO).hp = 0
		R.detour(campaign.session.expedition.corridor).luck = luck
		_at_entry(campaign)
		var outcome := R.reveal_detour(campaign)
		t.equal(outcome, "blind" if luck else "", "cão sem vida e %s: %s" % ["sorte" if luck else "sem sorte", "às cegas" if luck else "nada"])
		t.equal(R.detour(campaign.session.expedition.corridor).state, "revealed" if luck else "none", "o estado guarda o que houve")
		if luck:
			t.equal(R.detour_line(campaign), R.detour_text("fase_1", "Blind"), "às cegas, a tampa solta")
			var blind_view := R.detour_view(campaign.session.expedition.corridor)
			t.check(blind_view.blind and blind_view.sub.size() == 1, "e a barra mostra só um \"?\" embaixo (sem o caminho)")
	# Com o faro, antes de descer, a barra não conta as patrulhas: sempre as mesmas casas com "?".
	var sizes := {}
	for seed_value in 40:
		var c := _campaign(200 + seed_value)
		_at_entry(c)
		if R.reveal_detour(c) == "scent":
			var view := R.detour_view(c.session.expedition.corridor)
			sizes[view.sub.size()] = true
			t.check(view.sub.all(func(e): return e.live == -1 and e.step.type == ""), "semente %d: o ramal todo em \"?\"" % seed_value)
	t.equal(sizes.keys(), [R.DETOUR_PREVIEW_CELLS], "o mesmo número de casas, seja quantas forem as patrulhas")


func _hint(t) -> void:
	var campaign := _campaign(6)
	var route: Dictionary = campaign.session.expedition.corridor
	var d := R.detour(route)
	var above := R.detour_street_patrols(route)
	t.check(above >= 1 and above <= 2, "a rua pulada tem 1 ou 2 patrulhas (%d)" % above)
	var hints: Dictionary = R.detour_def("fase_1").Hints
	for below in [1, 2, 3]:
		d.patrols = below
		var key := "less" if below < above else ("same" if below == above else "more")
		t.equal(R.detour_hint(route), hints[key], "%d embaixo contra %d em cima: %s" % [below, above, key])


func _take(t) -> void:
	var campaign := _campaign(7)
	var route: Dictionary = _at_entry(campaign)
	var d := R.detour(route)
	var before: Array = route.steps.duplicate(true)
	var instinct := {}
	for hero_id in campaign.session.expedition.team:
		instinct[hero_id] = int(S.hero(campaign, hero_id).instinct)
	t.check(not R.take_detour(campaign), "sem o bueiro achado, não desce")
	R.reveal_detour(campaign)
	var sites_before: Array = route.sites.duplicate(true)
	t.check(R.take_detour(campaign), "achado, desce")
	var k: int = d.plan.size()
	t.equal(route.steps.size(), before.size() - (int(d.exit) - int(d.entry) - 1) + k, "os trechos do ramal entram no lugar dos pulados")
	t.equal(route.steps[-1].type, "boss", "o guardião continua no fim")
	t.equal(route.steps.slice(int(d.first), int(d.first) + k).map(func(s): return s.type), d.plan, "o ramal na ordem sorteada")
	t.check(route.steps.slice(int(d.first), int(d.first) + k).all(func(s): return s.get("detour", false) and not s.resolved), "marcados como do ramal")
	t.equal(d.skipped, before.slice(int(d.entry) + 1, int(d.exit)), "os pulados ficam guardados para a barra")
	for i in route.sites.size():
		var step: int = int(sites_before[i].step)
		if step > int(d.entry) and step < int(d.exit):
			t.check(route.sites[i].get("skipped", false) and not R.can_enter_house(campaign, i), "a casa do trecho %d ficou para trás" % (step + 1))
		elif step >= int(d.exit):
			t.equal(int(route.sites[i].step), step + int(d.shift), "a casa do trecho %d anda junto" % (step + 1))
	for hero_id in instinct:
		t.equal(int(S.hero(campaign, hero_id).instinct), mini(200, instinct[hero_id] + 15), "%s: +15 de Instinto na descida" % hero_id)
	t.equal(R.route_map(campaign.session.expedition, int(d.first)), "SewerDucts", "o ramal fica nos Dutos")
	t.equal(R.route_map(campaign.session.expedition, int(d.first) + k), "", "e o trecho da saída, na rua")
	t.equal(R.original_index(route, int(d.first) + k), int(d.exit), "com o número de antes na barra")
	t.equal(R.route_place(campaign.session.expedition, int(d.first)), "Galeria sob as Vitrines", "o lugar do ramal tem o nome da fase 1")
	t.equal(R.detour_range(route, "SewerDucts"), [int(d.first), k], "os trechos do ramal no mapa dele")
	t.equal(R.step_text(route, int(d.first) + 1), "Trecho 2 de %d na Galeria" % k, "o número do trecho no ramal")
	t.equal(R.step_text(route, int(d.first) + k), "Trecho %d de 10" % (int(d.exit) + 1), "e na rua, o da barra")
	t.equal(R.step_text(route, route.steps.size() - 1, false), "Trecho 10", "o guardião continua no trecho 10")


func _walk_through(t) -> void:
	var campaign := _campaign(8)
	campaign.station.erase("detour_events")
	var route: Dictionary = _at_entry(campaign)
	R.reveal_detour(campaign)
	R.take_detour(campaign)
	var d := R.detour(route)
	var expedition: Dictionary = campaign.session.expedition
	var fragments: int = int(expedition.loot.fragments)
	var events := 0
	for i in range(int(d.first), int(d.first) + int(d.count)):
		var outcome := R.enter_step(campaign, i)
		t.check(R.in_detour(route), "trecho %d: no ramal" % (i + 1))
		match route.steps[i].type:
			"combat":
				t.equal(outcome, "combat", "a patrulha do ramal luta")
				var fight := R.start_corridor_combat(campaign, true)
				t.check(not fight.opening, "no escuro, sem a vantagem de abertura")
				var ids: Array = fight.enemies.map(func(u): return u.enemy_id)
				t.check(ids.all(func(id): return ["robot_fungo", "rastejante_raiz", "cao_eco"].has(id)), "os inimigos do esgoto (%s)" % [ids])
				t.equal(int(R.combat_loot(campaign, "victory", false).fragments), 1, "o resultado da luta mostra o fragmento")
				R.end_combat(campaign, "victory", false)
				fragments += 1
				t.equal(int(expedition.loot.fragments), fragments, "a patrulha vencida rende 1 fragmento")
			"passage":
				t.equal(outcome, "event", "a passagem abre o evento do ramal")
				t.equal(campaign.session.event.event_id, "setas_na_parede", "as setas na parede")
				R.choose_event_option(campaign, "levar_filtro", 1)
				R.finish_event(campaign)
				events += 1
			_:
				route.steps[i].resolved = true
	t.equal(events, 1, "o evento abriu uma vez")
	R.enter_step(campaign, int(d.first) + int(d.count))
	t.equal(d.state, "done", "subindo, o desvio acaba")
	t.check(not R.in_detour(route), "e a equipe está na rua")
	# Na próxima vez, a passagem do ramal é comum.
	var again := _campaign(9)
	again.station = campaign.station
	var route2 := _at_entry(again)
	R.reveal_detour(again)
	R.take_detour(again)
	var d2 := R.detour(route2)
	var passage: int = int(d2.first) + int(d2.count) - 1
	for i in range(int(d2.first), passage):
		route2.index = i
		route2.steps[i].resolved = true
	t.equal(R.enter_step(again, passage), "", "a passagem do ramal não repete o evento na campanha")


func _objective(t) -> void:
	var bad := 0
	var marked := 0
	for focus in S.FOCI:
		for seed_value in 80:
			var route := R.create_corridor(seed_value * 389 + 11, "fase_1", "combat", "rua-das-vitrines")
			R.assign_search_sites(route, DOOR_STEPS, DOOR_SHOPS, focus.id)
			for site in route.sites:
				if site.has("objective_spot"):
					marked += 1
					if R.detour_skippable(route).has(int(site.step)):
						bad += 1
	t.equal(bad, 0, "o objetivo nunca cai numa casa dos trechos que o desvio pula (%d objetivos)" % marked)
	t.check(marked >= S.FOCI.size() * 80 * 0.95, "e quase sempre há casa para ele (%d de %d)" % [marked, S.FOCI.size() * 80])


func _save(t) -> void:
	var campaign := _campaign(10)
	var route: Dictionary = _at_entry(campaign)
	R.reveal_detour(campaign)
	R.take_detour(campaign)
	R.enter_step(campaign, int(R.detour(route).first))
	var loaded = JSON.parse_string(JSON.stringify(campaign))
	var expedition: Dictionary = loaded.session.expedition
	t.equal(R.route_map(expedition, int(expedition.corridor.index)), "SewerDucts", "salvo no meio do ramal, volta nos Dutos")
	t.check(R.in_detour(expedition.corridor), "e no ramal")
	var view := R.detour_view(expedition.corridor)
	t.check(view.shown and view.main.size() == 10 and view.sub.size() == int(R.detour(expedition.corridor).count),
		"a barra volta igual: os 10 da rua e o ramal")


func _old_corridor(t) -> void:
	var campaign := _campaign(11)
	var route: Dictionary = campaign.session.expedition.corridor
	route.erase("detour")
	_at_entry_old(route)
	t.equal(R.reveal_detour(campaign), "", "corredor de save antigo: sem desvio")
	t.check(not R.detour_view(route).shown, "e sem a linha de baixo")
	t.equal(R.route_map(campaign.session.expedition, 3), "", "o mapa de cada trecho, como antes")
	t.equal(R.detour_skippable(route), [], "e o objetivo pode cair em qualquer casa")


func _at_entry_old(route: Dictionary) -> void:
	for i in 3:
		route.steps[i].resolved = true
	route.index = 2


## Os objetos da Galeria entram como pontos de busca do ramal, sem virar o objetivo da rota (que fica numa casa da rua).
func _gallery_props(t) -> void:
	var campaign := _campaign(12)
	campaign.session.expedition.focus = "parts"
	var route: Dictionary = _at_entry(campaign)
	R.reveal_detour(campaign)
	R.take_detour(campaign)
	var d := R.detour(route)
	var first := R.assign_scenario_props(campaign, "SewerDucts", [int(d.first) + 1, int(d.first) + 2], ["Armário de ferramentas", "Mochila de explorador"])
	t.equal(route.prop_steps.slice(first), [int(d.first) + 1, int(d.first) + 2], "os objetos da Galeria nos trechos do ramal")
	t.equal(int(route.objective_prop), -1, "e nenhum deles é o objetivo da rota")


## O resgate (#188) com o desvio (#295, QA): toda ida à fase tem o preso; ele fica de preferência fora dos trechos que o
## desvio pula, e descer leva o trecho dele junto com os de depois da saída (a barra marca a casa certa). Sem lugar fora,
## o preso de um trecho pulado passa para a busca do ramal.
func _rescue(t) -> void:
	var assigned := 0
	var shifted := 0
	var moved := 0
	for seed_value in range(1, 121):
		var campaign: Dictionary = Campaign.create_initial(seed_value)
		S.hero(campaign, "hero_sapo_iris").captured = {"mission": "cisterna_turva", "spot": 2, "phase": "fase_1", "day": 0}
		R.start_expedition(campaign, "fase_1", seed_value * 7919 + 13)
		var route: Dictionary = campaign.session.expedition.corridor
		# Toda ida à fase do resgate tem o preso: a tela prometeu que a rota passa por ele.
		if not t.check(route.has("rescue"), "semente %d: a rota da fase do resgate tem o preso" % seed_value) or R.detour(route).is_empty():
			continue
		assigned += 1
		var step := int(route.rescue.step)
		var loots_outside: Array = range(1, route.steps.size()).filter(func(i): return route.steps[i].type == "loot" and not R.detour_skippable(route).has(i))
		var inside := R.detour_skippable(route).has(step)
		t.check(not inside or loots_outside.is_empty(), "semente %d: o preso só fica num trecho pulável quando não há outro" % seed_value)
		var prisoner: Dictionary = route.steps[step]
		R.assign_search_sites(route, DOOR_STEPS, DOOR_SHOPS)
		_at_entry(campaign)
		R.reveal_detour(campaign)
		if not R.take_detour(campaign):
			continue
		shifted += 1
		if inside:
			moved += 1
			var at := int(route.rescue.step)
			t.check(route.steps[at].get("detour", false) and route.steps[at].type == "loot", "semente %d: o preso de um trecho pulado vai para a busca do ramal" % seed_value)
			continue
		t.check(is_same(route.steps[int(route.rescue.step)], prisoner), "semente %d: depois da descida, o resgate aponta o mesmo trecho" % seed_value)
		t.check(R.detour_view(route).sub.all(func(cell): return not AHExplorationHud._is_rescue_step(cell.step, route)),
			"semente %d: nenhuma casa do ramal vira resgate quando o preso está na rua" % seed_value)
	t.check(assigned > 0 and shifted > 0 and moved > 0, "as sementes cobrem o resgate com o desvio tomado (%d rotas, %d descidas, %d para o ramal)" % [assigned, shifted, moved])
