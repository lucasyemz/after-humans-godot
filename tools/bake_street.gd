## Grava a Rua das Vitrines montada (AHStreetSet) em scenes/street_set.tscn, a cena que a rua carrega (#8). Rode de novo só
## quando mudar a montagem em código (scripts/street/street_set.gd): a cena é sobrescrita e o que foi mexido à mão nela
## se perde. Por isso, com a cena já gravada, pede --force.
##   Godot --headless --path . --script res://tools/bake_street.gd -- --force
extends SceneTree


func _initialize() -> void:
	_bake.call_deferred()


func _bake() -> void:
	var force := Array(OS.get_cmdline_user_args()).has("--force")
	var path: String = AHStreetSet.SCENE
	if ResourceLoader.exists(path) and not force:
		printerr("%s já existe (pode ter ajustes feitos no editor). Para sobrescrever: -- --force" % path)
		quit(1)
		return
	var street_set := AHStreetSet.new()
	street_set.name = "StreetSet"
	root.add_child(street_set)
	street_set.build()
	for node in street_set.find_children("*", "", true, false):
		node.owner = street_set
	var scene := PackedScene.new()
	var packed := scene.pack(street_set)
	var saved := ResourceSaver.save(scene, path) if packed == OK else packed
	print("%s: %s (%d nós)" % [path, "gravada" if saved == OK else "erro %d" % saved, street_set.find_children("*", "", true, false).size()])
	quit(0 if saved == OK else 1)
