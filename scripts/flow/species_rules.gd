## A espécie do indivíduo (#189, decisão de 01/11): a classe virou o papel (Proteção, Incursão, Química, Tiro, Sabotagem,
## Resgate), e a espécie (data/species.json) é de cada herói. Ela dá a linhagem da vantagem de tipo (#227), a altura, a
## pasta das camadas da arte e os nomes da cultura dela; não dá atributos. O herói guarda a dele em species; quem não tem
## (os fundadores de um save de antes) fica com a DefaultSpecies da classe. Os ids das classes não mudam.
class_name AHSpecies
extends RefCounted


## A espécie padrão da classe ("" sem classe).
static func default_for(class_id: String) -> String:
	var hero_class = GameData.row("classes", class_id)
	return String(hero_class.get("DefaultSpecies", "")) if hero_class != null else ""


## A espécie de um herói (o dicionário do elenco): a dele, ou a padrão da classe.
static func of_hero(hero) -> String:
	if hero == null:
		return ""
	var own := String(hero.get("species", ""))
	return own if own != "" else default_for(String(hero.get("class_id", "")))


static func row(species_id: String):
	return GameData.row("species", species_id)


## O nome na tela ("Cão", "Guaxinim").
static func display(species_id: String) -> String:
	var entry = row(species_id)
	return TranslationServer.translate(String(entry.DisplayName)) if entry != null else ""


## A linhagem (#227) da espécie ("" sem).
static func lineage(species_id: String) -> String:
	var entry = row(species_id)
	return String(entry.get("Lineage", "")) if entry != null else ""


## A altura da cabeça aos pés, em metros (0 sem a espécie).
static func height(species_id: String) -> float:
	var entry = row(species_id)
	return float(entry.get("Height", 0.0)) if entry != null else 0.0


## Os nomes que a comunidade daria a quem é da espécie (de objetos, lugares e traços; #64).
static func names(species_id: String) -> Array:
	var entry = row(species_id)
	return entry.get("Names", []) if entry != null else []


## O papel na tela ("Proteção"): o nome da classe.
static func role(class_id: String) -> String:
	var hero_class = GameData.row("classes", class_id)
	return TranslationServer.translate(String(hero_class.DisplayName)) if hero_class != null else ""


## "Cão · Proteção": a espécie e o papel de um herói, para as fichas e as listas.
static func kind_text(hero) -> String:
	if hero == null:
		return ""
	return " · ".join([display(of_hero(hero)), role(String(hero.get("class_id", "")))])


## Põe a espécie em quem não tem (a migração do save e o herói novo); a de quem tem não muda.
static func ensure(hero: Dictionary) -> void:
	if String(hero.get("species", "")) == "":
		hero.species = default_for(String(hero.get("class_id", "")))
