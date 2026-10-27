## O mapa do tutorial (#147) no motor, na câmera da exploração dos outros cenários: monta map/ContainmentCorridor.json
## (build_map.py, no contrato de tools/sync_scenarios.py) pela cena da rua de verdade e fotografa cada zona com o Bento e
## o Nick, sem a interface e com ela. Com --ref=<Mapa>, fotografa um cenário que já existe do mesmo jeito (a mesma
## câmera, a mesma equipe, o mesmo ponto da zona), para o lado a lado. Com --fight, também a primeira luta do mapa
## (fight_two.png/json, para as telas da dica de luta).
##   xvfb-run -n 93 -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     -s res://docs/design/tutorial/capture_map.gd -- --out=<pasta> [--ref=SealedShelter] [--fight | --only-fight]
##
## Até o mapa entrar no jogo (é da integração: MAPS, DISPLAY e a fase do tutorial), a captura o põe no lugar do Abrigo
## Lacrado só enquanto roda: grava o JSON por cima de data/scenarios/SealedShelter.json e devolve o original no fim
## (confira com git status). A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
##
## O que só o código faz (o pisca, a névoa baixa, o ambiente do lugar) entra aqui como protótipo, em _proto(), com os
## valores que a integração deve levar para o jogo.
extends SceneTree

const HOST := "res://data/scenarios/SealedShelter.json"
const MAP := "res://docs/design/tutorial/map/ContainmentCorridor.json"

var out := ""
var ref := ""
var fight := false
var zones := true
var campaign
var flow
var _host_bytes := PackedByteArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--ref="):
			ref = arg.trim_prefix("--ref=")
		elif arg == "--fight":
			fight = true
		elif arg == "--only-fight":
			fight = true
			zones = false
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	campaign = root.get_node("Campaign")
	flow = root.get_node("GameFlow")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	if ref == "":
		_host_bytes = FileAccess.get_file_as_bytes(HOST)
		var f := FileAccess.open(HOST, FileAccess.WRITE)
		f.store_buffer(FileAccess.get_file_as_bytes(MAP))
		f.close()
	var phase: Array = {"SealedShelter": ["fase_3", 0], "TriageGate": ["fase_4", 0], "SewerDucts": ["fase_5", 4],
		"FloodedDepot": ["fase_5", 0], "RiverDock": ["fase_2", 0]}.get(ref if ref != "" else "SealedShelter", ["fase_3", 0])
	var c: Dictionary = campaign.create_initial(7)
	c.completed_phases = ["fase_1", "fase_2", "fase_3", "fase_4"]
	# A equipe da abertura, o Bento e o Nick (#144): direto na expedição, sem o limite de equipe da fase do mapa anfitrião.
	c.preferred_formation = ["hero_cao_bento", "hero_gato_nick"]
	load("res://scripts/flow/journey_rules.gd").start_expedition(c, phase[0], 20261026)
	var route: Dictionary = c.session.expedition.corridor
	for i in int(phase[1]):
		route.steps[i].resolved = true
	route.index = int(phase[1])
	campaign.state = c
	campaign.save()
	flow.change_to("street", {}, false)
	await _settle()
	var street = current_scene
	var tag := ref if ref != "" else "TU"
	street.corridor.busy = true
	for zone_index in (street.scenario.zones.size() if zones else 0):
		street.set_scenario_zone(zone_index)
		var zone: Dictionary = street.scenario.zones[zone_index]
		street._place_leader(Vector3(zone.x0 + 5.6, street.floor_y, street.lane_z))
		street._mood = "night" if ref == "" else "golden"
		street._raining = false
		street._wet = 0.0
		street._apply_weather()
		if ref == "":
			_proto(street)
		await _frames(20)
		_hide_ui()
		await _frames(3)
		await _shot("%s-%d" % [tag, zone_index])
		_show_ui()
		await _frames(3)
		await _shot("%s-%d-hud" % [tag, zone_index])
		if ref == "" and zone_index == street.scenario.zones.size() - 1:
			# O fim do mapa: a equipe na porta aberta do vagão, o embarque (sem as patrulhas, que já ficaram para trás).
			for index in street.corridor.guards:
				for card in street.corridor.guards[index].cards:
					card.visible = false
			street._place_leader(Vector3(zone.x1 - 0.9, street.floor_y, street.lane_z))
			await _frames(20)
			_hide_ui()
			await _frames(3)
			await _shot("%s-exit" % tag)
			_show_ui()
	street.corridor.busy = false
	if fight:
		await _fight(street)
	_restore()
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	quit(0)


