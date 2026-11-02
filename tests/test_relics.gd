## AHRelics (#263): os dois slots por herói, a migração do relic_id antigo, os bloqueios (o mesmo id, o papel e o
## fundador), o total dos bônus com o teto de Velocidade, de onde cada relíquia sai (os sorteios e a Forja) e o bônus
## somado na unidade de combate.
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const G = preload("res://scripts/flow/station_grid.gd")
const M = preload("res://scripts/flow/side_mission_rules.gd")
const J = preload("res://scripts/flow/journey_rules.gd")
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
## A carga sem fase (#263, parte 2): as de antes e as quatro de papel.
const CARGO := ["botao_cobre", "coleira_lembranca", "gancho_telhado", "mira_torre", "pena_vidro", "placa_laranja", "rolha_cisterna"]
## As 13 da parte 2: [id, raridade, Only, origens].
const PART2 := [
	["plaqueta_patrulha", "uncommon", "role:cao", ["dig", "merchant"]],
	["gancho_telhado", "uncommon", "role:gato", ["cargo"]],
	["rolha_cisterna", "uncommon", "role:sapo", ["cargo"]],
	["mira_torre", "uncommon", "role:coruja", ["cargo"]],
	["pilha_remendada", "uncommon", "role:rato", ["dig"]],
	["placa_laranja", "uncommon", "role:tatu", ["cargo"]],
	["luva_sucata", "personal", "hero:hero_cao_bento", ["solo"]],
	["fivela_mochila", "personal", "hero:hero_gato_nick", ["solo"]],
	["caderno_medidas", "personal", "hero:hero_sapo_iris", ["solo"]],
	["luneta_torre", "personal", "hero:hero_coruja_vespera", ["solo"]],
	["cartao_eclusa", "rare", "", ["guardian"]],
	["coleira_nome", "keepsake", "", ["story"]],
	["colar_circuito", "keepsake", "hero:hero_cao_bento", ["story"]],
]
const COLAR_TEXT := "Um pingente feito à mão com uma peça de terminal dos Antigos. Bento guarda no bolso e não diz de quem é."

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
	# A parte 2: o catálogo, os sorteios, os gatilhos da luta e as origens especiais.
	_catalog()
	_real_restrictions()
	_never_drawn()
	_triggers()
	_guardian()
	_solo()
	_merchant()
	_coleira()
	_story_again()
	await _defeat_and_retreat()


static func _sorted(ids: Array) -> Array:
	var out := ids.duplicate()
	out.sort()
	return out


func _data() -> void:
	t.check(GameData.issues.is_empty(), "as tabelas validam (raridade, origens, papel e fase): %s" % ", ".join(GameData.issues))
	for relic_id in ["botao_cobre", "pena_vidro", "coleira_lembranca", "semente_guardada", "sino_vitrine", "raiz_trancada"]:
		t.check(GameData.row("relics", relic_id) != null, "%s na tabela" % relic_id)
	t.equal(AHRelics.rarity("botao_cobre"), "common", "o Botão de Cobre é comum")
	t.equal(AHRelics.rarity("coleira_lembranca"), "uncommon", "a Coleira de Lembrança é incomum")
	t.equal(AHRelics.forgeable(), ["botao_cobre", "pena_vidro", "semente_guardada"], "a Forja fabrica as comuns de origem forge")
	t.equal(AHRelics.pool("dig"), ["botao_cobre", "coleira_lembranca", "pena_vidro", "pilha_remendada", "plaqueta_patrulha"], "a escavação só tem as de dig")
	t.equal(AHRelics.pool("cargo"), CARGO, "a carga sem fase não tem as de fase")
	t.equal(AHRelics.pool("cargo", "fase_1"), _sorted(CARGO + ["sino_vitrine"]), "o Sininho só na carga da fase 1")
	t.equal(AHRelics.pool("cargo", "fase_2"), _sorted(CARGO + ["raiz_trancada"]), "a Raiz Trançada só na carga da fase 2")
	t.equal(AHRelics.pool("merchant"), ["plaqueta_patrulha"], "o Mercador só tem a Plaqueta")


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
	# Um save editado com mais slots que dois, ou a mesma relíquia repetida: o excesso e a cópia voltam ao estoque.
	c.inventory.relics = []
	bento.relics = ["botao_cobre", "pena_vidro", "coleira_lembranca"]
	S.migrate(c)
	t.equal([bento.relics, c.inventory.relics], [["botao_cobre", "pena_vidro"], ["coleira_lembranca"]], "a terceira volta ao estoque")
	c.inventory.relics = []
	bento.relics = ["pena_vidro", "pena_vidro"]
	S.migrate(c)
	t.equal([bento.relics, c.inventory.relics], [["pena_vidro", ""], ["pena_vidro"]], "a cópia repetida volta ao estoque")
	c.inventory.relics = []
	bento.relics = ["botao_cobre", "", null, "pena_vidro"]
	S.migrate(c)
	t.equal([bento.relics, c.inventory.relics], [["botao_cobre", ""], ["pena_vidro"]], "um null no excesso não para a migração")
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
	# Um id fora da tabela no estoque (de um save antigo) não prende o ciclo: fica bloqueado, e a válida depois dele entra.
	c.inventory.relics = ["fora_da_tabela", "botao_cobre"]
	found = AHRelics.options(c, bento, 1)
	t.equal(found[0], ["", "botao_cobre"], "o id desconhecido fica fora das opções")
	t.equal(found[1], {"fora_da_tabela": "Relíquia desconhecida."}, "com o motivo")


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
	full.inventory.relics = ["botao_cobre", "pena_vidro", "coleira_lembranca", "pilha_remendada", "plaqueta_patrulha"]
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
	two.RelicIds = ["sino_vitrine", ""]
	var bell := AHCombatEngine.make_hero_unit(two, 1, GameData.combat)
	t.equal([bell.max_hp, bell.hp], [28, 28], "com o Sininho e a vida cheia, a vida desce junto com o máximo")
	var hurt: Dictionary = two.duplicate()
	hurt.Hp = 10
	t.equal(AHCombatEngine.make_hero_unit(hurt, 1, GameData.combat).hp, 10, "e quem está ferido fica com a vida que tem")
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



