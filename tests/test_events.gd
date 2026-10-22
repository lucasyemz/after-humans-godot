## Eventos de exploração (#7): cada evento combina com o lugar e com o objeto vasculhado (Places e Objects em
## data/events.json); nos cenários, um objeto com escolha abre o evento na interação; reentrar, salvar e carregar não
## repetem a busca nem a consequência; a opção indisponível diz por quê; deixar para lá não custa nada.
extends RefCounted

const R = preload("res://scripts/flow/journey_rules.gd")
const PLACES := ["rua-das-vitrines", "ponte-das-raizes", "sala-esquecida", "laboratorio-silencioso", "tuneis-do-eco"]


func run(t) -> void:
	_pools(t)
	_house_choice(t)
	_scenario_choice(t)
	_requirements(t)
	await _scene(t)


func _pools(t) -> void:
	for place in PLACES:
		t.check(R.event_pool(place, "").size() >= 2, "%s tem pelo menos dois eventos (%s)" % [place, R.event_pool(place, "")])
	t.check(not R.event_pool("rua-das-vitrines", "").has("busca_sala_esporos"), "a enfermaria de esporos não aparece na rua")
	t.check(not R.event_pool("sala-esquecida", "").has("busca_cano_rompido"), "o cano sob o asfalto só na rua")
	t.check(R.event_pool("rua-das-vitrines", "movel").has("busca_caixa_sanitaria"), "a caixa no fundo do móvel sai de um móvel")
	t.check(not R.event_pool("rua-das-vitrines", "bolsa").has("busca_caixa_sanitaria"), "e não de uma mochila")
	t.equal(R.object_kind("Armário de vestiário"), "movel", "armário é móvel")
	t.equal(R.object_kind("Mochila de explorador"), "bolsa", "mochila é bolsa")
	t.equal(R.object_kind("a escada"), "", "a escada não é móvel")
	for id in GameData.table("events"):
		if String(id).begins_with("busca_"):
			var row: Dictionary = GameData.row("events", id)
			for place in row.get("Places", []):
				t.check(PLACES.has(place), "%s: lugar conhecido (%s)" % [id, place])
			t.check(row.Choices.size() >= 2, "%s: pelo menos duas escolhas" % id)


## O ponto com escolha de uma casa da rua: o evento é da rua, salvar e carregar no meio não sorteia de novo, a escolha
## vale uma vez e o ponto não abre outra vez.
func _house_choice(t) -> void:
	for seed_value in 40:
		var c: Dictionary = Campaign.create_initial(3)
		R.start_expedition(c, "fase_1", 5000 + seed_value)
		var route: Dictionary = c.session.expedition.corridor
		R.assign_search_sites(route, [1, 2, 3, 5, 6, 8], [0, 1, 2, 0, 1, 2])
		var found := [-1, -1]
		for i in route.sites.size():
			for j in route.sites[i].spots.size():
				if route.sites[i].spots[j].choice:
					found = [i, j]
		if found[0] < 0:
			continue
		var site: Dictionary = route.sites[found[0]]
		for step in site.step + 1:
			route.steps[step].resolved = true
		route.index = site.step
		site.has_enemy = false
		site.locked = false
		R.enter_house(c, found[0])
		var result: Dictionary = R.search_spot(c, found[0], found[1])
		t.check(result.ok and result.event != "", "o ponto com escolha abre um evento")
		t.check(R.event_pool("rua-das-vitrines", R.object_kind(R.SPOT_NAMES[site.shop][found[1]])).has(result.event), "o evento é da rua e do objeto (%s)" % result.event)
		# Salvar e carregar no meio do evento: o mesmo evento, sem resolver, sem busca nova.
		var back: Dictionary = Campaign._normalize(JSON.parse_string(JSON.stringify(c)))
		t.equal(back.session.event.event_id, result.event, "carregar no meio: o mesmo evento")
		t.equal(back.session.event.resolution, "", "carregar no meio: ainda sem escolha")
		t.check(not R.search_spot(back, found[0], found[1]).ok, "o ponto não abre de novo depois de carregar")
		var row: Dictionary = GameData.row("events", result.event)
		var leave: Dictionary = row.Choices[-1]
		var before := JSON.stringify(back.session.expedition.loot) + str(back.session.expedition.food) + str(back.inventory)
		t.check(R.choose_event_option(back, leave.Id, 7), "deixar para lá")
		t.check(not R.choose_event_option(back, row.Choices[0].Id, 7), "a escolha vale uma vez")
		t.check(R.finish_event(back) and not R.finish_event(back), "o evento fecha uma vez")
		if not leave.get("Success", {}).has("FoodDelta") and not leave.get("Success", {}).has("BandagesDelta"):
			t.equal(JSON.stringify(back.session.expedition.loot) + str(back.session.expedition.food) + str(back.inventory), before, "deixar para lá não custa nada")
		t.check(not R.search_spot(back, found[0], found[1]).ok, "nem depois do evento")
		return
	t.check(false, "nenhuma das 40 sementes teve um ponto com escolha")


