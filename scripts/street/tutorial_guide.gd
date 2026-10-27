## O guia do tutorial na rua (#144): abre as dicas de data/tutorial.json (hints) no momento certo, uma de cada vez, e
## fecha cada uma quando o jogador faz o que ela pede. O que já foi ensinado fica em campaign.tutorial.done (fechar o
## jogo no meio e voltar não repete). Só a primeira escolha de habilidade e de alvo trava a luta: as outras ações ficam
## desligadas até o jogador escolher uma habilidade.
## Os passos e quando cada um abre:
##   walk      a partida                      fecha ao andar uns metros
##   ability   a primeira vez do Bento na luta fecha ao mirar (a habilidade escolhida)
##   target    a mira                         fecha com o comando
##   search    o armário ao alcance           fecha ao vasculhar
##   bag       logo depois da busca           fecha ao abrir a Mochila
##   patrol    a segunda patrulha à frente    fecha quando a luta começa
##   position  a primeira vez na segunda luta fecha com o comando
##   item      a primeira vez na terceira     fecha ao usar um item (ou no fim da luta)
##   train     o trem parado na plataforma    fecha ao embarcar
class_name AHTutorialGuide
extends Node

## Quanto a equipe anda até a dica de andar se dar por cumprida (m).
const WALKED := 3.0

var corridor: AHStreetCorridor
var street: Node3D
var hint: AHTutorialHint
var _layer: CanvasLayer
var _start_x := 0.0
## Em que luta do tutorial a vez está (o trecho), ou -1 fora dela.
var _fight_step := -1


func _init(owner_corridor: AHStreetCorridor) -> void:
	corridor = owner_corridor
	street = owner_corridor.street
	name = "TutorialGuide"


func _ready() -> void:
	# Acima do HUD da luta e da exploração, abaixo do cartão da passagem e das dicas de primeira vez.
	_layer = CanvasLayer.new()
	_layer.layer = 15
	add_child(_layer)
	hint = AHTutorialHint.new()
	_layer.add_child(hint)
	street._arena.hud.tutorial_moment.connect(_on_combat)
	_start_x = street._leader.position.x
	_explore.call_deferred()


func done(id: String) -> bool:
	return Campaign.state.get("tutorial", {}).get("done", []).has(id)


## Mostra o passo, se ainda não foi ensinado (e não há outro aberto, a não ser que force).
func show(id: String, place: String = "top") -> void:
	var index := AHTutorial.hint_index(id)
	if index < 0 or done(id) or hint.step_id == id:
		return
	hint.show_step(AHTutorial.hints()[index], index + 1, AHTutorial.hints().size(), place)


## O passo foi cumprido: some e fica gravado.
func complete(id: String) -> void:
	var tutorial: Dictionary = Campaign.state.get("tutorial", {})
	if tutorial.is_empty():
		return
	var list: Array = tutorial.get("done", [])
	if not list.has(id):
		list.append(id)
		tutorial.done = list
	if hint.step_id == id:
		hint.hide_hint()


## Os momentos da exploração (o corredor chama): "searched", "bag", "fight_start", "fight_end", "platform", "board".
func event(kind: String) -> void:
	match kind:
		"searched":
			complete("search")
			show("bag")
		"bag":
			complete("bag")
		"fight_start":
			# A patrulha só conta como ensinada se a dica dela estava aberta (a primeira luta vem antes dela).
			if hint.step_id == "patrol":
				complete("patrol")
			complete("walk")
			hint.hide_hint()
		"fight_end":
			# O que a luta ensinava e não chegou a ser feito (a luta acabou antes) não volta.
			for id in ["ability", "target", "position", "item"]:
				if hint.step_id == id:
					complete(id)
			_fight_step = -1
			street._arena.hud.tutorial_locks = []
			_explore()
		"platform":
			hint.hide_hint()
			show("train")
		"board":
			complete("train")


## Na exploração: a próxima dica que cabe agora (o andar no começo; a Mochila se ficou pela metade).
func _explore() -> void:
	if not done("walk"):
		show("walk")
	elif done("search") and not done("bag"):
		show("bag")


