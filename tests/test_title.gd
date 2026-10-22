## A tela de título (#28): o jogo abre nela; Continuar só com um save que abre e leva à Estação ou à rua da expedição;
## Nova campanha escolhe o espaço (#34) e pergunta antes de sobrescrever um ocupado; Campanhas abre outro espaço;
## Opções abre e Voltar fecha; teclado e controle andam pelos botões; o ícone e a splash do projeto. Usa uma pasta de
## save própria e devolve a campanha de antes.
extends RefCounted

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var real_slot: int = Campaign.slot
	Campaign.save_dir = "user://test-title-%d" % Time.get_ticks_usec()
	Campaign.slot = 1

	_project()
	await _options_without_save()
	await _without_save()
	await _with_save()
	await _new_campaign_asks()
	await _options_and_keys()
	await _broken_save()
	await _continue_expedition()
	await _other_slot()

	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	_clear_saves()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state
	Campaign.slot = real_slot


func _project() -> void:
	t.equal(GameFlow.scene_path("title"), "res://scenes/title.tscn", "a cena de título está no GameFlow")
	for key in ["application/config/icon", "application/boot_splash/image"]:
		var path := String(ProjectSettings.get_setting(key, ""))
		t.check(path.begins_with("res://art/ui/title/") and ResourceLoader.exists(path), "%s aponta para a arte do título (%s)" % [key, path])
	var presets := ConfigFile.new()
	t.equal(presets.load("res://export_presets.cfg"), OK, "export_presets.cfg abre")
	t.equal(presets.get_value("preset.0.options", "application/icon", ""), "res://art/ui/title/app_icon.png", "o ícone no preset do Windows")
	t.equal(presets.get_value("preset.1.options", "html/export_icon", false), true, "a Web exporta o ícone do projeto")


## Sem save, mexer nas Opções do título não cria save; a campanha nova leva o que foi mexido.
func _options_without_save() -> void:
	_clear_saves()
	Campaign.state = Campaign.create_initial(10)
	var title := await _open_title()
	if title == null:
		return
	title.options_button.pressed.emit()
	await _frames(2)
	_press(title._modal, "2x")
	await _frames(2)
	for slider in title._modal.find_children("*", "HSlider", true, false):
		slider.value = 0.2
		slider.drag_ended.emit(true)
		slider.focus_exited.emit()
	await _frames(2)
	t.check(not Campaign.has_save(), "as Opções do título sem campanha não gravam save")
	title.close_modal()
	await _frames(2)
	t.equal(_texts(title._buttons), ["Nova campanha", "Opções"], "depois das Opções, ainda sem Continuar")
	title.new_button.pressed.emit()
	await _frames(2)
	t.check(not title.modal_open(), "sem save, Nova campanha não pergunta")
	t.check(await _settles_on("Station"), "e vai para a Estação")
	t.equal(int(Campaign.state.settings.battle_speed), 2, "a campanha nova leva a velocidade escolhida no título")
	var saved = Campaign.read_file(Campaign.primary_path())
	t.check(saved != null and int(saved.settings.battle_speed) == 2, "e grava com ela")


## Sem save: o jogo abre no título, sem Continuar; Nova campanha é o primeiro botão e começa direto (sem pergunta).
func _without_save() -> void:
	_clear_saves()
	Campaign.state = Campaign.create_initial(11)
	var title := await _open_title()
	if title == null:
		return
	t.check(title.continue_button == null, "sem save, não há Continuar")
	t.equal(_texts(title._buttons), ["Nova campanha", "Opções"], "sem save: Nova campanha e Opções")
	title.new_button.pressed.emit()
	t.check(await _settles_on("Station"), "Nova campanha sem save vai direto para a Estação")
	t.check(Campaign.has_valid_save(), "e grava a campanha nova")


## Com save: Continuar é o primeiro e leva à Estação com a campanha do save.
func _with_save() -> void:
	Campaign.new_game(12)
	var before: Dictionary = Campaign.state.duplicate(true)
	var title := await _open_title()
	if title == null:
		return
	t.check(title.continue_button != null, "com save, há Continuar")
	t.check(title.get_viewport().gui_get_focus_owner() == title.continue_button, "o foco começa no Continuar")
	t.equal(_texts(title._buttons), ["Continuar", "Nova campanha", "Opções"], "com save: Continuar, Nova campanha e Opções")
	title.continue_button.pressed.emit()
	t.check(await _settles_on("Station"), "Continuar leva à Estação")
	t.equal(Campaign.state.roster.map(func(h): return h.id), before.roster.map(func(h): return h.id), "Continuar mantém a campanha do save")


