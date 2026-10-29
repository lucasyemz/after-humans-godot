## Cada inimigo com arte no jogo tem um som próprio para cada ação dele (tools/synth_enemy_sounds.py): nada de todos com o
## mesmo soco de robô. O som existe, é curto e a luta acha o arquivo pela ação.
extends RefCounted


func run(t) -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/combat_art.json"))
	var actions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy-actions.json"))
	var checked := 0
	var paths := {}
	for enemy_id in manifest.enemies.keys():
		var own: Array = actions.filter(func(a): return String(a.EnemyId) == enemy_id)
		t.check(not own.is_empty(), "%s tem ações" % enemy_id)
		for action in own:
			var ability_id := String(action.Name).get_slice(".", 1)
			var path: String = AHCombatArena.ENEMY_CUES % [enemy_id, ability_id]
			if not t.check(ResourceLoader.exists(path), "%s · %s tem som próprio" % [enemy_id, action.DisplayName]):
				continue
			var stream: AudioStream = load(path)
			t.check(stream != null and stream.get_length() > 0.2 and stream.get_length() < 3.0,
				"%s · %s dura entre 0,2 e 3 s" % [enemy_id, action.DisplayName])
			paths[path] = true
			checked += 1
	t.check(checked >= 30, "os sons cobrem as ações dos inimigos (%d)" % checked)
	t.equal(paths.size(), checked, "cada ação tem o seu arquivo")
