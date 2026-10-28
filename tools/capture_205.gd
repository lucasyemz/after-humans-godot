## QA por captura da #205 (as poses do acampamento no chão), pela cena de verdade:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_205.gd -- --out=<pasta> [--level=0..3]
## Campanha própria na pasta da saída (o save do jogador fica intacto). Roda também na main de antes. O acampamento numa
## casa com quatro equipes: os fundadores e, com o Bento e o Nick, os recrutas com pose (cão e gato, sapo e coruja) e o
## Guaxinim e o Tatu (sem pose de acampamento). Cada equipe duas vezes: com o último ferido (deita) e com todos
## feridos (todos deitam). Cada foto tem o recorte dos pés (feet-*).
extends SceneTree

## Dois recrutas por equipe (o Alojamento do começo tem lugar para dois), entre o Bento e o Nick.
const TEAMS := {"founders": [], "dog_cat": ["cao", "gato"], "frog_owl": ["sapo", "coruja"], "raccoon_armadillo": ["rato", "tatu"]}

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--level="):
			level = int(arg.trim_prefix("--level="))
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
	root.get_node("Settings")._persist = false
	if level >= 0:
		root.get_node("Settings").set_level(level)
	for shot in TEAMS.keys().map(func(k): return [k, false]) + TEAMS.keys().map(func(k): return [k, true]):
		var team_name: String = shot[0]
		var c: Dictionary = campaign.create_initial(23)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var recruited: Array = []
		for class_id in TEAMS[team_name]:
			if not c.unlocked_classes.has(class_id):
				c.unlocked_classes.append(class_id)
			S.recruit(c, class_id, rng, "Teste")
			recruited.append(c.roster.back().id)
		J.start_expedition(c, "fase_1", 23)
		if not recruited.is_empty():
			c.session.expedition.team = [c.roster[0].id, recruited[0], recruited[1], c.roster[1].id]
		# Na primeira volta só o último deita; na segunda, todos (as 16 poses deitadas e sentadas aparecem).
		for id in (c.session.expedition.team if shot[1] else [c.session.expedition.team.back()]):
			S.hero(c, id).hp = maxi(1, int(S.hero(c, id).max_hp) / 5)
		campaign.state = c
		campaign.save()
		flow.change_to("street", {}, false)
		await _frames(10)
		while flow.busy:
			await process_frame
		var corridor = current_scene.corridor
		var route: Dictionary = c.session.expedition.corridor
		var site: int = route.sites.map(func(s): return s.camp_site).find(true)
		route.index = route.sites[site].step
		for i in route.index + 1:
			route.steps[i].resolved = true
		route.sites[site].has_enemy = false
		await corridor._enter_house(site)
		await _frames(20)
		await corridor._start_camp()
		await _frames(40)
		await _shot("camp-" + team_name + ("-asleep" if shot[1] else ""))
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(out.path_join(name + ".png"))
	image.get_region(Rect2i(0, 520, 1920, 260)).save_png(out.path_join("feet-" + name + ".png"))
	print("foto: ", name)
