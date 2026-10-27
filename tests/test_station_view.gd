## A Estação depois de jogar (#131): o herói da Sala não fica por cima do mapa, os cômodos por recuperar com o marcador
## (o custo certo e o motivo), a vista geral que anda para os lados dentro do limite (arrastando e pelas setas), o
## cômodo escolhido mais perto e o vizinho trocado direto, sem voltar à vista geral. A fila da chegada na ordem da
## formação e a saída andando ficam no test_return.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-station-view-%d" % Time.get_ticks_usec()
	Campaign.state = Campaign.create_initial(44)
	_neighbors()
	var station = await _open()
	if t.check(station != null, "a Estação abriu"):
		await _sala_to_map(station)
		await _lock_marks(station)
		await _pan(station)
		await _rooms(station)
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Tips.enabled = tips
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _neighbors() -> void:
	t.equal(AHRefugeHud.neighbor_room(S.BAR, 1), S.CANTEEN, "o vizinho da direita do Bar é a Cantina")
	t.equal(AHRefugeHud.neighbor_room(S.BAR, -1), S.CHARACTERS, "e o da esquerda, o Alojamento")
	t.equal(AHRefugeHud.neighbor_room(S.DORMITORY, -1), "", "na ponta, nenhum")
	t.equal(AHRefugeHud.neighbor_room(S.INFIRMARY, 1), S.RESEARCH, "no andar de baixo, da Enfermaria à Pesquisa")
	t.equal(AHRefugeHud.neighbor_room(S.DEPOT, 1), S.FORGE, "e do Depósito à Forja (o mesmo andar, mesmo com o piso mais fundo)")


## Na Sala dos Personagens, PREPARAR EXPEDIÇÃO abre o mapa com a Sala fechada: o herói de corpo inteiro não fica por cima.
func _sala_to_map(station) -> void:
	var hud: AHRefugeHud = station.hud
	hud.open_room(S.CHARACTERS)
	await _frames(5)
	t.check(is_instance_valid(hud._room_screen) and hud._room_screen.find_child("Hero", true, false) != null, "a Sala abre com o herói")
	hud.open_map()
	await _frames(5)
	t.check(hud._map.visible, "Preparar expedição abre o mapa")
	t.check(not is_instance_valid(hud._room_screen), "com a Sala (e o herói) fechada")
	var heroes: Array = hud.find_children("Hero", "", true, false).filter(func(n): return n is Control and n.is_visible_in_tree())
	t.equal(heroes.size(), 0, "nenhum herói da Sala por cima do mapa")
	hud._map.visible = false
	hud.close_panel()
	await _frames(5)


func _lock_marks(station) -> void:
	var hud: AHRefugeHud = station.hud
	var c: Dictionary = Campaign.state
	c.inventory.scrap = 0
	c.inventory.fragments = 0
	station.commit()
	await _settle(station)
	var forge := hud.lock_mark_info(c, S.FORGE)
	t.equal(forge.state, "short", "a Forja sem sucata: falta recurso")
	t.check(String(forge.title).contains(S.cost_text(S.next_level_cost(c, S.FORGE))), "o marcador diz o custo (%s)" % forge.title)
	t.equal(forge.note, S.upgrade_block(c, S.FORGE), "e o que falta")
	t.equal(hud.lock_mark_info(c, S.BAR).state, "closed", "o Bar: fechado, com o motivo")
	t.check(hud.lock_mark_info(c, S.CANTEEN).is_empty(), "o cômodo recuperado fica sem marcador")
	c.inventory.scrap = 20
	c.inventory.fragments = 5
	station.commit()
	await _frames(3)
	t.equal(hud.lock_mark_info(c, S.FORGE).state, "ready", "com sucata: dá para recuperar")
	var mark: PanelContainer = hud._lock_marks.get(S.FORGE)
	var rect: Rect2 = hud._room_rects.get(S.FORGE, Rect2())
	t.check(mark != null and mark.visible and rect.has_point(mark.get_global_rect().get_center()), "o marcador da Forja fica em cima dela (%s em %s)" % [mark.get_global_rect() if mark != null else Rect2(), rect])
	t.equal(String(mark.get_meta("state", "")) if mark != null else "", "ready", "aceso, pronto para recuperar")
	t.check(not hud._lock_marks.has(S.CANTEEN), "e a Cantina, sem")
	t.equal(S.upgrade_room(c, S.FORGE, 0), "", "recuperada a Forja")
	station.commit()
	await _frames(3)
	t.check(not hud._lock_marks.has(S.FORGE), "o marcador dela sai")


