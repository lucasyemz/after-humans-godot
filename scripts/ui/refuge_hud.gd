## HUD da Estação Raiz (o lobby do AHRefugeWidget, enxuto): identidade e recursos em cima, o menu dos cômodos à esquerda
## e, à direita, o painel do cômodo com a função, o estado, a melhoria e o serviço dele (elenco, preparação, forja,
## pesquisa, depósito, cantina, descanso), além do relatório da volta e do trem com um candidato. Tudo chama as regras
## de AHStationRules e grava pela Estação (station.commit()).
class_name AHRefugeHud
extends Control

const H := preload("res://scripts/ui/combat_hud.gd")
const S := preload("res://scripts/flow/station_rules.gd")
const J := preload("res://scripts/flow/journey_rules.gd")
## Fases com mapa nesta versão (as outras chegam com os cenários, na Fase 4 do plano).
const PLAYABLE_PHASES := ["fase_1"]
const RESULT_NAMES := {"victory": "Vitória", "retreat": "Retirada", "fled": "Fuga", "defeat": "Derrota"}

var station: AHStation
var current := ""
var _title: Label
var _subtitle: Label
var _resources: Label
var _menu: VBoxContainer
var _panel: PanelContainer
var _body: VBoxContainer
var _feedback: Label
var _feedback_tween: Tween
## Rascunho da Preparação: fase, equipe (da frente para trás), foco e suprimentos extras.
var _draft := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = H.make_label("ESTAÇÃO RAIZ", 32, H.GOLD)
	_title.position = Vector2(36, 22)
	add_child(_title)
	_subtitle = H.make_label("", 19, H.MUTED)
	_subtitle.position = Vector2(38, 66)
	add_child(_subtitle)
	_resources = H.make_label("", 19, H.TEXT)
	_resources.position = Vector2(1000, 24)
	_resources.size = Vector2(884, 60)
	_resources.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_resources)

	_menu = VBoxContainer.new()
	_menu.position = Vector2(36, 120)
	_menu.custom_minimum_size = Vector2(330, 0)
	_menu.add_theme_constant_override("separation", 6)
	add_child(_menu)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", H.panel_style(0.9))
	_panel.position = Vector2(1210, 110)
	_panel.size = Vector2(676, 900)
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_body)
	_panel.visible = false

	_feedback = H.make_label("", 22, H.TEXT)
	_feedback.position = Vector2(380, 1024)
	_feedback.size = Vector2(800, 40)
	add_child(_feedback)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and current != "":
		close_panel()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	var c: Dictionary = Campaign.state
	var f := S.forecast(c, 4)
	_resources.text = "Sementes %d · Sucata %d · Fragmentos %d · Curativos %d\nSuprimentos %d/%d · Água %d · Energia %d/%d" % [
		S.quantity(c, "seeds"), S.quantity(c, "scrap"), S.quantity(c, "fragments"), S.quantity(c, "bandages"),
		f.food, f.food_capacity, f.water, f.power_used, f.power_capacity]
	var status: Array[String] = ["Ciclo %d" % c.station.cycle_number, "%d no elenco" % S.living(c).size()]
	if c.night.phase != "none":
		status.append("noite por resolver no Dormitório")
	if S.visit_pending(c):
		status.append("alguém espera na plataforma")
	_subtitle.text = " · ".join(status)
	_build_menu()
	if current != "":
		_show(current)


func _build_menu() -> void:
	for child in _menu.get_children():
		child.queue_free()
	_menu_button("Vista geral", "", "overview")
	if S.visit_pending(Campaign.state):
		_menu_button("Plataforma: o trem chegou", "", "train")
	for room in AHStation.ROOMS:
		var level := S.room_level(Campaign.state, room.id)
		var room_def := S.room_def(room.id)
		var state := "" if level >= 1 else " · vazio"
		if level >= 2:
			state = " · nível %d" % level
		if room.id == S.DORMITORY and Campaign.state.night.phase != "none":
			state += " · noite"
		_menu_button(room_def.name + state, room.id, "")


