## A noite e o amanhecer (#132): o evento da noite sorteado pela semente (o mesmo com a mesma), o vigia que diminui as
## chances ruins, o efeito e o texto de cada evento, o save no meio da noite, a cena da noite que se pula (só o cartão
## com "Reduzir efeitos") e o resumo do amanhecer com os números da noite.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const R = preload("res://scripts/flow/network_radar.gd")
const TEAM := ["hero_cao_bento", "hero_coruja_vespera", "hero_gato_nick", "hero_sapo_iris"]

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_draw()
	_watch_odds()
	_events()
	_save_midway()
	await _scene()


## Uma campanha com a noite aberta (a volta da expedição id), com suprimentos para todos.
func _night(expedition_id: String = "night-1", watch: String = "") -> Dictionary:
	var c: Dictionary = Campaign.create_initial(132)
	S.begin_night(c, expedition_id, TEAM, 6)
	if watch != "":
		S.set_watch(c, watch)
	for entry in c.roster:
		entry.instinct = 60
	return c


func _draw() -> void:
	var a := _night("same")
	var b := _night("same")
	S.resolve_night(a)
	S.resolve_night(b)
	t.equal(a.night.event, b.night.event, "a mesma noite sorteia o mesmo evento")
	var seen := {}
	for i in 80:
		var c := _night("draw-%d" % i)
		S.resolve_night(c)
		seen[c.night.event_id] = true
	t.check(seen.size() >= 4 and seen.has("quiet"), "em 80 noites, vários eventos (%s)" % ", ".join(seen.keys()))


## O vigia diminui as chances ruins (evita as perdas) sem escolher a noite: a mesma semente sorteia o mesmo evento com
## ou sem vigia (a revisão do #172).
func _watch_odds() -> void:
	var bad_alone := 0
	var bad_watched := 0
	var changed: Array = []
	for i in 300:
		var alone := _night("odds-%d" % i)
		S.resolve_night(alone)
		bad_alone += 1 if S.night_event_bad(alone) else 0
		for watcher in ["hero_cao_bento", "hero_gato_nick"]:
			var watched := _night("odds-%d" % i, watcher)
			S.resolve_night(watched)
			if watcher == "hero_cao_bento":
				bad_watched += 1 if S.night_event_bad(watched) else 0
			# O vigia só pode trocar a noite tranquila pela que ele vê (o evento que pede vigia).
			if watched.night.event_id != alone.night.event_id and watched.night.event_id != "watcher_sees":
				changed.append("%d:%s>%s" % [i, alone.night.event_id, watched.night.event_id])
	t.check(bad_watched < bad_alone, "com vigia, menos noites com perda (%d contra %d em 300)" % [bad_watched, bad_alone])
	t.check(changed.is_empty(), "trocar o vigia não troca o evento sorteado (%s)" % ", ".join(changed.slice(0, 5)))


