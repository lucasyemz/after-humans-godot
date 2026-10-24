## A escolha do alvo pelo personagem inteiro (#57): o clique no meio do corpo de um inimigo (longe do nome) escolhe e
## um segundo clique no mesmo usa a habilidade nele; os botões com o nome não existem mais; as luzes dizem quem é quem
## (o alvo válido na cor do lado, o apontado mais forte com o ALVO, o herói da vez dourado, quem não pode ser alvo
## escurecido); o teclado continua: as setas andam entre os alvos e Enter usa.
extends RefCounted

var t
var _tree: SceneTree
var _command: Dictionary = {}


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-target-pick-%d" % Time.get_ticks_usec()
	var tips: bool = Tips.enabled
	Tips.enabled = false
	await _fight()
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
	street.corridor.debug_next_fight()
	for i in 10:
		await _tree.process_frame
	street.corridor._start_fight(Campaign.state.session.expedition.corridor.index, true)
	var arena: AHCombatArena = street._arena
	for i in 900:
		if arena.hud != null and arena.hud.waiting:
			break
		await _tree.process_frame
	var hud: AHCombatHud = arena.hud
	if not t.check(hud.waiting, "a vez do jogador chega"):
		return
	hud.command_chosen.connect(func(command): _command = command)
	var options: Array = hud._options.filter(func(o): return o.enemy_side and o.targets.size() >= 2 and o.get("enabled", true))
	if not t.check(not options.is_empty(), "há uma habilidade com dois alvos inimigos"):
		return
	var option: Dictionary = options[0]
	hud._on_ability(option)
	await _tree.process_frame
	await _tree.process_frame
	t.check(hud._markers.all(func(m): return not String(m.text).begins_with("▼")), "sem os botões com o nome")
	# As luzes: o herói da vez dourado, os alvos na cor dos inimigos, os aliados escurecidos.
	var actor: AHSpriteCard = arena.cards[hud._actor_id]
	t.check(actor.highlight() != Color.BLACK and not actor.dimmed(), "o herói da vez ganha o dourado")
	var targets: Array = hud._markers.filter(func(m): return m.has_meta("card"))
	t.check(targets.size() >= 2 and targets.all(func(m): return m.get_meta("card").highlight() != Color.BLACK), "os alvos válidos acendem")
	var others: Array = arena.session.state.player_team.filter(func(u): return u.id != hud._actor_id and AHCombatEngine.alive_any(u))
	t.check(others.all(func(u): return arena.cards[u.id].dimmed()), "quem não pode ser alvo fica escurecido")
	# O clique no meio do corpo do segundo alvo (longe da placa com o nome, que fica sob os pés).
	var second: Button = targets[1]
	var second_rank: int = int(second.get_meta("rank"))
	var card: AHSpriteCard = second.get_meta("card")
	var camera := hud.get_viewport().get_camera_3d()
	var middle := camera.unproject_position(card.global_position + Vector3(0, card.body_height * 0.55, 0))
	var plate: Control = hud._unit_bars.get(second.get_meta("unit_id"))
	t.check(plate == null or not Rect2(plate.global_position, plate.size).has_point(middle), "o clique fica longe da placa com o nome")
	await _click(middle)
	t.check(_command.is_empty(), "o primeiro clique escolhe sem usar")
	t.equal(hud._picked_rank, second_rank, "o clicado fica escolhido")
	t.check(hud._target_label.visible and hud._target_label.get_meta("card") == card, "o ALVO aparece acima dele")
	t.check(card.highlight().v > targets[0].get_meta("card").highlight().v, "a luz do apontado é mais forte que a dos outros alvos")
	await _click(middle)
	t.check(_command.get("kind", "") == "ability" and _command.get("rank", -1) == second_rank and _command.get("ability_id", "") == option.id,
		"o segundo clique no mesmo usa a habilidade nele %s" % [_command])
	t.check(actor.highlight() == Color.BLACK or not hud._markers.is_empty(), "as luzes apagam depois")
	# O teclado: na vez seguinte, as setas andam entre os alvos e Enter usa.
	_command = {}
	for i in 1200:
		if hud.waiting and hud._choosing == "":
			break
		await _tree.process_frame
	if not t.check(hud.waiting, "a vez seguinte chega"):
		return
	options = hud._options.filter(func(o): return o.enemy_side and o.targets.size() >= 2 and o.get("enabled", true))
	if options.is_empty():
		return
	hud._on_ability(options[0])
	await _tree.process_frame
	await _tree.process_frame
	var first_rank: int = int(hud._markers[0].get_meta("rank"))
	t.equal(hud._picked_rank, first_rank, "o foco começa no primeiro alvo e o escolhe")
	var next_rank: int = int(hud._markers[1].get_meta("rank"))
	await _press("ui_right")
	t.equal(hud._picked_rank, next_rank, "→ escolhe o próximo")
	await _press("ui_accept")
	t.equal(_command.get("rank", -1), next_rank, "Enter usa no escolhido %s" % [_command])


## Um clique de verdade, em coordenadas da tela do jogo (a janela sem tela do teste tem outra escala: a posição passa
## pela transformação final da viewport).
func _click(at: Vector2) -> void:
	at = _tree.root.get_final_transform() * at
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		_tree.root.push_input(event)
		await _tree.process_frame
	await _tree.process_frame


func _press(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		_tree.root.push_input(event)
		await _tree.process_frame
	await _tree.process_frame
