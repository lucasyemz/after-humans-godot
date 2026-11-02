## Autoload Campaign: o estado da campanha e o save em JSON, como FAHCampaignStorage na Unreal.
##
## O save fica em dois arquivos (principal e cópia de segurança) com o mesmo conteúdo. Cada um guarda um envelope com
## formato, versão e um SHA-256 do estado. A gravação vai primeiro para um .tmp e só depois substitui o arquivo, para uma
## queda no meio não estragar o save. Ao abrir: o principal; se ele não servir, a cópia; se nenhum servir, uma campanha
## nova, que só é gravada quando o jogo começa (os arquivos antigos ficam como estão).
##
## Três espaços de campanha (#34), cada um com o próprio principal e a própria cópia: o 1 é o save de sempre
## (campaign.json, então o save de antes das vagas já é o espaço 1, sem mover nada) e o 2 e o 3 são campaign_2.json e
## campaign_3.json. slots.json guarda o último espaço usado, que o Continuar abre. Um espaço estragado não mexe nos
## outros.
extends Node

signal changed
signal saved(ok: bool)

const FORMAT := "after-humans-campaign"
## 2 (#90): o nível dos heróis (level, xp, upgrades). O save da versão 1 abre migrado (AHHeroLevels.migrate).
const VERSION := 2
const PRIMARY := "campaign.json"
const BACKUP := "campaign.backup.json"
const SLOTS_FILE := "slots.json"
const SLOT_COUNT := 3
## As cenas em que o tempo jogado conta (o título e a troca de cena, não).
const PLAY_SCENES := ["station", "street"]
## Ordem dos fundadores na formação (FounderFormation na Unreal).
const FOUNDERS := ["cao", "gato", "sapo", "coruja"]
const ACCENTS := {"á": "a", "à": "a", "â": "a", "ã": "a", "é": "e", "ê": "e", "í": "i", "ó": "o", "ô": "o", "õ": "o", "ú": "u", "ç": "c"}

## Pasta dos saves; os testes trocam por uma pasta temporária.
var save_dir := "user://saves"
## O espaço de campanha em uso (1 a SLOT_COUNT).
var slot := 1
var state := {}
## De onde veio o estado atual: "new", "primary" ou "backup".
var source := "new"
## O aviso para o jogador (cópia recuperada, save inválido), guardado como tipo ("backup", "slot", "none") e espaço:
## warning_text() o traduz na hora de mostrar (#35), porque o save abre antes de as Opções ligarem o idioma.
var _warning_kind := ""
var _warning_slot := 0


## O tempo jogado ainda não somado ao estado (segundos de relógio, sem a escala de tempo).
var _play_seconds := 0.0
var _last_tick := 0
## De quem é esse tempo: o estado e o arquivo do último save ou da última abertura. Só ele ganha o tempo; um estado
## trocado por fora (os testes, as capturas) não conta nem grava nada no fechamento.
var _play_state = null
var _play_path := ""
## Ao fechar o jogo, grava só o tempo jogado desde o último save no arquivo do espaço (#34). Os testes desligam.
var save_time_on_quit := true
var _quit_saved := false


func _ready() -> void:
	slot = last_slot()
	load_or_new()


