## O vagão verde em camadas (#149, integração na #256), no mundo 3D: o interior atrás, as quatro folhas das portas, a
## carroceria, o vidro, as rodas e o truque, com a faísca na freada. As medidas são as do contrato do design
## (data/presentation/train_2d.json, a cópia de docs/design/trem-2d/contract.json que vai no jogo).
##
## A origem fica no meio do vagão, na altura do chão dele (a da plataforma), no plano da carroceria; a câmera olha para
## -Z. Quem está dentro fica em `inside_z()`, entre o interior e a carroceria: aparece pelas janelas e pelas portas.
class_name AHTrainCar
extends Node3D

const CONTRACT := "res://data/presentation/train_2d.json"
const LAYER_SHADER := preload("res://shaders/train_layer.gdshader")
const BLEND_SHADER := preload("res://shaders/train_layer_blend.gdshader")
## A altura da câmera da exploração acima do chão (m): o interior cresce em volta dela, para casar com as janelas.
const PIVOT_Y := 1.7
## As luzes da faísca no trilho (a mais forte no começo da freada).
const SPARK_LIGHT := 2.2

## O contrato inteiro (a parte "train" e a "passage").
static var _contract := {}

## A distância da câmera até a carroceria (m): o interior fica atrás dela, maior na mesma proporção.
var camera_distance := 19.0
## O brilho das camadas (o do card que o vagão substitui no mapa).
var brightness := 1.0
## Aceso (o interior frio) ou apagado (o vagão parado e abandonado).
var lit := true
## A faísca e a luz dela: fora com "Reduzir efeitos".
var sparks_enabled := true
## O nó que anda na chegada e na partida (o vagão, ou o grupo dele com as luzes no mapa); as rodas giram pelo que ele anda.
var carrier: Node3D

var px := 128.0
var _t: Dictionary
var _interior: MeshInstance3D
var _interior_mat: ShaderMaterial
var _leaves := {}
var _wheels: Array[MeshInstance3D] = []
var _sparks: Array[CPUParticles3D] = []
var _materials: Array[ShaderMaterial] = []
var _door_open := 0.0
var _door_tween: Tween
var _angle := 0.0
var _home := Vector3.ZERO


static func contract() -> Dictionary:
	if _contract.is_empty():
		_contract = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	return _contract


func _init(distance: float = 19.0, layer_brightness: float = 1.0) -> void:
	camera_distance = distance
	brightness = layer_brightness
	name = "TrainCar"
	_t = contract().train
	px = float(_t.px_per_m)
	_build()


## O meio de uma porta em x (m, no vagão): 0 a da esquerda (A), 1 a da direita (B).
func door_x(index: int) -> float:
	var door: Array = _t.doors[index]
	return ((float(door[0]) + float(door[2])) * 0.5 - float(_t.canvas[0]) * 0.5) / px


## A profundidade de quem está dentro (m, no vagão).
func inside_z() -> float:
	return float(_t.depth.team_inside)


## A largura do vagão (m).
func length() -> float:
	return float(_t.canvas[0]) / px


## Os materiais das camadas, para o clima do cenário (a cor e o molhado) chegar neles como nos cards.
func materials() -> Array[ShaderMaterial]:
	return _materials


func set_lit(on: bool) -> void:
	lit = on
	_interior_mat.set_shader_parameter("albedo_tex", load(_t.layers.interior if on else _t.layers.interior_off))


## As portas de 0 (fechadas) a 1 (abertas), na hora.
func set_doors(open: float) -> void:
	if _door_tween != null:
		_door_tween.kill()
		_door_tween = null
	_apply_doors(open)


## Abre ou fecha as portas no tempo do contrato (0,8 s, ease in-out). Devolve quando acabam.
func move_doors(open: bool) -> void:
	if _door_tween != null:
		_door_tween.kill()
	var seconds: float = float(_t.door_seconds.open if open else _t.door_seconds.close)
	_door_tween = create_tween()
	_door_tween.tween_method(_apply_doors, _door_open, 1.0 if open else 0.0, seconds)
	await _door_tween.finished
	_door_tween = null


func doors_open() -> float:
	return _door_open


## O vagão a `offset` m da casa dele em x: as rodas giram pelo que ele andou (ângulo = -distância / raio).
func drive(offset: float) -> void:
	var node := _carrier()
	var moved := _home.x + offset - node.position.x
	_angle -= moved / (float(_t.wheel_radius) / px)
	node.position.x = _home.x + offset
	for wheel in _wheels:
		wheel.rotation.z = _angle


## Fixa a casa do vagão (onde ele para) na posição de agora de quem anda.
func set_home() -> void:
	_home = _carrier().position


func _carrier() -> Node3D:
	return carrier if carrier != null else self


## A faísca nas quatro rodas, para trás do movimento (direction: +1 andando para a direita), e a luz no trilho.
func brake(on: bool, strength: float = 1.0, direction: float = 1.0) -> void:
	for spark in _sparks:
		spark.emitting = on and sparks_enabled
		spark.direction = Vector3(-signf(direction), 0.55, 0.15)
		(spark.get_child(0) as OmniLight3D).light_energy = SPARK_LIGHT * clampf(strength, 0.0, 1.0) if on and sparks_enabled else 0.0


