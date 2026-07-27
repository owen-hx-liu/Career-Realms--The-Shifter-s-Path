extends Node2D

enum SlotMaterial {
	EMPTY = 0,
	WOOD = 1,
	METAL = 2,
	STONE = 3,
}

enum PairStatus {
	INCOMPLETE = 0,
	MISMATCH = 1,
	SYMMETRICAL = 2,
}

const RETURN_SCENE_PATH: String = "res://scenes/control_room_repair_city.tscn"
const MAX_LEVEL: int = 3

const WOOD_SCENE: PackedScene = preload("res://scenes/wood.tscn")
const METAL_SCENE: PackedScene = preload("res://scenes/metal.tscn")
const STONE_SCENE: PackedScene = preload("res://scenes/stone.tscn")
const XRAY_SCENE: PackedScene = preload("res://scenes/x_ray.tscn")
const XRAY_FRAME_SCENE: PackedScene = preload("res://scenes/x_ray_frame.tscn")

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var board_layers: Array = []
var active_slot_widgets: Array = []

var material_textures: Dictionary = {}
var xray_texture: Texture2D
var xray_frame_texture: Texture2D

var selected_material: int = SlotMaterial.EMPTY
var allow_cycle_edits: bool = false
var puzzle_completed: bool = false

var xray_enabled: bool = false
var current_layer_index: int = 0

var row_count: int = 0
var cols_per_side: int = 0
var layer_count: int = 1
var slot_width: int = 72
var slot_height: int = 52

# Level-specific stats
var recommended_actions: int = 0
var action_count: int = 0
var xray_toggle_count: int = 0
var elapsed_time: float = 0.0

# Quest-wide accumulated stats
var total_recommended_actions: int = 0
var total_action_count: int = 0
var total_xray_toggle_count: int = 0
var total_elapsed_time: float = 0.0

var ui_layer: CanvasLayer
var ui_root: Control
var level_label: Label
var subtitle_label: Label
var selected_label: Label
var status_label: Label
var return_button: Button

var material_buttons: Dictionary = {}

var board_title_label: Label
var board_scroll: ScrollContainer
var rows_container: VBoxContainer

var xray_toggle_button: TextureButton
var xray_state_label: Label
var layer_buttons_container: HBoxContainer
var layer_buttons: Array = []

var win_panel: PanelContainer
var win_title: Label
var win_detail: Label
var win_score_label: Label
var next_building_button: Button
var star_container: HBoxContainer

# Sets up the full repair puzzle UI and starts the current quest level.
func _ready() -> void:
	rng.randomize()
	_load_asset_textures()
	_build_ui()
	
	# Reset quest stats at the very start
	total_recommended_actions = 0
	total_action_count = 0
	total_xray_toggle_count = 0
	total_elapsed_time = 0.0
	
	_start_level(_get_clamped_level())

# Updates elapsed time while the current building is still being repaired.
func _process(delta: float) -> void:
	if puzzle_completed:
		return
	elapsed_time += delta
	_update_header_text()

# Returns the active level clamped to the supported 1..3 range.
func _get_clamped_level() -> int:
	var level: int = int(GameState.current_level)
	if level < 1:
		level = 1
	if level > MAX_LEVEL:
		level = MAX_LEVEL
	return level

# Loads textures from the visual asset scenes used by this quest.
func _load_asset_textures() -> void:
	material_textures.clear()
	material_textures[SlotMaterial.WOOD] = _extract_scene_texture(WOOD_SCENE)
	material_textures[SlotMaterial.METAL] = _extract_scene_texture(METAL_SCENE)
	material_textures[SlotMaterial.STONE] = _extract_scene_texture(STONE_SCENE)
	xray_texture = _extract_scene_texture(XRAY_SCENE)
	xray_frame_texture = _extract_scene_texture(XRAY_FRAME_SCENE)

