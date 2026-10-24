## A folha de estilo de todas as telas (a direção aprovada na proposta de UX): painéis escuros com filete de cobre, dourado
## para o que pede atenção, texto de 18 px ou mais na base de 1920x1080, ícone e número antes de texto. As fontes são as da
## Unreal: Plus Jakarta Sans no texto e Cinzel nos títulos. install() põe o tema como padrão da janela inteira.
class_name AHUiStyle

const INK := Color("0d1012")
const PANEL := Color(0.055, 0.066, 0.074, 0.9)
const LINE := Color("3b3327")
const COPPER := Color("c98a4b")
const GOLD := Color("e9c47c")
const TEXT := Color("efe5d1")
const MUTED := Color("a69a84")
static var DANGER := Color("e2675b")
## Bom e ruim: verde e vermelho, ou azul e laranja no modo para daltonismo (Okabe–Ito; Settings.colorblind).
static var OK := Color("86c98f")
const VIOLET := Color("b7a6f4")
const ENEMY := Color("d9893d")
const BLUE := Color("8fb4f0")
## A escolha de alvo na luta (#57), num lugar só (o kit de componentes da #59 troca aqui): a cor de cada lado (os
## inimigos no perigo, os aliados no bom, os dois seguindo o daltonismo), o herói da vez no dourado, a força da luz em
## cada estado e o escurecido de quem não pode ser alvo. A força e a palavra ALVO também dizem quem é, não só a cor.
const TARGET_VALID := 0.32
const TARGET_ALSO := 0.5
const TARGET_POINTED := 0.95
const TARGET_ACTIVE := 0.45
const TARGET_DIM := 0.62
const TARGET_ACTIVE_COLOR := GOLD


static func target_color(enemy_side: bool) -> Color:
	return DANGER if enemy_side else OK


static func set_colorblind(on: bool) -> void:
	OK = Color("56b4e9") if on else Color("86c98f")
	DANGER = Color("e69f00") if on else Color("e2675b")


## Texto mínimo na base de 1080p (a regra 2 da proposta).
const MIN_TEXT := 18
## O tamanho do texto das Opções (Settings.text_size): todo tamanho de fonte das telas passa por px().
static var text_scale := 1.0


static func px(size: int) -> int:
	return int(round(size * text_scale))

static var _fonts := {}
static var _portraits := {}
static var _circle: Shader


static func font(kind: String = "body") -> Font:
	if not _fonts.has(kind):
		var path: String = {"body": "res://art/ui/fonts/plus-jakarta-sans-latin-400-normal.ttf",
			"bold": "res://art/ui/fonts/plus-jakarta-sans-latin-700-normal.ttf",
			"display": "res://art/ui/fonts/cinzel-latin-700-normal.ttf"}[kind]
		_fonts[kind] = load(path)
	return _fonts[kind]


## O tema padrão: a fonte e o tamanho de todo texto e o painel das dicas de mouse.
static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = px(20)
	var tip := panel(0.96)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", px(MIN_TEXT))
	return t


static func install(root: Window) -> void:
	root.theme = theme()


const _COLOR_NAMES := ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "icon_normal_color"]
const _STYLE_NAMES := ["panel", "normal", "hover", "pressed", "focus", "disabled", "fill", "background"]


