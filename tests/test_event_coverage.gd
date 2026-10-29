## A cobertura dos eventos de busca por mapa (#78, decisão do Lucas: 4 eventos próprios por lugar, mais os genéricos).
## Cada fase sorteia de pelo menos 4 eventos só dela, e cada um deles cabe num objeto que existe de verdade nos mapas
## da fase (a rua: os pontos das casas; as outras: os props da travessia e do mapa da fase). Nenhum evento próprio fica
## sem objeto, e os ids de antes continuam.
extends RefCounted

const R = preload("res://scripts/flow/journey_rules.gd")
## Os eventos de busca de antes da #78: os ids nunca mudam (saves e testes os guardam).
const OLD := ["busca_caixa_sanitaria", "busca_cano_rompido", "busca_mochila", "busca_barricada", "busca_choro_porta",
	"busca_poco_escuro", "busca_sala_esporos"]
const OWN_PER_PLACE := 4

var t


func run(context) -> void:
	t = context
	for id in OLD:
		t.check(GameData.row("events", id) != null, "o evento antigo %s continua" % id)
	for phase in R.PHASES:
		_phase(phase)


## Os objetos de cada mapa da fase: [mapa, nome].
func _objects(phase: Dictionary) -> Array:
	var out: Array = []
	if String(phase.map) == "":
		for shop in R.SPOT_NAMES:
			for name in shop:
				out.append(["Rua", name])
		return out
	for map in [String(phase.transit), String(phase.map)]:
		if map == "":
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/%s.json" % map))
		for prop in data.props:
			out.append([map, String(prop.name)])
	return out


func _phase(phase: Dictionary) -> void:
	var place := String(phase.scenario)
	var own: Array = []
	for id in GameData.table("events"):
		if String(id).begins_with("busca_") and GameData.row("events", id).get("Places", []) == [place]:
			own.append(id)
	var reached := {}
	var by_map := {}
	for object in _objects(phase):
		for id in R.event_pool(place, R.object_kind(object[1])):
			if own.has(id):
				reached[id] = true
				by_map[object[0]] = by_map.get(object[0], {})
				by_map[object[0]][id] = true
	t.check(own.size() >= OWN_PER_PLACE, "%s tem %d eventos só dela (pelo menos %d)" % [phase.name, own.size(), OWN_PER_PLACE])
	t.check(reached.size() >= OWN_PER_PLACE, "%s sorteia de %d eventos próprios: %s" % [phase.name, reached.size(), reached.keys()])
	var dead: Array = own.filter(func(id): return not reached.has(id))
	t.equal(dead, [], "%s: todo evento próprio cabe num objeto dos mapas dela" % phase.name)
	for map in by_map:
		t.check(by_map[map].size() >= 1, "%s: o mapa %s abre eventos da fase (%s)" % [phase.name, map, by_map[map].keys()])
	var maps: Array = ["Rua"] if String(phase.map) == "" else [phase.transit, phase.map].filter(func(m): return String(m) != "")
	for map in maps:
		t.check(by_map.has(map), "%s: o mapa %s tem objeto com evento da fase" % [phase.name, map])
