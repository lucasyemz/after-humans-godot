## Harness de QA da #210, sem alteração na produção. Fotos do acampamento (#77): a equipe numa casa com fogueira, acampando. Com a cena (#77): a roda em volta do fogo,
## Comer no primeiro (o efeito e o número verde), o terceiro escolhido e o curativo nele; numa versão anterior, só o
## painel do acampamento (as fotos de antes).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_camp.gd -- --out=<pasta> [--recruits] [--reduced]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
var proposal := false
var sleeping := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var recruits := false
	var reduced := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--proposal": proposal = true
		if arg == "--sleep": sleeping = true
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
	c.inventory.seeds = 500
	c.unlocked_classes = ["cao", "gato", "sapo", "coruja", "rato", "tatu"]
	if recruits:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for class_id in ["rato", "tatu"]:
			S.recruit(c, class_id, rng, "Teste")
	c.settings.reduced_environment_effects = reduced
	J.start_expedition(c, "fase_1", 23)
	if recruits:
		c.session.expedition.team = [c.roster[0].id, c.roster[2].id, c.roster[4].id, c.roster[5].id]
	var team: Array = c.session.expedition.team
	S.hero(c, team[0]).hp = int(S.hero(c, team[0]).max_hp) - 12
	S.hero(c, team[2]).hp = int(S.hero(c, team[2]).max_hp) - 9
	var tired = S.hero(c, team.back())
	tired.hp = int(tired.max_hp)
	for id in team:
		var h = S.hero(c,id)
		if h.get("art_variant", "") in ["raccoon_recruit_01", "armadillo_recruit_01"]: h.hp = maxi(1,int(h.max_hp)/5) if sleeping else h.max_hp
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
	await corridor._start_camp()
	await _frames(30)
	Engine.time_scale = 0.0
	await _frames(2)
	await _shot("before" + ("_sleep" if sleeping else "_seat"))
	if proposal:
		var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/design/recruit_camp/contract.json"))
		for pose in contract.poses:
			var variant: String = pose.recruit_id
			if not corridor.camp._poses.recruits.has(variant): corridor.camp._poses.recruits[variant] = {}
			corridor.camp._poses.recruits[variant][pose.state] = pose.show_art
		corridor.camp._arrange(team)
		await _frames(2)
	Engine.time_scale = 0.0
	await _frames(2)
	await _shot(("after" if proposal else "before") + ("_sleep" if sleeping else "_seat"))
	quit(0)


func _frames(count: int) -> void:
	for i in count: await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ",name)
