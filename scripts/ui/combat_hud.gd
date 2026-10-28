## HUD de combate (a proposta de UX, etapa 1), montado em código na base de 1920x1080:
## - em cima, a ordem da rodada com o rosto de cada um (quem age agora em dourado, inimigos com aro de cobre);
## - sob os pés de cada personagem, uma placa com nome, vida em número e os estados por extenso;
## - embaixo, o herói da vez por inteiro (vida e instinto até a crise), os quatro cartões de habilidade (o número, de
##   quais posições sai e quais alcança, a tecla e o motivo quando não dá) e as ações com tecla;
## - ao apontar uma habilidade ou um alvo, a dica completa: o que faz, quem atinge, se derruba e os termos explicados;
## - o registro da luta à direita, legível.
class_name AHCombatHud
extends Control

signal command_chosen(command: Dictionary)
signal result_closed
## Os momentos da vez que o tutorial (#144) acompanha: "turn" (a vez de um herói, {actor}), "target" (a mira de uma
## habilidade ou do Mover, {ability}), "cancel" (a mira desfeita), "command" (o comando escolhido) e "bag" (a Mochila).
signal tutorial_moment(kind: String, data: Dictionary)

const S = preload("res://scripts/ui/ui_style.gd")
const GOLD := S.GOLD
const INK := AHKit.INK
const TEXT := S.TEXT
const MUTED := S.MUTED
## Onde fica o rodapé da vez (a vida sob os pés não passa daqui): o topo da aba "Escolha um alvo", menos a folga.
const DOCK_TOP := 812.0
## As peças do alvo (docs/design/hud-target.md, "Geometria"), na base de 1920x1080.
const KIT_REGISTER := Rect2(46, 32, 272, 64)
const KIT_ROUND_CENTER := Vector2(996, 30)
const KIT_HERO := Rect2(64, 836, 564, 212)
const KIT_TAB_CENTER := Vector2(1024, 816)
const KIT_HEADER := Rect2(684, 852, 624, 56)
const KIT_HEADER_DIVIDER := 1192.0
const KIT_SLOT := Rect2(688, 916, 132, 132)
const KIT_SLOT_STEP := 160.0
const KIT_ACTION := Rect2(1584, 836, 128, 100)
const KIT_ACTION_STEP := Vector2(136, 112)
const KIT_TARGET_NAME := Vector2(176, 56)
## A inspeção (#128): o botão INSPECIONAR entre as habilidades e as ações, e o painel que, ligado, cobre o do herói da vez
## e as habilidades com os detalhes de quem está apontado.
const KIT_INSPECT := Rect2(1316, 984, 260, 64)
const KIT_INSPECT_PANEL := Rect2(64, 836, 1252, 212)
## A coluna do retrato no painel do herói (o nome e as barras começam aqui) e a altura das barras sob as unidades.
const HERO_TEXT_LEFT := 222.0
const PLATE_BAR_HEIGHT := 40.0
## A intenção das máquinas não sobe acima disto (a faixa da rodada termina em ~106).
const INTENT_TOP := 112.0
## O popup do fim da luta (#109): no alto, no lugar da faixa da rodada. Fecha sozinho em POPUP_HOLD s de verdade (#128:
## dá para ler; a velocidade da batalha não encurta), e o tempo para enquanto o mouse está em cima dele.
const POPUP_TOP := 24.0
const POPUP_WIDTH := 640.0
## O popup alarga com o texto até aqui (o XP de quatro nomes longos no Maior) antes de quebrar a linha: cada linha a
## mais desce sobre as cabeças da equipe.
const POPUP_MAX_WIDTH := 900.0
const POPUP_HOLD := 5.0
## O toque que fecha o popup só vale depois disto (ms): a tecla que acabou a luta não o fecha no mesmo instante.
const POPUP_GUARD_MS := 250
const KIT_PORTRAIT := 60.0
## A faixa da ordem (#193): a folga depois do último retrato (a ponta da direita da peça), a largura máxima na base de
## 1920 (com a margem de cada lado) e o menor retrato quando a fila é longa.
const ORDER_END_PAD := 14.0
const ORDER_EDGE := 24.0
const ORDER_MAX_WIDTH := 1920.0 - 2.0 * ORDER_EDGE
const ORDER_MIN_PORTRAIT := 36.0
## O espaço entre os retratos da faixa, e o menor, quando a fila é longa demais até para o menor retrato.
const ORDER_GAP := 8.0
const ORDER_MIN_GAP := 2.0
const ACTIONS := [["Mover", "move", "Q", "combat_move"], ["Defender", "defend", "W", "combat_defend"],
	["Mochila", "item", "I", "inventory"], ["Fugir", "flee", "F", "combat_flee"]]

var arena: AHCombatArena
var session: AHCombatSession
## A ficha (#89): na luta fica fechada (#128); continua aqui pelo touch_mode (o último apontar foi um toque).
var sheet: AHCharacterSheet
## Onde o mouse está (o último movimento, nas coordenadas da tela do jogo).
var _mouse := Vector2(-1, -1)
## A inspeção (#128, antes o Examinar da #89): os personagens de pé, da esquerda para a direita, e quem está escolhido.
var _examine: Array = []
var _examine_index := 0
## A instrução da vez de antes do Examinar (volta ao fechar).
var _examine_note := ""
## A inspeção ligada (#128): o painel de baixo mostra quem o mouse aponta ou quem foi escolhido (_examine).
var _inspect_on := false
var _inspect_button: Button
var _inspect_panel: PanelContainer
## O id e a ficha que o painel mostra agora (para não remontar a cada quadro).
var _inspect_info := {}
## O mouse em cima (#128): o nome na plaqueta sobre quem é apontado e a luz leve nele.
var _hover_label: Label
var _hovered := ""
var _order: HBoxContainer
var _order_panel: PanelContainer
var _panel: Control
var _hero_face: TextureRect
var _hero_name: Label
var _hero_hp: AHKitBar
var _hero_instinct: AHKitBar
var _hero_status: HFlowContainer
var _abilities: HBoxContainer
var _actions: GridContainer
var _description: Label
var _target_tab: PanelContainer
var _tab_text := ""
var _register: Button
var _ability_header: PanelContainer
var _ability_icon: TextureRect
var _ability_name: Label
var _ability_range: Label
var _message: Label
var _log: Label
var _log_panel: PanelContainer
var _log_title: Label
## O registro aberto pela tecla (#56); fechado, só a última linha aparece por LOG_FLASH segundos a cada lance.
var _log_open := false
var _quiet_focus := false
var _log_seen := 0
var _log_tween: Tween
const LOG_FLASH := 2.0
var _tip: PanelContainer
var _tip_box: VBoxContainer
var _result: PanelContainer
## Quando o popup do fim abriu (ms) e se ele espera um toque (a derrota).
var _result_opened := 0
var _result_waits := false
## O tempo que falta para o popup fechar sozinho (s) e o total; < 0: não fecha sozinho (a derrota).
var _result_left := -1.0
var _result_total := 1.0
var _result_timer: AHKitBar
## O X do popup (#128): por cima do canto dele, para não somar altura (o popup não desce sobre a equipe).
var _result_close: Button
var _unit_bars := {}
var _markers: Array = []
## A escolha do alvo (#57): o lado, as posições válidas, a habilidade, o escolhido, o clicado uma vez e se o último
## toque veio do mouse (o primeiro clique escolhe, o segundo usa; o teclado usa o escolhido).
var _pick_side := true
var _pick_ranks: Array = []
var _pick_ability := ""
var _picked_rank := -1
var _clicked_rank := -1
var _via_mouse := false
var _target_label: Label
## A prévia da habilidade mirada: uma marca sobre cada outro atingido (o par da granada, o vizinho do coquetel).
var _preview_marks: Array = []
var _actor_id := ""
var _options: Array = []
var _choosing := ""
var _bag: PanelContainer
var _crisis: Control
## Esperando o comando do herói (a captura usa para jogar por ele).
var waiting := false
## As ações travadas pelo tutorial nesta vez ("move", "defend", "item", "flee"): a primeira escolha é de uma habilidade.
var tutorial_locks: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	sheet = AHCharacterSheet.new()
	add_child(sheet)


# ---------------------------------------------------------------- peças (usadas também pelas outras telas)

static func panel_style(alpha: float = 0.9) -> StyleBox:
	return S.panel(alpha)


static func make_label(text: String, size: int, color: Color = TEXT) -> Label:
	return S.label(text, size, color)


static func make_bar(color: Color, height: float) -> ProgressBar:
	return S.bar(color, height)


## O botão do jogo com as molduras do Codex (#20): normal, sobre (hover), pressionado (filete interno), desligado e, para
## o comando principal, a barra lateral. O foco do teclado e do controle são as cantoneiras de fora (#25), na cor accent.
static func style_button(button: Button, accent: Color = GOLD, primary: bool = false) -> void:
	var margins := Vector4(20, 10, 20, 10)
	button.add_theme_stylebox_override("normal", S.frame("button_primary" if primary else "button_normal", 0.96, 1.0, margins))
	button.add_theme_stylebox_override("hover", S.frame("button_hover", 0.98, 1.0, margins))
	button.add_theme_stylebox_override("pressed", S.frame("button_pressed", 0.98, 1.0, margins + Vector4(0, 2, 0, -2)))
	button.add_theme_stylebox_override("disabled", S.frame("button_disabled", 0.9, 1.0, margins))
	var focus := AHFocusCorners.new()
	focus.color = Color(accent, 1.0) if accent != GOLD else TEXT
	AHFocusCorners.attach(button, focus)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_disabled_color", MUTED.darkened(0.3))
	button.add_theme_font_size_override("font_size", S.px(20))
	# O clique da interface em todo botão do jogo (SW_UI_Click).
	if not button.has_meta("click"):
		button.set_meta("click", true)
		button.pressed.connect(func(): Sound.click())


# ---------------------------------------------------------------- montagem

## Os textos da luta no kit (#60): a Barlow Condensed nos tamanhos de antes (AHKit.label_px).
static func _kit_label(text: String, size: int, color: Color = TEXT, kind: String = "body") -> Label:
	return AHKit.label_px(text, size, color, kind)


