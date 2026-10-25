## O HUD do acampamento (#77), no padrão da luta (decisão do Lucas): a placa com a vida e o instinto sobre cada herói,
## a área do clique no corpo inteiro (como o alvo da luta, #57), e embaixo o escolhido com Comer, Curativo e Levantar
## acampamento. As setas (ou o direcional) passam de um herói para outro; cima e baixo andam entre os botões; Interagir
## confirma. Cada comida ou curativo responde no herói: o número verde subindo, o efeito da #80 e o som. Troca para o
## kit da #59/#60 quando a biblioteca entrar.
class_name AHCampHud
extends Control

const H = preload("res://scripts/ui/combat_hud.gd")
const S = preload("res://scripts/ui/ui_style.gd")
## Os efeitos da #80 (docs/design/camp/contract.json): a comida, o curativo e, na Íris, a ampola.
const FOOD_EFFECT := "res://art/camp/food_morsel.webp"
const BANDAGE_EFFECT := "res://art/camp/bandage_wrap.webp"
const AMPOULE_EFFECT := "res://art/camp/iris_ampoule.webp"
const EFFECT_SIZE := 64.0
const EFFECT_MS := 600
const EFFECT_REDUCED_MS := 400
const FOOD_SOUND := "res://audio/ui/confirm.ogg"
const BANDAGE_SOUND := "res://audio/combat/RobotHeal.wav"

signal food(hero_id: String)
signal bandage(hero_id: String)
signal leave

## A largura dos botões do canto (Mochila e Menu, do exploration_hud) mais a folga até a barra.
const CORNER_BUTTONS := 452.0

var camp: AHCampScene
var _plates := {}
var _bodies := {}
var _bar: PanelContainer
var _name: Label
var _life: Label
var _life_bar: ProgressBar
var _instinct: Label
var _instinct_bar: ProgressBar
var eat_button: Button
var heal_button: Button
var leave_button: Button
var _note: Label
## O lado (−1, 1) que está apertado agora; 0 solto.
var _held := 0


func _init(scene: AHCampScene = null) -> void:
	camp = scene
	name = "CampHud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build_bar()
	for member in camp.members:
		_add_member(member.hero_id)
	camp.selected_changed.connect(func(_i): refresh())
	refresh()
	focus_bar.call_deferred()


## O foco na barra: Comer, senão Curativo, senão Levantar.
func focus_bar() -> void:
	if is_inside_tree():
		(eat_button if not eat_button.disabled else (heal_button if not heal_button.disabled else leave_button)).grab_focus()


func _build_bar() -> void:
	_bar = PanelContainer.new()
	_bar.add_theme_stylebox_override("panel", H.panel_style(0.92))
	add_child(_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_bar.add_child(row)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 2)
	who.custom_minimum_size = Vector2(360, 0)
	row.add_child(who)
	who.add_child(H.make_label(tr("Acampamento"), 18, H.MUTED))
	_name = H.make_label("", 28, H.GOLD)
	who.add_child(_name)
	_life = H.make_label("", 18, H.TEXT)
	who.add_child(_life)
	_life_bar = S.bar(Color(0.45, 0.85, 0.5), 10.0)
	_life_bar.custom_minimum_size = Vector2(340, 10)
	who.add_child(_life_bar)
	_instinct = H.make_label("", 17, S.VIOLET)
	who.add_child(_instinct)
	_instinct_bar = S.bar(Color(0.6, 0.48, 0.92), 8.0)
	_instinct_bar.max_value = 200
	_instinct_bar.custom_minimum_size = Vector2(340, 8)
	who.add_child(_instinct_bar)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	row.add_child(actions)
	eat_button = _action_button(func(): food.emit(camp.selected_id()))
	heal_button = _action_button(func(): bandage.emit(camp.selected_id()))
	actions.add_child(eat_button)
	actions.add_child(heal_button)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	row.add_child(side)
	leave_button = _action_button(func(): leave.emit())
	leave_button.text = tr("Levantar acampamento")
	side.add_child(leave_button)
	_note = H.make_label("", 16, H.MUTED)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(380, 0)
	side.add_child(_note)
	# Cima e baixo andam entre os três botões (as setas do lado trocam de herói).
	var order := [eat_button, heal_button, leave_button]
	for i in order.size():
		order[i].focus_neighbor_top = order[(i - 1 + order.size()) % order.size()].get_path()
		order[i].focus_neighbor_bottom = order[(i + 1) % order.size()].get_path()
		order[i].focus_neighbor_left = order[i].get_path()
		order[i].focus_neighbor_right = order[i].get_path()