# Builds the full-screen puzzle interface with side controls and a scrollable building board.
func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "RepairUI"
	add_child(ui_layer)

	ui_root = Control.new()
	ui_root.name = "Root"
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui_root)

	var background: ColorRect = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.08, 0.11, 0.15, 1.0)
	ui_root.add_child(background)

	var main_margin: MarginContainer = MarginContainer.new()
	main_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_margin.add_theme_constant_override("margin_left", 12)
	main_margin.add_theme_constant_override("margin_right", 12)
	main_margin.add_theme_constant_override("margin_top", 12)
	main_margin.add_theme_constant_override("margin_bottom", 12)
	ui_root.add_child(main_margin)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 10)
	main_margin.add_child(root_vbox)

	var header_panel: PanelContainer = PanelContainer.new()
	header_panel.custom_minimum_size = Vector2(0, 96)
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(header_panel)
	header_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.08, 0.11, 0.95), Color(0.25, 0.31, 0.40, 1.0), 10, 1))

	var header_padding: MarginContainer = MarginContainer.new()
	header_padding.add_theme_constant_override("margin_left", 14)
	header_padding.add_theme_constant_override("margin_right", 14)
	header_padding.add_theme_constant_override("margin_top", 10)
	header_padding.add_theme_constant_override("margin_bottom", 10)
	header_panel.add_child(header_padding)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	header_padding.add_child(header_hbox)

	var header_text: VBoxContainer = VBoxContainer.new()
	header_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_text)

	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 30)
	header_text.add_child(level_label)

	subtitle_label = Label.new()
	subtitle_label.add_theme_font_size_override("font_size", 16)
	header_text.add_child(subtitle_label)

	selected_label = Label.new()
	selected_label.add_theme_font_size_override("font_size", 15)
	header_text.add_child(selected_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	header_text.add_child(status_label)

	var header_buttons: VBoxContainer = VBoxContainer.new()
	header_buttons.add_theme_constant_override("separation", 6)
	header_buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_hbox.add_child(header_buttons)

	return_button = Button.new()
	return_button.text = "Return to Control Room"
	return_button.custom_minimum_size = Vector2(230, 42)
	return_button.pressed.connect(_on_return_button_pressed)
	header_buttons.add_child(return_button)

	var body_hbox: HBoxContainer = HBoxContainer.new()
	body_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 10)
	root_vbox.add_child(body_hbox)

	var side_panel: PanelContainer = PanelContainer.new()
	side_panel.custom_minimum_size = Vector2(290, 0)
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(side_panel)
	side_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.11, 0.14, 0.18, 0.95), Color(0.24, 0.31, 0.39, 1.0), 10, 1))

	var side_scroll: ScrollContainer = ScrollContainer.new()
	side_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	side_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	side_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	side_panel.add_child(side_scroll)

	var side_padding: MarginContainer = MarginContainer.new()
	side_padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_padding.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_padding.add_theme_constant_override("margin_left", 12)
	side_padding.add_theme_constant_override("margin_right", 12)
	side_padding.add_theme_constant_override("margin_top", 12)
	side_padding.add_theme_constant_override("margin_bottom", 12)
	side_scroll.add_child(side_padding)

	var side_vbox: VBoxContainer = VBoxContainer.new()
	side_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_vbox.add_theme_constant_override("separation", 10)
	side_padding.add_child(side_vbox)

	var material_title: Label = Label.new()
	material_title.text = "Materials"
	material_title.add_theme_font_size_override("font_size", 20)
	side_vbox.add_child(material_title)

	_create_material_button(side_vbox, SlotMaterial.WOOD, "Wood")
	_create_material_button(side_vbox, SlotMaterial.METAL, "Metal")
	_create_material_button(side_vbox, SlotMaterial.STONE, "Stone")

	var xray_title: Label = Label.new()
	xray_title.text = "X-Ray Scanner"
	xray_title.add_theme_font_size_override("font_size", 20)
	side_vbox.add_child(xray_title)

	var xray_holder: Control = Control.new()
	xray_holder.custom_minimum_size = Vector2(0, 136)
	side_vbox.add_child(xray_holder)

	var frame_rect: TextureRect = TextureRect.new()
	frame_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame_rect.texture = xray_frame_texture
	xray_holder.add_child(frame_rect)

	xray_toggle_button = TextureButton.new()
	xray_toggle_button.set_anchors_preset(Control.PRESET_CENTER)
	xray_toggle_button.position = Vector2(-52, -52)
	xray_toggle_button.custom_minimum_size = Vector2(104, 104)
	xray_toggle_button.ignore_texture_size = true
	xray_toggle_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	xray_toggle_button.texture_normal = xray_texture
	xray_toggle_button.texture_hover = xray_texture
	xray_toggle_button.texture_pressed = xray_texture
	xray_toggle_button.pressed.connect(_on_xray_toggle_pressed)
	xray_holder.add_child(xray_toggle_button)

	var xray_label: Label = Label.new()
	xray_label.text = "Toggle X-Ray"
	xray_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xray_label.position = Vector2(0, 118)
	xray_label.size = Vector2(280, 20)
	xray_holder.add_child(xray_label)

	xray_state_label = Label.new()
	xray_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	xray_state_label.text = "X-Ray OFF"
	side_vbox.add_child(xray_state_label)

	layer_buttons_container = HBoxContainer.new()
	layer_buttons_container.add_theme_constant_override("separation", 8)
	side_vbox.add_child(layer_buttons_container)

	var cycle_hint: Label = Label.new()
	cycle_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cycle_hint.text = "Higher levels add more layers and more structural holes. R badge = filled slot is replaceable."
	side_vbox.add_child(cycle_hint)

	var board_panel: PanelContainer = PanelContainer.new()
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(board_panel)
	board_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.13, 0.17, 0.95), Color(0.24, 0.31, 0.39, 1.0), 10, 1))

	var board_padding: MarginContainer = MarginContainer.new()
	board_padding.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_padding.add_theme_constant_override("margin_left", 10)
	board_padding.add_theme_constant_override("margin_right", 10)
	board_padding.add_theme_constant_override("margin_top", 10)
	board_padding.add_theme_constant_override("margin_bottom", 10)
	board_panel.add_child(board_padding)

	var board_vbox: VBoxContainer = VBoxContainer.new()
	board_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_vbox.add_theme_constant_override("separation", 8)
	board_padding.add_child(board_vbox)

	board_title_label = Label.new()
	board_title_label.add_theme_font_size_override("font_size", 18)
	board_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board_vbox.add_child(board_title_label)

	board_scroll = ScrollContainer.new()
	board_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL # Fixed size flag
	board_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	board_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	board_vbox.add_child(board_scroll)

	rows_container = VBoxContainer.new()
	rows_container.add_theme_constant_override("separation", 6)
	rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_scroll.add_child(rows_container)

	_build_win_panel()

