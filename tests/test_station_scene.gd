## A cena da Estação: abrir e fechar não deixa conexões nas opções (Settings.changed).
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")


func run(t) -> void:
	var tree: SceneTree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-station-scene-%d" % Time.get_ticks_usec()
	Campaign.state = Campaign.create_initial(21)
	var counts: Array = []
	for visit in 3:
		var station = await _open(tree)
		t.check(station != null, "a Estação abriu (visita %d)" % (visit + 1))
		counts.append(Settings.changed.get_connections().size())
	t.check(counts[0] == counts[1] and counts[1] == counts[2], "abrir a Estação de novo não soma conexões nas opções (%s)" % [counts])
	tree.unload_current_scene()
	await tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _open(tree: SceneTree):
	GameFlow.change_to("station", {}, false)
	for frame in 300:
		await tree.process_frame
		var scene := tree.current_scene
		if not GameFlow.busy and scene is AHStation and scene.hud != null:
			await tree.process_frame
			return scene
	return null
