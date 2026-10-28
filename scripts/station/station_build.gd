## A montagem da Estação Raiz, transcrita do AAHShelterStation da Unreal (Source/AfterHumans/Exploration/AHShelter*.cpp):
## a terra e as lajes, a plataforma com a abóbada, a via e o vagão, a passagem secreta, o eixo de escadas, o casco de cada
## cômodo e o mobiliário de cada um. As medidas são as da Unreal (cm, X para a direita, Y para o fundo negativo, Z para
## cima); AHStationBuilder converte. Peças que só existem como .uasset (o metrô Bombardier, a cadeira do bar, o binóculo,
## o kit de química, o sofá 3D, a xícara) ficam de fora ou usam a alternativa que a própria Unreal tinha.
class_name AHStationBuild
extends RefCounted

const STATION_END := 2760.0
const TRACK_END := 2560.0
const PLATFORM_FRONT := -360.0
const STATION_BACK := -1000.0
const BUFFERS_X := 2440.0
const CORE_X0 := 2800.0
const CORE_X1 := 3360.0
const B1_FLOOR := -520.0
const B1_CEILING := -200.0
const B2_FLOOR := -940.0
const B2_CEILING := -620.0
const FORGE_FLOOR := -1040.0
const FINISH := 2.0
const ROOM_BACK := -900.0
const CORRIDOR_BACK := -1120.0
const VAULT_SPRING := 300.0
const VAULT_RISE := 320.0
const DOOR_X := 2200.0
const DOOR_WIDTH := 110.0
const DOOR_HEIGHT := 225.0
## A parede secreta (#203): a largura da peça que desliza (cobre a porta e o batente).
const SECRET_WALL_WIDTH := 160.0
## O Mapa da Rede fixo na parede da plataforma (#203), entre a pilastra (até x 1622) e o caminho da parede falsa (de x
## 1820): o centro, o tamanho (largura, altura) e a altura do pé (cm).
const NETWORK_MAP_X := 1721.0
const NETWORK_MAP_SIZE := Vector2(176, 120)
const NETWORK_MAP_Z := 96.0
const PANEL_SLIDE := 300.0
const LANE_FRONT0 := -400.0
const LANE_FRONT1 := -580.0
const LANE_BACK0 := -760.0
const LANE_BACK1 := -960.0
const FLIGHT_LEFT := 2930.0
const FLIGHT_RIGHT := 3230.0
## Os trilhos e o leito baixam até a altura real de um metrô (a plataforma e as luzes não mudam).
const TRACK_DROP := -31.8462

const WARM := Color(1.0, 0.74, 0.47)
const AMBER := Color(1.0, 0.62, 0.32)
const NEUTRAL := Color(1.0, 0.94, 0.86)
const COOL := Color(0.82, 0.9, 1.0)
const STEEL_TINT := Color(0.62, 0.72, 0.66)
const ROCK_TINT := Color(0.17, 0.15, 0.13)
const PLASTER_TINT := Color(0.78, 0.72, 0.62)
const IVORY_TINT := Color(0.60, 0.58, 0.52)

## Os cômodos (a tabela Rooms da Unreal): id das regras, X, piso e teto, piso, parede, lambri, luz, porta do fundo
## (a borda esquerda do vão de 120 cm) e o forro.
const ROOMS := [
	{"id": "characters", "x0": -40.0, "x1": 760.0, "floor": B1_FLOOR, "ceiling": B1_CEILING, "floor_art": "wood_planks_grey", "wall": "painted_plaster_wall", "wainscot": "", "light": WARM, "door": 120.0, "lining": ""},
	{"id": "canteen", "x0": 1560.0, "x1": STATION_END, "floor": B1_FLOOR, "ceiling": B1_CEILING, "floor_art": "worn_tile_floor", "wall": "painted_plaster_wall", "wainscot": "long_white_tiles", "light": WARM, "door": 1700.0, "lining": ""},
	{"id": "bar", "x0": 760.0, "x1": 1560.0, "floor": B1_FLOOR, "ceiling": B1_CEILING, "floor_art": "wood_planks_grey", "wall": "red_brick_03", "wainscot": "", "light": AMBER, "door": 880.0, "lining": ""},
	{"id": "dormitory", "x0": -1240.0, "x1": -40.0, "floor": B1_FLOOR, "ceiling": B1_CEILING, "floor_art": "wood_planks_grey", "wall": "painted_plaster_wall", "wainscot": "", "light": WARM, "door": -210.0, "lining": ""},
	{"id": "forge", "x0": 1160.0, "x1": 2160.0, "floor": FORGE_FLOOR, "ceiling": B2_CEILING, "floor_art": "DiamondPlate008A", "wall": "CorrugatedSteel009", "wainscot": "Metal021", "light": NEUTRAL, "door": 1280.0, "lining": "MetalPlates006"},
	{"id": "depot", "x0": 560.0, "x1": 1160.0, "floor": B2_FLOOR, "ceiling": B2_CEILING, "floor_art": "concrete_floor_worn_001", "wall": "concrete_wall_008", "wainscot": "", "light": NEUTRAL, "door": 680.0, "lining": ""},
	{"id": "research", "x0": -640.0, "x1": 560.0, "floor": B2_FLOOR, "ceiling": B2_CEILING, "floor_art": "concrete_floor_painted", "wall": "painted_plaster_wall", "wainscot": "long_white_tiles", "light": COOL, "door": 390.0, "lining": ""},
	{"id": "preparation", "x0": 2160.0, "x1": STATION_END, "floor": B2_FLOOR, "ceiling": B2_CEILING, "floor_art": "rubber_tiles", "wall": "concrete_wall_008", "wainscot": "", "light": NEUTRAL, "door": 2280.0, "lining": ""},
	# A Enfermaria (#121), embaixo do Dormitório: o cômodo provisório até a arte do design (#124), no mesmo contrato.
	{"id": "infirmary", "x0": -1240.0, "x1": -640.0, "floor": B2_FLOOR, "ceiling": B2_CEILING, "floor_art": "worn_tile_floor", "wall": "painted_plaster_wall", "wainscot": "long_white_tiles", "light": COOL, "door": -1150.0, "lining": ""},
]

var b: AHStationBuilder
## O que a Estação liga e desliga depois de montada: o mobiliário de cada cômodo (some no nível 0), o estoque por faixa,
## as peças do vagão e a luz de cada sala.
var dressing := {}
var stock: Array = []
var wagon: Array[Node3D] = []
## As folhas do metrô voltadas à plataforma (a folha e o lado em que desliza: -1 ou 1) e o x (m) da porta, por onde o
## candidato desce; sem o modelo, nenhuma folha e o x fica NAN (o vagão de caixas).
var wagon_doors: Array = []
var train_exit_x := NAN
var room_lights := {}
var ember_light: OmniLight3D
var signal_light: OmniLight3D
var signal_glow: MeshInstance3D
## A passagem secreta: a parede falsa sobre a porta (#203; desliza para a esquerda, e os materiais dela andam junto pelo
## slide_offset do station_surface), a alavanca (gira) e a fresta de luz.
var panel: Node3D
var panel_materials: Array = []
var lever: Node3D
var slit: MeshInstance3D
var slit_light: OmniLight3D


func _init(builder: AHStationBuilder) -> void:
	b = builder


func build() -> void:
	_earth()
	_station()
	_track()
	var start := b.mark()
	_wagon()
	wagon = b.generated.slice(start)
	_secret_passage()
	_terminal_details()
	_stair_core()
	for index in ROOMS.size():
		_room_shell(index)
	_canteen()
	_depot()
	_forge()
	_dormitory_bunks()
	var mark := b.mark()
	_dormitory()
	_tag_dressing("dormitory", mark)
	_preparation()
	mark = b.mark()
	_research()
	_tag_dressing("research", mark)
	mark = b.mark()
	_bar()
	_tag_dressing("bar", mark)
	_infirmary()
	_characters_room()
	for index in ROOMS.size():
		if not ["canteen", "depot", "forge", "dormitory", "infirmary"].has(ROOMS[index].id):
			_placeholder_lighting(index)
	_corner_dressing()
	_room_returns()


func _tag_dressing(room_id: String, start: int) -> void:
	if not dressing.has(room_id):
		dressing[room_id] = []
	dressing[room_id].append_array(b.generated.slice(start))


## Faixa do estoque (#65): band 1..4; a peça aparece com o estoque nessa faixa ou acima.
func _tag_stock(start: int, band: int) -> void:
	stock.append([band, b.generated.slice(start)])


## Leva as peças criadas desde start para um pivô em at (metros), mantendo onde estão.
func _pivot(at: Vector3, start: int) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	b.root.add_child(pivot)
	for node in b.generated.slice(start):
		node.reparent(pivot)
	return pivot


static func vault_z(y: float) -> float:
	# Arco de círculo pela flecha: raio a partir da corda de 10 m.
	var half_chord := -STATION_BACK * 0.5
	var radius := (half_chord * half_chord + VAULT_RISE * VAULT_RISE) / (2.0 * VAULT_RISE)
	var center_z := VAULT_SPRING + VAULT_RISE - radius
	var offset := y - STATION_BACK * 0.5
	return center_z + sqrt(maxf(0.0, radius * radius - offset * offset))


static func room(id: String) -> Dictionary:
	for entry in ROOMS:
		if entry.id == id:
			return entry
	return {}


# ---------------------------------------------------------------- atalhos

func S(id: String, floor_z: float = 0.0, damp: float = 0.0, tint: Color = Color.WHITE, roughness: float = 1.0) -> Material:
	return b.surface(id, floor_z, damp, tint, roughness)


func box(a: Vector3, c: Vector3, material: Material, shadow: bool = true) -> MeshInstance3D:
	return b.box(a, c, material, shadow)


# ---------------------------------------------------------------- terra, plataforma e via

func _earth() -> void:
	var rock := S("rough_concrete", 0, 0, ROCK_TINT, 1.1)
	var slab := S("concrete_wall_008", 0, 0, Color(0.78, 0.76, 0.72))
	# Fundo de terra atrás de tudo: os vazios do corte leem como solo, nunca como céu.
	box(Vector3(-4000, -1400, -3000), Vector3(6000, -1360, 2600), rock, false)
	box(Vector3(-4000, -1360, 1100), Vector3(6000, 0, 2600), rock)
	box(Vector3(-4000, -1360, -3000), Vector3(6000, 0, -1500), rock)
	box(Vector3(-4000, -1360, -1500), Vector3(-1800, 0, 1100), rock)
	box(Vector3(3900, -1360, -1500), Vector3(6000, 0, 1100), rock)
	# Lajes contínuas entre os níveis.
	box(Vector3(-1800, CORRIDOR_BACK - 40, B2_CEILING), Vector3(3900, 0, B1_FLOOR - FINISH), slab)
	box(Vector3(-1800, CORRIDOR_BACK - 40, B1_CEILING), Vector3(STATION_END, 0, -140), slab)
	box(Vector3(-1800, CORRIDOR_BACK - 40, -1500), Vector3(3900, 0, FORGE_FLOOR - 30), rock)
	box(Vector3(-1800, CORRIDOR_BACK - 40, FORGE_FLOOR - 30), Vector3(1160, 0, B2_FLOOR - FINISH), rock)
	box(Vector3(2160, CORRIDOR_BACK - 40, FORGE_FLOOR - 30), Vector3(3900, 0, B2_FLOOR - FINISH), rock)
	box(Vector3(1160, CORRIDOR_BACK - 40, FORGE_FLOOR - 30), Vector3(2160, 0, FORGE_FLOOR - FINISH), rock)
	# Rocha nas pontas de cada nível.
	box(Vector3(-1800, CORRIDOR_BACK - 40, B1_FLOOR), Vector3(-1240, 0, B1_CEILING), rock)
	box(Vector3(-1800, CORRIDOR_BACK - 40, B2_FLOOR), Vector3(-1240, 0, B2_CEILING), rock)
	box(Vector3(-1800, -1360, -140), Vector3(-40, 0, 1100), rock)
	box(Vector3(CORE_X1 + 40, -1360, -1500), Vector3(3900, 0, 1100), rock)
	box(Vector3(STATION_END, -1360, 330), Vector3(CORE_X1 + 40, 0, 1100), rock)
	box(Vector3(-40, -1360, VAULT_SPRING + VAULT_RISE + 30), Vector3(STATION_END, 0, 1100), rock)


