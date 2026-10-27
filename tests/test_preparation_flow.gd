## A saída em três passos (#123): IR AO MAPA na Estação, o lugar no Mapa da Rede (PREPARAR NESTE LUGAR) e a equipe na
## Plataforma 1, cada um de pé sobre a sua carta, com o lugar e o radar no alto, o Foco da rota, a Comida e INICIAR
## EXPEDIÇÃO com a confirmação. Confere VOLTAR em cada passo, a troca de herói e de ordem, quem não pode ir (o caído e
## quem não tem arte de luta), o save no meio (no mapa e na plataforma) e a partida no vagão. O caminho inteiro pelos
## botões, com o briefing, fica no test_full_journey; o briefing em si, no test_briefing.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const J = preload("res://scripts/flow/journey_rules.gd")
const FOUNDERS := ["hero_cao_bento", "hero_coruja_vespera", "hero_gato_nick", "hero_sapo_iris"]

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-preparation-flow-%d" % Time.get_ticks_usec()
	Campaign.state = _campaign()
	Campaign.save()
	var station = await _open()
	if t.check(station != null, "a Estação abriu"):
		await _station_button(station)
		station = await _back_steps(station)
	if station != null:
		await _platform(station)
		station = await _save_midway(station)
	if station != null:
		await _guards(station)
		await _depart(station)
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


## Os quatro fundadores, um recruta caído (na Enfermaria) e o Risco (o rato, ainda sem arte de luta).
func _campaign() -> Dictionary:
	var c: Dictionary = Campaign.create_initial(123)
	c.preferred_formation = FOUNDERS.duplicate()
	c.inventory.seeds = 12
	var rex: Dictionary = S.recruit(c, "cao", RandomNumberGenerator.new(), "Rex")
	S.admit_fallen(c, [rex.hero_id])
	c.unlocked_classes.append("rato")
	S.recruit(c, "rato", RandomNumberGenerator.new(), "Risco")
	c.inventory.seeds = 12
	return c


## IR AO MAPA: o botão principal da Estação e o do cômodo da Preparação abrem o Mapa da Rede; a gaveta saiu.
func _station_button(station) -> void:
	var hud: AHRefugeHud = station.hud
	var go: Button = hud.find_child("Prepare", true, false)
	t.check(go != null and go.text.begins_with("IR AO MAPA"), "o botão principal da Estação é IR AO MAPA")
	t.equal(S.next_step(Campaign.state).get("button", ""), "Ir ao mapa", "o Próximo passo também leva ao mapa")
	go.pressed.emit()
	await _frames(2)
	t.check(hud._map.visible and hud.current == "", "IR AO MAPA abre o Mapa da Rede por cima da vista geral")
	var place: Button = hud._map.find_child("Prepare", true, false)
	t.check(place == null or place.text.begins_with("PREPARAR NESTE LUGAR"), "no mapa, o botão do lugar é PREPARAR NESTE LUGAR")
	hud._map.closed.emit()
	await _frames(2)
	hud.open_room(S.PREPARATION)
	await _frames(2)
	t.check(hud.find_child("Preparation", true, false) == null, "a gaveta da Preparação saiu")
	var to_map := _button(hud._panel, "Ir ao mapa")
	if t.check(to_map != null, "o cômodo da Preparação leva ao mapa"):
		to_map.pressed.emit()
		await _frames(2)
		t.check(hud._map.visible, "e abre o Mapa da Rede")
		hud._map.closed.emit()
	hud.close_panel()
	await _frames(2)


