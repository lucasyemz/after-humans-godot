## Os interiores fechados (#175): sob teto o sol não entra (luz fraca e sem sombra, sem os raios pela frente aberta),
## as paredes do lado das lojas têm a arte da parede do fundo, não o reboco liso, a porta da loja dá para um pedaço da
## rua (não para o céu) e, nas zonas cobertas, a câmera não passa da parede do lado.
extends RefCounted


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
		# Pela porta se vê a rua: o asfalto e o muro de tijolo lá fora.
		var outside: Array = room.find_children("*", "MeshInstance3D", true, false).filter(func(m):
			return m.position.x < -0.3 and m.material_override is StandardMaterial3D and m.material_override.albedo_texture != null)
		t.check(outside.size() >= 3, "%s: a rua do lado de fora da porta (%d peças)" % [AHHouseRoom.SHOP_ART[shop], outside.size()])
		room.free()
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
		tree.unload_current_scene()
		await tree.process_frame
	# Num cenário: o Cais do Rio tem o cais ao ar livre (zona 0) e os galpões cobertos (1 e 2).
	var c: Dictionary = Campaign.create_initial(7)
	c.completed_phases = ["fase_1"]
	AHStationRules.confirm_departure(c, c.preferred_formation.duplicate(), 0, 20261021, "fase_2", "")
	Campaign.state = c
	GameFlow.change_to("street", {}, false)
	street = null
	for frame in 600:
		await tree.process_frame
		if not GameFlow.busy and tree.current_scene != null and tree.current_scene.name == "Street" and frame > 3:
			street = tree.current_scene
			break
	if t.check(street != null and street.scenario != null and street.scenario.map_name == "RiverDock", "o Cais do Rio abre"):
		street._mood = "golden"
		street._raining = false
		street.set_scenario_zone(0)
		var dock_energy: float = street._sun.light_energy
		t.check(street._sun.shadow_enabled and dock_energy > 0.0, "no cais ao ar livre o sol tem sombra")
		var half_view: float = tan(deg_to_rad(street.SCENARIO_HALF_FOV)) * float(street.EXPLORE_CAMERA.scenario.distance)
		for zone in [1, 2]:
			street.set_scenario_zone(zone)
			t.check(not street._sun.shadow_enabled and is_equal_approx(street._sun.light_energy, dock_energy * street.COVERED_SUN),
				"no galpão %d o sol fica fraco e sem sombra" % zone)
			# Nas pontas do galpão: o líder longe da borda do quadro, e o quadro só até as colunas que fecham a ponta.
			for end in [[street.walk_min.x, -1.0], [street.walk_max.x, 1.0]]:
				street._place_leader(Vector3(float(end[0]), street.floor_y, street.lane_z), float(end[1]))
				street._update_camera(0.0)
				var edge: float = street._camera.position.x + float(end[1]) * half_view
				var wall: float = float(street._zone.x0) if end[1] < 0.0 else float(street._zone.x1)
				t.check(absf(edge - float(end[0])) >= 0.8, "no galpão %d o líder na ponta fica inteiro no quadro (%.2f m da borda)" % [
					zone, absf(edge - float(end[0]))])
				t.check(absf(edge - wall) <= AHScenarioWorld.END_CAP_WIDTH, "e o quadro para nas colunas da ponta (%.2f m além)" % absf(edge - wall))
			t.equal(street.scenario.find_children("ZoneEnd_%d_*" % zone, "MeshInstance3D", false, false).size(), 2,
				"o galpão %d com as duas colunas das pontas" % zone)
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
