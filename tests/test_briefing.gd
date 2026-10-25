## Briefing e debriefing com retrato (#88).
## - Os dados: cada fase tem duas ou três falas antes e uma na vitória; a retirada e a queda têm a delas; quem fala
##   existe (herói fundador ou morador da Estação); cada texto tem a versão em inglês.
## - Quem fala: o primeiro da lista que pode (o morador que mora na Estação; o herói que vai, ou que voltou vivo), sem
##   o mesmo duas vezes seguidas; sem ninguém, a fala sai. A fuga e a queda sem ninguém de volta têm a fala delas.
## - A caixa: a ordem das falas, Próximo e Partir na última, Pular, Interagir e Voltar, o clique e o toque na caixa (o
##   toque de verdade, com o clique emulado, passa uma fala só), a carência também nos botões.
## - Na Estação: Partir abre o briefing e só depois parte (pular também parte; Voltar fica na Preparação); a chegada
##   mostra o debriefing antes do relatório.
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")
const FOUNDERS := ["hero_cao_bento", "hero_gato_nick", "hero_sapo_iris", "hero_coruja_vespera"]

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-briefing-%d" % Time.get_ticks_usec()
	var tips: bool = Tips.enabled
	Tips.enabled = false
	_data()
	_speakers()
	await _dialog()
	await _station()
	Tips.enabled = tips
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


func _data() -> void:
	var data := AHBriefing.data()
	var english: Translation = load("res://data/i18n/en.po")
	var known := FOUNDERS + S.CIVILIANS.map(func(c): return c.id)
	var texts: Array = []
	for phase in AHJourneyRules.PHASES:
		var row: Dictionary = data.get(phase.id, {})
		var count: int = row.get("Briefing", []).size()
		t.check(count >= 2 and count <= 3, "%s: duas ou três falas no briefing (%d)" % [phase.id, count])
		t.check(String(row.get("Debriefing", {}).get("Text", "")) != "", "%s: a fala da vitória" % phase.id)
		texts += row.get("Briefing", []) + [row.get("Debriefing", {})]
	for result in ["retreat", "fled", "defeat", "defeat_none"]:
		t.check(String(data.get(result, {}).get("Debriefing", {}).get("Text", "")) != "", "a fala da volta: %s" % result)
		texts.append(data.get(result, {}).get("Debriefing", {}))
	var unknown: Array = []
	var untranslated: Array = []
	for entry in texts:
		if entry.get("Speakers", []).is_empty() or entry.Speakers.any(func(id): return not known.has(id)):
			unknown.append(entry.get("Text", ""))
		if english.get_message(String(entry.get("Text", ""))) == "":
			untranslated.append(entry.get("Text", ""))
	t.check(unknown.is_empty(), "quem fala é fundador ou morador: %s" % [unknown])
	t.check(untranslated.is_empty(), "cada fala tem a versão em inglês: %s" % [untranslated])


