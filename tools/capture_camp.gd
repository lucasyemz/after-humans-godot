## Fotos do acampamento (#77): a equipe numa casa com fogueira, acampando. Com a cena (#77): a roda em volta do fogo,
## Comer no primeiro (o efeito e o número verde), o terceiro escolhido e o curativo nele; numa versão anterior, só o
## painel do acampamento (as fotos de antes).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_camp.gd -- --out=<pasta> [--recruits] [--reduced]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var recruits := false
	var reduced := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--recruits":
			recruits = true
		elif arg == "--reduced":
			reduced = true
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
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	var c: Dictionary = campaign.create_initial(23)
	if recruits:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for class_id in ["gato", "coruja"]:
			S.recruit(c, class_id, rng, "Teste")
	c.settings.reduced_environment_effects = reduced
	J.start_expedition(c, "fase_1", 23)
	if recruits:
		c.session.expedition.team = [c.roster[0].id, c.roster[2].id, c.roster[4].id, c.roster[5].id]
	var team: Array = c.session.expedition.team
	S.hero(c, team[0]).hp = int(S.hero(c, team[0]).max_hp) - 12
	S.hero(c, team[2]).hp = int(S.hero(c, team[2]).max_hp) - 9
	var tired = S.hero(c, team.back())
	tired.hp = maxi(1, int(tired.max_hp) / 5)
	campaign.state = c
	campaign.save()
	flow.change_to("street", {}, false)
	await _frames(10)
	while flow.busy:
		await process_frame
	var street = current_scene
	var corridor = street.corridor
	var route: Dictionary = c.session.expedition.corridor
	var site: int = route.sites.map(func(s): return s.camp_site).find(true)
	route.index = route.sites[site].step
	for i in route.index + 1:
		route.steps[i].resolved = true
	route.sites[site].has_enemy = false
	await corridor._enter_house(site)
	await _frames(20)
	await _shot("00-house")
	await corridor._start_camp()
	await _frames(30)
	await _shot("01-camp")
	if corridor.get("camp") == null:
		quit(0)
		return
	var hud = street.exploration_hud
	hud.camp_hud.eat_button.pressed.emit()
	await _frames(3)
	await _shot("02-eat-response")
	corridor.camp.select(2)
	while corridor.camp.switching():
		await process_frame
	await _frames(20)
	hud.camp_hud.heal_button.pressed.emit()
	await _frames(3)
	await _shot("03-third-heal")
	# A Mochila no acampamento, na ampola (#98): as cargas que sobram para a próxima luta.
	if hud.has_method("show_inventory"):
		hud.show_inventory()
		await _frames(5)
		var bags: Array = hud.find_children("*", "AHInventoryPanel", true, false)
		if not bags.is_empty() and "selected" in bags[0]:
			bags[0].selected = "ampoule"
			bags[0]._build()
			await _frames(10)
			await _shot("04-bag-ampoule")
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
