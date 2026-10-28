## O herói ferido (#194): a regra (o limite da vida, o Caído em recuperação), o passo mais lento da equipe, o balanço de
## mancar (e sem ele com "Reduzir efeitos"), a pose de ferido quando a arte existe, o aviso na HUD que aparece e some e o
## save.
extends RefCounted

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	_rule()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-wounded-%d" % Time.get_ticks_usec()
	await _street()
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _rule() -> void:
	var rules := AHWounded.rules()
	t.check(rules.has("Threshold") and rules.has("SpeedFactor"), "os números vêm de data/wounded.json")
	var limit: float = float(rules.Threshold)
	var hero := {"id": "x", "alive": true, "max_hp": 100, "hp": int(100 * limit) - 1}
	t.check(AHWounded.is_wounded(hero), "abaixo do limite (%d de 100), ferido" % hero.hp)
	hero.hp = int(ceil(100 * limit))
	t.check(not AHWounded.is_wounded(hero), "no limite (%d de 100), não" % hero.hp)
	# Um limite só: o ferido que manca é o "Ferimento grave" do kit (o coração rachado da Sala dos Personagens).
	for hp in range(0, 101):
		var same: bool = AHWounded.is_wounded({"alive": true, "max_hp": 100, "hp": hp}) == (AHKit.health_state(hp, 100).id == "heavy")
		if not same:
			t.check(false, "com %d de 100, o ferido e o Ferimento grave do kit não batem" % hp)
			break
	t.equal(AHKit.heavy_below(), limit, "o kit lê o mesmo limite de data/wounded.json")
	hero.hp = 100
	hero.recovery_days = 2
	t.check(AHWounded.is_wounded(hero), "o Caído em recuperação conta como ferido, mesmo com a vida cheia")
	hero.alive = false
	t.check(not AHWounded.is_wounded(hero), "quem morreu não anda ferido")
	t.check(not AHWounded.is_wounded(null), "sem herói, não")
	hero = {"alive": true, "max_hp": 100, "hp": 10}
	t.equal(AHWounded.speed_factor(hero), float(rules.SpeedFactor), "ferido, anda na fração da velocidade")
	hero.hp = 100
	t.equal(AHWounded.speed_factor(hero), 1.0, "inteiro, na velocidade toda")
	# A pose: o arquivo da mesma pasta, no canvas e na âncora do idle; sem o arquivo, o idle.
	var idle: Dictionary = AHCombatArena.hero_art_of("hero_cao_bento").idle
	var other := AHWounded.pose(idle, "hurt.webp")
	t.check(other.file.ends_with("/hurt.webp") and other.anchor == idle.anchor and other.canvas == idle.canvas,
		"com o arquivo na pasta, a pose troca o arquivo e guarda o canvas e a âncora")
	t.equal(AHWounded.pose(idle, "nao-existe.webp"), idle, "sem o arquivo, fica o idle")


func _street() -> void:
	var c: Dictionary = Campaign.create_initial(5)
	AHJourneyRules.start_expedition(c, "fase_1", 5)
	var leader: Dictionary = c.roster.filter(func(h): return h.id == c.session.expedition.team[0])[0]
	leader.hp = maxi(1, int(leader.max_hp * 0.2))
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("street", {}, false)
	var street = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			street = _tree.current_scene
			break
	if not t.check(street != null, "a rua abre"):
		return
	t.equal(street.party_speed_factor(), float(AHWounded.rules().SpeedFactor), "com o líder ferido, a fila anda no passo dele")
	# O balanço: andando, o ferido pende para o lado e o inteiro não; com "Reduzir efeitos", ninguém.
	var tilts := _walk(street)
	t.check(tilts[0] > 0.01, "o ferido manca andando (pende %.3f rad)" % tilts[0])
	t.check(tilts.slice(1).all(func(v): return v < 0.0001), "quem está inteiro anda reto %s" % [tilts.slice(1)])
	Campaign.state.settings.reduced_environment_effects = true
	tilts = _walk(street)
	t.check(tilts.all(func(v): return v < 0.0001), "com Reduzir efeitos, sem o balanço")
	Campaign.state.settings.reduced_environment_effects = false
	# O aviso na HUD: o coração rachado no retrato do ferido, e some quando a vida volta.
	var hud: AHExplorationHud = street.exploration_hud
	hud.refresh(Campaign.state)
	var mark: Control = hud.find_child("Mate_%s" % leader.id, true, false).find_child("Wounded", true, false)
	t.check(mark != null and mark.tooltip_text == hud.tr("Precisa se recuperar"), "o retrato do ferido com o aviso")
	t.check(mark != null and mark.mouse_filter == Control.MOUSE_FILTER_PASS, "e o clique passa para a plaquinha (a Formação escolhe o herói)")
	t.equal(hud.find_children("Wounded", "", true, false).size(), 1, "só o ferido tem o aviso")
	# O save: a vida baixa volta com o save, e o herói segue ferido.
	Campaign.save()
	var saved = Campaign.read_file(Campaign.primary_path())
	t.check(AHWounded.is_wounded(saved.roster.filter(func(h): return h.id == leader.id)[0]), "depois do save, segue ferido")
	leader.hp = leader.max_hp
	hud.refresh(Campaign.state)
	t.equal(hud.find_children("Wounded", "", true, false).size(), 0, "com a vida de volta, o aviso some")
	t.equal(street.party_speed_factor(), 1.0, "e a fila volta ao passo todo")
	_tree.unload_current_scene()
	await _tree.process_frame


## Anda a fila alguns quadros para a direita e devolve o maior balanço de cada um.
func _walk(street) -> Array:
	var tilts: Array = []
	tilts.resize(street._heroes.size())
	tilts.fill(0.0)
	street._check_wounds()
	for frame in 40:
		street._leader.position.x += 0.05
		street._trail.push_front(street._leader.position)
		street._time += 1.0 / 60.0
		street._place_party(1.0 / 60.0)
		for index in street._heroes.size():
			tilts[index] = maxf(tilts[index], absf(street._heroes[index].rotation.z))
	return tilts
