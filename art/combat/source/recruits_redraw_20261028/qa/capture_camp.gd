## QA de acampamento #210/#225: main e desenho proposto, mesma câmera/equipe/momento.
extends SceneTree
var out := ""
var prototypes := ""
var spec := ""
var sleeping := false
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.trim_prefix("--out=")
		if arg.begins_with("--prototypes="):prototypes=arg.trim_prefix("--prototypes=")
		if arg.begins_with("--contract="):spec=arg.trim_prefix("--contract=")
		if arg=="--sleep":sleeping=true
	if out=="" or prototypes=="" or spec=="":quit(2);return
	var proposal: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(spec))
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign=root.get_node("Campaign")
	campaign.save_dir=out.path_join("save_camp_sleep" if sleeping else "save_camp_seat")
	campaign.save_time_on_quit=false
	root.get_node("Tips").set("enabled",false)
	var S=load("res://scripts/flow/station_rules.gd")
	var c: Dictionary=campaign.create_initial(23)
	c.inventory.seeds=500
	c.unlocked_classes=["cao","gato","sapo","coruja","rato","tatu"]
	var rng=RandomNumberGenerator.new()
	rng.seed=5
	S.recruit(c,"rato",rng,"Risco")
	S.recruit(c,"tatu",rng,"Casco")
	load("res://scripts/flow/journey_rules.gd").start_expedition(c,"fase_1",23)
	c.session.expedition.team=[c.roster[0].id,c.roster[1].id,c.roster[4].id,c.roster[5].id]
	for h in [c.roster[4],c.roster[5]]:h.hp=maxi(1,int(h.max_hp)/5) if sleeping else h.max_hp
	campaign.state=c
	root.get_node("GameFlow").change_to("street",{},false)
	await frames(10)
	while root.get_node("GameFlow").busy:await process_frame
	var street=current_scene
	var corridor=street.corridor
	var route: Dictionary=c.session.expedition.corridor
	var site: int=route.sites.map(func(s):return s.camp_site).find(true)
	route.index=route.sites[site].step
	for i in route.index+1:route.steps[i].resolved=true
	route.sites[site].has_enemy=false
	await corridor._enter_house(site)
	await frames(20)
	await corridor._start_camp()
	await create_timer(2.0).timeout
	await frames(30)
	Engine.time_scale=0
	var state="sleep" if sleeping else "seat"
	await shot("camp_"+state+"_before")
	for member in corridor.camp.members:
		var hero=campaign.hero(member.hero_id)
		if hero.class_id not in ["rato","tatu"]:continue
		var actor="raccoon" if hero.class_id=="rato" else "armadillo"
		var art: Dictionary=proposal.actors[actor].assets[state]
		var card=member.card
		card.body_height=proposal.actors[actor].height_m
		var image=Image.load_from_file(prototypes.path_join(art.prototype_file))
		image.generate_mipmaps()
		card._art=art.duplicate(true)
		card._art.file=prototypes.path_join(art.prototype_file)
		card._texture=ImageTexture.create_from_image(image)
		card._material.albedo_texture=card._texture
		card._frame=0
		card._frame_time=0
		card._layout()
	await frames(3)
	await shot("camp_"+state+"_after")
	quit(0)
func frames(n: int) -> void:
	for i in n:await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name+".png"))
	print("foto: ",name)
