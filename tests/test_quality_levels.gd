## As qualidades gráficas (#37): a sombra das luminárias só no Alto e no Ultra do Forward+ e no Ultra do Compatibility
## (o da web), e ela segue a qualidade na hora; o LOD mais cedo no Baixo e no Médio; e o roteiro de desempenho (--perf)
## não liga sozinho.
extends RefCounted

const SettingsService := preload("res://scripts/core/settings_service.gd")


func run(t) -> void:
	for quality in 4:
		var forward: Dictionary = SettingsService.effects_for(quality, true)
		var web: Dictionary = SettingsService.effects_for(quality, false)
		t.equal(forward.lamp_shadows, quality >= 2, "Forward+ %s: sombra das luminárias %s" % [Settings.LEVEL_NAMES[quality], quality >= 2])
		t.equal(web.lamp_shadows, quality >= 3, "Compatibility %s: sombra das luminárias %s" % [Settings.LEVEL_NAMES[quality], quality >= 3])
		t.equal(forward.shadows, quality >= 1, "a sombra do sol a partir do Médio (%s)" % Settings.LEVEL_NAMES[quality])
	t.check(SettingsService.LOD_THRESHOLD[0] > SettingsService.LOD_THRESHOLD[2] and SettingsService.LOD_THRESHOLD[2] == 1.0, "o Baixo troca para o LOD mais simples antes")

	var tree: SceneTree = Engine.get_main_loop()
	var lamp := OmniLight3D.new()
	lamp.add_to_group(Settings.SHADOW_LAMPS)
	lamp.shadow_enabled = true
	tree.root.add_child(lamp)
	var real: int = Settings.level
	Settings.level = 0
	Settings.apply()
	t.check(not lamp.shadow_enabled, "no Baixo a luminária acende sem sombra")
	t.equal(tree.root.get_viewport().mesh_lod_threshold, SettingsService.LOD_THRESHOLD[0], "o LOD do Baixo vale na hora")
	Settings.level = 3
	Settings.apply()
	t.check(lamp.shadow_enabled, "no Ultra a sombra volta")
	lamp.free()
	# Numa cena de verdade: a rua (a fogueira) e uma casa com acampamento no Baixo não têm luz omni com sombra.
	Settings.level = 0
	Settings.apply()
	var room := AHHouseRoom.new()
	tree.root.add_child(room)
	room.build(0, 0.0, 2, true)
	var shadowed: Array = room.find_children("*", "OmniLight3D", true, false).filter(func(l): return l.shadow_enabled)
	t.check(shadowed.is_empty(), "a casa com acampamento no Baixo: luzes sem sombra %s" % [shadowed])
	room.free()
	await _street_lights(t, tree)
	Settings.level = real
	Settings.apply()
	t.check(not AHPerfTour.requested(), "o roteiro de desempenho não liga sem --perf")


func _street_lights(t, tree: SceneTree) -> void:
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-quality-%d" % Time.get_ticks_usec()
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
		var lights: Array = street.find_children("*", "OmniLight3D", true, false)
		t.check(lights.size() > 3, "a rua tem luminárias (%d)" % lights.size())
		var shadowed: Array = lights.filter(func(l): return l.shadow_enabled).map(func(l): return str(l.get_path()))
		t.check(shadowed.is_empty(), "a rua no Baixo (fogueira e postes): nenhuma luz omni com sombra %s" % [shadowed])
		Settings.level = 3
		Settings.apply()
		t.check(lights.any(func(l): return l.shadow_enabled), "no Ultra as luminárias da rua voltam a ter sombra")
		tree.unload_current_scene()
		await tree.process_frame
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state