func _build() -> void:
	# A faixa da rodada (hud-target.md): "RODADA n", a linha com o ponto e os retratos quadrados da ordem.
	# A folga no fim: a área de conteúdo da peça (content_xywh) entra na ponta da direita, e o último retrato a cobria.
	_order_panel = PanelContainer.new()
	_order_panel.add_theme_stylebox_override("panel", AHKit.style("round_strip", Color.WHITE, Vector4(0, 0, ORDER_END_PAD, 0)))
	_order_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_order_panel)
	_order = HBoxContainer.new()
	_order.add_theme_constant_override("separation", int(ORDER_GAP))
	_order.alignment = BoxContainer.ALIGNMENT_CENTER
	_order.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_order_panel.add_child(_order)

	_message = AHKit.label("", "ability_name", TEXT, true)
	_message.position = Vector2(360, 150)
	_message.size = Vector2(1200, 44)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message)

	# O Registro com a tecla em aba (no alto à esquerda); o painel das linhas abre embaixo dele.
	_register = Button.new()
	_register.name = "Register"
	# A Plaqueta do kit (a Awesomic), apertável: abre e fecha as linhas.
	AHKit.style_as(_register, "plaque")
	_register.position = KIT_REGISTER.position
	_register.custom_minimum_size = KIT_REGISTER.size
	_register.size = KIT_REGISTER.size
	grow_hit(_register, Vector2(272, 112))
	_register.focus_mode = Control.FOCUS_NONE
	_register.pressed.connect(toggle_log)
	add_child(_register)
	var register_text := AHKit.label(tr("REGISTRO"), "plaque", TEXT, false, true)
	register_text.position = Vector2(24, 0)
	register_text.size = Vector2(180, KIT_REGISTER.size.y)
	register_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_register.add_child(register_text)
	var register_key := AHKitKey.make("combat_log")
	_register.add_child(register_key)
	register_key.position = Vector2(KIT_REGISTER.size.x - 58, 11)

	_log_panel = AHKit.panel_box("inset")
	_log_panel.position = Vector2(KIT_REGISTER.position.x, KIT_REGISTER.end.y + 8)
	_log_panel.custom_minimum_size = Vector2(460, 0)
	_log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_log_panel)
	var log_box := VBoxContainer.new()
	log_box.add_theme_constant_override("separation", 4)
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_panel.add_child(log_box)
	_log_title = AHKit.label(tr("REGISTRO"), "small", AHKit.AMBER, true, true)
	log_box.add_child(_log_title)
	_log = AHKit.label("", "text", TEXT)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.custom_minimum_size = Vector2(420, 0)
	log_box.add_child(_log)

	# O rodapé da vez do herói (as posições do alvo, na base de 1920x1080): o painel do herói, a aba e a barra da
	# habilidade, os quatro ícones e a grade das ações. _panel é a área inteira (o foco e a visibilidade).
	_panel = Control.new()
	_panel.name = "Dock"
	_panel.position = Vector2(0, DOCK_TOP)
	_panel.size = Vector2(1920, 1056.0 - DOCK_TOP)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	# O Painel do kit (panel_large), num Panel (e não PanelContainer): o retrato fica numa coluna à esquerda, e o nome e
	# as barras, na área à direita dele (HERO_TEXT_LEFT).
	var hero_panel := Panel.new()
	hero_panel.name = "HeroPanel"
	var hero_style := AHKit.style(AHKit.piece_of("panel", "large"))
	hero_style.content_margin_left = HERO_TEXT_LEFT
	hero_panel.add_theme_stylebox_override("panel", hero_style)
	hero_panel.position = KIT_HERO.position - _panel.position
	hero_panel.size = KIT_HERO.size
	hero_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(hero_panel)
	var hero_box := VBoxContainer.new()
	hero_box.add_theme_constant_override("separation", 4)
	hero_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_box.position = Vector2(hero_style.content_margin_left, hero_style.content_margin_top - 18)
	hero_box.size = KIT_HERO.size - Vector2(hero_style.content_margin_left + hero_style.content_margin_right, hero_style.content_margin_top + hero_style.content_margin_bottom - 36)
	hero_panel.add_child(hero_box)
	_hero_name = AHKit.label("", "hero_name", TEXT, true, true)
	_hero_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_hero_name.clip_text = true
	hero_box.add_child(_hero_name)
	_hero_hp = AHKit.bar("hero", 1, 1, "", "hero_value")
	_hero_hp.name = "HeroHp"
	_hero_hp.custom_minimum_size.y = 44
	hero_box.add_child(_hero_hp)
	_hero_instinct = AHKit.bar("instinct", 0, 200, "", "hero_value")
	_hero_instinct.name = "HeroInstinct"
	_hero_instinct.custom_minimum_size.y = 44
	_hero_instinct.mouse_filter = Control.MOUSE_FILTER_PASS
	_hero_instinct.tooltip_text = S.GLOSSARY.Instinto
	hero_box.add_child(_hero_instinct)
	# O retrato quadrado grande na coluna da esquerda (a área do nome e das barras começa em HERO_TEXT_LEFT).
	var frame := AHKit.panel("square_portrait")
	frame.position = Vector2(14, 14)
	frame.size = Vector2(184, 184)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_panel.add_child(frame)
	_hero_face = TextureRect.new()
	_hero_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hero_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_face.clip_contents = true
	frame.add_child(_hero_face)
	# Os estados do herói (fichas e efeitos) por cima do pé do retrato.
	_hero_status = HFlowContainer.new()
	_hero_status.add_theme_constant_override("h_separation", 4)
	_hero_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_status.position = Vector2(16, 150)
	_hero_status.size = Vector2(176, 44)
	hero_panel.add_child(_hero_status)

	# A aba acima da barra da habilidade: "Escolha um alvo" na mira; na vez, o que fazer.
	_target_tab = AHKit.panel("target_tab")
	_target_tab.name = "TargetTab"
	_target_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_target_tab)
	_description = AHKit.label("", "tab", TEXT, false, true)
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_tab.add_child(_description)

	# A barra da habilidade: o ícone, o nome e, depois da divisão, a faixa (dano ou cura).
	_ability_header = AHKit.panel("ability_header")
	_ability_header.name = "AbilityHeader"
	_ability_header.position = KIT_HEADER.position - _panel.position
	_ability_header.custom_minimum_size = KIT_HEADER.size
	_ability_header.size = KIT_HEADER.size
	_ability_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_ability_header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ability_header.add_child(header_row)
	_ability_icon = TextureRect.new()
	_ability_icon.custom_minimum_size = Vector2(40, 40)
	_ability_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ability_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ability_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(_ability_icon)
	_ability_name = AHKit.label("", "ability_name", TEXT, false, true)
	_ability_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ability_name.clip_text = true
	header_row.add_child(_ability_name)
	var divider := ColorRect.new()
	divider.color = Color(AHKit.SHADE, 0.55)
	divider.custom_minimum_size = Vector2(2, 40)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(divider)
	_ability_range = AHKit.label("", "range", TEXT, true)
	_ability_range.custom_minimum_size = Vector2(KIT_HEADER.end.x - KIT_HEADER_DIVIDER - 40, 0)
	_ability_range.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_row.add_child(_ability_range)

	_abilities = HBoxContainer.new()
	_abilities.name = "Abilities"
	_abilities.add_theme_constant_override("separation", int(KIT_SLOT_STEP - KIT_SLOT.size.x))
	_abilities.position = KIT_SLOT.position - _panel.position
	_panel.add_child(_abilities)

	# As ações numa grade 2x2 de peças chanfradas, com o ícone branco e a tecla em aba (F é a porta de saída).
	_actions = GridContainer.new()
	_actions.name = "Actions"
	_actions.columns = 2
	_actions.add_theme_constant_override("h_separation", int(KIT_ACTION_STEP.x - KIT_ACTION.size.x))
	_actions.add_theme_constant_override("v_separation", int(KIT_ACTION_STEP.y - KIT_ACTION.size.y))
	_actions.position = KIT_ACTION.position - _panel.position
	_panel.add_child(_actions)

	# A inspeção (#128): o botão com a tecla (combat_examine, trocável nas Opções) e o painel que ela abre.
	_inspect_button = AHKit.button(tr("Inspecionar"), "secondary")
	_inspect_button.name = "Inspect"
	_inspect_button.position = KIT_INSPECT.position - _panel.position
	_inspect_button.custom_minimum_size = KIT_INSPECT.size
	_inspect_button.size = KIT_INSPECT.size
	_inspect_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_inspect_button.focus_mode = Control.FOCUS_NONE
	_inspect_button.set_meta("click", true)
	_inspect_button.pressed.connect(func():
		Sound.click()
		toggle_inspect())
	_panel.add_child(_inspect_button)
	var inspect_key := AHKitKey.make("combat_examine")
	inspect_key.name = "Key"
	_inspect_button.add_child(inspect_key)
	_fit_inspect()
	_inspect_panel = AHKit.panel_box("large")
	_inspect_panel.name = "InspectPanel"
	_inspect_panel.position = KIT_INSPECT_PANEL.position - _panel.position
	_inspect_panel.custom_minimum_size = KIT_INSPECT_PANEL.size
	_inspect_panel.size = KIT_INSPECT_PANEL.size
	_inspect_panel.clip_contents = true
	_inspect_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_inspect_panel.visible = false
	_panel.add_child(_inspect_panel)
	# O painel cobre as habilidades; a aba da vez (o que fazer, e com a inspeção, o que a fecha) fica por cima dele.
	_panel.move_child(_target_tab, -1)
	for spec in ACTIONS:
		var button := Button.new()
		button.custom_minimum_size = KIT_ACTION.size
		grow_hit(button, Vector2(128, 112))
		button.text = ""
		AHKit.style_as(button, "icon")
		var icon := TextureRect.new()
		icon.texture = _action_icon(spec[1])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(34, 18)
		icon.size = Vector2(60, 48)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.name = "Icon"
		button.add_child(icon)
		var key := AHKitKey.make(spec[3])
		button.add_child(key)
		key.position = KIT_ACTION.size - Vector2(46, 46)
		if spec[1] == "item":
			# Quanto de comida há na Mochila, no canto de cima.
			var count := AHKit.label("", "small", AHKit.AMBER, true)
			count.name = "Count"
			count.position = Vector2(12, 6)
			button.add_child(count)
		button.pressed.connect(_on_action.bind(spec[1]))
		# A dica só com o mouse em cima ou com o foco do teclado/controle; o foco que a vez põe sozinha não abre (#56).
		button.focus_entered.connect(func(): if S.using_keys and not _quiet_focus: _describe_action(spec[1]))
		button.mouse_entered.connect(_describe_action.bind(spec[1]))
		button.mouse_exited.connect(_hide_tip)
		button.set_meta("kind", spec[1])
		button.set_meta("click", true)
		button.pressed.connect(func(): Sound.click())
		_actions.add_child(button)

	# O nome do alvo apontado (#57): a plaqueta escura com a linha na cor dos inimigos embaixo.
	_target_label = AHKit.label("", "world", TEXT, true, true)
	# Por cima da ficha do Examinar (z 20): o nome do apontado não some atrás dela.
	_target_label.z_index = 21
	_target_label.add_theme_stylebox_override("normal", AHKit.style("target_tab"))
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_label.custom_minimum_size = KIT_TARGET_NAME
	_target_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_label.visible = false
	var line := ColorRect.new()
	line.name = "Line"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = -7
	line.offset_bottom = -3
	line.offset_left = 14
	line.offset_right = -14
	_target_label.add_child(line)
	_tip = AHKit.panel_box("large")
	_tip.custom_minimum_size = Vector2(460, 0)
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	add_child(_tip)
	# Depois da dica: desenhado por cima dela.
	add_child(_target_label)
	# O nome de quem o mouse aponta (#128): a mesma plaqueta do alvo, sem a linha da cor do lado.
	_hover_label = AHKit.label("", "world", TEXT, true, true)
	_hover_label.name = "HoverName"
	_hover_label.z_index = 21
	_hover_label.add_theme_stylebox_override("normal", AHKit.style("target_tab"))
	_hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hover_label.custom_minimum_size = KIT_TARGET_NAME
	_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_hover_label.visible = false
	add_child(_hover_label)
	_tip_box = VBoxContainer.new()
	_tip_box.add_theme_constant_override("separation", 6)
	_tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(_tip_box)

	_result = AHKit.panel_box("large")
	_result.name = "ResultPopup"
	_result.position = Vector2(960.0 - POPUP_WIDTH * 0.5, POPUP_TOP)
	_result.custom_minimum_size = Vector2(POPUP_WIDTH, 0)
	_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result.visible = false
	add_child(_result)
	_result_close = AHKit.button("X", "icon")
	_result_close.name = "ResultClose"
	_result_close.custom_minimum_size = Vector2(44, 44)
	_result_close.size = Vector2(44, 44)
	_result_close.focus_mode = Control.FOCUS_NONE
	_result_close.tooltip_text = tr("Fechar")
	_result_close.visible = false
	_result_close.pressed.connect(func():
		if _result.visible:
			_result.visible = false
			result_closed.emit())
	add_child(_result_close)
	_restyle_kit()


## O ícone branco de cada ação: mover, defender, a Mochila e a saída (F é a porta com seta, não uma mira).
func _action_icon(kind: String) -> Texture2D:
	match kind:
		"flee":
			return AHKit.texture("exit")
		"move":
			return AHKit.legacy_icon("ui-arrow-right")
		"defend":
			return AHKit.legacy_icon("intent-block")
	return AHKit.legacy_icon("item-generic")


## As cores do kit que dependem do daltonismo (a linha do nome do alvo acompanha a cor das máquinas).
func _restyle_kit() -> void:
	(_target_label.get_node("Line") as ColorRect).color = AHKit.enemy_hp()


# ---------------------------------------------------------------- abrir, fechar e atualizar

func open(new_session: AHCombatSession) -> void:
	session = new_session
	visible = true
	_result.visible = false
	for bar in _unit_bars.values():
		if bar.has_meta("intent"):
			bar.get_meta("intent").queue_free()
		bar.queue_free()
	_unit_bars.clear()
	for unit in session.units():
		_unit_bars[unit.id] = _make_plate(unit)
	_reset_log()
	refresh()


## Luta nova (a arena e o HUD são os mesmos em todas as lutas da rua): o registro começa fechado e vazio, e cada lance
## dela mostra a própria linha (a contagem da luta anterior escondia as linhas da nova).
func _reset_log() -> void:
	if _log_tween:
		_log_tween.kill()
	_log_open = false
	_log_seen = 0
	_log.text = ""
	_log_panel.visible = false
	_log_panel.modulate.a = 1.0


func close() -> void:
	stop_examine()
	visible = false
	if arena != null:
		arena.show_ring("")
	sheet.close()
	_close_bag()
	_clear_markers()
	_hide_tip()
	for bar in _unit_bars.values():
		if bar.has_meta("intent"):
			bar.get_meta("intent").queue_free()
		bar.queue_free()
	_unit_bars.clear()


func _art_of(unit: AHCombat.Unit) -> Dictionary:
	return arena.hero_art(unit.hero_id).get("idle", {}) if unit.is_player else arena.enemy_art(unit.enemy_id).get("idle", {})


## A vida sob os pés (hud-target.md): a Barra do kit, ciano nos heróis e vermelha nas máquinas, com o valor por dentro
## e, em quem age, a moldura âmbar; os estados por cima dela. Nos inimigos, a intenção (o que ele faria se a vez fosse
## agora) é uma plaqueta à parte, acima da cabeça (meta "intent"): nunca cobre o corpo.
func _make_plate(unit: AHCombat.Unit) -> Control:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	plate.custom_minimum_size = Vector2(PLATE_PLAYER if unit.is_player else PLATE_ENEMY, 0)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(box)
	var status := HFlowContainer.new()
	status.name = "Status"
	status.alignment = FlowContainer.ALIGNMENT_CENTER
	status.add_theme_constant_override("h_separation", 4)
	status.add_theme_constant_override("v_separation", 3)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(status)
	if not unit.is_player:
		# A intenção: o que ele faria se a vez dele fosse agora (engine.enemy_intent); muda conforme a luta. O ícone vem
		# antes do texto.
		var intent_panel := AHKit.panel("target_tab")
		intent_panel.name = "IntentRow"
		intent_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		intent_panel.custom_minimum_size = Vector2(PLATE_ENEMY, 0)
		plate.set_meta("intent", intent_panel)
		add_child(intent_panel)
		move_child(intent_panel, 0)
		var intent_row := HBoxContainer.new()
		intent_row.add_theme_constant_override("separation", 6)
		intent_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		intent_panel.add_child(intent_row)
		var intent_icon := TextureRect.new()
		intent_icon.name = "IntentIcon"
		intent_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		intent_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		intent_icon.custom_minimum_size = Vector2.ONE * S.px(22)
		intent_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		intent_icon.mouse_filter = Control.MOUSE_FILTER_PASS
		intent_row.add_child(intent_icon)
		var intent := AHKit.label("", "small", S.ENEMY, true)
		intent.name = "Intent"
		intent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		intent.custom_minimum_size = Vector2(150, 0)
		intent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		intent.mouse_filter = Control.MOUSE_FILTER_PASS
		intent_row.add_child(intent)
	# A barra por último: ela fica na linha das outras (sob os pés), e o resto da placa sobe por cima.
	# A Barra do kit: a calha main_bar com o preenchimento ciano nos heróis e vermelho nas máquinas; quem age ganha a
	# moldura âmbar da escolha (selected_frame) por cima.
	var hp := AHKit.bar("hero" if unit.is_player else "enemy", unit.hp, unit.max_hp, "", "world")
	hp.name = "Hp"
	hp.custom_minimum_size = Vector2(0, PLATE_BAR_HEIGHT)
	box.add_child(hp)
	var active := AHKit.selected_overlay()
	active.name = "Active"
	active.visible = false
	hp.add_child(active)
	add_child(plate)
	move_child(plate, 0)
	return plate