func _menu_button(text: String, room_id: String, service: String) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(330, 46)
	H.style_button(button)
	var key := room_id if room_id != "" else service
	if key == current or (key == "overview" and current == ""):
		button.add_theme_color_override("font_color", H.GOLD)
	button.pressed.connect(func():
		if service == "overview":
			close_panel()
		elif service != "":
			open_service(service)
		else:
			open_room(room_id))
	_menu.add_child(button)


func open_room(room_id: String) -> void:
	current = room_id
	if room_id == S.PREPARATION and _draft.is_empty():
		_reset_draft()
	station.focus_room(room_id)
	refresh()


func open_service(service: String) -> void:
	current = service
	if service == "train" or service == "report":
		station.focus_platform()
	refresh()


func close_panel() -> void:
	current = ""
	_panel.visible = false
	station.focus_overview()
	refresh()


func toast(text: String, error: bool = false) -> void:
	_feedback.text = text
	_feedback.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45) if error else H.GOLD)
	_feedback.modulate.a = 1.0
	if _feedback_tween:
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(3.2)
	_feedback_tween.tween_property(_feedback, "modulate:a", 0.0, 0.6)


## Aplica uma ação das regras: "" grava e atualiza; senão mostra o motivo.
func _act(error: String, success: String = "") -> void:
	if error != "":
		toast(error, true)
		return
	station.commit()
	if success != "":
		toast(success)


# ---------------------------------------------------------------- painel

func _show(key: String) -> void:
	for child in _body.get_children():
		child.queue_free()
	_panel.visible = true
	match key:
		"report":
			_report()
		"train":
			_train()
		_:
			_room(key)


func _heading(text: String, subtitle: String = "") -> void:
	_body.add_child(H.make_label(text, 30, H.GOLD))
	if subtitle != "":
		_text(subtitle, 18, H.MUTED)


func _text(text: String, size: int = 19, color: Color = H.TEXT) -> Label:
	var label := H.make_label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(620, 0)
	_body.add_child(label)
	return label


