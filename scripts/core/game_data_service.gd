## Autoload GameData: todas as tabelas de data/*.json, carregadas uma vez.
## - tables: cada tabela como {Name da linha: linha}, como veio do JSON (números em float).
## - combat: as tabelas tipadas que o motor de combate usa (AHGameData, com os padrões das structs da Unreal).
extends Node

const DATA_DIR := "res://data"

var tables := {}
var combat: AHGameData
## Problemas da última carga (arquivo ausente, JSON inválido, referência quebrada).
var issues := PackedStringArray()


func _ready() -> void:
	reload()


## Lê de novo todas as tabelas. Retorna se não houve problema.
func reload(data_dir: String = DATA_DIR) -> bool:
	tables.clear()
	issues.clear()
	for file in DirAccess.get_files_at(data_dir):
		if not file.ends_with(".json"):
			continue
		var rows = JSON.parse_string(FileAccess.get_file_as_string(data_dir.path_join(file)))
		if typeof(rows) != TYPE_ARRAY:
			issues.append("%s: não é uma lista de linhas" % file)
			continue
		var table := {}
		for row in rows:
			if typeof(row) == TYPE_DICTIONARY and row.has("Name"):
				table[String(row.Name)] = row
		tables[file.get_basename().replace("-", "_")] = table
	combat = AHGameData.new()
	if not combat.load_from(data_dir):
		issues.append("tabelas do combate incompletas")
	issues.append_array(validate())
	for issue in issues:
		push_warning("GameData: " + issue)
	return issues.is_empty()


func table(table_name: String) -> Dictionary:
	return tables.get(table_name, {})


## Uma linha de uma tabela, ou null.
func row(table_name: String, id: String):
	return table(table_name).get(id)


## Referências entre tabelas que precisam existir.
func validate() -> PackedStringArray:
	var found := PackedStringArray()
	for required in ["classes", "abilities", "enemies", "enemy_actions", "perks", "instinct", "initial_heroes"]:
		if not tables.has(required):
			found.append("falta a tabela %s" % required)
	for class_id in table("classes"):
		for ability_id in table("classes")[class_id].get("AbilityIds", []):
			if not table("abilities").has(ability_id):
				found.append("classe %s: habilidade %s não existe" % [class_id, ability_id])
	for enemy_id in table("enemies"):
		for action_id in table("enemies")[enemy_id].get("ActionIds", []):
			if not table("enemy_actions").has(action_id):
				found.append("inimigo %s: ação %s não existe" % [enemy_id, action_id])
	for hero_id in table("initial_heroes"):
		var class_id: String = table("initial_heroes")[hero_id].get("ClassId", "")
		if not table("classes").has(class_id):
			found.append("fundador %s: classe %s não existe" % [hero_id, class_id])
	for perk_id in table("perks"):
		for other in table("perks")[perk_id].get("Incompatible", []):
			if not table("perks").has(other):
				found.append("perk %s: incompatível %s não existe" % [perk_id, other])
	return found
