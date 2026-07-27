extends Node2D

# --- SETTINGS ---
@export var required_ids: Array[String] = ["19"]
var signal_states: Dictionary = {}
var has_won: bool = false
var stars_earned: int = 0

# --- PATHS ---
@onready var score_box = $NinePatchRect
@onready var score_label = $NinePatchRect/Label
@onready var star_drawer = $NinePatchRect/Node2D 

# Visuals
var STAR_FILLED = Color(1.0, 0.84, 0.0)  # Gold
var STAR_EMPTY = Color(0.3, 0.3, 0.3)    # Dark gray

func _ready():
	add_to_group("win_menu")
	score_box.visible = false
	
	for id in required_ids:
		signal_states[id] = false
		
	if star_drawer:
		star_drawer.draw.connect(_on_star_drawer_draw)

func update_signal(id: String, state: bool):
	if has_won: return 
	if signal_states.has(id):
		signal_states[id] = state
		_check_win_condition()

func _check_win_condition():
	# Loop through every ID in the list ("15", "16", "17", "18", "19")
	for id in required_ids:
		# If any of the required signals are still false, stop right here
		if signal_states.get(id) == false:
			return 
			
	# If the loop finishes without returning, it means ALL targets were hit!
	_trigger_win()

func _trigger_win():
	if has_won: return
	has_won = true
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# 1. Center the Menu on Camera
		var canvas_transform = get_canvas_transform()
		var screen_center = -canvas_transform.origin / canvas_transform.get_scale() + (get_viewport_rect().size / 2 / canvas_transform.get_scale())
		self.global_position = screen_center
		
		# 2. Calculate Stars (Logic stays, but we won't print the 'count' anymore)
		var count = player.total_objects_placed if "total_objects_placed" in player else 0
		if count <= 26: stars_earned = 5
		elif count <= 29: stars_earned = 4
		elif count <= 32: stars_earned = 3
		elif count <= 35: stars_earned = 2
		else: stars_earned = 1
		
		# 3. Setup Box and Label (Removed the objects used line)
		score_label.text = "Congratulations!"
		score_box.visible = true
		
		# Offset the box
		score_box.position = -score_box.size / 2
		
		# 4. Draw the stars
		_animate_stars()

func _animate_stars():
	for i in range(stars_earned + 1):
		star_drawer.queue_redraw() 
		await get_tree().create_timer(0.2).timeout

func _on_star_drawer_draw():
	if not score_box: return
	
	# Using your preferred star lining settings
	var x_start = score_box.size.x / 2 - 100 
	var y_pos = 90 
	var gap = 50
	var size = 25

	for i in range(5):
		var pos = Vector2(x_start + (i * gap), y_pos)
		var color = STAR_FILLED if i < stars_earned else STAR_EMPTY
		
		var points = _get_star_points(pos, size)
		star_drawer.draw_colored_polygon(points, color)
		star_drawer.draw_polyline(points + PackedVector2Array([points[0]]), Color.BLACK, 2.0)

func _get_star_points(center: Vector2, radius: float) -> PackedVector2Array:
	var inner_radius = radius * 0.4
	var points = PackedVector2Array()
	for i in range(10):
		var angle = deg_to_rad(i * 36 - 90)
		var r = radius if i % 2 == 0 else inner_radius
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points