func _section(text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_body.add_child(spacer)
	_body.add_child(H.make_label(text, 22, H.GOLD.lightened(0.2)))


func _button(text: String, action: Callable, enabled: bool = true, parent: Container = null) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.custom_minimum_size = Vector2(0, 44)
	# Numa linha (Trocar, ↑, −, +) o botão fica do tamanho do texto; sozinho, quebra o texto longo.
	if parent == null:
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		button.custom_minimum_size = Vector2(56, 44)
	H.style_button(button)
	button.pressed.connect(action)
	(parent if parent else _body).add_child(button)
	return button


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_body.add_child(row)
	return row


func _room(room_id: String) -> void:
	var c: Dictionary = Campaign.state
	var level := S.room_level(c, room_id)
	var room_def := S.room_def(room_id)
	_heading(room_def.name, ("Nível %d" % level) if level >= 1 else "Vazio")
	_text(S.room_benefit(room_id, level))
	var cost := S.next_level_cost(c, room_id)
	if not cost.is_empty():
		var block := S.upgrade_block(c, room_id)
		var verb := "Recuperar" if level == 0 else "Melhorar"
		_button("%s (%s)%s" % [verb, S.cost_text(cost), "" if block == "" else " · " + block],
			func(): _act(S.upgrade_room(Campaign.state, room_id, level), "%s: nível %d." % [room_def.name, level + 1]), block == "")
	for civilian_id in c.station.residents:
		var who := S.civilian(civilian_id)
		if who.room == room_id:
			_civilian_card(c, who)
	if level < 1 and room_id != S.DORMITORY:
		return
	match room_id:
		S.CHARACTERS:
			_characters(c)
		S.PREPARATION:
			_preparation(c)
		S.CANTEEN:
			_canteen(c)
		S.DEPOT:
			_depot(c)
		S.FORGE:
			_forge(c)
		S.RESEARCH:
			_research(c)
		S.DORMITORY:
			_dormitory(c)


func _civilian_card(c: Dictionary, who: Dictionary) -> void:
	_section("%s · %s (%s)" % [who.name, who.role, who.species])
	var working := S.civilian_working(c, who.id)
	_text(("Ponto forte: %s" % who.benefit) if working else "Sem comida ou água no último ciclo: o ponto forte está parado até a próxima volta.",
		18, H.TEXT if working else Color(1.0, 0.6, 0.5))
	_text("Ponto fraco: %s" % who.drawback, 18, H.MUTED)
	_text(("Pedido entregue: %s." % who.request_reward) if S.has_completed_request(c, who.id) else ("Pedido: %s" % who.need), 18, H.MUTED)


# ---------------------------------------------------------------- Sala dos Personagens

func _characters(c: Dictionary) -> void:
	_section("Elenco (%d de %d)" % [S.living(c).size(), S.MAX_ROSTER])
	for entry in S.living(c):
		var hero_class = GameData.row("classes", entry.class_id)
		var tags: Array[String] = ["Vida %d/%d" % [entry.hp, entry.max_hp], "Instinto %d" % entry.instinct,
			"%d expedições" % int(entry.get("completed_expeditions", 0))]
		if entry.trauma:
			tags.append("trauma")
		var relic = GameData.row("relics", entry.relic_id) if entry.relic_id != "" else null
		tags.append("relíquia: %s" % (relic.DisplayName if relic else "nenhuma"))
		_text("%s · %s" % [entry.display_name, hero_class.DisplayName if hero_class else entry.class_id], 20, H.GOLD.lightened(0.3))
		_text(" · ".join(tags), 17, H.MUTED)
		var row := _row()
		var hero_id: String = entry.id
		if entry.trauma:
			_button("Tratar trauma (%d sementes)" % S.TRAUMA_COST, func(): _act(S.treat_trauma(Campaign.state, hero_id), "Trauma tratado."), true, row)
		var stock: Array = c.inventory.relics
		if not stock.is_empty() or entry.relic_id != "":
			_button("Trocar relíquia", func(): _cycle_relic(hero_id), true, row)
	_section("Recrutar")
	for class_id in c.unlocked_classes:
		var hero_class = GameData.row("classes", class_id)
		var free := S.can_recruit_volunteer(c, class_id)
		var id: String = class_id
		_button("%s · %s" % [hero_class.DisplayName if hero_class else class_id, "voluntário, de graça" if free else "%d sementes" % S.RECRUIT_COST],
			func(): _recruit(id), free or S.quantity(c, "seeds") >= S.RECRUIT_COST)
	if not c.memorial.is_empty():
		_section("Memorial")
		for entry in c.memorial:
			_text("%s · %s · %s" % [entry.display_name, entry.get("mission_name", ""), entry.get("cause", "")], 17, H.MUTED)


func _cycle_relic(hero_id: String) -> void:
	var c: Dictionary = Campaign.state
	var entry = S.hero(c, hero_id)
	var options: Array = [""]
	for relic_id in c.inventory.relics:
		if not options.has(relic_id):
			options.append(relic_id)
	if entry.relic_id != "" and not options.has(entry.relic_id):
		options.append(entry.relic_id)
	var index := options.find(entry.relic_id)
	var next: String = options[(index + 1) % options.size()]
	var relic = GameData.row("relics", next)
	_act(S.equip_relic(c, hero_id, next), "%s: %s." % [entry.display_name, relic.DisplayName if relic else "sem relíquia"])


func _recruit(class_id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var result := S.recruit(Campaign.state, class_id, rng)
	_act(result.error, "%s chegou à Estação." % (S.hero(Campaign.state, result.get("hero_id", "")).display_name if result.error == "" else ""))
	if result.error == "":
		var rng2 := RandomNumberGenerator.new()
		rng2.randomize()
		station._place_residents(rng2)


# ---------------------------------------------------------------- Preparação

func _reset_draft() -> void:
	var c: Dictionary = Campaign.state
	var team: Array = c.preferred_formation.filter(func(id): return S.hero(c, id) != null and S.hero(c, id).alive)
	for entry in S.living(c):
		if team.size() < 4 and not team.has(entry.id):
			team.append(entry.id)
	_draft = {"phase": "fase_1", "team": team, "focus": S.focus_recommended(c), "extra": 0}


func _preparation(c: Dictionary) -> void:
	var block := S.preparation_block(c)
	if block != "":
		_text(block, 20, Color(1.0, 0.65, 0.5))
		if c.night.phase != "none":
			_button("Ir ao Dormitório", func(): open_room(S.DORMITORY))
		elif S.visit_pending(c):
			_button("Ir à plataforma", func(): open_service("train"))
		return
	if _draft.is_empty():
		_reset_draft()
	_section("Fase")
	for info in J.PHASES:
		var unlocked := S.phase_unlocked(c, info.id)
		var playable: bool = PLAYABLE_PHASES.has(info.id)
		var state := "concluída" if c.completed_phases.has(info.id) else "liberada" if unlocked else "bloqueada"
		if unlocked and not playable:
			state = "o mapa chega com os cenários"
		var id: String = info.id
		var button := _button("%s%s · nível %d · %s" % ["▸ " if _draft.phase == id else "", info.name, info.level, state],
			func(): _draft.phase = id; refresh(), unlocked and playable)
		if _draft.phase == id:
			button.add_theme_color_override("font_color", H.GOLD)
	_section("Equipe (da frente para trás)")
	for rank in 4:
		var hero_id: String = _draft.team[rank] if rank < _draft.team.size() else ""
		var entry = S.hero(c, hero_id)
		var row := _row()
		var label := H.make_label("%d. %s" % [rank + 1, entry.display_name if entry else "—"], 20, H.TEXT)
		label.custom_minimum_size = Vector2(250, 0)
		row.add_child(label)
		if entry and S.attacks_from_rank(entry.class_id, rank + 1).is_empty():
			label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
		var slot := rank
		_button("Trocar", func(): _cycle_slot(slot), S.living(c).size() > _draft.team.size() or _draft.team.size() > 1, row)
		if rank > 0:
			_button("↑", func(): _swap(slot, slot - 1), true, row)
	_section("Foco da rota")
	var recommended := S.focus_recommended(c)
	for focus_id in [""] + S.FOCI.map(func(f): return f.id):
		if not S.focus_available(c, focus_id):
			continue
		var id: String = focus_id
		var label := S.focus_label(id)
		if id != "":
			label += " · " + S.focus_reward_text(id)
		if id == recommended:
			label += " · recomendado"
		var button := _button(("▸ " if _draft.focus == id else "") + label, func(): _draft.focus = id; refresh())
		if _draft.focus == id:
			button.add_theme_color_override("font_color", H.GOLD)
	_text(S.focus_reason(c, _draft.focus), 17, H.MUTED)
	_section("Suprimentos")
	var row := _row()
	var food_label := H.make_label("%d de graça + %d extras (%d sementes)" % [J.FREE_FOOD, _draft.extra, _draft.extra * S.FOOD_COST], 19)
	food_label.custom_minimum_size = Vector2(400, 0)
	row.add_child(food_label)
	_button("−", func(): _draft.extra = maxi(0, _draft.extra - 1); refresh(), _draft.extra > 0, row)
	_button("+", func(): _draft.extra = mini(J.MAX_FOOD - J.FREE_FOOD, _draft.extra + 1); refresh(),
		_draft.extra < J.MAX_FOOD - J.FREE_FOOD and (_draft.extra + 1) * S.FOOD_COST <= S.quantity(c, "seeds"), row)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	_body.add_child(spacer)
	var depart := _button("Confirmar partida", _depart)
	depart.custom_minimum_size = Vector2(0, 56)
	depart.add_theme_font_size_override("font_size", 24)


func _cycle_slot(rank: int) -> void:
	var c: Dictionary = Campaign.state
	var candidates: Array = S.living(c).map(func(h): return h.id)
	var current_id: String = _draft.team[rank] if rank < _draft.team.size() else ""
	var start := candidates.find(current_id)
	for step in range(1, candidates.size() + 1):
		var candidate: String = candidates[(start + step) % candidates.size()]
		if not _draft.team.has(candidate):
			if rank < _draft.team.size():
				_draft.team[rank] = candidate
			else:
				_draft.team.append(candidate)
			refresh()
			return
	# Todos já estão na equipe: troca de lugar com o próximo.
	_swap(rank, (rank + 1) % _draft.team.size())


func _swap(a: int, b: int) -> void:
	if a >= _draft.team.size() or b >= _draft.team.size():
		return
	var keep = _draft.team[a]
	_draft.team[a] = _draft.team[b]
	_draft.team[b] = keep
	refresh()


func _depart() -> void:
	var c: Dictionary = Campaign.state
	var error := S.confirm_departure(c, _draft.team.duplicate(), _draft.extra, randi(), _draft.phase, _draft.focus)
	if error != "":
		toast(error, true)
		return
	_draft = {}
	Campaign.save()
	GameFlow.change_to("street")


# ---------------------------------------------------------------- Cantina, Depósito, Forja, Pesquisa

func _canteen(c: Dictionary) -> void:
	var f := S.forecast(c, 4)
	_section("Próxima volta (equipe de 4)")
	_text("Suprimentos: %d no estoque, +%d da Cantina, %d para os moradores, a noite pede %d → %d depois da noite." % [
		f.food, f.food_produced, f.food_civilians, f.food_night_need, f.food_after_night])
	if f.food_spoiled > 0:
		_text("Acima da capacidade do Depósito (%d): %d estragam." % [f.food_capacity, f.food_spoiled], 18, Color(1.0, 0.65, 0.5))
	_text("Água: %d na estação, +%d do coletor, a equipe e os moradores bebem %d → %d%s." % [
		f.water, f.water_produced, f.water_consumed, f.water_after, " (vai faltar)" if f.thirsty else ""])
	_text("Energia: %d de %d.%s" % [f.power_used, f.power_capacity,
		"" if f.unpowered_rooms.is_empty() else " Sem energia: %s." % ", ".join(f.unpowered_rooms.map(func(id): return S.room_def(id).name))])
	if not c.station.last_cycle.is_empty():
		var cycle: Dictionary = c.station.last_cycle
		_section("Último ciclo (%d)" % cycle.number)
		_text("A Cantina produziu %d; os moradores comeram %d; estragaram %d; a água foi %d de consumo para %d do coletor%s." % [
			cycle.food_produced, cycle.food_civilians, cycle.food_spoiled, cycle.water_consumed, cycle.water_produced,
			" e faltou" if cycle.thirsty else ""], 18, H.MUTED)


func _depot(c: Dictionary) -> void:
	_section("Estoque")
	_text("Suprimentos: %d de %d" % [S.quantity(c, S.SUPPLIES), S.supply_capacity(c)])
	_text("Curativos: %d · Sementes: %d · Sucata: %d · Fragmentos: %d" % [S.quantity(c, "bandages"), S.quantity(c, "seeds"),
		S.quantity(c, "scrap"), S.quantity(c, "fragments")])
	_text("Água: %d" % c.station.water)
	var relics: Array = c.inventory.relics.map(func(id): return GameData.row("relics", id).DisplayName if GameData.row("relics", id) else id)
	_text("Relíquias no estoque: %s" % (", ".join(relics) if not relics.is_empty() else "nenhuma"))
	_text("Ferramentas: %s" % (", ".join(c.tools) if not c.tools.is_empty() else "nenhuma"))


func _forge(c: Dictionary) -> void:
	_section("Fabricar relíquias (%d sucatas cada)" % S.relic_cost(c))
	for relic_id in GameData.table("relics"):
		var relic: Dictionary = GameData.row("relics", relic_id)
		var id: String = relic_id
		_text("%s: %s" % [relic.DisplayName, relic.get("Description", "")], 18)
		_button("Fabricar %s" % relic.DisplayName, func(): _act(S.craft_relic(Campaign.state, id), "%s pronto. Equipe na Sala dos Personagens." % relic.DisplayName),
			S.quantity(c, "scrap") >= S.relic_cost(c))


func _research(c: Dictionary) -> void:
	_section("Melhorias de classe")
	for research_id in GameData.table("research"):
		var row: Dictionary = GameData.row("research", research_id)
		var done: bool = c.researched_skills.has(row.SkillId)
		var id: String = research_id
		_text("%s · %s" % [row.DisplayName, row.get("Description", "")], 18, H.MUTED if done else H.TEXT)
		_button("Pesquisado" if done else "Pesquisar (%d fragmentos)" % int(row.CostFragments),
			func(): _act(S.research(Campaign.state, id), "%s concluída." % row.DisplayName), not done and S.quantity(c, "fragments") >= int(row.CostFragments))


# ---------------------------------------------------------------- Dormitório: a noite da volta

func _dormitory(c: Dictionary) -> void:
	var night: Dictionary = c.night
	match night.phase:
		"planning":
			_section("Noite %d" % night.number)
			var sleepers: int = night.participants.filter(func(id): return S.hero(c, id) and S.hero(c, id).alive and id != night.watch_hero_id).size()
			_text("Quem dorme come um suprimento e recupera 35%% da vida e 15 de instinto (sem comida, 15%% e 5). Suprimentos: %d para %d." % [
				S.quantity(c, S.SUPPLIES), sleepers])
			if night.thirsty:
				_text("Faltou água na volta: o descanso rende menos instinto.", 18, Color(1.0, 0.65, 0.5))
			_section("Vigia")
			var options: Array = [""] + night.participants
			for hero_id in options:
				var entry = S.hero(c, hero_id)
				if hero_id != "" and (entry == null or not entry.alive):
					continue
				var id: String = hero_id
				var label := "Ninguém de vigia" if id == "" else "%s (Vida %d/%d)" % [entry.display_name, entry.hp, entry.max_hp]
				var button := _button(("▸ " if night.watch_hero_id == id else "") + label, func(): S.set_watch(Campaign.state, id); station.commit())
				if night.watch_hero_id == id:
					button.add_theme_color_override("font_color", H.GOLD)
			_text("Um vigia não descansa, mas protege os outros dos ruídos da noite.", 17, H.MUTED)
			_button("Comprar 1 suprimento (%d sementes)" % S.SUPPLY_COST_SEEDS,
				func(): _act("" if S.buy_supplies(Campaign.state) else "Sementes insuficientes.", "Suprimento comprado."),
				S.quantity(c, "seeds") >= S.SUPPLY_COST_SEEDS)
			_button("Dormir", func(): _act("" if S.resolve_night(Campaign.state) else "A noite não pode passar agora."))
		"dawn":
			_section("Amanhecer")
			_text(S.night_event_text(c))
			for result in night.results:
				var entry = S.hero(c, result.hero_id)
				if entry == null:
					continue
				_text(("%s ficou de vigia." % entry.display_name) if result.watch else "%s: +%d de vida, −%d de instinto%s." % [
					entry.display_name, result.hp_recovered, result.instinct_reduced, "" if result.fed else " (sem comida)"], 18)
			_button("Começar o dia", func():
				_act("" if S.finish_dawn(Campaign.state) else "Ainda não amanheceu.")
				if S.visit_pending(Campaign.state):
					open_service("train"))
		_:
			_text("Ninguém precisa descansar agora. Depois de cada expedição, a equipe passa a noite aqui.", 18, H.MUTED)


# ---------------------------------------------------------------- relatório da volta e trem

func _report() -> void:
	var c: Dictionary = Campaign.state
	var report: Dictionary = c.station.last_return
	if report.is_empty():
		close_panel()
		return
	var phase := J.phase(report.get("phase_id", ""))
	_heading("Relatório da expedição", "%s · %s" % [phase.get("name", ""), RESULT_NAMES.get(report.result, report.result)])
	var percent := int(report.get("percent", 0))
	_text("Saque entregue (%d%%): %d sementes, %d sucata, %d fragmentos%s%s." % [percent, report.seeds, report.scrap, report.fragments,
		(", %d água" % report.water) if report.water > 0 else "", (", %d suprimentos" % report.supplies) if report.supplies > 0 else ""])
	if report.get("request", "") != "":
		var who := S.civilian(report.request)
		_text("%s recebeu %s: %s." % [who.name, who.request_item, who.request_reward], 18, H.GOLD)
	_section("Equipe")
	for hero_id in report.team:
		var entry = S.hero(c, hero_id)
		if entry:
			_text(("%s · Vida %d/%d" % [entry.display_name, entry.hp, entry.max_hp]) if entry.alive else "%s não voltou." % entry.display_name,
				18, H.TEXT if entry.alive else Color(1.0, 0.55, 0.45))
	var cycle: Dictionary = report.get("cycle", {})
	if not cycle.is_empty():
		_section("A Estação no ciclo %d" % cycle.number)
		_text("A Cantina produziu %d suprimentos; os moradores comeram %d; estragaram %d. Água: %d bebida, %d do coletor%s." % [
			cycle.food_produced, cycle.food_civilians, cycle.food_spoiled, cycle.water_consumed, cycle.water_produced,
			"; faltou para alguém" if cycle.thirsty else ""], 18)
		if cycle.fragments_produced > 0:
			_text("A Cora trouxe %d fragmento." % cycle.fragments_produced, 18)
	_button("Entrar no abrigo", func():
		Campaign.state.station.last_return.seen = true
		station.commit()
		if Campaign.state.night.phase != "none":
			open_room(S.DORMITORY)
		elif S.visit_pending(Campaign.state):
			open_service("train")
		else:
			close_panel())


func _train() -> void:
	var c: Dictionary = Campaign.state
	var train: Dictionary = c.station.train
	if train.phase != "waiting":
		close_panel()
		return
	var who := S.civilian(train.candidate_id)
	_heading("O trem chegou", "%s quer morar na Estação" % who.name)
	_text("%s · %s (%s). %s" % [who.name, who.role, who.species, who.trait])
	_text("Ponto forte: %s" % who.benefit)
	_text("Ponto fraco: %s" % who.drawback, 19, H.MUTED)
	_text("Pedido: %s" % who.need, 18, H.MUTED)
	var before := S.forecast(c, 4)
	var after := S.forecast_with(c, who.id, 4)
	_section("Na próxima volta")
	_text("Suprimentos depois da noite: %d → %d · Água depois: %d → %d%s · Energia: %d → %d" % [
		before.food_after_night, after.food_after_night, before.water_after, after.water_after,
		" (vai faltar)" if after.thirsty else "", before.power_capacity, after.power_capacity], 18)
	if c.night.phase != "none":
		_text("A equipe ainda precisa passar a noite: decida depois do Dormitório, se preferir.", 17, H.MUTED)
	var row := _row()
	var id: String = who.id
	_button("Acolher %s" % who.name, func(): _decide(id, true), true, row)
	_button("Recusar", func(): _decide(id, false), true, row)


func _decide(candidate_id: String, accept: bool) -> void:
	var c: Dictionary = Campaign.state
	var error := S.decide_candidate(c, candidate_id, accept)
	if error != "":
		toast(error, true)
		return
	# A partida do trem é a cena da 3c; por enquanto ele parte na hora.
	S.finish_departure(c)
	var who := S.civilian(candidate_id)
	station.commit()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	station._place_residents(rng)
	toast(("%s vai morar na Estação." % who.name) if accept else "%s segue no trem. Pode voltar numa próxima viagem." % who.name)
	if Campaign.state.night.phase != "none":
		open_room(S.DORMITORY)
	else:
		close_panel()
