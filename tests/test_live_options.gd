## As Opções de acessibilidade valem na hora (#4): trocar o tamanho do texto ou as cores para daltonismo muda as telas
## abertas (Estação, mapa de fases, exploração, luta e Mochila) sem remontá-las nem perder o painel aberto e a seleção.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const U = preload("res://scripts/ui/ui_style.gd")


func run(t) -> void:
	_retune(t)
	var tree: SceneTree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-live-options-%d" % Time.get_ticks_usec()
	Campaign.state = Campaign.create_initial(31)
	await _station(t, tree)
	await _street(t, tree)
	Settings.set_text_size(0)
	Settings.set_colorblind(false)
	if tree.current_scene != null:
		tree.unload_current_scene()
	await tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state


## Um rótulo e um painel montados antes da troca acompanham os três tamanhos e as cores, ida e volta.
func _retune(t) -> void:
	var tree: SceneTree = Engine.get_main_loop()
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", U.panel(0.9, Color(U.DANGER, 0.6)))
	var good := U.label("bom", 20, U.OK)
	var bad := U.label("ruim", 17, U.DANGER)
	box.add_child(good)
	box.add_child(bad)
	tree.root.add_child(box)
	for size in [1, 2, 0, 2, 0]:
		Settings.set_text_size(size)
		t.equal([good.get_theme_font_size("font_size"), bad.get_theme_font_size("font_size")],
			[U.px(20), U.px(17)], "texto %s: o rótulo já aberto muda na hora" % Settings.TEXT_SIZES[size])
	Settings.set_colorblind(true)
	t.equal(good.get_theme_color("font_color"), U.OK, "daltonismo: o verde do rótulo aberto vira azul")
	t.equal(bad.get_theme_color("font_color"), U.DANGER, "daltonismo: o vermelho vira laranja")
	var border: Color = (box.get_theme_stylebox("panel") as StyleBoxFlat).border_color
	t.check(U._same_rgb(border, U.DANGER) and is_equal_approx(border.a, 0.6), "o filete do painel troca de cor e fica com a transparência")
	Settings.set_colorblind(false)
	t.equal(good.get_theme_color("font_color"), Color("86c98f"), "sem daltonismo: volta o verde")
	box.free()


func _wait_scene(tree: SceneTree, check: Callable) -> bool:
	for frame in 600:
		await tree.process_frame
		if not GameFlow.busy and tree.current_scene != null and check.call(tree.current_scene):
			await tree.process_frame
			return true
	return false


## Na Estação, com o Plano aberto: o texto do painel cresce, o painel continua aberto e o mapa de fases acompanha.
func _station(t, tree: SceneTree) -> void:
	GameFlow.change_to("station", {}, false)
	if not t.check(await _wait_scene(tree, func(s): return s is AHStation and s.hud != null), "a Estação abriu"):
		return
	var hud: AHRefugeHud = tree.current_scene.hud
	hud.open_service("plan")
	await tree.process_frame
	var title := _first_label(hud._body)
	var before := title.get_theme_font_size("font_size") if title else 0
	var children := hud._body.get_child_count()
	Settings.set_text_size(2)
	await tree.process_frame
	t.equal(hud.current, "plan", "o Plano continua aberto depois da troca")
	await tree.process_frame
	t.equal(hud._body.get_child_count(), children, "o painel refeito tem o mesmo conteúdo")
	var grown := _first_label(hud._body)
	t.check(grown != null and grown.get_theme_font_size("font_size") > before, "o texto do painel aberto cresceu (%d → %d)" % [before, grown.get_theme_font_size("font_size") if grown else 0])
	t.check(hud._resources.position.x + hud._resources.size.x <= 1889.0, "a barra do alto continua dentro da tela")
	# Na plaqueta, o nome da tela fica embaixo de "ESTAÇÃO RAIZ" (as linhas se encostam de propósito, -4).
	var title_rect: Rect2 = hud._title.get_global_rect()
	t.check(hud._subtitle.get_global_rect().position.y >= title_rect.position.y + title_rect.size.y * 0.7,
		"o subtítulo continua embaixo do título (%.0f, título até %.0f)" % [hud._subtitle.get_global_rect().position.y, title_rect.end.y])
	await tree.process_frame
	t.equal(hud.current, "plan", "o Plano continua aberto depois de refeito com o texto novo")
	# Daltonismo na Estação (o alerta da Comida aparece numa campanha nova): não sobra verde nem vermelho antigo.
	var old_ok: Color = U.OK
	var old_danger: Color = U.DANGER
	Settings.set_colorblind(true)
	await tree.process_frame
	await tree.process_frame
	t.equal(_old_colors(hud, old_ok, old_danger), [], "daltonismo: nenhuma cor antiga na Estação")
	Settings.set_colorblind(false)
	hud.open_map()
	await tree.process_frame
	Settings.set_text_size(0)
	await tree.process_frame
	t.check(hud._map.visible, "o mapa de fases continua aberto")
	await tree.process_frame
	t.check(hud._map._header.get_global_rect().end.x <= hud._map.get_node("Plaque").get_global_rect().end.x + 1.0, "o cabeçalho cabe na plaqueta")
	# O mapa aberto no Normal e trocado para o Maior com ele na tela.
	hud._map.visible = false
	hud.open_map()
	await tree.process_frame
	Settings.set_text_size(2)
	await tree.process_frame
	await tree.process_frame
	var tight := 0
	for region in hud._map._regions:
		var id: String = region.phase_id if region.phase_id != null else "refuge"
		var button: Control = hud._map._labels.get_node_or_null("Place_%s" % id)
		if button == null:
			tight += 1
			continue
		var center_x: float = button.position.x + button.size.x * 0.5
		if button.size.x + 0.5 < button.get_combined_minimum_size().x or absf(center_x - float(region.anchor[0])) > 1.0:
			tight += 1
	t.equal(tight, 0, "mapa no texto Maior: cada rótulo fica centrado no lugar e cabe no próprio botão")
	Settings.set_text_size(0)