func _station() -> void:
	var platform := S("anti_slip_concrete", 0, 0, Color(0.92, 0.88, 0.82))
	var edge := S("anti_slip_concrete", 0, 0, Color(1.0, 0.78, 0.22))
	var concrete := S("concrete_wall_008", 0, 0.35)
	var tiles := S("long_white_tiles", 0, 0.45, Color(0.96, 0.92, 0.82))
	var brick := S("red_brick_03", 0, 0, Color(0.78, 0.72, 0.66))
	var steel := S("green_metal_rust", 0, 0, STEEL_TINT, 0.9)
	var plate := S("metal_plate", 0, 0, Color(0.16, 0.3, 0.26))
	# Plataforma e a borda amarela; o leito da via fica 1 m abaixo, na frente.
	box(Vector3(0, STATION_BACK, -100), Vector3(STATION_END, PLATFORM_FRONT, 0), platform)
	box(Vector3(0, PLATFORM_FRONT - 45, 0), Vector3(TRACK_END, PLATFORM_FRONT, 0.6), edge, false)
	box(Vector3(TRACK_END, PLATFORM_FRONT, -140), Vector3(STATION_END, 0, 0), platform)
	# Parede de serviço (fundo): concreto, azulejo até 2,2 m e o vão da porta escondida.
	var door := [b.hole(DOOR_X - DOOR_WIDTH * 0.5, 0, DOOR_X + DOOR_WIDTH * 0.5, DOOR_HEIGHT)]
	b.wall_with_openings(-40, STATION_END, STATION_BACK - 40, STATION_BACK, 0, VAULT_SPRING + 20, door, concrete, true)
	b.wall_with_openings(0, STATION_END, STATION_BACK, STATION_BACK + 2, 0, 220, door, tiles, true)
	box(Vector3(0, STATION_BACK, 220), Vector3(STATION_END, STATION_BACK + 5, 232), steel)
	var x := 400.0
	while x < STATION_END - 100:
		if absf(x - DOOR_X) >= 250:
			box(Vector3(x - 22, STATION_BACK, 0), Vector3(x + 22, STATION_BACK + 26, VAULT_SPRING), concrete)
		x += 400
	# Abóbada de tijolo em segmentos (o corte mostra o arco) e as nervuras sobre as pilastras.
	var segments := 16
	for index in segments:
		var ya := STATION_BACK * index / segments
		var yb := STATION_BACK * (index + 1) / segments
		var a := Vector3(0, ya, vault_z(ya))
		var c := Vector3(0, yb, vault_z(yb))
		var mid := (a + c) * 0.5
		var length := a.distance_to(c) + 4
		var angle := rad_to_deg(atan2(c.z - a.z, c.y - a.y))
		b.beam(Vector3(STATION_END * 0.5 - 20, mid.y, mid.z + 18), Vector3(STATION_END + 40, length, 36), Vector3(0, 0, -angle), brick)
		var rib := 400.0
		while rib < STATION_END - 100:
			b.beam(Vector3(rib, mid.y, mid.z - 6), Vector3(50, length, 14), Vector3(0, 0, -angle), concrete)
			rib += 800
	# Muro de início com a boca do túnel por onde o trem chega.
	b.wall_with_openings(-40, 0, STATION_BACK, 0, -140, VAULT_SPRING + VAULT_RISE, [b.hole(-340, -140, -20, 340)], concrete, false)
	box(Vector3(TRACK_END, PLATFORM_FRONT, -140), Vector3(STATION_END, 0, VAULT_SPRING), concrete)
	box(Vector3(STATION_END, STATION_BACK - 40, -140), Vector3(CORE_X0, 0, VAULT_SPRING + VAULT_RISE), concrete)
	# Placas antigas (texto em 3D, sem letras na arte).
	box(Vector3(560, STATION_BACK + 2, 236), Vector3(1160, STATION_BACK + 7, 286), plate)
	b.sign("ESTAÇÃO RAIZ", Vector3(860, STATION_BACK + 9, 261), 34, Color8(232, 224, 200))
	box(Vector3(1600, STATION_BACK + 2, 240), Vector3(1860, STATION_BACK + 7, 272), plate)
	b.sign("PLATAFORMA 1", Vector3(1730, STATION_BACK + 9, 256), 20, Color8(232, 224, 200))
	for post in [2160.0, 2400.0]:
		box(Vector3(post - 1, -181, 250), Vector3(post + 1, -179, vault_z(-180)), steel, false)
	box(Vector3(2140, -184, 206), Vector3(2420, -178, 252), S("metal_plate", 0, 0, Color(0.55, 0.08, 0.05)))
	b.sign("FIM DA LINHA", Vector3(2280, -176, 229), 26, Color8(245, 238, 222))
	# Bancos, relógio, quadro elétrico e a luz da plataforma (neutra-fria: é a parte de fora).
	_terminal_furniture()
	b.prop("wall_clock", Vector3(1300, STATION_BACK + 3, 248))
	b.prop("utility_box_02", Vector3(2660, STATION_BACK + 24, 0))
	b.prop("korean_fire_extinguisher_01", Vector3(2560, STATION_BACK + 20, 0))
	b.prop("industrial_storage_cart", Vector3(760, -760, 0), 12)
	b.prop("wooden_military_crate", Vector3(160, -900, 0), 4)
	for lamp in [220.0, 520.0, 1320.0, 2040.0]:
		b.hang("hanging_industrial_lamp", Vector3(lamp, -700, vault_z(-700) - 4))
		b.light(Vector3(lamp, -700, vault_z(-700) - 150), 750, 850, COOL, true)
	for lamp in [980.0, 2560.0]:
		b.prop("industrial_wall_lamp", Vector3(lamp, STATION_BACK + 8, 262))
		b.light(Vector3(lamp, STATION_BACK + 40, 250), 180, 380, NEUTRAL, true)


func _terminal_furniture() -> void:
	var wood := S("wood_table_worn", 0, 0, Color(0.44, 0.32, 0.20))
	var iron := S("green_metal_rust", 0, 0, Color(0.24, 0.34, 0.29), 0.95)
	for x in [330.0, 1130.0, 1450.0]:
		# Profundidade do assento e apoios de trás para a câmera oblíqua; a frente é a arte.
		box(Vector3(x - 68, -964, 36), Vector3(x + 68, -921, 40), wood)
		for side in [-65.0, 65.0]:
			box(Vector3(x + side - 3, -967, 0), Vector3(x + side + 3, -961, 36), iron)
		box(Vector3(x - 67, -972, 40), Vector3(x + 67, -967, 85), wood)
		b.card("Terminal_Bench", Vector3(x, -920, 0), 160, 160.0 * 329 / 564)
	b.card("Preparation_Crate", Vector3(1680, -940, 0), 78, 78.0 * 380 / 410)
	b.card("Preparation_Backpack", Vector3(1590, -942, 0), 54, 54.0 * 1240 / 1125)


func _terminal_details() -> void:
	var concrete := S("rough_concrete", 0, 0.05, Color(0.72, 0.7, 0.64))
	var metal := S("metal_plate", 0, 0, Color(0.36, 0.37, 0.35), 0.9)
	var rail_top := S("metal_plate", -66, 0, Color(0.66, 0.64, 0.58), 0.65)
	var cable := S("metal_plate", 0, 0, Color(0.12, 0.14, 0.13))
	# Borda de concreto com espessura e juntas de construção.
	var x := 0.0
	while x < 2560:
		box(Vector3(x + 1, -363, -18), Vector3(minf(x + 79, 2560), -350, 0), concrete)
		x += 80
	for y in [-110.0, -250.0]:
		box(Vector3(-400, y - 3, -65.98 + TRACK_DROP), Vector3(2400, y + 3, -65.8 + TRACK_DROP), rail_top)
	box(Vector3(2450, -318, -73 + TRACK_DROP), Vector3(2470, -42, -64 + TRACK_DROP), metal)
	for column in [400.0, 800.0, 1200.0, 1600.0]:
		box(Vector3(column - 24, -1000, 0), Vector3(column + 24, -970, 14), concrete)
	box(Vector3(0, -996, 0), Vector3(1730, -992, 7), concrete)
	box(Vector3(2440, -996, 0), Vector3(2760, -992, 7), concrete)
	b.cylinder(Vector3(2260, -985, 294), 3, 760, Vector3(90, 0, 0), cable)
	box(Vector3(2626, -993, 276), Vector3(2654, -977, 312), metal)
	b.cylinder(Vector3(2640, -985, 182), 3, 188, Vector3.ZERO, cable)
	b.prop("metal_tool_chest", Vector3(100, -948, 0))
	b.prop("metal_jerrycan_green", Vector3(40, -948, 0), -8)


func _track() -> void:
	var start := b.mark()
	var ballast := S("gravel_floor_02", -100, 0.3, Color(0.72, 0.68, 0.62))
	var bed := S("rough_concrete", -100, 0.5, Color(0.7, 0.68, 0.64))
	var sleeper := S("wood_planks_grey", 0, 0, Color(0.42, 0.34, 0.27))
	var rail := S("metal_plate", 0, 0, Color(0.55, 0.5, 0.46), 0.7)
	var painted := S("green_metal_rust", 0, 0, Color(0.75, 0.16, 0.1), 0.9)
	box(Vector3(-400, PLATFORM_FRONT, -160), Vector3(TRACK_END, 0, -100), bed)
	box(Vector3(-400, -335, -100), Vector3(BUFFERS_X, -25, -92), ballast)
	var x := -360.0
	while x < BUFFERS_X - 20:
		box(Vector3(x - 12, -320, -92), Vector3(x + 12, -40, -84), sleeper)
		x += 65
	for y in [-110.0, -250.0]:
		box(Vector3(-400, y - 7, -84), Vector3(BUFFERS_X - 40, y + 7, -82), rail)
		box(Vector3(-400, y - 1.5, -82), Vector3(BUFFERS_X - 40, y + 1.5, -71), rail)
		box(Vector3(-400, y - 3.5, -71), Vector3(BUFFERS_X - 40, y + 3.5, -66), rail)
	# Batente: bloco de concreto, viga pintada e os dois para-choques.
	box(Vector3(BUFFERS_X + 30, -330, -100), Vector3(TRACK_END, -30, -10), bed)
	box(Vector3(BUFFERS_X, -330, -64), Vector3(BUFFERS_X + 30, -30, -16), painted)
	for y in [-110.0, -250.0]:
		b.cylinder(Vector3(BUFFERS_X - 20, y, -40), 26, 40, Vector3(90, 0, 0), rail)
		b.cylinder(Vector3(BUFFERS_X - 42, y, -40), 40, 6, Vector3(90, 0, 0), painted)
		b.beam(Vector3(BUFFERS_X + 60, y, -55), Vector3(150, 10, 10), Vector3(-25, 0, 0), rail)
	for node in b.generated.slice(start):
		node.position.y += TRACK_DROP * 0.01
	# Lanterna vermelha de fim de linha sobre o batente.
	box(Vector3(BUFFERS_X + 8, -186, -47.8462), Vector3(BUFFERS_X + 22, -174, 30), rail)
	signal_glow = box(Vector3(BUFFERS_X + 4, -192, 30), Vector3(BUFFERS_X + 26, -168, 52), b.emissive(Color(1, 0.08, 0.04), 14), false)
	signal_light = b.light(Vector3(BUFFERS_X - 20, -180, 44), 90, 300, Color(1, 0.15, 0.08), false)


## O metrô Bombardier S Stock (timblewee, CC BY 4.0), exportado da Unreal por tools/unreal_export_metro.py: o corpo no
## LOD2 e as quatro folhas de porta, no mesmo lugar do vagão da Unreal (BuildWagon). Os materiais de cada seção, na ordem
## dos slots da Unreal: a chapa de metal tingida (a cor da pintura ou o tom), e o vidro.
const METRO := "res://art/station/metro/%s.glb"
const METRO_CAR := Vector3(166.0586, -180.0, -97.8462)
const METRO_BODY_SLOTS := ["MetroDark", "MetroCream", "MetroGrey", "MetroRed", "MetroMetal", "MetroGlass", "MetroSeat"]
const METRO_DOOR_SLOTS := ["MetroRed", "MetroDark", "MetroCream", "MetroMetal", "MetroGlass", "MetroGrey"]
const METRO_COLORS := {"MetroDark": Color(0.07, 0.085, 0.075), "MetroCream": Color(0.76, 0.68, 0.55),
	"MetroGrey": Color(0.82, 0.87, 0.88), "MetroRed": Color(0.8, 0.09, 0.04), "MetroMetal": Color(0.3, 0.32, 0.3),
	"MetroSeat": Color(0.12, 0.18, 0.15)}
