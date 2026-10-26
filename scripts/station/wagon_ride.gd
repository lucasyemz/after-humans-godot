## A partida no vagão (#75): a cena de fundo da passagem da Estação para a fase. A equipe escolhida sentada no banco do
## metrô (o mesmo Bombardier da Estação, com os materiais de lá) enquanto o túnel passa pelas janelas: as luminárias da
## parede correndo para trás, a parede de concreto escorrendo e a câmera balançando com o trilho. Os fundadores usam a
## pose sentada (data/presentation/station_poses.json, *_seat); os recrutas, sem ela, ficam de pé nas pontas do banco
## até a arte do vagão do Codex (#79), que troca esta primeira versão pelo interior pintado.
class_name AHWagonRide
extends Node3D

## Quanto o vagão fica sozinho antes de o título da fase aparecer por cima.
const RIDE_SECONDS := 2.8
## O banco do fundo do vagão (m, no corpo do metrô): o meio, o piso, a frente do assento e o vão entre os lugares.
const BENCH_X := 2.0
const FLOOR_Y := 0.96
const SEAT_Z := -0.6
const STAND_Z := -0.45
## O assento do banco vai de BENCH_START a BENCH_END (medido no modelo): até quatro sentados lado a lado, ombro com ombro.
const BENCH_START := 1.2
const BENCH_END := 2.8
const SEAT_SLOT := 0.53
## Quem está de pé ocupa mais (o corpo inteiro, a cauda): fica fora do assento, nas pontas, com mais folga.
const STAND_SLOT := 0.85
## A folga entre o banco ocupado e o primeiro de pé (a cauda e a mochila de quem está de pé).
const STAND_GAP := 0.2
## O quadro da câmera, na altura da equipe (x em m): ninguém fica fora dele.
const FRAME_X := [0.15, 3.85]
## O túnel lá fora: a parede atrás das janelas do fundo, as luminárias e a velocidade do trem.
const TUNNEL_Z := -2.7
const LAMP_SPACING := 3.6
const SPEED := 13.0
const WARM := Color(1.0, 0.78, 0.52)

## A equipe (ids dos heróis, posição 1 primeiro).
var team: Array = []
## Os cartões de quem está no banco, na ordem da esquerda para a direita, com {"id", "seated"}.
var seats: Array = []
var _camera: Camera3D
var _camera_home := Vector3(BENCH_X, 1.86, 1.4)
## Para onde a câmera olha (a altura, no fundo do vagão): uns 2,4° para baixo.
const LOOK_Y := 1.75
var _lamps: Array[Node3D] = []
var _wall: StandardMaterial3D
var _time := 0.0


func _init(hero_ids: Array = []) -> void:
	team = hero_ids.duplicate()
	name = "WagonRide"


## O cartão da passagem da partida: o da rua (a fase e o trecho) com o vagão por trás e o título depois do passeio.
static func departure_card(campaign: Dictionary) -> Dictionary:
	var card: Dictionary = GameFlow.card_for("street")
	var expedition = campaign.get("session", {}).get("expedition")
	if card.is_empty() or expedition == null:
		return card
	card.backdrop = AHWagonRide.new(expedition.get("team", []))
	card.title_delay = RIDE_SECONDS
	card.hold = RIDE_SECONDS + GameFlow.CARD_SECONDS
	return card


func _ready() -> void:
	_environment()
	_wagon()
	_tunnel()
	_team()
	_camera = Camera3D.new()
	# Quase na horizontal e com o fov fechado o bastante para o chão da borda de baixo ficar além do corte (near): com
	# a câmera inclinada, o chão perto dela era cortado e a borda de baixo ficava com uma faixa preta serrilhada.
	_camera.fov = 60.0
	# O lado de perto do vagão (o banco, as barras e a divisória entre a câmera e o corredor) fica inteiro fora do quadro:
	# com o corte mais perto, as seções cortadas apareciam como peças soltas no chão.
	_camera.near = 1.3
	_camera.current = true
	add_child(_camera)
	_place_camera()


func _process(delta: float) -> void:
	_time += delta
	for lamp in _lamps:
		lamp.position.x -= SPEED * delta
		if lamp.position.x < BENCH_X - LAMP_SPACING * 2.0:
			lamp.position.x += LAMP_SPACING * _lamps.size()
	# 40 m de parede em 32 repetições: 1,25 m por repetição.
	_wall.uv1_offset.x += SPEED * delta / 1.25
	_place_camera()


## O balanço do trilho: uma ondulação curta e outra longa, e um leve giro.
func _place_camera() -> void:
	var sway := Vector3(0.0, 0.010 * sin(_time * 9.0) + 0.006 * sin(_time * 2.3), 0.0)
	_camera.position = _camera_home + sway
	_camera.look_at(Vector3(BENCH_X, LOOK_Y, -1.2) + sway)
	_camera.rotate_object_local(Vector3.FORWARD, deg_to_rad(0.35 * sin(_time * 1.7)))


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.025)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.45)
	env.ambient_light_energy = 0.18
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)


