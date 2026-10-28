## O acampamento encenado (#77; na estrutura da Unreal na #109, docs/design/hud-ajustes.md): a equipe numa fileira de
## lado, com a fogueira no meio, sentada no chão (os fundadores com as poses da #82, os recrutas com as da #80) ou
## deitada (quem chegou com até um quarto da vida), e a câmera parada na fogueira. Um
## fade leva a equipe às posições e outro a devolve à fila; passar de um herói para outro é um fade curto (como na
## Unreal). As regras de comer e curar não mudam (AHJourneyRules.camp_use_food / camp_use_bandage): aqui é só a cena.
class_name AHCampScene
extends Node

const POSES := "res://data/presentation/camp_poses.json"
## Os lugares, numa fileira a partir da fogueira (m), todos na mesma linha do chão, como a luta: a ordem da cena é a da
## formação de trás para a frente (Véspera, Íris | fogo | Nick, Bento). Os da direita olham para a esquerda, para o fogo.
const SLOTS := [Vector3(-3.3, 0, 0.2), Vector3(-1.55, 0, 0.2), Vector3(1.55, 0, 0.2), Vector3(3.3, 0, 0.2)]
## Com menos gente, os lugares de dentro primeiro (a formação da posição 1 fica sempre à direita do fogo).
const SLOT_ORDER := {1: [2], 2: [2, 1], 3: [2, 1, 0], 4: [3, 2, 1, 0]}
## Deita quem está com até esta fração da vida.
const LIE_DOWN_AT := 0.25
## Deitado, o corpo é mais largo que sentado: nos lugares da ponta, ele chega este tanto para dentro (m), para não sair do
## quadro da câmera parada na fogueira.
const LIE_INSET := 0.45
## O fade entre um herói e outro (s, cada metade) e o de entrar e sair do acampamento.
const SWITCH_FADE := 0.12
## A câmera: parada na fogueira (ninguém sai do quadro); o escolhido se marca pela luz da escolha e pela carta. A
## distância e a altura do alvo (m).
const FOCUS_PULL := 0.0
const FOCUS_DISTANCE := 10.5
const FOCUS_HEIGHT := 0.35
## A altura do alvo com a câmera quase reta (FLAT_PITCH, a de antes da #205): o alvo sobe enquanto o ângulo desce, para
## a fileira ficar na mesma linha da tela, acima do painel, em qualquer ângulo (focus_height).
const FLAT_FOCUS_HEIGHT := 0.75
const FLAT_PITCH := 4.0
## O ângulo da câmera do acampamento (graus, para baixo), o da arte das poses (#205): a arte é vista de cima, e o apoio
## do corpo (o quadril do sentado, o tronco do deitado: "support" de camp_poses.json) fica acima do pé. Numa carta de
## pé no chão, esse apoio cai no chão logo atrás do pé, embaixo do corpo, só se a câmera olhar do mesmo ângulo; com a
## câmera quase reta (4°), ele caía a mais de 1 m, e o corpo parecia voar.
const FOCUS_PITCH := 15.0
## Até onde atrás do pé o apoio pode cair no chão (m): a fundura de um corpo sentado ou deitado de lado.
const MAX_SUPPORT_DEPTH := 0.6
## Na parada de descanso de um cenário com água, a câmera de 15° mostrava o lago no lugar do fundo pintado (o Cais) e,
## com a fogueira no chão alagado (o Depósito), a água como uma placa lisa: com água no cenário, ela olha de
## WATER_STOP_PITCH; com a fogueira dentro d'água, do ângulo de antes (FLOODED_STOP_PITCH). A sombra acompanha o ângulo,
## até CONTACT_MAX_BACK atrás do pé.
const WATER_STOP_PITCH := 8.0
const FLOODED_STOP_PITCH := 4.0
## A meia largura da fileira com a folga dos corpos (m): a câmera recua até ela caber (a lente fechada dos cenários).
const ROW_HALF_WIDTH := 4.6
## O intervalo mínimo entre duas trocas de herói (s), com ou sem o fade: um toque no analógico troca um só.
const SWITCH_GAP := 0.2
## Ao levantar, o líder fica esta distância à direita da fogueira (m), para a fila de quatro (1,15 m entre um e outro)
## ficar toda à direita do fogo; numa sala estreita, até a parede.
const LEAVE_OFFSET := 4.3
## A pose de cuidar (a de usar item da luta, reactions.item) depois de comer ou curar, antes de voltar a sentar (s).
const CARE_POSE_SECONDS := 1.2
## A sombra de contato (#205): o chão embaixo do corpo, do pé até o apoio (a fogueira e a luz da sala não fazem sombra
## ali). Uma mancha escura e macia, na largura do corpo visível da pose: a fração dessa largura, quanto passa à frente do
## pé e atrás do apoio (m), quanto escurece no centro e a largura de quem fica de pé (sem pose de acampamento).
const CONTACT_WIDTH := 0.9
const CONTACT_FRONT := 0.12
const CONTACT_PAST := 0.15
const CONTACT_MAX_BACK := 1.2
const CONTACT_DARKNESS := 0.8
const CONTACT_STANDING_WIDTH := 0.8
## O nome do nó da sombra, filho da carta.
const CONTACT_NAME := "CampContact"

