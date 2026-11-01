## #275: external art proof only. Does not patch or save production gameplay.
extends SceneTree
var output := ""
var assets := ""
var previous_assets := ""
var kit
var style
var grid
var layout
var rules
var station
var campaign: Dictionary
var camera: Camera3D
var overlay: Control
var labels: Array[Label] = []
var audit := []
var card_log := []
var records := []
var textures := {}
var visuals := []
var short_names := {"platform_rubble":"Escombros","overturned_wagon":"Vagão","maintenance_machine":"Máquina","exposed_cables":"Cabos","flooded_duct":"Duto","root_chamber":"Raízes"}
var full_names := {"platform_rubble":"Escombros da plataforma","overturned_wagon":"Vagão tombado","maintenance_machine":"Máquina antiga de manutenção","exposed_cables":"Cabos expostos","flooded_duct":"Duto alagado","root_chamber":"Raízes"}
var artwork := {"1:1":"platform_rubble","1:2":"root_chamber","2:1":"overturned_wagon","2:2":"exposed_cables","2:3":"flooded_duct","2:4":"root_chamber","2:5":"maintenance_machine","2:6":"exposed_cables","3:1":"platform_rubble","3:2":"overturned_wagon","3:3":"maintenance_machine","3:4":"exposed_cables","3:5":"flooded_duct","3:6":"root_chamber","3:7":"maintenance_machine"}
func _initialize() -> void: run.call_deferred()
func frames(n:int) -> void:
	for i in n: await process_frame
func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):output=a.trim_prefix("--out=")
		if a.begins_with("--assets="):assets=a.trim_prefix("--assets=")
		if a.begins_with("--previous-assets="):previous_assets=a.trim_prefix("--previous-assets=")
	if output=="" or assets=="":quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	await process_frame
	kit=load("res://scripts/ui/kit/kit.gd");style=load("res://scripts/ui/ui_style.gd")
	grid=load("res://scripts/flow/station_grid.gd");layout=load("res://scripts/station/station_layout.gd");rules=load("res://scripts/flow/station_rules.gd")
	var service=root.get_node("Campaign")
	service.save_dir=output.path_join("isolated_save");service.save_time_on_quit=false
	root.get_node("Tips").enabled=false
	campaign=service.create_initial(6)
	# Valid post-excavation state, fixture only. All pairs share exactly this state.
	campaign.station.grid.landings[0]=true
	campaign.station.grid.cells[1][6]="free"
	campaign.station.grid.progress["1:2"]=1
	campaign.station.grid.target="1:2"
	service.state=campaign
	root.get_node("GameFlow").change_to("station",{},false)
	await frames(90)
	station=current_scene
	await shot("main_native_ui")
	station.hud.visible=false
	station.set_process(false)
	camera=root.get_camera_3d()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=28.0
	camera.position=Vector3(9.6,-6.0,40.0);camera.rotation_degrees=Vector3(-3,0,0)
	Engine.time_scale=0
	await frames(5)
	for variant in ["normal","larger","colorblind"]:
		style.text_scale=1.3 if variant=="larger" else 1.0
		root.get_node("Settings").colorblind=variant=="colorblind";style.set_colorblind(variant=="colorblind")
		await shot("before_"+variant)
		for view in ["overview","work","choice"]:
			labels=[];audit=[];card_log=[];visuals=[]
			build(view)
			await frames(4)
			for repeat in 3:
				for j in labels.size():
					var r: Array=audit[j].rect
					labels[j].size=Vector2(r[2],r[3]);labels[j].position=Vector2(r[0],r[1])
				for image in visuals:
					image.node.size=image.rect.size;image.node.position=image.rect.position
				await frames(2)
			for j in labels.size():
				var l: Label=labels[j];var r: Array=audit[j].rect
				audit[j].actual_size=[l.size.x,l.size.y];audit[j].actual_position=[l.position.x,l.position.y]
				if l.size.x>r[2]+1 or l.size.y>r[3]+1 or l.position.distance_to(Vector2(r[0],r[1]))>1:
					push_error("Review text overflow: "+l.text);quit(3);return
			await shot(view+"_"+variant)
			records.append({"view":view,"variant":variant,"cards":card_log.duplicate(true),"labels":audit.duplicate(true),"images":image_audit()})
			overlay.queue_free();await frames(2)
	# Previous artwork in the same frozen scene, so actors/time also match exactly.
	if previous_assets!="":
		assets=previous_assets;textures.clear()
		style.text_scale=1.0;root.get_node("Settings").colorblind=false;style.set_colorblind(false)
		labels=[];audit=[];card_log=[];visuals=[];build("overview")
		await frames(4)
		for repeat in 3:
			for j in labels.size():
				var lr: Array=audit[j].rect
				labels[j].size=Vector2(lr[2],lr[3]);labels[j].position=Vector2(lr[0],lr[1])
			for image in visuals:
				image.node.size=image.rect.size;image.node.position=image.rect.position
			await frames(2)
		await shot("overview_previous_normal")
		overlay.queue_free();await frames(2)
	var report={"base_commit":"69ad7910","engine":Engine.get_version_info().string,"renderer":"OpenGL Compatibility / Mesa llvmpipe CPU; no physical GPU","resolution":[1920,1080],"camera":var_to_str(camera.global_transform),"orthographic_size":camera.size,"fixture":"seed 6, L2 opened, 2:7 free, 1:2 progress 1 of 2; isolated memory/save only","before":"unmodified main Station scene; same orthographic review camera, people and frozen time","after":"independent illustrated card per actual buried/free grid cell, external textures and HUD review overlay only","records":records}
	var f=FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	unload_current_scene();station=null;overlay=null;labels.clear();textures.clear();await frames(3);root.get_node("Sound").quit(0)
