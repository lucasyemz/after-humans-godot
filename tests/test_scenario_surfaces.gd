## Nenhuma peça visível de cenário sem textura (#62): nem a grade padrão da Unreal (kind "grid", a blocagem), nem um
## material que precisa de imagem e não tem. Água e brilho são cor e luz, e passam. A regra mora também em
## tools/sync_scenarios.py (fix_grid), para a próxima exportação não trazer a grade de volta.
extends RefCounted

const MAPS := ["RiverDock", "RootBridge", "SealedShelter", "TriageGate", "FloodedDepot", "SewerDucts"]
## Os materiais que não usam imagem.
const WITHOUT_TEXTURE := ["water", "glow"]


func run(t) -> void:
	for map in MAPS:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/%s.json" % map))
		var bad: Array = []
		for index in data.parts.size():
			var part: Dictionary = data.parts[index]
			if part.get("hidden", false):
				continue
			for material_index in part.materials:
				var material: Dictionary = data.materials[int(material_index)]
				var kind: String = material.get("kind", "")
				if kind == "grid":
					bad.append("peça %d: a grade" % index)
				elif not WITHOUT_TEXTURE.has(kind) and String(material.get("albedo", "")) == "":
					bad.append("peça %d: %s sem imagem" % [index, kind])
				elif material.has("albedo") and not ResourceLoader.exists(material.albedo):
					bad.append("peça %d: %s não existe" % [index, material.albedo])
		t.check(bad.is_empty(), "%s: nenhuma peça visível sem textura %s" % [map, bad.slice(0, 6)])
