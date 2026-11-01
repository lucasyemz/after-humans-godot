## As skins completas (#138): a skin troca a arte do herói em todas as telas por um lugar só (AHCombatArena.art_entry e
## AHSkins.pose); a pose que falta cai na padrão; o save guarda e reabre a skin, e o save antigo abre com a padrão; a
## bloqueada não se veste; a barra de Admin libera todas; só visual (a paridade fica no test_combat_parity).
## A skin de teste aponta para a pasta da arte do Nick: troca o parado e as reações do Bento e deixa as habilidades, o
## retrato e as poses da Estação na padrão. Com a arte da Ronda (#137) no projeto, ela também é conferida inteira.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const TEST_SKIN := "test_bento_nick_folder"
const BENTO := "hero_cao_bento"

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_state: Dictionary = Campaign.state
	var real_dir: String = Campaign.save_dir
	var skins: Dictionary = GameData.table("skins")
	skins[TEST_SKIN] = {"Name": TEST_SKIN, "HeroId": BENTO, "DisplayName": "Teste", "Text": "", "Folder": "res://art/combat/heroes/nick",
		"Unlock": "admin", "Order": 99}
	AHSkins.forget()
	Campaign.save_dir = "user://test-skins-%d" % Time.get_ticks_usec()
	_data()
	_dress()
	_rules()
	_save()
	_watch()
	await _screens()
	skins.erase(TEST_SKIN)
	AHSkins.forget()
	# O rosto guardado pelo arquivo do parado: o da skin de teste (a pasta do Nick) não fica para os testes seguintes.
	AHUiStyle._portraits.clear()
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state


## data/skins.json: cada skin de um herói que existe, com nome, texto, pasta e como se libera.
func _data() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AHCombatArena.ART_MANIFEST))
	for row in GameData.table("skins").values():
		if row.Name == TEST_SKIN:
			continue
		t.check(manifest.heroes.has(String(row.HeroId)), "%s: de um herói do manifesto" % row.Name)
		t.check(String(row.DisplayName) != "" and String(row.get("Text", "")) != "" and String(row.Folder).begins_with("res://art/skins/"),
			"%s: nome, texto e pasta em art/skins" % row.Name)
		var unlock := String(row.Unlock)
		t.check(["start", "admin"].has(unlock) or (unlock.begins_with("phase:") and not AHJourneyRules.phase(unlock.trim_prefix("phase:")).is_empty()),
			"%s: como se libera (%s)" % [row.Name, unlock])
		# O que ainda falta na skin (as poses que caem na padrão): a lista sai no relatório do teste.
		var missing := AHSkins.missing(String(row.Name), manifest.heroes[row.HeroId], _extra_files(String(row.HeroId)))
		print("    %s: faltam %d pose(s)%s" % [row.Name, missing.size(), (": " + ", ".join(missing)) if not missing.is_empty() else ""])
	# A Ronda inteira (a arte do #204 na main): as 18 poses de verdade (o parado, a guarda de luta da #221, as 8 das
	# habilidades, as 3 reações e as 5 da Estação e do acampamento) e o retrato, nenhuma caindo na padrão.
	var watch = GameData.row("skins", "bento_watch")
	if t.check(watch != null and AHSkins.has_art("bento_watch"), "a Ronda tem a arte no projeto"):
		var poses: Array = Array(DirAccess.get_files_at(String(watch.Folder))).filter(func(f): return f.ends_with(".webp") and f != AHSkins.PORTRAIT)
		t.equal(poses.size(), 18, "a Ronda tem as 18 poses (%s)" % [poses])
		t.equal(AHSkins.missing("bento_watch", manifest.heroes[BENTO], _extra_files(BENTO)), [], "e nenhuma pose do Bento cai na padrão")
		for file in poses:
			t.check(ResourceLoader.exists(String(watch.Folder).path_join(file)) and load(String(watch.Folder).path_join(file)) is Texture2D,
				"a pose %s abre" % file)


