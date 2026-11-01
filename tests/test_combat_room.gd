## A luta cabe no lugar (#52): as quatro posições dos heróis e as dos inimigos ficam dentro da zona do cenário (ou da
## sala da casa, ou da rua) e fora dos obstáculos que cruzam a linha da luta, para cada trecho de luta de cada mapa
## (o chefe incluído), como o corredor a começa (o centro pela patrulha). Num lugar apertado os espaços encolhem, até um
## mínimo. Hoje nenhum cenário tem obstáculo na linha da luta: quem segura a fila é o limite da zona.
extends RefCounted

const MAPS := {"RiverDock": "fase_2", "RootBridge": "fase_2", "SealedShelter": "fase_3", "TriageGate": "fase_4",
	"FloodedDepot": "fase_5", "SewerDucts": "fase_5", "": "fase_1"}
const Arena := preload("res://scripts/combat/combat_arena.gd")
## A última posição que o jogo alcança (combat_session.move_targets e o Recuar dos inimigos param na 4).
const MAX_RANK := 4

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_fit_rules()
	_hero_spacing()
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


## O espaço entre heróis vizinhos (o escudo do Tatu, #196): só fundadores, qualquer equipe de 1 a 4 e qualquer
## distribuição nas posições (com vazias no meio, depois de Recuar ou de uma morte), ficam na fila de sempre. Redesenhados
## (#225), o Tatu e o Guaxinim cabem na posição e ficam também na fila de sempre. Com um herói mais largo que a posição
## (a medida do Tatu antigo, que fica para um próximo herói largo), os vizinhos ficam a pelo menos as meias larguras mais
## a folga, e a posição 4 nunca passa do que o fit() reservou.
func _hero_spacing() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Arena.ART_MANIFEST))
	var halves := {}
	for hero_id in ["hero_cao_bento", "hero_gato_nick", "hero_sapo_iris", "hero_coruja_vespera", "hero_tatu_5", "hero_rato_6"]:
		var class_id: String = hero_id.split("_")[1]
		var variants := AHStationRules.art_variants(class_id)
		var card := AHSpriteCard.new()
		card.body_height = AHCharacterHeights.find(hero_id)
		card.show_art(Arena.art_entry(manifest.heroes, hero_id, variants[0] if class_id in ["rato", "tatu"] else "").idle)
		halves[hero_id] = Arena.half_width(card)
		card.free()
	# A #225 pede o Tatu com no máximo uns 1,2 m de largura: redesenhado, ele cabe na posição.
	t.check(halves.hero_tatu_5 <= Arena.NARROW_HALF, "o Tatu redesenhado cabe na posição (%.2f m de meia largura)" % halves.hero_tatu_5)
	t.check(halves.hero_rato_6 <= Arena.NARROW_HALF, "e o Guaxinim também (%.2f m)" % halves.hero_rato_6)
	# O herói largo de teste: a meia largura do Tatu antigo (1,48 m de largura, #196).
	halves["hero_largo_7"] = 0.74
	halves["hero_largo_8"] = 0.74
	var arena = Arena.new()
	arena.session = AHCombatSession.new()
	arena.session.state = AHCombat.State.new()
	var founders_same := true
	var wide_ok := true
	var wide_inside := true
	for team in [["hero_cao_bento", "hero_gato_nick", "hero_sapo_iris", "hero_coruja_vespera"],
			["hero_cao_bento", "hero_tatu_5", "hero_rato_6", "hero_gato_nick"], ["hero_tatu_5", "hero_rato_6"],
			["hero_largo_7", "hero_tatu_5", "hero_largo_8", "hero_cao_bento"], ["hero_largo_7", "hero_largo_8"]]:
		# Quem cabe na posição fica na fila de sempre (os fundadores e, depois da #225, o Tatu e o Guaxinim).
		var founders: bool = not team.has("hero_largo_7")
		# Cada subconjunto da equipe em cada jeito de ocupar as posições 1 a 4.
		for mask in range(1, 1 << team.size()):
			var members: Array = []
			for i in team.size():
				if mask & (1 << i):
					members.append(team[i])
			for ranks in _placements(members.size()):
				arena.session.state.player_team.clear()
				arena._half_widths.clear()
				var reserve := 0.0
				var at := {}
				for i in members.size():
					var unit := AHCombat.Unit.new()
					unit.id = members[i]
					unit.is_player = true
					unit.rank = ranks[i]
					arena.session.state.player_team.append(unit)
					arena._half_widths[unit.id] = halves[unit.id]
					reserve += maxf(0.0, halves[unit.id] - Arena.NARROW_HALF) * 2.0
					at[unit.rank] = halves[unit.id]
				for rank in range(1, Arena.RANKS + 1):
					var offset: float = arena.hero_offset(rank)
					if founders and absf(offset - (Arena.FRONT_GAP + (rank - 1) * Arena.HERO_GAP)) > 0.0001:
						founders_same = false
					if rank > 1 and at.has(rank) and at.has(rank - 1):
						wide_ok = wide_ok and offset - arena.hero_offset(rank - 1) >= at[rank] + at[rank - 1] + Arena.WIDE_ROOM - 0.0001
				if arena.hero_offset(Arena.RANKS) > Arena.FRONT_GAP + (Arena.RANKS - 1) * Arena.HERO_GAP + reserve + 0.0001:
					wide_inside = false
	arena.free()
	t.check(founders_same, "quem cabe na posição (os fundadores, o Tatu e o Guaxinim): a fila de sempre em qualquer equipe e posição")
	t.check(wide_ok, "com um herói largo: os vizinhos não se cobrem")
	t.check(wide_inside, "com um herói largo: a posição 4 fica dentro do que o fit() reservou")


