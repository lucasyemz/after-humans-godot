## A Estação viva (#207, a proposta de 28/10 aprovada pelo Lucas): os moradores falam e pensam em balões do kit e, de
## tempos em tempos, um deles sai do cômodo pela porta do fundo e aparece pela porta de outro.
## - As falas: um balão por vez na Estação inteira (uma conversa ocupa o lugar até acabar), de 14 a 28 s entre um e
##   outro; o texto, as condições e o sorteio ficam em AHStationChatter (data/station-chatter.json). Só na vista geral e
##   com um cômodo aberto (o HUD diz em life_allowed), e com "Falas na Estação" ligada nas Opções.
## - O balão interativo (decisão do Lucas, 28/10): a fala em destaque que se aperta e abre a tirinha (AHComicReader). O
##   Próximo passo leva até ele (play_story): a conversa sai na hora e o balão fica até ser apertado.
## - O andar: a cada 45 a 90 s, um herói que está passeando vai a outro cômodo: anda até a porta do fundo, a porta abre
##   (a folha gira no batente: a provisória até a arte dos dois quadros), ele entra no vão e some; o corredor e a escada
##   levam a distância pela velocidade, mais 2 s por andar; a porta do destino abre e ele sai. Um andando por vez. Quem
##   visita volta ao cômodo dele depois de 1 a 2 min. Ninguém atravessa parede: entre as duas portas ele não aparece.
## Nada disso vai para o save; o sorteio usa um gerador próprio.
class_name AHStationLife
extends Node

const S := preload("res://scripts/flow/station_rules.gd")
const C := preload("res://scripts/flow/station_chatter.gd")

## O intervalo entre uma troca de cômodo e a seguinte (s), sorteado.
const WALK_GAP := Vector2(45.0, 90.0)
## Quanto o visitante fica no cômodo de outro antes de voltar ao dele (s).
const VISIT := Vector2(60.0, 120.0)
## A porta: o tempo de abrir (s), o quanto a folha encolhe na largura (presa na dobradiça) e quanto fica aberta.
const DOOR_TIME := 0.35
const DOOR_LEAF := 0.15
const DOOR_HOLD := 0.5
## O corredor e a escada: o tempo a mais por andar (s).
const FLOOR_TIME := 2.0
## Onde quem entra some (m à frente da folha, no vão).
const DOOR_DEPTH := 0.35
## Folga da área livre da tela para o balão (px de 1080).
const AREA_MARGIN := 12.0

var station: AHStation
var rng := RandomNumberGenerator.new()
## Os testes desligam o sorteio sozinho (tick manual pelas funções públicas).
var auto := true
var layer: Control
var bubble: AHKitBubble
var history := {}
var last_speaker := ""
## A conversa em curso: {row, ids, name, index}; e quanto falta para a fala de agora acabar ou a próxima entrar.
var talk := {}
var _line_left := 0.0
var _talk_gap := 0.0
var _chat_left := 0.0
## A tirinha que o Próximo passo pediu (a conversa sai na hora e o balão fica até ser apertado).
var story := ""
var _story_wait := 0.0
## Quem conversa na tirinha fica parado até ela acabar.
var _held: Array = []
## A troca de cômodo em curso: {walker, id, from, to, phase, t, speed, x_from, x_to, lane_z, floor_to, z_door}.
var trip := {}
var _walk_left := 0.0
## Quem visita: {id: {home, left}}.
var visits := {}
## As portas abrindo e fechando: {room_id: {amount, target}}.
var _doors := {}

signal comic_requested(name: String)


func _init(owner_station: AHStation) -> void:
	station = owner_station
	name = "Life"
	rng.randomize()
	_chat_left = rng.randf_range(C.GAP.x, C.GAP.y)
	_walk_left = rng.randf_range(WALK_GAP.x, WALK_GAP.y)


func _process(delta: float) -> void:
	_tick_doors(delta)
	if station.hud == null or layer == null:
		return
	_tick_trip(delta)
	_tick_talk(delta)


# ---------------------------------------------------------------- quem está à vista

