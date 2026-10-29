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
## As luminárias desenhadas com sombra (a Estação, os cenários e os postes da rua): a sombra delas segue a qualidade.
const SHADOW_LAMPS := "shadow_lamps"
## O limite de LOD de cada nível (Viewport.mesh_lod_threshold, em pixels): os modelos importados já têm LOD; no Baixo e
## no Médio a troca para o mais simples vem antes (#37).
const LOD_THRESHOLD := [6.0, 3.0, 1.0, 1.0]

var level := 2
var fullscreen := false
var vsync := true
## Cores para daltonismo: azul e laranja no lugar de verde e vermelho (AHUiStyle.set_colorblind).
var colorblind := false
## O tamanho do texto das telas (AHUiStyle.text_scale): as telas ficam na base de 1920x1080 e só as letras crescem.
const TEXT_SIZES := ["Normal", "Grande", "Maior"]
const TEXT_SCALE := [1.0, 1.15, 1.3]
var text_size := 0
## Controles de toque na exploração (AHTouchControls): automático (com tela de toque), sempre ou desligados.
const TOUCH_MODES := ["Automático", "Sempre", "Desligados"]
var touch_controls := 0
## As teclas trocadas nas Opções: a ação e a tecla principal nova (código físico). As outras teclas da ação (as setas,
## por exemplo) e os botões do controle continuam.
var keys := {}
const REMAPPABLE := ["move_left", "move_right", "move_back", "move_front", "run", "interact", "inventory", "formation", "cancel", "menu",
	"combat_ability_1", "combat_ability_2", "combat_ability_3", "combat_ability_4", "combat_move", "combat_defend", "combat_flee", "combat_examine", "combat_log", "hide_hud",
	"report_details", "station_prepare", "station_room_prev", "station_room_next"]


## O idioma das telas (#35): o português é o padrão e o inglês está em teste (data/i18n/en.po; o que falta traduzir
## aparece em português). A chave de cada texto é o próprio português.
const LANGUAGES := [["pt_BR", "Português"], ["en", "English (em teste)"]]
var language := "pt_BR"

## Nos scripts de teste e nas capturas as opções valem só na memória (nada é gravado na pasta de quem joga).
var _persist := true


func _ready() -> void:
	var args := Array(OS.get_cmdline_args()) + Array(OS.get_cmdline_user_args())
	_persist = not (args.has("-s") or args.has("--script") or args.any(func(a): return String(a).begins_with("--capture=") or String(a).begins_with("--capture-title=") or String(a).begins_with("--perf")))
	var config := ConfigFile.new()
	if _persist and config.load(PATH) == OK:
		level = clampi(int(config.get_value("graphics", "level", level)), 0, 3)
		fullscreen = bool(config.get_value("graphics", "fullscreen", fullscreen))
		vsync = bool(config.get_value("graphics", "vsync", vsync))
		colorblind = bool(config.get_value("accessibility", "colorblind", colorblind))
		text_size = clampi(int(config.get_value("accessibility", "text_size", text_size)), 0, TEXT_SIZES.size() - 1)
		touch_controls = clampi(int(config.get_value("controls", "touch", touch_controls)), 0, TOUCH_MODES.size() - 1)
		keys = config.get_value("controls", "keys", {})
		language = _known_language(String(config.get_value("interface", "language", language)))
	# --text-size=N nas capturas: confere as telas com o texto maior (só na memória).
	for arg in args:
		if String(arg).begins_with("--text-size="):
			text_size = clampi(int(String(arg).get_slice("=", 1)), 0, TEXT_SIZES.size() - 1)
		elif String(arg) == "--touch":
			touch_controls = 1
		# --language=en: as telas em outro idioma. Nas capturas e nos scripts as opções não são gravadas; jogando, a
		# próxima opção mudada grava o idioma (como --text-size).
		elif String(arg).begins_with("--language="):
			language = _known_language(String(arg).get_slice("=", 1))
	apply_controls()
	# O idioma vem das opções, nunca do sistema (num Windows em inglês o jogo abria em inglês).
	TranslationServer.set_locale(language)
	AHUiStyle.text_scale = TEXT_SCALE[text_size]
	AHUiStyle.install.call_deferred(get_tree().root)
	apply()


## O foco das telas só aparece para quem usa teclado ou controle (AHUiStyle.keep_focus).
func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5) \
			or event is InputEventAction:
		AHUiStyle.using_keys = true
	elif event is InputEventMouseButton or event is InputEventScreenTouch:
		AHUiStyle.using_keys = false


## As teclas padrão (as de tools/define_input.gd, no project.godot) com as trocas por cima.
func apply_controls() -> void:
	InputMap.load_from_project_settings()
	var defaults := {}
	for action in REMAPPABLE:
		defaults[action] = primary_key(action)
	for action in keys:
		if InputMap.has_action(action):
			_put_key(action, int(keys[action]))
	# Uma ação que ficou na tecla de fábrica, quando outra ação já foi trocada para ela num save antigo (a formação no R,
	# #129, com o R salvo em outra): ela fica com a tecla de fábrica da outra, a mesma troca do set_key, sem conflito.
	for action in REMAPPABLE:
		if keys.has(action) or not InputMap.has_action(action):
			continue
		var code := primary_key(action)
		for other in keys:
			if other != action and int(keys[other]) == code and code != 0:
				var free := int(defaults.get(other, 0))
				if free != 0 and not REMAPPABLE.any(func(a): return a != action and primary_key(a) == free):
					_put_key(action, free)
				break


