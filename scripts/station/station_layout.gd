## A Estação em grade na cena (#186; a cena, #273): onde cada cômodo, cada bloco soterrado e cada vaga livre ficam, a
## partir da grade da campanha (AHStationGrid). Medidas em cm e nos eixos da Unreal, como a montagem (station_build.gd):
## X para a direita, Y para o fundo negativo, Z para cima.
##
## A grade tem 3 subsolos de 7 vagas de 6 m (3,2 m de altura), da ponta esquerda até a parede da escada (STATION_END). O
## mobiliário de cada cômodo continua escrito onde ele ficava (o "molde" do cômodo); a montagem desloca tudo pelo
## offset até a vaga dele. A Cantina e o Depósito no nível 1 (o fogareiro e os caixotes) e a Preparação ficam na
## plataforma, fora da grade.
class_name AHStationLayout
extends RefCounted

const SLOT := 600.0
const STATION_END := 2760.0
const GRID_X0 := STATION_END - SLOT * 7
const FLOOR_Z := [-520.0, -940.0, -1360.0]
const HEIGHT := 320.0
const PLATFORM_HEIGHT := 300.0
## A profundidade em que os moradores andam: nos cômodos (a faixa de passeio da Unreal, Y -330) e na plataforma, à
## frente dos bancos e longe da beira.
const LANE_Y := -330.0
const PLATFORM_LANE_Y := -760.0

## O molde de cada cômodo: a extensão em X, o piso e a porta do fundo (a borda esquerda do vão de 120 cm) onde o
## mobiliário dele foi escrito, e a faixa livre de passeio. A largura é a da vaga (6 m ou 12 m): o Alojamento e o Bar
## encolheram para 6 m, a Forja cresceu para 12 m e baixou 1 m, e a Enfermaria tem os 12 m do #139.
const TEMPLATES := {
	"characters": {"x0": 60.0, "floor": -520.0, "door": 80.0, "lane": [170.0, 520.0]},
	"bar": {"x0": 860.0, "floor": -520.0, "door": 880.0, "lane": [990.0, 1330.0]},
	"canteen": {"x0": 1560.0, "floor": -520.0, "door": 1700.0, "lane": [1720.0, 2560.0]},
	"dormitory": {"x0": -1240.0, "floor": -520.0, "door": -210.0, "lane": [-1090.0, -190.0]},
	"forge": {"x0": 1060.0, "floor": -940.0, "door": 1280.0, "lane": [1240.0, 2080.0]},
	"depot": {"x0": 560.0, "floor": -940.0, "door": 680.0, "lane": [720.0, 1030.0]},
	"research": {"x0": -640.0, "floor": -940.0, "door": 390.0, "lane": [-490.0, 410.0]},
	"infirmary": {"x0": -1840.0, "floor": -940.0, "door": -1400.0, "lane": [-1720.0, -760.0]},
}

## Os cantos da plataforma (fora da grade, à direita do vagão parado): o fogareiro entre os dois bancos (a Cantina
## improvisada), a Preparação diante do Mapa da Rede e os caixotes entre o Mapa e a porta escondida (o Depósito
## improvisado; a parede falsa desliza atrás deles).
const PLATFORM := {
	"canteen": {"x0": 1060.0, "x1": 1520.0, "lane": [1110.0, 1470.0]},
	"preparation": {"x0": 1520.0, "x1": 1860.0, "lane": [1560.0, 1820.0]},
	"depot": {"x0": 1860.0, "x1": 2140.0, "lane": [1890.0, 2110.0]},
}


static func slot_x0(slot: int) -> float:
	return GRID_X0 + (slot - 1) * SLOT


static func floor_z(floor_number: int) -> float:
	return FLOOR_Z[floor_number - 1]


## O cômodo está numa vaga da grade (os outros que existem ficam na plataforma).
static func _in_grid(campaign: Dictionary, room_id: String) -> bool:
	return _has_grid(campaign) and AHStationGrid.placed(campaign, room_id)


static func _has_grid(campaign: Dictionary) -> bool:
	var station = campaign.get("station", {})
	return typeof(station) == TYPE_DICTIONARY and typeof(station.get("grid")) == TYPE_DICTIONARY \
		and typeof(station.grid.get("cells")) == TYPE_ARRAY


## Onde fica o cômodo (cm): {id, x0, x1, floor, ceiling, door, lane, lane_y, offset, place ("grid" ou "platform"),
## floor_number, slot}; {} se ele ainda não tem lugar (soterrado, sem vaga).
static func room(campaign: Dictionary, room_id: String) -> Dictionary:
	if _in_grid(campaign, room_id):
		var spot := AHStationGrid.room_spot(campaign, room_id)
		var f := AHStationGrid.block_floor(spot)
		var k := AHStationGrid.block_slot(spot)
		var template: Dictionary = TEMPLATES.get(room_id, {})
		var x0 := slot_x0(k)
		var z := floor_z(f)
		var width := SLOT * maxi(1, AHStationGrid.room_slots(room_id))
		var dx: float = x0 - float(template.get("x0", x0))
		var dz: float = z - float(template.get("floor", z))
		var lane: Array = template.get("lane", [x0 - dx + 150.0, x0 - dx + width - 150.0])
		return {"id": room_id, "x0": x0, "x1": x0 + width, "floor": z, "ceiling": z + HEIGHT,
			"door": float(template.get("door", x0 - dx + 120.0)) + dx, "lane": [lane[0] + dx, lane[1] + dx],
			"lane_y": LANE_Y, "offset": Vector3(dx, 0, dz), "place": "grid", "floor_number": f, "slot": k}
	if PLATFORM.has(room_id) and (room_id == AHStationRules.PREPARATION or AHStationRules.room_level(campaign, room_id) >= 1):
		var nook: Dictionary = PLATFORM[room_id]
		return {"id": room_id, "x0": nook.x0, "x1": nook.x1, "floor": 0.0, "ceiling": PLATFORM_HEIGHT, "door": NAN,
			"lane": nook.lane.duplicate(), "lane_y": PLATFORM_LANE_Y, "offset": Vector3.ZERO, "place": "platform",
			"floor_number": 0, "slot": 0}
	return {}


