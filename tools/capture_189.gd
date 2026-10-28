## Fotos dos recrutas flexíveis (#189): na Sala dos Personagens, um recruta cão que aprendeu a Ampola com a Íris (a
## habilidade escolhida, com Trocar por; e depois da troca), um recém-chegado de nível 1 (a nota de quando a escolha
## abre e o que ele já sabe) e o ramo Ensinar a comunidade na Pesquisa.
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
	c.station.rooms[S.RESEARCH] = 1
	c.inventory.seeds = 500
	c.inventory.fragments = 12
	var made: Dictionary = S.recruit(c, "cao", RandomNumberGenerator.new(), "Faísca")
	var recruit = S.hero(c, String(made.hero_id))
	# Já no nível 2: a escolha abre depois de subir um nível (decisão do Lucas, 28/10).
	recruit.level = 2
	recruit.learned = ["sapo_ampola_reparo_vivo"]
	recruit.mentor = {"hero_coruja_vespera": 1}
	# Um recém-chegado (nível 1) que já aprendeu a Ampola: a nota de quando a escolha abre e o que ele já sabe.
	var fresh_made: Dictionary = S.recruit(c, "gato", RandomNumberGenerator.new(), "Brasa")
	var fresh = S.hero(c, String(fresh_made.hero_id))
	fresh.learned = ["sapo_ampola_reparo_vivo"]
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
	screen.selected = recruit.id
	screen.ability = "cao_impacto_hidraulico"
	screen.rebuild()
	await _frames(10)
	# A coluna da esquerda rola até as escolhas (o detalhe e o Trocar por ficam abaixo das quatro habilidades).
	var scroll: ScrollContainer = screen.get_node("Left").get_child(0)
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _frames(20)
	await _shot("01-sala-escolha")
	var swap = screen.find_child("Swap_sapo_ampola_reparo_vivo", true, false)
	if swap:
		swap.pressed.emit()
	await _frames(30)
	await _shot("02-sala-trocada")
	screen = hud._room_screen
	screen.selected = fresh.id
	screen.ability = "gato_salto_entre_ruinas"
	screen.rebuild()
	await _frames(10)
	scroll = screen.get_node("Left").get_child(0)
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _frames(20)
	await _shot("04-sala-nivel-1")
	hud.close_panel()
	await _frames(10)
	hud.open_room(S.RESEARCH)
	await _frames(40)
	await _shot("03-pesquisa")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
