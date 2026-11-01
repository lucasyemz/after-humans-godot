## O trem que não trava e não repete (#182): nenhum personagem repetido (o trem e o recrutamento só trazem um rosto
## que não está no elenco; sem rosto livre, não vem animal), a casa cheia não traz animal, e às vezes descem dois
## (decididos na ordem que o jogador quiser; os dois vão embora juntos na partida). O save guarda o segundo, e o save
## antigo abre.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_never_repeats()
	_pairs()
	_pair_decisions()
	_saves()
	await _screens()


func _campaign(seed_value: int = 182) -> Dictionary:
	var c: Dictionary = Campaign.create_initial(seed_value)
	# O Alojamento no nível 4 (12 heróis): a casa nunca enche neste teste, só os rostos acabam.
	c.station.rooms[S.CHARACTERS] = 4
	c.inventory.seeds = 500
	return c


## Acolhendo tudo o que o trem traz: cada rosto chega uma vez; acabados os rostos, não vem mais animal.
func _never_repeats() -> void:
	var c := _campaign()
	var faces: Array = []
	var repeated := false
	for i in 80:
		if not S.train_on_return(c, "unique-%d" % i, "hero"):
			continue
		while c.station.train.phase == "waiting":
			var recruit := S.train_recruit(c)
			if not recruit.is_empty():
				var face := String(recruit.art_variant)
				repeated = repeated or faces.has(face) or c.roster.any(func(h): return String(h.get("art_variant", "")) == face)
				faces.append(face)
			S.decide_candidate(c, c.station.train.candidate_id, true)
		S.finish_departure(c)
	var all_faces: Array = []
	for class_id in S.train_classes(Campaign.create_initial(1)):
		all_faces.append_array(S.art_variants(class_id))
	t.check(not repeated, "o trem nunca trouxe um rosto que já estava no elenco (%d rostos)" % faces.size())
	faces.sort()
	all_faces.sort()
	t.equal(faces, all_faces, "e trouxe cada rosto de recruta uma vez")
	t.check(S.train_classes(c).is_empty(), "sem rosto livre, nenhuma classe vem no trem")
	var arrived := S.train_on_return(c, "after-faces", "hero")
	t.check(S.train_recruit(c).is_empty(), "e o trem não traz animal (%s)" % ("o civil" if arrived else "ninguém"))
	# O recrutamento (a barra de Admin, os voluntários) segue a mesma regra.
	t.check(S.recruit(c, "cao", RandomNumberGenerator.new(), "Outro").error != "", "o recrutamento também não repete")
	c.pending_offers.append({"class_id": "cao", "display_name": "Voluntário"})
	t.equal(S.receive_volunteers(c, RandomNumberGenerator.new()), 0, "o voluntário sem rosto livre não chega")
	t.equal(c.pending_offers.size(), 1, "e espera a vez, sem se perder")
	# Quem foi recusado libera o rosto: ele pode voltar mais tarde, com outro nome (é outra pessoa).
	var d := _campaign(183)
	S.train_on_return(d, "refused", "hero")
	var face := String(S.train_recruit(d).art_variant)
	var face_class := String(S.train_recruit(d).class_id)
	t.check(not S.free_art_variants(d, face_class).has(face), "o rosto de quem espera fica reservado")
	while d.station.train.phase == "waiting":
		S.decide_candidate(d, d.station.train.candidate_id, false)
	S.finish_departure(d)
	t.check(S.free_art_variants(d, face_class).has(face), "recusado, o rosto fica livre de novo")


## Às vezes descem dois (data/recruitment.json, SingleWeight e PairWeight): rostos e nomes diferentes, fora do elenco;
## só com lugar para os dois.
func _pairs() -> void:
	var pairs := 0
	var arrivals := 0
	var bad := false
	for i in 200:
		var c := _campaign(1820 + i)
		if not S.train_on_return(c, "pair-%d" % i, "hero") or S.train_recruit(c).is_empty():
			continue
		arrivals += 1
		var second: Dictionary = c.station.train.next
		if second.is_empty():
			continue
		pairs += 1
		var first: Dictionary = c.station.train.recruit
		bad = bad or second.recruit.art_variant == first.art_variant or second.recruit.display_name == first.display_name \
			or second.candidate_id == c.station.train.candidate_id
	var single := S.train_rule("train", "SingleWeight", 60)
	var pair := S.train_rule("train", "PairWeight", 0)
	var expected := 100.0 * pair / float(single + pair)
	var got := 100.0 * pairs / maxf(1.0, arrivals)
	t.check(pairs > 0 and absf(got - expected) < 10.0, "às vezes descem dois: %.0f%% das chegadas (a tabela: %.0f%%)" % [got, expected])
	t.check(not bad, "com rostos, nomes e ids diferentes")
	# Sem lugar para os dois, desce um só.
	var full_pairs := 0
	for i in 100:
		var c := _campaign(1840 + i)
		c.station.rooms[S.CHARACTERS] = 1
		S._add_hero(c, S._next_hero_id(c, "rato"), "rato", "Ocupa", [], "")
		if S.train_on_return(c, "tight-%d" % i, "hero") and not c.station.train.next.is_empty():
			full_pairs += 1
	t.equal(full_pairs, 0, "com um lugar só no Alojamento, nunca descem dois")


