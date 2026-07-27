extends Node
# In-context screenshot of the Ancient Egypt map: places a connected canal
# next to the player on the real desert terrain at the real camera zoom, so we
# can confirm the pixel-art canal matches the scene AND that the player renders
# on top of the canal (correct layering).
# Run windowed:  Godot --path . res://tools/egypt_canal_shot.tscn

const MAP := preload("res://scenes/maps/AncientEgyptMap.tscn")

func _ready() -> void:
	var out_dir := OS.get_user_data_dir() + "/egypt_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("SHOT_DIR=", out_dir)

	var map = MAP.instantiate()
	add_child(map)

	# Let the map _ready run (zone generation, etc.)
	for i in range(8):
		await get_tree().process_frame

	# Hide the intro narrator/dialogue so it doesn't cover the view.
	var nar = map.get_node_or_null("Narrator")
	if nar:
		nar.visible = false
		nar.set_process(false)
		nar.set_process_input(false)
	for child in map.get_children():
		if child is CanvasLayer and child.name != "HUD" and child.name != "LevelCompleteUI":
			child.visible = false

	var tm = map.get_node_or_null("TileMap")
	var pl = map.get_node_or_null("Player")
	if tm == null or pl == null:
		print("MISSING tilemap/player")
		get_tree().quit()
		return

	# Place a connected canal NEXT TO the player (leave the player's own tile
	# empty so the "Press C" placement highlight is visible).
	map.available_resources = 200
	var pt: Vector2i = tm.local_to_map(tm.to_local(pl.global_position))
	var cells := [
		pt + Vector2i(1, 0), pt + Vector2i(2, 0), pt + Vector2i(3, 0),
		pt + Vector2i(3, 1), pt + Vector2i(3, 2),
		pt + Vector2i(2, 2), pt + Vector2i(1, 2),
		pt + Vector2i(1, 1),
	]
	for c in cells:
		map._on_zone_build_requested(c)
	print("Placed canals:", map.built_canals.size())

	# Make the player camera current and centre it on the canal area.
	var cam = pl.get_node_or_null("worldcamera")
	if cam:
		cam.make_current()

	# Let the highlight activate, then capture quickly so the splash is visible.
	for i in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img: Image = get_viewport().get_texture().get_image()
	var path := out_dir + "/egypt_canal.png"
	var err := img.save_png(path)
	print("SHOT_SAVED err=", err, " ", path)
	print("SHOT_DONE")
	get_tree().quit()
