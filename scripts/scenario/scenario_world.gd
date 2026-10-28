## Monta um mapa de cenário da Unreal a partir de data/scenarios/<Mapa>.json (tools/sync_scenarios.py): as peças com as
## malhas e os materiais de lá, as luzes e os textos. Guarda as zonas caminháveis, as portas dos interiores laterais e
## os props vasculháveis, que o corredor usa. As peças fixas viram uma malha por material (como na Estação).
class_name AHScenarioWorld
extends Node3D

const MESHES := "res://data/scenarios/meshes.json"
## A Unreal mede a luz em lúmens; a mesma escala da Estação.
const LUMENS_PER_ENERGY := 260.0
## A folga da marca de interação acima do desenho do prop (m).
const MARKER_LIFT := 0.35
## Brilho dos cards de fundo (unlit, Emissive 0,5 na Unreal, sem adaptação de exposição): calibrado na tela.
const CARD_BRIGHTNESS := 1.7

## A folga acima da borda da frente ao subir o chão da luta.
const FRONT_LIFT_MARGIN := 0.06
## A borda da frente mais alta que ainda conta como piso (acima disso é parede, e a silhueta vale).
const FRONT_EDGE_MAX := 0.6

static var _mesh_cache: Array = []

var map_name := ""
var display_name := ""
var data := {}
var zones: Array = []
## Os obstáculos na faixa de passeio de cada zona (caixas do mundo): o que é sólido na Unreal, entre o piso e a altura
## da equipe, sem fechar a faixa inteira (sempre sobra passagem).
var obstacles: Array[AABB] = []
## As peças opacas (caixas do mundo) que podem ficar entre a câmera da luta e os pés de quem luta (#48).
var walls: Array[AABB] = []
var side_doors: Array = []
var props: Array = []
var _materials: Array = []
var _open_materials := {}
var _prop_nodes := {}
var _cards: Array[ShaderMaterial] = []
## A água pintada (#140): a do chão e a do fundo pintado; "Reduzir efeitos" a deixa mais lenta e sem piscar.
var _waters: Array[ShaderMaterial] = []
const WATER_COVERED := 0.3
## O que a água pintada guarda de espuma (os arrays do water_painted.gdshader).
const MAX_FOAM_POINTS := 16
const MAX_FOAM_LINES := 4
## As portas de dentro dos interiores (#141): a vista de fora (o material) e a luz que entra, por zona. Não escurecem com
## o interior: são o lado de fora, com a hora e a chuva de lá (set_doorways).
var _door_views: Array[ShaderMaterial] = []
## As zonas cobertas que já ganharam as colunas das pontas (close_zone_ends).
var _closed_zones: Array[int] = []
var _door_lights: Array[OmniLight3D] = []
var doorway_zones: Array[int] = []
## A luz de fora pela porta: a cor e a força no fim de tarde e na noite; a chuva tira um pouco e acinzenta.
const DOOR_LIGHT := {"golden": [Color(1.0, 0.8, 0.58), 1.7], "night": [Color(0.55, 0.65, 0.92), 0.8]}
const DOOR_RAIN_LIGHT := 0.7
## Fora é mais claro que a sala: a vista da porta brilha um pouco acima da cor do clima.
const DOOR_VIEW_BRIGHTNESS := {"golden": 1.25, "night": 0.75}
## A cor da hora de fora na vista: o céu do mapa é de dia, e o fim de tarde lá fora é pêssego (a mesma luz do cais).
const DOOR_VIEW_TINT := {"golden": Color(1.0, 0.76, 0.58), "night": Color(0.55, 0.6, 0.75)}
## As colunas que fecham as pontas de uma zona coberta (#175), na frente da faixa (m): a largura, a altura (do piso
## menos END_CAP_BELOW) e quanto ficam na frente da borda da zona.
const END_CAP_WIDTH := 2.0
const END_CAP_HEIGHT := 5.6
const END_CAP_BELOW := 1.0
const END_CAP_FRONT := 0.4
var _blockouts: Array[ShaderMaterial] = []


