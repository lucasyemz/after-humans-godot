## AHJourneyRules: corredor de 10 trechos, patrulhas por nível, casas e pontos de busca, eventos, acampamento, fim de luta
## e entrega do achado. Como os testes de fluxo da Unreal (AfterHumans.Flow.Corridor, HouseLoot e Loop).
extends RefCounted

const R = preload("res://scripts/flow/journey_rules.gd")
## Portas da rua (trecho e loja), como a cena informa.
const DOOR_STEPS := [1, 2, 3, 5, 6, 8]
const DOOR_SHOPS := [0, 1, 2, 0, 1, 2]


func run(t) -> void:
	_corridor_shape(t)
	_steps(t)
	_enemies(t)
	_john_villains(t)
	_progression(t)
	_sites(t)
	_search(t)
	_events(t)
	_camp(t)
	_combat_and_return(t)
	_save_round_trip(t)


func _campaign(seed_value: int = 1) -> Dictionary:
	var campaign: Dictionary = Campaign.create_initial(seed_value)
	R.start_expedition(campaign, "fase_1", seed_value * 7919 + 13)
	R.assign_search_sites(campaign.session.expedition.corridor, DOOR_STEPS, DOOR_SHOPS)
	return campaign


func _corridor_shape(t) -> void:
	var weathers := {}
	var bad := 0
	for seed_value in 300:
		var route := R.create_corridor(seed_value * 101, "fase_1", "combat", "rua-das-vitrines")
		var types: Array = route.steps.map(func(s): return s.type)
		var ok: bool = types.size() == 10 and types[0] == "start" and types[9] == "boss" \
			and types.count("combat") == 4 and types.count("loot") == 2 and types.count("rest") == 1 and types.count("passage") == 1
		# Cada par (trechos 1-2, 3-4, 5-6, 7-8) tem uma patrulha e uma pausa.
		for pair in 4:
			ok = ok and [types[1 + pair * 2], types[2 + pair * 2]].count("combat") == 1
		bad += 0 if ok else 1
		weathers[route.weather] = true
	t.equal(bad, 0, "300 corredores: partida, 4 pares patrulha/pausa e o guardião no fim")
	t.check(weathers.size() >= 5, "o clima varia entre as fases (%d climas)" % weathers.size())
	t.equal(R.create_corridor(42, "fase_1", "combat", "rua-das-vitrines"), R.create_corridor(42, "fase_1", "combat", "rua-das-vitrines"),
		"a mesma semente dá o mesmo corredor")


func _steps(t) -> void:
	var campaign := _campaign(3)
	var route: Dictionary = campaign.session.expedition.corridor
	t.equal(campaign.session.screen, "corridor", "a expedição começa no corredor")
	t.equal(campaign.session.expedition.food, R.FREE_FOOD, "comida inicial da expedição")
	t.equal(R.enter_step(campaign, 2), "", "não pula trechos")
	t.equal(route.index, 0, "continua no trecho 0")
	var first_combat: int = route.steps.map(func(s): return s.type).find("combat")
	for index in range(1, first_combat):
		R.enter_step(campaign, index)
	t.equal(R.enter_step(campaign, first_combat), "combat", "a patrulha abre a luta")
	t.equal(R.enter_step(campaign, first_combat + 1), "", "não passa da patrulha sem vencer")
	t.equal(route.index, first_combat, "fica no trecho da patrulha")
	t.equal(R.enter_step(campaign, first_combat - 1), "", "recuar da patrulha sempre pode")
	t.equal(route.index, first_combat - 1, "recuou")
	t.equal(R.enter_step(campaign, first_combat), "combat", "a patrulha continua esperando")


