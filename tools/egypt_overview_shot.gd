extends Node
# Overview screenshots of the Ancient Egypt map: themed reservoirs (blue basins)
# and flood zones (red danger), plus the flood animation. Connects a flood zone
# to a reservoir with a canal path, then captures before / during / after the flood.
# Run windowed:  Godot --path . res://tools/egypt_overview_shot.tscn

const MAP := preload("res://scenes/maps/AncientEgyptMap.tscn")

var map
var out_dir: String

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(900, 900))
	out_dir = OS.get_user_data_dir() + "/egypt_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("SHOT_DIR=", out_dir)

	map = MAP.instantiate()
	add_child(map)
	for i in range(8):
		await get_tree().process_frame

	var nar = map.get_node_or_null("Narrator")
	if nar:
		nar.visible = false
		nar.set_process(false)
	for child in map.get_children():
		if child is CanvasLayer and child.name != "HUD" and child.name != "LevelCompleteUI":
			child.visible = false

	var tm = map.get_node("TileMap")

	# Connect flood zone 0 to reservoir 0 with an L-shaped canal path.
	map.available_resources = 999
	var flood_tiles = map._collect_tiles_from_node_polygon(map.flood_zones_container.get_child(0), tm)
	var res_tiles = map._collect_tiles_from_node_polygon(map.reservoirs_container.get_child(0), tm)
	if flood_tiles.size() > 0 and res_tiles.size() > 0:
		var a: Vector2i = flood_tiles[flood_tiles.size() / 2]
		var b: Vector2i = res_tiles[res_tiles.size() / 2]
		var x = a.x
		while x != b.x:
			map._on_zone_build_requested(Vector2i(x, a.y))
			x += signi(b.x - x)
		var y = a.y
		while y != b.y:
			map._on_zone_build_requested(Vector2i(b.x, y))
			y += signi(b.y - y)
		map._on_zone_build_requested(b)
	print("Path canals:", map.built_canals.size())

	# Tight camera on the reservoir to judge the basin theming + fill.
	var cam := Camera2D.new()
	cam.position = Vector2(740, 415)
	cam.zoom = Vector2(3.6, 3.6)
	add_child(cam)
	cam.make_current()

	for i in range(4):
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	await _shot("closeup_before")

	map.trigger_flood()
	await get_tree().create_timer(0.5).timeout
	await _shot("closeup_during")

	await get_tree().create_timer(1.8).timeout
	await _shot("closeup_after")

	print("SHOT_DONE")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err := img.save_png(out_dir + "/" + name + ".png")
	print("SHOT_SAVED ", name, " err=", err)
