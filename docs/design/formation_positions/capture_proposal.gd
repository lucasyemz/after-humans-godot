## Protótipo de aprovação #260. Não integra UI, regras, save ou inputs do jogo.
## Executar só manualmente, com --script e -- --out=<pasta externa>.
extends SceneTree

var output := ""
var kit
var style
var overlay: Control
var stage
var records := []
var marker_records := []
var abilities: Array
var classes: Array
var audit := []
var live_labels: Array[Label] = []

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n: await process_frame

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	if output.is_empty():
		push_error("Informe --out fora do Git; esta ferramenta só produz capturas.")
		quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	await process_frame
	kit = load("res://scripts/ui/kit/kit.gd")
	style = load("res://scripts/ui/ui_style.gd")
	abilities = JSON.parse_string(FileAccess.get_file_as_string("res://data/abilities.json"))
	classes = JSON.parse_string(FileAccess.get_file_as_string("res://data/classes.json"))
	var campaign = root.get_node("Campaign")
	campaign.save_dir = output.path_join("isolated_save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").enabled = false
	var c: Dictionary = campaign.create_initial(6)
	for room in c.station.rooms: c.station.rooms[room] = 1
	c.station["tour_seen"] = true
	campaign.state = c
	root.get_node("GameFlow").change_to("station", {}, false)
	await frames(100)
	stage = current_scene
	stage.hud.open_room("characters")
	await frames(100)
	stage.set_process(false)
	Engine.time_scale = 0
	for variant in ["normal", "larger", "colorblind"]:
		style.text_scale = 1.3 if variant == "larger" else 1.0
		root.get_node("Settings").colorblind = variant == "colorblind"
		style.set_colorblind(variant == "colorblind")
		stage.hud.refresh()
		await frames(6)
		await shot("current_" + variant)
		for view in ["overview", "attack", "support"]:
			audit = []
			marker_records = []
			live_labels = []
			build(view)
			await frames(4)
			# A quebra de linha atualiza o mínimo de modo diferido na Godot.
			# Reaplicar o retângulo depois da composição evita conservar a altura de largura zero.
			for repeat in 3:
				for j in live_labels.size():
					var rect: Array = audit[j].rect
					live_labels[j].size = Vector2(rect[2],rect[3])
					live_labels[j].position = Vector2(rect[0],rect[1])
				await frames(2)
			for j in live_labels.size():
				var label: Label = live_labels[j]
				audit[j]["actual_size"] = [label.size.x,label.size.y]
				audit[j]["minimum_size"] = [label.get_minimum_size().x,label.get_minimum_size().y]
				audit[j]["actual_position"] = [label.position.x,label.position.y]
				var expected: Array = audit[j].rect
				if label.size.x > expected[2]+1 or label.size.y > expected[3]+1 or label.position.distance_to(Vector2(expected[0],expected[1])) > 1:
					push_error("Texto fora do retângulo: " + label.text)
					quit(3); return
			await shot(view + "_" + variant)
			records.append({"view":view,"variant":variant,"labels":audit.duplicate(true),"markers":marker_records.duplicate(true)})
			overlay.queue_free()
			await frames(2)
	var f = FileAccess.open(output.path_join("capture_audit.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"renderer":"OpenGL Compatibility / Mesa llvmpipe CPU","physical_gpu":false,"resolution":[1920,1080],"fixture":"real Station, initial campaign seed 6, rooms unlocked in isolated memory, Character Room, frozen camera/time; compact ability block and contextual tooltip over the same scene","records":records},"  "))
	f.close()
	unload_current_scene()
	stage = null
	overlay = null
	live_labels.clear()
	await frames(3)
	root.get_node("Sound").quit(0)

func shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name_ + ".png"))

