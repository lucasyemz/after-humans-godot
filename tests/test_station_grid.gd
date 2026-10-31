## A Estação em grade (#186; as regras e o save, #272): a campanha nova começa com o Dormitório, o Alojamento e a Forja
## parada no 1º subsolo e o resto soterrado; a escavação só anda nas voltas, um bloco por vez, na ordem (vizinho de uma
## vaga aberta, o andar de baixo depois do patamar); o escavador, o tatu, o guaxinim e o temperamento mudam o ritmo; os
## pontos que sobram não passam para o próximo bloco; o achado tem o mínimo, sai igual na mesma volta e vira curativo sem
## nada novo; construir pede a vaga livre do tamanho certo; o Próximo passo e o foco da rota só falam de construir com
## vaga; os saves de antes ganham a planta herdada, sem nenhum cômodo construído soterrado.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const J = preload("res://scripts/flow/journey_rules.gd")
const G = preload("res://scripts/flow/station_grid.gd")

var t


func run(context) -> void:
	t = context
	_new_campaign()
	_dig_order()
	_dig_on_returns()
	_digger()
	_finds()
	_build()
	_next_step()
	_saves()
	_intro()


func _campaign(seed_value: int = 186) -> Dictionary:
	return Campaign.create_initial(seed_value)


## Uma volta de expedição inteira: a partida da equipe salva, a vitória, o relatório e a noite resolvida.
func _return(c: Dictionary, seed_value: int) -> Dictionary:
	J.start_expedition(c, "fase_1", seed_value)
	c.session.result = "victory"
	var report := S.finish_return(c)
	S.resolve_night(c)
	S.finish_dawn(c)
	c.station.train = S._train_defaults()
	return report


## Abre o bloco na mão (o teste da construção não depende do ritmo da escavação).
func _open(c: Dictionary, key: String) -> void:
	if G.is_landing(key):
		G.grid(c).landings[G.block_floor(key) - 2] = true
	else:
		G.grid(c).cells[G.block_floor(key) - 1][G.block_slot(key) - 1] = G.FREE


func _new_campaign() -> void:
	var c := _campaign()
	var cells: Array = G.grid(c).cells
	t.equal(cells[0], ["", "", S.FORGE, S.FORGE, S.CHARACTERS, S.DORMITORY, S.DORMITORY], "o 1º subsolo da campanha nova: dois blocos, a Forja parada, o Alojamento e o Dormitório")
	t.check(cells[1].all(func(id): return id == "") and cells[2].all(func(id): return id == ""), "o 2º e o 3º subsolos começam soterrados")
	t.equal(G.grid(c).landings, [false, false], "os dois patamares também")
	t.equal(S.room_level(c, S.FORGE), 0, "a Forja começa parada")
	t.equal([S.room_level(c, S.CANTEEN), S.room_level(c, S.DEPOT)], [1, 1], "o fogareiro e os caixotes da plataforma são o nível 1 da Cantina e do Depósito")
	t.check(not G.placed(c, S.CANTEEN) and not G.placed(c, S.DEPOT) and not G.placed(c, S.PREPARATION), "a Cantina, o Depósito e a Preparação ficam fora da grade")
	for room_id in [S.RESEARCH, S.INFIRMARY, S.BAR]:
		t.check(G.buried(c, room_id), "%s começa soterrado" % room_id)
	t.check(not G.buried(c, S.FORGE) and S.upgrade_block(c, S.FORGE) != "" and G.space_block(c, S.FORGE) == "", "a Forja parada tem lugar: só falta a sucata")
	t.equal(S.canteen_food(c), S.CANTEEN_FOOD, "o fogareiro rende o que a Cantina rendia")
	t.equal(G.dig_target(c), "1:2", "a comunidade começa pelo bloco vizinho mais perto da escada")


