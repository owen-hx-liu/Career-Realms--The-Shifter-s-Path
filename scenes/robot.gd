extends Node2D

@export var robot_id: int = 1
@export var is_assigned: bool = false
@export var detection_radius: float = 100.0

var assigned_location = null
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO

func _ready():
	original_position = global_position
	print("Robot ", robot_id, " initialized")

func _process(_delta):
	if is_dragging:
		global_position = get_global_mouse_position() - drag_offset
		queue_redraw()

func _draw():
	if is_dragging:
		draw_circle(Vector2.ZERO, detection_radius, Color(0, 1, 0, 0.1))
		draw_arc(Vector2.ZERO, detection_radius, 0, 2 * PI, 32, Color(0, 1, 0, 0.4), 2.0)

func _on_area_2d_input_event(viewport, event, shape_idx):
	# Allow dragging even if assigned
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# If already assigned, remove from current location
			if is_assigned and assigned_location:
				print("Removing Robot ", robot_id, " from ", assigned_location.location_name)
				assigned_location.remove_robot(self)
				is_assigned = false
				assigned_location = null
			
			# Start dragging
			is_dragging = true
			drag_offset = get_global_mouse_position() - global_position
		else:
			is_dragging = false
			queue_redraw()
			check_for_assignment()

func check_for_assignment():
	var locations = get_tree().get_nodes_in_group("location_markers")
	
	var closest_location = null
	var closest_distance = detection_radius
	
	for location in locations:
		var distance = global_position.distance_to(location.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_location = location
	
	if closest_location:
		if closest_location.add_robot(self):
			assigned_location = closest_location
			is_assigned = true
			position_near_location(closest_location)
			return
	
	print("Robot ", robot_id, " returning home")
	global_position = original_position

func position_near_location(location):
	var robots_at_location = location.assigned_robots.size()
	var angle = (robots_at_location - 1) * (360.0 / max(location.robots_required, 1)) * PI / 180.0
	var offset = Vector2(cos(angle), sin(angle)) * 40
	
	global_position = location.global_position + offset
