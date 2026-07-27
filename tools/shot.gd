extends Node
# Offline screenshot harness for the SPLICE quest.
# Run with:  Godot --path . res://tools/shot.tscn
# It instances the quest, jumps to each state, saves a PNG, then quits.
# Output dir is printed as SHOT_DIR=... so the caller can find the files.

const QUEST := preload("res://scenes/world_scenes/AlienBioengineeringQuest.tscn")
const STATES := ["intro", "catch", "sequencer", "memory", "bioreactor", "boss", "victory"]

func _ready() -> void:
	var out_dir := OS.get_user_data_dir() + "/splice_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("SHOT_DIR=", out_dir)
	for st in STATES:
		var q = QUEST.instantiate()
		q.auto_return_delay = 0.0  # don't change scene mid-capture
		q.record_on_win = false    # don't touch the save during screenshots
		add_child(q)
		await get_tree().process_frame
		await get_tree().process_frame
		if q.has_method("debug_setup"):
			q.debug_setup(st)
		# let layout settle and the stage banner fade out
		await get_tree().create_timer(1.8).timeout
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [out_dir, st]
		var err := img.save_png(path)
		print("SHOT_SAVED ", st, " err=", err, " ", path)
		q.queue_free()
		await get_tree().process_frame
	print("SHOT_DONE")
	get_tree().quit()
