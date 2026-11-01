## AHRelics (#263): os dois slots por herói, a migração do relic_id antigo, os bloqueios (o mesmo id, o papel e o
## fundador), o total dos bônus com o teto de Velocidade, de onde cada relíquia sai (os sorteios e a Forja) e o bônus
## somado na unidade de combate.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const G = preload("res://scripts/flow/station_grid.gd")
const M = preload("res://scripts/flow/side_mission_rules.gd")
const PATROL := ["robot", "robot_fungo"]
## As linhas de teste, injetadas na tabela e tiradas no fim: o que nenhum sorteio pode escolher, as restrições e um +2.
const TEST_ROWS := {
	"teste_vel2": {"Name": "teste_vel2", "DisplayName": "Teste Veloz", "Rarity": "common", "Only": "", "Sources": ["cargo", "dig"], "SpeedBonus": 2},
	"teste_rara": {"Name": "teste_rara", "DisplayName": "Teste Rara", "Rarity": "rare", "Only": "", "Sources": ["forge", "cargo", "dig"], "MaxHpBonus": 9},
	"teste_pessoal": {"Name": "teste_pessoal", "DisplayName": "Teste Pessoal", "Rarity": "personal", "Only": "hero:hero_gato_nick", "Sources": ["forge", "cargo", "dig"]},
	"teste_lembranca": {"Name": "teste_lembranca", "DisplayName": "Teste Lembrança", "Rarity": "keepsake", "Only": "", "Sources": ["forge", "cargo", "dig"]},
	"teste_papel": {"Name": "teste_papel", "DisplayName": "Teste Papel", "Rarity": "common", "Only": "role:sapo", "Sources": ["cargo"]},
	"teste_fase": {"Name": "teste_fase", "DisplayName": "Teste Fase", "Rarity": "uncommon", "Only": "", "Sources": ["cargo"], "Phase": "fase_3"},
}
const NEVER := ["teste_rara", "teste_pessoal", "teste_lembranca"]

var t


func run(context) -> void:
	t = context
	_data()
	_migration()
	_slots()
	_swap()
	_forge()
	_inject()
	_cap()
	_restrictions()
	_draws()
	_combat()
	_remove()


func _data() -> void:
	t.check(GameData.issues.is_empty(), "as tabelas validam (raridade, origens, papel e fase): %s" % ", ".join(GameData.issues))
	for relic_id in ["botao_cobre", "pena_vidro", "coleira_lembranca", "semente_guardada", "sino_vitrine", "raiz_trancada"]:
		t.check(GameData.row("relics", relic_id) != null, "%s na tabela" % relic_id)
	t.equal(AHRelics.rarity("botao_cobre"), "common", "o Botão de Cobre é comum")
	t.equal(AHRelics.rarity("coleira_lembranca"), "uncommon", "a Coleira de Lembrança é incomum")
	t.equal(AHRelics.forgeable(), ["botao_cobre", "pena_vidro", "semente_guardada"], "a Forja fabrica as comuns de origem forge")
	t.equal(AHRelics.pool("dig"), ["botao_cobre", "coleira_lembranca", "pena_vidro"], "a escavação só tem as de dig")
	t.equal(AHRelics.pool("cargo"), ["botao_cobre", "coleira_lembranca", "pena_vidro"], "a carga sem fase não tem as de fase")
	t.equal(AHRelics.pool("cargo", "fase_1"), ["botao_cobre", "coleira_lembranca", "pena_vidro", "sino_vitrine"], "o Sininho só na carga da fase 1")
	t.equal(AHRelics.pool("cargo", "fase_2"), ["botao_cobre", "coleira_lembranca", "pena_vidro", "raiz_trancada"], "a Raiz Trançada só na carga da fase 2")


## O save de antes: o relic_id vira o slot 0, a chave sai, o estoque fica igual; de novo, nada muda.
func _migration() -> void:
	var c: Dictionary = Campaign.create_initial(263)
	t.equal(S.hero(c, "hero_cao_bento").relics, ["", ""], "o herói novo nasce com os dois slots vazios")
	for hero in c.roster:
		hero.erase("relics")
		hero.relic_id = ""
	S.hero(c, "hero_cao_bento").relic_id = "pena_vidro"
	S.hero(c, "hero_gato_nick").relic_id = "fora_da_tabela"
	c.inventory.relics = ["botao_cobre", "pena_vidro", "pena_vidro"]
	S.migrate(c)
	t.equal(S.hero(c, "hero_cao_bento").relics, ["pena_vidro", ""], "o relic_id antigo vira o slot 0")
	t.equal(S.hero(c, "hero_gato_nick").relics, ["fora_da_tabela", ""], "nem a que saiu da tabela se perde")
	t.equal(S.hero(c, "hero_sapo_iris").relics, ["", ""], "quem não tinha fica com os dois vazios")
	t.check(c.roster.all(func(h): return not h.has("relic_id")), "a chave relic_id sai")
	t.equal(c.inventory.relics, ["botao_cobre", "pena_vidro", "pena_vidro"], "o estoque não muda")
	var once: Dictionary = c.duplicate(true)
	S.migrate(c)
	t.equal(c.roster, once.roster, "migrar de novo não muda os heróis")
	t.equal(c.inventory.relics, once.inventory.relics, "nem o estoque")
	# Um save editado com os dois slots e ainda o relic_id: a antiga volta ao estoque em vez de sumir.
	var bento: Dictionary = S.hero(c, "hero_cao_bento")
	bento.relics = ["botao_cobre", "pena_vidro"]
	bento.relic_id = "coleira_lembranca"
	S.migrate(c)
	t.equal(bento.relics, ["botao_cobre", "pena_vidro"], "os dois slots cheios ficam")
	t.equal(c.inventory.relics.count("coleira_lembranca"), 1, "e a do relic_id volta ao estoque")
	# Pelo save: grava, lê e migra como o load faz.
	var saved: Dictionary = Campaign.create_initial(264)
	for hero in saved.roster:
		hero.erase("relics")
		hero.relic_id = ""
	S.hero(saved, "hero_cao_bento").relic_id = "botao_cobre"
	var back = JSON.parse_string(JSON.stringify(saved))
	S.migrate(back)
	t.equal(S.hero(back, "hero_cao_bento").relics, ["botao_cobre", ""], "o save antigo, lido do JSON, carrega com a relíquia no slot 0")


func _campaign() -> Dictionary:
	var c: Dictionary = Campaign.create_initial(265)
	c.inventory.relics = []
	return c


func _total_items(c: Dictionary) -> Dictionary:
	var counts := {}
	for relic_id in c.inventory.relics:
		counts[relic_id] = int(counts.get(relic_id, 0)) + 1
	for hero in c.roster:
		for relic_id in AHRelics.equipped(hero):
			counts[relic_id] = int(counts.get(relic_id, 0)) + 1
	return counts


## O mesmo id não entra nos dois slots do herói; em heróis diferentes, sim.
func _slots() -> void:
	var c := _campaign()
	c.inventory.relics = ["pena_vidro", "pena_vidro", "pena_vidro"]
	t.equal(AHRelics.equip(c, "hero_cao_bento", 0, "pena_vidro"), "", "a primeira pena no slot 0")
	var bento: Dictionary = S.hero(c, "hero_cao_bento")
	t.equal(AHRelics.block(c, bento, 1, "pena_vidro"), "Já equipada no outro slot.", "o motivo do bloqueio")
	t.equal(AHRelics.equip(c, "hero_cao_bento", 1, "pena_vidro"), "Já equipada no outro slot.", "a mesma no outro slot é recusada")
	t.equal(bento.relics, ["pena_vidro", ""], "e o slot 1 fica vazio")
	t.equal(c.inventory.relics.count("pena_vidro"), 2, "sem tirar do estoque")
	t.equal(AHRelics.equip(c, "hero_gato_nick", 0, "pena_vidro"), "", "a cópia num outro herói vale")
	t.equal(AHRelics.equip(c, "hero_cao_bento", 0, "pena_vidro"), "Já está equipada.", "a mesma no mesmo slot não muda nada")
	t.equal(AHRelics.equip(c, "hero_cao_bento", 2, "pena_vidro"), "Esse slot não existe.", "só há dois slots")
	t.equal(AHRelics.equip(c, "hero_cao_bento", 1, "botao_cobre"), "Essa relíquia não está no estoque.", "sem a peça no estoque, nada")
	t.equal(AHRelics.equip(c, "hero_cao_bento", 1, "nao_existe"), "Relíquia desconhecida.", "nem uma que não existe")
	t.equal(AHRelics.equipped(bento), ["pena_vidro"], "equipped lista só os ids")
	# As opções do botão Trocar: o vazio e o que o slot aceita; a pena bloqueada fica de fora, com o motivo.
	var found := AHRelics.options(c, bento, 1)
	t.equal(found[0], [""], "o slot 1 do Bento só aceita o vazio")
	t.equal(found[1], {"pena_vidro": "Já equipada no outro slot."}, "e diz por que a pena não serve")


