## O impacto dos golpes (#33): a pausa curta no acerto (e o tempo volta ao que era, inclusive acelerado), o tremor da
## câmera pelo dano (mais forte no crítico e na queda, nenhum com "Reduzir efeitos"), o clarão branco no alvo, o número
## maior no crítico e a dor de quem cai antes da queda. A 2x tudo encurta junto; o modo automático pula a pausa.
extends RefCounted

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_settings: Dictionary = Campaign.state.get("settings", {}).duplicate(true)
	if not Campaign.state.has("settings"):
		Campaign.state.settings = {}
	Campaign.state.settings.reduced_environment_effects = false
	_shake_rules()
	await _hitstop_rules()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-combat-impact-%d" % Time.get_ticks_usec()
	var tips: bool = Tips.enabled
	Tips.enabled = false
	await _in_street()
	Tips.enabled = tips
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state
	Campaign.state.settings = real_settings


## O tremor: cresce com o dano, o crítico treme mais, some sozinho e anda no dobro a 2x; com "Reduzir efeitos", nada.
func _shake_rules() -> void:
	var arena := AHCombatArena.new()
	arena._shake(0.05, false)
	var light := arena._shake_pixels
	arena._shake(0.5, false)
	var heavy := arena._shake_pixels
	arena._shake(0.5, true)
	var crit := arena._shake_pixels
	t.check(light >= AHCombatArena.SHAKE_MIN_PIXELS and light < heavy and heavy < crit, "o tremor cresce com o dano e o crítico treme mais (%.1f < %.1f < %.1f px)" % [light, heavy, crit])
	t.check(crit <= AHCombatArena.SHAKE_MAX_PIXELS * AHCombatArena.SHAKE_CRIT + 0.01, "e tem teto")
	arena._process(0.016)
	t.check(arena.camera_shake().length() > 0.0, "a câmera treme logo depois do acerto")
	for i in 30:
		arena._process(0.016)
	t.equal(arena.camera_shake(), Vector2.ZERO, "e para sozinha em %.2f s" % AHCombatArena.SHAKE_SECONDS)
	arena.speed = 2.0
	arena._shake(0.5, false)
	for i in 10:
		arena._process(0.016)
	t.equal(arena.camera_shake(), Vector2.ZERO, "a 2x o tremor dura a metade")
	Campaign.state.settings.reduced_environment_effects = true
	arena._shake(1.0, true)
	t.equal(arena.camera_shake(), Vector2.ZERO, "com Reduzir efeitos, a câmera não treme")
	Campaign.state.settings.reduced_environment_effects = false
	arena.free()


## A pausa: o tempo quase para e volta ao que era (inclusive o acelerado do teste da jornada); o automático pula.
func _hitstop_rules() -> void:
	var arena := AHCombatArena.new()
	_tree.root.add_child(arena)
	var real := Engine.time_scale
	Engine.time_scale = 3.0
	# Um quadro curto antes (o primeiro quadro depois de um trabalho longo tem um delta grande e venceria a pausa).
	await _tree.process_frame
	await _tree.process_frame
	var started := Time.get_ticks_msec()
	arena._hitstop(AHCombatArena.HITSTOP_SECONDS)
	t.check(is_equal_approx(Engine.time_scale, 3.0 * AHCombatArena.HITSTOP_TIME_SCALE), "na pausa o tempo quase para")
	await _until_time_back(3.0)
	var took := Time.get_ticks_msec() - started
	t.check(is_equal_approx(Engine.time_scale, 3.0), "e volta ao que era (3x)")
	t.check(took >= 50 and took < 1000, "a pausa dura uns %d ms de tempo real (%d)" % [int(AHCombatArena.HITSTOP_SECONDS * 1000), took])
	# A menor de três (com a máquina carregada um quadro pode levar muito): a 1x e a 2x.
	var slow := took
	for i in 2:
		slow = mini(slow, await _hitstop_ms(arena))
	arena.speed = 2.0
	var fast := 100000
	for i in 3:
		fast = mini(fast, await _hitstop_ms(arena))
	t.check(fast < slow, "a 2x a pausa encurta (%d ms < %d ms)" % [fast, slow])
	arena.auto_battle = true
	arena._hitstop(AHCombatArena.HITSTOP_SECONDS)
	t.check(is_equal_approx(Engine.time_scale, 3.0), "no modo automático não há pausa")
	arena.auto_battle = false
	arena._hitstop(1.0)
	arena.queue_free()
	await _tree.process_frame
	t.check(is_equal_approx(Engine.time_scale, 3.0), "a arena que sai no meio da pausa devolve o tempo")
	Engine.time_scale = real


