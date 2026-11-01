## A espécie no indivíduo (#189, decisão de 01/11): a classe virou o papel, e a espécie (data/species.json) é de cada herói.
## - os dados: as seis espécies com a linhagem, a altura, a pasta das camadas e os nomes; cada classe com a espécie
##   padrão (o rato é Guaxinim); os nomes de papel na tela;
## - o save: o herói novo nasce com a espécie; o save de antes ganha a padrão da classe; a de quem tem não muda;
## - a linhagem pela espécie, no motor de verdade (um cão no papel Química vence como Canidae) e na ficha;
## - a altura pela espécie do indivíduo, e pela padrão da classe para quem ainda não está no elenco;
## - os nomes do recruta pela espécie.
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")
const ROLES := {"cao": "Proteção", "gato": "Incursão", "sapo": "Química", "coruja": "Tiro", "rato": "Sabotagem", "tatu": "Resgate"}

var t


func run(context) -> void:
	t = context
	_data()
	_save()
	_lineage()
	_height_and_names()


func _data() -> void:
	var species: Dictionary = GameData.table("species")
	t.equal(species.keys().size(), 6, "seis espécies")
	var incomplete: Array = []
	for species_id in species:
		var row: Dictionary = species[species_id]
		var lineage = GameData.combat.type_classes.get(String(row.get("Lineage", "")))
		if lineage == null or lineage.Kind != "lineage" or float(row.get("Height", 0)) <= 0.0 or row.get("Names", []).is_empty() \
				or not DirAccess.dir_exists_absolute("res://art/combat/recruits/layers/%s" % row.get("ArtFolder", "")):
			incomplete.append(species_id)
	t.equal(incomplete, [], "cada espécie com a linhagem, a altura, os nomes e a pasta das camadas")
	for class_id in ROLES:
		t.check(species.has(AHSpecies.default_for(class_id)), "%s: a espécie padrão existe" % class_id)
		t.equal(AHSpecies.role(class_id), ROLES[class_id], "%s: o papel na tela" % class_id)
	t.equal(AHSpecies.default_for("rato"), "guaxinim", "o rato (id que não muda) é Guaxinim")
	var lineages: Array = species.values().map(func(row): return String(row.Lineage))
	t.equal(lineages.size(), 6, "as seis linhagens, uma por espécie")
	t.check(not GameData.row("classes", "cao").has("Lineage") and not GameData.row("classes", "cao").has("Species"),
		"a linhagem e a espécie saíram da classe")


func _save() -> void:
	var campaign: Dictionary = Campaign.create_initial(189)
	t.equal(campaign.roster.map(func(h): return h.species), ["cao", "gato", "sapo", "coruja"], "os fundadores nascem com a espécie")
	t.equal(Campaign.new_hero("hero_rato_9", "rato", "Teste", 21, []).species, "guaxinim", "o herói novo nasce com a padrão da classe")
	# O save de antes: sem a espécie. A migração dá a padrão e não troca a de quem já tem.
	var old: Dictionary = Campaign.create_initial(189)
	for entry in old.roster:
		entry.erase("species")
	old.roster.append(Campaign.new_hero("hero_rato_4", "rato", "Risco", 21, []))
	old.roster[-1].erase("species")
	old.roster[0].species = "gato"
	AHStationRules.migrate(old)
	t.equal(old.roster.map(func(h): return h.species), ["gato", "gato", "sapo", "coruja", "guaxinim"], "o save de antes ganha a espécie padrão, e a de quem tem fica")
	AHStationRules.migrate(old)
	t.equal(old.roster[0].species, "gato", "a migração não muda nada na segunda vez")
	t.equal(AHSpecies.kind_text(old.roster[0]), "Gato · Proteção", "a ficha: a espécie do indivíduo e o papel")
	t.equal(AHSpecies.kind_text(old.roster[4]), "Guaxinim · Sabotagem", "o Risco: Guaxinim · Sabotagem")
	# Uma espécie que a tabela não conhece (um save editado): vale a padrão da classe, sem separador solto.
	var odd := Campaign.new_hero("hero_cao_9", "cao", "Teste", 34, [])
	odd.species = "lobo"
	t.equal(AHSpecies.kind_text(odd), "Cão · Proteção", "a espécie desconhecida cai na padrão da classe")
	t.equal(GameData.combat.species_of("cao", "lobo"), "cao", "e no combate também")