# ================================================================ a parte 2

## As 13 relíquias novas, com a raridade, a restrição e as origens do desenho; o texto do colar, sem nome.
func _catalog() -> void:
	for spec in PART2:
		var row = GameData.row("relics", spec[0])
		if not t.check(row != null, "%s na tabela" % spec[0]):
			continue
		t.equal([AHRelics.rarity(spec[0]), String(row.get("Only", "")), Array(row.get("Sources", []))], [spec[1], spec[2], spec[3]],
			"%s: raridade, quem usa e de onde sai" % spec[0])
		t.check(String(row.get("Description", "")) != "", "%s tem texto" % spec[0])
	var colar: Dictionary = GameData.row("relics", "colar_circuito")
	t.equal([String(colar.DisplayName), String(colar.Description)], ["Colar de Circuito", COLAR_TEXT], "o colar: só o nome genérico e o texto do desenho")
	t.check(not JSON.stringify(colar).contains("Théo"), "nada no colar cita o irmão")
	t.equal(AHRelics.text("colar_circuito"), "%s %s" % [String(colar.Effect), COLAR_TEXT], "a tela mostra o efeito antes do texto")
	t.equal(AHRelics.text("botao_cobre"), String(GameData.row("relics", "botao_cobre").Description), "sem Effect, a descrição de sempre")
	t.equal([AHRelics.rarity_name("cartao_eclusa"), AHRelics.rarity_name("luva_sucata"), AHRelics.rarity_name("coleira_nome")], ["Rara", "Pessoal", "Lembrança"],
		"o nome de cada raridade")
	t.check(AHRelics.has_cost("gancho_telhado") and AHRelics.has_cost("fivela_mochila") and not AHRelics.has_cost("luva_sucata"), "o custo na ficha")
	# Os ids de habilidade do "+N" existem e são da classe certa.
	for relic_id in GameData.table("relics"):
		var ability := String(GameData.row("relics", relic_id).get("Ability", ""))
		if ability != "":
			t.check(GameData.combat.abilities.has(ability), "%s: a habilidade %s existe" % [relic_id, ability])


