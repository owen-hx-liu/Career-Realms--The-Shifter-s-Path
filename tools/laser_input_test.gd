extends Node
# Input-path test for PRISM ARRAY. Unlike laser_shot (which calls debug_* and
# bypasses input), this pushes REAL synthetic mouse/keyboard events through the
# viewport to prove the grid clicks (_unhandled_input) and toolbar buttons (GUI)
# actually fire.  Run windowed:  Godot --path . res://tools/laser_input_test.gd

const QUEST := preload("res://scenes/laser_quest.tscn")
var quest


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	quest = QUEST.instantiate()
	quest.record_on_win = false
	add_child(quest)
	await _wait(12)

	quest._start_run()
	await _wait(12)
	print("PHASE after start_run = ", quest.phase, "  (PLAY enum = ", quest.Phase.PLAY, ")")
	print("chamber=", quest.level_index, " mirrors_left=", quest.mirrors_left,
		" prisms_left=", quest.prisms_left, " tool=", quest.tool)

	# ---- TEST 1: grid left-click places a piece (board input path) -----------
	var cell := Vector2i(8, 1)                 # empty placeable cell in chamber 1
	var before: int = quest.pieces.size()
	_click(quest.cell_center(cell))
	await _wait(4)
	var after: int = quest.pieces.size()
	print("TEST1 grid-click place: pieces ", before, " -> ", after,
		"  placed_at_cell=", quest.pieces.has(cell),
		"  => ", ("PASS" if after == before + 1 else "FAIL"))

	# ---- TEST 2: keyboard M/P tool switch (_unhandled_input key path) ---------
	# jump to chamber 2 where prism stock > 0 so the switch is observable
	quest._next_level()
	await _wait(10)
	print("now chamber=", quest.level_index, " tool=", quest.tool,
		" prisms_left=", quest.prisms_left)
	_key(KEY_P)
	await _wait(3)
	var tool_after_p: String = quest.tool
	_key(KEY_M)
	await _wait(3)
	var tool_after_m: String = quest.tool
	print("TEST2 keyboard P then M: ", tool_after_p, " / ", tool_after_m,
		"  => ", ("PASS" if tool_after_p == "prism" and tool_after_m == "mirror" else "FAIL"))

	# ---- TEST 3: click the PRISM toolbar button (GUI button path) ------------
	var rect: Rect2 = quest.btn_prism.get_global_rect()
	print("btn_prism rect=", rect, " disabled=", quest.btn_prism.disabled,
		" visible=", quest.btn_prism.is_visible_in_tree())
	quest.tool = "mirror"
	_click(rect.get_center())
	await _wait(4)
	print("TEST3 click PRISM button: tool=", quest.tool,
		"  => ", ("PASS" if quest.tool == "prism" else "FAIL"))

	# ---- TEST 4: click the RESET button (search tree) ------------------------
	# place a couple pieces first, then RESET should clear them
	quest.tool = "mirror"
	_click(quest.cell_center(Vector2i(1, 0)))
	await _wait(2)
	var placed: int = quest.pieces.size()
	var reset_btn := _find_button(quest, "RESET")
	if reset_btn:
		_click(reset_btn.get_global_rect().get_center())
		await _wait(4)
		print("TEST4 RESET button: pieces ", placed, " -> ", quest.pieces.size(),
			"  => ", ("PASS" if quest.pieces.size() == 0 and placed > 0 else "FAIL"))
	else:
		print("TEST4 RESET button: NOT FOUND")

	# ---- diagnostics: what Controls sit over the board centre? ---------------
	_diagnose_picking(Vector2(576, 320))     # middle of the board
	get_tree().quit()


func _diagnose_picking(p: Vector2) -> void:
	print("--- controls covering board point ", p, " (mouse_filter STOP/PASS would eat clicks) ---")
	var hits: Array = []
	_collect_controls(get_tree().root, p, hits)
	for h in hits:
		print("   ", h)


func _collect_controls(n: Node, p: Vector2, out: Array) -> void:
	if n is Control:
		var c := n as Control
		if c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			var mf := "IGNORE"
			if c.mouse_filter == Control.MOUSE_FILTER_STOP: mf = "STOP"
			elif c.mouse_filter == Control.MOUSE_FILTER_PASS: mf = "PASS"
			out.append("%s  [%s]  rect=%s" % [c.get_path(), mf, str(c.get_global_rect())])
	for ch in n.get_children():
		_collect_controls(ch, p, out)


func _click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		get_viewport().push_input(ev, false)


func _key(code: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		get_viewport().push_input(ev, false)


func _find_button(root: Node, text: String) -> Button:
	if root is Button and (root as Button).text.strip_edges().to_upper().contains(text):
		return root
	for c in root.get_children():
		var r := _find_button(c, text)
		if r:
			return r
	return null


func _wait(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame
