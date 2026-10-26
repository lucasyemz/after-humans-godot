## A pílula de estado do kit (#60): status_pill tingida com o ícone e o rótulo do estado de vida (AHKit.health_state:
## Em forma, Ferimento leve, Ferimento grave). No daltonismo, a cor muda e o ícone também diz o estado (restyle).
class_name AHKitPill
extends PanelContainer

var hp := 0
var max_hp := 1
var _icon: TextureRect
var _label: Label


static func make(life: int, top: int) -> AHKitPill:
	var pill := AHKitPill.new()
	pill.hp = life
	pill.max_hp = maxi(1, top)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pill


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = AHKit.glyph("state_active", AHKit.size("small") + 4)
	row.add_child(_icon)
	_label = AHKit.label("", "text", Color("101214"), true)
	_label.remove_theme_constant_override("outline_size")
	row.add_child(_label)
	restyle()


func restyle() -> void:
	var state := AHKit.health_state(hp, max_hp)
	var box := AHKit.style("status_pill", state.color)
	# O ícone fica dentro da pílula: o recuo da esquerda do manifesto (36) já reserva o lugar dele.
	box.content_margin_left = 10
	add_theme_stylebox_override("panel", box)
	if _icon != null:
		_icon.texture = AHKit.icon(state.icon)
		# O texto claro no verde e no vermelho; escuro no âmbar (e no amarelo do daltonismo), como no alvo.
		var ink := Color("101214") if state.id == "light" else AHKit.TEXT
		_icon.modulate = ink
		_label.add_theme_color_override("font_color", ink)
		_label.text = TranslationServer.translate(state.label)
		set_meta("state", state.id)
