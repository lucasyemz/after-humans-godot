## Fotos das skins (#138): o Bento numa skin (--skin=<id>, "default" para a padrão) na Sala dos Personagens (com o
## seletor da roupa), dormindo no Dormitório, na rua, na luta e no acampamento. Rodar com a padrão e com a skin dá o
## antes e o depois, lado a lado.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_138.gd -- --out=<pasta> [--skin=bento_watch] [--text-size=2]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

const BENTO := "hero_cao_bento"
const ENEMIES := ["robot", "cao_eco"]

var out := ""
var skin := "default"
var campaign
var flow


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--skin="):
			skin = arg.trim_prefix("--skin=")
		elif arg.begins_with("--text-size="):
			root.get_node("Settings").set_text_size(int(arg.trim_prefix("--text-size=")))
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	campaign = root.get_node("Campaign")
	flow = root.get_node("GameFlow")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	await _station()
	await _street()
	await _camp()
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _dressed(seed_value: int) -> Dictionary:
	var S = load("res://scripts/flow/station_rules.gd")
	var c: Dictionary = campaign.create_initial(seed_value)
	S.unlock_all_skins(c)
	campaign.state = c
	print("skin: %s (%s)" % [skin, S.choose_skin(c, BENTO, skin)])
	return c


## A Sala com o seletor e o Bento escolhido; depois, ele dormindo no beliche do Dormitório.
func _station() -> void:
	var S = load("res://scripts/flow/station_rules.gd")
	var c := _dressed(138)
	c.station.last_return = {}
	campaign.save()
	flow.change_to("station", {}, false)
	await _settle()
	var station = current_scene
	var hud = station.hud
	hud.open_room(S.CHARACTERS)
	await _frames(10)
	hud._room_screen.selected = BENTO
	hud._room_screen.rebuild()
	await _frames(40)
	await _shot("01-sala")
	hud.close_panel()
	await _frames(10)
	# O Bento dormindo no Dormitório (a pose de dormir da Estação), com a câmera no cômodo.
	var card = station.residents.get(BENTO)
	var poses: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/station_poses.json"))
	for walker in station._walkers:
		if walker.get("hero_id", "") == BENTO:
			walker.wait = INF
			walker.sitting = 0.0
	card.show_art(load("res://scripts/flow/skins.gd").pose(poses[BENTO + "_sleep"], BENTO))
	card.position = station.sleep_slots()[0]
	station.focus_room_stage(S.DORMITORY, 160.0, 1760.0, true)
	await _frames(40)
	hud.visible = false
	await _frames(4)
	await _shot("02-dormitorio")


## A rua (a equipe parada) e a luta (a escolha da primeira ação).
func _street() -> void:
	var J = load("res://scripts/flow/journey_rules.gd")
	var c := _dressed(1381)
	c.preferred_formation = [BENTO, "hero_gato_nick", "hero_sapo_iris", "hero_coruja_vespera"]
	J.start_expedition(c, "fase_1", 4242)
	campaign.save()
	flow.change_to("street", {}, false)
	await _settle()
	var street = current_scene
	street.apply_corridor_weather("sunset")
	street.corridor.busy = true
	for index in street.corridor.guards:
		for card in street.corridor.guards[index].cards:
			card.visible = false
	await _frames(40)
	await _shot("03-rua")
	var cards: Array = []
	for id in ENEMIES:
		cards.append(street.corridor._enemy_card(id))
	var heroes: Array = street.party_ids.map(func(id): return campaign.hero(id))
	street.begin_fight()
	var arena = street._arena
	arena.auto_battle = false
	arena.start(heroes, street._heroes, ENEMIES, cards, street._leader.position.x + 3.0, true, 7)
	for i in 900:
		if arena.hud != null and arena.hud.waiting:
			break
		await process_frame
	await _frames(20)
	await _shot("04-luta")


## O acampamento, sentado no chão em volta da fogueira.
func _camp() -> void:
	var J = load("res://scripts/flow/journey_rules.gd")
	var c := _dressed(23)
	J.start_expedition(c, "fase_1", 23)
	campaign.save()
	flow.change_to("street", {}, false)
	await _settle()
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
	await _shot("05-acampamento")


func _settle() -> void:
	for i in 600:
		await process_frame
		if not flow.busy and current_scene != null and i > 10:
			break
	await _frames(30)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
