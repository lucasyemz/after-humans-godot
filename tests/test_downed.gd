## Os caídos no mapa (#179): quem cai na luta fica deitado no lugar dela; levantado, segue carregado e chega à Estação
## com menos dias de recuperação (data/recovery.json, carried); deixado, chega com os dias inteiros. O aviso depois da
## luta, o lembrete da volta e o resumo dizem a mesma coisa.
extends RefCounted

const J := preload("res://scripts/flow/journey_rules.gd")
const S := preload("res://scripts/flow/station_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_rules()
	_recovery()
	_delivered()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-downed-%d" % Time.get_ticks_usec()
	_save_roundtrip()
	await _scene()
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Tips.enabled = tips
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _campaign(seed_value: int) -> Dictionary:
	var c: Dictionary = Campaign.create_initial(seed_value)
	J.start_expedition(c, "fase_1", seed_value)
	return c


func _fell(c: Dictionary, hero_id: String) -> void:
	for hero in c.roster:
		if hero.id == hero_id:
			hero.alive = false
			hero.hp = 0


## mark_downed guarda quem caiu (uma vez), com o mapa, o lugar e a casa; lift passa o caído para os carregados.
func _rules() -> void:
	var c := _campaign(179)
	var team: Array = c.session.expedition.team
	t.equal(J.mark_downed(c, {}, "street"), [], "sem ninguém caído, nada fica no mapa")
	_fell(c, team[1])
	var fresh := J.mark_downed(c, {team[1]: Vector3(12.5, 0.0, -0.4)}, "grocery", 2)
	t.equal(fresh, [team[1]], "quem caiu na luta fica no mapa")
	var entry: Dictionary = J.downed_left(c)[0]
	t.check(entry.map == "grocery" and is_equal_approx(float(entry.x), 12.5) and is_equal_approx(float(entry.z), -0.4) and int(entry.house) == 2,
		"no lugar onde estava, no mapa e na casa da luta")
	t.equal(J.mark_downed(c, {}, "grocery"), [], "a luta seguinte não marca de novo quem já está no chão")
	t.equal(J.downed_left(c).size(), 1, "e ele fica uma vez só")
	t.check(not J.lift(c, team[0]), "quem está de pé não é levantado")
	t.check(J.lift(c, team[1]), "levantar o caído")
	t.check(J.downed_left(c).is_empty() and J.carried(c) == [team[1]], "sai do mapa e segue carregado")
	t.check(not J.lift(c, team[1]), "e não é levantado duas vezes")
	_fell(c, team[2])
	t.equal(J.mark_downed(c, {team[1]: Vector3(14, 0, 0), team[2]: Vector3(15, 0, 0)}, "grocery"), [team[2]], "outro que cai depois entra no mapa; o carregado, não")
	t.check(not c.roster.filter(func(h): return h.id == team[1])[0].alive, "o carregado segue fora das lutas (caído)")
	# O save de antes do #179: quem já tinha caído (fora de places, a luta de agora) não volta a cair, nem na origem.
	var old := _campaign(1795)
	_fell(old, old.session.expedition.team[1])
	t.equal(J.mark_downed(old, {}, "street"), [], "save antigo: quem caiu antes não é marcado de novo numa luta sem queda")
	t.check(J.downed_left(old).is_empty(), "e não aparece corpo na origem do mapa")


## Os dias de recuperação batem com o recovery.json: o carregado chega com a parte (Factor, para cima, mínimo 1), na
## Enfermaria e no Dormitório; o deixado, com os dias inteiros.
func _recovery() -> void:
	var factor := float(S.recovery_rule("carried").get("Factor", 1.0))
	t.check(factor > 0.0 and factor < 1.0, "o recovery.json tem a regra do carregado (Factor %.2f)" % factor)
	for beds in [0, 1]:
		var plain := _campaign(1790 + beds)
		var lifted := _campaign(1790 + beds)
		for c in [plain, lifted]:
			c.station.rooms[S.INFIRMARY] = beds
		var hero_id: String = plain.session.expedition.team[0]
		_fell(plain, hero_id)
		_fell(lifted, hero_id)
		var full: Array = S.admit_fallen(plain, [hero_id])
		var part: Array = S.admit_fallen(lifted, [hero_id], [hero_id])
		var where := "na Enfermaria" if full[0].bed else "no Dormitório"
		t.check(full[0].bed == (beds > 0) and part[0].bed == full[0].bed, "%s: os dois no mesmo lugar" % where)
		t.equal(part[0].days, maxi(1, ceili(full[0].days * factor)),
			"%s: deixado, %d dias; carregado, %d (recovery.json)" % [where, full[0].days, part[0].days])
		t.check(part[0].carried and not full[0].carried, "%s: o resumo sabe quem foi carregado" % where)
		t.check(part[0].days < full[0].days or full[0].days == 1, "%s: levantar encurta a recuperação" % where)
	# O carregado que chega ao Dormitório e ganha um leito depois também fica com a parte dos dias do leito (decisão do
	# Lucas, 28/10).
	var later := _campaign(1797)
	later.station.rooms[S.INFIRMARY] = 0
	var late_id: String = later.session.expedition.team[0]
	_fell(later, late_id)
	var arrived: Array = S.admit_fallen(later, [late_id], [late_id])
	later.station.rooms[S.INFIRMARY] = 1
	S._fill_beds(later)
	var bed_days := int(S.recovery_rule("infirmary").get("Days", 2))
	var hero_late = later.roster.filter(func(h): return h.id == late_id)[0]
	t.check(not arrived[0].bed and S.in_bed(hero_late), "o carregado do Dormitório ganha um leito depois")
	t.equal(S.recovery_days(hero_late), maxi(1, ceili(bed_days * factor)), "e fica com a parte dos dias do leito (%d)" % S.recovery_days(hero_late))
	# Sem a regra carried no recovery.json (um dado antigo), o fator é 1: o carregado chega com os dias inteiros.
	var rules: Dictionary = GameData.table("recovery")
	var kept = rules.get("carried")
	rules.erase("carried")
	var plain2 := _campaign(1796)
	var lifted2 := _campaign(1796)
	var id2: String = plain2.session.expedition.team[0]
	_fell(plain2, id2)
	_fell(lifted2, id2)
	t.equal(S.admit_fallen(lifted2, [id2], [id2])[0].days, S.admit_fallen(plain2, [id2])[0].days,
		"sem a regra carried, o carregado chega com os dias inteiros (fator 1)")
	if kept != null:
		rules["carried"] = kept


## A volta: finish_return entrega os caídos com o carregado marcado e os dias de cada um.
func _delivered() -> void:
	var c := _campaign(1793)
	var team: Array = c.session.expedition.team
	_fell(c, team[1])
	_fell(c, team[2])
	J.mark_downed(c, {team[1]: Vector3(3, 0, 0), team[2]: Vector3(4, 0, 0)}, "street")
	J.lift(c, team[1])
	c.session.screen = "corridor"
	t.check(J.safe_retreat(c), "a equipe volta")
	var delivered: Dictionary = J.finish_return(c)
	var by_id := {}
	for entry in delivered.get("fallen", []):
		by_id[entry.hero_id] = entry
	t.check(by_id.has(team[1]) and by_id[team[1]].carried, "o levantado chega carregado")
	t.check(by_id.has(team[2]) and not by_id[team[2]].carried, "o deixado chega pela recuperação inteira")
	t.check(by_id.get(team[1], {}).get("days", 0) <= by_id.get(team[2], {}).get("days", 0), "com menos dias (ou iguais, no mínimo)")
	t.check(c.roster.filter(func(h): return h.id == team[1])[0].alive, "e os dois voltam vivos à Estação")


## O save guarda quem está no chão e quem foi levantado.
func _save_roundtrip() -> void:
	Campaign.state = _campaign(1794)
	var team: Array = Campaign.state.session.expedition.team
	_fell(Campaign.state, team[1])
	_fell(Campaign.state, team[2])
	J.mark_downed(Campaign.state, {team[1]: Vector3(30.25, 0, -0.5), team[2]: Vector3(31, 0, -0.5)}, "street")
	J.lift(Campaign.state, team[2])
	t.check(Campaign.save(), "o save grava")
	var back = Campaign.read_file(Campaign.primary_path())
	if not t.check(back != null, "e abre de novo"):
		return
	var left: Array = J.downed_left(back)
	t.check(left.size() == 1 and left[0].hero_id == team[1] and is_equal_approx(float(left[0].x), 30.25), "o caído continua no mesmo lugar")
	t.equal(J.carried(back), [team[2]], "e o levantado continua carregado")


func _scene() -> void:
	Campaign.state = Campaign.create_initial(6)
	J.start_expedition(Campaign.state, "fase_1", 4242)
	GameFlow.change_to("street", {}, false)
	var street = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			street = _tree.current_scene
			break
	if not t.check(street != null, "a rua abre"):
		return
	var corridor = street.corridor
	corridor.debug_next_fight()
	await _frames(10)
	var route: Dictionary = Campaign.state.session.expedition.corridor
	if not t.check(corridor.guards.has(route.index), "há patrulha para a luta"):
		return
	corridor._start_fight(route.index, true)
	var arena: AHCombatArena = street._arena
	for i in 900:
		if arena.hud != null and arena.hud.waiting:
			break
		await _tree.process_frame
	if not t.check(arena.hud.waiting, "a vez do jogador chega"):
		return
	# Um da equipe (não o líder) cai; os inimigos ficam a um golpe, e a luta corre sozinha até a vitória.
	var fallen_unit = arena.session.state.player_team[1]
	var hero_id: String = fallen_unit.hero_id
	var name: String = Campaign.hero(hero_id).display_name
	fallen_unit.hp = 0
	fallen_unit.deaths_door = false
	for unit in arena.session.state.enemy_team:
		unit.hp = 1
	var spot: Vector3 = street._heroes[street.party_ids.find(hero_id)].position
	arena.auto_battle = true
	arena.speed = 8.0
	arena.hud.command_chosen.emit({"kind": "defend"})
	var limit := Time.get_ticks_msec() + 60000
	while arena.active and Time.get_ticks_msec() < limit:
		await _tree.process_frame
	await _frames(6)
	if not t.check(not arena.active and Campaign.state.session.result == "", "a luta acaba e a expedição segue"):
		return
	t.check(not Campaign.hero(hero_id).alive, "%s caiu" % name)
	t.check(not street.party_ids.has(hero_id), "e sai da fila da equipe")
	var body: AHSpriteCard = corridor.bodies.get(hero_id)
	t.check(body != null and body.visible and body.is_inside_tree(), "o corpo fica no mapa")
	if body == null:
		return
	t.check(absf(body.position.x - spot.x) < 4.0, "no lugar da luta (%.1f m de onde ele estava)" % absf(body.position.x - spot.x))
	t.check(street._heroes.all(func(card): return absf(body.position.x - card.position.x) > 1.0), "logo atrás da fila, sem ninguém de pé em cima dele")
	var warned: String = corridor.hud._toast_label.text
	t.check(warned.contains(name) and warned.contains("Levante"), "o aviso diz quem caiu e que dá para levantar (\"%s\")" % warned)
	# Sem levantar, a volta lembra antes; a primeira opção (a do E) é ficar.
	corridor._retreat()
	await _frames(3)
	var modal = corridor.hud._modal
	t.check(modal != null and modal.visible and _has_text(modal, "Ainda há quem caiu no mapa"), "a volta lembra quem ficou no chão")
	var buttons: Array = modal.find_children("*", "Button", true, false) if modal != null else []
	t.check(not buttons.is_empty() and buttons[0].text.to_lower().contains("ficar"), "e a primeira opção é ficar e levantar")
	if not buttons.is_empty():
		buttons[0].pressed.emit()
	await _frames(3)
	t.check(Campaign.state.session.result == "", "ficar não volta")
	# Seguir para o próximo mapa com ele no chão: pergunta antes (o mapa seguinte não volta), e ficar não viaja.
	corridor._travel_map(Campaign.state, Campaign.state.session.expedition.corridor.index + 1)
	await _frames(3)
	modal = corridor.hud._modal
	t.check(modal != null and modal.visible and _contains(modal, "Ainda há quem caiu neste mapa") and not GameFlow.busy,
		"seguir para o próximo mapa pergunta antes, sem viajar")
	buttons = modal.find_children("*", "Button", true, false) if modal != null else []
	if not buttons.is_empty():
		buttons[0].pressed.emit()
	await _frames(3)
	t.check(not GameFlow.busy and _tree.current_scene == street, "ficar e levantar não viaja")
	# Um corpo num mapa que ficou para trás não está ao alcance: a volta não oferece "Ficar e levantar" por ele.
	var entry: Dictionary = J.downed_left(Campaign.state)[0]
	entry.map = "OutroMapa"
	t.check(corridor._downed_here().is_empty(), "o caído de outro mapa não conta como ao alcance")
	entry.map = corridor._map_id()
	# O corpo de uma luta dentro de uma casa só aparece com a equipe dentro dela (a sala só existe aberta).
	entry.house = 0
	corridor._spawn_bodies()
	t.check(not corridor.bodies.has(hero_id), "o caído de uma casa não aparece na rua")
	entry.house = -1
	corridor._spawn_bodies()
	body = corridor.bodies.get(hero_id)
	# O líder chega perto: o aviso pede para levantar, e E levanta.
	street._leader.position.x = body.position.x + 0.3
	await _frames(4)
	t.check(corridor.hud._prompt_label.text.contains(name) and corridor.hud._prompt_label.text.contains("Levantar"),
		"perto do corpo, \"%s\"" % corridor.hud._prompt_label.text)
	t.check(corridor._action.is_valid(), "com a ação de levantar")
	if corridor._action.is_valid():
		corridor._action.call()
	await _frames(3)
	t.check(J.carried(Campaign.state).has(hero_id) and not corridor.bodies.has(hero_id), "levantado, o corpo sai do mapa")
	t.check(corridor.hud.find_child("Carried", true, false) != null, "e a equipe mostra quem carrega")
	t.check(Campaign.read_file(Campaign.primary_path()) != null and J.carried(Campaign.read_file(Campaign.primary_path())).has(hero_id),
		"e o save já sabe")
	# Sem ninguém no chão, a volta não pergunta; o resumo diz que ele foi carregado.
	corridor._retreat()
	await _frames(4)
	var summary = corridor.hud._modal
	t.check(summary != null and summary.visible and not _contains(summary, "Ainda há quem caiu no mapa"), "a volta segue direto, sem lembrete")
	t.check(summary != null and _contains(summary, "A equipe carregou") and _contains(summary, name),
		"o resumo diz que %s foi carregado" % name)


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame


func _has_text(node: Node, text: String) -> bool:
	return _contains(node, text)


func _contains(node: Node, text: String) -> bool:
	for label in node.find_children("*", "Label", true, false):
		if label.text.contains(text):
			return true
	for label in node.find_children("*", "RichTextLabel", true, false):
		if label.text.contains(text):
			return true
	return false
