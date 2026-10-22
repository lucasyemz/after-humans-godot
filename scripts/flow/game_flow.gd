## Autoload GameFlow: troca de cenas pelo id, com um fade preto entre elas. As outras partes do jogo pedem a cena pelo id
## (GameFlow.change_to("street")) e leem os parâmetros da troca em GameFlow.params.
extends Node

signal scene_changed(scene_id: String)

## Cenas do jogo pelo id. Cada fase do plano acrescenta as suas (combate, estação, cenários).
const SCENES := {
	"title": "res://scenes/title.tscn",
	"street": "res://scenes/street.tscn",
	"station": "res://scenes/station.tscn",
}
const FADE_SECONDS := 0.25

var current_id := ""
var params := {}
var busy := false
var _fade: ColorRect


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
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
	var capture := Array(OS.get_cmdline_user_args()).any(func(arg): return String(arg).begins_with("--capture="))
	change_to("street" if capture else "title", {}, false)


## Continuar (o título): a rua se a expedição está em andamento; senão a Estação Raiz.
func continue_game() -> bool:
	var session: Dictionary = Campaign.state.get("session", {})
	var in_expedition: bool = session.get("expedition") != null and session.get("result", "") == ""
	return await change_to("street" if in_expedition else "station")


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