# Creates the centered completion panel shown when a building is fully stabilized.
func _build_win_panel() -> void:
	win_panel = PanelContainer.new()
	win_panel.visible = false
	win_panel.set_anchors_preset(Control.PRESET_CENTER)
	win_panel.size = Vector2(560, 340)
	win_panel.position = Vector2(-280, -170)
	ui_root.add_child(win_panel)
	win_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.11, 0.14, 0.97), Color(0.34, 0.56, 0.36, 1.0), 14, 2))

	var win_padding: MarginContainer = MarginContainer.new()
	win_padding.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_padding.add_theme_constant_override("margin_left", 16)
	win_padding.add_theme_constant_override("margin_right", 16)
	win_padding.add_theme_constant_override("margin_top", 16)
	win_padding.add_theme_constant_override("margin_bottom", 16)
	win_panel.add_child(win_padding)

	var win_vbox: VBoxContainer = VBoxContainer.new()
	win_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	win_vbox.add_theme_constant_override("separation", 10)
	win_padding.add_child(win_vbox)

	win_title = Label.new()
	win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_title.add_theme_font_size_override("font_size", 34)
	win_title.text = "Quest Complete!"
	win_vbox.add_child(win_title)

	# Star container for dynamic star drawing
	star_container = HBoxContainer.new()
	star_container.alignment = BoxContainer.ALIGNMENT_CENTER
	star_container.add_theme_constant_override("separation", 10)
	win_vbox.add_child(star_container)

	win_detail = Label.new()
	win_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_detail.add_theme_font_size_override("font_size", 20)
	win_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	win_vbox.add_child(win_detail)

	win_score_label = Label.new()
	win_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_score_label.add_theme_font_size_override("font_size", 18)
	win_score_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	win_vbox.add_child(win_score_label)

	next_building_button = Button.new()
	next_building_button.text = "Exit Quest"
	next_building_button.custom_minimum_size = Vector2(220, 44)
	next_building_button.pressed.connect(_on_return_button_pressed)
	win_vbox.add_child(next_building_button)

# Draws stars in the star_container based on earned count.
func _draw_stars(earned: int) -> void:
	# Clear existing stars
	for child in star_container.get_children():
		child.queue_free()
	
	for i in range(5):
		var star: Control = Control.new()
		star.custom_minimum_size = Vector2(40, 40)
		star_container.add_child(star)
		
		var star_poly: Polygon2D = Polygon2D.new()
		star.add_child(star_poly)
		
		var points: PackedVector2Array = []
		var center: Vector2 = Vector2(20, 20)
		var outer_radius: float = 18.0
		var inner_radius: float = 8.0
		
		for j in range(10):
			var angle: float = deg_to_rad(j * 36 - 90)
			var r: float = outer_radius if j % 2 == 0 else inner_radius
			points.append(center + Vector2(cos(angle), sin(angle)) * r)
		
		star_poly.polygon = points
		if i < earned:
			star_poly.color = Color(1.0, 0.84, 0.0) # Gold
		else:
			star_poly.color = Color(0.3, 0.3, 0.3) # Grey

# Returns a reusable rounded panel style.
func _panel_style(bg: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border
	return style

# Creates a material selector button with an icon and label.
func _create_material_button(parent: Control, material_id: int, label_text: String) -> void:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(0, 52)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_material_button_pressed.bind(material_id))
	parent.add_child(btn)
	material_buttons[material_id] = btn

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 10)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn.add_child(hbox)

	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = material_textures.get(material_id, null)
	hbox.add_child(icon)

	var label: Label = Label.new()
	label.text = label_text
	hbox.add_child(label)

# Starts a new level, resetting all run-specific state and building the board.
func _start_level(level: int) -> void:
	GameState.current_level = level
	puzzle_completed = false
	xray_enabled = false
	current_layer_index = 0
	xray_toggle_count = 0
	elapsed_time = 0.0
	action_count = 0
	selected_material = SlotMaterial.EMPTY
	win_panel.visible = false
	_generate_level_layout(level)
	_rebuild_layer_buttons()
	_rebuild_active_layer_ui()
	_refresh_material_button_styles()
	_update_header_text()