func _dig_order() -> void:
	var c := _campaign()
	t.check(G.diggable(c, "1:2") and not G.diggable(c, "1:1"), "só o vizinho de uma vaga aberta: o bloco 1 espera o 2")
	t.check(G.diggable(c, "L2") and not G.diggable(c, "L3"), "o patamar do 2º subsolo dá; o do 3º espera o de cima")
	t.check(not G.diggable(c, "2:7") and not G.diggable(c, "2:1"), "o 2º subsolo espera o patamar")
	t.check(not G.diggable(c, "1:5") and not G.diggable(c, "9:9") and not G.diggable(c, "L1"), "vaga aberta ou bloco que não existe não se escava")
	t.equal(G.set_dig_target(c, "1:1"), TranslationServer.translate("Esse bloco ainda não dá para escavar: só o vizinho de uma vaga aberta, no mesmo andar, depois do patamar."), "escolher um bloco fora da ordem dá o motivo")
	t.equal(G.set_dig_target(c, "1:5"), TranslationServer.translate("Esse bloco já está aberto."), "e um bloco aberto também")
	t.equal(G.set_dig_target(c, "L2"), "", "o patamar pode ser a frente")
	t.equal(G.dig_target(c), "L2", "a frente escolhida manda")
	_open(c, "L2")
	t.check(G.diggable(c, "2:7") and not G.diggable(c, "2:6") and G.diggable(c, "L3"), "aberto o patamar, a vaga ao lado da escada e o patamar de baixo")
	t.equal(G.dig_target(c), "1:2", "aberta a frente escolhida, a comunidade volta ao mais perto da escada")


func _dig_on_returns() -> void:
	var c := _campaign()
	var first := _return(c, 1001)
	t.equal(first.get("dig", {}).get("block", ""), "1:2", "a primeira volta escava o bloco da comunidade")
	t.equal([int(first.dig.points), int(first.dig.progress), int(first.dig.work), bool(first.dig.opened)], [1, 1, 2, false], "sozinha, a comunidade faz 1 de 2 pontos")
	t.equal(G.report_line(first.dig), TranslationServer.translate("Escavação: %s, %d de %d pontos de obra.") % [G.block_name("1:2"), 1, 2], "o relatório diz quanto andou")
	# Esperar um dia não escava: com todos em recuperação, o dia passa e o bloco fica igual.
	for entry in c.roster:
		entry.recovery_days = 3
	t.equal(S.rest_day(c), "", "o dia de espera passa")
	t.equal(G.block_progress(c, "1:2"), 1, "o \"Esperar um dia\" não avança a escavação")
	for entry in c.roster:
		S._recover(entry)
	var scrap := S.quantity(c, "scrap")
	var second := _return(c, 1002)
	t.check(second.dig.opened and G.cell(c, 1, 2) == G.FREE, "a segunda volta abre o bloco: vira uma vaga livre")
	t.check(S.quantity(c, "scrap") >= scrap + int(second.scrap) + 1, "e devolve pelo menos a sucata do andar")
	t.check(G.report_line(second.dig).begins_with(TranslationServer.translate("Escavação: %s foi aberto. %s.").get_slice("%s", 0)) and G.report_line(second.dig).contains(G.block_name("1:2")), "o relatório diz o bloco aberto e o achado")
	t.equal(G.block_progress(c, "1:1"), 0, "os pontos não passam para o próximo bloco")
	t.equal(G.dig_target(c), "1:1", "a comunidade passa ao bloco seguinte")
	# Trocar de frente guarda o que já foi cavado.
	_return(c, 1003)
	t.equal(G.block_progress(c, "1:1"), 1, "um ponto no bloco 1")
	G.set_dig_target(c, "L2")
	_return(c, 1004)
	t.equal([G.block_progress(c, "1:1"), G.block_progress(c, "L2")], [1, 1], "a troca de frente guarda o ponto do bloco 1")
	# A volta com a mesma expedição não escava de novo.
	J.start_expedition(c, "fase_1", 1004)
	c.last_returned_expedition_id = "exp_1004"
	c.session.result = "victory"
	S.finish_return(c)
	t.equal(G.block_progress(c, "L2"), 1, "a mesma volta não escava duas vezes")
	# Sem nada para escavar, a volta não traz a linha.
	var full := _campaign()
	for key in G.block_keys():
		_open(full, key)
	t.check(_return(full, 1005).get("dig", {}).is_empty() and G.dig_step(full).is_empty(), "com tudo aberto, nada para escavar nem no Próximo passo")
	# O texto aprovado: "Escavação: o 2º subsolo, vaga 5, foi aberto. 3 sucatas e um curativo."
	t.equal(G.report_line({"block": "2:5", "opened": true, "finds": {"scrap": 3, "bandages": 1}}), "Escavação: o 2º subsolo, vaga 5, foi aberto. 3 sucatas e um curativo.", "a linha do relatório como aprovada")
	t.equal(G.report_line({"block": "L2", "opened": true, "finds": {"scrap": 1}}), "Escavação: o patamar do 2º subsolo foi aberto. 1 sucata.", "e a do patamar")