func _enemies(t) -> void:
	var campaign := _campaign(5)
	var expedition: Dictionary = campaign.session.expedition
	var route: Dictionary = expedition.corridor
	var types: Array = route.steps.map(func(s): return s.type)
	var enemy_ids := {}
	for index in 10:
		if types[index] != "combat" and types[index] != "boss":
			continue
		var group := R.corridor_enemies(expedition, index)
		t.check(group.size() >= 2 and group.size() <= 4, "trecho %d: 2 a 4 inimigos (%d)" % [index, group.size()])
		for spec in group:
			enemy_ids[spec.enemy_id] = true
			t.check(spec.hp == spec.max_hp and spec.hp >= 4, "%s: vida cheia e pelo menos 4" % spec.unit_id)
			t.check(GameData.row("enemies", spec.enemy_id) != null, "%s existe" % spec.enemy_id)
		if types[index] == "boss":
			t.equal(group.size(), 4, "o guardião vem com 4")
			t.check(group[0].display_name.ends_with("Guardião"), "o primeiro é o guardião")
			var base: int = int(GameData.row("enemies", group[0].enemy_id).MaxHp)
			t.equal(group[0].max_hp, maxi(4, roundi(base * 0.51 * 1.6)), "guardião: vida do nível 1 x 1,6")
	t.equal(R.corridor_enemies(expedition, 9), R.corridor_enemies(expedition, 9), "a mesma patrulha a cada vez (salvar e voltar)")
	# Todos os inimigos das patrulhas da Rua têm arte.
	var art = JSON.parse_string(FileAccess.get_file_as_string(AHCombatArena.ART_MANIFEST))
	var missing: Array = []
	for seed_value in 60:
		var other := _campaign(100 + seed_value)
		for index in 10:
			if ["combat", "boss"].has(other.session.expedition.corridor.steps[index].type):
				for spec in R.corridor_enemies(other.session.expedition, index):
					if not art.enemies.has(spec.enemy_id) and not missing.has(spec.enemy_id):
						missing.append(spec.enemy_id)
			for site in other.session.expedition.corridor.sites.size():
				for spec in R.corridor_enemies(other.session.expedition, R.HOUSE_ENEMY_INDEX + site):
					if not art.enemies.has(spec.enemy_id) and not missing.has(spec.enemy_id):
						missing.append(spec.enemy_id)
	t.equal(missing, [], "60 fases: todo inimigo das patrulhas e das casas tem arte")


## Os vilões do John entram onde a distribuição dele manda (Lucas, 22/10/2026): Recreador e Pipoco na Rua e no
## cinema, Carrasco e Faísca na oficina e nos Túneis, Enraizado e Broto na Ponte, Broto nos Túneis. As fases 3 e 4
## continuam sem eles, e o Porteiro segue como chefe. Cada um tem arte e altura própria.
func _john_villains(t) -> void:
	var expected := {
		"fase_1": ["recreador", "pipoco"],
		"fase_2": ["enraizado", "broto"],
		"fase_5": ["carrasco_industrial", "faisca", "broto"],
	}
	var john := ["recreador", "pipoco", "enraizado", "broto", "carrasco_industrial", "faisca"]
	var seen := {}
	var by_shop := {}
	var bosses := {}
	for phase_id in ["fase_1", "fase_2", "fase_3", "fase_4", "fase_5"]:
		seen[phase_id] = {}
		for seed_value in 40:
			var campaign: Dictionary = Campaign.create_initial(seed_value + 1)
			if not R.start_expedition(campaign, phase_id, seed_value * 7919 + 13):
				continue
			var expedition: Dictionary = campaign.session.expedition
			var route: Dictionary = expedition.corridor
			for index in route.steps.size():
				if route.steps[index].type == "combat" or route.steps[index].type == "boss":
					var group := R.corridor_enemies(expedition, index)
					if route.steps[index].type == "boss" and route.node_type == "boss":
						bosses[group[0].enemy_id] = true
					for spec in group:
						seen[phase_id][spec.enemy_id] = true
			if phase_id == "fase_1":
				R.assign_search_sites(route, DOOR_STEPS, DOOR_SHOPS)
				for site in route.sites.size():
					var shop: String = R.SHOP_NAMES[route.sites[site].shop]
					for spec in R.corridor_enemies(expedition, R.HOUSE_ENEMY_INDEX + site):
						by_shop[shop + ":" + spec.enemy_id] = true
	for phase_id in expected:
		for enemy_id in expected[phase_id]:
			t.check(seen[phase_id].has(enemy_id), "%s aparece na %s" % [enemy_id, phase_id])
	for phase_id in ["fase_3", "fase_4"]:
		t.check(john.all(func(id): return not seen[phase_id].has(id)), "a %s continua sem os vilões do John" % phase_id)
	# Na casa (1 ou 2 inimigos), o mestre vem com o seu ajudante.
	for key in ["cinema:recreador", "cinema:pipoco", "oficina:carrasco_industrial", "oficina:faisca"]:
		t.check(by_shop.has(key), "%s aparece na loja" % key.replace(":", ": "))
	t.check(by_shop.keys().all(func(k): return not k.begins_with("mercearia:") or not john.has(k.split(":")[1])),
		"a mercearia fica com o Coletor de Sucata, sem vilão do John")
	t.equal(bosses.keys(), ["porteiro"], "o Porteiro continua o chefe da fase 5")
	var art = JSON.parse_string(FileAccess.get_file_as_string(AHCombatArena.ART_MANIFEST))
	for enemy_id in john:
		t.check(art.enemies.has(enemy_id) and ResourceLoader.exists(art.enemies[enemy_id].idle.file), "%s tem a pose parada" % enemy_id)
		t.check(AHCharacterHeights.HEIGHTS.has(enemy_id), "%s tem altura própria" % enemy_id)


