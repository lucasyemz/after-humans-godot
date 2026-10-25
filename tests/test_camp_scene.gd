## O acampamento encenado (#77): a equipe em volta da fogueira, o herói escolhido pelo corpo ou pelas setas, Comer e
## Curativo com a resposta no herói, levantar acampamento e o jogo reaberto no meio dele.
## - As poses: os fundadores sentados no chão (#82) ou deitados (quem chegou com até um quarto da vida), os recrutas
##   com as da #80; o manifesto data/presentation/camp_poses.json tem o canvas, a âncora e a referência do idle.
## - As regras não mudam: comer dá +10% da vida e −5 de instinto, o curativo +8 de vida (os mesmos de antes).
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")
const J := preload("res://scripts/flow/journey_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-camp-%d" % Time.get_ticks_usec()
	var tips: bool = Tips.enabled
	Tips.enabled = false
	_manifest()
	await _camp()
	await _reopened()
	await _menu_in_camp()
	await _fades()
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


## O manifesto: as poses do contrato, com o canvas, a âncora e a referência do corpo do idle de cada um (a textura está
## na metade, como o idle; o AHSpriteCard aplica a razão), e cada arquivo existe.
func _manifest() -> void:
	var poses: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AHCampScene.POSES))
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AHCombatArena.ART_MANIFEST))
	t.equal(poses.heroes.size(), 4, "as poses dos quatro fundadores")
	t.equal(poses.recruits.size(), 4, "as poses das quatro variações de recruta")
	for hero_id in poses.heroes:
		var idle: Dictionary = art.heroes[hero_id].idle
		var seat: Dictionary = poses.heroes[hero_id].seat
		t.check(ResourceLoader.exists(seat.file) and ResourceLoader.exists(poses.heroes[hero_id].sleep.file), "%s: as poses existem" % hero_id)
		t.check(seat.canvas == idle.canvas and seat.anchor == idle.anchor and seat.body_reference_pixels == idle.body_reference_pixels,
			"%s: a sentada no chão com o canvas, a âncora e a referência do idle" % hero_id)
	for variant in poses.recruits:
		var idle: Dictionary = art.recruits[variant].idle
		for kind in ["seat", "sleep"]:
			var pose: Dictionary = poses.recruits[variant][kind]
			t.check(ResourceLoader.exists(pose.file) and pose.canvas == idle.canvas and pose.anchor == idle.anchor
				and pose.body_reference_pixels == idle.body_reference_pixels, "%s: %s com as medidas do idle" % [variant, kind])
	# O manifesto gerado bate com o contrato do Codex (o pedido do revisor do PR65): o mesmo payload show_art.
	var contract = JSON.parse_string(FileAccess.get_file_as_string("res://docs/design/camp/contract.json"))
	if t.check(contract is Dictionary, "o contrato do acampamento"):
		var same := true
		for pose in contract.poses:
			var entry: Dictionary = poses.heroes[pose.hero_id].seat if pose.has("hero_id") else poses.recruits[pose.recruit_id][pose.state]
			for field in pose.show_art:
				if entry.get(field) != pose.show_art[field]:
					same = false
		for review in contract.founder_sleep_review:
			for field in review.show_art:
				if poses.heroes[review.hero_id].sleep.get(field) != review.show_art[field]:
					same = false
		t.check(same, "camp_poses.json com o show_art do contrato (tools/build_camp_poses.py)")


## Uma expedição na fase 1 com a casa do acampamento à frente (sem guarda), a rua aberta e a equipe dentro dela.
func _street_at_camp(c: Dictionary):
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("street", {}, false)
	var street = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			street = _tree.current_scene
			break
	if street == null:
		return null
	var route: Dictionary = c.session.expedition.corridor
	var site: int = route.sites.map(func(s): return s.camp_site).find(true)
	if site < 0:
		return null
	route.index = route.sites[site].step
	for i in route.index + 1:
		route.steps[i].resolved = true
	route.sites[site].has_enemy = false
	await street.corridor._enter_house(site)
	return street


