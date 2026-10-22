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
	Settings.level = real
	Settings.apply()
	lamp.free()
	t.check(not AHPerfTour.requested(), "o roteiro de desempenho não liga sem --perf")
