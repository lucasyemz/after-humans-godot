## A partida no vagão (#75): ao confirmar a Preparação, a passagem mostra a equipe escolhida no vagão em movimento e
## termina no título da fase, que abre o mapa.
## - A equipe certa no vagão (1 a 4 heróis): os fundadores sentados (pose *_seat), os recrutas de pé nas pontas; os
##   mortos e quem ficou na Estação não aparecem.
## - O título da fase só depois do passeio; "Reduzir efeitos" tira o vagão (só o título).
## - Pular abre a mesma fase; sem pular, também.
## - Um save gravado no meio da passagem abre direto na fase.
extends RefCounted

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-departure-%d" % Time.get_ticks_usec()
	var tips: bool = Tips.enabled
	Tips.enabled = false
	await _teams()
	await _departure("none")
	await _departure("late")
	await _departure("early")
	_reduced()
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


## Uma campanha com os quatro fundadores e dois recrutas (um cão e um gato).
func _campaign() -> Dictionary:
	var c: Dictionary = Campaign.create_initial(31)
	# O Alojamento ampliado (#119): cabem os recrutas.
	c.station.rooms[AHStationRules.CHARACTERS] = 4
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	# Quatro recrutas direto no elenco, como num save antigo (o recrutamento não repete rosto, #182).
	for class_id in ["cao", "gato", "cao", "gato"]:
		AHStationRules._add_hero(c, AHStationRules._next_hero_id(c, class_id), class_id, "Teste", [], "")
	return c


func _teams() -> void:
	var c := _campaign()
	Campaign.state = c
	var founders: Array = c.roster.slice(0, 4).map(func(h): return h.id)
	var recruits: Array = c.roster.slice(4).map(func(h): return h.id)
	for team in [founders.slice(0, 1), founders.slice(0, 2), founders, [founders[0], recruits[0], founders[1], recruits[1]], recruits.slice(0, 1),
			recruits, [recruits[0], founders[0], founders[1], founders[2]], [founders[0], recruits[0], recruits[1], recruits[2]]]:
		var ride := AHWagonRide.new(team)
		_tree.root.add_child(ride)
		await _tree.process_frame
		var ids: Array = ride.seats.map(func(s): return s.id)
		ids.sort()
		var want: Array = team.duplicate()
		want.sort()
		t.equal(ids, want, "a equipe certa no vagão (%d)" % team.size())
		t.check(ride.seats.all(func(s): return s.seated == founders.has(s.id)), "os fundadores sentados e os recrutas de pé (%s)" % [team])
		# Quem está de pé fica nas pontas: entre dois sentados não há ninguém de pé.
		var shape: String = "".join(ride.seats.map(func(s): return "s" if s.seated else "p"))
		t.check(_edges_only(shape), "os de pé nas pontas do banco (%s)" % shape)
		var xs: Array = ride.seats.map(func(s): return s.card.position.x)
		t.check(xs.all(func(x): return x >= AHWagonRide.FRAME_X[0] and x <= AHWagonRide.FRAME_X[1]), "todos no quadro (%s)" % [xs])
		var sitting: Array = ride.seats.filter(func(s): return s.seated)
		t.check(sitting.all(_on_bench), "os sentados dentro do assento (%s)" % [xs])
		var standing: Array = ride.seats.filter(func(s): return not s.seated)
		var apart := true
		for a in standing:
			for b in ride.seats:
				if a != b and absf(a.card.position.x - b.card.position.x) < (AHWagonRide.STAND_SLOT if not b.seated else (AHWagonRide.STAND_SLOT + AHWagonRide.SEAT_SLOT) * 0.5) - 0.01:
					apart = false
		t.check(apart, "quem está de pé não se sobrepõe a ninguém (%s)" % [xs])
		# A posição 1 fica à direita dos seus: dos sentados, se está sentada; de todos, se está de pé.
		var first: Dictionary = ride.seats.filter(func(s): return s.id == team[0])[0]
		var group: Array = sitting if first.seated else ride.seats
		t.check(group.all(func(s): return s.card.position.x <= first.card.position.x), "a posição 1 à direita (%s)" % [team])
		t.check(ride.seats.all(func(s): return is_instance_valid(s.card) and s.card.mesh != null and s.card._texture != null),
			"cada um com a arte carregada")
		_floor_beyond_near(ride)
		ride.free()
	# Os mortos não embarcam.
	c.roster[1].alive = false
	var ride := AHWagonRide.new(founders.slice(0, 2))
	_tree.root.add_child(ride)
	await _tree.process_frame
	t.equal(ride.seats.map(func(s): return s.id), [founders[0]], "quem morreu não aparece no vagão")
	ride.free()