## Nova campanha com save abre os espaços; o ocupado pergunta antes: Cancelar volta sem mexer; Começar do zero troca a
## campanha daquele espaço.
func _new_campaign_asks() -> void:
	Campaign.new_game(13)
	Campaign.state.inventory.seeds = 777
	Campaign.save()
	var title := await _open_title()
	if title == null:
		return
	title.new_button.pressed.emit()
	await _frames(2)
	t.check(title.modal_open() and title._modal.find_child("Slot1", true, false) != null, "com save, Nova campanha mostra os espaços")
	t.check(not title._buttons.visible, "os botões do título somem atrás da janela")
	var slots: Array = [1, 2, 3].map(func(n): return title._modal.find_child("Slot%d" % n, true, false).text)
	t.check(slots[0].contains("Ciclo") and slots[1].contains("vazio") and slots[2].contains("vazio"), "o espaço 1 com o resumo e os outros vazios %s" % [slots])
	_press_name(title._modal, "Slot1")
	await _frames(2)
	t.check(title._modal.find_children("*", "Label", true, false).any(func(l): return l.text.contains("espaço 1")), "o espaço ocupado pede confirmação")
	_press(title._modal, "Cancelar")
	await _frames(2)
	t.check(not title.modal_open() and title._buttons.visible, "Cancelar fecha a confirmação")
	t.equal(int(Campaign.state.inventory.seeds), 777, "Cancelar não mexe na campanha")
	title.new_button.pressed.emit()
	await _frames(2)
	_press_name(title._modal, "Slot1")
	await _frames(2)
	_press(title._modal, "Começar do zero")
	t.check(await _settles_on("Station"), "Começar do zero vai para a Estação")
	t.check(int(Campaign.state.inventory.seeds) != 777, "Começar do zero troca a campanha")
	var saved = Campaign.read_file(Campaign.primary_path())
	t.check(saved != null and int(saved.inventory.seeds) != 777, "e grava a campanha nova por cima")


## Opções abre as opções de verdade e Voltar fecha; as setas andam pelos botões e Interagir aperta o do foco.
func _options_and_keys() -> void:
	Campaign.new_game(14)
	var title := await _open_title()
	if title == null:
		return
	title.options_button.pressed.emit()
	await _frames(2)
	t.check(title.modal_open() and not title._modal.find_children("*", "AHOptionsPanel", true, false).is_empty(), "Opções abre o painel de opções")
	await _action("cancel")
	t.check(not title.modal_open(), "Voltar fecha as Opções")
	AHUiStyle.using_keys = true
	await _frames(3)
	t.check(title.get_viewport().gui_get_focus_owner() == title.options_button, "fechadas as Opções, o foco volta a elas")
	await _action("ui_up")
	t.check(title.get_viewport().gui_get_focus_owner() == title.new_button, "↑ leva à Nova campanha")
	await _action("ui_up")
	t.check(title.get_viewport().gui_get_focus_owner() == title.continue_button, "↑ leva ao Continuar")
	await _action("ui_down")
	await _action("ui_down")
	t.check(title.get_viewport().gui_get_focus_owner() == title.options_button, "↓ ↓ volta às Opções")
	await _action("interact")
	t.check(title.modal_open(), "Interagir aperta o botão com foco (abre as Opções)")
	await _action("cancel")
	await _frames(2)
	t.check(title.get_viewport().gui_get_focus_owner() == title.options_button, "ao fechar, o foco volta às Opções")
	AHUiStyle.using_keys = false
	# Saindo pelo Continuar, a tela não aceita mais nada (o clique seguinte não abre a confirmação).
	title.continue_button.pressed.emit()
	title.new_button.pressed.emit()
	await _frames(1)
	t.check(not title.modal_open(), "depois do Continuar, Nova campanha não faz nada")
	t.check(await _settles_on("Station"), "e o Continuar segue para a Estação")