const DISPLAY := {"RootBridge": "Ponte das Raízes", "RiverDock": "Cais do Rio", "FloodedDepot": "Depósito Inundado",
	"SealedShelter": "Abrigo Lacrado", "SewerDucts": "Dutos de Esgoto", "TriageGate": "Portão de Triagem"}

## Ajustes de luz de cada local ao ar livre (AHWeatherSite dos scripts de ajuste da Unreal): a lua e o céu têm um
## mínimo, para a noite continuar legível, e a neblina rende. Os cenários fechados ficam com as luminárias do mapa.
const SITES := {
	"RiverDock": {"min_sun": 1.2, "min_night_sun": 1.4, "min_ambient": 0.75, "min_elevation": 35.0, "fog_scale": 0.5},
	"RootBridge": {"min_sun": 1.2, "min_night_sun": 1.4, "min_ambient": 0.75, "min_elevation": 0.0, "fog_scale": 0.35},
	"TriageGate": {"min_sun": 1.2, "min_night_sun": 1.4, "min_ambient": 0.75, "min_elevation": 40.0, "fog_scale": 0.6},
}


## O nome do mapa na tela, já no idioma do jogo (#35).
static func display_of(map: String) -> String:
	return TranslationServer.translate(DISPLAY.get(map, "Rua das Vitrines"))


static func exists(map: String) -> bool:
	return FileAccess.file_exists("res://data/scenarios/%s.json" % map)


func build(map: String) -> void:
	map_name = map
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/%s.json" % map))
	display_name = data.display
	zones = data.zones
	side_doors = data.side_doors
	props = data.props
	if _mesh_cache.is_empty():
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MESHES))
		for mesh in raw.meshes:
			_mesh_cache.append(_build_mesh(mesh))
	for material in data.materials:
		_materials.append(_material(material))
	var prop_parts := {}
	for index in props.size():
		for part in props[index].parts:
			prop_parts[int(part)] = index
	var merge := {}
	for i in data.parts.size():
		var part: Dictionary = data.parts[i]
		if part.get("hidden", false):
			continue
		var node := MeshInstance3D.new()
		node.mesh = _mesh_cache[int(part.mesh)]
		var b: Array = part.basis
		node.transform = Transform3D(Basis(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), Vector3(b[6], b[7], b[8])),
			Vector3(part.origin[0], part.origin[1], part.origin[2]))
		for surface in node.mesh.get_surface_count():
			var index: int = int(part.materials[mini(surface, part.materials.size() - 1)])
			node.set_surface_override_material(surface, _materials[index])
		if part.get("no_shadow", false) or data.materials[int(part.materials[0])].kind in ["card", "unlit", "water", "glow"]:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		if not data.materials[int(part.materials[0])].kind in ["card", "unlit", "water", "glow"] \
				and not data.materials[int(part.materials[0])].get("masked", false):
			walls.append(node.transform * node.mesh.get_aabb())
		if part.get("solid", false):
			_add_obstacle(node.transform * node.mesh.get_aabb())
		if prop_parts.has(i):
			if not _prop_nodes.has(prop_parts[i]):
				_prop_nodes[prop_parts[i]] = []
			_prop_nodes[prop_parts[i]].append(node)
		elif node.mesh.get_surface_count() == 1 and data.materials[int(part.materials[0])].kind != "water" \
				and not _in_front(node.transform * node.mesh.get_aabb()):
			var key := [int(part.mesh), int(part.materials[0]), node.cast_shadow]
			if not merge.has(key):
				merge[key] = []
			merge[key].append(node)
	_merge(merge)
	for light in data.lights:
		_light(light)
	for text in data.texts:
		_text(text)
	for doorway in data.get("doorways", []):
		_doorway(doorway)
	for layered in data.get("layered_cards", []):
		_layered_card(layered)


