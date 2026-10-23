## A tradução (#35): o jogo abre em português (a chave é o próprio texto, então nada muda); todo texto de tela das telas
## convertidas está em data/i18n/en.po (ou na lista do que não é texto) e o texto formatado passa por tr() antes do %;
## cada tradução guarda os marcadores (%s, %d) da original; os nomes e as descrições dos dados têm chave; e trocar para o
## inglês nas Opções muda as telas convertidas na hora.
extends RefCounted

const Scan := preload("res://tools/i18n_scan.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_language: String = Settings.language
	_portuguese_default()
	var po := Scan.read_po()
	_screens_in_table(po)
	_placeholders(po)
	_data_keys(po)
	await _switch_live()
	Settings.set_language(real_language)


func _portuguese_default() -> void:
	t.equal(ProjectSettings.get_setting("internationalization/locale/fallback", ""), "pt_BR", "o português é o idioma de reserva")
	t.check(Array(ProjectSettings.get_setting("internationalization/locale/translations", [])).has(Scan.PO), "o en.po está nas traduções do projeto")
	t.check(load(Scan.PO) is Translation, "o en.po abre como tradução")
	Settings.set_language("pt_BR")
	t.check(TranslationServer.get_locale().begins_with("pt"), "o jogo abre em português")
	for text in ["Continuar", "Nova campanha", "Vez de %s: escolha uma habilidade (1–4) ou uma ação."]:
		t.equal(TranslationServer.translate(text), text, "em português, '%s' fica igual" % text)
	t.equal(Settings._known_language("fr"), "pt_BR", "idioma desconhecido volta ao português")
	# O leitor acha a palavra solta minúscula e os marcadores com sinal.
	t.check(Scan.looks_like_text("vazio") and Scan.looks_like_text("de"), "palavra solta minúscula conta como texto")
	t.check(not Scan.looks_like_text("res://audio/ui/click.ogg") and not Scan.looks_like_text("move_left"), "caminho e id não contam")
	t.equal(Scan.placeholders("%s · +%d de vida, %+d de instinto"), ["%s", "%d", "%+d"], "o marcador %+d também conta")


## Todo texto de tela das telas convertidas está no PO (ou na lista do que não é texto); com %, passa por tr().
func _screens_in_table(po: Dictionary) -> void:
	var ignored := Scan.ignored()
	var outside: Array = []
	var unwrapped: Array = []
	var screen := 0
	for path in Scan.CONVERTED:
		var file: String = path.get_file()
		for found in Scan.screen_texts(path):
			if not found.wrapped and Scan.is_ignored(ignored, file, found.text):
				continue
			screen += 1
			# As obsoletas (#~) não contam: a Godot as ignora e o texto sairia em português.
			if not po.has(found.text) or po[found.text].obsolete:
				outside.append("%s:%d %s" % [file, found.line, found.text])
			elif not Scan.placeholders(found.text).is_empty() and not found.wrapped:
				unwrapped.append("%s:%d %s" % [file, found.line, found.text])
	t.check(screen > 300, "as telas convertidas têm os textos de tela (%d)" % screen)
	t.check(outside.is_empty(), "nenhum texto de tela fora do PO (rode tools/i18n_update.gd e traduza): %s" % [outside])
	t.check(unwrapped.is_empty(), "o texto formatado passa por tr() antes do %%: %s" % [unwrapped])
	# A lista do que não é texto não guarda sobra: cada linha ainda aparece no arquivo dela.
	var stale: Array = []
	for entry in ignored:
		var cut: int = entry.find(": ")
		var file: String = entry.substr(0, cut)
		var text: String = entry.substr(cut + 2)
		var paths: Array = Scan.CONVERTED.filter(func(c): return file == "*" or c.get_file() == file)
		if paths.is_empty() or not paths.any(func(p): return Scan.screen_texts(p).any(func(f): return f.text == text)):
			stale.append(entry)
	t.check(stale.is_empty(), "tools/i18n_ignore.txt sem linhas que sobraram: %s" % [stale])


## Cada tradução guarda os marcadores da original (um %d a menos quebra a formatação em inglês).
func _placeholders(po: Dictionary) -> void:
	var broken: Array = []
	var screen_done := 0
	var screen_total := 0
	var data_done := 0
	var data_total := 0
	for id in po:
		var entry: Dictionary = po[id]
		if entry.obsolete:
			continue
		var from_data: bool = entry.refs.all(func(r): return not String(r).contains(".gd:"))
		if from_data:
			data_total += 1
			data_done += 1 if entry.str != "" else 0
		else:
			screen_total += 1
			screen_done += 1 if entry.str != "" else 0
		if entry.str != "" and Scan.placeholders(entry.str) != Scan.placeholders(id):
			broken.append(id)
	t.check(broken.is_empty(), "as traduções guardam os marcadores: %s" % [broken])
	t.equal(screen_done, screen_total, "as telas convertidas estão traduzidas (%d de %d)" % [screen_done, screen_total])
	t.note("telas %d/%d traduzidas; dados %d/%d" % [screen_done, screen_total, data_done, data_total])


## Os nomes e as descrições dos dados têm chave no PO (os ids não mudam).
func _data_keys(po: Dictionary) -> void:
	var texts := Scan.data_texts()
	t.check(texts.size() > 150, "os dados têm textos (%d)" % texts.size())
	var missing: Array = texts.filter(func(f): return not po.has(f.text) or po[f.text].obsolete).map(func(f): return f.where)
	t.check(missing.is_empty(), "todo nome e descrição dos dados tem chave: %s" % [missing.slice(0, 10)])
	t.check(GameData.row("classes", "cao") != null, "os ids continuam os mesmos")


## Inglês nas Opções: o título e as Opções mudam na hora; de volta ao português, ficam como antes.
func _switch_live() -> void:
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var real_slot: int = Campaign.slot
	Campaign.save_dir = "user://test-i18n-%d" % Time.get_ticks_usec()
	Campaign.slot = 1
	Campaign.state = Campaign.create_initial(5)
	Settings.set_language("en")
	t.check(TranslationServer.get_locale().begins_with("en"), "o inglês liga")
	t.equal(TranslationServer.translate("Vez de %s: escolha uma habilidade (1–4) ou uma ação.") % "Nick", "Nick's turn: pick an ability (1–4) or an action.", "o texto formatado sai traduzido")
	# Os nomes dos inimigos na luta, inclusive com o sufixo da rota (o guardião, os relés do chefe), e o nome curto.
	t.equal(AHCombatHud.unit_name("Robô"), "Robot", "o nome do inimigo em inglês")
	t.equal(AHCombatHud.unit_name("Robô · Guardião"), "Robot · Guardian", "o guardião em inglês")
	t.equal(AHCombatHud.unit_name("Relé de Defesa Alfa"), "Defense Relay Alpha", "o relé do chefe em inglês")
	t.equal(AHCombatHud.unit_name("Nick"), "Nick", "o nome do herói não muda")
	t.equal(AHCombatHud.short_name("O Porteiro"), "Gatekeeper", "o nome curto sem o artigo")
	GameFlow.start()
	var title: AHTitleScreen = null
	for frame in 300:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene is AHTitleScreen and frame > 3:
			title = _tree.current_scene
			break
	if t.check(title != null, "o título abre"):
		await _tree.process_frame
		t.equal(title.new_button.text, "New campaign", "o título em inglês")
		title.options_button.pressed.emit()
		await _tree.process_frame
		var texts: Array = title._modal.find_children("*", "Label", true, false).map(func(l): return l.text)
		t.check(texts.has("Options") and texts.has("Language"), "as Opções em inglês")
		var buttons: Array = title._modal.find_children("*", "Button", true, false).map(func(b): return b.text)
		t.check(buttons.any(func(b): return String(b).contains("English (beta)")), "o idioma escolhido aparece marcado")
		title.close_modal()
		Settings.set_language("pt_BR")
		title._build_buttons()
		await _tree.process_frame
		t.equal(title.new_button.text, "Nova campanha", "de volta ao português")
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state
	Campaign.slot = real_slot
