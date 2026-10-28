extends SceneTree
var out := ""
var prototypes := ""
var spec := ""
var proposal: Dictionary
var recruit_team := false
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.trim_prefix("--out=")
		if arg.begins_with("--prototypes="):prototypes=arg.trim_prefix("--prototypes=")
		if arg.begins_with("--contract="):spec=arg.trim_prefix("--contract=")
		if arg=="--recruits":recruit_team=true
	if out=="" or prototypes=="" or spec=="":quit(2);return
	proposal=JSON.parse_string(FileAccess.get_file_as_string(spec))
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign=root.get_node("Campaign")
	campaign.save_dir=out.path_join("save_recruits" if recruit_team else "save_founders")
	campaign.save_time_on_quit=false
	root.get_node("Tips").set("enabled",false)
	var S=load("res://scripts/flow/station_rules.gd")
	var c: Dictionary=campaign.create_initial(6)
	c.inventory.seeds=500
	c.unlocked_classes=["cao","gato","sapo","coruja","rato","tatu"]
	var rng=RandomNumberGenerator.new()
	rng.seed=5
	S.recruit(c,"rato",rng,"Risco")
	S.recruit(c,"tatu",rng,"Casco")
	load("res://scripts/flow/journey_rules.gd").start_expedition(c,"fase_1",4242)
	c.session.expedition.team=[c.roster[0].id,c.roster[1].id,c.roster[4].id,c.roster[5].id] if recruit_team else [c.roster[0].id,c.roster[1].id,c.roster[2].id,c.roster[3].id]
	campaign.state=c
	root.get_node("GameFlow").change_to("street",{},false)
	await frames(120)
	var street=current_scene
	street.apply_corridor_weather("sunset")
	street.corridor.busy=true
	for index in street.corridor.guards:
		for card in street.corridor.guards[index].cards:card.visible=false
	for card in street._heroes:card.visible=false
	var Card=load("res://scripts/world/sprite_card.gd")
	var Heights=load("res://scripts/world/character_heights.gd")
	var sequence=["bento","nick","iris","vespera","raccoon","armadillo","watch"]
	var base: Vector3=street._heroes[0].position
	var shown=[]
	for i in sequence.size():
		var key: String=sequence[i]
		var id: String=proposal.actors[key].id
		var card=Card.new()
		card.body_height=Heights.find("rato" if key=="raccoon" else "tatu" if key=="armadillo" else id)
		var art: Dictionary=(street._combat_art.heroes if i<4 or key=="watch" else street._combat_art.recruits)[id].idle.duplicate(true)
		if key=="watch":art.file="res://art/skins/bento/watch/idle.webp"
		card.show_art(art)
		street.add_child(card)
		card.position=Vector3(street._leader.position.x+(i-3)*1.15,base.y,base.z)
		card.set_facing(1.0)
		shown.append(card)
	await frames(20)
	Engine.time_scale=0
	await shot("lineup_before")
	for state in ["exploration","combat"]:
		for i in sequence.size():
			shown[i].body_height=proposal.actors[sequence[i]].height_m
			bind(shown[i],proposal.actors[sequence[i]].states[state])
		await frames(3)
		await shot("lineup_"+state)
	var camera=root.get_camera_3d()
	var meta={"base_commit":"5bb2928","engine":Engine.get_version_info().string,"renderer":"OpenGL Compatibility / Mesa llvmpipe CPU / Xvfb","physical_gpu":false,"resolution":[1920,1080],"camera":var_to_str(camera.global_transform),"fov":camera.fov,"before":"main current art, skin watch current idle","after":"external proposed textures bound in memory; redraw225 dependency for recruits","same_process_pairs":true}
	Engine.time_scale=1
	for card in shown:card.queue_free()
	for card in street._heroes:card.visible=true
	await frames(5)
	var enemy_ids=["robot","cao_eco"]
	var enemy_cards=[]
	for id in enemy_ids:enemy_cards.append(street.corridor._enemy_card(id))
	var heroes: Array=street.party_ids.map(func(id):return campaign.hero(id))
	street.begin_fight()
	var arena=street._arena
	arena.auto_battle=false
	arena.start(heroes,street._heroes,enemy_ids,enemy_cards,street._leader.position.x+9,true,7)
	for i in 900:
		if arena.hud!=null and arena.hud.waiting:break
		await process_frame
	await create_timer(2.0).timeout
	Engine.time_scale=0
	arena.set_process(false)
	if recruit_team:
		for unit in arena.session.state.player_team:
			if unit.class_id=="cao":
				var art: Dictionary=street._combat_art.heroes.hero_cao_bento.idle.duplicate(true)
				art.file="res://art/skins/bento/watch/idle.webp"
				arena.cards[unit.id].show_art(art)
		await frames(3)
	var prefix="recruits" if recruit_team else "founders"
	await shot(prefix+"_fight_before")
	for unit in arena.session.state.player_team:
		var key: String={"cao":"watch" if recruit_team else "bento","gato":"nick","sapo":"iris","coruja":"vespera","rato":"raccoon","tatu":"armadillo"}[unit.class_id]
		var card=arena.cards[unit.id]
		card.body_height=proposal.actors[key].height_m
		bind(card,proposal.actors[key].states.combat)
	await frames(3)
	await shot(prefix+"_fight_after")
	var f=FileAccess.open(out.path_join(prefix+"_capture.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(meta,"  "))
	quit(0)
func bind(card,art: Dictionary) -> void:
	var path=prototypes.path_join(art.prototype_file)
	var im=Image.load_from_file(path)
	im.generate_mipmaps()
	card._art=art.duplicate(true)
	card._art.file=path
	card._texture=ImageTexture.create_from_image(im)
	card._material.albedo_texture=card._texture
	if card._silhouette!=null:card._silhouette.set_shader_parameter("albedo_tex",card._texture)
	card._frame=0
	card._frame_time=0
	card._layout()
func frames(n: int) -> void:
	for i in n:await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name+".png"))
	print("foto: ",name)
