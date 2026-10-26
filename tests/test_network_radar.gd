## O radar do Mapa da Rede (#87): ele lê da própria rota que a partida vai montar (a mesma semente), então o guardião,
## os inimigos das patrulhas, o clima e os pontos de busca batem com a fase; a leitura melhora com a Estação; a semente
## fica na campanha até a partida, e um save de antes dela abre normal.
extends RefCounted

const R := preload("res://scripts/flow/network_radar.gd")
const J := preload("res://scripts/flow/journey_rules.gd")
const S := preload("res://scripts/flow/station_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_truth()
	_states()
	_seeds()
	await _street_points()


## O que o radar lê é o que a fase tem: com a mesma semente, o guardião, os inimigos das patrulhas e o clima da rota que
## start_expedition monta; na rua, as casas que a cena sorteia.
func _truth() -> void:
	var wrong: Array = []
	for seed_value in [11, 4242, 90001, 123456]:
		for info in J.PHASES:
			var c: Dictionary = Campaign.create_initial(5)
			c.station.route_seeds = {info.id: seed_value}
			var read: Dictionary = R.reading(c, info.id)
			if not J.start_expedition(c, info.id, R.route_seed(c, info.id)):
				wrong.append("%s: a expedição não começou" % info.id)
				continue
			var expedition: Dictionary = c.session.expedition
			var route: Dictionary = expedition.corridor
			var guard: Array = J.corridor_enemies(expedition, route.steps.size() - 1)
			if read.boss.id != guard[0].enemy_id:
				wrong.append("%s/%d: guardião %s, o radar diz %s" % [info.id, seed_value, guard[0].enemy_id, read.boss.id])
			var counts := {}
			for index in route.steps.size():
				if route.steps[index].type == "combat":
					for unit in J.corridor_enemies(expedition, index):
						counts[unit.enemy_id] = int(counts.get(unit.enemy_id, 0)) + 1
			if counts != read.enemies.counts:
				wrong.append("%s/%d: patrulhas %s, o radar diz %s" % [info.id, seed_value, counts, read.enemies.counts])
			var top: String = read.enemies.ids[0]
			if counts.values().any(func(n): return n > counts[top]):
				wrong.append("%s/%d: o mais comum não vem primeiro" % [info.id, seed_value])
			if read.weather.id != route.weather:
				wrong.append("%s/%d: clima %s, o radar diz %s" % [info.id, seed_value, route.weather, read.weather.id])
	t.equal(wrong.slice(0, 6), [], "o guardião, os inimigos e o clima do radar são os da rota (4 sementes x 5 fases)")
	# A história: o radar diz "algo fala no rádio" só quando a Passagem da rota cai no mapa da fase (na travessia, o
	# evento não dispara). Andando a rota de verdade até a Passagem, o evento abre exatamente quando o radar disse.
	var lies: Array = []
	var both := {true: 0, false: 0}
	for phase_id in ["fase_2", "fase_3", "fase_5"]:
		for seed_value in range(60):
			var c: Dictionary = Campaign.create_initial(5)
			c.completed_phases = ["fase_1", "fase_2", "fase_3", "fase_4"]
			c.station.route_seeds = {phase_id: seed_value * 7919 + 13}
			var said: bool = R.reading(c, phase_id).story.has
			J.start_expedition(c, phase_id, R.route_seed(c, phase_id))
			var route: Dictionary = c.session.expedition.corridor
			var opened := false
			for index in range(1, route.steps.size()):
				if route.steps[index].type == "passage":
					route.index = index - 1
					route.steps[index - 1].resolved = true
					opened = J.enter_step(c, index) == "event"
			both[said] += 1
			if said != opened:
				lies.append("%s/%d: radar %s, evento %s" % [phase_id, seed_value, said, opened])
	t.equal(lies.slice(0, 5), [], "a história do radar é a da rota (a Passagem na travessia não tem o evento)")
	t.check(both[true] > 0 and both[false] > 0, "com rotas dos dois jeitos (%s)" % [both])


## A leitura melhora com a Estação: sem os cômodos, nada; a Pesquisa lê o guardião e os inimigos (a fase aberta inteira,
## a bloqueada só o sinal); o Depósito melhorado, os suprimentos; a Forja, a história e o clima; a fase concluída, tudo.
func _states() -> void:
	var c: Dictionary = Campaign.create_initial(5)
	var fresh: Dictionary = R.reading(c, "fase_1")
	t.check(R.PARTS.all(func(p): return fresh[p].state == "unknown"), "no começo, o radar não lê nada")
	c.station.rooms[S.RESEARCH] = 1
	var read: Dictionary = R.reading(c, "fase_1")
	t.check(read.boss.state == "known" and read.enemies.state == "known" and read.supplies.state == "unknown",
		"a Pesquisa recuperada lê o guardião e os inimigos")
	t.equal(R.reading(c, "fase_2").boss.state, "partial", "da fase bloqueada, só o sinal")
	c.station.rooms[S.DEPOT] = 2
	t.equal(R.reading(c, "fase_1").supplies.state, "known", "o Depósito melhorado lê os suprimentos")
	c.station.rooms[S.FORGE] = 1
	read = R.reading(c, "fase_1")
	t.check(read.story.state == "known" and read.weather.state == "known" and R.overall(read) == "known", "a Forja lê a história e o clima")
	var played: Dictionary = Campaign.create_initial(5)
	played.completed_phases = ["fase_1"]
	t.equal(R.overall(R.reading(played, "fase_1")), "known", "a fase concluída fica conhecida")
	t.equal(R.overall(R.reading(played, "fase_2")), "unknown", "e a outra, sem os cômodos, não")
	t.check(not R.reading(c, "fase_4").story.has, "a história: o Laboratório não tem")
	for room in [S.RESEARCH, S.DEPOT, S.FORGE]:
		t.check(R.room_reading(room) != "", "o %s diz o que lê no radar" % room)


## A semente: nasce na primeira leitura (um save sem a tabela abre normal), fica até a partida e sai com ela.
func _seeds() -> void:
	var c: Dictionary = Campaign.create_initial(5)
	c.station.erase("route_seeds")
	var first := R.route_seed(c, "fase_1")
	t.check(c.station.route_seeds.has("fase_1") and R.route_seed(c, "fase_1") == first, "a semente nasce na primeira leitura e fica")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c))
	t.equal(int(R.route_seed(saved, "fase_1")), first, "e volta do save")
	var before: Array = R.preview_route(c, "fase_1").steps
	t.equal(S.confirm_departure(c, ["hero_cao_bento", "hero_gato_nick", "hero_sapo_iris", "hero_coruja_vespera"].slice(0, J.team_limits("fase_1").max),
		0, R.route_seed(c, "fase_1"), "fase_1"), "", "a partida com a semente do radar")
	t.equal(c.session.expedition.corridor.steps, before, "a rota da partida é a que o radar leu")
	R.spend_seed(c, "fase_1")
	t.check(not c.station.route_seeds.has("fase_1"), "depois da partida, a fase ganha outra semente")