func chatter_on() -> bool:
	return bool(Campaign.state.get("settings", {}).get("station_chatter", true))


## {id: {room, say, think}} de quem pode falar ou pensar agora: à vista, num cômodo da grade (nada na plataforma), fora
## da Sala dos Personagens e de uma troca de cômodo. Quem dorme ou trabalha na pose só pensa; o caído nem pensa. Com um
## cômodo aberto, só quem está nele; e só quem tem a cabeça na área livre da tela.
func present() -> Dictionary:
	var out := {}
	var hud := station.hud
	var open_room: String = hud.current if hud != null and hud.current != "" else ""
	for walker in station.walkers():
		var id := String(walker.get("hero_id", walker.get("civilian", "")))
		var card: AHSpriteCard = walker.card
		if id == "" or not is_instance_valid(card) or not card.visible or id == station.stage_hero:
			continue
		if not trip.is_empty() and trip.id == id:
			continue
		var room := String(walker.get("room", ""))
		if room == "" or AHStation.room_def(room).get("place", "") != "grid":
			continue
		if open_room != "" and room != open_room:
			continue
		if not on_screen(card):
			continue
		var asleep: bool = walker.get("sleeping", false)
		if walker.get("recovering", false):
			continue
		var busy: bool = asleep or float(walker.get("working", 0.0)) > 0.0 or walker.get("civil_working", false)
		out[id] = {"room": room, "say": not busy, "think": true}
	return out


## A cabeça na tela (px da base de 1080), ou Vector2.INF atrás da câmera.
func head_point(card: AHSpriteCard) -> Vector2:
	var camera := station.camera
	var head := card.global_position + Vector3(0, card.head_height() + 0.08, 0)
	if camera == null or camera.is_position_behind(head):
		return Vector2.INF
	return camera.unproject_position(head)


func on_screen(card: AHSpriteCard) -> bool:
	var point := head_point(card)
	return point != Vector2.INF and station.hud.life_area().grow(-AREA_MARGIN).has_point(point)


# ---------------------------------------------------------------- as falas

func _tick_talk(delta: float) -> void:
	# A conversa da tirinha é um objetivo: sai mesmo com as falas desligadas nas Opções.
	var allowed: bool = station.hud.life_allowed() and (chatter_on() or story != "")
	if not allowed:
		# Uma tela por cima: a conversa acaba (a da tirinha também; o Próximo passo continua pedindo).
		if not talk.is_empty() or bubble != null:
			stop_talk()
		story = ""
		return
	if not talk.is_empty():
		_tick_line(delta)
		return
	if story != "":
		_story_wait -= delta
		if _story_wait <= 0.0:
			start_story_talk()
		return
	if not auto:
		return
	_chat_left -= delta
	if _chat_left <= 0.0:
		_chat_left = rng.randf_range(C.GAP.x, C.GAP.y)
		var chosen := C.pick(Campaign.state, present(), history, last_speaker, Time.get_ticks_msec(), rng)
		if not chosen.is_empty():
			start_talk(chosen)


## Começa a conversa (ou o pensamento) escolhida: {row, ids, name}.
func start_talk(chosen: Dictionary) -> void:
	_free_bubble()
	talk = chosen.duplicate()
	talk.index = 0
	history[String(chosen.row.Name)] = Time.get_ticks_msec()
	_show_line()


func _tick_line(delta: float) -> void:
	if bubble == null:
		_talk_gap -= delta
		if _talk_gap <= 0.0:
			_show_line()
		return
	var card := _speaker_card()
	# Quem fala saiu de vista (entrou numa tela, foi para a plataforma, a câmera foi para outro lado): a conversa acaba.
	if card == null or not card.visible or not on_screen(card):
		stop_talk()
		return
	bubble.place(head_point(card), station.hud.life_area())
	if bubble.is_story() and story != "":
		return
	_line_left -= delta
	if _line_left <= 0.0:
		_end_line()


func _speaker_card() -> AHSpriteCard:
	if talk.is_empty():
		return null
	var line: Dictionary = talk.row.Lines[talk.index]
	var id: String = talk.ids[int(line.get("Who", 0))]
	var card = station.residents.get(id)
	return card if is_instance_valid(card) else null


