## Os interiores fechados (#175): sob teto o sol não entra (luz fraca e sem sombra, sem os raios pela frente aberta),
## as paredes do lado das lojas têm a arte da parede do fundo, não o reboco liso, a porta da loja dá para um pedaço da
## rua (não para o céu) e, nas zonas cobertas, a câmera não passa da parede do lado.
extends RefCounted

## Os mapas com zona coberta: a fase, o trecho onde a rota está e as zonas cobertas.
const COVERED_MAPS := [["RiverDock", "fase_2", 0, [1, 2]], ["SealedShelter", "fase_3", 0, [0, 1, 2]],
	["FloodedDepot", "fase_5", 0, [0, 1, 2, 3]], ["SewerDucts", "fase_5", 4, [0]]]


func run(t) -> void:
	var tree: SceneTree = Engine.get_main_loop()
	for shop in AHHouseRoom.SHOP_ART.size():
		var room := AHHouseRoom.new()
		tree.root.add_child(room)
		room.build(shop, 0.0, 2, false)
		# As paredes do lado são as caixas de quina (estreitas em X, altas, na profundidade).
		var sides: Array = room.find_children("*", "MeshInstance3D", true, false).filter(func(m):
			return (m.mesh is BoxMesh and m.mesh.size.x < 0.5 and m.mesh.size.y >= AHHouseRoom.WALL_HEIGHT
				and not room.debug_colliders.has(m)))
		t.check(sides.size() >= 3, "%s: as paredes do lado (%d)" % [AHHouseRoom.SHOP_ART[shop], sides.size()])
		t.check(sides.all(func(m): return m.material_override is StandardMaterial3D and m.material_override.albedo_texture != null),
			"%s: as paredes do lado com a arte da loja" % AHHouseRoom.SHOP_ART[shop])
		# Pela porta se vê a rua: o asfalto no chão e o muro de tijolo em frente e do lado.
		var outside: Array = room.find_children("*", "MeshInstance3D", true, false).filter(func(m): return m.position.x < -0.3)
		t.equal(outside.filter(func(m): return _art(m) == "asphalt-v1.webp").size(), 1, "%s: o asfalto lá fora" % AHHouseRoom.SHOP_ART[shop])
		t.equal(outside.filter(func(m): return _art(m) == "alley-brick-v1.webp").size(), 2,
			"%s: os dois muros de tijolo lá fora" % AHHouseRoom.SHOP_ART[shop])
		room.free()
	t.check(AHHouseRoom._street_surface("asphalt-v1.webp") == AHHouseRoom._street_surface("asphalt-v1.webp")
		and AHHouseRoom._side_wall("grocery") == AHHouseRoom._side_wall("grocery"), "os materiais da loja montados uma vez só")
	await _street_sun(t, tree)


func _street_sun(t, tree: SceneTree) -> void:
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var real_level: int = Settings.level
	Settings.level = 3
	Settings.apply()
	Campaign.save_dir = "user://test-interiors-%d" % Time.get_ticks_usec()
	Campaign.state = Campaign.create_initial(6)
	AHJourneyRules.start_expedition(Campaign.state, "fase_1", 4242)
	GameFlow.change_to("street", {}, false)
	var street: Node = null
	for frame in 600:
		await tree.process_frame
		if not GameFlow.busy and tree.current_scene != null and tree.current_scene.name == "Street" and frame > 3:
			street = tree.current_scene
			break
	if t.check(street != null, "a rua abre"):
		street._mood = "golden"
		street._raining = false
		street._apply_weather()
		var open_energy: float = street._sun.light_energy
		t.check(street._sun.shadow_enabled and open_energy > 0.0, "na rua o sol tem sombra (%.2f)" % open_energy)
		street.set_indoor(true, 100.0, AHHouseRoom.WIDTH)
		t.check(not street._sun.shadow_enabled, "dentro da loja o sol não faz sombra (os raios pela frente aberta)")
		t.check(is_equal_approx(street._sun.light_energy, open_energy * street.COVERED_SUN),
			"e fica fraco (%.2f de %.2f)" % [street._sun.light_energy, open_energy])
		Settings.apply()
		t.check(not street._sun.shadow_enabled, "mudar a qualidade dentro da loja não devolve a sombra")
		street.set_indoor(false)
		t.check(street._sun.shadow_enabled and is_equal_approx(street._sun.light_energy, open_energy), "de volta à rua, o sol volta")
		# A sala aberta pelo caminho de verdade: a rua de fora da porta não encosta em nada da cena (a rua, o cenário).
		var corridor = street.corridor
		corridor._open_room(0)
		var room: AHHouseRoom = corridor.room
		var doorstep := AABB()
		for piece in room.find_children("*", "MeshInstance3D", true, false).filter(func(m): return m.position.x < -0.3):
			var piece_box: AABB = piece.global_transform * piece.mesh.get_aabb()
			doorstep = piece_box if not doorstep.has_volume() else doorstep.merge(piece_box)
		var touching: Array = street.find_children("*", "MeshInstance3D", true, false).filter(func(m):
			return m.visible and m.mesh != null and not room.is_ancestor_of(m) \
				and (m.global_transform * m.mesh.get_aabb()).intersects(doorstep)).map(func(m): return str(m.name))
		t.check(doorstep.has_volume() and touching.is_empty(), "a rua de fora da porta não encosta em outra peça %s" % [touching])
		corridor._close_room()
		tree.unload_current_scene()
		await tree.process_frame
	# Nos cenários: o Cais do Rio tem o cais ao ar livre (zona 0) e os galpões cobertos (1 e 2); o Abrigo, o Depósito e
	# os Dutos são cobertos inteiros.
	var dock_energy := -1.0
	for spec in COVERED_MAPS:
		var opened = await _open_map(tree, spec)
		if not t.check(opened != null and opened.scenario != null and opened.scenario.map_name == spec[0], "%s abre" % spec[0]):
			continue
		opened._mood = "golden"
		opened._raining = false
		if spec[0] == "RiverDock":
			opened.set_scenario_zone(0)
			dock_energy = opened._sun.light_energy
			t.check(opened._sun.shadow_enabled and dock_energy > 0.0, "no cais ao ar livre o sol tem sombra")
		for zone in spec[3]:
			_covered_zone(t, opened, spec[0], zone, dock_energy)
		tree.unload_current_scene()
		await tree.process_frame
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state
	Settings.level = real_level
	Settings.apply()


