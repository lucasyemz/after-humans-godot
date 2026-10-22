## A jornada inteira com as cenas de verdade (#3), sem janela: Estação → mapa de fases → Preparação → Rua das Vitrines
## (andar, vasculhar, as lutas no automático, o guardião) → volta → relatório → noite no Dormitório → trem. Aperta os
## botões das telas (pelo texto) e manda as ações de input (andar, Interagir), como quem joga; confere a campanha em cada
## passo e que nenhuma tela trava (cada espera tem prazo). Usa uma pasta de save própria e devolve a campanha de antes.
## O runner já conta os erros de script (acesso inválido, nó liberado) durante o teste.
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")
const J := preload("res://scripts/flow/journey_rules.gd")
## A jornada roda acelerada (tweens, timers e a física andam 8 vezes mais rápido).
const TIME_SCALE := 8.0
## Prazo de cada espera, em segundos reais: passou disso, a tela travou.
const TIMEOUT := 30.0
const SEED := 20261022

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-full-journey-%d" % Time.get_ticks_usec()
	var real_scale := Engine.time_scale
	Engine.time_scale = TIME_SCALE
	# As lutas e as buscas sorteiam pelo randi() global: com a semente fixa, a jornada sai sempre igual.
	seed(SEED)
	await _play()
	randomize()
	Engine.time_scale = real_scale
	_release_all()
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _play() -> void:
	t.check(Campaign.new_game(SEED), "campanha nova gravada na pasta do teste")
	if not await _station_to_departure():
		return
	if not await _journey():
		return
	if not await _return_report():
		return
	if not await _night():
		return
	await _train()
	await _final_checks()


# ---------------------------------------------------------------- Estação → partida

func _station_to_departure() -> bool:
	GameFlow.change_to("station", {}, false)
	if not await _until(func(): return _station() != null and _station().hud != null and not GameFlow.busy, "a Estação abrir"):
		return false
	var hud: AHRefugeHud = _station().hud
	await _frames(3)
	t.equal(Campaign.state.night.phase, "none", "campanha nova: sem noite pendente")
	if not await _press(hud, "Preparar expedição", "o botão Preparar expedição da Estação"):
		return false
	var map: AHPhaseMap = hud._map
	if not await _until(func(): return map.visible, "o mapa de fases abrir"):
		return false
	# Escolhe a fase 1 na lista do mapa e prepara a expedição dela.
	if not await _press(map, "Rua das Vitrines", "a fase 1 na lista do mapa"):
		return false
	t.equal(map.selected, "fase_1", "a fase 1 fica escolhida no mapa")
	if not await _press(map, "Preparar expedição", "Preparar expedição no painel da fase"):
		return false
	if not await _until(func(): return not map.visible and hud.current == S.PREPARATION, "a Preparação abrir"):
		return false
	t.equal(hud._draft.get("phase", ""), "fase_1", "a Preparação vem com a fase do mapa")
	t.equal(hud._draft.get("team", []).size(), 4, "a Preparação escala os quatro fundadores")
	# Escolher no mapa volta ao mapa; Preparar expedição de novo volta à mesma Preparação.
	if not await _press(hud, "Escolher no mapa", "Escolher no mapa na Preparação"):
		return false
	t.check(map.visible, "Escolher no mapa abre o mapa de fases")
	if not await _press(map, "Preparar expedição", "Preparar expedição de novo no mapa"):
		return false
	if not await _until(func(): return not map.visible and hud.current == S.PREPARATION and hud._prep != null and hud._prep.visible, "voltar à Preparação"):
		return false
	t.equal(hud._draft.get("phase", ""), "fase_1", "a Preparação continua com a fase 1")
	if not await _press(hud, "Partir", "o botão Partir da Preparação"):
		return false
	if not await _until(func(): return _street() != null and _street().corridor != null and not GameFlow.busy, "a rua abrir depois da partida"):
		return false
	var expedition = Campaign.state.session.expedition
	t.check(expedition != null and expedition.phase_id == "fase_1", "a expedição da fase 1 começou")
	t.equal(expedition.team.size() if expedition != null else 0, 4, "a equipe da expedição tem os quatro")
	t.equal(_street().party_ids.size(), 4, "os quatro andam na rua")
	var saved = Campaign.read_file(Campaign.primary_path())
	t.check(saved != null and saved.session.expedition != null and saved.session.expedition.phase_id == "fase_1", "a partida ficou gravada")
	return expedition != null


# ---------------------------------------------------------------- a jornada

func _journey() -> bool:
	var street = _street()
	var route: Dictionary = Campaign.state.session.expedition.corridor
	t.equal(route.steps.size(), 10, "o corredor tem 10 trechos")
	var searched := false
	var deadline := Time.get_ticks_msec() + 240000
	while not Campaign.state.session.expedition.objective_completed:
		if Time.get_ticks_msec() > deadline:
			t.check(false, "a jornada não chegou ao guardião em 4 minutos (trecho %d)" % (route.index + 1))
			return false
		if Campaign.state.session.result != "":
			t.check(false, "a jornada terminou antes do guardião: %s" % Campaign.state.session.result)
			return false
		# A pergunta de risco (descanso, guardião): segue em frente.
		if street.exploration_hud.modal_open():
			if not await _answer_modal(street):
				return false
			continue
		# Os primeiros caixotes já alcançados (atrás da equipe ou no trecho dela): anda até eles e aperta Interagir.
		if not searched and _crates_behind(street, route) >= 0:
			if not await _search_crates(street, route, _crates_behind(street, route)):
				return false
			searched = true
			continue
		street.corridor.debug_next_fight()
		await _frames(2)
		if not await _walk_into_fight(street):
			return false
		if not await _auto_fight(street):
			return false
	var fought: int = route.steps.filter(func(s): return (s.type == "combat" or s.type == "boss") and s.resolved).size()
	t.equal(fought, 5, "a jornada venceu as 4 patrulhas e o guardião")
	t.check(route.steps[9].resolved, "o guardião (trecho 10) ficou vencido")
	if not t.check(searched, "a equipe vasculhou os caixotes no caminho (nenhum caixote alcançado até o guardião)"):
		return false
	var saved = Campaign.read_file(Campaign.primary_path())
	t.check(saved != null and saved.session.expedition.objective_completed, "o guardião vencido ficou gravado")
	return true


func _walk_into_fight(street) -> bool:
	# A política automática vence as lutas de vida cheia (test_combat_session); o desgaste de uma luta para a outra
	# depende do sorteio. O teste cura a equipe antes de cada patrulha: o que ele confere é o fluxo, não o equilíbrio.
	for hero_id in Campaign.state.session.expedition.team:
		var entry = Campaign.hero(hero_id)
		if entry.alive:
			entry.hp = entry.max_hp
	Input.action_press("move_right")
	var ok: bool = await _until(func(): return street._arena.active or street.exploration_hud.modal_open(), "a equipe encostar na patrulha")
	Input.action_release("move_right")
	if ok and street.exploration_hud.modal_open() and not street._arena.active:
		# A pergunta do guardião aparece ao entrar no trecho dele; responde e continua andando.
		if not await _answer_modal(street):
			return false
		return await _walk_into_fight(street)
	return ok


func _auto_fight(street) -> bool:
	var arena: AHCombatArena = street._arena
	arena.auto_battle = true
	arena.speed = 20.0
	var ok: bool = await _until(func():
		if arena.hud.waiting:
			arena.hud.command_chosen.emit({"kind": "defend"})
		return not arena.active, "a luta terminar", 60.0)
	if not ok:
		return false
	await _frames(2)
	var result: String = arena.session.result()
	t.check(["victory", "defeat", "escaped"].has(result), "a luta terminou com um resultado (%s)" % result)
	if result != "victory":
		t.check(false, "a política automática perdeu uma luta da fase 1 (%s)" % result)
		return false
	t.equal(street.party_ids.size(), Campaign.state.session.expedition.team.filter(func(id): return Campaign.hero(id).alive).size(),
		"a equipe na rua é a que está viva depois da luta")
	return true


## Os caixotes de um trecho já alcançado e ainda não vasculhados (-1 se não há).
func _crates_behind(street, route: Dictionary) -> int:
	for key in street.corridor.props:
		if int(key) <= route.index and not route.props.get(str(key), false):
			return int(key)
	return -1


func _search_crates(street, route: Dictionary, index: int) -> bool:
	var corridor: AHStreetCorridor = street.corridor
	var before := _search_snapshot()
	street._place_leader(Vector3(corridor._step_x(index, 0.45), 0, 0.45))
	if not await _until(func(): return corridor._action.is_valid(), "o aviso Vasculhar aparecer perto dos caixotes"):
		return false
	await _action("interact")
	if not await _until(func(): return route.props.get(str(index), false), "a busca dos caixotes acontecer"):
		return false
	t.check(_search_snapshot() != before or Campaign.state.session.event != null,
		"a busca mudou algo: comida, achado, curativos, ferramentas, esperança, vida ou instinto")
	t.check(Campaign.read_file(Campaign.primary_path()).session.expedition.corridor.props.get(str(index), false), "a busca ficou gravada")
	# Repetir a busca não dá nada: o mesmo caixote não abre de novo.
	t.check(not J.search_prop(Campaign.state, index).ok, "o mesmo caixote não abre duas vezes")
	if street.exploration_hud.modal_open():
		return await _answer_modal(street)
	return true


