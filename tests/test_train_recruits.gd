## O recrutamento pelo trem (#122): na volta, o trem às vezes traz alguém (um animal de uma classe liberada ou um civil
## da fila), às vezes ninguém, com a mesma volta dando sempre o mesmo; a chance sobe a cada volta vazia. Na plataforma:
## aceitar (o custo), recusar (vai embora e não volta), não decidir (vai embora na partida), a casa cheia, o save no meio
## e o save antigo. Na tela: o + RECRUTAR saiu da Sala, o painel do trem mostra o animal, e o relatório diz quem chegou.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const J = preload("res://scripts/flow/journey_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_draw()
	_chance()
	_recruit_arrives()
	_accept_and_refuse()
	_no_decision()
	_full_house()
	_saves()
	_report_and_next_step()
	await _screens()


func _campaign(seed_value: int = 122) -> Dictionary:
	var c: Dictionary = Campaign.create_initial(seed_value)
	return c


## Uma volta da expedição: a vitória da fase 1, com o id dado (o sorteio do trem sai dele).
func _return(c: Dictionary, expedition_id: String) -> Dictionary:
	J.start_expedition(c, "fase_1", 7)
	c.session.expedition.id = expedition_id
	c.session.result = "victory"
	var delivered := S.finish_return(c)
	S.resolve_night(c)
	S.finish_dawn(c)
	return delivered


## O sorteio: a mesma volta traz sempre o mesmo; em muitas voltas, umas trazem alguém e outras não.
func _draw() -> void:
	var base := _campaign()
	var a: Dictionary = base.duplicate(true)
	var b: Dictionary = base.duplicate(true)
	S.train_on_return(a, "exp-same")
	S.train_on_return(b, "exp-same")
	t.equal(a.station.train, b.station.train, "a mesma volta traz sempre o mesmo")
	var arrived := 0
	var heroes := 0
	for i in 60:
		var c: Dictionary = base.duplicate(true)
		if S.train_on_return(c, "exp-%d" % i):
			arrived += 1
			heroes += 1 if not c.station.train.recruit.is_empty() else 0
	t.check(arrived > 5 and arrived < 45, "em 60 voltas, umas trazem alguém e outras não (%d chegaram)" % arrived)
	t.check(heroes > 0 and heroes < arrived, "chegam animais e civis (%d animais)" % heroes)
	var c: Dictionary = base.duplicate(true)
	t.check(S.train_on_return(c, "exp-force", "hero") and not c.station.train.recruit.is_empty(), "a barra de Admin força um animal")
	t.check(not S.train_on_return(c, "exp-force-2", "hero"), "com alguém esperando, o trem não traz outro")


## A chance: a base de data/recruitment.json e mais um pouco a cada volta vazia; quem chega zera.
func _chance() -> void:
	var c := _campaign()
	var base := S.train_rule("train", "Chance", -1)
	t.equal(S.train_chance(c), base, "a chance começa na base (%d%%)" % base)
	var empty := ""
	for i in 200:
		var probe: Dictionary = c.duplicate(true)
		if not S.train_on_return(probe, "dry-%d" % i):
			empty = "dry-%d" % i
			break
	if not t.check(empty != "", "acha uma volta vazia"):
		return
	S.train_on_return(c, empty)
	t.equal(int(c.station.train_dry), 1, "a volta vazia conta")
	t.equal(S.train_chance(c), base + S.train_rule("train", "ChanceStep", 0), "e a chance sobe")
	c.station.train_dry = 50
	t.equal(S.train_chance(c), S.train_rule("train", "ChanceMax", 0), "até o máximo")
	c.station.train.expedition_id = ""
	t.check(S.train_on_return(c, "after-dry", "hero"), "chega alguém")
	t.equal(int(c.station.train_dry), 0, "e a contagem zera")


## O animal que chega: uma classe liberada com arte, um nome livre, os traços, a variação e de onde veio.
func _recruit_arrives() -> void:
	var c := _campaign()
	S.train_on_return(c, "arrive", "hero")
	var recruit: Dictionary = c.station.train.recruit
	t.check(c.unlocked_classes.has(recruit.class_id), "uma classe liberada (%s)" % recruit.class_id)
	t.check(String(recruit.display_name) != "" and not S.living(c).any(func(h): return h.display_name == recruit.display_name), "com um nome que ninguém usa")
	t.check(recruit.perks.size() >= 2, "com os traços sorteados")
	t.check(String(recruit.origin) != "" and GameData.table("recruitment").values().any(func(r): return r.get("Text", "") == recruit.origin and r.ClassId == recruit.class_id),
		"e uma linha de onde veio, da classe dele")
	t.check(S.hero(c, c.station.train.candidate_id) == null, "ainda fora do elenco")
	t.equal(S.train_candidate_name(c), recruit.display_name, "o nome de quem espera")
	# Uma classe sem arte de luta não chega no trem (o rato, liberado por evento, antes da arte da #187): sem o recruta
	# desenhado dele no manifesto, fica fora; com ele, chega.
	c.unlocked_classes.append("rato")
	t.check(S.train_classes(c).has("rato"), "o rato, com o recruta desenhado, chega")
	var saved_art: Dictionary = S._recruit_art.duplicate(true)
	S._recruit_art.erase("raccoon_recruit_01")
	t.check(not S.train_classes(c).has("rato"), "a classe sem arte de luta não chega")
	S._recruit_art = saved_art


