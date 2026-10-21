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
var _street: Node3D
var _audio: Array[AudioStreamPlayer] = []
var _audio_next := 0


func setup(street: Node3D) -> void:
	_street = street
	art = JSON.parse_string(FileAccess.get_file_as_string(ART_MANIFEST))
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
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
	await _sync_positions(0.6)
	hud.open(session)
	_run()


func slot_position(unit: AHCombat.Unit) -> Vector3:
	var rank := maxi(unit.rank, 1)
	if unit.is_player:
		return Vector3(center_x - FRONT_GAP - (rank - 1) * HERO_GAP, _street.call("_ground_height", HERO_Z), HERO_Z - 0.03 * rank)
	return Vector3(center_x + FRONT_GAP + (rank - 1) * ENEMY_GAP, _street.call("_ground_height", ENEMY_Z), ENEMY_Z - 0.03 * rank)


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
		_:
			await _show_events(events)
	await _settle()


func _play_action(actor: AHCombat.Unit, card: AHSpriteCard, ability_id: String, kind: String, targets: Array, events: Array) -> void:
	var home := card.position
	var toward := 1.0 if actor.is_player else -1.0
	var hostile := targets.any(func(id): return session.state.find_unit(id) != null and session.state.find_unit(id).is_player != actor.is_player)
	var focus_x := home.x
	if not targets.is_empty():
		var target_card: AHSpriteCard = cards.get(targets[0])
		if target_card:
			focus_x = (home.x + target_card.position.x) * 0.5
	_street.set("combat_focus_x", focus_x)
	if actor.is_player:
		var hero := hero_art(actor.hero_id)
		var has_art: bool = hero.get("actions", {}).has(ability_id)
		show_pose(actor, "preparacao", ability_id)
		await _step(card, home + Vector3(0.35 * toward if hostile else 0.0, 0, 0), 0.22)
		await _wait(0.28)
		show_pose(actor, "execucao", ability_id)
		_play_cue(_hero_cue(actor, ability_id))
		if has_art:
			for target_id in (targets if not targets.is_empty() else [actor.id]):
				_spawn_vfx(actor, ability_id, target_id)
	else:
		var action = session.enemy_action(actor.enemy_id, ability_id)
		var pose := "attack1"
		if action != null:
			if action.bIsDefend:
				pose = "defense"
			elif action.TargetType == "Self":
				pose = "support"
		show_pose(actor, pose)
		await _step(card, home + Vector3(0.45 * toward if hostile else 0.0, 0, 0), 0.2)
		_play_enemy_cue(actor, action)
		if action != null:
			_float_text(card, action.DisplayName, Color(1.0, 0.85, 0.7), 0.9)
	await _wait(0.12)
	await _show_events(events)
	await _wait(0.35)
	show_pose(actor, "idle")
	await _step(card, home, 0.25)
	_street.set("combat_focus_x", null)


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
func _show_events(events: Array) -> void:
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
				_shake(card)
			AHCombat.EventType.HEAL:
				_float_text(card, event.text, Color(0.45, 1.0, 0.55), 1.0 + lift, 56)
				card.flash(Color(0.2, 0.9, 0.3))
			AHCombat.EventType.DODGE:
				_float_text(card, event.text, Color(0.85, 0.95, 1.0), 1.0 + lift, 52)
				show_pose(unit, "dodge")
				_play_cue("RobotDodge" if not unit.is_player and _is_machine(unit) else "Dodge")
				var back := card.position + Vector3(-0.4 if unit.is_player else 0.4, 0, 0)
				var tween := create_tween()
				tween.tween_property(card, "position", back, 0.12 / speed)
				tween.tween_property(card, "position", card.position, 0.25 / speed)
			AHCombat.EventType.CRIT:
				_float_text(card, event.text, Color(1.0, 0.85, 0.2), 1.4 + lift, 60)
			AHCombat.EventType.DEATH:
				_float_text(card, event.text, Color(0.9, 0.9, 0.9), 1.3 + lift, 48)
			AHCombat.EventType.CRISIS:
				_float_text(card, event.text, Color(1.0, 0.6, 0.25), 1.6 + lift, 44)
			AHCombat.EventType.BLOCK:
				_float_text(card, event.text, Color(0.55, 0.75, 1.0), 0.9 + lift, 40)
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


func _shake(card: AHSpriteCard) -> void:
	var origin := card.position
	var tween := create_tween()
	for i in 4:
		tween.tween_property(card, "position", origin + Vector3(0.06 * (1 if i % 2 == 0 else -1), 0, 0), 0.04 / speed)
	tween.tween_property(card, "position", origin, 0.04 / speed)


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
	_play_cue("UIClick")