## Nos cenários: metade dos mapas tem um objeto com escolha; vasculhá-lo abre um evento daquele lugar.
func _scenario_choice(t) -> void:
	var opened := {}
	var with_choice := 0
	for seed_value in 60:
		var c: Dictionary = Campaign.create_initial(4)
		R.start_expedition(c, "fase_3", 7000 + seed_value)
		var route: Dictionary = c.session.expedition.corridor
		R.assign_scenario_props(c, "SealedShelter", [1, 2, 5, 6, 8, 8])
		if route.choice_props.is_empty():
			continue
		with_choice += 1
		var prop: int = route.choice_props[0]
		t.equal(route.choice_props.size(), 1, "um objeto com escolha por mapa")
		for step in route.prop_steps[prop] + 1:
			route.steps[step].resolved = true
		route.index = route.prop_steps[prop]
		var result: Dictionary = R.search_scenario_prop(c, prop, "Fichário")
		if prop == route.objective_prop:
			continue
		t.check(result.ok and result.event != "", "o objeto com escolha abre um evento")
		t.check(R.event_pool("sala-esquecida", "movel").has(result.event), "o evento é da Sala Esquecida (%s)" % result.event)
		opened[result.event] = true
		t.check(not R.can_search_scenario_prop(c, prop), "e não abre de novo")
		# Voltar ao mesmo mapa (reentrar) mantém o objeto e a busca feita.
		R.assign_scenario_props(c, "SealedShelter", [1, 2, 5, 6, 8, 8])
		t.check(route.choice_props.has(prop) and route.searched_props.has(prop), "reentrar no mapa não sorteia de novo")
	t.check(with_choice > 10 and with_choice < 50, "cerca de metade dos mapas tem objeto com escolha (%d de 60)" % with_choice)
	t.check(opened.size() >= 2, "eventos variados na Sala Esquecida (%s)" % opened.keys())


## A opção indisponível diz por quê (RequirementText) e não pode ser escolhida.
func _requirements(t) -> void:
	var c: Dictionary = Campaign.create_initial(5)
	R.start_expedition(c, "fase_1", 99)
	c.session.event = {"event_id": "busca_choro_porta", "from_search": true, "resolution": "", "pending_hard_combat": false}
	var row: Dictionary = GameData.row("events", "busca_choro_porta")
	for choice in row.Choices:
		if choice.get("Requirement", "") == "HasTool":
			t.check(not R.can_choose(c, choice), "sem pé de cabra, %s fica indisponível" % choice.Id)
			t.check(String(choice.get("RequirementText", "")) != "", "e diz por quê")
			t.check(not R.choose_event_option(c, choice.Id, 3), "e não pode ser escolhida")


## Na cena: na Sala Esquecida, vasculhar o objeto com escolha abre o painel do evento ali mesmo.
func _scene(t) -> void:
	var tree: SceneTree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-events-%d" % Time.get_ticks_usec()
	var opened := false
	for seed_value in range(7000, 7060):
		Campaign.state = Campaign.create_initial(4)
		R.start_expedition(Campaign.state, "fase_3", seed_value)
		GameFlow.change_to("street", {}, false)
		var street = null
		for frame in 600:
			await tree.process_frame
			if not GameFlow.busy and tree.current_scene != null and tree.current_scene.get("corridor") != null:
				street = tree.current_scene
				break
		if street == null:
			break
		var route: Dictionary = Campaign.state.session.expedition.corridor
		var corridor: AHStreetCorridor = street.corridor
		var entries: Array = corridor.scenario_props.filter(func(e): return route.choice_props.has(e.prop) and e.prop != route.objective_prop)
		if entries.is_empty():
			continue
		var entry: Dictionary = entries[0]
		for step in route.prop_steps[entry.prop] + 1:
			route.steps[step].resolved = true
		route.index = route.prop_steps[entry.prop]
		corridor._search_scenario_prop(entry)
		await tree.process_frame
		t.check(Campaign.state.session.event != null, "o objeto com escolha (%s) abre o evento" % entry.name)
		t.check(street.exploration_hud.modal_open(), "e o painel do evento aparece na hora")
		opened = true
		break
	t.check(opened, "achou um mapa da Sala Esquecida com objeto com escolha")
	if tree.current_scene != null:
		tree.unload_current_scene()
	await tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state
