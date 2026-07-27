extends Node2D
 
enum QuestState {
	PLAZA,
	PLANNING,
	SIMULATING,
	RESULTS,
	GAME_OVER,
}
 
enum TerrainType {
	GRASS,
	FOREST,
	MOUNTAIN,
	LAKE,
	SLIME,
	SKELETON,
}
 
const CARDINAL_DIRS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]
 
const FOREST_SCENE: PackedScene = preload("res://scenes/forest_trap.tscn")
const MOUNTAIN_SCENE: PackedScene = preload("res://scenes/mountain.tscn")
const LAKE_SCENE: PackedScene = preload("res://scenes/lake.tscn")
const SLIME_SCENE: PackedScene = preload("res://scenes/slime.tscn")
const SKELETON_SCENE: PackedScene = preload("res://scenes/skeleton.tscn")
const VILLAGE_SCENE: PackedScene = preload("res://scenes/target_village.tscn")
 
const TERRAIN_COLOR_MAP := {
	TerrainType.GRASS: Color("6fbf5f"),
	TerrainType.FOREST: Color("3f7a30"),
	TerrainType.MOUNTAIN: Color("8a7f72"),
	TerrainType.LAKE: Color("3c92d9"),
	TerrainType.SLIME: Color("93cf55"),
	TerrainType.SKELETON: Color("7a6f67"),
}

const UI_OUTER_MARGIN: float = 14.0
const UI_BOTTOM_BAR_HEIGHT: float = 34.0
const UI_PANEL_MIN_HEIGHT: float = 112.0
const UI_PANEL_MAX_HEIGHT: float = 168.0
const TILE_SIZE_MIN: float = 4.0

@export var grid_width: int = 14
@export var grid_height: int = 10
@export var tile_size: float = 52.0
@export var board_origin: Vector2 = Vector2(96, 118)
 
@export var road_tile_limit: int = 45
@export var forest_count: int = 8
@export var mountain_count: int = 6
@export var lake_count: int = 6
@export var slime_count: int = 3
@export var skeleton_count: int = 3

@export_group("Traveler Visual")
@export var traveler_texture: Texture2D
@export_range(0.08, 1.20, 0.01) var traveler_texture_scale: float = 0.32
@export var traveler_texture_tint: Color = Color(1, 1, 1, 1)
@export var traveler_keep_texture_aspect: bool = true
@export var traveler_fallback_color: Color = Color("ffe58a")
 
var rng := RandomNumberGenerator.new()
 
const MAX_ROUNDS: int = 3
 
var state: QuestState = QuestState.PLANNING
var round_index: int = 0
var total_score: int = 0
var total_possible_score: int = 0
var final_star_rating: int = 0
var active_grid_width: int = 14
var active_grid_height: int = 10
var active_road_tile_limit: int = 45
 
var terrain_grid: Array = []
var road_cells := {}
var hub_cell: Vector2i = Vector2i.ZERO
var village_cells: Array[Vector2i] = []
 
var remaining_roads: int = 0
 
var carts: Array = []
var simulation_time: float = 0.0
var successful_deliveries: int = 0
var failed_deliveries: int = 0
var latest_score: int = 0
 
var feedback_text: String = ""
var feedback_color: Color = Color(0.95, 0.95, 0.95)
 
var entity_layer: Node2D
var ui_layer: CanvasLayer
var top_panel: Panel
var state_label: Label
var info_label: Label
var legend_label: Label
var feedback_label: Label
var results_label: Label
var start_button: Button
var repeat_button: Button
var restart_button: Button
var cached_viewport_size: Vector2 = Vector2.ZERO
var map_play_rect: Rect2 = Rect2()
 
func _ready() -> void:
	rng.randomize()
	if has_node("TileMap"):
		$TileMap.visible = false
	active_grid_width = max(6, grid_width)
	active_grid_height = max(4, grid_height)
	active_road_tile_limit = road_tile_limit
 
	entity_layer = Node2D.new()
	entity_layer.name = "EntityLayer"
	add_child(entity_layer)
 
	_build_ui()
	var viewport: Viewport = get_viewport()
	if not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	_apply_responsive_layout()
	_start_new_round()
 
func _process(delta: float) -> void:
	if state == QuestState.SIMULATING:
		_update_simulation(delta)
		_refresh_ui()
		queue_redraw()
 
func _unhandled_input(event: InputEvent) -> void:
	if state != QuestState.PLANNING:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var cell := _world_to_cell(mouse_event.position)
			if _is_in_bounds(cell):
				_toggle_road(cell)
 
