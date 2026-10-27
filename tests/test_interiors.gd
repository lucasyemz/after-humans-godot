## Os interiores fechados (#175): sob teto o sol não entra (luz fraca e sem sombra, sem os raios pela frente aberta) e
## as paredes do lado das lojas têm a arte da parede do fundo, não o reboco liso.
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
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state
	Settings.level = real_level
	Settings.apply()
