## A prancha das caras (#193): o ícone de cada personagem com arte (os heróis, os recrutas, os inimigos e os moradores),
## como o jogo desenha (AHUiStyle.face_texture no retrato do kit), para conferir as caixas de
## data/presentation/face_boxes.json de uma vez. Roda no código de antes também (o recorte automático).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/face_sheet.gd -- --out=<arquivo.png>
extends SceneTree

const COLUMNS := 8
const SIDE := 150.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out == "":
		push_error("Falta --out=<arquivo.png>.")
		quit(2)
		return
	var style = load("res://scripts/ui/ui_style.gd")
	var kit = load("res://scripts/ui/kit/kit.gd")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/combat_art.json"))
	var civilians: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/civilians.json"))
	var entries: Array = []
	for group in ["heroes", "recruits", "enemies"]:
		for id in manifest.get(group, {}):
			entries.append([id, manifest[group][id].get("idle", {})])
	for id in civilians:
		entries.append([id, civilians[id]])
	var back := ColorRect.new()
	back.color = Color(0.1, 0.1, 0.12)
	back.size = Vector2(1920, 1080)
	root.add_child(back)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.position = Vector2(24, 24)
	grid.add_theme_constant_override("h_separation", 84)
	grid.add_theme_constant_override("v_separation", 12)
	root.add_child(grid)
	for entry in entries:
		var cell := VBoxContainer.new()
		cell.add_child(kit.portrait(style.face_texture(entry[1]), SIDE))
		var label := Label.new()
		label.text = entry[0]
		label.add_theme_font_size_override("font_size", 15)
		cell.add_child(label)
		grid.add_child(cell)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.crop(1920, int(minf(1080.0, grid.position.y + grid.size.y + 24.0)))
	image.save_png(out)
	print("prancha: ", entries.size(), " personagens")
	quit(0)
