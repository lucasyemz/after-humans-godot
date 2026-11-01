## A Estação viva (#207): as falas e os pensamentos (data/station-chatter.json), o balão do kit, o balão interativo com a
## tirinha no Próximo passo e quem troca de cômodo pelas portas.
## - os dados: cada entrada com quem fala, as falas, as condições e o cômodo válidos; a tirinha da conversa existe;
## - a fala respeita as condições, o texto não volta antes de 10 min e o mesmo morador não abre duas seguidas;
## - a conversa só junta quem está no mesmo cômodo; quem dorme ou trabalha só pensa; o caído nem pensa;
## - o balão: a fala com a ponta, o pensamento com as bolinhas, o interativo apertável (e o foco do teclado);
## - quem anda chega ao cômodo certo, abre as duas portas e não atravessa parede (some entre as portas);
## - ninguém sai da tela de foco (a Sala dos Personagens), e nada de balão com uma tela por cima ou com as falas
##   desligadas;
## - o Próximo passo leva à conversa, o balão abre a tirinha, e lida até o fim ela sai dos objetivos.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const C = preload("res://scripts/flow/station_chatter.gd")

var t
var tree: SceneTree


func run(context) -> void:
	t = context
	tree = Engine.get_main_loop()
	_data()
	_rules()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-station-life-%d" % Time.get_ticks_usec()
	Campaign.state = _campaign()
	var station = await _open()
	t.check(station != null and station.life != null, "a Estação abriu com a vida dela")
	if station != null:
		station.life.auto = false
		await _bubbles(station)
		await _walk(station)
		await _focus_screen(station)
		await _story(station)
	tree.unload_current_scene()
	await tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state
	Tips.enabled = tips


## Uma campanha depois da primeira volta, com a planta herdada (todos os cômodos recuperados nas vagas) e o relatório
## já visto: a Estação abre na vista geral, sem visita guiada.
func _campaign() -> Dictionary:
	var c: Dictionary = Campaign.create_initial(207)
	for room in S.ROOMS:
		c.station.rooms[room.id] = 1
	c.station.erase("grid")
	AHStationGrid.migrate(c)
	c.station.cycle_number = 1
	c.station.last_return = {}
	return c


func _data() -> void:
	var rows := C.entries()
	t.check(rows.size() >= 32, "os 32 textos aprovados e a conversa da tirinha estão na tabela (%d)" % rows.size())
	var known := {}
	for entry in Campaign.create_initial(1).roster:
		known[entry.id] = true
	for civilian in S.CIVILIANS:
		known[civilian.id] = true
	var tokens := ["founder", "recruit", "recruit_new", "any"]
	var rooms: Array = S.ROOMS.map(func(r): return r.id)
	var bad: Array = []
	var comics := 0
	for row in rows:
		if not ["say", "think"].has(String(row.get("Kind", ""))):
			bad.append("%s: Kind" % row.Name)
		for who in row.Speakers:
			if not known.has(who) and not tokens.has(who):
				bad.append("%s: %s" % [row.Name, who])
		if row.Lines.is_empty() or row.Lines.size() > 3:
			bad.append("%s: de 1 a 3 falas" % row.Name)
		for line in row.Lines:
			if int(line.Who) < 0 or int(line.Who) >= row.Speakers.size() or String(line.Text).strip_edges() == "":
				bad.append("%s: fala sem quem diz" % row.Name)
			if String(line.get("Comic", "")) != "":
				comics += 1
				if C.comic(line.Comic).is_empty() or C.comic(line.Comic).get("Panels", []).is_empty():
					bad.append("%s: a tirinha %s não existe" % [row.Name, line.Comic])
		for condition in row.When:
			if not C.CONDITIONS.has(condition):
				bad.append("%s: condição %s" % [row.Name, condition])
		if String(row.Room) != "" and not rooms.has(row.Room):
			bad.append("%s: cômodo %s" % [row.Name, row.Room])
		if float(row.Weight) <= 0.0:
			bad.append("%s: peso" % row.Name)
	t.equal(bad, [], "toda entrada tem tipo, quem fala, as falas, as condições e o cômodo válidos")
	t.equal(comics, 1, "uma fala abre a tirinha (o balão interativo)")
	var story := C.entry("bento_brother")
	t.equal(story.get("Speakers", []), [C.BENTO, C.NICK], "a conversa da tirinha é do Bento com o Nick")
	t.equal(String(story.Lines[-1].get("Comic", "")), "bento_brother", "e o balão interativo é a última fala, a do Bento")
	t.equal(C.line_seconds("Oi."), 2.5 + 0.045 * 3, "o balão fica 2,5 s mais 45 ms por letra")
	t.equal(C.line_seconds("x".repeat(200)), 6.0, "até 6 s")


