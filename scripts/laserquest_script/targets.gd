extends StaticBody2D

@export var target_doors: Array[StaticBody2D] = []
@export var my_id: String = "1"
@export var texture_off: Texture2D
@export var texture_on: Texture2D

# This is now a String ("red", "cyan", etc.)
@export var required_color: String = "red"
@onready var sprite = $Sprite2D 

var is_hit_this_frame = false

func _ready():
	add_to_group("targets")

func _physics_process(_delta):
	if not is_hit_this_frame:
		if sprite.texture != texture_off:
			_set_state(false)
	
	is_hit_this_frame = false 

# IMPORTANT: Change the argument to (laser_color_name: String)
func on_hit(laser_color_name: String):
	# Simple string comparison
	if laser_color_name == required_color:
		is_hit_this_frame = true
		if sprite.texture != texture_on:
			_set_state(true)
	else:
		# Wrong color name doesn't trigger the target
		is_hit_this_frame = false

func _set_state(active: bool):
	sprite.texture = texture_on if active else texture_off
	
	# 1. Update Doors (Old code)
	for door in target_doors:
		if door and door.has_method("update_signal"):
			door.update_signal(my_id, active)
			
	# 2. Update Win Menu (New Code)
	# We use a group so we don't have to drag-and-drop the node
	get_tree().call_group("win_menu", "update_signal", my_id, active)
	
	print("Target ", my_id, " state changed to: ", active)
