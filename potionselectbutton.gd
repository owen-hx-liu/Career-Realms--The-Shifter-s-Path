extends Button

@export var potion_name: String

signal potion_chosen(potion_name: String)

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	emit_signal("potion_chosen", potion_name)
