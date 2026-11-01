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
	# A conversa do Nick é da #144 (test_tutorial): aqui ele entra direto.
	AHBriefing.enabled = false
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
	t.equal(data.zones.map(func(z): return z.name), ["Corredor", "Celas", "Rota do Nick", "Plataforma"], "as quatro zonas (o mapa do PR #173)")
	t.equal(data.security_doors.map(func(d): return [int(d.zone), d.role]), [[2, "entry"]], "a porta de segurança: a da rota do Nick, que baixa atrás da equipe")
	t.equal(data.props.map(func(p): return p.name), ["Armário de manutenção"], "a busca do tutorial é o armário de manutenção")
	t.check(not data.door_panel.is_empty() and int(data.train.zone) == 3, "o painel das portas e o trem na plataforma")
	t.check(data.lights.filter(func(l): return l.has("blink")).size() >= 6, "as lâmpadas de emergência piscam")
	# O entulho do pé da faixa (entre a borda da zona e a câmera) é primeiro plano: some quando tapa alguém, na luta
	# também, em vez de pintar a silhueta do herói (a QA do tutorial, rodada 2). Os outros mapas não marcam peça.
	var front: Array = []
	for part in data.parts:
		for zone in data.zones:
			if float(part.origin[0]) >= float(zone.x0) and float(part.origin[0]) <= float(zone.x1) \
					and float(part.origin[2]) > float(zone.z1) and data.materials[int(part.materials[0])].kind == "art":
				front.append(part)
	t.check(front.size() >= 3 and front.all(func(p): return p.get("foreground", false)), "o entulho à frente da faixa é primeiro plano (%d peças)" % front.size())
	for other in ["RiverDock", "RootBridge", "SealedShelter", "TriageGate", "FloodedDepot", "SewerDucts"]:
		t.check(not FileAccess.get_file_as_string("res://data/scenarios/%s.json" % other).contains("\"foreground\""), "%s sem peça marcada de primeiro plano" % other)
	# Toda peça tem textura (a coerência visual): só a lâmpada acesa é luz pura.
	for material in data.materials:
		if material.kind in ["art", "card", "surface", "blockout"]:
			t.check(ResourceLoader.exists(material.albedo), "a textura %s existe" % material.albedo)
	# A fase do tutorial joga como as outras, fora da lista das fases (o Mapa da Rede e o "Jogar de novo" leem a lista).
	t.check(not AHJourneyRules.PHASES.any(func(p): return p.id == AHTutorial.PHASE_ID), "o tutorial fora das fases da campanha")
	t.equal(AHJourneyRules.phase(AHTutorial.PHASE_ID).map, AHTutorial.MAP, "a fase do tutorial joga no Corredor de Contenção")
	t.check(not FileAccess.get_file_as_string("res://data/presentation/network_map.json").contains(AHTutorial.MAP), "o mapa fora do Mapa da Rede")
	t.equal(AHJourneyRules.step_range(AHTutorial.PHASE_ID, false), [0, 7], "os sete trechos no mapa")
	# Cada inimigo das lutas do tutorial existe em enemies.json (senão a luta ficaria mais curta sem aviso).
	for row_name in GameData.table("tutorial"):
		if String(row_name).begins_with("fight_"):
			var ids: Array = GameData.row("tutorial", row_name).get("Enemies", [])
			t.check(not ids.is_empty() and ids.all(func(id): return GameData.row("enemies", id) != null),
				"%s: os inimigos existem em enemies.json (%s)" % [row_name, ids])
			# O Boost pode tirar dano (a luta 2 e o Drone), mas nunca deixa um golpe sem dano ou curando.
			var boost: Dictionary = GameData.row("tutorial", row_name).get("Boost", {})
			for id in boost:
				var damage := int(boost[id].get("Damage", 0))
				for action_id in GameData.row("enemies", id).ActionIds:
					var range = GameData.row("enemy_actions", action_id).get("DamageRange")
					if range != null and int(range.Max) > 0:
						t.check(int(range.Min) + damage >= 1, "%s: o Boost de %s deixa %s com dano 1 ou mais" % [row_name, id, action_id])
	_finish_heals_team()
	# O pisca: 0,6 s acesa e 0,4 s quase apagada, na fase de cada lâmpada.
	t.check(AHScenarioWorld.blink_lit(0.1, 0.0) and not AHScenarioWorld.blink_lit(0.7, 0.0) and AHScenarioWorld.blink_lit(0.7, 0.5),
		"a lâmpada acende 0,6 s e apaga 0,4 s, fora de fase da vizinha")


## O embarque cura só a equipe que foi ao tutorial; o resto do elenco fica como está.
func _finish_heals_team() -> void:
	var c := Campaign.create_initial(5)
	var hurt: Array = []
	for hero in c.roster:
		hero.hp = 1
		hero.instinct = 30
		hurt.append(hero.id)
	var team: Array = hurt.slice(0, 2)
	c.session = {"screen": "street", "result": "", "expedition": {"team": team}, "event": null}
	AHTutorial.finish(c)
	t.check(c.roster.filter(func(h): return team.has(h.id)).all(func(h): return h.hp == int(h.max_hp) and h.instinct == 0),
		"o embarque cura a equipe do tutorial")
	t.check(c.roster.filter(func(h): return not team.has(h.id)).all(func(h): return h.hp == 1 and h.instinct == 30),
		"e não mexe no resto do elenco")


