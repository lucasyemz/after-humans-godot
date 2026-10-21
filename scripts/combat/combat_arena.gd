## A luta na própria rua (port enxuto do AAHCombatArena): a equipe e a patrulha se alinham em 4 posições de cada lado,
## a câmera se aproxima, e cada lance do AHCombatSession vira animação. O herói avança, mostra a preparação e a
## execução da ação (com o efeito no alvo e o som), os atingidos reagem (ferido, esquiva, morte) e os números sobem.
class_name AHCombatArena
extends Node3D

signal finished(result: String)

const ART_MANIFEST := "res://data/presentation/combat_art.json"
const HERO_GAP := 1.2
const ENEMY_GAP := 1.35
const FRONT_GAP := 1.0
const HERO_Z := -0.55
const ENEMY_Z := -0.8
## Habilidades a distância (AHArenaBeat::IsRanged): avançam só um passo, sem ir até o alvo.
const RANGED := ["gato_cacada_precisa", "sapo_carga_voltaica", "sapo_coquetel_corrosivo", "rato_frasco", "rato_poeira",
	"coruja_disparo_perfurante", "coruja_olho_nas_ruinas", "coruja_granada_fumaca", "coruja_recurso_emergencia",
	"sapo_ampola_reparo_vivo", "sapo_antidoto_campo", "esporo_contaminante", "voz_do_eco", "esmagamento_fungico",
	"porteiro_sirene"]
## Tempos do lance (ACTION_TIMING da web, como na Unreal): preparo, avanço, impacto e volta.
const PREPARE_SECONDS := 0.2
const ENTER_SECONDS := 0.18
const IMPACT_SECONDS := 0.75
const RETURN_SECONDS := 0.22
## Na aproximação a câmera vai 60% do caminho até o golpe e fecha para 86% da distância.
const CLOSE_FOCUS := 0.6
const CLOSE_DISTANCE := 0.86
## Folga de cada borda da tela ao enquadrar a luta inteira.
const FRAME_MARGIN := 0.84
## Quem age passa na frente dos outros (BringAttackerToFront): um pouco mais perto da câmera.
const FRONT_LIFT := 0.35
## Sons das ações dos heróis: classe -> prefixo da deixa (AHCombatAudioRules).
const HERO_CUES := {"cao": "BentoAction", "gato": "NickAction", "sapo": "IrisAction", "coruja": "VesperaAction"}

var session: AHCombatSession
var hud: AHCombatHud
var art := {}
## Joga os dois lados sozinho (QA e captura). speed acelera as esperas.
var auto_battle := false
var speed := 1.0
var center_x := 0.0
var active := false
var cards := {}
## Câmera da luta: o centro e a distância que enquadram todos, e o foco do golpe da vez (close_t 0..1 vai até ele).
var view_x := 0.0
var view_distance := 14.0
var focus_x := 0.0
var close_t := 0.0
var _street: Node3D
var _audio: Array[AudioStreamPlayer] = []
var _audio_next := 0


func setup(street: Node3D) -> void:
	_street = street
	art = JSON.parse_string(FileAccess.get_file_as_string(ART_MANIFEST))
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_audio.append(player)
	hud = AHCombatHud.new()
	hud.arena = self
	var layer := CanvasLayer.new()
	layer.layer = 3
	layer.add_child(hud)
	add_child(layer)
	hud.visible = false


# ---------------------------------------------------------------- arte

func hero_art(hero_id: String) -> Dictionary:
	return art.heroes.get(hero_id, {})


func enemy_art(enemy_id: String) -> Dictionary:
	return art.enemies.get(enemy_id, {})


func icon_path(ability_id: String) -> String:
	return art.icons.get(ability_id, "")


## Pose de um personagem pelo nome: idle, hurt, death, attack1, defense, dodge, support ou uma fase de ação.
func show_pose(unit: AHCombat.Unit, pose: String, ability_id: String = "") -> void:
	var card: AHSpriteCard = cards.get(unit.id)
	if card == null:
		return
	if unit.is_player:
		var hero := hero_art(unit.hero_id)
		if ability_id != "" and hero.get("actions", {}).has(ability_id) and hero.actions[ability_id].has(pose):
			card.show_art(hero.actions[ability_id][pose])
		elif hero.get("reactions", {}).has(pose):
			card.show_art(hero.reactions[pose])
		else:
			card.show_art(hero.idle)
	else:
		var enemy := enemy_art(unit.enemy_id)
		card.show_art(enemy.poses[pose] if enemy.get("poses", {}).has(pose) else enemy.idle)


