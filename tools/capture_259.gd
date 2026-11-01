## Fotos da #259 (as sete habilidades): a Sala com as 7 e a troca recusada pelo motivo, a Sala com a bloqueada e o
## requisito, o Treino com as de aprender, a luta com as 4 escolhidas e a ficha na inspeção. Roda também no código de
## antes (sem os campos novos, a Sala e a luta mostram as 4 de sempre).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_259.gd -- --out=<pasta> [--text-size=2] [--colorblind]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
var S


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
	S = load("res://scripts/flow/station_rules.gd")
	var J = load("res://scripts/flow/journey_rules.gd")
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	root.get_node("Settings").set_colorblind(colorblind)
	root.get_node("Settings").set_text_size(text_size)
	var c: Dictionary = campaign.create_initial(259)
	c.station.last_return = {}
	c.inventory.seeds = 40
	c.inventory.fragments = 0
	# O Bento no nível 7, com os 3 aprendidos, leva o Ombro de Carga no lugar do Não Estamos Sós.
	var bento = S.hero(c, "hero_cao_bento")
	bento.level = 7
	bento.unlocked = ["cao_ombro_de_carga", "cao_postura_firme", "cao_alerta_de_perigo"]
	bento.loadout = ["cao_punho_sucata", "cao_impacto_hidraulico", "cao_fique_atras_de_mim", "cao_ombro_de_carga"]
	# O Nick no nível 3, com a Salto da Calha aprendida e levada.
	var nick = S.hero(c, "hero_gato_nick")
	nick.level = 3
	nick.unlocked = ["gato_salto_da_calha"]
	nick.loadout = ["gato_corte_fase", "gato_salto_entre_ruinas", "gato_cacada_precisa", "gato_salto_da_calha"]
	# A Íris pronta para o treino do nível 3 (as de aprender), sem fragmentos.
	var iris = S.hero(c, "hero_sapo_iris")
	iris.level = 2
	iris.xp = 999
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	while flow.busy or current_scene == null or current_scene.name != "Station":
		await process_frame
	var station = current_scene
	var hud = station.hud
	await _frames(20)
	hud.open_room(S.CHARACTERS)
	await _until(func(): return station.camera_settled(), 900)
	await _frames(20)
	var screen = hud._room_screen
	screen.selected = "hero_cao_bento"
	screen.rebuild()
	await _frames(6)
	# O clique na habilidade, como o jogador: a coluna rola até o detalhe e a troca.
	await _press(screen, "Ability_cao_impacto_hidraulico")
	await _shot("01-sala-troca")
	screen.selected = "hero_gato_nick"
	screen.ability = ""
	screen.rebuild()
	await _frames(6)
	await _press(screen, "Ability_gato_rasgo_rapido")
	await _shot("02-sala-bloqueada")
	# A ficha (a da Preparação), com as habilidades: as da luta, as da Estação e as bloqueadas.
	var sheet_script = load("res://scripts/ui/character_sheet.gd")
	var sheet = sheet_script.new()
	hud.add_child(sheet)
	sheet.show_info(sheet_script.from_hero(S.hero(campaign.state, "hero_cao_bento")), Rect2(600, 260, 300, 200))
	await _frames(10)
	await _shot("06-ficha")
	sheet.queue_free()
	screen.selected = "hero_sapo_iris"
	screen.ability = ""
	screen.training = true
	screen.rebuild()
	await _frames(10)
	await _shot("03-treino")
	screen.training = false
	# Na luta, os quatro levam um desbloqueio: quem age primeiro mostra o dele.
	var st: Dictionary = campaign.state
	var iris2 = S.hero(st, "hero_sapo_iris")
	iris2.level = 7
	iris2.xp = 0
	iris2.unlocked = ["sapo_nevoa_calmante", "sapo_frasco_aderente", "sapo_curativo_rapido"]
	iris2.loadout = ["sapo_carga_voltaica", "sapo_coquetel_corrosivo", "sapo_ampola_reparo_vivo", "sapo_curativo_rapido"]
	var vespera = S.hero(st, "hero_coruja_vespera")
	vespera.level = 7
	vespera.unlocked = ["coruja_mira_no_marcado", "coruja_tiro_de_aviso", "coruja_posicao_elevada"]
	vespera.loadout = ["coruja_disparo_perfurante", "coruja_olho_nas_ruinas", "coruja_recurso_emergencia", "coruja_tiro_de_aviso"]
	# A luta: a equipe parte e a primeira luta abre na vez de um herói.
	J.start_expedition(campaign.state, "fase_1", 4242)
	flow.change_to("street", {}, false)
	for frame in 900:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.name == "Street" and frame > 10:
			break
	var street = current_scene
	street.corridor.debug_next_fight()
	await _frames(10)
	street.corridor._start_fight(campaign.state.session.expedition.corridor.index, true)
	var combat = street._arena.hud
	for i in 900:
		if combat != null and combat.waiting:
			break
		await process_frame
	await _frames(30)
	await _shot("04-luta")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _press(screen, name: String) -> void:
	var button = screen.find_child(name, true, false)
	if button != null:
		button.pressed.emit()
	await _frames(12)


func _until(condition: Callable, frames: int = 2400) -> void:
	for i in frames:
		if condition.call():
			return
		await process_frame


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