## Numa luta de verdade na rua: o número do crítico maior, o clarão branco, a câmera tremendo e quem cai com a dor.
func _in_street() -> void:
	Campaign.state = Campaign.create_initial(6)
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
	var enemy: AHCombat.Unit = arena.session.state.enemy_team[0]
	var card: AHSpriteCard = arena.cards[enemy.id]
	var before := arena.get_children().filter(func(n): return n is Label3D).size()
	var crit := AHCombat.Event.new()
	crit.type = AHCombat.EventType.CRIT
	crit.text = "CRÍTICO!"
	crit.target_unit_id = enemy.id
	crit.critical_roll = true
	var hit := AHCombat.Event.new()
	hit.type = AHCombat.EventType.DAMAGE
	hit.text = "-%d" % enemy.max_hp
	hit.amount = enemy.max_hp
	hit.target_unit_id = enemy.id
	var hp := enemy.hp
	enemy.hp = 0
	arena._show_events([crit, hit], card.position.x - 1.0)
	var labels: Array = arena.get_children().filter(func(n): return n is Label3D and n.text == hit.text)
	t.check(not labels.is_empty() and labels[-1].font_size == AHCombatArena.CRIT_TEXT_SIZE, "o número do crítico sai maior")
	t.check(card._material.emission.is_equal_approx(Color.WHITE), "o alvo tem o clarão branco")
	t.check(card._art == arena.enemy_art(enemy.enemy_id).get("poses", {}).get("hurt", card._art) and card._art != arena.enemy_art(enemy.enemy_id).get("idle"),
		"quem cai sente o golpe antes da queda")
	t.check(Engine.time_scale < 0.5, "a pausa do acerto começa")
	await _tree.process_frame
	await _tree.process_frame
	t.check(street._camera.h_offset != 0.0 or street._camera.v_offset != 0.0, "a câmera treme")
	await _until_time_back(1.0)
	t.check(is_equal_approx(Engine.time_scale, 1.0), "o tempo volta depois da pausa")
	t.check(arena.get_children().filter(func(n): return n is Label3D).size() > before, "os números aparecem")
	enemy.hp = hp
	# A troca de fase do chefe (SOBRECARGA DO PORTEIRO) também é CRIT, mas o golpe não foi crítico.
	await _until_time_back(1.0)
	var phase := AHCombat.Event.new()
	phase.type = AHCombat.EventType.CRIT
	phase.text = "SOBRECARGA DO PORTEIRO!"
	phase.target_unit_id = enemy.id
	hit.amount = 3
	hit.text = "-3"
	arena._show_events([phase, hit], card.position.x - 1.0)
	labels = arena.get_children().filter(func(n): return n is Label3D and n.text == "-3")
	t.check(not labels.is_empty() and labels[-1].font_size == 64, "a troca de fase do chefe não deixa o golpe com cara de crítico")
	t.check(arena._shake_pixels < AHCombatArena.SHAKE_MAX_PIXELS, "nem com o tremor de crítico")
	await _until_time_back(1.0)
	Campaign.state.settings.reduced_environment_effects = true
	hit.amount = 1
	arena._show_events([hit], card.position.x - 1.0)
	t.check(not card._material.emission.is_equal_approx(Color.WHITE), "com Reduzir efeitos, sem clarão")
	t.equal(arena.camera_shake(), Vector2.ZERO, "e sem tremor")
	Campaign.state.settings.reduced_environment_effects = false
	arena.hud._clear_markers()


## Espera (em tempo real, até 2 s) a escala de tempo voltar a scale.
func _until_time_back(scale: float) -> void:
	var limit := Time.get_ticks_msec() + 2000
	while not is_equal_approx(Engine.time_scale, scale) and Time.get_ticks_msec() < limit:
		await _tree.process_frame


## Quanto uma pausa do acerto leva no relógio (ms).
func _hitstop_ms(arena: AHCombatArena) -> int:
	await _tree.process_frame
	await _tree.process_frame
	var started := Time.get_ticks_msec()
	arena._hitstop(AHCombatArena.HITSTOP_SECONDS)
	await _until_time_back(3.0)
	return Time.get_ticks_msec() - started
