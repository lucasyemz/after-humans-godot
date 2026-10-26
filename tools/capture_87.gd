## Fotos do Mapa da Rede (#87, docs/design/hud-fluxo.md e phase-map.md): a fase 1 concluída e a Pesquisa recuperada, com
## nada escolhido, a Ponte escolhida (aberta: leitura do guardião e dos inimigos; sem o Depósito melhorado e a Forja, o
## resto não lido), a Rua escolhida (concluída: leitura completa) e a Sala Esquecida (bloqueada).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_87.gd -- --out=<pasta> [--text-size=2] [--colorblind]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var colorblind := false
	var text_size := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--colorblind":
			colorblind = true
		elif arg.begins_with("--text-size="):
			text_size = int(arg.trim_prefix("--text-size="))
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	var settings = root.get_node("Settings")
	var S = load("res://scripts/flow/station_rules.gd")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	settings.set_colorblind(colorblind)
	settings.set_text_size(text_size)
	var c: Dictionary = campaign.create_initial(23)
	c.completed_phases = ["fase_1"]
	c.station.rooms[S.RESEARCH] = 1
	# As sementes do exemplo da #86 (radar_snapshot.json): a mesma rota em toda captura.
	c.station.route_seeds = {"fase_1": 4242, "fase_2": 4242, "fase_3": 4242, "fase_4": 4242, "fase_5": 4242}
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	await _frames(10)
	while flow.busy:
		await process_frame
	await _frames(30)
	var hud = current_scene.hud
	hud._map.open("")
	await _frames(8)
	await _shot("map_none")
	for spec in [["fase_2", "map"], ["fase_1", "map_known"], ["fase_3", "map_locked"]]:
		hud._map.open(spec[0])
		await _frames(8)
		await _shot(spec[1])
	# A leitura completa de uma fase aberta: o Depósito melhorado e a Forja.
	c.station.rooms[S.DEPOT] = 2
	c.station.rooms[S.FORGE] = 1
	hud._map.open("fase_2")
	await _frames(8)
	await _shot("map_full")
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
