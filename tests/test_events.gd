## Eventos de exploração (#7): cada evento combina com o lugar e com o objeto vasculhado (Places e Objects em
## data/events.json); nos cenários, um objeto com escolha abre o evento na interação; reentrar, salvar e carregar não
## repetem a busca nem a consequência; a opção indisponível diz por quê; deixar para lá não custa nada.
extends RefCounted

const R = preload("res://scripts/flow/journey_rules.gd")
## Os props da Sala Esquecida, como a cena informa.
const NAMES := ["Objeto", "Objeto", "Fichário", "Objeto", "Objeto", "Caixote de baterias"]
const PLACES := ["rua-das-vitrines", "ponte-das-raizes", "sala-esquecida", "laboratorio-silencioso", "tuneis-do-eco"]


func run(t) -> void:
	_pools(t)
	_house_choice(t)
	_scenario_choice(t)
	_requirements(t)
	_event_art(t)
	_changes(t)
	await _scene(t)


const KINDS := ["movel", "armario", "maquina", "bolsa", "carga", "medico"]
const MAP_PLACES := {"RiverDock": "ponte-das-raizes", "RootBridge": "ponte-das-raizes", "SealedShelter": "sala-esquecida",
	"TriageGate": "laboratorio-silencioso", "FloodedDepot": "tuneis-do-eco", "SewerDucts": "tuneis-do-eco"}


func _pools(t) -> void:
	for place in PLACES:
		var all := {}
		for kind in KINDS:
			for id in R.event_pool(place, kind):
				all[id] = true
		t.check(all.size() >= 2, "%s tem pelo menos dois eventos (%s)" % [place, all.keys()])
	t.equal(R.event_pool("rua-das-vitrines", ""), [], "objeto sem tipo (a escada, \"Objeto\") não abre evento")
	t.check(not R.event_pool("rua-das-vitrines", "medico").has("busca_sala_esporos"), "a enfermaria de esporos não aparece na rua")
	t.check(not R.event_pool("sala-esquecida", "maquina").has("busca_cano_rompido"), "o cano sob o asfalto só na rua")
	t.check(R.event_pool("rua-das-vitrines", "movel").has("busca_caixa_sanitaria"), "a caixa no fundo do móvel sai de um móvel")
	t.check(not R.event_pool("rua-das-vitrines", "bolsa").has("busca_caixa_sanitaria"), "e não de uma mochila")
	for pair in [["Armário de vestiário", "armario"], ["Armário de ferramentas", "armario"], ["Mochila de explorador", "bolsa"],
			["Caixa de fusíveis", "maquina"], ["Caixa amarrada", "carga"], ["Caixa de mantimentos", "carga"], ["o caixa", "movel"],
			["Kit de primeiros socorros", "medico"], ["a escada", ""], ["Objeto", ""]]:
		t.equal(R.object_kind(pair[0]), pair[1], "%s: tipo %s" % [pair[0], pair[1]])
	for id in GameData.table("events"):
		if String(id).begins_with("busca_"):
			var row: Dictionary = GameData.row("events", id)
			for place in row.get("Places", []):
				t.check(PLACES.has(place), "%s: lugar conhecido (%s)" % [id, place])
			t.check(not row.get("Objects", []).is_empty(), "%s: diz em que objetos cabe" % id)
			for kind in row.get("Objects", []):
				t.check(KINDS.has(kind), "%s: tipo de objeto conhecido (%s)" % [id, kind])
			t.check(row.Choices.size() >= 2, "%s: pelo menos duas escolhas" % id)
	_all_objects(t)