## Fecha as pontas de uma zona coberta (#175): uma coluna de cada lado, na frente da faixa e por fora da parede do
## lado, com a arte dessa parede. A câmera da zona coberta mostra um pouco além da ponta (a equipe não encosta na borda
## do quadro) e lá, em vez do vazio por fora da sala, fica a parede.
func close_zone_ends(index: int) -> void:
	if _closed_zones.has(index):
		return
	_closed_zones.append(index)
	var zone: Dictionary = zones[index]
	for side in [-1.0, 1.0]:
		var edge: float = float(zone.x0) if side < 0.0 else float(zone.x1)
		var box := BoxMesh.new()
		box.size = Vector3(END_CAP_WIDTH, END_CAP_HEIGHT, 0.4)
		var cap := MeshInstance3D.new()
		cap.name = "ZoneEnd_%d_%s" % [index, "left" if side < 0.0 else "right"]
		cap.mesh = box
		cap.material_override = _end_material(edge)
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cap.position = Vector3(edge + side * (END_CAP_WIDTH * 0.5 + 0.1), float(zone.y) - END_CAP_BELOW + END_CAP_HEIGHT * 0.5,
			float(zone.z1) + END_CAP_FRONT)
		add_child(cap)


## A arte da parede do lado nessa ponta (a peça alta e fina junto dela), ou a primeira superfície do mapa.
func _end_material(edge: float) -> Material:
	for part in data.parts:
		var b: Array = part.basis
		if not part.get("hidden", false) and absf(float(part.origin[0]) - edge) < 0.8 and absf(b[0]) < 0.7 and absf(b[4]) >= 2.5 \
				and absf(b[8]) >= 3.0:
			return _materials[int(part.materials[0])]
	for i in data.materials.size():
		if data.materials[i].kind == "surface":
			return _materials[i]
	return _materials[0]


## As cores da água pintada (#140) que o mapa troca (surface, mid, deep, ripple e foam, em [r, g, b]) e o passo
## dela: com "Reduzir efeitos", mais devagar e sem o brilho piscando.
func _water_colors(material: ShaderMaterial, m: Dictionary) -> void:
	for key in ["surface", "mid", "deep", "ripple", "foam", "horizon"]:
		var c = m.get(key + "_color")
		if c != null:
			material.set_shader_parameter(key + "_color", Color(c[0], c[1], c[2]))
	_water_pace(material)


func _water_pace(material: ShaderMaterial) -> void:
	var reduced: bool = GameFlow.reduced_effects()
	material.set_shader_parameter("flow", 0.4 if reduced else 1.0)
	material.set_shader_parameter("sparkle", 0.0 if reduced else 1.0)


## A opção "Reduzir efeitos" mudou: a água pintada acompanha.
func refresh_water_pace() -> void:
	for material in _waters + _door_views:
		_water_pace(material)


## Tempo molhado nos materiais (a chuva lá fora) e a cor do clima nos cards de fundo. covered: a equipe num interior; a
## água pintada, sem luz própria, escurece com ele (vista da porta, não brilha ao lado da sala escura).
func set_weather(wet: float, tint: Color, covered: bool = false) -> void:
	for material in _cards:
		material.set_shader_parameter("wet", wet)
		material.set_shader_parameter("weather", Vector4(tint.r, tint.g, tint.b, 1.0))
	if covered:
		for material in _waters:
			material.set_shader_parameter("weather", Vector4(tint.r * WATER_COVERED, tint.g * WATER_COVERED, tint.b * WATER_COVERED, 1.0))
	for material in _blockouts:
		material.set_shader_parameter("wet", wet)


