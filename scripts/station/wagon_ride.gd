## A viagem no vagão (#75, pintada na #256): a cena de fundo da passagem. Dentro, o interior do mesmo vagão verde do
## Tutorial (#149, o contrato em data/presentation/train_2d.json), com o túnel correndo nas janelas e a equipe sentada de
## frente nos bancos da parede (station_poses.json, *_seat_front, #253); quem não tem essa pose (os recrutas, a skin
## sem ela) fica de pé na frente do lugar dele. Antes do interior, o vagão parte no túnel, com as rodas girando. A
## chegada com a faísca fica só onde dá para ver o trem parar (a plataforma da Estação, o Tutorial): aqui, só a freada.
class_name AHWagonRide
extends Control

## Quanto a viagem fica sozinha antes de o título da fase aparecer por cima (a partida no túnel e o interior).
const RIDE_SECONDS := 2.8
## O plano da partida no túnel, no começo.
const DEPART_SECONDS := 1.3
## O trem andando na passagem (#133), no canal do Ambiente.
const RIDE_SOUND := "res://audio/station/train_ride.ogg"
const RIDE_GAIN := 0.8
const BRAKE_SOUND := "res://audio/station/train_brake.ogg"
## O quadro da passagem (px): a cena cobre a tela inteira, centrada.
const FRAME := Vector2(1920, 1080)
## O plano do túnel: o vagão na escala da tela, o trilho nesta altura e o caminho que ele faz na partida (px).
const TUNNEL_SCALE := 1.1
const TUNNEL_RAIL_Y := 700.0
const TUNNEL_RUN := 1700.0
## Os lugares usados por tamanho da equipe (índices dos quatro do contrato, da esquerda para a direita): a posição 1
## fica na direita, e uma equipe menor senta junta, do lado direito do vagão.
const SLOTS := {1: [2], 2: [2, 3], 3: [1, 2, 3], 4: [0, 1, 2, 3]}

## A equipe (ids dos heróis, posição 1 primeiro).
var team: Array = []
## Quem está no vagão, da esquerda para a direita, com {"id", "seated", "card" (o Sprite2D)}.
var seats: Array = []
var depart_shot := true

var _p: Dictionary
var _stage: Node2D
var _inside: Node2D
var _outside: Node2D
var _tunnel: Sprite2D
var _car: AHTrainCar2D
var _time := 0.0
var _opened_ms := -1
var _car_home := 0.0


## hero_ids: a equipe. depart: com o plano da partida no túnel antes do interior.
func _init(hero_ids: Array = [], depart: bool = true) -> void:
	team = hero_ids.duplicate()
	depart_shot = depart
	name = "WagonRide"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_p = AHTrainCar.contract().passage
	_stage = Node2D.new()
	add_child(_stage)
	_build_inside()
	_build_outside()
	_show(depart_shot)


## O cartão da passagem da partida: o da rua (a fase e o trecho) com a viagem por trás e o título depois da partida e
## do interior.
static func departure_card(campaign: Dictionary) -> Dictionary:
	var card: Dictionary = GameFlow.card_for("street")
	var expedition = campaign.get("session", {}).get("expedition")
	if card.is_empty() or expedition == null:
		return card
	card.backdrop = AHWagonRide.new(expedition.get("team", []))
	# O trem saindo da plataforma, andando no túnel e freando na chegada (#133).
	card.sound = {"loop": RIDE_SOUND, "gain": RIDE_GAIN, "start": "res://audio/station/train_departure.ogg",
		"end": BRAKE_SOUND}
	card.title_delay = RIDE_SECONDS
	card.hold = RIDE_SECONDS + GameFlow.CARD_SECONDS
	return card


## O cartão da volta à Estação (#133): o da Estação, com o trem andando por baixo. A freada, o sino e a chegada tocam
## na plataforma, já na Estação.
static func return_card() -> Dictionary:
	var card: Dictionary = GameFlow.card_for("station")
	card.sound = {"loop": RIDE_SOUND, "gain": RIDE_GAIN}
	return card


func _ready() -> void:
	resized.connect(_fit)
	_fit()


