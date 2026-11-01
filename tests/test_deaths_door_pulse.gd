## O Último Fôlego de pé e piscando em vermelho (#281, a Porta da Morte do Darkest Dungeon): o pulso vai e volta, soma ao
## destaque da mira, volta depois do piscar do acerto e apaga ao desligar.
extends RefCounted


func run(t) -> void:
	var tree: SceneTree = Engine.get_main_loop()
	var card := AHSpriteCard.new()
	tree.root.add_child(card)
	var material: StandardMaterial3D = card._material
	t.equal(material.emission, Color.BLACK, "sem pulso, sem luz")
	card.set_danger(true)
	t.check(card.in_danger(), "o pulso liga")
	var reds: Array = []
	for i in 12:
		card._process(AHSpriteCard.DANGER_PERIOD / 12.0)
		reds.append(material.emission.r)
	var low: float = reds.min()
	var high: float = reds.max()
	t.check(low >= AHSpriteCard.DANGER_MIN * 0.99 and low < 0.1, "o pulso desce perto do mínimo (%.2f)" % low)
	t.check(high > 0.25 and high <= AHSpriteCard.DANGER_MAX * 1.01, "e sobe perto do máximo (%.2f)" % high)
	t.check(material.emission.r > material.emission.g * 4.0, "a luz é vermelha")
	# A mira acesa: o pulso soma à cor do destaque.
	card.set_highlight(Color(0.2, 0.4, 0.9), 1.0)
	card._process(0.01)
	t.check(material.emission.b > 0.85 and material.emission.r > 0.2 + AHSpriteCard.DANGER_MIN * 0.9, "o pulso soma ao destaque da mira")
	card.set_highlight(Color.BLACK, 0.0)
	# O piscar do acerto termina de volta no pulso, não no apagado.
	card.flash(Color.WHITE, 0.01)
	await card._flash_tween.finished
	card._process(0.0)
	t.check(material.emission.r >= AHSpriteCard.DANGER_MIN * 0.99, "depois do acerto o pulso continua")
	# Com os efeitos reduzidos, um brilho vermelho fixo no meio do pulso, sem piscar.
	card.steady_danger = true
	var steady: Array = []
	for i in 6:
		card._process(AHSpriteCard.DANGER_PERIOD / 6.0)
		steady.append(material.emission.r)
	t.check(steady.max() - steady.min() < 0.001 and absf(steady[0] - (AHSpriteCard.DANGER_MIN + AHSpriteCard.DANGER_MAX) * 0.5) < 0.001,
		"efeitos reduzidos: brilho fixo, sem piscar (%.2f a %.2f)" % [steady.min(), steady.max()])
	card.steady_danger = false
	card.set_danger(false)
	t.equal(material.emission, Color.BLACK, "desligado, a luz apaga")
	card._process(0.3)
	t.equal(material.emission, Color.BLACK, "e não volta sozinha")
	card.queue_free()