# Returns quest generation settings for each of the 3 repair levels.
func _level_config(level: int) -> Dictionary:
	if level <= 1:
		return {
			"rows": 5,
			"cols": 2,
			"layers": 1,
			"materials": [SlotMaterial.WOOD, SlotMaterial.STONE],
			"hole_chance": 0.42,
			"mismatch_chance": 0.0,
			"solved_chance": 0.45,
			"allow_cycle": false,
		}
	if level == 2:
		return {
			"rows": 6,
			"cols": 3,
			"layers": 2,
			"materials": [SlotMaterial.WOOD, SlotMaterial.METAL, SlotMaterial.STONE],
			"hole_chance": 0.56,
			"mismatch_chance": 0.18,
			"solved_chance": 0.20,
			"allow_cycle": true,
		}
	return {
		"rows": 8,
		"cols": 4,
		"layers": 3,
		"materials": [SlotMaterial.WOOD, SlotMaterial.METAL, SlotMaterial.STONE],
		"hole_chance": 0.66,
		"mismatch_chance": 0.28,
		"solved_chance": 0.08,
		"allow_cycle": true,
	}

# Generates a multi-column mirrored building with one or more internal X-ray layers.
func _generate_level_layout(level: int) -> void:
	board_layers.clear()
	recommended_actions = 0

	var config: Dictionary = _level_config(level)
	row_count = int(config.get("rows", 5))
	cols_per_side = int(config.get("cols", 2))
	layer_count = int(config.get("layers", 1))
	allow_cycle_edits = bool(config.get("allow_cycle", false))

	var material_values: Array = config.get("materials", [])
	var materials: Array = []
	for value in material_values:
		materials.append(int(value))

	var hole_chance: float = float(config.get("hole_chance", 0.5))
	var mismatch_chance: float = float(config.get("mismatch_chance", 0.0))
	var solved_chance: float = float(config.get("solved_chance", 0.2))

	for _layer_index in range(layer_count):
		var rows: Array = []
		for _row_index in range(row_count):
			var left_slots: Array = []
			var right_slots: Array = []
			left_slots.resize(cols_per_side)
			right_slots.resize(cols_per_side)

			for left_col in range(cols_per_side):
				var right_col: int = _mirror_col(left_col)
				var target_material: int = materials[rng.randi_range(0, materials.size() - 1)]
				var anchor_side: String = "left" if rng.randf() < 0.5 else "right"
				var editable_side: String = "right" if anchor_side == "left" else "left"

				var left_slot: Dictionary = {"material": SlotMaterial.EMPTY, "editable": true}
				var right_slot: Dictionary = {"material": SlotMaterial.EMPTY, "editable": true}

				if anchor_side == "left":
					left_slot["material"] = target_material
					left_slot["editable"] = false
				else:
					right_slot["material"] = target_material
					right_slot["editable"] = false

				var roll: float = rng.randf()
				if roll < hole_chance:
					if editable_side == "left":
						left_slot["material"] = SlotMaterial.EMPTY
						left_slot["editable"] = true
					else:
						right_slot["material"] = SlotMaterial.EMPTY
						right_slot["editable"] = true
					recommended_actions += _actions_to_target(SlotMaterial.EMPTY, target_material, allow_cycle_edits)
				elif roll < hole_chance + mismatch_chance:
					var wrong_material: int = _random_different_material(target_material, materials)
					if editable_side == "left":
						left_slot["material"] = wrong_material
						left_slot["editable"] = true
					else:
						right_slot["material"] = wrong_material
						right_slot["editable"] = true
					recommended_actions += _actions_to_target(wrong_material, target_material, allow_cycle_edits)
				elif roll < hole_chance + mismatch_chance + solved_chance:
					if editable_side == "left":
						left_slot["material"] = target_material
						left_slot["editable"] = false
					else:
						right_slot["material"] = target_material
						right_slot["editable"] = false
				else:
					if editable_side == "left":
						left_slot["material"] = SlotMaterial.EMPTY
						left_slot["editable"] = true
					else:
						right_slot["material"] = SlotMaterial.EMPTY
						right_slot["editable"] = true
					recommended_actions += _actions_to_target(SlotMaterial.EMPTY, target_material, allow_cycle_edits)

				left_slots[left_col] = left_slot
				right_slots[right_col] = right_slot

			rows.append({"left": left_slots, "right": right_slots})
		board_layers.append({"rows": rows})

	_enforce_locked_pair_symmetry()

	if recommended_actions <= 0 and not board_layers.is_empty():
		var first_layer: Dictionary = board_layers[0]
		var first_rows: Array = first_layer.get("rows", [])
		if not first_rows.is_empty():
			var first_row: Dictionary = first_rows[0]
			var right_index: int = _mirror_col(0)
			var first_right: Array = first_row.get("right", [])
			if right_index >= 0 and right_index < first_right.size():
				var first_slot: Dictionary = first_right[right_index]
				first_slot["material"] = SlotMaterial.EMPTY
				first_slot["editable"] = true
				first_right[right_index] = first_slot
				first_row["right"] = first_right
				first_rows[0] = first_row
				first_layer["rows"] = first_rows
				board_layers[0] = first_layer
				recommended_actions = 1

	_slot_size_for_level(_get_clamped_level())

