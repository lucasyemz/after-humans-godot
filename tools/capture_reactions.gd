## Prova das reações dos heróis na luta (#13): os quatro fundadores parados, com a pose de dano e caídos (a Íris e a
## Véspera ajoelhadas), numa luta de verdade da Rua das Vitrines, na vez do jogador.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_reactions.gd -- --out=<pasta>
## Grava idle.png, hurt.png e death.png. A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
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
	campaign.save_dir = out.path_join("save")
	root.get_node("Tips").set("enabled", false)
	campaign.state = campaign.create_initial(6)
	load("res://scripts/flow/journey_rules.gd").start_expedition(campaign.state, "fase_1", 4242)
	campaign.save()
	root.get_node("GameFlow").change_to("street", {}, false)
	await create_timer(2.5).timeout
	var street = current_scene
	street.corridor.debug_next_fight()
	await create_timer(0.5).timeout
	street.corridor._start_fight(campaign.state.session.expedition.corridor.index, true)
	var arena = street._arena
	for i in 900:
		if arena.hud != null and arena.hud.waiting:
			break
		await process_frame
	arena.hud._hide_tip()
	for pose in ["idle", "hurt", "death"]:
		for unit in arena.session.state.player_team:
			arena.show_pose(unit, pose)
			arena.cards[unit.id].set_tint(Color.WHITE)
		await create_timer(0.8).timeout
		root.get_viewport().get_texture().get_image().save_png(out.path_join(pose + ".png"))
		print(pose)
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)
