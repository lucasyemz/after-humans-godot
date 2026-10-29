## A barra de trechos da exploração (#180): a casa do guardião fica em alerta até ser vencido; vencido, fica como as
## outras resolvidas (o ícone verde e o check), mesmo sendo o trecho de agora, e o título diz "Guardião vencido". O
## trecho do trem no tutorial (#147) tem o ícone do trem, na cor dos outros.
extends RefCounted

var t


func run(context) -> void:
	t = context
	var hud := AHExplorationHud.new()
	var route := {"steps": [], "index": 0, "current_house": -1, "sites": []}
	# O guardião ainda por vir (o trecho de agora): em alerta, sem check.
	var boss := {"type": "boss", "resolved": false}
	var cell: Control = hud._route_cell(boss, true, true, route)
	t.check(_tint(cell).is_equal_approx(AHKit.alert_text()), "o guardião por vencer fica em alerta")
	t.check(not _has_check(cell), "e sem o check")
	t.equal(hud._step_label(boss), hud.tr(AHExplorationHud.STEP_LABELS.boss), "o título diz o guardião")
	cell.free()
	# Vencido: verde e com o check, mesmo sendo o trecho de agora (o último).
	boss.resolved = true
	cell = hud._route_cell(boss, true, true, route)
	t.check(_tint(cell).is_equal_approx(AHKit.good()), "o guardião vencido fica verde")
	t.check(_is_check(cell.get_child(cell.get_child_count() - 1)),
		"e com o check por cima da moldura de agora (o último filho), mesmo sendo o trecho de agora")
	t.equal(hud._step_label(boss), hud.tr("Guardião vencido"), "o título diz que acabou")
	cell.free()
	# Os outros trechos: o resolvido de agora segue sem check (a moldura de agora já marca), o de antes com check.
	var fight := {"type": "combat", "resolved": true}
	cell = hud._route_cell(fight, true, true, route)
	t.check(not _has_check(cell), "um trecho comum resolvido, sendo o de agora, fica sem o check")
	cell.free()
	cell = hud._route_cell(fight, false, true, route)
	t.check(_has_check(cell) and _tint(cell).is_equal_approx(AHKit.good()), "o de antes, verde e com o check")
	cell.free()
	# O trem do tutorial (#147): o ícone do trem do lobby (train_arrival, o do serviço do trem na Estação), na cor dos
	# ícones da exploração (não o do guardião, nem o alerta dele).
	var train := {"type": "train", "resolved": false}
	cell = hud._route_cell(train, true, true, route)
	var icon := cell.get_child(0) as TextureRect
	t.check(icon.texture == AHKit.legacy_icon("train_arrival") and icon.texture != AHKit.legacy_icon("node-boss"), "o trecho do trem com o ícone do trem")
	t.check(_tint(cell).is_equal_approx(AHKit.AMBER), "na cor do trecho de agora, como os outros")
	cell.free()
	cell = hud._route_cell(train, false, true, route)
	t.check(_tint(cell).is_equal_approx(AHKit.TEXT), "e, à frente, na cor dos outros ícones")
	cell.free()
	# Resolvido: verde como os outros trechos; com o check só quando já não é o de agora.
	train.resolved = true
	cell = hud._route_cell(train, true, true, route)
	t.check(_tint(cell).is_equal_approx(AHKit.good()) and not _has_check(cell), "o trem resolvido, sendo o de agora: verde, sem o check")
	cell.free()
	cell = hud._route_cell(train, false, true, route)
	t.check(_tint(cell).is_equal_approx(AHKit.good()) and _has_check(cell), "e, depois dele, verde e com o check")
	cell.free()
	hud.free()


## A cor do ícone do trecho (o primeiro filho, o glifo tingido).
func _tint(cell: Control) -> Color:
	return (cell.get_child(0) as TextureRect).modulate


## O check é o glifo "state_active" do kit.
func _has_check(cell: Control) -> bool:
	return cell.get_children().any(_is_check)


func _is_check(node: Node) -> bool:
	return node is TextureRect and node.texture == AHKit.legacy_icon("state_active")