## A fase fica mais difícil até o guardião (Lucas, 22/10/2026): a primeira patrulha pesa menos que a última, a
## patrulha forte (3 ou 4) só vem nas duas últimas antes do guardião, e o Robô volta às fases 2 e 5.
func _progression(t) -> void:
	var first_total := 0.0
	var last_total := 0.0
	var early_elites := 0
	var phases := 0
	var robot := {"fase_2": false, "fase_5": false}
	for phase_id in ["fase_1", "fase_2", "fase_3", "fase_4", "fase_5"]:
		for seed_value in 40:
			var campaign: Dictionary = Campaign.create_initial(seed_value + 1)
			if not R.start_expedition(campaign, phase_id, seed_value * 104729 + 7):
				continue
			var expedition: Dictionary = campaign.session.expedition
			var route: Dictionary = expedition.corridor
			var fights: Array = []
			for index in route.steps.size():
				if route.steps[index].type == "combat":
					fights.append(R.corridor_enemies(expedition, index))
			if fights.size() < 2:
				continue
			phases += 1
			var weight := func(group: Array) -> float:
				return group.reduce(func(sum, spec): return sum + R.enemy_strength(spec.enemy_id) * spec.max_hp / maxf(1.0, float(GameData.row("enemies", spec.enemy_id).MaxHp)), 0.0)
			first_total += weight.call(fights[0])
			last_total += weight.call(fights[-1])
			for i in fights.size() - 2:
				if fights[i].size() >= 3 and i < fights.size() - 2 and i == 0:
					early_elites += 1
			for group in fights:
				for spec in group:
					if robot.has(phase_id) and spec.enemy_id == "robot":
						robot[phase_id] = true
	t.check(phases > 150, "%d fases medidas" % phases)
	t.check(last_total > first_total * 1.5, "a última patrulha pesa mais que a primeira (%.0f contra %.0f)" % [last_total, first_total])
	t.equal(early_elites, 0, "a primeira patrulha nunca é a forte")
	t.check(robot.fase_2 and robot.fase_5, "o Robô volta às patrulhas das fases 2 e 5")


func _sites(t) -> void:
	var locked := 0
	for seed_value in 400:
		var route := R.create_corridor(seed_value * 977 + 5, "fase_1", "combat", "rua-das-vitrines")
		R.assign_search_sites(route, DOOR_STEPS, DOOR_SHOPS)
		var open: Array = route.sites.filter(func(s): return not s.locked)
		var doors: Array = route.sites.map(func(s): return s.door)
		var unique := {}
		for door in doors:
			unique[door] = true
		if open.size() != 3 or unique.size() != doors.size():
			t.check(false, "semente %d: três casas abertas em portas diferentes" % seed_value)
		if route.sites.filter(func(s): return s.camp_site).size() != 1 or route.sites.any(func(s): return s.camp_site and s.locked):
			t.check(false, "semente %d: uma casa de acampamento, nunca a trancada" % seed_value)
		for site in route.sites:
			if site.locked and (site.spots.size() != 3 or site.has_enemy):
				t.check(false, "semente %d: trancada tem a loja inteira e nenhuma patrulha" % seed_value)
		locked += 1 if route.sites.any(func(s): return s.locked) else 0
	t.check(locked > 400 * 0.28 and locked < 400 * 0.42, "casa trancada em ~35%% das fases (%d de 400)" % locked)
	t.note("casa trancada em %d de 400 fases" % locked)