## Os dois decididos um de cada vez; a partida leva os dois que ninguém decidiu.
func _pair_decisions() -> void:
	var c := _pair_campaign()
	if not t.check(not c.is_empty(), "achou uma chegada com dois"):
		return
	var first_id: String = c.station.train.candidate_id
	var second_id: String = c.station.train.next.candidate_id
	t.equal(S.decide_candidate(c, first_id, true), "", "acolhe o primeiro")
	t.check(S.hero(c, first_id) != null and c.station.train.phase == "waiting" and c.station.train.candidate_id == second_id,
		"e o segundo passa a esperar (o trem ainda não parte)")
	t.equal(S.decide_candidate(c, second_id, false), "", "recusa o segundo")
	t.check(S.hero(c, second_id) == null and c.station.train.phase == "departing", "aí o trem parte")
	# Na ordem que o jogador quiser (a decisão do Lucas): o segundo decidido antes do primeiro.
	var f := _pair_campaign()
	var f_first: String = f.station.train.candidate_id
	var f_second: String = f.station.train.next.candidate_id
	t.equal(S.decide_candidate(f, f_second, true), "", "acolhe o segundo antes do primeiro")
	t.check(S.hero(f, f_second) != null and S.hero(f, f_first) == null and f.station.train.phase == "waiting"
		and f.station.train.candidate_id == f_first and f.station.train.next.is_empty(), "e o primeiro continua esperando")
	t.equal(S.decide_candidate(f, f_first, true), "", "depois o primeiro")
	t.check(S.hero(f, f_first) != null and f.station.train.phase == "departing", "aí o trem parte, com os dois acolhidos")
	# Sem sementes para o segundo: a decisão barrada deixa os dois na ordem de antes (só decide_candidate desfaz).
	var poor := _pair_campaign()
	var poor_first: String = poor.station.train.candidate_id
	var poor_second: String = poor.station.train.next.candidate_id
	poor.inventory.seeds = 0
	poor.station.rooms[S.CHARACTERS] = 4
	var asks: Dictionary = poor.station.train.next.get("recruit", {})
	if t.check(not asks.is_empty() and S.recruit_price(poor, String(asks.class_id)) > 0, "o segundo é um animal que pede sementes"):
		t.check(S.decide_candidate(poor, poor_second, true) != "", "sem sementes, o segundo não entra")
		t.check(poor.station.train.candidate_id == poor_first and poor.station.train.next.candidate_id == poor_second
			and S.hero(poor, poor_second) == null, "e os dois ficam na ordem de antes")
	var g := _pair_campaign()
	var g_first: String = g.station.train.candidate_id
	t.check(S.bring_forward(g, g.station.train.next.candidate_id) and g.station.train.next.candidate_id == g_first,
		"trazer o segundo à frente troca os dois de lugar")
	t.check(not S.bring_forward(g, g.station.train.candidate_id) and not S.bring_forward(g, "hero_ninguem_9"),
		"quem já está à frente, ou não está no trem, não troca nada")
	# O id reservado dos dois: a barra de Admin recrutando a mesma classe no meio não o toma.
	var h := _pair_campaign()
	var h_ids := [String(h.station.train.candidate_id), String(h.station.train.next.candidate_id)]
	var taken_ids: Array = []
	for recruit in [h.station.train.recruit, h.station.train.next.recruit]:
		h.station.rooms[S.CHARACTERS] = 4
		var extra := S._next_hero_id(h, String(recruit.class_id))
		taken_ids.append(extra)
	t.check(not taken_ids.any(func(id): return h_ids.has(id)), "o próximo id livre pula os ids de quem espera no trem")
	S.decide_candidate(h, h_ids[1], true)
	S.decide_candidate(h, h_ids[0], true)
	t.check(S.hero(h, h_ids[0]) != null and S.hero(h, h_ids[1]) != null, "e os dois entram com o id reservado")
	# Os dois têm o rosto e o nome reservados: o recrutamento (a barra de Admin) não repete o segundo.
	var e := _pair_campaign()
	var second: Dictionary = e.station.train.next.recruit
	t.check(not S.free_art_variants(e, second.class_id).has(second.art_variant), "o rosto do segundo fica reservado")
	var hired := S.recruit(e, second.class_id, RandomNumberGenerator.new())
	var hired_hero = S.hero(e, String(hired.get("hero_id", "")))
	t.check(hired.error != "" or (hired_hero.art_variant != second.art_variant and hired_hero.display_name != second.display_name),
		"recrutar a classe do segundo não repete o rosto nem o nome")
	# O aviso, o Próximo passo e o relatório dizem os dois (os dois vão embora se a equipe partir).
	var names := S.train_waiting_names(e)
	t.check(names.size() == 2 and S.train_candidate_name(e).contains(names[0]) and S.train_candidate_name(e).contains(names[1]),
		"o nome de quem espera junta os dois (%s)" % S.train_candidate_name(e))
	t.check(S.next_step(e).text.contains("esperam"), "o Próximo passo fala dos dois")
	# Um trem inconsistente (sem candidato, num save velho) não trava a partida.
	var broken := _campaign(1999)
	broken.station.train.phase = "waiting"
	broken.station.train.candidate_id = ""
	S.train_leaves(broken)
	t.equal(broken.station.train.phase, "none", "o trem sem candidato não trava a partida")
	var d := _pair_campaign()
	var ids := [d.station.train.candidate_id, d.station.train.next.candidate_id]
	S.train_leaves(d)
	t.check(ids.all(func(id): return S.hero(d, id) == null) and d.station.train.phase == "none" and d.station.train.next.is_empty(),
		"sem decisão, os dois vão embora juntos na partida")