func _pan(station) -> void:
	var hud: AHRefugeHud = station.hud
	station.set_pan(0.0)
	await _settle(station)
	var base_x: float = station._overview_key().pos.x
	station.set_pan(100.0)
	t.equal(station.pan, station.PAN_RANGE.y, "a câmera anda para a direita só até o limite")
	t.check(absf(station._goal.pos.x - (base_x + station.PAN_RANGE.y)) < 0.001, "e a vista geral vai junto")
	station.set_pan(-100.0)
	t.equal(station.pan, station.PAN_RANGE.x, "e para a esquerda também")
	station.set_pan(0.0)
	await _settle(station)
	# A borda da tela só empurra depois de o mouse ficar nela um instante (quem passa a caminho do menu não arrasta a vista).
	hud._edge_time = 0.0
	t.equal(hud.edge_push(2.0, 1920.0, 0.2), 0.0, "o mouse acabou de encostar na borda: a câmera não anda")
	t.equal(hud.edge_push(2.0, 1920.0, 0.2), -1.0, "parado na borda, anda para a esquerda")
	t.equal(hud.edge_push(400.0, 1920.0, 0.2), 0.0, "saindo da borda, para")
	t.equal(hud.edge_push(1918.0, 1920.0, 0.1), 0.0, "e a outra borda também espera")
	t.equal(hud.edge_push(1918.0, 1920.0, 0.3), 1.0, "antes de andar para a direita")
	hud._edge_time = 0.0
	# Arrastar com o mouse anda a câmera e não abre o cômodo.
	var rect: Rect2 = hud._room_rects.get(S.CANTEEN, Rect2())
	var from := rect.get_center()
	hud._unhandled_input(_click(from, true))
	var motion := InputEventMouseMotion.new()
	motion.position = from + Vector2(-200, 0)
	hud._input(motion)
	hud._input(_click(from + Vector2(-200, 0), false))
	t.check(station.pan > 0.5, "arrastar para a esquerda anda a câmera para a direita (%.2f m)" % station.pan)
	t.equal(hud.current, "", "e não abre o cômodo")
	# Soltar sem arrastar abre.
	station.set_pan(0.0)
	await _settle(station)
	rect = hud._room_rects.get(S.CANTEEN, Rect2())
	hud._unhandled_input(_click(rect.get_center(), true))
	hud._input(_click(rect.get_center(), false))
	t.equal(hud.current, S.CANTEEN, "o clique sem arrastar abre o cômodo")
	hud.close_panel()
	await _settle(station)
	# As setas num cômodo fora do quadro (a câmera no limite da direita): ela volta até o cômodo ficar à vista.
	station.set_pan(station.PAN_RANGE.y)
	await _settle(station)
	hud._key_room = S.CHARACTERS
	hud._step_room(Vector2.LEFT)
	await _frames(2)
	var left: float = hud._overview_left()
	t.equal(hud._key_room, S.DORMITORY, "a seta escolhe o Dormitório")
	t.check(station.pan < station.PAN_RANGE.y, "e a câmera anda até ele (%.2f m)" % station.pan)
	await _settle(station)
	var dorm: Rect2 = station.room_screen_rects().get(S.DORMITORY, Rect2())
	t.check(dorm.position.x >= left - 2.0, "e ele fica fora do menu (%s, menu até %.0f)" % [dorm, left])
	station.set_pan(0.0)