signal selected_changed(index: int)

var active := false
## Quem está no acampamento, na ordem da equipe: {hero_id, card, slot, pose}.
var members: Array = []
var selected := 0
var focus_x := 0.0
var _street
## O lugar da fogueira: a casa do acampamento (AHHouseRoom) ou a parada de descanso (AHStreetCamp, #143).
var _room: Node3D
var _poses := {}
## O que cada carta mostrava antes (a arte, a posição e o lado), para devolver ao levantar.
var _before := {}
var _switching := false
var _last_switch := -1000.0
## O ângulo da câmera deste acampamento (pitch), escolhido ao montar.
var _pitch := FOCUS_PITCH
static var _contact_material: StandardMaterial3D


func _init(street = null) -> void:
	_street = street
	name = "Camp"


func _ready() -> void:
	if FileAccess.file_exists(POSES):
		_poses = JSON.parse_string(FileAccess.get_file_as_string(POSES))


## A pose de descanso de um herói: a do fundador (chao ou deitado) pelo id; a do recruta pela variação de arte; sem
## nenhuma, {} (fica de pé com o idle).
func pose_for(hero: Dictionary) -> Dictionary:
	var lie: bool = int(hero.get("hp", 0)) <= int(hero.get("max_hp", 1)) * LIE_DOWN_AT
	var kind := "sleep" if lie else "seat"
	var by_hero: Dictionary = _poses.get("heroes", {}).get(String(hero.id), {})
	if not by_hero.is_empty():
		return {"kind": kind, "art": by_hero.get(kind, by_hero.get("seat", {}))}
	var variant := String(hero.get("art_variant", ""))
	var by_variant: Dictionary = _poses.get("recruits", {}).get(variant, {})
	if not by_variant.is_empty():
		return {"kind": kind, "art": by_variant.get(kind, by_variant.get("seat", {}))}
	return {}


## A altura e a linha do foco da câmera (o piso e a fogueira do lugar).
## A fogueira é a da parada de descanso (#143, AHStreetCamp), e não a da casa do acampamento.
func at_stop() -> bool:
	return _room is AHStreetCamp


## A altura do alvo da câmera para este ângulo (m acima do chão): FOCUS_HEIGHT no ângulo da arte, FLAT_FOCUS_HEIGHT no
## de antes, e entre os dois no meio.
static func focus_height(degrees: float) -> float:
	return lerpf(FLAT_FOCUS_HEIGHT, FOCUS_HEIGHT, clampf((degrees - FLAT_PITCH) / (FOCUS_PITCH - FLAT_PITCH), 0.0, 1.0))


## O ângulo da câmera do acampamento (graus): o da arte, ou o menor na parada de um cenário com água. Calculado uma vez
## ao montar o acampamento (_pick_pitch), e não a cada quadro da câmera.
func pitch() -> float:
	return _pitch


func _pick_pitch() -> float:
	var scenario = _street.scenario if _street != null and "scenario" in _street else null
	if not at_stop() or scenario == null:
		return FOCUS_PITCH
	return stop_pitch(scenario, Vector3(_room.camp_x, _room.floor_y, _room.camp_z + 0.35))


## O ângulo na parada de descanso de um cenário, com a fogueira em fire: o de antes no chão alagado, o menor com água
## pintada no cenário e o da arte no seco.
static func stop_pitch(scenario: AHScenarioWorld, fire: Vector3) -> float:
	if scenario.water_floor(fire):
		return FLOODED_STOP_PITCH
	return WATER_STOP_PITCH if scenario.has_water() else FOCUS_PITCH


func focus_point() -> Vector3:
	return Vector3(focus_x, (_room.floor_y if _room != null else 0.0) + focus_height(pitch()), (_room.camp_z if _room != null else 0.0) - 0.2)


