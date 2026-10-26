## Os efeitos de impacto e de estados da luta (#84, arte da #41).
## - O manifesto: as onze folhas com os quadros, a âncora, o FPS e o loop de docs/design/combat-effects.md, e a textura do
##   tamanho dos quadros.
## - O evento certo toca o efeito certo: faíscas no robô, poeira nos outros, o crítico, a cura, o bloqueio e a esquiva;
##   o efeito curto some sozinho, e com "Reduzir efeitos" é um quadro parado e curto.
## - Os estados em loop enquanto duram (o sangramento do robô é o óleo), sem nenhum com "Reduzir efeitos" e nenhum
##   depois da luta. O modo daltonismo não muda a cor dos efeitos.
extends RefCounted

const SHEETS := {"hit_metal": [6, [128, 128], 12, false], "hit_dust": [6, [128, 208], 12, false],
	"critical": [6, [128, 128], 12, false], "healing": [6, [128, 128], 12, false], "block": [6, [128, 128], 12, false],
	"dodge": [6, [128, 192], 12, false], "status_bleeding_organic": [4, [128, 128], 4, true],
	"status_bleeding_robot": [4, [128, 128], 4, true], "status_poison": [4, [128, 128], 4, true],
	"status_stunned": [4, [128, 128], 4, true], "status_marked": [4, [128, 128], 4, true]}

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_manifest()
	_mapping()
	var real_settings: Dictionary = Campaign.state.get("settings", {}).duplicate(true)
	if not Campaign.state.has("settings"):
		Campaign.state.settings = {}
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-combat-effects-%d" % Time.get_ticks_usec()
	var tips: bool = Tips.enabled
	Tips.enabled = false
	await _in_street()
	Tips.enabled = tips
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state
	Campaign.state.settings = real_settings


func _manifest() -> void:
	var effects := AHCombatEffects.new()
	t.equal(JSON.parse_string(FileAccess.get_file_as_string(AHCombatEffects.MANIFEST)).effects.size(), SHEETS.size(), "as onze folhas da #41")
	for name in SHEETS:
		var sheet: Array = SHEETS[name]
		var entry := effects.entry(name)
		if not t.check(not entry.is_empty() and ResourceLoader.exists(entry.file), "%s existe" % name):
			continue
		var texture: Texture2D = load(entry.file)
		t.check(entry.frames.size() == sheet[0] and texture.get_width() == 256 * sheet[0] and texture.get_height() == 256,
			"%s: %d quadros de 256 px" % [name, sheet[0]])
		t.check(entry.anchor.map(func(v): return int(v)) == sheet[1] and int(entry.fps) == sheet[2] and entry.loop == sheet[3], "%s: a âncora, o FPS e o loop do documento" % name)
	t.check(not DirAccess.get_files_at("res://art/combat/effects").has("hit_metal.png"), "os PNG de origem saíram (WebP no lugar)")


func _mapping() -> void:
	var E := AHCombat.EventType
	t.equal(AHCombatEffects.for_event(E.DAMAGE, false, true), "hit_metal", "o acerto no robô: faíscas")
	t.equal(AHCombatEffects.for_event(E.DAMAGE, false, false), "hit_dust", "o acerto nos outros: poeira")
	t.equal(AHCombatEffects.for_event(E.DAMAGE, true, true), "critical", "o crítico")
	t.equal(AHCombatEffects.for_event(E.HEAL, false, false), "healing", "a cura")
	t.equal(AHCombatEffects.for_event(E.BLOCK, false, false), "block", "o bloqueio")
	t.equal(AHCombatEffects.for_event(E.DODGE, false, false), "dodge", "a esquiva")
	t.equal(AHCombatEffects.for_event(E.INSTINCT, false, false), "", "o instinto não tem efeito")
	var unit := AHCombat.Unit.new()
	unit.hp = 5
	unit.bleed.duration = 2
	unit.blight.duration = 1
	unit.stun_turns = 1
	unit.mark_duration = 2
	t.equal(AHCombatEffects.states_of(unit, false), {"bleeding": "status_bleeding_organic", "poison": "status_poison",
		"stunned": "status_stunned", "marked": "status_marked"}, "os quatro estados em loop")
	t.equal(AHCombatEffects.states_of(unit, true).bleeding, "status_bleeding_robot", "o sangramento do robô é o óleo")
	unit.hp = 0
	t.equal(AHCombatEffects.states_of(unit, false), {}, "quem caiu não tem loop")