func _search(t) -> void:
	# Uma casa aberta e sem patrulha, num corredor qualquer: os pontos rendem o resultado fixo da loja, uma vez.
	var campaign: Dictionary
	var site_index := -1
	for seed_value in range(20, 200):
		campaign = _campaign(seed_value)
		var sites: Array = campaign.session.expedition.corridor.sites
		for i in sites.size():
			if not sites[i].locked and not sites[i].has_enemy and not sites[i].spots.any(func(s): return s.choice):
				site_index = i
		if site_index >= 0:
			break
	var route: Dictionary = campaign.session.expedition.corridor
	var site: Dictionary = route.sites[site_index]
	t.check(not R.enter_house(campaign, site_index) or site.step <= route.index, "só entra numa casa de um trecho já alcançado")
	route.index = site.step
	t.check(R.enter_house(campaign, site_index), "entra na casa")
	var before := {"food": campaign.session.expedition.food, "seeds": campaign.session.expedition.loot.seeds,
		"scrap": campaign.session.expedition.loot.scrap, "bandages": campaign.inventory.bandages}
	var outcome = GameData.row("search_outcomes", R.FIXED_OUTCOMES[site.shop][0])
	var result := R.search_spot(campaign, site_index, 0)
	t.check(result.ok and result.text != "", "vasculhar o ponto 0 rende um texto")
	t.equal(campaign.session.expedition.food - before.food, mini(int(outcome.get("FoodDelta", 0)), R.MAX_FOOD - before.food), "comida do resultado fixo")
	t.equal(campaign.session.expedition.loot.seeds - before.seeds, int(outcome.get("SeedsDelta", 0)), "sementes do resultado fixo")
	t.check(not R.search_spot(campaign, site_index, 0).ok, "o mesmo ponto não rende de novo")
	R.leave_house(campaign)
	R.enter_house(campaign, site_index)
	t.check(not R.search_spot(campaign, site_index, 0).ok, "sair e entrar não reabre o ponto")
	R.leave_house(campaign)

	# Pé de cabra na bancada da oficina em ~50% das fases; arrombar a trancada quebra a ferramenta.
	var crowbars := 0
	var tries := 0
	for seed_value in range(300, 700):
		var c := _campaign(seed_value)
		var sites: Array = c.session.expedition.corridor.sites
		for i in sites.size():
			if sites[i].shop == 1 and not sites[i].locked and not sites[i].has_enemy and not sites[i].spots[0].choice:
				c.session.expedition.corridor.index = sites[i].step
				R.enter_house(c, i)
				tries += 1
				crowbars += 1 if R.search_spot(c, i, 0).text.contains("pé de cabra") else 0
				break
	t.check(tries > 50 and crowbars > tries * 0.35 and crowbars < tries * 0.65, "pé de cabra na bancada em ~50%% (%d de %d)" % [crowbars, tries])
	for seed_value in range(700, 900):
		var c := _campaign(seed_value)
		var sites: Array = c.session.expedition.corridor.sites
		var lock: int = sites.map(func(s): return s.locked).find(true)
		if lock < 0:
			continue
		c.session.expedition.corridor.index = sites[lock].step
		t.check(not R.can_enter_house(c, lock), "trancada não entra sem arrombar")
		t.check(not R.force_house(c, lock), "sem pé de cabra não arromba")
		R.grant_tool(c, R.CROWBAR)
		t.check(R.force_house(c, lock), "com pé de cabra arromba")
		t.check(not R.has_tool(c, R.CROWBAR), "o pé de cabra quebra")
		t.check(R.enter_house(c, lock), "arrombada, entra")
		R.leave_house(c)
		t.check(R.enter_house(c, lock), "e entra de novo sem gastar outro")
		break


func _events(t) -> void:
	for seed_value in range(1000, 1400):
		var c := _campaign(seed_value)
		var sites: Array = c.session.expedition.corridor.sites
		for i in sites.size():
			var spot: int = sites[i].spots.map(func(s): return s.choice).find(true)
			if spot < 0 or sites[i].has_enemy:
				continue
			c.session.expedition.corridor.index = sites[i].step
			R.enter_house(c, i)
			var result := R.search_spot(c, i, spot)
			t.check(result.event.begins_with("busca_"), "ponto com escolha abre um evento busca_ (%s)" % result.event)
			t.check(not R.in_corridor(c), "com o evento aberto, o corredor espera")
			var row = GameData.row("events", result.event)
			var choice = row.Choices.filter(func(o): return R.can_choose(c, o))[0]
			t.check(R.choose_event_option(c, choice.Id, 7), "escolhe uma opção disponível")
			t.check(c.session.event.resolution != "", "a escolha tem um resultado")
			t.check(R.finish_event(c), "fecha o evento")
			t.check(R.in_corridor(c), "a fase continua")
			t.check(not R.search_spot(c, i, spot).ok, "o ponto com escolha não reabre")
			return
	t.check(false, "nenhuma fase com ponto de escolha em 400 sementes")