## A pose de descanso pelo estado: parado, caído no Último Fôlego ou morto.
func rest_pose(unit: AHCombat.Unit) -> void:
	var card: AHSpriteCard = cards.get(unit.id)
	if card == null:
		return
	if unit.hp > 0:
		show_pose(unit, "idle")
		card.set_tint(Color.WHITE)
	else:
		show_pose(unit, "death")
		# Morto de vez fica cinza; no Último Fôlego, só caído.
		card.set_tint(Color(0.55, 0.55, 0.6) if not unit.deaths_door else Color.WHITE)


# ---------------------------------------------------------------- início e fim

## Começa a luta: hero_cards e enemy_cards já estão na cena (na ordem da formação). enemies: ids ou os inimigos já
## montados pelo corredor. opening: a equipe age primeiro (chegou sem ser vista).
func start(heroes: Array, hero_cards: Array, enemies: Array, enemy_cards: Array, at_x: float, opening: bool = false, seed_value: int = -1) -> void:
	session = AHCombatSession.create(heroes, enemies, opening, seed_value)
	# Velocidade da batalha das opções (1x ou 2x); a QA acelera mais e fica com a dela.
	if speed <= 2.0:
		speed = float(clampi(int(Campaign.state.get("settings", {}).get("battle_speed", 1)), 1, 2))
	center_x = at_x
	cards.clear()
	for index in session.state.player_team.size():
		cards[session.state.player_team[index].id] = hero_cards[index]
	for index in session.state.enemy_team.size():
		cards[session.state.enemy_team[index].id] = enemy_cards[index]
	active = true
	for unit in session.units():
		rest_pose(unit)
		cards[unit.id].set_facing(1.0 if unit.is_player else -1.0)
	_frame_arena()
	await _sync_positions(0.6)
	hud.open(session)
	_run()


## Enquadra a luta inteira (como a Unreal): o meio de quem luta e a distância em que o lado mais longo, mais meio
## personagem, cabe na tela com folga nas bordas.
func _frame_arena() -> void:
	var left := center_x - FRONT_GAP * 0.5
	var right := center_x + FRONT_GAP * 0.5
	var sprite_half := 0.6
	for unit in session.units():
		if unit.rank <= 0:
			continue
		var x := slot_position(unit).x
		left = minf(left, x)
		right = maxf(right, x)
		sprite_half = maxf(sprite_half, minf(cards[unit.id].body_height * 0.4, 1.3))
	view_x = (left + right) * 0.5
	focus_x = view_x
	close_t = 0.0
	var camera := get_viewport().get_camera_3d()
	var half_fov := deg_to_rad((camera.fov if camera else 26.0) * 0.5)
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var fit := ((right - left) * 0.5 + sprite_half) / (tan(half_fov) * aspect * FRAME_MARGIN)
	view_distance = maxf(fit, 10.0)


## O que a câmera da rua usa durante a luta: x e distância, já com a aproximação do golpe.
func camera_view() -> Vector2:
	return Vector2(lerpf(view_x, focus_x, CLOSE_FOCUS * close_t), view_distance * lerpf(1.0, CLOSE_DISTANCE, close_t))


func slot_position(unit: AHCombat.Unit) -> Vector3:
	var rank := maxi(unit.rank, 1)
	# Na rua a luta fica na calçada (HERO_Z, ENEMY_Z); nos cenários, na faixa da zona (um pouco atrás do meio dela).
	var hero_z: float = HERO_Z
	var enemy_z: float = ENEMY_Z
	if _street.get("scenario") != null:
		hero_z = _street.lane_z - 0.3
		enemy_z = hero_z - 0.25
	if unit.is_player:
		return Vector3(center_x - FRONT_GAP - (rank - 1) * HERO_GAP, _street.call("_ground_height", hero_z), hero_z - 0.03 * rank)
	return Vector3(center_x + FRONT_GAP + (rank - 1) * ENEMY_GAP, _street.call("_ground_height", enemy_z), enemy_z - 0.03 * rank)


