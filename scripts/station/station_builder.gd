## As peças básicas da montagem da Estação, com a mesma assinatura do AAHShelterStation da Unreal (Box, Beam, Cylinder,
## Prop, Hang, PropPlaced, Light, Sign, WallWithOpenings): as coordenadas vêm em centímetros e nos eixos da Unreal
## (X para a direita, Y para o fundo negativo, Z para cima) e viram metros da Godot aqui (x, z, y). Assim a montagem de
## cada cômodo é transcrita do C++ quase linha a linha (station_build.gd).
class_name AHStationBuilder
extends RefCounted

const SURFACES := "res://data/presentation/station_surfaces.json"
const MODELS := "res://art/station/models/%s/%s_1k.fbx"
## A Unreal mede a luz em lúmens; a Godot, em energia. Calibrado na tela (a lâmpada da plataforma, 750 lm, dá ~3).
const LUMENS_PER_ENERGY := 260.0

var root: Node3D
## Tudo o que foi criado, na ordem (como Generated da Unreal): marcas para agrupar o vagão e o mobiliário de cada sala.
var generated: Array[Node3D] = []
var _surfaces := {}
var _materials := {}
var _models := {}
var _prop_materials := {}
var _cube := BoxMesh.new()
var _cylinder := CylinderMesh.new()


func _init(target: Node3D) -> void:
	root = target
	_surfaces = JSON.parse_string(FileAccess.get_file_as_string(SURFACES))
	_cylinder.top_radius = 0.5
	_cylinder.bottom_radius = 0.5
	_cylinder.height = 1.0
	_cylinder.radial_segments = 24


## Ponto da Unreal (cm) em metros da Godot.
static func v(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, z, y) * 0.01


static func vu(point: Vector3) -> Vector3:
	return Vector3(point.x, point.z, point.y) * 0.01


## FRotator(Pitch, Yaw, Roll) da Unreal como base da Godot: a matriz da Unreal (FRotationMatrix) com os eixos Y e Z
## trocados (a Unreal é de mão esquerda; a troca de eixos leva para a de mão direita).
static func basis(pitch: float, yaw: float, roll: float) -> Basis:
	var p := deg_to_rad(pitch)
	var y := deg_to_rad(yaw)
	var r := deg_to_rad(roll)
	var sp := sin(p)
	var cp := cos(p)
	var sy := sin(y)
	var cy := cos(y)
	var sr := sin(r)
	var cr := cos(r)
	var x_axis := Vector3(cp * cy, cp * sy, sp)
	var y_axis := Vector3(sr * sp * cy - cr * sy, sr * sp * sy + cr * cy, -sr * cp)
	var z_axis := Vector3(-(cr * sp * cy + sr * sy), cy * sr - cr * sp * sy, cr * cp)
	var swap := func(a: Vector3) -> Vector3: return Vector3(a.x, a.z, a.y)
	return Basis(swap.call(x_axis), swap.call(z_axis), swap.call(y_axis))


func mark() -> int:
	return generated.size()


# ---------------------------------------------------------------- materiais

## Superfície projetada pelo mundo (Surface da Unreal): id da textura, piso do nível (cm, para a umidade), umidade, tinta
## e rugosidade.
func surface(id: String, floor_z: float = 0.0, damp: float = 0.0, tint: Color = Color.WHITE, roughness: float = 1.0) -> Material:
	var key := "s|%s|%s|%s|%s|%s" % [id, floor_z, damp, tint.to_html(), roughness]
	if _materials.has(key):
		return _materials[key]
	var info: Dictionary = _surfaces.get(id, {})
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/station_surface.gdshader")
	var path := "res://art/station/%s.webp" % id
	if info.is_empty() or not ResourceLoader.exists(path):
		# Sem a textura: o cinza do blockout, para a cena continuar legível (como a Unreal).
		material.set_shader_parameter("albedo_tex", preload("res://art/station/rough_concrete.webp"))
		material.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b) * 0.45)
	else:
		material.set_shader_parameter("albedo_tex", load(path))
		var shade: float = info.get("tint", 1.0)
		material.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b) * shade)
		if info.get("normal", false) and ResourceLoader.exists("res://art/station/%s_n.webp" % id):
			material.set_shader_parameter("normal_tex", load("res://art/station/%s_n.webp" % id))
			material.set_shader_parameter("use_normal", true)
	material.set_shader_parameter("tile_size", float(info.get("tile_cm", 200.0)) * 0.01)
	material.set_shader_parameter("roughness_scale", roughness)
	material.set_shader_parameter("floor_y", floor_z * 0.01)
	material.set_shader_parameter("damp_amount", damp)
	_materials[key] = material
	return material


