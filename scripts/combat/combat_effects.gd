## Os efeitos de impacto e de estados da luta (#84, arte da #41): no alvo, o acerto (faíscas no robô, poeira nos
## outros), o crítico, a cura, o bloqueio e a esquiva tocam uma vez (0,5 s a 12 fps); os estados (sangramento, veneno,
## atordoado e marcado) ficam em loop enquanto duram. As medidas vêm de data/presentation/combat_effects.json
## (docs/design/combat-effects.md): o tamanho em pixels da tela de 1080, convertido pela distância da câmera, e a
## altura de cada um no corpo (o tronco, os pés, ao lado ou acima da cabeça). Com "Reduzir efeitos", os loops não
## aparecem (o estado fica no ícone e no texto do HUD) e cada acerto mostra só um quadro curto parado. As cores não
## mudam no modo daltonismo: a forma de cada efeito é quem diz o que ele é, e o HUD tem o nome do estado.
class_name AHCombatEffects
extends RefCounted

const MANIFEST := "res://data/presentation/combat_effects.json"
## O tamanho na tela de 1080 (px) do quadro de 256: impactos de 128 a 192, cura, bloqueio e esquiva 128. Nos estados, o
## desenho ocupa só uns 120 dos 256 px do quadro: com o quadro em 192, a forma fica com uns 90 px (os 64 a 96 do
## documento).
const SCREEN_PX := {"hit_metal": 176.0, "hit_dust": 176.0, "critical": 192.0, "healing": 128.0, "block": 128.0,
	"dodge": 128.0, "status": 192.0}
## Onde, no corpo, cada um fica (fração da altura do corpo a partir do pé; a âncora do efeito vai nesse ponto).
const BODY_HEIGHT_AT := {"hit_metal": 0.5, "hit_dust": 0.3, "critical": 0.5, "healing": 0.5, "block": 0.5, "dodge": 0.02}
## A altura do atordoado e da marca (fração do corpo): na cabeça (as estrelas giram em volta dela e os cantos da marca a
## enquadram). Acima dela, os dois caíam no desfoque do alto da tela.
const HEAD_AT := 0.88
## Com "Reduzir efeitos": o quadro que fica parado e por quanto tempo (s).
const REDUCED_FRAME := 2
const REDUCED_SECONDS := 0.25
## Um pouco na frente do personagem (m), para o efeito não entrar nele.
const FRONT := 0.3
## A ordem dos estados no corpo: o sangramento ao lado, o veneno embaixo do lado de lá, o atordoado e a marca acima da
## cabeça (lado a lado quando os dois estão juntos).
const STATES := ["bleeding", "poison", "stunned", "marked"]
## Os efeitos de golpe (só num golpe de outro).
const HITS := ["hit_metal", "hit_dust", "critical"]
## Um efeito por alvo em cada lance, para não empilhar no mesmo ponto: o mais forte desta lista (o escudo no lugar do
## acerto que ele segurou).
const PRIORITY := ["critical", "block", "hit_metal", "hit_dust", "dodge", "healing"]

var _effects := {}
var _speed := 1.0


func _init() -> void:
	if FileAccess.file_exists(MANIFEST):
		_effects = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)).get("effects", {})


func has(effect: String) -> bool:
	return _effects.has(effect)


func entry(effect: String) -> Dictionary:
	return _effects.get(effect, {})


## O efeito curto de um evento (o nome da folha) ou "": o dano (crítico, faíscas no robô, poeira nos outros), a cura, o
## bloqueio e a esquiva.
static func for_event(type: int, crit: bool, machine: bool) -> String:
	match type:
		AHCombat.EventType.DAMAGE:
			return "critical" if crit else ("hit_metal" if machine else "hit_dust")
		AHCombat.EventType.HEAL:
			return "healing"
		AHCombat.EventType.BLOCK:
			return "block"
		AHCombat.EventType.DODGE:
			return "dodge"
	return ""


## O mais forte de dois efeitos ("" perde de todos).
static func stronger(a: String, b: String) -> String:
	if a == "" or (b != "" and PRIORITY.find(b) < PRIORITY.find(a)):
		return b
	return a


## Os estados com loop que a unidade tem agora: {estado: folha}. O sangramento do robô é o óleo.
static func states_of(unit: AHCombat.Unit, machine: bool) -> Dictionary:
	var out := {}
	if not unit.is_standing():
		return out
	if unit.bleed.duration > 0:
		out.bleeding = "status_bleeding_robot" if machine else "status_bleeding_organic"
	if unit.blight.duration > 0:
		out.poison = "status_poison"
	if unit.stun_turns > 0:
		out.stunned = "status_stunned"
	if unit.mark_duration > 0:
		out.marked = "status_marked"
	return out


