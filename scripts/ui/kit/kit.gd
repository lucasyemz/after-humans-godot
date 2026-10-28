## O kit da HUD (#60): os componentes da HUD e os tokens num lugar só.
## - O padrão é o kit da Awesomic (art/ui/kit/station; decisão do Lucas, docs/design/hud-direction.md, "Padrão de
##   componentes"), em todas as telas, a luta também. As telas pedem componentes (Painel, Plaqueta, Botão, Barra, Chip,
##   Aba, Linha de lista, Tecla, Carta, Foco: COMPONENTS), e não arquivos de arte; trocar a peça de um componente muda
##   todas as telas.
## - Do kit do Codex (art/ui/kit/combat) ficam só as peças da luta sem equivalente (CODEX_ONLY), até a Awesomic
##   redesenhá-las, e as que a Awesomic reaproveita (reuses_combat_kit no manifesto dela). As que deixaram de valer
##   (RETIRED) não são usadas em lugar nenhum (o test_kit confere). As medidas vêm dos assets.json (docs/design/
## hud-target.md e hud-station.md): nine_slice_ltrb vai nas texture_margin_* do StyleBoxTexture, o recuo de content_xywh
## nas content_margin_*, e as peças grandes repetem o aço (TILE_FIT) em vez de esticar.
## - As fontes: Barlow Condensed Medium nos rótulos e SemiBold nos nomes, títulos e números (OFL). Todo tamanho passa
##   por AHUiStyle.px(), então o texto Maior (130%) vale na hora, como no resto do jogo.
## - As cores dos alvos (hud-target.md, "Cores e daltonismo"; hud-station.md, "Cores de tinta"), com as do daltonismo;
##   os componentes recolorem no restyle() quando o daltonismo muda.
## - Os estados de vida (decisão do Lucas): Em forma acima de 75%, Ferimento leve de 50% a 75%, Ferimento grave abaixo de
##   50%.
## Nenhum componente decide regra de jogo: recebem os dados prontos (da sessão da luta, das regras da Estação).
class_name AHKit
extends RefCounted

const U := preload("res://scripts/ui/ui_style.gd")
const MANIFESTS := ["res://art/ui/kit/combat/assets.json", "res://art/ui/kit/station/assets.json"]
## As peças grandes: o centro repete o aço (hud-station.md, "Como usar na Godot").
const TILED := ["report_band", "panel_large"]
## As que repetem só na largura (as riscas da vida prevista mantêm o passo em qualquer largura).
const TILED_WIDE := ["bar_preview"]
const FONT_MEDIUM := "res://art/ui/fonts/barlow_condensed_medium.ttf"
const FONT_SEMIBOLD := "res://art/ui/fonts/barlow_condensed_semibold.ttf"
const ICONS := "res://art/ui/kit/station/icons/%s.webp"

## Os componentes e as peças da Awesomic de cada variante (hud-direction.md, a tabela do padrão).
const COMPONENTS := {
	"panel": {"large": "panel_large", "inset": "panel_inset", "band": "report_band"},
	"plaque": {"room": "room_plaque"},
	"button": {"primary": "primary_button", "secondary": "secondary_button", "icon": "icon_button", "chip": "chip_button", "train": "train_button"},
	"bar": {"main": "main_bar", "fill": "bar_fill", "preview": "bar_preview", "track": "slider_track"},
	"chip": {"cost": "cost_chip", "status": "status_pill", "result": "result_chip", "resource": "resource_chip", "resource_tile": "resource_tile", "trait": "trait_tile"},
	"tab": {"card": "card_tab", "nav": "nav_tab", "nav_active": "nav_tab_active", "hero": "hero_tab", "hero_selected": "hero_tab_selected"},
	"row": {"list": "list_row", "list_selected": "list_row_selected"},
	"key": {"tab": "key_tab", "button": "button_key", "bar": "keys_bar"},
	"card": {"hero": "hero_card", "upgrade": "upgrade_card", "upgrade_selected": "upgrade_card_selected"},
	"focus": {"focus": "focus_frame", "selected": "selected_frame", "corners": "selected_corners"},
	"slider": {"track": "slider_track", "knob": "slider_knob"},
	"toggle": {"off": "toggle_off", "on": "toggle_on"},
	"tag": {"room": "room_tag"},
	"medal": {"level": "level_medal"},
}
## As peças só da luta, do kit do Codex, que ainda não têm versão da Awesomic.
const CODEX_ONLY := ["round_strip", "ability_header", "ability_slot", "target_tab", "actor_ring", "selected_slot", "exit"]
## As peças do Codex que deixaram de valer (o equivalente da Awesomic tomou o lugar).
const RETIRED := ["panel", "hero_panel", "register", "action_button", "health_ally", "health_enemy", "active_health"]