func shot(name_:String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name_+".png"))
func txt(parent:Control,value:String,rect:Rect2,px:int=20,color:Color=Color("efe6d6"),bold:bool=false,center:bool=false) -> Label:
	var l:Label=kit.label("","text",color,bold)
	l.add_theme_font_size_override("font_size",style.px(px));l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	if center:l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l);l.text=value;l.size=rect.size;l.position=rect.position
	labels.append(l);audit.append({"text":value,"base_px":px,"font_px":style.px(px),"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
	return l
func panel(parent:Control,rect:Rect2,piece:String="panel_inset") -> Control:
	var p:=Panel.new();p.add_theme_stylebox_override("panel",kit.style(piece));p.position=rect.position;p.size=rect.size;parent.add_child(p);return p
func texture(key:String) -> Texture2D:
	if not textures.has(key):textures[key]=ImageTexture.create_from_image(Image.load_from_file(assets.path_join(key+".webp")))
	return textures[key]
func picture(parent:Control,key:String,rect:Rect2,tint:Color=Color.WHITE) -> TextureRect:
	var v:=TextureRect.new();v.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;v.stretch_mode=TextureRect.STRETCH_SCALE
	parent.add_child(v);v.texture=texture(key);v.size=rect.size;v.position=rect.position;v.modulate=tint
	visuals.append({"node":v,"rect":rect,"key":key})
	return v
func frame(parent:Control,key:String,rect:Rect2) -> void:
	picture(parent,"frames/"+key,rect)
func image_audit() -> Array:
	var out := []
	for image in visuals:
		var node:TextureRect=image.node;var rect:Rect2=image.rect
		out.append({"key":image.key,"expected":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"actual":[node.position.x,node.position.y,node.size.x,node.size.y]})
	return out
func screen_rect(entry:Dictionary) -> Rect2:
	var a=camera.unproject_position(Vector3(entry.x0*.01,entry.ceiling*.01,.01))
	var b=camera.unproject_position(Vector3(entry.x1*.01,entry.floor*.01,.01))
	var size:Vector2=b-a
	var ratio:float=(size.x-6.0)/size.x
	return Rect2(a+size*(1.0-ratio)*0.5,size*ratio)
func state_of(entry:Dictionary) -> String:
	if entry.state=="free":return "free"
	if grid.block_progress(campaign,entry.key)>0:return "work"
	if grid.diggable(campaign,entry.key):return "available"
	return "neighbor" if grid.block_open(campaign,"L"+str(entry.floor_number)) else "locked"
func reward(key:String,short_:bool=false) -> String:
	var r:Dictionary=grid.block_rule(key)
	var a: Array=[]
	if int(r.get("Scrap",0))>0:a.append("+%d %s"%[int(r.Scrap),"suc." if short_ else ("sucata" if int(r.Scrap)==1 else "sucatas")])
	if int(r.get("Fragments",0))>0:a.append("+%d %s"%[int(r.Fragments),"frag." if short_ else ("fragmento" if int(r.Fragments)==1 else "fragmentos")])
	return " · ".join(a)
func turns(key:String) -> String:
	var n:int=grid.returns_left(campaign,key)
	return "%d %s"%[n,"volta" if n==1 else "voltas"]
func build(view:String) -> void:
	overlay=Control.new();station.hud.get_parent().add_child(overlay);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	load("res://scripts/ui/station/station_frame.gd").top(overlay,campaign,"Expansão",func():pass)
	var speech=panel(overlay,Rect2(28,126,1860,70),"report_band")
	var face:Control=kit.portrait(load("res://art/ui/portraits/bento.png"),54)
	speech.add_child(face);face.position=Vector2(12,8);face.size=Vector2(54,54)
	txt(speech,"BENTO   “Quer dizer mais estação.”",Rect2(82,9,1730,52),24,kit.TEXT,true)
	for entry in layout.blocks(campaign):
		var rect:=screen_rect(entry);var state:=state_of(entry);var key:String=artwork.get(entry.key,"platform_rubble")
		var node:=Control.new();overlay.add_child(node);node.position=rect.position;node.size=rect.size
		if state!="free":picture(node,"illustrations/"+key,Rect2(Vector2.ZERO,rect.size))
		var fr:String={"locked":"frame_locked","available":"frame_available","neighbor":"frame_neighbor","work":"frame_available","free":"room_choice_card"}[state]
		frame(node,fr,Rect2(Vector2.ZERO,rect.size))
		var hh:float=36 if style.text_scale>1.2 else 28
		var title=panel(node,Rect2(0,-hh,rect.size.x,hh),"list_row")
		var cap:String={"locked":"BLOQUEADO","available":"LIBERADO","neighbor":"VIZINHO","work":"EM OBRA","free":"CONSTRUIR"}[state]
		txt(title,("Vaga livre" if state=="free" else short_names[key])+" · "+cap,Rect2(6,0,rect.size.x-12,hh),18,kit.alert_text() if state=="neighbor" else kit.TEXT,true,true)
		var footer=panel(node,Rect2(0,rect.size.y-32,rect.size.x,32),"list_row")
		var line:String={"locked":"Patamar fechado","available":"Escavar · "+reward(entry.key,true),"neighbor":"Escave o vizinho","work":"Escavando · "+turns(entry.key),"free":"Escolher cômodo"}[state]
		txt(footer,line,Rect2(6,0,rect.size.x-12,32),18,kit.alert_text() if state=="neighbor" else kit.TEXT,false,true)
		if state=="work":picture(node,"icons/work_in_progress",Rect2(8,8,32,32),kit.AMBER)
		if state=="free":picture(node,"icons/choose_room",Rect2(rect.size.x*.5-24,rect.size.y*.5-29,48,48),kit.AMBER)
		card_log.append({"key":entry.key,"art":key if state!="free" else "room_choice_card","state":state,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"guaranteed_reward":reward(entry.key),"progress":grid.block_progress(campaign,entry.key),"total_work":grid.block_work(entry.key)})
	var selected:String="1:2" if view=="work" else "2:6"
	var detail=panel(overlay,Rect2(28,810,1350,238),"panel_large")
	if view=="choice":
		picture(detail,"frames/room_choice_card",Rect2(16,14,390,208))
		var preview:=TextureRect.new();preview.texture=load("res://art/station/cards/Depot_Container.webp");preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;preview.position=Vector2(50,55);preview.size=Vector2(320,132);detail.add_child(preview)
		txt(detail,"DEPÓSITO · 1 VAGA",Rect2(438,14,880,58),30,kit.TEXT,true)
		txt(detail,"Custo: "+rules.cost_text(rules.next_level_cost(campaign,"depot")),Rect2(438,80,880,60),25)
		var block:String=rules.upgrade_block(campaign,"depot")
		txt(detail,block if block!="" else "Cabe na vaga 2:7. Confira e confirme para construir.",Rect2(438,149,880,70),23,kit.alert_text() if block!="" else kit.MUTED)
	else:
		var key:String=artwork[selected]
		picture(detail,"illustrations/"+key,Rect2(16,14,390,208));frame(detail,"frame_available",Rect2(16,14,390,208))
		txt(detail,full_names[key],Rect2(438,9,880,58),32,kit.TEXT,true)
		txt(detail,"Recompensa garantida: "+reward(selected),Rect2(438,74,880,50),25)
		if view=="work":
			var bar:Control=kit.bar("amber",grid.block_progress(campaign,selected),grid.block_work(selected),"")
			detail.add_child(bar);bar.position=Vector2(438,139);bar.size=Vector2(370,34)
			txt(detail,"Obra %d/%d · %s %s"%[grid.block_progress(campaign,selected),grid.block_work(selected),"falta" if grid.returns_left(campaign,selected)==1 else "faltam",turns(selected)],Rect2(830,133,490,48),22)
			txt(detail,"O progresso fica no bloco. Texto fora da barra, sobre aço escuro.",Rect2(438,183,880,43),20,kit.MUTED)
		else:
			txt(detail,"Escavar · "+turns(selected)+" no ritmo atual",Rect2(438,131,880,46),25,kit.AMBER,true)
			txt(detail,"Achados extras podem ocorrer; não fazem parte da recompensa garantida.",Rect2(438,183,880,43),20,kit.MUTED)
	var go:Control=kit.button("CONSTRUIR" if view=="choice" else ("OBRA EM ANDAMENTO" if view=="work" else "ESCAVAR ESTE BLOCO"),"primary")
	overlay.add_child(go);go.position=Vector2(1402,972);go.size=Vector2(486,76)
	go.icon=texture("icons/choose_room" if view=="choice" else ("icons/work_in_progress" if view=="work" else "icons/excavate"))
	go.expand_icon=true;go.add_theme_constant_override("icon_max_width",32)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","icon_normal_color","icon_hover_color","icon_pressed_color","icon_focus_color"]:go.add_theme_color_override(state,kit.ON_AMBER)
	if view=="choice":go.disabled=rules.upgrade_block(campaign,"depot")!=""
	if view=="work":go.disabled=true
	txt(overlay,"Arte #275 · prévia no kit · integração pelo Claude 1 / PR #284",Rect2(1402,811,486,146),22,kit.TEXT,false,true)
