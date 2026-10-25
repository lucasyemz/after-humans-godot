## Os textos do jogo não usam o que a lore tirou da história nem citam o que ela não conhece (#64; docs/narrative/lore.md
## §29 e a regra de consistência de narrative-design.md §14).
## - Os termos descontinuados: nos JSON de data/ e nas strings dos scripts.
## - Os nomes próprios dos textos dos dados e das fases (palavra com maiúscula fora do começo da frase): ou estão em
##   docs/narrative/known_names.txt, ou são o nome de algo definido nos dados. Um lugar, facção ou personagem novo entra
##   na lista junto com a seção da lore que o define; na dúvida, a pergunta vai para o Lucas numa issue.
extends RefCounted

## [o termo, se compara sem maiúsculas, por que não]. "VIGIA" com maiúsculas: "vigia" (quem vigia a noite) é outra coisa.
const BANNED := [
	["Programa Continuidade", false, "descontinuado como explicação do desaparecimento (lore §29)"],
	["guerra", true, "a queda veio da Peste; conflitos só aceleraram o colapso (lore §4, §9, §29)"],
	["aprendizagem", true, "a transformação por aprendizagem e interfaces foi descontinuada (lore §29)"],
	["VIGIA", false, "revelado só no fim da escada (narrative-design §7, lore §11)"],
	["Théo", false, "não aparece antes da hora (bento-nick-arc §11)"],
	["(provisório)", true, "rótulo de desenvolvimento na tela"],
]
const KNOWN := "res://docs/narrative/known_names.txt"
## As tabelas com texto de tela (as mesmas do i18n) e os campos que são texto.
const TABLES := ["abilities", "classes", "enemies", "enemy-actions", "events", "expedition-nodes", "perks", "relics", "research",
	"scenarios", "search-outcomes", "briefings"]
const TEXT_FIELDS := ["DisplayName", "Description", "Title", "Text", "Label", "Result", "Species", "Role"]
## Os campos que definem um nome (o que eles dizem passa a ser conhecido).
const NAME_FIELDS := ["DisplayName", "Title", "Species", "Role"]


func run(t) -> void:
	_banned(t)
	_names(t)


func _banned(t) -> void:
	var files: Array = []
	for name in DirAccess.get_files_at("res://data"):
		if name.ends_with(".json"):
			files.append("res://data/" + name)
	_scripts("res://scripts", files)
	for term in BANNED:
		var hits: Array = []
		for path in files:
			var lines := FileAccess.get_file_as_string(path).split("\n")
			for index in lines.size():
				var line := lines[index]
				# Nos scripts, só as strings (os comentários podem citar o termo para explicar a regra).
				if path.ends_with(".gd") and line.strip_edges().begins_with("#"):
					continue
				if (line.to_lower().contains(term[0].to_lower()) if term[1] else line.contains(term[0])):
					hits.append("%s:%d" % [path.trim_prefix("res://"), index + 1])
		t.check(hits.is_empty(), "nenhum \"%s\" nos textos: %s %s" % [term[0], term[2], hits.slice(0, 6)])


func _names(t) -> void:
	var known := {}
	for line in FileAccess.get_file_as_string(KNOWN).split("\n"):
		if not line.begins_with("#"):
			_add_words(known, line)
	var texts: Array = []
	for table in TABLES:
		_collect(JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % table)), table, texts, known)
	for phase in AHJourneyRules.PHASES:
		_add_words(known, phase.name)
		texts.append(["fases.%s" % phase.id, phase.description])
	var unknown: Array = []
	var word := RegEx.create_from_string("[\\wÀ-ÿ]+")
	for entry in texts:
		var text: String = entry[1]
		for match in word.search_all(text):
			var w := match.get_string()
			# Palavra minúscula, sigla ou letreiro em maiúsculas, ou o nome de quem age ({Heroi}): não é nome a conferir.
			if w[0] != w[0].to_upper() or w[0] == w[0].to_lower() or w == w.to_upper() or known.has(w):
				continue
			var before := text.substr(0, match.get_start()).strip_edges(false, true)
			if before == "" or ".!?:\"(“—{\n".contains(before[-1]):
				continue
			unknown.append("%s: %s" % [entry[0], w])
	t.check(unknown.is_empty(), "os nomes próprios dos textos estão na lore ou nos dados (%s) %s" % [KNOWN.trim_prefix("res://"), unknown.slice(0, 8)])


## Os textos de uma tabela ([onde, texto]); os nomes definidos nela entram no conhecido.
func _collect(value, where: String, texts: Array, known: Dictionary) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			for key in value:
				var item = value[key]
				if typeof(item) == TYPE_STRING and TEXT_FIELDS.has(key):
					texts.append(["%s.%s" % [where, key], item])
					if NAME_FIELDS.has(key):
						_add_words(known, item)
				else:
					_collect(item, where, texts, known)
		TYPE_ARRAY:
			for index in value.size():
				_collect(value[index], "%s.%d" % [where, index], texts, known)


func _add_words(known: Dictionary, text: String) -> void:
	for match in RegEx.create_from_string("[\\wÀ-ÿ]+").search_all(text):
		known[match.get_string()] = true


func _scripts(dir: String, out: Array) -> void:
	for name in DirAccess.get_files_at(dir):
		if name.ends_with(".gd"):
			out.append(dir.path_join(name))
	for sub in DirAccess.get_directories_at(dir):
		_scripts(dir.path_join(sub), out)
