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
## Folga entre dois heróis vizinhos mais largos que a posição (o escudo do Tatu, #187): o espaço entre eles cresce até
## as larguras medidas mais esta folga.
const WIDE_ROOM := 0.1
## Meia largura de quem não tem medida e da posição vazia: a que, com a folga, dá o espaço de sempre (HERO_GAP).
const NARROW_HALF := (HERO_GAP - WIDE_ROOM) * 0.5
## O menor encolhimento dos espaços da fila num lugar apertado (abaixo disso os personagens se sobrepõem demais).
const MIN_GAP_SCALE := 0.6
## A fila vai até a posição 4 dos dois lados (Mover, Recuar e o empurrão param nela).
const RANKS := 4
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
## Impacto do acerto (#33): a pausa curta (o tempo quase para; mais longa no crítico), o tremor da câmera em pixels da
## tela de 1080 (pelo dano em relação à vida do alvo; o crítico treme mais), quanto ele dura e o clarão branco no alvo
## antes da cor do dano. O número do crítico sai maior. Tudo se divide pela velocidade da luta; o tremor e o clarão
## saem com "Reduzir efeitos" e o modo automático (QA e captura) pula a pausa.
const HITSTOP_SECONDS := 0.07
const HITSTOP_CRIT_SECONDS := 0.09
const HITSTOP_TIME_SCALE := 0.03
const SHAKE_MIN_PIXELS := 4.0
const SHAKE_MAX_PIXELS := 14.0
const SHAKE_CRIT := 1.4
const SHAKE_SECONDS := 0.3
const FLASH_SECONDS := 0.07
const CRIT_TEXT_SIZE := 88
## A música abaixa (dB) na crise de instinto e no golpe crítico (#36).
const CRISIS_DUCK_DB := 9.0
const CRIT_DUCK_DB := 5.0
## Sons das ações dos heróis: classe -> prefixo da deixa (AHCombatAudioRules).
const HERO_CUES := {"cao": "BentoAction", "gato": "NickAction", "sapo": "IrisAction", "coruja": "VesperaAction"}

var session: AHCombatSession
var hud: AHCombatHud
var art := {}
## Joga os dois lados sozinho (QA e captura). speed acelera as esperas.
var auto_battle := false
var speed := 1.0
var center_x := 0.0
## O quanto os espaços da fila encolhem para a luta caber no lugar (#52): 1 = os de sempre.
var gap_scale := 1.0
## Meia largura do corpo de cada herói, em metros (pelo parado, com a altura dele).
var _half_widths := {}
var active := false
## A luta é a do guardião do trecho (a ficha diz, #89; as estrelas dele ficam no save, #91).
var boss_fight := false
var cards := {}
## O anel de quem age, no chão sob os pés (#60).
var ring: AHActorRing
## Câmera da luta: o centro e a distância que enquadram todos, e o foco do golpe da vez (close_t 0..1 vai até ele).
var view_x := 0.0
var view_distance := 14.0
var focus_x := 0.0
var close_t := 0.0
var _street: Node3D
var _audio: Array[AudioStreamPlayer] = []
var _audio_next := 0
## O tremor da câmera: a força em pixels, o tempo que falta (s, já na velocidade da luta) e a fase do balanço.
var _shake_pixels := 0.0
var _shake_left := 0.0
var _shake_time := 0.0
## A escala de tempo de antes da pausa do acerto (para devolver), ou -1 fora dela.
var _hitstop_scale := -1.0
## Os efeitos de impacto e os loops de estado no alvo (#84).
var effects := AHCombatEffects.new()


func _process(delta: float) -> void:
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta * speed)
		_shake_time += delta * speed
	# Com a luta decidida (a tela do resultado), os loops não voltam: o _run já os tirou.
	if active and session != null and not session.is_over():
		_sync_states()


## Os loops dos estados (sangramento, veneno, atordoado, marcado) seguem os estados de cada um; fora da luta, nenhum.
func _sync_states(clear: bool = false) -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var reduced := reduced_effects()
	for unit in session.units():
		var card: AHSpriteCard = cards.get(unit.id)
		if card != null:
			effects.sync_states(card, {} if clear else AHCombatEffects.states_of(unit, _is_machine(unit)), camera, reduced)


