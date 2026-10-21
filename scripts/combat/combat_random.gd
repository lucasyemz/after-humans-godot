## Gerador com semente (mulberry32), o mesmo de FAHCombatRandom e da web: com a mesma semente, os mesmos números.
class_name AHCombatRandom
extends RefCounted

const MASK := 0xFFFFFFFF

var state: int
## Quantos números já foram sorteados (o teste de paridade compara).
var draws := 0


func _init(seed_value: int = 1) -> void:
	state = seed_value & MASK


## Multiplicação de 32 bits sem estourar o int de 64 bits do GDScript (como Math.imul).
static func _mul32(a: int, b: int) -> int:
	var low := a * (b & 0xFFFF)
	var high := (a * (b >> 16)) & 0xFFFF
	return (low + (high << 16)) & MASK


## Número em [0, 1).
func next() -> float:
	draws += 1
	state = (state + 0x6D2B79F5) & MASK
	var t := state
	t = _mul32(t ^ (t >> 15), t | 1)
	t = ((t + _mul32(t ^ (t >> 7), t | 61)) & MASK) ^ t
	return float((t ^ (t >> 14)) & MASK) / 4294967296.0
