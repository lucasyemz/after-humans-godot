## O anel de quem age (#60, docs/design/hud-target.md): a peça actor_ring do kit num plano deitado no chão, sob os pés
## do ator, com o teste de profundidade (o corpo do personagem esconde a parte de trás, como a máscara das botas da
## composição do alvo). A elipse do desenho já está em perspectiva (256x80): o plano tem a profundidade que, vista pela
## câmera da luta, dá essa proporção na tela, e a largura de 248 px na base de 1080p. Sem pulso (Reduzir efeitos não
## muda nada aqui): a mesma informação está na barra e no retrato da rodada.
class_name AHActorRing
extends MeshInstance3D

## A largura na tela, em px na base de 1080p.
const SCREEN_WIDTH := 248.0
## Acima do chão (m): não briga com o piso no teste de profundidade.
const LIFT := 0.012

var _quad := QuadMesh.new()
var _material := StandardMaterial3D.new()
var _card: AHSpriteCard


func _init() -> void:
	mesh = _quad
	rotation_degrees.x = -90.0
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_texture = AHKit.texture("actor_ring")
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.no_depth_test = false
	_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


## Segue o personagem (null esconde).
func follow(card: AHSpriteCard) -> void:
	_card = card
	visible = card != null and card.visible


func _process(_delta: float) -> void:
	if _card == null or not is_instance_valid(_card) or not _card.visible:
		visible = false
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	visible = true
	var feet := _card.global_position
	global_position = feet + Vector3(0, LIFT, 0)
	# Metros por pixel na profundidade do pé: o corpo (m) sobre a altura dele na tela (px), na base de 1080p.
	var feet_px := camera.unproject_position(feet)
	var head_px := camera.unproject_position(feet + Vector3(0, _card.body_height, 0))
	var view_scale := 1080.0 / maxf(1.0, get_viewport().get_visible_rect().size.y)
	var body_px := maxf(8.0, (feet_px.y - head_px.y) * view_scale)
	var width := SCREEN_WIDTH * _card.body_height / body_px
	# A profundidade: a elipse do desenho (80/256) dividida pelo quanto o chão encolhe visto pela câmera.
	var pitch := absf(camera.global_transform.basis.z.normalized().y)
	var depth := width * (80.0 / 256.0) / maxf(0.15, pitch)
	_quad.size = Vector2(width, depth)
