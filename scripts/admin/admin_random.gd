## O sorteio fixo da barra de Admin (#130): forçar a Superação (0) ou o Colapso (quase 1) numa crise, sem mexer no
## gerador da luta (a semente segue igual depois).
class_name AHAdminRandom
extends AHCombatRandom

var _value := 0.0


func _init(value: float) -> void:
	super(1)
	_value = value


func next() -> float:
	return _value