func _events() -> void:
	var quiet := _night()
	S.resolve_night(quiet, "quiet")
	t.check(S.night_event_text(quiet).contains("tranquila"), "nada: a noite tranquila")
	# Ruídos: quem dorme baixa menos instinto; com vigia, nada.
	var noise := _night()
	S.resolve_night(noise, "distant_noise")
	t.equal(S.hero(noise, "hero_gato_nick").instinct, S.hero(quiet, "hero_gato_nick").instinct + 3, "ruídos: o instinto baixa 3 a menos")
	t.check(S.night_event_text(noise).contains("Ruídos"), "e o texto conta")
	var guarded := _night("night-1", "hero_cao_bento")
	S.resolve_night(guarded, "distant_noise")
	t.check(guarded.night.event.prevented and S.night_event_text(guarded).contains("vigia"), "com vigia, os ruídos não atrapalham")
	# Goteira: a água cai; com vigia, fica.
	var leak := _night()
	var water: int = leak.station.water
	S.resolve_night(leak, "leak")
	t.equal(int(leak.station.water), maxi(0, water - 2), "goteira: 2 de água a menos")
	t.check(S.night_event_text(leak).contains("goteira"), "e o texto conta")
	var dry := _night("night-1", "hero_cao_bento")
	S.resolve_night(dry, "leak")
	t.equal(int(dry.station.water), water, "com vigia, a água fica")
	# Baratas: os suprimentos caem; o Depósito melhorado protege.
	var pests := _night()
	S.resolve_night(pests, "pests")
	var reference := _night()
	S.resolve_night(reference, "quiet")
	t.equal(S.quantity(pests, S.SUPPLIES), S.quantity(reference, S.SUPPLIES) - 2, "baratas: 2 suprimentos a menos")
	var shelves := _night()
	shelves.station.rooms[S.DEPOT] = 2
	S.resolve_night(shelves, "pests")
	t.check(shelves.night.event.protected and S.night_event_text(shelves).contains("prateleiras"), "o Depósito melhorado protege")
	t.equal(S.quantity(shelves, S.SUPPLIES), S.quantity(reference, S.SUPPLIES), "e nada se perde")
	# Com o estoque vazio ou baixo, o texto conta o que de fato se perdeu (e o vazio não é ruim).
	var empty := _night()
	empty.station.water = 0
	S.resolve_night(empty, "leak")
	t.check(S.night_event_text(empty).contains("não havia água") and not S.night_event_bad(empty), "goteira sem água: nada a perder, sem alerta")
	var low := _night()
	low.station.water = 1
	S.resolve_night(low, "leak")
	t.check(int(low.station.water) == 0 and S.night_event_text(low).contains("1 de água se perdeu"), "goteira com 1 de água: perde 1, no singular")
	var bare := _night()
	S.adjust(bare, S.SUPPLIES, -S.quantity(bare, S.SUPPLIES))
	S.resolve_night(bare, "pests")
	t.check(S.night_event_text(bare).contains("não havia o que estragar") and not S.night_event_bad(bare), "baratas na despensa vazia: nada a estragar")
	var one := _night()
	S.adjust(one, S.SUPPLIES, -S.quantity(one, S.SUPPLIES) + 5)
	S.resolve_night(one, "pests")
	t.check(S.night_event_text(one).contains("1 suprimento se perdeu"), "baratas com 1 suprimento sobrando depois da ceia: no singular")
	# Barulho na plataforma: a chance do próximo trem sobe.
	var platform := _night()
	S.resolve_night(platform, "platform_noise")
	t.equal(int(platform.station.train_dry), 1, "barulho na plataforma: o próximo trem mais provável")
	# O vigia vê algo: o radar lê o guardião do próximo lugar.
	var sees := _night("night-1", "hero_coruja_vespera")
	t.equal(R.state_of(sees, "fase_1", "boss"), "unknown", "antes, sem leitura do guardião")
	S.resolve_night(sees, "watcher_sees")
	t.equal(R.state_of(sees, "fase_1", "boss"), "known", "o vigia viu: o guardião da fase 1 fica lido")
	t.check(S.night_event_text(sees).contains("Véspera") and S.night_event_text(sees).contains("Vitrines"), "e o texto diz quem viu e onde")
	# Um morador conversa.
	var talk := _night()
	talk.station.residents = [S.DORA]
	S.resolve_night(talk, "resident_talk")
	t.check(S.night_event_text(talk).begins_with("A Dora"), "a Dora conversa")
	# Quem tem trauma não dorme: o instinto não baixa.
	var trauma := _night()
	S.hero(trauma, "hero_gato_nick").trauma = true
	S.resolve_night(trauma, "sleepless")
	t.equal(trauma.night.event.hero_id, "hero_gato_nick", "o Nick, com trauma, não dorme")
	t.equal(S.hero(trauma, "hero_gato_nick").instinct, 60, "o instinto dele não baixa")
	t.check(S.night_event_text(trauma).contains("Nick"), "e o texto diz")
	# Sem sono, perde só o desconto do sono: a sede pesa igual (a revisão do #172).
	var dry_trauma := _night()
	S.hero(dry_trauma, "hero_gato_nick").trauma = true
	dry_trauma.night.thirsty = true
	S.resolve_night(dry_trauma, "sleepless")
	t.equal(S.hero(dry_trauma, "hero_gato_nick").instinct, 60 + S.THIRST_INSTINCT_PENALTY, "sem sono e com sede, a sede ainda pesa")
	# Os eventos que pedem algo só saem com ele.
	var strays: Array = []
	for i in 60:
		var lone := _night("needs-%d" % i)
		S.resolve_night(lone)
		if lone.night.event_id in ["watcher_sees", "resident_talk", "sleepless"]:
			strays.append(lone.night.event_id)
	t.check(strays.is_empty(), "sem vigia, morador ou trauma, nenhum evento que pede isso (%s)" % ", ".join(strays))


