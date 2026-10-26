## A carga recuperada do guardião (#91): seis caixas viradas; o jogador abre uma e as outras se revelam em seguida. A
## escolha é uma só (os botões apagam ao escolher); quem guarda o resultado é AHFightRewards.choose (o corredor chama).
## Mouse, toque, teclado e controle (os botões do modal: setas e Interagir). Com "Reduzir efeitos", a revelação é na
## hora. Usa os tokens do AHUiStyle, para trocar pelo kit da #59/#60.
class_name AHCargoPicker
extends VBoxContainer

const COLUMNS := 3
## O intervalo entre uma caixa revelada e a próxima (s).
const REVEAL_STEP := 0.25

signal chosen(index: int)
signal closed

var boxes: Array = []
var index := -1
var buttons: Array[Button] = []
var continue_button: Button


static func build(cargo_boxes: Array) -> AHCargoPicker:
	var picker := AHCargoPicker.new()
	picker.boxes = cargo_boxes
	return picker


func _ready() -> void:
	name = "CargoPicker"
	add_theme_constant_override("separation", 12)
	add_child(AHKit.label(tr("Carga recuperada"), "panel_title", AHKit.TEXT, true, true))
	var story := AHKit.label(tr("O guardião guardava compartimentos lacrados. Só dá tempo de abrir um antes de a carcaça ceder; o resto, a equipe vê pelas frestas."), "text", AHKit.TEXT)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.custom_minimum_size = Vector2(720, 0)
	add_child(story)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	add_child(grid)
	for i in boxes.size():
		var button := Button.new()
		button.name = "Box%d" % i
		button.custom_minimum_size = Vector2(232, 112)
		button.add_theme_constant_override("icon_max_width", 56)
		button.text = tr("Compartimento %d") % (i + 1)
		button.icon = _icon("item-generic")
		button.expand_icon = false
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		AHKit.style_button(button, AHKit.piece_of("chip", "resource_tile"), Vector4(10, 10, 10, 10))
		button.add_theme_font_override("font", AHKit.font(true))
		button.add_theme_font_size_override("font_size", AHKit.size("text"))
		button.add_theme_color_override("font_color", AHKit.TEXT)
		button.add_theme_color_override("icon_normal_color", AHKit.AMBER)
		button.pressed.connect(_choose.bind(i))
		grid.add_child(button)
		buttons.append(button)
	continue_button = AHStationReport._primary(tr("Continuar"), "", "interact")
	continue_button.icon = null
	continue_button.custom_minimum_size = Vector2(320, 60)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.add_theme_font_size_override("font_size", AHKit.size("row"))
	continue_button.visible = false
	continue_button.pressed.connect(func(): closed.emit())
	add_child(continue_button)
	if not buttons.is_empty():
		buttons[0].grab_focus.call_deferred()


func _choose(chosen_index: int) -> void:
	if index >= 0:
		return
	index = chosen_index
	for button in buttons:
		button.disabled = true
	_reveal(chosen_index, true)
	chosen.emit(chosen_index)
	Sound.play("res://audio/world/find_coins.ogg", 0.6)
	# As outras se revelam uma a uma (na hora, com "Reduzir efeitos").
	var reduced := GameFlow.reduced_effects()
	for i in boxes.size():
		if i == chosen_index:
			continue
		if not reduced and is_inside_tree():
			await get_tree().create_timer(REVEAL_STEP).timeout
		_reveal(i, false)
	continue_button.visible = true
	AHStationReport.fit_key(continue_button, 52.0)
	continue_button.grab_focus()


## Mostra o que a caixa tinha: a escolhida em dourado, as outras apagadas.
func _reveal(i: int, mine: bool) -> void:
	var box: Dictionary = boxes[i]
	var button: Button = buttons[i]
	button.text = AHFightRewards.box_text(box) + ("\n" + tr("(sua)") if mine else "")
	button.icon = _icon(AHFightRewards.icon_of(box))
	button.set_meta("revealed", true)
	if mine:
		# A escolhida: a moldura âmbar da seleção por cima e o texto em âmbar.
		button.add_child(AHKit.selected_overlay())
		button.add_theme_color_override("font_disabled_color", AHKit.AMBER)
		button.add_theme_color_override("icon_disabled_color", AHKit.AMBER)
	else:
		# As outras: legíveis, mas apagadas, no tom apagado sem transparência.
		button.add_theme_color_override("font_disabled_color", AHKit.MUTED)
		button.add_theme_color_override("icon_disabled_color", AHKit.MUTED)


func _icon(icon_name: String) -> Texture2D:
	return AHKit.legacy_icon(icon_name)
