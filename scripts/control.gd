extends Control

var is_open = false
var panel_width = 350.0 # Adjust this to make the panel wider or thinner

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event):
	if event.is_action_pressed("S"):
		is_open = !is_open
		visible = is_open
		queue_redraw()

func _process(_delta):
	if is_open: 
		queue_redraw()

func _draw():
	if not is_open: return
	
	var screen = get_viewport_rect().size
	# Calculate the starting X position for the panel (Right side)
	var panel_x = screen.x - panel_width
	
	# 1. TRANSLUCENT BACKGROUND (Only on the right side)
	# Rect2(x, y, width, height)
	draw_rect(Rect2(panel_x, 0, panel_width, screen.y), Color(0, 0, 0, 0.8), true)
	
	# Draw a border line to separate it from the game
	draw_line(Vector2(panel_x, 0), Vector2(panel_x, screen.y), Color(1, 1, 1, 0.3), 2.0)
	
	# Define a center point for text within the panel
	var panel_center_x = panel_x + (panel_width / 2.0)
	var font = ThemeDB.fallback_font
	
	# 2. TIMER (Top of Panel)
	var time_str = "%02d:%02d" % [int(global.game_timer) / 60, int(global.game_timer) % 60]
	draw_string(font, Vector2(panel_center_x - 30, 60), time_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 40, Color.WHITE)
	
	# 3. SCORE & STARS
	var stars = _get_star_count()
	var score_text = "Score: %d" % int(global.score)
	draw_string(font, Vector2(panel_center_x - 50, 110), score_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 28, Color.YELLOW)
	
	# Draw Stars (Smaller for the side panel)
	for i in range(1, 6):
		var star_col = Color.GOLD if i <= stars else Color.DIM_GRAY
		# Spacing stars across the panel width
		_draw_star(Vector2(panel_x + (i * 55), 160), 15, star_col)

	# 4. ANIMAL LIST
	var y = 230
	draw_string(font, Vector2(panel_x + 20, y - 30), "Animal Status:", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.AQUA)
	
	for animal in global.barn_animals:
		var status_col = Color.GREEN if animal.happy else Color.RED
		
		# Draw the Animal Name
		draw_string(font, Vector2(panel_x + 40, y), animal.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		
		# Draw a small status indicator circle
		draw_circle(Vector2(panel_x + 25, y - 6), 5, status_col)
		
		# If unhappy, draw the specific warning
		if not animal.happy:
			var reason = "HOT" if global.current_temp > animal.max else "COLD"
			draw_string(font, Vector2(panel_x + 200, y), reason, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.RED)
			
		y += 35

func _get_star_count() -> int:
	var s = global.score
	if s >= 450: return 5
	elif s >= 400: return 4
	elif s >= 300: return 3
	elif s >= 200: return 2
	else: return 1

func _draw_star(pos, size, color):
	var points = PackedVector2Array()
	var inner_r = size / 2.5
	var outer_r = size
	var rot = -PI / 2
	var step = PI / 5
	for i in range(10):
		var r = outer_r if i % 2 == 0 else inner_r
		points.append(pos + Vector2(cos(rot), sin(rot)) * r)
		rot += step
	draw_colored_polygon(points, color)