func _draw() -> void:
	if state == QuestState.GAME_OVER:
		_draw_game_over_overlay()
		return

	_draw_board()
	_draw_roads()
	_draw_hub_and_targets()
	_draw_carts()
 
func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)
 
	# Main panel — tall enough for 4 rows + buttons
	top_panel = Panel.new()
	top_panel.position = Vector2(12, 8)
	top_panel.size = Vector2(860, 106)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.10, 0.14, 0.96)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.22, 0.30, 0.40, 0.95)
	top_panel.add_theme_stylebox_override("panel", panel_style)
	ui_layer.add_child(top_panel)
 
	# Row 1 — state / round
	state_label = Label.new()
	state_label.position = Vector2(18, 10)
	state_label.size = Vector2(590, 22)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	state_label.text = "State: PLANNING"
	ui_layer.add_child(state_label)
 
	# Row 2 — road count + connected villages (short, always fits)
	info_label = Label.new()
	info_label.position = Vector2(18, 34)
	info_label.size = Vector2(590, 22)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info_label.text = ""
	ui_layer.add_child(info_label)
 
	# Row 3 — terrain legend (static hint, never overflows)
	legend_label = Label.new()
	legend_label.position = Vector2(18, 58)
	legend_label.size = Vector2(590, 22)
	legend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	legend_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend_label.text = "🌲 Forest: slow  ⛰ Mountain: very slow  ☠ Slime/Skeleton: fatal  🌊 Lake: blocked"
	ui_layer.add_child(legend_label)
 
	# Row 4 — feedback
	feedback_label = Label.new()
	feedback_label.position = Vector2(18, 82)
	feedback_label.size = Vector2(590, 22)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.text = ""
	ui_layer.add_child(feedback_label)
 
	# Results bar below the board
	results_label = Label.new()
	results_label.position = Vector2(12, 648)
	results_label.size = Vector2(860, 28)
	results_label.text = ""
	results_label.visible = false
	ui_layer.add_child(results_label)
 
	# Buttons stacked on the right side of the panel
	start_button = Button.new()
	start_button.position = Vector2(636, 14)
	start_button.size = Vector2(222, 36)
	start_button.text = "▶  Start Simulation"
	start_button.pressed.connect(_on_start_pressed)
	ui_layer.add_child(start_button)
 
	repeat_button = Button.new()
	repeat_button.position = Vector2(636, 58)
	repeat_button.size = Vector2(222, 36)
	repeat_button.text = "↺  Next Round"
	repeat_button.visible = false
	repeat_button.pressed.connect(_on_repeat_pressed)
	ui_layer.add_child(repeat_button)

	restart_button = Button.new()
	restart_button.position = Vector2(326, 590)
	restart_button.size = Vector2(232, 42)
	restart_button.text = "Play Again (3 Rounds)"
	restart_button.visible = false
	restart_button.pressed.connect(_on_restart_pressed)
	ui_layer.add_child(restart_button)

func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()

