## Opções no kit (o conteúdo; quem abre põe num painel; docs/design/hud-estacao.md, "Opções"): volumes de música,
## ambiente e efeitos, a velocidade da batalha e os efeitos do ambiente (na campanha, FAHCampaignSettings), a qualidade
## gráfica, a tela cheia e o vsync (nesta máquina, Settings) e os controles. Tudo vale na hora; os volumes salvam a
## campanha ao soltar o controle. As seções de hoje numa lista que rola, sem abas:
## - os controles deslizantes com o valor em âmbar;
## - liga e desliga com o rótulo "Ligado" ou "Desligado" ao lado (a cor sozinha não basta), a linha inteira é o alvo;
## - as opções em grupo, com a marcada em âmbar e a moldura da escolha.
class_name AHOptionsPanel
extends VBoxContainer

signal closed
## Na Estação, Opções também leva à Nova campanha (que saiu do menu dos cômodos).
signal new_campaign_requested
signal title_requested

## As ações do jogo e o nome delas na tela (as de teste ficam de fora).
const CONTROLS := [["move_left", "Andar para a esquerda"], ["move_right", "Andar para a direita"], ["move_back", "Para o fundo"],
	["move_front", "Para a frente"], ["run", "Correr"], ["interact", "Interagir"], ["inventory", "Mochila"], ["cancel", "Voltar"], ["menu", "Menu"],
	["combat_ability_1", "Luta: habilidade 1"], ["combat_ability_2", "Luta: habilidade 2"], ["combat_ability_3", "Luta: habilidade 3"],
	["combat_ability_4", "Luta: habilidade 4"], ["combat_move", "Luta: mover"], ["combat_defend", "Luta: defender"], ["combat_flee", "Luta: fugir"],
	["combat_examine", "Luta: inspecionar"], ["combat_log", "Luta: registro"], ["hide_hud", "Estação: ocultar a interface"],
	["report_details", "Estação: detalhes do relatório"], ["station_prepare", "Estação: preparar expedição"]]

const PAD_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_START: "Start", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "↑", JOY_BUTTON_DPAD_DOWN: "↓", JOY_BUTTON_DPAD_LEFT: "←", JOY_BUTTON_DPAD_RIGHT: "→",
	JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_STICK: "R3"}

