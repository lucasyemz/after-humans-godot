## O kit da HUD (#60): as peças do Codex (art/ui/kit/combat e art/ui/kit/station, aprovadas pelo Lucas na #97 e na
## #104) viram estilos e componentes, com os tokens num lugar só. As medidas vêm dos assets.json (docs/design/
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
const FONT_MEDIUM := "res://art/ui/fonts/barlow_condensed_medium.ttf"
const FONT_SEMIBOLD := "res://art/ui/fonts/barlow_condensed_semibold.ttf"
const ICONS := "res://art/ui/kit/station/icons/%s.webp"

## Os tamanhos de texto na base de 1080p (o Maior multiplica por 1,3 no px()).
const SIZE := {
	# Luta (hud-target.md, "Fonte e texto Maior").
	"register": 30, "round": 30, "hero_name": 40, "ability_name": 32, "hero_value": 32, "world": 26, "tab": 26,
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
const _HERO_HP := [Color("2fb6bd"), Color("56b4e9")]
const _ENEMY_HP := [Color("d23a2e"), Color("e69f00")]
const _HEALTHY := [Color("56b468"), Color("56b4e9")]
const _LIGHT_WOUND := [Color("f0a020"), Color("f0e442")]
const _HEAVY_WOUND := [Color("d23a2e"), Color("d55e00")]
const _ALERT_TEXT := [Color("e2584a"), Color("e8743a")]
const _GOOD := [Color("6cc77c"), Color("56b4e9")]

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


static func good() -> Color:
	return _GOOD[_cb()]


## O estado de vida do herói: {id, label, icon, color}. Caído (vida 0) conta como ferimento grave.
static func health_state(hp: int, max_hp: int) -> Dictionary:
	var share := float(hp) / float(maxi(1, max_hp))
	if share > HEALTHY_ABOVE:
		return {"id": "healthy", "label": "Em forma", "icon": "state_active", "color": _HEALTHY[_cb()]}
	if share >= LIGHT_FROM:
		return {"id": "light", "label": "Ferimento leve", "icon": "state_light_wound", "color": _LIGHT_WOUND[_cb()]}
	return {"id": "heavy", "label": "Ferimento grave", "icon": "state_wounded", "color": _HEAVY_WOUND[_cb()]}


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
	if TILED.has(piece):
		box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.modulate_color = tint
	return box


static func icon(name: String) -> Texture2D:
	var path := ICONS % name
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


## Um painel com a peça.
static func panel(piece: String, tint: Color = Color.WHITE) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", style(piece, tint))
	return box


## Um ícone do kit tingido (os glifos brancos de um tom) ou como é (os pintados).
static func glyph(name: String, side: float, tint: Color = Color.WHITE) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = icon(name)
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
