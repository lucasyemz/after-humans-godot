## A fogueira da parada de descanso (#143): o acampamento fora das casas, na rua ou no cenário, onde a equipe parou.
## Tem o que a cena do acampamento (AHCampScene) usa de um cômodo: o x da fogueira, o piso, a linha dela e onde a fila
## recomeça ao levantar. Onde há água no chão (o Depósito Inundado), a fogueira é o tambor de ferro com fogo (T_LP03,
## docs/design/luz-pratica.md): ninguém acende fogo na água, e o tambor fica em pé nela.
class_name AHStreetCamp
extends Node3D

## A fileira do acampamento ocupa 3,3 m para cada lado da fogueira (AHCampScene.SLOTS) e mais a folga do corpo.
const HALF_ROW := 4.0

var camp_x := 0.0
## Onde o líder fica ao levantar (dentro do trecho de descanso, antes da próxima patrulha).
var leave_x := 0.0
var floor_y := 0.0
## A linha da fogueira: a equipe senta um pouco à frente dela (AHCampScene.SLOTS).
var camp_z := 0.0
## Onde a fila fica ao levantar (o z da faixa de andar).
var leave_z := 0.0
## O tambor (T_LP03, 232 × 398 px): 0,92 m de altura, o pé no chão; o fogo assenta na boca, com o pé em y = 95 px do
## card e 85% da largura dele (fire_seat), em quatro quadros somados que trocam a uns 8 por segundo; a luz sai da boca
## (115, 107 px), na cor [1, 0,5, 0,2], e o halo tem o mesmo centro do card e o dobro do tamanho.
const BARREL_HEIGHT := 0.92
const BARREL_PX := Vector2(232, 398)
const BARREL_FIRE_SEAT := 95.0
const BARREL_FIRE_WIDTH := 0.85
const BARREL_LIGHT_PX := Vector2(115, 107)
const BARREL_FIRE_FPS := 8.0
## O fogo acima de 1 (o glow pega) e o halo mais baixo, só o brilho em volta.
const BARREL_FIRE_ENERGY := 1.6
const BARREL_HALO_ENERGY := 0.8
## Se a fogueira é o tambor (água no chão).
var barrel := false
var _fire_material: ShaderMaterial
var _fire_light: OmniLight3D
var _barrel_fire: MeshInstance3D
var _barrel_halo: MeshInstance3D
var _fire_frames: Array[Texture2D] = []
var _fire_frame := 0
var _fire_time := 0.0


## x: a fogueira (o corredor escolhe, AHStreetCorridor._stop_camp_place); leave: onde a fila recomeça; y: o piso; z: a
## faixa de andar; in_water: a fogueira cai na água do chão (o tambor no lugar dela).
func build(x: float, leave: float, y: float, z: float, in_water: bool = false) -> void:
	name = "StopCamp"
	camp_x = x
	leave_x = leave
	floor_y = y
	camp_z = z - 0.35
	leave_z = z
	barrel = in_water
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.6, 0.3)
	_fire_light.omni_range = 6.5
	_fire_light.add_to_group(Settings.SHADOW_LAMPS)
	_fire_light.shadow_enabled = Settings.effects().lamp_shadows
	_fire_light.visible = false
	add_child(_fire_light)
	if barrel:
		_build_barrel()
		return
	_fire_light.position = Vector3(camp_x, floor_y + 0.8, camp_z + 0.6)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	_fire_material = ShaderMaterial.new()
	_fire_material.shader = preload("res://shaders/campfire.gdshader")
	_fire_material.set_shader_parameter("albedo_tex", load("res://art/street/campfire-v1.png"))
	_fire_material.set_shader_parameter("burn", 0.0)
	var fire := MeshInstance3D.new()
	fire.mesh = quad
	fire.material_override = _fire_material
	fire.position = Vector3(camp_x, floor_y + 0.45, camp_z + 0.35)
	add_child(fire)


## O tambor de ferro com fogo: o card recortado (o corte de alfa dos cenários), o fogo somado por cima da boca e o halo.
func _build_barrel() -> void:
	var meters := BARREL_HEIGHT / BARREL_PX.y
	var size := BARREL_PX * meters
	var base := Vector3(camp_x, floor_y, camp_z + 0.35)
	var card := MeshInstance3D.new()
	card.name = "Barrel"
	card.mesh = QuadMesh.new()
	card.mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://art/scenarios/T_LP03.webp")
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.333
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	card.material_override = material
	card.position = base + Vector3(0, size.y * 0.5, 0)
	add_child(card)
	for i in 4:
		_fire_frames.append(load("res://art/scenarios/T_LP03_Fire_%d.webp" % i))
	var frame_size: Vector2 = _fire_frames[0].get_size()
	var fire_width := size.x * BARREL_FIRE_WIDTH
	var fire_height := fire_width * frame_size.y / frame_size.x
	_barrel_fire = _added_quad("BarrelFire", Vector2(fire_width, fire_height), _fire_frames[0], BARREL_FIRE_ENERGY)
	_barrel_fire.position = base + Vector3(0, size.y - BARREL_FIRE_SEAT * meters + fire_height * 0.5, 0.02)
	_barrel_halo = _added_quad("BarrelHalo", size * 2.0, load("res://art/scenarios/T_LP03_Halo.webp"), BARREL_HALO_ENERGY)
	_barrel_halo.position = card.position + Vector3(0, 0, 0.01)
	_fire_light.light_color = Color(1.0, 0.5, 0.2)
	_fire_light.position = base + Vector3((BARREL_LIGHT_PX.x - BARREL_PX.x * 0.5) * meters, size.y - BARREL_LIGHT_PX.y * meters, 0.25)


## Um quad somado (o fogo, o halo): colorido sobre preto, sem luz e sem névoa (shaders/added_sprite.gdshader).
func _added_quad(node_name: String, size: Vector2, texture: Texture2D, energy: float) -> MeshInstance3D:
	var quad := MeshInstance3D.new()
	quad.name = node_name
	quad.mesh = QuadMesh.new()
	quad.mesh.size = size
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/added_sprite.gdshader")
	material.set_shader_parameter("tex", texture)
	material.set_shader_parameter("energy", energy)
	quad.material_override = material
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.visible = false
	add_child(quad)
	return quad


func set_camp_lit(lit: bool) -> void:
	if barrel:
		_barrel_fire.visible = lit
		_barrel_halo.visible = lit
	else:
		_fire_material.set_shader_parameter("burn", 1.0 if lit else 0.0)
	_fire_light.visible = lit
	_fire_light.light_energy = 2.6


## O fogo do tambor tremula: os quatro quadros em ciclo, numa ordem que não se repete à vista (nunca o mesmo duas vezes).
func _process(delta: float) -> void:
	if not barrel or not _barrel_fire.visible:
		return
	_fire_time += delta
	if _fire_time < 1.0 / BARREL_FIRE_FPS:
		return
	_fire_time = 0.0
	_fire_frame = (_fire_frame + 1 + randi() % (_fire_frames.size() - 1)) % _fire_frames.size()
	(_barrel_fire.material_override as ShaderMaterial).set_shader_parameter("tex", _fire_frames[_fire_frame])
