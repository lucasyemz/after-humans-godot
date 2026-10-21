## Settings (autoload): as opções desta máquina (qualidade gráfica, tela cheia, vsync), em user://settings.cfg. Os
## volumes e a velocidade da batalha ficam na campanha (FAHCampaignSettings), como na Unreal.
##
## Qualidade (#47 da Unreal: Baixo, Médio, Alto e Ultra): resolução interna, oclusão de ambiente, neblina volumétrica,
## reflexos da chuva no chão e densidade da chuva. A troca vale na hora: as cenas ouvem changed e reaplicam.
extends Node

signal changed

const PATH := "user://settings.cfg"
const LEVEL_NAMES := ["Baixo", "Médio", "Alto", "Ultra"]
## Resolução interna de cada nível (a arte pintada aguenta pouco abaixo de 2/3).
const RENDER_SCALE := [0.67, 0.8, 1.0, 1.0]
## Gotas de chuva de cada nível (GetRainDensityScale da Unreal).
const RAIN_SCALE := [0.35, 0.55, 0.8, 1.0]

var level := 2
var fullscreen := false
var vsync := true
## Modo de desenvolvedor (F1): as teclas de teste (K, R, T, P, C) e o contador de quadros. Fica fora da tela do jogador.
var dev_mode := false


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		level = clampi(int(config.get_value("graphics", "level", level)), 0, 3)
		fullscreen = bool(config.get_value("graphics", "fullscreen", fullscreen))
		vsync = bool(config.get_value("graphics", "vsync", vsync))
		dev_mode = bool(config.get_value("dev", "enabled", dev_mode))
	AHUiStyle.install.call_deferred(get_tree().root)
	apply()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		set_dev_mode(not dev_mode)
		get_viewport().set_input_as_handled()


func set_dev_mode(value: bool) -> void:
	dev_mode = value
	_store()


func set_level(value: int) -> void:
	level = clampi(value, 0, 3)
	_store()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_store()


func set_vsync(value: bool) -> void:
	vsync = value
	_store()


func _store() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "level", level)
	config.set_value("graphics", "fullscreen", fullscreen)
	config.set_value("graphics", "vsync", vsync)
	config.set_value("dev", "enabled", dev_mode)
	config.save(PATH)
	apply()


## Janela e resolução interna; os efeitos de cada cena saem de effects() quando ela recebe changed.
func apply() -> void:
	var web := OS.has_feature("web")
	# A captura mede sem vsync e na janela dela; não mexe.
	var capture := Array(OS.get_cmdline_user_args()).any(func(arg): return String(arg).begins_with("--capture="))
	if not web and not capture and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	get_viewport().scaling_3d_scale = RENDER_SCALE[level]
	changed.emit()


## O que a cena liga (Forward+ só; o Compatibility da web não tem esses efeitos).
func effects() -> Dictionary:
	return {"ssao": level >= 1, "volumetric_fog": level >= 2, "ssr": level >= 2, "rain_scale": RAIN_SCALE[level],
		"shadows": level >= 1}