## A entrada vestida: as poses que a pasta tem trocam, o resto fica na padrão; as medidas e os efeitos ficam os da padrão.
func _dress() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AHCombatArena.ART_MANIFEST))
	var base: Dictionary = manifest.heroes[BENTO]
	var dressed := AHSkins.dress(base, TEST_SKIN)
	t.equal(dressed.idle.file, "res://art/combat/heroes/nick/idle.webp", "a skin troca o parado")
	t.equal(dressed.idle.anchor, base.idle.anchor, "com a âncora e a altura da pose padrão")
	t.equal(dressed.reactions.hurt.file, "res://art/combat/heroes/nick/hurt.webp", "e as reações que a pasta tem")
	var ability: String = base.actions.keys()[0]
	t.equal(dressed.actions[ability].execucao.file, base.actions[ability].execucao.file, "a pose que falta cai na padrão (%s)" % ability)
	t.equal(dressed.actions[ability].get("vfx", {}), base.actions[ability].get("vfx", {}), "o efeito é o mesmo em qualquer skin")
	t.equal(dressed.idle.portrait, base.idle.portrait, "sem retrato na pasta, o da padrão")
	t.check(AHSkins.dress(base, AHSkins.DEFAULT) == base and AHSkins.dress(base, "skin_que_nao_existe") == base, "a padrão (e a desconhecida) é a arte de hoje")
	t.equal(base.idle.file, "res://art/combat/heroes/bento/idle.webp", "vestir não mexe no manifesto")


## Escolher: a bloqueada não se veste; a liberada, sim, fora da expedição; a de outro herói, não.
func _rules() -> void:
	Campaign.state = Campaign.create_initial(138)
	var c: Dictionary = Campaign.state
	t.check(S.hero(c, BENTO).skin_id == AHSkins.DEFAULT, "o herói começa na padrão")
	for row in GameData.table("skins").values():
		if row.Unlock == "start":
			t.check(c.unlocked_skins.has(row.Name), "%s: liberada na campanha nova" % row.Name)
	# A Ronda vem ao terminar a fase 4 (decisão do Lucas): bloqueada no começo, com o motivo; liberada na volta da fase
	# terminada, com o aviso no relatório; e o save antigo de quem já terminou a fase abre com ela.
	t.check(not c.unlocked_skins.has("bento_watch"), "a Ronda começa bloqueada")
	t.check(S.skin_lock_reason(c, "bento_watch").contains(tr(AHJourneyRules.phase("fase_4").name)), "e diz que vem com a fase 4 (%s)" % S.skin_lock_reason(c, "bento_watch"))
	var won: Dictionary = Campaign.create_initial(1384)
	won.completed_phases.append("fase_4")
	won.session.expedition = {"id": "test-fase-4", "phase_id": "fase_4", "team": [BENTO], "loot": {}, "food": 0, "first_clear": true}
	won.session.result = "victory"
	var delivered: Dictionary = S.finish_return(won)
	t.check(won.unlocked_skins.has("bento_watch") and delivered.get("skins", []) == ["bento_watch"], "terminada a fase 4, a volta libera a Ronda e avisa (%s)" % [delivered.get("skins")])
	var report := AHStationReport.new()
	report.report = delivered
	var chips: Array = report._chips(won, "victory")
	report.free()
	t.check(chips.any(func(chip): return String(chip.text) == tr("Roupa nova: %s") % tr("Ronda")), "o relatório mostra a roupa nova, curto (o nome da aba)")
	var again: Dictionary = S.finish_return(won)
	t.check(again.get("skins", []).is_empty(), "e só avisa uma vez")
	# Salvo e reaberto entre o guardião e a volta: o save abre sem liberar a fase em curso, e o aviso vem na volta.
	var reopened: Dictionary = Campaign.create_initial(1386)
	reopened.completed_phases.append("fase_4")
	reopened.session.expedition = {"id": "test-fase-4b", "phase_id": "fase_4", "team": [BENTO], "loot": {}, "food": 0, "first_clear": true}
	reopened.session.result = "victory"
	S.migrate(reopened)
	t.check(not reopened.unlocked_skins.has("bento_watch"), "reaberto no meio da fase 4, a Ronda espera a volta")
	t.equal(S.finish_return(reopened).get("skins", []), ["bento_watch"], "e a volta libera e avisa")
	var old: Dictionary = Campaign.create_initial(1385)
	old.completed_phases.append("fase_4")
	S.migrate(old)
	t.check(old.unlocked_skins.has("bento_watch"), "o save de quem já terminou a fase 4 abre com a Ronda")
	var art_before: String = AHCombatArena.hero_art_of(BENTO).idle.file
	t.check(S.choose_skin(c, BENTO, TEST_SKIN) != "" and S.hero(c, BENTO).skin_id == AHSkins.DEFAULT, "a bloqueada não se veste")
	t.check(S.skin_lock_reason(c, TEST_SKIN) != "", "e diz o motivo")
	t.check(S.choose_skin(c, "hero_gato_nick", TEST_SKIN) != "", "a skin de um herói não serve em outro")
	var locked: int = GameData.table("skins").values().filter(func(row): return not c.unlocked_skins.has(row.Name) and AHSkins.has_art(row.Name)).size()
	var before: Array = c.unlocked_skins.duplicate()
	t.equal(S.unlock_all_skins(c), locked, "a barra de Admin libera todas as que têm arte")
	t.check(c.unlocked_skins.filter(func(id): return not before.has(id)).all(func(id): return AHSkins.has_art(id)),
		"e não libera nenhuma sem arte")
	t.check(S.skin_unlocked(c, TEST_SKIN), "liberada")
	t.equal(S.choose_skin(c, BENTO, TEST_SKIN), "", "liberada, se veste")
	t.check(AHCombatArena.hero_art_of(BENTO).idle.file != art_before, "e a arte do herói muda (a luta, a rua, a Sala e os rostos)")
	t.equal(S.choose_skin(c, BENTO, AHSkins.DEFAULT), "", "a padrão sempre se veste")
	t.equal(AHCombatArena.hero_art_of(BENTO).idle.file, art_before, "e a arte volta")
	c.session.expedition = {"id": "test"}
	t.check(S.choose_skin(c, BENTO, TEST_SKIN) != "", "na expedição, não se troca")
	c.session.expedition = null