func _show_line() -> void:
	var line: Dictionary = talk.row.Lines[talk.index]
	var text := C.line_text(line, String(talk.get("name", "")))
	var comic := String(line.get("Comic", ""))
	var kind := AHKitBubble.STORY if comic != "" else String(talk.row.get("Kind", "say"))
	bubble = AHKitBubble.make(kind, text)
	bubble.set_meta("speaker", talk.ids[int(line.get("Who", 0))])
	if comic != "":
		bubble.opened.connect(_open_comic.bind(comic))
	layer.add_child(bubble)
	var card := _speaker_card()
	if card != null:
		bubble.place(head_point(card), station.hud.life_area())
	_line_left = C.STORY_LINE if comic != "" else C.line_seconds(text)
	if comic != "" and story != "":
		bubble.take_focus()
	last_speaker = String(talk.ids[int(line.get("Who", 0))])


func _end_line() -> void:
	_free_bubble()
	talk.index += 1
	if talk.index >= talk.row.Lines.size():
		talk = {}
		return
	_talk_gap = C.LINE_GAP


func stop_talk() -> void:
	_free_bubble()
	talk = {}
	# Acabada a conversa da tirinha (lida, desistida ou interrompida), os dois voltam a passear.
	for walker in _held:
		if is_instance_valid(walker.get("card")) and is_inf(float(walker.get("wait", 0.0))):
			walker.wait = rng.randf_range(1.0, 3.0)
	_held = []


func _free_bubble() -> void:
	if bubble != null and is_instance_valid(bubble):
		bubble.queue_free()
	bubble = null


## O balão interativo na tela agora (para o foco do teclado e o teste), ou null.
func story_bubble() -> AHKitBubble:
	return bubble if bubble != null and is_instance_valid(bubble) and bubble.is_story() else null


func _open_comic(comic: String) -> void:
	stop_talk()
	story = ""
	comic_requested.emit(comic)


## O Próximo passo pediu a tirinha: o Bento e o Nick ficam juntos no cômodo do Bento (quem estava longe vai para lá, quem
## trabalhava levanta), a vista geral mostra o cômodo e a conversa sai logo, com o balão parado até ser apertado.
func play_story(comic: String) -> bool:
	var row := C.chatter_for(comic)
	if row.is_empty():
		return false
	var ids: Array = row.Speakers.duplicate()
	var lead = _walker_of(String(ids[0]))
	if lead == null:
		return false
	abort_trip()
	var room := String(lead.room)
	if AHStation.room_def(room).get("place", "") != "grid":
		room = S.DORMITORY
	var walkers: Array = []
	for id in ids:
		var walker = _walker_of(String(id))
		if walker == null or walker.get("recovering", false):
			return false
		walkers.append(walker)
	for walker in walkers:
		station.settle_in(walker, room)
	# Lado a lado: quem responde fica perto de quem conta (dentro da faixa do cômodo).
	var lead_card: AHSpriteCard = walkers[0].card
	for index in range(1, walkers.size()):
		var other: Dictionary = walkers[index]
		var side := 1.2 * index if lead_card.position.x + 1.2 * index <= float(other.max) else -1.2 * index
		var x := clampf(lead_card.position.x + side, float(other.min), float(other.max))
		other.card.position.x = x
		other.target = x
		other.card.set_facing(-signf(side))
		walkers[0].card.set_facing(signf(side))
	# Os dois ficam parados, lado a lado, até a conversa acabar (não saem passeando no meio dela).
	stop_talk()
	for walker in walkers:
		walker.wait = INF
	_held = walkers
	story = comic
	_story_wait = 0.6
	station.hud.focus_story_room(room)
	return true


## A conversa da tirinha, com quem está no cômodo (os dois já foram juntados por play_story).
func start_story_talk() -> bool:
	var row := C.chatter_for(story)
	var ids := C.cast(row, present(), Campaign.state)
	if ids.is_empty():
		# A câmera ainda chegando (a cabeça fora da área livre): tenta de novo logo.
		_story_wait = 0.3
		return false
	start_talk({"row": row, "ids": ids, "name": ""})
	return true


