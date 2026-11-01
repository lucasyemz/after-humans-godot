## As missões solo (#183, decisão do Lucas de 28/10): com a Preparação no nível 2, um mapa secundário mostra a cada dia
## algumas missões em lugares sorteados; o jogador manda (ou não) um herói em cada uma. Quem está em missão sai da
## equipe, do posto e da noite. No dia da volta, um sorteio contra a chance (a aptidão da classe, o nível, a vida, os
## traços e o estado) diz se deu certo (a recompensa inteira e XP), se volta ferido (35% da vida e metade) ou se foi
## capturado pelos robôs: aí vira um pino de resgate no mapa, prioritário e sem prazo (o resgate entra na rota, #188).
## Os números ficam em data/side-missions.json (a linha "rules"); o estado, em campaign.station.side_missions e no
## herói (side_mission em curso, captured).
class_name AHSideMissions
extends RefCounted

const S = preload("res://scripts/flow/station_rules.gd")
const J = preload("res://scripts/flow/journey_rules.gd")


static func rules() -> Dictionary:
	var row = GameData.row("side_missions", "rules")
	return row if row != null else {}


static func mission(mission_id: String) -> Dictionary:
	var row = GameData.row("side_missions", mission_id)
	return row if row != null and String(row.get("Kind", "")) == "mission" else {}


static func missions() -> Array:
	return GameData.table("side_missions").values().filter(func(row): return String(row.get("Kind", "")) == "mission")


## A aba abre com a Preparação no nível UnlockLevel.
static func unlocked(campaign: Dictionary) -> bool:
	return S.room_level(campaign, S.PREPARATION) >= int(rules().get("UnlockLevel", 2))


## O estado das missões na Estação: o quadro do dia (day, board), os relatórios de quem voltou (reports) e a semente
## dos sorteios (seed, sorteada no primeiro uso; a mesma ao salvar e voltar).
static func state(campaign: Dictionary) -> Dictionary:
	var station: Dictionary = campaign.station
	if typeof(station.get("side_missions")) != TYPE_DICTIONARY:
		station.side_missions = {"day": -1, "board": [], "reports": []}
	if not station.side_missions.has("seed"):
		station.side_missions.seed = randi()
	return station.side_missions


static func day(campaign: Dictionary) -> int:
	return int(campaign.station.get("cycle_number", 0))


## O índice (0 a 4) da fase mais alta liberada.
static func _phase_index(campaign: Dictionary) -> int:
	var best := 0
	for index in J.PHASES.size():
		if S.phase_unlocked(campaign, J.PHASES[index].id):
			best = index
	return best


static func _phase_of(phase_id: String) -> int:
	for index in J.PHASES.size():
		if J.PHASES[index].id == phase_id:
			return index
	return 0


## O quadro de hoje: [{id, spot}]. Um dia novo troca as missões que ninguém pegou (pela semente da campanha e do dia);
## a que está em curso não volta ao quadro.
static func board(campaign: Dictionary) -> Array:
	var st := state(campaign)
	if int(st.day) != day(campaign):
		st.day = day(campaign)
		st.board = _draw_board(campaign)
	return st.board


static func _draw_board(campaign: Dictionary) -> Array:
	var r := rules()
	var counts: Array = r.get("Board", [2])
	var count := int(counts[mini(_phase_index(campaign), counts.size() - 1)])
	var busy: Array = running(campaign).map(func(entry): return String(entry.side_mission.id))
	var pool: Array = missions().filter(func(row): return _phase_of(String(row.MinPhase)) <= _phase_index(campaign) and not busy.has(String(row.Name)))
	pool.sort_custom(func(a, b): return String(a.Name) < String(b.Name))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("missions:%d:%d" % [int(state(campaign).seed), day(campaign)])
	var spots: Array = range(Array(r.get("Spots", [])).size())
	var out: Array = []
	while out.size() < count and not pool.is_empty():
		var total := 0
		for row in pool:
			total += int(row.get("Weight", 1))
		var pick := rng.randi_range(1, maxi(1, total))
		var chosen = pool[0]
		for row in pool:
			pick -= int(row.get("Weight", 1))
			if pick <= 0:
				chosen = row
				break
		pool.erase(chosen)
		var spot := -1
		if not spots.is_empty():
			spot = spots.pop_at(rng.randi_range(0, spots.size() - 1))
		out.append({"id": String(chosen.Name), "spot": spot})
	return out