## Todos os cômodos com lugar, na ordem de AHStationRules.ROOMS.
static func rooms(campaign: Dictionary) -> Array:
	var out: Array = []
	for entry in AHStationRules.ROOMS:
		var placed := room(campaign, entry.id)
		if not placed.is_empty():
			out.append(placed)
	return out


## O deslocamento (cm) do molde do cômodo até a vaga dele (zero na plataforma ou sem lugar).
static func offset(campaign: Dictionary, room_id: String) -> Vector3:
	var placed := room(campaign, room_id)
	return placed.get("offset", Vector3.ZERO) if not placed.is_empty() else Vector3.ZERO


## As vagas sem cômodo (cm): {key, floor_number, slot, x0, x1, floor, ceiling, state ("buried", "digging" ou "free"),
## stage (0, 1 ou 2: a escavação em um terço ou dois terços) e from (o lado aberto de onde se cava: 1 direita, -1
## esquerda)}.
static func blocks(campaign: Dictionary) -> Array:
	var out: Array = []
	if not _has_grid(campaign):
		return out
	for f in range(1, AHStationGrid.FLOORS + 1):
		for k in range(1, AHStationGrid.SLOTS + 1):
			var value := AHStationGrid.cell(campaign, f, k)
			if value != "" and value != AHStationGrid.FREE:
				continue
			var key := "%d:%d" % [f, k]
			var entry := {"key": key, "floor_number": f, "slot": k, "x0": slot_x0(k), "x1": slot_x0(k) + SLOT,
				"floor": floor_z(f), "ceiling": floor_z(f) + HEIGHT, "state": "free" if value == AHStationGrid.FREE else "buried",
				"stage": 0, "from": 1}
			if value == "":
				# A obra começada fica à vista mesmo com a frente trocada (a regra guarda o que já foi cavado).
				var stage := dig_stage(campaign, key)
				if stage > 0:
					entry.state = "digging"
					entry.stage = stage
				entry.from = 1 if k == AHStationGrid.SLOTS or AHStationGrid.cell(campaign, f, k + 1) != "" else -1
			out.append(entry)
	return out


## Quanto da obra o bloco já tem, em terços (0: nada; 1: um terço ou mais; 2: dois terços ou mais).
static func dig_stage(campaign: Dictionary, key: String) -> int:
	var done := AHStationGrid.block_progress(campaign, key)
	if done <= 0:
		return 0
	return 2 if done * 3 >= AHStationGrid.block_work(key) * 2 else 1


## O patamar do andar (2 ou 3) está aberto.
static func landing_open(campaign: Dictionary, floor_number: int) -> bool:
	if floor_number <= 1:
		return true
	if not _has_grid(campaign):
		return floor_number == 2
	return AHStationGrid.block_open(campaign, "L%d" % floor_number)


## O que a cena mostra da grade, numa linha: muda quando um bloco abre, a escavação passa de um terço, um cômodo é
## construído ou a Cantina e o Depósito saem da plataforma (a cena remonta só então).
static func signature(campaign: Dictionary) -> String:
	if not _has_grid(campaign):
		return ""
	var parts: Array = [JSON.stringify(campaign.station.grid.cells), JSON.stringify(campaign.station.grid.landings)]
	for entry in blocks(campaign):
		parts.append("%s=%s%d" % [entry.key, entry.state, entry.stage])
	for room_id in [AHStationRules.CANTEEN, AHStationRules.DEPOT]:
		parts.append("%s%d" % [room_id, mini(AHStationRules.room_level(campaign, room_id), 1)])
	return "|".join(parts)


## Em metros da Godot, para a câmera e os moradores (station.gd): {id, x0, x1, floor, ceiling, lane, z, work_z, place}.
static func to_meters(placed: Dictionary) -> Dictionary:
	if placed.is_empty():
		return {}
	var lane_z: float = placed.lane_y * 0.01
	return {"id": placed.id, "x0": placed.x0 * 0.01, "x1": placed.x1 * 0.01, "floor": placed.floor * 0.01,
		"ceiling": placed.ceiling * 0.01, "lane": [placed.lane[0] * 0.01, placed.lane[1] * 0.01], "z": lane_z,
		"work_z": lane_z - 2.3 if placed.place == "grid" else lane_z - 0.8, "place": placed.place,
		"offset": AHStationBuilder.vu(placed.offset)}
