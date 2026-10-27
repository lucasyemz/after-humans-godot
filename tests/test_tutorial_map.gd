## O Corredor de Contenção (#147), o mapa do tutorial da abertura (#144):
## - o mapa monta no contrato dos cenários (as quatro zonas, as portas de segurança, o painel, o armário, o vagão e as
##   lâmpadas que piscam; com "Reduzir efeitos", acesas sem piscar);
## - a fase do tutorial joga como as outras, mas fica fora do Mapa da Rede e do "Jogar de novo";
## - a jornada pela cena de verdade: os trechos de cada zona, as três lutas fixas (no automático, todas vencidas), a porta
##   da zona abrindo só com a zona vencida, a de trás baixada, sem volta, o Nick entrando na equipe, o trem chegando e o
##   embarque levando à Estação.
extends RefCounted

const TIMEOUT := 30.0

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_data()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var real_tips: bool = Tips.enabled
	var real_briefing: bool = AHBriefing.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-tutorial-map-%d" % Time.get_ticks_usec()
	Campaign.state = Campaign.create_initial(5)
	await _journey()
	_release_all()
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state
	Tips.enabled = real_tips
	AHBriefing.enabled = real_briefing


func _data() -> void:
	t.check(AHScenarioWorld.exists(AHTutorial.MAP), "o mapa do tutorial existe em data/scenarios")
	t.equal(AHScenarioWorld.display_of(AHTutorial.MAP), "Corredor de Contenção", "o nome do lugar (decisão do Lucas)")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/%s.json" % AHTutorial.MAP))
	t.equal(data.zones.map(func(z): return z.name), ["Corredor de contenção", "Sala das celas", "Rota do Nick", "Plataforma"], "as quatro zonas")
	t.equal(data.security_doors.size(), 6, "as portas de segurança: a saída das três primeiras zonas e a entrada das três últimas")
	t.equal(data.props.map(func(p): return p.name), ["Armário de manutenção"], "a busca do tutorial é o armário de manutenção")
	t.check(not data.door_panel.is_empty() and int(data.train.zone) == 3, "o painel das portas e o trem na plataforma")
	t.check(data.lights.filter(func(l): return l.has("blink")).size() >= 6, "as lâmpadas de emergência piscam")
	# Toda peça tem textura (a coerência visual): só a lâmpada acesa é luz pura.
	for material in data.materials:
		if material.kind in ["art", "card", "surface", "blockout"]:
			t.check(ResourceLoader.exists(material.albedo), "a textura %s existe" % material.albedo)
	# A fase do tutorial joga como as outras, fora da lista das fases (o Mapa da Rede e o "Jogar de novo" leem a lista).
	t.check(not AHJourneyRules.PHASES.any(func(p): return p.id == AHTutorial.PHASE_ID), "o tutorial fora das fases da campanha")
	t.equal(AHJourneyRules.phase(AHTutorial.PHASE_ID).map, AHTutorial.MAP, "a fase do tutorial joga no Corredor de Contenção")
	t.check(not FileAccess.get_file_as_string("res://data/presentation/network_map.json").contains(AHTutorial.MAP), "o mapa fora do Mapa da Rede")
	t.equal(AHJourneyRules.step_range(AHTutorial.PHASE_ID, false), [0, 7], "os sete trechos no mapa")
	# O pisca: 0,6 s acesa e 0,4 s quase apagada, na fase de cada lâmpada.
	t.check(AHScenarioWorld.blink_lit(0.1, 0.0) and not AHScenarioWorld.blink_lit(0.7, 0.0) and AHScenarioWorld.blink_lit(0.7, 0.5),
		"a lâmpada acende 0,6 s e apaga 0,4 s, fora de fase da vizinha")


