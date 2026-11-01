## Os limites e os postos da Estação (#119): heróis pelo Alojamento (com o caído contando) e ajudantes pelo Dormitório,
## o recrutamento e o civil barrados com a casa cheia; um posto por herói e um herói por cômodo; quem parte deixa o
## posto; o rendimento pela espécie e pelos traços; o efeito aplicado na volta e mostrado no relatório; o save antigo.
## Na tela: a barra com os limites, o Posto na Sala, "Quem trabalha aqui" no cômodo e o aviso na plataforma.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const J = preload("res://scripts/flow/journey_rules.gd")
const FOUNDERS := ["hero_cao_bento", "hero_coruja_vespera", "hero_gato_nick", "hero_sapo_iris"]

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_limits()
	_posts()
	_yields()
	_return()
	_edges()
	_old_save()
	await _screens()


## Os fundadores e dois recrutas (uma coruja e um cão), com a Pesquisa, a Forja, a Enfermaria e o Alojamento (8) prontos.
func _campaign() -> Dictionary:
	var c: Dictionary = Campaign.create_initial(119)
	c.station.rooms[S.CHARACTERS] = 2
	for room in [S.RESEARCH, S.FORGE, S.INFIRMARY]:
		c.station.rooms[room] = 1
	S.recruit(c, "coruja", RandomNumberGenerator.new(), "Sereno")
	S.recruit(c, "cao", RandomNumberGenerator.new(), "Brasa")
	for entry in c.roster:
		entry.perks = []
	return c


func _id(c: Dictionary, name: String) -> String:
	return S.living(c).filter(func(h): return h.display_name == name)[0].id


func _limits() -> void:
	var c: Dictionary = Campaign.create_initial(1)
	t.equal(S.hero_limit(c), 6, "o Alojamento no nível 1 comporta 6 heróis")
	t.equal(S.helper_limit(c), 3, "com o Dormitório sem camas, 3 ajudantes")
	t.equal([1, 2, 3, 4].map(func(level): return S.hero_limit_at(level)), [6, 8, 10, 12], "os limites de cada nível do Alojamento")
	var dorm := Campaign.create_initial(1)
	dorm.station.rooms[S.DORMITORY] = S.room_def(S.DORMITORY).max_level
	var helpers: Array = GameData.row("hero_jobs", "limit_helpers").Levels
	t.equal(S.helper_limit(dorm), int(helpers.back()), "o último limite de ajudantes é o do Dormitório no nível máximo (nenhum inalcançável)")
	t.equal(helpers.size(), S.room_def(S.DORMITORY).max_level, "um limite de ajudantes por nível do Dormitório (#176: o chão e os beliches)")
	t.equal(S.limits_text(c), "Heróis 4 de 6 · Ajudantes 0 de 3", "o texto da barra")
	S.recruit(c, "cao", RandomNumberGenerator.new(), "A")
	S.recruit(c, "gato", RandomNumberGenerator.new(), "B")
	t.check(S.heroes_full(c), "com seis, o Alojamento enche")
	t.check(S.recruit(c, "sapo", RandomNumberGenerator.new(), "C").error.contains("cheio"), "recrutar com a casa cheia fica barrado, com o motivo")
	# O caído conta no limite.
	S.admit_fallen(c, [_id(c, "A")])
	t.check(S.heroes_full(c), "quem está em recuperação conta")
	# Com a casa cheia, o trem não traz animal (#182: ele ia embora na partida, e o trem parecia parado).
	S.train_on_return(c, "limits", "hero")
	c.inventory.seeds = 50
	t.check(S.train_recruit(c).is_empty(), "com a casa cheia, o trem não traz animal")
	# Ampliar o Alojamento: o limite sobe.
	c.inventory.scrap = 20
	c.inventory.fragments = 5
	t.equal(S.upgrade_room(c, S.CHARACTERS, 1), "", "amplia o Alojamento")
	t.equal(S.hero_limit(c), 8, "nível 2: 8 heróis")
	t.equal(S.recruit_block(c), "", "e o animal do trem pode entrar")
	# Os ajudantes: com a casa cheia de civis, o civil não chega, e acolher fica barrado.
	var d: Dictionary = Campaign.create_initial(2)
	d.station.residents = [S.DORA, S.OTTO, S.CORA].slice(0, S.helper_limit(d))
	d.station.candidate_queue = [S.CORA]
	d.station.residents = [S.DORA, S.OTTO, "extra"]
	t.check(S.helpers_full(d), "três ajudantes: o Dormitório cheio")
	S.train_on_return(d, "helpers", "civilian")
	t.check(d.station.train.recruit.size() > 0, "o civil não chega sem lugar (veio um animal)")
	d.station.train = {"phase": "waiting", "candidate_id": S.CORA, "expedition_id": "x", "accepted": false, "recruit": {}}
	t.check(S.decide_candidate(d, S.CORA, true).contains("ajudantes"), "acolher o civil com a casa cheia fica barrado")