## O protótipo do que só o código faz no Corredor de Contenção (para a integração, #147):
## - o ambiente baixo e neutro (uma cor, não o céu da noite, que puxava a névoa para o roxo) e a exposição um pouco
##   abaixo, para as poças das lâmpadas contarem;
## - a névoa baixa: dois véus de névoa rente ao chão em cada zona (MIST_SHADER, transparentes e iluminados: ficam
##   vermelhos perto das lâmpadas e somem no escuro; somem no alto e na base, sem marcar linha no chão), mais a neblina
##   da Environment, rala;
## - o primeiro plano (as peças a FRONT_Z do build_map.py) em alpha blend, para o desfoque pintado aparecer;
## - o pisca das lâmpadas fica parado aceso na foto (o ritmo está na página).
const MIST_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float strength = 0.5;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = vec2(world.x * 0.55 + TIME * 0.05, world.y * 1.6);
	float n = noise(p) * 0.6 + noise(p * 2.3 + 7.0) * 0.4;
	// Some no alto e também rente ao piso: a base do véu não marca uma linha no chão.
	float height = smoothstep(0.0, 0.85, 1.0 - UV.y);
	float base = smoothstep(1.0, 0.55, UV.y);
	float edge = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x);
	ALBEDO = vec3(0.8, 0.72, 0.66);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	ALPHA = clamp(strength * (0.35 + n) * (1.0 - height) * base * edge, 0.0, 1.0);
}
"""

var _mist_done := false


func _mist(street) -> void:
	if _mist_done:
		return
	_mist_done = true
	var shader := Shader.new()
	shader.code = MIST_SHADER
	for zone in street.scenario.zones:
		var lane: float = (zone.z0 + zone.z1) * 0.5
		for layer in [[-1.6, 1.1, 0.5], [1.2, 0.9, 0.36]]:
			var quad := MeshInstance3D.new()
			var mesh := QuadMesh.new()
			mesh.size = Vector2(zone.x1 - zone.x0 + 3.0, layer[1])
			quad.mesh = mesh
			var material := ShaderMaterial.new()
			material.shader = shader
			material.set_shader_parameter("strength", layer[2])
			quad.material_override = material
			quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			quad.position = Vector3((zone.x0 + zone.x1) * 0.5, zone.y + layer[1] * 0.5 - 0.02, lane + layer[0])
			street.scenario.add_child(quad)


func _proto(street) -> void:
	_mist(street)
	for node in street.scenario.find_children("*", "MeshInstance3D", true, false):
		var material = node.get_surface_override_material(0)
		if node.global_position.z > -0.5 and material is StandardMaterial3D and material.albedo_texture != null \
				and ["T_TU20", "T_TU21", "T_TU22"].has(material.albedo_texture.resource_path.get_file().get_basename()):
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var env: Environment = street._env
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.34, 0.33)
	env.ambient_light_energy = 0.3
	env.tonemap_exposure *= 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.08, 0.07)
	env.fog_light_energy = 1.0
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0


## A primeira luta do mapa, na zona do corredor (FIGHT_ZONE): a patrulha que está nela, com a equipe chegando por trás,
## como o K de teste faz (debug_next_fight), mas escolhendo a zona, e não a próxima patrulha da rota.
const FIGHT_ZONE := 0


func _fight(street) -> void:
	street._mood = "night" if ref == "" else "golden"
	street._raining = false
	street._wet = 0.0
	street._apply_weather()
	var c: Dictionary = campaign.state
	var corridor = street.corridor
	var picked := -1
	var keys: Array = corridor.guards.keys()
	keys.sort()
	for index in keys:
		if street.scenario.zone_at(corridor.guards[index].cards[0].position.x) == FIGHT_ZONE:
			picked = index
			break
	if picked < 0:
		push_error("Sem patrulha na zona %d." % FIGHT_ZONE)
		return
	# Os trechos antes dela vencidos, e a equipe no trecho dela, chegando por trás (como o K de teste a deixa).
	var route: Dictionary = c.session.expedition.corridor
	for i in picked:
		route.steps[i].resolved = true
	route.index = picked
	route.current_house = -1
	var front = corridor.guards[picked].cards[0]
	corridor._enter_segment(corridor._segment_of(picked), front.position.x - 2.6)
	await _frames(10)
	# O corredor acompanha o trecho pela posição do líder: o da patrulha de novo, na hora de começar.
	route.index = picked
	var step: Dictionary = c.session.expedition.corridor.steps[picked]
	print("luta: trecho %d de %d (%s, resolvido %s), tela %s, evento %s, casa %s, resultado '%s', arena %s" % [picked, route.index,
		step.type, step.resolved, c.session.get("screen"), c.session.get("event"), route.get("current_house"),
		c.session.get("result", ""), street._arena.active])
	corridor._start_fight(picked, true)
	var arena = street._arena
	for i in 400:
		if arena.hud != null and arena.hud.waiting:
			break
		if i == 30 and not arena.active:
			push_error("A luta não começou.")
			return
		await process_frame
	if ref == "":
		_proto(street)
	await _frames(30)
	_hide_ui()
	await _frames(3)
	await _shot("fight_two")
	var session = arena.session
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var units := []
	for unit in session.state.player_team + session.state.enemy_team:
		var card = arena.cards.get(unit.id)
		var feet := Vector2(-1, -1)
		var body := []
		if card != null:
			feet = cam.unproject_position(card.global_position)
			var r: Rect2 = load("res://scripts/ui/camp_hud.gd").body_rect(cam, card)
			body = [r.position.x, r.position.y, r.size.x, r.size.y]
		units.append({"id": unit.id, "name": unit.display_name, "hp": unit.hp, "max_hp": unit.max_hp, "player": unit.is_player,
			"class_id": unit.class_id, "enemy_id": unit.enemy_id, "rank": unit.rank, "speed": unit.speed, "instinct": unit.instinct,
			"feet": [feet.x, feet.y], "body": body})
	var current: String = session.state.current_turn_unit_id
	var order := []
	for item in session.state.initiative_queue:
		var unit = session.state.find_unit(item.unit_id)
		if unit != null and unit.hp > 0 and (not item.acted or item.unit_id == current):
			order.append(item.unit_id)
	var options := []
	for option in session.ability_options(current):
		options.append({"id": option.id, "name": option.name, "usable": option.usable})
	var f := FileAccess.open(out.path_join("fight_two.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"actor": current, "round": session.state.round, "order": order, "units": units, "options": options,
		"zone": street.scenario.zone_at(street._leader.position.x)}, "  "))
	f.close()


func _restore() -> void:
	if _host_bytes.is_empty():
		return
	var f := FileAccess.open(HOST, FileAccess.WRITE)
	f.store_buffer(_host_bytes)
	f.close()
	_host_bytes = PackedByteArray()


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
