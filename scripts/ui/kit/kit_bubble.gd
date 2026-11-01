## O balão da Estação viva (#207), um componente do kit, sobre a cabeça de quem fala:
## - a fala ("say"): a moldura da etiqueta do cômodo (room_tag) com a ponta para baixo, o texto em até 2 linhas;
## - o pensamento ("think"): a mesma moldura sem a ponta, três bolinhas em escada até a cabeça e o texto em itálico,
##   um pouco mais apagado;
## - o balão interativo ("story", decisão do Lucas de 28/10): a fala em negrito, sublinhada e no âmbar de destaque, que se
##   aperta (o mouse, o toque ou o foco do teclado com Interagir) e avisa em opened, para abrir a tirinha.
## place() recebe o ponto da cabeça na tela: a ponta (ou a bolinha menor) cai nele. A entrada é curta (cresce e acende);
## com Reduzir efeitos, aparece direto. O texto não passa por tr() aqui: quem chama já traduziu.
class_name AHKitBubble
extends Control

signal opened

const SAY := "say"
const THINK := "think"
const STORY := "story"
## A largura máxima do texto (px de 1080, antes do texto Maior) e o número de linhas.
const WIDTH := 340
const MAX_LINES := 2
## A room_tag tem a moldura até a linha 41 e a ponta embaixo, no meio (o recorte dela, em px da peça).
const FRAME_ROWS := 41
const TIP := Rect2(92, 41, 17, 11)
## As bolinhas do pensamento, da cabeça para cima: o raio e o deslocamento (px de 1080).
const DOTS := [[3.0, Vector2(0, -4)], [4.5, Vector2(8, -15)], [6.0, Vector2(18, -30)]]
const DOTS_HEIGHT := 40.0
## A entrada: a escala de partida e o tempo (s).
const ENTER_SCALE := 0.86
const ENTER_TIME := 0.16

var kind := SAY
var text := ""
var _body: Control
var _tip: TextureRect
var _hit: Button
var _tween: Tween


static func make(bubble_kind: String, bubble_text: String) -> AHKitBubble:
	var bubble := AHKitBubble.new()
	bubble.kind = bubble_kind
	bubble.text = bubble_text
	return bubble


func _ready() -> void:
	name = "Bubble"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := PanelContainer.new()
	box.name = "Frame"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override("panel", _frame_style())
	if kind == STORY:
		var rich := RichTextLabel.new()
		rich.name = "Text"
		rich.bbcode_enabled = true
		rich.fit_content = true
		rich.scroll_active = false
		rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rich.add_theme_font_override("normal_font", AHKit.font(true))
		rich.add_theme_font_size_override("normal_font_size", AHKit.size("text"))
		rich.add_theme_color_override("default_color", AHKit.AMBER)
		rich.add_theme_color_override("font_outline_color", Color(AHKit.SHADE, 0.9))
		rich.add_theme_constant_override("outline_size", 3)
		rich.text = "[u]%s[/u]" % text.replace("[", "[lb]")
		rich.custom_minimum_size.x = _text_width(true)
		box.add_child(rich)
	else:
		var label := AHKit.label(text, "text", AHKit.MUTED if kind == THINK else AHKit.TEXT)
		label.name = "Text"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.max_lines_visible = MAX_LINES
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.custom_minimum_size.x = _text_width(false)
		if kind == THINK:
			label.add_theme_font_override("font", _italic())
		box.add_child(label)
	_body = box
	add_child(_body)
	if kind != THINK:
		_tip = TextureRect.new()
		_tip.name = "Tip"
		var atlas := AtlasTexture.new()
		atlas.atlas = AHKit.texture(AHKit.piece_of("tag", "room"))
		atlas.region = TIP
		_tip.texture = atlas
		_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_tip)
	if kind == STORY:
		# O balão inteiro se aperta: um botão sem chapa por cima, com a moldura âmbar do foco do kit.
		_hit = Button.new()
		_hit.name = "Open"
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			_hit.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_hit.add_theme_stylebox_override("focus", AHKit.style("focus_frame"))
		_hit.focus_mode = Control.FOCUS_ALL
		_hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_hit.pressed.connect(func(): opened.emit())
		_hit.mouse_entered.connect(func(): _body.modulate = Color(1.12, 1.1, 1.05))
		_hit.mouse_exited.connect(func(): _body.modulate = Color.WHITE)
		add_child(_hit)
	_layout()
	_enter()