func _digger() -> void:
	var c := _campaign()
	c.station.rooms[S.CHARACTERS] = 4
	var tatu := _recruit(c, "tatu", "Casco")
	var guaxinim := _recruit(c, "rato", "Risco")
	var cao := _recruit(c, "cao", "Brasa")
	for entry in [tatu, guaxinim, cao]:
		entry.perks = []
	t.check(S.job_rooms(c).has(G.DIG), "com entulho para cavar, existe o posto de escavador")
	t.equal(S.post_name(G.DIG), TranslationServer.translate("Escavação"), "o posto se chama Escavação")
	t.equal([S.post_yield(cao, G.DIG), S.post_yield(tatu, G.DIG), S.post_yield(guaxinim, G.DIG)], [1, 2, 2], "o escavador soma 1; o tatu e o guaxinim, 2")
	cao.perks = ["hopeful"]
	t.equal(S.post_yield(cao, G.DIG), 2, "o esperançoso soma 1 a mais")
	cao.perks = ["gloomy"]
	t.equal(S.post_yield(cao, G.DIG), 0, "o pessimista, 1 a menos")
	t.equal(S.set_post(c, tatu.id, G.DIG), "", "o tatu fica na escavação")
	t.equal(S.yield_text(G.DIG, 2), TranslationServer.translate("+%d pontos de obra por volta") % 2, "o rendimento em pontos de obra")
	_open(c, "L2")
	G.set_dig_target(c, "2:7")
	t.equal([G.dig_rate(c), G.returns_left(c, "2:7")], [3, 1], "com o tatu, um bloco do 2º subsolo sai em 1 volta")
	S.set_post(c, cao.id, G.DIG)
	cao.perks = []
	t.equal(G.returns_left(c, "2:7"), 2, "com um escavador, em 2")
	S.set_post(c, cao.id, "")
	t.equal(G.returns_left(c, "2:7"), 3, "sem escavador, em 3")
	S.set_post(c, tatu.id, G.DIG)
	var report := _return(c, 2001)
	t.check(report.dig.opened and int(report.dig.points) == 3, "o tatu que ficou abre o bloco do 2º subsolo na volta")
	t.check(report.posts.any(func(p): return p.room == G.DIG and int(p.amount) == 2), "o relatório mostra o posto de escavador")
	# Aberto o último bloco, o escavador fica sem posto.
	var last := _campaign()
	for key in G.block_keys():
		if key != "3:1":
			_open(last, key)
	var digger := _recruit(last, "tatu", "Casco")
	S.set_post(last, digger.id, G.DIG)
	G.grid(last).progress["3:1"] = 3
	t.check(_return(last, 2002).dig.opened and S.post_of(digger) == "", "aberto o último bloco, o escavador sai do posto")
	# Quem está em recuperação não cava.
	tatu.recovery_days = 2
	t.equal(G.dig_rate(c), 1, "o escavador em recuperação não cava")
	tatu.recovery_days = 0
	t.equal(G.dig_rate(c, [tatu.id]), 1, "quem parte na equipe também não")
	# Sem entulho, o posto some (e escolher dá o motivo).
	var full := _campaign()
	for key in G.block_keys():
		_open(full, key)
	t.check(not S.job_rooms(full).has(G.DIG), "sem entulho, sem o posto")
	t.equal(S.set_post(full, full.roster[0].id, G.DIG), TranslationServer.translate("Não há entulho para escavar."), "e escolher dá o motivo")
	t.equal(S.room_in(G.DIG), TranslationServer.translate("na escavação"), "a Preparação diz \"deixa o posto na escavação\"")


