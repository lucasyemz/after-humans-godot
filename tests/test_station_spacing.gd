## Na Estação, ninguém para em cima de outro: com a casa cheia (os quatro fundadores, os recrutas e os moradores), um
## minuto de passeio simulado sem dois parados a menos de STOP_GAP na mesma faixa; e o posto do meio de um cômodo tem um
## herói de cada vez.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")


func run(t) -> void:
	var tree: SceneTree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-station-spacing-%d" % Time.get_ticks_usec()
	Campaign.state = Campaign.create_initial(33)
	# A casa cheia: os cômodos de passeio recuperados e os três moradores.
	for room in [S.FORGE, S.RESEARCH, S.DORMITORY, S.BAR]:
		Campaign.state.station.rooms[room] = 1
	Campaign.state.station.residents = [S.DORA, S.OTTO, S.CORA]
	var station = await _open(tree)
	if not t.check(station != null, "a Estação abriu"):
		_restore(real_dir, real_state)
		return
	var worst := INF
	var both_working := false
	for seed_value in 4:
		station._place_residents(RandomNumberGenerator.new() if seed_value == 0 else _rng(seed_value))
		for step in 600:
			station._walk(0.1)
			for i in station._walkers.size():
				var a: Dictionary = station._walkers[i]
				if not _stopped(a):
					continue
				for j in range(i + 1, station._walkers.size()):
					var b: Dictionary = station._walkers[j]
					if not _stopped(b) or not _same_lane(a.card, b.card):
						continue
					worst = minf(worst, absf(a.card.position.x - b.card.position.x))
			var working := {}
			for w in station._walkers:
				if w.get("working", 0.0) > 0.0:
					if working.has(w.get("room", "")):
						both_working = true
					working[w.get("room", "")] = true
	t.check(worst >= station.STOP_GAP - 0.05, "ninguém parado a menos de %.1f m de outro na mesma faixa (o mais perto: %.2f m)" % [station.STOP_GAP, worst])
	t.check(not both_working, "um herói de cada vez no posto do meio de cada cômodo")
	# Uma faixa lotada de propósito (mais gente do que lugares a STOP_GAP): ninguém anda para sempre, todos param em
	# algum momento.
	var crowd: Array = station._walkers.filter(func(w): return w.has("hero_id") and not w.get("sleeping", false) and not w.get("work", false))
	var lane: Dictionary = crowd[0]
	for w in crowd:
		w.room = lane.room
		w.min = lane.min
		w.max = minf(lane.max, lane.min + 2.0)
		w.floor = lane.floor
		w.home_z = lane.home_z
		w.wait = 0.0
		w.sitting = 0.0
		w.seat = -1
		w.card.position = Vector3(w.min, w.floor, w.home_z)
		station._choose_target(w)
	var stopped := {}
	for step in 1200:
		station._walk(0.1)
		for w in crowd:
			if w.get("wait", 0.0) > 0.0:
				stopped[w.hero_id] = true
	t.check(stopped.size() == crowd.size(), "numa faixa de 2 m com %d heróis, todos acabam parando (%d pararam)" % [crowd.size(), stopped.size()])
	_restore(real_dir, real_state)


func _stopped(walker: Dictionary) -> bool:
	if not is_instance_valid(walker.card) or not walker.card.visible or walker.get("sleeping", false):
		return false
	return walker.has("civilian") or walker.get("wait", 0.0) > 0.0 or walker.get("sitting", 0.0) > 0.0


func _same_lane(a: Node3D, b: Node3D) -> bool:
	return absf(a.position.y - b.position.y) <= 0.5 and absf(a.position.z - b.position.z) <= 1.5


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919
	return rng


func _open(tree: SceneTree):
	GameFlow.change_to("station", {}, false)
	for frame in 300:
		await tree.process_frame
		var scene := tree.current_scene
		if not GameFlow.busy and scene is AHStation and scene.hud != null:
			await tree.process_frame
			return scene
	return null


func _restore(real_dir: String, real_state: Dictionary) -> void:
	Campaign.save_dir = real_dir
	Campaign.state = real_state
