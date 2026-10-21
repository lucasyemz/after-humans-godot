## Sound (autoload): os canais de música, ambiente e efeitos com o volume das opções da campanha, e a paisagem sonora
## da cena (port do UAHSoundscapeSubsystem e do FAHAudio). A cena atual diz o que quer tocar por soundscape(), que
## devolve {music, music_gain, ambience, ambience_gain, rain, rain_gain} (caminhos em res://audio, "" = nada); a troca
## faz um crossfade de 1,5 s. Os efeitos soltos passam por play() e os passos por footstep().
extends Node

const FADE_SECONDS := 1.5
const BUSES := ["Music", "Ambience", "SFX"]
## O volume de cada canal fica nas opções da campanha (FAHCampaignSettings: 0,6 por padrão).
const SETTING_OF := {"Music": "music_volume", "Ambience": "ambience_volume", "SFX": "sfx_volume"}
const FOOTSTEP_VARIANTS := {"water": 4, "wood": 5, "concrete": 5}

## Música, ambiente e chuva: um par de players por canal (o que sai e o que entra).
var _channels: Array = []
var _effects: Array[AudioStreamPlayer] = []
var _next_effect := 0
var _refresh := 0.0
var _streams := {}


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
	Campaign.changed.connect(apply_volumes)
	apply_volumes()


## Os volumes das opções (0 a 1) nos canais.
func apply_volumes() -> void:
	var settings: Dictionary = Campaign.state.get("settings", {})
	for bus in BUSES:
		var value := clampf(float(settings.get(SETTING_OF[bus], 0.6)), 0.0, 1.0)
		var index := AudioServer.get_bus_index(bus)
		AudioServer.set_bus_mute(index, value <= 0.001)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))


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
			_fade(channel, current, linear_to_db(maxf(gain, 0.001)), 0.4)
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
	tween.tween_property(fresh, "volume_db", linear_to_db(maxf(gain, 0.001)), FADE_SECONDS)


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


## Um efeito solto no canal de efeitos (ou outro), com ganho e altura.
func play(path: String, gain: float = 1.0, pitch: float = 1.0, bus: String = "SFX") -> void:
	var stream: AudioStream = load(path)
	if stream == null:
		return
	var player := _effects[_next_effect]
	_next_effect = (_next_effect + 1) % _effects.size()
	player.stream = stream
	player.bus = bus
	player.volume_db = linear_to_db(maxf(gain, 0.001))
	player.pitch_scale = pitch
	player.play()


## Um passo no piso do lugar (FAHAudio::Footstep): variação ao acaso, 70% e altura de 0,94 a 1,06.
func footstep(surface: String) -> void:
	var variants: int = FOOTSTEP_VARIANTS.get(surface, 5)
	play("res://audio/world/footstep_%s_%d.ogg" % [surface, randi_range(1, variants)], 0.7, randf_range(0.94, 1.06))


func click() -> void:
	play("res://audio/ui/click.ogg", 0.8)


## O piso de cada cenário (SurfaceForScenario): água no Depósito e nos Dutos, madeira na Ponte e no Cais.
static func surface_of(map: String) -> String:
	if map == "FloodedDepot" or map == "SewerDucts":
		return "water"
	if map == "RootBridge" or map == "RiverDock":
		return "wood"
	return "concrete"
