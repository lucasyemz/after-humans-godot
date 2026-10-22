## A mixagem (#36): um barramento por tipo (música, ambiente, efeitos e interface) com o volume das Opções; a tabela de
## mixagem cobre todo som de audio/ e leva a música e os ambientes ao alvo em LUFS; todo som que o código toca existe;
## os sons novos abrem; a interface toca no barramento dela; a música abaixa na crise e volta; cada herói pisa de um jeito.
extends RefCounted

const MIX := "res://data/presentation/audio_mix.json"

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_buses()
	_table()
	_cues_exist()
	await _duck()


func _buses() -> void:
	for bus in ["Music", "Ambience", "SFX", "UI"]:
		t.check(AudioServer.get_bus_index(bus) >= 0, "o barramento %s existe" % bus)
	var settings: Dictionary = Campaign.state.settings
	var real: Dictionary = settings.duplicate()
	settings.music_volume = 0.5
	settings.ambience_volume = 0.4
	settings.sfx_volume = 0.3
	Sound.apply_volumes()
	for spec in [["Music", 0.5], ["Ambience", 0.4], ["SFX", 0.3], ["UI", 0.3]]:
		t.check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(spec[0])) - linear_to_db(spec[1])) < 0.05,
			"o volume das Opções controla %s" % spec[0])
	settings.sfx_volume = 0.0
	Sound.apply_volumes()
	t.check(AudioServer.is_bus_mute(AudioServer.get_bus_index("UI")), "efeitos no zero também calam a interface")
	settings.merge(real, true)
	Sound.apply_volumes()
	Sound.play("res://audio/ui/click.ogg")
	t.equal(Sound._effects[(Sound._next_effect - 1 + Sound._effects.size()) % Sound._effects.size()].bus, "UI", "o clique toca no barramento da interface")
	Sound.play("res://audio/world/door_open.ogg")
	t.equal(Sound._effects[(Sound._next_effect - 1 + Sound._effects.size()) % Sound._effects.size()].bus, "SFX", "a porta, no de efeitos")


## A tabela tem todo som de audio/; a música e os ambientes chegam ao alvo em LUFS.
func _table() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MIX))
	var files: Dictionary = table.files
	var missing: Array = []
	for path in _audio_files("res://audio"):
		if not files.has(path):
			missing.append(path)
	t.check(missing.is_empty(), "a tabela de mixagem cobre todo som de audio/ (rode tools/measure_audio.py): %s" % [missing])
	var off: Array = []
	var music := 0
	var ambience := 0
	for path in files:
		var entry: Dictionary = files[path]
		if not FileAccess.file_exists(path):
			off.append("%s não existe mais" % path)
			continue
		if entry.category == "music":
			music += 1
		elif entry.category == "ambience":
			ambience += 1
		if entry.category in ["music", "ambience", "ui"]:
			if not entry.normalized or absf(float(entry.lufs) + float(entry.gain_db) - float(table.targets[entry.category])) > 0.2:
				off.append(path)
	t.check(off.is_empty(), "a música, os ambientes e a interface no alvo: %s" % [off])
	t.check(music >= 6 and ambience >= 9, "as trilhas (%d) e os ambientes (%d) medidos" % [music, ambience])
	t.check(Sound.mix_db("res://audio/music/boss.ogg") < -5.0 and Sound.mix_db("res://audio/music/explore_3.ogg") > 5.0,
		"a trilha do chefe abaixa e a da Estação sobe (ficam no mesmo volume)")
	t.equal(Sound.mix_db("res://audio/nao_existe.ogg"), 0.0, "som fora da tabela fica como está")


## Todo som que o código toca existe; os novos (#36) abrem.
func _cues_exist() -> void:
	var absent: Array = []
	var regex := RegEx.create_from_string("\"(res://audio/[^\"%]+\\.(ogg|mp3|wav))\"")
	for script in _files("res://scripts", ".gd"):
		for found in regex.search_all(FileAccess.get_file_as_string(script)):
			if not ResourceLoader.exists(found.get_string(1)):
				absent.append("%s: %s" % [script.get_file(), found.get_string(1)])
	t.check(absent.is_empty(), "todo som citado no código existe: %s" % [absent])
	for name in ["station/train_bell", "station/train_brake", "ui/panel_open", "ui/panel_close", "ui/forge_confirm",
			"world/find_rare", "ui/victory", "ui/defeat", "combat/crisis"]:
		t.check(load("res://audio/%s.ogg" % name) is AudioStream, "o som novo %s abre" % name)
	for class_id in Campaign.FOUNDERS:
		t.check(Sound.HERO_STEPS.has(class_id), "o passo de %s" % class_id)
	t.check(Sound.HERO_STEPS.cao[0] < Sound.HERO_STEPS.gato[0], "o Bento pisa mais grave que o Nick")


## A música abaixa na crise e volta sozinha.
func _duck() -> void:
	var music := AudioServer.get_bus_index("Music")
	var before := AudioServer.get_bus_volume_db(music)
	Sound.duck(9.0, 0.05)
	await _tree.create_timer(0.3).timeout
	t.check(AudioServer.get_bus_volume_db(music) < before - 3.0, "a música abaixa (%.1f → %.1f dB)" % [before, AudioServer.get_bus_volume_db(music)])
	await _tree.create_timer(1.3).timeout
	t.check(absf(AudioServer.get_bus_volume_db(music) - before) < 0.1, "e volta ao volume das Opções")
	# Um mais fraco no meio de um mais forte não o corta; depois dele, vale.
	Sound.duck(9.0, 0.6)
	await _tree.create_timer(0.2).timeout
	Sound.duck(3.0, 0.05)
	await _tree.create_timer(0.2).timeout
	t.check(Sound.duck_db < -8.0, "um abaixamento mais fraco não corta o mais forte (%.1f dB)" % Sound.duck_db)
	await _tree.create_timer(1.5).timeout
	# Na pausa do acerto (o tempo quase parado) a música abaixa do mesmo jeito.
	var scale := Engine.time_scale
	Engine.time_scale = 0.03
	Sound.duck(5.0, 0.35)
	await _tree.create_timer(0.25, true, false, true).timeout
	Engine.time_scale = scale
	t.check(Sound.duck_db < -4.0, "o abaixamento anda mesmo com o tempo quase parado (%.1f dB)" % Sound.duck_db)
	await _tree.create_timer(1.5).timeout


func _audio_files(root: String) -> Array:
	var out: Array = []
	for extension in [".ogg", ".mp3", ".wav"]:
		out.append_array(_files(root, extension))
	return out


func _files(root: String, extension: String) -> Array:
	var out: Array = []
	for file in DirAccess.get_files_at(root):
		if file.ends_with(extension):
			out.append(root.path_join(file))
	for folder in DirAccess.get_directories_at(root):
		out.append_array(_files(root.path_join(folder), extension))
	return out
