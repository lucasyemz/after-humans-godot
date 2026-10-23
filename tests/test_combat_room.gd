## A luta cabe no lugar (#52): a fila dos heróis e a dos inimigos ficam inteiras dentro da zona do cenário (ou da sala da
## casa, ou da rua) e fora dos obstáculos que cruzam a linha da luta (escada, caixote), para cada trecho de luta de cada
## mapa, como o corredor a começa (o centro pela patrulha). Num lugar apertado os espaços encolhem, até um mínimo.
extends RefCounted

const MAPS := {"RiverDock": "fase_2", "RootBridge": "fase_2", "SealedShelter": "fase_3", "TriageGate": "fase_4",
	"FloodedDepot": "fase_5", "SewerDucts": "fase_5", "": "fase_1"}
const Arena := preload("res://scripts/combat/combat_arena.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_fit_rules()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-combat-room-%d" % Time.get_ticks_usec()
	var tips: bool = Tips.enabled
	Tips.enabled = false
	for map in MAPS:
		await _map(map)
	Tips.enabled = tips
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state


## A regra sozinha: com espaço fica onde pediu (ou encosta), apertada encolhe, e um obstáculo divide o lugar.
func _fit_rules() -> void:
	var left: float = Arena.FRONT_GAP + 3 * Arena.HERO_GAP
	var right: float = Arena.FRONT_GAP + 3 * Arena.ENEMY_GAP
	t.equal(Arena.fit(10.0, Vector2(0, 30), [], 4, 4), Vector2(10.0, 1.0), "com espaço, a luta fica onde a patrulha está")
	t.equal(Arena.fit(1.0, Vector2(0, 30), [], 4, 4), Vector2(left, 1.0), "perto da ponta, encosta nela sem passar")
	t.equal(Arena.fit(29.0, Vector2(0, 30), [], 4, 4), Vector2(30.0 - right, 1.0), "e do outro lado também")
	var tight := Arena.fit(4.0, Vector2(0, 8), [], 4, 4)
	t.check(tight.y < 1.0 and tight.y >= Arena.MIN_GAP_SCALE and is_equal_approx(tight.x - left * tight.y, 0.0), "num lugar apertado os espaços encolhem (%.2f)" % tight.y)
	var split := Arena.fit(15.0, Vector2(0, 40), [Vector2(10, 12)], 4, 4)
	t.check(split.x - left >= 12.0 - 0.001, "um obstáculo antes do centro: a fila dos heróis fica depois dele (%.2f)" % (split.x - left))
	t.equal(Arena.fit(5.0, Vector2(0, 30), [], 2, 1).x, 5.0, "com menos gente, ocupa menos")


## Cada trecho de luta do mapa: o centro como o corredor faz e as oito posições dentro do lugar e fora dos obstáculos.
func _map(map: String) -> void:
	var c: Dictionary = Campaign.create_initial(7)
	var phase: String = MAPS[map]
	c.completed_phases = ["fase_1", "fase_2", "fase_3", "fase_4"].slice(0, ["fase_1", "fase_2", "fase_3", "fase_4", "fase_5"].find(phase))
	AHStationRules.confirm_departure(c, c.preferred_formation.duplicate(), 0, 20261021, phase, "")
	var route: Dictionary = c.session.expedition.corridor
	var steps: Array = []
	for index in route.steps.size():
		if (route.steps[index].type == "combat" or route.steps[index].type == "boss") and AHJourneyRules.map_for_step(phase, index) == map:
			steps.append(index)
	if steps.is_empty():
		return
	for i in int(steps[0]):
		route.steps[i].resolved = true
	route.index = int(steps[0])
	Campaign.state = c
	GameFlow.change_to("street", {}, false)
	var street = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			street = _tree.current_scene
			break
	var name := map if map != "" else "Rua das Vitrines"
	if not t.check(street != null, "%s abre" % name):
		return
	var outside: Array = []
	var squeezed := 1.0
	for index in steps:
		if not street.corridor.guards.has(index):
			continue
		if street.scenario:
			street.set_scenario_zone(street.corridor.segments[street.corridor._segment_of(index)].zone)
		var at_x: float = street.corridor.guards[index].cards[0].position.x - 1.0
		var room: Dictionary = street.combat_room(at_x)
		var heroes: int = street.party_ids.size()
		var enemies: int = street.corridor.guards[index].cards.size()
		var placed: Vector2 = Arena.fit(at_x, room.bounds, room.obstacles, heroes, enemies)
		squeezed = minf(squeezed, placed.y)
		var xs: Array = []
		for rank in range(1, heroes + 1):
			xs.append(placed.x - (Arena.FRONT_GAP + (rank - 1) * Arena.HERO_GAP) * placed.y)
		for rank in range(1, enemies + 1):
			xs.append(placed.x + (Arena.FRONT_GAP + (rank - 1) * Arena.ENEMY_GAP) * placed.y)
		for x in xs:
			var blocked: bool = room.obstacles.any(func(o): return x > o.x and x < o.y)
			if x < room.bounds.x - 0.001 or x > room.bounds.y + 0.001 or blocked:
				outside.append("trecho %d: x=%.2f em [%.2f, %.2f]%s" % [index, x, room.bounds.x, room.bounds.y, " (obstáculo)" if blocked else ""])
	t.check(outside.is_empty(), "%s: todas as posições da luta dentro do lugar %s" % [name, outside])
	t.check(squeezed >= Arena.MIN_GAP_SCALE, "%s: os espaços encolhem no máximo até %.0f%% (%.0f%%)" % [name, Arena.MIN_GAP_SCALE * 100, squeezed * 100])
