## O antes e o depois do Corredor de Contenção (#147) dentro do jogo: a jornada do tutorial de verdade (AHTutorial.begin,
## a cena da rua, data/scenarios/ContainmentCorridor.json), na câmera da exploração, de noite como a fase. Roda igual na
## main (o antes) e na branch (o depois): nada é montado por fora do jogo.
##   xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     -s res://docs/design/tutorial-acabamento/capture_game.gd -- --out=<pasta> [--zones=0,1] [--nick] [--fight] [--exit]
##     [--proto]
## --nick põe o Nick na equipe (ele chega no aperto da sala das celas: as zonas 2 e 3 e o embarque são com os quatro).
## --fight fotografa a primeira luta (zona 0). --exit, a equipe na porta aberta do vagão, com o trem parado.
## --proto liga o protótipo da luz que é do código (a lanterna do líder a 30% no Corredor), para mostrar a proposta ao
## Claude; sem ele, a foto é o jogo como está.
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
var only_zones := []
var nick := false
var fight := false
var exit_shot := false
var proto := false
var lantern_scale := -1.0
var key_scale := -1.0
var campaign
var flow


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--zones="):
			only_zones = Array(arg.trim_prefix("--zones=").split(",")).map(func(z): return int(z))
		elif arg == "--nick":
			nick = true
		elif arg == "--fight":
			fight = true
		elif arg == "--exit":
			exit_shot = true
		elif arg == "--proto":
			proto = true
		elif arg.begins_with("--lantern="):
			proto = true
			lantern_scale = float(arg.trim_prefix("--lantern="))
		elif arg.begins_with("--key="):
			proto = true
			key_scale = float(arg.trim_prefix("--key="))
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	campaign = root.get_node("Campaign")
	flow = root.get_node("GameFlow")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	var c: Dictionary = campaign.create_initial(7)
	if not load("res://scripts/flow/tutorial_rules.gd").begin(c):
		push_error("A jornada do tutorial não começou.")
		quit(1)
		return
	if nick:
		c.session.expedition.team.append("hero_gato_nick")
	campaign.state = c
	campaign.save()
	flow.change_to("street", {}, false)
	await _settle()
	var street = current_scene
	print("mapa: ", street.scenario.map_name, ", zonas ", street.scenario.zones.size())
	_steady(street)
	street.corridor.busy = true
	if street.corridor.guide != null:
		street.corridor.guide.set_process(false)
	for zone_index in street.scenario.zones.size():
		if only_zones.is_empty() or only_zones.has(zone_index):
			var zone: Dictionary = street.scenario.zones[zone_index]
			await _zone(street, zone_index, zone.x0 + 5.6, "zone%d" % zone_index)
	if exit_shot:
		var last: int = street.scenario.zones.size() - 1
		street.scenario.park_train(true)
		_show_patrols(street, false)
		await _zone(street, last, float(street.scenario.zones[last].x1) - 0.9, "exit", false)
	street.corridor.busy = false
	if fight:
		await _fight(street)
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	quit(0)


## As lâmpadas paradas acesas na foto (o pisca é do jogo; sem isso, cada foto pegaria as lâmpadas numa fase diferente e
## o antes e o depois não seriam comparáveis).
func _steady(street) -> void:
	var world = street.scenario
	world.set_process(false)
	for entry in world._blink_lights:
		entry[0].light_energy = entry[1]
	for entry in world._blink_parts:
		entry[0].set_surface_override_material(0, entry[1])


func _zone(street, index: int, x: float, tag: String, hud := true) -> void:
	street.set_scenario_zone(index)
	street._place_leader(Vector3(x, street.floor_y, street.lane_z))
	street._raining = false
	street._wet = 0.0
	street._apply_weather()
	if proto:
		_proto(street)
	await _frames(20)
	_hide_ui()
	await _frames(3)
	await _shot(tag)
	_show_ui()
	if hud:
		await _frames(3)
		await _shot(tag + "-hud")


## O protótipo da luz que é do código (para a integração): no Corredor de Contenção, a lanterna de mão do líder a 30%
## (é ela que esquentava o mapa: a poça laranja por cima do vermelho das lâmpadas; as capturas aprovadas do #173 não a
## tinham). Apagada de vez, a equipe sumia na plataforma, antes de o trem chegar; a luz de leitura fica como está.
## --lantern=<escala> e --key=<escala> testam outras doses (0 apaga a lanterna).
const PROTO_LANTERN := 0.3
const PROTO_KEY := 1.0


func _proto(street) -> void:
	var lantern := PROTO_LANTERN if lantern_scale < 0.0 else lantern_scale
	for light in street._leader.find_children("*", "OmniLight3D", true, false):
		if not light.has_meta("proto"):
			light.set_meta("proto", true)
			light.light_energy *= lantern
			light.visible = lantern > 0.0
	street._key_light.light_energy *= PROTO_KEY if key_scale < 0.0 else key_scale


func _fight(street) -> void:
	var corridor = street.corridor
	var picked := -1
	var keys: Array = corridor.guards.keys()
	keys.sort()
	for index in keys:
		if street.scenario.zone_at(corridor.guards[index].cards[0].position.x) == 0:
			picked = index
			break
	if picked < 0:
		push_error("Sem patrulha na zona 0.")
		return
	var route: Dictionary = campaign.state.session.expedition.corridor
	for i in picked:
		route.steps[i].resolved = true
	route.index = picked
	route.current_house = -1
	var front = corridor.guards[picked].cards[0]
	corridor._enter_segment(corridor._segment_of(picked), front.position.x - 2.6)
	await _frames(10)
	route.index = picked
	corridor._start_fight(picked, true)
	var arena = street._arena
	for i in 400:
		if arena.hud != null and arena.hud.waiting:
			break
		if i == 30 and not arena.active:
			push_error("A luta não começou.")
			return
		await process_frame
	_steady(street)
	if proto:
		_proto(street)
	await _frames(30)
	_hide_ui()
	await _frames(3)
	await _shot("fight")
	_show_ui()
	await _frames(3)
	await _shot("fight-hud")


func _show_patrols(street, shown: bool) -> void:
	for index in street.corridor.guards:
		for card in street.corridor.guards[index].cards:
			card.visible = shown


## A interface: as CanvasLayers e os Controls de cima (os que não estão dentro de outro Control).
func _ui_nodes() -> Array:
	var nodes: Array = root.find_children("*", "CanvasLayer", true, false)
	for control in root.find_children("*", "Control", true, false):
		if not (control.get_parent() is Control):
			nodes.append(control)
	return nodes


func _hide_ui() -> void:
	for node in _ui_nodes():
		node.set_meta("was_visible", node.visible)
		node.visible = false


func _show_ui() -> void:
	for node in _ui_nodes():
		if node.has_meta("was_visible"):
			node.visible = node.get_meta("was_visible")
			node.remove_meta("was_visible")


func _settle() -> void:
	for frame in 900:
		await process_frame
		if not flow.busy and flow.passage == null and current_scene != null and current_scene.name == "Street" and frame > 3:
			break
	await _frames(30)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