## As restrições das relíquias reais: o papel e o fundador de cada uma.
func _real_restrictions() -> void:
	var c := _campaign()
	var heroes := {}
	for class_id in ["cao", "gato", "sapo", "coruja", "rato", "tatu"]:
		heroes[class_id] = {"id": "hero_%s_9" % class_id, "class_id": class_id, "alive": true, "relics": ["", ""]}
	for spec in PART2:
		var only: String = spec[2]
		if only.begins_with("role:"):
			var role := only.trim_prefix("role:")
			for class_id in heroes:
				var why := AHRelics.block(c, heroes[class_id], 0, spec[0])
				t.check((why == "") == (class_id == role), "%s no %s: %s" % [spec[0], class_id, why if why != "" else "aceita"])
		elif only.begins_with("hero:"):
			var owner := only.trim_prefix("hero:")
			for founder in c.roster:
				var why := AHRelics.block(c, founder, 0, spec[0])
				t.check((why == "") == (String(founder.id) == owner), "%s no %s: %s" % [spec[0], founder.id, why if why != "" else "aceita"])
			# O recruta da mesma classe também não usa: é do fundador.
			var recruit := {"id": "hero_x_7", "class_id": String(S.hero(c, owner).class_id), "alive": true}
			t.check(AHRelics.block(c, recruit, 0, spec[0]) != "", "%s: o recruta da mesma classe não usa" % spec[0])
		else:
			for founder in c.roster:
				t.equal(AHRelics.block(c, founder, 0, spec[0]), "", "%s serve em %s" % [spec[0], founder.id])
	# Pela troca de verdade: a Luva no Nick é recusada com o nome do Bento; no Bento, entra.
	c.inventory.relics = ["luva_sucata"]
	t.equal(AHRelics.equip(c, "hero_gato_nick", 0, "luva_sucata"), "Só %s usa." % String(S.hero(c, "hero_cao_bento").display_name), "a Luva no Nick")
	t.equal(AHRelics.equip(c, "hero_cao_bento", 0, "luva_sucata"), "", "e no Bento")


## O sorteio comum (a carga, a escavação, a missão solo, a Forja, o Mercador) nunca escolhe rara, pessoal ou lembrança,
## nem uma fora das Sources dela.
func _never_drawn() -> void:
	var phases: Array = [""] + AHJourneyRules.PHASES.map(func(p): return String(p.id))
	for source in ["cargo", "dig", "forge", "merchant", "solo"]:
		for phase_id in phases:
			var found := AHRelics.pool(source, phase_id)
			t.check(found.all(func(id): return AHRelics.DRAWABLE.has(AHRelics.rarity(id)) and AHRelics.has_source(id, source)),
				"%s %s: só comuns e incomuns da origem (%s)" % [source, phase_id, found])
	t.equal(AHRelics.pool("solo"), [], "nenhuma de missão solo cai por sorteio (são pessoais)")
	t.equal(AHRelics.pool("guardian"), [], "nem a do guardião")
	t.equal(AHRelics.pool("story"), [], "nem as de história")
	t.check(not AHRelics.pool("cargo").has("pilha_remendada") and not AHRelics.pool("dig").has("gancho_telhado"), "a de papel só na origem dela")
	# A carga e a missão solo de verdade, muitas vezes: nenhuma especial.
	var special := ["luva_sucata", "fivela_mochila", "caderno_medidas", "luneta_torre", "cartao_eclusa", "coleira_nome", "colar_circuito"]
	var c := _campaign()
	var bad := []
	for phase_id in phases.slice(1):
		for i in 300:
			for box in AHFightRewards._draw(c, {"phase_id": phase_id, "seed": i, "id": "exp_p2_%d" % i}):
				if box.kind == "relic" and special.has(String(box.relic_id)):
					bad.append(box.relic_id)
	for i in 400:
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var reward: Dictionary = M._reward(_campaign(), {"Reward": "seeds", "RelicChance": 1}, rng, false)
		if special.has(String(reward.relic_id)):
			bad.append(reward.relic_id)
		var d := _campaign()
		var f: Dictionary = G._find(d, "exp_dig_p2_%d" % i, "3:7")
		if special.has(String(f.relic)):
			bad.append(f.relic)
	t.equal(bad, [], "a carga, a missão solo e a escavação nunca dão uma especial")


func _hero(id: String, class_id: String, relics: Array, extra: Dictionary = {}) -> Dictionary:
	var out := {"Id": id, "ClassId": class_id, "DisplayName": id, "MaxHp": 30, "Hp": 30, "Instinct": 50, "RelicIds": relics}
	out.merge(extra, true)
	return out


## Uma luta direto no motor, contra dois robôs, com a mesma semente: com e sem a relíquia, o mesmo sorteio.
func _engine(heroes: Array, seed_value: int = 11) -> AHCombatEngine:
	var units: Array = []
	for i in heroes.size():
		units.append(AHCombatEngine.make_hero_unit(heroes[i], i + 1, GameData.combat))
	var enemies := [AHCombatEngine.make_enemy_unit("robot", "enemy_a", 1, GameData.combat),
		AHCombatEngine.make_enemy_unit("robot", "enemy_b", 2, GameData.combat)]
	var random := AHCombatRandom.new(seed_value)
	var context := AHCombat.Context.new()
	var state := AHCombatEngine.init_combat(units, enemies, context, GameData.combat, random, false)
	return AHCombatEngine.new(state, context, GameData.combat, random)


static func _damage(result: AHCombat.ActionResult) -> int:
	var total := 0
	for event in result.events:
		if event.type == AHCombat.EventType.DAMAGE:
			total += event.amount
	return total


## Cada gatilho novo da luta, com e sem a relíquia, na mesma semente.
func _triggers() -> void:
	# No início da luta: a Esquiva do Gancho e o Bloqueio da Placa, também pela sessão de verdade.
	var hook := AHCombatEngine.make_hero_unit(_hero("hero_gato_nick", "gato", ["gancho_telhado"]), 1, GameData.combat)
	t.equal([hook.tokens.dodge, hook.max_hp], [1, 28], "o Gancho: 1 Esquiva no início e -2 de Vida Máxima")
	var plate := AHCombatEngine.make_hero_unit(_hero("hero_tatu_9", "tatu", ["placa_laranja"]), 1, GameData.combat)
	t.equal([plate.tokens.block, plate.speed], [1, int(GameData.combat.classes.tatu.BaseSpeed) - 1], "a Placa: 1 Bloqueio no início e -1 de Velocidade")
	var c := _campaign()
	S.hero(c, "hero_gato_nick").relics = ["gancho_telhado", ""]
	S.hero(c, "hero_cao_bento").relics = ["placa_laranja", ""]
	var session := AHCombatSession.create(c.roster, PATROL, false, 5, 80, ["preparado"])
	var nick := session.state.find_unit("unit_hero_gato_nick")
	var bento := session.state.find_unit("unit_hero_cao_bento")
	t.equal([nick.tokens.dodge, bento.tokens.block], [1, 2], "na sessão: a Esquiva do Gancho, e o Bloqueio da Placa soma com o Preparado")
	var plain := AHCombatSession.create(_campaign().roster, PATROL, false, 5).state.find_unit("unit_hero_gato_nick")
	t.equal(plain.tokens.dodge, 0, "sem a relíquia, nenhuma ficha")
	# +1 de Velocidade só na primeira rodada (a Luneta da Torre), no mesmo sorteio.
	var base := _engine([_hero("hero_coruja_vespera", "coruja", [])], 21)
	var scope := _engine([_hero("hero_coruja_vespera", "coruja", ["luneta_torre"])], 21)
	var initiative := func(engine: AHCombatEngine) -> int:
		for item in engine.state.initiative_queue:
			if item.unit_id == "unit_hero_coruja_vespera":
				return item.initiative
		return -99
	t.equal(initiative.call(scope) - initiative.call(base), 1, "a Luneta: +1 na iniciativa da primeira rodada")
	t.equal(scope.state.find_unit("unit_hero_coruja_vespera").speed, base.state.find_unit("unit_hero_coruja_vespera").speed, "e a Velocidade de sempre igual")
	for engine in [base, scope]:
		engine.state.round = 2
		engine._roll_initiative_for_round()
	t.equal(initiative.call(scope) - initiative.call(base), 0, "na segunda rodada, nada a mais")
	t.equal(AHRelics.totals(["luneta_torre", "pena_vidro", "sino_vitrine"], GameData.combat.relics).first_turn_speed, 0, "dentro do teto de +2 com as outras (+1 e +1)")
	# +1 carga da Ampola (a Rolha) e +1 uso do Antídoto (o Caderno).
	var iris := _engine([_hero("hero_sapo_iris", "sapo", ["rolha_cisterna", "caderno_medidas"])]).state.find_unit("unit_hero_sapo_iris")
	var ampoule: int = GameData.combat.abilities.sapo_ampola_reparo_vivo.UsesMax
	var antidote: int = GameData.combat.abilities.sapo_antidoto_campo.UsesMax
	t.equal([iris.remaining_uses.sapo_ampola_reparo_vivo, iris.remaining_uses.sapo_antidoto_campo], [ampoule + 1, antidote + 1], "a Rolha e o Caderno: +1 carga e +1 uso")
	var spent := _engine([_hero("hero_sapo_iris", "sapo", ["rolha_cisterna"], {"ExpeditionUses": {"sapo_ampola_reparo_vivo": 1}})]).state.find_unit("unit_hero_sapo_iris")
	t.equal(spent.remaining_uses.sapo_ampola_reparo_vivo, 1, "as cargas gastas na expedição continuam gastas")
	var d := _campaign()
	J.start_expedition(d, "fase_1", 2631)
	var iris_hero: Dictionary = S.hero(d, "hero_sapo_iris")
	iris_hero.relics = ["rolha_cisterna", ""]
	if d.session.expedition.team.has("hero_sapo_iris"):
		t.equal(AHExplorationCare.ampoule_charges(d), ampoule + 1, "fora da luta, a Ampola também tem a carga a mais")
	# "Punho de Sucata" tira 2 Bloqueios (a Luva).
	var punch := func(relics: Array) -> int:
		var engine := _engine([_hero("hero_cao_bento", "cao", relics)])
		engine.state.enemy_team[0].tokens.block = 3
		engine.execute_player_ability("unit_hero_cao_bento", "cao_punho_sucata", 1)
		return engine.state.enemy_team[0].tokens.block
	t.equal(punch.call([]) - punch.call(["luva_sucata"]), 1, "a Luva: o Punho de Sucata tira um Bloqueio a mais")
	# "Fique Atrás de Mim": +1 Bloqueio (o Colar) e -5 de Instinto próprio (a Plaqueta).
	var guard := func(relics: Array) -> AHCombat.Unit:
		var engine := _engine([_hero("hero_cao_bento", "cao", relics), _hero("hero_gato_nick", "gato", [])])
		engine.execute_player_ability("unit_hero_cao_bento", "cao_fique_atras_de_mim", 2)
		return engine.state.find_unit("unit_hero_cao_bento")
	var plain_guard: AHCombat.Unit = guard.call([])
	var collar_guard: AHCombat.Unit = guard.call(["colar_circuito"])
	var tag_guard: AHCombat.Unit = guard.call(["plaqueta_patrulha"])
	t.equal([collar_guard.tokens.block - plain_guard.tokens.block, collar_guard.instinct - plain_guard.instinct], [1, 0], "o Colar: +1 Bloqueio no Fique Atrás de Mim")
	t.equal([tag_guard.instinct - plain_guard.instinct, tag_guard.tokens.block - plain_guard.tokens.block], [-5, 0], "a Plaqueta: -5 de Instinto no próprio cão")
	# "Olho nas Ruínas" dura +1 turno (a Mira).
	var mark := func(relics: Array) -> int:
		var engine := _engine([_hero("hero_cao_bento", "cao", []), _hero("hero_coruja_vespera", "coruja", relics)])
		engine.execute_player_ability("unit_hero_coruja_vespera", "coruja_olho_nas_ruinas", 1)
		return engine.state.enemy_team[0].mark_duration
	t.equal([mark.call([]), mark.call(["mira_torre"])], [2, 3], "a Mira: a Marca dura 3 turnos em vez de 2")
	# Carga de Eletrólito +1 de dano (a Pilha).
	var bolt := func(relics: Array) -> int:
		var engine := _engine([_hero("hero_cao_bento", "cao", []), _hero("hero_gato_nick", "gato", []), _hero("hero_rato_9", "rato", relics)])
		return _damage(engine.execute_player_ability("unit_hero_rato_9", "rato_frasco", 1))
	var bolt_plain: int = bolt.call([])
	var bolt_cell: int = bolt.call(["pilha_remendada"])
	t.check(bolt_plain > 0 and bolt_cell >= bolt_plain + 1, "a Pilha: +1 de dano na Carga de Eletrólito (%d → %d)" % [bolt_plain, bolt_cell])
	# +25% de dano em máquinas (o Cartão da Eclusa).
	var card := func(relics: Array) -> int:
		return _damage(_engine([_hero("hero_cao_bento", "cao", relics)]).execute_player_ability("unit_hero_cao_bento", "cao_punho_sucata", 1))
	var card_plain: int = card.call([])
	var card_on: int = card.call(["cartao_eclusa"])
	t.equal(card_on, AHCombatEngine.typed_damage(card_plain, 1.25), "o Cartão: +25%% contra a máquina (%d → %d)" % [card_plain, card_on])
	t.check(_engine([_hero("hero_cao_bento", "cao", [])]).is_mech_family(_engine([_hero("hero_cao_bento", "cao", [])]).state.enemy_team[0]), "o robô é da família mecânica")
	# +3 de Instinto quando um aliado cai (o Colar).
	var fall := func(relics: Array) -> int:
		var engine := _engine([_hero("hero_cao_bento", "cao", relics, {"Instinct": 10}), _hero("hero_gato_nick", "gato", [], {"Hp": 2})])
		engine._apply_damage(engine.state.find_unit("unit_hero_gato_nick"), 10, false, [], "teste")
		return engine.state.find_unit("unit_hero_cao_bento").instinct
	t.equal([fall.call([]), fall.call(["colar_circuito"])], [18, 21], "o Colar: +3 de Instinto a mais quando um aliado cai")