## VOLTAR em cada passo: o mapa volta à vista geral; a plataforma volta ao mapa com a escolha; a confirmação volta à
## plataforma.
func _back_steps(station):
	var hud: AHRefugeHud = station.hud
	hud.open_map()
	await _frames(2)
	_press_back()
	await _frames(3)
	t.check(not hud._map.visible and hud.current == "", "Voltar no mapa fecha o mapa, na vista geral")
	hud.open_map()
	hud._map._select("fase_1")
	await _frames(2)
	var place: Button = hud._map.find_child("Prepare", true, false)
	if not t.check(place != null and not place.disabled, "o lugar escolhido pode ser preparado"):
		return station
	hud._briefed = "fase_1"
	place.pressed.emit()
	await _frames(3)
	t.check(not hud._map.visible and hud.current == "departure" and is_instance_valid(hud._departure), "PREPARAR NESTE LUGAR leva a equipe para a plataforma")
	t.check(station.on_platform, "a câmera sobe para a Plataforma 1")
	t.equal(hud._draft.phase, "fase_1", "com o lugar escolhido")
	# A escolha da plataforma (o foco, a comida) volta igual depois do mapa.
	hud._draft.focus = ""
	hud._draft.extra = 2
	hud.refresh()
	await _frames(2)
	var draft: Dictionary = hud._draft.duplicate(true)
	_press_back()
	await _frames(3)
	t.check(hud._map.visible and hud._map.selected == "fase_1" and hud.current == "", "Voltar na plataforma abre o mapa no mesmo lugar")
	t.check(not is_instance_valid(hud._departure) and station.lineup.is_empty(), "a fila e as cartas saem com a plataforma")
	(hud._map.find_child("Prepare", true, false) as Button).pressed.emit()
	await _frames(3)
	t.equal(hud._draft, draft, "de volta à plataforma, a equipe, o foco e a comida de antes")
	hud._departure.open_confirm()
	await _frames(2)
	t.check(hud._departure.confirm_open(), "Iniciar expedição abre a confirmação")
	_press_back()
	await _frames(3)
	t.check(hud.current == "departure" and not hud._departure.confirm_open() and not hud._map.visible, "Voltar na confirmação fica na plataforma")
	# Do mapa aberto pela plataforma, Voltar desce para a vista geral.
	_press_back()
	await _frames(3)
	_press_back()
	await _frames(3)
	t.check(not hud._map.visible and hud.current == "" and not station.lineup.size(), "Voltar no mapa (vindo da plataforma) volta à vista geral")
	var deadline := Time.get_ticks_msec() + 20000
	while station.on_platform and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
	t.check(not station.on_platform, "e a câmera desce da plataforma")
	return station


## Na plataforma: a fila sobre as cartas (a posição 1 à direita), a troca de ordem e de herói, quem não pode ir.
func _platform(station) -> void:
	var hud: AHRefugeHud = station.hud
	hud._draft = {}
	hud._briefed = ""
	hud.open_map()
	hud._on_phase_chosen("fase_1")
	hud._briefed = "fase_1"
	await _frames(3)
	var screen: AHDepartureScreen = hud._departure
	t.equal(hud._draft.team, FOUNDERS, "a equipe da última partida, sem o caído nem o Risco")
	var slots: Array = screen.find_children("Slot*", "Button", true, false)
	t.equal(slots.map(func(b): return String(b.name)), ["Slot4", "Slot3", "Slot2", "Slot1"], "as quatro cartas, da posição 4 (esquerda) à 1 (direita)")
	var centers := screen.card_centers()
	t.check(centers[FOUNDERS[0]] > centers[FOUNDERS[3]], "a carta da frente (Bento) fica à direita")
	t.equal(station.lineup.map(func(e): return e.hero_id), AHStationReport.scene_order(FOUNDERS), "a fila da plataforma na ordem da cena")
	var band: Control = screen.find_child("Band", true, false)
	t.check(band != null and _label(band, "Rua das Vitrines") and screen.find_child("Radar", true, false) != null, "a faixa do alto com o lugar e o radar")
	# A ordem: duas cartas trocam de lugar.
	(slots[3] as Button).pressed.emit()
	await _frames(1)
	t.equal(screen.selected, 0, "clicar na carta da frente a escolhe")
	(screen.find_child("Slot2", true, false) as Button).pressed.emit()
	await _frames(2)
	t.equal(hud._draft.team.slice(0, 2), [FOUNDERS[1], FOUNDERS[0]], "a segunda carta troca as duas de lugar")
	t.equal(station.lineup.map(func(e): return e.hero_id), AHStationReport.scene_order(hud._draft.team), "e a fila acompanha")
	# Quem não pode ir: o caído com o motivo, o Risco sem arte; nenhum dos dois entra.
	var rex: Dictionary = S.living(Campaign.state).filter(func(h): return h.display_name == "Rex")[0]
	var risco: Dictionary = S.living(Campaign.state).filter(func(h): return h.display_name == "Risco")[0]
	var rex_chip: Button = screen.find_child("Bench_%s" % rex.id, true, false)
	t.check(rex_chip != null and rex_chip.disabled and rex_chip.text.contains("Caído") and rex_chip.text.contains("Volta"), "o caído aparece na lista da Estação com o motivo")
	var risco_chip: Button = screen.find_child("Bench_%s" % risco.id, true, false)
	t.check(risco_chip != null and risco_chip.disabled and risco_chip.text.contains("sem arte de combate"), "e quem não tem arte de luta também")
	screen.pick(3)
	screen.put_in(rex.id)
	screen.put_in(risco.id)
	await _frames(1)
	t.check(not hud._draft.team.has(rex.id) and not hud._draft.team.has(risco.id), "nenhum dos dois entra na equipe")
	screen.pick(3)
	# Trocar o herói: com uma carta escolhida, quem está na Estação entra no lugar dela.
	screen = hud._departure
	screen.pick(3)
	screen.leave_out()
	await _frames(2)
	t.equal(hud._draft.team.size(), 3, "Deixar na Estação: parte com três")
	screen = hud._departure
	screen.pick(3)
	await _frames(1)
	var iris_chip: Button = screen.find_child("Bench_%s" % FOUNDERS[3], true, false)
	t.check(iris_chip != null and not iris_chip.disabled, "com a vaga escolhida, a Íris da Estação pode entrar")
	if iris_chip != null:
		iris_chip.pressed.emit()
	await _frames(2)
	t.equal(hud._draft.team.size(), 4, "e entra na vaga")
	t.equal(station.lineup.size(), 4, "com os quatro na fila")
	# O caído forçado no rascunho (o rascunho de antes da queda): INICIAR EXPEDIÇÃO trava com o motivo.
	hud._draft.team[3] = rex.id
	hud.refresh()
	await _frames(2)
	var blocked: Button = hud._departure.find_child("StartBlocked", true, false)
	t.check(blocked != null and blocked.disabled and _label(blocked, "Rex"), "com o caído na equipe, Iniciar trava e diz o motivo")
	hud._departure.open_confirm()
	t.check(not hud._departure.confirm_open(), "e a confirmação não abre")
	hud._draft.team[3] = FOUNDERS[3]
	hud.refresh()
	await _frames(2)