## Leva cada unidade de pé para a posição dela (depois de trocas, empurrões e mortes).
func _sync_positions(seconds: float) -> void:
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	var any := false
	for unit in session.units():
		if unit.rank <= 0:
			continue
		var card: AHSpriteCard = cards[unit.id]
		var target := slot_position(unit)
		if card.position.distance_to(target) > 0.01:
			tween.tween_property(card, "position", target, seconds / speed)
			any = true
	if any:
		await tween.finished
	else:
		tween.kill()


func _run() -> void:
	while not session.is_over():
		hud.refresh()
		if session.is_player_turn():
			var start := session.begin_player_turn()
			if not start.events.is_empty():
				await _play_beat(start)
			if not start.can_act or session.is_over():
				continue
			var actor := session.current_actor()
			var beat: Dictionary
			if auto_battle:
				hud.show_waiting("%s age" % actor.display_name)
				await _wait(0.25)
				var auto := session.engine.play_auto_turn(actor.id)
				beat = {"source_id": actor.id, "kind": "ability" if auto.used_ability_id != "" else "defend",
					"ability_id": auto.used_ability_id, "events": auto.events, "ok": auto.success, "error": auto.error}
			else:
				var command: Dictionary = await hud.ask_command(actor.id)
				# Mochila: ação livre; o mesmo herói continua decidindo (sem começar a vez de novo).
				while command.kind == "item":
					var used := session.use_item(Campaign.state, command.item)
					if used.ok:
						Sound.play("res://audio/ui/confirm.ogg")
						await _play_beat(used)
						hud.refresh()
					else:
						Sound.play("res://audio/ui/deny.ogg")
					command = await hud.ask_command(actor.id, used.text if used.ok else used.error)
				beat = _execute(actor.id, command)
				if not beat.ok:
					hud.show_message(beat.error)
					continue
			await _play_beat(beat)
		else:
			var enemy := session.current_actor()
			hud.show_waiting("Vez de %s" % (enemy.display_name if enemy else "inimigo"))
			await _wait(0.45)
			await _play_beat(session.enemy_turn())
	hud.refresh()
	var result := session.result()
	session.write_back(Campaign.state)
	await hud.show_result(result, auto_battle)
	hud.close()
	active = false
	finished.emit(result)


func _execute(actor_id: String, command: Dictionary) -> Dictionary:
	match command.kind:
		"ability":
			return session.use_ability(actor_id, command.ability_id, command.rank)
		"move":
			return session.move(actor_id, command.rank)
		"flee":
			return session.flee(actor_id)
	return session.defend(actor_id)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds / speed).timeout


# ---------------------------------------------------------------- lances

func _play_beat(beat: Dictionary) -> void:
	var actor := session.state.find_unit(beat.source_id)
	var card: AHSpriteCard = cards.get(beat.source_id)
	var events: Array = beat.events
	var targets := _event_targets(events)
	match beat.kind:
		"ability", "enemy":
			if actor == null or card == null:
				await _show_events(events)
			else:
				await _play_action(actor, card, beat.ability_id, beat.kind, targets, events)
		"defend":
			if card:
				if actor and not actor.is_player:
					show_pose(actor, "defense")
				_float_text(card, "+1 Bloqueio", Color(0.55, 0.75, 1.0))
				await _wait(0.6)
		"flee":
			if card:
				_float_text(card, "Fuga!" if beat.get("escaped", false) else "Fuga falhou", Color(1, 0.9, 0.6))
				await _wait(0.7)
		"item":
			# A pose de usar item (ItemUse) enquanto a cura aparece.
			if actor and card:
				show_pose(actor, "item")
			await _show_events(events)
			await _wait(0.5)
		_:
			await _show_events(events)
	await _settle()
	# Crise de instinto (como na Unreal): um lance só dela para cada um que entrou em crise e segue de pé.
	if beat.kind != "crisis":
		for event in events:
			if event.type != AHCombat.EventType.CRISIS:
				continue
			var unit := session.state.find_unit(event.target_unit_id)
			if unit != null and (unit.hp > 0 or unit.deaths_door):
				await _play_crisis(unit, event.text)