func _process(_delta: float) -> void:
	# Com uma janela aberta (o Menu, as Opções, a Mochila, a conversa), a dica sai da frente e volta ao fechar.
	hint.visible = not corridor.hud.modal_open() and corridor.hud.find_child("Briefing", true, false) == null
	var avoid := _heads()
	# O aviso da tecla (Embarcar, Vasculhar) também fica à vista.
	var prompt: Control = corridor.hud.get("_prompt")
	if prompt != null and prompt.visible:
		avoid.append(prompt.get_global_rect())
	hint.set_avoid(avoid)
	if street._arena.active:
		_combat_focus()
		return
	var leader: Vector3 = street._leader.position
	match hint.step_id:
		"walk":
			if absf(leader.x - _start_x) > WALKED:
				complete("walk")
			hint.set_focus(_world_rect(leader + Vector3(0, 0.9, 0), Vector2(190, 300)))
		"bag":
			var button: Control = corridor.hud.get("_bag_button")
			hint.set_focus(button.get_global_rect() if button != null and button.is_visible_in_tree() else Rect2())
		"search", "train":
			# Passou do armário sem vasculhar: a dica sai (e a da patrulha pode vir na hora).
			if hint.step_id == "search" and not (corridor._action.is_valid() and corridor._action.get_method() == "_search_scenario_prop"):
				hint.hide_hint()
				return
			# O objeto inteiro (a marca fica em cima dele): o retângulo desce do ponto da marca até o chão.
			var point = corridor._action_point()
			hint.set_focus(_world_rect(point - Vector3(0, 0.9, 0), Vector2(170, 230)) if point != null else Rect2())
		"patrol":
			# A patrulha à frente: o primeiro da patrulha do trecho.
			var route: Dictionary = Campaign.state.session.expedition.corridor
			var guard = corridor.guards.get(route.index, corridor.guards.get(route.index + 1))
			hint.set_focus(_world_rect(guard.cards[0].global_position + Vector3(0, 0.9, 0), Vector2(200, 300)) if guard != null else Rect2())
		_:
			pass
	if hint.step_id == "" and not corridor.blocking():
		_watch_world()


## Abre as dicas que dependem do lugar: o armário ao alcance, a patrulha da segunda luta à frente.
func _watch_world() -> void:
	var route: Dictionary = Campaign.state.session.expedition.corridor
	if not done("search") and corridor._action.is_valid() and corridor._action.get_method() == "_search_scenario_prop":
		show("search")
	elif not done("patrol") and route.index >= 3 and (corridor.guards.has(route.index) or corridor.guards.has(route.index + 1)):
		show("patrol")


func _on_combat(kind: String, data: Dictionary) -> void:
	var hud: AHCombatHud = street._arena.hud
	var route: Dictionary = Campaign.state.session.expedition.corridor
	match kind:
		"turn":
			_fight_step = route.index
			if _fight_step == 1 and not done("ability"):
				# A primeira escolha trava: só as habilidades (as ações voltam quando ela é feita).
				hud.tutorial_locks = ["move", "defend", "item", "flee"]
				hud.apply_tutorial_locks()
				show("ability", "left")
			elif _fight_step == 4 and not done("position"):
				show("position", "left")
			elif _fight_step == 5 and not done("item"):
				show("item", "left")
		"target":
			if hint.step_id == "ability":
				complete("ability")
				show("target", "left")
		"cancel":
			# Desfeita a mira na primeira escolha: volta à dica da habilidade, com as ações ainda travadas.
			if hint.step_id == "target":
				var list: Array = Campaign.state.tutorial.get("done", [])
				list.erase("ability")
				hint.hide_hint()
				show("ability", "left")
		"command":
			# O comando de verdade solta as ações da primeira escolha.
			hud.tutorial_locks = []
			if hint.step_id == "target":
				complete("target")
			elif hint.step_id == "position":
				complete("position")
			elif hint.step_id == "item" and data.get("kind", "") == "item":
				complete("item")


func _combat_focus() -> void:
	var hud: AHCombatHud = street._arena.hud
	match hint.step_id:
		"ability":
			hint.set_focus(hud.tutorial_rect("abilities"))
		"target":
			hint.set_focus(hud.tutorial_rect("targets"))
		"position":
			hint.set_focus(hud.tutorial_rect("actions"))
		"item":
			hint.set_focus(hud.tutorial_rect("item"))


## As cabeças de quem está na tela (a equipe e, na luta, os inimigos): a dica não as cobre.
func _heads() -> Array:
	var cards: Array = street._heroes.duplicate()
	if street._arena.active:
		cards = street._arena.cards.values()
	var out: Array = []
	for card in cards:
		if is_instance_valid(card) and card.visible:
			var rect := _world_rect(card.global_position + Vector3(0, card.head_height() * 0.75, 0), Vector2(220, 260))
			if rect.has_area():
				out.append(rect)
	return out


## O retângulo na tela (1920 x 1080) em volta de um ponto do mundo.
func _world_rect(point: Vector3, size: Vector2) -> Rect2:
	var camera := street.get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(point):
		return Rect2()
	var view := street.get_viewport().get_visible_rect().size
	var at := camera.unproject_position(point) * Vector2(1920.0 / view.x, 1080.0 / view.y)
	return Rect2(at - size * 0.5, size)
