## O fim da luta que recompensa (#91, a P2 da proposta do laço): as estrelas da luta e a carga recuperada do guardião.
## - As estrelas: a vitória dá 1; os quatro critérios (ninguém caiu, poucas rodadas, o golpe final de um herói, o
##   instinto controlado) dão a 2ª e a 3ª (data/fight-stars.json). A melhor nota do guardião de cada fase fica no save
##   (campaign.mission_stars), para a #92 liberar a próxima missão.
## - A carga recuperada: depois do guardião, seis caixas viradas com o que a máquina guardava (data/recovered-cargo.json,
##   por fase), sorteadas pela semente da expedição; o jogador escolhe uma e as outras se revelam. A escolha fica no save
##   (expedition.cargo): salvar e voltar mostra as mesmas caixas e não deixa escolher de novo. O achado entra como o
##   resto do achado da rota (as sementes, a sucata, os fragmentos e os suprimentos chegam na volta) ou na hora (os
##   curativos na Mochila, a relíquia no Depósito).
class_name AHFightRewards
extends RefCounted

const BOXES := 6
## Os ícones de cada coisa da carga (art/ui/icons); a relíquia usa o dela (RELIC_ICONS), como na Mochila.
const ICONS := {"seeds": "lobby-seed", "scrap": "lobby-scrap", "fragments": "lobby-fragment", "supplies": "lobby-food",
	"bandages": "res-bandages", "relic": "relic-generic"}
const RELIC_ICONS := {"botao_cobre": "relic-copper-button", "pena_vidro": "relic-glass-feather", "coleira_lembranca": "relic-memory-collar"}


## O ícone de uma caixa revelada.
static func icon_of(box: Dictionary) -> String:
	if String(box.get("kind", "")) == "relic":
		return RELIC_ICONS.get(String(box.get("relic_id", "")), "relic-generic")
	return ICONS.get(String(box.get("kind", "")), "item-generic")


## Os critérios da luta vencida: [{id, met, text}] e as estrelas. boss: a luta do guardião (o par de rodadas é outro).
static func criteria(session: AHCombatSession, boss: bool) -> Dictionary:
	var state: AHCombat.State = session.state
	var rounds_row = GameData.row("fight_stars", "rounds")
	var par := int(rounds_row.get("Boss" if boss else "Patrol", 99)) if rounds_row != null else 99
	var fell: bool = state.player_team.any(func(u): return u.hp <= 0)
	var collapsed: bool = state.player_team.any(func(u): return u.crisis_outcome == AHCombat.Crisis.COLLAPSE)
	var list := [
		{"id": "no_falls", "met": not fell, "text": TranslationServer.translate("Ninguém caiu")},
		{"id": "rounds", "met": state.round <= par, "text": TranslationServer.translate("Em até %d rodadas (%d)") % [par, state.round]},
		{"id": "final_blow", "met": session.last_down_by_hero, "text": TranslationServer.translate("O golpe final foi de um herói")},
		{"id": "calm", "met": not collapsed, "text": TranslationServer.translate("Instinto controlado (sem colapso)")},
	]
	var met: int = list.filter(func(c): return c.met).size()
	return {"list": list, "met": met, "stars": stars_for(met) if state.victory else 0}


## As estrelas pelo número de critérios cumpridos (a vitória já dá 1).
static func stars_for(met: int) -> int:
	var row = GameData.row("fight_stars", "stars")
	var two := int(row.get("Two", 2)) if row != null else 2
	var three := int(row.get("Three", 4)) if row != null else 4
	return 3 if met >= three else (2 if met >= two else 1)


## Guarda a melhor nota do guardião da fase (campaign.mission_stars).
static func record_stars(campaign: Dictionary, phase_id: String, stars: int) -> void:
	if not campaign.has("mission_stars"):
		campaign.mission_stars = {}
	campaign.mission_stars[phase_id] = maxi(int(campaign.mission_stars.get(phase_id, 0)), stars)


static func stars_of(campaign: Dictionary, phase_id: String) -> int:
	return int(campaign.get("mission_stars", {}).get(phase_id, 0))


## As seis caixas da carga da expedição (sorteadas uma vez, pela semente dela, e guardadas): [{kind, amount, relic_id}].
static func cargo(campaign: Dictionary) -> Dictionary:
	var expedition = campaign.get("session", {}).get("expedition")
	if expedition == null:
		return {}
	if not expedition.has("cargo") or expedition.cargo.is_empty():
		expedition.cargo = {"boxes": _draw(campaign, expedition), "chosen": -1}
	return expedition.cargo