## Na rua e na luta: o HUD da exploração e o da luta mudam na hora; a luta continua esperando o mesmo herói.
func _street(t, tree: SceneTree) -> void:
	var c: Dictionary = Campaign.state
	t.equal(S.confirm_departure(c, c.preferred_formation.duplicate(), 0, 9090, "fase_1"), "", "parte")
	GameFlow.change_to("street", {}, false)
	if not t.check(await _wait_scene(tree, func(s): return s.get("corridor") != null), "a rua abriu"):
		return
	var street = tree.current_scene
	var hud: AHExplorationHud = street.exploration_hud
	var label := _first_label(hud)
	var before := label.get_theme_font_size("font_size")
	Settings.set_text_size(1)
	t.check(label.get_theme_font_size("font_size") > before, "o HUD da exploração cresce na hora")
	# A luta abre no tamanho Normal (as cartas montadas nele) e troca na hora.
	Settings.set_text_size(0)
	street.corridor.debug_next_fight()
	street.corridor._start_fight(c.session.expedition.corridor.index, true)
	var arena: AHCombatArena = street._arena
	for frame in 600:
		if arena.hud.waiting:
			break
		await tree.process_frame
	if not t.check(arena.hud.waiting, "a luta pede o comando"):
		return
	var actor: String = arena.hud._actor_id
	var plate_label := _first_label(arena.hud._unit_bars.values()[0])
	var plate_before := plate_label.get_theme_font_size("font_size")
	arena.hud._on_action("item")
	await tree.process_frame
	var bag_focus: Control = arena.hud._bag.find_children("*", "Button", true, false)[0]
	bag_focus.grab_focus()
	Settings.set_text_size(2)
	Settings.set_colorblind(true)
	for frame in 4:
		await tree.process_frame
	var owner := tree.root.gui_get_focus_owner()
	t.check(owner != null and arena.hud._bag != null and arena.hud._bag.is_ancestor_of(owner),
		"com a Mochila aberta, a troca não tira o foco dela (o Enter não escolhe uma carta por trás)")
	t.equal(arena.hud._choosing, "", "e nenhuma habilidade fica escolhida")
	t.check(plate_label.get_theme_font_size("font_size") > plate_before, "as fichas da luta crescem na hora")
	t.check(arena.hud.waiting and arena.hud._actor_id == actor, "a luta continua esperando o mesmo herói")
	t.check(arena.hud._bag != null, "a Mochila aberta continua aberta")
	t.check(arena.hud._panel.position.y + arena.hud._panel.size.y <= 1057.0, "o painel de baixo cabe na tela com o texto Maior")
	arena.hud._close_bag()
	Settings.set_text_size(0)
	await tree.process_frame
	Settings.set_text_size(2)
	await tree.process_frame
	await tree.process_frame
	var overflow := 0
	for card in arena.hud._abilities.get_children():
		if card.is_queued_for_deletion() or card.get_child_count() == 0:
			continue
		if card.size.y + 0.5 < (card.get_child(0) as Control).get_combined_minimum_size().y:
			overflow += 1
	t.equal(overflow, 0, "luta no texto Maior: o conteúdo de cada carta de habilidade cabe nela")
	t.check(arena.hud.waiting and arena.hud._actor_id == actor, "e a luta continua esperando o mesmo herói")
	var ok_cb: Color = U.OK
	var danger_cb: Color = U.DANGER
	Settings.set_colorblind(false)
	await tree.process_frame
	await tree.process_frame
	t.equal(_old_colors(arena.hud, ok_cb, danger_cb), [], "sem daltonismo de novo: nenhuma cor do modo daltonismo sobra na luta")


## Os nós visíveis que ainda têm o verde ou o vermelho de antes da troca (texto, painel, ícone, retângulo).
func _old_colors(root: Node, ok: Color, danger: Color) -> Array:
	var found: Array = []
	var same := func(c: Color) -> bool: return U._same_rgb(c, ok) or U._same_rgb(c, danger)
	for node in root.find_children("*", "CanvasItem", true, false):
		if not node.is_visible_in_tree() or node.is_queued_for_deletion():
			continue
		var bad: bool = same.call(node.modulate) or same.call(node.self_modulate)
		if node is Control:
			for name in ["font_color"]:
				bad = bad or (node.has_theme_color_override(name) and same.call(node.get_theme_color(name)))
			for name in ["panel", "normal", "fill"]:
				if node.has_theme_stylebox_override(name) and node.get_theme_stylebox(name) is StyleBoxFlat:
					var box: StyleBoxFlat = node.get_theme_stylebox(name)
					bad = bad or same.call(box.bg_color) or same.call(box.border_color)
			if node is ColorRect:
				bad = bad or same.call(node.color)
		if bad:
			found.append(str(node.name))
	return found


func _first_label(root: Node) -> Label:
	for node in root.find_children("*", "Label", true, false):
		if node.has_theme_font_size_override("font_size") and node.text != "":
			return node
	return null