func _save_midway() -> void:
	var c := _night("saved")
	S.resolve_night(c, "leak")
	var reopened = Campaign._normalize(JSON.parse_string(JSON.stringify(c)))
	S.migrate(reopened)
	t.equal(reopened.night.phase, "dawn", "o save no meio da noite abre no amanhecer")
	t.equal(S.night_event_text(reopened), S.night_event_text(c), "com o mesmo evento")


func _scene() -> void:
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var tips: bool = Tips.enabled
	Tips.enabled = false
	Campaign.save_dir = "user://test-night-%d" % Time.get_ticks_usec()
	for reduced in [false, true]:
		var c := _night("scene", "hero_cao_bento")
		c.settings.reduced_environment_effects = reduced
		c.station.rooms[S.DORMITORY] = 1
		Campaign.state = c
		Campaign.save()
		GameFlow.change_to("station", {}, false)
		var station: AHStation = null
		for frame in 600:
			await _tree.process_frame
			if not GameFlow.busy and GameFlow.passage == null and _tree.current_scene is AHStation and frame > 3:
				station = _tree.current_scene
				break
		if not t.check(station != null, "a Estação abriu"):
			continue
		var hud: AHRefugeHud = station.hud
		hud.open_room(S.DORMITORY)
		await _frames(3)
		var start := hud._footer.find_children("*", "Button", true, false).filter(func(b): return (b as Button).text.to_lower().begins_with("iniciar descanso"))
		if not t.check(not start.is_empty(), "o Dormitório tem Iniciar descanso"):
			continue
		start[0].pressed.emit()
		await _frames(2)
		t.check(hud.night_scene_open() and _label(hud._night_scene, "Noite 1"), "a cena da noite abre com o cartão")
		# Um refresh no meio da cena (as Opções, o trem) não religa o amanhecer por baixo da sombra.
		hud.refresh()
		await _frames(2)
		t.check(hud.night_scene_open() and not hud._panel.visible, "um refresh durante a cena não mostra o amanhecer por baixo")
		t.equal(Campaign.state.night.phase, "dawn", "e a noite já foi resolvida (o save no meio abre no amanhecer)")
		# Quem dormiu fica deitado no beliche, e o vigia de pé, até a manhã.
		var lying: Array = station._walkers.filter(func(w): return w.has("hero_id") and w.get("sleeping", false)).map(func(w): return w.hero_id)
		lying.sort()
		var slept: Array = ["hero_coruja_vespera", "hero_gato_nick", "hero_sapo_iris"]
		t.equal(lying, slept, "na noite, quem dorme fica deitado, e o vigia (Bento) de pé")
		var deadline := Time.get_ticks_msec() + 600
		while Time.get_ticks_msec() < deadline:
			await _tree.process_frame
		if reduced:
			t.equal(station.night_dim, 1.0, "com Reduzir efeitos, a Estação não escurece: só o cartão")
		else:
			t.check(station.night_dim < 0.9, "a Estação escurece (%.2f)" % station.night_dim)
		_send("interact")
		await _frames(3)
		t.check(not hud.night_scene_open() and station.night_dim == 1.0, "Interagir pula a noite, e a luz volta")
		t.check(not station._walkers.any(func(w): return w.has("hero_id") and w.get("sleeping", false)), "e de manhã todos se levantam")
		t.check(_label(hud._panel, "Amanhecer · Dia 1"), "o amanhecer abre")
		t.check(_label(hud._panel, "suprimentos comidos") and _label(hud._panel, "Água:"), "com os números da noite")
		t.check(_label(hud._panel, "Depois:") and not _label(hud._panel, "Depois: Passar a noite"), "o Depois diz o passo seguinte ao amanhecer")
		t.check(not _label(hud._panel, "−0 de instinto") and not _label(hud._panel, "+0 de vida"), "sem os zeros de quem não tinha o que recuperar")
		# Martelar Interagir não pula o amanhecer (a trava depois do pulo).
		_send("interact")
		await _frames(3)
		t.equal(Campaign.state.night.phase, "dawn", "o segundo Interagir logo depois do pulo não começa o dia")
		var told: Label = hud._panel.find_child("EventText", true, false)
		t.check(told != null and told.text == S.night_event_text(Campaign.state), "e o evento da noite")
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


func _send(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func _label(root: Node, part: String) -> bool:
	return root.find_children("*", "Label", true, false).any(func(l): return (l as Label).text.contains(part))


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame
