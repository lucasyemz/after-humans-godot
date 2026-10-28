## O aviso do alto da exploração fica justo ao texto: um aviso que quebra em duas linhas, logo depois de um curto, não
## mede a altura com a largura velha do rótulo (no texto Maior, a chapa saía alta e meio vazia, cobrindo o achado). E a
## frase mantida (hold_line) vai na frente dos avisos seguintes até completar o tempo dela.
extends RefCounted

const LONG := "Armário de manutenção: +1 curativo, +1 comida. A equipe recupera o fôlego."


func run(t) -> void:
	var tree: SceneTree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var real_size: int = Settings.text_size
	Campaign.save_dir = "user://test-toast-fit-%d" % Time.get_ticks_usec()
	Campaign.state = Campaign.create_initial(9)
	AHJourneyRules.start_expedition(Campaign.state, "fase_1", 9)
	GameFlow.change_to("street", {}, false)
	var street: Node = null
	for frame in 600:
		await tree.process_frame
		if not GameFlow.busy and tree.current_scene != null and tree.current_scene.name == "Street" and frame > 3:
			street = tree.current_scene
			break
	if t.check(street != null, "a rua abre"):
		var hud: AHExplorationHud = street.exploration_hud
		for size in [0, 2]:
			Settings.set_text_size(size)
			await tree.process_frame
			hud.toast("Trecho 5 · Suprimentos", 2.5)
			await tree.process_frame
			hud.toast(LONG, 3.5)
			var label: Label = hud._toast_label
			var text_height: float = label.get_line_count() * label.get_line_height()
			t.check(hud._toast.size.y <= text_height + 40.0, "tamanho de texto %d: a chapa do aviso justa ao texto (%.0f px para %d linhas de %.0f)" % [
				size, hud._toast.size.y, label.get_line_count(), text_height])
		# A frase mantida (o fôlego do tutorial) vai na frente dos avisos que chegam em seguida, até completar o tempo dela.
		hud.hold_line("Linha mantida.", 6.0)
		hud.toast("Outro aviso.", 2.5)
		t.equal(hud._toast_label.text, "Linha mantida. Outro aviso.", "a frase mantida vai na frente do aviso seguinte")
		hud.toast("Linha mantida. Já com ela.", 2.5)
		t.equal(hud._toast_label.text, "Linha mantida. Já com ela.", "e não se repete num aviso que já começa com ela")
		hud._held_until = Time.get_ticks_msec() - 1
		hud.toast("Depois do tempo.", 2.5)
		t.equal(hud._toast_label.text, "Depois do tempo.", "passado o tempo dela, o aviso vem sozinho")
		tree.unload_current_scene()
		await tree.process_frame
	Settings.set_text_size(real_size)
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state