## O lado de fora pelas portas de dentro (#141): a hora (golden ou night) e a chuva de fora, mesmo com a equipe dentro.
func set_doorways(mood: String, raining: bool) -> void:
	var key := mood if DOOR_LIGHT.has(mood) else "golden"
	var tint: Color = DOOR_VIEW_TINT[key]
	for material in _door_views:
		material.set_shader_parameter("weather", Vector4(tint.r, tint.g, tint.b, 1.0))
		material.set_shader_parameter("wet", 1.0 if raining else 0.0)
		material.set_shader_parameter("brightness", DOOR_VIEW_BRIGHTNESS[key])
	var light: Array = DOOR_LIGHT[key]
	for lamp in _door_lights:
		lamp.light_color = (light[0] as Color).lerp(Color(0.62, 0.66, 0.72), 0.5 if raining else 0.0)
		lamp.light_energy = float(light[1]) * (DOOR_RAIN_LIGHT if raining else 1.0)


## A porta de dentro da zona (o spec do mapa) ou um vazio: o interior sem ela entra do jeito antigo, sem a passagem.
func has_doorway(zone: int) -> bool:
	return doorway_zones.has(zone)


## Guarda a caixa se ela atrapalha a passagem em alguma zona: dentro da zona, na altura da equipe, na faixa de passeio
## (os 1,2 m de cada lado do meio) e sem cobrir a faixa inteira.
func _add_obstacle(box: AABB) -> void:
	for zone in zones:
		var lane: float = (zone.z0 + zone.z1) * 0.5
		var band := AABB(Vector3(zone.x0, zone.y + 0.15, lane - 1.2), Vector3(zone.x1 - zone.x0, 1.65, 2.4))
		if not band.intersects(box):
			continue
		var clipped := box.intersection(band)
		if clipped.size.z > 1.6 or box.size.x > 6.0:
			continue
		obstacles.append(clipped)
		return


## O ponto da marca de interação do prop (#142): o meio de cima do desenho dele, um palmo acima, como o marker_point
## dos objetos de busca da Rua. Sem peça montada (o prop só com o x), na altura de uma cômoda na faixa da zona.
func prop_marker_point(index: int) -> Vector3:
	var box := AABB()
	var first := true
	for node: MeshInstance3D in _prop_nodes.get(index, []):
		var part := node.global_transform * node.mesh.get_aabb() if node.is_inside_tree() else node.transform * node.mesh.get_aabb()
		# A primeira peça começa a caixa (uma carta de fundo é plana: sem volume, mas conta).
		box = part if first else box.merge(part)
		first = false
	if first:
		var zone := zone_at(float(props[index].x))
		var y: float = zones[zone].y if zone >= 0 else 0.0
		return Vector3(float(props[index].x), y + 1.9, -0.7)
	return Vector3(box.get_center().x, box.end.y + MARKER_LIFT, box.end.z)


## O prop vasculhado mostra a versão aberta (o material _Open da Unreal).
func open_prop(index: int) -> void:
	var prop: Dictionary = props[index]
	if int(prop.open) < 0 or not _prop_nodes.has(index):
		return
	for node: MeshInstance3D in _prop_nodes[index]:
		for surface in node.mesh.get_surface_count():
			node.set_surface_override_material(surface, _materials[int(prop.open)])


## Quanto o chão da luta sobe na zona para os pés ficarem acima da borda da frente (#48). A câmera da luta é quase
## reta: a linha de visão até o pé sobe slope metros por metro de profundidade. Uma peça na frente (z maior que feet_z),
## dentro da zona e mais alta que o piso cobre o pé quando a altura dela passa da linha; o chão sobe o que falta, com
## uma folga. Sem peça na frente, 0 (os outros cenários ficam iguais).
func front_lift(zone_index: int, feet_z: float, slope: float) -> float:
	var zone: Dictionary = zones[zone_index]
	var lift := 0.0
	for box in walls:
		var depth: float = box.position.z - feet_z
		if depth < 0.3 or box.end.x <= zone.x0 or box.position.x >= zone.x1:
			continue
		var above: float = box.end.y - zone.y
		if above <= 0.01 or box.position.y > zone.y + 3.0:
			continue
		lift = maxf(lift, above - slope * depth + FRONT_LIFT_MARGIN)
	return lift