## O personagem sozinho, a câmera perto: superação na pose de apoio, colapso na de dano, e a faixa no HUD (2,1 s).
func _play_crisis(unit: AHCombat.Unit, text: String) -> void:
	var card: AHSpriteCard = cards.get(unit.id)
	if card == null:
		return
	var breakthrough := unit.crisis_outcome == AHCombat.Crisis.BREAKTHROUGH
	show_pose(unit, "support" if breakthrough else "hurt")
	card.flash(Color(1.0, 0.85, 0.35) if breakthrough else Color(0.9, 0.2, 0.25), 0.6)
	hud.show_crisis(text, breakthrough)
	focus_x = card.position.x
	var tween := create_tween()
	tween.tween_property(self, "close_t", 1.0, 0.3 / speed)
	await _wait(1.65)
	tween = create_tween()
	tween.tween_property(self, "close_t", 0.0, 0.25 / speed)
	await _wait(0.4)
	hud.hide_crisis()
	rest_pose(unit)


func _play_action(actor: AHCombat.Unit, card: AHSpriteCard, ability_id: String, kind: String, targets: Array, events: Array) -> void:
	var home := card.position
	var hostile := targets.any(func(id): return session.state.find_unit(id) != null and session.state.find_unit(id).is_player != actor.is_player)
	var action = null if actor.is_player else session.enemy_action(actor.enemy_id, ability_id)
	var hero_action: Dictionary = hero_art(actor.hero_id).get("actions", {}).get(ability_id, {}) if actor.is_player else {}
	var support: bool = not hostile or (action != null and (action.bIsDefend or action.TargetType == "Self"))
	# Preparo: a pose de quem age, já na frente dos outros.
	if actor.is_player:
		show_pose(actor, "preparacao", ability_id)
	elif action != null and action.bIsDefend:
		show_pose(actor, "defense")
	elif action != null and action.TargetType == "Self":
		show_pose(actor, "support")
	else:
		show_pose(actor, "attack1")
	card.position.z = home.z + FRONT_LIFT
	var struck := _nearest_struck(actor, card, events)
	var advance := 0.0 if support else _advance(actor, card, ability_id, hero_action, struck)
	var contact := home.x + advance
	focus_x = (contact + struck.position.x) * 0.5 if struck != null else home.x
	await _wait(PREPARE_SECONDS)
	# Avanço até o contato (corpo a corpo) ou um passo (a distância); a câmera chega junto.
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card, "position:x", contact, ENTER_SECONDS / speed)
	tween.tween_property(self, "close_t", 1.0, ENTER_SECONDS / speed)
	await tween.finished
	# Impacto: a execução, o efeito no alvo, o som e as reações.
	if actor.is_player:
		show_pose(actor, "execucao", ability_id)
		_play_cue(_hero_cue(actor, ability_id))
		if not hero_action.is_empty():
			for target_id in (targets if not targets.is_empty() else [actor.id]):
				_spawn_vfx(actor, ability_id, target_id)
	else:
		_play_enemy_cue(actor, action)
		if action != null:
			_float_text(card, action.DisplayName, Color(1.0, 0.85, 0.7), 0.9)
	var impact_start := Time.get_ticks_msec()
	var life := float(hero_action.get("vfx", {}).get("life_seconds", 0.0)) + 0.05
	await _show_events(events, contact)
	var held := (Time.get_ticks_msec() - impact_start) * 0.001
	var impact := maxf(IMPACT_SECONDS * (0.8 if support else 1.0), life) / speed
	if held < impact:
		await get_tree().create_timer(impact - held).timeout
	# Volta: todos ao descanso e a câmera abre de novo.
	show_pose(actor, "idle")
	var back := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	back.tween_property(card, "position", home, RETURN_SECONDS / speed)
	back.tween_property(self, "close_t", 0.0, RETURN_SECONDS / speed)
	await back.finished


## Quanto quem ataca anda (como a Unreal): até encostar no inimigo atingido mais perto; os inimigos andam 40% do
## caminho; a distância, só um passo. Ações com contato na mão param com a mão no alvo.
func _advance(actor: AHCombat.Unit, card: AHSpriteCard, ability_id: String, hero_action: Dictionary, struck: AHSpriteCard) -> float:
	if struck == null:
		return 0.0
	var gap := struck.position.x - card.position.x
	var direction := signf(gap)
	var available := maxf(0.0, absf(gap) - ((card.body_height + struck.body_height) * 0.3 + 0.3))
	if RANGED.has(ability_id) or ability_id.contains("tiro") or ability_id.contains("descarga"):
		return direction * minf(available, card.body_height * 0.16)
	if not actor.is_player:
		return direction * available * 0.4
	var execute: Dictionary = hero_action.get("execucao", {})
	if hero_action.get("vfx", {}).get("anchor_on_hand", false) and execute.has("contact_pixels"):
		var reach := (float(execute.contact_pixels[0]) - float(execute.anchor[0])) * card.body_height / float(execute.body_reference_pixels)
		return direction * maxf(0.0, absf(gap) - reach - struck.body_height * 0.15)
	return direction * available


