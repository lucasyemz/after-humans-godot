## Fundo limpo do lote 7 (#120, #118): o fim de uma luta de verdade em que a Íris caiu e a equipe venceu, para o popup
## com "Íris caiu". A Íris começa a luta com 1 de vida (só isso muda); a luta corre no automático, e a semente seguinte é
## tentada até ela cair e a equipe vencer. As recompensas da sessão vão em fight_fallen.json.
##   xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     -s res://docs/design/hud-casa/capture.gd -- --out=<pasta>
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
	for seed in [4242, 5353, 6464, 7575, 8686, 9797]:
		if await _fight("fight_fallen", seed, {"fallen": "hero_sapo_iris"}):
			break
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	quit(0)

func _fight(name: String, seed: int, opts: Dictionary) -> bool:
	var c: Dictionary = campaign.create_initial(seed % 97)
	J.start_expedition(c, "fase_1", seed)
	c.session.expedition.loot.seeds = 4
	c.session.expedition.loot.scrap = 2
	c.session.expedition.loot.fragments = 0
	campaign.state = c
	campaign.save()
	flow.change_to("street", {}, false)
	await _settle()
	var street = current_scene
	var loot_before: Dictionary = c.session.expedition.loot.duplicate()
	street.corridor.debug_next_fight()
	await _frames(10)
	street.corridor._start_fight(c.session.expedition.corridor.index, true)
	var arena = street._arena
	for i in 900:
		if arena.hud != null and arena.hud.waiting:
			break
		await process_frame
	print("luta: ", name, " semente=", seed, " ativa=", arena.active)
	if opts.has("fallen"):
		for unit in arena.session.state.player_team:
			if unit.hero_id == opts.fallen:
				unit.hp = 1
	arena.auto_battle = true
	arena.speed = 8.0
	arena.hud.command_chosen.emit({"kind": "defend"})
	var limit := Time.get_ticks_msec() + 180000
	while arena.active and not arena.hud._result.visible and Time.get_ticks_msec() < limit:
		# Com a luta decidida, sai do automático: a tela do fim espera, e a foto sai com calma.
		if arena.session != null and arena.session.result() != "":
			arena.auto_battle = false
		await process_frame
	await _frames(2)
	# A luta corre no automático e não sai igual a cada vez: a semente que derruba a Íris pode mudar de uma corrida para
	# outra. No Último Fôlego, quem caiu fica na arena (a Íris não tem a pose de caída, então fica de pé).
	var down: Array = arena.session.state.player_team.filter(func(u): return u.hero_id == opts.get("fallen", "") and u.hp <= 0)
	if opts.has("fallen") and (arena.session.result() != "victory" or down.is_empty()):
		print("sem queda nesta semente: ", arena.session.result())
		arena.hud.result_closed.emit()
		await _frames(30)
		return false
	# A foto limpa do fim da luta, com quem ficou de pé no lugar (a HUD escondida).
	_hide_ui()
	await _frames(3)
	await _shot(name)
	var session = arena.session
	var HL = load("res://scripts/flow/hero_levels.gd")
	var FR = load("res://scripts/flow/fight_rewards.gd")
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var units := []
	for unit in session.state.player_team:
		var card = arena.cards.get(unit.id) if arena.get("cards") is Dictionary else null
		var feet := Vector2(-1, -1)
		var body := []
		if card != null:
			feet = cam.unproject_position(card.global_position)
			body = _body(cam, card)
		var hero = campaign.hero(unit.hero_id)
		units.append({"hero_id": unit.hero_id, "name": unit.display_name, "hp": unit.hp, "max_hp": unit.max_hp, "feet": [feet.x, feet.y], "body": body,
			"xp_gained": session.xp_gained.get(unit.hero_id, 0), "level": HL.level(hero) if hero != null else 0,
			"xp": HL.xp(hero) if hero != null else 0, "next_xp": int(HL.next_cost(hero).get("xp", 0)) if hero != null else 0,
			"training_ready": hero != null and not HL.next_cost(hero).is_empty() and HL.xp(hero) >= int(HL.next_cost(hero).xp)})
	var exp = campaign.state.session.get("expedition", {})
	var rewards = FR.criteria(session, false, "fase_1")
	_write(name, {"result": session.result(), "rewards": rewards, "units": units, "loot_before": loot_before,
		"loot_after": exp.get("loot", {}) if exp is Dictionary else {}, "session_result": campaign.state.session.get("result", "")})
	_show_ui()
	arena.hud.result_closed.emit()
	await _frames(30)
	return true


## O corpo visível na tela ([x, y, largura, altura]), pela mesma conta do clique do acampamento (AHCampHud.body_rect):
## as telas conferem que nenhum painel cobre a equipe.
func _body(cam: Camera3D, card) -> Array:
	var r: Rect2 = load("res://scripts/ui/camp_hud.gd").body_rect(cam, card)
	return [r.position.x, r.position.y, r.size.x, r.size.y]


## Esconde a interface: as CanvasLayers e os Controls de cima (os que não estão dentro de outro Control).
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
	await _frames(10)


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
