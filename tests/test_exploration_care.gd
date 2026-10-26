## Mochila: os cuidados fora da luta e o item na luta. Port dos testes da Unreal AfterHumans.Flow.ExplorationCare e
## AfterHumans.Flow.CombatItem, com os mesmos números (15% e 35% da vida, curativo +8, ampola de 5 a 8 com 3 cargas).
extends RefCounted

const R = preload("res://scripts/flow/journey_rules.gd")
const C = preload("res://scripts/flow/exploration_care.gd")


func run(t) -> void:
	_exploration(t)
	_camp(t)
	_combat(t)


## No acampamento, comer pouco pela Mochila é o mesmo da barra (decisão do Lucas, #98): +10% da vida e -5 de instinto.
func _camp(t) -> void:
	var campaign := _campaign(56)
	campaign.session.screen = "rest"
	campaign.session.expedition.food = 4
	var target: Dictionary = campaign.roster[0]
	var max_hp: int = target.max_hp
	var q := C.quote(campaign, target.id, C.SMALL_MEAL)
	t.equal(q.heal_min, R.camp_meal_heal(max_hp), "no acampamento a Mochila cota os 10% da barra")
	t.equal(q.instinct, -R.CAMP_MEAL_INSTINCT, "e os -5 de instinto")
	C.use(campaign, target.id, C.SMALL_MEAL)
	t.equal(target.hp, 1 + R.camp_meal_heal(max_hp), "cura 10% da vida")
	t.equal(target.instinct, 30 - R.CAMP_MEAL_INSTINCT, "tira 5 de instinto")
	target.hp = max_hp
	t.check(C.quote(campaign, target.id, C.SMALL_MEAL).available, "com a vida cheia, ainda come para baixar o instinto, como na barra")
	target.instinct = 0
	t.check(not C.quote(campaign, target.id, C.SMALL_MEAL).available, "com a vida cheia e sem instinto, não gasta comida")
	t.equal(C.quote(campaign, target.id, C.FULL_MEAL).instinct, 0, "comer bem não muda no acampamento")


func _campaign(seed_value: int) -> Dictionary:
	var campaign: Dictionary = Campaign.create_initial(seed_value)
	R.start_expedition(campaign, "fase_1", seed_value * 7919 + 13)
	for hero in campaign.roster:
		hero.hp = 1
		hero.instinct = 30
	return campaign


func _find(campaign: Dictionary, class_id: String) -> Dictionary:
	for hero in campaign.roster:
		if hero.class_id == class_id:
			return hero
	return {}


