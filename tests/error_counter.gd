## Conta os erros durante cada teste: os de script (acesso inválido, chamada inexistente...), que interrompem a função
## do teste no meio e sem isto o teste passava com menos verificações, e os do motor que o jogo provoca (o foco num
## controle fora da árvore, a lambda chamada com um nó já liberado, a espera que volta numa instância liberada, #66).
## Avisos e o push_error/push_warning dos próprios scripts (o aviso de uma entrada recusada) não contam.
extends Logger

var count := 0
var first := ""


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
		error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING or function == "push_error" or function == "push_warning":
		return
	count += 1
	if first == "":
		first = "%s:%d %s" % [file, line, rationale if rationale != "" else code]
