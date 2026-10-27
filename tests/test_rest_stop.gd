## A ferramenta à vista, a pose de cuidar de volta e a parada que vira acampamento (#143):
## - a ferramenta ganha dá o aviso (o ícone, o nome e o que ela faz), que sai com uma tecla; a MOCHILA ganha o selo NOVO
##   até abrir, e lá dentro a ferramenta nova abre escolhida, com o selo e a descrição;
## - o curativo na luta mostra a pose de usar item no herói; no acampamento, comer e curar também;
## - a parada de descanso pergunta Acampar aqui, Seguir em frente ou Voltar, com o estado da equipe; acampar abre o
##   acampamento ali (na rua e no cenário), o jogo reaberto no meio dele volta à fogueira, e levantar conta como o
##   acampamento da fase (a casa do acampamento não acampa de novo).
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")
const J := preload("res://scripts/flow/journey_rules.gd")
const C := preload("res://scripts/flow/exploration_care.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-rest-stop-%d" % Time.get_ticks_usec()
	var tips: bool = Tips.enabled
	Tips.enabled = false
	_rules()
	await _tool_notice()
	await _combat_pose()
	await _stop("fase_1", 31)
	await _stop("fase_2", 32)
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
	var c := Campaign.create_initial(30)
	J.start_expedition(c, "fase_1", 30)
	t.check(J.grant_tool(c, "lanterna"), "a lanterna chega")
	t.equal(c.new_tools, ["lanterna"], "e fica nova até a Mochila abrir")
	t.equal(c.tool_notices, ["lanterna"], "com o aviso pendente")
	t.check(not J.grant_tool(c, "lanterna"), "a mesma de novo não chega")
	t.equal(c.tool_notices.size(), 1, "nem repete o aviso")
	for tool in AHInventoryPanel.KNOWN_TOOLS:
		t.check(AHInventoryPanel.TOOL_TEXTS.has(tool), "%s diz o que faz" % tool)


## A rua da fase 1, aberta com a campanha c.
func _open(c: Dictionary):
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("street", {}, false)
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			return _tree.current_scene
	return null


func _tool_notice() -> void:
	var c := Campaign.create_initial(33)
	J.start_expedition(c, "fase_1", 33)
	var street = await _open(c)
	if not t.check(street != null, "a rua abre"):
		return
	var hud: AHExplorationHud = street.exploration_hud
	J.grant_tool(Campaign.state, "mascara")
	hud.refresh(Campaign.state)
	t.check(await _until(func(): return hud.tool_notice_shown(), 2.0), "a ferramenta ganha dá o aviso")
	var notice: Control = hud._tool_notice
	t.check(_has_text(notice, tr("Máscara com filtro")) and _has_text(notice, AHInventoryPanel.tool_text("mascara")),
		"com o nome e o que ela faz")
	t.check(Campaign.state.tool_notices.is_empty(), "o aviso sai da fila")
	t.check(hud._bag_new.visible, "a MOCHILA ganha o selo NOVO")
	t.check(hud._bag_new.get_global_rect().intersects(hud._bag_button.get_global_rect()), "no canto do botão")
	_press_key(KEY_A)
	await _frames(2)
	t.check(not hud.tool_notice_shown(), "uma tecla fecha o aviso")
	J.grant_tool(Campaign.state, "lanterna")
	t.check(await _until(func(): return hud.tool_notice_shown(), 2.0), "a próxima ferramenta dá o aviso dela")
	await _until(func(): return not hud.tool_notice_shown(), AHExplorationHud.TOOL_NOTICE_SECONDS + 2.0)
	t.check(not hud.tool_notice_shown(), "e ele some sozinho")
	hud.show_inventory()
	await _frames(3)
	var bag: AHInventoryPanel = hud._modal.find_children("", "AHInventoryPanel", true, false)[0]
	t.equal(bag.fresh, ["mascara", "lanterna"], "a Mochila sabe das duas novas")
	t.equal(bag.selected, "mascara", "e abre na primeira")
	t.equal(bag.find_children("New", "", true, false).size(), 2, "com o selo NOVO nas duas")
	t.check(_has_text(bag, AHInventoryPanel.tool_text("mascara")), "e a descrição dela")
	t.check(not hud._bag_new.visible and Campaign.state.new_tools.is_empty(), "aberta a Mochila, o selo do botão sai")
	hud.close_modal()
	await _frames(2)
	hud.show_inventory()
	await _frames(2)
	bag = hud._modal.find_children("", "AHInventoryPanel", true, false)[0]
	t.equal(bag.find_children("New", "", true, false).size(), 0, "na próxima vez, nada mais é novo")
	hud.close_modal()


func _combat_pose() -> void:
	var c := Campaign.create_initial(34)
	J.start_expedition(c, "fase_1", 34)
	c.inventory.bandages = 3
	var street = await _open(c)
	if not t.check(street != null, "a rua abre para a luta"):
		return
	street.corridor.debug_next_fight()
	await _frames(10)
	street.corridor._start_fight(Campaign.state.session.expedition.corridor.index, true)
	var arena: AHCombatArena = street._arena
	var hud: AHCombatHud = arena.hud
	if not t.check(await _until(func(): return hud != null and hud.waiting, 20.0), "a luta pede o comando"):
		return
	var actor: AHCombat.Unit = arena.session.current_actor()
	actor.hp = maxi(1, actor.max_hp - 10)
	var item: Dictionary = arena.hero_art(actor.hero_id).reactions.item
	hud.command_chosen.emit({"kind": "item", "item": C.BANDAGE})
	var posed := await _until(func(): return arena.cards[actor.id].art().get("file", "") == item.file, 3.0)
	t.check(posed, "o curativo na luta mostra a pose de usar item (%s)" % actor.display_name)
	t.check(await _until(func(): return arena.cards[actor.id].art().get("file", "") != item.file, 4.0), "e o herói volta ao de pé")
	for unit in arena.session.state.enemy_team:
		unit.hp = 1
	arena.auto_battle = true
	arena.speed = 8.0
	if hud.waiting:
		hud.command_chosen.emit({"kind": "defend"})
	await _until(func(): return not arena.active, 30.0)


## A parada de descanso da fase (fase_1: a Rua das Vitrines; fase_2: o Cais, um cenário).
func _stop(phase_id: String, seed_value: int) -> void:
	var c := Campaign.create_initial(seed_value)
	J.start_expedition(c, phase_id, seed_value)
	var team: Array = c.session.expedition.team
	S.hero(c, team[0]).hp = int(S.hero(c, team[0]).max_hp) - 9
	S.hero(c, team[0]).instinct = 60
	var route: Dictionary = c.session.expedition.corridor
	var rest: int = route.steps.map(func(s): return s.type).find("rest")
	if not t.check(rest > 0, "%s tem a parada de descanso" % phase_id):
		return
	for i in rest:
		route.steps[i].resolved = true
	route.index = rest - 1
	var street = await _open(c)
	if not t.check(street != null, "%s abre" % phase_id):
		return
	var corridor: AHStreetCorridor = street.corridor
	var hud: AHExplorationHud = street.exploration_hud
	# Sem a casa do acampamento na mesma parada (essa vira uma parada só, pela casa).
	for site in route.sites:
		if site.step == rest:
			site.camp_site = false
	corridor._enter_segment(corridor._segment_of(rest), corridor._step_x(rest, 0.5))
	var outcome := J.enter_step(Campaign.state, rest)
	corridor._announce(rest, outcome, true)
	await _frames(3)
	if not t.check(hud.modal_open(), "%s: a parada pergunta" % phase_id):
		return
	var options: Array = _buttons(hud._modal).map(func(b): return b.text.to_upper())
	t.equal(options, [tr("Acampar aqui").to_upper(), tr("Seguir em frente").to_upper(), tr("Voltar à Estação (metade do achado)").to_upper()],
		"%s: Acampar aqui, Seguir em frente ou Voltar" % phase_id)
	var hero = Campaign.hero(team[0])
	t.check(_has_text(hud._modal, "%d de" % _team_hp()) and _has_text(hud._modal, "%s (%d)" % [hero.display_name, 60]),
		"%s: o texto diz a vida da equipe e o instinto mais alto" % phase_id)
	t.check(_has_text(hud._modal, "%d de %d." % [J.food(Campaign.state), J.MAX_FOOD]), "%s: e a comida" % phase_id)
	_buttons(hud._modal)[0].pressed.emit()
	var camp: AHCampScene = corridor.camp
	if not t.check(await _until(func(): return camp.active and hud.camp_open(), 6.0), "%s: Acampar aqui abre o acampamento" % phase_id):
		return
	t.check(corridor.stop_camp != null and Campaign.state.session.screen == "rest", "%s: a fogueira acende na parada" % phase_id)
	var fire_x: float = corridor.stop_camp.camp_x
	t.check(fire_x - 3.6 >= street.walk_min.x - 0.5 and fire_x + 3.6 <= street.walk_max.x + 0.5, "%s: a fileira cabe na área de andar" % phase_id)
	for member in camp.members:
		var card: AHSpriteCard = member.card
		t.check(absf(card.position.x - fire_x) <= 3.4 and absf(card.position.y - corridor.stop_camp.floor_y) < 0.01,
			"%s: %s em volta da fogueira, no piso" % [phase_id, Campaign.hero(member.hero_id).display_name])
	await _frames(3)
	var camera: Camera3D = street.get_viewport().get_camera_3d()
	var on_screen := true
	for member in camp.members:
		var r := AHCampHud.body_rect(camera, member.card)
		on_screen = on_screen and Rect2(0, 0, 1920, 1080).encloses(r)
	t.check(on_screen, "%s: a câmera enquadra a equipe toda" % phase_id)
	# A pose de cuidar no acampamento.
	var hurt_id: String = team[0]
	var card: AHSpriteCard = camp.member_card(hurt_id)
	var seat := card.art()
	var item: Dictionary = AHCombatArena.hero_art_of(hurt_id).reactions.item
	corridor._camp_care(hurt_id, "bandage")
	t.equal(card.art().get("file", ""), item.file, "%s: o curativo no acampamento mostra a pose de cuidar" % phase_id)
	t.check(await _until(func(): return card.art() == seat, AHCampScene.CARE_POSE_SECONDS + 1.0), "%s: e o herói volta a sentar" % phase_id)
	# Reaberto no meio: a fogueira no mesmo lugar.
	var saved = Campaign.read_file(Campaign.primary_path())
	street = await _open(saved)
	if not t.check(street != null, "%s: reaberto no acampamento" % phase_id):
		return
	corridor = street.corridor
	t.check(corridor.camp.active and corridor.stop_camp != null and is_equal_approx(corridor.stop_camp.camp_x, fire_x),
		"%s: o jogo reaberto volta à fogueira da parada" % phase_id)
	await corridor._on_camp_leave()
	t.check(not corridor.camp.active and corridor.stop_camp == null and Campaign.state.session.screen == "corridor", "%s: levantar apaga a fogueira" % phase_id)
	t.check(J.camped(Campaign.state.session.expedition.corridor), "%s: e conta como o acampamento da fase" % phase_id)
	t.check(not J.can_camp_at_stop(Campaign.state), "%s: a parada não acampa de novo" % phase_id)


func _team_hp() -> int:
	var total := 0
	for hero in Campaign.state.roster:
		if Campaign.state.session.expedition.team.has(hero.id) and hero.alive:
			total += int(hero.hp)
	return total


func _buttons(root: Node) -> Array:
	return root.find_children("", "Button", true, false).filter(func(b): return b.is_visible_in_tree())


func _has_text(root: Node, part: String) -> bool:
	for node in root.find_children("", "Label", true, false):
		if String(node.text).contains(part):
			return true
	return false


func _press_key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)


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
