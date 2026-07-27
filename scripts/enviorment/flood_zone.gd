extends Area2D

@export var danger_label: String = "Flood Risk"

func _ready():
	visible = false

func flood_warning():
	visible = true
	print(danger_label)