## O inimigo atingido (ferido, esquiva, bloqueio ou morte) mais perto de quem age.
func _nearest_struck(actor: AHCombat.Unit, card: AHSpriteCard, events: Array) -> AHSpriteCard:
	var nearest: AHSpriteCard = null
	for event in events:
		var unit := session.state.find_unit(event.target_unit_id)
		var other: AHSpriteCard = cards.get(event.target_unit_id)
		if unit == null or other == null or unit.is_player == actor.is_player or event.ability_id != "":
			continue
		if not [AHCombat.EventType.DAMAGE, AHCombat.EventType.DODGE, AHCombat.EventType.BLOCK, AHCombat.EventType.DEATH].has(event.type):
			continue
		if nearest == null or absf(other.position.x - card.position.x) < absf(nearest.position.x - card.position.x):
			nearest = other
	return nearest


func _step(card: AHSpriteCard, to: Vector3, seconds: float) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position", to, seconds / speed)
	await tween.finished


func _event_targets(events: Array) -> Array:
	var ids: Array = []
	for event in events:
		if event.target_unit_id != "" and not ids.has(event.target_unit_id) and event.ability_id == "":
			ids.append(event.target_unit_id)
	return ids


## Números e reações de cada evento, no alvo.
func _show_events(events: Array, contact_x = null) -> void:
	var stagger := {}
	for event in events:
		var unit := session.state.find_unit(event.target_unit_id)
		var card: AHSpriteCard = cards.get(event.target_unit_id)
		if unit == null or card == null or event.ability_id != "":
			continue
		var lift: float = stagger.get(unit.id, 0.0)
		stagger[unit.id] = lift + 0.32
		match event.type:
			AHCombat.EventType.DAMAGE:
				_float_text(card, event.text, Color(1.0, 0.35, 0.3), 1.0 + lift, 64)
				card.flash(Color(1.0, 0.15, 0.1))
				if unit.hp > 0:
					show_pose(unit, "hurt")
				_recoil(card, contact_x, 0.11)
			AHCombat.EventType.HEAL:
				_float_text(card, event.text, Color(0.45, 1.0, 0.55), 1.0 + lift, 56)
				card.flash(Color(0.2, 0.9, 0.3))
			AHCombat.EventType.DODGE:
				_float_text(card, event.text, Color(0.85, 0.95, 1.0), 1.0 + lift, 52)
				show_pose(unit, "dodge")
				_play_cue("RobotDodge" if not unit.is_player and _is_machine(unit) else "Dodge")
				_recoil(card, contact_x, 0.2)
			AHCombat.EventType.CRIT:
				_float_text(card, event.text, Color(1.0, 0.85, 0.2), 1.4 + lift, 60)
			AHCombat.EventType.DEATH:
				_float_text(card, event.text, Color(0.9, 0.9, 0.9), 1.3 + lift, 48)
			AHCombat.EventType.CRISIS:
				# A crise tem o lance próprio (_play_crisis); quem caiu na hora ainda mostra o texto aqui.
				if unit.hp <= 0 and not unit.deaths_door:
					_float_text(card, event.text, Color(1.0, 0.6, 0.25), 1.6 + lift, 44)
			AHCombat.EventType.BLOCK:
				_float_text(card, event.text, Color(0.55, 0.75, 1.0), 0.9 + lift, 40)
				_recoil(card, contact_x, 0.035)
			AHCombat.EventType.INSTINCT:
				_float_text(card, event.text, Color(0.8, 0.6, 1.0), 0.9 + lift, 40)
			_:
				_float_text(card, event.text, Color(0.95, 0.92, 0.85), 0.9 + lift, 38)
	if not events.is_empty():
		hud.refresh()
		await _wait(0.55)


