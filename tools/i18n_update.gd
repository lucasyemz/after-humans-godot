## Atualiza data/i18n/en.po com os textos de tela das telas convertidas e os dos dados (#35), mantendo as traduções que já
## existem. Texto novo entra com a tradução vazia (em inglês aparece o português até alguém traduzir); texto que saiu do
## jogo fica no fim, marcado como obsoleto (#~), para não perder a tradução. Rode depois de mexer nas telas ou nos dados:
##   "$GODOT" --headless --path . -s res://tools/i18n_update.gd
## e traduza as linhas com msgstr "". O teste tests/test_i18n.gd acusa texto de tela que não está no PO.
extends SceneTree

const Scan := preload("res://tools/i18n_scan.gd")


func _initialize() -> void:
	var old := Scan.read_po()
	var ignored := Scan.ignored()
	var order: Array = []
	var refs := {}
	for path in Scan.CONVERTED:
		var file: String = path.get_file()
		for found in Scan.screen_texts(path):
			if ignored.has("%s: %s" % [file, found.text]):
				continue
			if not refs.has(found.text):
				order.append(found.text)
				refs[found.text] = []
			refs[found.text].append("#: %s:%d" % [path.trim_prefix("res://"), found.line])
	for found in Scan.data_texts():
		if not refs.has(found.text):
			order.append(found.text)
			refs[found.text] = []
		refs[found.text].append("#. %s" % found.where)
	var out := PackedStringArray([
		"# After Humans: os textos em inglês (#35). A chave (msgid) é o texto em português; msgstr vazio mostra o português.",
		"# Gerado por tools/i18n_update.gd: as traduções se mantêm; rode de novo depois de mexer nas telas ou nos dados.",
		"msgid \"\"", "msgstr \"\"", "\"Content-Type: text/plain; charset=UTF-8\\n\"", "\"Language: en\\n\"",
		"\"Plural-Forms: nplurals=2; plural=(n != 1);\\n\"", ""])
	var translated := 0
	for text in order:
		out.append_array(refs[text].slice(0, 4))
		out.append("msgid " + Scan.po_quote(text))
		var entry: Dictionary = old.get(text, {})
		if entry.get("plural", "") != "":
			out.append("msgid_plural " + Scan.po_quote(entry.plural))
			for index in entry.strs.size():
				out.append("msgstr[%d] %s" % [index, Scan.po_quote(entry.strs[index])])
			translated += 1 if entry.strs.all(func(s): return s != "") else 0
		else:
			out.append("msgstr " + Scan.po_quote(entry.get("str", "")))
			translated += 1 if entry.get("str", "") != "" else 0
		out.append("")
	var gone := 0
	for text in old:
		if refs.has(text) or (old[text].str == "" and old[text].strs.is_empty()):
			continue
		out.append("#~ msgid " + Scan.po_quote(text))
		out.append("#~ msgstr " + Scan.po_quote(old[text].str))
		out.append("")
		gone += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Scan.PO.get_base_dir()))
	var file := FileAccess.open(Scan.PO, FileAccess.WRITE)
	file.store_string("\n".join(out))
	file.close()
	print("en.po: %d textos, %d traduzidos, %d obsoletos" % [order.size(), translated, gone])
	quit()
