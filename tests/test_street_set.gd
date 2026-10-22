## A rua como cena (#8): scenes/street_set.tscn existe, a rua abre dela (não monta em código) e acha o que mexe depois
## (luzes, feixes, chão molhado, caixas da tecla C). Mexer num poste na cena (como no editor) aparece no jogo.
extends RefCounted


func run(t) -> void:
	t.check(ResourceLoader.exists(AHStreetSet.SCENE), "a cena da rua existe (%s)" % AHStreetSet.SCENE)
	var packed: PackedScene = load(AHStreetSet.SCENE)
	var baked: Node = packed.instantiate()
	t.check(baked is AHStreetSet, "a raiz da cena é a montagem da rua")
	for name in ["Ground", "Lamp1", "Lamp2", "Lamp3", "Building1", "Car1", "Skyline"]:
		t.check(baked.has_node(name), "a cena tem o nó %s" % name)
	baked.free()
	var tree: SceneTree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-street-set-%d" % Time.get_ticks_usec()
	var street = await _open(tree)
	if t.check(street != null, "a rua abriu"):
		t.equal(street._set.scene_file_path, AHStreetSet.SCENE, "a rua vem da cena gravada")
		t.equal(street._lamp_lights.size(), 3, "acha as luzes dos três postes")
		t.equal(street._door_lights.size(), 3, "e as três luzes de porta")
		t.check(street._shafts.size() >= 6, "acha os feixes de sol dos becos (%d)" % street._shafts.size())
		t.check(street._skyline_materials.size() >= 10, "acha as silhuetas do fundo (%d)" % street._skyline_materials.size())
		t.check(street._piece_materials.has("asphalt") and street._piece_materials.has("sidewalk"), "acha o chão que molha")
		t.check(street._piece_materials.asphalt.get_meta("puddles", null) is NoiseTexture2D, "com as poças")
		t.check(street._debug_colliders.size() > 50, "acha as caixas de colisão da tecla C (%d)" % street._debug_colliders.size())
		var lamp_x: float = street._set.get_node("Lamp1").global_position.x
		# Mexer no poste como no editor: muda a cena gravada (numa cópia) e abre a rua de novo.
		var copy: Node = packed.instantiate()
		copy.get_node("Lamp1").position.x += 2.0
		var edited := PackedScene.new()
		edited.pack(copy)
		copy.free()
		var path := Campaign.save_dir.path_join("street_set_edited.tscn")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
		t.equal(ResourceSaver.save(edited, path), OK, "grava a cena mexida")
		AHStreetSet.scene_path = path
		street = await _open(tree)
		AHStreetSet.scene_path = AHStreetSet.SCENE
		if t.check(street != null, "a rua abriu com a cena mexida"):
			var moved: Node3D = street._set.get_node("Lamp1")
			t.check(absf(moved.global_position.x - lamp_x - 2.0) < 0.001, "o poste mexido aparece no jogo, 2 m adiante")
			var light: OmniLight3D = street._lamp_lights.filter(func(l): return moved.is_ancestor_of(l))[0]
			var body: StaticBody3D = moved.find_children("*", "StaticBody3D", true, false)[0]
			t.check(absf(light.global_position.x - (lamp_x - 0.53 + 2.0)) < 0.01, "a luz do poste foi junto")
			t.check(absf(body.global_position.x - (lamp_x + 0.52 + 2.0)) < 0.01, "e a colisão também")
	if tree.current_scene != null:
		tree.unload_current_scene()
	await tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _open(tree: SceneTree):
	Campaign.state = Campaign.create_initial(8)
	AHJourneyRules.start_expedition(Campaign.state, "fase_1", 64)
	GameFlow.change_to("street", {}, false)
	for frame in 600:
		await tree.process_frame
		if not GameFlow.busy and tree.current_scene != null and tree.current_scene.get("corridor") != null:
			await tree.process_frame
			return tree.current_scene
	return null
