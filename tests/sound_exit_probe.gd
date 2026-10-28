## O fechamento do jogo, num processo à parte (o test_sound_exit roda este script e lê a saída): a música trocada (o
## tocador antigo parado no fim do crossfade), um efeito que acabou de começar e a janela fechada. Sem soltar os sons e
## esperar o servidor de áudio, o Godot avisa de instâncias e sons presos ao sair.
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var sound = root.get_node("Sound")
	sound.set_process(false)
	sound._switch(0, "res://audio/music/explore_3.ogg", 0.5)
	var until := Time.get_ticks_msec() + 300
	while Time.get_ticks_msec() < until:
		await process_frame
	sound._switch(0, "res://audio/music/explore_2.ogg", 0.5)
	until = Time.get_ticks_msec() + int((sound.FADE_SECONDS + 0.5) * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
	sound.play("res://audio/station/train_brake.ogg", 0.8)
	print("PROBE fechando")
	# Como a janela fechada: o aviso chega a todos os nós (o Sound fecha, o Campaign grava o tempo jogado).
	root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	# Se o aviso não fechar o jogo, a sonda sai sozinha com o código 3 (o teste falha em vez de esperar para sempre).
	until = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < until:
		await process_frame
	quit(3)