## Tira os filhos já (não só no fim do quadro), para o painel medir o tamanho novo na hora.
static func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## Um estado (S.statuses): o ícone da entrega #18 tingido de bom ou ruim (a forma também diz: bom tem cantoneiras retas
## no topo, ruim tem o topo chanfrado), com o número de fichas ou de vezes; o nome e a explicação ficam na dica do mouse
## (e na do foco, ao mirar). Sem ícone (Cego, Fraco, Imobilizado, Trauma), a ficha escrita de antes.
func _status_chip(entry: Array, size: int = 15) -> PanelContainer:
	var good: bool = entry[1]
	var icon_name: String = entry[2] if entry.size() > 2 else ""
	var chip := PanelContainer.new()
	var style := AHKit.chip_style(S.OK if good else S.DANGER)
	style.content_margin_left = 3 if icon_name != "" else 5
	style.content_margin_right = 4 if icon_name != "" else 5
	chip.add_theme_stylebox_override("panel", style)
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	chip.tooltip_text = S.status_tip(entry) if entry.size() > 4 else String(entry[0])
	var texture := S.combat_icon("status-%s_%s" % [icon_name, "good" if good else "bad"]) if icon_name != "" else null
	if texture == null:
		chip.add_child(_kit_label(entry[0], size, TEXT))
		return chip
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * S.px(size + 7)
	icon.modulate = S.OK if good else S.DANGER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.name = "Icon"
	row.add_child(icon)
	if int(entry[3]) > 0:
		var count := _kit_label(str(entry[3]), size, TEXT, "bold")
		count.name = "Count"
		row.add_child(count)
	return chip


## Atualiza placas, ordem dos turnos, painel do herói e o registro.
func refresh() -> void:
	if session == null:
		return
	var current := session.state.current_turn_unit_id
	for unit in session.units():
		var plate: PanelContainer = _unit_bars.get(unit.id)
		if plate == null:
			continue
		var card: AHSpriteCard = arena.cards.get(unit.id)
		# Quem caiu (o inimigo derrubado, o herói Caído, #178) perde a placa inteira: a barra, a moldura de quem age e os
		# estados. O herói no Último Fôlego (vida 0, ainda na luta) fica com ela.
		plate.visible = card != null and card.visible and AHCombatEngine.alive_any(unit)
		var box := plate.get_child(0)
		var hp: AHKitBar = box.get_node("Hp")
		hp.set_value(unit.hp, unit.max_hp, "%d/%d" % [unit.hp, unit.max_hp] if not unit.deaths_door else tr("Último Fôlego"))
		(hp.get_node("Active") as Control).visible = unit.id == current
		if not unit.is_player:
			var row := plate.get_meta("intent") as Control
			row.visible = plate.visible and unit.hp > 0
			row.reset_size.call_deferred()
			if unit.hp > 0:
				_show_intent(row.find_child("Intent", true, false), session.engine.enemy_intent(unit.id))
		var status: HFlowContainer = box.get_node("Status")
		for child in status.get_children():
			child.queue_free()
		for entry in S.statuses(unit):
			status.add_child(_status_chip(entry))
		# A placa encolhe de volta quando a intenção ou os estados ficam mais curtos.
		plate.reset_size.call_deferred()
	_refresh_order(current)
	arena.show_ring(current)
	_refresh_log()
	var actor := session.current_actor()
	if actor != null and actor.is_player:
		_show_hero(actor)


## A linha da intenção na placa do inimigo: o que ele vai fazer, sem dizer em quem (#128, decisão do Lucas); "?" quando
## ele está entre dois planos parecidos.
func _show_intent(label: Label, intent: Dictionary) -> void:
	var text := ""
	var color: Color = S.ENEMY
	# O ícone da intenção (art/ui/icons/intent-*): ataque, ataque em área (mais de um alvo de uma vez), cura, bloqueio,
	# mover, atordoado; sem plano claro, a interrogação.
	var icon := "unknown"
	match intent.kind:
		"attack":
			text = tr(intent.name)
			icon = "attack_area" if intent.target_ids.size() > 1 and not intent.either else "attack"
		"heal":
			text = tr("%s (se cura)") % tr(intent.name)
			color = S.OK
			icon = "heal"
		"defend":
			text = tr("%s (bloqueio)") % tr(intent.name)
			color = S.BLUE
			icon = "block"
		"move":
			text = tr(intent.name)
			color = S.MUTED
			icon = "move"
		"stunned":
			text = tr(intent.name)
			color = S.MUTED
			icon = "stunned"
	if text != "" and not intent.sure and not intent.either:
		text += " ?"
	label.text = text
	label.add_theme_color_override("font_color", color)
	var tip := tr("Intenção: o que ele faria se a vez fosse agora. Muda conforme a luta (quem cai, quem protege, a posição)%s.") % (
		"" if intent.sure else tr("; com \"?\", ele está entre dois planos parecidos"))
	label.tooltip_text = tip
	var icon_rect := label.get_parent().get_node_or_null("IntentIcon") as TextureRect
	if icon_rect != null:
		icon_rect.texture = S.combat_icon("intent-" + icon) if text != "" else null
		icon_rect.modulate = color
		icon_rect.visible = text != ""
		icon_rect.tooltip_text = tip


## A faixa da rodada (hud-target.md): "RODADA n", a linha com o ponto e os retratos quadrados da ordem, com o fundo
## avermelhado nas máquinas e a borda âmbar em quem age; quem já agiu sai da fila.
func _refresh_order(current: String) -> void:
	_clear(_order)
	var round_label := AHKit.label(tr("RODADA %d") % session.state.round, "round", TEXT, false, true)
	round_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_order.add_child(round_label)
	var mark := Control.new()
	mark.custom_minimum_size = Vector2(36, KIT_PORTRAIT)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.draw.connect(func():
		mark.draw_line(Vector2(0, KIT_PORTRAIT * 0.5), Vector2(36, KIT_PORTRAIT * 0.5), Color(AHKit.AMBER, 0.85), 2.0)
		mark.draw_circle(Vector2(18, KIT_PORTRAIT * 0.5), 4.0, AHKit.AMBER))
	_order.add_child(mark)
	for item in session.state.initiative_queue:
		var unit := session.state.find_unit(item.unit_id)
		if unit == null or (unit.hp <= 0 and not unit.deaths_door) or (item.acted and item.unit_id != current):
			continue
		_order.add_child(_order_face(unit, item.unit_id == current))
	# Fila longa demais para a largura: os retratos encolhem até caber; no menor retrato, o espaço entre eles também. A
	# ponta da direita fica sempre livre (a folga é da peça), e a faixa fica dentro da margem enquanto couber.
	_order.add_theme_constant_override("separation", int(ORDER_GAP))
	var width := _order_panel.get_combined_minimum_size().x
	if width > ORDER_MAX_WIDTH:
		var faces: Array = _order.get_children().filter(func(child): return child.has_meta("unit_id"))
		var side := maxf(ORDER_MIN_PORTRAIT, KIT_PORTRAIT - (width - ORDER_MAX_WIDTH) / maxf(1.0, faces.size()))
		for cell in faces:
			cell.custom_minimum_size = Vector2.ONE * side
		width = _order_panel.get_combined_minimum_size().x
		if width > ORDER_MAX_WIDTH:
			var gaps := maxf(1.0, _order.get_child_count() - 1)
			_order.add_theme_constant_override("separation", int(maxf(ORDER_MIN_GAP, ORDER_GAP - ceilf((width - ORDER_MAX_WIDTH) / gaps))))
	_order_panel.size = _order_panel.get_combined_minimum_size()
	var left := KIT_ROUND_CENTER.x - _order_panel.size.x * 0.5
	_order_panel.position = Vector2(clampf(left, ORDER_EDGE, maxf(ORDER_EDGE, 1920.0 - ORDER_EDGE - _order_panel.size.x)), KIT_ROUND_CENTER.y)


## Um retrato quadrado da ordem: o rosto no square_portrait, o fundo avermelhado nas máquinas e a borda âmbar em quem
## age. Informativo: não pega o mouse.
func _order_face(unit: AHCombat.Unit, now: bool) -> Control:
	var cell := AHKit.panel("square_portrait")
	cell.custom_minimum_size = Vector2(KIT_PORTRAIT, KIT_PORTRAIT)
	# Quadrado mesmo quando a fila longa o encolhe (a linha da faixa não o estica na altura).
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.set_meta("unit_id", unit.id)
	cell.tooltip_text = unit.display_name
	if not unit.is_player:
		var tint := ColorRect.new()
		tint.color = Color(AHKit.enemy_hp(), 0.32)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(tint)
	var face := TextureRect.new()
	face.texture = S.face_texture(_art_of(unit))
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.clip_contents = true
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(face)
	if now:
		var ring := Panel.new()
		ring.name = "Now"
		ring.add_theme_stylebox_override("panel", AHKit.outline(AHKit.AMBER, 3))
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(ring)
	return cell


## O painel do herói da vez: o retrato quadrado grande, o nome, a vida e o instinto (em ferrugem, decisão do Lucas).
func _show_hero(actor: AHCombat.Unit) -> void:
	if _hero_face.get_meta("unit", "") != actor.id:
		_hero_face.texture = S.face_texture(_art_of(actor))
		_hero_face.set_meta("unit", actor.id)
	_hero_name.text = actor.display_name.to_upper()
	_hero_hp.set_value(actor.hp, actor.max_hp, ("%d/%d" % [actor.hp, actor.max_hp]) + (tr(" · Último Fôlego") if actor.deaths_door else ""))
	_hero_instinct.set_value(actor.instinct, 200, "%d/200" % actor.instinct)
	_hero_instinct.tooltip_text = tr("Instinto %d/200 · em 200, crise") % actor.instinct + "\n" + S.GLOSSARY.Instinto
	for child in _hero_status.get_children():
		child.queue_free()
	for entry in S.statuses(actor):
		_hero_status.add_child(_status_chip(entry, 16))
	if actor.trauma:
		_hero_status.add_child(_status_chip([tr("Trauma"), false], 16))


## Fichas e efeitos da unidade em palavras curtas (o registro e os testes usam).
func status_text(unit: AHCombat.Unit, _short: bool) -> String:
	return " · ".join(S.statuses(unit).map(func(e): return e[0]))


## Teclado e controle (#5): a tela de cima da luta, onde o foco fica e onde Interagir confirma o botão com foco.
func _focus_scope() -> Control:
	if _bag != null:
		return _bag
	if _result.visible:
		return _result
	# Escolhendo o alvo: os marcadores ficam no próprio HUD.
	if _choosing != "":
		return self
	return _panel if waiting else null


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = event.position
	if visible and _close_popup_input(event):
		get_viewport().set_input_as_handled()
		return
	if visible and _examine_input(event):
		get_viewport().set_input_as_handled()
		return
	if visible and S.press_focused(_focus_scope(), event):
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_tick_result(_delta)
	if _bag != null or _result.visible or (waiting and _choosing == ""):
		# O foco que o jogo devolve (a Mochila fechada, um botão que sumiu) não abre a dica.
		_quiet_focus = true
		S.keep_focus(_focus_scope())
		_quiet_focus = false
	if not visible or session == null or arena == null:
		return
	if _description.text != _tab_text:
		_tab_text = _description.text
		_place_tab()
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# As placas e intenções acima da cabeça (o ALVO desvia delas), lidas depois de as escalonadas subirem.
	var short_controls: Array[Control] = []
	var widths := _plate_widths(camera)
	for unit_id in _unit_bars:
		var plate: Control = _unit_bars[unit_id]
		var card: AHSpriteCard = arena.cards.get(unit_id)
		if card == null or not plate.visible:
			continue
		if widths.has(unit_id) and not is_equal_approx(plate.custom_minimum_size.x, widths[unit_id]):
			plate.custom_minimum_size.x = widths[unit_id]
			# A intenção quebra em mais linhas na placa estreita (a largura mínima dela segurava a placa larga).
			var row := (plate.get_meta("intent") if plate.has_meta("intent") else null) as Control
			var intent: Control = row.find_child("Intent", true, false) if row != null else null
			if intent != null:
				# A placa menos as margens da plaqueta (as do target_tab), o ícone (que cresce com o texto) e o espaço
				# entre eles.
				row.custom_minimum_size.x = widths[unit_id]
				row.size = Vector2(widths[unit_id], 0)
				var box: StyleBox = row.get_theme_stylebox("panel") if row is PanelContainer else null
				var margins := box.content_margin_left + box.content_margin_right if box != null else 16.0
				intent.custom_minimum_size.x = maxf(40.0, widths[unit_id] - margins - S.px(22) - 6.0)
			plate.size = Vector2(widths[unit_id], 0)
		var feet := camera.unproject_position(card.global_position)
		var head := camera.unproject_position(card.global_position + Vector3(0, card.body_height * 1.05, 0))
		var short := card.body_height < SHORT_HEIGHT or _plate_stagger.has(unit_id)
		# O limite é o da barra (a última da placa): o resto sobe por cima dela.
		var bar_height: float = (plate.get_child(0).get_node("Hp") as Control).size.y
		var dock_limit := _dock_top() - bar_height - 6 if _panel.visible else INF
		# A placa que, presa pelo painel de baixo, subiria por mais da metade do corpo vai para cima da cabeça, como a
		# do baixinho (o Relé de Defesa sumia inteiro atrás da própria placa no texto Maior, #63).
		if not short and minf(feet.y + 10.0, dock_limit) < feet.y - (feet.y - head.y) * 0.5:
			short = true
		# A intenção e os estados, por cima da barra, também não cobrem o corpo: passando de um quinto da altura dele, a
		# placa inteira vai para cima da cabeça (a #63 no kit, com as plaquetas de três linhas do Maior).
		if not short and plate.size.y - bar_height > (feet.y - head.y) * 0.2:
			short = true
		var y := plate_y(feet.y, head.y, short, plate.size.y, dock_limit)
		if not short:
			# A barra (a última da placa) na linha de todas: sob os pés, sem passar do rodapé; a intenção e os estados
			# ficam por cima dela.
			y = minf(feet.y + 10.0, dock_limit) - (plate.size.y - bar_height)
		# A intenção acima da cabeça (acima da placa, no baixinho), sem subir na faixa da rodada.
		var tag := (plate.get_meta("intent") if plate.has_meta("intent") else null) as Control
		plate.position = Vector2(feet.x - plate.size.x * 0.5, y)
		if short:
			short_controls.append(plate)
		# Com o popup do fim aberto, as intenções saem (a luta acabou, e elas subiriam por trás dele).
		if tag != null and _result.visible:
			tag.visible = false
		if tag != null and tag.visible:
			var crown := camera.unproject_position(card.global_position + Vector3(0, card.head_height() + 0.15, 0))
			var bottom := minf(crown.y, plate.position.y - 4.0) if short else crown.y
			tag.position = Vector2(feet.x - tag.size.x * 0.5, maxf(INTENT_TOP, bottom - tag.size.y))
			short_controls.append(tag)
	_lift_staggered()
	var short_plates: Array[Rect2] = []
	for control in short_controls:
		short_plates.append(Rect2(control.position, control.size))
	for marker in _markers:
		if marker.has_meta("card"):
			# O botão do alvo cobre o corpo inteiro na tela (do pé à cabeça, na largura do corpo).
			var body := _body_rect(camera, marker.get_meta("card"))
			marker.position = body.position
			marker.size = body.size
	if _target_label != null and _target_label.visible and _target_label.has_meta("card"):
		var pointed: AHSpriteCard = _target_label.get_meta("card")
		if is_instance_valid(pointed):
			var top := camera.unproject_position(pointed.global_position + Vector3(0, pointed.head_height() + 0.15, 0))
			_target_label.position = top - Vector2(_target_label.size.x * 0.5, _target_label.size.y)
			# Nos baixinhos a placa fica acima da cabeça: o ALVO sobe para cima dela.
			for rect in short_plates:
				if rect.intersects(Rect2(_target_label.position, _target_label.size)):
					_target_label.position.y = rect.position.y - _target_label.size.y - 4
			# Na mira, a dica da habilidade sai de cima do apontado (ficava sobre o corpo e o ALVO).
			if _tip.visible:
				_dodge_tip(_body_rect(camera, pointed).merge(Rect2(_target_label.position, _target_label.size)))
	_update_sheet(camera)
	_update_hover(camera)
	# INSPECIONAR só aperta quando liga ou desliga de verdade (na vez de um herói, fora da mira e da Mochila).
	_inspect_button.disabled = not _inspect_on and (not waiting or _choosing != "" or _bag != null)
	for marker in _markers.filter(func(m): return not m.has_meta("card")) + _preview_marks:
		var target: Vector3 = marker.get_meta("world")
		var screen := camera.unproject_position(target)
		marker.position = screen - Vector2(marker.size.x * 0.5, marker.size.y + 24)
		# O marcador do alvo não cobre a placa de um baixinho (que fica acima da cabeça): sobe para cima dela.
		for rect in short_plates:
			if rect.intersects(Rect2(marker.position, marker.size)):
				marker.position.y = rect.position.y - marker.size.y - 6