func _speakers() -> void:
	var c: Dictionary = Campaign.create_initial(88)
	c.station.residents = []
	var lines := AHBriefing.departure(c, "fase_1", FOUNDERS)
	t.equal(lines.map(func(l): return l.speaker.id), ["hero_cao_bento", "hero_sapo_iris", "hero_gato_nick"], "sem a Dora na Estação, o Bento fala por ela; a ordem das falas")
	t.check(lines[0].text.begins_with("A despensa") and not lines[0].speaker.art.is_empty(), "com o texto e o retrato de quem fala")
	c.station.residents = [S.DORA]
	lines = AHBriefing.departure(c, "fase_1", FOUNDERS)
	t.equal(lines[0].speaker.id, S.DORA, "com a Dora na Estação, ela fala")
	t.check(lines[0].speaker.role == "Cozinheira" and not lines[0].speaker.art.is_empty(), "a Dora com o papel e o retrato")
	# Quem não vai não fala em primeira pessoa: a fase 3 sem o Nick.
	lines = AHBriefing.departure(c, "fase_3", ["hero_cao_bento", "hero_sapo_iris", "hero_coruja_vespera"])
	t.check(not lines.any(func(l): return l.speaker.id == "hero_gato_nick"), "quem fica na Estação não diz \"eu vou na frente\"")
	# Sem a Cora, a Íris não fala duas vezes seguidas.
	var ids: Array = lines.map(func(l): return l.speaker.id)
	var twice := false
	for i in range(1, ids.size()):
		twice = twice or ids[i] == ids[i - 1]
	t.check(not twice, "ninguém fala duas vezes seguidas: %s" % [ids])
	S.hero(c, "hero_sapo_iris").alive = false
	lines = AHBriefing.departure(c, "fase_1", FOUNDERS)
	t.equal(lines.size(), 2, "sem a Íris viva, a fala dela sai")
	S.hero(c, "hero_sapo_iris").alive = true
	# Na volta, só fala quem voltou vivo.
	t.equal(AHBriefing.debriefing(c, {"result": "victory", "phase_id": "fase_2", "team": ["hero_cao_bento", "hero_gato_nick"]}), [], "a vitória da fase 2 é a fala da Íris: sem ela na equipe, nada")
	t.equal(AHBriefing.debriefing(c, {"result": "victory", "phase_id": "fase_1", "team": FOUNDERS})[0].speaker.id, S.DORA, "a fala da vitória")
	t.equal(AHBriefing.debriefing(c, {"result": "retreat", "phase_id": "fase_1", "team": ["hero_gato_nick", "hero_cao_bento"]})[0].speaker.id, "hero_cao_bento", "a fala da retirada, de quem voltou")
	t.equal(AHBriefing.debriefing(c, {"result": "retreat", "phase_id": "fase_1", "team": ["hero_gato_nick"]})[0].speaker.id, "hero_gato_nick", "sem o Bento na equipe, outro que voltou")
	var fled := AHBriefing.debriefing(c, {"result": "fled", "phase_id": "fase_1", "team": FOUNDERS})
	t.check(fled.size() == 1 and not fled[0].text.contains("chegou"), "a fuga tem a fala dela, sem prometer achado (na fuga, nada chega)")
	S.hero(c, "hero_cao_bento").alive = false
	t.equal(AHBriefing.debriefing(c, {"result": "defeat", "phase_id": "fase_1", "team": ["hero_cao_bento", "hero_gato_nick"]})[0].speaker.id, "hero_gato_nick", "a queda: quem voltou fala")
	var none := AHBriefing.debriefing(c, {"result": "defeat", "phase_id": "fase_1", "team": ["hero_cao_bento"]})
	t.check(none.size() == 1 and none[0].speaker.id == S.DORA and none[0].text.begins_with("Ninguém desceu"), "ninguém voltou: a Dora, com a fala de ninguém de volta")
	c.station.residents = []
	t.equal(AHBriefing.debriefing(c, {"result": "defeat", "phase_id": "fase_1", "team": ["hero_cao_bento"]}), [], "sem ninguém de volta nem morador, nada")
	AHBriefing.enabled = false
	t.equal(AHBriefing.departure(c, "fase_1", FOUNDERS), [], "desligado (os testes de outras telas), nada")
	AHBriefing.enabled = true


func _dialog() -> void:
	var c: Dictionary = Campaign.create_initial(88)
	var lines := AHBriefing.departure(c, "fase_1", FOUNDERS)
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tree.root.add_child(host)
	# Próximo e Partir.
	var dialog := AHBriefingDialog.open(host, lines, "Partir")
	var result := [null]
	dialog.finished.connect(func(skipped): result[0] = skipped)
	await _frames(2)
	t.equal(dialog._text.text, lines[0].text, "abre na primeira fala")
	t.equal(dialog._name.text, "Bento", "com o nome de quem fala")
	t.check(dialog._face.get_child_count() == 1, "e o retrato")
	t.equal(dialog.next_button.text, "Próximo", "o botão Próximo")
	dialog.next_button.pressed.emit()
	t.equal(dialog._text.text, lines[1].text, "Próximo passa à segunda fala")
	# Interagir (E, o A do controle) passa; logo que abre, a carência segura o toque de antes.
	await _wait_guard(dialog)
	await _press("interact")
	t.equal(dialog.index, 2, "Interagir passa à terceira fala")
	t.equal(dialog.next_button.text, "Partir", "na última, o botão de quem chamou")
	t.check(not dialog.skip_button.visible, "e sem Pular")
	dialog.next_button.pressed.emit()
	await _frames(1)
	t.equal(result[0], false, "Partir na última fecha sem pular")
	# A carência: o toque logo que abre não passa a fala.
	dialog = AHBriefingDialog.open(host, lines, "Partir")
	result = [null]
	dialog.finished.connect(func(skipped): result[0] = skipped)
	await _frames(1)
	await _press("interact")
	t.equal(dialog.index, 0, "o toque logo que a caixa abre não passa a fala")
	await _wait_guard(dialog)
	# O clique e o toque na caixa passam a fala.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	dialog._on_box_input(click)
	t.equal(dialog.index, 1, "o clique na caixa passa a fala")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	dialog._on_box_input(touch)
	t.equal(dialog.index, 2, "o toque também")
	dialog.queue_free()
	await _frames(1)
	# O toque de verdade (com o clique que a Godot emula dele) pela tela: uma fala só. Na carência, os botões esperam.
	dialog = AHBriefingDialog.open(host, lines, "Partir")
	await _frames(1)
	t.check(dialog.next_button.disabled and dialog.skip_button.disabled, "na carência, os botões esperam")
	await _wait_guard(dialog)
	await _frames(2)
	t.check(not dialog.next_button.disabled, "e depois dela, valem")
	# Em coordenadas da janela (a tela de 1920 esticada para o tamanho dela).
	var at: Vector2 = _tree.root.get_final_transform() * dialog._text.get_global_rect().get_center()
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.position = at
	emulated.global_position = at
	emulated.pressed = true
	var real_touch := InputEventScreenTouch.new()
	real_touch.position = at
	real_touch.pressed = true
	_tree.root.push_input(emulated)
	_tree.root.push_input(real_touch)
	await _frames(1)
	t.equal(dialog.index, 1, "um toque de verdade passa uma fala só")
	dialog.queue_free()
	await _frames(1)
	# Voltar (Esc, B) e Pular pulam.
	dialog = AHBriefingDialog.open(host, lines, "Partir")
	result = [null]
	dialog.finished.connect(func(skipped): result[0] = skipped)
	var cancelled := [null]
	dialog.finished.connect(func(_s): cancelled[0] = dialog.cancelled)
	await _wait_guard(dialog)
	await _press("ui_cancel")
	t.check(result[0] == true and cancelled[0] == false, "Voltar pula (no debriefing)")
	dialog = AHBriefingDialog.open(host, lines, "Partir")
	dialog.cancel_on_back = true
	result = [null]
	dialog.finished.connect(func(skipped): result[0] = skipped)
	dialog.finished.connect(func(_s): cancelled[0] = dialog.cancelled)
	await _wait_guard(dialog)
	await _press("ui_cancel")
	t.check(result[0] == true and cancelled[0] == true, "no briefing, Voltar desiste")
	dialog = AHBriefingDialog.open(host, lines, "Partir")
	result = [null]
	dialog.finished.connect(func(skipped): result[0] = skipped)
	await _frames(2)
	dialog.skip_button.pressed.emit()
	t.equal(result[0], true, "Pular pula")
	host.queue_free()
	await _frames(1)


