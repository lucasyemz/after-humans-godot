## Fundos limpos do tutorial (#146): a abertura joga só com o Bento e o Nick (#144). Até o mapa do tutorial (#147) ficar
## pronto, a abertura usa um trecho da Rua das Vitrines, no mesmo contrato; a captura é essa rua, com a equipe de dois:
## - explore_two: a rua no começo do trecho, a interface escondida;
## - fight_two: a primeira luta da rua, na vez de um dos dois, a interface escondida, com o que a maquete precisa em
##   fight_two.json (as unidades com o lugar dos pés e do corpo na tela, a vida, quem age e a ordem da rodada).
##   xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     -s res://docs/design/tutorial/capture.gd -- --out=<pasta>
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto. Nada de scripts/, data/ ou tests/ muda.
extends SceneTree

var out := ""
var campaign
var flow
var J


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	campaign = root.get_node("Campaign")
	flow = root.get_node("GameFlow")
	J = load("res://scripts/flow/journey_rules.gd")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	var c: Dictionary = campaign.create_initial(7)
	# A formação da abertura: o Bento na frente e o Nick atrás (os dois primeiros, #144).
	c.preferred_formation = ["hero_cao_bento", "hero_gato_nick"]
	J.start_expedition(c, "fase_1", 4242)
	campaign.state = c
	campaign.save()
	flow.change_to("street", {}, false)
	await _settle()
	_hide_ui()
	await _frames(5)
	await _shot("explore_two")
	_show_ui()
	var street = current_scene
	street.corridor.debug_next_fight()
	await _frames(10)
	street.corridor._start_fight(c.session.expedition.corridor.index, true)
	var arena = street._arena
	for i in 1200:
		if arena.hud != null and arena.hud.waiting:
			break
		await process_frame
	await _frames(20)
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
			body = _body(cam, card)
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
	_write("fight_two", {"actor": current, "round": session.state.round, "order": order, "units": units, "options": options})
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	quit(0)


## O corpo visível na tela ([x, y, largura, altura]), pela mesma conta do clique do acampamento (AHCampHud.body_rect).
func _body(cam: Camera3D, card) -> Array:
	var r: Rect2 = load("res://scripts/ui/camp_hud.gd").body_rect(cam, card)
	return [r.position.x, r.position.y, r.size.x, r.size.y]


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


func _write(name: String, data: Dictionary) -> void:
	var f := FileAccess.open(out.path_join(name + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
