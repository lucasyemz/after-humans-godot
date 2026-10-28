## As poses do acampamento no chão (#205):
## - em cada pose (fundadores e recrutas, sentado e deitado), o ponto mais baixo do corpo na arte cai na linha do chão:
##   a âncora (o pé) fica no último pixel opaco, sem o corpo boiar acima dela;
## - o apoio do corpo (o quadril do sentado, o tronco do deitado: "support", medido na arte) cai no chão embaixo do
##   corpo na câmera do acampamento, a até MAX_SUPPORT_DEPTH atrás do pé, e o dado confere com a arte;
## - na cena, a câmera olha do ângulo da arte e cada herói em volta da fogueira tem a sombra de contato no chão, do pé
##   até atrás do apoio (também quem não tem pose de acampamento, como o Guaxinim e o Tatu, e fica de pé); ela acompanha
##   a pose de cuidar e sai ao levantar acampamento.
extends RefCounted

const J := preload("res://scripts/flow/journey_rules.gd")
const S := preload("res://scripts/flow/station_rules.gd")
## Quanto o corpo pode ficar acima da linha do chão (m): um pixel ou dois da arte reduzida.
const GROUND_TOLERANCE := 0.02

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_art()
	_stops()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-camp-ground-%d" % Time.get_ticks_usec()
	await _scene()
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _art() -> void:
	var poses: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AHCampScene.POSES))
	var count := 0
	for group in ["heroes", "recruits"]:
		for owner in poses[group]:
			for kind in ["seat", "sleep"]:
				var art: Dictionary = poses[group][owner].get(kind, {})
				if art.is_empty():
					continue
				var image: Image = (load(art.file) as Texture2D).get_image()
				if image.is_compressed():
					image.decompress()
				var lowest := _lowest_opaque_row(image)
				# A textura pode estar reduzida: o último pixel opaco nos pixels da arte original.
				var scale: float = float(art.canvas[1]) / float(image.get_height())
				var px_to_m: float = 1.8 / float(art.body_reference_pixels)
				var gap: float = (float(art.anchor[1]) - (lowest + 1) * scale) * px_to_m
				t.check(absf(gap) <= GROUND_TOLERANCE, "%s %s: o ponto mais baixo do corpo na linha do chão (%.3f m)" % [owner, kind, gap])
				# O apoio, medido de novo na arte (a mediana da faixa do meio), confere com o dado.
				var support: float = _support_row(image) * scale
				t.check(art.has("support") and absf(float(art.support) - support) <= 2.0 * scale,
					"%s %s: o apoio do dado confere com a arte (%s, medido %.1f)" % [owner, kind, art.get("support"), support])
				var depth := AHCampScene.support_depth(art)
				t.check(depth <= AHCampScene.MAX_SUPPORT_DEPTH,
					"%s %s: o apoio cai no chão embaixo do corpo (%.2f m atrás do pé)" % [owner, kind, depth])
				# Na parada com água pintada (8°), o apoio cai mais atrás: o teto da sombra não a corta antes dele.
				var water_depth := AHCampScene.support_depth(art, 1.8, AHCampScene.WATER_STOP_PITCH)
				t.check(minf(water_depth + AHCampScene.CONTACT_PAST, AHCampScene.CONTACT_MAX_BACK) >= water_depth,
					"%s %s: a 8°, a sombra chega ao apoio (%.2f m atrás do pé)" % [owner, kind, water_depth])
				count += 1
	t.check(count >= 16, "todas as poses conferidas (%d)" % count)


## O ângulo da parada de descanso por cenário: no chão alagado do Depósito, o de antes (a água fica fina, como era); com
## o lago pintado do Cais, o menor (o fundo continua no quadro); no seco (o Abrigo), o da arte.
func _stops() -> void:
	t.equal(AHCampScene.focus_height(AHCampScene.FLAT_PITCH), AHCampScene.FLAT_FOCUS_HEIGHT, "no ângulo de antes, a altura do alvo de antes")
	t.equal(AHCampScene.focus_height(AHCampScene.FOCUS_PITCH), AHCampScene.FOCUS_HEIGHT, "no ângulo da arte, a altura da casa")
	for spec in [["FloodedDepot", AHCampScene.FLOODED_STOP_PITCH], ["RiverDock", AHCampScene.WATER_STOP_PITCH],
			["SealedShelter", AHCampScene.FOCUS_PITCH]]:
		var scenario := AHScenarioWorld.new()
		_tree.root.add_child(scenario)
		scenario.build(spec[0])
		var zone: Dictionary = scenario.zones[0]
		var fire := Vector3((float(zone.x0) + float(zone.x1)) * 0.5, float(zone.y), (float(zone.z0) + float(zone.z1)) * 0.5)
		t.equal(AHCampScene.stop_pitch(scenario, fire), spec[1], "%s: o ângulo da parada de descanso" % spec[0])
		# O alvo acompanha o ângulo: a fileira na mesma linha da tela (no de antes, a altura de antes).
		var height := AHCampScene.focus_height(spec[1])
		t.check(height >= AHCampScene.FOCUS_HEIGHT and height <= AHCampScene.FLAT_FOCUS_HEIGHT, "%s: a altura do alvo (%.2f m)" % [spec[0], height])
		scenario.free()


