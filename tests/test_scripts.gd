## Todo script do jogo compila. Sem isto, um erro num script que os testes só usam de forma indireta (a arena, a rua)
## passava despercebido: o teste que dependia dele ainda rodava e o runner dizia que tudo passou.
extends RefCounted


func run(t) -> void:
	var files: Array[String] = []
	_collect("res://scripts", files)
	for path in files:
		var script: GDScript = load(path)
		t.check(script != null and script.can_instantiate(), "%s compila" % path)
	t.check(files.size() > 10, "achou os scripts do jogo (%d)" % files.size())
	t.note("%d scripts" % files.size())


func _collect(dir: String, files: Array[String]) -> void:
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			files.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(sub), files)
