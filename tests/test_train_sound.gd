## O som do trem na passagem do vagão (#133): a partida (o trem saindo da plataforma, o laço dos trilhos e a freada na
## chegada) e a volta à Estação (o laço; a freada e o sino tocam na plataforma). O laço entra com o cartão e sai com ele;
## pular corta num fade curto e sem a freada; tudo no canal do Ambiente (o volume do Ambiente nas Opções).
extends RefCounted

const RIDE := "res://audio/station/train_ride.ogg"
const BRAKE := "res://audio/station/train_brake.ogg"
const DEPARTURE := "res://audio/station/train_departure.ogg"

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-train-sound-%d" % Time.get_ticks_usec()
	Campaign.state = Campaign.create_initial(133)
	_cards()
	await _plays_and_ends()
	await _skip_cuts()
	_ambience_volume()
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	# A Estação da passagem grava o save: a pasta do teste sai junto (nada fica na pasta de saves).
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Tips.enabled = tips
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _cards() -> void:
	t.check(ResourceLoader.exists(RIDE) and (load(RIDE) as AudioStream).get_length() >= 4.0, "o laço do trem existe (%s)" % RIDE)
	t.check(Sound.mix_db(RIDE) != 0.0, "e está na tabela de mixagem (no alvo do Ambiente)")
	AHJourneyRules.start_expedition(Campaign.state, "fase_1", 133)
	var departure := AHWagonRide.departure_card(Campaign.state)
	t.equal(departure.get("sound", {}).get("loop", ""), RIDE, "a partida no vagão toca o trem andando")
	t.check(String(departure.sound.get("start", "")).ends_with("train_departure.ogg") and departure.sound.get("end", "") == BRAKE,
		"com a partida da plataforma no começo e a freada na chegada")
	if departure.get("backdrop") is Node:
		departure.backdrop.free()
	Campaign.state.session.expedition = null
	var back := AHWagonRide.return_card()
	t.check(back.title == GameFlow.card_for("station").title and back.sound.get("loop", "") == RIDE and not back.sound.has("end"),
		"a volta à Estação: o cartão da Estação com o trem andando (a freada toca na plataforma)")


## Sem pular: o laço toca no Ambiente, sobe com o cartão e, no fim, sai e a freada toca.
func _plays_and_ends() -> void:
	GameFlow.change_to("title", {}, false)
	await _settle()
	_silence()
	var card := GameFlow.card_for("station")
	card.sound = {"loop": RIDE, "gain": 0.8, "end": BRAKE}
	GameFlow.travel("station", card)
	var passage: AHPassageCard = null
	for i in 120:
		await _tree.process_frame
		if GameFlow.passage != null:
			passage = GameFlow.passage
			break
	if not t.check(passage != null, "a passagem abre"):
		return
	var player: AudioStreamPlayer = passage.get_node_or_null("Sound")
	t.check(player != null and player.playing and player.bus == "Ambience", "o laço toca com o cartão, no canal do Ambiente")
	var first := player.volume_db if player != null else 0.0
	var target := linear_to_db(0.8) + Sound.mix_db(RIDE)
	t.check(is_equal_approx(passage._sound_db(), target), "o volume do laço é o do cartão, na mixagem do Ambiente (%.1f dB)" % target)
	# O laço entra pelo relógio e chega ao volume dele antes de a Estação montar (o quadro da montagem trava o jogo): o
	# volume do último quadro sem a cena montada é o que tocou durante a montagem.
	var before_mount := -60.0
	var braked := false
	while GameFlow.busy:
		if _tree.current_scene == null and is_instance_valid(player):
			before_mount = player.volume_db
		await _tree.process_frame
		braked = braked or _playing(BRAKE)
	t.check(first <= -50.0 and before_mount >= target - 3.0,
		"e entra com o cartão: de %.0f dB até o volume dele (%.1f dB) antes de a Estação montar (%.1f dB)" % [first, target, before_mount])
	t.check(not is_instance_valid(player) or not player.playing, "no fim, o laço sai com o cartão")
	t.check(braked, "e, sem pular, a freada toca na chegada")


## Pulando: o laço sai num fade curto e a freada não toca.
func _skip_cuts() -> void:
	_silence()
	var card := GameFlow.card_for("title")
	card.backdrop = Node3D.new()
	card.hold = 3600.0
	card.sound = {"loop": RIDE, "gain": 0.8, "start": DEPARTURE, "end": BRAKE}
	GameFlow.travel("title", card)
	var limit := Time.get_ticks_msec() + 30000
	while (GameFlow.passage == null or not GameFlow.passage.ready_to_skip) and Time.get_ticks_msec() < limit:
		await _tree.process_frame
	var passage: AHPassageCard = GameFlow.passage
	if not t.check(passage != null and passage.sound_playing(), "o laço toca na passagem do vagão"):
		return
	var player: AudioStreamPlayer = passage.get_node("Sound")
	var cut_at := -1
	var braked := false
	limit = Time.get_ticks_msec() + 30000
	while GameFlow.busy and Time.get_ticks_msec() < limit:
		if GameFlow.passage != null and not GameFlow.passage.skipped:
			_skip()
		await _tree.process_frame
		if cut_at < 0 and GameFlow.passage != null and GameFlow.passage.skipped:
			cut_at = Time.get_ticks_msec()
		braked = braked or _playing(BRAKE)
	t.check(not GameFlow.busy and cut_at >= 0, "pulada, a passagem termina")
	t.check(not is_instance_valid(player) or not player.playing or player.volume_db < -40.0, "e o laço sai")
	t.check(not braked, "sem a freada (pular corta o som)")
	await _wait_ms(int(AHPassageCard.SOUND_SKIP_FADE * 1000.0) + 300)
	t.check(not _playing(DEPARTURE), "e a partida do trem (6 s) também sai, sem passar para a cena seguinte")


## O volume do Ambiente nas Opções vale para o trem: zerado, o canal fica mudo.
func _ambience_volume() -> void:
	var settings: Dictionary = Campaign.state.settings
	var before = settings.get("ambience_volume", 0.6)
	settings.ambience_volume = 0.0
	Sound.apply_volumes()
	t.check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambience")), "com o Ambiente em 0, o trem não toca (o canal mudo)")
	settings.ambience_volume = 0.5
	Sound.apply_volumes()
	t.check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambience")) and is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience")), linear_to_db(0.5)),
		"e segue o volume escolhido")
	settings.ambience_volume = before
	Sound.apply_volumes()


func _skip() -> void:
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = "interact"
		e.pressed = pressed
		_tree.root.push_input(e)


func _playing(path: String) -> bool:
	return Sound._effects.any(func(p): return p.playing and p.stream != null and p.stream.resource_path == path)


func _silence() -> void:
	for player in Sound._effects:
		player.stop()


func _wait_ms(ms: int) -> void:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		await _tree.process_frame


func _settle() -> void:
	for i in 10:
		await _tree.process_frame
	while GameFlow.busy:
		await _tree.process_frame
