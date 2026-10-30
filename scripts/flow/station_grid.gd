## A Estação em grade (#186; as regras e o save, #272): três subsolos de sete vagas de 6 m, com a escada à direita e um
## patamar em cada andar abaixo do primeiro. Quase tudo começa soterrado. A cada volta de expedição, a comunidade e quem
## ficou no posto de escavador cavam um bloco (pontos de obra); o bloco aberto vira uma vaga livre e devolve um achado.
## Numa vaga livre do tamanho certo, o jogador constrói um cômodo (AHStationRules.build_room). Os números e os textos
## ficam em data/station-grid.json; o tamanho de cada cômodo e o nível em que ele entra numa vaga, em AHStationRules.ROOMS.
##
## Estado (campaign.station.grid):
##   cells: três listas de sete vagas (o 1º, o 2º e o 3º subsolo, da esquerda para a escada): "" soterrada, "free" livre
##          ou o id do cômodo que a ocupa (o duplo, nas duas);
##   landings: [o patamar do 2º subsolo, o do 3º] (true: aberto);
##   target: o bloco escolhido para escavar ("": a comunidade cava o mais perto da escada);
##   progress: {bloco: pontos de obra já feitos} (trocar de bloco guarda o que já foi cavado);
##   intro_seen: a fala da primeira volta com escavação já apareceu.
## Os blocos: "1:3" (o 1º subsolo, vaga 3) e "L2" (o patamar do 2º subsolo).
class_name AHStationGrid
extends RefCounted

const FLOORS := 3
const SLOTS := 7
const FREE := "free"
## O posto de escavador (#119): um herói por vez, como os postos dos cômodos (data/hero-jobs.json, job_dig).
const DIG := "dig"
const BENTO := "hero_cao_bento"
const NICK := "hero_gato_nick"


static func rule(row_name: String) -> Dictionary:
	var row = GameData.row("station_grid", row_name)
	return row if row != null else {}


static func grid(campaign: Dictionary) -> Dictionary:
	return campaign.station.grid


# ================================================================ o começo e os saves

## A campanha nova (#186, opção A): o Dormitório, o Alojamento e a Forja parada no 1º subsolo; o resto soterrado.
static func init_new(campaign: Dictionary) -> void:
	campaign.station.grid = _layout("layout_new")


## Os saves de antes da grade: a planta herdada, com os cômodos na ordem de hoje, o 1º e o 2º subsolos abertos e o 3º
## soterrado. O save que ainda está na abertura do tutorial (a visita guiada não terminou) começa como a campanha nova.
## Nenhum cômodo já construído fica soterrado (heal). Idempotente.
static func migrate(campaign: Dictionary) -> void:
	var station: Dictionary = campaign.station
	if typeof(station.get("grid")) != TYPE_DICTIONARY or typeof(station.grid.get("cells")) != TYPE_ARRAY:
		if _opening(campaign):
			station.grid = _layout("layout_new")
		else:
			station.grid = _layout("layout_legacy")
			# O Depósito de nível 1 vira os caixotes da plataforma, e a vaga dele fica livre.
			if AHStationRules.room_level(campaign, AHStationRules.DEPOT) < 2:
				_clear_room(station.grid, AHStationRules.DEPOT)
			# A Cantina de hoje vira a Cantina construída (o nível 2): o fogareiro é o nível 1.
			if AHStationRules.room_level(campaign, AHStationRules.CANTEEN) < 2:
				station.rooms[AHStationRules.CANTEEN] = 2
	_normalize(station.grid)
	heal(campaign)


## Ainda na abertura do tutorial e com os cômodos da campanha nova.
static func _opening(campaign: Dictionary) -> bool:
	if not ["journey", "station"].has(AHTutorial.stage(campaign)):
		return false
	for room in AHStationRules.ROOMS:
		if int(campaign.station.rooms.get(room.id, 0)) != (1 if room.basic else 0):
			return false
	return true