## A ficha que abria ao apontar saiu da luta (#128, decisão do Lucas: era informação demais de uma vez); o mouse em cima
## só marca quem é, pela placa. Com a inspeção ligada, o painel de baixo mostra quem o mouse aponta ou, sem ninguém
## apontado, quem foi escolhido (clique, setas).
func _update_sheet(_camera: Camera3D) -> void:
	sheet.close()
	if not _inspect_on:
		return
	var unit_id := _pointed_unit()
	if unit_id == "" and not _examine.is_empty():
		unit_id = _examine[_examine_index]
	var unit := session.state.find_unit(unit_id) if unit_id != "" else null
	if unit == null:
		return
	var shown := String(_inspect_info.get("id", ""))
	if unit_id != shown:
		# A luz segue quem o painel mostra (o apontado ou o escolhido).
		for other in session.units():
			var other_card: AHSpriteCard = arena.cards.get(other.id)
			if other_card != null:
				other_card.set_highlight(S.GOLD, S.TARGET_ACTIVE if other.id == unit_id else 0.0)
	var info := AHCharacterSheet.from_unit(session, unit, arena.boss_fight and not unit.is_player)
	if info != _inspect_info:
		_inspect_info = info
		_fill_inspect(info)


## O mouse em cima (#128): sem a inspeção e fora da mira, o nome de quem é apontado numa plaqueta acima da cabeça e a
## luz leve no corpo; com a inspeção, a luz segue quem o painel mostra.
func _update_hover(camera: Camera3D) -> void:
	var unit_id := ""
	if not _inspect_on and _markers.is_empty() and _bag == null and not _result.visible:
		unit_id = _pointed_unit()
	var unit := session.state.find_unit(unit_id) if unit_id != "" and session != null else null
	var card: AHSpriteCard = arena.cards.get(unit_id) if unit != null else null
	if card == null or not unit.is_standing():
		unit_id = ""
	if unit_id != _hovered:
		var before: AHSpriteCard = arena.cards.get(_hovered) if _hovered != "" else null
		if before != null and is_instance_valid(before) and _markers.is_empty() and not _inspect_on:
			before.set_highlight(S.GOLD, 0.0)
		_hovered = unit_id
		if card != null:
			card.set_highlight(S.GOLD, S.TARGET_VALID)
			_hover_label.text = unit_name(unit.display_name)
	_hover_label.visible = card != null
	if card != null:
		_hover_label.reset_size()
		var top := camera.unproject_position(card.global_position + Vector3(0, card.head_height() + 0.15, 0))
		_hover_label.position = top - Vector2(_hover_label.size.x * 0.5, _hover_label.size.y)
		var plate: Control = _unit_bars.get(unit_id)
		var tag: Control = plate.get_meta("intent") if plate != null and plate.has_meta("intent") else null
		if tag != null and tag.visible and Rect2(tag.position, tag.size).intersects(Rect2(_hover_label.position, _hover_label.size)):
			_hover_label.position.y = tag.position.y - _hover_label.size.y - 4


## Quem o mouse aponta: o corpo na tela, a placa (a intenção pega o mouse para a dica dela) ou o botão do alvo na mira.
func _pointed_unit() -> String:
	if sheet.touch_mode:
		return ""
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null and _markers.has(hovered) and hovered.has_meta("unit_id"):
		return hovered.get_meta("unit_id")
	if hovered == null:
		return unit_at(_mouse)
	for plate_id in _unit_bars:
		var tag = (_unit_bars[plate_id].get_meta("intent") if _unit_bars[plate_id].has_meta("intent") else null)
		if _unit_bars[plate_id].is_ancestor_of(hovered) or (tag != null and (tag == hovered or tag.is_ancestor_of(hovered))):
			return plate_id
	return ""


## A inspeção (teclado, controle, o botão): liga com quem age escolhido; as setas e o clique no corpo escolhem outro; a
## tecla de novo, o botão ou Voltar desligam. Só na vez de um herói, fora da mira e da Mochila.
func _examine_input(event: InputEvent) -> bool:
	if not _inspect_on:
		if not event.is_action_pressed("combat_examine"):
			return false
		toggle_inspect()
		return _inspect_on
	if event.is_action_pressed("combat_examine") or S.is_back(event):
		stop_examine()
		return true
	for spec in [[-1, ["move_left", "ui_left"]], [1, ["move_right", "ui_right"]]]:
		for action in spec[1]:
			if event.is_action_pressed(action):
				_examine_index = posmod(_examine_index + spec[0], _examine.size())
				_paint_examine()
				return true
	# O clique (ou o toque) num corpo escolhe quem o painel mostra.
	var click: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if click:
		var unit_id := unit_at(event.position)
		if _examine.has(unit_id):
			_examine_index = _examine.find(unit_id)
			_paint_examine()
			return true
	# Com a inspeção ligada, o resto (as habilidades, Interagir) espera; o mouse e o toque seguem livres.
	return event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion


## Liga ou desliga a inspeção (#128).
func toggle_inspect() -> void:
	if _inspect_on:
		stop_examine()
		return
	if not waiting or _choosing != "" or _bag != null or session == null:
		return
	var standing := session.units().filter(func(u): return u.is_standing() and arena.cards.has(u.id) and arena.cards[u.id].visible)
	standing.sort_custom(func(a, b): return arena.cards[a.id].global_position.x < arena.cards[b.id].global_position.x)
	_examine = standing.map(func(u): return u.id)
	if _examine.is_empty():
		return
	_examine_index = maxi(0, _examine.find(_actor_id))
	_inspect_on = true
	_inspect_info = {}
	_hide_tip()
	_inspect_panel.visible = true
	_inspect_button.add_child(AHKit.selected_overlay())
	_paint_examine()
	_examine_note = _description.text
	# Curta, na largura da aba: o que escolhe e o que fecha.
	_description.text = tr("Inspecionar · %s/%s ou clique · %s fecha") % [S.key_name("move_left"), S.key_name("move_right"), S.key_name("combat_examine")]
	_place_tab()


func stop_examine() -> void:
	if not _inspect_on:
		return
	_inspect_on = false
	_examine = []
	_inspect_info = {}
	_inspect_panel.visible = false
	var overlay := _inspect_button.get_node_or_null("Selected")
	if overlay != null:
		_inspect_button.remove_child(overlay)
		overlay.queue_free()
	_paint_examine()
	_description.text = _examine_note
	_place_tab()


## O botão INSPECIONAR com a tecla no fim e o texto terminando antes dela; preso pela direita (cresce para a esquerda no
## texto Maior, sem entrar nas ações).
func _fit_inspect() -> void:
	# A letra das abas da luta (o vão entre as habilidades e as ações é estreito para a dos botões da Estação).
	_inspect_button.add_theme_font_size_override("font_size", AHKit.size("tab"))
	AHStationReport.fit_key(_inspect_button, 10.0)
	# No texto Maior, a letra encolhe o que falta para caber no vão (sem encostar na quarta habilidade).
	var room := KIT_INSPECT.size.x
	if _inspect_button.size.x > room:
		var font := _inspect_button.get_theme_font_size("font_size")
		var text_width := _inspect_button.size.x - _inspect_button.get_theme_stylebox("normal").get_minimum_size().x
		var fit := (text_width - (_inspect_button.size.x - room)) / maxf(1.0, text_width)
		_inspect_button.add_theme_font_size_override("font_size", maxi(AHKit.size("small"), int(font * fit)))
		AHStationReport.fit_key(_inspect_button, 10.0)
	_inspect_button.position.x = KIT_INSPECT.end.x - _inspect_button.size.x - _panel.position.x


## A inspeção ligada (#128).
func inspecting() -> bool:
	return _inspect_on


## A luz da escolha em quem está sendo inspecionado (a mesma do alvo, #57).
func _paint_examine() -> void:
	for unit in session.units():
		var card: AHSpriteCard = arena.cards.get(unit.id)
		if card != null:
			var on: bool = not _examine.is_empty() and _examine[_examine_index] == unit.id
			# A luz de quem age (mais leve que a do alvo apontado: aqui só se olha).
			card.set_highlight(S.GOLD, S.TARGET_ACTIVE if on else 0.0)


