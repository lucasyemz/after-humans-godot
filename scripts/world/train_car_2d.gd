## O vagão verde em camadas (#149) desenhado em 2D, para o plano do túnel da passagem (#256): a mesma ordem, as mesmas
## portas e as rodas de AHTrainCar, sem a profundidade (de lado, o interior fica atrás das janelas). Sem a faísca: a
## freada com faísca fica onde dá para ver o trem parar (AHTrainCar, na Estação e no Tutorial).
## A origem é o canto de cima à esquerda do quadro do vagão (1280 × 543 px); `scale` leva para a tela.
class_name AHTrainCar2D
extends Node2D

var _t: Dictionary
var _leaves := {}
var _wheels: Array[Sprite2D] = []
var _angle := 0.0
var _x := 0.0


func _init() -> void:
	name = "TrainCar2D"
	_t = AHTrainCar.contract().train
	_sprite(_t.layers.interior, Vector2.ZERO)
	for leaf_name in _t.leaves:
		var leaf: Dictionary = _t.leaves[leaf_name]
		var node := _sprite(leaf.file, Vector2(leaf.closed_top_left[0], leaf.closed_top_left[1]))
		_leaves[leaf_name] = {"node": node, "home": node.position.x, "offset": float(leaf.open_offset_x)}
	_sprite(_t.layers.body, Vector2.ZERO)
	_sprite(_t.layers.glass, Vector2.ZERO)
	for center in _t.wheel_centers:
		var wheel := _sprite(_t.layers.wheel, Vector2(center[0], center[1]), true)
		_wheels.append(wheel)
	_sprite(_t.layers.bogie, Vector2.ZERO)


## A largura e a altura do quadro do vagão (px, antes da escala).
func canvas() -> Vector2:
	return Vector2(_t.canvas[0], _t.canvas[1])


## A linha do trilho no quadro (px, antes da escala).
func rail_y() -> float:
	return float(_t.rail_y)


## O vagão em x (px na tela): as rodas giram pelo que ele andou (no quadro do vagão, sem a escala).
func drive(x: float) -> void:
	var moved := (x - _x) / maxf(scale.x, 0.001)
	_angle -= moved / float(_t.wheel_radius)
	_x = x
	position.x = x
	for wheel in _wheels:
		wheel.rotation = -_angle


func set_doors(open: float) -> void:
	var eased := clampf(open, 0.0, 1.0)
	eased = eased * eased * (3.0 - 2.0 * eased)
	for leaf_name in _leaves:
		var leaf: Dictionary = _leaves[leaf_name]
		leaf.node.position.x = leaf.home + leaf.offset * eased


func _sprite(file: String, at: Vector2, centered := false) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(file)
	sprite.centered = centered
	sprite.position = at
	add_child(sprite)
	return sprite
