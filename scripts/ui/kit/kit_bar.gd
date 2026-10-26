## A Barra do kit (#60; AHKit.bar): a calha main_bar e o preenchimento bar_fill tingido, com o valor por dentro. kind diz a cor: "hero" (vida dos heróis), "enemy" (vida das
## máquinas), "xp" (violeta), "instinct" (ferrugem, decisão do Lucas), "state" (a cor do estado de vida) ou "life" (a
## vida dos heróis nas telas da Estação: ciano, e no vermelho do ferimento grave). As cores
## do daltonismo valem na hora (restyle).
class_name AHKitBar
extends Control

var piece := "main_bar"
var kind := "hero"
## O valor e o máximo redesenham ao mudar (o tween da barra de XP no fim da luta anda por aqui).
var value := 0.0:
	set(v):
		value = v
		queue_redraw()
var max_value := 1.0:
	set(v):
		max_value = maxf(1.0, v)
		queue_redraw()
var text := ""
var text_role := "world"
var _label: Label


static func make(gutter: String, color_kind: String, shown: float, top: float, caption: String = "", role: String = "world") -> AHKitBar:
	var bar := AHKitBar.new()
	bar.piece = gutter
	bar.kind = color_kind
	bar.value = shown
	bar.max_value = maxf(1.0, top)
	bar.text = caption
	bar.text_role = role
	var size: Array = AHKit.entry(gutter).get("size", [200, 44])
	bar.custom_minimum_size = Vector2(0, size[1])
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _ready() -> void:
	_label = AHKit.label(text, text_role, AHKit.TEXT, true)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_label)
	_label.visible = text != ""


func set_value(shown: float, top: float, caption: String = "") -> void:
	value = shown
	max_value = maxf(1.0, top)
	text = caption
	if _label != null:
		_label.text = caption
		_label.visible = caption != ""
	queue_redraw()


func fill_color() -> Color:
	match kind:
		"enemy":
			return AHKit.enemy_hp()
		"xp":
			return AHKit.XP
		"instinct":
			return AHKit.INSTINCT
		"state":
			return AHKit.health_state(int(value), int(max_value)).color
		"life":
			var state := AHKit.health_state(int(value), int(max_value))
			return state.color if state.id == "heavy" else AHKit.hero_hp()
	return AHKit.hero_hp()


## A troca do daltonismo (AHUiStyle.retune chama em quem tem restyle).
func restyle() -> void:
	queue_redraw()


func _draw() -> void:
	var gutter := AHKit.style(piece)
	draw_style_box(gutter, Rect2(Vector2.ZERO, size))
	var inner := Rect2(Vector2(gutter.content_margin_left, gutter.content_margin_top),
		size - Vector2(gutter.content_margin_left + gutter.content_margin_right, gutter.content_margin_top + gutter.content_margin_bottom))
	# O preenchimento: uma faixa no alto da área de conteúdo (as barras do alvo têm o valor embaixo, no aço) ou cheia
	# quando não há texto.
	var band := inner
	if text != "" and piece != "main_bar":
		band = Rect2(inner.position + Vector2(0, 2), Vector2(inner.size.x, maxf(6.0, inner.size.y * 0.32)))
	var share := clampf(value / max_value, 0.0, 1.0)
	if share > 0.0:
		var fill := AHKit.style("bar_fill", fill_color())
		var width := maxf(fill.texture_margin_left + fill.texture_margin_right, band.size.x * share)
		draw_style_box(fill, Rect2(band.position, Vector2(width, band.size.y)))