func _apply_responsive_layout() -> void:
	var view_size: Vector2 = get_viewport_rect().size
	if view_size == Vector2.ZERO:
		return
	if view_size == cached_viewport_size:
		return
	cached_viewport_size = view_size

	var margin: float = max(UI_OUTER_MARGIN, min(view_size.x, view_size.y) * 0.012)
	var panel_pad: float = clamp(view_size.y * 0.015, 10.0, 16.0)
	var row_height: float = clamp(view_size.y * 0.028, 20.0, 26.0)
	var row_gap: float = clamp(view_size.y * 0.004, 2.0, 6.0)
	var legend_height: float = row_height * 1.35
	var required_panel_height: float = panel_pad * 2.0 + row_height * 3.0 + legend_height + row_gap * 3.0
	var panel_height: float = clamp(max(view_size.y * 0.17, required_panel_height), UI_PANEL_MIN_HEIGHT, UI_PANEL_MAX_HEIGHT)

	top_panel.position = Vector2(margin, margin)
	top_panel.size = Vector2(max(300.0, view_size.x - margin * 2.0), panel_height)

	var button_width: float = clamp(view_size.x * 0.24, 176.0, 270.0)
	var button_height: float = clamp(panel_height * 0.31, 32.0, 44.0)

	start_button.size = Vector2(button_width, button_height)
	repeat_button.size = Vector2(button_width, button_height)
	start_button.position = Vector2(top_panel.position.x + top_panel.size.x - button_width - panel_pad, top_panel.position.y + panel_pad)
	repeat_button.position = Vector2(start_button.position.x, start_button.position.y + button_height + panel_pad * 0.55)

	var text_left: float = top_panel.position.x + panel_pad
	var text_right: float = start_button.position.x - panel_pad
	var text_width: float = max(120.0, text_right - text_left)

	state_label.position = Vector2(text_left, top_panel.position.y + panel_pad - 1.0)
	state_label.size = Vector2(text_width, row_height)
	info_label.position = Vector2(text_left, state_label.position.y + row_height + row_gap)
	info_label.size = Vector2(text_width, row_height)
	legend_label.position = Vector2(text_left, info_label.position.y + row_height + row_gap)
	legend_label.size = Vector2(text_width, legend_height)
	feedback_label.position = Vector2(text_left, legend_label.position.y + legend_label.size.y + row_gap)
	feedback_label.size = Vector2(text_width, row_height)

	results_label.position = Vector2(margin, view_size.y - margin - UI_BOTTOM_BAR_HEIGHT)
	results_label.size = Vector2(view_size.x - margin * 2.0, UI_BOTTOM_BAR_HEIGHT)

	restart_button.size = Vector2(clamp(view_size.x * 0.26, 210.0, 300.0), 42.0)
	restart_button.position = Vector2((view_size.x - restart_button.size.x) * 0.5, view_size.y * 0.78)

	var board_top: float = top_panel.position.y + top_panel.size.y + margin
	var board_bottom: float = view_size.y - margin - UI_BOTTOM_BAR_HEIGHT - 8.0
	var available_board_height: float = max(80.0, board_bottom - board_top)
	var available_board_width: float = max(80.0, view_size.x - margin * 2.0)
	map_play_rect = Rect2(Vector2(margin, board_top), Vector2(available_board_width, available_board_height))

	var new_tile_size: float = min(available_board_width / float(active_grid_width), available_board_height / float(active_grid_height))
	tile_size = max(TILE_SIZE_MIN, new_tile_size)

	var board_pixel_size: Vector2 = Vector2(tile_size * float(active_grid_width), tile_size * float(active_grid_height))
	board_origin = Vector2(
		(view_size.x - board_pixel_size.x) * 0.5,
		board_top + (available_board_height - board_pixel_size.y) * 0.5
	)

	queue_redraw()

func _update_runtime_grid_size() -> void:
	var playable_w: float = max(1.0, map_play_rect.size.x)
	var playable_h: float = max(1.0, map_play_rect.size.y)
	# User asked for one extra functional row.
	active_grid_height = max(4, grid_height + 1)
	# Expand columns so the map uses the available width instead of empty side space.
	var inferred_cols: int = int(round(float(active_grid_height) * (playable_w / playable_h)))
	active_grid_width = max(grid_width, inferred_cols)
	var area_ratio: float = float(active_grid_width * active_grid_height) / float(max(1, grid_width * grid_height))
	active_road_tile_limit = max(road_tile_limit, int(round(float(road_tile_limit) * area_ratio * 0.72)))
 
func _start_new_round() -> void:
	round_index += 1
	if round_index == 1:
		total_score = 0
		total_possible_score = 0
	_update_runtime_grid_size()
	cached_viewport_size = Vector2.ZERO
	_apply_responsive_layout()
	state = QuestState.PLANNING
	remaining_roads = active_road_tile_limit
	simulation_time = 0.0
	successful_deliveries = 0
	failed_deliveries = 0
	latest_score = 0
	road_cells.clear()
	carts.clear()
 
	_generate_map()
	_refresh_entities()
	_set_feedback("Build connected roads from the Hub to all 3 villages, then press Start.", Color(0.92, 0.95, 1.0))
	_refresh_ui()
	queue_redraw()
 
