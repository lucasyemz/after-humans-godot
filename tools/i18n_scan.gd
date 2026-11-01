## Os textos de tela para a tradução (#35), lidos do código e dos dados: a ferramenta tools/i18n_update.gd (que atualiza
## data/i18n/en.po) e o teste tests/test_i18n.gd usam a mesma leitura.
##
## A chave de cada texto é o próprio texto em português (o msgid do PO): em português o jogo mostra a chave, igual a
## antes; em inglês, a tradução, ou a chave quando ela falta. Nas telas convertidas, todo literal que parece texto de
## tela tem de estar no PO ou na lista do que não é texto (tools/i18n_ignore.txt); e o texto com %s/%d passa por tr()
## antes da formatação. Nos dados, os campos de texto das tabelas viram chaves, sem mudar os ids.
extends RefCounted

const PO := "res://data/i18n/en.po"
const IGNORE := "res://tools/i18n_ignore.txt"
## As telas convertidas (a primeira leva: o título, as Opções, o HUD da exploração e da luta e a Estação; a segunda: o mapa
## de fases, a Mochila, as dicas, as regras da jornada, da Estação e dos cuidados, o registro da luta, a rua, os lugares e
## os avisos do save).
const CONVERTED := ["res://scripts/ui/title_screen.gd", "res://scripts/flow/fight_rewards.gd", "res://scripts/ui/cargo_picker.gd", "res://scripts/flow/hero_levels.gd", "res://scripts/ui/briefing_dialog.gd", "res://scripts/ui/character_sheet.gd", "res://scripts/ui/options_panel.gd", "res://scripts/core/settings_service.gd",
	"res://scripts/ui/exploration_hud.gd", "res://scripts/ui/passage_card.gd", "res://scripts/ui/camp_hud.gd",
	"res://scripts/ui/combat_hud.gd", "res://scripts/ui/kit/kit.gd", "res://scripts/ui/kit/kit_pill.gd", "res://scripts/ui/kit/kit_key.gd", "res://scripts/ui/kit/kit_bar.gd", "res://scripts/ui/refuge_hud.gd",
	"res://scripts/ui/station/station_report.gd", "res://scripts/ui/station/departure_screen.gd", "res://scripts/ui/station/character_room.gd", "res://scripts/ui/station/station_frame.gd",
	"res://scripts/ui/phase_map.gd", "res://scripts/flow/network_radar.gd", "res://scripts/ui/inventory_panel.gd", "res://scripts/ui/tips_service.gd",
	"res://scripts/ui/ui_style.gd", "res://scripts/flow/station_rules.gd", "res://scripts/flow/journey_rules.gd",
	"res://scripts/flow/exploration_care.gd", "res://scripts/combat/combat_engine.gd", "res://scripts/combat/combat_session.gd",
	"res://scripts/street/street.gd", "res://scripts/street/street_corridor.gd", "res://scripts/scenario/scenario_world.gd",
	"res://scripts/station/station_build.gd", "res://scripts/campaign/campaign_service.gd",
	"res://scripts/core/game_data_service.gd", "res://scripts/flow/game_flow.gd", "res://scripts/combat/combat_arena.gd",
	"res://scripts/ui/tutorial_hint.gd", "res://scripts/street/tutorial_guide.gd", "res://scripts/ui/station/station_tour.gd", "res://scripts/flow/station_grid.gd",
	"res://scripts/flow/side_mission_rules.gd", "res://scripts/ui/mission_board.gd",
	"res://scripts/flow/rescue_rules.gd",
	"res://scripts/flow/type_advantage.gd", "res://scripts/flow/hero_skills.gd"]
## Os campos de texto de cada tabela de data/ (os nomes e as descrições).
const DATA_FIELDS := {
	"abilities": ["DisplayName", "Description"], "classes": ["DisplayName", "Species", "Role", "Description"],
	"enemies": ["DisplayName", "Role", "Description"], "enemy-actions": ["DisplayName", "Description"], "events": ["Title", "Description"],
	"expedition-nodes": ["Title", "Description"], "perks": ["DisplayName", "Description"], "relics": ["DisplayName", "Description"],
	"research": ["DisplayName", "Description"], "scenarios": ["DisplayName"], "search-outcomes": ["Text"],
	"hero-upgrades": ["DisplayName", "Description"], "recruitment": ["Text"], "hero-jobs": ["Text"],
	"night-events": ["Text", "TextOne", "TextEmpty", "TextWatched", "TextProtected"],
	"skins": ["DisplayName", "ShortName", "Text"], "side-missions": ["Title", "Text"], "type-classes": ["DisplayName", "ShortName"],
}


## Os literais de uma linha de código (sem o comentário): [[texto, coluna], ...]. O texto vem sem as aspas, com os escapes
## do GDScript resolvidos (\n, \", \\).
static func literals(line: String) -> Array:
	var found: Array = []
	var i := 0
	while i < line.length():
		var c := line[i]
		if c == "#":
			break
		if c == "\"":
			var start := i
			var text := ""
			i += 1
			while i < line.length() and line[i] != "\"":
				if line[i] == "\\" and i + 1 < line.length():
					var next := line[i + 1]
					text += "\n" if next == "n" else ("\t" if next == "t" else next)
					i += 2
					continue
				text += line[i]
				i += 1
			found.append([text, start])
		i += 1
	return found


