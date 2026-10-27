## As telas da Estação no kit (#60): as regras novas da volta e o que as duas telas fazem.
## - O relatório guarda o foco e o objetivo da rota, e a fase liberada só na primeira vitória (nenhuma depois da última
##   fase, nem num save de antes, sem a marca first_clear).
## - Os abates da volta somam em kills_count uma vez só.
## - Na tela: cada herói da fila fica sobre o centro da sua carta; V/LB (report_details) troca as cartas pelos detalhes;
##   G/X (station_prepare) não abre nada no relatório nem com o Treino aberto; as Opções abertas da Sala voltam para ela.
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")
const J := preload("res://scripts/flow/journey_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_rules()
	var briefing: bool = AHBriefing.enabled
	AHBriefing.enabled = false
	var tips: bool = Tips.enabled
	Tips.enabled = false
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-station-kit-%d" % Time.get_ticks_usec()
	await _screens()
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
	Tips.enabled = tips
	AHBriefing.enabled = briefing


## Uma volta da fase dada: a equipe dos quatro fundadores, as quedas de cada um e o fim (vitória pelo corredor).
func _returned(phase_id: String, downs: Array, finish: bool = true, c: Dictionary = {}) -> Dictionary:
	if c.is_empty():
		c = Campaign.create_initial(17)
	var team: Array = c.roster.slice(0, 4).map(func(h): return h.id)
	J.start_expedition(c, phase_id, 17)
	var expedition: Dictionary = c.session.expedition
	expedition.team = team
	expedition.focus = S.FOCUS_WATER
	expedition.objective_done = true
	expedition.stats = {}
	for i in team.size():
		expedition.stats[team[i]] = {"damage": 0, "healing": 0, "downs": downs[i]}
	if finish:
		J.finish_corridor(c)
	c.session.result = "victory"
	return c


func _rules() -> void:
	var c := _returned("fase_1", [2, 1, 0, 3])
	var team: Array = c.session.expedition.team.duplicate()
	var report := S.finish_return(c)
	t.equal([report.focus, report.objective_done], [S.FOCUS_WATER, true], "o relatório guarda o foco e o objetivo cumprido")
	t.equal(report.unlocked_phase, "fase_2", "a primeira vitória na Rua das Vitrines libera a Ponte das Raízes")
	t.equal(team.map(func(id): return int(S.hero(c, id).kills_count)), [2, 1, 0, 3], "os abates da volta somam em kills_count")
	t.equal(S.finish_return(c), {}, "a mesma volta não entrega de novo")
	t.equal(int(S.hero(c, team[0]).kills_count), 2, "nem soma os abates duas vezes")
	# A segunda vitória na mesma fase (já concluída) não libera nada; os abates continuam somando.
	var again: Dictionary = Campaign.create_initial(17)
	again.completed_phases = ["fase_1"]
	S.hero(again, team[0]).kills_count = 2
	again = _returned("fase_1", [1, 0, 0, 0], true, again)
	report = S.finish_return(again)
	t.equal(report.get("unlocked_phase", "?"), "", "a segunda vitória na fase não mostra o lugar liberado")
	t.equal(int(S.hero(again, team[0]).kills_count), 3, "e os abates seguem somando (2 + 1)")
	# A última fase não libera outra.
	var last := _returned("fase_5", [0, 0, 0, 0])
	t.equal(S.finish_return(last).unlocked_phase, "", "a vitória na última fase não libera outra")
	# Um save de antes do #60: a expedição sem a marca first_clear e sem o foco.
	var old := _returned("fase_1", [0, 0, 0, 0])
	old.session.expedition.erase("first_clear")
	old.session.expedition.erase("focus")
	old.session.expedition.erase("objective_done")
	report = S.finish_return(old)
	t.equal([report.unlocked_phase, report.focus, report.objective_done], ["", "", false], "o save antigo abre o relatório sem o chip")


func _screens() -> void:
	var c := _returned("fase_1", [2, 1, 0, 3])
	S.finish_return(c)
	c.station.last_return.seen = false
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("station", {}, false)
	var station: AHStation = null
	for i in 600:
		await _tree.process_frame
		if _tree.current_scene is AHStation and _tree.current_scene.hud != null and not GameFlow.busy and i > 3:
			station = _tree.current_scene
			break
	if not t.check(station != null, "a Estação abre na volta"):
		return
	var hud: AHRefugeHud = station.hud
	if hud.current == AHRefugeHud.ARRIVAL:
		station.finish_team_arrival()
	if not t.check(await _until(func(): return hud.current == "report" and is_instance_valid(hud._report_screen)), "o relatório abre"):
		return
	await _until(func(): return station.camera_settled())
	await _frames(4)
	# Cada um da fila de pé sobre o centro da sua carta.
	var centers: Dictionary = hud._report_screen.card_centers()
	var off: Array = []
	for entry in station.lineup_screen_positions():
		if absf(entry.at.x - float(centers.get(entry.hero_id, -1000.0))) > 20.0:
			off.append("%s (%.0f contra %.0f)" % [entry.hero_id, entry.at.x, centers.get(entry.hero_id, -1.0)])
	t.equal(station.lineup_screen_positions().size(), 4, "os quatro da volta estão na fila")
	t.equal(off, [], "cada herói da fila fica a menos de 20 px do centro da sua carta")
	# V/LB: os detalhes e de volta às cartas; G não abre nada no relatório.
	_press("report_details")
	t.check(hud._report_screen.details and hud._report_screen._details.visible and not hud._report_screen._cards.visible, "V mostra os detalhes")
	_press("report_details")
	t.check(not hud._report_screen.details and hud._report_screen._cards.visible, "V de novo volta às cartas")
	_press("station_prepare")
	t.check(hud.current == "report" and not hud._map.visible, "G não abre o mapa no relatório")
	# Entrar no abrigo; a Sala dos Personagens.
	hud._report_screen.enter_shelter.emit()
	await _until(func(): return hud.current == "")
	var bento = S.hero(Campaign.state, c.roster[0].id)
	bento.xp = int(AHHeroLevels.next_cost(bento).xp)
	Campaign.state.inventory.seeds = 9
	hud.open_room(S.CHARACTERS)
	await _frames(3)
	t.check(is_instance_valid(hud._room_screen), "a Sala dos Personagens abre no kit")
	var shown: Array = station.residents.values().filter(func(card): return is_instance_valid(card) and card.visible)
	t.equal(shown.size(), 0, "nenhum morador aparece atrás da Sala")
	hud._room_screen.training = true
	hud._room_screen.rebuild()
	_press("station_prepare")
	t.check(not hud._map.visible and hud._room_screen.training, "G não abre o mapa com o Treino aberto")
	hud._room_screen.training = false
	hud._room_screen.rebuild()
	# As Opções pela engrenagem: fechar volta à Sala.
	(hud._room_screen.find_child("Options", true, false) as Button).pressed.emit()
	await _frames(2)
	t.equal(hud.current, "options", "a engrenagem abre as Opções")
	hud.close_panel()
	await _frames(2)
	t.check(hud.current == S.CHARACTERS and is_instance_valid(hud._room_screen), "fechar as Opções volta à Sala")
	hud.close_panel()
	await _frames(2)
	t.check(hud.current == "" and not is_instance_valid(hud._room_screen), "e fechar a Sala volta à vista geral")
	# Quem ainda sai andando da plataforma (#131) só volta ao cômodo depois de sair da câmera.
	var walking: Array = station._leaving.map(func(e): return e.hero_id)
	var hidden: Array = station.residents.keys().filter(func(id): return is_instance_valid(station.residents[id]) and not station.residents[id].visible and not walking.has(id))
	t.equal(hidden, [], "os moradores voltam com a Sala fechada")
	await _until(func(): return not station.lineup_leaving())
	t.equal(station.residents.values().filter(func(card): return is_instance_valid(card) and not card.visible).size(), 0, "e quem saía da plataforma também, ao sair da câmera")


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_tree.root.push_input(event)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	_tree.root.push_input(release)


func _until(condition: Callable, seconds: float = 20.0) -> bool:
	var limit := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < limit:
		if condition.call():
			return true
		await _tree.process_frame
	return condition.call()


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
