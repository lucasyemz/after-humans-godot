## data/presentation/combat_art.json: todo arquivo existe, cada habilidade dos heróis tem ícone, as três fases e som, e
## os inimigos das patrulhas têm as poses que a arena usa.
extends RefCounted

const POSES := ["attack1", "defense", "hurt", "death", "dodge", "support"]
const CUES := {"cao": "BentoAction", "gato": "NickAction", "sapo": "IrisAction", "coruja": "VesperaAction"}


func run(t) -> void:
	var art = JSON.parse_string(FileAccess.get_file_as_string(AHCombatArena.ART_MANIFEST))
	if not t.check(typeof(art) == TYPE_DICTIONARY, "manifesto da arte do combate carrega"):
		return
	var files := 0
	for path in _files(art):
		files += 1
		t.check(ResourceLoader.exists(path), "arquivo existe: %s" % path)
	t.note("%d arquivos" % files)

	for hero_id in ["hero_cao_bento", "hero_gato_nick", "hero_sapo_iris", "hero_coruja_vespera"]:
		var hero: Dictionary = art.heroes.get(hero_id, {})
		if not t.check(not hero.is_empty(), "arte de %s" % hero_id):
			continue
		_check_measured(t, hero.idle, hero_id + " parado")
		var class_id: String = hero_id.split("_")[1]
		var abilities: Array = GameData.row("classes", class_id).AbilityIds
		for index in abilities.size():
			var ability_id: String = abilities[index]
			t.check(art.icons.has(ability_id), "ícone de %s" % ability_id)
			t.check(art.audio.has("%s%d" % [CUES[class_id], index + 1]), "som de %s" % ability_id)
			var phases: Dictionary = hero.actions.get(ability_id, {})
			for phase in ["preparacao", "execucao", "vfx"]:
				t.check(phases.has(phase), "%s: fase %s" % [ability_id, phase])
			if phases.has("execucao"):
				_check_measured(t, phases.execucao, ability_id + " execução")

	for enemy_id in ["robot", "robot_fungo", "vigia_enferrujado"]:
		var enemy: Dictionary = art.enemies.get(enemy_id, {})
		if not t.check(not enemy.is_empty(), "arte de %s" % enemy_id):
			continue
		_check_measured(t, enemy.idle, enemy_id + " parado")
		if enemy.idle.has("frames"):
			# Quadro vazio faz o personagem sumir no meio da animação.
			var sheet: Image = (load(enemy.idle.file) as Texture2D).get_image()
			if sheet.is_compressed():
				sheet.decompress()
			for frame in enemy.idle.frames:
				var region := sheet.get_region(Rect2i(frame[0], frame[1], frame[2], frame[3]))
				t.check(not region.is_invisible(), "%s: quadro %s da folha parada tem desenho" % [enemy_id, frame])
		for pose in POSES:
			t.check(enemy.poses.has(pose), "%s: pose %s" % [enemy_id, pose])
	for cue in ["Dodge", "RobotDodge", "RobotHeal", "RobotPunch", "UIClick"]:
		t.check(art.audio.has(cue), "som %s" % cue)


func _check_measured(t, entry: Dictionary, label: String) -> void:
	t.check(entry.has("anchor") and entry.has("canvas") and float(entry.get("body_reference_pixels", 0)) > 0, "%s tem âncora e altura do corpo" % label)


func _files(value) -> Array:
	var found: Array = []
	match typeof(value):
		TYPE_DICTIONARY:
			for key in value:
				if key == "file" and typeof(value[key]) == TYPE_STRING:
					found.append(value[key])
				else:
					found.append_array(_files(value[key]))
		TYPE_ARRAY:
			for item in value:
				found.append_array(_files(item))
		TYPE_STRING:
			if value.begins_with("res://"):
				found.append(value)
	return found