## Depois do lance: mortos caem (inimigos somem), todos voltam à pose de descanso e às posições.
func _settle() -> void:
	for unit in session.units():
		var card: AHSpriteCard = cards.get(unit.id)
		if card == null or not card.visible:
			continue
		rest_pose(unit)
		if not unit.is_player and unit.hp <= 0:
			var tween := create_tween()
			tween.tween_interval(0.5 / speed)
			tween.tween_property(card, "position:y", card.position.y - 0.25, 0.4 / speed)
			tween.tween_callback(card.hide)
	await _sync_positions(0.35)
	hud.refresh()


## Empurrão para longe de quem bateu (esquiva mais, bloqueio quase nada); o _settle traz de volta ao posto.
func _recoil(card: AHSpriteCard, contact_x, strength: float) -> void:
	var away := 0.0
	if contact_x != null:
		away = signf(card.position.x - float(contact_x))
	if away == 0.0:
		away = 1.0 if card.position.x > center_x else -1.0
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position:x", card.position.x + away * card.body_height * strength, 0.12 / speed)


func _spawn_vfx(actor: AHCombat.Unit, ability_id: String, target_id: String) -> void:
	var vfx: Dictionary = hero_art(actor.hero_id).actions[ability_id].vfx
	var target_card: AHSpriteCard = cards.get(target_id)
	if target_card == null:
		return
	var effect := AHSpriteCard.new()
	effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect.set_blended(true)
	# A imagem inteira do efeito ocupa target_height_in_bodies da altura do alvo, centrada no peito dele.
	effect.body_height = target_card.body_height * float(vfx.get("target_height_in_bodies", 0.64))
	add_child(effect)
	var art_entry: Dictionary = vfx.duplicate()
	art_entry.anchor = [float(vfx.canvas[0]) * 0.5, float(vfx.canvas[1]) * 0.5]
	art_entry.body_reference_pixels = float(vfx.canvas[1])
	effect.show_art(art_entry)
	effect.set_facing(1.0 if actor.is_player else -1.0)
	effect.global_position = target_card.global_position + Vector3(0, target_card.body_height * 0.5, 0.25)
	effect.set_tint(Color(1, 1, 1, float(vfx.get("opacity", 0.8))))
	var life := float(vfx.get("life_seconds", 0.6)) / speed
	var tween := create_tween()
	tween.tween_property(effect, "scale", Vector3.ONE * 1.12, life)
	tween.tween_callback(effect.queue_free)


func _float_text(card: AHSpriteCard, text: String, color: Color, lift: float = 1.0, size: int = 44) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.outline_modulate = Color(0.05, 0.03, 0.03, 0.9)
	label.font_size = size
	label.outline_size = 14
	label.pixel_size = 0.0045
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	add_child(label)
	label.global_position = card.global_position + Vector3(0, card.head_height() + 0.55 + lift * 0.25, 0.4)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.55, 1.1 / speed)
	tween.tween_property(label, "modulate:a", 0.0, 1.1 / speed).set_delay(0.5 / speed)
	tween.chain().tween_callback(label.queue_free)


func _is_machine(unit: AHCombat.Unit) -> bool:
	return session.engine.is_machine(unit)


# ---------------------------------------------------------------- sons

func _hero_cue(actor: AHCombat.Unit, ability_id: String) -> String:
	var prefix: String = HERO_CUES.get(actor.class_id, "")
	var hero_class = session.data.classes.get(actor.class_id)
	if prefix == "" or hero_class == null:
		return ""
	var index: int = hero_class.AbilityIds.find(ability_id)
	return "%s%d" % [prefix, index + 1] if index >= 0 else ""


func _play_enemy_cue(actor: AHCombat.Unit, action) -> void:
	if action == null or not _is_machine(actor):
		return
	if action.TargetType == "Self":
		if action.HealRange.Max > 0:
			_play_cue("RobotHeal")
	elif action.DamageRange.Max > 0:
		_play_cue("RobotPunch")


func _play_cue(cue: String) -> void:
	var path: String = art.audio.get(cue, "")
	if path == "" or speed > 2.0:
		return
	var player := _audio[_audio_next]
	_audio_next = (_audio_next + 1) % _audio.size()
	player.stream = load(path)
	player.play()


func play_click() -> void:
	Sound.click()
