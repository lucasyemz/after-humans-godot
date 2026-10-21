## Autoload Campaign: o estado da campanha e o save em JSON, como FAHCampaignStorage na Unreal.
##
## O save fica em dois arquivos (principal e cópia de segurança) com o mesmo conteúdo. Cada um guarda um envelope com
## formato, versão e um SHA-256 do estado. A gravação vai primeiro para um .tmp e só depois substitui o arquivo, para uma
## queda no meio não estragar o save. Ao abrir: o principal; se ele não servir, a cópia; se nenhum servir, uma campanha
## nova, que só é gravada quando o jogo começa (os arquivos antigos ficam como estão).
extends Node

signal changed
signal saved(ok: bool)

const FORMAT := "after-humans-campaign"
const VERSION := 1
const PRIMARY := "campaign.json"
const BACKUP := "campaign.backup.json"
## Ordem dos fundadores na formação (FounderFormation na Unreal).
const FOUNDERS := ["cao", "gato", "sapo", "coruja"]
const ACCENTS := {"á": "a", "à": "a", "â": "a", "ã": "a", "é": "e", "ê": "e", "í": "i", "ó": "o", "ô": "o", "õ": "o", "ú": "u", "ç": "c"}

## Pasta dos saves; os testes trocam por uma pasta temporária.
var save_dir := "user://saves"
var state := {}
## De onde veio o estado atual: "new", "primary" ou "backup".
var source := "new"
## Aviso para mostrar ao jogador (cópia recuperada, save inválido).
var load_warning := ""


func _ready() -> void:
	load_or_new()


# ---------------------------------------------------------------- campanha nova

## Id estável do fundador: hero_<classe>_<nome sem acento, minúsculo> (hero_gato_nick).
static func founder_id(class_id: String, display_name: String) -> String:
	var simple := display_name.to_lower()
	for accent in ACCENTS:
		simple = simple.replace(accent, ACCENTS[accent])
	return "hero_%s_%s" % [class_id, simple]


## Dois ou três perks: um positivo, um negativo e, às vezes, um terceiro qualquer, sem incompatíveis (RollPerks).
static func roll_perks(perks: Dictionary, rng: RandomNumberGenerator) -> Array:
	var result: Array = []
	var compatible := func(id: String) -> bool:
		for other in result:
			if perks[id].get("Incompatible", []).has(other) or perks[other].get("Incompatible", []).has(id):
				return false
		return true
	var take := func(type: String) -> void:
		var pool: Array = []
		for id in perks:
			if not result.has(id) and (type == "" or perks[id].get("Type", "") == type) and compatible.call(id):
				pool.append(id)
		if not pool.is_empty():
			result.append(pool[mini(pool.size() - 1, floori(rng.randf() * pool.size()))])
	var count := 2 + floori(rng.randf() * 2.0)
	take.call("Positive")
	take.call("Negative")
	if count == 3:
		take.call("")
	return result


static func new_hero(id: String, class_id: String, display_name: String, max_hp: int, perks: Array) -> Dictionary:
	return {
		"id": id, "class_id": class_id, "display_name": display_name, "alive": true, "hp": max_hp, "max_hp": max_hp,
		"instinct": 0, "perks": perks, "crisis_outcome": "none", "trauma": false, "trainings": [], "expedition_uses": {},
		"relic_id": "", "completed_expeditions": 0, "expeditions_count": 0, "kills_count": 0,
	}