## A posição do lugar no mapa (nas medidas da pintura do Mapa da Rede, 1120 × 630).
static func spot_position(index: int) -> Vector2:
	var spots: Array = rules().get("Spots", [])
	if index < 0 or index >= spots.size():
		return Vector2(560, 315)
	return Vector2(float(spots[index][0]), float(spots[index][1]))


## Quem está numa missão agora.
static func running(campaign: Dictionary) -> Array:
	return campaign.roster.filter(func(entry): return typeof(entry.get("side_mission")) == TYPE_DICTIONARY)


## Quem foi capturado pelos robôs e espera o resgate.
static func captured(campaign: Dictionary) -> Array:
	return campaign.roster.filter(func(entry): return typeof(entry.get("captured")) == TYPE_DICTIONARY)


## Fora da Estação: numa missão ou capturado. Não parte, não pega posto e não passa a noite.
static func away(entry) -> bool:
	return entry != null and (typeof(entry.get("side_mission")) == TYPE_DICTIONARY or typeof(entry.get("captured")) == TYPE_DICTIONARY)


## Por que o herói está fora ("" se não está).
static func away_text(entry) -> String:
	if entry == null:
		return ""
	if typeof(entry.get("captured")) == TYPE_DICTIONARY:
		return TranslationServer.translate("%s está com os robôs e espera o resgate.") % entry.display_name
	if typeof(entry.get("side_mission")) == TYPE_DICTIONARY:
		var row := mission(String(entry.side_mission.id))
		return TranslationServer.translate("%s está numa missão solo (%s).") % [entry.display_name, TranslationServer.translate(String(row.get("Title", "")))]
	return ""


## Quantos dias faltam para a volta (1: volta no próximo dia).
static func days_left(campaign: Dictionary, entry: Dictionary) -> int:
	return maxi(0, int(entry.side_mission.back) - day(campaign))


## O nível da missão: o da fase dela (1, 3, 5, 7 ou 9).
static func mission_level(row: Dictionary) -> int:
	return int(J.PHASES[_phase_of(String(row.get("MinPhase", "fase_1")))].level)


## A chance de dar certo (de MinChance a MaxChance), escondida do jogador: a tela mostra só o selo.
static func chance(campaign: Dictionary, entry: Dictionary, mission_id: String) -> int:
	var r := rules()
	var row := mission(mission_id)
	if row.is_empty():
		return 0
	var bases: Array = r.get("BaseByDanger", [50, 40, 30])
	var value := int(bases[clampi(int(row.Danger) - 1, 0, bases.size() - 1)])
	var class_id := String(entry.get("class_id", ""))
	var aptitudes: Dictionary = r.get("Aptitudes", {})
	for need in row.get("Needs", []):
		var spec: Dictionary = aptitudes.get(need, {})
		if spec.get("Strong", []).has(class_id):
			value += int(r.get("Strong", 20))
		elif spec.get("Partial", []).has(class_id):
			value += int(r.get("Partial", 10))
	var diff := AHHeroLevels.level(entry) - mission_level(row)
	if diff > 0:
		value += mini(diff * int(r.get("LevelUp", 3)), int(r.get("LevelUpMax", 15)))
	elif diff < 0:
		value += diff * int(r.get("LevelDown", 8))
	var max_hp := maxi(1, int(entry.get("max_hp", 1)))
	value -= roundi(float(r.get("HpMax", 30)) * float(max_hp - clampi(int(entry.get("hp", max_hp)), 0, max_hp)) / max_hp)
	for perk in r.get("Perks", []):
		if entry.get("perks", []).has(perk.Perk) and (String(perk.get("Need", "")) == "" or row.get("Needs", []).has(perk.Need)):
			value += int(perk.Value)
	if bool(entry.get("trauma", false)):
		value -= int(r.get("Trauma", 10))
	if int(entry.get("instinct", 0)) >= int(r.get("CrisisAt", 120)):
		value -= int(r.get("Crisis", 10))
	return clampi(value, int(r.get("MinChance", 5)), int(r.get("MaxChance", 95)))