## Na Estação: o Partir da Preparação abre o briefing e só parte depois dele; a chegada mostra o debriefing antes do
## relatório.
func _station() -> void:
	Campaign.state = Campaign.create_initial(88)
	Campaign.save()
	GameFlow.change_to("station", {}, false)
	await _settle()
	var station = _tree.current_scene
	if not t.check(station != null and station.name == "Station", "a Estação abre"):
		return
	var hud: AHRefugeHud = station.hud
	var team: Array = Campaign.state.roster.slice(0, 4).map(func(h): return h.id)
	hud._draft = {"phase": "fase_1", "team": team, "focus": "", "extra": 0}
	# Voltar no briefing fica na Preparação, sem partir.
	hud._depart()
	await _frames(2)
	if t.check(hud.briefing_open(), "Partir abre o briefing"):
		await _wait_guard(hud.briefing)
		await _press("ui_cancel")
		await _frames(3)
		t.check(not hud.briefing_open() and Campaign.state.session.expedition == null and not hud._draft.is_empty(), "Voltar no briefing fica na Preparação, sem partir")
	hud._depart()
	await _frames(2)
	t.check(hud.briefing_open(), "Partir de novo abre o briefing")
	t.equal(Campaign.state.session.expedition, null, "a expedição ainda não começou")
	hud._depart()
	t.equal(_tree.root.find_children("Briefing", "AHBriefingDialog", true, false).size(), 1, "o segundo Partir não abre outro")
	hud.briefing.skip()
	for i in 600:
		if GameFlow.passage != null or GameFlow.current_id == "street":
			break
		await _tree.process_frame
	t.check(Campaign.state.session.expedition != null and Campaign.state.session.expedition.phase_id == "fase_1", "pulado, a equipe parte para a fase 1")
	await _settle()
	# A volta: a vitória da fase 1, a chegada e o debriefing antes do relatório.
	var c: Dictionary = Campaign.state
	c.session.result = "victory"
	S.finish_return(c)
	Campaign.save()
	GameFlow.change_to("station", {}, false)
	await _settle()
	station = _tree.current_scene
	hud = station.hud
	if not t.check(hud.current == AHRefugeHud.ARRIVAL, "a volta começa com a chegada"):
		return
	station.finish_team_arrival()
	for i in 900:
		if hud.briefing_open() or hud.current == "report":
			break
		await _tree.process_frame
	if not t.check(hud.briefing_open(), "depois da chegada, o debriefing"):
		return
	t.equal(hud.current, AHRefugeHud.ARRIVAL, "o relatório espera o debriefing")
	t.equal(hud.briefing.next_button.text, "Ver o relatório", "com Ver o relatório")
	hud.briefing.next_button.pressed.emit()
	for i in 300:
		if hud.current == "report":
			break
		await _tree.process_frame
	t.equal(hud.current, "report", "e o relatório abre")


func _wait_guard(dialog: AHBriefingDialog) -> void:
	while dialog.guarded():
		await _tree.process_frame


func _press(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		_tree.root.push_input(event)
		await _tree.process_frame


func _settle() -> void:
	for frame in 900:
		await _tree.process_frame
		if not GameFlow.busy and GameFlow.passage == null and _tree.current_scene != null and frame > 3:
			break
	await _frames(3)


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
