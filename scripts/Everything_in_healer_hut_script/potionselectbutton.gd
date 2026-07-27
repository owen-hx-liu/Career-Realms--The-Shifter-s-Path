# potion_button.gd
extends Button

signal potion_chosen(potion_name: String)

var potion_name: String = ""
var potion_icon: Texture2D:
	set(value):
		potion_icon = value
		# Set it as the button's built-in icon
		icon = value

func _ready():
	# Remove text - only show icon
	text = ""
	
	pressed.connect(_on_pressed)

func _on_pressed():
	emit_signal("potion_chosen", potion_name)
