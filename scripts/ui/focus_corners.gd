## O foco do teclado e do controle (#25, docs/design/interaction-states.md): quatro cantoneiras claras por fora do
## controle, a 6 px da borda, traço de 3 px e braços de 18 px. Não desloca o conteúdo e não se confunde com a seleção.
class_name AHFocusCorners
extends StyleBox

const GAP := 6.0
const WIDTH := 3.0
const ARM := 18.0

var color := Color("efe5d1")


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var r := rect.grow(GAP)
	var arm := minf(ARM, minf(r.size.x, r.size.y) * 0.5)
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx := 1.0 if corner.x == r.position.x else -1.0
		var sy := 1.0 if corner.y == r.position.y else -1.0
		var horizontal := Rect2(corner.x if sx > 0 else corner.x - arm, corner.y if sy > 0 else corner.y - WIDTH, arm, WIDTH)
		var vertical := Rect2(corner.x if sx > 0 else corner.x - WIDTH, corner.y if sy > 0 else corner.y - arm, WIDTH, arm)
		RenderingServer.canvas_item_add_rect(to_canvas_item, horizontal, color)
		RenderingServer.canvas_item_add_rect(to_canvas_item, vertical, color)