## O selo vago da chance: "good", "risky" ou "very_risky".
static func hint(value: int) -> String:
	var r := rules()
	if value >= int(r.get("GoodFrom", 65)):
		return "good"
	if value >= int(r.get("RiskyFrom", 40)):
		return "risky"
	return "very_risky"


static func hint_text(hint_id: String) -> String:
	match hint_id:
		"good":
			return TranslationServer.translate("Boa escolha")
		"risky":
			return TranslationServer.translate("Arriscado")
	return TranslationServer.translate("Muito arriscado")


## A comida que a missão leva (FoodPerDay por dia).
static func food_cost(mission_id: String) -> int:
	return int(mission(mission_id).get("Days", 1)) * int(rules().get("FoodPerDay", 1))


## Por que o herói não pode ir ("" pode).
static func send_block(campaign: Dictionary, hero_id: String, mission_id: String) -> String:
	if not unlocked(campaign):
		return TranslationServer.translate("Melhore a Preparação para mandar missões solo.")
	if not board(campaign).any(func(spot): return spot.id == mission_id):
		return TranslationServer.translate("Essa missão não está no quadro de hoje.")
	var entry = S.hero(campaign, hero_id)
	if entry == null or not entry.alive:
		return TranslationServer.translate("Esse herói não está na Estação.")
	if away(entry):
		return away_text(entry)
	if not S.can_deploy(entry):
		return S.deploy_block(entry)
	if running(campaign).size() >= int(rules().get("MaxActive", 2)):
		return TranslationServer.translate("Já há %d missões em curso.") % int(rules().get("MaxActive", 2))
	if S.quantity(campaign, S.SUPPLIES) < food_cost(mission_id):
		return TranslationServer.translate("Faltam suprimentos: a missão leva %d.") % food_cost(mission_id)
	return ""


## Manda o herói: paga a comida, tira do posto e marca a volta. A missão sai do quadro.
static func send(campaign: Dictionary, hero_id: String, mission_id: String) -> String:
	var block := send_block(campaign, hero_id, mission_id)
	if block != "":
		return block
	S.consume(campaign, S.SUPPLIES, food_cost(mission_id))
	S.leave_posts(campaign, [hero_id])
	var entry = S.hero(campaign, hero_id)
	var st := state(campaign)
	var spot: int = st.board.filter(func(item): return item.id == mission_id)[0].spot
	entry.side_mission = {"id": mission_id, "spot": spot, "sent": day(campaign), "back": day(campaign) + int(mission(mission_id).get("Days", 1))}
	st.board = st.board.filter(func(spot): return spot.id != mission_id)
	return ""


## Um dia novo (run_cycle): quem chegou ao dia da volta resolve a missão. Devolve os relatórios novos.
static func on_new_day(campaign: Dictionary) -> Array:
	var out: Array = []
	for entry in running(campaign):
		if int(entry.side_mission.back) <= day(campaign):
			out.append(_resolve(campaign, entry))
	if not out.is_empty():
		state(campaign).reports = out
	return out