func _exploration(t) -> void:
	var campaign := _campaign(55)
	var expedition: Dictionary = campaign.session.expedition
	t.equal(expedition.team.size(), campaign.roster.size(), "a equipe inteira na expedição")
	var iris := _find(campaign, "sapo")
	var target: Dictionary = campaign.roster[0]
	var max_hp: int = target.max_hp
	expedition.food = 4
	t.check(C.use(campaign, target.id, C.SMALL_MEAL) > 0, "comer pouco")
	t.equal(target.hp, 1 + maxi(1, max_hp * 15 / 100), "15% da vida, arredondado para baixo")
	t.equal(expedition.food, 3, "comer pouco gasta 1")
	t.equal(target.instinct, 30, "fora do acampamento não mexe no instinto")
	t.check(C.use(campaign, target.id, C.FULL_MEAL) > 0, "comer bem")
	t.equal(expedition.food, 0, "comer bem gasta 3")
	t.equal(C.use(campaign, target.id, C.SMALL_MEAL), 0, "sem comida não cura")
	t.equal(C.quote(campaign, target.id, C.SMALL_MEAL).reason, "Comida insuficiente.", "e diz por quê")

	target.hp = 1
	campaign.inventory.bandages = 1
	t.check(C.use(campaign, target.id, C.BANDAGE) > 0, "curativo na exploração")
	t.equal(target.hp, mini(max_hp, 9), "curativo +8")
	t.equal(campaign.inventory.bandages, 0, "gasta o estoque do refúgio")
	t.equal(C.use(campaign, target.id, C.BANDAGE), 0, "sem curativo não cura")
	campaign.inventory.bandages = 1
	target.hp = max_hp
	t.equal(C.use(campaign, target.id, C.BANDAGE), 0, "vida cheia guarda o curativo")
	t.equal(campaign.inventory.bandages, 1, "o curativo recusado não é gasto")
	t.equal(C.use(campaign, target.id, C.IRIS_AMPOULE), 0, "vida cheia não gasta carga")
	t.check(not iris.expedition_uses.has(C.AMPOULE), "a cotação não reserva carga")

	var in_range := true
	for i in 3:
		target.hp = 1
		t.check(C.use(campaign, target.id, C.IRIS_AMPOULE) > 0, "ampola na exploração (%d)" % (i + 1))
		in_range = in_range and target.hp >= 6 and target.hp <= 9
	t.check(in_range, "a cura respeita 5 a 8")
	t.equal(iris.expedition_uses[C.AMPOULE], 0, "as três cargas acabam")
	target.hp = 1
	campaign.session.screen = "rest"
	t.equal(C.use(campaign, target.id, C.IRIS_AMPOULE), 0, "fora do corredor não usa")
	campaign.session.screen = "corridor"
	campaign.session.event = {"event_id": "x"}
	t.equal(C.use(campaign, target.id, C.IRIS_AMPOULE), 0, "um evento aberto bloqueia")
	campaign.session.event = null
	t.equal(C.use(campaign, target.id, C.IRIS_AMPOULE), 0, "a quarta carga é recusada")
	t.equal(C.quote(campaign, target.id, C.IRIS_AMPOULE).reason, "Sem cargas. A ampola recarrega após uma vitória.", "e diz por quê")
	# Gravar e abrir não devolve a carga gasta.
	var path := "user://test_exploration_care.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(Campaign._envelope(campaign))
	file.close()
	var saved = Campaign.read_file(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	t.check(saved != null, "o save abre")
	t.equal(_find(saved, "sapo").expedition_uses.get(C.AMPOULE, -1) if saved else -1, 0, "o save guarda a carga gasta")

	# Recarga: vitória sim; derrota e fuga não; o antídoto continua limitado à expedição.
	var session := AHCombatSession.create([iris], ["robot"], false, 42)
	t.equal(session.state.player_team[0].remaining_uses.get(C.AMPOULE, -1), 0, "a luta não recarrega ao começar")
	t.equal(C.use(campaign, target.id, C.IRIS_AMPOULE), 0, "sem cargas na exploração com a luta montada")
	session.state.is_over = true
	session.state.victory = false
	C.restore_iris_after_victory(campaign, session)
	t.equal(iris.expedition_uses[C.AMPOULE], 0, "derrota não recarrega")
	session.state.victory = true
	session.state.escaped = true
	C.restore_iris_after_victory(campaign, session)
	t.equal(iris.expedition_uses[C.AMPOULE], 0, "fuga não recarrega")
	session.state.escaped = false
	iris.expedition_uses["sapo_antidoto_campo"] = 0
	C.restore_iris_after_victory(campaign, session)
	t.equal(iris.expedition_uses[C.AMPOULE], 3, "vitória recarrega a ampola")
	t.equal(session.state.player_team[0].remaining_uses[C.AMPOULE], 3, "e a foto da luta também")
	t.equal(iris.expedition_uses["sapo_antidoto_campo"], 0, "o antídoto continua limitado")

	iris.alive = false
	t.equal(C.use(campaign, target.id, C.IRIS_AMPOULE), 0, "Íris morta não cura")
	iris.alive = true
	expedition.team.erase(iris.id)
	t.equal(C.use(campaign, target.id, C.IRIS_AMPOULE), 0, "Íris fora da equipe não cura")
	expedition.team.append(iris.id)
	target.class_id = "non_playable_machine"
	t.equal(C.quote(campaign, target.id, C.IRIS_AMPOULE).reason, "A ampola trata somente aliados orgânicos.", "alvo não orgânico recusado")


func _combat(t) -> void:
	var campaign := _campaign(77)
	campaign.session.expedition.food = 4
	campaign.inventory.bandages = 2
	var heroes: Array = campaign.roster.slice(0, 4)
	var session := AHCombatSession.create(heroes, ["robot"], true, 9)
	# A vez de um herói, já decidindo (o começo da vez processado).
	var bento: AHCombat.Unit = session.state.player_team[0]
	session.state.current_turn_unit_id = bento.id
	session.processed_turn_key = session.turn_key()
	bento.hp = 5
	var heal := maxi(1, bento.max_hp * 15 / 100)
	t.check(not session.use_item(campaign, C.IRIS_AMPOULE).ok, "na luta a ampola é habilidade da Íris")
	t.check(session.use_item(campaign, C.SMALL_MEAL).ok, "comer pouco na luta")
	t.equal(bento.hp, 5 + heal, "cura o herói da vez")
	t.equal(campaign.session.expedition.food, 3, "gasta 1 comida")
	t.equal(session.state.current_turn_unit_id, bento.id, "ação livre: a vez continua")
	var second := session.use_item(campaign, C.BANDAGE)
	t.check(not second.ok, "um item por vez")
	t.check(String(second.error).contains("já usou"), "e explica o bloqueio")
	t.equal(campaign.inventory.bandages, 2, "o item bloqueado não é gasto")
	session.state.round += 1
	session.processed_turn_key = session.turn_key()
	t.check(session.use_item(campaign, C.BANDAGE).ok, "a próxima vez libera")
	t.equal(campaign.inventory.bandages, 1, "curativo gasta o estoque do refúgio")
	session.state.round += 1
	session.processed_turn_key = session.turn_key()
	bento.hp = bento.max_hp
	t.check(not session.use_item(campaign, C.BANDAGE).ok, "vida cheia recusada")
	bento.hp = 0
	bento.deaths_door = true
	t.check(not session.use_item(campaign, C.BANDAGE).ok, "Limiar da Morte recusado")
	bento.hp = 3
	bento.deaths_door = false
	session.processed_turn_key = ""
	t.check(not session.use_item(campaign, C.BANDAGE).ok, "só enquanto o herói decide")
	t.equal(campaign.inventory.bandages, 1, "recusas nunca gastam")