## O painel da inspeção (#128): à esquerda o retrato, o nome, a espécie e o papel (ou a máquina), a vida, o instinto e a
## velocidade; no meio os efeitos passivos; à direita os estados, cada um com o que faz. Sem caber (muitos estados, o
## texto Maior), as explicações saem, primeiro as dos passivos, depois as dos estados; por fim, os nomes numa linha.
func _fill_inspect(info: Dictionary) -> void:
	var margins: Vector2 = _inspect_panel.get_theme_stylebox("panel").get_minimum_size()
	var inner := KIT_INSPECT_PANEL.size - margins
	for level in 5:
		_clear(_inspect_panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inspect_panel.add_child(row)
		var identity := _inspect_identity(info, level)
		row.add_child(identity)
		# As duas colunas dividem o resto pelo que cada uma tem (a dos estados vazia fica estreita).
		var columns := inner.x - identity.custom_minimum_size.x - 36.0 - 4.0
		var share := float(maxi(1, info.passives.size())) / float(maxi(1, info.passives.size()) + maxi(1, info.states.size()))
		var passives := clampf(columns * share, 220.0, columns - 220.0)
		row.add_child(_inspect_list(tr("Efeitos passivos"), info.passives, tr("Nenhum"), level < 1, level >= 3, passives, "Passives"))
		row.add_child(_inspect_list(tr("Estados"), info.states, tr("Nenhum agora"), level < 2, level >= 3, columns - passives, "States"))
		var need := _inspect_panel.get_combined_minimum_size()
		if need.x <= KIT_INSPECT_PANEL.size.x + 0.5 and need.y <= KIT_INSPECT_PANEL.size.y + 0.5:
			break
	# O painel fica no espaço dele (sem crescer sobre o botão nem abaixo da HUD); o que sobrar no último nível é cortado.
	_inspect_panel.size = KIT_INSPECT_PANEL.size


func _inspect_identity(info: Dictionary, level: int = 0) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = "Identity"
	column.custom_minimum_size.x = 400 if level < 4 else 340
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	if not info.get("art", {}).is_empty():
		var face := AHKit.portrait(S.face_texture(info.art), 56)
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(face)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(names)
	var title := AHKit.label(String(info.name), "row", AHKit.enemy_hp() if info.enemy else TEXT, true, true)
	title.name = "Name"
	title.clip_text = true
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	names.add_child(title)
	var kind := String(info.get("kind", ""))
	if int(info.get("level", 0)) > 0:
		kind += (" · " if kind != "" else "") + tr("Nível %d") % int(info.level)
	if kind != "":
		var kind_label := AHKit.label(kind, "small", AHKit.AMBER)
		kind_label.name = "Kind"
		kind_label.clip_text = true
		names.add_child(kind_label)
	var life := AHKit.bar("enemy" if info.enemy else "hero", int(info.hp), maxi(1, int(info.max_hp)), tr("Vida %d/%d") % [info.hp, info.max_hp], "small")
	life.name = "Life"
	life.custom_minimum_size = Vector2(0, 24)
	column.add_child(life)
	if int(info.instinct) >= 0:
		var instinct := AHKit.bar("instinct", int(info.instinct), 200, tr("Instinto %d/200") % info.instinct, "small")
		instinct.name = "Instinct"
		instinct.custom_minimum_size = Vector2(0, 20)
		column.add_child(instinct)
	var speed := AHKit.label(tr("Velocidade %d · quem é mais rápido age antes") % info.speed if level < 1 else tr("Velocidade %d") % info.speed, "small", TEXT)
	speed.name = "Speed"
	speed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speed.custom_minimum_size.x = column.custom_minimum_size.x
	column.add_child(speed)
	return column


## Uma coluna da inspeção: o título em âmbar e cada linha na cor de bom ou ruim (com + ou −), com o que faz embaixo.
func _inspect_list(heading: String, rows: Array, empty: String, tips: bool, joined: bool, width: float, node_name: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = node_name
	column.custom_minimum_size.x = width
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(AHKit.label(heading, "small", AHKit.AMBER, true, true))
	var add := func(text: String, color: Color, part: String):
		var label := AHKit.label(text, "small", color, part == "Row")
		label.set_meta("part", part)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = width
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		column.add_child(label)
	if rows.is_empty():
		add.call(empty, MUTED, "Empty")
		return column
	if joined:
		for good in [true, false]:
			# O + ou − em cada nome (a cor sozinha não basta no daltonismo).
			var names: Array = rows.filter(func(r): return r[2] == good).map(func(r): return ("+ " if good else "− ") + String(r[0]))
			if not names.is_empty():
				add.call(" · ".join(names), S.OK if good else S.DANGER, "Row")
		return column
	for row in rows:
		if not tips or String(row[1]) == "":
			add.call(("+ " if row[2] else "− ") + String(row[0]), S.OK if row[2] else S.DANGER, "Row")
			continue
		# O nome na cor de bom ou ruim e, ao lado, o que faz (a linha só quebra quando a explicação é longa).
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(line)
		var name_label := AHKit.label(("+ " if row[2] else "− ") + String(row[0]), "small", S.OK if row[2] else S.DANGER, true)
		name_label.set_meta("part", "Row")
		name_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		line.add_child(name_label)
		var room := width - name_label.get_minimum_size().x - 8.0
		var tip := AHKit.label(String(row[1]), "small", MUTED)
		tip.set_meta("part", "RowTip")
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		if room >= width * 0.45:
			tip.custom_minimum_size.x = room
			line.add_child(tip)
		else:
			# O nome longo ocupa a coluna: a explicação desce para a linha de baixo, na largura toda.
			name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			name_label.custom_minimum_size.x = width
			tip.custom_minimum_size.x = width
			column.add_child(tip)
	return column


## Quem está naquele ponto da tela: o corpo (de pé) que o contém, o do centro mais perto quando dois se encostam; "" se
## ninguém.
func unit_at(point: Vector2) -> String:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if session == null or arena == null or camera == null:
		return ""
	var best := ""
	var best_distance := INF
	for unit in session.units():
		var card: AHSpriteCard = arena.cards.get(unit.id)
		if card == null or not card.visible or not unit.is_standing():
			continue
		var rect := _body_rect(camera, card)
		if rect.has_point(point) and absf(rect.get_center().x - point.x) < best_distance:
			best_distance = absf(rect.get_center().x - point.x)
			best = unit.id
	return best


## As placas escalonadas (_plate_stagger) sobem, com a intenção delas, para cima do que cobririam nos vizinhos (a
## placa e a intenção deles; a intenção fica na altura da cabeça, e a de quem é mais alto, mais embaixo).
func _lift_staggered() -> void:
	for unit_id in _plate_stagger:
		var plate: Control = _unit_bars.get(unit_id)
		if plate == null or not plate.visible:
			continue
		var tag := (plate.get_meta("intent") if plate.has_meta("intent") else null) as Control
		if tag != null and not tag.visible:
			tag = null
		var player: bool = session.state.find_unit(unit_id).is_player
		var theirs: Array[Rect2] = []
		for other_id in _unit_bars:
			var other: Control = _unit_bars[other_id]
			var unit = session.state.find_unit(other_id)
			if other_id == unit_id or _plate_stagger.has(other_id) or not other.visible or unit == null or unit.is_player != player:
				continue
			theirs.append(Rect2(other.position, other.size))
			var other_tag := (other.get_meta("intent") if other.has_meta("intent") else null) as Control
			if other_tag != null and other_tag.visible:
				theirs.append(Rect2(other_tag.position, other_tag.size))
		# Subir pela intenção pode pôr a placa sobre outra coisa do vizinho: sobe de novo, até não cobrir nada.
		for round in 4:
			var lift := 0.0
			var mine: Array[Rect2] = [Rect2(plate.position, plate.size)]
			if tag != null:
				mine.append(Rect2(tag.position, tag.size))
			for rect in theirs:
				for own in mine:
					if own.grow(-1).intersects(rect.grow(-1)):
						lift = maxf(lift, own.end.y - rect.position.y + 4.0)
			if lift <= 0.0:
				break
			plate.position.y -= lift
			if tag != null:
				tag.position.y = maxf(INTENT_TOP, tag.position.y - lift)


## A largura das placas de cada lado: a de sempre (176 dos heróis, 246 dos inimigos), estreitada até caber entre os pés
## vizinhos (com quatro inimigos a ~200 px um do outro, as placas de 246 px se cobriam: "Fa|ísca", #63).
func _plate_widths(camera: Camera3D) -> Dictionary:
	var out := {}
	_plate_stagger.clear()
	for player in [true, false]:
		var xs: Array = []
		var slots: Array = []
		for unit_id in _unit_bars:
			var unit = session.state.find_unit(unit_id)
			var card: AHSpriteCard = arena.cards.get(unit_id)
			if unit != null and unit.is_player == player and card != null and _unit_bars[unit_id].visible:
				xs.append([camera.unproject_position(card.global_position).x, unit_id])
				if unit.rank > 0:
					slots.append([camera.unproject_position(arena.slot_position(unit)).x, unit_id])
		xs.sort_custom(func(a, b): return a[0] < b[0])
		slots.sort_custom(func(a, b): return a[0] < b[0])
		# O escalonamento (#72) sai do lugar de destino de cada um, e não de onde a placa está no quadro: numa troca de
		# posição as placas não pulam de linha enquanto os dois se cruzam, e nas lutas de espaço normal nada sobe.
		for i in range(1, slots.size()):
			if slots[i][0] - slots[i - 1][0] < PLATE_MIN + PLATE_GAP and not _plate_stagger.has(slots[i - 1][1]):
				_plate_stagger[slots[i][1]] = true
		# Cada placa com a sua largura: a de sempre, ou o que cabe até o vizinho de cada lado (metade da distância de
		# cada um), para quem tem espaço não estreitar por causa dos outros.
		for i in xs.size():
			var width := PLATE_PLAYER if player else PLATE_ENEMY
			if i > 0:
				width = minf(width, xs[i][0] - xs[i - 1][0] - PLATE_GAP)
			if i < xs.size() - 1:
				width = minf(width, xs[i + 1][0] - xs[i][0] - PLATE_GAP)
			out[xs[i][1]] = maxf(PLATE_MIN, width)
	return out


const PLATE_PLAYER := 200.0
const PLATE_ENEMY := 200.0
const PLATE_MIN := 140.0
const PLATE_GAP := 8.0
## As placas escalonadas (acima da cabeça) porque o lugar do vizinho está mais perto que a placa mínima: _plate_widths
## as marca, pelo lugar de destino de cada um.
var _plate_stagger := {}


## O retângulo do corpo de um personagem na tela: do pé à cabeça e com a largura do corpo (a placa tem margem
## transparente; o clique vale no corpo).
func _body_rect(camera: Camera3D, card: AHSpriteCard) -> Rect2:
	var feet := camera.unproject_position(card.global_position)
	var head := camera.unproject_position(card.global_position + Vector3(0, card.head_height(), 0))
	var height := maxf(feet.y - head.y, 24.0)
	var width := maxf(height * BODY_WIDTH, 48.0)
	return Rect2(Vector2(feet.x - width * 0.5, head.y), Vector2(width, height))


## Afasta a dica (na altura de sempre) para o lado em que ela não cobre o apontado.
func _dodge_tip(avoid: Rect2) -> void:
	if not Rect2(_tip.position, _tip.size).intersects(avoid):
		return
	var left := avoid.position.x - 16 - _tip.size.x
	var right := avoid.end.x + 16
	_tip.position.x = left if left >= 16 and (avoid.get_center().x > 960 or right + _tip.size.x > 1904) else clampf(right, 16, 1904 - _tip.size.x)


## A largura do corpo, em fração da altura, para a área do clique no alvo.
const BODY_WIDTH := 0.45


## Abaixo desta altura (m) o personagem é baixinho (os ajudantes do John, o Rastejante de Cabos): a placa sob os pés
## subiria por cima do corpo quando encosta no painel de baixo.
const SHORT_HEIGHT := 0.9


## Onde fica a placa (y na tela): o baixinho, sempre acima da cabeça (não pula entre cima e baixo a cada lance); os
## outros, sob os pés, sem passar do limite do painel de baixo (dock_limit; INF sem o painel).
## A área de toque maior que o desenho (hud-target.md: Registro 272x112, ações 128x112, habilidades 140x140): uma
## camada invisível em volta do botão, que passa o toque e o clique para ele.
static func grow_hit(button: Control, target: Vector2) -> void:
	var hit := Control.new()
	hit.name = "Hit"
	hit.mouse_filter = Control.MOUSE_FILTER_PASS
	hit.show_behind_parent = true
	var drawn: Vector2 = button.custom_minimum_size
	hit.position = -(target - drawn).max(Vector2.ZERO) * 0.5
	hit.size = drawn.max(target)
	button.add_child(hit)


static func plate_y(feet_y: float, head_y: float, short: bool, plate_height: float, dock_limit: float) -> float:
	if short:
		return head_y - plate_height - 8.0
	return minf(feet_y + 10.0, dock_limit)


# ---------------------------------------------------------------- turno do herói

## Mostra as opções do herói e espera o comando: {kind: ability/move/defend/flee/item, ability_id, rank}.
## note: um aviso que fica na tela enquanto ele decide (o item da Mochila que acabou de usar).
func ask_command(actor_id: String, note: String = "") -> Dictionary:
	_actor_id = actor_id
	_message.text = note
	_panel.visible = true
	_build_abilities()
	waiting = true
	tutorial_moment.emit("turn", {"actor": actor_id})
	var command: Dictionary = await command_chosen
	waiting = false
	tutorial_moment.emit("command", command)
	stop_examine()
	# A Mochila não é modal: um comando escolhido com ela aberta (Defender, uma habilidade) fecha ela também. Aberta, ela
	# travava os atalhos dos próximos heróis e passava para a luta seguinte.
	_close_bag()
	# Durante o lance, o painel não mostra os botões de quem já agiu.
	for child in _abilities.get_children():
		child.queue_free()
	_description.text = ""
	_set_enabled(false)
	_hide_tip()
	# Durante o lance o painel sai da frente: a luta fica inteira à vista.
	_panel.visible = false
	return command


## Liga as travas do tutorial nas ações que já estão na tela (sem remontar as habilidades: o foco adiado delas fica).
func apply_tutorial_locks() -> void:
	for child in _actions.get_children():
		var kind: String = child.get_meta("kind", "")
		if tutorial_locks.has(kind):
			child.set_meta("locked", true)
			child.disabled = true
			(child.get_node("Icon") as Control).modulate = AHKit.LOCKED


## O que o tutorial destaca (na tela de 1920 x 1080): "abilities" (as quatro habilidades), "actions" (Mover e Defender),
## "item" (a Mochila) ou "targets" (os alvos acesos). Vazio quando não está na tela.
func tutorial_rect(kind: String) -> Rect2:
	match kind:
		"abilities":
			return _abilities.get_global_rect() if _abilities.is_visible_in_tree() and _abilities.get_child_count() > 0 else Rect2()
		"actions", "item":
			var found := Rect2()
			for child in _actions.get_children():
				var wanted: Array = ["move", "defend"] if kind == "actions" else ["item"]
				if child.is_visible_in_tree() and wanted.has(child.get_meta("kind", "")):
					found = child.get_global_rect() if not found.has_area() else found.merge(child.get_global_rect())
			return found
		"targets":
			var found := Rect2()
			for marker in _markers:
				if is_instance_valid(marker) and marker.is_visible_in_tree():
					found = marker.get_global_rect() if not found.has_area() else found.merge(marker.get_global_rect())
			return found
	return Rect2()


func show_waiting(text: String) -> void:
	_message.text = text
	_clear_markers()
	_set_enabled(false)


func show_message(text: String) -> void:
	_message.text = text


func _set_enabled(enabled: bool) -> void:
	for child in _abilities.get_children() + _actions.get_children():
		if child is Button:
			child.disabled = not enabled or child.get_meta("locked", false)
			if child.has_meta("ability_id"):
				_style_ability(child)


## O slot da habilidade (hud-target.md): a peça ability_slot; escolhida (enquanto o jogador escolhe o alvo), os cantos
## âmbar grossos por cima (a camada Selected); bloqueada, o ícone apagado (o motivo fica na barra e na dica).
func _style_ability(button: Button) -> void:
	var chosen: bool = _choosing != "" and button.get_meta("ability_id", "") == _choosing
	AHKit.style_button(button, "ability_slot")
	var selected := button.get_node_or_null("Selected") as Control
	if selected != null:
		selected.visible = chosen
	var icon := button.get_node_or_null("Icon") as Control
	if icon != null:
		icon.modulate = AHKit.LOCKED if button.get_meta("locked", false) else (AHKit.DISABLED_ICON if button.disabled and not chosen else Color.WHITE)


## A barra da habilidade: o ícone, o nome e a faixa de verdade nesta luta (o campo à direita da divisão).
func _show_header(option: Dictionary) -> void:
	if option.is_empty():
		_ability_icon.texture = null
		_ability_name.text = ""
		_ability_range.text = ""
		return
	var path := arena.icon_path(option.id)
	_ability_icon.texture = load(path) if path != "" else null
	_ability_name.text = tr(option.name).to_upper()
	_ability_name.add_theme_color_override("font_color", TEXT if option.usable else MUTED)
	var number := _number_of(option.id)
	_ability_range.text = number[0]
	_ability_range.add_theme_color_override("font_color", TEXT if option.usable else MUTED)


## A aba de cima da barra da habilidade, centrada nela.
func _place_tab() -> void:
	_target_tab.reset_size()
	_target_tab.size = _target_tab.get_combined_minimum_size()
	# A base da aba encosta no topo da barra da habilidade (no texto Maior ela cresce para cima).
	_target_tab.position = Vector2(KIT_TAB_CENTER.x - _target_tab.size.x * 0.5, KIT_HEADER.position.y + 4 - _target_tab.size.y) - _panel.position
	_target_tab.visible = _description.text != ""


## O número do cartão e da dica: a faixa de verdade nesta luta (com o treino da Pesquisa, uma ★ ao lado; a descrição
## diz "treinado" por extenso).
func _number_of(ability_id: String) -> Array:
	var ability: Dictionary = session.data.abilities[ability_id]
	if ability.DamageRange.Max > 0:
		var damage := session.effective_range(ability_id, "damage", _actor_id)
		return ["%d–%d" % [damage.Min, damage.Max], tr("dano ★") if damage.trained else tr("dano"), GOLD]
	if ability.HealRange.Max > 0:
		var heal := session.effective_range(ability_id, "heal", _actor_id)
		return ["+%d–%d" % [heal.Min, heal.Max], tr("cura ★") if heal.trained else tr("cura"), S.OK]
	return ["", "", GOLD]


## take_focus: a primeira habilidade ganha o foco (false quando a Mochila está aberta por cima: o foco fica nela).
func _build_abilities(take_focus: bool = true) -> void:
	for child in _abilities.get_children():
		child.queue_free()
	_options = session.ability_options(_actor_id)
	var first: Button
	for index in _options.size():
		var option: Dictionary = _options[index]
		var button := Button.new()
		button.custom_minimum_size = KIT_SLOT.size
		grow_hit(button, Vector2(140, 140))
		button.text = ""
		button.clip_contents = false
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.position = Vector2(8, 8)
		icon.size = KIT_SLOT.size - Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var path := arena.icon_path(option.id)
		if path != "":
			icon.texture = load(path)
		button.add_child(icon)
		var selected := Panel.new()
		selected.name = "Selected"
		selected.add_theme_stylebox_override("panel", AHKit.style("selected_slot"))
		selected.set_anchors_preset(Control.PRESET_FULL_RECT)
		selected.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selected.visible = false
		button.add_child(selected)
		# Usos e recarga numa aba pequena no alto (sem contador para os ilimitados).
		var extra := ""
		if option.cooldown > 0:
			extra = tr("Recarga %d") % option.cooldown
		elif option.uses >= 0:
			extra = tr("%d uso(s)") % option.uses
		if extra != "":
			var uses := AHKit.panel(AHKit.piece_of("key", "tab"))
			uses.name = "Uses"
			uses.mouse_filter = Control.MOUSE_FILTER_IGNORE
			uses.add_child(AHKit.label(extra, "small", AHKit.AMBER, true))
			uses.position = Vector2(4, -14)
			button.add_child(uses)
		var key := AHKitKey.make("combat_ability_%d" % (index + 1))
		button.add_child(key)
		key.position = Vector2(90, 90)
		button.set_meta("locked", not option.usable)
		button.set_meta("ability_id", option.id)
		button.disabled = not option.usable
		_style_ability(button)
		button.pressed.connect(_on_ability.bind(option))
		button.focus_entered.connect(func():
			_show_header(option)
			if S.using_keys and not _quiet_focus: _describe(option, button))
		button.mouse_entered.connect(func():
			_show_header(option)
			_describe(option, button))
		button.mouse_exited.connect(_hide_tip)
		button.set_meta("click", true)
		button.pressed.connect(func(): Sound.click())
		_abilities.add_child(button)
		if first == null and option.usable:
			first = button
	var shown: Array = _options.filter(func(o): return o.usable)
	_show_header(shown[0] if not shown.is_empty() else (_options[0] if not _options.is_empty() else {}))
	for child in _actions.get_children():
		var kind: String = child.get_meta("kind")
		var locked: bool = (kind == "move" and session.move_targets(_actor_id).is_empty()) or (kind == "flee" and not session.can_flee()) \
			or tutorial_locks.has(kind)
		child.set_meta("locked", locked)
		child.disabled = locked
		# Bloqueada, a ação também apaga o ícone (como as habilidades): a peça escura quase não muda no desligado.
		(child.get_node("Icon") as Control).modulate = AHKit.LOCKED if locked else Color.WHITE
		if kind == "item":
			(child.get_node("Count") as Label).text = str(AHJourneyRules.food(Campaign.state))
	# Na aba, curto como no alvo; o que fazer fica na dica das habilidades (_describe).
	var actor_name: String = session.state.find_unit(_actor_id).display_name
	_description.text = tr("Vez de %s") % actor_name
	_place_tab.call_deferred()
	if take_focus:
		_focus_quietly.call_deferred(first if first else _actions.get_child(1))


## O registro (#56): escondido; a cada lance novo, só a última linha por LOG_FLASH segundos. A tecla do registro abre as
## últimas linhas e fecha.
func _refresh_log() -> void:
	var lines: Array = session.state.combat_log
	_log_title.text = tr("REGISTRO · %s fecha") % S.key_name("combat_log") if _log_open else tr("REGISTRO · %s abre") % S.key_name("combat_log")
	if _log_open:
		_log.text = "\n".join(lines.slice(maxi(0, lines.size() - 6)))
		_log_panel.visible = not lines.is_empty()
		_log_panel.modulate.a = 1.0
		_log_seen = lines.size()
		return
	if lines.size() <= _log_seen:
		return
	_log_seen = lines.size()
	_log.text = lines[-1]
	_log_panel.visible = true
	_log_panel.modulate.a = 1.0
	if _log_tween:
		_log_tween.kill()
	_log_tween = create_tween()
	_log_tween.tween_interval(LOG_FLASH)
	_log_tween.tween_property(_log_panel, "modulate:a", 0.0, 0.4)
	_log_tween.tween_callback(func(): _log_panel.visible = _log_open)


func toggle_log() -> void:
	_log_open = not _log_open
	if _log_tween:
		_log_tween.kill()
	_log_panel.visible = false
	_log_seen = 0 if _log_open else session.state.combat_log.size()
	_refresh_log()


## O rodapé tem as posições do alvo em todos os tamanhos de texto (as peças comportam o texto Maior); só a aba se
## recentra no texto novo.
func _fit_dock() -> void:
	_panel.position = Vector2(0, DOCK_TOP)
	_panel.size = Vector2(1920, 1056.0 - DOCK_TOP)
	_place_tab()


## O foco que a vez põe sozinha: sem abrir a dica (ela abre com o mouse em cima ou quando o jogador anda o foco, #56).
func _focus_quietly(button: Control) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree():
		return
	_quiet_focus = true
	button.grab_focus()
	_quiet_focus = false


func _dock_top() -> float:
	return _panel.position.y


## O tamanho do texto ou as cores mudaram nas Opções (AHUiStyle.retune): as fichas e o painel se ajustam ao texto novo.
## As cartas de habilidade (altura, recuo e ícone pelo tamanho do texto) são refeitas com a mesma carta em foco; os
## botões de ação crescem junto.
func restyle() -> void:
	refresh()
	_restyle_kit()
	_fit_inspect()
	# O painel da inspeção remonta no tamanho novo.
	_inspect_info = {}
	if waiting and _choosing == "":
		var owner := get_viewport().gui_get_focus_owner()
		var focused: int = _abilities.get_children().find(owner)
		# Com a Mochila aberta, o foco continua nela (o Enter não escolhe uma carta por trás).
		_build_abilities(_bag == null)
		if focused >= 0 and _bag == null:
			await get_tree().process_frame
			if focused < _abilities.get_child_count():
				_focus_quietly(_abilities.get_child(focused))
	_fit_dock.call_deferred()


# ---------------------------------------------------------------- dicas

func _popup_divider() -> TextureRect:
	var line := TextureRect.new()
	line.texture = AHKit.texture("divider")
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.custom_minimum_size = Vector2(0, 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## Os recursos no popup: os da luta vencida (AHJourneyRules.combat_loot, o guardião), ou o achado que a fuga e a derrota
## deixaram para trás, na cor de alerta.
func _popup_loot(box: VBoxContainer, result: String) -> void:
	var campaign: Dictionary = Campaign.state
	var amounts := {}
	var lost := result != "victory"
	if lost:
		var expedition = campaign.get("session", {}).get("expedition")
		var loot: Dictionary = expedition.get("loot", {}) if expedition != null else {}
		for key in ["seeds", "scrap", "fragments"]:
			amounts[key] = int(loot.get(key, 0))
	else:
		amounts = AHJourneyRules.combat_loot(campaign, result, arena != null and arena.boss_fight)
	var shown: Array = ["seeds", "scrap", "fragments"].filter(func(k): return int(amounts.get(k, 0)) > 0)
	# A frase do que se perdeu só quando havia o que perder (a derrota diz sempre como a equipe caiu).
	if lost and (not shown.is_empty() or result == "defeat"):
		var note := AHKit.label(tr("A equipe recuou pelas sombras e largou o que carregava.") if result == "escaped" else tr("Todos caíram nas ruínas. O achado ficou para trás."), "text", TEXT)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(POPUP_WIDTH - 80.0, 0)
		box.add_child(note)
	if shown.is_empty():
		if not lost:
			var none := AHKit.label(tr("Nenhum recurso nesta luta"), "text", MUTED)
			none.name = "NoLoot"
			none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(none)
		return
	var chips := HBoxContainer.new()
	chips.name = "Loot"
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 10)
	box.add_child(chips)
	var icons := {"seeds": "lobby-seed", "scrap": "lobby-scrap", "fragments": "lobby-fragment"}
	for key in shown:
		var chip := AHKit.chip("cost")
		chip.set_meta("resource", key)
		chip.set_meta("amount", int(amounts[key]))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		chip.add_child(row)
		var icon := TextureRect.new()
		icon.texture = AHKit.legacy_icon(icons[key])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(24, 24)
		icon.modulate = AHKit.alert_text() if lost else AHKit.AMBER
		row.add_child(icon)
		row.add_child(AHKit.label((tr("−%d") if lost else tr("+%d")) % int(amounts[key]), "row", AHKit.alert_text() if lost else AHKit.AMBER, true))
		chips.add_child(chip)


## Quem caiu nesta luta (#118), em vermelho e com o ícone: "Íris caiu". Ninguém morre: volta à Estação em recuperação.
func _popup_fallen(box: VBoxContainer) -> void:
	if session == null:
		return
	var names := PackedStringArray()
	for unit in session.state.player_team:
		if unit.hp <= 0 and not unit.deaths_door:
			names.append(String(unit.display_name))
	if names.is_empty():
		return
	var row := HBoxContainer.new()
	row.name = "Fallen"
	row.set_meta("names", Array(names))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(AHKit.glyph("state_wounded", AHUiStyle.px(26), AHKit.alert_text()))
	var who := names[0] if names.size() == 1 else tr("%s e %s") % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]
	var label := AHKit.label((tr("%s caiu") if names.size() == 1 else tr("%s caíram")) % who, "row", AHKit.alert_text(), true)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(label)
	box.add_child(row)
	var note := AHKit.label(tr("Volta à Estação para se recuperar.") if names.size() == 1 else tr("Voltam à Estação para se recuperar."), "small", MUTED)
	note.name = "FallenNote"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)