## Entra no acampamento: a equipe vai para os lugares em volta da fogueira (com fade, a não ser instant: o jogo
## reaberto no meio do acampamento já abre nele).
func begin(room: Node3D, team: Array, instant: bool = false) -> void:
	if active or room == null:
		return
	_room = room
	_pitch = _pick_pitch()
	if not instant:
		await GameFlow.fade(1.0)
	_arrange(team)
	active = true
	# Começa no primeiro da formação (o da direita do fogo).
	var leader: int = members.map(func(m): return m.hero_id).find(team[0] if not team.is_empty() else "")
	select(maxi(0, leader), false)
	if not instant:
		await GameFlow.fade(0.0)


## Levanta acampamento: fade, cada um de volta à arte e ao lugar de antes, e a fila volta a seguir o líder.
func end(instant: bool = false) -> void:
	if not active:
		return
	if not instant:
		await GameFlow.fade(1.0)
	for member in members:
		var card: AHSpriteCard = member.card
		if not is_instance_valid(card):
			continue
		card.set_highlight(Color.BLACK, 0.0)
		var contact := card.get_node_or_null(CONTACT_NAME)
		if contact != null:
			contact.free()
		var before: Dictionary = _before.get(member.hero_id, {})
		if before.has("art"):
			card.show_art(before.art)
			card.set_facing(before.facing)
	members.clear()
	_before.clear()
	active = false
	if _street != null and _room != null:
		# A fila recomeça à direita da fogueira, virada para a porta de saída, sem ninguém em cima do fogo.
		# Na parada de descanso (#143), o ponto de levantar vem dela: dentro do trecho, antes da próxima patrulha.
		var leave_x: float = float(_room.leave_x) if "leave_x" in _room else minf(_room.camp_x + LEAVE_OFFSET, _street.walk_max.x)
		_street._place_leader(Vector3(leave_x, _room.floor_y, _room.leave_z), 1.0)
	if not instant:
		await GameFlow.fade(0.0)


func _arrange(team: Array) -> void:
	members.clear()
	_before.clear()
	var cards: Array = _street._heroes if _street != null else []
	var ids: Array = _street.party_ids if _street != null else team
	var alive: Array = []
	for index in mini(ids.size(), cards.size()):
		var hero = Campaign.hero(ids[index])
		if hero != null and hero.alive and team.has(ids[index]):
			alive.append([ids[index], cards[index], hero])
	var order: Array = SLOT_ORDER.get(alive.size(), [0, 1, 2, 3])
	for i in alive.size():
		var hero_id: String = alive[i][0]
		var card: AHSpriteCard = alive[i][1]
		var hero: Dictionary = alive[i][2]
		_before[hero_id] = {"art": card.art(), "facing": card.facing}
		var slot: int = order[i]
		var offset: Vector3 = SLOTS[slot]
		var pose := pose_for(hero)
		if not pose.is_empty() and not pose.art.is_empty():
			card.show_art(pose.art)
		card.scale = Vector3.ONE
		var inset: float = LIE_INSET * signf(offset.x) if pose.get("kind", "") == "sleep" and (slot == 0 or slot == SLOTS.size() - 1) else 0.0
		card.position = Vector3(_room.camp_x + offset.x - inset, _room.floor_y, _room.camp_z + offset.z + 0.35)
		card.set_facing(-1.0 if offset.x > 0.0 else 1.0)
		_contact(card, pose.get("art", {}))
		card.visible = true
		members.append({"hero_id": hero_id, "card": card, "slot": slot, "pose": pose.get("kind", "stand")})
	# Na ordem da cena, da esquerda para a direita: as setas e as cartas andam como se vê.
	members.sort_custom(func(a, b): return a.card.position.x < b.card.position.x)


