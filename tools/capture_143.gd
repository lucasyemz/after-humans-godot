## QA por captura da #143 (a ferramenta à vista, a pose de cuidar e a parada que vira acampamento), pela cena de verdade:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_143.gd -- --out=<pasta>
## Campanha própria na pasta da saída (o save do jogador fica intacto). Roda também na main de antes (o que ela não tem
## fica de fora): 01 a parada, 02 a fogueira da parada no cenário, 03 a pose de cuidar no acampamento, 04 o aviso da
## ferramenta, 05 a Mochila com a novidade, 06 o curativo na luta.
extends SceneTree

var out := ""
var campaign
var flow
var J


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	campaign = root.get_node("Campaign")
	flow = root.get_node("GameFlow")
	J = load("res://scripts/flow/journey_rules.gd")
	root.get_node("Tips").enabled = false
	root.get_node("Settings")._persist = false
	campaign.save_dir = out.path_join("save")
	await _stop("fase_1", 31, "01-stop-choice", "")
	await _stop("fase_2", 32, "", "02-stop-camp-scenario")
	await _tool()
	await _combat()
	print("capturas da #143 em %s" % out)
	quit(0)


func _open(c: Dictionary):
	campaign.state = c
	campaign.save()
	flow.change_to("street", {}, false)
	for frame in 900:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.name == "Street" and frame > 3:
			await _wait(1.0)
			return current_scene
	return null


func _stop(phase_id: String, seed_value: int, choice_shot: String, camp_shot: String) -> void:
	var c: Dictionary = campaign.create_initial(seed_value)
	J.start_expedition(c, phase_id, seed_value)
	var team: Array = c.session.expedition.team
	var lead: Dictionary = c.roster.filter(func(h): return h.id == team[0])[0]
	lead.hp = int(lead.max_hp) - 9
	lead.instinct = 60
	var route: Dictionary = c.session.expedition.corridor
	var rest: int = route.steps.map(func(s): return s.type).find("rest")
	for i in rest:
		route.steps[i].resolved = true
	route.index = rest - 1
	var street = await _open(c)
	if street == null:
		return
	var corridor = street.corridor
	for site in route.sites:
		if site.step == rest:
			site.camp_site = false
	corridor._enter_segment(corridor._segment_of(rest), corridor._step_x(rest, 0.5))
	var outcome: String = J.enter_step(campaign.state, rest)
	corridor._announce(rest, outcome, true)
	await _wait(1.0)
	if choice_shot != "":
		await _shot(choice_shot)
	if camp_shot == "" or not corridor.has_method("_camp_at_stop"):
		return
	street.exploration_hud.close_modal()
	await corridor._camp_at_stop()
	await _wait(1.5)
	await _shot(camp_shot)
	corridor._camp_care(team[0], "bandage")
	await _wait(0.5)
	await _shot("03-camp-care-pose")


func _tool() -> void:
	var c: Dictionary = campaign.create_initial(33)
	J.start_expedition(c, "fase_1", 33)
	var street = await _open(c)
	if street == null:
		return
	var hud = street.exploration_hud
	J.grant_tool(campaign.state, "lanterna")
	hud.refresh(campaign.state)
	if not hud.has_method("show_tool_notice"):
		# Antes: a ferramenta chega só no aviso curto da busca.
		hud.toast("Uma lanterna de manivela que ainda acende depois de umas voltas. (Ferramenta: Lanterna)", 5.0)
	await _wait(1.0)
	await _shot("04-tool-notice")
	if hud.has_method("hide_tool_notice"):
		hud.hide_tool_notice()
	hud.show_inventory()
	await _wait(1.0)
	await _shot("05-bag-new-tool")
	hud.close_modal()


func _combat() -> void:
	var c: Dictionary = campaign.create_initial(34)
	J.start_expedition(c, "fase_1", 34)
	c.inventory.bandages = 3
	var street = await _open(c)
	if street == null:
		return
	street.corridor.debug_next_fight()
	await _wait(0.5)
	street.corridor._start_fight(campaign.state.session.expedition.corridor.index, true)
	var arena = street._arena
	var limit := Time.get_ticks_msec() + 30000
	while (arena.hud == null or not arena.hud.waiting) and Time.get_ticks_msec() < limit:
		await process_frame
	await _wait(0.8)
	var actor = arena.session.current_actor()
	actor.hp = maxi(1, actor.max_hp - 10)
	arena.hud.command_chosen.emit({"kind": "item", "item": "bandage"})
	await _wait(0.35)
	await _shot("06-combat-item-pose")


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print(name)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout
