## O que a barra de Admin faz (#130, como o AHAdminWidget da Unreal): cada ação tem a aba, o texto do botão, onde vale
## ("any", "street": na jornada, "explore": na jornada fora da luta, "station", "fight": na vez de um herói,
## "campaign": com uma campanha aberta) e se mexe no save. run devolve o aviso curto
## do que fez ("" quando não deu, com o motivo em reason).
class_name AHAdminActions
extends RefCounted

const J = preload("res://scripts/flow/journey_rules.gd")
const S = preload("res://scripts/flow/station_rules.gd")

const TABS := ["Mapas", "Clima", "Ajustes", "Recursos", "Heróis", "Combate", "Jornada"]
## Os tempos da rua (journey_rules.WEATHERS) com o nome na tela.
const WEATHER_NAMES := {"clear": "Céu limpo", "sunset": "Pôr do sol", "mist": "Névoa", "night": "Noite",
	"rain": "Chuva", "storm": "Tempestade", "nightRain": "Noite com chuva"}
## A câmera (multiplica a distância da rua e da luta, e o campo de visão da Estação).
const ZOOM_STEP := 0.1
const ZOOM_RANGE := Vector2(0.6, 1.6)


## As ações, na ordem das abas. Cada uma: {id, tab, label, where, save}.
static func all() -> Array:
	var out: Array = []
	for phase in J.PHASES:
		out.append(_a("map_%s" % phase.id, "Mapas", phase.name, "campaign", true))
		if String(phase.get("transit", "")) != "":
			out.append(_a("map_%s_main" % phase.id, "Mapas", "%s (o mapa da fase)" % phase.name, "campaign", true))
	out.append(_a("map_station", "Mapas", "Estação", "campaign", true))
	for weather in WEATHER_NAMES:
		out.append(_a("weather_%s" % weather, "Clima", WEATHER_NAMES[weather], "street", false))
	out.append(_a("time_toggle", "Clima", "Trocar dia e noite", "street", false))
	out.append(_a("rain_toggle", "Clima", "Ligar ou desligar a chuva", "street", false))
	for spec in [["explore", "Câmera da exploração"], ["fight", "Câmera da luta"], ["station", "Câmera da Estação"]]:
		var now := roundi(float(Admin.camera_zoom.get(spec[0], 1.0)) * 100.0)
		out.append(_a("zoom_%s_in" % spec[0], "Ajustes", "%s: mais perto (agora %d%%)" % [spec[1], now], "any", false))
		out.append(_a("zoom_%s_out" % spec[0], "Ajustes", "%s: mais longe (agora %d%%)" % [spec[1], now], "any", false))
	out.append(_a("zoom_reset", "Ajustes", "Câmeras como antes", "any", false))
	for speed in [1, 2, 4]:
		out.append(_a("speed_%d" % speed, "Ajustes", "Velocidade da luta %dx%s" % [speed, " (agora)" if int(Admin.battle_speed) == speed else ""], "any", false))
	out.append(_a("speed_0", "Ajustes", "Velocidade da luta: a das Opções%s" % (" (agora)" if Admin.battle_speed <= 0.0 else ""), "any", false))
	out.append(_a("post_toggle", "Ajustes", "Pós-processamento", "street", false))
	out.append(_a("colliders_toggle", "Ajustes", "Mostrar as colisões", "street", false))
	for quality in 4:
		out.append(_a("quality_%d" % quality, "Ajustes", "Qualidade: %s%s" % [["Baixa", "Média", "Alta", "Ultra"][quality], " (agora)" if Settings.level == quality else ""], "any", false))
	out.append(_a("old_keys", "Ajustes", "Teclas de teste da rua (R T P C K)", "any", false))
	for spec in [["seeds", 20, "Sementes"], ["scrap", 10, "Sucata"], ["fragments", 5, "Fragmentos"], ["bandages", 5, "Curativos"],
			["food", 4, "Comida da jornada"], ["water", 5, "Água da Estação"]]:
		out.append(_a("add_%s" % spec[0], "Recursos", "+%d %s" % [spec[1], spec[2]], "campaign", true))
	out.append(_a("heal_team", "Heróis", "Curar todos (vida, instinto e trauma)", "campaign", true))
	out.append(_a("xp_team", "Heróis", "+100 de XP em todos", "campaign", true))
	out.append(_a("level_team", "Heróis", "Todos sobem um nível", "campaign", true))
	out.append(_a("recruit_now", "Heróis", "Recrutar agora", "campaign", true))
	out.append(_a("revive_all", "Heróis", "Trazer de volta quem morreu", "campaign", true))
	out.append(_a("next_patrol", "Combate", "Próxima patrulha", "explore", true))
	out.append(_a("breakthrough", "Combate", "Forçar Superação em quem age", "fight", false))
	out.append(_a("collapse", "Combate", "Forçar Colapso em quem age", "fight", false))
	out.append(_a("instinct_50", "Combate", "+50 de Instinto em quem age", "fight", false))
	out.append(_a("fight_win", "Combate", "Vencer a luta", "fight", true))
	out.append(_a("fight_lose", "Combate", "Perder a luta (quem lutou cai de vez)", "fight", true))
	out.append(_a("fight_flee", "Combate", "Fugir da luta", "fight", true))
	for enemy_id in _enemy_ids():
		out.append(_a("enemy_%s" % enemy_id, "Combate", "Lutar contra %s" % TranslationServer.translate(String(GameData.row("enemies", enemy_id).DisplayName)), "explore", true))
	out.append(_a("phase_finish", "Jornada", "Concluir a fase da jornada", "explore", true))
	out.append(_a("phase_reset", "Jornada", "Desfazer as fases concluídas", "campaign", true))
	out.append(_a("phase_unlock", "Jornada", "Liberar todas as fases", "campaign", true))
	out.append(_a("rooms_all", "Jornada", "Recuperar todos os cômodos", "campaign", true))
	out.append(_a("night_skip", "Jornada", "Pular a noite e o amanhecer", "station", true))
	for event_id in _event_ids():
		var row = GameData.row("events", event_id)
		out.append(_a("event_%s" % event_id, "Jornada", "Evento: %s" % TranslationServer.translate(String(row.get("Title", event_id))), "explore", true))
	return out


