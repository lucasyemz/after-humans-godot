## A formação na exploração e a câmera mais perto (#129):
## - a tecla FORMAÇÃO (ou o botão) abre a ordem nas plaquinhas; Interagir escolhe e troca, as setas andam, o clique
##   também troca; a ordem vale para a fila da rua, para a próxima luta (as posições 1 a 4) e fica no save;
## - não abre na luta, num evento, no acampamento nem com um painel aberto; com ela aberta, a equipe não anda;
## - a câmera da exploração usa os valores de street.EXPLORE_CAMERA: a equipe inteira na tela e os pés acima das
##   plaquinhas da equipe, na rua e num cenário.
extends RefCounted

const J := preload("res://scripts/flow/journey_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-formation-%d" % Time.get_ticks_usec()
	var tips: bool = Tips.enabled
	Tips.enabled = false
	_rules()
	_keys()
	await _formation()
	await _camera("fase_1")
	await _camera("fase_2")
	await _camera("fase_1", true)
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


func _rules() -> void:
	var c := Campaign.create_initial(50)
	J.start_expedition(c, "fase_1", 50)
	var team: Array = c.session.expedition.team.duplicate()
	t.check(J.swap_team(c, team[0], team[2]), "na rua, dois trocam de lugar")
	t.equal(c.session.expedition.team, [team[2], team[1], team[0], team[3]], "na ordem da equipe")
	c.session.event = {"event_id": "x", "from_search": true, "resolution": "", "pending_hard_combat": false, "object": ""}
	t.check(not J.swap_team(c, team[0], team[2]), "num evento, não")
	c.session.event = null
	c.session.screen = "rest"
	t.check(not J.swap_team(c, team[0], team[2]), "no acampamento, não")
	c.session.screen = "corridor"
	t.check(not J.swap_team(c, team[0], "ninguem"), "quem não está na equipe, não")


## Um save antigo com a tecla R trocada para outra ação: a formação (que nasce no R) fica com a tecla de fábrica da
## outra, a mesma troca do set_key, sem dividir a tecla com outra ação.
func _keys() -> void:
	var real_keys: Dictionary = Settings.keys.duplicate()
	Settings.keys = {"interact": KEY_R}
	Settings.apply_controls()
	var interact_default := KEY_E
	t.equal(Settings.primary_key("interact"), KEY_R, "a tecla salva vale")
	t.equal(Settings.primary_key("formation"), interact_default, "a formação fica com a tecla de fábrica do Interagir")
	var formation: int = Settings.primary_key("formation")
	var clash: Array = Settings.REMAPPABLE.filter(func(a): return a != "formation" and Settings.primary_key(a) == formation)
	t.equal(clash, [], "a tecla da formação não fica em outra ação")
	Settings.keys = real_keys
	Settings.apply_controls()
	t.equal(Settings.primary_key("formation"), KEY_R, "sem o save antigo, a formação volta ao R")


func _open(c: Dictionary):
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("street", {}, false)
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			return _tree.current_scene
	return null


func _formation() -> void:
	var c := Campaign.create_initial(51)
	J.start_expedition(c, "fase_1", 51)
	var team: Array = c.session.expedition.team.duplicate()
	var street = await _open(c)
	if not t.check(street != null, "a rua abre"):
		return
	var corridor: AHStreetCorridor = street.corridor
	var hud: AHExplorationHud = street.exploration_hud
	# Com uma dica aberta, a formação não abre por cima dela (a tecla é da dica).
	Tips.enabled = true
	var seen_explore: bool = Tips._seen.has("explore")
	Tips._seen.erase("explore")
	Tips.show_tip("explore")
	t.check(Tips.showing() and not corridor.can_open_formation(), "com uma dica aberta, a formação não abre")
	Tips.dismiss()
	Tips.enabled = false
	if seen_explore:
		Tips._seen["explore"] = true
	t.check(hud._formation_button.is_visible_in_tree(), "o botão FORMAÇÃO no canto")
	await _action("formation")
	t.check(hud.formation_open() and corridor.blocking(), "a tecla da formação abre, e a equipe para")
	t.equal(hud._party_box.find_children("Rank", "", true, false).size(), team.size(), "cada plaquinha com a posição")
	var leader_x: float = street._leader.position.x
	await _action("move_right")
	await _frames(5)
	t.check(is_equal_approx(street._leader.position.x, leader_x), "as setas andam o cursor, não a equipe")
	t.equal(hud._formation_cursor, 1, "o cursor anda para o segundo")
	await _action("move_left")
	await _action("interact")
	t.equal(hud._formation_pick, 0, "Interagir escolhe o primeiro")
	await _action("move_right")
	await _action("interact")
	var expect: Array = [team[1], team[0], team[2], team[3]]
	t.equal(Campaign.state.session.expedition.team, expect, "o segundo troca com ele")
	t.equal(street.party_ids, expect, "a fila da rua na ordem nova")
	t.equal(street._heroes[0].art().get("file", ""), AHCombatArena.hero_art_of(team[1]).idle.file, "e a placa da frente é a do novo líder")
	var saved = Campaign.read_file(Campaign.primary_path())
	t.equal(saved.session.expedition.team, expect, "a ordem fica no save")
	# O clique em duas plaquinhas também troca.
	var mates: Array = hud._party_box.get_children()
	_click(hud, mates[2])
	_click(hud, mates[3])
	await _frames(2)
	expect = [team[1], team[0], team[3], team[2]]
	t.equal(Campaign.state.session.expedition.team, expect, "o clique em duas troca as duas")
	await _action("formation")
	t.check(not hud.formation_open() and not corridor.blocking(), "a tecla da formação fecha")
	# A próxima luta nas posições novas.
	street.corridor.debug_next_fight()
	await _frames(10)
	t.check(not corridor.can_open_formation() or not street._arena.active, "antes da luta")
	corridor._start_fight(Campaign.state.session.expedition.corridor.index, true)
	var arena: AHCombatArena = street._arena
	if not t.check(await _until(func(): return arena.hud != null and arena.hud.waiting, 20.0), "a luta começa"):
		return
	var ranks: Array = []
	for hero_id in expect:
		var unit = arena.session.state.player_team.filter(func(u): return u.hero_id == hero_id)
		ranks.append(int(unit[0].rank) if not unit.is_empty() else -1)
	t.equal(ranks, [1, 2, 3, 4], "a próxima luta com as posições da formação")
	t.check(not corridor.can_open_formation(), "na luta, a formação não abre")
	await _action("formation")
	t.check(not hud.formation_open(), "nem pela tecla")
	# O X do controle é também o Defender: na luta, ele defende (a formação não come o botão).
	if t.check(arena.hud.waiting, "a luta espera o comando"):
		for pressed in [true, false]:
			var pad := InputEventJoypadButton.new()
			pad.button_index = JOY_BUTTON_X
			pad.pressed = pressed
			Input.parse_input_event(pad)
			await _frames(2)
		t.check(await _until(func(): return not arena.hud.waiting, 3.0), "na luta, o X do controle defende")
	for unit in arena.session.state.enemy_team:
		unit.hp = 1
	arena.auto_battle = true
	arena.speed = 8.0
	arena.hud.command_chosen.emit({"kind": "defend"})
	await _until(func(): return not arena.active, 30.0)
	await _until(func(): return not corridor.blocking(), 10.0)
	# Num evento ou com a Mochila aberta, não.
	Campaign.state.session.event = {"event_id": "busca_choro_porta", "from_search": true, "resolution": "", "pending_hard_combat": false, "object": ""}
	t.check(not corridor.can_open_formation(), "num evento, a formação não abre")
	Campaign.state.session.event = null
	hud.show_inventory()
	t.check(not corridor.can_open_formation(), "com a Mochila aberta, não")
	hud.close_modal()
	# O clique em MOCHILA ou MENU com a formação aberta fecha a formação antes de abrir o painel.
	for button in [hud._bag_button, hud._menu_button]:
		await _action("formation")
		t.check(hud.formation_open(), "a formação abre de novo")
		button.pressed.emit()
		await _frames(3)
		t.check(not hud.formation_open() and hud.modal_open(), "o clique em %s fecha a formação e abre o painel" % button.name)
		hud.close_modal()
		await _frames(2)


## A câmera da exploração: os valores num lugar só, a equipe inteira na tela e os pés acima das plaquinhas.
func _camera(phase_id: String, house: bool = false) -> void:
	var c := Campaign.create_initial(52)
	c.completed_phases = ["fase_1"]
	J.start_expedition(c, phase_id, 52)
	var street = await _open(c)
	if not t.check(street != null, "%s abre" % phase_id):
		return
	if house:
		# Dentro da primeira loja aberta, na entrada (a fila ainda atrás do líder, perto da parede).
		var route: Dictionary = Campaign.state.session.expedition.corridor
		var site: int = route.sites.map(func(s): return not s.locked).find(true)
		route.index = int(route.sites[site].step)
		for i in route.index:
			route.steps[i].resolved = true
		route.sites[site].has_enemy = false
		await street.corridor._enter_house(site)
		phase_id += " (dentro da loja)"
	await _frames(30)
	var camera: Camera3D = street.get_viewport().get_camera_3d()
	var key := "indoor" if house else ("street" if street.scenario == null else "scenario")
	var spec: Dictionary = street.EXPLORE_CAMERA[key]
	var to_leader := camera.global_position.distance_to(street._leader.global_position)
	t.check(to_leader < float(spec.distance) + 3.0, "%s: a câmera a uns %.1f m da equipe (antes, 18,5 ou 19)" % [phase_id, to_leader])
	var plaques: float = street.exploration_hud._party_box.get_global_rect().position.y
	var inside := true
	var feet_ok := true
	for card in street._heroes:
		var r := AHCampHud.body_rect(camera, card)
		inside = inside and r.position.y >= 0.0 and r.position.x >= 0.0 and r.end.x <= 1920.0
		feet_ok = feet_ok and r.end.y < plaques
	t.check(inside, "%s: a equipe inteira na tela" % phase_id)
	t.check(feet_ok, "%s: os pés acima das plaquinhas da equipe" % phase_id)


func _click(hud: AHExplorationHud, mate: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	mate.gui_input.emit(event)


func _action(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)


func _until(condition: Callable, seconds: float) -> bool:
	var limit := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > limit:
			return false
		await _tree.process_frame
	return true


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
