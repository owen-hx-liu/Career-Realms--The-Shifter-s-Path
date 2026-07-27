extends Control

# The colors for our wires - using high saturation for that "bright" look
var colors = [
	Color(1, 0, 0),    # Pure Red
	Color(0, 1, 0),    # Pure Green
	Color(0, 0.6, 1),  # Bright Blue
	Color(1, 1, 0)     # Pure Yellow
]

var selected_port = null 

func setup_game():
	# 1. Clear everything from the last attempt
	for n in get_children():
		if n is Button or n is Line2D:
			n.queue_free()
	
	selected_port = null
	
	# 2. Randomize the color order for both sides
	var left_colors = colors.duplicate()
	var right_colors = colors.duplicate()
	left_colors.shuffle()
	right_colors.shuffle()
	
	# 3. Spawn the ports
	for i in range(colors.size()):
		_create_port(i, left_colors[i], true)
		_create_port(i, right_colors[i], false)

func _create_port(index, color, is_left):
	var btn = Button.new()
	
	# --- MAKE IT SOLID AND BRIGHT ---
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(1, 1, 1, 0.4) # A soft white inner-glow effect
	sb.set_corner_radius_all(6)           # Rounded "socket" look
	
	# Apply style to all states so it stays solid
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("disabled", sb)
	
	# Positioning
	btn.custom_minimum_size = Vector2(50, 50)
	# Left column at x=150, Right column at x=450
	btn.position = Vector2(150 if is_left else 450, 100 + (index * 90))
	
	# Metadata for logic
	btn.set_meta("color", color)
	btn.set_meta("is_left", is_left)
	
	btn.pressed.connect(_on_port_pressed.bind(btn))
	add_child(btn)

func _on_port_pressed(btn):
	if selected_port == null:
		# First click must be on a left port to start a wire
		if btn.get_meta("is_left"):
			selected_port = btn
			btn.text = "●" # Visual indicator of selection
			btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		# Second click logic
		var same_color = btn.get_meta("color") == selected_port.get_meta("color")
		var different_side = btn.get_meta("is_left") != selected_port.get_meta("is_left")
		
		if same_color and different_side:
			# Match found!
			_draw_line(selected_port, btn)
			btn.disabled = true
			selected_port.disabled = true
			selected_port.text = ""
			selected_port = null
			_check_win()
		else:
			# Wrong match or clicked same side - Reset selection
			if selected_port:
				selected_port.text = ""
			selected_port = null

func _draw_line(p1, p2):
	var line = Line2D.new()
	# Match the line color to the port color
	line.default_color = p1.get_meta("color")
	line.width = 8 # Thick enough to see easily
	line.z_index = -1 # Draw lines behind the ports
	
	# Add points (centered on buttons)
	line.add_point(p1.position + Vector2(25, 25))
	line.add_point(p2.position + Vector2(25, 25))
	add_child(line)

func _check_win():
	# Count how many Line2D nodes exist
	var line_count = 0
	for n in get_children():
		if n is Line2D:
			line_count += 1
			
	if line_count >= colors.size():
		# Success! 
		print("System Restored!")
		global.fix_system()
		
		# Optional: Wait half a second so the player sees the last line
		await get_tree().create_timer(0.5).timeout
		get_parent().visible = false
