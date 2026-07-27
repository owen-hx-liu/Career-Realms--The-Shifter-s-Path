extends Node2D

@export var circle_radius: float = 15.0
@export var circle_color: Color = Color.BLACK
@export var shine_speed: float = 2.0
@export var location_name: String = "Location"
@export var robots_required: int = 1
@export var work_time: float = 60.0
@export var points_reward: int = 100

var shine_time: float = 0.0
var is_hovered: bool = false
var assigned_robots: Array = []
var is_working: bool = false
var is_completed: bool = false
var work_progress: float = 0.0
var actual_work_time: float = 0.0

func _ready():
	queue_redraw()

func _process(delta):
	shine_time += delta * shine_speed
	
	# Update work progress
	if is_working:
		work_progress += delta / actual_work_time
		if work_progress >= 1.0:
			complete_work()
	
	queue_redraw()

func _draw():
	var pulse = (sin(shine_time) + 1.0) / 2.0
	var current_radius = circle_radius + (pulse * 5)
	
	# Determine color
	var main_color = Color.BLACK
	
	if is_completed:
		main_color = Color(0.0, 0.8, 0.0)  # Green: complete
	elif is_working:
		if assigned_robots.size() >= robots_required:
			main_color = Color(0.0, 0.8, 0.0)  # Green: full capacity
		else:
			main_color = Color(1.0, 0.5, 0.0)  # Orange: partial capacity
	elif work_progress > 0:
		main_color = Color(0.5, 0.5, 0.5)  # Gray: paused with progress
	else:
		main_color = Color.BLACK  # Black: empty
	
	if is_hovered and not is_completed:
		main_color = main_color.lightened(0.2)
	
	# Draw circle
	var glow_color = Color(main_color.r, main_color.g, main_color.b, 0.5)
	draw_circle(Vector2.ZERO, current_radius + 10, glow_color)
	draw_circle(Vector2.ZERO, current_radius, main_color)
	
	var shine_color = Color(1, 1, 1, pulse * 0.7)
	draw_circle(Vector2(-5, -5), current_radius * 0.3, shine_color)
	
	# Progress bar (show if working OR paused with progress)
	if is_working or work_progress > 0:
		var bar_width = 60.0
		var bar_height = 8.0
		var bar_pos = Vector2(-bar_width / 2, current_radius + 20)
		
		draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color(0.2, 0.2, 0.2))
		
		var progress_width = bar_width * work_progress
		var bar_color = Color(0.0, 1.0, 0.0) if is_working else Color(0.8, 0.8, 0.0)  # Green if working, yellow if paused
		draw_rect(Rect2(bar_pos, Vector2(progress_width, bar_height)), bar_color)
		
		draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color.WHITE, false, 1.0)

func add_robot(robot) -> bool:
	if is_completed:
		print(location_name, " is already completed!")
		return false
	
	if assigned_robots.size() >= robots_required:
		print(location_name, " is full (", assigned_robots.size(), "/", robots_required, ")!")
		return false
	
	assigned_robots.append(robot)
	print(location_name, " now has ", assigned_robots.size(), "/", robots_required, " robots")
	
	# Start or resume work
	if assigned_robots.size() == 1:
		if work_progress > 0:
			# Resume from saved progress
			resume_work()
		else:
			# Start fresh
			start_work()
	
	queue_redraw()
	return true

func start_work():
	is_working = true
	work_progress = 0.0
	
	# Calculate work time based on robot efficiency
	# Formula: Time increases if fewer robots
	# efficiency = actual_robots / required_robots
	# If you have 1 robot but need 3: efficiency = 0.33, time = 3x longer
	# If you have 3 robots and need 3: efficiency = 1.0, time = normal
	
	var robot_efficiency = float(assigned_robots.size()) / float(robots_required)
	actual_work_time = work_time / robot_efficiency
	
	print(location_name, " starting work with ", assigned_robots.size(), "/", robots_required, " robots")
	print("  Efficiency: ", robot_efficiency * 100, "%")
	print("  Base time: ", work_time, "s → Actual time: ", actual_work_time, "s")

func complete_work():
	is_working = false
	is_completed = true
	work_progress = 1.0
	
	print("✓ ", location_name, " COMPLETED! Awarding ", points_reward, " points")
	
	# Award points
	var score_mgr = get_node_or_null("/root/MapView/ScoreManager")
	if score_mgr:
		score_mgr.add_points(points_reward)
	
	# Keep robots at location (they stay there when complete)
	# If you want them freed, uncomment below:
	# for robot in assigned_robots:
	#     robot.is_assigned = false
	#     robot.assigned_location = null

func _on_area_2d_mouse_entered():
	is_hovered = true

func _on_area_2d_mouse_exited():
	is_hovered = false

func _on_area_2d_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		show_location_info()

func show_location_info():
	if is_completed:
		print(location_name, " is already completed!")
		return
	
	var popup = get_node_or_null("/root/MapView/UILayer/LocationInfoPopup")
	if popup:
		var mouse_pos = get_viewport().get_mouse_position()
		var popup_panel = popup.get_node("Panel")
		var viewport_size = get_viewport().get_visible_rect().size
		
		var popup_x = mouse_pos.x - popup_panel.size.x / 2
		var popup_y = mouse_pos.y + 30
		
		popup_x = clamp(popup_x, 0, viewport_size.x - popup_panel.size.x)
		popup_y = clamp(popup_y, 0, viewport_size.y - popup_panel.size.y)
		
		popup.position = Vector2(popup_x, popup_y)
		popup.show_info(location_name, robots_required, work_time)
		
func remove_robot(robot):
	var index = assigned_robots.find(robot)
	if index != -1:
		assigned_robots.erase(robot)
		print(location_name, " removed robot. Now has ", assigned_robots.size(), "/", robots_required, " robots")
		
		# If no robots left, pause work (don't reset progress)
		if assigned_robots.size() == 0:
			pause_work()
		else:
			# Recalculate with fewer robots (work will take longer)
			recalculate_work_time_on_removal()
		
		queue_redraw()

func pause_work():
	# Pause work but KEEP progress
	is_working = false
	print(location_name, " work PAUSED at ", int(work_progress * 100), "% - no robots")
	print("  Progress saved! Add robots to resume.")
	queue_redraw()

func resume_work():
	# Resume from saved progress
	if work_progress >= 1.0:
		return  # Already complete
	
	is_working = true
	
	# Calculate remaining time
	var remaining_progress = 1.0 - work_progress
	var new_efficiency = float(assigned_robots.size()) / float(robots_required)
	var remaining_base_time = remaining_progress * work_time
	actual_work_time = work_progress * work_time + (remaining_base_time / new_efficiency)
	
	print(location_name, " work RESUMED from ", int(work_progress * 100), "%")
	print("  Efficiency: ", int(new_efficiency * 100), "% with ", assigned_robots.size(), " robots")

func recalculate_work_time_on_removal():
	if not is_working:
		return
	
	var remaining_progress = 1.0 - work_progress
	var new_efficiency = float(assigned_robots.size()) / float(robots_required)
	
	var remaining_work = remaining_progress * work_time
	var new_remaining_time = remaining_work / new_efficiency
	
	actual_work_time = (work_progress * actual_work_time) + new_remaining_time
	
	print(location_name, " work slowed! Efficiency: ", int(new_efficiency * 100), "%")