func _pair_campaign() -> Dictionary:
	for i in 200:
		var c := _campaign(1900 + i)
		if S.train_on_return(c, "two-%d" % i, "hero") and not c.station.train.next.is_empty():
			return c
	return {}


## O save guarda o segundo; o save de antes do #182 (sem o campo) abre com o trem de um só.
func _saves() -> void:
	var c := _pair_campaign()
	if c.is_empty():
		return
	var reopened = Campaign._normalize(JSON.parse_string(JSON.stringify(c)))
	S.migrate(reopened)
	t.equal(reopened.station.train.next.candidate_id, c.station.train.next.candidate_id, "o save guarda quem desceu junto")
	var old: Dictionary = c.duplicate(true)
	old.station.train.erase("next")
	S.migrate(old)
	t.check(typeof(old.station.train.get("next")) == TYPE_DICTIONARY and old.station.train.next.is_empty(), "o save antigo abre com um só")


## Na tela: o painel tem os dois à escolha, o segundo está de pé na plataforma, a aba dele o traz à frente, e decidido
## um, o painel mostra o outro (o trem não parte).
func _screens() -> void:
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-train-unique-%d" % Time.get_ticks_usec()
	var c := _pair_campaign()
	if c.is_empty():
		return
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
		hud.open_service("train")
		var end := Time.get_ticks_msec() + 40000
		while (station.train_busy() or not hud._panel.visible) and Time.get_ticks_msec() < end:
			await _tree.process_frame
		await _frames(3)
		var first_id: String = c.station.train.candidate_id
		var second_id: String = c.station.train.next.candidate_id
		var first_name: String = c.station.train.recruit.display_name
		var second_name: String = c.station.train.next.recruit.display_name
		var pair: Node = hud._panel.find_child("TrainPair", true, false)
		t.check(pair != null and pair.get_child_count() == 2 and _label(pair, first_name) and _label(pair, second_name),
			"o painel tem os dois à escolha (%s e %s)" % [first_name, second_name])
		t.check(is_instance_valid(station._companion) and station._companion.visible, "e o segundo está de pé na plataforma")
		# A aba do segundo o traz à frente: o painel passa a ser dele, e na plataforma ninguém sai do lugar.
		var spots := [station._candidate.position, station._companion.position]
		var order_before: Array = pair.get_children().map(func(n): return String(n.name)) if pair else []
		var tab: Button = pair.find_child("Pair_%s" % second_id, false, false) if pair else null
		if t.check(tab != null, "a aba do segundo"):
			tab.pressed.emit()
		await _frames(4)
		t.check(Campaign.state.station.train.candidate_id == second_id and station._candidate_id == second_id
			and _label(hud._panel, tr_line(second_name)),
			"a aba traz o segundo à frente, no painel e na cena")
		t.check(station._candidate.position == spots[1] and station._companion.position == spots[0], "cada um continua no lugar dele")
		var pair_now: Node = hud._panel.find_child("TrainPair", true, false)
		t.equal(pair_now.get_children().map(func(n): return String(n.name)) if pair_now else [], order_before,
			"as abas não trocam de lugar (seguem a plataforma)")
		# Fechar e reabrir o trem depois da troca: os dois continuam onde estavam, sem a chegada de novo.
		hud.close_panel()
		await _frames(6)
		hud.open_service("train")
		t.check(not station._pending_arrival, "reabrir o trem depois da troca não chama a chegada de novo")
		var settle := Time.get_ticks_msec() + 20000
		while station.train_busy() and Time.get_ticks_msec() < settle:
			await _tree.process_frame
		await _frames(4)
		t.check(not station.train_busy() and is_instance_valid(station._candidate) and is_instance_valid(station._companion)
			and station._candidate_id == second_id, "e os dois continuam na plataforma, com o escolhido à frente")
		# Acolher travado (sem sementes) no outro: a ordem e a cena ficam como estavam.
		Campaign.state.inventory.seeds = 0
		hud._decide(first_id, true)
		await _frames(3)
		t.check(Campaign.state.station.train.candidate_id == second_id and station._candidate_id == second_id
			and Campaign.state.station.train.next.get("candidate_id", "") == first_id, "a decisão barrada não troca ninguém de lugar")
		Campaign.state.inventory.seeds = 500
		hud.refresh()
		await _frames(3)
		# No Maior, com Acolher travado, o pedido e o motivo ficam à vista sem rolar.
		var size_before: int = Settings.text_size
		Settings.set_text_size(2)
		Campaign.state.inventory.seeds = 3
		hud.refresh()
		await _frames(6)
		var view: Rect2 = hud._scroll.get_global_rect()
		var reason: Array = hud._panel.find_children("*", "Label", true, false).filter(func(l): return (l as Label).text.contains("Faltam sementes"))
		t.check(not reason.is_empty() and view.encloses(reason[0].get_global_rect()), "no Maior, o motivo do Acolher travado fica à vista com dois")
		Settings.set_text_size(size_before)
		Campaign.state.inventory.seeds = 500
		hud.refresh()
		await _frames(4)
		hud._decide(second_id, false)
		await _frames(6)
		t.check(Campaign.state.station.train.phase == "waiting" and Campaign.state.station.train.candidate_id == first_id
			and _label(hud._panel, first_name) and hud._panel.find_child("TrainPair", true, false) == null,
			"recusado o segundo, o painel mostra o primeiro, sozinho")
		t.check(station._candidate_id == Campaign.state.station.train.candidate_id and not is_instance_valid(station._companion),
			"e ele é quem espera na plataforma")
		var promoted: AHSpriteCard = station._candidate
		end = Time.get_ticks_msec() + 15000
		while is_instance_valid(promoted) and absf(promoted.position.x - station._departure_slot(1).x) > 0.06 and Time.get_ticks_msec() < end:
			await _tree.process_frame
		t.check(is_instance_valid(promoted) and absf(promoted.position.x - station._departure_slot(1).x) <= 0.06, "e fica no lugar de quem espera")
		# Decidido o outro logo em seguida, com o recusado ainda voltando ao vagão: as portas só fecham depois que ele
		# entra.
		t.check(station.boarding_back(), "o recusado ainda volta ao vagão")
		hud._decide(Campaign.state.station.train.candidate_id, true)
		# Na espera, o trem conta como ocupado: a Preparação não abre com ele partindo atrás da fila.
		await _frames(2)
		t.check(station.train_busy(), "enquanto o recusado volta ao vagão, o trem conta como ocupado")
		hud._on_phase_chosen("fase_1")
		await _frames(2)
		t.check(hud.current != "departure", "e a Preparação não abre durante a partida")
		var closed_early := false
		end = Time.get_ticks_msec() + 20000
		while Campaign.state.station.train.phase != "none" and Time.get_ticks_msec() < end:
			closed_early = closed_early or (station._train_mode == 2 and station.boarding_back())
			await _tree.process_frame
		t.check(not closed_early and not station.boarding_back(), "o trem só fecha as portas depois que o recusado entra")
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


## O título do painel de um animal do trem.
func tr_line(name: String) -> String:
	return TranslationServer.translate("%s quer entrar na Estação") % name


func _label(node: Node, text: String) -> bool:
	for label in node.find_children("*", "Label", true, false):
		if (label as Label).text.contains(text):
			return true
	return false


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
