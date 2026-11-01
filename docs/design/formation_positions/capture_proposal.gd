## Protótipo de aprovação #260. Não integra UI, regras, save ou inputs do jogo.
## Executar só manualmente, com --script e -- --out=<pasta externa>.
extends SceneTree

var output := ""
var kit
var style
var overlay: Control
var stage
var records := []
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
		for view in ["formation", "sheet", "kit_change"]:
			audit = []
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
			records.append({"view":view,"variant":variant,"labels":audit.duplicate(true)})
			overlay.queue_free()
			await frames(2)
	var f = FileAccess.open(output.path_join("capture_audit.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"renderer":"OpenGL Compatibility / Mesa llvmpipe CPU","physical_gpu":false,"resolution":[1920,1080],"fixture":"real Station, initial campaign seed 6, rooms unlocked in isolated memory, Character Room, frozen camera/time; proposal kit modal over the same scene","records":records},"  "))
	quit(0)

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

func rank_strip(parent: Control, counts: Array, denominator: int, x: float, y: float, width: float) -> void:
	var w := (width - 24) / 4.0
	var peak: int = counts.max()
	for column in 4:
		var rank: int = 4-column
		var count: int = counts[rank-1]
		var rec: bool = count > 0 and count == peak
		var tile := box(parent,Rect2(x+column*(w+8),y,w,128))
		if rec:
			var focus: Control = kit.selected_overlay()
			tile.add_child(focus)
			focus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var ink: Color = kit.good() if rec else (kit.alert_text() if count == 0 else kit.TEXT)
		txt(tile,"POS. " + str(rank),Rect2(0,0,w,36),20,kit.TEXT,true,true)
		txt(tile,str(count) + "/" + str(denominator),Rect2(0,36,w,52),30,ink,true,true)
		txt(tile,"REC." if rec else ("SEM OPÇÃO" if count == 0 else "POSSÍVEL"),Rect2(0,92,w,34),18,ink,true,true)

func portrait(parent: Control, name_: String, rect: Rect2) -> void:
	var texture = load("res://art/ui/portraits/" + name_ + ".png")
	var p: Control = kit.portrait(texture,rect.size.x)
	parent.add_child(p)
	p.position = rect.position
	p.size = rect.size

func build(view: String) -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.hud.add_child(overlay)
	var veil: Control = kit.veil()
	overlay.add_child(veil)
	var panel := box(overlay,Rect2(68,62,1784,956),"large")
	txt(panel,"FORMAÇÃO / POSIÇÕES DO KIT" if view == "formation" else ("FICHA / VÉSPERA" if view == "sheet" else "AO TROCAR AS HABILIDADES"),Rect2(30,10,1480,70),40,kit.TEXT,true)
	txt(panel,"PROPOSTA #260",Rect2(1500,20,230,48),20,kit.MUTED,false,true)
	if view == "formation": formation(panel)
	elif view == "sheet": sheet(panel)
	else: kit_change(panel)
	txt(panel,"Retaguarda  4  ·  3  ·  2  ·  1  Frente   |   REC. = mais opções no kit; não é obrigação.",Rect2(30,839,1700,48),23,kit.TEXT)
	txt(panel,"Protótipo para aprovação · dados atuais · nenhuma mudança nas regras ou na equipe",Rect2(30,894,1700,36),20,kit.MUTED)

func formation(p: Control) -> void:
	txt(p,"Compare as opções antes de escolher a ordem da equipe.",Rect2(30,81,1680,48),26)
	var examples := [["BENTO","cao","bento","FRENTE"],["ÍRIS","sapo","iris","RETAGUARDA"],["GUAXINIM","rato","raccoon_recruit_01","KIT MISTO"]]
	for i in 3:
		var e: Array = examples[i]
		var card := box(p,Rect2(30+i*570,143,550,407))
		portrait(card,e[2],Rect2(16,18,94,94))
		txt(card,e[0],Rect2(126,12,400,62),34,kit.TEXT,true)
		txt(card,e[3],Rect2(126,67,400,40),23,kit.MUTED)
		rank_strip(card,coverage(data_for(e[1])),4,14,139,520)
		txt(card,"Habilidades que partem de cada posição.",Rect2(18,273,510,44),22)
		var message: String = ["Posições 1 e 2: 4 de 4 opções.","Posições 3 e 4: 4 de 4 opções.","Posições 2 e 3: 3 de 4 opções."][i]
		txt(card,message,Rect2(18,321,510,55),25,kit.good(),true)
	var lower := box(p,Rect2(30,578,1690,230))
	txt(lower,"A ORDEM CONTINUA SENDO SUA",Rect2(24,12,1600,50),30,kit.TEXT,true)
	txt(lower,"A indicação compara o alcance de origem das habilidades equipadas. Não mede dano, cura ou a melhor composição.",Rect2(24,67,1600,62),26)
	txt(lower,"Na seleção: apontar ou focar a carta abre este detalhe. Na formação: um resumo por carta, sem impedir a troca.",Rect2(24,143,1600,62),24,kit.MUTED)

func sheet(p: Control) -> void:
	portrait(p,"vespera",Rect2(30,103,150,150))
	txt(p,"POSIÇÃO ATUAL: 1",Rect2(211,105,1500,60),34,kit.TEXT,true)
	txt(p,"Nesta posição, 1 de 4 habilidades pode partir daqui.",Rect2(211,169,1500,75),28)
	var left := box(p,Rect2(30,280,620,520))
	txt(left,"OPÇÕES POR POSIÇÃO",Rect2(18,14,580,50),28,kit.TEXT,true)
	rank_strip(left,coverage(data_for("coruja")),4,18,99,580)
	txt(left,"Na posição 1: Recurso de Emergência.",Rect2(18,239,580,82),27)
	txt(left,"Se for deslocada, atualize a posição atual. O alcance das habilidades permanece o mesmo.",Rect2(18,343,580,147),26,kit.MUTED)
	var right := box(p,Rect2(675,280,1045,520))
	txt(right,"HABILIDADE",Rect2(20,8,600,50),25,kit.TEXT,true)
	txt(right,"PARTE DE",Rect2(660,8,340,50),25,kit.TEXT,true,true)
	var idx := 0
	for a in abilities:
		if a.Name in data_for("coruja"):
			var row := box(right,Rect2(14,72+idx*82,1008,73))
			txt(row,a.DisplayName,Rect2(12,2,614,66),27)
			txt(row," · ".join(a.OriginRanks.map(func(r):return str(int(r)))),Rect2(646,2,330,66),27,kit.TEXT,true,true)
			idx += 1
	txt(right,"Origem ≠ alvo. Recarga, estado e alvo válido são verificados separadamente no turno.",Rect2(20,408,994,91),25,kit.MUTED)

func kit_change(p: Control) -> void:
	var old_ids := data_for("sapo")
	var changed := old_ids.duplicate()
	changed.erase("sapo_carga_voltaica")
	txt(p,"ÍRIS / SIMULAÇÃO DE EDIÇÃO DO KIT",Rect2(30,81,1690,47),27,kit.TEXT,true)
	for i in 2:
		var card := box(p,Rect2(30+i*860,145,830,319))
		txt(card,"KIT ATUAL · 4 HABILIDADES" if i == 0 else "PRÉVIA · SEM CARGA VOLTAICA",Rect2(20,10,790,62),28,kit.TEXT,true)
		rank_strip(card,coverage(old_ids if i == 0 else changed),4 if i == 0 else 3,20,99,790)
		txt(card,"Recomendadas: 3 e 4." if i == 0 else "Recomendadas: 2, 3 e 4. Prévia não confirmada.",Rect2(20,232,790,66),25)
	var empty := box(p,Rect2(30,493,1690,315))
	txt(empty,"ESTADO LIMITE / SIMULAÇÃO COM SÓ CARGA VOLTAICA",Rect2(20,8,1640,58),28,kit.TEXT,true)
	rank_strip(empty,coverage(["sapo_carga_voltaica"]),1,20,94,626)
	txt(empty,"POSIÇÃO 1: NENHUMA HABILIDADE PARTE DAQUI",Rect2(690,76,970,67),27,kit.alert_text(),true)
	txt(empty,"Reveja o kit ou a formação. Isso não proíbe ocupar a posição.",Rect2(690,151,970,66),25)
	txt(empty,"Exemplo hipotético: não é um kit válido confirmado. No jogo, recarga e estados têm avisos próprios.",Rect2(690,218,970,86),22,kit.MUTED)
