## O chão da luta nos cenários (#48): no Depósito Inundado a borda da frente do piso (35 cm) cobria os pés de quem
## luta, porque a câmera da luta é quase reta. Em cada zona dos seis mapas, com a luta inteira dentro da zona e a câmera
## de perto e de longe, nenhuma peça opaca fica entre a câmera e o pé das oito posições; o chão só sobe onde precisa (no
## Depósito) e os outros cenários ficam iguais. (A luta perto da ponta da zona, com posições dentro da parede, é outro
## assunto: o centro da luta não é limitado à zona.)
extends RefCounted

const MAPS := ["RiverDock", "RootBridge", "SealedShelter", "TriageGate", "FloodedDepot", "SewerDucts"]
const World := preload("res://scripts/scenario/scenario_world.gd")
const Street := preload("res://scripts/street/street.gd")
const Arena := preload("res://scripts/combat/combat_arena.gd")


func run(t) -> void:
	for map in MAPS:
		var world: AHScenarioWorld = World.new()
		world.build(map)
		for aspect in [16.0 / 9.0, 4.0 / 3.0, 21.0 / 9.0]:
			var slope: float = Street.combat_slope_for(aspect)
			for zone_index in world.zones.size():
				var zone: Dictionary = world.zones[zone_index]
				var lane: float = (zone.z0 + zone.z1) * 0.5
				var lift: float = world.front_lift(zone_index, lane - 0.3, slope)
				var name := "%s %d (%s, %.2f)" % [map, zone_index, zone.name, aspect]
				if map == "FloodedDepot":
					t.check(lift > 0.1 and lift < 0.4, "%s: o chão da luta sobe (%.2f m)" % [name, lift])
					t.check(not _covered(world, zone, lane, 0.0, aspect).is_empty(), "%s: sem subir, a borda cobre os pés" % name)
				else:
					t.equal(lift, 0.0, "%s: o chão fica onde está" % name)
				var covered := _covered(world, zone, lane, lift, aspect)
				t.check(covered.is_empty(), "%s: os pés das 8 posições aparecem %s" % [name, covered])
		world.free()
	var card := AHSpriteCard.new()
	t.check(card.layers & AHSpriteCard.CHARACTER_LAYER != 0 and card.layers & 1 != 0, "as placas de personagem ficam na camada do preenchimento da luta")
	card.free()


## As posições cobertas (heróis 1-4 e inimigos 1-4) com a câmera da luta a 10, 14, 20 e 30 m (a fórmula da rua).
func _covered(world: AHScenarioWorld, zone: Dictionary, lane: float, lift: float, aspect: float) -> Array:
	var covered: Array = []
	var pitch := deg_to_rad(Street.SCENARIO_PITCH)
	var fov := 2.0 * atan(tan(deg_to_rad(Street.SCENARIO_HALF_FOV)) / aspect)
	var ground: float = zone.y + lift
	# A luta inteira dentro da zona (as salas do Abrigo têm 10 m e a fila de 8 ocupa 9,65 m), no meio da folga.
	var left: float = Arena.FRONT_GAP + 3 * Arena.HERO_GAP
	var right: float = Arena.FRONT_GAP + 3 * Arena.ENEMY_GAP
	var center: float = zone.x0 + left + (zone.x1 - zone.x0 - left - right) * 0.5
	for distance in [10.0, 14.0, 20.0, 30.0]:
		var target := Vector3(center, ground + Street.COMBAT_FEET_LINE * tan(fov * 0.5) * distance / cos(pitch), lane - 1.35)
		var camera := target + Vector3(0, sin(pitch) * distance, cos(pitch) * distance)
		for rank in range(1, 5):
			for side in [["herói", lane - 0.3, -Arena.FRONT_GAP - (rank - 1) * Arena.HERO_GAP],
					["inimigo", lane - 0.55, Arena.FRONT_GAP + (rank - 1) * Arena.ENEMY_GAP]]:
				var foot := Vector3(center + side[2], ground + 0.03, side[1] - 0.03 * rank)
				for box: AABB in world.walls:
					if box.intersects_segment(camera, foot):
						var label := "%s %d a %d m" % [side[0], rank, distance]
						if not covered.has(label):
							covered.append(label)
						break
	return covered
