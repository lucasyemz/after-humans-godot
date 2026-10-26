## As telas da Estação no kit (#105, docs/design/hud-estacao.md), com os cômodos recuperados (a Forja e a Pesquisa no
## nível 1, o Depósito no 2), os três civis morando e a noite e o trem pendentes, no Normal, no Maior e em inglês:
## - o painel do cômodo fica no lugar dele (596 de largura, de x 1296 a 1892) e acima do botão principal, em todos;
## - o texto das PENDÊNCIAS fica dentro do botão dele (o Maior e o inglês quebram a linha);
## - os cartões da Preparação seguram o conteúdo inteiro (o aviso de baixo é parte do cartão);
## - em inglês, as abas e o botão principal estão traduzidos.
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")
const J := preload("res://scripts/flow/journey_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	var locale := TranslationServer.get_locale()
	Tips.enabled = false
	Campaign.save_dir = "user://test-station-screens-%d" % Time.get_ticks_usec()
	await _screens()
	Tips.enabled = tips
	Settings.set_text_size(0)
	TranslationServer.set_locale(locale)
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


func _screens() -> void:
	var c: Dictionary = Campaign.create_initial(31)
	for room in [S.FORGE, S.RESEARCH, S.CANTEEN, S.BAR, S.DORMITORY]:
		c.station.rooms[room] = 1
	c.station.rooms[S.DEPOT] = 2
	c.station.residents = [S.DORA, S.OTTO, S.CORA]
	c.inventory.scrap = 9
	c.inventory.fragments = 3
	# A volta: a noite fica pendente no Dormitório e o trem espera na plataforma.
	J.start_expedition(c, "fase_1", 77)
	c.session.result = "victory"
	S.finish_return(c)
	c.station.last_return.seen = true
	c.station.train = {"phase": "waiting", "candidate_id": S.DORA, "expedition_id": "teste", "accepted": false}
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("station", {}, false)
	var hud: AHRefugeHud = null
	for frame in 900:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene is AHStation and _tree.current_scene.hud != null and frame > 3:
			hud = _tree.current_scene.hud
			break
	if not t.check(hud != null, "a Estação abre"):
		return
	for case in [[0, "pt"], [2, "pt"], [0, "en"]]:
		Settings.set_text_size(case[0])
		TranslationServer.set_locale(case[1])
		var tag := "texto %d, %s" % case
		for screen in [S.FORGE, S.RESEARCH, S.DEPOT, S.CANTEEN, S.BAR, S.DORMITORY, "plan", "options"]:
			if screen == "plan" or screen == "options":
				hud.open_service(screen)
			else:
				hud.open_room(screen)
			await _frames(4)
			var panel: Rect2 = hud._panel.get_global_rect()
			var prepare: Control = hud._frame.find_child("Prepare*", true, false)
			t.check(hud._panel.visible and absf(panel.size.x - AHRefugeHud.RIGHT.size.x) < 1.0 and panel.end.x <= 1893.0,
				"%s: o painel com a largura dele (%s, %s)" % [screen, panel, tag])
			t.check(prepare != null and panel.end.y <= prepare.get_global_rect().position.y,
				"%s: o painel acima do botão principal (%s)" % [screen, tag])
			# Com um cômodo aberto, as pendências ficam à esquerda; o texto de cada uma, dentro do botão.
			if screen == S.FORGE:
				var pending: Array = hud._menu.find_children("Pending_*", "Button", true, false)
				t.check(pending.size() == 2, "as duas pendências à esquerda (%s)" % tag)
				for button in pending:
					var inside := true
					for label in button.find_children("*", "Label", true, false):
						inside = inside and button.get_global_rect().grow(1.0).encloses(label.get_global_rect())
					t.check(inside, "%s: o texto dentro do botão (%s)" % [button.name, tag])
			hud.close_panel()
			await _frames(2)
		if case[1] == "en":
			var tab: Button = hud._frame.find_child("Nav_overview", true, false)
			t.check(tab != null and tab.text == TranslationServer.translate("Visão geral").to_upper() and tab.text != "VISÃO GERAL",
				"em inglês, as abas traduzidas (%s)" % (tab.text if tab else "?"))
	TranslationServer.set_locale("pt")
	# Os cartões da Preparação, no Maior: o conteúdo inteiro dentro do cartão.
	Campaign.state.night.phase = "none"
	Campaign.state.station.train = {"phase": "none", "candidate_id": "", "expedition_id": "teste", "accepted": false}
	Settings.set_text_size(2)
	hud.open_room(S.PREPARATION)
	await _frames(4)
	var slots: Array = hud._prep.find_children("Slot*", "Button", true, false)
	t.equal(slots.size(), 4, "os quatro cartões da Preparação")
	for slot in slots:
		var inside := true
		for label in slot.find_children("*", "Label", true, false):
			inside = inside and slot.get_global_rect().grow(1.0).encloses(label.get_global_rect())
		t.check(inside, "%s: o conteúdo dentro do cartão no Maior" % slot.name)
	hud.close_panel()


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
