extends Area2D

# Drag your "ControlPanel" (The UI/CanvasLayer/Control node) here in Inspector
@export var control_panel: Control 

var player_nearby: bool = false

func _ready():
	# Ensure the signals are connected
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
		
	# Start with the panel hidden
	if control_panel:
		control_panel.visible = false

func _on_body_entered(body):
	# Make sure your player node is actually in the group "player"!
	if body.is_in_group("player"):
		player_nearby = true
		print("Player entered Control Zone")

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false
		print("Player left Control Zone")
		
		# Auto-close the menu if you walk away while it's open
		if control_panel:
			control_panel.visible = false

func _input(event):
	# 1. Check if the button was pressed
	if event.is_action_pressed("collect"):
		
		# 2. CRITICAL FIX: We MUST check if the player is nearby here!
		# If this line is missing, the menu opens from anywhere in the level.
		if player_nearby:
			
			if control_panel:
				# Toggle the visibility
				control_panel.visible = not control_panel.visible
				print("Toggled Panel. New State: ", control_panel.visible)
			else:
				push_error("Control Panel node is not assigned in the Inspector!")