## A altura (m acima do piso) da borda baixa mais alta na frente da faixa da zona: o que encobre os pés de quem anda
## (a silhueta não pinta essa faixa, #51). Só as peças baixas (até FRONT_EDGE_MAX) contam; o resto tapa de verdade.
func front_edge(zone_index: int, feet_z: float) -> float:
	var zone: Dictionary = zones[zone_index]
	var edge := 0.0
	for box in walls:
		if box.position.z - feet_z < 0.05 or box.end.x <= zone.x0 or box.position.x >= zone.x1:
			continue
		var above: float = box.end.y - zone.y
		if above > 0.0 and above <= FRONT_EDGE_MAX:
			edge = maxf(edge, above)
	return edge


## Se o chão neste ponto está debaixo d'água (uma peça de água do mapa cobre o ponto, entre o chão e um pouco acima).
func water_floor(point: Vector3) -> bool:
	for part in data.parts:
		if part.get("hidden", false) or data.materials[int(part.materials[0])].kind != "water":
			continue
		var b: Array = part.basis
		var transform := Transform3D(Basis(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), Vector3(b[6], b[7], b[8])),
			Vector3(part.origin[0], part.origin[1], part.origin[2]))
		var box: AABB = (transform * _mesh_cache[int(part.mesh)].get_aabb()).grow(0.05)
		if box.position.x <= point.x and point.x <= box.end.x and box.position.z <= point.z and point.z <= box.end.z \
				and box.end.y > point.y and box.position.y < point.y + 1.0:
			return true
	return false


## A zona (0..n) que contém x, ou -1.
func zone_at(x: float) -> int:
	for i in zones.size():
		if x >= zones[i].x0 - 0.01 and x <= zones[i].x1 + 0.01:
			return i
	return -1


# ---------------------------------------------------------------- malhas e materiais

