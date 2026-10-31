## As placas das máquinas numa luta cheia (quatro inimigos, #60 sobre a #63): no texto Normal e no Maior, a intenção e a
## barra não cobrem o corpo (a barra e os estados no máximo um quinto dele; a intenção, acima da cabeça, nada) e as
## placas de um mesmo lado não se cobrem. Também com os espaços no mínimo (MIN_GAP_SCALE), o lugar mais apertado (#72):
## a câmera chega mais perto até as placas caberem; e, se ainda faltar espaço (a câmera presa longe), as placas do aperto
## somem, menos a de quem age e a do alvo na mira. Nunca uma placa em cima e outra embaixo (decisão do Lucas, 28/10).
extends RefCounted

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var real_size: int = Settings.text_size
	var tips: bool = Tips.enabled
	Campaign.save_dir = "user://test-plates-%d" % Time.get_ticks_usec()
	Tips.enabled = false
	await _fight()
	Settings.set_text_size(real_size)
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


## A luta do passo 7 da Rua das Vitrines na semente 1: dois Rastreadores, o Relé e o Pipoco.
func _fight() -> void:
	Campaign.state = Campaign.create_initial(6)
	AHJourneyRules.start_expedition(Campaign.state, "fase_1", 1)
	var route: Dictionary = Campaign.state.session.expedition.corridor
	var step := 7
	for i in step:
		route.steps[i].resolved = true
	route.index = step - 1
	GameFlow.change_to("street", {}, false)
	var street = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			street = _tree.current_scene
			break
	if not t.check(street != null, "a rua abre"):
		return
	for k in 4:
		street.corridor.debug_next_fight()
		for i in 20:
			await _tree.process_frame
		if street.corridor.guards.has(route.index) and route.index == step:
			break
	street.corridor._start_fight(route.index, true)
	var hud: AHCombatHud = street._arena.hud
	for i in 1500:
		if hud != null and hud.waiting:
			break
		await _tree.process_frame
	if not t.check(hud != null and hud.waiting, "a vez do jogador chega"):
		return
	var enemies: int = hud.session.state.enemy_team.size()
	t.check(enemies >= 4, "a luta tem quatro máquinas (%d)" % enemies)
	for size in [0, 2]:
		Settings.set_text_size(size)
		for i in 6:
			await _tree.process_frame
		_check(hud, "Maior" if size == 2 else "Normal")
	# Numa troca de posição (o Mover, um empurrão), com o espaço normal: nenhuma placa sobe enquanto os dois se cruzam.
	var arena: AHCombatArena = hud.arena
	for team in [hud.session.state.player_team, hud.session.state.enemy_team]:
		var first = team.filter(func(u): return u.rank == 1)[0]
		var second = team.filter(func(u): return u.rank == 2)[0]
		first.rank = 2
		second.rank = 1
		var hidden := {}
		arena._sync_positions(0.6)
		# Até os dois chegarem ao lugar novo (sem janela, os quadros passam mais rápido que o tempo da troca).
		for i in 600:
			await _tree.process_frame
			for unit_id in hud._crowded:
				hidden[unit_id] = true
			if [first, second].all(func(u): return arena.cards[u.id].position.distance_to(arena.slot_position(u)) < 0.01):
				break
		t.equal(hidden.keys(), [], "na troca de posição, com o espaço normal, nenhuma placa some")
		first.rank = 1
		second.rank = 2
		await arena._sync_positions(0.05)
	# O lugar mais apertado que a luta aceita (#72): os espaços encolhidos até MIN_GAP_SCALE, enquadrado como no começo
	# da luta. A câmera chega mais perto e nenhuma placa precisa sumir.
	var far := arena.view_distance
	arena.gap_scale = AHCombatArena.MIN_GAP_SCALE
	await arena._sync_positions(0.05)
	arena._frame_arena()
	street._update_camera(0.0)
	t.check(arena.view_distance < far, "no espaço mínimo, a câmera chega mais perto (%.1f m, antes %.1f m)" % [arena.view_distance, far])
	for size in [0, 2]:
		Settings.set_text_size(size)
		for i in 6:
			await _tree.process_frame
		var profile := ("Maior" if size == 2 else "Normal") + " no espaço mínimo"
		t.equal(hud._crowded.keys(), [], "no %s, com a câmera mais perto, nenhuma placa some" % profile)
		_check(hud, profile)
		await _aim(hud, profile)
	# Se ainda faltar espaço (a câmera presa na distância de antes): as placas do aperto somem, menos a de quem age.
	arena.view_distance = far
	street._update_camera(0.0)
	for size in [0, 2]:
		Settings.set_text_size(size)
		for i in 6:
			await _tree.process_frame
		var profile := ("Maior" if size == 2 else "Normal") + " no aperto"
		t.check(not hud._crowded.is_empty(), "no %s, há placas no aperto" % profile)
		var current: String = hud.session.state.current_turn_unit_id
		var shown: Array = hud._crowded.keys().filter(func(unit_id): return hud._unit_bars[unit_id].visible)
		t.check(shown.all(func(unit_id): return unit_id == current), "no %s, do aperto só fica a placa de quem age %s" % [profile, shown])
		_check(hud, profile)
		await _aim(hud, profile)


