extends Node2D
# Offline screenshot harness for the redesigned auto-connecting canal tiles.
# Run windowed:  Godot --path . res://tools/canal_shot.tscn
# Lays out canals in several connection patterns, lets them auto-tile, and
# saves a PNG so we can confirm they merge into one seamless waterway.
# Output dir is printed as SHOT_DIR=... so the caller can find the file.

const CANAL := preload("res://scenes/enviorment/CanalTile.tscn")
const TILE := 16.0
const VIEW_SCALE := 6.0
const OFFSET := Vector2(70, 90)

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1024, 768))

	var out_dir := OS.get_user_data_dir() + "/canal_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("SHOT_DIR=", out_dir)

	# Sandy desert backdrop.
	var bg := ColorRect.new()
	bg.color = Color("d8bf86")
	bg.size = Vector2(3000, 3000)
	bg.position = Vector2(-500, -500)
	add_child(bg)

	var container := Node2D.new()
	container.scale = Vector2(VIEW_SCALE, VIEW_SCALE)
	container.position = OFFSET
	add_child(container)

	# Clusters spaced apart so they don't accidentally connect.
	var cells := [
		# Connected canal: straights, corners, U-turn, dead ends
		Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(2,1), Vector2i(2,2),
		Vector2i(1,2), Vector2i(0,2), Vector2i(0,3), Vector2i(0,4),
		# Cross / plus
		Vector2i(5,0), Vector2i(4,1), Vector2i(5,1), Vector2i(6,1), Vector2i(5,2),
		# T-junction
		Vector2i(4,4), Vector2i(5,4), Vector2i(6,4), Vector2i(5,5),
		# Straight run
		Vector2i(7,6), Vector2i(8,6), Vector2i(9,6),
		# Isolated pool
		Vector2i(9,2),
	]
	var present := {}
	for c in cells:
		present[c] = true

	var nodes := {}
	for c in cells:
		var inst = CANAL.instantiate()
		inst.tile_position = c
		inst.tile_size = TILE
		inst.position = Vector2(c.x * TILE, c.y * TILE)
		container.add_child(inst)
		nodes[c] = inst

	for c in cells:
		var mask := 0
		if present.has(c + Vector2i(0, -1)): mask |= 1  # N
		if present.has(c + Vector2i(1, 0)):  mask |= 2  # E
		if present.has(c + Vector2i(0, 1)):  mask |= 4  # S
		if present.has(c + Vector2i(-1, 0)): mask |= 8  # W
		nodes[c].set_connections(mask)

	_label("Connected: corners, U-turn, dead ends", Vector2(60, 40))
	_label("Cross", Vector2(60 + 5 * TILE * VIEW_SCALE, 40))
	_label("T-junction", Vector2(60 + 4 * TILE * VIEW_SCALE, 50 + 3.2 * TILE * VIEW_SCALE))
	_label("Straight", Vector2(60 + 7 * TILE * VIEW_SCALE, 60 + 5.2 * TILE * VIEW_SCALE))
	_label("Isolated pool", Vector2(60 + 8.2 * TILE * VIEW_SCALE, 60 + 1.1 * TILE * VIEW_SCALE))

	# let layout + first shimmer settle
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path := out_dir + "/canals.png"
	var err := img.save_png(path)
	print("SHOT_SAVED err=", err, " ", path)
	print("SHOT_DONE")
	get_tree().quit()


func _label(text: String, pos: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_color_override("font_color", Color("2a2018"))
	l.add_theme_font_size_override("font_size", 18)
	add_child(l)