## Aceitar custa o que ele pede; recusar manda embora, e ele não volta.
func _accept_and_refuse() -> void:
	var c := _campaign()
	S.train_on_return(c, "accept", "hero")
	var id: String = c.station.train.candidate_id
	var recruit: Dictionary = c.station.train.recruit.duplicate(true)
	var price := S.recruit_price(c, recruit.class_id)
	t.equal(price, S.train_rule("recruit", "Cost", -1), "pede as sementes de data/ (%d)" % price)
	c.inventory.seeds = price - 1
	t.check(S.recruit_block(c).contains("sementes"), "sem sementes, o motivo")
	t.check(S.decide_candidate(c, id, true) != "" and S.hero(c, id) == null, "e não entra")
	c.inventory.seeds = price + 5
	t.equal(S.decide_candidate(c, id, true), "", "aceita")
	var entry = S.hero(c, id)
	t.check(entry != null and entry.display_name == recruit.display_name and entry.class_id == recruit.class_id, "entra no elenco com o nome e a classe")
	t.equal(entry.perks if entry != null else [], recruit.perks, "com os traços que mostrou")
	t.equal(String(entry.get("art_variant", "")) if entry != null else "", String(recruit.art_variant), "e a arte que mostrou")
	t.equal(S.quantity(c, "seeds"), 5, "pagou o que pediu")
	t.check(S.next_step(c).title != "Chegou alguém no trem", "decidido, o Próximo passo não diz mais que alguém espera")
	t.check(S.finish_departure(c) and c.station.train.recruit.is_empty(), "o trem parte vazio")
	# O id reservado na chegada usado por outro (a Admin recrutou da mesma classe): quem chegou ganha outro.
	var f := _campaign()
	S.train_on_return(f, "same-id", "hero")
	var reserved: String = f.station.train.candidate_id
	# Um segundo rosto da classe, para a Admin poder recrutar (o do trem está reservado, #182).
	var saved_art: Dictionary = S._recruit_art.duplicate(true)
	var cls: String = f.station.train.recruit.class_id
	S._recruit_art["test_%s_02" % cls] = {"class_id": cls, "idle": saved_art[S.art_variants(cls)[0]].idle}
	var other := S.recruit(f, cls, RandomNumberGenerator.new(), "Outro")
	S._recruit_art = saved_art
	t.equal(other.get("hero_id", ""), reserved, "a Admin usa o id reservado")
	f.inventory.seeds = 50
	S.decide_candidate(f, reserved, true)
	var ids: Array = f.roster.map(func(h): return h.id)
	t.equal(ids.size(), {}.merged(Dictionary(ids.reduce(func(acc, id): acc[id] = true; return acc, {}))).size(), "e quem chegou ganha um id novo (sem repetir)")
	# Recusar: vai embora e não volta (o civil recusado, sim, volta ao fim da fila).
	var d := _campaign()
	S.train_on_return(d, "refuse", "hero")
	var refused: String = d.station.train.candidate_id
	var queue: Array = d.station.candidate_queue.duplicate()
	t.equal(S.decide_candidate(d, refused, false), "", "recusa")
	S.finish_departure(d)
	t.check(S.hero(d, refused) == null and d.station.candidate_queue == queue, "não entra nem vai para a fila")
	# Enquanto o elenco não fecha uma equipe de quatro, vem de graça (como o voluntário de antes).
	var e := _campaign()
	e.roster = e.roster.slice(0, 2)
	S.train_on_return(e, "free", "hero")
	t.equal(S.recruit_price(e, e.station.train.recruit.class_id), 0, "com dois no elenco, vem de graça")