## Trocar e desequipar: nada se perde, nada se duplica, e o bônus sai junto.
func _swap() -> void:
	var c := _campaign()
	c.inventory.relics = ["botao_cobre", "pena_vidro", "coleira_lembranca"]
	var before := _total_items(c)
	var bento: Dictionary = S.hero(c, "hero_cao_bento")
	t.equal(AHRelics.equip(c, "hero_cao_bento", 0, "botao_cobre"), "", "o Botão no slot 0")
	t.equal(AHRelics.equip(c, "hero_cao_bento", 1, "pena_vidro"), "", "a Pena no slot 1")
	t.equal([AHRelics.max_hp_bonus(bento), AHRelics.speed_bonus(bento)], [3, 1], "os dois bônus somam")
	t.equal(c.inventory.relics, ["coleira_lembranca"], "as duas saíram do estoque")
	t.equal(AHRelics.equip(c, "hero_cao_bento", 0, "coleira_lembranca"), "", "troca o Botão pela Coleira")
	t.equal(bento.relics, ["coleira_lembranca", "pena_vidro"], "a Coleira no slot 0")
	t.equal(c.inventory.relics, ["botao_cobre"], "o Botão voltou ao estoque")
	t.equal([AHRelics.max_hp_bonus(bento), AHRelics.speed_bonus(bento), AHRelics.event_instinct_reduction(bento)], [0, 1, 2], "sem a vida do Botão, com o Instinto da Coleira")
	t.equal(_total_items(c), before, "nada perdido nem duplicado na troca")
	t.equal(AHRelics.equip(c, "hero_cao_bento", 1, ""), "", "desequipa o slot 1")
	t.equal(AHRelics.equip(c, "hero_cao_bento", 1, ""), "O slot já está vazio.", "o vazio de novo não faz nada")
	t.equal(AHRelics.equip(c, "hero_cao_bento", 0, ""), "", "desequipa o slot 0")
	t.equal(bento.relics, ["", ""], "os dois vazios")
	t.equal([AHRelics.max_hp_bonus(bento), AHRelics.speed_bonus(bento), AHRelics.event_instinct_reduction(bento), AHRelics.virtue_bonus(bento)], [0, 0, 0, 0.0], "sem bônus residual")
	t.equal(_total_items(c), before, "tudo de volta ao estoque")
	S.hero(c, "hero_gato_nick").alive = false
	c.inventory.relics.append("pena_vidro")
	t.equal(AHRelics.equip(c, "hero_gato_nick", 0, "pena_vidro"), "Só animais vivos usam relíquias.", "quem não está vivo não equipa")


## A Forja: só as comuns de origem forge.
func _forge() -> void:
	var c := _campaign()
	c.station.rooms[S.FORGE] = 1
	c.inventory.scrap = 30
	t.equal(S.craft_relic(c, "semente_guardada"), "", "a Semente no Bolso sai da Forja")
	t.equal(S.craft_relic(c, "coleira_lembranca"), "A Forja não fabrica essa relíquia.", "a incomum, não")
	t.equal(S.craft_relic(c, "sino_vitrine"), "A Forja não fabrica essa relíquia.", "nem a da carga")
	t.equal(c.inventory.relics, ["semente_guardada"], "só a comum entrou no estoque")
	t.equal(S.quantity(c, "scrap"), 30 - S.relic_cost(c), "e só ela custou sucata")


func _inject() -> void:
	for relic_id in TEST_ROWS:
		GameData.tables.relics[relic_id] = TEST_ROWS[relic_id].duplicate(true)
		GameData.combat.relics[relic_id] = AHGameData._merge(AHGameData.RELIC, TEST_ROWS[relic_id])


func _remove() -> void:
	for relic_id in TEST_ROWS:
		GameData.tables.relics.erase(relic_id)
		GameData.combat.relics.erase(relic_id)
	t.check(not GameData.table("relics").has("teste_vel2") and not GameData.combat.relics.has("teste_vel2"), "as linhas de teste saem da tabela")


