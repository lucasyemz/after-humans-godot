## A Estação em grade na cena (#186; a cena, #273): cada cômodo na vaga dele (6 m ou 12 m, 3,2 m de altura, dentro da
## grade e sem encostar em outro); o Alojamento e o Bar com 6 m, a Forja e a Enfermaria com 12 m; o fogareiro, os
## caixotes e a Preparação na plataforma até a Cantina e o Depósito serem construídos; os blocos soterrados, a escavação
## em um terço e dois terços e a vaga livre; os patamares; na cena, só os cômodos com lugar montados, a remontagem quando
## um cômodo é construído (o mobiliário, as luzes, o estoque e os moradores no lugar novo), os lugares de dormir, os
## leitos e o banco seguindo a vaga, e a vista geral descendo até o 3º subsolo.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const G = preload("res://scripts/flow/station_grid.gd")
const L = preload("res://scripts/station/station_layout.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_new_campaign()
	_legacy()
	_blocks()
	await _scene()


## A campanha nova (#186, opção A): a Forja parada nas vagas 3 e 4, o Alojamento na 5 e o Dormitório na 6 e 7 do 1º
## subsolo; a Cantina, o Depósito e a Preparação na plataforma; o resto sem lugar.
func _new_campaign() -> void:
	var c := Campaign.create_initial(273)
	var forge := L.room(c, S.FORGE)
	t.equal([forge.x0, forge.x1, forge.floor, forge.ceiling], [L.slot_x0(3), L.slot_x0(3) + 1200.0, -520.0, -200.0],
		"a Forja parada: 12 m e 3,2 m, nas vagas 3 e 4 do 1º subsolo")
	var characters := L.room(c, S.CHARACTERS)
	t.equal([characters.x0, characters.x1 - characters.x0], [L.slot_x0(5), 600.0], "o Alojamento: 6 m, na vaga 5")
	var dorm := L.room(c, S.DORMITORY)
	t.equal([dorm.x0, dorm.x1], [L.slot_x0(6), L.STATION_END], "o Dormitório encosta na escada (vagas 6 e 7)")
	for id in [S.CANTEEN, S.DEPOT, S.PREPARATION]:
		var nook := L.room(c, id)
		t.check(nook.get("place", "") == "platform" and nook.floor == 0.0, "%s na plataforma" % id)
	for id in [S.BAR, S.RESEARCH, S.INFIRMARY]:
		t.check(L.room(c, id).is_empty(), "%s ainda sem lugar (soterrado)" % id)
	_fits(c, "campanha nova")
	# O mobiliário vai junto: o deslocamento leva o molde até a vaga.
	t.equal(dorm.offset, Vector3(L.slot_x0(6) - L.TEMPLATES.dormitory.x0, 0, 0), "o Dormitório deslocado do molde até a vaga 6")
	t.check(dorm.lane[0] >= dorm.x0 and dorm.lane[1] <= dorm.x1, "a faixa de passeio dentro do Dormitório")


## Um save de antes da grade: a planta herdada, com a Forja de 12 m e 3,2 m (1 m mais baixa) e a Enfermaria de 12 m.
func _legacy() -> void:
	var c := Campaign.create_initial(274)
	for id in [S.FORGE, S.RESEARCH, S.BAR]:
		c.station.rooms[id] = 1
	c.station.rooms[S.INFIRMARY] = 2
	c.station.rooms[S.DEPOT] = 2
	c.station.erase("grid")
	G.migrate(c)
	var forge := L.room(c, S.FORGE)
	t.equal([forge.x1 - forge.x0, forge.ceiling - forge.floor, forge.floor], [1200.0, 320.0, -940.0],
		"a Forja herdada: 12 m, 3,2 m de altura, no 2º subsolo")
	var infirmary := L.room(c, S.INFIRMARY)
	t.equal([infirmary.x0, infirmary.x1 - infirmary.x0], [L.GRID_X0, 1200.0], "a Enfermaria de 12 m (#139), na ponta do 2º subsolo")
	t.equal(infirmary.offset, Vector3(L.GRID_X0 - L.TEMPLATES.infirmary.x0, 0, 0), "os leitos deslocados com ela")
	t.equal(L.room(c, S.BAR).x1 - L.room(c, S.BAR).x0, 600.0, "o Bar: 6 m")
	t.equal(L.room(c, S.DEPOT).get("place", ""), "grid", "o Depósito no nível 2 fica na vaga dele")
	t.equal(L.room(c, S.CANTEEN).get("place", ""), "grid", "a Cantina construída (nível 2) fica na vaga dupla")
	_fits(c, "planta herdada")
	var free: Array = L.blocks(c).filter(func(b): return b.state == "free")
	t.equal(free.map(func(b): return b.key), ["1:7"], "a vaga que sobra no 1º subsolo fica livre")
	t.check(L.landing_open(c, 2) and not L.landing_open(c, 3), "o patamar do 2º subsolo aberto, o do 3º soterrado")


## Os cômodos dentro da grade, do tamanho da vaga, sem encostar um no outro.
func _fits(c: Dictionary, label: String) -> void:
	var placed: Array = L.rooms(c).filter(func(r): return r.place == "grid")
	var ok := true
	for room in placed:
		var width: float = room.x1 - room.x0
		ok = ok and room.x0 >= L.GRID_X0 and room.x1 <= L.STATION_END and width == L.SLOT * G.room_slots(room.id)
		ok = ok and is_equal_approx(room.ceiling - room.floor, L.HEIGHT) and room.door >= room.x0 + 15.0 and room.door + 135.0 <= room.x1
		for other in placed:
			if other != room and other.floor == room.floor and other.x0 < room.x1 and room.x0 < other.x1:
				ok = false
	t.check(ok, "%s: cada cômodo na vaga dele, com a porta dentro, sem sobrepor outro" % label)


## Os blocos: a frente soterrada, a escavação em um terço e dois terços (do lado aberto) e a vaga livre.
func _blocks() -> void:
	var c := Campaign.create_initial(275)
	var buried: Array = L.blocks(c)
	t.equal(buried.size(), 2 + 14, "na campanha nova, 2 vagas soterradas no 1º subsolo e os dois andares de baixo")
	t.check(buried.all(func(b): return b.state == "buried"), "tudo soterrado antes da primeira volta")
	c.station.grid.target = "1:2"
	c.station.grid.progress["1:2"] = 1
	var digging: Dictionary = L.blocks(c).filter(func(b): return b.key == "1:2")[0]
	t.equal([digging.state, digging.stage, digging.from], ["digging", 1, 1], "1 de 2 pontos: um terço cavado, do lado da Forja")
	c.station.grid.progress["1:2"] = 2
	t.equal(L.dig_stage(c, "1:2"), 2, "e dois terços com a obra quase no fim")
	c.station.grid.cells[0][1] = G.FREE
	c.station.grid.progress.erase("1:2")
	var before := L.signature(c)
	t.equal(L.blocks(c).filter(func(b): return b.key == "1:2")[0].state, "free", "aberto, o bloco vira a vaga livre")
	c.station.grid.target = "1:1"
	c.station.grid.progress["1:1"] = 1
	t.check(L.signature(c) != before, "a escavação passando de um terço muda o que a cena mostra")
	t.equal(L.blocks(c).filter(func(b): return b.key == "1:1")[0].from, 1, "a vaga 1 é cavada a partir da vaga livre à direita")
	# Trocada a frente, a obra começada continua à vista (a regra guarda o que já foi cavado).
	c.station.grid.target = "L2"
	t.equal(L.blocks(c).filter(func(b): return b.key == "1:1")[0].state, "digging", "com a frente no patamar, a vaga 1 continua meio cavada")


## A cena: só os cômodos com lugar são montados; construído o Bar na vaga livre, a cena remonta e ele aparece lá.
func _scene() -> void:
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-station-layout-%d" % Time.get_ticks_usec()
	var c := Campaign.create_initial(276)
	# Os três moradores: a Cora é da Pesquisa, ainda soterrada.
	c.station.residents = [S.DORA, S.OTTO, S.CORA]
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("station", {}, false)
	var station = null
	for i in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene is AHStation and _tree.current_scene.hud != null:
			station = _tree.current_scene
			break
	if t.check(station != null, "a Estação abriu"):
		await _station(station, c)
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


func _station(station, c: Dictionary) -> void:
	var build: AHStationBuild = station._build
	t.check(build.grid_root != null and build.grid_root.get_child_count() > 0, "a grade montada")
	t.check(not build.dressing.has(S.BAR) and not build.room_lights.has(S.BAR), "o Bar soterrado: nada dele na cena")
	t.check(build.dressing.has(S.CANTEEN) and build.stove_light != null, "o fogareiro da plataforma (a Cantina de nível 1)")
	t.check(not build.stock.is_empty(), "as luzes do estoque nos caixotes da plataforma")
	t.check(station.rooms().map(func(r): return r.id).has(S.DEPOT), "o Depósito tem lugar (os caixotes)")
	# Os lugares seguem a vaga: quem dorme no Dormitório, o banco do fogareiro na plataforma.
	var dorm: Dictionary = station.room_def(S.DORMITORY)
	t.check(AHStation.sleep_slots(1).all(func(p): return p.x > dorm.x0 and p.x < dorm.x1 and is_equal_approx(p.y, dorm.floor)),
		"os lugares de dormir dentro do Dormitório (%.1f a %.1f m)" % [dorm.x0, dorm.x1])
	t.check(AHStation.canteen_seats().all(func(p): return p.y == 0.0 and p.z < -8.0), "o banco da Cantina é o do fogareiro, na plataforma")
	# A Cora, com a Pesquisa soterrada, fica no Alojamento; a Dora, no fogareiro da plataforma.
	var cora = station.residents.get(S.CORA)
	var characters: Dictionary = station.room_def(S.CHARACTERS)
	t.check(cora != null and cora.position.x >= characters.x0 and cora.position.x <= characters.x1 and is_equal_approx(cora.position.y, characters.floor),
		"a moradora da Pesquisa soterrada fica no Alojamento")
	var dora = station.residents.get(S.DORA)
	t.check(dora != null and dora.visible and dora.position.y == 0.0, "a Dora no fogareiro, à vista")
	# Com a fila do relatório na plataforma, quem mora nos cantos dela sai de cena (ninguém atrás da fila).
	station.show_report([c.roster[0].id], true)
	await _frames(2)
	t.check(not dora.visible, "a fila do relatório na plataforma: a Dora sai de cena")
	station.clear_lineup()
	await _frames(2)
	t.check(dora.visible, "e volta quando a fila sai")
	# Um cômodo soterrado escolhido (o Ver do Plano): a câmera vai para a vista geral, não fica no cômodo de antes.
	station.focus_room(S.CHARACTERS, true)
	station.focus_room(S.RESEARCH, true)
	t.check(station._in_overview, "a Pesquisa soterrada: a vista geral")
	# A vista geral desce até o 3º subsolo, sem passar do limite.
	station.focus_overview(true)
	station.set_pan(station.pan, -100.0)
	t.equal(station.pan_y, AHStation.PAN_Y_RANGE.x, "a vista desce até o limite do 3º subsolo")
	station.set_pan(station.pan, 0.0)
	# Construir o Bar numa vaga livre: a cena remonta, com o Bar na vaga.
	c.station.grid.cells[0][1] = G.FREE
	c.inventory.scrap = 20
	c.inventory.fragments = 5
	station.commit()
	await _frames(2)
	t.equal(S.build_room(c, S.BAR, "1:2"), "", "o Bar construído na vaga 2")
	station.commit()
	await _frames(3)
	var bar: Dictionary = station.room_def(S.BAR)
	t.check(not bar.is_empty() and is_equal_approx(bar.x0, L.slot_x0(2) * 0.01), "o Bar na vaga 2 (%s)" % bar)
	t.check(build.dressing.has(S.BAR) and build.room_lights.has(S.BAR), "a cena remontou com o mobiliário e a luz do Bar")
	var lamp: OmniLight3D = build.room_lights.get(S.BAR)
	t.check(lamp != null and lamp.position.x > bar.x0 and lamp.position.x < bar.x1, "a luz do Bar dentro da vaga")
	t.check(station.room_screen_rects().has(S.BAR) or not station.camera_settled(), "o Bar entra na seleção da vista geral")
	var residents_ok := true
	for walker in station._walkers:
		if walker.has("hero_id") and walker.get("room", "") != "":
			var room: Dictionary = station.room_def(walker.room)
			residents_ok = residents_ok and not room.is_empty() and walker.card.position.x >= room.x0 and walker.card.position.x <= room.x1
	t.check(residents_ok, "os moradores refeitos nos cômodos de agora")
	# A Cantina construída sai da plataforma: o fogareiro some e o banco é o da mesa.
	c.station.grid.cells[2][0] = G.FREE
	c.station.grid.cells[2][1] = G.FREE
	c.station.grid.landings = [true, true]
	c.inventory.scrap = 20
	t.equal(S.build_room(c, S.CANTEEN, "3:1"), "", "a Cantina construída no 3º subsolo")
	station.commit()
	await _frames(3)
	t.check(build.stove_light == null, "o fogareiro sai da plataforma")
	var canteen: Dictionary = station.room_def(S.CANTEEN)
	t.check(AHStation.canteen_seats().all(func(p): return p.x > canteen.x0 and p.x < canteen.x1), "o banco da mesa, na Cantina do 3º subsolo")
	station.pan_to_room(S.CANTEEN, 400.0, 1900.0)
	t.equal(station.pan_y, AHStation.PAN_Y_RANGE.x, "escolhido um cômodo do 3º subsolo, a vista desce até ele")


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
