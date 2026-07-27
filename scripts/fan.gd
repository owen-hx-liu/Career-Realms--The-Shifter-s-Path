extends Node2D

@export var fan_index: int = 0 
# Set this to the pixel size you want the fan to be in the game
@export var target_size: Vector2 = Vector2(30, 30) 

# Ensure this matches your node name (AnimatedSprite2D)
@onready var anim = $Sprite2D 

func _ready():
	_force_constant_size()

func _force_constant_size():
	# Get the size of the actual image frame
	var frame_tex = anim.sprite_frames.get_frame_texture("idle", 0)
	var current_res = frame_tex.get_size()
	
	# Calculate the scale needed: (Goal / Current)
	var required_scale = target_size / current_res
	anim.scale = required_scale

func _process(_delta):
	# Look at global array we set up [0, 0, 0]
	var state = global.fan_states[fan_index]
	
	if state == 0:
		anim.play("idle")
		anim.modulate = Color(1, 1, 1) # Normal
	elif state == 1:
		anim.play("running")
		anim.modulate = Color(1, 0.5, 0.5) # Red tint (Heat)
	elif state == -1:
		anim.play("running")
		anim.modulate = Color(0.5, 0.5, 1) # Blue tint (Cool)
