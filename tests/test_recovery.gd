## Ninguém morre (#118) e a Enfermaria (#121): quem cai volta Caído e em recuperação, os dias contam a cada volta, os
## leitos limitam, o curativo tira um dia, quem se recupera volta ao Alojamento, a derrota devolve todos, esperar um dia
## destrava a equipe toda caída e o save com memorial migra.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const J = preload("res://scripts/flow/journey_rules.gd")

var _seed := 500


func run(t) -> void:
	_fall_does_not_kill(t)
	_days_and_beds(t)
	_cannot_deploy(t)
	_bandage(t)
	_defeat(t)
	_rest_day(t)
	_migration(t)
	_room(t)
	_admin(t)


## Uma volta: a expedição sai com a equipe, os de fallen caem (alive = false, como a luta grava) e ela fecha com result.
## A noite e o trem da volta anterior ficam resolvidos antes.
func _return(c: Dictionary, team: Array, fallen: Array = [], result: String = "victory") -> Dictionary:
	c.night = S._night_defaults()
	c.station.train = S._train_defaults()
	_seed += 1
	J.start_expedition(c, "fase_1", _seed)
	c.session.expedition.team = team.duplicate()
	for hero_id in fallen:
		S.hero(c, hero_id).alive = false
	c.session.result = result
	c.session.screen = "result"
	return S.finish_return(c)


func _team(c: Dictionary) -> Array:
	return c.roster.slice(0, 4).map(func(h): return h.id)


func _fall_does_not_kill(t) -> void:
	var c: Dictionary = Campaign.create_initial(71)
	var team := _team(c)
	J.start_expedition(c, "fase_1", 71)
	c.session.expedition.team = team.duplicate()
	S.hero(c, team[2]).alive = false
	J.end_combat(c, "victory", false, "teste")
	t.equal(c.memorial.size(), 0, "cair na luta não põe ninguém no memorial")
	t.check(not S.hero(c, team[2]).alive, "quem caiu fica fora do resto da expedição")
	c.session.result = "victory"
	c.session.screen = "result"
	var report := S.finish_return(c)
	var iris = S.hero(c, team[2])
	t.check(iris.alive, "na volta, quem caiu está vivo")
	t.equal(int(iris.hp), int(S.recovery_rule("fallen").Hp), "com a vida baixa de data/recovery.json")
	t.equal(S.recovery_days(iris), int(S.recovery_rule("fallen").Days), "em recuperação pelos dias de data/recovery.json (sem Enfermaria)")
	t.check(S.recovering(iris) and not S.in_bed(iris), "sem a Enfermaria, se recupera no Dormitório")
	t.equal(report.fallen, [{"hero_id": team[2], "days": S.recovery_days(iris), "bed": false}], "o relatório diz quem chegou Caído")
	t.check(not c.night.participants.has(team[2]), "quem caiu não entra na noite (nem vigia nem come)")
	t.equal(report.returning, 3, "a água conta só quem voltou de pé")


func _days_and_beds(t) -> void:
	var c: Dictionary = Campaign.create_initial(72)
	c.station.rooms[S.INFIRMARY] = 1
	var team := _team(c)
	t.equal(S.infirmary_beds(c), 2, "a Enfermaria tem 2 leitos no nível 1")
	var report := _return(c, team, [team[0], team[1], team[2]])
	var bed_days := int(S.recovery_rule("infirmary").Days)
	var slow := int(S.recovery_rule("fallen").Days)
	t.equal(report.fallen.map(func(e): return e.bed), [true, true, false], "os leitos limitam: o terceiro fica no Dormitório")
	t.equal(report.fallen.map(func(e): return e.days), [bed_days, bed_days, slow], "no leito volta antes")
	# Um dia: a próxima volta (só o quarto vai).
	report = _return(c, [team[3]])
	t.equal(S.fallen(c).map(func(h): return S.recovery_days(h)), [bed_days - 1, bed_days - 1, slow - 1], "os dias contam a cada volta")
	t.equal(report.recovered, [], "ninguém volta antes do tempo")
	report = _return(c, [team[3]])
	t.equal(report.recovered, [team[0], team[1]], "quem chega a zero se recupera")
	var bento = S.hero(c, team[0])
	t.check(not S.recovering(bento) and int(bento.hp) == int(bento.max_hp), "volta ao Alojamento com a vida cheia")
	t.check(S.can_deploy(bento), "e pode partir de novo")
	var last = S.hero(c, team[2])
	t.check(S.in_bed(last), "o leito vago vai para quem esperava no Dormitório")
	t.equal(S.recovery_days(last), mini(slow - 2, bed_days), "no leito, os dias nunca passam dos da Enfermaria")
	c.station.rooms[S.INFIRMARY] = 2
	t.equal(S.infirmary_beds(c), 4, "4 leitos no nível 2")


func _cannot_deploy(t) -> void:
	var c: Dictionary = Campaign.create_initial(73)
	var team := _team(c)
	_return(c, team, [team[1]])
	c.night = S._night_defaults()
	c.station.train = S._train_defaults()
	var nick = S.hero(c, team[1])
	t.check(not S.can_deploy(nick), "quem está em recuperação não entra na equipe")
	t.check(S.deploy_block(nick).contains(String(nick.display_name)) and S.deploy_block(nick).contains(S.return_text(S.recovery_days(nick)).to_lower()),
		"e o motivo diz quando volta")
	var error := S.confirm_departure(c, team, 0, 900, "fase_1")
	t.equal(error, S.recovery_block(nick), "a partida com ele é recusada")
	t.equal(S.validate_team(c, team, "fase_1"), S.recovery_block(nick), "e a equipe também")
	t.equal(S.ready_heroes(c).size(), 3, "os outros três podem partir")
	# O atalho que parte com a formação salva (a barra de Admin) também deixa quem se recupera na Estação.
	t.check(J.start_expedition(c, "fase_1", 901), "a expedição pela formação parte")
	t.check(not c.session.expedition.team.has(team[1]), "sem quem está em recuperação")


func _bandage(t) -> void:
	var c: Dictionary = Campaign.create_initial(74)
	var team := _team(c)
	_return(c, team, [team[0], team[1]])
	var bento = S.hero(c, team[0])
	t.check(S.treat_block(c, team[0]) != "", "sem leito, o curativo não faz efeito")
	c.inventory.scrap = 50
	c.inventory.fragments = 50
	t.equal(S.upgrade_room(c, S.INFIRMARY, 0), "", "recuperar a Enfermaria com caídos esperando")
	t.check(S.in_bed(bento), "recuperada a Enfermaria, os caídos vão na hora para o leito")
	var bandages := S.quantity(c, "bandages")
	var days := S.recovery_days(bento)
	t.equal(S.treat_fallen(c, team[0]), "", "o curativo no leito vale")
	t.equal(S.recovery_days(bento), days - 1, "e tira um dia")
	t.equal(S.quantity(c, "bandages"), bandages - 1, "gastando um curativo")
	t.check(S.treat_fallen(c, team[0]) != "", "um curativo por dia em cada um")
	t.equal(S.quantity(c, "bandages"), bandages - 1, "o recusado não gasta")
	# O último dia: o curativo traz de volta.
	bento.recovery_days = 1
	bento.recovery_treated = -1
	t.equal(S.treat_fallen(c, team[0]), "", "o curativo do último dia")
	t.check(not S.recovering(bento) and int(bento.hp) == int(bento.max_hp), "traz de volta ao Alojamento")
	c.inventory.bandages = 0
	t.check(S.treat_block(c, team[1]) != "", "sem curativo no estoque, não trata")