## A rara do guardião: o Porteiro da fase 5 dá o Cartão da Eclusa na vitória, uma vez por campanha.
func _guardian() -> void:
	var c := _campaign()
	var expedition := _at_boss(c, "fase_5", 2635)
	t.check(J.guardian_ids(expedition).has("porteiro"), "o guardião da fase 5 é o Porteiro")
	t.equal(String(J.combat_loot(c, "victory", true).get("relic", "")), "cartao_eclusa", "o popup mostra o Cartão antes de a luta fechar")
	J.end_combat(c, "victory", true)
	t.equal(c.inventory.relics, ["cartao_eclusa"], "a vitória sobre o Porteiro dá o Cartão")
	t.check(AHRelics.given(c).has("cartao_eclusa") and expedition.found_relics.has("cartao_eclusa"), "anotado na campanha e no achado da expedição")
	_at_boss(c, "fase_5", 2636)
	t.check(not J.combat_loot(c, "victory", true).has("relic"), "na segunda vez, o popup não promete nada")
	J.end_combat(c, "victory", true)
	t.equal(c.inventory.relics.count("cartao_eclusa"), 1, "e não dá de novo")
	# O guardião de outra fase não dá raridade nenhuma.
	var other := _campaign()
	_at_boss(other, "fase_1", 2637)
	J.end_combat(other, "victory", true)
	t.equal(other.inventory.relics, [], "o guardião da fase 1 não dá o Cartão")