func _rules() -> void:
	var c: Dictionary = _campaign()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Ninguém caído, sem noite, sem trem: só valem as entradas sem condição (ou com as que a campanha tem).
	var now := C.conditions(c)
	t.check(not now.get("fallen", false) and not now.get("night", false) and not now.get("train_waiting", false),
		"campanha calma: nem caído, nem noite, nem trem")
	var everyone := {}
	for id in [C.BENTO, C.NICK, "hero_sapo_iris", "hero_coruja_vespera", S.DORA, S.OTTO, S.CORA]:
		everyone[id] = {"room": S.FORGE, "say": true, "think": true}
	var picked := {}
	for i in 300:
		var chosen := C.pick(c, everyone, {}, "", 0, rng)
		if not chosen.is_empty():
			picked[chosen.row.Name] = true
			for condition in chosen.row.When:
				t.check(now.get(condition, false), "a fala %s só sai com %s" % [chosen.row.Name, condition])
	t.check(not picked.has("fallen_bento") and not picked.has("night_vespera") and not picked.has("train_dora"),
		"sem caído, noite ou trem, as falas deles não saem")
	t.check(picked.has("forge_otto") or picked.has("forge_bento"), "na Forja, as falas da Forja saem")
	t.check(not picked.has("canteen_dora"), "a da Cantina não sai na Forja")
	# Com alguém caído, a fala do caído sai, com o nome dele e nunca na boca dele.
	var iris = S.hero(c, "hero_sapo_iris")
	iris.recovery_days = 2
	now = C.conditions(c)
	t.check(now.get("fallen", false), "a Íris em recuperação conta como caída")
	var bento_room := {C.BENTO: {"room": S.FORGE, "say": true, "think": true}}
	var hit := {}
	for i in 200:
		var chosen := C.pick(c, bento_room, {}, "", 0, rng)
		if not chosen.is_empty() and chosen.row.Name == "fallen_bento":
			hit = chosen
	t.equal(String(hit.get("name", "")), "Íris", "o Bento pensa no caído pelo nome")
	t.equal(C.line_text(C.entry("fallen_bento").Lines[0], "Íris"), "Devia ter sido eu no lugar de Íris.", "e o {nome} vira o nome")
	iris.recovery_days = 0
	# A conversa só junta quem está no mesmo cômodo.
	var apart := {C.BENTO: {"room": S.FORGE, "say": true, "think": true}, C.NICK: {"room": S.BAR, "say": true, "think": true}}
	t.equal(C.cast(C.entry("always_nick_bento_methods"), apart, c), [], "Bento na Forja e Nick no Bar não conversam")
	apart[C.NICK].room = S.FORGE
	t.equal(C.cast(C.entry("always_nick_bento_methods"), apart, c), [C.NICK, C.BENTO], "no mesmo cômodo, conversam")
	# Quem dorme ou trabalha só pensa.
	var asleep := {C.NICK: {"room": S.DORMITORY, "say": false, "think": true}}
	t.check(not C.open(C.entry("night_nick"), C.conditions(c), {}, 0), "o pensamento da noite pede a noite (ainda não)")
	t.equal(C.cast(C.entry("always_nick_backpack"), asleep, c), [C.NICK], "quem dorme pensa")
	t.equal(C.cast(C.entry("always_bento_nick_backpack"), {C.BENTO: {"room": S.BAR, "say": false, "think": true},
		C.NICK: {"room": S.BAR, "say": true, "think": true}}, c), [], "quem trabalha na pose não conversa")
	# O cômodo da entrada é o de quem fala primeiro.
	t.equal(C.cast(C.entry("bar_nick"), {C.NICK: {"room": S.FORGE, "say": true, "think": true}}, c), [], "o pensamento do Bar só no Bar")
	# O mesmo texto não volta antes de 10 minutos; o mesmo morador não abre duas seguidas.
	var history := {"always_nick_backpack": 1000}
	t.check(not C.open(C.entry("always_nick_backpack"), {}, history, 1000 + C.REPEAT_MS - 1), "o texto não volta antes de 10 min")
	t.check(C.open(C.entry("always_nick_backpack"), {}, history, 1000 + C.REPEAT_MS), "depois de 10 min, volta")
	t.equal(C.cast(C.entry("always_nick_backpack"), asleep, c, C.NICK), [], "quem falou por último não abre a próxima")
	# As condições que a campanha tem: a noite, o trem, a fome.
	c.night.phase = "planning"
	t.check(C.conditions(c).get("night", false), "a noite pendente conta")
	c.night.phase = "none"
	S.adjust(c, S.SUPPLIES, -S.quantity(c, S.SUPPLIES))
	t.check(C.conditions(c).get("food_low", false), "sem suprimentos, a fome conta")
	# O Próximo passo da tirinha: depois da primeira volta, com o Bento e o Nick de pé; caído um deles, não.
	var fresh: Dictionary = Campaign.create_initial(3)
	t.equal(C.story_pending(fresh), "", "na campanha nova (sem volta), a tirinha não espera")
	var after := _campaign()
	t.equal(C.story_pending(after), "bento_brother", "depois da primeira volta, a tirinha espera no Próximo passo")
	t.equal(String(S.next_step(after).get("action", "")), "story", "o Próximo passo leva à conversa")
	S.hero(after, C.NICK).recovery_days = 1
	t.equal(C.story_pending(after), "", "com o Nick caído, não")
	S.hero(after, C.NICK).recovery_days = 0
	after.night.phase = "planning"
	t.equal(String(S.next_step(after).get("action", "")), "dormitory", "a noite vem antes")
	after.night.phase = "none"
	t.check(C.mark_seen(after, "bento_brother") and not C.mark_seen(after, "bento_brother"), "vista uma vez só")
	t.check(String(S.next_step(after).get("action", "")) != "story", "vista, a tirinha sai do Próximo passo")
	# Antes de liberada (nenhuma volta), a conversa da tirinha nem sai no sorteio (QA da #207).
	var early := _campaign()
	early.station.cycle_number = 0
	var pair := {C.BENTO: {"room": S.BAR, "say": true, "think": true}, C.NICK: {"room": S.BAR, "say": true, "think": true}}
	var early_hits := 0
	for i in 400:
		if String(C.pick(early, pair, {}, "", 0, rng).get("row", {}).get("Name", "")) == "bento_brother":
			early_hits += 1
	t.equal(early_hits, 0, "antes da primeira volta, o balão interativo não sai no sorteio")
	# O save antigo ganha a lista vazia (migrate).
	var old := _campaign()
	old.station.erase("comics_seen")
	S.migrate(old)
	t.equal(old.station.get("comics_seen"), [], "o save antigo ganha a lista das tirinhas vistas")