func _generate_map() -> void:
	terrain_grid.clear()
	for y in active_grid_height:
		var row: Array = []
		for x in active_grid_width:
			row.append(TerrainType.GRASS)
		terrain_grid.append(row)
 
	hub_cell = Vector2i(1, int(active_grid_height / 2))
	village_cells.clear()
 
	var reserved := {}
	reserved[hub_cell] = true
 
	while village_cells.size() < 3:
		var candidate := Vector2i(
			rng.randi_range(active_grid_width - 4, active_grid_width - 2),
			rng.randi_range(1, active_grid_height - 2)
		)
		if reserved.has(candidate):
			continue
		reserved[candidate] = true
		village_cells.append(candidate)
 
	var available_cells: Array[Vector2i] = []
	for y in active_grid_height:
		for x in active_grid_width:
			var cell := Vector2i(x, y)
			if reserved.has(cell):
				continue
			available_cells.append(cell)
 
	# Each round adds more blockades — difficulty scales with round_index.
	var extra: int = round_index - 1  # 0 on round 1, 1 on round 2, 2 on round 3
	var area_ratio: float = float(active_grid_width * active_grid_height) / float(max(1, grid_width * grid_height))
	var scaled_forest: int = max(forest_count + extra * 2, int(round(float(forest_count + extra * 2) * area_ratio)))
	var scaled_mountain: int = max(mountain_count + extra * 2, int(round(float(mountain_count + extra * 2) * area_ratio)))
	var scaled_lake: int = max(lake_count + extra, int(round(float(lake_count + extra) * area_ratio)))
	var scaled_slime: int = max(slime_count + extra, int(round(float(slime_count + extra) * area_ratio)))
	var scaled_skeleton: int = max(skeleton_count + extra, int(round(float(skeleton_count + extra) * area_ratio)))
	available_cells.shuffle()
	_place_terrain_from_pool(available_cells, scaled_forest,   TerrainType.FOREST)
	_place_terrain_from_pool(available_cells, scaled_mountain, TerrainType.MOUNTAIN)
	_place_terrain_from_pool(available_cells, scaled_lake,     TerrainType.LAKE)
	_place_terrain_from_pool(available_cells, scaled_slime,    TerrainType.SLIME)
	_place_terrain_from_pool(available_cells, scaled_skeleton, TerrainType.SKELETON)
 
	_clear_anchor_neighbors_of_lakes()
 
func _place_terrain_from_pool(pool: Array[Vector2i], count: int, terrain_type: int) -> void:
	var place_count: int = min(count, pool.size())
	for _i in place_count:
		var cell: Vector2i = pool.pop_back()
		terrain_grid[cell.y][cell.x] = terrain_type
 
func _clear_anchor_neighbors_of_lakes() -> void:
	var anchors: Array[Vector2i] = [hub_cell]
	anchors.append_array(village_cells)
 
	for anchor in anchors:
		for dir in CARDINAL_DIRS:
			var near := anchor + dir
			if _is_in_bounds(near) and _terrain_at(near) == TerrainType.LAKE:
				terrain_grid[near.y][near.x] = TerrainType.GRASS
 
func _refresh_entities() -> void:
	for child in entity_layer.get_children():
		child.queue_free()
 
	for y in active_grid_height:
		for x in active_grid_width:
			var cell := Vector2i(x, y)
			match _terrain_at(cell):
				TerrainType.FOREST:
					_spawn_scene_on_cell(FOREST_SCENE,   cell, 0.50)
				TerrainType.MOUNTAIN:
					_spawn_scene_on_cell(MOUNTAIN_SCENE, cell, 0.52)
				TerrainType.LAKE:
					_spawn_scene_on_cell(LAKE_SCENE,     cell, 0.54)
				TerrainType.SLIME:
					_spawn_scene_on_cell(SLIME_SCENE,    cell, 0.38)
				TerrainType.SKELETON:
					_spawn_scene_on_cell(SKELETON_SCENE, cell, 0.38)
				_:
					pass
 
	for village in village_cells:
		_spawn_scene_on_cell(VILLAGE_SCENE, village, 0.42)
 
func _spawn_scene_on_cell(scene: PackedScene, cell: Vector2i, scale_value: float) -> void:
	var instance := scene.instantiate()
	if instance is Node2D:
		var node := instance as Node2D
		# Center on the tile and scale relative to tile_size so sprites
		# always fit within their cell regardless of source resolution.
		node.position = _cell_to_world(cell)
		node.scale = Vector2.ONE * scale_value
		node.z_index = cell.y  # y-sort so lower rows draw on top
	entity_layer.add_child(instance)
 
func _draw_board() -> void:
	# Fill the whole playable map area so there is no gray gap around the grid.
	draw_rect(map_play_rect, Color("6fbf5f"))
	draw_rect(map_play_rect, Color(0, 0, 0, 0.20), false, 2.0)

	for y in active_grid_height:
		for x in active_grid_width:
			var cell := Vector2i(x, y)
			var rect := Rect2(_cell_top_left(cell), Vector2(tile_size, tile_size))
			var terrain: int = _terrain_at(cell)
			draw_rect(rect, TERRAIN_COLOR_MAP.get(terrain, Color(0.4, 0.8, 0.4)))
			draw_rect(rect, Color(0, 0, 0, 0.18), false, 1.0)
 
func _draw_roads() -> void:
	for key in road_cells.keys():
		var cell: Vector2i = key
		var margin := tile_size * 0.20
		var rect := Rect2(
			_cell_top_left(cell) + Vector2(margin, margin),
			Vector2(tile_size - margin * 2.0, tile_size - margin * 2.0)
		)
		draw_rect(rect, Color("d39e3c"))
 