## As Opções valem na hora (#4): o tamanho do texto e as cores para daltonismo mudam nas telas já abertas sem remontá-las
## (o painel aberto, a rolagem e a seleção ficam como estão).
## - Todo tamanho de fonte passa por px(); px é inversível (round(round(s·k)/k) = s para k ≥ 1), então o tamanho de antes
##   volta ao da base e vai para a escala nova.
## - As cores de bom e de ruim (OK, DANGER) trocam onde aparecem: texto, painéis, barras, linhas e o aro dos rostos, com
##   a transparência de cada uso.
## - Depois, quem tem restyle() (os HUDs) refaz o que calcula na hora (posições pelo tamanho do texto, cores derivadas).
static func retune(root: Node, from_scale: float, from_ok: Color, from_danger: Color) -> void:
	var swaps := []
	if not _same_rgb(from_ok, OK):
		swaps.append([from_ok, OK])
	if not _same_rgb(from_danger, DANGER):
		swaps.append([from_danger, DANGER])
	var rescale := not is_equal_approx(from_scale, text_scale)
	var styles := {}
	var hooks: Array = []
	for node in [root] + root.find_children("*", "", true, false):
		# Ícones pintados por modulate (o alerta da barra da Estação, os nós da rota).
		if node is CanvasItem and not swaps.is_empty():
			node.modulate = _swap(node.modulate, swaps)
			node.self_modulate = _swap(node.self_modulate, swaps)
		if node is Control:
			var control: Control = node
			if rescale and control.has_theme_font_size_override("font_size"):
				var base := int(round(control.get_theme_font_size("font_size") / from_scale))
				control.add_theme_font_size_override("font_size", px(base))
			if not swaps.is_empty():
				for color_name in _COLOR_NAMES:
					if control.has_theme_color_override(color_name):
						control.add_theme_color_override(color_name, _swap(control.get_theme_color(color_name), swaps))
				for style_name in _STYLE_NAMES:
					if control.has_theme_stylebox_override(style_name):
						var style := control.get_theme_stylebox(style_name)
						# A mesma caixa pode servir a vários botões: troca uma vez só.
						if style is StyleBoxFlat and not styles.has(style):
							styles[style] = true
							style.bg_color = _swap(style.bg_color, swaps)
							style.border_color = _swap(style.border_color, swaps)
						elif style is AHFocusCorners and not styles.has(style):
							# O foco na cor de um estado (Recomeçar campanha, pendências) acompanha o daltonismo.
							styles[style] = true
							style.color = _swap(style.color, swaps)
				if control is ColorRect:
					control.color = _swap(control.color, swaps)
				if control.material is ShaderMaterial and control.material.get_shader_parameter("ring") != null:
					control.material.set_shader_parameter("ring", _swap(control.material.get_shader_parameter("ring"), swaps))
		elif node is Line2D and not swaps.is_empty():
			node.default_color = _swap(node.default_color, swaps)
		if node.has_method("restyle"):
			hooks.append(node)
	# Depois do quadro: os tamanhos mínimos só se refazem com as fontes novas aplicadas.
	for node in hooks:
		_restyle.call_deferred(node)


## A tela pode ter saído no meio (troca de cena): só refaz quem ainda está na árvore.
static func _restyle(node: Node) -> void:
	if is_instance_valid(node) and node.is_inside_tree():
		node.restyle()