func _check(hud: AHCombatHud, profile: String) -> void:
	var camera := hud.get_viewport().get_camera_3d()
	var covering: Array = []
	var rects: Array = []
	for unit_id in hud._unit_bars:
		var plate: Control = hud._unit_bars[unit_id]
		var card: AHSpriteCard = hud.arena.cards.get(unit_id)
		if not plate.visible or card == null:
			continue
		var unit := hud.session.state.find_unit(unit_id)
		var rect := Rect2(plate.position, plate.size)
		rects.append([unit.is_player, rect, unit_id])
		# A intenção, à parte, acima da cabeça.
		var tag = (plate.get_meta("intent") if plate.has_meta("intent") else null)
		if tag != null and tag.visible:
			rects.append([unit.is_player, Rect2(tag.position, tag.size), unit_id + " (intenção)"])
			var crown: Rect2 = hud._body_rect(camera, card)
			var hit := Rect2(tag.position, tag.size).intersection(crown)
			if hit.size.y > crown.size.y * 0.05 + 1.0:
				covering.append("%s intenção (%.0f%%)" % [unit_id, hit.size.y / crown.size.y * 100.0])
		var body: Rect2 = hud._body_rect(camera, card)
		var over := rect.intersection(body)
		if body.size.y > 0 and over.size.y > body.size.y * 0.2 + 1.0:
			covering.append("%s (%.0f%%)" % [unit_id, over.size.y / body.size.y * 100.0])
	t.equal(covering, [], "no %s, nenhuma placa cobre mais que um quinto do corpo" % profile)
	var overlaps: Array = []
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i][0] == rects[j][0] and rects[i][1].grow(-1).intersects(rects[j][1].grow(-1)):
				overlaps.append("%s × %s" % [rects[i][2], rects[j][2]])
	t.equal(overlaps, [], "no %s, as placas de um lado não se cobrem" % profile)


## Na mira, em cada inimigo: o ALVO (acima da cabeça) não cobre a placa nem a intenção de ninguém, nem as que subiram.
func _aim(hud: AHCombatHud, profile: String) -> void:
	var ranks: Array = hud.session.state.enemy_team.filter(func(u): return u.rank > 0).map(func(u): return u.rank)
	hud._show_markers(ranks, true, func(_rank): pass, "")
	await _tree.process_frame
	var covered: Array = []
	for marker in hud._markers.filter(func(m): return m.has_meta("card")):
		hud._select_target(int(marker.get_meta("rank")))
		await _tree.process_frame
		await _tree.process_frame
		# O alvo na mira mostra a placa dele, mesmo no aperto.
		var aimed: Control = hud._unit_bars.get(marker.get_meta("unit_id"))
		if aimed != null and not aimed.visible:
			covered.append("%s sem placa na mira" % marker.get_meta("unit_id"))
		var label := Rect2(hud._target_label.position, hud._target_label.size)
		for unit_id in hud._unit_bars:
			var plate: Control = hud._unit_bars[unit_id]
			var tag = plate.get_meta("intent") if plate.has_meta("intent") else null
			if plate.visible and Rect2(plate.position, plate.size).grow(-1).intersects(label.grow(-1)):
				covered.append("%s (mirando %s)" % [unit_id, marker.get_meta("unit_id")])
			if tag != null and tag.visible and Rect2(tag.position, tag.size).grow(-1).intersects(label.grow(-1)):
				covered.append("%s intenção (mirando %s)" % [unit_id, marker.get_meta("unit_id")])
	hud._clear_markers()
	hud._set_enabled(true)
	t.equal(covered, [], "no %s, o ALVO não cobre placa nem intenção de ninguém" % profile)
