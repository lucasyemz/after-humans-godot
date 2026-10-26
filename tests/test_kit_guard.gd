## A trava do padrão da HUD (#60, decisão do Lucas: o kit da Awesomic em todas as telas, docs/design/hud-direction.md):
## fora do kit (scripts/ui/kit e o AHUiStyle, onde moram os tokens), as telas não desenham por conta própria. Nada de
## - StyleBoxFlat (a chapa vem das peças do kit);
## - cor solta: Color("…") ou Color(0.3, …) (as cores são os tokens do AHKit; Color(AHKit.AMBER, 0.5) vale);
## - tamanho de texto solto: um número no font_size_override ou nos rótulos antigos (U.label, make_label);
## - as caixas e os botões antigos (U.panel, U.flat, U.bar, H.panel_style, H.style_button), que são StyleBoxFlat.
## As telas que ainda não foram migradas ficam em tools/kit_guard_exceptions.txt com quantas ocorrências têm hoje. A
## lista só encolhe: uma tela nova fora dela, ou uma que ganhou ocorrências, reprova; a que perdeu pede para baixar o
## número (ou sair da lista), como o i18n faz com o i18n_ignore.
## Limite conhecido: a busca é linha a linha, então o tamanho indireto (var size := 22 numa linha e o override com size
## noutra, AHKit.size("row") + 4) passa; a revisão pega esses.
extends RefCounted

const ROOT := "res://scripts/ui"
const EXCEPTIONS := "res://tools/kit_guard_exceptions.txt"
## O que a trava procura (o padrão, o que diz na falha). As linhas são lidas sem o conteúdo dos textos entre aspas e sem
## o comentário do fim (um "Color(1, 0, 0)" dentro de tr() não conta); só os nomes de tema com font_size ficam.
const RULES := [
	["StyleBoxFlat", "StyleBoxFlat"],
	["\\bColor\\(\\s*(\"|'|-?[0-9.])|\\bColor8\\(|\\bColor\\.(?:html|from_\\w+)\\(", "cor solta"],
	["\\bColor\\.(?!WHITE\\b|BLACK\\b|TRANSPARENT\\b)[A-Z][A-Z_]+\\b", "cor com nome"],
	["font_size_override\\(\\s*&?[\"'][^\"']*[\"']\\s*,\\s*(?:(?:AHUiStyle|U)\\.px\\(\\s*)?\\d|font_sizes/font_size[\"']\\s*,\\s*\\d|font_size\\s*=\\s*\\d",
		"tamanho de texto solto"],
	["\\b(?:\\w*label\\w*|_text)\\((?:[^()]|\\([^()]*\\))*?,\\s*\\d{2}\\b", "rótulo com tamanho solto"],
	["\\b(?:U|AHUiStyle)\\.(?:panel|flat|bar)\\(|\\bH\\.(?:panel_style|style_button)\\(", "caixa ou botão antigo"],
]


