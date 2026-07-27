extends Node
# Offline screenshot harness for the remastered Ancient Egypt narrator + ending.
# Instances the real AncientEgyptMap and captures three states so we can confirm
# the new pixel-art panels render, scale crisply, and fit their text:
#   intro.png            - narrator stela showing an intro line over the map
#   ending_dialogue.png  - narrator stela showing the success line
#   ending_ui.png        - LevelCompleteUI victory stela (5 stars)
# Run windowed (needs rendering):
#   Godot --path . res://tools/egypt_narrator_shot.tscn

const MAP := preload("res://scenes/maps/AncientEgyptMap.tscn")

func _ready() -> void:
	var out_dir := OS.get_user_data_dir() + "/egypt_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("SHOT_DIR=", out_dir)

	var map = MAP.instantiate()
	add_child(map)

	# Let the map _ready finish AND the auto intro typewriter settle so its
	# coroutine isn't still appending characters when we set our own text.
	for i in range(90):
		await get_tree().process_frame

	var pl = map.get_node_or_null("Player")
	if pl:
		var cam = pl.get_node_or_null("worldcamera")
		if cam:
			cam.make_current()

	var nar = map.get_node_or_null("Narrator")
	var ui = map.get_node_or_null("LevelCompleteUI")
	if nar:
		nar.set_process(false)   # stop the typewriter / input handling
	if ui and ui.has_method("hide_completion"):
		ui.hide_completion()

	# 1) intro stela (a long line, to verify wrapping inside the papyrus field)
	_show_dialogue(nar, "The Nile is rising fast — carve canals to steer the floodwaters into the reservoirs.")
	for i in range(4):
		await get_tree().process_frame
	await _shot(out_dir, "intro")

	# 2) success ending line on the same stela
	_show_dialogue(nar, "The canals redirected the floodwaters! Three reservoirs received water.")
	for i in range(4):
		await get_tree().process_frame
	await _shot(out_dir, "ending_dialogue")

	# 3) victory stela (completion UI)
	if nar:
		nar.visible = false
	if ui and ui.has_method("show_completion"):
		ui.show_completion(3)
	for i in range(110):
		await get_tree().process_frame
	await _shot(out_dir, "ending_ui")

	print("SHOT_DONE")
	get_tree().quit()


func _show_dialogue(nar, text: String) -> void:
	if nar == null:
		return
	nar.visible = true
	var box = nar.get_node_or_null("DialogueBox")
	var lbl = nar.get_node_or_null("DialogueBox/DialogueLabel")
	var cont = nar.get_node_or_null("DialogueBox/ContinueLabel")
	if box:
		box.visible = true
	if lbl:
		lbl.text = text
	if cont:
		cont.visible = true


func _shot(out_dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path := out_dir + "/" + name + ".png"
	var err := img.save_png(path)
	print("SHOT_SAVED err=", err, " ", path)
