## Teclado e controle em todas as telas (#5): manda as ações de input (as do teclado e do controle são as mesmas) e
## confere o foco. Na Estação: o menu da esquerda, as Opções, o mapa de fases, a Preparação, um cômodo e Voltar. Na
## exploração: a pausa e a Mochila. Na volta: o relatório, a noite no Dormitório e o trem, só com setas e Interagir. As
## teclas desenhadas acompanham a troca nas Opções.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const U = preload("res://scripts/ui/ui_style.gd")

var t
var tree: SceneTree


func run(context) -> void:
	t = context
	# O briefing e o debriefing (#88) têm o teste deles; aqui, fora do caminho.
	var briefing: bool = AHBriefing.enabled
	AHBriefing.enabled = false
	tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-keyboard-%d" % Time.get_ticks_usec()
	Campaign.state = Campaign.create_initial(41)
	# O trem da volta (#122) é sorteado: aqui ele traz sempre o próximo civil da fila (o test_train_recruits sorteia).
	var train_rule: Dictionary = GameData.table("recruitment").get("train", {})
	var train_before := train_rule.duplicate()
	train_rule.Chance = 100
	train_rule.CivilianShare = 100
	await _station()
	await _street()
	await _return()
	Settings.reset_keys()
	if tree.current_scene != null:
		tree.unload_current_scene()
	await tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state
	AHBriefing.enabled = briefing
	train_rule.merge(train_before, true)


