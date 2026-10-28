## QA por captura do tambor com fogo na parada de descanso (#205, decisão do Lucas): onde a fogueira cairia na água do
## chão, o tambor de ferro com fogo (T_LP03) no lugar dela. Pela cena de verdade:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_213.gd -- --out=<pasta>
## Campanha própria na pasta da saída. Roda também na main de antes. 01 a parada no Depósito Inundado (fase 5, semente
## 1, trecho 2), acampada; 02 o mesmo com dois quadros do fogo a outro tempo (o fogo tremula); 03 a parada seca do Cais
## (fase 2), que segue com a fogueira.
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
	await _stop("fase_5", 1, ["01-depot-camp", "02-depot-camp-flicker"])
	await _stop("fase_2", 32, ["03-dock-camp"])
	print("capturas do tambor em %s" % out)
	quit(0)


func _stop(phase_id: String, seed_value: int, shots: Array) -> void:
	var c: Dictionary = campaign.create_initial(seed_value)
	J.start_expedition(c, phase_id, seed_value)
	var route: Dictionary = c.session.expedition.corridor
	var rest: int = route.steps.map(func(s): return s.type).find("rest")
	for i in rest:
		route.steps[i].resolved = true
	route.index = rest - 1
	campaign.state = c
	campaign.save()
	flow.change_to("street", {}, false)
	var street = null
	for frame in 900:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.name == "Street" and frame > 3:
			street = current_scene
			break
	if street == null:
		return
	await create_timer(1.0).timeout
	var corridor = street.corridor
	for site in route.sites:
		if site.step == rest:
			site.camp_site = false
	corridor._enter_segment(corridor._segment_of(rest), corridor._step_x(rest, 0.5))
	var outcome: String = J.enter_step(campaign.state, rest)
	corridor._announce(rest, outcome, true)
	await create_timer(1.0).timeout
	street.exploration_hud.close_modal()
	await corridor._camp_at_stop()
	await create_timer(1.5).timeout
	for name in shots:
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
		await create_timer(0.3).timeout
