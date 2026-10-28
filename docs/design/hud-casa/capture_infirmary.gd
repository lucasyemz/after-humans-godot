## A Enfermaria nova na Estação de verdade (os ajustes do Lucas de 26/10, PR #139): carrega por cima do projeto o pacote
## de infirmary_proto.py (os scripts da Estação com a Enfermaria de 12 m, nos planos do Dormitório) e fotografa, sem a
## interface, a câmera do cômodo e a Visão geral, nos níveis 1 e 2. Na Enfermaria: a Íris caída num leito (no nível 2,
## a Véspera também, para mostrar mais leitos em uso),
## a Lupa (a recruta sapo das telas, com a arte frog_recruit_01) no posto de quem cuida, entre os leitos (#119), e o Bento
## de pé ao lado de um leito.
##   python3 -B docs/design/hud-casa/infirmary_proto.py <pasta>/proto.zip
##   xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     -s res://docs/design/hud-casa/capture_infirmary.gd -- --out=<pasta> --pack=<pasta>/proto.zip [--levels=1,2] \
##     [--views=room,clean,hud,forge,ui]
## Sem --pack, fotografa a Estação como ela está hoje no jogo (a Enfermaria de 6 m, com os beliches), com as mesmas
## pessoas e as mesmas câmeras: é o "antes" dos antes e depois do PR. Com ui (só no antes), também as telas de verdade
## do jogo de hoje, com a interface e no estado das telas da proposta (o Dia 5: a Lupa no posto da Enfermaria, o Brasa
## na Forja, as sucatas, os fragmentos e a água das telas): a Visão geral com a Enfermaria escolhida
## (infirmary_ui_overview.png), o cômodo aberto (infirmary_ui_room.png), a Sala com a Íris e com a Lupa
## (infirmary_ui_characters_fallen.png e infirmary_ui_characters_post.png) e a Forja aberta (infirmary_ui_forge.png).
## Grava infirmary_room_<nível>.png (a câmera do cômodo) e, no primeiro nível, infirmary_overview_<nível>.png (a Visão
## geral sem a HUD, a Estação inteira) e infirmary_hud_<nível>.png (a Visão geral na câmera de quando a HUD está aberta, com a faixa do
## menu à esquerda: o fundo da tela da Visão geral). Com forge, também forge_workers.png: a câmera da Forja de nível 1,
## com o Brasa (o recruta cão das telas) junto da bancada e o Otto no posto dele (o fundo de "Quem trabalha aqui"). A campanha fica numa pasta dentro de <pasta>; o
## save do jogador fica intacto e nada em scripts/ muda (o pacote vale só enquanto a captura roda).
## Sem placa de vídeo (Compatibility por software), cada quadro da Estação leva mais de um minuto: a captura usa o
## mínimo de quadros e a câmera vai direto (instant).
extends SceneTree