func _exit_tree() -> void:
	_end_hitstop()


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
	return art_entry(art.heroes, hero_id)


## A arte de um herói no manifesto. O recruta (hero_cao_4) usa a variação da classe guardada no save (art_variant, #32):
## a pose parada e o retrato dela, as poses próprias quando a variação tem (o Guaxinim e o Tatu, #187) e o efeito visual
## das habilidades do fundador. Sem variação (saves antigos sem arte, classe sem recruta desenhado), a do fundador; a
## classe sem fundador (o rato e o tatu) usa o recruta desenhado dela.
## variant: a do herói, se quem chama já tem a entrada; "" procura na campanha (Campaign.hero). O fundador vem na skin
## dele (AHSkins).
static func art_entry(heroes: Dictionary, hero_id: String, variant: String = "") -> Dictionary:
	# O fundador na skin que ele veste (#138): o único lugar que decide a arte da luta, da rua, da Sala e dos rostos.
	if heroes.has(hero_id):
		return AHSkins.dress(heroes[hero_id], AHSkins.skin_of(hero_id))
	var founder := {}
	var parts := hero_id.split("_")
	if parts.size() > 2 and parts[0] == "hero":
		for id in heroes:
			if String(id).begins_with("hero_%s_" % parts[1]):
				founder = heroes[id]
				break
	if variant == "":
		var entry = Campaign.hero(hero_id)
		variant = String(entry.get("art_variant", "")) if entry != null else ""
	# Classe sem fundador (o Guaxinim e o Tatu, #187): a arte é a do recruta dela, mesmo sem variação guardada.
	if founder.is_empty() and parts.size() > 2 and parts[0] == "hero":
		if variant == "":
			var variants := AHStationRules.art_variants(parts[1])
			variant = variants[0] if not variants.is_empty() else ""
		return {} if variant == "" else _variant_entry(founder, variant)
	if variant == "" or founder.is_empty():
		return founder
	return _variant_entry(founder, variant)


static var _variants := {}


static func _variant_entry(founder: Dictionary, variant: String) -> Dictionary:
	var key := "%s|%s" % [founder.get("name", ""), variant]
	if _variants.has(key):
		return _variants[key]
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(ART_MANIFEST))
	var art: Dictionary = _manifest.get("recruits", {}).get(variant, {})
	if art.is_empty():
		return founder
	var actions := {}
	for ability_id in founder.get("actions", {}):
		var action: Dictionary = founder.actions[ability_id]
		if action.has("vfx"):
			actions[ability_id] = {"vfx": action.vfx}
	# As poses próprias do recruta, quando ele tem (o Guaxinim e o Tatu, #187: um golpe por habilidade e as reações).
	for ability_id in art.get("actions", {}):
		actions[ability_id] = actions.get(ability_id, {}).merged(art.actions[ability_id])
	var out := {"name": variant, "variant": variant, "idle": art.idle, "actions": actions, "reactions": art.get("reactions", {})}
	_variants[key] = out
	return out


static var _manifest := {}


## A arte de um herói fora da luta (os rostos do HUD da exploração), lida uma vez do manifesto.
static func hero_art_of(hero_id: String, variant: String = "") -> Dictionary:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(ART_MANIFEST))
	return art_entry(_manifest.heroes, hero_id, variant)


## A entrada do fundador no manifesto, sem skin (a base que a Sala veste em cada aba da Roupa, #138).
static func founder_art_of(hero_id: String) -> Dictionary:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(ART_MANIFEST))
	return _manifest.get("heroes", {}).get(hero_id, {})


## A arte de um inimigo fora da luta (o rosto no Mapa da Rede, #87), do mesmo manifesto.
static func enemy_art_of(sprite_key: String) -> Dictionary:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(ART_MANIFEST))
	return _manifest.get("enemies", {}).get(sprite_key, {})


## A pose do inimigo ao agir: defesa ao defender, apoio na ação em si mesmo e no golpe sem dano num herói (a Buzina do
## Pipoco, a Risada do Recreador) quando ele tem a pose de apoio; senão, o ataque.
static func enemy_action_pose(action, art: Dictionary) -> String:
	if action == null:
		return "attack1"
	if action.get("bIsDefend", false):
		return "defense"
	if action.get("TargetType", "") == "Self":
		return "support"
	if int(action.get("DamageRange", {}).get("Max", 0)) <= 0 and art.get("poses", {}).has("support"):
		return "support"
	return "attack1"


