## As poses do acampamento no chão (#205):
## - em cada pose (fundadores e recrutas, sentado e deitado), o ponto mais baixo do corpo na arte cai na linha do chão:
##   a âncora (o pé) fica no último pixel opaco, sem o corpo boiar acima dela;
## - na cena, cada herói em volta da fogueira tem a sombra de contato no chão, embaixo do corpo (também quem não tem pose
##   de acampamento, como o Guaxinim e o Tatu, e fica de pé), e ela sai ao levantar acampamento.
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
				count += 1
	t.check(count >= 16, "todas as poses conferidas (%d)" % count)


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
	for member in camp.members:
		var card: AHSpriteCard = member.card
		var shadow := card.get_node_or_null(AHCampScene.CONTACT_NAME) as MeshInstance3D
		var who := "%s (%s)" % [Campaign.hero(member.hero_id).display_name, member.pose]
		if not t.check(shadow != null, "%s: com a sombra de contato" % who):
			continue
		t.check(is_equal_approx(shadow.global_position.y, corridor.room.floor_y + 0.015), "%s: a sombra no chão" % who)
		var width: float = (shadow.mesh as PlaneMesh).size.x
		t.check(width >= 0.5, "%s: a sombra na largura do corpo (%.2f m)" % [who, width])
	t.check(camp.members.filter(func(m): return m.pose == "stand").size() == 2, "o Guaxinim e o Tatu, sem pose de acampamento, de pé")
	await camp.end(true)
	t.check(street._heroes.all(func(card): return card.get_node_or_null(AHCampScene.CONTACT_NAME) == null),
		"ao levantar acampamento, as sombras saem")
	_tree.unload_current_scene()
	await _tree.process_frame
