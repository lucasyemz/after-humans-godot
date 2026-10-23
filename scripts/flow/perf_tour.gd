## Roteiro de desempenho (#37): com --perf, o jogo passa sozinho pelo título, pela Estação, pela rua, por uma luta e
## pelos seis cenários, em cada qualidade pedida, e mede em cada parada o tempo de quadro (média e p95 de 120 quadros),
## as chamadas de desenho, as primitivas, os objetos, a memória de vídeo e a memória do jogo. Serve no desktop (Forward+
## e Compatibility) e na web (o mesmo Compatibility), onde não há -s:
##   "$GODOT" --path . --resolution 1920x1080 -- --perf=<pasta> [--perf-levels=0,2] [--perf-only=station,street]
## Escreve <pasta>/perf.csv e perf.md (na web, só imprime as linhas "PERF ..." no console) e sai. A campanha fica em
## <pasta>/save (na web, em user://perf-tour), apagada no fim; as opções não são gravadas e o vsync fica desligado.
class_name AHPerfTour
extends Node

## Os cenários pela fase e o trecho em que aparecem (como tools/capture_scenarios.gd).
const SCENARIOS := {"RiverDock": ["fase_2", 0], "RootBridge": ["fase_2", 4], "SealedShelter": ["fase_3", 0],
	"TriageGate": ["fase_4", 0], "FloodedDepot": ["fase_5", 0], "SewerDucts": ["fase_5", 4]}
const FRAMES := 120
const SETTLE_SECONDS := 2.0

var out := ""
var levels: Array = [0, 2]
var only: Array = []
var rows: Array = []


static func requested() -> bool:
	return Array(OS.get_cmdline_user_args()).any(func(arg): return String(arg) == "--perf" or String(arg).begins_with("--perf="))


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--perf="):
			out = String(arg).trim_prefix("--perf=")
		elif String(arg).begins_with("--perf-levels="):
			levels = Array(String(arg).trim_prefix("--perf-levels=").split(",")).map(func(v): return clampi(int(v), 0, 3))
		elif String(arg).begins_with("--perf-only="):
			only = Array(String(arg).trim_prefix("--perf-only=").split(","))
	_run.call_deferred()


func _want(stop: String) -> bool:
	return only.is_empty() or only.has(stop)


func _run() -> void:
	# Sem vsync, para medir o custo do quadro e não a espera do monitor.
	if not OS.has_feature("web"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Tips.enabled = false
	# A campanha do roteiro fica na pasta da saída (como as capturas); sem pasta (a web), numa própria, apagada no fim.
	Campaign.save_dir = out.path_join("save") if out != "" and not OS.has_feature("web") else "user://perf-tour"
	Campaign.slot = 1
	print("PERF renderer=%s web=%s" % [RenderingServer.get_current_rendering_method(), OS.has_feature("web")])
	for level in levels:
		Settings.level = int(level)
		Settings.apply()
		if _want("title"):
			Campaign.state = Campaign.create_initial(5)
			await _visit("title", "title", level)
		if _want("station"):
			Campaign.new_game(5)
			await _visit("station", "station", level)
		if _want("street") or _want("combat"):
			Campaign.state = Campaign.create_initial(6)
			AHJourneyRules.start_expedition(Campaign.state, "fase_1", 4242)
			await _visit("street", "street", level, _want("street"))
			if _want("combat"):
				await _fight(level)
		for map in SCENARIOS:
			if _want(map) or _want("scenarios"):
				await _scenario(map, level)
	_finish()


## Abre a cena e mede depois de ela assentar.
func _visit(scene_id: String, name: String, level: int, measure: bool = true) -> void:
	GameFlow.change_to(scene_id, {}, false)
	await get_tree().create_timer(SETTLE_SECONDS).timeout
	while GameFlow.busy:
		await get_tree().process_frame
	if measure:
		await _measure(name, level)


func _fight(level: int) -> void:
	var street = get_tree().current_scene
	if street == null or not street.has_method("begin_fight"):
		return
	street.corridor.debug_next_fight()
	await get_tree().create_timer(0.5).timeout
	var route: Dictionary = Campaign.state.session.expedition.corridor
	if not street.corridor.guards.has(route.index):
		print("PERF combat sem patrulha")
		return
	street.corridor._start_fight(route.index, true)
	for i in 900:
		if street._arena.hud != null and street._arena.hud.waiting:
			break
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	await _measure("combat", level)


func _scenario(map: String, level: int) -> void:
	var spec: Array = SCENARIOS[map]
	var c: Dictionary = Campaign.create_initial(7)
	c.completed_phases = ["fase_1", "fase_2", "fase_3", "fase_4"]
	AHStationRules.confirm_departure(c, c.preferred_formation.duplicate(), 0, 20261021, spec[0], "")
	var route: Dictionary = c.session.expedition.corridor
	for i in int(spec[1]):
		route.steps[i].resolved = true
	route.index = int(spec[1])
	Campaign.state = c
	Campaign.save()
	await _visit("street", map, level)


## 120 quadros: o tempo de cada um (média e p95) e, no último, o que o servidor de desenho conta.
func _measure(name: String, level: int) -> void:
	var times: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in FRAMES:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	var avg: float = times.reduce(func(a, b): return a + b, 0.0) / times.size()
	times.sort()
	var row := {
		"scene": name, "level": Settings.LEVEL_NAMES[level], "renderer": RenderingServer.get_current_rendering_method(),
		"avg_ms": snappedf(avg, 0.01), "p95_ms": snappedf(times[int(times.size() * 0.95)], 0.01),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"video_mb": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"memory_mb": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1),
		"shadow_lights": _shadow_lights(),
	}
	rows.append(row)
	print("PERF %s level=%s avg_ms=%.2f p95_ms=%.2f draws=%d prims=%d objects=%d video_mb=%.1f mem_mb=%.1f shadow_lights=%d" % [
		row.scene, row.level, row.avg_ms, row.p95_ms, row.draw_calls, row.primitives, row.objects, row.video_mb, row.memory_mb, row.shadow_lights])


## As luzes acesas com sombra na cena (o custo que mais cresce no Forward+).
func _shadow_lights() -> int:
	var count := 0
	var scene := get_tree().current_scene
	if scene == null:
		return 0
	for light in scene.find_children("*", "Light3D", true, false):
		if light.visible and light.shadow_enabled and light.light_energy > 0.0:
			count += 1
	return count


func _finish() -> void:
	if out != "" and not OS.has_feature("web"):
		DirAccess.make_dir_recursive_absolute(out)
		var keys := ["scene", "level", "renderer", "avg_ms", "p95_ms", "draw_calls", "primitives", "objects", "video_mb", "memory_mb", "shadow_lights"]
		var csv := PackedStringArray([",".join(keys)])
		var md := PackedStringArray(["| " + " | ".join(keys) + " |", "|" + "---|".repeat(keys.size())])
		for row in rows:
			var values := PackedStringArray(keys.map(func(k): return str(row[k])))
			csv.append(",".join(values))
			md.append("| " + " | ".join(values) + " |")
		FileAccess.open(out.path_join("perf.csv"), FileAccess.WRITE).store_string("\n".join(csv) + "\n")
		FileAccess.open(out.path_join("perf.md"), FileAccess.WRITE).store_string("\n".join(md) + "\n")
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	print("PERF fim %d paradas" % rows.size())
	get_tree().quit()