## Luz própria, sem sombreamento (Emissive da Unreal): telas, lâmpadas, brasas.
func emissive(color: Color, intensity: float) -> Material:
	var key := "e|%s|%s" % [color.to_html(), intensity]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = intensity * 0.25
	_materials[key] = material
	return material


func glass() -> Material:
	if _materials.has("glass"):
		return _materials["glass"]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.62, 0.6, 0.22)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.12
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials["glass"] = material
	return material


# ---------------------------------------------------------------- formas

func _add(node: Node3D, parent: Node3D = null) -> Node3D:
	(parent if parent else root).add_child(node)
	generated.append(node)
	return node


## Caixa de min a max (cm, eixos da Unreal).
func box(min_corner: Vector3, max_corner: Vector3, material: Material, shadow: bool = true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = _cube
	mesh.material_override = material
	mesh.position = vu((min_corner + max_corner) * 0.5)
	var size := (max_corner - min_corner).abs() * 0.01
	mesh.scale = Vector3(maxf(size.x, 0.0005), maxf(size.z, 0.0005), maxf(size.y, 0.0005))
	if not shadow:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(mesh)
	return mesh


## Caixa girada em torno do centro (Beam da Unreal): tamanho em cm e FRotator(pitch, yaw, roll).
func beam(center: Vector3, size: Vector3, rotation: Vector3, material: Material) -> MeshInstance3D:
	var mesh := box(center - size * 0.5, center + size * 0.5, material)
	var scale := mesh.scale
	mesh.basis = basis(rotation.x, rotation.y, rotation.z) * Basis.from_scale(scale)
	return mesh


## Cilindro de diâmetro e comprimento (cm) com o eixo no Z da Unreal, girado por FRotator(pitch, yaw, roll).
func cylinder(center: Vector3, diameter: float, length: float, rotation: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = _cylinder
	mesh.material_override = material
	mesh.position = vu(center)
	mesh.basis = basis(rotation.x, rotation.y, rotation.z) * Basis.from_scale(Vector3(diameter, length, diameter) * 0.01)
	_add(mesh)
	return mesh


# ---------------------------------------------------------------- modelos

func _model(id: String) -> Dictionary:
	if _models.has(id):
		return _models[id]
	var path := MODELS % [id, id]
	var entry := {}
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path)
		var probe := scene.instantiate()
		var box := AABB()
		var first := true
		for node in probe.find_children("*", "MeshInstance3D", true, false):
			var mesh: MeshInstance3D = node
			var world := _local_transform(mesh, probe) * mesh.get_aabb()
			box = world if first else box.merge(world)
			first = false
		probe.free()
		entry = {"scene": scene, "box": box}
	_models[id] = entry
	return entry


static func _local_transform(node: Node3D, top: Node) -> Transform3D:
	var xf := node.transform
	var parent := node.get_parent()
	while parent and parent != top:
		if parent is Node3D:
			xf = (parent as Node3D).transform * xf
		parent = parent.get_parent()
	return xf


## Materiais que o FBX não achou (o caminho original da Poly Haven): a cor da pasta do modelo, pelo nome do material.
func _fix_materials(node: Node, id: String) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = child
		for surface_index in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface_index)
			if not (material is StandardMaterial3D) or (material as StandardMaterial3D).albedo_texture != null:
				continue
			var name: String = material.resource_name
			if name.ends_with("glass"):
				mesh.set_surface_override_material(surface_index, glass())
				continue
			if not _prop_materials.has(name):
				var fixed: StandardMaterial3D = material.duplicate()
				for candidate in ["%s_diff_1k.jpg" % name, "%s_body_diff_1k.jpg" % name, "%s_diff_1k.jpg" % id]:
					var path := "res://art/station/models/%s/%s" % [id, candidate]
					if ResourceLoader.exists(path):
						fixed.albedo_texture = load(path)
						fixed.albedo_color = Color.WHITE
						break
				_prop_materials[name] = fixed
			mesh.set_surface_override_material(surface_index, _prop_materials[name])


