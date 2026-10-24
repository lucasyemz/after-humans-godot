## Monta um mapa de cenário da Unreal a partir de data/scenarios/<Mapa>.json (tools/sync_scenarios.py): as peças com as
## malhas e os materiais de lá, as luzes e os textos. Guarda as zonas caminháveis, as portas dos interiores laterais e
## os props vasculháveis, que o corredor usa. As peças fixas viram uma malha por material (como na Estação).
class_name AHScenarioWorld
extends Node3D

const MESHES := "res://data/scenarios/meshes.json"
## A Unreal mede a luz em lúmens; a mesma escala da Estação.
const LUMENS_PER_ENERGY := 260.0
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


## Tempo molhado nos materiais (a chuva lá fora) e a cor do clima nos cards de fundo.
func set_weather(wet: float, tint: Color) -> void:
	for material in _cards:
		material.set_shader_parameter("wet", wet)
		material.set_shader_parameter("weather", Vector4(tint.r, tint.g, tint.b, 1.0))
	for material in _blockouts:
		material.set_shader_parameter("wet", wet)


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
