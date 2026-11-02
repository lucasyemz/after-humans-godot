## Fotos da #263 (as relíquias, PR 1): a Sala com os dois slots do Bento cheios, o aviso de bloqueio ao trocar o slot 2
## do Nick (a única do estoque já está no slot 1 dele) e a ficha com uma linha por relíquia. Roda também no código de
## antes (um slot só: o Bento leva a primeira, e o Nick troca o slot único).
##   xvfb-run -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     -s res://tools/capture_263.gd -- --out=<pasta>
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
var S


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
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	var c: Dictionary = campaign.create_initial(263)
	c.station.last_return = {}
	var bento = S.hero(c, "hero_cao_bento")
	var nick = S.hero(c, "hero_gato_nick")
	var two_slots: bool = bento.has("relics")
	if two_slots:
		bento.relics = ["botao_cobre", "semente_guardada"]
		nick.relics = ["pena_vidro", ""]
	else:
		bento.relic_id = "botao_cobre"
		nick.relic_id = "pena_vidro"
	c.inventory.relics = ["pena_vidro"]
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	while flow.busy or current_scene == null or current_scene.name != "Station":
		await process_frame
	var station = current_scene
	var hud = station.hud
	await _frames(20)
	hud.open_room(S.CHARACTERS)
	await _until(func(): return station.camera_settled(), 900)
	await _frames(20)
	var screen = hud._room_screen
	screen.selected = "hero_cao_bento"
	screen.rebuild()
	await _frames(10)
	await _scroll_to(screen, "RelicSlot1")
	await _shot("01-sala-dois-slots")
	screen.selected = "hero_gato_nick"
	screen.rebuild()
	await _frames(10)
	await _scroll_to(screen, "RelicSlot1")
	await _press(screen, "Relic1" if two_slots else "Relic")
	await _shot("02-sala-bloqueio")
	var sheet_script = load("res://scripts/ui/character_sheet.gd")
	var sheet = sheet_script.new()
	hud.add_child(sheet)
	sheet.show_info(sheet_script.from_hero(S.hero(campaign.state, "hero_cao_bento")), Rect2(600, 260, 300, 200))
	await _frames(10)
	await _shot("03-ficha")
	sheet.queue_free()
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


## Rola a coluna da Sala até o nó (as relíquias ficam abaixo da ficha).
func _scroll_to(screen, name: String) -> void:
	var node = screen.find_child(name, true, false)
	if node == null:
		node = screen.find_child("Relic", true, false)
	var parent = node.get_parent() if node != null else null
	while parent != null and not (parent is ScrollContainer):
		parent = parent.get_parent()
	if parent != null:
		await _frames(2)
		parent.ensure_control_visible(node)
	await _frames(6)


func _press(screen, name: String) -> void:
	var button = screen.find_child(name, true, false)
	if button != null:
		button.pressed.emit()
	await _frames(12)


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
