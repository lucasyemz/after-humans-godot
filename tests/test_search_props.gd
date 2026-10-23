## Os pontos de busca da Rua das Vitrines com o objeto à vista (#50): a tabela da arte (os dois estados na mesma tela,
## a âncora no pé), um objeto fechado em cada ponto das lojas e da rua, com colisão e o losango sobre o topo, que abre
## ao vasculhar e continua aberto depois de salvar e carregar.
extends RefCounted

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_table()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-search-props-%d" % Time.get_ticks_usec()
	var tips: bool = Tips.enabled
	Tips.enabled = false
	await _street_and_house()
	Tips.enabled = tips
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state


## Cada objeto das lojas e da rua tem os dois estados na mesma tela, com a âncora no pé e o chão igual nos dois.
func _table() -> void:
	var table := AHSearchProp.table()
	var names: Array = AHSearchProp.STREET.duplicate()
	for shop in AHSearchProp.SHOPS:
		names.append_array(shop)
	t.equal(names.size(), 12, "doze objetos: três por loja e três da rua")
	var bad: Array = []
	for name in names:
		if not table.has(name):
			bad.append("%s fora da tabela" % name)
			continue
		var spec: Dictionary = table[name]
		var closed: Texture2D = load(spec.closed)
		var open: Texture2D = load(spec.open)
		if closed == null or open == null:
			bad.append("%s sem arte" % name)
			continue
		if closed.get_size() != Vector2(spec.canvas[0], spec.canvas[1]) or open.get_size() != closed.get_size():
			bad.append("%s: as telas diferem" % name)
		var anchor := Vector2(spec.anchor[0], spec.anchor[1])
		var a := closed.get_image()
		var b := open.get_image()
		# O pé encosta na âncora (há pintura logo acima dela) e a faixa do chão é a mesma nos dois estados.
		var foot := false
		for x in a.get_width():
			if a.get_pixel(x, int(anchor.y) - 2).a > 0.5:
				foot = true
		if not foot:
			bad.append("%s: o pé não está na âncora" % name)
		var differs := 0
		for y in range(int(anchor.y) - 6, int(anchor.y) - 1):
			for x in a.get_width():
				if absf(a.get_pixel(x, y).a - b.get_pixel(x, y).a) > 0.1:
					differs += 1
		if differs > 20:
			bad.append("%s: o pé muda entre os estados (%d px)" % [name, differs])
		if float(spec.height_m) <= 0.3 or float(spec.body_reference_pixels) <= 0.0 or float(spec.body_reference_pixels) > anchor.y:
			bad.append("%s: altura inválida" % name)
	t.check(bad.is_empty(), "a arte de cada objeto segue o contrato: %s" % [bad])