func _camp(t) -> void:
	var c := _campaign(31)
	var route: Dictionary = c.session.expedition.corridor
	var camp: int = route.sites.map(func(s): return s.camp_site).find(true)
	route.index = route.sites[camp].step
	R.enter_house(c, camp)
	if route.sites[camp].has_enemy:
		t.check(not R.can_start_camp(c), "com patrulha na casa, não acampa")
		route.sites[camp].enemy_defeated = true
	t.check(R.start_camp(c), "acampa na casa limpa")
	var hero: Dictionary = c.roster[0]
	hero.hp = hero.max_hp - 12
	hero.instinct = 30
	var food_before: int = c.session.expedition.food
	t.check(R.camp_use_food(c, hero.id), "come no acampamento")
	t.equal([hero.hp, hero.instinct, c.session.expedition.food], [hero.max_hp - 12 + maxi(1, hero.max_hp / 10), 25, food_before - 1],
		"comer: +10% de vida, -5 de instinto, -1 comida")
	var bandages: int = c.inventory.bandages
	t.check(R.camp_use_bandage(c, hero.id), "usa um curativo")
	t.equal(c.inventory.bandages, bandages - 1, "gasta o curativo do refúgio")
	var weather: String = route.weather
	t.check(R.leave_camp(c, 9), "levanta acampamento")
	t.check(route.weather != weather, "o tempo passa (outro clima)")
	t.check(not R.can_start_camp(c), "só acampa uma vez por fase")


func _combat_and_return(t) -> void:
	var c := _campaign(41)
	var route: Dictionary = c.session.expedition.corridor
	var first: int = route.steps.map(func(s): return s.type).find("combat")
	for index in range(1, first + 1):
		R.enter_step(c, index)
	var fight := R.start_corridor_combat(c, true)
	t.check(not fight.is_empty() and fight.opening, "a luta do trecho abre com a vantagem da equipe")
	t.check(c.session.expedition.opening_used, "a vantagem de abertura fica usada")
	R.end_combat(c, "victory", false)
	t.check(route.steps[first].resolved, "vitória resolve o trecho")
	t.check(R.start_corridor_combat(c, true).is_empty(), "a patrulha vencida não volta")
	# Guardião: recompensa e fase concluída.
	for step in route.steps:
		step.resolved = step.type != "boss"
	route.index = 9
	R.end_combat(c, "victory", true)
	t.check(c.session.expedition.objective_completed and c.completed_phases.has("fase_1"), "o guardião conclui a fase")
	t.equal([c.session.expedition.loot.seeds, c.session.expedition.loot.scrap, c.session.expedition.loot.fragments], [16, 3, 1],
		"guardião (+6 sementes, +1 sucata) e fase (+10, +2, +1)")
	var seeds: int = c.inventory.seeds
	t.check(R.safe_retreat(c), "volta à Estação")
	t.equal(c.session.result, "victory", "com a fase concluída, é vitória")
	var delivered := R.finish_return(c)
	t.equal(c.inventory.seeds - seeds, 16, "vitória entrega o achado inteiro")
	t.equal(delivered.percent, 100, "vitória entrega 100%")
	t.equal(c.session.screen, "shelter", "a expedição fecha")
	# Retirada: metade. Fuga e derrota: nada.
	var r := _campaign(43)
	r.session.expedition.loot.seeds = 7
	R.safe_retreat(r)
	t.equal(R.finish_return(r).seeds, 3, "retirada entrega metade (arredonda para baixo)")
	var f := _campaign(44)
	f.session.expedition.loot.seeds = 7
	R.end_combat(f, "escaped", false)
	t.equal([f.session.result, R.finish_return(f).seeds], ["fled", 0], "fugir da luta termina a expedição sem achado")


func _save_round_trip(t) -> void:
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-journey-%d" % Time.get_ticks_usec()
	var c := _campaign(51)
	var route: Dictionary = c.session.expedition.corridor
	var site_index: int = route.sites.map(func(s): return not s.locked).find(true)
	route.index = route.sites[site_index].step
	R.enter_house(c, site_index)
	Campaign.state = c
	t.check(Campaign.save(), "salva no meio da casa")
	var saved: Dictionary = c.duplicate(true)
	Campaign.state = {}
	Campaign.load_or_new()
	t.equal(Campaign.state.session, saved.session, "a expedição volta igual (trecho, casas, casa aberta)")
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state