static func _same_rgb(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.004 and absf(a.g - b.g) < 0.004 and absf(a.b - b.b) < 0.004


static func _swap(color: Color, swaps: Array) -> Color:
	for pair in swaps:
		if _same_rgb(color, pair[0]):
			return Color(pair[1], color.a)
	return color


## As molduras de metal do Codex (#20, docs/design/ui-frames.md): 9-slice de 16 px em art/ui/frames/. scale < 1 reduz
## a peça inteira (as teclas e as fichas pequenas, menores que os 32 px das duas bordas), feita na hora a partir da
## mesma arte. margins: o conteúdo (esquerda, topo, direita, baixo).
const FRAMES := "res://art/ui/frames/%s.png"
const FRAME_SLICE := 16
static var _frame_textures := {}


static func frame_texture(kind: String, scale: float = 1.0) -> Texture2D:
	var key := "%s@%.2f" % [kind, scale]
	if not _frame_textures.has(key):
		var texture: Texture2D = load(FRAMES % kind)
		if not is_equal_approx(scale, 1.0):
			var image := texture.get_image()
			image.decompress()
			image.resize(maxi(4, roundi(image.get_width() * scale)), maxi(4, roundi(image.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
			texture = ImageTexture.create_from_image(image)
		_frame_textures[key] = texture
	return _frame_textures[key]


static func frame(kind: String, alpha: float = 1.0, scale: float = 1.0, margins: Vector4 = Vector4(20, 18, 20, 18)) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = frame_texture(kind, scale)
	style.set_texture_margin_all(roundf(FRAME_SLICE * scale))
	style.content_margin_left = margins.x
	style.content_margin_top = margins.y
	style.content_margin_right = margins.z
	style.content_margin_bottom = margins.w
	style.modulate_color = Color(1, 1, 1, alpha)
	return style


## A moldura de painel para uma borda: cobre (painel_normal) ou dourada (destaque); "" para as outras cores, que dizem
## um estado (bom, ruim) e continuam desenhadas.
static func _frame_kind(border: Color) -> String:
	var hue := Color(border, 1.0)
	if _near(hue, COPPER):
		return "panel_normal"
	if _near(hue, GOLD) or _near(hue, GOLD.darkened(0.2)):
		return "panel_highlight"
	return ""


static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.08


## O painel das telas: a moldura de metal quando a borda é a padrão (cobre) ou a de destaque (dourada) e tem 2 px ou
## mais. As finas (placas e fichas pequenas) e as de estado (bom, ruim) continuam desenhadas (flat), para a cor do
## estado aparecer e para o 9-slice caber.
static func panel(alpha: float = 0.9, border: Color = Color(COPPER, 0.55), width: int = 2) -> StyleBox:
	var kind := _frame_kind(border) if width >= 2 else ""
	if kind != "":
		return frame(kind, alpha, 1.0, Vector4(20, 14, 20, 14))
	return flat(alpha, border, width)


## O painel desenhado (o de antes das molduras): cor de estado, borda fina ou cantos próprios.
static func flat(alpha: float = 0.9, border: Color = Color(COPPER, 0.55), width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PANEL, alpha)
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(5)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


static func label(text: String, size: int = 20, color: Color = TEXT, kind: String = "body") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", px(size))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.025, 0.02))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Uma ficha: ícone (texto ou símbolo), rótulo e o número em destaque.
static func chip(text: String, value: String = "", color: Color = GOLD) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", frame("resource_chip", 0.92, 0.5, Vector4(10, 4, 10, 4)))
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	row.add_child(label(text, MIN_TEXT, TEXT))
	if value != "":
		row.add_child(label(value, MIN_TEXT, color, "bold"))
	return box


## O nome da tecla principal de uma ação (com as trocas das Opções).
static func key_name(action: String) -> String:
	var code := Settings.primary_key(action)
	if code == 0:
		return "?"
	return {KEY_ESCAPE: "Esc"}.get(code, OS.get_keycode_string(code))


## A tecla de uma ação desenhada; acompanha as trocas das Opções (refresh_keys).
static func action_cap(action: String) -> PanelContainer:
	var cap := key_cap(key_name(action))
	cap.set_meta("ah_action", action)
	return cap


## Depois de trocar uma tecla nas Opções: as teclas desenhadas das telas abertas mostram a nova.
static func refresh_keys(root: Node) -> void:
	for node in root.find_children("*", "PanelContainer", true, false):
		if node.has_meta("ah_action") and node.get_child_count() > 0 and node.get_child(0) is Label:
			(node.get_child(0) as Label).text = key_name(String(node.get_meta("ah_action")))


## Quem joga está no teclado ou no controle (a última entrada não foi o mouse nem o toque); Settings acompanha.
static var using_keys := false


## Teclado e controle (#5): o foco fica sempre num botão da tela aberta (scope). Se o botão com foco sumiu (a tela foi
## remontada), ficou invisível ou está em outra tela, volta para o botão de mesmo texto (o "+" da Preparação continua no "+") ou para o
## primeiro da tela. Os HUDs chamam a cada quadro com a tela de cima; é barato quando o foco já está certo.
static func keep_focus(scope: Control) -> void:
	# Com a dica da primeira vez aberta, o foco é dela ("Entendi").
	if scope == null or not scope.is_visible_in_tree() or not using_keys or Tips.showing():
		return
	var owner := scope.get_viewport().gui_get_focus_owner()
	if owner != null and owner.is_visible_in_tree() and scope.is_ancestor_of(owner):
		if int(scope.get_meta("ah_focus", 0)) != owner.get_instance_id():
			scope.set_meta("ah_focus", owner.get_instance_id())
			scope.set_meta("ah_focus_text", (owner as Button).text if owner is Button else "")
			scope.set_meta("ah_focus_index", focusable(scope).find(owner))
		scope.set_meta("ah_focus_at", owner.get_global_rect().get_center())
		return
	var choices := focusable(scope)
	if choices.is_empty():
		return
	# O de mesmo texto mais perto de onde estava (os "Vigiar" de cada cartão da noite); sem ele (o "+" chegou ao máximo e
	# desligou), o mais perto na tela, na mesma linha primeiro: o foco nunca pula sozinho para o Partir de baixo.
	var text := String(scope.get_meta("ah_focus_text", ""))
	var at: Vector2 = scope.get_meta("ah_focus_at", Vector2(-1, -1))
	var best: Control = null
	var best_score := INF
	for control in choices:
		var center: Vector2 = control.get_global_rect().get_center()
		var offset := center - at
		var score := absf(offset.x) + absf(offset.y) * 3.0
		if text != "" and control is Button and (control as Button).text == text:
			score -= 100000.0
		if at.x < 0.0:
			score = choices.find(control)
		if score < best_score:
			best_score = score
			best = control
	best.grab_focus()


## Uma tela nova no mesmo lugar (outro cômodo no painel): o foco começa do primeiro botão.
static func reset_focus(scope: Control) -> void:
	for key in ["ah_focus", "ah_focus_text", "ah_focus_index", "ah_focus_at"]:
		if scope.has_meta(key):
			scope.remove_meta(key)
	var owner := scope.get_viewport().gui_get_focus_owner() if scope.is_inside_tree() else null
	if owner != null and scope.is_ancestor_of(owner):
		owner.release_focus()


## Os controles da tela que recebem foco: visíveis, ativos e com foco ligado, na ordem da árvore.
static func focusable(scope: Node) -> Array:
	var out: Array = []
	for node in scope.find_children("*", "Control", true, false):
		var control: Control = node
		if control.focus_mode == Control.FOCUS_NONE or not control.is_visible_in_tree() or control.is_queued_for_deletion():
			continue
		if control is BaseButton and (control as BaseButton).disabled:
			continue
		if control is BaseButton or control is Range or control is LineEdit:
			out.append(control)
	return out


## Interagir (E, ou a tecla trocada) confirma o botão com foco, como Enter e o A do controle (ui_accept). Devolve true se
## apertou. O evento que já é ui_accept fica para a própria interface.
static func press_focused(scope: Control, event: InputEvent) -> bool:
	if scope == null or not scope.is_visible_in_tree() or not event.is_action_pressed("interact") or event.is_action("ui_accept") or Tips.showing():
		return false
	var owner := scope.get_viewport().gui_get_focus_owner()
	if not (owner is BaseButton) or not scope.is_ancestor_of(owner) or (owner as BaseButton).disabled:
		return false
	var button: BaseButton = owner
	if button.toggle_mode:
		button.button_pressed = not button.button_pressed
	else:
		button.pressed.emit()
	return true


## Voltar: B no controle, Backspace (cancel) ou Esc (ui_cancel).
static func is_back(event: InputEvent) -> bool:
	return event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel")


## A tecla desenhada (a do teclado; o controle mostra a do gamepad).
static func key_cap(text: String) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", frame("key_cap", 1.0, 0.5, Vector4(8, 2, 8, 3)))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, 15, TEXT, "bold")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	return box


static func bar(color: Color, height: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.72)
	back.border_color = Color(1, 1, 1, 0.14)
	back.set_border_width_all(1)
	back.set_corner_radius_all(int(height * 0.5))
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(int(height * 0.5))
	b.add_theme_stylebox_override("background", back)
	b.add_theme_stylebox_override("fill", fill)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## O rosto do personagem, recortado da própria arte (o topo do corpo pela âncora e pela altura do manifesto), num
## círculo com aro. art: a entrada do manifesto (idle de herói ou inimigo).
static func portrait(art: Dictionary, size: float, ring: Color = Color(1, 1, 1, 0.3), ring_width: float = 0.06) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = face_texture(art)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _circle == null:
		_circle = Shader.new()
		_circle.code = """shader_type canvas_item;
uniform vec4 ring : source_color = vec4(1.0);
uniform float width = 0.06;
void fragment() {
	float d = distance(UV, vec2(0.5));
	if (d > 0.5) { discard; }
	vec4 face = texture(TEXTURE, UV);
	vec4 back = vec4(0.09, 0.08, 0.07, 1.0);
	COLOR = mix(back, face, face.a);
	if (d > 0.5 - width) { COLOR = ring; }
}"""
	var material := ShaderMaterial.new()
	material.shader = _circle
	material.set_shader_parameter("ring", ring)
	material.set_shader_parameter("width", ring_width)
	rect.material = material
	return rect


static func set_ring(rect: TextureRect, ring: Color) -> void:
	if rect.material is ShaderMaterial:
		rect.material.set_shader_parameter("ring", ring)


static func face_texture(art: Dictionary) -> Texture2D:
	var file: String = art.get("file", "")
	if _portraits.has(file):
		return _portraits[file]
	# O retrato recortado da entrega #26 (art/ui/portraits, 256x256, olhos em 144,104), quando o parado tem um.
	var portrait: String = art.get("portrait", "")
	if portrait != "" and ResourceLoader.exists(portrait):
		_portraits[file] = load(portrait)
		return _portraits[file]
	var texture: Texture2D = load(file)
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var canvas := Vector2(art.canvas[0], art.canvas[1])
	var scale := 1.0
	var origin := Vector2.ZERO
	if art.has("frames"):
		var f: Array = art.frames[0]
		origin = Vector2(f[0], f[1])
		canvas = Vector2(f[2], f[3])
	else:
		scale = float(image.get_width()) / canvas.x
	var body: float = float(art.body_reference_pixels)
	var anchor := Vector2(art.anchor[0], art.anchor[1])
	# A cabeça: o terço de cima do corpo, um quadrado centrado no pé (as artes de perfil ficam bem com isso).
	var side := body * 0.42
	var top := anchor.y - body - side * 0.12
	var region := Rect2(origin + Vector2(anchor.x - side * 0.5, top) * scale, Vector2(side, side) * scale)
	region = region.intersection(Rect2(Vector2.ZERO, image.get_size()))
	var face := image.get_region(Rect2i(region))
	face.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	var out := ImageTexture.create_from_image(face)
	_portraits[file] = out
	return out


## As fichas e os efeitos da unidade por extenso, com a cor de bom (azul) ou ruim (vermelho): [texto, bom].
## Os estados da unidade: [texto curto, bom para quem tem?, ícone (art/ui/icons/status-<ícone>_good|_bad, "" sem ícone),
## número (fichas ou vezes que faltam; 0 sem número), termo do GLOSSARY]. Bom e ruim são para quem recebe o estado.
static func statuses(unit: AHCombat.Unit) -> Array:
	var out: Array = []
	var t := unit.tokens
	if t.block > 0: out.append(["Bloqueio %d" % t.block, true, "block", t.block, "Bloqueio"])
	if t.dodge > 0: out.append(["Esquiva %d" % t.dodge, true, "dodge", t.dodge, "Esquiva"])
	if t.guard > 0: out.append(["Guarda", true, "protection", 0, "Guarda"])
	if t.vuln > 0: out.append(["Vulnerável %d" % t.vuln, false, "vulnerable", t.vuln, "Vulnerável"])
	if unit.mark_duration > 0: out.append(["Marcado", false, "marked", unit.mark_duration, "Marcado"])
	if unit.stun_turns > 0: out.append(["Atordoado", false, "stunned", unit.stun_turns, "Atordoado"])
	if unit.bleed.duration > 0: out.append(["Sangra %d" % unit.bleed.magnitude, false, "bleeding", unit.bleed.duration, "Sangra"])
	if unit.blight.duration > 0: out.append(["Contaminado %d" % unit.blight.magnitude, false, "poison", unit.blight.duration, "Contaminado"])
	if unit.blind: out.append(["Cego", false, "", 0, "Cego"])
	if unit.weak: out.append(["Fraco", false, "", 0, "Fraco"])
	if unit.immobilize_turns > 0: out.append(["Imobilizado", false, "", unit.immobilize_turns, "Imobilizado"])
	return out


## A dica de um estado (mouse e foco): o nome, o número e a explicação do glossário.
static func status_tip(entry: Array) -> String:
	var text: String = entry[0]
	var count: int = entry[3]
	var term: String = entry[4]
	var what := ""
	match term:
		"Sangra", "Contaminado":
			what = "%s por vez · %d %s" % [text.get_slice(" ", 1), count, "vez" if count == 1 else "vezes"]
		"Bloqueio", "Esquiva", "Vulnerável":
			what = "%d %s" % [count, "ficha" if count == 1 else "fichas"]
		_:
			if count > 0:
				what = "%d %s" % [count, "vez" if count == 1 else "vezes"]
	return "%s%s: %s" % [term, (" (%s)" % what) if what != "" else "", GLOSSARY.get(term, "")]


## O ícone do estado ou da intenção (os SVG brancos da entrega #18), para tingir com a cor do bom e do ruim.
static func combat_icon(name: String) -> Texture2D:
	var path := "res://art/ui/icons/%s.svg" % name
	return load(path) if ResourceLoader.exists(path) else null


## O que cada termo quer dizer (as dicas do combate e o glossário).
const GLOSSARY := {
	"Bloqueio": "Cada ponto corta o próximo dano recebido; some ao ser usado.",
	"Esquiva": "Chance de evitar o próximo ataque; some ao ser usada.",
	"Guarda": "Protege um aliado: os ataques nele vão para quem guarda.",
	"Vulnerável": "Recebe mais dano no próximo ataque.",
	"Marcado": "Alvo das habilidades que pegam Marca (Caçada Precisa).",
	"Atordoado": "Perde a próxima vez.",
	"Sangra": "Perde vida no começo de cada vez.",
	"Contaminado": "Perde vida no começo de cada vez; curar remove.",
	"Cego": "Pode errar o ataque.",
	"Fraco": "Causa menos dano.",
	"Imobilizado": "Não pode mudar de posição.",
	"Instinto": "Sobe com o perigo. Em 200 vem a crise: superação ou colapso.",
}