## Um recruta que fica na Estação (fora da formação salva, que parte).
func _recruit(c: Dictionary, class_id: String, given_name: String) -> Dictionary:
	if not c.unlocked_classes.has(class_id):
		c.unlocked_classes.append(class_id)
	var result: Dictionary = S.recruit(c, class_id, RandomNumberGenerator.new(), given_name)
	t.equal(result.get("error", ""), "", "%s chega à Estação" % given_name)
	return S.hero(c, String(result.get("hero_id", "")))


func _finds() -> void:
	var counts := {"1": 0, "2": 0, "3": 0, "L": 0}
	var minimum_ok := true
	var same := true
	var rare := 0
	for i in 200:
		for key in ["1:2", "2:7", "3:7", "L2"]:
			var a := _campaign()
			var b := _campaign()
			var fa: Dictionary = G._find(a, "exp_%d" % i, key)
			var fb: Dictionary = G._find(b, "exp_%d" % i, key)
			same = same and fa == fb
			var row := G.block_rule(key)
			minimum_ok = minimum_ok and int(fa.scrap) >= int(row.Scrap) and int(fa.fragments) >= int(row.Fragments)
			minimum_ok = minimum_ok and S.quantity(a, "scrap") == int(fa.scrap) and not fa.texts.is_empty()
			if int(fa.bandages) > 0 or fa.tool != "" or fa.relic != "":
				rare += 1
			counts[key.left(1)] += 1
	t.check(same, "a mesma volta e o mesmo bloco dão sempre o mesmo achado")
	t.check(minimum_ok, "todo bloco devolve pelo menos o mínimo do andar, já no estoque, com o texto")
	t.check(rare > 40 and rare < 200, "o item raro sai às vezes (%d em 800)" % rare)
	# O patamar não tem sorteio nem item raro.
	var landing: Dictionary = G._find(_campaign(), "exp_x", "L2")
	t.equal([int(landing.scrap), int(landing.seeds), int(landing.fragments), int(landing.bandages)], [1, 0, 0, 0], "o patamar devolve 1 sucata")
	t.equal(landing.texts, [String(G.rule("landing").Text)], "com o texto da escada")
	# Sem nada novo para dar, o item raro vira curativo: a equipe com todas as ferramentas e todas as relíquias.
	var only_bandages := true
	var any_rare := false
	for i in 300:
		var c := _campaign()
		c.tools = ["lanterna", "mascara", "pe_de_cabra"]
		c.inventory.relics = GameData.table("relics").keys()
		var f: Dictionary = G._find(c, "exp_full_%d" % i, "3:7")
		only_bandages = only_bandages and f.tool == "" and f.relic == ""
		any_rare = any_rare or int(f.bandages) > 0
	t.check(only_bandages and any_rare, "sem ferramenta nem relíquia nova, o item raro vira curativo")
	# A ferramenta e a relíquia saem novas e entram no estoque.
	var tool_ok := true
	var relic_ok := true
	for i in 400:
		var c := _campaign()
		c.tools = ["lanterna"]
		var f: Dictionary = G._find(c, "exp_tool_%d" % i, "3:7")
		if f.tool != "":
			tool_ok = tool_ok and f.tool != "lanterna" and c.tools.has(f.tool)
		if f.relic != "":
			relic_ok = relic_ok and c.inventory.relics.has(f.relic)
	t.check(tool_ok, "a ferramenta do achado é uma que a equipe não tem, e entra na Mochila")
	t.check(relic_ok, "a relíquia entra no estoque")
	var text := G.finds_text({"scrap": 3, "bandages": 1})
	t.equal(text, TranslationServer.translate("%s e %s") % [TranslationServer.translate("%d sucatas") % 3, TranslationServer.translate("um curativo")], "\"3 sucatas e um curativo\"")