static func _build_mesh(raw: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for section in raw.sections:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		var v: Array = section.vertices
		var n: Array = section.normals
		var t: Array = section.uvs
		for i in range(0, v.size(), 3):
			vertices.append(Vector3(v[i], v[i + 1], v[i + 2]))
			normals.append(Vector3(n[i], n[i + 1], n[i + 2]))
		for i in range(0, t.size(), 2):
			uvs.append(Vector2(t[i], t[i + 1]))
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(section.triangles)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _tex(path: String) -> Texture2D:
	return load(path) if path != "" and ResourceLoader.exists(path) else null


func _material(m: Dictionary) -> Material:
	match m.kind:
		"blockout":
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/scenario_blockout.gdshader")
			var albedo := _tex(m.get("albedo", ""))
			if albedo:
				material.set_shader_parameter("albedo_tex", albedo)
			var c: Array = m.get("color", [1, 1, 1, 1])
			material.set_shader_parameter("color", Color(c[0], c[1], c[2]))
			material.set_shader_parameter("tile_size", float(m.get("tile", 140.0)) * 0.01)
			material.set_shader_parameter("roughness_value", float(m.get("roughness", 0.8)))
			_blockouts.append(material)
			return material
		"surface":
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/station_surface.gdshader")
			var albedo := _tex(m.get("albedo", ""))
			if albedo:
				material.set_shader_parameter("albedo_tex", albedo)
			var normal := _tex(m.get("normal", ""))
			if normal:
				material.set_shader_parameter("normal_tex", normal)
				material.set_shader_parameter("use_normal", true)
			var c: Array = m.get("tint", [1, 1, 1, 1])
			material.set_shader_parameter("tint", Vector3(c[0], c[1], c[2]))
			material.set_shader_parameter("tile_size", float(m.get("tile", 200.0)) * 0.01)
			material.set_shader_parameter("damp_amount", float(m.get("damp", 0.0)))
			return material
		"card", "unlit":
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/scenario_card.gdshader")
			# O fundo pintado com água (#140): abaixo da linha d'água, a água viva no lugar da pintura parada.
			if m.get("waterline") != null:
				material.shader = preload("res://shaders/scenario_card_water.gdshader")
				material.set_shader_parameter("waterline", float(m.waterline))
				material.set_shader_parameter("width_m", float(m.get("width_m", 75.0)))
				material.set_shader_parameter("far_m", float(m.get("far_m", 60.0)))
				material.set_shader_parameter("detail", float(m.get("detail", 0.4)))
				_water_colors(material, m)
				_waters.append(material)
			var albedo := _tex(m.get("albedo", ""))
			if albedo:
				material.set_shader_parameter("albedo_tex", albedo)
			if m.kind == "card":
				material.set_shader_parameter("brightness", float(m.get("emissive", 0.5)) * 2.0 * CARD_BRIGHTNESS * 0.5)
				material.set_shader_parameter("haze", float(m.get("haze", 0.0)))
				var hc: Array = m.get("haze_color", [0.55, 0.52, 0.48, 1])
				material.set_shader_parameter("haze_color", Color(hc[0], hc[1], hc[2]))
			else:
				material.set_shader_parameter("brightness", float(m.get("gain", 1.0)) * (0.6 if m.get("sky", false) else 1.0))
			_cards.append(material)
			return material
		"water":
			var material := ShaderMaterial.new()
			if m.get("painted", false):
				# A água pintada (#140): as faixas, as ondinhas desenhadas, o brilho e a espuma na margem e nas estacas.
				material.shader = preload("res://shaders/water_painted.gdshader")
				material.set_shader_parameter("front_z", float(m.get("front_z", 0.0)))
				material.set_shader_parameter("depth_scale", float(m.get("depth_scale", 18.0)))
				var lines: Array = m.get("foam_lines", [])
				var points: Array = m.get("foam_points", [])
				if lines.size() > MAX_FOAM_LINES or points.size() > MAX_FOAM_POINTS:
					push_warning("%s: a água pintada guarda %d linhas e %d pontos de espuma; o resto some (%d e %d no mapa)." % [
						map_name, MAX_FOAM_LINES, MAX_FOAM_POINTS, lines.size(), points.size()])
				var packed := Vector4(-9999, -9999, -9999, -9999)
				for i in mini(MAX_FOAM_LINES, lines.size()):
					packed[i] = float(lines[i])
				material.set_shader_parameter("foam_lines", packed)
				material.set_shader_parameter("line_foam_width", float(m.get("line_foam_width", 0.9)))
				var list: Array[Vector4] = []
				for point in points.slice(0, MAX_FOAM_POINTS):
					list.append(Vector4(float(point[0]), float(point[1]), float(point[2]), 0.0))
				while list.size() < MAX_FOAM_POINTS:
					list.append(Vector4.ZERO)
				material.set_shader_parameter("foam_points", list)
				material.set_shader_parameter("foam_count", mini(MAX_FOAM_POINTS, points.size()))
				_water_colors(material, m)
				_waters.append(material)
				_cards.append(material)
				return material
			material.shader = preload("res://shaders/water_waves.gdshader")
			for key in [["Amplitude", "amplitude"], ["Wavelength", "wavelength"], ["Speed", "speed"], ["Foam", "foam"],
					["RippleStrength", "ripple"], ["Roughness", "roughness_value"], ["Specular", "specular_value"]]:
				if m.get(key[0]) != null:
					material.set_shader_parameter(key[1], float(m[key[0]]))
			if m.get("tint") != null:
				material.set_shader_parameter("water_tint", Color(m.tint[0], m.tint[1], m.tint[2]))
			if m.get("foam_tint") != null:
				material.set_shader_parameter("foam_tint", Color(m.foam_tint[0], m.foam_tint[1], m.foam_tint[2]))
			return material
		"glow":
			var material := StandardMaterial3D.new()
			var c: Array = m.get("tint", [1, 0.62, 0.22, 1])
			material.albedo_color = Color(c[0], c[1], c[2])
			material.emission_enabled = true
			material.emission = Color(c[0], c[1], c[2])
			material.emission_energy_multiplier = 3.0
			material.roughness = 0.25
			return material
		"grid":
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.32, 0.32, 0.32)
			material.roughness = 0.9
			return material
	# "art", "facade", "prop": a textura pela UV da malha, com recorte pelo alfa e iluminada.
	var material := StandardMaterial3D.new()
	var albedo := _tex(m.get("albedo", ""))
	if albedo:
		material.albedo_texture = albedo
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.roughness = 0.9
	if m.get("masked", false) or (albedo and albedo.get_image() and albedo.get_image().detect_alpha() != Image.ALPHA_NONE):
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.333
	if m.get("two_sided", false) or m.kind == "facade":
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if m.kind == "prop" and m.get("normal", "") != "":
		material.normal_enabled = true
		material.normal_texture = _tex(m.normal)
		material.uv1_scale = Vector3.ONE
	return material