## O save guarda e reabre a skin; o save antigo (sem os campos) abre com a padrão e com as skins do começo.
func _save() -> void:
	Campaign.state = Campaign.create_initial(1381)
	var c: Dictionary = Campaign.state
	S.unlock_all_skins(c)
	S.choose_skin(c, BENTO, TEST_SKIN)
	t.check(Campaign.save(), "o save grava")
	var back = Campaign.read_file(Campaign.primary_path())
	if t.check(back != null, "e abre de novo"):
		t.equal(S.hero(back, BENTO).skin_id, TEST_SKIN, "com a skin")
		t.check(back.unlocked_skins.has(TEST_SKIN), "e as liberadas")
	var old: Dictionary = Campaign.create_initial(1382)
	old.erase("unlocked_skins")
	for entry in old.roster:
		entry.erase("skin_id")
	var reopened = Campaign._normalize(JSON.parse_string(JSON.stringify(old)))
	S.migrate(reopened)
	t.check(reopened.roster.all(func(h): return h.skin_id == AHSkins.DEFAULT), "o save antigo abre com a padrão")
	t.check(typeof(reopened.unlocked_skins) == TYPE_ARRAY, "e com a lista das liberadas")
	for row in GameData.table("skins").values():
		if row.Unlock == "start":
			t.check(reopened.unlocked_skins.has(row.Name), "%s: liberada também no save antigo" % row.Name)


## A Ronda (#137), quando a arte dela está no projeto: inteira, nas poses da luta, da Estação e do acampamento.
func _watch() -> void:
	if GameData.row("skins", "bento_watch") == null or not AHSkins.has_art("bento_watch"):
		print("    a arte da Ronda ainda não está no projeto (#204): conferida só com a skin de teste")
		Campaign.state = Campaign.create_initial(1385)
		t.check(not AHSkins.of_hero(BENTO).any(func(row): return row.Name == "bento_watch"), "sem a arte, a Ronda não aparece na Sala")
		t.check(S.choose_skin(Campaign.state, BENTO, "bento_watch") != "", "nem se veste")
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AHCombatArena.ART_MANIFEST))
	t.equal(AHSkins.missing("bento_watch", manifest.heroes[BENTO], _extra_files(BENTO)), [], "a Ronda tem todas as poses")
	Campaign.state = Campaign.create_initial(1383)
	Campaign.state.completed_phases.append("fase_4")
	S.migrate(Campaign.state)
	t.equal(S.choose_skin(Campaign.state, BENTO, "bento_watch"), "", "com a fase 4 terminada, a Ronda se veste")
	var poses: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/station_poses.json"))
	for kind in ["seat", "sleep", "work"]:
		t.check(String(AHSkins.pose(poses[BENTO + "_" + kind], BENTO).file).begins_with("res://art/skins/bento/watch/"), "a Ronda na pose %s da Estação" % kind)
	var camp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/camp_poses.json"))
	t.check(String(AHSkins.pose(camp.heroes[BENTO].seat, BENTO).file).begins_with("res://art/skins/bento/watch/"), "e sentada no acampamento")
	t.check(String(AHCombatArena.hero_art_of(BENTO).idle.portrait).ends_with("watch/portrait.webp"), "e com o retrato dela")


