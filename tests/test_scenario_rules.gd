## Regras das jornadas nos cenários (fases 2 a 5): mapa de cada trecho, faixas dos mapas de passagem, props
## vasculháveis com o objetivo da rota, interiores laterais e os dados exportados dos seis mapas. Como os testes de
## cenário da Unreal (AfterHumans.Flow.ScenarioProps e ScenarioRooms).
extends RefCounted

const R = preload("res://scripts/flow/journey_rules.gd")
const S = preload("res://scripts/flow/station_rules.gd")
const MAPS := ["RiverDock", "RootBridge", "SealedShelter", "TriageGate", "FloodedDepot", "SewerDucts"]


func run(t) -> void:
	_maps(t)
	_props(t)
	_rooms(t)
	_data(t)


func _campaign(phase_id: String, seed_value: int = 777) -> Dictionary:
	var campaign: Dictionary = Campaign.create_initial(31)
	campaign.completed_phases = ["fase_1", "fase_2", "fase_3", "fase_4"]
	S.confirm_departure(campaign, campaign.preferred_formation.duplicate(), 0, seed_value, phase_id, "parts")
	return campaign


func _maps(t) -> void:
	t.equal(R.map_for_step("fase_1", 3), "", "fase 1 fica na Rua")
	t.equal(R.map_for_step("fase_2", 0), "RiverDock", "fase 2 começa no Cais")
	t.equal(R.map_for_step("fase_2", 3), "RiverDock", "Cais até o trecho 3")
	t.equal(R.map_for_step("fase_2", 4), "RootBridge", "Ponte do trecho 4 em diante")
	t.equal(R.map_for_step("fase_3", 9), "SealedShelter", "fase 3 inteira no Abrigo")
	t.equal(R.map_for_step("fase_4", 0), "TriageGate", "fase 4 inteira no Portão")
	t.equal(R.map_for_step("fase_5", 2), "FloodedDepot", "fase 5 passa pelo Depósito")
	t.equal(R.map_for_step("fase_5", 9), "SewerDucts", "e acaba nos Dutos (Porteiro)")
	t.equal(R.step_range("fase_2", true), [0, 4], "Cais: trechos 0-3")
	t.equal(R.step_range("fase_2", false), [4, 6], "Ponte: trechos 4-9")
	t.equal(R.step_range("fase_3", false), [0, 10], "Abrigo: os dez trechos")


func _props(t) -> void:
	var bad := 0
	for seed_value in 60:
		var campaign := _campaign("fase_3", 1000 + seed_value)
		var route: Dictionary = campaign.session.expedition.corridor
		var first := R.assign_scenario_props(campaign, "SealedShelter", [1, 2, 5, 6, 8, 8])
		var again := R.assign_scenario_props(campaign, "SealedShelter", [1, 2, 5, 6, 8, 8])
		if first != 0 or again != 0 or route.prop_steps.size() != 6:
			bad += 1
		# O objetivo cai num prop do trecho 4 em diante.
		if route.objective_prop < 0 or route.prop_steps[route.objective_prop] < 4:
			bad += 1
	t.equal(bad, 0, "props atribuídos uma vez, objetivo depois do trecho 4")

	var campaign := _campaign("fase_3")
	var route: Dictionary = campaign.session.expedition.corridor
	R.assign_scenario_props(campaign, "SealedShelter", [1, 2, 5, 6, 8, 8])
	t.check(not R.can_search_scenario_prop(campaign, 0), "prop do trecho 1 fechado no trecho 0")
	R.enter_step(campaign, 1)
	var guarded: bool = route.steps[1].type == "combat"
	t.equal(R.can_search_scenario_prop(campaign, 0), not guarded, "a patrulha de pé guarda o prop do trecho dela")
	route.steps[1].resolved = true
	t.check(R.can_search_scenario_prop(campaign, 0), "patrulha vencida: prop aberto")
	t.check(R.search_scenario_prop(campaign, 0).ok, "vasculha")
	t.check(not R.can_search_scenario_prop(campaign, 0), "não vasculha duas vezes")
	# O prop do objetivo entrega o objetivo da rota.
	var objective: int = route.objective_prop
	for step in range(1, route.prop_steps[objective] + 1):
		route.steps[step].resolved = true
		R.enter_step(campaign, step)
	var result: Dictionary = R.search_scenario_prop(campaign, objective)
	t.check(result.ok and campaign.session.expedition.get("objective_done", false), "o prop do objetivo cumpre o objetivo")

	# Mapa de passagem e mapa da fase: as listas somam e o objetivo fica no mapa da fase.
	var deep := _campaign("fase_5")
	var deep_route: Dictionary = deep.session.expedition.corridor
	var depot := R.assign_scenario_props(deep, "FloodedDepot", [1, 2, 0, 0, 1, 1, 3, 3])
	var ducts := R.assign_scenario_props(deep, "SewerDucts", [6, 7])
	t.equal([depot, ducts], [0, 8], "Depósito nos props 0-7, Dutos em 8-9")
	t.check(deep_route.objective_prop >= 8, "objetivo nos Dutos")


func _rooms(t) -> void:
	var campaign := _campaign("fase_5")
	var route: Dictionary = campaign.session.expedition.corridor
	t.check(R.can_enter_scenario_room(campaign, 0), "porta do trecho 0 aberta")
	t.check(not R.can_enter_scenario_room(campaign, 2), "porta de um trecho adiante fechada")
	t.check(R.enter_scenario_room(campaign, 1, 0), "entra no interior")
	t.equal(route.current_room, 1, "interior atual")
	t.check(not R.can_enter_scenario_room(campaign, 0), "não entra em outro de dentro de um")
	t.check(R.leave_scenario_room(campaign), "sai")
	t.check(not R.leave_scenario_room(campaign), "sair de novo não faz nada")


func _data(t) -> void:
	for map in MAPS:
		t.check(AHScenarioWorld.exists(map), "%s exportado" % map)
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/%s.json" % map))
		var zones: Array = data.get("zones", [])
		var ok := not zones.is_empty()
		for i in zones.size():
			ok = ok and zones[i].x1 > zones[i].x0 and (i == 0 or zones[i].x0 >= zones[i - 1].x1)
		t.check(ok, "%s: zonas em ordem (%d)" % [map, zones.size()])
		var doors_ok := true
		for door in data.get("side_doors", []):
			doors_ok = doors_ok and int(door.zone) > 0 and int(door.zone) < zones.size()
		t.check(doors_ok, "%s: portas laterais levam a zonas que existem" % map)
		t.check(not data.get("props", []).is_empty(), "%s: props vasculháveis" % map)
