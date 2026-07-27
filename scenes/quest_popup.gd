extends Control

@export var message_text: String = "Default message"
@export var auto_close_time: float = 0.0

func _ready():
	print("MessagePopup _ready() called")
	print("Message text: ", message_text)
	
	# Set the message text to the Label
	if has_node("Panel/Label"):
		$Panel/Label.text = message_text
		print("Label text set to: ", message_text)
	else:
		print("ERROR: Panel/Label not found!")
		print("Available children: ")
		for child in get_children():
			print("  - ", child.name)
	
	# Center the popup
	var viewport_size = get_viewport_rect().size
	var scaled_size = size * scale
	position = (viewport_size / 2) - (scaled_size / 2)
	
	# Pause the game
	get_tree().paused = true
	print("Game paused")
	
	# Auto-close if time is set
	if auto_close_time > 0:
		print("Setting up auto-close timer for ", auto_close_time, " seconds")
		await get_tree().create_timer(auto_close_time, true, false, true).timeout
		close_popup()

func _process(_delta):
	if Input.is_action_just_pressed("ui_accept"):
		print("Space pressed - closing popup")
		close_popup()

func close_popup():
	print("Closing popup")
	get_tree().paused = false
	queue_free()