## O teto de +2 de Velocidade vindo das relíquias; o que tira velocidade não tem piso.
func _cap() -> void:
	var c := _campaign()
	c.inventory.relics = ["teste_vel2", "pena_vidro", "raiz_trancada", "sino_vitrine"]
	var bento: Dictionary = S.hero(c, "hero_cao_bento")
	AHRelics.equip(c, "hero_cao_bento", 0, "teste_vel2")
	AHRelics.equip(c, "hero_cao_bento", 1, "pena_vidro")
	t.equal(AHRelics.speed_bonus(bento), AHRelics.SPEED_CAP, "+2 e +1 dão o teto de +2")
	AHRelics.equip(c, "hero_cao_bento", 1, "raiz_trancada")
	t.equal([AHRelics.speed_bonus(bento), AHRelics.max_hp_bonus(bento)], [1, 4], "+2 e -1 dão +1, com a vida da Raiz")
	AHRelics.equip(c, "hero_cao_bento", 0, "sino_vitrine")
	t.equal([AHRelics.speed_bonus(bento), AHRelics.max_hp_bonus(bento)], [0, 2], "o Sininho e a Raiz: +1 -1 de Vel. e -2 +4 de vida")
	t.equal(AHRelics.totals(["pena_vidro", "pena_vidro"], GameData.table("relics")).speed, 1, "a mesma relíquia conta uma vez")


## As restrições por papel e por fundador, com os textos.
func _restrictions() -> void:
	var c := _campaign()
	c.inventory.relics = ["teste_papel", "teste_pessoal"]
	var bento: Dictionary = S.hero(c, "hero_cao_bento")
	var role := AHSpecies.role("sapo")
	t.check(role != "", "o papel do sapo tem nome")
	t.equal(AHRelics.block(c, bento, 0, "teste_papel"), "Só para %s." % role, "a do papel do sapo, no cão")
	t.equal(AHRelics.equip(c, "hero_cao_bento", 0, "teste_papel"), "Só para %s." % role, "é recusada com o papel")
	t.equal(AHRelics.equip(c, "hero_sapo_iris", 0, "teste_papel"), "", "e serve no sapo")
	var nick_name := String(S.hero(c, "hero_gato_nick").display_name)
	t.equal(AHRelics.equip(c, "hero_cao_bento", 1, "teste_pessoal"), "Só %s usa." % nick_name, "a pessoal do Nick, no Bento, diz quem usa")
	t.equal(AHRelics.equip(c, "hero_gato_nick", 1, "teste_pessoal"), "", "e serve no Nick")
	t.equal(c.inventory.relics, [], "as duas saíram do estoque")
	t.equal(bento.relics, ["", ""], "e o Bento continua sem nada")