static func _layout(row_name: String) -> Dictionary:
	var row := rule(row_name)
	var floors: Array = row.get("Floors", [])
	var cells: Array = []
	for f in FLOORS:
		var source: Array = floors[f] if f < floors.size() else []
		var line: Array = []
		for k in SLOTS:
			line.append(String(source[k]) if k < source.size() else "")
		cells.append(line)
	var landings: Array = row.get("Landings", [])
	return {"cells": cells, "landings": [landings.size() > 0 and bool(landings[0]), landings.size() > 1 and bool(landings[1])],
		"target": "", "progress": {}, "intro_seen": false}


## O save volta do JSON com os números em float e pode vir de uma versão com menos campos.
static func _normalize(state: Dictionary) -> void:
	var cells: Array = state.cells
	while cells.size() < FLOORS:
		cells.append([])
	for f in FLOORS:
		var line: Array = cells[f] if typeof(cells[f]) == TYPE_ARRAY else []
		while line.size() < SLOTS:
			line.append("")
		for k in SLOTS:
			var id := String(line[k])
			line[k] = id if id == "" or id == FREE or room_slots(id) > 0 else FREE
		cells[f] = line
	var landings: Array = state.get("landings", []) if typeof(state.get("landings")) == TYPE_ARRAY else []
	state.landings = [landings.size() > 0 and bool(landings[0]), landings.size() > 1 and bool(landings[1])]
	state.target = String(state.get("target", ""))
	var progress: Dictionary = state.get("progress", {}) if typeof(state.get("progress")) == TYPE_DICTIONARY else {}
	var clean := {}
	for key in progress:
		if int(progress[key]) > 0:
			clean[String(key)] = int(progress[key])
	state.progress = clean
	state.intro_seen = bool(state.get("intro_seen", false))


## Todo cômodo já construído tem vaga: o que não tem vai para a primeira vaga livre do tamanho dele ou, sem nenhuma, para
## as primeiras vagas onde ele cabe, desentulhadas na hora. O andar com vaga aberta tem o patamar aberto. A barra de Admin
## e os saves antigos passam por aqui.
static func heal(campaign: Dictionary) -> void:
	var state := grid(campaign)
	for room in AHStationRules.ROOMS:
		var id: String = room.id
		if room_slots(id) <= 0 or placed(campaign, id) or AHStationRules.room_level(campaign, id) < build_level(id):
			continue
		var spots := free_spots(campaign, id)
		var spot: String = spots[0] if not spots.is_empty() else _first_fit(campaign, id)
		if spot != "":
			_place(state, id, spot)
	for f in range(2, FLOORS + 1):
		if state.cells[f - 1].any(func(id): return id != ""):
			state.landings[f - 2] = true


static func _first_fit(campaign: Dictionary, room_id: String) -> String:
	var state := grid(campaign)
	var size := room_slots(room_id)
	for f in range(1, FLOORS + 1):
		for k in range(1, SLOTS - size + 2):
			var fits := true
			for i in size:
				var id := String(state.cells[f - 1][k + i - 1])
				fits = fits and (id == "" or id == FREE)
			if fits:
				return "%d:%d" % [f, k]
	return ""


static func _clear_room(state: Dictionary, room_id: String) -> void:
	for line in state.cells:
		for k in line.size():
			if line[k] == room_id:
				line[k] = FREE


# ================================================================ as vagas e os cômodos

## Quantas vagas o cômodo ocupa (0: fora da grade, na plataforma).
static func room_slots(room_id: String) -> int:
	return int(AHStationRules.room_def(room_id).get("slots", 0))


## O nível em que o cômodo entra numa vaga: 1 para os que são recuperados; 2 para a Cantina e o Depósito, que no nível 1
## são o fogareiro e os caixotes da plataforma.
static func build_level(room_id: String) -> int:
	return int(AHStationRules.room_def(room_id).get("build", 0))


static func cell(campaign: Dictionary, floor_number: int, slot: int) -> String:
	return String(grid(campaign).cells[floor_number - 1][slot - 1])


static func placed(campaign: Dictionary, room_id: String) -> bool:
	for line in grid(campaign).cells:
		if line.has(room_id):
			return true
	return false


## A vaga do cômodo ("1:3", a da esquerda no duplo), ou "".
static func room_spot(campaign: Dictionary, room_id: String) -> String:
	for f in range(1, FLOORS + 1):
		for k in range(1, SLOTS + 1):
			if cell(campaign, f, k) == room_id:
				return "%d:%d" % [f, k]
	return ""


## O próximo nível do cômodo é o de construir, e ele ainda não tem vaga.
static func needs_place(campaign: Dictionary, room_id: String) -> bool:
	return room_slots(room_id) > 0 and not placed(campaign, room_id) and AHStationRules.room_level(campaign, room_id) + 1 == build_level(room_id)


## O cômodo cabe a partir da vaga (a da esquerda): todas as vagas dele livres, no mesmo andar.
static func spot_fits(campaign: Dictionary, room_id: String, spot: String) -> bool:
	var size := room_slots(room_id)
	if size <= 0 or is_landing(spot) or not block_keys().has(spot):
		return false
	var f := block_floor(spot)
	var k := block_slot(spot)
	if k + size - 1 > SLOTS:
		return false
	for i in size:
		if cell(campaign, f, k + i) != FREE:
			return false
	return true


## As vagas livres onde o cômodo cabe, do 1º subsolo para baixo e da esquerda para a escada.
static func free_spots(campaign: Dictionary, room_id: String) -> Array:
	var out: Array = []
	for f in range(1, FLOORS + 1):
		for k in range(1, SLOTS + 1):
			var spot := "%d:%d" % [f, k]
			if spot_fits(campaign, room_id, spot):
				out.append(spot)
	return out


## Por que o cômodo não pode ser construído agora por falta de lugar ("" quando tem lugar ou não precisa).
static func space_block(campaign: Dictionary, room_id: String) -> String:
	if not needs_place(campaign, room_id) or not free_spots(campaign, room_id).is_empty():
		return ""
	var name := TranslationServer.translate(AHStationRules.room_def(room_id).name)
	if room_slots(room_id) >= 2:
		return TranslationServer.translate("Falta uma vaga dupla livre para %s: escave o entulho até abrir duas vagas vizinhas.") % name
	return TranslationServer.translate("Falta uma vaga livre para %s: escave o entulho para abrir uma.") % name


## O cômodo está soterrado: precisa de uma vaga que ainda não existe.
static func buried(campaign: Dictionary, room_id: String) -> bool:
	return space_block(campaign, room_id) != ""


static func place(campaign: Dictionary, room_id: String, spot: String) -> void:
	_place(grid(campaign), room_id, spot)


static func _place(state: Dictionary, room_id: String, spot: String) -> void:
	var f := block_floor(spot)
	var k := block_slot(spot)
	for i in room_slots(room_id):
		state.cells[f - 1][k + i - 1] = room_id
	state.progress.erase(spot)


# ================================================================ escavar

## Os blocos na ordem em que a comunidade cava sozinha: o 1º subsolo da escada para a esquerda, o patamar do 2º, o 2º
## subsolo, o patamar do 3º e o 3º subsolo.
static func block_keys() -> Array:
	var out: Array = []
	for f in range(1, FLOORS + 1):
		if f > 1:
			out.append("L%d" % f)
		for k in range(SLOTS, 0, -1):
			out.append("%d:%d" % [f, k])
	return out


static func is_landing(key: String) -> bool:
	return key.begins_with("L")


static func block_floor(key: String) -> int:
	return int(key.substr(1)) if is_landing(key) else int(key.get_slice(":", 0))


static func block_slot(key: String) -> int:
	return 0 if is_landing(key) else int(key.get_slice(":", 1))


static func block_open(campaign: Dictionary, key: String) -> bool:
	var f := block_floor(key)
	if is_landing(key):
		return f <= 1 or bool(grid(campaign).landings[f - 2])
	return cell(campaign, f, block_slot(key)) != ""


