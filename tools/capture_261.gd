## Fotos das habilidades de acampamento (#261):
##   camp: o acampamento com as habilidades do Bento, a de aliado esperando o alvo (no Nick) e depois de usada;
##   room: a Sala dos Personagens com a seção Acampamento (uma escolha do nível a fazer, a bloqueada apontada).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_261.gd -- --out=<pasta> --case=camp|room [--text-size=2]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
var case_name := "camp"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--case="):
			case_name = arg.trim_prefix("--case=")
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	if case_name == "room":
		await _room(campaign)
	else:
		await _camp(campaign)
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _camp(campaign) -> void:
	var flow = root.get_node("GameFlow")
	var S = load("res://scripts/flow/station_rules.gd")
	var J = load("res://scripts/flow/journey_rules.gd")
	var c: Dictionary = campaign.create_initial(23)
	J.start_expedition(c, "fase_1", 23)
	var team: Array = c.session.expedition.team
	S.hero(c, team[0]).hp = int(S.hero(c, team[0]).max_hp) - 12
	S.hero(c, "hero_gato_nick").instinct = 40
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
	var camp = corridor.camp
	var ids: Array = camp.members.map(func(m): return m.hero_id)
	camp.select(ids.find("hero_cao_bento"))
	while camp.switching():
		await process_frame
	await _frames(20)
	var panel = street.exploration_hud.camp_hud
	(panel.find_child("Skill_camp_cao_ombro_a_ombro", true, false) as Button).grab_focus()
	await _frames(5)
	await _shot("10-camp-skills")
	(panel.find_child("Skill_camp_cao_ombro_a_ombro", true, false) as Button).pressed.emit()
	camp.select(ids.find("hero_gato_nick"))
	while camp.switching():
		await process_frame
	await _frames(20)
	await _shot("11-target")
	panel._choose_target("hero_gato_nick")
	while camp.switching():
		await process_frame
	await _frames(10)
	(panel.find_child("Skill_camp_cao_ombro_a_ombro", true, false) as Button).grab_focus()
	await _frames(5)
	await _shot("12-used")


func _room(campaign) -> void:
	var flow = root.get_node("GameFlow")
	var S = load("res://scripts/flow/station_rules.gd")
	var c: Dictionary = campaign.create_initial(2611)
	var bento = S.hero(c, "hero_cao_bento")
	bento.level = 4
	bento.camp_unlocked = ["camp_cao_palavra_firme"]
	c.station.last_return = {}
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	await _frames(10)
	while flow.busy:
		await process_frame
	await _frames(20)
	var hud = current_scene.hud
	hud.open_room(S.CHARACTERS)
	await _frames(10)
	var screen = hud._room_screen
	screen.selected = "hero_cao_bento"
	screen.camp_skill = "camp_cao_dividir_a_carga"
	screen._reveal = true
	screen.rebuild()
	await _frames(20)
	await _shot("20-room")


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