func _camp() -> void:
	var c: Dictionary = Campaign.create_initial(23)
	J.start_expedition(c, "fase_1", 23)
	var team: Array = c.session.expedition.team
	# A Véspera chega muito ferida (deita); o Bento e o Nick, feridos (sentam).
	S.hero(c, team[0]).hp = int(S.hero(c, team[0]).max_hp) - 12
	S.hero(c, team[1]).hp = int(S.hero(c, team[1]).max_hp) - 3
	var tired = S.hero(c, team.back())
	tired.hp = maxi(1, int(tired.max_hp) / 5)
	var street = await _street_at_camp(c)
	if not t.check(street != null, "a rua abre com a casa do acampamento"):
		return
	var corridor: AHStreetCorridor = street.corridor
	var hud: AHExplorationHud = street.exploration_hud
	await corridor._start_camp()
	var camp: AHCampScene = corridor.camp
	t.check(camp.active and hud.camp_open() and Campaign.state.session.screen == "rest", "acampar abre a cena e o HUD do acampamento")
	t.check(corridor.blocking(), "no acampamento, a equipe não anda")
	t.equal(camp.members.size(), team.size(), "a equipe inteira em volta da fogueira")
	var room: AHHouseRoom = corridor.room
	for member in camp.members:
		var card: AHSpriteCard = member.card
		var hero = Campaign.hero(member.hero_id)
		var lie: bool = hero.hp <= hero.max_hp * AHCampScene.LIE_DOWN_AT
		t.check(card._art.file.contains("_sleep") if lie else card._art.file.contains("_seat_floor"),
			"%s %s (%s)" % [hero.display_name, "deitado" if lie else "sentado no chão", card._art.file.get_file()])
		t.check(absf(card.position.x - room.camp_x) <= 2.9, "%s perto da fogueira" % hero.display_name)
		t.check(card.facing == (-1.0 if card.position.x > room.camp_x else 1.0), "%s virado para o fogo" % hero.display_name)
	# As áreas do clique (o corpo inteiro na tela) não se sobrepõem.
	await _frames(3)
	var camera: Camera3D = street.get_viewport().get_camera_3d()
	var rects: Array = hud.camp_hud.click_rects(camera).values()
	var apart := true
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].grow(-2).intersects(rects[j].grow(-2)):
				apart = false
	t.check(apart, "os corpos na tela não se sobrepõem (o clique é de um só): %s" % [rects])
	# A câmera no escolhido; as setas trocam de herói (com o fade curto entre as posições).
	t.equal(camp.selected, 0, "começa no primeiro da equipe")
	t.check(is_equal_approx(camp.focus_x, lerpf(room.camp_x, camp.members[0].card.position.x, AHCampScene.FOCUS_PULL)), "a câmera puxada para o escolhido")
	await _press("move_right")
	await _until(func(): return not camp.switching(), 3.0)
	t.equal(camp.selected, 1, "a seta para a direita passa para o próximo")
	t.check(is_equal_approx(camp.focus_x, lerpf(room.camp_x, camp.members[1].card.position.x, AHCampScene.FOCUS_PULL)), "e a câmera vai junto")
	await _press("ui_left")
	await _until(func(): return not camp.switching(), 3.0)
	t.equal(camp.selected, 0, "e a da esquerda volta")
	# O clique no corpo escolhe.
	var body: Button = hud.camp_hud.find_child("Body_" + camp.members[2].hero_id, true, false)
	if t.check(body != null, "o corpo do terceiro tem a área do clique"):
		body.pressed.emit()
		await _until(func(): return not camp.switching(), 3.0)
		t.equal(camp.selected, 2, "o clique no corpo escolhe o herói")
	# O analógico: um toque troca um herói só, mesmo com Reduzir efeitos (sem o fade).
	Campaign.state.settings.reduced_environment_effects = true
	await _until(func(): return false, 0.3)
	var before_stick: int = camp.selected
	for value in [0.3, 0.6, 0.8, 1.0, 1.0, 0.9, 0.6, 0.2, 0.0]:
		var motion := InputEventJoypadMotion.new()
		motion.axis = JOY_AXIS_LEFT_X
		motion.axis_value = value
		_tree.root.push_input(motion)
		await _tree.process_frame
	t.equal(camp.selected, posmod(before_stick + 1, camp.members.size()), "um toque no analógico troca um herói só")
	Campaign.state.settings.reduced_environment_effects = false
	# A placa de cada um com a vida e o instinto.
	t.check(camp.members.all(func(m): return hud.camp_hud._plates[m.hero_id].find_child("Instinct", true, false) != null), "a placa de cada um com a barra do instinto")
	# Comer: as regras de sempre e a resposta no herói.
	camp.select(0, false)
	await _frames(2)
	var bento = Campaign.hero(camp.members[0].hero_id)
	bento.instinct = 20
	var hp0: int = bento.hp
	var food0 := J.food(Campaign.state)
	hud.camp_hud.refresh()
	# O A do controle confirma o botão com foco (como na luta).
	hud.camp_hud.eat_button.grab_focus()
	await _pad(JOY_BUTTON_A)
	await _frames(1)
	t.equal([bento.hp, bento.instinct, J.food(Campaign.state)], [mini(bento.max_hp, hp0 + maxi(1, bento.max_hp / 10)), 15, food0 - 1], "comer: +10% da vida, −5 de instinto, uma comida")
	t.check(not _tree.get_nodes_in_group("camp_effect").is_empty() and _gain_text(hud.camp_hud).contains("+%d" % (bento.hp - hp0)), "o efeito e o número verde no herói")
	t.check(_tree.get_nodes_in_group("camp_effect").any(func(e): return e.texture.resource_path.ends_with("food_morsel.webp")), "o efeito da comida")
	# Curativo na Íris (a ampola dela).
	var iris_index: int = camp.members.map(func(m): return m.hero_id).find("hero_sapo_iris")
	if iris_index >= 0:
		var iris = Campaign.hero("hero_sapo_iris")
		iris.hp = int(iris.max_hp) - 10
		camp.select(iris_index, false)
		await _frames(2)
		var bandages: int = Campaign.state.inventory.bandages
		hud.camp_hud.refresh()
		hud.camp_hud.heal_button.pressed.emit()
		await _frames(2)
		t.equal([iris.hp, Campaign.state.inventory.bandages], [int(iris.max_hp) - 2, bandages - 1], "curativo: +8 de vida, um curativo")
		t.check(_tree.get_nodes_in_group("camp_effect").any(func(e): return e.texture.resource_path.ends_with("iris_ampoule.webp")), "na Íris, a ampola")
	# Sem o que curar, o botão apaga.
	var full = Campaign.hero(camp.selected_id())
	full.hp = full.max_hp
	hud.camp_hud.refresh()
	t.check(hud.camp_hud.heal_button.disabled, "com a vida cheia, o curativo apaga")
	# Reduzir efeitos: o efeito parado, sem subir.
	Campaign.state.settings.reduced_environment_effects = true
	var low = Campaign.hero(camp.selected_id())
	low.hp = int(low.max_hp) - 5
	hud.camp_hud.refresh()
	hud.camp_hud.heal_button.pressed.emit()
	await _frames(2)
	var still: Array = _tree.get_nodes_in_group("camp_effect")
	var y0: float = still.back().position.y if not still.is_empty() else 0.0
	await _frames(6)
	t.check(not still.is_empty() and is_equal_approx(still.back().position.y, y0) and still.back().scale == Vector2.ONE, "com Reduzir efeitos, o efeito parado")
	Campaign.state.settings.reduced_environment_effects = false
	# Levantar no meio da troca de herói (com o A do controle): a troca termina e o preto cobre a volta das poses.
	await _until(func(): return false, 0.3)
	camp.step(1)
	await _frames(2)
	hud.camp_hud.leave_button.grab_focus()
	await _pad(JOY_BUTTON_A)
	var covered := true
	var limit := Time.get_ticks_msec() + 5000
	while camp.active and Time.get_ticks_msec() < limit:
		await _tree.process_frame
	covered = GameFlow._fade.visible and GameFlow._fade.modulate.a > 0.98
	await _until(func(): return not corridor.busy and not camp.active, 5.0)
	t.check(covered, "levantar durante a troca: o preto cobre a volta das poses")
	t.check(not camp.active and not hud.camp_open() and Campaign.state.session.screen == "corridor", "levantar acampamento volta ao corredor")
	var idle_ok: bool = true
	for index in street._heroes.size():
		var idle: Dictionary = AHCombatArena.art_entry(street._combat_art.heroes, street.party_ids[index]).idle
		if street._heroes[index]._art.file != idle.file:
			idle_ok = false
	t.check(idle_ok, "todos de volta com a arte de pé")
	t.check(not corridor.blocking(), "e a equipe volta a andar")
	t.check(street._heroes.all(func(h): return absf(h.position.x - room.camp_x) > 0.7), "e ninguém da fila fica em cima da fogueira: %s (fogo %.2f)" % [street._heroes.map(func(h): return snappedf(h.position.x, 0.01)), room.camp_x])


