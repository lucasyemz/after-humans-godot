## As poses do lobby (#249) na Estação de verdade: para cada caso de capture.json, monta a equipe com a arte da main
## (antes), fotografa, troca só a textura pela pose nova (depois) e fotografa de novo, no mesmo processo, com a mesma
## câmera, as mesmas posições e o mesmo instante. Nenhum arquivo do jogo muda: as poses novas são os WebP que o
## prepare_webp.py gera numa pasta fora do repositório, carregados só em memória.
##   xvfb-run -n 95 -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     -s res://docs/design/lobby_poses/capture_lobby.gd -- --out=<pasta> --ready=<saída do prepare_webp.py>
## A campanha de teste fica em <pasta>/save e é apagada no fim; o save do jogador fica intacto.
extends SceneTree

const CONTRACT := "res://docs/design/lobby_poses/contract.json"
const CAPTURE := "res://docs/design/lobby_poses/capture.json"
## Os cômodos abertos só na memória desta campanha de teste.
const ROOMS := ["characters", "canteen", "dormitory", "research"]
## O id do jogo de cada modelo da entrega: a arte de hoje (antes) e a altura de hoje.
const GAME_ID := {
	"bento": "hero_cao_bento", "nick": "hero_gato_nick", "iris": "hero_sapo_iris", "vespera": "hero_coruja_vespera",
	"dog": "dog_recruit_01", "cat": "cat_recruit_01", "frog": "frog_recruit_01", "owl": "owl_recruit_01",
	"raccoon": "raccoon_recruit_01", "armadillo": "armadillo_recruit_01",
}

var out := ""
var ready_dir := ""
var alt_dir := ""
var only: PackedStringArray = []
## Quadros de espera antes de cada foto: no Compatibility sem placa de vídeo cada quadro da Estação leva quase um minuto.
var wait := 2
var campaign
var flow
var contract: Dictionary
var combat: Dictionary
var poses: Dictionary
var Card
var Heights


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--ready="):
			ready_dir = arg.trim_prefix("--ready=")
		elif arg.begins_with("--alt="):
			alt_dir = arg.trim_prefix("--alt=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
		elif arg.begins_with("--wait="):
			wait = int(arg.trim_prefix("--wait="))
	if out == "" or ready_dir == "":
		push_error("Faltam --out=<pasta> e --ready=<pasta dos WebP>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	contract = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	combat = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/combat_art.json"))
	poses = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/station_poses.json"))
	var cases: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CAPTURE)).cases
	await process_frame
	Card = load("res://scripts/world/sprite_card.gd")
	Heights = load("res://scripts/world/character_heights.gd")
	campaign = root.get_node("Campaign")
	flow = root.get_node("GameFlow")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	var c: Dictionary = campaign.create_initial(249)
	for room in ROOMS:
		c.station.rooms[room] = 1
	campaign.state = c
	campaign.save()
	flow.change_to("station", {}, false)
	await _settle()
	var station = current_scene
	station.hud.visible = false
	for walker in station._walkers:
		walker.card.visible = false
	station.set_process(false)
	var camera := Camera3D.new()
	station.add_child(camera)
	camera.current = true
	for name in cases:
		if not only.is_empty() and not only.has(name):
			continue
		await _case(station, camera, name, cases[name])
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _case(station, camera: Camera3D, name: String, spec: Dictionary) -> void:
	camera.transform = str_to_var(spec.camera)
	camera.fov = spec.fov
	var cards: Array = []
	for actor in spec.actors:
		var card = Card.new()
		var before := _before_art(actor.actor, spec.state)
		card.body_height = Heights.find(_game_id(actor.actor))
		card.show_art(before)
		station.add_child(card)
		station.occlusion.track(card)
		card.position = str_to_var(actor.position)
		card.set_facing(1.0)
		cards.append(card)
	await _frames(wait)
	await _shot(name + "_before")
	await _swap(cards, spec, ready_dir)
	await _shot(name + "_after")
	if alt_dir != "":
		await _swap(cards, spec, alt_dir)
		await _shot(name + "_alt")
	for card in cards:
		card.queue_free()
	await _frames(1)


## Troca só a textura e as medidas pela pose nova, sem mexer na posição, na câmera ou na hora.
func _swap(cards: Array, spec: Dictionary, dir: String) -> void:
	for i in cards.size():
		var model: String = spec.actors[i].actor
		var asset: Dictionary = contract.actors[model].assets[spec.state]
		var card = cards[i]
		var texture := ImageTexture.create_from_image(Image.load_from_file(dir.path_join(asset.prototype_file)))
		card.body_height = contract.actors[model].height_m
		card._art = {"file": card._art.file, "canvas": asset.canvas, "anchor": asset.anchor,
			"body_reference_pixels": asset.body_reference_pixels}
		card._texture = texture
		card._material.albedo_texture = texture
		card._layout()
	await _frames(wait)


## A arte de hoje: a pose da Estação do fundador ou, sem ela (recrutas, fêmeas), o idle do macho de hoje.
func _before_art(model: String, state: String) -> Dictionary:
	var id := _game_id(model)
	if id.begins_with("hero_"):
		return combat.heroes[id].idle if state == "idle" else poses[id + "_" + state]
	return combat.recruits[id].idle


func _game_id(model: String) -> String:
	return GAME_ID[model.trim_suffix("_male").trim_suffix("_female")]


func _settle() -> void:
	for i in 600:
		await process_frame
		if not flow.busy and current_scene != null and i > 1:
			break
	await _frames(wait)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
