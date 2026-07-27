extends StaticBody2D

var dragging = false
@export var snap_degrees: float = 1.0
# The direction the mirror's "face" is pointing
@export var face_direction: Vector2 = Vector2.RIGHT 

func _ready():
	# --- PROTECTION START ---
	if not "laser_map" in get_tree().current_scene.name:
		set_process(false)
		set_process_input(false)
		hide()
		return
	# --- PROTECTION END ---

	# Ensure the mirror can be clicked
	input_pickable = true
	add_to_group("mirrors")

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: 
			dragging = true

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed: 
			dragging = false

func _process(_delta):
	if dragging:
		# Calculate angle towards mouse
		var target_angle = (get_global_mouse_position() - global_position).angle()
		# Snap and apply rotation
		var snapped_deg = snapped(rad_to_deg(target_angle), snap_degrees)
		rotation = deg_to_rad(snapped_deg)

# This is the function your Laser script calls
func get_reflection(incident_dir: Vector2) -> Vector2:
	# 1. Get the current direction of the mirror face based on rotation
	var normal = face_direction.rotated(rotation).normalized()
	
	# 2. Check which side the laser hit (Dot Product)
	var dot = incident_dir.dot(normal)
	
	# 3. 2-SIDED LOGIC:
	# If dot > 0, the laser hit the "back" of the normal.
	# We flip the normal so it reflects correctly off both sides.
	if dot > 0:
		normal = -normal
		dot = incident_dir.dot(normal)
	
	# 4. Standard Reflection Math: R = I - 2 * (I dot N) * N
	var reflection = (incident_dir - 2 * dot * normal).normalized()
	
	return reflection
