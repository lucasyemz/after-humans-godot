## Os três espaços de campanha (#34): criar, abrir e sobrescrever cada um sem mexer nos outros; o último usado é o que
## abre no começo; o save de antes das vagas vira o espaço 1 sem perder nada; um espaço estragado não estraga os outros;
## o resumo de cada espaço (ciclo, fases, elenco vivo, data e tempo jogado) e o tempo jogado só nas cenas de jogo.
extends RefCounted

var t


func run(context) -> void:
	t = context
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var real_slot: int = Campaign.slot
	Campaign.save_dir = "user://test-campaign-slots-%d" % Time.get_ticks_usec()
	Campaign.slot = 1

	_create_and_load()
	_overwrite()
	_migrate_old_save()
	_broken_slot()
	_play_time()

	_clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state
	Campaign.slot = real_slot


## Uma campanha em cada espaço; o último usado é o que abre no começo do jogo; Continuar de outro espaço abre o dele.
func _create_and_load() -> void:
	_clear()
	var rosters := {}
	for number in [1, 2, 3]:
		t.check(Campaign.new_game_in(number, 100 + number), "campanha nova no espaço %d" % number)
		rosters[number] = Campaign.state.roster.map(func(h): return h.perks)
		t.check(FileAccess.file_exists(Campaign.slot_path(number)) and FileAccess.file_exists(Campaign.slot_path(number, true)), "o espaço %d tem principal e cópia" % number)
	t.equal(Campaign.slot_path(1).get_file(), "campaign.json", "o espaço 1 é o save de sempre")
	t.equal(Campaign.slot_path(2).get_file(), "campaign_2.json", "o espaço 2 tem o arquivo dele")
	t.equal(Campaign.last_slot(), 3, "o último espaço usado fica gravado")
	# O jogo abrindo de novo: o autoload lê o último espaço e abre a campanha dele.
	Campaign.state = {}
	Campaign.slot = Campaign.last_slot()
	t.equal(Campaign.load_or_new(), "primary", "ao abrir o jogo, a última campanha usada abre")
	t.equal(Campaign.state.roster.map(func(h): return h.perks), rosters[3], "e é a do espaço 3")
	t.equal(Campaign.use_slot(1), "primary", "abrir o espaço 1")
	t.equal(Campaign.state.roster.map(func(h): return h.perks), rosters[1], "traz a campanha do espaço 1")
	t.equal(Campaign.last_slot(), 1, "e ele passa a ser o último")
	Campaign.state.completed_phases = ["fase_1", "fase_2"]
	Campaign.state.station.cycle_number = 4
	Campaign.state.roster[0].alive = false
	Campaign.save()
	var summary := Campaign.slot_summary(1)
	t.equal([summary.status, summary.cycle, summary.phases, summary.alive, summary.roster], ["ok", 4, 2, Campaign.state.roster.size() - 1, Campaign.state.roster.size()],
		"o resumo do espaço: ciclo, fases e elenco vivo")
	t.check(absi(int(summary.saved_at) - int(Time.get_unix_time_from_system())) < 120, "e a data do save")
	t.check(summary.has("played_seconds") and not summary.in_expedition, "o tempo jogado e se está numa expedição")
	t.equal(Campaign.slot_summary(2).cycle, 0, "os outros espaços com o resumo deles")


## Sobrescrever um espaço não toca nos outros.
func _overwrite() -> void:
	var one := FileAccess.get_file_as_string(Campaign.slot_path(1))
	var three := FileAccess.get_file_as_string(Campaign.slot_path(3))
	var two := FileAccess.get_file_as_string(Campaign.slot_path(2))
	t.check(Campaign.new_game_in(2, 999), "sobrescreve o espaço 2")
	t.check(FileAccess.get_file_as_string(Campaign.slot_path(2)) != two, "o espaço 2 mudou")
	t.equal(FileAccess.get_file_as_string(Campaign.slot_path(1)), one, "o espaço 1 ficou igual")
	t.equal(FileAccess.get_file_as_string(Campaign.slot_path(3)), three, "o espaço 3 ficou igual")


## O save de antes das vagas (campaign.json sem slots.json, sem tempo jogado nem data no envelope) é o espaço 1, inteiro.
func _migrate_old_save() -> void:
	_clear()
	var old: Dictionary = Campaign.create_initial(55)
	old.erase("played_seconds")
	old.inventory.seeds = 4321
	old.completed_phases = ["fase_1"]
	var envelope := {"format": Campaign.FORMAT, "version": Campaign.VERSION, "checksum": JSON.stringify(Campaign._normalize(old), "", true).sha256_text(), "campaign": old}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	for name in [Campaign.PRIMARY, Campaign.BACKUP]:
		var file := FileAccess.open(Campaign.save_dir.path_join(name), FileAccess.WRITE)
		file.store_string(JSON.stringify(envelope, "\t", true))
		file.close()
	Campaign.slot = Campaign.last_slot()
	t.equal(Campaign.slot, 1, "sem slots.json, o espaço é o 1")
	t.equal(Campaign.load_or_new(), "primary", "o save antigo abre como o espaço 1")
	t.equal(int(Campaign.state.inventory.seeds), 4321, "com as sementes de antes")
	t.equal(Campaign.state.roster.map(func(h): return h.id), old.roster.map(func(h): return h.id), "o mesmo elenco")
	t.equal(Campaign.state.completed_phases, ["fase_1"], "as mesmas fases")
	t.equal(int(Campaign.state.played_seconds), 0, "o tempo jogado começa em 0")
	var summary := Campaign.slot_summary(1)
	t.check(summary.status == "ok" and int(summary.saved_at) > 0, "o resumo usa a data do arquivo")
	t.equal(Campaign.slot_summary(2).status, "empty", "os espaços 2 e 3 começam vazios")
	t.check(Campaign.save(), "e grava de novo no formato com a data")
	t.check(Campaign.read_file(Campaign.slot_path(1)) != null, "o espaço 1 continua abrindo")


