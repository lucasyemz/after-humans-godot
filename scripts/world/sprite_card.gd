## Personagem pintado em pé: uma placa cuja origem é o ponto do pé. Trocar de pose (show_art) mantém o pé no lugar, a
## partir da âncora e da altura do corpo em pixels de cada imagem (data/presentation/combat_art.json). Também vira para
## os dois lados, pisca ao levar dano e toca folhas de quadros (o robô parado).
class_name AHSpriteCard
extends MeshInstance3D

## A camada das placas de personagem (além da 1): o preenchimento da luta nos cenários só pega elas.
const CHARACTER_LAYER := 1 << 19
## A silhueta de quem está escondido atrás de alguma coisa (#51): um segundo passe só onde a placa está atrás.
const SILHOUETTE_SHADER := preload("res://shaders/character_silhouette.gdshader")
## Toda placa de personagem marca o stencil com isto: a silhueta de um não pinta por cima de outro.
const STENCIL_CHARACTER := 1
## A altura acima do pé (m) que fica sem silhueta (a borda do piso da frente encobre a sola em alguns cenários).
const SILHOUETTE_FOOT := 0.12
## O pulso do Último Fôlego (#281, a Porta da Morte do Darkest Dungeon): a luz vermelha que vai e volta no desenho.
const DANGER_COLOR := Color(1.0, 0.08, 0.06)
const DANGER_PERIOD := 1.1
const DANGER_MIN := 0.04
const DANGER_MAX := 0.3

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
var _silhouette: ShaderMaterial
## O destaque da escolha de alvo (#57): a luz na cor do lado, que fica até sair; o piscar do acerto volta para ela.
var _highlight := Color.BLACK
var _tint := Color.WHITE
var _dimmed := false
## No Último Fôlego (#281): o pulso vermelho está ligado e onde ele está no ciclo (segundos).
var _danger := false
var _danger_time := 0.0
## Quanto acima do pé (m) fica sem silhueta: o padrão, ou a borda do piso da frente da zona do cenário (#51).
var silhouette_foot := SILHOUETTE_FOOT


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
	_material.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	_material.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	_material.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS
	_material.stencil_reference = STENCIL_CHARACTER


## Mostra uma arte do manifesto: {file, canvas, anchor, body_reference_pixels} e, numa folha, frames e fps.
func show_art(art: Dictionary) -> void:
	_art = art
	_texture = load(art.file)
	_material.albedo_texture = _texture
	if _silhouette != null:
		_silhouette.set_shader_parameter("albedo_tex", _texture)
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
	if _danger:
		_danger_time = fmod(_danger_time + delta, DANGER_PERIOD)
		if _flash_tween == null or not _flash_tween.is_running():
			_material.emission = _rest_emission()
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
	if _silhouette != null:
		_silhouette.set_shader_parameter("uv_offset", Vector2(_material.uv1_offset.x, _material.uv1_offset.y))
		_silhouette.set_shader_parameter("uv_scale", Vector2(_material.uv1_scale.x, _material.uv1_scale.y))
		# O pé e um pouco acima dele (SILHOUETTE_FOOT metros) não ganham silhueta.
		var foot_px := region.size.y - anchor.y + silhouette_foot / px_to_m
		_silhouette.set_shader_parameter("foot_cut", clampf(foot_px / region.size.y, 0.0, 0.5))


## Liga a silhueta na cor dada (a equipe sempre, os inimigos só na luta) ou desliga com null.
func set_silhouette(color) -> void:
	if color == null:
		_material.next_pass = null
		return
	if _silhouette == null:
		_silhouette = ShaderMaterial.new()
		_silhouette.shader = SILHOUETTE_SHADER
		# Depois dos transparentes do cenário: a silhueta fica por cima do que esconde o personagem.
		_silhouette.render_priority = 1
	_silhouette.set_shader_parameter("color", color)
	_silhouette.set_shader_parameter("albedo_tex", _texture)
	_material.next_pass = _silhouette
	_layout()


func set_silhouette_foot(meters: float) -> void:
	silhouette_foot = meters
	_layout()


func has_silhouette() -> bool:
	return _material.next_pass != null


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
	_flash_tween.tween_property(_material, "emission", _rest_emission(), seconds)
	# O destaque pode ter mudado durante o piscar (a mira abriu no meio): termina no atual.
	_flash_tween.tween_callback(func(): _material.emission = _rest_emission())


## Mistura por alfa (efeitos com transparência suave) em vez do recorte duro dos personagens.
func set_blended(blended: bool) -> void:
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if blended else BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	# O efeito não marca o stencil: o retângulo inteiro dele (alfa 0 incluído) abria um buraco na silhueta de trás.
	_material.stencil_mode = BaseMaterial3D.STENCIL_MODE_DISABLED if blended else BaseMaterial3D.STENCIL_MODE_CUSTOM
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if blended else BaseMaterial3D.SHADING_MODE_PER_PIXEL


## Escurece e dessatura (herói caído, inimigo derrotado sumindo).
func set_tint(color: Color) -> void:
	_tint = color
	_apply_albedo()


## O destaque da escolha de alvo (#57): uma luz na cor (strength de 0 a 1; 0 apaga) e, dimmed, o personagem um pouco
## escurecido (quem não pode ser alvo). As cores e as forças vêm de AHUiStyle.
func set_highlight(color: Color, strength: float, dimmed: bool = false) -> void:
	_highlight = color * strength if strength > 0.0 else Color.BLACK
	_highlight.a = 1.0
	if _flash_tween == null or not _flash_tween.is_running():
		_material.emission = _rest_emission()
		_material.emission_energy_multiplier = 0.7
	_dimmed = dimmed
	_apply_albedo()


## Liga ou desliga o pulso vermelho do Último Fôlego (#281). Ele soma ao destaque da mira e volta depois de um piscar.
func set_danger(on: bool) -> void:
	if on == _danger:
		return
	_danger = on
	_danger_time = 0.0
	if _flash_tween == null or not _flash_tween.is_running():
		_material.emission = _rest_emission()


func in_danger() -> bool:
	return _danger


## A luz de descanso: o destaque da mira mais o pulso do Último Fôlego (um seno, de DANGER_MIN a DANGER_MAX).
func _rest_emission() -> Color:
	if not _danger:
		return _highlight
	var wave := 0.5 - 0.5 * cos(TAU * _danger_time / DANGER_PERIOD)
	var light := _highlight + DANGER_COLOR * lerpf(DANGER_MIN, DANGER_MAX, wave)
	light.a = 1.0
	return light


func highlight() -> Color:
	return _highlight


func dimmed() -> bool:
	return _dimmed


func _apply_albedo() -> void:
	var factor := AHUiStyle.TARGET_DIM if _dimmed else 1.0
	_material.albedo_color = Color(_tint.r * factor, _tint.g * factor, _tint.b * factor, _tint.a)


## Altura da cabeça acima do pé, em metros (para barras e números).
func head_height() -> float:
	return body_height * 1.05


## A arte que o cartão mostra agora (a entrada de combat_art.json, com os quadros e a âncora).
func art() -> Dictionary:
	return _art
