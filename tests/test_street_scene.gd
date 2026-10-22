## A rua com uma expedição de verdade:
## - um recruta (hero_cao_4, sem arte própria ainda) vai para a rua e para a luta com a arte do fundador da classe (antes
##   a rua deixava de fora quem não estava no manifesto da arte: o recruta escalado sumia da equipe e da luta);
## - a Mochila aberta na luta fecha quando um comando é escolhido com o mouse, e não passa para a luta seguinte.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")


func run(t) -> void:
	var bento := AHCombatArena.hero_art_of("hero_cao_bento")
	t.equal(AHCombatArena.hero_art_of("hero_cao_4"), bento, "o recruta cão usa a arte do Bento")
	t.equal(AHCombatArena.hero_art_of("hero_peixe_4"), {}, "classe sem arte: nada")
	var tree: SceneTree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-recruit-party-%d" % Time.get_ticks_usec()
	Campaign.state = Campaign.create_initial(11)
	var recruit := S.recruit(Campaign.state, "cao", RandomNumberGenerator.new(), "Rex")
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
