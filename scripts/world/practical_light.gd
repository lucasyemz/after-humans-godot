## Uma fonte de luz prática do cenário (#154): o objeto pintado aceso (a arte de art/scenarios/T_LPnn), o halo somado em
## volta dele, a poça de luz no chão e a luz da cena. O perfil de ambiência do lugar (ambience.json, "lights") diz quais
## e onde. A qualidade manda: a luz da cena só no Forward+ e a partir da Média (no Compatibility, o chão da rua já tem as
## 8 luzes que cada malha pega), com a sombra pelo lamp_shadows; sem ela, o halo e a poça desenhados fazem a luz. De
## noite as fontes são a luz principal; no fim de tarde ficam mais fracas. Com "Reduzir efeitos", ficam paradas e acesas.
##
## O drone ("drone") não tem arte (a do PR #156 saiu): é um farol frio passando alto, ao longe, de noite, varrendo a rua
## e a névoa com o cone (no Forward+ a névoa volumétrica pega o cone; fora dele, só o ponto de luz no céu).
class_name AHPracticalLight
extends Node3D

## Cada fonte: a arte, a altura no mundo (m), a origem da luz no card (fração da largura e da altura, de cima), a cor,
## a poça (m, e a força dela, pool_energy, nas de parede), a força e o alcance da luz e o que ela faz (o fogo que tremula, o pulso da emergência). As medidas são as
## de docs/design/luz-pratica.md.
const KINDS := {
	"barrel": {"art": "T_LP03", "height": 0.92, "light": Vector2(115.0 / 232.0, 107.0 / 398.0), "color": Color(1.0, 0.5, 0.2),
		"pool": 3.2, "energy": 2.4, "range": 6.5, "fire": true, "shadow": true, "solid": true},
	"lantern": {"art": "T_LP02", "height": 0.42, "light": Vector2(91.0 / 185.0, 257.0 / 406.0), "color": Color(1.0, 0.62, 0.3),
		"pool": 1.6, "energy": 0.9, "range": 3.2, "shadow": true, "solid": true},
	"emergency": {"art": "T_LP06", "height": 0.34, "light": Vector2(88.0 / 207.0, 118.0 / 279.0), "color": Color(1.0, 0.22, 0.15),
		"pool": 1.4, "pool_energy": 0.35, "energy": 1.4, "range": 4.0, "pulse": true, "shadow": false},
}
const DRONE_COLOR := Color(0.7, 0.95, 1.0)
## O fogo do tambor: a boca (px do card, de cima), a largura do fogo (fração do card) e os quadros por segundo.
const FIRE_SEAT := 95.0 / 398.0
const FIRE_WIDTH := 0.85
const FIRE_FPS := 8.0
## A força no fim de tarde (o sol ainda manda) e de noite (as fontes são a luz principal).
const GOLDEN := 0.45
## O halo e a poça desenhados: a força com a luz da cena acesa (ela faz a poça de verdade) e sem ela.
const POOL_WITH_LIGHT := 0.3
const POOL_ALONE := 0.85
const HALO_ENERGY := 1.6
## A emergência: 0,6 s acesa e 0,4 s a 25% (como a do tutorial).
const PULSE_ON := 0.6
const PULSE_OFF := 0.4
const PULSE_LOW := 0.25
## O drone: a volta inteira (s), o trecho dela em que ele passa (o resto, longe) e a varredura do cone (graus).
const DRONE_PERIOD := 26.0
const DRONE_PASS := 0.55
const DRONE_SWEEP := 25.0

var kind := ""
var spec := {}
var light: Light3D
var halo: MeshInstance3D
var pool: MeshInstance3D
var card: MeshInstance3D
var fire: MeshInstance3D
var embers: CPUParticles3D
var _fire_frames: Array[Texture2D] = []
var _night := true
var _lights_on := true
var _reduced := false
var _time := 0.0
var _flicker := 1.0
var _next_frame := 0.0


