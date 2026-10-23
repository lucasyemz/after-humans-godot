## Quem fica escondido e o que esconde (#51, o AHOcclusion da Unreal). Os personagens acompanhados ganham a silhueta
## (AHSpriteCard.set_silhouette: a parte atrás de qualquer coisa aparece em preenchimento fraco e contorno); os objetos
## registrados que ficam entre a câmera e um deles esmaecem e voltam aos poucos quando saem da frente.
## O teste é pela caixa de cada objeto (fixa, medida ao registrar) contra os segmentos da câmera até três pontos do
## corpo (pé, meio e cabeça); só os objetos na faixa de X entre a câmera e os personagens são testados a cada quadro.
class_name AHOcclusion
extends Node

## Transparência do objeto que tapa alguém (0 = inteiro, 1 = some).
const FADED := 0.6
## Quanto a transparência anda por segundo (vai e volta em ~0,15 s); com "Reduzir efeitos", troca na hora.
const FADE_SPEED := 4.0
## Os pontos do corpo testados, em fração da altura.
const BODY_POINTS := [0.15, 0.5, 0.9]
## Objetos maiores que isto (m) não entram: o chão, as fachadas inteiras, o céu e os blocos juntados.
const MAX_WIDTH := 14.0
const MIN_HEIGHT := 0.3
## Cor da silhueta da equipe (creme discreto); a dos inimigos é a de perigo da interface (muda com o daltonismo).
const PARTY_COLOR := Color(0.95, 0.86, 0.62)

var _occluders: Array = []
var _fade := {}
var _cards: Array = []
var _enemy_cards: Array = []


## Registra um objeto que pode tapar alguém (a caixa é medida agora, no mundo).
func add_occluder(node: GeometryInstance3D) -> void:
	# Fora: personagens, partículas, blocos juntados e as caixas de depuração das colisões (tecla C).
	# e as peças que o cenário acabou de juntar numa malha (estão para sair da árvore).
	if node is AHSpriteCard or node is GPUParticles3D or node is CPUParticles3D or node.has_meta("merged") \
			or node.get_parent() is CollisionObject3D or node.is_queued_for_deletion():
		return
	var box: AABB = node.global_transform * node.get_aabb()
	if box.size.x > MAX_WIDTH or box.size.y < MIN_HEIGHT:
		return
	var entry := {"node": node, "box": box, "x": box.position.x}
	# Em ordem pelo começo em X: cada quadro só percorre a faixa entre a câmera e os personagens.
	_occluders.insert(_occluders.bsearch_custom(entry, func(a, b): return a.x < b.x), entry)


## Registra todo objeto visível de root (e dos filhos), menos os grandes e os personagens.
func scan(root: Node) -> void:
	for child in root.get_children():
		if child is AHSpriteCard:
			continue
		# Os escondidos também (o mobiliário que liga e desliga): esmaecer um invisível não custa nada.
		if child is GeometryInstance3D:
			add_occluder(child)
		scan(child)


func forget(root: Node) -> void:
	_occluders = _occluders.filter(func(o): return is_instance_valid(o.node) and o.node != root and not root.is_ancestor_of(o.node))


## A equipe: silhueta sempre.
func track(card: AHSpriteCard) -> void:
	if not _cards.has(card):
		_cards.append(card)
	card.set_silhouette(PARTY_COLOR)


## Os inimigos: silhueta só enquanto a luta dura (untrack ao fim).
func track_enemy(card: AHSpriteCard) -> void:
	if not _enemy_cards.has(card):
		_enemy_cards.append(card)
	card.set_silhouette(AHUiStyle.DANGER)


func untrack(card) -> void:
	_cards.erase(card)
	_enemy_cards.erase(card)
	if is_instance_valid(card):
		card.set_silhouette(null)


## Os objetos esmaecidos agora (para os testes e a captura).
func faded() -> Array:
	return _fade.keys().filter(func(n): return is_instance_valid(n) and _fade[n] > 0.0)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var eye := camera.global_position
	_cards = _cards.filter(func(c): return is_instance_valid(c))
	_enemy_cards = _enemy_cards.filter(func(c): return is_instance_valid(c))
	var points: Array[Vector3] = []
	var low := eye.x
	var high := eye.x
	for list in [_cards, _enemy_cards]:
		for card in list:
			if not is_instance_valid(card) or not card.is_visible_in_tree():
				continue
			for f in BODY_POINTS:
				var p: Vector3 = card.global_position + Vector3(0, card.body_height * f, 0)
				points.append(p)
				low = minf(low, p.x)
				high = maxf(high, p.x)
	var hit := {}
	if not points.is_empty():
		var first := _occluders.bsearch_custom({"x": low - MAX_WIDTH}, func(a, b): return a.x < b.x)
		for index in range(first, _occluders.size()):
			var o: Dictionary = _occluders[index]
			var box: AABB = o.box
			if box.position.x > high:
				break
			if box.end.x < low or not is_instance_valid(o.node):
				continue
			for p in points:
				if not box.has_point(p) and box.intersects_segment(eye, p):
					hit[o.node] = true
					break
	var step := 1.0 if _reduced() else FADE_SPEED * delta
	for node in hit:
		if not _fade.has(node):
			_fade[node] = 0.0
	for node in _fade.keys():
		if not is_instance_valid(node):
			_fade.erase(node)
			continue
		var value: float = move_toward(_fade[node], FADED if hit.has(node) else 0.0, step)
		node.transparency = value
		if value <= 0.0 and not hit.has(node):
			_fade.erase(node)
		else:
			_fade[node] = value


func _reduced() -> bool:
	return bool(Campaign.state.get("settings", {}).get("reduced_environment_effects", false))
