extends StaticBody2D

# --- ROTATION & DRAGGING ---
var dragging = false
@export var snap_degrees: float = 1.0

# --- RANGE CHECK ---
var player_in_range = false # New variable to track the player

# --- TEXTURE AND COLOR ARRAYS ---
@export var filter_textures: Array[Texture2D] = [] 
@export var color_names: Array[String] = ["red", "orange", "cyan"]
@export var visual_colors: Array[Color] = [Color.RED, Color.ORANGE, Color.CYAN]

var current_index: int = 0
var filter_color_name: String = "red"
var filter_visual_color: Color = Color.RED

@onready var sprite = $Sprite2D

func _ready():
	# --- PROTECTION START ---
	if not "laser_map" in get_tree().current_scene.name:
		set_process(false)
		set_process_input(false)
		hide()
		return
	# --- PROTECTION END ---

	add_to_group("filters")
	input_pickable = true 
	_update_filter()

# This is called when the player enters the Area2D
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true

# This is called when the player leaves the Area2D
func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func _input(event):
	# Stop dragging logic
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed: 
			dragging = false
	
	# Change Color/Sprite (Press 'C')
	# ONLY works if the player is standing in the Area2D!
	if Input.is_action_just_pressed("change_color") and player_in_range:
		current_index = (current_index + 1) % color_names.size()
		_update_filter()

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
