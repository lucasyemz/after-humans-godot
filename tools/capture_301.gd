## Foto da chegada ao mapa da fase com o descanso no 1º trecho dele (#301): a equipe vence a travessia e viaja; a foto
## é tirada depois do cartão da viagem, no lugar onde a pergunta "Um lugar quieto" deve aparecer.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_301.gd -- --out=<pasta> [--phase=fase_2 --seed=9]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
var phase_id := "fase_2"
var seed_value := 9


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--phase="):
			phase_id = arg.trim_prefix("--phase=")
		elif arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
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
	var flow = root.get_node("GameFlow")
	var J = load("res://scripts/flow/journey_rules.gd")
	var c: Dictionary = campaign.create_initial(seed_value)
	J.start_expedition(c, phase_id, seed_value)
	var route: Dictionary = c.session.expedition.corridor
	var first: int = int(J.step_range(phase_id, false)[0])
	for i in first:
		route.steps[i].resolved = true
	route.index = first - 1
	campaign.state = c
	campaign.save()
	flow.change_to("street", {}, false)
	await _frames(10)
	while flow.busy:
		await process_frame
	await _frames(10)
	current_scene.corridor.debug_next_fight()
	await _frames(10)
	while flow.busy:
		await process_frame
	await _frames(40)
	await _shot("%s-%d-arrival" % [phase_id, seed_value])
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