func _defeat(t) -> void:
	var c: Dictionary = Campaign.create_initial(75)
	var team := _team(c)
	var scrap := S.quantity(c, "scrap")
	J.start_expedition(c, "fase_1", 75)
	c.session.expedition.team = team.duplicate()
	c.session.expedition.loot.scrap = 5
	for hero_id in team:
		S.hero(c, hero_id).alive = false
	J.end_combat(c, "defeat", false, "teste")
	var report := S.finish_return(c)
	t.equal(report.fallen.size(), 4, "a derrota da equipe inteira devolve todos")
	t.check(c.roster.all(func(h): return h.alive and S.recovering(h)), "todos vivos e em recuperação")
	t.equal(S.quantity(c, "scrap"), scrap, "o achado da derrota se perde")
	t.equal(c.memorial.size(), 0, "o memorial fica vazio")
	t.equal(c.session.screen, "shelter", "e o jogo continua na Estação")


func _rest_day(t) -> void:
	var c: Dictionary = Campaign.create_initial(76)
	var team := _team(c)
	_return(c, team, [team[0]])
	c.night = S._night_defaults()
	c.station.train = S._train_defaults()
	t.check(S.rest_block(c) != "", "com quem possa partir, não dá para só esperar")
	t.check(S.next_step(c).action != "rest", "e o próximo passo não pede espera")
	_return(c, [team[1], team[2], team[3]], [team[1], team[2], team[3]], "defeat")
	c.night = S._night_defaults()
	c.station.train = S._train_defaults()
	t.equal(S.ready_heroes(c).size(), 0, "a equipe toda caída: ninguém pode partir")
	c.station.last_return.seen = true
	t.equal(S.next_step(c).action, "rest", "o próximo passo leva à Enfermaria para esperar")
	var cycle := int(c.station.cycle_number)
	var before: Array = S.fallen(c).map(func(h): return S.recovery_days(h))
	t.equal(S.rest_day(c), "", "esperar um dia vale")
	t.equal(int(c.station.cycle_number), cycle + 1, "o dia é um ciclo da Estação")
	t.equal(S.fallen(c).map(func(h): return S.recovery_days(h)), before.map(func(d): return d - 1).filter(func(d): return d > 0), "cada caído fica um dia mais perto")
	t.equal(c.station.last_rest.recovered, [team[0]] if before[0] == 1 else [], "e quem chega a zero volta")
	for i in 5:
		if S.rest_block(c) != "":
			break
		S.rest_day(c)
	t.check(not S.ready_heroes(c).is_empty(), "esperando, a equipe volta a poder partir (o jogo não trava)")