## Na tela: a Sala mostra o seletor; a bloqueada não veste; vestir troca a figura do herói na Sala (no cômodo, ele segue
## na roupa do lobby, #249).
func _screens() -> void:
	Campaign.state = Campaign.create_initial(1384)
	var tips: bool = Tips.enabled
	Tips.enabled = false
	GameFlow.change_to("station", {}, false)
	var station: AHStation = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene is AHStation and frame > 3:
			station = _tree.current_scene
			break
	if t.check(station != null, "a Estação abriu"):
		var hud: AHRefugeHud = station.hud
		var resident: AHSpriteCard = station.residents.get(BENTO)
		var before: Texture2D = resident._texture if resident != null else null
		hud.open_room(S.CHARACTERS)
		await _frames(4)
		var screen: AHCharacterRoom = hud._room_screen
		screen.selected = BENTO
		screen.rebuild()
		await _frames(3)
		var tab: Button = screen.find_child("Skin_%s" % TEST_SKIN, true, false)
		t.check(screen.find_child("Skins", true, false) != null and tab != null, "a Sala mostra as roupas do Bento")
		if tab != null:
			tab.pressed.emit()
			await _frames(3)
			t.equal(S.hero(Campaign.state, BENTO).skin_id, AHSkins.DEFAULT, "a bloqueada não se veste pela Sala")
		S.unlock_all_skins(Campaign.state)
		screen.rebuild()
		await _frames(3)
		tab = screen.find_child("Skin_%s" % TEST_SKIN, true, false)
		if tab != null:
			tab.pressed.emit()
			await _frames(4)
		t.equal(S.hero(Campaign.state, BENTO).skin_id, TEST_SKIN, "a liberada se veste pela Sala")
		# O nome de cada aba cabe nela, no Normal e no Maior (o nome curto, numa linha).
		var size_before: int = Settings.text_size
		for size in [0, 2]:
			Settings.set_text_size(size)
			hud._room_screen.rebuild()
			await _frames(4)
			var spilled: Array = []
			for skin_tab in hud._room_screen.find_children("Skin_*", "Button", true, false):
				var label: Label = skin_tab.get_node("SkinName")
				if label.get_minimum_size().x > skin_tab.size.x or label.get_line_count() > 1:
					spilled.append("%s (%s)" % [skin_tab.name, label.text])
			t.equal(spilled, [], "o nome cabe na aba (%s)" % ("Maior" if size == 2 else "Normal"))
		Settings.set_text_size(size_before)
		# O escolhido está no cômodo da Sala (#181): a placa dele troca de roupa na hora, sem sair da sala.
		t.check(station.stage_hero == BENTO and is_instance_valid(station.stage_card)
			and String(station.stage_card.art().get("file", "")) == "res://art/combat/heroes/nick/idle.webp", "a placa no cômodo da Sala troca na hora")
		# A placa dele no cômodo fica na roupa confortável do lobby (#249): a skin é a da expedição.
		resident = station.residents.get(BENTO)
		t.check(resident != null and resident._texture == before and String(resident.art().get("file", "")).begins_with("res://art/station/lobby/"),
			"e a placa dele no cômodo continua na roupa do lobby")
		hud.close_panel()
		await _frames(3)
	_tree.unload_current_scene()
	await _tree.process_frame
	Tips.enabled = tips


## As poses da Estação e do acampamento do herói (arquivos fora do manifesto da luta).
func _extra_files(hero_id: String) -> Array:
	var out: Array = []
	var poses: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/station_poses.json"))
	for kind in ["seat", "sleep", "work"]:
		if poses.has(hero_id + "_" + kind):
			out.append(String(poses[hero_id + "_" + kind].file))
	var camp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/camp_poses.json"))
	for kind in camp.get("heroes", {}).get(hero_id, {}):
		out.append(String(camp.heroes[hero_id][kind].file))
	return out


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