## As folhas, com o lado em que deslizam (só as da plataforma abrem) e o meio da porta da plataforma (cm, no vagão).
const METRO_DOORS := [["SM_BombardierPlatformLeft", -1.0], ["SM_BombardierPlatformRight", 1.0], ["SM_BombardierFrontLeft", 0.0],
	["SM_BombardierFrontRight", 0.0]]
const METRO_EXIT_X := 505.0
var _metro_paint := {}


func _wagon() -> void:
	if _metro():
		return
	_box_wagon()


func _metro() -> bool:
	var names: Array = ["SM_BombardierBody"] + METRO_DOORS.map(func(door): return door[0])
	for name in names:
		if not ResourceLoader.exists(METRO % name):
			return false
	_metro_piece("SM_BombardierBody", METRO_BODY_SLOTS)
	for door in METRO_DOORS:
		var leaf := _metro_piece(door[0], METRO_DOOR_SLOTS)
		if door[1] != 0.0:
			wagon_doors.append([leaf, door[1]])
	train_exit_x = (METRO_CAR.x + METRO_EXIT_X) * 0.01
	# A luminária do teto do vagão e a luz dela, como na Unreal.
	b.light(Vector3(380, -180, 250), 320, 520, WARM, false)
	box(Vector3(360, -200, 278), Vector3(400, -160, 288), b.emissive(WARM, 8), false)
	return true


func _metro_piece(name: String, slots: Array) -> Node3D:
	var node: Node3D = load(METRO % name).instantiate()
	node.position = AHStationBuilder.vu(METRO_CAR)
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = child
		for index in mesh.mesh.get_surface_count():
			var slot: String = slots[index] if index < slots.size() else "MetroMetal"
			mesh.set_surface_override_material(index, _metro_material(slot))
	b.root.add_child(node)
	b.generated.append(node)
	return node


## A pintura (creme, cinza e vermelho) é cor lisa, como o M_MetroPaint da Unreal; o resto é a chapa de metal tingida.
func _metro_material(slot: String) -> Material:
	if slot == "MetroGlass":
		return b.glass()
	if not ["MetroCream", "MetroGrey", "MetroRed"].has(slot):
		return S("metal_plate", 0, 0, METRO_COLORS[slot], 0.8)
	if not _metro_paint.has(slot):
		var paint := StandardMaterial3D.new()
		paint.albedo_color = METRO_COLORS[slot]
		paint.roughness = 0.45
		paint.metallic = 0.15
		_metro_paint[slot] = paint
	return _metro_paint[slot]


## O vagão em caixas (o que a Unreal monta quando falta o metrô): piso, lateral de trás com janelas, cabeceiras, teto,
## truques e a carga de chegada.
func _box_wagon() -> void:
	var body := S("green_metal_rust", 0, 0, Color(0.55, 0.72, 0.64), 0.95)
	var roof := S("metal_plate", 0, 0, Color(0.42, 0.44, 0.42))
	var floor := S("wood_planks_grey", 10, 0, Color(0.7, 0.6, 0.5))
	var iron := S("metal_plate", 0, 0, Color(0.28, 0.27, 0.26), 0.8)
	var shift := -520.0
	var x0 := 150.0 + shift
	var x1 := 1650.0 + shift
	var back := -318.0
	var front := -42.0
	var base := 10.0
	var top := 290.0
	box(Vector3(x0, back, base - 12), Vector3(x1, front, base), floor)
	box(Vector3(x0 - 10, back - 4, base - 34), Vector3(x1 + 10, front + 4, base - 12), iron)
	var windows: Array = []
	var wx := x0 + 160
	while wx < x1 - 160:
		windows.append(b.hole(wx, 120, wx + 150, 220))
		wx += 240
	b.wall_with_openings(x0, x1, back - 8, back, base, top, windows, body, true)
	for window: Rect2 in windows:
		box(Vector3(window.position.x, back - 5, window.position.y), Vector3(window.end.x, back - 3, window.end.y), b.glass(), false)
	for end in [x0, x1 - 8]:
		box(Vector3(end, back, base), Vector3(end + 8, front, top), body)
	box(Vector3(x0, back, top), Vector3(x1, front, top + 10), roof)
	box(Vector3(x0 + 20, back + 40, top + 10), Vector3(x1 - 20, front - 40, top + 26), roof)
	box(Vector3(x0, front - 6, base), Vector3(x1, front, base + 30), body)
	box(Vector3(x0, front - 6, top - 24), Vector3(x1, front, top), body)
	for bogie in [420.0 + shift, 1380.0 + shift]:
		box(Vector3(bogie - 120, -290, -66), Vector3(bogie + 120, -70, base - 34), iron)
		for wheel in [-70.0, 70.0]:
			for y in [-110.0, -250.0]:
				b.cylinder(Vector3(bogie + wheel, y, -36), 62, 8, Vector3(0, 0, 90), iron)
	box(Vector3(x0 - 40, -195, -40), Vector3(x0, -165, -20), iron)
	b.prop("wooden_crate_02", Vector3(560 + shift, -230, base), 90)
	b.prop("plastic_crate_01", Vector3(760 + shift, -260, base), 6)
	b.prop("plastic_crate_01", Vector3(760 + shift, -260, base + 26), -8)
	b.prop("metal_jerrycan_green", Vector3(900 + shift, -280, base), 80)
	b.prop("cardboard_box_01", Vector3(1120 + shift, -250, base), 30)
	b.prop("wooden_military_crate", Vector3(1360 + shift, -240, base), 92)
	box(Vector3(x0 + 30, back + 8, base + 40), Vector3(x0 + 260, back + 60, base + 48), floor)
	b.light(Vector3(900 + shift, -180, top - 40), 320, 520, WARM, false)
	box(Vector3(880 + shift, -200, top - 12), Vector3(920 + shift, -160, top - 2), b.emissive(WARM, 8), false)


## A porta de manutenção escondida atrás de uma parede falsa (#203): um pedaço da própria parede da plataforma, o mesmo
## azulejo e o mesmo concreto, que a comunidade montou sobre a porta e que desliza num trilho no chão. Fechada, só a
## fresta de luz na borda e a alavanca ao lado a denunciam. O Mapa da Rede fica fixo na parede ao lado.
func _secret_passage() -> void:
	var steel := S("green_metal_rust", 0, 0, STEEL_TINT, 0.9)
	var concrete := S("concrete_wall_008", 0, 0.3, Color(0.85, 0.83, 0.8))
	var floor := S("concrete_floor_worn_001")
	var scuff := S("concrete_floor_worn_001", 0, 0, Color(0.45, 0.42, 0.38))
	var left := DOOR_X - DOOR_WIDTH * 0.5
	var right := DOOR_X + DOOR_WIDTH * 0.5
	for x in [left - 8, right]:
		box(Vector3(x, STATION_BACK - 40, 0), Vector3(x + 8, STATION_BACK + 3, DOOR_HEIGHT + 8), steel)
	box(Vector3(left - 8, STATION_BACK - 40, DOOR_HEIGHT), Vector3(right + 8, STATION_BACK + 3, DOOR_HEIGHT + 10), steel)
	box(Vector3(left - PANEL_SLIDE - 40, STATION_BACK + 6, 0), Vector3(right + 50, STATION_BACK + 12, 2), steel)
	for y in [STATION_BACK + 22, STATION_BACK + 30]:
		box(Vector3(left - PANEL_SLIDE, y, 0), Vector3(right + 30, y + 3, 0.4), scuff, false)
	# A parede falsa, fechada sobre a porta: o azulejo da plataforma até 2,2 m e o concreto acima, sem vão, numa chapa rente à
	# parede (logo à frente do batente). Os materiais são cópias que andam com a peça (sem o azulejo "escorregar" no
	# deslize).
	var tiles := _moving(S("long_white_tiles", 0, 0.45, Color(0.96, 0.92, 0.82)))
	var cover := _moving(S("concrete_wall_008", 0, 0.35))
	var seam := _moving(S("long_white_tiles", 0, 0.45, Color(0.34, 0.31, 0.27)))
	panel_materials = [tiles, cover, seam]
	var panel_start := b.mark()
	var x0 := DOOR_X - SECRET_WALL_WIDTH * 0.5
	var x1 := DOOR_X + SECRET_WALL_WIDTH * 0.5
	box(Vector3(x0, STATION_BACK + 3, 0), Vector3(x1, STATION_BACK + 3.8, 220), tiles)
	# O concreto começa logo acima do azulejo (sem vão) e fica atrás da faixa de aço de 2,2 a 2,32 m, que segue inteira.
	box(Vector3(x0, STATION_BACK + 3, 220), Vector3(x1, STATION_BACK + 4.5, DOOR_HEIGHT + 22), cover)
	# A junta das bordas, uma linha suja de rejunte: fechada quase não se vê; no deslize, mostra a peça andando.
	for edge_x in [x0, x1 - 1.5]:
		box(Vector3(edge_x, STATION_BACK + 3.8, 0), Vector3(edge_x + 1.5, STATION_BACK + 4.2, 220), seam, false)
	panel = _pivot(b.v(DOOR_X, STATION_BACK + 4, 0), panel_start)
	_network_map(NETWORK_MAP_X)
	# Fresta de luz na borda da parede falsa (some quando ela abre) e a alavanca do mecanismo ao lado.
	var edge := DOOR_X + SECRET_WALL_WIDTH * 0.5
	slit = box(Vector3(edge, STATION_BACK + 1, 12), Vector3(edge + 2, STATION_BACK + 6, 214), b.emissive(WARM, 0.6), false)
	slit_light = b.light(Vector3(edge + 12, STATION_BACK + 30, 120), 8, 180, WARM, false)
	b.prop("power_box_01", Vector3(right + 140, STATION_BACK + 6, 92))
	box(Vector3(right + 186, STATION_BACK, 112), Vector3(right + 206, STATION_BACK + 10, 144), steel)
	var lever_start := b.mark()
	b.cylinder(Vector3(right + 196, STATION_BACK + 16, 150), 4, 44, Vector3.ZERO, steel)
	b.cylinder(Vector3(right + 196, STATION_BACK + 16, 174), 9, 9, Vector3.ZERO, S("metal_plate", 0, 0, Color(0.65, 0.12, 0.08)))
	lever = _pivot(b.v(right + 196, STATION_BACK + 12, 128), lever_start)
	# Corredor de serviço escondido atrás da parede, até o topo do eixo de escadas.
	var y0 := STATION_BACK - 40
	var y1 := -1220.0
	box(Vector3(left - 20, y1, -30), Vector3(CORE_X1, y0, 0), floor)
	box(Vector3(left - 20, y1, 240), Vector3(CORE_X1, y0, 270), concrete)
	box(Vector3(left - 20, y1 - 30, 0), Vector3(CORE_X1, y1, 240), concrete)
	box(Vector3(left - 60, y1, 0), Vector3(left - 20, y0, 240), concrete)
	b.light(Vector3(DOOR_X, -1120, 210), 260, 420, WARM, true)
	b.light(Vector3(3000, -1120, 210), 200, 380, WARM, false)


## Uma cópia própria de uma superfície (os mesmos parâmetros), para a peça que se move mexer só no slide_offset dela.
func _moving(source: ShaderMaterial) -> ShaderMaterial:
	var copy := ShaderMaterial.new()
	copy.shader = source.shader
	for uniform in source.shader.get_shader_uniform_list():
		copy.set_shader_parameter(uniform.name, source.get_shader_parameter(uniform.name))
	return copy


## O Mapa da Rede da plataforma (#203: antes na peça que desliza, agora fixo na parede ao lado, sob a placa
## PLATAFORMA 1): a chapa com as três linhas, as estações e a Raiz no fim.
func _network_map(center_x: float) -> void:
	var steel := S("green_metal_rust", 0, 0, STEEL_TINT, 0.9)
	var board := S("metal_plate", 0, 0, Color(0.12, 0.2, 0.18))
	var half := NETWORK_MAP_SIZE.x * 0.5
	var px := center_x
	var py := STATION_BACK + 2
	var z0 := NETWORK_MAP_Z
	var z1 := NETWORK_MAP_Z + NETWORK_MAP_SIZE.y
	box(Vector3(px - half, py, z0), Vector3(px + half, py + 6, z1), board)
	box(Vector3(px - half - 4, py + 6, z0 - 2), Vector3(px + half + 4, py + 10, z0 + 8), steel)
	box(Vector3(px - half - 4, py + 6, z1 - 8), Vector3(px + half + 4, py + 10, z1 + 2), steel)
	for x in [-half - 4, half - 4]:
		box(Vector3(px + x, py + 6, z0 - 2), Vector3(px + x + 8, py + 10, z1 + 2), steel)
	var step := (z1 - z0 - 50) / 4.0
	var lines := [[z0 + step * 3, Color(0.72, 0.2, 0.12)], [z0 + step * 2, Color(0.85, 0.62, 0.15)], [z0 + step, Color(0.2, 0.45, 0.38)]]
	for line in lines:
		var paint := S("metal_plate", 0, 0, line[1], 0.8)
		box(Vector3(px - half + 16, py + 6, line[0] - 2), Vector3(px + half - 32, py + 8, line[0] + 2), paint)
		var station_x := -half + 24
		while station_x < half - 32:
			box(Vector3(px + station_x - 4, py + 7, line[0] - 4), Vector3(px + station_x + 4, py + 9, line[0] + 4), paint)
			station_x += 44
	box(Vector3(px + half - 36, py + 6, z0 + step * 0.6), Vector3(px + half - 27, py + 9, z0 + step * 3.4), S("metal_plate", 0, 0, Color(0.9, 0.86, 0.78)))
	b.sign("MAPA DA REDE", Vector3(px, py + 11, z1 - 26), 18, Color8(232, 224, 200))
	b.sign("RAIZ", Vector3(px + half - 30, py + 11, z0 + step * 3.4 + 12), 11, Color8(232, 224, 200))