## O XP da luta numa linha, o de cada herói na ordem da cena (a soma enganava: o nível pede o XP de cada um), e quem
## fechou o XP do nível ("Treino pronto", que sobe no Alojamento).
func _popup_xp(box: VBoxContainer, result: String) -> void:
	if session == null or result != "victory":
		return
	var parts := PackedStringArray()
	var gains := {}
	var ready: Array = []
	# Na ordem da cena, da esquerda para a direita: a equipe vem da frente (à direita) para trás.
	var scene_order: Array = session.state.player_team.duplicate()
	scene_order.reverse()
	for unit in scene_order:
		var gained := int(session.xp_gained.get(unit.hero_id, 0))
		var hero = Campaign.hero(unit.hero_id)
		if gained > 0:
			parts.append(tr("%s +%d") % [unit.display_name, gained])
			gains[unit.hero_id] = gained
		if hero != null:
			var cost := AHHeroLevels.next_cost(hero)
			if not cost.is_empty() and AHHeroLevels.xp(hero) >= int(cost.xp):
				ready.append(String(hero.display_name))
	if not parts.is_empty():
		var xp := AHKit.label(tr("XP: %s") % " · ".join(parts), "text", AHKit.XP, true)
		xp.name = "Xp"
		xp.set_meta("xp", gains)
		xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		xp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		xp.custom_minimum_size = Vector2(_line_width(xp), 0)
		box.add_child(xp)
	# Quem fechou o XP do nível, todos numa linha só (a equipe ganha XP junta): o popup não desce sobre as cabeças.
	if not ready.is_empty():
		var row := HBoxContainer.new()
		row.name = "TrainingReady"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		row.add_child(AHKit.glyph("train", AHUiStyle.px(22), AHKit.AMBER))
		# Até dois, os nomes; mais que isso, quantos (a linha não alarga o popup sobre as cabeças; quem é cada um fica no
		# Alojamento, onde o Treino acontece).
		var who: String = ", ".join(PackedStringArray(ready)) if ready.size() <= 2 else tr("%d heróis") % ready.size()
		row.add_child(AHKit.label(tr("%s: Treino pronto") % who, "text", AHKit.AMBER, true))
		box.add_child(row)