## Os pontos de busca: na rua montada, as casas sorteadas e os objetos dos trechos de suprimentos são os que o radar contou;
## num cenário, os objetos vasculháveis do mapa.
func _street_points() -> void:
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-radar-%d" % Time.get_ticks_usec()
	for phase_id in ["fase_1", "fase_3"]:
		var c: Dictionary = Campaign.create_initial(6)
		c.completed_phases = ["fase_1", "fase_2"]
		c.station.route_seeds = {phase_id: 5150}
		var read: Dictionary = R.reading(c, phase_id)
		J.start_expedition(c, phase_id, R.route_seed(c, phase_id))
		Campaign.state = c
		GameFlow.change_to("street", {}, false)
		var street = null
		for frame in 600:
			await _tree.process_frame
			if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.get("corridor") != null:
				street = _tree.current_scene
				break
		if not t.check(street != null, "a rua abre (%s)" % phase_id):
			continue
		var route: Dictionary = c.session.expedition.corridor
		var points: int
		if phase_id == "fase_1":
			points = route.steps.filter(func(s): return s.type == "loot").size()
			for site in route.sites:
				points += site.spots.size()
		else:
			points = street.corridor.scenario_props.size()
		t.equal(read.supplies.points, points, "os pontos de busca do radar são os da fase montada (%s)" % phase_id)
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