## Modelo com os pés no ponto pedido (o centro da base da malha), girado em Yaw e na escala dada (Prop da Unreal).
func prop(id: String, feet: Vector3, yaw: float = 0.0, scale: float = 1.0, parent: Node3D = null) -> Node3D:
	var entry := _model(id)
	if entry.is_empty():
		return null
	var node: Node3D = entry.scene.instantiate()
	_fix_materials(node, id)
	var box: AABB = entry.box
	var bottom_center := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var rotation := basis(0.0, yaw, 0.0)
	node.basis = rotation * Basis.from_scale(Vector3.ONE * scale)
	node.position = vu(feet) - rotation * (bottom_center * scale)
	_add(node, parent)
	return node


## Pendurado: o topo da malha encosta no ponto do teto.
func hang(id: String, ceiling: Vector3, yaw: float = 0.0) -> Node3D:
	var entry := _model(id)
	if entry.is_empty():
		return null
	var node := prop(id, ceiling - Vector3(0, 0, entry.box.size.y * 100.0), yaw)
	if node and id == "caged_hanging_light":
		# A cúpula fica logo acima da luz da sala: sem sombra, para não pintar uma faixa preta no teto do corte.
		for mesh in node.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## Modelo girado em qualquer eixo, com o ponto mais baixo em Feet.Z e o centro sobre Feet (PropPlaced da Unreal).
func prop_placed(id: String, feet: Vector3, rotation: Vector3) -> Node3D:
	var node := prop(id, feet)
	if node == null:
		return null
	var box: AABB = _model(id).box
	var turn := basis(rotation.x, rotation.y, rotation.z)
	var rotated := AABB()
	for corner in 8:
		var point := Vector3(box.end.x if corner & 1 else box.position.x, box.end.y if corner & 4 else box.position.y,
			box.end.z if corner & 2 else box.position.z)
		var turned := turn * point
		rotated = AABB(turned, Vector3.ZERO) if corner == 0 else rotated.expand(turned)
	node.basis = turn
	node.position = vu(feet) - Vector3(rotated.get_center().x, rotated.position.y, rotated.get_center().z)
	return node


# ---------------------------------------------------------------- cards pintados

## Card pintado em pé (o Plane com M_<Sala>_<Nome> da Unreal): a base (centro de baixo) em base, largura e altura em cm,
## e o eixo horizontal right (eixos da Unreal; (1, 0, 0) é de frente para a câmera). Sem a arte, não cria nada.
func card(name: String, base: Vector3, width: float, height: float, shadow: bool = false, right: Vector3 = Vector3(1, 0, 0)) -> MeshInstance3D:
	var path := "res://art/station/cards/%s.webp" % name
	if not ResourceLoader.exists(path):
		return null
	var key := "c|" + name
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_texture = load(path)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 0.9
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_materials[key] = material
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height) * 0.01
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = _materials[key]
	if not shadow:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var axis := vu(right).normalized()
	mesh.basis = Basis(axis, Vector3.UP, axis.cross(Vector3.UP))
	mesh.position = vu(base + Vector3(0, 0, height * 0.5))
	_add(mesh)
	return mesh