func _action_button(action: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(300, 46)
	H.style_button(button)
	button.pressed.connect(action)
	return button


func _add_member(hero_id: String) -> void:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", H.panel_style(0.85))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(column)
	var label := H.make_label("", 16, H.TEXT)
	label.name = "Name"
	column.add_child(label)
	var bar := S.bar(Color(0.45, 0.85, 0.5), 6.0)
	bar.name = "Life"
	bar.custom_minimum_size = Vector2(120, 6)
	column.add_child(bar)
	# O instinto como na placa da luta: a barra violeta fina (em 200, crise).
	var instinct := S.bar(Color(0.6, 0.48, 0.92), 4.0)
	instinct.name = "Instinct"
	instinct.max_value = 200
	instinct.custom_minimum_size = Vector2(120, 4)
	column.add_child(instinct)
	add_child(plate)
	_plates[hero_id] = plate
	# A área do clique: o corpo inteiro na tela (como o alvo da luta), sem fundo.
	var body := Button.new()
	body.name = "Body_" + hero_id
	body.focus_mode = Control.FOCUS_NONE
	body.tooltip_text = String(Campaign.hero(hero_id).display_name)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		body.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	body.pressed.connect(func(): camp.select(camp.members.map(func(m): return m.hero_id).find(hero_id)))
	add_child(body)
	move_child(body, 0)
	_bodies[hero_id] = body


## Atualiza o escolhido, os botões e as placas (depois de cada comida e curativo, e na troca de herói).
func refresh() -> void:
	if not camp.active or camp.members.is_empty():
		return
	var campaign: Dictionary = Campaign.state
	var hero = Campaign.hero(camp.selected_id())
	if hero == null:
		return
	var food_left := AHJourneyRules.food(campaign)
	var bandages := int(campaign.inventory.bandages)
	_name.text = String(hero.display_name)
	_life.text = tr("Vida %d/%d") % [hero.hp, hero.max_hp]
	_life_bar.max_value = hero.max_hp
	_life_bar.value = hero.hp
	_instinct.text = tr("Instinto %d/200") % hero.instinct
	_instinct_bar.value = hero.instinct
	eat_button.text = tr("Comer (%d)") % food_left
	eat_button.disabled = food_left <= 0 or (hero.hp >= hero.max_hp and hero.instinct <= 0)
	heal_button.text = tr("Curativo (%d)") % bandages
	heal_button.disabled = bandages <= 0 or hero.hp >= hero.max_hp
	_note.text = tr("Comer: +10%% de vida e −5 de instinto. Curativo: +8 de vida. %s/%s troca de herói.") % [S.key_name("move_left"), S.key_name("move_right")]
	for member in camp.members:
		var plate: PanelContainer = _plates.get(member.hero_id)
		var someone = Campaign.hero(member.hero_id)
		if plate == null or someone == null:
			continue
		var chosen: bool = member.hero_id == camp.selected_id()
		plate.add_theme_stylebox_override("panel", H.panel_style(0.85) if not chosen else S.panel(0.9, S.GOLD, 2))
		(plate.find_child("Name", true, false) as Label).text = "%s %d/%d" % [someone.display_name, someone.hp, someone.max_hp]
		var bar: ProgressBar = plate.find_child("Life", true, false)
		bar.max_value = someone.max_hp
		bar.value = someone.hp
		(plate.find_child("Instinct", true, false) as ProgressBar).value = someone.instinct
	# O botão com foco que ficou apagado (comida acabou) passa o foco para o próximo que serve.
	var owner := get_viewport().gui_get_focus_owner() if get_viewport() else null
	if owner is Button and owner.disabled:
		for button in [eat_button, heal_button, leave_button]:
			if not button.disabled:
				button.grab_focus()
				break


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not camp.active:
		return
	var view := get_viewport_rect().size
	_bar.reset_size()
	# Centrada, mas sem passar dos botões do canto (a Mochila e o Menu continuam no acampamento, #98).
	var x := minf((view.x - _bar.size.x) * 0.5, view.x - CORNER_BUTTONS - _bar.size.x)
	_bar.position = Vector2(maxf(24.0, x), view.y - _bar.size.y - 24)
	# O Concluir jornada (guardião vencido) fica acima da barra: no texto Maior ele cresce e encostaria nela.
	var finish = get_parent().get("_finish_button") if get_parent() != null else null
	if finish is Control and finish.visible:
		finish.position.y = _bar.position.y - finish.size.y - 12.0
	var clicks := click_rects(camera)
	for member in camp.members:
		var card: AHSpriteCard = member.card
		if not is_instance_valid(card):
			continue
		var rect := body_rect(camera, card)
		var body: Button = _bodies.get(member.hero_id)
		if body != null and clicks.has(member.hero_id):
			body.position = clicks[member.hero_id].position
			body.size = clicks[member.hero_id].size
		var plate: PanelContainer = _plates.get(member.hero_id)
		if plate != null:
			plate.reset_size()
			# A placa embaixo dos pés, como na luta; em cima da cabeça fica o efeito de comer e curar.
			plate.position = Vector2(rect.get_center().x - plate.size.x * 0.5, rect.end.y + 6)
			plate.visible = not camera.is_position_behind(card.global_position)


## O corpo na tela: a caixa do alfa visível da pose (camp_poses.json, "visible"), e não o canvas inteiro (o da pose
## sentada tem o vazio de cima do idle); sem ela, do pé ao topo da placa.
static func body_rect(camera: Camera3D, card: AHSpriteCard) -> Rect2:
	var art: Dictionary = card.art()
	var corners: Array = []
	if art.has("visible"):
		var px_to_m: float = card.body_height / float(art.body_reference_pixels)
		var anchor := Vector2(art.anchor[0], art.anchor[1])
		var box: Array = art.visible
		for point in [Vector2(box[0], box[1]), Vector2(box[2], box[3])]:
			var local := Vector3((point.x - anchor.x) * px_to_m * card.facing, (anchor.y - point.y) * px_to_m, 0)
			corners.append(camera.unproject_position(card.global_position + local))
	else:
		var size: Vector2 = (card.mesh as QuadMesh).size
		var offset: Vector3 = (card.mesh as QuadMesh).center_offset
		corners.append(camera.unproject_position(card.global_position + Vector3(offset.x - size.x * 0.3, offset.y + size.y * 0.5, 0)))
		corners.append(camera.unproject_position(card.global_position + Vector3(offset.x + size.x * 0.3, 0, 0)))
	var low := Vector2(minf(corners[0].x, corners[1].x), minf(corners[0].y, corners[1].y))
	var high := Vector2(maxf(corners[0].x, corners[1].x), maxf(corners[0].y, corners[1].y))
	return Rect2(low, (high - low).max(Vector2(48, 24)))


## As áreas do clique de cada um: o corpo visível; onde dois se encostam na tela (quem está deitado atrás de quem está
## sentado na frente), a área se divide no meio da sobra, para cada clique ser de um só (a regra do contrato da #80).
func click_rects(camera: Camera3D) -> Dictionary:
	var out := {}
	for member in camp.members:
		if is_instance_valid(member.card):
			out[member.hero_id] = body_rect(camera, member.card)
	var ids: Array = out.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: Rect2 = out[ids[i]]
			var b: Rect2 = out[ids[j]]
			if not a.intersects(b):
				continue
			var left_id: String = ids[i] if a.get_center().x <= b.get_center().x else ids[j]
			var right_id: String = ids[j] if left_id == ids[i] else ids[i]
			var left: Rect2 = out[left_id]
			var right: Rect2 = out[right_id]
			var middle := (maxf(left.position.x, right.position.x) + minf(left.end.x, right.end.x)) * 0.5
			left.size.x = maxf(middle - left.position.x, 24.0)
			right.size.x = maxf(right.end.x - middle, 24.0)
			right.position.x = middle
			out[left_id] = left
			out[right_id] = right
	return out


## Interagir (E, o A do controle) confirma o botão com foco, como na luta. Esquerda e direita trocam de herói uma vez por
## toque: o analógico só troca de novo depois de voltar ao centro, e segurar a tecla não gira a roda.
func _input(event: InputEvent) -> void:
	if not camp.active or not is_visible_in_tree():
		return
	# Com o menu ou a Mochila abertos por cima, as teclas são deles.
	var parent := get_parent()
	if parent != null and parent.has_method("modal_open") and parent.modal_open():
		return
	if S.press_focused(self, event):
		get_viewport().set_input_as_handled()
		return
	# O eixo do analógico casa com as duas ações (esquerda e direita): cada lado olha só o seu.
	var handled := false
	for pair in [[-1, ["move_left", "ui_left"]], [1, ["move_right", "ui_right"]]]:
		for action in pair[1]:
			if not event.is_action(action):
				continue
			handled = true
			if event.is_action_pressed(action):
				if _held != pair[0]:
					_held = pair[0]
					camp.step(pair[0])
			elif event.is_action_released(action) and _held == pair[0]:
				_held = 0
	if handled:
		get_viewport().set_input_as_handled()


## A resposta no herói: o número verde (vida) e o do instinto subindo, o efeito e o som. Só a cena: os números já são
## os das regras (o que a vida e o instinto mudaram).
func respond(hero_id: String, kind: String, life_gain: int, instinct_change: int) -> void:
	var card := camp.member_card(hero_id)
	var camera := get_viewport().get_camera_3d()
	if card == null or camera == null:
		return
	var rect := body_rect(camera, card)
	var head := Vector2(rect.get_center().x, rect.position.y)
	var hero = Campaign.hero(hero_id)
	var file := FOOD_EFFECT if kind == "food" else (AMPOULE_EFFECT if hero != null and hero.id == "hero_sapo_iris" else BANDAGE_EFFECT)
	Sound.play(FOOD_SOUND if kind == "food" else BANDAGE_SOUND, 0.8)
	var reduced := GameFlow.reduced_effects()
	var effect := TextureRect.new()
	effect.name = "Effect"
	effect.add_to_group("camp_effect")
	effect.texture = load(file)
	effect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	effect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	effect.size = Vector2(EFFECT_SIZE, EFFECT_SIZE)
	effect.pivot_offset = effect.size * 0.5
	effect.position = head - Vector2(EFFECT_SIZE * 0.5, EFFECT_SIZE + 4)
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(effect)
	var numbers: Array = []
	if life_gain > 0:
		numbers.append(["+%d" % life_gain, Color(0.45, 0.95, 0.55)])
	if instinct_change != 0:
		numbers.append([tr("%+d instinto") % instinct_change, S.VIOLET])
	var labels: Array = []
	for i in numbers.size():
		var label := H.make_label(numbers[i][0], 26 if i == 0 else 18, numbers[i][1])
		label.name = "Gain"
		label.add_to_group("camp_gain")
		label.add_theme_constant_override("outline_size", 6)
		add_child(label)
		label.reset_size()
		label.position = head + Vector2(EFFECT_SIZE * 0.5 + 6, -EFFECT_SIZE + i * 30)
		labels.append(label)
	var nodes: Array = [effect] + labels
	if reduced:
		# Reduzir efeitos: parados por 400 ms, sem subir nem crescer.
		await get_tree().create_timer(EFFECT_REDUCED_MS / 1000.0).timeout
	else:
		effect.modulate.a = 0.0
		effect.scale = Vector2(0.8, 0.8)
		var tween := create_tween().set_parallel()
		tween.tween_property(effect, "modulate:a", 1.0, 0.1)
		tween.tween_property(effect, "scale", Vector2.ONE, 0.1)
		for node in nodes:
			tween.tween_property(node, "position:y", node.position.y - 20, EFFECT_MS / 1000.0)
			tween.tween_property(node, "modulate:a", 0.0, 0.2).set_delay(0.4)
		await tween.finished
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()
