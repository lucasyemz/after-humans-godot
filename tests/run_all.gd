## Roda todos os testes (tests/test_*.gd) sem janela e sai com código 0 se todos passarem:
##   Godot --headless --path . --script res://tests/run_all.gd
##   Godot --headless --path . --script res://tests/run_all.gd -- --filter=campaign
## Cada teste é um script com func run(t), que recebe um tests/test_context.gd. Os autoloads (GameData, Campaign,
## GameFlow) já estão carregados quando os testes rodam.
extends SceneTree

const TestContext = preload("res://tests/test_context.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Um quadro para os autoloads terminarem o _ready.
	await process_frame
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
	var files := Array(DirAccess.get_files_at("res://tests")).filter(func(file): return file.begins_with("test_") and file.ends_with(".gd") and file != "test_context.gd")
	files.sort()

	var failed := 0
	var ran := 0
	var started := Time.get_ticks_msec()
	for file in files:
		var test_name: String = file.get_basename()
		if filter != "" and not test_name.contains(filter):
			continue
		ran += 1
		var t := TestContext.new()
		var test_started := Time.get_ticks_msec()
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			failed += 1
			print("FAIL %s (o script não compila)" % test_name)
			continue
		var test = script.new()
		await test.run(t)
		var elapsed := Time.get_ticks_msec() - test_started
		var ok := t.failures.is_empty() and t.checks > 0
		if not ok:
			failed += 1
		var summary := "" if t.notes.is_empty() else " — " + "; ".join(t.notes)
		print("%s %s (%d verificações, %d ms)%s" % ["PASS" if ok else "FAIL", test_name, t.checks, elapsed, summary])
		if t.checks == 0:
			print("    nenhuma verificação feita")
		for failure in t.failures.slice(0, 10):
			print("    " + failure)
		if t.failures.size() > 10:
			print("    ... e mais %d falhas" % (t.failures.size() - 10))
	print("%d de %d testes passaram em %d ms." % [ran - failed, ran, Time.get_ticks_msec() - started])
	quit(0 if failed == 0 and ran > 0 else 1)