func _station() -> void:
	GameFlow.change_to("station", {}, false)
	if not t.check(await _wait(func(s): return s is AHStation and s.hud != null), "a Estação abriu"):
		return
	var hud: AHRefugeHud = tree.current_scene.hud
	await _frames(5)
	# Menu leva o foco aos botões da esquerda; as setas andam entre eles; Voltar devolve aos cômodos.
	await _send("menu")
	t.check(_inside(hud._menu), "Menu: o foco vai para o Próximo passo")
	var first := _focus()
	await _send("ui_down")
	t.check(_inside(hud._menu) and _focus() != first, "↓ anda entre os botões da esquerda")
	await _send("cancel")
	t.equal(_focus(), null, "Voltar devolve as setas aos cômodos")
	# Um cômodo pelas setas: o painel abre com o foco nele; Voltar fecha.
	await _send("move_right")
	await _send("interact")
	t.check(hud.current != "" and hud._panel.visible, "→ e Interagir abrem um cômodo (%s)" % hud.current)
	await _frames(2)
	t.check(_inside(hud.focus_scope()) and hud.focus_scope() != null, "o foco está no painel do cômodo (ou no Vista geral, se ele só tem texto)")
	await _send("cancel")
	t.equal(hud.current, "", "Voltar fecha o cômodo")
	# Só com as setas: Menu e ↓ descem da coluna da esquerda até o botão principal; Voltar devolve aos cômodos.
	await _send("menu")
	t.check(await _walk_to("Ir ao mapa", 12), "↓ desce da coluna da esquerda até IR AO MAPA")
	await _send("cancel")
	t.equal(_focus(), null, "e Voltar devolve as setas aos cômodos")
	# IR AO MAPA pelo botão principal (o foco nele, como o mouse): o mapa, o lugar, a plataforma e Voltar (#123).
	var prepare: Button = hud.find_child("Prepare", true, false)
	if not t.check(prepare != null and prepare.text.begins_with("IR AO MAPA"), "o botão principal é IR AO MAPA"):
		return
	prepare.grab_focus()
	await _send("interact")
	t.check(hud._map.visible, "Interagir (E) abre o mapa de fases")
	await _frames(2)
	t.check(_inside(hud._map), "o foco está no mapa de fases")
	await _send("ui_down")
	t.check(_inside(hud._map), "↓ no mapa mantém o foco nele")
	# As setas andam pelos lugares do mapa: ↓ chega até a última fase (Fase 5, os Túneis do Eco), visível na tela.
	if t.check(await _walk_to("Fase 5", 20), "↓ chega na última fase do mapa"):
		t.check(_visible_in(_focus(), hud._map), "e a lista rolou até ela")
	await _send("cancel")
	t.check(not hud._map.visible, "Voltar fecha o mapa")
	hud.open_map()
	await _frames(2)
	var go := _find(hud._map, "PREPARAR NESTE LUGAR")
	if go != null:
		go.grab_focus()
	# O briefing do lugar (#88) fica de fora aqui (o test_briefing cuida dele).
	hud._briefed = hud._map.selected
	await _send("ui_accept")
	t.check(hud.current == "departure" and hud._departure != null and hud._departure.visible, "Enter (A) leva a equipe para a plataforma")
	await _frames(2)
	t.check(_inside(hud._departure), "o foco está na plataforma")
	t.check(_focus() is Button and String((_focus() as Button).name).begins_with("Slot"), "a plataforma começa numa carta da equipe")
	for step in ["ui_down", "ui_right", "ui_down", "ui_left", "ui_up"]:
		await _send(step)
		t.check(_inside(hud._departure), "a plataforma mantém o foco com %s" % step)
	# O "+" da comida até o máximo: quando ele desliga, o foco fica por perto e o E nunca faz partir.
	var plus := _find(hud._departure, "+")
	if t.check(plus != null, "a plataforma tem o + da comida"):
		plus.grab_focus()
		for i in 8:
			await _send("interact")
			t.check(Campaign.state.session.expedition == null and not GameFlow.busy, "E no + (%d) não parte" % (i + 1))
			t.check(not hud._departure.confirm_open(), "e não abre a confirmação (%d)" % (i + 1))
	# G (X) abre a confirmação; Voltar fecha só ela.
	await _send("station_prepare")
	t.check(hud._departure.confirm_open() and _inside(hud._departure._confirm), "G abre a confirmação, com o foco nela")
	await _send("cancel")
	t.check(hud.current == "departure" and not hud._departure.confirm_open(), "Voltar fecha a confirmação e fica na plataforma")
	await _send("cancel")
	t.check(hud._map.visible and hud._map.selected != "", "Voltar na plataforma volta ao mapa, com o lugar escolhido")
	await _send("cancel")
	t.check(not hud._map.visible and hud.current == "", "e Voltar no mapa volta à vista geral")
	# As Opções pela engrenagem do alto; Interagir liga o daltonismo; Voltar fecha.
	var gear: Button = hud.find_child("Options", true, false)
	if t.check(gear != null, "a engrenagem das Opções no alto"):
		gear.grab_focus()
		await _send("interact")
		t.equal(hud.current, "options", "Interagir abre as Opções")
		await _frames(2)
		t.check(_inside(hud.focus_scope()), "o foco está nas Opções")
		if await _walk_to("Cores para daltonismo", 20):
			await _send("interact")
			t.check(Settings.colorblind, "Interagir liga as cores para daltonismo")
			Settings.set_colorblind(false)
		# Trocar uma tecla e desistir com o B do controle: nada muda e as Opções continuam abertas.
		if await _walk_to("Trocar", 30):
			var before := Settings.primary_key("interact")
			var keys_before := Settings.keys.duplicate()
			await _send("interact")
			await _joypad(JOY_BUTTON_B)
			t.equal(hud.current, "options", "B cancela a espera da tecla sem fechar as Opções")
			var key := InputEventKey.new()
			key.physical_keycode = KEY_D
			key.pressed = true
			Input.parse_input_event(key)
			await _frames(2)
			key.pressed = false
			Input.parse_input_event(key)
			await _frames(2)
			t.equal(Settings.keys, keys_before, "depois do B, a próxima tecla não troca nada")
			t.equal(Settings.primary_key("interact"), before, "Interagir continua na tecla dele")
		# A lista das Opções rola com o foco: ↓ chega até o Fechar, no fim.
		if t.check(await _walk_to("Fechar", 80), "↓ chega no Fechar, no fim das Opções"):
			t.check(_visible_in(_focus(), hud._panel), "e a lista rolou até ele")
		await _send("cancel")
		t.equal(hud.current, "", "Voltar fecha as Opções")
	# A dica da primeira vez: o foco vai para o Entendi e o A fecha a dica, sem mexer no painel de trás.
	var tips_before: bool = Tips.enabled
	Tips.enabled = true
	Tips._seen.erase("preparation")
	hud.open_room(S.PREPARATION)
	Tips.show_tip("preparation")
	await _frames(3)
	t.check(Tips.showing(), "a dica da Preparação aparece")
	await _send("ui_accept")
	t.check(not Tips.showing(), "o A (Enter) fecha a dica")
	t.equal(hud.current, S.PREPARATION, "e a Preparação continua aberta")
	Tips.enabled = tips_before
	await _send("cancel")
	# A dica das teclas segue a troca nas Opções.
	Settings.set_key("interact", KEY_J)
	t.check(_cap_text(hud, "interact") == "J", "a dica de Interagir mostra a tecla nova")
	# O botão principal também: a tecla nova com o X do controle, na hora (com as Opções abertas por cima).
	Settings.set_key("station_prepare", KEY_H)
	t.equal(_cap_text(hud, "station_prepare"), "H / X", "PREPARAR EXPEDIÇÃO mostra a tecla nova com o X do controle")
	Settings.reset_keys()
	t.check(_cap_text(hud, "interact") == U.key_name("interact"), "e volta com Restaurar")