## Parece texto de tela: tem letra e não é caminho, id, ação, nome de campo (CamelCase) nem argumento de linha de comando.
static func looks_like_text(text: String) -> bool:
	var letters := RegEx.create_from_string("[A-Za-zÀ-ú]")
	if letters.search(text) == null or text.contains("://") or text.begins_with("--"):
		return false
	# Uma palavra solta minúscula ("vazio", "de") é texto; os ids do código ("bold", "menu") ficam em i18n_ignore.txt.
	if RegEx.create_from_string("^[a-zà-ú]{2,}$").search(text) != null:
		return true
	if RegEx.create_from_string("^[a-z0-9_.:\\-/]*$").search(text) != null:
		return false
	if RegEx.create_from_string("^[A-Z][a-z0-9]+([A-Z][A-Za-z0-9]*)+$").search(text) != null:
		return false
	if RegEx.create_from_string("^[a-z_]+[A-Z]").search(text) != null:
		return false
	return true


## Os textos de tela de um script: [{text, line, wrapped}], wrapped quando o literal está logo dentro de tr( ou
## translate( (o texto formatado precisa disso). Todo literal dentro de tr() conta, mesmo uma palavra minúscula.
static func screen_texts(path: String) -> Array:
	var out: Array = []
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for number in lines.size():
		var line: String = lines[number]
		if line.strip_edges().begins_with("#"):
			continue
		for found in literals(line):
			var text: String = found[0]
			var before := line.substr(0, found[1]).strip_edges(false, true)
			var wrapped := before.ends_with("tr(") or before.ends_with("translate(")
			# O que passa por tr() é texto, mesmo minúsculo ("menu", "água"); fora dele, só o que parece texto.
			if not wrapped and not looks_like_text(text):
				continue
			out.append({"text": text, "line": number + 1, "wrapped": wrapped})
	return out


## Os textos dos dados: [{text, where}] (where = "tabela.id.campo").
static func data_texts() -> Array:
	var out: Array = []
	for table in DATA_FIELDS:
		var rows = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % table))
		var entries: Array = []
		if typeof(rows) == TYPE_DICTIONARY:
			for id in rows:
				entries.append([str(id), rows[id]])
		elif typeof(rows) == TYPE_ARRAY:
			for index in rows.size():
				entries.append([str(index), rows[index]])
		for entry in entries:
			if typeof(entry[1]) != TYPE_DICTIONARY:
				continue
			for field in DATA_FIELDS[table]:
				var value = entry[1].get(field)
				if typeof(value) == TYPE_STRING and String(value).strip_edges() != "":
					out.append({"text": value, "where": "%s.%s.%s" % [table, entry[0], field]})
	# As fases (o mapa e o Próximo passo): o nome e a descrição, da tabela do código (carregada na hora: com -s, o script
	# compila antes dos autoloads de que as regras dependem).
	for phase in load("res://scripts/flow/journey_rules.gd").PHASES:
		for field in ["name", "description"]:
			out.append({"text": phase[field], "where": "phases.%s.%s" % [phase.id, field]})
	# As missões solo (#183): a dica de cada aptidão, dentro da linha das regras.
	for row in JSON.parse_string(FileAccess.get_file_as_string("res://data/side-missions.json")):
		for need in row.get("Aptitudes", {}):
			out.append({"text": row.Aptitudes[need].Hint, "where": "side-missions.%s.%s.Hint" % [row.Name, need]})
	# O briefing e o debriefing (#88): as falas de cada fase, da retirada e da queda.
	for row in JSON.parse_string(FileAccess.get_file_as_string("res://data/briefings.json")):
		for index in row.get("Briefing", []).size():
			out.append({"text": row.Briefing[index].Text, "where": "briefings.%s.%d" % [row.Name, index]})
		if row.get("Debriefing") is Array:
			for index in row.Debriefing.size():
				out.append({"text": row.Debriefing[index].Text, "where": "briefings.%s.debriefing.%d" % [row.Name, index]})
		elif row.has("Debriefing"):
			out.append({"text": row.Debriefing.Text, "where": "briefings.%s.debriefing" % row.Name})
	# Os cenários (#147): o nome de cada zona (o "Seguindo para:" da troca de zona) e de cada prop vasculhável.
	for file in DirAccess.get_files_at("res://data/scenarios"):
		if not file.ends_with(".json") or file == "meshes.json":
			continue
		var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/" + file))
		for zone in map.get("zones", []):
			out.append({"text": zone.name, "where": "scenarios.%s.zones" % file.get_basename()})
		for prop in map.get("props", []):
			out.append({"text": prop.name, "where": "scenarios.%s.props" % file.get_basename()})
	# O tutorial (#144): os cartões da abertura e as dicas de cada passo.
	for row in JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial.json")):
		for index in row.get("Cards", []).size():
			for field in ["Title", "Subtitle"]:
				if String(row.Cards[index].get(field, "")).strip_edges() != "":
					out.append({"text": row.Cards[index][field], "where": "tutorial.%s.%d.%s" % [row.Name, index, field]})
		for step in row.get("Steps", []):
			if step is Dictionary:
				for field in ["Title", "Text", "Do"]:
					if String(step.get(field, "")).strip_edges() != "":
						out.append({"text": step[field], "where": "tutorial.%s.%s.%s" % [row.Name, step.Id, field]})
	# A Estação em grade (#186): os textos dos achados de cada bloco e do item raro, e a fala da primeira volta.
	for row in JSON.parse_string(FileAccess.get_file_as_string("res://data/station-grid.json")):
		for field in ["Text", "Card"]:
			if String(row.get(field, "")).strip_edges() != "":
				out.append({"text": row[field], "where": "station-grid.%s.%s" % [row.Name, field]})
		for list in ["Rolls", "Tools", "Lines"]:
			for index in row.get(list, []).size():
				if String(row[list][index].get("Text", "")).strip_edges() != "":
					out.append({"text": row[list][index].Text, "where": "station-grid.%s.%s.%d" % [row.Name, list, index]})
	# As escolhas dos eventos: o texto do botão, o requisito e o resultado de cada saída (#64; o resultado vai traduzido
	# pelo modelo, com {Heroi} e {Instinto} trocados depois).
	for row in JSON.parse_string(FileAccess.get_file_as_string("res://data/events.json")):
		for choice in row.get("Choices", []):
			var where := "events.%s.%s" % [row.get("Name", ""), choice.get("Id", "")]
			for field in ["Text", "RequirementText"]:
				if String(choice.get(field, "")).strip_edges() != "":
					out.append({"text": choice[field], "where": "%s.%s" % [where, field]})
			for outcome in ["Success", "Failure"]:
				var result := String(choice.get(outcome, {}).get("Result", ""))
				if result.strip_edges() != "":
					out.append({"text": result, "where": "%s.%s" % [where, outcome]})
	return out