## O tempo jogado anda só nas cenas de jogo, em segundos de relógio (a pausa do acerto e o teste acelerado não contam).
func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var step := (now - _last_tick) * 0.001 if _last_tick > 0 else 0.0
	_last_tick = now
	var flow := get_node_or_null("/root/GameFlow")
	if flow != null and PLAY_SCENES.has(flow.current_id) and not flow.busy and not get_tree().paused and is_same(state, _play_state):
		_play_seconds += minf(step, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		save_play_time()


## O tempo jogado desde o último save vai para o arquivo do espaço, sem gravar o resto do estado (quem fecha no meio de
## uma luta volta para onde o último save deixou, como antes; só o relógio não se perde). Uma vez só por execução.
func save_play_time() -> bool:
	var whole := floori(_play_seconds)
	if _quit_saved or not save_time_on_quit or whole <= 0 or not is_same(state, _play_state) or _play_path != primary_path():
		return false
	var campaign = read_file(primary_path())
	if campaign == null:
		return false
	_quit_saved = true
	campaign.played_seconds = int(campaign.get("played_seconds", 0)) + whole
	state.played_seconds = int(state.get("played_seconds", 0)) + whole
	_play_seconds -= whole
	# A data continua a do último save de progresso (a lista dos espaços mostra essa).
	var text := _envelope(campaign, _saved_at(primary_path()))
	return _write_atomic(primary_path(), text) and _write_atomic(backup_path(), text)


func _own_play_time() -> void:
	_play_state = state
	_play_path = primary_path()


## Soma ao estado o tempo jogado desde o último save.
func _flush_play_time() -> void:
	var whole := floori(_play_seconds)
	if whole > 0 and not state.is_empty():
		state.played_seconds = int(state.get("played_seconds", 0)) + whole
		_play_seconds -= whole


# ---------------------------------------------------------------- campanha nova

## Id estável do fundador: hero_<classe>_<nome sem acento, minúsculo> (hero_gato_nick).
static func founder_id(class_id: String, display_name: String) -> String:
	var simple := display_name.to_lower()
	for accent in ACCENTS:
		simple = simple.replace(accent, ACCENTS[accent])
	return "hero_%s_%s" % [class_id, simple]


## Dois ou três perks: um positivo, um negativo e, às vezes, um terceiro qualquer, sem incompatíveis (RollPerks).
## class_id (#264): as de cura só para quem cura. given: as que ele já tem (a positiva fixa do fundador conta como a
## positiva do sorteio).
static func roll_perks(perks: Dictionary, rng: RandomNumberGenerator, class_id: String = "", given: Array = []) -> Array:
	var result: Array = given.duplicate()
	var take := func(type: String) -> void:
		if type != "" and result.any(func(id): return perks.has(id) and perks[id].get("Type", "") == type):
			return
		var pool: Array = []
		for id in perks:
			if (type == "" or perks[id].get("Type", "") == type) and AHPerks.fits(result, id, class_id):
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
		"id": id, "class_id": class_id, "display_name": display_name,
		# A espécie do indivíduo (#189): a classe é o papel; quem chega sem uma fica com a padrão da classe.
		"species": AHSpecies.default_for(class_id), "alive": true, "hp": max_hp, "max_hp": max_hp,
		"instinct": 0, "perks": perks, "fixed_perks": [], "crisis_outcome": "none", "trauma": false, "trainings": [], "expedition_uses": {},
		# Os dois slots de relíquia (#263, AHRelics): o id de cada um, "" vazio.
		"relics": ["", ""], "completed_expeditions": 0, "expeditions_count": 0, "kills_count": 0,
		# A arte própria do recruta (#32): uma variação da classe no manifesto (dog_recruit_01); "" usa a do fundador.
		"art_variant": "",
		# As sete habilidades (#259, AHHeroSkills): os desbloqueios aprendidos no Treino e as que leva ([] = as 4 de base).
		"unlocked": [], "loadout": [], "camp_unlocked": [], "camp_loadout": [], "gear": {"weapon": 0, "armor": 0},
		# A skin completa que ele veste (#138): "default" é a arte de hoje; as outras ficam em data/skins.json.
		"skin_id": "default",
		# O nível (#90): o XP desde o último treino e as melhorias escolhidas (AHHeroLevels).
		"level": 1, "xp": 0, "upgrades": [],
		# Ninguém morre (#118): os dias que faltam na recuperação (0: pronto), se está num leito da Enfermaria e o ciclo
		# do último curativo.
		"recovery_days": 0, "recovery_bed": false, "recovery_treated": -1,
		# O posto na Estação enquanto a equipe está fora (#119): o cômodo, ou "".
		"post": "",
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
		# A melhor nota (1 a 3 estrelas) do guardião de cada fase (#91): {fase: estrelas}.
		"mission_stars": {},
		"researched_skills": [],
		"inventory": {"seeds": 30, "scrap": 0, "fragments": 0, "bandages": 2, "relics": [], "items": {}},
		# As relíquias que só saem uma vez e já saíram: a rara de cada guardião e a pessoal de cada fundador (#263).
		"relic_given": [],
		# O memorial (antes do #118): ninguém mais entra; fica vazio, e os saves antigos voltam com os heróis.
		"memorial": [],
		"settings": {"sfx_volume": 0.6, "ambience_volume": 0.6, "music_volume": 0.6, "battle_speed": 1, "reduced_environment_effects": false,
			"station_chatter": true},
		# Estação (cômodos, civis, economia), noite da volta e fila de voluntários: AHStationRules.init_new_campaign.
		"station": {},
		"session": {"screen": "shelter", "expedition": null},
		# Tempo jogado em segundos (o resumo do espaço de campanha, #34).
		"played_seconds": 0,
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
		# A positiva fixa do fundador (#264), nas campanhas novas: a marca de quem ele é; o resto, sorteado.
		var own := AHPerks.founder_fixed(class_id)
		var given: Array = [own] if own != "" and GameData.row("perks", own) != null else []
		var hero := new_hero(id, class_id, display_name, int(hero_class.BaseMaxHp), roll_perks(GameData.table("perks"), rng, class_id, given))
		hero.fixed_perks = given.duplicate()
		campaign.roster.append(hero)
		campaign.unlocked_classes.append(class_id)
		campaign.preferred_formation.append(id)
	AHStationRules.init_new_campaign(campaign)
	# A semente das missões solo (#183), depois dos fundadores: a mesma semente dá a mesma campanha.
	campaign.station.side_missions.seed = rng.randi()
	return campaign


## Começa um jogo novo e grava.
func new_game(seed_value: int = -1) -> bool:
	state = create_initial(seed_value)
	source = "new"
	_warning_kind = ""
	# O tempo jogado desde o último save é da campanha de antes, não da nova.
	_play_seconds = 0.0
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
	return slot_path(slot)


func backup_path() -> String:
	return slot_path(slot, true)


## O arquivo de um espaço: o 1 é o de sempre (campaign.json); os outros, campaign_<n>.json.
func slot_path(number: int, backup: bool = false) -> String:
	var base := (BACKUP if backup else PRIMARY) if number == 1 else ("campaign_%d%s.json" % [number, ".backup" if backup else ""])
	return save_dir.path_join(base)


## O último espaço usado (slots.json); 1 sem o arquivo ou com ele estragado.
func last_slot() -> int:
	var path := save_dir.path_join(SLOTS_FILE)
	if not FileAccess.file_exists(path):
		return 1
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return 1
	var last = json.data.get("last", 1)
	if typeof(last) != TYPE_INT and typeof(last) != TYPE_FLOAT:
		return 1
	var number := int(last)
	return number if number >= 1 and number <= SLOT_COUNT else 1


func _remember_slot() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))
	return _write_atomic(save_dir.path_join(SLOTS_FILE), JSON.stringify({"last": slot}))


