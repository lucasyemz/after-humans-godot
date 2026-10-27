## QA por captura da #129 (a câmera da exploração mais perto e a troca de formação), pela cena de verdade:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_129.gd -- --out=<pasta>
## Campanha própria na pasta da saída. Roda também na main de antes (sem a formação): a rua, uma casa e os seis cenários
## na câmera da exploração (a equipe no começo do mapa, com a próxima patrulha à frente) e, depois, a formação aberta.
extends SceneTree

const MAPS := [["street", "fase_1", 0], ["RiverDock", "fase_2", 0], ["RootBridge", "fase_2", 4], ["SealedShelter", "fase_3", 0],
	["TriageGate", "fase_4", 0], ["FloodedDepot", "fase_5", 0], ["SewerDucts", "fase_5", 4]]

var out := ""
var campaign
var flow
var J
var S


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
	S = load("res://scripts/flow/station_rules.gd")
	root.get_node("Tips").enabled = false
	root.get_node("Settings")._persist = false
	campaign.save_dir = out.path_join("save")
	for i in MAPS.size():
		await _map(i)
	await _formation()
	print("capturas da #129 em %s" % out)
	quit(0)


func _map(i: int) -> void:
	var spec: Array = MAPS[i]
	var c: Dictionary = campaign.create_initial(9)
	c.completed_phases = ["fase_1", "fase_2", "fase_3", "fase_4"]
	S.confirm_departure(c, c.preferred_formation.duplicate(), 0, 4242, spec[1], "")
	var route: Dictionary = c.session.expedition.corridor
	# Os trechos vencidos (nenhuma patrulha encostada na equipe na chegada), menos o guardião.
	for step in route.steps.size() - 1:
		route.steps[step].resolved = true
	route.index = int(spec[2])
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
	await _wait(1.5)
	await _shot("%02d-%s" % [i + 1, spec[0]])
	if i == 0:
		# A casa: a primeira loja aberta do caminho.
		var corridor = street.corridor
		for site_index in route.sites.size():
			if not route.sites[site_index].locked:
				route.index = maxi(route.index, int(route.sites[site_index].step))
				for step in route.index:
					route.steps[step].resolved = true
				route.sites[site_index].has_enemy = false
				await corridor._enter_house(site_index)
				await _wait(1.0)
				await _shot("01b-house")
				break


## A formação aberta na Rua das Vitrines: o Bento escolhido e o cursor na Íris.
func _formation() -> void:
	var c: Dictionary = campaign.create_initial(9)
	S.confirm_departure(c, c.preferred_formation.duplicate(), 0, 4242, "fase_1", "")
	campaign.state = c
	campaign.save()
	flow.change_to("street", {}, false)
	var street = null
	for frame in 900:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.name == "Street" and frame > 3:
			street = current_scene
			break
	if street == null or not street.exploration_hud.has_method("open_formation"):
		return
	await _wait(1.0)
	var hud = street.exploration_hud
	street.corridor.open_formation()
	hud._formation_pick = 0
	hud._formation_cursor = 2
	hud._show_formation()
	await _wait(0.5)
	await _shot("08-formation")


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print(name)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout
