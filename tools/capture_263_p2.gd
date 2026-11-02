## Fotos da #263, parte 2 (as relíquias novas): a Sala com a Luva de Sucata do Bento (o nome com a raridade e o que faz),
## a ficha com as duas relíquias, o Mercador com a Incomum da visita entre as trocas e o relatório de uma derrota que
## deixou para trás a relíquia achada na expedição. Roda também no código de antes (sem as relíquias novas: a Luva não
## existe, o Mercador tem as quatro trocas e a derrota não tira nada).
##   xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --resolution 1920x1080 \
##     -s res://tools/capture_263_p2.gd -- --out=<pasta>
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
var S
var flow
var campaign


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
	S = load("res://scripts/flow/station_rules.gd")
	var relics = load("res://scripts/flow/relic_rules.gd")
	var part2: bool = relics.get_script_method_list().any(func(m): return m.name == "find")
	campaign = root.get_node("Campaign")
	flow = root.get_node("GameFlow")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	# A Sala e a ficha: o Bento com o Botão de Cobre e a Luva de Sucata (a pessoal dele).
	var c: Dictionary = campaign.create_initial(2632)
	c.station.last_return = {}
	S.hero(c, "hero_cao_bento").relics = ["botao_cobre", "luva_sucata"]
	S.hero(c, "hero_gato_nick").relics = ["gancho_telhado", "pena_vidro"]
	c.inventory.relics = ["cartao_eclusa"]
	campaign.state = c
	campaign.save()
	await _station()
	var station = current_scene
	var hud = station.hud
	hud.open_room(S.CHARACTERS)
	await _until(func(): return station.camera_settled(), 900)
	await _frames(20)
	var screen = hud._room_screen
	screen.selected = "hero_cao_bento"
	screen.rebuild()
	await _frames(10)
	await _scroll_to(screen, "RelicSlot1")
	await _shot("01-sala-pessoal")
	var sheet_script = load("res://scripts/ui/character_sheet.gd")
	var sheet = sheet_script.new()
	hud.add_child(sheet)
	sheet.show_info(sheet_script.from_hero(S.hero(campaign.state, "hero_gato_nick")), Rect2(600, 260, 300, 200))
	await _frames(10)
	await _shot("02-ficha")
	sheet.queue_free()
	# O Mercador com a relíquia da visita.
	var m: Dictionary = campaign.create_initial(2633)
	m.inventory.seeds = 40
	m.inventory.scrap = 5
	m.inventory.fragments = 2
	S.train_on_return(m, "capture-263-merchant", "merchant")
	m.station.last_return = {}
	var train_state: Dictionary = m.station.train.duplicate(true)
	m.station.train = {"phase": "none", "candidate_id": "", "expedition_id": "", "accepted": false, "recruit": {}, "next": {}, "trades": {}}
	campaign.state = m
	campaign.save()
	await _station()
	station = current_scene
	hud = station.hud
	await _frames(4)
	campaign.state.station.train = train_state
	station.focus_platform(true)
	station.show_candidate(S.MERCHANT)
	station._go(station._candidate_key(), true, true)
	hud._arrived_candidate = S.MERCHANT
	hud.open_service("train")
	var end := Time.get_ticks_msec() + 600000
	while (station.train_busy() or not hud._panel.visible) and Time.get_ticks_msec() < end:
		await process_frame
	await _frames(8)
	# A troca da relíquia é a quinta: a lista rola até ela (no código de antes, até a última).
	var last = hud._body.find_child("Trade_buy_relic", true, false)
	if last == null:
		last = hud._body.find_child("Trade_buy_scrap", true, false)
	await _scroll_to(hud._body, last.name if last != null else "")
	await _shot("03-mercador")
	# A derrota que deixa para trás a relíquia achada (a caixa da carga) e o relatório da volta.
	var d: Dictionary = campaign.create_initial(2634)
	d.station.rooms[S.DORMITORY] = 1
	load("res://scripts/flow/journey_rules.gd").start_expedition(d, "fase_1", 2634)
	if part2:
		relics.find(d, "sino_vitrine")
	else:
		d.inventory.relics.append("sino_vitrine")
	d.session.result = "defeat"
	S.finish_return(d)
	campaign.state = d
	campaign.save()
	await _station()
	current_scene.hud.open_service("report")
	end = Time.get_ticks_msec() + 1200000
	while current_scene.hud.current != "report" and Time.get_ticks_msec() < end:
		await process_frame
	await _frames(6)
	await _shot("04-derrota")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _station() -> void:
	flow.change_to("station", {}, false)
	for i in 600:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.name == "Station" and i > 10:
			break
	await _frames(20)


## Rola a coluna da Sala até o nó (as relíquias ficam abaixo da ficha).
func _scroll_to(screen, name: String) -> void:
	var node = screen.find_child(name, true, false)
	var parent = node.get_parent() if node != null else null
	while parent != null and not (parent is ScrollContainer):
		parent = parent.get_parent()
	if parent != null:
		await _frames(2)
		parent.ensure_control_visible(node)
	await _frames(6)


func _until(condition: Callable, frames: int = 2400) -> void:
	for i in frames:
		if condition.call():
			return
		await process_frame


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