## Uma expedição parada na luta do guardião.
func _at_boss(c: Dictionary, phase_id: String, seed_value: int) -> Dictionary:
	c.session = {"screen": "shelter", "result": "", "expedition": null, "event": null}
	J.start_expedition(c, phase_id, seed_value)
	var route: Dictionary = c.session.expedition.corridor
	for step in route.steps:
		step.resolved = step.type != "boss"
	route.index = route.steps.size() - 1
	return c.session.expedition


## A missão solo do fundador dá a pessoal dele, uma vez; o recruta não ganha nada.
func _solo() -> void:
	var done := false
	for i in 200:
		var c := _campaign()
		M.state(c).seed = i
		var bento: Dictionary = S.hero(c, "hero_cao_bento")
		bento.side_mission = {"id": "fresta_galerias", "spot": 0, "sent": 0, "back": 0}
		var report: Dictionary = M._resolve(c, bento)
		if report.result != "success":
			continue
		done = true
		t.equal(String(report.reward.personal_id), "luva_sucata", "a primeira missão cumprida do Bento dá a Luva")
		t.check(c.inventory.relics.has("luva_sucata") and AHRelics.given(c).has("luva_sucata"), "no estoque, e anotada")
		t.check(M.report_line(c, report).contains("Luva de Sucata"), "o relatório diz: %s" % M.report_line(c, report))
		t.equal(AHRelics.solo_personal(c, "hero_cao_bento"), "", "na segunda, nada")
		t.equal(AHRelics.solo_personal(c, "hero_gato_nick"), "fivela_mochila", "a do Nick é a Fivela")
		t.equal([AHRelics.solo_personal(c, "hero_sapo_iris"), AHRelics.solo_personal(c, "hero_coruja_vespera")], ["caderno_medidas", "luneta_torre"],
			"a da Íris e a da Véspera")
		t.equal(AHRelics.solo_personal(c, "hero_cao_4"), "", "o recruta não tem pessoal")
		break
	t.check(done, "uma missão solo do Bento deu certo")


