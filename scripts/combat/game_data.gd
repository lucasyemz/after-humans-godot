## Tabelas do combate lidas direto dos JSON de produção (Data/*.json), com os mesmos padrões das structs de
## Source/AfterHumans/Data/AHGameData.h. Campos float da Unreal são arredondados para float32, como na DataTable.
class_name AHGameData
extends RefCounted

const RANGE := {"Min": 0, "Max": 0}
const DOT := {"Magnitude": 0, "Duration": 0}

const ABILITY := {
	"RemoveBlock": 0, "CleanseVulnCharges": 0, "ArmorPiercePercent": 0, "MachineDamagePercent": 100,
	"bBlockToSelf": false, "bGuardForTurn": false, "bRequiresMarkOrVuln": false, "bAdjacentTarget": false,
	"bTargetPair": false, "bOrganicOnly": false, "bUsesPerExpedition": false,
	"ClassId": "", "DisplayName": "", "OriginRanks": [], "TargetRanks": [], "TargetType": "SingleEnemy",
	"DamageRange": RANGE, "HealRange": RANGE, "InstinctDelta": 0, "Cooldown": 0, "UsesMax": 0,
	"PushTarget": 0, "AdvanceSelf": 0, "bConsumesMark": false,
	"Inflicts": {
		"ArmorBreakTurns": 0, "bBlind": false, "bWeak": false, "Immobilize": 0, "Stun": 0,
		"Bleed": DOT, "Blight": DOT, "bVuln": false, "bMark": false, "bDodge": false, "Block": 0, "bGuard": false,
	},
	"Cleanses": {"bMark": false, "bBlind": false, "bWeak": false, "bImmobilize": false, "bVuln": false, "bDot": false},
}
## A classe é o papel (#189): a espécie é do indivíduo, e DefaultSpecies é a de quem não tem uma (os fundadores e os saves
## de antes).
## Os atributos por papel (#258): a resistência a dano por turno, a deslocamento e a atordoamento (de 0 a 1) e o crítico a
## mais, em pontos percentuais sobre CRITICAL_CHANCE. Os padrões são os de antes do papel (0,2 de dano por turno e de
## deslocamento, como o motor já fazia com todo herói; nada contra atordoamento; o crítico de todos): os kits históricos
## da paridade, sem as colunas, lutam igual e sorteiam igual.
const CLASS := {"DisplayName": "", "DefaultSpecies": "", "BaseMaxHp": 1, "BaseSpeed": 0, "AbilityIds": [],
	"DotResist": 0.2, "DisplacementResist": 0.2, "StunResist": 0.0, "CritBonus": 0}
## A espécie (#189): a linhagem da vantagem de tipo (#227) e a altura vêm dela; ela não dá atributos.
const SPECIES := {"DisplayName": "", "Lineage": "", "Height": 1.64}
const ENEMY := {
	"DisplayName": "", "Category": "None", "MechFamily": "", "MaxHp": 1, "Speed": 0, "SpriteKey": "", "bIsBoss": false,
	"FormationSize": 0, "DisplacementResist": 0.2, "DotResist": 0.2, "ActionIds": [],
}
const ENEMY_ACTION := {
	"EnemyId": "", "DisplayName": "", "OriginRanks": [], "TargetRanks": [], "TargetType": "SingleAlly",
	"DamageRange": RANGE, "HealRange": RANGE, "InstinctAdd": 0, "Advances": 0, "Retreats": 0,
	"bIsDefend": false, "bIsPhaseTrigger": false,
	"Inflicts": {
		"bBlind": false, "bWeak": false, "Immobilize": 0, "Stun": 0, "Bleed": DOT, "Blight": DOT,
		"bVuln": false, "Push": 0, "Block": 0,
	},
}
const PERK := {"DisplayName": "", "Value": 0.0, "Speed": 0, "Virtue": 0.0}
const RELIC := {"DisplayName": "", "MaxHpBonus": 0, "SpeedBonus": 0, "EventInstinctReduction": 0, "VirtueBonus": 0.0}
## A vantagem de tipo (#227): as classificações (linhagens e famílias mecânicas) e quem vence quem (Beats), e a chave.
const TYPE_CLASS := {"Kind": "", "DisplayName": "", "ShortName": "", "Beats": []}
const TYPE_ADVANTAGE := {"Enabled": false, "Multiplier": 1.25}
const INSTINCT := {"Max": 200, "Crisis": {"Reset": 120, "HpLoss": 0.2, "HpHeal": 0.15, "TokenCap": 3, "BaseVirtue": 0.25}}

