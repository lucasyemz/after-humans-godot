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
		# O dano e a queda dos quatro fundadores (a da Íris e a da Véspera ajoelhadas, #13), no pé do parado.
		for pose in ["hurt", "death"]:
			var reaction: Dictionary = hero.get("reactions", {}).get(pose, {})
			if t.check(not reaction.is_empty(), "%s: pose %s" % [hero_id, pose]):
				_check_measured(t, reaction, "%s %s" % [hero_id, pose])

	_john_villains(t, art)
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


## Os vilões do John (#44, #45): cada pose de luta tem a âncora, a altura e a tela do idle (o pé não pula e a derrota
## não cresce); a pose do inimigo ao agir; e a placa dos baixinhos sempre acima da cabeça.
func _john_villains(t, art: Dictionary) -> void:
	for enemy_id in ["recreador", "pipoco", "enraizado", "broto", "carrasco_industrial", "faisca"]:
		var enemy: Dictionary = art.enemies.get(enemy_id, {})
		if not t.check(not enemy.is_empty(), "arte de %s" % enemy_id):
			continue
		for pose in ["attack1", "hurt", "defense", "death"]:
			var entry: Dictionary = enemy.poses.get(pose, {})
			t.check(not entry.is_empty(), "%s tem a pose %s" % [enemy_id, pose])
			if not entry.is_empty():
				t.equal([entry.anchor, entry.body_reference_pixels, entry.canvas], [enemy.idle.anchor, enemy.idle.body_reference_pixels, enemy.idle.canvas],
					"%s %s: mesma âncora, altura e tela do idle" % [enemy_id, pose])
	var horn = GameData.row("enemy_actions", "pipoco.buzina_irritante")
	var laugh = GameData.row("enemy_actions", "recreador.risada_gravada")
	t.equal(AHCombatArena.enemy_action_pose(horn, art.enemies.pipoco), "support", "a Buzina do Pipoco usa a pose de apoio")
	t.equal(AHCombatArena.enemy_action_pose(laugh, art.enemies.recreador), "support", "a Risada do Recreador usa a pose de apoio")
	t.equal(AHCombatArena.enemy_action_pose(GameData.row("enemy_actions", "enraizado.golpe_provisorio"), art.enemies.enraizado), "attack1",
		"o golpe do Enraizado usa o ataque")
	t.equal(AHCombatArena.enemy_action_pose(horn, art.enemies.enraizado), "attack1", "sem pose de apoio, o golpe sem dano usa o ataque")
	var H := preload("res://scripts/ui/combat_hud.gd")
	for dock in [INF, 700.0, 500.0]:
		t.equal(H.plate_y(760.0, 650.0, true, 70.0, dock), 650.0 - 70.0 - 8.0, "baixinho: a placa fica acima da cabeça (painel em %s)" % dock)
	t.equal(H.plate_y(760.0, 400.0, false, 70.0, INF), 770.0, "alto sem o painel: sob os pés")
	t.equal(H.plate_y(760.0, 400.0, false, 70.0, 700.0), 700.0, "alto com o painel: no limite do painel")