func txt(parent: Control, value: String, rect: Rect2, px: int = 24, color: Color = Color("efe5d1"), bold: bool = false, center: bool = false) -> Label:
	var l: Label = kit.label("", "text", color, bold)
	l.add_theme_font_size_override("font_size", style.px(px))
	if bold: l.add_theme_font_override("font", kit.font(true))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if center: l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	l.text = value
	l.size = rect.size
	l.position = rect.position
	live_labels.append(l)
	audit.append({"text":value,"base_px":px,"font_px":style.px(px),"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
	return l

func box(parent: Control, rect: Rect2, kind: String = "inset") -> Control:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", kit.style(kit.piece_of("panel", kind)))
	p.position = rect.position
	p.size = rect.size
	parent.add_child(p)
	# Os elementos deste protótipo são posicionados em coordenadas locais, sem container.
	var content := Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_child(content)
	return content

func data_for(class_id: String) -> Array:
	for c in classes:
		if c.Name == class_id: return c.AbilityIds
	return []

func coverage(ids: Array) -> Array:
	var counts := [0,0,0,0]
	for a in abilities:
		if a.Name in ids:
			for r in a.OriginRanks: counts[int(r)-1] += 1
	return counts

class RankMarker extends Control:
	var active := false
	var ink := Color("e9c47c")
	var target := false
	func _draw() -> void:
		var c := size * 0.5
		var radius := minf(size.x,size.y)*0.40
		if target:
			var points := PackedVector2Array([c+Vector2(0,-radius),c+Vector2(radius,0),c+Vector2(0,radius),c+Vector2(-radius,0)])
			draw_colored_polygon(points,Color("0d1012"))
			var closed := points.duplicate(); closed.append(points[0])
			draw_polyline(closed,ink,2.0,true)
			if active:
				var inner := PackedVector2Array()
				for point in points: inner.append(c+(point-c)*0.63)
				draw_colored_polygon(inner,ink)
		else:
			draw_circle(c,radius,Color("0d1012"))
			draw_arc(c,radius,0,TAU,40,ink,2.0,true)
			if active: draw_circle(c,radius*0.63,ink)

func markers(parent: Control, ranks: Array, x: float, y: float, target: bool, ink: Color, enemy: bool = false) -> void:
	var side: float = 40 if style.text_scale > 1.2 else 32
	var order := [1,2,3,4] if enemy else [4,3,2,1]
	var valid: Array[int] = []
	for rank in ranks: valid.append(int(rank))
	for i in 4:
		var marker := RankMarker.new()
		marker.position=Vector2(x+i*48,y)
		marker.size=Vector2(side,side)
		marker.active=valid.has(int(order[i]))
		marker_records.append({"target":target,"enemy":enemy,"rank":int(order[i]),"active":marker.active})
		marker.ink=ink
		marker.target=target
		parent.add_child(marker)
		txt(parent,str(order[i]),Rect2(x+i*48,y+44,side,32),20,kit.TEXT,true,true)

func build(view: String) -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.hud.add_child(overlay)
	# Só o bloco HABILIDADES é substituído: abas do elenco e ações da Sala permanecem.
	var compact_top: float = 554 if style.text_scale > 1.2 else 510
	var p := box(overlay,Rect2(28,compact_top,540,904-compact_top),"large")
	txt(p,"HABILIDADES DE COMBATE",Rect2(24,8,492,46),26,kit.TEXT,true)
	var ids := data_for("cao")
	var selected: int = {"overview":-1,"attack":1,"support":3}[view]
	var counts := coverage(ids)
	var origins := []
	var targets := []
	var ability: Dictionary = {}
	var enemy := true
	if selected < 0:
		for i in 4:
			if counts[i] == counts.max(): origins.append(i+1)
		for a in abilities:
			if a.Name in ids and a.TargetType == "SingleEnemy":
				for rank in a.TargetRanks:
					if rank not in targets: targets.append(rank)
	else:
		for a in abilities:
			if a.Name == ids[selected]: ability = a
		origins=ability.OriginRanks
		targets=ability.TargetRanks
		enemy=ability.TargetType == "SingleEnemy"
	txt(p,"PREFERÊNCIA" if selected < 0 else "PARTE DE",Rect2(24,60,220,34),20,kit.TEXT,true)
	txt(p,"ALVOS · ATAQUES" if selected < 0 else ("ALVO · INIMIGO" if enemy else "ALVO · ALIADO"),Rect2(272,60,242,34),20,kit.TEXT,true)
	markers(p,origins,28,102,false,kit.AMBER)
	markers(p,targets,276,102,true,kit.enemy_hp() if enemy else kit.hero_hp(),enemy)
	for i in ids.size():
		var slot: Control = kit.button("","icon")
		p.add_child(slot)
		slot.position=Vector2(24+i*132,193)
		slot.size=Vector2(96,96)
		var texture := TextureRect.new()
		texture.texture=load(load("res://scripts/combat/combat_arena.gd").icon_of(ids[i]))
		texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.position=Vector2(8,8)
		texture.size=Vector2(80,80)
		slot.add_child(texture)
		if i == selected:
			var focus: Control = kit.selected_overlay()
			slot.add_child(focus)
			focus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var key := Panel.new()
		key.add_theme_stylebox_override("panel",kit.style(kit.piece_of("key","tab")))
		p.add_child(key)
		key.position=Vector2(84+i*132,253)
		key.size=Vector2(36,36)
		txt(key,str(i+1),Rect2(0,0,36,36),20,kit.AMBER if i==selected else kit.TEXT,true,true)
	txt(p,"4 equipadas · frente 1 e 2" if selected < 0 else ability.DisplayName,Rect2(24,297,492,46),24,kit.TEXT,true)
	if selected >= 0:
		# Dica temporária da habilidade; somente ao apontar/focar, sobre o painel direito.
		var tip := box(overlay,Rect2(1316,612,540,314),"large")
		txt(tip,ability.DisplayName,Rect2(24,14,492,64),28,kit.TEXT,true)
		txt(tip,ability.Description,Rect2(24,89,492,112),23,kit.TEXT)
		txt(tip,"Cheio: alcança · vazio: fora",Rect2(24,218,492,48),20,kit.MUTED)
		txt(tip,"Inimigos: 1 → 4" if enemy else "Aliados: 4 → 1",Rect2(24,268,492,33),20,kit.TEXT)
	var stamp := box(overlay,Rect2(610,144,620,68),"inset")
	txt(stamp,"PROPOSTA #260 · " + ("RESUMO DO KIT" if selected < 0 else "HABILIDADE EM FOCO"),Rect2(16,8,588,50),22,kit.TEXT,true,true)
