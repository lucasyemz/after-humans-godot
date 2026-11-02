## A vista de fora na saída do trem (#217): a hora vem do ciclo da Estação (fim de tarde na volta, noite na cena da noite,
## amanhecer no resumo, dia no resto); a vista e a luz trocam com a hora, de uma vez ou com a transição; dá para ver a
## abertura da câmera da plataforma; a luz fica na ponta da plataforma; e o save não ganha nada.
extends RefCounted

const B = preload("res://scripts/station/station_build.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_hours()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-station-outside-%d" % Time.get_ticks_usec()
	Campaign.state = Campaign.create_initial(217)
	Campaign.state.station.last_return = {}
	GameFlow.change_to("station", {}, false)
	var station: AHStation = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene is AHStation and frame > 3:
			station = _tree.current_scene
			break
	if t.check(station != null, "a Estação abriu"):
		t.check(station.outside != null and station.outside.view != null and station.outside.light != null,
			"a vista de fora e a luz dela estão na Estação")
		t.equal(station.outside.hour, "day", "sem noite pendente, a Estação abre de dia")
		# O retrato depois de abrir (a chegada grava de propósito, com o tempo jogado de antes).
		var before := _state()
		_looks(station)
		await _follows(station)
		_framing(station)
		t.equal(_state(), before, "a vista não muda nada no save")
	AHStation.night_scene = false
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


## O estado da campanha sem o tempo jogado (que anda sozinho entre um teste e outro).
func _state() -> String:
	var copy: Dictionary = Campaign.state.duplicate(true)
	copy.erase("played_seconds")
	return JSON.stringify(copy)


## A hora pelo estado da noite e pela cena da noite; save sem a noite (antigo) é dia.
func _hours() -> void:
	var O := AHStationOutside
	t.equal(O.hour_of({"night": {"phase": "none"}}, false), "day", "sem noite: dia")
	t.equal(O.hour_of({"night": {"phase": "planning"}}, false), "dusk", "a volta, com a noite a planejar: fim de tarde")
	t.equal(O.hour_of({"night": {"phase": "dawn"}}, false), "dawn", "o resumo do amanhecer: amanhecer")
	t.equal(O.hour_of({"night": {"phase": "dawn"}}, true), "night", "a cena da noite passando: noite")
	t.equal(O.hour_of({"night": {"phase": "planning"}}, true), "night", "a cena da noite manda, qualquer que seja a fase")
	t.equal(O.hour_of({}, false), "day", "save sem a noite: dia")
	for hour in O.HOURS:
		t.check(O.LOOK.has(hour), "a hora %s tem a cor da vista e a luz" % hour)


## Cada hora mostra uma vista diferente: o dia é o mais claro, a noite a mais escura e com estrelas, e o amanhecer e o
## fim de tarde são quentes (mais vermelho que azul) e com o brilho no horizonte.
func _looks(station: AHStation) -> void:
	var seen := {}
	for hour in AHStationOutside.HOURS:
		station.outside.show_hour(hour, true)
		seen[hour] = station.outside.shown()
		t.equal(station.outside.hour, hour, "a vista mostra %s" % hour)
	var light := func(hour: String) -> float:
		var c: Color = seen[hour].tint
		return c.r + c.g + c.b
	t.check(light.call("day") > light.call("dusk") and light.call("day") > light.call("dawn"), "o dia é o mais claro")
	t.check(light.call("night") < light.call("dawn") * 0.6 and light.call("night") < light.call("dusk") * 0.6,
		"a noite é bem mais escura que o amanhecer e o fim de tarde")
	for hour in ["dawn", "dusk"]:
		var c: Color = seen[hour].tint
		t.check(c.r > c.b + 0.1, "%s é quente na vista" % hour)
		t.check(Color(seen[hour].glow).a > 0.2, "%s tem o brilho no horizonte" % hour)
		t.check(Color(seen[hour].light).r > Color(seen[hour].light).b, "a luz que entra em %s é quente" % hour)
	t.check(float(seen.night.stars) > 0.5 and float(seen.day.stars) == 0.0, "estrelas só à noite (e um resto no amanhecer)")
	t.check(Color(seen.night.light).b > Color(seen.night.light).r, "a luz da noite é fria")
	t.check(float(seen.night.energy) < float(seen.dusk.energy) and float(seen.dusk.energy) < float(seen.day.energy),
		"a luz que entra é mais forte de dia e fraca à noite")
	for hour in seen:
		t.check(float(seen[hour].energy) <= 2.0, "a luz de %s é leve (não muda o resto da Estação)" % hour)
		var shaft: Color = seen[hour].beam
		t.check(shaft.a > 0.0 and shaft.a <= 0.3, "o feixe de %s aparece, de leve" % hour)
		t.check(Color(seen[hour].tint).r <= 1.0 and Color(seen[hour].tint).g <= 1.0, "o céu de %s fica abaixo do glow" % hour)
	t.check(Color(seen.day.beam).a > Color(seen.night.beam).a * 2.0, "o feixe é bem mais forte de dia que à noite")
	t.check(Color(seen.dusk.beam).r > Color(seen.dusk.beam).b, "o feixe do fim de tarde é quente")


## A Estação acompanha o ciclo sozinha: a volta (fim de tarde), a cena da noite (noite), o amanhecer e o dia.
func _follows(station: AHStation) -> void:
	station.refresh_outside(true)
	Campaign.state.night.phase = "planning"
	await _tree.process_frame
	t.equal(station.outside.hour, "dusk", "a volta com a noite a planejar vira fim de tarde")
	# O HUD liga a cena da noite direto (AHStation.night_scene) e a Estação acompanha no quadro seguinte.
	AHStation.night_scene = true
	await _tree.process_frame
	t.equal(station.outside.hour, "night", "a cena da noite vira noite")
	# A troca é suave: no começo ainda está perto do fim de tarde; no fim chega à cor da noite.
	await _tree.create_timer(AHStationOutside.FADE + 0.4).timeout
	t.check(Color(station.outside.shown().tint).is_equal_approx(_tint("night")), "terminada a transição, a vista é a da noite")
	Campaign.state.night.phase = "dawn"
	station.set_night_scene(false)
	t.check(not AHStation.night_scene, "a cena da noite acabou")
	await _tree.process_frame
	t.equal(station.outside.hour, "dawn", "acabada a cena, o resumo do amanhecer é amanhecer")
	Campaign.state.night.phase = "none"
	await _tree.process_frame
	t.equal(station.outside.hour, "day", "fechado o amanhecer, é dia")
	Campaign.state.night.phase = "none"
	station.refresh_outside(true)


func _tint(hour: String) -> Color:
	var look: Dictionary = AHStationOutside.LOOK[hour]
	return look.tint * look.brightness


## Da câmera da plataforma, a abertura aparece na tela (no alto, à esquerda); a vista fica logo atrás do corte, no vão
## da abóbada e fora do salão; e a luz alcança só a ponta da plataforma, longe dos cômodos de baixo e do fim da plataforma.
func _framing(station: AHStation) -> void:
	station._set_goal(station._platform_key(), true)
	station._apply_key(station._platform_key())
	var camera: Camera3D = station.camera
	var view: MeshInstance3D = station.outside.view
	var mid := AHStationBuilder.v((B.OUTSIDE_X0 + B.OUTSIDE_X1) * 0.5, -200.0, B.vault_z(-200.0))
	t.check(camera.is_position_in_frustum(mid), "a câmera da plataforma vê a abertura")
	var size := station.get_viewport().get_visible_rect().size
	var on_screen := camera.unproject_position(mid)
	t.check(on_screen.x > 0.0 and on_screen.x < size.x * 0.5 and on_screen.y > 0.0 and on_screen.y < size.y * 0.5,
		"a abertura fica no alto, à esquerda da vista da plataforma (%s)" % [on_screen])
	var gap_back := AHStationBuilder.v(0, B.STATION_BACK * B.OUTSIDE_SEGMENTS / 16.0, 0).z
	t.check(view.global_position.z <= 0.0 and view.global_position.z > gap_back, "a vista fica logo atrás do corte, no vão")
	# Nunca dentro do salão: o pé da vista fica acima da abóbada naquela profundidade (senão tapava a parede e o trem).
	var depth_cm := view.global_position.z * 100.0
	var bottom := view.global_position.y - (view.mesh as QuadMesh).size.y * 0.5
	t.check(bottom >= AHStationBuilder.v(0, 0, B.vault_z(depth_cm)).y, "a vista não desce para dentro do salão")
	t.check(bottom < AHStationBuilder.v(0, 0, B.vault_z(depth_cm) + 10.0).y, "e começa colada na abóbada (sem fresta escura)")
	var x0 := AHStationBuilder.v(B.OUTSIDE_X0, 0, 0).x
	var x1 := AHStationBuilder.v(B.OUTSIDE_X1, 0, 0).x
	var half := (view.mesh as QuadMesh).size * 0.5
	t.check(view.global_position.x - half.x >= x0 - 0.001 and view.global_position.x + half.x <= x1 + 0.001,
		"a vista não passa dos lados da moldura")
	t.check(view.global_position.y + half.y <= AHStationBuilder.v(0, 0, B.OUTSIDE_TOP).y + 0.001,
		"nem do lintel (o contorno da Estação na câmera da plataforma)")
	t.check(B.OUTSIDE_TOP < B.VAULT_SPRING + B.VAULT_RISE, "o lintel fica abaixo da coroa da abóbada")
	t.check(B.OUTSIDE_SEGMENTS < 16 and B.OUTSIDE_X1 < B.TRACK_END * 0.3, "a abertura é curta e fica na saída do trem")
	var shaft: MeshInstance3D = station.outside.beam
	t.check(shaft.global_position.z > AHStationBuilder.v(0, -340, 0).z, "o feixe desce na frente do vagão")
	t.check(shaft.global_position.y - (shaft.mesh as QuadMesh).size.y * 0.5 < AHStationBuilder.v(0, 0, 0).y,
		"até a via (abaixo da plataforma)")
	var light := station.outside.light
	t.check(light.global_position.x + light.spot_range < AHStationBuilder.v(B.TRACK_END, 0, 0).x,
		"a luz de fora não chega ao fim da plataforma")
	t.check(not light.shadow_enabled, "a luz de fora não pesa com sombra")