## Dá para escavar: soterrado, vizinho de uma vaga aberta no mesmo andar (a vaga ao lado da escada encosta no patamar),
## com o patamar do andar aberto; o patamar, com o de cima aberto.
static func diggable(campaign: Dictionary, key: String) -> bool:
	if not block_keys().has(key) or block_open(campaign, key):
		return false
	var f := block_floor(key)
	if is_landing(key):
		return block_open(campaign, "L%d" % (f - 1))
	if not block_open(campaign, "L%d" % f):
		return false
	var k := block_slot(key)
	return k == SLOTS or cell(campaign, f, k + 1) != "" or (k > 1 and cell(campaign, f, k - 1) != "")


## Os blocos que dá para escavar agora, na ordem da comunidade.
static func dig_blocks(campaign: Dictionary) -> Array:
	return block_keys().filter(func(key): return diggable(campaign, key))


## A frente de escavação: a escolhida, se ainda dá; senão, a da comunidade (o bloco mais perto da escada). "" sem nada.
static func dig_target(campaign: Dictionary) -> String:
	var chosen := String(grid(campaign).target)
	if chosen != "" and diggable(campaign, chosen):
		return chosen
	var blocks := dig_blocks(campaign)
	return blocks[0] if not blocks.is_empty() else ""


## Escolhe a frente ("" devolve a escolha à comunidade). Devolve "" ou o motivo.
static func set_dig_target(campaign: Dictionary, key: String) -> String:
	if key != "" and not diggable(campaign, key):
		if block_keys().has(key) and block_open(campaign, key):
			return TranslationServer.translate("Esse bloco já está aberto.")
		return TranslationServer.translate("Esse bloco ainda não dá para escavar: só o vizinho de uma vaga aberta, no mesmo andar, depois do patamar.")
	grid(campaign).target = key
	return ""


static func block_rule(key: String) -> Dictionary:
	return rule("landing") if is_landing(key) else rule("floor_%d" % block_floor(key))


## Os pontos de obra que o bloco pede.
static func block_work(key: String) -> int:
	return maxi(1, int(block_rule(key).get("Work", 1)))


static func block_progress(campaign: Dictionary, key: String) -> int:
	return int(grid(campaign).progress.get(key, 0))


## Quantos pontos a comunidade faz sozinha a cada volta.
static func community_work() -> int:
	return maxi(0, int(rule("community").get("Work", 1)))


## Os pontos de uma volta: a comunidade e o escavador que ficou (fora da equipe, de pé). team: quem parte ou partiu.
static func dig_rate(campaign: Dictionary, team: Array = []) -> int:
	var digger = AHStationRules.worker(campaign, DIG)
	var extra := 0
	if digger != null and not team.has(digger.id) and not AHStationRules.recovering(digger):
		extra = AHStationRules.post_yield(digger, DIG)
	return community_work() + extra


## Quantas voltas faltam para abrir o bloco no ritmo de agora.
static func returns_left(campaign: Dictionary, key: String, team: Array = []) -> int:
	var left := maxi(0, block_work(key) - block_progress(campaign, key))
	return ceili(float(left) / float(maxi(1, dig_rate(campaign, team))))


## A volta da expedição: a comunidade e o escavador cavam a frente. Os pontos que sobram não passam para o próximo bloco.
## Devolve o que entra no relatório ({block, points, work, progress, opened, finds}) ou {} sem nada para escavar.
static func run_dig(campaign: Dictionary, expedition_id: String, digger_points: int) -> Dictionary:
	var key := dig_target(campaign)
	if key == "":
		return {}
	var state := grid(campaign)
	var points := community_work() + maxi(0, digger_points)
	var work := block_work(key)
	var done := block_progress(campaign, key) + points
	var out := {"block": key, "points": points, "work": work, "progress": mini(done, work), "opened": false, "finds": {}}
	if done < work:
		state.progress[key] = done
		return out
	state.progress.erase(key)
	if state.target == key:
		state.target = ""
	if is_landing(key):
		state.landings[block_floor(key) - 2] = true
	else:
		state.cells[block_floor(key) - 1][block_slot(key) - 1] = FREE
	out.opened = true
	out.finds = _find(campaign, expedition_id, key)
	return out


