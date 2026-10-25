## Fotos da passagem (#74): o antes (o fade preto de change_to no meio da troca) e o cartão novo em cada troca grande
## (título → Estação, Estação → rua, rua → rua no mapa da fase, Estação → título), carregando e pronto para pular, em
## inglês, com o texto Maior e com "Reduzir efeitos"; e as Opções da Estação com o Voltar ao título.
##   "$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_passage.gd -- --out=<pasta>
## A campanha fica numa pasta dentro de <pasta>; o save do jogador fica intacto.
extends SceneTree

var out := ""
var flow
var campaign


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out == "":
		push_error("Falta --out=<pasta>.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	campaign = root.get_node("Campaign")
	flow = root.get_node("GameFlow")
	campaign.save_dir = out.path_join("save")
	campaign.save_time_on_quit = false
	root.get_node("Tips").set("enabled", false)
	campaign.state = campaign.create_initial(21)
	campaign.save()
	flow.change_to("title", {}, false)
	await _idle()
	# Antes: a troca de sempre (change_to) é só o preto.
	flow.change_to("station")
	await _wait(func(): return flow._fade.modulate.a >= 0.99)
	await _shot("before-black")
	await _idle()
	# Título (Continuar) → Estação.
	flow.change_to("title", {}, false)
	await _idle()
	await _card("01-title-to-station", "station", true)
	# Estação → rua: a partida para a Ponte das Raízes (no mapa de passagem, o Cais do Rio).
	var J = load("res://scripts/flow/journey_rules.gd")
	J.start_expedition(campaign.state, "fase_2", 5)
	await _card("02-station-to-street", "street")
	# Rua → rua: o fim do mapa de passagem leva ao mapa da fase.
	campaign.state.session.expedition.corridor.index = 4
	await _card("03-transit-to-phase-map", "street")
	campaign.state.session.expedition = null
	await _card("04-street-to-station", "station")
	# As Opções da Estação: Voltar ao título.
	var hud = current_scene.hud
	hud.open_service("options")
	await _frames(6)
	var back: Button = null
	for button in hud.find_children("*", "Button", true, false):
		if button.text == "Voltar ao título":
			back = button
	if back != null:
		var scroll: Node = back.get_parent()
		while scroll != null and not scroll is ScrollContainer:
			scroll = scroll.get_parent()
		if scroll != null:
			scroll.ensure_control_visible(back)
		back.grab_focus()
	await _frames(4)
	await _shot("05-station-options-back-to-title")
	await _card("06-station-to-title", "title")
	# Em inglês, com o texto Maior e com Reduzir efeitos (sem movimento: o título já parado no primeiro quadro).
	TranslationServer.set_locale("en")
	await _card("07-english", "station")
	TranslationServer.set_locale("pt_BR")
	root.get_node("Settings").set_text_size(2)
	await _card("08-larger-text", "title")
	root.get_node("Settings").set_text_size(0)
	campaign.state.settings.reduced_environment_effects = true
	flow.travel("station")
	await _wait(func(): return flow.passage != null and flow._fade.modulate.a <= 0.01)
	await _shot("09-reduced-effects-first-frame")
	await _idle()
	campaign.state.settings.reduced_environment_effects = false
	for file in DirAccess.get_files_at(campaign.save_dir):
		DirAccess.remove_absolute(campaign.save_dir.path_join(file))
	DirAccess.remove_absolute(campaign.save_dir)
	quit(0)


## Uma passagem fotografada: o cartão logo que aparece (carregando, se ainda estiver) e pronto para pular; e a cena nova.
func _card(name: String, scene_id: String, loading: bool = false) -> void:
	flow.travel(scene_id)
	await _wait(func(): return flow.passage != null and flow._fade.modulate.a <= 0.01)
	if loading and not flow.passage.ready_to_skip:
		await _shot(name + "-loading")
	await _wait(func(): return flow.passage == null or flow.passage.ready_to_skip)
	await _frames(30)
	if flow.passage != null:
		await _shot(name)
	await _idle()
	await _frames(20)
	await _shot(name + "-arrived")


func _idle() -> void:
	await _frames(3)
	await _wait(func(): return not flow.busy)
	await _frames(3)


func _wait(condition: Callable) -> void:
	for i in 3000:
		if condition.call():
			return
		await process_frame


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("foto: ", name)
