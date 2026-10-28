## As skins completas dos heróis (#138): o mesmo personagem com outra roupa, nas mesmas poses. A skin padrão de cada um
## (DEFAULT) é a arte de hoje; as outras ficam em data/skins.json, cada uma com a pasta da arte (Folder). Cada pose da
## skin é o arquivo de mesmo nome da pose padrão nessa pasta (o retrato, portrait.webp), com o canvas, a âncora e a
## altura da pose padrão (o contrato da arte, docs/design/bento-watch.md); a pose que falta usa a padrão, então uma
## skin parcial não quebra nada. Só visual: nenhum número muda.
class_name AHSkins
extends RefCounted

const DEFAULT := "default"
## O retrato da skin, na pasta dela (o padrão fica em art/ui/portraits, com o nome do herói).
const PORTRAIT := "portrait.webp"

## As entradas de arte já vestidas, por herói e skin.
static var _dressed := {}


## As skins de um herói além da padrão, na ordem de data/skins.json. Só as que já têm arte (o parado na pasta): a
## skin que ainda não chegou (a arte em produção) não aparece.
static func of_hero(hero_id: String) -> Array:
	var out: Array = GameData.table("skins").values().filter(func(row): return String(row.get("HeroId", "")) == hero_id and has_art(String(row.Name)))
	out.sort_custom(func(a, b): return int(a.get("Order", 0)) < int(b.get("Order", 0)))
	return out


## A skin já tem a arte dela no projeto (o parado na pasta).
static func has_art(skin_id: String) -> bool:
	var skin = GameData.row("skins", skin_id)
	return skin != null and ResourceLoader.exists(String(skin.get("Folder", "")).path_join("idle.webp"))


## A skin que o herói veste no save ("default" sem campanha, sem herói ou sem a skin nos dados).
static func skin_of(hero_id: String) -> String:
	var entry = Campaign.hero(hero_id)
	var skin := String(entry.get("skin_id", DEFAULT)) if entry != null else DEFAULT
	return skin if skin == DEFAULT or GameData.row("skins", skin) != null else DEFAULT


## O arquivo de uma pose na skin: o de mesmo nome na pasta dela, se existe; senão, o padrão.
static func file_for(skin_id: String, file: String, name: String = "") -> String:
	if skin_id == DEFAULT or file == "":
		return file
	var skin = GameData.row("skins", skin_id)
	if skin == null:
		return file
	var path := String(skin.get("Folder", "")).path_join(name if name != "" else file.get_file())
	return path if ResourceLoader.exists(path) else file


## A entrada de arte do herói (a do manifesto: idle, actions, reactions) com as poses da skin no lugar das padrão. Os
## efeitos (vfx) e as medidas ficam os da padrão.
static func dress(entry: Dictionary, skin_id: String) -> Dictionary:
	if skin_id == DEFAULT or entry.is_empty() or GameData.row("skins", skin_id) == null:
		return entry
	var key := "%s|%s" % [entry.get("name", ""), skin_id]
	if _dressed.has(key):
		return _dressed[key]
	var out := entry.duplicate(true)
	out.skin = skin_id
	var idle: Dictionary = out.get("idle", {})
	idle.file = file_for(skin_id, String(idle.get("file", "")))
	if idle.has("portrait"):
		idle.portrait = file_for(skin_id, String(idle.portrait), PORTRAIT)
	for ability_id in out.get("actions", {}):
		for phase in ["preparacao", "execucao"]:
			var pose: Dictionary = out.actions[ability_id].get(phase, {})
			if pose.has("file"):
				pose.file = file_for(skin_id, String(pose.file))
	for reaction in out.get("reactions", {}):
		var pose: Dictionary = out.reactions[reaction]
		if pose.has("file"):
			pose.file = file_for(skin_id, String(pose.file))
	_dressed[key] = out
	return out


## Uma pose da Estação ou do acampamento (data/presentation/station_poses.json, camp_poses.json) na skin do herói.
static func pose(base: Dictionary, hero_id: String) -> Dictionary:
	var skin := skin_of(hero_id)
	if skin == DEFAULT or base.is_empty():
		return base
	var file := file_for(skin, String(base.get("file", "")))
	if file == base.get("file", ""):
		return base
	var out := base.duplicate(true)
	out.file = file
	return out


## As poses padrão que a skin ainda não tem (o teste lista o que falta em cada skin): os arquivos do herói no manifesto,
## o retrato, as poses da Estação e do acampamento.
static func missing(skin_id: String, entry: Dictionary, extra_files: Array = []) -> Array:
	var files: Array = []
	files.append(String(entry.get("idle", {}).get("file", "")))
	for ability_id in entry.get("actions", {}):
		for phase in ["preparacao", "execucao"]:
			files.append(String(entry.actions[ability_id].get(phase, {}).get("file", "")))
	for reaction in entry.get("reactions", {}):
		files.append(String(entry.reactions[reaction].get("file", "")))
	files.append_array(extra_files)
	var out: Array = []
	for file in files:
		if file != "" and file_for(skin_id, file) == file and not out.has(file.get_file()):
			out.append(file.get_file())
	if String(entry.get("idle", {}).get("portrait", "")) != "" and file_for(skin_id, entry.idle.portrait, PORTRAIT) == entry.idle.portrait:
		out.append(PORTRAIT)
	return out


## Esquece as entradas vestidas (os testes trocam a pasta de uma skin).
static func forget() -> void:
	_dressed.clear()