var out := ""
var pack := ""
var levels := [1, 2]
var views := ["room", "clean"]
var S


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--pack="):
			pack = arg.trim_prefix("--pack=")
		elif arg.begins_with("--levels="):
			levels = Array(arg.trim_prefix("--levels=").split(",")).map(func(v): return int(v))
		elif arg.begins_with("--views="):
			views = Array(arg.trim_prefix("--views=").split(","))
	DirAccess.make_dir_recursive_absolute(out)
	if pack != "":
		if not ProjectSettings.load_resource_pack(pack, true):
			push_error("O pacote da Enfermaria não carregou: %s" % pack)
			quit(1)
			return
		# Os scripts da Estação podem já estar carregados (as classes globais): recompila cada um com o texto do pacote.
		for path in ["res://scripts/station/station_build.gd", "res://scripts/station/station.gd"]:
			var script: GDScript = load(path)
			script.source_code = FileAccess.get_file_as_string(path)
			script.reload(true)
		if not load("res://scripts/station/station_build.gd").get_script_constant_map().has("INFIRMARY_PIECES"):
			push_error("Os scripts do pacote não entraram.")
			quit(1)
			return
	await process_frame
	S = load("res://scripts/flow/station_rules.gd")
	var J = load("res://scripts/flow/journey_rules.gd")
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	# A volta com a Íris caída (como tools/capture_118.gd, a história das telas), e a noite passada: um dia comum na
	# Estação, ela no leito da Enfermaria.
	var c: Dictionary = campaign.create_initial(17)
	c.station.rooms[S.INFIRMARY] = int(levels[0])
	# A Forja de nível 1, como no Dia 5 das telas (a Visão geral, IR AO MAPA, o Mapa e a plataforma).
	c.station.rooms[S.FORGE] = 1
	var team: Array = c.roster.slice(0, 4).map(func(h): return h.id)
	J.start_expedition(c, "fase_1", 17)
	c.session.expedition.team = team
	S.hero(c, "hero_sapo_iris").alive = false
	c.session.result = "victory"
	S.finish_return(c)
	# Os recrutas das telas, que chegaram no trem antes: a Lupa (no posto da Enfermaria) e o Brasa (na Forja); e os
	# civis do Dia 5, a Dora, o Otto e a Cora.
	S._add_hero(c, "hero_sapo_4", "sapo", "Lupa", [], "frog_recruit_01")
	S._add_hero(c, "hero_cao_5", "cao", "Brasa", [], "dog_recruit_01")
	c.station.residents = [S.DORA, S.OTTO, S.CORA]
	c.station.last_return.seen = true
	S.resolve_night(c)
	S.finish_dawn(c)
	c.station.train = S._train_defaults()
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	while flow.busy or current_scene == null:
		await process_frame
	var station = current_scene
	print("estação")
	await _frames(2)
	if views.has("ui") and pack == "":
		# As telas de hoje, com a interface, no estado das telas da proposta: a Lupa no posto da Enfermaria e o Brasa no da
		# Forja (#119, já na main), e as sucatas, os fragmentos e a água do Dia 5.
		c.station.rooms[S.INFIRMARY] = int(levels[0])
		for post in [["hero_sapo_4", S.INFIRMARY], ["hero_cao_5", S.FORGE]]:
			var block: String = S.set_post(c, post[0], post[1])
			if block != "":
				push_error("Posto de %s: %s" % [post[0], block])
		c.inventory.scrap = 9
		c.inventory.fragments = 3
		c.station.water = 6
		station.commit()
		_stage(station, _staff(int(levels[0])))
		var hud = station.hud
		hud.refresh()
		station.focus_overview(true)
		# A Enfermaria escolhida na Visão geral, como pelas setas (o mouse parado não desfaz a escolha).
		hud._key_room = S.INFIRMARY
		hud._last_mouse = root.get_mouse_position()
		await _frames(3)
		await _shot("infirmary_ui_overview")
		hud.open_room(S.INFIRMARY)
		station.focus_room(S.INFIRMARY, true)
		await _frames(3)
		await _shot("infirmary_ui_room")
		hud.close_panel()
		hud.open_room(S.CHARACTERS)
		await _frames(3)
		for pick in [["hero_sapo_iris", "infirmary_ui_characters_fallen"], ["hero_sapo_4", "infirmary_ui_characters_post"]]:
			if is_instance_valid(hud._room_screen):
				hud._room_screen.selected = pick[0]
				hud._room_screen.rebuild()
			await _frames(3)
			await _shot(pick[1])
		hud._close_room_screen()
		hud.close_panel()
		await _frames(1)
		hud.open_room(S.FORGE)
		station.focus_room(S.FORGE, true)
		await _frames(3)
		await _shot("infirmary_ui_forge")
		hud.close_panel()
		await _frames(1)
	_hide_ui()
	for level in levels:
		c.station.rooms[S.INFIRMARY] = level
		if level >= 2:
			# A Véspera vem depois da Íris no elenco: a Íris continua no leito 1, e ela vai para o 2.
			S.admit_fallen(c, ["hero_coruja_vespera"])
		station.commit()
		_stage(station, _staff(level))
		if views.has("room"):
			station.focus_room(S.INFIRMARY, true)
			await _frames(3)
			await _shot("infirmary_room_%d" % level)
		# As vistas da Estação inteira só no primeiro nível (cada quadro custa mais de um minuto sem placa de vídeo).
		if views.has("clean") and level == levels[0]:
			station.focus_clean_overview()
			for i in 6:
				if station.camera_settled():
					break
				await process_frame
			await _frames(2)
			await _shot("infirmary_overview_%d" % level)
		if views.has("hud") and level == levels[0]:
			station.focus_overview(true)
			await _frames(3)
			await _shot("infirmary_hud_%d" % level)
	if views.has("forge"):
		station.focus_room(S.FORGE, true)
		await _frames(3)
		await _shot("forge_workers")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	quit(0)