static func _a(id: String, tab: String, label: String, where: String, save: bool) -> Dictionary:
	return {"id": id, "tab": tab, "label": label, "where": where, "save": save}


static func _enemy_ids() -> Array:
	var ids: Array = GameData.table("enemies").keys()
	ids.sort()
	return ids


static func _event_ids() -> Array:
	var ids: Array = GameData.table("events").keys()
	ids.sort()
	return ids


## Onde a ação vale agora (a cena aberta e a campanha), ou o motivo de não valer.
static func blocked(action: Dictionary) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := tree.current_scene if tree != null else null
	var street := scene != null and scene.name == "Street"
	var fight: bool = street and scene._arena != null and scene._arena.active
	match String(action.where):
		"street":
			if not street:
				return TranslationServer.translate("Só na jornada")
		"explore":
			if not street:
				return TranslationServer.translate("Só na jornada")
			if fight:
				return TranslationServer.translate("Fora da luta")
		"station":
			if not scene is AHStation:
				return TranslationServer.translate("Só na Estação")
		"fight":
			if not fight or not scene._arena.hud.waiting:
				return TranslationServer.translate("Só na vez de um herói, na luta")
		"campaign":
			if Campaign.state.is_empty() or not Campaign.state.has("roster"):
				return TranslationServer.translate("Sem campanha aberta")
	return ""