func _open():
	GameFlow.change_to("station", {}, false)
	for frame in 300:
		await tree.process_frame
		var scene := tree.current_scene
		if not GameFlow.busy and scene is AHStation and scene.hud != null:
			for i in 30:
				await tree.process_frame
			return scene
	return null


func _settle(station) -> void:
	for frame in 240:
		await tree.process_frame
		if station.camera_settled():
			break
	await tree.process_frame


func _walker(station, id: String):
	for walker in station.walkers():
		if String(walker.get("hero_id", "")) == id:
			return walker
	return null


func _bubbles(station) -> void:
	var life: AHStationLife = station.life
	var hud: AHRefugeHud = station.hud
	t.check(hud.life_allowed(), "na vista geral, os balões valem")
	# O balão do kit: a fala com a ponta, o pensamento com as bolinhas e sem a ponta, o interativo apertável.
	var say := AHKitBubble.make(AHKitBubble.SAY, "Mede duas vezes, solda uma.")
	var think := AHKitBubble.make(AHKitBubble.THINK, "Mochila pronta. Só por precaução.")
	var story := AHKitBubble.make(AHKitBubble.STORY, "E foi assim que perdi meu irmão…")
	for bubble in [say, think, story]:
		hud.bubbles.add_child(bubble)
	await tree.process_frame
	t.check(say.get_node_or_null("Tip") != null and think.get_node_or_null("Tip") == null, "a fala tem a ponta; o pensamento, não")
	t.check(say.size.x > 60 and say.size.x <= AHUiStyle.px(AHKitBubble.WIDTH) + 40, "o balão tem a largura do texto (%s)" % say.size)
	var label: Label = think.get_node("Frame/Text")
	var italic = label.get_theme_font("font")
	t.check(italic is FontVariation and italic.variation_transform.x.y > 0.1 and is_equal_approx(italic.variation_transform.y.x, 0.0)
		and label.get_theme_color("font_color") == AHKit.MUTED, "o pensamento em itálico (inclinado) e mais apagado")
	var rich: RichTextLabel = story.get_node("Frame/Text")
	t.check(rich.text.begins_with("[u]") and rich.get_theme_color("default_color") == AHKit.AMBER and rich.get_theme_font("normal_font") == AHKit.font(true),
		"o interativo em negrito, sublinhado e no âmbar")
	var opened := [0]
	story.opened.connect(func(): opened[0] += 1)
	var button: Button = story.get_node("Open")
	button.pressed.emit()
	t.equal(opened[0], 1, "apertar o balão interativo abre")
	t.check(button.focus_mode == Control.FOCUS_ALL, "o interativo pega o foco do teclado e do controle")
	say.place(Vector2(960, 500), Rect2(0, 0, 1920, 1080))
	t.check(absf(say.position.x + say.size.x * 0.5 - 960) <= 1.0 and absf(say.position.y + say.size.y - 500) <= 1.0, "a ponta cai na cabeça")
	say.place(Vector2(5, 500), Rect2(400, 130, 1000, 800))
	t.check(say.position.x >= 400, "o balão não entra embaixo da coluna da esquerda")
	for bubble in [say, think, story]:
		bubble.queue_free()
	# Um balão por vez: a conversa ocupa o lugar até acabar. Com todos à vista no mesmo cômodo, sai um.
	var bento = _walker(station, C.BENTO)
	var nick = _walker(station, C.NICK)
	t.check(bento != null and nick != null, "o Bento e o Nick estão na Estação")
	if bento == null or nick == null:
		return
	station.settle_in(bento, S.BAR)
	station.settle_in(nick, S.BAR)
	await tree.process_frame
	var present := life.present()
	t.check(present.has(C.BENTO) and present.has(C.NICK), "os dois à vista no Bar contam como presentes")
	life.start_talk({"row": C.entry("always_nick_bento_methods"), "ids": [C.NICK, C.BENTO], "name": ""})
	await tree.process_frame
	t.check(life.bubble != null and hud.bubbles.get_child_count() >= 1, "a conversa mostra o balão")
	t.equal(String(life.bubble.get_meta("speaker", "")), C.NICK, "quem fala primeiro é o Nick")
	var count := 0
	for child in hud.bubbles.get_children():
		if child is AHKitBubble and not child.is_queued_for_deletion():
			count += 1
	t.equal(count, 1, "um balão por vez")
	life._tick_line(10.0)
	t.check(life.bubble == null and not life.talk.is_empty(), "a fala acaba e a próxima espera a folga")
	life._tick_line(C.LINE_GAP + 0.01)
	t.equal(String(life.bubble.get_meta("speaker", "")) if life.bubble != null else "", C.BENTO, "e o Bento responde")
	# Com uma tela por cima (o Plano), a conversa acaba.
	hud.open_service("plan")
	await tree.process_frame
	t.check(not hud.life_allowed(), "com o Plano aberto, os balões não valem")
	life._tick_talk(0.1)
	t.check(life.bubble == null and life.talk.is_empty(), "e a conversa acaba")
	hud.close_panel()
	await _settle(station)
	# Com as falas desligadas nas Opções, nada.
	Campaign.state.settings.station_chatter = false
	life.auto = true
	life._chat_left = 0.0
	life._tick_talk(0.1)
	t.check(life.talk.is_empty(), "com as falas desligadas, nenhum balão")
	Campaign.state.settings.station_chatter = true
	life._chat_left = 0.0
	life._tick_talk(0.1)
	t.check(not life.talk.is_empty(), "ligadas, o sorteio mostra uma fala")
	life.auto = false
	life.stop_talk()


