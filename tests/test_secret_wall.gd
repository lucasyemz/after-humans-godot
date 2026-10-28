## A parede secreta da plataforma (#203): no lugar do painel do Mapa da Rede, um pedaço da própria parede (o azulejo e o
## concreto) cobre a porta de manutenção e desliza do mesmo jeito (o pivô, PANEL_SLIDE, a alavanca e a fresta); o
## azulejo anda com a peça; na descida de verdade ela abre e volta ao lugar; o save não muda; e o Mapa da Rede fica fixo
## na parede ao lado, fora do caminho da peça e da pilastra.
extends RefCounted

const B = preload("res://scripts/station/station_build.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-secret-wall-%d" % Time.get_ticks_usec()
	Campaign.state = Campaign.create_initial(203)
	Campaign.state.station.last_return = {}
	GameFlow.change_to("station", {}, false)
	var station: AHStation = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene is AHStation and frame > 3:
			station = _tree.current_scene
			break
	if t.check(station != null, "a Estação abriu"):
		_pieces(station)
		await _descent(station)
		_network_map(station)
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


## A peça é a parede (o azulejo e o concreto da plataforma), e não mais o painel do mapa; fechada, ela cobre a porta.
func _pieces(station: AHStation) -> void:
	var build = station._build
	t.check(build.panel != null and build.panel.get_child_count() >= 2, "a parede falsa está no pivô que desliza")
	var tiles: Texture2D = load("res://art/station/long_white_tiles.webp")
	var tiles_like: Array = build.panel_materials.filter(func(m): return m is ShaderMaterial and m.get_shader_parameter("albedo_tex") == tiles)
	t.check(not tiles_like.is_empty(), "com o azulejo da parede da plataforma")
	var signs: Array = build.panel.find_children("*", "Label3D", true, false)
	t.equal(signs.size(), 0, "sem letreiro na peça (o Mapa da Rede não desliza mais)")
	var half := B.SECRET_WALL_WIDTH * 0.005
	t.check(half > B.DOOR_WIDTH * 0.005, "fechada, ela cobre a porta e o batente")
	station._apply_panel(0.0)
	t.check(is_equal_approx(build.panel.position.x, AHStation.DOOR_X) and build.slit.visible, "fechada: no lugar, com a fresta de luz")
	station._apply_panel(1.0)
	t.check(is_equal_approx(build.panel.position.x, AHStation.DOOR_X - AHStation.PANEL_SLIDE) and not build.slit.visible,
		"aberta: andou PANEL_SLIDE para a esquerda, e a fresta some")
	t.check(build.panel_materials.all(func(m): return (m.get_shader_parameter("slide_offset") as Vector3).is_equal_approx(Vector3(-AHStation.PANEL_SLIDE, 0, 0))),
		"o azulejo e o concreto andam com a peça (slide_offset)")
	station._apply_panel(0.0)
	t.check(build.panel_materials.all(func(m): return (m.get_shader_parameter("slide_offset") as Vector3).is_zero_approx()),
		"fechada de novo, a textura volta ao lugar")


## A descida de verdade (da plataforma para os cômodos): a parede abre no começo, a câmera passa, e ela volta ao lugar.
func _descent(station: AHStation) -> void:
	var before := JSON.stringify(Campaign.state)
	station._go(station._platform_key(), true, true)
	await _tree.process_frame
	station.focus_overview()
	var opened := 0.0
	var lever_turned := false
	var end := Time.get_ticks_msec() + 30000
	while station.passage_moving() and Time.get_ticks_msec() < end:
		await _tree.process_frame
		opened = maxf(opened, station._panel_open)
		lever_turned = lever_turned or not station._build.lever.basis.is_equal_approx(Basis.IDENTITY)
	t.check(opened > 0.95 and lever_turned, "na descida, a parede abre inteira e a alavanca gira (%.2f)" % opened)
	t.check(is_equal_approx(station._build.panel.position.x, AHStation.DOOR_X) and station._build.slit.visible,
		"no fim, a parede volta ao lugar e a fresta acende de novo")
	t.equal(JSON.stringify(Campaign.state), before, "o save não muda com a passagem")


## O Mapa da Rede (o terminal da plataforma no #87) continua na Estação: fixo na parede, ao lado, legível.
func _network_map(station: AHStation) -> void:
	var labels: Array = station.find_children("*", "Label3D", true, false).filter(func(l): return (l as Label3D).text == "MAPA DA REDE")
	if not t.check(labels.size() == 1, "o Mapa da Rede continua na plataforma"):
		return
	var x: float = (labels[0] as Label3D).global_position.x
	var half := B.NETWORK_MAP_SIZE.x * 0.005
	var path_left := (B.DOOR_X - B.SECRET_WALL_WIDTH * 0.5 - B.PANEL_SLIDE) * 0.01
	t.check(not station._build.panel.is_ancestor_of(labels[0]), "fixo (fora da peça que desliza)")
	t.check(x + half < path_left and x - half > 16.22, "entre a pilastra e o caminho da parede falsa (%.2f m)" % x)