func enemy_art(enemy_id: String) -> Dictionary:
	return art.enemies.get(enemy_id, {})


func icon_path(ability_id: String) -> String:
	return art.icons.get(art_id(ability_id), "")


## A habilidade cuja arte (o ícone, as poses, o efeito e o som) esta usa: as dos recrutas (rec_*, #215) não têm arte
## própria e usam a da parecida (ArtOf em data/abilities.json); as outras, a delas.
static func art_id(ability_id: String) -> String:
	var row = GameData.row("abilities", ability_id)
	return String(row.get("ArtOf", ability_id)) if row != null else ability_id


## O ícone de uma habilidade fora da luta (a Sala dos Personagens, #60).
static func icon_of(ability_id: String) -> String:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(ART_MANIFEST))
	return _manifest.get("icons", {}).get(art_id(ability_id), "")


## Pose de um personagem pelo nome: idle, hurt, death, attack1, defense, dodge, support ou uma fase de ação.
func show_pose(unit: AHCombat.Unit, pose: String, ability_id: String = "") -> void:
	var card: AHSpriteCard = cards.get(unit.id)
	if card == null:
		return
	if unit.is_player:
		var hero := hero_art(unit.hero_id)
		var key := art_id(ability_id) if ability_id != "" else ""
		if key != "" and hero.get("actions", {}).has(key) and hero.actions[key].has(pose):
			card.show_art(hero.actions[key][pose])
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
		# Morto de vez fica cinza; no Último Fôlego, só caído. Quem não tem a pose de caído (os recrutas) fica de pé,
		# então o Último Fôlego escurece um pouco o desenho para não parecer inteiro.
		var has_fallen: bool = not unit.is_player or hero_art(unit.hero_id).get("reactions", {}).has("death")
		if not unit.deaths_door:
			card.set_tint(Color(0.55, 0.55, 0.6))
		else:
			card.set_tint(Color.WHITE if has_fallen else Color(0.72, 0.62, 0.62))


# ---------------------------------------------------------------- início e fim

## Começa a luta: hero_cards e enemy_cards já estão na cena (na ordem da formação). enemies: ids ou os inimigos já
## montados pelo corredor. opening: a equipe age primeiro (chegou sem ser vista).
func start(heroes: Array, hero_cards: Array, enemies: Array, enemy_cards: Array, at_x: float, opening: bool = false, seed_value: int = -1) -> void:
	# Os efeitos de fase dos eventos (#78): valem nesta luta; o de uma luta só (Exposto) se gasta aqui.
	session = AHCombatSession.create(heroes, enemies, opening, seed_value, 80, AHJourneyRules.phase_effects(Campaign.state))
	AHJourneyRules.spend_fight_effects(Campaign.state)
	session.use_expedition(Campaign.state)
	# No tutorial (#144) os inimigos não derrubam ninguém, e os estados sempre pegam.
	if AHTutorial.is_tutorial(Campaign.state):
		AHTutorial.prepare_fight(session.context)
	Tips.show_tip("combat")
	# Velocidade da batalha das opções (1x ou 2x); a QA acelera mais e fica com a dela.
	if speed <= 2.0:
		speed = float(clampi(int(Campaign.state.get("settings", {}).get("battle_speed", 1)), 1, 2))
		# A barra de Admin (#130) pode pôr a luta em 4x.
		if Admin.battle_speed > 0.0 and Admin.allowed():
			speed = Admin.battle_speed
	cards.clear()
	_half_widths.clear()
	var wide := 0.0
	for index in session.state.player_team.size():
		var unit: AHCombat.Unit = session.state.player_team[index]
		cards[unit.id] = hero_cards[index]
		_half_widths[unit.id] = half_width(hero_cards[index])
		wide += maxf(0.0, _half_widths[unit.id] - NARROW_HALF)
	center_x = at_x
	gap_scale = 1.0
	if _street != null and _street.has_method("combat_room"):
		var room: Dictionary = _street.combat_room(at_x)
		var placed := fit(at_x, room.bounds, room.obstacles, wide * 2.0)
		center_x = placed.x
		gap_scale = placed.y
	for index in session.state.enemy_team.size():
		cards[session.state.enemy_team[index].id] = enemy_cards[index]
	# Os inimigos ganham a silhueta enquanto a luta dura (#51); a equipe já tem a dela.
	var occlusion = _street.get("occlusion") if _street != null else null
	if occlusion != null:
		for card in enemy_cards:
			occlusion.track_enemy(card)
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