## Campanha nova com os quatro fundadores (CreateInitialCampaign). seed < 0: sorteio livre.
func create_initial(seed_value: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var campaign := {
		"version": VERSION,
		"roster": [],
		"preferred_formation": [],
		"unlocked_classes": [],
		"tools": [],
		"completed_phases": [],
		"researched_skills": [],
		"inventory": {"seeds": 30, "scrap": 0, "fragments": 0, "bandages": 2, "relics": [], "items": {}},
		"memorial": [],
		"settings": {"sfx_volume": 0.6, "ambience_volume": 0.6, "music_volume": 0.6, "battle_speed": 1, "reduced_environment_effects": false},
		# Estação (cômodos, civis, economia), noite da volta e fila de voluntários: AHStationRules.init_new_campaign.
		"station": {},
		"session": {"screen": "shelter", "expedition": null},
	}
	var initial := GameData.table("initial_heroes")
	for class_id in FOUNDERS:
		var founder = null
		for row in initial.values():
			if row.get("ClassId", "") == class_id:
				founder = row
		var hero_class = GameData.row("classes", class_id)
		if founder == null or hero_class == null:
			push_error("Campanha nova: falta o fundador ou a classe %s nas tabelas." % class_id)
			continue
		var display_name: String = founder.DisplayName
		var id := founder_id(class_id, display_name)
		campaign.roster.append(new_hero(id, class_id, display_name, int(hero_class.BaseMaxHp), roll_perks(GameData.table("perks"), rng)))
		campaign.unlocked_classes.append(class_id)
		campaign.preferred_formation.append(id)
	AHStationRules.init_new_campaign(campaign)
	return campaign


## Começa um jogo novo e grava.
func new_game(seed_value: int = -1) -> bool:
	state = create_initial(seed_value)
	source = "new"
	load_warning = ""
	changed.emit()
	return save()


## Uma campanha que dá para jogar (IsUsable): versão certa e heróis com id, classe e vida.
static func is_usable(campaign) -> bool:
	if typeof(campaign) != TYPE_DICTIONARY or int(campaign.get("version", -1)) != VERSION:
		return false
	var roster = campaign.get("roster", [])
	if typeof(roster) != TYPE_ARRAY or roster.is_empty():
		return false
	for hero in roster:
		if typeof(hero) != TYPE_DICTIONARY or String(hero.get("id", "")) == "" or String(hero.get("class_id", "")) == "" or int(hero.get("max_hp", 0)) <= 0:
			return false
	return true


func hero(hero_id: String):
	for entry in state.get("roster", []):
		if entry.id == hero_id:
			return entry
	return null


# ---------------------------------------------------------------- gravar e abrir

func primary_path() -> String:
	return save_dir.path_join(PRIMARY)


func backup_path() -> String:
	return save_dir.path_join(BACKUP)


func has_save() -> bool:
	return FileAccess.file_exists(primary_path()) or FileAccess.file_exists(backup_path())


## Sobre o estado normalizado (inteiros como int), para gravar e conferir a mesma coisa.
static func _checksum(campaign: Dictionary) -> String:
	return JSON.stringify(_normalize(campaign), "", true).sha256_text()


static func _envelope(campaign: Dictionary) -> String:
	return JSON.stringify({"format": FORMAT, "version": VERSION, "checksum": _checksum(campaign), "campaign": campaign}, "\t", true)


## Grava o principal e depois a cópia. Recusa uma campanha inválida sem tocar nos arquivos.
func save() -> bool:
	if not is_usable(state):
		push_warning("Save recusado: campanha inválida.")
		saved.emit(false)
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))
	var text := _envelope(state)
	var ok := _write_atomic(primary_path(), text) and _write_atomic(backup_path(), text)
	if not ok:
		push_error("Falha ao salvar a campanha em %s." % save_dir)
	saved.emit(ok)
	return ok


static func _write_atomic(path: String, text: String) -> bool:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute)
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), absolute) == OK


## Lê um arquivo de save e devolve a campanha, ou null se ele estiver ausente, corrompido ou for de outra versão.
static func read_file(path: String):
	if not FileAccess.file_exists(path):
		return null
	# JSON.new().parse não escreve erro no log: um save corrompido é um caso esperado, tratado abaixo.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	var envelope = json.data
	if typeof(envelope) != TYPE_DICTIONARY or envelope.get("format", "") != FORMAT:
		return null
	# Quando o formato mudar, a migração das versões antigas entra aqui (como Migrate na Unreal).
	if int(envelope.get("version", -1)) != VERSION:
		return null
	var campaign = envelope.get("campaign")
	if typeof(campaign) != TYPE_DICTIONARY or envelope.get("checksum", "") != _checksum(campaign):
		return null
	campaign = _normalize(campaign)
	return campaign if is_usable(campaign) else null


## O JSON devolve todo número como float: volta para int os campos inteiros, para o estado sair igual ao que entrou.
static func _normalize(value):
	match typeof(value):
		TYPE_DICTIONARY:
			var out := {}
			for key in value:
				out[key] = _normalize(value[key])
			return out
		TYPE_ARRAY:
			return value.map(func(item): return _normalize(item))
		TYPE_FLOAT:
			return int(value) if value == floorf(value) and absf(value) < 1e15 else value
	return value


## Abre o principal; se não der, a cópia (com aviso); se nenhum servir, uma campanha nova sem gravar.
func load_or_new() -> String:
	load_warning = ""
	var campaign = read_file(primary_path())
	if campaign != null:
		source = "primary"
	else:
		campaign = read_file(backup_path())
		if campaign != null:
			source = "backup"
			load_warning = "O último salvamento não pôde ser aberto. Recuperamos uma cópia de segurança. Ações recentes podem não estar nela."
	if campaign == null:
		campaign = create_initial()
		source = "new"
		if has_save():
			load_warning = "Nenhum salvamento válido foi encontrado. Os dados anteriores foram preservados; um novo jogo só será salvo ao começar."
	# Saves anteriores à Estação ganham os cômodos, a noite e os civis (idempotente).
	AHStationRules.migrate(campaign)
	state = campaign
	changed.emit()
	return source