## Tudo o que uma busca pode mudar (os resultados ruins mexem só na vida, no instinto ou na esperança).
func _search_snapshot() -> Dictionary:
	var expedition: Dictionary = Campaign.state.session.expedition
	var team: Array = expedition.team.map(func(id): return Campaign.hero(id))
	return {"food": expedition.food, "loot": expedition.loot.duplicate(), "bandages": Campaign.state.inventory.bandages,
		"tools": Campaign.state.tools.size(), "hope": expedition.hope, "hp": team.map(func(h): return h.hp),
		"instinct": team.map(func(h): return h.instinct)}


## Responde o painel aberto no HUD da exploração (só os botões dele, não o Menu nem a Mochila): a pergunta de risco
## segue em frente; um evento escolhe a primeira opção que dá e depois fecha.
func _answer_modal(street) -> bool:
	var hud: AHExplorationHud = street.exploration_hud
	for attempt in 4:
		if not hud.modal_open():
			return true
		var options: Array = _buttons(hud._modal).filter(func(b): return b.is_visible_in_tree() and not b.disabled)
		var forward: Array = options.filter(func(b): return b.text.begins_with("Seguir em frente"))
		if not t.check(not options.is_empty(), "o painel da exploração tem um botão para seguir"):
			return false
		(forward[0] if not forward.is_empty() else options[0]).pressed.emit()
		await _frames(3)
	return await _until(func(): return not hud.modal_open(), "o painel da exploração fechar")


# ---------------------------------------------------------------- volta e relatório

func _return_report() -> bool:
	var street = _street()
	# Com o guardião vencido aparece Concluir jornada · Voltar à Estação.
	var hud_street: AHExplorationHud = street.exploration_hud
	if not await _until(func(): return hud_street._finish_button.is_visible_in_tree(), "o botão Concluir jornada aparecer"):
		return false
	hud_street._finish_button.pressed.emit()
	await _frames(3)
	# O resultado já entrega o achado e fecha a expedição (finish_return); a tela mostra o que chegou.
	if not await _until(func(): return Campaign.state.station.last_return.get("result", "") == "victory", "o resultado da jornada"):
		return false
	t.equal(Campaign.state.session.expedition, null, "a volta fechou a expedição")
	var delivered: Dictionary = Campaign.state.station.last_return
	t.check(int(delivered.get("seeds", 0)) > 0, "a vitória entrega sementes (%d)" % int(delivered.get("seeds", 0)))
	t.check(_has_label(street.exploration_hud, "Chegou à Estação: %d sementes" % int(delivered.get("seeds", 0))), "o resultado mostra o achado")
	t.check(Campaign.state.completed_phases.has("fase_1"), "a fase 1 ficou concluída")
	if not await _press(street.exploration_hud, "Voltar à Estação", "Voltar à Estação no resultado"):
		return false
	if not await _until(func(): return _station() != null and _station().hud != null and not GameFlow.busy, "a Estação abrir na volta"):
		return false
	var hud: AHRefugeHud = _station().hud
	await _frames(3)
	t.equal(hud.current, "report", "a volta abre o relatório na plataforma")
	var report: Dictionary = Campaign.state.station.last_return
	t.equal(report.get("result", ""), "victory", "o relatório é de vitória")
	t.equal(report.get("phase_id", ""), "fase_1", "o relatório é da fase 1")
	t.equal(Campaign.state.night.phase, "planning", "a noite da volta espera no Dormitório")
	if not await _press(hud, "Entrar no abrigo", "Entrar no abrigo no relatório"):
		return false
	t.check(Campaign.state.station.last_return.get("seen", false), "o relatório fica visto")
	if not await _until(func(): return hud.current == S.DORMITORY, "o Dormitório abrir depois do relatório"):
		return false
	# Com a noite pendente, Preparar expedição não parte: a Preparação diz o motivo e leva ao Dormitório.
	hud.close_panel()
	await _frames(2)
	hud.open_map()
	await _frames(2)
	t.check(not hud._map.visible and hud.current == S.PREPARATION, "com a noite pendente, Preparar expedição abre a Preparação, não o mapa")
	if not await _press(hud, "Ir ao Dormitório", "Ir ao Dormitório na Preparação bloqueada"):
		return false
	return await _until(func(): return hud.current == S.DORMITORY, "o Dormitório abrir pela Preparação")