func _build() -> void:
	var c := _campaign()
	c.inventory.scrap = 40
	c.inventory.fragments = 10
	t.equal(S.upgrade_block(c, S.RESEARCH), TranslationServer.translate("Falta uma vaga dupla livre para %s: escave o entulho até abrir duas vagas vizinhas.") % S.room_the(S.RESEARCH), "a Pesquisa soterrada pede uma vaga dupla")
	t.check(S.upgrade_room(c, S.RESEARCH, 0) != "" and S.room_level(c, S.RESEARCH) == 0, "e não se constrói")
	t.equal(S.upgrade_block(c, S.DEPOT), TranslationServer.translate("Falta uma vaga livre para %s: escave o entulho para abrir uma.") % S.room_the(S.DEPOT), "construir o Depósito pede uma vaga")
	_open(c, "1:2")
	t.equal(G.free_spots(c, S.DEPOT), ["1:2"], "aberto um bloco, o Depósito cabe nele")
	t.check(G.buried(c, S.RESEARCH), "a Pesquisa ainda não: uma vaga só")
	_open(c, "1:1")
	t.equal(G.free_spots(c, S.RESEARCH), ["1:1"], "abertos os dois, a Pesquisa cabe")
	t.equal(S.build_room(c, S.RESEARCH, "1:2"), TranslationServer.translate("%s não cabe nessa vaga.") % "O Centro de Pesquisa", "o duplo não cabe começando na vaga 2 (a 3 é da Forja)")
	t.equal(S.build_room(c, S.FORGE, "1:1"), TranslationServer.translate("Este cômodo já tem lugar na Estação."), "a Forja parada já tem lugar")
	var scrap := S.quantity(c, "scrap")
	t.equal(S.build_room(c, S.RESEARCH, "1:1"), "", "constrói a Pesquisa nas vagas 1 e 2")
	t.check(S.room_level(c, S.RESEARCH) == 1 and G.cell(c, 1, 1) == S.RESEARCH and G.cell(c, 1, 2) == S.RESEARCH, "a Pesquisa ocupa as duas vagas, no nível 1")
	t.equal(S.quantity(c, "scrap"), scrap - 3, "pelo custo de hoje")
	t.equal(S.build_room(c, S.RESEARCH, "1:1"), TranslationServer.translate("Este cômodo já tem lugar na Estação."), "um cômodo de cada tipo")
	# A Forja parada se recupera no lugar dela, sem vaga nova.
	t.equal(S.upgrade_room(c, S.FORGE, 0), "", "a Forja parada se recupera")
	t.equal(G.room_spot(c, S.FORGE), "1:3", "no mesmo lugar")
	# A Cantina construída: vaga dupla, 3 sucatas, +1 suprimento por volta.
	t.check(G.buried(c, S.CANTEEN), "sem vaga dupla, a Cantina não se constrói")
	_open(c, "L2")
	_open(c, "2:7")
	_open(c, "2:6")
	var before := S.forecast(c, 4)
	t.equal(S.upgrade_room(c, S.CANTEEN, 1), "", "com a vaga dupla do 2º subsolo, constrói a Cantina")
	t.check(S.room_level(c, S.CANTEEN) == 2 and G.room_spot(c, S.CANTEEN) == "2:6", "a Cantina vai para a primeira vaga livre onde cabe")
	var after := S.forecast(c, 4)
	if before.food_produced > 0:
		t.equal(after.food_produced, before.food_produced + 1, "a Cantina construída rende mais 1 suprimento por volta")
	t.equal(S.canteen_food(c), S.CANTEEN_FOOD + 1, "o fogareiro rendia 2; a Cantina, 3")
	t.check(S.next_level_cost(c, S.CANTEEN).is_empty(), "a Cantina construída está no nível máximo")