func _street() -> void:
	var c: Dictionary = Campaign.state
	t.equal(S.confirm_departure(c, c.preferred_formation.duplicate(), 0, 777, "fase_1"), "", "parte")
	GameFlow.change_to("street", {}, false)
	if not t.check(await _wait(func(s): return s.get("corridor") != null), "a rua abriu"):
		return
	var hud: AHExplorationHud = tree.current_scene.exploration_hud
	await _frames(3)
	await _send("menu")
	t.check(hud.menu_shown(), "Menu abre o Menu da expedição")
	await _frames(2)
	t.check(_inside(hud._modal) and _focus().name == "Resume", "o foco começa em Fechar")
	await _send("ui_up")
	t.check(_inside(hud._modal) and _focus().name != "Resume", "↑ anda no Menu da expedição")
	await _send("cancel")
	t.check(not hud.modal_open(), "Voltar (B) fecha o Menu da expedição")
	await _send("inventory")
	t.check(hud.inventory_shown(), "a Mochila abre")
	await _frames(2)
	t.check(_inside(hud._modal), "o foco está na Mochila")
	await _send("cancel")
	t.check(not hud.modal_open(), "Voltar fecha a Mochila")
	await _send("menu")
	await _frames(2)
	await _send("interact")
	t.check(not hud.modal_open(), "Interagir (E) confirma Fechar")
	# Na luta: a Mochila abre com o foco nela e Voltar fecha; Interagir confirma a habilidade com foco.
	var street = tree.current_scene
	street.corridor.debug_next_fight()
	street.corridor._start_fight(Campaign.state.session.expedition.corridor.index, true)
	var arena: AHCombatArena = street._arena
	for frame in 600:
		if arena.hud.waiting:
			break
		await tree.process_frame
	if not t.check(arena.hud.waiting, "a luta pede o comando"):
		return
	await _send("inventory")
	await _frames(2)
	t.check(arena.hud._bag != null and _inside(arena.hud._bag), "na luta, a Mochila abre com o foco nela")
	await _send("cancel")
	t.check(arena.hud._bag == null, "Voltar fecha a Mochila da luta")
	await _frames(2)
	t.check(_inside(arena.hud._panel), "o foco volta às habilidades")
	await _send("interact")
	await _frames(2)
	t.check(not arena.hud.waiting or arena.hud._choosing != "", "Interagir escolhe a habilidade com foco (%s)" % arena.hud._choosing)
	if arena.hud._choosing != "":
		await _send("interact")
		await _frames(2)
		t.check(not arena.hud.waiting, "Interagir confirma o alvo com foco")
	arena.auto_battle = true
	arena.speed = 20.0
	for frame in 1200:
		if not arena.active:
			break
		if arena.hud.waiting:
			arena.hud.command_chosen.emit({"kind": "defend"})
		await tree.process_frame


