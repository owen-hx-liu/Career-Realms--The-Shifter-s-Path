extends Sprite2D

func _ready():
	# 1. Connect to the global signal
	global.breakdown_changed.connect(_on_breakdown_changed)
	
	# 2. Check current state (in case we enter the room and it's ALREADY broken)
	visible = global.system_broken

func _on_breakdown_changed(is_broken):
	# If broken is true, visible is true.
	# If broken is false, visible is false.
	visible = is_broken
	
	# Optional: Add a simple blinking animation effect
	if is_broken:
		var tween = create_tween().set_loops()
		tween.tween_property(self, "modulate:a", 0.2, 0.5) # Fade out
		tween.tween_property(self, "modulate:a", 1.0, 0.5) # Fade in
	else:
		# Stop blinking and reset opacity
		modulate.a = 1.0
		# (The tween dies automatically when the node hides, usually, 
		# but resetting alpha is good practice)