func _walk(station) -> void:
	var life: AHStationLife = station.life
	var walker = _walker(station, "hero_sapo_iris")
	if walker == null:
		t.check(false, "a Íris está na Estação")
		return
	station.settle_in(walker, S.RESEARCH)
	await tree.process_frame
	t.check(life.can_walk(walker), "a Íris passeando pode trocar de cômodo")
	var from := AHStation.room_def(S.RESEARCH)
	var to := AHStation.room_def(S.BAR)
	t.check(life.start_trip(walker, S.BAR), "a troca começa")
	t.check(not life.start_trip(_walker(station, C.BENTO), S.FORGE), "um andando por vez")
	var card: AHSpriteCard = walker.card
	var opened_from := false
	var opened_to := false
	var hidden := false
	var inside := true
	var steps := 0
	life.set_process(false)
	while not life.trip.is_empty() and steps < 4000:
		steps += 1
		life._tick_doors(0.05)
		life._tick_trip(0.05)
		opened_from = opened_from or life.door_amount(S.RESEARCH) > 0.9
		opened_to = opened_to or life.door_amount(S.BAR) > 0.9
		if not card.visible:
			hidden = true
			continue
		# Visível, a placa fica dentro de um dos dois cômodos, no andar dele: nunca no meio da parede.
		var room: Dictionary = from if absf(card.position.y - from.floor) < 0.01 else to
		if card.position.x < room.x0 or card.position.x > room.x1 or (absf(card.position.y - from.floor) > 0.01 and absf(card.position.y - to.floor) > 0.01):
			inside = false
	life.set_process(true)
	t.check(life.trip.is_empty(), "a troca termina (%d passos)" % steps)
	t.check(opened_from and opened_to, "a porta de saída e a de chegada abrem")
	t.check(hidden, "entre as duas portas, ninguém aparece")
	t.check(inside, "quem anda não atravessa parede: sempre dentro de um dos dois cômodos")
	t.equal(String(walker.room), S.BAR, "quem anda chega ao cômodo certo")
	t.check(card.visible and absf(card.position.y - to.floor) < 0.01 and card.position.x >= to.x0 and card.position.x <= to.x1,
		"de pé no Bar, à vista")
	t.check(life.visits.has("hero_sapo_iris") and life.visits.hero_sapo_iris.home == S.RESEARCH, "e volta depois para a Pesquisa")
	for i in 40:
		life._tick_doors(0.05)
	t.check(life.door_amount(S.RESEARCH) == 0.0 and life.door_amount(S.BAR) == 0.0, "as portas fecham")
	var parts: Dictionary = station.door_parts(S.BAR)
	t.check(not parts.is_empty() and is_equal_approx(parts.leaf.scale.x, 1.0) and not parts.gap.visible, "a folha volta inteira e o vão some")
	# O ferido anda mais devagar.
	var hero = S.hero(Campaign.state, "hero_sapo_iris")
	hero.hp = 1
	t.check(life.start_trip(walker, S.RESEARCH), "a volta começa")
	t.check(is_equal_approx(float(life.trip.speed), AHStation.WALK_SPEED * float(AHWounded.rules().SpeedFactor)), "o ferido anda no passo de ferido")
	# A troca para no meio quando os moradores são refeitos: ninguém fica no corredor.
	life._tick_trip(0.05)
	station.place_residents()
	await tree.process_frame
	t.check(life.trip.is_empty() and life.away_ids().is_empty(), "refeitos os moradores, ninguém fica entre as portas")
	hero.hp = hero.max_hp