## Reaberto com o save do meio do acampamento: a equipe já em volta da fogueira, sem fade, com o HUD.
func _reopened() -> void:
	var c: Dictionary = Campaign.create_initial(29)
	J.start_expedition(c, "fase_1", 29)
	var street = await _street_at_camp(c)
	if street == null:
		return
	await street.corridor._start_camp()
	var saved = Campaign.read_file(Campaign.primary_path())
	t.check(saved is Dictionary and saved.session.screen == "rest", "o save do meio do acampamento")
	_tree.unload_current_scene()
	await _frames(2)
	Campaign.state = saved
	GameFlow.change_to("street", {}, false)
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			break
	street = _tree.current_scene
	await _frames(3)
	t.check(street != null and street.corridor.camp.active and street.exploration_hud.camp_open(), "reaberto, o acampamento já montado")


## O menu e a Mochila dentro do acampamento (#98): o Esc e o I abrem, as setas não trocam o herói por baixo deles, e
## voltar à Estação pelo menu fecha a fogueira antes do resultado.
func _menu_in_camp() -> void:
	var c: Dictionary = Campaign.create_initial(31)
	J.start_expedition(c, "fase_1", 31)
	var street = await _street_at_camp(c)
	if street == null:
		t.check(false, "a rua com o acampamento para o teste do menu")
		return
	var corridor = street.corridor
	var hud: AHExplorationHud = street.exploration_hud
	await corridor._start_camp()
	await _until(func(): return hud.camp_open() and not corridor.camp.switching(), 5.0)
	t.check(hud._menu_button.visible and hud._bag_button.visible, "no acampamento, o Menu e a Mochila continuam no canto")
	await _press("inventory")
	t.check(hud.inventory_shown(), "o I abre a Mochila no acampamento")
	var quote: Dictionary = AHExplorationCare.quote(Campaign.state, String(Campaign.state.session.expedition.team[0]), AHExplorationCare.SMALL_MEAL)
	t.check(not quote.available and String(quote.reason).contains("barra de baixo"), "na Mochila, o motivo aponta a barra do acampamento")
	var before: int = corridor.camp.selected
	await _press("ui_right")
	await _frames(3)
	t.equal(corridor.camp.selected, before, "com a Mochila aberta, a seta não troca o herói do acampamento")
	await _press("inventory")
	t.check(not hud.modal_open() and hud.camp_open(), "o I fecha a Mochila e o acampamento continua")
	await _press("menu")
	t.check(hud.menu_shown(), "o Esc abre o menu no acampamento")
	await _press("menu")
	t.check(not hud.modal_open() and corridor.camp.active, "e fecha de novo, sem levantar acampamento")
	await _press("menu")
	var back := _button(hud, "Voltar à Estação")
	t.check(back != null, "o menu do acampamento tem o Voltar à Estação")
	if back != null:
		back.pressed.emit()
		await _frames(2)
		var confirm := _button(hud, "Voltar à Estação")
		if confirm != null and hud.modal_open():
			confirm.pressed.emit()
	var closed := await _until(func(): return not corridor.camp.active and Campaign.state.session.screen == "result", 8.0)
	t.check(closed, "voltar à Estação de dentro do acampamento fecha a fogueira e mostra o resultado")
	t.check(not hud.camp_open(), "sem a barra do acampamento por baixo do resultado")