func _draw_hub_and_targets() -> void:
	var hub_center := _cell_to_world(hub_cell)
 
	# Outer glow ring
	draw_circle(hub_center, tile_size * 0.46, Color(0.16, 0.66, 1.0, 0.28))
	# Dark border ring
	draw_circle(hub_center, tile_size * 0.38, Color(0, 0, 0, 0.55))
	# Main hub fill
	draw_circle(hub_center, tile_size * 0.33, Color("2aa9ff"))
	# Inner highlight
	draw_circle(hub_center, tile_size * 0.16, Color(1.0, 1.0, 1.0, 0.55))
 
	# "START" text drawn just below the hub circle
	var font := ThemeDB.fallback_font
	var font_size := 13
	var label := "START"
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, hub_center + Vector2(-text_width * 0.5, tile_size * 0.52),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.95))
 
	# Villages
	for village in village_cells:
		var village_center := _cell_to_world(village)
		draw_circle(village_center, tile_size * 0.26, Color(0, 0, 0, 0.32))
		draw_circle(village_center, tile_size * 0.20, Color("f7d97b"))
		draw_circle(village_center, tile_size * 0.09, Color(1.0, 1.0, 1.0, 0.45))
 
func _draw_carts() -> void:
	if carts.is_empty():
		return
 
	for cart_data in carts:
		var failed: bool = cart_data.get("failed", false)
		# FIX: hide failed carts only during RESULTS, not during SIMULATING
		if failed and state == QuestState.RESULTS:
			continue
		var pos := _cart_world_position(cart_data)
		_draw_traveler_marker(pos)

func _draw_traveler_marker(pos: Vector2) -> void:
	var texture: Texture2D = traveler_texture
	if texture == null:
		draw_circle(pos, tile_size * 0.12, Color(0, 0, 0, 0.35))
		draw_circle(pos, tile_size * 0.09, traveler_fallback_color)
		return

	var texture_size_i: Vector2i = texture.get_size()
	if texture_size_i.x <= 0 or texture_size_i.y <= 0:
		draw_circle(pos, tile_size * 0.12, Color(0, 0, 0, 0.35))
		draw_circle(pos, tile_size * 0.09, traveler_fallback_color)
		return

	var texture_size: Vector2 = Vector2(float(texture_size_i.x), float(texture_size_i.y))
	var target_size: float = max(1.0, tile_size * traveler_texture_scale)
	var draw_size: Vector2 = Vector2.ONE * target_size

	if traveler_keep_texture_aspect:
		var aspect_scale: float = min(target_size / texture_size.x, target_size / texture_size.y)
		draw_size = texture_size * aspect_scale

	var shadow_offset: Vector2 = Vector2(0.0, tile_size * 0.03)
	draw_circle(pos + shadow_offset, draw_size.x * 0.34, Color(0, 0, 0, 0.25))

	var draw_rect_area: Rect2 = Rect2(pos - draw_size * 0.5, draw_size)
	draw_texture_rect(texture, draw_rect_area, false, traveler_texture_tint)
 
func _cart_world_position(cart_data: Dictionary) -> Vector2:
	var path: Array = cart_data.get("path", [])
	if path.is_empty():
		return _cell_to_world(hub_cell)
 
	var index: int = int(cart_data.get("index", 0))
	index = clamp(index, 0, path.size() - 1)
	var progress: float = float(cart_data.get("progress", 0.0))
 
	if index >= path.size() - 1:
		return _cell_to_world(path[path.size() - 1])
 
	var from_cell: Vector2i = path[index]
	var to_cell: Vector2i = path[index + 1]
	return _cell_to_world(from_cell).lerp(_cell_to_world(to_cell), progress)
 
func _toggle_road(cell: Vector2i) -> void:
	if road_cells.has(cell):
		road_cells.erase(cell)
		remaining_roads += 1
		_set_feedback("Removed road tile. Roads left: %d" % remaining_roads, Color(1.0, 0.95, 0.8))
		_refresh_ui()
		queue_redraw()
		return
 
	if remaining_roads <= 0:
		_set_feedback("No road tiles left. Press Repeat to reset the round.", Color(1.0, 0.7, 0.7))
		_refresh_ui()
		return
 
	if cell == hub_cell or village_cells.has(cell):
		_set_feedback("Roads cannot be placed directly on Hub or Village tiles.", Color(1.0, 0.7, 0.7))
		_refresh_ui()
		return
 
	if _terrain_at(cell) == TerrainType.LAKE:
		_set_feedback("Lake tiles are blocked. Pick another tile.", Color(1.0, 0.7, 0.7))
		_refresh_ui()
		return
 
	if not _is_connected_to_network(cell):
		_set_feedback("Roads must connect tile-to-tile from the Hub network.", Color(1.0, 0.7, 0.7))
		_refresh_ui()
		return
 
	road_cells[cell] = true
	remaining_roads -= 1
 
	var terrain := _terrain_at(cell)
	if terrain == TerrainType.SLIME or terrain == TerrainType.SKELETON:
		_set_feedback("Warning: road placed on hazard terrain — carts will fail here! Roads left: %d" % remaining_roads, Color(1.0, 0.75, 0.4))
	else:
		_set_feedback("Placed road tile. Roads left: %d" % remaining_roads, Color(0.86, 0.96, 0.86))
 
	_refresh_ui()
	queue_redraw()
 