## O save no meio: no mapa e na plataforma, nada parte nem gasta; reaberto, a Estação volta à vista geral, e o radar lê
## a mesma rota.
func _save_midway(station):
	var hud: AHRefugeHud = station.hud
	var seeds := S.quantity(Campaign.state, "seeds")
	hud._draft.extra = 3
	hud.refresh()
	t.check(Campaign.save(), "o save na plataforma grava")
	var disk = Campaign.read_file(Campaign.primary_path())
	t.check(disk != null and disk.session.expedition == null, "na plataforma, o save não tem expedição")
	t.equal(S.quantity(disk, "seeds") if disk != null else -1, seeds, "e a comida extra não gastou sementes")
	var seed_value := AHNetworkRadar.route_seed(Campaign.state, "fase_1")
	hud.back_to_map()
	await _frames(2)
	t.check(Campaign.save(), "o save no mapa grava")
	disk = Campaign.read_file(Campaign.primary_path())
	t.check(disk != null and disk.session.expedition == null, "no mapa, também sem expedição")
	t.equal(Campaign.load_or_new(), "primary", "o save reabre")
	station = await _open()
	if not t.check(station != null, "a Estação reabre do save"):
		return null
	hud = station.hud
	t.check(hud.current == "" and not hud._map.visible and not station.on_platform, "reaberta, a Estação fica na vista geral")
	t.equal(AHNetworkRadar.route_seed(Campaign.state, "fase_1"), seed_value, "e o radar lê a mesma rota")
	return station


