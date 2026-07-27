extends Control

@onready var points_label = $NinePatchRect/PointsLabel
var current_points = 0

func _ready():
	# Load saved points from GameState
	if "player_points" in GameState:
		current_points = GameState.player_points
	else:
		GameState.player_points = 0
	
	update_display()
	visible = false  # Start hidden

func add_points(amount: int):
	current_points += amount
	GameState.player_points = current_points
	update_display()
	print("[POINTS] Added ", amount, " points. Total: ", current_points)

func update_display():
	if points_label:
		points_label.text = "Points: \n" + str(current_points)
		print("[POINTS] Updated display to: Points: ", current_points)
	else:
		print("[POINTS] ERROR: points_label not found!")

func _process(delta):
	# Sync with GameState in case it was updated elsewhere
	if GameState.player_points != current_points:
		current_points = GameState.player_points
		update_display()
	
	# Show/hide with inventory - check the inventory's actual state
	var canvas_layer = get_parent()
	if canvas_layer:
		var inv_ui = canvas_layer.get_node_or_null("Inv_UI")
		if inv_ui:
			# Check if inventory has the is_open variable and use it
			if "is_open" in inv_ui:
				visible = inv_ui.is_open
			else:
				# Fallback: check visibility
				visible = inv_ui.visible
		else:
			visible = false
	else:
		visible = false