func _migration(t) -> void:
	var c: Dictionary = Campaign.create_initial(77)
	var team := _team(c)
	# O save de antes do #118: a Íris no memorial, com alive = false, e sem os campos da recuperação.
	var iris = S.hero(c, team[2])
	iris.alive = false
	iris.hp = 0
	c.memorial = [{"hero_id": iris.id, "display_name": iris.display_name, "class_id": iris.class_id, "mission_name": "Rua das Vitrines", "cause": "teste", "completed_expeditions": 0}]
	for entry in c.roster:
		for key in ["recovery_days", "recovery_bed", "recovery_treated"]:
			entry.erase(key)
	# Um herói do memorial que não está mais no elenco.
	c.memorial.append({"hero_id": "hero_rato_9", "display_name": "Ferrugem", "class_id": "rato", "mission_name": "", "cause": "", "completed_expeditions": 0})
	var old = Campaign._normalize(JSON.parse_string(JSON.stringify(c)))
	S.migrate(old)
	t.equal(old.memorial, [], "o memorial fica vazio")
	var back = S.hero(old, iris.id)
	t.check(back.alive and S.recovering(back), "quem estava no memorial volta Caído, em recuperação")
	t.equal(int(back.hp), int(S.recovery_rule("fallen").Hp), "com a vida baixa")
	var lost = S.hero(old, "hero_rato_9")
	t.check(lost != null and lost.display_name == "Ferrugem" and S.recovering(lost), "quem não estava mais no elenco volta com o nome de antes")
	t.check(old.roster.all(func(h): return h.has("recovery_days") and h.has("recovery_bed")), "todos ganham os campos da recuperação")
	var once: Dictionary = old.duplicate(true)
	S.migrate(old)
	t.equal(old, once, "a migração é idempotente")
	# O save do meio de uma expedição: quem caiu nela volta Caído só no fim da volta.
	var d: Dictionary = Campaign.create_initial(78)
	var d_team := _team(d)
	J.start_expedition(d, "fase_1", 78)
	d.session.expedition.team = d_team.duplicate()
	S.hero(d, d_team[1]).alive = false
	d.memorial = [{"hero_id": d_team[1], "display_name": "Nick", "class_id": "gato"}]
	S.migrate(d)
	t.check(not S.hero(d, d_team[1]).alive, "no meio da expedição, quem caiu nela continua fora")
	d.session.result = "retreat"
	d.session.screen = "result"
	S.finish_return(d)
	t.check(S.recovering(S.hero(d, d_team[1])), "e volta Caído no fim")
	# Pelo arquivo: o save antigo abre pelo Campaign com o herói de volta.
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-recovery-%d" % Time.get_ticks_usec()
	var e: Dictionary = Campaign.create_initial(79)
	S.hero(e, _team(e)[0]).alive = false
	e.memorial = [{"hero_id": _team(e)[0], "display_name": "Bento", "class_id": "cao"}]
	Campaign.state = e
	t.check(Campaign.save(), "grava o save antigo")
	Campaign.load_or_new()
	t.check(S.recovering(S.hero(Campaign.state, _team(e)[0])) and Campaign.state.memorial.is_empty(), "o save com memorial abre com o herói em recuperação")
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(Campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(Campaign.save_dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _room(t) -> void:
	var c: Dictionary = Campaign.create_initial(80)
	t.equal(S.room_level(c, S.INFIRMARY), 0, "a Enfermaria começa por recuperar")
	var row = GameData.row("recovery", "infirmary_level_1")
	t.equal(S.next_level_cost(c, S.INFIRMARY), {"scrap": int(row.Scrap), "fragments": int(row.Fragments)}, "o custo vem de data/recovery.json")
	c.inventory.scrap = 20
	c.inventory.fragments = 5
	t.equal(S.upgrade_room(c, S.INFIRMARY, 0), "", "recuperar a Enfermaria")
	t.equal(S.room_level(c, S.INFIRMARY), 1, "nível 1")
	t.equal(S.upgrade_room(c, S.INFIRMARY, 1), "", "melhorar a Enfermaria")
	t.equal(S.infirmary_beds(c), 4, "4 leitos")
	t.check(S.room_benefit(S.INFIRMARY, 2).contains("4"), "o texto do cômodo diz os leitos")
	t.check(not S.room_benefit(S.CHARACTERS, 1).to_lower().contains("memorial"), "o Alojamento não fala mais em memorial")


## A barra de Admin (#130): derrubar um herói, passar um dia e recuperar os caídos.
func _admin(t) -> void:
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-recovery-admin-%d" % Time.get_ticks_usec()
	Campaign.state = Campaign.create_initial(81)
	var c: Dictionary = Campaign.state
	t.check(AHAdminActions.run("fall_one") != "", "Admin: derrubar um herói")
	t.equal(S.fallen(c).size(), 1, "ele volta Caído")
	var days := S.recovery_days(S.fallen(c)[0])
	var cycle := int(c.station.cycle_number)
	t.check(AHAdminActions.run("pass_day") != "", "Admin: passar um dia")
	t.equal(int(c.station.cycle_number), cycle + 1, "o dia é um ciclo")
	t.equal(S.recovery_days(S.fallen(c)[0]), days - 1, "e a recuperação anda")
	t.check(AHAdminActions.run("recover_all") != "", "Admin: recuperar os caídos")
	t.equal(S.fallen(c).size(), 0, "ninguém mais em recuperação")
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(Campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(Campaign.save_dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state
