## As placas das máquinas numa luta cheia (quatro inimigos, #60 sobre a #63): no texto Normal e no Maior, a intenção e a
## barra não cobrem o corpo (a barra e os estados no máximo um quinto dele; a intenção, acima da cabeça, nada) e as placas de um mesmo lado não se cobrem.
extends RefCounted

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var real_size: int = Settings.text_size
	var tips: bool = Tips.enabled
	Campaign.save_dir = "user://test-plates-%d" % Time.get_ticks_usec()
	Tips.enabled = false
	await _fight()
	Settings.set_text_size(real_size)
	Tips.enabled = tips
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state


## A luta do passo 7 da Rua das Vitrines na semente 1: dois Rastreadores, o Relé e o Pipoco.
func _fight() -> void:
	Campaign.state = Campaign.create_initial(6)
	AHJourneyRules.start_expedition(Campaign.state, "fase_1", 1)
	var route: Dictionary = Campaign.state.session.expedition.corridor
	var step := 7
	for i in step:
		route.steps[i].resolved = true
	route.index = step - 1
	GameFlow.change_to("street", {}, false)
	var street = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			street = _tree.current_scene
			break
	if not t.check(street != null, "a rua abre"):
		return
	for k in 4:
		street.corridor.debug_next_fight()
		for i in 20:
			await _tree.process_frame
		if street.corridor.guards.has(route.index) and route.index == step:
			break
	street.corridor._start_fight(route.index, true)
	var hud: AHCombatHud = street._arena.hud
	for i in 1500:
		if hud != null and hud.waiting:
			break
		await _tree.process_frame
	if not t.check(hud != null and hud.waiting, "a vez do jogador chega"):
		return
	var enemies: int = hud.session.state.enemy_team.size()
	t.check(enemies >= 4, "a luta tem quatro máquinas (%d)" % enemies)
	for size in [0, 2]:
		Settings.set_text_size(size)
		for i in 6:
			await _tree.process_frame
		_check(hud, "Maior" if size == 2 else "Normal")


func _check(hud: AHCombatHud, profile: String) -> void:
	var camera := hud.get_viewport().get_camera_3d()
	var covering: Array = []
	var rects: Array = []
	for unit_id in hud._unit_bars:
		var plate: Control = hud._unit_bars[unit_id]
		var card: AHSpriteCard = hud.arena.cards.get(unit_id)
		if not plate.visible or card == null:
			continue
		var unit := hud.session.state.find_unit(unit_id)
		var rect := Rect2(plate.position, plate.size)
		rects.append([unit.is_player, rect, unit_id])
		# A intenção, à parte, acima da cabeça.
		var tag = (plate.get_meta("intent") if plate.has_meta("intent") else null)
		if tag != null and tag.visible:
			rects.append([unit.is_player, Rect2(tag.position, tag.size), unit_id + " (intenção)"])
			var crown: Rect2 = hud._body_rect(camera, card)
			var hit := Rect2(tag.position, tag.size).intersection(crown)
			if hit.size.y > crown.size.y * 0.05 + 1.0:
				covering.append("%s intenção (%.0f%%)" % [unit_id, hit.size.y / crown.size.y * 100.0])
		var body: Rect2 = hud._body_rect(camera, card)
		var over := rect.intersection(body)
		if body.size.y > 0 and over.size.y > body.size.y * 0.2 + 1.0:
			covering.append("%s (%.0f%%)" % [unit_id, over.size.y / body.size.y * 100.0])
	t.equal(covering, [], "no %s, nenhuma placa cobre mais que um quinto do corpo" % profile)
	var overlaps: Array = []
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i][0] == rects[j][0] and rects[i][1].grow(-1).intersects(rects[j][1].grow(-1)):
				overlaps.append("%s × %s" % [rects[i][2], rects[j][2]])
	t.equal(overlaps, [], "no %s, as placas de um lado não se cobrem" % profile)
