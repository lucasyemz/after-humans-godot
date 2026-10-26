## A ficha do personagem ao apontar (#89, a P7 da proposta do laço): o nome, a espécie e o papel (ou a máquina e o que
## ela é), a vida, o instinto, a velocidade, os efeitos passivos (traços, relíquia, laços, treinos) e os estados com o
## que cada um faz. Abre com o mouse em cima, o foco do teclado ou do controle e o toque longo; some ao sair. Assim o que
## saiu da tela fixa (#56) continua a um apontar de distância. Usa os tokens do AHUiStyle, para trocar pelo kit da #59/#60.
## O nível (#90) entra pela velocidade do Passo ligeiro e pelas melhorias do Treino, listadas nos passivos.
class_name AHCharacterSheet
extends PanelContainer

const U = preload("res://scripts/ui/ui_style.gd")
const WIDTH := 380.0
## O toque longo que abre a ficha (s).
const LONG_PRESS := 0.45
## A folga entre a ficha e o que ela descreve (px).
const GAP := 14.0
## O que o Último Fôlego e o Trauma fazem (o painel de baixo só diz o nome, e só de quem age).
const LAST_BREATH := "Com 0 de vida, ainda de pé: o próximo golpe tem 50% de chance de derrubar de vez."
const TRAUMA := "Começa cada jornada com 10 de instinto; trata-se no Alojamento."

## O que a ficha mostra agora ({} fechada): o dicionário de from_unit ou from_hero.
var info := {}
## O último apontar foi um toque (o mouse que a Godot emula do toque não abre a ficha: só o toque longo).
var touch_mode := false
## O toque que está segurando: o controle, o que mostrar e desde quando (ms); o controle que abriu a ficha pelo toque
## longo (o soltar dele não aperta o botão).
var _hold := {}
var _long_opened: Control


func _init() -> void:
	name = "CharacterSheet"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	# O aço e a Barlow do kit (#60), como a dica da luta.
	add_theme_stylebox_override("panel", AHKit.style(AHKit.piece_of("panel", "large")))
	custom_minimum_size = Vector2(WIDTH, 0)


## A ficha de quem está na luta: a unidade do combate, com os estados de agora. boss: o guardião do trecho.
static func from_unit(session: AHCombatSession, unit: AHCombat.Unit, boss: bool = false) -> Dictionary:
	var out := {"id": unit.id, "name": AHCombatHud.unit_name(unit.display_name), "hp": unit.hp, "max_hp": unit.max_hp,
		"speed": unit.speed, "instinct": unit.instinct if unit.is_player else -1, "passives": [], "states": [],
		"enemy": not unit.is_player}
	if unit.is_player:
		var hero_class = GameData.row("classes", unit.class_id)
		out.kind = _kind(hero_class)
		var hero = Campaign.hero(unit.hero_id)
		out.passives = _hero_passives(hero, unit.perks, unit.class_id)
		# Os laços desta jornada com quem está na luta (amizade ou rivalidade).
		var context = session.context if session != null else null
		if context != null:
			for other in session.state.player_team:
				if other.id == unit.id:
					continue
				var pair := [unit.hero_id, other.hero_id]
				pair.sort()
				var value := int(context.relationships.get("%s_%s" % pair, 0))
				if value != 0:
					out.passives.append([TranslationServer.translate("Laço com %s") % other.display_name,
						(TranslationServer.translate("Amizade %+d · em +3, quando um cai, o outro ergue a guarda (+1 bloqueio)") if value > 0
							else TranslationServer.translate("Rivalidade %+d · em −3, a falha de um abala o outro (+5 de instinto)")) % value, value > 0])
	else:
		var enemy = GameData.row("enemies", unit.enemy_id)
		var machine: bool = enemy != null and enemy.get("Category", "") == "Machine"
		out.kind = TranslationServer.translate("Máquina") if machine else TranslationServer.translate("Criatura")
		if boss:
			out.kind += " · " + TranslationServer.translate("guardião do trecho")
		if enemy != null:
			out.description = TranslationServer.translate(String(enemy.get("Description", "")))
			var dot := int(round(float(enemy.get("DotResist", 0.0)) * 100.0))
			var push := int(round(float(enemy.get("DisplacementResist", 0.0)) * 100.0))
			if dot > 0:
				out.passives.append([TranslationServer.translate("Resiste a dano por turno"), TranslationServer.translate("%d%% de chance de não sangrar nem contaminar") % dot, true])
			if push > 0:
				out.passives.append([TranslationServer.translate("Resiste a deslocamento"), TranslationServer.translate("%d%% de chance de não ser empurrado nem puxado") % push, true])
	for entry in U.statuses(unit):
		out.states.append([String(entry[0]), U.status_tip(entry) if entry.size() > 4 else "", bool(entry[1])])
	# O que o painel de baixo só mostra de quem age: o Último Fôlego e o Trauma.
	if unit.deaths_door and unit.hp <= 0:
		out.states.append([TranslationServer.translate("Último Fôlego"), TranslationServer.translate(LAST_BREATH), false])
	if unit.trauma:
		out.states.append([TranslationServer.translate("Trauma"), TranslationServer.translate(TRAUMA), false])
	return out