var width := 600.0
var allow_new_campaign := false
## Na Estação: o botão de voltar à tela de título (a campanha já está salva; Continuar volta para ela).
var allow_title := false
## O título "OPÇÕES" no alto (a Estação já tem o do painel).
var show_title := true
## As opções da campanha (volumes, velocidade, efeitos) vão para o save. No título sem campanha começada ficam só na
## memória: mexer nas Opções não cria um save nem regrava um que não abre (#28); a campanha nova leva os valores.
var save_campaign := true
## A ação esperando a tecla nova ("" = nenhuma).
var _waiting := ""


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var settings: Dictionary = Campaign.state.settings
	if show_title:
		add_child(AHKit.label(tr("Opções"), "panel_title", AHKit.TEXT, true, true))
	_section(tr("Som"), "opt_sound")
	for spec in [["Música", "music_volume"], ["Ambiente", "ambience_volume"], ["Efeitos", "sfx_volume"]]:
		_volume(tr(spec[0]), spec[1], float(settings.get(spec[1], 0.6)))

	_section(tr("Gráficos"), "opt_graphics")
	var levels := _group(tr("Qualidade"))
	for i in Settings.LEVEL_NAMES.size():
		var level := i
		_choice(tr(Settings.LEVEL_NAMES[i]), i == Settings.level, levels).pressed.connect(func():
			Settings.set_level(level)
			_rebuild())
	_hint(tr("Qualidade: resolução interna, sombras, oclusão, neblina e quantidade de chuva."))
	if not OS.has_feature("web"):
		_toggle(tr("Tela cheia"), Settings.fullscreen, func(on): Settings.set_fullscreen(on))
		_toggle(tr("Sincronia vertical (vsync)"), Settings.vsync, func(on): Settings.set_vsync(on))

	_section(tr("Jogo"), "nav_characters")
	var speeds := _group(tr("Velocidade da batalha"))
	for speed in [1, 2]:
		var value: int = speed
		_choice("%dx" % speed, int(settings.get("battle_speed", 1)) == speed, speeds).pressed.connect(func():
			Campaign.state.settings.battle_speed = value
			_save()
			_rebuild())
	_toggle(tr("Reduzir efeitos (clima, tremor e clarão)"), bool(settings.get("reduced_environment_effects", false)), func(on):
		Campaign.state.settings.reduced_environment_effects = on
		_save()
		Settings.changed.emit())
	_toggle(tr("Dicas da primeira vez"), Tips.enabled, func(on): Tips.set_enabled(on))
	_toggle(tr("Cores para daltonismo (azul e laranja)"), Settings.colorblind, func(on):
		Settings.set_colorblind(on)
		_rebuild())
	var sizes := _group(tr("Tamanho do texto"))
	for i in Settings.TEXT_SIZES.size():
		var index := i
		_choice(tr(Settings.TEXT_SIZES[i]), i == Settings.text_size, sizes).pressed.connect(func():
			Settings.set_text_size(index)
			_rebuild())
	# O idioma (#35): o português é o padrão; o inglês está em teste (o que falta traduzir fica em português).
	var languages := _group(tr("Idioma"), "opt_language")
	for entry in Settings.LANGUAGES:
		var code: String = entry[0]
		_choice(tr(entry[1]), Settings.language == entry[0], languages).pressed.connect(func():
			Settings.set_language(code)
			_rebuild())
	_wide_button(tr("Mostrar as dicas de novo"), func():
		Tips.reset()
		Tips.set_enabled(true)
		_rebuild())

	_section(tr("Controles"), "opt_controls")
	var touch := _group(tr("Controles de toque"))
	for i in Settings.TOUCH_MODES.size():
		var mode := i
		_choice(tr(Settings.TOUCH_MODES[i]), i == Settings.touch_controls, touch).pressed.connect(func():
			Settings.set_touch_controls(mode)
			_rebuild())
	_hint(tr("Analógico à esquerda para andar (até a borda corre) e Usar à direita; o aviso de interação também aceita toque."))
	_hint(tr("Trocar: clique e aperte a tecla nova (Esc cancela). Se outra ação usava a tecla, as duas trocam."))
	for spec in CONTROLS:
		var row := HBoxContainer.new()
		row.name = "Key_%s" % spec[0]
		row.add_theme_constant_override("separation", 10)
		var name := AHKit.label(tr(spec[1]), "text", AHKit.TEXT)
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name.custom_minimum_size = Vector2(width * 0.4, 0)
		name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name)
		var keys_label := AHKit.label(_keys(spec[0]), "small", AHKit.AMBER, true)
		keys_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keys_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		keys_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		keys_label.clip_text = true
		row.add_child(keys_label)
		var change := AHKit.button(tr("Aperte uma tecla…") if _waiting == spec[0] else tr("Trocar"), "chip")
		_chip_font(change)
		change.custom_minimum_size = Vector2(120, 56)
		if _waiting == spec[0]:
			change.add_theme_color_override("font_color", AHKit.AMBER)
			change.add_child(AHKit.selected_overlay())
		var action: String = spec[0]
		change.pressed.connect(func():
			_waiting = action
			_rebuild())
		row.add_child(change)
		add_child(row)
	_wide_button(tr("Restaurar as teclas padrão"), func():
		Settings.reset_keys()
		_rebuild())
	_hint(tr("Mouse: clique nos botões e nos alvos da luta."))

	if allow_new_campaign or allow_title:
		_section(tr("Campanha"), "station")
	if allow_title:
		_wide_button(tr("Voltar ao título"), func(): title_requested.emit())
	if allow_new_campaign:
		var fresh := _wide_button(tr("Nova campanha…"), func(): new_campaign_requested.emit())
		for state in ["font_color", "font_hover_color", "font_focus_color"]:
			fresh.add_theme_color_override(state, AHKit.alert_text())
	_wide_button(tr("Fechar"), func(): closed.emit())


func _rebuild() -> void:
	# Mantém a rolagem (trocar uma tecla lá embaixo não volta o painel para o topo).
	var scroll: ScrollContainer = null
	var node := get_parent()
	while node != null and scroll == null:
		scroll = node as ScrollContainer
		node = node.get_parent()
	var at := scroll.scroll_vertical if scroll else 0
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_ready()
	if scroll:
		scroll.set_deferred("scroll_vertical", at)