## Há algum arquivo no espaço (mesmo um que não abre): sobrescrever pede confirmação.
func slot_has_save(number: int) -> bool:
	return FileAccess.file_exists(slot_path(number)) or FileAccess.file_exists(slot_path(number, true))


## O resumo de um espaço para a tela de campanhas: status "empty", "broken" (há arquivo, nenhum abre) ou "ok", com o
## ciclo, as fases concluídas, o elenco vivo, a data do último save (unix, 0 sem data) e o tempo jogado.
func slot_summary(number: int) -> Dictionary:
	var summary := {"slot": number, "status": "empty"}
	if not slot_has_save(number):
		return summary
	var path := slot_path(number)
	var campaign = read_file(path)
	if campaign == null:
		path = slot_path(number, true)
		campaign = read_file(path)
	if campaign == null:
		summary.status = "broken"
		return summary
	var roster: Array = campaign.get("roster", [])
	summary.merge({"status": "ok", "recovered": path == slot_path(number, true),
		"cycle": int(campaign.get("station", {}).get("cycle_number", 0)),
		"phases": campaign.get("completed_phases", []).size(),
		# "alive" (o nome antigo da chave, lida pelo título): quantos estão prontos para partir, fora do memorial dos saves
		# antigos e da recuperação (#118).
		"alive": roster.filter(func(h): return h.get("alive", true) and int(h.get("recovery_days", 0)) <= 0).size(), "roster": roster.size(),
		"played_seconds": int(campaign.get("played_seconds", 0)), "saved_at": _saved_at(path),
		"in_expedition": campaign.get("session", {}).get("expedition") != null and campaign.get("session", {}).get("result", "") == ""}, true)
	return summary


## A hora do save: a do envelope (saves novos) ou a do arquivo.
static func _saved_at(path: String) -> int:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) == OK and typeof(json.data) == TYPE_DICTIONARY and json.data.has("saved_at"):
		return int(json.data.saved_at)
	return int(FileAccess.get_modified_time(path))