## O resultado de uma missão: o sorteio (a semente da campanha, do herói e do dia da saída) contra a chance.
static func _resolve(campaign: Dictionary, entry: Dictionary) -> Dictionary:
	var r := rules()
	var mission_id := String(entry.side_mission.id)
	var row := mission(mission_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("mission:%d:%s:%d" % [int(state(campaign).seed), entry.id, int(entry.side_mission.sent)])
	var value := chance(campaign, entry, mission_id)
	var roll := rng.randi_range(0, 99)
	var entry_spot = entry.side_mission.get("spot", -1)
	entry.erase("side_mission")
	var report := {"hero_id": entry.id, "mission": mission_id, "day": day(campaign), "reward": {}}
	if roll < value:
		report.result = "success"
		report.reward = _reward(campaign, row, rng, false)
		report.xp = AHHeroLevels.gain(entry, int(r.get("Xp", 10)))
	elif roll < value + int(r.get("HurtBand", 25)):
		report.result = "hurt"
		entry.hp = maxi(1, ceili(int(entry.max_hp) * float(r.get("HurtHp", 0.35))))
		report.reward = _reward(campaign, row, rng, true)
	else:
		report.result = "captured"
		entry.captured = {"mission": mission_id, "spot": int(entry_spot), "phase": String(row.get("MinPhase", "fase_1")), "day": day(campaign)}
	return report


## A recompensa da missão: o tipo dela com a faixa da carga recuperada da fase mais alta liberada; a relíquia só nas de
## RelicChance, em 1 de 14 (o peso da carga). half: metade, arredondada para baixo, e nunca a relíquia.
static func _reward(campaign: Dictionary, row: Dictionary, rng: RandomNumberGenerator, half: bool) -> Dictionary:
	var phase_id: String = J.PHASES[_phase_index(campaign)].id
	var cargo = GameData.row("recovered_cargo", phase_id)
	var kind := String(row.get("Reward", "seeds"))
	var amount := 1
	for item in (cargo.get("Items", []) if cargo != null else []):
		if String(item.Kind) == kind:
			amount = rng.randi_range(int(item.Min), int(item.Max))
	if half:
		amount = amount / 2
	var reward := {"kind": kind, "amount": amount, "relic_id": ""}
	if amount > 0:
		S.adjust(campaign, S.SUPPLIES if kind == "supplies" else kind, amount)
	if not half and int(row.get("RelicChance", 0)) > 0 and rng.randi_range(1, 14) == 1:
		var relics: Array = GameData.table("relics").keys()
		relics.sort()
		if not relics.is_empty():
			reward.relic_id = relics[rng.randi_range(0, relics.size() - 1)]
			campaign.inventory.relics.append(reward.relic_id)
	return reward


## A linha do relatório ("Casco voltou das Galerias com +3 sementes").
static func report_line(campaign: Dictionary, report: Dictionary) -> String:
	var entry = S.hero(campaign, String(report.hero_id))
	var hero_name: String = entry.display_name if entry != null else "?"
	var title := TranslationServer.translate(String(mission(String(report.mission)).get("Title", "")))
	var found := PackedStringArray()
	var reward: Dictionary = report.get("reward", {})
	if int(reward.get("amount", 0)) > 0:
		found.append(AHFightRewards.box_text({"kind": reward.kind, "amount": reward.amount}))
	if String(reward.get("relic_id", "")) != "":
		found.append(AHFightRewards.box_text({"kind": "relic", "relic_id": reward.relic_id}))
	match String(report.get("result", "")):
		"success":
			return TranslationServer.translate("%s voltou de %s com %s.") % [hero_name, title, ", ".join(found)] if not found.is_empty() \
				else TranslationServer.translate("%s voltou de %s.") % [hero_name, title]
		"hurt":
			return TranslationServer.translate("%s voltou de %s com ferimentos e com %s.") % [hero_name, title, ", ".join(found)] if not found.is_empty() \
				else TranslationServer.translate("%s voltou de %s com ferimentos e de mãos vazias.") % [hero_name, title]
	return TranslationServer.translate("%s caiu nas mãos dos robôs em %s. O resgate fica marcado no mapa.") % [hero_name, title]
