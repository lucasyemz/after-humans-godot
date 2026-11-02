## A vista de fora no fim da linha (#217): pela abertura da abóbada sobre a boca do túnel (AHStationBuild.OUTSIDE_*), um
## pedaço do Bairro Submerso (o panorama da ponte, até a arte própria chegar) com a cor da hora do dia, e a luz de fora
## caindo de leve na ponta da plataforma. O resto da Estação não muda.
##
## A campanha não tem relógio: a hora vem do ciclo da Estação (o dia e a noite do #132). Na volta, com a noite a
## planejar, é fim de tarde; durante a cena da noite, noite; no resumo do amanhecer, amanhecer; no resto, dia. O clima
## da rua não fica guardado na Estação (some na volta), então a vista não tem chuva.
class_name AHStationOutside
extends Node3D

const HOURS := ["dawn", "day", "dusk", "night"]
## O panorama dos cenários que já existem (a cidade alagada); a arte própria da abertura é a issue de design.
const SKY := "res://art/scenarios/T_BridgePanorama.webp"
## Cada hora: a cor e o brilho da vista, o brilho do horizonte (cor e força), as estrelas, e a luz que entra (cor, força).
const LOOK := {
	"dawn": {"tint": Color(0.98, 0.8, 0.78), "brightness": 0.85, "glow": Color(1.0, 0.62, 0.5), "glow_amount": 0.35,
		"stars": 0.25, "light": Color(1.0, 0.8, 0.72), "energy": 0.9},
	"day": {"tint": Color(1.0, 1.0, 1.0), "brightness": 1.2, "glow": Color(1.0, 1.0, 1.0), "glow_amount": 0.0,
		"stars": 0.0, "light": Color(0.92, 0.95, 1.0), "energy": 1.6},
	"dusk": {"tint": Color(1.0, 0.76, 0.58), "brightness": 0.95, "glow": Color(1.0, 0.5, 0.24), "glow_amount": 0.5,
		"stars": 0.0, "light": Color(1.0, 0.72, 0.48), "energy": 1.2},
	"night": {"tint": Color(0.4, 0.46, 0.68), "brightness": 0.42, "glow": Color(0.3, 0.36, 0.6), "glow_amount": 0.1,
		"stars": 1.0, "light": Color(0.55, 0.65, 0.92), "energy": 0.35},
}
## O tempo da troca de uma hora para a outra (s).
const FADE := 1.5

var hour := ""
var view: MeshInstance3D
var light: SpotLight3D
var _material: ShaderMaterial
var _tween: Tween


## A hora de fora pela campanha e pela cena da noite (AHStation.night_scene).
static func hour_of(campaign: Dictionary, night_scene: bool) -> String:
	if night_scene:
		return "night"
	match String(campaign.get("night", {}).get("phase", "none")):
		"planning":
			return "dusk"
		"dawn":
			return "dawn"
	return "day"


## A vista e a luz atrás da abertura (cm da Unreal, como AHStationBuild): a vista em pé logo atrás do corte, no lugar da
## faixa da abóbada que saiu (do pé da abóbada até a rocha), um pouco mais larga que o vão (as pontas ficam atrás da
## abóbada que sobrou); nunca dentro do salão, onde tapava a parede. A luz no vão, apontada para a ponta da plataforma.
func build() -> void:
	var depth := -10.0
	var x0 := AHStationBuild.OUTSIDE_X0 - 120.0
	var x1 := AHStationBuild.OUTSIDE_X1 + 150.0
	var z0 := AHStationBuild.vault_z(depth) + 2.0
	# Até o lintel: acima dele, a rocha (a vista não passa do contorno da Estação).
	var z1 := AHStationBuild.VAULT_SPRING + AHStationBuild.VAULT_RISE + 10.0
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/station_outside.gdshader")
	_material.set_shader_parameter("sky_tex", load(SKY))
	var quad := QuadMesh.new()
	quad.size = Vector2((x1 - x0) * 0.01, (z1 - z0) * 0.01)
	view = MeshInstance3D.new()
	view.name = "OutsideView"
	view.mesh = quad
	view.material_override = _material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.position = AHStationBuilder.v((x0 + x1) * 0.5, depth, (z0 + z1) * 0.5)
	add_child(view)
	light = SpotLight3D.new()
	light.name = "OutsideLight"
	light.position = AHStationBuilder.v((AHStationBuild.OUTSIDE_X0 + AHStationBuild.OUTSIDE_X1) * 0.5, -200.0, AHStationBuild.VAULT_SPRING + 200.0)
	light.spot_range = 7.0
	light.spot_angle = 50.0
	light.spot_attenuation = 1.2
	light.shadow_enabled = false
	add_child(light)
	# Para baixo: a borda da plataforma e a via na frente do trem, perto da boca do túnel.
	light.look_at(AHStationBuilder.v(420.0, -300.0, -100.0), Vector3.UP)


## Mostra a hora (com a troca suave, ou na hora com instant). Hora desconhecida vira dia.
func show_hour(next: String, instant: bool = false) -> void:
	if not LOOK.has(next):
		next = "day"
	if next == hour and not instant:
		return
	hour = next
	var look: Dictionary = LOOK[next]
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	var values := {"tint": look.tint * look.brightness, "glow": Color(look.glow, look.glow_amount), "stars": float(look.stars)}
	if instant or not is_inside_tree():
		for key in values:
			_material.set_shader_parameter(key, values[key])
		light.light_color = look.light
		light.light_energy = look.energy
		return
	_tween = create_tween().set_parallel(true)
	for key in values:
		_tween.tween_method(func(v): _material.set_shader_parameter(key, v), _material.get_shader_parameter(key), values[key], FADE)
	_tween.tween_property(light, "light_color", look.light, FADE)
	_tween.tween_property(light, "light_energy", float(look.energy), FADE)


## O que a vista mostra agora (para os testes): a cor (já com o brilho), o brilho do horizonte e as estrelas.
func shown() -> Dictionary:
	return {"tint": _material.get_shader_parameter("tint"), "glow": _material.get_shader_parameter("glow"),
		"stars": _material.get_shader_parameter("stars"), "light": light.light_color, "energy": light.light_energy}