var classes := {}
var species := {}
var abilities := {}
var enemies := {}
var enemy_actions := {}
var perks := {}
var relics := {}
var instinct := {}
var type_classes := {}
## {Enabled, Multiplier}: sem a tabela, desligada.
var type_advantage := TYPE_ADVANTAGE.duplicate()


## Valor de float32 (como um float da DataTable lido em double pelo C++).
static func f32(value: float) -> float:
	return PackedFloat32Array([value])[0]


## A espécie de uma unidade de herói (#189): a dela, ou a padrão da classe (sem uma, ou com uma que a tabela não conhece);
## "" sem nenhuma (os kits históricos da
## paridade não têm, e ficam sem linhagem).
func species_of(class_id: String, species_id: String) -> String:
	if species.has(species_id):
		return species_id
	var hero_class = classes.get(class_id)
	return String(hero_class.DefaultSpecies) if hero_class != null else ""


## Carrega as tabelas. kit_dir troca classes e habilidades (a paridade usa os kits históricos).
func load_from(data_dir: String, kit_dir: String = "") -> bool:
	var kits := kit_dir if kit_dir != "" else data_dir
	classes = _load_table(kits.path_join("classes.json"), CLASS)
	if FileAccess.file_exists(data_dir.path_join("species.json")):
		species = _load_table(data_dir.path_join("species.json"), SPECIES)
	abilities = _load_table(kits.path_join("abilities.json"), ABILITY)
	enemies = _load_table(data_dir.path_join("enemies.json"), ENEMY)
	enemy_actions = _load_table(data_dir.path_join("enemy-actions.json"), ENEMY_ACTION)
	perks = _load_table(data_dir.path_join("perks.json"), PERK)
	relics = _load_table(data_dir.path_join("relics.json"), RELIC)
	instinct = _load_table(data_dir.path_join("instinct.json"), INSTINCT)
	if FileAccess.file_exists(data_dir.path_join("type-classes.json")):
		type_classes = _load_table(data_dir.path_join("type-classes.json"), TYPE_CLASS)
	if FileAccess.file_exists(data_dir.path_join("type-advantage.json")):
		type_advantage = _load_table(data_dir.path_join("type-advantage.json"), TYPE_ADVANTAGE).get("TypeAdvantage", type_advantage)
	return not (classes.is_empty() or abilities.is_empty() or enemies.is_empty() or enemy_actions.is_empty())


static func _load_table(path: String, template: Dictionary) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var rows = JSON.parse_string(text)
	var table := {}
	if typeof(rows) != TYPE_ARRAY:
		push_error("Tabela inválida: %s" % path)
		return table
	for row in rows:
		table[String(row["Name"])] = _merge(template, row)
	return table


## Copia o modelo e aplica a linha por cima, convertendo para o tipo do modelo (o JSON da Godot lê números como float).
static func _merge(template: Dictionary, row: Dictionary) -> Dictionary:
	var out := {}
	for key in template:
		var default_value = template[key]
		var has := row.has(key)
		match typeof(default_value):
			TYPE_DICTIONARY:
				out[key] = _merge(default_value, row[key] if has else {})
			TYPE_INT:
				out[key] = int(row[key]) if has else default_value
			TYPE_FLOAT:
				out[key] = f32(float(row[key]) if has else default_value)
			TYPE_BOOL:
				out[key] = bool(row[key]) if has else default_value
			TYPE_ARRAY:
				var items: Array = []
				for item in (row[key] if has else default_value):
					items.append(int(item) if typeof(item) == TYPE_FLOAT else String(item))
				out[key] = items
			_:
				out[key] = String(row[key]) if has else default_value
	return out
