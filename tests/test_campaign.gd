## Campaign: campanha nova, save em JSON com cópia de segurança, recuperação e recusa de campanha inválida.
## Usa uma pasta temporária; o save real e o estado carregado ficam como estavam.
extends RefCounted


func run(t) -> void:
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var dir := "user://test-saves-%d" % Time.get_ticks_usec()
	Campaign.save_dir = dir
	_new_campaign(t)
	_save_and_load(t)
	_recovery(t)
	_refuse_invalid(t)
	_remove_dir(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _new_campaign(t) -> void:
	var campaign: Dictionary = Campaign.create_initial(42)
	var ids: Array = campaign.roster.map(func(hero): return hero.id)
	t.equal(ids, ["hero_cao_bento", "hero_gato_nick", "hero_sapo_iris", "hero_coruja_vespera"], "fundadores e ids")
	t.equal(campaign.preferred_formation, ids, "formação inicial")
	t.equal(campaign.unlocked_classes, ["cao", "gato", "sapo", "coruja"], "classes liberadas")
	t.equal(campaign.inventory.seeds, 30, "sementes iniciais")
	t.equal(campaign.inventory.bandages, 2, "curativos iniciais")
	var perks: Dictionary = GameData.table("perks")
	for hero in campaign.roster:
		var hero_class = GameData.row("classes", hero.class_id)
		t.equal(hero.max_hp, int(hero_class.BaseMaxHp), "%s: vida máxima da classe" % hero.id)
		t.check(hero.hp == hero.max_hp, "%s: começa com a vida cheia" % hero.id)
		t.check(hero.perks.size() >= 2 and hero.perks.size() <= 3, "%s: 2 ou 3 perks (%s)" % [hero.id, hero.perks])
		var types: Array = hero.perks.map(func(id): return perks[id].Type)
		t.check(types.has("Positive") and types.has("Negative"), "%s: um perk positivo e um negativo" % hero.id)
		for a in hero.perks:
			for b in hero.perks:
				t.check(not perks[a].get("Incompatible", []).has(b), "%s: perks incompatíveis %s e %s" % [hero.id, a, b])
	t.equal(Campaign.create_initial(42), campaign, "a mesma semente dá a mesma campanha")
	t.check(Campaign.is_usable(campaign), "campanha nova é utilizável")


func _save_and_load(t) -> void:
	t.check(Campaign.new_game(7), "new_game grava")
	var saved: Dictionary = Campaign.state.duplicate(true)
	t.check(FileAccess.file_exists(Campaign.primary_path()) and FileAccess.file_exists(Campaign.backup_path()), "principal e cópia existem")
	t.equal(FileAccess.get_file_as_string(Campaign.backup_path()), FileAccess.get_file_as_string(Campaign.primary_path()), "cópia igual ao principal")
	t.check(not FileAccess.file_exists(Campaign.primary_path() + ".tmp"), "nenhum .tmp sobra depois de gravar")
	Campaign.state = {}
	t.equal(Campaign.load_or_new(), "primary", "abre pelo principal")
	t.equal(Campaign.state, saved, "o estado volta igual ao gravado")
	t.equal(Campaign.warning_text(), "", "sem aviso ao abrir um save bom")


func _recovery(t) -> void:
	var saved: Dictionary = Campaign.state.duplicate(true)
	_write(Campaign.primary_path(), "{ isto não é JSON")
	t.equal(Campaign.load_or_new(), "backup", "principal corrompido: abre pela cópia")
	t.equal(Campaign.state, saved, "a cópia tem o estado gravado")
	t.check(Campaign.warning_text() != "", "avisa que recuperou a cópia")

	# Cópia adulterada (o checksum não bate) e principal corrompido: campanha nova, sem apagar os arquivos.
	var tampered := FileAccess.get_file_as_string(Campaign.backup_path()).replace("\"seeds\": 30", "\"seeds\": 999")
	t.check(tampered.contains("999"), "o teste conseguiu adulterar a cópia")
	_write(Campaign.backup_path(), tampered)
	t.equal(Campaign.load_or_new(), "new", "nenhum save válido: campanha nova")
	t.check(Campaign.warning_text().begins_with("Nenhum salvamento válido"), "avisa que nenhum save serviu")
	t.check(FileAccess.file_exists(Campaign.primary_path()) and FileAccess.file_exists(Campaign.backup_path()), "os arquivos antigos foram preservados")

	# Versão diferente também não abre.
	var other_version: Dictionary = JSON.parse_string(tampered.replace("999", "30"))
	other_version.version = 999
	_write(Campaign.backup_path(), JSON.stringify(other_version))
	t.check(Campaign.read_file(Campaign.backup_path()) == null, "save de outra versão é recusado")


func _refuse_invalid(t) -> void:
	t.check(Campaign.new_game(3), "grava uma campanha válida")
	var before := FileAccess.get_file_as_string(Campaign.primary_path())
	Campaign.state.roster = []
	t.check(not Campaign.save(), "recusa gravar campanha sem heróis")
	t.equal(FileAccess.get_file_as_string(Campaign.primary_path()), before, "o save anterior continua intacto")


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove_dir(dir: String) -> void:
	var absolute := ProjectSettings.globalize_path(dir)
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(absolute.path_join(file))
	DirAccess.remove_absolute(absolute)
