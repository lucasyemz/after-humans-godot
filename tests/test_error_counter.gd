## O contador de erros do run_all (#66): os erros de script e os do motor que o jogo provoca fazem o teste falhar; os
## avisos e o push_error/push_warning dos scripts, não. Chamado direto, sem provocar o erro (o contador da suíte
## contaria o erro de verdade).
extends RefCounted

const ErrorCounter = preload("res://tests/error_counter.gd")


func run(t) -> void:
	var counter := ErrorCounter.new()
	var none: Array[ScriptBacktrace] = []
	counter._log_error("push_error", "core/variant/variant_utility.cpp", 1023, "Save recusado.", "", false, Logger.ERROR_TYPE_ERROR, none)
	counter._log_error("push_warning", "core/variant/variant_utility.cpp", 1033, "Cena desconhecida.", "", false, Logger.ERROR_TYPE_WARNING, none)
	counter._log_error("cleanup", "core/object/object.cpp", 2536, "Leaked.", "", false, Logger.ERROR_TYPE_WARNING, none)
	t.equal(counter.count, 0, "push_error, push_warning e avisos não contam")
	counter._log_error("grab_focus", "scene/gui/control.cpp", 3001, "Condition \"!is_inside_tree()\" is true.", "", false,
		Logger.ERROR_TYPE_ERROR, none)
	t.equal(counter.count, 1, "o foco fora da árvore conta")
	t.check(counter.first.contains("control.cpp:3001") and counter.first.contains("is_inside_tree"), "e o primeiro diz onde e o quê (%s)" % counter.first)
	counter._log_error("call", "modules/gdscript/gdscript_lambda_callable.cpp", 110, "Lambda capture at index 0 was freed.", "", false,
		Logger.ERROR_TYPE_ERROR, none)
	counter._log_error("_ready", "res://scripts/x.gd", 3, "", "Invalid access.", false, Logger.ERROR_TYPE_SCRIPT, none)
	t.equal(counter.count, 3, "a lambda com nó liberado e o erro de script também")
	t.check(counter.first.contains("control.cpp"), "o primeiro continua o primeiro")
