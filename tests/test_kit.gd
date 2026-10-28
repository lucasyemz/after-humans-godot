## O kit da HUD (#60): as peças do Codex viram estilos com as medidas do assets.json (9-slice e recuo do conteúdo), o
## aço repete nas peças grandes, as fontes são a Barlow Condensed, os estados de vida seguem a decisão do Lucas (75% e
## 30%), as cores do daltonismo valem na hora nas barras e nas pílulas, e a tecla acompanha a troca nas Opções.
extends RefCounted

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_manifest()
	_states()
	_faces()
	_standard()
	await _components()


func _manifest() -> void:
	var missing: Array = []
	for path in AHKit.MANIFESTS:
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		for name in data.assets:
			if AHKit.texture(name) == null:
				missing.append(name)
	t.equal(missing, [], "toda peça dos dois manifestos carrega")
	var panel := AHKit.style(AHKit.piece_of("panel", "large"))
	t.equal([panel.texture_margin_left, panel.texture_margin_top, panel.texture_margin_right, panel.texture_margin_bottom], [44.0, 44.0, 44.0, 44.0],
		"o 9-slice vem do assets.json (o Painel da Awesomic)")
	t.equal([panel.content_margin_left, panel.content_margin_top], [24.0, 22.0], "o recuo do conteúdo vem do content_xywh")
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
	t.equal(AHKit.health_state(9, 30).id, "light", "30% exatos: Ferimento leve")
	t.equal(AHKit.health_state(8, 30).id, "heavy", "abaixo de 30%: Ferimento grave")
	t.equal(AHKit.health_state(0, 24).id, "heavy", "caído: Ferimento grave")
	t.equal([AHKit.health_state(34, 34).label, AHKit.health_state(17, 23).label, AHKit.health_state(7, 24).label], ["Em forma", "Ferimento leve", "Ferimento grave"],
		"os rótulos neutros")


## O padrão (decisão do Lucas, hud-direction.md): todo componente lê uma peça da Awesomic (o manifesto de
## art/ui/kit/station, ou uma que ele reaproveita da luta), e as peças do Codex que deixaram de valer não aparecem no
## código.
func _standard() -> void:
	var station = JSON.parse_string(FileAccess.get_file_as_string(AHKit.MANIFESTS[1]))
	var allowed: Array = station.assets.keys() + station.get("reuses_combat_kit", [])
	var outside: Array = []
	for component in AHKit.COMPONENTS:
		for kind in AHKit.COMPONENTS[component]:
			if not allowed.has(AHKit.COMPONENTS[component][kind]):
				outside.append("%s/%s" % [component, kind])
	t.equal(outside, [], "todo componente usa uma peça da Awesomic")
	var pattern := RegEx.create_from_string("AHKit(Bar|Key)?\\.(style|panel|make)\\(\"(%s)\"|AHKit\\.style_button\\([^,]+, \"(%s)\"" % ["|".join(AHKit.RETIRED), "|".join(AHKit.RETIRED)])
	var found: Array = []
	for path in _scripts("res://scripts"):
		if path.ends_with("kit/kit.gd"):
			continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			if pattern.search(lines[i]) != null:
				found.append("%s:%d" % [path.get_file(), i + 1])
	t.equal(found, [], "nenhuma peça aposentada do Codex (%s) no código" % ", ".join(AHKit.RETIRED))


func _scripts(dir: String) -> Array:
	var out: Array = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(sub)))
	return out


## Os retratos quadrados da faixa da rodada não saem vazios (o Rastejante de Cabos, deitado, saía com 1% de pixels).
func _faces() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(AHCombatArena.ART_MANIFEST))
	var empty: Array = []
	for group in ["heroes", "enemies"]:
		for id in manifest[group]:
			var art: Dictionary = manifest[group][id].get("idle", {})
			if not art.is_empty() and AHUiStyle.opaque_share(AHUiStyle.face_texture(art).get_image()) < AHUiStyle.FACE_MIN_OPAQUE:
				empty.append(id)
	t.equal(empty, [], "nenhum retrato da ordem sai vazio (heróis e máquinas)")


func _components() -> void:
	var host := Control.new()
	_tree.root.add_child(host)
	var bar := AHKit.bar("enemy", 6, 8, "6/8")
	var pill := AHKitPill.make(7, 24)
	var key := AHKitKey.make("combat_move")
	var instinct := AHKit.bar("instinct", 10, 200)
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