func _is_connected_to_network(cell: Vector2i) -> bool:
	for dir in CARDINAL_DIRS:
		var neighbor := cell + dir
		if not _is_in_bounds(neighbor):
			continue
		if neighbor == hub_cell or road_cells.has(neighbor):
			return true
	return false
 
func _validate_routes() -> Dictionary:
	var routes := {}
 
	for i in village_cells.size():
		var village := village_cells[i]
		var path: Array[Vector2i] = _find_path_to_village(village)
		if path.is_empty():
			return {
				"ok": false,
				"missing_index": i + 1,
			}
		routes[village] = path
 
	return {
		"ok": true,
		"routes": routes,
	}
 
func _find_path_to_village(village: Vector2i) -> Array[Vector2i]:
	var frontier: Array[Vector2i] = [hub_cell]
	var visited := {}
	var parent := {}
	visited[hub_cell] = true
 
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == village:
			break
 
		for dir in CARDINAL_DIRS:
			var neighbor := current + dir
			if not _is_in_bounds(neighbor):
				continue
			if not _is_network_node(neighbor):
				continue
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			parent[neighbor] = current
			frontier.append(neighbor)
 
	if not visited.has(village):
		return []
 
	var path: Array[Vector2i] = []
	var walk: Vector2i = village
	while true:
		path.push_front(walk)
		if walk == hub_cell:
			break
		walk = parent[walk]
 
	return path
 
func _is_network_node(cell: Vector2i) -> bool:
	return cell == hub_cell or road_cells.has(cell) or village_cells.has(cell)
 
func _on_start_pressed() -> void:
	if state != QuestState.PLANNING:
		return
 
	var validation := _validate_routes()
	if not validation.get("ok", false):
		var missing_index: int = int(validation.get("missing_index", -1))
		_set_feedback("Route missing from Hub to Village %d." % missing_index, Color(1.0, 0.7, 0.7))
		_refresh_ui()
		return
 
	_start_simulation(validation.get("routes", {}))
 
func _start_simulation(routes: Dictionary) -> void:
	state = QuestState.SIMULATING
	simulation_time = 0.0
	carts.clear()
 
	for village in village_cells:
		var path: Array = routes[village]
		carts.append({
			"village": village,
			"path": path,
			"index": 0,
			"progress": 0.0,
			"elapsed": 0.0,
			"done": false,
			"failed": false,
		})
 
	_set_feedback("Simulation running... carts are moving tile-by-tile.", Color(0.9, 0.95, 1.0))
	_refresh_ui()
	queue_redraw()
 
# FIX: Restructured to use remaining_delta so each cell step correctly applies
# its own terrain move_time, even when multiple cells are crossed in one frame.
func _update_simulation(delta: float) -> void:
	simulation_time += delta
 
	var finished_count: int = 0
	for i in carts.size():
		var cart: Dictionary = carts[i]
		if cart.get("done", false):
			finished_count += 1
			continue
 
		var path: Array = cart.get("path", [])
 
		# FIX: was missing finished_count += 1 before the continue, stalling completion.
		if path.size() < 2:
			cart["done"] = true
			cart["failed"] = true
			finished_count += 1
			continue
 
		if int(cart.get("index", 0)) >= path.size() - 1:
			cart["done"] = true
			finished_count += 1
			continue
 
		cart["elapsed"] = float(cart.get("elapsed", 0.0)) + delta
 
		# Use remaining_delta so each cell uses its own terrain speed correctly.
		var remaining_delta: float = delta
 
		while remaining_delta > 0.0 and not cart.get("done", false):
			var index: int = int(cart.get("index", 0))
			if index >= path.size() - 1:
				cart["done"] = true
				break
 
			var next_cell: Vector2i = path[index + 1]
			var move_time: float = _movement_time(next_cell)
			var progress: float = float(cart.get("progress", 0.0))
			var progress_gain: float = remaining_delta / move_time
 
			if progress + progress_gain >= 1.0:
				# Consume only the time needed to finish crossing this cell.
				var time_to_cross: float = (1.0 - progress) * move_time
				remaining_delta -= time_to_cross
				cart["progress"] = 0.0
				cart["index"] = index + 1
 
				var entered_cell: Vector2i = path[index + 1]
				if _is_fatal_cell(entered_cell):
					cart["failed"] = true
					cart["done"] = true
					break
 
				if index + 1 >= path.size() - 1:
					cart["done"] = true
			else:
				cart["progress"] = progress + progress_gain
				remaining_delta = 0.0
 
		if cart.get("done", false):
			finished_count += 1
 
	if finished_count == carts.size():
		_finish_simulation()
 