func _posts() -> void:
	var c := _campaign()
	var sereno := _id(c, "Sereno")
	var brasa := _id(c, "Brasa")
	# Com entulho para cavar, também o posto de escavador (#186).
	t.equal(S.job_rooms(c), [S.RESEARCH, S.FORGE, S.CANTEEN, S.INFIRMARY, AHStationGrid.DIG], "os postos dos cômodos recuperados e o de escavador")
	var d: Dictionary = Campaign.create_initial(3)
	t.equal(S.job_rooms(d), [S.CANTEEN, AHStationGrid.DIG], "na campanha nova, só a Cantina e a escavação")
	t.check(S.set_post(d, "hero_cao_bento", S.FORGE) != "", "sem a Forja, sem o posto dela")
	t.equal(S.set_post(c, sereno, S.RESEARCH), "", "a coruja vai para a Pesquisa")
	t.equal(S.set_post(c, sereno, S.FORGE), "", "e muda para a Forja: um posto por herói")
	t.equal(S.post_of(S.hero(c, sereno)), S.FORGE, "só o último vale")
	t.equal(S.set_post(c, brasa, S.FORGE), "", "o cão vai para a Forja")
	t.check(S.post_of(S.hero(c, sereno)) == "" and S.worker(c, S.FORGE).id == brasa, "um herói por cômodo: a coruja sai")
	S.admit_fallen(c, [brasa])
	t.check(S.post_of(S.hero(c, brasa)) == "", "quem cai deixa o posto")
	t.check(S.set_post(c, brasa, S.FORGE).contains("recuperação"), "e não pega posto em recuperação")
	# Quem parte deixa o posto.
	var e := _campaign()
	S.set_post(e, "hero_cao_bento", S.FORGE)
	S.set_post(e, _id(e, "Sereno"), S.RESEARCH)
	# Uma partida recusada não tira ninguém do posto (os postos só saem com a expedição começada).
	e.inventory.seeds = 0
	t.check(S.confirm_departure(e, FOUNDERS.duplicate(), 2, 9, "fase_1") != "" and S.post_of(S.hero(e, "hero_cao_bento")) == S.FORGE, "a partida recusada deixa o Bento na Forja")
	e.inventory.seeds = 12
	t.equal(S.confirm_departure(e, FOUNDERS.duplicate(), 0, 9, "fase_1"), "", "a equipe parte")
	t.check(S.post_of(S.hero(e, "hero_cao_bento")) == "" and S.post_of(S.hero(e, _id(e, "Sereno"))) == S.RESEARCH, "o Bento deixa a Forja; a coruja fica na Pesquisa")


func _yields() -> void:
	var c := _campaign()
	var coruja = S.hero(c, _id(c, "Sereno"))
	var cao = S.hero(c, _id(c, "Brasa"))
	t.equal(S.post_yield(coruja, S.RESEARCH), 2, "a coruja rende 2 na Pesquisa")
	t.equal(S.post_yield(cao, S.RESEARCH), 1, "o cão rende 1")
	t.equal(S.post_yield(cao, S.FORGE), 2, "e 2 na Forja")
	t.equal(S.post_yield(S.hero(c, "hero_sapo_iris"), S.INFIRMARY), 2, "o sapo rende 2 na Enfermaria")
	cao.perks = ["hopeful"]
	t.equal(S.post_yield(cao, S.CANTEEN), 2, "o esperançoso rende um a mais")
	cao.perks = ["gloomy"]
	t.equal(S.post_yield(cao, S.CANTEEN), 0, "o pessimista, um a menos")
	t.equal(S.post_yield(cao, S.FORGE), 1, "mesmo na Forja")
	t.equal(S.yield_text(S.RESEARCH, 2), "+2 fragmentos por volta", "o texto do rendimento")