## Quem cuida e quem visita, parados (fora do passeio): a Lupa no posto, entre o soro e o segundo leito (o soro à vista),
## virada para a Íris (recruta não tem pose de trabalho na Estação: de pé); o Bento de pé junto da cabeceira da Íris,
## virado para ela. Cada um: o ponto (cm, o x, a profundidade e o piso), a pose ("" é o idle) e para onde olha.
## O Brasa fica junto da bancada da Forja em todas as fotos (no Dia 5 ele está no posto dela). No nível 2, com a Véspera
## no segundo leito, a Lupa vai para os pés dele, junto do biombo, para não tapá-la.
const STAFF := {"hero_sapo_4": [Vector3(-1290, -590, -940), "", -1.0],
	"hero_cao_bento": [Vector3(-1660, -580, -940), "", 1.0],
	"hero_cao_5": [Vector3(1560, -600, -1040), "", 1.0]}
const STAFF_LEVEL_2 := {"hero_sapo_4": [Vector3(-1100, -590, -940), "", -1.0]}
## No jogo de hoje (sem o pacote), a Enfermaria vai de −1240 a −640, com os beliches em −1075 e −805: o Bento na
## cabeceira do primeiro beliche, virado para a Íris, e a Lupa entre os dois beliches.
const STAFF_TODAY := {"hero_sapo_4": [Vector3(-930, -590, -940), "", -1.0],
	"hero_cao_bento": [Vector3(-1195, -580, -940), "", 1.0]}


func _staff(level: int) -> Dictionary:
	var staff := STAFF.duplicate()
	if pack == "":
		staff.merge(STAFF_TODAY, true)
	elif level >= 2:
		staff.merge(STAFF_LEVEL_2, true)
	return staff


func _stage(station, spots: Dictionary) -> void:
	var B = load("res://scripts/station/station_builder.gd")
	station._walkers = station._walkers.filter(func(w): return not spots.has(w.get("hero_id", "")))
	# Quem o sorteio pôs para passear no mesmo cômodo (na faixa da frente, tapando quem está parado) vai para a Pesquisa;
	# e quem passeia no Depósito, ao lado da Forja (atrás do balcão dele, as pernas saíam recortadas na foto da Forja).
	var away: Dictionary = station.room_def(S.RESEARCH)
	for walker in station._walkers:
		if walker.has("hero_id") and [S.INFIRMARY, S.FORGE, "depot"].has(walker.get("room", "")) \
				and not S.recovering(S.hero(Campaign_state(), walker.hero_id)):
			walker.room = away.id
			walker.min = away.lane[0]
			walker.max = away.lane[1]
			walker.card.position.x = lerpf(away.lane[0], away.lane[1], 0.3)
			walker.target = walker.card.position.x
	for hero_id in spots:
		var card = station.residents.get(hero_id)
		if card == null:
			push_error("Sem a carta de %s." % hero_id)
			continue
		var spot: Array = spots[hero_id]
		card.position = B.vu(spot[0])
		if spot[1] != "" and station._poses.has(hero_id + spot[1]):
			card.show_art(station._poses[hero_id + spot[1]])
		card.set_facing(spot[2])
		card.visible = true


func Campaign_state() -> Dictionary:
	return root.get_node("Campaign").state


func _hide_ui() -> void:
	for node in root.find_children("*", "CanvasLayer", true, false):
		node.visible = false


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name, " ", Time.get_ticks_msec())