# Sets slot dimensions for each level so large boards stay readable.
func _slot_size_for_level(level: int) -> void:
	if level <= 1:
		slot_width = 74
		slot_height = 54
	elif level == 2:
		slot_width = 64
		slot_height = 48
	else:
		slot_width = 54
		slot_height = 40

# Returns the expected number of clicks needed for a slot to reach its mirrored target.
func _actions_to_target(from_material: int, to_material: int, use_cycle: bool) -> int:
	if from_material == to_material:
		return 0
	if use_cycle:
		return 1
	return 1

# Ensures all non-editable mirrored base pairs are symmetric so the puzzle is always solvable.
func _enforce_locked_pair_symmetry() -> void:
	for layer_idx in range(layer_count):
		for row_idx in range(row_count):
			for left_col in range(cols_per_side):
				var right_col: int = _mirror_col(left_col)
				var left_slot: Dictionary = _get_slot(layer_idx, row_idx, "left", left_col)
				var right_slot: Dictionary = _get_slot(layer_idx, row_idx, "right", right_col)

				var left_locked: bool = not bool(left_slot.get("editable", false))
				var right_locked: bool = not bool(right_slot.get("editable", false))
				if not (left_locked and right_locked):
					continue

				var left_material: int = int(left_slot.get("material", SlotMaterial.EMPTY))
				var right_material: int = int(right_slot.get("material", SlotMaterial.EMPTY))

				if left_material != right_material:
					right_slot["material"] = left_material
					_set_slot(layer_idx, row_idx, "right", right_col, right_slot)

# Returns a random material different from the given target material.
func _random_different_material(target_material: int, materials: Array) -> int:
	var pool: Array = []
	for material_id in materials:
		if int(material_id) != target_material:
			pool.append(int(material_id))
	if pool.is_empty():
		return target_material
	return int(pool[rng.randi_range(0, pool.size() - 1)])

# Returns the mirror-matched column index on the opposite side of the center axis.
func _mirror_col(col_index: int) -> int:
	return cols_per_side - 1 - col_index

# Rebuilds the layer selector controls shown when X-ray mode is enabled.
func _rebuild_layer_buttons() -> void:
	for child in layer_buttons_container.get_children():
		child.queue_free()
	layer_buttons.clear()

	layer_buttons_container.visible = xray_enabled
	if not xray_enabled:
		xray_state_label.text = "X-Ray OFF"
		return

	xray_state_label.text = "X-Ray ON: choose a structure layer"
	for layer_idx in range(layer_count):
		var button: Button = Button.new()
		button.text = "Layer %d" % [layer_idx + 1]
		button.custom_minimum_size = Vector2(80, 34)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_layer_button_pressed.bind(layer_idx))
		layer_buttons_container.add_child(button)
		layer_buttons.append(button)

	_refresh_layer_button_styles()

# Updates style highlights so the active X-ray layer button is clearly visible.
func _refresh_layer_button_styles() -> void:
	for layer_idx in range(layer_buttons.size()):
		var button: Button = layer_buttons[layer_idx] as Button
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		if layer_idx == current_layer_index:
			style.bg_color = Color(0.18, 0.32, 0.40, 0.95)
			style.border_color = Color(0.50, 0.82, 0.95, 1.0)
		else:
			style.bg_color = Color(0.18, 0.20, 0.24, 0.92)
			style.border_color = Color(0.32, 0.36, 0.42, 1.0)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)

# Rebuilds the visible board for the current active layer.
func _rebuild_active_layer_ui() -> void:
	active_slot_widgets.clear()
	_clear_children(rows_container)

	if board_layers.is_empty():
		return

	var active_layer: Dictionary = board_layers[current_layer_index]
	var rows: Array = active_layer.get("rows", [])
	var total_width: int = (cols_per_side * 2 * slot_width) + (cols_per_side * 2 * 4) + 44 + 26
	rows_container.custom_minimum_size = Vector2(total_width, 0)

	for row_index in range(rows.size()):
		var row_hbox: HBoxContainer = HBoxContainer.new()
		row_hbox.custom_minimum_size = Vector2(0, slot_height + 6)
		row_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		row_hbox.add_theme_constant_override("separation", 4)
		rows_container.add_child(row_hbox)

		var floor_label: Label = Label.new()
		floor_label.custom_minimum_size = Vector2(40, slot_height)
		floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		floor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		floor_label.text = "F%d" % [rows.size() - row_index]
		row_hbox.add_child(floor_label)

		var left_buttons: Array = []
		var left_icons: Array = []
		var left_badges: Array = []
		for col in range(cols_per_side):
			var left_info: Dictionary = _create_slot_widget(row_index, "left", col)
			row_hbox.add_child(left_info.get("button") as Button)
			left_buttons.append(left_info.get("button"))
			left_icons.append(left_info.get("icon"))
			left_badges.append(left_info.get("badge"))

		var axis_rect: ColorRect = ColorRect.new()
		axis_rect.custom_minimum_size = Vector2(10, slot_height)
		axis_rect.color = Color(0.84, 0.91, 0.95, 0.92)
		row_hbox.add_child(axis_rect)

		var right_buttons: Array = []
		var right_icons: Array = []
		var right_badges: Array = []
		for col in range(cols_per_side):
			var right_info: Dictionary = _create_slot_widget(row_index, "right", col)
			row_hbox.add_child(right_info.get("button") as Button)
			right_buttons.append(right_info.get("button"))
			right_icons.append(right_info.get("icon"))
			right_badges.append(right_info.get("badge"))

		active_slot_widgets.append({
			"left_buttons": left_buttons,
			"left_icons": left_icons,
			"left_badges": left_badges,
			"right_buttons": right_buttons,
			"right_icons": right_icons,
			"right_badges": right_badges,
			"axis": axis_rect,
		})

	_refresh_all_row_visuals()
	_update_board_title()

