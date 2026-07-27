extends Node
# Headless end-to-end test: drives all 5 stages of XENO LAB to completion,
# clicking the story-beat buttons, through to victory. Verifies no runtime errors
# and that the phase chain advances correctly.
# Run: Godot --headless --path . res://tools/playtest.tscn
const QUEST := preload("res://scenes/world_scenes/AlienBioengineeringQuest.tscn")

func _ready() -> void:
	var q = QUEST.instantiate()
	q.auto_return_delay = 0.0
	q.record_on_win = false
	add_child(q)
	await get_tree().process_frame
	await get_tree().process_frame

	_log(q, "after _ready (intro)")
	_click_continue(q)                       # Enter the Lab -> CATCH
	await get_tree().process_frame
	_log(q, "entered CATCH")

	# Stage 1: force the sample quota, tick once to trigger completion beat
	q.c_samples = q.c_goal
	q._catch_tick(0.016)
	_click_continue(q)                       # -> SEQUENCER
	await get_tree().process_frame
	_log(q, "entered SEQUENCER")

	# Stage 2: force cleared quota
	q.q_cleared = q.q_goal
	q._sequencer_tick(0.016)
	_click_continue(q)                       # -> MEMORY
	await get_tree().process_frame
	_log(q, "entered MEMORY")

	# Stage 3: jump past the final round
	q.m_round = q.m_goal_round
	q._next_memory_round()                   # -> beat
	_click_continue(q)                       # -> BIOREACTOR
	await get_tree().process_frame
	_log(q, "entered BIOREACTOR")

	# Stage 4: force full growth, tick to trigger completion
	q.r_growth = 100.0
	q._bioreactor_tick(0.016)
	_click_continue(q)                       # -> BOSS
	await get_tree().process_frame
	_log(q, "entered BOSS")

	# Stage 5: nuke the boss
	q._damage_boss(999.0)                    # -> VICTORY
	await get_tree().process_frame
	await get_tree().process_frame
	_log(q, "after boss kill")

	print("RESULT  phase=", q.phase, " (VICTORY==", q.Phase.VICTORY, ")",
		"  finished=", q.finished,
		"  overlay_visible=", q.overlay.visible,
		"  stars=", q._calc_stars(),
		"  score=", q.score)
	get_tree().quit()

func _click_continue(q) -> void:
	# emit the first Button found under the overlay (the story "continue" button)
	var b := _find_button(q.overlay)
	if b:
		b.pressed.emit()
	else:
		print("  (no continue button found in overlay)")

func _find_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button:
			return c
		var r := _find_button(c)
		if r: return r
	return null

func _log(q, label: String) -> void:
	print("STEP ", label, "  phase=", q.phase, "  integrity=", int(q.integrity), "  score=", q.score)