## Todos os jeitos de pôr count heróis em posições distintas de 1 a RANKS.
func _placements(count: int) -> Array:
	if count == 0:
		return [[]]
	var out: Array = []
	for rest in _placements(count - 1):
		for rank in range(1, Arena.RANKS + 1):
			if not rest.has(rank):
				out.append(rest + [rank])
	return out


## A regra sozinha: com espaço fica onde pediu (ou encosta), apertada encolhe, e um obstáculo divide o lugar. A fila
## reservada tem sempre as quatro posições de cada lado (quem recua para a vazia, o chefe de duas posições).
func _fit_rules() -> void:
	var left: float = Arena.FRONT_GAP + (Arena.RANKS - 1) * Arena.HERO_GAP
	var right: float = Arena.FRONT_GAP + (Arena.RANKS - 1) * Arena.ENEMY_GAP
	t.equal(Arena.fit(10.0, Vector2(0, 30), []), Vector2(10.0, 1.0), "com espaço, a luta fica onde a patrulha está")
	t.equal(Arena.fit(1.0, Vector2(0, 30), []), Vector2(left, 1.0), "perto da ponta, encosta nela sem passar")
	t.equal(Arena.fit(29.0, Vector2(0, 30), []), Vector2(30.0 - right, 1.0), "e do outro lado também")
	var tight := Arena.fit(4.0, Vector2(0, 8), [])
	t.check(tight.y < 1.0 and tight.y >= Arena.MIN_GAP_SCALE and is_equal_approx(tight.x - left * tight.y, 0.0), "num lugar apertado os espaços encolhem (%.2f)" % tight.y)
	var split := Arena.fit(15.0, Vector2(0, 40), [Vector2(10, 12)])
	t.check(split.x - left >= 12.0 - 0.001, "um obstáculo antes do centro: a fila dos heróis fica depois dele (%.2f)" % (split.x - left))
	# Um vão minúsculo com a patrulha dentro perde para um grande onde a fila cabe (QA da #52).
	var small := Arena.fit(20.0, Vector2(0, 60), [Vector2(17, 18), Vector2(22, 23)])
	t.check(is_equal_approx(small.y, 1.0) and (small.x - left >= 23.0 - 0.001 or small.x + right <= 17.0 + 0.001), "o vão pequeno da patrulha perde para o que cabe a fila (%.2f)" % small.x)
	# A patrulha em cima de um obstáculo: o vão que deixa o centro mais perto.
	var inside := Arena.fit(40.0, Vector2(0, 80), [Vector2(38, 41)])
	t.check(is_equal_approx(inside.x, 41.0 + left), "a patrulha sobre um obstáculo: o lado mais perto (%.2f)" % inside.x)


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
		var placed: Vector2 = Arena.fit(at_x, room.bounds, room.obstacles)
		squeezed = minf(squeezed, placed.y)
		# As posições pelo próprio slot_position da arena, de 1 a 4 dos dois lados (as que o Mover, o Recuar e o
		# chefe de duas posições alcançam), não só as ocupadas.
		var arena: AHCombatArena = street._arena
		arena.center_x = placed.x
		arena.gap_scale = placed.y
		var xs: Array = []
		for side in [true, false]:
			for rank in range(1, MAX_RANK + 1):
				var unit := AHCombat.Unit.new()
				unit.is_player = side
				unit.rank = rank
				xs.append(arena.slot_position(unit).x)
		for x in xs:
			var blocked: bool = room.obstacles.any(func(o): return x > o.x and x < o.y)
			if x < room.bounds.x - 0.001 or x > room.bounds.y + 0.001 or blocked:
				outside.append("trecho %d: x=%.2f em [%.2f, %.2f]%s" % [index, x, room.bounds.x, room.bounds.y, " (obstáculo)" if blocked else ""])
	t.check(outside.is_empty(), "%s: todas as posições da luta dentro do lugar %s" % [name, outside])
	t.check(squeezed >= Arena.MIN_GAP_SCALE, "%s: os espaços encolhem no máximo até %.0f%% (%.0f%%)" % [name, Arena.MIN_GAP_SCALE * 100, squeezed * 100])
