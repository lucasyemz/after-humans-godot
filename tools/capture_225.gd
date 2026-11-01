## Fotos do Guaxinim e do Tatu redesenhados (#225) e das duas poses paradas (#221), pela rua e pela luta de verdade:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_225.gd -- --out=<pasta>
## lineup (os seis lado a lado na rua, na pose de exploração, com os pés na mesma linha e as alturas do jogo),
## lineup_combat (os mesmos na pose de luta: a guarda de quem tem uma), street (a fila com o Bento, a Íris, o Guaxinim e o
## Tatu) e fight (a vez do jogador na primeira luta da fase 1, com a mesma fila). Roda também na main de antes.
extends SceneTree

const ORDER := ["hero_cao_bento", "hero_gato_nick", "hero_sapo_iris", "hero_coruja_vespera", "hero_rato_4", "hero_tatu_5"]

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
	var flow = root.get_node("GameFlow")
	var S = load("res://scripts/flow/station_rules.gd")
	# Pelo load: o script de captura compila antes dos autoloads, e as classes do jogo dependem deles.
	var Arena = load("res://scripts/combat/combat_arena.gd")
	var Card = load("res://scripts/world/sprite_card.gd")
	var Heights = load("res://scripts/world/character_heights.gd")
	root.get_node("Settings")._persist = false
	root.get_node("Tips").set("enabled", false)
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	var c: Dictionary = campaign.create_initial(6)
	# O Guaxinim e o Tatu no elenco, como recrutas (a arte é a do recruta da classe).
	S._add_hero(c, "hero_rato_4", "rato", "Risco", [], "raccoon_recruit_01")
	S._add_hero(c, "hero_tatu_5", "tatu", "Casco", [], "armadillo_recruit_01")
	c.unlocked_classes.append_array(["rato", "tatu"])
	c.preferred_formation = ["hero_cao_bento", "hero_sapo_iris", "hero_rato_4", "hero_tatu_5"]
	load("res://scripts/flow/journey_rules.gd").start_expedition(c, "fase_1", 4242)
	campaign.state = c
	flow.change_to("street", {}, false)
	for frame in 900:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.name == "Street" and frame > 3:
			break
	var street = current_scene
	await _frames(60)
	await _shot("street")
	# Os seis lado a lado, na frente da fila (que fica escondida), com os pés na mesma linha.
	for card in street._heroes:
		card.visible = false
	var leader: Vector3 = street._leader.position
	var cards: Array = []
	for index in ORDER.size():
		var hero_id: String = ORDER[index]
		var hero = campaign.hero(hero_id)
		var art: Dictionary = Arena.art_entry(street._combat_art.heroes, hero_id, String(hero.get("art_variant", "")))
		var card = Card.new()
		card.body_height = Heights.find(hero_id)
		card.show_art(art.idle)
		street.add_child(card)
		card.position = Vector3(leader.x - 2.4 + index * 1.3, leader.y, leader.z)
		card.set_facing(1.0)
		cards.append([card, art])
	await _frames(20)
	await _shot("lineup")
	for pair in cards:
		pair[0].show_art(pair[1].get("combat_idle", pair[1].idle))
	await _frames(20)
	await _shot("lineup_combat")
	for pair in cards:
		pair[0].queue_free()
	for card in street._heroes:
		card.visible = true
	await _frames(10)
	street.corridor.debug_next_fight()
	await _frames(10)
	street.corridor._start_fight(c.session.expedition.corridor.index, true)
	var arena = street._arena
	for i in 1500:
		if arena.hud != null and arena.hud.waiting:
			break
		await process_frame
	await _frames(30)
	await _shot("fight")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	print("capturas da #225 em %s" % out)
	quit(0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