## A largura de uma linha do popup sem quebrar, até o máximo (POPUP_MAX_WIDTH menos as margens); a fonte e o tamanho
## são os do rótulo, já com o tamanho de texto das Opções.
func _line_width(label: Label) -> float:
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	var text := label.text.to_upper() if label.uppercase else label.text
	return minf(ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) + 8.0, POPUP_MAX_WIDTH - 80.0)


## Qualquer tecla, clique ou toque fecha o popup do fim (depois de um instante, para a tecla que acabou a luta não
## fechá-lo junto); a derrota também fecha assim, mas não sozinha.
## A contagem do popup do fim (#128): para enquanto o mouse (ou o foco) está nele; no zero, fecha. Com Reduzir efeitos, a
## linha fica parada, mas o popup fecha no mesmo tempo.
func _tick_result(delta: float) -> void:
	if _result_left < 0.0 or not _result.visible:
		return
	if result_held():
		return
	_result_left = maxf(0.0, _result_left - delta)
	if _result_timer != null and not GameFlow.reduced_effects():
		_result_timer.value = _result_left / _result_total
	if _result_left <= 0.0:
		_result_left = -1.0
		_result.visible = false
		result_closed.emit()


## O popup segura a contagem: o mouse em cima dele ou o foco num botão dele.
func result_held() -> bool:
	if not _result.visible:
		return false
	var focus := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	# No toque, o último ponto do mouse emulado não segura (o dedo não fica em cima).
	var pointed: bool = not sheet.touch_mode and _result.get_global_rect().has_point(_mouse)
	return pointed or (focus != null and _result.is_ancestor_of(focus))


func _close_popup_input(event: InputEvent) -> bool:
	if not _result.visible or Time.get_ticks_msec() - _result_opened < POPUP_GUARD_MS:
		return false
	var press: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]) \
		or (event is InputEventScreenTouch and event.pressed) or (event is InputEventJoypadButton and event.pressed)
	if press:
		# Fechado antes de avisar: duas teclas no mesmo quadro não avisam duas vezes.
		_result.visible = false
		result_closed.emit()
	return press


func _hide_tip() -> void:
	if _choosing == "":
		_tip.visible = false


