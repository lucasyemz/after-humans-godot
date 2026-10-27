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
const FOCUS_HEIGHT := 0.75
## A meia largura da fileira com a folga dos corpos (m): a câmera recua até ela caber (a lente fechada dos cenários).
const ROW_HALF_WIDTH := 4.6
## O intervalo mínimo entre duas trocas de herói (s), com ou sem o fade: um toque no analógico troca um só.
const SWITCH_GAP := 0.2
## Ao levantar, o líder fica esta distância à direita da fogueira (m), para a fila de quatro (1,15 m entre um e outro)
## ficar toda à direita do fogo; numa sala estreita, até a parede.
const LEAVE_OFFSET := 4.3
## A pose de cuidar (a de usar item da luta, reactions.item) depois de comer ou curar, antes de voltar a sentar (s).
const CARE_POSE_SECONDS := 1.2

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


func focus_point() -> Vector3:
	return Vector3(focus_x, (_room.floor_y if _room != null else 0.0) + FOCUS_HEIGHT, (_room.camp_z if _room != null else 0.0) - 0.2)


## Entra no acampamento: a equipe vai para os lugares em volta da fogueira (com fade, a não ser instant: o jogo
## reaberto no meio do acampamento já abre nele).
func begin(room: Node3D, team: Array, instant: bool = false) -> void:
	if active or room == null:
		return
	_room = room
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
		card.visible = true
		members.append({"hero_id": hero_id, "card": card, "slot": slot, "pose": pose.get("kind", "stand")})
	# Na ordem da cena, da esquerda para a direita: as setas e as cartas andam como se vê.
	members.sort_custom(func(a, b): return a.card.position.x < b.card.position.x)


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
	await get_tree().create_timer(CARE_POSE_SECONDS).timeout
	# Levantou acampamento no meio: a arte de antes já voltou (end); senão, a de descanso.
	if active and is_instance_valid(card) and card.art() == item:
		card.show_art(rest)