# Creates one clickable slot button for a specific row, side, and column index.
func _create_slot_widget(row_index: int, side: String, col_index: int) -> Dictionary:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(slot_width, slot_height)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_slot_pressed.bind(row_index, side, col_index))

	var icon: TextureRect = TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 6
	icon.offset_top = 4
	icon.offset_right = -6
	icon.offset_bottom = -4
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	button.add_child(icon)

	var badge: PanelContainer = PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -22
	badge.offset_top = 4
	badge.offset_right = -4
	badge.offset_bottom = 20

	var badge_label: Label = Label.new()
	badge_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.text = "R"
	badge_label.add_theme_font_size_override("font_size", 10)
	badge.add_child(badge_label)
	button.add_child(badge)

	return {
		"button": button,
		"icon": icon,
		"badge": badge,
	}

# Clears all existing children from the given node.
func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()

# Handles selecting a material from the side selector.
func _on_material_button_pressed(material_id: int) -> void:
	selected_material = material_id
	_refresh_material_button_styles()
	_update_header_text()

# Updates selector styles so the chosen material stands out.
func _refresh_material_button_styles() -> void:
	for key in material_buttons.keys():
		var material_id: int = int(key)
		var button: Button = material_buttons[key] as Button
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		if material_id == selected_material:
			style.bg_color = Color(0.23, 0.33, 0.22, 0.95)
			style.border_color = Color(0.54, 0.85, 0.49, 1.0)
		else:
			style.bg_color = Color(0.18, 0.20, 0.24, 0.92)
			style.border_color = Color(0.32, 0.36, 0.42, 1.0)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)

# Handles clicking a structural slot to place the currently selected material.
func _on_slot_pressed(row_index: int, side: String, col_index: int) -> void:
	if puzzle_completed:
		return
	if row_index < 0 or row_index >= row_count:
		return
	if col_index < 0 or col_index >= cols_per_side:
		return

	var slot: Dictionary = _get_slot(current_layer_index, row_index, side, col_index)
	if not bool(slot.get("editable", false)):
		return

	var current_material: int = int(slot.get("material", SlotMaterial.EMPTY))
	if selected_material == SlotMaterial.EMPTY:
		return
	if current_material == selected_material:
		return

	slot["material"] = selected_material
	action_count += 1

	_set_slot(current_layer_index, row_index, side, col_index, slot)
	_refresh_row_visual(row_index)
	_check_for_completion()
	_update_header_text()

# Gets a slot dictionary from the generated board data.
func _get_slot(layer_idx: int, row_idx: int, side: String, col_idx: int) -> Dictionary:
	var layer_data: Dictionary = board_layers[layer_idx]
	var rows: Array = layer_data.get("rows", [])
	var row: Dictionary = rows[row_idx]
	var side_slots: Array = row.get(side, [])
	return side_slots[col_idx]

# Writes a slot dictionary into the generated board data.
func _set_slot(layer_idx: int, row_idx: int, side: String, col_idx: int, slot: Dictionary) -> void:
	var layer_data: Dictionary = board_layers[layer_idx]
	var rows: Array = layer_data.get("rows", [])
	var row: Dictionary = rows[row_idx]
	var side_slots: Array = row.get(side, [])
	side_slots[col_idx] = slot
	row[side] = side_slots
	rows[row_idx] = row
	layer_data["rows"] = rows
	board_layers[layer_idx] = layer_data

# Returns symmetry status for one mirrored pair within a given layer row.
func _pair_status(layer_idx: int, row_idx: int, left_col_idx: int) -> int:
	var left_slot: Dictionary = _get_slot(layer_idx, row_idx, "left", left_col_idx)
	var right_slot: Dictionary = _get_slot(layer_idx, row_idx, "right", _mirror_col(left_col_idx))
	var left_material: int = int(left_slot.get("material", SlotMaterial.EMPTY))
	var right_material: int = int(right_slot.get("material", SlotMaterial.EMPTY))

	if left_material == SlotMaterial.EMPTY or right_material == SlotMaterial.EMPTY:
		return PairStatus.INCOMPLETE
	if left_material == right_material:
		return PairStatus.SYMMETRICAL
	return PairStatus.MISMATCH

