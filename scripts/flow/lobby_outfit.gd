## A roupa confortável do lobby (#243, as poses da #249): quem mora na Estação veste a dele nos cômodos (parado,
## sentado no banco, deitado no beliche e no posto de trabalho). A skin de expedição gravada (AHSkins) não muda e é a
## que aparece fora dos cômodos: Ver personagem, a fila da chegada e do relatório, a partida, a rua, a luta e o
## acampamento. A troca acontece quando a equipe sai da plataforma depois da chegada; quem abre o jogo na Estação já
## encontra todos com ela. Os fundadores pelo id; os recrutas pela variação da arte (art_variant). Quem ainda não tem
## a roupa fica com a de expedição em todas as poses, sem misturar as duas.
class_name AHLobbyOutfit
extends RefCounted

const MANIFEST := "res://data/presentation/lobby_outfits.json"

static var _manifest := {}


## As poses de lobby do herói ({idle, seat, sleep, work}, o que a roupa tem); vazio se ele não tem a roupa.
## art: a entrada de arte de expedição dele (AHCombatArena.art_entry), que diz a variação do recruta.
static func poses_of(hero_id: String, art: Dictionary) -> Dictionary:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var heroes: Dictionary = _manifest.get("heroes", {})
	if heroes.has(hero_id):
		return heroes[hero_id]
	var variant := String(art.get("variant", ""))
	return _manifest.get("recruits", {}).get(variant, {}) if variant != "" else {}