## Toca o efeito curto no personagem: some sozinho no fim (a velocidade da luta encurta). reduced: um quadro parado.
func play(effect: String, card: AHSpriteCard, camera: Camera3D, speed: float, reduced: bool) -> AHSpriteCard:
	if not _effects.has(effect) or card == null or not is_instance_valid(card):
		return null
	_speed = maxf(speed, 0.01)
	var art: Dictionary = _effects[effect].duplicate(true)
	art.fps = float(art.fps) * _speed
	if reduced:
		art.frames = [art.frames[mini(REDUCED_FRAME, art.frames.size() - 1)]]
	var node := _sprite(art, meters(SCREEN_PX.get(effect, 160.0), card, camera))
	node.name = "Effect_" + effect
	node.add_to_group("combat_effect")
	node.set_meta("effect", effect)
	card.add_child(node)
	node.position = Vector3(0, card.body_height * float(BODY_HEIGHT_AT.get(effect, 0.5)), FRONT)
	var life: float = REDUCED_SECONDS if reduced else float(_effects[effect].frames.size()) / float(_effects[effect].fps)
	var tween := node.create_tween()
	tween.tween_interval(life / _speed)
	tween.tween_callback(node.queue_free)
	return node


## Mantém os loops de estado de um personagem iguais aos estados dele (cria os novos e tira os que acabaram). Sem nada
## com "Reduzir efeitos" (o estado fica no HUD).
func sync_states(card: AHSpriteCard, states: Dictionary, camera: Camera3D, reduced: bool) -> void:
	if card == null or not is_instance_valid(card):
		return
	var wanted: Dictionary = {} if reduced else states
	for child in card.get_children():
		if child.is_in_group("combat_state") and (not wanted.has(child.get_meta("state")) or wanted[child.get_meta("state")] != child.get_meta("effect")):
			child.get_parent().remove_child(child)
			child.queue_free()
	var above_head: int = int(wanted.has("stunned")) + int(wanted.has("marked"))
	for state in STATES:
		if not wanted.has(state):
			continue
		var node: AHSpriteCard = null
		for child in card.get_children():
			if child.is_in_group("combat_state") and child.get_meta("state") == state:
				node = child
		if node == null:
			var effect: String = wanted[state]
			if not _effects.has(effect):
				continue
			node = _sprite(_effects[effect], meters(SCREEN_PX.status, card, camera))
			node.name = "State_" + state
			node.add_to_group("combat_state")
			node.set_meta("state", state)
			node.set_meta("effect", effect)
			card.add_child(node)
		node.position = state_offset(state, card, above_head > 1)
		node.set_facing(card.facing)


## Onde o loop do estado fica no personagem (m, a partir do pé): as gotas ao lado do corpo (para a frente), o veneno
## baixo do lado de trás, o atordoado e a marca na cabeça, lado a lado se os dois estão juntos. Mais alto, eles caíam no
## desfoque do alto da tela (o tilt-shift do pós-processo) e perdiam a forma.
static func state_offset(state: String, card: AHSpriteCard, both_above: bool) -> Vector3:
	var height := card.body_height
	var side := card.facing
	match state:
		"bleeding":
			return Vector3(side * height * 0.3, height * 0.55, FRONT)
		"poison":
			return Vector3(-side * height * 0.3, height * 0.32, FRONT)
		"stunned":
			return Vector3(-height * 0.13 if both_above else 0.0, height * HEAD_AT, FRONT)
		"marked":
			return Vector3(height * 0.13 if both_above else 0.0, height * HEAD_AT, FRONT)
	return Vector3(0, height * 0.5, FRONT)


## Os metros que dão px na tela de 1080 na distância do personagem (sem câmera, uma fração do corpo).
static func meters(px: float, card: AHSpriteCard, camera: Camera3D) -> float:
	if camera == null or not camera.is_inside_tree():
		return card.body_height * px / 400.0
	var distance := maxf(0.5, -(camera.global_transform.affine_inverse() * card.global_position).z)
	var visible_height := 2.0 * distance * tan(deg_to_rad(camera.fov) * 0.5)
	return px / 1080.0 * visible_height


func _sprite(art: Dictionary, height: float) -> AHSpriteCard:
	var node := AHSpriteCard.new()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_blended(true)
	node.body_height = height
	node.show_art(art)
	return node