## A tecla nova entra no lugar da primeira (a ordem diz qual é a principal).
func _put_key(action: String, code: int) -> void:
	var events := InputMap.action_get_events(action)
	var key := InputEventKey.new()
	key.physical_keycode = code
	var replaced := false
	for i in events.size():
		if events[i] is InputEventKey and not replaced:
			events[i] = key
			replaced = true
	if not replaced:
		events.push_front(key)
	InputMap.action_erase_events(action)
	for event in events:
		InputMap.action_add_event(action, event)


## A tecla principal da ação agora (código físico; 0 se não houver).
func primary_key(action: String) -> int:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.physical_keycode if event.physical_keycode != 0 else event.keycode
	return 0


## Troca a tecla principal; se outra ação já usava essa tecla, ela fica com a antiga desta (troca, sem conflito).
func set_key(action: String, code: int) -> void:
	var old := primary_key(action)
	for other in REMAPPABLE:
		if other != action and primary_key(other) == code:
			keys[other] = old
	keys[action] = code
	apply_controls()
	_store()
	AHUiStyle.refresh_keys(get_tree().root)


func reset_keys() -> void:
	keys.clear()
	apply_controls()
	_store()
	AHUiStyle.refresh_keys(get_tree().root)


## As cores e o tamanho do texto valem na hora, também nas telas abertas (AHUiStyle.retune).
func set_colorblind(value: bool) -> void:
	var ok := AHUiStyle.OK
	var danger := AHUiStyle.DANGER
	colorblind = value
	_store()
	AHUiStyle.retune(get_tree().root, AHUiStyle.text_scale, ok, danger)


func set_text_size(value: int) -> void:
	var scale: float = AHUiStyle.text_scale
	text_size = clampi(value, 0, TEXT_SIZES.size() - 1)
	AHUiStyle.text_scale = TEXT_SCALE[text_size]
	AHUiStyle.install(get_tree().root)
	_store()
	AHUiStyle.retune(get_tree().root, scale, AHUiStyle.OK, AHUiStyle.DANGER)


## Troca o idioma na hora: os textos fixos das telas mudam sozinhos; as telas montadas com texto formatado se refazem
## ao receber changed (ou ao abrir de novo).
func set_language(code: String) -> void:
	language = _known_language(code)
	TranslationServer.set_locale(language)
	_store()
	changed.emit()


static func _known_language(code: String) -> String:
	for entry in LANGUAGES:
		if entry[0] == code:
			return code
	return "pt_BR"


func set_touch_controls(value: int) -> void:
	touch_controls = clampi(value, 0, TOUCH_MODES.size() - 1)
	_store()


## Os controles de toque aparecem agora? (Automático: só com tela de toque.)
func touch_visible() -> bool:
	return touch_controls == 1 or (touch_controls == 0 and DisplayServer.is_touchscreen_available())


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
	if not _persist:
		apply()
		return
	var config := ConfigFile.new()
	config.set_value("graphics", "level", level)
	config.set_value("graphics", "fullscreen", fullscreen)
	config.set_value("graphics", "vsync", vsync)
	config.set_value("accessibility", "colorblind", colorblind)
	config.set_value("accessibility", "text_size", text_size)
	config.set_value("controls", "keys", keys)
	config.set_value("controls", "touch", touch_controls)
	config.set_value("interface", "language", language)
	config.save(PATH)
	apply()


## Janela e resolução interna; os efeitos de cada cena saem de effects() quando ela recebe changed.
func apply() -> void:
	var web := OS.has_feature("web")
	# A captura e o roteiro de desempenho (--perf) medem sem vsync e na janela deles; não mexe.
	var capture := Array(OS.get_cmdline_user_args()).any(func(arg): return String(arg).begins_with("--capture=") or String(arg).begins_with("--perf"))
	if not web and not capture and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	get_viewport().scaling_3d_scale = RENDER_SCALE[level]
	get_viewport().mesh_lod_threshold = LOD_THRESHOLD[level]
	apply_lamp_shadows()
	AHUiStyle.set_colorblind(colorblind)
	changed.emit()


## O que a cena liga (Forward+ só; o Compatibility da web não tem esses efeitos). As sombras das luminárias (as
## OmniLight3D com sombra: a cena desenhada de novo seis vezes por luz) só no Alto e no Ultra do Forward+ e no Ultra do
## Compatibility, o da web (#37: com as 18 da Estação, 5 mil chamadas de desenho por quadro contra 480 sem elas); no
## resto elas acendem sem sombra. A do sol continua a partir do Médio.
func effects() -> Dictionary:
	return effects_for(level, RenderingServer.get_current_rendering_method() == "forward_plus")


static func effects_for(quality: int, forward_plus: bool) -> Dictionary:
	return {"ssao": quality >= 1, "volumetric_fog": quality >= 2, "ssr": quality >= 2, "rain_scale": RAIN_SCALE[quality],
		"shadows": quality >= 1, "lamp_shadows": quality >= 3 or (quality >= 2 and forward_plus)}


## As luminárias que têm sombra no desenho (o grupo SHADOW_LAMPS) seguem a qualidade na hora.
func apply_lamp_shadows() -> void:
	var on: bool = effects().lamp_shadows
	for light in get_tree().get_nodes_in_group(SHADOW_LAMPS):
		light.shadow_enabled = on
