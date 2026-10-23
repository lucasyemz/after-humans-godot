## A silhueta e o esmaecimento (#51): a placa do personagem marca o stencil e ganha o passe da silhueta na região que
## mostra (quadro e lado); o objeto entre a câmera e um personagem acompanhado esmaece e volta quando sai da frente
## (na hora, com "Reduzir efeitos"); a equipe tem silhueta na rua, os inimigos só na luta, os heróis na Estação.
extends RefCounted

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_card()
	await _fade()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-occlusion-%d" % Time.get_ticks_usec()
	var tips: bool = Tips.enabled
	Tips.enabled = false
	await _street()
	await _scenario()
	await _station()
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


func _card() -> void:
	var card := AHSpriteCard.new()
	var material: StandardMaterial3D = card.material_override
	t.check(material.stencil_mode == BaseMaterial3D.STENCIL_MODE_CUSTOM and material.stencil_flags == BaseMaterial3D.STENCIL_FLAG_WRITE
		and material.stencil_reference == AHSpriteCard.STENCIL_CHARACTER, "toda placa de personagem marca o stencil")
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AHCombatArena.ART_MANIFEST)).heroes.values()[0].idle
	card.show_art(art)
	t.check(not card.has_silhouette(), "sem silhueta até pedir")
	card.set_silhouette(Color.RED)
	var pass_material: ShaderMaterial = material.next_pass
	t.check(card.has_silhouette() and pass_material != null and pass_material.shader == AHSpriteCard.SILHOUETTE_SHADER, "com silhueta, o segundo passe")
	t.check(pass_material.get_shader_parameter("albedo_tex") == material.albedo_texture, "a silhueta usa a arte da placa")
	card.set_facing(-1.0)
	var scale: Vector2 = pass_material.get_shader_parameter("uv_scale")
	t.check(scale.x < 0.0 and is_equal_approx(scale.x, material.uv1_scale.x), "e a mesma região e o mesmo lado")
	card.set_silhouette(null)
	t.check(not card.has_silhouette(), "desliga")
	card.free()


## Um caixote entre a câmera e o personagem esmaece; fora da frente, volta.
func _fade() -> void:
	var stage := Node3D.new()
	_tree.root.add_child(stage)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.5, 8)
	stage.add_child(camera)
	camera.make_current()
	var card := AHSpriteCard.new()
	card.show_art(JSON.parse_string(FileAccess.get_file_as_string(AHCombatArena.ART_MANIFEST)).heroes.values()[0].idle)
	stage.add_child(card)
	var crate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, 1.6, 0.6)
	crate.mesh = box
	crate.position = Vector3(0, 0.8, 3)
	stage.add_child(crate)
	var far := MeshInstance3D.new()
	far.mesh = box
	far.position = Vector3(6, 0.8, 3)
	stage.add_child(far)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor.mesh = plane
	stage.add_child(floor)
	var occlusion := AHOcclusion.new()
	stage.add_child(occlusion)
	occlusion.scan(stage)
	t.equal(occlusion._occluders.size(), 2, "registra os dois caixotes, não o chão")
	occlusion.track(card)
	t.check(card.has_silhouette(), "a equipe ganha a silhueta")
	await _until(func(): return crate.transparency >= AHOcclusion.FADED - 0.001, 2.0)
	t.check(is_equal_approx(crate.transparency, AHOcclusion.FADED), "o caixote na frente esmaece (%.2f)" % crate.transparency)
	t.equal(far.transparency, 0.0, "o de longe fica inteiro")
	t.check(occlusion.faded() == [crate], "faded() diz qual")
	card.position.x = -4.0
	await _until(func(): return crate.transparency <= 0.0, 2.0)
	t.equal(crate.transparency, 0.0, "fora da frente, volta inteiro")
	# Com "Reduzir efeitos", troca na hora (sem animação).
	var settings: Dictionary = Campaign.state.get("settings", {})
	var reduced: bool = settings.get("reduced_environment_effects", false)
	settings.reduced_environment_effects = true
	card.position.x = 0.0
	await _tree.process_frame
	await _tree.process_frame
	t.check(is_equal_approx(crate.transparency, AHOcclusion.FADED), "com Reduzir efeitos, esmaece na hora")
	settings.reduced_environment_effects = reduced
	occlusion.untrack(card)
	t.check(not card.has_silhouette(), "quem sai da lista perde a silhueta")
	stage.queue_free()
	await _tree.process_frame


