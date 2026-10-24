## Autoload GameFlow: troca de cenas pelo id, com um fade preto entre elas. As outras partes do jogo pedem a cena pelo id
## (GameFlow.change_to("street")) e leem os parâmetros da troca em GameFlow.params. As trocas grandes (título, Estação,
## rua e cenários) passam pela passagem (travel, #74): o cartão com o título do lugar enquanto a cena carrega.
extends Node

signal scene_changed(scene_id: String)

## Cenas do jogo pelo id. Cada fase do plano acrescenta as suas (combate, estação, cenários).
const SCENES := {
	"title": "res://scenes/title.tscn",
	"street": "res://scenes/street.tscn",
	"station": "res://scenes/station.tscn",
}
const FADE_SECONDS := 0.25
## Quanto o cartão da passagem fica na tela, no mínimo, quando ninguém pula (a cena carregando pode segurar mais).
const CARD_SECONDS := 1.8

var current_id := ""
var params := {}
var busy := false
## O cartão da passagem aberto (null fora dela).
var passage: AHPassageCard
var _layer: CanvasLayer
var _fade: ColorRect


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	_layer = layer
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_fade.visible = false
	layer.add_child(_fade)
	add_child(layer)


static func scene_path(scene_id: String) -> String:
	return SCENES.get(scene_id, "")


## Primeira cena depois do boot: a tela de título (#28). O modo de captura da rua (--capture=) monta a própria campanha e
## abre direto a rua.
func start() -> void:
	# O roteiro de desempenho (--perf, #37) passa pelas cenas sozinho e sai.
	if AHPerfTour.requested():
		add_child(AHPerfTour.new())
		return
	var capture := Array(OS.get_cmdline_user_args()).any(func(arg): return String(arg).begins_with("--capture="))
	change_to("street" if capture else "title", {}, false)


## Continuar (o título): a rua se a expedição está em andamento; senão a Estação Raiz.
func continue_game() -> bool:
	var session: Dictionary = Campaign.state.get("session", {})
	var in_expedition: bool = session.get("expedition") != null and session.get("result", "") == ""
	return await travel("street" if in_expedition else "station")


## O cartão de uma cena: o título e o subtítulo da Estação (o ciclo), da rua (a fase, o lugar e o trecho) ou do título.
## Só cita a fase da expedição em andamento, que já está liberada (a escada de revelações, docs/narrative).
static func card_for(scene_id: String) -> Dictionary:
	var c: Dictionary = Campaign.state
	match scene_id:
		"station":
			return {"title": String(TranslationServer.translate("Estação Raiz")),
				"subtitle": String(TranslationServer.translate("Ciclo %d")) % int(c.get("station", {}).get("cycle_number", 0))}
		"street":
			var expedition = c.get("session", {}).get("expedition")
			if expedition == null:
				return {}
			var info := AHJourneyRules.phase(String(expedition.get("phase_id", "")))
			if info.is_empty():
				return {}
			var corridor: Dictionary = expedition.get("corridor", {})
			var index := int(corridor.get("index", 0))
			var steps := int(corridor.get("steps", []).size())
			var place := AHScenarioWorld.display_of(AHJourneyRules.map_for_step(info.id, index))
			var phase_name := String(TranslationServer.translate(info.name))
			var step_text := String(TranslationServer.translate("Trecho %d de %d")) % [index + 1, steps] if steps > 0 else ""
			var parts: Array = [] if place == phase_name else [place]
			if step_text != "":
				parts.append(step_text)
			return {"title": phase_name, "subtitle": " · ".join(parts)}
		"title":
			return {"title": "After Humans"}
	return {}