## Todo objeto vasculhável do jogo (os props dos cenários e os pontos das casas da rua): o que ele pode abrir combina
## com o lugar e com o tipo dele; objeto sem evento possível nunca vira objeto com escolha.
func _all_objects(t) -> void:
	var pairs := 0
	var objects: Array = []
	for map in MAP_PLACES:
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/%s.json" % map))
		for prop in data.props:
			objects.append([MAP_PLACES[map], String(prop.name)])
	for shop in R.SPOT_NAMES:
		for name in shop:
			objects.append(["rua-das-vitrines", name])
	for entry in objects:
		var kind := R.object_kind(entry[1])
		for id in R.event_pool(entry[0], kind):
			var row: Dictionary = GameData.row("events", id)
			var places: Array = row.get("Places", [])
			t.check((places.is_empty() or places.has(entry[0])) and row.Objects.has(kind), "%s (%s) → %s combina" % [entry[1], entry[0], id])
			pairs += 1
	t.check(pairs > 20, "pares objeto → evento conferidos (%d)" % pairs)
	# Um mapa só com "Objeto" e um caixote: o objeto com escolha cai sempre no caixote (o que tem evento).
	for seed_value in 30:
		var c: Dictionary = Campaign.create_initial(6)
		R.start_expedition(c, "fase_3", 9000 + seed_value)
		R.assign_scenario_props(c, "SealedShelter", [1, 2, 5], ["Objeto", "Objeto", "Caixote de baterias"])
		var route: Dictionary = c.session.expedition.corridor
		t.check(route.choice_props.is_empty() or route.choice_props == [2], "o objeto com escolha nunca é um \"Objeto\" sem evento")


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
		for choice in row.Choices:
			if choice.get("Requirement", "") == "" and choice.get("Success", {}).keys() == ["Result"]:
				leave = choice
		var before := JSON.stringify(back.session.expedition.loot) + str(back.session.expedition.food) + str(back.inventory)
		t.check(R.choose_event_option(back, leave.Id, 7), "deixar para lá")
		t.check(not R.choose_event_option(back, row.Choices[0].Id, 7), "a escolha vale uma vez")
		t.check(R.finish_event(back) and not R.finish_event(back), "o evento fecha uma vez")
		if leave.get("Success", {}).keys() == ["Result"]:
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
		R.assign_scenario_props(c, "SealedShelter", [1, 2, 5, 6, 8, 8], NAMES)
		if route.choice_props.is_empty():
			continue
		with_choice += 1
		var prop: int = route.choice_props[0]
		t.equal(route.choice_props.size(), 1, "um objeto com escolha por mapa")
		for step in route.prop_steps[prop] + 1:
			route.steps[step].resolved = true
		route.index = route.prop_steps[prop]
		var result: Dictionary = R.search_scenario_prop(c, prop, NAMES[prop])
		if prop == route.objective_prop:
			continue
		t.check(result.ok and result.event != "", "o objeto com escolha abre um evento")
		t.check(R.event_pool("sala-esquecida", R.object_kind(NAMES[prop])).has(result.event), "o evento é da Sala Esquecida e do objeto (%s → %s)" % [NAMES[prop], result.event])
		t.equal(c.session.event.get("object", ""), NAMES[prop], "o evento guarda o objeto vasculhado")
		opened[result.event] = true
		t.check(not R.can_search_scenario_prop(c, prop), "e não abre de novo")
		# Voltar ao mesmo mapa (reentrar) mantém o objeto e a busca feita.
		R.assign_scenario_props(c, "SealedShelter", [1, 2, 5, 6, 8, 8], NAMES)
		t.check(route.choice_props.has(prop) and route.searched_props.has(prop), "reentrar no mapa não sorteia de novo")
	t.check(with_choice > 10 and with_choice < 50, "cerca de metade dos mapas tem objeto com escolha (%d de 60)" % with_choice)
	t.check(opened.size() >= 2, "eventos variados na Sala Esquecida (%s)" % str(opened.keys()))


## A opção indisponível diz por quê (RequirementText) e não pode ser escolhida.
func _requirements(t) -> void:
	_texts(t)
	_hero_name(t)
	_requirements_only(t)


## As descrições dos eventos ligados a objeto não falam de outro lugar (asfalto, galho) nem começam como se o objeto
## fosse outra coisa: as de lugar começam por onde está, ao lado ou atrás do objeto.
func _texts(t) -> void:
	for id in ["busca_cano_rompido", "busca_poco_escuro", "busca_sala_esporos"]:
		var text: String = GameData.row("events", id).Description
		t.check(not text.contains("asfalto"), "%s: sem asfalto dentro de casa" % id)
		t.check(text.begins_with("Atrás") or text.begins_with("Ao lado") or text.begins_with("O kit"), "%s: começa pelo objeto vasculhado" % id)


## O texto com {Heroi} sempre ganha um nome, com ou sem dano.
func _hero_name(t) -> void:
	for seed_value in 20:
		var c: Dictionary = Campaign.create_initial(8)
		R.start_expedition(c, "fase_5", 300 + seed_value)
		c.session.event = {"event_id": "busca_sala_esporos", "from_search": true, "resolution": "", "pending_hard_combat": false}
		R.choose_event_option(c, "prender_folego", seed_value)
		t.check(not c.session.event.resolution.contains("{Heroi}") and not c.session.event.resolution.contains("  "),
			"o herói tem nome no texto (%s)" % c.session.event.resolution.left(60))