## Voltar na conversa da tirinha: ela acaba, e o Próximo passo continua pedindo.
func cancel_story() -> void:
	story = ""
	stop_talk()


## O morador saiu da vida da Estação de repente (foi para o leito com ela aberta): a troca de cômodo dele para, e a
## conversa em que ele está (ou a da tirinha, que o segura) acaba; os outros voltam a passear.
func release(hero_id: String) -> void:
	if not trip.is_empty() and String(trip.walker.get("hero_id", "")) == hero_id:
		abort_trip()
	var walker = _walker_of(hero_id)
	var talking: bool = Array(talk.get("ids", [])).has(hero_id) or (walker != null and _held.has(walker))
	# A tirinha pendente sem conversa no ar (a câmera a interrompeu) também acaba: senão ficava esperando por ele.
	talking = talking or (story != "" and Array(C.chatter_for(story).get("Speakers", [])).has(hero_id))
	if talking:
		cancel_story()


func _walker_of(id: String):
	for walker in station.walkers():
		if String(walker.get("hero_id", "")) == id and is_instance_valid(walker.card):
			return walker
	return null


# ---------------------------------------------------------------- andar de um cômodo a outro

## Quem está entre as duas portas (não aparece em lugar nenhum).
func away_ids() -> Array:
	return [trip.id] if not trip.is_empty() and ["away", "opening_to"].has(trip.phase) else []


## Quem pode sair andando: um herói passeando num cômodo da grade (fora da Sala, do posto com a pose, da plataforma, da
## cama, da recuperação e do banco) e que não é o vigia da noite.
func can_walk(walker: Dictionary) -> bool:
	if not walker.has("hero_id") or not is_instance_valid(walker.card) or not walker.card.visible:
		return false
	if walker.hero_id == station.stage_hero or walker.get("sleeping", false) or walker.get("recovering", false):
		return false
	if float(walker.get("working", 0.0)) > 0.0 or float(walker.get("sitting", 0.0)) > 0.0 or int(walker.get("seat", -1)) >= 0:
		return false
	if walker.get("vanish", false) or walker.get("stay", false):
		return false
	var c: Dictionary = Campaign.state
	if c.night.phase != "none" and String(c.night.get("watch_hero_id", "")) == walker.hero_id:
		return false
	return AHStation.room_def(String(walker.room)).get("place", "") == "grid"


## Os cômodos da grade com porta para onde se pode ir, com o peso do estado: com fome, a Cantina; à noite, o Dormitório;
## com alguém caído, a Enfermaria (visita); fora disso, qualquer um recuperado.
func destinations(from: String) -> Dictionary:
	var c: Dictionary = Campaign.state
	var out := {}
	var conditions := C.conditions(c)
	for room in AHStation.rooms():
		if room.place != "grid" or room.id == from or S.room_level(c, room.id) < 1 or room.id == S.CHARACTERS and station.stage_hero != "":
			continue
		var weight := 1.0
		if conditions.get("food_low", false) and room.id == S.CANTEEN:
			weight = 4.0
		if conditions.get("night", false) and room.id == S.DORMITORY:
			weight = 4.0
		if conditions.get("fallen", false) and room.id == S.INFIRMARY:
			weight = 3.0
		if _occupants(room.id) >= 2:
			continue
		out[room.id] = weight
	return out


func _occupants(room_id: String) -> int:
	var count := 0
	for walker in station.walkers():
		if walker.has("hero_id") and String(walker.get("room", "")) == room_id and not walker.get("recovering", false):
			count += 1
	return count


