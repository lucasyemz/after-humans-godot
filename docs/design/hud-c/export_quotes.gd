extends SceneTree
func _initialize():
	call_deferred("_run")
func _run():
	await process_frame
	var campaign=root.get_node("Campaign")
	var c=campaign.create_initial(6)
	var result={}
	for name in ["combat","combat-boss"]:
		var meta=JSON.parse_string(FileAccess.get_file_as_string("res://docs/design/loop-screens/before/"+name+".json"))
		var enemies=[]
		for u in meta.units:
			if not u.player:enemies.append({"enemy_id":u.enemy_id,"unit_id":u.id,"rank":int(u.rank),"hp":int(u.hp),"max_hp":int(u.max_hp),"display_name":u.name})
		var session=load("res://scripts/combat/combat_session.gd").create(c.roster,enemies,false,4242)
		for u in meta.units:
			var actual=session.state.find_unit(u.id)
			assert(actual!=null and actual.hp==int(u.hp) and actual.max_hp==int(u.max_hp))
			actual.instinct=float(u.instinct)
		session.state.current_turn_unit_id=meta.actor
		result[name]={"actor":meta.actor,"options":session.ability_options(meta.actor),"can_flee":session.can_flee(),"move_targets":session.move_targets(meta.actor),"source":"AHCombatSession reconstructed from captured DTOs + initial roster6"}
	FileAccess.open("res://docs/design/hud-c/session_quotes.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("HUD quotes exported; snapshots matched")
	quit()
