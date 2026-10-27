## A câmera de cinema por lugar (#153, data/presentation/ambience.json e AHAmbience):
## - o perfil carrega de data/: o default, um por mapa e o da Estação, e cada lugar só troca o que muda;
## - a Rua das Vitrines (o piloto) abre com o perfil dela no pós, no glow e na névoa, com as folhas e o vapor;
## - a qualidade manda: no Baixo, sem o desfoque de profundidade e com pouca partícula;
## - a barra de Admin muda o perfil ao vivo, copia o perfil e volta ao do arquivo.
extends RefCounted

const J := preload("res://scripts/flow/journey_rules.gd")
const MAPS := ["ShopfrontStreet", "RiverDock", "RootBridge", "SealedShelter", "TriageGate", "FloodedDepot", "SewerDucts", "Station"]

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var real_level: int = Settings.level
	var real_persist: bool = Settings._persist
	Settings._persist = false
	Campaign.save_dir = "user://test-ambience-%d" % Time.get_ticks_usec()
	_data()
	await _street()
	Settings.set_level(real_level)
	Settings._persist = real_persist
	Admin.ambience = {}
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _data() -> void:
	var data := AHAmbience.data()
	var fields: Array = data.default.keys()
	t.check(fields.size() >= 18, "o default tem os campos do perfil (%d)" % fields.size())
	for id in MAPS:
		t.check(data.has(id), "%s tem perfil" % id)
		var extra: Array = Array(data.get(id, {}).keys()).filter(func(k): return not fields.has(k))
		t.equal(extra, [], "%s: só campos do perfil" % id)
	var street := AHAmbience.profile("ShopfrontStreet")
	t.check(float(street.grain) > float(data.default.grain) and Array(street.steam).size() > 0, "a Rua troca o que muda (o grão, o vapor)")
	t.equal(AHAmbience.profile("NaoExiste").saturation, data.default.saturation, "um lugar sem perfil fica com o default")
	t.equal(AHAmbience.post_values(street, 0).max_blur, 0.0, "no Baixo, sem o desfoque de profundidade")
	t.check(AHAmbience.post_values(street, 3).max_blur > 0.0, "no Ultra, com ele")
	t.check(AHAmbience.particles(street, "dust", 0) < AHAmbience.particles(street, "dust", 3), "no Baixo, menos partícula")


func _street() -> void:
	var c := Campaign.create_initial(60)
	J.start_expedition(c, "fase_1", 60)
	Campaign.state = c
	Campaign.save()
	Settings.set_level(3)
	GameFlow.change_to("street", {}, false)
	var street = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			street = _tree.current_scene
			break
	if not t.check(street != null, "a Rua abre"):
		return
	var p := AHAmbience.profile("ShopfrontStreet")
	t.equal(street.ambience_id(), "ShopfrontStreet", "a Rua usa o perfil dela")
	t.check(is_equal_approx(float(street._post.get_shader_parameter("grain")), float(p.grain))
		and is_equal_approx(float(street._post.get_shader_parameter("vignette")), float(p.vignette)), "o pós com o grão e a vinheta do perfil")
	t.check(is_equal_approx(street._env.glow_hdr_threshold, float(p.glow_threshold)), "o glow com o limiar do perfil")
	t.equal(street._steam.size(), Array(p.steam).size(), "os respiros de vapor do perfil")
	t.check(street._leaves.emitting or street._raining, "as folhas caindo")
	# A qualidade: no Baixo, o desfoque sai; de volta ao Ultra, volta.
	Settings.set_level(0)
	await _tree.process_frame
	t.equal(float(street._post.get_shader_parameter("max_blur")), 0.0, "no Baixo, sem o desfoque")
	Settings.set_level(3)
	await _tree.process_frame
	t.check(float(street._post.get_shader_parameter("max_blur")) > 0.0, "no Ultra, com o desfoque")
	# A barra de Admin, ao vivo.
	var before := float(street._post.get_shader_parameter("saturation"))
	AHAdminActions.run("amb_saturation_up")
	t.check(float(street._post.get_shader_parameter("saturation")) > before, "o Admin sobe a saturação na hora")
	var warm_before: float = Vector3(street._post.get_shader_parameter("highlights_tint")).x
	AHAdminActions.run("amb_warmth_up")
	t.check(Vector3(street._post.get_shader_parameter("highlights_tint")).x > warm_before, "e o calor das luzes")
	var copied := AHAdminActions.run("amb_copy")
	t.check(copied.contains("ShopfrontStreet") and copied.contains("highlights_tint"), "copiar o perfil traz os números mudados")
	AHAdminActions.run("amb_reset")
	t.check(is_equal_approx(float(street._post.get_shader_parameter("saturation")), before), "voltar ao perfil do arquivo")
	var amb_actions: Array = AHAdminActions.all().filter(func(a): return a.tab == "Ambiência")
	t.check(amb_actions.size() >= 20 and amb_actions.all(func(a): return AHAdminActions.blocked(a) == ""), "a aba Ambiência vale na jornada")