## Na volta, cada posto de quem ficou rende; o relatório mostra.
func _return() -> void:
	var c := _campaign()
	var sereno := _id(c, "Sereno")
	var brasa := _id(c, "Brasa")
	S.set_post(c, sereno, S.RESEARCH)
	S.set_post(c, brasa, S.FORGE)
	S.admit_fallen(c, ["hero_cao_bento"])
	S.recruit(c, "sapo", RandomNumberGenerator.new(), "Lupa")
	var lupa := _id(c, "Lupa")
	S.set_post(c, lupa, S.INFIRMARY)
	var team: Array = ["hero_coruja_vespera", "hero_gato_nick", "hero_sapo_iris"]
	var days: int = S.recovery_days(S.hero(c, "hero_cao_bento"))
	var fragments := S.quantity(c, "fragments")
	var scrap := S.quantity(c, "scrap")
	t.equal(S.confirm_departure(c, team, 0, 9, "fase_1"), "", "parte com três")
	c.session.expedition.loot = {}
	c.session.result = "retreat"
	var delivered := S.finish_return(c)
	t.equal(S.quantity(c, "fragments"), fragments + 2, "a coruja na Pesquisa: +2 fragmentos")
	t.equal(S.quantity(c, "scrap"), scrap + 2, "o cão na Forja: +2 sucatas")
	t.equal(days, 2, "o Bento no leito: 2 dias")
	t.equal(S.recovery_days(S.hero(c, "hero_cao_bento")), 0, "o dia que passou e o da Enfermaria: o Bento volta")
	t.check(delivered.recovered.has("hero_cao_bento"), "e o relatório diz que ele voltou")
	var rooms: Array = delivered.posts.map(func(p): return p.room)
	rooms.sort()
	t.equal(rooms, [S.FORGE, S.INFIRMARY, S.RESEARCH], "o relatório traz os três postos")
	t.equal(delivered.posts.filter(func(p): return p.room == S.RESEARCH)[0].amount, 2, "com o que cada um rendeu")


## O que a QA achou (#119): o voluntário espera lugar, a Cantina respeita o Depósito e o Plano diz o que o Alojamento dá.
func _edges() -> void:
	var c: Dictionary = Campaign.create_initial(5)
	S.recruit(c, "cao", RandomNumberGenerator.new(), "A")
	S.recruit(c, "gato", RandomNumberGenerator.new(), "B")
	c.pending_offers = [{"class_id": "cao", "display_name": "Casco"}]
	t.equal(S.receive_volunteers(c, RandomNumberGenerator.new()), 0, "com o Alojamento cheio, o voluntário não entra")
	t.equal(c.pending_offers.size(), 1, "e continua esperando lugar")
	var d := _campaign()
	var brasa := _id(d, "Brasa")
	S.hero(d, brasa).perks = ["hopeful"]
	S.set_post(d, brasa, S.CANTEEN)
	S.adjust(d, S.SUPPLIES, 50)
	S.confirm_departure(d, FOUNDERS.duplicate(), 0, 9, "fase_1")
	d.session.expedition.loot = {}
	d.session.result = "retreat"
	S.finish_return(d)
	t.check(S.quantity(d, S.SUPPLIES) <= S.supply_capacity(d), "o posto da Cantina não passa do Depósito (%d)" % S.quantity(d, S.SUPPLIES))
	t.check(S.room_benefit(S.CHARACTERS, 2).contains("8 heróis"), "o Plano diz o que o Alojamento no nível 2 comporta")
	t.equal(S.room_in(S.RESEARCH), "no Centro de Pesquisa", "o artigo do cômodo")


