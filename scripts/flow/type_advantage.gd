## A vantagem de tipo na tela (#227): a linhagem do herói (a da classe) e a família mecânica do inimigo, quem cada uma
## vence e de quem perde, nos textos da ficha, da inspeção e da mira. A regra é a do motor (AHCombatEngine.type_multiplier),
## lida das mesmas tabelas (GameData.combat: type_classes e type_advantage).
class_name AHTypes
extends RefCounted


static func enabled() -> bool:
	return bool(GameData.combat.type_advantage.Enabled)


## O bônus em pontos percentuais (25 para ×1,25).
static func percent() -> int:
	return roundi((float(GameData.combat.type_advantage.Multiplier) - 1.0) * 100.0)


## A linhagem de uma classe ("" sem).
static func of_class(class_id: String) -> String:
	var hero_class = GameData.combat.classes.get(class_id)
	return String(hero_class.Lineage) if hero_class != null else ""


## A família mecânica de um inimigo ("" sem).
static func of_enemy(enemy_id: String) -> String:
	var enemy = GameData.combat.enemies.get(enemy_id)
	return String(enemy.MechFamily) if enemy != null else ""


## O nome na tela ("Linhagem dos Cães", "Família Perseguidora"); o nome científico fica só nos dados.
static func display(type_id: String) -> String:
	var row = GameData.combat.type_classes.get(type_id)
	return TranslationServer.translate(String(row.DisplayName)) if row != null else ""


## O nome curto ("Cães", "Perseguidores"), para os títulos que precisam caber.
static func short(type_id: String) -> String:
	var row = GameData.combat.type_classes.get(type_id)
	return TranslationServer.translate(String(row.ShortName)) if row != null else ""


## Quem esta classificação vence (recebe dela o dano a mais), pelos ids.
static func beats_ids(type_id: String) -> Array:
	var row = GameData.combat.type_classes.get(type_id)
	return row.Beats.duplicate() if row != null else []


## Quem vence esta classificação (causa nela o dano a mais), pelos ids.
static func beaten_by_ids(type_id: String) -> Array:
	return GameData.combat.type_classes.keys().filter(func(id): return GameData.combat.type_classes[id].Beats.has(type_id))


## Os nomes de quem esta classificação vence.
static func beats(type_id: String) -> Array:
	return beats_ids(type_id).map(display)


## Os nomes de quem vence esta classificação.
static func beaten_by(type_id: String) -> Array:
	return beaten_by_ids(type_id).map(display)


## Os nomes curtos numa frase ("Gatos e Perseguidores").
static func _short_list(ids: Array) -> String:
	var names: Array = ids.map(short)
	if names.size() <= 1:
		return "".join(names)
	return TranslationServer.translate("%s e %s") % [", ".join(names.slice(0, names.size() - 1)), names.back()]


## As linhas da ficha e da inspeção ([título, o que faz, bom?, "type"], como os efeitos passivos; a marca "type" deixa a
## inspeção tirá-las quando não cabem): em quem a classificação
## causa mais dano e de quem recebe mais. O título diz tudo sozinho (sem caber, a inspeção mostra só os títulos). Sem a
## regra ligada (ou sem classificação), nenhuma.
static func sheet_rows(type_id: String) -> Array:
	if not enabled() or display(type_id) == "":
		return []
	var out: Array = [[TranslationServer.translate("Dano +%d%% em %s") % [percent(), _short_list(beats_ids(type_id))],
		TranslationServer.translate("Vantagem de tipo: a %s causa +%d%% de dano direto em: %s") % [display(type_id), percent(), ", ".join(beats(type_id))], true, "type"]]
	var against := beaten_by_ids(type_id)
	if not against.is_empty():
		out.append([TranslationServer.translate("Recebe +%d%% de %s") % [percent(), _short_list(against)],
			TranslationServer.translate("Vantagem de tipo: recebe +%d%% de dano direto de: %s") % [percent(), ", ".join(beaten_by(type_id))], false, "type"])
	return out


## O nome da classificação para a ficha e a inspeção ("Linhagem dos Cães"), vazio com a regra desligada.
static func label(type_id: String) -> String:
	return display(type_id) if enabled() else ""
