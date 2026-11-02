## A barra de trechos da exploração (#180): a casa do guardião fica em alerta até ser vencido; vencido, fica como as
## outras resolvidas (o ícone verde e o check), mesmo sendo o trecho de agora, e o título diz "Guardião vencido". O
## trecho do trem no tutorial (#147) tem o ícone do trem, na cor dos outros. O trecho do preso e o pino do resgate têm a
## mão erguida (#295).
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
	# O trecho do preso (#188, #295): a mão erguida (node-rescue) no lugar do ícone de suprimentos; o outro trecho de
	# suprimentos segue com o dele, e a casa ainda não alcançada continua com "?".
	var prisoner := {"type": "loot", "resolved": false}
	var supplies := {"type": "loot", "resolved": false}
	var with_rescue := {"steps": [supplies, prisoner], "index": 0, "current_house": -1, "sites": [], "rescue": {"step": 1}}
	cell = hud._route_cell(prisoner, true, true, with_rescue)
	t.check((cell.get_child(0) as TextureRect).texture == AHKit.legacy_icon("node-rescue") and AHKit.legacy_icon("node-rescue") != null,
		"o trecho do preso com o ícone de resgate")
	t.check(_tint(cell).is_equal_approx(AHKit.AMBER), "na cor do trecho de agora")
	cell.free()
	cell = hud._route_cell(supplies, false, true, with_rescue)
	t.check((cell.get_child(0) as TextureRect).texture == AHKit.legacy_icon("node-loot"), "o outro trecho de suprimentos segue com o dele")
	cell.free()
	cell = hud._route_cell(prisoner, false, false, with_rescue)
	t.check(cell.get_child(0) is Label and (cell.get_child(0) as Label).text == "?", "não alcançado, o trecho do preso continua com ?")
	cell.free()
	t.check(not AHExplorationHud._is_rescue_step(prisoner, {"steps": [supplies, prisoner], "index": 0}), "sem resgate na rota, nenhum trecho é o do preso")
	# O título do trecho: "Resgate" no do preso da expedição de agora; o outro de suprimentos e, sem expedição, o do tipo.
	var real_state = Campaign.state
	Campaign.state = {"session": {"expedition": {"corridor": with_rescue}}}
	t.equal(hud._step_label(prisoner), hud.tr("Resgate"), "o título do trecho do preso diz Resgate")
	t.equal(hud._step_label(supplies), hud.tr(AHExplorationHud.STEP_LABELS.loot), "o outro trecho de suprimentos segue Suprimentos")
	Campaign.state = {"session": {"expedition": null}}
	t.equal(hud._step_label(prisoner), hud.tr(AHExplorationHud.STEP_LABELS.loot), "sem expedição, o título volta ao do tipo")
	Campaign.state = real_state
	t.check(not AHExplorationHud._is_rescue_step({"type": "loot", "resolved": false}, with_rescue), "um trecho igual, mas de outra rota, não é o do preso")
	hud.free()
	# O pino do resgate no Mapa da Rede (#295): a mão erguida numa placa escura do kit, maior que os outros faróis.
	var parent := Control.new()
	AHMissionBoard._pin(parent, "Rescue_0", "Resgatar Véspera", "node-rescue", AHKit.alert_text(), Vector2(300, 300), false, true)
	AHMissionBoard._pin(parent, "Mission_0", "Uma missão", "marker-here", AHKit.TEXT, Vector2(600, 300), false)
	var plate := parent.get_node_or_null("Rescue_0/Plate") as PanelContainer
	t.check(plate != null and plate.get_node_or_null("Beacon") is TextureRect, "o farol do resgate fica na placa")
	t.check(plate != null and (plate.get_node("Beacon") as TextureRect).texture == AHKit.legacy_icon("node-rescue"), "com o ícone de resgate")
	t.check(parent.get_node_or_null("Mission_0/Beacon") is TextureRect and parent.get_node_or_null("Mission_0/Plate") == null, "os outros pinos seguem sem a placa")
	parent.free()


## A cor do ícone do trecho (o primeiro filho, o glifo tingido).
func _tint(cell: Control) -> Color:
	return (cell.get_child(0) as TextureRect).modulate


## O check é o glifo "state_active" do kit.
func _has_check(cell: Control) -> bool:
	return cell.get_children().any(_is_check)


func _is_check(node: Node) -> bool:
	return node is TextureRect and node.texture == AHKit.legacy_icon("state_active")
