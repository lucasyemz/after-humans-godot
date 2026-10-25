## A tecla do kit (#60): a aba key_tab com o nome da tecla de uma ação (AHUiStyle.key_name, com as trocas das Opções)
## ou um texto fixo ("E / A"). Acompanha a troca de tecla (refresh_keys procura o meta ah_action num PanelContainer
## com um Label).
class_name AHKitKey
extends PanelContainer

var action := ""


static func make(action_name: String, text: String = "", piece: String = "key_tab") -> AHKitKey:
	var key := AHKitKey.new()
	key.action = action_name
	key.add_theme_stylebox_override("panel", AHKit.style(piece))
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var size: Array = AHKit.entry(piece).get("size", [42, 42])
	key.custom_minimum_size = Vector2(size[0], size[1]) if piece == "key_tab" else Vector2(0, size[1])
	var shown := text if text != "" else AHUiStyle.key_name(action_name)
	var label := AHKit.label(shown, "key", AHKit.TEXT, true, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.add_child(label)
	if action_name != "" and text == "":
		key.set_meta("ah_action", action_name)
	return key
