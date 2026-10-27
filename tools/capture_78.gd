## Fotos da #78: um evento de busca novo em cada fase (o cartão e o resultado com os chips) e os efeitos de fase dos
## eventos, no chip do resultado e no começo da luta (os heróis Vulneráveis e com Bloqueio).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_78.gd -- --out=<pasta> [--text-size=2] [--colorblind]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto. Evento que não existe (num branch de
## antes) fica sem foto.
extends SceneTree

## [fase, evento, escolha do resultado (índice entre as que dá para escolher), semente]
const SHOTS := [
	["fase_1", "busca_latas_estufadas", 2, 3],
	["fase_1", "busca_caixa_sanitaria", 0, 3],
	["fase_1", "busca_cano_rompido", 0, 3],
	["fase_2", "busca_bolsa_mapa", 1, 3],
	["fase_3", "busca_baterias_camaras", 0, 3],
	["fase_4", "busca_cesto_confiscados", 0, 3],
	["fase_5", "busca_kit_lacre_novo", 0, 3],
]

var out := ""
var J


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
	J = load("res://scripts/flow/journey_rules.gd")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	settings.set_colorblind(colorblind)
	settings.set_text_size(text_size)
	var street: Node = null
	var phase := ""
	for spec in SHOTS:
		if root.get_node("GameData").row("events", spec[1]) == null:
			continue
		if spec[0] != phase:
			phase = spec[0]
			var c: Dictionary = campaign.create_initial(6)
			c.completed_phases = J.PHASES.map(func(p): return p.id).slice(0, J.PHASES.map(func(p): return p.id).find(phase))
			J.start_expedition(c, phase, 4242)
			campaign.state = c
			campaign.save()
			street = await _street(flow)
			street.apply_corridor_weather("sunset")
		var state: Dictionary = campaign.state
		var hud = street.exploration_hud
		state.session.event = {"event_id": spec[1], "from_search": true, "resolution": "", "pending_hard_combat": false, "object": ""}
		hud.show_event(state)
		await _frames(8)
		await _shot("%s_%s" % [spec[0], spec[1]])
		var row = root.get_node("GameData").row("events", spec[1])
		var open: Array = row.Choices.filter(func(o): return J.can_choose(state, o))
		J.choose_event_option(state, open[mini(spec[2], open.size() - 1)].Id, spec[3])
		hud.show_event(state)
		await _frames(8)
		await _shot("%s_%s_result" % [spec[0], spec[1]])
		hud.close_modal()
		state.session.event = null
	# A luta com os efeitos de fase: Exposto, Preparado e Cansado.
	var f: Dictionary = campaign.create_initial(6)
	J.start_expedition(f, "fase_1", 4242)
	f.session.expedition.corridor.effects = ["exposto", "preparado", "cansado"]
	campaign.state = f
	street = await _street(flow)
	street.apply_corridor_weather("sunset")
	street.corridor.debug_next_fight()
	await _frames(10)
	street.corridor._start_fight(f.session.expedition.corridor.index, true)
	var combat = street._arena.hud
	for i in 900:
		if combat != null and combat.waiting:
			break
		await process_frame
	await _frames(30)
	await _shot("fight_effects")
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
