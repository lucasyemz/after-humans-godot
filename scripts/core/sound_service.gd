## Sound (autoload): os canais de música, ambiente e efeitos com o volume das opções da campanha, e a paisagem sonora
## da cena (port do UAHSoundscapeSubsystem e do FAHAudio). A cena atual diz o que quer tocar por soundscape(), que
## devolve {music, music_gain, ambience, ambience_gain, rain, rain_gain} (caminhos em res://audio, "" = nada); a troca
## faz um crossfade de 1,5 s. Os efeitos soltos passam por play() e os passos por footstep().
##
## Mixagem (#36): um barramento por tipo (Music, Ambience, SFX e UI, que segue o volume de efeitos das opções); cada
## arquivo tem o ganho da tabela data/presentation/audio_mix.json (tools/measure_audio.py: a música e os ambientes
## levados ao mesmo volume em LUFS), por baixo do ganho de cada cena; e a música abaixa (duck) na crise de instinto e no
## golpe crítico.
extends Node

const FADE_SECONDS := 1.5
const BUSES := ["Music", "Ambience", "SFX", "UI"]
## O volume de cada canal fica nas opções da campanha (FAHCampaignSettings: 0,6 por padrão); a interface segue o de
## efeitos (as Opções têm três controles).
const SETTING_OF := {"Music": "music_volume", "Ambience": "ambience_volume", "SFX": "sfx_volume", "UI": "sfx_volume"}
const MIX := "res://data/presentation/audio_mix.json"
## Os passos de cada classe (altura e volume): o Bento pesado, o Nick leve.
const HERO_STEPS := {"cao": [0.88, 0.85], "gato": [1.12, 0.5], "sapo": [1.0, 0.65], "coruja": [1.05, 0.6]}
const FOOTSTEP_VARIANTS := {"water": 4, "wood": 5, "concrete": 5}

## Música, ambiente e chuva: um par de players por canal (o que sai e o que entra).
var _channels: Array = []
var _effects: Array[AudioStreamPlayer] = []
var _next_effect := 0
var _refresh := 0.0
var _streams := {}
## O ganho de cada arquivo da tabela de mixagem (dB).
var _mix := {}
## Quanto a música está abaixada agora (dB, 0 = nada) e o tween que a leva e traz.
var duck_db := 0.0:
	set(value):
		duck_db = value
		_apply_bus("Music")
var _duck_tween: Tween
## Até quando (ms do relógio) e quanto vale o abaixamento em curso: um mais fraco não corta o mais forte antes disso.
var _duck_until := 0
var _duck_amount := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	for channel in 3:
		var bus: String = "Music" if channel == 0 else "Ambience"
		var players: Array[AudioStreamPlayer] = []
		for i in 2:
			var player := AudioStreamPlayer.new()
			player.bus = bus
			add_child(player)
			players.append(player)
		_channels.append({"path": "", "gain": 0.0, "players": players, "active": 0, "tween": null})
	for i in 10:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_effects.append(player)
	var table = JSON.parse_string(FileAccess.get_file_as_string(MIX)) if FileAccess.file_exists(MIX) else null
	if typeof(table) == TYPE_DICTIONARY:
		for path in table.get("files", {}):
			_mix[path] = float(table.files[path].get("gain_db", 0.0))
	Campaign.changed.connect(apply_volumes)
	apply_volumes()


## Os volumes das opções (0 a 1) nos canais.
func apply_volumes() -> void:
	for bus in BUSES:
		_apply_bus(bus)


func _apply_bus(bus: String) -> void:
	var settings: Dictionary = Campaign.state.get("settings", {}) if Campaign else {}
	var value := clampf(float(settings.get(SETTING_OF[bus], 0.6)), 0.0, 1.0)
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)) + (duck_db if bus == "Music" else 0.0))


## O ganho do arquivo na tabela de mixagem (dB; 0 fora dela).
func mix_db(path: String) -> float:
	return _mix.get(path, 0.0)


