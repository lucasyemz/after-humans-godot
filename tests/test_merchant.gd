## O Mercador (#182, parte 2): o trem às vezes traz o Sr. dos Trilhos no lugar de alguém (o peso em data/recruitment.json),
## também com a casa cheia. Ele não entra no elenco: troca nos números de data/merchant.json, com o limite por visita, e
## é dispensado antes da Preparação. O save guarda as trocas da visita, e o save antigo abre. Na tela: o painel das
## trocas, a pose de oferta, a dispensa com ele voltando ao vagão de passada, e o Maior sem nada fora do painel.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const J = preload("res://scripts/flow/journey_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_arrivals()
	_trades()
	_dismissal()
	_return_report()
	_saves()
	await _screens()


func _campaign(seed_value: int = 218) -> Dictionary:
	var c: Dictionary = Campaign.create_initial(seed_value)
	c.station.rooms[S.CHARACTERS] = 4
	c.inventory.seeds = 40
	c.inventory.scrap = 6
	c.inventory.fragments = 3
	return c


## Quem o trem traz: o Mercador numa parte das chegadas (o peso dele contra o de vir um ou dois), sempre o mesmo na mesma
## volta; com a casa cheia e a fila vazia, só ele ou ninguém; com o peso zero, nunca.
func _arrivals() -> void:
	var arrivals := 0
	var merchants := 0
	var alone := true
	for i in 400:
		var c := _campaign()
		if not S.train_on_return(c, "merchant-%d" % i):
			continue
		arrivals += 1
		if S.merchant_here(c):
			merchants += 1
			alone = alone and c.station.train.recruit.is_empty() and c.station.train.next.is_empty()
	t.check(alone, "o Mercador vem sozinho, sem recruta junto")
	var weights: Dictionary = GameData.row("recruitment", "train")
	var expected := float(weights.MerchantWeight) / float(weights.SingleWeight + weights.PairWeight + weights.MerchantWeight)
	var share := float(merchants) / maxf(1.0, float(arrivals))
	t.check(absf(share - expected) < 0.08, "o Mercador é %d%% das chegadas (o peso dá %d%%; %d de %d)" % [roundi(share * 100), roundi(expected * 100), merchants, arrivals])
	# A mesma volta traz sempre o mesmo.
	var same := true
	for i in 30:
		var a := _campaign()
		var b := _campaign()
		S.train_on_return(a, "again-%d" % i)
		S.train_on_return(b, "again-%d" % i)
		same = same and S.merchant_here(a) == S.merchant_here(b) and a.station.train.candidate_id == b.station.train.candidate_id
	t.check(same, "a mesma expedição traz sempre o mesmo")
	# A casa cheia e a fila vazia: nenhum animal nem civil, mas o Mercador ainda vem.
	var full_merchants := 0
	var others := 0
	for i in 200:
		var c := _campaign()
		c.station.rooms[S.CHARACTERS] = 0
		while not S.heroes_full(c):
			c.roster.append(Campaign.new_hero("hero_cao_%d" % (c.roster.size() + 50), "cao", "Extra", 30, []))
		c.station.candidate_queue = []
		if S.train_on_return(c, "full-%d" % i):
			if S.merchant_here(c):
				full_merchants += 1
			else:
				others += 1
	t.check(full_merchants > 0 and others == 0, "com a casa cheia e a fila vazia, só o Mercador vem (%d vezes em 200)" % full_merchants)
	# A barra de Admin traz o Mercador na hora.
	var forced := _campaign()
	t.check(S.train_on_return(forced, "admin-merchant", "merchant") and S.merchant_here(forced), "a barra de Admin traz o Mercador")
	t.equal(S.train_candidate_name(forced), TranslationServer.translate(S.MERCHANT_NAME), "e quem espera na plataforma é o Sr. dos Trilhos")
	t.equal(int(forced.station.get("train_dry", -1)), 0, "a chegada dele zera as voltas sem ninguém")
	# Peso zero: nunca vem.
	var saved := int(weights.MerchantWeight)
	weights.MerchantWeight = 0
	var never := true
	for i in 200:
		var c := _campaign()
		S.train_on_return(c, "merchant-%d" % i)
		never = never and not S.merchant_here(c)
	weights.MerchantWeight = saved
	t.check(never, "com o peso zero, o Mercador nunca vem")


