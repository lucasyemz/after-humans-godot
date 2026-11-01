## As duas poses paradas (#221): a de exploração (idle, armas guardadas) e a de combate (combat_idle, armas na mão).
## - nos dados: cada herói com combat_idle tem o arquivo, a mesma tela e a mesma âncora no pé do idle; a skin Bento Ronda
##   tem a guarda dela, e a skin sem guarda luta no parado dela;
## - na luta de verdade: ao entrar, cada fundador passa para a guarda; ao vencer, a fila volta à pose de exploração.
extends RefCounted

const FOUNDERS := ["hero_cao_bento", "hero_gato_nick", "hero_sapo_iris", "hero_coruja_vespera"]

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_data()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-stances-%d" % Time.get_ticks_usec()
	await _fight()
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _data() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AHCombatArena.ART_MANIFEST))
	for hero_id in FOUNDERS:
		var entry: Dictionary = manifest.heroes[hero_id]
		if not t.check(entry.has("combat_idle"), "%s tem a pose de combate" % hero_id):
			continue
		var combat: Dictionary = entry.combat_idle
		t.check(ResourceLoader.exists(combat.file), "%s: o arquivo da guarda existe" % hero_id)
		t.equal(combat.canvas, entry.idle.canvas, "%s: a mesma tela do idle" % hero_id)
		t.equal(combat.anchor, entry.idle.anchor, "%s: a mesma âncora no pé do idle" % hero_id)
		t.check(combat.file != entry.idle.file, "%s: a guarda é outra imagem" % hero_id)
		var texture: Texture2D = load(combat.file)
		var idle: Texture2D = load(entry.idle.file)
		t.check(texture != null and texture.get_size() == idle.get_size(), "%s: a textura da guarda com o tamanho da do idle" % hero_id)
	# A skin Bento Ronda: a guarda dela, na pasta dela.
	var watch := AHSkins.dress(AHCombatArena.art_entry(manifest.heroes, "hero_cao_bento"), "bento_watch")
	t.check(String(watch.get("combat_idle", {}).get("file", "")).begins_with("res://art/skins/bento/watch/"), "a skin Bento Ronda luta na guarda dela")
	t.check(not AHSkins.missing("bento_watch", manifest.heroes.hero_cao_bento).has("combat_idle.webp"), "e a guarda não falta na skin")
	# Uma skin sem guarda (a pasta só com o parado) luta no parado dela, nunca na guarda da roupa padrão.
	var plain: Dictionary = manifest.heroes.hero_cao_bento.duplicate(true)
	plain.combat_idle.file = "res://art/combat/heroes/bento/combat_idle_que_nao_existe.webp"
	AHSkins.forget()
	var dressed := AHSkins.dress(plain, "bento_watch")
	t.check(not dressed.has("combat_idle"), "a skin sem a guarda dela fica no parado dela")
	AHSkins.forget()


func _fight() -> void:
	Campaign.state = Campaign.create_initial(6)
	AHJourneyRules.start_expedition(Campaign.state, "fase_1", 4242)
	GameFlow.change_to("street", {}, false)
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			break
	var street = _tree.current_scene
	# Na rua, a pose de exploração.
	t.check(_all_show(street, false), "na rua, a fila está na pose de exploração")
	street.corridor.debug_next_fight()
	await _frames(10)
	var route: Dictionary = Campaign.state.session.expedition.corridor
	if not t.check(street.corridor.guards.has(route.index), "há patrulha para a luta"):
		return
	street.corridor._start_fight(route.index, true)
	var arena: AHCombatArena = street._arena
	for i in 900:
		if arena.hud != null and arena.hud.waiting:
			break
		await _tree.process_frame
	if not t.check(arena.hud.waiting, "a vez do jogador chega"):
		return
	t.check(_all_show(street, true), "na luta, cada fundador está na guarda")
	# A vitória: a fila volta à pose de exploração.
	for unit in arena.session.state.enemy_team:
		unit.hp = 0
	arena.hud.command_chosen.emit({"kind": "defend"})
	for i in 1800:
		if not arena.active:
			break
		await _tree.process_frame
	await _frames(10)
	t.check(not arena.active, "a luta termina")
	t.check(_all_show(street, false), "depois da luta, a fila volta à pose de exploração")


## A fila mostra a guarda (combat true) ou o parado de exploração de cada herói.
func _all_show(street, combat: bool) -> bool:
	var manifest: Dictionary = street._combat_art
	for index in street.party_ids.size():
		var hero_id: String = street.party_ids[index]
		var entry: Dictionary = manifest.heroes.get(hero_id, {})
		if entry.is_empty():
			continue
		var wanted: String = String(entry.combat_idle.file) if combat and entry.has("combat_idle") else String(entry.idle.file)
		var shown: String = String(street._heroes[index]._art.get("file", ""))
		if shown != wanted:
			push_warning("%s mostra %s, esperado %s" % [hero_id, shown, wanted])
			return false
	return true


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
