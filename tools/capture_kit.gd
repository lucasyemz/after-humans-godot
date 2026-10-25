## A galeria do kit (#60): as peças e os componentes de scripts/ui/kit/ sobre o aço, para comparar com as pranchas do
## Codex (docs/design/hud-target/piece_comparison.webp e hud-station/pieces_*.webp).
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_kit.gd -- --out=<pasta> [--text-size=2] [--colorblind]
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var size := 0
	var colorblind := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--text-size="):
			size = int(arg.trim_prefix("--text-size="))
		elif arg == "--colorblind":
			colorblind = true
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	# Carregados na hora: com -s, o script compila antes dos autoloads de que o kit depende.
	var Kit = load("res://scripts/ui/kit/kit.gd")
	var Key = load("res://scripts/ui/kit/kit_key.gd")
	var Bar = load("res://scripts/ui/kit/kit_bar.gd")
	var Pill = load("res://scripts/ui/kit/kit_pill.gd")
	var Style = load("res://scripts/ui/ui_style.gd")
	var settings = root.get_node("Settings")
	settings.set_text_size(size)
	settings.colorblind = colorblind
	Style.set_colorblind(colorblind)
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)
	var back := TextureRect.new()
	back.texture = Kit.texture("steel_material")
	back.stretch_mode = TextureRect.STRETCH_TILE
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.modulate = Color(0.55, 0.55, 0.55)
	page.add_child(back)
	var grid := VBoxContainer.new()
	grid.position = Vector2(40, 30)
	grid.add_theme_constant_override("separation", 22)
	page.add_child(grid)
	# Os componentes da Awesomic (o padrão, hud-direction.md): Plaqueta, Abas, Chips.
	var row := _row(grid)
	for spec in [["plaque", Kit.plaque()], ["tab card", Kit.tab("card")], ["chip cost", Kit.chip("cost")], ["chip result", Kit.chip("result")],
			["Codex: target_tab", Kit.panel("target_tab")]]:
		spec[1].add_child(Kit.label(spec[0], "tab", Kit.TEXT, true, true))
		row.add_child(spec[1])
	# Botões nos estados (o segundo de cada um desligado) e Teclas.
	row = _row(grid)
	for kind in ["primary", "secondary", "icon", "chip", "train", "nav", "list"]:
		row.add_child(Kit.button(kind, kind))
	var off = Kit.button("off", "secondary")
	off.disabled = true
	row.add_child(off)
	row.add_child(Key.make("combat_move"))
	row.add_child(Key.make("", "E / A", "button"))
	# Barras.
	row = _row(grid)
	for spec in [["hero", 24, 24, "24/24"], ["enemy", 6, 8, "6/8"], ["life", 8, 23, "8/23"], ["xp", 60, 90, ""], ["instinct", 40, 200, ""], ["state", 8, 24, ""]]:
		var bar = Kit.bar(spec[0], spec[1], spec[2], spec[3])
		bar.custom_minimum_size.x = 220
		row.add_child(bar)
	# Pílulas dos três estados.
	row = _row(grid)
	for hp in [34, 17, 8]:
		row.add_child(Pill.make(hp, 34 if hp == 34 else (23 if hp == 17 else 24)))
	# Painéis e Cartas.
	row = _row(grid)
	for spec in [["card hero", Kit.card("hero"), Vector2(380, 256)], ["panel large", Kit.panel_box("large"), Vector2(420, 260)],
			["panel inset", Kit.panel_box("inset"), Vector2(300, 200)], ["panel band", Kit.panel_box("band"), Vector2(560, 216)]]:
		spec[1].custom_minimum_size = spec[2]
		spec[1].add_child(Kit.label(spec[0], "card_name", Kit.TEXT, true, true))
		row.add_child(spec[1])
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var name := "kit" + ("_large" if size == 2 else "") + ("_colorblind" if colorblind else "")
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
	quit(0)


func _row(parent: Container) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	return row
