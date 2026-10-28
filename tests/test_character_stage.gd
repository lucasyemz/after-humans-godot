## A Sala dos Personagens com o herói no cômodo (#181): o escolhido entra na sala, de pé no chão dela e na escala da
## Estação, entre os dois painéis, sem figura da interface por cima; trocar de herói troca quem está na sala; sair
## devolve cada um (o caído em recuperação, quem já estava na sala) ao lugar de antes.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	var size_before: int = Settings.text_size
	Tips.enabled = false
	Campaign.save_dir = "user://test-character-stage-%d" % Time.get_ticks_usec()
	Campaign.state = Campaign.create_initial(181)
	# Um caído em recuperação (#118): fica deitado na Enfermaria ou no Dormitório, fora do passeio.
	var fallen: Dictionary = Campaign.state.roster[2]
	S.admit_fallen(Campaign.state, [fallen.id])
	var station = await _open()
	if t.check(station != null, "a Estação abriu"):
		for size in [0, 2]:
			Settings.set_text_size(size)
			await _stage(station, "Maior" if size == 2 else "Normal", fallen.id)
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


func _stage(station, profile: String, fallen_id: String) -> void:
	var hud: AHRefugeHud = station.hud
	# Onde cada morador está antes de abrir a Sala (o passeio para enquanto a tela cobre a Estação).
	var before := {}
	for id in station.residents:
		before[id] = [station.residents[id].position, station.residents[id].visible]
	hud.open_room(S.CHARACTERS)
	await _frames(5)
	var screen: AHCharacterRoom = hud._room_screen
	if not t.check(is_instance_valid(screen), "%s: a Sala abre" % profile):
		return
	var first: String = screen.selected
	var card: AHSpriteCard = station.stage_card
	t.check(is_instance_valid(card) and station.stage_hero == first, "%s: o escolhido (%s) está no cômodo" % [profile, first])
	t.equal(screen.find_children("*", "Control", true, false).filter(func(n): return n.get_class() == "Control" and n.name == "Hero").size(), 0,
		"%s: nenhuma figura do herói na interface" % profile)
	if card == null:
		return
	var room: Dictionary = station.room_def(S.CHARACTERS)
	t.check(is_equal_approx(card.position.y, room.floor) and card.position.x > room.x0 and card.position.x < room.x1,
		"%s: de pé no chão da Sala (y %.2f, x %.2f)" % [profile, card.position.y, card.position.x])
	t.equal(card.body_height, AHCharacterHeights.find(first), "%s: na altura dele, a escala dos moradores" % profile)
	t.check(station.residents.values().all(func(r): return not r.visible), "%s: os moradores escondidos enquanto a tela cobre a Estação" % profile)
	# Os pés aparecem entre os dois painéis, acima da barra de baixo.
	await _settle(station)
	var feet: Vector2 = station.camera.unproject_position(card.global_position)
	# O vão real entre os painéis (no Maior, o da esquerda cresce com o texto): os pés no meio dele.
	var left_end: float = screen.get_node("Left").get_global_rect().end.x
	var right_start: float = screen.get_node("Right").get_global_rect().position.x
	t.check(is_equal_approx(screen.stage_gap().x, left_end) and is_equal_approx(screen.stage_gap().y, right_start),
		"%s: a câmera usa o vão real entre os painéis (%.0f a %.0f)" % [profile, left_end, right_start])
	t.check(absf(feet.x - (left_end + right_start) * 0.5) < 12.0 and feet.y > 400.0 and feet.y < 1000.0,
		"%s: os pés no meio do vão entre os painéis (%.0f, %.0f; o meio em %.0f)" % [profile, feet.x, feet.y, (left_end + right_start) * 0.5])
	# O tamanho da figura antiga da interface (o pedido do Lucas): a câmera dentro do cômodo, a altura do herói em px.
	var head: Vector2 = station.camera.unproject_position(card.global_position + Vector3(0, card.body_height, 0))
	var expected: float = card.body_height * AHStation.STAGE_PX_PER_METER
	t.check(absf((feet.y - head.y) - expected) < expected * 0.05 and absf(feet.y - AHStation.STAGE_FEET) < 20.0,
		"%s: do tamanho da figura antiga (%.0f px, esperado %.0f) e com os pés na linha dela (y %.0f)" % [profile, feet.y - head.y, expected, feet.y])
	# Trocar de herói: o de antes sai da sala, o novo entra.
	var other: String = S.living(Campaign.state).filter(func(h): return h.id != first)[0].id
	screen.selected = other
	screen.rebuild()
	await _frames(3)
	t.check(not is_instance_valid(card) or card.is_queued_for_deletion(), "%s: trocar tira o de antes" % profile)
	t.check(is_instance_valid(station.stage_card) and station.stage_hero == other, "%s: e põe o novo (%s)" % [profile, other])
	t.check(station.get_node_or_null("StageHero") == station.stage_card, "%s: uma placa só na sala, com o nome dela" % profile)
	# O caído em recuperação também pode ser escolhido: aparece na sala só enquanto escolhido.
	screen.selected = fallen_id
	screen.rebuild()
	await _frames(3)
	t.equal(station.stage_hero, fallen_id, "%s: o caído em recuperação aparece na sala" % profile)
	# Sair: ninguém fica na sala por ter sido escolhido; cada um volta para onde estava.
	hud.close_panel()
	await _frames(5)
	t.check(not is_instance_valid(station.stage_card) and station.stage_hero == "", "%s: ao sair, o escolhido sai da sala" % profile)
	var moved: Array = []
	for id in before:
		var card_now = station.residents.get(id)
		if card_now == null or card_now.visible != before[id][1] or card_now.position.distance_to(before[id][0]) > 0.6:
			moved.append(id)
	t.equal(moved, [], "%s: cada morador volta para onde estava (e o caído, para a recuperação)" % profile)


func _open():
	GameFlow.change_to("station", {}, false)
	for frame in 300:
		await _tree.process_frame
		var scene := _tree.current_scene
		if not GameFlow.busy and scene is AHStation and scene.hud != null:
			await _settle(scene)
			return scene
	return null


func _settle(station) -> void:
	for i in 600:
		await _tree.process_frame
		if station.camera_settled() and not station.passage_moving() and i > 4:
			break


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