## Os tamanhos de texto na base de 1080p (o Maior multiplica por 1,3 no px()).
const SIZE := {
	# Luta (hud-target.md, "Fonte e texto Maior").
	"plaque": 30, "round": 30, "hero_name": 40, "ability_name": 32, "hero_value": 32, "world": 26, "tab": 26,
	"key": 26, "range": 28,
	# Estação (hud-station.md).
	"phase_name": 76, "panel_hero": 52, "panel_title": 40, "card_name": 36, "primary": 30, "row": 27, "text": 23,
	"small": 20,
}

## As cores (tinta do kit; nunca da imagem).
const STEEL := Color("1b1d20")
const STEEL_LIGHT := Color("25282c")
const AMBER := Color("f0a020")
const TEXT := Color("efe6d6")
const MUTED := Color("a9a294")
const XP := Color("b7a6f4")
const INSTINCT := Color("c07a3c")
## O escuro por baixo (as faixas, o escurecido atrás do herói, a sombra no chão): Color(AHKit.SHADE, alfa).
const SHADE := Color.BLACK
## O texto e os ícones em cima do âmbar (o botão principal).
const ON_AMBER := Color("1a1408")
## O fundo quase preto das faixas da luta.
const INK := Color(0.055, 0.066, 0.074, 0.9)
## O ícone travado (a habilidade que ainda não abriu) e o desligado (a que não serve agora).
const LOCKED := Color(0.42, 0.42, 0.42)
const DISABLED_ICON := Color(0.72, 0.72, 0.72)
## O rosto de quem caiu (o relatório da volta) e o marcador claro da luta (o alvo apontado).
const FALLEN := Color(0.5, 0.5, 0.55)
const AMBER_LIGHT := Color(1.0, 0.85, 0.45)
## O que não vale daqui (a habilidade que não sai da posição): o ícone escurecido.
const DIM := Color(0.3, 0.3, 0.32)
## A noite pendente no Dormitório (a luz e os cantos do cômodo na vista geral).
const NIGHT := Color("b7a6f4")
const _HERO_HP := [Color("2fb6bd"), Color("56b4e9")]
const _ENEMY_HP := [Color("d23a2e"), Color("e69f00")]
const _HEALTHY := [Color("56b468"), Color("56b4e9")]
const _LIGHT_WOUND := [Color("f0a020"), Color("f0e442")]
const _HEAVY_WOUND := [Color("d23a2e"), Color("d55e00")]
const _ALERT_TEXT := [Color("e2584a"), Color("e8743a")]
const _GOOD := [Color("6cc77c"), Color("56b4e9")]
## A vida prevista (bar_preview, #109): verde clara; azul clara no daltonismo.
const _PREVIEW := [Color("a6e3ae"), Color("a9d8f5")]
## O véu dos cuidados sem efeito (as riscas da bar_preview, escuras).
const VEIL := Color(0.04, 0.04, 0.05, 0.62)

## Os limites dos estados (fração da vida máxima).
const HEALTHY_ABOVE := 0.75
const LIGHT_FROM := 0.5

static var _entries := {}
static var _textures := {}
static var _fonts := {}


static func _cb() -> int:
	return 1 if Settings.colorblind else 0


static func hero_hp() -> Color:
	return _HERO_HP[_cb()]


static func enemy_hp() -> Color:
	return _ENEMY_HP[_cb()]


static func alert_text() -> Color:
	return _ALERT_TEXT[_cb()]


static func preview_color() -> Color:
	return _PREVIEW[_cb()]


static func good() -> Color:
	return _GOOD[_cb()]


## O estado de vida do herói: {id, label, icon, color}. Caído (vida 0) conta como ferimento grave.
static func health_state(hp: int, max_hp: int) -> Dictionary:
	var share := float(hp) / float(maxi(1, max_hp))
	if share > HEALTHY_ABOVE:
		return {"id": "healthy", "label": "Em forma", "icon": "state_active", "color": _HEALTHY[_cb()]}
	if share >= heavy_below():
		return {"id": "light", "label": "Ferimento leve", "icon": "state_light_wound", "color": _LIGHT_WOUND[_cb()]}
	return {"id": "heavy", "label": "Ferimento grave", "icon": "state_wounded", "color": _HEAVY_WOUND[_cb()]}