func _lineage() -> void:
	var data := AHGameData.new()
	data.load_from("res://data")
	data.type_advantage.Enabled = true
	var engine := AHCombatEngine.new(AHCombat.State.new(), AHCombat.Context.new(), data, null)
	var frog := AHCombatEngine.make_hero_unit({"Id": "f", "ClassId": "sapo", "DisplayName": "F", "Hp": 10, "MaxHp": 10}, 1, data)
	var dog_chemist := AHCombatEngine.make_hero_unit({"Id": "d", "ClassId": "sapo", "Species": "cao", "DisplayName": "D", "Hp": 10, "MaxHp": 10}, 1, data)
	var cat := AHCombatEngine.make_hero_unit({"Id": "c", "ClassId": "gato", "DisplayName": "C", "Hp": 10, "MaxHp": 10}, 1, data)
	t.equal([engine.type_of(frog), engine.type_of(dog_chemist)], ["Anura", "Canidae"], "a linhagem vem da espécie: o sapo Anura, o cão na Química Canidae")
	t.equal(engine.type_multiplier(dog_chemist, cat), 1.25, "o cão na Química vence o gato como Canidae")
	t.equal(engine.type_multiplier(frog, cat), 1.0, "o sapo na Química, não")
	# Os kits históricos da paridade não têm espécie: a unidade fica sem linhagem, e a paridade não muda.
	var legacy := AHGameData.new()
	legacy.load_from("res://data", "res://data/legacy_kits")
	if legacy.classes.has("cao"):
		var unit := AHCombatEngine.make_hero_unit({"Id": "l", "ClassId": "cao", "DisplayName": "L", "Hp": 10, "MaxHp": 10}, 1, legacy)
		t.equal(legacy.species_of("cao", ""), "", "o kit histórico sem a espécie padrão")
		t.equal(AHCombatEngine.new(AHCombat.State.new(), AHCombat.Context.new(), legacy, null).type_of(unit), "", "e sem linhagem")
	# A ficha fora da luta: o cão na Química mostra a Linhagem dos Cães.
	var hero := Campaign.new_hero("hero_sapo_9", "sapo", "Teste", 23, [])
	hero.species = "cao"
	t.equal(AHTypes.of_hero(hero), "Canidae", "a ficha lê a linhagem da espécie do herói")
	t.equal(AHCharacterSheet.from_hero(hero).kind, "Cão · Química", "e mostra Cão · Química")


func _height_and_names() -> void:
	var saved: Dictionary = Campaign.state
	var campaign: Dictionary = Campaign.create_initial(189)
	Campaign.state = campaign
	var nick: Dictionary = campaign.roster[1]
	t.equal(AHCharacterHeights.find(nick.id), AHSpecies.height("gato"), "a altura do Nick é a do gato")
	nick.species = "tatu"
	t.equal(AHCharacterHeights.find(nick.id), AHSpecies.height("tatu"), "a altura segue a espécie do indivíduo")
	t.equal(AHCharacterHeights.find("hero_rato_44"), AHSpecies.height("guaxinim"), "quem não está no elenco: a padrão da classe do id")
	t.equal(AHCharacterHeights.find("civil_dora"), 1.56, "os civis seguem na tabela de alturas")
	var name := S.hero_name(campaign, "rato")
	t.check(AHSpecies.names("guaxinim").has(name), "o recruta guaxinim ganha um nome da espécie (%s)" % name)
	Campaign.state = saved