## Ninguém decidiu antes da partida: quem esperava vai embora no trem.
func _no_decision() -> void:
	var c := _campaign()
	S.train_on_return(c, "undecided", "hero")
	var id: String = c.station.train.candidate_id
	t.equal(S.preparation_block(c), "", "alguém esperando não trava a partida")
	t.equal(S.confirm_departure(c, c.preferred_formation.duplicate(), 0, 9, "fase_1"), "", "a equipe parte")
	t.check(S.hero(c, id) == null and c.station.train.phase == "none", "e quem esperava foi embora no trem")
	var d := _campaign()
	S.train_on_return(d, "undecided-civ", "civilian")
	var civilian: String = d.station.train.candidate_id
	S.confirm_departure(d, d.preferred_formation.duplicate(), 0, 9, "fase_1")
	t.check(not S.is_resident(d, civilian) and d.station.candidate_queue.back() == civilian, "o civil que ninguém acolheu volta ao fim da fila")


## A casa cheia (#182): o trem não traz animal (ele não teria onde ficar, ia embora na partida e o trem parecia
## parado); com lugar de ajudante, ainda traz o civil.
func _full_house() -> void:
	var c := _campaign()
	var classes := ["cao", "gato", "sapo", "coruja"]
	for i in S.hero_limit(c) - S.living(c).size():
		S.recruit(c, classes[i % 4], RandomNumberGenerator.new(), "Morador %d" % i)
	t.equal(S.living(c).size(), S.hero_limit(c), "o Alojamento cheio")
	t.check(S.train_classes(c).is_empty(), "com a casa cheia, nenhuma classe vem no trem")
	var arrived := S.train_on_return(c, "full", "hero")
	t.check(S.train_recruit(c).is_empty(), "o trem não traz animal")
	t.check(not arrived or not S.civilian(c.station.train.candidate_id).is_empty(), "só o civil, se houver lugar de ajudante")
	# O recruta já esperando (um save de antes) continua barrado com o motivo.
	c.station.train = S._train_defaults()
	c.station.train.phase = "waiting"
	c.station.train.candidate_id = "hero_cao_99"
	c.station.train.recruit = {"class_id": "cao", "display_name": "Antigo", "perks": [], "art_variant": "", "origin": ""}
	c.inventory.seeds = 50
	t.check(S.recruit_block(c).contains("cheio"), "o animal que já esperava fica barrado, com o motivo")
	t.check(S.decide_candidate(c, "hero_cao_99", true) != "" and S.living(c).size() == S.hero_limit(c), "e não entra")


## O save no meio, com alguém esperando, e o save antigo (sem o recruta nem a contagem).
func _saves() -> void:
	var c := _campaign()
	S.train_on_return(c, "saved", "hero")
	var reopened = Campaign._normalize(JSON.parse_string(JSON.stringify(c)))
	S.migrate(reopened)
	t.equal(reopened.station.train.phase, "waiting", "reaberto, ele ainda espera")
	t.equal(reopened.station.train.recruit, c.station.train.recruit, "o mesmo, com os mesmos traços")
	t.equal(S.decide_candidate(reopened, reopened.station.train.candidate_id, true), "", "e dá para aceitar")
	var old := _campaign()
	old.station.train = {"phase": "waiting", "candidate_id": S.DORA, "expedition_id": "old", "accepted": false}
	old.station.erase("train_dry")
	var legacy = Campaign._normalize(JSON.parse_string(JSON.stringify(old)))
	S.migrate(legacy)
	t.check(legacy.station.train.recruit == {} and int(legacy.station.train_dry) == 0, "o save antigo ganha o recruta vazio e a contagem")
	t.equal(S.train_candidate_name(legacy), "Dora", "e a Dora continua esperando")
	t.equal(S.decide_candidate(legacy, S.DORA, true), "", "acolhida como antes")


## O relatório da volta e o Próximo passo dizem quem chegou (ou que o trem veio vazio).
func _report_and_next_step() -> void:
	var c := _campaign()
	var arrived := ""
	var empty := ""
	for i in 200:
		var probe: Dictionary = c.duplicate(true)
		var delivered := _return(probe, "report-%d" % i)
		if String(delivered.get("train", "")) != "" and arrived == "":
			arrived = "report-%d" % i
		elif delivered.has("train") and String(delivered.train) == "" and empty == "":
			empty = "report-%d" % i
		if arrived != "" and empty != "":
			break
	if not t.check(arrived != "" and empty != "", "acha uma volta com alguém e uma vazia"):
		return
	var full: Dictionary = c.duplicate(true)
	var delivered := _return(full, arrived)
	t.equal(String(delivered.train), S.train_candidate_name(full), "o relatório diz quem chegou")
	full.station.last_return.seen = true
	t.equal(S.next_step(full).title, "Chegou alguém no trem", "e o Próximo passo também")
	var none: Dictionary = c.duplicate(true)
	t.equal(String(_return(none, empty).train), "", "na volta vazia, ninguém")