## Passa a usar o espaço e abre a campanha dele (Continuar de outro espaço). Devolve a origem, como load_or_new.
func use_slot(number: int) -> String:
	slot = clampi(number, 1, SLOT_COUNT)
	_remember_slot()
	return load_or_new()


## Campanha nova no espaço (sobrescreve o que houver nele) e grava. Os outros espaços ficam como estão.
func new_game_in(number: int, seed_value: int = -1) -> bool:
	slot = clampi(number, 1, SLOT_COUNT)
	_remember_slot()
	return new_game(seed_value)


func has_save() -> bool:
	return FileAccess.file_exists(primary_path()) or FileAccess.file_exists(backup_path())


## Há um save que abre (o principal ou a cópia): o Continuar do título.
func has_valid_save() -> bool:
	return read_file(primary_path()) != null or read_file(backup_path()) != null


## Sobre o estado normalizado (inteiros como int), para gravar e conferir a mesma coisa.
static func _checksum(campaign: Dictionary) -> String:
	return JSON.stringify(_normalize(campaign), "", true).sha256_text()


## saved_at: a data do save (a lista dos espaços mostra); sem ela, agora.
static func _envelope(campaign: Dictionary, saved_at: int = -1) -> String:
	return JSON.stringify({"format": FORMAT, "version": VERSION, "checksum": _checksum(campaign),
		"saved_at": saved_at if saved_at >= 0 else int(Time.get_unix_time_from_system()),
		"campaign": campaign}, "\t", true)


## Grava o principal e depois a cópia. Recusa uma campanha inválida sem tocar nos arquivos.
func save() -> bool:
	if not is_usable(state):
		push_warning("Save recusado: campanha inválida.")
		saved.emit(false)
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))
	_flush_play_time()
	var text := _envelope(state)
	var ok := _write_atomic(primary_path(), text) and _write_atomic(backup_path(), text)
	if ok:
		_own_play_time()
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
	# A migração das versões antigas (como Migrate na Unreal): a 1 ganha o nível dos heróis (#90).
	var version := int(envelope.get("version", -1))
	if version < 1 or version > VERSION:
		return null
	var campaign = envelope.get("campaign")
	if typeof(campaign) != TYPE_DICTIONARY or envelope.get("checksum", "") != _checksum(campaign):
		return null
	campaign = _normalize(campaign)
	if version == 1 and int(campaign.get("version", -1)) == 1:
		AHHeroLevels.migrate(campaign)
		campaign.version = VERSION
	# As estrelas das fases (#91): o save de antes delas começa sem nenhuma.
	if not campaign.has("mission_stars"):
		campaign.mission_stars = {}
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


## O aviso do último load no idioma atual ("" sem aviso).
func warning_text() -> String:
	match _warning_kind:
		"backup":
			return tr("O último salvamento não pôde ser aberto. Recuperamos uma cópia de segurança. Ações recentes podem não estar nela.")
		"slot":
			return tr("O save do espaço %d não pôde ser aberto (o arquivo foi preservado). As outras campanhas estão em Campanhas.") % _warning_slot
		"none":
			return tr("Nenhum salvamento válido foi encontrado. Os dados anteriores foram preservados; um novo jogo só será salvo ao começar.")
	return ""


## Abre o principal; se não der, a cópia (com aviso); se nenhum servir, uma campanha nova sem gravar.
func load_or_new() -> String:
	_warning_kind = ""
	var campaign = read_file(primary_path())
	if campaign != null:
		source = "primary"
	else:
		campaign = read_file(backup_path())
		if campaign != null:
			source = "backup"
			_warning_kind = "backup"
	if campaign == null:
		campaign = create_initial()
		source = "new"
		var other := range(1, SLOT_COUNT + 1).filter(func(n): return n != slot and slot_summary(n).status == "ok")
		if has_save() and not other.is_empty():
			# Só este espaço falhou: o aviso diz qual e onde estão as outras campanhas.
			_warning_kind = "slot"
			_warning_slot = slot
		elif has_save():
			_warning_kind = "none"
	# Saves anteriores às vagas não têm o tempo jogado (#34): começa em 0.
	if not campaign.has("played_seconds"):
		campaign.played_seconds = 0
	_play_seconds = 0.0
	_quit_saved = false
	# Saves anteriores à Estação ganham os cômodos, a noite e os civis (idempotente).
	AHStationRules.migrate(campaign)
	state = campaign
	_own_play_time()
	changed.emit()
	return source