## A peça fica toda na frente da faixa de andar da zona dela: pode tapar a equipe e esmaece sozinha (#51), por isso
## não se junta às outras.
func _in_front(box: AABB) -> bool:
	var zone := zone_at(box.get_center().x)
	return zone >= 0 and box.position.z > (zones[zone].z0 + zones[zone].z1) * 0.5


func _merge(groups: Dictionary) -> void:
	for key in groups:
		var parts: Array = groups[key]
		if parts.size() < 2:
			continue
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for node: MeshInstance3D in parts:
			tool.append_from(node.mesh, 0, node.transform)
		var combined := MeshInstance3D.new()
		combined.mesh = tool.commit()
		combined.material_override = parts[0].get_surface_override_material(0)
		combined.cast_shadow = key[2]
		# Peças juntadas ficam espalhadas: a caixa delas não diz o que tapa quem (#51).
		combined.set_meta("merged", true)
		add_child(combined)
		for node: MeshInstance3D in parts:
			node.queue_free()


## Uma fachada pintada em camadas (#141): os pedaços da mesma pintura ([u0, v0, u1, v1] e o z de cada um, com a posição
## e o tamanho já corrigidos pela perspectiva; shade escurece o pedaço, a silhueta de trás que dá a espessura) numa malha
## só, com um material só, iluminada como a arte do mapa. Numa malha só, a fachada inteira recebe as mesmas luzes (no
## Compatibility, cada malha pega no máximo 8) e as emendas não mudam de cor.
func _layered_card(spec: Dictionary) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_normal(Vector3(0, 0, 1))
	for piece in spec.pieces:
		var c := Vector3(float(piece.x), float(piece.y), float(piece.z))
		var half := Vector2(float(piece.w), float(piece.h)) * 0.5
		var r: Array = piece.rect
		var corners := [[Vector3(-half.x, half.y, 0), Vector2(r[0], r[1])], [Vector3(half.x, half.y, 0), Vector2(r[2], r[1])],
			[Vector3(half.x, -half.y, 0), Vector2(r[2], r[3])], [Vector3(-half.x, -half.y, 0), Vector2(r[0], r[3])]]
		var shade := float(piece.get("shade", 1.0))
		for i in [0, 1, 2, 0, 2, 3]:
			surface.set_color(Color(shade, shade, shade))
			surface.set_uv(corners[i][1])
			surface.add_vertex(c + corners[i][0])
	var material := StandardMaterial3D.new()
	material.albedo_texture = _tex(String(spec.albedo))
	material.vertex_color_use_as_albedo = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.roughness = 0.9
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.333
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.name = "Layered_%s" % String(spec.get("name", "card"))
	node.mesh = surface.commit()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