## O Mercador: uma Incomum por visita (a Plaqueta), pelo preço da tabela.
func _merchant() -> void:
	var c := _campaign()
	S.train_on_return(c, "relic-merchant-%d" % Time.get_ticks_usec(), "merchant")
	t.check(S.merchant_here(c), "o Mercador está na plataforma")
	var row: Dictionary = GameData.row("merchant", "buy_relic")
	t.equal([String(row.Give), String(row.Get), int(row.Limit)], ["seeds", "relic", 1], "a troca: sementes por uma relíquia, uma por visita")
	t.equal(AHRelics.merchant_offer(c), "plaqueta_patrulha", "ele traz a Plaqueta, a única Incomum de origem merchant")
	t.equal(S.trade_get_text(c, row), "Plaqueta de Patrulha", "a troca mostra o nome")
	c.inventory.seeds = int(row.GiveAmount) * 2
	t.equal(S.merchant_trade(c, "buy_relic"), "", "a compra sai")
	t.equal([c.inventory.relics, S.quantity(c, "seeds")], [["plaqueta_patrulha"], int(row.GiveAmount)], "a Plaqueta no estoque, pelo preço")
	t.check(S.merchant_trade(c, "buy_relic") != "" and c.inventory.relics.size() == 1, "uma por visita")
	var poor := _campaign()
	S.train_on_return(poor, "relic-poor-%d" % Time.get_ticks_usec(), "merchant")
	poor.inventory.seeds = 1
	t.check(S.trade_block(poor, "buy_relic") != "", "sem sementes, não sai")
	t.check(S.trade_block(_campaign(), "buy_relic") != "", "sem o Mercador, não sai")


## O Caixote de Coleiras: "Levar a coleira com o nome" dá a Coleira com Nome (não mais o Fragmento), uma vez.
func _coleira() -> void:
	var c := _campaign()
	J.start_expedition(c, "fase_3", 2638)
	var fragments := int(c.session.expedition.loot.fragments)
	c.session.event = {"event_id": "busca_coleiras_numeradas", "from_search": true, "resolution": "", "pending_hard_combat": false, "object": "carga"}
	t.check(J.choose_event_option(c, "levar_coleira_nome", 1), "a escolha sai")
	t.check(c.inventory.relics.has("coleira_nome"), "a Coleira com Nome vai para o estoque")
	t.equal(int(c.session.expedition.loot.fragments), fragments, "e não dá mais o Fragmento")
	t.check(c.session.event.changes.any(func(ch): return ch.kind == "relic" and ch.id == "coleira_nome"), "o chip do resultado mostra a relíquia")
	t.check(c.session.expedition.found_relics.has("coleira_nome"), "é achado da expedição")
	J.finish_event(c)
	c.session.event = {"event_id": "busca_coleiras_numeradas", "from_search": true, "resolution": "", "pending_hard_combat": false, "object": "carga"}
	var take: Dictionary = GameData.row("events", "busca_coleiras_numeradas").Choices[0]
	t.check(not J.can_choose(c, take), "com a Coleira na equipe, a escolha some (é única)")
	S.hero(c, "hero_cao_bento").relics = ["coleira_nome", ""]
	c.inventory.relics.erase("coleira_nome")
	t.check(not J.can_choose(c, take), "também com ela equipada")


## A Lembrança da história volta ao mesmo ponto enquanto não está com a equipe (o evento fixo oferece de novo).
func _story_again() -> void:
	var row: Dictionary = GameData.row("events", "porta_espera")
	var choice: Dictionary = row.Choices[1]
	var original: Dictionary = choice.Success.duplicate(true)
	choice.Success.GrantRelic = "colar_circuito"
	var c := _campaign()
	J.start_expedition(c, "fase_3", 2639)
	c.station.story_events = ["fase_3"]
	t.equal(J.story_event(c), "porta_espera", "o evento já visto volta enquanto a Lembrança não veio")
	c.inventory.relics.append("colar_circuito")
	t.equal(J.story_event(c), "", "com ela na equipe, não volta")
	choice.Success = original
	t.check(not GameData.row("events", "porta_espera").Choices[1].Success.has("GrantRelic"), "a linha de teste sai")