func _process(_delta: float) -> void:
	# Pelo relógio, como o cartão (o título e o tempo dele): numa máquina lenta o delta chega cortado, e a chegada
	# atrasava até depois de o cartão fechar.
	if _opened_ms < 0:
		_opened_ms = Time.get_ticks_msec()
	_time = (Time.get_ticks_msec() - _opened_ms) / 1000.0
	_tunnel.region_rect.position.x = _time * float(_p.tunnel.scroll_px_per_second) / float(_p.tunnel.scale)
	if depart_shot and _time < DEPART_SECONDS:
		_show(true)
		# A partida: parado no meio, o vagão acelera e sai pela direita.
		var t := _time / DEPART_SECONDS
		_car.drive(_car_home + TUNNEL_RUN * t * t)
		return
	_show(false)


func _show(outside: bool) -> void:
	_outside.visible = outside
	_inside.visible = not outside


## A cena de 1920 × 1080 cobre a tela, centrada (corta as sobras, sem faixa preta).
func _fit() -> void:
	var view := size if size.x > 0.0 else get_viewport_rect().size
	var k := maxf(view.x / FRAME.x, view.y / FRAME.y)
	_stage.scale = Vector2(k, k)
	_stage.position = (view - FRAME * k) * 0.5


func _build_inside() -> void:
	_inside = Node2D.new()
	_inside.name = "Inside"
	_stage.add_child(_inside)
	var back := ColorRect.new()
	back.color = Color(0.02, 0.02, 0.025)
	back.size = FRAME
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inside.add_child(back)
	# O túnel: a faixa repetida em X, atrás dos vãos das janelas, correndo para trás.
	var tunnel: Dictionary = _p.tunnel
	_tunnel = Sprite2D.new()
	_tunnel.texture = load(tunnel.file)
	_tunnel.centered = false
	_tunnel.region_enabled = true
	_tunnel.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_tunnel.region_rect = Rect2(0, 0, FRAME.x / float(tunnel.scale), _tunnel.texture.get_height())
	_tunnel.scale = Vector2(tunnel.scale, tunnel.scale)
	_tunnel.position = Vector2(tunnel.position[0], tunnel.position[1])
	_tunnel.modulate = Color(tunnel.modulate[0], tunnel.modulate[1], tunnel.modulate[2])
	_inside.add_child(_tunnel)
	var background := Sprite2D.new()
	background.texture = load(_p.background.file)
	background.centered = false
	_inside.add_child(background)
	var shadows := Node2D.new()
	_inside.add_child(shadows)
	var people := Node2D.new()
	_inside.add_child(people)
	var poles := Sprite2D.new()
	poles.texture = load(_p.poles.file)
	poles.centered = false
	_inside.add_child(poles)
	_team(shadows, people)


## A equipe nos lugares: a posição 1 no lugar mais à direita. Sentado de frente quem tem a pose (o quadril no assento),
## de pé na frente do lugar quem não tem.
func _team(shadows: Node2D, people: Node2D) -> void:
	var poses: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/station_poses.json"))
	var combat_art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AHCombatArena.ART_MANIFEST))
	var riders: Array = []
	for hero_id in team:
		var entry = AHStationRules.hero(Campaign.state, hero_id)
		if entry == null or not entry.get("alive", true) or riders.size() >= 4:
			continue
		var seat := AHSkins.seat_pose(poses, String(hero_id), "front")
		if not seat.is_empty() and seat.has("hip"):
			riders.append({"id": hero_id, "art": seat, "seated": true})
			continue
		var art := AHCombatArena.art_entry(combat_art.heroes, hero_id, String(entry.get("art_variant", "")))
		if art.has("idle"):
			riders.append({"id": hero_id, "art": art.idle, "seated": false})
	if riders.is_empty():
		return
	var slots: Array = SLOTS[riders.size()]
	var px_per_m: float = _p.px_per_m
	var tint := Color(_p.hero_modulate[0], _p.hero_modulate[1], _p.hero_modulate[2])
	var placed: Array = []
	for index in riders.size():
		var rider: Dictionary = riders[index]
		# A posição 1 à direita: o primeiro da equipe no último lugar.
		var seat_spec: Dictionary = _p.seats[slots[slots.size() - 1 - index]]
		var art: Dictionary = rider.art
		var texture: Texture2D = load(art.file)
		# A arte pode estar numa resolução diferente do canvas medido (as da luta ficam na metade).
		var half: float = texture.get_width() / float(art.canvas[0])
		var scale: float = AHCharacterHeights.find(rider.id) * px_per_m / (float(art.body_reference_pixels) * half)
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.scale = Vector2(scale, scale)
		sprite.modulate = tint
		var x: float = seat_spec.seat_support[0]
		var foot := Vector2(x, float(seat_spec.projected_foot_anchor[1]))
		if rider.seated:
			# O ponto hip da pose no assento (os pés caem no chão à frente do banco).
			sprite.position = Vector2(x, seat_spec.seat_support[1]) - Vector2(art.hip[0], art.hip[1]) * half * scale
			foot = sprite.position + Vector2(art.anchor[0], art.anchor[1]) * half * scale
			_shadow(shadows, Vector2(x, float(seat_spec.seat_support[1]) + 8.0), scale * half * float(art.body_reference_pixels) / 946.0, 1.0)
		else:
			# De pé na frente do lugar, os pés no chão, olhando para o meio do vagão.
			var facing := 1.0 if x < FRAME.x * 0.5 else -1.0
			sprite.flip_h = facing < 0.0
			var anchor_x: float = float(art.anchor[0]) * half
			if sprite.flip_h:
				anchor_x = texture.get_width() - anchor_x
			sprite.position = foot - Vector2(anchor_x, float(art.anchor[1]) * half) * scale
		_shadow(shadows, foot, scale * half * float(art.body_reference_pixels) / 946.0, 0.8)
		people.add_child(sprite)
		placed.append({"id": rider.id, "seated": rider.seated, "card": sprite, "x": x})
	placed.sort_custom(func(a, b): return a.x < b.x)
	for spot in placed:
		seats.append({"id": spot.id, "seated": spot.seated, "card": spot.card})


