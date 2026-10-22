## Opções (o conteúdo; quem abre põe num painel): volumes de música, ambiente e efeitos, a velocidade da batalha e os
## efeitos do ambiente (na campanha, FAHCampaignSettings), a qualidade gráfica, a tela cheia e o vsync (nesta máquina,
## Settings) e os controles. Tudo vale na hora; os volumes salvam a campanha ao soltar o controle.
class_name AHOptionsPanel
extends VBoxContainer

signal closed
## Na Estação, Opções também leva à Nova campanha (que saiu do menu dos cômodos).
signal new_campaign_requested

const H = preload("res://scripts/ui/combat_hud.gd")
## As ações do jogo e o nome delas na tela (as de teste ficam de fora).
const CONTROLS := [["move_left", "Andar para a esquerda"], ["move_right", "Andar para a direita"], ["move_back", "Para o fundo"],
	["move_front", "Para a frente"], ["run", "Correr"], ["interact", "Interagir"], ["inventory", "Mochila"], ["cancel", "Voltar"], ["menu", "Menu"],
	["combat_ability_1", "Luta: habilidade 1"], ["combat_ability_2", "Luta: habilidade 2"], ["combat_ability_3", "Luta: habilidade 3"],
	["combat_ability_4", "Luta: habilidade 4"], ["combat_move", "Luta: mover"], ["combat_defend", "Luta: defender"], ["combat_flee", "Luta: fugir"]]

const PAD_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_START: "Start", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "↑", JOY_BUTTON_DPAD_DOWN: "↓", JOY_BUTTON_DPAD_LEFT: "←", JOY_BUTTON_DPAD_RIGHT: "→"}

var width := 600.0
var allow_new_campaign := false
## A ação esperando a tecla nova ("" = nenhuma).
var _waiting := ""


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var settings: Dictionary = Campaign.state.settings
	_title("Opções", 32)
	_section("Som")
	for spec in [["Música", "music_volume"], ["Ambiente", "ambience_volume"], ["Efeitos", "sfx_volume"]]:
		_volume(spec[0], spec[1], float(settings.get(spec[1], 0.6)))

	_section("Gráficos")
	var levels := HBoxContainer.new()
	levels.add_theme_constant_override("separation", 6)
	add_child(levels)
	for i in Settings.LEVEL_NAMES.size():
		var button := _choice(Settings.LEVEL_NAMES[i], i == Settings.level, levels)
		var level := i
		button.pressed.connect(func():
			Settings.set_level(level)
			_rebuild())
	_hint("Qualidade: resolução interna, sombras, oclusão, neblina e quantidade de chuva.")
	if not OS.has_feature("web"):
		_toggle("Tela cheia", Settings.fullscreen, func(on): Settings.set_fullscreen(on))
		_toggle("Sincronia vertical (vsync)", Settings.vsync, func(on): Settings.set_vsync(on))

	_section("Jogo")
	var speeds := HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 6)
	add_child(speeds)
	var label := H.make_label("Velocidade da batalha", 19, H.TEXT)
	label.custom_minimum_size = Vector2(260, 0)
	speeds.add_child(label)
	for speed in [1, 2]:
		var button := _choice("%dx" % speed, int(settings.get("battle_speed", 1)) == speed, speeds)
		var value: int = speed
		button.pressed.connect(func():
			Campaign.state.settings.battle_speed = value
			Campaign.save()
			_rebuild())
	_toggle("Reduzir efeitos do ambiente (relâmpagos e poeira)", bool(settings.get("reduced_environment_effects", false)), func(on):
		Campaign.state.settings.reduced_environment_effects = on
		Campaign.save()
		Settings.changed.emit())

	_toggle("Dicas da primeira vez", Tips.enabled, func(on): Tips.set_enabled(on))
	_toggle("Cores para daltonismo (azul e laranja)", Settings.colorblind, func(on):
		Settings.set_colorblind(on)
		_rebuild())
	var sizes := HBoxContainer.new()
	sizes.add_theme_constant_override("separation", 6)
	add_child(sizes)
	var size_label := H.make_label("Tamanho do texto", 19, H.TEXT)
	size_label.custom_minimum_size = Vector2(260, 0)
	sizes.add_child(size_label)
	for i in Settings.TEXT_SIZES.size():
		var button := _choice(Settings.TEXT_SIZES[i], i == Settings.text_size, sizes)
		var index := i
		button.pressed.connect(func():
			Settings.set_text_size(index)
			_rebuild())
	_hint("O texto novo vale nas telas que abrirem depois (a próxima luta, a volta à Estação).")
	var again := Button.new()
	again.text = "Mostrar as dicas de novo"
	again.custom_minimum_size = Vector2(0, 42)
	H.style_button(again)
	again.pressed.connect(func():
		Tips.reset()
		Tips.set_enabled(true)
		_rebuild())
	add_child(again)

	_section("Controles")
	var touch := HBoxContainer.new()
	touch.add_theme_constant_override("separation", 6)
	add_child(touch)
	var touch_label := H.make_label("Controles de toque", 19, H.TEXT)
	touch_label.custom_minimum_size = Vector2(200, 0)
	touch.add_child(touch_label)
	for i in Settings.TOUCH_MODES.size():
		var button := _choice(Settings.TOUCH_MODES[i], i == Settings.touch_controls, touch)
		button.custom_minimum_size.x = 0
		var mode := i
		button.pressed.connect(func():
			Settings.set_touch_controls(mode)
			_rebuild())
	_hint("Analógico à esquerda para andar (até a borda corre) e Usar à direita; o aviso de interação também aceita toque.")
	_hint("Trocar: clique e aperte a tecla nova (Esc cancela). Se outra ação usava a tecla, as duas trocam.")
	for spec in CONTROLS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name := H.make_label(spec[1], 18, H.TEXT)
		name.custom_minimum_size = Vector2(230, 0)
		row.add_child(name)
		var keys_label := H.make_label(_keys(spec[0]), 18, H.GOLD)
		keys_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keys_label.clip_text = true
		row.add_child(keys_label)
		var change := Button.new()
		change.text = "Aperte uma tecla…" if _waiting == spec[0] else "Trocar"
		change.custom_minimum_size = Vector2(150, 36)
		H.style_button(change)
		if _waiting == spec[0]:
			change.add_theme_color_override("font_color", H.GOLD)
		var action: String = spec[0]
		change.pressed.connect(func():
			_waiting = action
			_rebuild())
		row.add_child(change)
		add_child(row)
	var defaults := Button.new()
	defaults.text = "Restaurar as teclas padrão"
	defaults.custom_minimum_size = Vector2(0, 40)
	H.style_button(defaults)
	defaults.pressed.connect(func():
		Settings.reset_keys()
		_rebuild())
	add_child(defaults)
	_hint("Mouse: clique nos botões e nos alvos da luta.")

	if allow_new_campaign:
		_section("Campanha")
		var fresh := Button.new()
		fresh.text = "Nova campanha…"
		fresh.custom_minimum_size = Vector2(0, 44)
		H.style_button(fresh, AHUiStyle.DANGER)
		fresh.pressed.connect(func(): new_campaign_requested.emit())
		add_child(fresh)

	var close := Button.new()
	close.text = "Fechar"
	close.custom_minimum_size = Vector2(0, 50)
	H.style_button(close)
	close.pressed.connect(func(): closed.emit())
	add_child(close)