## A dica completa da habilidade sobre o cartão: o número, o texto, quem atinge (ao mirar) e os termos explicados.
func _describe(option: Dictionary, button: Control = null, rank: int = -1) -> void:
	var ability: Dictionary = session.data.abilities[option.id]
	_clear(_tip_box)
	_tip_box.add_child(AHKit.label(tr(option.name), "range", GOLD, true, true))
	var number := _number_of(option.id)
	var facts := PackedStringArray()
	if number[0] != "":
		facts.append(tr("%s de %s") % [number[0], number[1]])
	if ability.Cooldown > 0:
		facts.append(tr("recarga %d") % ability.Cooldown)
	if ability.UsesMax > 0:
		facts.append(tr("%d usos por expedição") % ability.UsesMax if ability.bUsesPerExpedition else tr("%d usos") % ability.UsesMax)
	if not facts.is_empty():
		_tip_box.add_child(_kit_label(" · ".join(facts), S.MIN_TEXT, TEXT, "bold"))
	var row = GameData.row("abilities", option.id)
	# Os termos do glossário (em português) são procurados no texto original; a tela mostra o traduzido.
	var text: String = row.get("Description", "") if row != null else ""
	var body := _kit_label(tr(text), S.MIN_TEXT, TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(430, 0)
	_tip_box.add_child(body)
	# O alcance: de que posições sai e quais alcança (as bolinhas dos cartões antigos, em texto).
	var reach := tr("Sai das posições %s") % " · ".join(ability.get("OriginRanks", []).map(func(r): return str(int(r))))
	if String(ability.get("TargetType", "")) != "Self":
		reach += tr(" · alcança %s") % " · ".join(ability.get("TargetRanks", []).map(func(r): return str(int(r))))
	_tip_line(reach, S.MIN_TEXT, S.MUTED)
	if not option.usable:
		_tip_box.add_child(_kit_label(option.reason, S.MIN_TEXT, AHKit.alert_text()))
	# Os termos a explicar, cada um uma vez só: os estados (dos alvos, ao mirar; senão, do herói da vez e dos inimigos) e
	# os que o texto da habilidade cita.
	var terms: Array = []
	if rank > 0:
		var ids: Array = session.hit_ids(_actor_id, option.id, rank)
		var hits := PackedStringArray()
		for id in ids:
			var unit := session.state.find_unit(id)
			if unit == null:
				continue
			var note := tr("%s (vida %d)") % [_name(unit), unit.hp]
			if not unit.is_player and ability.DamageRange.Max > 0 and session.effective_range(option.id, "damage", _actor_id).Max >= unit.hp:
				note += tr(" · pode cair")
			# Os estados do alvo por extenso: no foco, a dica faz o papel da dica do mouse sobre os ícones (#30).
			note += _status_words(unit, terms)
			hits.append(note)
		if not hits.is_empty():
			_tip_line(tr("Atinge: ") + "; ".join(hits), S.MIN_TEXT, S.DANGER if option.enemy_side else S.OK, "bold")
	else:
		# Sem mirar (o cartão com foco): os estados de quem está na luta, para quem joga no teclado, no controle ou no toque.
		var actor := session.state.find_unit(_actor_id)
		var mine := _status_words(actor, terms) if actor != null else ""
		if mine != "":
			_tip_line(tr("Você:") + mine.trim_prefix(" ·"), 17, TEXT)
		var others := PackedStringArray()
		for enemy in session.state.enemy_team:
			if enemy.hp > 0:
				var words := _status_words(enemy, terms)
				if words != "":
					others.append(unit_name(enemy.display_name) + ":" + words.trim_prefix(" ·"))
		if not others.is_empty():
			_tip_line("; ".join(others), 17, MUTED)
	# O que fazer (a instrução que a aba curta não diz): na mira, como usar; na vez, como escolher.
	if _choosing != "":
		_tip_line(tr("Clique no alvo e clique de novo para usar (%s usa; %s ou B volta).") % [S.key_name("ui_accept"), S.key_name("cancel")], S.MIN_TEXT, AHKit.AMBER)
	elif waiting:
		_tip_line(tr("Escolha uma habilidade (%s–%s) ou uma ação.") % [S.key_name("combat_ability_1"), S.key_name("combat_ability_4")], S.MIN_TEXT, AHKit.AMBER)
	for word in S.GLOSSARY:
		if not terms.has(word) and (text.contains(word) or text.to_lower().contains(word.to_lower().substr(0, 6))):
			terms.append(word)
	var glosses: Array = []
	for word in terms:
		glosses.append(_tip_line("%s: %s" % [word, S.GLOSSARY.get(word, "")], 16, S.VIOLET))
	# A dica cabe entre o alto da tela e a doca: o que não couber das explicações sai, de baixo para cima.
	var room := _dock_top() - 96.0 - 130.0
	while not glosses.is_empty() and _tip_box.get_combined_minimum_size().y + 24.0 > room:
		var last: Control = glosses.pop_back()
		_tip_box.remove_child(last)
		last.queue_free()
	_place_tip(button)


## " · Sangra 2, Marcado" (vazio sem estados), e os termos de cada estado entram em terms, uma vez só.
func _status_words(unit: AHCombat.Unit, terms: Array) -> String:
	var marks := S.statuses(unit)
	for entry in marks:
		if not terms.has(entry[4]):
			terms.append(entry[4])
	return "" if marks.is_empty() else " · " + ", ".join(marks.map(func(e): return e[0]))


## O nome de quem luta na língua do jogo: o do inimigo vem dos dados, às vezes com um sufixo da rota (o guardião da
## fase, os relés Alfa e Beta do chefe), traduzido em partes (#35). O dos heróis não muda.
static func unit_name(text: String) -> String:
	var whole := TranslationServer.translate(text)
	if whole != text:
		return whole
	for suffix in [" · Guardião", " Alfa", " Beta"]:
		if text.ends_with(suffix):
			return TranslationServer.translate(text.trim_suffix(suffix)) + _suffix(suffix)
	return whole


static func _suffix(suffix: String) -> String:
	match suffix:
		" · Guardião":
			return TranslationServer.translate(" · Guardião")
		" Alfa":
			return TranslationServer.translate(" Alfa")
	return TranslationServer.translate(" Beta")


## O nome de quem luta na tela: o do herói como está, o do inimigo traduzido.
func _name(unit: AHCombat.Unit) -> String:
	return unit.display_name if unit.is_player else unit_name(unit.display_name)


## O nome curto da barra de ordem: o substantivo, sem o artigo. Em português é a primeira palavra ("Relé de Defesa"
## fica "Relé", "O Porteiro" fica "Porteiro"); em inglês, a última ("Defense Relay" fica "Relay").
static func short_name(text: String) -> String:
	var words := unit_name(text).split(" ", false)
	if words.size() > 1 and ["O", "A", "Os", "As", "The"].has(words[0]):
		words.remove_at(0)
	if words.is_empty():
		return text
	# Os sufixos da rota (" · Guardian", " Alpha") não são o substantivo.
	var english := TranslationServer.get_locale().begins_with("en")
	if english:
		while words.size() > 1 and (words[-1] in ["·", "Guardian", "Alpha", "Beta"] or words[-1].is_valid_int()):
			words.remove_at(words.size() - 1)
		return words[-1]
	return words[0]

func _tip_line(text: String, size: int, color: Color, kind: String = "body") -> Label:
	var line := _kit_label(text, size, color, kind)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(430, 0)
	_tip_box.add_child(line)
	return line


func _place_tip(button: Control) -> void:
	_tip.visible = true
	_tip.size = _tip.get_combined_minimum_size()
	var x := 420.0
	if button != null and is_instance_valid(button) and button.is_inside_tree():
		x = button.global_position.x + button.size.x * 0.5 - _tip.size.x * 0.5
	_tip.position = Vector2(clampf(x, 16, 1904 - _tip.size.x), maxf(130, _dock_top() - 96 - _tip.size.y))


func _describe_action(kind: String) -> void:
	var texts := {"move": [tr("Mover"), tr("Troca de posição com o aliado vizinho. Gasta a vez.")],
		"defend": [tr("Defender"), tr("+1 Bloqueio e passa a vez. ") + S.GLOSSARY.Bloqueio],
		"flee": [tr("Fugir"), tr("60% de chance de a equipe recuar e sair da luta. Na fuga, larga o que carregava.")],
		"item": [tr("Mochila"), tr("Comida ou curativo no herói da vez. Ação livre: a vez continua, um item por vez dele.")]}
	_clear(_tip_box)
	_tip_box.add_child(AHKit.label(texts[kind][0], "range", GOLD, true, true))
	var body := _kit_label(texts[kind][1], S.MIN_TEXT, TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(430, 0)
	_tip_box.add_child(body)
	_place_tip(_actions)
	_tip.position.x = 1904 - _tip.size.x


func _on_ability(option: Dictionary) -> void:
	if option.self:
		command_chosen.emit({"kind": "ability", "ability_id": option.id, "rank": session.state.find_unit(_actor_id).rank})
		return
	_choosing = option.id
	_show_markers(option.targets, option.enemy_side, func(rank): command_chosen.emit({"kind": "ability", "ability_id": option.id, "rank": rank}), option.id)


func _on_action(kind: String) -> void:
	match kind:
		"item":
			_open_bag()
		"move":
			_choosing = "move"
			_show_markers(session.move_targets(_actor_id), false, func(rank): command_chosen.emit({"kind": "move", "rank": rank}))
		_:
			command_chosen.emit({"kind": kind})


## A faixa da crise de instinto: "CRISE DE INSTINTO" e o resultado (superação em dourado, colapso em vermelho).
func show_crisis(text: String, breakthrough: bool) -> void:
	hide_crisis()
	_crisis = ColorRect.new()
	_crisis.color = Color(AHKit.SHADE, 0.55)
	_crisis.position = Vector2(0, 182)
	_crisis.size = Vector2(1920, 112)
	_crisis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crisis)
	# Na ferrugem do Instinto (decisão do Lucas), clareada para ler sobre o aço.
	var title := AHKit.label(tr("CRISE DE INSTINTO"), "text", AHKit.INSTINCT.lightened(0.3), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 10)
	title.size = Vector2(1920, 30)
	_crisis.add_child(title)
	var result := AHKit.label(text, "hero_name", AHKit.crisis_color(breakthrough), true, true)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.position = Vector2(0, 42)
	result.size = Vector2(1920, 60)
	_crisis.add_child(result)
	_crisis.modulate.a = 0.0
	create_tween().tween_property(_crisis, "modulate:a", 1.0, 0.2)


func hide_crisis() -> void:
	if _crisis != null:
		_crisis.queue_free()
	_crisis = null


## A Mochila por cima do painel, no herói da vez; o item escolhido vira comando (ação livre: a vez continua).
func _open_bag() -> void:
	if _bag != null:
		return
	stop_examine()
	_hide_tip()
	Tips.show_tip("bag")
	tutorial_moment.emit("bag", {})
	Sound.play("res://audio/ui/bag_open.ogg")
	_bag = PanelContainer.new()
	_bag.add_theme_stylebox_override("panel", AHKit.style(AHKit.piece_of("panel", "large")))
	_bag.position = Vector2(510, 140)
	_bag.custom_minimum_size = Vector2(900, 0)
	var panel := AHInventoryPanel.new()
	panel.session = session
	panel.closed.connect(_close_bag)
	panel.combat_item.connect(func(kind):
		_close_bag()
		command_chosen.emit({"kind": "item", "item": kind}))
	_bag.add_child(panel)
	add_child(_bag)


func _close_bag() -> void:
	if _bag != null:
		_bag.queue_free()
	_bag = null


func bag_open() -> bool:
	return _bag != null


# ---------------------------------------------------------------- alvos

## A escolha do alvo (#57, como na Unreal): a área do clique é o corpo inteiro de cada alvo válido (um botão sem fundo do
## tamanho do corpo na tela), e não mais um botão com o nome. O mouse em cima mostra quem a habilidade atinge dali; o
## clique escolhe (o ALVO acima e a luz mais forte) e um segundo clique no mesmo usa. O teclado e o controle andam
## entre os alvos com as setas (o foco escolhe) e Enter ou A usa. Uma posição vazia (mover para lá) tem o botão dela.
## ability_id: a habilidade mirada (vazio: o Mover).
func _show_markers(ranks: Array, enemy_side: bool, on_pick: Callable, ability_id: String = "") -> void:
	stop_examine()
	_clear_markers()
	# Antes de desligar os cartões: o escolhido ganha a moldura de escolhida (_style_ability lê _choosing).
	_choosing = ability_id if ability_id != "" else "move"
	_set_enabled(false)
	_pick_side = enemy_side
	_pick_ranks = ranks.duplicate()
	_pick_ability = ability_id
	_picked_rank = -1
	_clicked_rank = -1
	var team: Array = session.state.enemy_team if enemy_side else session.state.player_team
	for rank in ranks:
		var unit = AHCombatEngine._find(team, func(u): return session.engine.occupies_rank(u, rank) and AHCombatEngine.alive_any(u))
		var marker := Button.new()
		marker.set_meta("rank", rank)
		if unit != null and arena.cards.has(unit.id):
			marker.set_meta("card", arena.cards[unit.id])
			marker.set_meta("unit_id", unit.id)
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				marker.add_theme_stylebox_override(state, StyleBoxEmpty.new())
			# O nome e o resto estão na ficha que abre ao apontar (#89): sem a dica do sistema por cima dela.
		else:
			var probe := AHCombat.Unit.new()
			probe.is_player = not enemy_side
			probe.rank = rank
			marker.text = tr("Posição %d") % rank
			marker.custom_minimum_size = Vector2(180, 46)
			style_button(marker, AHKit.AMBER_LIGHT)
			marker.set_meta("world", arena.slot_position(probe) + Vector3(0, 2.0, 0))
		marker.mouse_entered.connect(_hover_target.bind(rank))
		marker.mouse_exited.connect(_hover_target.bind(-1))
		marker.focus_entered.connect(_select_target.bind(rank))
		marker.gui_input.connect(_marker_input)
		marker.pressed.connect(_press_target.bind(rank, on_pick))
		add_child(marker)
		_markers.append(marker)
	for i in _markers.size():
		_markers[i].focus_neighbor_left = _markers[(i - 1 + _markers.size()) % _markers.size()].get_path()
		_markers[i].focus_neighbor_right = _markers[(i + 1) % _markers.size()].get_path()
	# A aba diz como no alvo ("Escolha um alvo"); o como fica na dica do alvo apontado (_describe).
	_description.text = tr("Escolha um alvo")
	tutorial_moment.emit("target", {"ability": ability_id})
	_paint_targets()
	if not _markers.is_empty():
		_via_mouse = false
		_markers[0].grab_focus.call_deferred()


## De onde veio o último toque no alvo: mouse ou toque (o primeiro clique só escolhe) ou teclado e controle.
func _marker_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		_via_mouse = true
	elif event is InputEventKey or event is InputEventJoypadButton:
		_via_mouse = false


## O clique: o primeiro no personagem escolhe, o segundo no mesmo usa; pelo teclado ou controle, usa o escolhido.
func _press_target(rank: int, on_pick: Callable) -> void:
	if _via_mouse and _clicked_rank != rank:
		_clicked_rank = rank
		_select_target(rank)
		return
	_clear_markers()
	_set_enabled(true)
	on_pick.call(rank)


## O alvo escolhido (pelo foco ou pelo clique): o ALVO acima dele, a luz mais forte e a dica de quem é atingido.
func _select_target(rank: int) -> void:
	if _markers.is_empty():
		return
	# Escolhido pelo teclado ou controle, outro alvo: o clique seguinte num alvo só escolhe (não usa sem ver o ALVO nele).
	if _clicked_rank != rank:
		_clicked_rank = -1
	_picked_rank = rank
	if _pick_ability != "":
		_preview_hits(_pick_ability, rank)
	_paint_targets()


## O mouse em cima mostra a mira dali; fora, volta ao escolhido.
func _hover_target(rank: int) -> void:
	# O botão que sai debaixo do mouse (a escolha acabou) avisa a saída: aí não há mais o que pintar.
	if _markers.is_empty():
		return
	var shown := rank if rank >= 0 else _picked_rank
	if _pick_ability != "" and shown >= 0:
		_preview_hits(_pick_ability, shown)
	_paint_targets(shown)


## As luzes de cada personagem na escolha (cores e forças de AHUiStyle): o herói da vez em dourado; os alvos válidos na
## cor do lado, fraca; os outros atingidos dali, média; o apontado, forte, com o ALVO; quem não pode ser alvo, escurecido.
func _paint_targets(pointed: int = -2) -> void:
	if pointed == -2:
		pointed = _picked_rank
	var hit: Array = session.hit_ids(_actor_id, _pick_ability, pointed) if _pick_ability != "" and pointed >= 0 else []
	var color := S.target_color(_pick_side)
	for unit in session.units():
		var card: AHSpriteCard = arena.cards.get(unit.id)
		if card == null or not AHCombatEngine.alive_any(unit):
			continue
		if unit.id == _actor_id:
			# O herói da vez apontado (a cura nele mesmo): o dourado, forte.
			var self_pointed: bool = unit.is_player != _pick_side and pointed >= 0 and session.engine.occupies_rank(unit, pointed)
			card.set_highlight(S.TARGET_ACTIVE_COLOR, S.TARGET_POINTED if self_pointed else S.TARGET_ACTIVE)
		elif unit.is_player != _pick_side and _pick_ranks.any(func(r): return session.engine.occupies_rank(unit, r)):
			var strength := S.TARGET_VALID
			if pointed >= 0 and session.engine.occupies_rank(unit, pointed):
				strength = S.TARGET_POINTED
			elif hit.has(unit.id):
				strength = S.TARGET_ALSO
			card.set_highlight(color, strength)
		elif hit.has(unit.id):
			card.set_highlight(color, S.TARGET_ALSO)
		else:
			card.set_highlight(Color.BLACK, 0.0, true)
	# O nome do alvo acima do apontado, na plaqueta com a linha na cor do lado (não só a luz diz quem é).
	_target_label.visible = false
	for marker in _markers:
		if pointed >= 0 and int(marker.get_meta("rank")) == pointed and marker.has_meta("card"):
			var unit = session.state.find_unit(String(marker.get_meta("unit_id", "")))
			_target_label.text = _name(unit) if unit != null else tr("ALVO")
			(_target_label.get_node("Line") as ColorRect).color = AHKit.enemy_hp() if unit == null or not unit.is_player else AHKit.hero_hp()
			_target_label.reset_size()
			_target_label.visible = true
			_target_label.set_meta("card", marker.get_meta("card"))


func _clear_markers() -> void:
	for marker in _markers:
		marker.queue_free()
	_markers.clear()
	_clear_preview()
	_choosing = ""
	_picked_rank = -1
	_clicked_rank = -1
	_pick_ranks = []
	_tip.visible = false
	if _target_label != null:
		_target_label.visible = false
	if session != null and arena != null:
		for unit in session.units():
			var card: AHSpriteCard = arena.cards.get(unit.id)
			if card != null and is_instance_valid(card):
				card.set_highlight(Color.BLACK, 0.0)


## Quem a habilidade atinge mirando nesta posição (CombatSession.hit_ids, a mesma conta do ataque): a dica mostra todos
## com a vida e se podem cair; a luz de cada um (_paint_targets) mostra quem é atingido.
func _preview_hits(ability_id: String, rank: int) -> void:
	_clear_preview()
	var option: Array = _options.filter(func(o): return o.id == ability_id)
	if not option.is_empty():
		var index := _options.find(option[0])
		_describe(option[0], _abilities.get_child(index) if index < _abilities.get_child_count() else null, rank)


func _clear_preview() -> void:
	for mark in _preview_marks:
		mark.queue_free()
	_preview_marks.clear()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("combat_log") and session != null:
		toggle_log()
		get_viewport().set_input_as_handled()
		return
	# A Mochila: I abre na vez de um herói; Esc, Backspace ou I fecham.
	if _bag != null and (S.is_back(event) or event.is_action_pressed("menu") or event.is_action_pressed("inventory")):
		_close_bag()
		get_viewport().set_input_as_handled()
		return
	if waiting and _choosing == "" and _bag == null:
		for i in 4:
			if event.is_action_pressed("combat_ability_%d" % (i + 1)) and i < _abilities.get_child_count():
				var button: Button = _abilities.get_child(i)
				if not button.disabled:
					get_viewport().set_input_as_handled()
					button.pressed.emit()
				return
		for spec in ACTIONS:
			if event.is_action_pressed(spec[3]):
				var action: Button = _actions.get_children().filter(func(b): return b.get_meta("kind") == spec[1])[0]
				get_viewport().set_input_as_handled()
				if not action.disabled:
					action.pressed.emit()
				return
	if _choosing != "" and S.is_back(event):
		_clear_markers()
		_set_enabled(true)
		tutorial_moment.emit("cancel", {})
		_build_abilities()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- resultado

## Mostra o fim da luta e espera "Continuar" (no modo automático, segue sozinho).
## O fim da luta: o título, as estrelas e os critérios (rewards, de AHFightRewards.criteria; a vitória) e cada herói com a
## vida e o XP ganho enchendo a barra até o próximo nível (#91). Continuar fecha (o automático fecha sozinho).
## O popup curto do fim da luta (#109, docs/design/hud-ajustes.md): um Painel pequeno no alto, no lugar da faixa da
## rodada, longe da equipe; sem botão. "BATALHA FINALIZADA", o resultado (a vitória com as estrelas), os recursos da
## luta em chips (ou "Nenhum recurso nesta luta"), o XP de cada herói numa linha, quem ficou com o Treino pronto e, no
## guardião, que a carga abre em seguida. A fuga e a derrota mostram o achado que se perdeu, na cor de alerta.
## Decisão do Lucas: a vitória e a fuga fecham sozinhas (POPUP_HOLD, metade no 2x) ou com qualquer tecla, clique ou
## toque; a derrota espera um toque, menos na luta automática (automatic), que não tem quem toque.
func show_result(result: String, automatic: bool = false, rewards: Dictionary = {}, hold: float = POPUP_HOLD) -> void:
	_panel.visible = false
	# A luta acabou: ninguém mais age, o anel sai do chão já na tela do fim, e a faixa da rodada dá lugar ao popup.
	if arena != null:
		arena.show_ring("")
	_order_panel.visible = false
	# A vitória e a derrota têm o toque delas (#36); a fuga, não.
	if result == "victory" or result == "defeat":
		Sound.play("res://audio/ui/%s.ogg" % result)
		Sound.duck(9.0, 1.6)
	_message.text = ""
	_clear_markers()
	_clear(_result)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result.add_child(box)
	var title := AHKit.label(tr("Batalha finalizada"), "panel_title", TEXT, true, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var line := HBoxContainer.new()
	line.name = "Outcome"
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 6)
	box.add_child(line)
	var names := {"victory": tr("Vitória"), "defeat": tr("Derrota"), "escaped": tr("Fuga")}
	var tone: Color = AHKit.AMBER if result == "victory" else (AHKit.alert_text() if result == "defeat" else TEXT)
	line.add_child(AHKit.label(names.get(result, result), "card_name", tone, true, true))
	if result == "victory" and not rewards.is_empty():
		var stars := HBoxContainer.new()
		stars.name = "Stars"
		stars.set_meta("stars", int(rewards.stars))
		stars.add_theme_constant_override("separation", 2)
		stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for i in 3:
			stars.add_child(AHKit.glyph("star" if i < int(rewards.stars) else "star_empty", AHUiStyle.px(28), AHKit.AMBER if i < int(rewards.stars) else MUTED))
		line.add_child(stars)
	box.add_child(_popup_divider())
	_popup_fallen(box)
	_popup_loot(box, result)
	_popup_xp(box, result)
	if result == "victory" and arena != null and arena.boss_fight:
		var cargo := AHKit.label(tr("A carga do guardião abre em seguida"), "text", AHKit.AMBER)
		cargo.name = "Cargo"
		cargo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(cargo)
	var waits := result == "defeat" and not automatic
	# A linha do tempo já separa o pé; sem ela (a derrota), o divisor.
	if waits:
		box.add_child(_popup_divider())
	var timer: AHKitBar = null
	if not waits:
		timer = AHKit.bar("state", 1, 1)
		timer.name = "Timer"
		timer.kind = "amber"
		timer.piece = AHKit.piece_of("bar", "track")
		timer.custom_minimum_size = Vector2(316, 14)
		timer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(timer)
	var hint := AHKit.label(tr("Qualquer tecla ou toque para continuar") if waits else (tr("Fecha sozinho · toque para fechar antes") if sheet.touch_mode
		else tr("Fecha sozinho · o mouse em cima segura · qualquer tecla fecha")), "small", MUTED)
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	_result.reset_size()
	_result.size = _result.get_combined_minimum_size()
	_result.position = Vector2(960.0 - _result.size.x * 0.5, POPUP_TOP)
	_result.visible = true
	_result_opened = Time.get_ticks_msec()
	_result_waits = waits
	# Quadrado em qualquer tamanho de texto (no Maior, a letra o esticava para cima).
	var side := maxf(44.0, maxf(_result_close.get_combined_minimum_size().x, _result_close.get_combined_minimum_size().y))
	_result_close.custom_minimum_size = Vector2(side, side)
	_result_close.size = Vector2(side, side)
	_result_close.position = _result.position + Vector2(_result.size.x - side - 10, 10)
	_result_close.visible = true
	_result_timer = timer
	_result_left = -1.0
	if not waits:
		# O tempo de verdade (1x e 2x dão o mesmo); só a QA, acelerada além do 2x, encurta. A contagem anda em _process e
		# para com o mouse em cima.
		var speed: float = arena.speed if arena != null else 1.0
		_result_left = hold / speed if speed > 2.0 else hold
		_result_total = maxf(0.01, _result_left)
	await result_closed
	_result_left = -1.0
	_result_close.visible = false
	_result.visible = false
	_order_panel.visible = true