## Faz a ação. Devolve o aviso curto ("" quando nada mudou).
static func run(id: String) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := tree.current_scene
	var c: Dictionary = Campaign.state
	if id.begins_with("map_"):
		return _map(id.trim_prefix("map_"))
	if id.begins_with("weather_"):
		var weather := id.trim_prefix("weather_")
		scene.apply_corridor_weather(weather)
		return TranslationServer.translate("Tempo: %s") % TranslationServer.translate(WEATHER_NAMES[weather])
	if id.begins_with("zoom_"):
		return _zoom(id.trim_prefix("zoom_"))
	if id.begins_with("speed_"):
		var speed := int(id.trim_prefix("speed_"))
		Admin.battle_speed = float(speed)
		# Na luta aberta, já vale agora; a escolha das Opções do jogador não muda.
		var arena = scene.get("_arena") if scene != null else null
		if arena != null and arena.active:
			arena.speed = float(speed) if speed > 0 else float(clampi(int(c.get("settings", {}).get("battle_speed", 1)), 1, 2))
		return TranslationServer.translate("Velocidade da luta: a das Opções") if speed == 0 else TranslationServer.translate("Velocidade da luta: %dx") % speed
	if id.begins_with("quality_"):
		Settings.set_level(int(id.trim_prefix("quality_")))
		return TranslationServer.translate("Qualidade trocada")
	if id.begins_with("add_"):
		return _add(id.trim_prefix("add_"))
	if id.begins_with("enemy_"):
		Admin.next_enemy = id.trim_prefix("enemy_")
		var enemy_name := TranslationServer.translate(String(GameData.row("enemies", Admin.next_enemy).DisplayName))
		# Só vale se parou na frente de uma patrulha: parando num evento da Passagem (ou viajando de mapa), o inimigo
		# escolhido não fica armado para uma luta que o jogador não pediu.
		var stopped: bool = scene.corridor.debug_next_fight()
		var route: Dictionary = c.session.expedition.corridor if c.session.get("expedition") != null else {}
		if not stopped or c.session.get("event") != null or route.is_empty() or not scene.corridor.guards.has(int(route.index)):
			Admin.next_enemy = ""
			return ""
		return TranslationServer.translate("A próxima patrulha vem com %s") % enemy_name
	if id.begins_with("event_"):
		c.session.event = {"event_id": id.trim_prefix("event_"), "from_search": true, "resolution": "", "pending_hard_combat": false, "object": ""}
		scene.exploration_hud.show_event(c)
		return TranslationServer.translate("Evento aberto")
	match id:
		"time_toggle":
			scene._mood = "night" if scene._mood == "golden" else "golden"
			scene._apply_weather()
			return TranslationServer.translate("Dia e noite trocados")
		"rain_toggle":
			scene._raining = not scene._raining
			scene._apply_weather()
			return TranslationServer.translate("Chuva ligada") if scene._raining else TranslationServer.translate("Chuva desligada")
		"post_toggle":
			scene._post.set_shader_parameter("enabled", not scene._post.get_shader_parameter("enabled"))
			return TranslationServer.translate("Pós-processamento trocado")
		"colliders_toggle":
			for debug in scene._debug_colliders:
				debug.visible = not debug.visible
			return TranslationServer.translate("Colisões trocadas")
		"old_keys":
			Settings.set_dev_mode(not Settings.dev_mode)
			return TranslationServer.translate("Teclas de teste ligadas") if Settings.dev_mode else TranslationServer.translate("Teclas de teste desligadas")
		"heal_team":
			for hero in c.roster:
				if hero.get("alive", true):
					hero.hp = int(hero.max_hp)
					hero.instinct = 0
					hero.trauma = false
			return _saved(TranslationServer.translate("Todos curados"))
		"xp_team":
			for hero in c.roster:
				if hero.get("alive", true):
					AHHeroLevels.gain(hero, 100)
			return _saved(TranslationServer.translate("+100 de XP em todos"))
		"level_team":
			var raised := 0
			for hero in c.roster:
				if hero.get("alive", true) and AHHeroLevels.level(hero) < AHHeroLevels.MAX_LEVEL:
					var row = GameData.row("hero_levels", "level_%d" % (AHHeroLevels.level(hero) + 1))
					AHHeroLevels.gain(hero, maxi(0, int(row.Xp) - AHHeroLevels.xp(hero)) if row != null else 0)
					raised += 1
			return _saved(TranslationServer.translate("%d herói(s) prontos para subir de nível no Alojamento") % raised)
		"recruit_now":
			return _recruit()
		"revive_all":
			var back := 0
			for hero in c.roster:
				if not hero.get("alive", true):
					hero.alive = true
					hero.hp = int(hero.max_hp)
					back += 1
			c.memorial = []
			return _saved(TranslationServer.translate("%d herói(s) de volta") % back)
		"next_patrol":
			return TranslationServer.translate("Indo para a próxima patrulha") if scene.corridor.debug_next_fight() else ""
		"breakthrough", "collapse":
			return _crisis(scene._arena, id == "collapse")
		"instinct_50":
			var actor: AHCombat.Unit = scene._arena.session.current_actor()
			actor.instinct = mini(int(scene._arena.session.engine.instinct_rules().Max), actor.instinct + 50)
			scene._arena.hud.refresh()
			return TranslationServer.translate("+50 de Instinto em %s") % actor.display_name
		"fight_win", "fight_lose", "fight_flee":
			return _end_fight(scene._arena, id.trim_prefix("fight_"))
		"phase_finish":
			c.session.expedition.objective_completed = true
			var route: Dictionary = c.session.expedition.corridor
			for step in route.steps:
				step.resolved = true
			route.index = route.steps.size() - 1
			J.safe_retreat(c)
			scene.corridor._show_result()
			return _saved(TranslationServer.translate("Fase concluída"))
		"phase_reset":
			c.completed_phases = []
			return _saved(TranslationServer.translate("Fases concluídas desfeitas"))
		"phase_unlock":
			c.completed_phases = J.PHASES.slice(0, J.PHASES.size() - 1).map(func(p): return p.id)
			return _saved(TranslationServer.translate("Todas as fases liberadas"))
		"rooms_all":
			for room in S.ROOMS:
				c.station.rooms[room.id] = maxi(1, int(c.station.rooms.get(room.id, 0)))
			_refresh_station(scene)
			return _saved(TranslationServer.translate("Todos os cômodos recuperados"))
		"night_skip":
			var night := S.resolve_night(c)
			var dawn := S.finish_dawn(c)
			if not night and not dawn:
				return ""
			_refresh_station(scene)
			return _saved(TranslationServer.translate("A noite e o amanhecer passaram"))
	return ""


