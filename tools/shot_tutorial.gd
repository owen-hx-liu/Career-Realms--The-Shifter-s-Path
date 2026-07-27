extends Node
# Offline screenshot harness for the Hub Tutorial.
# Run windowed (needs rendering):  Godot --path . res://tools/shot_tutorial.tscn
# Loads MainHub with the tutorial forced on, jumps through several pages, and
# saves a PNG of each to OS.get_user_data_dir()/tutorial_shots/.

const MAINHUB := preload("res://scenes/maps/MainHub.tscn")
const PAGES := [0, 3, 4, 6]   # intro, an arrow-keys page, a multi-key page, finale

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep running while the tutorial pauses the tree
	var out_dir := OS.get_user_data_dir() + "/tutorial_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("SHOT_DIR=", out_dir)

	# Force the welcome tutorial, then build the hub as a child so we have a
	# real backdrop behind the (screen-space) tutorial UI.
	get_node("/root/global").show_hub_tutorial = true
	var hub = MAINHUB.instantiate()
	add_child(hub)

	# let the hub build + the tutorial animate in and pause the tree
	await get_tree().create_timer(1.6).timeout
	var tut = _find_tutorial()
	if tut == null:
		print("SHOT_ERROR tutorial node not found")
		get_tree().quit()
		return

	for pg in PAGES:
		tut._show_page(pg)
		tut._finish_typing()              # reveal the full line for the capture
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var path := "%s/page_%d.png" % [out_dir, pg]
		print("SHOT_SAVED page=", pg, " err=", img.save_png(path), " ", path)

	print("SHOT_DONE")
	get_tree().quit()

func _find_tutorial() -> Node:
	# the tutorial adds itself to the current scene (this harness root)
	for c in get_children():
		var scr = c.get_script()
		if scr and str(scr.resource_path).ends_with("HubTutorial.gd"):
			return c
	# also check the hub's children just in case
	for hub in get_children():
		for c in hub.get_children():
			var scr2 = c.get_script()
			if scr2 and str(scr2.resource_path).ends_with("HubTutorial.gd"):
				return c
	return null
