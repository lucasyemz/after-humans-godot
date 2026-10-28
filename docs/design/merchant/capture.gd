## QA #218: cena real da main; o protótipo só acrescenta a arte em memória.
extends SceneTree
var out := ""
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out=arg.trim_prefix("--out=")
	if out == "":
		push_error("Informe --out=<pasta temporária>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled",false)
	var c: Dictionary = campaign.create_initial(6)
	load("res://scripts/flow/journey_rules.gd").start_expedition(c,"fase_1",4242)
	campaign.state=c
	root.get_node("GameFlow").change_to("street",{},false)
	await _frames(120)
	var street=current_scene
	street.apply_corridor_weather("sunset")
	street.corridor.busy=true
	for index in street.corridor.guards:
		for card in street.corridor.guards[index].cards: card.visible=false
	for card in street._heroes: card.visible=false
	var Card=load("res://scripts/world/sprite_card.gd")
	var Heights=load("res://scripts/world/character_heights.gd")
	var lineup=["hero_cao_bento","hero_gato_nick","","hero_sapo_iris","hero_coruja_vespera"]
	var base: Vector3=street._heroes[0].position
	var positions=[]
	for i in lineup.size():
		var id: String=lineup[i]
		if id=="": continue
		var card=Card.new()
		card.body_height=Heights.find(id)
		card.show_art(street._combat_art.heroes[id].idle)
		street.add_child(card)
		card.position=Vector3(street._leader.position.x+(i-2)*1.65,base.y,base.z)
		card.set_facing(1.0)
		positions.append({"subject":id,"body_height":card.body_height,"position":var_to_str(card.global_position)})
	await _frames(20)
	Engine.time_scale=0.0
	await _frames(2)
	await _shot("before")
	var contract: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/design/merchant/contract.json"))
	var merchant=Card.new()
	merchant.body_height=1.72
	street.add_child(merchant)
	merchant.position=Vector3(street._leader.position.x,base.y,base.z)
	merchant.set_facing(1.0)
	positions.append({"subject":"merchant prototype","body_height":merchant.body_height,"position":var_to_str(merchant.global_position)})
	for pose in ["idle","walk","trade"]:
		merchant.show_art(contract.assets[pose])
		await _frames(3)
		await _shot("after_"+pose)
	var camera=root.get_camera_3d()
	var meta={"base_commit":"ff8fc83","engine":Engine.get_version_info().string,"renderer":"OpenGL Compatibility / Mesa llvmpipe CPU / Xvfb","physical_gpu":false,"camera":var_to_str(camera.global_transform),"fov":camera.fov,"resolution":[1920,1080],"subjects":positions,"same_process":true,"time_scale":0.0,"before":"main scene, founders, no merchant art registered","after":"AHSpriteCard prototype in memory, no production registry/logic change"}
	var f=FileAccess.open(out.path_join("capture.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(meta,"  "))
	quit(0)
func _frames(n: int) -> void:
	for i in n: await process_frame
func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name+".png"))
	print("foto: ",name)
