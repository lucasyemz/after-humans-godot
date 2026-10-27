## Tipos do combate, espelhando Source/AfterHumans/Combat/AHCombatTypes.h.
class_name AHCombat
extends RefCounted

enum EventType { DAMAGE, HEAL, INSTINCT, DODGE, BLOCK, CRIT, DEATH, CRISIS, INFO }
enum Outcome { NONE, BLOCK_GRANTED, GUARD_GRANTED, STUN_APPLIED, VULNERABILITY_REMOVED, INSTINCT_REDUCED, DODGE_GRANTED, DOT_CLEANSED, MARK_APPLIED, BLIND_APPLIED }
enum Crisis { NONE, COLLAPSE, BREAKTHROUGH }


class Event:
	var text := ""
	var type := EventType.INFO
	var outcome := Outcome.NONE
	var target_unit_id := ""
	var ability_id := ""
	var amount := 0
	var turn_skipped_stun := false
	## O CRIT do golpe crítico sorteado (não a troca de fase do chefe, que também é CRIT): a tela do impacto (#33).
	var critical_roll := false


class Tokens:
	var block := 0
	var dodge := 0
	var vuln := 0
	var guard := 0
	var mark := 0


## Dano por turno (sangramento, contaminação). Duração 0 = nenhum.
class Dot:
	var magnitude := 0
	var duration := 0

	func is_set() -> bool:
		return duration > 0 and magnitude > 0

	func clear() -> void:
		magnitude = 0
		duration = 0


class Unit:
	var id := ""
	var is_player := false
	var hero_id := ""
	var enemy_id := ""
	var class_id := ""
	var display_name := ""
	## 1 a 4; 0 = fora da formação (morto).
	var rank := 1
	var hp := 1
	var max_hp := 1
	var speed := 0
	var damage_bonus := 0
	var instinct := 0
	var perks: Array = []
	var crisis_outcome := Crisis.NONE
	var crisis_count := 0
	var instinct_history: Array = []
	var perk_activations := {}
	var deaths_door := false
	var tokens := Tokens.new()
	var guard_target_rank := 0
	var guard_for_turn := false
	var guard_target_id := ""
	var armor_break_turns := 0
	var bleed := Dot.new()
	var blight := Dot.new()
	var stun_turns := 0
	var blind := false
	var weak := false
	var immobilize_turns := 0
	var mark_duration := 0
	var cooldowns := {}
	var remaining_uses := {}
	## +n nos limites de dano ou cura de uma habilidade (o nível do herói, #90): {ability_id: n}.
	var ability_bonus := {}
	var trauma := false
	var sprite_key := ""

	func is_standing() -> bool:
		return hp > 0 or (is_player and deaths_door)


class InitiativeItem:
	var unit_id := ""
	var is_player := false
	var initiative := 0
	var acted := false


class State:
	var round := 1
	var current_turn_unit_id := ""
	var initiative_queue: Array = []
	var player_team: Array = []
	var enemy_team: Array = []
	var combat_log: PackedStringArray = []
	var is_over := false
	var victory := false
	var escaped := false
	var boss_phase := 1
	var enemy_target_history: Array = []
	var processed_player_turn_key := ""
	var deaths: Array = []

	func find_unit(unit_id: String) -> Unit:
		for unit in player_team:
			if unit.id == unit_id:
				return unit
		for unit in enemy_team:
			if unit.id == unit_id:
				return unit
		return null


class Context:
	var hope := 80
	## "heroiA_heroiB" (ordenados) -> -3 a +3.
	var relationships := {}
	var researched_skills: Array = []
	## Só a paridade com as gravações da web liga (ver bLegacyWebAdvanceSwap no C++).
	var legacy_web_advance_swap := false
	## A vida de um herói não desce disto (0: desce até o Último Fôlego). O tutorial (#144) usa 1: ninguém cai.
	var min_hero_hp := 0


class ActionResult:
	var success := false
	var error := ""
	var escaped := false
	var events: Array = []
	var used_ability_id := ""
