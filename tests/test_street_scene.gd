## A rua com uma expedição de verdade:
## - um recruta (hero_cao_4) vai para a rua e para a luta com a arte própria da classe (#32); sem variação no save, a do
##   fundador (antes a rua deixava de fora quem não estava no manifesto da arte: o recruta escalado sumia da equipe e da
##   luta);
## - a Mochila aberta na luta fecha quando um comando é escolhido com o mouse, e não passa para a luta seguinte.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")


func run(t) -> void:
	var tree: SceneTree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-street-scene-%d" % Time.get_ticks_usec()
	# Numa campanha isolada: o save do jogador (que pode ter os seus recrutas) não entra na conta.
	Campaign.state = Campaign.create_initial(11)
	var bento := AHCombatArena.hero_art_of("hero_cao_bento")
	t.equal(AHCombatArena.art_entry({"hero_cao_bento": bento}, "hero_cao_4", ""), bento, "recruta fora do elenco (sem variação): a arte do Bento")
	t.equal(AHCombatArena.hero_art_of("hero_peixe_4"), {}, "classe sem arte: nada")
	var recruit := S.recruit(Campaign.state, "cao", RandomNumberGenerator.new(), "Rex")
	t.equal(AHCombatArena.hero_art_of(recruit.hero_id).get("variant", ""), "dog_recruit_01", "o recruta escalado usa a arte própria")
	var team := [recruit.hero_id, "hero_gato_nick", "hero_sapo_iris", "hero_coruja_vespera"]
	t.equal(S.confirm_departure(Campaign.state, team, 0, 4242, "fase_1"), "", "parte com o recruta na frente")
	GameFlow.change_to("street", {}, false)
	var limit := Time.get_ticks_msec() + 20000
	while (tree.current_scene == null or tree.current_scene.get("corridor") == null or GameFlow.busy) and Time.get_ticks_msec() < limit:
		await tree.process_frame
	var street = tree.current_scene
	if t.check(street != null and street.get("corridor") != null, "a rua abriu"):
		t.equal(street.party_ids, team, "o recruta anda na rua com a equipe")
		street.corridor.debug_next_fight()
		var route: Dictionary = Campaign.state.session.expedition.corridor
		street.corridor._start_fight(route.index, true)
		await tree.process_frame
		var arena: AHCombatArena = street._arena
		t.check(arena.active and arena.session.state.player_team.any(func(u): return u.hero_id == recruit.hero_id), "o recruta luta")
		t.check(not arena.hero_art(recruit.hero_id).is_empty(), "a arena acha a arte do recruta")
		# No Último Fôlego, o recruta (sem a pose de caído) fica de pé, mas escurecido; morto de vez, cinza.
		var unit = arena.session.state.player_team.filter(func(u): return u.hero_id == recruit.hero_id)[0]
		var card: AHSpriteCard = arena.cards[unit.id]
		var hp: int = unit.hp
		unit.hp = 0
		unit.deaths_door = true
		arena.rest_pose(unit)
		t.equal(card._material.albedo_color, Color(0.72, 0.62, 0.62), "recruta no Último Fôlego: escurecido")
		unit.deaths_door = false
		arena.rest_pose(unit)
		t.equal(card._material.albedo_color, Color(0.55, 0.55, 0.6), "morto de vez: cinza")
		unit.hp = hp
		arena.rest_pose(unit)
		t.equal(card._material.albedo_color, Color.WHITE, "de pé de novo: normal")
		await _bag(t, tree, arena)
		tree.unload_current_scene()
		await tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _bag(t, tree: SceneTree, arena: AHCombatArena) -> void:
	var limit := Time.get_ticks_msec() + 20000
	while not arena.hud.waiting and arena.active and Time.get_ticks_msec() < limit:
		await tree.process_frame
	if not t.check(arena.hud.waiting, "a luta pede o comando do herói"):
		return
	arena.hud._on_action("item")
	t.check(arena.hud._bag != null, "a Mochila abre na luta")
	# Defender clicado com a Mochila aberta (ela não cobre a barra de ações).
	arena.hud.command_chosen.emit({"kind": "defend"})
	await tree.process_frame
	t.check(arena.hud._bag == null, "escolhido o comando, a Mochila fecha")
	arena.hud._open_bag()
	arena.hud.close()
	t.check(arena.hud._bag == null, "fechar o HUD da luta fecha a Mochila")