## A sombra de contato embaixo da carta (#205), no chão: sob o corpo visível da pose ("visible" de camp_poses.json, em
## pixels da arte original) ou, de pé, sob o pé.
func _contact(card: AHSpriteCard, art: Dictionary) -> void:
	var shadow := card.get_node_or_null(CONTACT_NAME) as MeshInstance3D
	if shadow == null:
		shadow = MeshInstance3D.new()
		shadow.name = CONTACT_NAME
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shadow.material_override = _contact_shadow_material()
		card.add_child(shadow)
	var width := CONTACT_STANDING_WIDTH
	var center := 0.0
	if art.has("visible") and art.has("anchor") and art.has("body_reference_pixels"):
		var px_to_m: float = card.body_height / float(art.body_reference_pixels)
		var visible: Array = art.visible
		width = (float(visible[2]) - float(visible[0])) * px_to_m * CONTACT_WIDTH
		center = ((float(visible[0]) + float(visible[2])) * 0.5 - float(art.anchor[0])) * px_to_m * card.facing
	var back := minf(support_depth(art, card.body_height, pitch()) + CONTACT_PAST, CONTACT_MAX_BACK)
	var plane := PlaneMesh.new()
	plane.size = Vector2(width, CONTACT_FRONT + back)
	shadow.mesh = plane
	# Do pé (um pouco à frente) até atrás do apoio: a câmera está do lado de +z.
	shadow.position = Vector3(center, 0.015, (CONTACT_FRONT - back) * 0.5)


## Quanto atrás do pé o apoio do corpo cai no chão, na câmera do acampamento (m): a altura do apoio sobre o pé
## ("support" de camp_poses.json, em pixels da arte) dividida pela inclinação da câmera. Sem apoio (de pé), zero.
static func support_depth(art: Dictionary, body_height: float = 1.8, degrees: float = FOCUS_PITCH) -> float:
	if not art.has("support") or not art.has("anchor") or not art.has("body_reference_pixels"):
		return 0.0
	var lift: float = (float(art.anchor[1]) - float(art.support)) * body_height / float(art.body_reference_pixels)
	return maxf(0.0, lift) / tan(deg_to_rad(degrees))


static func _contact_shadow_material() -> StandardMaterial3D:
	if _contact_material != null:
		return _contact_material
	# Escura até o meio do raio e macia na borda: lê como o corpo apoiado, sem um contorno duro.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(0, 0, 0, CONTACT_DARKNESS), Color(0, 0, 0, CONTACT_DARKNESS * 0.7), Color(0, 0, 0, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	_contact_material = StandardMaterial3D.new()
	_contact_material.albedo_texture = texture
	_contact_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_contact_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_contact_material.render_priority = -1
	return _contact_material


## Escolhe o herói (o índice em members). fade: o fade curto entre as posições (sem Reduzir efeitos, que corta direto).
func select(index: int, fade: bool = true) -> void:
	if members.is_empty() or _switching:
		return
	index = posmod(index, members.size())
	if index == selected and active and fade:
		return
	var with_fade: bool = fade and not GameFlow.reduced_effects()
	if with_fade:
		_switching = true
		await GameFlow.fade(1.0, SWITCH_FADE)
	selected = index
	# O escolhido com a luz da escolha (a mesma do alvo na luta, #57); os outros sem ela.
	for i in members.size():
		if is_instance_valid(members[i].card):
			members[i].card.set_highlight(AHUiStyle.GOLD, 0.2 if i == selected else 0.0)
	var card: AHSpriteCard = members[selected].card
	var center: float = _room.camp_x if _room != null else 0.0
	focus_x = lerpf(center, card.position.x, FOCUS_PULL) if is_instance_valid(card) else center
	if _street != null:
		_street._update_camera(0.0)
	selected_changed.emit(selected)
	if with_fade:
		await GameFlow.fade(0.0, SWITCH_FADE)
		_switching = false


func step(direction: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _switching or now - _last_switch < SWITCH_GAP:
		return
	_last_switch = now
	select(selected + direction)


func selected_id() -> String:
	return members[selected].hero_id if active and not members.is_empty() else ""


func member_card(hero_id: String) -> AHSpriteCard:
	for member in members:
		if member.hero_id == hero_id:
			return member.card
	return null


func switching() -> bool:
	return _switching


## Comer ou curar (#143): o herói mostra a pose de usar item (a mesma da luta) e volta à de descanso. Sem a pose (os
## recrutas), fica como está.
func show_care_pose(hero_id: String) -> void:
	var card := member_card(hero_id)
	var hero = Campaign.hero(hero_id)
	if card == null or hero == null:
		return
	var item: Dictionary = AHCombatArena.hero_art_of(hero_id, String(hero.get("art_variant", ""))).get("reactions", {}).get("item", {})
	if item.is_empty():
		return
	var rest := card.art()
	card.show_art(item)
	_contact(card, item)
	await get_tree().create_timer(CARE_POSE_SECONDS).timeout
	# Levantou acampamento no meio: a arte de antes já voltou (end); senão, a de descanso.
	if active and is_instance_valid(card) and card.art() == item:
		card.show_art(rest)
		_contact(card, rest)

