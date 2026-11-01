## QA por captura da vantagem de tipo (#227), pela cena de verdade:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_227.gd -- --out=<pasta>
## Campanha própria na pasta da saída. Roda também na main de antes. A luta cheia do passo 7 da Rua das Vitrines na
## semente 1 (dois Rastreadores, da Família Perseguidora; o Relé; o Pipoco, da Emissora), nos textos Normal e Maior:
## inspect-hero e inspect-enemy (a inspeção do herói da vez e de um Rastreador), target (a mira do Bento num Rastreador:
## a vantagem na plaqueta e na dica).
extends SceneTree

var out := ""


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
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	var settings = root.get_node("Settings")
	root.get_node("Tips").enabled = false
	settings._persist = false
	campaign.save_dir = out.path_join("save")
	var c: Dictionary = campaign.create_initial(6)
	load("res://scripts/flow/journey_rules.gd").start_expedition(c, "fase_1", 1)
	var route: Dictionary = c.session.expedition.corridor
	for i in 7:
		route.steps[i].resolved = true
	route.index = 6
	campaign.state = c
	flow.change_to("street", {}, false)
	for frame in 900:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.name == "Street" and frame > 3:
			break
	var street = current_scene
	for k in 4:
		street.corridor.debug_next_fight()
		for i in 20:
			await process_frame
		if street.corridor.guards.has(route.index) and route.index == 7:
			break
	street.corridor._start_fight(route.index, true)
	var hud = street._arena.hud
	# A vez do Bento (Linhagem dos Cães, vence a Perseguidora): os outros se defendem até ela chegar.
	var options: Array = []
	# Só o Bento no Rastreador: a mesma vez na main de antes e na branch (com a Véspera, a ordem mudava entre as duas).
	var wanted := {"cao": "cao_eco"}
	for turn in 12:
		for i in 1500:
			if hud.waiting:
				break
			await process_frame
		var actor = hud.session.state.find_unit(hud._actor_id)
		if wanted.has(actor.class_id):
			options = hud._options.filter(func(o): return o.enemy_side and o.get("usable", true) and not _ranks_of(hud, o, wanted[actor.class_id]).is_empty())
			if not options.is_empty():
				break
		hud.command_chosen.emit({"kind": "defend"})
		await create_timer(0.5).timeout
	for size in [0, 2]:
		settings.set_text_size(size)
		await create_timer(0.6).timeout
		var tag := "maior" if size == 2 else "normal"
		# A inspeção: o herói da vez e o primeiro Rastreador.
		hud.toggle_inspect()
		await create_timer(0.4).timeout
		await _shot("inspect-hero-" + tag)
		var tracker: String = hud._examine.filter(func(id): return id.ends_with("cao_eco"))[0]
		hud._examine_index = hud._examine.find(tracker)
		hud._paint_examine()
		await create_timer(0.4).timeout
		await _shot("inspect-enemy-" + tag)
		hud.stop_examine()
		await create_timer(0.3).timeout
		# A mira no alvo com a vantagem.
		if not options.is_empty():
			var option: Dictionary = options[0]
			hud._on_ability(option)
			await create_timer(0.4).timeout
			var rank: int = _ranks_of(hud, option, wanted[hud.session.state.find_unit(hud._actor_id).class_id])[0]
			hud._select_target(rank)
			await create_timer(0.4).timeout
			await _shot("target-" + tag)
			hud._clear_markers()
			hud._set_enabled(true)
			hud._hide_tip()
			hud._choosing = ""
			await create_timer(0.3).timeout
	print("capturas da #227 em %s" % out)
	quit(0)


## As posições dos alvos da habilidade onde está o inimigo enemy_id.
func _ranks_of(hud, option: Dictionary, enemy_id: String) -> Array:
	return option.targets.filter(func(r): return hud.session.state.enemy_team.any(func(u): return u.rank == r and u.enemy_id == enemy_id))


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