## O apoio: na faixa do meio do corpo visível (40% da largura), a mediana da última linha opaca de cada coluna.
func _support_row(image: Image) -> float:
	var used := image.get_used_rect()
	var lows: Array = []
	for x in range(int(used.position.x + used.size.x * 0.3), int(used.position.x + used.size.x * 0.7)):
		for y in range(used.end.y - 1, -1, -1):
			if image.get_pixel(x, y).a > 0.5:
				lows.append(y + 1)
				break
	lows.sort()
	return float(lows[lows.size() / 2])


## A última linha com algum pixel opaco (alfa acima da metade).
func _lowest_opaque_row(image: Image) -> int:
	for y in range(image.get_height() - 1, -1, -1):
		for x in range(0, image.get_width(), 2):
			if image.get_pixel(x, y).a > 0.5:
				return y
	return -1


func _scene() -> void:
	# O Bento, o Guaxinim e o Tatu (sem pose de acampamento) e o Nick, ferido (deita).
	var c: Dictionary = Campaign.create_initial(23)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var recruited: Array = []
	for class_id in ["rato", "tatu"]:
		if not c.unlocked_classes.has(class_id):
			c.unlocked_classes.append(class_id)
		recruited.append(S.recruit(c, class_id, rng, "Teste").hero_id)
	J.start_expedition(c, "fase_1", 23)
	c.session.expedition.team = [c.roster[0].id, recruited[0], recruited[1], c.roster[1].id]
	S.hero(c, c.roster[1].id).hp = 1
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("street", {}, false)
	var street = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			street = _tree.current_scene
			break
	if not t.check(street != null, "a rua abre"):
		return
	var route: Dictionary = c.session.expedition.corridor
	var site: int = route.sites.map(func(s): return s.camp_site).find(true)
	route.index = route.sites[site].step
	for i in route.index + 1:
		route.steps[i].resolved = true
	route.sites[site].has_enemy = false
	var corridor: AHStreetCorridor = street.corridor
	await corridor._enter_house(site)
	await corridor._start_camp()
	var camp: AHCampScene = corridor.camp
	t.equal(camp.members.size(), 4, "os quatro em volta da fogueira")
	for frame in 90:
		street._update_camera(0.05)
	var camera: Camera3D = street._camera
	t.check(absf(rad_to_deg(-camera.global_rotation.x) - AHCampScene.FOCUS_PITCH) < 0.5,
		"a câmera do acampamento olha do ângulo da arte (%.1f°)" % rad_to_deg(-camera.global_rotation.x))
	for member in camp.members:
		var card: AHSpriteCard = member.card
		var shadow := card.get_node_or_null(AHCampScene.CONTACT_NAME) as MeshInstance3D
		var who := "%s (%s)" % [Campaign.hero(member.hero_id).display_name, member.pose]
		if not t.check(shadow != null, "%s: com a sombra de contato" % who):
			continue
		t.check(is_equal_approx(shadow.global_position.y, corridor.room.floor_y + 0.015), "%s: a sombra no chão" % who)
		var width: float = (shadow.mesh as PlaneMesh).size.x
		t.check(width >= 0.5, "%s: a sombra na largura do corpo (%.2f m)" % [who, width])
		# Do pé até atrás do apoio: a borda de trás da sombra passa do ponto onde o apoio toca o chão.
		var back: float = (shadow.mesh as PlaneMesh).size.y * 0.5 - shadow.position.z
		t.check(back >= AHCampScene.support_depth(card.art(), card.body_height), "%s: a sombra chega ao apoio (%.2f m atrás do pé)" % [who, back])
	t.check(camp.members.filter(func(m): return m.pose == "stand").size() == 2, "o Guaxinim e o Tatu, sem pose de acampamento, de pé")
	# A pose de cuidar (de pé, a de usar item) troca a sombra pela do pé, e a de descanso volta depois.
	var sitter: Dictionary = camp.members.filter(func(m): return m.pose == "seat" or m.pose == "sleep")[0]
	var rest_size: Vector2 = (sitter.card.get_node(AHCampScene.CONTACT_NAME).mesh as PlaneMesh).size
	camp.show_care_pose(sitter.hero_id)
	await _tree.process_frame
	var care_size: Vector2 = (sitter.card.get_node(AHCampScene.CONTACT_NAME).mesh as PlaneMesh).size
	t.check(not care_size.is_equal_approx(rest_size), "de pé para cuidar, a sombra é a do pé (%s, sentado %s)" % [care_size, rest_size])
	await _tree.create_timer(AHCampScene.CARE_POSE_SECONDS + 0.2).timeout
	t.check((sitter.card.get_node(AHCampScene.CONTACT_NAME).mesh as PlaneMesh).size.is_equal_approx(rest_size), "e volta a do descanso")
	await camp.end(true)
	t.check(street._heroes.all(func(card): return card.get_node_or_null(AHCampScene.CONTACT_NAME) == null),
		"ao levantar acampamento, as sombras saem")
	_tree.unload_current_scene()
	await _tree.process_frame