## Abaixo desta fração da vida, ferimento grave: o mesmo limite do herói ferido que manca na exploração (#194), em
## data/wounded.json (Threshold). Lido pela árvore, e não pelo nome do autoload, para os scripts de captura (-s), que
## compilam antes dos autoloads; sem a tabela, LIGHT_FROM.
static func heavy_below() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	var data: Node = tree.root.get_node_or_null("GameData") if tree != null else null
	var row = data.row("wounded", "wounded") if data != null else null
	return float(row.Threshold) if row != null else LIGHT_FROM


## A entrada da peça no manifesto (os dois kits; os nomes não se repetem).
static func entry(piece: String) -> Dictionary:
	if _entries.is_empty():
		for path in MANIFESTS:
			var data = JSON.parse_string(FileAccess.get_file_as_string(path))
			if data is Dictionary:
				for name in data.get("assets", {}):
					_entries[name] = data.assets[name]
	return _entries.get(piece, {})


static func texture(piece: String) -> Texture2D:
	if not _textures.has(piece):
		var info := entry(piece)
		_textures[piece] = load("res://" + String(info.file)) if not info.is_empty() else null
	return _textures[piece]


## A caixa da peça: o 9-slice e o recuo do conteúdo do manifesto. tint: o modulate (as pílulas e preenchimentos claros
## são tingidos); pad: um recuo a mais (o conteúdo de um botão que cresce no Maior).
static func style(piece: String, tint: Color = Color.WHITE, pad: Vector4 = Vector4.ZERO) -> StyleBoxTexture:
	var info := entry(piece)
	var box := StyleBoxTexture.new()
	box.texture = texture(piece)
	var slice = info.get("nine_slice_ltrb")
	if slice is Array and slice.size() == 4:
		box.texture_margin_left = slice[0]
		box.texture_margin_top = slice[1]
		box.texture_margin_right = slice[2]
		box.texture_margin_bottom = slice[3]
	# O recuo do conteúdo; as peças de seleção não têm o seu e usam o da peça de base (o mesmo tamanho).
	var content = info.get("content_xywh")
	if not (content is Array) and piece.ends_with("_selected"):
		content = entry(piece.trim_suffix("_selected")).get("content_xywh")
	if content is Array and content.size() == 4:
		var size: Array = info.size
		box.content_margin_left = content[0] + pad.x
		box.content_margin_top = content[1] + pad.y
		box.content_margin_right = size[0] - content[0] - content[2] + pad.z
		box.content_margin_bottom = size[1] - content[1] - content[3] + pad.w
	if TILED_WIDE.has(piece):
		box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	if TILED.has(piece):
		box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.modulate_color = tint
	return box


static func icon(name: String) -> Texture2D:
	var path := ICONS % name
	return load(path) if ResourceLoader.exists(path) else null


## Os recursos pintados (#125), pelo nome antigo do ícone (art/ui/icons). Pintado não se tinge.
const PAINTED := {"lobby-seed": "resource_seeds", "lobby-scrap": "resource_scrap", "lobby-fragment": "resource_fragments",
	"lobby-food": "resource_food", "lobby-water": "resource_water", "lobby-energy": "resource_power",
	"res-bandages": "resource_bandages", "res-hope": "resource_hope"}


## O recurso pintado do nome antigo, ou null.
static func painted(name: String) -> Texture2D:
	return icon(PAINTED[name]) if PAINTED.has(name) else null


## Um ícone pelo nome antigo, para tingir: o glifo do kit (#135, mesmo nome) ou, sem ele, o SVG de art/ui/icons.
static func legacy_icon(name: String) -> Texture2D:
	var glyph_icon := icon(name)
	if glyph_icon != null:
		return glyph_icon
	var path := "res://art/ui/icons/%s.svg" % name
	return load(path) if ResourceLoader.exists(path) else null


static func font(emphasis: bool = false) -> Font:
	var path := FONT_SEMIBOLD if emphasis else FONT_MEDIUM
	if not _fonts.has(path):
		_fonts[path] = load(path)
	return _fonts[path]


## O tamanho de um uso de texto (SIZE), já no tamanho das Opções.
static func size(role: String) -> int:
	return U.px(int(SIZE.get(role, SIZE.text)))


