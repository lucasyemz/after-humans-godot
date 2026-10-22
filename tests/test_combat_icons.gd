## Os ícones da luta (#30, a entrega #18): cada estado com ícone aponta para um SVG que existe, na versão boa ou ruim de
## quem recebe; a ficha mostra o ícone e o número, e o nome e a explicação ficam na dica; cada intenção do inimigo tem o
## seu ícone.
extends RefCounted

const S := preload("res://scripts/ui/ui_style.gd")


func run(t) -> void:
	var unit := AHCombat.Unit.new()
	unit.display_name = "Teste"
	unit.tokens.block = 2
	unit.tokens.dodge = 1
	unit.tokens.guard = 1
	unit.tokens.vuln = 1
	unit.mark_duration = 2
	unit.stun_turns = 1
	unit.bleed.duration = 3
	unit.bleed.magnitude = 2
	unit.blight.duration = 2
	unit.blight.magnitude = 1
	unit.blind = true
	var entries := S.statuses(unit)
	t.equal(entries.size(), 9, "nove estados na unidade de teste")
	var icons := {}
	for entry in entries:
		t.equal(entry.size(), 5, "%s tem texto, bom, ícone, número e termo" % entry[0])
		if entry[2] == "":
			continue
		icons[entry[2]] = entry[1]
		for side in ["good", "bad"]:
			var path := "res://art/ui/icons/status-%s_%s.svg" % [entry[2], side]
			t.check(ResourceLoader.exists(path), "%s existe" % path)
		t.check(S.status_tip(entry).begins_with(entry[4]) and S.status_tip(entry).contains(S.GLOSSARY[entry[4]]), "a dica de %s explica o termo" % entry[0])
	t.equal(icons.keys().size(), 8, "os oito símbolos da entrega aparecem (bloqueio, esquiva, proteção, vulnerável, marca, atordoado, sangramento, veneno)")
	t.check(icons.block and icons.dodge and icons.protection, "bloqueio, esquiva e proteção são bons para quem recebe")
	t.check(not icons.vulnerable and not icons.marked and not icons.bleeding and not icons.poison and not icons.stunned, "os outros são ruins")
	var bleed: Array = entries.filter(func(e): return e[4] == "Sangra")[0]
	t.equal(bleed[3], 3, "o sangramento mostra as vezes que faltam")
	t.check(S.status_tip(bleed).contains("2 por vez") and S.status_tip(bleed).contains("3 vezes"), "e a dica diz quanto por vez e quantas vezes")

	var hud := AHCombatHud.new()
	var chip: PanelContainer = hud._status_chip(entries[0])
	var icon := chip.find_child("Icon", true, false) as TextureRect
	t.check(icon != null and icon.texture != null, "a ficha de estado mostra o ícone")
	var count := chip.find_child("Count", true, false) as Label
	t.check(count != null and count.text == "2", "com o número (2 de bloqueio)")
	t.check(chip.tooltip_text.contains(S.GLOSSARY.Bloqueio), "o nome e a explicação ficam na dica do mouse")
	t.check(chip.mouse_filter != Control.MOUSE_FILTER_IGNORE, "a ficha recebe o mouse (para a dica)")
	var blind: PanelContainer = hud._status_chip(entries.filter(func(e): return e[4] == "Cego")[0])
	t.check(blind.find_child("Icon", true, false) == null, "sem ícone na entrega, a ficha continua escrita")
	var good_icon: Texture2D = S.combat_icon("status-block_good")
	var bad_icon: Texture2D = S.combat_icon("status-block_bad")
	t.check(good_icon != null and bad_icon != null and good_icon != bad_icon, "bom e ruim são arquivos diferentes (a forma muda, não só a cor)")
	chip.free()
	blind.free()
	hud.free()

	for name in ["attack", "attack_area", "heal", "block", "move", "stunned", "unknown"]:
		t.check(S.combat_icon("intent-" + name) != null, "a intenção %s tem ícone" % name)
