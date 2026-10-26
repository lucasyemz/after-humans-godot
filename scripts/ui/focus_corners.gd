## O foco do teclado e do controle (#25, docs/design/interaction-states.md): quatro cantoneiras claras por fora do
## controle, a 6 px da borda, traço de 3 px e braços de 18 px. Não desloca o conteúdo e não se confunde com a seleção.
class_name AHFocusCorners
extends StyleBox

const GAP := 6.0
const WIDTH := 3.0
const ARM := 18.0

var color := AHKit.TEXT
## Por dentro do controle, quando uma lista com rolagem (ou outro pai que recorta) cortaria as de fora.
var inside := false


## Liga o foco num botão: a cada vez que ele ganha o foco, confere se as cantoneiras de fora caberiam no pai que recorta.
static func attach(button: Control, corners: AHFocusCorners) -> void:
	button.add_theme_stylebox_override("focus", corners)
	if not button.has_meta("ah_focus_corners"):
		button.set_meta("ah_focus_corners", true)
		button.focus_entered.connect(func():
			var style := button.get_theme_stylebox("focus")
			if style is AHFocusCorners:
				style.inside = clipped(button))


## Algum pai recorta o desenho (ScrollContainer, clip_contents) e as cantoneiras de fora sairiam dele?
static func clipped(control: Control) -> bool:
	var outer := control.get_global_rect().grow(GAP + WIDTH)
	var node := control.get_parent()
	while node is Control:
		if (node is ScrollContainer or (node as Control).clip_contents) and not (node as Control).get_global_rect().encloses(outer):
			return true
		node = node.get_parent()
	return false


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var r := rect.grow(-WIDTH - 1.0) if inside else rect.grow(GAP)
	var arm := minf(ARM, minf(r.size.x, r.size.y) * 0.5)
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx := 1.0 if corner.x == r.position.x else -1.0
		var sy := 1.0 if corner.y == r.position.y else -1.0
		var horizontal := Rect2(corner.x if sx > 0 else corner.x - arm, corner.y if sy > 0 else corner.y - WIDTH, arm, WIDTH)
		var vertical := Rect2(corner.x if sx > 0 else corner.x - WIDTH, corner.y if sy > 0 else corner.y - arm, WIDTH, arm)
		RenderingServer.canvas_item_add_rect(to_canvas_item, horizontal, color)
		RenderingServer.canvas_item_add_rect(to_canvas_item, vertical, color)