## A sombra de contato: no assento, sob o quadril, e no chão, sob o pé (a largura do contrato na escala de quem senta).
func _shadow(holder: Node2D, at: Vector2, body_scale: float, strength: float) -> void:
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	soft.gradient = Gradient.new()
	soft.gradient.set_color(0, Color(0, 0, 0, 0.55))
	soft.gradient.set_color(1, Color(0, 0, 0, 0))
	var width: float = float(_p.shadow_width_px) * body_scale
	var shadow := Sprite2D.new()
	shadow.texture = soft
	shadow.position = at
	shadow.scale = Vector2(width / 64.0, width * 0.16 / 64.0) * strength
	holder.add_child(shadow)


## O plano do túnel: a parede escura, os trilhos e o vagão de lado, na escala da tela.
func _build_outside() -> void:
	_outside = Node2D.new()
	_outside.name = "Outside"
	_stage.add_child(_outside)
	var back := ColorRect.new()
	back.color = Color(0.015, 0.015, 0.018)
	back.size = FRAME
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outside.add_child(back)
	# A parede do túnel atrás do vagão: a mesma faixa das janelas, mais escura e parada.
	var wall := Sprite2D.new()
	wall.texture = load(_p.tunnel.file)
	wall.centered = false
	wall.region_enabled = true
	wall.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var wall_scale := 2.2
	wall.region_rect = Rect2(0, 0, FRAME.x / wall_scale, wall.texture.get_height())
	wall.scale = Vector2(wall_scale, wall_scale)
	wall.position = Vector2(0, TUNNEL_RAIL_Y - wall.texture.get_height() * wall_scale + 40.0)
	wall.modulate = Color(0.32, 0.34, 0.38)
	_outside.add_child(wall)
	var bed := ColorRect.new()
	bed.color = Color(0.07, 0.065, 0.06)
	bed.position = Vector2(0, TUNNEL_RAIL_Y)
	bed.size = Vector2(FRAME.x, FRAME.y - TUNNEL_RAIL_Y)
	bed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outside.add_child(bed)
	_car = AHTrainCar2D.new()
	_car.scale = Vector2(TUNNEL_SCALE, TUNNEL_SCALE)
	var car_size := _car.canvas() * TUNNEL_SCALE
	_car_home = (FRAME.x - car_size.x) * 0.5
	_car.position = Vector2(_car_home, TUNNEL_RAIL_Y - _car.rail_y() * TUNNEL_SCALE)
	_car.drive(_car_home)
	_outside.add_child(_car)
	var rail := ColorRect.new()
	rail.color = Color(0.36, 0.33, 0.3)
	rail.position = Vector2(0, TUNNEL_RAIL_Y - 4.0)
	rail.size = Vector2(FRAME.x, 9.0)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outside.add_child(rail)