func run(t) -> void:
	var found := _scan()
	var allowed := _exceptions()
	var over: Array = []
	var stale: Array = []
	for path in found:
		var count: int = found[path].size()
		if not allowed.has(path):
			over.append("%s: %d (%s)" % [path, count, found[path][0]])
		elif count > int(allowed[path]):
			over.append("%s: %d, a lista deixa %d (%s)" % [path, count, allowed[path], found[path][0]])
	for path in allowed:
		var count: int = found.get(path, []).size()
		if count < int(allowed[path]):
			stale.append("%s: %d (a lista diz %d)" % [path, count, allowed[path]])
	t.equal(over, [], "nenhuma tela desenha fora do kit além das exceções")
	t.equal(stale, [], "as exceções encolhem com as telas migradas (baixe o número em tools/kit_guard_exceptions.txt)")
	# As telas migradas pela #105 e pela #109 ficam fora da lista de vez.
	for path in ["res://scripts/ui/refuge_hud.gd", "res://scripts/ui/options_panel.gd", "res://scripts/ui/camp_hud.gd", "res://scripts/ui/station/station_frame.gd"]:
		t.check(not allowed.has(path) and not found.has(path), "%s no kit, sem exceção" % path.get_file())
	# A trava acha o que deve: uma linha de cada regra.
	for sample in ["box = StyleBoxFlat.new()", "color = Color(\"d9ad62\")", "color = Color(0.3, 0.3, 0.32)", "color = Color8(200, 100, 50)",
			"color = Color.html(\"#f00\")", "color = Color.from_hsv(0.1, 0.5, 0.5)", "color = Color.RED",
			"add_theme_font_size_override(\"font_size\", AHUiStyle.px(22))", "add_theme_font_size_override(&\"font_size\", 22)",
			"add_theme_font_size_override('font_size', 22)", "label.label_settings.font_size = 22", "set(\"theme_override_font_sizes/font_size\", 22)",
			"H.make_label(tr(\"Oi\"), 34, H.GOLD)", "AHKit.label_px(tr(\"x\"), 26, AHKit.TEXT)", "_kit_label(tr(option.name), 26, GOLD)",
			"_text(tr(\"Vida\"), 16, TEXT)", "H.style_button(button)"]:
		t.check(_matches(sample).size() == 1, "a trava acha \"%s\"" % sample)
	for sample in ["color = Color(AHKit.AMBER, 0.5)", "modulate = Color.WHITE", "label.text = tr(\"Color(1, 0, 0) e StyleBoxFlat\")",
			"x = 1  # Color(\"fff\") num comentário", "label.add_theme_font_size_override(\"font_size\", AHKit.size(\"text\"))"]:
		t.check(_matches(sample).is_empty(), "e deixa passar \"%s\"" % sample)


## As ocorrências por arquivo (só os que têm alguma).
func _scan() -> Dictionary:
	var found := {}
	for path in _files(ROOT):
		if path.begins_with(ROOT + "/kit/") or path.get_file() == "ui_style.gd":
			continue
		var hits: Array = []
		var number := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			number += 1
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue
			for what in _matches(line):
				hits.append("%d: %s" % [number, what])
		if not hits.is_empty():
			found[path] = hits
	return found


func _matches(line: String) -> Array:
	var hits: Array = []
	line = _code_only(line)
	for rule in RULES:
		var regex := RegEx.create_from_string(rule[0])
		for m in regex.search_all(line):
			hits.append(rule[1])
	return hits


## A linha sem o conteúdo dos textos entre aspas ("Color(1, 0, 0)" vira "") e sem o comentário do fim; os textos com
## font_size (o nome do tema) ficam, para a regra do tamanho.
func _code_only(line: String) -> String:
	var out := ""
	var quote := ""
	var inside := ""
	var i := 0
	while i < line.length():
		var ch := line[i]
		if quote != "":
			if ch == "\\":
				inside += line.substr(i, 2)
				i += 2
				continue
			if ch == quote:
				out += (inside if inside.contains("font_size") else "") + ch
				quote = ""
			else:
				inside += ch
		elif ch == "\"" or ch == "'":
			out += ch
			quote = ch
			inside = ""
		elif ch == "#":
			break
		else:
			out += ch
		i += 1
	return out


func _files(dir: String) -> Array:
	var out: Array = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir.path_join(sub)))
	return out


func _exceptions() -> Dictionary:
	var allowed := {}
	for line in FileAccess.get_file_as_string(EXCEPTIONS).split("\n"):
		line = line.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var parts := line.rsplit(":", true, 1)
		if parts.size() != 2 or not parts[1].strip_edges().is_valid_int():
			push_error("tools/kit_guard_exceptions.txt: a linha \"%s\" não está no formato \"caminho: número\"" % line)
			continue
		allowed["res://" + parts[0].strip_edges()] = int(parts[1])
	return allowed