func _stair_core() -> void:
	var concrete := S("concrete_wall_008", 0, 0.2, Color(0.88, 0.85, 0.8))
	var steps := S("concrete_floor_worn_001")
	var steel := S("green_metal_rust", 0, 0, STEEL_TINT, 0.9)
	var tiles := S("long_white_tiles", 0, 0.3, Color(0.96, 0.92, 0.82))
	b.wall_with_openings(STATION_END, CORE_X0, STATION_BACK, 0, B2_FLOOR, B2_CEILING, [b.hole(-760, B2_FLOOR, -580, B2_FLOOR + 220)], concrete, false)
	b.wall_with_openings(STATION_END, CORE_X0, STATION_BACK, 0, B1_FLOOR, B1_CEILING, [b.hole(-760, B1_FLOOR, -580, B1_FLOOR + 220)], concrete, false)
	box(Vector3(CORE_X1, STATION_BACK - 40, B2_FLOOR - 30), Vector3(CORE_X1 + 40, 0, 330), concrete)
	b.wall_with_openings(CORE_X0, CORE_X1, STATION_BACK - 40, STATION_BACK, B2_FLOOR, 300, [b.hole(3240, 0, 3350, 230)], concrete, true)
	box(Vector3(CORE_X0, STATION_BACK - 40, 300), Vector3(CORE_X1, 0, 330), concrete)
	var floor := func(x0: float, x1: float, y0: float, y1: float, z: float) -> void:
		box(Vector3(x0, y0, z - 25), Vector3(x1, y1, z), steps)
	floor.call(CORE_X0, CORE_X1, LANE_BACK0, 0, 0)
	floor.call(FLIGHT_RIGHT, CORE_X1, LANE_BACK1, LANE_BACK0, 0)
	floor.call(CORE_X0, FLIGHT_LEFT, LANE_BACK1, LANE_FRONT0, -260)
	floor.call(CORE_X0, CORE_X1, LANE_FRONT1 - 0.1, 0, B1_FLOOR)
	floor.call(CORE_X0, CORE_X1, LANE_BACK0, LANE_FRONT1, B1_FLOOR)
	floor.call(CORE_X0, FLIGHT_LEFT, LANE_BACK1, LANE_BACK0, B1_FLOOR)
	floor.call(FLIGHT_RIGHT, CORE_X1, LANE_BACK1, LANE_BACK0, B1_FLOOR)
	floor.call(CORE_X0, FLIGHT_LEFT, LANE_BACK1, LANE_FRONT0, -740)
	floor.call(CORE_X0, CORE_X1, LANE_BACK1, 0, B2_FLOOR)
	# Lances: degraus maciços com focinho de aço, a laje inclinada por baixo e o corrimão.
	var flight := func(x_from: float, x_to: float, z_from: float, z_to: float, y0: float, y1: float) -> void:
		var risers := maxi(1, roundi(absf(z_to - z_from) / 20.0))
		var rise := (z_to - z_from) / risers
		var run := (x_to - x_from) / risers
		for step in risers:
			var xa := x_from + step * run
			var xb := xa + run
			var top := z_from + (step + 1) * rise
			box(Vector3(minf(xa, xb), y0, top - absf(rise) - 6), Vector3(maxf(xa, xb), y1, top), steps)
			box(Vector3(minf(xa, xb), y0, top - 2), Vector3(minf(xa, xb) + 3, y1, top + 0.5), steel, false)
		var a := Vector3(x_from, (y0 + y1) * 0.5, z_from - 30)
		var c := Vector3(x_to, (y0 + y1) * 0.5, z_to - 30)
		var angle := rad_to_deg(atan2(c.z - a.z, c.x - a.x))
		b.beam((a + c) * 0.5, Vector3(a.distance_to(c), absf(y1 - y0), 18), Vector3(angle, 0, 0), concrete)
		var rail_y := y1 - 4 if y1 > -500 else y0 + 4
		b.beam(Vector3((x_from + x_to) * 0.5, rail_y, (z_from + z_to) * 0.5 + 90), Vector3(a.distance_to(c), 5, 5), Vector3(angle, 0, 0), steel)
	flight.call(FLIGHT_RIGHT, FLIGHT_LEFT, 0, -260, LANE_BACK1, LANE_BACK0)
	flight.call(FLIGHT_LEFT, FLIGHT_RIGHT, -260, B1_FLOOR, LANE_FRONT1, LANE_FRONT0)
	flight.call(FLIGHT_RIGHT, FLIGHT_LEFT, B1_FLOOR, -740, LANE_BACK1, LANE_BACK0)
	flight.call(FLIGHT_LEFT, FLIGHT_RIGHT, -740, B2_FLOOR, LANE_FRONT1, LANE_FRONT0)
	for z in [0.0, B1_FLOOR]:
		box(Vector3(CORE_X0, LANE_BACK0 - 2, z + 96), Vector3(FLIGHT_RIGHT, LANE_BACK0 + 2, z + 100), steel, false)
		var post := CORE_X0 + 40
		while post < FLIGHT_RIGHT:
			box(Vector3(post - 2, LANE_BACK0 - 2, z), Vector3(post + 2, LANE_BACK0 + 2, z + 100), steel, false)
			post += 100
	# Antecâmara: azulejo, placa e luz quente (aqui começa o abrigo).
	box(Vector3(CORE_X1 - 2, LANE_BACK1, 0), Vector3(CORE_X1, 0, 180), tiles)
	box(Vector3(CORE_X0 + 60, STATION_BACK + 2, 200), Vector3(CORE_X0 + 340, STATION_BACK + 7, 240), S("metal_plate", 0, 0, Color(0.16, 0.3, 0.26)))
	b.sign("ABRIGO", Vector3(CORE_X0 + 200, STATION_BACK + 9, 220), 22, Color8(232, 224, 200))
	for landing in [0.0, B1_FLOOR, B2_FLOOR]:
		var fixture := Vector3(CORE_X1 - 60, STATION_BACK + 8, landing + 230)
		b.prop("industrial_wall_lamp", fixture)
		b.light(fixture + Vector3(0, 35, 0), 260, 650, WARM, true)


func _room_shell(index: int) -> void:
	var r: Dictionary = ROOMS[index]
	var bar: bool = r.id == "bar"
	var forge: bool = r.id == "forge"
	var depot: bool = r.id == "depot"
	var floor_tint := Color(0.85, 0.79, 0.69) if bar else Color(0.72, 0.70, 0.65) if depot else Color.WHITE
	var floor := S(r.floor_art, r.floor, 0, floor_tint)
	var plaster: bool = r.wall == "painted_plaster_wall"
	var wall_tint := PLASTER_TINT if plaster else IVORY_TINT if depot else Color(0.85, 0.82, 0.78)
	var wall := S(r.wall, r.floor, 0.25, Color(0.84, 0.80, 0.74) if bar else wall_tint)
	var concrete := S("concrete_wall_008", r.floor, 0.3, Color(0.86, 0.84, 0.8))
	var forge_steel: Material = S(r.wainscot) if forge else null
	var steel := S("green_metal_rust", 0, 0, STEEL_TINT, 0.9)
	box(Vector3(r.x0, ROOM_BACK, r.floor - FINISH), Vector3(r.x1, 0, r.floor), floor)
	if r.lining != "":
		box(Vector3(r.x0 + 15, ROOM_BACK, r.ceiling - 8), Vector3(r.x1 - 15, -3, r.ceiling), S(r.lining), false)
	var back_door := [b.hole(r.door, r.floor, r.door + 120, r.floor + 220)]
	b.wall_with_openings(r.x0, r.x1, ROOM_BACK - 40, ROOM_BACK, r.floor, r.ceiling, back_door, wall, true)
	if r.wainscot != "" and not forge:
		var height := 200.0 if r.id == "canteen" else 150.0
		b.wall_with_openings(r.x0, r.x1, ROOM_BACK, ROOM_BACK + 2, r.floor, r.floor + height, back_door, S(r.wainscot, r.floor, 0, Color(0.97, 0.94, 0.86)), true)
		box(Vector3(r.x0, ROOM_BACK, r.floor + height), Vector3(r.door - 8, ROOM_BACK + 4, r.floor + height + 6), steel)
		box(Vector3(r.door + 128, ROOM_BACK, r.floor + height), Vector3(r.x1, ROOM_BACK + 4, r.floor + height + 6), steel)
	else:
		# O rodapé claro para nos batentes, sem cobrir a base da porta.
		box(Vector3(r.x0, ROOM_BACK, r.floor), Vector3(r.door - 8, ROOM_BACK + 3, r.floor + 12), forge_steel if forge_steel else concrete)
		box(Vector3(r.door + 128, ROOM_BACK, r.floor), Vector3(r.x1, ROOM_BACK + 3, r.floor + 12), forge_steel if forge_steel else concrete)
	var frame := S("green_metal_rust", 0, 0, Color(0.42, 0.46, 0.32), 0.9)
	box(Vector3(r.door - 8, ROOM_BACK - 40, r.floor), Vector3(r.door, ROOM_BACK + 4, r.floor + 228), frame)
	box(Vector3(r.door + 120, ROOM_BACK - 40, r.floor), Vector3(r.door + 128, ROOM_BACK + 4, r.floor + 228), frame)
	box(Vector3(r.door - 8, ROOM_BACK - 40, r.floor + 220), Vector3(r.door + 128, ROOM_BACK + 4, r.floor + 228), frame)
	# A porta pintada aprovada (a mesma nas oito salas), com os batentes que fecham o vão de 120 cm.
	var leaf_height := 220.0
	var leaf_width := leaf_height * 776.0 / 1717.0
	var leaf_left: float = r.door + (120.0 - leaf_width) * 0.5
	box(Vector3(r.door, ROOM_BACK - 4, r.floor), Vector3(leaf_left + 0.5, ROOM_BACK + 2, r.floor + leaf_height), frame, false)
	box(Vector3(leaf_left + leaf_width - 0.5, ROOM_BACK - 4, r.floor), Vector3(r.door + 120, ROOM_BACK + 2, r.floor + leaf_height), frame, false)
	b.card("Door", Vector3(r.door + 60, ROOM_BACK + 3, r.floor), leaf_width, leaf_height)
	var side_holes: Array = []
	if r.id == "canteen":
		side_holes.append(b.hole(-760, r.floor + 95, -600, r.floor + 190))
	b.wall_with_openings(r.x0 - 15, r.x0 + 15, ROOM_BACK - 40, 0, r.floor - 2, r.ceiling, side_holes, concrete, false)
	if r.id == "canteen":
		box(Vector3(r.x0 - 30, -770, r.floor + 90), Vector3(r.x0 + 30, -590, r.floor + 95), S("wood_table_worn", r.floor))
	if forge:
		box(Vector3(r.x1 - 15, ROOM_BACK - 40, FORGE_FLOOR), Vector3(r.x1 + 15, 0, B2_FLOOR), concrete)
	# Bordas do corte: perfil escuro na laje do piso e do teto.
	var cut := S("rough_concrete", 0, 0, Color(0.2, 0.19, 0.18))
	box(Vector3(r.x0, -2, r.floor - 30), Vector3(r.x1, 0.5, r.floor - 2), cut, false)
	box(Vector3(r.x0, -2, r.ceiling), Vector3(r.x1, 0.5, r.ceiling + 30), cut, false)
	# Corredor de serviço atrás e a tubulação ao longo do teto.
	box(Vector3(r.x0, CORRIDOR_BACK, r.floor - FINISH), Vector3(r.x1, ROOM_BACK - 40, r.floor), S("concrete_floor_worn_001", r.floor))
	box(Vector3(r.x0, CORRIDOR_BACK - 40, r.floor), Vector3(r.x1, CORRIDOR_BACK, r.ceiling), concrete)
	b.cylinder(Vector3((r.x0 + r.x1) * 0.5, ROOM_BACK + 30, r.ceiling - 22), 12, r.x1 - r.x0, Vector3(90, 0, 0), steel)
	b.cylinder(Vector3((r.x0 + r.x1) * 0.5, ROOM_BACK + 52, r.ceiling - 18), 8, r.x1 - r.x0, Vector3(90, 0, 0), S("metal_plate", 0, 0, Color(0.55, 0.42, 0.32)))


