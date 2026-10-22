## A cena da Estação: abrir e fechar não deixa conexões nas opções (Settings.changed), e quem dorme continua no
## beliche quando os passeios são refeitos (depois de acolher ou recusar o candidato do trem, com a noite pendente).
## Partir clicado duas vezes (o segundo clique cai durante o fade da saída) parte uma vez só, sem erro.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")


func run(t) -> void:
	var tree: SceneTree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-station-scene-%d" % Time.get_ticks_usec()
	Campaign.state = Campaign.create_initial(21)
	var counts: Array = []
	for visit in 3:
		var station = await _open(tree)
		t.check(station != null, "a Estação abriu (visita %d)" % (visit + 1))
		counts.append(Settings.changed.get_connections().size())
	t.check(counts[0] == counts[1] and counts[1] == counts[2], "abrir a Estação de novo não soma conexões nas opções (%s)" % [counts])
	# A noite pendente: quem dorme deita; refeitos os passeios (o trem), continua deitado.
	var c: Dictionary = Campaign.state
	S.confirm_departure(c, c.preferred_formation.duplicate(), 0, 555, "fase_1")
	c.session.result = "retreat"
	c.session.screen = "result"
	S.finish_return(c)
	t.equal(c.night.phase, "planning", "a volta deixa a noite pendente")
	var station = await _open(tree)
	if t.check(station != null, "a Estação abriu com a noite pendente"):
		var asleep := func(): return station._walkers.filter(func(w): return w.get("sleeping", false)).size()
		var before: int = asleep.call()
		t.check(before > 0, "quem dorme está no beliche (%d)" % before)
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		station._place_residents(rng)
		t.equal(asleep.call(), before, "refeitos os passeios, os mesmos continuam dormindo")
		S.resolve_night(c)
		S.finish_dawn(c)
		if S.visit_pending(c):
			S.decide_candidate(c, c.station.train.candidate_id, false)
			S.finish_departure(c)
		t.equal(S.preparation_block(c), "", "a Estação fica livre para partir")
		# Um fundador caído e o Risco (sem arte de combate) na Estação: a Preparação escala quem pode ir.
		c.unlocked_classes.append("rato")
		var risco: String = S.recruit(c, "rato", RandomNumberGenerator.new(), "Risco").hero_id
		var rex: String = S.recruit(c, "cao", RandomNumberGenerator.new(), "Rex").hero_id
		S.hero(c, "hero_cao_bento").alive = false
		station.hud._draft = {}
		station.hud.open_room(S.PREPARATION)
		t.check(not station.hud._draft.team.has(risco) and station.hud._draft.team.has(rex), "a Preparação escala o Rex no lugar do Bento, não o Risco")
		station.hud._depart()
		station.hud._depart()
		await tree.process_frame
		t.check(c.session.expedition != null, "Partir clicado duas vezes parte")
		var id: String = c.session.expedition.id if c.session.expedition != null else ""
		while GameFlow.busy:
			await tree.process_frame
		t.equal(c.session.expedition.id if c.session.expedition != null else "", id, "e parte uma vez só")
	tree.unload_current_scene()
	await tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _open(tree: SceneTree):
	GameFlow.change_to("station", {}, false)
	for frame in 300:
		await tree.process_frame
		var scene := tree.current_scene
		if not GameFlow.busy and scene is AHStation and scene.hud != null:
			await tree.process_frame
			return scene
	return null