## A derrota total perde as relíquias achadas na expedição (menos a Lembrança); as de antes ficam. O recuo e a fuga
## mantêm tudo. Também com o save gravado e lido no meio da expedição.
func _defeat_and_retreat() -> void:
	var real_dir: String = Campaign.save_dir
	var real_state = Campaign.state
	Campaign.save_dir = "user://test-relics-%d" % Time.get_ticks_usec()
	for spec in [["defeat", false], ["defeat", true], ["retreat", true], ["fled", false]]:
		var result: String = spec[0]
		var reload: bool = spec[1]
		var c := _campaign()
		c.inventory.relics = ["botao_cobre", "sino_vitrine"]
		AHRelics.equip(c, "hero_gato_nick", 0, "botao_cobre")
		J.start_expedition(c, "fase_1", 2640)
		var expedition: Dictionary = c.session.expedition
		# A carga (a caixa da relíquia) e o evento (a Lembrança).
		expedition.objective_completed = true
		expedition.cargo = {"boxes": [{"kind": "relic", "amount": 1, "relic_id": "sino_vitrine"}], "chosen": -1}
		t.equal(AHFightRewards.choose(c, 0), "", "%s: a caixa da relíquia" % result)
		c.session.event = {"event_id": "busca_coleiras_numeradas", "from_search": true, "resolution": "", "pending_hard_combat": false, "object": "carga"}
		J.choose_event_option(c, "levar_coleira_nome", 1)
		J.finish_event(c)
		t.equal(c.inventory.relics, ["sino_vitrine", "sino_vitrine", "coleira_nome"], "%s: o estoque durante a expedição" % result)
		if reload:
			Campaign.state = c
			t.check(Campaign.save(), "%s: o save no meio da expedição grava" % result)
			Campaign.state = {}
			Campaign.load_or_new()
			c = Campaign.state
			t.equal(Array(c.session.expedition.get("found_relics", [])), ["sino_vitrine", "coleira_nome"], "%s: o achado volta com o save" % result)
		c.session.result = result
		c.session.screen = "result"
		var delivered: Dictionary = S.finish_return(c)
		var nick: Dictionary = S.hero(c, "hero_gato_nick")
		# Só as desta conta: a escavação da volta pode achar outra.
		var mine: Array = c.inventory.relics.filter(func(id): return ["botao_cobre", "sino_vitrine", "coleira_nome"].has(id))
		if result == "defeat":
			t.equal(mine, ["sino_vitrine", "coleira_nome"], "derrota%s: o Sininho achado sai; o de antes e a Lembrança ficam" % (" (com o save relido)" if reload else ""))
			t.equal(delivered.get("lost_relics", []), ["sino_vitrine"], "derrota: o relatório diz o que ficou para trás")
		else:
			t.equal(mine, ["sino_vitrine", "sino_vitrine", "coleira_nome"], "%s: a equipe fica com o achado" % result)
			t.equal(delivered.get("lost_relics", []), [], "%s: nada perdido" % result)
		t.equal(AHRelics.equipped(nick), ["botao_cobre"], "%s: a equipada antes fica" % result)
	# A rara achada e perdida na derrota volta a poder sair do guardião.
	var lost := _campaign()
	_at_boss(lost, "fase_5", 2641)
	J.end_combat(lost, "victory", true)
	lost.session.result = "defeat"
	lost.session.screen = "result"
	S.finish_return(lost)
	t.check(not lost.inventory.relics.has("cartao_eclusa") and not AHRelics.given(lost).has("cartao_eclusa"), "o Cartão perdido na derrota pode sair de novo")
	_at_boss(lost, "fase_5", 2642)
	J.end_combat(lost, "victory", true)
	t.check(lost.inventory.relics.has("cartao_eclusa"), "e sai na próxima vitória sobre o Porteiro")
	# Equipada no meio (um save editado): a derrota a tira do slot.
	var slot := _campaign()
	J.start_expedition(slot, "fase_1", 2643)
	AHRelics.find(slot, "pena_vidro")
	AHRelics.equip(slot, "hero_cao_bento", 1, "pena_vidro")
	t.equal(AHRelics.lose_finds(slot, slot.session.expedition), ["pena_vidro"], "a achada e já equipada também sai")
	t.equal(AHRelics.slots(S.hero(slot, "hero_cao_bento")), ["", ""], "do slot")
	var dir := ProjectSettings.globalize_path(Campaign.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	Campaign.save_dir = real_dir
	Campaign.state = real_state
