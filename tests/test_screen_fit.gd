## As molduras e o foco nas telas (#29): nos três tamanhos de texto, nenhum botão visível sai da tela (o Partir da
## Preparação, as listas da Estação); o foco por cantoneiras não é cortado pelas listas com rolagem (vai para dentro do
## botão); e, na luta, o cartão escolhido mostra a moldura de escolhida enquanto se escolhe o alvo.
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-screen-fit-%d" % Time.get_ticks_usec()
	Campaign.new_game(5)
	Campaign.state.inventory.scrap = 9
	Campaign.state.inventory.fragments = 3
	GameFlow.change_to("station", {}, false)
	if await _settles_on("Station"):
		var hud: AHRefugeHud = _tree.current_scene.hud
		for size in [0, 1, 2]:
			Settings.set_text_size(size)
			await _frames(4)
			_check_screen("vista geral (texto %d)" % size)
			for screen in ["plan", "characters", "forge", "options", S.PREPARATION]:
				if screen == "plan" or screen == "options":
					hud.open_service(screen)
				else:
					hud.open_room(screen)
				await _frames(4)
				_check_screen("%s (texto %d)" % [screen, size])
				hud.close_panel()
				await _frames(2)
			hud.open_map()
			await _frames(4)
			_check_screen("mapa de fases (texto %d)" % size)
			hud._map.visible = false
			await _frames(2)
		Settings.set_text_size(0)
	await _combat_choice()
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state


## Botões e painéis visíveis dentro da tela; cada botão com foco numa lista que recorta desenha as cantoneiras por dentro.
func _check_screen(name: String) -> void:
	var view := Rect2(Vector2.ZERO, Vector2(1920, 1080))
	var off: Array = []
	var cut: Array = []
	var plain: Array = []
	# Os painéis e as listas inteiros na tela (o conteúdo rolável pode passar da vista; a lista não).
	for node in _tree.root.find_children("*", "Control", true, false):
		var box: Control = node
		if (box is PanelContainer or box is ScrollContainer) and box.is_visible_in_tree() and _on_screen_layer(box) and not _in_scroll(box):
			if not view.grow(1).encloses(box.get_global_rect()):
				off.append("%s %s" % [box.get_class(), box.get_global_rect()])
	for node in _tree.root.find_children("*", "BaseButton", true, false):
		var button: BaseButton = node
		if not button.is_visible_in_tree() or not _on_screen_layer(button):
			continue
		# Dentro de uma lista com rolagem, o que está fora da vista é rolável, não cortado.
		if not view.grow(1).encloses(button.get_global_rect()) and not _in_scroll(button):
			off.append(button.text if button is Button else button.name)
		if button.focus_mode == Control.FOCUS_NONE or button.disabled:
			continue
		var style := button.get_theme_stylebox("focus")
		if not style is AHFocusCorners:
			plain.append(button.text if button is Button else button.name)
		else:
			button.grab_focus()
			if AHFocusCorners.clipped(button) and not style.inside:
				cut.append(button.text if button is Button else button.name)
	t.check(off.is_empty(), "%s: nenhum botão fora da tela %s" % [name, off])
	t.check(cut.is_empty(), "%s: foco que a lista cortaria vai para dentro %s" % [name, cut])
	t.check(plain.is_empty(), "%s: todo botão com foco mostra as cantoneiras %s" % [name, plain])


func _in_scroll(control: Control) -> bool:
	var node := control.get_parent()
	while node != null:
		if node is ScrollContainer:
			return true
		node = node.get_parent()
	return false


## Os botões das telas (não os da rua 3D nem os que outra cena deixou para trás).
func _on_screen_layer(control: Control) -> bool:
	return _tree.current_scene != null and _tree.current_scene.is_ancestor_of(control)


func _combat_choice() -> void:
	Campaign.state = Campaign.create_initial(6)
	AHJourneyRules.start_expedition(Campaign.state, "fase_1", 4242)
	GameFlow.change_to("street", {}, false)
	if not await _settles_on("Street"):
		t.check(false, "a rua abre")
		return
	var street = _tree.current_scene
	street.corridor.debug_next_fight()
	await _frames(10)
	var route: Dictionary = Campaign.state.session.expedition.corridor
	if not t.check(street.corridor.guards.has(route.index), "há patrulha para a luta"):
		return
	street.corridor._start_fight(route.index, true)
	var hud: AHCombatHud = street._arena.hud
	for i in 900:
		if hud != null and hud.waiting:
			break
		await _tree.process_frame
	if not t.check(hud.waiting, "a vez do jogador chega"):
		return
	var chosen: Button = null
	for index in hud._options.size():
		var option: Dictionary = hud._options[index]
		if option.usable and not option.self:
			chosen = hud._abilities.get_child(index)
			break
	if not t.check(chosen != null, "há habilidade com alvo"):
		return
	chosen.pressed.emit()
	await _frames(2)
	# A escolhida ganha os cantos âmbar do kit (a camada Selected, selected_slot), por cima do slot.
	var mark: Control = chosen.get_node_or_null("Selected")
	t.check(chosen.disabled and mark != null and mark.visible and String((mark.get_theme_stylebox("panel") as StyleBoxTexture).texture.resource_path).ends_with("selected_slot.webp"),
		"a habilidade escolhida mostra os cantos de escolhida")
	for child in hud._abilities.get_children():
		if child != chosen and child.get_node_or_null("Selected") != null:
			t.check(not child.get_node("Selected").visible, "as outras não")
	street._arena.hud._clear_markers()


func _settles_on(scene_name: String) -> bool:
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == scene_name and frame > 3:
			return true
	return false


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
