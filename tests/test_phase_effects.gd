## Os efeitos de fase dos eventos na luta (#78, decisão do Lucas: a luta aplica corridor.effects). Exposto: a próxima
## luta começa com cada herói Vulnerável, e o efeito sai da lista quando ela começa. Cansado: −1 de velocidade nas lutas
## até o fim da fase. Preparado: 1 Bloqueio no começo de cada luta da fase. O resultado do evento diz o efeito num chip.
extends RefCounted

const R = preload("res://scripts/flow/journey_rules.gd")

var t


func run(context) -> void:
	t = context
	_known()
	_combat()
	_spend()
	_changes()


## Todo efeito que os eventos dão (PhaseEffects em data/events.json) tem regra na luta e texto no chip.
func _known() -> void:
	var used := {}
	for event_id in GameData.table("events"):
		for choice in GameData.row("events", event_id).get("Choices", []):
			for side in ["Success", "Failure"]:
				for id in choice.get(side, {}).get("PhaseEffects", []):
					used[id] = true
	t.check(used.size() >= 3, "os eventos dão efeitos de fase (%s)" % [used.keys()])
	for id in used:
		t.check(R.PHASE_EFFECTS.has(id), "o efeito %s tem regra na luta" % id)
		t.check(String(R.PHASE_EFFECTS.get(id, {}).get("text", "")) != "", "e um texto para o chip (%s)" % id)


func _session(effects: Array) -> AHCombatSession:
	var c: Dictionary = Campaign.create_initial(5)
	R.start_expedition(c, "fase_1", 77)
	var heroes: Array = c.session.expedition.team.map(func(id): return _hero(c, id))
	return AHCombatSession.create(heroes, ["robot"], false, 31, 80, effects)


func _hero(c: Dictionary, id: String) -> Dictionary:
	for hero in c.roster:
		if hero.id == id:
			return hero
	return {}


## Cada efeito muda os heróis da luta (e só eles), e a luta diz no registro o que vale.
func _combat() -> void:
	var plain := _session([])
	var tired := _session(["cansado"])
	var exposed := _session(["exposto"])
	var ready := _session(["preparado", "cansado"])
	for index in plain.state.player_team.size():
		var base: AHCombat.Unit = plain.state.player_team[index]
		t.equal(tired.state.player_team[index].speed, base.speed - 1, "Cansado: %s com −1 de velocidade" % base.display_name)
		t.equal(exposed.state.player_team[index].tokens.vuln, 1, "Exposto: %s começa Vulnerável" % base.display_name)
		t.equal(exposed.state.player_team[index].tokens.block, 0, "e sem Bloqueio")
		t.equal(ready.state.player_team[index].tokens.block, 1, "Preparado: %s começa com 1 Bloqueio" % base.display_name)
		t.equal(ready.state.player_team[index].speed, base.speed - 1, "e o Cansado junto ainda tira a velocidade")
		t.equal(base.tokens.vuln + base.tokens.block, 0, "sem efeito, nada muda")
	for session in [tired, exposed, ready]:
		var enemy: AHCombat.Unit = session.state.enemy_team[0]
		t.equal([enemy.speed, enemy.tokens.vuln, enemy.tokens.block], [plain.state.enemy_team[0].speed, 0, 0], "os inimigos não mudam")
	t.check(Array(exposed.state.combat_log).has("Exposto: a equipe começa Vulnerável."), "o registro da luta diz o efeito")
	t.check(not Array(plain.state.combat_log).any(func(line): return String(line).begins_with("Exposto") or String(line).begins_with("Cansado")),
		"sem efeito, o registro não fala dele")


## A luta começou: o Exposto (uma luta só) sai; Cansado e Preparado ficam até o fim da fase. Expedição nova, lista vazia.
func _spend() -> void:
	var c: Dictionary = Campaign.create_initial(5)
	R.start_expedition(c, "fase_1", 78)
	t.equal(R.phase_effects(c), [], "a expedição começa sem efeitos")
	c.session.expedition.corridor.effects = ["exposto", "cansado", "preparado", "desconhecido"]
	t.equal(R.phase_effects(c), ["exposto", "cansado", "preparado"], "a luta lê só os efeitos com regra")
	R.spend_fight_effects(c)
	t.equal(c.session.expedition.corridor.effects, ["cansado", "preparado", "desconhecido"], "o Exposto se gasta na luta")
	R.spend_fight_effects(c)
	t.equal(R.phase_effects(c), ["cansado", "preparado"], "os da fase ficam de luta em luta")
	R.start_expedition(c, "fase_1", 79)
	t.equal(R.phase_effects(c), [], "a fase seguinte começa sem eles")
	t.equal(R.phase_effects({}), [], "sem expedição, nenhum")


## O resultado do evento traz o efeito (e a ferramenta ganha) na lista dos chips.
func _changes() -> void:
	var found := {}
	for event_id in GameData.table("events"):
		for choice in GameData.row("events", event_id).get("Choices", []):
			var effects: Array = choice.get("Success", {}).get("PhaseEffects", [])
			var tool := String(choice.get("Success", {}).get("GrantTool", ""))
			if (effects.is_empty() and tool == "") or float(choice.get("FailChance", 0.0)) > 0.0:
				continue
			var c: Dictionary = Campaign.create_initial(4)
			R.start_expedition(c, "fase_1", 90)
			c.tools = c.tools.filter(func(x): return x != tool)
			c.session.event = {"event_id": event_id, "from_search": true, "resolution": "", "pending_hard_combat": false, "object": ""}
			if not R.can_choose(c, choice) or not R.choose_event_option(c, choice.Id, 3):
				continue
			var listed: Array = c.session.event.changes.filter(func(x): return x.kind == "effect").map(func(x): return x.id)
			t.equal(listed, effects, "%s/%s: os chips dizem os efeitos" % [event_id, choice.Id])
			for change in c.session.event.changes.filter(func(x): return x.kind == "effect"):
				t.equal(int(change.amount) > 0, bool(R.PHASE_EFFECTS[change.id].good), "%s: a cor do chip segue o efeito (%s)" % [event_id, change.id])
			if tool != "":
				t.check(c.session.event.changes.any(func(x): return x.kind == "tool" and x.id == tool and int(x.amount) == 1), "%s: o chip da ferramenta ganha" % event_id)
				found.tool = true
			found.effect = found.get("effect", false) or not effects.is_empty()
	t.check(found.get("effect", false) and found.get("tool", false), "conferidos os chips de efeito e de ferramenta (%s)" % [found])