func _next_step() -> void:
	var c := _campaign()
	var step := S.next_step(c)
	t.equal(step.room, S.FORGE, "na campanha nova, o Próximo passo aponta a Forja parada (a visita guiada continua igual)")
	c.station.rooms[S.FORGE] = 1
	G.place(c, S.FORGE, "1:3")
	c.inventory.scrap = 0
	step = S.next_step(c)
	t.equal(step.title, TranslationServer.translate("Escavar o entulho do %dº subsolo") % 1, "com a Pesquisa soterrada, o Próximo passo manda escavar")
	t.equal(step.action, "depart", "a escavação anda com as voltas: o botão leva ao mapa")
	t.check(not String(S.focus_reason(c, S.FOCUS_PARTS)).contains(TranslationServer.translate("a Pesquisa")), "o foco em peças não pede sucata para a Pesquisa soterrada")
	_open(c, "1:2")
	_open(c, "1:1")
	t.check(S.next_step(c).get("block", "") == "", "com a vaga dupla, o Próximo passo deixa de mandar escavar")
	c.inventory.scrap = 3
	c.inventory.fragments = 2
	t.equal(S.next_step(c).room, S.RESEARCH, "e pede a Pesquisa quando dá para pagar")
	# O save antigo: tudo construído; o patamar do 3º subsolo só quando não sobra nada para construir nem fase nova.
	var old := _legacy()
	S.migrate(old)
	t.check(S.next_step(old).get("block", "") == "", "no save antigo, o Próximo passo não manda escavar à toa")
	for room in S.ROOMS:
		old.station.rooms[room.id] = room.max_level
	G.heal(old)
	old.completed_phases = J.PHASES.map(func(p): return p.id)
	t.equal(S.next_step(old).get("block", ""), "L3", "sem nada para construir, aponta o patamar do 3º subsolo")


## Um save de antes da grade: a Estação de hoje, sem a grade, com o tutorial já feito.
func _legacy() -> Dictionary:
	var c := _campaign()
	c.station.erase("grid")
	for room in S.ROOMS:
		c.station.rooms[room.id] = 1
	c.station.rooms[S.FORGE] = 0
	c.station.rooms[S.BAR] = 0
	return c


