## O Mapa da Rede na tela (#87): o clique no próprio lugar escolhe a fase; o painel mostra a leitura do radar (o guardião e
## os inimigos com a Pesquisa, "não lido" sem ela); a fase bloqueada não prepara; as setas andam pelos lugares; a leitura
## fixa a semente da fase no save; um save sem a semente abre normal.
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-phase-map-%d" % Time.get_ticks_usec()
	await _map()
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


func _map() -> void:
	var c: Dictionary = Campaign.create_initial(9)
	c.completed_phases = ["fase_1"]
	c.station.erase("route_seeds")
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("station", {}, false)
	var hud: AHRefugeHud = null
	for frame in 900:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene is AHStation and _tree.current_scene.hud != null and frame > 3:
			hud = _tree.current_scene.hud
			break
	if not t.check(hud != null, "a Estação abre"):
		return
	var map: AHPhaseMap = hud._map
	map.open("")
	await _frames(3)
	t.check(map.get_global_rect().size.is_equal_approx(map.get_viewport_rect().size), "o mapa cobre a tela e segura os cliques")
	t.check(Campaign.state.station.has("route_seeds") and Campaign.state.station.route_seeds.size() == 5, "um save sem as sementes abre, e o mapa as fixa")
	var saved = Campaign.read_file(Campaign.primary_path())
	t.check(saved is Dictionary and saved.station.get("route_seeds", {}).size() == 5, "e elas vão para o save")
	# O clique no próprio lugar (o centro do polígono da Ponte, em pixels da pintura) escolhe a fase.
	var bridge: Dictionary = map.region_of("fase_2")
	var center := Vector2.ZERO
	for p in bridge.hit_polygon:
		center += Vector2(p[0], p[1])
	center /= bridge.hit_polygon.size()
	t.equal(map.phase_at(center), "fase_2", "o ponto no polígono é da Ponte")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = center
	map._on_map_input(click)
	await _frames(2)
	t.equal(map.selected, "fase_2", "o clique no lugar escolhe a fase")
	var radar: Node = map._aside.find_child("Radar", true, false)
	var boss: Label = radar.find_child("Read_boss", true, false).find_child("Value", true, false) if radar != null else null
	t.check(boss != null and boss.text == "Não lido", "sem a Pesquisa, o guardião não é lido (%s)" % (boss.text if boss else "?"))
	var prepare: Button = map.find_child("Prepare", true, false)
	t.check(prepare != null and not prepare.disabled, "a Ponte aberta prepara")
	# Com a Pesquisa recuperada, o guardião da rota fixada aparece pelo nome.
	Campaign.state.station.rooms[S.RESEARCH] = 1
	map.refresh()
	await _frames(2)
	var read: Dictionary = AHNetworkRadar.reading(Campaign.state, "fase_2")
	boss = map._aside.find_child("Read_boss", true, false).find_child("Value", true, false)
	t.equal(boss.text, AHPhaseMap.radar_text("boss", read.boss), "com a Pesquisa, o guardião da rota")
	t.check(boss.text != "Não lido" and boss.text != "", "pelo nome (%s)" % boss.text)
	# G / X (station_prepare), como diz o botão, segue para a Preparação com a fase aberta.
	var chosen: Array = []
	map.phase_chosen.connect(func(id): chosen.append(id))
	var prepare_key := InputEventAction.new()
	prepare_key.action = "station_prepare"
	prepare_key.pressed = true
	map._unhandled_input(prepare_key)
	t.equal(chosen, ["fase_2"], "G / X prepara a fase escolhida")
	map.visible = true
		# A fase bloqueada: o botão principal travado.
	map._select("fase_3")
	await _frames(2)
	prepare = map.find_child("Prepare", true, false)
	t.check(prepare != null and prepare.disabled, "a fase bloqueada não prepara")
	# As setas andam pelos lugares, e Interagir escolhe.
	AHUiStyle.using_keys = true
	var refuge: Button = map._labels.get_node("Place_refuge")
	refuge.grab_focus()
	await _frames(1)
	var down := InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	Input.parse_input_event(down)
	await _frames(2)
	var focused := map.get_viewport().gui_get_focus_owner()
	t.check(focused != null and focused.name == "Place_fase_1", "↓ vai da Estação para a Fase 1 (%s)" % (focused.name if focused else "nada"))
	if focused is Button:
		(focused as Button).pressed.emit()
		await _frames(2)
	t.equal(map.selected, "fase_1", "e Interagir escolhe")
	# O X do painel tira a escolha.
	map._aside.find_child("Deselect", true, false).pressed.emit()
	await _frames(2)
	t.equal(map.selected, "", "o X volta aos lugares")
	map.visible = false


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