## Monta a fonte de um item de "lights" do perfil: {kind, at: [x, y, z] (o pé do card), floor (o y do chão, para a
## poça; o do pé, se faltar)}; o drone: {kind: "drone", y, z, x0, x1}.
func setup(entry: Dictionary) -> void:
	spec = entry
	kind = String(entry.kind)
	name = "Practical_%s" % kind
	if kind == "drone":
		_build_drone()
	else:
		_build_source(KINDS[kind])
	set_process(true)


func _build_source(data: Dictionary) -> void:
	var at: Array = spec.at
	position = Vector3(float(at[0]), float(at[1]), float(at[2]))
	var lit: Texture2D = load("res://art/scenarios/%s_Lit.webp" % data.art)
	var height := float(data.height)
	var width := height * lit.get_width() / lit.get_height()
	# O card aceso, como os cards do cenário (o alfa cortado em 0,333).
	var material := StandardMaterial3D.new()
	material.albedo_texture = lit
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.333
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9
	card = _quad("Card", Vector2(width, height), Vector3(0, height * 0.5, 0), material)
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if data.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# O halo: o dobro do card, no mesmo centro, somado.
	halo = _quad("Halo", Vector2(width, height) * 2.0, Vector3(0, height * 0.5, 0.02),
		_glow(load("res://art/scenarios/%s_Halo.webp" % data.art), Color(1, 1, 1)))
	# A origem da luz no card.
	var origin := Vector3((data.light.x - 0.5) * width, (1.0 - data.light.y) * height, 0.15)
	# A poça no chão, deitada embaixo da luz, na cor dela.
	var floor_y := float(spec.get("floor", position.y)) - position.y
	var size := float(data.pool)
	pool = _quad("Pool", Vector2(size, size), Vector3(origin.x, floor_y + 0.02, 0.4), _glow(load("res://art/scenarios/T_LP_Pool.webp"), data.color))
	pool.rotation_degrees.x = -90.0
	var omni := OmniLight3D.new()
	omni.name = "Light"
	omni.position = origin
	omni.light_color = data.color
	omni.omni_range = float(data.range)
	omni.omni_attenuation = 1.4
	omni.light_volumetric_fog_energy = 3.0
	omni.light_specular = 0.4
	omni.add_to_group(Settings.SHADOW_LAMPS)
	omni.shadow_enabled = Settings.effects().lamp_shadows
	add_child(omni)
	light = omni
	if data.get("fire", false):
		for i in 4:
			_fire_frames.append(load("res://art/scenarios/%s_Fire_%d.webp" % [data.art, i]))
		var fire_width := width * FIRE_WIDTH
		var fire_height := fire_width * _fire_frames[0].get_height() / _fire_frames[0].get_width()
		var seat := height * (1.0 - FIRE_SEAT)
		fire = _quad("Fire", Vector2(fire_width, fire_height), Vector3(0, seat + fire_height * 0.5, 0.03), _glow(_fire_frames[0], Color(1, 1, 1)))
		embers = _embers(Vector3(0, seat + 0.1, 0.05), data.color)


## A caixa de colisão das fontes de chão (o tambor, o lampião): a equipe anda pelos becos e não as atravessa. Vazia nas
## de parede e no drone.
func volume() -> AABB:
	if card == null or not KINDS[kind].get("solid", false):
		return AABB()
	var size := (card.mesh as QuadMesh).size
	return AABB(global_position + Vector3(-size.x * 0.4, 0.0, -0.25), Vector3(size.x * 0.8, size.y, 0.5))


func _build_drone() -> void:
	position = Vector3(float(spec.get("x0", 0.0)), float(spec.get("y", 9.0)), float(spec.get("z", -2.0)))
	var dot := QuadMesh.new()
	# Grande o bastante para o desfoque de profundidade do alto da tela não apagar o ponto.
	dot.size = Vector2.ONE * 0.6
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/glow_sprite.gdshader")
	material.set_shader_parameter("color", DRONE_COLOR)
	material.set_shader_parameter("energy", 6.0)
	halo = MeshInstance3D.new()
	halo.name = "Halo"
	halo.mesh = dot
	halo.material_override = material
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	var spot := SpotLight3D.new()
	spot.name = "Light"
	spot.light_color = DRONE_COLOR
	spot.spot_range = float(spec.get("y", 9.0)) + 6.0
	spot.spot_angle = 14.0
	spot.light_energy = 6.0
	spot.light_volumetric_fog_energy = 5.0
	spot.shadow_enabled = false
	spot.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	add_child(spot)
	light = spot