## Save estragado: sem Continuar (o jogo não continua de um arquivo que não abre).
func _broken_save() -> void:
	_clear_saves()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	var file := FileAccess.open(Campaign.primary_path(), FileAccess.WRITE)
	file.store_string("{ isto não é um save")
	file.close()
	t.check(Campaign.has_save() and not Campaign.has_valid_save(), "o arquivo existe mas não abre")
	var title := await _open_title()
	if title == null:
		return
	t.check(title.continue_button == null, "save estragado não mostra Continuar")
	title.options_button.pressed.emit()
	await _frames(2)
	_press(title._modal, "2x")
	await _frames(2)
	t.equal(FileAccess.get_file_as_string(Campaign.primary_path()), "{ isto não é um save", "as Opções não regravam o save que não abre")
	title.close_modal()
	await _frames(2)
	title.new_button.pressed.emit()
	await _frames(2)
	t.check(title._modal.find_child("Slot1", true, false).text.contains("não abre"), "o espaço com o save estragado diz que não abre")
	_press_name(title._modal, "Slot1")
	await _frames(2)
	t.check(title.modal_open(), "com um save que não abre, Nova campanha pergunta antes")
	var texts: Array = title._modal.find_children("*", "Label", true, false).map(func(l): return l.text)
	t.check(texts.any(func(x): return String(x).contains("não pôde ser aberto")), "e diz que o save não abre")
	_press(title._modal, "Cancelar")
	await _frames(2)
	t.equal(FileAccess.get_file_as_string(Campaign.primary_path()), "{ isto não é um save", "Cancelar não mexe no arquivo")


## Continuar no meio de uma expedição leva à rua.
func _continue_expedition() -> void:
	Campaign.state = Campaign.create_initial(15)
	AHJourneyRules.start_expedition(Campaign.state, "fase_1", 77)
	Campaign.save()
	var title := await _open_title()
	if title == null:
		return
	title.continue_button.pressed.emit()
	t.check(await _settles_on("Street"), "Continuar com a expedição em andamento leva à rua")


## Duas campanhas: Campanhas aparece e abre a do outro espaço; um espaço vazio começa sem perguntar.
func _other_slot() -> void:
	_clear_saves()
	Campaign.new_game_in(2, 21)
	var second: Array = Campaign.state.roster.map(func(h): return h.perks)
	Campaign.new_game_in(1, 22)
	var title := await _open_title()
	if title == null:
		return
	t.equal(_texts(title._buttons), ["Continuar", "Nova campanha", "Campanhas", "Opções"], "com duas campanhas, há Campanhas")
	title.load_button.pressed.emit()
	await _frames(2)
	t.check(title._modal.find_child("Slot3", true, false).disabled, "o espaço vazio não abre")
	t.check(title._modal.find_child("Slot1", true, false).text.contains("último usado"), "o último usado está marcado")
	_press_name(title._modal, "Slot2")
	t.check(await _settles_on("Station"), "escolher o espaço 2 vai para a Estação")
	t.equal(Campaign.slot, 2, "no espaço 2")
	t.equal(Campaign.state.roster.map(func(h): return h.perks), second, "com a campanha dele")
	title = await _open_title()
	if title == null:
		return
	title.new_button.pressed.emit()
	await _frames(2)
	_press_name(title._modal, "Slot3")
	t.check(await _settles_on("Station"), "o espaço vazio começa direto")
	t.check(Campaign.slot == 3 and Campaign.slot_summary(3).status == "ok", "e grava no espaço 3")
	t.equal(Campaign.slot_summary(2).status, "ok", "o espaço 2 continua lá")


# ---------------------------------------------------------------- apoio

func _press_name(scope: Node, name: String) -> void:
	var button := scope.find_child(name, true, false) as Button
	if t.check(button != null and not button.disabled, "botão %s" % name):
		button.pressed.emit()


func _open_title() -> AHTitleScreen:
	GameFlow.start()
	if not await _settles_on("Title"):
		t.check(false, "o jogo abre na tela de título")
		return null
	await _frames(2)
	return _tree.current_scene as AHTitleScreen


func _settles_on(scene_name: String) -> bool:
	for frame in 300:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == scene_name and frame > 3:
			return true
	return false


func _texts(box: Node) -> Array:
	return box.get_children().filter(func(c): return c is Button and not c.is_queued_for_deletion()).map(func(c): return c.text)


func _press(scope: Node, text: String) -> void:
	for button in scope.find_children("*", "Button", true, false):
		if button.text == text:
			button.pressed.emit()
			return
	t.check(false, "botão %s" % text)


func _action(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame


func _clear_saves() -> void:
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
