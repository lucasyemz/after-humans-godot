## Os textos do jogo não usam o que a lore tirou da história (#64; docs/narrative/lore.md §29 e a regra de consistência
## de narrative-design.md §14). Varre os JSON de data/ e as strings dos scripts. Um termo novo aqui entra junto com a
## seção da lore que o descontinua; na dúvida, a pergunta vai para o Lucas numa issue.
extends RefCounted

## [o termo (com maiúsculas, para "vigia", quem vigia a noite, não ser o VIGIA), por que não].
const BANNED := [
	["Programa Continuidade", "descontinuado como explicação do desaparecimento (lore §29)"],
	["guerra", "a queda veio da Peste; conflitos só aceleraram o colapso (lore §4, §9, §29)"],
	["aprendizagem", "a transformação por aprendizagem e interfaces foi descontinuada (lore §29)"],
	["VIGIA", "revelado só no fim da escada (narrative-design §7, lore §11)"],
	["Théo", "não aparece antes da hora (bento-nick-arc §11)"],
	["(provisório)", "rótulo de desenvolvimento na tela"],
]


func run(t) -> void:
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
				if line.contains(term[0]):
					hits.append("%s:%d" % [path.trim_prefix("res://"), index + 1])
		t.check(hits.is_empty(), "nenhum \"%s\" nos textos: %s %s" % [term[0], term[1], hits.slice(0, 6)])


func _scripts(dir: String, out: Array) -> void:
	for name in DirAccess.get_files_at(dir):
		if name.ends_with(".gd"):
			out.append(dir.path_join(name))
	for sub in DirAccess.get_directories_at(dir):
		_scripts(dir.path_join(sub), out)