## O chão que aparece nos cantos de baixo da tela fica além do corte da câmera (senão a borda de baixo mostra o vazio
## embaixo do chão), com folga para o balanço.
func _floor_beyond_near(ride: AHWagonRide) -> void:
	var camera: Camera3D = ride._camera
	var view := camera.get_viewport().get_visible_rect().size
	var worst := INF
	for point in [Vector2(0, view.y - 1), Vector2(view.x * 0.5, view.y - 1), Vector2(view.x - 1, view.y - 1)]:
		var origin := camera.project_ray_origin(point)
		var normal := camera.project_ray_normal(point)
		if normal.y >= 0.0:
			continue
		var hit := origin + normal * ((AHWagonRide.FLOOR_Y - origin.y) / normal.y)
		worst = minf(worst, (hit - camera.global_position).dot(-camera.global_basis.z))
	t.check(worst >= camera.near + 0.05, "o chão da borda de baixo fica além do corte da câmera (%.2f m; corte %.2f m)" % [worst, camera.near])


func _on_bench(spot: Dictionary) -> bool:
	var x: float = spot.card.position.x
	return x >= AHWagonRide.BENCH_START and x <= AHWagonRide.BENCH_END


func _edges_only(shape: String) -> bool:
	var inner := shape.strip_edges()
	while inner.begins_with("p"):
		inner = inner.substr(1)
	while inner.ends_with("p"):
		inner = inner.left(-1)
	return not inner.contains("p")


