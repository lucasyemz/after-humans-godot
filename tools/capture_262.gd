## Fotos da Arma e da Segunda Pele na Forja (#262):
##   10-forge: a Forja nível 1 com o Bento no nível 4 (a seção rolada até as peças);
##   11-forge-done: depois de melhorar a Arma (o resto do dia apagado, com o motivo na tela);
##   20-room (--case=room, PR 2): a Sala com as duas peças do Bento (Arma 2, Segunda Pele 1) e o próximo nível.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_262.gd -- --out=<pasta> [--case=room] [--text-size=2]
## Só mexe no estado por dicionários (roda também antes da #262, para a foto de antes). O save do jogador fica intacto.
extends SceneTree

var out := ""
var case_name := "forge"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--case="):
			case_name = arg.trim_prefix("--case=")
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	campaign.save_dir = out.path_join("save-262")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	var S = load("res://scripts/flow/station_rules.gd")
	var c: Dictionary = campaign.create_initial(262)
	c.station.last_return = {}
	c.station.rooms[S.FORGE] = 1
	S.adjust(c, "scrap", 20)
	S.adjust(c, "fragments", 6)
	for hero in c.roster:
		hero.level = 4
	if case_name == "room":
		var bento = S.hero(c, "hero_cao_bento")
		bento.level = 6
		bento.gear = {"weapon": 2, "armor": 1}
	campaign.state = c
	campaign.save()
	var flow = root.get_node("GameFlow")
	flow.change_to("station", {}, false)
	await _frames(10)
	while flow.busy:
		await process_frame
	await _frames(20)
	var hud = current_scene.hud
	if case_name == "room":
		hud.open_room(S.CHARACTERS)
		await _frames(10)
		var screen = hud._room_screen
		screen.selected = "hero_cao_bento"
		screen.rebuild()
		await _frames(20)
		var target := screen.find_child("Gear", true, false) as Control
		if target == null:
			target = screen.find_child("Relic", true, false) as Control
		if target != null:
			var scroll: Node = target.get_parent()
			while scroll != null and not scroll is ScrollContainer:
				scroll = scroll.get_parent()
			if scroll != null:
				(scroll as ScrollContainer).ensure_control_visible(target)
		await _frames(10)
		await _shot("20-room")
		_cleanup(campaign)
		return
	hud.open_room(S.FORGE)
	await _frames(20)
	await _reveal(hud, "Gear_armor")
	await _shot("10-forge")
	var button := hud.find_child("Upgrade_weapon", true, false) as Button
	if button != null and not button.disabled:
		button.pressed.emit()
		await _frames(20)
		await _reveal(hud, "Gear_armor")
		await _shot("11-forge-done")
	_cleanup(campaign)


func _cleanup(campaign) -> void:
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


## Rola o painel até a peça (antes da #262, até o fim da Forja).
func _reveal(hud, name: String) -> void:
	var target := hud.find_child(name, true, false) as Control
	if target == null:
		target = hud.find_child("Workers", true, false) as Control
	if target == null:
		return
	var scroll: Node = target.get_parent()
	while scroll != null and not scroll is ScrollContainer:
		scroll = scroll.get_parent()
	if scroll != null:
		(scroll as ScrollContainer).ensure_control_visible(target)
	await _frames(10)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
