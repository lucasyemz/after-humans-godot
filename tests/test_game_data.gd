## GameData: as tabelas de produção carregam e as referências entre elas existem.
extends RefCounted


func run(t) -> void:
	t.check(GameData.issues.is_empty(), "problemas ao carregar: %s" % "; ".join(GameData.issues))
	for table_name in ["classes", "abilities", "enemies", "enemy_actions", "perks", "instinct", "relics", "research",
			"encounters", "events", "expedition_nodes", "initial_heroes", "scenarios", "search_outcomes"]:
		t.check(not GameData.table(table_name).is_empty(), "tabela %s vazia ou ausente" % table_name)
	for class_id in ["cao", "gato", "sapo", "coruja"]:
		t.check(GameData.row("classes", class_id) != null, "classe fundadora %s ausente" % class_id)
	t.check(GameData.row("instinct", "Default") != null, "regras de instinto (Default) ausentes")
	t.check(GameData.row("classes", "não-existe") == null, "row() devolve null para id desconhecido")
	t.check(not GameData.combat.abilities.is_empty() and not GameData.combat.enemies.is_empty(), "tabelas tipadas do combate vazias")
	t.equal(GameData.combat.classes.size(), GameData.table("classes").size(), "o combate e o GameData leem as mesmas classes")
	t.note("%d tabelas" % GameData.tables.size())