func _saves() -> void:
	var old := _legacy()
	S.migrate(old)
	var cells: Array = G.grid(old).cells
	t.equal(cells[0], [S.DORMITORY, S.DORMITORY, S.CHARACTERS, S.BAR, S.CANTEEN, S.CANTEEN, G.FREE], "a planta herdada no 1º subsolo: o Bar parado e a vaga livre que sobra")
	t.equal(cells[1], [S.INFIRMARY, S.INFIRMARY, S.RESEARCH, S.RESEARCH, G.FREE, S.FORGE, S.FORGE], "no 2º: o Depósito de nível 1 vira os caixotes e a vaga fica livre")
	t.check(cells[2].all(func(id): return id == ""), "o 3º subsolo soterrado")
	t.equal(G.grid(old).landings, [true, false], "o patamar do 2º aberto, o do 3º não")
	t.equal(S.room_level(old, S.CANTEEN), 2, "a Cantina de hoje vira a Cantina construída")
	t.equal([S.room_level(old, S.FORGE), S.room_level(old, S.BAR)], [0, 0], "os níveis não mudam: a Forja e o Bar seguem parados, na vaga deles")
	var buried: Array = S.ROOMS.filter(func(r): return G.room_slots(r.id) > 0 and S.room_level(old, r.id) >= G.build_level(r.id) and not G.placed(old, r.id))
	t.check(buried.is_empty(), "nenhum cômodo construído fica soterrado: %s" % [buried])
	t.check(not G.grid(old).intro_seen, "o save antigo vê a fala da escavação uma vez")
	# O Depósito no nível 2 fica na vaga.
	var depot := _legacy()
	depot.station.rooms[S.DEPOT] = 2
	S.migrate(depot)
	t.equal(G.room_spot(depot, S.DEPOT), "2:5", "o Depósito no nível 2 fica na vaga dele")
	# Idempotente: abrir de novo não muda nada, nem a Cantina.
	var again: Dictionary = old.duplicate(true)
	S.migrate(again)
	t.equal(again.station.grid, old.station.grid, "migrar de novo não muda a grade")
	t.equal(S.room_level(again, S.CANTEEN), 2, "nem a Cantina")
	# O save volta igual do JSON, com os pontos guardados.
	var c := _campaign()
	_return(c, 3001)
	G.set_dig_target(c, "1:2")
	var reopened = Campaign._normalize(JSON.parse_string(JSON.stringify(c)))
	S.migrate(reopened)
	t.equal(reopened.station.grid, c.station.grid, "o save guarda a grade, a frente e os pontos")
	t.equal(G.block_progress(reopened, "1:2"), 1, "e o ponto volta inteiro")
	# Ainda na abertura do tutorial (a visita guiada por fazer), o save começa como a campanha nova.
	var opening := _campaign()
	opening.station.erase("grid")
	opening.tutorial = {"stage": "station"}
	S.migrate(opening)
	t.equal(G.grid(opening).cells[0], ["", "", S.FORGE, S.FORGE, S.CHARACTERS, S.DORMITORY, S.DORMITORY], "o save na visita guiada começa como a campanha nova")
	t.equal(S.room_level(opening, S.CANTEEN), 1, "com o fogareiro")
	var changed := _campaign()
	changed.station.erase("grid")
	changed.tutorial = {"stage": "station"}
	changed.station.rooms[S.RESEARCH] = 1
	S.migrate(changed)
	t.check(G.placed(changed, S.RESEARCH), "com um cômodo já recuperado, recebe a planta herdada e nada fica soterrado")
	# O save de antes da Estação (sem cômodos) abre com tudo recuperado e no lugar.
	var ancient := _campaign()
	ancient.erase("station")
	S.migrate(ancient)
	t.check(S.ROOMS.all(func(r): return G.room_slots(r.id) <= 0 or S.room_level(ancient, r.id) < G.build_level(r.id) or G.placed(ancient, r.id)), "o save de antes da Estação abre sem cômodo soterrado")
	# A barra de Admin: todos os cômodos recuperados ganham vaga, desentulhada se preciso.
	var admin := _campaign()
	for room in S.ROOMS:
		admin.station.rooms[room.id] = maxi(1, int(admin.station.rooms.get(room.id, 0)))
	G.heal(admin)
	t.check([S.RESEARCH, S.INFIRMARY, S.BAR, S.FORGE].all(func(id): return G.placed(admin, id)), "todos recuperados pela barra de Admin, todos com vaga")
	t.check(G.grid(admin).landings[0] == G.grid(admin).cells[1].any(func(id): return id != ""), "o patamar abre junto com o andar")


func _intro() -> void:
	var c := _campaign()
	t.check(not G.intro_pending(c), "antes da primeira volta, nada")
	_return(c, 4001)
	t.check(G.intro_pending(c), "a primeira volta com escavação traz a fala")
	var lines := G.intro_lines(c)
	t.equal(lines.map(func(l): return l.speaker), [G.BENTO, G.NICK, G.BENTO], "o Bento e o Nick conversam")
	t.equal(lines[0].text, "Ouviu isso? Tem vento passando atrás do entulho.", "com o texto aprovado")
	S.hero(c, G.NICK).recovery_days = 2
	t.equal(G.intro_lines(c), [{"speaker": "", "text": "Atrás do entulho tem mais estação."}], "com o Nick caído, só o cartão")
	G.see_intro(c)
	_return(c, 4002)
	t.check(not G.intro_pending(c), "a fala aparece uma vez só")
