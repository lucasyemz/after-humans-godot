## As caras (#193): todo personagem com arte tem um retrato ou uma caixa da cara nos dados (data/presentation), e o ícone
## sai dela; o morador da Estação mostra o rosto, não o meio do corpo; e a faixa da ordem da luta fecha a ponta da
## direita com qualquer fila, no Normal e no Maior.
extends RefCounted

const U := preload("res://scripts/ui/ui_style.gd")
const J := preload("res://scripts/flow/journey_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_data()
	_civilians()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	var size_before: int = Settings.text_size
	Tips.enabled = false
	Campaign.save_dir = "user://test-faces-%d" % Time.get_ticks_usec()
	await _order()
	Settings.set_text_size(size_before)
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Tips.enabled = tips
	Campaign.save_dir = real_dir
	Campaign.state = real_state


## Os heróis e os recrutas têm retrato; cada inimigo tem a caixa da cara dentro do canvas, e o recorte não sai vazio.
func _data() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/combat_art.json"))
	var boxes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(U.FACE_BOXES)).get("enemies", {})
	var missing: Array = []
	for group in ["heroes", "recruits"]:
		for id in manifest[group]:
			var idle: Dictionary = manifest[group][id].get("idle", {})
			if not ResourceLoader.exists(String(idle.get("portrait", ""))):
				missing.append(id)
	t.equal(missing, [], "todo herói e recruta tem retrato (art/ui/portraits)")
	var outside: Array = []
	var empty: Array = []
	for id in manifest.enemies:
		var idle: Dictionary = manifest.enemies[id].get("idle", {})
		var box: Array = boxes.get(id, [])
		if box.size() != 3:
			missing.append(id)
			continue
		var canvas := Vector2(idle.canvas[0], idle.canvas[1])
		if idle.has("frames"):
			canvas = Vector2(idle.frames[0][2], idle.frames[0][3])
		if box[0] < 0 or box[1] < 0 or box[0] + box[2] > canvas.x or box[1] + box[2] > canvas.y:
			outside.append(id)
		t.equal(U.face_box(idle), box, "%s: o ícone usa a caixa dos dados" % id)
		var face: Texture2D = U.face_texture(idle)
		if face == null or U.opaque_share(face.get_image()) < 0.25:
			empty.append(id)
	t.equal(missing, [], "todo inimigo tem a caixa da cara (face_boxes.json)")
	t.equal(outside, [], "e a caixa fica dentro do canvas")
	t.equal(empty, [], "e o recorte é a máquina, não o fundo vazio (um quarto ou mais opaco)")
	t.equal(boxes.keys().filter(func(id): return not manifest.enemies.has(id)), [], "nenhuma caixa sobra sem inimigo")


## O morador: o rosto da portrait_uv, quadrado, perto do topo da arte (antes, o retrato do kit cortava o corpo inteiro
## no meio).
func _civilians() -> void:
	var civilians: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/civilians.json"))
	for id in civilians:
		var art: Dictionary = civilians[id]
		var box: Array = U.face_box(art)
		t.check(box.size() == 3 and box[1] + box[2] < float(art.canvas[1]) * 0.6, "%s: a caixa da cara fica no alto da arte" % id)
		var face: Texture2D = AHRefugeHud._civilian_face(id)
		t.check(face != null and face.get_width() == face.get_height(), "%s: o ícone na Estação é o rosto, quadrado" % id)


## A faixa da ordem: a ponta da direita (a margem da peça) fica livre depois do último retrato, e a faixa cabe na tela,
## da fila de uma luta à mais cheia.
func _order() -> void:
	Campaign.state = Campaign.create_initial(6)
	J.start_expedition(Campaign.state, "fase_1", 1)
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
	var queue: Array = hud.session.state.initiative_queue
	var real: Array = queue.duplicate()
	var current: String = hud.session.current_actor().id
	for size in [0, 2]:
		Settings.set_text_size(size)
		var profile := "Maior" if size == 2 else "Normal"
		for count in [real.size(), 14, 30]:
			queue.clear()
			queue.append_array(real)
			while queue.size() < count:
				var source = real[queue.size() % real.size()]
				var item = source.get_script().new()
				item.unit_id = source.unit_id
				item.is_player = source.is_player
				queue.append(item)
			hud._refresh_order(current)
			for i in 4:
				await _tree.process_frame
			_check_strip(hud, "%s, %d na fila" % [profile, count])
	queue.clear()
	queue.append_array(real)


func _check_strip(hud: AHCombatHud, label: String) -> void:
	var panel: PanelContainer = hud._order_panel
	var rect := panel.get_global_rect()
	var style: StyleBox = panel.get_theme_stylebox("panel")
	var cap: float = style.texture_margin_right if style is StyleBoxTexture else 0.0
	var faces: Array = hud._order.get_children().filter(func(child): return child.has_meta("unit_id"))
	if faces.is_empty():
		t.check(false, "%s: a fila tem retratos" % label)
		return
	var last: Rect2 = faces[-1].get_global_rect()
	t.check(rect.position.x >= 0.0 and rect.end.x <= 1920.0, "%s: a faixa cabe na tela (%.0f a %.0f)" % [label, rect.position.x, rect.end.x])
	t.check(last.end.x <= rect.end.x - cap + 0.5, "%s: o último retrato termina antes da ponta (%.0f, a ponta em %.0f)" % [label, last.end.x, rect.end.x - cap])
	t.check(faces.all(func(cell): return cell.size.x >= hud.ORDER_MIN_PORTRAIT - 0.5 and absf(cell.size.x - cell.size.y) < 1.0),
		"%s: os retratos ficam quadrados e legíveis (%.0f px)" % [label, faces[-1].size.x])
