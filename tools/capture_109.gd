## Fotos da #109 (docs/design/hud-ajustes.md), para comparar com as maquetes nos quatro perfis:
## - o acampamento na estrutura da Unreal: o Bento escolhido com o foco na Ração (a vida prevista) e o Nick com a vida
##   cheia e o instinto em 0 (nenhum cuidado faz efeito);
## - o Menu da expedição na rua;
## - o popup do fim da luta: a patrulha, o nível novo (os quatro com o Treino pronto), o guardião (com os recursos), a
##   fuga e a derrota.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_109.gd -- --out=<pasta> [--text-size=2] [--colorblind]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var colorblind := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--colorblind":
			colorblind = true
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	var S = load("res://scripts/flow/station_rules.gd")
	var J = load("res://scripts/flow/journey_rules.gd")
	var Rewards = load("res://scripts/flow/fight_rewards.gd")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	if colorblind:
		root.get_node("Settings").set_colorblind(true)
	var c: Dictionary = campaign.create_initial(23)
	J.start_expedition(c, "fase_1", 23)
	var team: Array = c.session.expedition.team
	for spec in [["hero_cao_bento", 22, 0], ["hero_gato_nick", 24, 0], ["hero_sapo_iris", 14, 20], ["hero_coruja_vespera", 26, 10]]:
		var hero = S.hero(c, spec[0])
		if hero != null:
			hero.hp = mini(int(hero.max_hp), spec[1])
			hero.instinct = spec[2]
	campaign.state = c
	campaign.save()
	flow.change_to("street", {}, false)
	await _frames(10)
	while flow.busy:
		await process_frame
	var street = current_scene
	var corridor = street.corridor
	var hud = street.exploration_hud
	# O Menu da expedição na rua.
	await _frames(20)
	corridor.open_menu()
	await _frames(10)
	await _shot("menu")
	hud.close_modal()
	await _frames(5)
	# O acampamento.
	var route: Dictionary = c.session.expedition.corridor
	var site: int = route.sites.map(func(s): return s.camp_site).find(true)
	route.index = route.sites[site].step
	for i in route.index + 1:
		route.steps[i].resolved = true
	route.sites[site].has_enemy = false
	await corridor._enter_house(site)
	await _frames(20)
	await corridor._start_camp()
	await _frames(30)
	var camp = corridor.camp
	var bento: int = camp.members.map(func(m): return m.hero_id).find("hero_cao_bento")
	camp.select(maxi(0, bento), false)
	await _frames(5)
	hud.camp_hud.eat_button.grab_focus()
	await _frames(10)
	await _shot("camp_preview")
	var nick: int = camp.members.map(func(m): return m.hero_id).find("hero_gato_nick")
	camp.select(maxi(0, nick), false)
	await _frames(5)
	hud.camp_hud.leave_button.grab_focus()
	hud.camp_hud.refresh()
	await _frames(10)
	await _shot("camp_full")
	# O popup do fim da luta: a patrulha, o guardião, a fuga e a derrota (abertos à mão, sobre uma luta de verdade).
	var fresh: Dictionary = campaign.create_initial(6)
	J.start_expedition(fresh, "fase_1", 4242)
	campaign.state = fresh
	flow.change_to("street", {}, false)
	await _frames(10)
	while flow.busy:
		await process_frame
	street = current_scene
	street.corridor.debug_next_fight()
	await _frames(10)
	street.corridor._start_fight(fresh.session.expedition.corridor.index, true)
	var fight = street._arena.hud
	for i in 900:
		if fight != null and fight.waiting:
			break
		await process_frame
	await _frames(10)
	var session = fight.session
	# O XP de uma patrulha (o da luta de verdade sai do xp_gained, que a luta recém-aberta ainda não tem).
	for unit in session.state.player_team:
		session.xp_gained[unit.hero_id] = 8 if unit.hero_id in ["hero_coruja_vespera", "hero_cao_bento"] else 11
	for name in ["fight_none", "fight_level", "fight_loot", "fight_fled", "fight_defeat"]:
		var result: String = {"fight_none": "victory", "fight_level": "victory", "fight_loot": "victory", "fight_fled": "escaped", "fight_defeat": "defeat"}[name]
		# O nível novo: os quatro fecham o XP do nível juntos (o caso comum), todos numa linha.
		for unit in session.state.player_team:
			var hero = campaign.hero(unit.hero_id)
			hero.xp = int(load("res://scripts/flow/hero_levels.gd").next_cost(hero).get("xp", 0)) if name == "fight_level" else 0
		street._arena.boss_fight = name == "fight_loot"
		if name == "fight_loot":
			fresh.session.expedition.corridor.index = fresh.session.expedition.corridor.steps.size() - 1
		if name == "fight_fled" or name == "fight_defeat":
			fresh.session.expedition.loot.seeds = 6
			fresh.session.expedition.loot.scrap = 2
		# As três estrelas da maquete (a luta recém-aberta ainda não tem critério cumprido).
		var rewards: Dictionary = Rewards.criteria(session, name == "fight_loot", "fase_1") if result == "victory" else {}
		if not rewards.is_empty():
			rewards.stars = 3
		fight.show_result(result, false, rewards)
		await _frames(12)
		await _shot(name)
		fight.result_closed.emit()
		await _frames(4)
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
