## A parte segura do enxugamento do HUD (#56): na luta, o registro fica escondido (a cada lance só a última linha por um
## instante; a tecla do registro abre e fecha) e a dica da habilidade não abre sozinha quando a vez começa (abre com o
## mouse em cima ou quando o jogador anda o foco); na exploração, a dica das teclas é só da primeira jornada.
extends RefCounted

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var real_scale := Engine.time_scale
	var real_keys: bool = AHUiStyle.using_keys
	Campaign.save_dir = "user://test-hud-quiet-%d" % Time.get_ticks_usec()
	var tips: bool = Tips.enabled
	Tips.enabled = false
	await _fight()
	Engine.time_scale = real_scale
	AHUiStyle.using_keys = real_keys
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


func _fight() -> void:
	Campaign.state = Campaign.create_initial(6)
	AHJourneyRules.start_expedition(Campaign.state, "fase_1", 4242)
	GameFlow.change_to("street", {}, false)
	var street = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			street = _tree.current_scene
			break
	if not t.check(street != null, "a rua abre"):
		return
	# A dica das teclas: na primeira jornada sim; depois da primeira volta, não.
	await _tree.process_frame
	t.check(AHExplorationHud.first_journey() and street.exploration_hud._hint.visible or Settings.touch_visible(),
		"a dica das teclas na primeira jornada")
	Campaign.state.station.cycle_number = 1
	await _tree.process_frame
	t.check(not AHExplorationHud.first_journey() and not street.exploration_hud._hint.visible, "e não depois da primeira volta")
	Campaign.state.station.cycle_number = 0
	street.corridor.debug_next_fight()
	for i in 10:
		await _tree.process_frame
	street.corridor._start_fight(Campaign.state.session.expedition.corridor.index, true)
	var arena: AHCombatArena = street._arena
	var hud: AHCombatHud = arena.hud
	AHUiStyle.using_keys = true
	for i in 900:
		if hud != null and hud.waiting:
			break
		await _tree.process_frame
	if not t.check(hud.waiting, "a vez do jogador chega"):
		return
	await _tree.process_frame
	await _tree.process_frame
	# A dica não abre sozinha com o foco que a vez põe, nem para quem joga pelo teclado.
	t.check(not hud._tip.visible, "a dica não abre sozinha quando a vez começa")
	var card: Control = hud._abilities.get_child(1)
	card.mouse_entered.emit()
	t.check(hud._tip.visible, "abre com o mouse em cima")
	card.mouse_exited.emit()
	t.check(not hud._tip.visible, "e fecha quando ele sai")
	await _press("ui_right")
	t.check(hud._tip.visible, "e abre quando o jogador anda o foco")
	# O registro: escondido; o lance mostra só a última linha por um instante.
	var lines: Array = hud.session.state.combat_log
	t.check(not hud._log_open, "o registro começa fechado")
	hud.session.state.combat_log.append("Linha de teste do registro.")
	hud.refresh()
	t.check(hud._log_panel.visible and hud._log.text == "Linha de teste do registro.", "o lance mostra só a última linha")
	Engine.time_scale = 4.0
	await _tree.create_timer(AHCombatHud.LOG_FLASH + 0.8).timeout
	Engine.time_scale = 1.0
	t.check(not hud._log_panel.visible, "e some depois de %.0f s" % AHCombatHud.LOG_FLASH)
	await _press("combat_log")
	t.check(hud._log_open and hud._log_panel.visible and hud._log.text.count("\n") >= mini(lines.size(), 6) - 1, "a tecla do registro abre as últimas linhas")
	await _press("combat_log")
	t.check(not hud._log_open and not hud._log_panel.visible, "e fecha")
	# A tecla do registro troca nas Opções como as outras (trocar outra para L não deixa duas ações na mesma tecla).
	t.check(Settings.REMAPPABLE.has("combat_log") and AHOptionsPanel.CONTROLS.any(func(c): return c[0] == "combat_log"),
		"o registro está nas teclas das Opções")
	# A Mochila fechada pelo teclado devolve o foco à carta sem abrir a dica.
	hud._hide_tip()
	await _press("inventory")
	await _press("menu")
	for i in 3:
		await _tree.process_frame
	t.check(hud._bag == null and not hud._tip.visible, "a Mochila fechada não abre a dica")
	# Luta nova na mesma rua (o HUD é o mesmo): o registro aberto e a contagem da anterior não passam para ela.
	await _press("combat_log")
	hud._log.text = "Texto da luta anterior."
	hud.open(hud.session)
	var log: Array = hud.session.state.combat_log
	t.check(not hud._log_open and hud._log_seen == log.size() and hud._log.text == log[-1],
		"a luta nova começa com o registro fechado, mostrando a linha dela (não a da anterior)")
	hud.session.state.combat_log.append("Primeiro lance da luta nova.")
	hud.refresh()
	t.check(hud._log_panel.visible and hud._log.text == "Primeiro lance da luta nova.", "e o lance dela aparece")


func _press(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		_tree.root.push_input(event)
		await _tree.process_frame
	await _tree.process_frame
