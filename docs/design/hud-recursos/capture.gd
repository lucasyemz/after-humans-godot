## Fotos do lote A (docs/design/hud-recursos.md): o relatório da volta e a barra do alto da Estação, desenhados pela
## Godot com o código do jogo (AHStationReport e AHStationFrame.top) sobre as capturas limpas da Estação
## (hud-v2/before/station-report_clean.webp e station_clean.webp). A cena 3D da Estação não abre no xvfb sem placa de
## vídeo (o llvmpipe fica parado na montagem), então só a interface é de agora; o fundo é a captura limpa.
##   xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     -s res://docs/design/hud-recursos/capture.gd -- --out=<pasta> [--text-size=2] [--colorblind]
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto. Nada de scripts/, data/ ou tests/ muda.
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var colorblind := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--colorblind":
			colorblind = true
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	var S = load("res://scripts/flow/station_rules.gd")
	var J = load("res://scripts/flow/journey_rules.gd")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	if colorblind:
		root.get_node("Settings").set_colorblind(true)
	# A volta do tools/capture_station_kit.gd: a Rua das Vitrines vencida com o objetivo de água, os cinco recursos.
	var c: Dictionary = campaign.create_initial(17)
	var team: Array = c.roster.slice(0, 4).map(func(h): return h.id)
	J.start_expedition(c, "fase_1", 17)
	var expedition: Dictionary = c.session.expedition
	expedition.team = team
	expedition.focus = S.FOCUS_WATER
	expedition.objective_done = true
	expedition.loot = {"seeds": 14, "scrap": 6, "fragments": 3, "water": 4, "supplies": 2}
	S.hero(c, team[1]).hp = int(S.hero(c, team[1]).max_hp * 0.6)
	S.hero(c, team[2]).hp = int(S.hero(c, team[2]).max_hp * 0.3)
	J.finish_corridor(c)
	c.session.result = "victory"
	S.finish_return(c)
	# Os materiais da barra do alto como as maquetes da #105: 30 sementes, 9 sucatas, 3 fragmentos, 2 curativos.
	c.inventory.seeds = 30
	c.inventory.scrap = 9
	c.inventory.fragments = 3
	c.inventory.bandages = 2
	campaign.state = c
	var layer := CanvasLayer.new()
	root.add_child(layer)
	# 1. O relatório.
	var screen := _backdrop(layer, "res://docs/design/hud-v2/before/station-report_clean.webp")
	var report = load("res://scripts/ui/station/station_report.gd").make(c.station.last_return)
	screen.add_child(report)
	await _frames(30)
	await _shot("report")
	screen.queue_free()
	# 2. A barra do alto da Estação (a vista geral).
	screen = _backdrop(layer, "res://docs/design/hud-v2/before/station_clean.webp")
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(frame)
	load("res://scripts/ui/station/station_frame.gd").top(frame, c, TranslationServer.translate("Vista geral"), func(): pass)
	await _frames(30)
	await _shot("bar")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _backdrop(layer: CanvasLayer, path: String) -> Control:
	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.size = Vector2(1920, 1080)
	layer.add_child(screen)
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	var bg := TextureRect.new()
	bg.texture = ImageTexture.create_from_image(image)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.size = Vector2(1920, 1080)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(bg)
	return screen


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