func _rebuild() -> void:
	# Mantém a rolagem (trocar uma tecla lá embaixo não volta o painel para o topo).
	var scroll: ScrollContainer = null
	var node := get_parent()
	while node != null and scroll == null:
		scroll = node as ScrollContainer
		node = node.get_parent()
	var at := scroll.scroll_vertical if scroll else 0
	for child in get_children():
		child.queue_free()
	_ready()
	if scroll:
		scroll.set_deferred("scroll_vertical", at)


func _title(text: String, size: int) -> void:
	add_child(H.make_label(text, size, H.GOLD))


## A explicação em cinza embaixo de uma opção (quebra a linha com o texto maior).
func _hint(text: String) -> void:
	var hint := H.make_label(text, 16, H.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(width - 40, 0)
	add_child(hint)


func _section(text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	add_child(spacer)
	add_child(H.make_label(text, 22, H.GOLD.lightened(0.2)))


func _volume(text: String, key: String, value: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var label := H.make_label(text, 19, H.TEXT)
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = round(value * 100.0)
	slider.custom_minimum_size = Vector2(width - 260, 32)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var number := H.make_label("%d%%" % slider.value, 19, H.MUTED)
	number.custom_minimum_size = Vector2(70, 0)
	row.add_child(number)
	slider.value_changed.connect(func(v):
		Campaign.state.settings[key] = v / 100.0
		number.text = "%d%%" % v
		Sound.apply_volumes())
	slider.drag_ended.connect(func(_changed): Campaign.save())
	# Clique sem arrastar também grava (as setas e o clique na barra não terminam um arrasto).
	slider.focus_exited.connect(func(): Campaign.save())


func _choice(text: String, chosen: bool, parent: Container) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 44)
	H.style_button(button)
	if chosen:
		button.add_theme_color_override("font_color", H.GOLD)
		button.text = "▸ " + text
	parent.add_child(button)
	return button


func _toggle(text: String, on: bool, action: Callable) -> void:
	var check := CheckButton.new()
	check.text = text
	check.button_pressed = on
	check.add_theme_font_size_override("font_size", AHUiStyle.px(19))
	check.add_theme_color_override("font_color", H.TEXT)
	check.toggled.connect(func(value): action.call(value))
	add_child(check)


## Esperando a tecla nova: a primeira tecla apertada vira a principal da ação (Esc cancela).
func _input(event: InputEvent) -> void:
	if _waiting == "" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code != KEY_ESCAPE:
		Settings.set_key(_waiting, code)
	_waiting = ""
	_rebuild()


## As teclas e botões de uma ação, como o InputMap tem (define_input.gd).
func _keys(action: String) -> String:
	var names := PackedStringArray()
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			names.append(OS.get_keycode_string(code))
		elif event is InputEventJoypadButton:
			names.append("Controle " + PAD_NAMES.get(event.button_index, str(event.button_index)))
	return " · ".join(names)
