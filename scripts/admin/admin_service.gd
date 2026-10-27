## A barra de Admin para testes (#130, o AHAdminWidget da Unreal): a ação admin_toggle (F1) abre e fecha, por cima de
## tudo, em qualquer tela. Aberta, o jogo fica pausado: a tela de baixo não recebe as teclas nem anda, e o que a barra
## mudou aparece ao fechar. Só na build de teste (a do editor e as exportações de depuração) ou com --admin na linha de
## comando; na do jogador, o F1 não abre nada. O que a barra muda fora do save (a câmera, a velocidade, o inimigo da
## próxima patrulha) fica aqui.
extends Node

## A camada por cima de tudo (a passagem e as dicas ficam abaixo).
const LAYER := 120

## Multiplica a distância da câmera da rua e da luta e o campo de visão da Estação.
var camera_zoom := {"explore": 1.0, "fight": 1.0, "station": 1.0}
## A ambiência mudada ao vivo pela barra (#153), por lugar: {id: {campo: valor}} por cima do perfil do arquivo.
var ambience := {}
## A velocidade da luta escolhida na barra (1, 2 ou 4); 0: a das Opções.
var battle_speed := 0.0
## O inimigo da próxima patrulha ("" = o da rota).
var next_enemy := ""
## Para os testes: finge a build do jogador (o F1 não abre).
var player_build := false

var _layer: CanvasLayer
var panel: AHAdminPanel
## O jogo já estava pausado quando a barra abriu (fechar devolve como estava).
var _was_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)
	# O último da raiz recebe as teclas antes de todos (o F1 não é engolido pela tela, nem na chegada do trem).
	_to_last.call_deferred()
	GameFlow.scene_changed.connect(func(_id): _to_last.call_deferred())
	GameFlow.scene_changed.connect(func(_id): next_enemy = "")


func _to_last() -> void:
	if is_inside_tree():
		get_parent().move_child(self, -1)


## A barra vale nesta build: a de teste, ou a do jogador aberta com --admin.
func allowed() -> bool:
	if player_build:
		return false
	return OS.is_debug_build() or OS.get_cmdline_user_args().has("--admin") or OS.get_cmdline_args().has("--admin")


func is_open() -> bool:
	return panel != null and panel.visible


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func open() -> void:
	if not allowed() or is_open():
		return
	if panel == null:
		panel = AHAdminPanel.new()
		_layer.add_child(panel)
	_was_paused = get_tree().paused
	get_tree().paused = true
	panel.open()


func close() -> void:
	if not is_open():
		return
	panel.close()
	get_tree().paused = _was_paused


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("admin_toggle") and not event.is_echo():
		if not allowed():
			return
		# Aberta pelo teclado, a barra já começa com o foco num botão.
		if event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction:
			AHUiStyle.using_keys = true
		toggle()
		get_viewport().set_input_as_handled()
		return
	if is_open():
		# O Settings (pausado) não vê as teclas: o foco aparece para quem usa teclado ou controle.
		if event is InputEventKey or event is InputEventJoypadButton:
			AHUiStyle.using_keys = true
		elif event is InputEventMouseButton:
			AHUiStyle.using_keys = false


## A luta contra o inimigo escolhido (a próxima patrulha): a mesma quantidade de vagas, todas dele, com as posições
## recontadas pelo tamanho (o de tamanho 2 ocupa duas, e quem não cabe nas quatro sai, como em journey_rules).
func override_enemies(enemies: Array) -> Array:
	if next_enemy == "" or not allowed():
		return enemies
	var row = GameData.row("enemies", next_enemy)
	if row == null:
		next_enemy = ""
		return enemies
	var size := maxi(1, int(row.get("FormationSize", 0)))
	var out: Array = []
	var next_rank := 1
	for spec in enemies:
		if next_rank + size - 1 > 4:
			break
		var copy: Dictionary = spec.duplicate()
		copy.enemy_id = next_enemy
		copy.unit_id = "%s_admin" % String(spec.unit_id)
		copy.rank = next_rank
		copy.hp = int(row.MaxHp)
		copy.max_hp = int(row.MaxHp)
		# O sufixo do nome ("· Guardião") fica com quem toma o lugar.
		var original = GameData.row("enemies", String(spec.enemy_id))
		var suffix := String(spec.get("display_name", "")).trim_prefix(String(original.DisplayName)) if original != null else ""
		copy.display_name = String(row.DisplayName) + suffix
		copy.damage_bonus = 0
		next_rank += size
		out.append(copy)
	next_enemy = ""
	return out


## A distância da câmera vezes o zoom da barra (1 sem ela).
func zoom(key: String) -> float:
	return float(camera_zoom.get(key, 1.0)) if allowed() else 1.0
