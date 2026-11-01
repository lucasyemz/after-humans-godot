## A escada da história no jogo (#64): o evento de história da fase abre na primeira Passagem dela, uma vez por campanha
## (fases sem evento não abrem nada), e a primeira vitória em cada fase traz a linha "O que a equipe viu" no relatório,
## também uma vez. Os saves de antes ganham as listas vazias.
extends RefCounted

const R = preload("res://scripts/flow/journey_rules.gd")
const S = preload("res://scripts/flow/station_rules.gd")


func run(t) -> void:
	for phase_id in ["fase_1", "fase_2", "fase_3", "fase_4", "fase_5"]:
		_passage(t, phase_id)
	_report(t)
	# Save anterior: sem as listas, a migração as cria vazias.
	var old: Dictionary = Campaign.create_initial(5)
	old.station.erase("story_events")
	old.station.erase("story_reports")
	S.migrate(old)
	t.check(old.station.get("story_events") == [] and old.station.get("story_reports") == [], "save anterior ganha as listas vazias")


func _campaign(phase_id: String) -> Dictionary:
	var campaign: Dictionary = Campaign.create_initial(31)
	campaign.completed_phases = ["fase_1", "fase_2", "fase_3", "fase_4"]
	S.confirm_departure(campaign, campaign.preferred_formation.duplicate(), 0, 4242, phase_id, "parts")
	# Com o par calmo (#292), algumas rotas têm a única Passagem na travessia: sorteia outra, como na segunda expedição.
	if not _has_phase_passage(campaign, phase_id):
		_again(campaign, phase_id, 4243)
	return campaign


func _has_phase_passage(campaign: Dictionary, phase_id: String) -> bool:
	var steps: Array = campaign.session.expedition.corridor.steps
	for step in steps.size():
		if steps[step].type == "passage" and R.map_for_step(phase_id, step) == R.phase(phase_id).get("map", ""):
			return true
	return false


## Anda pelo corredor até a primeira Passagem no mapa da fase (vencendo as patrulhas do caminho; a da travessia não
## abre o evento) e devolve o que a entrada dela deu.
func _walk_to_passage(campaign: Dictionary) -> String:
	var route: Dictionary = campaign.session.expedition.corridor
	var phase_id: String = campaign.session.expedition.phase_id
	for step in range(1, route.steps.size()):
		route.steps[route.index].resolved = true
		var outcome: String = R.enter_step(campaign, step)
		if route.steps[step].type == "passage":
			if R.map_for_step(phase_id, step) != R.phase(phase_id).get("map", ""):
				if outcome != "":
					return "abriu na travessia"
				continue
			return outcome
	return "sem passagem"


func _passage(t, phase_id: String) -> void:
	var campaign := _campaign(phase_id)
	var outcome := _walk_to_passage(campaign)
	var expected: String = R.STORY_EVENTS.get(phase_id, "")
	if expected == "":
		t.check(outcome == "" and campaign.session.event == null, "%s: a Passagem sem evento de história" % phase_id)
		return
	t.check(outcome == "event" and campaign.session.event != null and campaign.session.event.event_id == expected,
		"%s: a primeira Passagem abre %s" % [phase_id, expected])
	t.check(GameData.row("events", expected) != null, "%s: o evento existe nos dados" % phase_id)
	var row = GameData.row("events", expected)
	R.choose_event_option(campaign, row.Choices[-1].Id, 1)
	t.check(R.finish_event(campaign) and campaign.session.event == null, "%s: o evento fecha e a fase segue" % phase_id)
	# O que libera uma classe (o guaxinim) volta enquanto ela não for liberada; os outros não repetem.
	var unlocks := ""
	for choice in row.Choices:
		unlocks = String(choice.get("Success", {}).get("UnlockClass", "")) if unlocks == "" else unlocks
	_again(campaign, phase_id, 99)
	if unlocks == "":
		t.equal(_walk_to_passage(campaign), "", "%s: a segunda expedição não repete o evento" % phase_id)
		return
	t.equal(_walk_to_passage(campaign), "event", "%s: recusado, o evento volta (a classe não se perde)" % phase_id)
	campaign.session.expedition.food = 9
	R.choose_event_option(campaign, row.Choices[0].Id, 1)
	R.finish_event(campaign)
	t.check(campaign.unlocked_classes.has(unlocks), "%s: aceito, a classe é liberada" % phase_id)
	_again(campaign, phase_id, 98)
	t.equal(_walk_to_passage(campaign), "", "%s: liberada, o evento não volta" % phase_id)


## Uma nova expedição da mesma fase, na mesma campanha.
## Sorteia até a rota ter uma Passagem no mapa da fase (em algumas, a única fica na travessia).
func _again(campaign: Dictionary, phase_id: String, seed_value: int) -> void:
	for attempt in 50:
		campaign.session = {"screen": "shelter", "result": "", "expedition": null, "event": null}
		campaign.station.train.phase = "none"
		S.confirm_departure(campaign, campaign.preferred_formation.duplicate(), 0, seed_value + attempt, phase_id, "parts")
		var steps: Array = campaign.session.expedition.corridor.steps
		for step in steps.size():
			if steps[step].type == "passage" and R.map_for_step(phase_id, step) == R.phase(phase_id).get("map", ""):
				return


func _report(t) -> void:
	var campaign := _campaign("fase_5")
	campaign.session.result = "victory"
	var first: Dictionary = S.finish_return(campaign)
	t.equal(first.get("story", ""), R.STORY_REPORTS.fase_5, "a primeira vitória traz o que a equipe viu")
	t.equal(campaign.station.last_return.get("story", ""), R.STORY_REPORTS.fase_5, "e fica no relatório")
	# A noite da volta resolvida à parte: só a segunda saída importa aqui.
	campaign.night.phase = "none"
	campaign.station.train.phase = "none"
	t.equal(S.confirm_departure(campaign, campaign.preferred_formation.duplicate(), 0, 98, "fase_5", "parts"), "", "a segunda expedição parte")
	campaign.session.result = "victory"
	t.equal(S.finish_return(campaign).get("story", "x"), "", "a segunda vitória na fase não repete")
	# Fase com evento de história: sem o evento visto, a linha (que cita o que ele mostrou) fica para depois.
	var unseen := _campaign("fase_2")
	unseen.session.result = "victory"
	t.equal(S.finish_return(unseen).get("story", "x"), "", "sem o evento da fase visto, a linha fica para depois")
	t.check(not unseen.station.story_reports.has("fase_2"), "e não é gasta")
	var seen := _campaign("fase_2")
	seen.station.story_events.append("fase_2")
	seen.session.result = "victory"
	t.equal(S.finish_return(seen).get("story", ""), R.STORY_REPORTS.fase_2, "com o evento visto, a linha vem")
	var lost := _campaign("fase_1")
	lost.session.result = "defeat"
	t.equal(S.finish_return(lost).get("story", "x"), "", "a derrota não traz a linha")
	# A linhagem é palavra da luta desde a #227: a linha da fase 3 não a põe entre as que ninguém entende (#285).
	t.check(not R.STORY_REPORTS.fase_3.contains("linhagem"), "a fase 3 não diz que ninguém entende \"linhagem\"")
	t.check(R.STORY_REPORTS.fase_3.contains("\"edição\", \"incubação\""), "e segue com as outras duas palavras")
	for text in R.STORY_REPORTS.values():
		t.check(not text.contains("Théo") and not text.contains("VIGIA"), "nenhuma linha revela antes da hora: %s" % text.left(30))
