## O rodízio dos tocadores de efeito (#72): com o trem tocando (a chegada, 7 s), dez efeitos curtos seguidos pegam os
## tocadores livres ou o que está mais perto de acabar, e o trem não é cortado.
extends RefCounted

const TRAIN := "res://audio/station/train_arrival.ogg"
const CLICK := "res://audio/ui/click.ogg"

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	for player in Sound._effects:
		player.stop()
	var train: AudioStreamPlayer = Sound.play(TRAIN)
	if not t.check(train != null and train.playing, "o trem toca"):
		return
	var others: Array = []
	for i in Sound._effects.size():
		others.append(Sound.play(CLICK))
		await _tree.process_frame
	t.check(not others.has(train), "dez efeitos seguidos não tomam o tocador do trem")
	t.check(train.playing and train.stream.resource_path == TRAIN, "e o trem segue tocando")
	# Com todos tocando, o próximo pega o que está mais perto de acabar (um clique), nunca o trem.
	t.check(Sound._effects.all(func(p): return p.playing), "os tocadores estão todos ocupados")
	var next: AudioStreamPlayer = Sound.play(CLICK)
	t.check(next != train and train.stream.resource_path == TRAIN, "o seguinte, com todos tocando, também não corta o trem")
	for player in Sound._effects:
		player.stop()