## Da Estação para a fase pela Preparação confirmada: o vagão, o título da fase depois e a rua aberta na fase certa. O
## save no meio da passagem já é o da expedição: reaberto, segue para a rua.
## skip: "none" (sem pular), "late" (pula com a fase montada) ou "early" (pula no meio do passeio).
func _departure(skip: String) -> void:
	Campaign.state = _campaign()
	Campaign.save()
	GameFlow.change_to("station", {}, false)
	await _settle()
	var station = _tree.current_scene
	if not t.check(station != null and station.name == "Station", "a Estação abre"):
		return
	var c: Dictionary = Campaign.state
	var team: Array = c.roster.slice(0, 3).map(func(h): return h.id)
	team.append(c.roster[4].id)
	station.hud._draft = {"phase": "fase_1", "team": team, "focus": "", "extra": 0}
	# O briefing (#88) abre na chegada à plataforma (test_briefing); a confirmação parte direto.
	station.hud._depart()
	while GameFlow.passage == null:
		await _tree.process_frame
	var card: AHPassageCard = GameFlow.passage
	t.check(card.backdrop is AHWagonRide, "a passagem da partida mostra o vagão")
	var ride: AHWagonRide = card.backdrop
	var ids: Array = ride.seats.map(func(s): return s.id)
	ids.sort()
	team.sort()
	t.equal(ids, team, "a equipe da Preparação no vagão")
	t.equal(card.title, "Rua das Vitrines", "o título da fase")
	var band: Control = card.find_child("Title", true, false).get_parent().get_parent()
	await _tree.process_frame
	t.check(band.modulate.a < 0.05, "o título espera o passeio no vagão")
	# O save gravado agora (o jogo fecha no meio da passagem) já é a expedição: reaberto, vai direto para a rua.
	var disk = Campaign.read_file(Campaign.primary_path())
	var session: Dictionary = disk.get("session", {}) if disk is Dictionary else {}
	t.check(session.get("expedition") != null and session.get("result", "x") == "", "o save do meio da passagem é o da expedição")
	var expedition_id: String = Campaign.state.session.expedition.id
	var opened := Time.get_ticks_msec()
	if skip == "early":
		# A carência: o Interagir apertado logo que o cartão abre (o duplo da confirmação) não pula, e a dica ainda não
		# diz que dá.
		t.check(card.find_child("Hint", true, false).get_child_count() == 1, "na carência, a dica ainda não mostra pular")
		await _press("interact")
		t.check(not card.skip_requested, "pular logo que o cartão abre não vale (a carência de %d ms)" % AHPassageCard.SKIP_GRACE_MS)
		# Pular no meio do passeio encerra o passeio: o título acende na hora, a fase monta e a passagem fecha.
		while (Time.get_ticks_msec() - opened) < 400:
			await _tree.process_frame
		t.check(card.find_child("Hint", true, false).get_child_count() >= 2, "no passeio, a dica já diz que dá para pular")
		await _press("interact")
		t.check(card.skip_requested and card.title_lit, "pular no passeio acende o título na hora")
	else:
		# A rua só monta (o quadro travado) depois do passeio, com o título aceso: o vagão anda liso até lá.
		while is_instance_valid(card) and not card.ready_to_skip and GameFlow.busy:
			await _tree.process_frame
		t.check((Time.get_ticks_msec() - opened) / 1000.0 >= AHWagonRide.RIDE_SECONDS, "a fase monta só depois do passeio no vagão")
	if skip == "late":
		await _press("interact")
	var lit := false
	while GameFlow.busy:
		if GameFlow.passage != null:
			lit = GameFlow.passage.title_lit
		await _tree.process_frame
	var elapsed := (Time.get_ticks_msec() - opened) / 1000.0
	if skip == "none":
		t.check(lit, "o cartão só fecha com o título da fase aceso")
	if skip == "early":
		t.check(elapsed < AHWagonRide.RIDE_SECONDS, "pulada no passeio, a fase abre antes do fim do passeio (%.2f s)" % elapsed)
	var street = _tree.current_scene
	t.check(street != null and street.name == "Street" and Campaign.state.session.expedition.id == expedition_id
		and Campaign.state.session.expedition.phase_id == "fase_1", "%s, a passagem abre a fase" % {"none": "sem pular", "late": "pulada", "early": "pulada no passeio"}[skip])
	if skip == "none":
		t.check(elapsed >= AHWagonRide.RIDE_SECONDS + GameFlow.CARD_SECONDS, "sem pular, o vagão e o título ficam %.1f s (%.2f s)" % [AHWagonRide.RIDE_SECONDS + GameFlow.CARD_SECONDS, elapsed])
	# Reaberto do save do meio: o Continuar segue para a rua.
	Campaign.state = disk
	var target: bool = Campaign.state.session.get("expedition") != null and Campaign.state.session.get("result", "") == ""
	t.check(target, "o Continuar do save do meio abre a fase")


## Com "Reduzir efeitos", o vagão não entra: só o título, logo.
func _reduced() -> void:
	var c := _campaign()
	Campaign.state = c
	AHJourneyRules.start_expedition(c, "fase_1", 9)
	var card := AHWagonRide.departure_card(c)
	t.check(card.backdrop is AHWagonRide and card.title_delay > 0.0 and card.hold > GameFlow.CARD_SECONDS, "o cartão da partida tem o vagão e o passeio")
	var still := AHPassageCard.new(card, true)
	t.check(still.title_delay == 0.0 or still.backdrop != null, "o cartão lê o atraso do título")
	_tree.root.add_child(still)
	t.check(still.backdrop == null and still.title_delay == 0.0, "com Reduzir efeitos, sem o vagão e sem esperar o título")
	still.free()


func _settle() -> void:
	for i in 10:
		await _tree.process_frame
	while GameFlow.busy:
		await _tree.process_frame
	for i in 3:
		await _tree.process_frame


func _press(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		_tree.root.push_input(event)
		await _tree.process_frame