static func _saved(text: String) -> String:
	Campaign.save()
	return text


static func _refresh_station(scene: Node) -> void:
	if scene is AHStation and scene.hud != null:
		scene.hud.refresh()


## Ir direto a um mapa: uma expedição nova na fase (com a equipe da formação) ou a Estação.
static func _map(target: String) -> String:
	var c: Dictionary = Campaign.state
	if GameFlow.busy:
		return ""
	# A cena troca com o jogo andando (a barra pausada seguraria a nova).
	Admin.close()
	if target == "station":
		c.session = {"expedition": null, "event": null, "screen": "", "result": ""}
		Campaign.save()
		GameFlow.change_to("station")
		return TranslationServer.translate("Indo para a Estação")
	var main := target.ends_with("_main")
	var phase_id := target.trim_suffix("_main")
	if not J.start_expedition(c, phase_id, randi()):
		return ""
	if main:
		var info := J.phase(phase_id)
		var route: Dictionary = c.session.expedition.corridor
		route.index = int(info.transit_steps)
		for i in route.index:
			route.steps[i].resolved = true
	Campaign.save()
	GameFlow.change_to("street")
	return TranslationServer.translate("Indo para %s") % TranslationServer.translate(String(J.phase(phase_id).name))


static func _zoom(spec: String) -> String:
	if spec == "reset":
		Admin.camera_zoom = {"explore": 1.0, "fight": 1.0, "station": 1.0}
		return TranslationServer.translate("Câmeras como antes")
	var parts := spec.split("_")
	var key := parts[0]
	var step := -ZOOM_STEP if parts[1] == "in" else ZOOM_STEP
	Admin.camera_zoom[key] = clampf(snappedf(float(Admin.camera_zoom.get(key, 1.0)) + step, 0.01), ZOOM_RANGE.x, ZOOM_RANGE.y)
	return TranslationServer.translate("Câmera: %d%% da distância") % roundi(Admin.camera_zoom[key] * 100.0)


