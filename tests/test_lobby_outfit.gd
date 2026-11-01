## A roupa confortável do lobby (#249): nos cômodos da Estação cada morador veste a dele; a de expedição (com a skin
## gravada) fica no resto.
## - O manifesto: os quatro fundadores (parado, banco, beliche e trabalho) e os seis recrutas (parado, banco e beliche),
##   com a arte no projeto e a textura na proporção do canvas.
## - Abrindo o jogo na Estação, todos já estão com a roupa do lobby, inclusive no banco, no beliche e no posto; os
##   recrutas também sentam e deitam.
## - A skin de expedição (a Ronda do Bento) não muda o cômodo, mas veste a figura de Ver personagem.
## - Na volta, quem desce do trem chega e faz a fila na roupa de expedição, sem aparecer no cômodo ao mesmo tempo; a
##   roupa do lobby aparece quando ele sai da plataforma. A fila da partida também é de expedição.
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")
const LOBBY := "res://art/station/lobby/"

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var briefing: bool = AHBriefing.enabled
	AHBriefing.enabled = false
	var tips: bool = Tips.enabled
	Tips.enabled = false
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-lobby-outfit-%d" % Time.get_ticks_usec()
	_manifest()
	await _load_in_lobby()
	await _after_arrival()
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
	Tips.enabled = tips
	AHBriefing.enabled = briefing


func _manifest() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AHLobbyOutfit.MANIFEST))
	var combat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AHCombatArena.ART_MANIFEST))
	var want := {}
	for hero_id in combat.heroes:
		want[hero_id] = ["idle", "seat", "sleep", "work"]
	var got := {}
	for hero_id in manifest.heroes:
		got[hero_id] = _sorted(manifest.heroes[hero_id].keys())
	t.equal(got, want, "os quatro fundadores têm as quatro poses do lobby")
	got = {}
	want = {}
	for variant in combat.recruits:
		want[variant] = ["idle", "seat", "sleep"]
	for variant in manifest.recruits:
		got[variant] = _sorted(manifest.recruits[variant].keys())
	t.equal(got, want, "cada recruta tem o parado, o banco e o beliche do lobby")
	var bad: Array = []
	for section in ["heroes", "recruits"]:
		for id in manifest[section]:
			for state in manifest[section][id]:
				var pose: Dictionary = manifest[section][id][state]
				var texture: Texture2D = load(pose.file) if ResourceLoader.exists(pose.file) else null
				if texture == null or not String(pose.file).begins_with(LOBBY):
					bad.append("%s %s: sem arte" % [id, state])
					continue
				# A textura é o canvas reduzido por igual: a âncora e a altura do manifesto valem nela.
				var ratio_x := float(texture.get_width()) / float(pose.canvas[0])
				var ratio_y := float(texture.get_height()) / float(pose.canvas[1])
				if absf(ratio_x - ratio_y) > 0.01:
					bad.append("%s %s: textura fora da proporção" % [id, state])
				if state == "seat" and pose.get("facing", "") != "side":
					bad.append("%s seat: não é de lado" % id)
	t.equal(bad, [], "toda pose do lobby tem a arte no projeto, na proporção do canvas")
	# O fundador pelo id e o recruta pela variação; sem a roupa, vazio.
	t.equal(AHLobbyOutfit.poses_of("hero_cao_bento", {}).idle.file, LOBBY + "bento/idle.webp", "o Bento pelo id")
	t.equal(AHLobbyOutfit.poses_of("hero_cao_7", {"variant": "dog_recruit_01"}).idle.file, LOBBY + "dog_male/idle.webp", "o recruta pela variação")
	t.check(AHLobbyOutfit.poses_of("hero_cao_7", {"variant": "dog_recruit_99"}).is_empty(), "sem a roupa, nada")