## A passagem (#74): o fade fecha, a cena atual sai, o cartão com o título aparece enquanto a cena seguinte carrega em
## segundo plano e monta por baixo dele (o _ready pesado roda com o título na tela) e o fade abre na cena nova. O cartão pode ter uma cena de fundo (card.backdrop). Interagir, Esc, o
## controle ou um toque pulam, mas só com a cena seguinte carregada (nunca abre uma cena pela metade). Com "Reduzir
## efeitos", sem movimento: só o título. Sem card, usa o da cena (card_for). card.hold troca o tempo mínimo do cartão
## (a partida no vagão fica mais). Retorna false como change_to.
func travel(scene_id: String, card: Dictionary = {}, scene_params: Dictionary = {}) -> bool:
	var path := scene_path(scene_id)
	if path == "" or busy:
		push_warning("GameFlow: cena desconhecida ou troca em andamento (%s)." % scene_id)
		return false
	busy = true
	params = scene_params
	if card.is_empty():
		card = card_for(scene_id)
	ResourceLoader.load_threaded_request(path)
	await _fade_to(1.0)
	var tree := get_tree()
	# A cena de antes sai já no preto: nada por trás do cartão anda nem recebe tecla enquanto a outra carrega.
	if tree.current_scene != null:
		tree.unload_current_scene()
	passage = AHPassageCard.new(card, reduced_effects())
	_layer.add_child(passage)
	_layer.move_child(passage, 0)
	await _fade_to(0.0)
	var hold: float = CARD_SECONDS if passage.backdrop == null else float(card.get("hold", CARD_SECONDS))
	var packed: PackedScene = null
	var scene: Node = null
	var mode := Node.PROCESS_MODE_INHERIT
	# Pelo relógio, desde que o cartão abriu: o quadro que monta a cena trava segundos, mas o delta dele chega cortado
	# (~0,14 s); somando deltas, o tempo mínimo só começava depois da montagem.
	var opened := Time.get_ticks_msec()
	while scene == null or not (passage.skipped or Time.get_ticks_msec() - opened >= hold * 1000.0):
		await tree.process_frame
		if packed == null:
			var status := ResourceLoader.load_threaded_get_status(path)
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				packed = ResourceLoader.load_threaded_get(path)
			elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				# O pedido em segundo plano falhou (ou já foi consumido): carrega aqui mesmo.
				packed = load(path)
		elif scene == null:
			# A cena nova monta por baixo do cartão (opaco), parada: não anda nem recebe tecla até o cartão sair. Só
			# depois de montada dá para pular.
			scene = packed.instantiate()
			mode = scene.process_mode
			scene.process_mode = Node.PROCESS_MODE_DISABLED
			tree.root.add_child(scene)
			tree.current_scene = scene
			await tree.process_frame
			passage.mark_ready()
	await _fade_to(1.0)
	passage.queue_free()
	passage = null
	scene.process_mode = mode
	current_id = scene_id
	scene_changed.emit(scene_id)
	await _fade_to(0.0)
	busy = false
	return true


static func reduced_effects() -> bool:
	return bool(Campaign.state.get("settings", {}).get("reduced_environment_effects", false))


## Troca para a cena pelo id. Retorna false se o id não existir ou se já houver uma troca em andamento.
func change_to(scene_id: String, scene_params: Dictionary = {}, fade: bool = true) -> bool:
	var path := scene_path(scene_id)
	if path == "" or busy:
		push_warning("GameFlow: cena desconhecida ou troca em andamento (%s)." % scene_id)
		return false
	busy = true
	params = scene_params
	if fade:
		await _fade_to(1.0)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	current_id = scene_id
	scene_changed.emit(scene_id)
	if fade:
		await _fade_to(0.0)
	busy = false
	return true


## Uma cena que, ao abrir, vê que o jogo pertence a outra (a Estação no meio de uma expedição, a rua sem expedição) pede
## a troca daqui: ela espera a troca que a abriu terminar (change_to recusa enquanto busy) e então troca.
func redirect(scene_id: String) -> void:
	while busy:
		await get_tree().process_frame
	change_to(scene_id, {}, false)


## Escurece (1) ou clareia (0) a tela, para transições dentro da mesma cena (entrar numa casa).
func fade(alpha: float) -> void:
	await _fade_to(alpha)


func _fade_to(alpha: float) -> void:
	_fade.visible = true
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, FADE_SECONDS)
	await tween.finished
	# Transparente, o retângulo ainda custaria uma passada na tela inteira.
	_fade.visible = alpha > 0.0
