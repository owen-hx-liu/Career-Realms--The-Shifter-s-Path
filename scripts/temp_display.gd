extends CanvasLayer

@export var temp_label: Label 

func _ready():
	# If this doesn't print when you start the game, 
	# the script isn't attached to the right node!
	print("Temp UI is awake!")

func _process(_delta):
	if temp_label == null:
		# This will alert you if you forgot to drag the label in
		push_warning("Temp Label is missing from the Inspector!")
		return
		
	var temp = global.current_temp
	
	# Update the text
	temp_label.text = "%.1f°F" % temp
	
	# Logic for color
	if temp > 85.0:
		temp_label.add_theme_color_override("font_color", Color.RED)
	elif temp < 52.0:
		temp_label.add_theme_color_override("font_color", Color.AQUA)
	else:
		temp_label.add_theme_color_override("font_color", Color.WHITE)
