## Fechar o jogo não prende som (#66): o Sound para os tocadores, solta os streams e espera o servidor de áudio
## descartá-los antes de fechar. Roda o fechamento num processo à parte (tests/sound_exit_probe.gd) e confere que o
## Godot não avisa de instância nem de recurso preso na saída.
extends RefCounted


func run(t) -> void:
	var output: Array = []
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tests/sound_exit_probe.gd"]
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	var text := "\n".join(output)
	if not t.check(code == 0 and text.contains("PROBE fechando"), "o fechamento roda (código %d)" % code):
		print(text)
		return
	t.check(not text.contains("leaked at exit"), "nenhuma instância presa na saída")
	t.check(not text.contains("still in use at exit"), "nenhum som preso na saída")
	t.check(Engine.get_main_loop().auto_accept_quit == false, "fechar a janela passa pelo Sound.quit")