## Os sorteios: só comum e incomum, cada um com a sua origem, e a Phase só na carga daquela fase.
func _draws() -> void:
	for source in ["cargo", "dig", "forge"]:
		t.check(not AHRelics.pool(source, "fase_3").any(func(id): return NEVER.has(id)), "%s: nunca rara, pessoal ou lembrança" % source)
	t.check(AHRelics.pool("cargo", "fase_3").has("teste_fase") and not AHRelics.pool("cargo", "fase_1").has("teste_fase"), "a de fase só na fase dela")
	t.check(not AHRelics.forgeable().any(func(id): return NEVER.has(id) or id == "teste_papel"), "a Forja não fabrica a rara, a pessoal, a lembrança nem a sem forge")
	var c := _campaign()
	c.station.rooms[S.FORGE] = 1
	c.inventory.scrap = 30
	t.equal(S.craft_relic(c, "teste_rara"), "A Forja não fabrica essa relíquia.", "craft_relic recusa a rara mesmo com forge")
	# A carga recuperada: muitas expedições, cada fase.
	var cargo_seen := {}
	var cargo_ok := true
	for phase_id in ["fase_1", "fase_2", "fase_3"]:
		var allowed := AHRelics.pool("cargo", phase_id)
		for i in 400:
			var expedition := {"phase_id": phase_id, "seed": i, "id": "exp_relic_%d" % i}
			for box in AHFightRewards._draw(c, expedition):
				if box.kind == "relic":
					cargo_seen["%s:%s" % [phase_id, box.relic_id]] = true
					cargo_ok = cargo_ok and allowed.has(String(box.relic_id))
	t.check(cargo_ok, "a carga só sorteia as de cargo, comuns ou incomuns, e as de fase na fase delas")
	t.check(cargo_seen.has("fase_1:sino_vitrine") and cargo_seen.has("fase_2:raiz_trancada") and cargo_seen.has("fase_3:teste_fase"), "e cada uma de fase cai na fase dela: %s" % ", ".join(cargo_seen.keys()))
	t.check(not cargo_seen.has("fase_1:raiz_trancada") and not cargo_seen.has("fase_2:sino_vitrine"), "e não na outra")
	# A escavação: só as de dig que a equipe não tem.
	var dig_ok := true
	var dig_any := false
	for i in 400:
		var d := _campaign()
		var f: Dictionary = G._find(d, "exp_dig_%d" % i, "3:7")
		if f.relic != "":
			dig_any = true
			dig_ok = dig_ok and AHRelics.pool("dig").has(f.relic) and not NEVER.has(f.relic)
	t.check(dig_any and dig_ok, "a escavação só dá as de dig")
	var full := _campaign()
	full.inventory.relics = ["botao_cobre", "pena_vidro", "coleira_lembranca"]
	S.hero(full, "hero_cao_bento").relics = ["teste_vel2", ""]
	t.equal(G._new_relics(full), [], "com as de dig no estoque ou equipadas (nos dois slots), nada novo para escavar")
	# A missão solo: só as de cargo sem fase.
	var solo_ok := true
	var solo_any := false
	var allowed_solo := AHRelics.pool("cargo")
	for i in 600:
		var s := _campaign()
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var reward: Dictionary = M._reward(s, {"Reward": "seeds", "RelicChance": 1}, rng, false)
		if String(reward.relic_id) != "":
			solo_any = true
			solo_ok = solo_ok and allowed_solo.has(String(reward.relic_id))
	t.check(solo_any and solo_ok, "a missão solo só dá as de cargo, sem as de fase")


## O bônus na unidade de combate: os dois slots somam, com o teto, e o RelicId antigo ainda vale.
func _combat() -> void:
	var base := {"Id": "hero_cao_bento", "ClassId": "cao", "DisplayName": "Bento", "MaxHp": 30, "Hp": 30}
	var speed := int(GameData.combat.classes.cao.BaseSpeed)
	var plain := AHCombatEngine.make_hero_unit(base, 1, GameData.combat)
	t.equal([plain.max_hp, plain.speed], [30, speed], "sem relíquia, a vida e a velocidade da classe")
	var two: Dictionary = base.duplicate()
	two.RelicIds = ["botao_cobre", "pena_vidro"]
	var unit := AHCombatEngine.make_hero_unit(two, 1, GameData.combat)
	t.equal([unit.max_hp, unit.speed], [33, speed + 1], "o Botão e a Pena somam na luta")
	two.RelicIds = ["teste_vel2", "pena_vidro"]
	t.equal(AHCombatEngine.make_hero_unit(two, 1, GameData.combat).speed, speed + 2, "com o teto de +2 de Velocidade")
	two.RelicIds = ["semente_guardada", ""]
	t.check(absf(AHCombatEngine.make_hero_unit(two, 1, GameData.combat).virtue_bonus - 0.05) < 0.001, "a Semente no Bolso dá +5 pp de Superação")
	var old: Dictionary = base.duplicate()
	old.RelicId = "botao_cobre"
	t.equal(AHCombatEngine.make_hero_unit(old, 1, GameData.combat).max_hp, 33, "o RelicId antigo ainda vale")
	# A sessão de combate leva os dois slots do herói da campanha.
	var c := _campaign()
	var bento: Dictionary = S.hero(c, "hero_cao_bento")
	var without := AHCombatSession.create(c.roster, PATROL, false, 5).state.find_unit("unit_hero_cao_bento")
	bento.relics = ["botao_cobre", "pena_vidro"]
	var equipped_unit := AHCombatSession.create(c.roster, PATROL, false, 5).state.find_unit("unit_hero_cao_bento")
	t.equal([equipped_unit.max_hp - without.max_hp, equipped_unit.speed - without.speed], [3, 1], "a sessão manda os dois slots (RelicIds)")
	# A Superação na crise: a chance soma o bônus da relíquia.
	var session := AHCombatSession.create(c.roster, PATROL, false, 5)
	var chance: float = session.engine._virtue_chance([])
	t.check(absf(session.engine._virtue_chance([], 0.05) - chance - 0.05) < 0.001, "o VirtueBonus soma na chance de Superação")