## A ficha de um herói fora da luta (a Preparação): do elenco, sem estados de luta.
static func from_hero(hero: Dictionary) -> Dictionary:
	var hero_class = GameData.row("classes", String(hero.get("class_id", "")))
	var speed := int(hero_class.get("BaseSpeed", 0)) if hero_class != null else 0
	for perk_id in hero.get("perks", []):
		var perk = GameData.row("perks", perk_id)
		if perk != null and String(perk.get("Unit", "")) == "Speed" and String(perk.get("Target", "self")) == "self":
			speed += int(perk.get("Value", 0))
	# O nível (#90): o Passo ligeiro soma na velocidade, como na luta.
	speed += int(AHHeroLevels.combat_bonus(hero).speed)
	var out := {"id": String(hero.get("id", "")), "name": String(hero.get("display_name", "")), "kind": _kind(hero_class),
		"hp": int(hero.get("hp", 0)), "max_hp": int(hero.get("max_hp", 1)), "speed": speed, "instinct": int(hero.get("instinct", 0)),
		"passives": _hero_passives(hero, hero.get("perks", []), String(hero.get("class_id", ""))), "states": [], "enemy": false}
	if hero.get("trauma", false):
		out.states.append([TranslationServer.translate("Trauma"), TranslationServer.translate(TRAUMA), false])
	return out


static func _kind(hero_class) -> String:
	if hero_class == null:
		return ""
	return "%s · %s" % [TranslationServer.translate(String(hero_class.get("Species", ""))), TranslationServer.translate(String(hero_class.get("Role", "")))]


## Os traços (perks), a relíquia e os treinos do herói (a Pesquisa da classe, campaign.researched_skills): [título, o que
## faz, bom?].
static func _hero_passives(hero, perks: Array, class_id: String) -> Array:
	var out: Array = []
	for perk_id in perks:
		var perk = GameData.row("perks", perk_id)
		if perk != null:
			out.append([TranslationServer.translate(String(perk.DisplayName)), TranslationServer.translate(String(perk.get("Description", ""))), bool(perk.get("bPositive", true))])
	if hero != null:
		var relic = GameData.row("relics", String(hero.get("relic_id", "")))
		if relic != null:
			out.append([TranslationServer.translate("Relíquia: %s") % TranslationServer.translate(String(relic.DisplayName)), TranslationServer.translate(String(relic.get("Description", ""))), true])
	# As melhorias do Treino (#90), uma linha por melhoria com quantas vezes foi escolhida.
	if hero != null:
		var counts := {}
		for upgrade_id in hero.get("upgrades", []):
			counts[upgrade_id] = int(counts.get(upgrade_id, 0)) + 1
		for upgrade_id in counts:
			var upgrade = GameData.row("hero_upgrades", upgrade_id)
			if upgrade != null:
				var title := TranslationServer.translate(String(upgrade.DisplayName))
				if counts[upgrade_id] > 1:
					title = TranslationServer.translate("%s ×%d") % [title, counts[upgrade_id]]
				out.append([title, TranslationServer.translate(String(upgrade.get("Description", ""))), true])
	var learned: Array = Campaign.state.get("researched_skills", []) if Campaign.state is Dictionary else []
	for research in GameData.table("research").values():
		if String(research.get("ClassId", "")) == class_id and learned.has(String(research.get("SkillId", ""))):
			out.append([TranslationServer.translate(String(research.DisplayName)), TranslationServer.translate(String(research.get("Description", ""))), true])
	return out


## Liga a ficha a um controle (os cartões da Preparação): o mouse em cima e o foco do teclado ou do controle abrem,
## sair fecha, e o toque longo abre até soltar (sem apertar o botão). provider: a função que devolve o info.
func attach(control: Control, provider: Callable) -> void:
	control.mouse_entered.connect(func():
		if not touch_mode:
			show_info(provider.call(), control.get_global_rect()))
	control.mouse_exited.connect(func():
		if not touch_mode and _hold.is_empty():
			close())
	control.focus_entered.connect(func():
		if U.using_keys:
			show_info(provider.call(), control.get_global_rect()))
	control.focus_exited.connect(func():
		if _hold.is_empty():
			close())
	control.gui_input.connect(_attached_input.bind(control, provider))


func _attached_input(event: InputEvent, control: Control, provider: Callable) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_hold = {"control": control, "provider": provider, "since": Time.get_ticks_msec()}
		else:
			_hold = {}
			if _long_opened == control:
				# O soltar do toque longo não aperta o botão (o próprio toque solto aperta o BaseButton).
				control.accept_event()
				close()
				_forget_long.call_deferred()
	elif event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION and _long_opened == control:
		# O soltar do toque longo não aperta o botão (não troca o herói na Preparação).
		control.accept_event()
		if not event.pressed:
			_forget_long.call_deferred()


func _forget_long() -> void:
	_long_opened = null


