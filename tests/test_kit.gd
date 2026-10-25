## O kit da HUD (#60): as peças do Codex viram estilos com as medidas do assets.json (9-slice e recuo do conteúdo), o
## aço repete nas peças grandes, as fontes são a Barlow Condensed, os estados de vida seguem a decisão do Lucas (75% e
## 50%), as cores do daltonismo valem na hora nas barras e nas pílulas, e a tecla acompanha a troca nas Opções.
extends RefCounted

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_manifest()
	_states()
	await _components()


func _manifest() -> void:
	var missing: Array = []
	for path in AHKit.MANIFESTS:
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		for name in data.assets:
			if AHKit.texture(name) == null:
				missing.append(name)
	t.equal(missing, [], "toda peça dos dois manifestos carrega")
	var panel := AHKit.style("hero_panel")
	t.equal([panel.texture_margin_left, panel.texture_margin_top, panel.texture_margin_right, panel.texture_margin_bottom], [224.0, 24.0, 24.0, 24.0],
		"o 9-slice vem do assets.json (o painel do herói protege a coluna do retrato)")
	t.equal([panel.content_margin_left, panel.content_margin_top], [232.0, 40.0], "o recuo do conteúdo vem do content_xywh")
	var band := AHKit.style("report_band")
	t.check(band.axis_stretch_horizontal == StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT, "as peças grandes repetem o aço (TILE_FIT)")
	t.check(AHKit.style("panel").axis_stretch_horizontal == StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH, "as pequenas esticam")
	var selected := AHKit.style("hero_tab_selected")
	t.equal(selected.content_margin_left, AHKit.style("hero_tab").content_margin_left, "a peça de escolha usa o recuo da peça de base")
	t.check(AHKit.font(false).resource_path.ends_with("barlow_condensed_medium.ttf") and AHKit.font(true).resource_path.ends_with("barlow_condensed_semibold.ttf"),
		"as fontes são a Barlow Condensed Medium e SemiBold")
	var scale: float = AHUiStyle.text_scale
	AHUiStyle.text_scale = 1.3
	t.equal(AHKit.size("hero_name"), 52, "no texto Maior o nome do herói vai de 40 para 52 (130%)")
	AHUiStyle.text_scale = scale


func _states() -> void:
	t.equal(AHKit.health_state(34, 34).id, "healthy", "vida cheia: Em forma")
	t.equal(AHKit.health_state(26, 34).id, "healthy", "acima de 75%: Em forma")
	t.equal(AHKit.health_state(25, 34).id, "light", "75% ou menos: Ferimento leve")
	t.equal(AHKit.health_state(12, 24).id, "light", "50% exatos: Ferimento leve")
	t.equal(AHKit.health_state(11, 24).id, "heavy", "abaixo de 50%: Ferimento grave")
	t.equal(AHKit.health_state(0, 24).id, "heavy", "caído: Ferimento grave")
	t.equal([AHKit.health_state(34, 34).label, AHKit.health_state(17, 23).label, AHKit.health_state(8, 24).label], ["Em forma", "Ferimento leve", "Ferimento grave"],
		"os rótulos neutros")


func _components() -> void:
	var host := Control.new()
	_tree.root.add_child(host)
	var bar := AHKitBar.make("health_enemy", "enemy", 6, 8, "6/8")
	var pill := AHKitPill.make(8, 24)
	var key := AHKitKey.make("combat_move")
	var instinct := AHKitBar.make("main_bar", "instinct", 10, 200)
	for node in [bar, pill, key, instinct]:
		host.add_child(node)
	await _tree.process_frame
	var colorblind: bool = Settings.colorblind
	Settings.colorblind = false
	bar.restyle()
	pill.restyle()
	t.equal(bar.fill_color(), Color("d23a2e"), "a vida das máquinas em vermelho")
	t.equal(instinct.fill_color(), AHKit.INSTINCT, "o instinto em ferrugem (decisão do Lucas)")
	t.check(String(pill.get_meta("state")) == "heavy" and (pill.get_theme_stylebox("panel") as StyleBoxTexture).modulate_color == Color("d23a2e"), "a pílula do ferimento grave no vermelho")
	Settings.colorblind = true
	bar.restyle()
	pill.restyle()
	t.equal(bar.fill_color(), Color("e69f00"), "no daltonismo, a vida das máquinas em laranja")
	t.equal((pill.get_theme_stylebox("panel") as StyleBoxTexture).modulate_color, Color("d55e00"), "e a pílula no vermelhão")
	Settings.colorblind = colorblind
	t.check(key.has_meta("ah_action") and (key.get_child(0) as Label).text == AHUiStyle.key_name("combat_move"), "a tecla mostra a da ação (com as trocas das Opções)")
	host.queue_free()
	await _tree.process_frame