## Há carga para escolher: o guardião desta expedição caiu e a escolha ainda não foi feita.
static func cargo_pending(campaign: Dictionary) -> bool:
	var expedition = campaign.get("session", {}).get("expedition")
	if expedition == null or not expedition.get("objective_completed", false):
		return false
	# Fase sem carga na tabela (ou sorteio vazio): não há o que escolher, e a equipe segue.
	if expedition.has("cargo") and not expedition.cargo.is_empty():
		if expedition.cargo.get("boxes", []).is_empty():
			return false
	elif not has_cargo(String(expedition.get("phase_id", ""))):
		return false
	return int(expedition.get("cargo", {}).get("chosen", -1)) < 0


## A fase tem carga recuperada (uma linha com itens em data/recovered-cargo.json).
static func has_cargo(phase_id: String) -> bool:
	var row = GameData.row("recovered_cargo", phase_id)
	return row != null and not row.get("Items", []).is_empty()


## Escolhe a caixa (0 a 5): o achado dela entra; as outras ficam só reveladas. Devolve o erro ("" deu certo).
static func choose(campaign: Dictionary, index: int) -> String:
	if not cargo_pending(campaign):
		return TranslationServer.translate("A carga já foi escolhida.")
	var boxes: Array = cargo(campaign).boxes
	if index < 0 or index >= boxes.size():
		return TranslationServer.translate("Essa caixa não existe.")
	var expedition: Dictionary = campaign.session.expedition
	var box: Dictionary = boxes[index]
	match String(box.kind):
		"bandages":
			campaign.inventory.bandages = int(campaign.inventory.bandages) + int(box.amount)
		"relic":
			campaign.inventory.relics.append(String(box.relic_id))
		_:
			expedition.loot[box.kind] = int(expedition.loot.get(box.kind, 0)) + int(box.amount)
	expedition.cargo.chosen = index
	return ""


## O texto de uma caixa ("+3 sementes", "Relíquia: Botão de Cobre").
static func box_text(box: Dictionary) -> String:
	var amount := int(box.get("amount", 0))
	match String(box.get("kind", "")):
		"seeds":
			return TranslationServer.translate("+%d sementes") % amount if amount != 1 else TranslationServer.translate("+1 semente")
		"scrap":
			return TranslationServer.translate("+%d sucatas") % amount if amount != 1 else TranslationServer.translate("+1 sucata")
		"fragments":
			return TranslationServer.translate("+%d fragmentos") % amount if amount != 1 else TranslationServer.translate("+1 fragmento")
		"supplies":
			return TranslationServer.translate("+%d suprimentos") % amount if amount != 1 else TranslationServer.translate("+1 suprimento")
		"bandages":
			return TranslationServer.translate("+%d curativos") % amount if amount != 1 else TranslationServer.translate("+1 curativo")
		"relic":
			var relic = GameData.row("relics", String(box.get("relic_id", "")))
			return TranslationServer.translate("Relíquia: %s") % (TranslationServer.translate(String(relic.DisplayName)) if relic else "?")
	return ""


## O sorteio das seis caixas: a semente da expedição (a mesma ao salvar e voltar); no máximo uma relíquia.
static func _draw(campaign: Dictionary, expedition: Dictionary) -> Array:
	var row = GameData.row("recovered_cargo", String(expedition.get("phase_id", "")))
	var items: Array = row.Items if row != null else []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("cargo:%s:%s" % [str(expedition.get("seed", 0)), String(expedition.get("id", ""))])
	var out: Array = []
	var relic_given := false
	for i in BOXES:
		var pool: Array = items.filter(func(item): return item.Kind != "relic" or not relic_given)
		var total := 0
		for item in pool:
			total += int(item.Weight)
		var pick := rng.randi_range(1, maxi(1, total))
		var chosen = pool[0] if not pool.is_empty() else null
		for item in pool:
			pick -= int(item.Weight)
			if pick <= 0:
				chosen = item
				break
		if chosen == null:
			continue
		var box := {"kind": String(chosen.Kind), "amount": rng.randi_range(int(chosen.Min), int(chosen.Max)), "relic_id": ""}
		if box.kind == "relic":
			relic_given = true
			var relics: Array = GameData.table("relics").keys()
			relics.sort()
			box.relic_id = relics[rng.randi_range(0, relics.size() - 1)] if not relics.is_empty() else ""
		out.append(box)
	return out