# Checks the entire building and completes the puzzle when all layers are mirrored.
func _check_for_completion() -> void:
	for layer_idx in range(layer_count):
		for row_idx in range(row_count):
			for col_idx in range(cols_per_side):
				if _pair_status(layer_idx, row_idx, col_idx) != PairStatus.SYMMETRICAL:
					return
	_on_puzzle_completed()

# Completes the run, computes score/stars, and shows the centered result panel.
func _on_puzzle_completed() -> void:
	if puzzle_completed:
		return

	puzzle_completed = true
	
	# Accumulate current level stats into quest totals
	total_recommended_actions += recommended_actions
	total_action_count += action_count
	total_xray_toggle_count += xray_toggle_count
	total_elapsed_time += elapsed_time
	
	var current_level: int = _get_clamped_level()
	
	if current_level < MAX_LEVEL:
		# Auto-advance to next level without showing win panel
		var next_level: int = current_level + 1
		GameState.current_level = next_level
		_start_level(next_level)
	else:
		# Final level complete - show the official quest ending
		var score_data: Dictionary = _calculate_final_score()
		var score: int = int(score_data.get("score", 0))
		var stars: int = int(score_data.get("stars", 1))

		GameState.last_repair_score = score
		GameState.last_repair_stars = stars

		win_detail.text = "All %d buildings stabilised. Quest successfully concluded." % MAX_LEVEL
		win_score_label.text = "Total Score %d / 100\nTotal Actions: %d (optimal %d)  |  Total Time: %.1fs  |  X-Ray toggles: %d" % [
			score,
			total_action_count,
			total_recommended_actions,
			total_elapsed_time,
			total_xray_toggle_count,
		]

		_draw_stars(stars)
		win_panel.visible = true
		_update_header_text()

# Computes a balanced score for the entire quest (3 levels).
func _calculate_final_score() -> Dictionary:
	# Using total stats for the final rating
	var extra_actions: int = max(0, total_action_count - total_recommended_actions)
	
	# Base target time for 3 levels (approx 180s)
	var target_time: float = 180.0 
	var time_over: float = max(0.0, total_elapsed_time - target_time)

	var score: int = 100
	score -= int(round(time_over * 0.4)) 
	score -= extra_actions * 4 
	score -= total_xray_toggle_count

	score = clampi(score, 0, 100)
	var stars: int = _score_to_stars(score)

	return {
		"score": score,
		"stars": stars,
	}

# Converts score values into 1..5 stars.
func _score_to_stars(score: int) -> int:
	if score >= 90:
		return 5
	if score >= 75:
		return 4
	if score >= 60:
		return 3
	if score >= 45:
		return 2
	return 1

# Refreshes every currently visible row.
func _refresh_all_row_visuals() -> void:
	for row_idx in range(active_slot_widgets.size()):
		_refresh_row_visual(row_idx)

# Refreshes visual state of one row on the currently visible layer.
func _refresh_row_visual(row_idx: int) -> void:
	if row_idx < 0 or row_idx >= active_slot_widgets.size():
		return

	var widgets: Dictionary = active_slot_widgets[row_idx]
	var left_buttons: Array = widgets.get("left_buttons", [])
	var left_icons: Array = widgets.get("left_icons", [])
	var left_badges: Array = widgets.get("left_badges", [])
	var right_buttons: Array = widgets.get("right_buttons", [])
	var right_icons: Array = widgets.get("right_icons", [])
	var right_badges: Array = widgets.get("right_badges", [])
	var axis: ColorRect = widgets.get("axis") as ColorRect

	for col_idx in range(cols_per_side):
		_apply_slot_visual(
			left_buttons[col_idx] as Button,
			left_icons[col_idx] as TextureRect,
			left_badges[col_idx] as PanelContainer,
			row_idx,
			"left",
			col_idx
		)
		_apply_slot_visual(
			right_buttons[col_idx] as Button,
			right_icons[col_idx] as TextureRect,
			right_badges[col_idx] as PanelContainer,
			row_idx,
			"right",
			col_idx
		)

	if axis != null:
		if xray_enabled:
			axis.color = Color(0.45, 0.93, 1.0, 0.95)
		else:
			axis.color = Color(0.84, 0.91, 0.95, 0.92)

