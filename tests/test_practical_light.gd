## A luz prática na Rua das Vitrines (#154, AHPracticalLight e o "lights" do perfil de ambiência):
## - poucas fontes, do kit que ficou (o tambor com fogo, o lampião, a emergência e o farol do drone), sem a arte que o
##   Lucas tirou (a gambiarra, o letreiro, o robô, o sensor e o drone pintado);
## - cada fonte com o card aceso, o halo, a poça e a luz, fora da faixa de andar;
## - a qualidade manda: sem a luz da cena (Compatibility ou Baixo), só o halo e a poça, mais fortes; com ela, a poça
##   desenhada enfraquece e a sombra segue o lamp_shadows;
## - de noite e na chuva as fontes são a luz principal; o drone só passa de noite; com "Reduzir efeitos", nada tremula
##   nem passa (a emergência acesa, o drone escondido); só o tambor faz sombra de luz.
extends RefCounted

const J := preload("res://scripts/flow/journey_rules.gd")
const KEPT := ["barrel", "lantern", "emergency", "drone"]
const REMOVED := ["T_LP01", "T_LP05", "T_LP07", "T_LP08", "T_LP09", "T_LP_Beam"]

var t
var _tree: SceneTree


func run(context) -> void:
	t = context
	_tree = Engine.get_main_loop()
	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	var real_persist: bool = Settings._persist
	Settings._persist = false
	Campaign.save_dir = "user://test-practical-%d" % Time.get_ticks_usec()
	_data()
	await _street()
	if _tree.current_scene != null:
		_tree.unload_current_scene()
	await _tree.process_frame
	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Settings._persist = real_persist
	Campaign.save_dir = real_dir
	Campaign.state = real_state


func _data() -> void:
	var lights: Array = AHAmbience.profile("ShopfrontStreet").lights
	t.check(lights.size() >= 3 and lights.size() <= 5, "poucas fontes na Rua (%d)" % lights.size())
	t.check(lights.all(func(l): return KEPT.has(String(l.kind))), "só as fontes que ficaram")
	t.equal(Array(AHAmbience.profile("RiverDock").lights), [], "os outros mapas esperam o piloto")
	for kind in AHPracticalLight.KINDS:
		var art: String = AHPracticalLight.KINDS[kind].art
		t.check(not REMOVED.has(art) and ResourceLoader.exists("res://art/scenarios/%s_Lit.webp" % art)
			and ResourceLoader.exists("res://art/scenarios/%s_Halo.webp" % art), "%s: o card aceso e o halo existem" % kind)


func _street() -> void:
	var c := Campaign.create_initial(60)
	J.start_expedition(c, "fase_1", 60)
	Campaign.state = c
	Campaign.save()
	GameFlow.change_to("street", {}, false)
	var street = null
	for frame in 600:
		await _tree.process_frame
		if not GameFlow.busy and _tree.current_scene != null and _tree.current_scene.name == "Street" and frame > 3:
			street = _tree.current_scene
			break
	if not t.check(street != null, "a Rua abre"):
		return
	var real_level: int = Settings.level
	var sources: Array = street._practical
	t.equal(sources.size(), AHAmbience.profile("ShopfrontStreet").lights.size(), "as fontes do perfil na Rua")
	for source: AHPracticalLight in sources:
		if source.kind == "drone":
			t.check(source.light is SpotLight3D and source.global_position.y > 5.0, "o drone: o farol para baixo, alto")
			continue
		t.check(source.card != null and source.halo != null and source.pool != null and source.light is OmniLight3D,
			"%s: o card, o halo, a poça e a luz" % source.kind)
		# A rua anda pelos becos: as de chão ficam no beco (atrás da calçada, fora do caminho da rua) e seguram a equipe;
		# as de parede, no alto.
		if AHPracticalLight.KINDS[source.kind].get("solid", false):
			t.check(source.global_position.z < AHStreetSet.FACADE_FRONT_Y * 0.01 and street._blocked(source.global_position),
				"%s: no beco, com colisão" % source.kind)
		else:
			t.check(source.global_position.y > 2.0, "%s: no alto da parede" % source.kind)
		# Só a fonte principal (o tambor) faz sombra de luz; as outras, nunca.
		var casts: bool = AHPracticalLight.KINDS[source.kind].get("light_shadow", false)
		t.check(source.light.is_in_group(Settings.SHADOW_LAMPS) == casts and (casts or not source.light.shadow_enabled),
			"%s: %s" % [source.kind, "a sombra segue o lamp_shadows" if casts else "sem sombra de luz"])
	var barrel: AHPracticalLight = sources.filter(func(s): return s.kind == "barrel")[0]
	t.check(barrel.fire != null and barrel.embers != null, "o tambor tem o fogo e as fagulhas")
	var drone: AHPracticalLight = sources.filter(func(s): return s.kind == "drone")[0]
	# No Baixo (ou fora do Forward+): sem a luz da cena, só o halo e a poça.
	Settings.set_level(0)
	await _tree.process_frame
	t.check(not barrel.light.visible, "no Baixo, a luz da cena fica apagada")
	t.check(is_equal_approx(_pool(barrel) / barrel._flicker, AHPracticalLight.POOL_ALONE * (1.0 if street._mood == "night" else AHPracticalLight.GOLDEN)),
		"e a poça desenhada faz a luz")
	Settings.set_level(real_level)
	await _tree.process_frame
	t.equal(barrel.light.visible, street._forward_plus and real_level >= 1, "a luz da cena só no Forward+, da Média para cima")
	# Com a luz da cena (Forward+, da Média para cima).
	barrel.refresh(true, false, true, false)
	t.check(barrel.light.visible and _pool(barrel) < AHPracticalLight.POOL_ALONE, "com a luz da cena, a poça desenhada enfraquece")
	var night_energy: float = barrel.light.light_energy / barrel._flicker
	barrel.refresh(false, false, true, false)
	t.check(barrel.light.light_energy / barrel._flicker < night_energy, "no fim de tarde, a fonte é mais fraca que de noite")
	var golden_energy: float = barrel.light.light_energy / barrel._flicker
	barrel.refresh(false, true, true, false)
	t.check(barrel.light.light_energy / barrel._flicker > golden_energy * 1.5, "na chuva, as fontes viram a luz principal")
	drone.refresh(false, false, true, false)
	t.check(not drone.visible, "o drone não passa de dia")
	drone.refresh(true, false, true, false)
	t.check(drone.visible, "e passa de noite")
	var emergency: AHPracticalLight = sources.filter(func(s): return s.kind == "emergency")[0]
	emergency._time = AHPracticalLight.PULSE_ON + 0.1
	emergency._process(0.0)
	emergency.refresh(true, false, true, true)
	t.equal(emergency._flicker, 1.0, "Reduzir efeitos: a emergência fica acesa, não presa no pulso fraco")
	drone.refresh(true, false, true, true)
	t.check(not drone.visible, "e o drone não passa")
	emergency.refresh(true, false, true, false)
	barrel.refresh(true, false, true, true)
	t.check(not barrel.embers.emitting, "Reduzir efeitos: sem fagulhas")
	barrel.refresh(true, false, true, false, false)
	t.check(not barrel.visible and not barrel.light.visible, "num interior, a fonte some")
	# A rua devolve o estado dela.
	street._mood = "night"
	street._raining = false
	street._apply_weather()
	t.check(barrel.visible and drone.visible, "de noite, na rua, o tambor e o drone")


func _pool(source: AHPracticalLight) -> float:
	return float((source.pool.material_override as ShaderMaterial).get_shader_parameter("energy"))
