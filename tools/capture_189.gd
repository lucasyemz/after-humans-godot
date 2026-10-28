## Fotos dos recrutas (#189 e #215): na Sala dos Personagens, um recruta cão recém-chegado (as 3 da raça e o que vem pela
## frente), um veterano com a do Bento aprendida (5: a que fica na Estação e o Trocar por) e o Treino para o nível 4 (a
## opção de aprender com o Bento, que custa fragmentos).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_189.gd -- --out=<pasta> [--text-size=2]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--text-size="):
			root.get_node("Settings").set_text_size(int(arg.trim_prefix("--text-size=")))
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	var S = load("res://scripts/flow/station_rules.gd")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	var c: Dictionary = campaign.create_initial(189)
	c.station.rooms[S.CHARACTERS] = 4
	c.inventory.seeds = 500
	c.inventory.fragments = 12
	var fresh = S.hero(c, String(S.recruit(c, "cao", RandomNumberGenerator.new(), "Faísca").hero_id))
	var vet = S.hero(c, String(S.recruit(c, "cao", RandomNumberGenerator.new(), "Ronco").hero_id))
	vet.level = 4
	vet.learned = ["cao_fique_atras_de_mim"]
	var pupil = S.hero(c, String(S.recruit(c, "cao", RandomNumberGenerator.new(), "Brasa").hero_id))
	pupil.level = 3
	pupil.xp = 500
	c.station.last_return = {}
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	for i in 600:
		await process_frame
		if not flow.busy and current_scene != null and i > 10:
			break
	await _frames(30)
	var hud = current_scene.hud
	hud.open_room(S.CHARACTERS)
	await _frames(10)
	var screen = hud._room_screen
	screen.selected = fresh.id
	screen.rebuild()
	await _frames(10)
	_scroll_down(screen)
	await _frames(30)
	await _shot("01-recem-chegado")
	screen.selected = vet.id
	screen.ability = "rec_cao_patada"
	screen.rebuild()
	await _frames(10)
	_scroll_down(screen)
	await _frames(30)
	await _shot("02-veterano")
	screen.selected = pupil.id
	screen.training = true
	screen._upgrade = "learn_founder"
	screen.rebuild()
	await _frames(40)
	await _shot("03-treino")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


## A coluna da esquerda rola até o fim (as habilidades e as notas ficam abaixo dos heróis).
func _scroll_down(screen) -> void:
	var scroll: ScrollContainer = screen.get_node("Left").get_child(0)
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