func _focus_screen(station) -> void:
	var life: AHStationLife = station.life
	var hud: AHRefugeHud = station.hud
	hud.open_room(S.CHARACTERS)
	for frame in 20:
		await tree.process_frame
	var chosen: String = station.stage_hero
	t.check(chosen != "", "a Sala dos Personagens mostra um herói")
	t.check(not hud.life_allowed(), "com a Sala aberta, nem balão nem troca de cômodo")
	var walker = _walker(station, chosen)
	if walker != null:
		t.check(not life.can_walk(walker), "quem está na tela de foco não sai andando")
	t.check(not life.present().has(chosen), "nem fala")
	hud.close_panel()
	await _settle(station)


func _story(station) -> void:
	var life: AHStationLife = station.life
	var hud: AHRefugeHud = station.hud
	hud.refresh()
	t.equal(String(hud._next.get("action", "")), "story", "o Próximo passo pede a conversa")
	# Com as falas desligadas nas Opções, a conversa do objetivo sai mesmo assim (QA da #207: o passo travava).
	Campaign.state.settings.station_chatter = false
	hud._run_next()
	t.equal(life.story, "bento_brother", "a conversa da tirinha começa")
	var bento = _walker(station, C.BENTO)
	var nick = _walker(station, C.NICK)
	t.check(bento != null and nick != null and bento.room == nick.room, "o Bento e o Nick no mesmo cômodo")
	t.check(absf(bento.card.position.x - nick.card.position.x) <= 1.3, "lado a lado")
	var shown := false
	for frame in 600:
		await tree.process_frame
		# As falas de antes passam sozinhas; a do balão interativo fica.
		if life.bubble != null and not life.bubble.is_story():
			life._line_left = 0.0
		if life.story_bubble() != null:
			shown = true
			break
	t.check(shown, "a conversa chega ao balão interativo (com as falas desligadas)")
	Campaign.state.settings.station_chatter = true
	if not shown:
		return
	life._tick_line(60.0)
	t.check(life.story_bubble() != null, "o balão da tirinha fica até ser apertado")
	t.check(hud.focus_scope() == life.story_bubble(), "e fica com o foco do teclado e do controle")
	life.story_bubble().get_node("Open").pressed.emit()
	await tree.process_frame
	t.check(hud.comic_open(), "apertado, abre a tirinha")
	t.check(not hud.life_allowed(), "com a tirinha aberta, nenhum outro balão")
	var reader: AHComicReader = hud._comic
	t.check(reader.panels.size() >= 5, "a tirinha tem os quadros do dado (%d)" % reader.panels.size())
	t.check(reader.get_node("Comic").find_child("Placeholder", true, false).visible, "sem a arte, o quadro provisório")
	# Fechar antes do fim não conta: o objetivo continua.
	reader._close()
	await tree.process_frame
	t.check(not C.comic_seen(Campaign.state, "bento_brother"), "fechada no começo, a tirinha não fica vista")
	hud.open_comic("bento_brother")
	await tree.process_frame
	reader = hud._comic
	for i in reader.panels.size():
		reader.advance()
	await tree.process_frame
	t.check(not hud.comic_open(), "o último quadro fecha a tirinha")
	t.check(C.comic_seen(Campaign.state, "bento_brother"), "lida até o fim, fica vista")
	t.check(String(hud._next.get("action", "")) != "story", "e sai do Próximo passo")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Campaign.primary_path()))
	t.check(saved.get("campaign", {}).get("station", {}).get("comics_seen", []).has("bento_brother"), "e o save guarda")
