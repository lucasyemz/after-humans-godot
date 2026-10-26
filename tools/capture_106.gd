## Fotos da #106 (docs/design/hud-exploracao.md), para comparar com as maquetes nos quatro perfis: a rua, a patrulha à
## frente, a interação no interior, a busca, o achado, o evento e o resultado dele, o evento de cenário, a Mochila,
## abandonar a expedição, diante do guardião, o guardião vencido e o toque (nada por perto e perto do caixa).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_106.gd -- --out=<pasta> [--text-size=2] [--colorblind]
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
	var J = load("res://scripts/flow/journey_rules.gd")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	settings.set_colorblind(colorblind)
	settings.set_text_size(text_size)
	var c: Dictionary = campaign.create_initial(6)
	J.start_expedition(c, "fase_1", 4242)
	campaign.state = c
	campaign.save()
	var street = await _street(flow)
	var hud = street.exploration_hud
	var corridor = street.corridor
	street.apply_corridor_weather("sunset")
	await _frames(30)
	await _shot("explore")
	# A patrulha à frente: desconfiada, fora da tela à direita.
	hud.set_patrol(street._leader.global_position + Vector3(40, 0, 0), 0.55, false)
	corridor.set_process(false)
	await _frames(6)
	await _shot("patrol")
	hud.set_patrol(null, 0.0, false)
	corridor.set_process(true)
	# A busca e o achado.
	hud.toast(tr("Na mochila esquecida: 2 sementes e 1 sucata."))
	await _frames(6)
	await _shot("search")
	hud.loot_burst([["lobby-seed", "+2 sementes"], ["lobby-scrap", "+1 sucata"]], street._leader.global_position + Vector3(0, 1.9, 0))
	# Na captura cada quadro é lento: poucos quadros, com o achado ainda subindo.
	await _frames(3)
	await _shot("loot")
	# O evento e o resultado dele.
	c.session.event = {"event_id": "busca_choro_porta", "from_search": true, "resolution": "", "pending_hard_combat": false, "object": "Armário de vestiário"}
	hud.show_event(c)
	await _frames(8)
	await _shot("event")
	var row = root.get_node("GameData").row("events", "busca_choro_porta")
	var choice: Dictionary = row.Choices.filter(func(o): return J.can_choose(c, o))[0]
	J.choose_event_option(c, choice.Id, 3)
	hud.show_event(c)
	await _frames(8)
	await _shot("event_result")
	hud.close_modal()
	c.session.event = null
	# A Mochila, abandonar a expedição e diante do guardião.
	hud.show_inventory()
	await _frames(8)
	await _shot("inventory")
	hud._confirm_return(false)
	await _frames(8)
	await _shot("risk")
	hud.close_modal()
	hud.show_choice(tr("O guardião está à frente"), tr("Vencer o guardião conclui a fase e leva todo o achado. Se a equipe cair, o achado fica para trás; voltar agora leva metade."),
		[[tr("Seguir em frente"), func(): pass], [tr("Voltar à Estação (metade do achado)"), func(): pass]])
	await _frames(8)
	await _shot("boss_choice")
	hud.close_modal()
	# O toque, nada por perto.
	settings.touch_controls = 1
	await _frames(10)
	await _shot("touch")
	settings.touch_controls = 0
	# A interação no interior, perto do caixa (e o toque com o Usar aceso).
	var route: Dictionary = c.session.expedition.corridor
	var site: int = route.sites.map(func(s): return s.shop).find(0)
	route.index = route.sites[site].step
	for i in route.index:
		route.steps[i].resolved = true
	route.sites[site].has_enemy = false
	await corridor._enter_house(site)
	await _frames(20)
	street._leader.position.x = corridor.room.spot_xs[0]
	await _frames(20)
	await _shot("interior")
	settings.touch_controls = 1
	await _frames(10)
	await _shot("touch_active")
	settings.touch_controls = 0
	await corridor._leave_house()
	await _frames(20)
	# O guardião vencido: os trechos resolvidos, o objetivo cumprido e o Concluir jornada.
	for step in route.steps:
		step.resolved = true
	route.index = route.steps.size() - 1
	c.session.expedition.objective_completed = true
	# A carga já escolhida (sem caixas pendentes); a rua parada para o trecho não voltar ao do líder.
	c.session.expedition.cargo = {"boxes": [], "chosen": -1}
	corridor.set_process(false)
	hud.set_patrol(null, 0.0, false)
	hud.show_prompt("")
	hud.set_markers([])
	hud.refresh(c)
	await _frames(10)
	await _shot("boss_done")
	# O evento de cenário (Abrigo Lacrado, fase 3).
	var s: Dictionary = campaign.create_initial(8)
	s.completed_phases = ["fase_1", "fase_2"]
	J.start_expedition(s, "fase_3", 4242)
	campaign.state = s
	street = await _street(flow)
	street.apply_corridor_weather("sunset")
	s.session.event = {"event_id": "busca_sala_esporos", "from_search": true, "resolution": "", "pending_hard_combat": false, "object": "Maca"}
	street.exploration_hud.show_event(s)
	await _frames(10)
	await _shot("scenario_event")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _street(flow) -> Node:
	flow.change_to("street", {}, false)
	await _frames(10)
	while flow.busy:
		await process_frame
	await _frames(30)
	return current_scene


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