func _journey() -> void:
	if not t.check(AHTutorial.start_journey(Campaign.state), "a jornada do tutorial começa"):
		return
	var expedition: Dictionary = Campaign.state.session.expedition
	t.equal(expedition.team, ["hero_cao_bento"], "o Bento começa sozinho")
	var route: Dictionary = expedition.corridor
	t.equal(route.steps.map(func(s): return s.type), ["start", "combat", "nick", "loot", "combat", "combat", "train"], "os trechos do tutorial")
	Campaign.save()
	GameFlow.change_to("street", {}, false)
	if not await _until(func(): return _street() != null and not GameFlow.busy, "a rua abrir"):
		return
	var street = _street()
	var corridor: AHStreetCorridor = street.corridor
	t.equal(street.scenario.map_name, AHTutorial.MAP, "a rua abre no Corredor de Contenção")
	t.equal(corridor.segments.map(func(s): return s.steps), [2, 3, 1, 1], "os trechos de cada zona")
	t.equal(corridor.guards.keys(), [1, 4, 5], "as três patrulhas do tutorial")
	t.equal(corridor.guards[1].specs.map(func(s): return s.enemy_id), ["broto"], "a primeira luta: o Bento contra o Broto")
	t.equal(corridor.guards[4].specs.map(func(s): return s.enemy_id), ["rastejante_raiz"], "a segunda luta")
	t.equal(corridor.guards[5].specs.map(func(s): return s.enemy_id), ["ninho_errante"], "a terceira luta")
	# A HUD da abertura: o objetivo é o trem, a plaqueta diz Abertura (sem clima: é um subsolo).
	t.check(street.exploration_hud._goal_title.text.begins_with("Chegar ao trem"), "o objetivo da abertura é o trem")
	t.equal(street.exploration_hud._place_sub.text, "Abertura", "a plaqueta: Abertura, sem clima")
	# O Menu não tem volta à Estação: a saída é o trem; e a retirada direta também recusa.
	corridor.open_menu()
	await _frames(2)
	var back := street.exploration_hud.find_child("Return", true, false) as Button
	t.check(back != null and back.disabled, "no Menu, Voltar à Estação fica apagado")
	street.exploration_hud.close_modal()
	await _frames(2)
	corridor._retreat()
	await _frames(2)
	t.check(Campaign.state.session.result == "" and Campaign.state.station.last_return.is_empty(), "e a retirada não abandona a abertura")
	var metro: Node3D = street.scenario.get_node("Metro")
	t.check(not metro.visible, "o vagão só aparece quando chega")
	t.equal(corridor.scenario_props.map(func(e): return e.step), [3], "o armário fica no trecho da busca, antes da segunda luta")
	var exit0: int = street.scenario.doors_of(0, "exit")[0]
	t.check(not street.scenario.door_open(exit0), "a porta do fim do corredor fica baixada antes da primeira luta")
	await _fight(street)
	t.check(street.scenario.door_open(exit0), "vencida a primeira luta, a porta abre")
	# O Nick: o próximo passo é o encontro, e ele entra na equipe.
	corridor.debug_next_fight()
	await _frames(2)
	t.equal(Campaign.state.session.expedition.team, ["hero_cao_bento", "hero_gato_nick"], "o Nick entra na equipe")
	t.equal(street.party_ids, ["hero_cao_bento", "hero_gato_nick"], "e anda com o Bento")
	t.equal(corridor.segment, 1, "a sala das celas")
	t.check(not street.scenario.door_open(street.scenario.doors_of(1, "entry")[0]), "a porta de trás baixou")
	# Sem volta: andar para a esquerda até a ponta não leva de volta ao corredor.
	street._place_leader(Vector3(corridor.segments[1].x0 + 0.3, street.floor_y, street.lane_z))
	await _frames(4)
	t.equal(corridor.segment, 1, "as portas baixaram atrás: não há volta")
	t.check(not corridor._action.is_valid() or corridor._action.get_method() != "_retreat", "nem a volta à Estação pelo começo")
	await _fight(street)
	await _fight(street)
	t.check(route.steps.filter(func(s): return s.type == "combat" and s.resolved).size() == 3, "as três lutas vencidas em sequência, sem cura entre elas")
	t.check(Campaign.state.roster.filter(func(h): return Campaign.state.session.expedition.team.has(h.id)).all(func(h): return h.alive), "e ninguém cai")
	# A plataforma: o trem chega e para; o embarque leva à Estação.
	corridor.debug_next_fight()
	if not await _until(func(): return route.steps[6].resolved and not corridor.busy, "o trem parar na plataforma"):
		return
	t.equal(corridor.segment, 3, "a plataforma")
	t.check(metro.visible and absf(metro.position.x - float(street.scenario.train.x)) < 0.01, "o vagão chegou e parou")
	street._place_leader(Vector3(float(street.scenario.train.x), street.floor_y, street.lane_z))
	await _frames(3)
	t.check(corridor._train_point() != null and corridor._action.is_valid() and corridor._action.get_method() == "_board_train", "perto do vagão, o aviso é embarcar")
	corridor._action.call()
	if await _until(func(): return _tree.current_scene is AHStation and not GameFlow.busy, "o trem levar à Estação", 40.0):
		t.check(Campaign.state.session.expedition == null, "a jornada do tutorial terminou")


## Anda até a patrulha do trecho e luta no automático. Devolve se venceu.
func _fight(street) -> bool:
	street.corridor.debug_next_fight()
	await _frames(2)
	Input.action_press("move_right")
	var touched: bool = await _until(func(): return street._arena.active, "a equipe encostar na patrulha")
	Input.action_release("move_right")
	if not touched:
		return false
	var arena: AHCombatArena = street._arena
	arena.auto_battle = true
	arena.speed = 20.0
	if not await _until(func():
		if arena.hud.waiting:
			arena.hud.command_chosen.emit({"kind": "defend"})
		return not arena.active, "a luta terminar", 150.0):
		return false
	await _frames(2)
	var result: String = arena.session.result()
	t.equal(result, "victory", "a luta do tutorial é vencida no automático")
	return result == "victory"


func _street():
	var scene := _tree.current_scene
	return scene if scene != null and scene.get("corridor") != null and scene.corridor != null and not scene.corridor.segments.is_empty() else null


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


func _release_all() -> void:
	for action in ["move_left", "move_right", "move_back", "move_front", "run"]:
		Input.action_release(action)
