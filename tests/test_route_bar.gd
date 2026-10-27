## A barra de trechos da exploração (#180): a casa do guardião fica em alerta até ser vencido; vencido, fica como as
## outras resolvidas (o ícone verde e o check), mesmo sendo o trecho de agora, e o título diz "Guardião vencido".
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
	hud.free()


## A cor do ícone do trecho (o primeiro filho, o glifo tingido).
func _tint(cell: Control) -> Color:
	return (cell.get_child(0) as TextureRect).modulate


## O check é o glifo "state_active" do kit.
func _has_check(cell: Control) -> bool:
	return cell.get_children().any(_is_check)


func _is_check(node: Node) -> bool:
	return node is TextureRect and node.texture == AHKit.legacy_icon("state_active")
