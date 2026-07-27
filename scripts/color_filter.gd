extends StaticBody2D

# --- ROTATION & DRAGGING ---
var dragging = false
@export var snap_degrees: float = 1.0

# --- RANGE CHECK ---
var player_in_range = false

# --- TEXTURE AND COLOR ARRAYS ---
@export var filter_textures: Array[Texture2D] = [] 
@export var color_names: Array[String] = ["red", "orange", "cyan"]
@export var visual_colors: Array[Color] = [Color.RED, Color.ORANGE, Color.CYAN]
var current_index: int = 0
var filter_color_name: String = "red"
var filter_visual_color: Color = Color.RED

@onready var sprite = $Sprite2D

func _ready():
	print("[Filter] ========== FILTER _ready START ==========")
	print("[Filter] Current scene name:", get_tree().current_scene.name)
	
	# --- PROTECTION START ---
	if not "laser_map" in get_tree().current_scene.name:
		print("[Filter] Not in laser_map scene, disabling filter")
		set_process(false)
		set_process_input(false)
		hide()
		return
	# --- PROTECTION END ---
	
	print("[Filter] Filter active in laser_map scene")
	print("[Filter] Filter position:", global_position)
	add_to_group("filters")
	input_pickable = true 
	_update_filter()
	
	# Check if Area2D exists
	var area = get_node_or_null("Area2D")
	if area:
		print("[Filter] ✓ Area2D found!")
		print("[Filter] Area2D collision layer:", area.collision_layer)
		print("[Filter] Area2D collision mask:", area.collision_mask)
		
		# MANUALLY connect signals if not connected
		if not area.body_entered.is_connected(_on_area_2d_body_entered):
			print("[Filter] ⚠ body_entered NOT connected - connecting now...")
			area.body_entered.connect(_on_area_2d_body_entered)
		else:
			print("[Filter] ✓ body_entered already connected")
			
		if not area.body_exited.is_connected(_on_area_2d_body_exited):
			print("[Filter] ⚠ body_exited NOT connected - connecting now...")
			area.body_exited.connect(_on_area_2d_body_exited)
		else:
			print("[Filter] ✓ body_exited already connected")
			
		# Check if Area2D has a CollisionShape
		var collision_shape = area.get_node_or_null("CollisionShape2D")
		if collision_shape:
			print("[Filter] ✓ CollisionShape2D found!")
			print("[Filter] CollisionShape disabled:", collision_shape.disabled)
			if collision_shape.shape:
				print("[Filter] ✓ Shape assigned:", collision_shape.shape)
			else:
				print("[Filter] ✗ ERROR: No shape assigned to CollisionShape2D!")
		else:
			print("[Filter] ✗ ERROR: CollisionShape2D NOT FOUND in Area2D!")
	else:
		print("[Filter] ✗ ERROR: Area2D node NOT FOUND!")
	
	# Find player and check groups
	await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")
	if player:
		print("[Filter] ✓ Player found:", player.name)
		print("[Filter] Player position:", player.global_position)
		print("[Filter] Player groups:", player.get_groups())
		print("[Filter] Player collision layer:", player.collision_layer if "collision_layer" in player else "N/A")
		print("[Filter] Player collision mask:", player.collision_mask if "collision_mask" in player else "N/A")
	else:
		print("[Filter] ✗ ERROR: No player found in 'player' group!")
	
	print("[Filter] ========== FILTER _ready END ==========")

# This is called when the player enters the Area2D
func _on_area_2d_body_entered(body: Node2D) -> void:
	print("[Filter] ==========================================")
	print("[Filter] _on_area_2d_body_entered called! Body:", body.name)
	print("[Filter] Body type:", body.get_class())
	print("[Filter] Body groups:", body.get_groups())
	print("[Filter] Body position:", body.global_position)
	print("[Filter] ==========================================")
	
	if body.is_in_group("player"):
		player_in_range = true
		print("[Filter] ✓✓✓ Player ENTERED range - player_in_range = TRUE ✓✓✓")
	else:
		print("[Filter] Body is NOT in 'player' group")

# This is called when the player leaves the Area2D
func _on_area_2d_body_exited(body: Node2D) -> void:
	print("[Filter] _on_area_2d_body_exited called! Body:", body.name)
	
	if body.is_in_group("player"):
		player_in_range = false
		print("[Filter] ✓ Player LEFT range - player_in_range = FALSE")

# COMBINED _input function
func _input(event):
	# Change Color/Sprite (Press 'C')
	if event.is_action_pressed("change_color"):
		print("[Filter] 'change_color' action detected!")
		print("[Filter] player_in_range:", player_in_range)
		
		if player_in_range:
			print("[Filter] ✓✓✓ Changing color! ✓✓✓")
			current_index = (current_index + 1) % color_names.size()
			_update_filter()
			print("[Filter] Changed to index:", current_index, "color:", color_names[current_index])
		else:
			print("[Filter] ✗ Player NOT in range, cannot change color")
	
	# Stop dragging when mouse released
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed: 
			dragging = false

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: 
			dragging = true

func _process(_delta):
	if dragging:
		var target_angle = (get_global_mouse_position() - global_position).angle()
		var snapped_deg = snapped(rad_to_deg(target_angle), snap_degrees)
		rotation = deg_to_rad(snapped_deg)

func _update_filter():
	filter_color_name = color_names[current_index]
	filter_visual_color = visual_colors[current_index]
	
	if filter_textures.size() > current_index:
		sprite.texture = filter_textures[current_index]