## A explicação em cinza embaixo de uma opção (quebra a linha com o texto maior).
func _hint(text: String) -> void:
	var hint := AHKit.label(text, "small", AHKit.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(width - 20, 0)
	add_child(hint)


## O título de uma seção: o ícone e o nome em âmbar, em caixa alta.
func _section(text: String, icon_name: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var glyph := AHKit.glyph(icon_name, 28, AHKit.AMBER)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	row.add_child(AHKit.label(text, "row", AHKit.AMBER, true, true))


## O controle deslizante do kit: a calha, o preenchimento âmbar, o pegador no valor e o número em âmbar.
func _volume(text: String, key: String, value: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	var label := AHKit.label(text, "text", AHKit.TEXT)
	label.custom_minimum_size = Vector2(width * 0.3, 0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = round(value * 100.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0, 56)
	slider.add_theme_stylebox_override("slider", AHKit.style(AHKit.piece_of("slider", "track")))
	var fill := AHKit.style(AHKit.piece_of("bar", "fill"), AHKit.AMBER)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := AHKit.texture(AHKit.piece_of("slider", "knob"))
	for state in ["grabber", "grabber_highlight", "grabber_disabled"]:
		slider.add_theme_icon_override(state, knob)
	row.add_child(slider)
	var number := AHKit.label("%d%%" % slider.value, "row", AHKit.AMBER, true)
	number.custom_minimum_size = Vector2(76, 0)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(number)
	slider.value_changed.connect(func(v):
		Campaign.state.settings[key] = v / 100.0
		number.text = "%d%%" % v
		Sound.apply_volumes())
	slider.drag_ended.connect(func(_changed): _save())
	# Clique sem arrastar também grava (as setas e o clique na barra não terminam um arrasto).
	slider.focus_exited.connect(func(): _save())


## Um grupo de opções: o nome numa linha e as escolhas embaixo, quebrando a linha quando o texto maior não cabe (#29).
func _group(text: String, icon_name: String = "") -> HFlowContainer:
	var label := AHKit.label(text, "text", AHKit.TEXT)
	add_child(label)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	add_child(flow)
	return flow


func _choice(text: String, chosen: bool, parent: Container) -> Button:
	var button := AHKit.button(text, "chip")
	_chip_font(button)
	button.custom_minimum_size = Vector2(64, 56)
	if chosen:
		for state in ["font_color", "font_hover_color", "font_focus_color"]:
			button.add_theme_color_override(state, AHKit.AMBER)
		button.add_child(AHKit.selected_overlay())
	parent.add_child(button)
	return button


## O texto dos botões pequenos do kit (as opções, Trocar) no tamanho dos rótulos.
static func _chip_font(button: Button) -> void:
	button.add_theme_font_override("font", AHKit.font(true))
	button.add_theme_font_size_override("font_size", AHKit.size("row"))


func _wide_button(text: String, action: Callable) -> Button:
	var button := AHKit.button(text, "secondary")
	button.text = text
	button.custom_minimum_size = Vector2(0, 60)
	button.add_theme_font_size_override("font_size", AHKit.size("row"))
	button.pressed.connect(action)
	add_child(button)
	return button


## Liga e desliga: a linha inteira é o alvo (56 de altura); à direita, "Ligado" ou "Desligado" e o pegador (desligado,
## de aço claro à esquerda; ligado, âmbar à direita).
func _toggle(text: String, on: bool, action: Callable) -> void:
	var button := Button.new()
	button.name = "Toggle"
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 56)
	AHKit.style_as(button, "list", Vector4(-2, 0, 170, 0))
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_font_override("font", AHKit.font(false))
	button.add_theme_font_size_override("font_size", AHKit.size("text"))
	button.set_meta("on", on)
	var state := HBoxContainer.new()
	state.add_theme_constant_override("separation", 12)
	state.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	state.offset_left = -170
	state.offset_right = -6
	state.alignment = BoxContainer.ALIGNMENT_END
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(state)
	var word := AHKit.label(tr("Ligado") if on else tr("Desligado"), "small", AHKit.AMBER if on else AHKit.MUTED, on)
	word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	state.add_child(word)
	var knob := TextureRect.new()
	knob.texture = AHKit.texture(AHKit.piece_of("toggle", "on" if on else "off"))
	knob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	knob.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	knob.custom_minimum_size = Vector2(64, 32)
	knob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state.add_child(knob)
	button.pressed.connect(func():
		action.call(not on)
		if is_inside_tree():
			_rebuild())
	add_child(button)


## Esperando a tecla nova: a primeira tecla apertada vira a principal da ação (Esc cancela). No controle, B (Voltar)
## cancela; com o painel fechado (ou escondido) a espera acaba, sem trocar nada.
func _input(event: InputEvent) -> void:
	if _waiting == "":
		return
	if not is_visible_in_tree():
		_waiting = ""
		return
	if not (event is InputEventKey) and AHUiStyle.is_back(event):
		get_viewport().set_input_as_handled()
		_waiting = ""
		_rebuild()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code != KEY_ESCAPE:
		Settings.set_key(_waiting, code)
	_waiting = ""
	_rebuild()


func _exit_tree() -> void:
	_waiting = ""


## As teclas e botões de uma ação, como o InputMap tem (define_input.gd).
func _keys(action: String) -> String:
	var names := PackedStringArray()
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			names.append(OS.get_keycode_string(code))
		elif event is InputEventJoypadButton:
			names.append(tr("Controle ") + PAD_NAMES.get(event.button_index, str(event.button_index)))
	return " · ".join(names)


func _save() -> void:
	if save_campaign:
		Campaign.save()
