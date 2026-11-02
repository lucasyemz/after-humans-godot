## As fotos do ícone de resgate (#295): o trecho do preso na barra de trechos e o pino do resgate no Mapa da Rede.
## Mesmo cenário da prancha do Codex (semente 23, a Véspera capturada na fase 2, expedição 4242), sem trocar textura à
## mão: roda igual na main (o antes) e na branch (o depois).
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 -s res://tools/capture_295.gd -- --out=<pasta>
extends SceneTree

var output := ""


func _initialize() -> void:
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await process_frame


func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(file + ".png"))


func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	if output == "":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	await process_frame
	var service = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	var settings = root.get_node("Settings")
	service.save_dir = output.path_join("isolated_save")
	service.save_time_on_quit = false
	settings._persist = false
	root.get_node("Tips").enabled = false
	var S = load("res://scripts/flow/station_rules.gd")
	var J = load("res://scripts/flow/journey_rules.gd")
	var R = load("res://scripts/flow/rescue_rules.gd")
	var c: Dictionary = service.create_initial(23)
	c.completed_phases = ["fase_1"]
	c.station.rooms[S.PREPARATION] = 2
	var vespera: Dictionary = c.roster.filter(func(h): return h.class_id == "coruja")[0]
	vespera.captured = {"mission": "cisterna_turva", "spot": 2, "phase": "fase_2", "day": 0}
	service.state = c
	J.start_expedition(c, "fase_2", 4242)
	var route: Dictionary = c.session.expedition.corridor
	var index: int = R.current(c).step
	for i in index:
		route.steps[i].resolved = true
	route.index = index
	flow.change_to("street", {}, false)
	await frames(40)
	while flow.busy:
		await process_frame
	var street = current_scene
	if street.corridor.prisoner != null:
		street._place_leader(street.corridor.prisoner.position - Vector3(0.8, 0, 0))
	await frames(20)
	Engine.time_scale = 0
	street.exploration_hud.refresh(c)
	await frames(8)
	await shot("route")
	Engine.time_scale = 1
	c.session = {"screen": "shelter", "expedition": null}
	flow.change_to("station", {}, false)
	await frames(35)
	while flow.busy:
		await process_frame
	var map = current_scene.hud._map
	map.open("")
	map.show_tab("missions")
	map.pick_mission("rescue:0")
	await frames(12)
	Engine.time_scale = 0
	await frames(4)
	await shot("map")
	var pin = map.find_child("Rescue_0", true, false)
	var rect := Rect2()
	if pin != null:
		rect = (pin as Control).get_global_rect()
	var file := FileAccess.open(output.path_join("rects.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"route_index": index, "pin": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}))
	file.close()
	Engine.time_scale = 1
	unload_current_scene()
	await frames(3)
	root.get_node("Sound").quit(0)
