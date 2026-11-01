## A Arma e a Segunda Pele (#262, aprovado em 01/11): os dados, a compra (requisitos, cobrança uma vez, vida uma vez, o
## dia da Forja), a luta (dano sem cura, crítico, resistências com teto), o save e a seção da Forja.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const G = preload("res://scripts/flow/gear_rules.gd")
const J = preload("res://scripts/flow/journey_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop() as SceneTree
	_data()
	_buy()
	_day()
	_combat()
	_save()
	_sheet()
	await _forge_panel()


func _data() -> void:
	var rows: Array = []
	for piece in G.PIECES:
		for at in range(1, G.MAX_LEVEL + 1):
			var row := G.step(piece, at)
			rows.append([piece, at, int(row.get("HeroLevel", 0)), int(row.get("ForgeLevel", 0)), int(row.get("Scrap", 0)), int(row.get("Fragments", 0))])
	t.equal(rows, [
		["weapon", 1, 2, 1, 3, 0], ["weapon", 2, 4, 1, 4, 1], ["weapon", 3, 6, 2, 5, 2], ["weapon", 4, 8, 2, 6, 3],
		["armor", 1, 2, 1, 3, 0], ["armor", 2, 4, 1, 4, 1], ["armor", 3, 6, 2, 5, 2], ["armor", 4, 8, 2, 6, 3],
	], "os níveis, requisitos e custos da proposta aprovada")
	var full := {"gear": {"weapon": 4, "armor": 4}}
	t.equal(G.combat_bonus(full), {"damage": 2, "crit": 4, "dot": 10, "stun": 10, "max_hp": 6}, "as duas peças no máximo: +2 de dano, +4 pp, +10/+10 pp, +6 de vida")
	t.check(not G.step("weapon", 1).has("Speed") and not G.step("armor", 1).has("Speed"), "nenhuma peça dá Velocidade")


## Um herói pronto para a Forja: no nível pedido, com recursos e a Forja no nível dado.
func _ready_campaign(seed_value: int, hero_level: int, forge: int) -> Dictionary:
	var c: Dictionary = Campaign.create_initial(seed_value)
	c.station.rooms[S.FORGE] = forge
	S.adjust(c, "scrap", 100)
	S.adjust(c, "fragments", 100)
	for hero in c.roster:
		hero.level = hero_level
	return c


func _buy() -> void:
	var c := _ready_campaign(31, 1, 1)
	var hero: Dictionary = c.roster[0]
	t.equal(G.level(hero, "weapon"), 0, "o herói novo chega com a Arma no nível 0")
	t.check(G.block(c, hero.id, "weapon").contains("nível 2"), "no nível 1 do herói, a Arma não melhora")
	hero.level = 2
	var scrap := S.quantity(c, "scrap")
	var life := int(hero.max_hp)
	var hp := int(hero.hp)
	t.equal(G.upgrade(c, hero.id, "armor"), "", "a Segunda Pele sobe para o nível 1")
	t.equal([G.level(hero, "armor"), S.quantity(c, "scrap"), int(hero.max_hp), int(hero.hp)], [1, scrap - 3, life + 3, hp + 3],
		"cobra 3 sucatas uma vez e soma 3 de vida uma vez")
	t.check(G.upgrade(c, hero.id, "armor") != "", "a segunda melhoria do dia na Forja 1 espera")
	t.equal([G.level(hero, "armor"), S.quantity(c, "scrap"), int(hero.max_hp)], [1, scrap - 3, life + 3], "e não cobra nem soma nada")
	c.station.cycle_number = int(c.station.get("cycle_number", 0)) + 1
	t.check(G.block(c, hero.id, "armor").contains("nível 4"), "o nível 2 da peça pede o herói no nível 4")
	hero.level = 6
	t.equal(G.upgrade(c, hero.id, "armor"), "", "no herói nível 6, sobe para o 2")
	c.station.cycle_number = int(c.station.cycle_number) + 1
	t.check(G.block(c, hero.id, "armor").contains("Forja no nível 2"), "o nível 3 da peça pede a Forja no nível 2")
	c.station.rooms[S.FORGE] = 0
	t.check(G.block(c, hero.id, "armor").contains("Recupere a Forja"), "sem a Forja, nada melhora")
	c.station.rooms[S.FORGE] = 2
	hero.level = 8
	t.equal(G.upgrade(c, hero.id, "armor"), "", "Forja 2: o 3")
	t.equal(G.upgrade(c, hero.id, "armor"), "", "e no mesmo dia (duas na Forja 2), o 4")
	t.equal([G.level(hero, "armor"), int(hero.max_hp)], [4, life + 6], "no máximo, a vida somou só os dois níveis de vida")
	c.station.cycle_number = int(c.station.cycle_number) + 1
	t.check(G.block(c, hero.id, "armor").contains("máximo"), "acima de 4, recusa")
	# Sem recursos, recusa sem cobrar.
	var poor := _ready_campaign(32, 2, 1)
	S.adjust(poor, "scrap", -S.quantity(poor, "scrap") + 2)
	var before := S.quantity(poor, "scrap")
	t.check(G.upgrade(poor, poor.roster[0].id, "weapon").contains("Faltam"), "sem sucata, recusa com o que falta")
	t.equal([S.quantity(poor, "scrap"), G.level(poor.roster[0], "weapon")], [before, 0], "e não cobra nem sobe")
	# Quem está na expedição ou em missão solo não melhora.
	var away := _ready_campaign(33, 2, 1)
	J.start_expedition(away, "fase_1", 33)
	var going := String(away.session.expedition.team[0])
	t.check(G.block(away, going, "weapon").contains("expedição"), "quem está na expedição espera a volta")


func _day() -> void:
	var c := _ready_campaign(34, 2, 2)
	t.equal(G.left_today(c), 2, "Forja 2: duas melhorias por dia")
	t.equal(G.upgrade(c, c.roster[0].id, "weapon"), "", "a primeira")
	t.equal(G.upgrade(c, c.roster[1].id, "weapon"), "", "a segunda, de outro herói")
	t.check(G.upgrade(c, c.roster[2].id, "weapon").contains("amanhã"), "a terceira espera o dia seguinte")
	c.station.cycle_number = int(c.station.get("cycle_number", 0)) + 1
	t.equal(G.left_today(c), 2, "no dia seguinte, a Forja faz de novo")


func _combat() -> void:
	var c := _ready_campaign(35, 8, 2)
	var hero: Dictionary = c.roster[0]
	hero.gear = {"weapon": 4, "armor": 4}
	var plain := AHCombatSession.create([c.roster[1]], [], false, 7)
	var geared := AHCombatSession.create([hero], [], false, 7)
	var unit: AHCombat.Unit = geared.state.player_team[0]
	t.equal([unit.gear_damage, snappedf(unit.gear_crit, 0.001)], [2, 0.04], "a Arma entra na luta: +2 de dano e +4 pp de crítico")
	var engine: AHCombatEngine = geared.engine
	var role = engine.find_class(unit.class_id)
	t.equal(snappedf(engine.hero_crit_chance(unit), 0.001), snappedf(0.1 + float(role.CritBonus) / 100.0 + 0.04, 0.001), "o crítico soma papel e Arma")
	t.equal(snappedf(engine.hero_resist(unit, "DotResist"), 0.001), snappedf(minf(0.8, float(role.DotResist) + 0.1), 0.001), "a resistência a dano contínuo soma a Segunda Pele")
	t.equal(snappedf(engine.hero_resist(unit, "DisplacementResist"), 0.001), snappedf(float(role.DisplacementResist), 0.001), "a de deslocamento não muda")
	unit.gear_resist = {"StunResist": 0.9}
	t.equal(engine.hero_resist(unit, "StunResist"), 0.8, "o teto de 80% vale")
	# O dano na faixa mostrada (e no motor) soma a Arma; a cura não.
	var damage_id := ""
	var heal_id := ""
	for ability_id in unit.ability_ids if not unit.ability_ids.is_empty() else role.AbilityIds:
		var ability: Dictionary = geared.data.abilities[ability_id]
		if damage_id == "" and int(ability.DamageRange.Max) > 0:
			damage_id = ability_id
		if heal_id == "" and int(ability.HealRange.Max) > 0:
			heal_id = ability_id
	if damage_id != "":
		var shown := geared.effective_range(damage_id, "damage", unit.id)
		var raw: Dictionary = geared.data.abilities[damage_id].DamageRange
		t.equal([shown.Min - int(raw.Min), shown.Max - int(raw.Max)], [2, 2], "a faixa de dano mostra +2 da Arma")
	var healer: Dictionary = {}
	for entry in c.roster:
		if String(entry.class_id) == "sapo":
			healer = entry
	if not healer.is_empty():
		healer.gear = {"weapon": 4, "armor": 0}
		var heal_session := AHCombatSession.create([healer], [], false, 7)
		var medic: AHCombat.Unit = heal_session.state.player_team[0]
		var heals: Array = heal_session.data.classes[medic.class_id].AbilityIds.filter(func(id): return int(heal_session.data.abilities[id].HealRange.Max) > 0)
		if t.check(not heals.is_empty(), "a Química tem uma cura"):
			var heal_range := heal_session.effective_range(heals[0], "heal", medic.id)
			var raw_heal: Dictionary = heal_session.data.abilities[heals[0]].HealRange
			t.equal([heal_range.Min, heal_range.Max], [int(raw_heal.Min), int(raw_heal.Max)], "a Arma não mexe na cura")
	# Sem peças, nada muda (a paridade).
	var zero: AHCombat.Unit = plain.state.player_team[0]
	t.equal([zero.gear_damage, zero.gear_crit], [0, 0.0], "sem peças, tudo zero")


func _save() -> void:
	var c: Dictionary = Campaign.create_initial(36)
	var hero: Dictionary = c.roster[0]
	hero.erase("gear")
	S.migrate(c)
	t.equal(hero.get("gear"), {"weapon": 0, "armor": 0}, "o save de antes ganha as peças no nível 0")
	hero.gear = {"weapon": 2, "armor": 3}
	var life := int(hero.max_hp)
	S.migrate(c)
	S.migrate(c)
	t.equal([hero.gear, int(hero.max_hp)], [{"weapon": 2, "armor": 3}, life], "migrar duas vezes não muda nada (nem a vida)")
	for bad in [5, "x", {"weapon": "a", "armor": [1]}, {"weapon": 9, "armor": -2}, {"weapon": 1.0}]:
		hero.gear = bad
		t.check(G.level(hero, "weapon") >= 0 and G.combat_bonus(hero).damage >= 0, "o gear editado %s não quebra" % str(bad))
		S.migrate(c)
		t.check(typeof(hero.gear) == TYPE_DICTIONARY and G.level(hero, "weapon") <= 4 and G.level(hero, "armor") >= 0, "e vira números de 0 a 4: %s" % str(hero.gear))
	# Salvar e carregar: o nível e a vida ficam.
	hero.gear = {"weapon": 1, "armor": 1}
	var copy: Dictionary = JSON.parse_string(JSON.stringify(c))
	S.migrate(copy)
	t.equal([G.level(copy.roster[0], "weapon"), G.level(copy.roster[0], "armor"), int(copy.roster[0].max_hp)], [1, 1, int(hero.max_hp)], "o JSON do save guarda as peças e a vida")


## A ficha fora da luta (#262, PR 2): a resistência e o crítico com as peças, como na luta; sem peças, como antes.
func _sheet() -> void:
	var c: Dictionary = Campaign.create_initial(38)
	var hero: Dictionary = c.roster[0]
	var role = GameData.combat.classes.get(String(hero.class_id))
	var pct := func(value): return roundi(float(value) * 100.0)
	var plain := AHCharacterSheet.role_rows(String(hero.class_id))
	t.check(String(plain[0][0]).contains("dano por turno %d%%" % pct.call(role.DotResist)), "sem peças, a resistência do papel")
	hero.gear = {"weapon": 4, "armor": 4}
	var rows := AHCharacterSheet.role_rows(String(hero.class_id), G.combat_bonus(hero))
	t.check(String(rows[0][0]).contains("dano por turno %d%%" % pct.call(G.resist_with(float(role.DotResist), 10))), "com a Segunda Pele, a de dano contínuo soma")
	t.check(String(rows[0][0]).contains("atordoamento %d%%" % pct.call(G.resist_with(float(role.StunResist), 10))), "e a de atordoamento")
	var crit: Array = rows.filter(func(r): return String(r[0]).begins_with("Crítico"))
	t.check(crit.size() == 1 and String(crit[0][0]).contains("%d%%" % (10 + int(role.CritBonus) + 4)) and String(crit[0][0]).contains("Arma +4"),
		"o crítico soma a Arma, mesmo num papel sem crítico (%s)" % (crit[0][0] if not crit.is_empty() else "nada"))
	t.check(int(role.CritBonus) > 0 or not String(crit[0][0]).contains("papel +0"), "num papel sem crítico, sem \"papel +0\" (%s)" % crit[0][0])
	t.equal(G.resist_with(0.75, 10), 0.8, "a ficha usa o mesmo teto da luta")
	var sheet := AHCharacterSheet.from_hero(hero)
	t.check(sheet.passives.any(func(r): return String(r[0]).contains("Arma +4")), "a ficha do herói mostra o crítico com a Arma")
	t.check(G.next_text({"gear": {"weapon": 1, "armor": 0}}, "weapon").contains("nível 2"), "o próximo nível da peça")
	t.equal(G.next_text({"gear": {"weapon": 4, "armor": 0}}, "weapon"), "", "no máximo, sem próximo")


## A seção da Forja: o herói escolhido, as duas peças, o Melhorar e o motivo do bloqueio na tela.
func _forge_panel() -> void:
	var real_state: Dictionary = Campaign.state
	var real_dir: String = Campaign.save_dir
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-gear-%d" % Time.get_ticks_usec()
	var c := _ready_campaign(37, 2, 1)
	c.station.last_return = {}
	Campaign.state = c
	GameFlow.change_to("station", {}, false)
	var station: AHStation = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene is AHStation and frame > 3:
			station = _tree.current_scene
			break
	if t.check(station != null, "a Estação abriu"):
		var hud: AHRefugeHud = station.hud
		hud.open_room(S.FORGE)
		await _frames(4)
		t.check(hud.find_child("Gear_weapon", true, false) != null and hud.find_child("Gear_armor", true, false) != null, "a Forja mostra a Arma e a Segunda Pele")
		var first: Dictionary = c.roster[0]
		var button := hud.find_child("Upgrade_weapon", true, false) as Button
		if t.check(button != null and not button.disabled, "com o Melhorar da Arma"):
			button.pressed.emit()
			await _frames(4)
			t.equal(G.level(S.hero(Campaign.state, first.id), "weapon"), 1, "que melhora a Arma do herói escolhido")
			var after := hud.find_child("Upgrade_armor", true, false) as Button
			t.check(after != null and after.disabled, "e o resto do dia fica apagado (Forja 1)")
			t.check(hud.find_child("GearBlock_armor", true, false) != null, "com o motivo na tela")
		var other := hud.find_child("GearHero_%s" % c.roster[1].id, true, false) as Button
		if t.check(other != null, "um chip por herói"):
			other.pressed.emit()
			await _frames(4)
			t.equal(hud._gear_hero, String(c.roster[1].id), "escolher outro herói mostra as peças dele")
		# A Sala (PR 2): as duas peças do herói e o Melhorar na Forja, que abre a Forja com ele escolhido.
		hud.open_room(S.CHARACTERS)
		await _frames(4)
		var screen: AHCharacterRoom = hud._room_screen
		screen.selected = first.id
		screen.rebuild()
		await _frames(3)
		var weapon_row := screen.find_child("Gear_weapon", true, false) as Control
		if t.check(weapon_row != null and screen.find_child("Gear_armor", true, false) != null, "a Sala mostra a Arma e a Segunda Pele"):
			var words: Array = weapon_row.find_children("*", "Label", true, false).map(func(l): return String(l.text))
			t.check(words.any(func(w): return w.contains("nível 1 de 4")) and words.any(func(w): return w.contains("+1 de dano")), "com o nível e o que soma (%s)" % " | ".join(words))
			t.check(words.any(func(w): return w.begins_with("Próximo: nível 2")), "e o próximo nível")
		# Herói em missão solo ou a Forja não recuperada: o botão apaga, com o motivo.
		var nick: Dictionary = S.hero(Campaign.state, c.roster[1].id)
		nick.side_mission = {"id": String(AHSideMissions.missions()[0].Name), "spot": 0, "sent": AHSideMissions.day(Campaign.state), "back": AHSideMissions.day(Campaign.state) + 2}
		var away_reason := G.reach_block(Campaign.state, nick.id)
		screen.selected = nick.id
		screen.rebuild()
		await _frames(3)
		var blocked := screen.find_child("GearForge", true, false) as Button
		t.check(away_reason != "" and blocked != null and blocked.disabled and screen.find_child("GearBlock", true, false) != null,
			"em missão solo, o Melhorar na Forja apaga, com o motivo (%s)" % away_reason)
		nick.erase("side_mission")
		Campaign.state.station.rooms[S.FORGE] = 0
		screen.rebuild()
		await _frames(3)
		blocked = screen.find_child("GearForge", true, false) as Button
		t.check(blocked != null and blocked.disabled and G.reach_block(Campaign.state, nick.id).contains("Recupere a Forja"), "sem a Forja, também")
		Campaign.state.station.rooms[S.FORGE] = 1
		screen.selected = first.id
		screen.rebuild()
		await _frames(3)
		var go := screen.find_child("GearForge", true, false) as Button
		if t.check(go != null, "com o Melhorar na Forja"):
			go.pressed.emit()
			await _frames(4)
			t.equal([hud.current, hud._gear_hero], [S.FORGE, String(first.id)], "que abre a Forja com o herói escolhido")
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


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