## Um espaço estragado (principal e cópia) não estraga os outros; slots.json estragado volta ao 1.
func _broken_slot() -> void:
	_clear()
	Campaign.new_game_in(1, 1)
	Campaign.new_game_in(3, 3)
	var one := FileAccess.get_file_as_string(Campaign.slot_path(1))
	for backup in [false, true]:
		var file := FileAccess.open(Campaign.slot_path(2, backup), FileAccess.WRITE)
		file.store_string("{ estragado")
		file.close()
	t.equal([Campaign.slot_summary(1).status, Campaign.slot_summary(2).status, Campaign.slot_summary(3).status], ["ok", "broken", "ok"], "só o espaço 2 aparece estragado")
	t.equal(Campaign.use_slot(2), "new", "abrir o espaço estragado dá uma campanha nova sem gravar")
	t.check(Campaign.load_warning != "", "com o aviso")
	t.equal(FileAccess.get_file_as_string(Campaign.slot_path(2)), "{ estragado", "o arquivo estragado fica como estava")
	t.equal(Campaign.use_slot(1), "primary", "o espaço 1 continua abrindo")
	t.equal(FileAccess.get_file_as_string(Campaign.slot_path(1)), one, "sem mudar")
	t.equal(Campaign.use_slot(3), "primary", "e o 3 também")
	# A cópia salva o espaço quando só o principal estraga.
	var file := FileAccess.open(Campaign.slot_path(3), FileAccess.WRITE)
	file.store_string("{ estragado")
	file.close()
	t.check(Campaign.slot_summary(3).status == "ok" and Campaign.slot_summary(3).recovered, "o espaço com a cópia boa abre pela cópia")
	file = FileAccess.open(Campaign.save_dir.path_join(Campaign.SLOTS_FILE), FileAccess.WRITE)
	file.store_string("nada")
	file.close()
	t.equal(Campaign.last_slot(), 1, "slots.json estragado volta ao espaço 1")
	for value in ["null", "[2]", "{}", "\"2\"", "7", "0"]:
		file = FileAccess.open(Campaign.save_dir.path_join(Campaign.SLOTS_FILE), FileAccess.WRITE)
		file.store_string("{\"last\": %s}" % value)
		file.close()
		t.equal(Campaign.last_slot(), 1, "slots.json com last = %s volta ao espaço 1" % value)
	# O último espaço estragado com outro bom: o aviso diz qual espaço e onde estão as outras.
	file = FileAccess.open(Campaign.save_dir.path_join(Campaign.SLOTS_FILE), FileAccess.WRITE)
	file.store_string("{\"last\": 2}")
	file.close()
	Campaign.slot = Campaign.last_slot()
	Campaign.load_or_new()
	t.check(Campaign.load_warning.contains("espaço 2") and Campaign.load_warning.contains("Campanhas"), "o aviso diz que só o espaço 2 não abre: %s" % Campaign.load_warning)
	Campaign.slot = 1


## O tempo jogado anda na Estação e na rua, não no título; vai para o save em segundos inteiros.
func _play_time() -> void:
	_clear()
	Campaign.new_game_in(1, 7)
	var scene: String = GameFlow.current_id
	GameFlow.current_id = "title"
	Campaign._play_seconds = 0.0
	Campaign._process(0.0)
	OS.delay_msec(40)
	Campaign._process(0.0)
	t.equal(Campaign._play_seconds, 0.0, "no título o tempo não anda")
	GameFlow.current_id = "station"
	OS.delay_msec(40)
	Campaign._process(0.0)
	t.check(Campaign._play_seconds > 0.02, "na Estação anda")
	GameFlow.current_id = scene
	Campaign._play_seconds = 75.6
	var before := int(Campaign.state.get("played_seconds", 0))
	Campaign.save()
	t.equal(int(Campaign.read_file(Campaign.slot_path(1)).played_seconds), before + 75, "o save leva os segundos inteiros")
	t.check(is_equal_approx(snappedf(Campaign._play_seconds, 0.01), 0.6), "e guarda a fração para o próximo")
	Campaign._play_seconds = 600.0
	Campaign.new_game_in(2, 2)
	t.equal(int(Campaign.read_file(Campaign.slot_path(2)).played_seconds), 0, "a campanha nova começa com 0 jogado (o tempo da outra não passa)")
	t.equal(AHTitleScreen.slot_text(Campaign.slot_summary(1), true).contains("1 min jogados"), true, "o resumo mostra o tempo jogado")
	t.check(AHTitleScreen.slot_text({"slot": 2, "status": "empty"}, false).contains("vazio"), "o espaço vazio diz vazio")


func _clear() -> void:
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