## O achado do bloco aberto: o mínimo, um sorteio (um dos achados do andar, ou nada) e, à parte, a chance de um item
## raro. A mesma expedição e o mesmo bloco dão sempre o mesmo achado. Já entra no estoque.
static func _find(campaign: Dictionary, expedition_id: String, key: String) -> Dictionary:
	var row := block_rule(key)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:dig:%s" % [expedition_id, key])
	var finds := {"scrap": int(row.get("Scrap", 0)), "seeds": 0, "fragments": int(row.get("Fragments", 0)), "bandages": 0,
		"tool": "", "relic": "", "texts": [String(row.get("Text", ""))]}
	var roll := _pick(row.get("Rolls", []), rng.randi_range(1, 100))
	if not roll.is_empty():
		var kind := String(roll.Kind)
		finds[kind] = int(finds.get(kind, 0)) + int(roll.get("Amount", 1))
		finds.texts.append(String(roll.get("Text", "")))
	if rng.randi_range(1, 100) <= int(row.get("RareChance", 0)):
		var rare := rule("rare")
		var kind := String(_pick(rare.get("Rolls", []), rng.randi_range(1, 100)).get("Kind", "bandage"))
		var text := ""
		if kind == "tool":
			var tools: Array = rare.get("Tools", []).filter(func(t): return not AHJourneyRules.has_tool(campaign, String(t.Tool)))
			if not tools.is_empty():
				var tool: Dictionary = tools[rng.randi() % tools.size()]
				finds.tool = String(tool.Tool)
				text = String(tool.get("Text", ""))
		elif kind == "relic":
			var relics := _new_relics(campaign)
			if not relics.is_empty():
				finds.relic = relics[rng.randi() % relics.size()]
				text = _rare_text(rare, "relic")
		# O curativo, e o que vira curativo quando não há nada novo para dar.
		if finds.tool == "" and finds.relic == "":
			finds.bandages = 1
			text = _rare_text(rare, "bandage")
		finds.texts.append(text)
	finds.texts = finds.texts.filter(func(t): return t != "")
	AHStationRules.adjust(campaign, "scrap", finds.scrap)
	AHStationRules.adjust(campaign, "seeds", finds.seeds)
	AHStationRules.adjust(campaign, "fragments", finds.fragments)
	AHStationRules.adjust(campaign, "bandages", finds.bandages)
	if finds.tool != "":
		AHJourneyRules.grant_tool(campaign, finds.tool)
	if finds.relic != "":
		campaign.inventory.relics.append(finds.relic)
	return finds


## A linha do sorteio que saiu (as chances somadas, de 1 a 100), ou {} (nada).
static func _pick(rolls: Array, roll: int) -> Dictionary:
	var top := 0
	for entry in rolls:
		top += int(entry.get("Chance", 0))
		if roll <= top:
			return entry
	return {}


static func _rare_text(rare: Dictionary, kind: String) -> String:
	for entry in rare.get("Rolls", []):
		if String(entry.get("Kind", "")) == kind:
			return String(entry.get("Text", ""))
	return ""


## As relíquias que a equipe ainda não tem (nem no estoque nem equipadas), em ordem.
static func _new_relics(campaign: Dictionary) -> Array:
	var owned: Array = campaign.inventory.get("relics", []).duplicate()
	for entry in campaign.roster:
		owned.append(String(entry.get("relic_id", "")))
	var out: Array = GameData.table("relics").keys().filter(func(id): return not owned.has(String(id)))
	out.sort()
	return out


# ================================================================ os textos

static func floor_name(floor_number: int) -> String:
	return TranslationServer.translate("%dº subsolo") % floor_number


## "o 2º subsolo, vaga 5" ou "o patamar do 2º subsolo".
static func block_name(key: String) -> String:
	if is_landing(key):
		return TranslationServer.translate("o patamar do %dº subsolo") % block_floor(key)
	return TranslationServer.translate("o %dº subsolo, vaga %d") % [block_floor(key), block_slot(key)]