# ---------------------------------------------------------------- noite e trem

func _night() -> bool:
	var hud: AHRefugeHud = _station().hud
	var hurt: Array = Campaign.state.night.participants.filter(func(id): var h = Campaign.hero(id); return h.hp < h.max_hp)
	if not await _press(hud, "Iniciar descanso", "Iniciar descanso no Dormitório"):
		return false
	t.equal(Campaign.state.night.phase, "dawn", "a noite passou: amanhecer")
	t.equal(Campaign.state.night.results.size(), Campaign.state.night.participants.size(), "um resultado da noite por herói")
	if not hurt.is_empty():
		t.check(Campaign.state.night.results.any(func(r): return r.hp_recovered > 0), "quem dormiu ferido recuperou vida")
	if not await _press(hud, "Começar o dia", "Começar o dia no Dormitório"):
		return false
	t.equal(Campaign.state.night.phase, "none", "o dia começou")
	return true


func _train() -> void:
	var hud: AHRefugeHud = _station().hud
	if not t.check(S.visit_pending(Campaign.state), "o trem chega na primeira volta (a fila de candidatos começa cheia)"):
		return
	if not await _until(func(): return hud.current == "train", "a plataforma do trem abrir"):
		return
	var candidate: String = Campaign.state.station.train.candidate_id
	var residents: int = S.resident_count(Campaign.state)
	if not await _press(hud, "Acolher", "Acolher o candidato do trem"):
		return
	if not await _until(func(): return Campaign.state.station.train.phase == "none" and hud.current == "", "o trem partir"):
		return
	t.check(S.is_resident(Campaign.state, candidate), "o candidato acolhido mora na Estação")
	t.equal(S.resident_count(Campaign.state), residents + 1, "um morador a mais")


func _final_checks() -> void:
	await _frames(1)
	var saved = Campaign.read_file(Campaign.primary_path())
	t.check(saved != null, "o save do fim abre")
	if saved != null:
		t.equal(saved.completed_phases, Campaign.state.completed_phases, "o save tem as fases concluídas")
		t.equal(saved.night.phase, "none", "o save não tem noite pendente")
		t.equal(saved.session.expedition, null, "o save não tem expedição aberta")
	var hud: AHRefugeHud = _station().hud
	t.equal(S.preparation_block(Campaign.state), "", "a Estação fica pronta para a próxima partida")
	t.equal(hud.current, "", "a Estação volta à vista geral")
	# O mapa de fases mostra a fase 1 concluída.
	hud.open_map()
	await _frames(2)
	if await _press(hud._map, "Rua das Vitrines", "a fase 1 na lista do mapa"):
		t.check(_has_label(hud._map, "Concluída"), "o mapa mostra a fase 1 concluída")
	hud._map.visible = false


# ---------------------------------------------------------------- auxiliares

func _station() -> AHStation:
	return _tree.current_scene as AHStation


func _street():
	var scene := _tree.current_scene
	return scene if scene != null and scene.get("corridor") != null else null


## Espera a condição, quadro a quadro; passou do prazo, a tela travou (falha com o que se esperava).
func _until(condition: Callable, what: String, seconds: float = TIMEOUT) -> bool:
	var limit := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > limit:
			t.check(false, "travou esperando %s" % what)
			return false
		await _tree.process_frame
	return true


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame


func _has_label(root: Node, part: String) -> bool:
	for node in root.find_children("*", "Label", true, false):
		if not node.is_queued_for_deletion() and node.is_visible_in_tree() and node.text.contains(part):
			return true
	return false


func _buttons(root: Node) -> Array:
	var found: Array = []
	for node in root.find_children("*", "Button", true, false):
		if not node.is_queued_for_deletion():
			found.append(node)
	return found


## Aperta o primeiro botão visível e ativo cujo texto começa com prefix (espera ele aparecer).
func _press(root: Node, prefix: String, what: String) -> bool:
	var target: Array = []
	var found: bool = await _until(func():
		for button in _buttons(root):
			if button.is_visible_in_tree() and not button.disabled and button.text.begins_with(prefix):
				target.append(button)
				return true
		return false, what)
	if not found:
		return false
	target[0].pressed.emit()
	await _frames(3)
	return true


## Uma ação de input apertada e solta, pelo caminho do jogo (_unhandled_input).
func _action(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)


func _release_all() -> void:
	for action in ["move_left", "move_right", "move_back", "move_front", "run"]:
		Input.action_release(action)