## O GameFlow.fade público: um fade novo substitui o que corre (a tela não fica presa no preto).
func _fades() -> void:
	var rect: ColorRect = GameFlow._fade
	var resumed := [false]
	var first := func():
		await GameFlow.fade(1.0, 0.5)
		resumed[0] = true
	first.call()
	await _frames(2)
	await GameFlow.fade(0.0, 0.05)
	await _frames(40)
	t.check(rect.modulate.a < 0.01 and not rect.visible, "dois fades seguidos terminam no último (transparente)")
	t.check(resumed[0], "e quem esperava o primeiro fade continua (a troca de cena não fica presa)")


func _button(root: Node, prefix: String) -> Button:
	for button in root.find_children("*", "Button", true, false):
		if not button.is_queued_for_deletion() and button.is_visible_in_tree() and button.text.begins_with(prefix):
			return button
	return null


func _has(root: Node, node_name: String) -> bool:
	return not root.find_children(node_name, "", true, false).is_empty()


func _gain_text(root: Node) -> String:
	return " ".join(_tree.get_nodes_in_group("camp_gain").filter(func(l): return root.is_ancestor_of(l)).map(func(l): return l.text))


func _press(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		_tree.root.push_input(event)
		await _tree.process_frame


func _pad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		_tree.root.push_input(event)
		await _tree.process_frame


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