## O que a QA achou (#123): G na subida não abre a confirmação; o briefing espera a interface escondida (F2) e a dica da
## primeira vez, um de cada vez; a lista compacta diz o motivo; a vaga vazia leva o herói para o fim da fila.
func _guards(station) -> void:
	var hud: AHRefugeHud = station.hud
	var tips: bool = Tips.enabled
	Tips.enabled = true
	Tips._seen.erase("preparation")
	hud._draft = {}
	hud._briefed = ""
	hud.open_map()
	hud._on_phase_chosen("fase_1")
	await _frames(2)
	t.check(Tips.showing(), "a dica da plataforma aparece na primeira vez")
	hud._departure.press_start()
	t.check(not hud._departure.confirm_open(), "G na subida da câmera não abre a confirmação")
	hud.set_hud_hidden(true)
	var deadline := Time.get_ticks_msec() + 20000
	while (not station.camera_settled() or station.passage_moving()) and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
	await _frames(10)
	t.check(not hud.briefing_open(), "com a interface escondida (F2), o briefing espera")
	hud.set_hud_hidden(false)
	await _frames(3)
	t.check(not hud.briefing_open(), "com a dica aberta, também")
	Tips.dismiss()
	await _frames(3)
	t.check(hud.briefing_open() and hud.is_visible_in_tree(), "fechada a dica, o briefing abre, com a interface à vista")
	hud._departure.press_start()
	t.check(not hud._departure.confirm_open(), "com o briefing aberto, a confirmação espera")
	if hud.briefing_open():
		hud.briefing.skip()
	await _frames(3)
	hud._departure.press_start()
	t.check(hud._departure.confirm_open(), "lido o briefing, G abre a confirmação")
	hud._departure.close_confirm()
	Tips.enabled = tips
	# A vaga vazia: o herói escolhido vai para a última posição ocupada.
	hud._draft.team = FOUNDERS.slice(0, 3)
	hud.refresh()
	await _frames(1)
	hud._departure.pick(0)
	hud._departure.pick(3)
	t.equal(hud._draft.team, [FOUNDERS[1], FOUNDERS[2], FOUNDERS[0]], "a vaga vazia leva o herói para o fim da fila")
	# A lista compacta (muitos na Estação) diz o motivo do caído no próprio botão.
	hud._departure._compact = true
	hud._departure.rebuild()
	await _frames(1)
	var rex: Dictionary = S.living(Campaign.state).filter(func(h): return h.display_name == "Rex")[0]
	var chip: Button = hud._departure.find_child("Bench_%s" % rex.id, true, false)
	t.check(chip != null and chip.text.contains("Caído"), "na lista compacta, o caído diz \"Caído\" (%s)" % (chip.text if chip else "?"))
	hud._draft.team = FOUNDERS.duplicate()
	hud._departure._compact = false
	hud.refresh()
	await _frames(1)


## INICIAR EXPEDIÇÃO na confirmação: o resumo (o lugar, a equipe, a comida) e a partida no vagão.
func _depart(station) -> void:
	var hud: AHRefugeHud = station.hud
	hud.open_map()
	hud._on_phase_chosen("fase_1")
	hud._briefed = "fase_1"
	hud._departure.waiting = false
	hud._draft.extra = 1
	hud.refresh()
	await _frames(3)
	var seeds := S.quantity(Campaign.state, "seeds")
	var start: Button = hud._departure.find_child("Start", true, false)
	if not t.check(start != null and not start.disabled, "INICIAR EXPEDIÇÃO liberado"):
		return
	start.pressed.emit()
	await _frames(2)
	var confirm: Control = hud._departure._confirm
	if not t.check(confirm != null and hud._departure.confirm_open(), "a confirmação abre"):
		return
	t.check(_label(confirm, "Rua das Vitrines"), "o resumo diz o lugar")
	t.check(_label(confirm, "1. Bento") and _label(confirm, "4. Íris"), "a equipe na ordem")
	t.check(_label(confirm, "1 extras"), "e a comida")
	t.equal(Campaign.state.session.expedition, null, "a confirmação ainda não parte")
	(confirm.find_child("Go", true, false) as Button).pressed.emit()
	# Voltar no fade da partida: nada volta (o rascunho já foi gasto).
	await _frames(1)
	_press_back()
	await _frames(3)
	t.check(not hud._map.visible and hud.current == "departure", "Voltar durante o fade da partida não volta ao mapa")
	var deadline := Time.get_ticks_msec() + 20000
	while GameFlow.passage == null and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
	t.check(GameFlow.passage != null and GameFlow.passage.backdrop is AHWagonRide, "a partida no vagão")
	var expedition = Campaign.state.session.expedition
	t.check(expedition != null and expedition.phase_id == "fase_1" and expedition.team == FOUNDERS, "a expedição parte com a equipe da plataforma")
	t.equal(S.quantity(Campaign.state, "seeds"), seeds - S.FOOD_COST, "a comida extra sai na partida")
	while GameFlow.busy:
		await _tree.process_frame


func _open():
	GameFlow.change_to("station", {}, false)
	for frame in 600:
		await _tree.process_frame
		var scene := _tree.current_scene
		if not GameFlow.busy and GameFlow.passage == null and scene is AHStation and scene.hud != null and frame > 3:
			await _frames(3)
			return scene
	return null


func _press_back() -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = "ui_cancel"
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func _button(root: Node, prefix: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if node.is_visible_in_tree() and (node as Button).text.to_lower().begins_with(prefix.to_lower()):
			return node
	return null


func _label(root: Node, part: String) -> bool:
	return root.find_children("*", "Label", true, false).any(func(l): return (l as Label).text.contains(part))


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
