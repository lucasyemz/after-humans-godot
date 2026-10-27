## Fotos do Guaxinim e do Tatu na luta (#187): o trem traz um de cada (como o force da barra de Admin), a Estação acolhe
## os dois, e a equipe (Guaxinim, Tatu, Bento e Nick) luta na rua contra um robô e um cão eco. Fotografa a formação
## parada (a escala ao lado dos outros e os pés no chão), cada golpe e cada reação deles, e depois deixa a luta correr
## sozinha até o fim (as ações de verdade, com a queda de quem cair).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_187.gd -- --out=<pasta>
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

const ENEMIES := ["robot", "cao_eco"]

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
	var S = load("res://scripts/flow/station_rules.gd")
	var campaign = root.get_node("Campaign")
	campaign.save_dir = out.path_join("save")
	root.get_node("Tips").set("enabled", false)
	var c: Dictionary = campaign.create_initial(6)
	c.inventory.seeds = 500
	var unlocked: Array = c.unlocked_classes.duplicate()
	var arrived: Array = []
	for class_id in ["rato", "tatu"]:
		# Só a classe dela liberada, para o trem forçado trazer esta.
		c.unlocked_classes = [class_id]
		var came: bool = S.train_on_return(c, "qa187-%s" % class_id, "hero")
		var recruit: Dictionary = c.station.train.get("recruit", {})
		print("trem: %s, %s (%s, arte %s)" % [came, recruit.get("display_name", "?"), recruit.get("class_id", "?"), recruit.get("art_variant", "?")])
		var error: String = S.decide_candidate(c, c.station.train.candidate_id, true)
		S.finish_departure(c)
		var hero = c.roster.back()
		print("acolhido: %s %s %s" % [error, hero.id, hero.get("art_variant", "")])
		arrived.append(hero.id)
	c.unlocked_classes = unlocked + ["rato", "tatu"]
	# O Tatu entre dois vizinhos: o escudo dele não pode cobrir nenhum.
	c.preferred_formation = ["hero_cao_bento", arrived[1], arrived[0], "hero_gato_nick"]
	load("res://scripts/flow/journey_rules.gd").start_expedition(c, "fase_1", 4242)
	campaign.state = c
	root.get_node("GameFlow").change_to("street", {}, false)
	for i in 120:
		await process_frame
	var street = current_scene
	street.apply_corridor_weather("sunset")
	street.corridor.busy = true
	for index in street.corridor.guards:
		for card in street.corridor.guards[index].cards:
			card.visible = false
	# Os seis lado a lado, na mesma linha do chão: a escala do Guaxinim e do Tatu contra a dos fundadores.
	var lineup := ["hero_cao_bento", "hero_coruja_vespera", "hero_gato_nick", "hero_sapo_iris"] + arrived
	var base: Vector3 = street._heroes[0].position
	var shown: Array = []
	var Card = load("res://scripts/world/sprite_card.gd")
	var Heights = load("res://scripts/world/character_heights.gd")
	var Arena = load("res://scripts/combat/combat_arena.gd")
	for card in street._heroes:
		card.visible = false
	for i in lineup.size():
		var hero = campaign.hero(lineup[i])
		var card = Card.new()
		card.body_height = Heights.find(lineup[i])
		card.show_art(Arena.art_entry(street._combat_art.heroes, lineup[i], String(hero.get("art_variant", ""))).idle)
		street.add_child(card)
		card.position = Vector3(street._leader.position.x + (i - 2.5) * 1.25, base.y, base.z)
		card.set_facing(1.0)
		shown.append(card)
	await _frames(30)
	await _save("00-lineup")
	for card in shown:
		print("fila %s: altura %.2f m, pé em y=%.3f" % [lineup[shown.find(card)], card.body_height, card.global_position.y])
		card.queue_free()
	for card in street._heroes:
		card.visible = true
	var cards: Array = []
	for id in ENEMIES:
		cards.append(street.corridor._enemy_card(id))
	var heroes: Array = street.party_ids.map(func(id): return campaign.hero(id))
	print("equipe: ", street.party_ids)
	street.begin_fight()
	var arena = street._arena
	arena.auto_battle = false
	arena.start(heroes, street._heroes, ENEMIES, cards, street._leader.position.x + 3.0, true, 7)
	for i in 900:
		if arena.hud != null and arena.hud.waiting:
			break
		await process_frame
	await _frames(20)
	await _save("01-formation")
	var state = arena.session.state
	for unit in state.player_team:
		var card = arena.cards[unit.id]
		print("%s: altura %.2f m, pé em y=%.3f" % [unit.hero_id, card.body_height, card.global_position.y])
	# Cada pose dos dois, com a câmera aberta: os golpes e as reações (a queda por último).
	arena.hud.visible = false
	for unit in state.player_team.filter(func(u): return u.class_id in ["rato", "tatu"]):
		for ability_id in arena.session.data.classes[unit.class_id].AbilityIds:
			arena.show_pose(unit, "execucao", ability_id)
			await _frames(4)
			await _save("02-%s-%s" % [unit.class_id, ability_id])
		for pose in ["hurt", "dodge", "defense", "death"]:
			arena.show_pose(unit, pose)
			await _frames(4)
			await _save("03-%s-%s" % [unit.class_id, pose])
		arena.show_pose(unit, "idle")
	arena.hud.visible = true
	# A luta de verdade, sozinha, até o fim.
	arena.speed = 2.0
	arena.auto_battle = true
	arena.hud.command_chosen.emit({"kind": "defend"})
	var shot := 0
	var frame := 0
	var limit := Time.get_ticks_msec() + 180000
	while arena.active and not arena.hud._result.visible and Time.get_ticks_msec() < limit:
		frame += 1
		if frame % 45 == 0 and shot < 16:
			shot += 1
			await _save("04-fight-%02d" % shot)
		await process_frame
	await _frames(4)
	await _save("05-end")
	print("fim: ", arena.hud._result.visible)
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit()


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)


func _frames(count: int) -> void:
	for i in count:
		await process_frame