## Luz das salas sem montagem própria de luz (Alojamento, Bar, Pesquisa, Preparação): o pendente gaiola.
func _placeholder_lighting(index: int) -> void:
	var r: Dictionary = ROOMS[index]
	var center_x: float = (r.x0 + r.x1) * 0.5
	b.hang("caged_hanging_light", Vector3(center_x, -480, r.ceiling))
	room_lights[r.id] = b.light(Vector3(center_x, -480, r.ceiling - 90), 1400, maxf(700.0, (r.x1 - r.x0) * 0.8), r.light, true)
	if r.ceiling - r.floor > 360:
		b.light(Vector3(center_x, -300, r.floor + 180), 500, 600, r.light, false)


# ---------------------------------------------------------------- Cantina

func _canteen() -> void:
	var r := room("canteen")
	var f: float = r.floor
	var steel := S("metal_plate", f, 0, Color(0.78, 0.78, 0.76), 0.55)
	var painted := S("green_metal_rust", f, 0, STEEL_TINT, 0.9)
	var wood := S("wood_table_worn", f, 0, Color(0.9, 0.82, 0.72))
	var cabinet := S("wood_planks_grey", f, 0, Color(0.62, 0.7, 0.66))
	var concrete := S("concrete_floor_worn_001", f, 0, Color(0.92, 0.9, 0.86))
	var copper := S("metal_plate", f, 0, Color(0.72, 0.42, 0.26), 0.6)
	# Refeitório (esquerda) em concreto polido; a cozinha fica com a cerâmica do casco.
	box(Vector3(r.x0 + 15, ROOM_BACK, f), Vector3(2150, 0, f + 0.6), concrete)
	# Bancada da cozinha no fundo: armários com a frente pintada, tampo de aço, pia, fogão, coifa e duto.
	var counter_y := ROOM_BACK + 66
	var top := f + 90
	box(Vector3(2180, ROOM_BACK, f), Vector3(2300, counter_y - 4, top - 4), cabinet)
	box(Vector3(2360, ROOM_BACK, f), Vector3(2740, counter_y - 4, top - 4), cabinet)
	box(Vector3(2180, ROOM_BACK, f), Vector3(2740, counter_y - 10, f + 10), painted)
	for x in [2240.0, 2420.0, 2540.0, 2660.0]:
		b.card("Cantina_Front", Vector3(x, counter_y, f + 14), 120, 68.52)
	box(Vector3(2180, ROOM_BACK, top - 4), Vector3(2300, counter_y + 2, top), steel)
	box(Vector3(2360, ROOM_BACK, top - 4), Vector3(2740, counter_y + 2, top), steel)
	var sink := 2560.0
	box(Vector3(sink - 45, ROOM_BACK + 12, top - 30), Vector3(sink + 45, counter_y - 6, top - 28), steel)
	for x in [sink - 45, sink + 43]:
		box(Vector3(x, ROOM_BACK + 12, top - 30), Vector3(x + 2, counter_y - 6, top), steel)
	box(Vector3(sink - 45, counter_y - 8, top - 30), Vector3(sink + 45, counter_y - 6, top), steel)
	b.cylinder(Vector3(sink, ROOM_BACK + 10, top + 22), 4, 44, Vector3.ZERO, copper)
	b.cylinder(Vector3(sink, ROOM_BACK + 20, top + 44), 4, 22, Vector3(90, 90, 0), copper)
	b.cylinder(Vector3(sink - 30, ROOM_BACK + 6, f + 120), 5, 150, Vector3.ZERO, copper)
	b.cylinder(Vector3(sink - 30, ROOM_BACK + 6, r.ceiling - 40), 5, 400, Vector3(90, 0, 0), copper)
	var stove := b.prop("electric_stove", Vector3(2330, ROOM_BACK + 34, f), 0, 90.0 / 85.869714)
	if stove:
		# Preenche o vão de 60 cm mantendo o tampo a 90 cm.
		stove.scale.x *= 58.0 / (0.723836 * 100.0 * stove.scale.x)
	var hood := Vector3(2330, ROOM_BACK + 40, f + 190)
	box(hood + Vector3(-55, -40, 0), hood + Vector3(55, 40, 8), steel)
	b.beam(hood + Vector3(0, 0, 26), Vector3(80, 60, 40), Vector3.ZERO, steel)
	box(hood + Vector3(-18, -18, 46), hood + Vector3(18, 18, r.ceiling - hood.z), steel)
	# Prateleira de parede com louça e panelas; barra com as frigideiras.
	box(Vector3(2400, ROOM_BACK, f + 150), Vector3(2740, ROOM_BACK + 30, f + 154), wood)
	for x in [2420.0, 2720.0]:
		box(Vector3(x, ROOM_BACK, f + 140), Vector3(x + 4, ROOM_BACK + 26, f + 150), painted)
	b.card("Cantina_Utensils", Vector3(2570, ROOM_BACK + 32, f + 154), 160, 40.94)
	box(Vector3(2190, ROOM_BACK + 6, f + 176), Vector3(2290, ROOM_BACK + 8, f + 178), steel)
	b.prop("brass_pan_01", Vector3(2215, ROOM_BACK + 12, f + 150), 90)
	b.prop("brass_pan_01", Vector3(2262, ROOM_BACK + 12, f + 152), 90)
	b.prop("wooden_cutting_board", Vector3(2440, counter_y - 30, top), 4)
	b.prop("sweet_potato", Vector3(2430, counter_y - 26, top + 4), 30)
	b.prop("sweet_potato", Vector3(2452, counter_y - 34, top + 4), -40)
	b.prop("brass_pot_01", Vector3(2318, ROOM_BACK + 45, top))
	# Filtro de água e os galões.
	var filter := Vector3(2730, -520, f)
	box(filter + Vector3(-26, -26, 0), filter + Vector3(26, 26, 70), painted)
	b.cylinder(filter + Vector3(0, 0, 110), 44, 80, Vector3.ZERO, steel)
	b.cylinder(filter + Vector3(0, 0, 152), 46, 4, Vector3.ZERO, painted)
	b.cylinder(filter + Vector3(0, 25, 88), 3, 10, Vector3(90, 0, 0), copper)
	b.prop("plastic_bottle_gallon", filter + Vector3(-50, 10, 0))
	b.prop("plastic_bottle_gallon", filter + Vector3(-52, 36, 0), 40)
	# Despensa: estante de aço com os mantimentos por prateleira (o estoque mostra a faixa de suprimentos).
	var pantry := Vector3(2050, ROOM_BACK + 30, f)
	b.prop("steel_frame_shelves_01", pantry)
	for level in 4:
		var z := 4.0 + level * 52
		if level == 0:
			b.prop("plastic_crate_01", pantry + Vector3(-28, 0, z))
			b.prop("plastic_crate_01", pantry + Vector3(28, 0, z), 4)
		var mark := b.mark()
		if level == 1:
			b.card("Cantina_Pantry", pantry + Vector3(0, 32, 60), 90, 17.09)
		if level == 2:
			b.prop("wicker_basket_01", pantry + Vector3(-20, 0, z + 4))
			b.prop("food_apple_01", pantry + Vector3(36, 4, z + 4))
		if level == 1 or level == 2:
			_tag_stock(mark, level)
		if level == 3:
			b.prop("plastic_bottle_gallon", pantry + Vector3(-30, 0, z + 4))
			b.prop("plastic_bottle_gallon", pantry + Vector3(-6, 0, z + 4), 20)
	var roots := b.mark()
	for x in [-22.0, -6.0, 10.0]:
		b.prop("sweet_potato", pantry + Vector3(x, -6, 2 * 52 + 8), x * 7)
	_tag_stock(roots, 3)
	b.prop("wooden_bucket_01", Vector3(2480, counter_y + 40, f))
	# Mesa comunitária: tampo de madeira, pés de aço, banco, banquetas e a louça posta.
	var table_x0 := 1650.0
	var table_x1 := 2050.0
	var table_y0 := -560.0
	var table_y1 := -460.0
	var table_top := f + 76
	box(Vector3(table_x0, table_y0, table_top - 5), Vector3(table_x1, table_y1, table_top), wood)
	for x in [table_x0 + 20, table_x1 - 26]:
		for y in [table_y0 + 8, table_y1 - 14]:
			box(Vector3(x, y, f), Vector3(x + 6, y + 6, table_top - 5), painted)
	box(Vector3(table_x0 + 20, table_y0 + 40, f + 18), Vector3(table_x1 - 20, table_y0 + 46, f + 22), painted)
	var bench_y := table_y0 - 50
	box(Vector3(table_x0 + 10, bench_y, f + 42), Vector3(table_x1 - 10, bench_y + 32, f + 46), wood)
	for x in [table_x0 + 30, table_x1 - 34]:
		box(Vector3(x, bench_y + 6, f), Vector3(x + 4, bench_y + 26, f + 42), painted)
	b.prop("folding_wooden_stool", Vector3(1720, table_y1 + 50, f), 10)
	b.prop("folding_wooden_stool", Vector3(1980, table_y1 + 46, f), -14)
	for x in [1700.0, 1800.0, 1900.0, 2000.0]:
		b.prop("carved_wooden_plate", Vector3(x, -530, table_top), x)
	for x in [1700.0, 1900.0]:
		b.prop("carved_wooden_plate", Vector3(x, -486, table_top), x * 2)
	b.prop("pot_enamel_01", Vector3(1850, -505, table_top), 30)
	b.prop("wooden_bowl_01", Vector3(1960, -488, table_top))
	b.prop("plastic_bottle_gallon", Vector3(1760, -488, table_top))
	b.prop("painted_wooden_cabinet", Vector3(1640, ROOM_BACK + 36, f), 180)
	b.prop("wicker_basket_01", Vector3(1640, ROOM_BACK + 36, f + 118))
	# Luz: quente sobre a mesa, neutra na preparação.
	for x in [1760.0, 1940.0]:
		b.hang("caged_hanging_light", Vector3(x, -510, r.ceiling))
		var lamp := b.light(Vector3(x, -510, r.ceiling - 95), 1100, 760, WARM, true)
		if x == 1760.0:
			room_lights["canteen"] = lamp
	b.prop("mounted_fluorescent_lights", Vector3(2460, -700, r.ceiling - 4))
	b.light(Vector3(2460, -700, r.ceiling - 30), 1500, 820, NEUTRAL, true)
	b.light(Vector3(2330, ROOM_BACK + 40, f + 182), 220, 260, NEUTRAL, false)


# ---------------------------------------------------------------- Depósito