## A volta só com o teclado: relatório → Entrar no abrigo → Dormitório → Iniciar descanso → Começar o dia → trem.
func _return() -> void:
	var c: Dictionary = Campaign.state
	if c.session.expedition == null:
		return
	c.session.result = "retreat"
	c.session.screen = "result"
	tree.current_scene.corridor._show_result()
	await _frames(2)
	tree.current_scene.exploration_hud.close_modal()
	GameFlow.change_to("station", {}, false)
	if not t.check(await _wait(func(s): return s is AHStation and s.hud != null), "a Estação abriu na volta"):
		return
	var hud: AHRefugeHud = tree.current_scene.hud
	await _frames(3)
	# A volta começa com a chegada de trem (#76): Interagir pula para o relatório.
	t.equal(hud.current, AHRefugeHud.ARRIVAL, "a volta começa com a chegada de trem")
	await _send("interact")
	await _frames(3)
	t.equal(hud.current, "report", "Interagir pula a chegada e o relatório abre")
	# O relatório recém-aberto pela chegada ignora pular e voltar por um instante (o segundo toque de quem pula).
	var guard := Time.get_ticks_msec() + AHRefugeHud.REPORT_GUARD_MS + 50
	while Time.get_ticks_msec() < guard:
		await _frames(1)
	await _send("ui_down")
	if not t.check(await _walk_to("Entrar no abrigo", 30), "↓ chega em Entrar no abrigo"):
		return
	await _send("interact")
	await _frames(3)
	t.equal(hud.current, "", "Entrar no abrigo volta à vista geral (a noite espera no Dormitório)")
	# Menu leva o foco ao Próximo passo (Ir ao Dormitório); Interagir abre o Dormitório.
	await _send("menu")
	await _send("interact")
	await _frames(3)
	t.equal(hud.current, S.DORMITORY, "Menu e Interagir no Próximo passo abrem o Dormitório")
	for step in [["Iniciar descanso", S.DORMITORY], ["Começar o dia", ""]]:
		await _send("ui_down")
		if not t.check(await _walk_to(step[0], 30), "↓ chega em %s" % step[0]):
			return
		await _send("interact")
		await _frames(3)
		if step[1] != "":
			t.equal(hud.current, step[1], "%s leva ao %s" % [step[0], step[1]])
		# A cena da noite (#132): Interagir pula para o amanhecer.
		if step[0] == "Iniciar descanso":
			t.check(hud.night_scene_open(), "Iniciar descanso abre a cena da noite")
			await _send("interact")
			await _frames(3)
			t.check(not hud.night_scene_open() and _focus() is BaseButton, "Interagir pula a noite, e o foco fica no amanhecer")
	t.equal(c.night.phase, "none", "a noite passou só com o teclado")
	if S.visit_pending(c):
		await _frames(3)
		t.equal(hud.current, "train", "o trem espera na plataforma")
		# O painel do trem abre depois da cena (o trem chega, o candidato desce, a câmera nele: #61).
		var end := Time.get_ticks_msec() + 30000
		while (hud.station.train_busy() or not hud._panel.visible) and Time.get_ticks_msec() < end:
			await tree.process_frame
		await _frames(3)
		if t.check(await _walk_to("Acolher", 10), "↓ chega em Acolher"):
			await _send("interact")
			t.equal(c.station.train.phase, "departing", "Interagir acolhe o candidato")


## Anda com ↓ até o botão com foco começar com prefix (no máximo steps passos).
func _walk_to(prefix: String, steps: int) -> bool:
	for i in steps:
		var owner := _focus()
		if owner is BaseButton and String(owner.get("text")).to_lower().begins_with(prefix.to_lower()):
			return true
		await _send("ui_down")
	var owner := _focus()
	return owner is BaseButton and String(owner.get("text")).to_lower().begins_with(prefix.to_lower())


## O controle aparece inteiro na área de rolagem dele (a lista rolou até ele).
func _visible_in(control: Control, panel: Control) -> bool:
	if control == null:
		return false
	var area: Control = panel
	var node := control.get_parent()
	while node != null and node != panel:
		if node is ScrollContainer:
			area = node
			break
		node = node.get_parent()
	var rect := area.get_global_rect().grow(2.0)
	return rect.encloses(control.get_global_rect()) and rect.position.y + rect.size.y <= 1082.0


func _joypad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)


func _cap_text(root: Node, action: String) -> String:
	for node in root.find_children("*", "PanelContainer", true, false):
		if node.get_meta("ah_action", "") == action:
			return (node.get_child(0) as Label).text
	return ""


func _find(root: Node, prefix: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if node.is_visible_in_tree() and node.text.begins_with(prefix):
			return node
	return null


func _focus() -> Control:
	return tree.root.gui_get_focus_owner()


func _inside(scope: Control) -> bool:
	var owner := _focus()
	return scope != null and owner != null and owner.is_visible_in_tree() and scope.is_ancestor_of(owner)


func _send(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await tree.process_frame


func _wait(check: Callable) -> bool:
	for frame in 600:
		await tree.process_frame
		if not GameFlow.busy and tree.current_scene != null and check.call(tree.current_scene):
			await _frames(2)
			return true
	return false
