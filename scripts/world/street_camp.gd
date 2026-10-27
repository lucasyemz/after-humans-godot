## A fogueira da parada de descanso (#143): o acampamento fora das casas, na rua ou no cenário, onde a equipe parou.
## Tem o que a cena do acampamento (AHCampScene) usa de um cômodo: o x da fogueira, o piso, a linha dela e onde a fila
## recomeça ao levantar.
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
var _fire_material: ShaderMaterial
var _fire_light: OmniLight3D


## x: a fogueira (o corredor escolhe, AHStreetCorridor._stop_camp_place); leave: onde a fila recomeça; y: o piso; z: a
## faixa de andar.
func build(x: float, leave: float, y: float, z: float) -> void:
	name = "StopCamp"
	camp_x = x
	leave_x = leave
	floor_y = y
	camp_z = z - 0.35
	leave_z = z
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
	_fire_light = OmniLight3D.new()
	_fire_light.position = Vector3(camp_x, floor_y + 0.8, camp_z + 0.6)
	_fire_light.light_color = Color(1.0, 0.6, 0.3)
	_fire_light.omni_range = 6.5
	_fire_light.add_to_group(Settings.SHADOW_LAMPS)
	_fire_light.shadow_enabled = Settings.effects().lamp_shadows
	_fire_light.visible = false
	add_child(_fire_light)


func set_camp_lit(lit: bool) -> void:
	_fire_material.set_shader_parameter("burn", 1.0 if lit else 0.0)
	_fire_light.visible = lit
	_fire_light.light_energy = 2.6
