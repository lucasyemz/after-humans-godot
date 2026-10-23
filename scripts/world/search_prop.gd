## Um ponto de busca com o objeto à vista (#50): o card do prop fechado, que troca para o aberto depois de vasculhado.
## A arte (tools/convert_search_props.py) tem a tela inteira nos dois estados e a âncora no pé no mesmo ponto; a
## escala sai da altura de referência (do pé ao topo fechado) e da altura do objeto em metros
## (data/presentation/search_props.json). O nó fica no pé; o losango de "dá para usar" vai logo acima do topo fechado.
class_name AHSearchProp
extends Node3D

const TABLE := "res://data/presentation/search_props.json"
## O losango fica esta distância (px da textura) acima do topo fechado (32 px na tela original).
const MARKER_PIXELS := 16.0
## Os da rua, na ordem em que se alternam pelos trechos de busca.
const STREET := ["street_crates", "street_trash_can", "street_mailbox"]
## Os três de cada loja, na ordem dos pontos (SPOT_NAMES).
const SHOPS := [["grocery_cash_counter", "grocery_refrigerator", "grocery_shelving"],
	["workshop_workbench", "workshop_engine", "workshop_parts_cabinet"],
	["cinema_ticket_booth", "cinema_popcorn_cart", "cinema_stair_cabinet"]]

static var _table: Dictionary = {}

var prop_name := ""
var opened := false
var spec: Dictionary = {}
var _card: MeshInstance3D
var _material: StandardMaterial3D
var _meters_per_pixel := 0.01


static func table() -> Dictionary:
	if _table.is_empty():
		_table = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
	return _table


## O prop do ponto spot da loja shop (o quarto ponto, se houver, repete o primeiro).
static func shop_prop(shop: int, spot: int) -> String:
	return SHOPS[clampi(shop, 0, 2)][spot % 3]


static func street_prop(order: int) -> String:
	return STREET[order % STREET.size()]


func setup(name_id: String, open: bool) -> AHSearchProp:
	prop_name = name_id
	spec = table()[name_id]
	name = "SearchProp_" + name_id
	_meters_per_pixel = float(spec.height_m) / float(spec.body_reference_pixels)
	var canvas := Vector2(spec.canvas[0], spec.canvas[1])
	var anchor := Vector2(spec.anchor[0], spec.anchor[1])
	var quad := QuadMesh.new()
	quad.size = canvas * _meters_per_pixel
	_card = MeshInstance3D.new()
	_card.name = "Card"
	_card.mesh = quad
	# O centro da tela fica acima (e ao lado) da âncora: a âncora cai no nó.
	_card.position = Vector3((canvas.x * 0.5 - anchor.x) * _meters_per_pixel, (anchor.y - canvas.y * 0.5) * _meters_per_pixel, 0)
	_material = StandardMaterial3D.new()
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_material.alpha_scissor_threshold = 0.5
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.roughness = 1.0
	_material.metallic_specular = 0.15
	_material.backlight_enabled = true
	_material.backlight = Color(0.45, 0.45, 0.45)
	_card.material_override = _material
	add_child(_card)
	set_open(open)
	return self


func set_open(open: bool) -> void:
	opened = open
	_material.albedo_texture = load(spec.open if open else spec.closed)


## O ponto do losango, no mundo: no centro do topo fechado, um pouco acima dele.
func marker_point() -> Vector3:
	return to_global(Vector3(0, (float(spec.body_reference_pixels) + MARKER_PIXELS) * _meters_per_pixel, 0))


## A caixa do volume do objeto (metros, no espaço do pai): pé no chão, largura e profundidade da tabela.
func volume() -> AABB:
	var size := Vector3(float(spec.width_m), float(spec.height_m), float(spec.depth_m))
	return AABB(position - Vector3(size.x * 0.5, 0, size.z * 0.5), size)