func _rooms(station) -> void:
	var hud: AHRefugeHud = station.hud
	# Mais perto que antes: as paredes do lado saem um pouco do quadro.
	hud.open_room(S.BAR)
	var room: Dictionary = station.room_def(S.BAR)
	var before: Dictionary = station._framed_key(room.x0 - 0.3, room.x1 + 0.3, room.floor + 1.55, station.SCREEN_MENU_RIGHT, station.SCREEN_PANEL_LEFT, 26.0, -3.0, 0.0)
	t.check(station._goal.pos.z < before.pos.z - 0.3, "o cômodo escolhido fica mais perto (%.2f contra %.2f m)" % [station._goal.pos.z, before.pos.z])
	await _settle(station)
	# O vizinho direto, sem passar pela vista geral.
	var seen: Array = []
	var push := InputEventAction.new()
	push.action = "station_room_next"
	push.pressed = true
	hud._input(push)
	seen.append(hud.current)
	t.equal(hud.current, S.CANTEEN, "a tecla do vizinho troca o Bar pela Cantina")
	t.check(not seen.has("") and not station._in_overview, "sem voltar à vista geral")
	await _settle(station)
	# Clicar no vizinho (fora do painel): a Cantina leva ao Bar.
	var rects: Dictionary = station.room_screen_rects()
	var bar: Rect2 = rects.get(S.BAR, Rect2())
	t.check(bar.size.x > 0.0, "o Bar aparece ao lado da Cantina")
	hud._unhandled_input(_click(bar.get_center(), true))
	t.equal(hud.current, S.BAR, "clicar no Bar troca direto")
	t.check(not station._in_overview, "e a câmera vai do cômodo ao vizinho")
	hud.close_panel()
	await _settle(station)
	# A Sala fica no meio do andar de cima: o vizinho passa por ela (do Dormitório à Sala, da Sala ao Bar).
	hud.open_room(S.DORMITORY)
	await _frames(3)
	push = InputEventAction.new()
	push.action = "station_room_next"
	push.pressed = true
	hud._input(push)
	await _frames(3)
	t.equal(hud.current, S.CHARACTERS, "do Dormitório, o vizinho é a Sala")
	hud._input(push)
	await _frames(3)
	t.equal(hud.current, S.BAR, "e da Sala, o Bar")
	hud.close_panel()
	await _settle(station)
	t.check(Settings.REMAPPABLE.has("station_room_prev") and Settings.REMAPPABLE.has("station_room_next"), "as teclas do vizinho podem ser trocadas nas Opções")
	# Texto Maior: o cartão do cômodo por recuperar não sobe por cima da coluna do menu.
	# O cartão aberto antes da troca do tamanho do texto (o Bar apontado no Normal) é refeito no Maior, dentro da tela.
	hud._key_room = S.BAR
	hud._last_mouse = hud.get_viewport().get_mouse_position()
	await _frames(15)
	Settings.set_text_size(2)
	hud.refresh()
	await _frames(15)
	var swapped: Rect2 = hud._room_card.get_global_rect()
	var bar_mark: PanelContainer = hud._lock_marks.get(S.BAR)
	t.check(swapped.end.y <= 1080.0 and not swapped.intersects(hud._menu.get_global_rect()), "trocado o texto com o Bar apontado, o cartão é refeito dentro da tela (%s)" % swapped)
	t.check(hud._room_card.find_child("LockTitle", true, false) != null or (bar_mark != null and bar_mark.visible), "e o custo continua à vista")
	for id in [S.BAR, S.FORGE, S.RESEARCH, S.INFIRMARY]:
		hud._key_room = id
		hud._last_mouse = hud.get_viewport().get_mouse_position()
		await _frames(20)
		var card: Rect2 = hud._room_card.get_global_rect()
		var menu: Rect2 = hud._menu.get_global_rect()
		t.check(hud._room_card.visible and not card.intersects(menu), "texto Maior, %s: o cartão fora do menu (%s, menu %s)" % [id, card, menu])
		var in_card: bool = hud._room_card.find_child("LockTitle", true, false) != null
		var mark: PanelContainer = hud._lock_marks.get(id)
		if not hud.lock_mark_info(Campaign.state, id).is_empty():
			t.check(in_card or (mark != null and mark.visible), "texto Maior, %s: o custo à vista no cartão ou no marcador" % id)
	hud._key_room = ""
	Settings.set_text_size(0)
	hud.refresh()
	await _frames(3)


func _click(at: Vector2, down: bool) -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = down
	click.position = at
	return click


func _open():
	GameFlow.change_to("station", {}, false)
	for frame in 300:
		await _tree.process_frame
		var scene := _tree.current_scene
		if not GameFlow.busy and scene is AHStation and scene.hud != null:
			await _tree.process_frame
			return scene
	return null


## A câmera parada (a vista geral recalcula os retângulos dos cômodos).
func _settle(station) -> void:
	for i in 600:
		await _tree.process_frame
		if station.camera_settled() and not station.passage_moving() and i > 4:
			break
	await _frames(3)


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
