## O ALVO e o clique na altura da pose atual (#70): no Último Fôlego o herói fica ajoelhado, bem mais baixo que de pé.
## O "ALVO" (a plaqueta com o nome) fica logo acima da cabeça ajoelhada, e não meio metro acima, onde estaria a de pé;
## o retângulo do clique vai do pé a essa cabeça. De pé, nada muda.
extends RefCounted

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-target-kneel-%d" % Time.get_ticks_usec()
	var tips: bool = Tips.enabled
	Tips.enabled = false
	_poses()
	await _fight()
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


## O topo de cada pose dos fundadores: de pé, a altura do corpo; ajoelhado (a queda), bem mais baixo.
func _poses() -> void:
	var heroes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AHCombatArena.ART_MANIFEST)).heroes
	for hero_id in heroes:
		var hero: Dictionary = heroes[hero_id]
		var card := AHSpriteCard.new()
		card.body_height = 1.8
		card.show_art(hero.idle)
		t.check(absf(card.pose_top() - card.body_height) < card.body_height * 0.04,
			"%s de pé: o topo da pose é a altura do corpo (%.2f m)" % [hero_id, card.pose_top()])
		if hero.get("reactions", {}).has("death"):
			card.show_art(hero.reactions.death)
			var ratio := card.pose_top() / card.body_height
			t.check(ratio > 0.45 and ratio < 0.8, "%s ajoelhado: o topo fica entre 45%% e 80%% da altura de pé (%.2f)" % [hero_id, ratio])
		card.free()


func _fight() -> void:
	Campaign.state = Campaign.create_initial(6)
	AHJourneyRules.start_expedition(Campaign.state, "fase_1", 4242)
	GameFlow.change_to("street", {}, false)
	var street = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			street = _tree.current_scene
			break
	if not t.check(street != null, "a rua abre"):
		return
	street.corridor.debug_next_fight()
	for i in 10:
		await _tree.process_frame
	street.corridor._start_fight(Campaign.state.session.expedition.corridor.index, true)
	var arena: AHCombatArena = street._arena
	for i in 900:
		if arena.hud != null and arena.hud.waiting:
			break
		await _tree.process_frame
	var hud: AHCombatHud = arena.hud
	if not t.check(hud.waiting, "a vez do jogador chega"):
		return
	# Um fundador que não é o da vez e tem a pose de caído vai para o Último Fôlego.
	var fallen = null
	for unit in arena.session.state.player_team:
		if unit.id != hud._actor_id and arena.cards.has(unit.id) and arena.hero_art(unit.hero_id).get("reactions", {}).has("death"):
			fallen = unit
			break
	if not t.check(fallen != null, "há um fundador para cair"):
		return
	var card: AHSpriteCard = arena.cards[fallen.id]
	var camera := hud.get_viewport().get_camera_3d()
	fallen.hp = 0
	fallen.deaths_door = true
	arena.rest_pose(fallen)
	t.check(card.pose_top() < card.body_height * 0.8, "no Último Fôlego, a pose é a ajoelhada (%.2f de %.2f m)" % [card.pose_top(), card.body_height])
	hud._show_markers([fallen.rank], false, func(_rank): pass, "")
	await _tree.process_frame
	hud._select_target(fallen.rank)
	await _tree.process_frame
	await _tree.process_frame
	if not t.check(hud._target_label.visible and hud._target_label.get_meta("card") == card, "o ALVO aparece no ajoelhado"):
		return
	var feet := camera.unproject_position(card.global_position)
	var kneeling_head := camera.unproject_position(card.global_position + Vector3(0, card.pose_top(), 0))
	var standing_head := camera.unproject_position(card.global_position + Vector3(0, card.body_height, 0))
	var label := Rect2(hud._target_label.position, hud._target_label.size)
	# Logo acima da cabeça ajoelhada: a base do ALVO entre a cabeça e um quinto da altura de pé acima dela, bem abaixo
	# de onde ficava (acima da cabeça de pé).
	var gap := kneeling_head.y - label.end.y
	t.check(gap >= 0.0 and gap < (feet.y - standing_head.y) * 0.2,
		"o ALVO fica logo acima da cabeça ajoelhada (%.0f px acima dela)" % gap)
	t.check(label.end.y > standing_head.y + (kneeling_head.y - standing_head.y) * 0.5,
		"o ALVO não fica na altura de quem está de pé (base %.0f, cabeça de pé %.0f)" % [label.end.y, standing_head.y])
	# O clique: do pé à cabeça ajoelhada, na largura do corpo de pé.
	var marker: Control = hud._markers.filter(func(m): return m.has_meta("card") and m.get_meta("card") == card).front()
	var rect := Rect2(marker.position, marker.size)
	t.check(rect.has_point(kneeling_head + Vector2(0, 4)) and rect.has_point(feet - Vector2(0, 4)), "o clique cobre do pé à cabeça ajoelhada")
	t.check(not rect.has_point(standing_head + Vector2(0, 4)), "acima da cabeça ajoelhada, onde ficaria a de pé, o clique não pega")
	var standing_width := maxf((feet.y - camera.unproject_position(card.global_position + Vector3(0, card.head_height(), 0)).y) * AHCombatHud.BODY_WIDTH, 48.0)
	t.check(absf(rect.size.x - standing_width) < 1.0, "a largura do clique é a do corpo de pé (%.0f e %.0f)" % [rect.size.x, standing_width])
	hud._clear_markers()
	hud._set_enabled(true)