func _movement_time(cell: Vector2i) -> float:
	match _terrain_at(cell):
		TerrainType.FOREST:
			return 1.7
		TerrainType.MOUNTAIN:
			return 2.7
		_:
			return 1.0
 
func _is_fatal_cell(cell: Vector2i) -> bool:
	var terrain := _terrain_at(cell)
	return terrain == TerrainType.SLIME or terrain == TerrainType.SKELETON
 
func _finish_simulation() -> void:
	state = QuestState.RESULTS
	successful_deliveries = 0
	failed_deliveries = 0
 
	for cart_data in carts:
		if cart_data.get("failed", false):
			failed_deliveries += 1
		else:
			successful_deliveries += 1
 
	var area_ratio: float = float(active_grid_width * active_grid_height) / float(max(1, grid_width * grid_height))
	var base_score: int = int(round(1200.0 * area_ratio))
	var completion_bonus: int = int(round(350.0 * area_ratio)) if successful_deliveries == village_cells.size() else 0

	# Larger functional maps naturally take longer routes, so time penalty rate softens with map size.
	var time_penalty_rate: float = 25.0 / max(1.0, sqrt(area_ratio))
	var time_penalty: int = int(round(simulation_time * time_penalty_rate))

	# More terrain hazards on bigger maps should not over-punish a run.
	var failed_penalty_per_route: int = int(round(220.0 / max(1.0, sqrt(area_ratio))))
	var failed_penalty: int = failed_deliveries * failed_penalty_per_route

	# Keep road bonus meaningful but balanced as route budget grows with map size.
	var road_bonus_per_tile: int = max(4, int(round(12.0 / max(1.0, area_ratio * 0.75))))
	var unused_roads_bonus: int = remaining_roads * road_bonus_per_tile

	latest_score = max(0, base_score - time_penalty - failed_penalty + completion_bonus + unused_roads_bonus)
	var perfect_round_score: int = base_score + int(round(350.0 * area_ratio)) + (active_road_tile_limit * road_bonus_per_tile)
	total_possible_score += perfect_round_score
 
	total_score += latest_score
 
	if round_index >= MAX_ROUNDS:
		state = QuestState.GAME_OVER
		final_star_rating = _score_to_star_rating(total_score)
		_set_feedback("All rounds complete! Final score: %d" % total_score, Color(1.0, 0.95, 0.6))
	else:
		_set_feedback("Round %d done — %d/%d rounds complete. Press Next Round." % [round_index, round_index, MAX_ROUNDS], Color(0.88, 1.0, 0.88))
	_refresh_ui()
	queue_redraw()
 
func _on_repeat_pressed() -> void:
	if state == QuestState.GAME_OVER:
		return
	_start_new_round()

func _on_restart_pressed() -> void:
	round_index = 0
	total_score = 0
	total_possible_score = 0
	final_star_rating = 0
	_start_new_round()