static func _add(kind: String) -> String:
	var c: Dictionary = Campaign.state
	match kind:
		"seeds", "scrap", "fragments":
			c.inventory[kind] = int(c.inventory.get(kind, 0)) + {"seeds": 20, "scrap": 10, "fragments": 5}[kind]
		"bandages":
			c.inventory.bandages = int(c.inventory.get("bandages", 0)) + 5
		"food":
			var expedition = c.get("session", {}).get("expedition")
			if expedition == null:
				return ""
			expedition.food = mini(J.MAX_FOOD, int(expedition.food) + 4)
		"water":
			c.station.water = int(c.station.get("water", 0)) + 5
	return _saved(TranslationServer.translate("Recurso somado"))


## Recruta na hora, de graça, uma classe liberada (o nome dado pula o custo e a cota de voluntários; o limite de vivos
## da Estação vale).
static func _recruit() -> String:
	var c: Dictionary = Campaign.state
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if S.living(c).size() >= S.MAX_ROSTER:
		return ""
	for class_id in c.get("unlocked_classes", []):
		var hero := S.recruit(c, class_id, rng, S.hero_name(c, class_id))
		if String(hero.get("error", "x")) == "":
			var made = Campaign.hero(String(hero.hero_id))
			return _saved(TranslationServer.translate("%s chegou à Estação") % String(made.display_name if made != null else hero.hero_id))
	return ""


## A crise de quem age, com o resultado escolhido (o sorteio da crise trocado por um que dá sempre o mesmo).
static func _crisis(arena: AHCombatArena, collapse: bool) -> String:
	var actor: AHCombat.Unit = arena.session.current_actor()
	var engine: AHCombatEngine = arena.session.engine
	if not actor.is_player or engine.is_machine(actor):
		return ""
	var real := engine.random
	engine.random = AHAdminRandom.new(0.9999 if collapse else 0.0)
	actor.instinct = int(engine.instinct_rules().Max)
	engine._crisis_batch.erase(actor.id)
	var events: Array = []
	engine._apply_instinct_crisis(actor, events)
	engine.random = real
	arena._play_beat({"source_id": actor.id, "kind": "turn_start", "ability_id": "", "events": events, "ok": true, "error": ""})
	arena.hud.refresh()
	return TranslationServer.translate("Colapso em %s") % actor.display_name if collapse else TranslationServer.translate("Superação em %s") % actor.display_name


## Termina a luta já decidida: a vez do herói fecha com um Defender, e a arena segue para o fim.
static func _end_fight(arena: AHCombatArena, how: String) -> String:
	var state: AHCombat.State = arena.session.state
	match how:
		"win":
			for unit in state.enemy_team:
				unit.hp = 0
			state.victory = true
		"lose":
			for unit in state.player_team:
				unit.hp = 0
				unit.deaths_door = false
			state.victory = false
		"flee":
			state.escaped = true
	state.is_over = true
	arena.hud.command_chosen.emit({"kind": "defend"})
	return {"win": TranslationServer.translate("Luta vencida"), "lose": TranslationServer.translate("Luta perdida"), "flee": TranslationServer.translate("A equipe fugiu")}[how]