func _tick_trip(delta: float) -> void:
	if not trip.is_empty():
		_step_trip(delta)
		return
	# O tempo da visita corre com qualquer tela: ninguém fica fora do cômodo dele por muito mais que 2 min.
	for id in visits.keys():
		visits[id].left -= delta
	if not auto or not station.hud.life_allowed() or story != "":
		return
	# Primeiro quem visita há tempo demais volta para casa, na hora; senão, um sorteado vai a outro cômodo.
	for id in visits.keys():
		if visits[id].left <= 0.0:
			var walker = _walker_of(id)
			if walker != null and can_walk(walker) and start_trip(walker, visits[id].home):
				return
	_walk_left -= delta
	if _walk_left > 0.0:
		return
	_walk_left = rng.randf_range(WALK_GAP.x, WALK_GAP.y)
	var movers: Array = station.walkers().filter(func(w): return can_walk(w))
	if movers.is_empty():
		return
	var walker: Dictionary = movers[rng.randi_range(0, movers.size() - 1)]
	var options := destinations(String(walker.room))
	if options.is_empty():
		return
	var total := 0.0
	for weight in options.values():
		total += weight
	var roll := rng.randf() * total
	for room_id in options:
		roll -= options[room_id]
		if roll <= 0.0:
			start_trip(walker, room_id)
			return


## Porta do cômodo: o x do meio do vão (m) e a profundidade de quem some ali.
static func door_spot(room_id: String) -> Vector3:
	var placed := AHStationLayout.room(Campaign.state, room_id)
	if placed.is_empty() or placed.place != "grid" or is_nan(float(placed.door)):
		return Vector3.INF
	return Vector3((placed.door + 60.0) * 0.01, placed.floor * 0.01, (AHStationBuild.ROOM_BACK + 3.0) * 0.01 + DOOR_DEPTH)


## Sai do cômodo dele para to (o x do vão das duas portas, o andar e a velocidade de quem está ferido).
func start_trip(walker: Dictionary, to: String) -> bool:
	if not trip.is_empty() or not can_walk(walker) or to == String(walker.room):
		return false
	var from_door := door_spot(String(walker.room))
	var to_door := door_spot(to)
	if from_door == Vector3.INF or to_door == Vector3.INF:
		return false
	var hero = S.hero(Campaign.state, walker.hero_id)
	var speed: float = AHStation.WALK_SPEED * AHWounded.speed_factor(hero)
	var floors: int = absi(int(AHStationLayout.room(Campaign.state, walker.room).floor_number) - int(AHStationLayout.room(Campaign.state, to).floor_number))
	trip = {"walker": walker, "id": String(walker.hero_id), "from": String(walker.room), "to": to, "phase": "to_door", "t": 0.0,
		"speed": speed, "door_from": from_door, "door_to": to_door,
		"travel": absf(to_door.x - from_door.x) / speed + FLOOR_TIME * floors}
	walker.life = true
	walker.card.scale = Vector3.ONE
	return true


func _step_trip(delta: float) -> void:
	var walker: Dictionary = trip.walker
	var card: AHSpriteCard = walker.card
	if not is_instance_valid(card):
		trip = {}
		return
	trip.t += delta
	var time := Time.get_ticks_msec() * 0.001
	match trip.phase:
		"to_door":
			# Até o vão, na faixa: anda de lado e depois para o fundo, com o balanço do passo.
			var door: Vector3 = trip.door_from
			if not _walk_to(card, Vector3(door.x, card.position.y, card.position.z), trip.speed, delta, time, walker):
				return
			set_door(trip.from, true)
			trip.phase = "opening"
			trip.t = 0.0
		"opening":
			if trip.t < DOOR_TIME:
				return
			trip.phase = "in"
		"in":
			var door: Vector3 = trip.door_from
			if not _walk_to(card, door, trip.speed, delta, time, walker):
				return
			trip.phase = "away"
			trip.t = 0.0
			station.hide_residents(station.residents_hidden())
			set_door(trip.from, false, DOOR_HOLD)
		"away":
			if trip.t < trip.travel:
				return
			var door: Vector3 = trip.door_to
			card.position = door
			card.scale = Vector3.ONE
			set_door(trip.to, true)
			trip.phase = "opening_to"
			trip.t = 0.0
		"opening_to":
			if trip.t < DOOR_TIME:
				return
			trip.phase = "out"
			station.settle_in(walker, trip.to, false)
			card.position = trip.door_to
			station.hide_residents(station.residents_hidden())
		"out":
			if not _walk_to(card, Vector3(card.position.x, card.position.y, float(walker.home_z)), trip.speed, delta, time, walker):
				return
			set_door(trip.to, false, DOOR_HOLD)
			_arrive()