## A chegada: o vagão vem de `run` m da casa (negativo: da esquerda) e para nela em `seconds`, freando (ease-out); a
## faísca da metade da velocidade até parar, como no contrato. As portas ficam fechadas.
func arrive(seconds: float, run: float) -> void:
	set_doors(0.0)
	var time := 0.0
	drive(run)
	while time < seconds:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		time += get_process_delta_time()
		var t := clampf(time / seconds, 0.0, 1.0)
		var u := 1.0 - t
		drive(run * u * u)
		# A velocidade cai na reta (ease-out quadrático): metade em t = 0,5.
		brake(t >= 0.5 and t < 1.0, 1.0 - (t - 0.5) * 2.0, -signf(run))
	drive(0.0)
	brake(false)


## A partida: o vagão sai de casa até `run` m à direita em `seconds`, acelerando (ease-in). on_step recebe o quanto ele
## já andou, para quem está dentro ir junto.
func depart(seconds: float, run: float, on_step: Callable = Callable()) -> void:
	var time := 0.0
	while time < seconds:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		time += get_process_delta_time()
		var t := clampf(time / seconds, 0.0, 1.0)
		drive(run * t * t)
		if on_step.is_valid():
			on_step.call(run * t * t)


func _apply_doors(open: float) -> void:
	_door_open = open
	var eased := open * open * (3.0 - 2.0 * open)
	for name in _leaves:
		var leaf: Dictionary = _leaves[name]
		leaf.node.position.x = leaf.home + leaf.offset * eased


func _build() -> void:
	var size := Vector2(_t.canvas[0], _t.canvas[1])
	var depth: Dictionary = _t.depth
	# O interior fica atrás da carroceria (o fundo do vagão), maior na mesma proporção da distância, para casar com as
	# janelas vistas de frente.
	var k := (camera_distance - float(depth.interior_z)) / camera_distance
	_interior = _layer(_t.layers.interior, size, Vector2.ZERO, depth.interior_z, k)
	_interior_mat = _interior.material_override
	for leaf_name in _t.leaves:
		var leaf: Dictionary = _t.leaves[leaf_name]
		var node := _layer(leaf.file, Vector2(leaf.size[0], leaf.size[1]), Vector2(leaf.closed_top_left[0], leaf.closed_top_left[1]),
			depth.leaves, 1.0, leaf.blend == "alpha")
		_leaves[leaf_name] = {"node": node, "home": node.position.x, "offset": float(leaf.open_offset_x) / px}
	_layer(_t.layers.body, size, Vector2.ZERO, 0.0)
	_layer(_t.layers.glass, size, Vector2.ZERO, depth.glass, 1.0, true)
	var r: float = _t.wheel_radius
	for center in _t.wheel_centers:
		var wheel := _layer(_t.layers.wheel, Vector2(2 * r, 2 * r), Vector2(center[0] - r, center[1] - r), depth.wheels)
		_wheels.append(wheel)
		_sparks.append(_spark(Vector3((center[0] - size.x * 0.5) / px, (float(_t.floor_y) - center[1] - r) / px, float(depth.wheels) + 0.02)))
	_layer(_t.layers.bogie, size, Vector2.ZERO, depth.bogie)


## Uma camada: a textura num quad, com o canto de cima à esquerda em top_left (px, no quadro do vagão). scale > 1
## aumenta em volta da altura da câmera (o interior).
func _layer(file: String, size: Vector2, top_left: Vector2, z: float, scale := 1.0, blend := false) -> MeshInstance3D:
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size / px * scale
	quad.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = BLEND_SHADER if blend else LAYER_SHADER
	material.set_shader_parameter("albedo_tex", load(file))
	material.set_shader_parameter("brightness", brightness)
	quad.material_override = material
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_materials.append(material)
	var center := top_left + size * 0.5
	var p := Vector2((center.x - float(_t.canvas[0]) * 0.5) / px, (float(_t.floor_y) - center.y) / px)
	var pivot := Vector2(0.0, PIVOT_Y)
	p = pivot + (p - pivot) * scale
	quad.position = Vector3(p.x, p.y, z)
	add_child(quad)
	return quad


func _spark(at: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = at
	p.amount = int(_t.sparks.amount_per_wheel)
	p.lifetime = float(_t.sparks.lifetime)
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3(-1.0, 0.55, 0.15)
	p.spread = 28.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.particle_flag_align_y = true
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.035, 0.16)
	var material := StandardMaterial3D.new()
	material.albedo_texture = spark_texture(false)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	p.mesh = mesh
	add_child(p)
	# O brilho laranja no trilho onde a roda raspa.
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.6, 0.25)
	glow.light_energy = 0.0
	glow.omni_range = 1.6
	p.add_child(glow)
	return p


## A textura da faísca é um risco deitado com a cabeça à direita; a partícula alinha o Y com a velocidade, então o risco
## fica em pé, com a cabeça para a frente do movimento: para cima no quad 3D (clockwise false), para baixo no 2D.
static var _spark_textures := {}
static func spark_texture(clockwise: bool) -> Texture2D:
	if not _spark_textures.has(clockwise):
		var image := (load(contract().train.layers.spark) as Texture2D).get_image()
		image.decompress()
		image.rotate_90(CLOCKWISE if clockwise else COUNTERCLOCKWISE)
		_spark_textures[clockwise] = ImageTexture.create_from_image(image)
	return _spark_textures[clockwise]
