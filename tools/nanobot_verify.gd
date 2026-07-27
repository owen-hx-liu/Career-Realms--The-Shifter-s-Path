extends Node

# Headless logic test for the hospital / nanobot quest fix.
# Run: Godot --headless --path . res://tools/nanobot_verify.tscn

func _ready() -> void:
	await get_tree().process_frame
	var results: Array = []

	# --- SceneManager autoload (drives every door / level transition) ---
	var sm = get_node_or_null("/root/SceneManager")
	results.append(["SceneManager autoload present", sm != null])
	results.append(["SceneManager.change_scene() exists", sm != null and sm.has_method("change_scene")])
	results.append(["SceneManager overlay (ColorRect) wired", get_node_or_null("/root/SceneManager/ColorRect") != null])
	results.append(["SceneManager AnimationPlayer wired", get_node_or_null("/root/SceneManager/AnimationPlayer") != null])

	# --- Global autoload (hospital quest state) ---
	var g = get_node_or_null("/root/Global")
	var lower = get_node_or_null("/root/global")
	results.append(["Global autoload present", g != null])
	results.append(["Global is distinct from lowercase 'global'", g != null and lower != null and g != lower])
	if g != null:
		g.completed_patients = ["patient_1", "patient_2", "patient_3", "patient_4"]
		results.append(["all_patients_complete() == true when all done", g.all_patients_complete() == true])
		g.completed_patients = ["patient_1", "patient_3"]
		results.append(["all_patients_complete() == false when partial", g.all_patients_complete() == false])

	# --- Congrats finale path: room loads with all-complete state ---
	if g != null:
		g.completed_patients = ["patient_1", "patient_2", "patient_3", "patient_4"]
		g.spawn_point = "from_level"
		var room = load("res://scenes/patient_1_room.tscn").instantiate()
		add_child(room)
		await get_tree().process_frame
		var cong = room.get_node_or_null("CongratsScreen")
		results.append(["patient_1_room has CongratsScreen node", cong != null])
		results.append(["show_congrats() fired (CongratsScreen visible)", cong != null and cong.visible == true])
		room.queue_free()

	# --- world_3 NPC script restored ---
	var npc_script = load("res://scenes/npc.gd")
	results.append(["world_3 NPC script (scenes/npc.gd) loads", npc_script != null])

	print("\n========== NANOBOT QUEST VERIFY ==========")
	var all_pass := true
	for r in results:
		var ok: bool = r[1]
		if not ok:
			all_pass = false
		print(("[PASS] " if ok else "[FAIL] ") + str(r[0]))
	print("========== RESULT: " + ("ALL PASS" if all_pass else "SOME FAILED") + " ==========\n")
	get_tree().quit()
