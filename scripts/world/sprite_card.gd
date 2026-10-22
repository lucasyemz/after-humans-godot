## Personagem pintado em pé: uma placa cuja origem é o ponto do pé. Trocar de pose (show_art) mantém o pé no lugar, a
## partir da âncora e da altura do corpo em pixels de cada imagem (data/presentation/combat_art.json). Também vira para
## os dois lados, pisca ao levar dano e toca folhas de quadros (o robô parado).
class_name AHSpriteCard
extends MeshInstance3D

## A camada das placas de personagem (além da 1): o preenchimento da luta nos cenários só pega elas.
const CHARACTER_LAYER := 1 << 19

## Altura do corpo em metros (do pé ao topo da cabeça na pose parada).
var body_height := 1.8
var facing := 1.0
var _quad := QuadMesh.new()
var _material := StandardMaterial3D.new()
var _art := {}
var _texture: Texture2D
var _frame := 0
var _frame_time := 0.0
var _flash_tween: Tween


func _init() -> void:
	mesh = _quad
	layers = 1 | CHARACTER_LAYER
	material_override = _material
	# A placa muda de tamanho e de deslocamento a cada pose e quadro: sem margem, a câmera podia descartá-la como fora
	# da tela (a sombra continuava aparecendo).
	extra_cull_margin = 2.0
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_material.alpha_scissor_threshold = 0.5
	_material.roughness = 1.0
	_material.metallic_specular = 0.15
	# Placa fina: a luz de trás também conta.
	_material.backlight_enabled = true
	_material.backlight = Color(0.45, 0.45, 0.45)
	_material.emission_enabled = true
	_material.emission = Color.BLACK


## Mostra uma arte do manifesto: {file, canvas, anchor, body_reference_pixels} e, numa folha, frames e fps.
func show_art(art: Dictionary) -> void:
	_art = art
	_texture = load(art.file)
	_material.albedo_texture = _texture
	_frame = 0
	_frame_time = 0.0
	_layout()


## Mostra uma imagem inteira com a base no pé (as placas da rua, sem manifesto).
func show_plain(texture: Texture2D) -> void:
	show_art({"file": texture.resource_path, "canvas": [texture.get_width(), texture.get_height()],
		"anchor": [texture.get_width() * 0.5, texture.get_height()], "body_reference_pixels": texture.get_height()})


func set_facing(value: float) -> void:
	if value != facing:
		facing = value
		_layout()


func _process(delta: float) -> void:
	if _art.has("frames"):
		_frame_time += delta
		var step := 1.0 / float(_art.get("fps", 10))
		if _frame_time >= step:
			_frame_time -= step
			_frame = (_frame + 1) % _art.frames.size()
			_layout()


func _layout() -> void:
	if _texture == null:
		return
	# Medidas do manifesto em pixels da imagem original; a textura pode ter sido reduzida.
	var canvas := Vector2(_art.canvas[0], _art.canvas[1])
	var region := Rect2(Vector2.ZERO, canvas)
	var texture_scale := float(_texture.get_width()) / canvas.x
	if _art.has("frames"):
		var f: Array = _art.frames[_frame]
		region = Rect2(f[0], f[1], f[2], f[3])
		texture_scale = 1.0
	var px_to_m := body_height / float(_art.body_reference_pixels)
	var size := region.size * px_to_m
	_quad.size = size
	# A âncora (pé) fica na origem: o centro da placa se desloca a partir dela.
	var anchor := Vector2(_art.anchor[0], _art.anchor[1])
	var offset := Vector2(region.size.x * 0.5 - anchor.x, anchor.y - region.size.y * 0.5) * px_to_m
	_quad.center_offset = Vector3(offset.x * facing, offset.y, 0)
	var tex_size := Vector2(_texture.get_width(), _texture.get_height())
	var uv_pos := region.position * texture_scale / tex_size
	var uv_size := region.size * texture_scale / tex_size
	if facing < 0.0:
		_material.uv1_offset = Vector3(uv_pos.x + uv_size.x, uv_pos.y, 0)
		_material.uv1_scale = Vector3(-uv_size.x, uv_size.y, 1)
	else:
		_material.uv1_offset = Vector3(uv_pos.x, uv_pos.y, 0)
		_material.uv1_scale = Vector3(uv_size.x, uv_size.y, 1)


## Pisca numa cor (dano vermelho, cura verde) e volta.
## Pisca na cor e apaga em seconds; com white_seconds, começa com um clarão branco que vira a cor (o acerto, #33).
func flash(color: Color, seconds: float = 0.35, white_seconds: float = 0.0) -> void:
	if _flash_tween:
		_flash_tween.kill()
	_material.emission = Color.WHITE if white_seconds > 0.0 else color
	_material.emission_energy_multiplier = 0.7
	_flash_tween = create_tween()
	if white_seconds > 0.0:
		_flash_tween.tween_property(_material, "emission", color, white_seconds)
	_flash_tween.tween_property(_material, "emission", Color.BLACK, seconds)


## Mistura por alfa (efeitos com transparência suave) em vez do recorte duro dos personagens.
func set_blended(blended: bool) -> void:
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if blended else BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if blended else BaseMaterial3D.SHADING_MODE_PER_PIXEL


## Escurece e dessatura (herói caído, inimigo derrotado sumindo).
func set_tint(color: Color) -> void:
	_material.albedo_color = color


## Altura da cabeça acima do pé, em metros (para barras e números).
func head_height() -> float:
	return body_height * 1.05