func _depot() -> void:
	var r := room("depot")
	var f: float = r.floor
	var painted := S("green_metal_rust", f, 0, STEEL_TINT, 0.9)
	var wood := S("wood_table_worn", f, 0, Color(0.9, 0.82, 0.72))
	var ratios := {"Depot_Crate": 1480.0 / 777.0, "Depot_Sack": 1053.0 / 1285.0, "Depot_Container": 1174.0 / 1020.0}
	var art := func(name: String, base: Vector3, width: float) -> void:
		b.card(name, base, width, width / ratios[name], true)
	# Barra de tinta verde acinzentada no rodapé (padrão ferroviário) com o friso de aço.
	var back_door := [b.hole(r.door, f, r.door + 120, f + 220)]
	b.wall_with_openings(r.x0 + 15, r.x1 - 15, ROOM_BACK, ROOM_BACK + 1.5, f, f + 110, back_door, S("painted_plaster_wall", f, 0.35, Color(0.5, 0.58, 0.54)), true)
	box(Vector3(r.x0 + 15, ROOM_BACK, f + 110), Vector3(r.door - 8, ROOM_BACK + 4, f + 114), painted)
	box(Vector3(r.door + 128, ROOM_BACK, f + 110), Vector3(r.x1 - 15, ROOM_BACK + 4, f + 114), painted)
	# Estantes no fundo; a estante A é a comida (#65): uma prateleira por faixa de estoque.
	var shelf_y := ROOM_BACK + 27
	var shelf := [13.0, 64.0, 115.0, 165.0]
	b.prop("steel_frame_shelves_02", Vector3(850, shelf_y, f))
	b.prop("steel_frame_shelves_02", Vector3(935, shelf_y, f))
	var mark := b.mark()
	art.call("Depot_Crate", Vector3(850, ROOM_BACK + 55, f + shelf[0]), 50)
	_tag_stock(mark, 1)
	mark = b.mark()
	art.call("Depot_Crate", Vector3(850, ROOM_BACK + 55, f + shelf[1]), 48)
	_tag_stock(mark, 2)
	mark = b.mark()
	art.call("Depot_Sack", Vector3(837, ROOM_BACK + 55, f + shelf[2]), 28)
	art.call("Depot_Container", Vector3(865, ROOM_BACK + 55, f + shelf[2]), 20)
	_tag_stock(mark, 3)
	mark = b.mark()
	art.call("Depot_Crate", Vector3(850, ROOM_BACK + 55, f + shelf[3]), 46)
	_tag_stock(mark, 4)
	art.call("Depot_Container", Vector3(935, ROOM_BACK + 55, f + shelf[0]), 34)
	for x in [921.0, 949.0]:
		art.call("Depot_Sack", Vector3(x, ROOM_BACK + 55, f + shelf[1]), 23)
	art.call("Depot_Container", Vector3(935, ROOM_BACK + 55, f + shelf[2]), 30)
	art.call("Depot_Sack", Vector3(1007, ROOM_BACK + 60, f), 38)
	art.call("Depot_Container", Vector3(1051, ROOM_BACK + 60, f), 36)
	b.prop("Barrel_02", Vector3(1106, ROOM_BACK + 30, f), 20)
	# Bancada de conferência na entrada, com as caixas que chegaram.
	var bench_x0: float = r.x0 + 18
	var bench_x1 := bench_x0 + 110
	var bench_y0 := -680.0
	var bench_y1 := -608.0
	var bench_top := f + 88
	box(Vector3(bench_x0, bench_y0, bench_top - 5), Vector3(bench_x1, bench_y1, bench_top), wood)
	for x in [bench_x0 + 3, bench_x1 - 8]:
		for y in [bench_y0 + 3, bench_y1 - 8]:
			box(Vector3(x, y, f), Vector3(x + 5, y + 5, bench_top - 5), painted)
	box(Vector3(bench_x0 + 3, bench_y1 - 8, bench_top - 14), Vector3(bench_x1 - 3, bench_y1 - 3, bench_top - 5), painted)
	box(Vector3(bench_x0 + 3, bench_y0 + 3, f + 10), Vector3(bench_x1 - 3, bench_y1 - 3, f + 13), wood)
	var center_x := (bench_x0 + bench_x1) * 0.5
	art.call("Depot_Crate", Vector3(center_x, bench_y1 - 6, f + 13), 82)
	art.call("Depot_Crate", Vector3(center_x, bench_y1 - 6, bench_top), 86)
	b.hang("caged_hanging_light", Vector3(860, -480, r.ceiling))
	room_lights["depot"] = b.light(Vector3(860, -480, r.ceiling - 90), 1000, 700, r.light, true)


# ---------------------------------------------------------------- Forja

func _forge() -> void:
	var r := room("forge")
	var f: float = r.floor
	var c: float = r.ceiling
	var hood_finish := S("metal_plate", f, 0, Color(0.32, 0.31, 0.29), 0.9)
	var cladding := S("Metal021", f)
	var olive := S("green_metal_rust", 0, 0, Color(0.42, 0.46, 0.32), 0.9)
	# O revestimento do metrô aprovado: faixa oliva, aço escovado embaixo e o escudo de calor da fornalha.
	box(Vector3(r.x0 + 15, ROOM_BACK + 0.2, f + 190), Vector3(r.door - 8, ROOM_BACK + 2, f + 206), olive, false)
	box(Vector3(r.door + 128, ROOM_BACK + 0.2, f + 190), Vector3(1950, ROOM_BACK + 2, f + 206), olive, false)
	var band_top := f + 140
	box(Vector3(r.x0 + 15, ROOM_BACK + 0.2, f), Vector3(r.door - 8, ROOM_BACK + 2, band_top), cladding, false)
	box(Vector3(r.door + 128, ROOM_BACK + 0.2, f), Vector3(r.x1 - 15, ROOM_BACK + 2, band_top), cladding, false)
	box(Vector3(1950, ROOM_BACK + 0.2, band_top), Vector3(2120, ROOM_BACK + 2, c - 29), hood_finish, false)
	box(Vector3(r.x0 + 15, ROOM_BACK + 1, c - 8), Vector3(r.x1 - 15, ROOM_BACK + 7, c - 2), cladding, false)
	# Daqui em diante é a oficina em si (#70: some no nível 0; o revestimento acima fica).
	var dressing_start := b.mark()
	var painted := S("green_metal_rust", f, 0, STEEL_TINT, 0.9)
	var steel := S("metal_plate", f, 0, Color(0.5, 0.48, 0.45), 0.6)
	var sooty := S("metal_plate", f, 0, Color(0.16, 0.15, 0.14), 0.9)
	var refractory := S("rough_concrete", f, 0, Color(0.1, 0.085, 0.075))
	var brick := S("factory_brick", f, 0.2, Color(0.62, 0.5, 0.42))
	var rail := S("metal_plate", 0, 0, Color(0.72, 0.68, 0.62), 0.5)
	var worn := S("metal_plate", 0, 0, Color(0.86, 0.83, 0.79), 0.4)
	var sleeper := S("wood_planks_grey", 0, 0, Color(0.56, 0.46, 0.36))
	# Fornalha: base de tijolo, câmara de chapa com a boca para a sala, interior refratário e brasas.
	var fx0 := 1960.0
	var fx1 := 2110.0
	var mouth_x0 := 2005.0
	var mouth_x1 := 2065.0
	var chamber_z0 := f + 72
	var chamber_z1 := f + 160
	var mouth_z0 := f + 88
	var mouth_z1 := f + 128
	box(Vector3(fx0, ROOM_BACK, f), Vector3(fx1, ROOM_BACK + 105, f + 70), brick)
	box(Vector3(fx0, ROOM_BACK + 101, f + 66), Vector3(fx1, ROOM_BACK + 107, f + 72), steel)
	box(Vector3(fx0 + 5, ROOM_BACK, chamber_z0), Vector3(fx1 - 5, ROOM_BACK + 55, chamber_z1), refractory)
	box(Vector3(fx0 + 5, ROOM_BACK + 55, chamber_z0), Vector3(mouth_x0, ROOM_BACK + 92, chamber_z1), refractory)
	box(Vector3(mouth_x1, ROOM_BACK + 55, chamber_z0), Vector3(fx1 - 5, ROOM_BACK + 92, chamber_z1), refractory)
	box(Vector3(mouth_x0, ROOM_BACK + 55, chamber_z0), Vector3(mouth_x1, ROOM_BACK + 92, mouth_z0), refractory)
	box(Vector3(mouth_x0, ROOM_BACK + 55, mouth_z1), Vector3(mouth_x1, ROOM_BACK + 92, chamber_z1), refractory)
	b.wall_with_openings(fx0 + 5, fx1 - 5, ROOM_BACK + 92, ROOM_BACK + 100, chamber_z0, chamber_z1, [b.hole(mouth_x0, mouth_z0, mouth_x1, mouth_z1)], sooty, true)
	box(Vector3(fx0, ROOM_BACK, chamber_z1), Vector3(fx1, ROOM_BACK + 102, chamber_z1 + 6), sooty)
	box(Vector3(mouth_x0 - 5, ROOM_BACK + 100, mouth_z1), Vector3(mouth_x1 + 5, ROOM_BACK + 104, mouth_z1 + 6), steel)
	box(Vector3(mouth_x0 - 5, ROOM_BACK + 100, mouth_z0 - 6), Vector3(mouth_x1 + 5, ROOM_BACK + 108, mouth_z0), steel)
	for x in [mouth_x0 - 5, mouth_x1]:
		box(Vector3(x, ROOM_BACK + 100, mouth_z0), Vector3(x + 5, ROOM_BACK + 104, mouth_z1), steel)
	var ember := b.emissive(Color(1, 0.36, 0.08), 6)
	box(Vector3(mouth_x0, ROOM_BACK + 55.5, mouth_z0), Vector3(mouth_x1, ROOM_BACK + 56, mouth_z0 + 18), b.emissive(Color(1, 0.28, 0.06), 1.5), false)
	var coals := [[2010.0, 2026.0, 5.0], [2026.0, 2040.0, 7.0], [2040.0, 2052.0, 4.0], [2052.0, 2062.0, 6.0]]
	for index in coals.size():
		var coal: Array = coals[index]
		box(Vector3(coal[0], ROOM_BACK + 60 + index * 4, mouth_z0), Vector3(coal[1] - 1, ROOM_BACK + 86 - index * 3, mouth_z0 + coal[2]), refractory if index % 2 else ember, false)
	ember_light = b.light(Vector3((mouth_x0 + mouth_x1) * 0.5, ROOM_BACK + 118, mouth_z0 + 14), 260, 380, Color(1, 0.45, 0.15), false)
	# Coifa e duto: sobe até perto do teto e entra na parede do fundo.
	var duct_x := (mouth_x0 + mouth_x1) * 0.5
	box(Vector3(fx0 - 9, ROOM_BACK + 2, chamber_z1 + 6), Vector3(fx1 + 9, ROOM_BACK + 111.5, f + 200.5), hood_finish)
	box(Vector3(fx0 - 10, ROOM_BACK, f + 200), Vector3(fx1 + 10, ROOM_BACK + 112, f + 208), hood_finish)
	box(Vector3(duct_x - 60, ROOM_BACK + 10, f + 208), Vector3(duct_x + 60, ROOM_BACK + 100, f + 232), hood_finish)
	box(Vector3(duct_x - 34, ROOM_BACK + 26, f + 232), Vector3(duct_x + 34, ROOM_BACK + 86, f + 256), hood_finish)
	b.cylinder(Vector3(duct_x, ROOM_BACK + 50, (f + 256 + c - 60) * 0.5), 36, c - 60 - (f + 256), Vector3.ZERO, sooty)
	box(Vector3(duct_x - 20, ROOM_BACK + 30, c - 78), Vector3(duct_x + 20, ROOM_BACK + 70, c - 40), sooty)
	b.cylinder(Vector3(duct_x, ROOM_BACK + 15, c - 59), 36, 30, Vector3(90, 90, 0), sooty)
	# Bigorna improvisada: trecho de trilho sobre dormentes empilhados em grade.
	var anvil := Vector3(1890, -560, f)
	for layer in 3:
		var z0 := f + layer * 20
		if layer == 1:
			for x in [-30.0, 8.0]:
				box(Vector3(anvil.x + x, anvil.y - 24, z0), Vector3(anvil.x + x + 22, anvil.y + 24, z0 + 20), sleeper)
		else:
			for y in [-24.0, 1.0]:
				box(Vector3(anvil.x - 35, anvil.y + y, z0), Vector3(anvil.x + 35, anvil.y + y + 23, z0 + 20), sleeper)
	var rail_z := f + 60
	box(Vector3(anvil.x - 32, anvil.y - 7, rail_z), Vector3(anvil.x + 32, anvil.y + 7, rail_z + 2), rail)
	box(Vector3(anvil.x - 32, anvil.y - 1.5, rail_z + 2), Vector3(anvil.x + 32, anvil.y + 1.5, rail_z + 13), rail)
	box(Vector3(anvil.x - 32, anvil.y - 3.5, rail_z + 13), Vector3(anvil.x + 32, anvil.y + 3.5, rail_z + 18), rail)
	box(Vector3(anvil.x - 29, anvil.y - 3, rail_z + 18), Vector3(anvil.x + 29, anvil.y + 3, rail_z + 18.4), worn, false)
	b.prop_placed("sledgehammer_01", anvil + Vector3(46, 8, 0), Vector3(0, 90, -8))
	b.prop("metal_jerrycan_green", anvil + Vector3(-70, -14, 0), 20)
	# A bancada pintada aprovada (o conjunto da oficina) e o carrinho de ferramentas no canto da porta.
	var workbay_width := 460.0
	var workbay_height := workbay_width * 860.0 / 1485.0
	var workbay := Vector3(1670, ROOM_BACK + 90, f)
	b.card("Forge_Workbay", workbay, workbay_width, workbay_height)
	b.contact(Vector3(workbay.x, workbay.y - 8, f), Vector2(460, 65), 0.36)
	b.prop("tool_cart", Vector3(r.x0 + 57, ROOM_BACK + 70, f), 90)
	# Bandeja de cabos aberta, ramal da exaustão e eletrodutos nas paredes.
	for x in [1515.0, 1580.0]:
		box(Vector3(x, -820, c - 46), Vector3(x + 4, -170, c - 34), painted, false)
	var rung := -810.0
	while rung < -170:
		box(Vector3(1515, rung, c - 46), Vector3(1584, rung + 5, c - 42), steel, false)
		rung += 80
	for x in [1531.0, 1545.0, 1561.0]:
		b.cylinder(Vector3(x, -495, c - 39), 5, 650, Vector3(90, 90, 0), sooty)
	box(Vector3(2038, -870, c - 98), Vector3(2135, -812, c - 60), hood_finish, false)
	box(Vector3(2085, -870, c - 98), Vector3(2135, -180, c - 60), hood_finish, false)
	for x in [1185.0, 2129.0]:
		b.cylinder(Vector3(x, -615, f + 250), 8, 240, Vector3.ZERO, painted)
	# Armários baixos nas laterais até o corte, com a caixa de ferramentas e os lingotes em cima.
	var return_length := 420.0
	var return_height := return_length * 286.0 / 1068.0
	var return_depth := return_height * 340.0 / 286.0
	var case_material := S("Metal021", f, 0, Color(0.55, 0.55, 0.42))
	var case_top := S("metal_plate", f, 0, Color(0.27, 0.27, 0.18))
	for left in [true, false]:
		var x0 := 1177.0 if left else 2143.0 - return_depth
		var x1 := x0 + return_depth
		box(Vector3(x0, -570, f), Vector3(x1, 0, f + return_height - 5), case_material, false)
		box(Vector3(x0, -570, f + return_height - 5), Vector3(x1, 0, f + return_height), case_top, false)
		b.contact(Vector3((x0 + x1) * 0.5, -285, f), Vector2(return_depth + 6, 568), 0.38)
		b.card("Forge_Ingots" if left else "Forge_Toolbox", Vector3((x0 + x1) * 0.5, -295, f + return_height), 55,
			55.0 * 606.0 / 1439.0 if left else 55.0 * 703.0 / 1439.0, true)
	# Prateleira alta de peças sobressalentes no fundo e o suporte de barras sobre o armário da esquerda.
	box(Vector3(1440, ROOM_BACK + 2, f + 288), Vector3(1910, ROOM_BACK + 5, f + 380), painted, false)
	for height in [285.0, 376.0]:
		box(Vector3(1440, ROOM_BACK + 2, f + height), Vector3(1910, ROOM_BACK + 61, f + height + 4), steel, false)
	for x in [1440.0, 1595.0, 1750.0, 1906.0]:
		box(Vector3(x, ROOM_BACK + 2, f + 289), Vector3(x + 4, ROOM_BACK + 61, f + 376), painted, false)
	b.card("Forge_ToolRack", Vector3(1600, ROOM_BACK + 62, f + 289), 150, 150.0 / 1.7597173, true)
	for height in [138.0, 258.0]:
		box(Vector3(1178, -553, f + height), Vector3(1210, -447, f + height + 4), painted, false)
	for y in [-540.0, -515.0, -490.0, -465.0]:
		box(Vector3(1188, y, f + 142), Vector3(1192, y + 8, f + 258), steel, false)
	# Luz: pendente sobre a bigorna, um preenchimento fraco e o realce na frente da bigorna.
	b.hang("caged_hanging_light", Vector3(anvil.x, anvil.y, c))
	room_lights["forge"] = b.light(Vector3(anvil.x, anvil.y, c - 100), 900, 760, NEUTRAL, true)
	b.light(Vector3(1660, -260, f + 160), 350, 700, NEUTRAL, false)
	b.light(anvil + Vector3(0, 170, 110), 180, 320, NEUTRAL, false)
	_tag_dressing("forge", dressing_start)