## O metrô com as peças e os materiais da Estação (AHStationBuild), na origem.
func _wagon() -> void:
	var builder := AHStationBuilder.new(self)
	var build := AHStationBuild.new(builder)
	var pieces: Array[Node3D] = [build._metro_piece("SM_BombardierBody", AHStationBuild.METRO_BODY_SLOTS)]
	for door in AHStationBuild.METRO_DOORS:
		pieces.append(build._metro_piece(door[0], AHStationBuild.METRO_DOOR_SLOTS))
	# O vidro da Estação é claro (lá fora é a plataforma acesa); aqui, o túnel escuro aparece pelas janelas.
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.04, 0.05, 0.05, 0.3)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.2
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	for piece in pieces:
		piece.position = Vector3.ZERO
		for mesh: MeshInstance3D in piece.find_children("*", "MeshInstance3D", true, false):
			for index in mesh.mesh.get_surface_count():
				if mesh.get_surface_override_material(index) == builder.glass():
					mesh.set_surface_override_material(index, glass)
	# As luminárias do teto ao longo do vagão (a da frente do banco mais forte).
	for x in [BENCH_X - 4.5, BENCH_X, BENCH_X + 4.5]:
		var light := OmniLight3D.new()
		light.position = Vector3(x, 3.1, 0.0)
		light.light_color = WARM
		light.light_energy = 1.1 if x == BENCH_X else 0.7
		light.omni_range = 5.5
		light.omni_attenuation = 1.2
		add_child(light)


## A parede do túnel atrás das janelas do fundo e as luminárias que passam.
func _tunnel() -> void:
	# O concreto da Estação, numa placa que escorre (a textura anda: o trem passa por ela).
	_wall = StandardMaterial3D.new()
	_wall.albedo_texture = preload("res://art/station/rough_concrete.webp")
	_wall.albedo_color = Color(0.16, 0.15, 0.14)
	_wall.uv1_scale = Vector3(32, 5, 1)
	_wall.roughness = 1.0
	var wall := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(40, 6)
	wall.mesh = plane
	wall.position = Vector3(BENCH_X, 2.0, TUNNEL_Z)
	wall.material_override = _wall
	add_child(wall)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = WARM
	glow.emission_enabled = true
	glow.emission = WARM
	glow.emission_energy_multiplier = 4.0
	for index in 10:
		var lamp := Node3D.new()
		lamp.position = Vector3(BENCH_X - LAMP_SPACING * 2.0 + index * LAMP_SPACING, 2.25, TUNNEL_Z + 0.05)
		var tube := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.4, 0.1, 0.05)
		tube.mesh = box
		tube.material_override = glow
		lamp.add_child(tube)
		var light := OmniLight3D.new()
		light.light_color = WARM
		light.light_energy = 1.4
		light.omni_range = 3.2
		light.position = Vector3(0, 0, 0.4)
		lamp.add_child(light)
		add_child(lamp)
		_lamps.append(lamp)


## A equipe no banco: os sentados no meio, quem não tem pose sentada de pé nas pontas.
func _team() -> void:
	var poses: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/station_poses.json"))
	var combat_art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AHCombatArena.ART_MANIFEST))
	var seated: Array = []
	var standing: Array = []
	# Posição 1 na direita, como a fila da partida na plataforma.
	var order := team.duplicate()
	order.reverse()
	for hero_id in order:
		var entry = AHStationRules.hero(Campaign.state, hero_id)
		if entry == null or not entry.get("alive", true):
			continue
		var seat: Dictionary = poses.get(String(hero_id) + "_seat", {})
		if not seat.is_empty():
			seated.append({"id": hero_id, "art": seat, "seated": true})
		else:
			var art := AHCombatArena.art_entry(combat_art.heroes, hero_id, String(entry.get("art_variant", "")))
			if art.has("idle"):
				standing.append({"id": hero_id, "art": art.idle, "seated": false})
	# Os sentados no meio do assento, na ordem da equipe (posição 1 à direita); quem está de pé nas pontas, por fora
	# deles: o primeiro da equipe na ponta direita, o seguinte à esquerda, e assim por diante. Cada um um pouco mais à frente
	# ou atrás do vizinho, para quem se sobrepõe não brigar na mesma profundidade.
	var left_edge := BENCH_X - seated.size() * SEAT_SLOT * 0.5
	var right_edge := BENCH_X + seated.size() * SEAT_SLOT * 0.5
	var spots: Array = []
	for index in seated.size():
		spots.append([seated[index], Vector3(left_edge + (index + 0.5) * SEAT_SLOT, FLOOR_Y, SEAT_Z - 0.03 * (index % 2)), 1.0])
	var by_position := standing.duplicate()
	by_position.reverse()
	var right_count := (by_position.size() + 1) / 2
	for index in by_position.size():
		var right := index % 2 == 0
		# Na direita, o primeiro da equipe vai mais para a ponta (a posição 1 à direita de todos).
		var step: int = right_count - 1 - index / 2 if right else index / 2
		var x := right_edge + STAND_GAP + STAND_SLOT * (step + 0.5) if right else left_edge - STAND_GAP - STAND_SLOT * (step + 0.5)
		# Os da direita olham para o meio (a arte olha para a direita).
		spots.append([by_position[index], Vector3(x, FLOOR_Y, STAND_Z - 0.03 * (index % 2)), -1.0 if right else 1.0])
	spots.sort_custom(func(a, b): return a[1].x < b[1].x)
	for entry in spots:
		var spot: Dictionary = entry[0]
		var card := AHSpriteCard.new()
		card.body_height = AHCharacterHeights.find(spot.id)
		card.show_art(spot.art)
		card.position = entry[1]
		card.set_facing(entry[2])
		add_child(card)
		seats.append({"id": spot.id, "seated": spot.seated, "card": card})