## Anda o cartão até o ponto (m), na velocidade, virado para onde anda no x; true ao chegar.
func _walk_to(card: AHSpriteCard, goal: Vector3, speed: float, delta: float, time: float, walker: Dictionary) -> bool:
	var gap := goal - card.position
	if gap.length() < 0.03:
		card.position = goal
		card.scale = Vector3.ONE
		return true
	if absf(gap.x) > 0.02:
		card.set_facing(signf(gap.x))
	card.position += gap.normalized() * minf(gap.length(), speed * delta)
	card.scale = Vector3(1, 1.0 + 0.025 * absf(sin(time * 7.0 + float(walker.get("phase", 0.0)))), 1)
	return false


func _arrive() -> void:
	var walker: Dictionary = trip.walker
	var id: String = trip.id
	var home: String = visits[id].home if visits.has(id) else trip.from
	if trip.to == home:
		visits.erase(id)
	else:
		visits[id] = {"home": home, "left": rng.randf_range(VISIT.x, VISIT.y)}
	walker.erase("life")
	walker.wait = rng.randf_range(0.5, 2.0)
	trip = {}


## A troca de cômodo para no meio (a equipe chegou, os moradores foram refeitos): quem andava volta na hora ao cômodo
## de onde saiu, e as portas fecham.
func abort_trip() -> void:
	if trip.is_empty():
		return
	var walker: Dictionary = trip.walker
	var from: String = trip.from
	trip = {}
	if is_instance_valid(walker.get("card")):
		walker.erase("life")
		station.settle_in(walker, from)
	for room_id in _doors:
		_doors[room_id].target = 0.0
		_doors[room_id].amount = 0.0
		_apply_door(room_id, 0.0)
	station.hide_residents(station.residents_hidden())


## Os moradores foram refeitos (station._place_residents): nada da troca nem da visita fica.
func reset() -> void:
	trip = {}
	visits.clear()
	stop_talk()
	for room_id in _doors:
		_doors[room_id].target = 0.0
		_doors[room_id].amount = 0.0
		_apply_door(room_id, 0.0)


# ---------------------------------------------------------------- as portas

## Abre (ou fecha, depois de hold s) a porta do fundo do cômodo.
func set_door(room_id: String, open: bool, hold: float = 0.0) -> void:
	if not _doors.has(room_id):
		_doors[room_id] = {"amount": 0.0, "target": 0.0, "hold": 0.0}
	_doors[room_id].target = 1.0 if open else 0.0
	_doors[room_id].hold = hold


func door_amount(room_id: String) -> float:
	return float(_doors.get(room_id, {}).get("amount", 0.0))


func _tick_doors(delta: float) -> void:
	for room_id in _doors:
		var door: Dictionary = _doors[room_id]
		if door.hold > 0.0:
			door.hold -= delta
			continue
		var before: float = door.amount
		door.amount = move_toward(door.amount, door.target, delta / DOOR_TIME)
		if door.amount != before:
			_apply_door(room_id, door.amount)


## A folha gira no batente (a provisória): encolhe na largura presa na dobradiça da esquerda, e o vão escuro aparece.
func _apply_door(room_id: String, amount: float) -> void:
	var parts: Dictionary = station.door_parts(room_id)
	if parts.is_empty() or not is_instance_valid(parts.leaf):
		return
	var leaf: MeshInstance3D = parts.leaf
	var eased := smoothstep(0.0, 1.0, amount)
	var width: float = lerpf(1.0, DOOR_LEAF, eased)
	leaf.scale.x = width
	leaf.position.x = float(parts.hinge) + float(parts.width) * width * 0.5
	if is_instance_valid(parts.get("gap")):
		parts.gap.visible = amount > 0.01