## Onde a luta cabe (#52): a fila dos heróis à esquerda do centro e a dos inimigos à direita, inteiras dentro de
## bounds (x mínimo e máximo, já com a folga da borda) e fora dos obstáculos (faixas em x [início, fim] que cruzam a
## linha da luta). Reserva as RANKS posições de cada lado, não só as ocupadas: quem recua para a posição vazia e o
## chefe de duas posições (que empurra os outros para a 3 e a 4) continuam dentro. Entre os vãos onde a fila cabe,
## fica no que deixa o centro mais perto de at_x; se não cabe em nenhum, no maior, com os espaços encolhidos até
## MIN_GAP_SCALE. Devolve (centro, escala dos espaços).
static func fit(at_x: float, bounds: Vector2, obstacles: Array, hero_extra: float = 0.0) -> Vector2:
	var left: float = FRONT_GAP + (RANKS - 1) * HERO_GAP + hero_extra
	var right: float = FRONT_GAP + (RANKS - 1) * ENEMY_GAP
	var cuts: Array = obstacles.duplicate()
	cuts.sort_custom(func(a, b): return a.x < b.x)
	var spans: Array = []
	var start := bounds.x
	for cut in cuts:
		if cut.y <= start or cut.x >= bounds.y:
			continue
		if cut.x > start:
			spans.append(Vector2(start, cut.x))
		start = maxf(start, cut.y)
	if start < bounds.y:
		spans.append(Vector2(start, bounds.y))
	if spans.is_empty():
		return Vector2(clampf(at_x, bounds.x, bounds.y), MIN_GAP_SCALE)
	var best := INF
	var center := at_x
	var widest: Vector2 = spans[0]
	for span: Vector2 in spans:
		if span.y - span.x > widest.y - widest.x:
			widest = span
		if span.y - span.x < left + right:
			continue
		var here := clampf(at_x, span.x + left, span.y - right)
		if absf(here - at_x) < best:
			best = absf(here - at_x)
			center = here
	if best < INF:
		return Vector2(center, 1.0)
	var scale := maxf((widest.y - widest.x) / (left + right), MIN_GAP_SCALE)
	return Vector2(widest.x + left * scale, scale)


func slot_position(unit: AHCombat.Unit) -> Vector3:
	var rank := maxi(unit.rank, 1)
	# Na rua a luta fica na calçada (HERO_Z, ENEMY_Z); nos cenários, na faixa da zona (um pouco atrás do meio dela).
	var hero_z: float = HERO_Z
	var enemy_z: float = ENEMY_Z
	if _street.get("scenario") != null:
		hero_z = _street.lane_z - 0.3
		enemy_z = hero_z - 0.25
	if unit.is_player:
		return Vector3(center_x - hero_offset(rank) * gap_scale, _street.call("_ground_height", hero_z), hero_z - 0.03 * rank)
	return Vector3(center_x + (FRONT_GAP + (rank - 1) * ENEMY_GAP) * gap_scale, _street.call("_ground_height", enemy_z), enemy_z - 0.03 * rank)


## Distância do centro até a posição rank dos heróis: HERO_GAP entre vizinhos, ou mais, se os dois juntos são mais
## largos (cada um pela largura de quem está na posição agora; posição vazia conta como NARROW_HALF). Nunca passa do
## que start() reserva no fit(): cada herói alarga no máximo os dois vãos dele, em meia largura além de NARROW_HALF.
func hero_offset(rank: int) -> float:
	var at := {}
	for unit in (session.state.player_team if session != null else []):
		if unit.rank > 0:
			at[unit.rank] = _half_widths.get(unit.id, NARROW_HALF)
	var offset := FRONT_GAP
	for k in range(2, rank + 1):
		offset += maxf(HERO_GAP, float(at.get(k - 1, NARROW_HALF)) + float(at.get(k, NARROW_HALF)) + WIDE_ROOM)
	return offset