func _street_and_house() -> void:
	Campaign.state = Campaign.create_initial(5)
	AHJourneyRules.start_expedition(Campaign.state, "fase_1", 5050)
	var street = await _open_street()
	if street == null:
		return
	var route: Dictionary = Campaign.state.session.expedition.corridor
	var corridor = street.corridor
	# A rua: um objeto fechado em cada trecho de busca, com colisão e o losango logo acima do topo.
	var loot: Array = []
	for index in route.steps.size():
		if route.steps[index].type == "loot":
			loot.append(index)
	t.check(not loot.is_empty() and loot.all(func(i): return corridor.props.has(i) and corridor.props[i] is AHSearchProp),
		"cada trecho de busca da rua tem o objeto (%d)" % loot.size())
	if loot.is_empty():
		return
	var kinds := {}
	for index in loot:
		kinds[corridor.props[index].prop_name] = true
	t.check(kinds.size() == mini(3, loot.size()) and kinds.keys().all(func(k): return AHSearchProp.STREET.has(k)),
		"a rua alterna os objetos dela: %s" % [kinds.keys()])
	var first: int = loot[0]
	var prop: AHSearchProp = corridor.props[first]
	t.check(not prop.opened, "antes de vasculhar, fechado")
	_marker_on_top(prop, "na rua")
	t.check(_collider_at(street, prop.global_position + Vector3(0, 0.3, 0)), "o objeto da rua tem colisão")
	# A caixa entra na lista da tecla C e do _free_spot (QA da #50), e nenhum objeto fica na frente da porta de uma loja.
	t.check(loot.all(func(i): return street._blocked(corridor.props[i].volume().get_center())), "o _free_spot vê a colisão dos objetos da rua")
	var near_door: Array = []
	for i in loot:
		for door in corridor.doors:
			if absf(float(door.x) - corridor.props[i].position.x) < corridor.PROP_DOOR_CLEARANCE - 0.01:
				near_door.append(i)
	t.check(near_door.is_empty(), "nenhum objeto da rua na frente de uma porta %s" % [near_door])
	for i in first:
		route.steps[i].resolved = true
	route.index = first
	corridor._search_prop(first)
	t.check(route.props.get(str(first), false) and prop.opened, "vasculhado, abre")
	# A loja: o objeto de cada ponto, na loja de cada tipo.
	if not t.check(not route.sites.is_empty(), "a rua tem lojas"):
		return
	var site_index := 0
	var site: Dictionary = route.sites[site_index]
	site.locked = false
	site.has_enemy = false
	route.index = maxi(route.index, int(site.step))
	for shop in 3:
		site.shop = shop
		corridor._open_room(site_index)
		var room = corridor.room
		t.equal(room.search_props.size(), mini(site.spots.size(), 3), "a loja %d tem um objeto por ponto" % shop)
		for i in room.search_props.size():
			var spot: AHSearchProp = room.search_props[i]
			t.equal(spot.prop_name, AHSearchProp.SHOPS[shop][i], "o ponto %d da loja %d é %s" % [i, shop, AHSearchProp.SHOPS[shop][i]])
			t.check(absf(spot.global_position.x - room.spot_xs[i]) < 0.01 and not spot.opened, "no lugar do ponto, fechado")
		if not room.search_props.is_empty():
			_marker_on_top(room.search_props[0], "na loja %d" % shop)
		# Sem caminho por trás: entre o objeto e a parede do fundo a equipe não passa (QA da #50).
		await _tree.physics_frame
		t.check(room.search_props.all(func(p): return street._blocked(Vector3(p.global_position.x, 0, p.volume().position.z - 0.35))),
			"na loja %d, ninguém passa por trás dos objetos" % shop)
		corridor._close_room()
		await _tree.process_frame
	site.shop = 0
	if not t.check(AHJourneyRules.enter_house(Campaign.state, site_index), "a equipe entra na loja"):
		return
	corridor._open_room(site_index)
	corridor._search_spot(site_index, 0)
	t.check(site.spots[0].searched and corridor.room.search_props[0].opened, "vasculhado na loja, abre")
	t.check(not corridor.room.search_props[1].opened, "o vizinho continua fechado")
	# Salvar e carregar: a rua e a loja voltam com os vasculhados abertos.
	Campaign.save()
	Campaign.state = {}
	Campaign.load_or_new()
	street = await _open_street()
	if street == null:
		return
	t.check(street.corridor.props[first].opened, "depois de carregar, o da rua continua aberto")
	t.check(not street.corridor.props[loot[-1]].opened or loot.size() == 1, "e os outros, fechados")
	var room = street.corridor.room
	if room == null:
		street.corridor._open_room(Campaign.state.session.expedition.corridor.current_house)
		room = street.corridor.room
	t.check(room != null and room.search_props[0].opened and not room.search_props[1].opened, "e o da loja também")


func _open_street():
	GameFlow.change_to("street", {}, false)
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			return _tree.current_scene
	t.check(false, "a rua abre")
	return null


## O losango fica sobre o centro do topo fechado (um pouco acima), não solto no ar.
func _marker_on_top(prop: AHSearchProp, where: String) -> void:
	var point := prop.marker_point()
	var top := prop.global_position.y + float(prop.spec.height_m)
	t.check(absf(point.x - prop.global_position.x) < 0.01 and point.y > top and point.y < top + 0.25,
		"o losango %s fica logo acima do topo (%.2f m sobre %.2f m)" % [where, point.y, top])


func _collider_at(street: Node, point: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = point
	return not street.get_world_3d().direct_space_state.intersect_point(query).is_empty()