## Abaixa a música amount_db por hold segundos (a crise, o crítico) e volta devagar; o mais forte vale.
func duck(amount_db: float, hold: float) -> void:
	var now := Time.get_ticks_msec()
	if absf(amount_db) < _duck_amount and now < _duck_until:
		return
	_duck_amount = absf(amount_db)
	_duck_until = now + int((0.12 + hold) * 1000.0)
	if _duck_tween:
		_duck_tween.kill()
	# Em tempo de relógio: a pausa do acerto (o tempo quase parado) não segura a música no alto.
	_duck_tween = create_tween().set_ignore_time_scale(true)
	_duck_tween.tween_property(self, "duck_db", -absf(amount_db), 0.12)
	_duck_tween.tween_interval(hold)
	_duck_tween.tween_property(self, "duck_db", 0.0, 0.8)


func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 0.25
	var scene := get_tree().current_scene
	var want: Dictionary = scene.soundscape() if scene and scene.has_method("soundscape") else {}
	_switch(0, want.get("music", ""), want.get("music_gain", 0.32))
	_switch(1, want.get("ambience", ""), want.get("ambience_gain", 0.8))
	_switch(2, want.get("rain", ""), want.get("rain_gain", 0.7))


## Troca o que o canal toca (crossfade); o mesmo caminho só ajusta o ganho.
func _switch(index: int, path: String, gain: float) -> void:
	var channel: Dictionary = _channels[index]
	var players: Array = channel.players
	var current: AudioStreamPlayer = players[channel.active]
	if channel.path == path:
		if path != "" and not is_equal_approx(channel.gain, gain):
			channel.gain = gain
			_fade(channel, current, linear_to_db(maxf(gain, 0.001)) + mix_db(path), 0.4)
		return
	var old := current
	channel.path = path
	channel.gain = gain
	if channel.tween:
		channel.tween.kill()
	var tween := create_tween().set_parallel(true)
	channel.tween = tween
	if old.playing:
		tween.tween_property(old, "volume_db", -60.0, FADE_SECONDS)
		tween.chain().tween_callback(old.stop)
	if path == "":
		return
	channel.active = 1 - channel.active
	var fresh: AudioStreamPlayer = players[channel.active]
	fresh.stream = _loop(path)
	fresh.volume_db = -60.0
	fresh.play()
	tween.tween_property(fresh, "volume_db", linear_to_db(maxf(gain, 0.001)) + mix_db(path), FADE_SECONDS)


func _fade(channel: Dictionary, player: AudioStreamPlayer, db: float, seconds: float) -> void:
	if channel.tween:
		channel.tween.kill()
	channel.tween = create_tween()
	channel.tween.tween_property(player, "volume_db", db, seconds)


func _loop(path: String) -> AudioStream:
	if not _streams.has(path):
		var stream: AudioStream = load(path)
		if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
			stream.loop = true
		elif stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
		_streams[path] = stream
	return _streams[path]


## Um efeito solto no canal de efeitos (ou outro), com ganho e altura. Os sons de audio/ui vão para o canal da
## interface.
func play(path: String, gain: float = 1.0, pitch: float = 1.0, bus: String = "SFX") -> void:
	var stream: AudioStream = load(path)
	if stream == null:
		return
	var player := _effects[_next_effect]
	_next_effect = (_next_effect + 1) % _effects.size()
	player.stream = stream
	player.bus = "UI" if bus == "SFX" and path.begins_with("res://audio/ui/") else bus
	player.volume_db = linear_to_db(maxf(gain, 0.001)) + mix_db(path)
	player.pitch_scale = pitch
	player.play()


## Um passo no piso do lugar (FAHAudio::Footstep): variação ao acaso, altura de 0,94 a 1,06 vezes a do herói que anda
## (HERO_STEPS) e o volume dele (70% sem herói).
func footstep(surface: String, class_id: String = "") -> void:
	var variants: int = FOOTSTEP_VARIANTS.get(surface, 5)
	var step: Array = HERO_STEPS.get(class_id, [1.0, 0.7])
	play("res://audio/world/footstep_%s_%d.ogg" % [surface, randi_range(1, variants)], step[1], step[0] * randf_range(0.94, 1.06))


func click() -> void:
	play("res://audio/ui/click.ogg", 0.8)


## O piso de cada cenário (SurfaceForScenario): água no Depósito e nos Dutos, madeira na Ponte e no Cais.
static func surface_of(map: String) -> String:
	if map == "FloodedDepot" or map == "SewerDucts":
		return "water"
	if map == "RootBridge" or map == "RiverDock":
		return "wood"
	return "concrete"