## Um rótulo do kit: Barlow Condensed, a cor e o tamanho do uso; upper: caixa alta (a luta e os títulos).
static func label(text: String, role: String = "text", color: Color = TEXT, emphasis: bool = false, upper: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.uppercase = upper
	l.add_theme_font_override("font", font(emphasis))
	l.add_theme_font_size_override("font_size", size(role))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Um rótulo do kit por tamanho em px (na base de 1080p): para as telas que ainda dizem o tamanho em vez do uso. kind
## como no AHUiStyle.label: "display" (títulos: SemiBold em caixa alta), "bold" (SemiBold) ou "body" (Medium). A
## Barlow é condensada: o mínimo é o do kit (20 px).
static func label_px(text: String, base: int, color: Color = TEXT, kind: String = "body") -> Label:
	var l := label(text, "text", color, kind != "body", kind == "display")
	l.add_theme_font_size_override("font_size", U.px(maxi(int(SIZE.small), base + 2)))
	return l


## A ficha de um estado na luta: o fundo escuro e a borda na cor de bom ou de ruim (a forma do ícone também diz).
static func chip_style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(STEEL, 0.82)
	box.border_color = Color(color, 0.85)
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = 3
	box.content_margin_right = 4
	return box


## A cor da crise: a superação no âmbar, o colapso no texto de alerta.
static func crisis_color(breakthrough: bool) -> Color:
	return AMBER if breakthrough else alert_text()


# ---------------------------------------------------------------- componentes

## A peça de um componente na variante pedida (COMPONENTS).
static func piece_of(component: String, kind: String) -> String:
	var kinds: Dictionary = COMPONENTS.get(component, {})
	if not kinds.has(kind):
		push_error("Componente do kit sem a variante: %s/%s" % [component, kind])
		return ""
	return kinds[kind]


## Painel: "large" (as chapas grandes, com o aço repetido) ou "inset" (o painel de dentro).
static func panel_box(kind: String = "large", tint: Color = Color.WHITE) -> PanelContainer:
	return panel(piece_of("panel", kind), tint)


## Plaqueta (o nome da tela, o Registro).
static func plaque() -> PanelContainer:
	return panel(piece_of("plaque", "room"))


## Botão nos estados do kit: "primary", "secondary", "icon" ou "chip".
static func button(text: String = "", kind: String = "secondary", pad: Vector4 = Vector4.ZERO) -> Button:
	var b := Button.new()
	b.text = text.to_upper() if kind != "chip" else text
	style_as(b, kind, pad)
	return b


## Aplica o estilo de um componente de botão a um botão que já existe (os de "button", e os de plaqueta, aba e linha
## de lista que também se apertam: "plaque", "nav", "nav_active", "hero", "hero_selected", "list", "list_selected",
## "upgrade", "upgrade_selected").
static func style_as(target: BaseButton, kind: String, pad: Vector4 = Vector4.ZERO) -> void:
	var piece := ""
	for component in ["button", "plaque", "tab", "row", "card"]:
		if COMPONENTS[component].has(kind):
			piece = COMPONENTS[component][kind]
			break
	if kind == "plaque":
		piece = piece_of("plaque", "room")
	style_button(target, piece, pad)


## Barra: a calha main_bar com o preenchimento tingido ("hero" ciano, "enemy" vermelho, "xp", "instinct", "life",
## "state"), com o valor por dentro.
static func bar(color_kind: String, shown: float, top: float, caption: String = "", role: String = "world") -> AHKitBar:
	return AHKitBar.make(piece_of("bar", "main"), color_kind, shown, top, caption, role)


## Chip: "cost", "result" ou "resource" (a pílula do estado de vida é a AHKitPill).
static func chip(kind: String = "cost") -> PanelContainer:
	return panel(piece_of("chip", kind))


## Aba (não apertável): "card" (a aba sobre a carta), "nav" e as outras de COMPONENTS.tab.
static func tab(kind: String = "card") -> PanelContainer:
	return panel(piece_of("tab", kind))


## Carta: "hero" (a do relatório) ou "upgrade".
static func card(kind: String = "hero") -> PanelContainer:
	return panel(piece_of("card", kind))


## A escolha que fica (a opção marcada, quem age): a moldura âmbar sem fundo, por cima da peça.
static func selected_overlay() -> Panel:
	var frame := Panel.new()
	frame.name = "Selected"
	frame.add_theme_stylebox_override("panel", style(piece_of("focus", "selected")))
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return frame


## O véu de uma peça sem efeito (a habilidade sem uso, o cuidado que não serve): as riscas escuras por cima da chapa,
## sem transparência no texto (o texto fica no tom apagado).
static func veil() -> Panel:
	var cover := Panel.new()
	cover.name = "Veil"
	var box := style(piece_of("bar", "preview"), VEIL)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	cover.add_theme_stylebox_override("panel", box)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cover


## Um texto com a seta (→) desenhada: a Barlow Condensed não tem o caractere, então ele vira o ícone da seta, do tamanho
## do texto (hud-estacao.md, "A seta").
static func arrow_label(text: String, role: String = "text", color: Color = TEXT, emphasis: bool = false) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.autowrap_mode = TextServer.AUTOWRAP_OFF
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.add_theme_font_override("normal_font", font(emphasis))
	rich.add_theme_font_size_override("normal_font_size", size(role))
	rich.add_theme_color_override("default_color", color)
	set_arrow_text(rich, text)
	return rich


static func set_arrow_text(rich: RichTextLabel, text: String) -> void:
	var side := int(size(rich.get_meta("role", "text")) * 0.8) if rich.has_meta("role") else int(rich.get_theme_font_size("normal_font_size") * 0.8)
	var arrow := "[img=%dx%d color=#%s]res://art/ui/icons/ui-arrow-right.svg[/img]" % [side, side, AMBER.to_html(false)]
	rich.text = text.replace("[", "[lb]").replace("→", arrow)


## O retrato quadrado (o rosto do herói ou do civil na moldura square_portrait), do lado pedido.
static func portrait(texture: Texture2D, side: float, dim: bool = false) -> PanelContainer:
	var frame := panel("square_portrait")
	frame.name = "Portrait"
	frame.custom_minimum_size = Vector2(side, side)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := TextureRect.new()
	face.texture = texture
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.clip_contents = true
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim:
		face.modulate = DIM
	frame.add_child(face)
	return frame


## Um painel com a peça (para os componentes e para as peças só da luta, CODEX_ONLY).
static func panel(piece: String, tint: Color = Color.WHITE) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", style(piece, tint))
	return box


## Um ícone do kit tingido (os glifos brancos de um tom) ou como é (os pintados).
static func glyph(name: String, side: float, tint: Color = Color.WHITE) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = legacy_icon(name)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(side, side)
	rect.modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## O estilo de um botão do kit nos quatro estados: normal, foco (a peça de foco ou a moldura âmbar), apertado e
## desligado. Peças com as variantes (_focus, _pressed, _disabled) usam as delas; as outras, modulações da mesma.
static func style_button(button: BaseButton, piece: String, pad: Vector4 = Vector4.ZERO) -> void:
	var normal := style(piece, Color.WHITE, pad)
	var focus: StyleBox = style(piece + "_focus", Color.WHITE, pad) if not entry(piece + "_focus").is_empty() else _amber_focus(piece, pad)
	var pressed: StyleBox = style(piece + "_pressed", Color.WHITE, pad) if not entry(piece + "_pressed").is_empty() else style(piece, Color(0.85, 0.85, 0.85), pad + Vector4(0, 2, 0, -2))
	var disabled: StyleBox = style(piece + "_disabled", Color.WHITE, pad) if not entry(piece + "_disabled").is_empty() else style(piece, Color(0.6, 0.6, 0.6), pad)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", style(piece, Color(1.12, 1.1, 1.05), pad))
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_font_override("font", font(true))
	button.add_theme_font_size_override("font_size", size("primary"))
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(state, TEXT)
	button.add_theme_color_override("font_disabled_color", Color(TEXT, 0.72))


## O foco do teclado e do controle: a moldura âmbar do kit por cima da peça (hud-station.md, "Foco"), sem fundo.
static func _amber_focus(piece: String, pad: Vector4) -> StyleBox:
	var focus := style("focus_frame")
	var base := style(piece, Color.WHITE, pad)
	focus.content_margin_left = base.content_margin_left
	focus.content_margin_top = base.content_margin_top
	focus.content_margin_right = base.content_margin_right
	focus.content_margin_bottom = base.content_margin_bottom
	return focus


## Uma moldura só de borda (o contorno de quem age na faixa da rodada), sem fundo.
static func outline(color: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = color
	box.set_border_width_all(width)
	return box