func _old_save() -> void:
	var c := _campaign()
	for name in ["X1", "X2", "X3"]:
		c.station.rooms[S.CHARACTERS] = 4
		# Um save antigo, de antes do #182: três gatos com o mesmo rosto.
		S._add_hero(c, S._next_hero_id(c, "gato"), "gato", name, [], "cat_recruit_01")
	c.station.rooms[S.CHARACTERS] = 1
	for entry in c.roster:
		entry.erase("post")
	var reopened = Campaign._normalize(JSON.parse_string(JSON.stringify(c)))
	S.migrate(reopened)
	t.check(reopened.roster.all(func(h): return h.get("post", "x") == ""), "o save antigo abre sem posto")
	t.equal(S.room_level(reopened, S.CHARACTERS), 3, "e o Alojamento cresce até caber os 9 que já moram lá")
	t.check(S.living(reopened).size() <= S.hero_limit(reopened), "ninguém fica de fora")


func _screens() -> void:
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-hero-jobs-%d" % Time.get_ticks_usec()
	var c := _campaign()
	S.set_post(c, _id(c, "Brasa"), S.FORGE)
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("station", {}, false)
	var station: AHStation = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and GameFlow.passage == null and _tree.current_scene is AHStation and frame > 3:
			station = _tree.current_scene
			break
	if t.check(station != null, "a Estação abriu"):
		var hud: AHRefugeHud = station.hud
		await _frames(3)
		t.check(_label(hud._frame, "Heróis 6 de 8"), "a barra mostra os limites")
		# O Posto na Sala.
		hud.open_room(S.CHARACTERS)
		await _frames(3)
		var room: AHCharacterRoom = hud._room_screen
		room._select(_id(c, "Sereno"))
		await _frames(3)
		var chip: Button = room.find_child("Post_research", true, false)
		if t.check(chip != null, "a Sala tem o Posto, com a Pesquisa"):
			chip.pressed.emit()
			await _frames(3)
			t.equal(S.post_of(S.hero(Campaign.state, _id(c, "Sereno"))), S.RESEARCH, "escolher o posto na Sala vale")
			t.check(_label(hud._room_screen, "+2 fragmentos por volta"), "e mostra o que rende")
		# No teclado, o foco fica no posto escolhido depois da escolha.
		AHUiStyle.using_keys = true
		var forge: Button = hud._room_screen.find_child("Post_forge", true, false)
		forge.grab_focus()
		forge.pressed.emit()
		await _frames(4)
		var owner := _tree.root.gui_get_focus_owner()
		t.equal(String(owner.name) if owner != null else "", "Post_forge", "o foco continua no posto escolhido")
		AHUiStyle.using_keys = false
		t.check(_label(hud._room_screen, "Heróis 6 de 8"), "a Sala mostra os limites")
		hud.close_panel()
		await _frames(2)
		# Quem trabalha aqui, no cômodo.
		hud.open_room(S.FORGE)
		await _frames(3)
		t.check(_label(hud._panel, "Quem trabalha aqui") and _label(hud._panel, "Sereno ·"), "a Forja diz quem trabalha nela (o Sereno, que tirou o Brasa)")
		var bento: Button = hud._panel.find_child("Worker_hero_cao_bento", true, false)
		if t.check(bento != null, "e quem pode ficar no lugar"):
			bento.pressed.emit()
			await _frames(3)
			t.equal(S.worker(Campaign.state, S.FORGE).id, "hero_cao_bento", "trocar pelo cômodo vale")
		hud.close_panel()
		await _frames(2)
		# A plataforma avisa quem deixa o posto.
		hud._draft = {}
		hud.open_map()
		hud._on_phase_chosen("fase_1")
		hud._briefed = "fase_1"
		await _frames(3)
		t.check(_label(hud._departure, "deixa o posto na Forja"), "a plataforma avisa que o Bento deixa a Forja")
		hud.close_panel()
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


func _label(root: Node, part: String) -> bool:
	return root.find_children("*", "Label", true, false).any(func(l): return (l as Label).text.contains(part))


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
