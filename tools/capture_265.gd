## Fotos dos serviços dos cômodos (#265):
##   bar: o Bar com as conversas do dia (uma já usada no nível 2) e o trauma a tratar;
##   infirmary: a Enfermaria no nível 2, com a peculiaridade negativa a tratar num leito;
##   training: o diálogo do Treino (quantos heróis por dia);
##   camp: a Sala com uma de acampamento para aprender (o aviso que leva ao Treino) e o Treino de acampamento aberto.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_265.gd -- --out=<pasta> --case=bar|infirmary|training|camp [--text-size=2]
## Só mexe no estado por dicionários (roda também na main, para as fotos de antes). O save do jogador fica intacto.
extends SceneTree

var out := ""
var case_name := "bar"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--case="):
			case_name = arg.trim_prefix("--case=")
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var campaign = root.get_node("Campaign")
	campaign.save_dir = out.path_join("save-%s" % case_name)
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	var S = load("res://scripts/flow/station_rules.gd")
	var c: Dictionary = campaign.create_initial(265)
	c.station.last_return = {}
	S.adjust(c, "seeds", 40)
	S.adjust(c, "fragments", 10)
	match case_name:
		"bar":
			c.station.rooms[S.BAR] = 2
			for index in 3:
				c.roster[index].trauma = true
			c.station.bar_talks = {"cycle": int(c.station.get("cycle_number", 0)), "heroes": [String(c.roster[3].id)]}
		"infirmary":
			c.station.rooms[S.INFIRMARY] = 2
			var anxious = S.hero(c, "hero_rato_ana") if S.hero(c, "hero_rato_ana") != null else c.roster[0]
			if not Array(anxious.perks).has("anxious"):
				anxious.perks.append("anxious")
		"training", "camp":
			c.station.rooms["training"] = 2
			var bento = S.hero(c, "hero_cao_bento")
			bento.level = 4
			bento.camp_unlocked = ["camp_cao_palavra_firme"]
			bento.xp = 9999
	campaign.state = c
	campaign.save()
	var flow = root.get_node("GameFlow")
	flow.change_to("station", {}, false)
	await _frames(10)
	while flow.busy:
		await process_frame
	await _frames(20)
	var hud = current_scene.hud
	match case_name:
		"bar":
			hud.open_room(S.BAR)
			await _frames(20)
			await _shot("10-bar")
		"infirmary":
			hud.open_room(S.INFIRMARY)
			await _frames(20)
			await _shot("20-infirmary")
		"training":
			hud.open_room(S.CHARACTERS)
			await _frames(10)
			var screen = hud._room_screen
			screen.selected = "hero_cao_bento"
			screen.training = true
			screen.rebuild()
			await _frames(20)
			await _shot("30-training")
		"camp":
			hud.open_room(S.CHARACTERS)
			await _frames(10)
			var screen = hud._room_screen
			screen.selected = "hero_cao_bento"
			screen.camp_skill = "camp_cao_dividir_a_carga"
			screen._reveal = true
			screen._reveal_camp = true
			screen.rebuild()
			await _frames(20)
			await _shot("40-room")
			var learn := screen.find_child("CampLearn", true, false) as Button
			if learn != null and not learn.disabled:
				learn.pressed.emit()
				await _frames(20)
				await _shot("41-camp-training")
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