# ---------------------------------------------------------------- Dormitório, Preparação, Pesquisa, Bar e Personagens

## Os beliches do Dormitório: o card inteiro da entrega #1 do Codex (art/station/cards/dormitory_bunk.webp, as linhas
## medidas em docs/design/bunk.md), uma peça só por beliche. Quatro lugares, um por herói da equipe, onde quem dorme
## deita à noite (AHStation.sleep_slots). Ficam mesmo com o quarto por recuperar.
const BUNK_X := [-1010.0, -660.0]
const BUNK_Y := -665.0
const BUNK_FLOOR := -520.0
const BUNK_CARD := "dormitory_bunk"
## O card (1024x677) e as linhas medidas nele, em pixels a partir do topo: os dois colchões, o piso e a âncora.
const BUNK_PX := Vector2(1024.0, 677.0)
const BUNK_UPPER_PX := 132.17
const BUNK_LOWER_PX := 451.95
const BUNK_FLOOR_PX := 653.06
const BUNK_ANCHOR_X_PX := 511.64
## A largura na Estação (cm): a armação fica com a largura da cama antiga (255 cm).
const BUNK_WIDTH := 267.0
const BUNK_SCALE := BUNK_WIDTH / 1024.0
## Do colchão de baixo ao de cima, e do piso ao colchão de baixo (onde o corpo encosta), em cm.
const BUNK_UPPER := (BUNK_LOWER_PX - BUNK_UPPER_PX) * BUNK_SCALE
const MATTRESS_TOP := (BUNK_FLOOR_PX - BUNK_LOWER_PX) * BUNK_SCALE


func _dormitory_bunks() -> void:
	var height := BUNK_PX.y * BUNK_SCALE
	for x in BUNK_X:
		# A âncora do card (o pé, no centro) fica em x e no piso; a margem transparente de baixo vai para baixo do chão.
		var base := Vector3(x + (BUNK_PX.x * 0.5 - BUNK_ANCHOR_X_PX) * BUNK_SCALE, BUNK_Y, BUNK_FLOOR - (BUNK_PX.y - BUNK_FLOOR_PX) * BUNK_SCALE)
		b.card(BUNK_CARD, base, BUNK_WIDTH, height)


func _dormitory() -> void:
	var f := -520.0
	var wood := S("wood_table_worn", f, 0, Color(0.58, 0.47, 0.34))
	var steel := S("green_metal_rust", f, 0, Color(0.5, 0.6, 0.54))
	# O armário com a frente da Cantina e os ganchos com os pertences.
	var cabinet := Vector3(-345, -720, f)
	var cabinet_width := 170.0
	var cabinet_height := cabinet_width * 788.0 / 1380.0
	box(cabinet + Vector3(-85, -77, 0), cabinet + Vector3(85, -1, 3), steel)
	box(cabinet + Vector3(-85, -77, 3), cabinet + Vector3(85, -2, 3 + cabinet_height), wood)
	box(cabinet + Vector3(-87, -79, 3 + cabinet_height), cabinet + Vector3(87, 2, 6 + cabinet_height), wood)
	b.card("Cantina_Front", cabinet + Vector3(0, 0, 3), cabinet_width, cabinet_height)
	b.card("Dormitory_PersonalPegs", Vector3(-345, -887, f + 120), 140, 140.0 * 1037.0 / 1112.0)
	# Mesa de cabeceira com a tigela.
	var table := Vector3(-835, -718, f)
	box(table + Vector3(-24, -22, 58), table + Vector3(24, 22, 62), wood)
	box(table + Vector3(-21, -19, 30), table + Vector3(21, 19, 33), wood)
	for x in [-19.0, 19.0]:
		for y in [-17.0, 17.0]:
			box(table + Vector3(x - 2, y - 2, 3), table + Vector3(x + 2, y + 2, 58), wood)
			box(table + Vector3(x - 2.5, y - 2.5, 0), table + Vector3(x + 2.5, y + 2.5, 4), steel)
	b.prop("wooden_bowl_01", table + Vector3(0, 0, 62))
	b.hang("caged_hanging_light", Vector3(-760, -460, -200))
	room_lights["dormitory"] = b.light(Vector3(-760, -460, -290), 650, 800, Color(1, 0.72, 0.42), true)


## A Enfermaria provisória (#121): os beliches do Dormitório como leitos (um beliche no nível 1, dois no nível 2), a
## estante de amostras como a de remédios e o armário com a frente da Cantina. Vazia (nível 0), só uma caixa tombada.
const INFIRMARY_BUNK_X := [-1075.0, -805.0]
const INFIRMARY_FLOOR := -940.0


func _infirmary() -> void:
	var f := INFIRMARY_FLOOR
	var height := BUNK_PX.y * BUNK_SCALE
	for index in INFIRMARY_BUNK_X.size():
		var mark := b.mark()
		var x: float = INFIRMARY_BUNK_X[index]
		var base := Vector3(x + (BUNK_PX.x * 0.5 - BUNK_ANCHOR_X_PX) * BUNK_SCALE, BUNK_Y, f - (BUNK_PX.y - BUNK_FLOOR_PX) * BUNK_SCALE)
		b.card(BUNK_CARD, base, BUNK_WIDTH, height)
		# O segundo beliche só aparece com a Enfermaria melhorada (os leitos 3 e 4).
		_tag_dressing("infirmary" if index == 0 else "infirmary@2", mark)
	var mark := b.mark()
	b.card("Research_SampleShelves", Vector3(-940, -886, f + 160), 150, 97)
	b.card("Cantina_Front", Vector3(-700, -720, f), 90, 90.0 * 788.0 / 1380.0)
	b.hang("caged_hanging_light", Vector3(-940, -480, B2_CEILING))
	room_lights["infirmary"] = b.light(Vector3(-940, -480, B2_CEILING - 90), 1100, 700, COOL, true)
	_tag_dressing("infirmary", mark)
	b.card("Depot_Container", Vector3(-1180, -520, f), 60, 60.0 / 1.1509804)


func _preparation() -> void:
	var f := -940.0
	var wood := S("wood_table_worn", f, 0, Color(0.65, 0.56, 0.42))
	var steel := S("green_metal_rust", f, 0, Color(0.55, 0.65, 0.59))
	b.prop("painted_wooden_bench", Vector3(2220, -590, f), 90)
	b.prop("steel_frame_shelves_02", Vector3(2220, -830, f))
	b.prop("metal_jerrycan_green", Vector3(2220, -826, f + 11.447))
	b.card("Preparation_Crate", Vector3(2220, -811, f + 62.127), 44, 44.0 * 380.0 / 410.0)
	b.card("Preparation_Crate", Vector3(2220, -811, f + 112.806), 44, 44.0 * 380.0 / 410.0)
	b.card("Preparation_Crate", Vector3(2472, -545, f), 72, 72.0 * 380.0 / 410.0)
	b.card("Preparation_Backpack", Vector3(2670, -545, f), 67, 67.0 * 1240.0 / 1125.0)
	# A bancada com a frente pintada, a caixa de ferramentas e a prancheta com a lista.
	var table := Vector3(2550, -735, f)
	box(table + Vector3(-111, -38, 84.8), table + Vector3(111, 38, 90), wood)
	for x in [-105.0, 105.0]:
		box(table + Vector3(x - 3, -34, 0), table + Vector3(x + 3, 32, 84.8), steel)
	b.card("Forge_BenchFront", table + Vector3(0, 39, 0), 222, 222.0 * 683.0 / 1786.0)
	b.card("Forge_Toolbox", table + Vector3(53, 12, 90), 60, 60.0 * 703.0 / 1439.0)
	# O diagrama das rotas emoldurado (o título é texto, não arte).
	box(Vector3(2420, -899, f + 147), Vector3(2700, -892, f + 284), wood)
	b.card("Preparation_Routes", Vector3(2560, -889, f + 154), 266, 123)
	b.sign("ROTAS", Vector3(2560, -887, f + 265), 14, Color8(230, 224, 200))
	box(table + Vector3(-20, 4, 90), table + Vector3(0, 32, 90.8), wood)
	b.card("Preparation_Checklist", table + Vector3(-10, 33, 90.8), 18, 26)


