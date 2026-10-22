## Os controles de toque: o analógico aperta as ações de andar com a força do dedo, corre perto da borda, solta tudo
## ao tirar o dedo, e o Usar manda a ação interact. O mouse imitado a partir do toque não conta duas vezes.
extends RefCounted


class FakeArena:
	var active := false


class FakeStreet extends Node:
	var _arena = FakeArena.new()
	var corridor = null
	var exploration_hud = null


func run(t) -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var street := FakeStreet.new()
	root.add_child(street)
	var touch := AHTouchControls.new()
	touch.street = street
	street.add_child(touch)
	touch.visible = true

	var start := AHTouchControls.STICK_HOME
	_touch(touch, 0, start, true)
	t.check(Input.get_vector("move_left", "move_right", "move_back", "move_front").length() < 0.01, "encostar não anda")
	_drag(touch, 0, start + Vector2(AHTouchControls.STICK_RADIUS * 0.5, 0))
	var half := Input.get_vector("move_left", "move_right", "move_back", "move_front")
	t.check(half.x > 0.4 and half.x < 0.6 and absf(half.y) < 0.01, "meio caminho para a direita anda devagar (%s)" % half)
	t.check(not Input.is_action_pressed("run"), "meio caminho não corre")
	_drag(touch, 0, start + Vector2(0, -AHTouchControls.STICK_RADIUS * 2))
	var up := Input.get_vector("move_left", "move_right", "move_back", "move_front")
	t.check(up.y < -0.9, "para cima na tela vai para o fundo (%s)" % up)
	t.check(Input.is_action_pressed("run"), "até a borda corre")
	_touch(touch, 0, start, false)
	t.check(Input.get_vector("move_left", "move_right", "move_back", "move_front").length() < 0.01 and not Input.is_action_pressed("run"),
		"tirar o dedo solta tudo")

	# O mouse que a Godot imita do toque fica de fora; o de verdade mexe no analógico.
	var fake := InputEventMouseButton.new()
	fake.button_index = MOUSE_BUTTON_LEFT
	fake.pressed = true
	fake.position = start
	fake.device = InputEvent.DEVICE_ID_EMULATION
	touch._input(fake)
	t.check(touch._stick_finger == -2, "o mouse imitado não pega o analógico")

	# Usar: o segundo dedo, com o primeiro andando.
	_touch(touch, 0, start, true)
	_touch(touch, 1, AHTouchControls.USE_CENTER, true)
	Input.flush_buffered_events()
	t.check(Input.is_action_pressed("interact"), "Usar aperta interact")
	_touch(touch, 1, AHTouchControls.USE_CENTER, false)
	Input.flush_buffered_events()
	t.check(not Input.is_action_pressed("interact"), "soltar o Usar solta interact")
	touch._release_all()
	# As peças da entrega #23: todas carregam, e a arte não muda as áreas de toque.
	for name in ["stick_base_normal", "stick_base_active", "stick_knob_normal", "stick_knob_active", "stick_run_mark", "use_inactive", "use_ready", "use_pressed"]:
		var texture: Texture2D = touch._texture(name)
		t.check(texture != null, "a peça %s carrega" % name)
		for suffix in ["", "_2x"]:
			t.check(ResourceLoader.exists(AHTouchControls.TOUCH_ART % [name, suffix]), "%s%s existe" % [name, suffix])
	t.equal([AHTouchControls.STICK_RADIUS, AHTouchControls.USE_RADIUS, AHTouchControls.STICK_HOME, AHTouchControls.USE_CENTER],
		[110.0, 78.0, Vector2(230, 800), Vector2(1790, 800)], "os raios e os centros da proposta")
	street.queue_free()


func _touch(touch: AHTouchControls, finger: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = at
	event.pressed = pressed
	touch._input(event)


func _drag(touch: AHTouchControls, finger: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = at
	touch._input(event)