## Meia largura, em metros, da arte que o cartão mostra (body_width_pixels do manifesto); sem a medida, NARROW_HALF.
static func half_width(card: AHSpriteCard) -> float:
	var art := card.art()
	if not art.has("body_width_pixels"):
		return NARROW_HALF
	return float(art.body_width_pixels) * 0.5 * card.body_height / float(art.body_reference_pixels)


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
				hud.show_waiting(tr("%s age") % actor.display_name)
				await _wait(0.25)
				var auto := session.engine.play_auto_turn(actor.id)
				session._count(actor.id, auto.events)
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
			hud.show_waiting(tr("Vez de %s") % (AHCombatHud.unit_name(enemy.display_name) if enemy else tr("inimigo")))
			await _wait(0.45)
			await _play_beat(session.enemy_turn())
	hud.refresh()
	_sync_states(true)
	var result := session.result()
	session.write_back(Campaign.state)
	# As estrelas da luta (#91); as do guardião ficam no save, por fase.
	var expedition = Campaign.state.get("session", {}).get("expedition")
	var rewards := AHFightRewards.criteria(session, boss_fight, String(expedition.phase_id) if expedition != null else "")
	if boss_fight and result == "victory" and expedition != null:
		AHFightRewards.record_stars(Campaign.state, String(expedition.phase_id), int(rewards.stars))
	# O popup do fim (#109): a vitória e a fuga fecham sozinhas (no ritmo da luta), a derrota espera um toque.
	await hud.show_result(result, auto_battle, rewards)
	hud.close()
	var occlusion = _street.get("occlusion") if _street != null else null
	if occlusion != null:
		for unit in session.state.enemy_team:
			occlusion.untrack(cards[unit.id])
	active = false
	boss_fight = false
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
	# A espera para com o jogo pausado (a barra de Admin, #130): o inimigo não age por trás dela.
	await get_tree().create_timer(seconds / speed, false).timeout


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
				_float_text(card, tr("+1 Bloqueio"), Color(0.55, 0.75, 1.0))
				await _wait(0.6)
		"flee":
			if card:
				_float_text(card, tr("Fuga!") if beat.get("escaped", false) else tr("Fuga falhou"), Color(1, 0.9, 0.6))
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
	if session.state.player_team.any(func(u): return u.instinct >= 100):
		Tips.show_tip("instinct")
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
	# A crise tem o som dela e a música abaixa enquanto ela dura (#36).
	Sound.play("res://audio/combat/crisis.ogg", 0.9)
	Sound.duck(CRISIS_DUCK_DB, 1.65 / speed)
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
	var hero_action: Dictionary = _action_art(actor, ability_id) if actor.is_player else {}
	var support: bool = not hostile or (action != null and (action.bIsDefend or action.TargetType == "Self"))
	# Preparo: a pose de quem age, já na frente dos outros.
	if actor.is_player:
		show_pose(actor, "preparacao", ability_id)
	else:
		show_pose(actor, enemy_action_pose(action, enemy_art(actor.enemy_id)))
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
		if hero_action.has("vfx"):
			for target_id in (targets if not targets.is_empty() else [actor.id]):
				_spawn_vfx(actor, ability_id, target_id)
	else:
		_play_enemy_cue(actor, ability_id, action)
		if action != null:
			_float_text(card, action.DisplayName, Color(1.0, 0.85, 0.7), 0.9)
	var impact_start := Time.get_ticks_msec()
	var life := float(hero_action.get("vfx", {}).get("life_seconds", 0.0)) + 0.05
	await _show_events(events, contact, actor.id)
	var held := (Time.get_ticks_msec() - impact_start) * 0.001
	var impact := maxf(IMPACT_SECONDS * (0.8 if support else 1.0), life) / speed
	if held < impact:
		await get_tree().create_timer(impact - held, false).timeout
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
	var key := art_id(ability_id)
	if RANGED.has(key) or key.contains("tiro") or key.contains("descarga"):
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