## A porta de um interior lateral por dentro (#141): o batente escuro e, por ela, um pedaço do lado de fora (o céu e a
## água pintada do mapa, door_view.gdshader), com a luz de fora entrando. spec: x, y (o piso), z (a parede de trás),
## w e h (o vão), sky (a textura do céu).
func _doorway(spec: Dictionary) -> void:
	var x := float(spec.x)
	var y := float(spec.get("y", 0.0))
	var z := float(spec.z)
	var w := float(spec.get("w", 1.5))
	var h := float(spec.get("h", 2.4))
	var view := ShaderMaterial.new()
	view.shader = preload("res://shaders/door_view.gdshader")
	var sky := _tex(String(spec.get("sky", "")))
	if sky:
		view.set_shader_parameter("sky_tex", sky)
	_water_colors(view, spec)
	_water_pace(view)
	_door_views.append(view)
	doorway_zones.append(int(spec.get("zone", -1)))
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	var outside := MeshInstance3D.new()
	outside.name = "DoorwayView_%d" % roundi(x * 10.0)
	outside.mesh = quad
	outside.material_override = view
	outside.position = Vector3(x, y + h * 0.5, z)
	outside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(outside)
	var frame := StandardMaterial3D.new()
	frame.albedo_color = Color(0.16, 0.13, 0.11)
	frame.roughness = 0.85
	for piece in [[Vector3(x - w * 0.5 - 0.1, y + h * 0.5, z + 0.08), Vector3(0.2, h, 0.25)],
			[Vector3(x + w * 0.5 + 0.1, y + h * 0.5, z + 0.08), Vector3(0.2, h, 0.25)],
			[Vector3(x, y + h + 0.1, z + 0.08), Vector3(w + 0.4, 0.2, 0.25)]]:
		var box := BoxMesh.new()
		box.size = piece[1]
		var node := MeshInstance3D.new()
		node.mesh = box
		node.material_override = frame
		node.position = piece[0]
		add_child(node)
	var light := OmniLight3D.new()
	light.name = "DoorwayLight_%d" % roundi(x * 10.0)
	light.light_color = DOOR_LIGHT.golden[0]
	light.light_energy = DOOR_LIGHT.golden[1]
	light.omni_range = 4.5
	light.position = Vector3(x + 0.3, y + h * 0.7, z + 1.0)
	add_child(light)
	_door_lights.append(light)
	set_doorways("golden", false)


func _light(light: Dictionary) -> void:
	if light.type == "sun":
		# O sol do mapa: a rua já tem o seu (o clima), então o do cenário entra fraco, só para a direção de cada mapa.
		return
	if not light.get("visible", true):
		return
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(light.origin[0], light.origin[1], light.origin[2])
	lamp.light_energy = float(light.lumens) / LUMENS_PER_ENERGY
	lamp.omni_range = float(light.radius)
	lamp.omni_attenuation = 1.4
	lamp.light_color = Color(light.color[0], light.color[1], light.color[2])
	var shadows := bool(light.shadows) and RenderingServer.get_current_rendering_method() == "forward_plus"
	if shadows:
		lamp.add_to_group(Settings.SHADOW_LAMPS)
	lamp.shadow_enabled = shadows and Settings.effects().lamp_shadows
	add_child(lamp)


func _text(text: Dictionary) -> void:
	var label := Label3D.new()
	label.text = text.text
	label.font_size = 64
	label.pixel_size = float(text.size) / 64.0
	label.modulate = Color(text.color[0], text.color[1], text.color[2])
	label.shaded = true
	var b: Array = text.basis
	label.transform = Transform3D(Basis(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), Vector3(b[6], b[7], b[8])),
		Vector3(text.origin[0], text.origin[1], text.origin[2]))
	add_child(label)