func _requirements_only(t) -> void:
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
		var says: bool = street.exploration_hud._modal.find_children("*", "Label", true, false).any(func(l): return l.text == "Ao vasculhar: %s" % entry.name)
		t.check(says, "o painel diz o que foi vasculhado (%s)" % entry.name)
		# A barra das teclas do evento aberto: sem o Fechar (o evento pede uma escolha).
		await tree.process_frame
		t.equal(street.exploration_hud._panel_keys_kind, "choose", "no evento, a barra não promete Fechar")
		# Resolvido: o que mudou em chips; um evento de um save antigo (sem a lista) mostra só o texto.
		var event: Dictionary = Campaign.state.session.event
		var choice: Dictionary = GameData.row("events", event.event_id).Choices.filter(func(o): return R.can_choose(Campaign.state, o))[0]
		R.choose_event_option(Campaign.state, choice.Id, 5)
		street.exploration_hud.show_event(Campaign.state)
		await tree.process_frame
		var chips: Node = street.exploration_hud._modal.find_child("Changes", true, false)
		t.equal(chips.get_child_count() if chips else 0, event.changes.size(), "um chip por mudança (%s)" % [event.changes])
		t.check(street.exploration_hud._modal.find_child("Continue", true, false) != null, "e o CONTINUAR")
		await tree.process_frame
		t.equal(street.exploration_hud._panel_keys_kind, "continue", "no resultado, a barra só tem Interagir Continuar")
		# A Mochila: a barra fecha pela tecla do Menu, e segue a troca nas Opções.
		street.exploration_hud.show_inventory()
		Settings.set_key("menu", KEY_P)
		await tree.process_frame
		var keys: Control = street.exploration_hud._panel_keys
		var says_p: bool = keys.find_children("*", "Label", true, false).any(func(l): return l.text == "P")
		t.check(street.exploration_hud._panel_keys_kind == "menu" and says_p, "na Mochila, a barra diz Fechar na tecla do Menu (trocada para P)")
		Settings.reset_keys()
		street.exploration_hud.show_event(Campaign.state)
		await tree.process_frame
		event.erase("changes")
		street.exploration_hud.show_event(Campaign.state)
		await tree.process_frame
		t.check(street.exploration_hud._modal.find_child("Changes", true, false) == null and street.exploration_hud._modal.find_child("Continue", true, false) != null,
			"o evento salvo antes da lista abre sem os chips")
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


## O que mudou no resultado (#106, os chips): em todos os eventos e escolhas, com sucesso e falha (as sementes), a
## lista event.changes é a diferença de fato no estado (os limites contam: a comida não passa de 8, a Esperança de 100,
## a vida não cai abaixo de 1).
func _changes(t) -> void:
	var checked := 0
	var wrong: Array = []
	for event_id in GameData.table("events"):
		var row = GameData.row("events", event_id)
		for choice in row.get("Choices", []):
			for seed_value in [11, 12, 13, 14]:
				var c: Dictionary = Campaign.create_initial(4)
				R.start_expedition(c, "fase_1", 90)
				c.session.expedition.hope = 97
				c.session.expedition.food = 7
				c.session.event = {"event_id": event_id, "from_search": true, "resolution": "", "pending_hard_combat": false, "object": ""}
				if not R.can_choose(c, choice):
					continue
				var before := _snapshot(c)
				if not R.choose_event_option(c, choice.Id, seed_value):
					continue
				var after := _snapshot(c)
				var said := {}
				for change in c.session.event.get("changes", []):
					said[change.kind] = int(said.get(change.kind, 0)) + int(change.amount)
				for kind in after:
					var moved: int = after[kind] - before[kind]
					if int(said.get(kind, 0)) != moved:
						wrong.append("%s/%s (semente %d): %s mudou %d, a lista diz %d" % [event_id, choice.Id, seed_value, kind, moved, int(said.get(kind, 0))])
				checked += 1
	t.check(checked > 40, "as escolhas dos eventos conferidas (%d)" % checked)
	t.equal(wrong.slice(0, 5), [], "a lista do que mudou é a diferença de fato no estado")


func _snapshot(c: Dictionary) -> Dictionary:
	var e: Dictionary = c.session.expedition
	var life := 0
	var instinct := 0
	for hero_id in e.team:
		life += _hp(c, hero_id)
		for hero in c.roster:
			if hero.id == hero_id:
				instinct += int(hero.instinct)
	return {"hope": e.hope, "food": e.food, "bandages": c.inventory.bandages, "scrap": e.loot.scrap, "fragments": e.loot.fragments,
		"seeds": e.loot.seeds, "life": life, "instinct": instinct}


func _hp(c: Dictionary, hero_id: String) -> int:
	for hero in c.roster:
		if hero.id == hero_id:
			return int(hero.hp)
	return 0


## A ilustração do cenário no topo do cartão de evento (#31, a entrega #22): uma por mapa, e a da rua sem cenário.
func _event_art(t) -> void:
	var hud := AHExplorationHud.new()
	var seen := {}
	for map_id in ["", "RiverDock", "RootBridge", "SealedShelter", "TriageGate", "FloodedDepot", "SewerDucts"]:
		hud.map_id = map_id
		var art := hud.event_art()
		t.check(art != null and art.get_width() == 1200 and art.get_height() == 500, "o mapa %s tem a ilustração 1200x500" % (map_id if map_id != "" else "da rua"))
		if art != null:
			seen[art.resource_path] = true
	t.equal(seen.size(), 7, "cada mapa com a sua ilustração")
	hud.map_id = "MapaQueNaoExiste"
	t.check(hud.event_art() != null and hud.event_art().resource_path.ends_with("street.webp"), "mapa sem ilustração usa a da rua")
	hud.free()