## As telas: a Sala sem + RECRUTAR (com o caminho até a plataforma), o painel do trem com o animal e o relatório.
func _screens() -> void:
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-train-recruits-%d" % Time.get_ticks_usec()
	var c := _campaign()
	c.inventory.seeds = 30
	S.train_on_return(c, "screens", "hero")
	c.station.last_return = {}
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
		# Durante a chegada do trem, a equipe não sobe para a plataforma (quem desce cairia no meio da fila).
		await _frames(2)
		hud._on_phase_chosen("fase_1")
		await _frames(1)
		t.check(station.train_busy() and hud.current != "departure", "com o trem chegando, a partida espera")
		# A chegada do trem toca sozinha (a volta com alguém): o painel abre depois da cena.
		var end := Time.get_ticks_msec() + 30000
		while (station.train_busy() or not hud._panel.visible) and Time.get_ticks_msec() < end:
			await _tree.process_frame
		var name: String = c.station.train.recruit.display_name
		t.check(hud.current == "train" and _label(hud._panel, name) and _label(hud._panel, String(c.station.train.recruit.origin)), "o painel do trem mostra o animal e de onde veio")
		t.check(_label(hud._panel, "Pedido"), "e o que ele pede")
		var accept := hud._footer.find_children("*", "Button", true, false).filter(func(b): return (b as Button).text.to_lower().begins_with("acolher"))
		t.check(not accept.is_empty() and not accept[0].disabled, "Acolher liberado")
		t.check(station._candidate != null and station._candidate.visible, "e ele de pé na plataforma")
		hud.open_room(S.CHARACTERS)
		await _frames(4)
		var room: Control = hud._room_screen
		var buy := room.find_children("*", "Button", true, false).filter(func(b): return (b as Button).text.contains("sementes") or (b as Button).text.contains("voluntário"))
		t.check(buy.is_empty() and room.find_child("Tab_recruit", true, false) == null, "a Sala não tem mais o + RECRUTAR")
		var to_train: Button = room.find_child("ToTrain", true, false)
		t.check(to_train != null and to_train.text.to_lower().contains(String(c.station.train.recruit.display_name).to_lower()), "e leva até quem espera na plataforma")
		# Sem ninguém vivo no elenco (um save antigo, de antes da #118), a Sala abre sem herói, com o aviso.
		var alive_before: Array = Campaign.state.roster.map(func(h): return h.alive)
		for entry in Campaign.state.roster:
			entry.alive = false
		room.rebuild()
		await _frames(2)
		t.check(room.find_child("EmptyRoster", true, false) != null and room.find_child("Right", true, false) == null, "sem ninguém vivo, a Sala abre com o aviso e sem o painel do herói")
		for i in alive_before.size():
			Campaign.state.roster[i].alive = alive_before[i]
		room.rebuild()
		await _frames(2)
		hud.close_panel()
		await _frames(2)
		t.check(is_instance_valid(station._candidate) and station._candidate.visible, "na vista geral, ele espera na plataforma")
		hud._briefed = "fase_1"
		hud.open_map()
		hud._on_phase_chosen("fase_1")
		await _frames(2)
		t.check(hud.current == "departure" and not is_instance_valid(station._candidate), "na partida, ele sai da fila")
		hud.back_to_map()
		hud._map.closed.emit()
		await _frames(2)
		t.check(is_instance_valid(station._candidate), "de volta à vista geral, ele volta para a plataforma")
		# Sem sementes, Acolher trava sem a tecla, e a tecla de Acolher (E, Enter, A) não recusa pelo foco.
		Campaign.state.inventory.seeds = 3
		hud.open_service("train")
		end = Time.get_ticks_msec() + 30000
		while (station.train_busy() or not hud._panel.visible) and Time.get_ticks_msec() < end:
			await _tree.process_frame
		await _frames(2)
		var locked := hud._footer.find_children("*", "Button", true, false).filter(func(b): return (b as Button).text.to_lower().begins_with("acolher"))
		t.check(not locked.is_empty() and locked[0].disabled and not locked[0].get_node("Key").visible, "sem sementes, Acolher trava sem a tecla")
		t.check(_label(hud._panel, "Faltam sementes"), "com o motivo à vista")
		for action in ["ui_down", "interact", "ui_accept"]:
			_send(action)
			await _frames(3)
		t.equal(Campaign.state.station.train.phase, "waiting", "as teclas não mandam embora quem espera")
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


func _send(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func _label(root: Node, part: String) -> bool:
	return root.find_children("*", "Label", true, false).any(func(l): return (l as Label).text.contains(part))


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