func _research() -> void:
	var f := -940.0
	var wood := S("wood_table_worn", f, 0, Color(0.65, 0.56, 0.42))
	var steel := S("green_metal_rust", f, 0, Color(0.55, 0.65, 0.59))
	var table := Vector3(-100, -730, f)
	var top := 95.864
	box(table + Vector3(-120, -57, top - 4), table + Vector3(120, 57, top), wood)
	for x in [-118.0, 112.0]:
		box(table + Vector3(x, -53, 0), table + Vector3(x + 6, 54, top - 4), steel)
	b.card("Forge_BenchFront", table + Vector3(0, 58, 0), 240, 240.0 * 683.0 / 1786.0)
	b.card("Research_Bookshelf", Vector3(-500, -785, f), 240.0 * 290.0 / 539.0, 240)
	b.card("Research_RadioDesk", Vector3(255, -690, f), 190, 190.0 * 340.0 / 518.0)
	b.card("Research_SampleShelves", Vector3(255, -886, f + 160), 185, 120)
	b.prop("folding_wooden_stool", Vector3(80, -620, f), 20)
	box(table + Vector3(-105, -30, top), table + Vector3(15, 16, top + 1.2), steel)
	# Mural de notas neutras; as palavras são texto.
	box(Vector3(-415, -899, f + 155), Vector3(-65, -892, f + 280), wood)
	b.card("Research_Notes", Vector3(-240, -889, f + 162), 336, 111)
	var titles := ["AMOSTRAS", "REGISTROS", "ANÁLISE"]
	for index in 3:
		b.sign(titles[index], Vector3(-350 + index * 110, -887, f + 261), 11, Color8(229, 224, 200))


func _bar() -> void:
	var f := -520.0
	var wood := S("wood_table_worn", f, 0, Color(0.68, 0.57, 0.42))
	var steel := S("green_metal_rust", f, 0, Color(0.57, 0.66, 0.59))
	var cloth := S("terry_cloth", f, 0, Color(0.71, 0.75, 0.65))
	# Balcão de 260 x 75 x 110 cm: três tábuas, estrutura e a frente pintada.
	for board in 3:
		box(Vector3(1100, -675 + board * 25, f + 105), Vector3(1360, -650.5 + board * 25, f + 110), wood)
	for x in [1114.0, 1346.0]:
		for y in [-660.0, -612.0]:
			box(Vector3(x - 3, y - 3, f), Vector3(x + 3, y + 3, f + 105), steel)
	box(Vector3(1111, -664, f + 84), Vector3(1349, -658, f + 91), steel)
	box(Vector3(1111, -615, f + 84), Vector3(1349, -609, f + 91), steel)
	b.card("Bar_Front", Vector3(1228.5, -608, f + 30), 222, 60.55)
	box(Vector3(1117.5, -614, f + 30), Vector3(1339.5, -610, f + 90.55), wood)
	b.cylinder(Vector3(1230, -578, f + 28), 4, 210, Vector3(90, 0, 0), steel)
	for x in [1125.0, 1335.0]:
		box(Vector3(x - 2, -611, f + 25), Vector3(x + 2, -578, f + 29), steel)
	# As banquetas (a cadeira redonda da Unreal só existe como .uasset).
	b.prop("folding_wooden_stool", Vector3(1160, -465, f))
	b.prop("folding_wooden_stool", Vector3(1290, -465, f), 25)
	b.prop("painted_wooden_shelves", Vector3(1320, -865, f))
	box(Vector3(1295, -883, f + 112.507), Vector3(1345, -847, f + 114), wood)
	for height in [135.0, 180.0]:
		box(Vector3(1120, -898, f + height - 4), Vector3(1400, -867, f + height), wood)
		for x in [1132.0, 1384.0]:
			box(Vector3(x, -898, f + height - 23), Vector3(x + 4, -894, f + height - 4), steel)
			box(Vector3(x, -898, f + height - 7), Vector3(x + 4, -869, f + height - 4), steel)
	var widths := [16.17, 9.23, 16.68, 9.69]
	var heights := [28.0, 34.0, 30.0, 32.0]
	for bottle in [[0, 1145.0, 135.0], [1, 1168.0, 135.0], [2, 1275.0, 135.0], [3, 1370.0, 135.0], [1, 1190.0, 180.0], [3, 1210.0, 180.0], [2, 1350.0, 180.0]]:
		b.card("Bar_Bottle%d" % bottle[0], Vector3(bottle[1], -866, f + bottle[2]), widths[bottle[0]], heights[bottle[0]])
	b.card("Bar_Bottle0", Vector3(1140, -628, f + 110), widths[0], heights[0])
	box(Vector3(1290, -663, f + 110), Vector3(1324, -638, f + 110.35), cloth)
	box(Vector3(1291, -662, f + 110.35), Vector3(1322, -639, f + 110.7), cloth)


func _characters_room() -> void:
	var f := -520.0
	var wood := S("wood_table_worn", f, 0, Color(0.72, 0.63, 0.49))
	var painted := S("green_metal_rust", f, 0, Color(0.61, 0.68, 0.61))
	var paper := S("painted_plaster_wall", f, 0, Color(0.83, 0.8, 0.68))
	# O sofá pintado com o assento físico atrás, a estante e o mural.
	var sofa := Vector3(500, -790, f)
	box(sofa + Vector3(-120, -75, 18), sofa + Vector3(120, -2, 25), wood)
	for x in [-122.0, 122.0]:
		for y in [-68.0, -8.0]:
			box(sofa + Vector3(x - 4, y - 4, 0), sofa + Vector3(x + 4, y + 4, 18), wood)
	b.card("CharactersRoom_Sofa", sofa, 260, 260.0 * 723.0 / 1763.0)
	b.card("Research_Bookshelf", Vector3(310, -830, f), 65, 65.0 * 539.0 / 290.0)
	b.card("CharactersRoom_Notice", Vector3(30, -815, f), 92, 92.0 * 536.0 / 354.0)
	b.prop("folding_wooden_stool", Vector3(675, -620, f), -25)
	# Mesa baixa de 44 cm com um livro fechado.
	for plank in 3:
		box(Vector3(435, -690 + 20 * plank, f + 40), Vector3(555, -670.5 + 20 * plank, f + 44), wood)
	for x in [444.0, 546.0]:
		for y in [-681.0, -639.0]:
			box(Vector3(x - 3, y - 3, f), Vector3(x + 3, y + 3, f + 40), painted)
	box(Vector3(441, -684, f + 12), Vector3(549, -678, f + 18), painted)
	box(Vector3(441, -642, f + 12), Vector3(549, -636, f + 18), painted)
	box(Vector3(452, -682, f + 44), Vector3(476, -666, f + 44.3), painted)
	box(Vector3(453, -681, f + 44.3), Vector3(475, -667, f + 46.8), paper)
	box(Vector3(452, -682, f + 46.8), Vector3(476, -666, f + 47.1), painted)


## Peças pintadas nos cantos de cada sala (BuildCornerDressing): no piso, de frente; ou na parede do lado.
func _corner_dressing() -> void:
	var items := [
		["characters", "Preparation_Backpack", Vector3(15, -520, -520), 60.0, 66.0, true],
		["characters", "Depot_Container", Vector3(710, -520, -520), 55.0, 55.0 / 1.1509804, true],
		["canteen", "Cantina_Utensils", Vector3(1577, -430, -350), 140.0, 140.0 * 40.94 / 160.0, false],
		["bar", "Cantina_Front", Vector3(810, -570, -520), 65.0, 65.0 * 788.0 / 1380.0, true],
		["bar", "CharactersRoom_Notice", Vector3(1543, -280, -380), 60.0, 60.0 * 536.0 / 354.0, false],
		["dormitory", "Preparation_Backpack", Vector3(-1160, -520, -520), 60.0, 66.0, true],
		["dormitory", "Dormitory_PersonalPegs", Vector3(-57, -560, -390), 80.0, 80.0 * 1037.0 / 1112.0, false],
		["forge", "Forge_ToolRack", Vector3(1177, -340, -885), 180.0, 180.0 / 1.7597173, false],
		["forge", "Depot_Container", Vector3(2050, -600, -1040), 50.0, 50.0 / 1.1509804, true],
		["depot", "Depot_Container", Vector3(620, -520, -940), 60.0, 60.0 / 1.1509804, true],
		["depot", "Preparation_Backpack", Vector3(1110, -520, -940), 50.0, 55.0, true],
		["research", "Depot_Container", Vector3(-570, -520, -940), 60.0, 60.0 / 1.1509804, true],
		["preparation", "Preparation_Backpack", Vector3(2200, -520, -940), 50.0, 55.0, true],
		["preparation", "Dormitory_PersonalPegs", Vector3(2743, -560, -810), 80.0, 80.0 * 1037.0 / 1112.0, false],
	]
	for item in items:
		var start := b.mark()
		var left_wall: bool = item[0] == "canteen" or item[0] == "forge"
		var right := Vector3(1, 0, 0) if item[5] else Vector3(0, 1.0 if left_wall else -1.0, 0)
		b.card(item[1], item[2], item[3], item[4], false, right)
		if item[5]:
			b.contact(item[2], Vector2(item[3] * 1.25, 45), 0.35)
		_tag_dressing(item[0], start)


## Os armários baixos das laterais de cada sala (BuildRoomReturns): caixa, tampo, a frente pintada e um objeto em cima.
func _room_returns() -> void:
	var plans := [
		["characters", -40.0, 760.0, -520.0, 80.0, 360.0, 140.0, 1380.0 / 788.0],
		["canteen", 1560.0, 2760.0, -520.0, 90.0, 400.0, 140.0, 1380.0 / 788.0],
		["bar", 760.0, 1560.0, -520.0, 90.0, 360.0, 275.0, 222.0 / 60.55],
		["dormitory", -1240.0, -40.0, -520.0, 85.0, 400.0, 140.0, 1380.0 / 788.0],
		["depot", 560.0, 1160.0, -940.0, 60.0, 340.0, 90.0, 340.0 / 286.0],
		["research", -640.0, 560.0, -940.0, 90.0, 450.0, 210.0, 1786.0 / 683.0],
		["preparation", 2160.0, 2760.0, -940.0, 65.0, 360.0, 210.0, 1786.0 / 683.0],
	]
	for p in plans:
		var start := b.mark()
		var height: float = p[6] / p[7]
		var top: float = p[3] + height + 4
		var metal: bool = ["depot", "research", "preparation"].has(p[0])
		var body := S("Metal021", p[3], 0, Color(0.55, 0.55, 0.42)) if metal else S("wood_table_worn", p[3], 0, Color(0.55, 0.45, 0.34))
		var worktop := S("metal_plate", p[3], 0, Color(0.27, 0.27, 0.18)) if metal else S("wood_table_worn", p[3], 0, Color(0.42, 0.38, 0.33))
		var front := "Forge_BenchFront" if metal else "Cantina_Front"
		for left in [true, false]:
			var wall: float = p[1] + 15 if left else p[2] - 15
			var a: float = wall if left else wall - p[4]
			var c: float = a + p[4]
			var mid := (a + c) * 0.5
			box(Vector3(a, -p[5], p[3]), Vector3(c, 0, top - 4), body, false)
			box(Vector3(a, -p[5], top - 4), Vector3(c, 0, top), worktop, false)
			# A frente pintada repetida ao longo do armário, virada para dentro da sala.
			var tiles := maxi(1, roundi(p[5] / (height * p[7])))
			var tile_width: float = p[5] / tiles
			for tile in tiles:
				var y: float = -p[5] + tile_width * (tile + 0.5)
				b.card(front, Vector3(c + 0.2 if left else a - 0.2, y, p[3]), tile_width, height, false, Vector3(0, 1.0 if left else -1.0, 0))
			b.contact(Vector3(mid, -p[5] * 0.5, p[3]), Vector2(p[4] + 6, p[5] - 2), 0.3)
			var y_prop: float = -p[5] * 0.62
			match p[0]:
				"bar":
					b.card("Bar_Bottle0" if left else "Bar_Bottle2", Vector3(mid - 10, y_prop, top), 16.17 if left else 16.68, 28.0 if left else 30.0)
					b.card("Bar_Bottle1" if left else "Bar_Bottle3", Vector3(mid + 12, y_prop - 5, top), 9.23 if left else 9.69, 34.0 if left else 32.0)
				"characters", "depot":
					b.card("Preparation_Backpack" if left == (p[0] == "characters") else "Preparation_Crate", Vector3(mid, y_prop, top),
						35.0 if left == (p[0] == "characters") else 46.0, 35.0 * 1240.0 / 1125.0 if left == (p[0] == "characters") else 46.0 * 380.0 / 410.0)
				"preparation":
					b.card("Preparation_Crate" if left else "Forge_Toolbox", Vector3(mid, y_prop, top), 46.0 if left else 42.0,
						46.0 * 380.0 / 410.0 if left else 42.0 * 703.0 / 1439.0)
		_tag_dressing(p[0], start)