## O jogo aberto na Estação: a roupa do lobby direto, sem animação.
func _load_in_lobby() -> void:
	var c: Dictionary = Campaign.create_initial(249)
	for class_id in ["cao", "gato", "sapo", "coruja", "rato", "tatu"]:
		var variant: String = S.pick_art_variant(c, class_id)
		S._add_hero(c, S._next_hero_id(c, class_id), class_id, "Teste %s" % class_id, [], variant)
	# A Ronda (#138) vestida no Bento: a skin é a de expedição.
	S.unlock_all_skins(c)
	S.choose_skin(c, "hero_cao_bento", "bento_watch")
	var station := await _open(c)
	if not t.check(station != null, "a Estação abre"):
		return
	t.check(station.hud.current != AHRefugeHud.ARRIVAL and not station.team_arriving(), "sem volta pendente, nada de chegada")
	var dressed: Array = []
	var other: Array = []
	for entry in S.living(c):
		var card: AHSpriteCard = station.residents.get(entry.id)
		if card == null:
			other.append("%s sem placa" % entry.id)
		elif String(card.art().get("file", "")).begins_with(LOBBY):
			dressed.append(entry.id)
		else:
			other.append("%s: %s" % [entry.id, card.art().get("file", "")])
	t.equal(other, [], "abrindo na Estação, ninguém está na roupa de expedição")
	t.equal(dressed.size(), S.living(c).size(), "os %d moradores já estão na roupa do lobby" % dressed.size())
	t.check(station.residents.values().all(func(card): return card.visible), "e todos à vista nos cômodos")
	# O banco, o beliche e o posto também (os recrutas agora sentam e deitam).
	var wrong: Array = []
	for walker in station._walkers.filter(func(w): return w.has("hero_id")):
		var founder: bool = not S.is_recruit(walker.hero_id)
		var states: Array = ["idle", "seat", "sleep", "work"] if founder else ["idle", "seat", "sleep"]
		if _sorted(walker.poses.keys()) != _sorted(states) or walker.poses.values().any(func(p): return not String(p.file).begins_with(LOBBY)):
			wrong.append(walker.hero_id)
	t.equal(wrong, [], "cada morador senta, deita e trabalha na roupa do lobby")
	var recruit: Dictionary = station._walkers.filter(func(w): return w.has("hero_id") and S.is_recruit(w.hero_id))[0]
	recruit.seat = 0
	station._seats[0] = recruit
	station._sit_down(recruit)
	t.check(String(recruit.card.art().file).ends_with("/seat.webp") and String(recruit.card.art().file).begins_with(LOBBY), "o recruta senta no banco da Cantina")
	station._stand_up(recruit)
	t.check(recruit.card.art().file == recruit.poses.idle.file, "e levanta na mesma roupa")
	# A noite: quem dorme deita no beliche na roupa do lobby.
	c.night.phase = "planning"
	c.night.participants = S.living(c).map(func(h): return h.id)
	c.night.watch_hero_id = c.night.participants[-1]
	station._update_sleepers()
	var lying: Array = station._walkers.filter(func(w): return w.get("sleeping", false))
	t.check(not lying.is_empty() and lying.all(func(w): return String(w.card.art().file).begins_with(LOBBY) and String(w.card.art().file).ends_with("sleep.webp")),
		"à noite, %d deitados no beliche na roupa do lobby" % lying.size())
	c.night.phase = "none"
	station._update_sleepers()
	# A Ronda não muda o cômodo; Ver personagem mostra a roupa de expedição, na skin.
	var bento: AHSpriteCard = station.residents.get("hero_cao_bento")
	t.equal(bento.art().get("file"), LOBBY + "bento/idle.webp", "com a Ronda vestida, o Bento no cômodo continua na roupa do lobby")
	station.show_stage_hero("hero_cao_bento")
	t.check(is_instance_valid(station.stage_card) and String(station.stage_card.art().file).begins_with("res://art/skins/bento/watch/"),
		"e em Ver personagem aparece com a Ronda")
	station.clear_stage_hero()
	station.redress("hero_cao_bento")
	t.equal(station.residents.get("hero_cao_bento").art().get("file"), LOBBY + "bento/idle.webp", "trocar de skin não tira a roupa do lobby")
	# A fila da partida: a roupa de expedição.
	var team: Array = S.living(c).slice(0, 4).map(func(h): return h.id)
	station.show_departure(team)
	await _frames(2)
	t.check(not station.lineup.is_empty() and station.lineup.all(func(e): return not String(e.card.art().file).begins_with(LOBBY)),
		"na fila da partida, todos na roupa de expedição")
	t.check(team.all(func(id): return not station.residents[id].visible), "e fora do cômodo enquanto estão na plataforma")
	station.clear_lineup()


## A volta: a chegada e o relatório na roupa de expedição; a do lobby quando saem da plataforma.
func _after_arrival() -> void:
	var c: Dictionary = Campaign.create_initial(250)
	var team: Array = c.roster.slice(0, 4).map(func(h): return h.id)
	AHJourneyRules.start_expedition(c, "fase_1", 250)
	c.session.expedition.team = team
	c.session.result = "victory"
	S.finish_return(c)
	var station := await _open(c)
	if not t.check(station != null, "a Estação abre na volta"):
		return
	var hud: AHRefugeHud = station.hud
	t.check(station.team_arriving(), "a volta começa com a chegada de trem")
	# Ninguém da equipe aparece no cômodo enquanto ainda está no trem (lá estaria na roupa do lobby).
	t.check(team.all(func(id): return not station.residents[id].visible), "quem está no trem não aparece no cômodo")
	# Uma tela do kit que cobre a Estação e sai (hide_residents) no meio da chegada.
	station.hide_residents(true)
	await _frames(2)
	station.hide_residents(false)
	var early: Array = station._arrivals.filter(func(a): return a.card == null).map(func(a): return a.hero_id)
	t.check(early.all(func(id): return not station.residents[id].visible), "nem fechando uma tela no meio da chegada (%d ainda no trem)" % early.size())
	t.check(await _until(func(): return hud.current == "report", 40.0), "o relatório abre com todos na fila")
	t.check(station.lineup.size() == team.size() and station.lineup.all(func(e): return not String(e.card.art().file).begins_with(LOBBY)),
		"na chegada e no relatório, a equipe está na roupa de expedição")
	t.check(team.all(func(id): return not station.residents[id].visible), "e não aparece no cômodo")
	hud._enter_shelter_then(Callable())
	await _frames(2)
	t.check(station._leaving.all(func(e): return not String(e.card.art().file).begins_with(LOBBY)), "saindo da plataforma, ainda de expedição")
	t.check(await _until(func(): return not station.lineup_leaving(), 30.0), "a equipe sai da plataforma")
	t.check(team.all(func(id): return station.residents[id].visible and String(station.residents[id].art().file).begins_with(LOBBY)),
		"depois da chegada, cada um aparece no cômodo na roupa do lobby")


func _open(c: Dictionary) -> AHStation:
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("station", {}, false)
	for i in 600:
		await _tree.process_frame
		var scene := _tree.current_scene
		if scene is AHStation and scene.hud != null and not GameFlow.busy and i > 3:
			return scene
	return null


func _until(condition: Callable, seconds: float) -> bool:
	var limit := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < limit:
		if condition.call():
			return true
		await _tree.process_frame
	return condition.call()


func _frames(count: int) -> void:
	for i in count:
		await _tree.process_frame


func _sorted(values: Array) -> Array:
	var out := values.duplicate()
	out.sort()
	return out