func _with_merchant() -> Dictionary:
	var c := _campaign()
	S.train_on_return(c, "trades-%d" % Time.get_ticks_usec(), "merchant")
	return c


## As trocas nos números da tabela: dá o que pede, recebe o que oferece, até o limite da visita; sem o que dar, não sai.
func _trades() -> void:
	t.equal(S.merchant_trades().map(func(r): return String(r.Name)), ["sell_fragments", "buy_fragments", "sell_scrap", "buy_scrap"],
		"as quatro trocas, na ordem da tabela")
	for row in S.merchant_trades():
		var c := _with_merchant()
		var id := String(row.Name)
		var give := String(row.Give)
		var got := String(row.Get)
		c.inventory[give] = int(row.GiveAmount) * (int(row.Limit) + 1)
		var give_before := S.quantity(c, give)
		var got_before := S.quantity(c, got)
		var done := 0
		while S.merchant_trade(c, id) == "":
			done += 1
			if done > 20:
				break
		t.equal(done, int(row.Limit), "%s sai %d vez(es) por visita" % [id, int(row.Limit)])
		t.equal(S.quantity(c, give), give_before - done * int(row.GiveAmount), "%s: a Estação dá %d %s por troca" % [id, int(row.GiveAmount), give])
		t.equal(S.quantity(c, got), got_before + done * int(row.GetAmount), "%s: e recebe %d %s" % [id, int(row.GetAmount), got])
		t.equal(S.trades_left(c, id), 0, "%s: esgotada" % id)
		t.check(S.trade_block(c, id) != "", "%s: esgotada, diz o motivo" % id)
	# Ninguém ganha comprando e vendendo de volta.
	var buy_fragments: Dictionary = GameData.row("merchant", "buy_fragments")
	var sell_fragments: Dictionary = GameData.row("merchant", "sell_fragments")
	var buy_scrap: Dictionary = GameData.row("merchant", "buy_scrap")
	var sell_scrap: Dictionary = GameData.row("merchant", "sell_scrap")
	t.check(int(buy_fragments.GiveAmount) > int(sell_fragments.GetAmount) and int(buy_scrap.GiveAmount) > int(sell_scrap.GetAmount),
		"comprar custa mais do que vender rende (fragmento e sucata)")
	# Sem o que dar: não sai, e nada muda.
	var poor := _with_merchant()
	poor.inventory.seeds = 3
	var block := S.trade_block(poor, "buy_fragments")
	t.check(block.contains(TranslationServer.translate("sementes")), "sem sementes, a compra diz o que falta (%s)" % block)
	t.check(S.merchant_trade(poor, "buy_fragments") != "" and S.quantity(poor, "seeds") == 3 and S.quantity(poor, "fragments") == 3,
		"e nada muda")
	t.check(S.merchant_trade(poor, "nada") != "", "uma troca desconhecida não sai")
	# Sem o Mercador, nenhuma troca.
	var empty := _campaign()
	t.check(S.merchant_trade(empty, "sell_scrap") != "" and S.quantity(empty, "scrap") == 6, "sem o Mercador na plataforma, nenhuma troca")
	# A próxima visita começa do zero.
	var c := _with_merchant()
	S.merchant_trade(c, "buy_fragments")
	S.dismiss_merchant(c)
	S.finish_departure(c)
	S.train_on_return(c, "next-visit", "merchant")
	t.equal(S.trades_left(c, "buy_fragments"), int(buy_fragments.Limit), "a próxima visita começa com as trocas do zero")


## O Mercador não fica nem é recusado; a Preparação e a partida pedem para dispensá-lo; dispensado, o trem parte.
func _dismissal() -> void:
	var c := _with_merchant()
	t.check(S.decide_candidate(c, S.MERCHANT, true) != "" and S.merchant_here(c), "o Mercador não pode ser acolhido")
	t.check(S.decide_candidate(c, S.MERCHANT, false) != "" and S.merchant_here(c), "nem recusado: ele é dispensado")
	t.check(not c.roster.any(func(h): return String(h.id) == S.MERCHANT), "e não entra no elenco")
	var block := S.preparation_block(c)
	t.check(block.contains("Sr. dos Trilhos"), "a Preparação pede para dispensá-lo (%s)" % block)
	t.check(AHKit.font(true).get_string_size(block, HORIZONTAL_ALIGNMENT_LEFT, -1, AHKit.size("small")).x
		<= AHKit.font(true).get_string_size(TranslationServer.translate("Conclua a noite no Dormitório antes de partir."), HORIZONTAL_ALIGNMENT_LEFT, -1, AHKit.size("small")).x,
		"o motivo é curto como o da noite (ele aparece no botão IR AO MAPA, numa linha)")
	# Esperar um dia não mexe no trem: o Mercador não trava o descanso.
	t.equal(S._day_block(c), "", "o Mercador não trava o dia na Estação")
	var team: Array = S.living(c).slice(0, 4).map(func(h): return String(h.id))
	t.equal(S.confirm_departure(c, team, 0, 7, "fase_1"), block, "e a partida também")
	t.check(c.session.get("expedition") == null, "a equipe não parte com ele na plataforma")
	var step := S.next_step(c)
	t.check(step.action == "train" and String(step.text).contains(TranslationServer.translate(S.MERCHANT_NAME)), "o Próximo passo leva à plataforma")
	t.equal(S.dismiss_merchant(c), "", "dispensar")
	t.equal(c.station.train.phase, "departing", "dispensado, o trem parte")
	t.check(S.dismiss_merchant(c) != "", "dispensar de novo não vale")
	S.finish_departure(c)
	t.check(not S.merchant_here(c) and S.preparation_block(c) == "", "o trem partiu: a Preparação abre")
	t.equal(S.confirm_departure(c, team, 0, 7, "fase_1"), "", "e a equipe parte")


## A volta que traz o Mercador: o relatório diz que ele veio.
func _return_report() -> void:
	var found := false
	for i in 120:
		var c := _campaign(300 + i)
		c.station.rooms[S.DORMITORY] = 1
		J.start_expedition(c, "fase_1", 500 + i)
		c.session.result = "victory"
		var report := S.finish_return(c)
		if report.get("merchant", false):
			found = true
			t.check(S.merchant_here(c) and String(report.train) == TranslationServer.translate(S.MERCHANT_NAME),
				"a volta que traz o Mercador guarda no relatório quem veio")
			break
	t.check(found, "alguma volta traz o Mercador")


## O save guarda o Mercador e as trocas da visita; o save de antes (sem o campo) abre sem trocas.
func _saves() -> void:
	var c := _with_merchant()
	S.merchant_trade(c, "sell_scrap")
	var reopened = Campaign._normalize(JSON.parse_string(JSON.stringify(c)))
	S.migrate(reopened)
	t.check(S.merchant_here(reopened), "o save guarda o Mercador na plataforma")
	t.equal(S.trades_left(reopened, "sell_scrap"), int(GameData.row("merchant", "sell_scrap").Limit) - 1, "e as trocas da visita")
	var old: Dictionary = _campaign()
	old.station.train.erase("trades")
	S.migrate(old)
	t.check(typeof(old.station.train.get("trades")) == TYPE_DICTIONARY and old.station.train.trades.is_empty(), "o save antigo abre sem trocas")


## Na tela: o trem chega com o Mercador, o painel mostra as trocas e ele oferece a mercadoria; trocar muda o estoque e
## esgota a troca; a Preparação pede para dispensá-lo; dispensado, ele volta ao vagão de passada e o trem parte.
func _screens() -> void:
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-merchant-%d" % Time.get_ticks_usec()
	var c := _with_merchant()
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
		var art: Dictionary = AHCombatArena.npc_art_of(S.MERCHANT)
		t.check(["idle", "walk", "trade", "portrait"].all(func(k): return art.has(k)), "a arte do Mercador está no manifesto")
		hud.open_service("train")
		var saw_walk := false
		var end := Time.get_ticks_msec() + 40000
		while (station.train_busy() or not hud._panel.visible) and Time.get_ticks_msec() < end:
			if is_instance_valid(station._candidate) and String(station._candidate.art().get("file", "")) == String(art.walk.file):
				saw_walk = true
			await _tree.process_frame
		await _frames(4)
		t.check(saw_walk, "ele desce do trem de passada")
		t.check(is_instance_valid(station._candidate) and station._candidate_id == S.MERCHANT, "o Mercador está na plataforma")
		t.check(is_instance_valid(station._candidate) and String(station._candidate.art().get("file", "")) == String(art.trade.file),
			"com o painel aberto, ele oferece a mercadoria")
		t.check(is_instance_valid(station._candidate) and is_equal_approx(station._candidate.body_height, 1.72), "na altura do Bento")
		t.check(_label(hud._panel, TranslationServer.translate(S.MERCHANT_NAME)), "o painel é dele")
		var rows: Array = S.merchant_trades().map(func(r): return hud._body.find_child("Trade_%s" % r.Name, true, false))
		t.check(rows.all(func(r): return r != null), "com as quatro trocas")
		var buy: Node = hud._body.find_child("Trade_buy_fragments", true, false)
		var button: Button = buy.find_child("Do", true, false) if buy else null
		if t.check(button != null and not button.disabled, "comprar um fragmento está liberado"):
			var seeds := S.quantity(Campaign.state, "seeds")
			var fragments := S.quantity(Campaign.state, "fragments")
			button.pressed.emit()
			await _frames(3)
			t.equal([S.quantity(Campaign.state, "seeds"), S.quantity(Campaign.state, "fragments")], [seeds - 12, fragments + 1],
				"a troca muda o estoque")
			buy = hud._body.find_child("Trade_buy_fragments", true, false)
			button = buy.find_child("Do", true, false) if buy else null
			t.check(button != null and button.text == TranslationServer.translate("Esgotada") and _label(buy, TranslationServer.translate("Esgotada nesta visita.")),
				"e, no limite da visita, a troca fica esgotada")
			var seeds_now := S.quantity(Campaign.state, "seeds")
			if button != null:
				button.pressed.emit()
			await _frames(2)
			t.equal(S.quantity(Campaign.state, "seeds"), seeds_now, "apertar a esgotada não troca nada")
		# Sem sementes, o que falta fica na cor de alerta.
		Campaign.state.inventory.seeds = 0
		hud.refresh()
		await _frames(3)
		var scrap_row: Node = hud._body.find_child("Trade_buy_scrap", true, false)
		var give: Node = scrap_row.find_child("Give", true, false) if scrap_row else null
		var give_label: Label = give.find_children("*", "Label", true, false)[0] if give else null
		t.check(give_label != null and give_label.get_theme_color("font_color") == AHKit.alert_text(), "o que falta dar fica na cor de alerta")
		Campaign.state.inventory.seeds = 40
		hud.refresh()
		await _frames(3)
		# No Maior, nada sai pelos lados do painel, e Dispensar fica à vista.
		var size_before: int = Settings.text_size
		Settings.set_text_size(2)
		hud.refresh()
		await _frames(6)
		var panel: Rect2 = hud._panel.get_global_rect()
		var wide: Array = hud._body.find_children("*", "Control", true, false).filter(func(n): return n.is_visible_in_tree() and (n as Control).get_global_rect().end.x > panel.end.x + 1.0)
		t.check(wide.is_empty(), "no Maior, nada sai pela direita do painel%s" % ("" if wide.is_empty() else " (%s)" % wide[0].name))
		var dismiss: Button = hud._footer.find_child("Dismiss", false, false)
		t.check(dismiss != null and dismiss.is_visible_in_tree() and panel.encloses(dismiss.get_global_rect()), "e Dispensar fica à vista")
		Settings.set_text_size(size_before)
		hud.refresh()
		await _frames(4)
		await _keys(hud)
		# A Preparação: o mapa não abre; ela pede para dispensá-lo e leva à plataforma.
		hud.open_map()
		await _frames(4)
		t.check(hud.current == S.PREPARATION and _label(hud._panel, "Sr. dos Trilhos"),
			"com ele na plataforma, a Preparação pede para dispensá-lo")
		hud._on_phase_chosen("fase_1")
		await _frames(3)
		t.check(hud.current != "departure", "e a partida não abre")
		hud.open_service("train")
		end = Time.get_ticks_msec() + 20000
		while (station.train_busy() or not hud._panel.visible) and Time.get_ticks_msec() < end:
			await _tree.process_frame
		await _frames(3)
		dismiss = hud._footer.find_child("Dismiss", false, false)
		if t.check(dismiss != null, "o botão de dispensar"):
			dismiss.pressed.emit()
		var walked_back := false
		end = Time.get_ticks_msec() + 30000
		while Campaign.state.station.train.phase != "none" and Time.get_ticks_msec() < end:
			if is_instance_valid(station._candidate) and String(station._candidate.art().get("file", "")) == String(art.walk.file):
				walked_back = true
			await _tree.process_frame
		t.check(walked_back, "dispensado, ele volta ao vagão de passada")
		t.equal(Campaign.state.station.train.phase, "none", "e o trem parte")
		await _frames(3)
		t.check(not is_instance_valid(station._candidate), "a plataforma fica vazia")
		t.equal(S.preparation_block(Campaign.state), "", "e a Preparação abre")
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


## Só o teclado (a QA da rodada 1): Interagir nunca dispensa o Mercador sem querer, nem sem troca possível, e apertar
## várias vezes não desfaz uma troca com a de volta (o foco fica na troca apertada, mesmo esgotada).
func _keys(hud: AHRefugeHud) -> void:
	var keys_before: bool = AHUiStyle.using_keys
	AHUiStyle.using_keys = true
	var c: Dictionary = Campaign.state
	var stock := [int(c.inventory.seeds), int(c.inventory.scrap), int(c.inventory.fragments)]
	c.inventory.seeds = 0
	c.inventory.scrap = 0
	c.inventory.fragments = 0
	hud._merchant_focus = ""
	hud.refresh()
	await _frames(6)
	var focus := hud.get_viewport().gui_get_focus_owner()
	t.check(focus != null and focus.name == "Do", "sem troca possível, o foco começa numa troca, e não em Dispensar (%s)" % (focus.name if focus else "nenhum"))
	for i in 3:
		await _send("interact")
	t.check(S.merchant_here(c), "e Interagir não dispensa o Mercador")
	# Com o que trocar: Interagir várias vezes faz só a troca do foco, até o limite, e não a de volta.
	c.inventory.seeds = 40
	c.inventory.scrap = 6
	c.inventory.fragments = 3
	c.station.train.trades = {}
	hud._merchant_focus = ""
	hud.refresh()
	await _frames(6)
	var first: Dictionary = S.merchant_trades()[0]
	for i in 8:
		await _send("interact")
	focus = hud.get_viewport().gui_get_focus_owner()
	t.check(S.merchant_here(c), "apertar Interagir oito vezes não dispensa o Mercador")
	t.equal(int(c.station.train.trades.get(String(first.Name), 0)), int(first.Limit), "faz a troca do foco até o limite")
	t.equal(c.station.train.trades.keys(), [String(first.Name)], "e nenhuma outra (nem a de volta)")
	var row: Node = focus.get_parent().get_parent().get_parent() if focus != null else null
	t.check(focus != null and focus.name == "Do" and row != null and String(row.name) == "Trade_%s" % first.Name,
		"o foco fica na troca esgotada")
	c.inventory.seeds = stock[0]
	c.inventory.scrap = stock[1]
	c.inventory.fragments = stock[2]
	AHUiStyle.using_keys = keys_before
	hud.refresh()
	await _frames(3)


func _send(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(3)


func _label(node: Node, text: String) -> bool:
	for label in node.find_children("*", "Label", true, false):
		if (label as Label).text.contains(text):
			return true
	return false


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