func _journey() -> void:
	if not t.check(AHTutorial.start_journey(Campaign.state), "a jornada do tutorial começa"):
		return
	var expedition: Dictionary = Campaign.state.session.expedition
	t.equal(expedition.team, ["hero_cao_bento", "hero_sapo_iris", "hero_coruja_vespera"], "o Bento começa com a Íris e a Véspera")
	var route: Dictionary = expedition.corridor
	t.equal(route.steps.map(func(s): return s.type), ["start", "combat", "nick", "combat", "loot", "combat", "train"], "os trechos do tutorial")
	Campaign.save()
	GameFlow.change_to("street", {}, false)
	if not await _until(func(): return _street() != null and not GameFlow.busy, "a rua abrir"):
		return
	var street = _street()
	var corridor: AHStreetCorridor = street.corridor
	t.equal(street.scenario.map_name, AHTutorial.MAP, "a rua abre no Corredor de Contenção")
	t.equal(corridor.segments.map(func(s): return s.steps), [2, 3, 1, 1], "os trechos de cada zona")
	t.equal(corridor.guards.keys(), [1, 3, 5], "as três patrulhas do tutorial")
	t.equal(corridor.guards[1].specs.map(func(s): return s.enemy_id), ["broto", "faisca", "pipoco"], "a primeira luta: os três contra três pequenos")
	t.equal(corridor.guards[3].specs.map(func(s): return s.enemy_id), ["rastejante_raiz", "broto"], "a segunda luta")
	t.equal(corridor.guards[5].specs.map(func(s): return s.enemy_id), ["faisca", "ninho_errante"], "a terceira luta")
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
	t.equal(corridor.scenario_props.map(func(e): return e.step), [4], "o armário fica no trecho da busca, depois da segunda luta")
	var route_door: int = street.scenario.doors_of(2, "entry")[0]
	await _fight(street)
	# O Nick: o próximo passo é o encontro, e ele entra na equipe.
	corridor.debug_next_fight()
	await _frames(2)
	t.equal(Campaign.state.session.expedition.team, ["hero_cao_bento", "hero_sapo_iris", "hero_coruja_vespera", "hero_gato_nick"], "o Nick entra na equipe")
	t.equal(street.party_ids, ["hero_cao_bento", "hero_sapo_iris", "hero_coruja_vespera", "hero_gato_nick"], "e a equipe anda com os quatro")
	t.equal(corridor.segment, 1, "a sala das celas")
	# Sem volta: andar para a esquerda até a ponta não leva de volta ao corredor.
	street._place_leader(Vector3(corridor.segments[1].x0 + 0.3, street.floor_y, street.lane_z))
	await _frames(4)
	t.equal(corridor.segment, 1, "as portas baixaram atrás: não há volta")
	t.check(not corridor._action.is_valid() or corridor._action.get_method() != "_retreat", "nem a volta à Estação pelo começo")
	await _fight(street)
	await _fight(street)
	t.equal(corridor.segment, 2, "a rota do Nick")
	t.check(not street.scenario.door_open(route_door), "a porta de segurança baixou atrás da equipe")
	t.check(route.steps.filter(func(s): return s.type == "combat" and s.resolved).size() == 3, "as três lutas vencidas em sequência, sem a busca (e o fôlego dela) no meio")
	t.check(Campaign.state.roster.filter(func(h): return Campaign.state.session.expedition.team.has(h.id)).all(func(h): return h.alive), "e ninguém cai")
	# A plataforma: o trem chega e para; o embarque leva à Estação.
	corridor.debug_next_fight()
	if not await _until(func(): return route.steps[6].resolved and not corridor.busy, "o trem parar na plataforma"):
		return
	t.equal(corridor.segment, 3, "a plataforma")
	# O nó do vagão fica na origem (as peças estão no lugar delas no mapa): parado, ele volta ao zero.
	t.check(metro.visible and metro.position.is_zero_approx() and metro.get_child_count() > 0, "o vagão chegou e parou")
	# O vagão em camadas (#256) no lugar do card: parado com as portas abertas.
	var car: AHTrainCar = street.scenario.train_car
	t.check(car != null and car.get_parent() == metro and is_equal_approx(car.doors_open(), 1.0), "o vagão em camadas, com as portas abertas")
	street._place_leader(Vector3(float(street.scenario.train.x), street.floor_y, street.lane_z))
	await _frames(3)
	t.check(corridor._train_point() != null and corridor._action.is_valid() and corridor._action.get_method() == "_board_train", "perto do vagão, o aviso é embarcar")
	corridor._action.call()
	# O embarque (#256): a equipe entra pela porta, as portas fecham antes de o vagão andar, e ele parte com todos
	# dentro (entre o interior e a carroceria, dentro do comprimento do vagão).
	if await _until(func(): return metro.position.x > 0.3, "o vagão partir", 20.0):
		t.check(car.doors_open() <= 0.0, "as portas fecham antes de o vagão andar")
		var x0: float = car.global_position.x - car.length() * 0.5
		var inside_z: float = car.global_position.z + car.inside_z()
		var inside := true
		for hero in street._heroes:
			var at: Vector3 = hero.global_position
			inside = inside and at.x > x0 and at.x < x0 + car.length() and absf(at.z - inside_z) < 0.2
		t.check(inside, "a equipe inteira vai dentro do vagão")
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
