## QA visual da #225. Os PNG/WebP propostos só são carregados em memória; nenhuma tabela é alterada.
extends SceneTree
var out := ""
var prototypes := ""
var spec := ""
var proposal: Dictionary
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.trim_prefix("--out=")
		if arg.begins_with("--prototypes="):prototypes=arg.trim_prefix("--prototypes=")
		if arg.begins_with("--contract="):spec=arg.trim_prefix("--contract=")
	if out=="" or prototypes=="" or spec=="":
		push_error("Informe --out= --prototypes= --contract=")
		quit(2)
		return
	proposal=JSON.parse_string(FileAccess.get_file_as_string(spec))
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign=root.get_node("Campaign")
	campaign.save_dir=out.path_join("save_game")
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
	var ids=[c.roster[4].id,c.roster[5].id]
	load("res://scripts/flow/journey_rules.gd").start_expedition(c,"fase_1",4242)
	c.session.expedition.team=[c.roster[0].id,c.roster[1].id,ids[0],ids[1]]
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
	var sequence=["hero_cao_bento","hero_coruja_vespera","hero_gato_nick","hero_sapo_iris","raccoon","armadillo"]
	var base: Vector3=street._heroes[0].position
	var shown=[]
	for i in sequence.size():
		var id: String=sequence[i]
		var card=Card.new()
		if i<4:
			card.body_height=Heights.find(id)
			card.show_art(street._combat_art.heroes[id].idle)
		else:
			card.body_height=proposal.actors[id].old_height_m
			card.show_art(street._combat_art.recruits[id+"_recruit_01"].idle)
		street.add_child(card)
		card.position=Vector3(street._leader.position.x+(i-2.5)*1.3,base.y,base.z)
		card.set_facing(1.0)
		shown.append(card)
	await frames(20)
	Engine.time_scale=0
	await shot("lineup_before")
	for i in [4,5]:shown[i].body_height=proposal.actors[sequence[i]].height_m;shown[i]._layout()
	await frames(2)
	await shot("lineup_height_only")
	for i in [4,5]:bind(shown[i],proposal.actors[sequence[i]].assets.idle)
	await frames(2)
	await shot("lineup_after")
	var camera=root.get_camera_3d()
	var meta={"base_commit":"561f798","engine":Engine.get_version_info().string,"renderer":"OpenGL Compatibility / Mesa llvmpipe CPU / Xvfb","physical_gpu":false,"resolution":[1920,1080],"lineup_camera":var_to_str(camera.global_transform),"lineup_fov":camera.fov,"before":"main code/data/current art and heights","height_only":"diagnostic: old art at target heights, not main","after":"external proposed WebP loaded as ImageTexture in memory","same_process_pairs":true,"actors":[]}
	for i in sequence.size():meta.actors.append({"id":sequence[i],"body_height":shown[i].body_height,"position":var_to_str(shown[i].global_position)})
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
	await frames(20)
	Engine.time_scale=0
	arena.set_process(false)
	await shot("fight_before")
	for unit in arena.session.state.player_team:
		if unit.class_id in ["rato","tatu"]:
			var actor="raccoon" if unit.class_id=="rato" else "armadillo"
			var card=arena.cards[unit.id]
			card.body_height=proposal.actors[actor].height_m
			bind(card,proposal.actors[actor].assets.idle)
	await frames(3)
	await shot("fight_after")
	var f=FileAccess.open(out.path_join("capture.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(meta,"  "))
	quit(0)
func bind(card,art: Dictionary) -> void:
	var path=prototypes.path_join(art.prototype_file)
	var image=Image.load_from_file(path)
	image.generate_mipmaps()
	card._art=art.duplicate(true)
	card._art.file=path
	card._texture=ImageTexture.create_from_image(image)
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