func _street() -> void:
	Campaign.state = Campaign.create_initial(6)
	AHJourneyRules.start_expedition(Campaign.state, "fase_1", 4242)
	GameFlow.change_to("street", {}, false)
	var street = await _scene("Street")
	if street == null:
		return
	t.check(street.occlusion != null and street._heroes.all(func(c): return c.has_silhouette()), "na rua, a equipe tem silhueta")
	t.check(street.occlusion._occluders.size() > 20, "e a rua registra o que pode tapar (%d)" % street.occlusion._occluders.size())
	t.check(street.occlusion._occluders.all(func(o): return not (o.node.get_parent() is CollisionObject3D)), "sem as caixas de depuração")
	t.check(street.occlusion._occluders.all(func(o): return is_instance_valid(o.node)), "nenhum registrado já saiu da árvore")
	street.corridor.debug_next_fight()
	for i in 10:
		await _tree.process_frame
	var route: Dictionary = Campaign.state.session.expedition.corridor
	var guards: Array = street.corridor.guards.get(route.index, {}).get("cards", [])
	t.check(not guards.is_empty() and guards.all(func(c): return not c.has_silhouette()), "a patrulha andando não tem silhueta")
	street.corridor._start_fight(route.index, true)
	var arena: AHCombatArena = street._arena
	for i in 900:
		if arena.hud != null and arena.hud.waiting:
			break
		await _tree.process_frame
	var enemies: Array = arena.session.state.enemy_team.map(func(u): return arena.cards[u.id])
	t.check(not enemies.is_empty() and enemies.all(func(c): return c.has_silhouette()), "na luta, os inimigos ganham a silhueta")


## Num cenário, as peças que o cenário junta numa malha saem da árvore: nenhuma fica registrada (a captura caía).
func _scenario() -> void:
	var c: Dictionary = Campaign.create_initial(6)
	c.completed_phases = ["fase_1"]
	AHStationRules.confirm_departure(c, c.preferred_formation.duplicate(), 0, 4242, "fase_2", "")
	Campaign.state = c
	GameFlow.change_to("street", {}, false)
	var street = await _scene("Street")
	if street == null:
		return
	await _tree.process_frame
	t.check(street.scenario != null and street.occlusion._occluders.size() > 20, "o cenário registra o que pode tapar (%d)" % street.occlusion._occluders.size())
	t.check(street.occlusion._occluders.all(func(o): return is_instance_valid(o.node)), "nenhuma peça juntada fica registrada")


func _station() -> void:
	Campaign.state = Campaign.create_initial(6)
	GameFlow.change_to("station", {}, false)
	var station = await _scene("")
	if station == null:
		return
	var heroes: Array = station._walkers.filter(func(w): return w.has("hero_id")).map(func(w): return w.card)
	t.check(not heroes.is_empty() and heroes.all(func(c): return c.has_silhouette()), "na Estação, os heróis têm silhueta (%d)" % heroes.size())


func _scene(name: String):
	for frame in 600:
		await _tree.process_frame
		var scene := _tree.current_scene
		if not GameFlow.busy and scene != null and frame > 3 and (scene.name == name if name != "" else scene is AHStation):
			await _tree.process_frame
			return scene
	t.check(false, "a cena %s abre" % name)
	return null


func _until(condition: Callable, limit: float) -> void:
	var end := Time.get_ticks_msec() + int(limit * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < end:
		await _tree.process_frame
