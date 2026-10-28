## QA por captura da #194 (o herói ferido), pela cena de verdade:
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_194.gd -- --out=<pasta>
## Campanha própria na pasta da saída. Roda também na main de antes. A Rua da fase 1 com o Bento (o líder) a 20% da vida
## e a Véspera a 25%: a equipe parada (o aviso na HUD) e uma sequência andando (walk-00..walk-11, o mancar), e os
## recortes dos pés (feet-*) para a folha de antes e depois; por fim, os quatro feridos parados (all-wounded).
extends SceneTree

var out := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	var flow = root.get_node("GameFlow")
	root.get_node("Tips").enabled = false
	root.get_node("Settings")._persist = false
	campaign.save_dir = out.path_join("save")
	var c: Dictionary = campaign.create_initial(5)
	load("res://scripts/flow/journey_rules.gd").start_expedition(c, "fase_1", 5)
	var team: Array = c.session.expedition.team
	for hero in c.roster:
		if hero.id == team[0]:
			hero.hp = maxi(1, int(hero.max_hp * 0.2))
		elif hero.id == team.back():
			hero.hp = maxi(1, int(hero.max_hp * 0.25))
	campaign.state = c
	campaign.save()
	flow.change_to("street", {}, false)
	for frame in 900:
		await process_frame
		if not flow.busy and current_scene != null and current_scene.name == "Street" and frame > 3:
			break
	var street = current_scene
	await create_timer(1.5).timeout
	street.exploration_hud.refresh(campaign.state)
	await create_timer(0.5).timeout
	await _shot("stand")
	# Andando para a direita: o líder avança e a fila segue; uma foto a cada 4 quadros.
	street.corridor.busy = true
	for frame in 48:
		street._leader.position.x += 0.04
		street._trail.push_front(street._leader.position)
		await process_frame
		if frame % 4 == 3:
			await _shot("walk-%02d" % (frame / 4))
	# Os quatro fundadores feridos, parados: a âncora da pose de cada um (o pé na linha do chão).
	street.corridor.busy = false
	for hero in campaign.state.roster:
		if hero.id in team:
			hero.hp = maxi(1, int(hero.max_hp * 0.2))
	street._check_wounds()
	street.exploration_hud.refresh(campaign.state)
	await create_timer(1.0).timeout
	await _shot("all-wounded")
	print("capturas da #194 em %s" % out)
	quit(0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png(out.path_join(name + ".png"))
	image.get_region(Rect2i(0, 520, 1920, 560)).save_png(out.path_join("feet-" + name + ".png"))