## Sombra de contato macia no piso (M_DepartureContact): centro em cm, tamanho (X, Y) em cm e a força.
func contact(center: Vector3, size: Vector2, strength: float) -> MeshInstance3D:
	var key := "contact|%s" % strength
	if not _materials.has(key):
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0, 0, 0, strength))
		gradient.set_color(1, Color(0, 0, 0, 0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials[key] = material
	var quad := PlaneMesh.new()
	quad.size = size * 0.01
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = _materials[key]
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.position = vu(center + Vector3(0, 0, 0.3))
	# PlaneMesh deita em XZ da Godot: o tamanho X é o X da Unreal e o Y (fundo) é o Z da Godot.
	_add(mesh)
	return mesh


# ---------------------------------------------------------------- luz e texto

func light(position: Vector3, lumens: float, radius: float, color: Color, shadows: bool) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.position = vu(position)
	lamp.light_energy = lumens / LUMENS_PER_ENERGY
	lamp.omni_range = radius * 0.01
	lamp.omni_attenuation = 1.4
	lamp.light_color = color
	lamp.light_size = 0.04
	# A sombra das luminárias segue a qualidade das opções (Settings.apply_lamp_shadows, #37).
	if shadows:
		lamp.add_to_group(Settings.SHADOW_LAMPS)
	lamp.shadow_enabled = shadows and Settings.effects().lamp_shadows
	_add(lamp)
	return lamp


## Texto 3D de frente para a câmera (Sign da Unreal): tamanho em cm.
func sign(text: String, center: Vector3, size: float, color: Color, yaw: float = 0.0, parent: Node3D = null) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = 64
	label.pixel_size = size * 0.01 / 64.0
	label.outline_size = 0
	label.shaded = true
	label.position = vu(center)
	label.rotation.y = -deg_to_rad(yaw)
	_add(label, parent)
	return label


## Parede com vãos (WallWithOpenings da Unreal): holes são Rect2 (posição ao longo da parede e altura), em cm.
func wall_with_openings(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, holes: Array, material: Material, along_x: bool) -> void:
	var u0 := x0 if along_x else y0
	var u1 := x1 if along_x else y1
	var piece := func(a: float, b: float, bottom: float, top: float) -> void:
		if b - a < 0.5 or top - bottom < 0.5:
			return
		if along_x:
			box(Vector3(a, y0, bottom), Vector3(b, y1, top), material)
		else:
			box(Vector3(x0, a, bottom), Vector3(x1, b, top), material)
	var sorted := holes.duplicate()
	sorted.sort_custom(func(a: Rect2, b: Rect2): return a.position.x < b.position.x)
	var cursor := minf(u0, u1)
	var finish := maxf(u0, u1)
	for hole: Rect2 in sorted:
		piece.call(cursor, hole.position.x, z0, z1)
		piece.call(hole.position.x, hole.end.x, z0, hole.position.y)
		piece.call(hole.position.x, hole.end.x, hole.end.y, z1)
		cursor = hole.end.x
	piece.call(cursor, finish, z0, z1)


## Junta as caixas e os cilindros fixos que dividem o material numa malha só (cada peça era uma chamada de desenho: a
## Estação passava de 12 mil no renderizador da web). keep: as peças que ligam e desligam (o mobiliário de cada sala, o
## estoque, o vagão) ficam separadas. Devolve quantas peças entraram nas malhas juntas.
func merge_static(keep: Dictionary) -> int:
	var groups := {}
	for node in generated:
		if not (node is MeshInstance3D) or keep.has(node) or not is_instance_valid(node):
			continue
		var mesh := node as MeshInstance3D
		if (mesh.mesh != _cube and mesh.mesh != _cylinder) or mesh.material_override == null or mesh.get_parent() != root:
			continue
		var key := [mesh.material_override, mesh.cast_shadow]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(mesh)
	var merged := 0
	for key in groups:
		var parts: Array = groups[key]
		if parts.size() < 2:
			continue
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: MeshInstance3D in parts:
			tool.append_from(part.mesh, 0, part.transform)
		var combined := MeshInstance3D.new()
		combined.mesh = tool.commit()
		combined.material_override = key[0]
		combined.cast_shadow = key[1]
		root.add_child(combined)
		for part: MeshInstance3D in parts:
			generated.erase(part)
			part.queue_free()
		generated.append(combined)
		merged += parts.size()
	return merged


## FBox2D(min, max) da Unreal como Rect2.
static func hole(min_u: float, min_v: float, max_u: float, max_v: float) -> Rect2:
	return Rect2(min_u, min_v, max_u - min_u, max_v - min_v)