## Números e reações de cada evento, no alvo. Num golpe (contact_x), o acerto mais forte dá a pausa e o tremor.
## actor_id: quem age (o dano nele mesmo, como o sangramento no começo da vez, não é golpe).
func _show_events(events: Array, contact_x = null, actor_id: String = "") -> void:
	var stagger := {}
	var crits := {}
	for event in events:
		# Só o crítico sorteado: a SOBRECARGA DO PORTEIRO (troca de fase) também é CRIT e não é golpe crítico.
		if event.type == AHCombat.EventType.CRIT and event.critical_roll:
			crits[event.target_unit_id] = true
	var strongest := -1.0
	var crit_hit := false
	# O efeito de cada alvo neste lance (#84): um só, o mais forte (AHCombatEffects.stronger).
	var damaged := {}
	for event in events:
		if event.type == AHCombat.EventType.DAMAGE:
			damaged[event.target_unit_id] = true
	var shown := {}
	for event in events:
		var unit := session.state.find_unit(event.target_unit_id)
		var card: AHSpriteCard = cards.get(event.target_unit_id)
		if unit == null or card == null or event.ability_id != "":
			continue
		var lift: float = stagger.get(unit.id, 0.0)
		stagger[unit.id] = lift + 0.32
		match event.type:
			AHCombat.EventType.DAMAGE:
				var crit: bool = crits.has(unit.id)
				_float_text(card, event.text, Color(1.0, 0.55, 0.2) if crit else Color(1.0, 0.35, 0.3), 1.0 + lift, CRIT_TEXT_SIZE if crit else 64)
				card.flash(Color(1.0, 0.15, 0.1), 0.35 / speed, 0.0 if reduced_effects() else FLASH_SECONDS / speed)
				# Quem cai também sente o golpe (a dor e um empurrão maior) antes da pose de queda, no _settle.
				show_pose(unit, "hurt")
				_recoil(card, contact_x, 0.11 if unit.hp > 0 else 0.17)
				strongest = maxf(strongest, float(event.amount) / maxf(1.0, float(unit.max_hp)) + (1.0 if unit.hp <= 0 else 0.0))
				crit_hit = crit_hit or crit
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
		# O efeito curto no alvo (#84): o acerto e o crítico só num golpe de outro (o sangramento e o veneno da vez não
		# são golpe); o escudo só quando o bloqueio segura um golpe (o bloqueio ganho por habilidade não).
		var effect := AHCombatEffects.for_event(event.type, crits.has(unit.id), _is_machine(unit))
		if AHCombatEffects.HITS.has(effect) and (contact_x == null or unit.id == actor_id):
			effect = ""
		if effect == "block" and not damaged.has(unit.id):
			effect = ""
		shown[unit.id] = AHCombatEffects.stronger(shown.get(unit.id, ""), effect)
	for unit_id in shown:
		if shown[unit_id] != "":
			effects.play(shown[unit_id], cards[unit_id], get_viewport().get_camera_3d() if is_inside_tree() else null, speed, reduced_effects())
	if not events.is_empty():
		hud.refresh()
		if contact_x != null and strongest >= 0.0:
			_shake(strongest, crit_hit)
			if crit_hit:
				Sound.duck(CRIT_DUCK_DB, 0.35 / speed)
			await _hitstop(HITSTOP_CRIT_SECONDS if crit_hit else HITSTOP_SECONDS)
		await _wait(0.55)


func reduced_effects() -> bool:
	return bool(Campaign.state.get("settings", {}).get("reduced_environment_effects", false))


## O tremor do acerto: de SHAKE_MIN a SHAKE_MAX pixels conforme o dano tira da vida do alvo (meia vida ou a queda dão o
## máximo), mais forte no crítico.
func _shake(strength: float, crit: bool) -> void:
	if reduced_effects():
		return
	_shake_pixels = minf(lerpf(SHAKE_MIN_PIXELS, SHAKE_MAX_PIXELS, clampf(strength * 2.0, 0.0, 1.0)) * (SHAKE_CRIT if crit else 1.0),
		SHAKE_MAX_PIXELS * SHAKE_CRIT)
	_shake_left = SHAKE_SECONDS
	_shake_time = 0.0