## A moldura da room_tag sem a ponta (a parte de cima da peça, com o 9-slice da borda de baixo encolhido).
static func _frame_style() -> StyleBoxTexture:
	var box := AHKit.style(AHKit.piece_of("tag", "room"))
	box.region_rect = Rect2(0, 0, AHKit.entry("room_tag").size[0], FRAME_ROWS)
	box.texture_margin_bottom = 9
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 6
	box.content_margin_bottom = 7
	return box


## A Barlow Condensed não tem itálico: a inclinação vem de uma variação da fonte.
static func _italic() -> FontVariation:
	var italic := FontVariation.new()
	italic.base_font = AHKit.font(false)
	italic.variation_transform = Transform2D(Vector2(1, 0.2), Vector2(0, 1), Vector2.ZERO)
	return italic


func _text_width(emphasis: bool) -> float:
	var font := AHKit.font(emphasis)
	var full := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, AHKit.size("text")).x + 4.0
	return minf(full, float(AHUiStyle.px(WIDTH)))


## O corpo em cima, a ponta (ou as bolinhas) embaixo, no meio; o tamanho do balão é o do conjunto.
func _layout() -> void:
	_body.reset_size()
	var body := _body.get_combined_minimum_size()
	_body.size = body
	_body.position = Vector2.ZERO
	var tail: float = TIP.size.y - 1.0 if kind != THINK else float(AHUiStyle.px(int(DOTS_HEIGHT)))
	if _tip != null:
		_tip.size = TIP.size
		_tip.position = Vector2(round(body.x * 0.5 - TIP.size.x * 0.5), body.y - 1.0)
	if _hit != null:
		_hit.position = Vector2.ZERO
		_hit.size = body
	size = Vector2(body.x, body.y + tail)
	pivot_offset = Vector2(size.x * 0.5, size.y)
	queue_redraw()


## As três bolinhas do pensamento, em escada da cabeça até o balão.
func _draw() -> void:
	if kind != THINK:
		return
	var foot := Vector2(size.x * 0.5, size.y)
	var scale_px := AHUiStyle.px(100) / 100.0
	for dot in DOTS:
		var at: Vector2 = foot + dot[1] * scale_px
		draw_circle(at, dot[0] * scale_px + 1.5, Color(AHKit.MUTED, 0.85))
		draw_circle(at, dot[0] * scale_px, AHKit.STEEL)


## A ponta do balão (o meio de baixo) no ponto da cabeça, dentro da área livre (o balão não sai dela).
func place(head: Vector2, area: Rect2) -> void:
	var at := Vector2(head.x - size.x * 0.5, head.y - size.y)
	at.x = clampf(at.x, area.position.x, maxf(area.position.x, area.end.x - size.x))
	at.y = clampf(at.y, area.position.y, maxf(area.position.y, area.end.y - size.y))
	position = at.round()


## O balão apertável (o interativo) leva o foco do teclado e do controle.
func take_focus() -> void:
	if is_instance_valid(_hit):
		_hit.grab_focus()


func is_story() -> bool:
	return kind == STORY


func _enter() -> void:
	var reduced := bool(Campaign.state.get("settings", {}).get("reduced_environment_effects", false))
	if reduced:
		return
	modulate.a = 0.0
	scale = Vector2.ONE * ENTER_SCALE
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, ENTER_TIME)
	_tween.tween_property(self, "scale", Vector2.ONE, ENTER_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
