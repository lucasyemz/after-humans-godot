## GameFlow e input: as cenas registradas existem, a cena inicial é o boot e as ações têm teclado e gamepad.
extends RefCounted


func run(t) -> void:
	t.equal(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/boot.tscn", "cena inicial")
	for scene_id in GameFlow.SCENES:
		t.check(ResourceLoader.exists(GameFlow.scene_path(scene_id)), "cena %s existe" % scene_id)
	t.equal(GameFlow.scene_path("não-existe"), "", "id desconhecido não tem caminho")
	t.check(not await GameFlow.change_to("não-existe"), "change_to recusa id desconhecido")
	t.check(not GameFlow.busy, "a recusa não deixa o GameFlow ocupado")
	_keys(t)
	_text_size(t)

	for action in ["move_left", "move_right", "move_back", "move_front", "run", "interact", "cancel", "menu"]:
		if not t.check(InputMap.has_action(action), "ação %s existe" % action):
			continue
		var events := InputMap.action_get_events(action)
		t.check(events.any(func(e): return e is InputEventKey), "%s tem tecla" % action)
		t.check(events.any(func(e): return e is InputEventJoypadButton or e is InputEventJoypadMotion), "%s tem gamepad" % action)
	for action in ["debug_rain", "debug_time", "debug_post", "debug_colliders"]:
		t.check(InputMap.has_action(action), "ação de teste %s existe" % action)


## Trocar teclas (Opções): a tecla nova vira a principal, as outras continuam, e quem já usava a tecla troca com ela.
## O tamanho do texto passa por todo rótulo das telas e volta ao normal.
func _text_size(t) -> void:
	Settings.set_text_size(2)
	var big := AHUiStyle.label("x", 20)
	t.check(big.get_theme_font_size("font_size") == 26, "texto Maior: 20 vira 26")
	t.check(get_tree_root_theme_size() == 26, "o tema padrão também cresce")
	big.free()
	Settings.set_text_size(0)
	var normal := AHUiStyle.label("x", 20)
	t.check(normal.get_theme_font_size("font_size") == 20, "texto Normal: 20 fica 20")
	normal.free()


func get_tree_root_theme_size() -> int:
	return (Engine.get_main_loop() as SceneTree).root.theme.default_font_size


func _keys(t) -> void:
	Settings.reset_keys()
	var left := Settings.primary_key("move_left")
	var right := Settings.primary_key("move_right")
	Settings.set_key("move_left", KEY_J)
	t.equal(Settings.primary_key("move_left"), KEY_J, "a tecla nova é a principal")
	t.check(InputMap.action_get_events("move_left").size() >= 2, "as outras teclas da ação continuam (a seta)")
	Settings.set_key("move_left", right)
	t.equal([Settings.primary_key("move_left"), Settings.primary_key("move_right")], [right, KEY_J], "a tecla de outra ação troca com a antiga")
	Settings.reset_keys()
	t.equal([Settings.primary_key("move_left"), Settings.primary_key("move_right")], [left, right], "restaurar volta às padrão")