## "3 sucatas e um curativo": o que o bloco devolveu.
static func finds_text(finds: Dictionary) -> String:
	var parts: Array = []
	var scrap := int(finds.get("scrap", 0))
	var seeds := int(finds.get("seeds", 0))
	var fragments := int(finds.get("fragments", 0))
	if scrap > 0:
		parts.append(TranslationServer.translate("1 sucata") if scrap == 1 else TranslationServer.translate("%d sucatas") % scrap)
	if seeds > 0:
		parts.append(TranslationServer.translate("1 semente") if seeds == 1 else TranslationServer.translate("%d sementes") % seeds)
	if fragments > 0:
		parts.append(TranslationServer.translate("1 fragmento") if fragments == 1 else TranslationServer.translate("%d fragmentos") % fragments)
	if int(finds.get("bandages", 0)) > 0:
		parts.append(TranslationServer.translate("um curativo"))
	match String(finds.get("tool", "")):
		"lanterna":
			parts.append(TranslationServer.translate("uma lanterna"))
		"mascara":
			parts.append(TranslationServer.translate("uma máscara com filtro"))
		"pe_de_cabra":
			parts.append(TranslationServer.translate("um pé de cabra"))
	var relic = GameData.row("relics", String(finds.get("relic", "")))
	if relic != null:
		parts.append(TranslationServer.translate("a relíquia %s") % TranslationServer.translate(String(relic.DisplayName)))
	if parts.size() <= 1:
		return "" if parts.is_empty() else parts[0]
	return TranslationServer.translate("%s e %s") % [", ".join(parts.slice(0, parts.size() - 1)), parts[-1]]


## A linha do relatório da volta: "Escavação: o 2º subsolo, vaga 5, foi aberto. 3 sucatas e um curativo." ou o andamento.
static func report_line(dig: Dictionary) -> String:
	if dig.is_empty():
		return ""
	var key := String(dig.get("block", ""))
	if dig.get("opened", false):
		var found := finds_text(dig.get("finds", {}))
		return TranslationServer.translate("Escavação: %s foi aberto. %s.") % [block_name(key), found.left(1).to_upper() + found.substr(1)]
	return TranslationServer.translate("Escavação: %s, %d de %d pontos de obra.") % [block_name(key), int(dig.get("progress", 0)), int(dig.get("work", 1))]


## "1 volta", "3 voltas".
static func returns_text(count: int) -> String:
	return TranslationServer.translate("1 volta") if count == 1 else TranslationServer.translate("%d voltas") % count


## O Próximo passo de escavar (#186, ponto 7), ou {} sem bloco para escavar. A escavação anda com as voltas: o botão leva
## ao mapa.
static func dig_step(campaign: Dictionary) -> Dictionary:
	var key := dig_target(campaign)
	if key == "":
		return {}
	var title := TranslationServer.translate("Escavar o patamar do %dº subsolo") % block_floor(key) if is_landing(key) \
		else TranslationServer.translate("Escavar o entulho do %dº subsolo") % block_floor(key)
	return {"title": title, "text": TranslationServer.translate("Quem fica na Estação cava enquanto a equipe está fora. Este bloco abre em %s.") % returns_text(returns_left(campaign, key)),
		"action": "depart", "button": TranslationServer.translate("Ir ao mapa"), "room": "", "block": key}


# ================================================================ a primeira volta

## A fala da primeira volta com escavação ainda não apareceu, e a última volta escavou.
static func intro_pending(campaign: Dictionary) -> bool:
	return not bool(grid(campaign).get("intro_seen", false)) and not campaign.station.get("last_return", {}).get("dig", {}).is_empty()


static func see_intro(campaign: Dictionary) -> void:
	grid(campaign).intro_seen = true


## A fala (#186, ponto 10): [{speaker, text}] com o Bento e o Nick na Estação, de pé; senão, só o cartão ([{speaker "",
## text}]).
static func intro_lines(campaign: Dictionary) -> Array:
	var row := rule("intro")
	for hero_id in [BENTO, NICK]:
		var entry = AHStationRules.hero(campaign, hero_id)
		if entry == null or not entry.get("alive", true) or AHStationRules.recovering(entry):
			return [{"speaker": "", "text": String(row.get("Card", ""))}]
	return row.get("Lines", []).map(func(line): return {"speaker": String(line.Speaker), "text": String(line.Text)})
