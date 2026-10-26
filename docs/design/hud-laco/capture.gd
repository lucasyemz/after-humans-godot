## Fundo limpo da carga recuperada (#91) para o lote 6 (#96), tirado do jogo de verdade (gl_compatibility, 1920x1080):
## a rua com o guardião vencido e a carga esperando a escolha, sem a interface, e as seis caixas sorteadas (o conteúdo,
## o texto e o ícone de AHFightRewards) em cargo.json. A escolha (a caixa 2) e a ordem da revelação vão junto.
##   xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     -s res://docs/design/hud-laco/capture.gd -- --out=<pasta>
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto. Nada de scripts/, data/ ou tests/ muda.
extends SceneTree

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	var J = load("res://scripts/flow/journey_rules.gd")
	var FR = load("res://scripts/flow/fight_rewards.gd")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	# O guardião vencido, como em tools/capture_rewards.gd: reaberto, a carga espera a escolha.
	var c: Dictionary = campaign.create_initial(96)
	J.start_expedition(c, "fase_1", 9696)
	c.session.expedition.objective_completed = true
	campaign.state = c
	campaign.save()
	flow.change_to("street", {}, false)
	for frame in 900:
		await process_frame
		if not flow.busy and flow.passage == null and current_scene != null and current_scene.name == "Street" and frame > 3:
			break
	await _frames(30)
	var boxes: Array = FR.cargo(campaign.state).boxes
	var dump := {"phase": "fase_1", "boxes": [], "chosen": 1}
	for box in boxes:
		dump.boxes.append({"kind": box.kind, "amount": box.amount, "relic_id": box.get("relic_id", ""), "text": FR.box_text(box), "icon": FR.icon_of(box)})
	# O corpo de cada herói na tela (a conta do clique do acampamento, AHCampHud.body_rect): a tela confere que o painel
	# da carga não cobre a equipe.
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var HUD = load("res://scripts/ui/camp_hud.gd")
	dump["bodies"] = []
	for card in current_scene._heroes:
		var r: Rect2 = HUD.body_rect(cam, card)
		dump.bodies.append([r.position.x, r.position.y, r.size.x, r.size.y])
	_hide_ui()
	await _frames(4)
	await _shot("cargo")
	var f := FileAccess.open(out.path_join("cargo.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(dump, "  "))
	f.close()
	# O caso da relíquia (o texto mais longo): a primeira semente da expedição, a partir da desta, cujo sorteio traz uma
	# relíquia; a escolha é ela. Só o sorteio muda: a rua e a equipe são as da foto.
	for seed in range(9697, 9997):
		var other: Dictionary = campaign.create_initial(96)
		J.start_expedition(other, "fase_1", seed)
		other.session.expedition.objective_completed = true
		var drawn: Array = FR.cargo(other).boxes
		var relic := drawn.map(func(b): return b.kind).find("relic")
		if relic < 0:
			continue
		var relic_dump := {"phase": "fase_1", "seed": seed, "boxes": [], "chosen": relic, "bodies": dump.bodies}
		for box in drawn:
			relic_dump.boxes.append({"kind": box.kind, "amount": box.amount, "relic_id": box.get("relic_id", ""), "text": FR.box_text(box), "icon": FR.icon_of(box)})
		var g := FileAccess.open(out.path_join("cargo_relic.json"), FileAccess.WRITE)
		g.store_string(JSON.stringify(relic_dump, "  "))
		g.close()
		print("relíquia na semente ", seed)
		break
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	quit(0)


func _hide_ui() -> void:
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	for control in root.find_children("*", "Control", true, false):
		if not (control.get_parent() is Control):
			control.visible = false


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
