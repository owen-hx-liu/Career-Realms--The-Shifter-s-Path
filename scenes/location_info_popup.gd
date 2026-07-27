extends Control

@onready var info_label = $Panel/InfoLabel

func _ready():
	visible = false

func show_info(location_name: String, robots_required: int, work_time: float):
	# Create the message
	var time_text = str(int(work_time)) + " seconds"
	var message = "Location: " + location_name + "\n\n"
	message += "Takes " + str(robots_required) + " robots and " + time_text + " to complete!\n\n"
	message += "Drag as many robots as you want to send!"
	
	info_label.text = message
	visible = true
	print("Showing popup for: ", location_name)

func hide_popup():
	visible = false

func _on_close_button_pressed():
	hide_popup()

# Close when clicking outside
func _input(event):
	if visible and event is InputEventMouseButton and event.pressed:
		# Check if click is outside the panel
		var panel = $Panel
		var mouse_pos = get_global_mouse_position()
		var panel_rect = Rect2(panel.global_position, panel.size)
		
		if not panel_rect.has_point(mouse_pos):
			hide_popup()