func _refresh_ui() -> void:
	entity_layer.visible = state != QuestState.GAME_OVER
	top_panel.visible = state != QuestState.GAME_OVER
	state_label.visible = state != QuestState.GAME_OVER
	info_label.visible = state != QuestState.GAME_OVER
	legend_label.visible = state != QuestState.GAME_OVER
	feedback_label.visible = state != QuestState.GAME_OVER
	results_label.visible = false
	restart_button.visible = false

	match state:
		QuestState.PLAZA:
			state_label.text = "State: PLAZA | Round %d" % round_index
			info_label.text = ""
			start_button.visible = false
			repeat_button.visible = false
		QuestState.PLANNING:
			var connected_count := _count_connected_villages()
			state_label.text = "State: PLANNING  |  Round %d" % round_index
			info_label.text = "Roads Left: %d / %d     Villages Connected: %d / 3     Left-click to place or remove a road tile" % [remaining_roads, active_road_tile_limit, connected_count]
			start_button.visible = true
			start_button.disabled = false
			repeat_button.visible = false
		QuestState.SIMULATING:
			state_label.text = "State: SIMULATING"
			info_label.text = "Simulation Time: %.1fs | Carts Active: %d" % [simulation_time, carts.size()]
			start_button.visible = true
			start_button.disabled = true
			repeat_button.visible = false
		QuestState.RESULTS:
			state_label.text = "State: RESULTS  |  Round %d / %d" % [round_index, MAX_ROUNDS]
			info_label.text = "Round done. Press Next Round to continue." if round_index < MAX_ROUNDS else "All rounds done!"
			start_button.visible = false
			repeat_button.visible = round_index < MAX_ROUNDS
			repeat_button.disabled = false
			results_label.visible = true
			results_label.text = "Time: %.1fs | Deliveries: %d/3 | Failed: %d | Round Score: %d | Total Score: %d" % [simulation_time, successful_deliveries, failed_deliveries, latest_score, total_score]
		QuestState.GAME_OVER:
			start_button.visible = false
			repeat_button.visible = false
			restart_button.visible = true
		_:
			pass

	feedback_label.text = feedback_text
	feedback_label.modulate = feedback_color
 
func _count_connected_villages() -> int:
	var connected := 0
	for village in village_cells:
		if not _find_path_to_village(village).is_empty():
			connected += 1
	return connected
 
func _set_feedback(message: String, tint: Color = Color(0.95, 0.95, 0.95)) -> void:
	feedback_text = message
	feedback_color = tint
 
func _terrain_at(cell: Vector2i) -> int:
	return terrain_grid[cell.y][cell.x]
 
func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < active_grid_width and cell.y >= 0 and cell.y < active_grid_height
 
func _cell_top_left(cell: Vector2i) -> Vector2:
	return board_origin + Vector2(cell.x, cell.y) * tile_size
 
func _cell_to_world(cell: Vector2i) -> Vector2:
	return _cell_top_left(cell) + Vector2(tile_size * 0.5, tile_size * 0.5)
 
func _world_to_cell(world_position: Vector2) -> Vector2i:
	var x := int(floor((world_position.x - board_origin.x) / tile_size))
	var y := int(floor((world_position.y - board_origin.y) / tile_size))
	return Vector2i(x, y)

func _score_to_star_rating(score: int) -> int:
	var perfect_total: float = float(max(1, total_possible_score))
	var ratio: float = 0.0
	if perfect_total > 0.0:
		ratio = float(score) / perfect_total

	if ratio >= 0.85:
		return 5
	if ratio >= 0.70:
		return 4
	if ratio >= 0.55:
		return 3
	if ratio >= 0.40:
		return 2
	if score > 0:
		return 1
	return 0

func _draw_game_over_overlay() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var center_x: float = viewport_size.x * 0.5
	var title_y: float = viewport_size.y * 0.22
	var stars_y: float = viewport_size.y * 0.50

	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.06, 0.09, 0.14, 1.0), true)
	_draw_centered_text("Quest Complete", Vector2(center_x, title_y), 56, Color(0.97, 0.98, 1.0))
	_draw_centered_text("Final Score: %d" % total_score, Vector2(center_x, title_y + 56.0), 34, Color(0.92, 0.96, 1.0))

	var star_spacing: float = 95.0
	for i in range(5):
		var star_center := Vector2(center_x + (float(i) - 2.0) * star_spacing, stars_y)
		var is_filled: bool = i < final_star_rating
		var fill := Color("f9cf62") if is_filled else Color(0.30, 0.35, 0.42, 0.9)
		_draw_star_icon(star_center, 34.0, fill, Color(0.14, 0.14, 0.16, 0.95))

	_draw_centered_text("Star Rating: %d / 5" % final_star_rating, Vector2(center_x, stars_y + 76.0), 30, Color(1.0, 0.95, 0.80))
	_draw_centered_text("Round %d of %d complete" % [round_index, MAX_ROUNDS], Vector2(center_x, stars_y + 116.0), 24, Color(0.78, 0.86, 0.96))

func _draw_star_icon(center: Vector2, outer_radius: float, fill: Color, outline: Color) -> void:
	var points := PackedVector2Array()
	var inner_radius: float = outer_radius * 0.46
	for i in range(10):
		var angle: float = -PI * 0.5 + float(i) * PI / 5.0
		var radius: float = outer_radius if i % 2 == 0 else inner_radius
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)

	draw_colored_polygon(points, fill)

	var border := PackedVector2Array(points)
	border.append(points[0])
	draw_polyline(border, outline, 2.2, true)

func _draw_centered_text(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(center.x - text_width * 0.5, center.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