## O deslocamento da câmera agora, em pixels da tela de 1080 (a rua converte para a distância da câmera).
func camera_shake() -> Vector2:
	if _shake_left <= 0.0 or reduced_effects():
		return Vector2.ZERO
	var fade := _shake_left / SHAKE_SECONDS
	var amplitude := _shake_pixels * fade * fade
	return Vector2(sin(_shake_time * 71.0), sin(_shake_time * 97.0 + 1.3)) * amplitude


## A pausa do acerto: o tempo quase para (os números, o empurrão e o clarão congelam) e volta.
func _hitstop(seconds: float) -> void:
	if auto_battle or _hitstop_scale >= 0.0:
		return
	_hitstop_scale = Engine.time_scale
	Engine.time_scale = _hitstop_scale * HITSTOP_TIME_SCALE
	await get_tree().create_timer(seconds / speed, false, false, true).timeout
	_end_hitstop()


func _end_hitstop() -> void:
	if _hitstop_scale >= 0.0:
		Engine.time_scale = _hitstop_scale
		_hitstop_scale = -1.0


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
	var vfx: Dictionary = _action_art(actor, ability_id).vfx
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

## Os sons das ações dos inimigos: audio/combat/enemies/<inimigo>/<ação>.wav.
const ENEMY_CUES := "res://audio/combat/enemies/%s/%s.wav"


func _hero_cue(actor: AHCombat.Unit, ability_id: String) -> String:
	# O som é o da habilidade (a da classe dela; a do recruta, o da parecida, ArtOf): o recruta que aprendeu com a Íris
	# toca o som da ampola.
	var key := art_id(ability_id)
	var ability = session.data.abilities.get(key)
	var class_id := String(ability.get("ClassId", "")) if ability != null else ""
	if class_id == "":
		class_id = actor.class_id
	var prefix: String = HERO_CUES.get(class_id, "")
	var hero_class = session.data.classes.get(class_id)
	if prefix == "" or hero_class == null:
		return ""
	var index: int = hero_class.AbilityIds.find(key)
	return "%s%d" % [prefix, index + 1] if index >= 0 else ""


## O som da ação do inimigo: cada habilidade tem o dela (tools/synth_enemy_sounds.py, ligado ao que a arte mostra). Sem
## arquivo, o soco ou a cura de robô de antes.
func _play_enemy_cue(actor: AHCombat.Unit, ability_id: String, action) -> void:
	var path := ENEMY_CUES % [actor.enemy_id, ability_id]
	if ResourceLoader.exists(path):
		_play_path(path)
		return
	if action == null or not _is_machine(actor):
		return
	if action.TargetType == "Self":
		if action.HealRange.Max > 0:
			_play_cue("RobotHeal")
	elif action.DamageRange.Max > 0:
		_play_cue("RobotPunch")


func _play_cue(cue: String) -> void:
	_play_path(art.audio.get(cue, ""))


func _play_path(path: String) -> void:
	if path == "" or speed > 2.0:
		return
	var player := _audio[_audio_next]
	_audio_next = (_audio_next + 1) % _audio.size()
	player.stream = load(path)
	player.play()


func play_click() -> void:
	Sound.click()


## O anel no chão sob quem age (unit_id; "" esconde). Criado na primeira vez, filho da arena (no mundo da luta).
func show_ring(unit_id: String) -> void:
	if ring == null:
		ring = AHActorRing.new()
		ring.name = "ActorRing"
		add_child(ring)
	var card: AHSpriteCard = cards.get(unit_id) if unit_id != "" else null
	ring.follow(card if active else null)


## A arte de uma ação do herói: a da arte dele e, sem ela (a habilidade aprendida de outra classe, #189), o efeito do
## fundador dono da habilidade, com o herói parado (sem pose de golpe própria).
func _action_art(actor: AHCombat.Unit, ability_id: String) -> Dictionary:
	var key := art_id(ability_id)
	var own: Dictionary = hero_art(actor.hero_id).get("actions", {}).get(key, {})
	if own.has("vfx"):
		return own
	for founder_id in art.heroes:
		var action: Dictionary = art.heroes[founder_id].get("actions", {}).get(key, {})
		if action.has("vfx"):
			return own.merged({"vfx": action.vfx})
	return own

