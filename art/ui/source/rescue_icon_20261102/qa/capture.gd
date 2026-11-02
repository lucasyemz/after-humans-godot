extends SceneTree
var output := ""
var icon_path := ""
var records := []
func _initialize() -> void:run.call_deferred()
func frames(n:int) -> void:
	for i in n:await process_frame
func shot(n:String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(n+".png"))
func glyph(node:Node):
	if node is TextureRect:return node
	for child in node.get_children():
		var found=glyph(child)
		if found!=null:return found
	return null
func pair(node:TextureRect,tex:Texture2D,key:String,variant:String) -> void:
	var old=node.texture
	await shot(key+"_before_"+variant)
	node.texture=tex
	await frames(2)
	await shot(key+"_after_"+variant)
	records.append({"view":key,"variant":variant,"before_texture":old.resource_path,"after_texture":icon_path,"rect":var_to_str(node.get_global_rect()),"icon_size":[node.size.x,node.size.y]})
	node.texture=old
func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):output=a.trim_prefix("--out=")
		if a.begins_with("--icon="):icon_path=a.trim_prefix("--icon=")
	if output=="" or icon_path=="":quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	await process_frame
	var service=root.get_node("Campaign");var flow=root.get_node("GameFlow");var settings=root.get_node("Settings")
	service.save_dir=output.path_join("isolated_save");service.save_time_on_quit=false;settings._persist=false
	root.get_node("Tips").enabled=false
	var S=load("res://scripts/flow/station_rules.gd");var J=load("res://scripts/flow/journey_rules.gd");var R=load("res://scripts/flow/rescue_rules.gd");var U=load("res://scripts/ui/ui_style.gd")
	var c:Dictionary=service.create_initial(23);c.completed_phases=["fase_1"]
	c.station.rooms[S.PREPARATION]=2
	var vespera:Dictionary=c.roster.filter(func(h):return h.class_id=="coruja")[0]
	vespera.captured={"mission":"cisterna_turva","spot":2,"phase":"fase_2","day":0}
	service.state=c
	J.start_expedition(c,"fase_2",4242)
	var route:Dictionary=c.session.expedition.corridor
	var index:int=R.current(c).step
	for i in index:route.steps[i].resolved=true
	route.index=index
	flow.change_to("street",{},false)
	await frames(40)
	while flow.busy:await process_frame
	var street=current_scene
	if street.corridor.prisoner!=null:street._place_leader(street.corridor.prisoner.position-Vector3(0.8,0,0))
	await frames(20)
	Engine.time_scale=0
	var tex=ImageTexture.create_from_image(Image.load_from_file(icon_path))
	for variant in ["normal","larger","colorblind"]:
		U.text_scale=1.3 if variant=="larger" else 1.0
		settings.colorblind=variant=="colorblind";U.set_colorblind(variant=="colorblind")
		street.exploration_hud.refresh(c)
		await frames(8)
		var node=glyph(street.exploration_hud._route_row.get_child(index*2))
		if node==null:push_error("No route glyph");quit(3);return
		await pair(node,tex,"route",variant)
	Engine.time_scale=1
	c.session={"screen":"shelter","expedition":null}
	flow.change_to("station",{},false)
	await frames(35)
	while flow.busy:await process_frame
	var map=current_scene.hud._map
	map.open("");map.show_tab("missions");map.pick_mission("rescue:0")
	await frames(12)
	Engine.time_scale=0
	for variant in ["normal","larger","colorblind"]:
		U.text_scale=1.3 if variant=="larger" else 1.0
		settings.colorblind=variant=="colorblind";U.set_colorblind(variant=="colorblind")
		map.restyle()
		await frames(8)
		var pin=map.find_child("Rescue_0",true,false)
		if pin==null:push_error("No rescue pin");quit(4);return
		await pair(glyph(pin.get_node("Beacon")),tex,"map",variant)
	var f=FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"base":"e2f0b58a","renderer":"Compatibility / Mesa llvmpipe CPU; no physical GPU","fixture":"seed23; Ves captured fase2; expedition4242; route current rescue step; isolated save","records":records},"  "));f.close()
	unload_current_scene();street=null;map=null;await frames(3);root.get_node("Sound").quit(0)
