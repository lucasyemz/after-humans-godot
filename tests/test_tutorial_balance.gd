## O equilíbrio das lutas do tutorial (#144), pela simulação das três em sequência como no jogo (a vida passa de uma
## para a outra; entre a segunda e a terceira, só o fôlego, da busca ou da chegada à zona do Drone; as regras de
## AHTutorial.prepare_fight), com sementes fixas e duas políticas: a ingênua (a primeira habilidade no primeiro alvo,
## como quem aperta o que vê) e a automática da paridade (com a abertura em metade das lutas 2 e 3).
## - a primeira luta é uma lição de verdade: a equipe de três perde de 10% a 25% da vida somada, em média, na ingênua;
## - a terceira mostra a contaminação do Drone de Expurgo em pelo menos 90% das vezes, nas duas políticas;
## - o piso de vida 1 é rede, não o que segura a luta: alguém chega a 1 em no máximo 10% das lutas 2 e 3;
## - as três terminam em vitória.
## Os números de referência ficam em docs/qa/tutorial-arc.md.
extends RefCounted

const RUNS := 40

var t


func run(context) -> void:
	t = context
	_breath_once()
	for policy in ["naive", "auto"]:
		var damage: Array = []
		var team_hp: Array = []
		var contaminated := 0
		var victories := 0
		var floor_hits := {3: 0, 5: 0}
		for run in RUNS:
			var c: Dictionary = Campaign.create_initial(1000 + run)
			AHTutorial.begin(c, 5000 + run)
			var expedition: Dictionary = c.session.expedition
			for step in [1, 3, 5]:
				if step == 3:
					AHTutorial.join(c)
				# O fôlego antes do Drone: em metade das corridas pela busca do armário, na outra metade ao chegar à zona da
				# luta (quem passou sem vasculhar).
				if step == 5:
					if run % 4 < 2:
						AHTutorial.catch_breath(c)
					else:
						t.check(AHTutorial.breath_on_arrival(c, 5, 1) or _team_full(c), "sem a busca, o fôlego vem ao chegar à luta do Drone")
				var heroes: Array = expedition.team.map(func(id): return AHStationRules.hero(c, id))
				var opening: bool = policy == "auto" and step != 1 and run % 2 == 0
				var session := AHCombatSession.create(heroes, AHJourneyRules.corridor_enemies(expedition, step), opening, 9000 + run * 7 + step, 80)
				session.use_expedition(c)
				AHTutorial.prepare_fight(session.context)
				var hp_before := _team_hp(session)
				if step == 1:
					team_hp.append(session.state.player_team.reduce(func(sum, u): return sum + u.max_hp, 0))
				var blight := false
				var floor_hit := false
				var turns := 0
				while not session.is_over() and turns < 300:
					turns += 1
					if session.is_player_turn():
						_play(session, policy)
					else:
						session.enemy_turn()
					for unit in session.state.player_team:
						blight = blight or unit.blight.duration > 0
						floor_hit = floor_hit or unit.hp <= 1
				if step == 1:
					damage.append(hp_before - _team_hp(session))
				if floor_hit and floor_hits.has(step):
					floor_hits[step] += 1
				if step == 5 and blight:
					contaminated += 1
				if session.result() == "victory":
					victories += 1
				session.write_back(c)
		var share := _avg(damage) / _avg(team_hp)
		print("    tutorial (%s): 1ª luta tira %.1f de %.0f de vida (%.0f%%); contaminação na 3ª em %d de %d; vida 1 na 2ª em %d e na 3ª em %d" % [
			policy, _avg(damage), _avg(team_hp), share * 100.0, contaminated, RUNS, floor_hits[3], floor_hits[5]])
		t.equal(victories, RUNS * 3, "%s: as três lutas terminam em vitória" % policy)
		for step in floor_hits:
			t.check(floor_hits[step] <= ceili(RUNS * 0.1), "%s: na luta do trecho %d, alguém chega à vida 1 em no máximo 10%% das vezes (%d de %d)" % [policy, step, floor_hits[step], RUNS])
		if policy == "naive":
			t.check(share >= 0.10 and share <= 0.25, "naive: a primeira luta tira de 10%% a 25%% da vida da equipe (%.0f%%)" % (share * 100.0))
		t.check(contaminated >= RUNS * 0.9, "%s: a contaminação aparece na terceira luta em 90%% das vezes ou mais (%d de %d)" % [policy, contaminated, RUNS])


## A vez do herói: a ingênua usa a primeira habilidade de ataque no primeiro alvo (ou defende); a automática é a da paridade.
## O fôlego vem uma vez só: depois da busca, a chegada não cura de novo; sem a busca, a chegada cura; e só na zona da
## luta do Drone.
func _breath_once() -> void:
	var c: Dictionary = Campaign.create_initial(77)
	AHTutorial.begin(c, 77)
	var hero = AHStationRules.hero(c, c.session.expedition.team[0])
	hero.hp = 2
	t.check(not AHTutorial.breath_on_arrival(c, 2, 3), "a chegada à zona do Nick não dá fôlego")
	t.check(AHTutorial.catch_breath(c) and int(hero.hp) > 2, "a busca dá o fôlego")
	hero.hp = 2
	t.check(not AHTutorial.breath_on_arrival(c, 5, 1) and int(hero.hp) == 2, "depois da busca, a chegada à luta do Drone não cura de novo")
	c = Campaign.create_initial(78)
	AHTutorial.begin(c, 78)
	hero = AHStationRules.hero(c, c.session.expedition.team[0])
	hero.hp = 2
	t.check(AHTutorial.breath_on_arrival(c, 5, 1) and int(hero.hp) > 2, "sem a busca, a chegada à luta do Drone dá o fôlego")
	t.check(not AHTutorial.catch_breath(c), "e a busca depois não dá outro")


func _team_full(c: Dictionary) -> bool:
	return c.session.expedition.team.all(func(id):
		var hero = AHStationRules.hero(c, id)
		return int(hero.hp) >= int(hero.max_hp))


func _play(session: AHCombatSession, policy: String) -> void:
	if policy == "auto":
		session.auto_player_turn()
		return
	var actor = session.current_actor()
	var start: Dictionary = session.begin_player_turn()
	if not start.can_act or session.is_over():
		return
	var options: Array = session.ability_options(actor.id).filter(func(o): return o.usable and o.enemy_side and not o.targets.is_empty())
	if options.is_empty():
		session.defend(actor.id)
	else:
		session.use_ability(actor.id, options[0].id, options[0].targets[0])


func _team_hp(session: AHCombatSession) -> int:
	return session.state.player_team.reduce(func(sum, u): return sum + maxi(0, u.hp), 0)


func _avg(values: Array) -> float:
	return values.reduce(func(sum, v): return sum + float(v), 0.0) / maxf(1.0, values.size())
