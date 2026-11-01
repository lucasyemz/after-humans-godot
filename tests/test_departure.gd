## A partida no vagão (#75): ao confirmar a Preparação, a passagem mostra a equipe escolhida no vagão em movimento e
## termina no título da fase, que abre o mapa.
## - A equipe certa no vagão (1 a 4 heróis): os fundadores sentados de frente (pose *_seat_front, #256) nos lugares do
##   contrato, os recrutas de pé na frente do lugar; os mortos e quem ficou na Estação não aparecem.
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
	await _sparks()
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
	# O contrato que vai no jogo é a cópia do design (docs fica fora da exportação).
	var design = JSON.parse_string(FileAccess.get_file_as_string("res://docs/design/trem-2d/contract.json"))
	t.check(design != null and design == AHTrainCar.contract(), "data/presentation/train_2d.json é igual ao contrato do design")
	var contract: Dictionary = AHTrainCar.contract().passage
	var slots: Array = contract.seats.map(func(seat): return float(seat.seat_support[0]))
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
		t.check(ride.seats.all(func(s): return s.seated == founders.has(s.id)), "os fundadores sentados de frente e os recrutas de pé (%s)" % [team])
		# Cada um no vão de um lugar do contrato (entre as barras), sem dois no mesmo.
		var used: Array = []
		for s in ride.seats:
			var hit: Array = slots.filter(func(x): return _covers(s.card, x))
			if hit.size() >= 1 and not used.has(hit[0]):
				used.append(hit[0])
		t.equal(used.size(), ride.seats.size(), "cada um no vão do seu lugar (%s)" % [team])
		t.check(ride.seats.filter(func(s): return s.seated).all(func(s): return _hip_on_seat(s, contract)), "o quadril de quem senta no assento")
		# A posição 1 fica no lugar mais à direita.
		t.equal(ride.seats[-1].id, team[0], "a posição 1 à direita (%s)" % [team])
		t.check(ride.seats.all(func(s): return is_instance_valid(s.card) and s.card.texture != null), "cada um com a arte carregada")
		ride.free()
	# Os mortos não embarcam.
	c.roster[1].alive = false
	var ride := AHWagonRide.new(founders.slice(0, 2))
	_tree.root.add_child(ride)
	await _tree.process_frame
	t.equal(ride.seats.map(func(s): return s.id), [founders[0]], "quem morreu não aparece no vagão")
	ride.free()
	c.roster[1].alive = true
	# As poses sentadas pela direção do banco (#253): de lado na cantina, de frente (com o ponto hip) no vagão.
	var poses: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/station_poses.json"))
	for hero_id in founders:
		t.equal(String(poses[hero_id + "_seat"].get("facing", "")), "side", "%s: a pose sentada da cantina é de lado" % hero_id)
		var front: Dictionary = poses.get(hero_id + "_seat_front", {})
		t.check(front.get("facing", "") == "front" and front.has("hip") and ResourceLoader.exists(String(front.get("file", ""))),
			"%s: a de frente existe, com o ponto hip" % hero_id)
		t.equal(AHSkins.seat_pose(poses, hero_id, "front").get("file", ""), front.get("file", ""), "e é a que o banco de frente pede")
	# A skin sem a pose de frente (a Ronda do Bento, #253): de pé na skin, e não sentado na roupa padrão.
	c.roster[0].skin_id = "bento_watch"
	ride = AHWagonRide.new(founders.slice(0, 1))
	_tree.root.add_child(ride)
	await _tree.process_frame
	t.check(not ride.seats[0].seated and String(ride.seats[0].card.texture.resource_path).contains("skins/bento/watch"),
		"o Bento de Ronda fica de pé, na Ronda")
	ride.free()
	c.roster[0].erase("skin_id")


## O Sprite2D cobre o x (px no quadro).
func _covers(card: Sprite2D, x: float) -> bool:
	var left := card.position.x
	return x > left and x < left + card.texture.get_width() * card.scale.x


func _hip_on_seat(spot: Dictionary, contract: Dictionary) -> bool:
	var poses: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/station_poses.json"))
	var pose: Dictionary = poses[String(spot.id) + "_seat_front"]
	var card: Sprite2D = spot.card
	var hip := card.position + Vector2(pose.hip[0], pose.hip[1]) * card.scale
	return contract.seats.any(func(seat): return hip.distance_to(Vector2(seat.seat_support[0], seat.seat_support[1])) < 1.0)


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


## A faísca do vagão (#256): na freada, nas quatro rodas, com a luz no trilho; com "Reduzir efeitos", nem uma nem outra.
func _sparks() -> void:
	for enabled in [true, false]:
		var car := AHTrainCar.new()
		car.sparks_enabled = enabled
		_tree.root.add_child(car)
		car.brake(true, 1.0, 1.0)
		var particles: Array = car.find_children("*", "CPUParticles3D", true, false)
		t.equal(particles.size(), 4, "uma faísca em cada roda")
		t.check(particles.all(func(p): return p.emitting == enabled and ((p.get_child(0) as OmniLight3D).light_energy > 0.0) == enabled),
			"a faísca e a luz %s" % ("na freada" if enabled else "fora com Reduzir efeitos"))
		car.free()
	await _tree.process_frame