## O literal está na lista do que não é texto: no arquivo dele ou em "*" (os ids do código, em qualquer arquivo).
static func is_ignored(ignored_list: Dictionary, file: String, text: String) -> bool:
	return ignored_list.has("%s: %s" % [file, text]) or ignored_list.has("*: " + text)


## A lista do que parece texto mas não é (nomes de nó, teclas, unidades): "arquivo: texto" por linha; "*: palavra" vale
## em todos os arquivos.
static func ignored() -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(IGNORE):
		return out
	for line in FileAccess.get_file_as_string(IGNORE).split("\n"):
		if line.strip_edges() == "" or line.begins_with("#"):
			continue
		var cut := line.find(": ")
		if cut > 0:
			out[line.substr(0, cut) + ": " + line.substr(cut + 2).c_unescape()] = true
	return out


## O PO lido à mão: {msgid: {str, plural, strs, refs}} na ordem do arquivo (o tradutor e o teste veem o mesmo).
static func read_po(path: String = PO) -> Dictionary:
	var entries := {}
	if not FileAccess.file_exists(path):
		return entries
	var current := {}
	var field := ""
	var refs: Array = []
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw.strip_edges()
		# As obsoletas (#~) entram marcadas (a Godot as ignora): o texto que volta recupera a tradução.
		var obsolete := line.begins_with("#~ ")
		if obsolete:
			line = line.substr(3)
		if line.begins_with("#:") or line.begins_with("#."):
			refs.append(line.substr(2).strip_edges())
			continue
		if line.begins_with("msgid "):
			if current.has("id") and current.id != "":
				entries[current.id] = current
			current = {"id": _po_string(line.substr(6)), "str": "", "plural": "", "strs": [], "refs": refs, "obsolete": obsolete}
			refs = []
			field = "id"
		elif line.begins_with("msgid_plural "):
			current.plural = _po_string(line.substr(13))
			field = "plural"
		elif line.begins_with("msgstr["):
			current.strs.append(_po_string(line.substr(line.find("]") + 2)))
			field = "strs"
		elif line.begins_with("msgstr "):
			current.str = _po_string(line.substr(7))
			field = "str"
		elif line.begins_with("\"") and not current.is_empty():
			var more := _po_string(line)
			match field:
				"id":
					current.id += more
				"plural":
					current.plural += more
				"str":
					current.str += more
				"strs":
					current.strs[-1] += more
	if current.has("id") and current.id != "":
		entries[current.id] = current
	return entries


static func _po_string(quoted: String) -> String:
	var inner := quoted.strip_edges()
	if inner.length() >= 2 and inner.begins_with("\"") and inner.ends_with("\""):
		inner = inner.substr(1, inner.length() - 2)
	return inner.c_unescape()


static func po_quote(text: String) -> String:
	return "\"" + text.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\t", "\\t") + "\""


## Os marcadores de formato (%s, %d, %02d, %%) de um texto, na ordem.
static func placeholders(text: String) -> Array:
	var out: Array = []
	for found in RegEx.create_from_string("%[-+#0-9.]*[sdfx%]").search_all(text):
		out.append(found.get_string())
	return out