## Numa luta de verdade na rua: cada evento no alvo, os loops dos estados e o fim da luta.
func _in_street() -> void:
	Campaign.state = Campaign.create_initial(6)
	Campaign.state.settings.reduced_environment_effects = false
	AHJourneyRules.start_expedition(Campaign.state, "fase_1", 4242)
	GameFlow.change_to("street", {}, false)
	var settled := false
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			settled = true
			break
	if not t.check(settled, "a rua abre"):
		return
	var street = _tree.current_scene
	street.corridor.debug_next_fight()
	for i in 10:
		await _tree.process_frame
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
	arena.auto_battle = true
	var enemy: AHCombat.Unit = arena.session.state.enemy_team[0]
	var hero: AHCombat.Unit = arena.session.state.player_team[0]
	var other: AHCombat.Unit = arena.session.state.player_team[1]
	var enemy_card: AHSpriteCard = arena.cards[enemy.id]
	var hero_card: AHSpriteCard = arena.cards[hero.id]
	var E := AHCombat.EventType
	var hit := enemy_card.position.x - 1.0
	# O acerto no robô e no herói, a cura, o bloqueio e a esquiva: cada um com o seu, no alvo.
	arena._show_events([_event(E.DAMAGE, enemy.id, 1), _event(E.DAMAGE, hero.id, 1)], hit)
	t.equal(_effects(enemy_card), ["hit_metal"], "o acerto no robô toca as faíscas nele")
	t.equal(_effects(hero_card), ["hit_dust"], "e no herói, a poeira")
	await _until(func(): return _effects(enemy_card).is_empty(), 2.0)
	t.check(_effects(enemy_card).is_empty(), "o efeito curto some sozinho")
	var crit := _event(E.CRIT, enemy.id, 0)
	crit.critical_roll = true
	arena._show_events([crit, _event(E.DAMAGE, enemy.id, 1), _event(E.HEAL, hero.id, 1)], hit)
	t.equal(_effects(enemy_card), ["critical"], "o crítico troca as faíscas pelo corte")
	t.equal(_effects(hero_card), ["healing"], "a cura")
	var node: AHSpriteCard = enemy_card.get_children().filter(func(n): return n.is_in_group("combat_effect"))[0]
	t.check(node.global_position.y > enemy_card.global_position.y + enemy_card.body_height * 0.3, "no tronco do alvo")
	var camera := street.get_viewport().get_camera_3d()
	var px: float = node.body_height / AHCombatEffects.meters(1080.0, enemy_card, camera) * 1080.0
	var size: Dictionary = arena.effects.layout("critical")
	t.check(is_equal_approx(node.body_height, maxf(enemy_card.body_height * float(size.body), AHCombatEffects.meters(float(size.min_px), enemy_card, camera))),
		"no tamanho de data/presentation (%.0f px: a fração do corpo, sem passar abaixo do mínimo)" % px)
	t.check(px >= float(size.min_px) - 1.0, "e pelo menos o mínimo na tela")
	await _until(func(): return _effects(enemy_card).is_empty() and _effects(hero_card).is_empty(), 2.0)
	# Um efeito por alvo: o golpe bloqueado (a blindagem consumida e o bloqueio) mostra só o escudo.
	arena._show_events([_event(E.BLOCK, other.id, 0), _event(E.BLOCK, other.id, 0), _event(E.DAMAGE, other.id, 1)], hit)
	t.equal(_effects(arena.cards[other.id]), ["block"], "o golpe bloqueado: só o escudo, no lugar do acerto")
	await _until(func(): return _effects(arena.cards[other.id]).is_empty(), 2.0)
	# Sem golpe, sem efeito de golpe: o bloqueio ganho, o sangramento da vez e o dano em quem age.
	arena._show_events([_event(E.BLOCK, other.id, 0)], hit)
	arena._show_events([_event(E.DAMAGE, hero.id, 1)])
	arena._show_events([_event(E.DAMAGE, enemy.id, 1)], hit, enemy.id)
	t.equal(_effects(arena.cards[other.id]) + _effects(hero_card) + _effects(enemy_card), [], "o bloqueio ganho, o sangramento da vez e o dano em quem age não tocam efeito")
	arena._show_events([_event(E.DODGE, other.id, 0)], hit)
	var dodge: Array = arena.cards[other.id].get_children().filter(func(n): return n.is_in_group("combat_effect"))
	t.check(dodge.size() == 1 and dodge[0].position.y < 0.1, "a esquiva nos pés")
	# Reduzir efeitos: um quadro parado e curto.
	await _until(func(): return _effects(arena.cards[other.id]).is_empty(), 2.0)
	Campaign.state.settings.reduced_environment_effects = true
	arena._show_events([_event(E.DAMAGE, enemy.id, 1)], hit)
	var still: Array = enemy_card.get_children().filter(func(n): return n.is_in_group("combat_effect"))
	t.check(still.size() == 1 and still[0]._art.frames.size() == 1, "com Reduzir efeitos, um quadro parado")
	await _until(func(): return _effects(enemy_card).is_empty(), 1.0)
	t.check(_effects(enemy_card).is_empty(), "e curto")
	# Os estados: o loop enquanto dura, nada com Reduzir efeitos, e sai quando acaba.
	enemy.bleed.duration = 2
	enemy.mark_duration = 2
	hero.blight.duration = 2
	await _frames(2)
	t.equal(_states(enemy_card), [], "com Reduzir efeitos, sem loop de estado")
	Campaign.state.settings.reduced_environment_effects = false
	var colorblind: bool = Settings.colorblind
	Settings.colorblind = true
	await _frames(2)
	t.equal(_states(enemy_card), ["status_bleeding_robot", "status_marked"], "o robô sangra óleo e está marcado")
	t.equal(_states(hero_card), ["status_poison"], "o herói envenenado")
	var looping: Array = enemy_card.get_children().filter(func(n): return n.is_in_group("combat_state"))
	t.check(looping.all(func(n): return n._art.loop and n._tint == Color.WHITE), "em loop e sem recolorir no modo daltonismo")
	var marked = looping.filter(func(n): return n.get_meta("state") == "marked")
	t.check(not marked.is_empty() and marked[0].position.y > enemy_card.body_height * 0.85, "a marca na cabeça")
	Settings.colorblind = colorblind
	enemy.mark_duration = 0
	await _frames(2)
	t.equal(_states(enemy_card), ["status_bleeding_robot"], "a marca acabou, o loop dela sai")
	# A luta até o fim, com os estados ainda ativos: depois dela, nenhum loop na rua (nem na tela do resultado).
	hero.mark_duration = 99
	arena.speed = 8.0
	var ended := [false]
	arena.finished.connect(func(_r): ended[0] = true, CONNECT_ONE_SHOT)
	arena.hud.command_chosen.emit({"kind": "defend"})
	var limit := Time.get_ticks_msec() + 60000
	var during_result := false
	while not ended[0] and Time.get_ticks_msec() < limit:
		await _tree.process_frame
		if arena.hud._result.visible and not _all_states(arena).is_empty():
			during_result = true
	if t.check(ended[0], "a luta termina"):
		t.check(not during_result, "na tela do resultado, nenhum loop volta")
		await _frames(3)
		t.equal(_all_states(arena), [], "depois da luta, nenhum loop nos heróis nem na patrulha")


func _event(type: int, target: String, amount: int) -> AHCombat.Event:
	var event := AHCombat.Event.new()
	event.type = type
	event.target_unit_id = target
	event.amount = amount
	event.text = "-%d" % amount
	return event


func _effects(card: AHSpriteCard) -> Array:
	return card.get_children().filter(func(n): return n.is_in_group("combat_effect") and not n.is_queued_for_deletion()).map(func(n): return n.get_meta("effect"))


func _all_states(arena: AHCombatArena) -> Array:
	var out: Array = []
	for card in arena.cards.values():
		if is_instance_valid(card):
			out += _states(card)
	return out


func _states(card: AHSpriteCard) -> Array:
	var out: Array = card.get_children().filter(func(n): return n.is_in_group("combat_state") and not n.is_queued_for_deletion()).map(func(n): return n.get_meta("effect"))
	out.sort()
	return out


func _until(condition: Callable, seconds: float) -> void:
	var limit := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < limit:
		await _tree.process_frame


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
