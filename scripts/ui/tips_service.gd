## Tips (autoload): as dicas da primeira vez (a etapa 2 da proposta de UX, aprovada pelo Lucas). Cada uma aparece uma vez
## para quem joga, num cartão no alto da tela que não para o jogo; "Entendi" fecha, "Desligar dicas" desliga todas. O que
## já foi visto e a escolha ficam em user://tips.cfg (por máquina, não pela campanha: uma campanha nova não repete).
## As cenas só chamam Tips.show_tip("id") no momento certo. Nas capturas e nos scripts de teste (-s) as dicas ficam
## desligadas e nada é gravado: a automação não marca dicas como vistas na pasta de quem joga.
extends CanvasLayer

const PATH := "user://tips.cfg"
const TIPS := {
	"station": ["A Estação Raiz", "Este é o refúgio. O cartão \"Próximo passo\" diz o que fazer agora; clique num cômodo para ver o que ele faz. Para partir, use Preparar expedição."],
	"preparation": ["Montar a equipe", "A posição importa: cada habilidade sai de certas posições e alcança outras (as bolinhas). A frente fica à direita, como na luta. Clique em dois heróis para trocá-los de lugar."],
	"explore": ["Explorar", "Ande com A e D. Os losangos dourados marcam o que dá para usar: chegue perto e aperte E. A rota no alto mostra os trechos até o guardião."],
	"patrol": ["Patrulhas", "A patrulha olha à frente. Se ela não te vir até você encostar, a equipe ganha a abertura e age primeiro. A barra amarela é a suspeita dela."],
	"combat": ["Combate por posição", "Na sua vez, escolha uma habilidade (1 a 4) e depois o alvo. As bolinhas \"de\" dizem de que posições ela sai; as \"em\", quais alcança. Passe o mouse para ver o resultado. O ▶ sob cada inimigo diz o que ele pretende fazer."],
	"instinct": ["Instinto", "O perigo enche a barra roxa. Em 200 vem a crise: com esperança alta, a superação (cura e bloqueio); com ela baixa, o colapso (trauma e vulnerável). Descansar baixa o instinto."],
	"search": ["Vasculhar", "Caixotes, armários e casas podem ter comida, sucata e o objetivo da rota. Às vezes há perigo: uma em três buscas sai ruim."],
	"bag": ["Mochila", "Comida e curativos curam fora da luta e, na luta, como ação livre do herói da vez. A comida é da expedição: o que sobrar não volta."],
	"boss_down": ["Fase concluída", "O guardião caiu. Volte à Estação quando quiser (o botão no canto ou Esc): todo o achado chega com a equipe."],
	"return": ["A volta", "O relatório mostra o que chegou. Depois vem a noite no Dormitório: quem dorme come e recupera vida e instinto."],
}

var enabled := true
var _automated := false
var _seen := {}
var _card: PanelContainer
var _title: Label
var _text: Label
var _current := ""
var _queue: Array = []


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := Array(OS.get_cmdline_args()) + Array(OS.get_cmdline_user_args())
	_automated = args.has("-s") or args.has("--script") or args.any(func(a): return String(a).begins_with("--capture="))
	var config := ConfigFile.new()
	if not _automated and config.load(PATH) == OK:
		enabled = bool(config.get_value("tips", "enabled", true))
		for id in config.get_value("tips", "seen", []):
			_seen[id] = true
	# A captura das próprias dicas liga só na memória (AH_TIPS_QA=1); nada é gravado.
	if _automated:
		enabled = OS.get_environment("AH_TIPS_QA") == "1"
	_build()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", AHUiStyle.panel(0.95, AHUiStyle.GOLD))
	_card.custom_minimum_size = Vector2(600, 0)
	_card.visible = false
	root.add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	head.add_child(AHUiStyle.label("DICA", 15, AHUiStyle.COPPER, "bold"))
	_title = AHUiStyle.label("", 24, AHUiStyle.GOLD, "display")
	head.add_child(_title)
	_text = AHUiStyle.label("", AHUiStyle.MIN_TEXT, AHUiStyle.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(570, 0)
	box.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)
	var off := Button.new()
	off.text = "Desligar dicas"
	off.custom_minimum_size = Vector2(170, 40)
	AHCombatHud.style_button(off)
	off.add_theme_color_override("font_color", AHUiStyle.MUTED)
	off.focus_mode = Control.FOCUS_NONE
	off.pressed.connect(func(): set_enabled(false))
	row.add_child(off)
	var ok := Button.new()
	ok.text = "Entendi"
	ok.custom_minimum_size = Vector2(150, 40)
	AHCombatHud.style_button(ok)
	ok.add_theme_color_override("font_color", AHUiStyle.GOLD)
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(dismiss)
	row.add_child(ok)


## Mostra a dica se ela ainda não foi vista (e as dicas estão ligadas). Uma de cada vez; as outras esperam a vez.
func show_tip(id: String) -> void:
	if not enabled or _seen.has(id) or not TIPS.has(id) or id == _current or _queue.has(id):
		return
	if _current != "":
		_queue.append(id)
		return
	_current = id
	_seen[id] = true
	_store()
	_title.text = TIPS[id][0]
	_text.text = TIPS[id][1]
	_card.size = _card.get_combined_minimum_size()
	_card.position = Vector2(960 - _card.size.x * 0.5, 150)
	_card.modulate.a = 0.0
	_card.visible = true
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.25)


func dismiss() -> void:
	_card.visible = false
	_current = ""
	if not _queue.is_empty():
		show_tip(_queue.pop_front())


func seen(id: String) -> bool:
	return _seen.has(id)


func set_enabled(value: bool) -> void:
	enabled = value
	if not value:
		_queue.clear()
		_card.visible = false
		_current = ""
	_store()


## Volta a mostrar todas (Opções).
func reset() -> void:
	_seen.clear()
	_store()


func _store() -> void:
	if _automated:
		return
	var config := ConfigFile.new()
	config.set_value("tips", "enabled", enabled)
	config.set_value("tips", "seen", _seen.keys())
	config.save(PATH)


func _unhandled_input(event: InputEvent) -> void:
	# Enter fecha a dica aberta (sem roubar o Enter de quem joga quando não há dica).
	if _card.visible and event.is_action_pressed("ui_accept"):
		dismiss()
		get_viewport().set_input_as_handled()