func _process(_delta: float) -> void:
	if _hold.is_empty() or _long_opened != null:
		return
	var control: Control = _hold.control
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		_hold = {}
		return
	if Time.get_ticks_msec() - int(_hold.since) >= int(LONG_PRESS * 1000.0):
		_long_opened = control
		show_info(_hold.provider.call(), control.get_global_rect())


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_mode = true
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		touch_mode = false


## Mostra a ficha ao lado de around (o retângulo, na tela, de quem ela descreve). bottom: até onde ela pode descer (na
## luta, o alto do painel das habilidades, que ela não cobre).
func show_info(new_info: Dictionary, around: Rect2, bottom: float = INF) -> void:
	if new_info.is_empty():
		close()
		return
	var view := get_viewport_rect().size
	var room := minf(view.y - 16.0, bottom) - 16.0
	if new_info != info or not visible:
		info = new_info
		# Muitos estados ou o texto Maior: a ficha encolhe (sem a descrição e as explicações dos passivos, depois sem as
		# dos estados) para caber entre o alto da tela e o painel de baixo.
		for level in 4:
			_build(level)
			reset_size()
			if size.y <= room:
				break
	visible = true
	reset_size()
	var spot := Vector2(around.end.x + GAP, around.position.y)
	if spot.x + size.x > view.x - 16:
		spot.x = around.position.x - GAP - size.x
	spot.x = clampf(spot.x, 16, view.x - size.x - 16)
	spot.y = clampf(spot.y, 16, maxf(16.0, minf(view.y - 16, bottom) - size.y))
	position = spot


func close() -> void:
	visible = false
	info = {}


func showing(id: String = "") -> bool:
	return visible and (id == "" or info.get("id", "") == id)


## level: 0 inteira; 1 sem a descrição e as explicações dos passivos; 2 também sem as explicações dos estados; 3 os nomes
## de cada seção numa linha só (bons e ruins separados, cada um na sua cor).
func _build(level: int = 0) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var title := AHKit.label(String(info.name), "card_name", AHKit.enemy_hp() if info.enemy else AHKit.AMBER, true, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(WIDTH - 48, 0)
	title.name = "Name"
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(title)
	if String(info.get("kind", "")) != "":
		box.add_child(_text(String(info.kind), 17, U.MUTED, "Kind"))
	if String(info.get("description", "")) != "" and level < 1:
		box.add_child(_text(String(info.description), 16, U.TEXT, "Description"))
	# Os números: a vida, o instinto (heróis) e a velocidade.
	var numbers := _text(TranslationServer.translate("Vida %d/%d") % [info.hp, info.max_hp], 19, U.TEXT, "Life")
	box.add_child(numbers)
	var life := AHKit.bar("enemy" if info.enemy else "life", int(info.hp), maxi(1, int(info.max_hp)))
	life.name = "LifeBar"
	life.custom_minimum_size = Vector2(0, 22)
	box.add_child(life)
	if int(info.instinct) >= 0:
		box.add_child(_text(TranslationServer.translate("Instinto %d/200 · em 200, crise") % info.instinct, 17, AHKit.INSTINCT.lightened(0.25), "Instinct"))
	box.add_child(_text(TranslationServer.translate("Velocidade %d · quem é mais rápido age antes na rodada") % info.speed, 17, U.TEXT, "Speed"))
	_section(box, TranslationServer.translate("Efeitos passivos"), info.passives, TranslationServer.translate("Nenhum"), level < 1, level >= 3)
	_section(box, TranslationServer.translate("Estados"), info.states, TranslationServer.translate("Nenhum agora"), level < 2, level >= 3)


func _section(box: VBoxContainer, heading: String, rows: Array, empty: String, tips: bool = true, joined: bool = false) -> void:
	# Os títulos em cinza: o cobre ficava perto do laranja de ruim no daltonismo.
	box.add_child(_text(heading.to_upper(), 14, U.MUTED, "Heading", "bold"))
	if rows.is_empty():
		box.add_child(_text(empty, 16, U.MUTED, "Empty"))
		return
	if joined:
		for good in [true, false]:
			var names: Array = rows.filter(func(r): return r[2] == good).map(func(r): return String(r[0]))
			if not names.is_empty():
				box.add_child(_text(" · ".join(names), 16, U.OK if good else U.DANGER, "Row", "bold"))
		return
	for row in rows:
		# A cor diz bom ou ruim (verde e vermelho, ou azul e laranja no daltonismo); o texto diz o que é.
		var line := _text(String(row[0]), 17, U.OK if row[2] else U.DANGER, "Row", "bold")
		box.add_child(line)
		if tips and String(row[1]) != "":
			box.add_child(_text(String(row[1]), 15, U.MUTED, "RowTip"))


func _text(text: String, size: int, color: Color, node_name: String, kind: String = "body") -> Label:
	var label := AHKit.label_px(text, size, color, kind)
	label.name = node_name
	# O nome repetido (as linhas) vira outro na árvore; a parte fica na meta.
	label.set_meta("part", node_name)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDTH - 48, 0)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