func _quad(node_name: String, size: Vector2, at: Vector3, material: Material) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = quad
	node.material_override = material
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _glow(texture: Texture2D, color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/glow_texture.gdshader")
	material.set_shader_parameter("tex", texture)
	material.set_shader_parameter("color", color)
	return material


func _embers(at: Vector3, color: Color) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "Embers"
	particles.position = at
	particles.amount = 10
	particles.lifetime = 1.6
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.12
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 18.0
	particles.gravity = Vector3(0.05, 0.4, 0)
	particles.initial_velocity_min = 0.3
	particles.initial_velocity_max = 0.7
	var mote := QuadMesh.new()
	mote.size = Vector2.ONE * 0.04
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/glow_sprite.gdshader")
	material.set_shader_parameter("color", color.lightened(0.3))
	material.set_shader_parameter("energy", 3.0)
	mote.material = material
	particles.mesh = mote
	particles.local_coords = false
	add_child(particles)
	return particles


## A hora e a qualidade: night (as fontes viram a luz principal), lights_on (a luz da cena: Forward+ e da Média para
## cima), reduced (Reduzir efeitos: nada tremula nem se mexe) e shown (fora, num interior, a fonte some).
func refresh(night: bool, lights_on: bool, reduced: bool, shown: bool = true) -> void:
	_night = night
	_lights_on = lights_on and shown
	_reduced = reduced
	# O drone só passa de noite.
	visible = shown and (night or kind != "drone")
	if embers != null:
		embers.emitting = not reduced
	_apply()


func _process(delta: float) -> void:
	if _reduced:
		return
	_time += delta
	if fire != null:
		# O fogo: os quadros em ciclo, numa ordem que não se repete à vista, e a força entre 80 e 110%.
		_next_frame -= delta
		if _next_frame <= 0.0:
			_next_frame = 1.0 / FIRE_FPS
			(fire.material_override as ShaderMaterial).set_shader_parameter("tex", _fire_frames[randi() % _fire_frames.size()])
			_flicker = randf_range(0.8, 1.1)
	elif KINDS.get(kind, {}).get("pulse", false):
		_flicker = 1.0 if fmod(_time, PULSE_ON + PULSE_OFF) < PULSE_ON else PULSE_LOW
	elif kind == "drone":
		_drone_step()
	_apply()


## O drone atravessa a rua de x0 a x1 numa parte da volta e some longe no resto; o cone varre de um lado para o outro.
func _drone_step() -> void:
	var phase := fmod(_time, DRONE_PERIOD) / DRONE_PERIOD
	var across := clampf(phase / DRONE_PASS, 0.0, 1.0)
	position.x = lerpf(float(spec.get("x0", 0.0)), float(spec.get("x1", 80.0)), across)
	halo.visible = phase < DRONE_PASS
	light.visible = halo.visible and _lights_on
	light.rotation_degrees.z = sin(_time * 0.9) * DRONE_SWEEP


func _apply() -> void:
	var mood := 1.0 if _night else GOLDEN
	var power := mood * _flicker
	if kind == "drone":
		light.visible = _lights_on and halo.visible
		return
	var data: Dictionary = KINDS[kind]
	light.visible = _lights_on
	light.light_energy = float(data.energy) * power
	(halo.material_override as ShaderMaterial).set_shader_parameter("energy", HALO_ENERGY * power)
	# A de parede fica alta: a poça dela chega fraca ao chão (pool_energy).
	var pool_energy := float(data.get("pool_energy", 1.0)) * (POOL_WITH_LIGHT if _lights_on else POOL_ALONE)
	(pool.material_override as ShaderMaterial).set_shader_parameter("energy", pool_energy * power)
	if fire != null:
		(fire.material_override as ShaderMaterial).set_shader_parameter("energy", 1.4 * (0.6 + 0.4 * _flicker))
