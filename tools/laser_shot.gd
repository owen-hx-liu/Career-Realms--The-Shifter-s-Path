extends Node
# Offline screenshots + solvability self-test for the PRISM ARRAY laser quest.
# Applies each chamber's authored solution to prove a win is reachable, and
# saves PNGs of the intro, a richly-built board, an interstitial and victory.
# Run windowed:  Godot --path . res://tools/laser_shot.tscn

const QUEST := preload("res://scenes/laser_quest.tscn")

var quest
var out_dir: String
var results := []


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	out_dir = OS.get_user_data_dir() + "/laser_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("SHOT_DIR=", out_dir)

	quest = QUEST.instantiate()
	quest.record_on_win = false
	add_child(quest)
	await _wait(12)
	await _shot("01_intro")

	# ---- Chamber 1 : solve fully, capture the "cleared" panel --------------
	quest._start_run()
	await _wait(10)
	await _solve_current("CHAMBER 1")
	await _wait(6)
	await _shot("02_interstitial")

	# ---- Chamber 2 : advance + solve --------------------------------------
	quest._next_level()
	await _wait(10)
	await _solve_current("CHAMBER 2")

	# ---- Chamber 3 : showcase a partial board, then finish -----------------
	quest._next_level()
	await _wait(10)
	var n: int = quest.debug_solution_size()
	for i in range(n - 1):                        # all but the last piece
		quest.debug_place_piece(i)
		await _wait(3)
	await _wait(8)
	await _shot("03_play")                        # rich winding beam, partial
	quest.debug_place_piece(n - 1)                # complete it -> victory
	await _wait(8)
	var lit3: bool = quest._all_lit()
	results.append({"name": "CHAMBER 3", "ok": lit3})
	print("CHAMBER 3  solved=", lit3, "  phase=", quest.phase)
	await _wait(6)
	await _shot("04_victory")

	# ---- report ------------------------------------------------------------
	var all_ok := true
	for r in results:
		print("  ", r.name, " -> ", "PASS" if r.ok else "FAIL")
		all_ok = all_ok and r.ok
	print("LASER_SELFTEST=", "PASS" if all_ok else "FAIL")
	print("SHOT_DONE  stars=", quest._star_rating(), "  pieces=", quest.pieces_used_total, "/", quest.par_total)

	# verify the StarManager / EndingManager recording path for "laser_quest"
	quest._record(4)
	var sm = get_node_or_null("/root/StarManager")
	var em = get_node_or_null("/root/EndingManager")
	var rec_stars = sm.get_quest_stars("laser_quest") if sm else -1
	var rec_done = em.is_quest_completed("laser_quest", "Art") if em else false
	print("RECORD_CHECK  star_manager=", rec_stars, "  ending_complete=", rec_done,
		"  ->  ", ("PASS" if rec_stars >= 4 and rec_done else "FAIL"))
	get_tree().quit()


func _solve_current(label: String) -> void:
	quest.debug_apply_solution()
	await _wait(6)
	var ok: bool = quest._all_lit()
	results.append({"name": label, "ok": ok})
	print(label, "  solved=", ok, "  phase=", quest.phase)


func _wait(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err := img.save_png(out_dir + "/" + name + ".png")
	print("SHOT_SAVED ", name, " err=", err)
