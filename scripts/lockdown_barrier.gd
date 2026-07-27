extends StaticBody2D

@onready var collision_shape = $CollisionShape2D

func _process(_delta):
	# We use the variables ALREADY in your global script
	# If the quest is running and NOT over, the door is solid (disabled = false)
	if global.quest_active and not global.game_over:
		collision_shape.disabled = false
		queue_redraw() # To show the red "locked" effect
	else:
		# If the timer hit 0 and _end_game() was called, collision turns off
		collision_shape.disabled = true
		queue_redraw()

# Optional visual "Forcefield" art
func _draw():
	if global.quest_active and not global.game_over:
		var rect = collision_shape.shape.get_rect()
		# Draw a translucent red box so player sees the door is locked
		