# Applies icon and border style to one slot with symmetry-aware highlighting.
func _apply_slot_visual(button: Button, icon: TextureRect, badge: PanelContainer, row_idx: int, side: String, col_idx: int) -> void:
	if button == null or icon == null:
		return

	var slot: Dictionary = _get_slot(current_layer_index, row_idx, side, col_idx)
	var material_id: int = int(slot.get("material", SlotMaterial.EMPTY))
	var is_editable: bool = bool(slot.get("editable", false))
	var is_empty: bool = material_id == SlotMaterial.EMPTY

	if is_empty:
		icon.texture = null
	else:
		icon.texture = material_textures.get(material_id, null)

	var pair_col: int = col_idx if side == "left" else _mirror_col(col_idx)
	var pair_state: int = _pair_status(current_layer_index, row_idx, pair_col)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2

	if is_empty:
		style.bg_color = Color(0.09, 0.09, 0.11, 0.95)
		style.border_color = Color(0.40, 0.44, 0.50, 0.95)
		if xray_enabled:
			style.border_color = Color(0.58, 0.80, 0.95, 0.95)
	else:
		style.bg_color = Color(0.17, 0.19, 0.23, 0.96)
		if pair_state == PairStatus.SYMMETRICAL:
			style.border_color = Color(0.43, 0.90, 0.48, 0.98)
		else:
			style.border_color = Color(0.39, 0.43, 0.48, 0.95)

	if not is_editable:
		style.bg_color = style.bg_color.darkened(0.22)

	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)

	if badge != null:
		var show_badge: bool = is_editable and not is_empty
		badge.visible = show_badge
		if show_badge:
			var badge_style: StyleBoxFlat = StyleBoxFlat.new()
			badge_style.bg_color = Color(0.95, 0.77, 0.26, 0.95)
			badge_style.border_color = Color(0.99, 0.92, 0.60, 1.0)
			badge_style.border_width_left = 1
			badge_style.border_width_top = 1
			badge_style.border_width_right = 1
			badge_style.border_width_bottom = 1
			badge_style.corner_radius_top_left = 4
			badge_style.corner_radius_top_right = 4
			badge_style.corner_radius_bottom_left = 4
			badge_style.corner_radius_bottom_right = 4
			badge.add_theme_stylebox_override("panel", badge_style)
			if badge.get_child_count() > 0:
				var badge_label: Label = badge.get_child(0) as Label
				if badge_label != null:
					badge_label.add_theme_color_override("font_color", Color(0.12, 0.10, 0.08, 1.0))

# Toggles X-ray mode and reveals/hides layer controls.
func _on_xray_toggle_pressed() -> void:
	xray_enabled = not xray_enabled
	xray_toggle_count += 1
	if not xray_enabled:
		current_layer_index = 0
	_rebuild_layer_buttons()
	_rebuild_active_layer_ui()
	_update_header_text()

# Switches to a specific X-ray layer when the player clicks Layer 1/2/3.
func _on_layer_button_pressed(layer_idx: int) -> void:
	if not xray_enabled:
		return
	current_layer_index = clampi(layer_idx, 0, layer_count - 1)
	_refresh_layer_button_styles()
	_rebuild_active_layer_ui()
	_update_header_text()

# Returns from the puzzle scene to the control room scene.
func _on_return_button_pressed() -> void:
	get_tree().change_scene_to_file(RETURN_SCENE_PATH)

# Updates top header text and dynamic run stats.
func _update_header_text() -> void:
	var level: int = _get_clamped_level()
	level_label.text = "Skyscraper Repair  |  Level %d / %d" % [level, MAX_LEVEL]

	if selected_material == SlotMaterial.EMPTY:
		selected_label.text = "Selected Material: none"
	else:
		selected_label.text = "Selected Material: %s" % _material_name(selected_material)

	var layer_view_text: String = "Layer %d/%d" % [current_layer_index + 1, layer_count]
	if not xray_enabled:
		layer_view_text = "Layer 1/%d" % layer_count

	if puzzle_completed:
		status_label.text = "Level complete. Total Time %.1fs, actions %d" % [total_elapsed_time + elapsed_time, total_action_count + action_count]
	else:
		status_label.text = "Time %.1fs  |  Actions %d (target %d)  |  %s" % [elapsed_time, action_count, recommended_actions, layer_view_text]

	subtitle_label.text = "Repair the full mirrored facade around the center axis. Filled slots with an R badge are replaceable."
	_update_board_title()

# Updates the board title line with current layer and X-ray state.
func _update_board_title() -> void:
	if board_title_label == null:
		return
	var layer_text: String = "Layer %d/%d" % [current_layer_index + 1, layer_count]
	if not xray_enabled:
		layer_text = "Surface Layer (toggle X-Ray for inner layers)"
	board_title_label.text = "Facade Grid: %d rows x %d mirrored columns per side  |  %s" % [row_count, cols_per_side, layer_text]

# Converts material enum values into readable names.
func _material_name(material_id: int) -> String:
	match material_id:
		SlotMaterial.WOOD:
			return "Wood"
		SlotMaterial.METAL:
			return "Metal"
		SlotMaterial.STONE:
			return "Stone"
		_:
			return "None"

# Extracts the first Sprite2D texture from an asset scene.
func _extract_scene_texture(scene: PackedScene) -> Texture2D:
	var instance: Node = scene.instantiate()
	var sprite: Sprite2D = _find_first_sprite(instance)
	var texture: Texture2D = null
	if sprite != null:
		texture = sprite.texture
	instance.free()
	return texture

# Recursively finds and returns the first Sprite2D node in a scene tree.
func _find_first_sprite(node: Node) -> Sprite2D:
	if node is Sprite2D:
		return node as Sprite2D
	for child in node.get_children():
		var found: Sprite2D = _find_first_sprite(child)
		if found != null:
			return found
	return null