## O nome do arquivo da arte de uma peça ("" sem arte).
func _art(mesh: MeshInstance3D) -> String:
	var material := mesh.material_override as StandardMaterial3D
	return material.albedo_texture.resource_path.get_file() if material != null and material.albedo_texture != null else ""


func _open_map(tree: SceneTree, spec: Array):
	var c: Dictionary = Campaign.create_initial(7)
	c.completed_phases = ["fase_1", "fase_2", "fase_3", "fase_4"]
	AHStationRules.confirm_departure(c, c.preferred_formation.duplicate(), 0, 20261021, spec[1], "")
	var route: Dictionary = c.session.expedition.corridor
	for i in int(spec[2]):
		route.steps[i].resolved = true
	route.index = int(spec[2])
	Campaign.state = c
	GameFlow.change_to("street", {}, false)
	for frame in 600:
		await tree.process_frame
		if not GameFlow.busy and tree.current_scene != null and tree.current_scene.name == "Street" and frame > 3:
			return tree.current_scene
	return null


## Uma zona coberta: o sol fraco e sem sombra e, nas duas pontas, o líder inteiro no quadro, o quadro fechado pela
## coluna da ponta na largura e na altura, e a coluna sem atravessar peça do mapa.
func _covered_zone(t, street, map: String, zone: int, dock_energy: float) -> void:
	street.set_scenario_zone(zone)
	var name := "%s z%d" % [map, zone]
	t.check(not street._sun.shadow_enabled, "%s: o sol sem sombra" % name)
	if dock_energy > 0.0:
		t.check(is_equal_approx(street._sun.light_energy, dock_energy * street.COVERED_SUN), "%s: o sol fraco" % name)
	var caps: Array = street.scenario.find_children("ZoneEnd_%d_*" % zone, "MeshInstance3D", false, false)
	if not t.equal(caps.size(), 2, "%s: as duas colunas das pontas" % name):
		return
	var half_view: float = tan(deg_to_rad(street.SCENARIO_HALF_FOV)) * float(street.EXPLORE_CAMERA.scenario.distance)
	var size: Vector2 = street.get_viewport().get_visible_rect().size
	for end in [[street.walk_min.x, -1.0, "left"], [street.walk_max.x, 1.0, "right"]]:
		street._place_leader(Vector3(float(end[0]), street.floor_y, street.lane_z), float(end[1]))
		street._update_camera(0.0)
		var edge: float = street._camera.position.x + float(end[1]) * half_view
		t.check(absf(edge - float(end[0])) >= 0.8, "%s, ponta %s: o líder inteiro no quadro (%.2f m da borda)" % [
			name, end[2], absf(edge - float(end[0]))])
		var cap: MeshInstance3D = street.scenario.get_node("ZoneEnd_%d_%s" % [zone, end[2]])
		var box: AABB = cap.global_transform * cap.mesh.get_aabb()
		# Os dois cantos do quadro desse lado batem na frente da coluna: ela cobre a faixa além da ponta de cima a baixo.
		var screen_x: float = 0.0 if end[1] < 0.0 else size.x - 1.0
		var covered := true
		for screen_y in [0.0, size.y - 1.0]:
			var origin: Vector3 = street._camera.project_ray_origin(Vector2(screen_x, screen_y))
			var normal: Vector3 = street._camera.project_ray_normal(Vector2(screen_x, screen_y))
			var hit = Plane(Vector3.BACK, box.end.z).intersects_ray(origin, normal)
			covered = covered and hit != null and hit.x >= box.position.x and hit.x <= box.end.x \
				and hit.y >= box.position.y and hit.y <= box.end.y
		t.check(covered, "%s, ponta %s: a coluna cobre a borda do quadro em cima e embaixo" % [name, end[2]])
		var wall: float = float(street._zone.x0) if end[1] < 0.0 else float(street._zone.x1)
		var crossing := _crossing(street.scenario, box, wall)
		t.check(crossing.is_empty(), "%s, ponta %s: a coluna não atravessa peça do mapa %s" % [name, end[2], crossing])


## As peças do mapa que a coluna atravessa. Ficam de fora a parede do lado (a coluna encosta nela, com a mesma arte) e
## as peças que passam de uma zona a outra (o fundo, o forro e a moldura da frente, no mesmo plano da coluna).
func _crossing(scenario: AHScenarioWorld, box: AABB, edge: float) -> Array:
	var out := []
	for i in scenario.data.parts.size():
		var part: Dictionary = scenario.data.parts[i]
		if part.get("hidden", false):
			continue
		var b: Array = part.basis
		var transform := Transform3D(Basis(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), Vector3(b[6], b[7], b[8])),
			Vector3(part.origin[0], part.origin[1], part.origin[2]))
		var piece: AABB = transform * AHScenarioWorld._mesh_cache[int(part.mesh)].get_aabb()
		if piece.size.x > 8.0 or (piece.size.x < 0.7 and absf(piece.get_center().x - edge) < 0.8):
			continue
		if piece.intersection(box).has_volume():
			out.append(i)
	return out
