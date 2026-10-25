## Briefing e debriefing (#88, a P6 da proposta do laço, docs/design/loop-proposal-maa.md): duas ou três falas com o
## retrato de quem pede antes de cada saída, e uma na volta (o que se conseguiu e o que muda). As falas ficam em
## data/briefings.json; cada uma diz quem pode falar, na ordem, e fala o primeiro presente (o herói vivo no elenco, o
## morador que mora na Estação). Sem ninguém, a fala sai. Uma linha por fase (Name = o id da fase, com Briefing e o
## Debriefing da vitória), mais "retreat" e "defeat" (o Debriefing da retirada e da queda). As missões curtas (#92) entram
## na mesma tabela.
class_name AHBriefing
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")
const DATA := "res://data/briefings.json"
const CIVILIAN_ART := "res://data/presentation/civilians.json"

## Desligado, nenhuma fala abre (os testes de outras telas, como o Tips.enabled).
static var enabled := true
## Os resultados da volta com fala.
const RESULTS := ["victory", "retreat", "fled", "defeat"]
static var _data := {}
static var _civilian_art := {}


## As linhas da tabela pelo Name.
static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA):
		for row in JSON.parse_string(FileAccess.get_file_as_string(DATA)):
			_data[String(row.Name)] = row
	return _data


## As falas antes da saída para a fase: [{speaker, text}] (o speaker de speaker()). team: quem vai (os heróis só falam
## se vão; a fala é deles, em primeira pessoa).
static func departure(campaign: Dictionary, phase_id: String, team: Array) -> Array:
	var out: Array = []
	if not enabled:
		return out
	for entry in data().get(phase_id, {}).get("Briefing", []):
		var line := _line(campaign, entry, team, out.back().speaker.id if not out.is_empty() else "")
		if not line.is_empty():
			out.append(line)
	return out


## A fala da volta, pelo resultado do relatório (station.last_return): a da fase na vitória, a da retirada, a da fuga
## ou a da queda ("defeat_none" quando ninguém voltou). Os heróis só falam se voltaram vivos. [] sem fala (ou sem ninguém
## para falar).
static func debriefing(campaign: Dictionary, report: Dictionary) -> Array:
	if not enabled:
		return []
	var result := String(report.get("result", ""))
	if not RESULTS.has(result):
		return []
	var back: Array = report.get("team", []).filter(func(id): return S.hero(campaign, id) != null and S.hero(campaign, id).get("alive", true))
	var row_name := String(report.get("phase_id", "")) if result == "victory" else result
	if result == "defeat" and back.is_empty():
		row_name = "defeat_none"
	var line := _line(campaign, data().get(row_name, {}).get("Debriefing", {}), back)
	return [] if line.is_empty() else [line]


## Quem fala: {id, name, role, art (a entrada do manifesto para o retrato)}; {} se não está (herói morto ou fora do
## elenco, morador que não mora na Estação).
static func speaker(campaign: Dictionary, speaker_id: String) -> Dictionary:
	if speaker_id.begins_with("civil_"):
		if not S.is_resident(campaign, speaker_id):
			return {}
		var civilian := S.civilian(speaker_id)
		if _civilian_art.is_empty() and FileAccess.file_exists(CIVILIAN_ART):
			_civilian_art = JSON.parse_string(FileAccess.get_file_as_string(CIVILIAN_ART))
		return {"id": speaker_id, "name": civilian.get("name", ""), "role": civilian.get("role", ""), "art": _civilian_art.get(speaker_id, {})}
	var hero = S.hero(campaign, speaker_id)
	if hero == null or not hero.get("alive", true):
		return {}
	return {"id": speaker_id, "name": String(hero.display_name), "role": "",
		"art": AHCombatArena.hero_art_of(speaker_id, String(hero.get("art_variant", ""))).get("idle", {})}


## A fala com o primeiro da lista que pode dizê-la: o morador que mora na Estação, o herói de team. Quem acabou de
## falar (previous) só repete se não houver outro.
static func _line(campaign: Dictionary, entry: Dictionary, team: Array, previous: String = "") -> Dictionary:
	if String(entry.get("Text", "")) == "":
		return {}
	var found: Array = []
	for speaker_id in entry.get("Speakers", []):
		if not speaker_id.begins_with("civil_") and not team.has(speaker_id):
			continue
		var who := speaker(campaign, speaker_id)
		if not who.is_empty():
			found.append(who)
	if found.is_empty():
		return {}
	var others := found.filter(func(w): return w.id != previous)
	return {"speaker": (others if not others.is_empty() else found)[0], "text": entry.Text}
